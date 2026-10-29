/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno ufs/ufs_bmap.c
 *   Ported from ufs/ufs_bmap.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* ufs_bmap.c -- logical block to physical block.  UFS 1.10c; 1.12a added
 * the allocation arm.
 *
 * THE ONE FUNCTION THAT DEFINES WHAT A FILE IS.  Everything above it -- read,
 * write, readdir, truncate -- asks the same question: the file's block N, where
 * is it on the disk.  Four direct addresses live in the inode; past those the
 * inode holds three INDIRECT block addresses, each pointing at a block of 256
 * more addresses, nested one, two and three deep.
 *
 * So the reach is 4 + 256 + 65,536 + 16,777,216 blocks, and the cost of
 * reaching them is one disk read per level.  A file's first four kilobytes are
 * free to find; its fifth costs a read; anything past 260 KB costs two.
 *
 *============================================================================
 * RENO'S STRUCTURE, 2.11BSD'S ARITHMETIC.
 *
 * The campaign's standing split lands inside a single function here, so it is
 * worth being exact about which half came from where.
 *
 * FROM RENO: the SHAPE.  It returns an errno and writes the answer through a
 * pointer, where 2.11BSD's returns a daddr_t and overloads it -- 0 for an
 * error, -1 for a hole -- which cannot express "block 0" and does not need to,
 * but only because block 0 is the boot block.  Reno also splits allocation out
 * into balloc, and this port is read-only until 1.12, so Reno's is the shape
 * that survives contact.
 *
 * FROM 2.11BSD: the LEVEL ARITHMETIC.  Reno computes the level with `sh *=
 * NINDIR` and indexes with `i = (bn / sh) % NINDIR`.  On a VAX those are single
 * instructions; fcc calls a runtime helper for every 32-bit divide, once per
 * level per block.  NINDIR is a power of two, so 2.11BSD's shift and mask are
 * exact rather than an approximation of Reno -- see the NSHIFT note in
 * ufs_fs.h.
 *
 *============================================================================
 * IT RETURNS FILESYSTEM BLOCKS, NOT DEVICE BLOCKS, and both originals return
 * device blocks: Reno's ends `*bnp = fsbtodb(fs, nb)` and 2.11BSD's callers
 * apply the same shift.  FGX's buffer cache is keyed by FILESYSTEM block --
 * ufs_sbread reads the superblock as `bread(devvp, UFS_SBLOCK, ...)` with
 * UFS_SBLOCK 1, not 2 -- and bio_strategy is what splits one 1024-byte
 * filesystem block into two 512-byte device transfers.  Applying fsbtodb here
 * would double every address exactly once, which is the kind of error that
 * reads plausibly and lands half a file away.
 *
 * NO READ-AHEAD.  2.11BSD's bmap also leaves the next block in a global
 * `rablock` for breada.  FGX has no read-ahead -- SmartPort PIO is synchronous
 * and there is nothing to overlap it with -- so the two `ra` assignments are
 * dropped rather than carried dead.
 *
 * ALLOCATION IS HERE AS OF 1.12a, in ufs_bmapx, and it is the other half of
 * the file: a zero address on a WRITE takes a block off the free list, threads
 * it into the indirect chain, and writes the indirect block back synchronously
 * so it never points at garbage.  ufs_bmap itself is unchanged -- it is now the
 * read-only door onto the same descent, which is where every 1.10c caller
 * still arrives.  On a read a zero address is a HOLE and the caller gets -1,
 * which is Reno's contract exactly.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "mount.h"
#include "vfsops.h"
#include "ufs_fs.h"
#include "ufsmount.h"
#include "inode.h"

/* A directory's data blocks are zeroed on the platter when allocated, as
 * 2.11BSD's B_SYNC directory writes keep them; see bmapnew. */
#define ISDIRBLK(ip)    (((ip)->i_mode & IFMT) == IFDIR)

extern int   bread();
extern int   bwrite();
extern void  brelse();
extern struct buf *getblk();
extern long  ufs_dget32();
extern void  ufs_dput32();
extern int   ufs_balloc();
extern void  kc_panic();


