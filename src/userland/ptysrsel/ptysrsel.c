/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ptcselect()
 * (vendor/2.11BSD/usr/sys/sys/tty_pty.c:379-408) as the behaviour under test.
 *
 * ptysrsel - select() on a pty must agree with the read and the write it
 * predicts, in BOTH directions.
 *
 * THIS IS THE THIRD TIME A PTY POLL OP WAS LEFT READING A RING THE INCREMENT
 * UNDERNEATH IT HAD STOPPED FEEDING, so it is the last time it goes unmeasured:
 *
 *   T4 increment 4  `_PtyM_Poll' answered POLLIN from the OUT ring after
 *                   `t_oproc' became `ptsstart' -- caught before it shipped.
 *   T4 increment 7  `_PtyS_Poll' answered POLLOUT from the same dead ring, so
 *                   select promised a write `ttwrite' then blocked on.
 *                   `ptyswsel' is that fixture.
 *   T6 increment 4a BOTH remaining arms at once, and in OPPOSITE directions --
 *                   which is why one fixture covers both here.
 *
 * CASE 1, THE SLAVE MUST BECOME READABLE.  `_PtyS_Poll' answered POLLIN from
 * `PTYR_InCount'.  The master's write feeds the line discipline directly now,
 * so that count is pinned at 0: select said "not readable" forever while the
 * bytes sat in `t_rawq' and a read(2) would have returned them at once.  A
 * select-driven reader on a pty slave simply went deaf -- the exact defect
 * `_Ttyv_Poll' was written to cure one device over.
 *
 * CASE 2, THE MASTER MUST STOP BEING WRITABLE.  `_PtyM_Poll' answered POLLOUT
 * from `PTYR_InCount < PTY_RING_SZ', which for a pinned-at-zero count is
 * "always writable" -- while `_PtyM_Write' refuses at TTYHOG with EAGAIN.  A
 * select that promises a write which then fails is the one answer select
 * exists to prevent.
 *
 * BOTH ARE ASSERTED IN THEIR NEGATIVE STATE FIRST, and that is what stops a
 * driver that answers "ready" unconditionally from passing: case 1 checks the
 * slave is NOT readable before the master writes, and case 2 checks the master
 * IS writable before the queue fills.  An assertion that only ever looks for
 * "ready" is satisfied by the broken driver it is meant to catch.
 *
 * THE LOOP BOUND IS 300, just past the hog mark at 253.  Each turn costs a
 * select AND a write, so a broken driver that never stops saying "writable"
 * runs the whole bound -- and at 400 that took long enough to end as a TIMEOUT
 * rather than as a named failure.  A mutation that hangs names nothing; this
 * one reports `master-always-writable' with the count.
 *
 * RAW WITH ECHO OFF on the slave, for `ptyhog's reason: RAW does not disable
 * echo, and a master write with echo on also fills the slave's t_outq, which
 * is a different queue from the one under test.
 */
#include <stdio.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/ioctl.h>                  /* TIOCFLUSH 0x7410, via <sgtty.h> */
#include <sys/file.h>                   /* FREAD */

/* THE 16-BIT KERNEL FORM, not BSD's encoded _IOR/_IOW -- include/loader.s:685.
 * The encoded values assemble fine and simply never match; ptyhog paid for
 * that one already. */
#define FIONBIO  0x667E
#define TIOCGETP 0x7408
#define TIOCSETP 0x7409
#define RAW      0x0020
#define ECHO     0x0008

int open(char *path, int flags);
int close(int fd);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int ioctl(int fd, int cmd, char *arg);

static char master[] = "/dev/ptyp0";
static char slave[]  = "/dev/ttyp0";
static char one[]    = "x";

/* A zero timeout makes select a poll, which is what these ask.  fd_set and
 * struct timeval are ptyswsel's convention, and it is the one that works. */
static int
readable(fd)
int fd;
{
	fd_set rd;
	struct timeval tv;

	FD_ZERO(&rd);
	FD_SET(fd, &rd);
	tv.tv_sec = 0;
	tv.tv_usec = 0;
	if (select(fd + 1, (void *)&rd, (void *)0, (void *)0, &tv) < 0)
		return (-1);
	return (FD_ISSET(fd, &rd) ? 1 : 0);
}

static int
writable(fd)
int fd;
{
	fd_set wr;
	struct timeval tv;

	FD_ZERO(&wr);
	FD_SET(fd, &wr);
	tv.tv_sec = 0;
	tv.tv_usec = 0;
	if (select(fd + 1, (void *)0, (void *)&wr, (void *)0, &tv) < 0)
		return (-1);
	return (FD_ISSET(fd, &wr) ? 1 : 0);
}

