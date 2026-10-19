/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD ul(1)
 *   Ported from ul(1), 2.11BSD (ul.c 5.1, Berkeley, 5/31/85).  Original work:
 *   Copyright (c) 1980 Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * ul -- underline/bold via overstrike.  Maps nroff teletype overstrike
 * (X\bX bold, _\bX underline) to the SHR console's termcap us/ue/md/me
 * (SGR ESC[4m / [24m / [1m / [0m).  FGX/fcc adaptations (no feature loss):
 *  - tputs is defined here: it parses the termcap padding spec but applies
 *    no delay (moot on a memory-mapped console); vi's slice 4.2 factors it
 *    into a termlib.
 *  - putch/getc/fflush: putch wraps fputc(stdout); getc -> fgetc;
 *    fflush is a no-op (fcc stdio is unbuffered -- fputc writes immediately).
 *  - bzero(obuf,n) -> memset(obuf,0,n) (equivalent); filter() ANSI-fied.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#ifndef lint
char copyright[] =
"@(#) Copyright (c) 1980 Regents of the University of California.\n\
 All rights reserved.\n";
#endif not lint

#ifndef lint
static char sccsid[] = "@(#)ul.c	5.1 (Berkeley) 5/31/85";
#endif not lint

#include <stdio.h>

/* libc functions not declared by <stdio.h> -- fcc requires a declaration even
 * for bound calls.  strcpy/strcmp/memset/exit are standard; tgetent/tgetstr/
 * tgetflag are the C-callable termcap bridge (fcc_libc_shims.s). */
void  exit(int code);
char *getenv(char *name);
char *strcpy(char *d, char *s);
int   strcmp(char *a, char *b);
char *memset(char *s, int c, int n);
int   tgetent(char *bp, char *name);
char *tgetstr(char *id, char **area);
int   tgetflag(char *id);

/* ANSI forward prototypes (tools/ansify.sh via cproto) */
int main(int argc, char **argv);
int filter(FILE *f);
int putch(int c);
int fflush(FILE *f);
int isatty(int fd);
int flushln(void);
int overstrike(void);
int iattr(void);
int initbuf(void);
int fwd(void);
int reverse(void);
int initcap(void);
int outchar(int c);
int puts(char *str);
int outc(int c);
int setmode(int newmode);

#define	IESC	'\033'
#define	SO	'\016'
#define	SI	'\017'
#define	HFWD	'9'
#define	HREV	'8'
#define	FREV	'7'
#define	MAXBUF	512

#define	NORMAL	000
#define	ALTSET	001	/* Reverse */
#define	SUPERSC	002	/* Dim */
#define	SUBSC	004	/* Dim | Ul */
#define	UNDERL	010	/* Ul */
#define	BOLD	020	/* Bold */

int	must_use_uc, must_overstrike;
char	*CURS_UP, *CURS_RIGHT, *CURS_LEFT,
	*ENTER_STANDOUT, *EXIT_STANDOUT, *ENTER_UNDERLINE, *EXIT_UNDERLINE,
	*ENTER_DIM, *ENTER_BOLD, *ENTER_REVERSE, *UNDER_CHAR, *EXIT_ATTRIBUTES;

struct	CHAR	{
	char	c_mode;
	char	c_char;
} ;

struct	CHAR	obuf[MAXBUF];
int	col, maxcol;
int	mode;
int	halfpos;
int	upln;
int	iflag;

int 
main (int argc, char **argv)
{
	char *cp, *termtype;
	FILE *f;
	/* Upstream uses termcap[1024] to receive tgetent's entry, but FGX's
	 * baked tgetent ignores the buffer (caps come from the libc table via
	 * tgetstr), so a token size suffices.  It must stay small for another
	 * reason: fcc's function PROLOGUE param-spill emits a bare `STA
	 * 7+FRAMESIZE,S`, and the 65816 stack-relative offset is 8-bit -- a
	 * frame > ~248B (which termcap[1024] caused) overflows it.  fcc gap:
	 * guard the prologue spill like the body accesses (matters for vi). */
	char termcap[32];
	int i;

	termtype = getenv("TERM");
	if (termtype == NULL || (argv[0][0] == 'c' && !isatty(1)))
		termtype = "lpr";

	/* Option scan.  FGX-original, replacing 2.11BSD ul's bundled getopt.c
	 * (a K&R thicket fcc couldn't parse -- the recipe's "hand-rolled arg
	 * scan" idiom).  Faithful to ul's CLI: -i, -tTERM / -t TERM (the -T
	 * alias for nroff compat), and -- to end options.  `i` ends at the
	 * first file operand (was getopt's optind). */
	for (i = 1; i < argc; i++) {
		cp = argv[i];
		if (cp[0] != '-' || cp[1] == '\0')
			break;				/* first file operand */
		if (cp[1] == '-' && cp[2] == '\0') {	/* "--" ends options */
			i++;
			break;
		}
		if (cp[1] == 'i' && cp[2] == '\0') {
			iflag = 1;
			continue;
		}
		if (cp[1] == 't' || cp[1] == 'T') {
			if (cp[2] != '\0')
				termtype = &cp[2];	/* -tTERM (attached) */
			else if (i + 1 < argc)
				termtype = argv[++i];	/* -t TERM (separate) */
			continue;
		}
		fprintf(stderr, "Usage: %s [ -i ] [ -tTerm ] file...\n",
			argv[0]);
		exit(1);
	}

	switch(tgetent(termcap, termtype)) {

	case 1:
		break;

	default:
		fprintf(stderr,"trouble reading termcap");
		/* fall through to ... */

	case 0:
		/* No such terminal type - assume dumb */
		strcpy(termcap, "dumb:os:col#80:cr=^M:sf=^J:am:");
		break;
	}
	initcap();
	if (    (tgetflag("os") && ENTER_BOLD==NULL ) ||
		(tgetflag("ul") && ENTER_UNDERLINE==NULL && UNDER_CHAR==NULL))
			must_overstrike = 1;
	initbuf();
	if (i == argc)
		filter(stdin);
	else for (; i<argc; i++) {
		f = fopen(argv[i],"r");
		if (f == NULL) {
			perror(argv[i]);
			exit(1);
		} else
			filter(f);
	}
	exit(0);
}

int filter(FILE *f)
{
	int c;

	while((c = fgetc(f)) != EOF) switch(c) {

	case '\b':
		if (col > 0)
			col--;
		continue;

	case '\t':
		col = (col+8) & ~07;
		if (col > maxcol)
			maxcol = col;
		continue;

	case '\r':
		col = 0;
		continue;

	case SO:
		mode |= ALTSET;
		continue;

	case SI:
		mode &= ~ALTSET;
		continue;

	case IESC:
		switch (c = fgetc(f)) {

		case HREV:
			if (halfpos == 0) {
				mode |= SUPERSC;
				halfpos--;
			} else if (halfpos > 0) {
				mode &= ~SUBSC;
				halfpos--;
			} else {
				halfpos = 0;
				reverse();
			}
			continue;

		case HFWD:
			if (halfpos == 0) {
				mode |= SUBSC;
				halfpos++;
			} else if (halfpos < 0) {
				mode &= ~SUPERSC;
				halfpos++;
			} else {
				halfpos = 0;
				fwd();
			}
			continue;

		case FREV:
			reverse();
			continue;

		default:
			fprintf(stderr,
				"Unknown escape sequence in input: %o, %o\n",
				IESC, c);
			exit(1);
		}
		continue;

	case '_':
		if (obuf[col].c_char)
			/* fcc gap: no compound-assign to a struct-array-element
			 * field (arr[i].field op= v) -- the lvalue parses but only
			 * plain '=' is accepted.  Written out (identical effect)
			 * here and at the two sites below; fix fcc for vi. */
			obuf[col].c_mode = obuf[col].c_mode | UNDERL | mode;
		else
			obuf[col].c_char = '_';
	case ' ':
		col++;
		if (col > maxcol)
			maxcol = col;
		continue;

	case '\n':
		flushln();
		continue;

	default:
		if (c < ' ')	/* non printing */
			continue;
		if (obuf[col].c_char == '\0') {
			obuf[col].c_char = c;
			obuf[col].c_mode = mode;
		} else if (obuf[col].c_char == '_') {
			obuf[col].c_char = c;
			obuf[col].c_mode = obuf[col].c_mode | UNDERL|mode;
		} else if (obuf[col].c_char == c)
			obuf[col].c_mode = obuf[col].c_mode | BOLD|mode;
		else {
			obuf[col].c_mode = c;
			obuf[col].c_mode = mode;
		}
		col++;
		if (col > maxcol)
			maxcol = col;
		continue;
	}
	if (maxcol)
		flushln();
}

int 
flushln (void)
{
	int lastmode;
	int i;
	int hadmodes = 0;

	lastmode = NORMAL;
	for (i=0; i<maxcol; i++) {
		if (obuf[i].c_mode != lastmode) {
			hadmodes++;
			setmode(obuf[i].c_mode);
			lastmode = obuf[i].c_mode;
		}
		if (obuf[i].c_char == '\0') {
			if (upln) {
				puts(CURS_RIGHT);
			} else
				outc(' ');
		} else
			outc(obuf[i].c_char);
	}
	if (lastmode != NORMAL) {
		setmode(0);
	}
	if (must_overstrike && hadmodes)
		overstrike();
	putch('\n');
	if (iflag && hadmodes)
		iattr();
	fflush(stdout);
	if (upln)
		upln--;
	initbuf();
}

/*
 * For terminals that can overstrike, overstrike underlines and bolds.
 * We don't do anything with halfline ups and downs, or Greek.
 */
int 
overstrike (void)
{
	register int i;
	char lbuf[256];
	register char *cp = lbuf;
	int hadbold=0;

	/* Set up overstrike buffer */
	for (i=0; i<maxcol; i++)
		switch (obuf[i].c_mode) {
		case NORMAL:
		default:
			*cp++ = ' ';
			break;
		case UNDERL:
			*cp++ = '_';
			break;
		case BOLD:
			*cp++ = obuf[i].c_char;
			hadbold=1;
			break;
		}
	putch('\r');
	*cp = ' ';			/* fcc gap: deref-store in for-init; hoisted out */
	for ( ; *cp==' '; cp--)
		*cp = 0;
	for (cp=lbuf; *cp; cp++)
		putch(*cp);
	if (hadbold) {
		putch('\r');
		for (cp=lbuf; *cp; cp++)
			putch(*cp=='_' ? ' ' : *cp);
		putch('\r');
		for (cp=lbuf; *cp; cp++)
			putch(*cp=='_' ? ' ' : *cp);
	}
}

int 
iattr (void)
{
	register int i;
	char lbuf[256];
	register char *cp = lbuf;

	for (i=0; i<maxcol; i++)
		switch (obuf[i].c_mode) {
		case NORMAL:	*cp++ = ' '; break;
		case ALTSET:	*cp++ = 'g'; break;
		case SUPERSC:	*cp++ = '^'; break;
		case SUBSC:	*cp++ = 'v'; break;
		case UNDERL:	*cp++ = '_'; break;
		case BOLD:	*cp++ = '!'; break;
		default:	*cp++ = 'X'; break;
		}
	*cp = ' ';			/* fcc gap: deref-store in for-init; hoisted out */
	for ( ; *cp==' '; cp--)
		*cp = 0;
	for (cp=lbuf; *cp; cp++)
		putch(*cp);
	putch('\n');
}

int 
initbuf (void)
{

	memset(obuf, 0, sizeof (obuf));		/* depends on NORMAL == 0 */
	col = 0;
	maxcol = 0;
	mode &= ALTSET;
}

int 
fwd (void)
{
	int oldcol, oldmax;

	oldcol = col;
	oldmax = maxcol;
	flushln();
	col = oldcol;
	maxcol = oldmax;
}

int 
reverse (void)
{
	upln++;
	fwd();
	puts(CURS_UP);
	puts(CURS_UP);
	upln++;
}

int 
initcap (void)
{
	static char tcapbuf[512];
	char *bp = tcapbuf;

	/* This nonsense attempts to work with both old and new termcap */
	CURS_UP =		tgetstr("up", &bp);
	CURS_RIGHT =		tgetstr("ri", &bp);
	if (CURS_RIGHT == NULL)
		CURS_RIGHT =	tgetstr("nd", &bp);
	CURS_LEFT =		tgetstr("le", &bp);
	if (CURS_LEFT == NULL)
		CURS_LEFT =	tgetstr("bc", &bp);
	if (CURS_LEFT == NULL && tgetflag("bs"))
		CURS_LEFT =	"\b";

	ENTER_STANDOUT =	tgetstr("so", &bp);
	EXIT_STANDOUT =		tgetstr("se", &bp);
	ENTER_UNDERLINE =	tgetstr("us", &bp);
	EXIT_UNDERLINE =	tgetstr("ue", &bp);
	ENTER_DIM =		tgetstr("mh", &bp);
	ENTER_BOLD =		tgetstr("md", &bp);
	ENTER_REVERSE =		tgetstr("mr", &bp);
	EXIT_ATTRIBUTES =	tgetstr("me", &bp);

	if (!ENTER_BOLD && ENTER_REVERSE)
		ENTER_BOLD = ENTER_REVERSE;
	if (!ENTER_BOLD && ENTER_STANDOUT)
		ENTER_BOLD = ENTER_STANDOUT;
	if (!ENTER_UNDERLINE && ENTER_STANDOUT) {
		ENTER_UNDERLINE = ENTER_STANDOUT;
		EXIT_UNDERLINE = EXIT_STANDOUT;
	}
	if (!ENTER_DIM && ENTER_STANDOUT)
		ENTER_DIM = ENTER_STANDOUT;
	if (!ENTER_REVERSE && ENTER_STANDOUT)
		ENTER_REVERSE = ENTER_STANDOUT;
	if (!EXIT_ATTRIBUTES && EXIT_STANDOUT)
		EXIT_ATTRIBUTES = EXIT_STANDOUT;
	
	/*
	 * Note that we use REVERSE for the alternate character set,
	 * not the as/ae capabilities.  This is because we are modelling
	 * the model 37 teletype (since that's what nroff outputs) and
	 * the typical as/ae is more of a graphics set, not the greek
	 * letters the 37 has.
	 */

	UNDER_CHAR =		tgetstr("uc", &bp);
	must_use_uc = (UNDER_CHAR && !ENTER_UNDERLINE);
}

int 
outchar (int c)
{
	putch(c&0177);
}

/* fcc's libc has no putch (od.c defines its own too); getc is fgetc; stdio
 * is unbuffered so fflush is a no-op. */
int
putch (int c)
{
	fputc(c, stdout);
	return c;
}

int
fflush (FILE *f)
{
	return 0;			/* fcc fputc writes immediately -- nothing buffered */
}

/* tputs now comes from libtermlib (BSD-foundations P1) — the local copy
 * this comment anchored is retired; the tool selects libs="termlib".
 * UP and BC below are tentative definitions: libtermlib defines them, as
 * 2.11BSD's tgoto.c does, and K&R A.10.2's common extension merges the
 * two (this tool never calls tgoto, so they stay null). */
char *UP;
char *BC;
/* RTL-ABI: termlib compiles tputs/tgoto behind EMPTY-PAREN forward
 * decls (the fcc variadic flip, matching elvis's K&R externs) — every
 * client must declare them the same way or the args land reversed. */
void tputs();

int
puts (char *str)
{
	if (str)
		tputs(str, 1, outchar);
}

static int curmode = 0;
int 
outc (int c)
{
	putch(c);
	if (must_use_uc &&  (curmode&UNDERL)) {
		puts(CURS_LEFT);
		puts(UNDER_CHAR);
	}
}

int 
setmode (int newmode)
{
	if (!iflag)
	{
		if (curmode != NORMAL && newmode != NORMAL)
			setmode(NORMAL);
		switch (newmode) {
		case NORMAL:
			switch(curmode) {
			case NORMAL:
				break;
			case UNDERL:
				puts(EXIT_UNDERLINE);
				break;
			default:
				/* This includes standout */
				puts(EXIT_ATTRIBUTES);
				break;
			}
			break;
		case ALTSET:
			puts(ENTER_REVERSE);
			break;
		case SUPERSC:
			/*
			 * This only works on a few terminals.
			 * It should be fixed.
			 */
			puts(ENTER_UNDERLINE);
			puts(ENTER_DIM);
			break;
		case SUBSC:
			puts(ENTER_DIM);
			break;
		case UNDERL:
			puts(ENTER_UNDERLINE);
			break;
		case BOLD:
			puts(ENTER_BOLD);
			break;
		default:
			/*
			 * We should have some provision here for multiple modes
			 * on at once.  This will have to come later.
			 */
			puts(ENTER_STANDOUT);
			break;
		}
	}
	curmode = newmode;
}
