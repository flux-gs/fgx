/* preinc_pderef: prefix ++/-- on a PARENTHESIZED deref statement -- `--(*vp);`
 * / `++(*vp);` (tcsh sh.set `--(*vp);`).  The prefix arm stripped parens then
 * required an IDENT, so `(*vp)` died 'expected identifier after ++/--'; now the
 * paren-wrapped deref RMWs the pointee (same S_PREINC_DEREF as `--*ptr;`).
 * -> 42. */
int
main()
{
    int v;
    int *vp;
    vp = &v;
    v = 41;
    ++(*vp);        /* v = 42 */
    ++(*vp);        /* v = 43 */
    --(*vp);        /* v = 42 */
    return *vp;
}
