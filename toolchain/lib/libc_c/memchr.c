/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno vendor/4.3BSD-Reno/lib/libc/string/memchr.c
 *   Original work: memchr.c 5.5 (Berkeley) 5/15/90,
 *	Copyright (c) 1990 The Regents of the University of California.
 */
/* memchr(3), for _doprnt's %.Ns (doprnt.c).  Its own member, as strstr.c's
 * rule has it.  Upstream's body.  FGX deltas:
 * - n is an int, as <string.h>'s other mem functions take theirs.
 * - NULL is spelled 0: <string.h>'s is a char pointer, and this returns
 *   void *.
 */
void *
memchr(s, c, n)
	const void *s;
	register unsigned char c;
	register int n;
{
	if (n != 0) {
		register const unsigned char *p = s;

		do {
			if (*p++ == c)
				return ((void *)(p - 1));
		} while (--n != 0);
	}
	return (0);
}
