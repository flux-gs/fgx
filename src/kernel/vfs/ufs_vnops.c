/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno ufs/ufs_vnops.c
 *   Ported from ufs/ufs_vnops.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* ufs_vnops.c -- UFS's vnode operations.  UFS 1.11a: the VECTOR, and almost
 * none of the operations.
 *
 * WHY IT EXISTS BEFORE IT DOES ANYTHING.  getnewvnode takes the ops vector as
 * an argument -- a vnode without one cannot be dispatched to at all -- so iget
 * cannot mint its first inode until this table exists.  Everything in it is a
 * refusal today; 1.11b fills in read and getattr, 1.11c lookup and readdir,
 * 1.12 the rest.
 *
 * REFUSALS RATHER THAN NULLS, and rather than one shared stub.  Reno's
 * dead_vnodeops is the model and it distinguishes three kinds:
 *
 *   ufs_enotsup   an operation this filesystem will support and does not yet.
 *                 ENOSYS: the caller asked something reasonable of a
 *                 filesystem that cannot answer it, which is what ENOSYS is
 *                 for, and 1.11b/c/1.12 replace these one at a time.
 *   ufs_erofs     an operation that MODIFIES.  EROFS, not ENOSYS, because the
 *                 mount is forced read-only until 1.12 and "read-only file
 *                 system" is the true answer rather than a placeholder --
 *                 a caller can act on it, and a test can assert it.
 *   ufs_nullop    an operation whose correct behaviour is to succeed and do
 *                 nothing.
 *
 * The three are separate so a red says WHICH kind of gap was hit.  A single
 * stub returning ENOSYS everywhere would report a write to a read-only mount as
 * an unimplemented feature, which is the sort of thing that gets diagnosed
 * twice.
 *
 * VECTOR ORDER IS `struct vnodeops`'s, and dead_vnops.c already says what
 * happens if it drifts: "a shifted vector is a call that lands on the wrong
 * operation rather than a compile error".  The comment beside each slot is the
 * only check there is, so the comments are load-bearing.
 */

#include "fsparam.h"
#include "vnode.h"
#include "specdev.h"    /* v_rdev: ufs_strategy names the device vnode's dev */
#include "buf.h"
#include "uio.h"
#include "dir.h"      /* 1.11c: readdir clamps to DIRBLKSIZ */
#include "namei.h"    /* 1.12c: create and remove take a nameidata */
#include "mount.h"
#include "vfsops.h"
#include "ufsmount.h"  /* 1.12b: ufs_inactive frees an inode, which needs the
                        *        mount's superblock through ITOUMP */
#include "inode.h"
#include "file.h"      /* 1.12a: FWRITE, the flag ufs_fsync consults */

/* From ufs_inode.c, which is PUT after this file so the vector can name it. */
extern int  ufs_reclaim();
extern void ufs_itimes();
extern int  ufs_lookup();       /* ufs_lookup.c, PUT after this file */

/* ufs_bmap.c, beside this file in ufs.mod. */
extern int ufs_bmap();
extern int ufs_bmapx();     /* 1.12a: the same descent, with allocation */
extern int iupdat();        /* ufs_inode.c */
extern int ufs_itrunc();    /* ufs_inode.c, 1.12b */
extern int ufs_ialloc();    /* 1.12c: maknode takes a number off the i-list */
extern int ufs_direnter();  /* ufs_lookup.c, 1.12c */
extern int ufs_dirremove();
/* Used before they are defined, or defined in a file PUT after this one.  The
 * warning fcc gives without these is not cosmetic: an implicit declaration is
 * assumed to return int, and a far pointer returned that way loses its bank. */
extern int  ufs_read();
extern int  ufs_lock();     /* defined below; ufs_inactive calls it BY NAME
                             * rather than through VOP_LOCK -- see there */
extern int  ufs_unlock();
extern int  iget();
extern void iput();
extern int ufs_dirempty();  /* ufs_lookup.c, 1.12c-b: rmdir's precondition */
extern int ufs_dirrewrite();/* ufs_lookup.c, 1.12c-c: rename's overwrite */
extern int ufs_checkpath(); /* ufs_lookup.c, 1.12c-c: the loop check */
extern int ufs_access();    /* defined at the foot of this file; rename
                             * asks it of the source before rewriting
                             * that directory's ".." */
extern void clrbuf();       /* ufs_bmap.c, since the bank split */
extern void ufs_setvnodeops();  /* ufs_inode.c, likewise */
extern void vfs_setspecops();   /* vfs_subr.c, in vfs.mod -- see ufs_dirinit */
extern void vfs_setcacheops();  /* vfs_subr.c, in vfs.mod -- see ufs_dirinit */
/* vfs_cache.c, THIS bank since the name cache was wired -- the two entries
 * vfs.mod still needs, which ufs_dirinit hands over for the same reason it
 * hands over spec_vnodeops. */
extern struct cacheops ufs_cacheops;
/* vfs_cache.c, THIS module.  rename and rmdir invalidate by re-minting the
 * directory's capability number; see their sites for which name goes stale. */
extern void cache_purge();
/* spec_vnops.c, THIS bank since 2026-09-05 -- the plain device vector, which
 * ufs_dirinit hands to vfs.mod because vfs_subr.c can no longer form it. */
extern struct vnodeops spec_vnodeops;
extern int ufs_ifmttovt();
extern void vrele();
extern void ufs_ifree();
extern void vgone();

/* vfs.mod, through src/modules/ufs/vfs_import.s.  uiomove and biodone are new
 * at 1.11b and are why VFSCORE_COUNT moved from 9 to 11. */
extern int  bread();
extern int  bwrite();
extern struct buf *getblk();
extern void brelse();
extern int  uiomove();
extern void biodone();
extern void kc_panic();
/* vfs.mod, through src/modules/ufsdir/vfs_import.s.  These are not CALLED from
 * here except for the three spec_* the ufsspec_* wrappers forward to -- the
 * rest are ENTRIES of spec_inodeops below, whose cells must name a function in
 * this module, so each is the address of the shim and the shim crosses.  UFS
 * 1.13a; include/modules.s carries the argument for the ABI. */
extern int  spec_lookup();
extern int  spec_open();
extern int  spec_close();
extern int  spec_read();
extern int  spec_write();
extern int  spec_ioctl();
extern int  spec_select();
extern int  spec_bmap();
extern int  spec_strategy();
extern int  spec_badop();
extern void ufs_setspecops();   /* ufs_inode.c, in the other half */
extern dev_t ufs_getrdev();
extern void  ufs_setrdev();
/* The inode lock's three primitives, 1.12d.  kc_sleep is the UNINTERRUPTIBLE
 * one -- KSVC_SLEEPUN -- which is what the buffer cache's lock waits already
 * use, and the distinction is the whole protocol: a lock wait a signal can
 * cut short returns to a caller that believes it holds the inode. */
extern void kc_sleep();
extern void kc_wakeup();
extern int  kc_curpid();
extern int  kc_curuid();       /* UFS 2.6: KSVC_CURUID */
extern int  kc_curgid();       /* UFS 2.6: KSVC_CURGID */

int
ufs_enotsup()
{
    return (ENOSYS);
}


/* ufs_select -- select(2) on a regular file.  4.3BSD-Reno ufs/ufs_vnops.c:763,
 * verbatim: `return (1)' for EVERY `which', marked XXX upstream.
 *
 * A REGULAR FILE NEVER BLOCKS, so it is ready to read and ready to write, and
 * the exceptional question (`which' 0) gets the same answer.  2.11BSD says the
 * same in ino_select's default arm, which covers regular files, directories
 * and block devices alike (usr/sys/sys/sys_inode.c:376-377).  So a file named
 * in an exceptional set is reported in it, as on both.
 *
 * vfs_select reads an arm's return as a BOOLEAN, which is why this slot holds
 * a select routine rather than ufs_enotsup: an errno is nonzero, and would be
 * read as an answer.
 */
int
ufs_select(vp, which, fflags, cred)
    struct vnode *vp;
    int    which;
    int    fflags;
    char  *cred;
{
    return (1);
}


/* ufs_strategy -- turn a LOGICAL block request into a physical one.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:1472-1524.  THIS IS THE PIECE THAT MAKES THE
 * BUFFER CACHE WORK FOR FILES, and everything below it was already waiting:
 * vfs_bio.c keys the cache by `(b_vp, b_lblkno)` and sets `b_blkno = b_lblkno`
 * "until VOP_BMAP says otherwise"; bgetvp sets `b_dev = NODEV` for anything
 * that is not a device vnode and its comment names this function as what fills
 * it in; bio_strategy.c's header says the device number "becomes a real
 * major/minor dev_t with specfs in 1.5, where ufs_strategy fills it in from the
 * inode's i_devvp".  All three were written against a function that did not
 * exist yet.  This is it.
 *
 * SO A FILE'S BLOCKS ARE CACHED BY LOGICAL NUMBER, which is the whole reason
 * for the two-block-number scheme: a block's identity within a file survives
 * the file being extended or moved, and the physical address is resolved as
 * late as the I/O.  Two files can hold logical block 0 at once without
 * colliding, and the same physical block reached through two different files
 * would be a bug the cache should NOT paper over.
 *
 * THE `b_blkno == b_lblkno` TEST IS RENO'S "not mapped yet", and it is
 * deliberately conservative rather than exact: a logical block that genuinely
 * lives at the same physical number re-runs bmap on a re-issue.  That is
 * idempotent -- bmap is a pure function of the inode's address array -- so the
 * cost is one lookup, and the alternative is a separate "mapped" flag that
 * every path would have to clear correctly.
 *
 * FGX's ufs_bmap TAKES THE ADDRESS ARRAY, NOT THE INODE (`ufs_bmap(devvp,
 * addr, lbn, resultbno)`), because it was written at 1.10c before an in-core
 * inode existed and its own header says 1.11's iget would pass `dp->di_addr`.
 * That is this call.
 */
int
ufs_strategy(bp)
struct buf *bp;
{
    struct inode *ip;
    struct vnode *vp;
    int           error;

    if (bp->b_vp->v_type == VBLK || bp->b_vp->v_type == VCHR)
        kc_panic("ufs_strategy: spec");
    ip = VTOI(bp->b_vp);
    if (bp->b_blkno == bp->b_lblkno) {
        error = ufs_bmap(ip->i_devvp, ip->i_addr, bp->b_lblkno, &bp->b_blkno);
        if (error)
            return (error);
        if (bp->b_blkno == (daddr_t)-1)
            clrbuf(bp);
    }
    /* A HOLE IS NOT AN ERROR AND NOT AN I/O.  clrbuf above has already made
     * the buffer read as zeroes, which is what a hole contains; all that is
     * left is to mark it done, or bread's biowait waits for a transfer nobody
     * is going to perform.  Reno does exactly this. */
    if (bp->b_blkno == (daddr_t)-1) {
        biodone(bp);
        return (0);
    }
    vp = ip->i_devvp;
    bp->b_dev = vp->v_rdev;
    (*(vp->v_op->vn_strategy))(bp);
    return (0);
}


/* ufs_vbmap -- the VOP_BMAP slot.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:1447-1462, where it is called `ufs_bmap` and the
 * worker it forwards to is plain `bmap`.  THE NAMES ARE SWAPPED HERE and the
 * reason is chronological rather than considered: this tree's worker was
 * written at 1.10c, before a vnode op existed to wrap it, and took the name.
 * Renaming it now would touch every 1.10c caller and its probe to buy nothing,
 * so the WRAPPER carries the odd name and this comment.
 *
 * TWO OUT-PARAMETERS, EITHER OPTIONAL, and that is Reno's interface rather
 * than an accident: `vpp` asks "which vnode does the I/O actually go to" --
 * the answer is the device vnode, not this file -- and `bnp` asks "where does
 * logical block bn live".  vfs_bio's checkoverlap uses the first without the
 * second; ufs_strategy uses the second without the first.  A caller that wants
 * neither is asking nothing and gets 0.
 */
int
ufs_vbmap(vp, bn, vpp, bnp)
struct vnode  *vp;
daddr_t        bn;
struct vnode **vpp;
daddr_t       *bnp;
{
    struct inode *ip;

    ip = VTOI(vp);
    if (vpp != (struct vnode **)0)
        *vpp = ip->i_devvp;
    if (bnp == (daddr_t *)0)
        return (0);
    return (ufs_bmap(ip->i_devvp, ip->i_addr, bn, bnp));
}


/* ufs_getattr -- the inode's answer to stat(2).
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:355-398.  Copies out of the in-core inode; the
 * syscall layer turns a vattr into a `struct stat` and is the only place that
 * knows that shape.
 *
 * IT OPENS WITH ITIMES, as upstream does (`ITIMES(ip, &time, &time)`), so a
 * stat of a file that has been read since its last update reports the CURRENT
 * access time rather than the one on the platter.  That was not possible until
 * apple/fgx#167: kernel C had no clock, and this comment used to say so.
 * ufs_itimes reads one now, and only when a stamp is actually dirty.
 *
 * THE STAMPS STAY IN CORE until something writes the inode back, which is
 * 1.12's iupdat -- the mount is read-only, so IMOD has no consumer yet.  That
 * is Reno's arrangement too and not a shortcut: ITIMES sets IMOD and returns;
 * writing is a separate decision made by a separate function.
 *
 * va_bytes and va_gen are absent from `struct vattr` here; vnode.h says why.
 *
 * va_rdev IS REAL AS OF 1.13a, and only for the two types that have one.  It
 * lives in di_addr[0] -- inode.h derives exactly where from both upstreams --
 * which is the same word a regular file keeps its first block address in, so
 * reporting it unconditionally would name a device made out of a block number.
 * Reno's getattr does the same test (`if (vp->v_type == VBLK || vp->v_type ==
 * VCHR)`) for the same reason.
 */
