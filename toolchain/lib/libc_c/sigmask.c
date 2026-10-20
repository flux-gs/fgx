/* sigblock/sigsetmask/sigpause — BSD signal-mask API, REAL since 2026-07-27.
 * The kernel (SYS_SIGSETMASK #102) keeps a per-task 32-bit mask in the BSD
 * sigmask() convention (bit n-1 blocks signal n) and leaves masked signals
 * PENDING; they deliver at the first syscall exit after unmasking.  The OLD
 * mask is tracked in a libc-side shadow -- tasks are single-threaded, so the
 * shadow cannot race, and it keeps the kernel handler store-only.
 *
 * Why this exists: tcsh's pfork does sigblock(sigmask(SIGCHLD)) around
 * fork + palloc.  FGX's fork is a sequential snapshot-fork -- the child can
 * run to completion before fork() returns -- so without a real mask the
 * SIGCHLD delivered AT THE FORK SYSCALL'S OWN EXIT, pchild reaped a pid the
 * shell had not recorded yet, and the job stayed PRUNNING forever (the
 * interactive-pipeline hang).  Note the `long` types: sigmask(SIGCHLD) is
 * bit 19, which the old int prototypes silently truncated away. */
/* The shadow lives in lib/libc_data.s, not here: crt0's signal trampoline must
 * reach it in every binary, and the archive carve only pulls this member's data
 * into binaries that call sigblock().  See apple/fgx#53. */
#include <errno.h>
#include <signal.h>

extern long _sig_curmask;               /* shadow; 0 at exec = kernel state */

/* The process's own disposition table (lib/libc_data.s), which signal.c
 * writes and _sig_query below reads.  DECLARED IN BOTH MEMBERS on purpose:
 * the archive carve compiles each member SOLO, so a name it does not own has
 * to be visible from its own source -- this used to be a signal.c static
 * (_sig_disp) that sigmask.c reached only because the pile is one TU. */
extern char *_sig_c_tab[];

long sigsetmask(long mask)
{
    long old = _sig_curmask;

    _sig_curmask = mask;
    (void)__syscall(102, (int)mask, (int)(mask >> 16), 0);
    return old;
}

long sigblock(long mask)
{
    return sigsetmask(_sig_curmask | mask);
}

/* sigprocmask(2) -- SYS_SIGPROCMASK (#120), the same kernel routine as #102
 * with a real `how'.  This is the call syslogd's main loop is built on, and it
 * is the one that can BLOCK atomically: sigblock() above computes its new mask
 * in userland from the shadow, so a signal arriving mid-computation is a race
 * crt0's trampoline has to compensate for (see its _sig_curmask save).  Here
 * the kernel does the read-modify-write with interrupts its own problem.
 *
 * The old mask comes back 32 bits wide in A + Y, the return-hi convention
 * lseek() also uses; __syscall_y() reads the high half.
 *
 * THE SHADOW IS KEPT IN STEP so a program may mix this with sigblock() and
 * sigsetmask().  The new mask is recomputed here rather than returned by the
 * kernel, because the registers are spent carrying the old one out -- and the
 * kernel is still the authority on SIG_CANTMASK, so if these two ever disagree
 * the shadow is merely optimistic and a task never becomes unkillable. */
int sigprocmask(int how, sigset_t *set, sigset_t *oset)
{
    long newmask;
    long old;
    int khow;

    if (set == (sigset_t *)0) {
        khow = SIG_QUERY;               /* POSIX: report, change nothing */
        newmask = 0;
    } else {
        if (how != SIG_SETMASK && how != SIG_BLOCK && how != SIG_UNBLOCK) {
            errno = EINVAL;
            return (-1);
        }
        khow = how;
        newmask = *set;
    }

    old = (long)(unsigned long)(unsigned int)__syscall(120, (int)newmask,
                                                       (int)(newmask >> 16),
                                                       khow);
    if (__syscall_c() == 0) {
        errno = (int)old;
        return (-1);
    }
    old |= ((unsigned long)__syscall_y() << 16);

    if (khow == SIG_SETMASK)
        _sig_curmask = newmask & ~SIG_CANTMASK;
    else if (khow == SIG_BLOCK)
        _sig_curmask = old | (newmask & ~SIG_CANTMASK);
    else if (khow == SIG_UNBLOCK)
        _sig_curmask = old & ~newmask;

    if (oset != (sigset_t *)0)
        *oset = old;
    return (0);
}

