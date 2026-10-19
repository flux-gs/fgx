/* long long * / and % -- sub-increment 1c of the C99 extension
 * (docs/history/plans/2026-09-23-fcc-long-long-plan.md); not K&R.  Every
 * expected value was computed on the host.  Products that wrap and ones with
 * negative factors; unsigned division including a divisor with its top bit
 * set (the remainder's 65th bit); signed division truncating toward zero in
 * all four sign combinations, with the remainder taking the dividend's sign
 * as K&R A.7.6's (a/b)*b + a%b == a requires.  A failing check returns its
 * index (skipping 42); all passing returns 42. */
long long a, b, r;
unsigned long long ua, ub, u;

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

static int
uis(v, hi, lo)
    unsigned long long v;
    long hi, lo;
{
    long *h = (long *)&v;
    return h[0] == lo && h[1] == hi;
}

int
main()
{
    put(&a, 0x00000000L, 0x00000003L); put(&b, 0x00000000L, 0x00000005L); r = a * b; if (!is(r, 0x00000000L, 0x0000000FL)) return 1;
    put(&a, 0x00000000L, 0xFFFFFFFFL); put(&b, 0x00000000L, 0xFFFFFFFFL); r = a * b; if (!is(r, 0xFFFFFFFEL, 0x00000001L)) return 2;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0x00000000L, 0x00000010L); r = a * b; if (!is(r, 0x12345678L, 0x9ABCDEF0L)) return 3;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFF9L); put(&b, 0x00000000L, 0x00000006L); r = a * b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFD6L)) return 4;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFF9L); put(&b, 0xFFFFFFFFL, 0xFFFFFFFAL); r = a * b; if (!is(r, 0x00000000L, 0x0000002AL)) return 5;
    put(&a, 0x00000001L, 0x00000000L); put(&b, 0x00000001L, 0x00000000L); r = a * b; if (!is(r, 0x00000000L, 0x00000000L)) return 6;
    put(&a, 0xDEADBEEFL, 0xCAFEBABEL); put(&b, 0x00000001L, 0x23456789L); r = a * b; if (!is(r, 0x1D2EEDEEL, 0x6EAA61AEL)) return 7;
    put(&a, 0x00000000L, 0x00000000L); put(&b, 0x7FFFFFFFL, 0xFFFFFFFFL); r = a * b; if (!is(r, 0x00000000L, 0x00000000L)) return 8;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000002L); r = a * b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFEL)) return 9;
    put((long long *)&ua, 0x00000000L, 0x00000064L); put((long long *)&ub, 0x00000000L, 0x00000007L); u = ua / ub; if (!uis(u, 0x00000000L, 0x0000000EL)) return 10;
    put((long long *)&ua, 0x00000000L, 0x00000064L); put((long long *)&ub, 0x00000000L, 0x00000007L); u = ua % ub; if (!uis(u, 0x00000000L, 0x00000002L)) return 11;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x00000000L, 0x00000003L); u = ua / ub; if (!uis(u, 0x55555555L, 0x55555555L)) return 12;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x00000000L, 0x00000003L); u = ua % ub; if (!uis(u, 0x00000000L, 0x00000000L)) return 13;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x80000000L, 0x00000001L); u = ua / ub; if (!uis(u, 0x00000000L, 0x00000001L)) return 14;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x80000000L, 0x00000001L); u = ua % ub; if (!uis(u, 0x7FFFFFFFL, 0xFFFFFFFEL)) return 15;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); put((long long *)&ub, 0x00000001L, 0x00000000L); u = ua / ub; if (!uis(u, 0x00000000L, 0x01234567L)) return 16;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); put((long long *)&ub, 0x00000001L, 0x00000000L); u = ua % ub; if (!uis(u, 0x00000000L, 0x89ABCDEFL)) return 17;
    put((long long *)&ua, 0x00000000L, 0x00000005L); put((long long *)&ub, 0x80000000L, 0x00000000L); u = ua / ub; if (!uis(u, 0x00000000L, 0x00000000L)) return 18;
    put((long long *)&ua, 0x00000000L, 0x00000005L); put((long long *)&ub, 0x80000000L, 0x00000000L); u = ua % ub; if (!uis(u, 0x00000000L, 0x00000005L)) return 19;
    put((long long *)&ua, 0xFEDCBA98L, 0x76543210L); put((long long *)&ub, 0x00000000L, 0xFEDCBA98L); u = ua / ub; if (!uis(u, 0x00000001L, 0x00000000L)) return 20;
    put((long long *)&ua, 0xFEDCBA98L, 0x76543210L); put((long long *)&ub, 0x00000000L, 0xFEDCBA98L); u = ua % ub; if (!uis(u, 0x00000000L, 0x76543210L)) return 21;
    put((long long *)&ua, 0x00000000L, 0x00003039L); put((long long *)&ub, 0x00000000L, 0x00003039L); u = ua / ub; if (!uis(u, 0x00000000L, 0x00000001L)) return 22;
    put((long long *)&ua, 0x00000000L, 0x00003039L); put((long long *)&ub, 0x00000000L, 0x00003039L); u = ua % ub; if (!uis(u, 0x00000000L, 0x00000000L)) return 23;
    put((long long *)&ua, 0x00000000L, 0x00000001L); put((long long *)&ub, 0x00000000L, 0x00000002L); u = ua / ub; if (!uis(u, 0x00000000L, 0x00000000L)) return 24;
    put((long long *)&ua, 0x00000000L, 0x00000001L); put((long long *)&ub, 0x00000000L, 0x00000002L); u = ua % ub; if (!uis(u, 0x00000000L, 0x00000001L)) return 25;
    put(&a, 0x00000000L, 0x00000064L); put(&b, 0x00000000L, 0x00000007L); r = a / b; if (!is(r, 0x00000000L, 0x0000000EL)) return 26;
    put(&a, 0x00000000L, 0x00000064L); put(&b, 0x00000000L, 0x00000007L); r = a % b; if (!is(r, 0x00000000L, 0x00000002L)) return 27;
    put(&a, 0xFFFFFFFFL, 0xFFFFFF9CL); put(&b, 0x00000000L, 0x00000007L); r = a / b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFF2L)) return 28;
    put(&a, 0xFFFFFFFFL, 0xFFFFFF9CL); put(&b, 0x00000000L, 0x00000007L); r = a % b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFEL)) return 29;
    put(&a, 0x00000000L, 0x00000064L); put(&b, 0xFFFFFFFFL, 0xFFFFFFF9L); r = a / b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFF2L)) return 30;
    put(&a, 0x00000000L, 0x00000064L); put(&b, 0xFFFFFFFFL, 0xFFFFFFF9L); r = a % b; if (!is(r, 0x00000000L, 0x00000002L)) return 31;
    put(&a, 0xFFFFFFFFL, 0xFFFFFF9CL); put(&b, 0xFFFFFFFFL, 0xFFFFFFF9L); r = a / b; if (!is(r, 0x00000000L, 0x0000000EL)) return 32;
    put(&a, 0xFFFFFFFFL, 0xFFFFFF9CL); put(&b, 0xFFFFFFFFL, 0xFFFFFFF9L); r = a % b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFEL)) return 33;
    put(&a, 0xC0000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000003L); r = a / b; if (!is(r, 0xEAAAAAAAL, 0xAAAAAAABL)) return 34;
    put(&a, 0xC0000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000003L); r = a % b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFFL)) return 35;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0xFFFFFFFFL, 0xFFFFFFFFL); r = a / b; if (!is(r, 0x80000000L, 0x00000001L)) return 36;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0xFFFFFFFFL, 0xFFFFFFFFL); r = a % b; if (!is(r, 0x00000000L, 0x00000000L)) return 37;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFBL); put(&b, 0x00000000L, 0x0000000AL); r = a / b; if (!is(r, 0x00000000L, 0x00000000L)) return 38;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFBL); put(&b, 0x00000000L, 0x0000000AL); r = a % b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFBL)) return 39;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFFFFFFFFL, 0xFFFF0000L); r = a / b; if (!is(r, 0xFFFFFEDCL, 0xBA987655L)) return 40;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFFFFFFFFL, 0xFFFF0000L); r = a % b; if (!is(r, 0x00000000L, 0x0000CDEFL)) return 41;

    /* The result used where it is made -- a comparison operand and an argument
     * -- rather than stored first, with a constant operand on either side. */
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0x00000000L, 0x00000003L);
    r = a * b;
    if (a * b != r || a * 3 != r || 3 * a != r) return 43;
    if (!is(a * b, 0x0369D036L, 0x9D0369CDL)) return 44;
    r = a / b;
    if (a / b != r || a / 3 != r || a % b != a - r * 3) return 45;
    return 42;
}