int
ufs_getattr(vp, vap, cred)
struct vnode *vp;
struct vattr *vap;
char         *cred;
{
    struct inode *ip;

    ip = VTOI(vp);
    ufs_itimes(ip);
    vap->va_type      = vp->v_type;
    vap->va_mode      = ip->i_mode & ~IFMT;
    vap->va_nlink     = (short)ip->i_nlink;
    vap->va_uid       = ip->i_uid;
    vap->va_gid       = ip->i_gid;
    vap->va_fsid      = (long)ip->i_dev;
    vap->va_fileid    = (long)ip->i_number;
    vap->va_size      = ip->i_size;
    vap->va_blocksize = (long)FS_BLKSIZE;
    vap->va_atime     = ip->i_atime;
    vap->va_mtime     = ip->i_mtime;
    vap->va_ctime     = ip->i_ctime;
    vap->va_flags     = ip->i_flags;
    if (vp->v_type == VCHR || vp->v_type == VBLK)
        vap->va_rdev = ufs_getrdev(ip);
    else
        vap->va_rdev = (dev_t)NODEV;
    return (0);
}


/* ufs_readdir -- hand a directory's raw bytes to the caller.  UFS 1.11c.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:1362-1384, and it is thin upstream for the same
 * reason it is thin here: on this format the ON-DISK entry and the one the
 * caller wants are the SAME LAYOUT, so there is nothing to translate.  Later
 * BSDs grew a repacking loop precisely because that stopped being true.
 *
 * WHAT IT ACTUALLY DOES IS ENFORCE THE DIRBLKSIZ INVARIANT, which is the whole
 * of its value.  An entry may not straddle a 512-byte directory block, so a
 * caller that starts mid-block or asks for a length that ends mid-block gets a
 * partial entry and no way to know: d_reclen would walk it off the end of its
 * buffer.  Refusing both is what makes "read a directory as bytes and step by
 * d_reclen" a safe thing for userland to do.
 *
 * SO THE ALIGNMENT RULES ARE THE INTERFACE, not defensive coding:
 *   - uio_offset must be a multiple of DIRBLKSIZ;
 *   - the transfer is rounded DOWN to a multiple of DIRBLKSIZ;
 *   - a request smaller than one DIRBLKSIZ is EINVAL, because rounding it down
 *     gives zero and a zero-length read would look like end-of-directory.
 *
 * `lost` IS RESTORED TO uio_resid so the caller's own accounting still sees
 * the bytes it asked for and did not get.  Upstream does this and it looks
 * like bookkeeping until you notice that read(2) reports what MOVED by
 * comparing resid before and after: without it, a caller asking for 700 bytes
 * would be told 700 moved when 512 did.
 *
 * eofflagp IS SET FROM i_size AFTER THE READ, which is Reno's line
 * (`(VTOI(vp)->i_size - uio->uio_offset) <= 0`) and not the same as "the read
 * came up short" -- a short read can also mean the buffer filled.
 */
int
ufs_readdir(vp, uio, cred, eofflagp)
struct vnode *vp;
struct uio   *uio;
char         *cred;
int          *eofflagp;
{
    struct inode *ip;
    int           count;
    int           lost;
    int           error;

    if (uio->uio_rw != UIO_READ)
        kc_panic("ufs_readdir mode");
    if (vp->v_type != VDIR)
        return (ENOTDIR);

    count = (int)uio->uio_resid;
    count = count & ~(DIRBLKSIZ - 1);
    lost  = (int)uio->uio_resid - count;
    if (count < DIRBLKSIZ)
        return (EINVAL);
    if ((uio->uio_offset & (off_t)(DIRBLKSIZ - 1)) != 0L)
        return (EINVAL);

    uio->uio_resid        = (unsigned short)count;
    uio->uio_iov->iov_len = (unsigned short)count;
    error = ufs_read(vp, uio, 0, cred);
    uio->uio_resid = uio->uio_resid + (unsigned short)lost;

    ip = VTOI(vp);
    if (ip->i_size - uio->uio_offset <= 0L)
        *eofflagp = 1;
    else
        *eofflagp = 0;
    return (error);
}


/* ufs_read -- fill the uio from the file, a block at a time.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:599-651.  The loop is spec_read's and Reno's:
 * each turn reads the block containing uio_offset, hands uiomove the run from
 * `on` to the end of that block, and goes round -- uiomove having advanced the
 * cursor, which is what makes the next turn address the next block.
 *
 * WHAT MAKES IT A FILE READ RATHER THAN A DEVICE READ is two lines: the block
 * number is LOGICAL (ufs_strategy resolves it), and the transfer is clamped to
 * i_size.  Without the clamp a read of the last block returns the whole block,
 * including whatever the tail of it happens to hold -- which on a filesystem
 * another implementation wrote is somebody else's deleted data.
 *
 * `diff` IS A long, WHERE RENO DECLARES AN int, and that is not a style
 * choice: Reno's int is 32 bits and this one is 16.  `i_size - uio_offset` on
 * the probe's own /big is 307200, which as a 16-bit int is 4608 -- a clamp
 * that would silently truncate every read past the first 64 KB of a file to a
 * plausible smaller number.  This is the silent-truncation class the campaign
 * chose 2.11BSD over netbsd-0-9 to avoid, arriving anyway through an upstream
 * declaration that is correct upstream.
 *
 * THE resid CLAMP IS SPELLED UNSIGNED for the same family of reason.
 * uio_resid is an `unsigned short` here (uio.h explains why), so spec_read's
 * `if (n > (int)uio->uio_resid)` reads a resid above 32767 as NEGATIVE and
 * clamps n to it.  n is at most FS_BLKSIZE, so comparing in unsigned is both
 * correct and free.  spec_read has the same line and the same latent defect;
 * filed rather than fixed in passing, because its own probe should be the
 * thing that goes red.
 *
 * READ-AHEAD IS ABSENT.  Reno issues `breada` when v_lastr says the access is
 * sequential.  bio_strategy is SYNCHRONOUS by design -- vfs_bio.c's header
 * turns that into the invariant that no sleep in this filesystem is a disk
 * wait -- so a read-ahead would be a second blocking transfer rather than an
 * overlapped one: strictly slower, and it would break the invariant to get
 * there.  v_lastr is not maintained for the same reason.
 *
 * b_resid IS ALWAYS ZERO and the clamp on it is inert, exactly as spec_read
 * records: every assignment to it in vfs_bio.c is `= 0`, because the block
 * layer either completes a block or fails the whole request.  It is carried
 * anyway, because the day a short read becomes possible is the day its absence
 * silently truncates every transfer that hits one.
 */
int
ufs_read(vp, uio, ioflag, cred)
struct vnode *vp;
struct uio   *uio;
int           ioflag;
char         *cred;
{
    struct inode *ip;
    struct buf   *bp;
    daddr_t       lbn;
    off_t         diff;
    int           on;
    int           n;
    int           type;
    int           error;

    ip = VTOI(vp);
    if (uio->uio_rw != UIO_READ)
        kc_panic("ufs_read mode");
    /* Reno's three, and the list is the point: a VBLK or VCHR inode reaches
     * spec_read through its own vector, and anything else is a caller that has
     * lost track of what it holds. */
    type = (int)(ip->i_mode & IFMT);
    if (type != IFDIR && type != IFREG && type != IFLNK)
        kc_panic("ufs_read type");
    if (uio->uio_resid == 0)
        return (0);
    if (uio->uio_offset < 0)
        return (EINVAL);

    ip->i_flag |= IACC;
    error = 0;
    do {
        lbn = lblkno(uio->uio_offset);
        on  = (int)blkoff(uio->uio_offset);
        n   = FS_BLKSIZE - on;
        if ((unsigned short)n > uio->uio_resid)
            n = (int)uio->uio_resid;
        diff = ip->i_size - uio->uio_offset;
        if (diff <= 0L)
            return (0);
        if (diff < (off_t)n)
            n = (int)diff;
        error = bread(vp, lbn, &bp);
        /* bread sets *bpp BEFORE it can fail (it comes from getblk, which
         * blocks rather than failing), so the buffer is ours to release on the
         * error path too. */
        if (error) {
            brelse(bp);
            return (error);
        }
        if (n > FS_BLKSIZE - (int)bp->b_resid)
            n = FS_BLKSIZE - (int)bp->b_resid;
        error = uiomove(&bp->b_addr[on], n, uio);
        brelse(bp);
    } while (error == 0 && uio->uio_resid > 0 && n != 0);
    return (error);
}

/* ufs_write -- the other half of a file.  UFS 1.12a.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:658-746, with 2.11BSD's `writei`
 * (usr/sys/sys/ufs_rdwri.c) for the buffer decision, which is the one place
 * the two differ in a way this format cares about.
 *
 * IT IS ufs_read WITH THE ARROWS REVERSED, and the differences from that
 * function are exactly the interesting part:
 *
 *   A HOLE IS FILLED RATHER THAN READ.  ufs_read stops at i_size and treats a
 *   zero address as zeroes; here a zero address means allocate, which is what
 *   ufs_bmapx's B_WRITE arm does.  So the write path is where a file gets
 *   bigger, and it is the only place in this port that takes a block off the
 *   free list for a FILE (the allocator itself has been there since 1.10b).
 *
 *   THE BUFFER IS NOT ALWAYS READ FIRST.  A write covering a whole block has
 *   nothing to preserve, so it takes the buffer with getblk and never touches
 *   the platter for it -- 2.11BSD's `if (n == bsize) bp = getblk(...) else bp =
 *   bread(...)`.  A PARTIAL write into an EXISTING block must bread, or the
 *   bytes it is not writing come back as whatever the buffer last held.  And a
 *   partial write into a block that was a hole a moment ago must do NEITHER:
 *   there is nothing meaningful on the platter for it, and the free list hands
 *   out blocks with the previous owner's bytes still in them.  That is the
 *   third case, and it is why ufs_bmapx reports freshness.
 *
 *   b_blkno IS SET FROM THE MAPPING WE JUST DID, which is Reno's `bp->b_blkno =
 *   fsbtodb(fs, newb)` in balloc and is load-bearing rather than an
 *   optimisation.  A cached buffer for a block that WAS a hole carries
 *   b_blkno == -1 from ufs_strategy's hole arm; that is not equal to b_lblkno,
 *   so strategy would not re-map it, would take the hole arm again, and would
 *   call biodone without performing any I/O.  The write would be accepted,
 *   reported successful, and never reach the disk.  Read a hole, then write it,
 *   and that is the sequence.
 *
 * IT USED TO WRITE THE INODE BACK ON EVERY CALL.  That was 1.12a's stated
 * temporary divergence and 1.12b retired it; the paragraph is kept because the
 * reasoning is what a reader will want if the question comes back.  Reno marks IUPD|ICHG and
 * leaves the write-back to iupdat from close, sync or inactive; 2.11BSD's iput
 * does it when the last reference goes.  This port has none of those paths yet
 * -- `close` and `inactive` are still ufs_nullop, and iput is a bare vrele.  So
 * an inode left dirty here never reaches the platter at all, and the volume
 * ends up with blocks that are off the free list and owned by an on-disk inode
 * that still says size zero: exactly what fsck calls unreferenced, and exactly
 * what the 1.9 oracle would report on a volume this increment wrote.
 *
 * Adding IUPDAT to iput would be upstream's answer and is deliberately NOT
 * taken here: ufs_read sets IACC on every read, so an iput that flushes would
 * make every READ of a mounted volume write an inode back.  That is correct
 * Unix behaviour and it is not this increment's to introduce -- it would mutate
 * the scratch volume under every read-path probe case that exists today.
 * 1.12b's ufs_inactive is where the write-back belongs, and this line comes out
 * when it lands.
 *
 * WHAT IS ABSENT AND WHY, so it is not rediscovered as a bug:
 *
 *   NO RLIMIT_FSIZE CHECK.  Reno raises SIGXFSZ past the process's file-size
 *   limit.  `u_rlimit` exists in this kernel (include/kernel.s, UFS 1.2) but
 *   kernel C has no u-area to reach it through -- vfs_file.c's header explains
 *   the same absence for u_ofile.  It belongs with the syscall layer that can
 *   see the process.
 *

 *   NO munhash LOOP.  Reno walks the block it just wrote calling
 *   `munhash(ip->i_devvp, ...)` once per CLBYTES, dropping the VM system's
 *   page-cache mapping of that device block so a later fault cannot serve the
 *   stale page.  FGX has no VM and no page cache -- there is no second cache of
 *   a device block to invalidate -- so the loop has no counterpart here rather
 *   than being deferred.  Named because a reader diffing against Reno will find
 *   it missing and should not have to work out which kind of gap it is.
 *
 *   NO IO_UNIT ROLLBACK.  Reno undoes a partial failed write with itrunc; that
 *   is 1.12b.  Until then a write that fails halfway leaves the bytes it did
 *   manage, which is what a filesystem without rollback does and is stated
 *   here rather than left to be found.
 */
