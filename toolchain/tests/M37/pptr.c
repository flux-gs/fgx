/* H1 minimal bisect of the dirchurn/getdir corruption: far-pointer traffic
 * THROUGH an out-parameter (struct rec ** = far ptr to a bank-0 stack
 * local).  Staged exits isolate the first broken construct:
 *   2 = chained `fp = *pv = calloc(...)` store/yield
 *   3 = plain read-back of *pv in the callee
 *   4 = realloc through *pv (store of call result via out-param)
 *   5 = copied contents after realloc
 *   6 = write via pointer read back from *pv in main
 * Host clang cross-checks.  Exit 42 when every stage holds. */
#include <stdlib.h>

struct rec { int tag; char *name; int pad[11]; };

int mk(struct rec **pv)
{
    struct rec *fp;

    fp = *pv = (struct rec *)calloc(4, sizeof(struct rec));
    if (fp == 0) return 1;
    fp->tag = 7;                     /* write via the chained-yield local */
    {
        struct rec *t = *pv;         /* read back through the out-param */
        if (t->tag != 7) return 3;   /* ((*pv)->tag is an fcc parse gap) */
    }
    return 0;
}

int grow(struct rec **pv)
{
    *pv = (struct rec *)realloc((char *)*pv, 8 * sizeof(struct rec));
    if (*pv == 0) return 1;
    return 0;
}

int main(void)
{
    struct rec *v;
    int r;

    v = 0;
    r = mk(&v);
    if (r == 1) return 1;
    if (r == 3) return 3;
    if (v == 0 || v->tag != 7) return 2;
    v->name = (char *)&v->tag;       /* known-nonzero far value */
    if (grow(&v)) return 1;
    if (v->tag != 7) return 4;
    if (v->name == 0) return 5;
    {
        struct rec *w = v + 7;       /* (v[7].tag = x is an fcc parse gap) */
        w->tag = 9;
        if (w->tag != 9) return 6;
    }
    free((char *)v);
    return 42;
}
