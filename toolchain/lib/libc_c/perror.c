/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/gen/perror.c
 *   Original work: perror.c 8.1 (Berkeley) 6/4/93,
 *	Copyright (c) 1988, 1993
 *	The Regents of the University of California.
 */
/* Upstream's body.  The #include lines are the aggregate's (libc_c.c). */
void
perror(s)
	char *s;
{
	register struct iovec *v;
	struct iovec iov[4];

	v = iov;
	if (s && *s) {
		v->iov_base = (char *)s;
		v->iov_len = strlen(s);
		v++;
		v->iov_base = ": ";
		v->iov_len = 2;
		v++;
	}
	v->iov_base = strerror(errno);
	v->iov_len = strlen(v->iov_base);
	v++;
	v->iov_base = "\n";
	v->iov_len = 1;
	(void)writev(STDERR_FILENO, iov, (v - iov) + 1);
}
