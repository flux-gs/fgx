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
 * doprnt.c, 4.3BSD-Reno's _doprnt, calls __lc_pf_float where Reno calls its
 * cvt, with cvt's interface: the digits go into the caller's buffer from
 * startp + 1, a negative number sets *signp to '-', and the length is
 * returned.  libc.so's one printf serves every dynamic program, as in SunOS
 * 4.1.3's shared libc, which has no fltused.  A static link (fgx_static)
 * takes this member only for a program that carries the marker; any other
 * gets toolchain/lib/ffltpr.c's __lc_pf_float, which gives a `?'.
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

static char *__lc_fpt, *__lc_fpe;        /* the caller's buffer */

static void
__lc_fput(int c)
{
    if (__lc_fpt < __lc_fpe)
        *__lc_fpt++ = c;
}

/* The exponent: e or E, a sign, and at least two digits. */
static void
__lc_pf_exp(int ech, int x)
{
    __lc_fput(ech);
    if (x < 0) {
        __lc_fput('-');
        x = -x;
    } else {
        __lc_fput('+');
    }
    if (x >= 100) {
        __lc_fput('0' + x / 100);
        x = x % 100;
    }
    __lc_fput('0' + x / 10);
    __lc_fput('0' + x % 10);
}

/* Trailing zeros, then a trailing point, off the conversion so far. */
static void
__lc_pf_strip(char *start)
{
    while (__lc_fpt > start && __lc_fpt[-1] == '0')
        __lc_fpt--;
    if (__lc_fpt > start && __lc_fpt[-1] == '.')
        __lc_fpt--;
}

/* One %e, %f or %g conversion of f into startp + 1 .. endp, for doprnt.c:
 * fmtch is the conversion character and prec its precision, which _doprnt
 * has already defaulted to 6.  Returns the length. */
int
__lc_pf_float(double f, int prec, int flags, char *signp, int fmtch,
              char *startp, char *endp)
{
    int decpt, sign, i, P, X, ech, c;
    char *p, *start;

    c = fmtch;
    start = __lc_fpt = startp + 1;
    __lc_fpe = endp;
    ech = (c == 'E' || c == 'G') ? 'E' : 'e';
    P = (prec == 0) ? 1 : prec;
    if (c == 'f' || c == 'F')
        p = fcvt(f, prec, &decpt, &sign);
    else if (c == 'e' || c == 'E')
        p = ecvt(f, prec + 1, &decpt, &sign);
    else
        p = ecvt(f, P, &decpt, &sign);
    if (sign)
        *signp = '-';
    if (*p == 'i' || *p == 'n') {        /* ecvt's "inf" or "nan" */
        while (*p)
            __lc_fput(*p++);
    } else if (c == 'f' || c == 'F') {
        /* fcvt gives decpt + prec digits; one past NDIG is cut short, and
         * the places it could not reach print as 0. */
        if (decpt <= 0)
            __lc_fput('0');
        for (i = 0; i < decpt; i++)
            __lc_fput(*p ? *p++ : '0');
        if (prec > 0)
            __lc_fput('.');
        for (i = 0; i < prec; i++)
            __lc_fput((i < -decpt || !*p) ? '0' : *p++);
    } else if (c == 'e' || c == 'E') {
        if (*p == '0')                   /* zero: fltpr.s's pscien, e+00 */
            decpt++;
        __lc_fput(*p++);
        if (prec > 0)
            __lc_fput('.');
        for (i = 0; i < prec; i++)
            __lc_fput(*p ? *p++ : '0');
        __lc_pf_exp(ech, decpt - 1);
    } else {
        X = (*p == '0') ? 0 : decpt - 1; /* zero's exponent is 0 */
        if (X < -4 || X >= P) {
            __lc_fput(*p++);
            __lc_fput('.');
            for (i = 1; i < P; i++)
                __lc_fput(*p++);
            __lc_pf_strip(start);
            __lc_pf_exp(ech, X);
        } else {
            if (X >= 0) {
                for (i = 0; i <= X; i++)
                    __lc_fput(*p++);
                __lc_fput('.');
                for (i = X + 1; i < P; i++)
                    __lc_fput(*p++);
            } else {
                __lc_fput('0');
                __lc_fput('.');
                for (i = 0; i < -X - 1; i++)
                    __lc_fput('0');
                for (i = 0; i < P; i++)
                    __lc_fput(*p++);
            }
            __lc_pf_strip(start);
        }
    }
    return (int)(__lc_fpt - start);
}