int
ufs_write(vp, uio, ioflag, cred)
struct vnode *vp;
struct uio   *uio;
int           ioflag;
char         *cred;
{
    struct inode *ip;
    struct buf   *bp;
    daddr_t       lbn;
    daddr_t       bn;
    int           on;
    int           n;
    int           fresh;
    int           type;
    int           error;
    int           werror;
    int           notroot;

    ip = VTOI(vp);
    if (uio->uio_rw != UIO_WRITE)
        kc_panic("ufs_write mode");
    /* ufs_read's three, and for the same reason: a VBLK or VCHR inode reaches
     * spec_write through its own vector, and anything else is a caller that
     * has lost track of what it holds.  Reno additionally insists a directory
     * write be IO_SYNC; that arm arrives with direnter in 1.12c, and until
     * something can create one there is no unsynchronised directory write to
     * refuse. */
    type = (int)(ip->i_mode & IFMT);
    if (type != IFDIR && type != IFREG && type != IFLNK)
        kc_panic("ufs_write type");

    /* IO_APPEND IS VREG-ONLY UPSTREAM, and Reno's switch is where it says so:
     * the `case VREG:` arm applies it and falls through to `case VLNK:`, which
     * does not.  A symlink is written once and whole by ufs_symlink, and a
     * directory is written by direnter at a slot it computed -- appending to
     * either would be a caller that has lost track of what it holds. */
    if ((ioflag & IO_APPEND) && type == IFREG)
        uio->uio_offset = ip->i_size;
    if (uio->uio_offset < 0)
        return (EINVAL);
    if (uio->uio_resid == 0)
        return (0);

    error = 0;
    n     = 0;
    notroot = (kc_curuid() != 0);

    do {
        lbn = lblkno(uio->uio_offset);
        on  = (int)blkoff(uio->uio_offset);
        n   = FS_BLKSIZE - on;
        if ((unsigned short)n > uio->uio_resid)
            n = (int)uio->uio_resid;

        error = ufs_bmapx(ip->i_devvp, (daddr_t *)0, lbn, B_WRITE, ip,
                          &bn, &fresh);
        if (error)
            break;

        if (n == FS_BLKSIZE || fresh) {
            bp = getblk(vp, lbn);
            if (fresh && n != FS_BLKSIZE)
                clrbuf(bp);
        } else {
            error = bread(vp, lbn, &bp);
            if (error) {
                brelse(bp);
                break;
            }
        }
        bp->b_blkno = bn;               /* see the head of this function */

        /* GROW BEFORE THE COPY, which is Reno's order.  uiomove can fail
         * partway and leave the file larger than what was successfully
         * written; that is what IO_UNIT and itrunc are for upstream, and 1.12b
         * brings them. */
        if (uio->uio_offset + (off_t)n > ip->i_size)
            ip->i_size = uio->uio_offset + (off_t)n;

        /* CLAMP TO WHAT THE BUFFER ACTUALLY HOLDS.  Reno's `n = MIN(n, size -
         * bp->b_resid)`, and it is INERT here for the reason ufs_read states
         * about its own copy of this line: every assignment to b_resid in
         * vfs_bio.c is `= 0`, because the block layer either completes a block
         * or fails the whole request.  Carried anyway, and carried in BOTH
         * directions, because the day a short transfer becomes possible is the
         * day its absence silently writes past what the buffer holds -- and a
         * clamp present on the read path and missing on the write path is the
         * asymmetry that would make that hard to see. */
        if (n > FS_BLKSIZE - (int)bp->b_resid)
            n = FS_BLKSIZE - (int)bp->b_resid;

        error = uiomove(&bp->b_addr[on], n, uio);
        ip->i_flag |= IUPD | ICHG;
        /* WRITING A FILE DROPS ITS PRIVILEGE.  Reno ufs_vnops.c:736-738 and
         * 2.11BSD usr/sys/sys/sys_inode.c:300-302, in the loop and not after
         * it, so a write that fails part-way has still cleared the bits for
         * the bytes it did land.  Without this, a caller who may write a
         * set-user-ID binary may put its own instructions inside one, which is
         * the whole of the privilege.  Root is exempt, as upstream has it, or
         * no setuid binary could ever be installed.
         *
         * 2.11BSD TESTS THE REAL uid HERE where Reno tests the effective one,
         * and the difference is real: a setuid-root program writing its own
         * binary clears the bits under 2.11BSD and keeps them under Reno.
         * Reno's is taken, because that is the tree this VFS is ported from
         * and cr_uid is the id every other check in this file uses.
         *
         * THE ID IS READ ONCE, ABOVE THE LOOP, where upstream reads cr_uid
         * inside it: cr_uid is a field of a structure it already holds, while
         * kc_curuid is a gateway call into bank 0 and this loop runs once per
         * block.  The caller cannot change identity part-way through its own
         * write, so the answer is the same either way. */
        if (notroot)
            ip->i_mode &= ~(ISUID | ISGID);

        /* THE BUFFER GOES OUT EVEN ON A uiomove ERROR.  Its block is already
         * threaded into the inode, so releasing it unwritten would leave a
         * block the file owns holding the previous owner's bytes -- worse than
         * the partial copy this preserves.  bwrite releases it either way. */
        werror = bwrite(bp);
        if (error == 0)
            error = werror;
    } while (error == 0 && uio->uio_resid > 0 && n != 0);

    /* THE INODE IS LEFT DIRTY, which is upstream's arrangement and is new at
     * 1.12b.  1.12a wrote it back on every call because nothing else in the
     * tree would -- close and inactive were both ufs_nullop -- and said in as
     * many words that the line came out when ufs_inactive landed.  It has.  A
     * write now marks IUPD|ICHG and the write-back happens at the last vrele,
     * or here and now if the caller asked for IO_SYNC, which is Reno's
     * `if (!error && (ioflag & IO_SYNC)) iupdat(...)`. */
    if (error == 0 && (ioflag & IO_SYNC)) {
        werror = iupdat(ip, 1);
        if (error == 0)
            error = werror;
    }
    return (error);
}


/* ufs_fsync -- everything this file has is on the platter when this returns.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:791-803.
 *
 * vflushbuf IS ABSENT AND THAT IS NOT A GAP.  Reno's line pushes the vnode's
 * dirty buffer list out; this port has no dirty buffer list to push, because
 * ufs_write bwrites every buffer it fills before it returns and ufs_bmapx does
 * the same for every indirect block it creates.  vfs_bio.c's header already
 * makes synchronous I/O the invariant the rest of the filesystem is written
 * against.  A delayed write has since arrived, and it did not change this:
 * spec_write's partial-block arm is the one bdwrite in the tree and it dirties
 * a DEVICE vnode, never a file's, so there is still nothing on a UFS vnode's
 * dirty list for this function to push.  What that delayed write DID need is
 * a flush in sync(2), which vfs_syscalls.c's vfs_sync now makes
 * (apple/fgx#398).
 *
 * fflags & FWRITE SETS ICHG upstream, because fsync(2) on a descriptor opened
 * for writing is a change to the file even if nothing was written.  FWRITE is
 * file.h's, and no caller here passes it yet; the arm is carried so the flag
 * has a reader when 1.7's syscall layer starts supplying one.
 */
int
ufs_fsync(vp, fflags, cred, waitfor)
struct vnode *vp;
int           fflags;
char         *cred;
int           waitfor;
{
    struct inode *ip;

    ip = VTOI(vp);
    if (fflags & FWRITE)
        ip->i_flag |= ICHG;
    return (iupdat(ip, waitfor));
}


/* ufs_readlink -- what a symbolic link points at.  UFS 1.12a.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:1389, which is one line: `return (ufs_read(vp,
 * uiop, 0, cred))`.  IT IS NOT A SHORTCUT.  A symlink's target IS the file's
 * contents on this format -- 2.11BSD stores it in the data blocks like any
 * other file, with i_size the length of the string and no NUL -- so reading
 * the link and reading the file are the same operation, and ufs_read's own
 * type check has admitted IFLNK since 1.11b for exactly this.
 *
 * (Reno's FFS has fast symlinks, which live in the inode's address array when
 * they fit, and its readlink is still this line because `ufs_read` handles
 * both.  2.11BSD has no fast symlinks, so there is only the one case here.)
 *
 * THE OTHER TWO THIRDS OF SYMLINKS WERE NAMED HERE AS GAPS AND ARE BOTH
 * CLOSED.  The text that stood here said ufs_symlink "needs maknode and
 * direnter, which are 1.12c's" and that "FGX's vfs_lookup.c has the flags and
 * ni_loopcnt and not the arm" -- true when written, and left standing after
 * 1.12c landed both.  ufs_symlink is below at :1096 and is a REAL entry in the
 * vnodeops table (:1961); namei's follow arm is `nexpand' (vfs_lookup.c:366)
 * with Reno's two-clause VLNK condition at :831 and ELOOP at MAXSYMLINKS.
 *
 * WHICH MADE THIS NOTE ACTIVELY EXPENSIVE, not merely out of date: it is what
 * a reader consults to learn whether a namei caller needs FOLLOW, and three
 * callers were written without it on its authority (apple/fgx#294's sweep --
 * root_stat, vfs_chdir, vfs_listdir).  A "this tree does not X" line outlives
 * the increment that made it true unless something deletes it.
 */
int
ufs_readlink(vp, uiop, cred)
struct vnode *vp;
struct uio   *uiop;
char         *cred;
{
    return (ufs_read(vp, uiop, 0, cred));
}


/* ufs_setattr -- the writable half of stat(2).  UFS 1.12b.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c:404.  Reno's function is mostly PERMISSION work
 * -- chown1, chmod1, suser checks on the times and the flags -- and this port
 * has no credential to check any of it against (file.h: f_cred is always 0).
 * So what lands here is the SIZE arm plus the timestamps, and the rest is
 * refused rather than silently ignored, which is the difference between a gap
 * and a lie.
 *
 * THE SIZE ARM IS THE ONE 1.12b EXISTS FOR: it is ftruncate(2) reaching the
 * filesystem, and it is upstream's three lines -- refuse a directory, then
 * itrunc.  EISDIR rather than EINVAL is Reno's answer and is the one POSIX
 * names.
 *
 * REFUSING THE UNSETTABLE FIELDS IS UPSTREAM'S OPENING and is kept verbatim in
 * spirit: va_type, va_nlink, va_fsid, va_fileid, va_blocksize and va_rdev are
 * not things a caller may set, and a filesystem that ignored them would let a
 * caller believe it had.  This tree's vattr has no va_bytes or va_gen (vnode.h
 * says why), so those two are absent from the list rather than dropped from it.
 *
 * THE OWNER AND MODE ARMS ARE ufs_chown1 AND ufs_chmod1, above, which are
 * Reno's two functions kept as two functions -- gates, narrowings and set-id
 * clearings included.  They were inlined here while nothing evaluated a
 * credential; their own header says why that stopped being true.
 *
 * THE ORDER IS UPSTREAM'S AND IT IS NOT ARBITRARY: chown clears the set-id
 * bits for a non-root caller, so a combined setattr that changed both would
 * have its new mode cleared if the mode arm ran first.
 *
 * va_flags -- the user flags word -- IS still refused.  Unlike the mode and
 * the owner it has no root path worth having: nothing in this tree sets or
 * reads i_flags, and ls(1) prints them only under -o.
 */
/* ufs_chmod1 / ufs_chown1 -- 4.3BSD-Reno's chmod1 (ufs_vnops.c:466) and
 * chown1 (ufs_vnops.c:495), each as its own function because each is its own
 * function upstream and the shape is what makes them diffable against it.
 *
 * THEY WERE INLINED IN ufs_setattr AND THE REASON EXPIRED.  The note there
 * read "Reno's function is its credential test, its quota bookkeeping and four
 * assignments, and only the assignments survive a kernel with neither" -- true
 * while nothing evaluated a credential, and false the moment exec began
 * honouring a set-user-ID bit (apple/fgx#416), because then the credential
 * test is most of the point.  What is still absent is the quota half, and that
 * is absent because there are no quotas.
 *
 * THE IDS COME FROM kc_curuid/kc_curgid, not from a passed ucred.  That is
 * ufs_access's divergence and its header carries the reasoning; upstream's
 * `suser(cred, &u.u_acflag)' also sets an accounting flag this kernel has no
 * field for, and `groupmember()' walks a list where FGX has one gid, so both
 * collapse to a compare.
 */
static int
ufs_chmod1(vp, mode)
struct vnode *vp;
int           mode;
{
    register struct inode *ip = VTOI(vp);
    int cuid;

    cuid = kc_curuid();
    /* Reno :473-474 -- `if (cred->cr_uid != ip->i_uid && (error =
     * suser(cred, &u.u_acflag))) return (error);' */
    if (cuid != 0 && (uid_t)cuid != ip->i_uid)
        return (EPERM);
    ip->i_mode &= ~07777;
    /* Reno :477-482.  A non-root caller may not make a non-directory sticky,
     * and may not set ISGID on a group it does not belong to.  ISUID needs no
     * such line: chmod cannot give a file away, so the bit can only ever name
     * the caller, who already has those privileges. */
    if (cuid != 0) {
        if (vp->v_type != VDIR)
            mode &= ~ISVTX;
        if (ip->i_gid != (gid_t)kc_curgid())
            mode &= ~ISGID;
    }
    ip->i_mode |= (mode & 07777);
    ip->i_flag |= ICHG;
    /* NO xrele.  Upstream drops a shared text image whose sticky bit has just
     * been cleared; this kernel has no text table to drop from. */
    return (0);
}

