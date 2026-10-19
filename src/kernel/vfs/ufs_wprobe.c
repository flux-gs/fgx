/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX-Origin: original -- FGX code.  It CITES BSD but contains none of it;
 * registering it would assert the Regents' copyright over work they did not
 * write.
 */
/* ufs_wprobe.c -- the filesystem asserted through its WRITING vnode
 * operations.  UFS 1.12b, split out of ufs_vnprobe.c.
 *
 * THE THIRD SPLIT, AND THE THIRD TIME FOR THE SAME REASON.  ufs.mod is one
 * 65,536-byte bank.  1.12a split ufs_probe.c in two when the shipping code
 * grew past what one gate could carry; 1.12b's shipping code -- itrunc,
 * indirtrunc with its three-kilobyte per-level copy table, setattr and
 * inactive -- added another 9,778 bytes, and the vnode gate went over again.
 * Measured: ufs.mod ships at 44,061 bytes now against 34,283 before this
 * increment.
 *
 * THE SEAM IS READING VERSUS WRITING, which is a subject seam and not a line
 * count:
 *
 *   ufs_probe.c     the volume as BLOCKS -- superblock, allocators, bmap.
 *   ufs_vnprobe.c   the volume as FILES, READ -- the mount, the inode hash,
 *                   getattr, read, lookup, readdir.
 *   this file       the volume as FILES, WRITTEN -- write, fsync, readlink
 *                   (which has to build a symlink to have one), truncate,
 *                   setattr and the unlink-while-open release.
 *
 * All three gates are MUTUALLY EXCLUSIVE, so what they share costs nothing
 * twice, and the case numbers do not overlap: 860-912 the write path, 920-960
 * truncate and release, 968-1037 the directory-entry layer, 1038-1101 the
 * rest of directory mutation (1102-1103 continue that range), 1104-1169
 * rename (1170-1183 continue it).
 *
 * EVERYTHING ELSE ABOUT HOW A PROBE HERE WORKS IS ufs_probe.c's HEADER -- where
 * the expected numbers come from, why the volume is identified before a byte is
 * written, and why it must be left as it was found.
 */

#include "fsparam.h"
#include "vnode.h"
#include "specdev.h"
#include "buf.h"
#include "ufs_fs.h"
#include "mount.h"
#include "vfsops.h"
#include "ufsmount.h"
#include "inode.h"
#include "uio.h"
#include "dir.h"
#include "namei.h"

extern int          bdevvp();
extern int          ufs_sbread();
extern int          ufs_sbupdate();
extern int          ufs_bmap();
extern int          ufs_itrunc();
extern long         ufs_dget32();
extern int          ufs_mountfs();
extern void         vref();
extern int          iget();
extern void         iput();
extern void         vrele();
extern int          bread();
extern int          bwrite();
extern void         brelse();
extern int          kc_blkio();
extern int          namei();          /* the walk, 1.6/symlinks */
extern struct nameidata *ndslot();

#define DEV_BLKSIZE     512
#define PROBE_READ      1
#define PROBE_WRITE     0

/* One 512-byte scratch for the RAW oracle reads. */
static char probebuf[DEV_BLKSIZE];

/* The decoded superblock -- the pristine copy the write sections are restored
 * from, read off the platter immediately before them and written back
 * immediately after. */
static struct ufs_sb probesb;

/* Raw device access, bypassing the cache entirely: this is the oracle. */
static int
rawio(dev, dblk, isread)
    int     dev;
    daddr_t dblk;
    int     isread;
{
    return (kc_blkio(dev, (int)(dblk >> 16), (int)dblk, probebuf, isread));
}


/* ---- THE WRITE PROBE (UFS 1.12a) ---------------------------------------
 *
 * WHAT THIS HAS TO CATCH IS A WRITE PATH THAT DOES NOTHING, and that is a
 * sharper requirement than it sounds.  A filesystem that accepts every write,
 * allocates nothing and touches no block leaves a volume fsck calls perfect.
 * It passes "did the machine survive", it passes "is the free list consistent",
 * and it passes any test that reads its own writes back through the buffer
 * cache -- because the cache is holding exactly the bytes it was handed.  The
 * campaign has already shipped one fix that turned out to be inert and one
 * that was a gesture; a write path is the easiest place in this tree to do it
 * again.
 *
 * SO EVERY VERIFICATION HERE IS A RAW BLOCK READ.  kc_blkio, through rawio,
 * goes to the SmartPort under the buffer cache, under bio_strategy, under
 * everything vfs.mod owns.  If the bytes are there they are on the platter.
 * Reading them back with VOP_READ proves only that the two halves of this
 * increment agree with each other, which is worth something and is not this.
 *
 * IT MUTATES THE VOLUME, AND THE RESTORE RULES ARE 1.10b's, for the same
 * reason: disk/ufsscratch.po is handed to MAME by path with no per-run copy,
 * and ninja will not rebuild an image newer than its inputs, so a run that
 * leaves the volume changed poisons it until someone deletes it by hand.  A
 * function rather than a block, so every early return still reaches the
 * caller's restore.
 *
 * WHAT IT TOUCHES, exactly, and why each is restorable:
 *
 *   INODE 5, which is free on this volume and stays free.  mkfs made 1024
 *   inodes and the root directory names 2, 3 and 4; the first case below
 *   REFUSES TO PROCEED if slot 5's mode is not zero, so a volume whose layout
 *   ever changes stops this rather than overwriting a real file.  The slot is
 *   zeroed again at the end, through the buffer cache so the cached copy and
 *   the platter agree.
 *
 *   THREE BLOCKS off the free list -- two data and one single-indirect.  The
 *   caller's ufs_sbupdate(probesb) puts the free list back, which returns all
 *   three.  Their contents are then garbage, which is what every block on a
 *   free list holds.
 *
 *   AND NOTHING ELSE.  Three allocations against sb_nfree of 26 cannot empty
 *   the cache, so no chain block is consumed and no refill writes one -- which
 *   matters, because a consumed chain block is NOT restorable by putting the
 *   superblock back.  If this section ever grows past twenty-odd blocks it
 *   needs 1.10b's answer instead, or its own volume.
 */
static char wpat[64];

/* The symlink target for section (k).  A PATH RATHER THAN A PATTERN, because a
 * link's contents are a path and a reader looking at the raw block should be
 * able to see that this is what it is.  NOT NUL-TERMINATED on the volume: a
 * symlink's i_size is the length of the target and the string does not carry a
 * terminator, which is the format assertion case 904 makes. */
#define LNKTARGLEN      15
static char lnktarg[LNKTARGLEN] = {
    '/', 'u', 's', 'r', '/', 'b', 'i', 'n', '/', 't', 'a', 'r', 'g', 'e', 't'
};

static int
writeguard(dev, devvp, mp)
int           dev;
struct vnode *devvp;
struct mount *mp;
{
    struct inode *wip;
    struct vnode *wvp;
    struct inode *lip;      /* (k): the symlink */
    struct vnode *lvp;
    struct uio    u;
    struct iovec  iov;
    struct buf   *bp;
    daddr_t       bn0;
    daddr_t       bn4;
    daddr_t       ind;
    daddr_t       got;
    long          sz;
    int           i;
    int           slot;

    /* ---- (a) A FREE INODE, AND PROOF THAT IT IS ONE --------------------- */
    if (iget(mp, (ino_t)5, &wip) != 0)
        return (860);
    wvp = ITOV(wip);
    if (wip->i_mode != 0) {
        iput(wip);
        return (861);       /* slot 5 is NOT free -- do not write on it */
    }

    /* MAKE IT A REGULAR FILE IN CORE.  1.12c's maknode is what does this for
     * real, from a create(2); here the four fields are set by hand because the
     * subject under test is the write path and not the one above it.  v_type
     * has to move with the mode: iget set it from a mode of zero, so the vnode
     * came back VBAD and ufs_write's type check would refuse it -- correctly.
     */
    wip->i_mode  = (unsigned short)(IFREG | 0644);
    wip->i_nlink = 1;
    wip->i_size  = 0L;
    wvp->v_type  = VREG;

    for (i = 0; i < 64; i++)
        wpat[i] = (char)(0xA0 + i);

    /* ---- (b) A PARTIAL WRITE INTO A BLOCK THAT DOES NOT EXIST ----------
     *
     * 64 bytes at offset 8.  Everything about this is the first-time path: no
     * block, no indirect, no size.  It has to allocate a direct block, clear
     * it, put the bytes at offset 8, and leave the rest of the block ZERO --
     * not the previous owner's content, which is what the free list is full
     * of.
     */
    iov.iov_base = wpat;
    iov.iov_len  = 64;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)8;
    u.uio_resid  = 64;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(wvp, &u, 0, (char *)0) != 0)
        return (862);
    if (u.uio_resid != 0)
        return (863);       /* a short write nobody reported */
    if (wip->i_size != 72L)
        return (864);       /* offset 8 + 64 bytes */
    if (wip->i_addr[0] == (daddr_t)0)
        return (865);       /* nothing was allocated: the write went nowhere */
    bn0 = wip->i_addr[0];

    /* ---- (c) THE BYTES ARE ON THE PLATTER ------------------------------
     *
     * The whole point of the section.  A raw read of the physical block the
     * inode now names, under every cache this kernel has.  fs block N is
     * device blocks 2N and 2N+1; the payload is at offset 8, so it is entirely
     * inside the first.
     */
    if (rawio(dev, bn0 * (daddr_t)2, PROBE_READ) != 0)
        return (866);
    for (i = 0; i < 8; i++)
        if (probebuf[i] != (char)0)
            return (867);   /* clrbuf did not run: stale bytes before the write */
    for (i = 0; i < 64; i++)
        if (probebuf[8 + i] != (char)(0xA0 + i))
            return (868);   /* the bytes are not there */
    for (i = 72; i < DEV_BLKSIZE; i++)
        if (probebuf[i] != (char)0)
            return (869);   /* stale bytes AFTER the write */

    /* ---- (d) THE INODE IS ON THE PLATTER TOO ---------------------------
     *
     * iupdat, ufs_iencode and the PDP-11 byte order, checked as BYTES rather
     * than by reading the inode back through iget -- which would answer out of
     * the in-core copy and prove nothing.  A size of 72 encodes as 00 00 00 48
     * in PDP-11 order (high word first, each word little-endian): bytes 00 00
     * then 48 00.  An encoder with its halves swapped writes 48 00 00 00 and
     * gives 4,718,592.
     */
    /* FSYNC FIRST, WHICH IS NEW AT 1.12b.  Until 1.12b ufs_write wrote the
     * inode back on every call, so the platter was already current here; the
     * inode is now left dirty until the last vrele or an explicit sync, which
     * is upstream's arrangement.  So this case has to ask for the flush --
     * which also makes it the only thing that exercises VOP_FSYNC on a file
     * with something to flush.  Removing this call is a red arm for the whole
     * write-back path, and it gives 871. */
    if (VOP_FSYNC(wvp, 0, (char *)0, 1) != 0)
        return (912);

    slot = itoo((ino_t)5) * UFS_DINODESIZE;
    if (rawio(dev, itod((ino_t)5) * (daddr_t)2, PROBE_READ) != 0)
        return (870);
    if (probebuf[slot + 8] != (char)0x00 || probebuf[slot + 9] != (char)0x00 ||
        probebuf[slot + 10] != (char)0x48 || probebuf[slot + 11] != (char)0x00)
        return (871);       /* di_size is not 72, or not in PDP-11 order */
    if (ufs_dget32(probebuf, slot + 12) != bn0)
        return (872);       /* di_addr[0] on the platter is not the block */

    /* ---- (e) A PARTIAL WRITE INTO A BLOCK THAT DOES EXIST --------------
     *
     * The bread arm.  Sixteen bytes at offset 200, into the block (b) created.
     * Everything (b) wrote must survive, which is what separates bread from
     * getblk here: taking the buffer without reading it would return the rest
     * of the block as whatever the cache last held.
     *
     * THE POOL IS FLUSHED FIRST, AND WITHOUT THAT THIS CASE CANNOT FAIL.
     * MEASURED, not reasoned about: with the flush removed, a mutation that
     * makes ufs_write take getblk on EVERY write -- deleting the bread arm
     * outright -- leaves this probe green.  The reason is that (b) has just
     * written logical block 0, so its buffer is still resident and getblk
     * returns it with the right bytes already in it.  Skipping a read of a
     * block you are holding is harmless; the defect only appears once the
     * buffer has been evicted, which is the state a real system is in almost
     * always and this probe was in never.
     *
     * NBUF + 4 DISTINCT DEVICE BLOCKS is what evicts it.  The pool is NBUF
     * buffers on an LRU free list (vfs_bio.c), so reading more distinct blocks
     * than it holds guarantees the one from (b) is gone.  They are read
     * through the DEVICE vnode by physical block, they are read-only, and they
     * are blocks 2 upward -- the i-list and the start of the data area, which
     * exist on any volume this probe has already refused to run without.
     */
    for (i = 0; i < NBUF + 4; i++) {
        if (bread(devvp, (daddr_t)(2 + i), &bp) != 0) {
            brelse(bp);
            return (900);       /* the volume stopped answering mid-probe */
        }
        brelse(bp);
    }

    iov.iov_base = wpat;
    iov.iov_len  = 16;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)200;
    u.uio_resid  = 16;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(wvp, &u, 0, (char *)0) != 0)
        return (873);
    if (wip->i_addr[0] != bn0)
        return (874);       /* it re-allocated a block it already had */
    if (rawio(dev, bn0 * (daddr_t)2, PROBE_READ) != 0)
        return (875);
    for (i = 0; i < 64; i++)
        if (probebuf[8 + i] != (char)(0xA0 + i))
            return (876);   /* the first write was destroyed by the second */
    for (i = 0; i < 16; i++)
        if (probebuf[200 + i] != (char)(0xA0 + i))
            return (877);

    /* ---- (f) PAST THE DIRECT BLOCKS: AN INDIRECT BLOCK IS BUILT --------
     *
     * Logical block 4 is the first that needs one.  Blocks 1, 2 and 3 are
     * never written and stay holes, which is also what makes the size below
     * meaningful: a file of 4,152 bytes occupying two blocks.
     *
     * TWO ALLOCATIONS HAPPEN HERE and the ORDER between them is the property
     * that matters: the indirect block must be zeroed and written BEFORE the
     * inode points at it, or a reader arriving in between walks a block of
     * somebody else's data as if it were addresses.  What this can check
     * afterwards is the result -- an indirect block whose only non-zero entry
     * is the one just threaded.
     */
    iov.iov_base = wpat;
    iov.iov_len  = 56;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)(4L * 1024L);
    u.uio_resid  = 56;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(wvp, &u, 0, (char *)0) != 0)
        return (878);
    if (wip->i_size != 4152L)
        return (879);
    if (wip->i_addr[1] != (daddr_t)0 || wip->i_addr[2] != (daddr_t)0 ||
        wip->i_addr[3] != (daddr_t)0)
        return (880);       /* the skipped blocks are not holes */
    ind = wip->i_addr[NADDR - NIADDR];   /* the single indirect slot */
    if (ind == (daddr_t)0)
        return (881);       /* no indirect block was created */

    /* The indirect block, raw.  Entry 0 is logical block 4; every other entry
     * must still be zero, which is what says bmapnew cleared it rather than
     * handing back a block full of the last file's addresses. */
    if (rawio(dev, ind * (daddr_t)2, PROBE_READ) != 0)
        return (882);
    bn4 = ufs_dget32(probebuf, 0);
    if (bn4 == (daddr_t)0)
        return (883);
    for (i = 4; i < DEV_BLKSIZE; i++)
        if (probebuf[i] != (char)0)
            return (884);   /* the indirect block was not cleared */

    /* ...and the data block it names. */
    if (rawio(dev, bn4 * (daddr_t)2, PROBE_READ) != 0)
        return (885);
    for (i = 0; i < 56; i++)
        if (probebuf[i] != (char)(0xA0 + i))
            return (886);
    for (i = 56; i < DEV_BLKSIZE; i++)
        if (probebuf[i] != (char)0)
            return (887);

    /* ---- (g) READ A HOLE, THEN WRITE IT --------------------------------
     *
     * The sequence that catches a lost write, and it is not exotic: block 1
     * has never been written, so reading it caches a buffer whose b_blkno is
     * -1 -- ufs_strategy's hole marker.  A write that then takes that buffer
     * and does not overwrite b_blkno hands bio_strategy a buffer that still
     * says "hole"; strategy calls biodone without performing any I/O, bwrite
     * reports success, and the bytes are gone.  Nothing above this case can
     * see that, because every block written above was either fresh or already
     * mapped.
     *
     * The read is through VOP_READ so it goes through the same cache the write
     * will; the verification is raw, as everywhere here.
     */
    iov.iov_base = probebuf;
    iov.iov_len  = 32;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)1024;
    u.uio_resid  = 32;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(wvp, &u, 0, (char *)0) != 0)
        return (888);
    for (i = 0; i < 32; i++)
        if (probebuf[i] != (char)0)
            return (889);   /* a hole did not read as zeroes */

    iov.iov_base = wpat;
    iov.iov_len  = 32;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)1024;
    u.uio_resid  = 32;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(wvp, &u, 0, (char *)0) != 0)
        return (890);
    if (wip->i_addr[1] == (daddr_t)0)
        return (891);
    if (rawio(dev, wip->i_addr[1] * (daddr_t)2, PROBE_READ) != 0)
        return (892);
    for (i = 0; i < 32; i++)
        if (probebuf[i] != (char)(0xA0 + i))
            return (893);   /* the write into a previously-read hole was LOST */

    /* ---- (h) IO_APPEND WRITES AT THE END, WHATEVER THE OFFSET SAYS ----- */
    sz = wip->i_size;
    iov.iov_base = wpat;
    iov.iov_len  = 8;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;        /* deliberately wrong; IO_APPEND overrides */
    u.uio_resid  = 8;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(wvp, &u, IO_APPEND, (char *)0) != 0)
        return (894);
    if (wip->i_size != sz + 8L)
        return (895);       /* it wrote at offset 0 and did not grow */

    /* ---- (i) THE ROUND TRIP, LAST -------------------------------------
     *
     * Now that the platter has been checked directly, reading back through
     * VOP_READ is worth doing: it says the two halves agree, and it exercises
     * ufs_read over a file whose blocks this increment allocated rather than
     * mkfs.  A failure here after (c) through (g) passed means the READ path
     * cannot see what the write path built -- a bmap disagreement, not a lost
     * write.
     */
    if (ufs_bmap(devvp, wip->i_addr, (daddr_t)4, &got) != 0 || got != bn4)
        return (896);
    iov.iov_base = probebuf;
    iov.iov_len  = 56;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)(4L * 1024L);
    u.uio_resid  = 56;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(wvp, &u, 0, (char *)0) != 0)
        return (897);
    for (i = 0; i < 56; i++)
        if (probebuf[i] != (char)(0xA0 + i))
            return (898);

    /* ---- (j) PUT SLOT 5 BACK ------------------------------------------
     *
     * THE RESTORE IS SEMANTIC, NOT BYTE FOR BYTE, and that is true of the
     * block-level gate too rather than being this section's compromise.
     * MEASURED by comparing the image against a fresh `fgxfs mkfs` after a
     * run: what differs is sb_time -- ufs_sbupdate stamps it on every write,
     * so writing the pristine copy back cannot restore a zero -- and the
     * contents of the blocks that were handed out, which are back on the free
     * list holding what the last owner left, exactly as every block on a free
     * list does.  A gate-1 run leaves the same four bytes at the same place
     * plus its own spill blocks.
     *
     * WHAT MAKES THAT SAFE IS tools/tryprobe.sh REBUILDING THE VOLUME PER RUN,
     * not the restore alone.  The restore is what keeps the FREE LIST and the
     * counts true, which is what the next boot's case 403 reads; the rebuild
     * is what keeps sb_time zero, which is what case 408 reads.  Run this
     * probe by hand against an image nobody rebuilt and 408 is what fires.
     *
     * THROUGH THE BUFFER CACHE, not through rawio, and the difference is not
     * cosmetic: iupdat wrote this block with bread/bwrite, so the cache holds
     * a copy.  Zeroing the platter underneath it would leave the two
     * disagreeing, and the next reader of that block gets whichever it happens
     * to consult.  The free-list half of the restore is the caller's, exactly
     * as it is for the allocator probe.
     */
    if (bread(devvp, itod((ino_t)5), &bp) != 0) {
        brelse(bp);
        return (899);
    }
    for (i = 0; i < UFS_DINODESIZE; i++)
        bp->b_addr[slot + i] = (char)0;
    if (bwrite(bp) != 0)
        return (899);

    /* The in-core copy goes with it, so nothing can write it back out:
     * ufs_inactive flushes a dirty inode, and this is the state it must find.
     *
     * THE DIRTY FLAGS AND NOT THE WHOLE WORD, which used to read `i_flag = 0`
     * and was correct until 1.12d put the inode lock in the same word.  A
     * wholesale clear takes ILOCKED with it, so the iput one line below
     * unlocked an inode the flag word said was already free and panicked in
     * ufs_unlock -- a probe teardown line reporting a fault in the thing it
     * was tearing down.  The four named here are what iupdat tests. */
    wip->i_flag &= ~(IUPD | IACC | ICHG | IMOD);
    wip->i_mode = 0;
    iput(wip);

    /* ---- (k) A SYMBOLIC LINK, WRITTEN AND READ BACK -------------------
     *
     * VOP_READLINK, and it needs a VLNK vnode to read -- which nothing on this
     * volume can supply, because `fgxfs mkfs` does not make one and
     * ufs_symlink is 1.12c.  So this builds one: inode 6, mode IFLNK, and the
     * target string written through VOP_WRITE, which is exactly what Reno's
     * ufs_symlink does after maknode (`vn_rdwr(UIO_WRITE, ...)` of the target
     * at offset 0).  The link is real in every respect except that no
     * directory entry names it.
     *
     * THAT IS WHAT MAKES THIS WORTH RUNNING RATHER THAN CIRCULAR.  ufs_readlink
     * is one line -- it forwards to ufs_read -- so the thing under test is not
     * arithmetic, it is whether an IFLNK inode survives the write path at all
     * and comes back through the READ path, whose type check has admitted
     * IFLNK since 1.11b without anything ever handing it one.  A symlink's
     * target IS the file's contents on this format, with i_size the length of
     * the string and no NUL, so the size check below is the format assertion
     * and not a detail.
     *
     * The raw read is the same oracle as everywhere here: the string has to be
     * ON THE PLATTER, not merely in a buffer VOP_READ can find.
     */
    if (iget(mp, (ino_t)6, &lip) != 0)
        return (901);
    lvp = ITOV(lip);
    if (lip->i_mode != 0) {
        iput(lip);
        return (902);       /* slot 6 is NOT free -- do not write on it */
    }
    lip->i_mode  = (unsigned short)(IFLNK | 0777);
    lip->i_nlink = 1;
    lip->i_size  = 0L;
    lvp->v_type  = VLNK;

    for (i = 0; i < LNKTARGLEN; i++)
        wpat[i] = lnktarg[i];

    iov.iov_base = wpat;
    iov.iov_len  = LNKTARGLEN;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = LNKTARGLEN;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(lvp, &u, 0, (char *)0) != 0)
        return (903);
    if (lip->i_size != (off_t)LNKTARGLEN)
        return (904);       /* a link's size IS its target's length */
    if (lip->i_addr[0] == (daddr_t)0)
        return (905);

    /* On the platter, under everything. */
    if (rawio(dev, lip->i_addr[0] * (daddr_t)2, PROBE_READ) != 0)
        return (906);
    for (i = 0; i < LNKTARGLEN; i++)
        if (probebuf[i] != lnktarg[i])
            return (907);

    /* ...and back through the vnode op.  A cold pool first, for the reason
     * section (e) states: reading what is still in the buffer you just wrote
     * proves less than it looks. */
    for (i = 0; i < NBUF + 4; i++) {
        if (bread(devvp, (daddr_t)(2 + i), &bp) != 0) {
            brelse(bp);
            return (900);
        }
        brelse(bp);
    }
    for (i = 0; i < LNKTARGLEN; i++)
        probebuf[i] = (char)0;
    iov.iov_base = probebuf;
    iov.iov_len  = LNKTARGLEN;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = LNKTARGLEN;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READLINK(lvp, &u, (char *)0) != 0)
        return (908);
    if (u.uio_resid != 0)
        return (909);       /* a short readlink nobody reported */
    for (i = 0; i < LNKTARGLEN; i++)
        if (probebuf[i] != lnktarg[i])
            return (910);

    /* Slot 6 back, on section (j)'s terms. */
    if (bread(devvp, itod((ino_t)6), &bp) != 0) {
        brelse(bp);
        return (911);
    }
    slot = itoo((ino_t)6) * UFS_DINODESIZE;
    for (i = 0; i < UFS_DINODESIZE; i++)
        bp->b_addr[slot + i] = (char)0;
    if (bwrite(bp) != 0)
        return (911);
    lip->i_flag &= ~(IUPD | IACC | ICHG | IMOD);   /* not the whole word: see
                                                   * section (j)'s teardown */
    lip->i_mode = 0;
    iput(lip);

    return (0);
}


