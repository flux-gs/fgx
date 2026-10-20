/* SPDX-License-Identifier: Apache-2.0
 * FGX-Provenance: 65816-llvm-mos (vendor/65816-llvm-mos/runtime/src/math.c)
 *   The W65816 llvm-mos fork's ldexp(), commit 4a13f9df, for libc's
 *   decimal conversions (apple/fgx#447).
 *   FGX deltas: the work is on long double, with ldexp() as the double
 *   interface; int is 16 bits, so the exponent step is clamped to +-4096;
 *   overflow and underflow build the infinity or zero from bits.
 *   See docs/PROVENANCE.md.
 */
/*
 * ldexp(value, exp): value * 2**exp, by adjusting the exponent field.
 *
 * Derived from vendor/65816-llvm-mos/runtime/src/math.c, ldexp() (see
 * docs/PROVENANCE.md).  No BSD tree carries a portable one: 2.11BSD's is
 * PDP-11 assembly (pdp/gen/ldexp.s) and 4.3BSD-Reno's i386 C is x87 inline
 * assembly.
 *
 * __lc_ldexpl does the work on long double, the 64-bit IEEE type, because
 * libc's decimal conversions (atof.c) need the full width.  ldexp() is the
 * double interface.
 */

long double
__lc_ldexpl(long double x, int n)
{
    unsigned long long b;
    int e;

    b = *(unsigned long long *)&x;
    e = (int)((b >> 52) & 0x7FF);
    /* Infinity or NaN as it is.  Zero stays zero; a denormal is left alone,
     * since the soft double flushes denormals to zero anyway. */
    if (e == 0x7FF || e == 0)
        return x;
    /* int is 16 bits: clamp so e + n cannot wrap.  Past +-4096 the answer is
     * already an overflow or an underflow. */
    if (n > 4096)
        n = 4096;
    if (n < -4096)
        n = -4096;
    e = e + n;
    if (e >= 0x7FF)                             /* overflow: +-infinity */
        b = (b & 0x8000000000000000ULL) | 0x7FF0000000000000ULL;
    else if (e <= 0)                            /* underflow: +-0 */
        b = b & 0x8000000000000000ULL;
    else
        b = (b & 0x800FFFFFFFFFFFFFULL) | ((unsigned long long)e << 52);
    return *(long double *)&b;
}

double
ldexp(double value, int exp)
{
    return __lc_ldexpl(value, exp);
}
