/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * tztest -- libc time zones (toolchain/lib/libc_c/ctime.c, 4.3BSD-Reno 5.23)
 * against the zone files in /usr/share/zoneinfo.
 *
 *   TZ A1 ... ok   TZ=America/New_York: 2026-01-15 12:00 UTC is 07:00 EST,
 *                  gmtoff -18000, isdst 0
 *   TZ A2 ... ok   ...and 2026-07-15 12:00 UTC is 08:00 EDT, -14400, isdst 1
 *   TZ A3 ok       asctime of A1 is "Thu Jan 15 07:00:00 2026\n"
 *   TZ B1 ... ok   a POSIX string with a ten-hour offset, TEN-10: 22:00,
 *                  gmtoff 36000 (getsecs multiplies the hours in int)
 *   TZ B2 ... ok   TZ=No/Such_Zone falls back to GMT: 12:00, "GMT"
 *   TZ B3 GMT ok   gmtime names its zone "GMT" (the GMT file's first
 *                  abbreviation, which a zic -r build makes "-00")
 *   TZ C1 0 ok     mktime inverts localtime at both A instants
 *   TZ C2 ... ok   mktime on 2026-03-08 with tm_isdst -1: 01:30 is EST,
 *                  02:30 falls in the spring-forward gap and is -1, 03:30
 *                  is EDT (the values the vendored Reno ctime.c gives on
 *                  the host with 32-bit long and time_t)
 *   TZ F1 7 ok     difftime(10, 3) is 7.0 (Reno's difftime.c)
 *   TZ D1 n ok     date(1) 2601151200 under TZ=America/New_York sets the
 *                  clock to 2026-01-15 17:00 UTC; n is how many seconds
 *                  past it the clock reads afterwards, 0..3
 *   TZ VERDICT PASS
 * D1 sets the clock (root only; the harness runs as root) and puts it back.
 *
 * `tztest -k' and `tztest -z' run one case each, after the harness has put a
 * zone in /etc/localtime and run adjkerntz -a, so the zone the KERNEL is
 * adjusted to comes from /etc/localtime, as at boot:
 *   TZ E1 off=N diff=M ok   America/New_York: machdep.adjkerntz is minus
 *                           New York's gmtoff now (18000 or 14400), and the
 *                           kernel clock is the battery clock plus it
 *   TZ E2 off=0 diff=M ok   UTC again: the offset is 0, and the kernel clock
 *                           is the battery clock
 * Each run prints its own TZ VERDICT.
 */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <machine/cpu.h>

extern char **environ;
long ticks();

/* Each case points environ at one of these and calls tzset, which reads TZ
 * through getenv. */
static char *env_ny[] = { "TZ=America/New_York", 0 };
static char *env_ten[] = { "TZ=TEN-10", 0 };
static char *env_none[] = { "TZ=No/Such_Zone", 0 };
static int fail;

/* Reno's mktime on 2026-03-08 01:30, 02:30 and 03:30 in America/New_York. */
static long oracle_c2[] = { 1772951400L, -1L, 1772955000L };

/* The kernel writes the frame through (caller bank, offset), so it lives in
 * the data bank.  rtcnow() and mdlong() are timetest's, copied rather than
 * shared: the test must not trust the code it checks. */
static unsigned char rtc[6];            /* sec min hour year day mon */

/* The battery clock as epoch seconds, its local time taken as-is. */
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

/* machdep.<id> as a long (adjkerntz), or -9999 if the read fails. */
static long
mdlong(id)
    int id;
{
    int mib[2];
    long old;
    unsigned len;

    mib[0] = CTL_MACHDEP;
    mib[1] = id;
    len = sizeof(long);
    if (sysctl(mib, 2, &old, &len, (void *)0, 0) < 0 || len != sizeof(long))
        return (-9999L);
    return (old);
}

static void
zone(e)
    char **e;
{
    environ = e;
    tzset();
}

/* One line per case: what localtime made of t, and whether it is what the
 * case expects. */
static void
at(id, t, hh, mm, off, dst, abbr)
    char *id, *abbr;
    long t, off;
    int hh, mm, dst;
{
    struct tm *tm;
    int ok;

    tm = localtime(&t);
    ok = tm->tm_hour == hh && tm->tm_min == mm && tm->tm_gmtoff == off &&
         tm->tm_isdst == dst && strcmp(tm->tm_zone, abbr) == 0;
    printf("TZ %s %02d:%02d %ld %d %s %s\n", id, tm->tm_hour, tm->tm_min,
           tm->tm_gmtoff, tm->tm_isdst, tm->tm_zone, ok ? "ok" : "FAIL");
    if (!ok)
        fail = 1;
}

static void
inverse(id, t)
    char *id;
    long t;
{
    struct tm tm;
    long r;

    tm = *localtime(&t);
    r = mktime(&tm);
    printf("TZ %s %ld %s\n", id, r - t, r == t ? "ok" : "FAIL");
    if (r != t)
        fail = 1;
}

/* E1: machdep.adjkerntz is minus New York's current gmtoff, and the kernel
 * clock is the battery clock plus that offset.  E2: back under UTC, the
 * offset is 0 and the kernel clock is the battery clock again. */
static void
kcheck(id, want_ny)
    char *id;
    int want_ny;
{
    struct timeval now;
    long off, want, diff;

    gettimeofday(&now, (struct timezone *)0);
    off = mdlong(CPU_ADJKERNTZ);
    zone(env_ny);
    want = want_ny ? -localtime(&now.tv_sec)->tm_gmtoff : 0L;
    diff = now.tv_sec - rtcnow() - off;
    printf("TZ %s off=%ld diff=%ld %s\n", id, off, diff,
           off == want && diff >= -2 && diff <= 2 ? "ok" : "FAIL");
    if (off != want || diff < -2 || diff > 2)
        fail = 1;
}

main(argc, argv)
    int argc;
    char **argv;
{
    long t;
    char *s;

    if (argc > 1) {
        if (strcmp(argv[1], "-k") == 0)
            kcheck("E1", 1);
        else if (strcmp(argv[1], "-z") == 0)
            kcheck("E2", 0);
        else
            fail = 1;
        printf("TZ VERDICT %s\n", fail ? "FAIL" : "PASS");
        exit(fail);
    }

    zone(env_ny);
    at("A1", 1768478400L, 7, 0, -18000L, 0, "EST");
    at("A2", 1784116800L, 8, 0, -14400L, 1, "EDT");
    t = 1768478400L;
    s = asctime(localtime(&t));
    printf("TZ A3 %s", strcmp(s, "Thu Jan 15 07:00:00 2026\n") == 0 ?
           "ok\n" : "FAIL\n");
    if (strcmp(s, "Thu Jan 15 07:00:00 2026\n") != 0) {
        printf("TZ A3 got %s", s);
        fail = 1;
    }
    zone(env_ten);
    at("B1", 1768478400L, 22, 0, 36000L, 0, "TEN");
    zone(env_none);
    at("B2", 1768478400L, 12, 0, 0L, 0, "GMT");
    t = 1768478400L;
    s = gmtime(&t)->tm_zone;
    printf("TZ B3 %s %s\n", s, strcmp(s, "GMT") == 0 ? "ok" : "FAIL");
    if (strcmp(s, "GMT") != 0)
        fail = 1;
    zone(env_ny);
    inverse("C1", 1768478400L);
    inverse("C1", 1784116800L);
    {
        struct tm tm;
        long r[3];
        int i, ok;

        ok = 1;
        for (i = 0; i < 3; i++) {
            tm.tm_year = 126; tm.tm_mon = 2; tm.tm_mday = 8;
            tm.tm_hour = 1 + i; tm.tm_min = 30; tm.tm_sec = 0;
            tm.tm_isdst = -1;
            r[i] = mktime(&tm);
            if (r[i] != oracle_c2[i])
                ok = 0;
        }
        printf("TZ C2 %ld %ld %ld %s\n", r[0], r[1], r[2], ok ? "ok" : "FAIL");
        if (!ok)
            fail = 1;
    }
    {
        double d;

        d = difftime(10L, 3L);
        printf("TZ F1 %ld %s\n", (long)d, d == 7.0 ? "ok" : "FAIL");
        if (d != 7.0)
            fail = 1;
    }
    {
        struct timeval save, now;
        long t0, back;
        int pid, st;

        gettimeofday(&save, (struct timezone *)0);
        t0 = ticks();
        zone(env_ny);                   /* date inherits environ */
        if ((pid = fork()) == 0) {
            execl("/bin/date", "date", "2601151200", (char *)0);
            _exit(127);
        }
        while (wait(&st) != pid)
            ;
        gettimeofday(&now, (struct timezone *)0);
        back = now.tv_sec - 1768496400L;
        printf("TZ D1 %ld %s\n", back, back >= 0 && back <= 3 ? "ok" : "FAIL");
        if (back < 0 || back > 3)
            fail = 1;
        save.tv_sec += (ticks() - t0) / 60;         /* put the clock back */
        settimeofday(&save, (struct timezone *)0);
    }
    printf("TZ VERDICT %s\n", fail ? "FAIL" : "PASS");
    exit(fail);
}
