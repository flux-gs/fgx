/* lvalue_computed_base: store through a COMPUTED pointer base --
 * `(q + n)->field [op]= rhs` -- which no per-shape store handler covers
 * (tcsh alloc11 `(q + nw)->ptr = allocx`).  Routed through the new uniform
 * K&R-canonical lvalue-address walker (docs plan
 * 2026-07-23-fcc-uniform-lvalue-walker.md).  -> 42. */
struct hdr { int busy; char *ptr; };

int
main()
{
    struct hdr  arr[4];
    char        buf[4];
    struct hdr *q, *r;

    buf[0] = 'Z';
    q = arr;

    (q + 2)->ptr  = buf;      /* computed base, pointer-leaf store */
    (q + 2)->busy = 40;       /* computed base, int-leaf store     */
    (q + 2)->busy += 2;       /* computed base, int compound       */

    r = q + 2;                /* read back via a plain pointer      */
    return (r->ptr == buf) ? r->busy : 0;   /* 40 + 2 == 42 */
}
