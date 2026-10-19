/* M11: libc atol — 32-bit parse, BANK-AWARE (works on a malloc'd / far string).
 * Promoted from expr(1)'s local atol so the toolchain owns it (CORE rule: no
 * per-tool copy of a standard fn).  c_atol seeds a bank-aware LIBC_DP_LP0 from
 * the long-ptr arg, so reading a heap string in a non-DBR bank works; the
 * 16-bit atoi path is DBR-relative and would miss it.  -100000 exercises both
 * the sign and the 32-bit accumulate (> 16 bits).  Returns 42 iff correct. */
#include <stdlib.h>
int main(void)
{
    char *p;
    long  v;

    p = malloc(16);
    if (!p)
        return 1;
    p[0] = '-'; p[1] = '1'; p[2] = '0'; p[3] = '0';
    p[4] = '0'; p[5] = '0'; p[6] = '0'; p[7] = 0;     /* "-100000" */
    v = atol(p);
    if (v == -100000L)
        return 42;
    return 1;
}
