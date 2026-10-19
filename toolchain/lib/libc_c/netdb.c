/* ---- the resolver: gethostbyname(3), gethostbyaddr(3), getservbyname(3) ---
 * 2.11BSD keeps these in libc (lib/libc/net, lib/libc/net/named).  FGX's is
 * its own, smaller than upstream's res_*: /etc/hosts first, then one DNS
 * query over UDP to the nameserver in /etc/resolv.conf, and /etc/services.
 * See docs/history/plans/2026-07-20-dns-resolver-scoping.md.
 */

/* libc primitives the resolver calls.  A FILE* is a far char* on FGX, so
 * these are declared with that convention rather than <stdio.h>'s FILE. */
extern char *fopen(char *path, char *mode);
extern char *fgets(char *s, int size, char *fp);
extern int   fclose(char *fp);
extern int   sprintf(char *buf, char *fmt, ...);
extern int   nanosleep(int ticks);
extern int   close(int fd);
extern int   socket(int domain, int type, int proto);
extern int   sendto(int s, char *buf, int len, int flags, char *to, int tolen);
extern int   recvfrom(int s, char *buf, int maxlen, int flags, char *from, int fromlen);

/* ---- resolver: gethostbyname/gethostbyaddr -------------------------------
 * Slim, FGX-shaped: /etc/hosts first, then a single DNS A (or PTR) query over
 * UDP to the nameserver in /etc/resolv.conf (written by dhclient).  The DNS
 * packet is laid out by BYTE OFFSET — no bitfield HEADER struct (fcc has none).
 * See docs/history/plans/2026-07-20-dns-resolver-scoping.md. */

int h_errno = 0;

/* case-insensitive equality of two NUL-terminated strings (hostnames). */
static int _ci_eq(char *a, char *b)
{
    int ca, cb;
    for (;;) {
        ca = *a & 0xFF; cb = *b & 0xFF;
        if (ca >= 'A' && ca <= 'Z') ca += 32;
        if (cb >= 'A' && cb <= 'Z') cb += 32;
        if (ca != cb) return 0;
        if (ca == 0) return 1;
        a++; b++;
    }
}

/* Fill the single static hostent (non-reentrant — matches BSD gethostbyname). */
static struct hostent *_fill_he(char *name, unsigned char *ip4)
{
    static struct hostent he;
    static char namebuf[256];
    static unsigned char addr[4];
    static char *addr_list[2];
    static char *aliases[1];
    int i;

    for (i = 0; name[i] && i < 255; i++) namebuf[i] = name[i];
    namebuf[i] = 0;
    for (i = 0; i < 4; i++) addr[i] = ip4[i];
    addr_list[0] = (char *)addr;
    addr_list[1] = 0;
    aliases[0]   = 0;
    he.h_name      = namebuf;
    he.h_aliases   = aliases;
    he.h_addrtype  = AF_INET;
    he.h_length    = 4;
    he.h_addr_list = addr_list;
    return &he;
}

/* dotted-quad string -> 4 network-order bytes.  0 on malformed. */
static int _parse_ip4(char *s, unsigned char *ip4)
{
    u_long v = inet_addr(s);
    if (v == (u_long)-1) return 0;
    ip4[0] = (unsigned char)(v & 0xFF);
    ip4[1] = (unsigned char)((v >> 8) & 0xFF);
    ip4[2] = (unsigned char)((v >> 16) & 0xFF);
    ip4[3] = (unsigned char)((v >> 24) & 0xFF);
    return 1;
}

/* /etc/hosts scan ("a.b.c.d  name [alias ...]").  Forward when name != 0 (match
 * name/alias -> ip4); reverse when name == 0 (match ip4 -> out_name, first
 * hostname).  1 on hit.  One parser serves both directions (code-size). */
static int _hosts_scan(char *name, unsigned char *ip4, char *out_name)
{
    char *f = fopen("/etc/hosts", "r");
    char line[160];
    char *p, *ipstr, *tok;
    unsigned char lip[4];
    int i;

    if (f == (char *)0) return 0;
    while (fgets(line, sizeof line, f) != (char *)0) {
        p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#' || *p == '\n' || *p == '\r' || *p == 0) continue;
        ipstr = p;
        while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\r') p++;
        if (*p) *p++ = 0;
        if (!_parse_ip4(ipstr, lip)) continue;
        if (name == (char *)0) {                        /* reverse: match the ip */
            if (lip[0]==ip4[0] && lip[1]==ip4[1] && lip[2]==ip4[2] && lip[3]==ip4[3]) {
                while (*p == ' ' || *p == '\t') p++;
                tok = p;
                while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\r') p++;
                *p = 0;
                if (tok[0]) { for (i=0; tok[i] && i<255; i++) out_name[i]=tok[i];
                              out_name[i]=0; fclose(f); return 1; }
            }
            continue;
        }
        while (*p) {                                    /* forward: match name/alias */
            while (*p == ' ' || *p == '\t') p++;
            if (*p == '\n' || *p == '\r' || *p == 0 || *p == '#') break;
            tok = p;
            while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\r') p++;
            if (*p) *p++ = 0;
            if (_ci_eq(tok, name)) {
                ip4[0]=lip[0]; ip4[1]=lip[1]; ip4[2]=lip[2]; ip4[3]=lip[3];
                fclose(f); return 1;
            }
        }
    }
    fclose(f);
    return 0;
}

