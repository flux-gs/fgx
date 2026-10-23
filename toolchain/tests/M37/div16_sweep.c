/* div16_sweep.c -- the 16-bit division helpers against a reference.
 *
 * _fcc_divu16, _fcc_modu16, _fcc_divs16 and _fcc_mods16 share one core,
 * _fcc_udiv16, which runs eight steps instead of sixteen for a dividend
 * under 256 and must carry a remainder past 16 bits when the divisor is
 * $8000 or more.  Divisors are VARIABLES so every operation reaches a
 * helper.  The reference is repeated subtraction, which shares no code
 * with the helpers.  K&R 2nd ed A.7.6: "(a/b)*b + a%b is equal to a", the
 * remainder taking the dividend's sign since `/' truncates.  Exit 42. */

unsigned uq, ur;

/* unsigned reference: q, r by subtracting d until r < d */
refu(n, d)
unsigned n, d;
{
    uq = 0;
    ur = n;
    while (ur >= d) {
        ur -= d;
        uq++;
    }
}

unsigned dv[] = { 1, 2, 3, 7, 10, 100, 255, 256, 257, 400, 1000,
                  32767, 32768, 32769, 65534, 65535 };
unsigned nv[] = { 0, 1, 9, 100, 254, 255, 256, 257, 1969, 2026, 4095,
                  32767, 32768, 40000, 65534, 65535 };
int      sd[] = { 1, -1, 3, -3, 10, -10, 400, -400, 32767, -32767 };
int      sn[] = { 0, 1, -1, 7, -7, 255, -255, 256, -256, 2026, -2026,
                  32767, -32767, -32768 };

int main()
{
    int i, j, bad, q, r, n, d;
    unsigned un, ud;

    bad = 0;
    for (i = 0; i < 16; i++)
        for (j = 0; j < 16; j++) {
            un = nv[i];
            ud = dv[j];
            if (ud > 1000 && un / 2 > ud)
                continue;               /* keep the reference loop short */
            refu(un, ud);
            if (un / ud != uq) bad++;
            if (un % ud != ur) bad++;
        }
    for (i = 0; i < 14; i++)
        for (j = 0; j < 10; j++) {
            n = sn[i];
            d = sd[j];
            if (n == -32768 && d == -1)
                continue;               /* the one overflowing quotient */
            q = n / d;
            r = n % d;
            if (q * d + r != n) bad++;
            if (r != 0 && (r < 0) != (n < 0)) bad++;
            if ((r < 0 ? -r : r) >= (d < 0 ? -d : d)) bad++;
        }
    return bad == 0 ? 42 : bad;
}
