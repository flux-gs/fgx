/* addrarrfieldidx.c -- `&structarray[i].arrayfield[j]'.  apple/fgx#202.
 *
 * AN ARTIFICIAL REJECT, and the neighbours are what prove it: `&one.arr[j]'
 * (struct-var base), `&p->arr[j]' (pointer base), `&g.inner.arr[j]' (nested
 * dot) and BOTH the read and store twins of `arr[i].arr[j]' all compiled.
 * Only the struct-ARRAY base lacked the arm -- the address-of production
 * built the field's address and then left the `[' unread, so it surfaced at
 * the statement parser as "expected ';'".  Same one-hop-further-out shape as
 * apple/fgx#207's second cell, same twin rule as #155.
 *
 * K&R A.7.3.1: "A postfix expression followed by an expression in square
 * brackets is a postfix expression denoting a subscripted array reference ...
 * E1[E2] is identical (by definition) to *((E1)+(E2))"; A.7.4.2 makes `&' of
 * that the pointer.  Neither conditions the result on how E1 was spelled.
 *
 * THE ADDRESS IS ASSERTED BY USING IT, not by compiling it.  Every case here
 * writes THROUGH the pointer and reads back through the ORDINARY subscript
 * path -- the one that already worked -- so the two spellings have to agree
 * about where the element is.  A parse fix that computed a plausible wrong
 * address would compile, and comparing it against nothing would pass.
 *
 * THE ELEMENT SIZE IS THE FIELD'S, NOT THE OUTER ARRAY'S, and that is the
 * arithmetic most likely to be got wrong: `struct e' is bigger than the
 * `long' its arr[] holds, so scaling j by the wrong one lands inside a
 * different element entirely.  The neighbours are checked for exactly that.
 *
 * Exit 42.
 */

struct e {
    int   pad;
    long  arr[4];
    int   tail;
};

struct sm {
    int   q;
    int   r;
};

struct hs {
    int        pad;
    struct sm  sa[3];
    int        tail;
};

struct e   earr[3];
struct hs  harr[2];

int
main()
{
    long      *lp;
    struct sm *smp;
    struct e  *ep;
    int        i, j;

    /* ---- 1: a clean slate, written through the ordinary path. */
    for (i = 0; i < 3; i++) {
        earr[i].pad  = 0x1111;
        earr[i].tail = 0x2222;
        for (j = 0; j < 4; j++)
            earr[i].arr[j] = 0L;
    }

    /* ---- 2: write through the pointer, read back through the subscript.
     * i and j are VARIABLES, so the index arithmetic runs rather than being
     * folded -- a constant-only test would not exercise the scale at all. */
    i = 1; j = 2;
    lp = &earr[i].arr[j];
    *lp = 0x44332211L;
    if (earr[1].arr[2] != 0x44332211L)  return (2);

    /* ---- 3: AND NOTHING ELSE MOVED.  Scaling j by the OUTER element size
     * instead of the field's lands in a different struct, and every check on
     * the target alone would miss it. */
    if (earr[1].arr[0] != 0L)           return (3);
    if (earr[1].arr[3] != 0L)           return (4);
    if (earr[0].arr[2] != 0L)           return (5);
    if (earr[2].arr[2] != 0L)           return (6);
    if (earr[1].pad != 0x1111)          return (7);
    if (earr[1].tail != 0x2222)         return (8);

    /* ---- 10: THE FIRST AND LAST ELEMENTS of the field, where an off-by-one
     * in the field offset shows as a write into pad or tail. */
    i = 0; j = 0;
    lp = &earr[i].arr[j];
    *lp = 0x0A0B0C0DL;
    if (earr[0].arr[0] != 0x0A0B0C0DL)  return (10);
    if (earr[0].pad != 0x1111)          return (11);

    i = 2; j = 3;
    lp = &earr[i].arr[j];
    *lp = 0x0E0F1011L;
    if (earr[2].arr[3] != 0x0E0F1011L)  return (12);
    if (earr[2].tail != 0x2222)         return (13);

    /* ---- 20: THE POINTER ITSELF AGREES with the one the working spellings
     * produce.  `ep->arr' is the pointer-base twin, which compiled all along;
     * if the two disagree, one of them is computing a different object. */
    i = 1;
    ep = &earr[i];
    lp = &earr[i].arr[3];
    if (lp != &ep->arr[3])              return (20);

    /* ---- 30: A STRUCT-typed array field, where the scale is the inner
     * struct's size rather than a scalar's. */
    /* Zeroed THROUGH A POINTER, because `harr[i].sa[j].q = 0' -- a scalar
     * store past a struct-array field of a struct-array element -- is itself
     * refused ("expected '='").  A separate production from the address-of
     * one under test here, and it fails closed; spelled the way that compiles
     * rather than widened in a fixture for something else. */
    for (i = 0; i < 2; i++) {
        harr[i].pad  = 0x3333;
        harr[i].tail = 0x4444;
        for (j = 0; j < 3; j++) {
            smp = &harr[i].sa[j];
            smp->q = 0;
            smp->r = 0;
        }
    }
    i = 1; j = 2;
    smp = &harr[i].sa[j];
    smp->q = 0x5555;
    smp->r = 0x6666;

    /* READ BACK THROUGH A SECOND, INDEPENDENTLY FORMED POINTER, because
     * `harr[1].sa[2].q' as a READ is refused as well ("expected ')'") -- the
     * same production family, also failing closed.  Constant indices here
     * against the variable ones above, so the two pointers are computed by
     * different paths and agreeing is evidence. */
    smp = &harr[1].sa[2];
    if (smp->q != 0x5555)               return (30);
    if (smp->r != 0x6666)               return (31);
    smp = &harr[1].sa[0];
    if (smp->q != 0)                    return (32);
    smp = &harr[1].sa[1];
    if (smp->q != 0)                    return (33);
    smp = &harr[0].sa[2];
    if (smp->q != 0)                    return (34);
    if (harr[1].pad != 0x3333)          return (35);
    if (harr[1].tail != 0x4444)         return (36);

    return (42);
}
