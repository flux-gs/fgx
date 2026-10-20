/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX-Origin: original -- FGX code.  It CITES BSD (see below) but contains
 * none of it; registering it would assert the Regents' copyright over work
 * they did not write.
 */
/* ufs_vnprobe.c -- the filesystem asserted through its READING vnode
 * operations.  UFS 1.12a, split out of ufs_probe.c; split again at 1.12b, when
 * the WRITING half became ufs_wprobe.c for the same bank reason a second time.
 *
 * WHY THERE ARE TWO FILES, WHICH IS A BANK PROBLEM AND NOT A TAXONOMY.
 *
 * ufs.mod is one 65,536-byte bank.  Measured on 2026-08-20, at the commit
 * before 1.12a: the shipping module is 29,372 bytes and the probe adds 31,915,
 * for 61,287 with 4,249 to spare.  1.12a's SHIPPING code -- ufs_write,
 * ufs_fsync, ufs_bmapx's allocation arm, iupdat, ufs_iencode -- is 4,612
 * bytes, which puts the single-gate probe build 363 bytes over the bank before
 * this file's own cases exist at all.  1.12b and 1.12c add several times that.
 *
 * vfs.mod reached the same wall twice and answered it the same way both times;
 * src/modules/vfs/vfs.s:246-261 records it ("the two together do not fit"),
 * and the earlier probe gates are what came out of it.  One probe file, one
 * `DO GATE=1`, and the gates are MUTUALLY EXCLUSIVE -- a build carries one of
 * them, so what the two share costs nothing twice.
 *
 * THE SEAM IS THE MOUNT, and it is where the subject changes rather than where
 * the line count was convenient:
 *
 *   ufs_probe.c    the volume as BLOCKS.  The superblock, the block and inode
 *                  allocators, bmap's descent, and the validator.  It never
 *                  builds a struct mount and never takes a vnode for a file.
 *
 *   this file      the volume as FILES.  Everything that needs a mount: iget
 *                  and the inode hash, VOP_GETATTR/READ/LOOKUP/READDIR, and
 *                  1.12a's VOP_WRITE.  It mounts the volume itself rather than
 *                  inheriting one.
 *
 * ONE CASE MOVED THE OTHER WAY.  815 and 816 -- the superblock's fs_time stamp
 * -- lived in readguard and asserted on `allocsb`, which only the allocator
 * section drives through a refill.  Across a gate boundary that becomes a case
 * whose precondition is in a file this build does not contain: it would fail
 * for the wrong reason, or worse, be quietly rewritten to pass.  It is now in
 * allocprobe, beside the allocator whose behaviour it actually describes.
 *
 * CASE NUMBERS DO NOT RESTART.  A code names one failing property across the
 * whole campaign -- 700-715 the mount, 750-762 the inode hash, 800-819 the
 * read path, 820-856 the name lookup, 860-899 the write path -- and a reader
 * given "ufs: BROKEN, case 883" should not first have to work out which gate
 * produced it.  Codes print whole as a 16-bit decimal, so the range is free.
 *
 * EVERYTHING ELSE ABOUT HOW THIS FILE WORKS IS ufs_probe.c's HEADER: where the
 * expected numbers come from (tools/fgxfs.py, an independent implementation of
 * the same format), why it identifies the volume before writing a byte, and
 * why it must leave the volume exactly as it found it.  That reasoning is not
 * repeated here; it is not this file's, it is the probe's.
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
#include "uio.h"        /* 1.11b: ufs_read takes a uio */
#include "dir.h"        /* 1.11c: the on-disk directory entry */
#include "namei.h"      /* 1.11c: VOP_LOOKUP takes a nameidata */

extern int          bdevvp();
extern int          ufs_ialloc();
extern int          ufs_bmap();
extern long         kern_time();
extern int          ufs_mountfs();
extern void         vref();
extern int          iget();
extern void         iput();
extern void         ufs_ifree();
extern struct inode *ufs_ifind();
extern void         vrele();
extern int          kc_curpid();
extern struct inode *ufs_ifind();
extern int          bread();
extern void         brelse();
extern int          kc_blkio();
extern void         kc_ticks();

#define DEV_BLKSIZE     512
#define PROBE_READ      1
#define PROBE_WRITE     0

/* One 512-byte scratch for the RAW oracle reads. */
static char probebuf[DEV_BLKSIZE];

/* The 60 Hz counter, for the cost assertion in the read guard's section (m).
 * A module buffer rather than a stack local, which is kc_ticks's stated
 * contract; and TWO 16-BIT WORDS rather than four bytes, which is the layout
 * kc_ticks writes.
 *
 * ONLY THE LOW WORD IS USED, and it is enough by a wide margin: the window
 * being timed is a hundred clock reads, which is well under a second, where the
 * low word wraps in 18.2 minutes.  Doing it in 16 bits also keeps the RULER
 * cheaper than the thing it measures -- the first version of this assembled a
 * long out of bytes, and the multiplies cost more than the calls did. */
static unsigned probetick[2];

static unsigned
probe_ticks()
{
    kc_ticks(probetick);
    return (probetick[0]);
}

/* Raw device access, bypassing the cache entirely: this is the oracle. */
static int
rawio(dev, dblk, isread)
    int     dev;
    daddr_t dblk;
    int     isread;
{
    return (kc_blkio(dev, (int)(dblk >> 16), (int)dblk, probebuf, isread));
}


/* ---- 10c. AN INODE ALLOCATED IN CORE IS NOT A FREE INODE ------------------
 *
 * apple/fgx#168, filed at 1.10b and due the moment 1.11a landed iget.  2.11BSD's
 * ialloc has two guards this port could not have until then: it rechecks a
 * number after popping it off the cache (ufs_alloc.c:163-178), and its i-list
 * scan skips any number ifind() reports in core (ufs_alloc.c:208-209).  Both ask
 * the same question -- has this number been handed out by someone who has not
 * written it to disk yet -- and the i-list cannot answer it, because an inode
 * allocated in core still reads di_mode 0 on the platter.
 *
 * THE FAILURE IS SILENT: without the guards two files get the same inode and
 * nothing returns an error anywhere.  That is what earns it cases of its own.
 *
 * THE TWO GUARDS GET SEPARATE ASSERTIONS ON PURPOSE.  Either one alone keeps a
 * second allocation from returning the same number, so a single "it did not
 * hand it out twice" case would stay green with either guard deleted -- the
 * dead-case trap this campaign has hit before.  So (a) asserts on the CACHE,
 * which only the scan-side guard can keep clean, and (b) puts the number back
 * with ufs_ifree -- which consults nothing, upstream's behaviour too -- so only
 * the pop-side guard can catch it.
 *
 * A FUNCTION RATHER THAN A BLOCK, for allocprobe's reason plus one more: this
 * probe runs on FGX_STK_KERNEL, the 256-byte static boot stack, and the 1.11a
 * chain already fits it with under 32 bytes to spare (apple/fgx#172).  Fourteen
 * bytes of automatics inside ufs_probe took it over; out here they cost nothing
 * until this runs.
 *
 * THE MOUNT'S OWN SUPERBLOCK is what this allocates against, not allocsb:
 * section 7 deliberately leaves that one wrecked (case 560 sets sb_isize = 2 to
 * force ENOSPC), and this is the copy 1.12 will really use.  Nothing writes it
 * -- ufs_ialloc only breads, and ufs_unmount does not flush -- so the volume is
 * left exactly as it was found.
 */
