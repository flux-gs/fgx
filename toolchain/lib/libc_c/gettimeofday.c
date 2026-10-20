/* ---- gettimeofday ----------------------------------------------------------
 * gettimeofday(2) reads the KERNEL's clock, UTC with a sub-second part
 * (SYS_GETTIMEOFDAY, 124; src/kernel/tty/kern_time.c); settimeofday.c sets it.
 *
 * BOTH STAGE THROUGH A DATA-BANK BUFFER, not a stack local.  The kernel
 * addresses the caller's buffer as _Sys_CallerBank:offset -- the caller's DATA
 * bank -- while a local lives in bank 0 on the stack, so a local makes the
 * kernel write into the data bank at the stack's offset and read back garbage
 * (measured on the RTC call: epoch 1536361332 = 2018 instead of 1785082864).
 * Not reentrant, in line with the other libc staging buffers. */
/* The kernel fills tv_sec, tv_usec, tz_minuteswest and tz_dsttime whole;
 * the caller gets only the halves it asked for, as 2.11BSD's gettimeofday
 * copies out `if (uap->tp)' and `if (uap->tzp)' (kern_time.c:22). */
static long __lc_tod[3];            /* tv_sec, tv_usec, then two tz ints */

int gettimeofday(struct timeval *tv, struct timezone *tz)
{
    int r;

    r = (int)__syscall(124, (unsigned)(unsigned long)&__lc_tod[0], 0, 0);
    if (__syscall_c() == 0) {
        errno = r;
        return -1;
    }
    if (tv != 0) {
        tv->tv_sec  = __lc_tod[0];
        tv->tv_usec = __lc_tod[1];
    }
    if (tz != 0) {
        tz->tz_minuteswest = ((int *)&__lc_tod[2])[0];
        tz->tz_dsttime     = ((int *)&__lc_tod[2])[1];
    }
    return 0;
}
