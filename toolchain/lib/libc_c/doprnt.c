/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno vendor/4.3BSD-Reno/lib/libc/stdio/doprnt.c
 *   Original work: doprnt.c 5.39 (Berkeley) 6/28/90,
 *	Copyright (c) 1988 Regents of the University of California.
 */
/* _doprnt, the printf engine: upstream's body, writing into the FILE's
 * buffer through putc and bcopy.  The #include lines are the aggregate's
 * (libc_c.c).  FGX deltas:
 * - ARG casts the plain int to its basetype.  Upstream's int is 32 bits, so
 *   `va_arg(argp, int)' into a u_long is the same either way; here it is 16,
 *   and %x of 0xffff sign-extended to ffffffff.
 * - %qd and %lld are 64-bit (QUADINT), from netbsd-0-9's vfprintf.c, which
 *   is 4.4BSD's: the four words are divided in place, 32 bits at a time,
 *   because this pile cannot reach the long long runtime.
 * - The %e/%f/%g digits are __lc_pf_float's, with cvt's interface: fltpr.c,
 *   or ffltpr's `?' in a static program that prints no float, as 2.11BSD
 *   splits pdp/stdio/fltpr.s from doprnt.s so that a program with no
 *   floating point loads none.  cvt itself is double arithmetic.
 * - %s's memchr is <string.h>'s: upstream's block-scope `char *memchr()'
 *   hid the prototype, and prec, an int, went where a size_t is read.
 * - `*buf = '\0'', where upstream assigns NULL, which is a pointer here.
 */
/* 11-bit exponent (VAX G floating point) is 308 decimal digits */
#define	MAXEXP		308
/* 128 bit fraction takes up 39 decimal digits; max reasonable precision */
#define	MAXFRACT	39

#define	DEFPREC		6

#define	BUF		(MAXEXP+MAXFRACT+1)	/* + decimal point */

#define	PUTC(ch)	(void) putc(ch, fp)

#define ARG(basetype) \
	_ulong = flags&LONGINT ? va_arg(argp, long basetype) : \
	    flags&SHORTINT ? (short basetype)va_arg(argp, int) : \
	    (basetype)va_arg(argp, int)

#define	todigit(c)	((c) - '0')
#define	tochar(n)	((n) + '0')

/* have to deal with the negative buffer count kludge */
#define	NEGATIVE_COUNT_KLUDGE

#define	LONGINT		0x01		/* long integer */
#define	LONGDBL		0x02		/* long double; unimplemented */
#define	SHORTINT	0x04		/* short integer */
#define	ALT		0x08		/* alternate form */
#define	LADJUST		0x10		/* left adjustment */
#define	ZEROPAD		0x20		/* zero (as opposed to blank) pad */
#define	HEXPREFIX	0x40		/* add 0x or 0X prefix */
#define	QUADINT		0x80		/* FGX: %qd, %lld */

int	__lc_pf_float(double, int, int, char *, int, char *, char *);

/* FGX: a quad's four words, lowest first, as the caller pushed them. */
#define	QARG() \
	for (n = 0; n < 4; n++) \
		_quad[n] = va_arg(argp, unsigned)
#define	QNONZERO()	(_quad[0] | _quad[1] | _quad[2] | _quad[3])

/* A 64-bit value as four 16-bit words, w[0] lowest, divided in place by base
 * (8, 10 or 16); the remainder is returned.  Each step divides a value below
 * base * 65536, so it stays in 32 bits. */
static int
__lc_pf_qdiv(w, base)
	unsigned *w;
	int base;
{
	unsigned long cur, r;
	int i;

	r = 0;
	for (i = 3; i >= 0; i--) {
		cur = (r << 16) | w[i];
		w[i] = (unsigned)(cur / base);
		r = cur % base;
	}
	return ((int)r);
}

