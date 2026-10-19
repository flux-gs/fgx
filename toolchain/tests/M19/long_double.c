/* `long double' is a type.  K&R A.4.2: single, double and "extra precision
 * floating point (long double) may be synonymous, but the ones later in the
 * list are at least as precise as those before".  long double is fcc's 64-bit
 * IEEE double; double is the 32-bit single until the two become one type
 * (docs/history/plans/2026-09-23-fcc-64bit-double-plan.md).  It did not parse
 * at all once: `long' took the declaration and `double' was left behind as a
 * stray token ("expected declarator name").
 *
 * Every place a type name is written: a global, a local, a struct member, a
 * cast, sizeof, and a K&R parameter.  Nothing here reads a long double as a
 * number, which the 64-bit runtime has yet to provide, so a value is a bit
 * pattern copied through each place.  Exits 42 iff each carries the value
 * and the size of a long double. */
long double g;

struct s { int tag; long double v; };
struct s sv;

long double
same(x)
    long double x;
{
    return x;
}

static int
bits(p, hi, lo)
    long double *p;
    long hi, lo;
{
    long *h = (long *)p;
    return h[0] == lo && h[1] == hi;
}

int
main()
{
    long double l;
    long *h = (long *)&l;
    int ok;

    ok = 0;
    h[0] = 0L;
    h[1] = 0x40080000L;                     /* 3.0 */
    g = (long double)l;
    if (bits(&g, 0x40080000L, 0L))
        ok += 10;
    if (sizeof(long double) == 8 && sizeof l == 8 &&
        sizeof(long double) >= sizeof(double))
        ok += 10;
    sv.v = l;
    if (bits(&sv.v, 0x40080000L, 0L) && sizeof sv == sizeof(int) + 8)
        ok += 11;
    l = same(g);
    if (bits(&l, 0x40080000L, 0L))
        ok += 11;
    return ok;
}
