/* B-6 follow-up probe: %f integer part beyond 2^31.  Each value is an exact
 * float (multiple of its ULP).  Returns the index of the first wrong
 * conversion, or 42 if all pass — so the MAME exit code reveals the boundary. */
#include <stdio.h>

char buf[48];

int streq(char *s, char *t)
{
    int i;
    i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];
}

int main(void)
{
    sprintf(buf, "%.1f", 2000000000.0); if (!streq(buf, "2000000000.0")) return 1;
    sprintf(buf, "%.1f", 3000000000.0); if (!streq(buf, "3000000000.0")) return 2;
    sprintf(buf, "%.1f", 4294967040.0); if (!streq(buf, "4294967040.0")) return 3;
    return 42;
}
