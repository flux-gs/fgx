/* T5-C C4 batch 5: misc wrappers + the first PURE-C conversions.
 *
 * atoi/atol are plain C (atoi -> atol is the intra-pile C-to-C call
 * pin: it rides the zero-reloc PHK/RTL trampoline — a near JSR into a
 * JSL-shaped entry hung exactly here); getenv is a plain C walk of
 * args_env (negative path here — run_runtime chunks carry NO env, so
 * the positive path is envtest's job in the FGX fast group);
 * waitpid(-1,WNOHANG) with no children at all is ECHILD -1 (the 0
 * return is children-but-none-reaped); ticks sampled around a syscall.
 *
 * atoi/atol clang-semantics; the rest FGX-only (MAME oracle).
 * (Second missing-prototype lesson this campaign: without <stdlib.h>
 * fcc defaults atol to int-return and the long compare is truncated —
 * m5-probe bisection chased a phantom codegen bug for a while.)
 * 6*7 = 42. */
#include <stdlib.h>
#include <string.h>

int main(void)
{
    char fsbuf[128];
    int st, t1, t2, r = 0;

    if (atoi(" -42") == -42)              r += 6;
    if (atol("100000") == 100000L)        r += 6;
    if (getenv("NOPEVAR") == 0)           r += 6;
    if (kill(30000, 9) == -1)             r += 6;   /* ESRCH pid */
    if (waitpid(-1, &st, 1) == -1)        r += 6;   /* ECHILD: no children */
    t1 = ticks();
    if (getfsstat(fsbuf, 128, 0) >= 1)    r += 6;   /* boot volume */
    t2 = ticks();
    if (t2 - t1 >= 0)                     r += 6;
    return r;
}
