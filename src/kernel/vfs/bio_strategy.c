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
 * THE DEVICE NUMBER IS AN INDEX.
 *
 * b_dev is a device INDEX into the kernel's device table, in the single-major
 * dev_t space spec_vnops.c describes (FGX has no bdevsw; major(dev) is a
 * constant and minor(dev) is the index).  ufs_strategy fills it in from the
 * inode's i_devvp (ufs_vnops.c), and bgetvp sets it from v_rdev or to NODEV
 * (vfs_bio.c).  A buffer that reaches here still holding NODEV is a bug in the caller, not a
 * default to paper over: NODEV is 0xFFFF and would index far off the end of a
 * device table with a handful of entries.  It is rejected as an error.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"

/* The block layer, reached through the kernel-C seam (src/kernel/far/kc_sys.s).
 *   kc_blkio(dev, blkhi, blklo, addr, isread) -> 0 on success, else errno.
 * It is sleep-free by construction: SmartPort PIO spins, and the RAM disk
 * copies.  tools/check_fs_sleep_invariant.py holds both this file and kc_sys.s
 * to that. */
extern int kc_blkio();

/* In vfs_bio.c, which is compiled beside this file into the same bank. */
extern void biodone();

#define DEV_BLKSIZE     512
#define DEVB_PER_FSB    (FS_BLKSIZE / DEV_BLKSIZE)

void
bio_strategy(bp)
    struct buf *bp;
{
    daddr_t dblk;
    int     i;
    int     rc;
    int     isread;

    if (bp->b_dev == NODEV) {
        /* No device was ever filled in.  Fail the buffer rather than issuing
         * I/O to index 0xFFFF; brelse turns B_ERROR into B_INVAL, so it will
         * not be served to anyone as a hit. */
        bp->b_error = EIO;
        bp->b_flags |= B_ERROR;
        biodone(bp);
        return;
    }

    isread = 0;
    if (bp->b_flags & B_READ)
        isread = 1;

    dblk = bp->b_blkno * (daddr_t)DEVB_PER_FSB;

    for (i = 0; i < DEVB_PER_FSB; i++) {
        /* &bp->b_addr[n], not b_addr + n: the arena is in a different bank
         * from this code, and pointer arithmetic has dropped the bank byte in
         * this compiler before. */
        rc = kc_blkio((int)bp->b_dev,
                      (int)(dblk >> 16),
                      (int)dblk,
                      &bp->b_addr[i * DEV_BLKSIZE],
                      isread);
        if (rc != 0) {
            /* A failed SECOND transfer leaves a torn 1024-byte block on disk.
             * That is worth knowing rather than hiding: the buffer is marked
             * B_ERROR so nothing reads it back as good, but the on-disk half
             * write has already happened and only fsck will see it. */
            bp->b_error = rc;
            bp->b_flags |= B_ERROR;
            break;
        }
        dblk = dblk + (daddr_t)1;
    }

    biodone(bp);
}
