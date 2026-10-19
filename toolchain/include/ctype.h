/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ctype.h - character classification.
 *
 * FGX-Provenance: 2.11BSD usr/include/ctype.h
 *   Ported from ctype.h 4.2 85/09/04 (2.11BSD), vendored at
 *   vendor/2.11BSD/usr/include/ctype.h.
 *   Original work: the Regents of the University of California.
 *   The upstream file carries its sccsid and no dated notice.
 *   UCB notice retained per the BSD license; FGX changes are BSD-2-Clause
 *   (see LICENSE / docs/PROVENANCE.md).
 *
 * THE CLASSIFIERS ARE UPSTREAM'S TABLE LOOKUPS, and so each evaluates its
 * argument ONCE.  BSD source depends on that: syslogd's `isdigit(*++p)' walks
 * a "<13>" priority one digit per test, and a macro that named `c' twice
 * stepped p twice per test and read <13> as 3.  The table is _ctype_, libc's
 * ctype_.c, one flag byte per character with the byte for EOF first.
 *
 * FGX'S INDEX IS MASKED TO EIGHT BITS where upstream's is not.  fcc's plain
 * char is signed, so a byte with the high bit set -- common in Apple II text --
 * reaches these as -128..-1, and upstream's (_ctype_+1)[c] would read up to 127
 * bytes before the table.  (c)&0377 sends those to the table's upper half,
 * which is all zero: no class, as upstream's 7-bit table means.  EOF (-1)
 * masks to 255, also zero, which is what the table's leading EOF byte says.
 *
 * toupper AND tolower ARE NOT UPSTREAM'S.  2.11BSD's convert unconditionally
 * -- `((c)-'a'+'A')', correct only for a character already known to be lower
 * case -- and FGX's callers pass arbitrary characters, so these test first.
 * They name c twice, so they must not be handed a side-effecting argument.
 */
#ifndef _CTYPE_H
#define _CTYPE_H

#define	_U	01
#define	_L	02
#define	_N	04
#define	_S	010
#define _P	020
#define _C	040
#define _X	0100
#define	_B	0200

extern	char	_ctype_[];

#define	isalpha(c)	((_ctype_+1)[(c)&0377]&(_U|_L))
#define	isupper(c)	((_ctype_+1)[(c)&0377]&_U)
#define	islower(c)	((_ctype_+1)[(c)&0377]&_L)
#define	isdigit(c)	((_ctype_+1)[(c)&0377]&_N)
#define	isxdigit(c)	((_ctype_+1)[(c)&0377]&(_N|_X))
#define	isspace(c)	((_ctype_+1)[(c)&0377]&_S)
#define ispunct(c)	((_ctype_+1)[(c)&0377]&_P)
#define isalnum(c)	((_ctype_+1)[(c)&0377]&(_U|_L|_N))
#define isprint(c)	((_ctype_+1)[(c)&0377]&(_P|_U|_L|_N|_B))
#define isgraph(c)	((_ctype_+1)[(c)&0377]&(_P|_U|_L|_N))
#define iscntrl(c)	((_ctype_+1)[(c)&0377]&_C)
#define isascii(c)	((unsigned)(c)<=0177)
#define toupper(c)	(islower(c) ? (c) - 'a' + 'A' : (c))
#define tolower(c)	(isupper(c) ? (c) - 'A' + 'a' : (c))
#define toascii(c)	((c)&0177)

#endif /* _CTYPE_H */
