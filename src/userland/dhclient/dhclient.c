/*
 * dhclient - DHCP client (FGX UDP-sockets v1).
 *
 *   dhclient [-d domain] [-n nameserver] [iface]
 *
 *   -d domain       override the search domain (else DHCP opt15, else none)
 *   -n nameserver   override the DNS server IP (else DHCP opt6)
 *   iface           interface name; default = the primary (first) interface
 *
 * A slim RFC 2131 state machine, more robust than the old kernel boot-time
 * DHCP: DISCOVER -> OFFER -> REQUEST -> ACK with retransmit/backoff, proper
 * TLV option parsing, then sets the interface's netmask, address and
 * broadcast and the default route through the socket ioctls ifconfig(8) and
 * route(8) use (SIOCSIFNETMASK, SIOCSIFADDR, SIOCSIFBRDADDR, SIOCADDRT), and
 * writes /etc/resolv.conf.  The interface and its MAC come from SIOCGIFCONF:
 * the first one with an Ethernet link-level address, or the one named.  One
 * with no address yet is given 0.0.0.0 first, as early BOOTP clients did, so
 * the DISCOVER has an interface to leave by.
 *
 * Resolver config precedence (highest wins): -d/-n flags > /etc/dhclient.conf
 * (`domain`/`search`/`nameserver` lines) > DHCP (opt6 dns, opt15 domain).  So a
 * LAN with no DHCP search option can still get one from the conf file or the
 * command line, and a bad DHCP nameserver can be superseded locally.
 *
 * Lease persistence (RFC 2131 INIT-REBOOT): on bind we write the IP to
 * /etc/dhcp.lease, and the gateway on a second line, so the next lease can
 * delete the default route it added (rtrequest deletes only a route whose
 * gateway matches); on the next boot, if that file exists, we re-REQUEST the
 * same IP (opt50, no server-id, broadcast) before falling back to DISCOVER on
 * NAK/timeout — so a rebooting FGX keeps its address instead of drawing a fresh
 * one from the pool each time.  No background renew daemon yet (that needs
 * multitasking); renew = re-run dhclient.
 *
 * fcc constraints honored: sockaddr_in / ifreq / the DHCP packet are RAW byte
 * arrays with explicit offsets (fcc still even-aligns word members, so no
 * struct matches a packed wire layout even post-B-8); IP octets print via %u
 * (fcc's %02x width is unreliable); the lease is a 32-bit value printed by a
 * local decimal helper (fcc printf has no %lu).  ticks() is a small asm helper
 * (dhclient_ticks.s) over SYS_TICKS — fcc has no inline asm.
 */
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/time.h>             /* select */
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/route.h>
#include <netinet/in.h>
#include <errno.h>

extern int errno;

/* --- a sockaddr_in as raw bytes, for the DHCP sockets. --- */
#define SIN_FAMILY     0       /* 2: AF_INET (short, low byte first)   */
#define SIN_PORT       2       /* 2: port, network order (hi,lo)       */
#define SIN_ADDR       4       /* 4: IPv4 addr, network order          */

int ticks(void);              /* dhclient_ticks.s: lo16 of the 60 Hz counter */

/* --- DHCP constants. --- */
#define DH_DISCOVER   1
#define DH_OFFER      2
#define DH_REQUEST    3
#define DH_ACK        5
#define PORT_SRV      67
#define PORT_CLI      68
#define PKT_MAX      300
#define RX_MAX       600

