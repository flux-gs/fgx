/* B-6 Phase 3: printf %f (float -> decimal string via pf_emit_float, which
 * calls the softfloat runtime).  Covers the milestone 3.14, an integral
 * value, explicit precision, a negative, and a multi-digit integer part.
 * Returns 42 iff every conversion matches. */
#include <stdio.h>

char buf[32];

int streq(char *s, char *t)
{
    int i;
    i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];          /* both reached NUL together */
}

int main(void)
{
    sprintf(buf, "%f", 3.14);
    if (!streq(buf, "3.140000"))  return 1;

    sprintf(buf, "%f", 2.0);
    if (!streq(buf, "2.000000"))  return 2;

    sprintf(buf, "%.2f", 3.14159);
    if (!streq(buf, "3.14"))      return 3;

    sprintf(buf, "%f", -1.5);
    if (!streq(buf, "-1.500000")) return 4;

    sprintf(buf, "%.3f", 0.5);
    if (!streq(buf, "0.500"))     return 5;

    sprintf(buf, "%f", 42.0);
    if (!streq(buf, "42.000000")) return 6;

    /* PRECISION ZERO SUPPRESSES THE DECIMAL POINT.  K&R 2nd ed B.1.2, p.203,
     * on `f': "The default precision is 6; a precision of 0 suppresses the
     * decimal point."  The point was emitted unconditionally until 2026-09-05,
     * so these five printed "52.", "53.", "0." and "5.e+01" -- found in df(1)'s
     * capacity column, which is `%5.0f%%' and showed `52.%'.
     *
     * THE CASES ABOVE COULD NOT HAVE CAUGHT IT: every one has a non-zero
     * precision, explicit or defaulted, so every one wants the point. */
    sprintf(buf, "%.0f", 52.4);
    if (!streq(buf, "52"))        return 7;

    sprintf(buf, "%.0f", 0.4);
    if (!streq(buf, "0"))         return 8;

    /* ...AND THE OTHER HALF OF THE SAME PAIR, WHICH ROUNDS.  This case said
     * "52" until 2026-09-06 and called it "the rounding-free truncation
     * upstream specifies" -- a claim about 2.11BSD that the tree contradicts.
     * printf's float path there is
     * vendor/2.11BSD/usr/lib/libc/pdp/stdio/fltpr.s, which calls
     * _ecvt/_fcvt/_gcvt, and cvt() in
     * vendor/2.11BSD/usr/lib/libc/pdp/gen/ecvt.c ends with `*p1 += 5;' and a
     * carry loop -- round-half-up on the digit string, the carry reaching the
     * integer part.  So 52.9 at %.0f is "53" there.
     *
     * The two cases are kept adjacent because 52.4 and 52.9 are the pair that
     * tells the two policies apart: truncation prints "52" for both. */
    sprintf(buf, "%.0f", 52.9);
    if (!streq(buf, "53"))        return 9;

    /* The suppression sentence governs %e too, and that arm was fixed with it. */
    sprintf(buf, "%.0e", 52.0);
    if (!streq(buf, "5e+01"))     return 10;

    /* AND SO DOES THE ROUNDING, which is what this case is really for: 52.0
     * normalises to 52.0/10 = 5.19999980926 in a float32, so a truncating
     * mantissa loop prints "5.1e+01".  It did, from the day this case was
     * written until 2026-09-06 -- the case was added while the runtime oracle
     * could not boot, so nothing ran it. */
    sprintf(buf, "%.1e", 52.0);
    if (!streq(buf, "5.2e+01"))   return 11;

    /* The carry out of the mantissa, which cvt() spells `*p1 = '1';
     * (*decpt)++'.  Rounding 9.99 at one decimal makes it ten, and the
     * exponent has to absorb that or the answer reads "10.0e+00". */
    sprintf(buf, "%.1e", 9.99);
    if (!streq(buf, "1.0e+01"))   return 12;

    /* The same carry in %f, where it walks into the integer part instead. */
    sprintf(buf, "%.1f", 9.99);
    if (!streq(buf, "10.0"))      return 13;

    return 42;
}
