/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/sys/kern_time.c
 *   Ported from usr/sys/sys/kern_time.c, 2.11BSD, with FreeBSD 2.2.8's
 *   inittodr (sys/i386/isa/clock.c).  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* kern_time.c -- the kernel's time of day, in the TTY bank.
 *
 * THE CLOCK ITSELF IS FOUR CORE WORDS AND ONE ADD.  `_kTodSec' and `_kTodFrac'
 * (include/memmap.s) hold UTC as 32.32 fixed-point seconds, and the heartbeat
 * adds `_kTickFrac', one VBL, every tick (src/kernel/toolbox.s) -- 4.3BSD-Reno
 * kern_clock.c:223's `BUMPTIME(&time, tick)' in a binary fraction.  This file
 * is everything else, reaching those words only through kc_todsnap,
 * kc_todstore and kc_tickset (kc_sys.s), which copy them under SEI.
 *
 * WHY THIS BANK: it has the room (docs/history/plans/tty-kernel-bank.md, "Tenants other
 * than the tty layer").  Nothing here touches a tty.
 *
 * `tick' is Reno's, microseconds per clock interrupt, and NOT 2.11BSD's
 * integer hz: the VBL is not exactly 60 Hz on the machine, and a clock that
 * assumed it would drift.  An NTSC IIgs scans 262 lines of 912 master clocks
 * at 14.31818 MHz: 59.923 Hz, 16,688 us, which clkrate measures on the
 * machine (16,688.5 us over 600 s).  MAME's VBL is 60.000 Hz, so its clock
 * runs 1,300 ppm fast; machdep.tick sets 16667 there, and 20000 at 50 Hz.
 *
 * THIS BANK'S STATICS ARE NOT ZEROED AT LOAD (docs/history/plans/tty-kernel-bank.md, section
 * 4), so every global here has an initializer, which puts its value in the
 * image rather than leaving whatever the Memory Manager left.
 */
#include "../vfs/kern_epoch.c"          /* kern_epoch: a local date -> seconds */

extern void kc_todsnap(), kc_todstore(), kc_tickset(), kc_rtcread(),
            kc_rtcwrite(), kc_log();
extern long kc_rootfstime();
extern int  kc_uid();

unsigned      tod_snap[6] = { 0, 0, 0, 0, 0, 0 };  /* kc_todsnap: sec, frac, ticks */
unsigned      tod_new[4] = { 0, 0, 0, 0 };         /* kc_todstore: sec, frac */
unsigned      tod_tick[2] = { 0, 0 };              /* kc_tickset: _kTickFrac */
unsigned char tod_rtc[6] = { 0, 0, 0, 0, 0, 0 };   /* kc_rtcread/write: the RTC's frame */
unsigned      tod_rtcsp = 0;                       /* kc_rtc*: the caller's S */

int tod_valid = 0;                      /* the clock has been set */
int tick = 16688;                       /* us per VBL: Reno's `tick' */
int tz_minuteswest = 0;                 /* 2.11BSD conf/param.c:40's `tz' */
int tz_dsttime = 0;
long adjkerntz = 0;                     /* FreeBSD clock.c:100's int, which is
                                         * 32 bits there: a zone ten hours out
                                         * is 36,000 s */
int disable_rtc_set = 0;                /* FreeBSD clock.c:101 */
int wall_cmos_clock = 1;                /* FreeBSD clock.c:119; the IIgs clock
                                         * holds LOCAL time */

/* adjtime's slew, FreeBSD 2.2.8's (vendor/FreeBSD-2.2.8/sys/kern/
 * kern_time.c): `timedelta', the correction still owed in us; `tickdelta',
 * the signed us added per tick while it is; `tickadj', the standard rate,
 * 4.3BSD-Reno conf/param.c:63's `240000 / (60 * HZ)' -- 240 ms a minute --
 * at 60 Hz; and `bigadj', above which the rate is ten times that. */
#define TICKADJ         (240000 / (60 * 60))
#define BIGADJ          1000000L
long     timedelta = 0L;
long     boottime;                      /* 2.11BSD's `boottime', its tv_sec:
                                         * tv_usec is 0, the clock having
                                         * just been written with 0 */
long     tickdelta = 0L;
unsigned tod_adjt0[2] = { 0, 0 };       /* _kSystemTicks when it began */

/* frac (2^-32 s) <-> usec, on the fraction's high word: 1e6 / 65536 is
 * 15625 / 1024, so a step of about 15 us. */
static long
tod_usec(hi)
    unsigned hi;
{
    return (((long)hi * 15625L) >> 10);
}

static unsigned
tod_frachi(usec)
    long usec;
{
    return ((unsigned)((usec << 10) / 15625L));
}

/* One VBL in 2^-32 s: us * 2^32 / 1e6, as (us << 16) / 15625, then << 10,
 * carrying the remainder so the answer is exact to the last bit. */
static void
tod_settick(us)
    int us;
{
    long a, hi, rem, v;

    a = (long)us << 16;
    hi = a / 15625L;
    rem = a % 15625L;
    v = (hi << 10) + ((rem << 10) / 15625L);
    tod_tick[0] = (unsigned)v;
    tod_tick[1] = (unsigned)(v >> 16);
    kc_tickset();
}

/* How much of the slew the clock has taken since it began, as of the
 * snapshot in tod_snap.  FreeBSD's hardclock adds `tick + tickdelta' each
 * tick and takes tickdelta off timedelta until it is 0; here the same sum is
 * worked out when someone reads the clock, so the interrupt pays nothing.
 * adjtime rounds timedelta to a whole number of tickdeltas, so the count of
 * ticks it needs is exact and the sum stops at timedelta. */
static long
tod_applied()
{
    long now, n, need;

    if (timedelta == 0L || tickdelta == 0L)
        return (0L);
    now = (long)tod_snap[4] | ((long)tod_snap[5] << 16);
    n = now - ((long)tod_adjt0[0] | ((long)tod_adjt0[1] << 16));
    need = timedelta / tickdelta;
    if (n >= need)
        return (timedelta);
    return (n * tickdelta);
}

/* The clock as a timeval: the core's time plus the slew taken so far. */
static void
tod_read(sec, usec)
    long *sec;
    long *usec;
{
    long s, u;

    kc_todsnap();
    s = (long)tod_snap[0] | ((long)tod_snap[1] << 16);
    u = tod_usec(tod_snap[3]) + tod_applied();
    s = s + u / 1000000L;
    u = u % 1000000L;
    if (u < 0L) {
        u = u + 1000000L;
        s = s - 1L;
    }
    *sec = s;
    *usec = u;
}

static void
tod_write(sec, usec)
    long sec;
    long usec;
{
    tod_new[0] = (unsigned)sec;
    tod_new[1] = (unsigned)(sec >> 16);
    tod_new[2] = 0;
    tod_new[3] = tod_frachi(usec);
    kc_todstore();
}

/* Fold the slew taken so far into the core's clock and restart the count
 * from now, so what is still owed is timedelta and nothing is counted twice.
 * Done before anything replaces the clock or the slew; returns the clock as
 * read, which the fold does not change. */
static void
tod_fold(sec, usec)
    long *sec;
    long *usec;
{
    tod_read(sec, usec);
    timedelta = timedelta - tod_applied();
    tod_adjt0[0] = tod_snap[4];
    tod_adjt0[1] = tod_snap[5];
    tod_write(*sec, *usec);
}

/* What a local-time wall clock is behind UTC: FreeBSD clock.c:755 and :788,
 * `tz.tz_minuteswest * 60 + (wall_cmos_clock ? adjkerntz : 0)'. */
static long
tod_localoff()
{
    return ((long)tz_minuteswest * 60L +
            (wall_cmos_clock ? adjkerntz : 0L));
}

/* inittodr -- set the clock at boot, from the root filesystem and then the
 * battery clock.  2.11BSD's order, straight after mounting the root
 * (usr/sys/sys/init_main.c:197):
 *
 *      time.tv_sec = fs->fs_time;
 *      if (toytime = toyclk())
 *              time.tv_sec = toytime;
 *
 * which is FreeBSD's inittodr(base) (clock.c:709): `time.tv_sec = base', then
 * the RTC's local seconds made UTC by the offset, or a complaint and the base
 * kept when the RTC does not hold a valid time.  The core calls this through
 * tty slot 43 once the root is mounted; `_kRootFsTime' is 0 when it was not. */
void
tod_init()
{
    long sec;

    tod_settick(tick);
    boottime = kc_rootfstime();
    tod_write(boottime, 0L);
    kc_rtcread();
    sec = kern_epoch(1900 + (int)tod_rtc[3], (int)tod_rtc[5] + 1,
                     (int)tod_rtc[4] + 1, (int)tod_rtc[2], (int)tod_rtc[1],
                     (int)tod_rtc[0]);
    if (sec == 0L) {
        kc_log("Invalid time in real time clock.\n");
        kc_log("Check and reset the date immediately!\n");
    } else {
        boottime = sec + tod_localoff();
        tod_write(boottime, 0L);
        tod_valid = 1;
    }
}

/* gettimeofday -- 2.11BSD kern_time.c:22.  `time' and `tz' copied out whole:
 * blk[0] tv_sec, blk[1] tv_usec, then tz_minuteswest and tz_dsttime as two
 * ints.  libc's wrapper hands on only what its caller asked for, which is
 * upstream's `if (uap->tp)' / `if (uap->tzp)'.  blk names the caller's bank
 * (the core stub supplies it), so this is the copyout.  Always succeeds. */
int
tod_gettimeofday(blk)
    long *blk;
{
    long s, u;

    tod_read(&s, &u);
    blk[0] = s;
    blk[1] = u;
    ((int *)blk)[4] = tz_minuteswest;
    ((int *)blk)[5] = tz_dsttime;
    return (0);
}

/* The battery clock's frame for local seconds t: kern_epoch's inverse, by
 * FreeBSD resettodr's walk (clock.c:790-815) -- years from 1970, then
 * months, a leap year every fourth (exact 1901-2099).  Returns 0 when t
 * falls outside what the frame's year byte (year - 1900) can hold. */
static int
tod_frame(t)
    long t;
{
    static char dim[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    long days;
    int y, m, ml;

    if (t < 0L)
        return (0);
    tod_rtc[0] = (unsigned char)(t % 60L);
    t = t / 60L;
    tod_rtc[1] = (unsigned char)(t % 60L);
    t = t / 60L;
    tod_rtc[2] = (unsigned char)(t % 24L);
    days = t / 24L;
    for (y = 1970; ; y++) {
        ml = (y & 3) ? 365 : 366;
        if (days < (long)ml)
            break;
        days = days - (long)ml;
    }
    if (y - 1900 > 255)
        return (0);
    for (m = 0; ; m++) {
        ml = dim[m];
        if (m == 1 && (y & 3) == 0)
            ml++;
        if (days < (long)ml)
            break;
        days = days - (long)ml;
    }
    tod_rtc[3] = (unsigned char)(y - 1900);
    tod_rtc[4] = (unsigned char)days;           /* day of the month - 1 */
    tod_rtc[5] = (unsigned char)m;              /* month - 1 */
    return (1);
}

/* resettodr -- write the clock back to the battery clock, in local time:
 * FreeBSD clock.c:771, `tm -= tz.tz_minuteswest * 60 + (wall_cmos_clock ?
 * adjkerntz : 0)' (:788), unless disable_rtc_set.  FreeBSD calls it from
 * settimeofday (kern_time.c:144) and from a write to machdep.adjkerntz
 * (machdep.c:716), and not at reboot: its boot() syncs and unmounts and
 * leaves the RTC alone (kern_shutdown.c:174). */
void
resettodr()
{
    long s, u;

    if (disable_rtc_set)
        return;
    tod_read(&s, &u);
    if (tod_frame(s - tod_localoff()))
        kc_rtcwrite();
}

/* settimeofday -- the super user sets the time, the zone, or both; the core
 * thunk has already asked, as FreeBSD asks suser first (kern_time.c:105) and
 * 2.11BSD asks in both halves (kern_time.c:67, :80).  blk, in the caller's
 * bank: a flags word (bit 0 = a time, bit 1 = a zone), tv_sec, tv_usec,
 * tz_minuteswest, tz_dsttime.
 *
 * FreeBSD's order: everything is checked before anything changes -- a
 * tv_usec outside 0..999999 is EINVAL (kern_time.c:111) -- then the time is
 * set (2.11BSD's setthetime, kern_time.c:75) and written back to the battery
 * clock (resettodr, kern_time.c:144), then the zone.  `boottime' moves with
 * the step, as 2.11BSD's does (kern_time.c:101), so kern.boottime keeps
 * naming the same instant.  SYS_UPTIME (#51) does not read it: it pairs the
 * battery clock's boot snapshot with the battery clock now. */
int
tod_settimeofday(blk)
    char *blk;
{
    int flags;
    long sec, usec;

    flags = *(int *)blk;
    sec = *(long *)(blk + 2);
    usec = *(long *)(blk + 6);
    if ((flags & 1) && (usec < 0L || usec >= 1000000L))
        return (EINVAL);
    if (flags & 1) {
        long os, ou;

        tod_fold(&os, &ou);             /* a slew in progress carries on */
        boottime += sec - os;           /* 2.11BSD kern_time.c:101 */
        tod_write(sec, usec);
        tod_valid = 1;
        resettodr();
    }
    if (flags & 2) {
        tz_minuteswest = *(int *)(blk + 10);
        tz_dsttime = *(int *)(blk + 12);
    }
    return (0);
}

/* adjtime -- slew the clock by a delta rather than step it, and report what
 * the previous call still owed.  FreeBSD 2.2.8 kern_time.c's, whose rounding
 * this needs: 4.3BSD-Reno's (kern_time.c:100) rounds to a multiple of
 * tickadj while slewing ten times faster above bigadj, so a large correction
 * need not be a whole number of steps and overshoots, and it picks the rate
 * only when no slew is running.  FreeBSD picks it every call, the same way
 * either side of zero, and rounds to a multiple of the rate itself, "lest the
 * correction overshoot".  The super user only (2.11BSD kern_time.c:123),
 * asked by the core thunk.  blk: delta (tv_sec, tv_usec) in, olddelta out. */
int
tod_adjtime(blk)
    long *blk;
{
    long ndelta, ntickdelta, odelta, s, u;

    ndelta = blk[0] * 1000000L + blk[1];
    if (ndelta > BIGADJ || ndelta < -BIGADJ)
        ntickdelta = 10L * TICKADJ;
    else
        ntickdelta = TICKADJ;
    if (ndelta % ntickdelta)
        ndelta = ndelta / ntickdelta * ntickdelta;
    if (ndelta < 0L)
        ntickdelta = -ntickdelta;
    tod_fold(&s, &u);
    odelta = timedelta;
    timedelta = ndelta;
    tickdelta = ntickdelta;
    blk[2] = odelta / 1000000L;
    blk[3] = odelta % 1000000L;
    return (0);
}

/* The machdep sysctl leaves: FreeBSD 2.2.8's ids (i386/include/cpu.h:127-131)
 * for its variables (i386/i386/machdep.c:709-730), mirrored from userland's
 * <machine/cpu.h>, and machdep.tick, FGX's own at the id FreeBSD's CPU_MAXID
 * leaves free: the rate the clock advances at, set when the machine's VBL is
 * measured (clkrate). */
#define CTL_MAXNAME     12
#define CPU_ADJKERNTZ   2
#define CPU_DISRTCSET   3
#define CPU_WALLCLOCK   5
#define CPU_TICK        6
#define SYSCTL_OLDP     0x0001
#define SYSCTL_NEWP     0x0002
#define CTL_KERN        1
#define KERN_CLOCKRATE  12
#define KERN_BOOTTIME   21

/* sysctl(2)'s machdep node.  The core routes a name whose first part is
 * CTL_MACHDEP here, as 2.11BSD's __sysctl switches to cpu_sysctl
 * (kern_sysctl.c:131); everything else goes to root_sysctl in the far bank,
 * whose block this is: name[0], name[1], namelen, flags, oldlen, newlen, and
 * the value both in and out, from word 6.  kern.clockrate and kern.boottime
 * are routed here too, for the clock's rate and its boot reading.
 *
 * The checks are __sysctl's and cpu_sysctl's in their order: a write needs
 * the super user (kern_sysctl.c:100), the name length is bounded, every name
 * at this level is terminal (ENOTDIR), an unknown one is EOPNOTSUPP -- FGX's
 * ENOTSUP, the same 45 -- and sysctl_int's length rules follow, for an int of
 * 2 bytes or, for adjkerntz, the 4 of a long: FreeBSD serves it with
 * sysctl_handle_int (machdep.c:710-721) on a 32-bit int.  A write to
 * adjkerntz writes the battery clock back, as FreeBSD's handler does
 * (machdep.c:716); one to tick takes effect at the next VBL. */
int
tod_sysctl(blk)
    int *blk;
{
    int flags, namelen, size, *var;
    long newval;

    flags = blk[3];
    namelen = blk[2];
    if ((flags & SYSCTL_NEWP) && kc_uid() != 0)
        return (EPERM);
    if (namelen > CTL_MAXNAME || namelen < 2)
        return (EINVAL);
    if (namelen != 2)
        return (ENOTDIR);
    /* kern.clockrate, 2.11BSD kern_sysctl.c's sysctl_clockrate: a struct
     * clockinfo, read only through sysctl_rdstruct's tests in their order.
     * hz is upstream's integer rate; this clock keeps `tick' instead, so hz
     * is tick rounded to whole hertz -- 60 on an NTSC machine, 50 on PAL.
     * stathz is hz and profhz 0, as upstream fills them. */
    if (blk[0] == CTL_KERN) {
        if ((flags & SYSCTL_OLDP) && blk[4] < 8)
            return (ENOMEM);
        if (flags & SYSCTL_NEWP)
            return (EPERM);
        blk[4] = 8;             /* sizeof (struct clockinfo), (struct timeval) */
        if (blk[1] == KERN_BOOTTIME) {
            /* kern_sysctl.c:250, sysctl_rdstruct of `boottime' */
            *(long *)(blk + 6) = boottime;
            *(long *)(blk + 8) = 0L;
            return (0);
        }
        blk[6] = (int)((1000000L + tick / 2) / tick);   /* hz */
        blk[7] = tick;
        blk[8] = blk[6];                        /* stathz */
        blk[9] = 0;                             /* profhz */
        return (0);
    }
    var = 0;
    size = 2;                                   /* sizeof(int) */
    switch (blk[1]) {
    case CPU_ADJKERNTZ: size = 4;               break;  /* sizeof(long) */
    case CPU_DISRTCSET: var = &disable_rtc_set; break;
    case CPU_WALLCLOCK: var = &wall_cmos_clock; break;
    case CPU_TICK:      var = &tick;            break;
    default:
        return (ENOTSUP);
    }
    if ((flags & SYSCTL_OLDP) && blk[4] < size)
        return (ENOMEM);
    if ((flags & SYSCTL_NEWP) && blk[5] != size)
        return (EINVAL);
    if (size == 4)
        newval = ((long)blk[7] << 16) | ((long)blk[6] & 0xFFFFL);
    else
        newval = blk[6];
    if ((flags & SYSCTL_NEWP) && blk[1] == CPU_TICK && newval <= 0)
        return (EINVAL);
    blk[4] = size;
    if (size == 4) {
        blk[6] = (int)adjkerntz;
        blk[7] = (int)(adjkerntz >> 16);
    } else
        blk[6] = *var;
    if (flags & SYSCTL_NEWP) {
        if (blk[1] == CPU_TICK) {
            tick = (int)newval;
            tod_settick(tick);
        } else if (blk[1] == CPU_ADJKERNTZ) {
            adjkerntz = newval;
            resettodr();
        } else
            *var = (int)newval;
    }
    return (0);
}

/* The clock's seconds for kernel C in a module (KSVC_TIME, tty slot 48):
 * UTC, which UFS stamps with as 2.11BSD does, or local time -- UTC less the
 * offset resettodr writes the battery clock with -- which ProDOS stamps
 * with, GS/OS reading its dates as local. */
long
tod_now(local)
    int local;
{
    long s, u;

    tod_read(&s, &u);
    if (local)
        s = s - tod_localoff();
    return (s);
}
