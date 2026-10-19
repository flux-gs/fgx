/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 2.11BSD usr/sys/sys/ufs_alloc.c
 *   Ported from usr/sys/sys/ufs_alloc.c, 2.11BSD.  Original work:
 *   Copyright (c) 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* ufs_alloc.c -- the 2.11BSD block and inode allocators.  UFS 1.10b.
 *
 * THE FREE LIST IS A CHAIN, NOT A BITMAP, and everything odd about this file
 * follows from that.  The superblock caches NICFREE (50) block addresses.
 * Allocation pops one off the top.  When the cache empties, the address popped
 * LAST is not an ordinary block: it holds the next fifty, so reading it
 * refills the cache and hands the block itself to the caller.  Freeing
 * reverses it -- when the cache is full, the block being freed becomes the
 * container for the current fifty and the cache resets to empty.
 *
 * So a chain block is on the free list AND is the list, its contents matter
 * only until it is allocated, and there is no separate metadata to keep
 * consistent.  That is v7's design, unchanged in 2.11BSD, and it is why FFS's
 * cylinder groups are not here: the campaign's format is 2.11BSD's.
 *
 * THE INODE CACHE IS THE SAME IDEA WITH NO CHAIN.  The superblock caches up to
 * NICINOD (100) free inode numbers, ialloc pops one, and when they run out it
 * SCANS the i-list for more.  Freeing pushes one back and simply drops it if
 * the cache is full -- an inode is not lost by that, only forgotten, and the
 * next scan finds it again.  fs_lasti and fs_nbehind are what stop the scan
 * starting from block 2 every time.
 *
 *============================================================================
 * WHAT THIS PORT DOES NOT HAVE YET, STATED HERE RATHER THAN DISCOVERED LATER.
 *
 *   NO INODE.  2.11BSD's balloc/ialloc/free/ifree all take a `struct inode *`
 *   and reach through it for `i_fs` and `i_dev`.  The in-core inode arrives
 *   with 1.11 and the mount that would own the superblock arrives with 1.8, so
 *   these take the device vnode and the superblock directly.  That is Reno's
 *   shape rather than 2.11BSD's in one respect too -- ufs_balloc returns a
 *   BLOCK NUMBER, where 2.11BSD's returns a `struct buf *` it has already
 *   getblk'd and optionally cleared.  bmap (1.10c) wants the number.
 *
 *   THE ifind GUARDS LANDED AT 1.11a (apple/fgx#168) and are described at the
 *   two sites in ufs_ialloc.  What 1.10b said about them was right and has
 *   expired: with no in-core inode table there was exactly one path by which an
 *   inode could be allocated, so the cache could not go stale.  1.11a's iget
 *   made it possible, and both guards went in the same day the table did.
 *
 *   NO CLOCK, so ufs_sbupdate cannot stamp fs_time -- see its comment and
 *   apple/fgx#167.
 *
 * WHAT IS NOT MISSING, because it would be easy to assume it is: the on-disk
 * lock bytes ARE honoured.  fs_flock and fs_ilock guard the windows where this
 * code does I/O with the in-core lists inconsistent, and kc_sleep/kc_wakeup
 * exist for precisely this (vfs_bio.c uses them for buffer locks).  Dropping
 * them would have been a silent bet that nothing else ever allocates
 * concurrently, and 1.12 breaks that bet.
 */

#include "fsparam.h"
#include "vnode.h"
#include "specdev.h"    /* v_rdev: ufs_ifind is keyed by device number */
#include "buf.h"
#include "ufs_fs.h"
#include "inode.h"

extern int          bread();
extern int          bwrite();
extern void         brelse();
extern struct buf  *getblk();
extern void         kc_sleep();
extern void         kc_wakeup();
extern void         ufs_fblkdecode();
extern void         ufs_fblkencode();
extern int          ufs_sbupdate();
extern struct inode *ufs_ifind();


/* ufs_badblock -- is this address on the volume's data area at all?
 *
 * 2.11BSD ufs_subr.c:106.  A block below sb_isize is inside the i-list or the
 * superblock, one at or above sb_volblocks is off the end of the disk, and
 * either handed to the free list would eventually be given out as a data
 * block.  Returns 1 for bad, matching upstream's sense, which reads backwards
 * at the call sites and is kept because the call sites are ported too.
 *
 * Upstream also prints; this returns silently.  There is no fserr here (it
 * formats a mount point name this port does not carry) and nothing above these
 * functions yet to route a message to. */
int
ufs_badblock(sb, bno)
struct ufs_sb *sb;
daddr_t bno;
{
    if (bno < (daddr_t)sb->sb_isize || bno >= sb->sb_volblocks)
        return (1);
    return (0);
}


/* ufs_balloc -- take one block off the free list.  2.11BSD's balloc.
 *
 * THE do/while AROUND THE POP IS NOT A RETRY FOR ITS OWN SAKE.  Upstream
 * writes it as `do { ... } while (badblock(fs, bno));` -- a bad address on the
 * list is skipped and the next one taken, so one corrupt entry costs a block
 * rather than the filesystem.  The loop can only end two ways because every
 * pass either returns or shortens the cache.
 *
 * THE ORDER OF THE THREE REFUSALS IS LOAD-BEARING.  `nfree <= 0` is the empty
 * list; `nfree > NICFREE` is upstream's "bad free count", a count that would
 * index past the array -- checked BEFORE the subscript, not after; `bno == 0`
 * is the terminator mkfs writes at the very bottom, and reaching it means the
 * volume is genuinely full rather than corrupt.
 */
int
ufs_balloc(devvp, sb, resultbno)
struct vnode  *devvp;
struct ufs_sb *sb;
daddr_t       *resultbno;
{
    struct buf *bp;
    daddr_t     bno;
    int         error;

    while (sb->sb_flock)
        kc_sleep((char *)&sb->sb_flock);

    for (;;) {
        if (sb->sb_nfree <= 0)
            goto nospace;
        if (sb->sb_nfree > NICFREE)
            goto nospace;               /* upstream's "bad free count" */
        sb->sb_nfree--;
        bno = sb->sb_free[sb->sb_nfree];
        if (bno == (daddr_t)0)
            goto nospace;
        if (!ufs_badblock(sb, bno))
            break;
    }

    /* THE CACHE JUST EMPTIED, SO THE BLOCK WE POPPED IS THE NEXT BATCH.  Read
     * it, refill from it, and hand the container itself to the caller.
     *
     * The superblock goes back to disk here and upstream explains why in a
     * comment worth keeping: written synchronously "so that the free list
     * pointer won't point at garbage".  Blocks have already been handed out
     * from the batch this read replaced; if the machine stops before the head
     * moves on disk, the next mount walks a list whose front is gone. */
    if (sb->sb_nfree <= 0) {
        sb->sb_flock = 1;
        error = bread(devvp, bno, &bp);
        if (error == 0)
            ufs_fblkdecode(bp->b_addr, sb);
        brelse(bp);

        /* fs_fmod is cleared BEFORE the write, not after: the flag means "the
         * in-core copy is ahead of the disk", and it stops being true at the
         * moment the encode reads it. */
        sb->sb_fmod = 0;
        (void)ufs_sbupdate(devvp, sb);
        sb->sb_flock = 0;
        kc_wakeup((char *)&sb->sb_flock);

        /* A FAILED CHAIN READ ARRIVES HERE AS AN EMPTY LIST, which is
         * upstream's behaviour and not an oversight: the decode was skipped,
         * so nfree is still 0 and this is the same refusal as a genuinely full
         * volume.  It means an I/O error on the free list reports ENOSPC
         * rather than EIO.  Kept, because diverging would put this port's
         * failure mode out of step with the format's own fsck. */
        if (sb->sb_nfree <= 0)
            goto nospace;
    }

    sb->sb_fmod = 1;
    sb->sb_tfree--;
    *resultbno = bno;
    return (0);

nospace:
    /* Upstream zeroes both counts here, and it looks destructive until you see
     * what it is for: it makes the next call fail immediately instead of
     * re-walking a list already known to be exhausted or corrupt.
     *
     * IT DOES NOT RELEASE sb_flock, and that is not an omission.  Every path
     * that reaches this label has the lock clear already -- the pop loop runs
     * before it is taken, and the refill arm drops it before its own test.
     * Clearing it here would look tidier and would be a wakeup on a channel
     * this call does not hold. */
    sb->sb_nfree = 0;
    sb->sb_tfree = (daddr_t)0;
    return (ENOSPC);
}


/* ufs_bfree -- put one block back.  2.11BSD's free().
 *
 * THE `nfree <= 0` ARM IS NOT THE SAME AS THE SPILL ARM and it is easy to read
 * as dead code.  An empty cache means the chain has no head, so pushing an
 * address onto it would produce a list with no terminator: the next drain
 * would run off the end of the chain into whatever the last container held.
 * Seeding free[0] = 0 restores the terminator mkfs wrote.  Upstream has this;
 * mkfs.c's own bfree does NOT, because mkfs calls bfree(0) first and never
 * empties the cache after -- which is why tools/fgxfs.py's bfree, ported from
 * mkfs.c, has no such arm.  The two are not in conflict; they are the same
 * algorithm entered from different states.
 */
int
ufs_bfree(devvp, sb, bno)
struct vnode  *devvp;
struct ufs_sb *sb;
daddr_t        bno;
{
    struct buf *bp;
    int         error;

    if (ufs_badblock(sb, bno))
        return (EINVAL);

    while (sb->sb_flock)
        kc_sleep((char *)&sb->sb_flock);

    if (sb->sb_nfree <= 0) {
        sb->sb_nfree = 1;
        sb->sb_free[0] = (daddr_t)0;
    }

    /* THE CACHE IS FULL, SO THIS BLOCK BECOMES THE CONTAINER FOR IT.  getblk
     * rather than bread is right here and wrong in ufs_sbupdate: this block is
     * being overwritten as a chain block, so its previous contents are
     * irrelevant and reading them would be a wasted revolution.
     *
     * ONLY THE FIRST 202 BYTES ARE WRITTEN.  A chain block is 2 + 50 * 4
     * bytes; the other 822 are whatever getblk handed over.  Upstream has the
     * same hole -- `*fbp = *((FBLKP)&fs->fs_nfree)` copies sizeof(struct fblk)
     * and no more -- and it is harmless because the block is on the free list
     * and ufs_balloc's caller clears it before use.  Noted because
     * tools/fgxfs.py zeroes the whole block instead, so a byte-for-byte
     * comparison of a container written by the two tools will differ in the
     * tail while both are correct. */
    if (sb->sb_nfree >= NICFREE) {
        sb->sb_flock = 1;
        bp = getblk(devvp, bno);
        ufs_fblkencode(sb, bp->b_addr);
        sb->sb_nfree = 0;
        error = bwrite(bp);
        sb->sb_flock = 0;
        kc_wakeup((char *)&sb->sb_flock);
        if (error)
            return (error);
    }

    sb->sb_free[sb->sb_nfree] = bno;
    sb->sb_nfree++;
    sb->sb_tfree++;
    sb->sb_fmod = 1;
    return (0);
}


/* ufs_ialloc -- take one inode number off the cache, scanning if it is empty.
 * 2.11BSD's ialloc, minus the iget/ifind rechecks named at the top of this
 * file.
 *
 * WHY THE SCAN IS CIRCULAR RATHER THAN FROM THE TOP.  Restarting at inode 1
 * every time is O(i-list) per hundred allocations, and on a volume whose low
 * inodes are all in use it re-reads the same full blocks forever.  fs_lasti
 * remembers where the last scan stopped so the next one continues there.
 * fs_nbehind is the estimate that makes it safe: ifree counts the frees that
 * happened BELOW lasti, and once that estimate passes 4 * NICINOD the scan
 * starts from the top again to pick them up.  `first` carries whether this
 * attempt began mid-list, so a mid-list scan that comes up short falls back to
 * a full one rather than reporting a full filesystem.
 */
int
ufs_ialloc(devvp, sb, resultino)
struct vnode  *devvp;
struct ufs_sb *sb;
ino_t         *resultino;
{
    struct buf *bp;
    daddr_t     adr;
    ino_t       ino;
    ino_t       inobas;
    int         first;
    int         i;
    int         error;
    int         taken;
    dev_t       dev;

    /* Upstream reaches through `pip` for i_dev; this port has the device vnode
     * instead, and v_rdev is the same number by the same name. */
    dev = devvp->v_rdev;

    while (sb->sb_ilock)
        kc_sleep((char *)&sb->sb_ilock);

loop:
    /* INODES 1 AND 2 ARE NEVER HANDED OUT.  2 is the root; 1 is a historical
     * hack -- bad blocks were once linked to it and dump tapes still assume it
     * exists, so mkfs marks it allocated.  Upstream's test is `ino <= ROOTINO`
     * and it sits on the POP side rather than in the scan, so both numbers can
     * enter the cache and are discarded on the way out. */
    while (sb->sb_ninode > 0) {
        sb->sb_ninode--;
        ino = sb->sb_inode[sb->sb_ninode];
        /* THE POST-POP RECHECK (2.11BSD ufs_alloc.c:163-178, apple/fgx#168).
         * The cache was filled by a scan that read the i-list at some earlier
         * moment.  Between then and now the number may have been handed out,
         * and the i-list will not say so: an inode allocated in core has not
         * been written yet, so its on-disk di_mode is still 0.  The IN-CORE
         * TABLE is the only record of that, which is what ufs_ifind reads.
         *
         * Upstream spells this as `iget` then `if (ip->i_mode == 0)`, taking
         * the inode and putting it back with iput if the mode says otherwise.
         * It can, because upstream's ialloc RETURNS the inode -- so it wants
         * one in hand anyway.  This one returns a NUMBER (see the note at the
         * head of this file), so a bare ufs_ifind asks the same question
         * without minting a vnode and immediately releasing it. */
        if (ino <= (ino_t)UFS_ROOTINO)
            continue;
        if (ufs_ifind(dev, ino) != (struct inode *)0)
            continue;               /* spoken for in core */

        /* ...AND FREE ON THE PLATTER.  Upstream's recheck is `iget` then
         * `if (ip->i_mode == 0)`, and iget BREADS the i-list block
         * (vendor/2.11BSD/usr/sys/sys/ufs_inode.c:198) -- so the mode it tests
         * is the DISK's whenever the inode is not already in core.  A bare
         * ufs_ifind covers only the stale IN-CORE case, and the two are not the
         * same question.
         *
         * The one it misses is a stale ON-DISK cache: a crash between the
         * moment an allocated di_mode reached the platter and the moment the
         * superblock was written leaves sb_inode[] naming a number the i-list
         * has already given away.  On remount nothing is in core, so ifind says
         * free and the number goes out a second time -- two files cross-linked
         * on one inode, silently.  fsck would repair the volume, but nothing
         * here would refuse it.
         *
         * Same two-byte test the scan below uses, for the reason given there:
         * di_mode is the first field and 16 bits, so it overlays this machine
         * directly.  This costs a bread per allocation, which is what upstream
         * pays for its iget. */
        error = bread(devvp, itod(ino), &bp);
        if (error) {
            brelse(bp);
            return (error);
        }
        taken = (bp->b_addr[itoo(ino) * UFS_DINODESIZE] != 0 ||
                 bp->b_addr[itoo(ino) * UFS_DINODESIZE + 1] != 0);
        brelse(bp);
        if (taken)
            continue;               /* the cache was stale; keep looking */

        sb->sb_fmod = 1;
        sb->sb_tinode--;
        *resultino = ino;
        return (0);
    }

    sb->sb_ilock = 1;

    /* SEEDED, WHERE UPSTREAM LEAVES IT UNINITIALISED.  `fs_lasti = inobas`
     * below runs unconditionally, but inobas is only assigned inside the block
     * loop, so a scan whose first block address already sits past the end of
     * the i-list would store a garbage restart point.  It cannot happen on a
     * superblock ufs_sbvalid has passed -- itod of any valid inode is below
     * sb_isize -- which is presumably why it has never bitten upstream.  One
     * word of divergence is cheaper than that argument holding forever. */
    inobas = (ino_t)1;

    if (sb->sb_nbehind < (ino_t)(4 * NICINOD)) {
        first = 1;
        ino = sb->sb_lasti;
        adr = itod(ino);
    } else {
fromtop:
        first = 0;
        ino = (ino_t)1;
        adr = (daddr_t)(UFS_SBLOCK + 1);
        sb->sb_nbehind = 0;
    }

    for (; adr < (daddr_t)sb->sb_isize; adr++) {
        inobas = ino;
        error = bread(devvp, adr, &bp);
        if (error) {
            brelse(bp);
            ino += INOPB;
            continue;
        }

        /* di_mode IS THE FIRST FIELD OF A DINODE and it is 16 bits, so it is
         * the one on-disk field readable without a decoder: a short overlays
         * this machine directly, only longs need the half-swap.  A dinode is
         * 64 bytes (inode.h, measured on a live PDP-11 and pinned by
         * toolchain/tests/M37/pdplayout.c) and mode 0 means the slot is free.
         * The full decode arrives with 1.11; this needs one field. */
        for (i = 0; i < INOPB; i++) {
            /* A FREE SLOT ON DISK IS NOT A FREE INODE.  The second test is
             * 2.11BSD ufs_alloc.c:208-209 (`if (ifind(pip->i_dev, ino)) goto
             * cont;`) and it is what stops the scan re-caching a number that
             * has already been handed out but not yet written -- the exact
             * shape apple/fgx#168 was filed for.  Order matters and is
             * upstream's: the cheap byte test first, the table walk only for
             * slots that look free. */
            if (bp->b_addr[i * UFS_DINODESIZE] == 0 &&
                bp->b_addr[i * UFS_DINODESIZE + 1] == 0 &&
                ufs_ifind(dev, ino) == (struct inode *)0) {
                sb->sb_inode[sb->sb_ninode] = ino;
                sb->sb_ninode++;
                /* NO ino++ ON THIS PATH, deliberately: upstream breaks out of
                 * the slot loop before its `cont:` label, leaving ino naming
                 * the slot just taken.  It does not matter to the cache, which
                 * is already full, but it is the shape upstream has. */
                if (sb->sb_ninode >= NICINOD)
                    break;
            }
            ino++;
        }
        brelse(bp);
        if (sb->sb_ninode >= NICINOD)
            break;
    }

    /* THE PARTIAL CACHE IS THROWN AWAY BEFORE THE FULL RESCAN, and that one
     * line is 2.11BSD PATCH 433 (2000-10-17).  vendor/2.11BSD/ is a ~1999
     * snapshot, four patches short of it, so this port inherited the defect
     * verbatim -- see vendor/2.11BSD/usr/sys/sys/ufs_alloc.c:222, which has the
     * bare `goto fromtop' this used to have.  apple/fgx#278.
     *
     * Upstream's own words for what goes wrong, from the comment the patch adds
     * beside the fix:
     *
     *   "If some inodes have been found but not NICINOD of them the intent was
     *    to go back and scan the inode list from the beginning and add new
     *    inodes to fs_inode[].  On filesystems with few free inodes this had
     *    the unfortunate side effect of finding the inodes we already knew
     *    about!  The resulting duplicates caused fs_ninode to be higher than it
     *    should have been.  Part of the allocation logic said there were inodes
     *    available (fs_ninode > 0) while `fs_tinode = 0' meant there were none!
     *
     *    Since we're going to scan from the beginning simply toss away any
     *    inodes already found.  Either NICINOD or all available inodes will be
     *    found."
     *
     * NOTHING IS LOST BY DISCARDING THEM: the scan that follows starts at inode
     * 1 and covers everything the partial scan did.
     *
     * IT MATTERS MORE HERE THAN ON A PDP-11.  The trigger is a filesystem with
     * fewer than NICINOD (100) free inodes, which upstream calls the unusual
     * case -- "the number of inodes on the disk is much higher than 512".
     * FGX's volumes are the opposite way round: disk/fgxdev.po has SIXTEEN
     * inodes in total, small volumes are the normal case on a IIgs, and every
     * volume enters this state as it fills. */
    if (sb->sb_ninode < NICINOD && first) {
        sb->sb_ninode = 0;
        goto fromtop;
    }

    sb->sb_lasti = inobas;
    sb->sb_ilock = 0;
    kc_wakeup((char *)&sb->sb_ilock);
    if (sb->sb_ninode > 0)
        goto loop;
    return (ENOSPC);
}


/* ufs_ifree -- give an inode number back.  2.11BSD's ifree.
 *
 * IT CAN THROW THE NUMBER AWAY AND THAT IS CORRECT.  If the cache is full, or
 * a scan is in progress and would be confused by a concurrent push, the number
 * is simply not recorded -- the inode is still free on disk, and the next scan
 * finds it.  What must NOT be lost is fs_tinode, which is why it is
 * incremented before either early return.
 *
 * The nbehind bump is the other half of the circular scan: a free below the
 * scan's restart point is one the next mid-list scan cannot see, so it is
 * counted, and enough of them send the scan back to the top.
 */
void
ufs_ifree(sb, ino)
struct ufs_sb *sb;
ino_t          ino;
{
    sb->sb_tinode++;
    if (sb->sb_ilock)
        return;
    if (sb->sb_ninode >= NICINOD) {
        if (sb->sb_lasti > ino)
            sb->sb_nbehind++;
        return;
    }
    sb->sb_inode[sb->sb_ninode] = ino;
    sb->sb_ninode++;
    sb->sb_fmod = 1;
}
