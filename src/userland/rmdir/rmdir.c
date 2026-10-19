/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 1983 Regents of the University of California.
 *
 * FGX-Provenance: 2.11BSD rmdir(1)
 *   Ported from rmdir.c 5.1 (Berkeley) 4/30/85 (usr/bin/rmdir.c).
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX adaptations (mechanical port):
 *   - rmdir(2) is SYS_RMDIR on FGX (removes an EMPTY directory; the kernel
 *     enforces is-dir -> ENOTDIR and empty -> ENOTEMPTY).
 *   - perror() -> fprintf(stderr, ... strerror(errno)) to match the sibling
 *     mkdir(1) port's error style.
 *   - Dropped the copyright[]/sccsid[] blocks.
 */
#include <errno.h>
#include <stdio.h>
#include <string.h>

int main(argc, argv)
	int argc;
	char **argv;
{
	int errors = 0;

	if (argc < 2) {
		fprintf(stderr, "usage: %s directory ...\n", argv[0]);
		exit(1);
	}
	while (--argc)
		if (rmdir(*++argv) < 0) {
			fprintf(stderr, "rmdir: %s: %s\n",
			    *argv, strerror(errno));
			errors++;
		}
	exit(errors != 0);
	return errors != 0;
}
