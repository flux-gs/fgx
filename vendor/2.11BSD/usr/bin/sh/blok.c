#ifndef lint
static char sccsid[] = "@(#)blok.c	4.2 8/11/83";
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
 *	storage allocator
 *	(circular first fit strategy)
 */

#define BUSY 01
#define busy(x)	(Rcheat((x)->word)&BUSY)

POS		brkincr=BRKINCR;
BLKPTR		blokp;			/*current search pointer*/
BLKPTR		bloktop=BLK(end);	/*top of arena (last blok)*/



ADDRESS	alloc(nbytes)
	POS		nbytes;
{
	REG POS		rbytes = round(nbytes+BYTESPERWORD,BYTESPERWORD);

	LOOP	INT		c=0;
		REG BLKPTR	p = blokp;
		REG BLKPTR	q;
		REP	IF !busy(p)
			THEN	WHILE !busy(q = p->word) DO p->word = q->word OD
				IF ADR(q)-ADR(p) >= rbytes
				THEN	blokp = BLK(ADR(p)+rbytes);
					IF q > blokp
					THEN	blokp->word = p->word;
					FI
					p->word=BLK(Rcheat(blokp)|BUSY);
					return(ADR(p+1));
				FI
			FI
			q = p; p = BLK(Rcheat(p->word)&~BUSY);
		PER	p>q ORF (c++)==0 DONE
		addblok(rbytes);
	POOL
}

VOID	addblok(reqd)
	POS		reqd;
{
	IF stakbas!=staktop
	THEN	REG STKPTR	rndstak;
		REG BLKPTR	blokstak;

		/* FGX #16: this terminator is written AT staktop, which is exactly
		 * where the arena has run out -- the same unguarded past-the-break
		 * store the fault handler used to absorb. */
		IF brkend-staktop < BYTESPERWORD
		THEN	IF setbrk(brkincr) == -1
			THEN	error(nospace);
			FI
			IF brkincr < BRKMAX
			THEN	brkincr += 256;
			FI
		FI
		pushstak(0);
		rndstak=round(staktop,BYTESPERWORD);
		blokstak=BLK(stakbas)-1;
		blokstak->word=stakbsy; stakbsy=blokstak;
		bloktop->word=BLK(Rcheat(rndstak)|BUSY);
		bloktop=BLK(rndstak);
	FI
	reqd += brkincr; reqd &= ~(brkincr-1);
	blokp=bloktop;
	/*
	 * FGX (apple/fgx#16): make the break cover the arena BEFORE writing into
	 * it.  Documented as a vendor exception in src/userland/sh/README.md.
	 *
	 * Upstream just walks bloktop forward and stores through it.  It never
	 * calls setbrk and never looks at brkend, because on a PDP-11 it does
	 * not have to: the store past the break TRAPS, fault.c's MEMF handler
	 * calls setbrk, the break moves, and the faulting instruction restarts.
	 * The shell's whole heap grows by page fault.
	 *
	 * FGX has no write-fault, so those stores would land past the break in
	 * silence, where sbrk's zero-fill of the next grow erases them.  So grow
	 * first, the way 2.11BSD does wherever it cannot rely on the fault.  The
	 * far edge is not the new bloktop but the stak item copied just above it,
	 * so cover that too.  The copy is movstr, so its extent is
	 * length(stakbot): at startup staktop is still 0 while stakbot is nullstr,
	 * and staktop-stakbot is negative.  A refused break returns -1 since #13,
	 * so a genuinely full arena reports `sh: no space` here
	 * rather than scribbling.
	 */
	BEGIN
	   REG STKPTR	need;
	   need = STK(BLK(Rcheat(bloktop)+reqd)+2) + length(stakbot)
		  + BYTESPERWORD;
	   WHILE brkend < need
	   DO	IF setbrk(brkincr) == -1
		THEN	error(nospace);
		FI
		IF brkincr < BRKMAX
		THEN	brkincr += 256;
		FI
	   OD
	END
	bloktop=bloktop->word=BLK(Rcheat(bloktop)+reqd);
	bloktop->word=BLK(ADR(end)+1);
	BEGIN
	   REG STKPTR stakadr=STK(bloktop+2);
	   staktop=movstr(stakbot,stakadr);
	   stakbas=stakbot=stakadr;
	END
}

VOID	free(ap)
	BLKPTR		ap;
{
	REG BLKPTR	p;

	IF (p=ap) ANDF p<bloktop
	THEN	Lcheat((--p)->word) &= ~BUSY;
	FI
}

#ifdef DEBUG
chkbptr(ptr)
	BLKPTR	ptr;
{
	INT		exf=0;
	REG BLKPTR	p = end;
	REG BLKPTR	q;
	INT		us=0, un=0;

	LOOP
	   q = Rcheat(p->word)&~BUSY;
	   IF p==ptr THEN exf++ FI
	   IF q<end ORF q>bloktop THEN abort(3) FI
	   IF p==bloktop THEN break FI
	   IF busy(p)
	   THEN us += q-p;
	   ELSE un += q-p;
	   FI
	   IF p>=q THEN abort(4) FI
	   p=q;
	POOL
	IF exf==0 THEN abort(1) FI
	prn(un); prc(SP); prn(us); prc(NL);
}
#endif
