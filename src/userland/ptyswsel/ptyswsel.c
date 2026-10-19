/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ttyselect()'s FWRITE
 * arm (usr/sys/sys/tty.c) as the behaviour under test.
 *
 * ptyswsel - SELECT ON A PTY SLAVE FOR WRITE, and whether it tells the truth.
 * TTY campaign T4, the defect found while retiring the ring's out half.
 *
 * `_PtyS_Poll' answers POLLOUT from `PTYR_OutCount', the slave->master ring's
 * fill level.  T4 increment 4 stopped feeding that ring -- a pty slave's output
 * goes to the DISCIPLINE'S `t_outq' now and waits there for the master's read --
 * so the count is 0 forever and the arm says "writable" unconditionally.
 *
 * MEANWHILE `ttwrite' STILL BLOCKS.  Upstream's rule is `t_outq.c_cc <=
 * TTLOWAT(tp)' (ttyselect's FWRITE arm); above the high watermark a write
 * sleeps until the far end drains it.  So select promises a write that will not
 * block and the very next write(2) blocks -- which is the one thing select
 * exists to prevent, and it is silent.
 *
 * THIS IS THE SAME DEFECT `_PtyM_Poll' HAD, caught during increment 4 by
 * reading rather than by a test, with the note that NO FIXTURE COVERED SELECT
 * ON A PTY MASTER.  None covered the slave either.  This is that fixture.
 *
 * HOW THE QUEUE IS FILLED WITHOUT HANGING.  The slave is put in non-blocking
 * mode and written until it answers EWOULDBLOCK, which is `ttwrite's own
 * IO_NDELAY arm reporting that `t_outq' is at the high watermark.  Nothing
 * reads the master in between, so the bytes stay queued.  That is the state in
 * which select must say NOT writable.
 *
 * THREE MEASUREMENTS, and the middle one is the defect:
 *
 *   1  empty queue      select says writable      (true before and after)
 *   2  queue at hiwat   select must say NO        (the arm under test)
 *   3  master drains    select says writable      (proves 2 was the queue and
 *                                                  not a select that broke)
 *
 * WITHOUT 3 THE FIXTURE WOULD BE HALF A TEST: a select arm wired to a constant
 * zero would pass 2 and fail nothing, so the recovery is what makes 2 mean
 * "select tracked the queue" rather than "select stopped answering".
 */
#include <stdio.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/ioctl.h>

int open(char *path, int flags);
int close(int fd);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int ioctl(int fd, int cmd, char *arg);

static char master[] = "/dev/ptyp0";
static char slave[]  = "/dev/ttyp0";
static char blk[]    = "0123456789abcdef";

/* Writable now?  A zero timeout makes select a poll, which is what this asks. */
static int
wr_ready(fd)
int fd;
{
	fd_set wr;
	struct timeval tv;
	int n;

	FD_ZERO(&wr);
	FD_SET(fd, &wr);
	tv.tv_sec = 0;
	tv.tv_usec = 0;
	n = select(fd + 1, (void *)0, (void *)&wr, (void *)0, &tv);
	if (n < 0)
		return (-1);
	return (FD_ISSET(fd, &wr) ? 1 : 0);
}

int
main()
{
	int m, s, on, n, i, w1, w2, w3, total;
	char buf[64];

	m = open(master, 2);
	if (m < 0) { printf("PTYSWSEL FAIL master\n"); return 1; }
	s = open(slave, 2);
	if (s < 0) { printf("PTYSWSEL FAIL slave\n"); return 1; }

	/* BOTH ENDS NON-BLOCKING.  The slave so the fill loop can stop at the
	 * high watermark instead of sleeping on it, and THE MASTER so the drain
	 * loop can stop at the empty queue instead of sleeping on that -- the
	 * first draft set only the slave and hung in the drain, which looks
	 * exactly like the select hanging and is not. */
	on = 1;
	if (ioctl(s, FIONBIO, (char *)&on) < 0) {
		printf("PTYSWSEL FAIL nbio\n");
		return 1;
	}
	on = 1;
	if (ioctl(m, FIONBIO, (char *)&on) < 0) {
		printf("PTYSWSEL FAIL mnbio\n");
		return 1;
	}

	/* 1  An empty output queue is writable. */
	w1 = wr_ready(s);

	/* 2  Fill it until ttwrite refuses, then ask again. */
	total = 0;
	for (i = 0; i < 400; i++) {
		n = write(s, blk, 16);
		if (n <= 0)
			break;
		total += n;
	}
	/* THE POSITIVE CONTROL.  n == -1 is `ttwrite's own IO_NDELAY arm saying
	 * the queue is AT the high watermark -- without it, a `not writable'
	 * below could mean the queue never filled rather than that select saw
	 * it fill. */
	printf("PTYSWSEL filled n=%d\n", n);
	w2 = wr_ready(s);

	/* 3  Let the master drain it, and ask once more. */
	for (i = 0; i < 400; i++) {
		n = read(m, buf, 64);
		if (n <= 0)
			break;
	}
	w3 = wr_ready(s);

	printf("PTYSWSEL q=%d w1=%d w2=%d w3=%d\n", total, w1, w2, w3);

	if (total == 0)
		printf("PTYSWSEL FAIL nofill\n");   /* nothing queued: 2 means nothing */
	else if (w1 == 1 && w2 == 0 && w3 == 1)
		printf("PTYSWSEL TRACKS\n");
	else if (w2 == 1)
		printf("PTYSWSEL ALWAYS\n");        /* the dead-ring answer */
	else
		printf("PTYSWSEL OTHER\n");

	(void) close(s);
	(void) close(m);
	return 0;
}
