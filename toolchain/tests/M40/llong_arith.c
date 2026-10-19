/* long long arithmetic, bitwise, shifts and comparisons -- sub-increment 1b
 * of the C99 extension (docs/history/plans/2026-09-23-fcc-long-long-plan.md);
 * not K&R, so nothing here cites K&R for the type.  Every expected value was
 * computed on the host with 64-bit two's-complement arithmetic.  The operand
 * pairs carry and borrow across all four words, the shift counts sit on and
 * around every word boundary, and the compares include the ones decided only
 * by a low word and the ones where signed and unsigned disagree.  A failing
 * check returns its own index (skipping 42); main's own checks return 200 up;
 * all of them passing returns 42. */
long long a, b, r;
unsigned long long ua, ub, u;
int i, n;

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

static int
run()
{
    put(&a, 0x00000000L, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a + b; if (!is(r, 0x00000001L, 0x00000000L)) return 1;
    put(&a, 0x00000000L, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a - b; if (!is(r, 0x00000000L, 0xFFFFFFFEL)) return 2;
    put(&a, 0x00000000L, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a & b; if (!is(r, 0x00000000L, 0x00000001L)) return 3;
    put(&a, 0x00000000L, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a | b; if (!is(r, 0x00000000L, 0xFFFFFFFFL)) return 4;
    put(&a, 0x00000000L, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a ^ b; if (!is(r, 0x00000000L, 0xFFFFFFFEL)) return 5;
    put(&a, 0x00000000L, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = ~a; if (!is(r, 0xFFFFFFFFL, 0x00000000L)) return 6;
    put(&a, 0x00000000L, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = -a; if (!is(r, 0xFFFFFFFFL, 0x00000001L)) return 7;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a + b; if (!is(r, 0x80000000L, 0x00000000L)) return 8;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a - b; if (!is(r, 0x7FFFFFFFL, 0xFFFFFFFEL)) return 9;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a & b; if (!is(r, 0x00000000L, 0x00000001L)) return 10;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a | b; if (!is(r, 0x7FFFFFFFL, 0xFFFFFFFFL)) return 11;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = a ^ b; if (!is(r, 0x7FFFFFFFL, 0xFFFFFFFEL)) return 12;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = ~a; if (!is(r, 0x80000000L, 0x00000000L)) return 13;
    put(&a, 0x7FFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); r = -a; if (!is(r, 0x80000000L, 0x00000001L)) return 14;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFEDCBA98L, 0x76543210L); r = a + b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFFL)) return 15;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFEDCBA98L, 0x76543210L); r = a - b; if (!is(r, 0x02468ACFL, 0x13579BDFL)) return 16;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFEDCBA98L, 0x76543210L); r = a & b; if (!is(r, 0x00000000L, 0x00000000L)) return 17;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFEDCBA98L, 0x76543210L); r = a | b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFFL)) return 18;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFEDCBA98L, 0x76543210L); r = a ^ b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFFL)) return 19;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFEDCBA98L, 0x76543210L); r = ~a; if (!is(r, 0xFEDCBA98L, 0x76543210L)) return 20;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0xFEDCBA98L, 0x76543210L); r = -a; if (!is(r, 0xFEDCBA98L, 0x76543211L)) return 21;
    put(&a, 0xFFFFFFFFL, 0x00000001L); put(&b, 0x00000000L, 0xFFFFFFFFL); r = a + b; if (!is(r, 0x00000000L, 0x00000000L)) return 22;
    put(&a, 0xFFFFFFFFL, 0x00000001L); put(&b, 0x00000000L, 0xFFFFFFFFL); r = a - b; if (!is(r, 0xFFFFFFFEL, 0x00000002L)) return 23;
    put(&a, 0xFFFFFFFFL, 0x00000001L); put(&b, 0x00000000L, 0xFFFFFFFFL); r = a & b; if (!is(r, 0x00000000L, 0x00000001L)) return 24;
    put(&a, 0xFFFFFFFFL, 0x00000001L); put(&b, 0x00000000L, 0xFFFFFFFFL); r = a | b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFFL)) return 25;
    put(&a, 0xFFFFFFFFL, 0x00000001L); put(&b, 0x00000000L, 0xFFFFFFFFL); r = a ^ b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFEL)) return 26;
    put(&a, 0xFFFFFFFFL, 0x00000001L); put(&b, 0x00000000L, 0xFFFFFFFFL); r = ~a; if (!is(r, 0x00000000L, 0xFFFFFFFEL)) return 27;
    put(&a, 0xFFFFFFFFL, 0x00000001L); put(&b, 0x00000000L, 0xFFFFFFFFL); r = -a; if (!is(r, 0x00000000L, 0xFFFFFFFFL)) return 28;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000001L); r = a + b; if (!is(r, 0x80000000L, 0x00000001L)) return 29;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000001L); r = a - b; if (!is(r, 0x7FFFFFFFL, 0xFFFFFFFFL)) return 30;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000001L); r = a & b; if (!is(r, 0x00000000L, 0x00000000L)) return 31;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000001L); r = a | b; if (!is(r, 0x80000000L, 0x00000001L)) return 32;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000001L); r = a ^ b; if (!is(r, 0x80000000L, 0x00000001L)) return 33;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000001L); r = ~a; if (!is(r, 0x7FFFFFFFL, 0xFFFFFFFFL)) return 34;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x00000000L, 0x00000001L); r = -a; if (!is(r, 0x80000000L, 0x00000000L)) return 35;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000002L); r = a + b; if (!is(r, 0x00000000L, 0x00000001L)) return 36;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000002L); r = a - b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFDL)) return 37;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000002L); r = a & b; if (!is(r, 0x00000000L, 0x00000002L)) return 38;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000002L); r = a | b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFFL)) return 39;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000002L); r = a ^ b; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFDL)) return 40;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000002L); r = ~a; if (!is(r, 0x00000000L, 0x00000000L)) return 41;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000002L); r = -a; if (!is(r, 0x00000000L, 0x00000001L)) return 43;
    put(&a, 0x00010000L, 0xFFFF0000L); put(&b, 0x0000FFFFL, 0x00010000L); r = a + b; if (!is(r, 0x00020000L, 0x00000000L)) return 44;
    put(&a, 0x00010000L, 0xFFFF0000L); put(&b, 0x0000FFFFL, 0x00010000L); r = a - b; if (!is(r, 0x00000001L, 0xFFFE0000L)) return 45;
    put(&a, 0x00010000L, 0xFFFF0000L); put(&b, 0x0000FFFFL, 0x00010000L); r = a & b; if (!is(r, 0x00000000L, 0x00010000L)) return 46;
    put(&a, 0x00010000L, 0xFFFF0000L); put(&b, 0x0000FFFFL, 0x00010000L); r = a | b; if (!is(r, 0x0001FFFFL, 0xFFFF0000L)) return 47;
    put(&a, 0x00010000L, 0xFFFF0000L); put(&b, 0x0000FFFFL, 0x00010000L); r = a ^ b; if (!is(r, 0x0001FFFFL, 0xFFFE0000L)) return 48;
    put(&a, 0x00010000L, 0xFFFF0000L); put(&b, 0x0000FFFFL, 0x00010000L); r = ~a; if (!is(r, 0xFFFEFFFFL, 0x0000FFFFL)) return 49;
    put(&a, 0x00010000L, 0xFFFF0000L); put(&b, 0x0000FFFFL, 0x00010000L); r = -a; if (!is(r, 0xFFFEFFFFL, 0x00010000L)) return 50;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 1; r = a << n; if (!is(r, 0x02468ACFL, 0x13579BDEL)) return 51;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 1; r = a >> n; if (!is(r, 0x0091A2B3L, 0xC4D5E6F7L)) return 52;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 1; u = ua >> n; if (!uis(u, 0x0091A2B3L, 0xC4D5E6F7L)) return 53;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 15; r = a << n; if (!is(r, 0xA2B3C4D5L, 0xE6F78000L)) return 54;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 15; r = a >> n; if (!is(r, 0x00000246L, 0x8ACF1357L)) return 55;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 15; u = ua >> n; if (!uis(u, 0x00000246L, 0x8ACF1357L)) return 56;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 16; r = a << n; if (!is(r, 0x456789ABL, 0xCDEF0000L)) return 57;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 16; r = a >> n; if (!is(r, 0x00000123L, 0x456789ABL)) return 58;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 16; u = ua >> n; if (!uis(u, 0x00000123L, 0x456789ABL)) return 59;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 17; r = a << n; if (!is(r, 0x8ACF1357L, 0x9BDE0000L)) return 60;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 17; r = a >> n; if (!is(r, 0x00000091L, 0xA2B3C4D5L)) return 61;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 17; u = ua >> n; if (!uis(u, 0x00000091L, 0xA2B3C4D5L)) return 62;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 31; r = a << n; if (!is(r, 0xC4D5E6F7L, 0x80000000L)) return 63;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 31; r = a >> n; if (!is(r, 0x00000000L, 0x02468ACFL)) return 64;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 31; u = ua >> n; if (!uis(u, 0x00000000L, 0x02468ACFL)) return 65;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 32; r = a << n; if (!is(r, 0x89ABCDEFL, 0x00000000L)) return 66;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 32; r = a >> n; if (!is(r, 0x00000000L, 0x01234567L)) return 67;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 32; u = ua >> n; if (!uis(u, 0x00000000L, 0x01234567L)) return 68;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 33; r = a << n; if (!is(r, 0x13579BDEL, 0x00000000L)) return 69;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 33; r = a >> n; if (!is(r, 0x00000000L, 0x0091A2B3L)) return 70;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 33; u = ua >> n; if (!uis(u, 0x00000000L, 0x0091A2B3L)) return 71;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 47; r = a << n; if (!is(r, 0xE6F78000L, 0x00000000L)) return 72;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 47; r = a >> n; if (!is(r, 0x00000000L, 0x00000246L)) return 73;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 47; u = ua >> n; if (!uis(u, 0x00000000L, 0x00000246L)) return 74;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 48; r = a << n; if (!is(r, 0xCDEF0000L, 0x00000000L)) return 75;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 48; r = a >> n; if (!is(r, 0x00000000L, 0x00000123L)) return 76;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 48; u = ua >> n; if (!uis(u, 0x00000000L, 0x00000123L)) return 77;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 63; r = a << n; if (!is(r, 0x80000000L, 0x00000000L)) return 78;
    put(&a, 0x01234567L, 0x89ABCDEFL); n = 63; r = a >> n; if (!is(r, 0x00000000L, 0x00000000L)) return 79;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); n = 63; u = ua >> n; if (!uis(u, 0x00000000L, 0x00000000L)) return 80;
    put(&a, 0x80000000L, 0x00000001L); n = 1; r = a << n; if (!is(r, 0x00000000L, 0x00000002L)) return 81;
    put(&a, 0x80000000L, 0x00000001L); n = 1; r = a >> n; if (!is(r, 0xC0000000L, 0x00000000L)) return 82;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 1; u = ua >> n; if (!uis(u, 0x40000000L, 0x00000000L)) return 83;
    put(&a, 0x80000000L, 0x00000001L); n = 15; r = a << n; if (!is(r, 0x00000000L, 0x00008000L)) return 84;
    put(&a, 0x80000000L, 0x00000001L); n = 15; r = a >> n; if (!is(r, 0xFFFF0000L, 0x00000000L)) return 85;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 15; u = ua >> n; if (!uis(u, 0x00010000L, 0x00000000L)) return 86;
    put(&a, 0x80000000L, 0x00000001L); n = 16; r = a << n; if (!is(r, 0x00000000L, 0x00010000L)) return 87;
    put(&a, 0x80000000L, 0x00000001L); n = 16; r = a >> n; if (!is(r, 0xFFFF8000L, 0x00000000L)) return 88;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 16; u = ua >> n; if (!uis(u, 0x00008000L, 0x00000000L)) return 89;
    put(&a, 0x80000000L, 0x00000001L); n = 17; r = a << n; if (!is(r, 0x00000000L, 0x00020000L)) return 90;
    put(&a, 0x80000000L, 0x00000001L); n = 17; r = a >> n; if (!is(r, 0xFFFFC000L, 0x00000000L)) return 91;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 17; u = ua >> n; if (!uis(u, 0x00004000L, 0x00000000L)) return 92;
    put(&a, 0x80000000L, 0x00000001L); n = 31; r = a << n; if (!is(r, 0x00000000L, 0x80000000L)) return 93;
    put(&a, 0x80000000L, 0x00000001L); n = 31; r = a >> n; if (!is(r, 0xFFFFFFFFL, 0x00000000L)) return 94;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 31; u = ua >> n; if (!uis(u, 0x00000001L, 0x00000000L)) return 95;
    put(&a, 0x80000000L, 0x00000001L); n = 32; r = a << n; if (!is(r, 0x00000001L, 0x00000000L)) return 96;
    put(&a, 0x80000000L, 0x00000001L); n = 32; r = a >> n; if (!is(r, 0xFFFFFFFFL, 0x80000000L)) return 97;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 32; u = ua >> n; if (!uis(u, 0x00000000L, 0x80000000L)) return 98;
    put(&a, 0x80000000L, 0x00000001L); n = 33; r = a << n; if (!is(r, 0x00000002L, 0x00000000L)) return 99;
    put(&a, 0x80000000L, 0x00000001L); n = 33; r = a >> n; if (!is(r, 0xFFFFFFFFL, 0xC0000000L)) return 100;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 33; u = ua >> n; if (!uis(u, 0x00000000L, 0x40000000L)) return 101;
    put(&a, 0x80000000L, 0x00000001L); n = 47; r = a << n; if (!is(r, 0x00008000L, 0x00000000L)) return 102;
    put(&a, 0x80000000L, 0x00000001L); n = 47; r = a >> n; if (!is(r, 0xFFFFFFFFL, 0xFFFF0000L)) return 103;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 47; u = ua >> n; if (!uis(u, 0x00000000L, 0x00010000L)) return 104;
    put(&a, 0x80000000L, 0x00000001L); n = 48; r = a << n; if (!is(r, 0x00010000L, 0x00000000L)) return 105;
    put(&a, 0x80000000L, 0x00000001L); n = 48; r = a >> n; if (!is(r, 0xFFFFFFFFL, 0xFFFF8000L)) return 106;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 48; u = ua >> n; if (!uis(u, 0x00000000L, 0x00008000L)) return 107;
    put(&a, 0x80000000L, 0x00000001L); n = 63; r = a << n; if (!is(r, 0x80000000L, 0x00000000L)) return 108;
    put(&a, 0x80000000L, 0x00000001L); n = 63; r = a >> n; if (!is(r, 0xFFFFFFFFL, 0xFFFFFFFFL)) return 109;
    put((long long *)&ua, 0x80000000L, 0x00000001L); n = 63; u = ua >> n; if (!uis(u, 0x00000000L, 0x00000001L)) return 110;
    put(&a, 0x00000001L, 0x00000000L); put(&b, 0x00000000L, 0xFFFFFFFFL); i = (a < b); if (i != 0) return 111;
    put((long long *)&ua, 0x00000001L, 0x00000000L); put((long long *)&ub, 0x00000000L, 0xFFFFFFFFL); i = (ua < ub); if (i != 0) return 112;
    put(&a, 0x00000001L, 0x00000000L); put(&b, 0x00000000L, 0xFFFFFFFFL); i = (a > b); if (i != 1) return 113;
    put((long long *)&ua, 0x00000001L, 0x00000000L); put((long long *)&ub, 0x00000000L, 0xFFFFFFFFL); i = (ua > ub); if (i != 1) return 114;
    put(&a, 0x00000001L, 0x00000000L); put(&b, 0x00000000L, 0xFFFFFFFFL); i = (a <= b); if (i != 0) return 115;
    put((long long *)&ua, 0x00000001L, 0x00000000L); put((long long *)&ub, 0x00000000L, 0xFFFFFFFFL); i = (ua <= ub); if (i != 0) return 116;
    put(&a, 0x00000001L, 0x00000000L); put(&b, 0x00000000L, 0xFFFFFFFFL); i = (a >= b); if (i != 1) return 117;
    put((long long *)&ua, 0x00000001L, 0x00000000L); put((long long *)&ub, 0x00000000L, 0xFFFFFFFFL); i = (ua >= ub); if (i != 1) return 118;
    put(&a, 0x00000001L, 0x00000000L); put(&b, 0x00000000L, 0xFFFFFFFFL); i = (a == b); if (i != 0) return 119;
    put((long long *)&ua, 0x00000001L, 0x00000000L); put((long long *)&ub, 0x00000000L, 0xFFFFFFFFL); i = (ua == ub); if (i != 0) return 120;
    put(&a, 0x00000001L, 0x00000000L); put(&b, 0x00000000L, 0xFFFFFFFFL); i = (a != b); if (i != 1) return 121;
    put((long long *)&ua, 0x00000001L, 0x00000000L); put((long long *)&ub, 0x00000000L, 0xFFFFFFFFL); i = (ua != ub); if (i != 1) return 122;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); i = (a < b); if (i != 1) return 123;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x00000000L, 0x00000001L); i = (ua < ub); if (i != 0) return 124;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); i = (a > b); if (i != 0) return 125;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x00000000L, 0x00000001L); i = (ua > ub); if (i != 1) return 126;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); i = (a <= b); if (i != 1) return 127;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x00000000L, 0x00000001L); i = (ua <= ub); if (i != 0) return 128;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); i = (a >= b); if (i != 0) return 129;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x00000000L, 0x00000001L); i = (ua >= ub); if (i != 1) return 130;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); i = (a == b); if (i != 0) return 131;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x00000000L, 0x00000001L); i = (ua == ub); if (i != 0) return 132;
    put(&a, 0xFFFFFFFFL, 0xFFFFFFFFL); put(&b, 0x00000000L, 0x00000001L); i = (a != b); if (i != 1) return 133;
    put((long long *)&ua, 0xFFFFFFFFL, 0xFFFFFFFFL); put((long long *)&ub, 0x00000000L, 0x00000001L); i = (ua != ub); if (i != 1) return 134;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0x01234567L, 0x89ABCDEFL); i = (a < b); if (i != 0) return 135;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); put((long long *)&ub, 0x01234567L, 0x89ABCDEFL); i = (ua < ub); if (i != 0) return 136;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0x01234567L, 0x89ABCDEFL); i = (a > b); if (i != 0) return 137;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); put((long long *)&ub, 0x01234567L, 0x89ABCDEFL); i = (ua > ub); if (i != 0) return 138;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0x01234567L, 0x89ABCDEFL); i = (a <= b); if (i != 1) return 139;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); put((long long *)&ub, 0x01234567L, 0x89ABCDEFL); i = (ua <= ub); if (i != 1) return 140;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0x01234567L, 0x89ABCDEFL); i = (a >= b); if (i != 1) return 141;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); put((long long *)&ub, 0x01234567L, 0x89ABCDEFL); i = (ua >= ub); if (i != 1) return 142;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0x01234567L, 0x89ABCDEFL); i = (a == b); if (i != 1) return 143;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); put((long long *)&ub, 0x01234567L, 0x89ABCDEFL); i = (ua == ub); if (i != 1) return 144;
    put(&a, 0x01234567L, 0x89ABCDEFL); put(&b, 0x01234567L, 0x89ABCDEFL); i = (a != b); if (i != 0) return 145;
    put((long long *)&ua, 0x01234567L, 0x89ABCDEFL); put((long long *)&ub, 0x01234567L, 0x89ABCDEFL); i = (ua != ub); if (i != 0) return 146;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (a < b); if (i != 1) return 147;
    put((long long *)&ua, 0x80000000L, 0x00000000L); put((long long *)&ub, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (ua < ub); if (i != 0) return 148;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (a > b); if (i != 0) return 149;
    put((long long *)&ua, 0x80000000L, 0x00000000L); put((long long *)&ub, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (ua > ub); if (i != 1) return 150;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (a <= b); if (i != 1) return 151;
    put((long long *)&ua, 0x80000000L, 0x00000000L); put((long long *)&ub, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (ua <= ub); if (i != 0) return 152;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (a >= b); if (i != 0) return 153;
    put((long long *)&ua, 0x80000000L, 0x00000000L); put((long long *)&ub, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (ua >= ub); if (i != 1) return 154;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (a == b); if (i != 0) return 155;
    put((long long *)&ua, 0x80000000L, 0x00000000L); put((long long *)&ub, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (ua == ub); if (i != 0) return 156;
    put(&a, 0x80000000L, 0x00000000L); put(&b, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (a != b); if (i != 1) return 157;
    put((long long *)&ua, 0x80000000L, 0x00000000L); put((long long *)&ub, 0x7FFFFFFFL, 0xFFFFFFFFL); i = (ua != ub); if (i != 1) return 158;
    put(&a, 0x00000000L, 0x00000005L); put(&b, 0x00000000L, 0x00000006L); i = (a < b); if (i != 1) return 159;
    put((long long *)&ua, 0x00000000L, 0x00000005L); put((long long *)&ub, 0x00000000L, 0x00000006L); i = (ua < ub); if (i != 1) return 160;
    put(&a, 0x00000000L, 0x00000005L); put(&b, 0x00000000L, 0x00000006L); i = (a > b); if (i != 0) return 161;
    put((long long *)&ua, 0x00000000L, 0x00000005L); put((long long *)&ub, 0x00000000L, 0x00000006L); i = (ua > ub); if (i != 0) return 162;
    put(&a, 0x00000000L, 0x00000005L); put(&b, 0x00000000L, 0x00000006L); i = (a <= b); if (i != 1) return 163;
    put((long long *)&ua, 0x00000000L, 0x00000005L); put((long long *)&ub, 0x00000000L, 0x00000006L); i = (ua <= ub); if (i != 1) return 164;
    put(&a, 0x00000000L, 0x00000005L); put(&b, 0x00000000L, 0x00000006L); i = (a >= b); if (i != 0) return 165;
    put((long long *)&ua, 0x00000000L, 0x00000005L); put((long long *)&ub, 0x00000000L, 0x00000006L); i = (ua >= ub); if (i != 0) return 166;
    put(&a, 0x00000000L, 0x00000005L); put(&b, 0x00000000L, 0x00000006L); i = (a == b); if (i != 0) return 167;
    put((long long *)&ua, 0x00000000L, 0x00000005L); put((long long *)&ub, 0x00000000L, 0x00000006L); i = (ua == ub); if (i != 0) return 168;
    put(&a, 0x00000000L, 0x00000005L); put(&b, 0x00000000L, 0x00000006L); i = (a != b); if (i != 1) return 169;
    put((long long *)&ua, 0x00000000L, 0x00000005L); put((long long *)&ub, 0x00000000L, 0x00000006L); i = (ua != ub); if (i != 1) return 170;
    return 0;
}

int
main()
{
    int f;
    long long z;

    f = run();
    if (f)
        return f;
    /* conditions, !, a mixed int operand in both orders, narrowing casts */
    put(&z, 0L, 0L);
    if (z || !(!z))
        return 200;
    put(&z, 0x00010000L, 0L);         /* nonzero only in w2 */
    if (!z)
        return 201;
    put(&a, 0L, 0xFFFFFFFFL);
    i = 1;
    r = a + i;                        /* int on the right widens */
    if (!is(r, 1L, 0L))
        return 202;
    r = i - a;                        /* int on the left widens */
    if (!is(r, -1L, 2L))
        return 203;
    i = -1;
    r = a + i;                        /* a signed int sign-extends */
    if (!is(r, 0L, 0xFFFFFFFEL))
        return 204;
    put(&a, 0x01234567L, 0x89ABCDEFL);
    if ((long)a != 0x89ABCDEFL || (int)a != (int)0xCDEF)
        return 205;
    return 42;
}