static char ifname[IFNAMSIZ];               /* the interface's name   */
static unsigned char mac[6];                /* its link-level address */
static unsigned char oldgw[4];              /* the gateway the last lease added */
static int haveoldgw;
static unsigned char pkt[PKT_MAX];          /* TX DHCP/BOOTP message */
static unsigned char rx[RX_MAX];            /* RX datagram payload   */
static unsigned char sa_srv[16];            /* 255.255.255.255:67    */
static unsigned char sa_loc[16];            /* 0.0.0.0:68            */
static unsigned char sa_from[16];           /* recvfrom source       */
static unsigned char xid[4];                /* our transaction id    */
static unsigned char optbuf[8];             /* parse_opt scratch     */
static unsigned char yip[4];                /* yiaddr (leased IP)    */
static unsigned char srv[4];                /* server id (opt54)     */
static unsigned char mask[4];               /* opt1 netmask          */
static unsigned char gw[4];                 /* opt3 router           */
static unsigned char dns[4];                /* opt6 dns              */
static char domain[64];                     /* opt15 / conf / -d search domain */
static char confline[96];                   /* /etc/dhclient.conf line buffer  */
static unsigned long lease;                 /* opt51 lease seconds   */
static char decbuf[12];                     /* u32 -> decimal        */
static unsigned char saved[4];              /* lease read from /etc/dhcp.lease */
static char lbuf[40];                       /* lease-file read buffer */

/* unsigned-long -> decimal string in decbuf (fcc printf has no %lu, and no
 * long modulo — extract each digit as v - (v/10)*10). */
static void u32dec(unsigned long v)
{
    int i, n;
    unsigned long q;
    char tmp[11];
    n = 0;
    if (v == 0) { decbuf[0] = '0'; decbuf[1] = 0; return; }
    while (v != 0) {
        q = v / 10;
        tmp[n++] = (char)('0' + (int)(v - q * 10));
        v = q;
    }
    for (i = 0; i < n; i++)
        decbuf[i] = tmp[n - 1 - i];
    decbuf[n] = 0;
}

/* Fill pkt with a DHCP message of the given type; returns its length.
 * add_opt50 appends opt50 (requested IP = yip); add_opt54 appends opt54
 * (server id = srv).  SELECTING REQUEST uses both; INIT-REBOOT uses opt50 only
 * (RFC 2131: no server-id when re-requesting a remembered lease). */
static int build_dhcp(int msgtype, int add_opt50, int add_opt54)
{
    int i, p;
    for (i = 0; i < PKT_MAX; i++)
        pkt[i] = 0;
    pkt[0] = 1;                 /* op = BOOTREQUEST  */
    pkt[1] = 1;                 /* htype = ethernet  */
    pkt[2] = 6;                 /* hlen              */
    pkt[4] = xid[0]; pkt[5] = xid[1]; pkt[6] = xid[2]; pkt[7] = xid[3];
    pkt[10] = 0x80;             /* flags = broadcast */
    for (i = 0; i < 6; i++)     /* chaddr = our MAC  */
        pkt[28 + i] = mac[i];
    pkt[236] = 0x63; pkt[237] = 0x82; pkt[238] = 0x53; pkt[239] = 0x63; /* cookie */
    p = 240;
    pkt[p++] = 53; pkt[p++] = 1; pkt[p++] = msgtype;                    /* opt53 */
    pkt[p++] = 55; pkt[p++] = 4; pkt[p++] = 1; pkt[p++] = 3;            /* opt55 */
    pkt[p++] = 6;  pkt[p++] = 51;
    if (add_opt50) {
        pkt[p++] = 50; pkt[p++] = 4;                                   /* opt50 */
        for (i = 0; i < 4; i++) pkt[p++] = yip[i];
    }
    if (add_opt54) {
        pkt[p++] = 54; pkt[p++] = 4;                                   /* opt54 */
        for (i = 0; i < 4; i++) pkt[p++] = srv[i];
    }
    pkt[p++] = 255;                                                    /* end   */
    return p;
}

/* Walk the TLV options after the magic cookie; copy option `want`'s value into
 * out (<= outlen bytes) and return its length, or 0 if absent. */
static int parse_opt(unsigned char *p, int len, int want, unsigned char *out, int outlen)
{
    int i, code, l, j;
    i = 240;
    while (i < len) {
        code = p[i];
        if (code == 255) break;
        if (code == 0) { i++; continue; }
        l = p[i + 1];
        if (code == want) {
            for (j = 0; j < l && j < outlen; j++)
                out[j] = p[i + 2 + j];
            return l;
        }
        i += 2 + l;
    }
    return 0;
}

