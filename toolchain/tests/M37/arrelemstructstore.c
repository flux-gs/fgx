/* arrelemstructstore.c -- whole-struct assignment where the LHS reaches through
 * an ARRAY ELEMENT and one or more dots, and where the RHS is a struct-valued
 * member read at the same kind of depth.  apple/fgx#259.
 *
 * fcc refused both halves:
 *
 *   gt.MA[i].L = tmp;        the STORE.  Fell through the chain walker's word
 *                            store and wrote TWO BYTES of the source's ADDRESS
 *                            into an eight-byte member.  Silent.
 *   x = gt.MA[0].L;          the READ.   "mid-chain-dot read with a struct-value
 *                            leaf not yet supported" -- N_LV_LOAD_E dereferences
 *                            its leaf, and a struct does not fit a register.
 *
 * K&R A.7.17: "in the simple form, the value of the expression replaces that of
 * the object referred to by the lvalue", with operands that may be "structures
 * or unions of the same type".  The OBJECT, not its first word.  A.7.3.3 makes
 * the dot production recursive and carries no depth limit, so the member is as
 * good an lvalue at depth as at one hop.
 *
 * WHY THE FENCES, AND WHY A ZERO SOURCE.  This is memberstructassign.c's lesson
 * applied one level out, and it is the whole design of this file:
 *
 *   - a wrong ADDRESS emits a perfectly good copy loop somewhere else, so every
 *     case checks the NEIGHBOURING array elements and the sibling members;
 *   - a wrong LENGTH runs off either end, so each target sits between two
 *     fences that must survive;
 *   - checking only that the pattern ARRIVED cannot catch an over-copy, because
 *     an over-long loop still delivers the pattern.  So the last case assigns an
 *     ALL-ZERO source: if the loop is too long it writes zeros into a fence, and
 *     nothing else in this file would have noticed.
 *
 * The index is a RUNTIME variable throughout: a constant subscript folds into a
 * different arm and would not exercise the one this issue is about.
 */

struct leaf { unsigned short a; long b; unsigned short c; };
struct mid  { unsigned short head; struct leaf L; unsigned short tail; };
struct top  { struct mid MA[3]; struct mid M; };

struct top  gt;
struct top *gp;
struct leaf g_src;
struct leaf g_zero;
struct leaf g_dst;

static void
seed(void)
{
    int k;
    g_src.a = 0x1111; g_src.b = 0x22223333L; g_src.c = 0x4444;
    g_zero.a = 0; g_zero.b = 0L; g_zero.c = 0;
    for (k = 0; k < 3; k++) {
        gt.MA[k].head  = 0xC0DE;
        gt.MA[k].tail  = 0xBEEF;
        gt.MA[k].L.a   = 0x9000 + k;
        gt.MA[k].L.b   = 0xA0000L + k;
        gt.MA[k].L.c   = 0xB000 + k;
    }
    gt.M.head = 0xF00D; gt.M.tail = 0xFEED;
    gt.M.L.a  = 0x7777; gt.M.L.b = 0x88889999L; gt.M.L.c = 0x6666;
    g_dst.a = 0; g_dst.b = 0L; g_dst.c = 0;
}

/* 0 if the pattern landed whole; a small non-zero code naming the member. */
static int
landed(p)
struct leaf *p;
{
    if (p->a != 0x1111)       return (1);
    if (p->b != 0x22223333L)  return (2);
    if (p->c != 0x4444)       return (3);
    return (0);
}

int
main(void)
{
    int i;

    gp = &gt;

    /* ---- 1. STORE: array element, one dot, simple RHS. -------------- */
    seed();
    i = 1;
    gt.MA[i].L = g_src;
    if (landed(&gt.MA[1].L))       return (1 + landed(&gt.MA[1].L));
    if (gt.MA[1].head != 0xC0DE)   return (5);   /* fence below */
    if (gt.MA[1].tail != 0xBEEF)   return (6);   /* fence above */
    if (gt.MA[0].L.a  != 0x9000)   return (7);   /* element below */
    if (gt.MA[2].L.a  != 0x9002)   return (8);   /* element above */

    /* ---- 2. STORE through the arrow twin. --------------------------- */
    seed();
    i = 2;
    gp->MA[i].L = g_src;
    if (landed(&gt.MA[2].L))       return (10 + landed(&gt.MA[2].L));
    if (gt.MA[2].head != 0xC0DE)   return (15);
    if (gt.MA[2].tail != 0xBEEF)   return (16);
    if (gt.MA[1].L.a  != 0x9001)   return (17);

    /* ---- 3. READ: struct-valued member at array-element depth. ------ */
    seed();
    i = 0;
    g_dst = gt.MA[i].L;
    if (g_dst.a != 0x9000)         return (20);
    if (g_dst.b != 0xA0000L)       return (21);
    if (g_dst.c != 0xB000)         return (22);
    if (gt.MA[0].L.a != 0x9000)    return (23);  /* source untouched */

    /* ---- 4. BOTH sides deep, which is the shape this issue was filed
     * on.  Element 2 receives element 0's leaf. ---------------------- */
    seed();
    i = 2;
    gt.MA[i].L = gt.MA[0].L;
    if (gt.MA[2].L.a != 0x9000)    return (30);
    if (gt.MA[2].L.b != 0xA0000L)  return (31);
    if (gt.MA[2].L.c != 0xB000)    return (32);
    if (gt.MA[2].head != 0xC0DE)   return (33);
    if (gt.MA[2].tail != 0xBEEF)   return (34);
    if (gt.MA[0].L.a != 0x9000)    return (35);  /* source untouched */
    if (gt.MA[1].L.a != 0x9001)    return (36);  /* the element between */

    /* ---- 5. THE ZERO SOURCE, which an over-copy cannot fake.  Every
     * case above checks that the PATTERN arrived, and an over-long loop
     * delivers the pattern and then keeps going.  Assigning all zeros
     * makes an over-run show up as a dead fence instead. */
    seed();
    i = 1;
    gt.MA[i].L = g_zero;
    if (gt.MA[1].L.a != 0)         return (40);
    if (gt.MA[1].L.b != 0L)        return (41);
    if (gt.MA[1].L.c != 0)         return (42 + 100);   /* not 42 */
    if (gt.MA[1].head != 0xC0DE)   return (44);   /* zeros must not reach here */
    if (gt.MA[1].tail != 0xBEEF)   return (45);
    if (gt.MA[0].L.c  != 0xB000)   return (46);
    if (gt.MA[2].L.a  != 0x9002)   return (47);

    return (42);
}
