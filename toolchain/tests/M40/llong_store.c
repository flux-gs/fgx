/* `long long' -- the C99 type fcc adopts as an extension; it is not in K&R,
 * so nothing here cites K&R (docs/history/plans/2026-09-23-fcc-long-long-
 * plan.md, sub-increment 1a).  STORAGE ONLY: a value survives every copy --
 * local, global, parameter, return, a K&R call -- and widening from int and
 * from long sign-extends a signed value and zero-fills an unsigned one, the
 * rule K&R A.6.2 gives for the integral types it has.
 *
 * There is no long long comparison yet, so each value is built and read
 * through `long *' views of its two halves.  Every one of the four 16-bit
 * words differs, so a dropped, swapped or truncated word changes the answer.
 * Exits 42 iff all of it holds. */
long long ga, gb;
long lo_neg = -5L;
unsigned long lo_big = 0x89ABCDEFL;

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
is(v, hi, lo)
    long long v;
    long hi, lo;
{
    long *h = (long *)&v;
    return h[0] == lo && h[1] == hi;
}

static long long
pass(v)
    long long v;
{
    long long w;
    w = v;
    return w;
}

long long twice_arg(long long a, long long b) { return b; }

int
main()
{
    long long a, b;
    int i = -3;
    unsigned u = 0xFFFE;
    int ok = 0;

    put(&a, 0x01234567L, 0x89ABCDEFL);
    b = a;                          /* local to local */
    ga = b;                         /* local to global */
    gb = ga;                        /* global to global */
    if (is(gb, 0x01234567L, 0x89ABCDEFL))
        ok += 10;
    if (is(pass(gb), 0x01234567L, 0x89ABCDEFL) &&
        is(twice_arg(a, pass(b)), 0x01234567L, 0x89ABCDEFL))
        ok += 10;                   /* parameter, return, prototyped call */
    a = i;                          /* signed int sign-extends */
    b = u;                          /* unsigned int zero-fills */
    if (is(a, -1L, -3L) && is(b, 0L, 0xFFFEL))
        ok += 11;
    a = lo_neg;                     /* signed long sign-extends */
    b = lo_big;                     /* unsigned long zero-fills */
    if (is(a, -1L, -5L) && is(b, 0L, 0x89ABCDEFL))
        ok += 11;
    return ok;
}
