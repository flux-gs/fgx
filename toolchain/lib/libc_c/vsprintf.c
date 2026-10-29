/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/vsprintf.c
 *   Original work: vsprintf.c 5.2.1 (2.11BSD) 1995/04/02,
 *	Copyright (c) 1988
 *	Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
int
vsprintf(str, fmt, ap)
	char *str, *fmt;
	va_list ap;
{
	FILE f;

	f._flag = _IOWRT+_IOSTRG;
	f._ptr = str;
	f._cnt = 32767;
	_doprnt(fmt, ap, &f);
	*f._ptr = 0;
	return (f._ptr - str);
}
