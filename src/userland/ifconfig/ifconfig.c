/*
 * ifconfig - show / configure a network interface (FGX net-config v1).
 *
 *   ifconfig                 list all interfaces
 *   ifconfig u2s1            show one interface
 *   ifconfig u2s1 inet A.B.C.D netmask A.B.C.D broadcast A.B.C.D   (T5)
 *
 * Talks to the kernel ifnet table via SYS_IFCONFIG (the c_ifctl shim).
 *
 * The ifreq is a RAW 32-byte array, not a C struct: fcc even-aligns
 * word/long/pointer members (chars byte-pack since B-8 2026-07-06, words
 * still don't), so a struct still would not match the kernel's fully
 * packed IF_* layout (include/ifnet.s).
 * Byte offsets here mirror IF_* exactly.  Output is printf-only (the console
 * drops LF on the putchar/fputs path); the MAC is built with a local hex table
 * (fcc's %02x width is unreliable — same as netdump.c).
 */
#include <stdio.h>
#include <string.h>

#define IFR_SIZE      32
#define IFR_NAME       0      /* 8 bytes, NUL-padded */
#define IFR_SLOT       8      /* 1 (also the IFC_GETN index) */
#define IFR_MAC        9      /* 6 */
#define IFR_FLAGS     15      /* 1 */
#define IFR_IP        16      /* 4 */
#define IFR_NETMASK   20      /* 4 */
#define IFR_BROADCAST 24      /* 4 */

#define IFC_GETN      0
#define IFC_GET       1
#define IFC_SET       2

/* kernel IF_Flags bits (include/ifnet.s) — the real per-interface state. */
#define IFF_LINK_UP   0x01    /* card present + SHAR written */
#define IFF_IP_CONF   0x02    /* IP layer configured (DHCP or ifconfig) */
#define IFF_DHCP      0x04    /* IP came from a DHCP lease */

/* BSD-style display flag bits (what ifconfig prints in flags=NN<...>). */
#define BF_UP         0x01
#define BF_BROADCAST  0x02
#define BF_RUNNING    0x40

int ifctl(int op, unsigned char *ifr);

static unsigned char ifr[IFR_SIZE];
static char hexd[17] = "0123456789abcdef";
static char macbuf[18];
static char nmbuf[12];
static char flagbuf[48];

static void fmt_mac(void)
{
    int i, j, v;
    j = 0;
    for (i = 0; i < 6; i++) {
        v = ifr[IFR_MAC + i];
        macbuf[j++] = hexd[(v >> 4) & 15];
        macbuf[j++] = hexd[v & 15];
        if (i < 5)
            macbuf[j++] = ':';
    }
    macbuf[j] = 0;
}

/* netmask -> nmbuf as BSD-style "0xffffff00". */
static void fmt_mask(void)
{
    int i, j, v;
    nmbuf[0] = '0';
    nmbuf[1] = 'x';
    j = 2;
    for (i = 0; i < 4; i++) {
        v = ifr[IFR_NETMASK + i];
        nmbuf[j++] = hexd[(v >> 4) & 15];
        nmbuf[j++] = hexd[v & 15];
    }
    nmbuf[j] = 0;
}

/* Build the BSD-style "NN<TOK,...>" flags string from the real IF_Flags byte;
 * return the numeric value.  The W5100 is a broadcast medium; UP/RUNNING track
 * IFF_LINK_UP (card present + link), so a down card no longer reads as up. */
static int render_flags(void)
{
    int f, n;
    unsigned char iff;
    iff = ifr[IFR_FLAGS];
    f = BF_BROADCAST;                     /* W5100 = broadcast medium */
    if (iff & IFF_LINK_UP)
        f = f | BF_UP | BF_RUNNING;
    flagbuf[0] = 0;
    n = 0;
    if (f & BF_UP)        { if (n) strcat(flagbuf, ","); strcat(flagbuf, "UP");        n = 1; }
    if (f & BF_BROADCAST) { if (n) strcat(flagbuf, ","); strcat(flagbuf, "BROADCAST"); n = 1; }
    if (f & BF_RUNNING)   { if (n) strcat(flagbuf, ","); strcat(flagbuf, "RUNNING");   n = 1; }
    return f;
}

