/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ptcwrite()
 * (vendor/2.11BSD/usr/sys/sys/tty_pty.c:433-438) as the behaviour under test.
 *
 * ptyhog - a master that writes faster than its slave reads must be REFUSED,
 * not silently emptied into a full queue.
 *
 * NOTHING IN THE SUITE COULD SEE THIS, which is the whole reason it exists.
 * apple/fgx#108 T6 increment 4a replaced the pty in-ring with a direct call to
 * the line discipline, and the ring carried the backpressure for free:
 * `_Pty_InPut' answered C=0 when it was full and `_PtyM_Write' blocked on that.
 * Upstream's equivalent is an explicit test, and it is the half a port drops
 * without noticing:
 *
 *      if ((tp->t_rawq.c_cc + tp->t_canq.c_cc) >= TTYHOG - 2 &&
 *         (tp->t_canq.c_cc > 0 || tp->t_flags & (RAW|CBREAK))) {
 *              wakeup((caddr_t)&tp->t_rawq);
 *              goto block;
 *      }
 *
 * Drop it and a master write never blocks -- it keeps handing bytes to putc(),
 * which returns -1 once the cblock pool is dry, and the characters are simply
 * GONE.  Every other pty fixture stays green, because not one of them writes
 * more than a line before reading it back.
 *
 * NON-BLOCKING, DELIBERATELY.  The blocking form of this test is a HANG when it
 * fails, and a hang names nothing -- "a mutation that hangs is a poor mutation"
 * is a rule this campaign has paid for.  With FIONBIO set the same refusal
 * arrives as EAGAIN and the case reports a NUMBER: how many bytes went in
 * before the queue said stop.
 *
 * THE BOUND IS ASSERTED AT BOTH ENDS, and one alone would be worthless:
 *
 *   NOT ZERO   a driver that refuses everything would pass a bare "it stopped"
 *              assertion while being completely broken.
 *   NOT HUGE   the point of the test.  TTYHOG is 255, so a correct kernel stops
 *              somewhere near it; a kernel that has lost the guard runs to the
 *              end of the buffer below and reports every byte accepted.
 *
 * ECHO OFF AS WELL AS RAW, and finding out why cost the first four runs.  RAW
 * does NOT disable echo -- `ttyecho's own RAW arm still calls `ttyoutput' -- so
 * with echo left on, every byte written to the master also lands in the SLAVE'S
 * t_outq, which nothing here drains.  That is a second queue filling, and the
 * write path stalls on it at almost exactly the mark this test is aiming at, so
 * it reads as the input hog mark firing and blocking.  It is not: this measures
 * the INPUT queue, and the output one has to be kept out of the way.
 *
 * RAW MODE ON THE SLAVE.  Upstream's test has a `t_canq.c_cc > 0 ||
 * t_flags & (RAW|CBREAK)' disjunct: in COOKED mode with an empty canonical
 * queue the writer is allowed PAST the hog mark, because the line it is
 * building has to be able to finish.  A cooked test would therefore be
 * measuring that exception rather than the rule.
 */
#include <stdio.h>

#define FIONBIO 0x667E
/* THE 16-BIT KERNEL FORM, not BSD's encoded _IOR/_IOW.  include/loader.s:685
 * is the numbering FGX actually dispatches, and ROADMAP records why: 2.11BSD's
 * sys_generic.c:199 hands the DRIVER the decoded 16-bit command, and that is
 * already FGX's own.  The encoded values assemble fine and simply never match. */
#define TIOCGETP 0x7408
#define TIOCSETP 0x7409
#define RAW      0x0020
#define ECHO     0x0008

int open(char *path, int flags);
int close(int fd);
int write(int fd, char *buf, int n);
int ioctl(int fd, int cmd, char *arg);

static char master[] = "/dev/ptyp0";
static char slave[]  = "/dev/ttyp0";
static char one[]    = "x";

int
main()
{
	int m, s, arg, i, n, sent;
	char sg[6];

	m = open(master, 2);
	if (m < 0) {
		printf("PTYHOG FAIL master\n");
		return 1;
	}
	s = open(slave, 2);
	if (s < 0) {
		printf("PTYHOG FAIL slave\n");
		(void) close(m);
		return 1;
	}

	/* RAW on the slave -- see the header: cooked mode is allowed past the
	 * hog mark while the canonical queue is empty. */
	if (ioctl(s, TIOCGETP, sg) < 0) {
		printf("PTYHOG FAIL getp\n");
		return 1;
	}
	/* RAW **AND ECHO OFF**.  RAW does not disable echo -- `ttyecho's own RAW
	 * arm still calls `ttyoutput' -- so with echo left on every byte written
	 * to the master also lands in the slave's t_outq, which nothing here
	 * drains.  That is a SECOND queue filling, and it is not the one under
	 * test: this measures the INPUT hog mark. */
	sg[4] = (sg[4] | RAW) & ~ECHO;
	if (ioctl(s, TIOCSETP, sg) < 0) {
		printf("PTYHOG FAIL setp\n");
		return 1;
	}

	/* Non-blocking on the MASTER, so the refusal is a value and not a hang. */
	arg = 1;
	if (ioctl(m, FIONBIO, (char *)&arg) < 0) {
		printf("PTYHOG FAIL fionbio\n");
		return 1;
	}

	/* Write until it says stop.  The bound is well past TTYHOG (255) so a
	 * kernel that never refuses reports the whole run. */
	sent = 0;
	for (i = 0; i < 400; i++) {
		n = write(m, one, 1);
		if (n != 1)
			break;
		sent = sent + 1;
	}

	(void) close(s);
	(void) close(m);

	printf("PTYHOG sent %d\n", sent);
	if (sent == 0) {
		printf("PTYHOG FAIL refused-everything\n");
		return 1;
	}
	if (sent >= 400) {
		printf("PTYHOG FAIL no-backpressure\n");
		return 1;
	}
	printf("PTYHOG BLOCKED\n");
	return 0;
}
