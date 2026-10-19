/* typedefunsigned.c -- a typedef must carry its base type's SIGNEDNESS.
 *
 * `typedef unsigned int u_int' recorded only LT_INT: struct Typedef had a
 * base_type and no signedness, and a TWORD has nowhere to keep one.  So every
 * u_int, u_short and u_char in the ported tree compiled SIGNED while the same
 * declaration spelled out longhand compiled unsigned -- two spellings of one
 * type generating different code.
 *
 * IT IS SILENT UNTIL BIT 15 IS SET.  Below 32768 a signed and an unsigned int
 * hold the same value and every operation agrees, which is why nothing caught
 * it.  Above it they diverge on exactly the operations that consult the sign:
 * widening to long, comparison, division, right shift.
 *
 * fsck(8) is where it surfaced (apple/fgx#399).  `if ((off_t)msize < totsz)'
 * with msize a u_int of 34185 took the SIGNED widening helper, read
 * $FFFF8589 = -31351, and sent a filesystem whose maps fitted in memory down
 * the scratch-file path instead.
 *
 * EVERY CASE IS ASSERTED AGAINST ITS LONGHAND TWIN rather than against a
 * literal, which is what makes this a test of the TYPEDEF and not of unsigned
 * arithmetic: the two declarations name one type, so any operation that tells
 * them apart is the defect, whatever the right answer happens to be.
 *
 * Exit 42 = pass; every other code identifies the property that failed.
 */
typedef unsigned int   u_int;
typedef unsigned short u_short;
typedef unsigned char  u_char;
typedef long           off_t;

u_int   gt;                     /* via typedef, global */
unsigned int gd;                /* longhand, global   */

int main()
{
    u_int        at;            /* via typedef, local */
    unsigned int ad;            /* longhand, local    */
    u_short      st;
    unsigned short sd;
    u_char       ct;
    unsigned char cd;
    off_t        big;

    /* 1. WIDENING TO LONG -- the case fsck hit.  $8589 sign-extended is
     *    negative; zero-extended it is 34185. */
    at = 34185; ad = 34185;
    big = 24004L;
    if (((off_t)at < big) != ((off_t)ad < big))
        return (43);
    if ((off_t)at < big)
        return (44);            /* and the right answer is "no" */

    /* 2. The same through a GLOBAL, which reaches the defect by a different
     *    emit path (g->is_unsigned rather than lc->is_unsigned). */
    gt = 34185; gd = 34185;
    if (((off_t)gt < big) != ((off_t)gd < big))
        return (45);
    if ((off_t)gt < big)
        return (46);

    /* 3. COMPARISON against a plain int, no cast in sight. */
    at = 40000; ad = 40000;
    if ((at > 10) != (ad > 10))
        return (47);
    if (!(at > 10))
        return (48);

    /* 4. DIVISION, which picks a signed or unsigned helper by operand type. */
    at = 40000; ad = 40000;
    if (at / 100 != ad / 100)
        return (49);
    if (at / 100 != 400)
        return (50);

    /* 5. RIGHT SHIFT -- arithmetic versus logical. */
    at = 0x8000; ad = 0x8000;
    if ((at >> 4) != (ad >> 4))
        return (51);
    if (at >> 4 != 0x0800)
        return (52);

    /* 6. A CAST TO the typedef must be as unsigned as the longhand cast. */
    big = 40000L;
    if ((u_int)big != (unsigned int)big)
        return (53);

    /* 7. The narrower widths, which have their own promotion rules. */
    st = 40000; sd = 40000;
    if ((off_t)st != (off_t)sd)
        return (54);
    if ((off_t)st != 40000L)
        return (55);

    ct = 200; cd = 200;
    if ((int)ct != (int)cd)
        return (56);
    if ((int)ct != 200)
        return (57);

    return (42);
}
