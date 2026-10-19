/*
 * ping - ICMP echo client over a BSD raw socket (W5100 IPRAW offload).
 *
 *   ping <host>            continuous, until ^C   (BSD default)
 *   ping <host> <count>    stop after <count> probes (gate-friendly)
 *
 * socket(AF_INET, SOCK_RAW, IPPROTO_ICMP); build an ICMP echo request with a
 * per-probe payload pattern, software-checksum it (the W5100 does IP+ARP+IP
 * checksum, not L4), send, poll recvfrom for the reply, and VERIFY the remote
 * echoed our exact id/seq AND payload back byte-for-byte.  The payload check is
 * the real end-to-end proof: a reply only counts if the remote copied our data
 * verbatim into its echo reply.  No bind() — the kernel implicit-binds on first
 * send.  1-second inter-probe interval + min/avg/max stats, like BSD ping.
 *
 * Limits (honest): RTT uses the 60 Hz SYS_TICKS counter (16.67 ms resolution),
 * so sub-tick replies read 0 ms; under MAME, emulated time != real network RTT.
 * TTL is unavailable — the W5100 IPRAW recv delivers the IP payload (ICMP
 * message) only, having stripped the IP header where TTL lives.
 *
 * ^C arrives as SIGINT from the tty, the way BSD ping takes it.  It used to be
 * polled out of the kernel keyboard ring with pollkey(), which takes no fd --
 * so over a pty this watched the PHYSICAL CONSOLE and the remote user's ^C
 * could not stop a ping they had started (apple/fgx#151).  The tty discipline
 * already sends SIGINT to the foreground process group of the line the ^C was
 * typed on, which is the right line by construction.
 *
 * fcc notes: file-scope raw byte buffers (fcc pads structs; stack buffers land
 * in the wrong bank).  No %lu/UL; checksum uses end-around carry in 16-bit.
 */
#include <stdio.h>
#include <stdlib.h>
#include <setjmp.h>
#include <signal.h>
#include <netdb.h>
#include "../lib/socket_h.h"

int ticks(void);            /* ping_ticks.s */

/* THE HANDLER LONGJMPS, and it has to.  FGX re-enters a marked syscall
 * unconditionally on signal return -- there is no SA_INTERRUPT -- so a handler
 * that merely set a flag and returned would drop straight back into the
 * recvfrom it interrupted, and the loop would never reach the test.  That is
 * the same reason alrmintr(8) and elvis's V7 ttyread() backend longjmp.
 *
 * FILE-SCOPE jmp_buf, not automatic: an automatic one is copied through the
 * DATA bank and lands in the malloc heap (fcc #42). */
jmp_buf intr_jb;
int stopped;

void onintr(int sig)
{
    stopped = 1;
    longjmp(intr_jb, 1);
}

#define PAYLOAD 56          /* BSD-default ICMP data bytes -> 64-byte ICMP msg */
#define ICMPLEN (8 + PAYLOAD)

static unsigned char dst[16];       /* dst sockaddr_in        */
static unsigned char from[16];      /* reply src sockaddr_in  */
static unsigned char pkt[72];       /* ICMP echo request (8 + 56) */
static unsigned char rbuf[256];     /* reply buffer           */

/* one's-complement 16-bit checksum, fcc-safe (no long, no 0xffff masks). */
unsigned int icmp_cksum(unsigned char *p, int n)
{
    unsigned int sum, w;
    int i;
    sum = 0;
    i = 0;
    while (i + 1 < n) {
        w = (p[i] << 8) | p[i + 1];
        sum = sum + w;
        if (sum < w) sum = sum + 1;     /* end-around carry */
        i = i + 2;
    }
    if (i < n) {
        w = p[i] << 8;
        sum = sum + w;
        if (sum < w) sum = sum + 1;
    }
    return ~sum;
}

/* parse "a.b.c.d" into out[0..3]; return 1 on success, 0 on malformed. */
int parse_ip(char *s, unsigned char *out)
{
    int i, v, ndig;
    i = 0;
    while (i < 4) {
        v = 0;
        ndig = 0;
        while (*s >= '0' && *s <= '9') {
            v = v * 10 + (*s - '0');
            s = s + 1;
            ndig = ndig + 1;
        }
        if (ndig == 0 || v > 255) return 0;
        out[i] = v;
        i = i + 1;
        if (i < 4) {
            if (*s != '.') return 0;
            s = s + 1;
        }
    }
    return (*s == 0);
}

/* busy-wait ~`t` 60 Hz ticks.  ^C does not return through here -- the handler
   longjmps past it -- so there is nothing to report back. */
int wait_ticks(int t)
{
    int t0;
    t0 = ticks();
    while ((ticks() - t0) < t)
        ;
    return 0;
}

