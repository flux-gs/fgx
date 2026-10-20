/* Default argument promotion -- increment 4 of apple/fgx#447
 * (docs/history/plans/2026-09-23-fcc-64bit-double-plan.md).  K&R A.7.3.2:
 * with an old-style declaration in scope, or past a `...', "each float
 * argument is converted to double".  A.10.1: an old-style float parameter
 * keeps its declared type ("the first edition specified that the
 * declarations of float parameters were adjusted to read double"), so it is
 * received as a double, narrowed on entry, and `&x' is a float *.  Covered:
 * float arguments past `...' read back with va_arg(ap, double); a call
 * through an old-style declaration to a later old-style definition; a call
 * to an earlier one, with a float and with an int argument; an old-style
 * float parameter between an int and a long; a call through a function
 * pointer.  A failing check returns its number; all passing returns 42. */
#include <stdarg.h>

static double
vsum(int n, ...)
{
    va_list ap;
    double s;

    s = 0;
    va_start(ap, n);
    while (n-- > 0)
        s = s + va_arg(ap, double);
    va_end(ap);
    return s;
}

static float
twice(x)
    float x;
{
    float *p = &x;

    return *p * 2;
}

static long
mix(a, x, b)
    int a;
    float x;
    long b;
{
    return a + (long)(x * 4) + b;
}

double half();

int
main()
{
    float f1 = 1.5f, f2 = 2.25f, f3 = -0.75f, r;
    float (*fp)() = twice;

    if (vsum(3, f1, f2, f3) != 3.0) return 1;
    r = half(f1 + f1 + f1 + f1 + 2);
    if (r != 4.0f) return 2;
    if (twice(1.25f) != 2.5f) return 3;
    if (twice(3) != 6.0f) return 4;
    if (mix(1, 0.5f, 100000L) != 100003L) return 5;
    if (fp(2.0f) != 4.0f) return 6;
    return 42;
}

double
half(x)
    float x;
{
    return x / 2;
}
