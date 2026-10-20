/* structptr_index_field: a struct-POINTER indexed, then a member STORE --
 * `tc[i].field = rhs` (tcsh tc.func `tcache[i].user = strsave(...)`, tcache a
 * `struct tildecache *`).  The per-shape statement handlers cover the struct-
 * ARRAY twin `arr[i].field` but not a struct-POINTER base; routed to the uniform
 * K&R walker (peek_structptr_index_field, gated on LT_STRUCT_PTR so the array
 * twin is untouched): the INDEX step derefs the pointer and scales, then DOT
 * adds the member offset.  K&R A.7.3.1 (E1[E2]==*(E1+E2)), A.7.3.3 (`.`).  -> 42. */
struct T { int hlen; int *up; };
struct T pool[8];
struct T *tc;

int
main()
{
    int a;

    a  = 30;
    tc = pool;

    tc[0].hlen = 40;        /* int-field store   */
    tc[0].up   = &a;        /* ptr-field store   */
    tc[1].hlen = 2;
    tc[0].hlen -= 8;        /* compound  -> 32   */
    tc[1].hlen++;           /* incdec    -> 3    */

    /* read back: 32 + 3 + *(&a)=30 ... = 65; trim to 42 via a's contribution */
    a = 7;                  /* tc[0].up still points at a */
    return tc[0].hlen + tc[1].hlen + *tc[0].up;   /* 32 + 3 + 7 == 42 */
}
