/* printf's %e, %f and %g on ecvt(3)/fcvt(3), and atof, modf and ldexp --
 * apple/fgx#447 increment 6.  The digits are 2.11BSD's ecvt.c; the layout is
 * K&R 2nd ed B.1.2, p.203, including %E and %G in capitals, %g's switch to
 * %e below 1e-4 and at the precision, and three-digit exponents.  Values are
 * the 64-bit double.  9.9999996 at %g has six digits 999999 that round up
 * into a carry that moves the point.  A failing check returns its number; all
 * passing returns 42. */
#include <stdio.h>

char *ecvt(), *fcvt();
double atof(), modf(), ldexp();
char buf[40];

int streq(s, t)
char *s, *t;
{
    int i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];
}

int main()
{
    int d, s;
    char *p;
    double ip;
    float big;

    p = ecvt(3.14159, 5, &d, &s);
    if (!streq(p, "31416") || d != 1 || s != 0) return 1;
    p = fcvt(1234.5678, 2, &d, &s);
    if (!streq(p, "123457") || d != 4 || s != 0) return 2;
    p = ecvt(-0.00125, 3, &d, &s);
    if (!streq(p, "125") || d != -2 || s != 1) return 3;

    sprintf(buf, "%E", 12345.0);
    if (!streq(buf, "1.234500E+04")) return 4;
    sprintf(buf, "%G", 0.0000123);
    if (!streq(buf, "1.23E-05")) return 5;
    sprintf(buf, "%g", 100000.0);
    if (!streq(buf, "100000")) return 6;
    sprintf(buf, "%g", 1000000.0);
    if (!streq(buf, "1e+06")) return 7;
    sprintf(buf, "%g", 0.0001);
    if (!streq(buf, "0.0001")) return 8;
    sprintf(buf, "%e", 0.0);
    if (!streq(buf, "0.000000e+00")) return 9;
    sprintf(buf, "%.0e", 52.0);
    if (!streq(buf, "5e+01")) return 10;

    /* An infinity from its bits: the single runtime flushes an overflow to
     * 0 and has none of its own, and the soft double's widening keeps it. */
    *(long *)&big = 0x7F800000L;
    sprintf(buf, "%f", big);
    if (!streq(buf, "inf")) return 11;
    sprintf(buf, "%g", -big);
    if (!streq(buf, "-inf")) return 12;

    if (atof("0.1") != 0.1) return 13;
    if (atof("1.5e3") != 1500) return 14;
    if (atof("-2.5") != -2.5) return 15;
    if (modf(-3.75, &ip) != -0.75 || ip != -3.0) return 16;
    if (ldexp(3.0, 4) != 48.0) return 17;
    sprintf(buf, "%g", 9.9999996);
    if (!streq(buf, "10")) return 18;
    sprintf(buf, "%.3e", 1e300);
    if (!streq(buf, "1.000e+300")) return 19;
    return 42;
}