static int
inodeguard(devvp, mp)
struct vnode *devvp;
struct mount *mp;
{
    struct ufsmount *ump;
    struct ufs_sb   *asb;
    struct inode    *ip;
    ino_t            first;
    ino_t            got;
    int              k;
    int              refs;

    /* Through a local, which is iget's spelling too.  `&VFSTOUFS(mp)->um_sb`
     * is the address of a member through a CAST expression, and fcc rejects it
     * -- filed as apple/fgx#174.  A local is what every other caller writes in
     * any case. */
    ump = VFSTOUFS(mp);
    asb = &ump->um_sb;

    /* Empty the cache so the allocation has to SCAN the i-list. */
    asb->sb_ninode  = 0;
    asb->sb_nbehind = 0;
    if (ufs_ialloc(devvp, asb, &first) != 0)
        return (740);

    /* PUT IT IN CORE AND DO NOT WRITE IT.  That is the whole state under test.
     * A version of this that flushed first could not go red: the on-disk mode
     * would be nonzero and the scan would skip the number for the ordinary
     * reason, which is the vacuity trap #168 named in advance. */
    if (iget(mp, first, &ip) != 0)
        return (741);
    if (ip->i_number != first)
        return (742);

    /* (a) THE SCAN must not re-cache it. */
    asb->sb_ninode  = 0;
    asb->sb_nbehind = 0;
    if (ufs_ialloc(devvp, asb, &got) != 0)
        return (743);
    for (k = 0; k < (int)asb->sb_ninode; k++) {
        if (asb->sb_inode[k] == first)
            return (744);
    }

    /* (b) THE POP must refuse it even when the number reaches the cache by
     * another route.  Freeing an inode that is still in core is not contrived
     * -- it is an unlinked file somebody still has open. */
    ufs_ifree(asb, first);
    if (ufs_ialloc(devvp, asb, &got) != 0)
        return (745);
    if (got == first)
        return (746);

    /* (c) THE CACHE CAN BE STALE AGAINST THE PLATTER, NOT JUST AGAINST CORE.
     *
     * Upstream's post-pop recheck is `iget` then `if (ip->i_mode == 0)`, and
     * iget breads the i-list -- so it refuses a number whose ON-DISK mode is
     * nonzero, which is the state a crash between the i-list write and the
     * superblock write leaves behind.  A bare ufs_ifind cannot see that.
     *
     * INODE 3 IS lost+found: allocated on disk by mkfs, and the one allocated
     * inode this probe never brings into core -- 2 is refused as the root, and
     * 4 (/big) is hashed by case 725 above.  So it is the only number here that
     * ISOLATES the disk test: ufs_ifree pushes it onto the cache without
     * consulting anything (upstream's behaviour too), and only the platter can
     * say no. */
    ufs_ifree(asb, (ino_t)3);
    if (ufs_ialloc(devvp, asb, &got) != 0)
        return (750);
    if (got == (ino_t)3)
        return (751);

    iput(ip);

    /* (d) A RECYCLED VNODE MUST LEAVE THE HASH.
     *
     * Not part of apple/fgx#168, but it is what makes (a) and (b) mean
     * anything: both trust ufs_ifind, and ufs_ifind is only truthful while the
     * hash matches reality.  Reno keeps it so in ufs_reclaim
     * (vendor/4.3BSD-Reno/ufs/ufs_inode.c:288-303, "Remove the inode from its
     * hash chain"); this port had ufs_nullop in that slot until now, so a
     * recycled vnode stayed on its old bucket and ufs_ihashins then re-pointed
     * the same memory into a second one.
     *
     * FORCING THE RECYCLE IS THE WHOLE TEST.  Nothing else in this probe wraps
     * the vnode pool, so without these lines the fix cannot go red -- the
     * defect is invisible until the 32nd handout.  So: put an inode in core,
     * release it so it sits on the free list still hashed, then churn
     * VNODE_POOL+2 further inodes through iget/iput until the pool comes round
     * and hands that vnode to somebody else.  Afterwards the old identity must
     * be GONE from the table.
     *
     * Expect a HANG rather than a case number if this regresses: a walk that
     * crosses from one bucket into another never meets its head sentinel.  That
     * is the defect's real shape, and it is why it is worth forcing here rather
     * than waiting for 1.11b to meet it. */
    if (iget(mp, (ino_t)UFS_ROOTINO, &ip) != 0)
        return (747);
    iput(ip);
    for (k = 0; k < VNODE_POOL + 2; k++) {
        struct inode *tip;

        /* Any inode that is not the one under test; 8 upward is past the
         * reserved low numbers and inside the i-list on this volume. */
        if (iget(mp, (ino_t)(8 + k), &tip) != 0)
            return (748);

        /* THE CHURN HAS TO LOOK LIKE REAL FILES SINCE 1.12b, and finding out
         * why is worth more than the two lines.  Inodes 8 upward are FREE on
         * this volume, so their on-disk mode is zero -- and ufs_inactive's
         * first arm is Reno's "get rid of inodes related to stale file
         * handles": a mode-zero inode is vgone'd on the spot.  Correct, and it
         * empties the pool slot immediately, so the loop below stopped WRAPPING
         * the pool and started reusing one slot forever.  The root inode was
         * then never recycled and case 749 went red -- the probe catching its
         * own mechanism being invalidated by a change that was right.
         *
         * A non-zero mode keeps each one on the free list still hashed, which
         * is the state this loop needs.  i_nlink must go with it: inactive's
         * OTHER arm frees the blocks and the number of an inode whose link
         * count has reached zero, and a fabricated file with nlink 0 would have
         * this loop quietly freeing thirty inodes off the volume.  Nothing is
         * written for them either way -- iget leaves i_flag clear, so iupdat
         * has nothing to do.  Restored to the platter's own zero at the end of
         * the pass. */
        tip->i_mode  = (unsigned short)(IFREG | 0644);
        tip->i_nlink = 1;
        ITOV(tip)->v_type = VREG;
        iput(tip);
    }
    if (ufs_ifind(devvp->v_rdev, (ino_t)UFS_ROOTINO) != (struct inode *)0)
        return (749);

