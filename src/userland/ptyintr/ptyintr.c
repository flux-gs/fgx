/* ptyintr -- ^C written to a pty MASTER kills the foreground process on the
 * slave even though that process never reads (apple/fgx#57).
 *
 * BSD generates SIGINT in ttyinput(), when the character ARRIVES, so a
 * foreground process that is not reading still takes it.  FGX tested t_intrc
 * where the slave DEQUEUED instead, so a ^C sent over a pty sat in the input
 * ring until a read(2) that a busy process never makes.
 *
 * FGX-Provenance: none.  A test fixture with no upstream; the tty.c lines it
 * quotes are CITED, not derived.
 *
 * Opens the master, spawnx's spinner(8) on the slave with the slave as its
 * fd 0/1/2 (so the child acquires the line as its controlling tty and becomes
 * its foreground group -- the file_actions recipe is b3ptyrd's, verbatim in
 * shape), lets it settle, writes one $03 to the master, and then asks whether
 * the child died of SIGINT.
 *
 * spinner LOOPS ON yield(), AND THAT MATTERS: FGX delivers pending signals at
 * SYSCALL EXIT, so a target that makes no syscall at all could not receive one
 * however this discipline is wired, and would prove nothing about #57.  What
 * spinner never does is read its tty, which is the property under test.
 *
 * WHY spawnx AND NOT fork: FGX's fork is snapshot/vfork shaped and the child
 * borrows the parent's stack and direct page, so a forked child is not an
 * independent task; and the file_actions open has to happen IN THE CHILD for
 * the child to be the one that claims the line.
 *
 * waitpid(WNOHANG) rather than a blocking wait: on the unfixed kernel the
 * child never dies, and a blocking wait would hang until the harness timeout
 * with nothing printed.  Reporting `PTYINTR NONE` with the raw pid/status is
 * a red test that says WHY.
 */
#include <stdio.h>
#include <sys/wait.h>

int open(char *path, int flags);
int write(int fd, char *buf, int n);
int read(int fd, char *buf, int n);
int ioctl(int fd, int cmd, char *arg);
int spawnx(char *path, char **argv, unsigned char *acts);
int sleep(int sec);

static char master[]   = "/dev/ptyp1";
static char slave[]    = "/dev/ttyp1";
static char spinpath[] = "/testbin/spinner";
static char intr[]     = "\003";

#define FIONBIO 0x667E

static char *gav[2];
static unsigned char fa[64];

int
main(argc, argv)
	int argc;
	char **argv;
{
	int m, i, kid, p, st;

	m = open(master, 2);
	if (m < 0) {
		printf("PTYINTR FAIL master\n");
		return 1;
	}
	i = 1;
	(void) ioctl(m, FIONBIO, (char *)&i);   /* the drain below must not block */

	i = 0;
	/* DETACH FIRST (apple/fgx#60): spawn now inherits the process
	 * group, so without this the child arrives already in this
	 * driver's group and ttyopen's `p_pgrp == 0` claim never fires --
	 * the slave line would get no foreground group.  telnetd does the
	 * same thing with TIOCNOTTY before it opens the line. */
	fa[i++] = 4; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 1; fa[i++] = 3;
	fa[i++] = ((int)slave) & 0xff;
	fa[i++] = (((int)slave) >> 8) & 0xff;
	fa[i++] = 2; fa[i++] = 0;
	fa[i++] = 3; fa[i++] = 0; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 3; fa[i++] = 1; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 3; fa[i++] = 2; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 2; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 0;

	gav[0] = spinpath;
	gav[1] = (char *)0;
	kid = spawnx(spinpath, gav, fa);
	if (kid < 0) {
		printf("PTYINTR FAIL spawn\n");
		return 1;
	}

	(void) sleep(2);                /* let it claim the line and settle */

	if (write(m, intr, 1) != 1) {
		printf("PTYINTR FAIL write\n");
		return 1;
	}

	/* DRAIN THE MASTER WHILE THE SIGNAL LANDS, and this is load-bearing
	 * rather than tidy -- it is what apple/fgx#251 turned out to be.
	 *
	 * `ttyinput's intr arm ECHOES the character before it signals
	 * (`ttyecho(c, tp)', vendor/2.11BSD/usr/sys/sys/tty.c:912, ported at
	 * tty.c:1109), so a `^C' leaves "^C" sitting in the line's `t_outq'.
	 * The signalled task then dies, and its slave close goes through
	 * `ttylclose' -> `ttywflush' -> `ttywait', which SLEEPS until the
	 * output queue drains.  On a pty that queue drains only when the
	 * MASTER READS.  A master that writes the `^C' and then sleeps leaves
	 * the corpse parked in close for as long as the run lasts, `waitpid'
	 * sees no zombie, and the fixture reports "the signal never arrived"
	 * about a signal that arrived and was acted on.
	 *
	 * MEASURED (task table sampled every 60 frames through the run): the
	 * spinner goes READY -> BLOCKED at the same instant the `^C' is
	 * written, and stays blocked until its parent exits.  The `^C' echo is
	 * the only thing in that queue.
	 *
	 * The old hand-coded intr test in `_PtyM_Write' did not echo, so this
	 * fixture never had output to drain until T6 increment 4a moved the
	 * test into `ttyinput' -- where upstream has always echoed. */
	{
		char sink[64];
		int t;

		for (t = 0; t < 24; t++) {
			(void) read(m, sink, sizeof sink);
			(void) sleep(0);
		}
	}
	(void) sleep(3);                /* delivery happens at a syscall exit */

	st = 0;
	p = waitpid(-1, &st, WNOHANG);
	if (p == kid && WIFSIGNALED(st) && WTERMSIG(st) == 2)
		printf("PTYINTR OK SIG%d\n", WTERMSIG(st));
	else
		printf("PTYINTR NONE p=%d st=%d\n", p, st);
	return 0;
}
