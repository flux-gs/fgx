/* FGX libc — sys/resource.h.  BSD getrlimit/getrusage/priority shapes.
 *
 * The limits live in the kernel's per-process u-area and survive fork and exec.
 * RLIMIT_DATA is enforced by the break path, the site Reno checks in obreak
 * (kern/kern_mman.c:342), so tcsh's `limit datasize' does something; the rest
 * are storage that `limit'/`ulimit' read back, and getrusage keeps no
 * accounting (zero-filled).
 */
#ifndef _SYS_RESOURCE_H
#define _SYS_RESOURCE_H

#include <sys/types.h>
#include <sys/time.h>          /* struct timeval */

typedef long rlim_t;

#define RLIMIT_CPU      0       /* CPU time in seconds */
#define RLIMIT_FSIZE    1       /* maximum file size */
#define RLIMIT_DATA     2       /* data size */
#define RLIMIT_STACK    3       /* stack size */
#define RLIMIT_CORE     4       /* core file size */
#define RLIMIT_RSS      5       /* resident set size */
#define RLIMIT_MEMLOCK  6       /* locked-in-memory address space */
#define RLIMIT_NPROC    7       /* number of processes */
#define RLIMIT_NOFILE   8       /* number of open files */
#define RLIM_NLIMITS    9       /* number of resource limits */

#define RLIM_INFINITY   0x7fffffffL

struct rlimit {
    rlim_t rlim_cur;            /* current (soft) limit */
    rlim_t rlim_max;            /* maximum (hard) limit */
};

#define RUSAGE_SELF      0
#define RUSAGE_CHILDREN (-1)

struct rusage {
    struct timeval ru_utime;   /* user time used */
    struct timeval ru_stime;   /* system time used */
    long ru_maxrss;            /* max resident set size */
    long ru_ixrss;             /* shared memory size */
    long ru_idrss;             /* unshared data size */
    long ru_isrss;             /* unshared stack size */
    long ru_minflt;            /* page reclaims */
    long ru_majflt;            /* page faults */
    long ru_nswap;             /* swaps */
    long ru_inblock;           /* block input operations */
    long ru_oublock;           /* block output operations */
    long ru_msgsnd;            /* messages sent */
    long ru_msgrcv;            /* messages received */
    long ru_nsignals;          /* signals received */
    long ru_nvcsw;             /* voluntary context switches */
    long ru_nivcsw;            /* involuntary context switches */
    long ru_ovly;              /* 2.11BSD: overlay swaps (PDP-11); tcsh
                                * sh.time.c reads it -- zero-filled here */
};

#define PRIO_PROCESS  0
#define PRIO_PGRP     1
#define PRIO_USER     2

int getrlimit(int resource, struct rlimit *rlp);
int setrlimit(int resource, struct rlimit *rlp);
int getrusage(int who, struct rusage *rup);
/* wait3(2): BSD reap-with-usage.  Declared HERE rather than in <sys/wait.h>
 * because the prototype needs struct rusage complete, and sys/wait.h is
 * deliberately free of it.  FGX zero-fills the rusage -- see libc_c.c. */
int wait3(int *status, int options, struct rusage *rusage);
int getpriority(int which, int who);
int setpriority(int which, int who, int prio);

#endif /* _SYS_RESOURCE_H */
