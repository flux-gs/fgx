/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ptcclose()
 * (usr/sys/sys/tty_pty.c:222) and ttymodem() (usr/sys/sys/tty.c:709) as the
 * behaviour under test.
 *
 * ptyhup - CLOSING THE MASTER HANGS UP THE SLAVE'S SESSION.  TTY campaign T4
 * increment 2.
 *
 * NOTHING IN THE SUITE ASSERTED A HANGUP OF ANY KIND before this file, which
 * is why it is written ahead of the change rather than after it.  There are two
 * different mechanisms in the tree and the tests could not tell them apart:
 *
 *   FGX today:  _Tty_GetByte's `@tgb_phup' arm (syscall.s) hands a READER a
 *               `^D' once PTYF_MOPEN is clear, so a process that is blocked in
 *               read(2) sees end-of-file.  A process that is NOT reading is
 *               told nothing at all, and neither is one that is stopped.
 *   BSD:        ptcclose calls `(*linesw[t_line].l_modem)(tp, 0)', whose real
 *               routine is ttymodem, whose lost-carrier arm does
 *               `gsignal(tp->t_pgrp, SIGHUP)', then SIGCONT, then
 *               ttyflush(tp, FREAD|FWRITE).  The session is TOLD; it does not
 *               have to ask.
 *
 * THE TARGET NEVER READS ITS TTY, and that is the whole discrimination.
 * spinner(8) loops on yield(), so the `^D' mechanism can never reach it -- no
 * read, no end-of-file -- while the carrier mechanism reaches it at its next
 * syscall exit, because FGX delivers pending signals there.  A test whose
 * target read the slave would go green on both kernels and prove nothing.
 * (Delivery needs SOME syscall, which is what yield() is for; the same
 * reasoning is written out in ptyintr.c and in spinner.c itself.)
 *
 * THE ALIVE CHECK IS A POSITIVE CONTROL, not a formality.  "Died of SIGHUP" is
 * a vacuous pass if the child was already dead of something else -- a failed
 * exec, a signal from claiming the line, a panic in the spawn path.  So the
 * child is required to be RUNNING immediately before the close (waitpid
 * WNOHANG answers 0) and dead of exactly SIGHUP immediately after it.  Only
 * the close lies between the two answers.
 *
 * THE CHILD MUST OWN THE LINE AS ITS CONTROLLING TERMINAL, because ttymodem
 * signals `tp->t_pgrp' and nothing else.  The file_actions recipe below is
 * ptyintr's verbatim in shape: detach from this driver's process group FIRST
 * (apple/fgx#60 -- spawn inherits the group, so without the detach the child
 * arrives already in a group and ttyopen's `p_pgrp == 0' claim never fires,
 * leaving the line with no foreground group at all), then open the slave and
 * dup it onto fd 0, 1 and 2.
 *
 * WHY spawnx AND NOT fork: FGX's fork is snapshot/vfork shaped and the child
 * borrows the parent's stack and direct page, so a forked child is not an
 * independent task; and the open has to happen IN THE CHILD for the child to
 * be the one that claims the line.
 *
 * THE MASTER IS OPENED FIRST and stays open until the close under test:
 * /dev/ttyp1 cannot be opened at all until the master side has created the
 * pair, so the child's own open depends on this one.
 */
/* THE CLOSE'S OWN ANSWER IS ASSERTED, not only its effect.  close(2) on
 * either pty side answered -1 with errno 10 while the hangup it performed
 * went through: `Fs_Close' carried its deferred-error latch across the
 * teardown in a scratch cell the pty driver writes (apple/fgx#352).  A probe
 * that ignored the -1 would have gone green on that kernel. */
#include <stdio.h>
#include <sys/wait.h>
#include <errno.h>

int open(char *path, int flags);
int close(int fd);
int spawnx(char *path, char **argv, unsigned char *acts);
int sleep(int sec);

static char master[]   = "/dev/ptyp1";
static char slave[]    = "/dev/ttyp1";
static char spinpath[] = "/testbin/spinner";

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
		printf("PTYHUP FAIL master\n");
		return 1;
	}

	i = 0;
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
		printf("PTYHUP FAIL spawn\n");
		return 1;
	}

	(void) sleep(2);                /* let it claim the line and settle */

	/* POSITIVE CONTROL: it has to be alive for the close to be what kills
	 * it.  waitpid answers 0 for "children exist, none has exited". */
	st = 0;
	p = waitpid(-1, &st, WNOHANG);
	if (p != 0) {
		printf("PTYHUP FAIL early p=%d st=%d\n", p, st);
		return 1;
	}
	printf("PTYHUP alive\n");

	if (close(m) < 0) {
		printf("PTYHUP FAIL close e=%d\n", errno);
		return 1;
	}

	(void) sleep(3);                /* delivery happens at a syscall exit */

	st = 0;
	p = waitpid(-1, &st, WNOHANG);
	if (p == kid && WIFSIGNALED(st) && WTERMSIG(st) == 1)
		printf("PTYHUP OK SIG%d\n", WTERMSIG(st));
	else
		printf("PTYHUP NONE p=%d st=%d\n", p, st);
	return 0;
}
