/* FGX libc — sys/socket.h.  BSD socket API (the C mirror of the SYS_SOCKET
 * family; cf. src/userland/lib/socket_h.h).  The kernel reads the sockaddr
 * buffer by byte offset via the caller's DBR, so struct sockaddr is a 16-byte
 * generic address matching sockaddr_in's layout. */
#ifndef _SYS_SOCKET_H
#define _SYS_SOCKET_H
#include <sys/types.h>

#define AF_UNSPEC    0
#define AF_UNIX      1
#define AF_INET      2
#define PF_UNIX      AF_UNIX
#define PF_INET      AF_INET

#define SOCK_STREAM  1
#define SOCK_DGRAM   2
#define SOCK_RAW     3

#define SOL_SOCKET   0xFFFF
#define SO_DEBUG     0x0001
#define SO_REUSEADDR 0x0004
#define SO_KEEPALIVE 0x0008
#define SO_DONTROUTE 0x0010
#define SO_BROADCAST 0x0020
#define SO_USELOOPBACK 0x0040
#define SO_OOBINLINE 0x0100

#define MSG_OOB      0x0001
#define MSG_PEEK     0x0002
#define MSG_DONTWAIT 0x0080

#define SHUT_RD      0       /* shutdown how: stop receiving (no-op on FGX) */
#define SHUT_WR      1       /* stop sending: send FIN (half-close)         */
#define SHUT_RDWR    2       /* both: send FIN                              */

struct sockaddr {           /* 2.11BSD sys/socket.h, verbatim */
    u_short sa_family;      /* 0: address family */
    char    sa_data[14];    /* 2..15: up to 14 bytes of address */
};

int socket(int domain, int type, int proto);
int bind(int s, struct sockaddr *addr, int addrlen);
int connect(int s, struct sockaddr *addr, int addrlen);
int listen(int s, int backlog);
int accept(int s, struct sockaddr *addr, int *addrlen);
int send(int s, char *buf, int len, int flags);
int recv(int s, char *buf, int len, int flags);
int sendto(int s, char *buf, int len, int flags, struct sockaddr *to, int tolen);
int recvfrom(int s, char *buf, int len, int flags, struct sockaddr *from, int *fromlen);
int setsockopt(int s, int level, int optname, char *optval, int optlen);
int getsockopt(int s, int level, int optname, char *optval, int *optlen);
int shutdown(int s, int how);
int getpeername(int s, struct sockaddr *name, int *namelen);
int getsockname(int s, struct sockaddr *name, int *namelen);
#endif
