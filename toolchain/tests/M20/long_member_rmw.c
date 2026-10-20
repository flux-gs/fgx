/* long_member_rmw: 32-bit ++/-- on a LONG struct member -- postfix, prefix,
 * and statement forms, all CARRY-sensitive.  Previously the member incdec (and
 * the S_COMPOUND_MEMBER `+=1` desugar) touched only the low 16-bit word, so an
 * inc across a 16-bit boundary lost the carry.  tcsh sh.time
 * `tsum->tv_sec++, ...`.  -> 42. */
struct s { long a; long b; };

int
main()
{
    struct s  x;
    struct s *p;
    long      old, nw;
    int       carry_ok, borrow_ok, post_ok, pre_ok;

    p = &x;

    x.a = 0xFFFFL;              /* 65535 */
    p->a++;                     /* carry -> 0x10000 (65536) */
    carry_ok = (x.a == 0x10000L) ? 10 : 0;

    x.b = 0x10000L;            /* 65536 */
    p->b--;                     /* borrow -> 0xFFFF (65535) */
    borrow_ok = (x.b == 0xFFFFL) ? 10 : 0;

    x.a = 20L;
    old = p->a++;               /* postfix: old==20, x.a==21 */
    post_ok = (old == 20L && x.a == 21L) ? 10 : 0;

    x.b = 41L;
    nw = ++p->b;                /* prefix: new==42 */
    pre_ok = (nw == 42L) ? 12 : 0;

    return carry_ok + borrow_ok + post_ok + pre_ok;   /* 10+10+10+12 == 42 */
}