/* ---- THE TRUNCATE AND RELEASE PROBE (UFS 1.12b) ------------------------
 *
 * WHAT THIS HAS TO CATCH IS A RECLAIM THAT FREES TOO FEW BLOCKS, and that is
 * invisible by every other means: a truncate that drops the addresses but does
 * not put the blocks back leaves a volume that reads correctly, passes every
 * consistency check this kernel can make, and simply fills up.  apple/fgx#68
 * was that defect on the ProDOS side and it took a user noticing free space
 * going missing.
 *
 * SO THE ORACLE IS THE FREE-BLOCK COUNT, read before and after and asserted
 * EXACTLY.  sb_tfree is the volume's own accounting, maintained by the 1.10b
 * allocator that this code has to hand blocks back to.  "It went up" would
 * pass a reclaim that returned three blocks out of four; only the exact number
 * discriminates, and the file is built to have a number worth counting -- two
 * direct blocks, one past the direct addresses, and the indirect block that
 * had to be created to reach it.
 *
 * IT USES ITS OWN INODE AND RESTORES IT, on the same terms as the write probe
 * above: inode 7, checked free first, and put back through the buffer cache at
 * the end.  The blocks come off the free list and go back onto it, which is
 * what this section is about.
 */
static int
truncguard(dev, devvp, mp)
int           dev;
struct vnode *devvp;
struct mount *mp;
{
    struct inode    *tip;
    struct vnode    *tvp;
    struct ufsmount *ump;
    struct uio       u;
    struct iovec     iov;
    struct buf      *bp;
    struct vattr     va;
    daddr_t          before;
    daddr_t          after;
    daddr_t          b0;
    daddr_t          b4;
    daddr_t          ind;
    long             released;
    int              i;
    int              slot;

    if (iget(mp, (ino_t)7, &tip) != 0)
        return (920);
    tvp = ITOV(tip);
    if (tip->i_mode != 0) {
        iput(tip);
        return (921);       /* slot 7 is NOT free -- do not write on it */
    }
    ump = ITOUMP(tip);

    tip->i_mode  = (unsigned short)(IFREG | 0644);
    tip->i_nlink = 1;
    tip->i_size  = 0L;
    tvp->v_type  = VREG;

    for (i = 0; i < 64; i++)
        wpat[i] = (char)(0x30 + i);

    /* ---- (a) BUILD A FILE WHOSE BLOCK COUNT IS KNOWN -------------------
     *
     * Logical 0 and logical 4.  THREE blocks, and naming the number is the
     * point of the case rather than a detail: block 0, block 4, and the single
     * indirect block that logical 4 cannot be reached without.  Blocks 1, 2
     * and 3 are never written and stay holes, which is why it is three and not
     * six.
     */
    before = ump->um_sb.sb_tfree;

    iov.iov_base = wpat;
    iov.iov_len  = 64;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = 64;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(tvp, &u, 0, (char *)0) != 0)
        return (922);

    iov.iov_base = wpat;
    iov.iov_len  = 64;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)(4L * 1024L);
    u.uio_resid  = 64;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(tvp, &u, 0, (char *)0) != 0)
        return (923);

    b0  = tip->i_addr[0];
    ind = tip->i_addr[NDADDR];
    if (b0 == (daddr_t)0 || ind == (daddr_t)0)
        return (924);
    if (rawio(dev, ind * (daddr_t)2, PROBE_READ) != 0)
        return (925);
    b4 = ufs_dget32(probebuf, 0);
    if (b4 == (daddr_t)0)
        return (926);

    after = ump->um_sb.sb_tfree;
    if (before - after != (daddr_t)3)
        return (927);       /* the file did not cost exactly three blocks */

    /* ---- (b) TRUNCATE TO ZERO AND COUNT THEM BACK ---------------------- */
    if (ufs_itrunc(tip, (off_t)0, 0, &released) != 0)
        return (928);
    if (tip->i_size != 0L)
        return (929);
    if (released != 3L)
        return (930);       /* itrunc's own count disagrees with the file */
    if (ump->um_sb.sb_tfree != before)
        return (931);       /* THE RECLAIM LEAKED: free space did not return */
    for (i = 0; i < NADDR; i++)
        if (tip->i_addr[i] != (daddr_t)0)
            return (932);   /* an address survived the truncate */

    /* ---- (c) AND THE PLATTER AGREES, not just the in-core inode -------- */
    if (VOP_FSYNC(tvp, 0, (char *)0, 1) != 0)
        return (933);
    slot = itoo((ino_t)7) * UFS_DINODESIZE;
    if (rawio(dev, itod((ino_t)7) * (daddr_t)2, PROBE_READ) != 0)
        return (934);
    if (ufs_dget32(probebuf, slot + 8) != 0L)
        return (935);       /* di_size on disk still says the old length */
    if (ufs_dget32(probebuf, slot + 12) != 0L)
        return (936);       /* di_addr[0] on disk still names a freed block */

    /* ---- (d) THE FILE STILL WORKS AFTER BEING TRUNCATED TO NOTHING -----
     *
     * Re-grow logical 0 and read it back: the bytes must be the SECOND write's.
     * This is a round trip over a block that was freed and reallocated, which
     * is the state a truncate leaves behind.
     *
     * IT IS NOT THE vinvalbuf CASE, although it was written believing it was.
     * MEASURED: with the vinvalbuf call deleted from itrunc, this stays GREEN
     * and case 951 goes red instead.  The reason is that ufs_write takes the
     * buffer for a freshly allocated block with getblk and CLEARS it -- so
     * even a stale buffer is zeroed before the new bytes go in, and the write
     * path repairs the very staleness this case was meant to detect.  Only a
     * block the write path never touches can show it, which is what the HOLE
     * read in section (f) does.  Kept, because a round trip across a reclaim
     * is worth asserting on its own account; renamed, because a case that
     * cannot fail for the reason its comment gives is worse than no comment.
     */
    for (i = 0; i < 64; i++)
        wpat[i] = (char)(0xC0 + i);
    iov.iov_base = wpat;
    iov.iov_len  = 64;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = 64;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(tvp, &u, 0, (char *)0) != 0)
        return (937);

    for (i = 0; i < 64; i++)
        probebuf[i] = (char)0;
    iov.iov_base = probebuf;
    iov.iov_len  = 64;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = 64;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(tvp, &u, 0, (char *)0) != 0)
        return (938);
    for (i = 0; i < 64; i++)
        if (probebuf[i] != (char)(0xC0 + i))
            return (939);   /* the round trip across a reclaim lost bytes */

    /* ---- (e) A PARTIAL TRUNCATE ZEROES THE TAIL ------------------------
     *
     * Shrinking to 40 bytes must leave bytes 40..1023 of block 0 as ZEROES on
     * the platter, because the file may grow again and they would become
     * readable a second time.  Upstream's reason, upstream's arithmetic, and
     * the check is raw so a cached buffer cannot answer for it.
     */
    if (ufs_itrunc(tip, (off_t)40, 0, &released) != 0)
        return (940);
    if (tip->i_size != 40L)
        return (941);
    if (released != 0L)
        return (942);       /* nothing should have been freed: one block still */
    if (tip->i_addr[0] == (daddr_t)0)
        return (943);       /* it freed the block it was told to keep */
    if (rawio(dev, tip->i_addr[0] * (daddr_t)2, PROBE_READ) != 0)
        return (944);
    for (i = 0; i < 40; i++)
        if (probebuf[i] != (char)(0xC0 + i))
            return (945);   /* the kept bytes did not survive */
    for (i = 40; i < DEV_BLKSIZE; i++)
        if (probebuf[i] != (char)0)
            return (946);   /* the tail past the new EOF was not zeroed */

    /* ---- (f) GROWING IS A HOLE -- AND THIS IS vinvalbuf's CASE ---------
     *
     * Two properties, and the second one was found by mutation rather than
     * designed.
     *
     * The stated divergence from 2.11BSD first: Reno's itrunc records the size
     * and allocates nothing, so the extended region costs no blocks (949) and
     * reads as zeroes because ufs_read serves a hole (951).
     *
     * AND 951 IS WHAT CATCHES A MISSING vinvalbuf.  Logical block 4 was
     * written earlier, cached, and then freed by the truncate to zero.  Re-
     * growing past it makes it a HOLE -- so nothing allocates it, nothing
     * writes it, and the read goes straight to getblk, which hands back the
     * buffer still holding the old contents.  A hole that reads as somebody
     * else's data is exactly the corruption vinvalbuf exists to prevent, and
     * because no write intervenes there is nothing to repair it.  Deleting the
     * call from itrunc turns this case red; section (d), which was written for
     * the job, stays green.
     */
    before = ump->um_sb.sb_tfree;
    if (ufs_itrunc(tip, (off_t)9000, 0, &released) != 0)
        return (947);
    if (tip->i_size != 9000L)
        return (948);
    if (ump->um_sb.sb_tfree != before)
        return (949);       /* growing allocated something */
    for (i = 0; i < 64; i++)
        probebuf[i] = (char)0xFF;
    iov.iov_base = probebuf;
    iov.iov_len  = 64;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)4096;
    u.uio_resid  = 64;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(tvp, &u, 0, (char *)0) != 0)
        return (950);
    for (i = 0; i < 64; i++)
        if (probebuf[i] != (char)0)
            return (951);   /* a hole read as a freed block's old contents --
                             * a missing vinvalbuf; see this section's head */

    /* ---- (g) ufs_setattr IS ftruncate REACHING THE FILESYSTEM ---------- */
    va.va_type      = VNON;
    va.va_mode      = (unsigned short)VA_UNSET;
    va.va_nlink     = VA_UNSET;
    va.va_uid       = (uid_t)VA_UNSET;
    va.va_gid       = (gid_t)VA_UNSET;
    va.va_fsid      = VA_UNSET;
    va.va_fileid    = VA_UNSET;
    va.va_blocksize = VA_UNSET;
    va.va_rdev      = (dev_t)VA_UNSET;
    va.va_atime     = (time_t)VA_UNSET;
    va.va_mtime     = (time_t)VA_UNSET;
    va.va_ctime     = (time_t)VA_UNSET;
    va.va_size      = (off_t)16;
    if (VOP_SETATTR(tvp, &va, (char *)0) != 0)
        return (952);
    if (tip->i_size != 16L)
        return (953);

    /* ...and it refuses what it cannot do, rather than ignoring it. */
    va.va_size = (off_t)VA_UNSET;
    va.va_mode = (unsigned short)0644;
    if (VOP_SETATTR(tvp, &va, (char *)0) != EPERM)
        return (954);       /* chmod without a credential must not "succeed" */
    va.va_mode  = (unsigned short)VA_UNSET;
    va.va_nlink = 2;
    if (VOP_SETATTR(tvp, &va, (char *)0) != EINVAL)
        return (955);       /* nlink is not a settable attribute */
    va.va_nlink = VA_UNSET;

    /* ---- (h) UNLINK WHILE OPEN: the release happens at the LAST ref ----
     *
     * i_nlink to zero is what a dirremove will do at 1.12c.  Until the last
     * reference goes, the file keeps its blocks -- that is the whole contract.
     * Dropping it must then free BOTH the blocks and the inode number.
     */
    before = ump->um_sb.sb_tfree;
    if (tip->i_addr[0] == (daddr_t)0)
        return (956);       /* nothing left to release: the case is vacuous */
    tip->i_nlink = 0;
    tip->i_flag |= ICHG;
    iput(tip);              /* the last reference -> vrele -> VOP_INACTIVE */

    if (ump->um_sb.sb_tfree != before + (daddr_t)1)
        return (957);       /* inactive did not give the block back */

    /* THE INODE NUMBER WENT BACK TOO, and the on-disk mode says the slot is
     * free.  Read raw: the in-core inode is gone by now. */
    if (rawio(dev, itod((ino_t)7) * (daddr_t)2, PROBE_READ) != 0)
        return (958);
    if (probebuf[slot] != (char)0 || probebuf[slot + 1] != (char)0)
        return (959);       /* di_mode on the platter still claims a file */

    /* ---- (i) PUT SLOT 7 BACK, on section (j)'s terms above ------------- */
    if (bread(devvp, itod((ino_t)7), &bp) != 0) {
        brelse(bp);
        return (960);
    }
    for (i = 0; i < UFS_DINODESIZE; i++)
        bp->b_addr[slot + i] = (char)0;
    if (bwrite(bp) != 0)
        return (960);

    return (0);
}



