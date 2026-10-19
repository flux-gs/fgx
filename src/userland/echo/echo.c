/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD echo(1)
 *   Ported from echo(1), 2.11BSD (usr/bin/echo.c, 4.2 Berkeley 5/27/85).
 *   Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * echo - write arguments to standard output.  Verbatim port of 2.11BSD
 * echo(1): args separated by single blanks, terminated by a newline unless
 * -n is given.
 *
 * FGX needs this as a real binary, not a shell builtin.  The Bourne shell
 * has no echo builtin -- v7 and 2.11BSD sh both fork /bin/echo -- so once
 * bsh became /bin/sh and the login shell, every `echo` in a script or at
 * the prompt failed with "echo: not found".  jsh's builtin had been
 * covering for its absence.
 */
#include <stdio.h>

int
main(argc, argv)
	int	argc;
	char	**argv;
{
	register int i, nflg;

	nflg = 0;
	if (argc > 1 && argv[1][0] == '-' && argv[1][1] == 'n' && !argv[1][2]) {
		nflg++;
		argc--;
		argv++;
	}
	for (i = 1; i < argc; i++) {
		fputs(argv[i], stdout);
		if (i < argc-1)
			putchar(' ');
	}
	if (nflg == 0)
		putchar('\n');
	return 0;
}
