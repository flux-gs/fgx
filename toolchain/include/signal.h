/* FGX libc — signal.h.  Signal numbers + signal(2) for BSD ports.
 *
 * Signal NUMBERS mirror the kernel's include/loader.s "Full BSD set"
 * (2.11BSD <sys/signal.h> numbering) -- the authoritative source.
 *
 * WHICH SIGNALS CAN YOU ACTUALLY CATCH?  Exactly these five:
 *
 *     SIGINT  SIGALRM  SIGCHLD  SIGTERM  SIGHUP
 *
 * They are the ones with a per-task handler table in the kernel (signal.s
 * _SigHndBase).  For every OTHER signal, signal(sig, SIG_DFL) and
 * signal(sig, SIG_IGN) are REAL -- the kernel keeps a per-task ignore mask
 * covering all 32 -- but signal(sig, my_handler) is accepted and never
 * delivered.  Do not build a feature on one: check this list first.  init(8)
 * did not, believed signal(SIGTERM, ...), and shipped two dead handlers
 * (apple/fgx#26, closed 2026-08-04 by making TERM/HUP real).
 *
 * A handler body may ONLY set a plain int flag and return -- delivery is
 * synchronous at syscall exit on top of whatever libc call it interrupted.
 * See docs/userland-abi.md section 6A before writing one.
 *
 * signal() SIGNATURE NOTE: the faithful prototype is
 *     void (*signal(int sig, void (*func)()))();
 * i.e. a function RETURNING a signal-handler pointer.  fcc cannot yet declare a
 * function whose return type is a function pointer (parse_func_decl_with_spec has
 * no LT_FN_PTR return branch), so the return type is spelled `char *`: still a
 * 4-byte FAR pointer, so the previous handler survives the round trip and a
 * caller that saves/restores it works.
 *
 * It was declared int-returning until 2026-07-26, and that was a LANDMINE, not
 * merely lossy: libc DEFINES signal() as `char *signal(...)` (libc_c.c), so the
 * declaration and the definition disagreed on the return WIDTH -- 2 bytes vs 4.
 * Nothing caught it while no TU saw both, but the moment libc_c.c itself included
 * <sys/signal.h> (which includes this file) every call to signal() inside the
 * shared libc pile took the int-return path against a far-pointer definition.
 * init died before the console existed, so all 15 failsafe tests came back as a
 * blank screen with no diagnostic.  Keep this declaration and the libc_c.c
 * definition IDENTICAL.
 */
#ifndef _SIGNAL_H
#define _SIGNAL_H

#define SIGHUP          1       /* hangup */
#define SIGINT          2       /* interrupt (Ctrl-C) */
#define SIGQUIT         3       /* quit (Ctrl-\) */
#define SIGILL          4       /* illegal instruction */
#define SIGTRAP         5       /* trace trap */
#define SIGABRT         6       /* abort() */
#define SIGEMT          7       /* emulator trap */
#define SIGFPE          8       /* arithmetic exception */
#define SIGKILL         9       /* uncatchable terminate */
#define SIGBUS          10      /* bus error */
#define SIGSEGV         11      /* segmentation violation */
#define SIGSYS          12      /* bad argument to syscall */
#define SIGPIPE         13      /* write to closed pipe */
#define SIGALRM         14      /* alarm timer expired */
#define SIGTERM         15      /* software termination */
#define SIGURG          16      /* urgent condition on socket */
#define SIGSTOP         17      /* uncatchable stop */
#define SIGTSTP         18      /* keyboard stop (Ctrl-Z) */
#define SIGCONT         19      /* continue if stopped */
#define SIGCHLD         20      /* child stopped/exited */
#define SIGTTIN         21      /* background read from tty */
#define SIGTTOU         22      /* background write from tty */
#define SIGIO           23      /* I/O possible */
/* Tail of the 2.11BSD set (values from examples/2.11BSD usr/include/signal.h).
 * FGX loader.s currently stops at SIGIO=23; these are accept-but-inert on FGX
 * (no CPU/file-size limits, profiling, window-size, or user signals) and
 * loader.s should be extended to match when real delivery lands. */
#define SIGXCPU         24      /* exceeded CPU time limit (inert on FGX) */
#define SIGXFSZ         25      /* exceeded file size limit (inert on FGX) */
#define SIGVTALRM       26      /* virtual time alarm (inert on FGX) */
#define SIGPROF         27      /* profiling timer (inert on FGX) */
#define SIGWINCH        28      /* window size change (inert on FGX) */
#define SIGUSR1         30      /* user-defined 1 (inert on FGX) */
#define SIGUSR2         31      /* user-defined 2 (inert on FGX) */

/* One past the highest signal number, as on 2.11BSD (which also uses 32).
 * BSD code sizes per-signal tables with it (`char sigs[NSIG]`) and loops
 * `for (i = 1; i < NSIG; i++)`, so it must stay ONE PAST the largest SIG*
 * above -- bump it if a signal beyond 31 is ever added. */
#ifndef NSIG
#define NSIG            32
#endif

/* sys_siglist(3): the signal names, indexed by signal number, NSIG of them.
 * 2.11BSD's own table (libc_c/siglist.c).  A tool that waits on a child and
 * reports how it died reads this -- mount(8) does. */
