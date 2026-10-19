/* addr_grouped_operand: '&' of an operand wrapped in a redundant grouping paren
 * -- `&((p)[i])`, `&(p)->m` (tcsh sh.dir's UC(&((c)[1])) in ISDOTDOT).  The '&'
 * arm's greedy amp-paren loop ate the operand's own '(' as if it were an
 * amp-wrap, so the trailing `[`/`->` mis-associated ("expected ')'").  The fix
 * gives a grouping ')' back when a postfix op follows it.  K&R A.7.4.2 ('&' of
 * any lvalue), A.7.3.1 (E1[E2]).  -> 42. */
struct S { int m; int n; };

int
main()
{
    int       arr[4];
    int      *p;
    struct S  s;
    struct S *sp;
    int       r;

    arr[0] = 10; arr[1] = 20; arr[2] = 30; arr[3] = 5;
    p  = arr;
    s.m = 7; s.n = 99;
    sp = &s;

    r  = (&((p)[1]))[0];   /* &p[1] then [0] == p[1]        -> 20 */
    r += (&((p)[3]))[0];   /* p[3]                          -> +5  = 25 */
    r += *(&(sp)->m);      /* &(sp)->m deref == sp->m       -> +7  = 32 */
    r += *(&((p)[0]));     /* &p[0] deref == p[0]           -> +10 = 42 */

    return r;
}
