/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/lib/libc/net/getnbyaddr.c
 *   Ported from usr/lib/libc/net/getnbyaddr.c, 2.11BSD (getnetbyaddr.c 5.3).  Original work:
 *   Copyright (c) 1983 Regents of the University of California.
 *   All rights reserved.
 */
/* getnetbyaddr, verbatim.  The #include lines are the aggregate's (libc_c.c). */
extern int _net_stayopen;

struct netent *
getnetbyaddr(net, type)
	register long net;
	register int type;
{
	register struct netent *p;

	setnetent(_net_stayopen);
	while (p = getnetent())
		if (p->n_addrtype == type && p->n_net == net)
			break;
	if (!_net_stayopen)
		endnetent();
	return (p);
}
