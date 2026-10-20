
/* sigaction(2) and the sigset_t helpers.
 *
 * THE HANDLER GOES IN THROUGH signal(), which is already the whole road: the
 * kernel keeps one entry point per task plus a catch bit per signal
 * (apple/fgx#58) and the per-signal dispatch happens in crt0's trampoline out of
 * `_sig_c_tab', which IS BSD's u_signal[NSIG].  So sigaction adds exactly what
 * signal() cannot express -- sa_mask -- and reports the rest.
 *
 * sa_mask IS HONOURED, and this is where the 2.11BSD counterpart puts it:
 *
 *     u.u_sigmask[signum] = sa->sa_mask &~ sigcantmask;
 *                     -- vendor/2.11BSD/usr/sys/sys/kern_sig2.c, setsigvec
 *
 * stored at install and applied when the handler is entered (postsig ORs
 * `u.u_sigmask[sig]' into p_sigmask).  FGX's postsig is crt0's trampoline, which
 * already saves the pre-delivery mask and blocks the delivered signal, so the
 * set is added there and unwound by the restore that was already there.  The
 * table is this file's own static and its offset is published in
 * `_sig_act_maskoff' (lib/libc_data.s) so the trampoline can find it without
 * every binary paying 128 bytes for a table it never uses.
 *
 * `sigcantmask' is subtracted on the way in, as upstream subtracts it: SIGKILL
 * and SIGSTOP are not blockable, and the kernel refuses them on the mask road
 * too (apple/fgx#471), so a handler cannot make itself unkillable by listing
 * them in sa_mask.
 *
 * THE FLAGS ARE RECORDED AND REPORTED; two of the three are not acted on, and
 * saying which beats implying all of them work:
 *
 *   SA_RESTART is always in force.  A syscall marked by `_Sys_MarkRestart' is
 *     re-entered unconditionally after delivery (src/kernel/syscall.s), so it is
 *     the ABSENCE of SA_RESTART -- upstream's u_sigintr bit -- that FGX cannot
 *     express.  A caller clearing it gets restart anyway.  Reported as set,
 *     because that is what the system does.
 *   SA_NOCLDSTOP is not honoured.  FGX posts SIGCHLD for stopped children as
 *     well as dead ones on purpose (src/kernel/signal.s: tcsh's pchild reaps
 *     stops via wait3(WNOHANG|WUNTRACED), and without the post pjwait polled
 *     forever after ^Z).  Suppressing it per-process needs kernel state this
 *     does not add.  A handler that only wants exits sees a wait3 that returns
 *     0, which is what syslogd's reapchild does with it.
 *   SA_ONSTACK is ignored: there is no sigaltstack(2).
 *
 * Kept as a record rather than dropped so that `osa' reports what was asked for
 * and a later kernel can honour them without changing this interface.
 */

#define SA_NSIG         32              /* NSIG; entry 0 unused */

static long  _sa_mask_tab[SA_NSIG];     /* per-signal sa_mask, sigcantmask off */
static int   _sa_flag_tab[SA_NSIG];     /* per-signal sa_flags, as given */
static int   _sa_published = 0;

/* sigemptyset/sigfillset/sigaddset/sigdelset/sigismember -- POSIX, and syslogd
 * builds its block set with the first three.  A sigset_t is a long and the bit
 * for signal s is (s-1), which is the convention <signal.h>'s sigmask() uses and
 * the kernel's per-task mask uses. */
int sigemptyset(set)
    sigset_t *set;
{
    if (set == (sigset_t *)0) { errno = EINVAL; return (-1); }
    *set = 0L;
    return (0);
}

int sigfillset(set)
    sigset_t *set;
{
    if (set == (sigset_t *)0) { errno = EINVAL; return (-1); }
    *set = ~0L;
    return (0);
}

int sigaddset(set, sig)
    sigset_t *set;
    int sig;
{
    if (set == (sigset_t *)0 || sig < 1 || sig >= SA_NSIG) {
        errno = EINVAL;
        return (-1);
    }
    *set |= (1L << (sig - 1));
    return (0);
}

int sigdelset(set, sig)
    sigset_t *set;
    int sig;
{
    if (set == (sigset_t *)0 || sig < 1 || sig >= SA_NSIG) {
        errno = EINVAL;
        return (-1);
    }
    *set &= ~(1L << (sig - 1));
    return (0);
}

int sigismember(set, sig)
    sigset_t *set;
    int sig;
{
    if (set == (sigset_t *)0 || sig < 1 || sig >= SA_NSIG) {
        errno = EINVAL;
        return (-1);
    }
    return ((*set & (1L << (sig - 1))) != 0L);
}

int sigaction(sig, nsa, osa)
    int sig;
    struct sigaction *nsa;
    struct sigaction *osa;
{
    extern char *_sig_query();
    extern int   _sig_act_maskoff;
    char *prev;

    /* Upstream's own checks, in its order: the range first, then the refusal to
     * install anything for SIGKILL or SIGSTOP -- and only when a NEW action is
     * being set, so a query about them still answers (kern_sig2.c:82-91). */
    if (sig <= 0 || sig >= SA_NSIG) {
        errno = EINVAL;
        return (-1);
    }
    if (nsa != (struct sigaction *)0 && (sig == SIGKILL || sig == SIGSTOP)) {
        errno = EINVAL;
        return (-1);
    }

    /* Publish the table to crt0's trampoline on first use.  The cast takes the
     * data-bank OFFSET, which is what the trampoline indexes: it runs with DBR
     * already on this bank. */
    if (_sa_published == 0) {
        _sig_act_maskoff = (int)(long)&_sa_mask_tab[0];
        _sa_published = 1;
    }

    if (osa != (struct sigaction *)0) {
        osa->sa_handler = (void (*)())_sig_query(sig);
        osa->sa_mask    = _sa_mask_tab[sig];
        /* SA_RESTART is reported set because it IS in force, whatever was
         * asked for; the rest is echoed back as recorded. */
        osa->sa_flags   = _sa_flag_tab[sig] | SA_RESTART;
    }

    if (nsa != (struct sigaction *)0) {
        /* The mask goes down BEFORE the handler, so a signal arriving between
         * the two cannot run the new handler with the old set. */
        _sa_mask_tab[sig] = nsa->sa_mask & ~SIG_CANTMASK;
        _sa_flag_tab[sig] = nsa->sa_flags;
        prev = signal(sig, (char *)nsa->sa_handler);
        if (prev == (char *)-1) {
            _sa_mask_tab[sig] = 0L;     /* nothing was installed */
            _sa_flag_tab[sig] = 0;
            return (-1);                /* signal() set errno */
        }
    }
    return (0);
}
