/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/scanf.c
 *   Original work: scanf.c 5.2 (Berkeley) 3/9/86,
 *	The Regents of the University of California.
 */
/* ---- scanf(3), fscanf(3), sscanf(3) --------------------------------------
 * Upstream's three wrappers over _doscan (doscan.c).  FGX deltas: each takes
 * its arguments with va_start where upstream takes `&args', the prototypes
 * in stdio.h being variadic; and sscanf hands _doscan its string through
 * __lc_scstr and a NULL FILE, where upstream builds an _IOSTRG FILE on the
 * stack (doscan.c says why).
 */
int
scanf(char *fmt, ...)
{
	va_list ap;
	int r;

	va_start(ap, fmt);
	r = _doscan(stdin, fmt, (int **)ap);
	va_end(ap);
	return (r);
}

int
fscanf(FILE *iop, char *fmt, ...)
{
	va_list ap;
	int r;

	va_start(ap, fmt);
	r = _doscan(iop, fmt, (int **)ap);
	va_end(ap);
	return (r);
}

int
sscanf(char *str, char *fmt, ...)
{
	va_list ap;
	int r;

	va_start(ap, fmt);
	__lc_scstr = str;
	r = _doscan((FILE *)NULL, fmt, (int **)ap);
	va_end(ap);
	return (r);
}
