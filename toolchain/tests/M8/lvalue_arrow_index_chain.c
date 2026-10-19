/* lvalue_arrow_index_chain: pure-arrow lvalue chains that cross a subscript at
 * depth >= 2 arrows -- the shapes the per-shape statement store handlers miss,
 * now routed to the uniform K&R walker (peek_mixed_lvalue_store broadened;
 * K&R Appendix A.7.3 postfix grammar: `.`/`->`/`[]` are one recursive
 * left-to-right production and `E1[E2]` == `*((E1)+(E2))`, so a chain's
 * address is one uniform walk regardless of the `->`/`[]` mix).
 *   (a) double-arrow then a TRAILING index:  p->next->buf[i] = c
 *       (tcsh tc.who `wholist->w_next->w_tty[i] = ...`)
 *   (b) an index followed by a further arrow+dot: p->kids[j]->val = n
 *       (tcsh sh.set `p->v_link[0]->v_bal = ...`)
 * Both compute the leaf ADDRESS through emit_lvalue_addr (bank preserved) then
 * store by leaf type.  Read back directly.  -> 42. */
struct node {
    struct node *next;
    struct node *kids[4];
    char         buf[8];
    int          val;
};

int
main()
{
    struct node a, b, c;
    struct node *p;

    p = &a;
    p->next    = &b;           /* setup via supported arrow stores */
    p->kids[2] = &c;

    p->next->buf[3] = 10;      /* (a) arrow, arrow, index  -> b.buf[3] = 10 */
    p->kids[2]->val = 32;      /* (b) arrow, index, arrow, dot -> c.val = 32 */

    return b.buf[3] + c.val;   /* 10 + 32 == 42 */
}
