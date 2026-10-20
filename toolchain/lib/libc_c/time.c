/* time(3) -- BSD layering: a library routine over gettimeofday(2), exactly as
 * 2.11BSD defines it.  Returns time_t seconds since the epoch, and stores the
 * same value through `t` when non-NULL.
 *
 * This used to reach the RTC itself with a raw `LDX #$0D03 / JSL $E10000`
 * (Misc Toolset ReadTimeHex) from USER context.  That call never returns for
 * tcsh -- see SYS_RTCREAD (#31) in the kernel for the measurement -- so the
 * Toolbox interaction now lives in the kernel and this side keeps only the
 * arithmetic, which measured correct (1785082864 = 2026-07-26). */
long time(long *t)
{
    struct timeval tv;

    if (gettimeofday(&tv, (struct timezone *)0) < 0)
        return -1;
    if (t != 0)
        *t = tv.tv_sec;
    return tv.tv_sec;
}

