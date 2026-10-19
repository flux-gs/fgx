/* jmpbuf_width.c - does libc's setjmp fit inside the jmp_buf the header
 * declares?
 *
 * Nothing tested this, and the gap was invisible in both directions.  When the
 * buffer grew 10 -> 12 bytes (bank-0 stack campaign 1.1), the two existing
 * setjmp fixtures carried a PRIVATE `char _jb[10]` typedef instead of including
 * <setjmp.h>, so they never saw the change: 546 goldens reported byte-identical
 * and the runtime oracle reported 2/2 pass while libc's setjmp wrote two bytes
 * past `env`.  Fixing the typedef made the goldens move, and the runtime STILL
 * passed -- setjmp_jump's `marker` is reset after the setjmp calls, so an
 * overrun into it is overwritten before anything looks.
 *
 * So: a guard word declared immediately after the buffer, given a value BEFORE
 * setjmp and checked after both the direct call and the longjmp resume.  A
 * buffer one word too small puts setjmp's last store exactly on top of it.
 *
 * This depends on fcc emitting globals into the data segment in DECLARATION
 * order, which it does and which the .expected.data.s golden pins -- if that
 * ever changes, this fixture stops being a width test and the golden diff is
 * where it shows.
 *
 * Returns 42 iff the guard survives.  clang returns 42 (its jmp_buf is its own
 * business; the guard is simply never touched).
 */
#include <setjmp.h>

jmp_buf env;
int guard;                      /* MUST stay immediately after env */

int
main(argc, argv)
	int	argc;
	char	**argv;
{
	guard = 0x5A5A;

	if (setjmp(env) == 0) {
		if (guard != 0x5A5A)
			return 1;       /* setjmp stored past the buffer */
		longjmp(env, 7);
		return 2;               /* unreachable */
	}

	if (guard != 0x5A5A)
		return 3;               /* longjmp stored past the buffer */
	return 42;
}
