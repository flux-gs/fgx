/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/vfs_bio.c
 *   Ported from kern/vfs_bio.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* vfs_bio.c -- the FGX buffer cache: the pool, its hash chains, its free
 * lists, the I/O path, and the vnode block lists that make it an index of
 * files rather than only a pool of blocks.
 *
 * Ported from 4.3BSD-Reno kern/vfs_bio.c, with 2.11BSD as the guide wherever
 * Reno assumes a machine FGX is not.  What that means concretely:
 *
 * FIXED-SIZE BUFFERS.  Reno's buffers are variable-size and grown on demand by
 * brealloc/allocbuf out of the VM system.  FGX has no VM system, and 2.11BSD's
 * buffers are fixed at one filesystem block, so these are too: NBUF buffers of
 * FS_BLKSIZE, carved once from a static arena.  brealloc, bfree, b_bufsize and
 * the BQ_EMPTY free list all go with it -- a buffer always has its memory, so
 * there is no such thing as an empty one, and getblk's "stray size" retry
 * cannot arise because every buffer is the same size by construction.
 *
 * THREE FREE LISTS, not four.  BQ_LOCKED, BQ_LRU and BQ_AGE survive.  2.11BSD
 * notes in its own buf.h that it never uses BQ_LOCKED or BQ_EMPTY; BQ_LOCKED
 * is kept because a buffer pinned in core is a real state here (the legacy
 * block layer already pins), and BQ_EMPTY is dropped as above.
 *
 * KEYED BY (b_vp, b_lblkno).  That is the point of replacing the legacy
 * device-keyed cache: a vnode-keyed cache can enumerate every buffer belonging
 * to a file, which is what makes fsync, truncate and invalidate-on-unmount
 * possible at all.
 *
 * WHERE IT SLEEPS, AND WHY THAT IS THE WHOLE DESIGN.  Reno's vfs_bio sleeps in
 * five places: getblk on a busy buffer, getnewbuf on an empty free list,
 * biowait on I/O completion, and vflushbuf/vinvalbuf on both.  Every one of
 * those except biowait is a BUFFER LOCK WAIT and sits ABOVE the block driver.
 * biowait is the only one that waits on the disk, and on this machine it never
 * waits at all: FGX's disk I/O is synchronous SmartPort PIO, so the transfer is
 * already finished when the driver returns and B_DONE is set before biowait is
 * ever called.
 *
 * That is not an incidental saving.  It means Blk_Read/Blk_Write never become
 * able to block, so the legacy FS layer's sixty-odd shared singletons stay safe
 * exactly as they are, and tools/check_fs_sleep_invariant.py keeps passing
 * permanently instead of being a tripwire waiting to be disarmed.  The price is
 * one rule, and it is a rule rather than a mechanism: A DEVICE IS CACHED BY
 * EXACTLY ONE STACK, legacy blkcache or this one, never both -- two caches over
 * one device would hold the same block twice with no coherence between them.
 */

#include "fsparam.h"
#include "vnode.h"
#include "specdev.h"
#include "buf.h"

/* Free-list heads.  Reno uses a `struct buf` as each head so the same insq/remq
 * macros work on heads and members alike; the head's av_forw/av_back are the
 * list and nothing else in it is read.  Keeping that costs a few bytes per list
 * and keeps the list handling identical to the source. */
#define BQ_LOCKED   0           /* pinned in core, never reclaimed */
#define BQ_LRU      1           /* valid, reclaim oldest first */
#define BQ_AGE      2           /* valid but not worth keeping */
#define BQ_COUNT    3

struct buf bfreelist[BQ_COUNT];

/* The hash chains.  Reno's BUFHASH mixes the vnode pointer with the logical
 * block; the pointer is 4 bytes here and its low bits are the ones that vary,
 * so the mix uses those.  BUFHASHSZ is a power of two so the modulo is a mask.
 */
#define BUFHASHSZ   16
#define BUFHASHMASK (BUFHASHSZ - 1)

struct buf bufhash[BUFHASHSZ];

/* The buffers themselves.  The headers are small and the arena is not, which
 * is exactly why struct buf does not embed its block: the two are placed
 * independently, and only the arena needs a bank of its own.
 *
 * THE ARENA IS NOT DECLARED HERE.  It used to be `char bufarena[NBUF *
 * FS_BLKSIZE]`, which made 16 KB of zero-initialised data part of this
 * translation unit and therefore part of whichever bank the unit lands in.
 * That is a quarter of the far bank, the only expansion bank there is, spent
 * on storage that has no reason to sit beside code -- and the far bank is
 * where the rest of the VFS has to go.  bufinit takes the base address
 * instead, so the kernel hands it heap and the unit fixture hands it a static
 * array, and neither choice is baked in here. */
