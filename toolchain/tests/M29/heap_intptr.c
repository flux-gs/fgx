/* heap_intptr.c — store/read small ints through a malloc'd int* heap pointer
 * using pre/post-inc + a shift-down copy, mirroring 2.11BSD ed's line-handle
 * array (zero/dot/dol are int* into a malloc'd block; append does
 * `a1 = ++dol; *--a2 = *--a1; *rdot = tl`).  ed reads its handles back as huge
 * values (block offsets 1024/3072 for a 3-line file), so this isolates whether
 * int* arithmetic/deref on a heap (bank $07-$09) pointer is the culprit.
 * Returns 42 iff every value round-trips; clang returns 42 too.
 */
#ifdef __FGX__
/* malloc/realloc take the FULL 32-bit size_t on FGX (train-2 M-4: requests
 * past the arena go to a dedicated MM bank, so malloc(80000L) is real).  They
 * therefore CANNOT be declared K&R empty-paren here: `char *malloc();` makes
 * the caller push a 2-byte int for a 4-byte parameter, the callee reads a
 * garbage high word, and malloc returns NULL -- which is exactly how this
 * fixture failed once the runtime oracle came back online.  free() stays
 * empty-paren; it takes a pointer, so there is no width to get wrong.
 *
 * The K&R-unspecified-args coverage this fixture used to claim lives in
 * fixtures whose callee arguments are all int-width.  For a 32-bit size_t the
 * K&R spelling is not "unspecified", it is wrong. */
char *malloc(unsigned long);
#else
#include <stdlib.h>
#endif

int main(void)
{
    int *base, *p, *q;

    base = (int *)malloc(64);
    if (base == 0) return 9;

    /* store 2,6,10 at base[1..3] via pre-increment (ed append style) */
    p = base;
    *++p = 2;
    *++p = 6;
    *++p = 10;

    /* read back via post-increment */
    q = base + 1;
    if (*q++ != 2)  return 1;
    if (*q++ != 6)  return 2;
    if (*q   != 10) return 3;

    /* shift-down copy: ed's `*--a2 = *--a1` */
    p = base + 4;
    q = base + 4;
    *--p = *--q;            /* base[3] = base[3] (self) ... use distinct: */
    p = base + 3;
    q = base + 2;
    *p = *q;                /* base[3] = base[2] = 6 */
    if (base[3] != 6) return 4;
    if (base[1] != 2) return 5;

    return 42;
}
