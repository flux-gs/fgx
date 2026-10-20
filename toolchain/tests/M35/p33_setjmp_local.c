/* M35/P3-3: a local written BEFORE setjmp must survive a longjmp from a
 * DEEPER frame.  The deep frame shifts the frame pointer; on resume the
 * setjmp-caller must address `before` through the RESTORED frame pointer,
 * not the abandoned deep one.  `&before` forces it to the frame (not a
 * register/DP-IMG promotion).  jmp_buf must be global (fcc rule).
 *
 * Portable C: clang returns 42.  Expected RED under the current soft stack
 * (longjmp does not restore _fcc_ssp) — 3.1a's jmp_buf _fcc_ssp save/restore
 * turns it green.
 *
 * 3.3 review case (rc 5/6): re-form &before AFTER the resume.  The pre-formed
 * bp is fb-insensitive (a stored absolute address) and the direct reads are
 * n,S (S-restore-sensitive only), so a fresh post-longjmp &local is the ONLY
 * shape that consumes the longjmp-restored frame base at jmp_buf+2 — without
 * it that restore has no runtime net. */
/* <setjmp.h> under BOTH compilers.  This used to re-declare jmp_buf inline for
 * __FGX__, which meant the fixture never saw the toolchain header -- so when
 * the buffer grew 10 -> 12 bytes (bank-0 stack campaign 1.1) the golden stayed
 * byte-identical and reported PASS while libc's setjmp wrote two bytes past
 * `env` into the global the linker placed after it.  A fixture that cannot see
 * the ABI it exercises is not testing it. */
#include <setjmp.h>

jmp_buf env;
int marker;

void
deep(void)
{
    int junk[8];
    int i;
    for (i = 0; i < 8; i++)
        junk[i] = i;
    marker += junk[3];          /* keep junk live; shifts the frame pointer */
    longjmp(env, 1);
}

int
main(void)
{
    int before;
    int *bp = &before;          /* &local → forced onto the frame */
    int *bp2;
    int r;

    before = 314;
    r = setjmp(env);
    if (r == 0)
        deep();                 /* never returns; longjmps back to here */

    if (before != 314) return 1;   /* direct frame read (n,S): tests S restore */
    if (*bp != 314)    return 2;    /* deref &local through a pointer */
    if (r != 1)        return 3;
    if (marker != 3)   return 4;

    bp2 = &before;                 /* re-formed post-resume: consumes restored fb */
    if (bp2 != bp)     return 5;
    if (*bp2 != 314)   return 6;
    return 42;
}
