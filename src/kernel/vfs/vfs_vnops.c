/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/vfs_vnops.c
 *   Ported from kern/vfs_vnops.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* vfs_vnops.c -- the glue between a `struct file` and a vnode.  UFS 1.7c.
 *
 * THIS IS THE LAYER THE VFS HAS BEEN MISSING A CUSTOMER FOR.  Everything under
 * it works and is exercised: namei walks (1.6b), UFS reads and writes (1.11,
 * 1.12), device files open and reach real drivers (1.13a, 1.13b), and the open
 * file table exists with its allocator (1.2c).  What has never existed is the
 * piece that turns "a path and a mode" into "a file struct with a vnode in it",
 * and it is why src/kernel/main.s says the inward seam "returns when namei
 * gives the VFS a syscall-path customer, shaped by that customer".  These are
 * the functions that customer calls.
 *
 * THE SYSCALL LAYER IS NOT HERE, AND THAT IS THE SPLIT.  1.7c is the vnode
 * half -- pure kernel C inside vfs.mod, driven by a probe, touching no
 * dispatcher.  Wiring open(2)/read(2)/write(2)/close(2) onto it is 1.7d, and
 * doing both at once would mean debugging a port and a dispatcher change
 * through one symptom.  Until 1.7d lands, the FCB is still what open(2) fills
 * in and file.h's "NOTHING WRITES THIS TABLE FROM A SYSCALL YET" stays true.
 *
 *----------------------------------------------------------------------------
 * WHAT IS NOT CARRIED FROM UPSTREAM, each with its reason.  The campaign's
 * rule is to name a gap rather than let it be rediscovered as a bug:
 *
 *   THE ACCESS CHECKS ARE CARRIED as of UFS 2.6 (apple/fgx#320) and this
 *   entry is kept as the record of what they were waiting for.  While
 *   `ufs_access' was `ufs_enotsup' the calls were omitted rather than
 *   commented out, because porting them would have failed EVERY open with
 *   ENOTSUP.  THE COUNT HERE SAID THREE AND RENO HAS TWO -- VREAD for a read
 *   open and VWRITE for a write or truncate open, kern/vfs_vnops.c -- which is
 *   what reading the function rather than remembering it settled.  namei's own
 *   VOP_ACCESS is a separate site and is still absent; see vfs_lookup.c.
 *
 *   xrele IN vn_writechk.  Reno drops a shared-text reference and retries
 *   before refusing an ETXTBSY.  There is no vnode-backed shared text here --
 *   nothing in the tree sets VTEXT, which is why the flag test is kept as ONE
 *   test rather than upstream's two: without the xrele between them the second
 *   can only agree with the first.
 *
 *   vn_ioctl AND vn_select ARRIVE IN 1.7d, AND THE 1.7c NOTE THAT SAID THEY
 *   SHOULD NOT IS ANSWERED RATHER THAN DELETED.  It said "a vn_ioctl built now
 *   would be a wrapper around a panic", which is true and is not the same as
 *   saying the wrapper is wrong.  The panic is spec_ioctl's, it is deliberate
 *   (spec_vnops.c), and it stays exactly where 1.13b put it: these two carry
 *   the caller's arguments to VOP_IOCTL/VOP_SELECT and decide nothing.  For a
 *   regular file they reach ufs_enotsup; for a device they reach the panic.
 *   Both are what an ioctl on such an fd does TODAY by the other route, so
 *   porting them changes no behaviour and invents no policy.
 *
 *   THE MARSHALLING DECISION IS STILL OPEN and still belongs to a caller:
 *   ioctl's `data` is a pointer into the CALLER's bank and select's `which` is
 *   a per-process wait record.  Neither is settled here, because nothing here
 *   dereferences either -- they are passed through.  What settles them is the
 *   descriptor conversion (plan I2), which is the first thing that routes a
 *   real ioctl(2) down this vector.
 *
 *   vn_lock AND vn_unlock, and with them FSHLOCK/FEXLOCK.  These are flock(2)
 *   advisory locking, which does not exist here.  vn_close's upstream test for
 *   those two bits goes with them -- see file.h for why carrying the constants
 *   without their setter is worse than not carrying them.
 *
 *   vn_stat.  It converts a vattr into a `struct stat`, which is the syscall
 *   layer's shape rather than the vnode layer's, and vnode.h's vattr note
 *   already parks two decisions there (va_bytes, and what st_blocks reports
 *   when the 2.11BSD dinode carries no block count).  It belongs with the
 *   syscall that asks for it, in 1.7d.
 *
 *   vn_fhtovp.  NFS file handles.  The campaign has no goal for NFS.
 *
 *   THE fileops VECTOR.  Reno's `struct fileops vnops = { vn_read, vn_write,
 *   vn_ioctl, vn_select, vn_close }` exists so its syscalls can dispatch
 *   through fp->f_ops.  Nothing dispatches that way yet -- FGX classifies on
 *   f_type through the ladder 1.2a built -- so the vector arrives in 1.7d with
 *   the code that reads it.  file.h says f_ops is "somewhere for 1.7 to put
 *   vnops"; putting it there ahead of its reader would leave an entry in a
 *   table nothing checks, which vnode.h's VATTR_NULL note argues against for
 *   the same reason.
 *
 *   CREDENTIALS.  Every `struct ucred *cred` argument upstream is passed here
 *   as `(char *)0`, at Reno's argument position, exactly as namei.h's ni_cred
 *   and file.h's f_cred are carried.  The null is PERMANENT: this kernel takes
 *   2.11BSD's credential model, where the ids are the running process's and
 *   are read from the u-area rather than handed down a call chain.  file.h's
 *   f_cred note is the canonical statement.  The argument position is kept so
 *   the call shape is still upstream's and a diff against Reno reads.
 */

#include "fsparam.h"
#include "vnode.h"
#include "mount.h"
#include "namei.h"
#include "file.h"
#include "uio.h"
#include "dir.h"     /* DIRBLKSIZ -- readdir's alignment IS its interface */
#include "vfsops.h" /* VFS_STATFS -- statfs(2) dispatches, so it lives here */

extern int  namei();
/* DECLARED, AND K&R C IS WHY.  An undeclared function defaults to returning
 * `int' -- 16 bits here -- and ndslot returns a POINTER, so without this the
 * nameidata address arrives truncated and namei walks from nowhere.  It fails
 * silently: the call compiles, and vfs_listdir merely reported that it could
 * not resolve a path that exists. */
extern struct nameidata *ndslot();
extern void vrele();
extern void vput();
extern struct vnode *vfs_cdir();  /* DECLARED PER TU: apple/fgx#293 -- an
                                   * untyped extern would truncate the
                                   * pointer to a 16-bit int */


/* vattr_null -- Reno's VATTR_NULL (sys/vnode.h:265, `*(vap) = va_null`).
 *
 * IT ARRIVES NOW BECAUSE IT FINALLY HAS A CALLER.  vnode.h's note explains why
 * it was left out at 1.11b: upstream's callers are create, mkdir and chmod --
 * all write path -- and adding it early would have cost a cross-module shim
 * for a function nothing called.  vn_open is one of those callers, and it is
 * in vfs.mod beside this, so the shim the note worried about is not needed:
 * ufs.mod is not involved.
 *
 * A FILESYSTEM SETS WHAT IT KNOWS AND SKIPS WHAT IS VA_UNSET, so the fill has
 * to reach EVERY field.  Upstream gets that from a structure assignment out of
 * a zeroed-then-VNOVAL'd global; this assigns them one at a time because a
 * kernel-C global that needs initialising is the shape apple/fgx#88 rejects.
 * Missing one field here does not fail loudly -- it hands the filesystem a
 * stale value from the caller's stack and asks it to honour it. */
void
vattr_null(vap)
struct vattr *vap;
{
    vap->va_type      = VNON;
    vap->va_mode      = (unsigned short)VA_UNSET;
    vap->va_nlink     = (short)VA_UNSET;
    vap->va_uid       = (uid_t)VA_UNSET;
    vap->va_gid       = (gid_t)VA_UNSET;
    vap->va_fsid      = (long)VA_UNSET;
    vap->va_fileid    = (long)VA_UNSET;
    vap->va_size      = (off_t)VA_UNSET;
    vap->va_blocksize = (long)VA_UNSET;
    vap->va_atime     = (time_t)VA_UNSET;
    vap->va_mtime     = (time_t)VA_UNSET;
    vap->va_ctime     = (time_t)VA_UNSET;
    vap->va_flags     = (unsigned short)VA_UNSET;
    vap->va_rdev      = (dev_t)VA_UNSET;
}


/* vn_writechk -- may this vnode be written?  4.3BSD-Reno kern/vfs_vnops.c:130.
 *
 * A DEVICE ON A READ-ONLY FILESYSTEM IS STILL WRITABLE, which is the whole
 * point of the v_type exclusions: MNT_RDONLY is a statement about the medium,
 * and writing /dev/console does not write the medium.  Getting this wrong
 * makes a read-only /dev useless, which is precisely the mount 1.13c wants.
 * VSOCK is in upstream's list and kept here even though FGX has no vnode
 * sockets -- dropping a term from a condition is how the condition stops
 * meaning what its name says. */
int
vn_writechk(vp)
struct vnode *vp;
{
    if ((vp->v_mount->mnt_flag & MNT_RDONLY) &&
        vp->v_type != VCHR && vp->v_type != VBLK && vp->v_type != VSOCK)
        return (EROFS);
    /* ONE TEST, NOT UPSTREAM'S TWO -- see this file's head: with no xrele
     * between them the second could only repeat the first.  Nothing in this
     * tree sets VTEXT today, so this cannot fire; it is kept because the day
     * something does, its absence would be a silently writable text file. */
    if (vp->v_flag & VTEXT)
        return (ETXTBSY);
    return (0);
}


