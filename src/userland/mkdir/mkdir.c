/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 1983 Regents of the University of California.
 *
 * FGX-Provenance: 2.11BSD mkdir(1)
 *   Ported from mkdir.c 5.7 (Berkeley) 5/31/90 (usr/bin/mkdir.c).
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * FGX adaptations (mechanical port):
 *   - mkdir(2) is SYS_MKDIR on FGX; the kernel applies the umask to the
 *     0777 mode (`& 0777 &~ u_cmask', as upstream's kernel does).
 *   - Dropped the DOSCCS copyright/sccsid blocks and <sys/types.h> include.
 *   - -p (create intermediate dirs) is preserved verbatim (stat + mkdir walk).
 */
#include <sys/stat.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

extern int optind;

int build();
int usage();

int main(argc, argv)
	int argc;
	char **argv;
{
	int ch, exitval, pflag;

	pflag = 0;
	while ((ch = getopt(argc, argv, "p")) != EOF)
		switch (ch) {
		case 'p':
			pflag = 1;
			break;
		case '?':
		default:
			usage();
		}

	if (!*(argv += optind))
		usage();

	for (exitval = 0; *argv; ++argv)
		if (pflag)
			exitval |= build(*argv);
		else if (mkdir(*argv, 0777) < 0) {
			fprintf(stderr, "mkdir: %s: %s\n",
			    *argv, strerror(errno));
			exitval = 1;
		}
	exit(exitval);
	return exitval;
}

int build(path)
	char *path;
{
	register char *p;
	struct stat sb;
	int create, ch;

	for (create = 0, p = path;; ++p)
		if (!*p || *p == '/') {
			ch = *p;
			*p = '\0';
			if (stat(path, &sb)) {
				if (errno != ENOENT || mkdir(path, 0777) < 0) {
					fprintf(stderr, "mkdir: %s: %s\n",
					    path, strerror(errno));
					return (1);
				}
				create = 1;
			}
			if (!(*p = ch))
				break;
		}
	if (!create) {
		fprintf(stderr, "mkdir: %s: %s\n", path, strerror(EEXIST));
		return (1);
	}
	return (0);
}

int usage()
{
	fprintf(stderr, "usage: mkdir [-p] dirname ...\n");
	exit(1);
	return 1;
}
