/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno net/if_dl.h
 *   After net/if_dl.h, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1990 Regents of the University of California.
 *   All rights reserved.
 */
/* A link-level address, as SIOCGIFCONF returns one per interface.  Reno's
 * fields from sdl_index on, in 2.11BSD's fixed 16-byte sockaddr: the family
 * is a u_short and there is no sdl_len.  sdl_nlen is 0, the name being the
 * ifreq's ifr_name, so the address starts sdl_data. */
#ifndef _NET_IF_DL_H_
#define _NET_IF_DL_H_


#ifndef AF_LINK
#define	AF_LINK		18		/* link layer interface */
#endif

struct sockaddr_dl {
	u_short	sdl_family;	/* AF_LINK */
	u_short	sdl_index;	/* the interface's place in the list, from 1 */
	u_char	sdl_type;	/* IFT_* */
	u_char	sdl_nlen;	/* 0: the name is ifr_name */
	u_char	sdl_alen;	/* link level address length */
	u_char	sdl_slen;	/* link layer selector length */
	char	sdl_data[8];	/* the link level address */
};

#define	LLADDR(s)	((caddr_t)((s)->sdl_data + (s)->sdl_nlen))

#define	IFT_ETHER	0x6		/* Reno net/if_types.h */
#define	IFT_LOOP	0x18

#endif /* _NET_IF_DL_H_ */
