/*
 * fltpr -- printf's %e, %f and %g, loaded only into a program that uses
 * floating point.
 *
 * 2.11BSD splits its printf the same way and for the same reason.
 * vendor/2.11BSD/usr/lib/libc/pdp/stdio/fltpr.s holds doprnt's floating
 * output, and says: "If the compiler notices any floating point type stuff
 * going on in a C object, it automatically outputs a reference to the symbol
 * "fltused" to force loading of this portion of the doprnt support.  If
 * fltused is not defined the references to pgen, pfloat and pscien in doprnt
 * will be satisfied by ffltpr.s (fake floating print)."
 *
 * Here fcc marks such a translation unit with `]__lc_fltused', and
 * FGX_AR_HAVE_fltpr tells printf.c to call __lc_pf_float.  Without it, printf
 * prints `?' for the conversion (__lc_pf_q), as ffltpr.s does.  libc's
 * library-mode compile always defines it: libc.so's one printf serves every
 * dynamic program, as in SunOS 4.1.3's shared libc, which has no fltused.  A
 * static link (fgx_static) takes this member only for a program that carries
 * the marker; any other gets toolchain/lib/ffltpr.c's __lc_pf_float, which
 * prints the `?'.
 *
 * THE DIGITS are ecvt(3) and fcvt(3)'s (ecvt.c), as fltpr.s's pfloat and
 * pscien call _fcvt and _ecvt.  THE LAYOUT is K&R 2nd ed B.1.2, p.203, rather
 * than fltpr.s's, which differs for %e and %g:
 *   f  "decimal notation of the form [-]mmm.ddd, where the number of d's is
 *      given by the precision.  The default precision is 6; a precision of 0
 *      suppresses the decimal point."
 *   e  "[-]m.dddddde+/-xx or [-]m.ddddddE+/-xx, where the number of d's is
 *      specified by the precision."  So ecvt is asked for precision + 1
 *      digits; pscien asks for `precision' and prints one fewer.
 *   g  "%e or %E is used if the exponent is less than -4 or greater than or
 *      equal to the precision; otherwise %f is used.  Trailing zeros and a
 *      trailing decimal point are not printed."  gcvt(3) switches on
 *      `decpt-ndigit > 4' instead, so pgen's rule is not K&R's.
 * The exponent has at least two digits, and three at 100 or more, which a
 * double reaches.  An infinity or a NaN prints as ecvt spells it, "inf" or
 * "nan", after its sign.
 */
int __lc_fltused;

char *ecvt(), *fcvt();

/* The exponent: e or E, a sign, and at least two digits. */
static void
__lc_pf_exp(int ech, int x)
{
    __lc_gput(ech);
    if (x < 0) {
        __lc_gput('-');
        x = -x;
    } else {
        __lc_gput('+');
    }
    if (x >= 100) {
        __lc_gput('0' + x / 100);
        x = x % 100;
    }
    __lc_gput('0' + x / 10);
    __lc_gput('0' + x % 10);
}

/* Trailing zeros, then a trailing point, off the staged conversion. */
static void
__lc_pf_strip(void)
{
    while (__lc_pf_glen > 0 && __lc_pf_gbuf[__lc_pf_glen - 1] == '0')
        __lc_pf_glen--;
    if (__lc_pf_glen > 0 && __lc_pf_gbuf[__lc_pf_glen - 1] == '.')
        __lc_pf_glen--;
}

/* One %e, %f or %g conversion of f, for printf.c's __lc_vpf: c is the
 * conversion character, and the flags are printf's. */
void __lc_pf_float(int c, double f, int width, int prec, int hasprec,
                   int zeropad, int leftjust)
{
    int decpt, sign, i, P, X, ech;
    char *p;

    if (!hasprec)
        prec = 6;
    ech = (c == 'E' || c == 'G') ? 'E' : 'e';
    P = (prec == 0) ? 1 : prec;
    if (c == 'f' || c == 'F')
        p = fcvt(f, prec, &decpt, &sign);
    else if (c == 'e' || c == 'E')
        p = ecvt(f, prec + 1, &decpt, &sign);
    else
        p = ecvt(f, P, &decpt, &sign);
    if (sign) {                          /* sign first; magnitude staged */
        __lc_pfc('-');
        if (width)
            width--;
    }
    __lc_pf_glen = 0;
    if (*p == 'i' || *p == 'n') {        /* ecvt's "inf" or "nan" */
        while (*p)
            __lc_gput(*p++);
    } else if (c == 'f' || c == 'F') {
        /* fcvt gives decpt + prec digits; one past NDIG is cut short, and
         * the places it could not reach print as 0. */
        if (decpt <= 0)
            __lc_gput('0');
        for (i = 0; i < decpt; i++)
            __lc_gput(*p ? *p++ : '0');
        if (prec > 0)
            __lc_gput('.');
        for (i = 0; i < prec; i++)
            __lc_gput((i < -decpt || !*p) ? '0' : *p++);
    } else if (c == 'e' || c == 'E') {
        if (*p == '0')                   /* zero: fltpr.s's pscien, e+00 */
            decpt++;
        __lc_gput(*p++);
        if (prec > 0)
            __lc_gput('.');
        for (i = 0; i < prec; i++)
            __lc_gput(*p ? *p++ : '0');
        __lc_pf_exp(ech, decpt - 1);
    } else {
        X = (*p == '0') ? 0 : decpt - 1; /* zero's exponent is 0 */
        if (X < -4 || X >= P) {
            __lc_gput(*p++);
            __lc_gput('.');
            for (i = 1; i < P; i++)
                __lc_gput(*p++);
            __lc_pf_strip();
            __lc_pf_exp(ech, X);
        } else {
            if (X >= 0) {
                for (i = 0; i <= X; i++)
                    __lc_gput(*p++);
                __lc_gput('.');
                for (i = X + 1; i < P; i++)
                    __lc_gput(*p++);
            } else {
                __lc_gput('0');
                __lc_gput('.');
                for (i = 0; i < -X - 1; i++)
                    __lc_gput('0');
                for (i = 0; i < P; i++)
                    __lc_gput(*p++);
            }
            __lc_pf_strip();
        }
    }
    __lc_pf_padout(width, zeropad, leftjust, 0);
}
