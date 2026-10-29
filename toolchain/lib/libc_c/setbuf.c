/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/setbuf.c
 *   Original work: setbuf.c 8.1.1 (2.11BSD) 1997/7/29,
 *	Copyright (c) 1990, 1993
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
void
setbuf(fp, buf)
	FILE *fp;
	char *buf;
{
	(void) setvbuf(fp, buf, buf ? _IOFBF : _IONBF, BUFSIZ);
}
