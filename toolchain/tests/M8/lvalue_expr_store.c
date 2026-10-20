/* lvalue_expr_store: a multi-step lvalue chain STORE in EXPRESSION context --
 * the shape the per-shape expression arms miss, now routed to the uniform K&R
 * walker as build_assign's last resort (peek_expr_lvalue_store ->
 * build_lvalue_suffixes -> N_LV_STORE_E).  K&R A.7.17: the LHS of an assignment
 * is ANY modifiable lvalue and the expression's value is the value stored --
 * so a chain store nested in a comma / used by an enclosing expression must
 * both store AND leave its value.  Mirrors tcsh sh.parse
 * `t->R.T_dcdr = t->L.T_dcar, t->L.T_dcar = 0`.  -> 42. */
struct inner { int v; };
struct outer { struct inner *ip; int tag; };
struct box   { struct outer L; struct outer R; };   /* arrow-then-dot leaves */

int
main()
{
    struct inner  i;
    struct box    b;
    struct box   *t;
    struct inner *q;
    int           s;

    i.v    = 5;
    b.L.ip = &i;
    t      = &b;

    /* (1) arrow-dot POINTER store as a COMMA operand (value discarded):
     *     move ip from L to R, clear L. */
    t->R.ip = t->L.ip, t->L.ip = 0;

    /* (2) value-leaving plain scalar store: s = (chain = 20) yields 20. */
    s = (t->R.tag = 20);

    /* read the moved pointer back (2-level read) and follow it: +5 -> 25 */
    q  = t->R.ip;
    s += q->v;

    /* (3) value-leaving COMPOUND store: (chain -= 5) yields 15 -> s = 40 */
    s += (t->R.tag -= 5);

    return s + (t->L.ip == 0 ? 2 : 0);   /* 40 + 2 == 42 */
}
