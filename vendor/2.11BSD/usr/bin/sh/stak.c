#ifndef lint
static char sccsid[] = "@(#)stak.c	4.2 8/11/83";
#endif

#
/*
 * UNIX shell
 *
 * S. R. Bourne
 * Bell Telephone Laboratories
 *
 */

#include	"defs.h"

STKPTR		stakbot=nullstr;



/* ========	storage allocation	======== */

STKPTR	getstak(asize)
	INT		asize;
{	/* allocate requested stack */
	REG STKPTR	oldstak;
	REG INT		size;

	size=round(asize,BYTESPERWORD);
	oldstak=stakbot;
	stakneed(oldstak, size);
	staktop = stakbot += size;
	return(oldstak);
}

STKPTR	locstak()
{	/* set up stack for local use
	 * should be followed by `endstak'
	 */
	IF brkend-stakbot<BRKINCR
	THEN	/*
		 * FGX (apple/fgx#13): react to a refused break.  This is not a new
		 * policy -- it is fault.c:30's, verbatim:
		 *
		 *	IF setbrk(brkincr) == -1 THEN error(nospace); FI
		 *
		 * On a PDP-11 that runs from the MEMF (write-fault) signal, which
		 * is how upstream discovers a full arena; FGX has no write-fault,
		 * so MEMF is never delivered and this PROACTIVE call is the only
		 * site that ever learns.  Without the check the shell returns
		 * stakbot without the BRKINCR of headroom it just promised, and
		 * every caller writes past the arena -- a hang, not a crash.
		 *
		 * error() -> failed() -> exitsh(ERROR) is BSD's own answer: an
		 * interactive shell prints `sh: no space` and returns to its
		 * prompt, a script exits non-zero.  Both beat wandering.
		 */
		IF setbrk(brkincr) == -1
		THEN	error(nospace);
		FI
		IF brkincr < BRKMAX
		THEN	brkincr += 256;
		FI
	FI
	return(stakbot);
}

STKPTR	savstak()
{
	assert(staktop==stakbot);
	return(stakbot);
}

STKPTR	endstak(argp)
	REG STRING	argp;
{	/* tidy up after `locstak' */
	REG STKPTR	oldstak;
	*argp++=0;
	oldstak=stakbot; stakbot=staktop=round(argp,BYTESPERWORD);
	return(oldstak);
}

VOID	tdystak(x)
	REG STKPTR 	x;
{
	/* try to bring stack back to x */
	WHILE ADR(stakbsy)>ADR(x)
	DO free(stakbsy);
	   stakbsy = stakbsy->word;
	OD
	staktop=stakbot=max(ADR(x),ADR(stakbas));
	rmtemp(x);
}

stakchk()
{
	IF (brkend-stakbas)>BRKINCR+BRKINCR
	THEN	setbrk(-BRKINCR);
	FI
}

STKPTR	cpystak(x)
	STKPTR		x;
{
	REG STKPTR	p = locstak();

	stakneed(p, length(x));
	return(endstak(movstr(x,p)));
}

/*
 * FGX: make the break cover `n' bytes from `p', plus the terminator and the
 * round-up endstak adds.  Upstream writes the stak with no bound and lets the
 * write past the break raise MEMF, whose handler grows it (fault.c:29); FGX has
 * no write fault, so every writer reserves first.  setbrk only moves brkend, so
 * `p' stays valid.  The distance is unsigned: a bank's free span passes 32 KB,
 * and every writer keeps `p' at or below brkend.  A refused break is fault.c's
 * `no space'.
 */
INT	stakneed(p, n)
	STKPTR		p;
	POS		n;
{
	WHILE (POS)(brkend-p) < n+BYTESPERWORD+2
	DO	IF setbrk(brkincr) == -1
		THEN	error(nospace);
		FI
		IF brkincr < BRKMAX
		THEN	brkincr += 256;
		FI
	OD
	return(0);
}
