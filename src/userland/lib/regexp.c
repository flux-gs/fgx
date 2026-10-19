/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD regex(3)
 *   Ported from regex.c 5.2 (Berkeley 3/9/86), usr/lib/libc/gen/regex.c:
 *   re_comp / re_exec / advance / backref / cclass.  Original work:
 *   Copyright (c) 1980 Regents of the University of California.  All rights
 *   reserved.  UCB notice retained per the BSD license; FGX changes are
 *   BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * The reusable ed-style basic-regular-expression engine -- the same lineage
 * 2.11BSD vi/ex (ex_re.c) use.  Character classes are stored as a
 * length-prefixed LINEAR byte list scanned by cclass() (NOT a bitmap), so
 * there is no bit-packing codegen.  Shared across userland tools by textual
 * #include (fcc has no separate compilation): grep includes it today; vi will
 * reuse it (Phase 4.3), adding the IGNORECASE/MAGIC seams then.
 *
 * API:
 *   char *re_comp(char *s);   0 on success, else an error-message string.
 *                             0/empty s reuses the last compiled RE.
 *   int   re_exec(char *s);   1 = s matched, 0 = no match, -1 = internal error.
 *   int   re_wflag;           caller sets nonzero to wrap the RE in \< ... \>.
 *
 * FGX/fcc adaptations (no feature loss):
 *  - PLUS \< / \> word-boundary ops (CBRC/CLET; regex.c lacked them, taken from
 *    grep.c's engine) -- for grep -w and as a vi prerequisite.  The \< line-
 *    start check uses an explicit re_bol the engine sets, so advance()'s lp[-1]
 *    is never read out of bounds (grep.c's `lp==expbuf` guard was buggy).
 *  - `&buf[n]` written `buf + n` (no &array-element op in fcc yet).
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#ifndef lint
static char re_sccsid[] = "@(#)regex.c\t5.2 (Berkeley) 3/9/86";
#endif not lint

/*
 * Compiled-RE opcodes (ed lineage).  CSTAR is OR'd into a base opcode.
 */
#define CBRA    1
#define CCHR    2
#define CDOT    4
#define CCL     6
#define NCCL    8
#define CDOL    10
#define CEOF    11
#define CKET    12
#define CBRC    14              /* \<  beginning of word (zero-width)  */
#define CLET    15              /* \>  end of word (zero-width)        */
#define CBACK   18

#define CSTAR   01

#define ESIZE   512
#define NBRA    9

/* ---- engine state (file-scope) ---- */
char  expbuf[ESIZE];
char *braslist[NBRA];
char *braelist[NBRA];
int   circf;
char *re_bol;                   /* beginning of the line being matched */
int   re_wflag;                 /* caller: wrap the RE with \< ... \>   */
char *re_toolong = "Regular expression too long";
char *re_loc2;                  /* advance() sets this to the char past a match */
int   re_nbra;                  /* number of \( \) groups in the last re_comp   */

/* ---- ANSI forward prototypes (tools/ansify.sh via cproto) ---- */
char *re_comp(char *sp);
int   re_exec(char *p1);
int   re_amatch(char *s);
int   advance(char *lp, char *ep);
int   backref(int i, char *lp);
int   cclass(char *set, int c, int af);
int   wordc(int c);

/* word char: [A-Za-z0-9_] */
int wordc(int c)
{
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
	       (c >= '0' && c <= '9') || c == '_';
}

/*
 * compile the regular expression argument into expbuf.  Returns 0 on success,
 * else a pointer to an error message.
 */
char *
re_comp(sp)
	register char *sp;
{
	register int   c;
	register char *ep = expbuf;
	int   cclcnt, numbra = 0;
	char *lastep = 0;
	char  bracket[NBRA];
	char *bracketp = &bracket[0];

#define comerr(msg) { expbuf[0] = 0; numbra = 0; return (msg); }

	if (sp == 0 || *sp == '\0') {
		if (*ep == 0)
			return ("No previous regular expression");
		return (0);
	}
	if (*sp == '^') {
		circf = 1;
		sp++;
	} else
		circf = 0;
	if (re_wflag)
		*ep++ = CBRC;
	for (;;) {
		if (ep >= expbuf + ESIZE)
			comerr(re_toolong);
		if ((c = *sp++) == '\0') {
			if (bracketp != bracket)
				comerr("unmatched \\(");
			if (re_wflag)
				*ep++ = CLET;
			*ep++ = CEOF;
			*ep++ = 0;
			re_nbra = numbra;
			return (0);
		}
		if (c != '*')
			lastep = ep;
		switch (c) {

		case '.':
			*ep++ = CDOT;
			continue;

		case '*':
			if (lastep == 0 || *lastep == CBRA || *lastep == CKET ||
			    *lastep == CBRC || *lastep == CLET)
				goto defchar;
			*lastep |= CSTAR;
			continue;

		case '$':
			if (*sp != '\0')
				goto defchar;
			*ep++ = CDOL;
			continue;

		case '[':
			*ep++ = CCL;
			*ep++ = 0;
			cclcnt = 1;
			if ((c = *sp++) == '^') {
				c = *sp++;
				ep[-2] = NCCL;
			}
			do {
				if (c == '\0')
					comerr("missing ]");
				if (c == '-' && ep[-1] != 0) {
					if ((c = *sp++) == ']') {
						*ep++ = '-';
						cclcnt++;
						break;
					}
					while (ep[-1] < c) {
						*ep = ep[-1] + 1;
						ep++;
						cclcnt++;
						if (ep >= expbuf + ESIZE)
							comerr(re_toolong);
					}
				}
				*ep++ = c;
				cclcnt++;
				if (ep >= expbuf + ESIZE)
					comerr(re_toolong);
			} while ((c = *sp++) != ']');
			lastep[1] = cclcnt;
			continue;

		case '\\':
			if ((c = *sp++) == '(') {
				if (numbra >= NBRA)
					comerr("too many \\(\\) pairs");
				*bracketp++ = numbra;
				*ep++ = CBRA;
				*ep++ = numbra++;
				continue;
			}
			if (c == ')') {
				if (bracketp <= bracket)
					comerr("unmatched \\)");
				*ep++ = CKET;
				*ep++ = *--bracketp;
				continue;
			}
			if (c == '<') {
				*ep++ = CBRC;
				continue;
			}
			if (c == '>') {
				*ep++ = CLET;
				continue;
			}
			if (c >= '1' && c < ('1' + NBRA)) {
				*ep++ = CBACK;
				*ep++ = c - '1';
				continue;
			}
			*ep++ = CCHR;
			*ep++ = c;
			continue;

		defchar:
		default:
			*ep++ = CCHR;
			*ep++ = c;
		}
	}
}

/*
 * match the argument string against the compiled re
 */
int
re_exec(p1)
	register char *p1;
{
	register char *p2 = expbuf;
	register int   c;
	int   rv;

	re_bol = p1;
	for (c = 0; c < NBRA; c++) {
		braslist[c] = 0;
		braelist[c] = 0;
	}
	if (circf)
		return (advance(p1, p2));
	/* fast check for first character */
	if (*p2 == CCHR) {
		c = p2[1];
		do {
			if (*p1 != c)
				continue;
			if (rv = advance(p1, p2))
				return (rv);
		} while (*p1++);
		return (0);
	}
	/* regular algorithm */
	do
		if (rv = advance(p1, p2))
			return (rv);
	while (*p1++);
	return (0);
}

/*
 * Anchored match of s against the last re_comp'd RE (no search/step): 1 if s
 * matches starting at s[0], else 0.  On a match, re_loc2 points past the match
 * (so re_loc2 - s is the match length) and braslist[0]/braelist[0] bound the
 * first \(...\) group.  Used by expr(1)'s ':' / match operators.
 */
int
re_amatch(s)
	register char *s;
{
	register int c;

	re_bol = s;
	for (c = 0; c < NBRA; c++) {
		braslist[c] = 0;
		braelist[c] = 0;
	}
	return (advance(s, expbuf));
}

/*
 * try to match the next thing in the dfa
 */
int
advance(lp, ep)
	register char *lp, *ep;
{
	register char *curlp;
	int   ct, i;
	int   rv;

	for (;;)
		switch (*ep++) {

		case CCHR:
			if (*ep++ == *lp++)
				continue;
			return (0);

		case CDOT:
			if (*lp++)
				continue;
			return (0);

		case CDOL:
			if (*lp == '\0')
				continue;
			return (0);

		case CEOF:
			re_loc2 = lp;
			return (1);

		case CCL:
			if (cclass(ep, *lp++, 1)) {
				ep += *ep;
				continue;
			}
			return (0);

		case NCCL:
			if (cclass(ep, *lp++, 0)) {
				ep += *ep;
				continue;
			}
			return (0);

		case CBRA:
			braslist[*ep++] = lp;
			continue;

		case CKET:
			braelist[*ep++] = lp;
			continue;

		case CBRC:                      /* \< : beginning of word */
			if (wordc(*lp) && (lp == re_bol || !wordc(lp[-1])))
				continue;
			return (0);

		case CLET:                      /* \> : end of word */
			if (!wordc(*lp))
				continue;
			return (0);

		case CBACK:
			if (braelist[i = *ep++] == 0)
				return (-1);
			if (backref(i, lp)) {
				lp += braelist[i] - braslist[i];
				continue;
			}
			return (0);

		case CBACK | CSTAR:
			if (braelist[i = *ep++] == 0)
				return (-1);
			curlp = lp;
			ct = braelist[i] - braslist[i];
			while (backref(i, lp))
				lp += ct;
			while (lp >= curlp) {
				if (rv = advance(lp, ep))
					return (rv);
				lp -= ct;
			}
			continue;

		case CDOT | CSTAR:
			curlp = lp;
			while (*lp++)
				;
			goto star;

		case CCHR | CSTAR:
			curlp = lp;
			while (*lp++ == *ep)
				;
			ep++;
			goto star;

		case CCL | CSTAR:
		case NCCL | CSTAR:
			curlp = lp;
			while (cclass(ep, *lp++, ep[-1] == (CCL | CSTAR)))
				;
			ep += *ep;
			goto star;

		star:
			do {
				lp--;
				if (rv = advance(lp, ep))
					return (rv);
			} while (lp > curlp);
			return (0);

		default:
			return (-1);
		}
}

int
backref(i, lp)
	register int   i;
	register char *lp;
{
	register char *bp;

	bp = braslist[i];
	while (*bp++ == *lp++)
		if (bp >= braelist[i])
			return (1);
	return (0);
}

int
cclass(set, c, af)
	register char *set;
	register int   c;
	int   af;
{
	register int n;

	if (c == 0)
		return (0);
	n = *set++;
	while (--n)
		if (*set++ == c)
			return (af);
	return (!af);
}
