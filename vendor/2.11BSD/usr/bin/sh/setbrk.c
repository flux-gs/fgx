#ifndef lint
static char sccsid[] = "@(#)setbrk.c	4.2 8/11/83";
#endif

#
/*
 *	UNIX shell
 *
 *	S. R. Bourne
 *	Bell Telephone Laboratories
 *
 */

#include	"defs.h"

/*
 * FGX (apple/fgx#13): two edits, both restoring what the rest of this shell
 * already assumes.  Documented as a vendor exception in src/userland/sh/README.md.
 *
 * 1. `char *sbrk();`.  Undeclared, K&R makes it int-returning, and on FGX a
 *    pointer is a 32-bit bank:offset -- so fcc kept the 16-bit offset and
 *    stamped bank 0 (measured in setbrk.code.s: `LDA #0 / STA 3,S`), throwing
 *    away the bank libc returns in Y.  brkend has been a bank-0 pointer while
 *    the arena lives in the data bank.  Latent rather than fatal today, because
 *    the only uses are `brkend-stakbot` and `brkend-stakbas` and fcc subtracts
 *    offsets -- but any future DEREFERENCE of brkend would read bank 0.
 *    csh/alloc11.c in this same vendored tree declares it exactly this way.
 *
 * 2. Check the result.  Upstream cannot fail here: on a PDP-11 a refused break
 *    is discovered by WRITING past it, and fault.c's MEMF handler then calls
 *    setbrk again and reports `error(nospace)` if that fails too.  FGX has no
 *    write-fault, so MEMF is never delivered and that handler is unreachable
 *    code -- leaving `brkend = a + incr` to compute -1+incr and the shell to
 *    allocate against garbage.  Measured as a HANG, not a crash.
 *
 *    So the contract fault.c:30 already tests -- setbrk returns -1 on failure
 *    -- is honored here, and brkend is left ALONE so the shell's idea of its
 *    arena stays true.  `(INT)a == -1` is alloc11.c's spelling too: compare the
 *    truncated int, never a far pointer against an int constant (fcc #6).
 */
char	*sbrk();

setbrk(incr)
{
	REG BYTPTR	a=sbrk(incr);
	IF (INT)a == -1
	THEN	return(-1);		/* brkend untouched -- see above */
	FI
	brkend=a+incr;
	return(a);
}
