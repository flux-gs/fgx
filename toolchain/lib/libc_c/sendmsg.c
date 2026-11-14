/* ---- sendmsg(2) and recvmsg(2) ----------------------------------------------
 * The message header is 2.11BSD's struct msghdr (<sys/socket.h>), and the
 * kernel reads it whole, with every pointer in it: the header's bank goes in
 * the caller-bank slot and its offset in A, the descriptor in X and the flags
 * in Y, as bind(2) passes its address.  recvmsg writes msg_namelen and
 * msg_accrightslen back into the header.  A member of its own, for the reason
 * socket_srv.c gives: the libc pile is dead-stripped by file. */
int sendmsg(int s, struct msghdr *msg, int flags)
{
    unsigned long lp = (unsigned long)msg;
    int r = (int)__syscall_db(131, (unsigned)(lp >> 16), (unsigned)lp, s, flags);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}

int recvmsg(int s, struct msghdr *msg, int flags)
{
    unsigned long lp = (unsigned long)msg;
    int r = (int)__syscall_db(132, (unsigned)(lp >> 16), (unsigned)lp, s, flags);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return r;
}
