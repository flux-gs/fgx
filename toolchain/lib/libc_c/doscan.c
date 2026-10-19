/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/doscan.c
 *   Original work: doscan.c 5.2 (Berkeley) 3/9/86,
 *	The Regents of the University of California.
 */
/* ---- _doscan: the scanf(3) engine ------------------------------------------
 * Upstream's body.  argp walks the caller's arguments as an int **, one
 * pointer per conversion, which is also what a va_list is on this ABI
 * (printf.c's vsprintf note); scanf.c hands it over from va_start.
 *
 * FGX deltas:
 * - A NULL iop reads the string __lc_scstr instead of a stream, for
 *   sscanf.  Upstream's sscanf builds a FILE on the stack flagged _IOSTRG
 *   whose buffer is the string, and _filbuf answers EOF at its end; an FGX
 *   FILE is a slot in _libc_FILE_table and holds no buffer pointer, so there
 *   is no FILE to build.  _sc_getc and _sc_ungetc stand where upstream calls
 *   getc and ungetc, and do exactly those on a stream.
 * - %g is a floating conversion beside %e and %f, and an L prefix means
 *   double as l does.  K&R 2nd ed B.1.3: "The conversion characters e, f,
 *   and g may be preceded by l if a pointer to double rather than float is
 *   in the argument list, and by L if a pointer to a long double."  Upstream
 *   read %g as an integer and took %Le for a conversion named `l'.  long
 *   double is double here.
 * - `register c' and its like are spelled `register int', and _innum's
 *   `extern double atof()' is stdlib.h's prototype.
 * Not carried, as upstream has none: %i, %n and %p.
 */

#define	SPC	01
#define	STP	02

#define	SHORT	0
#define	REGULAR	1
#define	LONG	2
#define	INT	0
#define	FLOAT	1

static char *_getccl();
static int _innum(), _instr();

static char *__lc_scstr;		/* sscanf's input; see _sc_getc */

static char _sctab[256] = {
	0,0,0,0,0,0,0,0,
	0,SPC,SPC,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	SPC,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
};

/* getc(iop), or the next character of sscanf's string: EOF at its end,
 * which it does not step past. */
static int
_sc_getc(iop)
	FILE *iop;
{
	if (iop != NULL)
		return (getc(iop));
	if (*__lc_scstr == '\0')
		return (EOF);
	return (*__lc_scstr++ & 0377);
}

/* ungetc(c, iop), or one step back along sscanf's string. */
static void
_sc_ungetc(c, iop)
	int c;
	FILE *iop;
{
	if (iop != NULL)
		ungetc(c, iop);
	else if (c != EOF)
		__lc_scstr--;
}

_doscan(iop, fmt, argp)
FILE *iop;
register char *fmt;
register int **argp;
{
	register int ch;
	int nmatch, len, ch1;
	int **ptr, fileended, size;

	nmatch = 0;
	fileended = 0;
	for (;;) switch (ch = *fmt++) {
	case '\0':
		return (nmatch);
	case '%':
		if ((ch = *fmt++) == '%')
			goto def;
		ptr = 0;
		if (ch != '*')
			ptr = argp++;
		else
			ch = *fmt++;
		len = 0;
		size = REGULAR;
		while (isdigit(ch)) {
			len = len*10 + ch - '0';
			ch = *fmt++;
		}
		if (len == 0)
			len = 30000;
		if (ch=='l' || ch=='L') {		/* FGX: L, K&R B.1.3 */
			size = LONG;
			ch = *fmt++;
		} else if (ch=='h') {
			size = SHORT;
			ch = *fmt++;
		} else if (ch=='[')
			fmt = _getccl(fmt);
		if (isupper(ch)) {
			ch = tolower(ch);
			size = LONG;
		}
		if (ch == '\0')
			return(-1);
		if (_innum(ptr, ch, len, size, iop, &fileended) && ptr)
			nmatch++;
		if (fileended)
			return(nmatch? nmatch: -1);
		break;

	case ' ':
	case '\n':
	case '\t':
		while ((ch1 = _sc_getc(iop))==' ' || ch1=='\t' || ch1=='\n')
			;
		if (ch1 != EOF)
			_sc_ungetc(ch1, iop);
		break;

	default:
	def:
		ch1 = _sc_getc(iop);
		if (ch1 != ch) {
			if (ch1==EOF)
				return(-1);
			_sc_ungetc(ch1, iop);
			return(nmatch);
		}
	}
}

