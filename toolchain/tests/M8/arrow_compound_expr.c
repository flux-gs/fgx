/* arrow_compound_expr: `p->field op= rhs` as an EXPRESSION (comma operand) --
 * the arrow twin of the dot-field `t.flags op= rhs` desugar.  build_assign's
 * arrow branch handled `p->f = rhs` but not `p->f op= rhs`, so a compound
 * arrow-member assign in expression context (tcsh sh.time
 * `tsum->tv_sec++, tsum->tv_usec -= 1000000`) failed.  Now it desugars to
 * N_ARROW_LOAD_CHAIN read -> N_BINOP -> N_STORE_MEMBER, int and long.  -> 42. */
struct s { int i; long a; long b; };

int
main()
{
    struct s  x;
    struct s *p;

    p = &x;
    x.i = 10;
    x.a = 41;
    x.b = 1000000L;

    /* comma operands: int compound, long postfix, long compound */
    p->i -= 4, p->a++, p->b -= 999994L;    /* i=6, a=42, b=6 */

    return (int)(p->i + p->a + p->b - 12);  /* 6 + 42 + 6 - 12 == 42 */
}