/* ---- THE DIRECTORY-ENTRY LAYER (UFS 1.12c-a) ---------------------------
 *
 * WHAT THIS HAS TO CATCH IS A DIRECTORY THAT STILL SCANS, and that is the
 * sharp requirement here for the same reason an inert write was the sharp one
 * above.  direnter and dirremove do not rewrite a directory; they REARRANGE
 * one in place -- trimming a live record to what its name needs and handing
 * the slack to the entry that follows, or folding a dead record into the
 * record before it.  Every wrong intermediate state of that is a directory a
 * scan walks perfectly happily: a d_reclen chain is self-describing, and one
 * that has lost an entry, gained a hole or absorbed the wrong neighbour still
 * terminates, still finds every OTHER name, and still passes anything that
 * asks whether the filesystem is consistent.  A name silently missing from
 * `ls` is the whole failure.
 *
 * SO EVERY ASSERTION IS A RAW BLOCK READ, on the bytes of the record AND on
 * the d_reclen of its neighbour, never on what a second lookup returns alone.
 * A lookup agreeing with the direnter that just ran proves the two halves of
 * one increment agree with each other, which is not the claim.
 *
 * THE DIRECTORY IS BUILT BY HAND AND IT IS NOT THE ROOT.  Inode 8 -- free on
 * this volume, checked before a byte is written, released at the end -- which
 * is the discipline inodes 5 and 7 get above.  THREE LAYOUTS are written into
 * it, each with VOP_WRITE at offset zero, because the properties below are
 * properties of a directory's SHAPE and no one shape expresses them all:
 *
 *   ROOMY        "." and a ".." whose d_reclen owns the rest of the block.
 *                What a directory with room in it looks like, and the shape
 *                that drives ni_count != 0 in both direnter and dirremove.
 *   COMPACTABLE  two ADJACENT dead records of twelve bytes and no other slack
 *                anywhere.  Neither is big enough for the name; together they
 *                are.  The only shape that reaches direnter's compaction loop.
 *   FULL         1024 bytes of records with ZERO slack, so the scan finds no
 *                usable space at all.  Drives ni_count == 0: a fresh block at
 *                the end for direnter, a first-in-block entry for dirremove.
 *
 * ni_count MEANS TWO DIFFERENT THINGS, which is why each of its two values
 * gets a case in BOTH routines.  On a create it is the SIZE of the run at
 * ni_offset and zero means "no room, start a block"; on a delete it is the
 * DISTANCE BACK to the previous entry and zero means "first in its block, just
 * clear d_ino".  They are not two branches of one behaviour, they are four
 * separate pieces of code, and a case for one says nothing about the other.
 *
 * ni_dent's NAME IS THE CALLER'S TO FILL, and this probe fills it because
 * nothing else does yet.  ufs_dirscan writes d_ino and d_reclen on a HIT;
 * d_namlen and d_name are what namei will copy out of the path once the CREATE
 * side of the walk is wired up, which is 1.12c's remaining work.  direnter
 * reads DIRSIZ(d_namlen) bytes starting at &ni_dent, so a caller that left
 * them unset would write a zero-length name -- and that is not something the
 * layer below can check on its behalf.
 */
#define DIRSCRATCH      8               /* the scratch directory's inode */
#define NMADE           4               /* names this section creates */

static char             dirimg[2 * DIRBLKSIZ];
static struct vattr     dirva;  /* what VOP_CREATE takes a mode in */
static struct nameidata dir_nd;         /* STATIC for probe_look's reason */
static char             dir_nameend[1]; /* a NUL: "last component" */
static ino_t            dir_made[NMADE];
static int              dir_nmade;

static char dndot[1]     = { '.' };
static char dndotdot[2]  = { '.', '.' };
static char dnalpha[5]   = { 'a', 'l', 'p', 'h', 'a' };
static char dnbeta[4]    = { 'b', 'e', 't', 'a' };
static char dncompact[13] = {
    'c', 'o', 'm', 'p', 'a', 'c', 't', 'e', 'd', 'n', 'a', 'm', 'e'
};

/* dirrec -- lay one record into dirimg; returns the offset past it.
 *
 * The name goes through a char pointer rather than e->d_name[i]: d_name is
 * declared at MAXNAMLEN and the record on disk is d_reclen bytes, so the
 * array's own bounds describe nothing about where this name may be written.
 */
static int
dirrec(off, ino, reclen, nm, n)
int   off;
int   ino;
int   reclen;
char *nm;
int   n;
{
    struct direct *e;
    char          *d;
    int            i;

    e = (struct direct *)&dirimg[off];
    e->d_ino    = (ino_t)ino;
    e->d_reclen = (unsigned short)reclen;
    e->d_namlen = (unsigned short)n;
    d = (char *)e + DIRHDRSIZ;
    for (i = 0; i < n; i++)
        d[i] = nm[i];
    return (off + reclen);
}

/* dirfill -- `count` live records with three-byte names and a d_reclen of
 * exactly DIRSIZ(3).  ZERO SLACK is the point: reclen equals what the name
 * needs, so the slot search finds nothing to give away and a directory built
 * of these is FULL in the only sense the scan cares about. */
static int
dirfill(off, count)
int off;
int count;
{
    char nm[3];
    int  i;

    for (i = 0; i < count; i++) {
        nm[0] = 'f';
        nm[1] = (char)('a' + (i / 26));
        nm[2] = (char)('a' + (i % 26));
        off = dirrec(off, (int)UFS_ROOTINO, DIRSIZ(3), nm, 3);
    }
    return (off);
}

/* dirwrite -- replace the scratch directory's contents with dirimg[0..len).
 *
 * i_size IS ZEROED FIRST so the write SETS it rather than extending it: these
 * layouts replace one another, and a 512-byte one written over a 1024-byte one
 * would leave the tail of the previous shape for the next scan to walk. */
static int
dirwrite(dvp, dip, len)
struct vnode *dvp;
struct inode *dip;
int           len;
{
    struct uio   u;
    struct iovec iov;

    dip->i_size  = (off_t)0;
    iov.iov_base = dirimg;
    iov.iov_len  = len;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = (unsigned short)len;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    return (VOP_WRITE(dvp, &u, IO_SYNC, (char *)0));
}

/* dirlook -- drive VOP_LOOKUP for an operation that will MODIFY the directory.
 *
 * LOCKPARENT IS ALWAYS SET, and not for symmetry: a CREATE or RENAME miss on
 * the last component unlocks the parent unless the caller asked to keep it,
 * and every caller here is about to hand that same directory to direnter.
 *
 * ni_dvp IS SET HERE.  ufs_lookup does not set it -- namei does -- and
 * direnter, dirremove and maknode all reach the directory through it.
 *
 * THE PARENT LOCK IS TAKEN AND GIVEN BACK HERE (UFS 1.12d), and both halves
 * need saying because neither is what namei does.
 *
 * TAKEN, because a locked parent is VOP_LOOKUP's precondition: ufs_lookup
 * unlocks dvp in its ".." arm and in the miss arm, and an unlock of something
 * that was never locked is a panic.  namei takes it once per component; these
 * cases hold ONE directory across dozens of operations, so it is re-taken per
 * call here instead.
 *
 * GIVEN BACK, because the alternative is worse.  Every directory these cases
 * keep -- the scratch directory, the subdirectories they make -- is also a
 * directory they LOOK UP BY NAME, and iget returns a locked inode: a lookup
 * that reaches a directory this process already holds waits in ufs_ihashget
 * for a lock it is itself holding.  That wait is BEFORE ufs_lock's
 * self-deadlock check, so it is a hang and not a panic.  Reno never meets
 * this because a syscall holds nothing between namei calls; a probe that
 * keeps handles for pointer comparison does, and holding them UNLOCKED is
 * the same answer Reno's rename gives for its source (`DELETE | WANTPARENT`,
 * kern/vfs_syscalls.c -- no LOCKLEAF, so lookup() drops the leaf lock).
 *
 * WHAT THAT COSTS, stated rather than left to be discovered: the operation
 * that FOLLOWS the search runs with the parent unlocked, where namei would
 * hold it across both.  These cases cannot observe the difference -- they are
 * single-threaded, which is the same limit the guard headers already record
 * about the lock generally -- and what they do still exercise on all sixty
 * calls is ufs_lookup's own discipline: the ".." arm's unlock and re-lock,
 * the miss arm's conditional release, and the fact that every arm leaves the
 * parent locked when LOCKPARENT is set.  That last one is asserted rather
 * than assumed: the unlock below is unconditional, so an arm that dropped
 * the parent lock is a panic in ufs_unlock naming this function.
 */
static int dirlookerr;

static int
dirlook(dvp, ndp, nm, n, op)
struct vnode     *dvp;
struct nameidata *ndp;
char             *nm;
int               n;
int               op;
{
    char *d;
    int   i;

    ndp->ni_ptr      = nm;
    ndp->ni_namelen  = (short)n;
    ndp->ni_next     = dir_nameend;
    ndp->ni_nameiop  = (short)(op | LOCKPARENT);
    ndp->ni_vp       = (struct vnode *)0;
    ndp->ni_dvp      = dvp;
    ndp->ni_isdotdot = 0;
    /* CLEARED, NOT LEFT: a LOOKUP asks for no slot and the scan writes none,
     * so a stale offset from the previous call would be read as this one's. */
    ndp->ni_offset   = (off_t)0;
    ndp->ni_count    = 0;
    ndp->ni_endoff   = (off_t)0;

    /* The half of ni_dent that belongs to the caller -- see the header. */
    ndp->ni_dent.d_namlen = (unsigned short)n;
    d = (char *)&ndp->ni_dent + DIRHDRSIZ;
    for (i = 0; i < n; i++)
        d[i] = nm[i];
    d[n] = (char)0;

    VOP_LOCK(dvp);
    dirlookerr = VOP_LOOKUP(dvp, ndp);
    VOP_UNLOCK(dvp);
    return (dirlookerr);
}

/* dirkeep / dirdrop -- how these cases hold a vnode BETWEEN operations.
 *
 * A HANDLE KEPT ACROSS OTHER OPERATIONS IS KEPT UNLOCKED: the reference, not
 * the lock.  That is what a process holds a cwd or an open file as, and what
 * Reno's rename holds its SOURCE as; here it is not a preference but the only
 * thing that works.  Every directory and file these cases keep is also one
 * they LOOK UP BY NAME again -- that is usually the whole assertion, "the
 * second name reaches the same in-core inode" -- and iget returns a locked
 * inode.  A lookup reaching an inode this process already holds waits in
 * ufs_ihashget for a lock this process is itself holding, and that wait comes
 * BEFORE ufs_lock's self-deadlock check, so it is a hang naming nothing.
 *
 * THE ASSERTIONS ARE UNAFFECTED, because every one of them is about the
 * REFERENCE.  Pointer identity, i_number, i_nlink, i_size are all readable
 * through an unlocked reference; the lock excludes other writers, and there
 * are none here.
 *
 * dirdrop is the matching release, and it is a vrele rather than an iput for
 * the same reason -- see iput's header in ufs_inode.c, which is careful that
 * the two are not opposites.
 */
static struct inode *
dirkeep(ip)
struct inode *ip;
{
    VOP_UNLOCK(ITOV(ip));
    return (ip);
}

static void
dirdrop(ip)
struct inode *ip;
{
    vrele(ITOV(ip));
}

/* dirlooksrc -- find a RENAME's source, the way rename(2) finds it.
 *
 * A dirlook whose result comes back UNLOCKED, which is what makes it a
 * different function rather than a flag: every other search here wants the
 * leaf locked, and this one must not have it.  Reno's rename(2) takes its
 * source with `namei(DELETE | WANTPARENT | SAVESTART)` -- no LOCKLEAF, so
 * lookup() drops the leaf lock before returning (kern/vfs_lookup.c:381).
 *
 * TWO SEPARATE THINGS DEPEND ON IT, and the second is the one that is easy to
 * miss.  ufs_rename releases the source with vrele, so a locked source is
 * left locked forever -- that much is visible in the operation.  But the
 * TARGET lookup happens first, and it locks the target's PARENT: rename a
 * directory into its own subtree and that parent IS the source.  So a locked
 * source deadlocks before ufs_rename is even called, which is what case 1146
 * found -- `mv sbx sbx/kid` locking sbx twice, once as the thing being moved
 * and once as the directory being moved into.
 *
 * CASE 1146 IS ITS ARM, and it is a real one rather than a nod: take the
 * unlock out and that case does not report a wrong answer, it STOPS, because
 * the target lookup waits in ufs_ihashget for a lock this same process holds.
 * The lock cases proper are in ufs_vnprobe.c's lockguard -- they belong to
 * the gate that owns lookup, and ufsprobe.mod at THIS gate has 1,241 bytes
 * free against that gate's 40,179.
 */
