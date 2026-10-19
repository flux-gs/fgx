/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno hp300/float.h
 *   Ported from float.h 7.1 (Berkeley) 5/8/90.  Original work:
 *   Copyright (c) 1989 Regents of the University of California.
 *   All rights reserved.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 */
/* float.h -- the characteristics of float, double and long double, K&R 2nd ed
 * B.11 (apple/fgx#447).
 *
 * Reno's hp300 header, the IEEE one: float is IEEE single, double and long
 * double are one type, IEEE double, as fcc's are.  Both round to nearest,
 * ties to even (toolchain/lib/fcc_runtime.s's _fcc_fround; the soft double,
 * lib/libdouble/softdouble.c), which is FLT_ROUNDS 1.
 *
 * FGX delta: DBL_MIN and DBL_MAX are given to 17 digits, as NetBSD 0.9's i386
 * float.h has them.  Reno's 16-digit 1.797693134862316E+308 is past the
 * largest double and reads as an infinity, and 2.225073858507201E-308 is
 * below the smallest normal one, a denormal the soft double flushes to 0:
 * the 68881 reads a constant in extended precision, and fcc reads it with
 * strtod.
 *
 * Neither runtime makes a denormal (both flush to 0), and the single one has
 * no infinity (it flushes an overflow to 0), which no name here describes.
 */
#ifndef _FLOAT_H
#define _FLOAT_H

#define FLT_RADIX	2		/* b */
#define FLT_ROUNDS	1		/* FP addition rounds to nearest */

#define FLT_MANT_DIG	24		/* p */
#define FLT_EPSILON	1.19209290E-07F	/* b**(1-p) */
#define FLT_DIG		6		/* floor((p-1)*log10(b))+(b == 10) */
#define FLT_MIN_EXP	-125		/* emin */
#define FLT_MIN		1.17549435E-38F	/* b**(emin-1) */
#define FLT_MIN_10_EXP	-37		/* ceil(log10(b**(emin-1))) */
#define FLT_MAX_EXP	128		/* emax */
#define FLT_MAX		3.40282347E+38F	/* (1-b**(-p))*b**emax */
#define FLT_MAX_10_EXP	38		/* floor(log10((1-b**(-p))*b**emax)) */

#define DBL_MANT_DIG	53
#define DBL_EPSILON	2.2204460492503131E-16
#define DBL_DIG		15
#define DBL_MIN_EXP	-1021
#define DBL_MIN		2.2250738585072014E-308
#define DBL_MIN_10_EXP	-307
#define DBL_MAX_EXP	1024
#define DBL_MAX		1.7976931348623157E+308
#define DBL_MAX_10_EXP	308

#define LDBL_MANT_DIG	DBL_MANT_DIG
#define LDBL_EPSILON	DBL_EPSILON
#define LDBL_DIG	DBL_DIG
#define LDBL_MIN_EXP	DBL_MIN_EXP
#define LDBL_MIN	DBL_MIN
#define LDBL_MIN_10_EXP	DBL_MIN_10_EXP
#define LDBL_MAX_EXP	DBL_MAX_EXP
#define LDBL_MAX	DBL_MAX
#define LDBL_MAX_10_EXP	DBL_MAX_10_EXP

#endif /* _FLOAT_H */
