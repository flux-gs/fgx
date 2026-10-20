/* M35/P3-3: two far slot operands in ONE expression — the `_fcc_fp` single-DP-
 * temp collision hazard.  A far (>255 B offset) slot access builds its bank-0
 * address in _fcc_fp; if an expression held two such addresses live at once,
 * the second build would clobber the first before it was consumed.
 *
 * The operands MUST be struct FIELDS, not scalars: a scalar like `int hi`
 * register-promotes to a DP image and never touches the frame, so a scalar
 * version is vacuous (0 far accesses).  Struct fields never promote, so
 * `s.a`/`s.b`/`s.c` at byte offsets 522/524/526 (pushed past 255 by pad[520])
 * are genuine far _fcc_fp accesses.  This exercises far reads/stores under
 * expression pressure and proves the emit structure builds-and-consumes
 * _fcc_fp atomically (no two addresses live simultaneously).
 *
 * Its 528 B frame needs the 3.2 FGX2 stack-size field (a >256 B frame overruns
 * the default 1-page HW stack) and the 3.1b n,S far-fallback.
 *
 * Portable C: clang returns 42. */
struct big {
    int  lo;            /* byte 0   — near control */
    char pad[520];
    int  a;             /* byte 522 — far */
    int  b;             /* byte 524 — far */
    int  c;             /* byte 526 — far */
};

int
main(void)
{
    struct big s;
    int i;

    s.lo = 0;
    for (i = 0; i < 520; i++)
        s.pad[i] = 0;

    s.a = 100;
    s.b = 200;

    s.c = s.a + s.b;                 /* two far field reads, one expr */
    if (s.c != 300)  return 1;

    s.c = s.a * 2 + s.b * 3;         /* far reads interleaved with temps */
    if (s.c != 800)  return 2;

    s.a = s.b = s.c;                 /* chained far field store */
    if (s.a != 800 || s.b != 800) return 3;

    if (s.lo != 0 || s.pad[0] != 0 || s.pad[519] != 0) return 4;
    return 42;
}
