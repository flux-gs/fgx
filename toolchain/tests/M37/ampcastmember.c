/* `&((cast)expr)->member` -- the address of a member reached through a CAST.
 * apple/fgx#174.
 *
 * This is the natural spelling of `&VFSTOUFS(mp)->um_sb`, since the tree's
 * VFSTOUFS and VTOI are both `((struct T *)(...))`.  fcc handled only the
 * SUBSCRIPT continuation after a parenthesised cast -- `&((char_type *)h)[i]`,
 * which ampcastsub.c covers -- so a '->' after the cast reached
 * `expect(TOK_LBRACKET)` and reported the '[' it wanted.
 *
 * K&R A.7.4.2 (p.164): "The unary operator & takes the address of its operand.
 * The operand must be an lvalue referring neither to a bit-field nor to an
 * object declared as register."  A.7.3.3 makes `E1->MOS` an lvalue "if the type
 * is not an array type".  A cast yields a pointer VALUE, `->` on it yields an
 * lvalue, and neither sentence distinguishes a cast base from an identifier.
 *
 * IT ASSERTS VALUES, and specifically that the address is the RIGHT one: an
 * address computed with the wrong member offset still compiles, still stores,
 * and corrupts a neighbour.  So every member is written through the returned
 * pointer and read back through the struct.
 *
 * Exit 42.
 */

struct m {
    int  a;
    int  b;
    long c;
};

struct holder { char *d; };

char           buf[16];
struct holder  h;

int
main()
{
    int  *pa;
    int  *pb;
    long *pc;
    struct m *mp;

    h.d = buf;

    /* Address of each member through the cast, written through, read back
     * through a DIFFERENT route -- the plain struct pointer -- so a wrong
     * offset cannot agree with itself. */
    pa = &((struct m *)h.d)->a;
    pb = &((struct m *)h.d)->b;
    pc = &((struct m *)h.d)->c;
    *pa = 11;
    *pb = 22;
    *pc = 333333L;

    mp = (struct m *)buf;
    if (mp->a != 11)      return (1);
    if (mp->b != 22)      return (2);
    if (mp->c != 333333L) return (3);

    /* The three addresses must be DISTINCT and correctly spaced: two members
     * sharing an address is exactly what a dropped offset produces. */
    if (pa == pb) return (4);
    if ((char *)pb - (char *)pa != 2) return (5);
    if ((char *)pc - (char *)pa != 4) return (6);

    /* The cast base as an expression rather than a plain lvalue -- this is the
     * VFSTOUFS shape, where the operand is itself a member read. */
    pb = &((struct m *)h.d)->b;
    *pb = 99;
    if (mp->b != 99) return (7);

    /* The rvalue spelling was never broken and is the CONTROL. */
    if (((struct m *)h.d)->a != 11) return (8);

    /* ...and the subscript continuation, which ampcastsub.c owns, must still
     * work: this fix rewired the arm it lives in. */
    {
        char *cp;
        buf[5] = 77;
        cp = &((char *)buf)[5];
        if (*cp != 77) return (9);
    }
    return (42);
}
