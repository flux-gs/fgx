/*
 * nc - minimal netcat for the FGX TCP client.
 *   nc <ip> <port>        pipe stdin->socket then socket->stdout (use a redirect
 *                         `nc ip port < file`; an interactive console never EOFs)
 *   nc -g <ip> <port>     send "GET / HTTP/1.0" then print the response (no stdin)
 *
 * Validates connect/send/recv/close + read()/write() on a socket fd.  The
 * target may be a dotted quad or a host name (resolved via /etc/hosts + DNS,
 * gethostbyname).  fcc-compiled (all-tools-in-C); generated nc.s is a
 * gitignored build artifact.
 */
#include <stdio.h>
#include <netdb.h>
#include "../lib/socket_h.h"

/* raw fd read/write (no <unistd.h>); fcc maps to c_read/c_write.  See netdump.c. */
int read(int fd, void *buf, int n);
int write(int fd, void *buf, int n);

static unsigned char sa[SIN_SIZE];
static unsigned char buf[512];
static unsigned char httpget[] = "GET / HTTP/1.0\r\n\r\n";

/* parse "a.b.c.d" into out[4]; 0 ok, -1 malformed. */
static int parse_ip(char *s, unsigned char *out)
{
    int i, v;
    for (i = 0; i < 4; i++) {
        if (*s < '0' || *s > '9') return -1;
        v = 0;
        while (*s >= '0' && *s <= '9') { v = v * 10 + (*s - '0'); s++; }
        if (v > 255) return -1;
        out[i] = (unsigned char)v;
        if (i < 3) { if (*s != '.') return -1; s++; }
    }
    return (*s == 0) ? 0 : -1;
}

int main(int argc, char **argv)
{
    int s, n, port, i, getmode, ai;
    unsigned char ip[4];
    char *ipstr, *portstr;

    getmode = 0;
    ai = 1;
    if (argc >= 2 && argv[1][0] == '-' && argv[1][1] == 'g' && argv[1][2] == 0) {
        getmode = 1; ai = 2;          /* -g: send GET / HTTP/1.0 */
    }
    if (argc != ai + 2) {             /* need exactly <ip> <port> after the flag */
        printf("usage: nc [-g] <ip> <port>   (-g sends GET / HTTP/1.0)\n");
        return 1;
    }
    ipstr = argv[ai];
    portstr = argv[ai + 1];

    if (parse_ip(ipstr, ip) != 0) {         /* not a dotted quad -> resolve it */
        struct hostent *h;
        unsigned char *a;
        h = gethostbyname(ipstr);
        if (h == 0) { printf("nc: cannot resolve %s\n", ipstr); return 1; }
        a = (unsigned char *)h->h_addr_list[0];
        ip[0] = a[0]; ip[1] = a[1]; ip[2] = a[2]; ip[3] = a[3];
    }
    port = 0;
    for (i = 0; portstr[i]; i++) port = port * 10 + (portstr[i] - '0');

    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) { printf("nc: socket failed\n"); return 1; }

    sa[SIN_FAMILY] = AF_INET;
    sa[SIN_PORT]   = (unsigned char)((port >> 8) & 0xff);
    sa[SIN_PORT+1] = (unsigned char)(port & 0xff);
    sa[SIN_ADDR]   = ip[0]; sa[SIN_ADDR+1] = ip[1];
    sa[SIN_ADDR+2] = ip[2]; sa[SIN_ADDR+3] = ip[3];

    if (connect(s, sa, SIN_SIZE) != 0) {
        printf("nc: connect failed\n");
        close(s);
        return 1;
    }

    if (getmode) {
        n = 0; while (httpget[n]) n++;        /* strlen */
        write(s, httpget, n);                 /* write()==send on the socket */
    } else {
        while ((n = read(0, buf, sizeof(buf))) > 0)
            write(s, buf, n);
    }

    /* socket -> stdout until the peer closes (recv returns 0 at EOF) */
    while ((n = recv(s, buf, sizeof(buf), 0)) > 0)
        write(1, buf, n);

    close(s);
    return 0;
}