/* Search list from resolv.conf's "search"/"domain" directive (space-separated
 * domains), captured by _nameserver in the same scan gethostbyname appends. */
static char _resolv_search[128];

/* Parse /etc/resolv.conf: first "nameserver a.b.c.d" -> ns4 (return 1), and
 * stash the first "search <d..>" / "domain <d>" list in _resolv_search. */
static int _nameserver(unsigned char *ns4)
{
    char *f = fopen("/etc/resolv.conf", "r");
    char line[128];
    char *p, *e;
    int got = 0, i;

    _resolv_search[0] = 0;
    if (f == (char *)0) return 0;
    while (fgets(line, sizeof line, f) != (char *)0) {
        p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#') continue;
        if (!got && strncmp(p, "nameserver", 10) == 0) {
            p += 10;
            while (*p == ' ' || *p == '\t') p++;
            e = p;
            while (*e && *e != '\n' && *e != '\r' && *e != ' ' && *e != '\t') e++;
            *e = 0;
            if (_parse_ip4(p, ns4)) got = 1;
            continue;
        }
        if (_resolv_search[0] == 0 &&
            (strncmp(p, "search", 6) == 0 || strncmp(p, "domain", 6) == 0) &&
            (p[6] == ' ' || p[6] == '\t')) {                /* keyword is a word */
            p += 6;
            while (*p == ' ' || *p == '\t') p++;
            for (i = 0; p[i] && p[i] != '\n' && p[i] != '\r' && i < 126; i++)
                _resolv_search[i] = p[i];
            _resolv_search[i] = 0;
        }
    }
    fclose(f);
    return got;
}

/* Encode "www.x.com" -> length-prefixed labels + root 0.  Bytes written, or -1. */
static int _enc_qname(char *name, unsigned char *out)
{
    int i = 0, o = 0, start, l, k;

    while (name[i]) {
        start = i; l = 0;
        while (name[i] && name[i] != '.') { i++; l++; }
        if (l == 0 || l > 63) return -1;               /* empty / over-long label */
        out[o++] = (unsigned char)l;
        for (k = 0; k < l; k++) out[o++] = name[start + k];
        if (name[i] == '.') i++;
    }
    out[o++] = 0;                                       /* root label */
    return o;
}

/* Skip a (possibly compressed) name; return the offset just past it, or -1. */
static int _skip_name(unsigned char *p, int off, int len)
{
    while (off < len) {
        int c = p[off];
        if (c == 0) return off + 1;
        if ((c & INDIR_MASK) == INDIR_MASK) return off + 2;   /* pointer ends name */
        off += 1 + c;
    }
    return -1;
}

/* Decode a (possibly compressed) name at off into out (dotted). */
static void _dec_name(unsigned char *p, int off, int len, char *out)
{
    int o = 0, guard = 0, c, k;

    while (off >= 0 && off < len && (c = p[off]) != 0 && guard++ < 128) {
        if ((c & INDIR_MASK) == INDIR_MASK) {           /* compression pointer */
            off = ((c & 0x3F) << 8) | p[off + 1];
            continue;
        }
        off++;
        if (o && o < 254) out[o++] = '.';
        for (k = 0; k < c && off < len && o < 254; k++) out[o++] = p[off++];
    }
    out[o] = 0;
}

