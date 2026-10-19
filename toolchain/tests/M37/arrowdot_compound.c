/* apple/fgx#280: COMPOUND assignment whose lvalue is a nested struct field
 * reached through a POINTER -- `p->a.b &= v'.  Arrow-then-dot was the one
 * chain shape peek_mixed_lvalue_store did not classify (it routed the mirror,
 * dot-then-arrow, all along), so it fell past every arm and died
 * "expected '='" -- while the hand-expanded `p->a.b = p->a.b & v' compiled.
 *
 * K&R A.7.17: "All require an lvalue as left operand, and the lvalue must be
 * modifiable", and "An expression of the form E1 op= E2 is equivalent to
 * E1 = E1 op (E2) except that E1 is evaluated only once."  Nothing restricts
 * the lvalue's SHAPE, so the reject was artificial.
 *
 * The VALUE is checked, not just the parse: a wrong address computation would
 * still compile.  Each arm also asserts a NEIGHBOURING member is untouched,
 * which is what catches a store that lands one field early or late.
 * Exits 42 iff all three land (14 + 14 + 14). */
struct inner { unsigned short lo; unsigned short hi; };
struct outer { unsigned short guard0; struct inner a; unsigned short guard1; };

struct outer g;

int
main()
{
    struct outer *p;
    int r = 0;

    p = &g;

    g.guard0 = 0xAAAA; g.guard1 = 0x5555;
    g.a.lo = 0x00FF; g.a.hi = 0x1234;
    p->a.lo &= 0x000F;                  /* 0x00FF & 0x000F == 0x000F */
    if (g.a.lo == 0x000F && g.a.hi == 0x1234 &&
        g.guard0 == 0xAAAA && g.guard1 == 0x5555)
        r += 14;

    g.a.hi = 0x1200;
    p->a.hi |= 0x0034;                  /* 0x1200 | 0x0034 == 0x1234 */
    if (g.a.hi == 0x1234 && g.a.lo == 0x000F &&
        g.guard0 == 0xAAAA && g.guard1 == 0x5555)
        r += 14;

    g.a.lo = 100;
    p->a.lo += 23;                      /* the arithmetic form, not just bitwise */
    if (g.a.lo == 123 && g.a.hi == 0x1234 &&
        g.guard0 == 0xAAAA && g.guard1 == 0x5555)
        r += 14;

    return r;
}
