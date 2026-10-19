/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* ---- strerror(3) ---------------------------------------------------------
 * FGX-Provenance: 2.11BSD lib/libc/string/strerror.c (8.1.1 (2.11BSD)
 *   1996/3/15) vendored at vendor/2.11BSD/usr/lib/libc/string/strerror.c.
 *   Copyright (c) 1988, 1993 The Regents of the University of California.
 *   All rights reserved.  UCB notice retained per the BSD license; FGX
 *   changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 * Upstream's body: the message comes from syserrlst() (syserrlst.c), and a
 * number with none gets "Unknown error: <n>" built by hand.  One line added,
 * the NUL after the digits: upstream relies on ebuf's zero fill, so a shorter
 * number after a longer one kept the longer one's tail ("Unknown error: 9934"
 * for 99 after 1234).  4.4BSD has the same loop; FreeBSD later added the same
 * terminator.
 */
char *
strerror(num)
	int num;
{
#define	UPREFIX	"Unknown error: "
	static char ebuf[30] = UPREFIX;		/* 32-bit number + slop */
	register unsigned int errnum;
	register char *p, *t;
	char tmp[20];

	errnum = num;				/* convert to unsigned */
	if (p = syserrlst(errnum))
		return(p);

	/* Do this by hand, so we don't include stdio(3). */
	t = tmp;
	do {
		*t++ = '0' + (errnum % 10);
	} while (errnum /= 10);
	for (p = ebuf + sizeof(UPREFIX) - 1;;) {
		*p++ = *--t;
		if (t <= tmp)
			break;
	}
	*p = '\0';				/* FGX: see the header */
	return(ebuf);
}
