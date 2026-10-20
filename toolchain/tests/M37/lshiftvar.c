/* Variable-count 32-bit shifts — compress output()'s `code >>= 8-r_off`,
 * `code << r_off`, and `(1L<<n_bits)-1` growth path (Fable rank-2).  The
 * 28-byte input keeps n_bits=9 and r_off small; 616 bytes grows n_bits and
 * uses more r_off values.  Exit 42. */
typedef long code_int;
int main(void)
{
    code_int code;
    long m;
    int nb, roff;

    /* (1L << nb) - 1 for nb 9..12  — MAXCODE growth path */
    for (nb = 9; nb <= 12; nb++) {
        m = (1L << nb) - 1;
        if (nb == 9  && m != 511L)  return 1;
        if (nb == 10 && m != 1023L) return 2;
        if (nb == 11 && m != 2047L) return 3;
        if (nb == 12 && m != 4095L) return 4;
    }
    /* variable long right shift: code >>= (8 - roff) */
    code = 0x0006E065L;                 /* 450661, nonzero high word */
    for (roff = 0; roff <= 7; roff++) {
        long v = code >> (8 - roff);
        long expect = 450661L >> (8 - roff);   /* compile-time on host side is n/a; recompute */
        /* recompute expect via repeated halving to avoid trusting the same op */
        long e = 450661L; int s = 8 - roff;
        while (s-- > 0) e = e / 2;
        if (v != e) return 10 + roff;
    }
    /* variable long left shift: (code << roff) with a 12-bit code */
    code = 0xABCL;                       /* 2748 */
    for (roff = 0; roff <= 7; roff++) {
        long v = code << roff;
        long e = 2748L; int s = roff;
        while (s-- > 0) e = e * 2;
        if (v != e) return 20 + roff;
    }
    return 42;
}
