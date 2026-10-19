/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ptsclose()
 * (usr/sys/sys/tty_pty.c:88-96) and ttyclose() (usr/sys/sys/tty.c:695) as the
 * behaviour under test.
 *
 * ptyflush - INPUT QUEUED FOR A SESSION DOES NOT SURVIVE IT.  TTY campaign T4
 * increment 3, and written before it for the reason ptyhup was.
 *
 * `ptsclose' is three calls and the middle one is the whole of this test:
 *
 *      (*linesw[tp->t_line].l_close)(tp, flag);
 *      ttyclose(tp);
 *      ptcwakeup(tp, FREAD|FWRITE);
 *
 * `ttyclose' flushes both queues, clears t_pgrp and clears the WHOLE of
 * t_state.  Without it a line is a ratchet rather than a cycle: whatever the
 * last session left in the canonical queue is what the next session's first
 * read(2) returns, and TS_ISOPEN never comes down, so the next `ttyopen' takes
 * its already-open arm.
 *
 * THE LEFTOVER IS MADE ON PURPOSE.  A six-byte line goes in and only two bytes
 * are read out, so "CDE\n" stays in t_canq -- upstream's ttread copies while
 * the caller still wants bytes and leaves the rest queued, which is what makes
 * a short read of a long line work at all.  The second session then asks for
 * ONE byte after a fresh "Z\n" is sent, and the two kernels answer differently
 * in a single character: 'Z' if the queue was flushed, 'C' if it was not.
 *
 * NO SPAWN AND NO SECOND PROCESS.  The property is the LINE's, not a session's
 * ownership of it, so one process opening the slave twice measures it exactly.
 * The master stays open throughout, which is required twice over: /dev/ttyp0
 * cannot be opened without one, and `_Pty_MaybeReset' -- which would flush the
 * pty rings and hide the defect -- only fires when BOTH sides are shut.
 *
 * THE FIRST READ IS THE POSITIVE CONTROL.  If it does not answer "AB" then the
 * leftover was never made, and whatever the second read says is about
 * something else.
 */
#include <stdio.h>

int open(char *path, int flags);
int close(int fd);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);

static char master[] = "/dev/ptyp0";
static char slave[]  = "/dev/ttyp0";
static char line1[]  = "ABCDE\n";
static char line2[]  = "Z\n";

int
main()
{
	int m, s, n;
	char buf[16];

	m = open(master, 2);
	if (m < 0) {
		printf("PTYFLUSH FAIL master\n");
		return 1;
	}
	s = open(slave, 2);
	if (s < 0) {
		printf("PTYFLUSH FAIL slave\n");
		return 1;
	}

	if (write(m, line1, 6) != 6) {
		printf("PTYFLUSH FAIL write1\n");
		return 1;
	}

	buf[0] = 0;
	buf[1] = 0;
	n = read(s, buf, 2);
	printf("PTYFLUSH r1 n=%d b=%d%d\n", n, buf[0], buf[1]);
	if (n != 2 || buf[0] != 'A' || buf[1] != 'B') {
		printf("PTYFLUSH FAIL setup\n");
		return 1;
	}

	/* DRAIN THE ECHO BEFORE CLOSING, and this is not tidiness -- without it
	 * the close BLOCKS FOREVER, on FGX and on 2.11BSD alike.
	 *
	 * The slave is in cooked mode with ECHO, so reading "AB" put those
	 * characters into the line's OUTPUT queue on their way back to the
	 * master.  `ptsclose' calls l_close, which is `ttylclose', which for an
	 * ordinary (non-FNDELAY) close is `ttywflush' -> `ttywait': it kicks the
	 * line and sleeps while the queue is non-empty, carrier is up and the
	 * line has an output routine.  All three hold here -- and since T4
	 * increment 4 the only thing that empties that queue is the MASTER'S
	 * READ, which this process has not done yet.  So it would be waiting for
	 * itself.
	 *
	 * THAT IS BSD'S BEHAVIOUR, NOT A DEFECT.  The wait exists so a session's
	 * output reaches the far end before the line goes away.  This fixture
	 * only ever avoided it because FGX used to drain `t_outq' eagerly into a
	 * ring, which absorbed the echo; the ring is gone, and the dependency it
	 * was hiding is the reason this read is here. */
	n = read(m, buf, 16);
	if (n <= 0) {
		printf("PTYFLUSH FAIL echo n=%d\n", n);
		return 1;
	}

	/* The session ends with "CDE\n" still queued for it. */
	(void) close(s);

	s = open(slave, 2);
	if (s < 0) {
		printf("PTYFLUSH FAIL reopen\n");
		return 1;
	}

	if (write(m, line2, 2) != 2) {
		printf("PTYFLUSH FAIL write2\n");
		return 1;
	}

	buf[0] = 0;
	n = read(s, buf, 1);
	printf("PTYFLUSH r2 n=%d b=%d\n", n, buf[0]);
	if (n == 1 && buf[0] == 'Z')
		printf("PTYFLUSH OK\n");
	else
		printf("PTYFLUSH BAD\n");

	(void) close(s);
	(void) close(m);
	return 0;
}
