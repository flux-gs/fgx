/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD grep(1)
 *   Front-end derived from grep.c 4.6 (Berkeley 5/14/84), usr/bin/grep.c
 *   (main/execute/succeed, flag set, -i pattern-rewrite).  The regexp engine
 *   lives in ../lib/regexp.c (2.11BSD regex.c, its own provenance row).
 *   Original work: Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX changes
 *   are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * grep -- print lines matching a basic regular expression.
 *   status: 0 = matches found, 1 = no matches, 2 = error.
 *
 * The matcher is the reusable ed-style BRE engine in ../lib/regexp.c (the same
 * lineage vi/ex reuse).  grep's I/O loop is freopen(file,"r",stdin) +
 * getchar() -- the Phase 0 primitives.
 *
 * FGX/fcc adaptations (no feature loss):
 *  - Lines are terminated by '\n' OR '\r' (FGX text is CR-terminated; other
 *    ported tools key on CR too).  Output prints '\n'; libc maps LF->CR for the
 *    console.
 *  - Hand-rolled islower/toupper (no <ctype.h>); `&arr[i]` written `arr + i`.
 *  - Flags: -i/-y (case-insensitive via [Xx] pattern rewrite), -w (\<word\>),
 *    -x (whole line, ^...$), -v -n -c -l -h -s -e, clustered (-iv).  Dropped -b
 *    (no Unix block concept for FGX files; not faked).
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#ifndef lint
static char sccsid[] = "@(#)grep.c\t4.6 (Berkeley) 5/14/84";
#endif not lint

#include <stdio.h>

/* libc decls not in <stdio.h>. */
void  exit(int code);

/* The ed-style BRE engine: re_comp / re_exec + the opcodes, ESIZE/NBRA and the
   re_wflag seam.  fcc has no separate compilation, so the engine is shared by
   textual #include -- vi will include the same file (Phase 4.3). */
#include "../lib/regexp.c"

#define LBSIZE  1024            /* line buffer (LBSIZE+1 bytes incl. NUL) */

/* ANSI forward prototypes (front-end; engine protos come from regexp.c) */
int   main(int argc, char **argv);
void  execute(char *file);
void  succeed(char *f);
void  errexit(char *s);
int   islow(int c);
int   isup(int c);
int   upcase(int c);
int   locase(int c);

int islow(int c)  { return c >= 'a' && c <= 'z'; }
int isup(int c)   { return c >= 'A' && c <= 'Z'; }
int upcase(int c) { return islow(c) ? c - 'a' + 'A' : c; }
int locase(int c) { return isup(c)  ? c - 'A' + 'a' : c; }

char  linebuf[LBSIZE + 1];
char  patbuf[ESIZE];            /* -i rewritten pattern */
char  xbuf[ESIZE];              /* -x ^...$ wrapped pattern */
long  lnum;
long  tln;                      /* match count for -c */
int   nfile;                    /* number of file operands */
int   nsucc;                    /* any line matched at all (for exit status) */
int   retcode;                  /* 2 if any file errored */
int   hflag = 1;                /* print filename prefix (cleared by -h) */
int   sflag;                    /* -s silent */
int   vflag;                    /* -v invert */
int   nflag;                    /* -n line number */
int   cflag;                    /* -c count only */
int   lflag;                    /* -l list filenames only */
int   iflag;                    /* -i/-y case-insensitive */
int   xflag;                    /* -x whole-line match */

