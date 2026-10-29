/* setjmp.h - non-local goto for FGX C programs (faithful BSD-port support).
 *
 * setjmp() / longjmp() are COMPILER BUILTINS in fcc (see userland-abi.md
 * §3.6 and toolchain/src/cc/parse_expr.c): fcc emits the call inline in
 * the caller, passing the jmp_buf's data-bank address in X, to the hand-
 * written asm in src/userland/lib/libc.s.  They are intercepted by name, so
 * no prototypes are declared here (and must not be — a prototype would route
 * them through the ordinary stack-based call path).
 *
 * jmp_buf is a 48-byte buffer matching the asm layout (libc.s):
 *   +0 PB  +1 DBR  +2..3 _fcc_fb  +4..5 PC  +6..7 SP  +8..9 DP
 *   +10..11 _fcc_sfp   (bank-0 stack campaign 1.1)
 *   +12..15 the 32-bit signal mask (apple/fgx#64)
 *   +16..47 the callee-saved direct-page band, _fcc_img16.._fcc_img31
 * It grew 10 -> 12 in 1.1, 12 -> 16 for the mask and 16 -> 48 for the band.
 * If you keep a private copy of this typedef, it WILL be written past:
 * libc's setjmp stores 48 bytes unconditionally.  There
 * was one such copy (src/userland/ed/ed.c) and it now includes this header.
 * It is a struct (not the historical array typedef) because fcc has no array
 * typedefs; a bare jmp_buf identifier still decays to its address, so source
 * written `setjmp(env)` / `longjmp(env, v)` compiles unchanged.
 *
 * IMPORTANT: a jmp_buf MUST have static storage (a file-scope global or a
 * `static` local).  The asm addresses it DBR-relative (the program's data
 * bank), but an automatic (stack) buffer lives in bank $00 — a different bank
 * under single-bank FGX1 (DBR = own bank != $00).  fcc fails closed (a compile
 * error) on a bare stack-local jmp_buf rather than silently corrupting it.
 * This matches real practice: a setjmp buffer must outlive the function that
 * calls setjmp, so it is essentially always a global/static anyway.
 *
 * THE MASK IS PART OF THE CONTRACT, not an implementation detail.  2.11BSD's
 * setjmp.3: "Setjmp and longjmp save and restore the signal mask sigmask(2),
 * while _setjmp and _longjmp manipulate only the C stack and registers."  FGX
 * behaved as _setjmp did until apple/fgx#64, which was harmless until #53 made
 * a delivered signal blocked for its handler's duration (as postsig() does).
 * crt0's trampoline unblocks on NORMAL return, so a handler that longjmps out
 * left its signal blocked forever -- the standard BSD idiom, and why bsh took
 * exactly one ^C.  _setjmp/_longjmp are NOT provided: no port in the tree calls
 * them, and adding them means teaching fcc two more builtin names.
 */
#ifndef _SETJMP_H
#define _SETJMP_H

typedef struct { char _jb[48]; } jmp_buf;

/* setjmp(jmp_buf env)        -> 0 on the direct call, the longjmp value on
 *                               resume.  Usable in any expression context.
 * longjmp(jmp_buf env, int v) -> does not return; setjmp returns v (or 1 if
 *                               v == 0, per the C standard).
 * Both are fcc builtins — intentionally no prototypes. */

#endif /* _SETJMP_H */
