/* arrowarraychain.c -- two shapes the arrow-chain reader had no arm for, both
 * found porting 2.11BSD's tty_subr.c.  apple/fgx#200, apple/fgx#201.
 *
 *   #200  p->q->arr        an ARRAY field at the end of a MULTI-hop run.
 *                          One hop (`p->arr') has decayed since N_AV_DECAY;
 *                          two hops died "chained '->' to in-struct array
 *                          field not yet supported".
 *   #201  ((struct s *)cp)[-1].f   a COMPUTED struct-pointer base, subscripted.
 *                          A NAMED base (`bp[-1].f') has always worked; a cast
 *                          makes the base computed and there was no arm, so it
 *                          reached ipv_elem_size and hit the apple/fgx#166
 *                          zero-stride guard -- which is the guard doing its
 *                          job: its own comment says the arm is unreachable
 *                          "and that is exactly why it is worth arming ... a
 *                          parser relaxation would silently turn it into a
 *                          wild pointer."
 *
 * Both now route through the uniform lvalue walker, which is the third of the
 * arrow run's three emitters -- the ADDRESS-OF and STORE spellings of these
 * exact expressions have always compiled, which is what made the read arm's
 * absence look like a language limit rather than a hole (apple/fgx#189's
 * shape, again).
 *
 * K&R A.7.1: "an lvalue of type array of T is converted to a pointer to the
 * first object in the array" -- unconditional, so the number of hops that
 * reached the array cannot matter.  A.7.3.1: E1[E2] is *((E1)+(E2)), and A.7.7
 * scales the sum by the pointee -- nothing there distinguishes a named operand
 * from a cast one.
 *
 * EVERY CASE ASSERTS A VALUE, and that is the point of the file rather than a
 * habit.  When apple/fgx#189 taught the parser a missing hop shape, the newly
 * accepted `&E->m->d.arr[i]' COMPILED AND COMPUTED A WILD ADDRESS; a fixture
 * that only checked "it builds" would have gone green over it.  So the blocks
 * are seeded with values that encode WHICH block and WHICH byte was reached,
 * and the address forms are asserted to agree with the read forms.
 */

#define CBS 28

struct blk {
    struct blk *b_next;
    char        b_info[CBS];
};

struct wrap {
    int         w_tag;
    struct blk *w_blk;
};

struct blk  pool[3];
struct wrap wr;
char       *g;
int        *gi;

struct ib { struct ib *i_next; int i_arr[4]; };
struct ib  ipool[2];

