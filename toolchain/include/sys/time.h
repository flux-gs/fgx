/* FGX libc — sys/time.h.  The BSD umbrella time header: on 2.11BSD (which has
 * no standalone <sys/time.h>) the calendar-time struct tm and the time(3)
 * routines are reached through the <sys/time.h> path, so a BSDTIMES port
 * (tcsh tc.sched `localtime()->tm_hour`) that includes only <sys/time.h> still
 * sees struct tm.  Pull it in here (guarded, no field clash with timeval). */
#ifndef _SYS_TIME_H
#define _SYS_TIME_H
#include <time.h>
struct timeval  { long tv_sec; long tv_usec; };
struct timezone { int tz_minuteswest; int tz_dsttime; };
int gettimeofday(struct timeval *tp, struct timezone *tzp);
int settimeofday(struct timeval *tp, struct timezone *tzp);
int adjtime(struct timeval *delta, struct timeval *olddelta);
int select(int nfds, void *rd, void *wr, void *ex, struct timeval *tv);

/* Interval timers.  Field ORDER is upstream's -- it_interval first, then
 * it_value (vendor/2.11BSD/usr/sys/h/time.h:69-72) -- because a port that
 * swapped them would compile and arm the wrong one. */
struct itimerval {
    struct timeval it_interval;         /* reloaded into it_value on expiry */
    struct timeval it_value;            /* time to the next SIGALRM */
};

#define ITIMER_REAL     0               /* wall clock -> SIGALRM */
#define ITIMER_VIRTUAL  1               /* EINVAL in FGX */
#define ITIMER_PROF     2               /* EINVAL in FGX */

/* setitimer(2).  FGX implements ITIMER_REAL only, and reports the old value
 * through `oitv' NOT AT ALL -- see lib/libc_c/itimer.c for both divergences and
 * why a wrong-looking answer was refused in favour of a visible one.  There is
 * no getitimer(2). */
int setitimer(int which, struct itimerval *itv, struct itimerval *oitv);

/*
 * Operations on timevals -- verbatim from 2.11BSD usr/sys/h/time.h.  BSD code
 * expects these from <sys/time.h>; without them `timercmp(&a, &b, >)` parses
 * as a CALL with `>` as an argument ("expected expression"), which is what
 * tcsh sh.proc hit.  timercmp takes the comparison OPERATOR as a macro
 * argument, so it cannot be a function.
 *
 * NB: timercmp does not work for >= or <=.
 */
#define	timerisset(tvp)		((tvp)->tv_sec || (tvp)->tv_usec)
#define	timercmp(tvp, uvp, cmp)	\
	((tvp)->tv_sec cmp (uvp)->tv_sec || \
	 (tvp)->tv_sec == (uvp)->tv_sec && (tvp)->tv_usec cmp (uvp)->tv_usec)
#define	timerclear(tvp)		(tvp)->tv_sec = (tvp)->tv_usec = 0
/* sysctl kern.clockrate's value, 2.11BSD h/time.h:81. */
struct clockinfo {
    int hz;                     /* clock frequency */
    int tick;                   /* micro-seconds per hz tick */
    int stathz;                 /* statistics clock frequency */
    int profhz;                 /* profiling clock frequency */
};

#endif
