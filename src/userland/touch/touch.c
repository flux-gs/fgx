/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD touch(1)
 *   Ported from touch(1), 2.11BSD (touch.c 4.3 1983/8/11; Berkeley).
 *   Copyright (c) 1983 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * The mtime bump is upstream's read+rewrite-first-byte trick, not utimes(2).
 *
 * FGX adaptations:
 *   - argc guard added (the 4.3BSD original derefs argv[argc] on no args).
 */
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

int	dontcreate;	/* set if -c option */
int	force;		/* set if -f option */

char *whoami = "touch";

int touch();
int readwrite();

int main(argc, argv)
	int	argc;
	char	**argv;
{
	char	*argp;

	if (argc < 2)
		exit(0);
	dontcreate = 0;
	force = 0;
	for (argv++; *argv && **argv == '-'; argv++) {
		for (argp = &(*argv)[1]; *argp; argp++) {
			switch (*argp) {
			case 'c':
				dontcreate = 1;
				break;
			case 'f':
				force = 1;
				break;
			default:
				fprintf(stderr, "%s: bad option -%c\n",
					whoami, *argp);
				exit(1);
			}
		}
	}
	for (/*void*/; *argv; argv++) {
		touch(*argv);
	}
	return 0;
}

int touch(filename)
	char	*filename;
{
	struct stat	statbuffer;

	if (stat(filename, &statbuffer) == -1) {
		if (!dontcreate) {
			readwrite(filename, 0L);
		} else {
			fprintf(stderr, "%s: %s: does not exist\n",
				whoami, filename);
		}
		return 0;
	}
	if ((statbuffer.st_mode & S_IFMT) != S_IFREG) {
		fprintf(stderr, "%s: %s: can only touch regular files\n",
			whoami, filename);
		return 0;
	}
	if (!access(filename, 4|2)) {
		readwrite(filename, statbuffer.st_size);
		return 0;
	}
	if (force) {
		if (chmod(filename,0666)) {
			fprintf(stderr, "%s: %s: couldn't chmod: ",
				whoami, filename);
			perror("");
			return 0;
		}
		readwrite(filename,statbuffer.st_size);
		if (chmod(filename,statbuffer.st_mode)) {
			fprintf(stderr, "%s: %s: couldn't chmod back: ",
				whoami, filename);
			perror("");
			return 0;
		}
	} else {
		fprintf(stderr, "%s: %s: cannot touch\n", whoami, filename);
	}
	return 0;
}

int readwrite(filename, size)
	char	*filename;
	off_t	size;
{
	int	filedescriptor;
	char	first;

	if (size) {
		filedescriptor = open(filename, 2);
		if (filedescriptor == -1) {
error:
			fprintf(stderr, "%s: %s: ", whoami, filename);
			perror("");
			return 0;
		}
		if (read(filedescriptor, &first, 1) != 1) {
			goto error;
		}
		if (lseek(filedescriptor, 0L, 0) == -1) {
			goto error;
		}
		if (write(filedescriptor, &first, 1) != 1) {
			goto error;
		}
	} else {
		filedescriptor = creat(filename, 0666);
		if (filedescriptor == -1) {
			goto error;
		}
	}
	if (close(filedescriptor) == -1) {
		goto error;
	}
	return 0;
}
