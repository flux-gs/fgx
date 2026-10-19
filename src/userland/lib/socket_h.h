/*
 * socket_h.h - BSD UDP socket API for FGX userland C tools.
 *
 * The C mirror of include/socket.s (kernel ABI).  sockaddr_in is a RAW
 * 16-byte buffer accessed by explicit byte offsets, NOT an fcc struct: fcc
 * even-aligns word/long/pointer members (scalar chars byte-pack since B-8
 * 2026-07-06, but words still don't), so a struct still cannot reproduce a
 * fully byte-packed wire layout.  The net-config tools (ifconfig/route)
 * learned the same lesson with ifreq.
 *
 * Usage:
 *   unsigned char sa[16];           // sockaddr_in
 *   sa[SIN_FAMILY] = AF_INET;
 *   sa[SIN_PORT]   = (port >> 8) & 0xff;   // network order (big-endian)
 *   sa[SIN_PORT+1] = port & 0xff;
 *   sa[SIN_ADDR..SIN_ADDR+3] = a.b.c.d;    // network order
 *
 * Shims: socket->c_socket, bind->c_bind, sendto->c_sendto,
 * recvfrom->c_recvfrom, setsockopt->c_setsockopt (toolchain/lib/fcc_libc_shims.s).
 */
#ifndef _FGX_SOCKET_H_
#define _FGX_SOCKET_H_

/* Address family / socket type / setsockopt option (BSD values). */
#define AF_UNIX        1       /* local to host; SOCK_DGRAM only here  */
#define AF_INET        2
#define SOCK_DGRAM     2
#define SOL_SOCKET     0xFFFF
#define SO_BROADCAST   0x0020
#define SOCK_RAW       3        /* raw IP socket (ping)                  */
#define IPPROTO_ICMP   1        /* IP protocol number for raw ICMP       */
#define SOCK_STREAM    1        /* stream socket (TCP)                   */
#define IPPROTO_TCP    6        /* IP protocol number for TCP            */
#define MSG_DONTWAIT   0x80     /* recv/send: this call non-blocking     */

/* struct sockaddr_in field byte offsets (16 bytes, 2.11BSD layout).
 *
 * THIS FILE DESCRIBED THE 4.4BSD LAYOUT UNTIL apple/fgx#142 -- sin_len at 0 and
 * a one-byte sin_family at 1 -- while include/socket.s moved the kernel to
 * 2.11BSD's (a two-byte `short sin_family' at 0, no sin_len) on 2026-07-19 to
 * match toolchain/include/netinet/in.h.  The disagreement was invisible because
 * every INPUT path ignores the family and reads only sin_port@2 and
 * sin_addr@4, which the two layouts agree on, and every user of this header was
 * a writer.  getpeername/getsockname are the first calls that hand a family
 * BACK, so a reader using the old offset would have got the high byte of the
 * short -- always zero -- and concluded the family was not AF_INET. */
#define SIN_FAMILY     0       /* 2: AF_INET (short, low byte first)   */
#define SIN_PORT       2       /* 2: port, network order (hi,lo)       */
#define SIN_ADDR       4       /* 4: IPv4 addr, network order          */
#define SIN_ZERO       8       /* 8: zero pad                          */
#define SIN_SIZE       16

#define INADDR_ANY        0x00000000
#define INADDR_BROADCAST  0xFFFFFFFF

/*
 * htons/htonl: the 65816 is little-endian; network order is big-endian, so
 * these byte-swap.  ntoh* are the same swap.  Most FGX net code keeps
 * addresses as raw network-order bytes, so these are mainly for ports.
 *
 * Single-line, no 'UL' integer suffix: fcc's lexer rejects 0xffUL (use
 * (unsigned long) casts + plain hex instead).
 */
#define htons(x)  ((unsigned short)((((unsigned short)(x) & 0xff) << 8) | (((unsigned short)(x) >> 8) & 0xff)))
#define ntohs(x)  htons(x)
#define htonl(x)  ((unsigned long)(((unsigned long)((x) & 0xff) << 24) | ((unsigned long)((x) & 0xff00) << 8) | (((unsigned long)(x) >> 8) & 0xff00) | (((unsigned long)(x) >> 24) & 0xff)))
#define ntohl(x)  htonl(x)

/*
 * BSD UDP socket calls.  Buffers and sockaddrs may live in any bank.
 * recvfrom is non-blocking: returns -1 when no datagram is queued.
 */
int socket(int domain, int type, int proto);
int bind(int s, unsigned char *addr, int addrlen);
int connect(int s, unsigned char *addr, int addrlen);
int send(int s, unsigned char *buf, int len, int flags);
int recv(int s, unsigned char *buf, int len, int flags);
int sendto(int s, unsigned char *buf, int len, int flags,
           unsigned char *to, int tolen);
int recvfrom(int s, unsigned char *buf, int len, int flags,
             unsigned char *from, int *fromlen);
int setsockopt(int s, int level, int optname, unsigned char *optval, int optlen);

/* Raw-fd close (sockets and files).  FGX has no <unistd.h>; declared here
 * since the net tools close sockets.  Distinct from fclose(FILE *). */
int close(int fd);

#endif /* _FGX_SOCKET_H_ */
