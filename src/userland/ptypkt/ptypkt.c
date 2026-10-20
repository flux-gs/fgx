/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ptsstop()
 * (usr/sys/sys/tty_pty.c:297-318), ptsstart() (:163-175), ptcread()'s pt_send
 * arm (:252-257) and ttyflush()/ttioctl()'s TIOCSTOP arm (usr/sys/sys/tty.c)
 * as the behaviour under test.
 *
 * ptypkt - THE PACKET-MODE STATUS BYTES, AND WHETHER THE EVENTS BEHIND THEM
 * HAPPENED.  TTY campaign T4 increment 5, written BEFORE the increment.
 *
 * A pty master in TIOCPKT mode gets a status byte at the head of every read.
 * 2.11BSD keeps the pending bits in `pt_send' and `ptcread' delivers them
 * AHEAD of any data, one read to a byte:
 *
 *      if (pti->pt_flags&PF_PKT && pti->pt_send) {
 *              error = ureadc((int)pti->pt_send, uio);
 *              ...
 *              pti->pt_send = 0;
 *              return (0);
 *      }
 *
 * `pt_send' has exactly two producers and FGX has neither of them:
 *
 *      ptsstop(tp, flush)   d_stop.  flush == 0 means the line was STOPPED,
 *                           so PF_STOPPED goes on and TIOCPKT_STOP is armed;
 *                           otherwise `flush' IS the FREAD/FWRITE mask, whose
 *                           bit values are TIOCPKT_FLUSHREAD/FLUSHWRITE --
 *                           upstream's own comment there is "note: FLUSHREAD
 *                           and FLUSHWRITE already ok".
 *      ptsstart(tp)         t_oproc.  A line that had been stopped is running
 *                           again, so PF_STOPPED comes off and TIOCPKT_START
 *                           is armed.
 *
 * THE PTY SLAVE'S d_stop SLOT IS ZERO IN FGX, and the comment beside it says
 * why: "a pty ring is not in flight".  That was true while `tty_oproc' drained
 * `t_outq' into the pty's own ring on every ttstart.  INCREMENT 4 ENDED IT --
 * `t_oproc' for a pty slave is `ptsstart' now, which moves no data, so the
 * bytes wait in `t_outq' and the line has output in flight exactly as a serial
 * line does.
 *
 * SO THIS FIXTURE ASKS FOUR QUESTIONS, AND THE FIRST IS THE POSITIVE CONTROL.
 *
 *   1  DATA.  Five bytes from the slave, read by the master: six bytes back
 *      with a leading TIOCPKT_DATA.  This proves packet mode is alive at all,
 *      without which every other -1 below would be a report about TIOCPKT
 *      rather than about `pt_send'.
 *   2  FLUSH.  Five more bytes, then TIOCFLUSH(FWRITE) from the slave.  Two
 *      things must be true and FGX gets its status byte from a hand-rolled
 *      flag that only asserts the first: the master is TOLD (b0 = 2), and the
 *      bytes are GONE -- the very next read has nothing to hand over.  A
 *      status byte announcing a flush that discarded nothing is worse than no
 *      status byte, because the master acts on it.
 *   3  STOP.  TIOCSTOP on the slave reaches `ttioctl', which sets TS_TTSTOP
 *      and calls d_stop with rw == 0.  The master must be told: b0 = 4.
 *   4  START.  TIOCSTART reaches `ttstart', which calls `t_oproc' -- and that
 *      is `ptsstart', whose whole remaining job is this byte: b0 = 8.
 *
 * THE MASTER IS NON-BLOCKING ON PURPOSE.  A missing status byte leaves the
 * queue empty, and a blocking master would simply hang there -- which names
 * nothing, and is the shape this campaign has already recorded as a poor
 * measurement.  With FIONBIO the same absence reads back as n=-1 against an
 * expected n=1, and the line says which of the four is missing.
 *
 * THE ioctl CHECKS ARE `< 0', NOT `!= 0'.  A successful FGX ioctl answers C=1
 * with whatever the arm happened to leave in A, and `_PtyM_Ioctl's TIOCPKT arm
 * leaves the pair's flags word there -- upstream returns (0).  Asserting on an
 * undefined success value would make this fixture a report about that instead
 * of about `pt_send', so it tests the sign, as ptytest does.
 *
 * NO NEWLINE IN THE PAYLOAD, for ptyrec's and ptyoutq's reason: `_PtyS_Write'
 * applies the slave tty's CRMOD, so an LF would arrive as CR+LF and the counts
 * would be off by one for a reason unrelated to the question.
 */
#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/file.h>

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
	int m, s, n, on, arg, bad;
	char buf[16];

	bad = 0;

	m = open(master, 2);
	if (m < 0) {
		printf("PTYPKT FAIL master\n");
		return 1;
	}
	s = open(slave, 2);
	if (s < 0) {
		printf("PTYPKT FAIL slave\n");
		return 1;
	}

	on = 1;
	if (ioctl(m, TIOCPKT, (char *)&on) < 0) {
		printf("PTYPKT FAIL pkt\n");
		return 1;
	}
	on = 1;
	if (ioctl(m, FIONBIO, (char *)&on) < 0) {
		printf("PTYPKT FAIL nbio\n");
		return 1;
	}

	/* 1  THE POSITIVE CONTROL: packet mode prefixes a data read. */
	if (write(s, out, 5) != 5) {
		printf("PTYPKT FAIL write\n");
		return 1;
	}
	for (n = 0; n < 16; n++)
		buf[n] = 0;
	n = read(m, buf, 16);
	printf("PTYPKT data n=%d b0=%d b1=%d\n", n, buf[0], buf[1]);
	if (n != 6 || buf[0] != TIOCPKT_DATA || buf[1] != 'A') {
		printf("PTYPKT DEAD\n");    /* packet mode itself: read no further */
		(void) close(s);
		(void) close(m);
		return 1;
	}

	/* 2  FLUSH: the master is told, AND the bytes are gone. */
	if (write(s, out, 5) != 5) {
		printf("PTYPKT FAIL write2\n");
		return 1;
	}
	arg = FWRITE;
	if (ioctl(s, TIOCFLUSH, (char *)&arg) < 0) {
		printf("PTYPKT FAIL flush\n");
		return 1;
	}
	for (n = 0; n < 16; n++)
		buf[n] = 0;
	n = read(m, buf, 16);
	printf("PTYPKT flush n=%d b0=%d\n", n, buf[0]);
	if (n != 1 || buf[0] != TIOCPKT_FLUSHWRITE)
		bad++;
	for (n = 0; n < 16; n++)
		buf[n] = 0;
	n = read(m, buf, 16);
	printf("PTYPKT flushed n=%d b0=%d\n", n, buf[0]);
	if (n > 0)
		bad++;                     /* the flush discarded nothing */

	/* 3  STOP. */
	arg = 0;
	if (ioctl(s, TIOCSTOP, (char *)&arg) < 0) {
		printf("PTYPKT FAIL stop\n");
		return 1;
	}
	for (n = 0; n < 16; n++)
		buf[n] = 0;
	n = read(m, buf, 16);
	printf("PTYPKT stop n=%d b0=%d\n", n, buf[0]);
	if (n != 1 || buf[0] != TIOCPKT_STOP)
		bad++;

	/* 4  START. */
	arg = 0;
	if (ioctl(s, TIOCSTART, (char *)&arg) < 0) {
		printf("PTYPKT FAIL start\n");
		return 1;
	}
	for (n = 0; n < 16; n++)
		buf[n] = 0;
	n = read(m, buf, 16);
	printf("PTYPKT start n=%d b0=%d\n", n, buf[0]);
	if (n != 1 || buf[0] != TIOCPKT_START)
		bad++;

	if (bad == 0)
		printf("PTYPKT BSD\n");
	else
		printf("PTYPKT MISSING %d\n", bad);

	(void) close(s);
	(void) close(m);
	return 0;
}
