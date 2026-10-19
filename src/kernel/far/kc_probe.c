/* kc_probe.c -- the first C compiled into the FGX kernel.
 *
 * It runs at boot, from main.s _KcProbe, and the smoke gate asserts its
 * verdict.  WHAT THAT PROVES, exactly: the core kernel can switch banks and
 * direct pages, cross into the far bank through export slot 27, run
 * fcc-generated code that calls an fcc runtime helper (_fcc_lts16), and get
 * the right answer back with DBR correct -- if DBR were still the core bank
 * the helper's scratch would be written over kernel code.
 *
 * WHAT IT DOES NOT PROVE, and this was measured rather than assumed: that the
 * direct page is the RIGHT one.  Pointing KC_ENTER at FGX_DP_KKERN instead
 * and rebuilding still returns 42 and still boots.  The reason is structural
 * -- this function writes every DP slot it later reads, so it is self
 * consistent on any page, and the damage of running on the kernel's own page
 * is to the CONSOLE state that shares $C0-$EF, which nothing here asserts.
 * The page choice rests on the overlap between include/dpmap.s and
 * src/kernel/far/fcc_dp.s, which deserves a build-time check of its own.
 *
 * It exists to prove the kernel-C seam end to end on real silicon: the core
 * kernel switches to FGX_DP_KERNELC, calls through a far-bank export slot into
 * fcc-generated code, and gets a correct answer back.  Until something like
 * this runs, KC_ENTER/KC_LEAVE are a contract nothing has tested.
 *
 * It is written to FAIL if the direct page is wrong rather than to look
 * plausible.  A function that only added its two arguments would pass with no
 * direct page at all, because fcc keeps a trivial expression in the
 * accumulator and never touches a DP slot.  So this one:
 *
 *   - takes a local ARRAY, which forces a real stack frame and makes the
 *     prologue seed _fcc_fb ($BB) and the epilogue restore it;
 *   - walks that array through a POINTER, which routes the loads and stores
 *     through _fcc_ptr ($E8) as an indirect-long;
 *   - accumulates across iterations, so a single clobbered slot changes the
 *     answer instead of being masked.
 *
 * If D still pointed at the kernel's own direct page, $E8 there is the console
 * string pointer and $BB is console scratch: the walk would read and write the
 * live console state and return a wrong sum.  The caller checks the value, so
 * that shows up as a failure rather than as a mystery in the display.
 *
 * kc_probe(seed) returns seed*4 + 6 for the array it builds.  The caller
 * passes 9 and expects 42.
 */

/* The C-to-kernel direction of the seam (src/kernel/far/kc_sys.s).  Called
 * below to exercise it; see the comment at the call site. */
extern void kc_wakeup();

int
kc_probe(seed)
int seed;
{
    int  cell[4];
    int *p;
    int  i;
    int  sum;

    p = cell;
    for (i = 0; i < 4; i++)
        p[i] = seed + i;

    /* CROSS THE SEAM OUTWARD, between the two loops rather than after them.
     *
     * This is the only call to a non-runtime function anywhere in kernel C, so
     * it is the only thing that proves three separate mechanisms on silicon:
     * that --pile's PHK/PEA/PHK/PEA/RTL idiom reaches its target at all (the
     * default FGX2_FARCALL would assemble as JSL $00:0000 and hang); that the
     * _cfp site inside kc_sys.s got its bank byte patched; and that the
     * wrappers put D and DBR back.
     *
     * kc_wakeup rather than kc_sleep because a sleep at boot would never be
     * woken -- and the two share their entire prologue and epilogue, which is
     * the part under test.  No task waits on this channel, so the kernel side
     * is a no-op scan of the task table.
     *
     * ITS POSITION IS THE ASSERTION.  The sum is accumulated AFTER the call
     * through the same pointer and frame base the first loop used, so a
     * direct page or data bank that came back wrong corrupts _fcc_ptr or
     * _fcc_fb and the caller's 42 check fails.  Called after the sum, it would
     * prove only that the machine kept running.
     */
    kc_wakeup((char *)p);

    sum = 0;
    for (i = 0; i < 4; i++)
        sum = sum + p[i];

    /* seed*4 + (0+1+2+3) == seed*4 + 6 */
    return sum;
}
