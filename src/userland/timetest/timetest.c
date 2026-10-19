/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * timetest -- the kernel clock (src/kernel/tty/kern_time.c), one line per
 * check and a verdict:
 *
 *   TT A1 adv=N ok     gettimeofday advances 2..4 s across sleep(3)
 *   TT A2 vals=N ok    tv_usec takes more than one value over 20 ticks
 *   TT A3 diff=N ok    less the boot's machdep.adjkerntz, the kernel's seconds are
 *                      the battery clock's, read directly (SYS_RTCREAD),
 *                      within 2 s -- inittodr's conversion
 * and, as root (settimeofday), each undone before the next:
 *   TT B1 diff=N ok    settimeofday(now + 1000) reads back within 1 s
 *   TT B2 rtc=N ok     ...and the battery clock read directly agrees within
 *                      2 s: resettodr wrote it back
 *   TT B3 tz=M,D ok    a zone-only call sets the zone and leaves the time
 *   TT B4 e=22 ok      a tv_usec of 1000000 is EINVAL and changes nothing
 * and adjtime, measured over exactly 120 ticks (the clock moves only on a
 * tick, so a read just after one is exact), then cancelled:
 *   TT C1 extra=N ok   a +1 s slew runs 120 x 66 us fast (7000..9000)
 *   TT C3 old=N ok     the next adjtime reports what was still owed, just
 *                      under 1 s
 *   TT C2 extra=N ok   a -1 s slew runs as much slow
 * and the machdep sysctls, each restored:
 *   TT D1 K,0,1,16688 ok   adjkerntz (K, the boot's), disable_rtc_set, wall_cmos_clock and
 *                      tick read their defaults, take a write and read it back
 *   TT D2 rtc=N,M ok   adjkerntz = 3600 writes the battery clock back an hour
 *                      behind the kernel (N near -3600), and 0 puts it back
 *   TT D3 extra=N ok   tick at 25000 runs the clock 120 x 8312 us fast over
 *                      120 ticks (an int is 16 bits: twice 16688 is not one)
 *   TT D4 e=45 ok      an unknown machdep leaf is EOPNOTSUPP
 *   TT D5 -46800 ok    adjkerntz holds New Zealand's -46800, which a 16-bit
 *                      int cannot (it is a long, FreeBSD's 32-bit int)
 * and what UFS stamps with (KSVC_TIME, kern_time in ufs.mod):
 *   TT E1 diff=N ok    a new file's mtime is gettimeofday's within 2 s
 *   TT E2 diff=N ok    ...still, with adjkerntz at 3600: the stamp is UTC,
 *                      where the battery clock is now an hour behind
 *   TT VERDICT PASS
 */
#include <stdio.h>
#include <errno.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <machine/cpu.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>

long ticks();

/* The kernel writes the frame through (caller bank, offset), so it lives in
 * the data bank; a stack local would name an offset in bank 0. */
static unsigned char rtc[6];            /* sec min hour year day mon */

/* The battery clock as epoch seconds, its local time taken as-is: the same
 * arithmetic as the kernel's kern_epoch, done here so the check does not
 * trust the code it checks. */
static long
rtcnow()
{
    static char dim[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    int year, mon, i;
    long days;

    (void)__syscall(31, (unsigned)(unsigned long)&rtc[0], 0, 0);
    year = rtc[3] + 1900;
    mon = rtc[5] + 1;
    days = (long)(year - 1970) * 365L + (long)((year - 1970 + 1) >> 2);
    for (i = 1; i < mon; i++)
        days += dim[i - 1];
    if ((year & 3) == 0 && mon >= 3)
        days++;
    days += rtc[4];
    return days * 86400L + (long)rtc[2] * 3600L + (long)rtc[1] * 60L +
           (long)rtc[0];
}

/* machdep.<id>: read it, and write v unless v is NOVAL.  Returns the old
 * value, or -9999 when either half fails. */
#define NOVAL (-32768)
static int
machdep(id, v)
    int id, v;
{
    int mib[2], old;
    unsigned len;

    mib[0] = CTL_MACHDEP;
    mib[1] = id;
    len = sizeof(int);
    if (sysctl(mib, 2, &old, &len, (void *)0, 0) < 0)
        return (-9999);
    if (v != NOVAL && sysctl(mib, 2, (void *)0, (unsigned *)0, &v,
                             sizeof(int)) < 0)
        return (-9999);
    return (old);
}

/* machdep.adjkerntz, which is a long: machdep() for 4 bytes. */
static long
mdlong(id, v)
    int id;
    long v;
{
    int mib[2];
    long old;
    unsigned len;

    mib[0] = CTL_MACHDEP;
    mib[1] = id;
    len = sizeof(long);
    if (sysctl(mib, 2, &old, &len, (void *)0, 0) < 0 || len != sizeof(long))
        return (-9999L);
    if (v != NOVAL && sysctl(mib, 2, (void *)0, (unsigned *)0, &v,
                             sizeof(long)) < 0)
        return (-9999L);
    return (old);
}

/* A fresh file's mtime less gettimeofday's seconds. */
static long
stampdiff()
{
    struct timeval now;
    struct stat st;
    int fd;

    unlink("/tmp/tt.e");
    fd = open("/tmp/tt.e", O_WRONLY | O_CREAT, 0644);
    if (fd < 0)
        return (99999L);
    write(fd, "e", 1);
    close(fd);
    gettimeofday(&now, (struct timezone *)0);
    if (stat("/tmp/tt.e", &st) < 0)
        return (99998L);
    unlink("/tmp/tt.e");
    return ((long)st.st_mtime - now.tv_sec);
}

/* How far the clock moves per 120 ticks beyond 120 x the default tick, the
 * unslewed rate.  The clock holds still between ticks, so each read is kept
 * only when the tick count is the same on both sides of it, and the result is
 * scaled by the ticks that really passed: a preemption between the wait and
 * the read once landed four or eight extra 25000 us ticks in D3. */
static long
over120()
{
    struct timeval a, b;
    long t0, t1, n;

    t0 = ticks();
    while (ticks() == t0)
        ;
    do {                        /* a clock read inside one tick: t0's */
        t0 = ticks();
        gettimeofday(&a, (struct timezone *)0);
    } while (ticks() != t0);
    while (ticks() < t0 + 120L)
        ;
    do {
        t1 = ticks();
        gettimeofday(&b, (struct timezone *)0);
    } while (ticks() != t1);
    n = t1 - t0;
    return (((b.tv_sec - a.tv_sec) * 1000000L + (b.tv_usec - a.tv_usec) -
             n * 16688L) * 120L / n);
}

int
main()
{
    struct timeval a, b;
    long adv, diff, t0, seen[20], kz0;
    int i, j, vals, fail;

    fail = 0;
    /* The zone offset adjkerntz -i set at boot: 0 on a UTC image, minus the
     * zone's gmtoff otherwise.  The battery clock is the kernel clock less
     * it, and every case that writes the offset puts this value back. */
    kz0 = mdlong(CPU_ADJKERNTZ, (long)NOVAL);

    gettimeofday(&a, (struct timezone *)0);
    sleep(3);
    gettimeofday(&b, (struct timezone *)0);
    adv = b.tv_sec - a.tv_sec;
    printf("TT A1 adv=%ld %s\n", adv, (adv >= 2 && adv <= 4) ? "ok" : "FAIL");
    if (adv < 2 || adv > 4)
        fail = 1;

    vals = 0;
    for (i = 0; i < 20; i++) {
        t0 = ticks();
        while (ticks() == t0)
            ;
        gettimeofday(&a, (struct timezone *)0);
        for (j = 0; j < vals; j++)
            if (seen[j] == a.tv_usec)
                break;
        if (j == vals)
            seen[vals++] = a.tv_usec;
    }
    printf("TT A2 vals=%d %s\n", vals, vals > 1 ? "ok" : "FAIL");
    if (vals <= 1)
        fail = 1;

    gettimeofday(&a, (struct timezone *)0);
    diff = a.tv_sec - rtcnow() - kz0;
    if (diff < 0)
        diff = -diff;
    printf("TT A3 diff=%ld %s\n", diff, diff <= 2 ? "ok" : "FAIL");
    if (diff > 2)
        fail = 1;
    {
        long want;

        want = -localtime(&a.tv_sec)->tm_gmtoff;
        printf("TT A4 kz=%ld %s\n", kz0, kz0 == want ? "ok" : "FAIL");
        if (kz0 != want)
            fail = 1;
    }

    {
        struct timeval now, back;
        struct timezone z, zz;
        long d, rd;
        int st;

        gettimeofday(&now, (struct timezone *)0);
        now.tv_sec += 1000L;
        st = settimeofday(&now, (struct timezone *)0);
        gettimeofday(&back, (struct timezone *)0);
        d = back.tv_sec - now.tv_sec;
        rd = rtcnow() - back.tv_sec + kz0;
        back.tv_sec -= 1000L;
        settimeofday(&back, (struct timezone *)0);          /* undo */
        if (d < 0)
            d = -d;
        if (rd < 0)
            rd = -rd;
        printf("TT B1 diff=%ld %s\n", d, (st == 0 && d <= 1) ? "ok" : "FAIL");
        printf("TT B2 rtc=%ld %s\n", rd, rd <= 2 ? "ok" : "FAIL");
        if (st != 0 || d > 1 || rd > 2)
            fail = 1;

        gettimeofday(&now, (struct timezone *)0);
        z.tz_minuteswest = 300;
        z.tz_dsttime = 1;
        st = settimeofday((struct timeval *)0, &z);
        gettimeofday(&back, &zz);
        z.tz_minuteswest = 0;
        z.tz_dsttime = 0;
        settimeofday((struct timeval *)0, &z);              /* undo */
        d = back.tv_sec - now.tv_sec;
        printf("TT B3 tz=%d,%d %s\n", zz.tz_minuteswest, zz.tz_dsttime,
               (st == 0 && zz.tz_minuteswest == 300 && zz.tz_dsttime == 1 &&
                d >= 0 && d <= 1) ? "ok" : "FAIL");
        if (st != 0 || zz.tz_minuteswest != 300 || zz.tz_dsttime != 1 ||
            d < 0 || d > 1)
            fail = 1;

        gettimeofday(&now, (struct timezone *)0);
        back = now;
        back.tv_sec += 5000L;
        back.tv_usec = 1000000L;
        errno = 0;
        st = settimeofday(&back, (struct timezone *)0);
        gettimeofday(&back, (struct timezone *)0);
        d = back.tv_sec - now.tv_sec;
        printf("TT B4 e=%d %s\n", errno,
               (st == -1 && errno == EINVAL && d >= 0 && d <= 1) ? "ok" : "FAIL");
        if (st != -1 || errno != EINVAL || d < 0 || d > 1)
            fail = 1;
    }

    {
        struct timeval d, old;
        long e1, e2;

        d.tv_sec = 1;
        d.tv_usec = 0;
        adjtime(&d, (struct timeval *)0);
        e1 = over120();
        d.tv_sec = -1;
        adjtime(&d, &old);
        e2 = over120();
        d.tv_sec = 0;
        adjtime(&d, (struct timeval *)0);                   /* cancel */
        printf("TT C1 extra=%ld %s\n", e1,
               (e1 >= 7000L && e1 <= 9000L) ? "ok" : "FAIL");
        printf("TT C3 old=%ld %s\n", old.tv_sec * 1000000L + old.tv_usec,
               (old.tv_sec == 0 && old.tv_usec > 980000L) ? "ok" : "FAIL");
        printf("TT C2 extra=%ld %s\n", e2,
               (e2 <= -7000L && e2 >= -9000L) ? "ok" : "FAIL");
        if (e1 < 7000L || e1 > 9000L || old.tv_sec != 0 ||
            old.tv_usec <= 980000L || e2 > -7000L || e2 < -9000L)
            fail = 1;
    }

    {
        static int ids[4] = { CPU_ADJKERNTZ, CPU_DISRTCSET, CPU_WALLCLOCK,
                              CPU_TICK };
        int d[4], i, ok, mib[2], v;
        unsigned len;
        struct timeval now;
        long r1, r2, e, d0;

        ok = 1;
        d0 = mdlong(ids[0], (long)NOVAL);
        mdlong(ids[0], d0 + 1L);
        if (mdlong(ids[0], d0) != d0 + 1L)              /* reads, restores */
            ok = 0;
        for (i = 1; i < 4; i++) {
            d[i] = machdep(ids[i], NOVAL);
            machdep(ids[i], d[i] + 1);
            if (machdep(ids[i], d[i]) != d[i] + 1)      /* reads, restores */
                ok = 0;
        }
        ok = ok && d0 == kz0 && d[1] == 0 && d[2] == 1 && d[3] == 16688;
        printf("TT D1 %ld,%d,%d,%d %s\n", d0, d[1], d[2], d[3],
               ok ? "ok" : "FAIL");
        if (!ok)
            fail = 1;

        mdlong(CPU_ADJKERNTZ, 3600L);
        gettimeofday(&now, (struct timezone *)0);
        r1 = rtcnow() - now.tv_sec;
        mdlong(CPU_ADJKERNTZ, kz0);
        gettimeofday(&now, (struct timezone *)0);
        r2 = rtcnow() - now.tv_sec + kz0;
        ok = r1 >= -3602L && r1 <= -3598L && r2 >= -2L && r2 <= 2L;
        printf("TT D2 rtc=%ld,%ld %s\n", r1, r2, ok ? "ok" : "FAIL");
        if (!ok)
            fail = 1;

        machdep(CPU_TICK, 25000);
        e = over120();
        machdep(CPU_TICK, 16688);
        ok = e >= 990000L && e <= 1010000L;
        printf("TT D3 extra=%ld %s\n", e, ok ? "ok" : "FAIL");
        if (!ok)
            fail = 1;

        mib[0] = CTL_MACHDEP;
        mib[1] = 4;
        len = sizeof(int);
        errno = 0;
        i = sysctl(mib, 2, &v, &len, (void *)0, 0);
        printf("TT D4 e=%d %s\n", errno, (i < 0 && errno == 45) ? "ok" : "FAIL");
        if (i >= 0 || errno != 45)
            fail = 1;

        mdlong(CPU_ADJKERNTZ, -46800L);
        e = mdlong(CPU_ADJKERNTZ, kz0);
        printf("TT D5 %ld %s\n", e, e == -46800L ? "ok" : "FAIL");
        if (e != -46800L)
            fail = 1;
    }

    {
        long e1, e2;

        e1 = stampdiff();
        mdlong(CPU_ADJKERNTZ, 3600L);
        e2 = stampdiff();
        mdlong(CPU_ADJKERNTZ, kz0);
        printf("TT E1 diff=%ld %s\n", e1, (e1 >= -2L && e1 <= 2L) ? "ok" : "FAIL");
        printf("TT E2 diff=%ld %s\n", e2, (e2 >= -2L && e2 <= 2L) ? "ok" : "FAIL");
        if (e1 < -2L || e1 > 2L || e2 < -2L || e2 > 2L)
            fail = 1;
    }

    printf("TT VERDICT %s\n", fail ? "FAIL" : "PASS");
    return fail;
}
