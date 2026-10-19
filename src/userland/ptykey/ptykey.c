/*
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.  The pty-master + spawnx recipe is
 * b3ptyrd.c's, which is logintest's.
 *
 * ptykey - the driver half of the apple/fgx#151 measurement.
 *
 * Opens the pty MASTER, spawns a probe on the SLAVE with the slave as its fd 0
 * only (fd 1 and 2 stay on the console, so the probe's verdict reaches the
 * screen), then pushes a line through the master for the probe to read.
 *
 * argv[1] names the probe, defaulting to ptykeyx.  One driver serves both the
 * leak measurement (ptykeyx) and the /dev/tty check (devttyx): the setup they
 * need is identical, and a second copy of it would be a second thing to keep
 * true.
 *
 * Run BACKGROUNDED so the shell can go on to park itself in `sleep', which is
 * what removes the competing console reader.
 *
 * The parent must NEVER exit: the slave's read(2) returns immediately once the
 * last master close lands, and a probe that got EOF instead of the byte would
 * report a false negative.
 */
#include <stdio.h>

int open(char *path, int flags);
int write(int fd, char *buf, int n);
int spawnx(char *path, char **argv, unsigned char *acts);
int sleep(int sec);

static char master[] = "/dev/ptyp1";
static char slave[]  = "/dev/ttyp1";
static char rxpath[] = "/testbin/ptykeyx";     /* default probe */

static char *probe;

/* The bytes that exist ONLY on the probe's terminal.  Nothing types either, so
 * they reach the probe by exactly one route: its own terminal.  Two of them so
 * devttyx can take one through /dev/tty and the other through fd 0 and show
 * that both landed on the same line; ptykeyx reads only the first.
 *
 * THE CR IS LOAD-BEARING.  The slave comes up in the cooked discipline, whose
 * `ttyinput' commits a line only on a terminator (`ttbreakc', tty.c), so
 * a payload without one sits in `t_rawq' and the probe's read(2) blocks
 * forever -- measured, and it reads exactly like the bytes never being
 * written. */
static char payload[] = "XB\r";

static char *gav[2];
static unsigned char fa[64];

int
main(argc, argv)
	int argc;
	char **argv;
{
	int m, i, r;

	probe = (argc > 1) ? argv[1] : rxpath;

	m = open(master, 2);
	if (m < 0) {
		printf("PTYKEY FAIL master\n");
		return 1;
	}

	i = 0;
	/* DETACH first (apple/fgx#60), so the child arrives with no process
	 * group and ttyopen's `p_pgrp == 0' claim fires on the slave -- which
	 * is what gives the probe a pty as its CONTROLLING terminal.  That
	 * binding is the subject: _Vc_CttyIsActive waves a pty ctty through
	 * unconditionally, and this measures what that costs. */
	fa[i++] = 4; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 1; fa[i++] = 3;
	fa[i++] = ((int)slave) & 0xff;
	fa[i++] = (((int)slave) >> 8) & 0xff;
	fa[i++] = 2; fa[i++] = 0;
	/* fd 0 <- slave.  fd 1 and 2 are LEFT ALONE on purpose: the probe's
	 * report has to land on the console for the harness to read it, and
	 * routing it back through the master would need a relay here. */
	fa[i++] = 3; fa[i++] = 0; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 2; fa[i++] = 3; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0; fa[i++] = 0;
	fa[i++] = 0;

	gav[0] = probe;
	gav[1] = (char *)0;
	r = spawnx(probe, gav, fa);
	if (r < 0) {
		printf("PTYKEY FAIL spawn\n");
		return 1;
	}

	printf("PTYKEY READY\n");

	/* Land the byte early: the probe settles, then polls, then reads, so
	 * the pty holds this until its last phase.  Report the write's own
	 * result -- a probe stuck in read(2) says nothing about whether the
	 * byte was ever sent, and that ambiguity cost a run. */
	(void) sleep(2);
	r = write(m, payload, 3);
	printf("PTYKEY WROTE %d\n", r);

	for (;;)
		(void) sleep(30);
}