    /* ---- (e) THE DEVICE VNODE'S REFERENCE COUNT COMES BACK (apple/fgx#175)
     *
     * Reno's iget VREFs i_devvp (vendor/4.3BSD-Reno/ufs/ufs_inode.c:212-213)
     * and its ufs_reclaim vreles it (:307-310).  Both halves were absent here,
     * then added, then backed out when the pair hung the machine; this is the
     * assertion that keeps them together now that it does not.
     *
     * WHY A DELTA AND NOT AN ABSOLUTE COUNT.  How many references stand on the
     * device vnode here depends on how many UFS inodes happen to be in core,
     * which depends on every case above; there is no number to assert against.
     * But the CHANGE across a churn is an invariant, and a sharp one: the loop
     * above has already saturated the pool, so every iget below both takes a
     * reference (its new inode) and gives one back (the vnode it recycles).
     * Net zero, every time round, forever.  That is the property that makes a
     * long-running filesystem possible, and it is exactly what a missing vrele
     * destroys -- the count would climb by one per iget and never come down.
     *
     * ONE CASE DISCRIMINATES BOTH HALVES.  Drop the vrele and the count grows
     * by the length of the loop: red here.  Drop the vref and the vreles have
     * nothing of their own to release, so they eat the mount's reference and
     * vrele's own `zero usecount` panic fires: red as a halt with its name on
     * the screen, which is only readable at all since apple/fgx#177.
     *
     * FOUR ITERATIONS, ON INODES THE LOOP ABOVE DID NOT TOUCH.  Four is enough
     * once the pool is saturated, and the whole probe runs inside a 30-second
     * boot budget that a second full-length churn overran.  The numbers must be
     * FRESH: re-getting 8..8+VNODE_POOL+1 would hit the hash, return without a
     * getnewvnode, and change no count at all -- the vacuous version of this
     * test. */
    refs = devvp->v_usecount;
    for (k = 0; k < 4; k++) {
        struct inode *tip;

        if (iget(mp, (ino_t)(8 + VNODE_POOL + 2 + k), &tip) != 0)
            return (752);
        /* Fabricated as a real file, for the loop above's reason and for one
         * more that belongs to THIS case.  NET ZERO is a steady-state
         * invariant: each iget takes a reference for its new inode and gives
         * one back through the vnode it recycles.  A mode-zero inode is
         * vgone'd by ufs_inactive the moment it is released (1.12b), so it
         * gives its reference back IMMEDIATELY as well as when it is recycled
         * -- the count then falls by one per iteration until the pool's
         * backlog of hashed inodes is drained, which is correct behaviour and
         * not the steady state this case measures. */
        tip->i_mode  = (unsigned short)(IFREG | 0644);
        tip->i_nlink = 1;
        ITOV(tip)->v_type = VREG;
        iput(tip);
    }
    if (devvp->v_usecount != refs)
        return (753);

    return (0);
}


/* ---- THE READ PATH (UFS 1.11b) ------------------------------------------
 *
 * ufs_getattr, ufs_read, and the ufs_strategy underneath them -- which is the
 * one that had never existed.  Everything below it was already written against
 * it: vfs_bio keys the cache by (b_vp, b_lblkno), bgetvp leaves b_dev NODEV for
 * a file and names ufs_strategy as what fills it in, bio_strategy's header says
 * the same.  So the interesting assertions here are not "did the bytes copy"
 * but "did the LOGICAL block number become the right PHYSICAL one".
 *
 * THE ORACLE IS THE FILE'S OWN CONTENT, and it is another implementation's.
 * `fgxfs mkfile /big --blocks 300` writes each 1024-byte block as 512 repeats
 * of the two bytes (lbn & 0xFF, lbn >> 8) -- its own comment says why: "a
 * reader that returns the right BYTES from the wrong BLOCK is caught, which a
 * constant fill or a random fill would both miss".  That is exactly the defect
 * a logical-to-physical map has, so the file was built for this test before
 * this test existed.
 *
 * A READ IS THEREFORE SELF-LOCATING: byte at file offset `off` must be
 * (off/1024) & 0xFF when off is even and (off/1024) >> 8 when it is odd.  Read
 * the wrong block and the value names the block you actually read.
 */
static int
readguard(devvp, mp)
struct vnode *devvp;
struct mount *mp;
{
    struct inode  *ip;
    struct vnode  *vp;
    struct vattr   va;
    struct uio     u;
    struct iovec   iov;
    struct vnode  *bmvp;
    struct inode  *rip;
    struct vnode  *rvp;
    daddr_t        bmbn;
    long           now;
    char           buf[8];
    int            error;

    /* ---- (a) getattr on the ROOT DIRECTORY -----------------------------
     * Every field this port fills, against fgxfs's reading of the same inode
     * (mode 040755, nlink 3, size 512) -- the numbers case 717-721 already
     * check on the raw inode, asked here through the VFS instead. */
    if (iget(mp, (ino_t)UFS_ROOTINO, &ip) != 0)
        return (760);
    vp = ITOV(ip);
    va.va_type = -2;                    /* not VA_UNSET and not a vtype */
    if (VOP_GETATTR(vp, &va, (char *)0) != 0)
        return (761);
    if (va.va_type != VDIR)
        return (762);
    /* The IFMT bits must be GONE: va_mode is the permission bits alone, which
     * is what stat(2) reports separately from st_mode's type. */
    if (va.va_mode != 0755)
        return (763);
    if (va.va_nlink != 3)
        return (764);
    if (va.va_size != 512L)
        return (765);
    if (va.va_fileid != (long)UFS_ROOTINO)
        return (766);
    if (va.va_fsid != (long)devvp->v_rdev)
        return (767);
    if (va.va_blocksize != 1024L)
        return (768);
    iput(ip);

    /* ---- (b) VOP_BMAP answers both halves, and either alone --------------
     * The device vnode is the answer to "where does the I/O go", and it is NOT
     * the file's own vnode -- which is the whole reason the slot takes a vpp. */
    if (iget(mp, (ino_t)4, &ip) != 0)
        return (769);
    vp = ITOV(ip);
    bmvp = (struct vnode *)0;
    bmbn = (daddr_t)-2;
    if (VOP_BMAP(vp, (daddr_t)0, &bmvp, &bmbn) != 0)
        return (770);
    if (bmvp != devvp)
        return (771);
    if (bmbn != (daddr_t)70)            /* di_addr[0], case 730's number */
        return (772);
    /* bnp alone: a caller that wants only the block must not need a vnode.
     * Logical 4 is the FIRST block past the four direct ones -- di_addr[4] is
     * the single indirect, not a fifth direct block -- so this also proves the
     * wrapper reaches the indirect walk rather than only the inline addresses.
     * 80 is section 9's own answer for the same block. */
    bmbn = (daddr_t)-2;
    if (VOP_BMAP(vp, (daddr_t)4, (struct vnode **)0, &bmbn) != 0)
        return (773);
    if (bmbn != (daddr_t)80)
        return (774);

    /* ---- (c) getattr on /big -------------------------------------------- */
    if (VOP_GETATTR(vp, &va, (char *)0) != 0)
        return (775);
    if (va.va_type != VREG)
        return (776);
    if (va.va_size != 307200L)
        return (777);

    /* ---- (d) READ THE FIRST BLOCK --------------------------------------
     * Four bytes at offset 0.  Logical block 0, so every pair is (0, 0) -- and
     * this is the case that would pass even with the mapping broken, because
     * logical 0 and physical 0 are only distinguishable further in.  It is here
     * to separate "the read moved nothing" from "the read moved the wrong
     * block": without it, (e)'s failure is ambiguous. */
    iov.iov_base = buf;
    iov.iov_len  = 4;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = 4;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    error = VOP_READ(vp, &u, 0, (char *)0);
    if (error)
        return (778);
    if (u.uio_resid != 0)
        return (779);
    if (buf[0] != 0 || buf[1] != 0 || buf[2] != 0 || buf[3] != 0)
        return (780);