struct buf buf[NBUF];

/* Supplied by the kernel; stubbed by the unit fixture.  Declared rather than
 * included so this file does not drag the whole kernel header set into a test
 * that only needs the list logic. */
extern void kc_sleep();
extern void kc_wakeup();
extern void kc_panic();

/* Forward declarations, K&R style.  getblk and getnewbuf both reach the vnode
 * association below them, and without these the calls would take the implicit
 * int return that pre-prototype C gives an unseen function -- which then
 * conflicts with the void definitions further down. */
void bgetvp();
void brelvp();
void reassignbuf();
int  bwrite();
int  biowait();
void biodone();

/* THE DISK IS REACHED THROUGH THE VNODE.
 *
 * This layer no longer knows what a disk is.  It issues VOP_STRATEGY on the
 * buffer's vnode, and what that reaches depends on what the vnode is: a device
 * vnode reaches spec_strategy and the block driver; a file's vnode will reach
 * its filesystem's strategy, which fills in b_dev from the inode's device
 * vnode and then issues the same call one level down.  That indirection is why
 * this file can serve both without a type test anywhere in it.
 *
 * The contract that makes the design work is unchanged and belongs to whatever
 * is at the end of the chain: it is SYNCHRONOUS.  It performs the transfer and
 * calls biodone before returning, so B_DONE is set before biowait is reached.
 *
 * EVERY VNODE HANDED TO getblk MUST CARRY A VECTOR.  Before this, a bare
 * struct vnode with nothing but a type was enough, because the call was to
 * bio_strategy by name; now it goes through v_op, and a null vector is a call
 * through a null pointer rather than a diagnosable error. */

static int
bufhashof(vp, blkno)
    struct vnode *vp;
    daddr_t blkno;
{
    /* The vnode pointers all come from one static pool, so they differ only in
     * their low bits; shifting the block number left by one keeps consecutive
     * blocks of one file off a single chain without cancelling the vnode. */
    return ((((int)vp >> 2) + (int)blkno) & BUFHASHMASK);
}

/* ---- list primitives, from 2.11BSD's buf.h macros -------------------------
 * Written as functions rather than macros: fcc compiles them the same, and a
 * macro that evaluates its argument four times is the kind of thing that goes
 * wrong quietly when someone passes it an expression.
 */

static void
bremhash(bp)
    register struct buf *bp;
{
    bp->b_back->b_forw = bp->b_forw;
    bp->b_forw->b_back = bp->b_back;
}

static void
binshash(bp, dp)
    register struct buf *bp;
    register struct buf *dp;
{
    bp->b_forw = dp->b_forw;
    bp->b_back = dp;
    dp->b_forw->b_back = bp;
    dp->b_forw = bp;
}

static void
bremfree(bp)
    register struct buf *bp;
{
    bp->av_back->av_forw = bp->av_forw;
    bp->av_forw->av_back = bp->av_back;
}

static void
binsheadfree(bp, dp)
    register struct buf *bp;
    register struct buf *dp;
{
    dp->av_forw->av_back = bp;
    bp->av_forw = dp->av_forw;
    dp->av_forw = bp;
    bp->av_back = dp;
}

static void
binstailfree(bp, dp)
    register struct buf *bp;
    register struct buf *dp;
{
    dp->av_back->av_forw = bp;
    bp->av_back = dp->av_back;
    dp->av_back = bp;
    bp->av_forw = dp;
}

/* ---- the vnode's block list ------------------------------------------------
 *
 * A SINGLY-linked list with a pointer-to-pointer back-link, not the circular
 * doubly-linked lists above.  Reno writes this sequence out by hand in three
 * places -- bgetvp, brelvp and reassignbuf -- and the three copies are where a
 * transcription error would sit undetected, because two of them are only
 * reached on paths a boot test does not take.  One copy each.
 *
 * b_blockb holds the ADDRESS OF the pointer that references this buffer.  For
 * the first buffer that is the vnode's v_cleanblkhd or v_dirtyblkhd; for any
 * other it is the previous buffer's b_blockf.  So the unlink is the same store
 * either way and the head is not a special case -- the same idiom the vnode
 * free list uses, and the same reason it is worth testing on this machine: it
 * takes the address of a field inside an array element, and that is the
 * construct that has dropped a bank byte here before.
 */

static void
bufinsvn(bp, listheadp)
    register struct buf *bp;
    register struct buf **listheadp;
{
    bp->b_blockf = *listheadp;
    bp->b_blockb = listheadp;
    if (bp->b_blockf)
        bp->b_blockf->b_blockb = &bp->b_blockf;
    *listheadp = bp;
}