int
main()
{
    char       *p;
    char       *q;
    int        *ip;
    struct blk *bp;
    struct blk *bp1;
    struct ib  *ibp;
    int         i;

    /* Seed: block n's byte k holds 0x10*(n+1) + k, so a value names both. */
    for (i = 0; i < CBS; i++) {
        pool[0].b_info[i] = (char)(0x10 + i);
        pool[1].b_info[i] = (char)(0x20 + i);
        pool[2].b_info[i] = (char)(0x30 + i);
    }
    pool[0].b_next = &pool[1];
    pool[1].b_next = &pool[2];
    pool[2].b_next = &pool[0];
    wr.w_tag = 0x7777;
    wr.w_blk = &pool[1];

    for (i = 0; i < 4; i++) {
        ipool[0].i_arr[i] = 0x100 + i;
        ipool[1].i_arr[i] = 0x200 + i;
    }
    ipool[0].i_next = &ipool[1];
    ipool[1].i_next = &ipool[0];

    /* ---- 10: the premise.  A block is 32 bytes on this ABI: a 4-byte link
     * plus CBS.  Every negative-index case below is really an assertion about
     * this number, so it is asserted first rather than assumed. */
    if (sizeof(struct blk) != 32) return (10);

    /* ---- 20: ONE hop to an array field.  The control that already worked --
     * if this goes red the fix landed on the wrong arm. */
    bp = &pool[0];
    p = bp->b_info;
    if (*p != (char)0x10) return (20);

    /* ---- 21: TWO hops to an array field.  #200's case.  pool[0].b_next is
     * &pool[1], so this must reach the 0x2n block and NOT the 0x1n one -- a
     * fix that dropped a hop would return 0x10 here and look plausible. */
    p = bp->b_next->b_info;
    if (*p != (char)0x20) return (21);
    if (p[1] != (char)0x21) return (22);

    /* ---- 23: THREE hops, so the run is longer than the two the walker needs
     * to be entered at all. */
    p = bp->b_next->b_next->b_info;
    if (*p != (char)0x30) return (23);

    /* ---- 24: two hops from a GLOBAL base, not a local.  The chain head
     * carries sym_gv instead of sym_lc and that is a different field. */
    p = wr.w_blk->b_next->b_info;
    if (*p != (char)0x30) return (24);

    /* ---- 25: the decayed pointer must EQUAL the address the &-form gives.
     * Two spellings of one address that disagree is exactly how a wrong hop
     * count survives a "does it compile" test. */
    if (bp->b_next->b_info != &bp->b_next->b_info[0]) return (25);
    bp1 = &pool[1];
    if (bp->b_next->b_info != &bp1->b_info[0])        return (26);

    /* ---- 27: subscripted, so the walker consumed the '[' itself and the
     * leaf is the ELEMENT rather than the array.  Different wrapper node. */
    if (bp->b_next->b_info[3] != (char)0x23) return (27);

    /* ---- 28: a 2-BYTE element, where a stride taken from the wrong type
     * lands on a real element rather than off the end.  0x102 and not 0x101
     * is the whole assertion. */
    ibp = &ipool[0];
    ip = ibp->i_next->i_arr;
    if (*ip != 0x200)                return (28);
    if (ibp->i_next->i_arr[2] != 0x202) return (29);

    /* ---- 30: the STORE spelling, which has always compiled.  Asserted here
     * because "always compiled" is not "always correct", and it shares the
     * walker with the new read arm now. */
    bp->b_next->b_info[5] = (char)0x99;
    if (pool[1].b_info[5] != (char)0x99) return (30);
    pool[1].b_info[5] = (char)0x25;      /* put it back for the cases below */

    /* ================= #201: a COMPUTED struct-pointer base ============= */

    /* ---- 40: the control -- a NAMED base with a negative index.  This has
     * always worked, and it is what says the cast is the variable. */
    bp = &pool[2];
    if (bp[-1].b_info[0] != (char)0x20) return (40);

    /* ---- 41: THE CASE.  A cast makes the base computed.
     *
     * THE BASE IS BLOCK-ALIGNED, AND THAT IS UPSTREAM'S PRECONDITION, not a
     * convenience: nextc only writes this expression under
     * `((int)cp & CROUND) == 0', i.e. when cp has just walked off the end of
     * one block and equals the base of the next.  So q is a block base here
     * and [-1] is the block before it.  A char* pointing INTO a block would
     * put [-1] 32 bytes below that BYTE, which is a different and meaningless
     * address -- the first draft of this case did exactly that and expected
     * the aligned answer, and the fixture failed on the arithmetic rather
     * than on the compiler. */
    q = (char *)&pool[2];
    if (((struct blk *)q)[-1].b_info[0] != (char)0x20) return (41);

    /* ---- 42: ...and the '.field' after it, which is what nextc actually
     * reads.  pool[1].b_next is &pool[2]. */
    if (((struct blk *)q)[-1].b_next != &pool[2]) return (42);

    /* ---- 43: nextc's expression, whole: cast, negative index, '.', '->',
     * and an array field at the end -- both fixes in one line.
     * ((struct blk *)q)[-1] is pool[1]; .b_next is &pool[2]; ->b_info is the
     * 0x3n block. */
    p = ((struct blk *)q)[-1].b_next->b_info;
    if (*p != (char)0x30) return (43);

    /* ---- 44: POSITIVE indices through the same computed base, so nothing
     * here rests on the sign. */
    q = (char *)&pool[0];
    if (((struct blk *)q)[1].b_info[0] != (char)0x20) return (44);
    if (((struct blk *)q)[2].b_info[0] != (char)0x30) return (45);

    /* ---- 46: index ZERO, where every wrong stride multiplies away.  Present
     * so the file records that it CANNOT distinguish a stride bug, not
     * because it can. */
    if (((struct blk *)q)[0].b_info[0] != (char)0x10) return (46);

    /* ---- 47: a computed base whose index is a VARIABLE, which is what a
     * loop writes and what a constant-folded case would never exercise. */
    i = 2;
    if (((struct blk *)q)[i].b_info[1] != (char)0x31) return (47);

    /* ---- 48: the address and the read must agree here too. */
    if (&((struct blk *)q)[1] != &pool[1]) return (48);

    return (42);
}
