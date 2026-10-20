/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 1980, 1986 Regents of the University of California.
 *
 * FGX-Provenance: 2.11BSD rm(1)
 *   Ported from rm.c 4.18 (Berkeley) 1/6/86 (usr/bin/rm.c).
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * rm - remove files, directories & trees.  Full 2.11BSD flag set: -f (force,
 * suppress errors), -i (interactive prompt), -r/-R (recurse).
 *
 * FGX adaptations (mechanical port):
 *  - unlink(2)/rmdir(2) are SYS_UNLINK/SYS_RMDIR; opendir/readdir/closedir are
 *    real libc (over SYS_LISTDIR).  No per-tool stubs.
 *  - -r recursion exploits FGX's SNAPSHOT opendir (whole dir read at open, a
 *    private per-DIR cursor): the parent DIR stays open across the recursive
 *    rm() with no close/reopen/prevname resync dance (readdir's return cell is
 *    a single shared static, so d_name is copied into `path` via append()
 *    BEFORE recursing — which the BSD code already does).  Same snapshot idiom
 *    tar(1)'s port uses.
 *  - errno surfaced via strerror() (the shim returns the real kernel errno).
 */
#include <sys/stat.h>
#include <sys/dir.h>
#include <errno.h>
#include <stdio.h>
/* stdlib.h: malloc returns a far ptr — without the prototype fcc assumes int
 * and drops the bank byte, corrupting the -r path buffer. */
#include <stdlib.h>
#include <string.h>

#ifndef S_IFMT
#define S_IFMT   0170000
#endif
#ifndef S_IFDIR
#define S_IFDIR  0040000
#endif
#ifndef MAXPATHLEN
#define MAXPATHLEN 128
#endif
#ifndef R_OK
#define R_OK 4
#define W_OK 2
#define X_OK 1
#endif

int fflg;               /* -f force - suppress error messages */
int iflg;               /* -i interrogate user on each file */
int rflg;               /* -r recurse */
int errcode;            /* true if errors occurred */

char *path;             /* malloc'd path buffer for -r descent */
char *pathp;            /* current end of path */
int   pathsz;

int rm();
int dotname();
int yes();
int append();

int main(argc, argv)
	char *argv[];
{
	register char *arg;

	fflg = !isatty(0);
	iflg = 0;
	rflg = 0;
	while (argc > 1 && argv[1][0] == '-') {
		arg = *++argv;
		argc--;
		/* a bare "-" ends option parsing */
		if (arg[1] == '\0')
			break;
		while (*++arg != '\0')
			switch (*arg) {
			case 'f':
				fflg++;
				break;
			case 'i':
				iflg++;
				break;
			case 'R':
			case 'r':
				rflg++;
				break;
			default:
				fprintf(stderr, "usage: rm [-rif] file ...\n");
				exit(1);
			}
	}

	if (argc < 2 && !fflg) {
		fprintf(stderr, "usage: rm [-rif] file ...\n");
		exit(1);
	}

	while (--argc > 0)
		(void) rm(*++argv, 0);

	exit(errcode != 0);
	return errcode != 0;
}

/*
 * Remove arg.  Recursive with -r.  Returns TRUE if it removed everything.
 */
int rm(arg, level)
	char arg[];
	int level;
{
	int ok;
	struct stat buf;
	struct direct *dp;
	DIR *dirp;
	char *cp;

	if (dotname(arg)) {
		fprintf(stderr, "rm: cannot remove `.' or `..'\n");
		return (0);
	}
	if (lstat(arg, &buf)) {
		if (!fflg) {
			fprintf(stderr, "rm: %s nonexistent\n", arg);
			errcode++;
		}
		return (0);
	}
	if ((buf.st_mode & S_IFMT) == S_IFDIR) {
		if (!rflg) {
			if (!fflg) {
				fprintf(stderr, "rm: %s directory\n", arg);
				errcode++;
			}
			return (0);
		}
		if (iflg && level != 0) {
			printf("rm: remove directory %s? ", arg);
			if (!yes())
				return (0);
		}
		if (access(arg, R_OK|W_OK|X_OK) != 0) {
			if (rmdir(arg) == 0)
				return (1);	/* salvaged: removed empty dir */
			if (!fflg) {
				fprintf(stderr, "rm: %s not changed\n", arg);
				errcode++;
			}
			return (0);		/* error */
		}
		if ((dirp = opendir(arg)) == NULL) {
			if (!fflg) {
				fprintf(stderr, "rm: cannot read %s?\n", arg);
				errcode++;
			}
			return (0);
		}
		if (level == 0)
			append(arg);
		/* FGX: snapshot DIR + private cursor -> no reopen dance. */
		while ((dp = readdir(dirp)) != NULL) {
			if (dotname(dp->d_name))
				continue;
			append(dp->d_name);        /* copies d_name into path */
			ok = rm(path, level + 1);
			(void) ok;
			/* pop the component we just appended */
			for (cp = pathp; *--cp != '/' && cp > path; )
				;
			pathp = cp;
			*cp = '\0';
		}
		closedir(dirp);
		if (level == 0) {
			pathp = path;
			*pathp = '\0';
		}
		if (iflg) {
			printf("rm: remove %s? ", arg);
			if (!yes())
				return (0);
		}
		if (rmdir(arg) < 0) {
			if (!fflg || iflg) {
				fprintf(stderr, "rm: %s: %s\n",
				    arg, strerror(errno));
				errcode++;
			}
			return (0);
		}
		return (1);
	}

	if (iflg) {
		printf("rm: remove %s? ", arg);
		if (!yes())
			return (0);
	} else if (!fflg) {
		if ((buf.st_mode&S_IFMT) != S_IFLNK && access(arg, W_OK) < 0) {
			printf("rm: override protection %o for %s? ",
				buf.st_mode&0777, arg);
			if (!yes())
				return (0);
		}
	}
	if (unlink(arg) < 0) {
		if (!fflg || iflg) {
			fprintf(stderr, "rm: %s: %s\n", arg, strerror(errno));
			errcode++;
		}
		return (0);
	}
	return (1);
}

/* boolean: is s "." or ".." ? */
int dotname(s)
	char *s;
{
	if (s[0] == '.') {
		if (s[1] == '.') {
			if (s[2] == '\0')
				return (1);
			return (0);
		}
		if (s[1] == '\0')
			return (1);
	}
	return (0);
}

/* yes/no answer from the user (for -i). */
int yes()
{
	int i, b;

	i = b = getchar();
	while (b != '\n' && b != EOF)
		b = getchar();
	return (i == 'y');
}

/* append name to path (the -r descent buffer). */
int append(name)
	char *name;
{
	register int n;

	n = strlen(name);
	if (path == NULL) {
		pathsz = MAXNAMLEN + MAXPATHLEN + 2;
		if ((path = malloc(pathsz)) == NULL) {
			fprintf(stderr, "rm: ran out of memory\n");
			exit(1);
		}
		pathp = path;
	} else if (pathp + n + 2 > path + pathsz) {
		fprintf(stderr, "rm: path name too long: %s\n", path);
		exit(1);
	} else if (pathp != path && pathp[-1] != '/')
		*pathp++ = '/';
	strcpy(pathp, name);
	pathp += n;
	return (0);
}
