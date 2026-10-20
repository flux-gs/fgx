/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD ptcwrite()
 * (usr/sys/sys/tty_pty.c:380-420), ptsread() (:100-138), ptcselect()'s FWRITE
 * arm (:358-370) and ptyioctl()'s TIOCREMOTE arm (:501-507) as the behaviour
 * NOT ported.
 *
 * ptyremote - REMOTE MODE IS REFUSED, AND THAT IS THE DIVERGENCE PINNED.
 * TTY campaign T4 increment 6.
 *
 * 2.11BSD's pty has a second input path.  With PF_REMOTE set the master writes
 * whole LINES straight into the slave's `t_canq', bypassing the line discipline
 * completely, and terminates each one with a NUL:
 *
 *      while (uio->uio_resid && tp->t_canq.c_cc < TTYHOG - 1) {
 *              ...
 *              (void) b_to_q(cp, cc, &tp->t_canq);
 *      }
 *      (void) putc(0, &tp->t_canq);
 *
 * and `ptsread' drains until ONE character is left, then discards it -- so the
 * NUL is what makes one `write(2)' one record.  It is for a master that does
 * its own line editing and must not be edited a second time locally; the
 * canonical customer is a login daemon in LINEMODE.
 *
 * IT IS NOT PORTED, AND THE REASON IS STRUCTURAL RATHER THAN EFFORT.  The pty
 * master's `d_write' slot is 0 ("none -- per-byte"), so spec_chwrite hands it
 * one byte at a time, and a per-byte path cannot place a per-write(2)
 * sentinel, because no byte in it knows that it is the last one.  REMOTE mode
 * needs the master to take the whole uio in a bulk `d_write'.
 *
 * AND NOTHING ANYWHERE ASKS FOR IT.  `TIOCREMOTE' appears in exactly two files
 * in the 2.11BSD tree -- `usr/sys/h/ioctl.h' and `usr/sys/sys/tty_pty.c' -- and
 * in two in FGX's, both vendored copies of those.  2.11BSD's own `rlogin' is
 * vendored and does not use it.  FGX's telnetd sets TIOCPKT and drops the
 * status byte unread, so it is not a LINEMODE daemon either (apple/fgx#143).
 *
 * SO WHAT THIS ASSERTS IS THE REFUSAL, because the alternative to porting is
 * not "do nothing" -- it is "fail the way an unsupported ioctl must".  A
 * TIOCREMOTE that returned success would leave a caller believing its next
 * write went in as a record, and the bytes would instead be edited by the very
 * discipline REMOTE mode exists to bypass.  ENOTTY is upstream's own answer for
 * a command a device does not implement, and it is what the fall-through in
 * `_Io_CdThenTty' already produces -- but "already produces" is a claim, and
 * this is the measurement of it.
 *
 * THE MASTER STAYS USABLE AFTERWARDS, which is the second half and not a
 * decoration: an ioctl that is refused must not disturb the device.  So the
 * refusal is followed by an ordinary write and read on the same pair.
 */
#include <stdio.h>
#include <sys/ioctl.h>

#define TIOCREMOTE 0x7469       /* _IOW(t, 105, int) -- ioctl.h:215.  NOT in
                                 * <sgtty.h> on purpose: the header describes
                                 * what FGX implements, and this is the one
                                 * command under test precisely because it is
                                 * not implemented. */
#define ENOTTY_    25

extern int errno;

int open(char *path, int flags);
int close(int fd);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);
int ioctl(int fd, int cmd, char *arg);

static char master[] = "/dev/ptyp0";
static char slave[]  = "/dev/ttyp0";
static char out[]    = "RMT";

int
main()
{
	int m, s, n, on, rc;
	char buf[16];

	m = open(master, 2);
	if (m < 0) {
		printf("PTYREMOTE FAIL master\n");
		return 1;
	}
	s = open(slave, 2);
	if (s < 0) {
		printf("PTYREMOTE FAIL slave\n");
		return 1;
	}

	/* 1  THE REFUSAL.  A silent success is the failure this exists to
	 *    catch, so the RETURN is what is asserted, not a side effect. */
	on = 1;
	errno = 0;
	rc = ioctl(m, TIOCREMOTE, (char *)&on);
	printf("PTYREMOTE remote rc=%d e=%d\n", rc, errno);

	/* 2  THE DEVICE IS UNDISTURBED.  A refused ioctl that had half-applied
	 *    would show up here and nowhere else. */
	if (write(s, out, 3) != 3) {
		printf("PTYREMOTE FAIL write\n");
		return 1;
	}
	for (n = 0; n < 16; n++)
		buf[n] = 0;
	n = read(m, buf, 16);
	printf("PTYREMOTE after n=%d b0=%d b2=%d\n", n, buf[0], buf[2]);

	if (rc >= 0)
		printf("PTYREMOTE ACCEPTED\n");     /* the silent-success case */
	else if (n == 3 && buf[0] == 'R' && buf[2] == 'T')
		printf("PTYREMOTE REFUSED\n");
	else
		printf("PTYREMOTE DISTURBED\n");

	(void) close(s);
	(void) close(m);
	return 0;
}