static
_innum(ptr, type, len, size, iop, eofptr)
int **ptr, *eofptr;
FILE *iop;
{
	register char *np;
	char numbuf[64];
	register int c, base;
	int expseen, scale, negflg, c1, ndigit;
	long lcval;

	if (type=='c' || type=='s' || type=='[')
		return(_instr(ptr? *(char **)ptr: (char *)NULL, type, len, iop, eofptr));
	lcval = 0;
	ndigit = 0;
	scale = INT;
	if (type=='e'||type=='f'||type=='g')	/* FGX: g, K&R B.1.3 */
		scale = FLOAT;
	base = 10;
	if (type=='o')
		base = 8;
	else if (type=='x')
		base = 16;
	np = numbuf;
	expseen = 0;
	negflg = 0;
	while ((c = _sc_getc(iop))==' ' || c=='\t' || c=='\n');
	if (c=='-') {
		negflg++;
		*np++ = c;
		c = _sc_getc(iop);
		len--;
	} else if (c=='+') {
		len--;
		c = _sc_getc(iop);
	}
	for ( ; --len>=0; *np++ = c, c = _sc_getc(iop)) {
		if (isdigit(c)
		 || base==16 && ('a'<=c && c<='f' || 'A'<=c && c<='F')) {
			ndigit++;
			if (base==8)
				lcval <<=3;
			else if (base==10)
				lcval = ((lcval<<2) + lcval)<<1;
			else
				lcval <<= 4;
			c1 = c;
			if (isdigit(c))
				c -= '0';
			else if ('a'<=c && c<='f')
				c -= 'a'-10;
			else
				c -= 'A'-10;
			lcval += c;
			c = c1;
			continue;
		} else if (c=='.') {
			if (base!=10 || scale==INT)
				break;
			ndigit++;
			continue;
		} else if ((c=='e'||c=='E') && expseen==0) {
			if (base!=10 || scale==INT || ndigit==0)
				break;
			expseen++;
			*np++ = c;
			c = _sc_getc(iop);
			if (c!='+'&&c!='-'&&('0'>c||c>'9'))
				break;
		} else
			break;
	}
	if (negflg)
		lcval = -lcval;
	if (c != EOF) {
		_sc_ungetc(c, iop);
		*eofptr = 0;
	} else
		*eofptr = 1;
 	if (ptr==NULL || np==numbuf || (negflg && np==numbuf+1) )/* gene dykes*/
		return(0);
	*np++ = 0;
	switch((scale<<4) | size) {

	case (FLOAT<<4) | SHORT:
	case (FLOAT<<4) | REGULAR:
		**(float **)ptr = atof(numbuf);
		break;

	case (FLOAT<<4) | LONG:
		**(double **)ptr = atof(numbuf);
		break;

	case (INT<<4) | SHORT:
		**(short **)ptr = lcval;
		break;

	case (INT<<4) | REGULAR:
		**(int **)ptr = lcval;
		break;

	case (INT<<4) | LONG:
		**(long **)ptr = lcval;
		break;
	}
	return(1);
}

static
_instr(ptr, type, len, iop, eofptr)
register char *ptr;
register FILE *iop;
int *eofptr;
{
	register int ch;
	register char *optr;
	int ignstp;

	*eofptr = 0;
	optr = ptr;
	if (type=='c' && len==30000)
		len = 1;
	ignstp = 0;
	if (type=='s')
		ignstp = SPC;
	while ((ch = _sc_getc(iop)) != EOF && _sctab[ch] & ignstp)
		;
	ignstp = SPC;
	if (type=='c')
		ignstp = 0;
	else if (type=='[')
		ignstp = STP;
	while (ch!=EOF && (_sctab[ch]&ignstp)==0) {
		if (ptr)
			*ptr++ = ch;
		if (--len <= 0)
			break;
		ch = _sc_getc(iop);
	}
	if (ch != EOF) {
		if (len > 0)
			_sc_ungetc(ch, iop);
		*eofptr = 0;
	} else
		*eofptr = 1;
	if (ptr && ptr!=optr) {
		if (type!='c')
			*ptr++ = '\0';
		return(1);
	}
	return(0);
}

static char *
_getccl(s)
register unsigned char *s;
{
	register int c, t;

	t = 0;
	if (*s == '^') {
		t++;
		s++;
	}
	for (c = 0; c < (sizeof _sctab / sizeof _sctab[0]); c++)
		if (t)
			_sctab[c] &= ~STP;
		else
			_sctab[c] |= STP;
	if ((c = *s) == ']' || c == '-') {	/* first char is special */
		if (t)
			_sctab[c] |= STP;
		else
			_sctab[c] &= ~STP;
		s++;
	}
	while ((c = *s++) != ']') {
		if (c==0)
			return((char *)--s);
		else if (c == '-' && *s != ']' && s[-2] < *s) {
			for (c = s[-2] + 1; c < *s; c++)
				if (t)
					_sctab[c] |= STP;
				else
					_sctab[c] &= ~STP;
		} else if (t)
			_sctab[c] |= STP;
		else
			_sctab[c] &= ~STP;
	}
	return((char *)s);
}

/* One translation unit (libc_c.c): the names above end here. */
#undef	SPC
#undef	STP
#undef	SHORT
#undef	REGULAR
#undef	LONG
#undef	INT
#undef	FLOAT
