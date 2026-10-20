/* T5-C C5: right-to-left (variadic) calls now WALK their args in reverse
 * source order (the record-and-reverse machinery + its u0 compensation are
 * retired), so every n,S offset bakes at its true stack depth.  Pins the
 * shapes the old guard die()'d on ("raw n,S ... not yet supported"): a
 * variadic arg reading a long PARAM, a long LOCAL, a struct-value-PARAM
 * field, a struct-LOCAL field, and a pointer-param deref.  The live find
 * was abiprobe's printf("... %d", sb.st_mode).  Host clang cross-checks:
 * 12+7+11+4+5 = 39, +3 = 42. */
#include <stdarg.h>

struct box { int lo; int hi; };

int vsum2(int n, ...)
{
    va_list ap;
    int s = 0;

    va_start(ap, n);
    while (n-- > 0)
        s += va_arg(ap, int);
    va_end(ap);
    return s;
}

int probe(long lp, struct box bx, int *ip)
{
    long ll = 7;
    struct box lb;

    lb.lo = 0;
    lb.hi = 4;
    return vsum2(5, (int)lp, (int)ll, bx.lo, lb.hi, ip[0]);
}

int main(void)
{
    struct box b;
    int x = 5;

    b.lo = 11;
    b.hi = 0;
    return probe(12L, b, &x) + 3;                /* 39 + 3 = 42 */
}
