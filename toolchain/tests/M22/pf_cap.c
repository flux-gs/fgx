/* 2.11BSD's capital conversions: %D %U %O print a long as %ld %lu %lo do
 * (vendor/2.11BSD/usr/lib/libc/pdp/stdio/doprnt.s, swtab), with width.  Each
 * value needs its high word, so a 16-bit read could not pass.  %X is ANSI's
 * upper-case hex of an int.  Returns 42 iff all four format correctly. */
#include <stdio.h>

char b1[16];
char b2[16];
char b3[16];
char b4[16];

int streq(char *s, char *t)
{
    int i;
    i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];
}

int main()
{
    long x;
    x = 0L - 100000L;  sprintf(b1, "%9D", x);   /* "  -100000" */
    x = 70000L;        sprintf(b2, "%U", x);    /* "70000"     */
    x = 0x10008L;      sprintf(b3, "%O", x);    /* "200010"    */
    sprintf(b4, "%X", 0xBEEF);                  /* "BEEF"      */
    if (streq(b1, "  -100000") && streq(b2, "70000") &&
        streq(b3, "200010") && streq(b4, "BEEF"))
        return 42;
    return 1;
}