static int
dirlooksrc(dvp, ndp, nm, n)
struct vnode     *dvp;
struct nameidata *ndp;
char             *nm;
int               n;
{
    int error;

    error = dirlook(dvp, ndp, nm, n, DELETE);
    if (error == 0 && ndp->ni_vp != (struct vnode *)0)
        VOP_UNLOCK(ndp->ni_vp);
    return (error);
}

/* dirrename -- VOP_RENAME with the source handed over the way Reno hands it.
 *
 * THE SOURCE ARRIVES UNLOCKED AND THE TARGET LOCKED, and the asymmetry is
 * upstream's rather than this file's: ufs_rename releases the source with
 * vrele and the target with iput, which is only consistent if they arrive
 * that way.  Reno's rename(2) takes the source through `namei(DELETE |
 * WANTPARENT | SAVESTART)` -- no LOCKLEAF, so lookup() drops the leaf lock on
 * the way out -- and the target through `RENAME | LOCKPARENT | LOCKLEAF`
 * (kern/vfs_syscalls.c).  dirlook calls VOP_LOOKUP directly and VOP_LOOKUP
 * always returns ni_vp LOCKED, so standing in for lookup() means doing what
 * lookup() would have done with the flags rename uses.
 *
 * IT IS NOT COSMETIC.  Handing the source in locked leaves it locked after
 * ufs_rename's vrele, and the next lookup that reaches that inode waits in
 * ufs_ihashget for a lock nothing will release.
 */
static int
dirrename(fndp, tndp)
struct nameidata *fndp;
struct nameidata *tndp;
{
    /* THE UNLOCK IS dirlooksrc's, NOT THIS FUNCTION'S, and it was here first.
     * Doing it at the source LOOKUP rather than at the rename is what makes
     * `mv sbx sbx/kid` work: the target lookup between the two locks the
     * source as a parent.  See dirlooksrc. */
    if (VOP_ISLOCKED(fndp->ni_vp))
        kc_panic("rename: source is locked");
    return (VOP_RENAME(fndp, tndp));
}

/* dirat -- the record at byte `off` of a directory block, READ RAW.
 *
 * A filesystem block is 1024 bytes and rawio moves 512, so the sector is
 * chosen here rather than at seven call sites.  probebuf then holds that
 * sector and the returned pointer is into it. */
static struct direct *
dirat(dev, dblk, off)
int     dev;
daddr_t dblk;
int     off;
{
    if (rawio(dev, dblk * (daddr_t)2 + (daddr_t)(off / DIRBLKSIZ),
              PROBE_READ) != 0)
        return ((struct direct *)0);
    return ((struct direct *)&probebuf[off & (DIRBLKSIZ - 1)]);
}

/* dirnamed -- does the record at `e` carry exactly this name?
 *
 * BOTH HALVES, and the length alone is not one of them: 1.11c's case 855
 * exists because a dirmatch that compared d_namlen and never the bytes passed
 * every case written before it. */
static int
dirnamed(e, nm, n)
struct direct *e;
char          *nm;
int            n;
{
    char *d;
    int   i;

    if ((int)e->d_namlen != n)
        return (0);
    d = (char *)e + DIRHDRSIZ;
    for (i = 0; i < n; i++) {
        if (d[i] != nm[i])
            return (0);
    }
    return (1);
}

static int
dirguard(dev, devvp, mp)
int           dev;
struct vnode *devvp;
struct mount *mp;
{
    struct inode    *dip;
    struct vnode    *dvp;
    struct inode    *ip;
    struct ufsmount *ump;
    struct direct   *e;
    struct buf      *bp;
    daddr_t          dblk;
    daddr_t          nblk;
    ino_t            made;
    ino_t            zap;
    int              tinode;
    int              savenfree;
    int              g;
    int              i;
    int              off;
    int              slot;

    dir_nmade = 0;

    if (iget(mp, (ino_t)DIRSCRATCH, &dip) != 0)
        return (970);
    dvp = ITOV(dip);
    if (dip->i_mode != 0) {
        iput(dip);
        return (971);       /* slot 8 is NOT free -- do not write on it */
    }
    /* THE SCRATCH DIRECTORY IS HELD UNLOCKED FROM HERE ON.  iget hands it
     * over locked (UFS 1.12d) and dirlook takes the lock for itself on every
     * search, so keeping it would double-lock the first one -- and there is
     * nothing between operations for it to protect in a probe that is the
     * only thing running.  See dirlook's header. */
    VOP_UNLOCK(dvp);
    ump = ITOUMP(dip);

    dip->i_mode  = (unsigned short)(IFDIR | 0755);
    dip->i_nlink = 2;
    dip->i_size  = (off_t)0;
    dvp->v_type  = VDIR;

    /* ---- (a) THE ROOMY SHAPE: direnter WITH ni_count != 0 --------------- */
    for (i = 0; i < 2 * DIRBLKSIZ; i++)
        dirimg[i] = (char)0;
    off = dirrec(0, DIRSCRATCH, DIRSIZ(1), dndot, 1);
    off = dirrec(off, (int)UFS_ROOTINO, DIRBLKSIZ - off, dndotdot, 2);
    if (off != DIRBLKSIZ)
        return (972);
    if (dirwrite(dvp, dip, DIRBLKSIZ) != 0)
        return (973);
    if (dip->i_size != (off_t)DIRBLKSIZ)
        return (974);
    dblk = dip->i_addr[0];
    if (dblk == (daddr_t)0)
        return (975);

    if (dirlook(dvp, &dir_nd, dnalpha, 5, CREATE) != ENOENT)
        return (976);       /* a name that is not there must MISS */
    /* ".." owns 504 bytes and needs 12, so the scan finds a run and says so.
     * A ni_count of zero here would mean it had found nothing, and direnter
     * would start a fresh block at the end of a directory with 492 free bytes
     * sitting in it. */
    if (dir_nd.ni_count == 0)
        return (977);
    if (dir_nd.ni_offset != (off_t)DIRSIZ(1))
        return (978);       /* the run starts at the ".." record */

    dirva.va_type = VREG;
    dirva.va_mode = 0644;
    if (VOP_CREATE(&dir_nd, &dirva) != 0)
        return (979);
    if (dir_nd.ni_vp == (struct vnode *)0)
        return (980);
    ip = VTOI(dir_nd.ni_vp);
    made = ip->i_number;
    dir_made[dir_nmade] = made;
    dir_nmade = dir_nmade + 1;
    if (ip->i_nlink != 1 || (ip->i_mode & IFMT) != IFREG)
        return (981);
    iput(ip);

    /* THE BYTES ARE ON THE PLATTER, and this comes FIRST for a reason the
     * arms measured rather than a reason of taste.  Written the other way
     * round -- lookup first, raw read second -- BOTH of the mutations aimed at
     * the bytes reported the LOOKUP's case instead: a record the scan cannot
     * reach is invisible whether its contents are wrong or its neighbour was
     * left claiming its span, so the lookup answers first and answers for
     * everything.  Asserting the platter before the lookup is what makes each
     * arm name the property it broke.
     *
     * The new record goes where the trimmed ".." now ends. */
    e = dirat(dev, dblk, DIRSIZ(1) + DIRSIZ(2));
    if (e == (struct direct *)0)
        return (982);
    if (e->d_ino != made)
        return (983);
    if (!dirnamed(e, dnalpha, 5))
        return (984);

    /* AND THE NEIGHBOUR WAS TRIMMED.  ".." owned the whole block and now owns
     * exactly what its name needs; the slack became the new record's d_reclen.
     * A direnter that skipped the trim leaves two records claiming one span --
     * and the block still scans, it just scans STRAIGHT PAST the new name,
     * because ".." still says the next record is at the end of the block. */
    e = dirat(dev, dblk, DIRSIZ(1));
    if (e == (struct direct *)0)
        return (985);
    if ((int)e->d_reclen != DIRSIZ(2))
        return (986);

    /* ...AND THE NAME IS FINDABLE.  What this adds over the four cases above
     * is the WALK: the bytes being right does not prove the chain that has to
     * arrive at them is. */
    if (dirlook(dvp, &dir_nd, dnalpha, 5, LOOKUP) != 0)
        return (987);
    if (dir_nd.ni_vp == (struct vnode *)0)
        return (988);
    if (VTOI(dir_nd.ni_vp)->i_number != made)
        return (989);
    iput(VTOI(dir_nd.ni_vp));   /* ni_vp comes back LOCKED -- see ufs_lookup */

    /* ---- (b) AND OUT AGAIN: dirremove WITH ni_count != 0 ---------------- */
    if (dirlook(dvp, &dir_nd, dnalpha, 5, DELETE) != 0)
        return (990);
    if (dir_nd.ni_count == 0)
        return (991);       /* alpha does not start its block */
    if (VOP_REMOVE(&dir_nd) != 0)
        return (992);
    if (dirlook(dvp, &dir_nd, dnalpha, 5, LOOKUP) != ENOENT)
        return (993);

    /* THE RECORD IS ABSORBED, NOT REMOVED.  ".." gets its span back, which is
     * the only way the block stays walkable: nothing moves and nothing is
     * shortened. */
    e = dirat(dev, dblk, DIRSIZ(1));
    if (e == (struct direct *)0)
        return (994);
    if ((int)e->d_reclen != DIRBLKSIZ - DIRSIZ(1))
        return (995);
    /* ...AND THE SPACE IS REUSABLE, which is what "the chain still walks"
     * actually means here.  A lookup of "." would NOT say this: ufs_lookup
     * answers that one from the vnode it was handed and never reads a byte of
     * the directory, so it passes over any block at all.  Asking the scan
     * where the name would go next is a real walk of the record it just
     * rewrote, and the answer names the whole span again. */
    if (dirlook(dvp, &dir_nd, dnalpha, 5, CREATE) != ENOENT)
        return (996);
    if (dir_nd.ni_offset != (off_t)DIRSIZ(1))
        return (1034);
    if (dir_nd.ni_count != DIRBLKSIZ - DIRSIZ(1))
        return (1035);

    /* ---- (c) COMPACTION: TWO GAPS, NEITHER ENOUGH ALONE ----------------- */
    for (i = 0; i < 2 * DIRBLKSIZ; i++)
        dirimg[i] = (char)0;
    off = dirrec(0, DIRSCRATCH, DIRSIZ(1), dndot, 1);
    off = dirrec(off, (int)UFS_ROOTINO, DIRSIZ(2), dndotdot, 2);
    off = dirrec(off, 0, DIRSIZ(3), dndotdot, 2);   /* DEAD: d_ino is zero */
    off = dirrec(off, 0, DIRSIZ(3), dndotdot, 2);   /* DEAD, and ADJACENT */
    off = dirfill(off, (DIRBLKSIZ - off) / DIRSIZ(3));
    if (off != DIRBLKSIZ)
        return (997);       /* the layout must fill the block EXACTLY */
    if (dirwrite(dvp, dip, DIRBLKSIZ) != 0)
        return (998);
    dblk = dip->i_addr[0];

    /* DIRSIZ(13) is 20: more than either dead record's 12, less than the 24
     * they make together.  So SLOT_FOUND cannot fire and SLOT_COMPACT must. */
    if (dirlook(dvp, &dir_nd, dncompact, 13, CREATE) != ENOENT)
        return (999);
    if (dir_nd.ni_offset != (off_t)(DIRSIZ(1) + DIRSIZ(2)))
        return (1000);      /* the run starts at the FIRST dead record... */
    if (dir_nd.ni_count != 2 * DIRSIZ(3))
        return (1001);      /* ...and spans both of them */
    dirva.va_type = VREG;
    dirva.va_mode = 0644;
    if (VOP_CREATE(&dir_nd, &dirva) != 0)
        return (1002);
    ip = VTOI(dir_nd.ni_vp);
    made = ip->i_number;
    dir_made[dir_nmade] = made;
    dir_nmade = dir_nmade + 1;
    iput(ip);

    e = dirat(dev, dblk, DIRSIZ(1) + DIRSIZ(2));
    if (e == (struct direct *)0)
        return (1003);
    if (e->d_ino != made)
        return (1004);
    if (!dirnamed(e, dncompact, 13))
        return (1005);
    /* THE TWO RECORDS BECAME ONE, so the new entry owns both spans.  An entry
     * written into the first gap alone would carry a d_reclen of 12 and a name
     * that runs past the end of its own record. */
    if ((int)e->d_reclen != 2 * DIRSIZ(3))
        return (1006);

    /* ---- (d) THE FULL SHAPE, 1024 BYTES WITH NO SLACK ------------------- */
    for (i = 0; i < 2 * DIRBLKSIZ; i++)
        dirimg[i] = (char)0;
    off = dirrec(0, DIRSCRATCH, DIRSIZ(1), dndot, 1);
    off = dirrec(off, (int)UFS_ROOTINO, DIRSIZ(2), dndotdot, 2);
    off = dirfill(off, (DIRBLKSIZ - off) / DIRSIZ(3));
    if (off != DIRBLKSIZ)
        return (1007);
    /* The second 512-byte block the same way: forty-two records of twelve and
     * one of eight, which is 512 with nothing left over. */
    off = dirfill(off, (DIRBLKSIZ - DIRSIZ(1)) / DIRSIZ(3));
    off = dirrec(off, (int)UFS_ROOTINO, DIRSIZ(1), dndot, 1);
    if (off != 2 * DIRBLKSIZ)
        return (1008);
    if (dirwrite(dvp, dip, 2 * DIRBLKSIZ) != 0)
        return (1009);
    if (dip->i_size != (off_t)(2 * DIRBLKSIZ))
        return (1010);

    /* ---- (e) A CREATE THAT CANNOT ALLOCATE LEAKS NO INODE --------------
     *
     * maknode's failure arm is reachable only when direnter fails AFTER the
     * inode has been allocated and written, and on this volume the one way to
     * arrange that without contriving anything is a FULL DISK: ni_count == 0
     * makes direnter extend the directory, extending it allocates a block, and
     * ufs_balloc refuses at sb_nfree == 0.  So the free list is emptied IN
     * CORE for exactly this call and put straight back; the platter's copy is
     * never touched, and the caller's ufs_sbupdate restores it regardless.
     *
     * THE ORACLE IS sb_tinode AND NOT sb_ninode.  ufs_ifree has an arm that
     * throws the NUMBER away when its cache is full and still owes the COUNT,
     * so the cache is not a witness to this and the total is.
     */
    tinode    = (int)ump->um_sb.sb_tinode;
    savenfree = (int)ump->um_sb.sb_nfree;
    ump->um_sb.sb_nfree = 0;
    g = dirlook(dvp, &dir_nd, dnbeta, 4, CREATE);
    if (g != ENOENT) {
        g = 1011;
    } else if (dir_nd.ni_count != 0) {
        g = 1012;           /* nothing free anywhere: the scan must say so */
    } else if (VOP_CREATE(&dir_nd, &dirva) == 0) {
        g = 1013;           /* a create on a full disk must FAIL */
    } else {
        g = 0;
    }
    ump->um_sb.sb_nfree = (short)savenfree;
    if (g)
        return (g);
    if ((int)ump->um_sb.sb_tinode != tinode)
        return (1014);      /* the failed create kept the inode */

    /* ---- (f) direnter WITH ni_count == 0: A FRESH BLOCK AT THE END ------ */
    if (dirlook(dvp, &dir_nd, dnbeta, 4, CREATE) != ENOENT)
        return (1015);
    if (dir_nd.ni_count != 0)
        return (1016);
    if (dir_nd.ni_offset != (off_t)(2 * DIRBLKSIZ))
        return (1017);      /* on a DIRBLKSIZ boundary, past the contents */
    dirva.va_type = VREG;
    dirva.va_mode = 0644;
    if (VOP_CREATE(&dir_nd, &dirva) != 0)
        return (1018);
    ip = VTOI(dir_nd.ni_vp);
    made = ip->i_number;
    dir_made[dir_nmade] = made;
    dir_nmade = dir_nmade + 1;
    iput(ip);

    /* THE SIZE IS ROUNDED TO THE WHOLE BLOCK, not left at the end of the
     * record just written: the new entry's d_reclen owns the rest of its
     * block, and a size that stopped short would make the next create believe
     * the block was full. */
    if (dip->i_size != (off_t)(3 * DIRBLKSIZ))
        return (1019);
    nblk = dip->i_addr[1];
    if (nblk == (daddr_t)0)
        return (1020);      /* a block was allocated to hold it */
    e = dirat(dev, nblk, 0);
    if (e == (struct direct *)0)
        return (1021);
    if (e->d_ino != made)
        return (1022);
    if (!dirnamed(e, dnbeta, 4))
        return (1023);
    if ((int)e->d_reclen != DIRBLKSIZ)
        return (1024);

