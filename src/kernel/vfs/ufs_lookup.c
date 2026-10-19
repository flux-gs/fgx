/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno ufs/ufs_lookup.c
 *   Ported from ufs/ufs_lookup.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 */
/* ufs_lookup.c -- search one directory for one component.  UFS 1.11c.
 *
 * THE CONTRACT IS namei's:
 *
 *     0        found; ni_vp is the vnode, REFERENCED and LOCKED.
 *     ENOENT   not found.
 *     ENOTDIR  the thing being searched is not a directory.
 *
 * Those three answers and the locking that goes with them are 4.3BSD-Reno's,
 * read out of ufs/ufs_lookup.c; this file reproduces them over real directory
 * blocks.
 *
 *----------------------------------------------------------------------------
 * WHAT IS HERE AND WHAT IS 1.12's.
 *
 * Reno's ufs_lookup is 400 lines because it serves FOUR operations: LOOKUP,
 * and the setup CREATE, DELETE and RENAME need to modify the directory
 * afterwards.  The last three record where the name was found or where a new
 * one would fit -- i_offset, i_count, i_endoff, i_reclen -- so that direnter
 * and dirremove can act without scanning again.
 *
 * NONE OF THAT IS HERE.  The mount is read-only until 1.12, nothing calls
 * direnter or dirremove because neither exists, and bookkeeping written now
 * would be bookkeeping nothing checks.  What IS here is the part those
 * operations share -- the scan, the three-way ".", ".." and ordinary split,
 * and the lock disposal -- so 1.12 adds fields to a working scan rather than
 * writing the scan.
 *
 * The operation is still READ from ni_nameiop, because the LOCK DISPOSAL
 * differs by operation even when the search does not: a CREATE miss on the last
 * component must unlock the parent and a LOOKUP miss must not.  Getting that wrong leaks a lock only on the
 * create path, which is why it is written to the real rule now rather than to
 * the subset today's callers exercise.
 *
 *----------------------------------------------------------------------------
 * THE NAME CACHE IS WIRED HERE, which is what Reno's ufs_lookup is: it opens
 * with cache_lookup and closes with cache_enter, and so does this.
 *
 * IT WAS DELIBERATELY LEFT UNWIRED UNTIL apple/fgx#380, and the condition that
 * had to be met first was the invalidation, not the lookup.  A cache is a
 * correctness question the moment names can change, so the four purge points
 * upstream makes -- two in ufs_rename, two in ufs_rmdir -- landed with the two
 * calls here rather than after them.  ufs_reclaim's fifth is NOT repeated;
 * getnewvnode already purges on every handout, and ufs_inode.c says so at the
 * site.
 *
 * WHAT MAKES A STALE ENTRY IMPOSSIBLE TO USE is the capability number: v_id is
 * re-minted on every vnode handout, cache_lookup compares the recorded one
 * against the vnode's, and a mismatch is counted as a false hit and dropped.
 * namei.h explains why that field stays 32 bits wide.
 *
 * THE CACHE LIVES IN THIS MODULE, ufsdir.mod, for the reason spec_vnops.c
 * does: this file is its only hot-path caller, and its state is read on every
 * call.  vfs.mod keeps the two rare entries and reaches them through a table
 * ufs_dirinit hands over.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "mount.h"
#include "vfsops.h"
#include "ufs_fs.h"
#include "ufsmount.h"
#include "inode.h"
#include "dir.h"
#include "namei.h"

/* vfs_cache.c, THIS module.  cache_lookup returns -1 for a hit, ENOENT for a
 * negative hit and 0 for a miss -- see its header; the three are not a scale. */
extern int  cache_lookup();
extern void cache_enter();
/* vfs.mod, through src/modules/ufsdir/vfs_import.s.  The cache hit arm claims
 * the vnode it is handed rather than going through iget. */
extern int  vget();
extern void vput();

/* slotstatus -- Reno's NONE / COMPACT / FOUND (ufs/ufs_lookup.c:60-62), named
 * SLOT_* here because FOUND alone is too general a word to introduce into a
 * file that also has a `found` inode number. */
#define SLOT_NONE       0
#define SLOT_COMPACT    1
#define SLOT_FOUND      2

extern int  bread();
extern void brelse();
extern void vref();
extern void vrele();
extern int  iget();
extern void iput();
extern void kc_panic();
extern int  bwrite();       /* 1.12c: direnter and dirremove write blocks */
extern int  ufs_write();    /* 1.12c: a new entry grows the directory */
extern int  ufs_itrunc();   /* 1.12c: direnter gives the tail back */
extern int  kc_curuid();    /* 2.8: KSVC_CURUID, for the sticky-bit rule */
extern int  ufs_access();   /* 2.6: the walk's own permission check.  Same
                             * MODULE (ufsdir.mod PUTs ufs_vnops.s beside this
                             * file), so it is a direct call and not an import
                             * -- and upstream calls it directly here too,
                             * rather than through VOP_ACCESS, because the
                             * directory is this filesystem's own. */

/* ufs_dirmatch -- does the entry at `e` name this component?
 *
 * BOTH ENDS MATTER: a prefix compare matches "a" against the component "ab" and
 * hands back the wrong file.  Here the stored name carries its own length, so
 * the end test is `d_namlen == n` rather than a NUL check -- and that is the
 * stronger form, because it does not trust the on-disk NUL to be there.
 *
 * A FREE ENTRY NEVER MATCHES.  d_ino == 0 is upstream's deleted-name marker
 * ("If the first entry of a directory block is free, then its dp->d_ino is set
 * to 0"), and its name bytes are whatever the deleted name was.  Testing the
 * inode number first is what stops a lookup finding a file that is gone.
 */
static int
ufs_dirmatch(e, nm, n)
struct direct *e;
char          *nm;
int            n;
{
    int i;

    if (e->d_ino == (ino_t)0)
        return (0);
    if ((int)e->d_namlen != n)
        return (0);
    for (i = 0; i < n; i++) {
        if (e->d_name[i] != nm[i])
            return (0);
    }
    return (1);
}