int main(int argc, char **argv)
{
    int s, n, i, count, sent, recvd, id, seq, t0, t1, rtt, waited;
    int cont, good, loss, rmin, rmax, rsum, fromlen;
    unsigned int ck;

    stopped = 0;
    signal(SIGINT, onintr);

    if (argc < 2) {
        printf("usage: ping <ip> [count]\n");
        return 1;
    }
    if (!parse_ip(argv[1], &dst[SIN_ADDR])) {
        /* not a dotted quad -> resolve via /etc/hosts + DNS (gethostbyname). */
        struct hostent *h;
        unsigned char *a;
        h = gethostbyname(argv[1]);
        if (h == 0) {
            printf("ping: cannot resolve %s\n", argv[1]);
            return 1;
        }
        a = (unsigned char *)h->h_addr_list[0];
        dst[SIN_ADDR] = a[0]; dst[SIN_ADDR + 1] = a[1];
        dst[SIN_ADDR + 2] = a[2]; dst[SIN_ADDR + 3] = a[3];
    }
    cont = 1;                            /* continuous unless a count is given */
    count = 0;
    if (argc > 2) {
        count = atoi(argv[2]);
        cont = 0;
        if (count < 1) count = 1;
    }

    s = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);
    if (s < 0) {
        printf("ping: socket failed\n");
        return 1;
    }
    dst[SIN_FAMILY] = AF_INET;
    dst[SIN_PORT] = 0;
    dst[SIN_PORT + 1] = 0;

    printf("PING %s (%u.%u.%u.%u): %u data bytes\n", argv[1],
           dst[SIN_ADDR], dst[SIN_ADDR + 1], dst[SIN_ADDR + 2], dst[SIN_ADDR + 3],
           PAYLOAD);

    id = 0x4753;                         /* 'GS' */
    sent = 0;
    recvd = 0;
    seq = 0;
    rmin = 30000;
    rmax = 0;
    rsum = 0;

    /* ^C lands here, wherever in the loop it struck.  Falling through to the
       statistics is BSD ping's finish(): an interrupted ping still reports. */
    if (setjmp(intr_jb) != 0)
        printf("\n");
    while (!stopped && (cont || seq < count)) {

        /* build echo request: type 8, id, seq, per-probe payload pattern */
        for (i = 0; i < ICMPLEN; i = i + 1) pkt[i] = 0;
        pkt[0] = 8;                      /* echo request */
        pkt[1] = 0;
        pkt[4] = (id >> 8) & 0xff;
        pkt[5] = id & 0xff;
        pkt[6] = (seq >> 8) & 0xff;
        pkt[7] = seq & 0xff;
        for (i = 0; i < PAYLOAD; i = i + 1)
            pkt[8 + i] = (i + seq) & 0xff;       /* unique per seq */
        ck = icmp_cksum(pkt, ICMPLEN);
        pkt[2] = (ck >> 8) & 0xff;
        pkt[3] = ck & 0xff;

        t0 = ticks();
        sendto(s, pkt, ICMPLEN, 0, dst, 16);
        sent = sent + 1;

        good = 0;
        t1 = t0;
        waited = 0;
        while (waited < 60) {                     /* up to ~1s for a reply */
            fromlen = 16;
            n = recvfrom(s, rbuf, 256, 0, from, &fromlen);
            if (n >= ICMPLEN && rbuf[0] == 0 &&    /* echo reply, right size */
                rbuf[4] == ((id >> 8) & 0xff) && rbuf[5] == (id & 0xff) &&
                rbuf[6] == ((seq >> 8) & 0xff) && rbuf[7] == (seq & 0xff)) {
                good = 1;                          /* verify echoed payload */
                for (i = 0; i < PAYLOAD; i = i + 1)
                    if (rbuf[8 + i] != ((i + seq) & 0xff)) {
                        good = 0;
                        break;
                    }
                t1 = ticks();
                break;
            }
            t1 = ticks();
            waited = t1 - t0;
        }

        if (good) {
            rtt = (t1 - t0) * 17;                  /* 60 Hz -> ms (~16.7/tick) */
            recvd = recvd + 1;
            rsum = rsum + rtt;
            if (rtt < rmin) rmin = rtt;
            if (rtt > rmax) rmax = rtt;
            printf("%u bytes from %u.%u.%u.%u: icmp_seq=%u time=%u ms\n",
                   n, from[SIN_ADDR], from[SIN_ADDR + 1],
                   from[SIN_ADDR + 2], from[SIN_ADDR + 3], seq, rtt);
        } else if (waited >= 60) {
            printf("request timed out: icmp_seq=%u\n", seq);
        } else {
            printf("corrupt reply: icmp_seq=%u (payload mismatch)\n", seq);
        }

        seq = seq + 1;

        if (cont || seq < count)                  /* BSD 1s interval */
            (void) wait_ticks(60);
    }

    close(s);
    if (sent > 0) loss = (sent - recvd) * 100 / sent;
    else loss = 0;
    printf("--- %u.%u.%u.%u ping statistics ---\n",
           dst[SIN_ADDR], dst[SIN_ADDR + 1], dst[SIN_ADDR + 2], dst[SIN_ADDR + 3]);
    printf("%u packets transmitted, %u received, %u%% packet loss\n",
           sent, recvd, loss);
    if (recvd > 0)
        printf("round-trip min/avg/max = %u/%u/%u ms\n", rmin, rsum / recvd, rmax);
    return 0;
}