/* parse the "a.b.c.d" prefix of s into out[0..3]; return 1 if 4 octets parse. */
static int parse_quad(char *s, unsigned char *out)
{
    int i, v, nd;
    i = 0;
    while (i < 4) {
        v = 0;
        nd = 0;
        while (*s >= '0' && *s <= '9') {
            v = v * 10 + (*s - '0');
            s = s + 1;
            nd = nd + 1;
        }
        if (nd == 0 || v > 255) return 0;
        out[i] = v;
        i = i + 1;
        if (i < 4) {
            if (*s != '.') return 0;
            s = s + 1;
        }
    }
    return 1;                    /* 4 octets parsed; ignore trailing \n/space */
}

/* read /etc/dhcp.lease -> saved[]; return 1 if a valid IP was read. */
static int read_lease(void)
{
    FILE *f;
    int n, i;
    f = fopen("/etc/dhcp.lease", "r");
    if (f == 0) return 0;
    n = fread(lbuf, 1, sizeof lbuf - 1, f);
    fclose(f);
    if (n <= 0) return 0;
    lbuf[n] = 0;
    for (i = 0; lbuf[i] && lbuf[i] != '\n'; i++)
        ;
    if (lbuf[i] == '\n')
        haveoldgw = parse_quad(&lbuf[i + 1], oldgw);
    return parse_quad(lbuf, saved);
}

/* persist the current lease (yip) to /etc/dhcp.lease for next boot. */
static void write_lease(void)
{
    FILE *f;
    f = fopen("/etc/dhcp.lease", "w");
    if (f == 0) return;
    fprintf(f, "%u.%u.%u.%u\n", yip[0], yip[1], yip[2], yip[3]);
    if (gw[0] | gw[1] | gw[2] | gw[3])
        fprintf(f, "%u.%u.%u.%u\n", gw[0], gw[1], gw[2], gw[3]);
    fclose(f);
}

/* Wait for a DHCP reply of want_type with our xid, or for timeout_sec to
 * elapse.  Returns the datagram length (in rx) or 0 on timeout.  A UDP receive
 * blocks until a datagram arrives, so the wait is select's, with what is left
 * of the timeout, and recvfrom runs only when one is there. */
static int wait_reply(int s, int want_type, int timeout_sec)
{
    unsigned int start, now, limit, left;
    int n, mt, fromlen;
    fd_set rd;
    struct timeval tv;
    start = ticks();
    limit = timeout_sec * 60;
    while (1) {
        now = ticks();
        if ((unsigned int)(now - start) >= limit)
            return 0;
        left = limit - (unsigned int)(now - start);
        FD_ZERO(&rd);
        FD_SET(s, &rd);
        tv.tv_sec = left / 60;
        tv.tv_usec = (long)(left % 60) * 16667L;
        if (select(s + 1, &rd, (fd_set *)0, (fd_set *)0, &tv) <= 0)
            continue;
        fromlen = sizeof sa_from;
        n = recvfrom(s, rx, RX_MAX, 0, sa_from, &fromlen);
        if (n > 240 &&
            rx[4] == xid[0] && rx[5] == xid[1] &&
            rx[6] == xid[2] && rx[7] == xid[3]) {
            mt = 0;
            if (parse_opt(rx, n, 53, optbuf, 8) >= 1)
                mt = optbuf[0];
            if (mt == want_type)
                return n;
        }
    }
}

/* if line p begins with keyword kw followed by space/tab, return a pointer to
 * the first non-blank after it; else 0. */
static char *kwarg(char *p, char *kw)
{
    int i;
    for (i = 0; kw[i]; i++)
        if (p[i] != kw[i]) return 0;
    if (p[i] != ' ' && p[i] != '\t') return 0;
    p = p + i;
    while (*p == ' ' || *p == '\t') p = p + 1;
    return p;
}

/* copy the whitespace/newline-delimited token at s into out (<= max-1), NUL-term. */
static void token(char *s, char *out, int max)
{
    int i;
    for (i = 0; i < max - 1 && s[i] && s[i] != ' ' && s[i] != '\t' &&
                s[i] != '\n' && s[i] != '\r'; i++)
        out[i] = s[i];
    out[i] = 0;
}

