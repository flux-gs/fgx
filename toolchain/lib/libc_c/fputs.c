/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/fputs.c
 *   Original work: fputs.c 5.2 (Berkeley) 3/9/86,
 *	Copyright (c) 1984
 *	Regents of the University of California.
 */
/* Upstream's body.  FGX delta:
 * - `_bufsiz = 0', where upstream assigns NULL, which is a pointer here.
 * The #include lines are the aggregate's (libc_c.c).
 */
fputs(s, iop)
register char *s;
register FILE *iop;
{
	register r = 0;
	register c;
	int unbuffered;
	char localbuf[BUFSIZ];

	unbuffered = iop->_flag & _IONBF;
	if (unbuffered) {
		iop->_flag &= ~_IONBF;
		iop->_ptr = iop->_base = localbuf;
		iop->_bufsiz = BUFSIZ;
	}

	while (c = *s++)
		r = putc(c, iop);

	if (unbuffered) {
		fflush(iop);
		iop->_flag |= _IONBF;
		iop->_base = NULL;
		iop->_bufsiz = 0;
		iop->_cnt = 0;
	}

	return(r);
}
