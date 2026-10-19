/* setpgrp(pid, pgid) -- the BSD TWO-ARGUMENT form, which is what 2.11BSD
 * userland calls.  It is a straight alias for setpgid().
 *
 * This used to be the zero-argument SysV form hardcoded to setpgid(0, 0), on
 * the note that "2.11BSD's setpgrp(pid, pgrp) two-arg form is the SysV one".
 * That has it exactly backwards -- SysV's setpgrp() takes no arguments, BSD's
 * takes two -- and EVERY caller in the vendored tree passes two:
 * csh's setpgrp(0, shpgrp), window's setpgrp(pgrp, pgrp), uucp's
 * setpgrp(0, getpid()).
 *
 * The damage was silent because K&R C has no prototypes: the arguments were
 * pushed and then ignored, so every call meant "make ME a group leader under
 * MY OWN pid" no matter what was asked for.  tcsh reaches this through
 * tc.os.h's `#define setpgid(pid, pgrp) setpgrp(pid, pgrp)` (active because
 * config.h #undefs POSIX), so each member of a PIPELINE put itself in its own
 * group instead of the job leader's.  ^Z then signalled the tty's foreground
 * group, stopped only the leader, and tcsh waited forever for a job that could
 * never fully stop -- issue #5. */
int setpgrp(pid, pgid)
    int pid, pgid;
{
    return setpgid(pid, pgid);
}

/* killpg(pgrp, sig) == kill(-pgrp, sig): a negative pid is "the process group"
 * (the kernel's SYS_KILL already honours that convention). */
int killpg(int pgrp, int sig)
{
    return kill(-pgrp, sig);
}

/* getgid/getegid used to return a hardcoded 0 here (FGX is single-user and has
 * no group database).  They now issue the real SYS_GETGID and live next to
 * getuid further down, so userland reads what the KERNEL says. */

/* abort(3): BSD raises SIGABRT then exits.  FGX signal delivery is partial, so
 * go straight to the conventional 128+SIGABRT status -- the same code the fcc
 * stack guard uses, so an abort is distinguishable from an ordinary failure. */
void abort()
{
    _exit(128 + SIGABRT);
}

