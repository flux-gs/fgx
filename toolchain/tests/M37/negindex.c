/* negindex.c -- a NEGATIVE subscript on a pointer.  apple/fgx#190.
 *
 * `q = &a[1]; q[-1]' read the wrong element, silently.  `*(q - 1)' -- the same
 * thing by definition -- was correct, and K&R A.7.3.1 leaves no room for the
 * two to differ:
 *
 *   "E1[E2] is identical (by definition) to *((E1)+(E2))"
 *
 * with A.7.7 converting the integer "by multiplying it by the size of the
 * object to which the pointer points".  Neither paragraph makes the sign
 * special, so the two spellings must agree for a negative index exactly as
 * they do for a positive one.
 *
 * WHY IT WENT WRONG, because the shape decides what this file has to cover.
 * A pointer local promoted into a direct-page IMG pair deref'd via
 * `LDA [_fcc_img{k}],Y' with the scaled index in Y.  The 65816 adds Y to the
 * 24-bit base as an UNSIGNED 16-bit displacement WITH CARRY INTO THE BANK, so
 * a scaled index of -2 arrives as $FFFE and the effective address is
 * base + 65534: the RIGHT OFFSET IN THE NEXT BANK UP.  The value read is
 * therefore plausible -- correctly aligned, correctly sized, from live memory
 * -- and simply belongs to something else.
 *
 * That is why every case here checks a VALUE and why the array is seeded with
 * a per-element pattern.  A test that only checked "it compiled", or that read
 * a zeroed array, would have passed throughout.
 *
 * THREE SPELLINGS OF THE SAME ACCESS, and the bug moved only one of them:
 *   q[-1]       was broken   (promoted read, [img],Y)
 *   *(q - 1)    was correct  (folds into the pointer)
 *   q[-1] = v   was correct  (the store twin folds too)
 * so a fix verified on the store, or on the pointer-arithmetic spelling, would
 * have been verified on the two arms that never failed.  All three are here.
 *
 * The controls (positive indices) are not padding: the fix changes the emitted
 * sequence for EVERY promoted indexed read, so this file has to show that the
 * ordinary case still works, not only that the negative one started to.
 *
 * ONE CASE NUMBER PER ARM, first failure wins, as every other fixture here
 * does.  The first cut accumulated a bit MASK instead, on the reasoning that a
 * cumulative diagnostic beats one finding per run -- but that argument is for a
 * ten-minute on-target probe, not a forty-second fixture, and the mask had to
 * be truncated to a byte to survive the exit code, which silently discarded the
 * five highest arms.  A report that cannot name half its cases is worse than
 * one that names them one at a time.
 */

static int  ai[6];
static char ac[6];

int main()
{
    int  *qi;
    char *qc;
    int   k, i;

    for (i = 0; i < 6; i++) {
        ai[i] = 0x100 + i;
        ac[i] = (char)(0x10 + i);
    }

    qi = &ai[2];                            /* mid-array, so either direction
                                             * stays inside the object */

    /* --- 50: the defect -- a CONSTANT negative index ------------------ */
    if (qi[-1] != 0x101) return (50);
    if (qi[-2] != 0x100) return (51);

    /* --- 52: a VARIABLE negative index, which no constant-folding fix
     * would reach ------------------------------------------------------ */
    k = -1;
    if (qi[k] != 0x101) return (52);

    /* --- 53: controls -- the positive cases the fix must not disturb -- */
    k = 1;
    if (qi[k] != 0x103) return (53);
    if (qi[1] != 0x103) return (54);
    if (qi[0] != 0x102) return (55);

    /* --- 56: the spelling that was always correct, kept so a regression
     * in THIS arm is not mistaken for the defect coming back ----------- */
    if (*(qi - 1) != 0x101) return (56);
    if (*(qi + 1) != 0x103) return (57);

    /* --- 58: the STORE twin, also always correct.  It writes THROUGH the
     * negative index and both neighbours are checked, so a store that
     * landed one element out is caught rather than assumed. ------------ */
    qi[-1] = 0x777;
    if (ai[1] != 0x777) return (58);
    if (ai[0] != 0x100) return (59);
    if (ai[2] != 0x102) return (60);
    ai[1] = 0x101;

    /* --- 61: a 1-byte element, where the scale is 1 and the index
     * reaches Y unshifted -- a fix that only corrected the shifted form
     * passes everything above and fails here --------------------------- */
    qc = &ac[2];
    if (qc[-1] != (char)0x11) return (61);
    if (qc[1] != (char)0x13) return (62);

    return (42);
}