    /* ---- (g) dirremove WITH ni_count == 0: FIRST IN ITS BLOCK ----------- */
    if (dirlook(dvp, &dir_nd, dnbeta, 4, DELETE) != 0)
        return (1025);
    if (dir_nd.ni_count != 0)
        return (1026);      /* it starts a block: there is no record before it */
    if (VOP_REMOVE(&dir_nd) != 0)
        return (1027);
    if (dirlook(dvp, &dir_nd, dnbeta, 4, LOOKUP) != ENOENT)
        return (1028);
    /* THE RECORD STAYS AND KEEPS ITS SPAN.  Only d_ino is cleared: a dirremove
     * that also shortened d_reclen would leave the chain pointing into the
     * middle of space the record still owns. */
    e = dirat(dev, nblk, 0);
    if (e == (struct direct *)0)
        return (1029);
    if (e->d_ino != (ino_t)0)
        return (1030);
    if ((int)e->d_reclen != DIRBLKSIZ)
        return (1031);
    /* ...AND THE CLEARED RECORD IS VISIBLE AS FREE SPACE, which is the half a
     * raw read cannot see: the scan has to reach the third block through two
     * full ones and read a d_ino of zero as a gap.  ni_count is the record's
     * whole span, so nothing was lost on the way in either. */
    if (dirlook(dvp, &dir_nd, dnbeta, 4, CREATE) != ENOENT)
        return (1032);
    if (dir_nd.ni_offset != (off_t)(2 * DIRBLKSIZ))
        return (1036);
    if (dir_nd.ni_count != DIRBLKSIZ)
        return (1037);

    /* ---- PUT IT ALL BACK ------------------------------------------------
     *
     * The scratch directory goes out through the release path 1.12b built --
     * i_nlink zero and iput, which is what ufs_remove would have left behind
     * -- so ufs_inactive frees its blocks and its number.  ITS MODE IS LEFT
     * SET: inactive's first arm vgones a mode-zero inode on the spot without
     * reclaiming anything, and the blocks are the point.
     *
     * The i-list slots are then zeroed through the BUFFER CACHE, so the cached
     * copy and the platter agree -- writeguard's rule, for writeguard's
     * reason.  The blocks go back with the caller's ufs_sbupdate.
     */
    dip->i_nlink = 0;
    dip->i_flag |= ICHG;
    vrele(ITOV(dip));       /* UNLOCKED since the head of this guard, so the
                             * release is a vrele and not an iput -- and it
                             * still reaches ufs_inactive, which is the point */

    for (i = 0; i <= dir_nmade; i++) {
        if (i == dir_nmade)
            zap = (ino_t)DIRSCRATCH;
        else
            zap = dir_made[i];
        if (bread(devvp, itod(zap), &bp) != 0) {
            brelse(bp);
            return (1033);
        }
        slot = itoo(zap) * UFS_DINODESIZE;
        for (off = 0; off < UFS_DINODESIZE; off++)
            bp->b_addr[slot + off] = (char)0;
        if (bwrite(bp) != 0)
            return (1033);
    }

    return (0);
}



/* ---- THE REST OF DIRECTORY MUTATION (UFS 1.12c-b) ----------------------
 *
 * link, symlink, mkdir and rmdir, on a scratch directory of their own (inode
 * 9, checked free, released at the end) so that nothing here depends on what
 * dirguard left behind.
 *
 * WHAT EACH ONE HAS TO CATCH IS DIFFERENT, and that is why they are not one
 * case each:
 *
 *   link      is the operation that makes i_nlink MEAN something.  Everything
 *             1.12b built around a count reaching zero is inert while every
 *             file has exactly one name, so the case that matters is not that
 *             a second name appears -- it is that removing the FIRST one
 *             leaves the file reachable through the second.
 *   symlink   is a FORMAT claim: the contents are the path, i_size is its
 *             length, and there is no terminator on the volume.  1.12a's
 *             readlink probe asserted that against a symlink this probe built
 *             BY HAND; this is the side that makes one the way the kernel
 *             will.
 *   mkdir     must produce a directory that can be WALKED, which means "." and
 *             ".." exist, name the right inodes, and span the block with no
 *             gap.  A mkdir that gets the parent's link count wrong instead
 *             leaves a directory nothing can ever remove.
 *   rmdir     is mostly its REFUSALS.  Emptying a directory that was not empty
 *             detaches every name inside it and nothing will look for them
 *             again, so both halves of the precondition get a case: the link
 *             count says nobody else names this directory, dirempty says it
 *             names nobody else, and either alone lets a populated directory
 *             through.
 */
#define DIRSCRATCH2     9               /* this section's scratch directory */
#define NMADE2          16

static ino_t dir2_made[NMADE2];
static int   dir2_nmade;

static char dnlsrc[4]  = { 'l', 's', 'r', 'c' };
static char dnldst[4]  = { 'l', 'd', 's', 't' };
static char dnslnk[4]  = { 's', 'l', 'n', 'k' };
static char dnsub[3]   = { 's', 'u', 'b' };
static char dnkid[3]   = { 'k', 'i', 'd' };

/* The symlink target.  A PATH RATHER THAN A PATTERN, so a reader looking at
 * the raw block can see that this is what it is.  NOT NUL-terminated on the
 * volume: i_size is the length and the string carries no terminator. */
#define SLNKLEN         12
static char lnkback[SLNKLEN];   /* STATIC: see probe_nd's note on automatics */
static char slnktarg[SLNKLEN + 1] = {
    '/', 'u', 's', 'r', '/', 'l', 'i', 'b', '/', 'a', 'b', 'c', '\0'
};

/* namei's own names.  A relative target on purpose: an ABSOLUTE one restarts
 * the walk at rootdir, which on this machine is ProDOS and has nothing to do
 * with the scratch volume. */
static char dntgt[3]  = { 't', 'g', 't' };
static char dnlnk[3]  = { 'l', 'n', 'k' };
static char dndlk[3]  = { 'd', 'l', 'k' };
static char dnnd[2]   = { 'n', 'd' };
static char dnin[2]   = { 'i', 'n' };
static char dnla[2]   = { 'l', 'a' };
static char dnlb[2]   = { 'l', 'b' };
static char pthtgt[4]   = { 't', 'g', 't', 0 };
static char pthlnk[4]   = { 'l', 'n', 'k', 0 };
static char pthdlkin[7] = { 'd', 'l', 'k', '/', 'i', 'n', 0 };
static char pthla[3]    = { 'l', 'a', 0 };
static char pthnd[3]    = { 'n', 'd', 0 };
static char pthlb[3]    = { 'l', 'b', 0 };

/* nwalk -- one path resolution from `cdir`, the way a syscall would do it. */
static int
nwalk(path, cdir, op, vpp)
char          *path;
struct vnode  *cdir;
int            op;
struct vnode **vpp;
{
    struct nameidata *w;
    int               error;

    *vpp = (struct vnode *)0;
    w = ndslot(1, 0);
    if (w == (struct nameidata *)0)
        return (EINVAL);
    w->ni_dirp    = path;
    w->ni_segflg  = UIO_SYSSPACE;
    w->ni_nameiop = (short)op;
    w->ni_cdir    = cdir;
    w->ni_rdir    = (struct vnode *)0;
    w->ni_vp      = (struct vnode *)0;
    w->ni_dvp     = (struct vnode *)0;
    /* THE WORKING DIRECTORY GOES IN UNLOCKED, which is namei's precondition
     * rather than a courtesy: its loop takes VOP_LOCK on every directory it
     * descends into, starting with this one, so a directory this process
     * already held would be "locking against myself".  Nothing is needed here
     * to arrange that -- these cases hold their directories unlocked between
     * operations, which is dirlook's whole reason for giving the parent lock
     * back, and it is what a process holds a cwd as. */
    error = namei(w);
    if (error == 0)
        *vpp = w->ni_vp;
    return (error);
}

/* dirsym -- make a symlink whose target is `t`, `n` bytes, in `dvp`. */
static char dirsymbuf[8];

static int
dirsym(dvp, nm, n, t, tn, madep)
struct vnode *dvp;
char         *nm;
int           n;
char         *t;
int           tn;
ino_t        *madep;
{
    int i;

    for (i = 0; i < tn; i++)
        dirsymbuf[i] = t[i];
    dirsymbuf[tn] = (char)0;
    if (dirlook(dvp, &dir_nd, nm, n, CREATE) != ENOENT)
        return (1);
    dirva.va_type = VLNK;
    dirva.va_mode = 0777;
    if (VOP_SYMLINK(&dir_nd, &dirva, dirsymbuf) != 0)
        return (1);
    if (dirlook(dvp, &dir_nd, nm, n, LOOKUP) != 0)
        return (1);
    *madep = VTOI(dir_nd.ni_vp)->i_number;
    iput(VTOI(dir_nd.ni_vp));
    return (0);
}


/* dir2make -- create a plain file in the scratch directory and keep its
 * number, so the restore can put its i-list slot back. */
static int
dir2make(dvp, nm, n, ipp)
struct vnode  *dvp;
char          *nm;
int            n;
struct inode **ipp;
{
    int error;

    error = dirlook(dvp, &dir_nd, nm, n, CREATE);
    if (error != ENOENT)
        return (1);
    dirva.va_type = VREG;
    dirva.va_mode = 0644;
    if (VOP_CREATE(&dir_nd, &dirva) != 0)
        return (1);
    *ipp = dirkeep(VTOI(dir_nd.ni_vp));
    dir2_made[dir2_nmade] = (*ipp)->i_number;
    dir2_nmade = dir2_nmade + 1;
    return (0);
}

/* dir2unlink -- remove a name the way unlink(2) will. */
static int
dir2unlink(dvp, nm, n)
struct vnode *dvp;
char         *nm;
int           n;
{
    if (dirlook(dvp, &dir_nd, nm, n, DELETE) != 0)
        return (1);
    if (VOP_REMOVE(&dir_nd) != 0)
        return (1);
    return (0);
}

/* dirfind -- the record carrying this name, found by walking the raw block.
 *
 * WHY NOT A FIXED OFFSET, which is what the 1.12c-a cases use: there, WHERE
 * the record lands IS the property -- compaction is what those cases are
 * about.  Here it is incidental, and predicting it means re-deriving direnter's
 * trimming by hand at every call site.  The first two attempts got it wrong
 * (cases 1050 and 1082 fired on a correct kernel) because each create trims
 * the record before it, so every later entry moves.
 *
 * Walking d_reclen from the raw bytes asserts something the offset never did,
 * as well: that the chain on the PLATTER is walkable, independently of the
 * kernel scan that also has to walk it.
 */
static struct direct *
dirfind(dev, dblk, nm, n)
int      dev;
daddr_t  dblk;
char    *nm;
int      n;
{
    struct direct *e;
    int            off;
    int            reclen;

    off = 0;
    while (off < DIRBLKSIZ) {
        e = dirat(dev, dblk, off);
        if (e == (struct direct *)0)
            return ((struct direct *)0);
        reclen = (int)e->d_reclen;
        if (reclen < DIRHDRSIZ || (reclen & 3) != 0 ||
            off + reclen > DIRBLKSIZ)
            return ((struct direct *)0);    /* corrupt: stop, do not guess */
        if (e->d_ino != (ino_t)0 && dirnamed(e, nm, n))
            return (e);
        off = off + reclen;
    }
    return ((struct direct *)0);
}


static int
dirguard2(dev, devvp, mp)
int           dev;
struct vnode *devvp;
struct mount *mp;
{
    struct inode  *dip;
    struct vnode  *dvp;
    struct inode  *ip;
    struct inode  *sip;
    struct vnode  *svp;
    struct direct *e;
    struct buf    *bp;
    struct uio     u;
    struct iovec   iov;
    daddr_t        dblk;
    daddr_t        sblk;
    ino_t          made;
    ino_t          zap;
    int            i;
    int            off;
    int            slot;

    dir2_nmade = 0;

    if (iget(mp, (ino_t)DIRSCRATCH2, &dip) != 0)
        return (1038);
    dvp = ITOV(dip);
    if (dip->i_mode != 0) {
        iput(dip);
        return (1039);      /* slot 9 is NOT free -- do not write on it */
    }
    /* THE SCRATCH DIRECTORY IS HELD UNLOCKED FROM HERE ON.  iget hands it
     * over locked (UFS 1.12d) and dirlook takes the lock for itself on every
     * search, so keeping it would double-lock the first one -- and there is
     * nothing between operations for it to protect in a probe that is the
     * only thing running.  See dirlook's header. */
    VOP_UNLOCK(dvp);
    dip->i_mode  = (unsigned short)(IFDIR | 0755);
    dip->i_nlink = 2;
    dip->i_size  = (off_t)0;
    dvp->v_type  = VDIR;

    for (i = 0; i < 2 * DIRBLKSIZ; i++)
        dirimg[i] = (char)0;
    off = dirrec(0, DIRSCRATCH2, DIRSIZ(1), dndot, 1);
    off = dirrec(off, (int)UFS_ROOTINO, DIRBLKSIZ - off, dndotdot, 2);
    if (off != DIRBLKSIZ)
        return (1040);
    if (dirwrite(dvp, dip, DIRBLKSIZ) != 0)
        return (1041);
    dblk = dip->i_addr[0];

    /* ---- (a) link: A SECOND NAME FOR ONE INODE ------------------------- */
    if (dir2make(dvp, dnlsrc, 4, &ip))
        return (1042);
    made = ip->i_number;
    if (ip->i_nlink != 1)
        return (1043);
    if (dirlook(dvp, &dir_nd, dnldst, 4, CREATE) != ENOENT)
        return (1044);
    if (VOP_LINK(ITOV(ip), &dir_nd) != 0)
        return (1045);
    if (ip->i_nlink != 2)
        return (1046);

    /* BOTH NAMES REACH ONE INODE, and the POINTER is the assertion -- which
     * is what this comment always said and what the code did not do.  It
     * compared i_number, the exact oracle the sentence disavows: two in-core
     * inodes carrying one number compare equal on it, and that is precisely
     * the defect iget's hash exists to prevent.  Worse, the reference it
     * would have needed had already been dropped one line above.  The source
     * vnode is now HELD across the lookup so there is a pointer to compare.
     *
     * IT IS CORROBORATION, NOT THE PRIMARY ASSERTION, and the arm says so:
     * making iget's hash always miss fires at case 724, not here -- 1.11a
     * already asserts pointer identity for two gets of one inode, earlier and
     * correctly.  What this adds is that the SECOND NAME resolves to the same
     * in-core inode, which given 724 is implied rather than independent.  Kept
     * because it is a pointer comparison now and costs nothing; recorded
     * because a reader counting cases should not read it as covering the hash
     * on its own. */
    if (dirlook(dvp, &dir_nd, dnldst, 4, LOOKUP) != 0)
        return (1047);
    if (VTOI(dir_nd.ni_vp) != ip)
        return (1048);
    iput(VTOI(dir_nd.ni_vp));
    dirdrop(ip);
    e = dirfind(dev, dblk, dnldst, 4);
    if (e == (struct direct *)0)
        return (1049);      /* the name is not in the block's chain at all */
    if (e->d_ino != made)
        return (1050);

    /* THE CASE THE WHOLE OPERATION IS FOR.  Removing the FIRST name must
     * leave the file reachable through the second, with a count of one.  A
     * remove that freed the inode regardless would pass every case above --
     * and 1.12b's release path is what would silently be doing it. */
    if (dir2unlink(dvp, dnlsrc, 4))
        return (1051);
    if (dirlook(dvp, &dir_nd, dnldst, 4, LOOKUP) != 0)
        return (1052);
    ip = VTOI(dir_nd.ni_vp);
    if (ip->i_number != made)
        return (1053);
    if (ip->i_nlink != 1)
        return (1054);
    if (ip->i_mode == 0)
        return (1055);      /* the inode was freed out from under its name */
    iput(ip);
    if (dir2unlink(dvp, dnldst, 4))
        return (1056);