    /* ---- (e) READ A LATER BLOCK, and this is the real assertion ---------
     * Offset 4096 is logical block 4, which lives at PHYSICAL block 80 -- the
     * first block past the four direct ones, so it is reached through the
     * single indirect and not out of the inode at all.  The
     * bytes must name block 4.  A strategy that ignored bmap would read
     * physical 4 and return whatever block 4 of the volume holds; a strategy
     * that mapped but kept the logical number in b_blkno would read the same
     * wrong place.  Both are caught here and neither is caught by (d). */
    iov.iov_base = buf;
    iov.iov_len  = 4;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)4096;
    u.uio_resid  = 4;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(vp, &u, 0, (char *)0) != 0)
        return (781);
    if (buf[0] != 4 || buf[1] != 0 || buf[2] != 4 || buf[3] != 0)
        return (782);

    /* ---- (f) A READ THAT CROSSES A BLOCK BOUNDARY -----------------------
     * Two bytes at 1023: the last byte of logical block 0 and the first of
     * block 1.  1023 is odd, so it is block 0's HIGH byte (0); 1024 is even, so
     * it is block 1's low byte (1).  This is the one that proves the loop goes
     * round -- a body that transferred once and returned would move one byte
     * and leave resid at 1. */
    iov.iov_base = buf;
    iov.iov_len  = 2;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)1023;
    u.uio_resid  = 2;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(vp, &u, 0, (char *)0) != 0)
        return (783);
    if (u.uio_resid != 0)
        return (784);
    if (buf[0] != 0 || buf[1] != 1)
        return (785);

    /* ---- (g) A BLOCK REACHED THROUGH THE SINGLE INDIRECT ----------------
     * NDADDR is 4, so logical 0..3 come out of the inode and 4 upward need a
     * disk read to resolve.  Logical 100 is well inside the single indirect's
     * span, and its content names it: 100 = 0x0064. */
    iov.iov_base = buf;
    iov.iov_len  = 2;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)(100L * 1024L);
    u.uio_resid  = 2;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(vp, &u, 0, (char *)0) != 0)
        return (786);
    if (buf[0] != 100 || buf[1] != 0)
        return (787);

    /* ---- (h) THE SIZE CLAMP, AND IT NEEDS A FILE THAT IS NOT BLOCK-ALIGNED
     *
     * /big IS THE WRONG FILE FOR THIS and the first version of this case used
     * it anyway: 307200 is exactly 300 * 1024, so the last block ends exactly
     * at EOF and the BLOCK-BOUNDARY clamp already limits every read.  Removing
     * `if (diff < n) n = diff` from ufs_read left the probe green -- measured,
     * not reasoned -- because on that file the size clamp is unreachable.
     *
     * The ROOT DIRECTORY is 512 bytes, half a block (case 765 asserts the
     * size), so a read that starts inside it and asks past its end can only be
     * cut short by i_size.  Ask for 512 bytes from offset 256: the block has
     * 768 left, the request has 512, and the FILE has 256.  Only the last of
     * the three is the property under test, and it is the only one that gives
     * 256.  Without the clamp this returns 512 bytes, half of them the tail of
     * a block that on a volume another implementation wrote is somebody else's
     * deleted data.
     *
     * ufs_read admits IFDIR, which is Reno's list -- a directory IS readable as
     * bytes, and 1.11c's readdir is a formatter over exactly this. */
    if (iget(mp, (ino_t)UFS_ROOTINO, &rip) != 0)
        return (788);
    rvp = ITOV(rip);
    iov.iov_base = probebuf;
    iov.iov_len  = 512;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)256;
    u.uio_resid  = 512;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(rvp, &u, 0, (char *)0) != 0)
        return (789);
    if (u.uio_resid != 256)
        return (790);
    /* AND THE DIRECTORY READS AS ITSELF at offset 0.
     *
     * THE FORMAT IS THE VARIABLE-LENGTH ONE, not 2.11BSD's older fixed 16-byte
     * `direct`, and this case is where that was established -- measured off
     * disk/ufsscratch.fs rather than assumed, after an assertion written for
     * the fixed layout failed on the third byte:
     *
     *     02 00  08 00  01 00  2e 00      d_ino=2 reclen=8 namlen=1 "."
     *     02 00  0c 00  02 00  2e 2e ...  d_ino=2 reclen=12 namlen=2 ".."
     *
     * So the header is three 16-bit fields and the name follows, padded to a
     * 4-byte multiple.  1.11c's readdir is a formatter over exactly this, and
     * knowing it now is the difference between writing that against the disk
     * and writing it against a memory of 2.11BSD's h/dir.h. */
    iov.iov_base = probebuf;
    iov.iov_len  = 8;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = 8;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(rvp, &u, 0, (char *)0) != 0)
        return (794);
    if (probebuf[0] != (char)UFS_ROOTINO || probebuf[1] != 0)
        return (795);
    if (probebuf[2] != 8 || probebuf[3] != 0)
        return (796);
    if (probebuf[4] != 1 || probebuf[5] != 0)
        return (797);
    if (probebuf[6] != '.' || probebuf[7] != 0)
        return (798);
    iput(rip);

    /* ---- (i) A READ THAT STARTS PAST THE END ---------------------------
     * Zero bytes and no error -- Reno's `if (diff <= 0) return (0)`, which is
     * how read(2) reports EOF.  An unclamped loop would spin here. */
    iov.iov_base = buf;
    iov.iov_len  = 4;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)307200L;
    u.uio_resid  = 4;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(vp, &u, 0, (char *)0) != 0)
        return (791);
    if (u.uio_resid != 4)
        return (792);

    /* ---- (j) THE ACCESS FLAG IS SET, and nothing converts it yet --------
     * ufs_read sets IACC; with no clock (apple/fgx#167) nothing turns it into a
     * timestamp.  Asserting the flag rather than the stamp is the honest test
     * of what this increment actually does. */
    if ((ip->i_flag & IACC) == 0)
        return (793);
    iput(ip);

    /* ---- (k) THE CLOCK, AND WHAT THE STAMPS DO WITH IT (apple/fgx#167)
     *
     * IT BRANCHES ON WHETHER THIS MACHINE HAS A CLOCK, and that is not
     * hedging.  kern_time returns 0 for an unset or impossible RTC, and BOTH
     * behaviours are specified: with a clock the stamps freshen and the flags
     * are consumed; without one they are left exactly as they were, so a later
     * call with a working clock still has the work to do.  A probe that
     * asserted only the first would go red on a machine whose battery is flat
     * and call it a filesystem bug.
     *
     * What is NOT conditional is the arithmetic: a clock that reads at all must
     * read as a real date.  A small positive number or a negative one is
     * kern_time's sum going wrong, and that is the same failure whether or not
     * the battery is good. */
    now = kern_time();
    if (now < 0L)
        return (800);
    if (now != 0L && now < 1577836800L)     /* 2020-01-01, floor not target */
        return (801);

    if (iget(mp, (ino_t)4, &ip) != 0)
        return (802);
    vp = ITOV(ip);

    /* A STAT OF AN UNTOUCHED FILE MUST NOT TOUCH THE CLOCK, which here means
     * must not touch the STAMPS -- the flag guard in ufs_itimes is what keeps
     * a firmware excursion off the common path, and 12345 is a value no clock
     * can return, so a stamp that survives proves nothing wrote it. */
    ip->i_flag &= ~(IACC | IUPD | ICHG | IMOD);
    ip->i_atime = 12345L;
    if (VOP_GETATTR(vp, &va, (char *)0) != 0)
        return (803);
    if (ip->i_atime != 12345L)
        return (804);
    if (va.va_atime != 12345L)
        return (805);
    if (ip->i_flag & IMOD)
        return (806);

    /* ...and a dirty one must be stamped. */
    ip->i_flag |= IACC;
    if (VOP_GETATTR(vp, &va, (char *)0) != 0)
        return (807);
    if (now == 0L) {
        if (ip->i_atime != 12345L)
            return (808);
        if ((ip->i_flag & IACC) == 0)
            return (809);
    } else {
        if (ip->i_atime == 12345L)
            return (810);
        if (ip->i_atime < 1577836800L)
            return (811);
        if (ip->i_flag & IACC)
            return (812);       /* the flag is CONSUMED, or every later stat
                                 * pays for a firmware call it does not need */
        if ((ip->i_flag & IMOD) == 0)
            return (813);       /* ...and IMOD raised, which is what tells
                                 * 1.12's iupdat there is something to write */
        if (va.va_atime != ip->i_atime)
            return (814);       /* getattr reports the FRESH stamp, not the
                                 * one it read before calling itimes */
    }
    iput(ip);

    /* Cases 815 and 816 -- the superblock's own fs_time stamp -- USED TO BE
     * HERE and moved to allocprobe when the probe was split across two gates
     * (UFSPROBE / UFSVNPROBE, see the head of this file).  They assert on
     * allocsb, which only the allocator section drives through a refill, and a
     * case whose precondition is in the other gate's file is a case that
     * cannot fail honestly.  They belong beside the allocator in any event:
     * the property is 2.11BSD's balloc stamping fs_time, not the read path's.
     */

    /* ---- (m) THE CLOCK IS NO LONGER A ROM CALL (apple/fgx#182) -----------
     *
     * EVERY CASE ABOVE PASSES WHETHER OR NOT kern_time COSTS AN EXCURSION,
     * because they assert what the clock SAYS and this increment changed what
     * it COSTS.  So the cost is asserted directly, which is the only way this
     * work can go red.
     *
     * The measurement it is derived from: one RTC read is 3.6 ms
     * (src/userland/rtcbench, 600 iterations, syscall floor subtracted), which
     * is 0.22 of a 60 Hz tick.  A hundred of them is 360 ms = ~21 ticks.  The
     * derived clock pays a KSVC and some 32-bit arithmetic per call, plus AT
     * MOST one re-sync excursion if the loop straddles a KT_RESYNC boundary --
     * well under a tick in total.  Five is a tenfold margin on the new path and
     * a quarter of the old one, so it discriminates without being tight enough
     * to fail on a slow machine.
     *
     * GUARDED ON HAVING A CLOCK, and that is not defensive: with no RTC
     * kern_time never syncs, so every call takes the slow path by design and
     * the loop below would legitimately cost a hundred excursions.  Asserting
     * a cost bound on a machine with a flat battery would report a filesystem
     * bug for a dead coin cell. */
    if (now != 0L) {
        unsigned t0, t1;
        long     prev, cur;
        int      k;

        t0   = probe_ticks();
        prev = 0L;
        for (k = 0; k < 100; k++) {
            cur = kern_time();
            /* NEVER BACKWARD.  The re-sync lands on a whole second from a
             * 1 s-granular RTC, so an unclamped derived clock steps back --
             * and two files created either side of that carry out-of-order
             * mtimes.
             *
             * THIS WINDOW CANNOT CONTAIN A RE-SYNC and therefore cannot
             * falsify the clamp: a hundred calls take well under a second and
             * KT_RESYNC_TICKS is 60 s, so every call here is a fast path.
             * What it does assert is that the fast path itself is ordered,
             * which is not nothing -- a wrong borrow in the 16-bit elapsed
             * test would show up here as a jump backward.  Said plainly rather
             * than left to be assumed, on the same footing as the locking note
             * in section 1.11c. */
            if (cur < prev)
                return (817);
            prev = cur;
        }
        t1 = probe_ticks();
        if ((unsigned)(t1 - t0) >= 5)
            return (818);       /* still paying per call, not reading a counter */
        if (prev < 1577836800L)
            return (819);       /* ...and still a real date afterwards */
    }

    return (0);
}


