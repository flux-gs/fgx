/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/lib/libc/inet/inet_lnaof.c
 *   Ported from usr/lib/libc/inet/inet_lnaof.c, 2.11BSD (inet_lnaof.c 5.2).  Original work:
 *   Copyright (c) 1983 Regents of the University of California.
 *   All rights reserved.
 */
/* inet_lnaof, verbatim.  The #include lines are the aggregate's (libc_c.c). */
/*
 * Return the local network address portion of an
 * internet address; handles class a/b/c network
 * number formats.
 */
u_long
inet_lnaof(in)
	struct in_addr in;
{
	register u_long i = ntohl(in.s_addr);

	if (IN_CLASSA(i))
		return ((i)&IN_CLASSA_HOST);
	else if (IN_CLASSB(i))
		return ((i)&IN_CLASSB_HOST);
	else
		return ((i)&IN_CLASSC_HOST);
}
