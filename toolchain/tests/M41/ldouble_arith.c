/* long double arithmetic through the soft double -- increment 3 of
 * apple/fgx#447 (docs/history/plans/2026-09-23-fcc-64bit-double-plan.md).
 * Every expected bit pattern was computed on the host in IEEE double.  Values
 * a single cannot hold (1/3 to 53 bits, 2^53 - 1) show that the arithmetic is
 * 64-bit; a NaN is built from its bits, since a quiet NaN has no spelling.
 * Covered: the four operators, compares ordered and unordered, truth tests
 * (-0.0 is false, a NaN true), negation, conversion from int, unsigned, long,
 * unsigned long and float and back, ++ and -- through each kind of lvalue,
 * op= at either width, the usual conversions with an int on either side,
 * `?:' and argument passing.  A failing check returns its number; all
 * passing returns 42. */
struct s { int t; long double v; };
struct s gs;
long double g, garr[2];

static int
is(p, hi, lo)
    long double *p;
    long hi, lo;
{
    long *h = (long *)p;
    return h[0] == lo && h[1] == hi;
}

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
trunc3(x)
    int x;
{
    return x;
}

static long double
half(long double x)
{
    return x / 2;
}

int
main()
{
    long double a, b, c, z, nan, *p;
    unsigned u = 40000;
    unsigned long ul = 3000000000UL;
    long l = 70000L;
    int i;
    float f;

    a = 1;
    b = 3;
    c = a / b;              if (!is(&c, 0x3FD55555L, 0x55555555L)) return 1;
    c = -c;                 if (!is(&c, 0xBFD55555L, 0x55555555L)) return 2;
    c = 7 * (a / b);        if (!is(&c, 0x4002AAAAL, 0xAAAAAAAAL)) return 3;
    c = a / b + 2;          if (!is(&c, 0x4002AAAAL, 0xAAAAAAABL)) return 4;
    c = u;                  c = c / 7;
                            if (!is(&c, 0x40B65249L, 0x24924925L)) return 5;
    c = l * -3;             if (!is(&c, 0xC109A280L, 0x00000000L)) return 6;
    c = ul;                 if (!is(&c, 0x41E65A0BL, 0xC0000000L)) return 7;
    if ((unsigned long)c != 3000000000UL) return 8;
    c = 4294967296.0;       /* 2^32, exact in a float */
    c = c * 2097152 - 1;    if (!is(&c, 0x433FFFFFL, 0xFFFFFFFFL)) return 9;
    c++;                    if (!is(&c, 0x43400000L, 0x00000000L)) return 10;

    /* compares, and a NaN, which is unordered with everything */
    put(&nan, 0x7FF80000L, 0L);
    if (!(a < b) || a > b || !(a <= b) || a >= b || a == b || !(a != b))
        return 11;
    if (!(b <= 3) || !(b >= 3) || !(3 == b) || b < 3 || b > 3) return 12;
    if (nan < a || nan > a || nan <= a || nan >= a || nan == nan) return 13;
    if (!(nan != nan)) return 14;

    /* truth: -0.0 is false, a NaN is true */
    z = 0;
    z = -z;                 if (!is(&z, 0x80000000L, 0L)) return 15;
    if (z || !nan || !a) return 16;
    if (!(z == 0)) return 17;

    /* back to integers and float: the fraction goes (A.6.3) */
    c = -5;  c = c / 2;     /* -2.5 */
    if ((long)c != -2L || (int)c != -2) return 18;
    c = 79;  c = c / 10;    /* 7.9 */
    i = c;                  if (i != 7) return 19;
    /* A.6.4 allows either neighbour; the soft double takes the nearest,
     * where truncation would give 0x3EAAAAAA. */
    f = a / b;              if (*(long *)&f != 0x3EAAAAABL) return 20;
    f = 0.1;  c = f;        if (!is(&c, 0x3FB99999L, 0xA0000000L)) return 21;

    /* ++, -- and op= through variables, elements, members and pointers */
    g = 10;  g++;  ++g;  g--;
    if (g != 11) return 22;
    garr[1] = 1;  p = &garr[1];
    (*p)++;  p[0] += 0.5;
    if (garr[1] != 2.5) return 23;
    gs.v = 4;  gs.v *= b;  gs.v -= 1;
    if (gs.v != 11) return 24;
    i = 7;  i += a / b;     /* 7.333... narrowed */
    if (i != 7) return 25;
    a += 2;                 if (a != 3) return 26;

    /* ?:, and arguments converted as if by assignment */
    c = u > 1 ? a : 1;      if (c != 3) return 27;
    c = u < 1 ? a : 1;      if (c != 1) return 28;
    if (trunc3(a / 2) != 1) return 29;
    c = half(9);            if (c != 4.5) return 30;
    return 42;
}
