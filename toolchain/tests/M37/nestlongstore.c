/* nestlongstore.c -- storing a 4-byte scalar through `ptr->member.field`.
 *
 * `p->s.longfield = rhs;` died "'->struct-member.field' store: only int/char
 * scalar, a pointer, or an int/char array-element supported".  The DOT-chain
 * twin (`o.s.longfield = rhs;`) has stored longs and floats all along, and the
 * READ side worked -- so this was the arrow-then-dot spelling alone, which is
 * apple/fgx#155's twin-arm pattern for the second time in one deliverable.
 *
 * Found writing UFS 1.11a's on-disk inode decode:
 *
 *     dp->di_icom1.ic_size = ufs_dget32(b, 8);
 *
 * ic_size is off_t, and the icommon1/icommon2 grouping it sits inside is
 * 4.3BSD-Reno's own inode layout, pinned by pdplayout.c -- so the shape is a
 * FORMAT CONTRACT and not something the port could have spelled differently.
 *
 *============================================================================
 * WHY THE NEIGHBOURS ARE CHECKED, AND WHY IT ASSIGNS FROM AN INT.
 *
 * The failure mode of a width bug here is not a wrong value in the field, it is
 * a RIGHT value in the field and a wrecked one next door: a 2-byte store leaves
 * the high half stale, and a 4-byte store where 2 were meant reaches into the
 * following member.  So every case brackets the target with a field either side
 * and checks all three.
 *
 * And `p->s.L = 7;` -- an INT rhs into a long field -- is its own case, because
 * the emitter has to promote it.  Without that the high word is whatever the
 * 16-bit RHS left in the register, which is the classic "works with a literal
 * long, fails with a variable int" shape.  apple/fgx#153b is the standing rule:
 * a parse fix's test asserts VALUES.
 */

struct inner {
    int  before;
    long lv;
    int  between;
    float fv;
    int  after;
};

struct outer {
    int          head;
    struct inner in;
    int          tail;
};

static struct outer  o;
static struct outer *p;
static long          gl;
static int           gi;

int
main()
{
    p = &o;

    /* 1. THE SHAPE THAT WAS REJECTED: a long literal. */
    o.head = 1; o.tail = 2;
    o.in.before = 3; o.in.between = 4; o.in.after = 5;
    p->in.lv = 123456L;
    if (p->in.lv != 123456L)        return (1);
    if (o.in.before != 3)           return (2);
    if (o.in.between != 4)          return (3);
    if (o.head != 1 || o.tail != 2) return (4);

    /* 2. A NEGATIVE long, so the high word is not merely zero -- a store that
     *    wrote only the low half would pass case 1 on a small positive. */
    p->in.lv = -7L;
    if (p->in.lv != -7L)            return (5);
    if (o.in.between != 4)          return (6);

    /* 3. AN INT RHS, which the emitter must PROMOTE.  A missing promotion
     *    leaves register garbage in the high word. */
    gi = 9;
    p->in.lv = gi;
    if (p->in.lv != 9L)             return (7);
    if (o.in.between != 4)          return (8);

    /* 4. A NEGATIVE int RHS: promotion must SIGN-extend, not zero-extend. */
    gi = -3;
    p->in.lv = gi;
    if (p->in.lv != -3L)            return (9);

    /* 5. From a long variable, and read back through the DOT spelling -- the
     *    twin that always worked, so the two must agree. */
    gl = 999999L;
    p->in.lv = gl;
    if (o.in.lv != 999999L)         return (10);

    /* 6. FLOAT, the other 4-byte scalar the twin arm handles. */
    p->in.fv = 2.5;
    if (p->in.fv != 2.5)            return (11);
    if (o.in.between != 4)          return (12);
    if (o.in.after != 5)            return (13);

    /* 7. An int RHS into the float field converts rather than reinterprets. */
    gi = 6;
    p->in.fv = gi;
    if (p->in.fv != 6.0)            return (14);

    /* 8. THE ARMS THAT ALREADY WORKED, re-checked: a fix that broke the int,
     *    char or dot-chain spellings would be a poor trade. */
    p->in.before = 41;
    if (o.in.before != 41)          return (15);
    o.in.lv = 77L;
    if (p->in.lv != 77L)            return (16);
    if (o.in.before != 41)          return (17);

    return (42);
}
