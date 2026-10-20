/* arrowdotchain.c -- `E->member.field` where E is a COMPUTED base and `member`
 * is an EMBEDDED struct.  apple/fgx#189.
 *
 * `p->in.hi` compiled and `(p)->in.hi` did not, though K&R A.7.3.3 says in so
 * many words that they are the same expression: "Thus the expression E1->MOS
 * is the same as (*E1).MOS."  The two productions above that note are what
 * makes the chain legal at all --
 *
 *   "A postfix expression followed by a dot followed by an identifier is a
 *    postfix expression.  The first operand expression must be a structure or
 *    a union..."
 *   "A postfix expression followed by an arrow ... is a postfix expression.
 *    The first operand expression must be a pointer to a structure or union..."
 *
 * -- both say the RESULT IS ITSELF A POSTFIX EXPRESSION, and neither puts any
 * condition on how that operand was spelled.  So `E->m.n' is the dot
 * production applied to the arrow production's result, for any E.  fcc's
 * value-chain reader continued a hop run through `->' but not through `.',
 * so the tail was left unconsumed and the caller reported "expected ')'" --
 * pointing at the closing paren rather than at the member.
 *
 * WHY ONLY A COMPUTED BASE.  An IDENT base takes a different path whose result
 * carries the symbol it came from, and the reader's dot arm re-enters the
 * named-base builder on it.  A parenthesised or cast base has no symbol, fell
 * past that arm, and stopped.  Every BSD-shaped accessor macro is a cast base
 * (`VTOI(vp)->i_size', `VFSTOUFS(mp)->um_sb'), which is where this was found.
 *
 * PARSING IS NOT THE PROPERTY UNDER TEST, and that is the whole reason this
 * file asserts numbers.  An embedded struct member lives INSIDE the object the
 * base points at, so the hop must ADD its offset and keep the pointer.  A fix
 * that merely stopped the error could instead have DEREFERENCED it -- loading
 * the first word of the member and then indexing off that value, which is a
 * wild read that happens to be quiet.  Every case below therefore puts a
 * DIFFERENT value in every field, so a hop that lands one member early, one
 * member late, or one indirection too deep produces a number no other field
 * holds.
 *
 * The guard fields exist for the same reason: `lo' sits immediately before
 * `hi', so an offset that is short by one member reads `lo', and 0x1111 is a
 * value nothing else in the struct carries.
 */

struct inner {
    int lo;
    int hi;
};

struct arrd {
    int arr[4];
};

struct mid {
    int          pad;
    struct arrd  d;
};

struct outer {
    int           num;
    struct inner  in;
    struct inner *ip;
    struct mid   *m;
};

struct box {
    char *data;
};

/* The BSD-shaped accessor this was found through: a cast base, not an ident. */
#define OBJ(b)  ((struct outer *)(b)->data)

static struct outer ob;
static struct inner detached;
static struct mid   md;
static struct box   bx;

int main()
{
    struct outer *p;
    char         *raw;
    int          *ap;

    p = &ob;

    /* --- everything starts DISTINCT, so a misplaced hop shows up ------ */
    p->num      = 0x0777;
    p->in.lo    = 0x1111;
    p->in.hi    = 0x2222;
    detached.lo = 0x3333;
    detached.hi = 0x4444;
    p->ip       = &detached;
    md.pad      = 0x5555;
    md.d.arr[0] = 0x6660;
    md.d.arr[1] = 0x6661;
    md.d.arr[2] = 0x6662;
    md.d.arr[3] = 0x6663;
    p->m        = &md;
    bx.data     = (char *)&ob;

    /* --- 50: the spelling that already worked, so a regression here
     * separates "the fix broke the good path" from "the fix did nothing" --- */
    if (p->in.hi != 0x2222)
        return (50);
    if (p->in.lo != 0x1111)
        return (51);

    /* --- 52: the PARENTHESISED base -- the reported defect ------------ */
    if ((p)->in.hi != 0x2222)
        return (52);
    /* ...and it must be `hi', not the member before it.  A hop that adds no
     * offset, or the struct's own address read as an int, lands on lo. */
    if ((p)->in.lo != 0x1111)
        return (53);

    /* --- 54: the CAST base, which is how every accessor macro spells it */
    raw = (char *)&ob;
    if (((struct outer *)raw)->in.hi != 0x2222)
        return (54);
    if (OBJ(&bx)->in.hi != 0x2222)
        return (55);
    /* One hop only, through the same cast base: this worked before the fix
     * and proves the cast path itself is not what changed. */
    if (OBJ(&bx)->num != 0x0777)
        return (56);

    /* --- 57: ARROW then ARROW still derefs, and must not become an add.
     * `ip' is a struct POINTER, so its hop is a LOAD.  If the fix had made
     * every struct-ish hop an offset, this would read inside `ob' instead of
     * inside `detached' and come back 0x2222 rather than 0x4444. --------- */
    if ((p)->ip->hi != 0x4444)
        return (57);
    if ((p)->ip->lo != 0x3333)
        return (58);

    /* --- 59: ARROW, ARROW, then DOT -- a load followed by an offset ---- */
    if ((p)->m->d.arr[2] != 0x6662)
        return (59);
    if ((p)->m->pad != 0x5555)
        return (60);

    /* --- 61: writing through the chain reaches the same bytes the read
     * does.  A read path that computed a DIFFERENT address from the store
     * path would leave both halves self-consistent and disagree with each
     * other, which no single-sided case can see. ----------------------- */
    (p)->in.hi = 0x0BAD;
    if (p->in.hi != 0x0BAD)
        return (61);
    if (p->in.lo != 0x1111)
        return (62);            /* the store went one member early */
    if (p->num != 0x0777)
        return (63);            /* ...or clean off the front of the struct */
    p->in.hi = 0x2222;          /* put it back for what follows */

    /* --- 64: `&E->m->d.arr[i]' -- the address-of hop run, which is a
     * SEPARATE copy of the same loop and needed the same continuation.
     * Without it this refused with "addr-of chain requires an index '['",
     * because the run stopped at `.' and never reached the subscript.
     *
     * AN IDENT BASE, DELIBERATELY.  `&(p)->m->d.arr[1]' -- the same thing with
     * a redundant paren -- takes a THIRD path (the value chain's address arm)
     * and is still refused.  So is `&p->in.hi', which mis-associates as
     * `(&p->in) . hi': `&' takes the address of a whole postfix expression
     * (K&R A.7.4), and that arm returns before the chain is complete.  Both
     * are left refusing rather than half-fixed, and neither is asserted here
     * -- a case that cannot pass is not coverage. */
    ap = &p->m->d.arr[1];
    if (*ap != 0x6661)
        return (64);
    if (ap[1] != 0x6662)
        return (65);            /* the address was scaled wrong */

    /* ...and WRITE through it, which pins the address to one element rather
     * than to a value that two elements might share.  Reading alone cannot
     * tell `&arr[1]' from a pointer that happens to land on equal bytes.
     *
     * NOT `ap[-1]', which is the obvious way to check the element below: a
     * NEGATIVE subscript on a pointer is separately broken in this compiler
     * (apple/fgx#190 -- `q = &a[1]; q[-1]' reads the wrong element for a
     * plain int array, with no struct or chain involved), so a case built on
     * it would fail for a reason this file is not about. */
    *ap = 0x0ABC;
    if (md.d.arr[1] != 0x0ABC)
        return (66);            /* the address was not arr[1] */
    if (md.d.arr[0] != 0x6660)
        return (67);            /* it landed one element low */
    if (md.d.arr[2] != 0x6662)
        return (68);            /* ...or one element high */

    return (42);
}
