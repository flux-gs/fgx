/* long long conversions in every mix -- sub-increment 1d of the C99 extension
 * (docs/history/plans/2026-09-23-fcc-long-long-plan.md); not K&R, whose rules
 * for the integral types it has (A.6.1, A.6.2, A.6.5, A.7.16, A.9.4) are the
 * ones extended here by one rank.  Every expected value was worked on the host
 * in 64-bit two's complement.  Checks: narrowing stores, widening from each
 * narrower type by ITS signedness, the balance against unsigned int and
 * unsigned long, signed versus unsigned long long compares, ?: in both orders,
 * switch with case constants converted to 64 bits, parameters and returns that
 * narrow and widen, and a condition nonzero only in the top word.  A failing
 * check returns its number; all passing returns 42. */
long long a, b, r;
unsigned long long u, v;

static void
put(p, hi, lo)
    long long *p;
    long hi, lo;
{
    long *h = (long *)p;
    h[0] = lo;
    h[1] = hi;
}

static int
is(x, hi, lo)
    long long x;
    long hi, lo;
{
    long *h = (long *)&x;
    return h[0] == lo && h[1] == hi;
}

static int
uis(x, hi, lo)
    unsigned long long x;
    long hi, lo;
{
    long *h = (long *)&x;
    return h[0] == lo && h[1] == hi;
}

int takes_int(int i) { return i; }
long takes_long(long l) { return l; }
long long takes_ll(long long x) { return x; }
int narrows(long long x) { return x; }

static int
sw(x)
    long long x;
{
    switch (x) {
    case -1:            return 1;
    case 5:             return 2;
    case 0xFFFFFFFF:    return 3;       /* unsigned long: w2/w3 are zero */
    case 0x7FFFFFFFL:   return 4;
    }
    return 9;
}

int
main()
{
    int i, one = 1, zero = 0, n;
    unsigned ui;
    long l;
    unsigned long ul;
    unsigned char uc;

    /* narrowing stores keep the low bits */
    put(&a, 0x01234567L, 0x89ABCDEFL);
    i = a;  if (i != (int)0xCDEF) return 1;
    l = a;  if (l != 0x89ABCDEFL) return 2;
    uc = a; if (uc != 0xEF) return 3;
    ui = a; if (ui != 0xCDEF) return 4;

    /* widening by the source's own signedness */
    uc = 200;             r = uc;  if (!is(r, 0L, 200L)) return 5;
    i = -5;               r = i;   if (!is(r, -1L, -5L)) return 6;
    ui = 65535;           r = ui;  if (!is(r, 0L, 65535L)) return 7;
    l = -70000L;          r = l;   if (!is(r, -1L, -70000L)) return 8;
    ul = 0x89ABCDEFL;     r = ul;  if (!is(r, 0L, 0x89ABCDEFL)) return 9;
    ul = 0x89ABCDEFL;     u = ul;  if (!uis(u, 0L, 0x89ABCDEFL)) return 10;

    /* the balance: long long wins, and holds every unsigned int / long */
    put(&a, -1L, -1L);
    ui = 1;
    r = a + ui;           if (!is(r, 0L, 0L)) return 11;
    r = ui + a;           if (!is(r, 0L, 0L)) return 12;
    if (!(a < ui)) return 13;           /* signed: -1 < 1 */
    put(&b, 0L, 1L);
    ul = 0xFFFFFFFFL;
    r = ul + b;           if (!is(r, 1L, 0L)) return 14;
    r = b + ul;           if (!is(r, 1L, 0L)) return 15;
    l = -2L;
    if (!(a > l) || !(l < a)) return 16;
    /* unsigned long long meets long long: unsigned, so -1 is the maximum */
    put((long long *)&u, 0L, 1L);
    if (u > a) return 17;
    if (!(a > u)) return 18;

    /* ?: takes the common type whichever arm runs */
    i = -3;
    put(&b, 0x00000002L, 0L);
    r = one ? b : i;      if (!is(r, 2L, 0L)) return 19;
    r = zero ? b : i;     if (!is(r, -1L, -3L)) return 20;
    r = one ? i : b;      if (!is(r, -1L, -3L)) return 21;
    ui = 40000;
    r = zero ? b : ui;    if (!is(r, 0L, 40000L)) return 22;

    /* switch: each case constant converted to 64 bits (A.9.4) */
    put(&a, -1L, -1L);                 if (sw(a) != 1) return 23;
    put(&a, 0L, 5L);                   if (sw(a) != 2) return 24;
    put(&a, 0L, 0xFFFFFFFFL);          if (sw(a) != 3) return 25;
    put(&a, 0L, 0x7FFFFFFFL);          if (sw(a) != 4) return 26;
    put(&a, 1L, 5L);                   if (sw(a) != 9) return 27;  /* w2 differs */
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); if (sw(a) != 9) return 28;

    /* parameters and returns, narrowing and widening */
    put(&a, 0x01234567L, 0x89ABCDEFL);
    if (takes_int(a) != (int)0xCDEF) return 29;
    if (takes_long(a) != 0x89ABCDEFL) return 30;
    if (narrows(a) != (int)0xCDEF) return 31;
    i = -7;
    if (!is(takes_ll(i), -1L, -7L)) return 32;
    ul = 0xFFFFFFFFL;
    if (!is(takes_ll(ul), 0L, 0xFFFFFFFFL)) return 33;

    /* a condition sees every word */
    put(&a, 0x00010000L, 0L);          /* nonzero in w2 only */
    put(&b, 0L, 1L);
    n = 0;
    while (a && n < 3) {
        n++;
        if (n == 2)
            a = a - a;
    }
    if (n != 2) return 34;
    return 42;
}
