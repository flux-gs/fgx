/* long double constants -- increment 5 of apple/fgx#447
 * (docs/history/plans/2026-09-23-fcc-64bit-double-plan.md).  K&R A.2.5.3:
 * "L or l makes it long double, otherwise it is double", and both are the
 * 64-bit IEEE double, read on the host with strtod; an F constant is the
 * single, and widens to exactly what assigning it at run time stores.
 * Covered: L constants in expressions and under sizeof, static initializers of a
 * scalar, a static local, a flat, a nested and an unsized array, and a
 * struct member, from L, unsuffixed, integer, long long, unsigned and
 * character constants, negated; and a constant whose integer part is past 64
 * bits, which is still a floating constant.  Every expected bit pattern was
 * computed on the host in IEEE double.  A failing check returns its number;
 * all passing returns 42. */
struct s { int t; long double v; };
struct s gs = { 5, -0.1L };
long double g1 = 0.1L, g2 = -2.5L, g3 = 3, g4 = 40000, g5 = -1;
long double g6 = 4294967296, g7 = 0xFFFF, g8 = 'A', g9 = 1e300L;
long double gw = 0.1;
long double ga[3] = { 1.0L, -0.1L, 7 };
long double gm[2][2] = { { 1, 2 }, { 3, 4 } };
long double gu[] = { 1, 2, 3 };
int gi = 2.5L;
float gf = 0.5L;
long double g5p32 = 23283064365386962890625.L;  /* 5^32, past 64 bits */

static int
is(p, hi, lo)
    long double *p;
    long hi, lo;
{
    long *h = (long *)p;
    return h[0] == lo && h[1] == hi;
}

static long double
local_static()
{
    static long double sl = -0.1L;
    return sl;
}

int
main()
{
    long double a, b;
    float f;

    a = 0.1L;               if (!is(&a, 0x3FB99999L, 0x9999999AL)) return 1;
    a = 9007199254740991.0L; if (!is(&a, 0x433FFFFFL, 0xFFFFFFFFL)) return 2;
    a = 1.0L / 3;           b = 0.333333333333333314829616256247L;
                            if (a != b) return 3;
    a = 1.5L + 1;           if (!is(&a, 0x40040000L, 0x00000000L)) return 4;
    a = -0.1L;              if (!is(&a, 0xBFB99999L, 0x9999999AL)) return 5;
    a = 0.1;                if (!is(&a, 0x3FB99999L, 0x9999999AL)) return 6;
    a = 0.1f;               if (!is(&a, 0x3FB99999L, 0xA0000000L)) return 31;
    f = 0.5L;               if (f != 0.5f) return 7;
    if (sizeof 1.5L != 8 || sizeof(1.5l) != sizeof(long double)) return 8;
    if (sizeof 1.5f != 4) return 9;

    if (!is(&g1, 0x3FB99999L, 0x9999999AL)) return 10;
    if (!is(&g2, 0xC0040000L, 0x00000000L)) return 11;
    if (!is(&g3, 0x40080000L, 0x00000000L)) return 12;
    if (!is(&g4, 0x40E38800L, 0x00000000L)) return 13;
    if (!is(&g5, 0xBFF00000L, 0x00000000L)) return 14;
    if (!is(&g6, 0x41F00000L, 0x00000000L)) return 15;
    if (!is(&g7, 0x40EFFFE0L, 0x00000000L)) return 16;
    if (!is(&g8, 0x40504000L, 0x00000000L)) return 17;
    if (!is(&g9, 0x7E37E43CL, 0x8800759CL)) return 18;
    a = 0.1;                if (gw != a) return 19;
    if (!is(&ga[0], 0x3FF00000L, 0x00000000L)) return 20;
    if (!is(&ga[1], 0xBFB99999L, 0x9999999AL)) return 21;
    if (!is(&ga[2], 0x401C0000L, 0x00000000L)) return 22;
    if (!is(&gm[0][1], 0x40000000L, 0x00000000L)) return 23;
    if (!is(&gm[1][1], 0x40100000L, 0x00000000L)) return 24;
    if (sizeof gu != 24 || !is(&gu[2], 0x40080000L, 0x00000000L)) return 25;
    if (gs.t != 5 || !is(&gs.v, 0xBFB99999L, 0x9999999AL)) return 26;
    a = local_static();     if (!is(&a, 0xBFB99999L, 0x9999999AL)) return 27;
    if (gi != 2) return 28;
    if (gf != 0.5f) return 29;
    if (!is(&g5p32, 0x4493B8B5L, 0xB5056E17L)) return 30;
    return 42;
}
