/* lvalue_named_mixed: a NAMED-base MIXED dot-then-arrow chain store/compound --
 * `t->L.ip->flag |= v` (tcsh sh.sem `t->L.T_dcar->t_dflg |=`, sh.parse
 * `alout.next->word =`).  The per-shape handlers reach the struct-ptr via the
 * mixed chain then stop; the uniform K&R lvalue walker (peek_mixed_lvalue_store
 * -> build_lvalue_suffixes -> S_LV_STORE) computes the address and RMWs.  The
 * stores modify `i` through the chain, read back directly.  -> 42. */
struct inner  { int flag; };
struct outer  { struct inner *ip; int pad; };
struct outer2 { struct outer L; };

int
main()
{
    struct inner  i;
    struct outer2 o2;
    struct outer2 *t;

    i.flag  = 0;
    o2.L.ip = &i;
    t = &o2;

    t->L.ip->flag |= 40;      /* mixed chain compound-or */
    t->L.ip->flag += 2;       /* mixed chain compound-add */

    return i.flag;            /* 40 | (then +2) == 42 */
}
