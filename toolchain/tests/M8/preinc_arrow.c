/* preinc_arrow: prefix ++/-- on a `->` struct-member statement -- `++p->m;`
 * (tcsh glob `++pglob->gl_matchc;`).  Desugars to `p->f += 1`, the same node
 * the `p->f op= rhs` arm builds.  fcc handled `++IDENT`, `++*ptr`, and `++x.f`
 * (dot member) but the arrow form died 'expected ;'.  -> 42. */
struct S { int m; int n; };

int
main()
{
    struct S s;
    struct S *p;
    p = &s;
    s.m = 40; s.n = 5;
    ++p->m;                 /* s.m = 41 */
    --p->n;                 /* s.n = 4  */
    return p->m + p->n - 3; /* 41 + 4 - 3 == 42 */
}
