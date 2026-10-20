/* settimeofday(2): the kernel clock (SYS_SETTIMEOFDAY, 126), which sets the
 * time, the zone, or both, and writes the time back to the battery clock.
 * Super user only.  The block is flags (bit 0 = tv given, bit 1 = tz given),
 * tv_sec, tv_usec, tz_minuteswest, tz_dsttime, in the data bank for the
 * reason gettimeofday.c gives. */
static int __lc_stod[7];            /* flags, tv (2 longs), tz (2 ints) */

int settimeofday(struct timeval *tv, struct timezone *tz)
{
    int r;

    __lc_stod[0] = 0;
    if (tv != 0) {
        __lc_stod[0] |= 1;
        *(long *)&__lc_stod[1] = tv->tv_sec;
        *(long *)&__lc_stod[3] = tv->tv_usec;
    }
    if (tz != 0) {
        __lc_stod[0] |= 2;
        __lc_stod[5] = tz->tz_minuteswest;
        __lc_stod[6] = tz->tz_dsttime;
    }
    r = (int)__syscall(126, (unsigned)(unsigned long)&__lc_stod[0], 0, 0);
    if (__syscall_c() == 0) {
        errno = r;                  /* EPERM for a non-root caller, or EINVAL */
        return -1;
    }
    return 0;
}
