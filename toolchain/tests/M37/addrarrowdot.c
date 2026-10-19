/* addrarrowdot.c -- `&p->m.n', address-of a member reached by a DOT after an
 * ARROW, through a pointer base.  apple/fgx#212.
 *
 * AN ARTIFICIAL REJECT: it died "expected ')'" at the dot.  The neighbours are
 * what prove it -- `&p->FLAT' (the same thing one hop shorter), `&v.M.L' (the
 * same depth off a struct VARIABLE) and the plain read `p->M.L.b' at that
 * depth all compiled.  The address-of production consumed a fixed-shape PREFIX
 * of the suffix run and returned with the rest unread.
 *
 * THREE SILENT SIBLINGS came out of the variant matrix and none was in the
 * issue: `&h->tp->w' (two arrows, bare leaf) died a different death -- "addr-of
 * chain requires an index '['"; `&p->MA[i].z' (arrow, subscript, dot) died the
 * first one; and the struct-VARIABLE twin `&v.MA[i].z' died it too, found only
 * because this fixture used it as a trusted cross-check.  Same fault in every
 * case -- an arm consuming a fixed-shape prefix of the run -- so all are here.
 *
 * K&R p.164 A.7.4 gives `unary-expression: postfix expression', and the p.198
 * grammar makes `postfix-expression.identifier' itself a postfix-expression --
 * so the whole run is ONE operand however deep it goes.  A.7.3.3 supplies the
 * lvalue: "The result refers to the named member of the structure or union to
 * which the pointer expression points, and the type is the type of the member;
 * the result is an lvalue if the type is not an array type."  A.7.4.2 puts no
 * bound on how that lvalue was reached: "The unary operator & takes the address
 * of its operand.  The operand must be an lvalue referring neither to a
 * bit-field nor to an object declared as register."  Depth is not an exception.
 *
 * THE ADDRESS IS ASSERTED BY USING IT, not by compiling it -- apple/fgx#202's
 * first cut compiled and computed a WRONG address, and its acceptance matrix
 * passed.  Every case here does both of:
 *
 *   (a) compares the `&'-derived pointer against the SAME object addressed
 *       through a spelling that already worked (`&gt.M.L' on the struct
 *       variable, with p == &gt), so a plausible-but-wrong offset is caught
 *       even before anything is written; and
 *   (b) writes THROUGH the pointer and reads back through the ordinary member
 *       path, then checks the NEIGHBOURS on both sides are untouched -- a wrong
 *       parent offset emits a perfectly good store into the wrong member, and
 *       only the neighbour check sees that.
 *
 * The guards bracket every target, so a store that lands one member early or
 * one late is a failed row rather than a silent pass.  Indices are VARIABLES so
 * the scale arithmetic actually runs.
 *
 * Exit 42.
 */

struct leaf {
    int   g_lo;
    long  v;
    int   g_hi;
};

struct mid {
    int          g_lo;
    struct leaf  L;
    int          z;
    char         arr[4];
    int          g_hi;
};

struct top {
    int         g_lo;
    struct mid  M;
    int         w;
    struct mid  MA[3];
    int         g_hi;
};

struct hop {
    int          g_lo;
    struct top  *tp;
    struct mid   HM;
    int          g_hi;
};

struct top gt;
struct hop gh;

/* Reset every guard and every target to a known pattern, through the ordinary
 * member path only -- the path that worked before the fix. */
