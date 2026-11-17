/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/net/route.h
 *   The user-visible part of usr/sys/net/route.h, 2.11BSD: what route(8)
 *   hands SIOCADDRT and SIOCDELRT.  Original work:
 *   Copyright (c) 1980, 1986 Regents of the University of California.
 *   All rights reserved.
 */
#ifndef _NET_ROUTE_H_
#define _NET_ROUTE_H_

#include <sys/socket.h>

struct rtentry {
	u_int	rt_hash;		/* to speed lookups */
	struct	sockaddr rt_dst;	/* key */
	struct	sockaddr rt_gateway;	/* value */
	short	rt_flags;		/* up/down?, host/net */
	short	rt_refcnt;		/* # held references */
	u_long	rt_use;			/* raw # packets forwarded */
	struct	ifnet *rt_ifp;		/* the answer: interface to use */
};

#define	RTF_UP		0x1		/* route useable */
#define	RTF_GATEWAY	0x2		/* destination is a gateway */
#define	RTF_HOST	0x4		/* host entry (net otherwise) */
#define	RTF_DYNAMIC	0x10		/* created dynamically (by redirect) */
#define	RTF_MODIFIED	0x20		/* modified dynamically (by redirect) */

#endif /* _NET_ROUTE_H_ */
