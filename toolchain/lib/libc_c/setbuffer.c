/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/stdio/setbuffer.c
 *   Original work: setbuffer.c 8.1.1 (2.11BSD) 1997/7/29,
 *	Copyright (c) 1990, 1993
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
void
setbuffer(fp, buf, size)
	register FILE *fp;
	char *buf;
	int size;
{

	(void)setvbuf(fp, buf, buf ? _IOFBF : _IONBF, size);
}

/*
 * set line buffering
 */
int
setlinebuf(fp)
	FILE *fp;
{

	return (setvbuf(fp, (char *)NULL, _IOLBF, (size_t)0));
}