static void
bufremvn(bp)
    register struct buf *bp;
{
    register struct buf *bq;

    /* A buffer that is on no list at all -- freshly initialised, or already
     * removed -- has a null back-link and is left alone.  brelvp is reached
     * from both brelse and getnewbuf and can see either state. */
    if (bp->b_blockb == 0)
        return;
    if (bq = bp->b_blockf)
        bq->b_blockb = bp->b_blockb;
    *bp->b_blockb = bq;
    bp->b_blockf = 0;
    bp->b_blockb = 0;
}

/* ---- initialisation -------------------------------------------------------
 *
 * Reno's bufinit lives in machdep; this is the same work, done once from the
 * kernel's FS init.  Every buffer starts on BQ_AGE and INVALID: it has memory
 * but no contents, which under fixed-size buffers is the only "empty" state
 * there is.
 */
void
/* arena: NBUF * FS_BLKSIZE bytes, supplied by the caller.  See the note where
 * struct buf buf[] is declared for why it is not a global here. */
bufinit(arena)
char *arena;
{
    register struct buf *bp;
    register struct buf *dp;
    register int i;

    for (i = 0; i < BQ_COUNT; i++) {
        dp = &bfreelist[i];
        dp->av_forw = dp;
        dp->av_back = dp;
    }
    for (i = 0; i < BUFHASHSZ; i++) {
        dp = &bufhash[i];
        dp->b_forw = dp;
        dp->b_back = dp;
    }
    dp = &bfreelist[BQ_AGE];
    for (i = 0; i < NBUF; i++) {
        bp = &buf[i];
        bp->b_flags = B_INVAL;
        bp->b_dev = 0;
        bp->b_vp = 0;
        bp->b_lblkno = 0;
        bp->b_blkno = 0;
        bp->b_bcount = FS_BLKSIZE;
        bp->b_error = 0;
        bp->b_resid = 0;
        /* &arena[n], NOT arena + n.  Pointer arithmetic has dropped the bank
         * byte here before; the address-of-subscript form is the one fcc
         * carries a full 32-bit pointer through, and b_addr must be one -- the
         * arena is in a different bank from this code by design. */
        bp->b_addr = &arena[i * FS_BLKSIZE];
        /* Off any hash chain: b_forw/b_back point at the buffer itself, so a
         * bremhash before the first binshash is a no-op rather than a write
         * through a null pointer. */
        bp->b_forw = bp;
        bp->b_back = bp;
        /* On no vnode's block list.  bufremvn reads b_blockb to decide whether
         * there is anything to unlink, so this null is what makes the first
         * brelvp of a buffer's life a no-op rather than a store through
         * whatever the arena happened to contain. */
        bp->b_blockf = 0;
        bp->b_blockb = 0;
        binstailfree(bp, dp);
    }
}

/* ---- the cache ------------------------------------------------------------ */

/* See if a block is resident, without claiming it.  Reno keeps this so breada
 * can decline to start a read-ahead that would block. */
int
incore(vp, blkno)
    struct vnode *vp;
    daddr_t blkno;
{
    register struct buf *bp;
    register struct buf *dp;

    dp = &bufhash[bufhashof(vp, blkno)];
    for (bp = dp->b_forw; bp != dp; bp = bp->b_forw)
        if (bp->b_lblkno == blkno && bp->b_vp == vp &&
            (bp->b_flags & B_INVAL) == 0)
            return (1);
    return (0);
}

/* Take the oldest reclaimable buffer.  BQ_AGE first -- those are valid but not
 * worth keeping -- then BQ_LRU.  BQ_LOCKED is never a candidate: something
 * holds a live pointer into it.
 *
 * Reno sleeps here when every list is empty.  So does this, and it is a LOCK
 * wait, not an I/O wait: it is woken by brelse putting a buffer back. */
