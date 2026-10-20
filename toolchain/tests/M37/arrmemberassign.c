/* arrmemberassign.c -- `arr[i].m = <struct>' on a struct-ARRAY element.
 * apple/fgx#207's second silent cell, and it has a file of its own for a
 * reason worth stating.
 *
 * memberstructassign.c covers the whole eight-by-five matrix, but almost
 * every cell it added was a REJECT before the fix -- so that file does not
 * COMPILE against the old compiler and its red is a build failure.  This one
 * uses only shapes the old compiler accepted, so it compiles both ways and
 * its red is a WRONG EXIT CODE: the failure mode of the defect itself, which
 * is the thing a fixture for a SILENT miscompile has to be able to show.
 *
 * WHAT WAS WRONG.  `arr[i].m = g' fell through to the scalar field store,
 * which wrote two bytes of the SOURCE'S ADDRESS over the member.  It is the
 * same fault as `p->m = g' one hop further out, and it was found only by
 * re-running the matrix AFTER fixing that one -- the twin the parser's own
 * comment predicts ("fixing `s.pa[i] = p;' left `arr[k].pa[i] = p;' still
 * dying ... apple/fgx#155's lesson is that fcc has twin arms for most lvalue
 * shapes and they have to be fixed in pairs").
 *
 * THE NEIGHBOURING ELEMENTS ARE CHECKED, not just the target.  The index
 * scale and the member offset are added by the same node, so a fix that got
 * one and not the other emits a perfectly good copy loop into the WRONG
 * ELEMENT -- which every check on the target alone would miss.
 *
 * Exit 42.
 */

struct inner {
    unsigned short  a;
    long            b;
    unsigned short  c;
};

struct outer {
    unsigned short  head;
    struct inner    m;
    unsigned short  tail;
};

struct inner g_src;
struct outer g_arr[3];

int
main()
{
    struct outer *q;
    int           i;

    g_src.a = 0x1234;
    g_src.b = 0x11223344L;
    g_src.c = 0x5678;

    for (i = 0; i < 3; i++) {
        q = &g_arr[i];
        q->head = 0xAAAA;
        q->m.a  = 0;
        q->m.b  = 0L;
        q->m.c  = 0;
        q->tail = 0xBBBB;
    }

    i = 1;
    g_arr[i].m = g_src;

    q = &g_arr[1];
    if (q->m.a != 0x1234)      return (1);
    if (q->m.b != 0x11223344L) return (2);   /* past the first two bytes */
    if (q->m.c != 0x5678)      return (3);
    if (q->head != 0xAAAA)     return (4);   /* nothing before it moved */
    if (q->tail != 0xBBBB)     return (5);   /* and nothing after it */

    q = &g_arr[0];
    if (q->m.b != 0L)          return (6);   /* the element before */
    q = &g_arr[2];
    if (q->m.b != 0L)          return (7);   /* and the one after */

    return (42);
}
