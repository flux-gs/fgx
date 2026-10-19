/* arrfieldlong.c -- `p->structfield.longarray[i] = rhs`, the 4-byte element.
 *
 * THE ARM ACCEPTED int AND char ELEMENTS AND REFUSED long ONES, which had no
 * basis in the text.  K&R A.7.3.3 makes `p->arr` a non-lvalue precisely because
 * it IS an array ("the result is an lvalue if the type is not an array type"),
 * so the subscript decays it and the store goes through A.7.4.3's indirection:
 * "is an lvalue if the operand is a pointer to an object of arithmetic,
 * structure, union, or pointer type."  Neither paragraph says anything about
 * the ELEMENT type, and long is arithmetic exactly as int and char are.  The
 * 4-byte SCALAR leaf beside it in the same dispatch had already been fixed for
 * the same reason (apple/fgx#155's pairs rule); this is the array twin.
 *
 * Found writing UFS 1.12b's itrunc -- `oip->i_addr[NDADDR + level] = 0`, where
 * i_addr is 2.11BSD's on-disk daddr_t array, so the shape belongs to the format
 * and not to how the port was written.
 *
 * PARSING IS NOT THE PROPERTY UNDER TEST, and for this construct that matters
 * twice over.  A fix that merely stopped the error could still
 *
 *   - scale the index by 2 instead of 4, landing every store half an element
 *     low and clobbering the previous one's high word (apple/fgx#154's shape);
 *   - store only 16 bits, leaving the high word whatever the last write left;
 *   - or store an int RHS without promoting it, putting stack garbage in the
 *     high word -- which is why this assigns from an INT and not just from a
 *     long.
 *
 * MEASURED, and the third one is the reason case 59 exists.  With the
 * promotion deleted, the POSITIVE int case (57/58) stays GREEN: the high word
 * it failed to write happened to already be zero, so the wrong code produced
 * the right answer.  Only the NEGATIVE assignment discriminates, because
 * sign-extension cannot be arrived at by luck -- it fires at 59.  A fixture
 * with only the positive case would have been an inert test of a real defect.
 *
 * All three compile, and all three produce plausible small numbers.  So every
 * case writes a value whose HIGH word is non-zero and distinct, reads it back,
 * and checks both neighbours in the array are untouched.
 *
 * Exit 42 = pass; any other value identifies the case.  Numbered from 50 so no
 * failure can land on the pass code.
 */

struct inner {
    long    la[4];
    int     ia[4];
    char    ca[4];
};

struct outer {
    long          guard0;
    struct inner  in;
    long          guard1;
};

static struct outer ob;

int main()
{
    struct outer *p;
    int           i;
    int           k;

    p = &ob;

    /* --- everything starts known ------------------------------------- */
    p->guard0 = 0x11112222L;
    p->guard1 = 0x33334444L;
    for (i = 0; i < 4; i++) {
        p->in.la[i] = 0L;
        p->in.ia[i] = 0;
        p->in.ca[i] = 0;
    }

    /* --- 50: a constant long into the middle of the array ------------- */
    p->in.la[1] = 0x0A0B0C0DL;
    if (p->in.la[1] != 0x0A0B0C0DL)
        return (50);
    if (p->in.la[0] != 0L)
        return (51);            /* scaled short: it landed one element low */
    if (p->in.la[2] != 0L)
        return (52);            /* scaled long, or wrote 8 bytes */

    /* --- 53: the HIGH WORD specifically ------------------------------- */
    if ((int)(p->in.la[1] >> 16) != 0x0A0B)
        return (53);            /* a 16-bit store leaves this wrong */
    if ((int)(p->in.la[1] & 0xFFFFL) != 0x0C0D)
        return (54);

    /* --- 55: a VARIABLE index, which is the itrunc shape -------------- */
    k = 3;
    p->in.la[k] = 0x7E6D5C4BL;
    if (p->in.la[3] != 0x7E6D5C4BL)
        return (55);
    if (p->in.la[2] != 0L)
        return (56);

    /* --- 57: an INT rhs must PROMOTE, not leave garbage high ---------- */
    i = 0x1234;
    p->in.la[0] = i;
    if (p->in.la[0] != 0x00001234L)
        return (57);
    if ((int)(p->in.la[0] >> 16) != 0)
        return (58);            /* unpromoted: stack garbage in the high word */

    /* --- 59: a NEGATIVE int rhs sign-extends -------------------------- */
    i = -2;
    p->in.la[2] = i;
    if (p->in.la[2] != -2L)
        return (59);

    /* --- 60: the int and char arrays beside it still work ------------- */
    p->in.ia[2] = 0x4321;
    if (p->in.ia[2] != 0x4321)
        return (60);
    if (p->in.ia[1] != 0 || p->in.ia[3] != 0)
        return (61);
    p->in.ca[1] = (char)0x5A;
    if (p->in.ca[1] != (char)0x5A)
        return (62);
    if (p->in.ca[0] != (char)0 || p->in.ca[2] != (char)0)
        return (63);

    /* --- 64: NOTHING outside the inner struct moved ------------------- */
    if (p->guard0 != 0x11112222L)
        return (64);
    if (p->guard1 != 0x33334444L)
        return (65);

    /* --- 66: and the whole array reads back as written ---------------- */
    if (p->in.la[0] != 0x00001234L)
        return (66);
    if (p->in.la[1] != 0x0A0B0C0DL)
        return (67);
    if (p->in.la[2] != -2L)
        return (68);
    if (p->in.la[3] != 0x7E6D5C4BL)
        return (69);

    return (42);
}