static struct buf *
getnewbuf()
{
    register struct buf *bp;
    register struct buf *dp;

again:
    for (;;) {
        dp = &bfreelist[BQ_AGE];
        if (dp->av_forw == dp)
            dp = &bfreelist[BQ_LRU];
        if (dp->av_forw != dp)
            break;
        /* Every buffer is busy.  Mark the want and wait for a brelse. */
        dp->b_flags |= B_WANTED;
        kc_sleep((char *)dp);
    }
    bp = dp->av_forw;
    bremfree(bp);
    bp->b_flags |= B_BUSY;
    /* A delayed write must reach the disk before its buffer is reused, or the
     * write is simply lost.  bwrite releases the buffer itself, so the scan
     * restarts rather than continuing with a buffer that is no longer ours.
     *
     * This is where a write-back cache pays for itself being lazy, and it is
     * also the one place reclaim can block -- but on a SYNCHRONOUS write it
     * does not: bwrite issues the transfer, biowait finds B_DONE already set,
     * and control returns without ever reaching kc_sleep.  The flush sits
     * ABOVE the block driver either way, which is what keeps Blk_* unable to
     * block and the legacy layer's singletons safe. */
    if (bp->b_flags & B_DELWRI) {
        bwrite(bp);
        goto again;
    }
    if (bp->b_vp)
        brelvp(bp);
    bremhash(bp);
    bp->b_forw = bp;
    bp->b_back = bp;
    bp->b_flags = B_BUSY;
    bp->b_error = 0;
    bp->b_resid = 0;
    return (bp);
}

/* Assign a buffer to (vp, blkno).  If it is already resident, claim it;
 * otherwise recycle the oldest and attach it.
 *
 * Reno's "stray size" arm is gone: every buffer is FS_BLKSIZE by construction,
 * so a resident buffer of the wrong size cannot exist. */
struct buf *
getblk(vp, blkno)
    register struct vnode *vp;
    daddr_t blkno;
{
    register struct buf *bp;
    register struct buf *dp;

    /* THE VECTOR CONTRACT, ENFORCED AT THE BOUNDARY THAT STATES IT.
     *
     * The header above says every vnode handed to getblk must carry a vector,
     * because VOP_STRATEGY reaches the disk through v_op.  It was a comment and
     * nothing else.
     *
     * WHAT A NULL VECTOR WOULD COST, which is why the contract is worth an
     * instruction rather than a paragraph: fcc calls a function pointer by
     * pushing bank and offset-minus-one and returning to it, so a null becomes
     * $FFFF + 1 = $00/0000 rather than an address that faults.  Bank 0 is zeros,
     * $00 is BRK, and nothing installs the native BRK vector at $00:FFE6 -- so
     * the runaway BRK paves bank 0 with its own stack frames and erases the
     * relocation anchor the harness reads.  A null vector does not present as a
     * null vector; it presents as a machine with no screen.
     *
     * NO CALLER IN THIS TREE IS KNOWN TO BREAK THE CONTRACT.  This is a guard on
     * a stated invariant, not a fix for an observed caller: apple/fgx#463 got to
     * $00/0000 by exactly the route above, but its cause was a wild store from
     * net.mod's _Pipe_FreeSlot corrupting the heap, and no run has shown a vnode
     * arriving here without a vector.  Said plainly because the alternative is a
     * comment that reads as evidence.
     *
     * HERE AND NOT AT THE STRATEGY CALL, because this is where the vnode is
     * accepted: the panic then names the caller that handed it over, while a
     * check at VOP_STRATEGY would fire with only the buffer in hand, one or more
     * returns away from whoever is at fault.
     *
     * A fixed string, which is Reno's idiom for the same class:
     * vendor/4.3BSD-Reno/kern/dead_vnops.c:236 is dead_badop() calling
     * panic("dead_badop called") rather than reporting which op. */
    if (vp->v_op == (struct vnodeops *)0)
        kc_panic("getblk: vnode with no vector");

    dp = &bufhash[bufhashof(vp, blkno)];
loop:
    for (bp = dp->b_forw; bp != dp; bp = bp->b_forw) {
        if (bp->b_lblkno != blkno || bp->b_vp != vp ||
            (bp->b_flags & B_INVAL))
            continue;
        if (bp->b_flags & B_BUSY) {
            /* Someone else holds it.  This is the lock wait that makes the
             * cache safe to share, and the reason kernel C had to survive a
             * context switch before any of this could land. */
            bp->b_flags |= B_WANTED;
            kc_sleep((char *)bp);
            goto loop;
        }
        bremfree(bp);
        bp->b_flags |= B_BUSY;
        return (bp);
    }
    bp = getnewbuf();
    bgetvp(vp, bp);
    bp->b_lblkno = blkno;
    bp->b_blkno = blkno;        /* until VOP_BMAP says otherwise */
    binshash(bp, dp);
    return (bp);
}