static int
ufs_chown1(vp, uid, gid)
struct vnode *vp;
uid_t         uid;
gid_t         gid;
{
    register struct inode *ip = VTOI(vp);
    uid_t ouid;
    gid_t ogid;
    int   cuid;

    /* UNSET MEANS "LEAVE IT", which is upstream's own opening: it fills the
     * missing half from the inode rather than treating VNOVAL as a value, so
     * `chown f -1 20' changes the group alone. */
    if (uid == (uid_t)VA_UNSET)
        uid = ip->i_uid;
    if (gid == (gid_t)VA_UNSET)
        gid = ip->i_gid;
    cuid = kc_curuid();

    /* Reno :515-522, and its comment is the rule: "If we don't own the file,
     * are trying to change the owner of the file, or are not a member of the
     * target group, the caller must be superuser or the call fails." */
    if (cuid != 0 &&
        ((uid_t)cuid != ip->i_uid || uid != ip->i_uid ||
         gid != (gid_t)kc_curgid()))
        return (EPERM);

    ouid = ip->i_uid;
    ogid = ip->i_gid;
    ip->i_uid = uid;
    ip->i_gid = gid;
    if (ouid != uid || ogid != gid)
        ip->i_flag |= ICHG;
    /* Reno :589-592.  GIVING A FILE AWAY DROPS ITS PRIVILEGE, and with exec
     * honouring the bit this is load-bearing rather than tidy: without it any
     * caller could chown a file it owns to root and leave a set-user-ID bit
     * pointing at root.  The `cr_uid != 0' on both lines is why root can still
     * install a setuid binary with chown. */
    if (ouid != uid && cuid != 0)
        ip->i_mode &= ~ISUID;
    if (ogid != gid && cuid != 0)
        ip->i_mode &= ~ISGID;
    return (0);
}

int
ufs_setattr(vp, vap, cred)
struct vnode *vp;
struct vattr *vap;
char         *cred;
{
    struct inode *ip;
    int           error;

    ip = VTOI(vp);

    /* Unsettable.  Reno returns EINVAL for the lot. */
    if (vap->va_type != VNON)
        return (EINVAL);
    if (vap->va_nlink != VA_UNSET || vap->va_fsid != VA_UNSET ||
        vap->va_fileid != VA_UNSET || vap->va_blocksize != VA_UNSET ||
        vap->va_rdev != (dev_t)VA_UNSET)
        return (EINVAL);

    if (vap->va_flags != (unsigned short)VA_UNSET)
        return (EPERM);

    /* chown1, inlined: Reno's function is its credential test, its quota
     * bookkeeping and four assignments, and only the assignments survive a
     * kernel with neither.  UNSET MEANS "LEAVE IT", which is why upstream
     * fills the missing half from the inode rather than treating VNOVAL as a
     * value -- `chown f -1 20' changes the group alone.
     *
     * BEFORE THE MODE ARM, as upstream orders them, and it is not arbitrary:
     * chown clears the set-id bits for a non-root caller, so a combined
     * setattr that changed both would have its new mode cleared if the order
     * were reversed. */
    if (vap->va_uid != (uid_t)VA_UNSET || vap->va_gid != (gid_t)VA_UNSET) {
        error = ufs_chown1(vp, vap->va_uid, vap->va_gid);
        if (error)
            return (error);
    }

    if (vap->va_size != (off_t)VA_UNSET) {
        if (vp->v_type == VDIR)
            return (EISDIR);
        error = ufs_itrunc(ip, vap->va_size, 0, (long *)0);
        if (error)
            return (error);
    }

    /* utimes(2).  Upstream gates this on the caller owning the file or being
     * root; with no credential the gate cannot be evaluated, so the STAMPS are
     * honoured and the permission question is deferred with everything else at
     * 2.6.  Reno passes the requested times through to iupdat; ufs_itimes owns
     * the stamps here and reads the clock itself, so a REQUESTED time is
     * written into the field directly and the flag left clear -- otherwise
     * ufs_itimes would overwrite it with now. */
    if (vap->va_atime != (time_t)VA_UNSET) {
        ip->i_atime = vap->va_atime;
        ip->i_flag &= ~IACC;
        ip->i_flag |= IMOD;
    }
    if (vap->va_mtime != (time_t)VA_UNSET) {
        ip->i_mtime = vap->va_mtime;
        ip->i_flag &= ~IUPD;
        ip->i_flag |= IMOD;
    }
    if (vap->va_atime != (time_t)VA_UNSET ||
        vap->va_mtime != (time_t)VA_UNSET) {
        ip->i_flag |= ICHG;
        error = iupdat(ip, 1);
        if (error)
            return (error);
    }

    /* chmod1, inlined.  `ip->i_mode &= ~07777' then `|= mode & 07777' is
     * upstream's pair and the mask is what keeps IFMT: a mode written whole
     * would turn a regular file into whatever the caller's four digits named.
     *
     * NO xrele.  Upstream drops a shared text image whose sticky bit has just
     * been cleared; this kernel has no text table to drop from. */
    if (vap->va_mode != (unsigned short)VA_UNSET) {
        error = ufs_chmod1(vp, (int)vap->va_mode);
        if (error)
            return (error);
    }

    return (0);
}


/* ufs_inactive -- the last reference is gone; do what a last close implies.
 * UFS 1.12b.
 *
 * 4.3BSD-Reno ufs/ufs_inode.c's ufs_inactive.  vrele calls it through the
 * vector at every drop to zero, so wiring this makes it live on every path
 * that lets go of a UFS vnode -- which is what makes the two things below
 * happen at all.
 *
 * THIS IS WHERE AN UNLINKED OPEN FILE IS FINALLY RELEASED, which is the whole
 * point and the shape apple/fgx#66 describes on the ProDOS side: a file whose
 * directory entry is gone but whose descriptor is still open keeps its blocks
 * until the last close, and THEN gives them back.  i_nlink reaching zero is
 * the signal; the blocks go through itrunc-to-zero and the inode number goes
 * back on the free list.  Nothing can unlink yet -- that is 1.12c's dirremove
 * -- so the arm is reachable today only by a caller that zeroes i_nlink
 * itself, which is what the probe does.  It is written now because 1.12c would
 * otherwise land the unlink and the leak together.
 *
 * AND IT IS WHERE THE INODE REACHES THE PLATTER, which retires a divergence
 * 1.12a introduced deliberately: ufs_write wrote the inode back on EVERY call
 * because nothing else in the tree would, and its comment named this function
 * as where that line comes out.  It is out.  A write now marks the inode dirty
 * and the write-back happens here, at the last release, which is both
 * upstreams' arrangement -- and the reason an explicit fsync(2) exists.
 *
 * THE ORDER IS RENO'S: truncate, then clear the mode, then free the number.
 * Freeing first would put a number on the free list that still names blocks.
 *
 * vgone IS CALLED FOR THE REASON UPSTREAM CALLS IT, and it is not tidiness: an
 * inode left on the hash with i_mode == 0 is what ufs_ihashget returns the
 * moment ialloc hands that number out again, so the next file to reuse it
 * would be handed the dead in-core copy instead of reading its own dinode.
 * That is the failure mode apple/fgx#175 already cost this campaign once, from
 * the other direction.  It needed a new module-ABI entry (VFSCORE_Vgone).
 *
 * THE LOCK IS TAKEN DIRECTLY AND NOT THROUGH VOP_LOCK, and that is the one
 * thing in this function that is not upstream's spelling.  Reno writes
 * `ILOCK(ip)`, a macro on ilock; VOP_LOCK would be the natural translation
 * here and is WRONG, because of where this function is called from.  vclean
 * swaps v_op to dead_vnodeops BEFORE it calls inactive -- deliberately, so
 * that a new call arriving during the teardown lands on the dead vector
 * instead of re-entering a filesystem that is already tearing this vnode down
 * -- and it calls this one through the SAVED vector.  So `VOP_LOCK(vp)` from
 * in here dispatches to dead_lock, whose chkvnlock waits for VXLOCK to clear,
 * which is the flag vclean is holding while it waits for this function.  A
 * hang, not a panic.  Calling ufs_lock by name is what upstream's macro does
 * and is the only form that is correct from both callers.
 *
 * WHAT IS ABSENT: the quota release (a campaign non-goal) and i_rdev (there
 * are no on-disk device inodes until 1.13, and vnode.h says why va_rdev
 * reports NODEV).
 */
int
ufs_inactive(vp)
struct vnode *vp;
{
    struct inode    *ip;
    struct ufsmount *ump;
    int              error;
    int              uerror;

    ip = VTOI(vp);
    error = 0;

    /* A dead inode: nothing to write back, and it must not stay on the hash.
     * Reno's "get rid of inodes related to stale file handles". */
    if (ip->i_mode == 0) {
        if ((vp->v_flag & VXLOCK) == 0)
            vgone(vp);
        return (0);
    }

    /* AFTER the stale-handle arm above and not before it, which is Reno's
     * order: that arm calls vgone, and vgone's vclean takes this same lock. */
    ufs_lock(vp);

    if (ip->i_nlink <= 0) {
        ump = ITOUMP(ip);
        error = ufs_itrunc(ip, (off_t)0, 0, (long *)0);
        ip->i_mode = 0;
        ip->i_flag |= IUPD | ICHG;
        ufs_ifree(&ump->um_sb, ip->i_number);
    }

    /* Reno's IUPDAT: write it back if any of the four dirty flags is set.
     * iupdat makes that test itself, so the call is unconditional here and the
     * guard lives in one place. */
    uerror = iupdat(ip, 0);
    if (error == 0)
        error = uerror;

    /* UNLOCK BEFORE THE WIPE, not after.  `i_flag = 0` clears ILOCKED among
     * everything else, so doing it first would drop the lock without waking
     * anyone waiting on IWANT -- and they would sleep on a channel with no
     * waker left.  Reno's order, for Reno's reason. */
    ufs_unlock(vp);
    ip->i_flag = 0;

    /* Done with it entirely: let the pool have it back now rather than at the
     * next recycle. */
    if (vp->v_usecount == 0 && ip->i_mode == 0)
        vgone(vp);
    return (error);
}


/* ufs_maknode -- allocate an inode, fill it in, and give it a name.  1.12c.
 *
 * 4.3BSD-Reno ufs/ufs_vnops.c's maknode.  Every path that CREATES something --
 * create, mkdir, symlink, and mknod at 1.13 -- goes through here, which is why
 * it is one function rather than three similar ones.
 *
 * THE ORDER IS A CRASH-SAFETY ARGUMENT AND UPSTREAM SAYS SO IN ONE LINE:
 * "Make sure inode goes to disk before directory entry."  An entry naming an
 * inode the platter does not yet describe is a name pointing at whatever that
 * i-list slot last held; an inode with no entry naming it is merely lost, and
 * fsck reclaims it.  Between the two failures there is no contest, and it
 * costs one synchronous write to choose.
 *
 * THE FAILURE PATH ONLY WORKS BECAUSE 1.12b LANDED.  Upstream's `bad:` arm
 * sets i_nlink to 0 and iputs, trusting inactive to notice and free both the
 * blocks and the number.  Until ufs_inactive existed here that would have
 * leaked an inode on every failed create; now it is exactly what happens, and
 * this is the first caller to depend on it.
 *
 * WHAT IS ABSENT: ialloc's inode PREFERENCE (Reno passes dirpref() for a
 * directory and the parent's number otherwise, to keep a directory's inodes
 * near it -- FGX's ufs_ialloc takes no preference at all, because a 2.11BSD
 * i-list has no cylinder groups to be near); the uid and gid, which come from
 * a credential that does not exist until 2.6 and are left 0; and the ISGID
 * clearing, which is a permission decision with nothing to decide it.
 */
static int
ufs_maknode(mode, ndp, ipp)
int               mode;
struct nameidata *ndp;
struct inode    **ipp;
{
    struct inode    *pdir;
    struct inode    *ip;
    struct ufsmount *ump;
    ino_t            ino;
    int              error;

    *ipp = (struct inode *)0;
    pdir = VTOI(ndp->ni_dvp);
    ump  = ITOUMP(pdir);

    if ((mode & IFMT) == 0)
        mode |= IFREG;

    error = ufs_ialloc(pdir->i_devvp, &ump->um_sb, &ino);
    if (error)
        return (error);

    /* THE NUMBER IS NOT THE INODE.  ufs_ialloc hands back a free i-list slot;
     * iget is what brings it into core, and it reads the dinode -- which for a
     * free slot is zeroes, so the vnode arrives VNON and every field below is
     * being set for the first time rather than overwritten. */
    error = iget(ndp->ni_dvp->v_mount, ino, &ip);
    if (error) {
        ufs_ifree(&ump->um_sb, ino);
        return (error);
    }
    ip->i_mode  = (unsigned short)mode;
    ip->i_nlink = 1;
    /* THE OWNER IS THE CREATOR AND THE GROUP IS THE PARENT'S.  4.3BSD-Reno
     * ufs/ufs_vnops.c:1679 (maknode):
     *
     *      ip->i_uid = ndp->ni_cred->cr_uid;
     *      ip->i_gid = pdir->i_gid;
     *
     * TWO DIFFERENT SOURCES, and that asymmetry is the rule rather than an
     * accident: a file belongs to whoever made it, and it joins the group of
     * the directory it was made in -- which is how a shared directory stays
     * shared without every writer having to remember to chgrp.
     *
     * `kc_curuid' STANDS IN FOR THE CREDENTIAL, which is the divergence
     * ufs_access states at the foot of this file: there is no `struct ucred'
     * here (file.h's f_cred is always 0), so the effective ids are read at the
     * point they are needed instead of being carried down from namei.
     *
     * BOTH WERE 0 UNTIL apple/fgx#413 -- every file on the volume belonged to
     * root whoever created it, which is invisible on a machine with one user
     * and makes a non-privileged account useless the moment there is one: the
     * `fgx' test user could write in its own home and did not own what it
     * wrote. */
    ip->i_uid   = (uid_t)kc_curuid();
    ip->i_gid   = pdir->i_gid;
    ip->i_size  = 0L;
    ip->i_flag |= IACC | IUPD | ICHG;
    ITOV(ip)->v_type = ufs_ifmttovt((unsigned short)mode);

