/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD libcurses (putchar.c, Berkeley 6/7/85 era)
 *   Ported from usr.lib/libcurses (4.3BSD curses as shipped in 2.11BSD).
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if !defined(lint) && !defined(NOSCCS)
static char sccsid[] = "@(#)putchar.c	5.1 (Berkeley) 6/7/85";
#endif

# include	"curses.ext"

/* FGX: ANSI int(int) so the signature matches tputs' outc parameter
 * (int (*)(int) in libtermlib); upstream's char _putchar()
 * fell off the end without a return. */
int
_putchar(c)
int	c; {

	putchar(c);
#ifdef DEBUG
	fprintf(outf, "_PUTCHAR(%s)\n", unctrl(c));
#endif
	return c;
}
