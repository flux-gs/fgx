/* lvalue_chain_read: a multi-step chain READ whose `.field` bridges to a further
 * `->` (mid-chain dot) -- `t->L.cp->field`, the shape the pure-arrow read chain
 * (N_ARROW_CHAIN) cannot follow because it continues only struct-ptr fields
 * reached BY an arrow.  Routed to the uniform K&R walker (peek_chain_dot_bridges
 * -> build_lvalue_suffixes -> N_LV_LOAD_E): emit_lvalue_addr computes the leaf
 * address, then emit_fpr_deref_field loads it -- a scalar into A, a char into A
 * (zero-extended), a POINTER leaf as a full far pointer into the fpr.  Mirrors
 * tcsh sh.sem `t->L.T_dcar->t_dflg`.  K&R A.7.3 (one postfix production),
 * A.7.4.3 ('*'/deref an lvalue).  -> 42. */
struct C { struct C *nx; int dflg; char tag; };
struct O { union { struct C *cp; } L; };

int
main()
{
    struct C  c;
    struct O  o;
    struct O *t;
    struct C *q;
    int       s;

    c.dflg = 30; c.tag = 10; c.nx = &c;
    o.L.cp = &c;
    t = &o;

    s  = t->L.cp->dflg;             /* arrow-dot-arrow, int leaf   -> 30 */
    s += t->L.cp->tag;              /* char leaf (zero-extended)   -> +10 = 40 */
    q  = t->L.cp->nx;               /* POINTER leaf (far-ptr load) */
    s += (q == &c ? 2 : 0);         /* q must round-trip to &c     -> +2 = 42 */

    return s;
}
