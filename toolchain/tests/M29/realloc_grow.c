/* realloc_grow.c — SYS_REALLOC (kernel #91) + c_realloc shim, exercised via
 * the K&R empty-paren declaration fix.
 *
 * Verifies the kernel's alloc+copy+free preserves the original bytes when a
 * block GROWS, keeps the surviving prefix when it SHRINKS, and that
 * realloc(NULL, n) behaves as malloc(n).  Returns 42 iff every check holds.
 *
 * Cross-checked on the host with the real <stdlib.h> realloc: clang returns 42
 * too, so the oracle reflects C semantics (the C-reference discipline).
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
char *realloc(char *, unsigned long);
void  free();
#else
#include <stdlib.h>
#endif

int main(void)
{
    char *p;
    int   i;

    /* grow: fill 16 bytes, realloc to 200, the original 16 must survive. */
    p = malloc(16);
    if (p == 0) return 1;
    for (i = 0; i < 16; i++) p[i] = (char)(i + 1);
    p = realloc(p, 200);
    if (p == 0) return 2;
    for (i = 0; i < 16; i++) if ((p[i] & 0xFF) != i + 1) return 3;
    /* use the grown region too (catches a short/zero-length copy) */
    for (i = 16; i < 200; i++) p[i] = (char)(i & 0x7F);
    for (i = 0; i < 16; i++)   if ((p[i] & 0xFF) != i + 1) return 4;

    /* shrink: realloc to 8, the first 8 bytes must survive. */
    p = realloc(p, 8);
    if (p == 0) return 5;
    for (i = 0; i < 8; i++) if ((p[i] & 0xFF) != i + 1) return 6;
    free(p);

    /* realloc(NULL, n) == malloc(n). */
    p = realloc((char *)0, 32);
    if (p == 0) return 7;
    p[0] = 11; p[31] = 13;
    if ((p[0] & 0xFF) != 11)  return 8;
    if ((p[31] & 0xFF) != 13) return 9;
    free(p);

    return 42;
}
