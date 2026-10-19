/* B-6 follow-up: real %g (shortest of %e/%f at P significant digits, then
 * strip trailing zeros).  pf_emit_float's %g path generates P+1 digits,
 * rounds half-up (carry may bump the decimal exponent), picks %f when
 * -4 <= X < P else %e, lays out, and strips.  All targets host-verified
 * against glibc printf.  Returns 42 iff every conversion matches. */
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
    sprintf(buf, "%g", 3.5);        if (!streq(buf, "3.5"))     return 1;
    sprintf(buf, "%g", 100000.0);   if (!streq(buf, "100000"))  return 2;
    sprintf(buf, "%g", 1000000.0);  if (!streq(buf, "1e+06"))   return 3;
    sprintf(buf, "%g", 0.0001);     if (!streq(buf, "0.0001"))  return 4;
    sprintf(buf, "%g", 0.00001);    if (!streq(buf, "1e-05"))   return 5;
    sprintf(buf, "%g", 0.0);        if (!streq(buf, "0"))       return 6;
    sprintf(buf, "%g", 3.14159);    if (!streq(buf, "3.14159")) return 7;
    sprintf(buf, "%.3g", 3.14159);  if (!streq(buf, "3.14"))    return 8;
    sprintf(buf, "%g", 0.000123);   if (!streq(buf, "0.000123")) return 9;
    sprintf(buf, "%g", -2.5);       if (!streq(buf, "-2.5"))    return 10;

    return 42;
}