/* ufs_dirscan -- walk a directory looking for one name, and REMEMBER WHERE.
 *
 * 4.3BSD-Reno ufs/ufs_lookup.c's searchloop (:201-296), which is one loop
 * doing two jobs at once: matching the name, and -- when the caller intends to
 * create -- tracking the best place to put a new entry if the name is not
 * there.  1.11c ported the matching half; 1.12c adds the rest, because
 * direnter cannot work without it.
 *
 * WHAT IT RECORDS INTO ndp, AND WHY EACH IS NEEDED LATER:
 *
 *   ON A HIT, for dirremove: ni_offset is where the entry starts, ni_dent
 *   carries its d_ino and d_reclen, and ni_count is the DISTANCE BACK to the
 *   previous entry in the same 512-byte block -- or 0 when the entry is the
 *   first in its block, which dirremove reads as "just clear d_ino".  There is
 *   no previous entry to extend across a block boundary, which is the whole
 *   reason that distinction exists.
 *
 *   ON A MISS, for direnter: ni_offset and ni_count describe a run of space
 *   the new entry may occupy, and ni_count == 0 means none was found and the
 *   entry goes at the end.  ni_endoff is where the directory's USEFUL content
 *   stops, so direnter can hand the tail back with itrunc.
 *
 * THE SLOT SEARCH RESTARTS AT EVERY DIRBLKSIZ BOUNDARY, which is upstream's
 * rule and is not an optimisation: an entry may not cross a 512-byte block, so
 * free space in one block cannot be combined with free space in the next.  A
 * search that carried slotfreespace across the boundary would report room that
 * cannot hold anything.
 *
 * FREE SPACE COMES IN TWO SHAPES.  A DELETED entry is a record with d_ino 0 --
 * the whole of it is free.  A LIVE entry whose d_reclen exceeds the DIRSIZ its
 * name needs is carrying free space after the name.  Upstream counts both with
 * one expression (`size = d_reclen; if (d_ino) size -= DIRSIZ(ep)`), and that
 * is why a scan steps by d_reclen and never by DIRSIZ.
 *
 * COMPACTION IS THE THIRD CASE and is why slotfreespace accumulates: several
 * adjacent records may each be too small while their total is not, and
 * direnter can slide them together.  slotstatus COMPACT means exactly that,
 * and ni_count is then the span direnter is allowed to rearrange.
 *
 * THE CORRUPTION RESYNCHRONISATION IS THIS PORT'S AND IS KEPT.  Upstream calls
 * dirbad() and steps to the next DIRBLKSIZ boundary; the checks here are
 * stricter (a length that is unaligned, shorter than a header, or past the end
 * of its own block) and land in the same place, which dir.h's header explains.
 * A block being resynchronised through contributes NO slot: space inside a
 * record this scan could not parse is not space direnter may write into.
 */
static ino_t
ufs_dirscan(dvp, ip, nm, n, ndp, slotneeded, errp)
struct vnode     *dvp;
struct inode     *ip;
char             *nm;
int               n;
struct nameidata *ndp;          /* may be 0: a pure lookup records nothing */
int               slotneeded;   /* 0: do not track a slot at all */
int              *errp;         /* OUT: an I/O error, distinct from a miss */
{
    struct buf    *bp;
    struct direct *e;
    daddr_t        lbn;
    off_t          base;
    off_t          prevoff;
    off_t          enduseful;
    off_t          slotoffset;
    int            off;
    int            blkend;
    int            avail;
    int            reclen;
    int            size;
    int            slotstatus;
    int            slotfreespace;
    int            slotsize;
    int            error;
    ino_t          found;

    found         = (ino_t)0;
    base          = 0L;
    prevoff       = 0L;
    enduseful     = 0L;
    slotoffset    = (off_t)-1;
    slotstatus    = SLOT_NONE;
    slotfreespace = 0;
    slotsize      = 0;
    if (slotneeded == 0)
        slotstatus = SLOT_FOUND;    /* not looking: never record one */

    while (base < ip->i_size) {
        lbn = lblkno(base);
        error = bread(dvp, lbn, &bp);
        if (error) {
            /* AN UNREADABLE BLOCK IS NOT AN ABSENT NAME, and returning zero
             * here said it was.  The caller turns a zero into ENOENT, and a
             * CREATE reads ENOENT as "the name is free" -- with none of the
             * slot bookkeeping set, because this return skips the epilogue
             * that sets it.  direnter then takes its ni_count == 0 arm at
             * offset zero and writes the new entry over the head of the
             * directory, d_reclen spanning the whole block: "." and every
             * record after it gone, on a volume whose only fault was one bad
             * read.  Reno propagates the error (ufs/ufs_lookup.c:209-211) and
             * so does this now. */
            brelse(bp);
            if (errp != (int *)0)
                *errp = error;
            return ((ino_t)0);
        }
        /* How much of THIS filesystem block the directory actually owns.  The
         * last one is short whenever i_size is not a multiple of 1024. */
        avail = FS_BLKSIZE;
        if (ip->i_size - base < (off_t)FS_BLKSIZE)
            avail = (int)(ip->i_size - base);

        off = 0;
        while (off < avail) {
            /* The end of the 512-byte directory block this entry lives in.
             * An entry may not cross it, so this is the bound every length
             * below is checked against -- and the point the walk resumes from
             * if one is bad. */
            blkend = (off / DIRBLKSIZ) * DIRBLKSIZ + DIRBLKSIZ;
            if (blkend > avail)
                blkend = avail;

            /* A fresh 512-byte block: any run of free space started in the
             * previous one ends here and cannot be carried across. */
            if (slotstatus == SLOT_NONE && (off & (DIRBLKSIZ - 1)) == 0) {
                slotoffset    = (off_t)-1;
                slotfreespace = 0;
            }

            if (off + DIRHDRSIZ > blkend) {
                off = blkend;               /* no room for a header: skip on */
                continue;
            }
            e = (struct direct *)&bp->b_addr[off];
            reclen = (int)e->d_reclen;
            /* A length that is zero, unaligned, shorter than a header or past
             * the end of its own block is corrupt.  Resynchronise at the next
             * DIRBLKSIZ boundary rather than trusting it. */
            if (reclen < DIRHDRSIZ || (reclen & 3) != 0 ||
                off + reclen > blkend) {
                off = blkend;
                continue;
            }
            /* ...and a name that does not fit inside its own record is the
             * same kind of corruption, one level in. */
            if (DIRHDRSIZ + (int)e->d_namlen > reclen) {
                off = blkend;
                continue;
            }

            /* --- the slot search, upstream's :247-274 --------------------- */
            if (slotstatus != SLOT_FOUND) {
                size = reclen;
                if (e->d_ino != (ino_t)0)
                    size -= DIRSIZ((int)e->d_namlen);
                if (size > 0) {
                    if (size >= slotneeded) {
                        slotstatus = SLOT_FOUND;
                        slotoffset = base + (off_t)off;
                        slotsize   = reclen;
                    } else if (slotstatus == SLOT_NONE) {
                        slotfreespace += size;
                        if (slotoffset == (off_t)-1)
                            slotoffset = base + (off_t)off;
                        if (slotfreespace >= slotneeded) {
                            slotstatus = SLOT_COMPACT;
                            slotsize   = (int)((base + (off_t)off +
                                                (off_t)reclen) - slotoffset);
                        }
                    }
                }
            }

            if (e->d_ino != (ino_t)0 && ufs_dirmatch(e, nm, n)) {
                found = e->d_ino;
                if (ndp != (struct nameidata *)0) {
                    ndp->ni_offset       = base + (off_t)off;
                    ndp->ni_dent.d_ino    = e->d_ino;
                    ndp->ni_dent.d_reclen = e->d_reclen;
                    /* The distance back to the previous entry IN THIS BLOCK.
                     * Zero at a block boundary, which dirremove reads as "the
                     * first entry: clear d_ino instead of extending". */
                    if ((off & (DIRBLKSIZ - 1)) == 0)
                        ndp->ni_count = 0;
                    else
                        ndp->ni_count = (int)((base + (off_t)off) - prevoff);
                }
                break;
            }

            prevoff = base + (off_t)off;
            off = off + reclen;
            if (e->d_ino != (ino_t)0)
                enduseful = base + (off_t)off;
        }
        brelse(bp);
        if (found != (ino_t)0)
            return (found);
        base = base + (off_t)FS_BLKSIZE;
    }

    /* --- not found: describe where a new entry would go ------------------- */
    if (ndp != (struct nameidata *)0 && slotneeded != 0) {
        if (slotstatus == SLOT_NONE) {
            /* Nothing usable anywhere: the entry goes in a fresh directory
             * block at the end.  ROUNDED UP to DIRBLKSIZ, because direnter
             * writes a whole block and upstream panics ("wdir: newblk") if the
             * offset it is handed is not on a boundary. */
            ndp->ni_offset = (ip->i_size + (off_t)(DIRBLKSIZ - 1)) &
                             ~((off_t)(DIRBLKSIZ - 1));
            ndp->ni_count  = 0;
            enduseful      = ndp->ni_offset;
        } else {
            ndp->ni_offset = slotoffset;
            ndp->ni_count  = slotsize;
            if (enduseful < slotoffset + (off_t)slotsize)
                enduseful = slotoffset + (off_t)slotsize;
        }
        ndp->ni_endoff = (enduseful + (off_t)(DIRBLKSIZ - 1)) &
                         ~((off_t)(DIRBLKSIZ - 1));
    }
    return ((ino_t)0);
}