/* BSD ifconfig layout: name + flags, offload options, then ether / inet. */
static void show(void)
{
    int f;
    f = render_flags();
    fmt_mac();
    printf("%s: flags=%d<%s>\n", ifr, f, flagbuf);
    /* W5100 hardware TCP/IP offload — a static property of the chip (there is
     * no runtime cap mask; OFFLOAD_* is defined-only).  Honest token set: the
     * card does IPv4/ARP/TCP/UDP and their checksums; inbound ICMP echo too.
     * The options=<> framing already means "offloaded"; keep it under 80 cols. */
    printf("        options=<TCP4,UDP4,ICMP4,ARP,CSUM_IP,CSUM_TCP,CSUM_UDP>\n");
    printf("        ether %s\n", macbuf);
    if (ifr[IFR_FLAGS] & IFF_IP_CONF) {
        fmt_mask();
        printf("        inet %u.%u.%u.%u netmask %s broadcast %u.%u.%u.%u\n",
               ifr[IFR_IP], ifr[IFR_IP+1], ifr[IFR_IP+2], ifr[IFR_IP+3],
               nmbuf,
               ifr[IFR_BROADCAST], ifr[IFR_BROADCAST+1],
               ifr[IFR_BROADCAST+2], ifr[IFR_BROADCAST+3]);
        if (ifr[IFR_FLAGS] & IFF_DHCP)
            printf("        status: active (dhcp lease)\n");
    }
}

/* Parse a dotted-quad "A.B.C.D" from s into ifr[off..off+3]. */
static void parse_ip(char *s, int off)
{
    int i, v;
    for (i = 0; i < 4; i++) {
        v = 0;
        while (*s >= '0' && *s <= '9') {
            v = v * 10 + (*s - '0');
            s++;
        }
        ifr[off + i] = v;
        if (*s == '.')
            s++;
    }
}

int main(int argc, char **argv)
{
    int i, k;

    /* no args, or "-a": list every interface (BSD `ifconfig -a`). */
    if (argc < 2 || (argv[1][0] == '-' && argv[1][1] == 'a' && argv[1][2] == 0)) {
        for (i = 0; i < 4; i++) {
            ifr[IFR_SLOT] = i;
            if (ifctl(IFC_GETN, ifr) != 0)
                break;
            show();
        }
        return 0;
    }

    for (k = 0; k < 7 && argv[1][k]; k++)
        ifr[IFR_NAME + k] = argv[1][k];
    ifr[IFR_NAME + k] = 0;

    if (ifctl(IFC_GET, ifr) != 0) {
        printf("ifconfig: %s: no such interface\n", argv[1]);
        return 1;
    }

    if (argc >= 3) {
        /* GET above loaded the record (name/mac/current IP) so unset fields
         * are preserved; now parse the inet/netmask/broadcast args.  Keywords
         * have unique first letters: i/n/b. */
        i = 2;
        while (i < argc) {
            if (i + 1 < argc && argv[i][0] == 'i') {
                parse_ip(argv[i + 1], IFR_IP);
                i += 2;
            } else if (i + 1 < argc && argv[i][0] == 'n') {
                parse_ip(argv[i + 1], IFR_NETMASK);
                i += 2;
            } else if (i + 1 < argc && argv[i][0] == 'b') {
                parse_ip(argv[i + 1], IFR_BROADCAST);
                i += 2;
            } else {
                i++;
            }
        }
        if (ifctl(IFC_SET, ifr) != 0) {
            printf("ifconfig: %s: set failed\n", argv[1]);
            return 1;
        }
        ifctl(IFC_GET, ifr);    /* re-read to display the result */
    }

    show();
    return 0;
}
