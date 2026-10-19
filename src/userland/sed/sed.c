/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD sed(1)
 *   Ported from sed(1), 2.11BSD (sed0.c 4.2, sed1.c 4.2, sed.h 4.1; Berkeley).
 *   Copyright (c) 1985 The Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * Near-VERBATIM single-file assembly of sed0.c (compile) + sed1.c (execute) +
 * sed.h (declarations), produced by assemble.sh.  Edits vs upstream:
 *   1. drop sed.h's duplicate reend/lbend/cp tentative definitions (~99-101),
 *      which a single translation unit rejects as redefinitions;
 *   2. gline() ends a line on CR ('\r') as well as LF, so sed reads FGX-native
 *      ProDOS CR-terminated text files (build.sh stages on-disk text as CR;
 *      verbatim gline only saw '\n' -> never found a line -> zero output).
 *      Matches the FGX line-ending convention already in wc/uniq/fold/grep.
 * All sed logic — its own regexp (compile/advance) and command set — is unchanged.
 */
#include <stdio.h>
/* ---- sed.h (inlined; dup reend/lbend/cp dropped) ---- */
/*
 * sed -- stream  editor
 */

#define CBRA	1
#define	CCHR	2
#define	CDOT	4
#define	CCL	6
#define	CNL	8
#define	CDOL	10
#define	CEOF	11
#define CKET	12
#define CNULL	13
#define CLNUM	14
#define CEND	16
#define CDONT	17
#define	CBACK	18

#define	STAR	01

#define NLINES	256
#define	DEPTH	20
#define PTRSIZE	200
#define RESIZE	10000
#define	ABUFSIZE	20
#define	LBSIZE	4000
#define	ESIZE	256
#define	LABSIZE	50
#define NBRA	9

FILE	*fin;
union reptr	*abuf[ABUFSIZE];
union reptr **aptr;
char	*lastre;
char	ibuf[BUFSIZ];
char	*cbp;
char	*ebp;
char	genbuf[LBSIZE];
char	*loc1;
char	*loc2;
char	*locs;
char	seof;
char	*reend;
char	*lbend;
char	*hend;
char	*lcomend;
union reptr	*ptrend;
int	eflag;
int	dolflag;
int	sflag;
int	jflag;
int	numbra;
int	delflag;
long	lnum;
char	linebuf[LBSIZE+1];
char	holdsp[LBSIZE+1];
char	*spend;
char	*hspend;
int	nflag;
int	gflag;
char	*braelist[NBRA];
char	*braslist[NBRA];
long	tlno[NLINES];
int	nlno;
char	fname[12][40];
FILE	*fcode[12];
int	nfiles;

#define ACOM	01
#define BCOM	020
#define CCOM	02
#define	CDCOM	025
#define	CNCOM	022
#define COCOM	017
#define	CPCOM	023
#define DCOM	03
#define ECOM	015
#define EQCOM	013
#define FCOM	016
#define GCOM	027
#define CGCOM	030
#define HCOM	031
#define CHCOM	032
#define ICOM	04
#define LCOM	05
#define NCOM	012
#define PCOM	010
#define QCOM	011
#define RCOM	06
#define SCOM	07
#define TCOM	021
#define WCOM	014
#define	CWCOM	024
#define	YCOM	026
#define XCOM	033

char	*cp;

union	reptr {
	struct reptr1 {
		char	*ad1;
		char	*ad2;
		char	*re1;
		char	*rhs;
		FILE	*fcode;
		char	command;
		char	gfl;
		char	pfl;
		char	inar;
		char	negfl;
	} A;
	struct reptr2 {
		char	*ad1;
		char	*ad2;
		union reptr	*lb1;
		char	*rhs;
		FILE	*fcode;
		char	command;
		char	gfl;
		char	pfl;
		char	inar;
		char	negfl;
	} B;
} ptrspace[PTRSIZE], *rep;


char	respace[RESIZE];

struct label {
	char	asc[9];
	union reptr	*chain;
	union reptr	*address;
} ltab[LABSIZE];

struct label	*lab;
struct label	*labend;

int	f;
int	depth;

int	eargc;
char	**eargv;

extern	char	bittab[];

union reptr	**cmpend[DEPTH];
int	depth;
union reptr	*pending;
char	*badp;
char	bad;
char	*compile();
char	*ycomp();
char	*address();
char	*text();
char	*compsub();
struct label	*search();
char	*gline();
char	*place();
char	compfl;
/* ---- sed0.c (compile/parse) ---- */


struct label	*labtab = ltab;
char	CGMES[]	= "command garbled: %s\n";
char	TMMES[]	= "Too much text: %s\n";
char	LTL[]	= "Label too long: %s\n";
char	AD0MES[]	= "No addresses allowed: %s\n";
char	AD1MES[]	= "Only one address allowed: %s\n";
char	bittab[]  = {
		1,
		2,
		4,
		8,
		16,
		32,
		64,
		128
	};