/* probe_look -- drive VOP_LOOKUP the way lookup() would.
 *
 * The four fields ufs_lookup reads, and no more: ni_ptr and ni_namelen are the
 * component (NOT NUL-terminated in real use -- they point into the middle of a
 * path), ni_next is what tells it whether this is the LAST component, and
 * ni_nameiop carries the operation and LOCKPARENT.
 *
 * ni_next POINTS AT A NUL HERE, which means "last component" -- the case whose
 * lock disposal differs.  A helper that pointed it at more path would be
 * testing the intermediate case, and both are worth having; this one is the
 * one every assertion below is written against, so it is fixed rather than a
 * parameter nobody varies.
 */
static char probe_nameend[1];   /* a NUL, so ni_next says "last component" */

/* STATIC, not an automatic, and it is the same rule probesb and allocsb follow
 * at the head of this file.  A nameidata is ~40 bytes and this runs on the boot
 * path -- but the reason is sharper than frame size: ufs_lookup writes its
 * results THROUGH this pointer, and fcc has taken the DATA bank for the address
 * of an automatic struct before (the jmp_buf that landed in the malloc heap).
 * Measured here: with `nd` an automatic, one lookup returned 0 and reading
 * probe_nd.ni_vp back crashed the machine. */
static struct nameidata probe_nd;

static int
probe_look(dvp, ndp, nm, n)
struct vnode     *dvp;
struct nameidata *ndp;
char             *nm;
int               n;
{
    int error;

    ndp->ni_ptr      = nm;
    ndp->ni_namelen  = (short)n;
    ndp->ni_next     = probe_nameend;
    ndp->ni_nameiop  = LOOKUP;
    ndp->ni_vp       = (struct vnode *)0;
    ndp->ni_dvp      = (struct vnode *)0;
    ndp->ni_isdotdot = 0;
    /* THE PARENT LOCK IS TAKEN AND GIVEN BACK HERE (UFS 1.12d), exactly as
     * ufs_wprobe's dirlook does it and for the reasons written out there:
     * VOP_LOOKUP requires a locked parent, and a directory these cases KEEP
     * cannot be one they hold locked, because they look it up by name again
     * and iget returns a locked inode.
     *
     * WHICH ARM RAN DECIDES THE DISPOSAL, and that is why the unlock is not
     * unconditional here where it is in dirlook.  These cases search with a
     * plain LOOKUP -- no LOCKPARENT -- so ufs_lookup releases the parent
     * itself on the ordinary-name arm and does NOT on a miss, on an error, or
     * on the self-naming arm where ni_vp IS the parent.  namei's lookup()
     * settles the same question with its bad:/bad2: labels; asking is what a
     * caller standing in for it can do instead. */
    VOP_LOCK(dvp);
    error = VOP_LOOKUP(dvp, ndp);
    if (VOP_ISLOCKED(dvp))
        VOP_UNLOCK(dvp);
    return (error);
}


