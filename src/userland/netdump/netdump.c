/* netdump - tcpdump-shaped packet observer over /dev/bpf0.
 *
 * Reads one whole {caplen.w, datalen.w, frame...} record per read() from the
 * record-mode chardev (kernel Model B path), dissects the captured frame
 * (Ethernet -> ARP, or IPv4 -> ICMP/UDP/TCP), and prints one compact line:
 *
 *   <seq> <len> <source> > <dest> <summary>
 *
 * IP rows show IPs (proto port for UDP/TCP via the summary); non-IP rows show
 * MACs.  Snaplen is 60 bytes (kernel BPF_SNAPLEN), enough for Eth+IP+L4 heads.
 *
 * Termination: stop after maxpkts packets when given; otherwise run a safety
 * iteration bound so the program always exits.  No-arg uses a short bound
 * (gate-friendly); `netdump N` uses a long one for interactive ping capture.
 *
 * Usage: netdump [maxpkts]
 */
#include <stdio.h>
#include <setjmp.h>
#include <signal.h>
#include <stdlib.h>

/* fcc libc shims without a toolchain header. */
int read(int fd, void *buf, int n);
int fileno(FILE *fp);
/* ^C arrives as SIGINT from the tty, not polled out of the kernel keyboard
 * ring.  pollkey() takes no fd, so over a pty it watched the PHYSICAL CONSOLE
 * and a remote user could not stop this (apple/fgx#151).  The tty discipline
 * signals the foreground process group of the line the ^C was typed on, which
 * is the right line by construction.
 *
 * THE HANDLER LONGJMPS, and it has to.  FGX re-enters a marked syscall
 * unconditionally on signal return -- there is no SA_INTERRUPT -- so a handler
 * that set a flag and returned would drop straight back into the blocking call
 * it interrupted and the loop's test would never be reached.  Same idiom as
 * alrmintr(8) and elvis's V7 ttyread() backend.  FILE-SCOPE jmp_buf: an
 * automatic one is copied through the DATA bank into the malloc heap (fcc #42).
 */
jmp_buf intr_jb;
int stopped;

void onintr(int sig)
{
    stopped = 1;
    longjmp(intr_jb, 1);
}

#define ET_ARP   0x0806
#define ET_IPV4  0x0800
#define IPP_ICMP 1
#define IPP_TCP  6
#define IPP_UDP  17

/* file-scope: fcc syscall buffers must live in the data bank, not the stack. */
unsigned char rec[64];
char hexd[] = "0123456789abcdef";

/* read a 16-bit big-endian field (network byte order). */
int get16(unsigned char *p)
{
    return (p[0] << 8) | p[1];
}

void put_hex2(int b)
{
    printf("%c%c", hexd[(b >> 4) & 15], hexd[b & 15]);
}

void put_mac(unsigned char *p)
{
    int i;
    for (i = 0; i < 6; i = i + 1) {
        if (i > 0)
            printf(":");
        put_hex2(p[i]);
    }
}

void put_ip(unsigned char *p)
{
    printf("%u.%u.%u.%u", p[0], p[1], p[2], p[3]);
}

/* Dissect a captured Ethernet frame (caplen bytes) into a one-line summary. */
void parse_frame(unsigned char *f, int caplen)
{
    int et, op, proto, ihl, l4, type, code, sp, dp, id, sq;

    if (caplen < 14) {
        printf("(runt %u)", caplen);
        return;
    }
    et = get16(f + 12);

    if (et == ET_ARP) {
        put_mac(f + 6);
        printf(" > ");
        put_mac(f);
        op = get16(f + 20);
        if (op == 1) {
            printf(" ARP who-has ");
            put_ip(f + 38);
        } else if (op == 2) {
            printf(" ARP is-at ");
            put_ip(f + 28);
        } else {
            printf(" ARP op %u", op);
        }
        return;
    }

    if (et == ET_IPV4) {
        ihl = (f[14] & 15) * 4;
        proto = f[23];
        put_ip(f + 26);
        printf(" > ");
        put_ip(f + 30);
        l4 = 14 + ihl;
        if (proto == IPP_ICMP) {
            type = f[l4];
            code = f[l4 + 1];
            if (type == 8 || type == 0) {
                id = get16(f + l4 + 4);
                sq = get16(f + l4 + 6);
                if (type == 8)
                    printf(" ICMP echo req id %u seq %u", id, sq);
                else
                    printf(" ICMP echo rep id %u seq %u", id, sq);
            } else {
                printf(" ICMP type %u code %u", type, code);
            }
        } else if (proto == IPP_UDP) {
            sp = get16(f + l4);
            dp = get16(f + l4 + 2);
            printf(" UDP %u > %u len %u", sp, dp, get16(f + l4 + 4));
        } else if (proto == IPP_TCP) {
            sp = get16(f + l4);
            dp = get16(f + l4 + 2);
            printf(" TCP %u > %u", sp, dp);
        } else {
            printf(" IP proto %u", proto);
        }
        return;
    }

    /* non-IP, non-ARP: MACs + raw ethertype */
    put_mac(f + 6);
    printf(" > ");
    put_mac(f);
    printf(" type ");
    put_hex2((et >> 8) & 255);
    put_hex2(et & 255);
}

int main(int argc, char **argv)
{
    stopped = 0;
    signal(SIGINT, onintr);

    FILE *fp;
    int fd, n, caplen, datalen, npkts, maxpkts, seq;
    long iter, maxiter;

    maxpkts = 0;
    if (argc > 1)
        maxpkts = atoi(argv[1]);

    fp = fopen("/dev/bpf0", "r");
    if (fp == 0) {
        printf("netdump: cannot open /dev/bpf0\n");
        return 1;
    }
    fd = fileno(fp);
    printf("netdump: listening on /dev/bpf0\n");

    if (maxpkts > 0)
        maxiter = 4000000L;
    else
        maxiter = 5000L;

    npkts = 0;
    seq = 0;
    if (setjmp(intr_jb) != 0)
        printf("\nnetdump: interrupted\n");
    for (iter = 0L; !stopped && iter < maxiter; iter = iter + 1L) {
        n = read(fd, rec, 64);
        if (n >= 4) {
            caplen = rec[0] | (rec[1] << 8);
            datalen = rec[2] | (rec[3] << 8);
            if (caplen == 0) {
                /* sentinel: RX ring saturated (frames lost); datalen = count */
                printf("  [saturated %u]\n", datalen);
            } else {
                seq = seq + 1;
                printf("%4u %4u ", seq, datalen);
                parse_frame(&rec[4], caplen);
                printf("\n");
                npkts = npkts + 1;
                if (maxpkts > 0 && npkts >= maxpkts)
                    break;
            }
        }
    }
    fclose(fp);
    printf("netdump: %u packets\n", npkts);
    return 0;
}
