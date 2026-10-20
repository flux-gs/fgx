
/* setitimer(2) -- arm the calling process's ITIMER_REAL.
 *
 * SYS_SETITIMER (#121) lives in the far kernel bank and takes SECONDS in A and
 * X with `which' in Y, because upstream's ITIMER_REAL is whole seconds too:
 * setitimer stores `p->p_realtimer.it_value = aitv.it_value.tv_sec' and merely
 * increments it when any tv_usec is set
 * (vendor/2.11BSD/usr/sys/sys/kern_time.c:215-223).  The rounding-up of a
 * sub-second remainder is done HERE, for the same reason it is done there: a
 * caller asking for half a second must not get none.
 *
 * TWO DIVERGENCES, both stated rather than left to be found.
 *
 * ITIMER_VIRTUAL and ITIMER_PROF are EINVAL.  Upstream keeps them in
 * `u.u_timer[]' and charges them against CPU time that FGX does not account,
 * so a timer accepted here would simply never fire -- worse than a refusal.
 *
 * `oitv' IS NOT FILLED, and setitimer returns -1/ENOSYS when it is not NULL
 * rather than filling it with something plausible.  The kernel reports the old
 * timer through the 32-bit A + Y return channel that `__syscall_y()' reads, and
 * the remaining COUNT already uses all of it; the old INTERVAL has nowhere to
 * come back in.  Reporting the count and inventing the interval would be a
 * wrong answer wearing a success, and shadowing the interval in a libc static
 * would go stale the moment alarm(2) cleared it in the kernel or an exec reset
 * the static.  The honest fix is getitimer(2) as its own syscall, which nothing
 * in the tree calls today.  This is the bargain `fchdir' and `link' already
 * take here: a hard, visible refusal instead of a lie.
 *
 * syslogd(8) calls `setitimer(ITIMER_REAL, &itv, NULL)' and is unaffected.
 *
 * The kernel refuses an interval above ITIMER_MAX_INTERVAL (1023 s) with
 * EINVAL, which reaches the caller unchanged; it never truncates one.
 */

int setitimer(which, itv, oitv)
    int which;
    struct itimerval *itv;
    struct itimerval *oitv;
{
    long vsec;
    long isec;
    int  r;

    if (which != ITIMER_REAL) {
        errno = EINVAL;
        return (-1);
    }
    if (itv == (struct itimerval *)0) {
        errno = EINVAL;
        return (-1);
    }
    if (oitv != (struct itimerval *)0) {
        errno = ENOSYS;                 /* see the note above */
        return (-1);
    }

    vsec = itv->it_value.tv_sec;
    isec = itv->it_interval.tv_sec;
    if (vsec < 0L || isec < 0L ||
        itv->it_value.tv_usec < 0L || itv->it_interval.tv_usec < 0L) {
        errno = EINVAL;                 /* itimerfix's rule, kern_time.c:244 */
        return (-1);
    }
    /* Upstream rounds a sub-second remainder UP, so a timer asked for is a
     * timer that fires: `if (aitv.it_value.tv_usec) ++p->p_realtimer.it_value'. */
    if (itv->it_value.tv_usec)
        vsec++;
    if (itv->it_interval.tv_usec)
        isec++;
    /* The syscall takes 16-bit seconds in a register apiece. */
    if (vsec > 65535L || isec > 65535L) {
        errno = EINVAL;
        return (-1);
    }

    r = (int)__syscall(121, (int)vsec, (int)isec, ITIMER_REAL);
    if (__syscall_c() == 0) {
        errno = r;
        return (-1);
    }
    return (0);
}
