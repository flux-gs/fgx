/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/h/mbuf.h
 *   The user-visible part of usr/sys/h/mbuf.h, 2.11BSD, in the network
 *   stack's FGX layout (src/kernel/bsdnet/sys/mbuf.h).  Original work:
 *   Copyright (c) 1982, 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* What a program that reads the stack's memory through /dev/kmem needs to
 * read an mbuf: route(8)'s flushroutes reads the routing table this way.  The
 * layout is the stack's, field for field: a pointer is four bytes, so the
 * header is 10 and the tail 4. */
#ifndef _SYS_MBUF_H_
#define _SYS_MBUF_H_

#include <sys/types.h>

#define	MSIZE		128			/* size of an mbuf */
#define	MMINOFF		10			/* mbuf header length */
#define	MTAIL		4
#define	MMAXOFF		(MSIZE-MTAIL)		/* offset where data ends */
#define	MLEN		(MSIZE-MMINOFF-MTAIL)	/* mbuf data length */

/*
 * mbuf head, to typed data.  m_off is a 16-bit difference within the bank;
 * on a copy of the mbuf it names the same place in the copy, for data held
 * inside the mbuf itself.
 */
#define	mtod(x,t)	((t)(((long)(x) & 0xFFFF0000L) | \
			    (u_short)((u_short)(long)(x) + (x)->m_off)))

struct mbuf {
	struct	mbuf *m_next;		/* next buffer in chain */
	u_short	m_off;			/* offset of data */
	short	m_len;			/* amount of data in this mbuf */
	short	m_type;			/* mbuf type (0 == free) */
	u_char	m_dat[MLEN];		/* data storage */
	struct	mbuf *m_act;		/* link in higher-level mbuf list */
};

/* mbuf types */
#define	MT_FREE		0	/* should be on free list */
#define	MT_DATA		1	/* dynamic (data) allocation */
#define	MT_HEADER	2	/* packet header */
#define	MT_SOCKET	3	/* socket structure */
#define	MT_PCB		4	/* protocol control block */
#define	MT_RTABLE	5	/* routing tables */
#define	MT_HTABLE	6	/* IMP host tables */
#define	MT_ATABLE	7	/* address resolution tables */
#define	MT_SONAME	8	/* socket name */
#define	MT_ZOMBIE	9	/* zombie proc status */
#define	MT_SOOPTS	10	/* socket options */
#define	MT_FTABLE	11	/* fragment reassembly header */
#define	MT_RIGHTS	12	/* access rights */

#endif /* _SYS_MBUF_H_ */
