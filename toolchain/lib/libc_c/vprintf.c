/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/vprintf.c
 *   Original work: vprintf.c 5.2 (Berkeley) 6/27/88,
 *	Copyright (c) 1988 Regents of the University of California.
 */
/* Upstream's body; ap is a <stdarg.h> va_list. */
int
vprintf(char *fmt, char *ap)
{
	int len;

	len = _doprnt(fmt, ap, stdout);
	return (ferror(stdout) ? EOF : len);
}
