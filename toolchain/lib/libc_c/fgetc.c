/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/fgetc.c
 *   Original work: fgetc.c 5.3 (Berkeley) 3/4/87,
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
fgetc(fp)
register FILE *fp;
{
	return(getc(fp));
}
