/* M35/P3-3: deep frame — a local whose SLOT offset exceeds 255.
 *
 * Under the soft stack (today) locals are [_fcc_ssp],Y with a 16-bit Y, so
 * there is no 255 boundary; this passes now.  After the P3-3 flip, `after`
 * lives on the hardware stack at an n,S offset > 255 and must take the
 * `_fcc_fp` far fallback (G53).  A `char big[260]` first pushes every later
 * local past the 8-bit displacement.  Also probes big[] elements at
 * offsets 255/256/259 (the far-gate boundary).
 *
 * Portable C: clang returns 42 too. */
int
main(void)
{
    char big[260];
    int  after;          /* slot lands past offset 255 */
    int  i;

    for (i = 0; i < 260; i++)
        big[i] = (char)(i & 0x7f);
    after = 12345;

    if (big[0]   != 0)             return 1;
    if (big[255] != (char)(255 & 0x7f)) return 2;   /* 127 */
    if (big[256] != (char)(256 & 0x7f)) return 3;   /* 0   */
    if (big[259] != (char)(259 & 0x7f)) return 4;   /* 3   */
    if (after != 12345)            return 5;         /* far-slot read/write */

    after = 0;
    for (i = 0; i < 260; i++)
        after += big[i];           /* far-slot accumulate under a loop */
    /* sum of (i&0x7f) for i=0..259 = 2*(0..127) + (0..3) = 2*8128 + 6 = 16262 */
    if (after != 16262)            return 6;

    return 42;
}
