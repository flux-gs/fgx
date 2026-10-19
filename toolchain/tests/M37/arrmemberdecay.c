/* An ARRAY MEMBER one '.' hop past an arrow decays to a pointer, and can be
 * subscripted -- for every element type, not just char and int.  apple/fgx#180.
 *
 * K&R A.7.1 (p.161): "If the type of an expression or subexpression is ``array
 * of T,'' for some type T, then the value of the expression is a pointer to the
 * first object in the array, and the type of the expression is altered to
 * ``pointer to T.''"  The exception list -- "&, ++, --, sizeof, or as the left
 * operand of an assignment operator or the . operator" -- does not reach here:
 * the array is the RIGHT operand of '.', and the ELEMENT TYPE is not among the
 * conditions.
 *
 * WHAT WENT WRONG.  fcc's dotted-chain reader decayed LT_CHAR_ARRAY and
 * LT_INT_ARRAY and no other, so `p->s.longarr` fell through to a SCALAR LOAD:
 * it read the first element and pushed two bytes where a four-byte pointer
 * belonged, and every argument after it shifted.  In the kernel that made
 * `ufs_bmap(ip->i_devvp, ip->i_addr, lbn, &bn)` read its lbn from two bytes
 * further up and refuse the block as EFBIG.  Subscripting the same member was
 * the LOUD twin, "expected ')'", because neither arm matched the '['.
 *
 * IT ASSERTS VALUES, not that it parses.  A decay defect compiles: the wrong
 * shape is a legal instruction sequence returning a plausible number, so a
 * fixture that only had to build would have passed throughout.
 *
 * Exit 42.  Any other value names the property that broke.
 */

struct inner {
    long  la[4];
    int   ia[4];
    char  ca[4];
    long *pa[4];        /* an array of POINTERS: neither arm carried it */
};

struct outer {
    int          guard;
    struct inner in;
};

struct outer o;
long         spare;

/* Takes the DECAYED pointer.  The argument shape is the one that shipped
 * wrong, and it is why this is a call rather than an assignment. */
static long
sumlong(p, n)
long *p;
int   n;
{
    long t;
    int  i;

    t = 0L;
    for (i = 0; i < n; i++)
        t = t + p[i];
    return (t);
}

int
main()
{
    struct outer *p;
    long         *q;
    int          *r;
    char         *c;
    int           i;

    o.guard = 0x5A5A;
    for (i = 0; i < 4; i++) {
        o.in.la[i] = (long)(i + 1) * 1000L;
        o.in.ia[i] = (i + 1) * 10;
        o.in.ca[i] = (char)(i + 1);
        o.in.pa[i] = &spare;
    }
    p = &o;

    /* ---- the decay yields the ADDRESS, not the first element ---- */
    q = p->in.la;
    if (q[0] != 1000L) return (1);
    if (q[3] != 4000L) return (2);
    /* The pointer must name the member, not a copy of it: writing through it
     * must be visible in the struct. */
    q[1] = 2222L;
    if (o.in.la[1] != 2222L) return (3);
    q[1] = 2000L;

    /* ---- as a CALL ARGUMENT, which is the shape that shipped wrong ---- */
    if (sumlong(p->in.la, 4) != 10000L) return (4);

    /* ---- the SUBSCRIPT twin, which used to be a parse error ---- */
    if (p->in.la[0] != 1000L) return (5);
    if (p->in.la[2] != 3000L) return (6);
    if (p->in.pa[2] != &spare) return (7);

    /* ---- char and int were already right; they are the CONTROL ----
     * Without these, a fix that broke them would still show 42. */
    r = p->in.ia;
    if (r[0] != 10 || r[3] != 40) return (8);
    c = p->in.ca;
    if (c[0] != 1 || c[3] != 4) return (9);
    if (p->in.ia[2] != 30) return (10);
    if (p->in.ca[2] != 3) return (11);

    /* ---- the base is undisturbed ---- */
    if (o.guard != 0x5A5A) return (12);

    return (42);
}
