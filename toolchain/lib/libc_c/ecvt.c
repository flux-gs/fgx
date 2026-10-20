/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/pdp/gen/ecvt.c
 *   Original work: ecvt.c 5.1 (Berkeley) 3/15/86,
 *	The Regents of the University of California.
 */
/* ecvt(3) and fcvt(3): a double to a string of decimal digits.  The digits
 * behind printf's %e, %f and %g (fltpr.c), as 2.11BSD's fltpr.s calls
 * _ecvt and _fcvt (apple/fgx#447).
 *
 * Upstream's body, with three FGX deltas:
 * - cvt() works on long double, the 64-bit IEEE type, and calls __lc_modfl
 *   (modf.c) for its modf(); ecvt() and fcvt() keep the double interface.
 * - An infinity or a NaN returns "inf" or "nan", with *sign set.  The PDP-11
 *   had neither, and on IEEE `while (fi != 0)' never ends for an infinity.
 * - A value of 1e40 or more is divided by 1e10 until it is less, and the
 *   places added back to *decpt.  The integer part's digits are written
 *   right to left from the end of buf, unbounded; the PDP-11's largest double
 *   is about 1.7e38, 39 digits, and IEEE's is 1.8e308, which ran 230 bytes
 *   off the front of buf.  The digits the division disturbs are past a
 *   double's 17 significant ones.
 */

static char *cvt();
long double __lc_modfl();

#define	NDIG	80
char*
ecvt(arg, ndigits, decpt, sign)
double arg;
int ndigits, *decpt, *sign;
{
	return(cvt((long double)arg, ndigits, decpt, sign, 1));
}

char*
fcvt(arg, ndigits, decpt, sign)
double arg;
int ndigits, *decpt, *sign;
{
	return(cvt((long double)arg, ndigits, decpt, sign, 0));
}

static char*
cvt(arg, ndigits, decpt, sign, eflag)
long double arg;
int ndigits, *decpt, *sign;
{
	register int r2, sc;
	long double fi, fj;
	register char *p, *p1;
	static char buf[NDIG];
	unsigned *w;

	if (ndigits<0)
		ndigits = 0;
	if (ndigits>=NDIG-1)
		ndigits = NDIG-2;
	r2 = 0;
	*sign = 0;
	p = &buf[0];
	w = (unsigned *)&arg;			/* w[3]: sign, exponent, top */
	if ((w[3] & 0x7FF0) == 0x7FF0) {	/* FGX: infinity or NaN */
		*sign = (w[3] & 0x8000) != 0;
		*decpt = 0;
		if ((w[3] & 0x000F) | w[2] | w[1] | w[0]) {
			buf[0] = 'n'; buf[1] = 'a'; buf[2] = 'n';
		} else {
			buf[0] = 'i'; buf[1] = 'n'; buf[2] = 'f';
		}
		buf[3] = '\0';
		return(buf);
	}
	if (arg<0) {
		*sign = 1;
		arg = -arg;
	}
	sc = 0;
	while (arg >= 1e40L) {			/* FGX: see the note above */
		arg /= 1e10L;
		sc += 10;
	}
	arg = __lc_modfl(arg, &fi);
	p1 = &buf[NDIG];
	/*
	 * Do integer part
	 */
	if (fi != 0) {
		p1 = &buf[NDIG];
		while (fi != 0) {
			fj = __lc_modfl(fi/10, &fi);
			*--p1 = (int)((fj+.03)*10) + '0';
			r2++;
		}
		while (p1 < &buf[NDIG])
			*p++ = *p1++;
	} else if (arg > 0) {
		while ((fj = arg*10) < 1) {
			arg = fj;
			r2--;
		}
	}
	r2 += sc;
	p1 = &buf[ndigits];
	if (eflag==0)
		p1 += r2;
	*decpt = r2;
	if (p1 < &buf[0]) {
		buf[0] = '\0';
		return(buf);
	}
	while (p<=p1 && p<&buf[NDIG]) {
		arg *= 10;
		arg = __lc_modfl(arg, &fj);
		*p++ = (int)fj + '0';
	}
	if (p1 >= &buf[NDIG]) {
		buf[NDIG-1] = '\0';
		return(buf);
	}
	p = p1;
	*p1 += 5;
	while (*p1 > '9') {
		*p1 = '0';
		if (p1>buf)
			++*--p1;
		else {
			*p1 = '1';
			(*decpt)++;
			if (eflag==0) {
				if (p>buf)
					*p = '0';
				p++;
			}
		}
	}
	*p = '\0';
	return(buf);
}
