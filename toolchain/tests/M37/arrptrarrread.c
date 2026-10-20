/* `arr[i].ptrarr[j]` READ, where arr is an array of structs and the member is
 * an array of pointers.  apple/fgx#170.
 *
 * The two STORE arms for this shape were fixed earlier and the READ was not:
 * the rvalue reader listed the array types it would subscript -- char and int
 * -- and omitted long, float and pointer arrays, so the '[' was left unread and
 * the parse died on "expected ';'" one token later.  Third instance of the same
 * partial-list defect, after #180's two.
 *
 * K&R A.7.3.1 (p.162) makes it one production rather than a family: "The
 * expression E1[E2] is identical (by definition) to *((E1)+(E2))", and A.7.7
 * (p.166) fixes the scale -- the index "is converted to an address offset by
 * multiplying it by the size of the object to which the pointer points".
 * Neither sentence has an element-type condition.
 *
 * IT ASSERTS VALUES.  A subscript that parses but scales by the wrong stride
 * reads a neighbouring element and returns a plausible number, so a fixture
 * that only had to compile would pass throughout.  Every element here holds a
 * DISTINCT value for that reason.
 *
 * Exit 42; any other value names the property that broke.
 */

struct n { int v; };
struct t {
    struct n *sp[4];        /* array of POINTERS -- the reported case */
    long      lv[4];        /* the same list omitted these two */
    char     *cp[4];
};

struct n  nodes[4];
struct t  arr[2];
struct t  one;

int
main()
{
    int   i;
    struct n *p;
    long *lq;
    char *cq;

    for (i = 0; i < 4; i++)
        nodes[i].v = (i + 1) * 100;

    for (i = 0; i < 4; i++) {
        one.sp[i]    = &nodes[i];
        arr[0].sp[i] = &nodes[i];
        arr[1].sp[i] = &nodes[3 - i];       /* reversed: a wrong ELEMENT shows */
        arr[0].lv[i] = (long)(i + 1) * 100000L;
        arr[0].cp[i] = (char *)&nodes[i];
    }

    /* The spelling that always worked, as the CONTROL: without it a fix that
     * broke the dotted read would still show 42. */
    if (one.sp[0]->v != 100) return (1);
    if (one.sp[3]->v != 400) return (2);

    /* The reported case: read through an array-of-structs subscript. */
    if (arr[0].sp[0]->v != 100) return (3);
    if (arr[0].sp[2]->v != 300) return (4);
    if (arr[1].sp[0]->v != 400) return (5);     /* reversed */
    if (arr[1].sp[3]->v != 100) return (6);

    /* ...and as a pointer VALUE, not only as a chain base. */
    p = arr[0].sp[1];
    if (p->v != 200) return (7);
    p = arr[1].sp[1];
    if (p->v != 300) return (8);

    /* A LONG array member: the stride is 4, and a stride of 2 would read the
     * high half of the previous element -- a plausible number, not a crash. */
    if (arr[0].lv[0] != 100000L) return (9);
    if (arr[0].lv[3] != 400000L) return (10);
    lq = arr[0].lv;                     /* the decay, same partial list */
    if (lq[2] != 300000L) return (11);

    /* A char-pointer array member. */
    cq = arr[0].cp[2];
    if (cq != (char *)&nodes[2]) return (12);

    /* The base must not be disturbed by any of it. */
    if (nodes[0].v != 100 || nodes[3].v != 400) return (13);
    return (42);
}
