/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/pdp/machparam.h
 *   Written for FGX after usr/sys/pdp/machparam.h, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* machparam.h -- the machine constants the network code reads, for the 65816.
 * Byte order is LITTLE: the PDP's middle-endian long does not apply. */
#ifndef ENDIAN
#define	LITTLE	1234
#define	BIG	4321
#define	PDP	3412
#define	ENDIAN	LITTLE

#define	ntohs(x)	((u_short)((((u_short)(x) & 0xff) << 8) | \
			    (((u_short)(x) >> 8) & 0xff)))
#define	htons(x)	ntohs(x)
#define	ntohl(x)	((u_long)((((u_long)(x) & 0xffL) << 24) | \
			    (((u_long)(x) & 0xff00L) << 8) | \
			    (((u_long)(x) & 0xff0000L) >> 8) | \
			    (((u_long)(x) >> 24) & 0xffL)))
#define	htonl(x)	ntohl(x)

#define	NBPG		512		/* bytes/page */
#define	PGOFSET		(NBPG-1)	/* byte offset into page */
#define	PGSHIFT		9		/* LOG2(NBPG) */
#define	CLSIZE		2
#define	CLSIZELOG2	1
#define	MAXBSIZE_M	1024
#endif
