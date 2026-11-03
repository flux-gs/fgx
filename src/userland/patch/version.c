/* SPDX-License-Identifier: LicenseRef-Larry-Wall-Patch
 * FGX-Provenance: 2.11BSD usr.bin/patch/version.c (patch 2.0, patchlevel 12)
 *   Larry Wall's patch, as 2.11BSD ships it: VERBATIM below this block.
 *   Its terms, from patch.c: "Copyright 1986, Larry Wall.  This program may
 *   be copied as long as you don't try to make any money off of it, or
 *   pretend that you wrote it."
 */
/* $Header: version.c,v 2.0 86/09/17 15:40:11 lwall Exp $
 *
 * $Log:	version.c,v $
 * Revision 2.0  86/09/17  15:40:11  lwall
 * Baseline for netwide release.
 * 
 */

#include "EXTERN.h"
#include "common.h"
#include "util.h"
#include "INTERN.h"
#include "patchlevel.h"
#include "version.h"

/* Print out the version number and die. */

void
version()
{
    extern char rcsid[];

#ifdef lint
    rcsid[0] = rcsid[0];
#else
    fatal3("%s\nPatch level: %d\n", rcsid, PATCHLEVEL);
#endif
}
