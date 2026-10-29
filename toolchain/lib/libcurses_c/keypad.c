/* SPDX-License-Identifier: BSD-3-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 *
 * FGX-Provenance: NetBSD 1.5 libcurses (lib/libcurses/keypad.c)
 *   Ported into the 2.11BSD libcurses: the flag is _KEYPAD in _flags, the
 *   termcap string is 4.3BSD curses' KS, and output goes through _putchar.
 *   Original work: Copyright (c) 1998-1999 Brett Lymn and the NetBSD
 *   Foundation.  All rights reserved.  NetBSD notice retained per the BSD
 *   license (see docs/PROVENANCE.md).
 */
/*
 * Copyright (c) 1998-1999 Brett Lymn (blymn@baea.com.au, brett_lymn@yahoo.com)
 * All rights reserved.
 *
 * This code has been donated to The NetBSD Foundation by the Author.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. The name of the author may not be used to endorse or promote products
 *    derived from this software withough specific prior written permission
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

# include	"curses.ext"

/*
 * keypad --
 *	Turn on and off interpretation of function/keypad keys in the
 *	given window.
 */
keypad(win, bf)
reg WINDOW	*win;
bool		bf;
{
	if (bf) {
		win->_flags |= _KEYPAD;
		if (!(curscr->_flags & _KEYPAD)) {
			if (KS)
				tputs(KS, 0, _putchar);
			curscr->_flags |= _KEYPAD;
		}
	} else
		win->_flags &= ~_KEYPAD;
}