/* /etc/dhclient.conf overrides the DHCP-provided resolver config.  Recognized
 * lines: `domain X` / `search X` -> domain[]; `nameserver a.b.c.d` -> dns[].
 * Blank lines and `#' comments are ignored. */
static void read_conf(void)
{
    FILE *f;
    char *p, *v;
    f = fopen("/etc/dhclient.conf", "r");
    if (f == 0)
        return;
    while (fgets(confline, 96, f)) {
        p = confline;
        while (*p == ' ' || *p == '\t') p = p + 1;
        if (*p == '#' || *p == '\n' || *p == '\r' || *p == 0) continue;
        if ((v = kwarg(p, "domain")) != 0)          token(v, domain, 64);
        else if ((v = kwarg(p, "search")) != 0)     token(v, domain, 64);
        else if ((v = kwarg(p, "nameserver")) != 0) parse_quad(v, dns);
    }
    fclose(f);
}

static void write_resolv(void)
{
    FILE *f;
    f = fopen("/etc/resolv.conf", "w");
    if (f == 0)
        return;
    fprintf(f, "nameserver %u.%u.%u.%u\n", dns[0], dns[1], dns[2], dns[3]);
    if (domain[0])
        fprintf(f, "search %s\n", domain);
    fclose(f);
}

/* The interface to use: the one named, or the first with an Ethernet
 * link-level address, from SIOCGIFCONF's AF_LINK entries (<net/if_dl.h>).
 * Fills ifname and mac.  0, or -1 when there is none. */
static char ifcbuf[512];
static int find_if(char *want)
{
    struct ifconf ifc;
    struct ifreq *r;
    struct sockaddr_dl *sdl;
    int s, n, i;

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0)
        return -1;
    ifc.ifc_len = sizeof ifcbuf;
    ifc.ifc_buf = ifcbuf;
    n = ioctl(s, SIOCGIFCONF, (char *)&ifc);
    close(s);
    if (n < 0)
        return -1;
    n = ifc.ifc_len / sizeof (struct ifreq);
    for (r = ifc.ifc_req; n > 0; n--, r++) {
        sdl = (struct sockaddr_dl *)&r->ifr_addr;
        if (sdl->sdl_family != AF_LINK || sdl->sdl_type != IFT_ETHER ||
            sdl->sdl_alen != 6)
            continue;
        if (want != 0 && strncmp(want, r->ifr_name, IFNAMSIZ) != 0)
            continue;
        strncpy(ifname, r->ifr_name, IFNAMSIZ);
        for (i = 0; i < 6; i++)
            mac[i] = LLADDR(sdl)[i];
        return 0;
    }
    return -1;
}

/* One SIOCSIF* address ioctl on ifname: a sockaddr_in from four octets. */
static int setifaddr(int s, int cmd, unsigned char *a)
{
    struct ifreq ifr;
    struct sockaddr_in *sin;

    bzero((char *)&ifr, sizeof ifr);
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
    sin = (struct sockaddr_in *)&ifr.ifr_addr;
    sin->sin_family = AF_INET;
    bcopy((char *)a, (char *)&sin->sin_addr, 4);
    return ioctl(s, cmd, (char *)&ifr);
}

/* The default route through gateway g: SIOCADDRT or SIOCDELRT, as route(8). */
static int defroute(int s, int cmd, unsigned char *g)
{
    struct rtentry rt;
    struct sockaddr_in *sin;

    bzero((char *)&rt, sizeof rt);
    sin = (struct sockaddr_in *)&rt.rt_dst;
    sin->sin_family = AF_INET;
    sin = (struct sockaddr_in *)&rt.rt_gateway;
    sin->sin_family = AF_INET;
    bcopy((char *)g, (char *)&sin->sin_addr, 4);
    rt.rt_flags = RTF_UP | RTF_GATEWAY;
    return ioctl(s, cmd, (char *)&rt);
}

/* An interface with no address yet gets 0.0.0.0, so a DISCOVER to
 * 255.255.255.255 has one to leave by (the kernel routes the broadcast
 * address to it).  One that has an address keeps it until the lease. */