/* clrbuf -- a hole reads as zeroes.
 *
 * IT LIVES HERE RATHER THAN IN ufs_vnops.c SINCE THE BANK SPLIT, and the
 * move is what leaves the two halves of UFS with no call from the block
 * side to the directory side at all: bmapnew and ufs_itrunc are its heavy
 * callers and both are on this side, while ufs_vnops's three sites reach it
 * through the same vtable they already use for iget and iput.
 *
 * Reno keeps this as a MACRO in sys/buf.h (`blkclr(b_un.b_addr, b_bcount);
 * b_resid = 0`), so upstream inlines it into every filesystem that needs it;
 * a static here is the same arrangement spelled for a compiler with no
 * blkclr.  It WAS a static until 1.12a; ufs_bmap.c's allocation arm clears a
 * freshly allocated block through it, and one clear is better than two.  It is
 * still not a buffer-cache entry point and does not want one: it writes into a
 * buffer the caller already owns.
 *
 * `&bp->b_addr[i]` rather than `bp->b_addr + i`: the arena is in a different
 * bank from this code and pointer arithmetic has dropped the bank byte in this
 * compiler before (bio_strategy.c says the same, for the same reason).
 */
void
clrbuf(bp)
struct buf *bp;
{
    register unsigned short *w;
    register int             n;
    register char           *p;

    /* WORD STORES, AND THE BOUNDS OUT OF THE LOOP.  Both are upstream's shape.
     * 2.11BSD writes this routine in ASSEMBLY (pdp/mch_xxx.s, ENTRY(clrbuf))
     * and clears with the widest store the machine has -- `clrf' eight bytes at
     * a time where there is floating-point hardware, `clr' two where there is
     * not -- unrolled four to a loop.  A byte loop was the one shape upstream
     * did not use.
     *
     * The bounds matter more than the width here.  Written as
     * `for (i = 0; i < (int)bp->b_bcount; i++) bp->b_addr[i] = 0;' this reloads
     * bp from the frame and re-reads b_bcount through it on EVERY BYTE, so a
     * 1024-byte clear paid for 1024 frame reloads and 1024 signed compares
     * around 1024 stores.  It measured 23.86% of a `cat' of a 49 KB file.
     *
     * b_bcount is FS_BLKSIZE at its one assignment (vfs_bio.c), so the odd tail
     * below is unreachable today.  It is here because the routine's signature
     * promises b_bcount bytes and nothing enforces the invariant.
     *
     * AND THE LOOP IS A do/while, WHICH IS UPSTREAM'S TOO (`do *p++ = 0; while
     * (--c);').  Written `while (--n >= 0)' the test compiles to NINE
     * instructions -- fcc materialises the 0 into _fcc_tmp_b and does a full
     * signed subtract with the overflow correction -- against the two a test
     * for nonzero costs, because `--n' has already set Z.  That was thirteen
     * of the twenty instructions in the loop.  The `if (n)' guard is the one
     * thing upstream does not need: it clears MAXBSIZE, a constant, where this
     * clears b_bcount.
     *
     * INDEXING, NOT POINTER ARITHMETIC, for the reason this file already gives:
     * the arena is in a different bank from this code and `p + i' has dropped
     * the bank byte in this compiler before. */
    w = (unsigned short *)bp->b_addr;
    n = (int)(bp->b_bcount >> 1);
    if (n)
        do
            *w++ = 0;
        while (--n);
    if (bp->b_bcount & 1) {
        p = bp->b_addr;
        p[(int)bp->b_bcount - 1] = 0;
    }
    bp->b_resid = 0;
}

