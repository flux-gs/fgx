/* fkbadex - fork train probe: a snapshot-fork child whose exec FAILS, then
 * exits without ever having exec'd.
 *
 * This is the path bsh takes for "cmd: not found": the shell forks, the
 * child walks PATH calling execve on each candidate, every one fails, and the
 * child then prints the message and exit()s from the borrowed image.  Every
 * other fork test here covers the child EXECING (vfexec) or a vfork child
 * _exiting (vfexit); nothing covered snapshot-fork + failed-exec + exit.
 *
 * Reported symptom (2026-07-24): after a not-found, the NEXT command
 * hangs.  If the failed-exec-then-exit path leaks a kernel resource, forks
 * eventually stop succeeding -- and bsh's fork retry loop (its xec.c,
 * `while ((parent=fork()) == -1) { sigchk(); alarm(10); pause(); }`) then
 * spins forever, which is what the hang looks like.
 *
 * So: run the cycle N times and say which iteration breaks.  A leak shows up
 * as a fork or wait failure at a repeatable iteration; clean bookkeeping runs
 * all N.  Bare exit codes would hide WHICH step failed, so print each.
 */
#include <stdio.h>

/* Progress MUST be unbuffered: when this probe wedges, the parent never
 * returns and its buffered stdout is never flushed, and a child that _exit()s
 * never flushes either -- so a printf trail vanishes exactly when it matters
 * and the screen shows nothing at all.  write(2) straight to fd 1 instead. */
static void say(s)
	char *s;
{
	int n = 0;
	while (s[n]) n++;
	write(1, s, n);
}

static void sayn(v)
	int v;
{
	char b[8];
	int i = 0;
	if (v < 0) { say("-"); v = -v; }
	if (v == 0) b[i++] = '0';
	while (v) { b[i++] = '0' + (v % 10); v /= 10; }
	while (i) { char c = b[--i]; write(1, &c, 1); }
}

#define NCYCLE 12

static char badpath[] = "/nosuchdir/nosuchcmd";
static char goodpath[] = "/bin/true";   /* exists, exits 0, prints nothing */
static char arg0[]   = "true";
/* exec's argv is a NULL-terminated char ** of far pointers, which the kernel
 * walks in place (toolchain/lib/libc_c/exec.c).  av is the empty vector the
 * failing exec is handed; gav is the one for the exec that succeeds. */
static char *av[1];
static char *gav[2];

int main(argc, argv)
	int	argc;
	char	**argv;
{
	int i, pid, st, r;

	av[0] = (char *)0;
	gav[0] = arg0;
	gav[1] = (char *)0;
	for (i = 0; i < NCYCLE; i++) {
		pid = fork();
		if (pid < 0) {
			say("FKBADEX FAIL: fork failed at cycle "); sayn(i); say("\n");
			return 1;
		}
		if (pid == 0) {
			/* child: exec something that cannot exist, then exit
			 * from the borrowed image -- exactly bsh's path. */
			execv(badpath, av);
			/* The shell PRINTS "cmd: not found" from the borrowed
			 * image before exiting, so the child dirties the shared
			 * stdio/data state that _Fork_Restore then rolls back
			 * under the parent.  Reproduce that, not just the bare
			 * exit. */
				say("  child bad-exec ok "); sayn(i); say("\n");
			_exit(7);
		}
		st = 0;
		r = waitpid(pid, &st, 0);
		if (r != pid) {
			printf("FKBADEX FAIL: wait got %d want %d at cycle %d\n",
			       r, pid, i);
			return 1;
		}
		if (((st >> 8) & 0xFF) != 7) {
			say("FKBADEX FAIL: status %d at cycle "); sayn(i); say("\n");
			return 1;
		}
		/* Now a child whose exec SUCCEEDS, immediately after the one
		 * that failed.  This ordering is the whole point: a fork child
		 * that dies without exec'ing used to leave its TCB claiming the
		 * PARENT's arena stack, so the reap freed the parent's live
		 * pages in _stkArenaMap.  Nothing broke until the next
		 * SUCCESSFUL load called Task_AllocStack, whose first-fit scan
		 * then handed those same pages to this child -- which staged its
		 * resume frame there and ran wild.  failed-then-failed never
		 * tripped it; only failed-then-SUCCEEDED did. */
		pid = fork();
		if (pid < 0) {
			say("FKBADEX FAIL: fork2 failed at cycle "); sayn(i); say("\n");
			return 1;
		}
		if (pid == 0) {
			execv(goodpath, gav);
			_exit(9);       /* exec should have succeeded */
		}
		st = 0;
		r = waitpid(pid, &st, 0);
		if (r != pid) {
			printf("FKBADEX FAIL: wait2 got %d want %d at cycle %d\n",
			       r, pid, i);
			return 1;
		}
		if (((st >> 8) & 0xFF) != 0) {
			printf("FKBADEX FAIL: exec'd child status %d at cycle %d\n",
			       st, i);
			return 1;
		}
		say("cycle "); sayn(i); say(" ok\n");
	}
	say("FKBADEX OK\n");
	return 0;
}