/* Release a buffer back to a free list, waking anyone who wanted it. */
void
brelse(bp)
    register struct buf *bp;
{
    register struct buf *flist;

    if (bp->b_flags & B_WANTED)
        kc_wakeup((char *)bp);
    if (bfreelist[BQ_AGE].b_flags & B_WANTED) {
        bfreelist[BQ_AGE].b_flags &= ~B_WANTED;
        kc_wakeup((char *)&bfreelist[BQ_AGE]);
    }
    if (bfreelist[BQ_LRU].b_flags & B_WANTED) {
        bfreelist[BQ_LRU].b_flags &= ~B_WANTED;
        kc_wakeup((char *)&bfreelist[BQ_LRU]);
    }

    /* A buffer that failed, or was explicitly invalidated, keeps no contents
     * and loses its vnode -- otherwise the next getblk would find it by key
     * and hand back the wrong bytes. */
    if (bp->b_flags & B_ERROR)
        bp->b_flags |= B_INVAL;
    if (bp->b_flags & B_INVAL) {
        if (bp->b_vp)
            brelvp(bp);
        bremhash(bp);
        bp->b_forw = bp;
        bp->b_back = bp;
        /* AND the pending write goes with it.  An invalidated buffer's
         * contents are being thrown away deliberately -- truncate, unlink,
         * unmount -- so writing them out afterwards would resurrect data the
         * caller just discarded, and getnewbuf would flush it on the way to
         * reusing the buffer.  Reno clears it in the same arm. */
        bp->b_flags &= ~B_DELWRI;
    }

    if (bp->b_flags & B_INVAL)
        flist = &bfreelist[BQ_AGE];
    else if (bp->b_flags & B_LOCKED)
        flist = &bfreelist[BQ_LOCKED];
    else if (bp->b_flags & B_AGE)
        flist = &bfreelist[BQ_AGE];
    else
        flist = &bfreelist[BQ_LRU];

    /* Invalid and aged buffers go to the HEAD so they are reused first; a
     * good buffer goes to the tail so it survives as long as possible. */
    if (bp->b_flags & (B_INVAL | B_AGE))
        binsheadfree(bp, flist);
    else
        binstailfree(bp, flist);

    bp->b_flags &= ~(B_WANTED | B_BUSY | B_ASYNC | B_AGE);
}

/* ---- I/O -----------------------------------------------------------------
 *
 * bio_strategy is synchronous, so this whole layer is simpler than Reno's
 * without being different from it: the call sites, the flag transitions and
 * the order of operations are Reno's, and only the waiting degenerates.
 */

/* Wait for an I/O to finish.  On this machine it has already finished --
 * bio_strategy calls biodone before returning -- so the loop body never runs.
 * It is written as a loop anyway, because the day an asynchronous device
 * exists this is the code that has to be correct, and because a version that
 * simply asserted B_DONE would have to be rewritten rather than kept. */
int
biowait(bp)
    register struct buf *bp;
{
    while ((bp->b_flags & B_DONE) == 0)
        kc_sleep((char *)bp);
    if ((bp->b_flags & B_ERROR) == 0)
        return (0);
    return (bp->b_error ? bp->b_error : EIO);
}

/* Called by the strategy routine when the transfer is complete. */
void
biodone(bp)
    register struct buf *bp;
{
    register struct vnode *vp;

    if (bp->b_flags & B_DONE)
        kc_panic("biodone: already done");
    bp->b_flags |= B_DONE;
    /* A completed WRITE retires the vnode's outstanding-output count, and the
     * last one out wakes whoever is in vflushbuf waiting for the file to be
     * quiet.  Reads do not count: v_numoutput is about data still owed to the
     * disk, which is what fsync has to wait for. */
    if ((bp->b_flags & B_READ) == 0 && bp->b_vp) {
        vp = bp->b_vp;
        vp->v_numoutput--;
        if ((vp->v_flag & VBWAIT) && vp->v_numoutput <= 0) {
            if (vp->v_numoutput < 0)
                kc_panic("biodone: neg numoutput");
            vp->v_flag &= ~VBWAIT;
            kc_wakeup((char *)&vp->v_numoutput);
        }
    }
    /* An asynchronous write owns its own buffer: nobody is waiting for it, so
     * completion is the moment it goes back on a free list.  A synchronous
     * caller is inside biowait and gets woken instead. */
    if (bp->b_flags & B_ASYNC) {
        brelse(bp);
        return;
    }
    if (bp->b_flags & B_WANTED) {
        bp->b_flags &= ~B_WANTED;
        kc_wakeup((char *)bp);
    }
}

/* Read a block, from the cache if it is there.
 *
 * The hit test is B_DONE|B_DELWRI, which is Reno's and is worth stating: a
 * buffer that has been READ carries B_DONE, and one that is waiting to be
 * WRITTEN carries B_DELWRI and holds the newest bytes there are.  Both are
 * hits.  A freshly recycled buffer carries neither, because getnewbuf assigns
 * b_flags rather than or-ing into it. */