/* vn_mknode / vn_trunc0 -- vn_open's two vattr users, split out of its frame.
 *
 * THIS IS A STACK-DEPTH SPLIT AND NOT A CLEANUP, and it is a deliberate
 * divergence from upstream: 4.3BSD-Reno's vn_open declares `struct vattr vat'
 * in its own frame and uses it from both arms (kern/vfs_vnops.c).  A VAX has
 * room for that.  A per-pid kernel stack here is 512 bytes -- FGX_KSTK_SIZE,
 * and it cannot grow, because the pid-to-offset conversion is a hand-coded
 * XBA+ASL guarded by `ERR FGX_KSTK_SIZE-512' at every site, so the only legal
 * larger size is 1024 and that would take NPROC from 12 to 5.
 *
 * struct vattr is FORTY-TWO BYTES and vn_open is on the deepest chain the
 * kernel reaches: every process on this machine is execve'd, exec opens its
 * binary, and that open crosses core -> far -> core -> far -> module.  Which
 * is why all eleven live slices measured the SAME high-water to the byte --
 * they all run this one chain (apple/fgx#297).
 *
 * AND THE COMMON PATH NEVER USED IT.  A plain open -- which is what exec does
 * -- takes neither the FCREAT arm nor the FTRUNC one, so those 42 bytes were
 * reserved on every open in the system to serve two arms that a lookup never
 * enters.  Moving them into the arms means the frame appears only when the
 * work does, and the create/truncate chains are not the deepest ones.
 *
 * MEASURED, both directions: a 32-byte probe local added to vn_open overflowed
 * every slice outright -- canaries DEAD, 510 of 512 used -- which is what
 * established that this frame is on the deep chain rather than merely large.
 */
static int
vn_mknode(ndp, cmode)
struct nameidata *ndp;
int               cmode;
{
    struct vattr vat;

    vattr_null(&vat);
    vat.va_type = VREG;
    vat.va_mode = (unsigned short)cmode;
    return (VOP_CREATE(ndp, &vat));
}

static int
vn_trunc0(vp)
struct vnode *vp;
{
    struct vattr vat;

    vattr_null(&vat);
    vat.va_size = (off_t)0;
    return (VOP_SETATTR(vp, &vat, (char *)0));
}


/* vn_open -- turn a resolved-or-creatable path into an OPEN vnode.
 * 4.3BSD-Reno kern/vfs_vnops.c:47.
 *
 * THE CALLER FILLS IN ni_dirp/ni_segflg/ni_cdir/ni_rdir AND THIS OWNS
 * ni_nameiop, which is upstream's division and not an accident: the operation
 * and its flags are decided BY the mode, and a caller that set them would be
 * deciding CREATE-versus-LOOKUP twice.
 *
 * WHAT IT HANDS BACK, AND IN WHICH STATE.  On success ndp->ni_vp is a
 * REFERENCED, UNLOCKED vnode -- the VOP_UNLOCK before VOP_OPEN is upstream's
 * and it is load-bearing here for a reason this tree has already paid for:
 * an open file is held across other operations, and a handle kept across
 * other operations is kept UNLOCKED, or the next lookup that reaches it waits
 * on this process's own lock (ufs_ihashget, and that wait is before the
 * self-deadlock check, so it hangs naming nothing).  On failure it has
 * released everything it took.
 *
 * ni_dvp IS RELEASED ON THE EXISTING-FILE CREATE PATH and nulled, because
 * LOCKPARENT asked for it and this function is the last thing that wants it.
 * The `ni_dvp == ni_vp` case is a create of "." -- one vnode, two references,
 * so vrele and not vput, or the second call unlocks a lock the first released.
 */
int
vn_open(ndp, fmode, cmode)
struct nameidata *ndp;
int               fmode;
int               cmode;
{
    struct vnode *vp;
    int           error;

    if (fmode & FCREAT) {
        ndp->ni_nameiop = CREATE | LOCKPARENT | LOCKLEAF;
        if ((fmode & FEXCL) == 0)
            ndp->ni_nameiop |= FOLLOW;
        error = namei(ndp);
        if (error)
            return (error);
        if (ndp->ni_vp == (struct vnode *)0) {
            error = vn_mknode(ndp, cmode);
            /* AND NOW RELEASE THE PARENT, WHICH UPSTREAM DOES NOT DO HERE.
             * This is a REFERENCE-CONTRACT divergence and not an addition:
             * Reno's ufs_maknode ends with `iput(pdir)`, so by the time
             * VOP_CREATE returns the parent is already gone and its vn_open
             * has nothing to release.  THIS TREE'S ufs_maknode never touches
             * ni_dvp at all -- it reads it for the directory entry and leaves
             * it to the caller, exactly as every other routine in that layer
             * does.  So the LOCKPARENT lock taken above is still held here,
             * and without this the very next lookup that descends into this
             * directory waits for a lock this process owns: `lockself`,
             * naming the parent's inode.
             *
             * Same two cases as the existing-file arm below, for the same
             * reason: creating "." would give one vnode two references, and
             * vput would then unlock a lock vrele had already released. */
            if (ndp->ni_dvp == ndp->ni_vp)
                vrele(ndp->ni_dvp);
            else
                vput(ndp->ni_dvp);
            ndp->ni_dvp = (struct vnode *)0;
            /* AND THE FAILING CREATE OWES THAT RELEASE TOO, which is why the
             * error return is HERE and not above it.  A create that failed
             * used to return straight past the block above, leaving the
             * directory locked by a process that had moved on; the next lookup
             * descending into it then waited for a lock it already owned --
             * `lockself', naming the parent's inode.
             *
             * REACHED BY RUNNING OUT OF INODES, which is not exotic on this
             * machine: a volume with fewer than NICINOD free inodes is the
             * normal shape, and every volume enters that state as it fills.
             * Measured on a 45-inode volume -- `echo x >f' past the last inode
             * gave `cannot create' and then PANIC lockself 0002 on the mount
             * point's own inode.  apple/fgx#278. */
            if (error)
                return (error);
            /* The file was just made empty; truncating it is a no-op that
             * would call VOP_SETATTR on a fresh inode for nothing. */
            fmode = fmode & ~FTRUNC;
            vp = ndp->ni_vp;
        } else {
            if (ndp->ni_dvp == ndp->ni_vp)
                vrele(ndp->ni_dvp);
            else
                vput(ndp->ni_dvp);
            ndp->ni_dvp = (struct vnode *)0;
            vp = ndp->ni_vp;
            if (fmode & FEXCL) {
                error = EEXIST;
                goto bad;
            }
            fmode = fmode & ~FCREAT;
        }
    } else {
        ndp->ni_nameiop = LOOKUP | FOLLOW | LOCKLEAF;
        error = namei(ndp);
        if (error)
            return (error);
        vp = ndp->ni_vp;
    }
    if (vp->v_type == VSOCK) {
        /* Reno spells this EOPNOTSUPP (sys/errno.h:84).  This tree's errno.h
         * carries the same NUMBER, 45, under the name ENOTSUP, so the value a
         * caller sees is upstream's and only the spelling is local. */
        error = ENOTSUP;
        goto bad;
    }
    /* THE ACCESS CHECKS, UFS campaign 2.6 (apple/fgx#320).  Reno's structure
     * exactly, and the nesting is the load-bearing part: they are INSIDE the
     * `(fmode & FCREAT) == 0' test, so a file this very open just created is
     * not checked against its own new mode.  Upstream relies on that -- an
     * open(O_CREAT, 0) must still return a usable descriptor to its creator --
     * and a port that hoisted these out would break creating a file you cannot
     * then write.
     *
     * ORDER WITHIN THE WRITE ARM IS ALSO UPSTREAM'S: EISDIR first, then
     * vn_writechk, then VOP_ACCESS.  Reno chains the last two with `||' in one
     * `if', so writechk runs first; keeping that order means a write to a
     * read-only mount answers EROFS rather than EACCES, which is the more
     * specific of the two truths. */
    if ((fmode & FCREAT) == 0) {
        if (fmode & FREAD) {
            error = VOP_ACCESS(vp, VREAD, (char *)0);
            if (error)
                goto bad;
        }
        if (fmode & (FWRITE | FTRUNC)) {
            if (vp->v_type == VDIR) {
                error = EISDIR;
                goto bad;
            }
            error = vn_writechk(vp);
            if (error)
                goto bad;
            error = VOP_ACCESS(vp, VWRITE, (char *)0);
            if (error)
                goto bad;
        }
    }
    if (fmode & FTRUNC) {
        error = vn_trunc0(vp);
        if (error)
            goto bad;
    }
    VOP_UNLOCK(vp);
    error = VOP_OPEN(vp, fmode, (char *)0);
    if (error)
        vrele(vp);
    return (error);

bad:
    vput(vp);
    return (error);
}


/* vn_rdwr -- one contiguous transfer, building the uio for the caller.
 * 4.3BSD-Reno kern/vfs_vnops.c:157.
 *
 * THE `aresid` ARGUMENT IS THE DIFFERENCE BETWEEN "SHORT" AND "FAILED".  A
 * caller that passes one is prepared to see a partial transfer and gets the
 * leftover count; a caller that passes 0 is saying a partial transfer is an
 * error, and gets EIO.  Both callers exist upstream and the distinction is not
 * cosmetic -- exec reading a header wants the second.
 *
 * IO_NODELOCKED means "I already hold the lock".  Reno's callers use it when
 * they took VOP_LOCK themselves; this is the same contract, and it is the flag
 * that keeps this function from being unusable inside a routine that is
 * already holding the vnode. */
int
vn_rdwr(rw, vp, base, len, offset, segflg, ioflg, cred, aresid)
int           rw;               /* enum uio_rw: UIO_READ or UIO_WRITE */
struct vnode *vp;
char         *base;
int           len;
off_t         offset;
int           segflg;           /* enum uio_seg */
int           ioflg;
char         *cred;             /* Reno: struct ucred *.  Always 0 */
int          *aresid;
{
    struct uio    auio;
    struct iovec  aiov;
    int           error;

    if ((ioflg & IO_NODELOCKED) == 0)
        VOP_LOCK(vp);
    auio.uio_iov     = &aiov;
    auio.uio_iovcnt  = 1;
    aiov.iov_base    = base;
    aiov.iov_len     = len;
    auio.uio_resid   = len;
    auio.uio_offset  = offset;
    auio.uio_segflg  = segflg;
    auio.uio_rw      = rw;
    if (rw == UIO_READ)
        error = VOP_READ(vp, &auio, ioflg, cred);
    else
        error = VOP_WRITE(vp, &auio, ioflg, cred);
    if (aresid)
        *aresid = auio.uio_resid;
    else if (auio.uio_resid && error == 0)
        error = EIO;
    if ((ioflg & IO_NODELOCKED) == 0)
        VOP_UNLOCK(vp);
    return (error);
}


