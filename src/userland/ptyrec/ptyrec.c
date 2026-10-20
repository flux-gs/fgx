/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 4.3BSD-Reno ptcread()
 * (kern/tty_pty.c) as the behaviour under test.
 *
 * ptyrec - a read(2) on a pty MASTER returns a whole RECORD (apple/fgx#198).
 *
 * THIS PATH HAD NO TEST AT ALL, which is how it came to be decided by a flag
 * the driver wrote through the wrong pointer.  Measured 2026-08-22: with the
 * pty master's record mode DISABLED, the entire 34-test gate stays green,
 * telnet_loopback stays green (its own manifest declines to assert the `login:'
 * prompt, which is the only output a master read produces), and ptykey stays
 * green because it WRITES to the master and never reads it.
 *
 * WHAT RECORD MODE IS.  _PtyM_Read fills the caller's buffer whole and returns
 * a COUNT; _Sys_Read must therefore dispatch it ONCE rather than loop it a byte
 * at a time.  Which of the two happens is what this asserts, and the two are
 * trivially distinguishable: the per-byte loop takes the driver's COUNT and
 * stores it as one byte's VALUE, so a five-byte record comes back as n=1 with a
 * 5 where the first character should be.
 *
 * THE SLAVE IS THE WRITER because the ring under test is the slave->master one.
 * The master is opened FIRST and kept open: /dev/ttyp0 cannot be opened until
 * the master side has created the pair (see cdtwo).
 *
 * NO NEWLINE IN THE PAYLOAD, deliberately.  _PtyS_Write applies the slave tty's
 * CRMOD, so an LF would arrive as CR+LF and the count would be six -- a real
 * behaviour, but not the one under test, and it would make a failure ambiguous.
 */
#include <stdio.h>

int open(char *path, int flags);
int close(int fd);
int read(int fd, char *buf, int n);
int write(int fd, char *buf, int n);

static char master[] = "/dev/ptyp0";
static char slave[]  = "/dev/ttyp0";
static char out[]    = "ABCDE";

int
main()
{
	int m, s, n, i;
	char buf[16];

	m = open(master, 2);
	if (m < 0) {
		printf("PTYREC FAIL master\n");
		return 1;
	}
	s = open(slave, 2);
	if (s < 0) {
		printf("PTYREC FAIL slave\n");
		(void) close(m);
		return 1;
	}

	n = write(s, out, 5);
	if (n != 5) {
		printf("PTYREC FAIL write n=%d\n", n);
		(void) close(s);
		(void) close(m);
		return 1;
	}

	for (i = 0; i < 16; i++)
		buf[i] = 0;
	n = read(m, buf, 16);

	/* THE COUNT AND THE FIRST BYTE, both.  The count alone would pass on a
	 * driver that returned 5 without moving anything, and the byte alone
	 * would pass on the per-byte loop -- which does leave 'A' in the buffer,
	 * because the record op wrote it there before the loop overwrote it with
	 * the count. */
	printf("PTYREC n=%d b0=%d\n", n, buf[0]);
	if (n == 5 && buf[0] == 'A' && buf[4] == 'E')
		printf("PTYREC OK\n");
	else
		printf("PTYREC BAD\n");

	(void) close(s);
	(void) close(m);
	return 0;
}