int
bread(vp, blkno, bpp)
    struct vnode *vp;
    daddr_t blkno;
    struct buf **bpp;
{
    register struct buf *bp;

    bp = getblk(vp, blkno);
    *bpp = bp;
    if (bp->b_flags & (B_DONE | B_DELWRI))
        return (0);
    bp->b_flags |= B_READ;
    bp->b_resid = 0;
    VOP_STRATEGY(bp);
    return (biowait(bp));
}

/* Write a block and wait for it.  Releases the buffer either way -- including
 * on error, which is Reno's behaviour and the reason callers do not brelse
 * after bwrite. */
int
bwrite(bp)
    register struct buf *bp;
{
    register int err;
    register int async;
    register int delayed;

    async = bp->b_flags & B_ASYNC;
    delayed = bp->b_flags & B_DELWRI;
    /* B_DONE must go: this buffer is about to be in flight again, and leaving
     * it set would make biowait return before the transfer happened. */
    bp->b_flags &= ~(B_READ | B_DONE | B_ERROR | B_DELWRI);
    /* A buffer that WAS a delayed write is on its vnode's DIRTY list, and the
     * flag that put it there has just been cleared.  Moving it to the clean
     * list here -- after the clear, so reassignbuf reads the new state -- is
     * what keeps the two lists a partition rather than an approximation.  Skip
     * it and vinvalbuf would keep finding a clean buffer on the dirty list and
     * panic that its flush failed. */
    if (delayed)
        reassignbuf(bp, bp->b_vp);
    bp->b_resid = 0;
    /* Counted BEFORE the transfer, because the strategy call is synchronous
     * and biodone -- which decrements it -- runs before it returns. */
    bp->b_vp->v_numoutput++;
    VOP_STRATEGY(bp);
    if (async)
        return (0);             /* biodone released it */
    err = biowait(bp);
    brelse(bp);
    return (err);
}

/* Mark a block to be written later.  The buffer keeps the newest bytes and
 * goes back on a free list; the write happens when something reclaims it, or
 * when a flush walks the vnode.
 *
 * B_DONE is set alongside B_DELWRI so a subsequent bread treats it as a hit --
 * the bytes in hand are newer than the ones on disk, and reading the block
 * back would DISCARD the pending write. */
void
bdwrite(bp)
    register struct buf *bp;
{
    /* Only on the CLEAN-to-DIRTY transition.  bdwrite is called repeatedly on
     * a buffer that is written to more than once before it is flushed, and
     * reassigning an already-dirty buffer would unlink it from the dirty list
     * and put it straight back -- harmless, but it hides the state change the
     * flag is there to record. */
    if ((bp->b_flags & B_DELWRI) == 0) {
        bp->b_flags |= B_DELWRI;
        reassignbuf(bp, bp->b_vp);
    }
    bp->b_flags |= B_DONE;
    brelse(bp);
}

/* Write without waiting.  On synchronous I/O this is bwrite with the release
 * moved into biodone; it exists so callers can express intent, and so the day
 * a device can queue, only this path changes. */
void
bawrite(bp)
    register struct buf *bp;
{
    bp->b_flags |= B_ASYNC;
    bwrite(bp);
}

/* ---- vnode association ----------------------------------------------------
 *
 * Reno threads every buffer onto its vnode's clean or dirty list, and the two
 * lists are a PARTITION: a buffer with B_DELWRI is on the dirty list and one
 * without it is on the clean list, with no third state and no membership of
 * both.  bdwrite, bwrite and reassignbuf are the only places that move a
 * buffer between them, and every one of them changes the flag first and
 * reassigns second, so the list follows the flag rather than racing it.
 */
void
bgetvp(vp, bp)
    register struct vnode *vp;
    register struct buf *bp;
{
    if (bp->b_vp)
        kc_panic("bgetvp: not free");
    bp->b_vp = vp;
    /* UNCONDITIONALLY, which is the whole point.  A recycled buffer still
     * carries the previous owner's device, so setting b_dev only in some cases
     * hands that stale device to the strategy call.
     *
     * NODEV is the RIGHT answer for a file, not a placeholder.  A device vnode
     * knows its device and says so, as of 1.5; a regular file's does not,
     * because the device is a property of the FILESYSTEM the file belongs to
     * rather than of the file.  ufs_strategy fills it in from the inode's
     * i_devvp at the moment the I/O is issued, which is the only point at
     * which it is known. */
    if (vp->v_type == VBLK || vp->v_type == VCHR)
        bp->b_dev = vp->v_rdev;
    else
        bp->b_dev = NODEV;
    vp->v_holdcnt++;
    /* A newly claimed buffer holds no pending write, so it starts CLEAN.  It
     * reaches the dirty list only through bdwrite. */
    bufinsvn(bp, &vp->v_cleanblkhd);
}

