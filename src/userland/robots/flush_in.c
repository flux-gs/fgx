/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: 2.11BSD robots (flush_in.c, sccs 5.1, Berkeley 1985)
 *   Ported from src/games/robots (4.3BSD robots as shipped in 2.11BSD).
 *   Original work: Copyright (c) 1980 Regents of the University of
 *   California.  All rights reserved.  UCB notice retained per the BSD
 *   license; FGX changes are BSD-2-Clause (see LICENSE / docs/PROVENANCE.md).
 *
 *   FGX delta: no TIOCFLUSH ioctl — the crmode() fallback arm is the
 *   whole body (upstream's #else branch), tokens-after-#endif dropped.
 */
/*
 * Copyright (c) 1980 Regents of the University of California.
 * All rights reserved.  The Berkeley software License Agreement
 * specifies the terms and conditions for redistribution.
 */

#if !defined(lint) && !defined(NOSCCS)
static char sccsid[] = "@(#)flush_in.c	5.1 (Berkeley) 5/30/85";
#endif

# include <curses.h>

/*
 * flush_in:
 *	Flush all pending input.
 */
flush_in()
{
	crmode();
}
