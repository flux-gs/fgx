/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ptcread()
 * (usr/sys/sys/tty_pty.c:234-296), ptsstart() (:290) and ttioctl()'s TIOCOUTQ
 * arm (usr/sys/sys/tty.c) as the behaviour under test.
 *
 * ptyoutq - HOW MUCH OUTPUT IS PENDING ON A PTY, and who is entitled to know.
 * TTY campaign T4, the measurement behind the increment 4 design question.
 *
 * THIS FIXTURE MEASURES A DIVERGENCE RATHER THAN A DEFECT, and it is written
 * so that the number is on the screen whichever way the design goes.
 *
 * 2.11BSD'S PTY HAS EXACTLY ONE OUTPUT BUFFER, and it is the discipline's:
 *
 *      ptcopen   tp->t_oproc = ptsstart;
 *      ptsstart  if (tp->t_state & TS_TTSTOP) return; ... ptcwakeup(tp, FREAD);
 *      ptcread   if (tp->t_outq.c_cc && (tp->t_state&TS_TTSTOP) == 0) break;
 *                cc = q_to_b(&tp->t_outq, buf, MIN(uio->uio_resid, BUFSIZ));
 *
 * `ptsstart' MOVES NO DATA -- it is a wakeup.  The slave's bytes sit in
 * `t_outq' until the master's own read dequeues them, so `TIOCOUTQ', which
 * answers `tp->t_outq.c_cc', is the true count of what is waiting.
 *
 * FGX BINDS THE GENERIC `tty_oproc' TO EVERY LINE, and it DRAINS: on each
 * `ttstart' it empties `t_outq' through `kc_cdwrite' into the pty's own
 * 128-byte ring.  That is right for a console, where the bytes are on the
 * screen when the call returns, and it is a second buffer on a pty, where
 * there is no device -- the far end's read IS the device.
 *
 * SO THE QUESTION THIS ASKS IS ONE NUMBER: with five bytes written by the
 * slave and not yet read by the master, how many does the discipline say are
 * outstanding?  Five is BSD's answer.  Zero is FGX's, and zero is also what
 * `ttycheckoutq' waits on, what `ttywait' drains, and what `ttyflush(FWRITE)'
 * discards at a hangup -- so the same zero is four other mechanisms measuring
 * an empty queue on a line that has output pending.
 *
 * THERE ARE TWO POSITIVE CONTROLS AND THE FIXTURE IS WORTHLESS WITHOUT EITHER.
 *
 * THE FIRST IS THE MASTER READ.  Zero from TIOCOUTQ could mean "nothing is
 * pending", which would make this a report about a lost write rather than
 * about where the bytes live.  Reading them back proves they were there the
 * whole time and only the discipline could not see them.
 *
 * THE SECOND IS TIOCSTOP, and it answers the harder question: whether the
 * TIOCOUTQ arm RAN AT ALL.  A dead ioctl and an empty queue give the same
 * zero.  So the line is stopped -- `tty_oproc' returns at once on TS_TTSTOP
 * without draining -- and five more bytes are written.  Those have nowhere to
 * go but `t_outq', so a live arm MUST answer five.  That makes the first
 * measurement mean something exact: not "TIOCOUTQ does not work here", but
 * "TIOCOUTQ works, and the queue it reports really is empty, because
 * `tty_oproc' already moved the bytes into the ring".
 *
 * NO NEWLINE IN THE PAYLOAD, for ptyrec's reason: `_PtyS_Write' applies the
 * slave tty's CRMOD, so an LF would arrive as CR+LF and the count under test
 * would be six for a reason that has nothing to do with the question.
 */
#include <stdio.h>
#include <sys/ioctl.h>

int open(char *path, int flags);
int close(int fd);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int ioctl(int fd, int cmd, char *arg);

static char master[] = "/dev/ptyp0";
static char slave[]  = "/dev/ttyp0";
static char out[]    = "ABCDE";

int
main()
{
	int m, s, n, q;
	char buf[16];

	m = open(master, 2);
	if (m < 0) {
		printf("PTYOUTQ FAIL master\n");
		return 1;
	}
	s = open(slave, 2);
	if (s < 0) {
		printf("PTYOUTQ FAIL slave\n");
		return 1;
	}

	/* Five bytes from the slave, and NOBODY READS THE MASTER yet. */
	if (write(s, out, 5) != 5) {
		printf("PTYOUTQ FAIL write\n");
		return 1;
	}

	q = -1;
	if (ioctl(s, TIOCOUTQ, (char *)&q) != 0) {
		printf("PTYOUTQ FAIL ioctl\n");
		return 1;
	}
	printf("PTYOUTQ outq=%d\n", q);

	/* THE POSITIVE CONTROL: the bytes exist, whatever the discipline said. */
	for (n = 0; n < 16; n++)
		buf[n] = 0;
	n = read(m, buf, 16);
	printf("PTYOUTQ read n=%d b0=%d b4=%d\n", n, buf[0], buf[4]);

	if (n != 5 || buf[0] != 'A' || buf[4] != 'E') {
		printf("PTYOUTQ FAIL pending\n");
		(void) close(s);
		(void) close(m);
		return 1;
	}

	/* THE SECOND CONTROL.  Stop the line, so tty_oproc refuses to drain,
	 * and write again: those bytes have nowhere to go but t_outq, so a
	 * TIOCOUTQ arm that is alive has to answer five. */
	if (ioctl(s, TIOCSTOP, (char *)&n) != 0) {
		printf("PTYOUTQ FAIL stop\n");
		return 1;
	}
	if (write(s, out, 5) != 5) {
		printf("PTYOUTQ FAIL write2\n");
		return 1;
	}
	n = -1;
	if (ioctl(s, TIOCOUTQ, (char *)&n) != 0) {
		printf("PTYOUTQ FAIL ioctl2\n");
		return 1;
	}
	printf("PTYOUTQ stopped outq=%d\n", n);

	(void) ioctl(s, TIOCSTART, (char *)&q);

	if (n != 5)
		printf("PTYOUTQ DEAD\n");      /* the arm never ran: q means nothing */
	else if (q == 5)
		printf("PTYOUTQ BSD\n");
	else if (q == 0)
		printf("PTYOUTQ RING\n");
	else
		printf("PTYOUTQ OTHER\n");

	(void) close(s);
	(void) close(m);
	return 0;
}