    error = iupdat(ip, 1);
    if (error)
        goto bad;
    error = ufs_direnter(ip, ndp);
    if (error)
        goto bad;

    *ipp = ip;
    return (0);

bad:
    /* Upstream's arm: unname it and let inactive do the rest. */
    ip->i_nlink = 0;
    ip->i_flag |= ICHG;
    iput(ip);
    return (error);
}


/* ufs_create -- the VOP_CREATE slot.  4.3BSD-Reno ufs/ufs_vnops.c's ufs_create.
 *
 * It is maknode plus recording the result, which is all upstream's is.  The
 * mode arrives as a vattr because that is the shape VOP_CREATE takes from
 * open(2) with O_CREAT, and the TYPE bits come from va_type rather than from
 * va_mode -- MAKEIMODE upstream, spelled out here because a create with the
 * IFMT bits left in va_mode would make a directory out of an open(2).
 *
 * VSOCK ARRIVES HERE AND NOT THROUGH ufs_mknod, which is worth saying because
 * the reflex is to look for mknod(2).  Reno's unp_bind binds an AF_UNIX socket's
 * name with VOP_CREATE:
 *
 *      VATTR_NULL(&vattr);
 *      vattr.va_type = VSOCK;
 *      vattr.va_mode = 0777;
 *      if (error = VOP_CREATE(ndp, &vattr))
 *
 * so a socket node needs no mknod(2) and no on-disk format change -- the same
 * slot open(O_CREAT) already uses, and ufs_inode.c already maps IFSOCK to VSOCK.
 * Unlike ufs_mknod this KEEPS the vnode in ni_vp, which unp_bind needs: it hangs
 * the socket on it.
 */
int
ufs_create(ndp, vap)
struct nameidata *ndp;
struct vattr     *vap;
{
    struct inode *ip;
    int           mode;
    int           error;

    mode = (int)(vap->va_mode & 07777);
    if (vap->va_type == VDIR)
        mode |= IFDIR;
    else if (vap->va_type == VLNK)
        mode |= IFLNK;
    else if (vap->va_type == VSOCK)
        mode |= IFSOCK;
    else
        mode |= IFREG;

    error = ufs_maknode(mode, ndp, &ip);
    if (error)
        return (error);
    ndp->ni_vp = ITOV(ip);
    return (0);
}


/* ufs_link -- the VOP_LINK slot.  4.3BSD-Reno ufs/ufs_vnops.c:849-874.
 *
 * A SECOND NAME FOR ONE INODE, which is the operation that makes the link
 * COUNT mean something: everything 1.12b built around i_nlink reaching zero is
 * inert while every file has exactly one name.
 *
 * THE COUNT GOES UP BEFORE THE NAME EXISTS, and is put back if the name
 * cannot be made.  Upstream's order, and the reason is a crash rather than an
 * error return: an inode whose count is one too high leaks a file that fsck
 * can find and correct, where a name pointing at an inode whose count does not
 * include it is a file that vanishes the moment the OTHER name is removed.
 * The safe direction is the one that over-counts.
 *
 * TWO DIVERGENCES, both stated rather than left:
 *
 *   - Reno brackets the whole thing in ILOCK/IUNLOCK unless the target IS the
 *     directory.  There is no inode lock in this tree yet, so there is nothing
 *     to take -- see the note at the foot of the vnodeops table.
 *   - Reno's ceiling test is `i_nlink == LINK_MAX - 1`.  This one is `>=`,
 *     which is strictly safer and differs only for a count that upstream's
 *     test would already have walked past.
 */
int
ufs_link(vp, ndp)
struct vnode     *vp;
struct nameidata *ndp;
{
    struct inode *ip;
    int           error;

    ip = VTOI(vp);
    if ((int)ip->i_nlink >= LINK_MAX - 1)
        return (EMLINK);

    ip->i_nlink++;
    ip->i_flag |= ICHG;
    error = iupdat(ip, 1);
    if (error == 0)
        error = ufs_direnter(ip, ndp);
    if (error) {
        ip->i_nlink--;
        ip->i_flag |= ICHG;
    }
    return (error);
}


/* ufs_symlink -- the VOP_SYMLINK slot.  4.3BSD-Reno ufs/ufs_vnops.c:1342-1358.
 *
 * IT IS maknode PLUS A WRITE, and the write is the whole of the format: a
 * symlink's contents ARE the target path, its i_size is that path's length,
 * and there is no terminator on the volume.  ufs_readlink (1.12a) reads it
 * back through ufs_read for the same reason -- the two have been able to
 * agree since 1.12a, and this is the side that can now produce one.
 *
 * `strlen` DOES NOT EXIST HERE.  Kernel C links no libkern, which is why
 * ufs_dircopy and ufs_iencode open-code their loops too.
 *
 * Upstream passes IO_NODELOCKED, which says "the vnode is already locked" and
 * has no counterpart while there is no lock.  It is NOT translated to IO_SYNC:
 * that would be a different promise, and one upstream does not make here.
 */
int
ufs_symlink(ndp, vap, target)
struct nameidata *ndp;
struct vattr     *vap;
char             *target;
{
    struct inode *ip;
    struct uio    u;
    struct iovec  iov;
    int           len;
    int           error;

    error = ufs_maknode((int)(IFLNK | (vap->va_mode & 07777)), ndp, &ip);
    if (error)
        return (error);

    len = 0;
    while (target[len] != '\0')
        len++;

    iov.iov_base = target;
    iov.iov_len  = len;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = (unsigned short)len;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    error = ufs_write(ITOV(ip), &u, 0, (char *)0);
    iput(ip);
    return (error);
}


/* ufs_mkdir -- the VOP_MKDIR slot.  4.3BSD-Reno ufs/ufs_vnops.c:1168-1272.
 *
 * IT CANNOT USE maknode, and upstream says why in its own comment: the entry
 * in the PARENT must be made LAST, after "." and ".." are on the platter.  A
 * directory that is named before it has a "." is a directory the walk can
 * enter and cannot leave, and a crash in that window leaves one on the disk.
 * So mkdir simulates the front half of maknode -- ialloc, iget, fill in --
 * and calls direnter itself at the end.
 *
 * THE PARENT'S LINK COUNT GOES UP BEFORE THE ENTRY EXISTS, for the reason
 * ufs_link's does: over-counting is recoverable and under-counting is not.
 * The new directory's own count starts at TWO, which is "." and the name the
 * parent is about to carry -- neither of which exists yet either.
 *
 * "." AND ".." ARE BUILT BY HAND rather than from a `struct dirtemplate`.
 * Upstream's template is a struct whose layout depends on sizeof, and this
 * tree has a standing note (dir.h) about not trusting sizeof over a directory
 * record: `struct direct` declares d_name at MAXNAMLEN and no record on disk
 * is that long.  Two `struct direct` writes into a byte buffer is the same
 * bytes with nothing to get wrong.
 *
 * ".." OWNS THE REST OF THE BLOCK.  That is upstream's mastertemplate exactly
 * -- `{ 0, 12, 1, "." }, { 0, DIRBLKSIZ - 12, 2, ".." }` with its eight-byte
 * header -- and the reason is the scan: a directory's records must span it
 * with no gaps, so the last one absorbs the remainder.  Upstream's 12 is
 * DIRSIZ(1) for a Reno header; ours is 8.
 *
 * ONE ARM OF UPSTREAM'S IS UNREACHABLE HERE and is not carried: it panics when
 * DIRBLKSIZ exceeds the filesystem's fragment size, because it writes the
 * template with a single block's worth of I/O.  A block here is 1024 and
 * DIRBLKSIZ is 512, and neither is a mount-time variable.
 *
 * ITS RECOVERY IS SIMPLER THAN UPSTREAM'S, and that is a difference in the
 * CALLER's conventions rather than in the operation.  Reno drops the parent
 * before direnter and has to find it again with namei to undo the link count;
 * here direnter does not consume ni_dvp -- nothing in this tree's directory
 * layer releases it -- so the parent is still in hand and the undo is direct.
 */
static char mkdirtmpl[DIRSIZ(1) + DIRSIZ(2)];

int
ufs_mkdir(ndp, vap)
struct nameidata *ndp;
struct vattr     *vap;
{
    struct inode    *dp;
    struct inode    *ip;
    struct ufsmount *ump;
    struct direct   *e;
    struct uio       u;
    struct iovec     iov;
    char            *nm;
    ino_t            ino;
    int              dmode;
    int              i;
    int              error;

    dp    = VTOI(ndp->ni_dvp);
    ump   = ITOUMP(dp);
    dmode = (int)(vap->va_mode & 0777) | IFDIR;

    error = ufs_ialloc(dp->i_devvp, &ump->um_sb, &ino);
    if (error)
        return (error);
    error = iget(ndp->ni_dvp->v_mount, ino, &ip);
    if (error) {
        ufs_ifree(&ump->um_sb, ino);
        return (error);
    }
    ip->i_mode  = (unsigned short)dmode;
    ip->i_nlink = 2;
    /* THE OWNER IS THE CREATOR AND THE GROUP IS THE PARENT'S.  4.3BSD-Reno
     * ufs/ufs_vnops.c:1195 (ufs_mkdir):
     *
     *      ip->i_uid = ndp->ni_cred->cr_uid;
     *      ip->i_gid = dp->i_gid;
     *
     * TWO DIFFERENT SOURCES, and that asymmetry is the rule rather than an
     * accident: a file belongs to whoever made it, and it joins the group of
     * the directory it was made in -- which is how a shared directory stays
     * shared without every writer having to remember to chgrp.
     *
     * `kc_curuid' STANDS IN FOR THE CREDENTIAL, which is the divergence
     * ufs_access states at the foot of this file: there is no `struct ucred'
     * here (file.h's f_cred is always 0), so the effective ids are read at the
     * point they are needed instead of being carried down from namei.
     *
     * BOTH WERE 0 UNTIL apple/fgx#413 -- every file on the volume belonged to
     * root whoever created it, which is invisible on a machine with one user
     * and makes a non-privileged account useless the moment there is one: the
     * `fgx' test user could write in its own home and did not own what it
     * wrote. */
    ip->i_uid   = (uid_t)kc_curuid();
    ip->i_gid   = dp->i_gid;
    ip->i_size  = (off_t)0;
    ip->i_flag |= IACC | IUPD | ICHG;
    ITOV(ip)->v_type = VDIR;
    error = iupdat(ip, 1);
    if (error)
        goto bad;

    dp->i_nlink++;
    dp->i_flag |= ICHG;
    error = iupdat(dp, 1);
    if (error) {
        dp->i_nlink--;
        dp->i_flag |= ICHG;
        goto bad;
    }

    for (i = 0; i < DIRSIZ(1) + DIRSIZ(2); i++)
        mkdirtmpl[i] = (char)0;
    e = (struct direct *)&mkdirtmpl[0];
    e->d_ino    = ip->i_number;
    e->d_reclen = (unsigned short)DIRSIZ(1);
    e->d_namlen = 1;
    nm = &mkdirtmpl[0] + DIRHDRSIZ;
    nm[0] = '.';
    e = (struct direct *)&mkdirtmpl[DIRSIZ(1)];
    e->d_ino    = dp->i_number;
    e->d_reclen = (unsigned short)(DIRBLKSIZ - DIRSIZ(1));
    e->d_namlen = 2;
    nm = &mkdirtmpl[DIRSIZ(1)] + DIRHDRSIZ;
    nm[0] = '.';
    nm[1] = '.';

    iov.iov_base = mkdirtmpl;
    iov.iov_len  = DIRSIZ(1) + DIRSIZ(2);
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = (unsigned short)(DIRSIZ(1) + DIRSIZ(2));
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    error = ufs_write(ITOV(ip), &u, IO_SYNC, (char *)0);
    if (error) {
        dp->i_nlink--;
        dp->i_flag |= ICHG;
        goto bad;
    }

    /* THE SIZE IS THE WHOLE BLOCK, not the twenty bytes just written: ".."
     * spans the rest of it, and a scan walks to i_size.  The remainder is
     * zeroes, because a freshly allocated block arrives cleared. */
    ip->i_size  = (off_t)DIRBLKSIZ;
    ip->i_flag |= ICHG | IUPD;

    error = ufs_direnter(ip, ndp);
    if (error) {
        dp->i_nlink--;
        dp->i_flag |= ICHG;
        goto bad;
    }
    ndp->ni_vp = ITOV(ip);
    return (0);

bad:
    /* No explicit itrunc: a zero link count is what makes ufs_inactive give
     * the blocks and the number back, which is 1.12b's arm and upstream's
     * note here word for word. */
    ip->i_nlink = 0;
    ip->i_flag |= ICHG;
    iput(ip);
    return (error);
}


