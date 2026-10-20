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
int bind(int fd, char *addr, int addrlen)
{
    (void)addrlen;
    unsigned long lp = (unsigned long)addr;
    int r = (int)__syscall_db(72, (unsigned)(lp >> 16), (unsigned)lp, fd, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int listen(int fd)                            /* SYS_LISTEN=84: 0 / -1 */
{
    int r = (int)__syscall(84, fd, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int accept(int fd)                            /* SYS_ACCEPT=85: connfd / -1 */
{
    int r = (int)__syscall(85, fd, 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

/* shutdown(fd, how) -- TCP half-close (SYS_SHUTDOWN=100).  SHUT_WR/SHUT_RDWR send
 * a FIN (the W5100 socket stays in FIN_WAIT, so recv still drains queued data +
 * sees the peer FIN as EOF); SHUT_RD is a no-op (can't stop RX).  The fd stays
 * open -- close(fd) does the full teardown.  0 / -1 (EBADF/ENOTSOCK). */
int shutdown(int fd, int how)
{
    int r = (int)__syscall(100, fd, how, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

/* getpeername(2) / getsockname(2) -- SYS_GETPEERNAME=108, SYS_GETSOCKNAME=109.
 *
 * The kernel writes a full 16-byte sockaddr_in and takes no length, which keeps
 * its side to the two registers connect(2) already uses.  The BSD 3-arg form's
 * namelen is settled HERE: a buffer that cannot hold a whole record is EINVAL
 * rather than a short write the caller would have to think about, and *namelen
 * comes back as what was actually written.
 *
 * These were DECLARED in sys/socket.h and implemented nowhere (apple/fgx#142) --
 * a program that called either compiled clean and failed at link, which is the
 * "a declaration reads as shipped" shape.  telnetd(8) is the customer: upstream
 * is an inetd child whose first act is getpeername(0,...) to learn the peer for
 * login's -h. */
#define _SIN_SIZE 16                       /* SIN_SIZE, include/socket.s */

int getpeername(int fd, char *name, int *namelen)
{
    int r;
    unsigned long lp;
    if (namelen == 0 || *namelen < _SIN_SIZE) { errno = EINVAL; return -1; }
    lp = (unsigned long)name;
    r = (int)__syscall_db(108, (unsigned)(lp >> 16), (unsigned)lp, fd, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    *namelen = _SIN_SIZE;
    return 0;
}

int getsockname(int fd, char *name, int *namelen)
{
    int r;
    unsigned long lp;
    if (namelen == 0 || *namelen < _SIN_SIZE) { errno = EINVAL; return -1; }
    lp = (unsigned long)name;
    r = (int)__syscall_db(109, (unsigned)(lp >> 16), (unsigned)lp, fd, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    *namelen = _SIN_SIZE;
    return 0;
}

int sendto(int s, char *buf, int len, int flags, char *to, int tolen)
{
    /* argblk words 4..5 = dst IP, 6 = port (net order) -- composed as word
     * stores from the sockaddr_in's fields (SIN_PORT @2, SIN_ADDR @4) */
    int r;
    unsigned long lp = (unsigned long)buf;
    (void)tolen;
    _sock_argblk[0] = (int)lp;
    _sock_argblk[1] = len;
    _sock_argblk[2] = flags;
    _sock_argblk[3] = (int)(lp >> 16);
    _sock_argblk[4] = ((to[4] & 0xFF) | ((to[5] & 0xFF) << 8));
    _sock_argblk[5] = ((to[6] & 0xFF) | ((to[7] & 0xFF) << 8));
    _sock_argblk[6] = ((to[2] & 0xFF) | ((to[3] & 0xFF) << 8));
    r = (int)__syscall(73, (unsigned)(unsigned long)&_sock_argblk[0], s, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

/* recvfrom(2).  THE KERNEL WRITES THE SOURCE ADDRESS INTO THIS BLOCK, never
 * into the caller's `from': word 4 points it at the 16 bytes from word 5 on,
 * which sit in the data bank the kernel reads the block through, and every
 * transport writes one whole 16-byte record there (a sockaddr_in, or AF_UNIX's
 * sun_noname).  What the caller gets is then 2.11BSD's recvit exactly: nothing
 * when `from' is null, else min(*fromlen, 16) bytes and that count written back
 * -- netcopyout's `if (*len > m->m_len) *len = m->m_len' (sys_net.c:221-223),
 * with `*fromlen <= 0' copying nothing and answering 0 (uipc_syscalls.c,
 * recvit).  getpeername settles its namelen here for the same reason. */
int recvfrom(int s, char *buf, int maxlen, int flags, char *from, int *fromlen)
{
    int r, n;
    unsigned long lp = (unsigned long)buf;
    _sock_argblk[0] = (int)lp;
    _sock_argblk[1] = maxlen;
    _sock_argblk[2] = flags;
    _sock_argblk[3] = (int)(lp >> 16);
    _sock_argblk[4] = (int)(unsigned long)&_sock_argblk[5];
    r = (int)__syscall(74, (unsigned)(unsigned long)&_sock_argblk[0], s, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    if (from) {
        n = *fromlen;
        if (n < 0)
            n = 0;
        if (n > _SIN_SIZE)
            n = _SIN_SIZE;
        memcpy(from, (char *)&_sock_argblk[5], n);
        *fromlen = n;
    }
    return r;
}
