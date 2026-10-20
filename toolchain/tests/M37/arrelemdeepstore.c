/* arrelemdeepstore.c -- a STORE through a struct-array element followed by more
 * than one dot.  apple/fgx#213.
 *
 * fcc rejected `gt.MA[i].L.v = x' with "LHS subfield must be scalar", while
 *
 *   x = gt.MA[i].L.v      the READ at that depth        compiled
 *   gt.M.L.v  = x         two dots, no array element    compiled
 *   gt.MA[i].g = x        array element, ONE dot        compiled
 *
 * so it was an artificial reject that failed closed, and the discriminator is
 * the ARRAY ELEMENT followed by more than one dot -- not the leaf type, since
 * an int leaf rejected exactly as a long one did.
 *
 * K&R A.7.3.3: "A postfix expression followed by a dot followed by an
 * identifier is a postfix expression.  The first operand expression must be a
 * structure or a union ... The value is the named member of the structure or
 * union, and its type is the type of the member.  The expression is an lvalue
 * if the first expression is an lvalue, and if the type of the second
 * expression is not an array type."  The production is RECURSIVE -- a dot
 * selection yields a postfix expression, which is then the operand of the next
 * dot -- so it carries no depth limit at all, and lvalue-ness propagates from
 * the first operand.  `gt' is an lvalue, so `gt.MA[i]' is one (A.7.3.1), so
 * `.L' is, so `.v' is.
 *
 * THE REJECT HALF OF THIS FILE CANNOT GO RED, and that is worth stating rather
 * than leaving to be discovered: against the unfixed compiler these lines do
 * not produce a wrong answer, they fail to BUILD.  What the value checks below
 * are really for is the other half -- the fix routes these shapes to the
 * expression layer, and a store that lands in the wrong ELEMENT or the wrong
 * SIBLING would compile and be silent.  So every case writes a distinct
 * pattern and then checks its neighbours are untouched.  The index is a
 * RUNTIME variable throughout: a constant subscript can be folded into a
 * different arm and would not exercise the one that rejected.
 */

struct leaf  { int g; int v; long w; };
struct inner { int g; struct leaf L; };
struct mid   { int g; struct leaf L; struct inner I; };
struct top   { struct mid MA[3]; struct mid M; };

struct top gt;
struct top *gp;

static void
clear(void)
{
    int k;
    for (k = 0; k < 3; k++) {
        gt.MA[k].g     = 0x1000 + k;
        gt.MA[k].L.g   = 0x2000 + k;
        gt.MA[k].L.v   = 0x3000 + k;
        gt.MA[k].L.w   = 0x40000L + k;
        gt.MA[k].I.g   = 0x5000 + k;
        gt.MA[k].I.L.g = 0x6000 + k;
        gt.MA[k].I.L.v = 0x7000 + k;
    }
    gt.M.L.v = 0x8000;
}

int
main(void)
{
    int i;

    gp = &gt;

    /* ---- 1. dot path, TWO dots, runtime index. ---------------------- */
    clear();
    i = 1;
    gt.MA[i].L.v = 0x55AA;
    if (gt.MA[1].L.v != 0x55AA)   return (1);   /* the store itself */
    if (gt.MA[0].L.v != 0x3000)   return (2);   /* element below untouched */
    if (gt.MA[2].L.v != 0x3002)   return (3);   /* element above untouched */
    if (gt.MA[1].L.g != 0x2001)   return (4);   /* sibling field untouched */
    if (gt.MA[1].g   != 0x1001)   return (5);   /* outer field untouched */
    if (gt.M.L.v     != 0x8000)   return (6);   /* the non-array twin */

    /* ---- 2. arrow twin, same depth. --------------------------------- */
    clear();
    i = 2;
    gp->MA[i].L.v = 0x1234;
    if (gt.MA[2].L.v != 0x1234)   return (10);
    if (gt.MA[1].L.v != 0x3001)   return (11);
    if (gt.MA[2].L.g != 0x2002)   return (12);
    if (gt.MA[2].g   != 0x1002)   return (13);

    /* ---- 3. THREE dots, to show the depth limit is gone and not moved. */
    clear();
    i = 0;
    gt.MA[i].I.L.v = 0x0F0F;
    if (gt.MA[0].I.L.v != 0x0F0F) return (20);
    if (gt.MA[0].I.L.g != 0x6000) return (21);
    if (gt.MA[0].I.g   != 0x5000) return (22);
    if (gt.MA[0].L.v   != 0x3000) return (23);  /* the OTHER leaf untouched */
    if (gt.MA[1].I.L.v != 0x7001) return (24);

    /* ---- 4. a LONG leaf at depth, because the store width differs. --- */
    clear();
    i = 2;
    gt.MA[i].L.w = 0x00ABCDEFL;
    if (gt.MA[2].L.w != 0x00ABCDEFL) return (30);
    if (gt.MA[1].L.w != 0x40001L)    return (31);
    if (gt.MA[2].L.v != 0x3002)      return (32);

    /* ---- 5. THE STRUCT-VALUED LEAF LIVES IN arrelemstructstore.c.
     * `gt.MA[i].L = <struct>' is a whole-struct assignment rather than a
     * store to a scalar leaf, and it needs fences and a zero source to be
     * tested honestly, so it has a file of its own (apple/fgx#259 -- fixed
     * in the same branch).  Named here so this file's silence on it is not
     * read as the case being uncovered. */

    /* ---- 6. read-back through the same depth, as a control. ---------
     * The READ always compiled; if it ever stops agreeing with the store
     * the two have drifted apart, which is the fault this class keeps
     * taking. */
    clear();
    i = 1;
    gt.MA[i].L.v = 0x7E7E;
    if (gt.MA[i].L.v != 0x7E7E)   return (50);

    return (42);
}
