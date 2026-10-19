/* B-6 follow-up: field width + justify + zero-pad for %f / %e / %g.
 * The float conversions now stage their magnitude into pf_gbuf and emit it
 * width-padded (pf_pad_emit_gbuf); the sign is emitted first with pf_width
 * decremented, so '0' padding lands after the sign ("%08.2f" of -3.14 ->
 * "-0003.14").  All targets host-verified against glibc.  Returns 42. */
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
    sprintf(buf, "%8.2f", 3.14159);   if (!streq(buf, "    3.14"))   return 1;
    sprintf(buf, "%-8.2f", 3.14159);  if (!streq(buf, "3.14    "))   return 2;
    sprintf(buf, "%08.2f", 3.14159);  if (!streq(buf, "00003.14"))   return 3;
    sprintf(buf, "%08.2f", -3.14159); if (!streq(buf, "-0003.14"))   return 4;
    sprintf(buf, "%10.2e", 1234.5);   if (!streq(buf, "  1.23e+03")) return 5;
    sprintf(buf, "%-10.2e", 1234.5);  if (!streq(buf, "1.23e+03  ")) return 6;
    sprintf(buf, "%8g", 3.5);         if (!streq(buf, "     3.5"))   return 7;
    sprintf(buf, "%-8g", 3.5);        if (!streq(buf, "3.5     "))   return 8;
    sprintf(buf, "%08g", 3.5);        if (!streq(buf, "000003.5"))   return 9;
    sprintf(buf, "%10.3g", 1234567.0); if (!streq(buf, "  1.23e+06")) return 10;

    return 42;
}
