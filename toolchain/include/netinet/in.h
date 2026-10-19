/* FGX libc — netinet/in.h.  Lifted from 2.11BSD netinet/in.h (verbatim struct
 * layouts + constants), trimmed to the userland surface.  sockaddr_in is the
 * 2.11BSD layout (short sin_family @0, sin_port @2, sin_addr @4, sin_zero @8):
 * fcc byte-packs it to the same 16 bytes FGX's kernel reads, and sin_port /
 * sin_addr land at the offsets FGX expects.  The kernel's sockaddr_in is the
 * matching 2.11BSD layout (include/socket.s): input reads sin_port@2 /
 * sin_addr@4 only, and output fills (recvfrom src; future accept/getpeername
 * peer) write sin_family as a 2-byte short @0, so a caller reads AF_INET back.
 * Ports/addresses are network (big-endian) order; the 65816 is little-endian,
 * so htons/htonl byte-swap. */
#ifndef _NETINET_IN_H
#define _NETINET_IN_H
#include <sys/types.h>

#define IPPROTO_ICMP   1
#define IPPROTO_TCP    6
#define IPPROTO_UDP    17

#define INADDR_ANY        0x00000000
#define INADDR_BROADCAST  0xFFFFFFFF
#define INADDR_LOOPBACK   0x7F000001

struct in_addr { u_long s_addr; };

struct sockaddr_in {              /* 2.11BSD netinet/in.h, verbatim */
    short          sin_family;   /* 0: AF_INET (FGX ignores it on input) */
    u_short        sin_port;     /* 2: network order                     */
    struct in_addr sin_addr;     /* 4: network order                     */
    char           sin_zero[8];  /* 8: pad to 16                         */
};

#define htons(x)  ((u_short)((((u_short)(x) & 0xff) << 8) | (((u_short)(x) >> 8) & 0xff)))
#define ntohs(x)  htons(x)
#define htonl(x)  ((u_long)(((u_long)((x) & 0xff) << 24) | ((u_long)((x) & 0xff00) << 8) | (((u_long)(x) >> 8) & 0xff00) | (((u_long)(x) >> 24) & 0xff)))
#define ntohl(x)  htonl(x)
#endif
