/* T5-C C4 batch 7: kernel heap in C — malloc/free/realloc.
 *
 * The heap returns OWN-BANK pointers (outside DBR), so every string op
 * here is a genuine cross-bank exercise through the C str* conversions;
 * realloc must preserve contents across a probable move.  realloc's
 * prototype was ADDED to stdlib.h with this batch — without it the
 * pointer checks would run int-truncated (the campaign's recurring
 * missing-prototype trap).
 *
 * FGX-only (MAME oracle).  8+8+8+9+9 = 42. */
#include <stdlib.h>
#include <string.h>

int main(void)
{
    char *p, *q;
    int r = 0;

    p = (char *)malloc(64);
    if (p != 0)                  r += 8;
    strcpy(p, "hello");                    /* literal -> heap bank */
    if (strcmp(p, "hello") == 0) r += 8;
    q = (char *)realloc(p, 4096);          /* grow; likely moves */
    if (q != 0)                  r += 8;
    if (strcmp(q, "hello") == 0) r += 9;   /* contents preserved */
    free(q);
    if (malloc(30000) != 0)      r += 9;   /* big alloc after free */
    return r;
}