int
main()
{
	int m, s, i, n, on, arg;
	char sg[6];

	m = open(master, 2);
	s = open(slave, 2);
	if (m < 0 || s < 0) {
		printf("PTYSRSEL FAIL open\n");
		return 1;
	}
	if (ioctl(s, TIOCGETP, sg) < 0) {
		printf("PTYSRSEL FAIL getp\n");
		return 1;
	}
	sg[4] = (sg[4] | RAW) & ~ECHO;
	if (ioctl(s, TIOCSETP, sg) < 0) {
		printf("PTYSRSEL FAIL setp\n");
		return 1;
	}

	/* NON-BLOCKING MASTER, and it is what makes a FAILURE REPORT ITSELF.
	 * The bug under test is "select says writable and the write then
	 * blocks", so a broken driver drives this straight into that block --
	 * and the fixture ends as a TIMEOUT, which names nothing.  With FIONBIO
	 * the same write comes back EAGAIN, the loop breaks, and the case
	 * reports `master-always-writable' with a count.  Measured: without
	 * this, mutating the POLLOUT arm produced no output at all. */
	on = 1;
	if (ioctl(m, FIONBIO, (char *)&on) < 0) {
		printf("PTYSRSEL FAIL fionbio\n");
		return 1;
	}

	/* ---- 1: the slave is NOT readable before anything is written ---- */
	if (readable(s) != 0) {
		printf("PTYSRSEL FAIL slave-readable-early\n");
		return 1;
	}
	/* ...and IS once the master writes.  This is the arm that was dead. */
	if (write(m, one, 1) != 1) {
		printf("PTYSRSEL FAIL master-write\n");
		return 1;
	}
	if (readable(s) != 1) {
		printf("PTYSRSEL FAIL slave-deaf\n");
		return 1;
	}
	printf("PTYSRSEL slave readable\n");

	/* ---- 2: the master is writable, and stops being so at the hog ---- */
	if (writable(m) != 1) {
		printf("PTYSRSEL FAIL master-unwritable-early\n");
		return 1;
	}
	n = 1;
	i = 0;
	while (i < 300 && writable(m) == 1) {
		if (write(m, one, 1) != 1)
			break;
		n = n + 1;
		i = i + 1;
	}
	if (writable(m) != 0) {
		printf("PTYSRSEL FAIL master-always-writable %d\n", n);
		return 1;
	}
	printf("PTYSRSEL master stops at %d\n", n);

	/* 3: A MASTER'S TIOCFLUSH DISCARDS THE SLAVE'S INPUT (apple/fgx#241).
	 * `ptyioctl' has no TIOCFLUSH arm -- its master switch is TIOCPKT,
	 * TIOCUCNTL, TIOCREMOTE and TIOCSETP/SETN/SETD and nothing else
	 * (vendor/2.11BSD/usr/sys/sys/tty_pty.c:483-511) -- so the command
	 * falls through to `ttioctl(tp, ...)' on the SLAVE'S tp at
	 * tty_pty.c:526.  FGX's `_PtyM_Ioctl' used to claim it and answer
	 * SUCCESS without touching a queue.
	 *
	 * HERE, AFTER THE HOG LOOP, BECAUSE THE QUEUE IS ALREADY FULL: case 2
	 * left ~254 bytes in the slave's `t_rawq', so the pre-check below is a
	 * real positive control without another write.
	 *
	 * FREAD ONLY.  It flushes `t_canq'/`t_rawq' and never touches
	 * `t_outq', so it cannot interact with echo or with a packet-mode
	 * stream, and `readable(slave)' is then a clean single-queue question.
	 * The FWRITE half belongs with ptypkt. */
	if (readable(s) != 1) {			/* POSITIVE CONTROL */
		printf("PTYSRSEL FAIL flush-nothing-queued\n");
		return 1;
	}
	arg = FREAD;
	if (ioctl(m, TIOCFLUSH, (char *)&arg) < 0) {
		printf("PTYSRSEL FAIL tiocflush\n");
		return 1;
	}
	if (readable(s) != 0) {
		printf("PTYSRSEL FAIL master-flush-inert\n");
		return 1;
	}
	printf("PTYSRSEL master flush\n");

	(void) close(s);
	(void) close(m);
	printf("PTYSRSEL BOTH\n");
	return 0;
}
