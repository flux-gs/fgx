/* H1: qsort(3) (shellsort in the pile) — int array via cmp fn, then a
 * struct array sorted by a field (the ls port's afile pattern), then a
 * reverse cmp.  cmp signatures are const-void* so the HOST oracle's own
 * qsort prototype accepts them (fcc skips const).  14+14+14 = 42. */
#include <stdlib.h>

struct rec { int key; int tag; };

int icmp(const void *a, const void *b)
{
    return *(const int *)a - *(const int *)b;
}

int rcmp(const void *a, const void *b)
{
    return *(const int *)b - *(const int *)a;
}

int scmp(const void *a, const void *b)
{
    return ((const struct rec *)a)->key - ((const struct rec *)b)->key;
}

int iv[7];
struct rec rv[4];

int main(void)
{
    int r = 0, i, ok;

    iv[0] = 9; iv[1] = 1; iv[2] = 8; iv[3] = 0;
    iv[4] = 5; iv[5] = 3; iv[6] = 7;
    qsort(iv, 7, sizeof(int), icmp);
    ok = 1;
    for (i = 1; i < 7; i++)
        if (iv[i - 1] > iv[i]) ok = 0;
    if (ok && iv[0] == 0 && iv[6] == 9) r += 14;

    rv[0].key = 3; rv[0].tag = 30;
    rv[1].key = 1; rv[1].tag = 10;
    rv[2].key = 2; rv[2].tag = 20;
    rv[3].key = 0; rv[3].tag = 0;
    qsort(rv, 4, sizeof(struct rec), scmp);
    if (rv[0].tag == 0 && rv[1].tag == 10 &&
        rv[2].tag == 20 && rv[3].tag == 30) r += 14;

    qsort(iv, 7, sizeof(int), rcmp);
    if (iv[0] == 9 && iv[6] == 0) r += 14;

    return r;
}
