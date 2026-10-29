/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/fgets.c
 *   Original work: fgets.c 5.2 (Berkeley) 3/9/86,
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
char *
fgets(s, n, iop)
char *s;
register FILE *iop;
{
	register c;
	register char *cs;

	cs = s;
	while (--n>0 && (c = getc(iop)) != EOF) {
		*cs++ = c;
		if (c=='\n')
			break;
	}
	if (c == EOF && cs==s)
		return(NULL);
	*cs++ = '\0';
	return(s);
}
