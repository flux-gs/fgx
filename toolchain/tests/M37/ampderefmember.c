/* `&(*p)->m' and `&(*p)->m[i]' -- the address of a member reached through
 * the POINTEE of a pointer-to-pointer.
 *
 * This is ProDOS's `&(*bpp)->b_addr[off]', where a helper hands a buffer back
 * through `struct buf **bpp'.  fcc's `&(*p)' arm accepted only the SUBSCRIPT
 * continuation `&(*p)[i]', which ampderef.c covers, so a '->' after the
 * parenthesis reached `expect(TOK_LBRACKET)' and reported the '[' it wanted.
 *
 * K&R A.7.4.2 (p.164): "The operand must be an lvalue referring neither to a
 * bit-field nor to an object declared as register".  A.7.3.3 makes the arrow
 * form an lvalue "if the type is not an array type", and `*p' is a pointer to
 * a structure, which is all its first operand must be.
 *
 * IT ASSERTS VALUES: every address is written through and read back through
 * the plain struct, so a wrong member offset cannot agree with itself.
 *
 * Exit 42.
 */

struct b {
    int   flags;
    char *addr;
    long  blkno;
};

char     data[16];
struct b bufs[2];

int
fill(bpp)
struct b **bpp;
{
    char *cp;
    long *lp;

    cp = &(*bpp)->addr[3];          /* the member is a pointer, subscripted */
    *cp = 77;
    lp = &(*bpp)->blkno;            /* a plain member */
    *lp = 123456L;
    cp = &((*bpp)->addr[5]);        /* an extra paren around the chain */
    *cp = 55;
    return (0);
}

int
main()
{
    struct b  *bp;
    struct b **bpp;
    int       *ip;

    bufs[1].addr = data;
    bp  = &bufs[1];
    bpp = &bp;
    fill(bpp);
    if (data[3] != 77)              return (1);
    if (bufs[1].blkno != 123456L)   return (2);
    if (data[5] != 55)              return (3);
    if (bufs[0].blkno != 0L)        return (4);

    ip = &(*bpp)->flags;            /* offset 0, the member a dropped offset
                                     * would also land on -- so check the
                                     * LAST one lands where the struct puts it */
    *ip = 9;
    if (bufs[1].flags != 9)         return (5);
    if ((char *)&(*bpp)->blkno != (char *)&bufs[1].blkno ||
        (char *)&(*bpp)->blkno == (char *)ip) return (6);

    /* ampderef.c's subscript continuation, whose arm this rewired. */
    {
        char  *cp;
        char  *rp;
        char **pp;

        rp = data;
        pp = &rp;
        cp = &(*pp)[3];
        if (*cp != 77)              return (7);
    }
    return (42);
}