/* bmapnew -- one fresh block, zeroed on the platter before anything points at
 * it.  UFS 1.12a.
 *
 * 2.11BSD's `balloc(ip, flags|B_CLRBUF)` (usr/sys/sys/ufs_alloc.c) hands its
 * caller a cleared BUFFER; this hands back a NUMBER, because FGX's allocator
 * already does (`ufs_balloc(devvp, sb, &bno)`, ufs_alloc.c) and because the
 * two callers below want different things done with the block.
 *
 * THE ZERO-AND-WRITE IS NOT TIDINESS.  A block coming off the free list holds
 * whatever the file that last owned it left there.  Point an indirect block at
 * it without clearing it and the next walk down reads those bytes as block
 * ADDRESSES -- a file whose blocks are somebody else's data, which fsck sees as
 * cross-linked and a reader sees as a file full of stale content.  Both
 * upstreams say the same thing in the same place: "Write synchronously so that
 * indirect blocks never point at garbage."
 *
 * IT IS KEYED ON THE DEVICE VNODE, by physical block, which is what
 * ufs_bmap's own indirect reads do -- an indirect block is not part of any
 * file's logical address space and has no logical number to be cached under.
 *
 * `clear' IS 0 FOR A PLAIN FILE'S DATA BLOCK, which comes back as a bare
 * number.  2.11BSD's bmap allocates one with `balloc(ip, flags)' -- cleared
 * only when the caller asked, written with bdwrite unless B_SYNC -- and only
 * directories pass B_SYNC, "so they never appear with garbage in them on the
 * disk".  Every caller here owns a fresh data block's bytes already: *freshp
 * tells ufs_write and ufs_itrunc to clear the buffer, and both write it.
 * Zeroing it on the platter first was a second synchronous write of every
 * block a file grew by.
 */
static int
bmapnew(devvp, ip, resultbno, clear)
struct vnode  *devvp;
struct inode  *ip;
daddr_t       *resultbno;
int            clear;
{
    struct ufsmount *ump;
    struct buf      *bp;
    daddr_t          newb;
    int              error;

    /* Through a local: `&ITOUMP(ip)->um_sb` is the address of a member through
     * a CAST expression and fcc rejects it (apple/fgx#174).  Every other
     * caller in this port spells it with a local for the same reason. */
    ump = ITOUMP(ip);

    error = ufs_balloc(devvp, &ump->um_sb, &newb);
    if (error)
        return (error);
    *resultbno = newb;
    if (!clear)
        return (0);

    bp = getblk(devvp, newb);
    clrbuf(bp);
    /* bwrite releases the buffer on both arms (vfs_bio.c), so there is no
     * brelse here and none on the error path either. */
    return (bwrite(bp));
}


