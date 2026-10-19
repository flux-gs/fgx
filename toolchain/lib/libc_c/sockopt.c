/* setsockopt(2).  The option VALUE reaches the kernel: `optval' and `optlen'
 * used to be discarded here, with the comment "v1: setting an option enables
 * it", so the kernel could only ever turn an option ON -- passing a zero to
 * clear one set it instead, and nothing could report the difference
 * (apple/fgx#439).
 *
 * Arg block (_sock_argblk, the caller's data bank, read via _Sys_CallerBank):
 *   +0 level  +2 optname  +4 optval offset  +6 optlen  +8 optval bank
 * The bank rides beside the offset as it does for every socket buffer
 * (apple/fgx#480): `optval' is most often the address of a local, and locals
 * live in the stack bank, not the data bank the block is read through.
 */
/* Declared here as well as in socket.c: the archive carve compiles each member
 * ALONE, so a member that uses the block must declare it or its single-member
 * closure does not build. */
extern int _sock_argblk[];

int setsockopt(int fd, int level, int optname, char *optval, int optlen)
{
    int r;
    _sock_argblk[0] = level;
    _sock_argblk[1] = optname;
    _sock_argblk[2] = (int)(unsigned long)optval;
    _sock_argblk[3] = optlen;
    _sock_argblk[4] = (int)((unsigned long)optval >> 16);
    r = (int)__syscall(75, (unsigned)(unsigned long)&_sock_argblk[0], fd, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }
    return 0;
}