/* ufs_rmdir -- the VOP_RMDIR slot.  4.3BSD-Reno ufs/ufs_vnops.c:1279-1332.
 *
 * THE NAME GOES FIRST AND THE INODE SECOND, which upstream states as the
 * crash argument it is: a directory whose entry is gone but whose inode still
 * lives is reattached by fsck to lost+found, where an inode freed while its
 * name still points at it is a name pointing into a reallocated i-list slot.
 *
 * "rmdir ." IS ITS OWN ARM because the two references are to ONE vnode: an
 * iput of each would release twice what was acquired once.
 *
 * THE COUNT DROPS BY TWO, not one.  The name in the parent is one, and the
 * directory's own "." is the other -- and "." is being quashed along with
 * everything else, so nothing will ever remove it.  Any remaining links are
 * left for later, which is upstream's note and stays true here.
 *
 * cache_purge IS MADE TWICE, which is upstream's count: once on the parent
 * after the entry is removed, once on the directory itself after it is
 * truncated.  Both arrived with the wiring of the cache into ufs_lookup, and
 * without them this returns a vnode for a name that no longer exists.
 *
 * IT DOES NOT RELEASE THE DIRECTORY, AND UPSTREAM'S DOES.  This is the
 * divergence in THE WHOLE LAYER, stated here because rmdir is where it first
 * bites: in 4.3BSD-Reno every directory-modifying routine CONSUMES ni_dvp --
 * `direnter` ends with `iput(dp)` (ufs_lookup.c), `ufs_remove` ends with
 * `iput(dp)`, `ufs_rmdir` releases both, and `maknode`'s error arm has to set
 * `pdir = NULL` precisely because direnter already released it.  Nothing in
 * this tree does: ufs_direnter, ufs_dirremove, ufs_maknode, ufs_create and
 * ufs_remove all leave ni_dvp exactly as they found it, so THE CALLER OWNS IT
 * throughout.
 *
 * That is a coherent convention and the port keeps it, but it was never
 * written down, and a faithful transcription of upstream's rmdir into it
 * releases a reference the caller still holds.  The probe found that as
 * `vrele: zero usecount` -- one panic, at the first refusal, from an operation
 * that had done nothing wrong except obey the other tree's rules.
 *
 * So: ni_vp is released here, exactly once, on every path.  ni_dvp is not
 * touched.  The `rmdir .` arm releases ONE reference and not two, because both
 * of its names are for one vnode and only one of them was acquired by the
 * lookup this call is finishing.
 */
int
ufs_rmdir(ndp)
struct nameidata *ndp;
{
    struct inode *ip;
    struct inode *dp;
    int           error;

    ip = VTOI(ndp->ni_vp);
    dp = VTOI(ndp->ni_dvp);

    if (dp == ip) {
        vrele(ITOV(ip));        /* the lookup's reference, and only that */
        return (EINVAL);
    }

    /* TWO TESTS AND NOT ONE.  A link count of 2 says nobody else names this
     * directory; dirempty says it names nobody else.  Either alone lets a
     * populated directory through: a count of 2 is what a directory full of
     * FILES has, and an empty directory with a third link is one somebody
     * else can still reach. */
    if (ip->i_nlink != 2 || !ufs_dirempty(ip, dp->i_number)) {
        error = ENOTEMPTY;
        goto out;
    }

    error = ufs_dirremove(ndp);
    if (error)
        goto out;
    dp->i_nlink--;
    dp->i_flag |= ICHG;
    /* THE PARENT'S CACHED NAMES ARE NOW WRONG -- one of them is the directory
     * just unlinked.  Reno purges here, between the dirremove and the truncate
     * (ufs/ufs_vnops.c:1315), and the position matters: the entry has to stop
     * being answerable before anything can look it up again. */
    cache_purge(ITOV(dp));

    ip->i_nlink = (short)((int)ip->i_nlink - 2);
    error = ufs_itrunc(ip, (off_t)0, IO_SYNC, (long *)0);
    /* AND THE DIRECTORY'S OWN, which are "." and ".." and whatever was cached
     * BELOW it -- every one of them names a vnode reached through this one.
     * Reno's second purge, ufs/ufs_vnops.c:1331. */
    cache_purge(ITOV(ip));
out:
    iput(ip);
    return (error);
}


/* ufs_rename -- the VOP_RENAME slot.  4.3BSD-Reno ufs/ufs_vnops.c:901-1155.
 *
 * THE LARGEST FUNCTION IN THE INCREMENT, and upstream's header says why in
 * one sentence worth keeping: rename is unlink(new) + link(old,new) +
 * unlink(old), "but ``atomically''", and a full commit is not feasible, so
 * "best we can do is always guarantee the target exists".  Every ordering
 * below follows from that -- each step leaves a filesystem that fsck can
 * repair, and none leaves one where a name points at nothing.
 *
 * THE THREE STEPS ARE UPSTREAM'S:
 *
 *   1) bump the source's link count, so it cannot be reclaimed while it has
 *      two names and so a crash over-counts rather than under-counts;
 *   2) make the TARGET name reach the source -- direnter if the name is free,
 *      dirrewrite over the existing entry if it is not;
 *   3) unlink the source name and give the borrowed link back.
 *
 * STEP 3 RE-FINDS THE SOURCE ENTRY, AND THE REASON IS NOT UPSTREAM'S.  Reno
 * calls namei again because it dropped locks and another process may have
 * moved things.  Kernel C here runs to completion inside a syscall
 * (include/kernelc.s), so no other process runs in the middle of this one --
 * and the re-find is STILL REQUIRED, because step 2 may have rearranged the
 * very block step 1 recorded an offset in.  When the source and target
 * directories are the same, direnter's compaction slides records towards the
 * front and fndp->ni_offset stops naming the source's entry.  Same necessity,
 * different cause, and it is written down because a reader who knows Reno
 * would otherwise delete this as a concurrency artefact.
 *
 * It re-drives VOP_LOOKUP rather than namei: the component is one name in a
 * directory this function is holding, which is exactly what namei would
 * reduce to, and namei's CREATE/DELETE side is not wired to UFS yet.
 *
 * WHAT IS NOT CARRIED, each with its reason:
 *
 *   - THE STICKY BIT.  ISVTX plus a uid comparison implements append-only
 *     directories.  It belongs with the three VWRITE checks ufs_lookup is
 *     still owed rather than here on its own -- apple/fgx#419.
 *   - THE checkpath/namei RETRY LOOP.  Reno loops because checkpath unlocks
 *     the target's parent and namei must re-establish it; this port takes no
 *     locks, so checkpath is called once.
 *   - cache_purge IS NOT MISSING ANY MORE.  ufs_lookup consults the name
 *     cache, so both of upstream's calls are made: on the target's parent when
 *     an existing directory is replaced, and on the new parent when ".." is
 *     rewritten.
 *   - THE EXDEV PANICS.  Reno checks i_dev on three inodes because its namei
 *     can cross a mount point; a rename here is handed two nameidata from one
 *     filesystem and there is no second UFS mount to reach.
 *
 * AND ONE DIVERGENCE THAT IS STRICTER: Reno's `dirbad` PRINTS "rename:
 * mangled dir" and carries on with the ".." patch skipped, leaving a
 * directory whose parent pointer is wrong.  This panics.  A filesystem that
 * has just been told its ".." is not ".." has nothing left to be right about,
 * and this tree has no printf to be ignored in.
 *
 * REFERENCES: the caller owns both ni_dvp, as everywhere in this layer.  This
 * function releases fndp->ni_vp and tndp->ni_vp exactly once each, on every
 * path, plus anything it acquires itself.
 */
int
ufs_rename(fndp, tndp)
struct nameidata *fndp;
struct nameidata *tndp;
{
    struct inode  *ip;              /* the source inode, the one being moved */
    struct inode  *xp;              /* the target, then the re-found source */
    struct inode  *dp;              /* the target's directory */
    struct inode  *fdp;             /* the source's directory */
    struct direct *e;
    struct buf    *bp;
    char          *nm;
    int            dotlen;
    int            doingdirectory;
    int            oldparent;
    int            newparent;
    int            error;

    error          = 0;
    doingdirectory = 0;
    oldparent      = 0;
    newparent      = 0;

    fdp = VTOI(fndp->ni_dvp);
    ip  = VTOI(fndp->ni_vp);
    dp  = VTOI(tndp->ni_dvp);
    xp  = (struct inode *)0;
    if (tndp->ni_vp != (struct vnode *)0)
        xp = VTOI(tndp->ni_vp);

    if ((ip->i_mode & IFMT) == IFDIR) {
        /* ".", "..", AND ALIASES OF ".", which upstream refuses "for obvious
         * reasons" and which are worth spelling out: renaming "." renames the
         * directory the walk is standing in, and the entry it would rewrite
         * is the one it is reading.  IRENAME catches a directory already
         * being moved -- it cannot be set in this tree, where nothing else
         * runs during this call, and it is tested anyway because the flag
         * exists and the day it can be set is the day this matters. */
        nm = fndp->ni_ptr;
        if (((int)fndp->ni_namelen == 1 && nm[0] == '.') ||
            fdp == ip || fndp->ni_isdotdot != 0 ||
            (ip->i_flag & IRENAME) != 0) {
            error = EINVAL;
            goto outnolink;
        }
        ip->i_flag    |= IRENAME;
        oldparent      = (int)fdp->i_number;
        doingdirectory = 1;
    }

    /* ---- 1) THE BORROWED LINK ------------------------------------------ */
    ip->i_nlink++;
    ip->i_flag |= ICHG;
    error = iupdat(ip, 1);
    if (error)
        goto out;

    if (oldparent != (int)dp->i_number)
        newparent = (int)dp->i_number;

    if (doingdirectory && newparent) {
        /* A NEW PARENT MEANS ".." IS REWRITTEN, AND THAT IS A WRITE TO THE
         * SOURCE.  Reno asks it at ufs/ufs_vnops.c:968 and its comment is the
         * rule: "the user must have write permission in the source so as to
         * be able to change `..'".  Upstream locks the vnode around the call;
         * this port takes no locks.  The borrowed link above is given back by
         * `out'. */
        error = ufs_access(fndp->ni_vp, VWRITE, (char *)0);
        if (error)
            goto out;

        /* MOVING A DIRECTORY INTO ITS OWN SUBTREE loses everything under it:
         * the subtree names itself in a ring and nothing outside points in. */
        error = ufs_checkpath(ip, dp);
        if (error)
            goto out;
    }

    /* ---- 2) THE TARGET NAME REACHES THE SOURCE ------------------------- */
    if (xp == (struct inode *)0) {
        /* A NEW ".." IN A NEW PARENT is a link the parent has to account for.
         * When the two directories are the same the count does not move, and
         * upstream notes that explicitly because the symmetric-looking code
         * would be wrong. */
        if (doingdirectory && newparent) {
            dp->i_nlink++;
            dp->i_flag |= ICHG;
            error = iupdat(dp, 1);
            if (error) {
                /* PUT IT BACK.  `out:` returns the SOURCE's borrowed link and
                 * knows nothing about this one, so a failure here would leave
                 * the new parent permanently one link heavy -- a directory
                 * whose count can never reach zero, which is to say one
                 * nothing can ever remove.  This error path is FGX's own:
                 * upstream ignores iupdat's return here, and ufs_mkdir in this
                 * file already undoes the same bump the same way. */
                dp->i_nlink--;
                dp->i_flag |= ICHG;
                goto out;
            }
        }
        error = ufs_direnter(ip, tndp);
        if (error)
            goto out;
    } else {
        if (xp->i_number == ip->i_number)
            kc_panic("rename: same file");

        /* THE TWO MUST BE THE SAME KIND, and a directory being replaced must
         * be EMPTY and have no other links.  Upstream's reason for the second
         * half is the one that is easy to miss: a remaining link would name a
         * directory with no "." and no "..". */
        if ((xp->i_mode & IFMT) == IFDIR) {
            if (!ufs_dirempty(xp, dp->i_number) || (int)xp->i_nlink > 2) {
                error = ENOTEMPTY;
                goto out;
            }
            if (!doingdirectory) {
                error = ENOTDIR;
                goto out;
            }
            /* THE TARGET DIRECTORY IS ABOUT TO BE REPLACED, so its parent's
             * cached names are about to be wrong.  Reno purges here, at the
             * point the checks have all passed and before dirrewrite commits
             * (ufs/ufs_vnops.c:1045). */
            cache_purge(ITOV(dp));
        } else if (doingdirectory) {
            error = EISDIR;
            goto out;
        }

        error = ufs_dirrewrite(dp, ip, tndp);
        if (error)
            goto out;

        /* The target's entry now names the source, so the target itself has
         * lost a link.  A directory loses two -- the name and its own "." --
         * and it was just shown to have exactly those, so the inode and its
         * space go now rather than at the next reference drop. */
        xp->i_nlink--;
        if (doingdirectory) {
            xp->i_nlink--;
            if (xp->i_nlink != 0)
                kc_panic("rename: linked directory");
            error = ufs_itrunc(xp, (off_t)0, IO_SYNC, (long *)0);
        }
        xp->i_flag |= ICHG;
        iput(xp);
        xp = (struct inode *)0;
    }

