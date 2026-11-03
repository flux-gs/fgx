/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD vendor/2.11BSD/usr/lib/libc/gen/telldir.c and
 *   seekdir.c
 *   Original work: telldir.c 5.2 and seekdir.c 5.2 (Berkeley) 3/9/86,
 *	Copyright (c) 1983 Regents of the University of California.
 */
/* telldir(3) and seekdir(3).  Upstream's interface: telldir's answer is a
 * position in the directory, and "Only values returned by telldir should be
 * passed to seekdir".  Upstream's position is the descriptor's offset less
 * what is still buffered; a FGX DIR is the whole directory read at opendir
 * (dir.c), so the position is the cursor into that snapshot and seekdir
 * sets it.  A second opendir of the same, unchanged directory lists it in
 * the same order, so a position carries across a closedir and reopen as
 * du(1) carries it.  One member for both, as each needs the other's
 * meaning of the position. */
long
telldir(dirp)
	DIR *dirp;
{
	return ((long)dirp->dd_loc);
}

void
seekdir(dirp, loc)
	register DIR *dirp;
	long loc;
{
	if (loc >= 0 && loc <= dirp->dd_size)
		dirp->dd_loc = (int)loc;
}
