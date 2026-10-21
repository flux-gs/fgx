/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/pdp/conf.c, usr/sys/sys/ufs_bio.c
 *   The block device switch is ported from usr/sys/pdp/conf.c and its call
 *   from usr/sys/sys/ufs_bio.c, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* bio_strategy.c -- the kernel's disk, under the buffer cache.
 *
 * vfs_bio.c calls this and declares it extern; the unit fixture supplies a
 * fake in its place.  This is the real one.  It BECOMES VOP_STRATEGY once
 * vnodeops exist in 1.4/1.5 -- the call sites are already in the right places
 * and only the spelling changes.
 *
 *----------------------------------------------------------------------------
 * IT IS SYNCHRONOUS, AND THAT IS THE WHOLE DESIGN.
 *
 * It performs the transfer and calls biodone BEFORE RETURNING, so B_DONE is
 * set by the time biowait looks.  biowait's sleep is therefore unreachable,
 * which is what keeps every sleep in this filesystem ABOVE the block driver:
 * the remaining ones are buffer LOCK waits, not disk waits.  Blk_Read and
 * Blk_Write consequently never have to become blocking, and the legacy FS
 * layer's shared singletons stay safe exactly as they are.
 *
 * If this ever becomes asynchronous, that argument collapses in one step and
 * takes the no-sleep invariant with it.  It is cheap to keep: SmartPort PIO is
 * synchronous at the hardware, so there is nothing to wait for.
 *
 *----------------------------------------------------------------------------
 * TWO TRANSFERS PER CALL.
 *
 * The filesystem block is FS_BLKSIZE (1024) and the device block is 512, so
 * every strategy call is two device transfers at 2*b_blkno and 2*b_blkno+1.
 * The block number is a 32-bit daddr_t and is handed over as two 16-bit halves
 * because that is the block layer's interface.
 *
 * THE HIGH WORD MUST BE SET AGAIN FOR THE SECOND TRANSFER.  Blk_Read and
 * Blk_Write latch _blkNumHi and ZERO it in the same breath -- that self-clean
 * is what lets sixteen-bit callers stay correct without an audit, and it means
 * a caller that sets the high word once and issues two operations sends the
 * second one to the wrong place.  kc_blkio takes both halves per call for
 * precisely this reason; there is no way to set it once here.
 *
 *----------------------------------------------------------------------------
 * THE DEVICE NUMBER IS A MAJOR AND A MINOR, AND bdevsw IS INDEXED BY THE MAJOR.
 *
 * This is 2.11BSD's block device switch (usr/sys/h/conf.h, usr/sys/pdp/
 * conf.c:174) and its one call, `(*bdevsw[major(dev)].d_strategy)(bp)'
 * (usr/sys/sys/ufs_bio.c:38), which is bio_strategy below.  ufs_strategy fills
 * b_dev from the inode's i_devvp (ufs_vnops.c), and bgetvp sets it from v_rdev
 * or to NODEV (vfs_bio.c).  A buffer that reaches here still holding NODEV is a
 * bug in the caller, not a default to paper over: NODEV's major is past the
 * table, so it is getmdev's ENXIO (ufs_mount.c:346) like any other.
 *
 * EACH DRIVER OWNS A SLICE OF THE KERNEL'S DEVICE TABLE, and its unit is a row
 * there.  The table is what the block layer
 * (src/drivers/block) indexes, so kc_blkio takes a ROW: sd units are rows 0..7
 * in the order the SmartPort scan found them, the RAM disk is row 8, and
 * SmartPort CD-ROMs are rows 9..12.  The
 * slices are BDEV_SD_ROW0/BDEV_NSD and BDEV_RAM_ROW in include/fs.s, which
 * the scan and ramdisk.mod register against; the two copies are equal by
 * hand.  A unit in range whose row holds no device fails its transfer with EIO
 * in the block layer, which is where "nothing attached there" is known.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"

/* The block layer, reached through the kernel-C seam (src/kernel/far/kc_sys.s).
 *   kc_blkio(row, blkhi, blklo, addr, isread) -> 0 on success, else errno.
 * It is sleep-free by construction: SmartPort PIO spins, and the RAM disk
 * copies.  tools/check_fs_sleep_invariant.py holds both this file and kc_sys.s
 * to that. */
extern int kc_blkio();

/* In vfs_bio.c, which is compiled beside this file into the same bank. */
extern void biodone();

#define DEV_BLKSIZE     512
#define DEVB_PER_FSB    (FS_BLKSIZE / DEV_BLKSIZE)

/* The block device switch, indexed by major: 2.11BSD's struct bdevsw with
 * each driver's slice of the device table where its function pointers would
 * be.  Every FGX block driver reaches the disk through the same kc_blkio, so
 * the drivers differ only in WHICH ROWS are theirs -- and vfs.mod's bank has
 * no room for a strategy routine per driver that would say so in code.  The
 * rows are include/fs.s's BDEV_* slices; the two copies are equal by hand. */
struct bdevsw {
    char    d_row0;             /* the driver's unit 0 */
    char    d_nunit;            /* how many units it has */
    char    d_flags;            /* D_RDONLY */
};
#define D_RDONLY        1       /* a write is EROFS, as NetBSD's cdstrategy
                                 * answers one (sys/scsi/cd.c:369) */

struct bdevsw bdevsw[NBLKDEV] = {
    { 0, 8, 0 },                /* sd = 0: BDEV_SD_ROW0, BDEV_NSD */
    { 8, 1, 0 },                /* ram = 1: BDEV_RAM_ROW */
    { 9, 4, D_RDONLY },         /* cd = 2: BDEV_CD_ROW0, BDEV_NCD */
};

/* bio_strategy -- `(*bdevsw[major(dev)].d_strategy)(bp)', with the one
 * strategy every driver shares inlined: the unit becomes a row, and the row
 * gets two 512-byte transfers.  THE HIGH WORD MUST BE SET AGAIN FOR THE SECOND
 * TRANSFER: see the header. */