/* ufs_sticky -- may THIS caller unlink IP out of the sticky directory DP?
 *
 * 2.11BSD ufs_namei.c:621-628 and Reno ufs/ufs_lookup.c:421-427, which agree:
 * root always may, the directory's owner always may, and anyone else may only
 * take away a file that is already theirs.
 *
 * IT IS A FUNCTION RATHER THAN FOUR LINES INLINE FOR A MEASURED REASON.  The
 * uid it needs is a local, and a local in ufs_lookup is paid for by EVERY
 * lookup on the machine -- fcc sizes a frame once, for all of a function's
 * locals, and ufs_lookup sits in the deepest chain the boot walks.  Inline it
 * cost 6 bytes of the boot kernel stack: bootstk went from 52 bytes spare to
 * 46 against a floor of 48, which is apple/fgx#338's ratchet doing its job.
 * Out here the frame is entered only on the DELETE that needs it, and the
 * boot's lookups do not pay for a question they never ask.
 */
static int
ufs_sticky(dp, ip)
struct inode *dp;               /* the directory, carrying ISVTX */
struct inode *ip;               /* the name being taken out of it */
{
    int uid;

    uid = kc_curuid();
    if (uid == 0 || uid == dp->i_uid || ip->i_uid == uid)
        return (0);
    return (EPERM);
}


/* ufs_lookup -- the VOP_LOOKUP slot.  4.3BSD-Reno ufs/ufs_lookup.c:78-390,
 * reduced to the LOOKUP operation as the header explains.
 *
 * THE THREE-WAY SPLIT IS UPSTREAM'S: "." is this
 * vnode, ".." is a lock taken in the opposite direction, and everything else
 * is a scan.  They are separate arms because their LOCKING differs, not
 * because their searching does -- resolving "." by scanning would find the
 * right inode and then lock a vnode that is already locked.
 */
int
ufs_lookup(dvp, ndp)
struct vnode     *dvp;
struct nameidata *ndp;
{
    struct inode *dp;
    struct inode *ip;
    struct vnode *vp;
    char         *nm;
    int           n;
    int           lastcomponent;
    int           op;
    int           slotneeded;
    ino_t         ino;
    unsigned long vpid;         /* the cached vnode's capability number, read
                                 * before the lock wait and checked after */
    int           error;

    /* ni_dvp IS SET FIRST AND UNCONDITIONALLY -- Reno's ufs_lookup.c:95 does
     * `ndp->ni_dvp = vdp;` before anything can fail.
     * filesystem that leaves ni_dvp unset on an error path has it released
     * twice or not at all. */
    ndp->ni_dvp = dvp;
    ndp->ni_vp  = (struct vnode *)0;

    if (dvp->v_type != VDIR)
        return (ENOTDIR);

    /* IS THE DIRECTORY SEARCHABLE?  Reno's ufs/ufs_lookup.c:106-109, in that
     * order: the ENOTDIR test first, then VEXEC.  This is the check that makes
     * a mode mean anything for a PATH rather than for a file -- without it a
     * caller who may not enter a directory can still name what is inside it,
     * and every enforcement above this is decoration.
     *
     * UPSTREAM CALLS ufs_access DIRECTLY, not through VOP_ACCESS, and so does
     * this: the directory is this filesystem's own, so there is no vector to
     * dispatch through.  ufsdir.mod PUTs ufs_vnops.s beside this file, so the
     * call does not cross a bank.
     *
     * THE THREE VWRITE SITES ARE THE OTHER HALF and they are below, in the
     * arms that need them rather than beside this one: the CREATE/RENAME miss
     * (Reno ufs_lookup.c:321), and the DELETE and RENAME hits (:396, :441).
     * This one answers "may I look inside"; those answer "may I change what
     * is in here", and a directory can permit either without the other. */
    error = ufs_access(dvp, VEXEC, (char *)0);
    if (error)
        return (error);

    dp = VTOI(dvp);
    nm = ndp->ni_ptr;
    n  = (int)ndp->ni_namelen;
    op = ndp->ni_nameiop & OPMASK;
    lastcomponent = (*ndp->ni_next == '\0');