/* ---- THE NAME LOOKUP AND readdir (UFS 1.11c) ----------------------------
 *
 * VOP_LOOKUP IS CALLED DIRECTLY HERE, with a nameidata built by hand, rather
 * than through namei.  That is deliberate: namei's own behaviour is already
 * asserted by the path-walk probe, and what is new at 1.11c is
 * whether UFS answers the same contract over real directory blocks.  Driving
 * the vnode op directly is what makes a failure name THIS file rather than the
 * walk above it.
 *
 * THE ORACLE IS `fgxfs ls`, which reports the root of disk/ufsscratch.fs as
 * `.` and `..` at inode 2, `lost+found` at 3 and `big` at 4.  Those numbers are
 * the other implementation's, read off the same volume.
 *
 * LOCKING IS REAL HERE AS OF 1.12d, and these cases were written before it
 * was.  What that means for them is not that they now assert the lock -- they
 * do not, and lockguard below is where the state transitions are
 * asserted -- but that they now RUN under it.  Every iget below hands back a
 * locked inode and every iput gives the lock back, so a disposal that had been
 * merely untidy is now a panic.  That is the useful part: the pairs here were
 * written to upstream's contract from 1.11a on and this is the first run that
 * can tell whether they meant it.
 */
static int
nameguard(devvp, mp)
struct vnode *devvp;
struct mount *mp;
{
    struct inode    *rip;
    struct inode    *fip;
    struct vnode    *rvp;
    struct vnode    *fvp;
    struct direct   *e;
    struct uio       u;
    struct iovec     iov;
    int              eof;
    int              off;
    int              seen;
    int              rderr;     /* the readdir return, kept off `eof' -- which
                                 * is that call's OUT parameter */

    if (iget(mp, (ino_t)UFS_ROOTINO, &rip) != 0)
        return (820);
    rvp = ITOV(rip);
    /* HELD UNLOCKED FOR THE WHOLE SECTION.  probe_look takes the parent lock
     * for each search and gives it back, and "." and ".." below resolve to
     * this very vnode -- which a lookup cannot do while this process holds it
     * locked.  See probe_look. */
    VOP_UNLOCK(rvp);
    /* ---- (a) AN ORDINARY NAME ------------------------------------------ */
    if (probe_look(rvp, &probe_nd, "big", 3) != 0)
        return (821);
    fvp = probe_nd.ni_vp;
    if (fvp == (struct vnode *)0)
        return (822);
    if (probe_nd.ni_dvp != rvp)
        return (823);           /* set FIRST and unconditionally */
    fip = VTOI(fvp);        /* through a local.  fcc rejected the member
                             * reached straight off VTOI here and the cause
                             * was never established -- VTOI(vp)->i_number
                             * compiles in isolation.  Not attributed. */
    if (fip->i_number != (ino_t)4)
        return (824);
    if (fvp->v_type != VREG)
        return (825);
    if (fip->i_size != 307200L)
        return (826);           /* it is really /big, not merely inode 4 */
    iput(fip);                  /* ni_vp comes back LOCKED -- see ufs_lookup */

    /* ---- (b) A SECOND LOOKUP ON THE SAME DIRECTORY ----------------------
     *
     * This case exists because it was BLOCKED, not because two is a round
     * number.  1.11c landed with the whole of nameguard uncalled on the
     * reading that "two consecutive VOP_LOOKUPs on the same directory hang
     * the machine inside Blk_Read and one does not", and that was the wild
     * return of apple/fgx#183 seen through a screen the machine had already
     * erased.  With the page-1 frame parked, the second lookup is ordinary --
     * and this asserts it stays that way.
     *
     * It is also the first case here that reaches a DIRECTORY: lost+found is
     * VDIR at inode 3, so the ordinary-name arm's iget and VOP_LOCK run
     * against something other than the file above. */
    if (probe_look(rvp, &probe_nd, "lost+found", 10) != 0)
        return (827);
    fvp = probe_nd.ni_vp;
    if (fvp == (struct vnode *)0)
        return (828);
    fip = VTOI(fvp);
    if (fip->i_number != (ino_t)3)
        return (829);
    if (fvp->v_type != VDIR)
        return (830);
    iput(fip);

    /* ---- (c) "." IS THE DIRECTORY ITSELF --------------------------------
     *
     * Reno returns the SAME vnode with an extra reference rather than looking
     * anything up, and the assertion has to be pointer identity: an
     * implementation that scanned the block and iget()'d inode 2 would give a
     * vnode with the right i_number and the wrong lock. */
    if (probe_look(rvp, &probe_nd, ".", 1) != 0)
        return (831);
    if (probe_nd.ni_vp != rvp)
        return (832);
    vrele(rvp);                 /* balance the vref "." took */

    /* ---- (d) ".." AT THE ROOT NAMES THE ROOT ----------------------------
     *
     * On this volume root's ".." is inode 2, which is root -- so this does not
     * exercise the unlock/iget/lock dance, it exercises the arm that catches a
     * directory naming itself under another name and hands back dvp instead of
     * deadlocking iget against a lock the vnode already holds.  Worth saying,
     * because the case reads like ".." coverage and is not. */
    probe_nd.ni_isdotdot = 1;
    if (probe_look(rvp, &probe_nd, "..", 2) != 0)
        return (833);
    if (probe_nd.ni_vp != rvp)
        return (834);
    vrele(rvp);
    probe_nd.ni_isdotdot = 0;

    /* ---- (e) A NAME THAT IS NOT THERE -----------------------------------
     *
     * ENOENT, and ni_vp still null.  The second half is the one that matters:
     * a scan that left a stale ni_vp behind would hand the caller the previous
     * lookup's vnode with an error code, and every caller here tests the code
     * first and would never notice. */
    if (probe_look(rvp, &probe_nd, "nosuch", 6) != ENOENT)
        return (835);
    if (probe_nd.ni_vp != (struct vnode *)0)
        return (836);
    if (probe_nd.ni_dvp != rvp)
        return (837);           /* set before anything can fail */

    /* ---- (f) A NAME THE SAME LENGTH AS ONE THAT IS THERE ----------------
     *
     * "bit" is three bytes, exactly like "big", so a search that compared only
     * d_namlen would hand back inode 4 for it.  NOTHING ELSE IN THIS FILE CAN
     * TELL THOSE APART: the four names on this volume are 1, 2, 10 and 3 bytes
     * long, all different, so every other hit and every other miss lands the
     * same way whether or not the bytes are compared.  Found by mutation --
     * dropping ufs_dirmatch's byte loop left every case above green. */
    if (probe_look(rvp, &probe_nd, "bit", 3) != ENOENT)
        return (855);
    if (probe_nd.ni_vp != (struct vnode *)0)
        return (856);

    /* ---- (f) readdir REFUSES WHAT IT CANNOT ANSWER SAFELY ---------------
     *
     * The alignment rules ARE the interface (see ufs_readdir), so they are
     * asserted before the transfer that depends on them.  A request under one
     * DIRBLKSIZ rounds down to zero, and a zero-length read is
     * indistinguishable from end-of-directory; an unaligned offset would hand
     * back a partial entry whose d_reclen walks the caller off its own buffer.
     * Both are EINVAL, and both are checked BEFORE any I/O -- so a green here
     * also says the refusal is not merely the read failing for its own
     * reasons. */
    iov.iov_base = probebuf;
    iov.iov_len  = DIRBLKSIZ - 1;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = DIRBLKSIZ - 1;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    VOP_LOCK(rvp);
    rderr = VOP_READDIR(rvp, &u, (char *)0, &eof);
    VOP_UNLOCK(rvp);
    if (rderr != EINVAL)
        return (838);

