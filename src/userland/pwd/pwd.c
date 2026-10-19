/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD pwd(1)
 *   Ported from pwd(1), 2.11BSD (usr/bin/pwd.c, 5.1 Berkeley 4/30/85).
 *   Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * pwd - print the working (current) directory.  Verbatim port.
 *
 * The Bourne shell has no `pwd` builtin -- v7 and 2.11BSD sh both fork
 * /bin/pwd -- so once bsh became the login shell this was a real gap, the
 * same class as /bin/echo and /bin/printenv.
 *
 * getwd() is the 4.xBSD call this expects, and the sole cwd call libc
 * provides -- there is deliberately no getcwd(), so vendored BSD sources
 * compile as written.  It leaves the error MESSAGE in the caller's buffer,
 * which is exactly what the fprintf below prints.
 */
#include <stdio.h>
#include <sys/param.h>

char *getwd();

int
main(argc, argv)
	int	argc;
	char	**argv;
{
	char pathname[MAXPATHLEN + 1];

	if (getwd(pathname) == NULL) {
		fprintf(stderr, "pwd: %s\n", pathname);
		return 1;
	}
	printf("%s\n", pathname);
	return 0;
}