    /* ---- THE NAME CACHE, BEFORE THE SCAN --------------------------------
     * Reno's placement exactly (ufs/ufs_lookup.c:124): after the type and
     * VEXEC checks, because a cache must not answer a lookup the caller was
     * not allowed to make, and before everything else, because the scan below
     * reads directory blocks off the disk.
     *
     * THREE ANSWERS, NOT TWO.  ENOENT is a NEGATIVE hit -- the name is known
     * absent -- and returning it here is what stops a shell's PATH search
     * re-reading every directory for a command that is not in the first four.
     * Zero is a miss and falls through to the scan.  Anything else is a hit
     * with the vnode in ni_vp.
     *
     * THE HIT ARM HAS TO CLAIM THE VNODE, and that is all the length below is.
     * cache_lookup hands back a bare pointer: no reference, no lock.  What
     * this function promises is iget's post-condition -- ni_vp referenced and
     * LOCKED -- because lookup() unlocks it unless LOCKLEAF was asked for, so
     * a leaf returned unlocked would be unlocked twice.
     *
     * AND THE LOCK IS EXPLICIT, WHICH IS THIS TREE'S DIVERGENCE AND NOT AN
     * OVERSIGHT.  Reno's vget ends `VREF(vp); VOP_LOCK(vp);'
     * (kern/vfs_subr.c:440), so upstream's arm needs no lock of its own; this
     * tree's vget deliberately does not lock -- vfs_subr.c's checkalias
     * records the decision and the reason, "namei takes every directory lock
     * explicitly instead, and both would be a double lock".  So the VOP_LOCK
     * is written here, where upstream has it inside vget.
     *
     * WHICH IS ALSO WHY THE CAPABILITY NUMBER IS RE-READ.  VOP_LOCK sleeps on
     * ILOCKED, and a vnode can be reclaimed and re-minted while it sleeps.
     * v_id is captured BEFORE the wait and compared after; a change means the
     * thing now on the end of the pointer is a different file, so it is given
     * back and the scan runs after all.  Reno makes the same check for the
     * same window (ufs/ufs_lookup.c:144-147). */
    error = cache_lookup(ndp);
    if (error) {
        if (error == ENOENT)
            return (error);

        vp = ndp->ni_vp;
        vpid = vp->v_id;

        if (vp == dvp) {
            /* "." -- the answer is the directory we are already holding, so
             * there is nothing to claim and nothing to wait for.  Locking it
             * again would be this process locking an inode it holds, which
             * ufs_lock panics on by name. */
            vref(vp);
            return (0);
        }

        if (ndp->ni_isdotdot) {
            /* UPWARD, SO THE PARENT GOES FIRST.  Locking up the tree while
             * holding down it is the directory deadlock, and the miss arm
             * below releases in the same order for the same reason. */
            VOP_UNLOCK(dvp);
            error = vget(vp);
            if (error == 0) {
                VOP_LOCK(vp);
                if (vpid == vp->v_id) {
                    if ((ndp->ni_nameiop & LOCKPARENT) && lastcomponent)
                        VOP_LOCK(dvp);
                    return (0);
                }
                vput(vp);
            }
            VOP_LOCK(dvp);
        } else {
            error = vget(vp);
            if (error == 0) {
                VOP_LOCK(vp);
                if (vpid == vp->v_id) {
                    if ((ndp->ni_nameiop & LOCKPARENT) == 0 || !lastcomponent)
                        VOP_UNLOCK(dvp);
                    return (0);
                }
                vput(vp);
            }
        }

        /* THE ENTRY WAS STALE, or the vnode was being torn down and vget
         * refused.  Both mean "the cache cannot answer this"; the directory is
         * locked again and the scan below does the work. */
        ndp->ni_vp = (struct vnode *)0;
    }

    /* ---- "." IS NOT A SPECIAL CASE HERE, AND USED TO BE ------------------
     *
     * This arm answered "." from the vnode it was handed, without reading the
     * directory -- which is right for a LOOKUP and wrong for everything else,
     * because DELETE and RENAME need ni_offset, ni_count and ni_dent, and a
     * scan that never ran leaves all three holding the previous walk's.
     * dirremove would then write a cleared header at a stale offset.
     *
     * Reno has no such arm.  It scans "." like any other name and handles the
     * self-naming case at the DISPOSITION (ufs/ufs_lookup.c:487, "we want
     * ourself, ie `.`"), which is exactly what the `ino == dp->i_number` arm
     * below already does here.  Removing this one makes the two trees agree
     * and costs a LOOKUP of "." one directory read -- upstream's price.
     *
     * It also made two probe cases unable to fail: an assertion that a
     * directory "still scans", written as a lookup of ".", passed over any
     * block at all.
     */

    /* ---- ".." ---------------------------------------------------------
     * THE PARENT IS RELEASED BEFORE THE TARGET IS ACQUIRED.  Locking upward
     * while holding downward is the classic directory-tree deadlock, and every
     * other walk in the system takes these locks the other way; upstream says
     * so at the site ("race to get the inode") and accepts the race instead.
     *
     * WHAT ".." MEANS AT A MOUNT POINT OR AT THE ROOT IS NOT THIS FUNCTION'S
     * CALL.  ni_isdotdot exists so lookup() can decide whether going up also
     * means leaving this filesystem, and whether ".." must stop at "/".  Here
     * it is an ordinary entry read off the disk, exactly as it is on the
     * volume. */
    if (n == 2 && nm[0] == '.' && nm[1] == '.') {
        ino = ufs_dirscan(dvp, dp, nm, n, (struct nameidata *)0, 0, &error);
        if (ino == (ino_t)0)
            return (ENOENT);        /* a directory with no ".." is corrupt, and
                                     * ENOENT is the truthful answer to the
                                     * question that was asked */
        VOP_UNLOCK(dvp);
        error = iget(dvp->v_mount, ino, &ip);
        if (error) {
            /* The parent was unlocked above and the caller's error path
             * expects it locked, so put it back before failing. */
            VOP_LOCK(dvp);
            return (error);
        }
        vp = ITOV(ip);          /* iget hands it back LOCKED, which is the
                                 * contract: ni_vp comes back locked */
        ndp->ni_vp = vp;
        if ((ndp->ni_nameiop & LOCKPARENT) && lastcomponent)
            VOP_LOCK(dvp);
        if (ndp->ni_makeentry)
            cache_enter(ndp);
        return (0);
    }

