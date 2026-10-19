/* sigexec - closed-loop check that execve RESETS a caught SIGTERM.
 *
 * FGX-Provenance: none
 *
 * The kernel keeps caught-signal dispositions in per-task tables (memmap.s
 * SIGHND_*_OFF) and _Sig_ResetOnExec walks them at the exec commit point,
 * reverting anything CAUGHT to SIG_DFL -- the handler address belonged to the
 * old image.  That walk is a counted loop over the table run (SIGHND_NHND), so
 * adding a signal table without bumping the count leaves the new signal's slot
 * un-reset, silently, with no build error.  SIGTERM and SIGHUP were added on
 * 2026-08-04; this probe is what makes the count wrong go red.
 *
 * The trick is exec'ing THIS SAME IMAGE.  A different image would make the
 * stale handler offset meaningless and the failure mode a wild jump; re-exec'ing
 * ourselves keeps every offset valid, so the two outcomes are clean and
 * deterministic:
 *
 *   reset correctly -> no handler -> SIGTERM takes its SA_TERM default and the
 *                      process dies.  "RAISING" prints, "SURVIVED" never does.
 *   NOT reset       -> the kernel slot still holds crt0's _sig_tramp offset,
 *                      the trampoline runs, finds a zeroed _sig_c_term in the
 *                      fresh image and skips -- so we survive and print
 *                      "SURVIVED", which is the failure signature.
 *
 * Note it is the TRAMPOLINE offset, not onterm's, that the kernel stores (see
 * libc signal()), which is why the un-reset case is a survivable no-op rather
 * than a crash.  Either way "SURVIVED" is reached only when the reset missed.
 */
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <sys/wait.h>

static int got;

/* Flag-setter only -- the sole supported handler shape (userland-abi.md 6A). */
int
onterm(sig)
	int sig;
{
	got = 1;
	return 0;
}

/* File scope, not locals: an fcc local aggregate lives on the bank-0 hardware
 * stack, and these are handed to execv. */
static char  a0[] = "sigexec";
static char  a1[] = "raise";
static char *av[3];

/* The OTHER counted walk over the same table run: Task_Alloc zeroes a fresh
 * pid's handler slots, because the slot may be a recycled pid whose previous
 * occupant caught something.  Same failure shape as the exec reset -- a count
 * that missed the new tables leaves a stale SIGTERM disposition -- but it is
 * only reachable through pid REUSE, which exec never exercises.
 *
 * So: fork a child that catches SIGTERM and exits WITHOUT exec'ing (leaving the
 * disposition behind if nothing clears it), then keep forking until a child
 * comes back with that same pid and have it raise SIGTERM on itself.  A clean
 * slot means SA_TERM and the parent reaps a signalled child; a stale slot means
 * the trampoline runs, no-ops against the fresh cell, and the child exits 9.
 *
 * The probe reports which of the three things happened, including "never got
 * the pid back", so it cannot pass by simply failing to reach the interesting
 * case. */
static int
reuse()
{
	int p, pid, w, st, i;

	p = fork();
	if (p == 0) {
		signal(SIGTERM, onterm);
		_exit(0);		/* no exec: disposition is left behind */
	}
	if (p < 0) {
		printf("SIGEXEC REUSE FORKFAIL\n");
		return 1;
	}
	while ((w = wait(&st)) != p && w >= 0)
		;			/* reaped an orphan; keep going */

	/* NPROC is 8, and Task_Alloc hands out slots on a rotating cursor, so
	 * p comes back around after a handful of forks.  40 is slack. */
	for (i = 0; i < 40; i++) {
		pid = fork();
		if (pid == 0) {
			if (getpid() == p) {
				kill(getpid(), SIGTERM);
				(void)getpid();	/* one more delivery boundary */
				_exit(9);	/* still here -> stale slot */
			}
			_exit(0);
		}
		if (pid < 0) {
			printf("SIGEXEC REUSE FORKFAIL\n");
			return 1;
		}
		while ((w = wait(&st)) != pid && w >= 0)
			;
		if (pid != p)
			continue;
		if (WIFSIGNALED(st)) {
			printf("SIGEXEC REUSE CLEAN pid=%d sig=%d\n",
			       p, WTERMSIG(st));
			return 0;
		}
		printf("SIGEXEC REUSE STALE pid=%d code=%d\n",
		       p, WEXITSTATUS(st));
		return 1;
	}
	printf("SIGEXEC REUSE NOPID pid=%d never recycled\n", p);
	return 1;
}

int
main(argc, argv)
	int argc;
	char **argv;
{
	int rc;

	if (argc > 1 && strcmp(argv[1], "reuse") == 0) {
		rc = reuse();
		fflush(stdout);
		return rc;
	}
	if (argc > 1) {
		/* Post-exec child.  A caught SIGTERM here means the reset
		 * missed our table. */
		printf("SIGEXEC RAISING\n");
		fflush(stdout);
		kill(getpid(), SIGTERM);
		/* Delivery happens at syscall EXIT, so kill()'s own return is
		 * already a delivery point; one more syscall makes certain we
		 * have crossed a boundary before claiming to have survived. */
		(void)getpid();
		printf("SIGEXEC SURVIVED got=%d\n", got);
		fflush(stdout);
		return 0;
	}

	signal(SIGTERM, onterm);
	av[0] = a0;
	av[1] = a1;
	av[2] = (char *)0;
	execv("/testbin/sigexec", av);
	printf("SIGEXEC EXECFAIL\n");
	fflush(stdout);
	return 1;
}
