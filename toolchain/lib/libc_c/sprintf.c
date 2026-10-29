/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/sprintf.c
 *   Original work: vsprintf.c 5.2.1 (2.11BSD) 1995/04/02,
 *	Copyright (c) 1988
 *	Regents of the University of California.
 */
/* Upstream's body.  FGX delta: the arguments arrive through <stdarg.h>
 * rather than as `&args', as in printf.c: the prototype in <stdio.h> is
 * variadic, and on this ABI the two are the same pointer. */
int
sprintf(char *str, char *fmt, ...)
{
	FILE _strbuf;
	va_list ap;

	_strbuf._flag = _IOWRT+_IOSTRG;
	_strbuf._ptr = str;
	_strbuf._cnt = 32767;
	va_start(ap, fmt);
	_doprnt(fmt, ap, &_strbuf);
	va_end(ap);
	*_strbuf._ptr = 0;
	return(_strbuf._ptr - str);
}
