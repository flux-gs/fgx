/* structsrcdeep.c -- a struct assignment whose RHS is a member MORE THAN ONE
 * HOP deep.  apple/fgx#214.
 *
 * `tq = tp->t_rawq' in 2.11BSD's ttypend is the shape that found it: tty.h
 * defines `t_rawq' as `t_nu.t_t.T_rawq', so it is arrow, dot, dot.  Upstream's
 * own code, with nothing to rewrite.
 *
 * AN ARTIFICIAL REJECT, and the two SIDES not agreeing is what says so:
 * apple/fgx#207 took the LEFT side to arrow+dot and two-dot depth and left the
 * right at one hop.  `p->M.L = L' compiled while `L = p->M.L' did not.
 *
 * K&R A.7.17 (p.169) conditions a struct assignment on one thing only --
 * "both operands are structures or unions of the same type" -- and says
 * nothing about how either was reached.  A.7.3.2 supplies the lvalue at depth:
 * "The expression is an lvalue if the first expression is an lvalue, and if
 * the type of the second expression is not an array type", applied as many
 * times as the run is long.
 *
 * THE COPY IS ASSERTED BY USING IT, per apple/fgx#202: a struct assignment
 * that reads from a wrong offset produces a perfectly good copy of the wrong
 * bytes, which compiles and looks fine.  Every case below copies a struct
 * whose fields hold DISTINCT values, checks all of them, and checks the
 * NEIGHBOURING members of the source were not what got copied instead.
 *
 * Exit 42.
 */

struct leaf {
    int  a;
    int  b;
    char c;
    char d;
};

struct mid {
    int         guard;
    struct leaf L;
    int         z;
};

struct top {
    int         guard;
    struct mid  M;
    struct leaf FLAT;
    struct mid  MA[3];
};

struct hop {
    struct top *tp;
    struct mid  HM;
};

struct top gt;
struct hop gh;

static
fill(lp, base)
    struct leaf *lp;
    int base;
{
    lp->a = base;
    lp->b = base + 1;
    lp->c = (char)(base + 2);
    lp->d = (char)(base + 3);
}

static
same(lp, base)
    struct leaf *lp;
    int base;
{
    if (lp->a != base)                  return (0);
    if (lp->b != base + 1)              return (0);
    if (lp->c != (char)(base + 2))      return (0);
    if (lp->d != (char)(base + 3))      return (0);
    return (1);
}

int
main()
{
    struct top  *p;
    struct hop  *h;
    struct leaf  L;
    struct mid   M;
    int          i;
    int          r;

    r = 0;
    p = &gt;
    h = &gh;
    gh.tp = &gt;

    /* Distinct contents everywhere, so a copy from the wrong place cannot
     * accidentally look right. */
    gt.guard = 0x7777;
    gt.M.guard = 0x1111;  gt.M.z = 0x2222;
    fill(&gt.M.L, 100);
    fill(&gt.FLAT, 200);
    for (i = 0; i < 3; i++) {
        gt.MA[i].guard = 0x3300 + i;
        gt.MA[i].z     = 0x4400 + i;
        fill(&gt.MA[i].L, 300 + i * 10);
    }
    gh.HM.guard = 0x5555;  gh.HM.z = 0x6666;
    fill(&gh.HM.L, 400);

    /* ---- 1: `L = p->M.L' -- arrow then dot.  The reported shape. */
    fill(&L, 0);
    L = p->M.L;
    if (same(&L, 100))                          r += 6;

    /* ---- 2: `L = v.M.L' -- two dots on a VARIABLE base.  It rejected too,
     * which is what said the gap was the right-hand side rather than the
     * arrow. */
    fill(&L, 0);
    L = gt.M.L;
    if (same(&L, 100))                          r += 6;

    /* ---- 3: `M = p->MA[i]' -- a subscript with no dot after it.  The index
     * is a VARIABLE so the scale actually runs, and the neighbours are checked
     * because scaling by the wrong element size lands in one of them. */
    i = 2;
    M = p->MA[i];
    if (M.guard == 0x3302 && M.z == 0x4402 && same(&M.L, 320))
                                                r += 6;
    i = 0;
    M = p->MA[i];
    if (M.guard == 0x3300 && M.z == 0x4400 && same(&M.L, 300))
                                                r += 6;

    /* ---- 4: `L = p->MA[i].L' -- subscript AND a dot after it. */
    i = 1;
    fill(&L, 0);
    L = p->MA[i].L;
    if (same(&L, 310))                          r += 6;

    /* ---- 5: `M = h->tp->M' -- two arrows. */
    M.guard = 0;  M.z = 0;
    M = h->tp->M;
    if (M.guard == 0x1111 && M.z == 0x2222 && same(&M.L, 100))
                                                r += 6;

    /* ---- 6: BOTH sides members, and the SOURCE must be untouched.  A copy
     * that ran the wrong way, or through a shared temporary, shows here. */
    gt.FLAT.a = 0;
    gt.FLAT = gh.HM.L;
    if (same(&gt.FLAT, 400) && same(&gh.HM.L, 400) &&
        gt.M.guard == 0x1111 && gt.guard == 0x7777)
                                                r += 6;

    return r;                                   /* 6 * 7 == 42 */
}