    /* ---- (b) symlink: THE CONTENTS ARE THE PATH ------------------------ */
    if (dirlook(dvp, &dir_nd, dnslnk, 4, CREATE) != ENOENT)
        return (1057);
    dirva.va_type = VLNK;
    dirva.va_mode = 0777;
    if (VOP_SYMLINK(&dir_nd, &dirva, slnktarg) != 0)
        return (1058);
    if (dirlook(dvp, &dir_nd, dnslnk, 4, LOOKUP) != 0)
        return (1059);
    sip = dirkeep(VTOI(dir_nd.ni_vp));
    svp = ITOV(sip);
    dir2_made[dir2_nmade] = sip->i_number;
    dir2_nmade = dir2_nmade + 1;
    if ((sip->i_mode & IFMT) != IFLNK)
        return (1060);
    if (svp->v_type != VLNK)
        return (1061);
    /* i_size IS THE LENGTH OF THE TARGET, with no terminator counted.  A
     * symlink written with its NUL reads back one byte too long, and every
     * path built from it carries a stray byte no lookup can match. */
    if (sip->i_size != (off_t)SLNKLEN)
        return (1062);
    sblk = sip->i_addr[0];
    if (sblk == (daddr_t)0)
        return (1063);
    e = dirat(dev, sblk, 0);            /* the raw block, read as bytes */
    if (e == (struct direct *)0)
        return (1064);
    for (i = 0; i < SLNKLEN; i++) {
        if (probebuf[i] != slnktarg[i])
            return (1065);
    }
    /* ...and it reads back through the vnode op, which is the half 1.12a
     * asserted against a hand-built link.  Now both sides are the kernel's. */
    iov.iov_base = lnkback;
    iov.iov_len  = SLNKLEN;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = (unsigned short)SLNKLEN;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READLINK(svp, &u, (char *)0) != 0)
        return (1066);
    if (u.uio_resid != 0)
        return (1067);
    for (i = 0; i < SLNKLEN; i++) {
        if (lnkback[i] != slnktarg[i])
            return (1068);
    }
    dirdrop(sip);

    /* ---- (c) mkdir: A DIRECTORY THAT CAN BE WALKED --------------------- */
    if (dirlook(dvp, &dir_nd, dnsub, 3, CREATE) != ENOENT)
        return (1069);
    dirva.va_type = VDIR;
    dirva.va_mode = 0755;
    if (VOP_MKDIR(&dir_nd, &dirva) != 0)
        return (1070);
    sip = dirkeep(VTOI(dir_nd.ni_vp));
    svp = ITOV(sip);
    made = sip->i_number;
    dir2_made[dir2_nmade] = made;
    dir2_nmade = dir2_nmade + 1;
    if ((sip->i_mode & IFMT) != IFDIR || svp->v_type != VDIR)
        return (1071);
    /* TWO LINKS: its own "." and the name the parent now carries. */
    if (sip->i_nlink != 2)
        return (1072);
    /* AND THE PARENT GAINED ONE, for the ".." inside it.  A mkdir that
     * forgets this leaves a directory whose count can never reach zero, so
     * nothing will ever remove it. */
    if (dip->i_nlink != 3)
        return (1073);
    if (sip->i_size != (off_t)DIRBLKSIZ)
        return (1074);
    sblk = sip->i_addr[0];
    if (sblk == (daddr_t)0)
        return (1075);

    e = dirat(dev, sblk, 0);
    if (e == (struct direct *)0)
        return (1076);
    if (e->d_ino != made || !dirnamed(e, dndot, 1))
        return (1077);
    if ((int)e->d_reclen != DIRSIZ(1))
        return (1078);
    e = dirat(dev, sblk, DIRSIZ(1));
    if (e == (struct direct *)0)
        return (1079);
    if (e->d_ino != (ino_t)DIRSCRATCH2 || !dirnamed(e, dndotdot, 2))
        return (1080);
    /* ".." OWNS THE REST OF THE BLOCK.  A scan walks to i_size and the records
     * must span it with no gap, so the last one absorbs the remainder -- and
     * a ".." left at DIRSIZ(2) would make the next direnter here start a
     * second block over 492 free bytes. */
    if ((int)e->d_reclen != DIRBLKSIZ - DIRSIZ(1))
        return (1081);
    /* ...and the name is in the PARENT, on the platter. */
    e = dirfind(dev, dblk, dnsub, 3);
    if (e == (struct direct *)0)
        return (1082);
    if (e->d_ino != made)
        return (1083);

    /* ---- (d) rmdir: THE REFUSALS FIRST --------------------------------- */
    /* A CHILD MAKES IT NON-EMPTY.  The count stays 2 -- a directory full of
     * FILES has exactly two links -- so this is the arm only dirempty can
     * refuse, and asserting it separately from the count is the point. */
    if (dir2make(svp, dnkid, 3, &ip))
        return (1084);
    dirdrop(ip);
    if (dirlook(dvp, &dir_nd, dnsub, 3, DELETE) != 0)
        return (1085);
    if (sip->i_nlink != 2)
        return (1086);      /* the precondition for the case below */
    if (VOP_RMDIR(&dir_nd) != ENOTEMPTY)
        return (1087);

    /* "rmdir ." IS ITS OWN ARM, because both of its names are for ONE vnode.
     * NO EXTRA REFERENCE IS TAKEN: this tree's ops release ni_vp and never
     * ni_dvp, so the lookup's vref is exactly what the refusal gives back and
     * the handle from VOP_MKDIR survives it.  Getting this wrong is what the
     * `vrele: zero usecount` panic was. */
    if (dirlook(svp, &dir_nd, dndot, 1, DELETE) != 0)
        return (1089);
    if (dir_nd.ni_vp != svp)
        return (1090);
    if (VOP_RMDIR(&dir_nd) != EINVAL)
        return (1091);

    /* ---- (e) ...AND THEN IT SUCCEEDS ----------------------------------- */
    if (dir2unlink(svp, dnkid, 3))
        return (1092);

    /* THE OTHER HALF OF THE PRECONDITION, and it needs its own case because
     * the two halves refuse different directories.  This one is EMPTY, so
     * dirempty would allow it; a third link means somebody else still names
     * it, and only the count can say so.  Without this case a rmdir that
     * dropped the count test entirely stays green. */
    sip->i_nlink = 3;
    if (dirlook(dvp, &dir_nd, dnsub, 3, DELETE) != 0)
        return (1102);
    if (VOP_RMDIR(&dir_nd) != ENOTEMPTY)
        return (1103);
    sip->i_nlink = 2;

    if (dirlook(dvp, &dir_nd, dnsub, 3, DELETE) != 0)
        return (1093);
    if (VOP_RMDIR(&dir_nd) != 0)
        return (1094);
    /* THE PARENT'S COUNT COMES BACK DOWN.  Without this an empty tree cannot
     * be dismantled: every mkdir/rmdir pair would leave the parent one link
     * heavier than it started. */
    if (dip->i_nlink != 2)
        return (1095);
    if (dirlook(dvp, &dir_nd, dnsub, 3, LOOKUP) != ENOENT)
        return (1096);
    /* ...and the directory it removed is gone from the i-list, which is
     * ufs_inactive doing 1.12b's work on a count this took to zero. */
    dirdrop(sip);              /* the last reference: inactive reclaims it here */
    if (iget(mp, made, &ip) != 0)
        return (1097);
    if (ip->i_mode != 0)
        return (1098);
    iput(ip);

    /* ---- (h) namei FOLLOWS A SYMLINK, AND KNOWS WHEN NOT TO ------------
     *
     * THE VNODE OP AND THE WALK ARE DIFFERENT CLAIMS.  Section (b) above
     * asserted that ufs_symlink writes a link and ufs_readlink reads it back;
     * this asserts that a PATH RESOLUTION goes through one.  Nothing before
     * this drove namei against a real symlink, because until 1.12c-b nothing
     * could make one.
     *
     * THE THIRD CASE IS THE ONE THAT MATTERS.  A symlink in the MIDDLE of a
     * path is followed whether or not the caller asked -- Reno's condition is
     * `(FOLLOW) || *ni_next == '/'` -- and a port that reads only the first
     * half compiles, passes the other three cases here, and fails every
     * `cat /usr/link/file` in the system.
     */
    {
        struct vnode *wvp;
        ino_t         tgtino;
        ino_t         inino;
        ino_t         ndino;
        int           e2;

        if (dir2make(dvp, dntgt, 3, &ip))
            return (1184);
        tgtino = ip->i_number;
        dirdrop(ip);

        if (dirlook(dvp, &dir_nd, dnnd, 2, CREATE) != ENOENT)
            return (1185);
        dirva.va_type = VDIR;
        dirva.va_mode = 0755;
        if (VOP_MKDIR(&dir_nd, &dirva) != 0)
            return (1186);
        sip   = dirkeep(VTOI(dir_nd.ni_vp));
        svp   = ITOV(sip);
        ndino = sip->i_number;
        dir2_made[dir2_nmade] = ndino;
        dir2_nmade = dir2_nmade + 1;
        if (dir2make(svp, dnin, 2, &ip))
            return (1187);
        inino = ip->i_number;
        dirdrop(ip);

        if (dirsym(dvp, dnlnk, 3, dntgt, 3, &made))
            return (1188);
        dir2_made[dir2_nmade] = made;
        dir2_nmade = dir2_nmade + 1;
        if (dirsym(dvp, dndlk, 3, dnnd, 2, &made))
            return (1189);
        dir2_made[dir2_nmade] = made;
        dir2_nmade = dir2_nmade + 1;

        /* FOLLOW SET: the answer is what the link points at. */
        if (nwalk(pthlnk, dvp, LOOKUP | FOLLOW, &wvp) != 0)
            return (1190);
        if (VTOI(wvp)->i_number != tgtino)
            return (1191);
        if (wvp->v_type != VREG)
            return (1192);
        vrele(wvp);

        /* FOLLOW CLEAR on the LAST component: the answer is the LINK.  This
         * is the whole of the difference between stat and lstat, and a namei
         * that followed unconditionally would return the target here. */
        if (nwalk(pthlnk, dvp, LOOKUP, &wvp) != 0)
            return (1193);
        if (wvp->v_type != VLNK)
            return (1194);
        if (VTOI(wvp)->i_number == tgtino)
            return (1195);
        vrele(wvp);

        /* FOLLOW CLEAR, and the link is NOT the last component: it must be
         * followed anyway, because there is no other way to reach "in". */
        if (nwalk(pthdlkin, dvp, LOOKUP, &wvp) != 0)
            return (1196);
        if (VTOI(wvp)->i_number != inino)
            return (1197);
        vrele(wvp);

        /* A RING IS NOT A PATH.  `la -> lb -> la` with FOLLOW must give up
         * rather than resolve forever. */
        if (dirsym(dvp, dnla, 2, dnlb, 2, &made))
            return (1198);
        dir2_made[dir2_nmade] = made;
        dir2_nmade = dir2_nmade + 1;
        if (dirsym(dvp, dnlb, 2, dnla, 2, &made))
            return (1199);
        dir2_made[dir2_nmade] = made;
        dir2_nmade = dir2_nmade + 1;
        e2 = nwalk(pthla, dvp, LOOKUP | FOLLOW, &wvp);
        if (e2 != ELOOP)
            return (1200);

        /* ...and the names go again, so the restore below sees the directory
         * it expects. */
        if (dir2unlink(svp, dnin, 2))
            return (1201);
        dirdrop(sip);
        if (dirlook(dvp, &dir_nd, dnnd, 2, DELETE) != 0)
            return (1202);
        if (VOP_RMDIR(&dir_nd) != 0)
            return (1203);
        if (dir2unlink(dvp, dnlnk, 3) || dir2unlink(dvp, dndlk, 3) ||
            dir2unlink(dvp, dnla, 2) || dir2unlink(dvp, dnlb, 2) ||
            dir2unlink(dvp, dntgt, 3))
            return (1204);
    }

    /* ---- PUT IT ALL BACK ------------------------------------------------ */
    dip->i_nlink = 0;
    dip->i_flag |= ICHG;
    vrele(ITOV(dip));       /* UNLOCKED since the head of this guard, so the
                             * release is a vrele and not an iput -- and it
                             * still reaches ufs_inactive, which is the point */

    for (i = 0; i <= dir2_nmade; i++) {
        if (i == dir2_nmade)
            zap = (ino_t)DIRSCRATCH2;
        else
            zap = dir2_made[i];
        if (bread(devvp, itod(zap), &bp) != 0) {
            brelse(bp);
            return (1099);
        }
        slot = itoo(zap) * UFS_DINODESIZE;
        for (off = 0; off < UFS_DINODESIZE; off++)
            bp->b_addr[slot + off] = (char)0;
        if (bwrite(bp) != 0)
            return (1099);
    }

    return (0);
}


/* ---- rename (UFS 1.12c-c) ----------------------------------------------
 *
 * THE CASE THIS SECTION EXISTS FOR IS 1120, and it is worth naming before the
 * rest: a rename WITHIN one directory whose step-2 direnter COMPACTS the block
 * and slides the source's own record forward.  ufs_rename recorded where the
 * source entry was before it did that, so the offset it is holding names the
 * wrong bytes by the time it comes to unlink -- and what saves it is the
 * re-lookup in step 3, which upstream does for a completely different reason
 * (it dropped locks; this tree drops none).  A reader who knows Reno would
 * delete that re-lookup as a concurrency artefact, and the directory would
 * come apart on a case nothing else here would produce.
 *
 * The layout is built to force it: a DEAD record immediately before the
 * source, and a new name needing more than either gap alone.  direnter's
 * compaction loop then slides the source down into the dead record's place.
 *
 * AND THE ARM AIMED AT IT SHOWED SOMETHING SHARPER.  Deleting the re-lookup
 * does not reach 1135 at all -- it fires at 1112, in the PLAIN rename above,
 * because ni_dent.d_reclen is stale too: the DELETE lookup recorded the
 * source record's length BEFORE step 2 trimmed it, and dirremove folds that
 * length into the record before it.  So the re-find is load-bearing on EVERY
 * rename, not only on one that compacts, and the plain case is the cheapest
 * demonstration of it.
 *
 * That leaves 1135-1137 asserting the SCENARIO rather than isolated by an arm
 * of their own, and no plausible one-line defect separates a stale offset from
 * a stale length -- both come from the same recording.  Said here rather than
 * left for a reader to assume the arms cover every case one to one.
 *
 * THE REFUSALS GET AS MUCH ROOM AS THE SUCCESSES, because rename is the one
 * operation here that can destroy an arbitrary amount of a filesystem in a
 * single call: moving a directory into its own subtree detaches everything
 * under it with no record of where it was.
 */
#define DIRSCRATCH3     10
#define NMADE3          10

static struct nameidata dir_nd2;        /* rename needs TWO */
static ino_t dir3_made[NMADE3];
static int   dir3_nmade;

static char dnra[1]    = { 'a' };
static char dnrb[2]    = { 'b', 'b' };
static char dnrlong[9] = { 'r','e','n','a','m','e','d','t','o' };
static char dnrsub[3]  = { 's', 'b', 'x' };
static char dnrsub2[3] = { 's', 'b', 'y' };
static char dnrkid[3]  = { 'k', 'd', 'z' };
static char dnrnest[3] = { 'n', 's', 't' };
static char dnrnst2[3] = { 'n', 'x', '2' };

/* dir3note -- remember an inode so the restore can zero its i-list slot. */
static void
dir3note(n)
ino_t n;
{
    if (dir3_nmade < NMADE3) {
        dir3_made[dir3_nmade] = n;
        dir3_nmade = dir3_nmade + 1;
    }
}

static int
dirguard3(dev, devvp, mp)
int           dev;
struct vnode *devvp;
struct mount *mp;
{
    struct inode  *dip;
    struct vnode  *dvp;
    struct inode  *ip;
    struct inode  *sub;
    struct vnode  *subvp;
    struct inode  *sub2;
    struct vnode  *sub2vp;
    struct inode  *nst;
    struct vnode  *nstvp;
    struct inode  *nst2;
    struct vnode  *nst2vp;
    struct direct *e;
    struct buf    *bp;
    daddr_t        dblk;
    ino_t          amade;
    ino_t          bmade;
    ino_t          submade;
    ino_t          zap;
    int            i;
    int            off;
    int            slot;

    dir3_nmade = 0;

    if (iget(mp, (ino_t)DIRSCRATCH3, &dip) != 0)
        return (1104);
    dvp = ITOV(dip);
    if (dip->i_mode != 0) {
        iput(dip);
        return (1105);
    }
    /* THE SCRATCH DIRECTORY IS HELD UNLOCKED FROM HERE ON.  iget hands it
     * over locked (UFS 1.12d) and dirlook takes the lock for itself on every
     * search, so keeping it would double-lock the first one -- and there is
     * nothing between operations for it to protect in a probe that is the
     * only thing running.  See dirlook's header. */
    VOP_UNLOCK(dvp);
    dip->i_mode  = (unsigned short)(IFDIR | 0755);
    dip->i_nlink = 2;
    dip->i_size  = (off_t)0;
    dvp->v_type  = VDIR;

    /* ---- (a) THE PLAIN CASE: a file gets a different name -------------- */
    for (i = 0; i < 2 * DIRBLKSIZ; i++)
        dirimg[i] = (char)0;
    off = dirrec(0, DIRSCRATCH3, DIRSIZ(1), dndot, 1);
    off = dirrec(off, (int)UFS_ROOTINO, DIRBLKSIZ - off, dndotdot, 2);
    if (dirwrite(dvp, dip, DIRBLKSIZ) != 0)
        return (1106);
    dblk = dip->i_addr[0];