/* vn_read -- read through a `struct file`, advancing its offset.
 * 4.3BSD-Reno kern/vfs_vnops.c:196.
 *
 * THE OFFSET LIVES IN THE FILE STRUCT, NOT THE VNODE, and that is what makes
 * an inherited offset inherited: two descriptors from one open(2) share this
 * f_offset and move it for each other, while two independent open(2)s of the
 * same path have two file structs over one vnode and do not.  file.h's "THREE
 * TABLES, NOT ONE" is this line.
 *
 * THE ADVANCE IS `count - uio_resid`, THE AMOUNT ACTUALLY MOVED, not the
 * amount asked for: a short read at end of file must leave the offset at the
 * end, not past it. */
int
vn_read(fp, uio)
struct file *fp;
struct uio  *uio;
{
    struct vnode *vp;
    int           count;
    int           error;

    vp = (struct vnode *)fp->f_data;
    VOP_LOCK(vp);
    uio->uio_offset = fp->f_offset;
    count = uio->uio_resid;
    /* ioctl(FIONBIO) sets FNDELAY now, so this arm is LIVE -- but only as far
     * as spec_read, which drops the ioflag for a VCHR vnode.  A regular file
     * reads it; a character device under /dev does not.  apple/fgx#310. */
    error = VOP_READ(vp, uio, (fp->f_flag & FNDELAY) ? IO_NDELAY : 0,
                     (char *)0);
    fp->f_offset += count - uio->uio_resid;
    VOP_UNLOCK(vp);
    return (error);
}


/* vn_write -- write through a `struct file`.  4.3BSD-Reno kern/vfs_vnops.c:213.
 *
 * THE APPEND CASE TAKES ITS OFFSET BACK FROM THE uio RATHER THAN ADDING TO
 * THE OLD ONE, and the two are not the same number.  IO_APPEND makes the
 * filesystem seek to the current end before writing, so where the write landed
 * is only knowable afterwards -- adding the count to the pre-write f_offset
 * would put the descriptor wherever it happened to be pointing plus a length,
 * which for two appenders to one file is neither of their writes.
 *
 * IO_APPEND IS GATED ON VREG because appending is a statement about a file's
 * length; a device has no end to seek to. */
int
vn_write(fp, uio)
struct file *fp;
struct uio  *uio;
{
    struct vnode *vp;
    int           count;
    int           error;
    int           ioflag;

    ioflag = 0;
    vp = (struct vnode *)fp->f_data;
    if (vp->v_type == VREG && (fp->f_flag & FAPPEND))
        ioflag |= IO_APPEND;
    if (fp->f_flag & FNDELAY)           /* live, but see vn_read on VCHR */
        ioflag |= IO_NDELAY;
    VOP_LOCK(vp);
    uio->uio_offset = fp->f_offset;
    count = uio->uio_resid;
    error = VOP_WRITE(vp, uio, ioflag, (char *)0);
    if (ioflag & IO_APPEND)
        fp->f_offset = uio->uio_offset;
    else
        fp->f_offset += count - uio->uio_resid;
    VOP_UNLOCK(vp);
    return (error);
}


/* vn_close -- close a `struct file`'s vnode.  4.3BSD-Reno kern/vfs_vnops.c:358.
 *
 * f_data IS CLEARED BEFORE VOP_CLOSE, AND THE ORDER IS THE WHOLE FUNCTION.
 * Upstream says so in a comment and it matters more here than there, because
 * this is the path apple/fgx#76 lives on: VOP_CLOSE on a device asks "is this
 * the last close", and spec_close answers with vcount(), which counts the
 * references the vnode still has.  Leaving this file's reference attached
 * while asking makes the answer always "no" and the driver's teardown never
 * runs.
 *
 * WHAT THIS DOES NOT DO IS DECIDE WHETHER TO CALL VOP_CLOSE AT ALL.  That is
 * closef's job (vfs_file.c) and it is keyed on f_count reaching zero, which is
 * a count of DESCRIPTORS across all processes -- so a dup'd or forked
 * descriptor closing does not reach here.  Two different last-close questions,
 * one per table, and conflating them is the bug #76 was.
 *
 * The upstream FSHLOCK/FEXLOCK test is absent -- see this file's head. */
int
vn_close(fp)
struct file *fp;
{
    struct vnode *vp;
    int           error;

    vp = (struct vnode *)fp->f_data;
    fp->f_data = (char *)0;
    error = VOP_CLOSE(vp, fp->f_flag, (char *)0);
    vrele(vp);
    return (error);
}


/* vn_getattr -- VOP_GETATTR, performed on THIS side of the seam.
 *
 * IT EXISTS BECAUSE OF WHERE THE DISPATCH HAPPENS, not because upstream has
 * it: Reno's lseek calls VOP_GETATTR inline, and this tree's lseek body is in
 * the far kernel bank.  The rule this file follows: a VOP_ is dispatched in the
 * module that owns the vnode layer, and the far bank calls a named function
 * here.  The seam carries the call; the vector never crosses.
 */
int
vn_getattr(vp, vap)
struct vnode *vp;
struct vattr *vap;
{
    return (VOP_GETATTR(vp, vap, (char *)0));
}


/* vn_setsize -- set a vnode's LENGTH.  The VOP_SETATTR half of Reno's
 * ftruncate (kern/vfs_syscalls.c:1346).  UFS 2.7.
 *
 * IT TAKES A SIZE AND NOT A vattr, and that is the whole reason it exists as
 * its own entry rather than a `vn_setattr' mirroring vn_getattr above.  Reno's
 * ftruncate builds the vattr itself:
 *
 *      VATTR_NULL(&vattr);
 *      vattr.va_size = uap->length;
 *      error = VOP_SETATTR(vp, &vattr, fp->f_cred);
 *
 * and `vattr_null' is THIS module's, beside the structure it fills.  Building
 * the vattr in the far bank would either cross a second seam to reach it or
 * duplicate a VNOVAL fill that has to agree with vfs_subr's field for field --
 * and a field this side later adds would be left holding stack residue, which
 * ufs_setattr reads as "the caller asked for this".  A size is one number and
 * cannot be half-initialised.
 *
 * THE CALLER'S CHECKS ARE NOT REPEATED HERE.  Reno's EISDIR and vn_writechk
 * arms run before it reaches VOP_SETATTR, and they run in the far bank where
 * the descriptor is -- see root_ftruncate.  Splitting them that way keeps this
 * function what its name says and leaves the errno decisions at the syscall
 * boundary, which is vfs_syscalls.c's job everywhere else.
 */
int
vn_setsize(vp, length)
struct vnode *vp;
off_t         length;
{
    struct vattr va;

    vattr_null(&va);
    va.va_size = length;
    return (VOP_SETATTR(vp, &va, (char *)0));
}


/* ONE DIRECTORY BLOCK, sized by the constant that defines the interface.
 * ufs_readdir rounds every transfer down to a multiple of DIRBLKSIZ and
 * refuses a request smaller than one, so this is both the minimum and the
 * natural unit; a listing walks the directory one of these at a time. */
static char vfs_dirblk[DIRBLKSIZ];
/* readlink's landing ground, for the reason vfs_dirblk is one: the VOP fills
 * THIS, and the caller's buffer is filled from it afterwards. */
static char vfs_linkbuf[MAXPATHLEN];

/* vfs_listdir -- listdir(2)'s whole body, performed on THIS side of the seam.
 * UFS campaign, the directory-read conversion (apple/fgx#291).
 *
 * FGX-ORIGIN IN SHAPE, AND AN EARLIER VERSION OF THIS COMMENT OVERSTATED IT.
 * It said "PORTED FROM getdirentries in SEQUENCE: resolve the name, refuse a
 * non-directory, then loop VOP_READDIR".  Read side by side with
 * 4.3BSD-Reno's getdirentries (kern/vfs_syscalls.c:1579) that is not what
 * either does.  Upstream:
 *
 *   - takes an FD and calls getvnode, where this takes a PATH and calls namei;
 *   - calls VOP_READDIR exactly ONCE, where this loops to end-of-directory;
 *   - answers EINVAL for a non-directory, where this answers ENOTDIR;
 *   - returns RAW `struct direct' records and leaves the walk to libc, where
 *     this returns a packed list of NUL-terminated names.
 *
 * SYS_LISTDIR is an FGX syscall with no upstream counterpart, so the shape is
 * FGX's.  What IS taken from getdirentries is the middle: the uio built over
 * one iovec, the VDIR test before it, and the eofflag contract.  The record
 * walk comes from the FORMAT -- dir.h, and ufs_vnprobe.c's walk over the same
 * bytes -- not from upstream code.  Said plainly here because a port claim
 * that does not survive reading the upstream is worse than no claim.
 *
 * THE LEAF LOCK IS TAKEN, and the note that used to stand here said it was
 * not: "NO VOP_LOCK, WHICH RENO HAS AND THIS TREE DOES NOT ... this matches
 * local practice rather than upstream."  That reading made a caller-side
 * omission sound like a missing subsystem.  It is not one -- ufs_lock sleeps
 * on ILOCKED (ufs_vnops.c:1740), namei locks every directory it descends, and
 * lookup() honours LOCKLEAF at both exits -- so upstream's discipline was
 * available the whole time and simply not asked for.  apple/fgx#294; the flag
 * site below carries the reasoning and ufs_vnprobe.c's four now lock too.
 *
 * IT IS IN THIS MODULE AND NOT IN THE FAR BANK BESIDE root_stat, and that was
 * MEASURED rather than chosen.  Written there it compiled to 1,353 bytes
 * against a far bank with 697 free -- over by 656 -- while vfs.mod has
 * thousands.  The structural argument agrees with the measurement and is the
 * better reason: namei, ndslot and vrele are ALL this module's, and the
 * VOP_READDIR is dispatched here by vn_getattr's rule, so a body in the far
 * bank would cross the seam once per directory block.  Here it crosses ONCE,
 * on the way in, and nothing else crosses at all.
 *
 * IT OWNS THE uio, which is the same rule stated one level down.  ufs_readdir's
 * alignment rules ARE its interface (ufs_vnops.c says so at its header):
 * uio_offset must be a multiple of DIRBLKSIZ, the transfer is rounded DOWN to
 * a multiple of DIRBLKSIZ, and a request smaller than one DIRBLKSIZ is EINVAL
 * because rounding it down gives zero and a zero-length read would look like
 * end-of-directory.  A caller in another bank that got them wrong would get a
 * partial entry whose d_reclen walks off the end of the buffer.
 *
 * IT STEPS BY d_reclen AND NEVER BY DIRSIZ, which dir.h states is the
 * invariant and not a preference: an entry may carry free space after it, so
 * DIRSIZ(d_namlen) is a LOWER bound on the record and stepping by it would
 * resynchronise onto the middle of the next name.
 *
 * THE DIRECTORY BLOCK IS THIS MODULE'S OWN, and that was a measurement too.
 * Lending the core's `_fsDirBuf' costs no memory and was the first shape, but
 * it makes the argument a THIRD bank the core must marshal -- and the core
 * bank is the one with 29 bytes free, where vfs.mod has thousands.  Twelve
 * bytes of core marshalling for 512 bytes of module BSS is the right side of
 * that trade, and it also ends a lifetime coupling: `_fsDirBuf' is the legacy
 * readdir path's scratch, and the two arms no longer have to agree about who
 * may hold it.
 *
 * `.' AND `..' ARE RETURNED, deliberately.  Reno's readdir hands them up and
 * ls(1) filters them -- src/userland/ls/ls.c:291 is the standard
 * `aflg == 0 && d_name[0] == '.'' test, carried from the same upstream.  The
 * legacy ProDOS arm never produced them because a ProDOS directory has no such
 * entries, so `ls -a' showing nothing was reporting the FILESYSTEM's shape.
 * Filtering here to match it would make the kernel lie to a flag whose whole
 * job is to ask.
 *
 * NO LOWERCASING, which the legacy arm does in the core loop
 * (syscall.s @ld_copyByte, folding A-Z on the way out) because ProDOS stores a
 * name uppercase and carries display case in the version bytes.  2.11BSD names
 * are BYTES.  A file called README is called README, and folding it would make
 * the name this returns one that open(2) cannot then resolve.
 *
 * A CORRUPT RECORD ENDS THE BLOCK, not the listing.  d_reclen is bounded below
 * by the 8-byte header, must be 4-byte aligned, and must not run past what
 * moved; failing any of those the rest of THIS block is unreadable but the
 * next one is not, because every DIRBLKSIZ boundary starts a fresh entry
 * (dir.h:50).  That is the resynchronisation the block size exists to give.
 *
 * Returns the bytes written (>= 0), or -errno.  The two cannot collide: no
 * errno is 0 and no count is negative.
 */
