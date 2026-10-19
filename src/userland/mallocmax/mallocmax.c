/* mallocmax - how much heap can ONE process actually get?
 *
 * Written 2026-07-26 because tcsh dies at startup with its own "Out of memory."
 * (libc malloc returning NULL) and nothing anywhere reports the budget.  malloc
 * on FGX is SYS_MALLOC32 (#96) against the KERNEL heap -- not a per-process
 * sbrk arena -- so the interesting number is how much a single task can obtain
 * before the kernel says no, and in how many chunks.
 *
 * Deliberately does NOT free: the question is the ceiling, not churn behaviour.
 * Chunk size is a parameter because the byte-grain arenas and the >=$F000
 * dedicated-MM-block path are different allocators, and tcsh's startup is many
 * SMALL allocations -- so small-chunk capacity is the number that matters here.
 */
#include <stdio.h>
#include <stdlib.h>   /* malloc: MUST be prototyped -- an implicit decl
                         * returns int and truncates the far pointer's BANK */

#define CHUNK   256
#define MAXN    2048            /* 2048 * 256 = 512 KB ceiling on the probe */

main(argc, argv)
    int argc;
    char **argv;
{
    char *p;
    long  total;
    int   n;
    unsigned long sz;

    /* --- 2. single-allocation ceiling, straddling the $F000 threshold ---
     * malloc routes >= $F000 to a dedicated MM block (_Kmalloc_Big) and below
     * it to the byte-grain arenas, so the two sides are different allocators
     * and must be probed separately. */
    sz = 1024L;
    while (sz <= 262144L) {
        p = (char *)malloc(sz);
        /* Print the RAW pointer, do not just test it.  A dedicated big block
         * comes back at bank:0000 -- offset zero by design -- so `p ? ..` is
         * only meaningful if the compiler tests all 32 bits.  If the alloc
         * succeeded, the bank byte here is non-zero even when the offset is 0. */
        printf("MSZ %ld ptr=%08lx\n", sz, (unsigned long)p);
        sz = sz * 2;
    }
    p = (char *)malloc(61439L);         /* $EFFF: last arena-grain size */
    printf("MSZ 61439 ptr=%08lx\n", (unsigned long)p);
    p = (char *)malloc(61440L);         /* $F000: first big-block size */
    printf("MSZ 61440 ptr=%08lx\n", (unsigned long)p);

    /* --- 3. the documented realloc limit -------------------------------
     * stdlib.h states realloc sizes >= $F000 return NULL ("no big-block
     * realloc yet -- the kernel copy path can't see the old block's length").
     * Grow one block across that boundary and report exactly where it stops. */
    p = (char *)malloc(1024L);
    sz = 1024L;
    while (p != (char *)0 && sz <= 131072L) {
        sz = sz * 2;
        p = (char *)realloc(p, sz);
        printf("RSZ %ld %s\n", sz, p ? "ok" : "FAIL");
    }
    /* --- 3. capacity sweep LAST: it never frees, so running it first exhausted
     * the heap and made every size probe above report a false FAIL. ------ */
    total = 0;
    n = 0;
    while (n < MAXN) {
        p = (char *)malloc((unsigned long)CHUNK);
        if (p == (char *)0)
            break;
        p[0] = 1;                       /* touch it: a returned-but-unusable
                                           pointer is worse than a NULL */
        p[CHUNK - 1] = 1;
        total = total + CHUNK;
        n++;
    }
    printf("MMAX chunks=%d bytes=%ld\n", n, total);

    printf("MMDONE2\n");
    return 0;
}