void
brelvp(bp)
    register struct buf *bp;
{
    register struct vnode *vp;

    if (bp->b_vp == 0)
        return;
    bufremvn(bp);
    vp = bp->b_vp;
    bp->b_vp = 0;
    if (vp->v_holdcnt)
        vp->v_holdcnt--;
}

/* Move a buffer onto the list its flags say it belongs on.  Called on every
 * clean/dirty transition, and by vinvalbuf for the buffer that turns out to
 * belong to a vnode other than the one being invalidated. */
void
reassignbuf(bp, newvp)
    register struct buf *bp;
    register struct vnode *newvp;
{
    if (newvp == 0)
        kc_panic("reassignbuf: no vnode");
    bufremvn(bp);
    if (bp->b_flags & B_DELWRI)
        bufinsvn(bp, &newvp->v_dirtyblkhd);
    else
        bufinsvn(bp, &newvp->v_cleanblkhd);
}

/* ---- flush and invalidate -------------------------------------------------
 *
 * The two operations the vnode-keyed cache exists to make possible.  A
 * device-keyed cache cannot express either: asked to write out one file, it
 * can only walk every buffer on the machine and test each one.
 *
 * Neither takes an spl.  Reno raises to splbio around each list walk because
 * its buffers are completed by a disk interrupt that can arrive mid-walk.
 * Here the transfer is synchronous SmartPort PIO -- bio_strategy performs it
 * and calls biodone before returning -- so no completion ever runs
 * concurrently with these, and the only way to lose the list is to sleep,
 * which both do explicitly and both re-start the walk afterwards.
 */

/* Write out every dirty buffer belonging to a vnode.  This is fsync.
 *
 * B_SYNC in `flags` asks for the data to be ON THE DISK when this returns
 * rather than merely queued.  It is Reno's value and Reno's collision: 0x0002
 * is also B_DONE in b_flags.  The two never meet -- this is an argument, not a
 * stored flag -- and keeping Reno's number means a call lifted from a Reno
 * listing means what it says. */
void
vflushbuf(vp, flags)
    register struct vnode *vp;
    int flags;
{
    register struct buf *bp;
    struct buf *nbp;

loop:
    for (bp = vp->v_dirtyblkhd; bp; bp = nbp) {
        nbp = bp->b_blockf;
        if (bp->b_flags & B_BUSY)
            continue;
        if ((bp->b_flags & B_DELWRI) == 0)
            kc_panic("vflushbuf: not dirty");
        bremfree(bp);
        bp->b_flags |= B_BUSY;
        /* bawrite and bwrite both take the buffer OFF the dirty list, so nbp
         * -- read before the write -- is what the walk continues from.  Under
         * B_SYNC the walk restarts instead, because bwrite can sleep and the
         * list may have moved underneath it. */
        if ((flags & B_SYNC) == 0) {
            bawrite(bp);
        } else {
            bwrite(bp);
            goto loop;
        }
    }
    if ((flags & B_SYNC) == 0)
        return;
    /* Wait for the writes to reach the disk.  On synchronous I/O they already
     * have: biodone ran inside bio_strategy and took v_numoutput to zero
     * before bwrite returned, so this loop never executes.  It is written
     * anyway for the same reason biowait is -- the day a device can queue,
     * this is the code that has to be right, and a version that asserted
     * v_numoutput == 0 would have to be replaced rather than kept. */
    while (vp->v_numoutput) {
        vp->v_flag |= VBWAIT;
        kc_sleep((char *)&vp->v_numoutput);
    }
    if (vp->v_dirtyblkhd)
        goto loop;
}

