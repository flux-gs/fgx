/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code; cites 2.11BSD vhangup() and
 * forceclose() (usr/sys/sys/sys_inode.c:706, :718) as the behaviour under
 * test.
 *
 * vhup - vhangup(2) REVOKES THE CONTROLLING TERMINAL FROM THE FILES OPEN ON
 * IT.  The probe gives up its terminal, opens a pty slave, which makes that
 * its controlling terminal, and calls vhangup.  The descriptor it held must
 * then answer EBADF, and a new open of the same slave must work: telnetd's
 * `open, vhangup, open'.
 *
 * THE WRITE BEFORE THE CALL IS THE POSITIVE CONTROL: an EBADF afterwards
 * means nothing from a descriptor that never worked.
 */
#include <stdio.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <sgtty.h>
#include <sys/file.h>

static char master[] = "/dev/ptyp1";
static char slave[]  = "/dev/ttyp1";

int
main(argc, argv)
	int argc;
	char **argv;
{
	int m, t, s1, s2, r, e;

	m = open(master, O_RDWR);
	if (m < 0) {
		printf("VHUP FAIL master\n");
		return 1;
	}
	t = open("/dev/tty", O_RDWR);
	if (t >= 0) {
		ioctl(t, TIOCNOTTY, 0);
		close(t);
	}
	s1 = open(slave, O_RDWR);
	if (s1 < 0) {
		printf("VHUP FAIL slave e=%d\n", errno);
		return 1;
	}
	if (write(s1, "a", 1) != 1) {
		printf("VHUP FAIL before e=%d\n", errno);
		return 1;
	}
	printf("VHUP open\n");

	(void) signal(SIGHUP, SIG_IGN);
	r = vhangup();
	(void) signal(SIGHUP, SIG_DFL);
	if (r != 0) {
		printf("VHUP FAIL call e=%d\n", errno);
		return 1;
	}

	errno = 0;
	r = write(s1, "b", 1);
	e = errno;
	if (r != -1 || e != EBADF) {
		printf("VHUP FAIL not revoked r=%d e=%d\n", r, e);
		return 1;
	}
	printf("VHUP revoked\n");

	s2 = open(slave, O_RDWR);
	if (s2 < 0 || write(s2, "c", 1) != 1) {
		printf("VHUP FAIL reopen e=%d\n", errno);
		return 1;
	}
	printf("VHUP OK\n");
	return 0;
}
