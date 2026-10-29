/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/putw.c
 *   Original work: putw.c 5.2.1 (2.11BSD GTE) 1/1/94,
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
putw(w, iop)
register FILE *iop;
{
	register char *p;
	register i;

	p = (char *)&w;
	for (i=sizeof(int); --i>=0;)
		putc(*p++, iop);
	return(ferror(iop));
}

#ifdef pdp11
putlw(w, iop)
long w;
register FILE *iop;
{
	register char *p;
	register i;

	p = (char *)&w;
	for (i=sizeof(long); --i>=0;)
		putc(*p++, iop);
	return(ferror(iop));
}
#endif
