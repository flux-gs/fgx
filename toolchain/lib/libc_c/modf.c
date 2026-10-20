/* SPDX-License-Identifier: Apache-2.0
 * FGX-Provenance: 65816-llvm-mos (vendor/65816-llvm-mos/runtime/src/math.c)
 *   The W65816 llvm-mos fork's modf(), trunc() and floor(), commit
 *   4a13f9df, for libc's decimal conversions (apple/fgx#447).
 *   FGX deltas: the work is on long double, with modf() as the double
 *   interface; trunc() is floor()'s fraction mask applied directly.
 *   See docs/PROVENANCE.md.
 */
/*
 * modf(value, iptr): the fractional part of value, with its integral part
 * stored through iptr.  Both carry value's sign.
 *
 * Derived from vendor/65816-llvm-mos/runtime/src/math.c: modf() there is
 * value - trunc(value), and trunc() rests on floor()'s mask of the fraction
 * bits.  Truncation toward zero is that mask alone, so __lc_truncl applies it
 * directly (see docs/PROVENANCE.md).  2.11BSD's modf is PDP-11 assembly
 * (pdp/gen/modf.s) and 4.3BSD-Reno's i386 C is x87 inline assembly.
 *
 * The work is done on long double, the 64-bit IEEE type, for libc's decimal
 * conversions (ecvt.c).  modf() is the double interface.
 */

/* value rounded toward zero: its fraction bits cleared. */
static long double
__lc_truncl(long double x)
{
    unsigned long long b;
    int e;

    b = *(unsigned long long *)&x;
    e = (int)((b >> 52) & 0x7FF) - 1023;
    if (e < 0)                                  /* |x| < 1: +-0 */
        b = b & 0x8000000000000000ULL;
    else if (e < 52)
        b = b & ~(((unsigned long long)1 << (52 - e)) - 1);
    return *(long double *)&b;                  /* e >= 52: already whole */
}

long double
__lc_modfl(long double value, long double *iptr)
{
    *iptr = __lc_truncl(value);
    return value - *iptr;
}

double
modf(double value, double *iptr)
{
    long double ip, f;

    f = __lc_modfl(value, &ip);
    *iptr = ip;
    return f;
}
