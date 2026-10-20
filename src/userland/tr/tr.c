/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD tr(1)
 *   Ported from tr(1), 2.11BSD (4.2, Berkeley, 4/22/85).  Original work:
 *   Copyright (c) 1985 The Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * tr - transliterate / delete / squeeze characters.  Near-verbatim port of
 * 2.11BSD tr(1): -c complement, -d delete, -s squeeze; a-z ranges; \nnn octal
 * escapes.  The libc functions it uses (putchar / clearerr / ferror) are
 * implemented in libc (toolchain/lib/libc.s), not worked around; chained
 * assignment (`a.f = b.f = 0`) is supported by fcc (parse_assign).  The ONE
 * source adaptation is the argv option scan: fcc has no `*argv[0]` /
 * `argv[0][1]` / `*++argv[0]`, so the scan walks a local `char *p = argv[0]`
 * (behavior-identical — the upstream in-place argv[0] mutation is discarded by
 * the following argv++).  Same approach as ul(1)'s option scan.
 *
 * Note: the upstream `*--s->p = 0` writes through the `""` sentinel (pre-ANSI
 * writable-literal assumption).  Harmless on FGX (no memory protection; the
 * write lands on a RAM byte that is already 0).  On hosts with read-only
 * literals, build the reference with `clang -fwritable-strings` to validate.
 */
#include <stdio.h>

/* tr - transliterate data stream */
int	dflag	= 0;
int	sflag	= 0;
int	cflag = 0;
int	save	= 0;
char	code[256];
char	squeez[256];
char	vect[256];
struct string { int last, max; char *p; } string1, string2;

main(argc,argv)
char **argv;
{
	register i;
	int j;
	register c, d;
	char *compl;
	char *p;		/* FGX: option-scan cursor (fcc-friendly argv walk) */
	int lastd;

	string1.last = string2.last = 0;
	string1.max = string2.max = 0;
	string1.p = string2.p = "";

	if(--argc>0) {
		argv++;
		p = argv[0];	/* FGX: scan via local char* (fcc: no *argv[0]/argv[0][1]/*++argv[0]) */
		if(*p=='-'&&p[1]!=0) {
			while(*++p)
				switch(*p) {
				case 'c':
					cflag++;
					continue;
				case 'd':
					dflag++;
					continue;
				case 's':
					sflag++;
					continue;
				}
			argc--;
			argv++;
		}
	}
	if(argc>0) string1.p = argv[0];
	if(argc>1) string2.p = argv[1];
	for(i=0; i<256; i++)
		code[i] = vect[i] = 0;
	if(cflag) {
		while(c = next(&string1))
			vect[c&0377] = 1;
		j = 0;
		for(i=1; i<256; i++)
			if(vect[i]==0) vect[j++] = i;
		vect[j] = 0;
		compl = vect;
	}
	for(i=0; i<256; i++)
		squeez[i] = 0;
	lastd = 0;
	for(;;){
		if(cflag) c = *compl++;
		else c = next(&string1);
		if(c==0) break;
		d = next(&string2);
		if(d==0) d = lastd;
		else lastd = d;
		squeez[d&0377] = 1;
		code[c&0377] = dflag?1:d;
	}
	while(d = next(&string2))
		squeez[d&0377] = 1;
	squeez[0] = 1;
	for(i=0;i<256;i++) {
		if(code[i]==0) code[i] = i;
		else if(dflag) code[i] = 0;
	}

	clearerr(stdout);
	while((c=getc(stdin)) != EOF ) {
		if(c == 0) continue;
		if(c = code[c&0377]&0377)
			if(!sflag || c!=save || !squeez[c&0377]) {
				putchar(save = c);
				if(ferror(stdout))
					exit(1);
			}
	}
	exit(0);
}

next(s)
struct string *s;
{

again:
	if(s->max) {
		if(s->last++ < s->max)
			return(s->last);
		s->max = s->last = 0;
	}
	if(s->last && *s->p=='-') {
		nextc(s);
		s->max = nextc(s);
		if(s->max==0) {
			s->p--;
			return('-');
		}
		if(s->max < s->last)  {
			s->last = s->max-1;
			return('-');
		}
		goto again;
	}
	return(s->last = nextc(s));
}

nextc(s)
struct string *s;
{
	register c, i, n;

	c = *s->p++;
	if(c=='\\') {
		i = n = 0;
		while(i<3 && (c = *s->p)>='0' && c<='7') {
			n = n*8 + c - '0';
			i++;
			s->p++;
		}
		if(i>0) c = n;
		else c = *s->p++;
	}
	if(c==0) *--s->p = 0;
	return(c&0377);
}
