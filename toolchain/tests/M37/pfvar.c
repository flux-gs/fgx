/* T5-C C5: printf family as ordinary variadic C (c_printf & co in the pile).
 * Pins the NEWLY-expressible surface: >9 args (the libc_args 9-arg cap is
 * retired), REAL snprintf truncation (the old binding aliased sprintf with
 * the size ignored), '*' width from an arg, %.Ns precision, %c char
 * promotion, and float VARIABLE varargs (%f/%g through va_arg — the M28
 * fixtures only pass literals).  Host clang cross-checks:
 * 6+8+7+6+5+4+3+3 = 42. */
#include <stdio.h>

char buf[64];

int streq(char *s, char *t)
{
    int i = 0;
    while (s[i] && s[i] == t[i]) i++;
    return s[i] == t[i];
}

int main(void)
{
    int r = 0, n;
    char cv = 'Q';
    float fv = 1.5;
    float gv = 0.375;

    sprintf(buf, "%d%d%d%d%d%d%d%d%d%d%d", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
    if (streq(buf, "1234567891011")) r += 6;

    n = snprintf(buf, 4, "%d", 12345);
    if (streq(buf, "123") && n == 5) r += 8;

    sprintf(buf, "%*d|%-*d", 5, 42, 4, 7);
    if (streq(buf, "   42|7   ")) r += 7;

    sprintf(buf, "%.3s", "hello");
    if (streq(buf, "hel")) r += 6;

    sprintf(buf, "%c%c", cv, 'z');
    if (streq(buf, "Qz")) r += 5;

    sprintf(buf, "%.2f", fv);
    if (streq(buf, "1.50")) r += 4;

    sprintf(buf, "%g", gv);
    if (streq(buf, "0.375")) r += 3;

    n = sprintf(buf, "ret%d", 7);
    if (n == 4) r += 3;

    return r;                                    /* 42 */
}
