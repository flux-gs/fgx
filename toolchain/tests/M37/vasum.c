/* T5-C C2: real va_list over the K&R right-to-left stack ABI (<stdarg.h>).
 *
 * A variadic-DEFINED function walks 3 promoted ints, a 4-byte long slot,
 * and a 4-byte char* slot via va_arg — the full slot-size matrix.  The
 * va_start anchor is &last-named-param (bank-0 hardware stack, P3-3).
 * clang cross-checked (host stdarg): 35 + 5 + 2 = 42. */
#include <stdarg.h>

int vsum(int n, ...)
{
    va_list ap;
    int s = 0;
    long lv;
    char *sp;

    va_start(ap, n);
    while (n-- > 0)
        s += va_arg(ap, int);
    lv = va_arg(ap, long);
    sp = va_arg(ap, char *);
    s += (int)(lv >> 16);
    if (sp[0] == 'Z')
        s += 2;
    va_end(ap);
    return s;
}

int main(void)
{
    return vsum(3, 12, 11, 12, 0x50000L, "Z");
}