static
clear()
{
    int i;

    gt.g_lo = 0x7A7A;  gt.g_hi = 0x7B7B;  gt.w = 0x7C7C;
    gt.M.g_lo = 0x1010;  gt.M.g_hi = 0x1011;  gt.M.z = 0x1012;
    gt.M.L.g_lo = 0x2020;  gt.M.L.g_hi = 0x2021;  gt.M.L.v = 0L;
    for (i = 0; i < 4; i++)
        gt.M.arr[i] = 0x30 + i;
    for (i = 0; i < 3; i++) {
        gt.MA[i].g_lo = 0x4040 + i;
        gt.MA[i].g_hi = 0x4050 + i;
        gt.MA[i].z    = 0x4060 + i;
        /* NOT `gt.MA[i].L.v = 0L' -- a STORE two dots deep through an array
         * element is its own reject ("LHS subfield must be scalar", and it
         * fails for an `int' leaf too, so it is not about the long).  A
         * separate defect, kept out of this fixture so this one stays about
         * the address-of run; case 6 writes its own target and does not need
         * a cleared baseline. */
    }
    gh.g_lo = 0x5A5A;  gh.g_hi = 0x5B5B;
    gh.HM.g_lo = 0x6060;  gh.HM.g_hi = 0x6061;  gh.HM.z = 0x6062;
    gh.tp = &gt;
}

