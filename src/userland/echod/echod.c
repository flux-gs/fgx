/*
 * echod - a TCP echo server (Phase 6.2 payoff demo).
 *
 * Usage: echod [port]   (default 7777)
 *
 * Loops: socket -> bind(INADDR_ANY:port) -> listen -> accept (blocks via the
 * kernel socket-sleep path until a peer connects) -> echo every byte back until
 * the peer closes -> close.  Demonstrates the server-side TCP added to the
 * kernel (SYS_LISTEN/SYS_ACCEPT + the W5100 OPEN->LISTEN->ESTABLISHED flow).
 *
 * read()/write() work on a socket fd (read==recv, write==send).  accept()
 * returns a NEW connection fd and detaches the listener, so we re-socket/bind/
 * listen each iteration (the W5100 is single-socket per listener).
 */
#include "../lib/socket_h.h"
#include <stdio.h>

int atoi(const char *s);
int read(int fd, void *buf, int n);
int write(int fd, void *buf, int n);
int listen(int fd);              /* echod_stubs.s: SYS_LISTEN */
int accept(int fd);              /* echod_stubs.s: SYS_ACCEPT */

int main(int argc, char **argv)
{
    int lfd, cfd, n, port;
    unsigned char sa[SIN_SIZE];
    unsigned char buf[128];

    port = 7777;
    if (argc > 1)
        port = atoi(argv[1]);

    printf("echod: listening on port %d\n", port);

    for (;;) {
        lfd = socket(AF_INET, SOCK_STREAM, 0);
        if (lfd < 0) { printf("echod: socket failed\n"); return 1; }

        sa[SIN_FAMILY] = AF_INET;
        sa[SIN_PORT]   = (unsigned char)((port >> 8) & 0xff);
        sa[SIN_PORT+1] = (unsigned char)(port & 0xff);
        sa[SIN_ADDR]   = 0;     /* INADDR_ANY */
        sa[SIN_ADDR+1] = 0;
        sa[SIN_ADDR+2] = 0;
        sa[SIN_ADDR+3] = 0;

        if (bind(lfd, sa, SIN_SIZE) != 0) {
            printf("echod: bind failed\n");
            close(lfd);
            return 1;
        }
        if (listen(lfd) != 0) {
            printf("echod: listen failed\n");
            close(lfd);
            return 1;
        }

        cfd = accept(lfd);
        if (cfd < 0) {
            printf("echod: accept failed\n");
            close(lfd);
            return 1;
        }
        printf("echod: connection accepted\n");

        /* Echo until the peer closes (read returns 0 at EOF). */
        while ((n = read(cfd, buf, sizeof(buf))) > 0)
            write(cfd, buf, n);

        close(cfd);
        close(lfd);
        printf("echod: connection closed\n");
    }
    return 0;
}
