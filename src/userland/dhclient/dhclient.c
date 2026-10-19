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
 * TLV option parsing, then assigns ip/netmask/broadcast/gateway via
 * SYS_IFCONFIG (the c_ifctl shim) and writes /etc/resolv.conf.
 *
 * Resolver config precedence (highest wins): -d/-n flags > /etc/dhclient.conf
 * (`domain`/`search`/`nameserver` lines) > DHCP (opt6 dns, opt15 domain).  So a
 * LAN with no DHCP search option can still get one from the conf file or the
 * command line, and a bad DHCP nameserver can be superseded locally.
 *
 * Lease persistence (RFC 2131 INIT-REBOOT): on bind we write the IP to
 * /etc/dhcp.lease; on the next boot, if that file exists, we re-REQUEST the
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
#include "../lib/socket_h.h"

/* --- ifreq raw layout (mirrors include/ifnet.s IF_*; see ifconfig.c). --- */
#define IFR_SIZE      32
#define IFR_NAME       0      /* 8  NUL-padded                 */
#define IFR_MAC        9      /* 6                             */
#define IFR_IP        16      /* 4                             */
#define IFR_NETMASK   20      /* 4                             */
#define IFR_BROADCAST 24      /* 4                             */
#define IFR_GATEWAY   28      /* 4                             */
#define IFR_SLOT       8      /* index byte (also the IFC_GETN index) */
#define IFC_GETN       0      /* by index -> fill the record   */
#define IFC_GET        1      /* by name -> fill the record    */
#define IFC_SET        2      /* by name -> set ip/nm/bc/gw    */
#define IFC_SETDHCP    4      /* as IFC_SET + mark IFF_DHCP    */

int ifctl(int op, unsigned char *ifr);
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

static unsigned char ifr[IFR_SIZE];
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
static char lbuf[24];                       /* lease-file read buffer */

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
        pkt[28 + i] = ifr[IFR_MAC + i];
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
    int n;
    f = fopen("/etc/dhcp.lease", "r");
    if (f == 0) return 0;
    n = fread(lbuf, 1, 23, f);
    fclose(f);
    if (n <= 0) return 0;
    lbuf[n] = 0;
    return parse_quad(lbuf, saved);
}

/* persist the current lease (yip) to /etc/dhcp.lease for next boot. */
static void write_lease(void)
{
    FILE *f;
    f = fopen("/etc/dhcp.lease", "w");
    if (f == 0) return;
    fprintf(f, "%u.%u.%u.%u\n", yip[0], yip[1], yip[2], yip[3]);
    fclose(f);
}

/* Poll recvfrom until a DHCP reply of want_type with our xid arrives, or
 * timeout_sec elapses.  Returns the datagram length (in rx) or 0 on timeout. */
static int wait_reply(int s, int want_type, int timeout_sec)
{
    unsigned int start, now, limit;
    int n, mt, fromlen;
    start = ticks();
    limit = timeout_sec * 60;
    while (1) {
        now = ticks();
        if ((unsigned int)(now - start) >= limit)
            return 0;
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

    /* load the interface record -> our MAC (chaddr). */
    if (ifn != 0) {
        /* explicit interface name */
        for (i = 0; i < 7 && ifn[i]; i++)
            ifr[IFR_NAME + i] = ifn[i];
        ifr[IFR_NAME + i] = 0;
        if (ifctl(IFC_GET, ifr) != 0) {
            printf("dhclient: %s: no such interface\n", ifn);
            return 1;
        }
    } else {
        /* no arg: use the primary (first registered) interface, whatever slot */
        ifr[IFR_SLOT] = 0;
        if (ifctl(IFC_GETN, ifr) != 0) {
            printf("dhclient: no network interface\n");
            return 1;
        }
        ifn = (char *)ifr;     /* IFR_NAME == 0; record name (NUL-padded) for logs */
    }

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

    /* assign: refresh the record, then set ip/netmask/broadcast/gateway. */
    ifctl(IFC_GET, ifr);
    for (i = 0; i < 4; i++) {
        ifr[IFR_IP + i] = yip[i];
        ifr[IFR_NETMASK + i] = mask[i];
        ifr[IFR_BROADCAST + i] = yip[i] | (mask[i] ^ 0xff);   /* ip | ~mask */
        ifr[IFR_GATEWAY + i] = gw[i];
    }
    /* IFC_SETDHCP, not IFC_SET: it applies the same IP fields but also marks
     * IFF_DHCP, which is what lets `ifconfig` report the address as a lease
     * rather than a hand-config.  Both ops went through IFC_SET before, so the
     * kernel could not tell them apart and IFF_DHCP was never set by anything. */
    if (ifctl(IFC_SETDHCP, ifr) != 0) {
        printf("dhclient: assign failed\n");
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
