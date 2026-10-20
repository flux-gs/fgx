/* long double's storage -- increment 2 of apple/fgx#447
 * (docs/history/plans/2026-09-23-fcc-64bit-double-plan.md).  long double and
 * double are one type, the 64-bit IEEE double, which K&R A.4.2 allows ("may
 * be synonymous, but the ones later in the list are at least as precise as
 * those before").  Every value here is a bit pattern
 * set and checked through `long' views, and every word of the eight differs.
 * It is copied through each place a value can be kept or passed.  A failing
 * check returns its number; all passing returns 42. */
struct s { int t; long double v; int w; };
struct s gs, gs2;
long double g, garr[3], *gp;

static void
put(p, hi, lo)
    long double *p;
    long hi, lo;
{
    long *h = (long *)p;
    h[0] = lo;
    h[1] = hi;
}

static int
is(p, hi, lo)
    long double *p;
    long hi, lo;
{
    long *h = (long *)p;
    return h[0] == lo && h[1] == hi;
}

long double
ident(long double x)
{
    return x;
}

long double
kr(x)
    long double x;
{
    long double y;

    y = x;
    return y;
}

long double
pick(c, x, y)
    int c;
    long double x, y;
{
    return c ? x : y;
}

int
main()
{
    long double a, b, arr[4], *p;
    struct s st, *sp;
    struct s ls = { 1 };
    int n = 1;

    if (sizeof(long double) != 8 || sizeof a != 8 || sizeof arr != 32)
        return 1;
    if (sizeof(struct s) != 12 || sizeof(double) != 8)
        return 2;

    put(&a, 0x40091EB8L, 0x51EB851FL);          /* 3.14 */
    b = a;                  if (!is(&b, 0x40091EB8L, 0x51EB851FL)) return 3;
    g = b;                  if (!is(&g, 0x40091EB8L, 0x51EB851FL)) return 4;
    put(&b, 0xC0FE2400L, 0x12345678L);
    a = g;                  if (!is(&a, 0x40091EB8L, 0x51EB851FL)) return 5;

    arr[2] = b;             if (!is(&arr[2], 0xC0FE2400L, 0x12345678L)) return 6;
    a = arr[n + 1];         if (!is(&a, 0xC0FE2400L, 0x12345678L)) return 7;
    garr[1] = g;            if (!is(&garr[1], 0x40091EB8L, 0x51EB851FL)) return 8;
    a = garr[n];            if (!is(&a, 0x40091EB8L, 0x51EB851FL)) return 9;

    p = &arr[1];
    *p = b;                 if (!is(&arr[1], 0xC0FE2400L, 0x12345678L)) return 10;
    p[1] = g;               if (!is(&arr[2], 0x40091EB8L, 0x51EB851FL)) return 11;
    a = p[n];               if (!is(&a, 0x40091EB8L, 0x51EB851FL)) return 12;
    gp = garr;
    gp[2] = *p;             if (!is(&garr[2], 0xC0FE2400L, 0x12345678L)) return 13;

    st.t = 7; st.w = 9;
    st.v = b;               if (!is(&st.v, 0xC0FE2400L, 0x12345678L)) return 14;
    if (st.t != 7 || st.w != 9) return 15;
    sp = &gs;
    sp->v = st.v;           if (!is(&gs.v, 0xC0FE2400L, 0x12345678L)) return 16;
    gs2 = gs;               if (!is(&gs2.v, 0xC0FE2400L, 0x12345678L)) return 17;
    a = sp->v;              if (!is(&a, 0xC0FE2400L, 0x12345678L)) return 18;

    a = ident(g);           if (!is(&a, 0x40091EB8L, 0x51EB851FL)) return 19;
    a = kr(b);              if (!is(&a, 0xC0FE2400L, 0x12345678L)) return 20;
    a = pick(1, g, b);      if (!is(&a, 0x40091EB8L, 0x51EB851FL)) return 21;
    a = pick(0, g, b);      if (!is(&a, 0xC0FE2400L, 0x12345678L)) return 22;
    a = n ? b : g;          if (!is(&a, 0xC0FE2400L, 0x12345678L)) return 23;
    a = (long double)g;     if (!is(&a, 0x40091EB8L, 0x51EB851FL)) return 24;
    a = st.v = g;           if (!is(&a, 0x40091EB8L, 0x51EB851FL) ||
                                !is(&st.v, 0x40091EB8L, 0x51EB851FL)) return 25;
    /* A.8.7: the members past a short list "are initialized with 0". */
    if (ls.t != 1 || !is(&ls.v, 0L, 0L) || ls.w != 0) return 26;
    return 42;
}