    if (dir2make(dvp, dnra, 1, &ip))
        return (1107);
    amade = ip->i_number;
    dir3note(amade);
    dirdrop(ip);

    if (dirlooksrc(dvp, &dir_nd, dnra, 1) != 0)
        return (1108);
    if (dirlook(dvp, &dir_nd2, dnrb, 2, CREATE) != ENOENT)
        return (1109);
    if (dirrename(&dir_nd, &dir_nd2) != 0)
        return (1110);
    if (dirlook(dvp, &dir_nd, dnra, 1, LOOKUP) != ENOENT)
        return (1111);      /* the old name must be GONE */
    if (dirlook(dvp, &dir_nd, dnrb, 2, LOOKUP) != 0)
        return (1112);
    ip = VTOI(dir_nd.ni_vp);
    if (ip->i_number != amade)
        return (1113);      /* ...and the new one reaches the SAME inode */
    /* THE COUNT IS UNCHANGED.  rename borrows a link and gives it back; one
     * that forgot either half leaves a file that cannot be deleted, or one
     * deleted while it still has a name. */
    if (ip->i_nlink != 1)
        return (1114);
    iput(ip);
    e = dirfind(dev, dblk, dnrb, 2);
    if (e == (struct direct *)0)
        return (1115);
    if (e->d_ino != amade)
        return (1116);

    /* ---- (b) OVER AN EXISTING FILE ------------------------------------- */
    if (dir2make(dvp, dnra, 1, &ip))
        return (1117);
    amade = ip->i_number;
    dir3note(amade);
    dirdrop(ip);
    if (dirlook(dvp, &dir_nd, dnrb, 2, LOOKUP) != 0)
        return (1118);
    bmade = VTOI(dir_nd.ni_vp)->i_number;
    iput(VTOI(dir_nd.ni_vp));

    if (dirlooksrc(dvp, &dir_nd, dnra, 1) != 0)
        return (1119);
    if (dirlook(dvp, &dir_nd2, dnrb, 2, DELETE) != 0)
        return (1120);
    if (dirrename(&dir_nd, &dir_nd2) != 0)
        return (1121);
    if (dirlook(dvp, &dir_nd, dnrb, 2, LOOKUP) != 0)
        return (1122);
    ip = VTOI(dir_nd.ni_vp);
    if (ip->i_number != amade)
        return (1123);      /* the name now reaches the SOURCE */
    iput(ip);
    /* AND THE FILE IT REPLACED IS GONE FROM THE i-LIST.  A rename that
     * rewrote the entry without dropping the old target's link leaks an inode
     * and its blocks on every overwrite, which is invisible until the volume
     * fills. */
    if (iget(mp, bmade, &ip) != 0)
        return (1124);
    if (ip->i_mode != 0)
        return (1125);
    iput(ip);
    if (dir2unlink(dvp, dnrb, 2))
        return (1126);

    /* ---- (c) THE COMPACTION CASE, which is what step 3 is for ---------- */
    for (i = 0; i < 2 * DIRBLKSIZ; i++)
        dirimg[i] = (char)0;
    off = dirrec(0, DIRSCRATCH3, DIRSIZ(1), dndot, 1);
    off = dirrec(off, (int)UFS_ROOTINO, DIRSIZ(2), dndotdot, 2);
    off = dirrec(off, 0, DIRSIZ(3), dndotdot, 2);       /* DEAD, 12 bytes */
    off = dirrec(off, (int)UFS_ROOTINO, DIRSIZ(3), dnra, 1); /* "a", 12 */
    off = dirfill(off, (DIRBLKSIZ - off) / DIRSIZ(3));
    if (off != DIRBLKSIZ)
        return (1127);
    if (dirwrite(dvp, dip, DIRBLKSIZ) != 0)
        return (1128);
    dblk = dip->i_addr[0];

    /* "a" is a real file, so give it a real inode rather than the placeholder
     * the layout carries. */
    if (dirlook(dvp, &dir_nd, dnra, 1, LOOKUP) != 0)
        return (1129);
    if (dir_nd.ni_offset != (off_t)(DIRSIZ(1) + DIRSIZ(2) + DIRSIZ(3)))
        return (1130);      /* "a" starts at 32 -- the layout must hold */
    /* AND THE RESULT IS RELEASED, which this case did not do and which cost a
     * run to find.  The layout above gives "a" a PLACEHOLDER d_ino of
     * UFS_ROOTINO, so this lookup resolves to the ROOT: it was leaking a
     * reference on the root vnode, invisibly, and once the lock was real it
     * left the root LOCKED and the next lookup of "a" waited in ufs_ihashget
     * for a lock this same process was holding.  The lock did not create the
     * defect; it made a silent leak into a stopped machine. */
    iput(VTOI(dir_nd.ni_vp));

    if (dirlooksrc(dvp, &dir_nd, dnra, 1) != 0)
        return (1131);
    /* DIRSIZ(9) is 16: more than the dead record's 12, more than "a"'s four
     * bytes of slack, and exactly the two together.  So direnter must compact,
     * and compacting slides "a" down into the dead record's place. */
    if (dirlook(dvp, &dir_nd2, dnrlong, 9, CREATE) != ENOENT)
        return (1132);
    if (dir_nd2.ni_count != DIRSIZ(3) + DIRSIZ(3))
        return (1133);      /* the run spans the dead record AND "a" */
    if (dirrename(&dir_nd, &dir_nd2) != 0)
        return (1134);
    /* "a" MOVED, and rename unlinked it where it ended up rather than where
     * it started.  Both of these fail if step 3 trusts the stale offset. */
    if (dirlook(dvp, &dir_nd, dnra, 1, LOOKUP) != ENOENT)
        return (1135);
    if (dirlook(dvp, &dir_nd, dnrlong, 9, LOOKUP) != 0)
        return (1136);
    iput(VTOI(dir_nd.ni_vp));
    /* ...and the block still SCANS all the way to the end, which a dirremove
     * that folded the wrong record would have ended. */
    e = dirfind(dev, dblk, dnrlong, 9);
    if (e == (struct direct *)0)
        return (1137);

    /* ---- (d) A DIRECTORY MOVES, AND ".." MOVES WITH IT ----------------- */
    for (i = 0; i < 2 * DIRBLKSIZ; i++)
        dirimg[i] = (char)0;
    off = dirrec(0, DIRSCRATCH3, DIRSIZ(1), dndot, 1);
    off = dirrec(off, (int)UFS_ROOTINO, DIRBLKSIZ - off, dndotdot, 2);
    if (dirwrite(dvp, dip, DIRBLKSIZ) != 0)
        return (1138);
    dblk = dip->i_addr[0];

    if (dirlook(dvp, &dir_nd, dnrsub, 3, CREATE) != ENOENT)
        return (1139);
    dirva.va_type = VDIR;
    dirva.va_mode = 0755;
    if (VOP_MKDIR(&dir_nd, &dirva) != 0)
        return (1140);
    sub = dirkeep(VTOI(dir_nd.ni_vp));
    subvp = ITOV(sub);
    submade = sub->i_number;
    dir3note(submade);

    if (dirlook(dvp, &dir_nd, dnrsub2, 3, CREATE) != ENOENT)
        return (1141);
    dirva.va_type = VDIR;
    dirva.va_mode = 0755;
    if (VOP_MKDIR(&dir_nd, &dirva) != 0)
        return (1142);
    sub2 = dirkeep(VTOI(dir_nd.ni_vp));
    sub2vp = ITOV(sub2);
    dir3note(sub2->i_number);
    if (dip->i_nlink != 4)
        return (1143);      /* two children, two ".." links */

    /* ---- (e) THE REFUSALS, before the move that succeeds ---------------- */
    /* A DIRECTORY INTO ITS OWN SUBTREE.  Everything under it would be alive,
     * in use and unreachable, and nothing records where it was.
     *
     * CHECKPATH HAS TWO ANSWERS AND THEY ARE DIFFERENT ERRORS, which is not
     * obvious until it is read: moving a directory into ITSELF trips the very
     * first test -- target IS source -- and gives EEXIST, while moving it into
     * something BELOW itself is what the ".."-walk finds, and gives EINVAL.
     * Both are refusals of the same mistake and only the second exercises the
     * walk, so both get a case. */
    if (dirlooksrc(dvp, &dir_nd, dnrsub, 3) != 0)
        return (1144);
    if (dirlook(subvp, &dir_nd2, dnrkid, 3, CREATE) != ENOENT)
        return (1145);
    if (dirrename(&dir_nd, &dir_nd2) != EEXIST)
        return (1146);
    /* Deleting the checkpath CALL is caught here, at the cheaper test.  What
     * isolates the walk below is a checkpath that answers its first question
     * and never loops. */

    /* ...AND TWO LEVELS DOWN, WHICH IS THE ONLY DEPTH THAT MAKES IT WALK.
     *
     * A DIRECT child does not: checkpath reads that child's ".." on its first
     * pass, finds the source, and returns EINVAL without ever reaching the
     * iget that advances to the next parent.  So the fixture was green
     * against a checkpath that answers its first question and never loops --
     * which is what the arm aimed at it was supposed to rule out, and could
     * not.  A GRANDCHILD forces one full ascent: nst2's ".." is nst, which is
     * neither the source nor the root, so the loop must iget nst and go round
     * before it can find sbx. */
    if (dirlook(subvp, &dir_nd, dnrnest, 3, CREATE) != ENOENT)
        return (1170);
    dirva.va_type = VDIR;
    dirva.va_mode = 0755;
    if (VOP_MKDIR(&dir_nd, &dirva) != 0)
        return (1171);
    nst   = dirkeep(VTOI(dir_nd.ni_vp));
    nstvp = ITOV(nst);
    dir3note(nst->i_number);

    if (dirlook(nstvp, &dir_nd, dnrnst2, 3, CREATE) != ENOENT)
        return (1178);
    dirva.va_type = VDIR;
    dirva.va_mode = 0755;
    if (VOP_MKDIR(&dir_nd, &dirva) != 0)
        return (1179);
    nst2   = dirkeep(VTOI(dir_nd.ni_vp));
    nst2vp = ITOV(nst2);
    dir3note(nst2->i_number);

    if (dirlooksrc(dvp, &dir_nd, dnrsub, 3) != 0)
        return (1172);
    if (dirlook(nst2vp, &dir_nd2, dnrkid, 3, CREATE) != ENOENT)
        return (1173);
    if (dirrename(&dir_nd, &dir_nd2) != EINVAL)
        return (1174);

    /* Take both back out, so the emptiness cases below still describe sbx. */
    if (dirlook(nstvp, &dir_nd, dnrnst2, 3, DELETE) != 0)
        return (1182);
    if (VOP_RMDIR(&dir_nd) != 0)
        return (1183);
    dirdrop(nst2);
    if (dirlook(subvp, &dir_nd, dnrnest, 3, DELETE) != 0)
        return (1175);
    if (VOP_RMDIR(&dir_nd) != 0)
        return (1176);
    dirdrop(nst);
    if (sub->i_nlink != 2)
        return (1177);

    /* A FILE OVER A DIRECTORY, and a directory over a file.
     *
     * THE PAIRING READS BACKWARDS AND BOTH VENDORS AGREE ON IT.  A file
     * renamed onto a directory gives ENOTDIR, and a directory renamed onto a
     * file gives EISDIR -- 4.3BSD-Reno ufs/ufs_vnops.c:1035-1046 and 2.11BSD
     * usr/sys/sys/ufs_syscalls.c:959-971, the same six lines in both.  The
     * errno describes the SOURCE's unsuitability for the slot it is being put
     * in, not the target's kind: "you asked me to put a non-directory where a
     * directory is" is ENOTDIR.  Read the other way round it looks like a
     * transposition, which is why it is written down here.
     *
     * NOT VERIFIED AGAINST POSIX: no copy of the text is in this tree, and
     * rename(2) is not a syscall here yet.  Two independent BSDs agreeing is
     * what these values rest on, and the day rename(2) gets a man page is the
     * day to check whether the standard pairs them the other way and say so in
     * BUGS. */
    if (dir2make(dvp, dnra, 1, &ip))
        return (1147);
    dir3note(ip->i_number);
    dirdrop(ip);
    if (dirlooksrc(dvp, &dir_nd, dnra, 1) != 0)
        return (1148);
    if (dirlook(dvp, &dir_nd2, dnrsub2, 3, DELETE) != 0)
        return (1149);
    if (dirrename(&dir_nd, &dir_nd2) != ENOTDIR)
        return (1150);
    if (dirlooksrc(dvp, &dir_nd, dnrsub2, 3) != 0)
        return (1151);
    if (dirlook(dvp, &dir_nd2, dnra, 1, DELETE) != 0)
        return (1152);
    if (dirrename(&dir_nd, &dir_nd2) != EISDIR)
        return (1153);
    /* DELETING THIS REFUSAL DOES NOT PRODUCE A CASE, it produces a panic:
     * rename carries on, dirrewrite points the file's entry at the directory,
     * and the two decrements that follow take the file's link count to -1 --
     * kc_panic("rename: linked directory").  Detected, loudly, but not as a
     * verdict this probe can name.  The arm that names it substitutes a
     * DIFFERENT errno, which is the defect shape a reader would actually
     * write. */

    /* A DIRECTORY OVER A NON-EMPTY DIRECTORY. */
    if (dir2make(subvp, dnrkid, 3, &ip))
        return (1154);
    dir3note(ip->i_number);
    dirdrop(ip);
    if (dirlooksrc(dvp, &dir_nd, dnrsub2, 3) != 0)
        return (1155);
    if (dirlook(dvp, &dir_nd2, dnrsub, 3, DELETE) != 0)
        return (1156);
    if (dirrename(&dir_nd, &dir_nd2) != ENOTEMPTY)
        return (1157);
    if (dir2unlink(subvp, dnrkid, 3))
        return (1158);

    /* ---- (f) ...AND THEN THE DIRECTORY MOVES --------------------------- */
    if (dirlooksrc(dvp, &dir_nd, dnrsub, 3) != 0)
        return (1159);
    if (dirlook(sub2vp, &dir_nd2, dnrsub, 3, CREATE) != ENOENT)
        return (1160);
    if (dirrename(&dir_nd, &dir_nd2) != 0)
        return (1161);

    /* ".." NOW NAMES THE NEW PARENT.  A rename that moved the entry and left
     * ".." behind gives a directory whose parent pointer is a lie -- and the
     * next rmdir of it, or any walk upward through it, follows that lie. */
    if (iget(mp, submade, &sub) != 0)
        return (1162);
    /* RAW, AND THE FIRST VERSION OF THIS CASE WAS NOT.  Reading the block back
     * through `bread(devvp, ...)` fires on a CORRECT kernel: rename patches
     * ".." through the DIRECTORY vnode at logical block 0, while the device
     * vnode holds a separate buffer for the same disk block -- the one
     * bmapnew cleared when the block was allocated -- and bread hands that
     * back without going near the platter.  Two cache keys for one block are
     * two different answers, and only one of them is what a PDP-11 mounting
     * this volume would see.  Which is the whole reason this file's rule is
     * that verification goes under the buffer cache. */
    e = dirat(dev, sub->i_addr[0], DIRSIZ(1));
    if (e == (struct direct *)0)
        return (1163);
    if (e->d_ino != sub2->i_number)
        return (1164);
    /* iput, NOT dirdrop, AND `sub' IS STILL HELD AFTERWARDS.  The iget above
     * is the SECOND reference this guard has on that directory -- the first is
     * the dirkeep taken when mkdir made it -- and iget hands its one back
     * LOCKED (ufs_inode.c:489's VOP_LOCK, the contract iput asserts).  So the
     * release that matches it is iput: dirdrop is a bare vrele, which returned
     * one of the two references and left the inode LOCKED as well.
     *
     * THE ONE IT LEAKED WAS INVISIBLE UNTIL 1.8b-3c, when ufs_unmount gained
     * its vflush and the mount stopped being able to go away with a vnode
     * still referenced.  apple/fgx#274; found by asking which guard rather
     * than which inode, after four builds spent on the latter. */
    iput(sub);

    /* THE LINK COUNTS FOLLOWED IT.  The old parent lost the ".." that pointed
     * at it and the new one gained one; a rename that moved a directory
     * without either leaves two counts that can never reach zero. */
    if (dip->i_nlink != 3)
        return (1165);
    if (sub2->i_nlink != 3)
        return (1166);

    /* ---- PUT IT ALL BACK ------------------------------------------------ */
    dirdrop(sub);           /* the mkdir's reference, matching sub2's below */
    dirdrop(sub2);
    dip->i_nlink = 0;
    dip->i_flag |= ICHG;
    vrele(ITOV(dip));       /* UNLOCKED since the head of this guard, so the
                             * release is a vrele and not an iput -- and it
                             * still reaches ufs_inactive, which is the point */

