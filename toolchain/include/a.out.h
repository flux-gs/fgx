/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* a.out.h - the executable header.
 *
 * FGX-Provenance: FGX-original, with 2.11BSD's interface
 *   Interface: the Regents of the University of California.
 *   2.11BSD usr/include/a.out.h (5.6.1 1/6/94) names the header `struct exec'
 *   and tests it with N_BADMAG(x), true when x.a_magic is not an executable's
 *   magic number.  This file keeps those two names over FGX's own format,
 *   include/loader.s: a 16-byte header whose first four bytes are "FGX2" or
 *   "FGX3".  FGX has no PDP-11 a.out, overlays or symbol table in the file,
 *   so upstream's N_TXTOFF, N_STROFF and the rest have nothing to describe.
 */
#ifndef _AOUT_H_
#define _AOUT_H_

struct exec {
	long	a_magic;		/* "FGX2" or "FGX3", little-endian */
	char	a_hdr[12];		/* segment count, entry, flags, ... */
};

#define	A_MAGIC2	0x32584746L	/* "FGX2" */
#define	A_MAGIC3	0x33584746L	/* "FGX3" */

#define	N_BADMAG(x) \
	(((x).a_magic) != A_MAGIC2 && ((x).a_magic) != A_MAGIC3)

#endif /* !_AOUT_H_ */
