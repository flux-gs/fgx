/* ---- system + time (C4 batch 12 — FIRST PILE-DATA users) ------------------
 * These statics are the data-plumbing tier's proof: they live in
 * lib/libc_c_data.s, which every seg1 link now PUTs at a template-frozen
 * offset (after fcc_runtime_data), so the shared pile code resolves them
 * identically in every binary.  The kernel reads argv tables and their
 * strings from _Sys_CallerBank (= DBR = the data bank) — exactly where
 * pile data now lives. */
static char __lc_sh_path[] = "/bin/sh";
static char __lc_sh_arg0[] = "sh";
static char __lc_sh_argc[] = "-c";

/* system(3) -- 2.11BSD's shape (apple/fgx#61).
 *
 * The BSD original (usr/lib/libc/gen/system.c) is three pieces of signal
 * handling wrapped around a fork, and FGX had none of them: it spawned,
 * waited, and returned the exit code.
 *
 *   - SIGCHLD BLOCKED across the whole operation, so a caller's own SIGCHLD
 *     handler cannot reap the child before waitpid does.  (Depends on fork
 *     inheriting the mask, which is apple/fgx#54 -- before that landed this
 *     block would have been half-real.)
 *   - SIGINT AND SIGQUIT IGNORED IN THE PARENT while it waits, so ^C reaches
 *     the child and the caller survives.  That is why you can interrupt a
 *     pager under man(1) without killing man.
 *   - THE RAW WAIT STATUS returned, not the exit code, so WEXITSTATUS() and
 *     friends mean what they mean everywhere else.
 *
 * ONE DELIBERATE DEVIATION, AND FGX'S FORK FORCES IT.  BSD installs the two
 * ignores AFTER vfork(), which is safe there because vfork suspends the parent
 * until the child execs.  FGX's fork is a SEQUENTIAL SNAPSHOT fork -- the child
 * can run to completion before fork() returns, which is the same property that
 * makes the SIGCHLD block necessary -- so an ignore installed after fork()
 * would go up after the child had already come and gone.  They go up BEFORE.
 *
 * THE CHILD MUST THEN UNDO THEM, and this is the part that would silently
 * produce uninterruptible children if it were skipped: fork now inherits
 * dispositions (#54) and an ignored signal survives exec, so without the two
 * restores below the child would inherit SIG_IGN for SIGINT -- the exact
 * opposite of what BSD gives you.
 *
 * FORK, NOT SPAWN, IS ALSO WHAT MAKES ^C WORK AT ALL: the child inherits the
 * process GROUP, so _Kill_GroupFanout can reach it.  A spawned child sits in
 * pgrp 0 (apple/fgx#60), and with the parent correctly ignoring SIGINT the
 * signal would reach nobody -- measured, and worse than doing nothing.
 */
int system(char *cmd)
{
    int pid, st;
    long omask;
    char *intsave, *quitsave;
    char *av[4];

    if (cmd == (char *)0)
        return 1;                       /* "just checking..." -- BSD */

    av[0] = __lc_sh_arg0;
    av[1] = __lc_sh_argc;
    av[2] = cmd;
    av[3] = (char *)0;

    omask    = sigblock(sigmask(SIGCHLD));
    intsave  = signal(SIGINT,  (char *)SIG_IGN);
    quitsave = signal(SIGQUIT, (char *)SIG_IGN);

    pid = fork();
    if (pid == 0) {
        (void)signal(SIGINT,  intsave);     /* see "THE CHILD MUST THEN UNDO" */
        (void)signal(SIGQUIT, quitsave);
        (void)sigsetmask(omask);
        (void)execv(__lc_sh_path, av);      /* execv supplies environ */
        _exit(127);                         /* exec failed: BSD's 127 */
    }
    if (pid < 0)
        st = 127 << 8;                      /* BSD: w_retcode = 127 */
    else if (waitpid(pid, &st, 0) < 0)
        st = -1;

    (void)sigsetmask(omask);
    (void)signal(SIGINT,  intsave);
    (void)signal(SIGQUIT, quitsave);
    return st;
}