    /* ---- an ordinary name --------------------------------------------- */
    /* SLOT TRACKING IS ONLY FOR THE OPERATION THAT WILL USE IT.  A scan asked
     * for a slot does strictly more work per entry, and a slot recorded for a
     * LOOKUP would be read by nothing -- while a slot NOT recorded for a
     * CREATE is what makes direnter write at offset zero.  slotneeded is the
     * size the new name actually needs, which is what lets the scan tell a
     * usable gap from one that is merely free.  Reno computes the same value
     * the same way and only under the same condition. */
    slotneeded = 0;
    if ((op == CREATE || op == RENAME) && lastcomponent)
        slotneeded = DIRSIZ(n);
    error = 0;
    ino = ufs_dirscan(dvp, dp, nm, n, ndp, slotneeded, &error);
    if (error)
        return (error);         /* a read failure, not a free name */
    if (ino == (ino_t)0) {
        /* THE MISS HAS TWO DISPOSALS AND THEY ARE OPPOSITE, and they are
         * upstream's rather than re-derived: a
         * LOOKUP or DELETE miss leaves the directory LOCKED because namei
         * treats it as an error and its `bad:` arm does the unlock, while a
         * CREATE or RENAME miss on the LAST component is not an error -- namei
         * returns 0 with a null ni_vp meaning "the name is free" -- so nobody
         * downstream will unlock it and the filesystem must, unless the caller
         * asked to keep it.  Reno: `if (!lockparent) IUNLOCK(dp);`. */
        /* A DIRECTORY THAT HAS BEEN REMOVED TAKES NO NEW NAMES.  Upstream
         * guards the create arm with `dp->i_nlink != 0` (ufs/ufs_lookup.c:316)
         * and it was dropped here without a word.  It costs one comparison,
         * and what it prevents is an entry written into a directory whose
         * blocks ufs_inactive is about to give back. */
        if (op != LOOKUP && op != DELETE && lastcomponent &&
            dp->i_nlink == 0)
            return (ENOENT);
        /* ACCESS FOR WRITE IS THE RIGHT TO PUT A NAME HERE.  Reno
         * ufs/ufs_lookup.c:321, whose comment is the rule itself -- "access
         * for write is interpreted as allowing creation of files in the
         * directory" -- and 2.11BSD asks the same at ufs_namei.c:510.
         *
         * IT RETURNS WITH THE DIRECTORY STILL LOCKED, which is upstream's
         * shape and this port's: an error out of VOP_LOOKUP is namei's `bad'
         * arm and that arm does the unlock.  Only the success path below
         * hands the lock back early, and only when LOCKPARENT is clear. */
        if (op != LOOKUP && op != DELETE && lastcomponent) {
            error = ufs_access(dvp, VWRITE, (char *)0);
            if (error)
                return (error);
        }
        if (op != LOOKUP && op != DELETE && lastcomponent &&
            (ndp->ni_nameiop & LOCKPARENT) == 0)
            VOP_UNLOCK(dvp);
        /* THE NAME IS KNOWN ABSENT, WHICH IS AN ANSWER AND WORTH KEEPING.
         * ni_vp is null here, and that is what cache_enter records as a
         * negative entry -- the one cache_lookup returns ENOENT for.  Reno
         * enters it at the same point and calls it out in the same words,
         * "insert name into cache (as non-existent) if appropriate"
         * (ufs/ufs_lookup.c:357-361).
         *
         * NOT ON THE i_nlink == 0 ARM ABOVE.  That directory has been removed
         * and is waiting for ufs_inactive; seeding the cache against a vnode
         * that is on its way out buys nothing, and cache_purge on the handout
         * is what would have to undo it. */
        if (ndp->ni_makeentry)
            cache_enter(ndp);
        return (ENOENT);
    }

    /* AND THE SAME RIGHT COVERS TAKING A NAME AWAY.  Reno asks VWRITE of the
     * parent for DELETE (ufs/ufs_lookup.c:396, "write access to directory
     * required to delete files") and again for the RENAME target (:441);
     * 2.11BSD's two are ufs_namei.c:593 and :669.
     *
     * BOTH SIT BEFORE THE SELF-REFERENCE ARM BELOW, which is upstream's order
     * and not an accident of this port's shape: :396 precedes Reno's
     * `dp->i_number == ndp->ni_dent.d_ino' at :408, and :441 precedes its
     * EISDIR at :447.  Asking afterwards would let `rm .' and `mv x .' answer
     * before anyone had been asked for permission.
     *
     * WANTPARENT GATES THE RENAME HALF, upstream's own `flag == RENAME &&
     * wantparent' (:440): a rename that does not ask for the parent back is
     * not the caller that rewrites an entry in it.  Upstream's `wantparent' is
     * LOCKPARENT OR WANTPARENT (:101, `ndp->ni_nameiop & (LOCKPARENT|
     * WANTPARENT)'), and rename(2)'s target walk asks for LOCKPARENT. */
    if (lastcomponent &&
        (op == DELETE ||
         (op == RENAME &&
          (ndp->ni_nameiop & (LOCKPARENT | WANTPARENT)) != 0))) {
        error = ufs_access(dvp, VWRITE, (char *)0);
        if (error)
            return (error);
    }

    /* A DIRECTORY THAT CONTAINS ITSELF UNDER ANOTHER NAME would deadlock the
     * iget below against the lock this vnode already holds.  It cannot happen
     * on a well-formed volume -- only "." names its own directory -- but this
     * volume was written by another implementation, and upstream has the same
     * arm for the same reason. */
    if (ino == dp->i_number) {
        /* RENAMING ONTO "." IS EISDIR, and upstream tests it exactly here for
         * the reason its comment gives -- "careful about locking second
         * inode, this can only occur if the target is `.`"
         * (ufs/ufs_lookup.c:445-446).  Without it rename would be handed the
         * directory it is renaming INTO as the thing being replaced. */
        if (op == RENAME && lastcomponent)
            return (EISDIR);
        ndp->ni_vp = dvp;
        vref(dvp);
        if (ndp->ni_makeentry)
            cache_enter(ndp);
        return (0);
    }

    error = iget(dvp->v_mount, ino, &ip);
    if (error)
        return (error);
    vp = ITOV(ip);                  /* LOCKED by iget -- the contract is that
                                     * ni_vp comes back locked, and iget is
                                     * where this tree takes it */

    /* THE STICKY BIT, AND IT IS WHAT MAKES A 1777 /tmp SAFE.  In a directory
     * carrying ISVTX a caller may unlink only a name it owns, or any name if
     * it owns the directory; root is exempt.  2.11BSD ufs_namei.c:621-628,
     * whose comment is the rule -- "if directory is sticky, then user must
     * own the directory, or the file in it, else he may not delete it (unless
     * he's root).  This implements append-only directories."
     *
     * RENO'S PLACEMENT RATHER THAN 2.11BSD's.  2.11BSD reaches the test only
     * under `lockparent', because that is the only arm in which it igets the
     * target at all; this port igets on every hit, as Reno does (:413-427),
     * so the test sits with the iget and covers the caller that did not ask
     * to keep the parent.  THE SELF-REFERENCE CASE CANNOT REACH HERE -- it
     * returned above -- which is upstream too: `rm .' never gets a second
     * inode to compare owners with.
     *
     * ni_vp IS STILL NULL AT THIS POINT, deliberately: the assignment below
     * is Reno's `ndp->ni_vp = ITOV(tdp)' at :428, AFTER the refusal, so the
     * iput here is the only release this vnode needs. */
    if (op == DELETE && lastcomponent && (dp->i_mode & ISVTX) != 0 &&
        ufs_sticky(dp, ip) != 0) {
        iput(ip);
        return (EPERM);
    }

    ndp->ni_vp = vp;

    /* WHO UNLOCKS THE PARENT IS THE FILESYSTEM'S CALL -- VOP_LOOKUP returns
     * ni_dvp "unlocked unless LOCKPARENT set", and only the filesystem knows
     * whether the operation being set up still needs the directory.  ONLY THE
     * LAST COMPONENT COUNTS: LOCKPARENT asks for the parent of the FINAL name,
     * and an intermediate directory is released as the walk advances. */
    if ((ndp->ni_nameiop & LOCKPARENT) == 0 || !lastcomponent)
        VOP_UNLOCK(dvp);
    /* AND REMEMBER IT.  Reno's closing two lines (ufs/ufs_lookup.c:497-501),
     * and the gate is upstream's: ni_makeentry is namei's decision, not this
     * function's -- it is clear for the last component of a DELETE or a
     * RENAME, because the name is about to stop meaning what it means now. */
    if (ndp->ni_makeentry)
        cache_enter(ndp);
    return (0);
}