    for (i = 0; i <= dir3_nmade; i++) {
        if (i == dir3_nmade)
            zap = (ino_t)DIRSCRATCH3;
        else
            zap = dir3_made[i];
        if (bread(devvp, itod(zap), &bp) != 0) {
            brelse(bp);
            return (1167);
        }
        slot = itoo(zap) * UFS_DINODESIZE;
        for (off = 0; off < UFS_DINODESIZE; off++)
            bp->b_addr[slot + off] = (char)0;
        if (bwrite(bp) != 0)
            return (1167);
    }
    return (0);
}


/* ufs_probe -- the entry point probe_dev.s calls in a UFSWPROBE build.
 *
 * IT SHARES ITS NAME WITH ufs_probe.c's, deliberately: the two files are
 * mutually exclusive gates and ufs.s PUTs exactly one of them, so one name
 * means the driver needs no conditional.  Merlin32 would not accept the
 * alternative -- it collects EQU labels before evaluating DO -- and ufs.s says
 * so where PROBE_ENTRY is defined.
 *
 * fsblk IS UNUSED HERE and is kept because the two gates share one driver
 * (src/modules/common/probe_dev.s): the block-level gate uses it as the spill
 * block for the free-list chain test, and a second signature would mean a
 * second driver. */
int
ufs_probe(dev, fsblk)
    int     dev;
    daddr_t fsblk;
{
    struct vnode *devvp;

    /* ---- IDENTIFY THE VOLUME BEFORE WRITING A SINGLE BYTE ---------------
     *
     * The same check vfs_probe makes, and made for the same reason rather than
     * copied for symmetry: this file writes too, and a device index is not
     * proof of which image answers.  An uninitialised device table reads as an
     * online disk, and the emulator is free to map an attached image somewhere
     * other than where the numbering suggests -- both happened, and the
     * earlier version wrote to whatever answered at index 1.
     *
     * The bytes are the superblock's leading fields: sb_isize 0x0042 (66) and
     * the low word of sb_volblocks 0x1000 (4096).  A volume that does not
     * identify is left completely alone.
     */
    if (rawio(dev, (daddr_t)2, PROBE_READ) != 0)
        return (60);            /* cannot even read the candidate */
    if (probebuf[0] != (char)0x42 || probebuf[1] != (char)0x00 ||
        probebuf[4] != (char)0x00 || probebuf[5] != (char)0x10)
        return (61);            /* NOT the scratch volume -- nothing written */

    /* The device vnode.  Every read below goes through VOP_STRATEGY on a vnode
     * whose ops vector came from specfs, so a vector that did not resolve or a
     * device number that did not survive checkalias fails here, on the boot
     * path, against a real disk -- a context the fcc fixtures cannot reach at
     * all (apple/fgx#88). */
    if (bdevvp(dev, &devvp) != 0)
        return (62);

    /* ---- 10. THE MOUNT (UFS 1.8a) --------------------------------------
     *
     * THE FIRST TIME THIS TREE ATTACHES A FILESYSTEM TO ANYTHING.  Everything
     * before it reads a volume; this one builds the `struct mount` the VFS
     * understands, with the `struct ufsmount` only UFS understands hanging off
     * it, and then asks the filesystem to describe itself.
     *
     * THE MOUNT TAKES ITS OWN REFERENCE on the device vnode, which is why vref
     * is here: ufs_unmount ends with a vrele, and without a matching vref that
     * would be releasing the reference this probe holds.  A real mount(2) will
     * do exactly the same thing for the same reason.
     */
    {
        static struct mount    pmnt;
        static struct ufsmount pump;
        struct vnode          *rootvp;

        /* ZEROED HERE AND NOT ASSUMED, because a module's statics are NOT
         * zeroed at load -- the same fact that cost apple/fgx#219, where
         * ufs_mountfs's old `mnt_flag |= MNT_RDONLY' ORed into whatever the
         * image happened to carry and a surviving MNT_NODEV made spec_open
         * refuse every node.  Now that the mount HONOURS this field instead
         * of overwriting it, a garbage MNT_RDONLY here would mount the probe
         * volume read-only and the assertion below would read as a pass. */
        pmnt.mnt_flag = 0;

        vref(devvp);
        if (ufs_mountfs(devvp, &pmnt, &pump) != 0)
            return (700);

        /* The private data is wired both ways, which is what makes a mount
         * usable from either end: the VFS reaches UFS through mnt_data, and
         * UFS reaches back through um_mountp. */
        if (pmnt.mnt_data != (char *)&pump)
            return (701);
        if (pump.um_mountp != &pmnt || pump.um_devvp != devvp)
            return (702);

        /* IT HONOURS WHAT IT WAS ASKED, which is the assertion that replaced
         * "it mounts read-only whatever it was asked".  That force was a
         * placeholder for the write path, 1.12 landed, and ufs_mountfs no
         * longer overrides the caller.  pmnt was zeroed above, so the flag
         * must come back CLEAR -- a mount that still forced it would fail
         * here, which is the direction that matters: the old assertion would
         * have passed on a kernel that ignored the caller entirely. */
        if (pmnt.mnt_flag & MNT_RDONLY)
            return (703);

        /* ---- statfs: the numbers df prints ------------------------------
         *
         * THE MAPPING IS 2.11BSD's statfs1, NOT RENO's, and these constants are
         * what fgxfs reports for the same volume.  Reno computes free space
         * from a cylinder-group summary that a 2.11BSD volume does not have, so
         * taking its code here would have produced nonsense rather than a
         * subtle error -- which is the good case, but only if somebody checks.
         */
        if (pmnt.mnt_stat.f_type != MOUNT_UFS)
            return (704);
        if (pmnt.mnt_stat.f_fsize != 1024L || pmnt.mnt_stat.f_bsize != 1024L)
            return (705);
        /* volblocks 4096 less the 66-block i-list and its two leading blocks. */
        if (pmnt.mnt_stat.f_blocks != 4030L)
            return (706);
        if (pmnt.mnt_stat.f_bfree != 3725L)
            return (707);
        /* f_bavail EQUALS f_bfree here and does not in Reno: FFS reserves
         * fs_minfree percent for root, and 2.11BSD has no such reserve.  A df
         * showing a gap would be inventing one. */
        if (pmnt.mnt_stat.f_bavail != 3725L)
            return (708);
        /* (isize - 2) * INOPB: the i-list's length in blocks times the inodes
         * that fit in each. */
        if (pmnt.mnt_stat.f_files != 1024L)
            return (709);
        if (pmnt.mnt_stat.f_ffree != 1020L)
            return (710);

        /* ---- 10b. THE ROOT VNODE (UFS 1.11a) -----------------------------
         *
         * CASE 711 USED TO ASSERT ufs_root RETURNED ENOSYS, and it was written
         * to go red exactly here.  It did.  What replaces it is the thing the
         * boundary was holding back: a real root vnode, produced by iget from
         * the mount this section just built.
         *
         * The root is inode 2 by convention -- inode 0 does not exist and inode
         * 1 is the historical bad-block hack -- so there is no lookup involved.
         */
        if (VFS_ROOT(&pmnt, &rootvp) != 0)
            return (711);
        if (rootvp == (struct vnode *)0)
            return (716);
        /* The vnode's TYPE comes from the inode's mode bits, and that crossing
         * is the seam between the filesystem and the VFS: everything above
         * works in vnode types, everything below in 2.11BSD IFMT bits.  The
         * root is a directory on any volume worth mounting. */
        if (rootvp->v_type != VDIR)
            return (717);
        {
            struct inode  *rip;
            struct dinode *rdp;

            rip = VTOI(rootvp);
            if (rip->i_number != (ino_t)UFS_ROOTINO)
                return (718);
            /* What fgxfs put in inode 2: drwxr-xr-x, three links (itself, its
             * own '..', and lost+found's '..'), one 512-byte block at 68. */
            if (rip->i_din.di_icom1.ic_mode != 040755)
                return (719);
            if (rip->i_din.di_icom1.ic_nlink != 3)
                return (720);
            if (rip->i_din.di_icom1.ic_size != 512L)
                return (721);
            /* THROUGH A LOCAL POINTER TO THE NESTED STRUCT, and that is
             * ordinary C rather than a dodge: `rip->i_din.di_addr[0]` --
             * arrow, dot, subscript -- is one of the arrow-rooted member
             * shapes fcc is missing (apple/fgx#171).  What the PORT needs is
             * array DECAY through the same chain, `ip->i_din.di_addr` passed
             * to ufs_bmap, and that works; the subscript form is a probe
             * convenience and reads no worse this way. */
            rdp = &rip->i_din;
            if (rdp->di_addr[0] != (daddr_t)68)
                return (722);

            /* ---- THE PROPERTY THE WHOLE HASH EXISTS FOR --------------------
             *
             * Two gets of one inode must return ONE in-core inode.  If they did
             * not, two opens of a file would each have their own link count and
             * their own size, and the second writer would win silently.  This
             * is the case iget's hash is for, and asserting the POINTERS are
             * equal is the only way to see it -- comparing the contents would
             * pass against two identical copies.
             *
             * THE LOCK COMES OFF FOR THE SECOND GET, AND IT HAS TO (1.12d).
             * iget returns a LOCKED inode, so a process holding one cannot get
             * it again -- ufs_ihashget waits on ILOCKED for a lock this same
             * process is holding, and the wait is BEFORE ufs_lock's
             * self-deadlock check, so it is a hang and not a panic.  Reno has
             * the property and no caller that trips it: two gets of one inode
             * are two PROCESSES there, never one.
             *
             * What the case is about survives untouched, because it is about
             * the REFERENCE and not the lock: this holds root's reference
             * across the second get, and the second get returning the same
             * pointer is the whole assertion. */
            {
                struct inode *rip2;

                VOP_UNLOCK(rootvp);
                if (iget(&pmnt, (ino_t)UFS_ROOTINO, &rip2) != 0)
                    return (723);
                if (rip2 != rip)
                    return (724);
                iput(rip2);          /* the second reference, and the lock
                                      * the second get took with it */
            }
            /* AND IT STAYS UNLOCKED FROM HERE, which is the same rule every
             * other handle in this file follows and matters more for this one
             * than for any of them: the root is held across the sections
             * below, and those sections walk directories whose ".." names it.
             * A lookup that reaches the root while this process holds it
             * locked waits in ufs_ihashget for its own lock.  A reference is
             * all this needs -- the assertions above are already done. */

            /* ---- A DIFFERENT INODE IS A DIFFERENT in-core inode ------------
             *
             * The mirror image, and it is not redundant: a hash that returned
             * the first entry of every chain would pass the case above and fail
             * here.  Inode 4 is /big, whose addresses section 9 already walked
             * with bmap -- so this also checks that the DECODE agrees with what
             * bmap read straight off the i-list block. */
            {
                struct inode *bip;

                if (iget(&pmnt, (ino_t)4, &bip) != 0)
                    return (725);
                if (bip == rip)
                    return (726);
                if (bip->i_number != (ino_t)4)
                    return (727);
                if (ITOV(bip)->v_type != VREG)
                    return (728);
                if (bip->i_din.di_icom1.ic_size != 307200L)
                    return (729);
                /* The same seven addresses section 9 decoded by hand. */
                rdp = &bip->i_din;
                if (rdp->di_addr[0] != (daddr_t)70 ||
                    rdp->di_addr[4] != (daddr_t)78 ||
                    rdp->di_addr[5] != (daddr_t)358 ||
                    rdp->di_addr[6] != (daddr_t)0)
                    return (730);
                iput(bip);
            }
            vrele(rootvp);      /* unlocked since the case above */
        }

        /* ---- THE WRITE PATH (UFS 1.12a) --------------------------------
         *
         * A PRISTINE COPY IS TAKEN FROM THE DISK FIRST, not carried down from
         * section 6: the validator cases above scribble on probesb in core
         * deliberately, and the PLATTER's copy is pristine because section 8
         * already put it back.  Re-reading is one block and removes the
         * question entirely.
         *
         * The restore runs whatever writeguard returned, which is why it is a
         * function -- the same rule allocprobe follows and for the same
         * reason.  It puts back the FREE LIST; the inode slot writeguard used
         * is writeguard's own to clean up, because only it knows which one.
         *
         * The mount's in-core superblock is left as the writes left it.
         * Nothing below reads it -- VFS_MOUNT and VFS_UNMOUNT are the two
         * stubs -- and the next boot reads the platter.
         */
        {
            int g;

            if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
                return (858);
            g = writeguard(dev, devvp, &pmnt);
            if (ufs_sbupdate(devvp, &probesb) != 0)
                return (859);
            if (g)
                return (g);
        }

        /* ---- TRUNCATE AND RELEASE (UFS 1.12b) --------------------------
         *
         * Same restore discipline, same reason, and the pristine copy is taken
         * again rather than reused: writeguard's own restore has run by now,
         * so the platter is back to the volume `fgxfs mkfs` built.
         */
        {
            int g;

            if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
                return (918);
            g = truncguard(dev, devvp, &pmnt);
            if (ufs_sbupdate(devvp, &probesb) != 0)
                return (919);
            if (g)
                return (g);
        }

        /* ---- THE DIRECTORY-ENTRY LAYER (UFS 1.12c-a) -------------------
         *
         * Same restore discipline, and the pristine copy is re-read for the
         * same reason: truncguard's own restore has run, so the platter is
         * back to the volume `fgxfs mkfs` built.  This section takes blocks
         * for its scratch directory and inodes for the names it creates.  The
         * blocks come back with the superblock; the inode slots are
         * dirguard's own to zero, because only it knows which ones it got.
         */
        {
            int g;

            if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
                return (968);
            g = dirguard(dev, devvp, &pmnt);
            if (ufs_sbupdate(devvp, &probesb) != 0)
                return (969);
            if (g)
                return (g);
        }

        /* ---- THE REST OF DIRECTORY MUTATION (UFS 1.12c-b) -------------- */
        {
            int g;

            if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
                return (1100);
            g = dirguard2(dev, devvp, &pmnt);
            if (ufs_sbupdate(devvp, &probesb) != 0)
                return (1101);
            if (g)
                return (g);
        }

        /* ---- rename (UFS 1.12c-c) --------------------------------------- */
        {
            int g;

            if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
                return (1180);
            g = dirguard3(dev, devvp, &pmnt);
            if (ufs_sbupdate(devvp, &probesb) != 0)
                return (1181);
            if (g)
                return (g);
        }



        /* ufs_mount IS NO LONGER A STUB (UFS 1.8b-1), and this case moved
         * with it rather than being deleted.  It asserted ENOSYS while the
         * vfsops slot was `return (ENOSYS)'; what it asserts now is the first
         * thing the real body does, which is refuse a mount that names no
         * device.  Reno reaches the same refusal through a copyin of a
         * `struct ufs_args' whose fspec is null; ours takes the device path
         * as `data' directly, so a null one is EINVAL here.  The case still
         * proves the slot is REACHED -- a vector still holding the stub
         * answers ENOSYS and goes red. */
        if (VFS_MOUNT(&pmnt, (char *)0, (char *)0, &dir_nd) != EINVAL)
            return (712);

        /* ---- and unmount ------------------------------------------------ */
        /* THE MOUNT GOES OUT OF SERVICE FIRST, and that is the CALLER's job
         * rather than the vector's.  `ufs_unmount' opens with `vflush' since
         * UFS 1.8b-3c, and vflush opens with Reno's assertion --
         * `if ((mp->mnt_flag & MNT_MPBUSY) == 0) panic("vflush: not busy")',
         * vendor/4.3BSD-Reno/kern/vfs_subr.c:537 -- so everything that
         * dispatches VFS_UNMOUNT must have made the mount busy first.  Reno
         * does it in `vfs_busy' (same file, :102); FGX does it inline in
         * `vfs_dounmount', which is the only publisher in the tree.
         *
         * A PROBE DRIVES THE VECTOR DIRECTLY, on a `struct mount' of its own,
         * because it predates mount(2) and exists to exercise ufs_vfsops in
         * isolation.  So it owes what dounmount owes.  Without this line the
         * machine PANICs here before a single case is reported, and the gate
         * that would have said so is a knob nobody had run since the increment
         * landed (apple/fgx#272).  Not cleared afterwards, on Reno's own
         * pattern: a successful unmount never unbusies, because the mount is
         * finished with. */
        pmnt.mnt_flag |= MNT_MPBUSY;
        if (VFS_UNMOUNT(&pmnt, 1) != EINVAL)
            return (713);   /* a forced unmount has nothing to revoke yet */
        if (VFS_UNMOUNT(&pmnt, 0) != 0)
            return (714);
        /* Unhooked, so a second mount cannot find stale private data. */
        if (pmnt.mnt_data != (char *)0)
            return (715);
    }

    vrele(devvp);
    return (0);
}