/* Parse a response for the first IN/qtype answer.  1=found, 0=none, -1=bad. */
static int _parse_resp(unsigned char *p, int len, int qtype, int id,
                       unsigned char *ip4, char *out_name)
{
    int qd, an, off, i, type, cls, rdlen;

    if (len < HFIXEDSZ) return -1;
    if (((p[0] << 8) | p[1]) != id) return -1;          /* id mismatch */
    if (p[3] & 0x0F) return -1;                          /* RCODE != 0 */
    qd = (p[4] << 8) | p[5];
    an = (p[6] << 8) | p[7];
    if (an <= 0) return 0;
    off = HFIXEDSZ;
    for (i = 0; i < qd; i++) {                           /* skip questions */
        off = _skip_name(p, off, len);
        if (off < 0) return -1;
        off += QFIXEDSZ;
    }
    for (i = 0; i < an; i++) {                           /* walk answers */
        off = _skip_name(p, off, len);
        if (off < 0 || off + 10 > len) return -1;
        type  = (p[off] << 8) | p[off + 1];
        cls   = (p[off + 2] << 8) | p[off + 3];
        rdlen = (p[off + 8] << 8) | p[off + 9];          /* ttl @ off+4..7 */
        off  += 10;
        if (off + rdlen > len) return -1;
        if (cls == C_IN && type == qtype) {
            if (qtype == T_A && rdlen == 4) {
                ip4[0]=p[off]; ip4[1]=p[off+1]; ip4[2]=p[off+2]; ip4[3]=p[off+3];
                return 1;
            }
            if (qtype == T_PTR && out_name) { _dec_name(p, off, len, out_name); return 1; }
        }
        off += rdlen;                                    /* CNAMEs skipped; an A
                                                          * later in the answer
                                                          * still matches (no
                                                          * explicit chase) */
    }
    return 0;
}

/* Send a DNS query (qtype A or PTR) for qname, poll for the reply.  1 on hit. */
static int _dns_resolve(int qtype, char *qname, unsigned char *ip4, char *out_name)
{
    static int seq = 0x4321;
    static unsigned char query[300], resp[PACKETSZ];   /* off the small bank-0 stack */
    unsigned char ns[4], sa[16], from[16];
    int off, n, qlen, id, s, tries, poll, rc;

    if (!_nameserver(ns)) return 0;

    id = (++seq) & 0xFFFF;
    query[0] = (id >> 8) & 0xFF; query[1] = id & 0xFF;
    query[2] = DNS_RD; query[3] = 0;                     /* flags: recursion desired */
    query[4] = 0; query[5] = 1;                          /* QDCOUNT = 1 */
    query[6]=0; query[7]=0; query[8]=0; query[9]=0; query[10]=0; query[11]=0;
    off = HFIXEDSZ;
    n = _enc_qname(qname, &query[off]);
    if (n < 0) return 0;
    off += n;
    query[off++] = (qtype >> 8) & 0xFF; query[off++] = qtype & 0xFF;   /* QTYPE */
    query[off++] = 0; query[off++] = C_IN;                            /* QCLASS IN */
    qlen = off;

    for (n = 0; n < 16; n++) sa[n] = 0;
    sa[1] = AF_INET;                                     /* family; sendto reads
                                                          * only port@2 + addr@4 */
    sa[2] = 0; sa[3] = 53;                               /* :53 network order */
    sa[4]=ns[0]; sa[5]=ns[1]; sa[6]=ns[2]; sa[7]=ns[3];

    s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) return 0;

    for (tries = 0; tries < 3; tries++) {                /* 3 sends, ~1.5s each */
        sendto(s, (char *)query, qlen, 0, (char *)sa, 16);
        for (poll = 0; poll < 90; poll++) {
            n = recvfrom(s, (char *)resp, PACKETSZ, 0, (char *)from, 16);
            if (n >= HFIXEDSZ) {
                if (resp[2] & DNS_TC) { close(s); return 0; }   /* truncated: no TCP */
                rc = _parse_resp(resp, n, qtype, id, ip4, out_name);
                if (rc == 1) { close(s); return 1; }
                /* rc 0/-1: not our answer / malformed -> keep polling, then retry */
            }
            nanosleep(1);                                /* ~1 tick between polls */
        }
    }
    close(s);
    return 0;
}

/* gethostbyname — /etc/hosts, then a DNS A query for the name as given, then
 * (for an unqualified name) the name with each resolv.conf search/domain
 * appended (`host www` -> `www.example.com`).  NULL + h_errno on failure; a
 * dotted-quad name resolves to itself (BSD convenience). */
struct hostent *gethostbyname(char *name)
{
    static unsigned char ip4[4];
    static char fqdn[256];
    unsigned char ns[4];
    int i, j, has_dot;

    if (_hosts_scan(name, ip4, (char *)0)) return _fill_he(name, ip4);
    if (_parse_ip4(name, ip4))             return _fill_he(name, ip4);

    _nameserver(ns);                       /* populate _resolv_search (ns unused here) */
    has_dot = 0;
    for (i = 0; name[i]; i++) if (name[i] == '.') { has_dot = 1; break; }

    /* Qualified name (has a dot): try it as given first. */
    if (has_dot && _dns_resolve(T_A, name, ip4, (char *)0)) return _fill_he(name, ip4);

