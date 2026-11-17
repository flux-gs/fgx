/* ---- socket family, the calls a CONNECTED CLIENT does not make -------------
 * bind(2), listen(2), accept(2), shutdown(2), getpeername(2), getsockname(2),
 * sendto(2) and recvfrom(2).  socket.c keeps socket/connect/send/recv, which is
 * everything a client that dials one service and talks to it needs.
 *
 * A MEMBER OF ITS OWN BECAUSE THE LIBC PILE IS DEAD-STRIPPED AT FILE
 * GRANULARITY, which is the same reason strpbrk/strsep/strstr are not in
 * string.c and getmntinfo is not in wait.c -- see docs/PROVENANCE.md on both.
 * syslog(3) calls socket, connect and send, so before this split every binary
 * that logs carried all twelve wrappers: su(1)'s seg2 is one unsplittable bank
 * of libc.s, the shims, libc.sel.s and libfgx.s, and those eight surplus
 * wrappers put it past 64 KB.
 *
 * The kernel's socket calls take a DATA-bank arg block (_sock_argblk in
 * libc_data.s) -- word fields land as plain extern-int-array stores, and the
 * buffer's bank rides beside its offset, as socket.c's header describes. */
extern int _sock_argblk[];

/* T5-C arity regression class (dhclient "bind :68 failed"): callers use the
 * full BSD prototypes (socket_h.h) -- bind(s,addr,addrlen) etc.  fcc anchors
 * the callee's params such that EXTRA trailing caller args shift the binding
 * (the retired asm shims read absolute slots of the full frame, so they
 * tolerated it).  Every socket shim therefore declares the caller's FULL arity
 * and ignores what the kernel doesn't take. */
int bind(int fd, char *addr, int addrlen)       /* addrlen in Y, as connect */
{
    unsigned long lp = (unsigned long)addr;
    int r = (int)__syscall_db(72, (unsigned)(lp >> 16), (unsigned)lp, fd, addrlen);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int listen(int fd, int backlog)               /* SYS_LISTEN=84: 0 / -1 */
{
    int r = (int)__syscall(84, fd, backlog, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int getpeername(int fd, char *name, int *namelen);

/* accept(2) -- SYS_ACCEPT=85: the new descriptor / -1.  The kernel takes the
 * listener alone; the peer's name, when the caller asks for one, is the new
 * socket's getpeername, min(*addrlen, its length) bytes, as 2.11BSD's accept()
 * copies it (uipc_syscalls.c). */
int accept(int fd, char *addr, int *addrlen)
{
    int r;

    r = (int)__syscall(85, fd, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    if (addr != 0 && addrlen != 0 && getpeername(r, addr, addrlen) < 0)
        *addrlen = 0;
    return r;
}

/* shutdown(fd, how) -- SYS_SHUTDOWN=100, 2.11BSD's soshutdown: 0 stops
 * receiving, 1 sending (a FIN on TCP), 2 both.  The fd stays open; close(fd)
 * tears the socket down.  0 / -1. */
int shutdown(int fd, int how)
{
    int r = (int)__syscall(100, fd, how, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* getpeername(2) / getsockname(2) -- SYS_GETPEERNAME=108, SYS_GETSOCKNAME=109.
 * *namelen goes in Y; the kernel copies min(*namelen, the name's length) bytes,
 * as 2.11BSD's uipc_syscalls.c does, and returns the count, which becomes the
 * new *namelen.  A negative *namelen asks for nothing. */
int getpeername(int fd, char *name, int *namelen)
{
    int r;
    unsigned long lp = (unsigned long)name;
    if (namelen == 0) { errno = EFAULT; return -1; }
    r = (int)__syscall_db(108, (unsigned)(lp >> 16), (unsigned)lp, fd,
        *namelen < 0 ? 0 : *namelen);
    if (__syscall_c() == 0) { errno = r; return -1; }
    *namelen = r;
    return 0;
}

int getsockname(int fd, char *name, int *namelen)
{
    int r;
    unsigned long lp = (unsigned long)name;
    if (namelen == 0) { errno = EFAULT; return -1; }
    r = (int)__syscall_db(109, (unsigned)(lp >> 16), (unsigned)lp, fd,
        *namelen < 0 ? 0 : *namelen);
    if (__syscall_c() == 0) { errno = r; return -1; }
    *namelen = r;
    return 0;
}

int sendto(int s, char *buf, int len, int flags, char *to, int tolen)
{
    /* argblk words 4..5 = dst IP, 6 = port (net order) -- composed as word
     * stores from the sockaddr_in's fields (SIN_PORT @2, SIN_ADDR @4) -- and
     * words 7..9 the sockaddr itself, its offset, bank and length, which the
     * kernel stack's sendto copies whole, as an AF_UNIX name needs */
    int r;
    unsigned long lp = (unsigned long)buf;
    unsigned long tp = (unsigned long)to;
    _sock_argblk[0] = (int)lp;
    _sock_argblk[1] = len;
    _sock_argblk[2] = flags;
    _sock_argblk[3] = (int)(lp >> 16);
    _sock_argblk[4] = ((to[4] & 0xFF) | ((to[5] & 0xFF) << 8));
    _sock_argblk[5] = ((to[6] & 0xFF) | ((to[7] & 0xFF) << 8));
    _sock_argblk[6] = ((to[2] & 0xFF) | ((to[3] & 0xFF) << 8));
    _sock_argblk[7] = (int)tp;
    _sock_argblk[8] = (int)(tp >> 16);
    _sock_argblk[9] = tolen;
    r = (int)__syscall(73, (unsigned)(unsigned long)&_sock_argblk[0], s, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

/* recvfrom(2).  Block words 4 and 5 are `from', its offset and bank, and word
 * 6 its length, which the kernel cuts to the source name's and writes back:
 * 2.11BSD's recvit, min(*fromlen, the name's length) bytes, nothing when
 * `from' is null or *fromlen is not positive (uipc_syscalls.c). */
int recvfrom(int s, char *buf, int maxlen, int flags, char *from, int *fromlen)
{
    int r;
    unsigned long lp = (unsigned long)buf;
    unsigned long fp = (unsigned long)from;
    _sock_argblk[0] = (int)lp;
    _sock_argblk[1] = maxlen;
    _sock_argblk[2] = flags;
    _sock_argblk[3] = (int)(lp >> 16);
    _sock_argblk[4] = (int)fp;
    _sock_argblk[5] = (int)(fp >> 16);
    _sock_argblk[6] = (from && *fromlen > 0) ? *fromlen : 0;
    r = (int)__syscall(74, (unsigned)(unsigned long)&_sock_argblk[0], s, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    if (from)
        *fromlen = _sock_argblk[6];
    return r;
}
