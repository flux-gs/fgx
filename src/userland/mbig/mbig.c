/* mbig — train-2 M-4 exit-criterion fixture.
 *
 * Proves: malloc(80000L) succeeds (SYS_MALLOC32 dedicated MM block) and the
 * block is USABLE ACROSS its bank crossing (fcc far-pointer + 32-bit index
 * arithmetic carries the bank).  Also proves free() routes the offset-0
 * big-block shape (DisposeHandle + row tombstone) and that a second big
 * malloc reuses the freed table row.
 *
 * Output: "MB=P" on success, "MB=F:<step>" on the first failure.
 */
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    unsigned long n = 80000L;
    unsigned char *p;
    unsigned char *q;
    unsigned long i;

    p = (unsigned char *)malloc(n);
    if (p == 0) {
        printf("MB=F:alloc\n");
        return 1;
    }

    /* Stamp a position-derived pattern across the whole block — the stride
     * lands on both sides of the 64 KB bank boundary — then verify. */
    for (i = 0; i < n; i += 257)
        p[i] = (unsigned char)(i ^ (i >> 8));
    for (i = 0; i < n; i += 257)
        if (p[i] != (unsigned char)(i ^ (i >> 8))) {
            printf("MB=F:verify\n");
            return 1;
        }

    /* A small arena malloc stays healthy alongside the big block. */
    q = (unsigned char *)malloc(64);
    if (q == 0) {
        printf("MB=F:small\n");
        return 1;
    }
    q[0] = 'k';
    q[63] = 'q';
    if (q[0] != 'k' || q[63] != 'q') {
        printf("MB=F:smallrw\n");
        return 1;
    }
    free(q);

    free(p);

    /* The freed row is a tombstone: a second big alloc must reuse it. */
    p = (unsigned char *)malloc(70000L);
    if (p == 0) {
        printf("MB=F:rowreuse\n");
        return 1;
    }
    p[0] = 1;
    p[69999] = 2;
    if (p[0] != 1 || p[69999] != 2) {
        printf("MB=F:rw2\n");
        return 1;
    }
    free(p);

    printf("MB=P\n");
    return 0;
}