    /* Append the search/domain and try: name "." domain.  For an unqualified
     * name this is tried BEFORE the bare name (BSD ndots) so `host www` becomes
     * `www.example.com` without a doomed single-label query first. */
    if (_resolv_search[0]) {
        for (i = 0; name[i] && i < 200; i++) fqdn[i] = name[i];
        fqdn[i++] = '.';
        for (j = 0; _resolv_search[j] > ' ' && i < 254; j++) fqdn[i++] = _resolv_search[j];
        fqdn[i] = 0;
        if (_dns_resolve(T_A, fqdn, ip4, (char *)0)) return _fill_he(fqdn, ip4);
    }

    /* Unqualified name with no search hit: bare query as a last resort. */
    if (!has_dot && _dns_resolve(T_A, name, ip4, (char *)0)) return _fill_he(name, ip4);

    h_errno = HOST_NOT_FOUND;
    return (struct hostent *)0;
}

/* gethostbyaddr — reverse: /etc/hosts, then a DNS PTR query.  addr = 4 net-order
 * bytes.  The returned hostent's address is the queried addr. */
struct hostent *gethostbyaddr(char *addr, int len, int type)
{
    static char namebuf[256];                  /* off the small bank-0 stack */
    unsigned char *a = (unsigned char *)addr;
    unsigned char dummy[4];
    char qname[48];

    if (len != 4 || type != AF_INET) { h_errno = NO_RECOVERY; return (struct hostent *)0; }
    if (_hosts_scan((char *)0, a, namebuf)) return _fill_he(namebuf, a);
    sprintf(qname, "%d.%d.%d.%d.in-addr.arpa", a[3], a[2], a[1], a[0]);
    if (_dns_resolve(T_PTR, qname, dummy, namebuf)) return _fill_he(namebuf, a);
    h_errno = HOST_NOT_FOUND;
    return (struct hostent *)0;
}

/* /etc/services reader: "name  port/proto  [aliases]".  Match name-or-alias, and
 * proto if one is given.  Returns 1 with the host-order port + canonical name. */
static int _services_lookup(char *name, char *proto, char *out_name, int *out_port)
{
    char *f = fopen("/etc/services", "r");
    char line[160];
    char *p, *nm, *portstr, *protostr, *tok;
    int matched, v, k, i;

    if (f == (char *)0) return 0;
    while (fgets(line, sizeof line, f) != (char *)0) {
        p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#' || *p == '\n' || *p == '\r' || *p == 0) continue;
        nm = p;                                          /* official name */
        while (*p && *p != ' ' && *p != '\t') p++;
        if (*p) *p++ = 0;
        while (*p == ' ' || *p == '\t') p++;
        portstr = p;                                     /* port/proto token */
        while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\r') p++;
        if (*p) *p++ = 0;
        protostr = portstr;
        while (*protostr && *protostr != '/') protostr++;
        if (*protostr != '/') continue;                  /* malformed */
        *protostr++ = 0;                                 /* portstr=port, protostr=proto */
        if (proto && proto[0] && !_ci_eq(protostr, proto)) continue;   /* proto mismatch */
        matched = _ci_eq(nm, name);
        if (!matched) {                                  /* try aliases */
            while (*p) {
                while (*p == ' ' || *p == '\t') p++;
                if (*p == '\n' || *p == '\r' || *p == 0 || *p == '#') break;
                tok = p;
                while (*p && *p != ' ' && *p != '\t' && *p != '\n' && *p != '\r') p++;
                if (*p) *p++ = 0;
                if (_ci_eq(tok, name)) { matched = 1; break; }
            }
        }
        if (matched) {
            v = 0; k = 0;
            while (portstr[k] >= '0' && portstr[k] <= '9') { v = v * 10 + (portstr[k] - '0'); k++; }
            *out_port = v;
            for (i = 0; nm[i] && i < 63; i++) out_name[i] = nm[i];
            out_name[i] = 0;
            fclose(f); return 1;
        }
    }
    fclose(f);
    return 0;
}

/* getservbyname(name, proto) — resolve a service via /etc/services (shipped on
 * every disk).  Static servent, s_port in NETWORK order; NULL if unknown. */
struct servent *getservbyname(char *name, char *proto)
{
    static struct servent se;
    static char se_name[64];
    int port;

    if (_services_lookup(name, proto, se_name, &port)) {
        se.s_name    = se_name;
        se.s_aliases = (char **)0;
        se.s_port    = (int)htons(port);
        se.s_proto   = proto;
        return &se;
    }
    return (struct servent *)0;
}