extern char *sys_siglist[];

#define SIG_DFL         (0)     /* default action */
#define SIG_IGN         (1)     /* ignore signal */

char *signal(int sig, char *handler);/* returns the PREVIOUS handler; see the
                                        SIGNATURE NOTE.
                                        Real arg prototype (was empty-paren `signal()`)
                                        so a null-pointer-constant handler (SIG_DFL/
                                        SIG_IGN) widens to a 4-byte far ptr — under the
                                        B2 uniform-R-to-L ABI an empty-paren decl no
                                        longer mismatches the pile's ordering, but the
                                        arg WIDTH still needs the prototype. */
int kill(int pid, int sig);     /* kill(pid, sig) — SYS_KILL #37 */

/* BSD signal-mask API — REAL as of 2026-07-27 (SYS_SIGSETMASK #102): the
 * kernel keeps a per-task 32-bit mask (bit n-1 blocks signal n, the sigmask()
 * convention) and leaves masked signals PENDING until unmasked.  All three
 * take/return `long` — the 32-bit mask is what makes sigmask(SIGCHLD) = bit
 * 19 survive; the old int prototypes truncated it to nothing, which is how
 * tcsh's pfork "blocked" SIGCHLD without blocking anything.  The returned old
 * mask comes from a libc-side shadow (single-threaded per task). */
long sigblock(long mask);
long sigsetmask(long mask);

/* sigprocmask(2).  `how' values MATCH the kernel's (include/loader.s), so the
 * wrapper passes them straight through; SIG_SETMASK is 0 because that is what
 * SYS_SIGSETMASK's existing callers already send as their third argument.
 *
 * A null `set' means "tell me the mask and change nothing", which POSIX
 * requires and the kernel spells SIG_QUERY. */
typedef long sigset_t;

#define SIG_SETMASK     0       /* replace the mask */
#define SIG_BLOCK       1       /* old | new */
#define SIG_UNBLOCK     2       /* old & ~new */
#define SIG_QUERY       3       /* read it back, change nothing (a null `set') */

/* The signals no task may block -- `sigcantmask' in BSD
 * (2.11BSD usr/sys/h/signalvar.h:121), bit (s-1) as the mask convention here
 * uses: SIGKILL is 9 and SIGSTOP is 17.  The KERNEL enforces this on the write
 * (apple/fgx#471); this copy only keeps libc's shadow of the mask honest, so a
 * drift would make the shadow optimistic and never make a task unkillable. */
#define SIG_CANTMASK    (0x00000100L | 0x00010000L)

int sigprocmask(int how, sigset_t *set, sigset_t *oset);
int sigsuspend(sigset_t *set);

/* HERE AND NOT IN <sys/signal.h>, WHICH IS WHERE 2.11BSD KEEPS IT.  FGX's
 * layering is the inverse of upstream's: this file is authoritative for the SIG*
 * numbers, NSIG, sigmask() and the mask API, and <sys/signal.h> includes it to
 * add the sigvec shapes.  Putting struct sigaction there would leave it
 * invisible to a port that includes <signal.h> alone -- which syslogd(8) does,
 * and which upstream serves because ITS <signal.h> pulls in <sys/signal.h>.
 * Reversing that here would be a circular include; keeping sigaction beside
 * sigset_t and sigprocmask is the arrangement this tree already has.
 */
/* sigaction(2) -- the POSIX form, and the one a port should reach for: its
 * sa_mask is a full sigset_t where sigvec's sv_mask is an int, which on a
 * 16-bit-int machine cannot express SIGSTOP (17) upward.  2.11BSD carries
 * sigaction as syscall 31 and marks 108 "(old sigvec)" for the same reason.
 *
 * FGX honours sa_handler and sa_mask.  THE FLAGS ARE RECORDED AND REPORTED BUT
 * NOT ALL ACTED ON, and lib/libc_c/sigaction.c says which and why:
 *   SA_RESTART   -- always in force; FGX restarts a marked syscall
 *                   unconditionally, so its ABSENCE is what cannot be expressed.
 *   SA_NOCLDSTOP -- not honoured: FGX posts SIGCHLD for stopped children as well
 *                   as dead ones, deliberately, and suppressing it needs kernel
 *                   state this does not add.
 *   SA_ONSTACK   -- ignored; there is no sigaltstack(2) here.
 */
struct sigaction {
    void   (*sa_handler)();      /* SIG_DFL, SIG_IGN, or a handler */
    sigset_t sa_mask;            /* blocked FOR THE HANDLER'S DURATION */
    int      sa_flags;           /* SA_* below */
};
#define SA_ONSTACK   0x0001      /* ignored: no signal stack in FGX */
#define SA_RESTART   0x0002      /* always in force here */
#define SA_NOCLDSTOP 0x0004      /* recorded, not honoured */

int sigaction(int sig, struct sigaction *nsa, struct sigaction *osa);
int sigemptyset(sigset_t *set);
int sigfillset(sigset_t *set);
int sigaddset(sigset_t *set, int sig);
int sigdelset(sigset_t *set, int sig);
int sigismember(sigset_t *set, int sig);


#define sigmask(n)  (1L << ((n) - 1))

#endif /* _SIGNAL_H */
