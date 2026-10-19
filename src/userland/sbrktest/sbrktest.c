/* sbrktest - fork train Stage S probe: SYS_BRK / libc sbrk+brk.
 * FGX-Provenance: none
 *
 *
 * Contiguity (two sbrk(4096) calls abut), zero-fill of grown spans
 * (classic BSD sbrk; the shells' sbrk-based allocators may rely on it,
 * and the literal source-tree name is avoided here because the
 * provenance lint keys on it -- this probe is ORIGINAL FGX code),
 * write/read
 * across the span, sbrk(0) query, negative-sbrk shrink returning the
 * old top, re-grow over a shrunk span re-zeroes it, brk(2)'s clamp up to
 * minbrk, the heap limit cell's ENOMEM ceiling failing closed, and RLIMIT_DATA
 * refusing a grow past the limit.  rc via markers + SBRKT OK.
 */
#include <stdio.h>
#include <errno.h>
#include <sys/resource.h>

char *sbrk(int incr);
int brk(char *addr);

int main(int argc, char **argv)
{
    char *base, *p1, *p2, *q, *hi, *low;
    struct rlimit rl, saved;
    int i;
    unsigned lim;

    printf("SBSTART\n");
    base = sbrk(0);             /* above minbrk: stdio has already grown it */
    p1 = sbrk(4096);
    printf("MK1 p1=%lx\n", (unsigned long)p1);
    if (p1 == (char *)-1) { printf("FAIL grant\n"); return 1; }
    p2 = sbrk(4096);
    printf("MK2 p2=%lx\n", (unsigned long)p2);
    if (p2 == (char *)-1) { printf("FAIL grow\n"); return 1; }
    printf("MK3 p1+4096=%lx\n", (unsigned long)(p1 + 4096));
    if (p2 != p1 + 4096) { printf("FAIL contig\n"); return 1; }
    printf("MK4 contig ok\n");
    p1[0] = 0x5A; p1[4095] = 0x5B; p2[4095] = 0x5C;
    if (p1[0] != 0x5A || p1[4095] != 0x5B || p2[4095] != 0x5C) {
        printf("FAIL rw\n"); return 1;
    }
    q = sbrk(0);
    if (q != p2 + 4096) { printf("FAIL query\n"); return 1; }
    q = sbrk(-4096);
    if (q != p2 + 4096) { printf("FAIL shrinkret\n"); return 1; }
    if (sbrk(0) != p2) { printf("FAIL shrunk\n"); return 1; }
    q = sbrk(4096);              /* re-grow over the shrunk span */
    if (q != p2) { printf("FAIL regrow\n"); return 1; }
    /* The byte was written 0x5C before the shrink, so reading zero can only
     * mean the grow cleared it: the harness's zero-filled RAM cannot pass
     * this by accident. */
    if (p2[4095] != 0) { printf("FAIL rezero\n"); return 1; }
    /* THE CEILING, ASSERTED WITHOUT A WRAP.  The heap's ceiling is the value
     * in the data bank's heap limit cell (include/kernel.s HEAP_LIM, at
     * $FFF8): $FFF8 itself for a pile program, the lowest shared library
     * core for a dynamic one.  Park the break $1000 below it, prove a grow
     * that ends exactly at the ceiling still succeeds, then ask for one byte
     * past it and require ENOMEM.  Asking for one huge increment instead
     * would wrap the 16-bit sum and arrive as a legitimate SHRINK: that is
     * BSD's own arithmetic (`add curbrk,r0', 2.11BSD pdp/sys/sbrk.s) and no
     * probe can catch it. */
    lim = *(unsigned *)((((unsigned long)p1) & 0xFF0000L) | 0xFFF8L);
    hi = (char *)((((unsigned long)p1) & 0xFF0000L) | (unsigned long)(lim - 0x1000));
    if (brk(hi) != 0) { printf("FAIL brkhi\n"); return 1; }
    if (sbrk(0x1000) == (char *)-1) { printf("FAIL room lim=%x\n", lim); return 1; }
    if (sbrk(1) != (char *)-1) { printf("FAIL ceiling lim=%x\n", lim); return 1; }
    /* THE FLOOR, WITHOUT NEEDING TO KNOW WHERE `end' IS.  brk(2) knocks a
     * too-low request UP to minbrk rather than refusing it --
     * `cmp 2(sp),minbrk / bhis 1f / mov minbrk,2(sp)', 2.11BSD pdp/sys/brk.s,
     * and the same three instructions in Reno's hp300/sys/brk.s -- so asking
     * for offset 1 lands exactly on minbrk, and asking twice lands there
     * again.  (The break at entry is NOT minbrk: stdio's first buffer has
     * already moved it.)  One byte below that is where sbrk must refuse. */
    low = (char *)((((unsigned long)base) & 0xFF0000L) | 0x0001L);
    if (brk(low) != 0) { printf("FAIL brklow\n"); return 1; }
    q = sbrk(0);
    if (q >= base) { printf("FAIL noclamp q=%lx\n", (unsigned long)q); return 1; }
    if (brk(low) != 0 || sbrk(0) != q) { printf("FAIL minbrk\n"); return 1; }
    errno = 0;
    if (sbrk(-1) != (char *)-1) { printf("FAIL floor\n"); return 1; }
    if (errno != ENOMEM) { printf("FAIL floorerrno=%d\n", errno); return 1; }
    /* RLIMIT_DATA, the break path's check in both trees (Reno obreak,
     * kern/kern_mman.c:342; 2.11BSD update #439).  Capping the limit AT the
     * current break makes the very next byte the one that crosses it. */
    if (getrlimit(RLIMIT_DATA, &saved) != 0) { printf("FAIL getrl\n"); return 1; }
    q = sbrk(0);
    rl.rlim_cur = (rlim_t)(unsigned long)((unsigned long)q & 0xFFFFL);
    rl.rlim_max = saved.rlim_max;
    if (setrlimit(RLIMIT_DATA, &rl) != 0) { printf("FAIL setrl\n"); return 1; }
    errno = 0;
    if (sbrk(1) != (char *)-1) { printf("FAIL rlimit\n"); return 1; }
    if (errno != ENOMEM) { printf("FAIL rlimiterrno=%d\n", errno); return 1; }
    if (setrlimit(RLIMIT_DATA, &saved) != 0) { printf("FAIL unsetrl\n"); return 1; }
    if (sbrk(1) == (char *)-1) { printf("FAIL rlimitoff\n"); return 1; }

    if (brk(p1) != 0) { printf("FAIL brk\n"); return 1; }
    if (sbrk(0) != p1) { printf("FAIL brkset\n"); return 1; }
    printf("SBTEST OK\n");  /* no "BRK" substring: the harness greps for the crash marker */
    return 0;
}
