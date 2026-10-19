/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD printenv(1)
 *   Ported from printenv(1), 2.11BSD (usr/ucb/printenv.c, 5.1 Berkeley
 *   5/31/85; Bill Joy, UCB, February 1979).  Original work:
 *   Copyright (c) 1980, 1993 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * printenv - print out the environment.  Verbatim port of 2.11BSD
 * printenv(1): with no argument print every NAME=VALUE; with a NAME
 * argument print just that value.  Exit 0 if something was printed,
 * 1 if not (BSD's !found).
 *
 * This is the BSD way to inspect the environment -- there is no env(1)
 * in 2.11BSD.  FGX needs it as a real binary because the Bourne shell has
 * no such builtin; jsh's `env` builtin had been standing in for it, so
 * nothing showed the environment once bsh became the login shell.
 *
 * Depends on libc's POSIX `environ`, which is what crt0 publishes from the
 * kernel's args_env block.
 */
#include <stdio.h>

extern	char **environ;

static int
prefix(cp, dp)
	char	*cp, *dp;
{
	while (*cp && *dp && *cp == *dp)
		cp++, dp++;
	if (*cp == 0)
		return (*dp == '=');
	return (0);
}

int
main(argc, argv)
	int	argc;
	char	**argv;
{
	register char **ep;
	int found = 0;

	argc--, argv++;
	if (environ)
		for (ep = environ; *ep; ep++)
			if (argc == 0 || prefix(argv[0], *ep)) {
				register char *cp = *ep;

				found++;
				if (argc) {
					while (*cp && *cp != '=')
						cp++;
					if (*cp == '=')
						cp++;
				}
				printf("%s\n", cp);
			}
	return (!found);
}
