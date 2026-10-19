/* heapkill - sbrk(2) refuses CHECKABLY, and a program may choose to die of it.
 *
 * FGX-Provenance: none
 *
 * Two things in one probe, because they are the two halves of the same
 * contract and a suite that proves only one looks exactly like a suite that
 * proves both:
 *
 *   1. sbrk() RETURNS (char *)-1 when the kernel refuses a grow, and the caller
 *      is still alive to see it.  It briefly did not -- it _exit(136)ed instead,
 *      on the theory that 2.11BSD's unchecked `brkend = sbrk(incr) + incr` could
 *      not be taught to check.  It could: fault.c:30 already carried the check,
 *      FGX simply could not deliver the write-fault that reaches it, so #13
 *      moved the same test to the call site that IS reachable and put POSIX
 *      sbrk back.  HKRET proves the return happened at all; HKERR proves it was
 *      a refusal rather than some other -1.
 *
 *   2. TASK_EXIT_HEAPFULL (136) still names that death for a program that WANTS
 *      it -- the kernel logs `heap exhausted: killed pid $NN`.  libc no longer
 *      chooses it on anyone's behalf, so this probe opts in explicitly, which
 *      doubles as the worked example of how to.  Without this half the kernel's
 *      whole reporting path would have no setter and would quietly rot.
 *
 * sbrktest covers the ordinary contract (contiguity, shrink, the ENOMEM
 * ceiling); srcexhaust covers what the shell now does with a refusal.
 */
#include <stdio.h>
#include <errno.h>

char *sbrk(int incr);
int brk(char *addr);
void _exit(int code);

int
main()
{
    char *p;

    printf("HKSTART\n");

    /* REACH THE CEILING WITHOUT WRAPPING THE 16-BIT SUM.  sbrk's increment is
     * an addend that libc adds to the break before the kernel validates the
     * sum -- `add curbrk,r0', 2.11BSD pdp/sys/sbrk.s -- so walking up in big
     * steps does not converge on a refusal: the first step past $FFFF lands
     * LOW and is a legitimate shrink.  Upstream cannot tell those apart either
     * (update #58 is that bug costing a program its .bss), so the probe parks
     * the break just under the top instead and asks for a grow that lands at
     * $FFFF, past HEAP_LIM ($FFF8).  No wrap is involved and the refusal is
     * the ceiling's. */
    p = sbrk(0);
    if (brk((char *)((((unsigned long)p) & 0xFF0000L) | 0xF000L)) != 0) {
        printf("HKNOPARK\n");           /* could not reach the top of the bank:
                                         * every assertion below would be
                                         * vacuous */
        return 1;
    }
    p = sbrk(0x0FFF);

    if (p != (char *)-1) {
        printf("HKNOCEIL\n");           /* a grow to $FFFF was ALLOWED: the
                                         * ceiling moved, and every assertion
                                         * below would be vacuous */
        return 1;
    }

    printf("HKRET\n");                  /* it came BACK -- the whole point */
    if (errno != ENOMEM) {
        printf("HKERR errno=%d\n", errno);
        return 2;
    }

    /* Opt in to the fatal policy, the way a program that cannot cope should. */
    _exit(136);                         /* TASK_EXIT_HEAPFULL (include/loader.s) */
    printf("HKALIVE\n");                /* _exit returned: impossible */
    return 3;
}