int
main()
{
    struct top  *p;
    struct hop  *h;
    struct leaf *lp;
    long        *vp;
    int         *ip;
    char        *cp;
    int          i, j;
    int          r;

    r = 0;
    p = &gt;
    h = &gh;

    /* ---- 1: `&p->M.L' -- the reported shape, a STRUCT-typed member reached
     * by a dot after the arrow.  Cross-checked against `&gt.M.L', the struct-
     * variable spelling that already compiled. */
    clear();
    lp = &p->M.L;
    if (lp == &gt.M.L) {
        lp->v = 0x11223344L;
        if (gt.M.L.v == 0x11223344L &&
            gt.M.L.g_lo == 0x2020 && gt.M.L.g_hi == 0x2021 &&
            gt.M.g_lo == 0x1010 && gt.M.z == 0x1012 && gt.M.g_hi == 0x1011 &&
            gt.g_lo == 0x7A7A && gt.w == 0x7C7C && gt.g_hi == 0x7B7B)
            r += 4;
    }

    /* ---- 2: `&p->M.z' -- the SCALAR twin, so the reject was never about the
     * member's type. */
    clear();
    ip = &p->M.z;
    if (ip == &gt.M.z) {
        *ip = 0x0BAD;
        if (gt.M.z == 0x0BAD &&
            gt.M.g_lo == 0x1010 && gt.M.g_hi == 0x1011 &&
            gt.M.L.g_hi == 0x2021 && gt.M.arr[0] == 0x30 &&
            gt.w == 0x7C7C)
            r += 4;
    }

    /* ---- 3: `&p->M.L.v' -- TWO dots after the arrow.  The depth is what the
     * run has to reach; stopping one hop short lands on L's guard. */
    clear();
    vp = &p->M.L.v;
    if (vp == &gt.M.L.v) {
        *vp = 0x7EEDBEEFL;
        if (gt.M.L.v == 0x7EEDBEEFL &&
            gt.M.L.g_lo == 0x2020 && gt.M.L.g_hi == 0x2021 &&
            gt.M.z == 0x1012)
            r += 4;
    }

    /* ---- 4: `&p->M.arr[j]' -- arrow, dot, then a SUBSCRIPT, with j a
     * variable so the index scale runs. */
    clear();
    j = 2;
    cp = &p->M.arr[j];
    if (cp == &gt.M.arr[2]) {
        *cp = 0x5F;
        if (gt.M.arr[2] == 0x5F &&
            gt.M.arr[1] == 0x31 && gt.M.arr[3] == 0x33 &&
            gt.M.z == 0x1012 && gt.M.g_hi == 0x1011)
            r += 4;
    }

    /* ---- 5: `&p->MA[i].z' -- arrow, SUBSCRIPT, then a dot.  The element
     * scale is `struct mid', and the neighbours on both sides are the check
     * that says so: scaling by anything else lands in one of them. */
    clear();
    i = 1;
    ip = &p->MA[i].z;
    if (ip == &gt.MA[1].z) {
        *ip = 0x0C0C;
        if (gt.MA[1].z == 0x0C0C &&
            gt.MA[0].z == 0x4060 && gt.MA[2].z == 0x4062 &&
            gt.MA[1].g_lo == 0x4041 && gt.MA[1].g_hi == 0x4051 &&
            gt.MA[0].g_hi == 0x4050 && gt.MA[2].g_lo == 0x4042)
            r += 4;
    }

    /* ---- 6: `&p->MA[i].L.v' -- and one hop further, so the dot run after the
     * subscript is not just one deep. */
    clear();
    i = 2;
    vp = &p->MA[i].L.v;
    if (vp == &gt.MA[2].L.v) {
        *vp = 0x0123FEDCL;
        if (gt.MA[2].L.v == 0x0123FEDCL &&
            gt.MA[2].z == 0x4062 && gt.MA[2].g_lo == 0x4042 &&
            gt.MA[1].g_hi == 0x4051)
            r += 4;
    }

    /* ---- 7: SIBLING ONE -- `&h->tp->w', two arrows and a BARE leaf.  This is
     * the one the arrow-chain loop refused outright because it demanded a
     * trailing index; it was not in the issue. */
    clear();
    ip = &h->tp->w;
    if (ip == &gt.w) {
        *ip = 0x0DAD;
        if (gt.w == 0x0DAD &&
            gt.g_lo == 0x7A7A && gt.g_hi == 0x7B7B &&
            gt.M.g_hi == 0x1011 && gt.MA[0].g_lo == 0x4040)
            r += 4;
    }

    /* ---- 8: `&h->tp->M.z' -- two arrows AND a dot, both faults at once. */
    clear();
    ip = &h->tp->M.z;
    if (ip == &gt.M.z) {
        *ip = 0x0E0E;
        if (gt.M.z == 0x0E0E &&
            gt.M.g_lo == 0x1010 && gt.M.g_hi == 0x1011 && gt.w == 0x7C7C)
            r += 4;
    }

    /* ---- 9: `&h->HM.z' -- arrow into an EMBEDDED struct then a dot, on a
     * different base, so case 1 is not carrying the whole family. */
    clear();
    ip = &h->HM.z;
    if (ip == &gh.HM.z) {
        *ip = 0x0F0F;
        if (gh.HM.z == 0x0F0F &&
            gh.HM.g_lo == 0x6060 && gh.HM.g_hi == 0x6061 &&
            gh.g_lo == 0x5A5A && gh.g_hi == 0x5B5B &&
            gh.tp == &gt)
            r += 4;
    }

    /* ---- 10: THE STRUCT-VARIABLE TWIN -- `&gt.MA[i].z', a dot after a
     * subscript on a struct VARIABLE base.  It rejected in its own right, and
     * it was found only because cases 5 and 6 above used it as their trusted
     * cross-check.  It gets its own value assertion here rather than resting on
     * that comparison: two arms agreeing is weaker than each being checked. */
    clear();
    i = 2;
    ip = &gt.MA[i].z;
    *ip = 0x1A1A;
    if (gt.MA[2].z == 0x1A1A &&
        gt.MA[1].z == 0x4061 && gt.MA[0].z == 0x4060 &&
        gt.MA[2].g_lo == 0x4042 && gt.MA[2].g_hi == 0x4052 &&
        gt.MA[1].g_hi == 0x4051)
        r += 3;

    /* ---- 11: `&gh.tp->w' -- an ARROW after a dot, the mixed run in the other
     * order, again on a struct-variable base. */
    clear();
    ip = &gh.tp->w;
    if (ip == &gt.w) {
        *ip = 0x1B1B;
        if (gt.w == 0x1B1B &&
            gt.g_lo == 0x7A7A && gt.g_hi == 0x7B7B &&
            gt.M.g_hi == 0x1011 && gh.g_lo == 0x5A5A)
            r += 3;
    }

    return r;                          /* 4*9 + 3*2 == 42 */
}