static void ensure_addr(int s)
{
    struct ifreq ifr;
    static unsigned char zero[4];

    bzero((char *)&ifr, sizeof ifr);
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
    if (ioctl(s, SIOCGIFADDR, (char *)&ifr) < 0)
        (void) setifaddr(s, SIOCSIFADDR, zero);
}

/* The lease, as ifconfig(8) and route(8) would set it: the mask before the
 * address so the address is read with it (ifconfig.c's order), then the
 * broadcast, then the default route, the last lease's deleted first. */
static int assign(int s)
{
    unsigned char brd[4];
    int i;

    for (i = 0; i < 4; i++)
        brd[i] = yip[i] | (mask[i] ^ 0xff);         /* ip | ~mask */
    if (setifaddr(s, SIOCSIFNETMASK, mask) < 0 ||
        setifaddr(s, SIOCSIFADDR, yip) < 0 ||
        setifaddr(s, SIOCSIFBRDADDR, brd) < 0)
        return -1;
    if (haveoldgw)
        (void) defroute(s, SIOCDELRT, oldgw);
    if ((gw[0] | gw[1] | gw[2] | gw[3]) &&
        defroute(s, SIOCADDRT, gw) < 0 && errno != EEXIST)
        return -1;
    return 0;
}

int main(int argc, char **argv)
{
    int s, i, tries, to, n, got, havesaved, on;
    unsigned int t0;
    char *ifn, *cli_dom, *cli_ns;

    /* args: [-d domain] [-n nameserver] [iface] (flags in any order). */
    ifn = 0; cli_dom = 0; cli_ns = 0;
    for (i = 1; i < argc; i++) {
        if (argv[i][0] == '-' && argv[i][1] == 'd' && argv[i][2] == 0 && i + 1 < argc)
            cli_dom = argv[++i];
        else if (argv[i][0] == '-' && argv[i][1] == 'n' && argv[i][2] == 0 && i + 1 < argc)
            cli_ns = argv[++i];
        else
            ifn = argv[i];
    }

    /* the interface and our MAC (chaddr): its AF_LINK entry. */
    if (find_if(ifn) != 0) {
        if (ifn != 0)
            printf("dhclient: %s: no such interface\n", ifn);
        else
            printf("dhclient: no network interface\n");
        return 1;
    }
    ifn = ifname;

    /* xid: fixed prefix + a ticks-derived suffix so retries reuse one xid. */
    t0 = ticks();
    xid[0] = 0x3d; xid[1] = 0xf6;
    xid[2] = (t0 >> 8) & 0xff; xid[3] = t0 & 0xff;

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) {
        printf("dhclient: socket failed\n");
        return 1;
    }
    /* every DISCOVER and REQUEST goes to 255.255.255.255, which sendto
     * refuses unless SO_BROADCAST is on.  The value sets or clears it. */
    on = 1;
    if (setsockopt(s, SOL_SOCKET, SO_BROADCAST, (char *)&on, sizeof(on)) < 0) {
        printf("dhclient: setsockopt SO_BROADCAST failed\n");
        close(s);
        return 1;
    }
    ensure_addr(s);

    for (i = 0; i < 16; i++) sa_loc[i] = 0;
    sa_loc[SIN_FAMILY] = AF_INET;
    sa_loc[SIN_PORT + 1] = PORT_CLI;           /* :68 (port hi = 0) */
    if (bind(s, sa_loc, 16) != 0) {
        printf("dhclient: bind :68 failed\n");
        close(s);
        return 1;
    }

    for (i = 0; i < 16; i++) sa_srv[i] = 0;
    sa_srv[SIN_FAMILY] = AF_INET;
    sa_srv[SIN_PORT + 1] = PORT_SRV;           /* :67 */
    sa_srv[SIN_ADDR] = 255; sa_srv[SIN_ADDR + 1] = 255;
    sa_srv[SIN_ADDR + 2] = 255; sa_srv[SIN_ADDR + 3] = 255;

    /* INIT-REBOOT: if a lease is remembered, re-REQUEST that exact IP
     * (opt50, no server-id, broadcast).  ACK -> reuse; NAK/timeout -> DISCOVER. */
    got = 0;
    havesaved = read_lease();
    if (havesaved) {
        for (i = 0; i < 4; i++) yip[i] = saved[i];
        to = 2;
        for (tries = 0; tries < 2; tries++) {
            n = build_dhcp(DH_REQUEST, 1, 0);
            sendto(s, pkt, n, 0, sa_srv, 16);
            if (wait_reply(s, DH_ACK, to)) { got = 1; break; }
            to = to * 2;
        }
        if (got)
            printf("%s: re-requesting lease %u.%u.%u.%u\n",
                   ifn, saved[0], saved[1], saved[2], saved[3]);
    }

    if (!got) {
        /* DISCOVER -> OFFER, backoff 2/4/8/16 s.  If a lease is remembered,
         * hint it via opt50 (yip still = saved) so a server that ignores the
         * INIT-REBOOT REQUEST may still offer the same IP. */
        to = 2;
        for (tries = 0; tries < 4; tries++) {
            n = build_dhcp(DH_DISCOVER, havesaved, 0);
            sendto(s, pkt, n, 0, sa_srv, 16);
            if (wait_reply(s, DH_OFFER, to))
                break;
            to = to * 2;
        }
        if (tries >= 4) {
            printf("dhclient: no DHCPOFFER\n");
            close(s);
            return 1;
        }
        for (i = 0; i < 4; i++) yip[i] = rx[16 + i];      /* yiaddr  */
        if (parse_opt(rx, RX_MAX, 54, optbuf, 8) >= 4)    /* server id */
            for (i = 0; i < 4; i++) srv[i] = optbuf[i];

        /* REQUEST -> ACK, backoff. */
        to = 2;
        for (tries = 0; tries < 4; tries++) {
            n = build_dhcp(DH_REQUEST, 1, 1);
            sendto(s, pkt, n, 0, sa_srv, 16);
            if (wait_reply(s, DH_ACK, to))
                break;
            to = to * 2;
        }
        if (tries >= 4) {
            printf("dhclient: no DHCPACK\n");
            close(s);
            return 1;
        }
    }

    /* parse the ACK. */
    for (i = 0; i < 4; i++) yip[i] = rx[16 + i];
    for (i = 0; i < 4; i++) { mask[i] = 0; gw[i] = 0; dns[i] = 0; }
    parse_opt(rx, RX_MAX, 1, mask, 4);
    parse_opt(rx, RX_MAX, 3, gw, 4);
    parse_opt(rx, RX_MAX, 6, dns, 4);
    domain[0] = 0;
    n = parse_opt(rx, RX_MAX, 15, (unsigned char *)domain, 63);  /* opt15 domain */
    if (n > 63) n = 63;
    domain[n] = 0;
    lease = 0;
    if (parse_opt(rx, RX_MAX, 51, optbuf, 4) >= 4)
        lease = ((unsigned long)optbuf[0] << 24) |
                ((unsigned long)optbuf[1] << 16) |
                ((unsigned long)optbuf[2] << 8) |
                 (unsigned long)optbuf[3];

    /* assign: netmask, address, broadcast, then the default route. */
    if (assign(s) != 0) {
        printf("dhclient: assign failed: errno %d\n", errno);
        close(s);
        return 1;
    }

    /* apply overrides in increasing precedence: conf file, then -d/-n flags. */
    read_conf();
    if (cli_dom != 0) token(cli_dom, domain, 64);
    if (cli_ns != 0)  parse_quad(cli_ns, dns);

    write_resolv();
    write_lease();              /* persist for INIT-REBOOT on next boot */

    u32dec(lease);
    printf("%s: bound to %u.%u.%u.%u -- renewal in %s seconds\n",
           ifn, yip[0], yip[1], yip[2], yip[3], decbuf);
    printf("        gateway %u.%u.%u.%u  dns %u.%u.%u.%u\n",
           gw[0], gw[1], gw[2], gw[3], dns[0], dns[1], dns[2], dns[3]);
    if (domain[0])
        printf("        search %s\n", domain);
    close(s);
    return 0;
}
