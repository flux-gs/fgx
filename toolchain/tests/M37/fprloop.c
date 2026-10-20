/* H1 minimal repro: a pointer LOCAL conditionally REASSIGNED inside a loop
 * body, then passed to a libc binding at the top of the next iteration —
 * the call's argument sees the PREVIOUS iteration's pointer (stale FPR /
 * spill across the back-edge).  Found live as ls/getdir's post-realloc
 * memset(fp,...) writing through the old block (heap-corruption storm).
 * Host clang cross-checks.  6+6+6+6+6+6+6 = 42. */
#include <string.h>

struct rec { int tag; char *name; int pad[11]; };

struct rec g1[4], g2[4];

int main(void)
{
    struct rec *fp;
    int i, r = 0;

    g1[2].tag = 77;                  /* canary: must survive */
    g1[3].tag = 78;
    fp = g1;
    for (i = 0; i < 4; i++) {
        memset((char *)fp, 0, sizeof(struct rec));
        fp->tag = i + 1;
        fp->name = strdup("x");      /* ptr-returning call stored THROUGH fp
                                      * (the FPR spill/restore trigger) */
        if (fp->name == 0) return 9;
        fp++;
        if (i == 1)
            fp = g2;                 /* conditional mid-loop reassign */
    }
    if (g1[0].tag == 1)  r += 6;
    if (g1[1].tag == 2)  r += 6;
    if (g2[0].tag == 3)  r += 6;
    if (g2[1].tag == 4)  r += 6;
    if (g1[2].tag == 77) r += 6;     /* stale fp would memset these */
    if (g1[3].tag == 78) r += 6;
    if (g2[2].tag == 0)  r += 6;
    return r;
}