main(argc, argv)
char	*argv[];
{

	eargc = argc;
	eargv = argv;

	badp = &bad;
	aptr = abuf;
	lab = labtab + 1;	/* 0 reserved for end-pointer */
	rep = ptrspace;
	rep->ad1 = respace;
	lbend = &linebuf[LBSIZE];
	hend = &holdsp[LBSIZE];
	lcomend = &genbuf[71];
	ptrend = &ptrspace[PTRSIZE];
	reend = &respace[RESIZE];
	labend = &labtab[LABSIZE];
	lnum = 0;
	pending = 0;
	depth = 0;
	spend = linebuf;
	hspend = holdsp;
	fcode[0] = stdout;
	nfiles = 1;

	if(eargc == 1)
		exit(0);


	while (--eargc > 0 && (++eargv)[0][0] == '-')
		switch (eargv[0][1]) {

		case 'n':
			nflag++;
			continue;

		case 'f':
			if(eargc-- <= 0)	exit(2);

			if((fin = fopen(*++eargv, "r")) == NULL) {
				fprintf(stderr, "Cannot open pattern-file: %s\n", *eargv);
				exit(2);
			}

			fcomp();
			fclose(fin);
			continue;

		case 'e':
			eflag++;
			fcomp();
			eflag = 0;
			continue;

		case 'g':
			gflag++;
			continue;

		default:
			fprintf(stdout, "Unknown flag: %c\n", eargv[0][1]);
			continue;
		}


	if(compfl == 0) {
		eargv--;
		eargc++;
		eflag++;
		fcomp();
		eargv++;
		eargc--;
		eflag = 0;
	}

	if(depth) {
		fprintf(stderr, "Too many {'s");
		exit(2);
	}

	labtab->address = rep;

	dechain();

/*	abort();	/*DEBUG*/

	if(eargc <= 0)
		execute((char *)NULL);
	else while(--eargc >= 0) {
		execute(*eargv++);
	}
	fclose(stdout);
	exit(0);
}
fcomp()
{

	register char	*p, *op, *tp;
	char	*address();
	union reptr	*pt, *pt1;
	int	i;
	struct label	*lpt;

	compfl = 1;
	op = lastre;

	if(rline(linebuf) < 0)	return;
	if(*linebuf == '#') {
		if(linebuf[1] == 'n')
			nflag = 1;
	}
	else {
		cp = linebuf;
		goto comploop;
	}

	for(;;) {
		if(rline(linebuf) < 0)	break;

		cp = linebuf;

comploop:
/*	fprintf(stdout, "cp: %s\n", cp);	/*DEBUG*/
		while(*cp == ' ' || *cp == '\t')	cp++;
		if(*cp == '\0' || *cp == '#')		continue;
		if(*cp == ';') {
			cp++;
			goto comploop;
		}

		p = address(rep->ad1);
		if(p == badp) {
			fprintf(stderr, CGMES, linebuf);
			exit(2);
		}

		if(p == rep->ad1) {
			if(op)
				rep->ad1 = op;
			else {
				fprintf(stderr, "First RE may not be null\n");
				exit(2);
			}
		} else if(p == 0) {
			p = rep->ad1;
			rep->ad1 = 0;
		} else {
			op = rep->ad1;
			if(*cp == ',' || *cp == ';') {
				cp++;
				if((rep->ad2 = p) > reend) {
					fprintf(stderr, TMMES, linebuf);
					exit(2);
				}
				p = address(rep->ad2);
				if(p == badp || p == 0) {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				if(p == rep->ad2)
					rep->ad2 = op;
				else
					op = rep->ad2;

			} else
				rep->ad2 = 0;
		}

		if(p > reend) {
			fprintf(stderr, "Too much text: %s\n", linebuf);
			exit(2);
		}

		while(*cp == ' ' || *cp == '\t')	cp++;

swit:
		switch(*cp++) {

			default:
				fprintf(stderr, "Unrecognized command: %s\n", linebuf);
				exit(2);

			case '!':
				rep->negfl = 1;
				goto swit;

			case '{':
				rep->command = BCOM;
				rep->negfl = !(rep->negfl);
				cmpend[depth++] = &rep->lb1;
				if(++rep >= ptrend) {
					fprintf(stderr, "Too many commands: %s\n", linebuf);
					exit(2);
				}
				rep->ad1 = p;
				if(*cp == '\0')	continue;

				goto comploop;

			case '}':
				if(rep->ad1) {
					fprintf(stderr, AD0MES, linebuf);
					exit(2);
				}

				if(--depth < 0) {
					fprintf(stderr, "Too many }'s\n");
					exit(2);
				}
				*cmpend[depth] = rep;

				rep->ad1 = p;
				continue;

			case '=':
				rep->command = EQCOM;
				if(rep->ad2) {
					fprintf(stderr, AD1MES, linebuf);
					exit(2);
				}
				break;

			case ':':
				if(rep->ad1) {
					fprintf(stderr, AD0MES, linebuf);
					exit(2);
				}

				while(*cp++ == ' ');
				cp--;


				tp = lab->asc;
				while((*tp++ = *cp++))
					if(tp >= &(lab->asc[8])) {
						fprintf(stderr, LTL, linebuf);
						exit(2);
					}
				*--tp = '\0';

				if(lpt = search(lab)) {
					if(lpt->address) {
						fprintf(stderr, "Duplicate labels: %s\n", linebuf);
						exit(2);
					}
				} else {
					lab->chain = 0;
					lpt = lab;
					if(++lab >= labend) {
						fprintf(stderr, "Too many labels: %s\n", linebuf);
						exit(2);
					}
				}
				lpt->address = rep;
				rep->ad1 = p;

				continue;

			case 'a':
				rep->command = ACOM;
				if(rep->ad2) {
					fprintf(stderr, AD1MES, linebuf);
					exit(2);
				}
				if(*cp == '\\')	cp++;
				if(*cp++ != '\n') {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				rep->re1 = p;
				p = text(rep->re1);
				break;
			case 'c':
				rep->command = CCOM;
				if(*cp == '\\')	cp++;
				if(*cp++ != ('\n')) {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				rep->re1 = p;
				p = text(rep->re1);
				break;
			case 'i':
				rep->command = ICOM;
				if(rep->ad2) {
					fprintf(stderr, AD1MES, linebuf);
					exit(2);
				}
				if(*cp == '\\')	cp++;
				if(*cp++ != ('\n')) {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				rep->re1 = p;
				p = text(rep->re1);
				break;

			case 'g':
				rep->command = GCOM;
				break;

			case 'G':
				rep->command = CGCOM;
				break;

			case 'h':
				rep->command = HCOM;
				break;

			case 'H':
				rep->command = CHCOM;
				break;

			case 't':
				rep->command = TCOM;
				goto jtcommon;

			case 'b':
				rep->command = BCOM;
jtcommon:
				while(*cp++ == ' ');
				cp--;

				if(*cp == '\0') {
					if(pt = labtab->chain) {
						while(pt1 = pt->lb1)
							pt = pt1;
						pt->lb1 = rep;
					} else
						labtab->chain = rep;
					break;
				}
				tp = lab->asc;
				while((*tp++ = *cp++))
					if(tp >= &(lab->asc[8])) {
						fprintf(stderr, LTL, linebuf);
						exit(2);
					}
				cp--;
				*--tp = '\0';

				if(lpt = search(lab)) {
					if(lpt->address) {
						rep->lb1 = lpt->address;
					} else {
						pt = lpt->chain;
						while(pt1 = pt->lb1)
							pt = pt1;
						pt->lb1 = rep;
					}
				} else {
					lab->chain = rep;
					lab->address = 0;
					if(++lab >= labend) {
						fprintf(stderr, "Too many labels: %s\n", linebuf);
						exit(2);
					}
				}
				break;

			case 'n':
				rep->command = NCOM;
				break;

			case 'N':
				rep->command = CNCOM;
				break;

			case 'p':
				rep->command = PCOM;
				break;

			case 'P':
				rep->command = CPCOM;
				break;

			case 'r':
				rep->command = RCOM;
				if(rep->ad2) {
					fprintf(stderr, AD1MES, linebuf);
					exit(2);
				}
				if(*cp++ != ' ') {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				rep->re1 = p;
				p = text(rep->re1);
				break;

			case 'd':
				rep->command = DCOM;
				break;

			case 'D':
				rep->command = CDCOM;
				rep->lb1 = ptrspace;
				break;

			case 'q':
				rep->command = QCOM;
				if(rep->ad2) {
					fprintf(stderr, AD1MES, linebuf);
					exit(2);
				}
				break;

			case 'l':
				rep->command = LCOM;
				break;

			case 's':
				rep->command = SCOM;
				seof = *cp++;
				rep->re1 = p;
				p = compile(rep->re1);
				if(p == badp) {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				if(p == rep->re1) {
					if(op)
					    rep->re1 = op;
					else {
					    fprintf(stderr, 
						"First RE may not be null\n");
					    exit(2);
					}
				} else {
					op = rep->re1;
				}

				if((rep->rhs = p) > reend) {
					fprintf(stderr, TMMES, linebuf);
					exit(2);
				}

				if((p = compsub(rep->rhs)) == badp) {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				if(*cp == 'g') {
					cp++;
					rep->gfl++;
				} else if(gflag)
					rep->gfl++;

				if(*cp == 'p') {
					cp++;
					rep->pfl = 1;
				}

				if(*cp == 'P') {
					cp++;
					rep->pfl = 2;
				}

				if(*cp == 'w') {
					cp++;
					if(*cp++ !=  ' ') {
						fprintf(stderr, CGMES, linebuf);
						exit(2);
					}
					if(nfiles >= 10) {
						fprintf(stderr, "Too many files in w commands\n");
						exit(2);
					}

					text(fname[nfiles]);
					for(i = nfiles - 1; i >= 0; i--)
						if(cmp(fname[nfiles],fname[i]) == 0) {
							rep->fcode = fcode[i];
							goto done;
						}
					if((rep->fcode = fopen(fname[nfiles], "w")) == NULL) {
						fprintf(stderr, "cannot open %s\n", fname[nfiles]);
						exit(2);
					}
					fcode[nfiles++] = rep->fcode;
				}
				break;

			case 'w':
				rep->command = WCOM;
				if(*cp++ != ' ') {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				if(nfiles >= 10){
					fprintf(stderr, "Too many files in w commands\n");
					exit(2);
				}

				text(fname[nfiles]);
				for(i = nfiles - 1; i >= 0; i--)
					if(cmp(fname[nfiles], fname[i]) == 0) {
						rep->fcode = fcode[i];
						goto done;
					}

				if((rep->fcode = fopen(fname[nfiles], "w")) == NULL) {
					fprintf(stderr, "Cannot create %s\n", fname[nfiles]);
					exit(2);
				}
				fcode[nfiles++] = rep->fcode;
				break;

			case 'x':
				rep->command = XCOM;
				break;

			case 'y':
				rep->command = YCOM;
				seof = *cp++;
				rep->re1 = p;
				p = ycomp(rep->re1);
				if(p == badp) {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				if(p > reend) {
					fprintf(stderr, TMMES, linebuf);
					exit(2);
				}
				break;

		}
done:
		if(++rep >= ptrend) {
			fprintf(stderr, "Too many commands, last: %s\n", linebuf);
			exit(2);
		}

		rep->ad1 = p;

		if(*cp++ != '\0') {
			if(cp[-1] == ';')
				goto comploop;
			fprintf(stderr, CGMES, linebuf);
			exit(2);
		}

	}
	rep->command = 0;
	lastre = op;
}
char	*compsub(rhsbuf)
char	*rhsbuf;
{
	register char	*p, *q;

	p = rhsbuf;
	q = cp;
	for(;;) {
		if((*p = *q++) == '\\') {
			*p = *q++;
			if(*p > numbra + '0' && *p <= '9')
				return(badp);
			*p++ |= 0200;
			continue;
		}
		if(*p == seof) {
			*p++ = '\0';
			cp = q;
			return(p);
		}
		if(*p++ == '\0') {
			return(badp);
		}

	}
}

char *compile(expbuf)
char	*expbuf;
{
	register c;
	register char *ep, *sp;
	char	neg;
	char *lastep, *cstart;
	int cclcnt;
	int	closed;
	char	bracket[NBRA], *bracketp;

	if(*cp == seof) {
		cp++;
		return(expbuf);
	}

	ep = expbuf;
	lastep = 0;
	bracketp = bracket;
	closed = numbra = 0;
	sp = cp;
	if (*sp == '^') {
		*ep++ = 1;
		sp++;
	} else {
		*ep++ = 0;
	}
	for (;;) {
		if (ep >= &expbuf[ESIZE]) {
			cp = sp;
			return(badp);
		}
		if((c = *sp++) == seof) {
			if(bracketp != bracket) {
				cp = sp;
				return(badp);
			}
			cp = sp;
			*ep++ = CEOF;
			return(ep);
		}
		if(c != '*')
			lastep = ep;
		switch (c) {

		case '\\':
			if((c = *sp++) == '(') {
				if(numbra >= NBRA) {
					cp = sp;
					return(badp);
				}
				*bracketp++ = numbra;
				*ep++ = CBRA;
				*ep++ = numbra++;
				continue;
			}
			if(c == ')') {
				if(bracketp <= bracket) {
					cp = sp;
					return(badp);
				}
				*ep++ = CKET;
				*ep++ = *--bracketp;
				closed++;
				continue;
			}

			if(c >= '1' && c <= '9') {
				if((c -= '1') >= closed)
					return(badp);
	
				*ep++ = CBACK;
				*ep++ = c;
				continue;
			}
			if(c == '\n') {
				cp = sp;
				return(badp);
			}
			if(c == 'n') {
				c = '\n';
			}
			goto defchar;

		case '\0':
			continue;
		case '\n':
			cp = sp;
			return(badp);

		case '.':
			*ep++ = CDOT;
			continue;

		case '*':
			if (lastep == 0)
				goto defchar;
			if(*lastep == CKET) {
				cp = sp;
				return(badp);
			}
			*lastep |= STAR;
			continue;

		case '$':
			if (*sp != seof)
				goto defchar;
			*ep++ = CDOL;
			continue;

		case '[':
			if(&ep[17] >= &expbuf[ESIZE]) {
				fprintf(stderr, "RE too long: %s\n", linebuf);
				exit(2);
			}

			*ep++ = CCL;

			neg = 0;
			if((c = *sp++) == '^') {
				neg = 1;
				c = *sp++;
			}

			cstart = sp;
			do {
				if(c == '\0') {
					fprintf(stderr, CGMES, linebuf);
					exit(2);
				}
				if (c=='-' && sp>cstart && *sp!=']') {
					for (c = sp[-2]; c<*sp; c++)
						ep[c>>3] |= bittab[c&07];
				}
				if(c == '\\') {
					switch(c = *sp++) {
						case 'n':
							c = '\n';
							break;
					}
				}

				ep[c >> 3] |= bittab[c & 07];
			} while((c = *sp++) != ']');

			if(neg)
				for(cclcnt = 0; cclcnt < 16; cclcnt++)
					ep[cclcnt] ^= -1;
			ep[0] &= 0376;

			ep += 16;

			continue;

		defchar:
		default:
			*ep++ = CCHR;
			*ep++ = c;
		}
	}
}
rline(lbuf)
char	*lbuf;
{
	register char	*p, *q;
	register	t;
	static char	*saveq;

	p = lbuf - 1;

	if(eflag) {
		if(eflag > 0) {
			eflag = -1;
			if(eargc-- <= 0)
				exit(2);
			q = *++eargv;
			while(*++p = *q++) {
				if(*p == '\\') {
					if((*++p = *q++) == '\0') {
						saveq = 0;
						return(-1);
					} else
						continue;
				}
				if(*p == '\n') {
					*p = '\0';
					saveq = q;
					return(1);
				}
			}
			saveq = 0;
			return(1);
		}
		if((q = saveq) == 0)	return(-1);

		while(*++p = *q++) {
			if(*p == '\\') {
				if((*++p = *q++) == '0') {
					saveq = 0;
					return(-1);
				} else
					continue;
			}
			if(*p == '\n') {
				*p = '\0';
				saveq = q;
				return(1);
			}
		}
		saveq = 0;
		return(1);
	}

	while((t = getc(fin)) != EOF) {
		*++p = t;
		if(*p == '\\') {
			t = getc(fin);
			*++p = t;
		}
		else if(*p == '\n') {
			*p = '\0';
			return(1);
		}
	}
	*++p = '\0';
	return(-1);
}

char	*address(expbuf)
char	*expbuf;
{
	register char	*rcp;
	long	lno;

	if(*cp == '$') {
		cp++;
		*expbuf++ = CEND;
		*expbuf++ = CEOF;
		return(expbuf);
	}

	if(*cp == '/') {
		seof = '/';
		cp++;
		return(compile(expbuf));
	}

	rcp = cp;
	lno = 0;

	while(*rcp >= '0' && *rcp <= '9')
		lno = lno*10 + *rcp++ - '0';

	if(rcp > cp) {
		*expbuf++ = CLNUM;
		*expbuf++ = nlno;
		tlno[nlno++] = lno;
		if(nlno >= NLINES) {
			fprintf(stderr, "Too many line numbers\n");
			exit(2);
		}
		*expbuf++ = CEOF;
		cp = rcp;
		return(expbuf);
	}
	return(0);
}
cmp(a, b)
char	*a,*b;
{
	register char	*ra, *rb;

	ra = a - 1;
	rb = b - 1;

	while(*++ra == *++rb)
		if(*ra == '\0')	return(0);
	return(1);
}

char	*text(textbuf)
char	*textbuf;
{
	register char	*p, *q;

	p = textbuf;
	q = cp;
	while(*q == '\t' || *q == ' ')	q++;
	for(;;) {

		if((*p = *q++) == '\\')
			*p = *q++;
		if(*p == '\0') {
			cp = --q;
			return(++p);
		}
		if(*p == '\n') {
			while(*q == '\t' || *q == ' ')	q++;
		}
		p++;
	}
}


struct label	*search(ptr)
struct label	*ptr;
{
	struct label	*rp;

	rp = labtab;
	while(rp < ptr) {
		if(cmp(rp->asc, ptr->asc) == 0)
			return(rp);
		rp++;
	}

	return(0);
}


dechain()
{
	struct label	*lptr;
	union reptr	*rptr, *trptr;

	for(lptr = labtab; lptr < lab; lptr++) {

		if(lptr->address == 0) {
			fprintf(stderr, "Undefined label: %s\n", lptr->asc);
			exit(2);
		}

		if(lptr->chain) {
			rptr = lptr->chain;
			while(trptr = rptr->lb1) {
				rptr->lb1 = lptr->address;
				rptr = trptr;
			}
			rptr->lb1 = lptr->address;
		}
	}
}

char *ycomp(expbuf)
char	*expbuf;
{
	register char	c, *ep, *tsp;
	char	*sp;

	ep = expbuf;
	sp = cp;
	for(tsp = cp; *tsp != seof; tsp++) {
		if(*tsp == '\\')
			tsp++;
		if(*tsp == '\n')
			return(badp);
	}
	tsp++;

	while((c = *sp++ & 0177) != seof) {
		if(c == '\\' && *sp == 'n') {
			sp++;
			c = '\n';
		}
		if((ep[c] = *tsp++) == '\\' && *tsp == 'n') {
			ep[c] = '\n';
			tsp++;
		}
		if(ep[c] == seof || ep[c] == '\0')
			return(badp);
	}
	if(*tsp != seof)
		return(badp);
	cp = ++tsp;

	for(c = 0; !(c & 0200); c++)
		if(ep[c] == 0)
			ep[c] = c;

	return(ep + 0200);
}
/* ---- sed1.c (execute) ---- */


char	*trans[040]  = {
	"\\01",
	"\\02",
	"\\03",
	"\\04",
	"\\05",
	"\\06",
	"\\07",
	"<-",
	">-",
	"\n",
	"\\13",
	"\\14",
	"\\15",
	"\\16",
	"\\17",
	"\\20",
	"\\21",
	"\\22",
	"\\23",
	"\\24",
	"\\25",
	"\\26",
	"\\27",
	"\\30",
	"\\31",
	"\\32",
	"\\33",
	"\\34",
	"\\35",
	"\\36",
	"\\37"
};
char	rub[] = {"\177"};

execute(file)
char *file;
{
	register char *p1, *p2;
	register union reptr	*ipc;
	int	c;
	char	*execp;

	if (file) {
		if ((f = open(file, 0)) < 0) {
			fprintf(stderr, "Can't open %s\n", file);
		}
	} else
		f = 0;

	ebp = ibuf;
	cbp = ibuf;

	if(pending) {
		ipc = pending;
		pending = 0;
		goto yes;
	}

	for(;;) {
		if((execp = gline(linebuf)) == badp) {
			close(f);
			return;
		}
		spend = execp;

		for(ipc = ptrspace; ipc->command; ) {

			p1 = ipc->ad1;
			p2 = ipc->ad2;

			if(p1) {

				if(ipc->inar) {
					if(*p2 == CEND) {
						p1 = 0;
					} else if(*p2 == CLNUM) {
						c = p2[1];
						if(lnum > tlno[c]) {
							ipc->inar = 0;
							if(ipc->negfl)
								goto yes;
							ipc++;
							continue;
						}
						if(lnum == tlno[c]) {
							ipc->inar = 0;
						}
					} else if(match(p2, 0)) {
						ipc->inar = 0;
					}
				} else if(*p1 == CEND) {
					if(!dolflag) {
						if(ipc->negfl)
							goto yes;
						ipc++;
						continue;
					}

				} else if(*p1 == CLNUM) {
					c = p1[1];
					if(lnum != tlno[c]) {
						if(ipc->negfl)
							goto yes;
						ipc++;
						continue;
					}
					if(p2)
						ipc->inar = 1;
				} else if(match(p1, 0)) {
					if(p2)
						ipc->inar = 1;
				} else {
					if(ipc->negfl)
						goto yes;
					ipc++;
					continue;
				}
			}

			if(ipc->negfl) {
				ipc++;
				continue;
			}
	yes:
			command(ipc);

			if(delflag)
				break;

			if(jflag) {
				jflag = 0;
				if((ipc = ipc->lb1) == 0) {
					ipc = ptrspace;
					break;
				}
			} else
				ipc++;

		}
		if(!nflag && !delflag) {
			for(p1 = linebuf; p1 < spend; p1++)
				putc(*p1, stdout);
			putc('\n', stdout);
		}

		if(aptr > abuf) {
			arout();
		}

		delflag = 0;

	}
}
match(expbuf, gf)
char	*expbuf;
{
	register char	*p1, *p2, c;

	if(gf) {
		if(*expbuf)	return(0);
		p1 = linebuf;
		p2 = genbuf;
		while(*p1++ = *p2++);
		locs = p1 = loc2;
	} else {
		p1 = linebuf;
		locs = 0;
	}

	p2 = expbuf;
	if(*p2++) {
		loc1 = p1;
		if(*p2 == CCHR && p2[1] != *p1)
			return(0);
		return(advance(p1, p2));
	}

	/* fast check for first character */

	if(*p2 == CCHR) {
		c = p2[1];
		do {
			if(*p1 != c)
				continue;
			if(advance(p1, p2)) {
				loc1 = p1;
				return(1);
			}
		} while(*p1++);
		return(0);
	}

	do {
		if(advance(p1, p2)) {
			loc1 = p1;
			return(1);
		}
	} while(*p1++);
	return(0);
}
advance(alp, aep)
char	*alp, *aep;
{
	register char *lp, *ep, *curlp;
	char	c;
	char *bbeg;
	int	ct;

/*fprintf(stderr, "*lp = %c, %o\n*ep = %c, %o\n", *lp, *lp, *ep, *ep);	/*DEBUG*/

	lp = alp;
	ep = aep;
	for (;;) switch (*ep++) {

	case CCHR:
		if (*ep++ == *lp++)
			continue;
		return(0);

	case CDOT:
		if (*lp++)
			continue;
		return(0);

	case CNL:
	case CDOL:
		if (*lp == 0)
			continue;
		return(0);

	case CEOF:
		loc2 = lp;
		return(1);

	case CCL:
		c = *lp++ & 0177;
		if(ep[c>>3] & bittab[c & 07]) {
			ep += 16;
			continue;
		}
		return(0);

	case CBRA:
		braslist[*ep++] = lp;
		continue;

	case CKET:
		braelist[*ep++] = lp;
		continue;

	case CBACK:
		bbeg = braslist[*ep];
		ct = braelist[*ep++] - bbeg;

		if(ecmp(bbeg, lp, ct)) {
			lp += ct;
			continue;
		}
		return(0);

	case CBACK|STAR:
		bbeg = braslist[*ep];
		ct = braelist[*ep++] - bbeg;
		curlp = lp;
		while(ecmp(bbeg, lp, ct))
			lp += ct;

		while(lp >= curlp) {
			if(advance(lp, ep))	return(1);
			lp -= ct;
		}
		return(0);


	case CDOT|STAR:
		curlp = lp;
		while (*lp++);
		goto star;

	case CCHR|STAR:
		curlp = lp;
		while (*lp++ == *ep);
		ep++;
		goto star;

	case CCL|STAR:
		curlp = lp;
		do {
			c = *lp++ & 0177;
		} while(ep[c>>3] & bittab[c & 07]);
		ep += 16;
		goto star;

	star:
		if(--lp == curlp) {
			continue;
		}

		if(*ep == CCHR) {
			c = ep[1];
			do {
				if(*lp != c)
					continue;
				if(advance(lp, ep))
					return(1);
			} while(lp-- > curlp);
			return(0);
		}

		if(*ep == CBACK) {
			c = *(braslist[ep[1]]);
			do {
				if(*lp != c)
					continue;
				if(advance(lp, ep))
					return(1);
			} while(lp-- > curlp);
			return(0);
		}

		do {
			if(lp == locs)	break;
			if (advance(lp, ep))
				return(1);
		} while (lp-- > curlp);
		return(0);

	default:
		fprintf(stderr, "RE botch, %o\n", *--ep);
	}
}
substitute(ipc)
union reptr	*ipc;
{
	if(match(ipc->re1, 0) == 0)	return(0);

	sflag = 1;
	dosub(ipc->rhs);

	if(ipc->gfl) {
		while(*loc2) {
			if(match(ipc->re1, 1) == 0) break;
			dosub(ipc->rhs);
		}
	}
	return(1);
}

dosub(rhsbuf)
char	*rhsbuf;
{
	register char *lp, *sp, *rp;
	int c;

	lp = linebuf;
	sp = genbuf;
	rp = rhsbuf;
	while (lp < loc1)
		*sp++ = *lp++;
	while(c = *rp++) {
		if (c == '&') {
			sp = place(sp, loc1, loc2);
			continue;
		} else if (c&0200 && (c &= 0177) >= '1' && c < NBRA+'1') {
			sp = place(sp, braslist[c-'1'], braelist[c-'1']);
			continue;
		}
		*sp++ = c&0177;
		if (sp >= &genbuf[LBSIZE])
			fprintf(stderr, "output line too long.\n");
	}
	lp = loc2;
	loc2 = sp - genbuf + linebuf;
	while (*sp++ = *lp++)
		if (sp >= &genbuf[LBSIZE]) {
			fprintf(stderr, "Output line too long.\n");
		}
	lp = linebuf;
	sp = genbuf;
	while (*lp++ = *sp++);
	spend = lp-1;
}
char	*place(asp, al1, al2)
char	*asp, *al1, *al2;
{
	register char *sp, *l1, *l2;

	sp = asp;
	l1 = al1;
	l2 = al2;
	while (l1 < l2) {
		*sp++ = *l1++;
		if (sp >= &genbuf[LBSIZE])
			fprintf(stderr, "Output line too long.\n");
	}
	return(sp);
}

command(ipc)
union reptr	*ipc;
{
	register int	i;
	register char	*p1, *p2, *p3;
	char	*execp;


	switch(ipc->command) {

		case ACOM:
			*aptr++ = ipc;
			if(aptr >= &abuf[ABUFSIZE]) {
				fprintf(stderr, "Too many appends after line %ld\n",
					lnum);
			}
			*aptr = 0;
			break;

		case CCOM:
			delflag = 1;
			if(!ipc->inar || dolflag) {
				for(p1 = ipc->re1; *p1; )
					putc(*p1++, stdout);
				putc('\n', stdout);
			}
			break;
		case DCOM:
			delflag++;
			break;
		case CDCOM:
			p1 = p2 = linebuf;

			while(*p1 != '\n') {
				if(*p1++ == 0) {
					delflag++;
					return;
				}
			}

			p1++;
			while(*p2++ = *p1++);
			spend = p2-1;
			jflag++;
			break;

		case EQCOM:
			fprintf(stdout, "%ld\n", lnum);
			break;

		case GCOM:
			p1 = linebuf;
			p2 = holdsp;
			while(*p1++ = *p2++);
			spend = p1-1;
			break;

		case CGCOM:
			*spend++ = '\n';
			p1 = spend;
			p2 = holdsp;
			while(*p1++ = *p2++)
				if(p1 >= lbend)
					break;
			spend = p1-1;
			break;

		case HCOM:
			p1 = holdsp;
			p2 = linebuf;
			while(*p1++ = *p2++);
			hspend = p1-1;
			break;

		case CHCOM:
			*hspend++ = '\n';
			p1 = hspend;
			p2 = linebuf;
			while(*p1++ = *p2++)
				if(p1 >= hend)
					break;
			hspend = p1-1;
			break;

		case ICOM:
			for(p1 = ipc->re1; *p1; )
				putc(*p1++, stdout);
			putc('\n', stdout);
			break;

		case BCOM:
			jflag = 1;
			break;

		case LCOM:
			p1 = linebuf;
			p2 = genbuf;
			genbuf[72] = 0;
			while(*p1)
				if(*p1 >= 040) {
					if(*p1 == 0177) {
						p3 = rub;
						while(*p2++ = *p3++)
							if(p2 >= lcomend) {
								*p2 = '\\';
								fprintf(stdout, "%s\n", genbuf);
								p2 = genbuf;
							}
						p2--;
						p1++;
						continue;
					}
					*p2++ = *p1++;
					if(p2 >= lcomend) {
						*p2 = '\\';
						fprintf(stdout, "%s\n", genbuf);
						p2 = genbuf;
					}
				} else {
					p3 = trans[*p1-1];
					while(*p2++ = *p3++)
						if(p2 >= lcomend) {
							*p2 = '\\';
							fprintf(stdout, "%s\n", genbuf);
							p2 = genbuf;
						}
					p2--;
					p1++;
				}
			*p2 = 0;
			fprintf(stdout, "%s\n", genbuf);
			break;

		case NCOM:
			if(!nflag) {
				for(p1 = linebuf; p1 < spend; p1++)
					putc(*p1, stdout);
				putc('\n', stdout);
			}

			if(aptr > abuf)
				arout();
			if((execp = gline(linebuf)) == badp) {
				pending = ipc;
				delflag = 1;
				break;
			}
			spend = execp;

			break;
		case CNCOM:
			if(aptr > abuf)
				arout();
			*spend++ = '\n';
			if((execp = gline(spend)) == badp) {
				pending = ipc;
				delflag = 1;
				break;
			}
			spend = execp;
			break;

		case PCOM:
			for(p1 = linebuf; p1 < spend; p1++)
				putc(*p1, stdout);
			putc('\n', stdout);
			break;
		case CPCOM:
	cpcom:
			for(p1 = linebuf; *p1 != '\n' && *p1 != '\0'; )
				putc(*p1++, stdout);
			putc('\n', stdout);
			break;

		case QCOM:
			if(!nflag) {
				for(p1 = linebuf; p1 < spend; p1++)
					putc(*p1, stdout);
				putc('\n', stdout);
			}
			if(aptr > abuf)	arout();
			fclose(stdout);
			exit(0);
		case RCOM:

			*aptr++ = ipc;
			if(aptr >= &abuf[ABUFSIZE])
				fprintf(stderr, "Too many reads after line%ld\n",
					lnum);

			*aptr = 0;

			break;

		case SCOM:
			i = substitute(ipc);
			if(ipc->pfl && i)
				if(ipc->pfl == 1) {
					for(p1 = linebuf; p1 < spend; p1++)
						putc(*p1, stdout);
					putc('\n', stdout);
				}
				else
					goto cpcom;
			if(i && ipc->fcode)
				goto wcom;
			break;

		case TCOM:
			if(sflag == 0)	break;
			sflag = 0;
			jflag = 1;
			break;

		wcom:
		case WCOM:
			fprintf(ipc->fcode, "%s\n", linebuf);
			fflush(ipc->fcode);
			break;
		case XCOM:
			p1 = linebuf;
			p2 = genbuf;
			while(*p2++ = *p1++);
			p1 = holdsp;
			p2 = linebuf;
			while(*p2++ = *p1++);
			spend = p2 - 1;
			p1 = genbuf;
			p2 = holdsp;
			while(*p2++ = *p1++);
			hspend = p2 - 1;
			break;

		case YCOM:
			p1 = linebuf;
			p2 = ipc->re1;
			while(*p1 = p2[*p1])	p1++;
			break;
	}

}

char	*
gline(addr)
char	*addr;
{
	register char	*p1, *p2;
	register	c;
	p1 = addr;
	p2 = cbp;
	for (;;) {
		if (p2 >= ebp) {
			if ((c = read(f, ibuf, BUFSIZ)) <= 0) {
				return(badp);
			}
			p2 = ibuf;
			ebp = ibuf+c;
		}
		if ((c = *p2++) == '\n' || c == '\r') {
			if(p2 >=  ebp) {
				if((c = read(f, ibuf, BUFSIZ)) <= 0) {
					close(f);
					if(eargc == 0)
							dolflag = 1;
				}

				p2 = ibuf;
				ebp = ibuf + c;
			}
			break;
		}
		if(c)
		if(p1 < lbend)
			*p1++ = c;
	}
	lnum++;
	*p1 = 0;
	cbp = p2;

	return(p1);
}
ecmp(a, b, count)
char	*a, *b;
{
	while(count--)
		if(*a++ != *b++)	return(0);
	return(1);
}

arout()
{
	register char	*p1;
	FILE	*fi;
	char	c;
	int	t;

	aptr = abuf - 1;
	while(*++aptr) {
		if((*aptr)->command == ACOM) {
			for(p1 = (*aptr)->re1; *p1; )
				putc(*p1++, stdout);
			putc('\n', stdout);
		} else {
			if((fi = fopen((*aptr)->re1, "r")) == NULL)
				continue;
			while((t = getc(fi)) != EOF) {
				c = t;
				putc(c, stdout);
			}
			fclose(fi);
		}
	}
	aptr = abuf;
	*aptr = 0;
}

