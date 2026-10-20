/* sys/signal.h -- FGX port shim: BSD sigvec/sigmask layer over FGX <signal.h>
 * (which carries the SIG* numbers + NSIG).  FGX signal delivery is being
 * built out (P2 of the tcsh campaign); these give the BSD source its expected
 * shapes, with the libc sigvec/sigblock/sigsetmask backing them. */
#ifndef _FGX_SYS_SIGNAL_H
#define _FGX_SYS_SIGNAL_H
#include <signal.h>

#ifndef sigmask
#define sigmask(n)   (1L << ((n) - 1))   /* 1L, NOT 1: see sigmask_t below */
#endif

typedef long sigset_t;          /* 32 signals fit a long */

/* sigmask_t MUST BE 32 BITS, and nothing else defines it here (apple/fgx#55).
 *
 * tcsh declares its mask variables `sigmask_t`, but every typedef of it in
 * sh.types.h sits behind a platform guard -- `#ifdef sun` and `#ifdef __hpux`
 * -- and this build is -Dpdp11, so NEITHER is taken.  fcc is K&R, so an
 * undeclared type name falls back to implicit `int`, which is 16 bits here.
 *
 * The result was silent and total: `sigmask_t omask = sigblock(...)` compiled
 * to a single 16-bit store (verified in the generated asm -- fcc computed the
 * returned high word into _fcc_long_hi and then never stored it), so every
 * save/restore pair dropped the mask's top half.  SIGCHLD is bit 19, SIGTSTP
 * bit 17, SIGCONT bit 18: `sigsetmask(omask)` therefore UNBLOCKED exactly the
 * job-control signals it was restoring, and sh.proc.c alone has ten of these.
 *
 * Named with tcsh's own _SIGMASK_T guard so a future sh.types.h branch that
 * does define it cannot collide. */
#ifndef _SIGMASK_T
#define _SIGMASK_T
typedef long sigmask_t;
#endif

struct sigvec {
    void  (*sv_handler)();       /* signal handler */
    int     sv_mask;             /* signals to block during handler */
    int     sv_flags;            /* SV_* behavior flags */
};
#define SV_ONSTACK   0x0001
#define SV_INTERRUPT 0x0002
#define SV_BSDSIG    0x0004
#define SV_RESETHAND 0x0008

/* sigblock/sigsetmask are DELIBERATELY ABSENT from this list.  <signal.h>,
 * included above, already declares them `long sigblock(long)` /
 * `long sigsetmask(long)`.  Re-declaring them here as K&R int-returning put a
 * conflicting declaration of the same symbols in every tcsh TU -- the second
 * half of apple/fgx#55, and the half that decides whether a 16-bit value is
 * passed where libc reads 32.  Only the functions <signal.h> does NOT declare
 * belong here. */
extern int  sigvec();
extern long sigpause();
#endif /* _FGX_SYS_SIGNAL_H */
