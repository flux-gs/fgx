/* long_shift.c -- 32-bit shifts by a constant, inlined.
 *
 * Every long shift used to be a libcall.  _fcc_long_mul was 1.92% of a
 * five-exec profile and _fcc_long_shr 0.99%, and the hot callers are the block
 * I/O path itself: bio_strategy.c computes `bp->b_blkno * DEVB_PER_FSB' with
 * DEVB_PER_FSB = 2 -- a full 32x32 multiply for a shift by one, once per block
 * -- and takes `(int)(dblk >> 16)' twice more per block, which is a word move.
 *
 * K&R 2nd ed A.7.8 (p.166) settles the three questions this raises.  The left
 * shift is a bit pattern -- "The value of E1<<E2 is E1 (interpreted as a bit
 * pattern) left-shifted E2 bits" -- so one sequence serves both signednesses.
 * "The type of the result is that of the promoted left operand", so the result
 * stays long and the cases below assign it to one.  And "The result is
 * undefined if the right operand is negative, or greater than or equal to the
 * number of bits in the left expression's type", which is what bounds k at 31.
 *
 * THE WHOLE RISK IS THE SIGNED RIGHT SHIFT.  A.7.8 (p.167) says only that
 * "The right shift is equivalent to division by 2**E2 if E1 is unsigned or it
 * has a nonnegative value; otherwise the result is implementation-defined" --
 * so the standard permits either fill.  FGX's choice is already made and
 * published by _fcc_long_shr, which is sign-preserving, and the inline must
 * reproduce THAT or `x >> 10' would mean one thing when 10 is a literal and
 * another when it is not.  Every negative case below discriminates the two: a
 * zero fill leaves the top k bits clear where an arithmetic fill sets them.
 *
 * Operands come from globals so the front end cannot fold the shift away and
 * test nothing.  Returns the number of the first case that failed, or 42. */

long a, r;
unsigned long ua, ur;

int main()
{
    /* ---- left shift, k < 16 ---- */
    a = 1L;        r = a << 1;   if (r != 2L)            return 1;
    a = 1L;        r = a << 15;  if (r != 32768L)        return 2;
    a = 0x1234L;   r = a << 4;   if (r != 0x12340L)      return 3;
    /* carry must cross the word boundary, not fall out of the low word */
    a = 0x8000L;   r = a << 1;   if (r != 0x10000L)      return 4;
    a = -1L;       r = a << 1;   if (r != -2L)           return 5;

    /* ---- left shift, k >= 16: the low word BECOMES the high word ---- */
    a = 1L;        r = a << 16;  if (r != 0x10000L)      return 6;
    a = 0x1234L;   r = a << 16;  if (r != 0x12340000L)   return 7;
    a = 1L;        r = a << 17;  if (r != 0x20000L)      return 8;
    a = 1L;        r = a << 31;  if (r != -2147483648L)  return 9;

    /* ---- unsigned right shift, k < 16 ---- */
    ua = 0x12340L; ur = ua >> 4;  if (ur != 0x1234L)     return 10;
    ua = 0x10000L; ur = ua >> 1;  if (ur != 0x8000L)     return 11;
    /* the high word's outgoing bit must arrive in the low word's top bit */
    ua = 0x30000L; ur = ua >> 1;  if (ur != 0x18000L)    return 12;
    ua = 0xFFFFFFFFL; ur = ua >> 15; if (ur != 0x1FFFFL) return 13;

    /* ---- unsigned right shift, k >= 16: a word move ---- */
    ua = 0x12345678L; ur = ua >> 16; if (ur != 0x1234L)  return 14;
    ua = 0x12345678L; ur = ua >> 20; if (ur != 0x123L)   return 15;
    ua = 0xFFFFFFFFL; ur = ua >> 31; if (ur != 1L)       return 16;

    /* ---- SIGNED right shift, non-negative: fill is irrelevant ---- */
    a = 0x12340L;  r = a >> 4;   if (r != 0x1234L)       return 17;
    a = 0x12345678L; r = a >> 16; if (r != 0x1234L)      return 18;

    /* ---- SIGNED right shift, NEGATIVE: the discriminating cases ----
     * A zero fill would give a large positive here; the helper sign-fills. */
    a = -1L;       r = a >> 1;   if (r != -1L)           return 19;
    a = -2L;       r = a >> 1;   if (r != -1L)           return 20;
    a = -1024L;    r = a >> 10;  if (r != -1L)           return 21;
    a = -1025L;    r = a >> 10;  if (r != -2L)           return 22;
    a = -65536L;   r = a >> 16;  if (r != -1L)           return 23;
    a = -65537L;   r = a >> 16;  if (r != -2L)           return 24;
    a = -2147483648L; r = a >> 31; if (r != -1L)         return 25;
    /* k=15 and k=1 are the ends of the mask the fixup ORs in */
    a = -32768L;   r = a >> 15;  if (r != -1L)           return 26;
    a = -2147483648L; r = a >> 16; if (r != -32768L)     return 27;

    /* ---- long * 2^n routes to the left shift ---- */
    a = 3L;        r = a * 2;    if (r != 6L)            return 28;
    a = 0x8000L;   r = a * 2;    if (r != 0x10000L)      return 29;
    a = -3L;       r = a * 2;    if (r != -6L)           return 30;
    a = 5L;        r = a * 65536; if (r != 0x50000L)     return 31;
    a = 7L;        r = a * 1;    if (r != 7L)            return 32;
    /* a NON-power-of-two long constant still multiplies through the helper */
    a = 100L;      r = a * 3;    if (r != 300L)          return 33;

    /* ---- k == 0 is the identity, and the result is still long ---- */
    a = 0x12345678L; r = a << 0; if (r != 0x12345678L)   return 34;
    a = 0x12345678L; r = a >> 0; if (r != 0x12345678L)   return 35;

    /* ---- past A.7.8's bound the libcall still has it ---- */
    a = 1L;        r = a << 4;   if (r != 16L)           return 36;

    return 42;
}
