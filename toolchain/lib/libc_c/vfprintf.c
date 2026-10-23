/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/vfprintf.c
 *   Original work: vfprintf.c 5.2 (Berkeley) 6/27/88,
 *	Copyright (c) 1988 Regents of the University of California.
 */
/* Upstream's body.  FGX deltas:
 * - ap is a <stdarg.h> va_list, the same pointer as upstream's varargs one.
 * - The borrowed buffer is fprintf.c's 128 bytes, and its size is set:
 *   upstream sets _ptr and _base but leaves _bufsiz 0, so each character
 *   went out through _flsbuf on its own.
 */
int
vfprintf(FILE *iop, char *fmt, char *ap)
{
	int len;
	char localbuf[_LC_LOCALBUF];

	if (iop->_flag & _IONBF) {
		iop->_flag &= ~_IONBF;
		iop->_ptr = iop->_base = localbuf;
		iop->_bufsiz = _LC_LOCALBUF;
		len = _doprnt(fmt, ap, iop);
		(void) fflush(iop);
		iop->_flag |= _IONBF;
		iop->_base = NULL;
		iop->_bufsiz = 0;
		iop->_cnt = 0;
	} else
		len = _doprnt(fmt, ap, iop);
	return (ferror(iop) ? EOF : len);
}
