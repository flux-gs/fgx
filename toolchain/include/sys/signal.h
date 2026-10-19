/* FGX libc — sys/signal.h.  BSD sigvec/sigmask layer over <signal.h>.
 *
 * <signal.h> is the authoritative source of the SIG* numbers, NSIG, sigmask(),
 * and the sigblock/sigsetmask mask API (REAL since 2026-07-27: kernel-backed
 * 32-bit per-task masks; masked signals stay pending).  This header adds the
 * BSD sigvec(2) shapes BSD
 * sources expect on top of it.  It includes <signal.h>, so including this alone
 * gives a port the whole signal surface.
 */
#ifndef _SYS_SIGNAL_H
#define _SYS_SIGNAL_H

#include <signal.h>            /* SIG* numbers, NSIG, sigmask(), sigblock/sigsetmask */

typedef long sigset_t;          /* 32 signals fit a long */

struct sigvec {
    void  (*sv_handler)();       /* signal handler */
    int     sv_mask;             /* signals to block during the handler */
    int     sv_flags;            /* SV_* behavior flags */
};
#define SV_ONSTACK   0x0001      /* take signal on signal stack */
#define SV_INTERRUPT 0x0002      /* do not restart syscalls */
#define SV_BSDSIG    0x0004      /* BSD signal semantics */
#define SV_RESETHAND 0x0008      /* reset handler to SIG_DFL on delivery */

/* Minimal machine context handed to a handler — FGX does not populate it. */
struct sigcontext {
    int sc_onstack;              /* signal-stack state */
    int sc_mask;                 /* signal mask to restore */
    long sc_pc;                  /* program counter at signal time */
};

int sigvec(int sig, struct sigvec *nvec, struct sigvec *ovec);
long sigpause(long mask);       /* installs `mask`, waits (cooperative yield),
                                 * restores the previous mask.  `long` so bit
                                 * 19 (SIGCHLD) survives -- see signal.h. */

#endif /* _SYS_SIGNAL_H */
