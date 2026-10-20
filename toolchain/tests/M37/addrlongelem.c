/* addrlongelem.c -- `&arr[i]` where arr's element is a 4-byte scalar.
 * apple/fgx#191.
 *
 * `&ac[i]` (char), `&ai[i]` (int), `&as[i]` (a 6-byte struct) and `&p[i]` on a
 * `long *` all compiled.  `&al[i]` on a `long` ARRAY did not, with
 * "expected ')'".  The element TYPE is not a condition on the production --
 * K&R A.7.3.1:
 *
 *   "One of the two expressions must have type `pointer to T', where T is some
 *    type, and the other must have integral type; the type of the subscript
 *    expression is T."
 *
 * T is universally quantified; there is no list of element types a subscript
 * works for.  A.7.4.2 then fixes the result: "If the type of the operand is T,
 * the type of the result is `pointer to T.'"  LT_LONG_ARRAY and LT_FLOAT_ARRAY
 * were simply missing from the arm's type test, so the expression fell past it
 * with the '[' unread and the error named the paren instead of the operation.
 *
 * THE STRIDE IS WHAT THIS FILE IS REALLY FOR.  Adding the types to the test
 * without giving them an element size of 4 would compile every line below and
 * scale the index by 2 -- `&al[2]` landing in the middle of al[1], a wild
 * pointer of exactly the kind apple/fgx#166 was.  So every case here checks an
 * ADDRESS BY ITS EFFECT: it writes through the pointer and reads the array
 * back, including both neighbours, because a half-element error corrupts one
 * of them and leaves the target looking plausible.
 *
 * The int array beside it is not padding.  It shares the arm and its `es = 2`
 * is the value the long case would wrongly inherit, so a fix that set the
 * stride globally rather than per-type breaks the control and not the subject.
 *
 * NOT COVERED, and separate: `&arr2d[i][j]` still refuses, for EVERY element
 * type including int and char.  That is an element-type-independent gap in the
 * same arm and not this defect; it is filed on its own rather than asserted
 * here, since a case that cannot pass is not coverage.
 */

static long al[6];
static int  ai[6];

int main()
{
    long *ql;
    int  *qi;
    int   k;
    int   i;

    for (i = 0; i < 6; i++) {
        al[i] = 0x11110000L + i;
        ai[i] = 0x100 + i;
    }

    /* --- 50: the defect -- a CONSTANT index into a long array --------- */
    ql = &al[2];
    if (*ql != 0x11110002L) return (50);

    /* --- 51: the STRIDE, by effect.  A stride of 2 puts this write into
     * the middle of al[1] and leaves al[2] alone; a stride of 4 hits al[2]
     * and leaves both neighbours whole. -------------------------------- */
    *ql = 0x7A6B5C4DL;
    if (al[2] != 0x7A6B5C4DL) return (51);
    if (al[1] != 0x11110001L) return (52);   /* scaled short */
    if (al[3] != 0x11110003L) return (53);   /* scaled long, or wrote 8 bytes */
    al[2] = 0x11110002L;

    /* --- 54: the HIGH WORD specifically, so a pointer that is right but
     * only 16 bits wide is caught ------------------------------------- */
    ql = &al[4];
    if ((int)(*ql >> 16) != 0x1111) return (54);
    if ((int)(*ql & 0xFFFFL) != 4) return (55);

    /* --- 56: a VARIABLE index, which is the shape a loop uses --------- */
    k = 3;
    ql = &al[k];
    if (*ql != 0x11110003L) return (56);
    k = 0;
    ql = &al[k];
    if (*ql != 0x11110000L) return (57);

    /* --- 58: element 0, where a wrong stride multiplies to zero and the
     * case would pass whatever the stride is if it stood alone --------- */
    ql = &al[0];
    if (*ql != 0x11110000L) return (58);

    /* --- 59: the int array through the SAME arm, unchanged ------------ */
    qi = &ai[2];
    if (*qi != 0x102) return (59);
    *qi = 0x333;
    if (ai[2] != 0x333) return (60);
    if (ai[1] != 0x101) return (61);
    if (ai[3] != 0x103) return (62);

    return (42);
}
