/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: none.  Original FGX code.
 *
 * statid - print the (st_dev, st_ino) pairs getwd(3) compares, apple/fgx#365.
 *
 * getwd walks up with `for (;;)' and breaks only when the directory it just
 * fstat'd has the SAME st_dev and st_ino as stat("/") reported
 * (toolchain/lib/libc_c/getwd.c:74-76).  There is no iteration cap and no
 * bound on the "../" it appends to a 128-byte buffer each pass, so a walk that
 * never recognises the root writes off the end of the frame -- which is the
 * `stack overflow: killed pid' that kills the multibank sweep at construct 31.
 *
 * This prints both sides of that comparison, in getwd's own order and by
 * getwd's own calls, so the answer is about the same code paths and not about
 * a convenient approximation of them:
 *
 *   stat("/")            -> rdev/rino, the loop's target
 *   stat("./")           -> the walk's starting point
 *   fstat(opendir("./../")) -> what the first pass actually compares
 *   fstat(opendir("/"))  -> the same directory as line 1, reached the other way
 *
 * Lines 1 and 4 name ONE directory through two syscalls.  If they disagree,
 * the walk cannot terminate and getwd is the victim rather than the culprit.
 */
#include <sys/stat.h>
#include <sys/dir.h>
#include <stdio.h>

int stat();
int fstat();
char *strcpy();

static void show(tag, s)
char *tag;
struct stat *s;
{
	printf("SID %-9s dev=%d ino=%u\n", tag, s->st_dev, s->st_ino);
}

int main()
{
	struct stat d;
	DIR *dirp;
	char curdir[128];
	unsigned short rootino;
	short rootdev;

	if (stat("/", &d) < 0) { printf("SID FAIL stat /\n"); return 1; }
	show("root_s", &d);
	rootino = d.st_ino;
	rootdev = d.st_dev;

	strcpy(curdir, "./");
	if (stat(curdir, &d) < 0) { printf("SID FAIL stat ./\n"); return 1; }
	show("dot_s", &d);

	strcpy(curdir, "./../");
	if ((dirp = opendir(curdir)) == (DIR *)0) { printf("SID FAIL opendir ./../\n"); return 1; }
	if (fstat(dirp->dd_fd, &d) < 0) { printf("SID FAIL fstat ./../\n"); return 1; }
	show("dotdot_f", &d);
	closedir(dirp);

	if ((dirp = opendir("/")) == (DIR *)0) { printf("SID FAIL opendir /\n"); return 1; }
	if (fstat(dirp->dd_fd, &d) < 0) { printf("SID FAIL fstat /\n"); return 1; }
	show("root_f", &d);
	closedir(dirp);

	/* THE VERDICT, AND IT IS THE WHOLE POINT.  One directory, two syscalls:
	 * stat(2) by name and fstat(2) by descriptor.  They must agree, because
	 * getwd(3) decides it has reached the root by comparing exactly these
	 * two answers.  Printed as a word rather than left to a fixture matching
	 * numbers with exact spacing. */
	if (d.st_ino == rootino && d.st_dev == rootdev)
		printf("SID MATCH stat/fstat agree on /\n");
	else
		printf("SID MISMATCH stat=%u fstat=%u\n", rootino, d.st_ino);

	/* AND THE THING THAT ACTUALLY MATTERS: does the walk terminate now?
	 * Printed LAST so the pairs above survive on screen if this dies. */
	printf("SID calling getwd\n");
	{
		char wd[128];
		char *w;
		wd[0] = 0;
		w = getwd(wd);
		if (w == (char *)0)
			printf("SID getwd NULL\n");
		else
			printf("SID getwd=[%s]\n", wd);
	}

	printf("SID DONE\n");
	return 0;
}
