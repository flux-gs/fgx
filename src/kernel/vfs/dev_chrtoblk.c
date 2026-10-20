/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX-Origin: original -- FGX code.  GENERATED, do not edit.
 */
/* dev_chrtoblk.c -- a raw disk's block counterpart.  apple/fgx#410.
 *
 * WRITTEN BY tools/ninja/gen.py FROM RAW_DISK_NODES and ROOT_BLKUNITS.  Edit
 * the lists there; the same lists mknod the nodes onto the root, so this
 * table and the image cannot disagree.
 *
 * THE ONLY CALLER IS spec_securechr, the securelevel gate: a character
 * device may not be opened for writing at level 1 while a filesystem is
 * mounted on the block device behind it, and this is what says which block
 * device that is.
 */

#include "vnode.h"

/* chrtoblk -- the block rdev behind a character rdev, or NODEV.
 * 2.11BSD usr/sys/pdp/conf.c:563. */
dev_t
chrtoblk(dev)
dev_t dev;
{
    if (dev == 10) return ((dev_t) 0);   /* rsd0 -> sd0 */
    if (dev == 11) return ((dev_t) 1);   /* rsd1 -> sd1 */
    if (dev == 12) return ((dev_t) 2);   /* rsd2 -> sd2 */
    if (dev == 13) return ((dev_t) 3);   /* rsd3 -> sd3 */
    if (dev == 14) return ((dev_t) 4);   /* rsd4 -> sd4 */
    if (dev == 15) return ((dev_t) 5);   /* rsd5 -> sd5 */
    if (dev == 16) return ((dev_t) 6);   /* rsd6 -> sd6 */
    if (dev == 17) return ((dev_t) 7);   /* rsd7 -> sd7 */
    return ((dev_t)NODEV);
}
