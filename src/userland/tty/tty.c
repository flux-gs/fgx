/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD tty(1)
 *   Ported from tty(1), 2.11BSD (4.1, Berkeley, 10/1/80).  Original work:
 *   the Regents of the University of California; the 2.11BSD file
 *   carries no copyright notice.
 *   FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * vendor/2.11BSD/usr/usr.bin/tty.c, verbatim below this comment.
 */
static char *sccsid = "@(#)tty.c	4.1 (Berkeley) 10/1/80";
/*
 * Type tty name
 */

char	*ttyname();

main(argc, argv)
char **argv;
{
	register char *p;

	p = ttyname(0);
	if(argc==2 && !strcmp(argv[1], "-s"))
		;
	else
		printf("%s\n", (p? p: "not a tty"));
	exit(p? 0: 1);
}
