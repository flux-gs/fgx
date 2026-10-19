/* H1 find-repro: the EXACT getdir() SHAPE — the growing array is handed
 * back through OUT-PARAMETERS (struct rec **pfp0/pfplast = far pointers
 * into main's bank-0 stack frame), with the DIR live and strdup churn
 * interleaved, realloc-doubling THROUGH *pfp0.  ls corrupts under this
 * shape; the plain-local variants (heapchurn, earlier dirchurn) are
 * green — the out-param indirection is the differentiator (the elvis
 * multibank whack-a-mole class).  FGX-only (MAME oracle).  Exit 42;
 * 100+i first bad name; 200+i bad tag; 60+n low count. */
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

char nbuf[16];

struct rec { int tag; char *name; int pad[11]; };  /* == 28 B, afile-exact */

int getall(dir, pfp0, pfplast)
    char *dir;
    struct rec **pfp0, **pfplast;
{
    struct rec *fp;
    int nent = 20, n = 0;

    fp = *pfp0 = (struct rec *)calloc(nent, sizeof(struct rec));
    *pfplast = *pfp0 + nent;
    while (n < 46) {
        struct rec *dbg0 = *pfp0;
        sprintf(nbuf, "name%02d", n);
        if (n > 0 && dbg0->name[0] != 'n') return -20;   /* dead at loop top */
        memset((char *)fp, 0, sizeof(struct rec));
        if (n > 0 && dbg0->name[0] != 'n') return -13;   /* dead by memset */
        fp->tag = n;
        if (n > 0 && dbg0->name[0] != 'n') return -15;   /* dead by tag store */
        fp->name = strdup(nbuf);
        if (fp->name == 0) return -2;
        if (n > 0 && dbg0->name[0] != 'n') return -14;   /* dead by strdup */
        fp++;
        n++;
        if (fp == *pfplast) {
            struct rec *c0 = *pfp0;
            struct rec *before = *pfp0;
            if (c0->name[0] != 'n') return -10;      /* dead BEFORE realloc */
            *pfp0 = (struct rec *)realloc((char *)*pfp0,
                                          2 * nent * sizeof(struct rec));
            if (*pfp0 == before) return -18;         /* store never landed
                                                      * (grow must move) */
            if (*pfp0 == 0) return -3;
            c0 = *pfp0;
            if (c0->name[0] != 'n') return -11;      /* dead BY realloc */
            fp = *pfp0 + nent;
            if (fp != c0 + nent) return -16;         /* fp arith broken */
            {   /* is the new block REALLY 2*nent*28 bytes?  poke its tail */
                char *e = (char *)c0;
                int k;
                for (k = nent * sizeof(struct rec); k < 2 * nent * sizeof(struct rec); k++)
                    e[k] = 0x55;
                if (c0->name[0] != 'n') return -17;  /* tail poke killed name0 */
            }
            *pfplast = fp + nent;
            nent *= 2;
            if (c0->name[0] != 'n') return -12;      /* dead by fp/plast updates */
        }
    }
    *pfplast = fp;
    return n;
}

int main(void)
{
    struct rec *v, *fp;
    struct rec *vlast;
    int n, i, j;

    n = getall("/bin", &v, &vlast);
    if (n == -10) return 50;
    if (n == -11) return 51;
    if (n == -12) return 52;
    if (n == -20) return 53;
    if (n == -13) return 54;
    if (n == -15) return 55;
    if (n == -14) return 56;
    if (n == -16) return 57;
    if (n == -17) return 58;
    if (n == -18) return 59;
    if (n < 0) return 1;
    if (n < 20) return 60 + n;
    fp = v;
    for (i = 0; i < n; i++) {
        if (fp->tag != i) return 200 + (i > 54 ? 54 : i);
        if (fp->name[0] != 'n') return 100 + (i > 54 ? 54 : i);
        fp++;
    }
    free((char *)v);
    return 42;
}
