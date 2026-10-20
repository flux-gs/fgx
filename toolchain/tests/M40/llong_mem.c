/* long long through every access path -- sub-increment 1e of the C99
 * extension (docs/history/plans/2026-09-23-fcc-long-long-plan.md); not K&R.
 * 64-bit literals (LL, ULL, and a value past unsigned long), a pointer, a
 * subscripted pointer, local and global arrays, members by `.' and `->',
 * compound assignment through each, ++/-- on variables and on elements, and
 * static and automatic initializers.
 * Stores are read back through `long *' views, so a store that writes two or
 * four bytes of the eight shows.  A failing check returns its number; all
 * passing returns 42. */
struct s { int t; long long v; int w; };
struct s gs;
long long g, garr[3], *p;
int n = 1;
long long gi1 = 0x0123456789ABCDEFLL, gi2 = -2, gi3[4] = { 1, -1LL, 0x100000000LL };
unsigned long long gi4 = 5000000000;
struct s gsi = { 7, 0x1122334455667788LL, 9 };
long long *gip = &gi3[2];

static int
is(x, hi, lo)
    long long *x;
    long hi, lo;
{
    long *h = (long *)x;
    return h[0] == lo && h[1] == hi;
}

int
main()
{
    long long a, b, arr[4];
    unsigned long long u;
    struct s st, *sp = &gs;
    int i;
    static long long sl = -5;
    long long la[3] = { 5, -1 };
    struct s ls = { 1, -3, 2 };

    /* literals */
    a = 0x0123456789ABCDEFLL;
    if (!is(&a, 0x01234567L, 0x89ABCDEFL)) return 1;
    u = 0xFFFFFFFFFFFFFFFFULL;
    if (!is((long long *)&u, -1L, -1L)) return 2;
    a = 5000000000;                     /* past unsigned long: long long */
    if (!is(&a, 1L, 0x2A05F200L)) return 3;
    a = 1LL << 40;
    if (!is(&a, 0x100L, 0L) || a != 0x10000000000LL) return 4;
    if (sizeof(struct s) != 12 || sizeof 5000000000 != 8) return 5;

    /* through a pointer, and a subscripted one */
    p = garr;
    a = 0x0123456789ABCDEFLL;
    *p = a;                    if (!is(&garr[0], 0x01234567L, 0x89ABCDEFL)) return 6;
    b = *p;                    if (b != a) return 7;
    p[1] = a + 1;              if (!is(&garr[1], 0x01234567L, 0x89ABCDF0L)) return 8;
    b = p[n];                  if (b != a + 1) return 9;

    /* local and global arrays */
    arr[2] = a;                if (!is(&arr[2], 0x01234567L, 0x89ABCDEFL)) return 10;
    b = arr[n + 1];            if (b != a) return 11;
    garr[2] = -a;              if (!is(&garr[2], 0xFEDCBA98L, 0x76543211L)) return 12;
    b = garr[n + 1];           if (b != -a) return 13;

    /* members, by `.' and `->' */
    st.t = 7; st.w = 9;
    st.v = a;                  if (!is(&st.v, 0x01234567L, 0x89ABCDEFL)) return 14;
    if (st.t != 7 || st.w != 9) return 15;
    b = st.v;                  if (b != a) return 16;
    sp->v = ~a;                if (!is(&gs.v, 0xFEDCBA98L, 0x76543210L)) return 17;
    b = sp->v;                 if (b != ~a) return 18;
    b = gs.v;                  if (b != ~a) return 19;

    /* compound assignment through each path */
    *p += 0x100000000LL;       if (*p != a + 0x100000000LL) return 20;
    arr[1] = 3; arr[1] *= a;   if (arr[1] != a * 3) return 21;
    st.v -= 1;                 if (st.v != a - 1) return 22;
    garr[1] |= 0xF000000000000000LL;
    if (!is(&garr[1], 0xF1234567L, 0x89ABCDF0L)) return 23;
    sp->v <<= 4;               if (sp->v != ~a << 4) return 24;

    /* ++ and -- on variables and on elements */
    a = 0xFFFFFFFFLL;
    b = a++;                   if (b != 0xFFFFFFFFLL || a != 0x100000000LL) return 25;
    b = --a;                   if (b != 0xFFFFFFFFLL || a != b) return 26;
    g = -1;
    g++;                       if (g != 0) return 27;
    --g;                       if (g != -1) return 28;
    garr[0] = 0xFFFFFFFFFFFFLL;
    (*p)++;                    if (garr[0] != 0x1000000000000LL) return 29;
    arr[3] = 0; arr[3]--;      if (arr[3] != -1) return 30;
    st.v = 0x7FFFFFFFFFFFFFFFLL;
    st.v++;                    if (!is(&st.v, 0x80000000L, 0L)) return 31;

    /* a narrower target of a long long op= computes at 64 bits */
    i = 30000;
    a = 0x100000000LL;
    i /= a;                    if (i != 0) return 32;   /* 30000 / 2^32 */
    i = 7;
    i += a;                    if (i != 7) return 33;   /* low word of 2^32+7 */

    /* static and automatic initializers */
    if (!is(&gi1, 0x01234567L, 0x89ABCDEFL) || gi2 != -2) return 34;
    if (gi3[0] != 1 || gi3[1] != -1 || !is(&gi3[2], 1L, 0L) || gi3[3] != 0)
        return 35;
    if (!is((long long *)&gi4, 1L, 0x2A05F200L)) return 36;
    if (gsi.t != 7 || !is(&gsi.v, 0x11223344L, 0x55667788L) || gsi.w != 9)
        return 37;
    if (*gip != 0x100000000LL || sl != -5) return 38;
    if (la[0] != 5 || la[1] != -1 || la[2] != 0) return 39;
    if (ls.t != 1 || ls.v != -3 || ls.w != 2) return 40;
    return 42;
}
