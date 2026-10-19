/* _libc_start (libc_start.s) publishes the offset of crt0's register->stack
 * signal adapter, crt0_lib.s _sig_tramp, here (0 = an FGX1 crt0 without one). */
extern int _sig_tramp_off;

/* THE PROCESS'S OWN DISPOSITION TABLE, 32 far cells indexed by signal number,
 * declared in lib/libc_data.s.  This is BSD's u_signal[NSIG]: the kernel keeps
 * only a CATCH bit per signal plus one entry point per task (apple/fgx#58),
 * and the per-signal dispatch happens in crt0's trampoline out of this table.
 *
 * It is also the shadow signal() must return.  That used to be a separate
 * `static char *_sig_disp[32]` here -- 128 bytes holding exactly the same
 * information -- which is gone: one table, two readers.  It lives in
 * libc_data rather than as a static for crt0's sake; see the note there. */
extern char *_sig_c_tab[];

char *signal(int sig, char *handler)
{
    unsigned long lh = (unsigned long)handler;
    char *prev;
    int r;

    if (sig < 1 || sig > 31) { errno = 22; return (char *)-1; }   /* EINVAL */
    prev = _sig_c_tab[sig];

    /* SIG_DFL(0) / SIG_IGN(1) sentinels go to the kernel verbatim -- it keeps
     * the per-task IGN mask, which has always covered all 31 signals. */
    if (lh < 2) {   /* no UL-suffix in fcc; long compare promotes */
        r = (int)__syscall(48, sig, (unsigned)lh, 0);
        if (__syscall_c() == 0) { errno = r; return (char *)-1; }
        _sig_c_tab[sig] = handler;
        return prev;
    }

    if (_sig_tramp_off == 0) {            /* no adapter (FGX1 crt0) */
        errno = 78;                       /* ENOSYS */
        return (char *)-1;
    }

    /* A REAL HANDLER, for ANY signal the kernel will catch.  This used to
     * consult a five-entry map and, for anything outside it, "accept and
     * remember" without telling the kernel -- reporting success for a handler
     * that could never run.  That silent-accept is what made the gap
     * undetectable from a port (apple/fgx#58).  Now every signal goes to the
     * kernel and the kernel decides: SIGKILL and SIGSTOP come back EINVAL, as
     * BSD's sigaction answers for them, and everything else is installed. */
    r = (int)__syscall(48, sig, _sig_tramp_off, 0);
    if (__syscall_c() == 0) { errno = r; return (char *)-1; }
    _sig_c_tab[sig] = handler;
    return prev;
}

/* termcap surface (tgetent/tgetflag/tgetnum/tgetstr) -> lib/libtermlib_c/
 * libtermlib.c (BSD-foundations P1); the asm _tc_* engines + tables stay
 * libc.s/libc_data internals. */