/* Write out every delayed write for a DEVICE, whichever vnode holds it.
 *
 * 2.11BSD usr/sys/sys/ufs_bio.c:426, "Make sure all write-behind blocks on dev
 * are flushed out. (from umount and sync)":
 *
 *      for (flist = bfreelist; flist < &bfreelist[BQ_EMPTY]; flist++)
 *      for (bp = flist->av_forw; bp != flist; bp = bp->av_forw) {
 *              if ((bp->b_flags & B_DELWRI) == 0)
 *                      continue;
 *              if (dev == bp->b_dev) {
 *                      bp->b_flags |= B_ASYNC;
 *                      notavail(bp);
 *                      bwrite(bp);
 *                      splx(s);
 *                      goto loop;
 *              }
 *      }
 *
 * WHY THE POOL AND NOT THE VNODE, when vflushbuf above already walks a vnode's
 * dirty list.  4.3BSD-Reno's ufs_sync reaches a device node's delayed writes
 * by walking `mp->mnt_mounth', the mount's list of its own vnodes, and
 * vflushbuf-ing each dirty one (ufs/ufs_vfsops.c:571) before flushing the
 * mount's own device vnode (:580).  THIS TREE KEEPS NO SUCH LIST -- ufs_sync's
 * header says so -- and the two halves are not interchangeable: a partial-block
 * write through /dev/sd0 leaves its buffer on the vnode the WRITER opened,
 * which is an alias of the mount device vnode and not the same vnode, so
 * flushing `um_devvp` alone finds nothing.  Keyed on the DEVICE, every alias is
 * covered at once, which is what upstream's two lines achieve together.
 *
 * b_dev AND NOT b_vp->v_rdev.  b_dev is where the buffer is actually going --
 * bio_strategy routes on it -- and it is set unconditionally by bgetvp; a
 * regular file's vnode has no meaningful v_rdev at all, so keying on that
 * would silently skip file data the day a file buffer is ever left dirty.
 *
 * NODEV FLUSHES EVERYTHING, which is upstream's convention for this argument
 * (sys_inode.c and the umount path both pass a real device; the all-devices
 * call is what a shutdown wants).
 *
 * bwrite RATHER THAN B_ASYNC + bwrite, which is upstream's line.  B_ASYNC only
 * chooses who releases the buffer -- biodone rather than bwrite's own tail --
 * and this machine's I/O is synchronous SmartPort PIO, so the transfer is over
 * either way before the call returns.  The synchronous form is what sync(2)
 * promises, and it reports an error the async one throws away.
 *
 * THE WALK RESTARTS after every write, upstream's `goto loop', because bwrite
 * releases the buffer and brelse puts it back on a free list -- so the list
 * being walked has moved.  No spl: this cache is completed inside
 * bio_strategy, which the head of this file states as the invariant.
 */
void
bflush(dev)
    dev_t dev;
{
    register struct buf *bp;
    register struct buf *flist;

loop:
    for (flist = bfreelist; flist < &bfreelist[BQ_COUNT]; flist++) {
        for (bp = flist->av_forw; bp != flist; bp = bp->av_forw) {
            if ((bp->b_flags & B_DELWRI) == 0)
                continue;
            if (dev != (dev_t)NODEV && bp->b_dev != dev)
                continue;
            bremfree(bp);
            bp->b_flags |= B_BUSY;
            (void)bwrite(bp);
            goto loop;
        }
    }
}


/* Detach every buffer from a vnode, so the vnode can be reclaimed and reused
 * for a DIFFERENT file.
 *
 * This is the function whose absence made vclean unsafe to write.  The cache
 * is keyed by (b_vp, b_lblkno); leave a buffer chained to a vnode that is
 * about to be handed to another file and getblk finds it by key and returns
 * the old file's bytes as the new file's.  `save` asks for pending writes to
 * be issued first -- 1 for a reclaim, where the data is still owed to the
 * disk, and 0 for an unmount of a filesystem that is going away.
 *
 * Returns the number of dirty buffers it had to write, which is what
 * mntinvalbuf reports when it arrives with unmount. */
int
vinvalbuf(vp, save)
    register struct vnode *vp;
    int save;
{
    register struct buf *bp;
    struct buf *nbp;
    struct buf *blist;
    int dirty;

    dirty = 0;
    for (;;) {
        /* Dirty first: writing a buffer moves it to the clean list, so
         * draining that list last means each buffer is visited once. */
        if (blist = vp->v_dirtyblkhd)
            /* void */;
        else if (blist = vp->v_cleanblkhd)
            /* void */;
        else
            break;
        for (bp = blist; bp; bp = nbp) {
            nbp = bp->b_blockf;
            if (bp->b_flags & B_BUSY) {
                /* Someone else holds it.  Wait, then restart from the top --
                 * nbp is not trustworthy across a sleep. */
                bp->b_flags |= B_WANTED;
                kc_sleep((char *)bp);
                break;
            }
            bremfree(bp);
            bp->b_flags |= B_BUSY;
            if (save && (bp->b_flags & B_DELWRI)) {
                dirty++;
                bwrite(bp);
                break;
            }
            if (bp->b_vp != vp)
                reassignbuf(bp, bp->b_vp);
            else
                bp->b_flags |= B_INVAL;
            brelse(bp);
        }
    }
    if (vp->v_dirtyblkhd || vp->v_cleanblkhd)
        kc_panic("vinvalbuf: flush failed");
    return (dirty);
}