int
vfs_listdir(pid, path, buf, size)
int   pid;
char *path;
char *buf;
int   size;
{
    struct nameidata *ndp;
    struct iovec      iov;
    struct uio        u;
    struct vnode     *vp;
    struct direct    *e;
    int               total;
    int               eof;
    int               blkno;
    int               moved;
    int               n;
    int               nl;
    int               i;

    /* THE CALLER'S SLOT, NOT PID 1'S.  This read `ndslot(1, 0)' while taking
     * a pid and using it two lines down for ni_cdir, so every listing in the
     * system walked on INIT's nameidata -- and this walk asks for LOCKLEAF.
     * Two walks sharing one slot orphan a lock: the second clears ni_vp and
     * the first's leaf stays held, which `ufs_ilock' then reports as
     * `lockself' the next time anybody resolves that inode.
     *
     * IT IS NOT A PORTING SLIP, because there is nothing upstream to slip
     * from: Reno's nameidata is a per-call STACK LOCAL (`struct nameidata nd'
     * in each syscall body), so "which slot" is a question this tree invented
     * when it made them a per-pid pool.  vfs_openat passes its pid; this did
     * not.  apple/fgx#311. */
    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (-EINVAL);

    ndp->ni_dirp    = path;
    ndp->ni_segflg  = UIO_SYSSPACE;
    /* LOCKLEAF AND FOLLOW, WHICH THIS ASKED FOR NEITHER.  apple/fgx#294.
     *
     * LOCKLEAF is the lock VOP_READDIR is entitled to.  Reno's getdirentries
     * (kern/vfs_syscalls.c:1579) takes `VOP_LOCK(vp)' before the dispatch and
     * unlocks after, because ITS vnode came out of a file descriptor that
     * nobody locked; this one comes out of namei, which returns the leaf
     * UNLOCKED unless asked -- so the same gap arrives by the other road and
     * was open the whole time.  It is latent only while ufs_mountfs forces
     * MNT_RDONLY: the walk below steps by `d_reclen', so a record torn under
     * it walks off the end of the block rather than merely reading a stale
     * name.  Asking namei for the lock is this tree's own shape (vfs_chdir),
     * and it costs the same one flag upstream's VOP_LOCK pair costs.
     *
     * FOLLOW is the separate half: without it `ls' on a symlink to a
     * directory reached the LINK, whose v_type is VLNK, and answered ENOTDIR.
     * lookup() follows an INTERIOR symlink whatever the caller asked (:831,
     * Reno's second clause) -- FOLLOW governs the last component only, which
     * is exactly the component a listing names. */
    ndp->ni_nameiop = LOOKUP | FOLLOW | LOCKLEAF;
    /* THE PROCESS'S OWN DIRECTORY, WHICH IS WHAT MAKES `ls' WITH NO ARGUMENT
     * MEAN ANYTHING.  It was a hard zero, so a relative name resolved against
     * the ROOT -- and that is not a miss but a WRONG ANSWER, which apple/fgx#295
     * measured: `ls' in /etc listed / instead.
     *
     * PASSED UNCONDITIONALLY AND NOT UNDER A `*path == '/'' TEST, which is
     * Reno's shape: its callers hand namei `u.u_cdir' and namei decides, at
     * vfs_lookup.c:628, because only namei can decide again after a symlink.
     * For an absolute name it never reads this field, so the test root_open
     * carries is equivalent rather than load-bearing. */
    ndp->ni_cdir    = vfs_cdir(pid);
    ndp->ni_rdir    = (struct vnode *)0;
    ndp->ni_vp      = (struct vnode *)0;
    ndp->ni_dvp     = (struct vnode *)0;

    i = namei(ndp);
    if (i)
        return (-i);

    vp = ndp->ni_vp;
    if (vp->v_type != VDIR) {
        vput(vp);
        return (-ENOTDIR);
    }

    total = 0;
    eof   = 0;
    blkno = 0;
    while (eof == 0) {
        /* THE OFFSET IS BUILT FROM A BLOCK INDEX, so it cannot be misaligned
         * by construction -- the first of ufs_readdir's three rules enforced
         * rather than trusted.  ints are 16 bits here, so counting blocks and
         * multiplying to off_t is also what keeps a large directory reachable:
         * a byte cursor would stop at 32 KB and do it silently. */
        iov.iov_base = vfs_dirblk;
        iov.iov_len  = (unsigned short)DIRBLKSIZ;
        u.uio_iov    = &iov;
        u.uio_iovcnt = 1;
        u.uio_offset = (off_t)blkno * (off_t)DIRBLKSIZ;
        u.uio_resid  = (unsigned short)DIRBLKSIZ;
        u.uio_segflg = UIO_SYSSPACE;
        u.uio_rw     = UIO_READ;

        i = VOP_READDIR(vp, &u, (char *)0, &eof);
        if (i) {
            vput(vp);
            return (-i);
        }
        /* WHAT MOVED, not what was asked for.  uio_resid is how a uio reports
         * movement (uio.h: "the caller learns how much from what is LEFT"),
         * and the tail of a short block still holds whatever the buffer held
         * before -- walking it would read stale bytes as records. */
        moved = DIRBLKSIZ - (int)u.uio_resid;

        n = 0;
        while (n + 8 <= moved) {
            e = (struct direct *)&vfs_dirblk[n];
            if (e->d_reclen < 8 || (e->d_reclen & 3) != 0)
                break;
            if (n + (int)e->d_reclen > moved)
                break;
            nl = (int)e->d_namlen;
            if (e->d_ino != 0 && nl > 0) {
                /* A RECORD IS `ino:2' THEN `name\0'.  The inode number is the
                 * point: readdir(3) reported a synthesized 1 for every entry
                 * while the real number sat right here and was dropped on the
                 * way out (apple/fgx#358).  getwd(3) walks up through `..' and
                 * matches the level by inode -- "if (dp->d_fileno == ino)",
                 * 4.3BSD-Reno lib/libc/gen/getwd.c -- so a constant 1 makes
                 * that loop run to end-of-directory every time.
                 *
                 * Little-endian, byte at a time, because this is a WIRE and
                 * `buf' is a caller buffer of unknown alignment.
                 *
                 * A NAME THAT DOES NOT FIT ENDS THE LISTING RATHER THAN
                 * TRUNCATING ONE: the caller reads this buffer as a run of
                 * NUL-terminated names, so half a name with a NUL after it is
                 * indistinguishable from a real file. */
                if (total + nl + 3 > size)
                    goto done;
                /* ONE 16-BIT STORE, which is what the byte budget allows.
                 * vfs.mod builds with 23 bytes to spare (apple/fgx#299), and a
                 * mask-and-shift pair or two indexed byte stores do not fit in
                 * that.  The 65816 has no alignment requirement, so an unaligned
                 * short store into a caller buffer is legal and is a single
                 * 16-bit STA. */
                *(unsigned short *)&buf[total] = e->d_ino;
                total += 2;
                for (i = 0; i < nl; i++)
                    buf[total++] = e->d_name[i];
                buf[total++] = '\0';
            }
            n += (int)e->d_reclen;
        }
        blkno++;
    }

    /* NO END MARKER IS WRITTEN, and none is needed: the return value IS the
     * length, and a record now carries a 2-byte inode so the reader has a fixed
     * amount to check before it can trust a name.  The old terminator was a
     * zero-length name, which only worked while records were bare strings.
     * Dropping it also buys back the bytes the inode costs -- vfs.mod builds
     * with 23 to spare (apple/fgx#299), which is not enough to add to this loop
     * without removing something. */
done:
    vput(vp);
    return (total);
}


/* vn_ioctl -- Reno kern/vfs_vnops.c:306.  A pass-through, deliberately.
 *
 * `data` IS THE CALLER'S POINTER AND IS NOT DEREFERENCED HERE.  Upstream's
 * vn_ioctl has a VCHR/VBLK arm that reads a tty out of the argument for the
 * TIOCSCTTY case; it is not carried, because that arm is what needs the
 * bank-marshalling decision and this function is not where that decision goes.
 * Carrying it would mean choosing how a caller-bank pointer is read, here,
 * with no caller -- the exact shape 1.7c refused and was right to.  What
 * reaches VOP_IOCTL is what the caller passed. */
int
vn_ioctl(fp, com, data)
struct file *fp;
int          com;
char        *data;
{
    return (VOP_IOCTL((struct vnode *)fp->f_data, com, data, fp->f_flag,
                      (char *)0));
}


