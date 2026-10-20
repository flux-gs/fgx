/* adjtime(2): slew the kernel clock by *delta rather than step it
 * (SYS_ADJTIME, 125; src/kernel/tty/kern_time.c), and report through
 * *olddelta what the previous call still owed.  Super user only.  The block
 * is delta then olddelta, in the data bank for the reason gettimeofday.c
 * gives. */
static long __lc_adj[4];            /* delta sec, usec; olddelta sec, usec */

int adjtime(struct timeval *delta, struct timeval *olddelta)
{
    int r;

    __lc_adj[0] = delta->tv_sec;
    __lc_adj[1] = delta->tv_usec;
    r = (int)__syscall(125, (unsigned)(unsigned long)&__lc_adj[0], 0, 0);
    if (__syscall_c() == 0) {
        errno = r;
        return -1;
    }
    if (olddelta != 0) {
        olddelta->tv_sec = __lc_adj[2];
        olddelta->tv_usec = __lc_adj[3];
    }
    return 0;
}
