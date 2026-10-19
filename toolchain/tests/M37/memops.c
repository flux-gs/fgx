/* T5-C C4b: memcpy/memset in C over __asm — the first __asm consumers.
 *
 * Cross-bank on purpose: the source is a bank-0 STACK local, the dest a
 * data-segment global — the [dp],Y long-pointer loops must carry both
 * banks.  Also pins n=0 (no bytes touched) and the return-dst
 * convention.  clang cross-checked: 8*5 + 2 = 42.
 *
 * (First calibration ran 40: WITHOUT <string.h> fcc defaults memset to
 * an int-returning extern, so the return-value compare was a truncated
 * bank-zeroed word — declare your protos.) */
#include <string.h>

char gbuf[16];

int main(void)
{
    char lb[8];
    int i, r = 0;

    memset(lb, 'A', 8);              /* bank-0 stack fill */
    memcpy(gbuf, lb, 8);             /* bank 0 -> data bank */
    memset(gbuf + 4, 'B', 2);        /* offset poke through ptr arith */
    for (i = 0; i < 8; i++) {
        if (gbuf[i] == "AAAABBAA"[i])
            r += 5;
    }
    if (memset(gbuf, 'Z', 0) == (void *)gbuf)
        r += 2;                      /* n=0 edge + return value */
    return r;
}
