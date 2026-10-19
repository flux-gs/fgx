/* apple/fgx#453: _fcc_mul16 and _fcc_long_mul scan the SMALLER operand and
 * stop when its bits run out.  Every product here has two run-time operands,
 * and each asymmetric pair is asked in both orders so both sides of the
 * operand swap are taken; zero, one, sign bits and wraparound are the edges.
 * Expected values are computed on the host with 16- and 32-bit wraparound.
 * Exit 42, or the number of the first check that failed. */
static int iv(int x) { return x; }
static unsigned uv(unsigned x) { return x; }
static long lv(long x) { return x; }

int main(void)
{
    if (iv(0) * iv(1234) != 0) return 1;
    if (iv(1234) * iv(0) != 0) return 2;
    if (iv(1) * iv(-7) != -7) return 3;
    if (iv(-7) * iv(1) != -7) return 4;
    if (iv(300) * iv(300) != 24464) return 5;
    if (iv(-1) * iv(-1) != 1) return 6;
    if (iv(-3) * iv(7) != -21) return 7;
    if (iv(7) * iv(-3) != -21) return 8;
    if (uv(0xFFFF) * uv(0xFFFF) != 1) return 9;
    if (uv(12345) * uv(54321) != 28393u) return 10;
    if (uv(54321) * uv(12345) != 28393u) return 11;
    if (uv(0x8000) * uv(2) != 0) return 12;
    if (uv(2) * uv(0x8000) != 0) return 13;
    if (uv(255) * uv(255) != 65025u) return 14;
    if (iv(181) * iv(181) != 32761) return 15;
    if (iv(0x7FFF) * iv(3) != 32765) return 16;
    if (uv(40000) * uv(40000) != 4096) return 17;

    if (lv(0L) * lv(123456L) != 0L) return 18;
    if (lv(123456L) * lv(0L) != 0L) return 19;
    if (lv(-1L) * lv(-1L) != 1L) return 20;
    if (lv(100000L) * lv(100000L) != 1410065408L) return 21;
    if (lv(-70000L) * lv(3L) != -210000L) return 22;
    if (lv(3L) * lv(-70000L) != -210000L) return 23;
    if (lv(0x12345678L) * lv(0x1234567L) != -1195040184L) return 24;
    if (lv(0x1234567L) * lv(0x12345678L) != -1195040184L) return 25;
    if (lv(65536L) * lv(65536L) != 0L) return 26;
    if (lv(1L) * lv(2147483647L) != 2147483647L) return 27;
    if (lv(-46341L) * lv(46341L) != 2147479015L) return 28;
    /* the scanned operand's LOW word is zero and its high word is not: a
     * loop that stopped on the low word alone would answer 0 */
    if (lv(65536L) * lv(100000L) != -2036334592L) return 29;
    return 42;
}
