/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/scanf.c
 *   Original work: scanf.c 5.2 (Berkeley) 3/9/86,
 *	The Regents of the University of California.
 */
/* ---- scanf(3), fscanf(3), sscanf(3) --------------------------------------
 * Upstream's three wrappers over _doscan (doscan.c).  FGX deltas: each takes
 * its arguments with va_start where upstream takes `&args', the prototypes
 * in stdio.h being variadic.  sscanf builds upstream's _IOSTRG FILE on the
 * string, which _filbuf answers EOF at its end.
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
	FILE _strbuf;

	va_start(ap, fmt);
	_strbuf._flag = _IOREAD|_IOSTRG;
	_strbuf._ptr = _strbuf._base = str;
	_strbuf._cnt = 0;
	while (*str++)
		_strbuf._cnt++;
	_strbuf._bufsiz = _strbuf._cnt;
	r = _doscan(&_strbuf, fmt, (int **)ap);
	va_end(ap);
	return (r);
}