    /* ---- 3) UNLINK THE SOURCE ------------------------------------------ */
    fndp->ni_nameiop = (short)(DELETE | LOCKPARENT);
    fndp->ni_vp      = (struct vnode *)0;
    error = VOP_LOOKUP(fndp->ni_dvp, fndp);
    if (error != 0 || fndp->ni_vp == (struct vnode *)0) {
        /* The name is gone.  For a FILE that is a legitimate outcome of a
         * concurrent unlink upstream and cannot happen here; for a directory
         * it cannot happen in either tree, because a link count of three
         * makes rmdir refuse with ENOTEMPTY. */
        if (doingdirectory)
            kc_panic("rename: lost dir entry");
        error = 0;
        goto done;
    }
    xp = VTOI(fndp->ni_vp);
    if (xp != ip) {
        if (doingdirectory)
            kc_panic("rename: lost dir entry");
    } else {
        /* A DIRECTORY THAT CHANGED PARENT CARRIES A STALE "..", and the old
         * parent is carrying a link for a child it no longer has. */
        if (doingdirectory && newparent) {
            fdp->i_nlink--;
            fdp->i_flag |= ICHG;
            if (bread(ITOV(xp), (daddr_t)0, &bp) != 0) {
                brelse(bp);
            } else {
                e = (struct direct *)&bp->b_addr[0];
                /* BOUNDED, for ufs_checkpath's reason: "."'s d_reclen comes
                 * off the platter and an impossible one would index past the
                 * buffer. */
                dotlen = (int)e->d_reclen;
                if (dotlen < DIRHDRSIZ || (dotlen & 3) != 0 ||
                    dotlen + DIRHDRSIZ > FS_BLKSIZE)
                    kc_panic("rename: mangled dir");
                e  = (struct direct *)&bp->b_addr[dotlen];
                nm = (char *)e + DIRHDRSIZ;
                if ((int)e->d_namlen != 2 || nm[0] != '.' || nm[1] != '.')
                    kc_panic("rename: mangled dir");
                e->d_ino = (ino_t)newparent;
                (void)bwrite(bp);
                /* ".." NOW NAMES A DIFFERENT DIRECTORY, and any cached entry
                 * that resolved it still names the old one.  Reno purges the
                 * NEW parent here, inside the arm that actually rewrote the
                 * entry (ufs/ufs_vnops.c:1128) -- not outside it, because a
                 * mangled directory that was not patched has nothing to
                 * invalidate. */
                cache_purge(ITOV(dp));
            }
        }
        /* THE UNLINK HAPPENS WHATEVER THE PATCH DID, which is upstream's
         * ordering and not an oversight in it.  Skipping it on a failed ".."
         * write leaves the directory live under BOTH names with the old
         * parent's link count already decremented -- strictly the worse of
         * the two crash states, and the one no fsck can attribute.  Reno
         * writes best-effort and always reaches dirremove. */
        error = ufs_dirremove(fndp);
        if (error == 0) {
            xp->i_nlink--;
            xp->i_flag |= ICHG;
        }
        xp->i_flag &= ~IRENAME;
    }
    iput(xp);
    xp = (struct inode *)0;

done:
    ip->i_flag &= ~IRENAME;
    vrele(ITOV(ip));
    return (error);

out:
    /* The borrowed link goes back.  Everything above this label either has
     * not taken it or has not yet given the source a second name. */
    ip->i_nlink--;
    ip->i_flag |= ICHG;
outnolink:
    ip->i_flag &= ~IRENAME;
    if (xp != (struct inode *)0)
        iput(xp);
    vrele(ITOV(ip));
    return (error);
}


/* ufs_remove -- the VOP_REMOVE slot.  4.3BSD-Reno ufs/ufs_vnops.c's ufs_remove.
 *
 * IT DOES NOT FREE ANYTHING, and that is the whole of unlink(2)'s contract: it
 * takes the NAME away and drops the link count.  The blocks and the inode
 * number go back when the last reference does, in ufs_inactive -- which is why
 * a file can be unlinked while it is open and keep working.  1.12b built that
 * side; this is the side that makes it reachable.
 *
 * dp == ip IS THE `rm .` CASE and needs the vrele rather than the iput,
 * because the two references are to one vnode and iput would release a lock
 * this function never took.  Upstream carries the same test.
 */
int
ufs_remove(ndp)
struct nameidata *ndp;
{
    struct inode *ip;
    struct inode *dp;
    int           error;

    ip = VTOI(ndp->ni_vp);
    dp = VTOI(ndp->ni_dvp);

    error = ufs_dirremove(ndp);
    if (error == 0) {
        ip->i_nlink--;
        ip->i_flag |= ICHG;
    }
    if (dp == ip)
        vrele(ITOV(ip));
    else
        iput(ip);
    return (error);
}


/* ufs_lock / ufs_unlock / ufs_islocked -- the inode lock.  UFS 1.12d.
 * 4.3BSD-Reno ufs/ufs_inode.c:654-687 (ilock, iunlock) and ufs/ufs_vnops.c's
 * ufs_lock/ufs_unlock/ufs_islocked, which are one-line wrappers there.
 *
 * WHAT IT IS FOR, since a probe cannot show it: every mutating operation in
 * this filesystem reads a block, changes some bytes and writes it back, and
 * between the read and the write it SLEEPS -- in bread, in bwrite, in
 * ufs_ialloc's wait on sb_ilock.  Two writers of one file interleaved inside
 * ufs_write's loop, or two direnters interleaved inside one directory block,
 * each write back a block built from what they read before the other's change.
 * The lock is what makes "read, modify, write" one step for the inode it names.
 *
 * IT IS THE VNODE'S LOCK AND THE INODE'S BIT, which is upstream's arrangement
 * and not a compromise between two.  ILOCKED lives in i_flag because the
 * filesystem is what owns the notion; the ENTRY POINTS are vnode ops because
 * everything above the filesystem -- namei, vclean, vput -- has only a vnode
 * to hold.  Reno spells the same pair as ilock()/iunlock() with ufs_lock and
 * ufs_unlock as one-line wrappers around them; there is no second caller here
 * for the inner form, so there is one function instead of two.
 *
 * TAKEN INSIDE iget, released by iput, exactly as upstream: iget returns a
 * LOCKED inode and iput unlocks and releases.  Every `iget ... iput` pair in
 * this tree is therefore a lock held across the work between them, and they
 * were written that way from 1.11a on against slots that were still nullops.
 * vget does NOT take it here -- Reno's does -- because this tree's namei locks
 * each directory explicitly (vfs_lookup.c) rather than by side effect, and
 * both would be a double lock.
 *
 * THE SLEEP CHANNEL IS THE INODE, matching Reno, and it must stay the inode
 * rather than the vnode: ufs_ihashget can be waiting on the same address.
 *
 * SELF-DEADLOCK IS A PANIC AND NOT A HANG, which is the whole reason
 * i_lockholder exists.  A single-threaded boot that locks an inode twice would
 * otherwise sleep on a channel nothing will ever wake, and a hang is a harness
 * timeout that names no function.  Reno's panic string is "locking against
 * myself" and is kept verbatim -- it is what a search will be looking for.
 */
/* ufs_panicino -- panic naming the INODE, and the number is the whole point.
 *
 * MEASURED RATHER THAN PREFERRED.  Bringing the inode lock up cost four
 * on-target runs whose entire output was `locking against myself`, each one
 * followed by a guess; the fifth run printed the number and named the site on
 * the first reading.  A lock fault is about ONE object and the panic that does
 * not say which is a panic that has to be bisected.
 *
 * kernel C has no formatter and kc_panic takes a string, so the four digits
 * are laid out by hand.  Sixteen bytes of module data, once, against a class
 * of fault whose alternative diagnosis is a rebuild per hypothesis.
 */
static char ufs_pbuf[16];

static void
ufs_panicino(what, ino)
char  *what;
ino_t  ino;
{
    char *cp;
    int   i;
    int   q;

    for (i = 0; i < 10 && what[i] != '\0'; i++)
        ufs_pbuf[i] = what[i];
    ufs_pbuf[i] = ' ';
    q = (int)ino;
    ufs_pbuf[i + 1] = (char)('0' + ((q / 1000) % 10));
    ufs_pbuf[i + 2] = (char)('0' + ((q / 100) % 10));
    ufs_pbuf[i + 3] = (char)('0' + ((q / 10) % 10));
    ufs_pbuf[i + 4] = (char)('0' + (q % 10));
    ufs_pbuf[i + 5] = (char)0;
    cp = ufs_pbuf;
    kc_panic(cp);
}


int
ufs_lock(vp)
struct vnode *vp;
{
    register struct inode *ip;

    ip = VTOI(vp);
    while (ip->i_flag & ILOCKED) {
        /* READ THE PID AFTERWARDS AND EVERY TIME, never once into a local
         * above the loop: a pid read before a sleep names a different process
         * after one (apple/fgx#41), and kc_sys.s says so at kc_curpid. */
        if (ip->i_lockholder == (short)kc_curpid())
            ufs_panicino("lockself", ip->i_number);
        ip->i_flag |= IWANT;
        kc_sleep((char *)ip);
    }
    ip->i_flag |= ILOCKED;
    ip->i_lockholder = (short)kc_curpid();
    return (0);
}

/* A PANIC WHERE RENO WARNS, deliberately.  Upstream's iunlock calls vprint on
 * an inode that is not locked and carries on; there is no vprint here, and
 * more to the point an unlock of something this tree never locked is exactly
 * the defect this increment exists to find.  Carrying on would leave it to be
 * discovered as the NEXT lock of the same inode hanging or panicking somewhere
 * unrelated -- which is exactly how this increment spent its first four
 * on-target runs.  There is no man page to put the divergence in: nothing in
 * this kernel is documented at the vnode-op layer yet, so it is stated here
 * and nowhere else. */
int
ufs_unlock(vp)
struct vnode *vp;
{
    register struct inode *ip;

    ip = VTOI(vp);
    if ((ip->i_flag & ILOCKED) == 0)
        ufs_panicino("unlkfree", ip->i_number);
    ip->i_lockholder = 0;
    ip->i_flag &= ~ILOCKED;
    if (ip->i_flag & IWANT) {
        ip->i_flag &= ~IWANT;
        kc_wakeup((char *)ip);
    }
    return (0);
}

int
ufs_islocked(vp)
struct vnode *vp;
{
    if (VTOI(vp)->i_flag & ILOCKED)
        return (1);
    return (0);
}


/* ufs_mknod -- the VOP_MKNOD slot.  4.3BSD-Reno ufs/ufs_vnops.c's ufs_mknod.
 * UFS 1.13a.
 *
 * IT IS maknode PLUS A DEVICE NUMBER, AND THEN IT THROWS THE VNODE AWAY, which
 * is the part that reads like a bug and is upstream's whole point.  maknode
 * allocates the inode and calls iget on it while its mode is still ZERO -- so
 * the vnode iget minted is VNON, wears the ordinary ufs_vnodeops, and never
 * went near checkalias.  It is the wrong vnode for a device file and there is
 * no way to fix it in place: the alias chain is joined at iget, from the mode
 * that is only now correct.
 *
 * So the entry on the platter is right and the vnode is discarded, and the
 * NEXT lookup of the name builds a proper one.  Reno's comment: "Remove inode
 * so that it will be reloaded by iget and checked to see if it is an alias of
 * an existing entry in the inode cache."
 *
 * CONSEQUENCE FOR THE CALLER, and it is why this does not set ni_vp where
 * ufs_create does: mknod(2) returns no descriptor.  A caller that wants the
 * device must look the name up, which is exactly the path that builds the
 * right vnode.
 *
 * NOT SUPPORTED HERE, and refused rather than mis-made.  VFIFO, which this
 * kernel does not have.  VSOCK, which it DOES have -- but an AF_UNIX socket's
 * name is bound through VOP_CREATE, which is upstream's route for it too, so a
 * VSOCK reaching mknod(2) is a caller error rather than a gap; see ufs_create.
 * And 2.11BSD's use of a bare IFMT to flag bad sectors for badsect(8) -- not
 * ported, and whose inode would otherwise be a device file with an impossible
 * type.
 */
int
ufs_mknod(ndp, vap)
struct nameidata *ndp;
struct vattr     *vap;
{
    struct inode *ip;
    struct vnode *vp;
    int           mode;
    int           error;

    mode = (int)(vap->va_mode & 07777);
    if (vap->va_type == VCHR)
        mode |= IFCHR;
    else if (vap->va_type == VBLK)
        mode |= IFBLK;
    else
        return (EINVAL);

    error = ufs_maknode(mode, ndp, &ip);
    if (error)
        return (error);

    ip->i_flag |= IACC | IUPD | ICHG;
    /* VA_UNSET IS "the caller did not say", NOT "no device".  NODEV is a
     * device number a caller can legitimately mean; upstream tests VNOVAL here
     * for the same distinction, and its comment adds the reason it does not
     * range-check: badsect wants to store a block number in this field. */
    if (vap->va_rdev != (dev_t)VA_UNSET)
        ufs_setrdev(ip, vap->va_rdev);

    /* THE DINODE REACHES THE PLATTER THROUGH ufs_inactive, which iput's vrele
     * runs when this last reference goes -- and iupdat writes synchronously,
     * so it is on the disk before the vgone below rather than in a buffer.
     * See iupdat's header in ufs_inode.c for why that is unconditional. */
    vp = ITOV(ip);
    iput(ip);

