/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/lib/libc/inet/inet_maddr.c
 *   Ported from usr/lib/libc/inet/inet_maddr.c, 2.11BSD (inet_makeaddr.c 5.1).  Original work:
 *   Copyright (c) 1983 Regents of the University of California.
 *   All rights reserved.
 */
/* inet_makeaddr, verbatim.  The #include lines are the aggregate's (libc_c.c). */
/*
 * Formulate an Internet address from network + host.  Used in
 * building addresses stored in the ifnet structure.
 */
struct in_addr
inet_makeaddr(net, host)
	long net, host;
{
	u_long addr;

	if (net < 128)
		addr = (net << IN_CLASSA_NSHIFT) | (host & IN_CLASSA_HOST);
	else if (net < 65536L)
		addr = (net << IN_CLASSB_NSHIFT) | (host & IN_CLASSB_HOST);
	else
		addr = (net << IN_CLASSC_NSHIFT) | (host & IN_CLASSC_HOST);
	addr = htonl(addr);
	return (*(struct in_addr *)&addr);
}
