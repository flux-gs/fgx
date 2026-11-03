/* SPDX-License-Identifier: LicenseRef-Larry-Wall-Patch
 * FGX-Provenance: 2.11BSD usr.bin/patch/EXTERN.h (patch 2.0, patchlevel 12)
 *   Larry Wall's patch, as 2.11BSD ships it: VERBATIM below this block.
 *   Its terms, from patch.c: "Copyright 1986, Larry Wall.  This program may
 *   be copied as long as you don't try to make any money off of it, or
 *   pretend that you wrote it."
 */
/* $Header: EXTERN.h,v 2.0 86/09/17 15:35:37 lwall Exp $
 *
 * $Log:	EXTERN.h,v $
 * Revision 2.0  86/09/17  15:35:37  lwall
 * Baseline for netwide release.
 * 
 */

#undef EXT
#define EXT extern

#undef INIT
#define INIT(x)

#undef DOINIT
