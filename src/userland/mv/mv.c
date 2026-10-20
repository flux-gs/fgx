/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 1980 Regents of the University of California.
 *
 * FGX-Provenance: 2.11BSD mv(1)
 *   Ported from mv.c 5.3.1 (2.11BSD) 1996/1/5 (usr/bin/mv.c).
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * mv - move/rename files & directories.  -i (interactive), -f (force).
 *   mv f1 f2            rename f1 to f2
 *   mv f1 ... fn dir    move each into dir
 *
 * FGX adaptations (mechanical port):
 *  - rename(2) is SYS_RENAME: in-place when source and target share a parent
 *    directory and the target is absent; otherwise EXDEV, and we copy+unlink
 *    (exactly BSD's cross-filesystem fallback).  So same-dir renames — files
 *    AND directories — are atomic; everything else is copy+unlink.
 *  - The ISDEV branch is out: FGX has no mknod(2), so a device node moved
 *    across file systems gets upstream's "unknown file type" refusal.
 *  - copy buffer is a static block (the IIgs has no room for BSD's 8 KB auto).
 */
#include <sys/stat.h>
#include <sys/dir.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>

#define	DELIM	'/'
#ifndef MAXPATHLEN
#define MAXPATHLEN 128
#endif
#ifndef S_IFMT
#define S_IFMT   0170000
#endif
#ifndef S_IFDIR
#define S_IFDIR  0040000
#endif

#define MODEBITS 07777
#define	ISDIR(st)	(((st).st_mode & S_IFMT) == S_IFDIR)
#define	ISLNK(st)	(((st).st_mode & S_IFMT) == S_IFLNK)
#define	ISREG(st)	(((st).st_mode & S_IFMT) == S_IFREG)

struct	stat s1, s2;
int	iflag;			/* -i interactive mode */
int	fflag;			/* -f force overwriting */

char	copybuf[1024];		/* copy fallback block buffer (static, not stack) */

int move();
int movewithshortname();
int query();
char *dname();
int mv_error();
int Perror2();

int main(argc, argv)
	char *argv[];
{
	int i, r;
	register char *arg;
	char *dest;

	iflag = 0;
	fflag = 0;
	if (argc < 2)
		goto usage;
	while (argc > 1 && *argv[1] == '-') {
		argc--;
		arg = *++argv;
		if (*(arg + 1) == '\0')		/* bare "-" ends options */
			break;
		while (*++arg != '\0')
			switch (*arg) {
			case 'i':
				iflag++;
				break;
			case 'f':
				fflag++;
				break;
			default:
				goto usage;
			}
	}
	if (argc < 3)
		goto usage;
	dest = argv[argc - 1];
	if (stat(dest, &s2) >= 0 && ISDIR(s2)) {
		r = 0;
		for (i = 1; i < argc - 1; i++)
			r |= movewithshortname(argv[i], dest);
		exit(r);
	}
	if (argc > 3)
		goto usage;
	r = move(argv[1], argv[2]);
	exit(r);

usage:
	fprintf(stderr,
"usage: mv [-if] f1 f2 or mv [-if] f1 ... fn d1 (`fn' is a file or directory)\n");
	exit(1);
	return (1);
}

int movewithshortname(src, dest)
	char *src, *dest;
{
	register char *shortname;
	char target[MAXPATHLEN + 1];

	shortname = dname(src);
	if (strlen(dest) + strlen(shortname) > MAXPATHLEN - 1) {
		mv_error("%s/%s: pathname too long", dest, shortname);
		return (1);
	}
	sprintf(target, "%s/%s", dest, shortname);
	return (move(src, target));
}

int move(source, target)
	char *source, *target;
{
	int targetexists;

	if (lstat(source, &s1) < 0) {
		Perror2(source, "Cannot access");
		return (1);
	}
	/*
	 * First, try to rename source to destination.
	 * The only reason we continue on failure is if
	 * the move is on a nondirectory and not across
	 * file systems.
	 */
	targetexists = lstat(target, &s2) >= 0;
	if (targetexists) {
		if (s1.st_dev == s2.st_dev && s1.st_ino == s2.st_ino) {
			mv_error("%s and %s are identical", source, target);
			return (1);
		}
		if (iflag && !fflag && isatty(fileno(stdin)) &&
		    query("remove %s? ", target) == 0)
			return (1);
		if (access(target, 2) < 0 && !fflag && isatty(fileno(stdin))) {
			if (query("override protection %o for %s? ",
			  s2.st_mode & MODEBITS, target) == 0)
				return (1);
		}
	}
	if (rename(source, target) >= 0)
		return (0);
	if (errno != EXDEV) {
		Perror2(errno == ENOENT && targetexists == 0 ? target : source,
		    "rename");
		return (1);
	}
	if (ISDIR(s1)) {
		mv_error("can't mv directories across file systems");
		return (1);
	}
	if (targetexists && unlink(target) < 0) {
		Perror2(target, "Cannot unlink");
		return (1);
	}
	/*
	 * File can't be renamed, try to recreate the symbolic
	 * link, or copy the file wholesale between file systems.
	 */
	if (ISLNK(s1)) {
		register m;
		char symln[MAXPATHLEN + 1];

		m = readlink(source, symln, sizeof (symln) - 1);
		if (m < 0) {
			perror(source);
			return (1);
		}
		symln[m] = '\0';

		m = umask(~(s1.st_mode & MODEBITS));
		if (symlink(symln, target) < 0) {
			perror(target);
			return (1);
		}
		(void) umask(m);
		goto cleanup;
	}
	if (ISREG(s1)) {
		register int fi, fo, n;
		struct timeval tv[2];

		fi = open(source, 0);
		if (fi < 0) {
			perror(source);
			return (1);
		}

		fo = creat(target, s1.st_mode & MODEBITS);
		if (fo < 0) {
			perror(target);
			close(fi);
			return (1);
		}

		for (;;) {
			n = read(fi, copybuf, sizeof copybuf);
			if (n == 0) {
				break;
			} else if (n < 0) {
				Perror2(source, "read");
				close(fi);
				close(fo);
				return (1);
			} else if (write(fo, copybuf, n) != n) {
				Perror2(target, "write");
				close(fi);
				close(fo);
				return (1);
			}
		}

		close(fi);
		close(fo);

		tv[0].tv_sec = s1.st_atime;
		tv[0].tv_usec = 0;
		tv[1].tv_sec = s1.st_mtime;
		tv[1].tv_usec = 0;
		(void) utimes(target, tv);
		goto cleanup;
	}
	mv_error("%s: unknown file type %o", source, s1.st_mode);
	return (1);

cleanup:
	if (unlink(source) < 0) {
		Perror2(source, "Cannot unlink");
		return (1);
	}
	return (0);
}

/*VARARGS*/
int query(prompt, a1, a2)
	char *prompt, *a1, *a2;
{
	register int i, c;

	fprintf(stderr, prompt, a1, a2);
	i = c = getchar();
	while (c != '\n' && c != EOF)
		c = getchar();
	return (i == 'y');
}

char *dname(name)
	register char *name;
{
	register char *p;

	p = name;
	while (*p)
		if (*p++ == DELIM && *p)
			name = p;
	return (name);
}

/*VARARGS*/
int mv_error(fmt, a1, a2)
	char *fmt, *a1, *a2;
{
	fprintf(stderr, "mv: ");
	fprintf(stderr, fmt, a1, a2);
	fprintf(stderr, "\n");
	return (0);
}

int Perror2(s, msg)
	char *s, *msg;
{
	fprintf(stderr, "mv: %s: %s\n", s, msg);
	return (0);
}
