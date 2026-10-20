/* long_mods.c -- signed 32-bit modulo, taken from the divide's own remainder.
 *
 * _fcc_long_mods used to compute `dvd - (dvd / dvr) * dvr': a 32-bit divide,
 * then a 32-bit multiply, then a 32-bit subtract, to recover a value the
 * divide's restoring loop had already produced and left in
 * _fcc_long_div_rem_*.  _fcc_long_modu was fixed to read it; the signed one
 * was not.
 *
 * K&R 2nd ed A.7.6 (p.166) is what pins the answer.  It does NOT say which
 * sign a remainder takes -- "if both operands are non-negative, then the
 * remainder is non-negative and smaller than the divisor, if not, it is
 * guaranteed only that the absolute value of the remainder is smaller than the
 * absolute value of the divisor".  What it does fix is the identity: "it is
 * always true that (a/b)*b + a%b is equal to a".  Since _fcc_long_divs
 * truncates toward zero, that identity FORCES the remainder's sign to be the
 * dividend's -- so the sign is not a free choice, and the identity is the
 * assertion this fixture leans on.
 *
 * THE SIGN MUST COME FROM THE DIVIDEND, NOT THE QUOTIENT.  divs tracks
 * _fcc_long_div_negq, the XOR of the two operands' signs; using it would be
 * right for three sign combinations and wrong for the fourth -- a positive
 * dividend with a negative divisor.  Cases 7-9 and 13-15 are that quadrant.
 *
 * Values straddle the 16-bit boundary so the arithmetic is genuinely 32-bit.
 * Operands come from globals so nothing folds.  Returns the first failing
 * case, or 42. */

long a, b, q, r;

int main()
{
    /* ---- both non-negative ---- */
    a = 100L;      b = 7L;   r = a % b;  if (r != 2L)        return 1;
    a = 100000L;   b = 7L;   r = a % b;  if (r != 5L)        return 2;
    a = 100000L;   b = 1000L; r = a % b; if (r != 0L)        return 3;
    a = 7L;        b = 100L; r = a % b;  if (r != 7L)        return 4;
    a = 0L;        b = 5L;   r = a % b;  if (r != 0L)        return 5;
    a = 2147483647L; b = 1000L; r = a % b; if (r != 647L)    return 6;

    /* ---- positive dividend, NEGATIVE divisor: the quadrant a quotient-signed
     * remainder gets wrong.  Truncation gives 100/-7 = -14, so
     * 100 - (-14 * -7) = 100 - 98 = 2, POSITIVE. ---- */
    a = 100L;      b = -7L;  r = a % b;  if (r != 2L)        return 7;
    a = 100000L;   b = -7L;  r = a % b;  if (r != 5L)        return 8;
    a = 100000L;   b = -1000L; r = a % b; if (r != 0L)       return 9;

    /* ---- negative dividend: the remainder follows IT ---- */
    a = -100L;     b = 7L;   r = a % b;  if (r != -2L)       return 10;
    a = -100000L;  b = 7L;   r = a % b;  if (r != -5L)       return 11;
    a = -7L;       b = 100L; r = a % b;  if (r != -7L)       return 12;

    /* ---- both negative ---- */
    a = -100L;     b = -7L;  r = a % b;  if (r != -2L)       return 13;
    a = -100000L;  b = -7L;  r = a % b;  if (r != -5L)       return 14;
    a = -2147483647L; b = -1000L; r = a % b; if (r != -647L) return 15;

    /* ---- A.7.6's identity, asserted directly, in all four quadrants ---- */
    a = 123456L;  b = 789L;  q = a / b; r = a % b; if (q * b + r != a) return 16;
    a = 123456L;  b = -789L; q = a / b; r = a % b; if (q * b + r != a) return 17;
    a = -123456L; b = 789L;  q = a / b; r = a % b; if (q * b + r != a) return 18;
    a = -123456L; b = -789L; q = a / b; r = a % b; if (q * b + r != a) return 19;

    /* ---- ...and |a%b| < |b|, the other half of what A.7.6 guarantees ---- */
    a = -123456L; b = -789L; r = a % b; if (r <= -789L || r > 0L)  return 20;
    a = 123456L;  b = -789L; r = a % b; if (r >= 789L || r < 0L)   return 21;

    /* ---- a divisor of 1 and of the dividend itself ---- */
    a = 123456L;  b = 1L;    r = a % b; if (r != 0L)         return 22;
    a = -123456L; b = 1L;    r = a % b; if (r != 0L)         return 23;
    a = 123456L;  b = 123456L; r = a % b; if (r != 0L)       return 24;

    /* ---- divisor zero: A.7.6 leaves it undefined, and this returns the
     * dividend.  Asserted so the documented answer cannot drift silently. ---- */
    a = 12345L;   b = 0L;    r = a % b; if (r != 12345L)     return 25;

    return 42;
}