    iov.iov_base = probebuf;
    iov.iov_len  = DIRBLKSIZ;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)1;
    u.uio_resid  = DIRBLKSIZ;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    VOP_LOCK(rvp);
    rderr = VOP_READDIR(rvp, &u, (char *)0, &eof);
    VOP_UNLOCK(rvp);
    if (rderr != EINVAL)
        return (839);

    /* ---- (g) THE DIRECTORY, READ AS BYTES -------------------------------
     *
     * The oracle is `fgxfs ls`, and dir.h carries the bytes it is asserting
     * against -- `02 00 08 00 01 00 2e 00` and the three entries after it.
     * Those numbers came off the volume the other implementation wrote.
     *
     * The walk STEPS BY d_reclen, never by DIRSIZ, because an entry may carry
     * free space after it; and it must land EXACTLY on DIRBLKSIZ, which is the
     * invariant that lets a scan resynchronise at a block boundary. */
    iov.iov_base = probebuf;
    iov.iov_len  = DIRBLKSIZ;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = DIRBLKSIZ;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    eof = 0;
    VOP_LOCK(rvp);
    rderr = VOP_READDIR(rvp, &u, (char *)0, &eof);
    VOP_UNLOCK(rvp);
    if (rderr != 0)
        return (840);
    if (u.uio_resid != 0)
        return (841);           /* the whole block moved */
    if (eof != 1)
        return (842);           /* the root is one DIRBLKSIZ, so that was all
                                 * of it -- and eof is computed from i_size,
                                 * not from the read coming up short */

    off  = 0;
    seen = 0;
    while (off < DIRBLKSIZ) {
        e = (struct direct *)&probebuf[off];
        if (e->d_reclen < DIRSIZ(e->d_namlen))
            return (843);       /* a record too short for its own name */
        if ((e->d_reclen & 3) != 0)
            return (844);
        if (seen == 0) {
            if (e->d_ino != (ino_t)2 || e->d_namlen != 1 ||
                e->d_reclen != 8 || e->d_name[0] != '.')
                return (845);
        } else if (seen == 1) {
            if (e->d_ino != (ino_t)2 || e->d_namlen != 2 ||
                e->d_reclen != 12 ||
                e->d_name[0] != '.' || e->d_name[1] != '.')
                return (846);
        } else if (seen == 2) {
            if (e->d_ino != (ino_t)3 || e->d_namlen != 10 ||
                e->d_reclen != 20 || e->d_name[0] != 'l')
                return (847);
        } else if (seen == 3) {
            if (e->d_ino != (ino_t)4 || e->d_namlen != 3 ||
                e->d_name[0] != 'b' || e->d_name[1] != 'i' ||
                e->d_name[2] != 'g')
                return (848);
            /* THE LAST ENTRY CARRIES THE REST OF THE BLOCK.  8+12+20 = 40 are
             * spoken for, so `big` is 472 bytes of which it uses 12 -- which
             * is why the walk must step by d_reclen and why this is the number
             * that proves it did. */
            if (e->d_reclen != DIRBLKSIZ - 40)
                return (849);
        } else {
            return (850);       /* a fifth entry: fgxfs sees four */
        }
        off = off + (int)e->d_reclen;
        seen = seen + 1;
    }
    if (off != DIRBLKSIZ)
        return (851);           /* the chain must land ON the boundary */
    if (seen != 4)
        return (852);

    /* ---- (h) readdir IS FOR DIRECTORIES ---------------------------------
     *
     * ENOTDIR off the vnode type, checked before the alignment rules upstream
     * and here.  /big is the only non-directory this volume has. */
    if (probe_look(rvp, &probe_nd, "big", 3) != 0)
        return (853);
    fvp = probe_nd.ni_vp;
    iov.iov_base = probebuf;
    iov.iov_len  = DIRBLKSIZ;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = DIRBLKSIZ;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    /* fvp COMES BACK LOCKED from probe_look -- ufs_lookup's contract -- so
     * this one already holds what the three above had to take. */
    if (VOP_READDIR(fvp, &u, (char *)0, &eof) != ENOTDIR)
        return (854);
    iput(VTOI(fvp));

    vrele(rvp);             /* unlocked since the head of this section */
    return (0);
}


/* ---- THE INODE LOCK (UFS 1.12d) ----------------------------------------
 *
 * WHAT THESE CASES CANNOT SEE, said first so a green gate is not read as more
 * than it is: CONTENTION.  The lock exists so that two processes reading a
 * directory block, changing a slot and writing it back cannot interleave, and
 * this probe runs at boot with one process.  Nothing here can be made to fail
 * by deleting the exclusion itself.  A green result says the PROTOCOL is
 * consistent; it does not say the lock excludes anybody.
 *
 * WHY THE PROTOCOL IS STILL WORTH ASSERTING, and it is not a consolation
 * prize: a single-threaded run makes every protocol error DETERMINISTIC.  A
 * lock taken twice by one process is a certain panic rather than a rare one,
 * and a lock never released is a certain stop at the next acquisition of the
 * same inode.  Bringing 1.12d up found eight defects that way, each of them
 * reproducing on every run -- including two that had been latent since 1.11a
 * because the lock was ufs_nullop and could not notice them: a lookup whose
 * result was never released (case 1130's "a", which resolves to the ROOT),
 * and a teardown clearing the whole flag word one line before iput.
 *
 * WHAT IS DELIBERATELY NOT HERE: the CONSTRUCTION window -- iget holds the
 * lock across its own bread so that a second finder cannot be handed an inode
 * whose dinode has not been read.  Reaching it needs a second process inside
 * iget, which is contention by another name.  ufs_ihashget's header carries
 * the argument in place of a case.
 *
 * WHICH CASES CAN ACTUALLY GO RED, MEASURED.  Eight mutations were run
 * against these; four fired at the case they were aimed at and four were
 * caught EARLIER, by the kernel, with a panic:
 *
 *   ufs_lock not recording the holder            -> 863
 *   ufs_unlock not clearing it                   -> 865
 *   ufs_lookup always releasing the parent       -> 874
 *   ufs_lookup never releasing it                -> 878
 *
 *   iget's construction arm not locking          -> panic `unlkfree 0002`
 *   iget's hash-hit arm not locking              -> panic `unlkfree 0002`
 *   iput not unlocking                           -> panic `lockself 0004`
 *   ufs_lookup unlocking the leaf, not the parent-> panic `unlkfree 0004`
 *
 * SO 862, 868, 869 AND 873/877 ARE SHADOWED and cannot be made to fail on
 * their own, which is worth stating rather than leaving to be discovered by
 * someone counting cases.  The reason is not weakness in them: those four
 * mutations break an invariant the KERNEL now checks at every call site, so
 * the first iput or the next lock of the same inode panics long before this
 * section runs -- naming the inode, which is more than a case number does.
 * What the cases buy is the contract written down at the one place it is
 * directly observable, and a detector for the day a panic is softened.
 */
static char lknbig[3] = { 'b', 'i', 'g' };

/* lockfill -- probe_nd, set up for a RAW VOP_LOOKUP of "big" under `op`.
 *
 * probe_nd is reused rather than a second nameidata declared: 158 bytes, and
 * the section that owns it has finished by the time this runs.  dirlook does the same filling for its own
 * calls; this is the same work for a caller that must NOT go through dirlook,
 * because dirlook gives the parent lock back and (e) and (f) are about who
 * holds it. */
