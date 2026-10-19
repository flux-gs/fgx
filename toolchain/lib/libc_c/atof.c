/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno lib/libc/hp300/stdlib/atof.c
 *   Ported from atof(3), 4.3BSD-Reno (5.1, 1990/05/12).  Original work:
 *   Copyright (c) 1990 The Regents of the University of California.
 *   All rights reserved.  This code is derived from software contributed to
 *   Berkeley by the Systems Programming Group of the University of Utah
 *   Computer Science Department.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* atof(3): a decimal string to a double (apple/fgx#447).
 *
 * PORTED FROM 4.3BSD-RENO's hp300 COPY, NOT 2.11BSD, because it is the one
 * written for IEEE doubles: it accumulates digits up to 2^53 (_twoemax, "#ifdef
 * IEEE") and scales by an exact table of 5^(2^k) up to 5^256.  2.11BSD's
 * (pdp/gen/atof.c) stops at 2^56 and a LOGHUGE of 39, the PDP-11's range.
 *
 * FGX deltas:
 * - the work is on long double, the 64-bit IEEE type, with __lc_ldexpl
 *   (ldexp.c) for ldexp(); atof() keeps the double interface.
 * - _exp5[] is the "IEEE" decimal table with an L suffix, so each entry is
 *   the long double nearest to it, not a bit-pattern table: hp300's struct
 *   of high and low words is in big-endian order.
 * - _twoemax and _exp5 are static: nothing outside this file reads them.
 */
#include <ctype.h>

long double __lc_ldexpl();

static long double _twoemax =
	9007199254740992.L;	/*2^53*/

static long double _exp5[] = {
	5.L,
	25.L,
	625.L,
	390625.L,
	152587890625.L,
	23283064365386962890625.L,
	5.4210108624275231e+044L,
	2.9387358770557196e+089L,
	8.6361685550944492e+178L,
};

double
atof(p)
register char *p;
{
	register c, exp = 0, eexp = 0;
	long double fl = 0, flexp = 1.0;
	int bexp, neg = 1, negexp = 1;

	while((c = *p++) == ' ');
	if (c == '-') neg = -1;	else if (c == '+'); else --p;

	while ((c = *p++), isdigit(c))
		if (fl < _twoemax) fl = 10*fl + (c-'0'); else exp++;
	if (c == '.')
	while ((c = *p++), isdigit(c))
		if (fl < _twoemax)
		{
			fl = 10*fl + (c-'0');
			exp--;
		}
	if ((c == 'E') || (c == 'e'))
	{
		if ((c= *p++) == '+'); else if (c=='-') negexp = -1; else --p;
		while ((c = *p++), isdigit(c)) eexp = 10*eexp + (c-'0');
		if (negexp < 0) eexp = -eexp; exp += eexp;
	}
	bexp = exp;
	if (exp < 0) exp = -exp;

	for (c = 0; c < sizeof(_exp5)/sizeof(_exp5[0]); c++)
	{
		if (exp & 01) flexp *= _exp5[c];
		exp >>= 1; if (exp == 0) break;
	}

	if (bexp < 0) fl /= flexp; else fl *= flexp;
	fl = __lc_ldexpl(fl, bexp);
	if (neg < 0) return(-fl); else return(fl);
}
