/* ldiv_sweep.c -- the 32-bit division helpers on every path _fcc_long_udiv
 * takes: a divisor that fits a word (two word passes, the first skipped for
 * a zero high word, eight steps for a dividend under 256) and a wider one
 * (the 32-step loop).  Divisors are VARIABLES so every operation reaches a
 * helper.  Checked against K&R 2nd ed A.7.6, "(a/b)*b + a%b is equal to a",
 * with the remainder bounded by the divisor and signed like the dividend,
 * and against known quotients.  Exit 42. */

unsigned long un[] = { 0L, 1L, 9L, 255L, 256L, 65535L, 65536L, 65537L,
                       86399L, 86400L, 1729000000L, 2147483647L,
                       2147483648L, 4294967295L };
unsigned long ud[] = { 1L, 2L, 7L, 10L, 60L, 255L, 256L, 512L, 3600L,
                       65535L, 65536L, 86400L, 1000000L, 4294967295L };
long sn[] = { 0L, 1L, -1L, 59L, -59L, 86400L, -86400L, 1729000000L,
              -1729000000L, 2147483647L, -2147483647L };
long sd[] = { 1L, -1L, 7L, -7L, 60L, -60L, 86400L, -86400L, 100000L };

int main()
{
    int i, j, bad;
    unsigned long n, d, q, r;
    long a, b, sq, sr;

    bad = 0;
    for (i = 0; i < 14; i++)
        for (j = 0; j < 14; j++) {
            n = un[i];
            d = ud[j];
            q = n / d;
            r = n % d;
            if (q * d + r != n) bad++;
            if (r >= d) bad++;
        }
    for (i = 0; i < 11; i++)
        for (j = 0; j < 9; j++) {
            a = sn[i];
            b = sd[j];
            sq = a / b;
            sr = a % b;
            if (sq * b + sr != a) bad++;
            if (sr != 0 && (sr < 0) != (a < 0)) bad++;
            if ((sr < 0 ? -sr : sr) >= (b < 0 ? -b : b)) bad++;
        }
    d = 10L;
    if (4294967295L / d != 429496729L) bad++;
    if (4294967295L % d != 5L) bad++;
    d = 86400L;
    if (1729000000L / d != 20011L) bad++;
    if (1729000000L % d != 49600L) bad++;
    b = 60L;
    if (-86399L / b != -1439L) bad++;
    if (-86399L % b != -59L) bad++;
    return bad == 0 ? 42 : bad;
}