/* vn_select -- Reno kern/vfs_vnops.c:347, verbatim but for the cred.
 *
 * Reno passes u.u_cred; there is no ucred here by design (file.h), so this
 * passes the same null every other VOP call site in this file passes.  A VOP
 * that needs the ids asks kc_curuid/kc_curgid for them. */
int
vn_select(fp, which)
struct file *fp;
int          which;
{
    return (VOP_SELECT((struct vnode *)fp->f_data, which, fp->f_flag,
                       (char *)0));
}


/* `vnops` IS IN vfs_syscalls.c, with the code that dereferences it.  Its five
 * entries name far-side import shims, so a call through f_ops is same-bank and
 * only the shim crosses.  The five functions below are the targets, reached
 * through those shims.
 */


/* nd_begin -- set up a walk.  The six fields every namei caller here fills.
 *
 * FACTORED BECAUSE IT PAID FOR ITSELF IN BANK SPACE, not for tidiness.  The
 * five namespace calls below each wrote the same six assignments, and vfs.mod
 * is a 64 KB bank that vfs_rename pushed 783 bytes past the end.  fcc emits a
 * store per field per site; one function emits them once.
 *
 * ni_rdir STAYS 0 -- that is chroot(2), which does not exist here -- and
 * ni_vp/ni_dvp are CLEARED rather than left as the slot holds them: an ndslot
 * persists across walks, so a stale ni_vp would be a vnode this call never
 * referenced and the error paths would release it.
 */
static void
nd_begin(ndp, op, dvp, path)
struct nameidata *ndp;
int               op;
struct vnode     *dvp;
char             *path;
{
    ndp->ni_nameiop = op;
    ndp->ni_segflg  = UIO_SYSSPACE;
    ndp->ni_dirp    = path;
    ndp->ni_cdir    = dvp;
    ndp->ni_rdir    = (struct vnode *)0;
    ndp->ni_vp      = (struct vnode *)0;
    ndp->ni_dvp     = (struct vnode *)0;
}


/* THE NAMESPACE OPERATIONS -- unlink(2), mkdir(2) and rmdir(2), ported from
 * 4.3BSD-Reno kern/vfs_syscalls.c (`unlink', `mkdir', `rmdir').  UFS campaign,
 * apple/fgx#318's second half.
 *
 * THEY TAKE pid AND dvp for vfs_openat's reason exactly: Reno reads the walk's
 * starting directory out of the u-area (`u.u_nd', `u.u_cdir') and kernel C
 * here has no u-area, so the caller passes both.  Zero dvp still means "start
 * at the system root", which is namei's own convention (vfs_lookup.c).
 *
 * THE ni_ FIELDS ARE CLEARED RATHER THAN LEFT AS THE SLOT HOLDS THEM.  An
 * ndslot persists across walks, so a stale ni_vp would be a vnode this call
 * never referenced and the error paths below would release it.
 *
 * THERE IS NO VOP_ABORTOP HERE AND UPSTREAM CALLS ONE.  vnode.h records why
 * the macro does not exist -- "a macro nobody uses is a macro nobody has
 * checked" -- and its whole job in these three is to let a filesystem drop
 * whatever the lookup staged for a create or delete it is now abandoning.
 * UFS's own abortop in Reno frees the pathname buffer, which this tree does
 * not allocate: ni_ptr points into the caller's string.  So the release the
 * error paths still owe is the REFERENCES, and that is what they do inline.
 * The divergence is recorded in the man pages' BUGS.
 *
 * NO CREDENTIALS reach these functions, so one of upstream's tests cannot be
 * evaluated and is spelled out rather than dropped:
 *   - Reno lets the SUPERUSER unlink a directory (`suser(ndp->ni_cred)').
 *     With no credential to weigh, the safe reading of that test is its
 *     non-root arm: a directory is refused.  rmdir(2) is the way.
 * mkdir's mode arrives already masked: the syscall layer applies
 * `& 0777 &~ u_cmask' (_Sys_ApplyCmask, syscall.s) before the call reaches
 * vfs_mkdir, so the mode is taken as given here.
 */

/* vfs_unlink -- remove a name.  Reno's unlink(2). */
int
vfs_unlink(pid, dvp, path)
int           pid;
struct vnode *dvp;
char         *path;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    nd_begin(ndp, DELETE | LOCKPARENT | LOCKLEAF, dvp, path);

    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;

    /* A DIRECTORY IS NOT UNLINKED HERE -- see the head note on suser. */
    if (vp->v_type == VDIR)
        error = EPERM;
    /* AND NEITHER IS A MOUNT POINT, which is upstream's own next test:
     * "Don't unlink a mounted file." */
    else if (vp->v_flag & VROOT)
        error = EBUSY;

    if (error == 0) {
        error = VOP_REMOVE(ndp);
    /* THE PARENT IS THIS CALLER'S TO RELEASE, WHICH IS A DIVERGENCE FROM
     * UPSTREAM AND NOT AN ADDITION.  Reno's ufs_remove/ufs_rmdir/ufs_mkdir
     * end by putting the directory down themselves, so its vfs_syscalls.c has
     * nothing to release on the success path.  THIS TREE'S DO NOT: they read
     * ni_dvp for the directory entry and leave it alone -- measured, and
     * consistent across all three.  vn_open above records the same fact about
     * ufs_maknode and does the same thing about it.
     *
     * WITHOUT IT THE MACHINE HANGS, not merely leaks: LOCKPARENT took the
     * lock, so the next lookup that descends into this directory waits on a
     * lock this process already owns.  Measured as `mkdir /tmp/d1; ls /tmp'
     * producing no output at all. */
        vput(ndp->ni_dvp);
        return (error);
    }

    /* The two vnodes go back.  Same pair of cases as everywhere else in this
     * layer: one vnode with two references is vrele'd once, two distinct ones
     * are vput. */
    if (ndp->ni_dvp == vp)
        vrele(ndp->ni_dvp);
    else
        vput(ndp->ni_dvp);
    vput(vp);
    return (error);
}


/* vfs_rename -- rename(2).  4.3BSD-Reno kern/vfs_syscalls.c:1410-1482.
 *
 * TWO WALKS, WHICH IS WHY VFS_NDPERPROC IS 2 (fsparam.h:404).  Reno keeps the
 * from-walk in u.u_nd and the to-walk in an automatic `struct nameidata tond',
 * duplicating one into the other with nddup.  There is no u-area here and a
 * nameidata is far too big for a kernel-C frame, so both come from the pool:
 * slot 0 is the from-walk and slot 1 the to-walk, and nd_begin sets each from
 * scratch rather than copying, which is the same result because the only thing
 * nddup carries that matters is ni_segflg and nd_begin writes it.
 *
 * THE OPS ARE UPSTREAM'S EXACTLY.  DELETE|WANTPARENT for the source -- the
 * parent comes back UNLOCKED because ufs_rename re-finds the source entry
 * itself -- and RENAME|LOCKPARENT|LOCKLEAF|NOCACHE for the target, whose parent
 * must be held because the entry is about to be written into it.  NOCACHE
 * because the target name is being redefined and must not be remembered.
 *
 * THE FOUR CHECKS ARE UPSTREAM'S AND IN UPSTREAM'S ORDER: a directory may not
 * replace a file (ENOTDIR) nor a file a directory (EISDIR); the two ends must
 * be on one mount (EXDEV); a directory may not be renamed into itself
 * (EINVAL); and renaming a thing onto itself is not an error but a no-op --
 * Reno spells that `error = -1' and turns it back into 0 at the exit, which is
 * carried here verbatim because a caller that gets EINVAL for `mv f f' is
 * wrong in a way userland cannot see.
 *
 * REFERENCES.  ufs_rename's own header states the contract: "the caller owns
 * both ni_dvp, as everywhere in this layer.  This function releases
 * fndp->ni_vp and tndp->ni_vp exactly once each, on every path."  So on the
 * VOP path this function releases the two PARENTS and nothing else, and on
 * every path that does not reach the VOP it releases all four itself -- which
 * is what Reno's else-arm does with VOP_ABORTOP, a slot this tree does not
 * have (vnode.h:152).
 */
int
vfs_rename(pid, fdvp, from, tdvp, to)
int           pid;
struct vnode *fdvp;
char         *from;
struct vnode *tdvp;
char         *to;
{
    struct nameidata *fndp;
    struct nameidata *tndp;
    struct vnode     *fvp;
    struct vnode     *tvp;
    struct vnode     *tdirp;
    int               error;

    fndp = ndslot(pid, 0);
    tndp = ndslot(pid, 1);
    if (fndp == (struct nameidata *)0 || tndp == (struct nameidata *)0)
        return (EINVAL);

    nd_begin(fndp, DELETE | WANTPARENT, fdvp, from);
    error = namei(fndp);
    if (error)
        return (error);
    fvp = fndp->ni_vp;

    nd_begin(tndp, RENAME | LOCKPARENT | LOCKLEAF | NOCACHE, tdvp, to);
    error = namei(tndp);
    if (error) {
        vrele(fndp->ni_dvp);
        vrele(fvp);
        return (error);
    }
    tdirp = tndp->ni_dvp;
    tvp   = tndp->ni_vp;

    if (tvp != (struct vnode *)0) {
        if (fvp->v_type == VDIR && tvp->v_type != VDIR)
            error = ENOTDIR;
        else if (fvp->v_type != VDIR && tvp->v_type == VDIR)
            error = EISDIR;
    }
    if (error == 0 && fvp->v_mount != tdirp->v_mount)
        error = EXDEV;
    if (error == 0 && fvp == tdirp)
        error = EINVAL;
    /* Source is the destination: nothing to do, and NOT an error. */
    if (error == 0 && fvp == tvp)
        error = -1;

    if (error == 0) {
        error = VOP_RENAME(fndp, tndp);
        /* BOTH PARENTS ARE OURS AND THEY ARE THE ONLY TWO LEFT -- ufs_rename
         * released fvp and tvp.  NO SAME-VNODE SPECIAL CASE HERE, and this is
         * the one place in the layer where that is right: the two walks took
         * SEPARATE references, WANTPARENT unlocked on the source's parent and
         * LOCKPARENT locked on the target's.  A rename inside one directory
         * therefore holds that directory TWICE, and the two releases below are
         * one per reference -- vrele for the unlocked one, vput for the locked
         * one -- whether or not they are the same vnode. */
        vrele(fndp->ni_dvp);
        vput(tdirp);
        return (error);
    }

    /* Reno's else-arm, with the releases standing in for VOP_ABORTOP. */
    if (tdirp == tvp)
        vrele(tdirp);
    else
        vput(tdirp);
    if (tvp != (struct vnode *)0)
        vput(tvp);
    vrele(fndp->ni_dvp);
    vrele(fvp);
    if (error == -1)
        return (0);
    return (error);
}


