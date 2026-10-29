/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/fprintf.c
 *   Original work: fprintf.c 5.2 (Berkeley) 3/9/86,
 *	Copyright (c) 1980 Regents of the University of California.
 */
/* Upstream's body.  FGX deltas:
 * - <stdarg.h> arguments, and the count returned: see printf.c.
 */
int
fprintf(FILE *iop, char *fmt, ...)
{
	char localbuf[BUFSIZ];
	va_list ap;
	int len;

	va_start(ap, fmt);
	if (iop->_flag & _IONBF) {
		iop->_flag &= ~_IONBF;
		iop->_ptr = iop->_base = localbuf;
		iop->_bufsiz = BUFSIZ;
		len = _doprnt(fmt, ap, iop);
		fflush(iop);
		iop->_flag |= _IONBF;
		iop->_base = NULL;
		iop->_bufsiz = 0;
		iop->_cnt = 0;
	} else
		len = _doprnt(fmt, ap, iop);
	va_end(ap);
	return(ferror(iop)? EOF: len);
}
