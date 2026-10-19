/* printf's 64-bit conversions and <limits.h>'s long long limits --
 * sub-increment 1f of the C99 extension
 * (docs/history/plans/2026-09-23-fcc-long-long-plan.md); not K&R.  `ll' is
 * C99's length modifier and `q' is 4.4BSD's (netbsd-0-9 vfprintf.c's
 * QUADINT).  Every expected string was computed on the host.  A long long
 * between two other arguments checks that the argument walk steps eight
 * bytes.  A failing check returns its number; all passing returns 42. */
#include <limits.h>
#include <stdio.h>
#include <string.h>

static char b[64];

int
main()
{
    long long a = 0x0123456789ABCDEFLL;

    sprintf(b, "%lld", a);
    if (strcmp(b, "81985529216486895") != 0) return 1;
    sprintf(b, "%lld", LLONG_MIN);
    if (strcmp(b, "-9223372036854775808") != 0) return 2;
    sprintf(b, "%llu", ULLONG_MAX);
    if (strcmp(b, "18446744073709551615") != 0) return 3;
    sprintf(b, "%llx|%llX", a, a);
    if (strcmp(b, "123456789abcdef|123456789ABCDEF") != 0) return 4;
    sprintf(b, "%llo", ULLONG_MAX);
    if (strcmp(b, "1777777777777777777777") != 0) return 5;
    sprintf(b, "%qd|%llu", -1LL, 0LL);
    if (strcmp(b, "-1|0") != 0) return 6;
    sprintf(b, "%020lld|%-6lld|%6lld", -42LL, 7LL, -7LL);
    if (strcmp(b, "-0000000000000000042|7     |    -7") != 0) return 7;
    sprintf(b, "%d %lld %ld %d", 3, a, 70000L, 9);
    if (strcmp(b, "3 81985529216486895 70000 9") != 0) return 8;
    if (LLONG_MAX != 0x7FFFFFFFFFFFFFFFLL || LLONG_MIN >= 0 ||
        LLONG_MIN + LLONG_MAX != -1 || ULLONG_MAX != 0xFFFFFFFFFFFFFFFFULL)
        return 9;
    return 42;
}
