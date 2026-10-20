/* M35/P3-3 3.1b (family b): a struct field PAST the 255 B n,S window forces
 * emit_field_lda / emit_field_sta onto the far (_fcc_fp) slot-address path.
 * Unlike a scalar, a struct field never register-promotes, so it always hits
 * memory — this is the fail-loud gate for the far field arm.  `hi` and `hi2`
 * sit at byte offsets 258/260 (> 255); `lo` at 0 is the near control.  The
 * three sentinels differ, so a far access that mis-addresses by a word (or
 * loses the bank) reads a neighbour and exits non-42.
 *
 * Portable C: clang returns 42 too. */
struct big {
    int  lo;            /* byte 0    — near n,S */
    char pad[256];
    int  hi;            /* byte 258  — far _fcc_fp */
    int  hi2;           /* byte 260  — far _fcc_fp, adjacent to hi */
};

int
main(void)
{
    struct big s;

    s.lo  = 0x11;
    s.hi  = 0x22;       /* emit_field_sta far */
    s.hi2 = 0x33;
    s.pad[0]   = 7;     /* keep pad live so the struct isn't elided */
    s.pad[255] = 9;

    if (s.lo  != 0x11)  return 1;   /* near control */
    if (s.hi  != 0x22)  return 2;   /* emit_field_lda far */
    if (s.hi2 != 0x33)  return 3;   /* far, would read hi's neighbour if biased */
    if (s.pad[0]   != 7) return 4;
    if (s.pad[255] != 9) return 5;
    return 42;
}
