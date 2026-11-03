/* SPDX-License-Identifier: LicenseRef-Larry-Wall-Patch
 * FGX-Provenance: 2.11BSD usr.bin/patch/inp.h (patch 2.0, patchlevel 12)
 *   Larry Wall's patch, as 2.11BSD ships it: VERBATIM below this block.
 *   Its terms, from patch.c: "Copyright 1986, Larry Wall.  This program may
 *   be copied as long as you don't try to make any money off of it, or
 *   pretend that you wrote it."
 */
/* $Header: inp.h,v 2.0 86/09/17 15:37:25 lwall Exp $
 *
 * $Log:	inp.h,v $
 * Revision 2.0  86/09/17  15:37:25  lwall
 * Baseline for netwide release.
 * 
 */

EXT LINENUM input_lines INIT(0);	/* how long is input file in lines */
EXT LINENUM last_frozen_line INIT(0);	/* how many input lines have been */
					/* irretractibly output */

bool rev_in_string();
void scan_input();
bool plan_a();			/* returns false if insufficient memory */
void plan_b();
char *ifetch();