int
main(int argc, char **argv)
{
	char *pat;
	char *src, *dst;
	char *msg;

	/* option scan (FGX-original, grep.c's flag semantics + clustered flags
	   like -iv).  Advances argv/argc in the body rather than via grep.c's
	   `while (--argc>0 && (++argv)[0][0]=='-')` -- the body-advance form reads
	   cleaner and clusters single-char flags.  ((++argv)[0][0] itself now
	   compiles in fcc; the paren-subscript-on-T** gap it once hit is fixed.) */
	argc--;                                 /* skip program name (argv[0]) */
	argv++;
	while (argc > 0 && argv[0][0] == '-') {
		char *f = argv[0] + 1;
		if (*f == '\0')                 /* lone "-" : a file operand, stop */
			break;
		for (; *f; f++) {
			switch (*f) {
			case 'i': case 'y': iflag = 1; break;
			case 'w': re_wflag = 1; break;
			case 'x': xflag = 1; break;
			case 'h': hflag = 0; break;
			case 's': sflag = 1; break;
			case 'v': vflag = 1; break;
			case 'l': lflag = 1; break;
			case 'c': cflag = 1; break;
			case 'n': nflag = 1; break;
			case 'e':                       /* -e PATTERN: consume arg, pattern next */
				argc--; argv++;
				goto outflags;
			default:
				errexit("grep: unknown flag");
			}
		}
		argc--;
		argv++;
	}
outflags:
	if (argc <= 0)
		exit(2);
	pat = argv[0];

	/* -i: rewrite each cased letter into a two-element class, e.g. a -> [Aa],
	   A -> [Aa], so the case-sensitive engine matches either case.  (grep.c's
	   yflag block folded only LOWERCASE letters -- so `grep -i ABC` there
	   didn't match "abc"; we fold uppercase too, matching real grep.) */
	if (iflag) {
		dst = patbuf;
		for (src = pat; *src; ) {
			if (*src == '\\') {
				*dst++ = *src++;
				if (*src)
					*dst++ = *src++;
			} else if (*src == '[') {
				while (*src != '\0' && *src != ']')
					*dst++ = *src++;
			} else if (islow(*src) || isup(*src)) {
				*dst++ = '[';
				*dst++ = upcase(*src);
				*dst++ = locase(*src);
				*dst++ = ']';
				src++;
			} else
				*dst++ = *src++;
			if (dst >= patbuf + ESIZE - 5)
				errexit("grep: argument too long");
		}
		*dst = '\0';
		pat = patbuf;
	}

	/* -x: anchor whole-line as ^...$ (built on top of any -i rewrite, reading
	   pat -- argv[0] or patbuf -- into a separate xbuf). */
	if (xflag) {
		dst = xbuf;
		*dst++ = '^';
		for (src = pat; *src && dst < xbuf + ESIZE - 2; )
			*dst++ = *src++;
		*dst++ = '$';
		*dst = '\0';
		pat = xbuf;
	}

	if (msg = re_comp(pat)) {
		fprintf(stderr, "grep: %s\n", msg);
		exit(2);
	}

	nfile = argc - 1;
	if (argc <= 1) {                        /* no file operands: read stdin */
		if (lflag)
			exit(1);
		execute((char *)0);
	} else
		while (--argc > 0) {
			argv++;
			execute(*argv);
		}
	exit(retcode != 0 ? retcode : (nsucc == 0));
	return 0;
}

void
execute(file)
	char *file;
{
	register char *p1;
	register int   c;

	if (file) {
		if (freopen(file, "r", stdin) == NULL) {
			perror(file);
			retcode = 2;
			return;
		}
	}
	lnum = 0;
	tln = 0;
	for (;;) {
		lnum++;
		p1 = linebuf;
		while ((c = getchar()) != '\n' && c != '\r') {
			if (c == EOF) {
				if (cflag) {
					if (nfile > 1)
						printf("%s:", file);
					printf("%ld\n", tln);
				}
				return;
			}
			*p1++ = c;
			if (p1 >= linebuf + LBSIZE - 1)
				break;
		}
		*p1 = '\0';
		/* a "hit" = matched unless -v inverts.  re_exec returns non-zero on
		   match (incl. -1 internal-error, treated as match like BSD). */
		if (re_exec(linebuf) ? !vflag : vflag) {
			nsucc = 1;
			if (lflag) {            /* -l: print the filename ONCE, stop this file */
				printf("%s\n", file);
				return;
			}
			succeed(file);
		}
	}
}

/* Emit one matching line per the output flags.  nsucc + -l are handled by the
   caller (execute); -l never reaches here. */
void
succeed(f)
	char *f;
{
	if (sflag)
		return;
	if (cflag) {
		tln++;
		return;
	}
	if (nfile > 1 && hflag)
		printf("%s:", f);
	if (nflag)
		printf("%ld:", lnum);
	printf("%s\n", linebuf);
}

void
errexit(s)
	char *s;
{
	fprintf(stderr, "%s\n", s);
	exit(2);
}