/* sigpause(mask): BSD "install mask, wait for a signal, restore, return".
 *
 * REAL SINCE apple/fgx#59.  This used to be sigsetmask(new) + SYS_YIELD +
 * sigsetmask(old), and neither half of sigsuspend's promise survived that
 * shape.  The install and the wait were not ATOMIC, so the awaited signal
 * could arrive between them, be handled, and leave the yield waiting for one
 * that had already been and gone.  And SYS_YIELD is not a wait -- it returns
 * at once -- so a bare "pause until the signal" spun at 60 Hz.  It worked only
 * because csh-family callers loop around it; any vendored code that pauses
 * once and expects to block burned a core instead.
 *
 * SYS_SIGPAUSE installs the mask and sleeps inside ONE syscall, which is where
 * the atomicity comes from, and returns EINTR unconditionally -- 2.11BSD's
 * sigsuspend does both, and its comment for the second is "always return EINTR
 * rather than ERESTART".
 *
 * THE SHADOW IS SET BEFORE THE CALL AND RESTORED AFTER IT, and the order
 * matters for more than bookkeeping.  FGX delivers signals at SYSCALL EXIT, so
 * by the time the syscall returns here the handler HAS ALREADY RUN -- it ran
 * with the pause mask in force, and the caller's mask goes back afterwards.
 * That is exactly what BSD needs SAS_OLDMASK/u_oldmask and a sigreturn-time
 * install to achieve; FGX gets the same ordering from where delivery happens.
 * Returns -1/EINTR. */
long sigpause(long mask)
{
    long old = _sig_curmask;

    /* Shadow only -- do NOT sigsetmask() here.  That would install the mask in
     * a separate syscall and re-open the window this exists to close; the
     * kernel side of SYS_SIGPAUSE does the install. */
    _sig_curmask = mask;
    (void)__syscall(107, (int)mask, (int)(mask >> 16), 0);
    (void)sigsetmask(old);
    errno = EINTR;
    return -1;
}

/* sigsuspend(2): sigpause with the mask read through a pointer.  2.11BSD's is
 * syscall 107 and takes a POINTER to the mask, where FGX's 107 takes the mask
 * itself -- the "nonstandard (mask instead of pointer) calling convention" that
 * upstream's own comment attributes to 4.4 (usr/sys/sys/kern_sig2.c, above
 * sigpending).  So the pointer is read here, and a null one is upstream's
 * `nmask = 0': wait with nothing blocked.  Always -1/EINTR, as upstream's
 * `always return EINTR rather than ERESTART'. */
int sigsuspend(sigset_t *set)
{
    return ((int)sigpause(set ? *set : 0L));
}

/* sigvec(2): the BSD struct form of signal(2).  Only sv_handler is applied.
 *
 * ITS OLD COMMENT SAID "FGX has no signal mask (sv_mask)", WHICH STOPPED BEING
 * TRUE on 2026-07-27 when the kernel-backed per-task 32-bit masks landed, and is
 * doubly untrue now that sigaction(2) honours sa_mask through crt0's trampoline.
 * The gap is no longer the mask; it is THIS call, deliberately.
 *
 * WHY sigvec DOES NOT APPLY sv_mask: routing it through sigaction pulls that
 * function, the sigset_t helpers and a 128-byte per-signal table into every
 * binary that calls sigvec, and tcsh -- which is the caller, via mysigvec --
 * overflowed its 64 KB segment when this was tried.  A port that wants a mask
 * applied should call sigaction, which is the faithful road and the one 2.11BSD
 * itself moved to (it carries sigaction as syscall 31 and marks 108 "(old
 * sigvec)").  sv_mask is an int in any case, so it cannot name SIGSTOP upward.
 *
 * A NULL `vec' means "query only", which is how tcsh calls it (mysigvec(SIGINT,
 * NULL, &osv)).
 */
int sigvec(int sig, struct sigvec *vec, struct sigvec *ovec)
{
    extern char *_sig_query();
    int old;

    if (vec != (struct sigvec *)0)
        old = (int)signal(sig, (char *)vec->sv_handler);
    else
        old = (int)_sig_query(sig);       /* query-only: report the shadow,
                                          * not a hardwired SIG_DFL */
    if (ovec != (struct sigvec *)0) {
        ovec->sv_handler = (void (*)())old;
        ovec->sv_mask    = 0;
        ovec->sv_flags   = 0;
    }
    return 0;
}

/* current disposition without changing it (sigvec NULL-vec query).  Reads the
 * process's own disposition table, which signal.c also writes -- it moved from
 * a signal.c static (_sig_disp) into lib/libc_data.s as _sig_c_tab when
 * apple/fgx#58 made crt0's trampoline dispatch out of it. */
char *_sig_query(int sig)
{
    if (sig < 1 || sig > 31)
        return (char *)0;
    return _sig_c_tab[sig];
}