/* vfs_mkdir -- make a directory.  Reno's mkdir(2). */
int
vfs_mkdir(pid, dvp, path, dmode)
int           pid;
struct vnode *dvp;
char         *path;
int           dmode;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    struct vattr      vattr;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    /* CREATE | LOCKPARENT and NOT LOCKLEAF, which is upstream's exactly: the
     * leaf must not exist, so there is nothing to lock. */
    nd_begin(ndp, CREATE | LOCKPARENT, dvp, path);

    error = namei(ndp);
    if (error)
        return (error);

    vp = ndp->ni_vp;
    if (vp != (struct vnode *)0) {
        if (ndp->ni_dvp == vp)
            vrele(ndp->ni_dvp);
        else
            vput(ndp->ni_dvp);
        vrele(vp);
        return (EEXIST);
    }

    vattr_null(&vattr);
    vattr.va_type = VDIR;
    vattr.va_mode = (unsigned short)(dmode & 0777);
    error = VOP_MKDIR(ndp, &vattr);
    /* THE NEW DIRECTORY IS PUT BACK ON SUCCESS ONLY.  ufs_mkdir returns it
     * referenced and locked in ni_vp; on failure it has already let go. */
    if (error == 0)
        vput(ndp->ni_vp);
    /* AND THE PARENT ALWAYS, for vfs_unlink's reason -- ufs_mkdir reads
     * ni_dvp and never touches its reference or its lock. */
    vput(ndp->ni_dvp);
    return (error);
}


/* vfs_symlink -- symlink(2).  4.3BSD-Reno kern/vfs_syscalls.c:773-810.
 *
 * CREATE|LOCKPARENT and no LOCKLEAF, which is upstream's and vfs_mkdir's: the
 * leaf must not exist, so there is nothing to lock, and a leaf that DOES exist
 * is EEXIST rather than a silent replacement.
 *
 * THE TARGET IS NOT COPIED IN.  Reno MALLOCs MAXPATHLEN and copyinstr's the
 * target into it because its caller's pointer is userspace; the path arrives
 * here already staged in a kernel buffer by the syscall layer, which is the
 * same reason every other path in this file is UIO_SYSSPACE.  So the malloc,
 * the copyinstr and the FREE at `out' all go, and with them upstream's only
 * two error paths that are not namei's.
 *
 * 0777 AND NO UMASK.  Reno writes `0777 &~ u.u_cmask'.  The mask exists
 * (U_Cmask, set by umask(2)) but it is applied only to creating opens and
 * mkdir (the _Sys_ApplyCmask callers, syscall.s and process.s); _Sys_Symlink
 * does not call it, so
 * the link is created 0777.  It is also what a symlink's mode means in practice --
 * the target's permissions are what get checked, not the link's.
 *
 * REFERENCES: ufs_symlink is maknode plus a write and iputs the new inode
 * ITSELF, so unlike vfs_mkdir there is no ni_vp to put back on success.  The
 * parent is this caller's, always, for the reason vfs_unlink's header gives.
 */
int
vfs_symlink(pid, dvp, path, target, mode)
int           pid;
struct vnode *dvp;
char         *path;
char         *target;
int           mode;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    struct vattr      vattr;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    nd_begin(ndp, CREATE | LOCKPARENT, dvp, path);

    error = namei(ndp);
    if (error)
        return (error);

    vp = ndp->ni_vp;
    if (vp != (struct vnode *)0) {
        if (ndp->ni_dvp == vp)
            vrele(ndp->ni_dvp);
        else
            vput(ndp->ni_dvp);
        vrele(vp);
        return (EEXIST);
    }

    vattr_null(&vattr);
    vattr.va_type = VLNK;
    vattr.va_mode = (unsigned short)mode;  /* `0777 &~ u.u_cmask' (Reno
                                             * vfs_syscalls.c:805), masked in
                                             * the core, where the u-area is */
    error = VOP_SYMLINK(ndp, &vattr, target);
    vput(ndp->ni_dvp);
    return (error);
}


/* vfs_readlink -- readlink(2), WHOLE, on this side of the seam.  apple/fgx#326.
 *
 * IT IS vfs_listdir'S SHAPE AND THAT IS THE POINT.  The first attempt kept the
 * walk in the far bank and passed the VNODE across, taking (vp, buf, count) --
 * and it returned the right COUNT with the wrong BYTES, `ls -l' printing
 * `-> ???' for a link whose contents were perfectly good.  Narrowing it cost a
 * day and ended at "the caller's buffer pointer, as this module receives it",
 * with one discriminating fact left over: vfs_listdir takes a caller buffer
 * across this same seam and has always worked.
 *
 * So the difference was DELETED rather than explained.  Same four arguments in
 * the same order as vfs_listdir -- (pid, path, buf, count), twelve bytes -- the
 * walk on this side where namei already lives, and the caller reduced to
 * root_listdir's three lines.  Nothing crosses but scalars and the buffer that
 * is known to cross.
 *
 * NO FOLLOW, which is the whole of readlink: every other walk in this file
 * resolves a link, and this one must stop AT it.  Reno's readlink is the same
 * one flag (kern/vfs_syscalls.c:1046, `LOOKUP | LOCKLEAF').
 *
 * Returns the byte count, or -errno, which is this hook's convention.
 */
int
vfs_readlink(pid, path, buf, count)
int   pid;
char *path;
char *buf;
int   count;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    struct uio        u;
    struct iovec      iov;
    int               error;
    int               moved;
    int               i;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (-EINVAL);
    if (count > MAXPATHLEN)
        count = MAXPATHLEN;
    if (count <= 0)
        return (0);

    nd_begin(ndp, LOOKUP | LOCKLEAF, vfs_cdir(pid), path);

    error = namei(ndp);
    if (error)
        return (-error);
    vp = ndp->ni_vp;

    /* EINVAL for a name that is not a link is readlink(2)'s answer and the one
     * a caller's S_IFLNK guard expects. */
    if (vp->v_type != VLNK) {
        vput(vp);
        return (-EINVAL);
    }

    iov.iov_base = vfs_linkbuf;
    iov.iov_len  = (unsigned short)count;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = (unsigned short)count;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;

    error = VOP_READLINK(vp, &u, (char *)0);
    vput(vp);
    if (error)
        return (-error);

    /* WHAT MOVED, not what was asked for -- vfs_listdir's rule. */
    moved = count - (int)u.uio_resid;
    for (i = 0; i < moved; i++)
        buf[i] = vfs_linkbuf[i];
    return (moved);
}


/* vfs_rmdir -- remove an empty directory.  Reno's rmdir(2). */
int
vfs_rmdir(pid, dvp, path)
int           pid;
struct vnode *dvp;
char         *path;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    nd_begin(ndp, DELETE | LOCKPARENT | LOCKLEAF, dvp, path);

    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;

    if (vp->v_type != VDIR)
        error = ENOTDIR;
    /* NO rmdir "." PLEASE, in upstream's words: the parent and the leaf being
     * the same vnode IS that case, and it is caught by identity rather than by
     * inspecting the name. */
    else if (ndp->ni_dvp == vp)
        error = EINVAL;
    else if (vp->v_flag & VROOT)
        error = EBUSY;

    if (error == 0) {
        error = VOP_RMDIR(ndp);
        /* The parent, for vfs_unlink's reason exactly. */
        vput(ndp->ni_dvp);
        return (error);
    }

    if (ndp->ni_dvp == vp)
        vrele(ndp->ni_dvp);
    else
        vput(ndp->ni_dvp);
    vput(vp);
    return (error);
}


/*============================================================================
 * statfs(2) AND THE HALF getfsstat(2) SHARES WITH IT
 *
 * Ported from 4.3BSD-Reno kern/vfs_syscalls.c:325 (`statfs') and :383
 * (`getfsstat').  The 2.11BSD pair (usr/sys/sys/ufs_syscalls2.c) CANNOT be
 * ported and it is worth saying why, because the filesystem itself came from
 * there: 2.11BSD recovers the mount from an inode with
 *
 *      mp = (struct mount *)((int)ip->i_fs - offsetof(struct mount, m_filsys));
 *
 * -- pointer arithmetic off a superblock EMBEDDED in struct mount.  There is
 * no m_filsys in this tree and there is no `struct inode' at this layer;
 * Reno's `ndp->ni_vp->v_mount' is a field that exists here because the whole
 * VFS came from Reno.  So: Reno's interface over 2.11BSD's numbers, which is
 * the same seam ufs_statfs sits on and PROVENANCE already records.
 *
 * WHY HERE AND NOT IN vfs_syscalls.c, which is where upstream keeps both and
 * where the mount table lives: that file compiles into the FAR BANK
 * (tools/ninja/gen.py:59), and statfs's walk is namei, ndslot and vrele while
 * both halves copy out through uio_copy -- all of them this module's.  The
 * mount-table WALK stays in vfs_syscalls.c beside the table; it is only the
 * per-mount half that comes here.
 *============================================================================
 */

/* kern_subr.c's, declared rather than left implicit: an undeclared call is
 * how apple/fgx#327 happened, and this one passes two pointers. */
extern void uio_copy();

/* vfs_statfs1 -- refresh one mount's cached statfs and hand out a copy.
 *
 * Reno spells these four lines twice, once inside statfs() and once inside
 * getfsstat(); 2.11BSD factors the identical body out and calls it `statfs1'
 * (usr/sys/sys/ufs_syscalls2.c:59), which is the name kept here.  Two trees
 * arriving at the same cut is a good reason to take it.
 *
 * THE CACHE IS REFRESHED AND THE COPY COMES FROM THE CACHE, which is Reno's
 * order and not the shorter one available.  VFS_STATFS(mp, sbp) would fill
 * the caller's buffer in one call -- ufs_statfs supports it, that is what its
 * `sbp != &mp->mnt_stat' tail is for -- but then mnt_stat would never be
 * updated after mount time, and mnt_stat is what getfsstat(2) reports under
 * MNT_NOWAIT.  A cache nothing refreshes is a cache that is wrong.  (It also
 * said "and what dev_mount.c's probes assert against"; those went with the
 * /dev volume on 2026-09-05 and df(1) is the reader now.)
 */
