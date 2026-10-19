/* M35/P3-3 (3.1b review): scalar locals past byte 255 under REGISTER
 * PROMOTION.  This is the ORIGINAL p33_fcc_fp_dbl body, preserved when that
 * fixture was rewritten to struct fields: it turned out VACUOUS as a far-path
 * test — hi1/hi2/hi3 register-promote to DP images (_fcc_img) and never touch
 * the frame (0 far accesses).  That vacuity is exactly why it stays in the
 * suite under this name: it pins the promoted-scalar round-trip behaviour
 * (loads/stores/chained assignment through _fcc_img) for hot scalars whose
 * frame slots sit past the 255-byte n,S window, plus the pad[] far byte-fill.
 * The far _fcc_fp expression-pressure test lives in p33_fcc_fp_dbl (struct
 * fields, which never promote).
 *
 * Its 528-byte frame needs the 3.2 FGX2 stack-size field.
 *
 * Portable C: clang returns 42. */
int
main(void)
{
    char pad[520];
    int  hi1, hi2, hi3;     /* offsets ~520-526, all > 255 */
    int  i;

    for (i = 0; i < 520; i++)
        pad[i] = 0;
    hi1 = 100;
    hi2 = 200;

    hi3 = hi1 + hi2;                 /* two reads, one expr */
    if (hi3 != 300)  return 1;

    hi3 = hi1 * 2 + hi2 * 3;         /* reads interleaved with temps */
    if (hi3 != 800)  return 2;

    hi1 = hi2 = hi3;                 /* chained store */
    if (hi1 != 800 || hi2 != 800) return 3;

    /* keep pad live so it isn't optimized away */
    if (pad[0] != 0 || pad[519] != 0) return 4;

    return 42;
}
