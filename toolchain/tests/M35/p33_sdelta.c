/* M35/P3-3: g_s_delta stress — a local read AFTER temporaries are pushed.
 *
 * After the flip, locals are n,S and their displacement tracks g_s_delta
 * (the compile-time count of mid-expression pushes).  A push-emit site that
 * forgets to bump g_s_delta reads a NEIGHBOURING slot — which often still
 * exits 0, so this is exit-code-fragile by design: keep the arithmetic
 * distinctive.  Nested call args interleave pushes with local reads.
 *
 * Portable C: clang returns 42. */
int
g(int x)
{
    return x + 1;
}

int
add3(int a, int b, int c)
{
    return a + b + c;
}

int
main(void)
{
    int loc = 10;
    int other = 3;
    int r;

    /* nested args: loc is read while g()'s call frame pushes are live */
    r = add3(g(loc), loc, g(g(loc)));      /* 11 + 10 + 12 = 33 */
    if (r != 33)   return 1;

    /* mixed pushes: two locals read across multiply/add temporaries */
    r = g(loc) + g(loc) * other;            /* 11 + 11*3 = 44 */
    if (r != 44)   return 2;

    /* local read after a deeper push chain */
    r = add3(add3(loc, other, g(loc)), loc, other);  /* (10+3+11)+10+3 = 37 */
    if (r != 37)   return 3;

    if (loc != 10 || other != 3) return 4;  /* locals unclobbered */
    return 42;
}
