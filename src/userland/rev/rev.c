/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD rev(1)
 *   Ported from rev(1), 2.11BSD (4.1, Berkeley, 10/1/80).  Original work:
 *   the Regents of the University of California; the 2.11BSD file
 *   carries no copyright notice.
 *   FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * vendor/2.11BSD/usr/usr.bin/rev.c, verbatim below this comment.
 */
static char *sccsid = "@(#)rev.c	4.1 (Berkeley) 10/1/80";
#include <stdio.h>

/* reverse lines of a file */

#define N 256
char line[N];
FILE *input;

main(argc,argv)
char **argv;
{
	register i,c;
	input = stdin;
	do {
		if(argc>1) {
			if((input=fopen(argv[1],"r"))==NULL) {
				fprintf(stderr,"rev: cannot open %s\n",
					argv[1]);
				exit(1);
			}
		}
		for(;;){
			for(i=0;i<N;i++) {
				line[i] = c = getc(input);
				switch(c) {
				case EOF:
					goto eof;
				default:
					continue;
				case '\n':
					break;
				}
				break;
			}
			while(--i>=0)
				putc(line[i],stdout);
			putc('\n',stdout);
		}
eof:
		fclose(input);
		argc--;
		argv++;
	} while(argc>1);
}