int
vfs_statfs1(mp, sbp)
struct mount  *mp;
struct statfs *sbp;
{
    int error;

    error = VFS_STATFS(mp, &mp->mnt_stat);
    if (error)
        return (error);
    mp->mnt_stat.f_flags = (short)(mp->mnt_flag & MNT_VISFLAGMASK);
    uio_copy((char *)&mp->mnt_stat, (char *)sbp, sizeof(struct statfs));
    return (0);
}


/* vfs_statfs -- statfs(2)'s body.  Reno kern/vfs_syscalls.c:325.
 *
 * LOOKUP | FOLLOW, AND NO LOCKLEAF, so the release is vrele and not vput --
 * upstream's exactly.  A statfs asks about the FILESYSTEM under a name, so
 * the leaf is wanted only long enough to read v_mount off it, and following
 * the symlink is the point: `statfs' on a link reports the filesystem the
 * link's TARGET is on, which is what df(1) needs when a mount point is
 * reached through one.
 *
 * `pid' AND THE cwd, for vfs_readlink's reason exactly: a relative path is
 * resolved against the CALLER's directory, and this bank is the one that can
 * ask which that is.
 */
int
vfs_statfs(pid, path, sbp)
int            pid;
char          *path;
struct statfs *sbp;
{
    struct nameidata *ndp;
    struct mount     *mp;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    nd_begin(ndp, LOOKUP | FOLLOW, vfs_cdir(pid), path);

    error = namei(ndp);
    if (error)
        return (error);

    /* v_mount IS THE ANSWER AND IT IS TAKEN BEFORE THE RELEASE.  vrele may
     * return the vnode to the free list, so reading mp afterwards would be
     * reading through a vnode this call no longer holds -- Reno takes it in
     * the same order and the order is the whole of the correctness. */
    mp = ndp->ni_vp->v_mount;
    vrele(ndp->ni_vp);
    if (mp == (struct mount *)0)
        return (EINVAL);

    return (vfs_statfs1(mp, sbp));
}



/* vn_access -- the per-bit half of access(2), performed in THIS bank.
 *
 * UFS campaign 2.6.  vfs_access (vfs_syscalls.c, far bank) resolves the name
 * and hands the vnode here, because the two things this needs -- the VOP_ACCESS
 * dispatch and vn_writechk -- both live on this side.  One VFSCORE slot instead
 * of two, and the permission logic sits beside the writability rule it uses.
 *
 * ONE BIT PER CALL, WHICH IS 2.11BSD's SHAPE AND NOT RENO'S.  Reno's saccess
 * (kern/vfs_syscalls.c:911) ORs R_OK/W_OK/X_OK into ONE mode and makes a single
 * VOP_ACCESS call; its ufs_access ends `if ((ip->i_mode & mode) != 0)', which
 * passes when ANY requested bit is granted -- so `access(f, R_OK|W_OK)' on a
 * mode 0444 file answers YES on Reno.  2.11BSD (usr/sys/sys/ufs_syscalls.c:383)
 * asks one bit at a time and is right.  ufs_access is unchanged and stays
 * upstream's; what changes is that callers pass a single bit, which is now the
 * rule this file states.
 *
 * fmode == 0 IS F_OK, existence only: the caller's namei succeeding is the
 * whole answer and nothing is checked here.
 *
 * vn_writechk BEFORE the W_OK check, as Reno's saccess has it: a read-only
 * mount is EROFS, not EACCES, and asking the mode about a volume that refuses
 * every write would answer the wrong question.
 */
int
vn_access(vp, fmode)
struct vnode *vp;
int           fmode;
{
    int error;

    if (fmode & R_OK) {
        error = VOP_ACCESS(vp, VREAD, (char *)0);
        if (error)
            return (error);
    }
    if (fmode & W_OK) {
        error = vn_writechk(vp);
        if (error)
            return (error);
        error = VOP_ACCESS(vp, VWRITE, (char *)0);
        if (error)
            return (error);
    }
    if (fmode & X_OK) {
        error = VOP_ACCESS(vp, VEXEC, (char *)0);
        if (error)
            return (error);
    }
    return (0);
}

/* vn_execchk -- exec(2)'s permission tests, both performed in THIS bank.
 *
 * apple/fgx#416.  Load_Binary opened the image and read it; nothing between
 * the open and the first instruction asked the mode, so a file was executable
 * exactly when it was readable -- and every file staged was 0644.
 *
 * TWO TESTS, ANSWERING DIFFERENT QUESTIONS, which is 4.3BSD-Reno
 * kern/kern_exec.c:129-138:
 *
 *   again:
 *      if (error = VOP_ACCESS(vp, VEXEC, cred))
 *              goto bad;
 *      if ((p->p_flag & STRC) && (error = VOP_ACCESS(vp, VREAD, cred)))
 *              goto bad;
 *      if (vp->v_type != VREG ||
 *          (vattr.va_mode & (VEXEC|(VEXEC>>3)|(VEXEC>>6))) == 0) {
 *              error = EACCES;
 *              goto bad;
 *      }
 *
 * and 2.11BSD usr/sys/sys/kern_exec.c:86-93 in its own idiom (`access(ip,
 * IEXEC)', then `(ip->i_mode & (IEXEC|(IEXEC>>3)|(IEXEC>>6))) == 0').  The
 * first is per-caller and root passes it always.  The SECOND takes no
 * credential and refuses a file with no execute bit in any triple to
 * everybody, root included -- which is the test this volume needed, where
 * root runs everything on the primary console.
 *
 * IT ANSWERS AN ERRNO AND TAKES NO vattr, which is vn_setsize's rule one
 * screen down -- the structure stays on the side that fills it -- and here
 * there is a measured reason too: VOP_GETATTR reached from Load_Binary's
 * context with a vattr the FAR BANK owns corrupts a live pty session, while
 * VOP_ACCESS from that same context is safe any number of times.  Bisected to
 * the single call and filed as apple/fgx#417; keeping both tests here costs
 * one VFSCORE slot and hands the far bank an int.
 *
 * THE TRACED-PROCESS ARM IS ABSENT because there is no ptrace and so no
 * p_flag & STRC to read.  Said rather than dropped: the day a debugger
 * arrives, a traced exec of an unreadable binary must be refused too, and
 * this is the line it goes on.
 *
 * MNT_NOEXEC IS TESTED FIRST, ahead of the mode and ahead of the credential,
 * which is upstream's order (kern_exec.c:119).
 */
int
vn_execchk(vp)
struct vnode *vp;
{
    struct vattr va;
    int          error;

    if (vp->v_mount != (struct mount *)0 &&
        (vp->v_mount->mnt_flag & MNT_NOEXEC))
        return (EACCES);
    error = VOP_ACCESS(vp, VEXEC, (char *)0);
    if (error)
        return (error);
    error = VOP_GETATTR(vp, &va, (char *)0);
    if (error)
        return (error);
    if (vp->v_type != VREG ||
        (va.va_mode & (VEXEC | (VEXEC >> 3) | (VEXEC >> 6))) == 0)
        return (EACCES);
    return (0);
}

/* vn_execsugid -- whose credentials does this image run with?
 *
 * apple/fgx#416.  4.3BSD-Reno kern/kern_exec.c:123-127, which runs before the
 * access tests and after the getattr:
 *
 *      if ((vp->v_mount->mnt_flag & MNT_NOSUID) == 0) {
 *              if (vattr.va_mode & VSUID)
 *                      uid = vattr.va_uid;
 *              if (vattr.va_mode & VSGID)
 *                      gid = vattr.va_gid;
 *      }
 *
 * 2.11BSD usr/sys/sys/kern_exec.c:79-84 is the same block against i_mode.
 * `uid' and `gid' start as the CALLER's effective ids (Reno :115-116), so a
 * file with neither bit changes nothing -- which is what -1 says here.
 *
 * ONE ID PER CALL, and `want' selects it, because this answers an int for
 * apple/fgx#417's reason: nothing that crosses back to the far bank may be a
 * structure.  The two calls cost a second VOP_GETATTR on the exec path and buy
 * one VFSCORE slot instead of three.
 *
 * MNT_NOSUID IS THE MOUNT'S VETO and it is read here rather than beside
 * MNT_NOEXEC in vn_execchk, because the two refuse different things: NOEXEC
 * refuses the exec, NOSUID allows it and declines only the privilege.
 */
int
vn_execsugid(vp, want)
struct vnode *vp;
int           want;             /* 0 = the uid, 1 = the gid */
{
    struct vattr va;

    if (vp->v_mount != (struct mount *)0 &&
        (vp->v_mount->mnt_flag & MNT_NOSUID))
        return (-1);
    if (VOP_GETATTR(vp, &va, (char *)0))
        return (-1);
    if (want == 0)
        return ((va.va_mode & VSUID) ? (int)va.va_uid : -1);
    return ((va.va_mode & VSGID) ? (int)va.va_gid : -1);
}

/* vfs_setattr -- chmod(2) and chown(2) reaching the filesystem.  UFS 2.6.
 *
 * ONE FUNCTION FOR TWO SYSCALLS, AND THAT IS UPSTREAM'S SHAPE RATHER THAN A
 * SAVING.  4.3BSD-Reno's chmod (kern/vfs_syscalls.c:1129), chown (:1197) and
 * truncate (:1308) are the same seven lines three times over: namei, then
 * VATTR_NULL, then ONE field, then VOP_SETATTR, then vput.  Only the field
 * and the namei flags differ.  Collapsing them here costs one KFAR slot
 * instead of three -- and there are two left -- but the argument for it is
 * that the filesystem interface is VOP_SETATTR either way, and three
 * near-identical wrappers would be three places to get the vattr fill wrong.
 *
 * VA_UNSET MEANS "LEAVE IT" and is how one entry serves both callers: chmod
 * passes a mode with the owner unset, chown passes an owner with the mode
 * unset, and `chown f -1 20' leaves the uid alone through the same mechanism
 * one level down in ufs_setattr, which fills a missing half from the inode.
 *
 * `follow' IS THE CALLER'S AND THE TWO SYSCALLS DISAGREE.  chmod resolves
 * with FOLLOW; chown resolves with NOFOLLOW -- upstream's :1204 against
 * :1136, and it is worth stating because it looks like an inconsistency and
 * is not.  A symlink has no mode of its own worth changing, so chmod means
 * the target; a symlink DOES have an owner, so 4.3BSD's chown means the link.
 * (POSIX later split that into chown/lchown; Reno is the ancestor this tree
 * follows.)
 *
 * NO LOCKLEAF, so no vput.  Upstream locks the leaf because VOP_SETATTR is
 * documented as taking a locked inode and because its chown1/chmod1 say
 * "inode must be locked before calling".  This port takes no vnode locks at
 * all -- ufs_rename's header records the same absence and the same reason --
 * so the release is vrele, as it is in vfs_statfs beside this.
 */
