/* ---- socket family (C4 batch 6) ------------------------------------------
 * The kernel's socket calls take a DATA-bank arg block (_sock_argblk in
 * libc_data.s) -- word fields land as plain extern-int-array stores.  The
 * block is read through the caller's DBR, but the BUFFER is not: its bank
 * rides in the block beside its offset, so a buffer in any bank works --
 * an fcc stack local lives in bank 0, not in the data bank the block does.
 * send, recv, sendto and recvfrom share the block's first four words
 * {buf offset, len, MSG_* flags, buf bank}; the layout is libc_data.s's.
 *
 * THE OTHER EIGHT WRAPPERS ARE IN socket_srv.c, a member of their own because
 * the libc pile is dead-stripped at FILE granularity: syslog(3) needs only
 * socket, connect and send, and carrying bind/listen/accept/shutdown/
 * getpeername/getsockname/sendto/recvfrom with them put su(1)'s seg2 past its
 * 64 KB bank.  What stays here is what a client that dials one service and
 * talks to it needs. */
/* The BSD socket arg block (send / recv / sendto / recvfrom).  A flat scalar
 * block passed by pointer to SYS_SEND/RECV/SENDTO/RECVFROM; the kernel reads it
 * via _Sys_CallerBank = the caller's DBR, so it lives in the program's data
 * bank.  Reused per call (the wrappers are not reentrant).
 *
 * ALL FOUR CALLS SHARE THE FIRST FOUR WORDS, and the kernel reads them at the
 * same offsets for all four (SOCKARG_BANK, include/socket.s):
 *   [0..1] buf offset   [2..3] len   [4..5] MSG_* flags   [6..7] buf bank
 * The bank is what lets the buffer sit in any bank -- an fcc stack local is in
 * bank 0, not in this one.  Then, per call:
 *   sendto:   [8..11] dst IP, [12..13] dst port (net order)
 *   recvfrom: [8..9] offset of the source-address staging, which is [10..25]:
 *             the kernel writes a whole 16-byte address there and libc copies
 *             what the caller asked for (socket_srv.c, recvfrom)
 * tools/check_sock_argblk.py holds this layout against net.mod's reads. */
int _sock_argblk[13];

int socket(int domain, int type, int proto)
{
    int r = (int)__syscall(71, domain, type, proto);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

/* addrlen is declared and ignored for the T5-C arity reason socket_srv.c's bind
 * records: every socket shim declares the caller's FULL BSD arity, because fcc
 * anchors the callee's params such that extra trailing caller args shift the
 * binding. */
int connect(int fd, char *addr, int addrlen)
{
    (void)addrlen;
    unsigned long lp = (unsigned long)addr;
    int r = (int)__syscall_db(76, (unsigned)(lp >> 16), (unsigned)lp, fd, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}

int send(int s, char *buf, int len, int flags)
{
    int r;
    unsigned long lp = (unsigned long)buf;
    _sock_argblk[0] = (int)lp;
    _sock_argblk[1] = len;
    _sock_argblk[2] = flags;
    _sock_argblk[3] = (int)(lp >> 16);
    r = (int)__syscall(77, (unsigned)(unsigned long)&_sock_argblk[0], s, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

int recv(int s, char *buf, int maxlen, int flags)
{
    int r;
    unsigned long lp = (unsigned long)buf;
    _sock_argblk[0] = (int)lp;
    _sock_argblk[1] = maxlen;
    _sock_argblk[2] = flags;
    _sock_argblk[3] = (int)(lp >> 16);
    r = (int)__syscall(78, (unsigned)(unsigned long)&_sock_argblk[0], s, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}
