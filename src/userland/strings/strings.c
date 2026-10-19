/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD strings(1)
 *   Ported from strings(1), 2.11BSD (strings.c 5.1.2, 2.11BSD GTE, 2/25/94).
 *   Original work: Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX changes
 *   are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * strings -- print the printable character runs (>= minlength, default 4) in
 * a file.  The natural companion to od(1)/hd: "what text is in this binary?".
 * Also the validator for the Phase 0 I/O primitives: it reads each input with
 * getc(stdin) and rebinds stdin to each file argument with the canonical
 * freopen(file,"r",stdin) -- the proper implementation, not the head.c
 * open/read workaround.
 *
 * FGX/fcc adaptations (no feature loss):
 *  - Dropped the a.out exec-header logic (struct xexec / N_BADMAG / N_DATOFF /
 *    the fseek-to-data-segment).  That mode scans only a PDP-11 a.out binary's
 *    data segment; FGX has no a.out format (binaries are FGX1/FGX2/ProDOS BIN),
 *    so it is meaningless here.  This port therefore always scans the ENTIRE
 *    file -- exactly upstream's `-a`/`asdata` path.  `-a` is still accepted
 *    (now a no-op) for command-line compatibility.
 *  - Line terminator: prints '\n'; libc translates LF->CR for the console
 *    (Con_PutChar drops LF), so newlines render.  Redirected output carries CR;
 *    a byte-exact diff against host strings normalizes CR<->LF (an FGX
 *    convention shared by od/cat/wc, not a strings behavior).
 *  - `&buf[n]` written as `buf + n` (fcc has no &array-element operator yet).
 *  - isdigit() hand-rolled (no <ctype.h>); EOF/ferror/feof collapse to getc's
 *    EOF (-1) return.  Octal literals 0177/0200 are the BSD dirt() thresholds.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#ifndef lint
static char sccsid[] = "@(#)strings.c\t5.1.2 (2.11BSD GTE) 2/25/94";
#endif not lint

#include <stdio.h>

/* libc decls not provided by <stdio.h>. */
void exit(int code);

#define STRBUFSZ 1024           /* current-run buffer (BSD BUFSIZ) */

int  oflg;                      /* -o: print byte offset before each string */
int  minlength = 4;             /* -#: minimum run length to print */
char buf[STRBUFSZ];             /* candidate run (file-scope; fcc stack arrays unsafe) */

/* ANSI forward prototypes (tools/ansify.sh via cproto) */
int  main(int argc, char **argv);
void find(void);
int  dirt(int c);
int  isdig(int c);

int
isdig(int c)
{
	return c >= '0' && c <= '9';
}

int
main(int argc, char **argv)
{
	int i;

	argc--;
	argv++;
	while (argc > 0 && argv[0][0] == '-') {
		/* "-" alone (argv[0][1]==0) is upstream "treat as data" -- a no-op
		   on FGX (we always full-scan); the loop simply skips it. */
		for (i = 1; argv[0][i] != 0; i++) {
			int ch = argv[0][i];
			if (ch == 'o') {
				oflg = 1;
				continue;
			}
			if (ch == 'a')
				continue;	/* -a: data-only; n/a on FGX (always full) */
			if (!isdig(ch)) {
				fprintf(stderr,
				    "Usage: strings [ -a ] [ -o ] [ -# ] [ file ... ]\n");
				exit(1);
			}
			minlength = ch - '0';
			for (i++; argv[0][i] != 0 && isdig(argv[0][i]); i++)
				minlength = minlength * 10 + argv[0][i] - '0';
			i--;
		}
		argc--;
		argv++;
	}

	do {
		if (argc > 0) {
			if (freopen(argv[0], "r", stdin) == NULL) {
				perror(argv[0]);
				exit(1);
			}
			argc--;
			argv++;
		}
		find();
	} while (argc > 0);
	return 0;
}

/* Scan stdin to EOF, printing each printable run of length >= minlength. */
void
find(void)
{
	char *cp;
	int   c, cc;

	cp = buf;
	cc = 0;
	for (;;) {
		c = getc(stdin);
		if (c == EOF || c == '\n' || dirt(c)) {
			if (cp > buf && cp[-1] == '\n')
				--cp;
			*cp++ = 0;
			if (cp > buf + minlength) {
				if (oflg)
					printf("%ld ", ftell(stdin) - cc - 1);
				printf("%s\n", buf);
			}
			cp = buf;
			cc = 0;
			if (c == EOF)
				break;
		} else {
			if (cp < buf + (STRBUFSZ - 2))
				*cp++ = c;
			cc++;
		}
	}
}

/* Non-printable test: 1 = "dirt" (ends a run), 0 = part of a run.
   '\n'/'\f' return 0 (handled as separators by the caller); DEL and the
   high/control bytes are dirt.  0177=127 (DEL), 0200=128 (octal).  NB: the
   threshold is `c > 0200`, so 0x80 itself counts as printable and can appear
   inside an emitted run -- a faithful 2.11BSD quirk (modern strings(1) treat
   0x80 as non-printable); 0x81..0xFF are dirt.  Verified byte-identical to a
   clang build of this same source. */
int
dirt(int c)
{
	switch (c) {
	case '\n':
	case '\f':
		return 0;
	case 0177:
		return 1;
	default:
		return c > 0200 || c < ' ';
	}
}