int
vfs_setattr(pid, path, follow, mode, uid, gid, atime, mtime)
int            pid;
char          *path;
int            follow;
int            mode;
int            uid;
int            gid;
time_t         atime;
time_t         mtime;
{
    struct nameidata *ndp;
    struct vattr      vat;
    struct vnode     *vp;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    nd_begin(ndp, follow ? (LOOKUP | FOLLOW) : LOOKUP, vfs_cdir(pid), path);

    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;

    /* EROFS BEFORE THE WORK, which is upstream's order at :1148 and is the
     * one place a read-only mount is caught: ufs_setattr itself does not
     * consult mnt_flag, exactly as Reno's does not. */
    if (vp->v_mount != (struct mount *)0 &&
        (vp->v_mount->mnt_flag & MNT_RDONLY)) {
        vrele(vp);
        return (EROFS);
    }

    vattr_null(&vat);
    if (mode != VA_UNSET)
        vat.va_mode = (unsigned short)(mode & 07777);
    if (uid != VA_UNSET)
        vat.va_uid = (uid_t)uid;
    if (gid != VA_UNSET)
        vat.va_gid = (gid_t)gid;
    /* THE TIMESTAMPS RIDE THE SAME ENTRY, which is this function's own
     * argument extended by one syscall.  Reno has chmod, chown and utimes as
     * three separate calls that differ ONLY in which field of the vattr they
     * fill and all end in one VOP_SETATTR (kern/vfs_syscalls.c: chmod1 :1148,
     * chown1 :1189, utimes :1269) -- the note above already says that about
     * mode and owner, and time is the third of the same shape.  A sibling
     * function would be a second copy of the walk, the EROFS arm and the
     * release, in a module with 1,356 bytes free. */
    if (atime != (time_t)VA_UNSET)
        vat.va_atime = atime;
    if (mtime != (time_t)VA_UNSET)
        vat.va_mtime = mtime;

    error = VOP_SETATTR(vp, &vat, (char *)0);
    vrele(vp);
    return (error);
}


/* vfs_link -- link(2).  4.3BSD-Reno kern/vfs_syscalls.c:719.  UFS 2.6.
 *
 * A SECOND NAME FOR ONE INODE, and the last of the namespace operations to
 * arrive.  ufs_link has been in the vnodeops table since 1.12c-b and driven by
 * ufs_wprobe; what was missing was every layer above it, so `ln a b' answered
 * ENOSYS from libc while `ln -s a b' worked.
 *
 * TWO WALKS THROUGH ONE nameidata, which is upstream's shape and not a saving:
 * Reno reuses u.u_nd for both, keeping only `vp' from the first.  The order is
 * load-bearing -- the TARGET is resolved first and with FOLLOW, so `ln
 * symlink-to-f g' makes a second name for f rather than for the symlink; the
 * LINKNAME is resolved second with CREATE|LOCKPARENT, which is what leaves
 * ni_dvp held for VOP_LINK to enter the record into.
 *
 * pid AND NO dvp, unlike its siblings above.  Both paths start from the same
 * place -- the caller's directory -- so passing it twice would be two crossings
 * of one fact; vfs_setattr took the same shape one increment earlier.
 *
 * EXDEV IS UNREACHABLE TODAY and is here because it is upstream's check: there
 * is one UFS mount, so two names cannot land on different ones.  The day a
 * second volume is mountable, a missing test is a hard link across filesystems
 * -- an inode number pointing into the wrong i-list, which is corruption
 * rather than a refusal.
 *
 * A DIRECTORY CAN BE LINKED HERE AND UPSTREAM ONLY LETS ROOT DO IT.  Reno's
 * gate is `vp->v_type == VDIR && suser(cred, &u.u_acflag)'; this kernel has no
 * credential, every process is uid 0 by the same reasoning ufs_setattr's mode
 * and owner arms landed on, so the gate passes for everyone.  That is a real
 * hazard and link(2)'s BUGS section says so: `ln d d2' makes a cycle no fsck
 * can fully repair, and 4.4BSD later removed the ability from root as well.
 * It is NOT quietly refused here, because a refusal would be this port
 * diverging from its source on a judgement rather than on a reading.
 *
 * NO VOP_ABORTOP.  vnode.h records why the macro is still absent -- no caller
 * -- and for UFS it reduces to the vrele/vput this does inline, which is what
 * vfs_symlink's error arm does two functions up.
 */
int
vfs_link(pid, target, linkname)
int   pid;
char *target;
char *linkname;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    struct vnode     *xp;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    nd_begin(ndp, LOOKUP | FOLLOW, vfs_cdir(pid), target);
    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;

    /* A DIRECTORY IS NOT LINKED, TO ANYBODY -- vfs_unlink's arm exactly, and
     * for the same reason.  Both upstreams gate this on the superuser and
     * check it HERE, on the target, between the two nameis: 2.11BSD's
     * `if ((ip->i_mode&IFMT) == IFDIR && !suser())' (ufs_syscalls.c:254) and
     * Reno's `if (vp->v_type == VDIR && (error = suser(...)))'
     * (kern/vfs_syscalls.c:737).
     *
     * REFUSING ROOT TOO IS THE DIVERGENCE AND IT IS DELIBERATE: a second name
     * for a directory is a cycle in the tree, which fsck cannot repair and
     * which nothing in this system needs -- ufs_mkdir writes `.' and `..'
     * itself.  vfs_unlink already made the same choice, and a link that only
     * root can create is a link only root can fail to remove. */
    if (vp->v_type == VDIR) {
        vrele(vp);
        return (EPERM);
    }

    nd_begin(ndp, CREATE | LOCKPARENT, vfs_cdir(pid), linkname);
    error = namei(ndp);
    if (error) {
        vrele(vp);
        return (error);
    }

    xp = ndp->ni_vp;
    if (xp != (struct vnode *)0)
        error = EEXIST;
    else if (vp->v_mount != ndp->ni_dvp->v_mount)
        error = EXDEV;

    if (error == 0)
        error = VOP_LINK(vp, ndp);
    else if (xp != (struct vnode *)0)
        vrele(xp);

    /* AND THE PARENT ALWAYS, which is vfs_mkdir's line for its reason:
     * ufs_link reads ni_dvp -- direnter writes the record into it -- and never
     * touches its reference or its lock.  UPSTREAM DOES NOT DO THIS AND MUST
     * NOT: Reno's direnter ends in `iput(dp)', consuming the parent, so its
     * link() releases ni_dvp only on the error arm.  This tree's direnter
     * leaves it to the caller, which is why every namespace operation in this
     * file ends the same way and why copying Reno's release pattern here would
     * have leaked a vnode on every successful link. */
    if (ndp->ni_dvp == xp)
        vrele(ndp->ni_dvp);
    else
        vput(ndp->ni_dvp);
    vrele(vp);
    return (error);
}


/* vfs_sync1 -- VFS_SYNC on one mount.  apple/fgx#332.
 *
 * vfs_statfs1'S TWIN.  The mount-list WALK stays in the far bank beside the
 * list; only the per-mount VFS_SYNC crosses, which is exactly how getfsstat(2)
 * is split.
 */
int
vfs_sync1(mp)
struct mount *mp;
{
    if (mp == (struct mount *)0)
        return (EINVAL);
    if (mp->mnt_flag & MNT_RDONLY)
        return (0);
    return (VFS_SYNC(mp, MNT_NOWAIT));
}


/* vfssw -- the filesystem type switch.  4.3BSD-Reno kern/vfs_conf.c:
 *
 *      struct vfsops *vfssw[] = {
 *              (struct vfsops *)0,     -- 0 = MOUNT_NONE
 *              &ufs_vfsops,            -- 1 = MOUNT_UFS
 *
 * RENO'S TABLE IS INITIALISED AND THIS ONE IS HANDED ITS ROWS, because a
 * filesystem here is a MODULE and not something linked into this bank: the
 * address of `ufs_vfsops' is inside ufs.mod and this bank cannot name it.  So
 * each filesystem's mod_init hands its row over through vfs_setvfsops, which is
 * the arrangement vfs_setspecops and vfs_setcacheops already have.  A row a
 * module never handed over stays null, which is Reno's "not configured" and
 * reads as ENODEV in vfs_mountat exactly as it does upstream.
 *
 * IT LIVES HERE BECAUSE ITS WRITERS DO.  A module cannot reach the far bank, so
 * the table cannot be vfs_syscalls.c's the way Reno's mount() finds it; the far
 * bank asks for a row through vfs_getvfsops and does the dispatch itself. */
static struct vfsops *vfssw[MOUNT_MAXTYPE + 1];

/* vfs_setvfsops -- a filesystem's mod_init handing over its vfssw row.  The
 * pointer is FAR and stays far, which is what makes the dispatch through it
 * land in the owning module; see vfs_setspecops. */
int
vfs_setvfsops(type, ops)
int            type;
struct vfsops *ops;
{
    /* Row 0 stays null: MOUNT_NONE is "no filesystem" in Reno's table too. */
    if (type == MOUNT_NONE || (unsigned)type > MOUNT_MAXTYPE)
        return (EINVAL);
    vfssw[type] = ops;
    return (0);
}


/* vfs_getvfsops -- vfssw[type], or null for a type with no row.  The bound is
 * Reno's own, from mount(): `(unsigned long)uap->type > MOUNT_MAXTYPE ||
 * vfssw[uap->type] == (struct vfsops *)0' is ENODEV, and vfs_mountat asks both
 * halves as the one question this answers.
 *
 * A LOOKUP AND NOT A DISPATCH, and that is the point of it.  It returns before
 * the mount does anything, so the call chain under VFS_MOUNT -- the deepest
 * per-task kernel stack in the system -- carries none of it. */
struct vfsops *
vfs_getvfsops(type)
int type;
{
    if ((unsigned)type > MOUNT_MAXTYPE)
        return ((struct vfsops *)0);
    return (vfssw[type]);
}
