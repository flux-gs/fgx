/* heapcap - how much heap can ONE process get, from a clean start?
 *
 * mallocmax answers a different question: it runs its size and realloc probes
 * FIRST and never frees, so its sweep reports what is LEFT, not the ceiling.
 * That is what made #11 look like a 19,712-byte heap when the real per-process
 * figure is a whole private sbrk bank.  This does nothing but the sweep.
 *
 * It also probes the MID BAND first, from a clean heap: payloads between
 * 32762 and the $F000 big-block threshold once failed outright -- too big for
 * malloc's signed-sbrk guard, too small for the MM path -- so a size that
 * worked either side of it returned NULL.  A hole in the middle of a size range
 * is the kind of thing a sweep never notices.
 *
 * Output: "HEAPMID <size> <ok|FAIL>" then "HEAPCAP chunks=<n> bytes=<total>".
 */
#include <stdio.h>
#include <stdlib.h>

#define CHUNK   256
#define MAXN    4096            /* 1 MB probe ceiling */

main(argc, argv)
    int argc;
    char **argv;
{
    char *p;
    long  total;
    int   n;

    /* Mid band, one size at a time, each freed before the next.  40000 sits in
     * the old hole; 32768 is its lower edge.  LARGEST FIRST, deliberately: free
     * returns a block to the list but does not un-sbrk it, so probing 32768
     * first leaves a 32 KB free block that 40000 cannot use and then needs a
     * second 40 KB of break -- 72 KB against a 64 KB bank, a false FAIL that
     * says nothing about the size band being tested. */
    p = (char *)malloc(40000L);
    printf("HEAPMID 40000 %s\n", p ? "ok" : "FAIL");
    if (p) free(p);
    p = (char *)malloc(32768L);
    printf("HEAPMID 32768 %s\n", p ? "ok" : "FAIL");
    if (p) free(p);

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
    printf("HEAPCAP chunks=%d bytes=%ld\n", n, total);

    /* The floor lives HERE, not in the manifest, because the exact number moves
     * with the heap's start offset and the block header -- an exact match would
     * go red on changes that are not regressions.  What must not happen is the
     * heap losing an ORDER OF MAGNITUDE, which is what #11 was: the private
     * sbrk bank is ~64 KB, and anything that drops the usable figure to a data
     * segment's tail (~20 KB) or below is the regression this is here to catch.
     */
    if (total < 49152L) {
        printf("HEAPCAP FAIL: floor 49152\n");
        return 1;
    }
    printf("HEAPCAP OK\n");
    return 0;
}