    /* VNON BEFORE vgone, which is Reno's order and load-bearing: vclean
     * dispatches through the vnode's own vector, and a vnode still claiming
     * to be VCHR would be cleaned as a device it never joined the alias chain
     * as. */
    vp->v_type = VNON;
    vgone(vp);
    ndp->ni_vp = (struct vnode *)0;
    return (0);
}


/* ufsspec_read / ufsspec_write / ufsspec_close -- the three device operations
 * that also have to touch the INODE.  4.3BSD-Reno ufs/ufs_vnops.c's ufsspec_*.
 *
 * READING A DEVICE STILL SETS ITS FILE'S ACCESS TIME.  The bytes come from a
 * driver and none of the inode's fields describe them, but the inode is still
 * a file with an atime that `ls -lu /dev` reads.  Everything else in
 * spec_inodeops is one side or the other; these three are both.
 */
int
ufsspec_read(vp, uio, ioflag, cred)
struct vnode *vp;
struct uio   *uio;
int           ioflag;
char         *cred;
{
    VTOI(vp)->i_flag |= IACC;
    return (spec_read(vp, uio, ioflag, cred));
}

int
ufsspec_write(vp, uio, ioflag, cred)
struct vnode *vp;
struct uio   *uio;
int           ioflag;
char         *cred;
{
    VTOI(vp)->i_flag |= IUPD | ICHG;
    return (spec_write(vp, uio, ioflag, cred));
}

int
ufsspec_close(vp, flag, cred)
struct vnode *vp;
int           flag;
char         *cred;
{
    struct inode *ip;

    /* THE GUARD IS UPSTREAM'S AND BOTH HALVES MATTER.  `v_usecount > 1` means
     * this is not the last close, so the timestamps are worth settling now
     * rather than at a teardown that may be a long way off; and NOT ILOCKED
     * means somebody else is mid-operation on this inode and its flags are
     * theirs to finish with. */
    ip = VTOI(vp);
    if (vp->v_usecount > 1 && (ip->i_flag & ILOCKED) == 0)
        ufs_itimes(ip);
    return (spec_close(vp, flag, cred));
}


int
ufs_erofs()
{
    return (EROFS);
}

int
ufs_nullop()
{
    return (0);
}

/* ufs_access -- may THIS caller do THAT to this file?
 *
 * Ported from 4.3BSD-Reno `ufs/ufs_vnops.c', ufs_access().  UFS campaign 2.6.
 * `mode' is one of VREAD, VWRITE or VEXEC (vnode.h, Reno's sys/vnode.h:226-228).
 *
 * THE ONE DIVERGENCE, AND IT IS THE WHOLE POINT OF THE SEAM.  Reno takes a
 * `struct ucred *' and reads cred->cr_uid and cred->cr_groups from it.  This
 * kernel has no ucred by design and takes 2.11BSD's shape instead, whose own
 * check is `access(ip, mode)' (usr/sys/sys/ufs_fio.c:32) reading `u.u_uid'
 * from the u-area -- file.h's f_cred note is the canonical statement of why.
 * So the ids come from the CALLER'S U-AREA, via kc_curuid/kc_curgid
 * (KSVC_CURUID/KSVC_CURGID).  The `cred' argument is kept so the signature
 * matches the ops table and upstream, and is ignored.
 *
 * ASKING ON BEHALF OF ANOTHER SET OF IDS NEEDS NO CREDENTIAL, which is the
 * thing that looks like it should.  Reno passes a ucred down so access(2) can
 * be answered for the REAL ids; 2.11BSD answers the same question by swapping
 * them into the u-area around the call and putting them back: `t_uid =
 * u.u_uid; u.u_uid = u.u_ruid;' and its restore, in
 * saccess (usr/sys/sys/ufs_syscalls.c:383).  FGX has the same triples
 * (U_Ruid/U_Uid/U_Svuid, include/kernel.s), so that mechanism is available
 * here as it stands.  Recorded because the absence of a cred parameter reads
 * like a limitation and is not one.
 *
 * NO GROUP LIST.  Reno walks cred->cr_groups for cr_ngroups entries; FGX has a
 * single effective gid in the u-area, so the membership test is one compare.
 *
 * NO QUOTA BLOCK.  Reno's #ifdef QUOTA calls getinoquota for a VWRITE on a
 * VREG/VDIR/VLNK; there are no quotas here.
 *
 * NO VOP_ISLOCKED ASSERTION.  Reno's is under #ifdef DIAGNOSTIC and this port
 * takes no vnode locks.
 *
 * THE SHIFTS ARE UPSTREAM'S AND THE ORDER MATTERS.  Owner is the mode as
 * given; a non-owner shifts right 3 and tests the group; a non-member shifts
 * right 3 AGAIN for other.  The `goto found' is what makes the group case skip
 * the second shift, so the three cases are shifts of 0, 3 and 6.  The final
 * test is `& mode' against zero, NOT equality -- upstream calls this with one
 * bit at a time, and a multi-bit mode would pass on ANY match rather than all.
 */
int
ufs_access(vp, mode, cred)
struct vnode *vp;
int           mode;
char         *cred;             /* Reno: struct ucred *.  Always 0 -- see head */
{
    register struct inode *ip = VTOI(vp);
    int uid;

    /* If you are the super-user, you always get access. */
    uid = kc_curuid();
    if (uid == 0)
        return (0);

    /* The check is based on ONE of owner, group, public.  If not owner, check
     * group; if not a member of the group, check public. */
    if (uid != ip->i_uid) {
        mode >>= 3;
        if (ip->i_gid != kc_curgid())
            mode >>= 3;
    }
    if ((ip->i_mode & mode) != 0)
        return (0);
    return (EACCES);
}

struct vnodeops ufs_vnodeops = {
    ufs_lookup,         /* lookup    -- REAL as of 1.11c */
    ufs_create,         /* create    -- REAL as of 1.12c */
    ufs_mknod,          /* mknod     -- REAL as of 1.13a */
    ufs_nullop,         /* open      -- nothing to do for a regular file */
    ufs_nullop,         /* close */
    /* REAL as of 2.6.  NOTHING CALLS IT YET: vn_open's two VOP_ACCESS sites
     * and namei's are the next increment, and turning them on is what makes
     * permissions ENFORCED rather than merely answerable. */
    ufs_access,         /* access    -- REAL as of 2.6 */
    ufs_getattr,        /* getattr   -- REAL as of 1.11b */
    ufs_setattr,        /* setattr   -- REAL as of 1.12b */
    ufs_read,           /* read      -- REAL as of 1.11b */
    ufs_write,          /* write     -- REAL as of 1.12a */
    ufs_enotsup,        /* ioctl     -- not a device; ENOTTY once there is a
                         *              caller that can tell the difference */
    ufs_select,         /* select */
    ufs_enotsup,        /* mmap      -- no VM */
    ufs_fsync,          /* fsync     -- REAL as of 1.12a */
    ufs_nullop,         /* seek      -- Reno's is a no-op too */
    ufs_remove,         /* remove    -- REAL as of 1.12c */
    ufs_link,           /* link      -- REAL as of 1.12c-b */
    ufs_rename,         /* rename    -- REAL as of 1.12c-c */
    ufs_mkdir,          /* mkdir     -- REAL as of 1.12c-b */
    ufs_rmdir,          /* rmdir     -- REAL as of 1.12c-b */
    ufs_symlink,        /* symlink   -- REAL as of 1.12c-b */
    ufs_readdir,        /* readdir   -- REAL as of 1.11c */
    ufs_readlink,       /* readlink  -- REAL as of 1.12a */
    ufs_nullop,         /* abortop */
    ufs_inactive,       /* inactive  -- REAL as of 1.12b */
    ufs_reclaim,        /* reclaim  -- REAL, not a refusal: it is what takes
                         * the inode off its hash chain.  See ufs_inode.c. */
    ufs_lock,           /* lock      -- REAL as of 1.12d; see above */
    ufs_unlock,         /* unlock */
    ufs_vbmap,          /* bmap      -- REAL as of 1.11b; see the wrapper */
    ufs_strategy,       /* strategy  -- REAL as of 1.11b: the logical-to-
                         * physical map that makes the buffer cache work
                         * for FILES rather than only for devices */
    ufs_nullop,         /* print */
    ufs_islocked        /* islocked -- REAL as of 1.12d */
};


/* spec_inodeops -- the vector a DEVICE FILE wears.  UFS 1.13a.
 * 4.3BSD-Reno ufs/ufs_vnops.c:125, entry for entry.
 *
 * TWO HALVES FROM TWO MODULES.  The device operations are vfs.mod's spec_* and
 * the inode operations are this file's ufs_*; the table is built HERE because
 * a vtable cell must name a function in the module that owns the cell, so the
 * spec_* names above resolve to this module's import shims and the shims cross
 * the bank.  ufs_vnodeops already does exactly that for ufs_reclaim.
 *
 * WHY NOT JUST spec_vnodeops, which exists and is one table instead of two:
 * its reclaim slot is spec_nullop, and a device file HAS an inode -- a nullop
 * reclaim leaves that inode on its hash bucket when the vnode is recycled,
 * which is apple/fgx#175 and cost this campaign a session already.  Its
 * getattr is spec_ebadf, so `ls -l /dev` would fail on every entry.  The two
 * tables are not more and less complete versions of each other; they are for
 * a device with an inode and a device without one.
 *
 * lock/unlock/islocked ARE ufs_*, and that is only possible because 1.12d
 * made them real.  A device file is an inode like any other and iget hands it
 * over locked; had these been spec_lock -- a no-op -- iput would have unlocked
 * something never locked, which is a panic since 1.12d.
 */
struct vnodeops spec_inodeops = {
    spec_lookup,        /* lookup    -- a device is not a directory */
    spec_badop,         /* create */
    spec_badop,         /* mknod */
    spec_open,          /* open      -- the DRIVER's */
    ufsspec_close,      /* close     -- timestamps, then the driver's */
    ufs_access,         /* access    -- REAL as of 2.6, as ufs_vnodeops */
    ufs_getattr,        /* getattr   -- the INODE's, and it reports va_rdev */
    ufs_setattr,        /* setattr   -- likewise */
    ufsspec_read,       /* read      -- atime, then the driver's */
    ufsspec_write,      /* write     -- mtime/ctime, then the driver's */
    spec_ioctl,         /* ioctl */
    spec_select,        /* select */
    spec_badop,         /* mmap */
    ufs_nullop,         /* fsync     -- Reno's spec_nullop, spelled locally */
    spec_badop,         /* seek */
    spec_badop,         /* remove */
    spec_badop,         /* link */
    spec_badop,         /* rename */
    spec_badop,         /* mkdir */
    spec_badop,         /* rmdir */
    spec_badop,         /* symlink */
    spec_badop,         /* readdir */
    spec_badop,         /* readlink */
    spec_badop,         /* abortop */
    ufs_inactive,       /* inactive  -- the INODE's: an unlinked open device
                         * file gives its i-list slot back like any other */
    ufs_reclaim,        /* reclaim   -- and comes off the inode hash.  This is
                         * the slot spec_vnodeops cannot supply */
    ufs_lock,           /* lock      -- REAL since 1.12d; see above */
    ufs_unlock,         /* unlock */
    spec_bmap,          /* bmap      -- the device's, not the file's */
    spec_strategy,      /* strategy */
    ufs_nullop,         /* print */
    ufs_islocked        /* islocked */
};


/* ufs_dirinit -- hand the ops table to the block half, once, at load time.
 *
 * THE TWO HALVES OF UFS ARE TWO MODULES SINCE THE BANK SPLIT, and this is the whole of
 * what the NAME half has to tell the BLOCK half: where the vnode-ops table is.
 * iget stamps it into every vnode it mints and refuses until it has one.
 *
 * ufsdir.s calls this from its mod_init, after both vtables resolve and before
 * anything else runs -- the same shape ufs.mod's mod_init uses for ufs_init,
 * and for the same reason: there is no mount yet to dispatch from.
 */
void
ufs_dirinit()
{
    ufs_setvnodeops(&ufs_vnodeops);
    /* AND THE DEVICE-FILE TABLE, in the same call and for the same reason:
     * iget stamps one or the other into every vnode it mints, from the mode it
     * has just read, and it cannot ask this module for either.  Both go over
     * together so that the single "have I been given a table" guard in iget
     * covers both -- there is no state in which one is set and the other is
     * not. */
    ufs_setspecops(&spec_inodeops);
    /* AND THE PLAIN DEVICE VECTOR GOES THE OTHER WAY, to vfs.mod.  spec_vnops.c
     * lives in THIS module since 2026-09-05, so vfs.mod's bdevvp and checkalias
     * -- which took &spec_vnodeops directly while it was theirs -- cannot form
     * the address any more.  Same hand-over, opposite direction; both of
     * vfs_subr.c's readers refuse until this runs. */
    vfs_setspecops(&spec_vnodeops);
    /* AND THE NAME CACHE'S TWO RARE ENTRIES, the same way and for the same
     * reason.  vfs_cache.c is this module's since the cache was wired into
     * ufs_lookup, so vfs.mod's getnewvnode and vfs_dounmount cannot name
     * cache_purge and cache_purgevfs; they dispatch through this table.
     *
     * AFTER nchinit, WHICH ufsdir.s HAS ALREADY RUN.  The order matters in one
     * direction only: vfs.mod may call co_purge as soon as this returns, and
     * the wrap arm it might take walks the buckets nchinit builds. */
    vfs_setcacheops(&ufs_cacheops);
}