_doprnt(fmt0, argp, fp)
	u_char *fmt0;
	va_list argp;
	register FILE *fp;
{
	register u_char *fmt;	/* format string */
	register int ch;	/* character from fmt */
	register int cnt;	/* return value accumulator */
	register int n;		/* random handy integer */
	register char *t;	/* buffer pointer */
	u_long _ulong;		/* integer arguments %[diouxX] */
	unsigned _quad[4];	/* FGX: %q[diouxX] */
	int base;		/* base for [diouxX] conversion */
	int dprec;		/* decimal precision in [diouxX] */
	int fieldsz;		/* field size expanded by sign, etc */
	int flags;		/* flags as above */
	int fpprec;		/* `extra' floating precision in [eEfgG] */
	int prec;		/* precision from format (%.3d), or -1 */
	int realsz;		/* field size expanded by decimal precision */
	int size;		/* size of converted field or string */
	int width;		/* width from format (%8d), or 0 */
	char sign;		/* sign prefix (' ', '+', '-', or \0) */
	char softsign;		/* temporary negative sign for floats */
	char *digs;		/* digits for [diouxX] conversion */
	char buf[BUF];		/* space for %c, %[diouxX], %[eEfgG] */

	if (fp->_flag & _IORW) {
		fp->_flag |= _IOWRT;
		fp->_flag &= ~(_IOEOF|_IOREAD);
	}
	if ((fp->_flag & _IOWRT) == 0)
		return (EOF);

	fmt = fmt0;
	digs = "0123456789abcdef";
	for (cnt = 0;; ++fmt) {
		n = fp->_cnt;
		for (t = (char *)fp->_ptr; (ch = *fmt) && ch != '%';
		     ++cnt, ++fmt)
			if (--n < 0
#ifdef NEGATIVE_COUNT_KLUDGE
			    && (!(fp->_flag & _IOLBF) || -n >= fp->_bufsiz)
#endif
			    || ch == '\n' && fp->_flag & _IOLBF) {
				fp->_cnt = n;
				fp->_ptr = t;
				(void) _flsbuf((u_char)ch, fp);
				n = fp->_cnt;
				t = (char *)fp->_ptr;
			} else
				*t++ = ch;
		fp->_cnt = n;
		fp->_ptr = t;
		if (!ch)
			return (cnt);

		flags = 0; dprec = 0; fpprec = 0; width = 0;
		prec = -1;
		sign = '\0';

rflag:		switch (*++fmt) {
		case ' ':
			/*
			 * ``If the space and + flags both appear, the space
			 * flag will be ignored.''
			 *	-- ANSI X3J11
			 */
			if (!sign)
				sign = ' ';
			goto rflag;
		case '#':
			flags |= ALT;
			goto rflag;
		case '*':
			/*
			 * ``A negative field width argument is taken as a
			 * - flag followed by a  positive field width.''
			 *	-- ANSI X3J11
			 * They don't exclude field widths read from args.
			 */
			if ((width = va_arg(argp, int)) >= 0)
				goto rflag;
			width = -width;
			/* FALLTHROUGH */
		case '-':
			flags |= LADJUST;
			goto rflag;
		case '+':
			sign = '+';
			goto rflag;
		case '.':
			if (*++fmt == '*')
				n = va_arg(argp, int);
			else {
				n = 0;
				while (isascii(*fmt) && isdigit(*fmt))
					n = 10 * n + todigit(*fmt++);
				--fmt;
			}
			prec = n < 0 ? -1 : n;
			goto rflag;
		case '0':
			/*
			 * ``Note that 0 is taken as a flag, not as the
			 * beginning of a field width.''
			 *	-- ANSI X3J11
			 */
			flags |= ZEROPAD;
			goto rflag;
		case '1': case '2': case '3': case '4':
		case '5': case '6': case '7': case '8': case '9':
			n = 0;
			do {
				n = 10 * n + todigit(*fmt);
			} while (isascii(*++fmt) && isdigit(*fmt));
			width = n;
			--fmt;
			goto rflag;
		case 'L':
			flags |= LONGDBL;
			goto rflag;
		case 'h':
			flags |= SHORTINT;
			goto rflag;
		case 'l':
			if (flags & LONGINT)
				flags |= QUADINT;
			flags |= LONGINT;
			goto rflag;
		case 'q':
			flags |= QUADINT;
			goto rflag;
		case 'c':
			*(t = buf) = va_arg(argp, int);
			size = 1;
			sign = '\0';
			goto pforw;
		case 'D':
			flags |= LONGINT;
			/*FALLTHROUGH*/
		case 'd':
		case 'i':
			if (flags & QUADINT) {
				QARG();
				if (_quad[3] & 0x8000) {	/* negate in place */
					for (n = 0; n < 4; n++)
						_quad[n] = ~_quad[n];
					for (n = 0; n < 4; n++)
						if (++_quad[n] != 0)
							break;
					sign = '-';
				}
			} else {
				ARG(int);
				if ((long)_ulong < 0) {
					_ulong = -_ulong;
					sign = '-';
				}
			}
			base = 10;
			goto number;
		case 'e':
		case 'E':
		case 'f':
		case 'g':
		case 'G':
			/*
			 * don't do unrealistic precision; just pad it with
			 * zeroes later, so buffer size stays rational.
			 */
			if (prec > MAXFRACT) {
				if (*fmt != 'g' && *fmt != 'G' || (flags&ALT))
					fpprec = prec - MAXFRACT;
				prec = MAXFRACT;
			}
			else if (prec == -1)
				prec = DEFPREC;
			softsign = 0;
			*buf = '\0';
			size = __lc_pf_float(va_arg(argp, double), prec, flags,
			    &softsign, *fmt, buf, buf + sizeof(buf));
			if (softsign)
				sign = '-';
			t = *buf ? buf : buf + 1;
			goto pforw;
		case 'n':
			if (flags & LONGINT)
				*va_arg(argp, long *) = cnt;
			else if (flags & SHORTINT)
				*va_arg(argp, short *) = cnt;
			else
				*va_arg(argp, int *) = cnt;
			break;
		case 'O':
			flags |= LONGINT;
			/*FALLTHROUGH*/
		case 'o':
			if (flags & QUADINT)
				QARG();
			else
				ARG(unsigned);
			base = 8;
			goto nosign;
		case 'p':
			/*
			 * ``The argument shall be a pointer to void.  The
			 * value of the pointer is converted to a sequence
			 * of printable characters, in an implementation-
			 * defined manner.''
			 *	-- ANSI X3J11
			 */
			/* NOSTRICT */
			_ulong = (u_long)va_arg(argp, void *);
			base = 16;
			goto nosign;
		case 's':
			if (!(t = va_arg(argp, char *)))
				t = "(null)";
			if (prec >= 0) {
				/*
				 * can't use strlen; can only look for the
				 * NUL in the first `prec' characters, and
				 * strlen() will go further.
				 */
				char *p;

				if (p = memchr(t, 0, prec)) {
					size = p - t;
					if (size > prec)
						size = prec;
				} else
					size = prec;
			} else
				size = strlen(t);
			sign = '\0';
			goto pforw;
		case 'U':
			flags |= LONGINT;
			/*FALLTHROUGH*/
		case 'u':
			if (flags & QUADINT)
				QARG();
			else
				ARG(unsigned);
			base = 10;
			goto nosign;
		case 'X':
			digs = "0123456789ABCDEF";
			/* FALLTHROUGH */
		case 'x':
			if (flags & QUADINT)
				QARG();
			else
				ARG(unsigned);
			base = 16;
			/* leading 0x/X only if non-zero */
			if (flags & ALT &&
			    (flags & QUADINT ? QNONZERO() : _ulong) != 0)
				flags |= HEXPREFIX;

			/* unsigned conversions */
nosign:			sign = '\0';
			/*
			 * ``... diouXx conversions ... if a precision is
			 * specified, the 0 flag will be ignored.''
			 *	-- ANSI X3J11
			 */
number:			if ((dprec = prec) >= 0)
				flags &= ~ZEROPAD;

			/*
			 * ``The result of converting a zero value with an
			 * explicit precision of zero is no characters.''
			 *	-- ANSI X3J11
			 */
			t = buf + BUF;
			if (flags & QUADINT) {
				if (QNONZERO() != 0 || prec != 0) {
					do {
						*--t = digs[__lc_pf_qdiv(_quad, base)];
					} while (QNONZERO());
					digs = "0123456789abcdef";
					if (flags & ALT && base == 8 && *t != '0')
						*--t = '0'; /* octal leading 0 */
				}
			} else if (_ulong != 0 || prec != 0) {
				do {
					*--t = digs[_ulong % base];
					_ulong /= base;
				} while (_ulong);
				digs = "0123456789abcdef";
				if (flags & ALT && base == 8 && *t != '0')
					*--t = '0'; /* octal leading 0 */
			}
			size = buf + BUF - t;

pforw:
			/*
			 * All reasonable formats wind up here.  At this point,
			 * `t' points to a string which (if not flags&LADJUST)
			 * should be padded out to `width' places.  If
			 * flags&ZEROPAD, it should first be prefixed by any
			 * sign or other prefix; otherwise, it should be blank
			 * padded before the prefix is emitted.  After any
			 * left-hand padding and prefixing, emit zeroes
			 * required by a decimal [diouxX] precision, then print
			 * the string proper, then emit zeroes required by any
			 * leftover floating precision; finally, if LADJUST,
			 * pad with blanks.
			 */

			/*
			 * compute actual size, so we know how much to pad
			 * fieldsz excludes decimal prec; realsz includes it
			 */
			fieldsz = size + fpprec;
			if (sign)
				fieldsz++;
			if (flags & HEXPREFIX)
				fieldsz += 2;
			realsz = dprec > fieldsz ? dprec : fieldsz;

			/* right-adjusting blank padding */
			if ((flags & (LADJUST|ZEROPAD)) == 0 && width)
				for (n = realsz; n < width; n++)
					PUTC(' ');
			/* prefix */
			if (sign)
				PUTC(sign);
			if (flags & HEXPREFIX) {
				PUTC('0');
				PUTC((char)*fmt);
			}
			/* right-adjusting zero padding */
			if ((flags & (LADJUST|ZEROPAD)) == ZEROPAD)
				for (n = realsz; n < width; n++)
					PUTC('0');
			/* leading zeroes from decimal precision */
			for (n = fieldsz; n < dprec; n++)
				PUTC('0');

			/* the string or number proper */
			n = size;
			if (fp->_cnt - n >= 0 && (fp->_flag & _IOLBF) == 0) {
				fp->_cnt -= n;
				bcopy(t, (char *)fp->_ptr, n);
				fp->_ptr += n;
			} else
				while (--n >= 0)
					PUTC(*t++);
			/* trailing f.p. zeroes */
			while (--fpprec >= 0)
				PUTC('0');
			/* left-adjusting padding (always blank) */
			if (flags & LADJUST)
				for (n = realsz; n < width; n++)
					PUTC(' ');
			/* finally, adjust cnt */
			cnt += width > realsz ? width : realsz;
			break;
		case '\0':	/* "%?" prints ?, unless ? is NULL */
			return (cnt);
		default:
			PUTC((char)*fmt);
			cnt++;
		}
	}
	/* NOTREACHED */
}

/* One translation unit (libc_c.c): the names above end with this member. */
#undef	MAXEXP
#undef	MAXFRACT
#undef	DEFPREC
#undef	BUF
#undef	PUTC
#undef	ARG
#undef	todigit
#undef	tochar
#undef	NEGATIVE_COUNT_KLUDGE
#undef	LONGINT
#undef	LONGDBL
#undef	SHORTINT
#undef	ALT
#undef	LADJUST
#undef	ZEROPAD
#undef	HEXPREFIX
#undef	QUADINT
#undef	QARG
#undef	QNONZERO
