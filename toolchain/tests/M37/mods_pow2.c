/* mods_pow2.c -- SIGNED remainder by a power-of-two constant, inlined.
 *
 * fcc used to inline %2^k only for an UNSIGNED dividend; a signed one fell to
 * _fcc_mods16, a sixteen-step division loop.  libc's isleap, `y % 4' on a
 * signed year inside timesub's year walk, made it 10.9% of `ls -l /bin'.
 *
 * K&R 2nd ed A.7.6 (p.166): "it is always true that (a/b)*b + a%b is equal
 * to a".  `/' truncates toward zero, so the remainder takes the dividend's
 * sign, and the inline sequence must agree with _fcc_mods16 for every
 * dividend.  The sweep below makes that comparison directly: `x % 4' and
 * `x % 512' are inlined, `x % m4' and `x % m512' divide by a VARIABLE and so
 * call the helper.  Fixed cases pin the extremes.  Exit 42. */

int a, m4, m512, m1;

int main()
{
    int n, x, bad;

    n = 0;
    m4 = 4; m512 = 512; m1 = 1;

    /* every dividend from -1100 to 1100: inline against the helper */
    bad = 0;
    for (x = -1100; x <= 1100; x++) {
        if (x % 4 != x % m4)
            bad++;
        if (x % 512 != x % m512)
            bad++;
        if ((x / 4) * 4 + x % 4 != x)
            bad++;
    }
    if (bad == 0) n += 1;

    /* negative dividends take the dividend's sign */
    a = -1;     if (a % 4 == -1)        n += 2;
    a = -4;     if (a % 4 == 0)         n += 4;
    a = -7;     if (a % 4 == -3)        n += 8;
    a = 7;      if (a % 4 == 3)         n += 16;

    /* the extremes of the 16-bit range */
    a = -32768; if (a % 2 == 0)         n += 32;
    a = -32768; if (a % 16384 == 0)     n += 64;
    a = -32767; if (a % 16384 == -16383) n += 128;
    a = 32767;  if (a % 16384 == 16383) n += 256;

    /* k = 1 is 0 for every dividend */
    a = -5;     if (a % 1 == 0 && a % m1 == 0) n += 512;

    /* isleap's shape, signed */
    a = 2024;   if (a % 4 == 0 && a % 100 != 0) n += 1024;
    a = 1900;   if (!(a % 4 == 0 && a % 100 != 0 || a % 400 == 0)) n += 2048;

    return n == 4095 ? 42 : n;
}