/* ufs_bmapx -- map a logical block to its physical block, GROWING THE FILE if
 * the caller is writing and the block is not there yet.  UFS 1.12a.
 *
 * THE ALLOCATION ARM IS 2.11BSD's, NOT RENO'S, and the choice is forced by the
 * format rather than preferred.  Reno's `balloc` (ufs/ufs_bmap.c:114) is half
 * FFS fragment management -- realloccg, fragroundup, blkpref, a rotational
 * layout policy -- and 2.11BSD's volume has no fragments at all: one block
 * size, FS_BLKSIZE, everywhere.  Porting Reno's would mean deleting most of it
 * and keeping the half that is 2.11BSD's anyway.  So the arms below are
 * 2.11BSD's `bmap` (usr/sys/sys/ufs_bmap.c), which is the same function this
 * one's READ path already came from, with its `rwflg` restored.
 *
 * FROM RENO, STILL: the interface.  An errno out, the answer through a
 * pointer, -1 for a hole -- see the head of this file on why 2.11BSD's
 * overloaded daddr_t return could not be carried here.
 *
 * `ip` IS THE WRITE PATH'S WHOLE ARGUMENT LIST.  Allocation needs the
 * superblock (through ITOUMP) and has to mark the inode dirty, and both
 * upstreams take `struct inode *` for exactly that.  On a READ it is null and
 * the address array is the caller's -- which is what keeps ufs_probe's
 * synthetic indirect chains, built in blocks no inode owns, able to exercise
 * the descent.  When it is non-null it REPLACES the array argument rather than
 * being checked against it: two ways to name one file's addresses is a way for
 * an allocation to be threaded into an array the reader is not reading.
 *
 * *freshp, WHEN THE CALLER PASSES ONE, SAYS THE DATA BLOCK IS BRAND NEW.  It
 * exists so ufs_write can tell a partial write into an existing block (which
 * must bread first, or it destroys the bytes it is not overwriting) from a
 * partial write into a block that was a hole a moment ago (which must NOT
 * read, because there is nothing on the platter for it yet and the free list
 * hands out blocks with the previous owner's content still in them).  Reno
 * carries the same distinction as balloc's B_CLRBUF flag and answers it by
 * returning the buffer; this port answers it with a flag and lets the caller
 * own the buffer, because ufs_write wants the buffer keyed by LOGICAL block on
 * the file vnode and an allocator that returned one would have keyed it by
 * physical block on the device.  Two cached buffers over one disk block is a
 * coherence bug the cache is specifically built not to have.
 *
 * TWO PLACES WHERE THIS IS STRICTER THAN 2.11BSD, both in the same direction
 * and both worth naming rather than leaving as an unexplained diff:
 *
 *   THE THREADED PARENT IS bwriteN, NOT bdwriteN.  Upstream ends its
 *   indirect-block loop with `bap[i] = nb; mapout(bp); bdwrite(bp)` -- a
 *   DELAYED write of the parent, after a synchronous write of the child.  The
 *   ordering guarantee is the same either way (the child is on the platter
 *   before anything points at it), and a delayed parent is the faster choice
 *   on a machine with a working sync(2) and an update daemon.  This port has
 *   neither yet, and bdwrite is not among the four buffer-cache entries
 *   ufs.mod imports from vfs.mod, so the parent goes out synchronously too.
 *   ponytail: synchronous parent; import bdwrite when a measurement says the
 *   indirect writes are what cost.
 *
 *   NO MNT_ASYNC.  Upstream opens with `int async = ip->i_fs->fs_flags &
 *   MNT_ASYNC` and lets an async mount downgrade every one of these writes to
 *   a bdwrite.  FGX has no async mount option, so there is nothing to read;
 *   when mount(2) grows one, this is one of the places that has to honour it.
 *
 * NOTE THAT ONLY THE FINAL DATA BLOCK IS REPORTED FRESH.  A newly allocated
 * INDIRECT block is already zeroed on the platter by bmapnew above and its
 * caller never sees the buffer, so the distinction does not arise for it.
 * A fresh data block is zeroed on the platter only for a directory.
 *
 * In:  addr[NADDR] -- decoded, native byte order (read path only; ignored when
 *      ip is non-null).  rwflg is B_READ or B_WRITE.  ip must be non-null when
 *      rwflg is not B_READ.  freshp may be null.
 * Out: 0 and *resultbno = the filesystem block, or -1 in it for a HOLE on a
 *      READ (a write never returns a hole -- it fills it);
 *      EFBIG for a negative or out-of-range logical block; EIO if an indirect
 *      block could not be read; ENOSPC from the allocator.
 */
