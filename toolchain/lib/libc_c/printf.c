/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/printf.c
 *   Original work: printf.c 5.2 (Berkeley) 3/9/86,
 *	The Regents of the University of California.
 */
/* Upstream's body.  FGX deltas:
 * - The arguments arrive through <stdarg.h> rather than as `&args'; on this
 *   ABI the two are the same pointer, and the prototype in <stdio.h> is
 *   variadic.
 * - The count is returned, as 2.11BSD's own vfprintf.c returns it, where
 *   upstream's printf returns 0.  2.11BSD's callers use it: more.c's
 *   prompt and finger's lprint.c add it to a column.
 */
int
printf(char *fmt, ...)
{
	va_list ap;
	int len;

	va_start(ap, fmt);
	len = _doprnt(fmt, ap, stdout);
	va_end(ap);
	return(ferror(stdout)? EOF: len);
}