/* ufs_dircopy -- move `n` bytes of directory record, SOURCE FIRST.
 *
 * Upstream writes `bcopy(src, dst, n)`; kernel C links no libkern and this
 * tree's other ports open-code the same loop (ufs_iencode's field list,
 * clrbuf).  The argument order is bcopy's deliberately, because these call
 * sites are being read against upstream's and a reversed copy that still
 * compiles is the kind of thing a directory survives just long enough to be
 * mysterious about.
 *
 * IT IS A FORWARD BYTE COPY AND THE COMPACTION LOOP RELIES ON THAT: it slides
 * records TOWARDS THE FRONT, so destination is always below source and the
 * regions may overlap.  A backward copy would be wrong here; memmove's
 * generality is not needed, but the direction is. */
static void
ufs_dircopy(src, dst, n)
struct direct *src;
struct direct *dst;
int            n;
{
    char *s;
    char *d;
    int   i;

    s = (char *)src;
    d = (char *)dst;
    for (i = 0; i < n; i++)
        d[i] = s[i];
}


/* ufs_blkatoff -- the buffer holding a directory's byte `offset`, and a
 * pointer into it.  4.3BSD-Reno ufs/ufs_lookup.c's blkatoff.
 *
 * Upstream's takes a `bsize` from blksize() because an FFS directory's last
 * block may be a fragment; there are no fragments here, so a directory block
 * is always FS_BLKSIZE and the argument goes away with it.
 */
static int
ufs_blkatoff(ip, offset, res, bpp)
struct inode  *ip;
off_t          offset;
char         **res;
struct buf   **bpp;
{
    struct buf *bp;
    int         error;

    *bpp = (struct buf *)0;
    error = bread(ITOV(ip), lblkno(offset), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }
    if (res != (char **)0)
        *res = &bp->b_addr[(int)blkoff(offset)];
    *bpp = bp;
    return (0);
}


/* ufs_direnter -- write the entry ufs_lookup found room for.  UFS 1.12c.
 *
 * IT DOES NOT RELEASE THE DIRECTORY AND UPSTREAM'S DOES.  Reno's ends with
 * `iput(dp)`, which is why its maknode sets `pdir = NULL` before its error arm
 * -- direnter has already given the reference back.  Nothing in this tree
 * consumes ni_dvp; the caller owns it from namei to the end of the operation.
 * ufs_vnops.c's ufs_rmdir header is the long version, written there because
 * that is where transcribing upstream's releases literally first panics.
 *
 * 4.3BSD-Reno ufs/ufs_lookup.c:549-658.  IT DOES NOT SEARCH: everything it
 * needs was recorded by the scan that failed to find the name, and re-scanning
 * here would be a second implementation of the same rules -- which is exactly
 * how a directory ends up with two entries for one name.
 *
 * THE TWO CASES ARE ni_count == 0 AND NOT, and they are genuinely different
 * operations rather than a fast path and a slow one:
 *
 *   ni_count == 0 means the scan found NO usable space, so the entry goes into
 *   a FRESH directory block at the end.  The record is written with d_reclen
 *   spanning the whole DIRBLKSIZ, because it is the only entry there and the
 *   free space after it belongs to it.  This is the only path that GROWS the
 *   directory, and it grows it through ufs_write -- which allocates the block,
 *   clears it and extends i_size, none of which this function should be doing
 *   itself.
 *
 *   ni_count != 0 means the entry goes in the run at ni_offset, which may need
 *   COMPACTING first: the scan may have found several adjacent records whose
 *   free space is only sufficient added together.  The loop slides the live
 *   ones towards the front, and what it leaves at the end is one usable gap.
 *
 * THE COMPACTION LOOP IS UPSTREAM'S, AND ITS SUBTLETY IS `dsize`: each record
 * is trimmed to the size its NAME needs (DIRSIZ) rather than the size it
 * currently claims (d_reclen), which is what releases the slack.  A record
 * whose d_ino is zero contributes its whole length instead, because nothing in
 * it needs keeping.  Getting that backwards produces a directory that still
 * parses and has lost an entry.
 *
 * IT ENDS BY TRUNCATING THE TAIL, which is upstream's line and is not
 * housekeeping: the scan reported ni_endoff as the point past which the
 * directory holds nothing useful, and a directory that keeps growing without
 * ever shrinking is how a long-lived one ends up mostly empty blocks.
 *
 * NOTE WHAT IT DOES NOT DO: it does not iput(dp).  Reno's does, because its
 * callers hand ownership over; here every caller holds the directory across
 * the call and releases it itself, which keeps the reference discipline
 * visible at the site that took the reference.
 */
int
ufs_direnter(ip, ndp)
struct inode     *ip;
struct nameidata *ndp;
{
    struct inode  *dp;
    struct direct *ep;
    struct direct *nep;
    struct buf    *bp;
    struct uio     u;
    struct iovec   iov;
    char          *dirbuf;
    int            loc;
    int            spacefree;
    int            dsize;
    int            newentrysize;
    int            error;

    dp = VTOI(ndp->ni_dvp);
    ndp->ni_dent.d_ino = ip->i_number;
    newentrysize = DIRSIZ((int)ndp->ni_dent.d_namlen);

    if (ndp->ni_count == 0) {
        /* A FRESH BLOCK AT THE END.  The offset must be on a DIRBLKSIZ
         * boundary or the record would start mid-block and every later scan
         * would resynchronise past it; the scan rounds up for exactly this
         * reason, and upstream panics here rather than write it. */
        if ((ndp->ni_offset & (off_t)(DIRBLKSIZ - 1)) != 0L)
            kc_panic("direnter: newblk");
        ndp->ni_dent.d_reclen = (unsigned short)DIRBLKSIZ;

        iov.iov_base = (char *)&ndp->ni_dent;
        iov.iov_len  = newentrysize;
        u.uio_iov    = &iov;
        u.uio_iovcnt = 1;
        u.uio_offset = ndp->ni_offset;
        u.uio_resid  = (unsigned short)newentrysize;
        u.uio_segflg = UIO_SYSSPACE;
        u.uio_rw     = UIO_WRITE;
        error = ufs_write(ndp->ni_dvp, &u, IO_SYNC, (char *)0);

        /* THE DIRECTORY'S SIZE IS ROUNDED UP TO THE WHOLE BLOCK, not left at
         * the end of the record just written.  The rest of that block is free
         * space belonging to this entry's d_reclen, and a scan walks to
         * i_size: leaving it short would make the next direnter believe the
         * block was full. */
        dp->i_size = (dp->i_size + (off_t)(DIRBLKSIZ - 1)) &
                     ~((off_t)(DIRBLKSIZ - 1));
        dp->i_flag |= ICHG | IUPD;
        return (error);
    }

