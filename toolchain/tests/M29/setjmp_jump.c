/* setjmp_jump.c — fcc setjmp/longjmp builtin (userland-abi.md §3.6).
 *
 * Exercises the builtin in every context that matters:
 *   - assignment context        r = setjmp(env)
 *   - if-condition context       if (setjmp(env) == 0)
 *   - switch context             switch (setjmp(env))
 *   - the double return          0 on the direct call, val on resume
 *   - longjmp from a DEEPER call frame (env.sp / RTL synthesis must be
 *     frame-correct, not a same-frame goto)
 *   - the C rule that longjmp(env, 0) makes setjmp return 1
 *
 * Returns 42 iff every check holds.  Cross-checked on the host with the real
 * <setjmp.h>: clang returns 42 too, so the oracle reflects C semantics rather
 * than whatever fcc happens to emit (the C-reference discipline).
 *
 * jmp_buf MUST be a global/static — fcc passes its data-bank address in X
 * (see the builtin in toolchain/src/cc/parse_expr.c).
 */
/* <setjmp.h> under BOTH compilers.  This used to re-declare jmp_buf inline for
 * __FGX__, which meant the fixture never saw the toolchain header -- so when
 * the buffer grew 10 -> 12 bytes (bank-0 stack campaign 1.1) the golden stayed
 * byte-identical and reported PASS while libc's setjmp wrote two bytes past
 * `env` into the global the linker placed after it.  A fixture that cannot see
 * the ABI it exercises is not testing it. */
#include <setjmp.h>

jmp_buf env;
int marker;

/* longjmp from a nested frame. */
void jump_from_deep(int v)
{
    marker = marker + v;
    longjmp(env, v + 1);        /* statement-context longjmp */
}

int main(void)
{
    int r;

    /* 1. assignment context + double return + nested-frame longjmp. */
    marker = 0;
    r = setjmp(env);
    if (r == 0) {
        jump_from_deep(40);     /* longjmp(env, 41); never returns here */
        return 1;               /* unreachable */
    }
    if (r != 41)      return 2; /* resume value carried through */
    if (marker != 40) return 3; /* deep frame ran exactly once */

    /* 2. if-condition context + the longjmp(env, 0) -> setjmp returns 1 rule. */
    r = setjmp(env);
    if (r == 0) {
        longjmp(env, 0);        /* C: setjmp must then return 1, not 0 */
        return 4;               /* unreachable */
    }
    if (r != 1) return 5;

    /* 3. switch context. */
    switch (setjmp(env)) {
    case 0:
        longjmp(env, 7);
        return 6;               /* unreachable */
    case 7:
        return 42;              /* success */
    default:
        return 7;
    }
}
