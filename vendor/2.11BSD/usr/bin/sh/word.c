#ifndef lint
static char sccsid[] = "@(#)word.c	4.6 10/31/85";
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
#include	"sym.h"


/* ========	character handling for command lines	========*/

/*
 * FGX (apple/fgx#16): keep room ahead of `argp` while a word is being built.
 * Documented as a vendor exception in src/userland/sh/README.md.
 *
 * word() calls locstak() ONCE, which guarantees BRKINCR (512) bytes of
 * headroom, and then writes the whole token with bare `*argp++` in loops that
 * are not bounded by anything.  On a PDP-11 that is deliberate: the write past
 * the break TRAPS, fault.c's MEMF handler calls setbrk, the break moves, and
 * the faulting instruction is restarted.  The lexer's token buffer grows by
 * PAGE FAULT.
 *
 * FGX has no write-fault, so the overrun would be silent, and sbrk's zero-fill
 * of the next grow would erase the token.
 *
 * So grow BEFORE writing, which is what 2.11BSD itself does wherever it cannot
 * rely on the fault -- roff's SPACETEST, and macro.c:201's per-character
 * locstak().  setbrk only moves brkend; nothing in [stakbot,staktop) is
 * relocated, so `argp` stays valid across it.  A refused break returns -1 since
 * #13, so a genuinely full arena now reports `sh: no space` here instead of
 * corrupting -- the two fixes compose.
 */
LOCAL INT	wdcnt;		/* chars writable before the next check */

VOID	wdgrow(argp)
	REG CHAR	*argp;
{
	REG POS		room;

	stakneed(argp, 0);
	room = (brkend-argp) - (BYTESPERWORD+2);
	wdcnt = room > 32767 ? 32767 : room;
}

/*
 * FGX: the check is HOISTED out of the per-character path.  The obvious form --
 * call a function before every `*argp++` -- costs 95 instructions per character
 * through a cross-bank FGX2_FARCALL, which is ~4 s of IIgs time on a 43 KB
 * sourced script.  A grow reserves at least BRKINCR (512) bytes, so the next 512
 * writes need no check at all: count them down instead, and pay the far call
 * only when the counter runs out.  Per character this is one INT decrement.
 *
 * The count is reset at the start of every word, so each word pays one wdgrow.
 * A count carried between words is not conservative: a word fixed on the stak
 * by endstak moves stakbot above it, so the next word can start higher than
 * the last one ended, and stakchk lowers the break between commands.
 */
#define wdroom(p)	IF --wdcnt < 0 THEN wdgrow(p) FI

word()
{
	REG CHAR	c, d;
	REG CHAR	*argp=locstak()+BYTESPERWORD;
	INT		alpha=1;

	wdcnt=0;

	wdnum=0; wdset=0;

	WHILE (c=nextc(0), space(c)) DONE

	IF c=='#' ANDF ((flags&prompt)==0 ORF ((flags&ttyflg) ANDF
	    standin->fstak!=0))
	THEN	WHILE (c=readc()) ANDF c!=NL DONE
	FI

	IF !eofmeta(c)
	THEN	REP	IF c==LITERAL
			THEN	wdroom(argp); *argp++=(DQUOTE);
				WHILE (c=readc()) ANDF c!=LITERAL
				DO wdroom(argp); *argp++=(c|QUOTE); chkpr(c) OD
				wdroom(argp); *argp++=(DQUOTE);

			ELSE	wdroom(argp); *argp++=(c);
				IF c=='=' THEN wdset |= alpha FI
				IF !alphanum(c) THEN alpha=0 FI
				IF qotchar(c)
				THEN	d=c;
					/* the write is IN the condition, so the
					 * room for iteration N+1 is made at the
					 * end of iteration N (and before the
					 * first, just above). */
					WHILE (*argp++=(c=nextc(d))) ANDF c!=d
					DO chkpr(c); wdroom(argp) OD
				FI
			FI
		PER (c=nextc(0), !eofmeta(c)) DONE
		argp=endstak(argp);
		IF !letter(argp->argval[0]) THEN wdset=0 FI

		peekc=c|MARK;
		IF argp->argval[1]==0 ANDF (d=argp->argval[0], digit(d)) ANDF (c=='>' ORF c=='<')
		THEN	word(); wdnum=d-'0';
		ELSE	/*check for reserved words*/
			IF reserv==FALSE ORF (wdval=syslook(argp->argval,reserved))==0
			THEN	wdarg=argp; wdval=0;
			FI
		FI

	ELIF dipchar(c)
	THEN	IF (d=nextc(0))==c
		THEN	wdval = c|SYMREP;
		ELSE	peekc = d|MARK; wdval = c;
		FI
	ELSE	IF (wdval=c)==EOF
		THEN	wdval=EOFSYM;
		FI
		IF iopend ANDF eolchar(c)
		THEN	copy(iopend); iopend=0;
		FI
	FI
	reserv=FALSE;
	return(wdval);
}

nextc(quote)
	CHAR		quote;
{
	REG CHAR	c, d;
	IF (d=readc())==ESCAPE
	THEN	IF (c=readc())==NL
		THEN	chkpr(NL); d=nextc(quote);
		ELIF quote ANDF c!=quote ANDF !escchar(c)
		THEN	peekc=c|MARK;
		ELSE	d = c|QUOTE;
		FI
	FI
	return(d);
}

readc()
{
	REG CHAR	c;
	REG INT		len;
	REG FILE	f;

retry:
	IF peekc
	THEN	c=peekc; peekc=0;
	ELIF (f=standin, f->fnxt!=f->fend)
	THEN	IF (c = *f->fnxt++)==0
		THEN	IF f->feval
			THEN	IF estabf(*f->feval++)
				THEN	c=EOF;
				ELSE	c=SP;
				FI
			ELSE	goto retry; /* = c=readc(); */
			FI
		FI
		IF flags&readpr ANDF standin->fstak==0 THEN prc(c) FI
		IF c==NL THEN f->flin++ FI
	ELIF f->feof ORF f->fdes<0
	THEN	c=EOF; f->feof++;
	ELIF (len=readb())<=0
	THEN	close(f->fdes); f->fdes = -1; c=EOF; f->feof++;
	ELSE	f->fend = (f->fnxt = f->fbuf)+len;
		goto retry;
	FI
	return(c);
}

LOCAL	readb()
{
	REG FILE	f=standin;
	REG INT		len;

	IF setjmp(INTbuf) == 0 THEN trapjmp[INTR] = 1; FI
	REP	IF trapnote&SIGSET THEN newline(); sigchk() FI
	PER (len=read(f->fdes,f->fbuf,f->fsiz))<0 ANDF trapnote DONE
	trapjmp[INTR] = 0;
	return(len);
}