    /* Upstream's "artifact of 4.2 and should never happen", carried because it
     * costs one comparison and its absence would be a silent overrun. */
    if (ndp->ni_offset + (off_t)ndp->ni_count > dp->i_size)
        dp->i_size = ndp->ni_offset + (off_t)ndp->ni_count;

    error = ufs_blkatoff(dp, ndp->ni_offset, &dirbuf, &bp);
    if (error)
        return (error);

    ep = (struct direct *)dirbuf;
    dsize = DIRSIZ((int)ep->d_namlen);
    if (ep->d_ino == (ino_t)0)
        dsize = 0;                      /* a dead record keeps nothing */
    spacefree = (int)ep->d_reclen - dsize;
    for (loc = (int)ep->d_reclen; loc < ndp->ni_count; ) {
        nep = (struct direct *)&dirbuf[loc];
        if (ep->d_ino != (ino_t)0) {
            /* Trim the live record to what its name needs and step past it. */
            ep->d_reclen = (unsigned short)dsize;
            ep = (struct direct *)((char *)ep + dsize);
        } else {
            /* Nothing there: its header is ours to overwrite. */
            spacefree += dsize;
        }
        dsize = DIRSIZ((int)nep->d_namlen);
        if (nep->d_ino == (ino_t)0)
            dsize = 0;
        spacefree += (int)nep->d_reclen - dsize;
        loc += (int)nep->d_reclen;
        if (dsize != 0)
            ufs_dircopy(nep, ep, dsize);
    }

    if (ep->d_ino == (ino_t)0) {
        if (spacefree + dsize < newentrysize)
            kc_panic("direnter: compact1");
        ndp->ni_dent.d_reclen = (unsigned short)(spacefree + dsize);
    } else {
        if (spacefree < newentrysize)
            kc_panic("direnter: compact2");
        ndp->ni_dent.d_reclen = (unsigned short)spacefree;
        ep->d_reclen = (unsigned short)dsize;
        ep = (struct direct *)((char *)ep + dsize);
    }
    ufs_dircopy(&ndp->ni_dent, ep, newentrysize);
    error = bwrite(bp);
    dp->i_flag |= ICHG | IUPD;

    /* Give the tail back.  ni_endoff is where the scan found the useful
     * contents to stop. */
    if (error == 0 && ndp->ni_endoff != 0L && ndp->ni_endoff < dp->i_size)
        error = ufs_itrunc(dp, ndp->ni_endoff, IO_SYNC, (long *)0);
    return (error);
}


/* ufs_dirremove -- take the entry ufs_lookup found out of its directory.
 *
 * 4.3BSD-Reno ufs/ufs_lookup.c:674-706, whose header is the clearest statement
 * of why ni_count means what it means here:
 *
 *     The ni_count field contains the size of the previous record in the
 *     directory.  If this is 0, the first entry is being deleted, so we need
 *     only zero the inode number to mark the entry as free.  If the entry
 *     isn't the first in the directory, we must reclaim the space of the now
 *     empty record by adding the record size to the size of the previous
 *     entry.
 *
 * SO A DELETED NAME LEAVES ITS RECORD BEHIND.  Nothing is moved and nothing is
 * shortened; either a d_ino of zero marks the record dead, or the record
 * vanishes into its predecessor's d_reclen.  That is why every scan in this
 * file steps by d_reclen and treats d_ino == 0 as free space rather than as
 * the end of the directory.
 */
int
ufs_dirremove(ndp)
struct nameidata *ndp;
{
    struct inode  *dp;
    struct direct *ep;
    struct buf    *bp;
    struct uio     u;
    struct iovec   iov;
    int            error;

    dp = VTOI(ndp->ni_dvp);

    if (ndp->ni_count == 0) {
        /* First in its block: mark it free in place.  Only the header is
         * rewritten, and d_reclen is left exactly as it was so the record
         * still spans the space it owns. */
        ndp->ni_dent.d_ino = (ino_t)0;
        iov.iov_base = (char *)&ndp->ni_dent;
        iov.iov_len  = DIRHDRSIZ;
        u.uio_iov    = &iov;
        u.uio_iovcnt = 1;
        u.uio_offset = ndp->ni_offset;
        u.uio_resid  = (unsigned short)DIRHDRSIZ;
        u.uio_segflg = UIO_SYSSPACE;
        u.uio_rw     = UIO_WRITE;
        error = ufs_write(ndp->ni_dvp, &u, IO_SYNC, (char *)0);
        dp->i_flag |= ICHG | IUPD;
        return (error);
    }

    /* Otherwise fold the record into the one before it. */
    error = ufs_blkatoff(dp, ndp->ni_offset - (off_t)ndp->ni_count,
                         (char **)&ep, &bp);
    if (error)
        return (error);
    ep->d_reclen = (unsigned short)((int)ep->d_reclen +
                                    (int)ndp->ni_dent.d_reclen);
    error = bwrite(bp);
    dp->i_flag |= ICHG | IUPD;
    return (error);
}


/* ufs_dirempty -- is this directory empty apart from "." and ".."?
 *
 * 4.3BSD-Reno ufs/ufs_lookup.c:763-806 (`dirempty`).  rmdir is its only
 * caller and the answer has to be exact in one direction: saying EMPTY of a
 * directory that is not detaches every name inside it, and nothing else in the
 * system will ever go looking for them again.
 *
 * UPSTREAM READS EACH ENTRY WITH vn_rdwr AND A struct dirtemplate; this walks
 * the blocks with ufs_blkatoff, which is what every other scan in this file
 * does and what the buffer cache is already holding.  The rules it applies are
 * upstream's, in upstream's order, and the ORDER is the substance: a record
 * with d_reclen 0 would loop forever, a d_ino of 0 is free space and skipped,
 * a name longer than two bytes ends it, and of the remaining two lengths only
 * ".." pointing at the RIGHT parent is accepted.
 *
 * "does not handle corrupted directories" is upstream's own note.  It holds
 * here too: a reclen that steps out of its block is refused by the caller's
 * scan, not by this.
 */
int
ufs_dirempty(ip, parentino)
struct inode *ip;
ino_t         parentino;
{
    struct direct *e;
    struct buf    *bp;
    char          *base;
    char          *nm;
    off_t          off;
    int            reclen;
    int            error;

    off = (off_t)0;
    while (off < ip->i_size) {
        error = ufs_blkatoff(ip, off, &base, &bp);
        if (error) {
            brelse(bp);
            return (0);
        }
        e      = (struct direct *)base;
        reclen = (int)e->d_reclen;
        nm     = base + DIRHDRSIZ;

        /* A zero-length record would never advance the offset.  Upstream's
         * "avoid infinite loops", and the only one of these tests that is
         * about this code rather than about the directory. */
        if (reclen == 0) {
            brelse(bp);
            return (0);
        }
        if (e->d_ino == (ino_t)0) {
            brelse(bp);
            off = off + (off_t)reclen;
            continue;                   /* free space, not an entry */
        }
        if ((int)e->d_namlen > 2 || nm[0] != '.') {
            brelse(bp);
            return (0);
        }
        /* d_namlen is 1 or 2 here.  1 is "."; 2 is ".." only if the second
         * byte is a dot AND it names the parent this rmdir came through --
         * upstream tests both, because a two-byte name beginning with a dot
         * is not necessarily "..", and a ".." pointing somewhere else is a
         * directory this rmdir has no business emptying. */
        if ((int)e->d_namlen == 2 &&
            (nm[1] != '.' || e->d_ino != parentino)) {
            brelse(bp);
            return (0);
        }
        brelse(bp);
        off = off + (off_t)reclen;
    }
    return (1);
}


