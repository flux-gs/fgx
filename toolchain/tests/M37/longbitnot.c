/* longbitnot.c -- `~' on a long inverts BOTH words.  apple/fgx#209.
 *
 * IT INVERTED ONLY THE LOW ONE.  N_BNOT was typed LT_INT unconditionally --
 * the comment beside it said "helper forces int" -- so a long operand reached
 * an emitter that was a bare `EOR #$FFFF' on A with _fcc_long_hi passed
 * through untouched.  ~0x00800000L came out as 0x0080FFFF.
 *
 * WHICH MEANS `x &= ~MASK' CLEARED NOTHING ABOVE BIT 15, silently, and only
 * for masks whose bits are up there.  A low-word mask inverts to the right
 * 32-bit value BY ACCIDENT -- ~0x00000001L needs high = 0xFFFF and passing
 * 0x0000 through then EOR-ing nothing still leaves... no: it leaves 0x0000,
 * which is wrong too, and the reason no caller noticed is subtler.  Every
 * existing `&= ~' in this tree is on an `unsigned short' field with a
 * short-typed mask, so the long path was never entered at all.  The first
 * caller to enter it is 2.11BSD's tty.c, whose t_flags is a long and whose
 * FLUSHO is 0x00800000L (apple/fgx#108 T3).
 *
 * K&R A.7.4.6: "The result of the ~ operator is the 1's complement of its
 * operand.  The usual arithmetic conversions are performed.  The type of the
 * operand must be integral."  The 1's complement OF THE OPERAND -- and the
 * usual arithmetic conversions (A.6.5) do not narrow a long to its low word.
 * N_NEG, three lines above N_BNOT in the parser, propagates LT_LONG and always
 * has; this is apple/fgx#155's pairs rule with the two arms adjacent.
 *
 * THE CASES ARE SPLIT BY WHERE THE BITS ARE, because that is what decides
 * whether the bug shows: a mask in the HIGH word is the one that fails, and a
 * test that only used low-word masks would pass against the broken compiler.
 *
 * Exit 42.
 */

long  hv;
long  lo;
unsigned short sh;

int
main()
{
    long r;

    /* ---- 1: the value of ~ itself, high word and low. */
    r = ~0x00800000L;
    if (r != (long)0xFF7FFFFF)  return (1);
    r = ~0x00000001L;
    if (r != (long)0xFFFFFFFE)  return (2);

    /* ---- 10: masking with it.  A HIGH-word bit must clear. */
    hv = 0x00800010L;
    hv = hv & ~0x00800000L;
    if (hv != 0x00000010L)      return (10);

    hv = 0x00800010L;
    hv &= ~0x00800000L;                       /* the compound twin */
    if (hv != 0x00000010L)      return (11);

    /* ---- 12: A LOW-word bit still clears -- the control.  This case passes
     * against the broken compiler, which is exactly why case 10 exists. */
    lo = 0x00800010L;
    lo &= ~0x00000010L;
    if (lo != 0x00800000L)      return (12);

    /* ---- 20: ~ OF A VARIABLE, not just a folded constant.  The emitter and
     * the constant folder are different code and only one of them was the
     * fault; a fix to either alone leaves the other. */
    hv = 0x00800000L;
    r = ~hv;
    if (r != (long)0xFF7FFFFF)  return (20);

    hv = 0x0F0F0F0FL;
    r = ~hv;
    if (r != (long)0xF0F0F0F0)  return (21);

    /* ---- 30: A MULTI-BIT MASK SPANNING BOTH WORDS, which is tty.c's
     * TS_LOCAL shape (TS_ERASE|TS_LNCH|TS_TYPEN|TS_CNTTB = 0x003C0000). */
    hv = 0x003C00FFL;
    hv &= ~0x003C0000L;
    if (hv != 0x000000FFL)      return (30);

    /* ---- 40: ~ ON AN int IS UNCHANGED, the control for the other side of
     * the type test.  A fix that made every ~ long would break this. */
    sh = 0x00F0;
    sh = sh & ~0x000FU;
    if (sh != 0x00F0)           return (40);

    return (42);
}
