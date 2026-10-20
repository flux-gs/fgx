/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD time(1)
 *   Ported from time(1), 2.11BSD (time.c 4.5 1983/7/1; Berkeley).
 *   Copyright (c) 1983 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * H1 of the hand-asm retirement roadmap; replaces the hand-asm time.s.
 *
 * FGX adaptations (missing-OS-concept scopes):
 *   - No fork/execvp: spawnvp (libc's execvp-shaped $PATH walk over
 *     the kernel spawn).
 *   - No rusage/CPU accounting: only the "real" line is printed (the
 *     hand-asm time did the same); user/sys need per-process tick
 *     accounting the kernel does not keep.
 *   - Timing via the 60 Hz SYS_TICKS counter (gettimeofday is 1 s-
 *     granular on the IIgs RTC); printed as seconds.tenths like BSD.
 */
#include <stdio.h>
#include <signal.h>

long ticks();
extern int optind;

static char *cargv[18];

int main(argc, argv)
	int	argc;
	char	**argv;
{
	int status, p, i;
	long before, after;

	if (argc <= 1)
		exit(0);
	if (argc > 17) {
		fprintf(stderr, "time: too many arguments\n");
		exit(1);
	}
	for (i = 1; i < argc; i++)
		cargv[i - 1] = (unsigned long)argv[i];
	cargv[argc - 1] = (char *)0;

	before = ticks();
	p = spawnvp(argv[1], cargv);
	if (p < 0) {
		perror(argv[1]);
		exit(1);
	}
	signal(SIGINT, SIG_IGN);
	signal(SIGQUIT, SIG_IGN);
	while (waitpid(p, &status, 0) != p)
		;
	after = ticks() - before;
	if ((status & 0377) != 0)
		fprintf(stderr, "Command terminated abnormally.\n");
	fprintf(stderr, "%9ld.%01ld real\n",
		after / 60L, (after % 60L) * 10L / 60L);
	exit((status >> 8) & 0xFF);
}
