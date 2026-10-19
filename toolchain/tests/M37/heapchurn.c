/* H1 find-repro: ls-shaped heap churn — calloc'd growing array REALLOCATED
 * (doubling) while small strdup blocks interleave, then verify every early
 * string survived and free everything.  On FGX this pattern corrupted the
 * kernel arena (first ~30 names trashed, double-free storm at cleanup).
 * Host clang cross-checks the logic.  Exit 42, or 100+i at the first
 * corrupted string, or 200+i at the first corrupted array slot. */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

struct rec { int tag; char *name; int pad[12]; };   /* ~30 B like afile */

char nbuf[16];

int main(void)
{
    struct rec *v;
    int nent = 20, n = 0, i, j;

    struct rec *fp;

    v = (struct rec *)calloc(nent, sizeof(struct rec));
    if (v == 0) return 1;
    fp = v;
    for (i = 0; i < 46; i++) {
        sprintf(nbuf, "name%02d", i);
        fp->tag = i;
        fp->name = strdup(nbuf);
        if (fp->name == 0) return 2;
        fp++;
        n++;
        if (n == nent) {
            v = (struct rec *)realloc((char *)v,
                                      2 * nent * sizeof(struct rec));
            if (v == 0) return 3;
            fp = v + nent;
            nent *= 2;
        }
    }
    fp = v;
    for (i = 0; i < 46; i++) {
        sprintf(nbuf, "name%02d", i);
        if (fp->tag != i) return 200 + i;
        for (j = 0; nbuf[j]; j++)
            if (fp->name[j] != nbuf[j]) return 100 + i;
        if (fp->name[j] != 0) return 100 + i;
        fp++;
    }
    fp = v;
    for (i = 0; i < 46; i++) {
        free(fp->name);
        fp++;
    }
    free((char *)v);
    return 42;
}
