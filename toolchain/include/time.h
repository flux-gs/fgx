/* FGX libc — time.h.  time(2)-shaped wall clock.
 *
 * time() is gettimeofday(2)'s seconds: the kernel's clock, UTC, set at boot
 * from the IIgs battery clock.  time_t itself is typedef'd in <sys/types.h> (fcc is
 * K&R single-include: no nested #include here — declare with long directly).
 */
#ifndef _TIME_H
#define _TIME_H

/* ANSI C puts time_t in <time.h>; same guarded typedef as <sys/types.h>
 * so either include order works (frotz dumb_input's `time_t start_time`). */
#ifndef _FGX_HAVE_TIME_T
#define _FGX_HAVE_TIME_T
typedef long time_t;    /* Unix epoch seconds */
#endif

/* size_t for strftime()'s maxsize/return -- same typedef as <sys/types.h>
 * and <stdio.h>; fcc permits the duplicate (sys/types.h's own comment). */
typedef unsigned long size_t;

/* 4.3BSD-Reno's broken-down time (include/time.h): tm_gmtoff and tm_zone
 * are the zone localtime applied (lib/libc_c/ctime.c). */
struct tm {
    int tm_sec;     /* 0-59 */
    int tm_min;     /* 0-59 */
    int tm_hour;    /* 0-23 */
    int tm_mday;    /* 1-31 */
    int tm_mon;     /* 0-11 */
    int tm_year;    /* years since 1900 */
    int tm_wday;    /* 0-6, Sunday = 0 */
    int tm_yday;    /* 0-365 */
    int tm_isdst;   /* Daylight Saving Time flag */
    long tm_gmtoff; /* offset from UTC in seconds */
    char *tm_zone;  /* time zone abbreviation */
};

long time(long *t);   /* real prototype: time(0) widens the null under B2 R-to-L */
char *ctime(long *clock);   /* static 26-byte "Www Mmm dd hh:mm:ss yyyy\n" */
struct tm *gmtime(long *clock);      /* static cell (BSD contract) */
struct tm *localtime(long *clock);   /* static cell; TZ, /etc/localtime, GMT */
char *asctime(struct tm *tp);        /* same static cell as ctime */
long mktime(struct tm *tp);          /* local time -> epoch; -1 if none */
double difftime();                   /* (time1, time0): time1 - time0, in seconds */
void tzset();                        /* reread TZ / /etc/localtime */
void tzsetwall();                    /* /etc/localtime, ignoring TZ */
extern char *tzname[2];              /* standard and summer abbreviations */
/* strftime(buf, maxsize, format, tm).  NO PROTOTYPE, and `maxsize' is the one
 * argument that makes that matter: it is a size_t, which is 32 bits here, so a
 * caller passing a plain int literal pushes a 2-byte slot where the callee reads
 * 4 and mis-frames `format' and `tm' behind it.  PASS A size_t -- `sizeof buf'
 * yields one, which is what upstream's own call site does.  Declared empty
 * rather than prototyped because K&R callers in the ported tree declare it
 * themselves and fcc does no widening.
 */
size_t strftime();    /* "%h %e %T " -> "Mon dd hh:mm:ss "; 0 on truncation, buf untouched past maxsize */

#endif /* _TIME_H */