static void
lockfill(op)
int op;
{
    probe_nd.ni_ptr      = lknbig;
    probe_nd.ni_namelen  = 3;
    probe_nd.ni_next     = probe_nameend;
    probe_nd.ni_nameiop  = (short)op;
    probe_nd.ni_vp       = (struct vnode *)0;
    probe_nd.ni_dvp      = (struct vnode *)0;
    probe_nd.ni_isdotdot = 0;
    probe_nd.ni_offset   = (off_t)0;
    probe_nd.ni_count    = 0;
    probe_nd.ni_endoff   = (off_t)0;
}

static int
lockguard(devvp, mp)
struct vnode *devvp;
struct mount *mp;
{
    struct inode *ip;
    struct inode *ip2;
    struct vnode *rvp;
    struct vnode *lvp;
    ino_t         lkino;
    int           i;

    /* ---- (a) iget HANDS BACK A LOCKED INODE ---------------------------- */
    /* AN INODE THAT IS NOT IN CORE, so this is iget's CONSTRUCTION arm and
     * not its hash-hit arm -- (c) below is the hash-hit arm and would be
     * unable to fail if this one had already been it.  ufs_ifind answers "is
     * it in core" without taking a reference or a lock, which is the whole
     * reason it exists apart from ufs_ihashget.
     *
     * THE NUMBER IS SEARCHED FOR RATHER THAN PICKED, and the first version of
     * this case picked one: lost+found, "the one directory no other section
     * here touches".  It is touched -- case 827 looks it up -- and the case
     * went red on its own precondition at the first run.  Which inodes are in
     * core depends on what the sections above did and on whether the vnode
     * pool has wrapped since, and both of those change whenever a case is
     * added anywhere in this file.  A search cannot go stale that way.
     *
     * A FREE SLOT IS AN ACCEPTABLE ANSWER.  iget reads whatever the i-list
     * holds and the lock has no opinion about the contents; what this needs
     * is an inode nothing else in this run is holding. */
    lkino = (ino_t)0;
    for (i = 3; i < 3 + 64; i++) {
        if (ufs_ifind(devvp->v_rdev, (ino_t)i) == (struct inode *)0) {
            lkino = (ino_t)i;
            break;
        }
    }
    if (lkino == (ino_t)0)
        return (860);      /* 64 consecutive inodes in core: not this volume */
    if (iget(mp, lkino, &ip) != 0)
        return (861);
    if (!VOP_ISLOCKED(ITOV(ip)))
        return (862);
    /* AND THIS PROCESS HOLDS IT.  i_lockholder is what turns a self-deadlock
     * into a panic naming the inode instead of a machine that stops, so a
     * lock that set the bit and left the holder alone would take the whole
     * diagnosis away without failing anything else. */
    if (ip->i_lockholder != (short)kc_curpid())
        return (863);

    /* ---- (b) UNLOCK CLEARS BOTH ---------------------------------------- */
    VOP_UNLOCK(ITOV(ip));
    if (VOP_ISLOCKED(ITOV(ip)))
        return (864);
    if (ip->i_lockholder != 0)
        return (865);      /* a stale holder is a false self-deadlock later */

    /* ---- (c) THE HASH-HIT ARM LOCKS TOO -------------------------------- */
    /* GUARANTEED to be that arm rather than assumed: (a)'s reference is still
     * held, so the inode cannot have left core.  iget has two arms and only
     * one of them was exercised above; ufs_ihashget returns a bare reference
     * and iget is what locks after it, so this is the case that says the
     * second half of that pair is wired. */
    if (iget(mp, lkino, &ip2) != 0)
        return (866);
    if (ip2 != ip)
        return (867);      /* one inode for two gets, as case 723 says */
    if (!VOP_ISLOCKED(ITOV(ip)))
        return (868);

    /* ---- (d) iput UNLOCKS AS WELL AS RELEASING ------------------------- */
    /* (a)'s reference is what makes this observable: without it the vnode
     * would be idle after the iput and its lock state would be a reading of
     * something nobody owns. */
    iput(ip2);
    if (VOP_ISLOCKED(ITOV(ip)))
        return (869);
    vrele(ITOV(ip));        /* (a)'s reference, left unlocked by (b) */

    /* ---- (e) VOP_LOOKUP RETURNS ni_vp LOCKED, AND KEEPS THE PARENT ----- */
    /* dirlook cannot show either half.  It gives the parent lock back on the
     * way out (see its header), so the parent is always "unlocked" through
     * that path; and it is the only search these cases use.  This calls
     * VOP_LOOKUP directly, which is what namei does, and asserts the contract
     * namei relies on. */
    if (iget(mp, (ino_t)UFS_ROOTINO, &ip) != 0)
        return (870);
    rvp = ITOV(ip);         /* LOCKED, which is VOP_LOOKUP's precondition */
    lockfill(LOOKUP | LOCKPARENT);
    if (VOP_LOOKUP(rvp, &probe_nd) != 0)
        return (871);
    lvp = probe_nd.ni_vp;
    if (lvp == (struct vnode *)0)
        return (872);
    if (!VOP_ISLOCKED(lvp))
        return (873);      /* the leaf: "ni_vp comes back LOCKED" */
    if (!VOP_ISLOCKED(rvp))
        return (874);      /* and LOCKPARENT means the parent stays */
    iput(VTOI(lvp));

    /* ---- (f) ...AND WITHOUT LOCKPARENT IT GIVES THE PARENT BACK -------- */
    /* The two arms differ by ONE flag and dispose of the parent oppositely,
     * which is exactly the decision namei's lookup() depends on the
     * filesystem having made.  Asserting only (e) would leave a ufs_lookup
     * that never releases the parent green -- and that is a leak of a LOCK,
     * which stops the machine rather than merely wasting a reference. */
    lockfill(LOOKUP);
    if (VOP_LOOKUP(rvp, &probe_nd) != 0)
        return (875);
    lvp = probe_nd.ni_vp;
    if (lvp == (struct vnode *)0)
        return (876);
    if (!VOP_ISLOCKED(lvp))
        return (877);
    if (VOP_ISLOCKED(rvp))
        return (878);      /* no LOCKPARENT: the parent went back */
    iput(VTOI(lvp));

    vrele(rvp);             /* unlocked since (f) */
    return (0);
}


/* ufs_probe -- the entry point probe_dev.s calls in a UFSVNPROBE build.
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

        {
            int g;

            g = inodeguard(devvp, &pmnt);
            if (g)
                return (g);
        }

        {
            int g;

            g = readguard(devvp, &pmnt);
            if (g)
                return (g);
        }

        {
            int g;

            g = nameguard(devvp, &pmnt);
            if (g)
                return (g);
            /* The inode lock, whose properties are lookup's and iget's and so
             * belong to the gate that owns both.  No restore bracket: it
             * takes references and locks and reads two names off the root,
             * and writes nothing. */
            g = lockguard(devvp, &pmnt);
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
        if (VFS_MOUNT(&pmnt, (char *)0, (char *)0, &probe_nd) != EINVAL)
            return (712);

        /* ---- and unmount ------------------------------------------------ */
        /* Out of service first: ufs_unmount calls vflush, and vflush asserts
         * MNT_MPBUSY (Reno's panic, vfs_subr.c:537).  Reno's publisher is
         * vfs_busy; FGX's is vfs_dounmount, which a probe does not go through
         * because it drives the vector on a mount of its own.  See
         * ufs_wprobe.c's copy of this for the whole reasoning, and
         * apple/fgx#272 for what it cost. */
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
