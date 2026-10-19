/* G-PF1: 32-bit long printf -- %ld (signed, incl. large negative), %lu (full
 * 32-bit range), and %lx (8 hex digits).  Exercises pf_format_udec32, the
 * 32-bit signed negate, and the 8-nibble pf_emit_hex.  Returns 42 iff all
 * six format correctly.
 *
 * b5/b6 ARE THE SEAM.  __lc_pf_udec peels high digits in 32-bit arithmetic
 * only while the value still needs 32 bits and finishes in 16, so `v > 65535L'
 * is a branch whose two sides run different divide routines.  100000 and
 * 4294967295 above both cross it mid-number and would catch a broken 32-bit
 * side; neither lands ON it, and an off-by-one in the test sends 65536 down
 * the 16-bit path where it truncates. */
#include <stdio.h>

char b1[16];
char b2[16];
char b3[16];
char b4[16];
char b5[16];
char b6[16];

int streq(char *s, char *t)
{
    int i;
    i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];                 /* both reached NUL together */
}

int main()
{
    long x;
    x = 100000L;       sprintf(b1, "%ld", x);   /* "100000"  (> 16 bits)     */
    x = 0L - 100000L;  sprintf(b2, "%ld", x);   /* "-100000" (32-bit negate) */
    x = 0x12345678L;   sprintf(b3, "%lx", x);   /* "12345678" (8 hex digits) */
    x = 0L - 1L;       sprintf(b4, "%lu", x);   /* "4294967295" (max u32)    */
    x = 65535L;        sprintf(b5, "%lu", x);   /* last value that fits 16   */
    x = 65536L;        sprintf(b6, "%lu", x);   /* first that does not       */
    if (streq(b1, "100000") && streq(b2, "-100000") &&
        streq(b3, "12345678") && streq(b4, "4294967295") &&
        streq(b5, "65535") && streq(b6, "65536"))
        return 42;
    return 1;
}
