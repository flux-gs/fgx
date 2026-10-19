/* chainincdec.c -- ++/-- on a MEMBER CHAIN, as a statement.
 *
 * `a->b->c++;` and `++a->b->c;` were rejected outright: the statement parser
 * desugared ONE hop of `.` or `->` into a compound assign and had no node for
 * a second, so the postfix form died "expected '='" and the prefix form died
 * with a message naming the limitation.  Both now route to the uniform lvalue
 * walker, which already served `a->b->c = x` and `a->b->c += 1`.
 *
 * PARSING IS NOT THE PROPERTY UNDER TEST.  A fix that only stopped the error
 * would pass a compile check while incrementing the wrong cell entirely -- and
 * on this machine the likeliest wrong cell is the right offset in the wrong
 * BANK, because every hop reloads a 4-byte pointer and only the last two hops
 * are exercised by the single-hop shapes that already worked.  So each case
 * reads the value back through a SEPARATE path from the one that wrote it and
 * checks the neighbours are untouched.
 *
 * Exit 42 = pass; any other value identifies the case.  Numbered from 50 so no
 * failure can land on the pass code.
 */

struct leaf {
    int     pre;                    /* neighbour, must not move */
    int     i;
    long    l;
    char    c;
    int     post;                   /* neighbour, must not move */
};

struct mid {
    struct leaf  *lp;
    struct leaf   ld;
};

struct top {
    struct mid   *mp;
    struct mid    md;
};

struct leaf L;
struct mid  M;
struct top  T;

static void
setup()
{
    L.pre = 1; L.i = 10; L.l = 100000L; L.c = 'A'; L.post = 2;
    M.lp = &L;
    M.ld.pre = 3; M.ld.i = 20; M.ld.l = 7L; M.ld.c = 'B'; M.ld.post = 4;
    T.mp = &M;
    T.md.lp = &L;
    T.md.ld.pre = 5; T.md.ld.i = 30; T.md.ld.l = 9L;
    T.md.ld.c = 'C'; T.md.ld.post = 6;
}

main()
{
    struct top *tp;
    struct mid *mp;

    setup();
    tp = &T;

    /* ---- three arrows, postfix.  The deepest chain, and the one whose
     *      failure mode is a write into the wrong bank. ---- */
    tp->mp->lp->i++;
    if (L.i != 11)                              return 50;
    if (L.pre != 1 || L.post != 2)              return 51;

    /* Read back through a DIFFERENT route to the same cell: if the increment
     * landed somewhere that merely looks like L.i from one direction, these
     * disagree. */
    if (T.mp->lp->i != 11)                      return 52;
    if (M.lp->i != 11)                          return 53;

    /* ---- three arrows, prefix ---- */
    ++tp->mp->lp->i;
    if (L.i != 12)                              return 54;

    /* ---- three arrows, decrement, both spellings ---- */
    tp->mp->lp->i--;
    --tp->mp->lp->i;
    if (L.i != 10)                              return 55;
    if (L.pre != 1 || L.post != 2)              return 56;

    /* ---- a LONG leaf.  32-bit read-modify-write, where a 16-bit increment
     *      would silently drop the carry into the high word. ---- */
    L.l = 65535L;
    tp->mp->lp->l++;
    if (L.l != 65536L)                          return 57;
    ++tp->mp->lp->l;
    if (L.l != 65537L)                          return 58;
    tp->mp->lp->l--;
    if (L.l != 65536L)                          return 59;

    /* ---- a CHAR leaf, whose neighbours are one byte away ---- */
    tp->mp->lp->c++;
    if (L.c != 'B')                             return 60;
    if (L.i != 10)                              return 61;

    /* ---- arrow then DOT: the chain ends in an embedded struct, so the last
     *      hop is an offset rather than a dereference ---- */
    tp->mp->ld.i++;
    if (M.ld.i != 21)                           return 62;
    if (M.ld.pre != 3 || M.ld.post != 4)        return 63;
    ++tp->mp->ld.i;
    if (M.ld.i != 22)                           return 64;

    /* ---- DOT then ARROW, and a pure dot chain, for symmetry ---- */
    tp->md.lp->i++;
    if (L.i != 11)                              return 65;
    /* Three hops of pure '.', no pointer anywhere in the chain. */
    T.md.ld.pre++;
    if (T.md.ld.pre != 6)                       return 66;
    if (T.md.ld.i != 30)                        return 72;

    /* ---- two arrows off a DIFFERENT base, to prove the walker reads the
     *      base it is given rather than a cached one ---- */
    mp = &M;
    mp->lp->i++;
    if (L.i != 12)                              return 67;

    /* ---- inside a loop, where the chain is re-walked every iteration ---- */
    L.i = 0;
    {
        int k;
        for (k = 0; k < 5; k++)
            tp->mp->lp->i++;
    }
    if (L.i != 5)                               return 68;
    if (L.pre != 1 || L.post != 2)              return 69;

    /* ---- and the SINGLE-hop forms still work, which is the check that the
     *      routing change did not steal a shape that already had a handler ---- */
    mp->ld.i = 0;
    mp->lp->pre = 0;
    L.i = 0;
    M.ld.i++;                                   /* one dot */
    if (M.ld.i != 1)                            return 70;
    mp->lp->i++;                                /* one arrow, one deref */
    if (L.i != 1)                               return 71;

    return 42;
}
