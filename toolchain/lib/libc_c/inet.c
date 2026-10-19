/* ---- inet address helpers (2.11BSD arpa/inet.h) --------------------------- */

/* inet_addr(cp) — parse "a.b.c.d" -> network-order address: bytes a,b,c,d land
 * at increasing memory, which on the little-endian 65816 is the u_long value
 * a | b<<8 | c<<16 | d<<24.  Returns (u_long)-1 on malformed input (BSD's classic
 * wart: 255.255.255.255 is indistinguishable from the error). */
u_long inet_addr(char *cp)
{
    unsigned char b[4];
    int part, any, i = 0, k;

    for (k = 0; k < 4; k++) {
        part = 0; any = 0;
        while (cp[i] >= '0' && cp[i] <= '9') { part = part * 10 + (cp[i] - '0'); i++; any = 1; }
        if (!any || part > 255) return (u_long)-1;
        b[k] = (unsigned char)part;
        if (k < 3) { if (cp[i] != '.') return (u_long)-1; i++; }
    }
    if (cp[i] != 0) return (u_long)-1;
    return (u_long)b[0] | ((u_long)b[1] << 8) | ((u_long)b[2] << 16) | ((u_long)b[3] << 24);
}

/* inet_ntoa(in) — network-order addr -> "a.b.c.d" in a static buffer (in.s_addr
 * passed by value: fcc pushes the 4-byte struct like a long). */
char *inet_ntoa(struct in_addr in)
{
    static char buf[18];
    u_long a = in.s_addr;

    sprintf(buf, "%d.%d.%d.%d",
            (int)(a & 255), (int)((a >> 8) & 255),
            (int)((a >> 16) & 255), (int)((a >> 24) & 255));
    return buf;
}