void
bio_strategy(bp)
    struct buf *bp;
{
    struct bdevsw *d;
    daddr_t dblk;
    int     i;
    int     rc;
    int     isread;

    /* NODEV is 0xFFFF, so its major is past the table too: a buffer no
     * device was ever filled in for fails here with the rest.  brelse turns
     * B_ERROR into B_INVAL, so it will not be served to anyone as a hit. */
    rc = ENXIO;
    if (major(bp->b_dev) >= NBLKDEV)
        goto out;
    d = &bdevsw[major(bp->b_dev)];
    if (minor(bp->b_dev) >= d->d_nunit)
        goto out;

    isread = 0;
    if (bp->b_flags & B_READ)
        isread = 1;
    rc = EROFS;
    if (!isread && (d->d_flags & D_RDONLY))
        goto out;

    dblk = bp->b_blkno * (daddr_t)DEVB_PER_FSB;

    for (i = 0; i < DEVB_PER_FSB; i++) {
        /* &bp->b_addr[n], not b_addr + n: the arena is in a different bank
         * from this code, and pointer arithmetic has dropped the bank byte in
         * this compiler before. */
        rc = kc_blkio(d->d_row0 + minor(bp->b_dev),
                      (int)(dblk >> 16),
                      (int)dblk,
                      &bp->b_addr[i * DEV_BLKSIZE],
                      isread);
        if (rc != 0) {
            /* A failed SECOND transfer leaves a torn 1024-byte block on disk.
             * That is worth knowing rather than hiding: the buffer is marked
             * B_ERROR so nothing reads it back as good, but the on-disk half
             * write has already happened and only fsck will see it. */
            break;
        }
        dblk = dblk + (daddr_t)1;
    }
out:
    if (rc != 0) {
        bp->b_error = rc;
        bp->b_flags |= B_ERROR;
    }
    biodone(bp);
}