/* ufs_checkpath -- is `source` an ancestor of `target`?
 *
 * 4.3BSD-Reno ufs/ufs_lookup.c:813-861 (`checkpath`).  rename is its only
 * caller and it exists to refuse ONE operation: moving a directory into its
 * own subtree.  `mv a a/b/c` would leave a, b and c naming each other in a
 * ring with nothing outside pointing in -- every file under them alive, in
 * use, and unreachable from the root, which no fsck can undo because there is
 * no record of where they were.
 *
 * IT WALKS ".." UPWARD, one directory at a time, until it reaches the root or
 * finds the source.  That is the only way to ask the question: the answer is
 * about the PATH between two inodes and neither inode knows it.
 *
 * TWO DIVERGENCES FROM UPSTREAM, both stated:
 *
 *   - Reno CONSUMES the target's reference (its header says "the target is
 *     always iput() before returning") because its caller has just handed
 *     over a locked inode.  This one releases only what it acquires itself,
 *     which is this tree's contract everywhere in the directory layer -- see
 *     ufs_rmdir's header in ufs_vnops.c.
 *   - THE WALK HOLDS REFERENCES AND NOT LOCKS, which is the third divergence
 *     and the one 1.12d forced.  Reno's ancestors arrive locked because its
 *     iget locks, and it gets away with that because of a detail one function
 *     further out: its rename takes the SOURCE's parent with WANTPARENT, not
 *     LOCKPARENT (kern/vfs_syscalls.c's rename, `DELETE | WANTPARENT |
 *     SAVESTART`), so fdvp is referenced and unlocked while tdvp is locked.
 *     This walk goes UPWARD from tdvp, and the first directory it can meet
 *     that the caller already holds is exactly fdvp -- unlocked there, locked
 *     here, because this tree's ufs_rename re-finds the source with a direct
 *     VOP_LOOKUP on ni_dvp instead of re-walking with namei, and a direct
 *     VOP_LOOKUP needs its parent locked.
 *
 *     So an ancestor lock here would deadlock the ORDINARY case -- `mv a/b
 *     a/c/b` -- and not merely a corrupt one.  It is not a lock this walk
 *     needs: it reads block 0 of each ancestor through bread, which is safe
 *     on its own, and the race it accepts (an ancestor mid-rename) is the one
 *     ufs_lookup's ".." arm accepts three hundred lines above, for the same
 *     reason and with the same upstream blessing.
 *
 *     Never two ancestors at once either way: each is released before the
 *     next is taken.
 *   - Reno finds ".." at a hardcoded offset of 12, its DIRSIZ(1).  This
 *     follows "."'s own d_reclen instead.  On a directory either tree would
 *     write they are the same number; on any other, the hardcoded one reads a
 *     field that is not there.
 */
int
ufs_checkpath(source, target)
struct inode *source;
struct inode *target;
{
    struct inode  *ip;
    struct inode  *nip;
    struct direct *e;
    struct buf    *bp;
    struct mount  *mp;
    char          *nm;
    ino_t          dotdot;
    int            dotlen;
    int            owned;
    int            error;

    error = 0;
    ip    = target;
    owned = 0;                          /* 1 => `ip` is ours to release */
    mp    = ITOV(target)->v_mount;

    if (ip->i_number == source->i_number)
        return (EEXIST);
    if (ip->i_number == (ino_t)UFS_ROOTINO)
        return (0);

    for (;;) {
        if ((ip->i_mode & IFMT) != IFDIR) {
            error = ENOTDIR;
            break;
        }
        error = bread(ITOV(ip), (daddr_t)0, &bp);
        if (error) {
            brelse(bp);
            break;
        }
        e = (struct direct *)&bp->b_addr[0];
        /* THE STEP IS BOUNDED.  "."'s d_reclen comes off the platter, so an
         * unchecked one indexes up to 64K past a 1024-byte buffer -- where
         * Reno's fixed offset of 12 merely read the wrong field.  Following
         * the record is still the better rule; refusing an impossible one is
         * what makes it safe. */
        dotlen = (int)e->d_reclen;
        if (dotlen < DIRHDRSIZ || (dotlen & 3) != 0 ||
            dotlen + DIRHDRSIZ > FS_BLKSIZE) {
            brelse(bp);
            error = ENOTDIR;
            break;
        }
        e = (struct direct *)&bp->b_addr[dotlen];
        nm = (char *)e + DIRHDRSIZ;
        if ((int)e->d_namlen != 2 || nm[0] != '.' || nm[1] != '.') {
            brelse(bp);
            error = ENOTDIR;            /* upstream's ".. not a directory" */
            break;
        }
        dotdot = e->d_ino;
        brelse(bp);

        if (dotdot == source->i_number) {
            error = EINVAL;             /* the source IS above the target */
            break;
        }
        if (dotdot == (ino_t)UFS_ROOTINO)
            break;                      /* reached the root without meeting it */

        if (owned)
            vrele(ITOV(ip));
        owned = 0;
        error = iget(mp, dotdot, &nip);
        if (error)
            break;
        /* THE LOCK GOES BACK AND THE REFERENCE STAYS -- see the header. */
        VOP_UNLOCK(ITOV(nip));
        ip    = nip;
        owned = 1;
    }

    if (owned)
        vrele(ITOV(ip));
    return (error);
}


/* ufs_dirrewrite -- point an existing entry at a different inode.
 *
 * 4.3BSD-Reno ufs/ufs_lookup.c:712-722.  rename(2) is its only caller
 * upstream, and it is written now because the entry's LOCATION comes from the
 * same scan the other two use and belongs beside them.
 *
 * ONLY THE HEADER IS REWRITTEN.  The name is already correct -- it is the name
 * that was looked up -- so d_namlen and the bytes after it stay as they are,
 * and d_reclen must too or the record would stop matching its neighbours.
 */
int
ufs_dirrewrite(dp, ip, ndp)
struct inode     *dp;
struct inode     *ip;
struct nameidata *ndp;
{
    struct uio   u;
    struct iovec iov;

    ndp->ni_dent.d_ino = ip->i_number;
    iov.iov_base = (char *)&ndp->ni_dent;
    iov.iov_len  = DIRHDRSIZ;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = ndp->ni_offset;
    u.uio_resid  = (unsigned short)DIRHDRSIZ;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    return (ufs_write(ITOV(dp), &u, IO_SYNC, (char *)0));
}
