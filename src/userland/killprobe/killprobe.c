/* killprobe - what survives kill(-1, SIGKILL), and why reboot(8) cannot drain.
 *
 * FGX-Provenance: none
 *
 * apple/fgx#401.  reboot(8)'s teardown ends when `kill(-1, SIGKILL)' answers
 * ESRCH -- nothing left to signal -- and on FGX it never does, so the loop runs
 * its five rounds and prints `CAUTION: some process(es) wouldn't die'.  This
 * runs the same sequence and NAMES what is still there after each round, which
 * the shell cannot do because the shell is one of the things being killed.
 *
 * The broadcast excludes the sender, which is what lets this report at all.
 */
#include <stdio.h>
#include <errno.h>
#include <signal.h>
#include <fgx.h>

struct procinfo plist[24];

static char *statename(s)
int s;
{
	switch (s) {
	case 0:  return "free";
	case 1:  return "ready";
	case 2:  return "run";
	case 3:  return "blocked";
	case 4:  return "zombie";
	case 5:  return "stopped";
	default: return "?";
	}
}

static void dump(tag)
char *tag;
{
	int n, i;

	n = procs((char *)plist, 24);
	printf("KP %s n=%d:", tag, n);
	for (i = 0; i < n; i++)
		printf(" %d/%s/%s", plist[i].pid, plist[i].name,
		       statename(plist[i].state));
	printf("\n");
}

int
main()
{
	int i, r;

	printf("KPSTART\n");

	/* SIGKILL AND SIGSTOP MUST NOT BE BLOCKABLE -- apple/fgx#471, and it
	 * belongs in THIS probe: a task that blocked SIGKILL is one cause of the
	 * drain failure measured below.  The pending bit is posted and
	 * _Sys_CheckSignal steps over it for ever, so kill(-1, SIGKILL) never
	 * answers ESRCH and reboot(8) prints its CAUTION line.
	 *
	 * The kernel subtracts `sigcantmask' on the write (BSD's
	 * usr/sys/h/signalvar.h:121), so asking to block EVERYTHING must come back
	 * with these two bits clear.  Bit (s-1): SIGKILL is 9, SIGSTOP is 17. */
	{
		sigset_t all, now;

		all = ~0L;
		if (sigprocmask(SIG_SETMASK, &all, (sigset_t *)0) < 0) {
			printf("KPMASK FAIL setmask errno=%d\n", errno);
			return (1);
		}
		now = 0;
		if (sigprocmask(0, (sigset_t *)0, &now) < 0) {
			printf("KPMASK FAIL query errno=%d\n", errno);
			return (1);
		}
		if (now & 0x00000100L) {
			printf("KPMASK FAIL SIGKILL blockable\n");
			return (1);
		}
		if (now & 0x00010000L) {
			printf("KPMASK FAIL SIGSTOP blockable\n");
			return (1);
		}
		all = 0;                        /* unblock before the sequence below */
		(void)sigprocmask(SIG_SETMASK, &all, (sigset_t *)0);
		printf("KPMASK ok\n");
	}

	dump("before");

	/* reboot(8)'s first move: idle init so it stops respawning. */
	errno = 0;
	r = kill(1, SIGTSTP);
	printf("KP tstp r=%d errno=%d\n", r, errno);
	sleep(2);
	dump("post-tstp");

	errno = 0;
	r = kill(-1, SIGTERM);
	printf("KP term r=%d errno=%d\n", r, errno);
	sleep(2);
	dump("post-term");

	for (i = 1; i <= 3; i++) {
		errno = 0;
		r = kill(-1, SIGKILL);
		printf("KP kill%d r=%d errno=%d\n", i, r, errno);
		sleep(2);
		dump("post-kill");
		if (r == -1 && errno == ESRCH) {
			printf("KPDRAINED round=%d\n", i);
			return (0);
		}
	}
	printf("KPSTUCK\n");
	return (1);
}
