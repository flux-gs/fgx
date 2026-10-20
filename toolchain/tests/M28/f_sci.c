/* B-6 deferred: printf %e (scientific).  %e normalizes the magnitude
 * to [1,10) via repeated *10 / /10 (tracking the decimal exponent) then emits
 * d.dddde+-NN.  (Real %g has its own fixture, f_gfmt.)  Returns 42 iff all
 * conversions match. */
#include <stdio.h>

char buf[32];

int streq(char *s, char *t)
{
    int i;
    i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];
}

int main(void)
{
    sprintf(buf, "%e", 0.0);    if (!streq(buf, "0.000000e+00")) return 1;
    sprintf(buf, "%e", 2.0);    if (!streq(buf, "2.000000e+00")) return 2;
    sprintf(buf, "%e", 0.5);    if (!streq(buf, "5.000000e-01")) return 3;
    sprintf(buf, "%e", 100.0);  if (!streq(buf, "1.000000e+02")) return 4;
    sprintf(buf, "%.1e", 0.25); if (!streq(buf, "2.5e-01"))      return 5;
    return 42;
}