int
ufs_bmapx(devvp, addr, lbn, rwflg, ip, resultbno, freshp)
struct vnode  *devvp;
daddr_t       *addr;
daddr_t        lbn;
int            rwflg;
struct inode  *ip;
daddr_t       *resultbno;
int           *freshp;
{
    struct buf *bp;
    daddr_t     nb;
    int         sh;
    int         i;
    int         j;
    int         error;

    if (freshp != (int *)0)
        *freshp = 0;
    if (lbn < (daddr_t)0)
        return (EFBIG);

    if (rwflg != B_READ) {
        if (ip == (struct inode *)0)
            kc_panic("ufs_bmapx: write with no inode");
        addr = ip->i_addr;
    }

    /* The first NDADDR blocks are in the inode and cost nothing to find. */
    if (lbn < (daddr_t)NDADDR) {
        nb = addr[(int)lbn];
        if (nb == (daddr_t)0) {
            if (rwflg == B_READ) {
                *resultbno = (daddr_t)-1;   /* a hole */
                return (0);
            }
            error = bmapnew(devvp, ip, &nb, ISDIRBLK(ip));
            if (error)
                return (error);
            addr[(int)lbn] = nb;
            ip->i_flag |= IUPD | ICHG;
            if (freshp != (int *)0)
                *freshp = 1;
        }
        *resultbno = nb;
        return (0);
    }

    /* HOW MANY LEVELS DEEP.  Subtract each level's span in turn until the
     * block falls inside one: 256 single, 65,536 double, 16,777,216 triple.
     * j counts DOWN from NIADDR, so j == 3 is the single indirect and j == 0
     * means the block is past everything this format can address.
     *
     * sh accumulates the shift for the level, and is what turns the remaining
     * block number into an index at each step below. */
    sh = 0;
    nb = (daddr_t)1;
    lbn -= (daddr_t)NDADDR;
    for (j = NIADDR; j > 0; j--) {
        sh += NSHIFT;
        nb <<= NSHIFT;
        if (lbn < nb)
            break;
        lbn -= nb;
    }
    if (j == 0)
        return (EFBIG);

    /* The inode's indirect slot for that level.  NADDR-j is 2.11BSD's
     * spelling and NDADDR+(NIADDR-j) is Reno's; they are the same slot. */
    nb = addr[NADDR - j];
    if (nb == (daddr_t)0) {
        if (rwflg == B_READ) {
            *resultbno = (daddr_t)-1;   /* the whole subtree is a hole */
            return (0);
        }
        error = bmapnew(devvp, ip, &nb, 1);
        if (error)
            return (error);
        addr[NADDR - j] = nb;
        ip->i_flag |= IUPD | ICHG;
    }

    /* WALK DOWN.  One disk read per level.  The loop runs NIADDR-j+1 times:
     * once for a single indirect, three times for a triple. */
    for (; j <= NIADDR; j++) {
        error = bread(devvp, nb, &bp);
        if (error) {
            brelse(bp);
            return (EIO);
        }

        /* THE ENTRIES ARE PDP-11 LONGS AND MUST BE DECODED, which is the one
         * place this port cannot follow either original's code.  Both index
         * the buffer directly -- `bap = bp->b_un.b_daddr; nb = bap[i]` -- and
         * both are right, because there the in-core form IS the on-disk form.
         * Here a raw index would read a 32-bit value with its halves swapped:
         * block 70 would come back as 4,587,520, which is not a small error
         * and not a plausible one either, but it IS one that only shows up
         * past the fourth block of a file. */
        sh -= NSHIFT;
        i = (int)((lbn >> sh) & (daddr_t)NMASK);
        nb = ufs_dget32(bp->b_addr, i * 4);

        if (nb == (daddr_t)0) {
            if (rwflg == B_READ) {
                brelse(bp);
                *resultbno = (daddr_t)-1;   /* a hole deeper in the tree */
                return (0);
            }
            error = bmapnew(devvp, ip, &nb,
                            j < NIADDR || ISDIRBLK(ip));
            if (error) {
                brelse(bp);
                return (error);
            }
            /* THREAD IT IN AND WRITE THE PARENT SYNCHRONOUSLY, in that order.
             * An indirect or directory child is already zeroed on the platter
             * (bmapnew), so at no point between these two writes does a
             * reachable address name a block holding somebody else's bytes.
             * A plain file's data child is not, as in 2.11BSD, where it is
             * bdwritten and its parent too.  The reverse order -- write
             * the parent first, clear the child after -- is the window both
             * upstreams' comment exists to close.
             *
             * The inode is NOT marked here: this address lives in an indirect
             * block, not in the inode, and the inode's own slot was marked
             * above when the top of this subtree was created.
             *
             * bwrite releases bp, so the brelse at the foot of the loop must
             * not also run -- hence the continue rather than falling through.
             */
            ufs_dput32(bp->b_addr, i * 4, nb);
            error = bwrite(bp);
            if (error)
                return (error);
            if (freshp != (int *)0 && j == NIADDR)
                *freshp = 1;
            continue;
        }

        brelse(bp);
    }

    *resultbno = nb;
    return (0);
}


/* ufs_bmap -- the READ-ONLY door, and the signature every 1.10c caller uses.
 *
 * Unchanged in behaviour and unchanged in shape: ufs_strategy, ufs_vbmap and
 * the probe's synthetic indirect chains all call this.  It is a wrapper rather
 * than a second copy of the descent because there is exactly one piece of
 * arithmetic here worth getting right and it should exist once -- the port has
 * already been bitten by two builders of one thing drifting apart.
 */
int
ufs_bmap(devvp, addr, lbn, resultbno)
struct vnode  *devvp;
daddr_t       *addr;
daddr_t        lbn;
daddr_t       *resultbno;
{
    return (ufs_bmapx(devvp, addr, lbn, B_READ, (struct inode *)0,
                      resultbno, (int *)0));
}
