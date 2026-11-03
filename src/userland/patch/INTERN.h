/* SPDX-License-Identifier: LicenseRef-Larry-Wall-Patch
 * FGX-Provenance: 2.11BSD usr.bin/patch/INTERN.h (patch 2.0, patchlevel 12)
 *   Larry Wall's patch, as 2.11BSD ships it: VERBATIM below this block.
 *   Its terms, from patch.c: "Copyright 1986, Larry Wall.  This program may
 *   be copied as long as you don't try to make any money off of it, or
 *   pretend that you wrote it."
 */
/* $Header: INTERN.h,v 2.0 86/09/17 15:35:58 lwall Exp $
 *
 * $Log:	INTERN.h,v $
 * Revision 2.0  86/09/17  15:35:58  lwall
 * Baseline for netwide release.
 * 
 */

#undef EXT
#define EXT

#undef INIT
#define INIT(x) = x

#define DOINIT
