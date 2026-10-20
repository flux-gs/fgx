/* select(2): marshal the fd_sets + timeval into the data-bank _sel_argblk, let
 * _Sys_Select scan + rewrite the result masks in place, copy them back.  fd_set
 * is { long fds_bits[1]; } so a set is accessed as *(long *)set (the proto in
 * <sys/time.h> passes void *).  timeval is pre-converted to 60 Hz ticks here.
 * argblk words: [0]nfds [1]present(b0rd b1wr b2ex b3timeout) [2,3]readfds lo/hi
 * [4,5]writefds [6,7]exceptfds [8,9]timeout-ticks. */
int _sel_argblk[10];                /* in the data bank: _Sys_Select reads
                                     * and rewrites it through the caller's
                                     * DBR */

int select(int nfds, void *rd, void *wr, void *ex, struct timeval *tv)
{
    int  r, present;
    long rmask, wmask, emask, ticks;

    present = 0;
    rmask = 0; wmask = 0; emask = 0;
    if (rd) { present |= 1; rmask = *(long *)rd; }
    if (wr) { present |= 2; wmask = *(long *)wr; }
    if (ex) { present |= 4; emask = *(long *)ex; }

    _sel_argblk[0] = nfds;
    _sel_argblk[2] = (int)rmask;
    _sel_argblk[3] = (int)(rmask >> 16);
    _sel_argblk[4] = (int)wmask;
    _sel_argblk[5] = (int)(wmask >> 16);
    _sel_argblk[6] = (int)emask;
    _sel_argblk[7] = (int)(emask >> 16);

    if (tv) {
        present |= 8;
        ticks = tv->tv_sec * 60L + tv->tv_usec / 16667L;   /* 60 Hz heartbeat */
        _sel_argblk[8] = (int)ticks;
        _sel_argblk[9] = (int)(ticks >> 16);
    } else {
        _sel_argblk[8] = 0;
        _sel_argblk[9] = 0;
    }
    _sel_argblk[1] = present;

    r = (int)__syscall(99, (unsigned)(unsigned long)&_sel_argblk[0], 0, 0);
    if (__syscall_c() == 0) { errno = r; return -1; }

    if (rd) *(long *)rd = ((long)(unsigned)_sel_argblk[3] << 16) | (unsigned)_sel_argblk[2];
    if (wr) *(long *)wr = ((long)(unsigned)_sel_argblk[5] << 16) | (unsigned)_sel_argblk[4];
    if (ex) *(long *)ex = ((long)(unsigned)_sel_argblk[7] << 16) | (unsigned)_sel_argblk[6];
    return r;
}

