/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/vfs_syscalls.c
 *   Ported from kern/vfs_syscalls.c and kern/sys_generic.c, 4.3BSD-Reno.
 *   Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 */
/* vfs_syscalls.c -- the bodies of open/read/write/lseek, over the file table
 * and the fileops vector.  UFS 1.7d.
 *
 * TWO UPSTREAM FILES, because Reno splits these by what they dispatch on, and
 * the split is worth preserving in the comments even though FGX has too few of
 * them to justify two files: `open` and `lseek` are kern/vfs_syscalls.c (they
 * know about vnodes); `read` and `write` are kern/sys_generic.c (they know only
 * about `struct file` and go through f_ops, which is exactly why a socket and
 * a file can share them).
 *
 *============================================================================
 * These are the syscall BODIES without the syscall LAYER: they take a pid and
 * already-marshalled kernel arguments, and they return an errno.  The layer
 * that turns a 65816 syscall frame into those arguments -- copying a path out
 * of the caller's bank, validating a user buffer -- is the kernel's assembly
 * (src/kernel/syscall.s and the far-bank shims), which calls these.
 *
 * WHY THE READER HAS TO BE HERE AND NOT IN THE PROBE.  The probe lives in
 * ufsprobe.mod, a different bank, and reaches this module through generated
 * shims (src/modules/ufsprobe/vfs_import.s).  Every dereference of f_ops
 * happens inside the image that owns the table, exactly as VOP_ dispatch
 * happens in the module that owns the vnode layer.
 *
 *----------------------------------------------------------------------------
 * BUFFERS ARE KERNEL-SPACE, AND THAT IS A DELIBERATE NARROWING, not an
 * oversight.  Every uio built below is UIO_SYSSPACE where Reno's is
 * UIO_USERSPACE.  FGX's "user space" is another BANK, not another address
 * space, so the marshalling question is a bank question and it belongs to the
 * caller that has the bank -- see the head note.  When I3 supplies one, these
 * take a segflg argument instead of hardcoding it, which is a smaller change
 * than it looks because uiomove already honours both.
 *
 * THE pid ARGUMENT IS RENO'S u.u_ofile MADE EXPLICIT, for the reason
 * vfs_file.c's header states at length: kernel C has no u-area, so every
 * per-process lookup takes the pid Reno takes implicitly.  fdcurrent() and
 * ndget() are the interfaces that ask "who am I"; these take the pid because a
 * probe must be able to drive them with no current process (the boot path).
 */

#include "fsparam.h"
#include "vnode.h"
#include "mount.h"
#include "namei.h"
#include "file.h"
#include "uio.h"
#include "vfsops.h"
#include "statlayout.h"

extern struct file  *getf();
extern void kc_panic();          /* far/kc_sys.s: name it, then halt */
extern struct file **fdbase();
extern struct nameidata *ndslot();
extern int  namei();            /* vfs.mod, through vfs_import.s -- 1.8b-2 */
extern struct vfsops *vfs_getvfsops();  /* vfs.mod, through vfs_import.s --
                                         * vfssw[].  A pointer return, so
                                         * declared per TU: #293 */
extern void vrele();
extern void bflush();           /* vfs.mod, through vfs_import.s -- sync(2)'s
                                 * delayed-write flush, apple/fgx#398 */
extern void vput();     /* VOP_UNLOCK + vrele.  DECLARED PER TU: #293 */
extern struct vnode *vfs_cdir();  /* likewise -- a pointer return */
extern int  vfs_dounmount();    /* vfs.mod, through vfs_import.s -- 1.8b-3c */
extern int  kc_curpid();
extern int  root_status;    /* root_mount.c -- 1 once the root is ours */
static int  root_stat_1();  /* stat/lstat's shared body; follow is the flag */
int         vn_stat();      /* Reno kern/vfs_vnops.c: a vnode -> struct stat */
int         fp_isvn();      /* a vnode descriptor: f_ops == &vnops */
extern int  falloc();
extern int  fdrelease();
extern int  vn_open();
extern int  vn_getattr();       /* VOP_GETATTR, dispatched in vfs.mod */
extern int  vn_execchk();       /* exec(2)'s permission pair, in vfs.mod */
extern int  vn_execsugid();     /* and whose ids it runs with */
extern int  vn_access();        /* 2.6: the per-bit check, likewise in vfs.mod
                                 * -- it needs VOP_ACCESS and vn_writechk, and
                                 * both live there.  vfs_import.s carries it. */
extern int  vn_setsize();       /* VOP_SETATTR, likewise -- ftruncate */
extern int  ufs_fsyncvp();      /* ufs.mod, UFSCORE_Fsync -- apple/fgx#355 */
extern int  vfs_fchdir();       /* the cwd table is vfs.mod's -- fchdir */
extern int  vfs_listdir();      /* vfs.mod: listdir(2) resolved and walked */
extern int  vfs_readlink();     /* vfs.mod, VFSCORE_Readlink -- #326 */
extern int  closef();

/* THE vnops VECTOR LIVES HERE, with its dispatcher.  This file compiles into
 * the FAR bank, a KFAR_FN_PTR can only name a label in this link unit, and the
 * functions it names are vfs.mod's.
 *
 * THE NAMES BELOW RESOLVE TO THE FAR-SIDE SHIMS, not to vfs.mod's functions --
 * src/kernel/far/vfs_import.s defines vn_read, vn_write, vn_ioctl, vn_select
 * and vn_close in THIS bank, each one copying its arguments and pile-calling
 * across.  So the vector is same-bank, the dispatch is an ordinary indirect
 * call, and exactly one thing crosses: the shim. */
extern int vn_read(), vn_write(), vn_ioctl(), vn_select(), vn_close();

struct fileops vnops = {
    vn_read,            /* fo_read   */
    vn_write,           /* fo_write  */
    vn_ioctl,           /* fo_ioctl  */
    vn_select,          /* fo_select */
    vn_close            /* fo_close  */
};


/* vfs_open -- open(2)'s body.  Reno kern/vfs_syscalls.c:open().
 *
 * THE ORDER IS UPSTREAM'S AND THE UNWIND IS THE REASON.  falloc first, then
 * vn_open: a failed open must leave the descriptor free, and Reno does that by
 * clearing u_ofile[indx] on the error path rather than by opening first and
 * allocating after.  Allocating second would mean a successfully opened vnode
 * with nowhere to put it, which is a vrele on a path that is easy to forget.
 *
 * WHAT IS NOT CARRIED: `p->p_dupfd` and the dupfdopen retry.  That is Reno's
 * /dev/fd machinery -- a driver whose open(2) means "give me a copy of
 * descriptor N" -- and there is no fdesc filesystem here.  Carrying the retry
 * would be a branch on a field nothing sets.  ERESTART is not translated to
 * EINTR either: nothing in this tree returns ERESTART from an open yet.
 */
int
vfs_open(pid, dvp, path, fmode, cmode, fdp)
int           pid;
struct vnode *dvp;
char         *path;
int           fmode;
int           cmode;
int          *fdp;
{
    struct file       *fp;
    struct file      **fdt;
    int                fd;
    int                error;

    if (fdp == (int *)0)
        return (EINVAL);

    error = falloc(pid, &fp, &fd);
    if (error)
        return (error);

    error = vfs_openat(pid, fd, dvp, path, fmode, cmode);
    if (error) {
        /* UNWIND IN THE ORDER RENO UNWINDS: drop the descriptor's claim on the
         * struct first, then release the struct.  falloc set f_count to 1 and
         * wired fdt[fd] to it; closef with the descriptor still pointing at it
         * would leave a dangling pointer for the next getf to hand out, which
         * is the hazard fdrelease exists to make impossible. */
        fdt = fdbase(pid);
        if (fdt != (struct file **)0)
            fdt[fd] = (struct file *)0;
        (void)closef(fp);
        return (error);
    }
    *fdp = fd;
    return (0);
}


/* vfs_openat -- open(2)'s second half: fill a descriptor the caller ALREADY
 * HOLDS.  UFS 1.7d I3.
 *
 * THE SPLIT IS NOT COSMETIC.  Reno's open(2) allocates the descriptor and then
 * opens the vnode into it, in that order and for the reason vfs_open's header
 * gives.  FGX has a second caller for the second half alone: the core bank's
 * `/dev' hook, whose descriptor was allocated by _Fcb_Alloc because THE fd
 * TABLE IS THE AUTHORITY ON DESCRIPTOR NUMBERS -- _Fd_Dup writes it without
 * ever reaching falloc, so the file table cannot know which numbers are live
 * (fcb.s says the same at more length, and the reversal has a boot failure
 * behind it).  So the core allocates, and this fills.
 *
 * The unwind stays with the ALLOCATING half above: a caller that did not
 * allocate the descriptor must not release it, and the core's hook frees its
 * own FCB on the error return.
 */
int
vfs_openat(pid, fd, dvp, path, fmode, cmode)
int           pid;
int           fd;
struct vnode *dvp;
char         *path;
int           fmode;
int           cmode;
{
    struct file       *fp;
    struct nameidata  *ndp;
    int                error;

    fp = getf(pid, fd);
    if (fp == (struct file *)0)
        return (EBADF);

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    /* THE CALLER OWNS THE WALK'S INPUTS AND vn_open OWNS ni_nameiop, which is
     * the division vfs_vnops.c states: the MODE decides the operation, so a
     * caller that set ni_nameiop would be asserting its own idea of that
     * mapping.
     *
     * `dvp` IS RENO'S u.u_cdir, PASSED RATHER THAN READ, for exactly the
     * reason vfs_file.c passes a pid: Reno's open(2) never sets ni_cdir
     * because namei reads the u-area itself, and kernel C here has no u-area
     * to read.  Zero means "start at the system root" (namei's own
     * convention -- vfs_lookup.c:261 falls back to `rootdir`), so an absolute
     * path behaves the same either way.
     *
     * IT IS AN ARGUMENT AND NOT A GLOBAL ON PURPOSE.  The alternative was to
     * set `rootdir` around the call; that is a
     * process-wide mutation to serve one walk, and #114's lesson is that a
     * path model with two authorities is worse than one honestly absent.
     * When there is a per-process cwd, I3 passes it here and nothing else
     * changes.
     *
     * ni_rdir STAYS 0 -- that is chroot(2), which does not exist here.  Both
     * it and ni_vp/ni_dvp are cleared rather than left as the slot holds them:
     * an ndslot persists across walks, so a stale ni_vp would be a vnode this
     * open never referenced and vn_open's error paths would release it. */
    ndp->ni_dirp   = path;
    ndp->ni_segflg = UIO_SYSSPACE;
    ndp->ni_cdir   = dvp;
    ndp->ni_rdir   = (struct vnode *)0;
    ndp->ni_vp     = (struct vnode *)0;
    ndp->ni_dvp    = (struct vnode *)0;

    error = vn_open(ndp, fmode, cmode);
    if (error)
        return (error);

    fp->f_flag   = fmode & FMASK;   /* Reno kern/vfs_syscalls.c:578 */
    fp->f_type   = DTYPE_VNODE;
    fp->f_ops    = &vnops;
    fp->f_data   = (char *)ndp->ni_vp;
    /* THE OFFSET IS RESET AND UPSTREAM DOES NOT DO THIS, because upstream's
     * struct came from falloc and falloc's slot is fresh.  Here the descriptor
     * may be a REUSED slot the core allocated, and vn_read advances f_offset
     * -- a stale one would start the first read of a new file part way in. */
    fp->f_offset = 0;
    return (0);
}


/* fdcheck -- the three-part guard every fd-taking syscall opens with.
 *
 * Reno spells it inline at each site as one condition:
 *
 *      if (((unsigned)uap->fdes) >= NOFILE ||
 *          (fp = u.u_ofile[uap->fdes]) == NULL ||
 *          (fp->f_flag & FREAD) == 0)
 *              return (EBADF);
 *
 * It is factored out here for the reason getf was factored out in vfs_file.c
 * (2.11BSD does the same): three copies of a bounds check is three chances to
 * write one of them with the wrong comparison, and the bound is FS_MAX_FDS
 * rather than NOFILE so the copies would not even look alike.
 *
 * `want` IS 0 FOR "no mode requirement", which lseek needs: seeking is neither
 * a read nor a write and upstream's lseek checks no mode bit.
 */
static struct file *
fdcheck(pid, fd, want)
int pid;
int fd;
int want;
{
    struct file *fp;

    fp = getf(pid, fd);
    if (fp == (struct file *)0)
        return ((struct file *)0);
    if (want && (fp->f_flag & want) == 0)
        return ((struct file *)0);
    return (fp);
}


/* rwuio -- 2.11BSD sys_generic.c:127-171: hand a uio that read(), write(),
 * readv() or writev() built to the descriptor's fo_rw ONCE, and report
 * `count - uio_resid'.  The direction is the uio's own uio_rw.
 *
 * The uio arrives BUILT and CHECKED: the core bank copies a vector in, refuses
 * more than 16 entries, and sums the lengths into uio_resid (_Sys_UioVec).
 * What is left here is upstream's descriptor check and the call.
 *
 * THE COUNT OUTRANKS AN INTERRUPTION, as upstream's setjmp arm has it: `if
 * (uio->uio_resid == count) return; else u.u_error = 0'.  The count goes back
 * through *cntp on every path and dev_rw prefers it to the errno, so a
 * transfer that moved bytes and was then interrupted reports the bytes.
 */
int
rwuio(pid, fd, uio, cntp)
int          pid;
int          fd;
struct uio  *uio;
int         *cntp;
{
    struct file *fp;
    int          cnt;
    int          error;

    fp = fdcheck(pid, fd, uio->uio_rw == UIO_WRITE ? FWRITE : FREAD);
    if (fp == (struct file *)0)
        return (EBADF);
    if (fp->f_ops == (struct fileops *)0)
        return (EBADF);     /* not a vector-dispatched descriptor -- see head */
    cnt = (int)uio->uio_resid;
    if (uio->uio_rw == UIO_WRITE)
        error = (*fp->f_ops->fo_write)(fp, uio);
    else
        error = (*fp->f_ops->fo_read)(fp, uio);
    *cntp = cnt - (int)uio->uio_resid;
    return (error);
}


/* rwcommon -- read(2) and write(2) over one buffer: the one-entry uio of
 * 2.11BSD's read()/write() (sys_generic.c:38-54, :84-100), handed to rwuio.
 * The binary loader's ld_read is its caller now; read(2) and write(2) from
 * userland reach rwuio through dev_rw with the uio the core bank built.
 */
static int
rwcommon(pid, fd, buf, len, cntp, iswrite)
int   pid;
int   fd;
char *buf;
int   len;
int  *cntp;
int   iswrite;
{
    struct uio   auio;
    struct iovec aiov;

    if (cntp == (int *)0)
        return (EINVAL);
    if (len < 0)
        return (EINVAL);
    /* AND A LENGTH THE FIELD CANNOT HOLD, which is apple/fgx#165's first
     * obligation written as code rather than as the note below it.  With a
     * 16-bit `int' this is provably never taken -- `len < 0' has already
     * removed everything above 32767 -- and that is the point: it is written
     * against UIO_MAXRESID, the width of uio_resid, so it becomes live by
     * itself the day `len' widens or `int' does.  The note below explains why
     * that day is the one to watch for; this is what will notice it. */
    if ((unsigned long)len > (unsigned long)UIO_MAXRESID)
        return (EINVAL);

    aiov.iov_base  = buf;
    aiov.iov_len   = len;
    auio.uio_iov   = &aiov;
    auio.uio_iovcnt = 1;
    /* THIS CAST IS LOSSLESS, AND ONLY BECAUSE `int' IS 16 BITS HERE.
     *
     * `uio_resid' and `iov_len' are `unsigned short', following 2.11BSD, whose
     * own header records the decision -- "changing uio_resid to u_short from
     * int" (vendor/2.11BSD/usr/sys/h/uio.h:34-37).  What unsigned gives up is
     * Reno's overflow detector, which sums the regions and tests the sign;
     * apple/fgx#165 is the obligation that comes with that.
     *
     * It is not owed yet, and the reason is the width rather than the iovec
     * count: fcc's `int' is 16 bits (asked of the compiler: sizeof int/short/
     * long/char emits 2, 2, 4, 1), so `len' is 16-bit signed, the `len < 0'
     * refusal above takes the top half of the range, and every value that
     * survives -- 0..32767 -- round-trips through unsigned short exactly.  The
     * `cnt - uio_resid' in rwuio is safe for the same reason.
     *
     * THE GUARD IS OWED THE MOMENT `int' STOPS BEING 16 BITS OR THIS COUNT
     * WIDENS.  A `long len' makes `len < 0' stop being sufficient, because a
     * positive long can exceed 65535 and this cast would then take the low
     * half in silence.  readv/writev's summing check is _Sys_UioVec's. */
    auio.uio_resid = (unsigned short)len;
    auio.uio_segflg = UIO_SYSSPACE;
    auio.uio_rw    = iswrite ? UIO_WRITE : UIO_READ;

    return (rwuio(pid, fd, &auio, cntp));
}


/* vfs_read -- read(2)'s body.  Reno kern/sys_generic.c:read(). */
int
vfs_read(pid, fd, buf, len, cntp)
int   pid;
int   fd;
char *buf;
int   len;
int  *cntp;
{
    return (rwcommon(pid, fd, buf, len, cntp, 0));
}


/* vfs_write -- write(2)'s body.  Reno kern/sys_generic.c:write(). */
int
vfs_write(pid, fd, buf, len, cntp)
int   pid;
int   fd;
char *buf;
int   len;
int  *cntp;
{
    return (rwcommon(pid, fd, buf, len, cntp, 1));
}



/*============================================================================
 * mount(2).  UFS 1.8b-2.  Reno kern/vfs_syscalls.c:mount(), with
 * 2.11BSD usr/sys/sys/ufs_mount.c:smount() consulted where the two differ.
 *============================================================================
 *
 * NO VNODE FIELD WAS ADDED FOR THIS, and the first cut of this increment was
 * planned around adding one.  Reno's `v_mountedhere' is not a member: it is an
 * ARM OF THE `v_un' UNION -- the same word as `vu_socket' and `vu_specinfo'
 * (4.3BSD-Reno sys/vnode.h) -- and vnode.h here already carries that word,
 * declared as its specinfo arm with the note that "mountedhere arrives with
 * mount at 1.6 ... and each will cast at the two or three places that touch
 * it".  This is those places.  sizeof(struct vnode) does not move, so
 * VNODE_FIXED, VFS_VNODE_SIZE, the vnode pool arena and vfslayout.c's boot
 * assertion are all untouched.
 *
 * THE OVERLAP IS RENO'S SEMANTICS AND NOT A TRICK: a covered directory is
 * VDIR and a VDIR never has specinfo, so the two arms cannot both be live.
 * getnewvnode clears the word (vfs_subr.c:285), which is what makes the null
 * test below mean "nothing is mounted here" on a vnode that has never been a
 * device.
 *
 * THE MOUNT TABLE IS A STATIC AND RENO'S IS A malloc.  Reno allocates a
 * `struct mount' per mount and links it into a circular list off `rootfs';
 * there is no allocator on this side of the seam, so the table is carved here
 * and a slot is free when mnt_op is null.  VFS_NMOUNT slots, which is the
 * number ufs.mod sizes its ufsmount pool to and for the same reason -- two
 * pools that can disagree about how many mounts exist is a refusal the caller
 * cannot explain.
 *
 * 2.11BSD IS THE AUTHORITY FOR THE FULL-TABLE ERRNO, because it is the tree
 * with a static mount table: `mountfs' scans `mount[NMOUNT]' and ends
 * `error = EMFILE;  /-- needs translation --/'.  The comment is upstream's
 * own and is kept in spirit here: EMFILE is what a full mount table has always
 * answered, and inventing a better one would make this the only system that
 * does.
 *
 * IT IS ZEROED BY A CALL AND NOT BY A LAZY GUARD, and the difference is the
 * whole reason this note is here.  The first cut carried `static int
 * vfs_mountinit' with the loop behind it, on apple/fgx#219's lesson: a
 * `struct mount' holding whatever bytes sat at its address ORs a stale
 * MNT_NODEV into mnt_flag and makes spec_open refuse every node under /dev
 * while the mount reports success.  But A GUARD FLAG LIVES IN THE STORAGE IT
 * DISTRUSTS -- if the bytes were garbage the flag would be garbage and the
 * loop would be skipped.  It could not defend against the thing it named.
 *
 * AND THE TWO AUTHORITIES ON THIS BANK DISAGREE, which is why it is not
 * simply dropped.  Measured today: `_vfs_syscalls_vfs_mounttab DS 1820' is
 * 1,820 zeros in bin/fgxfar.bin, because fcc's data segment emits its bytes
 * into the image.  But far.s's own static region is a DUM block chosen
 * expressly so it does NOT reach the image, and dev_mount.c records a static
 * in this bank that read garbage and cost a boot ("a `if (dev_mounted)
 * return' guard READ A GARBAGE FLAG and refused to mount").  A bank with both
 * kinds of storage in it is not a bank to reason about from one measurement.
 *
 * So vfs_mountinit() is CALLED, once, from the far bank's boot path -- which
 * is what ufs_init does for the ufsmount pool, and for the same reason.  It
 * depends on nothing in the storage it clears.
 *
 * WHAT THE PER-SLOT WRITES BELOW ARE FOR is the SECOND use of a slot, which
 * the image has nothing to do with: a slot handed back after a failed mount
 * carries the flags of the attempt that failed, and the OR would preserve
 * them.
 *
 * THERE IS A MOUNT LIST AGAIN, AND THIS PARAGRAPH USED TO SAY THERE WAS NOT.
 * What it said was: "Reno links each mount after `rootfs' so getfsstat(2) and
 * sync(2) can walk them; neither exists here, and a list with no walker is a
 * pointer pair to get wrong.  The table IS the enumeration when something
 * needs one."  Every word of that was true and the condition it named has now
 * been met -- getfsstat(2) is that something (apple/fgx#329, df(1)).
 *
 * AND THE TABLE COULD NOT HAVE SERVED.  The reason is not preference: there
 * are THREE `struct mount' in this kernel and only one of them is in the
 * table.  `root_mnt' (root_mount.c:76) and `dev_mnt' (dev_mount.c:67) are
 * each a static carved by the bank that mounts them -- deliberately, for the
 * reason dev_mnt states -- so a walk of vfs_mounttab[] would enumerate every
 * mount EXCEPT the root, which is the one df is asked about.  Reno has no
 * such split because rootfs is a list member like any other, and the list is
 * what makes the three homes irrelevant.
 *
 * mnt_next and mnt_prev were in `struct mount' the whole time, carried by the
 * port and pointing nowhere.  This is them being used.
 *============================================================================
 */
/* vfs.mod, through vfs_import.s: the per-mount half.  vfs_vnops.c's statfs
 * section says why it is over there. */
extern int vfs_statfs1();
extern int vfs_sync1();      /* vfs.mod, VFSCORE_Sync1 -- apple/fgx#332 */

static struct mount vfs_mounttab[VFS_NMOUNT];

/* THE LIST HEAD.  Reno declares `rootfs' in kern/vfs_conf.c and every walk in
 * vfs_syscalls.c starts and ends there (`mp = rootfs; ... } while (mp !=
 * rootfs)').  Cleared by vfs_mountinit below, because a far-bank static is
 * not zeroed at load and a garbage head is a walk off into the bank. */
struct mount *rootfs;


/* vfs_mountlist_root -- make mp the list, which is what mounting the ROOT
 * does.  Reno's ufs_mountroot (ufs/ufs_vfsops.c:101-103):
 *
 *      rootfs = mp;
 *      mp->mnt_next = mp;
 *      mp->mnt_prev = mp;
 *
 * A one-element circular list, so the `do { } while (mp != rootfs)' walk
 * visits it exactly once. */
void
vfs_mountlist_root(mp)
struct mount *mp;
{
    rootfs        = mp;
    mp->mnt_next  = mp;
    mp->mnt_prev  = mp;
}


/* vfs_mountlist_add -- link mp in behind the root.  Reno's mount(2)
 * (kern/vfs_syscalls.c:169-172), verbatim in order:
 *
 *      mp->mnt_next = rootfs->mnt_next;
 *      mp->mnt_prev = rootfs;
 *      rootfs->mnt_next = mp;
 *      mp->mnt_next->mnt_prev = mp;
 *
 * THE NULL-HEAD ARM IS NOT UPSTREAM'S and it is not decoration.  Reno cannot
 * reach mount(2) before mountroot has run, so rootfs is never null there.
 * FGX can: root_mount() treats a volume that fails ufs_sbvalid as "not a UFS
 * machine" and carries on with root_status 0, and dev_mount() may then mount
 * /dev with no root ever having been established.  Without this arm that is a
 * store through a null pointer on the boot path. */
void
vfs_mountlist_add(mp)
struct mount *mp;
{
    if (rootfs == (struct mount *)0) {
        vfs_mountlist_root(mp);
        return;
    }
    mp->mnt_next           = rootfs->mnt_next;
    mp->mnt_prev           = rootfs;
    rootfs->mnt_next       = mp;
    mp->mnt_next->mnt_prev = mp;
}

/* Called once, from the far bank's boot path, before any mount can be
 * attempted.  A slot is free when mnt_op is null, so this loop is what makes
 * that test mean anything. */
void
vfs_mountinit()
{
    int i;

    for (i = 0; i < VFS_NMOUNT; i++)
        vfs_mounttab[i].mnt_op = (struct vfsops *)0;
    /* And the list head, for this function's own reason one line up: a
     * far-bank static holds whatever the image left at that address. */
    rootfs = (struct mount *)0;
}


/* vfs_sync -- sync(2)'s mount-list walk.  4.3BSD-Reno kern/vfs_syscalls.c:268.
 * apple/fgx#332.
 *
 * vfs_getfsstat's WALK, one function down, and deliberately the same shape:
 * both start at `rootfs' and go round the ring, and both do the per-mount work
 * through a vfs.mod entry because the vector cell carries a MODULE's bank.
 *
 * THIS IS THE THING THAT WAS MISSING, and its absence was silent.  ufs_alloc
 * hands out blocks from a batch of up to fifty and writes the superblock back
 * only when the batch empties -- upstream's policy -- setting `sb_fmod' for
 * everything in between and trusting sync(2) to notice.  Nothing noticed:
 * `_Sys_Sync' called `Fs_SyncAll', which walks every task's fd table and
 * fsyncs descriptors, and never touched the mount list.  So an allocated block
 * stayed on the on-disk free list, `df' over-reported free space, and the next
 * mount gave the block away a second time -- measured as `block 17159 is
 * claimed by BOTH inode 567 and inode 568'.
 *
 * IT RETURNS NOTHING, as upstream's sync(2) does: a filesystem that cannot be
 * written is not a failure the caller can act on, and BSD's sync has no error
 * return to put one in.  vfs_sync1 already declines a read-only mount.
 *
 * NO MNT_MLOCK SKIP AND NO vfs_busy, which upstream has and this cannot use:
 * Reno skips a mount being torn down or built up, and nothing here sets the
 * bit yet -- getfsstat's own note beside the same test says so.  It is left
 * out rather than written as an always-false test, because an unmount that
 * ever does set it needs this arm ADDED and reviewed, not silently present.
 *
 * AND THE BUFFER CACHE, WHICH THE MOUNT WALK DOES NOT REACH (apple/fgx#398).
 * Reno flushes a mount's delayed writes inside ufs_sync -- vflushbuf over each
 * dirty vnode on `mp->mnt_mounth' (ufs/ufs_vfsops.c:571) and then over the
 * mount's own device vnode (:580).  Neither line ports: there is no mnt_mounth
 * here, and a MOUNTED device's block node cannot be opened by anyone
 * (spec_open's VBLK arm answers EBUSY through mountedon), so the only writer
 * that could dirty a buffer on one is the filesystem itself and every write it
 * makes is already a bwrite.  A per-mount flush would have nothing to do.
 *
 * WHAT IS ACTUALLY LEFT DIRTY lives on an UNMOUNTED spindle, which no mount
 * list visits: spec_write's partial-block arm is the one bdwrite in the tree,
 * and it fires when something writes fewer than FS_BLKSIZE bytes to a
 * /dev/sd<n> node.  Until then the bytes reach the platter only when getnewbuf
 * happens to recycle the buffer.  sync(2)'s contract is "all information in
 * core memory that should be on disk", update(8) has been calling it every
 * thirty seconds on the strength of that since apple/fgx#389, and 2.11BSD's
 * own bflush (usr/sys/sys/ufs_bio.c:426) is the shape that keeps it.
 *
 * BEFORE THE EARLY RETURN, so a machine with nothing mounted still flushes.
 */
static int vfs_wantclean;       /* vfs_syncclean() -> vfs_sync(), one call */

void
vfs_sync()
{
    struct mount *mp;

    bflush((dev_t)NODEV);
    if (rootfs == (struct mount *)0)
        return;
    mp = rootfs;
    do {
        if (vfs_wantclean)
            mp->mnt_flag |= MNT_CLEANSYNC;
        (void)vfs_sync1(mp);
        mp->mnt_flag &= ~MNT_CLEANSYNC;
        mp = mp->mnt_prev;
    } while (mp != rootfs);
}


/* vfs_syncclean -- the sync a machine does on its way down.  2.11BSD update
 * #456's fsclean(), usr/sys/sys/ufs_subr.c, called from boot():
 *
 *      for (mp = &mount[0]; mp < &mount[NMOUNT]; mp++) {
 *              ...
 *              if (fs->fs_flags & MNT_WASCLEAN) {
 *                      fs->fs_flags |= MNT_CLEAN;
 *                      fs->fs_fmod = 1;
 *                      ufs_sync(mp);
 *                      fs->fs_flags &= ~MNT_CLEAN;
 *              }
 *      }
 *
 * THIS IS WHAT MAKES A REBOOT A REBOOT RATHER THAN A CRASH.  Without it every
 * deliberate restart leaves the root looking exactly like a machine that lost
 * power, and the next boot pays for a full check it does not need -- over 45
 * seconds on the 32000-block root.  With it, an unclean shutdown is the only
 * thing that leaves work for fsck, which is the whole contract the clean flag
 * exists to express.
 *
 * SPLIT ACROSS THE BANK SEAM, which is the only structural difference from
 * upstream: the mount-list walk is the far bank's and the superblock belongs
 * to ufs.mod, so the per-mount half rides MNT_CLEANSYNC through the VFS_SYNC
 * this already performs rather than reaching into `fs' from here.  Upstream
 * clears MNT_CLEAN again after the write and so does that half -- a machine
 * that keeps running after the call must not be left claiming to be clean.
 */
void
vfs_syncclean()
{
    vfs_wantclean = 1;
    vfs_sync();
    vfs_wantclean = 0;
}


/* vfs_getfsstat -- getfsstat(2)'s body.  Reno kern/vfs_syscalls.c:383.
 *
 * WALKS THE LIST, NOT THE TABLE, for the reason the header above now gives:
 * the root and /dev are statics outside vfs_mounttab[], and the root is the
 * mount df(1) is actually asked about.
 *
 * THE REFRESH IS UNCONDITIONAL AND UPSTREAM'S IS NOT.  Reno reads:
 *
 *      if (((uap->flags & MNT_NOWAIT) == 0 || (uap->flags & MNT_WAIT)) &&
 *          (error = VFS_STATFS(mp, sp))) { mp = mp->mnt_prev; continue; }
 *
 * -- so MNT_NOWAIT hands back the CACHED mnt_stat without asking the
 * filesystem.  That flag exists for NFS, where a statfs is a round trip to a
 * server that may be down and where a hung df is worse than a stale one.
 * Every filesystem here is a local UFS whose numbers come out of an in-core
 * superblock ufs_alloc.c updates on every block allocated, so there is
 * nothing to wait on and the "fast" answer would differ from the true one for
 * no gain.  df(1) passes MNT_NOWAIT (df.c:89), so under upstream's rule it
 * would report the free space as it stood at MOUNT time -- which on a machine
 * that has been running a while is simply wrong.  The flag is accepted and
 * ignored; stated in getfsstat(2)'s BUGS.
 *
 * `sfsp' IS COUNTED IN STRUCTS AND `bufsize' IN BYTES, which is upstream's
 * interface and worth naming because the two are 100 apart: a caller that
 * passes an ENTRY count gets one mount reported and no error.
 *
 * A NULL BUFFER COUNTS AND COPIES NOTHING, and that arm is load-bearing rather
 * than defensive.  Reno guards every copy with `if (sfsp && ...)' and ends
 *
 *      if (sfsp && count > maxcount) *retval = maxcount;
 *      else                          *retval = count;
 *
 * -- so getfsstat(0, 0, ...) returns the TOTAL, not the clamped zero.  That is
 * the whole of how getmntinfo(3) sizes its malloc:
 *
 *      if (mntsize <= 0 && (mntsize = getfsstat(0, 0, MNT_NOWAIT)) < 0)
 *              return (0);
 *      ...
 *      bufsize = (mntsize + 1) * sizeof(struct statfs);
 *
 * (vendor/2.11BSD/usr/lib/libc/gen/getmntinfo.c:34-41).  A first draft here
 * dropped the `sfsp &&' as redundant -- it is not: without it the sizing call
 * answers 0, getmntinfo allocates one entry, and df(1) prints nothing while
 * every layer reports success.  Which is the bug this issue opened with.
 */
int
vfs_getfsstat(sbp, bufsize)
struct statfs *sbp;
int            bufsize;
{
    struct mount *mp;
    int           maxcount;
    int           count;

    if (rootfs == (struct mount *)0)
        return (0);

    maxcount = bufsize / sizeof(struct statfs);
    count    = 0;
    mp       = rootfs;
    do {
        /* MNT_MLOCK is upstream's skip: a mount point being torn down or
         * built up has a mnt_stat nobody should read.  It can be set here --
         * mount.h keeps Reno's numbering precisely so the bit means the same
         * thing -- and no code sets it yet, so today this never fires. */
        if (sbp != (struct statfs *)0 && count < maxcount &&
            (mp->mnt_flag & MNT_MLOCK) == 0L) {
            if (vfs_statfs1(mp, sbp) == 0) {
                sbp++;
                count++;
            }
        } else
            count++;
        mp = mp->mnt_prev;
    } while (mp != rootfs);

    if (sbp != (struct statfs *)0 && count > maxcount)
        return (maxcount);
    return (count);
}


/* vfs_mountslot -- the i'th table entry, or null past the end.
 *
 * THE TABLE IS THE ENUMERATION, which the note above says is what a static
 * table buys where Reno has a list.  This is that enumeration's one reader:
 * a caller that has mounted something and needs the `struct mount' back
 * cannot get it from vfs_mountat, whose return is mount(2)'s errno and
 * nothing else. */
struct mount *
vfs_mountslot(i)
int i;
{
    if (i < 0 || i >= VFS_NMOUNT)
        return ((struct mount *)0);
    return (&vfs_mounttab[i]);
}


static struct mount *
mountalloc()
{
    int i;

    for (i = 0; i < VFS_NMOUNT; i++) {
        if (vfs_mounttab[i].mnt_op == (struct vfsops *)0) {
            /* Reno writes these before VFS_MOUNT and so does this: the
             * filesystem ORs its own bits into mnt_flag, and an OR into a
             * slot that has been used before preserves every one of them.
             * mnt_op stays null until the filesystem sets it -- that is what
             * marks the slot taken, so it cannot be written here. */
            vfs_mounttab[i].mnt_flag         = 0L;
            vfs_mounttab[i].mnt_exroot       = 0;
            vfs_mounttab[i].mnt_mounth       = (struct vnode *)0;
            vfs_mounttab[i].mnt_vnodecovered = (struct vnode *)0;
            vfs_mounttab[i].mnt_data         = (char *)0;
            return (&vfs_mounttab[i]);
        }
    }
    return ((struct mount *)0);
}


/* vfs_mountflags -- write the caller's user-visible flags into a mount.
 *
 * Reno's `update:' label, kern/vfs_syscalls.c, and it SETS AND CLEARS rather
 * than only setting: a remount says what the mount is now, not what to add to
 * it, so `mount -w' has to be able to take MNT_RDONLY back off.  A fresh mount
 * arrives with mnt_flag zeroed and cannot tell the difference, which is why
 * this was once only the setting half.
 *
 * Four of Reno's five are here.  MNT_SYNCHRONOUS has no write path, and a flag
 * that statfs would report while nothing honours it is worse than one that is
 * absent.
 */
static void
vfs_mountflags(mp, flags)
struct mount *mp;
int           flags;
{
    if (flags & MNT_RDONLY)
        mp->mnt_flag |= MNT_RDONLY;
    else
        mp->mnt_flag &= ~MNT_RDONLY;
    if (flags & MNT_NODEV)
        mp->mnt_flag |= MNT_NODEV;
    else
        mp->mnt_flag &= ~MNT_NODEV;
    if (flags & MNT_NOEXEC)
        mp->mnt_flag |= MNT_NOEXEC;
    else
        mp->mnt_flag &= ~MNT_NOEXEC;
    if (flags & MNT_NOSUID)
        mp->mnt_flag |= MNT_NOSUID;
    else
        mp->mnt_flag &= ~MNT_NOSUID;
}


/* vfs_mountat -- mount(2)'s body.
 *
 * `dvp' IS RENO'S u.u_cdir, PASSED RATHER THAN READ, which is vfs_openat's
 * arrangement above and is here for the same reason plus one more: `rootdir'
 * is still zero on this machine (vfs_lookup.c:83 -- root is ProDOS, and never set), so an ABSOLUTE mount path cannot resolve at
 * all until Phase 2.5 makes root a UFS filesystem.  A body that only took an
 * absolute path would be one no caller could use.  Zero means "start at the
 * system root", namei's own convention, so this becomes Reno's signature
 * unchanged the day there is one.
 *
 * NO LOCKLEAF.  Reno holds the covered vnode locked from namei through to
 * `v_mountedhere = mp', and unlocks with VOP_UNLOCK.  This walk takes a
 * reference and no lock, and the release is vrele where Reno's is vput.
 * Nothing between the checks and the wiring sleeps, so the window the lock
 * guards does not open; it comes back with the lock the moment one does.
 *
 * THE REFERENCE-COUNT REFUSAL IS IN BOTH TREES, which is why it is here rather
 * than dropped as fussiness.  Reno: `if (vp->v_usecount != 1) RETURN (EBUSY)'.
 * 2.11BSD: `if (ip->i_count != 1 || ip->i_number == ROOTINO) error = EBUSY'.
 * Mounting over a directory somebody else is holding hides it from them with
 * no notice, and after a plain namei the walk's own reference is the only one
 * a free directory has.
 *
 * WHAT IS NOT CARRIED FROM UPSTREAM, and why:
 *
 *   suser()          CARRIED, but at the syscall layer rather than here:
 *                    _Sys_Mount (syscall.s) answers EPERM to a non-root
 *                    caller before this is reached, which is where _Suser and
 *                    the u-area are.  Both upstreams gate it -- 2.11BSD in
 *                    getmdev (usr/sys/sys/ufs_mount.c:331), Reno at the head
 *                    of mount() (kern/vfs_syscalls.c:63).  It was a REAL hole
 *                    until apple/fgx#416, and that campaign is what made it
 *                    urgent: with exec honouring a set-user-ID bit, anyone who
 *                    can mount can bring a set-user-ID-root shell with them.
 *   vfs_lock        see LOCKLEAF above: it guards a window that does not
 *                    open while nothing between the claim and the wiring
 *                    sleeps.
 *   vinvalbuf(vp,1)  Reno flushes the covered directory's cached buffers so a
 *                    read cannot answer from behind the mount.  OWED, and it
 *                    is 1.8b-3's for the same reason cache_purge is: nothing
 *                    can read THROUGH the mount point yet.
 *   cache_purge(vp)  Reno purges the covered directory's name-cache entries so
 *                    a stale hit cannot answer for the mount point.  OWED,
 *                    1.8b-3's -- it only matters once lookup crosses.
 *
 * THE MOUNT IS INVISIBLE WHEN THIS RETURNS, and that is worth stating rather
 * than discovering.  vfs_lookup.c descends no `v_mountedhere' and ascends no
 * `mnt_vnodecovered' -- it marks both sites by name, at :511 and :582 -- so a
 * filesystem mounted here is reachable through VFS_ROOT and through nothing
 * else.  1.8b-3 is what makes a PATH cross into it.
 *
 * AND unmount(2) IS NOT HERE, which is not an omission.  Reno's unmount does
 * NOT reach the mount through the covered directory: it requires the named
 * vnode to be the mounted filesystem's OWN root -- `if ((vp->v_flag & VROOT)
 * == 0) RETURN (EINVAL)' -- and takes `mp = vp->v_mount'.  No path can produce
 * that vnode until lookup crosses into a mount, so unmount(2) is 1.8b-3's by
 * upstream's own shape.  Writing one that reached through `v_mountedhere'
 * instead would be inventing an interface BSD does not have in order to work
 * around a feature that has not landed.
 *
 * THE TYPE SWITCH IS RENO'S TWO LINES, with the table read through
 * vfs_getvfsops because its rows are handed over by modules, which cannot
 * reach this bank:
 *
 *      if ((unsigned long)uap->type > MOUNT_MAXTYPE ||
 *          vfssw[uap->type] == (struct vfsops *)0) {
 *              vput(vp);
 *              RETURN (ENODEV);
 *      }
 *      mp->mnt_op = vfssw[uap->type];
 *
 * The lookup comes after mountalloc and upstream's comes before malloc, which
 * is the same order as far as anything can observe: mountalloc claims nothing
 * -- a slot is taken only once mnt_op is non-null -- so a refused type leaves
 * no slot to give back.  AND VFS_MOUNT IS DISPATCHED FROM HERE, not through a
 * further seam hop: this chain is the deepest per-task kernel stack in the
 * system, and a hop that re-pushes the arguments costs it ~30 bytes of 512.
 */
int
vfs_mountat(pid, dvp, type, dir, flags, data)
int           pid;
struct vnode *dvp;
int           type;
char         *dir;
int           flags;
char         *data;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    struct mount     *mp;
    int               error;
    long              oflag;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    /* ni_vp and ni_dvp are cleared rather than left as the slot holds them,
     * for vfs_openat's reason: an ndslot persists across walks. */
    ndp->ni_dirp    = dir;
    ndp->ni_segflg  = UIO_SYSSPACE;
    ndp->ni_cdir    = dvp;
    ndp->ni_rdir    = (struct vnode *)0;
    ndp->ni_vp      = (struct vnode *)0;
    ndp->ni_dvp     = (struct vnode *)0;
    ndp->ni_nameiop = LOOKUP | FOLLOW;
    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;            /* SAVED NOW: ufs_mount's getmdev walks the
                                 * same ndp and overwrites ni_vp with the
                                 * device. */

    /* A REMOUNT NAMES THE MOUNT'S OWN ROOT, and is decided before any of the
     * checks below, which is Reno's order: `if (uap->flags & MNT_UPDATE)' sits
     * immediately after namei and jumps past vinvalbuf, the usecount test and
     * the VDIR test.  It has to.  A mounted-on root is VDIR but its usecount is
     * not 1 and it is already covered, so every one of those would refuse the
     * remount the caller is entitled to.
     *
     * READ-ONLY TO READ-WRITE ONLY.  Reno answers EOPNOTSUPP the other way and
     * 2.11BSD answers EPERM, both with the same reason -- ufs_mount.c:80-84
     * says it out loud, "too much work to port pages of code to do (besides
     * which most programs get very upset at having access yanked out from
     * under them)".  Reno's errno is the one taken because this file is Reno's;
     * it is spelled ENOTSUP here and EOPNOTSUPP upstream, and the number is 45
     * in both (fsparam.h says why the name is local).
     *
     * mnt_flag IS SAVED AND RESTORED ON FAILURE.  The flags below are written
     * into the LIVE mount before ufs_mount sees them, so a filesystem that
     * refuses the update would otherwise leave the mount describing a
     * transition that did not happen. */
    if (flags & MNT_UPDATE) {
        if ((vp->v_flag & VROOT) == 0) {
            vrele(vp);
            return (EINVAL);
        }
        mp = vp->v_mount;
        if ((mp->mnt_flag & MNT_RDONLY) == 0 && (flags & MNT_RDONLY) != 0) {
            vrele(vp);
            return (ENOTSUP);
        }
        oflag = mp->mnt_flag;
        mp->mnt_flag |= MNT_UPDATE;
        vfs_mountflags(mp, flags);
        error = VFS_MOUNT(mp, dir, data, ndp);  /* Reno's `goto update':
                                                 * the type is not read */
        mp->mnt_flag &= ~MNT_UPDATE;
        if (error)
            mp->mnt_flag = oflag;
        vrele(vp);              /* the mount's own reference stands */
        return (error);
    }

    if (vp->v_type != VDIR) {
        vrele(vp);
        return (ENOTDIR);
    }
    if (vp->v_usecount != 1) {
        vrele(vp);
        return (EBUSY);         /* somebody else is holding it */
    }
    /* ALREADY COVERED.  Reno asks this under vfs_lock, after the allocation;
     * with no lock to take the order is free, and asking before the slot is
     * claimed means a refusal costs no slot to give back. */
    if (vp->v_un != (struct specinfo *)0) {
        vrele(vp);
        return (EBUSY);
    }
    mp = mountalloc();
    if (mp == (struct mount *)0) {
        vrele(vp);
        return (EMFILE);        /* the mount table is full -- 2.11BSD's */
    }

    mp->mnt_op = vfs_getvfsops(type);
    if (mp->mnt_op == (struct vfsops *)0) {
        vrele(vp);
        return (ENODEV);        /* no such filesystem type configured */
    }

    vfs_mountflags(mp, flags);

    error = VFS_MOUNT(mp, dir, data, ndp);
    if (error) {
        mp->mnt_op = (struct vfsops *)0;    /* give the slot back */
        vrele(vp);
        return (error);
    }

    /* THE TWO HALVES OF THE COVER, and neither is useful without the other:
     * down through the v_un word and up through mnt_vnodecovered.  Nothing
     * reads the downward half yet -- see the header -- but both are written
     * here because this is the only place that knows both vnodes.
     *
     * THE REFERENCE IS NOT GIVEN BACK: the mount holds it from here, which is
     * what Reno's `VOP_UNLOCK(vp)' without a vrele means, and what dounmount's
     * `vrele(coveredvp)' returns. */
    vp->v_un             = (struct specinfo *)mp;
    mp->mnt_vnodecovered = vp;

    /* AND INTO THE LIST, which is where Reno does it too -- kern/vfs_syscalls.c
     * links the mount immediately after VFS_MOUNT returns and before the cover
     * is published.  The order is swapped here only because the cover is
     * written in one place that knows both vnodes; nothing walks the list
     * between the two statements. */
    vfs_mountlist_add(mp);
    return (0);
}


/* vfs_unmountat -- unmount(2)'s body.  4.3BSD-Reno
 * kern/vfs_syscalls.c:unmount().  UFS 1.8b-3c.
 *
 * IT NAMES THE MOUNT'S OWN ROOT, NOT THE DIRECTORY IT COVERS, and that is
 * upstream's shape rather than a choice.  Reno does not look at
 * `v_mountedhere' anywhere in unmount: it requires the resolved vnode to carry
 * VROOT -- `if ((vp->v_flag & VROOT) == 0) RETURN (EINVAL)' -- and then takes
 * `mp = vp->v_mount'.  The two are the same path spelled once each way, and
 * the difference shows the moment something is mounted on a mount point: the
 * root belongs to the INNER filesystem and the cover to the outer.
 *
 * THIS IS WHY unmount COULD NOT LAND WITH mount.  At 1.8b-2 no path could
 * produce a mount root at all -- lookup crossed nothing -- so the test above
 * had no input, and an unmount reaching through the cover instead would have
 * been an interface BSD does not have, invented to route around a feature that
 * had not landed.  1.8b-3a and 1.8b-3b are what supplied it: the descent makes
 * a mount root reachable by name, and iget marks it VROOT.
 *
 * `dvp' AND NO LOCKLEAF, both for vfs_mountat's reasons: `rootdir' is still
 * zero so an absolute path resolves nothing, and nothing between the walk and
 * the release sleeps, so the walk takes a reference and releases with vrele
 * where Reno's vput's.
 *
 * EVERYTHING AFTER THE CHECK IS vfs.mod's.  cache_purgevfs and the vnode pool
 * are over there, and VFS_UNMOUNT goes with them -- so this resolves and
 * validates, and `vfs_dounmount' does the rest.  Reno splits the same way for a different
 * reason: its unmount(2) and its dounmount are separate because reboot(2)
 * calls the second one directly.
 *
 * suser IS CARRIED, at _Sys_Umount in the syscall layer -- see vfs_mountat.
 */
int
vfs_unmountat(pid, dvp, dir, flags)
int           pid;
struct vnode *dvp;
char         *dir;
int           flags;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    struct mount     *mp;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    ndp->ni_dirp    = dir;
    ndp->ni_segflg  = UIO_SYSSPACE;
    ndp->ni_cdir    = dvp;
    ndp->ni_rdir    = (struct vnode *)0;
    ndp->ni_vp      = (struct vnode *)0;
    ndp->ni_dvp     = (struct vnode *)0;
    ndp->ni_nameiop = LOOKUP | FOLLOW;
    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;

    /* MUST BE THE ROOT OF A MOUNTED FILESYSTEM.  Naming the covered directory
     * instead is EINVAL and not a courtesy redirect: the two are different
     * vnodes in different filesystems, and guessing which one the caller meant
     * is how `umount /mnt' comes to unmount something else. */
    if ((vp->v_flag & VROOT) == 0) {
        vrele(vp);
        return (EINVAL);
    }
    mp = vp->v_mount;

    /* THE ROOT IS NOT UNMOUNTABLE, and upstream says so with a panic:
     * vfs_remove opens `if (mp == rootfs) panic("vfs_remove: unmounting
     * root")' (4.3BSD-Reno kern/vfs_subr.c:46-47).  A refusal is taken here
     * instead -- deliberately a DIVERGENCE, and the reason is that Reno's
     * panic is a backstop for a case its own unmount(2) never reaches on a
     * running system, whereas `umount /' typed at this shell reaches it
     * directly.  Halting the machine because a user named the wrong path is
     * not an improvement on telling them no.
     *
     * IT IS ALSO WHAT KEEPS THE LIST HEAD HONEST.  Unlinking rootfs would
     * leave getfsstat(2) walking from a `struct mount' whose filesystem is
     * gone; the guard is what the walk's single-head assumption rests on.
     * EBUSY is the errno 4.4BSD settled on for this and is what umount(8)
     * already knows how to print. */
    if (mp == rootfs) {
        vrele(vp);
        return (EBUSY);
    }

    /* RELEASED BEFORE THE UNMOUNT, which is Reno's order and load-bearing
     * rather than tidy: vflush refuses while any vnode of this mount is still
     * referenced, and the walk's own reference on the root is one of those.
     * Holding it here would make every unmount fail EBUSY against itself. */
    vrele(vp);
    return (vfs_dounmount(mp, flags));
}


/* vfs_unmountdev -- umount(2), which names the DEVICE and not the directory.
 * 2.11BSD usr/sys/sys/ufs_mount.c's umount/unmount1.  UFS 2.6.
 *
 * THE INTERFACE IS 2.11BSD's AND THE BODY BELOW IT IS RENO's, which is worth
 * stating because the two ancestors disagree here and the disagreement is
 * visible from userland.  Reno's unmount(2) takes the mount POINT
 * (kern/vfs_syscalls.c:193); 2.11BSD's takes the SPECIAL FILE, resolves it
 * with getmdev and searches the mount table for a matching device number.
 * The port rule settles it: umount(8) comes from vendor/2.11BSD, and its
 * umountfs() normalises whatever it was given into `f_mntfromname' before
 * calling umount(name) -- so the kernel must accept a device or the tool
 * cannot go in verbatim.
 *
 * THE MATCH IS ON THE DEVICE NUMBER, not on the name, which is upstream's and
 * is the half worth copying carefully.  `/dev/sd1' and a symlink to it are one
 * device and two strings; comparing `f_mntfromname' would unmount neither.
 * The number comes from VOP_GETATTR's va_rdev, reached through vfs.mod's
 * vn_getattr, by vfs_vnops.c's rule that a VOP_ is dispatched in the module
 * that owns the vnode layer.
 *
 * A NON-DEVICE IS EINVAL AND NOT A SEARCH.  2.11BSD's getmdev refuses
 * anything but a block special the same way, and a directory reaching here
 * would otherwise match nothing and answer the misleading EINVAL of "not
 * mounted" rather than "that is not a device".
 */
int
vfs_unmountdev(pid, spec, flags)
int   pid;
char *spec;
int   flags;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    struct mount     *mp;
    struct vattr      vat;
    dev_t             dev;
    int               error;

    if (rootfs == (struct mount *)0)
        return (EINVAL);

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    ndp->ni_dirp    = spec;
    ndp->ni_segflg  = UIO_SYSSPACE;
    ndp->ni_cdir    = vfs_cdir(pid);
    ndp->ni_rdir    = (struct vnode *)0;
    ndp->ni_vp      = (struct vnode *)0;
    ndp->ni_dvp     = (struct vnode *)0;
    ndp->ni_nameiop = LOOKUP | FOLLOW;
    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;

    if (vp->v_type != VBLK) {
        vrele(vp);
        return (EINVAL);
    }
    error = vn_getattr(vp, &vat);
    dev = vat.va_rdev;
    vrele(vp);
    if (error)
        return (error);

    /* THE MOUNT LIST, walked as getfsstat and sync walk it, and matched on
     * the mount's OWN record of its device rather than on any filesystem's
     * private data.  2.11BSD's unmount1 compares `dev == mp->m_dev', a field
     * of the generic mount (usr/sys/sys/ufs_mount.c:278), and 4.3BSD-Reno's
     * home for the same fact is `mp->mnt_stat.f_fsid.val[0] = (long)dev'
     * (ufs/ufs_vfsops.c:277) -- which every filesystem's statfs here fills
     * at mount.  Reading mnt_data as a `struct ufsmount' matched a ProDOS
     * mount on whatever bytes sat at um_dev's offset. */
    mp = rootfs;
    do {
        if (mp->mnt_op != (struct vfsops *)0 &&
            mp->mnt_stat.f_fsid == (long)dev) {
            if (mp == rootfs)
                return (EBUSY);     /* vfs_unmountat's refusal, same reason */
            return (vfs_dounmount(mp, flags));
        }
        mp = mp->mnt_prev;
    } while (mp != rootfs);

    return (EINVAL);        /* not mounted -- 2.11BSD's unmount1 answer */
}


/* vfs_ioctl -- ioctl(2)'s body for a descriptor whose ops live in this bank.
 * Reno kern/sys_generic.c:ioctl().  UFS 1.7d I4.
 *
 * UPSTREAM'S ARGUMENT MARSHALLING IS NOT CARRIED, AND IT CANNOT BE.  Reno's
 * ioctl(2) sizes the argument from the command itself -- `size =
 * IOCPARM_LEN(com)' -- copies it into a stack buffer with copyin, dispatches,
 * and copies back out.  That decoding needs the LENGTH FIELD BSD packs into
 * the high half of an ioctl number, and FGX's ioctl numbers are SIXTEEN BITS:
 * `TIOCGETP EQU $7408' (include/loader.s:685) is the low half of Reno's
 * _IOR('t', 8, struct sgttyb) with the size bits cut off.  There is no length
 * to read, so there is nothing to size a copy with.
 *
 * SO THE POINTER IS THE ABI HERE, and that is a decision already made and
 * already relied upon rather than one taken now.  Every chardev ioctl op reads
 * the caller's argument through _Sys_IoctlArgLo/_Sys_IoctlArgBank, which the
 * syscall layer stages before it classifies the descriptor; `data' below is
 * that same pointer arriving by the longer road.  Nothing between here and the
 * driver dereferences it -- vn_ioctl says so in its own header, and spec_ioctl
 * does not pass it on -- so it crosses this seam as an opaque address.
 *
 * FIOCLEX, FIONCLEX AND FIOASYNC ARE ABSENT.  Reno answers all four
 * generically above the switch; FGX has no close-on-exec flag word and no
 * FASYNC reader, so each would be a knob nothing sets.  They belong with the
 * code that gives them meaning.
 *
 * FIONBIO IS NO LONGER ONE OF THEM, and it left that list because a device
 * opened under /dev needs it.  Reno answers it in ioctl() itself --
 * `case FIONBIO: error = fset(fp, FNDELAY, *(int *)data);'
 * (kern/sys_generic.c:388) -- and fset does TWO things, which is the whole
 * point:
 *
 *     if (value) fp->f_flag |= bit; else fp->f_flag &= ~bit;
 *     return (fioctl(fp, (int)(bit == FNDELAY ? FIONBIO : FIOASYNC),
 *         (caddr_t)&value));
 *                                        (kern/kern_descrip.c:192-203)
 *
 * The two halves have different readers.  The FLAG is what vn_read consults --
 * `VOP_READ(vp, uio, (fp->f_flag & FNDELAY) ? IO_NDELAY : 0, cred)'
 * (kern/vfs_vnops.c:326) -- and the DRIVER CALL is what lets a line keep its
 * own per-open state.  Passing it on without setting the flag, which is what
 * this routine did, tells the driver and leaves the VFS believing every read
 * may block; setting the flag without passing it on would do the reverse.
 *
 * The call below already carried FIONBIO to the driver, so only the flag was
 * missing.
 */
int
vfs_ioctl(pid, fd, com, data)
int   pid;
int   fd;
int   com;
char *data;
{
    struct file *fp;

    /* Reno requires FREAD or FWRITE -- `if ((fp->f_flag & (FREAD|FWRITE)) == 0)
     * return (EBADF)' -- which is not the same as requiring either one in
     * particular, so the test is spelled that way here too. */
    fp = fdcheck(pid, fd, FREAD | FWRITE);
    if (fp == (struct file *)0)
        return (EBADF);
    if (fp->f_ops == (struct fileops *)0)
        return (EBADF);
    if (com == FIONBIO) {
        if (*(int *)data)
            fp->f_flag |= FNDELAY;
        else
            fp->f_flag &= ~FNDELAY;
    }
    return ((*fp->f_ops->fo_ioctl)(fp, com, data));
}


/* vfs_select -- select(2)'s readiness for one descriptor.  Reno's selscan
 * (kern/sys_generic.c) is where the per-descriptor call lives.  UFS 1.7d I4.
 *
 * THREE CALLS, BECAUSE UPSTREAM MAKES THREE.  Reno's selscan loops over the
 * three bit sets and calls `(*fp->f_ops->fo_select)(fp, flag)' once per set
 * with flag = FREAD, then FWRITE, then 0 (kern/sys_generic.c:522-543 -- the
 * exceptional set IS `flag = 0', not a separate vector), and 2.11BSD's selscan
 * is the same loop (usr/sys/sys/sys_generic.c:465-476).  FGX's select arms
 * answer a readiness mask for one descriptor instead of being asked per set,
 * so this makes upstream's three calls and packs them into that mask: bit 0
 * readable, bit 1 writable, bit 2 an exceptional condition.  The same three
 * questions, batched.
 *
 * WHAT EACH VNODE ANSWERS.  A regular file, a directory, a block device and a
 * dead vnode say 1 to all three, which is what Reno and 2.11BSD say for them.
 * A character device answers through spec_select, which says 0 to the third
 * for every device where 2.11BSD asks the driver; its header names the
 * devices whose driver would say 1.
 *
 * AN ARM'S RETURN IS A BOOLEAN.  Every vnodeops table's select slot holds a
 * select routine for that reason: an errno-returning stub is nonzero, and would
 * read as "ready" on the first two calls and as an exceptional condition on
 * the third.
 *
 * NO MODE BIT IS REQUIRED, and that is upstream's behaviour rather than an
 * oversight: selscan tests only that the descriptor exists before dispatching,
 * so a descriptor open for writing may still be ASKED whether it is readable
 * -- and must be, since the answer "no" is the useful one.
 */
int
vfs_select(pid, fd)
int pid;
int fd;
{
    struct file *fp;
    int          res;

    fp = fdcheck(pid, fd, 0);
    if (fp == (struct file *)0)
        return (-EBADF);
    if (fp->f_ops == (struct fileops *)0)
        return (-EBADF);

    res = 0;
    if ((*fp->f_ops->fo_select)(fp, FREAD))
        res |= 1;                       /* readable */
    if ((*fp->f_ops->fo_select)(fp, FWRITE))
        res |= 2;                       /* writable */
    if ((*fp->f_ops->fo_select)(fp, 0))
        res |= 4;                       /* exceptional condition */
    return (res);
}


/* vfs_lseek -- lseek(2)'s body.  Reno kern/vfs_syscalls.c:lseek().
 *
 * ESPIPE FOR A NON-VNODE IS THE CONTRACT, not a refusal of convenience: it is
 * how a pipe or socket tells a caller it has no seek pointer, and the shell
 * depends on it.  The f_type test is upstream's and stays even though the only
 * type that can reach here today is DTYPE_VNODE -- the moment I2 gives pipes a
 * fileops, this is the line that keeps `lseek` on one honest.
 *
 * L_XTND READS THE SIZE THROUGH vn_getattr -- which is VOP_GETATTR performed
 * on vfs.mod's side.  The dispatch cannot happen here: v_op points at a table
 * in another bank, and calling through it from this one is a raw cross-bank
 * function pointer.  Going through the filesystem at all rather than reading
 * i_size directly is upstream's choice and the right one, which
 * matters for a device: a device has no i_size worth seeking to, and getattr
 * is where a filesystem gets to answer for its own type.
 */
int
vfs_lseek(pid, fd, off, whence, resultp)
int    pid;
int    fd;
off_t  off;
int    whence;
off_t *resultp;
{
    struct file  *fp;
    struct vattr  va;
    off_t         was;
    int           error;

    if (resultp == (off_t *)0)
        return (EINVAL);
    fp = fdcheck(pid, fd, 0);
    if (fp == (struct file *)0)
        return (EBADF);
    if (fp->f_type != DTYPE_VNODE)
        return (ESPIPE);

    was = fp->f_offset;
    if (whence == L_INCR) {
        fp->f_offset += off;
    } else if (whence == L_XTND) {
        error = vn_getattr((struct vnode *)fp->f_data, &va);
        if (error)
            return (error);
        fp->f_offset = off + va.va_size;
    } else if (whence == L_SET) {
        fp->f_offset = off;
    } else {
        return (EINVAL);
    }

    /* NEGATIVE IS REFUSED AFTER THE FACT, WHICH IS NOT UPSTREAM'S SHAPE.
     * Reno's lseek does not check, because on a PDP-11 a negative off_t that
     * reached VOP_READ met a filesystem that refused it.  Here off_t is a
     * 32-bit quantity fcc will happily add into and the read path indexes with
     * it, so a seek to -1 followed by a read is an index off the front of a
     * buffer.  The offset is RESTORED rather than clamped: clamping to zero
     * would make a bug look like a successful seek, and a failed lseek that
     * moved the pointer anyway is worse than either. */
    if (fp->f_offset < (off_t)0) {
        fp->f_offset = was;
        return (EINVAL);
    }

    *resultp = fp->f_offset;
    return (0);
}

/* ld_fd_is_vnode / ld_read -- Load_Binary's own reader.  UFS campaign 2.4.
 *
 * BSD'S KERNEL DOES NOT READ AN EXECUTABLE THROUGH A DESCRIPTOR, and that is
 * what these exist to follow.  Reno's exec reads the header with
 *
 *     error = vn_rdwr(UIO_READ, vp, (caddr_t)&exdata, sizeof (exdata),
 *         (off_t)0, UIO_SYSSPACE, (IO_UNIT|IO_NODELOCKED), cred, &resid);
 *
 * (vendor/4.3BSD-Reno/kern/kern_exec.c:156) -- on the VNODE, in system space,
 * with no fd anywhere in it.  FGX's Load_Binary is fd-keyed because that is
 * what it had, and routing its reads back down through the core bank's
 * fd layer and out again costs 74 bytes of a core bank with 33 free.  The
 * loader is ALREADY COMPILED INTO THIS BANK, so reading here is both the
 * cheaper arrangement and the one upstream describes.
 *
 * ld_read IS dev_rw's body with the direction fixed.  Kept separate rather
 * than calling dev_rw because dev_rw is a SEAM entry -- slot 38, reached by
 * JSL from the core bank -- and a same-bank caller has no business paying for
 * the crossing.  Both return the count, 0 at EOF, or -errno; the sign is the
 * discriminator, as it is at every other far entry.
 *
 * WHY THE CLASSIFY IS OWED FIRST.  rwcommon dispatches
 * `(*fp->f_ops->fo_read)(fp, &auio)', and a LEGACY descriptor's f_ops points
 * into the CORE bank -- so calling it from here would land at that offset in
 * THIS bank and run whatever happens to be there.  That is the same hazard
 * _Fcb_OpEntry guards in the core by comparing the bank; here the comparison
 * is against `vnops' itself, which is the only vector vfs_openat installs
 * (see fp->f_ops = &vnops above).
 *
 * kc_curpid() AND NOT A PASSED-IN pid, because the core's _Fcb_OwnerPid is
 * `_fdOwnerPid ? _fdOwnerPid : _curTask' and the override is set and cleared
 * only inside _Sys_ApplyFdActions, which never wraps a binary load.  The two
 * agree everywhere Load_Binary runs.
 */
int
ld_fd_is_vnode(fd)
int fd;
{
    return (fp_isvn(getf(kc_curpid(), fd)));
}

/* fp_isvn -- is this descriptor a vnode's?  `f_ops == &vnops', the one vector
 * vfs_openat installs, and NOT `f_type == DTYPE_VNODE': a descriptor the core
 * made (kdesc_alloc: a pipe end, among others) is DTYPE_VNODE provisionally
 * with an FCB in f_data.  _Sys_VnodeFp makes the same test in the core. */
int
fp_isvn(fp)
struct file *fp;
{
    return (fp != (struct file *)0 && fp->f_ops == &vnops);
}

int
ld_read(fd, buf, len)
int   fd;
char *buf;
int   len;
{
    int cnt;
    int error;

    cnt = 0;
    error = vfs_read(kc_curpid(), fd, buf, len, &cnt);
    if (cnt > 0)
        return (cnt);
    if (error)
        return (-error);
    return (0);
}

/* ld_exec_check -- may the file behind this descriptor be executed?
 *
 * apple/fgx#416.  This is the DESCRIPTOR half; vn_execchk (vfs_vnops.c) is the
 * half that asks the filesystem, and the split is vfs_access's exactly: the
 * far bank owns the descriptor, vfs.mod owns the vnode and the permission
 * logic.  Upstream needs no such split -- Reno's exec has the vnode from
 * namei and no fd anywhere in it (kern/kern_exec.c:110) -- but FGX's
 * Load_Binary is fd-keyed, for the reason ld_read's header gives.
 *
 * A LEGACY DESCRIPTOR IS LET THROUGH.  A ProDOS fd carries no vnode and no
 * mode; its f_ops live in the core bank, and dispatching through them from
 * here would run THIS bank at that offset -- the hazard ld_fd_is_vnode exists
 * for.  Refusing it instead would make every ProDOS-hosted binary
 * unexecutable to buy an enforcement that filesystem cannot express.
 */
int
ld_exec_check(fd)
int fd;
{
    struct file *fp;

    fp = getf(kc_curpid(), fd);
    if (fp == (struct file *)0)
        return (EBADF);
    if (fp->f_ops != &vnops)
        return (0);
    return (vn_execchk((struct vnode *)fp->f_data));
}

/* ld_exec_sugid -- ld_exec_check's companion: the id this image adopts, or -1.
 * The same descriptor guard, for the same reason -- a legacy fd has no vnode,
 * and a filesystem with no mode bits cannot mark anything set-id. */
int
ld_exec_sugid(fd, want)
int fd;
int want;
{
    struct file *fp;

    fp = getf(kc_curpid(), fd);
    if (fp == (struct file *)0)
        return (-1);
    if (fp->f_ops != &vnops)
        return (-1);
    return (vn_execsugid((struct vnode *)fp->f_data, want));
}

/* The two struct-stat stores, little-endian, byte at a time.  `sb' is a char*
 * into the kernel bank with no alignment guarantee and fcc has no unaligned
 * long store, so these are the four byte writes spelled out -- once, here,
 * rather than at each of root_stat's fifteen fields. */
void
sb_put16(p, v)
char *p;
int   v;
{
    p[0] = (char)(v & 0xFF);
    p[1] = (char)((v >> 8) & 0xFF);
}

void
sb_put32(p, v)
char *p;
long  v;
{
    p[0] = (char)(v & 0xFF);
    p[1] = (char)((v >> 8) & 0xFF);
    p[2] = (char)((v >> 16) & 0xFF);
    p[3] = (char)((v >> 24) & 0xFF);
}


/* root_stat -- stat(2) against the mounted root.  UFS campaign 2.4 / the path
 * syscall conversion.
 *
 * PORTED FROM 4.3BSD-Reno's vn_stat (kern/vfs_vnops.c), which is VOP_GETATTR
 * followed by a copy out of the vattr, with the S_IF* bits coming from the
 * VNODE's type rather than from va_mode -- va_mode carries permission bits
 * only, as vnode.h says at its declaration.
 *
 * THE WALK IS RENO'S stat(2) (kern/vfs_syscalls.c:971) AND NOT A PROBE'S.
 * This carried a plain LOOKUP without LOCKLEAF and
 * said so, which was a description of where the line was copied from rather
 * than of what stat(2) is.  Upstream's is `LOOKUP | LOCKLEAF | FOLLOW' with a
 * `vput', and both of the flags it adds change an answer:
 *
 *   FOLLOW is the ONLY thing separating stat from lstat -- upstream's lstat
 *   is the same six lines with NOFOLLOW (:1000).  Without it this reported
 *   the LINK where the caller asked about its target, which is reachable and
 *   not theoretical: ufs_symlink and ufs_readlink are REAL vnodeops entries
 *   (ufs_vnops.c:1961, :1963) and a 2.11BSD root ships symlinks.
 *
 *   LOCKLEAF is what VOP_GETATTR is entitled to (apple/fgx#294's class,
 *   caller-side): namei with a plain LOOKUP returns the leaf UNLOCKED by this
 *   file's own contract, so the attribute read ran against a vnode another
 *   process could be changing under it.  With the flag the leaf comes back
 *   locked and the disposal becomes `vput' -- upstream's, and the reason vput
 *   exists as its own function (vfs_subr.c:712).
 *
 * IT FILLS THE BSD STRUCT SINCE 2026-09-05, and this header used to explain
 * why it did not.  The reason was that converting meant converting the PRODOS
 * arm with it -- core assembly that would have needed a ProDOS-date-to-epoch
 * conversion written in 65816, in the bank that was out of room -- so the
 * cheaper order was to let the legacy fill DIE with the legacy resolver
 * instead.  That is what happened: ProDOS left the boot path on 2026-09-04,
 * the legacy arm no longer has a filesystem under it, and it now writes the
 * same layout with its three times left at zero rather than synthesised.
 *
 * What the cutover buys, in the tracker's terms: apple/fgx#319 (every file
 * dated Jan 1 1970 -- the inode always had the epoch and the image had nowhere
 * to put it) and the REPORTING half of apple/fgx#320 (mode, uid, gid, nlink
 * had no fields at all).  Enforcement is a separate job and is still absent:
 * `ufs_access' is `ufs_enotsup' and namei asks it nothing.
 */
int
root_stat(pid, path, sb)
int   pid;
char *path;
char *sb;
{
    return (root_stat_1(pid, path, sb, 1));
}


/* root_lstat -- lstat(2): stat(2) that does NOT follow a final symlink.
 *
 * Reno's is stat's six lines with NOFOLLOW where FOLLOW was
 * (kern/vfs_syscalls.c:995-1012), and root_stat's own header already said so:
 * "FOLLOW is the ONLY thing separating stat from lstat".  It is a wrapper here
 * rather than a copy for exactly that reason -- two bodies differing by one
 * flag is two bodies to keep in step.
 *
 * IT WAS `#define lstat stat' IN LIBC UNTIL 2026-09-05, which made every
 * symlink report its target.  ls(1) shows a link as a link because upstream
 * stats with lstat BY DEFAULT (`statf = Lflg ? stat : lstat'), so with the two
 * identical the 'l' type could never appear however good the rest was. */
int
root_lstat(pid, path, sb)
int   pid;
char *path;
char *sb;
{
    return (root_stat_1(pid, path, sb, 0));
}


static int
root_stat_1(pid, path, sb, follow)
int   pid;
char *path;
char *sb;
int   follow;
{
    struct nameidata *ndp;
    struct vattr      va;
    long              blocks;
    unsigned short    mode;
    int               error;
    int               i;

    if (root_status != 1)
        return (ENXIO);

    /* THE CALLER'S SLOT, as vfs_listdir's now is.  This walk asks for
     * LOCKLEAF too, and every stat(2) in the system came through it on PID 1's
     * nameidata -- two walks sharing one slot orphan a lock, which ufs_ilock
     * reports as `lockself'.  apple/fgx#311. */
    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    ndp->ni_dirp    = path;
    ndp->ni_segflg  = UIO_SYSSPACE;
    ndp->ni_nameiop = LOOKUP | LOCKLEAF;           /* Reno stat(2) :971 */
    if (follow)
        ndp->ni_nameiop |= FOLLOW;                 /* ...and lstat(2) :1000 */
    /* THE PROCESS'S OWN DIRECTORY.  apple/fgx#295: this was a hard zero, so
     * `stat(".")' answered about the ROOT -- and stat gates every directory
     * operation, which is why a bare `ls' failed while `ls /etc' worked.
     * Unconditional, for the reason vfs_listdir's twin of this comment gives:
     * namei owns the absolute/relative decision and is the only thing that can
     * make it again after a symlink. */
    ndp->ni_cdir    = vfs_cdir(pid);
    ndp->ni_rdir    = (struct vnode *)0;
    ndp->ni_vp      = (struct vnode *)0;
    ndp->ni_dvp     = (struct vnode *)0;

    error = namei(ndp);
    if (error)
        return (error);

    error = vn_stat(ndp->ni_vp, sb);
    vput(ndp->ni_vp);
    return (error);
}


/* vn_stat -- a vnode's attributes as a `struct stat'.  4.3BSD-Reno
 * kern/vfs_vnops.c, and it is upstream's function rather than a helper of ours.
 *
 * IT IS A FUNCTION BECAUSE THERE ARE TWO CALLERS, which is the whole reason
 * Reno has it: stat(2) reaches a vnode by name and fstat(2) reaches one by
 * descriptor, and the conversion between them must not differ.  This body was
 * inlined in root_stat_1 while stat(2) was the only asker, on vfs_vnops.c's
 * reasoning that it "belongs with the syscall that asks for it" -- and when
 * fstat(2) became the second asker it had nothing to call, kept answering from
 * the FCB, and reported st_ino as 0 where stat(2) reported the real inode.
 * getwd(3) compares those two answers to decide it has reached the root, so it
 * never terminated (apple/fgx#365).
 *
 * THE CALLER OWNS THE VNODE.  Upstream's stat(2) does `vn_stat' then `vput';
 * this does not release, for the same reason.
 *
 * THE TYPE COMES FROM THE VNODE AND THE PERMISSIONS FROM va_mode, which is
 * upstream's division and not an arrangement of ours: `mode = vap->va_mode'
 * then a switch on `vp->v_type' OR-ing in S_IF*, because va_mode carries
 * permission bits only -- vnode.h says so where it is declared.
 */
int
vn_stat(vp, sb)
struct vnode *vp;
char         *sb;
{
    struct vattr   va;
    long           blocks;
    unsigned short mode;
    int            error;
    int            i;

    error = vn_getattr(vp, &va);
    if (error)
        return (error);

    for (i = 0; i < STAT_SIZE; i++)
        sb[i] = 0;

    mode = (unsigned short)(va.va_mode & 07777);
    if (va.va_type == VDIR)
        mode |= S_IFDIR;
    else if (va.va_type == VREG)
        mode |= S_IFREG;
    else if (va.va_type == VCHR)
        mode |= S_IFCHR;
    else if (va.va_type == VBLK)
        mode |= S_IFBLK;
    else if (va.va_type == VLNK)
        mode |= S_IFLNK;
    else if (va.va_type == VSOCK)
        mode |= S_IFSOCK;
    /* Anything else keeps a zero type field.  Reno returns EBADF for the
     * default arm; that is right for a v_type this kernel cannot make.
     *
     * VSOCK IS HERE BECAUSE A NODE THAT CANNOT BE SEEN IS NOT A NODE.  Making
     * unp_bind able to CREATE one is half the job: without this arm the inode is
     * right on the platter and every reader is told it has no type at all, so
     * S_ISSOCK is false, `ls -l' prints no `s', and the only way to tell a bound
     * socket from a 0777 regular file is to open it. */

    SBSET16(sb, STX_dev,   va.va_fsid);
    SBSET16(sb, STX_ino,   va.va_fileid);
    SBSET16(sb, STX_mode,  mode);
    SBSET16(sb, STX_nlink, va.va_nlink);
    SBSET16(sb, STX_uid,   va.va_uid);
    SBSET16(sb, STX_gid,   va.va_gid);
    /* NODEV UNLESS THE VNODE NAMES A DEVICE, which is the whole reason
     * sys/stat.h argued for the field: 2.11BSD's fsck decides it is checking
     * the root with `rootdev == statb.st_rdev', and zero-for-everything makes
     * that true on every volume. */
    if (va.va_type == VCHR || va.va_type == VBLK)
        SBSET16(sb, STX_rdev, va.va_rdev);
    else
        SBSET16(sb, STX_rdev, 0xFFFF);

    SBSET32(sb, STX_size, va.va_size);

    /* A SHIFT AND NOT A DIVIDE.  `/ 512' on an off_t pulls fcc's 32-bit
     * unsigned divide runtime into this bank for a value that is a power
     * of two; measured at 1,655 bytes of far bank against 737 free. */
    blocks = (va.va_size + 511) >> 9;
    SBSET16(sb, STX_blocks, (unsigned short)blocks);

    /* THE DATES, WHICH EVERY FILE REPORTED AS Jan 1 1970 (apple/fgx#319).
     * The inode always had them -- ufs_getattr fills va_mtime from i_mtime --
     * and the legacy image had nowhere to put a Unix epoch.  It has one now. */
    /* `va.va_mtime' AND NOT `va.va_mtime.tv_sec'.  Reno's vn_stat says the
     * latter because its vattr carries a struct timeval; this tree's vattr
     * flattened the three to time_t (vnode.h:342-344), so the member does not
     * exist here and fcc said so. */
    SBSET32(sb, STX_mtime, va.va_mtime);
    SBSET32(sb, STX_atime, va.va_atime);
    SBSET32(sb, STX_ctime, va.va_ctime);

    return (0);
}


/* root_fstat -- fstat(2) against the mounted root.  apple/fgx#365.
 *
 * RENO'S fstat, WHICH LIVES IN kern/kern_descrip.c AND NOT IN THE VFS, because
 * it is a DESCRIPTOR operation where stat(2) is a namespace one.  Its whole
 * body is the type switch:
 *
 *      case DTYPE_VNODE:  error = vn_stat((struct vnode *)fp->f_data, &ub);
 *      case DTYPE_SOCKET: error = soo_stat((struct socket *)fp->f_data, &ub);
 *      default:           panic("fstat");
 *
 * THERE IS NO FALLBACK ARM UPSTREAM AND THERE IS NONE HERE.  Reno's `default'
 * is a panic on purpose: a descriptor type fstat was never taught is a kernel
 * bug, not a reason to answer with something plausible.  Answering anyway is
 * exactly how apple/fgx#365 survived -- the FCB arm reported st_ino 0 because
 * it could not know better, and no caller could tell that from a real zero.
 *
 * PIPES TAKE THE SOCKET ARM BECAUSE UPSTREAM HAS NO OTHER.  Reno's pipe(2) is
 * a socketpair (kern/uipc_syscalls.c: two AF_UNIX SOCK_STREAM sockets, f_type
 * DTYPE_SOCKET), so soo_stat is what a pipe gets there.  DTYPE_PIPE is
 * 2.11BSD's, carried here because this kernel has real pipes; the ANSWER is
 * still Reno's, and soo_stat's answer is `bzero' plus whatever the protocol
 * knows through PRU_SENSE -- mostly zeros, BY DESIGN and through a named
 * function, which is the distinction this file is being careful about.
 */
int
root_fstat(pid, fd, sb)
int   pid;
int   fd;
char *sb;
{
    struct file *fp;
    int          i;

    if (root_status != 1)
        return (ENXIO);

    fp = getf(pid, fd);
    if (fp == (struct file *)0)
        return (EBADF);

    /* fp_isvn, not f_type: vn_stat on a provisional descriptor's FCB is a
     * wild jump -- `echo hi | cat' took the machine down the moment cat
     * fstat'd its stdin.  Such a descriptor answers as a pipe does, below. */
    if (fp_isvn(fp))
        return (vn_stat((struct vnode *)fp->f_data, sb));

    if (fp->f_type >= DTYPE_VNODE && fp->f_type <= DTYPE_PIPE) {
        /* soo_stat: `bzero((caddr_t)ub, sizeof (*ub))' and then PRU_SENSE.
         * Nothing in this tree answers PRU_SENSE, so the zeroing is the whole
         * of it -- which is upstream's answer for a socket whose protocol
         * fills nothing, not a shortfall of ours. */
        for (i = 0; i < STAT_SIZE; i++)
            sb[i] = 0;
        return (0);
    }

    kc_panic("fstat");                 /* Reno's default: see above */
    return (EBADF);
}


/* root_readlink -- readlink(2) against the mounted root.  apple/fgx#326.
 *
 * ROOT_LISTDIR'S THREE LINES, and that is the fix.  This function used to do
 * the WALK here and hand a vnode to vfs.mod for the last hop; it returned the
 * right count with the wrong bytes, and a day of narrowing ended with
 * vfs_listdir -- which takes a caller buffer across the same seam -- working.
 * So the walk moved to where namei lives and this became the routing decision
 * it should always have been.  vfs_readlink's header carries the whole account.
 */
int
root_readlink(pid, path, buf, count)
int   pid;
char *path;
char *buf;
int   count;
{
    if (root_status != 1)
        return (-ENXIO);
    return (vfs_readlink(pid, path, buf, count));
}


/* root_listdir -- listdir(2) against the mounted root.  UFS campaign, the
 * directory-read conversion (apple/fgx#291).
 *
 * root_open's sibling and it is the same three lines for the same reason: the
 * ROUTING decision is this bank's, because `root_status' is root_mount.c's
 * storage here, and the WORK is vfs.mod's, because namei and VOP_READDIR both
 * are.  vfs_listdir's header carries the body and the measurement that put it
 * there.
 *
 * ENXIO FOR AN UNMOUNTED ROOT, for root_open's reason exactly: the core's hook
 * FALLS THROUGH on a negative return rather than failing the call, so a
 * machine whose boot volume is ProDOS is a machine whose every listdir still
 * reaches the legacy resolver.  This errno is a routing answer, not a
 * user-visible one.
 *
 * root_status AND NOT root_mounted: the first says ufs_mountfs succeeded, the
 * second that vfs_setroot took the root as well, and a walk needs the second.
 *
 * Returns the bytes written (>= 0), or -errno.
 */

int
root_listdir(pid, path, buf, size)
int   pid;
char *path;
char *buf;
int   size;
{
    if (root_status != 1)
        return (-ENXIO);
    return (vfs_listdir(pid, path, buf, size));
}


/* root_ftruncate -- ftruncate(2).  4.3BSD-Reno kern/vfs_syscalls.c:1346.
 * UFS 2.7.
 *
 * IT WAS A STUB ANSWERING ENOSYS, and it had been since 2026-09-04.  Its body
 * was Fs_Truncate in drivers/fs/write.s, the ProDOS write path, deleted with
 * ProDOS; _Fs_NoLegacy's own header says so and calls both it and rename
 * "ports waiting to be written, not decisions".  rename got written; this is
 * the other one.  Nothing under it was missing -- ufs_setattr has honoured
 * va_size since 1.12b (ufs_vnops.c) and calls the ported ufs_itrunc -- so what
 * was absent was only the path from a descriptor down to VOP_SETATTR.
 *
 * UPSTREAM'S ORDER, AND ALL FOUR REFUSALS:
 *
 *      if (error = getvnode(u.u_ofile, uap->fd, &fp)) RETURN (error);
 *      if ((fp->f_flag & FWRITE) == 0)               RETURN (EINVAL);
 *      ...
 *      if (vp->v_type == VDIR)   { error = EISDIR; goto out; }
 *      if (error = vn_writechk(vp))                  goto out;
 *      error = VOP_SETATTR(vp, &vattr, fp->f_cred);
 *
 * EINVAL AND NOT EBADF FOR A READ-ONLY DESCRIPTOR, which is upstream's choice
 * and is worth keeping rather than "improving": a descriptor opened O_RDONLY
 * is a perfectly good descriptor, so EBADF would be a lie about the fd.  That
 * is why the guard here is `getf' and an explicit FWRITE test rather than
 * `fdcheck(pid, fd, FWRITE)': fdcheck folds "not open" and "open the wrong
 * way" into one null return, and the two faults have two different errnos
 * upstream -- EBADF from getvnode, EINVAL from the flag test beside it.
 *
 * THE vattr IS BUILT IN vfs.mod, not here.  `vattr_null' lives beside the
 * structure it fills, so the seam carries a SIZE and vn_setsize does both -- see its header for why a
 * half-initialised vattr is the failure worth designing out.
 *
 * NO VOP_LOCK/VOP_UNLOCK BRACKET.  Reno takes one around the setattr; this
 * kernel's vnode locking is the vput/vrele discipline described in vnode.h and
 * there is no lock to take on a vnode held by an open file -- the same reason
 * vfs_lseek above reads va_size through vn_getattr without one.  Stated rather
 * than left as a silent omission from a function that otherwise follows
 * upstream line for line.
 *
 * NO VOP_ACCESS.  Reno's truncate(2) calls it and its ftruncate(2) does NOT --
 * the descriptor's own FWRITE is the check at this door, which is the same
 * split apple/fgx#324 records for the rest of the credential model.
 */
int
root_ftruncate(pid, fd, length)
int    pid;
int    fd;
off_t  length;
{
    struct file  *fp;
    struct vnode *vp;

    if (root_status != 1)
        return (ENXIO);

    fp = getf(pid, fd);
    if (fp == (struct file *)0)
        return (EBADF);
    if (fp->f_type != DTYPE_VNODE)
        return (EINVAL);
    if ((fp->f_flag & FWRITE) == 0)
        return (EINVAL);

    vp = (struct vnode *)fp->f_data;
    if (vp->v_type == VDIR)
        return (EISDIR);

    /* NEGATIVE IS REFUSED, AND UPSTREAM DOES NOT REFUSE IT.  Reno hands
     * uap->length straight to VOP_SETATTR, because on a PDP-11 a negative
     * off_t that reached ufs_itrunc met a filesystem that refused it.  Here it
     * reaches a loop that indexes with it -- vfs_lseek two functions down
     * carries the same divergence and the same reason. */
    if (length < 0L)
        return (EINVAL);

    return (vn_setsize(vp, length));
}


/* root_fsync -- fsync(2).  4.3BSD-Reno kern/vfs_syscalls.c:1383, whose body is

 *      if (error = getvnode(u.u_ofile, uap->fd, &fp))
 *              RETURN (error);
 *      vp = (struct vnode *)fp->f_data;
 *      VOP_LOCK(vp);
 *      error = VOP_FSYNC(vp, fp->f_flag, fp->f_cred, MNT_WAIT);
 *      VOP_UNLOCK(vp);
 *
 * IT REACHED NO FILESYSTEM AT ALL BEFORE THIS.  `Fs_Fsync' dispatched
 * FOP_Flush into the ProDOS FST, which answers EIO on a 2.11BSD volume, so
 * every fsync(2) of a regular file failed -- and `ufs_fsync' has been ported
 * and unreachable since 1.12, VOP_FSYNC having exactly two callers, both in a
 * probe.  apple/fgx#355.
 *
 * WHAT IS OWED IS THE INODE, NOT THE DATA.  `ufs_write' bwrites every buffer
 * it fills before it returns (ufs_vnops.c:636), so a file's bytes are already
 * on the platter; what it leaves behind is IUPD|ICHG on the inode, with the
 * write-back deferred to the last vrele (ufs_vnops.c:641).  That is precisely
 * what fsync(2) exists to force, and what `ufs_fsync' does -- `iupdat(ip,
 * waitfor)'.
 *
 * THE VOP_FSYNC IS ufs.mod's, in ufs_fsyncvp: `ufs_fsync' lives in ufsdir.mod,
 * which exports nothing, and ufs_fsyncvp's header says how it is reached.
 *
 * MNT_WAIT, which is upstream's fourth argument.  sync(2) passes MNT_NOWAIT
 * through vfs_sync1 because it is sweeping every mount; a caller who named one
 * descriptor is asking to be told when it is down.
 *
 * NO MODE REQUIREMENT ON THE DESCRIPTOR -- fdcheck's `want' is 0, as
 * root_fchdir's is.  Reno's getvnode does not test f_flag either, and fsync of
 * a read-only descriptor is legal: it is the FILE that is synced.
 *
 * EINVAL FOR A NON-VNODE, which is what Reno's getvnode answers for a
 * descriptor that is a socket or a pipe.  It does not reach here anyway --
 * `Fs_Fsync' answers success for those FCB types before crossing -- but the
 * arm is the one upstream has and a future caller crossing directly gets it.
 */
int
root_fsync(pid, fd)
int pid;
int fd;
{
    struct file *fp;

    if (root_status != 1)
        return (ENXIO);

    fp = fdcheck(pid, fd, 0);
    if (fp == (struct file *)0)
        return (EBADF);
    if (fp->f_type != DTYPE_VNODE)
        return (EINVAL);

    return (ufs_fsyncvp((struct vnode *)fp->f_data, fp->f_flag));
}


/* root_fchdir -- fchdir(2).  4.3BSD-Reno kern/vfs_syscalls.c:433.  UFS 2.7.
 *
 * IT WAS A libc STUB ANSWERING ENOSYS, and its own note said what it would
 * cost and why it had not been paid: "it needs the file table's vnode handed
 * to vfs.mod's cwd table, which is a KFAR slot and a seam entry of its own.
 * The far bank has 86 bytes free, which is the whole reason this is a stub
 * today."  The far bank has over 9,000 now, so the reason had expired --
 * which is the argument for a stub saying what blocks it rather than that it
 * is missing.
 *
 * chmod(1) and chown(8) are the callers that notice: their -R walk saves the
 * starting directory with open(".") and comes back to it with fchdir, and a
 * verbatim port carries the reference whether the system has one or not.
 *
 * NO MODE REQUIREMENT ON THE DESCRIPTOR.  fdcheck's `want' is 0, which is
 * lseek's: Reno's getvnode does not test f_flag either, and a directory
 * opened O_RDONLY is exactly what open(".") gives.
 *
 * THE TYPE TEST IS vfs.mod's, not repeated here.  Reno tests v_type under
 * VOP_LOCK and this tree's equivalent lives beside the cwd table -- see
 * vfs_fchdir, which also records why VOP_ACCESS is absent.
 */
int
root_fchdir(pid, fd)
int pid;
int fd;
{
    struct file *fp;

    if (root_status != 1)
        return (ENXIO);

    fp = fdcheck(pid, fd, 0);
    if (fp == (struct file *)0)
        return (EBADF);
    if (fp->f_type != DTYPE_VNODE)
        return (ENOTDIR);

    return (vfs_fchdir(pid, (struct vnode *)fp->f_data));
}


/* vfs_access -- access(2)'s name half.  UFS campaign 2.6, apple/fgx#324.
 *
 * Ported from 2.11BSD's saccess() (usr/sys/sys/ufs_syscalls.c:383) with
 * 4.3BSD-Reno's (kern/vfs_syscalls.c:911) read beside it.  This is the half
 * that resolves the name; vn_access (vfs_vnops.c) is the half that asks the
 * mode, and the split is where the bank boundary falls rather than a design.
 *
 * THE IDS ARE ALREADY SWAPPED when this runs.  access(2) answers for the REAL
 * ids, and `_Sys_Access' does that by assignment around this call, exactly as
 * both upstreams do it around their own bodies.  Nothing here passes a
 * credential: ufs_access reads the effective ids back through the kc_curuid
 * seam, and they are temporarily the real ones.
 */
int
vfs_access(pid, dvp, path, fmode)
int           pid;
struct vnode *dvp;
char         *path;
int           fmode;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    int               error;

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    /* THE FIELDS ARE SET BY HAND, not through nd_begin: that helper lives in
     * vfs.mod and this file is the far bank's.  vfs_mountat a few hundred
     * lines up does the same, and for the same reason ni_vp and ni_dvp are
     * cleared rather than trusted -- an ndslot persists across walks. */
    ndp->ni_dirp    = path;
    ndp->ni_segflg  = UIO_SYSSPACE;
    ndp->ni_cdir    = dvp;
    ndp->ni_rdir    = (struct vnode *)0;
    ndp->ni_vp      = (struct vnode *)0;
    ndp->ni_dvp     = (struct vnode *)0;
    ndp->ni_nameiop = LOOKUP | FOLLOW;

    error = namei(ndp);
    if (error)
        return (error);

    vp    = ndp->ni_vp;
    error = vn_access(vp, fmode);      /* fmode 0 = F_OK: vn_access asks nothing */
    vrele(vp);
    return (error);
}


/* unp_nameop -- an AF_UNIX socket's NAME, bound and looked up.  Far slot 74.
 *
 * 4.3BSD-Reno kern/uipc_usrreq.c's `unp_bind' and `unp_connect', which are the
 * two halves of this and are not otherwise reachable: namei lives in vfs.mod,
 * the C that calls it is in this far bank, and net.mod -- where the AF_UNIX
 * transport is -- can reach neither directly.  So the whole nameidata dance
 * happens here, in one call, rather than step by step across three seams.
 *
 * ONE ENTRY AND NOT TWO, because bind and lookup differ only in the walk they
 * ask for and what they do with the vnode.  A second far slot for that would be
 * a slot spent on a switch.
 *
 * `path' NAMES CORE-BANK MEMORY -- `_Sys_PathBuf', which the KSVC arm fills with
 * `_Sys_CopyPathToBuf' before it calls -- and the core-side stub supplies its
 * bank, as slot 71's does for `_fsStatBuf'.
 *
 * `slotp' CARRIES THE DESCRIPTOR SLOT BOTH WAYS: in for a bind, out for a
 * lookup.  It too is core-bank memory, and it is one word because a descriptor
 * index is what a socket's identity reduces to on this side of the seam -- the
 * far bank has no business knowing net.mod's table layout.
 *
 * IT IS STORED AS INDEX+1 so that zero means "no socket here", which a plain
 * index cannot: descriptor 0 is a live descriptor.  That distinction is load
 * bearing, because the name outlives the socket -- close(2) does not unlink it,
 * which is why syslogd unlinks before it binds -- so a VSOCK node with nothing
 * behind it is the ordinary case after a restart and must answer ECONNREFUSED
 * rather than connecting to descriptor 0.
 */
/* THE VNODE EACH BOUND SOCKET HOLDS -- Reno's per-unpcb `unp_vnode', indexed by
 * descriptor slot because that is what a socket's identity reduces to across the
 * seam.  It lives here and not in net.mod's socket record because only the bank
 * that holds vnodes can name one.
 *
 * unp_bind KEEPS the reference this remembers, and UNP_OP_UNBIND drops it.  A
 * bind that released the vnode instead left it reclaimable, and getnewvnode
 * zeroes `v_un' on reuse, so the name stopped resolving to its socket once the
 * pool turned over -- with syslogd still alive and still bound. */
static struct vnode *unp_vnodes[UNP_NVNODE];

int
unp_nameop(pid, op, path, slotp)
int             pid;
int             op;
char           *path;
unsigned short *slotp;
{
    struct nameidata *ndp;
    struct vattr      vattr;
    struct vnode     *vp;
    int               error;
    unsigned short    slot;

    /* THE ROOT-STATUS GATE GUARDS THE WALKS, and UNBIND does not walk.  It is
     * tested after the slot is taken and after the UNBIND arm has run, because
     * a close that answered ENXIO would leak the vnode a bind is holding and
     * leave the node's `v_un' naming a descriptor that is being freed.  Nothing
     * clears root_status once the root is mounted, so this is ordering rather
     * than a live path -- but the ordering is what makes the release
     * unconditional, which is what a close needs. */

    /* THE SLOT IS TAKEN OUT OF `slotp' BEFORE ANYTHING CAN SLEEP.  It points at
     * a core-bank global that the next task's socket call rewrites, and namei
     * and VOP_CREATE both sleep, so a second bind arriving mid-walk would leave
     * this one naming the other's descriptor.  The lookup arm has the mirror of
     * the same problem and stores its answer LAST, after vput. */
    if (op != UNP_OP_LOOKUP) {
        slot = *slotp;
        if (slot >= UNP_NVNODE)
            return (EINVAL);
    }

    /* UNBIND TAKES NO WALK, so it runs before a nameidata is claimed.  This is
     * Reno's unp_detach (kern/uipc_usrreq.c): `unp->unp_vnode->v_socket = 0;
     * vrele(unp->unp_vnode); unp->unp_vnode = 0'.  Without it the name outlived
     * the socket with its slot still in `v_un', so a later socket taking that
     * slot inherited every stale name pointing at it.
     *
     * THE TABLE AND `v_un' ARE CLEARED BEFORE THE vrele, which can sleep in
     * VOP_INACTIVE: a task that ran in the middle would otherwise find a
     * half-torn entry naming a vnode already on its way out. */
    if (op == UNP_OP_UNBIND) {
        vp = unp_vnodes[slot];
        if (vp == (struct vnode *)0)
            return (0);           /* never bound, or unbound already */
        unp_vnodes[slot] = (struct vnode *)0;
        vp->v_un         = (struct specinfo *)0;
        vrele(vp);
        return (0);
    }

    if (root_status != 1)
        return (ENXIO);

    /* THE CALLER'S SLOT, for the reason root_stat_1's comment gives: this walk
     * asks for LOCKPARENT or LOCKLEAF, and two walks sharing one nameidata
     * orphan a lock that ufs_ilock then reports as `lockself'. */
    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    ndp->ni_dirp   = path;
    ndp->ni_segflg = UIO_SYSSPACE;
    ndp->ni_cdir   = vfs_cdir(pid);
    ndp->ni_rdir   = (struct vnode *)0;
    ndp->ni_vp     = (struct vnode *)0;
    ndp->ni_dvp    = (struct vnode *)0;

    if (op == UNP_OP_BIND) {
        /* unp_bind: "ndp->ni_nameiop = CREATE | FOLLOW | LOCKPARENT". */
        ndp->ni_nameiop = CREATE | FOLLOW | LOCKPARENT;
        error = namei(ndp);
        if (error)
            return (error);

        /* THE NAME ALREADY EXISTS -- EADDRINUSE, and upstream's comment marks
         * adopt-and-wakeup as a FIFO-style improvement it did not make.  The
         * release is vfs_mkdir's, not upstream's: Reno calls VOP_ABORTOP first
         * and this tree does not have that macro, deliberately (vnode.h says a
         * macro nobody uses is a macro nobody has checked). */
        vp = ndp->ni_vp;
        if (vp != (struct vnode *)0) {
            if (ndp->ni_dvp == vp)
                vrele(ndp->ni_dvp);
            else
                vput(ndp->ni_dvp);
            vrele(vp);
            return (EADDRINUSE);
        }

        /* VOP_CREATE AND NOT VOP_MKNOD, which is upstream's route for a socket
         * node: "vattr.va_type = VSOCK; vattr.va_mode = 0777;". */
        /* ONLY THE TWO FIELDS THIS MEANS ARE SET, which is what vn_mknode does
         * for its own VOP_CREATE in this tree: ufs_create reads va_type and
         * va_mode and nothing else.  vattr_null is not called because it lives in
         * vfs.mod and this bank cannot reach it -- and vnode.h's note on the
         * absent VATTR_NULL is the same argument one layer up. */
        vattr.va_type = VSOCK;
        vattr.va_mode = (unsigned short)0777;
        error = VOP_CREATE(ndp, &vattr);
        if (error == 0) {
            /* `vp->v_socket = unp->unp_socket' upstream.  Here it is the
             * descriptor slot, in the same union arm and with the same cast
             * vfs_mountat uses for mountedhere -- the far bank cannot name
             * net.mod's table. */
            vp = ndp->ni_vp;
            vp->v_un        = (struct specinfo *)(slot + 1);
            unp_vnodes[slot] = vp;
            /* VOP_UNLOCK AND NOT vput, WHICH IS WHAT UPSTREAM DOES: unp_bind
             * ends `unp->unp_vnode = vp; VOP_UNLOCK(vp)', keeping the
             * reference for the socket's life.  vput is VOP_UNLOCK plus vrele,
             * and dropping the count to zero here left the vnode reclaimable
             * with its slot still in `v_un' -- getnewvnode zeroes that word on
             * reuse, so about 64 lookups later connect(2) answered
             * ECONNREFUSED for a name whose socket was still bound and still
             * reading.  UNP_OP_UNBIND is what releases it.
             *
             * The mount path holds a reference through the same union word for
             * the same reason: see vfs_mountat, "the mount's own reference
             * stands". */
            VOP_UNLOCK(vp);
        }
        /* AND THE PARENT ALWAYS, which is vfs_mkdir's rule: ufs_makeinode reads
         * ni_dvp and never touches its reference or its lock. */
        vput(ndp->ni_dvp);
        return (error);
    }

    /* unp_connect: "ndp->ni_nameiop = LOOKUP | FOLLOW | LOCKLEAF". */
    ndp->ni_nameiop = LOOKUP | FOLLOW | LOCKLEAF;
    error = namei(ndp);
    if (error)
        return (error);
    vp = ndp->ni_vp;

    /* "if (vp->v_type != VSOCK) { error = ENOTSOCK; goto bad; }" */
    if (vp->v_type != VSOCK) {
        vput(vp);
        return (ENOTSOCK);
    }

    /* "error = VOP_ACCESS(vp, VWRITE, p->p_ucred)".  FGX is not a secure
     * platform, but a BSD permission check still ports -- and this one earns its
     * keep: syslogd chmods /dev/log 0666 deliberately, which only means
     * something if the write permission is asked for. */
    error = VOP_ACCESS(vp, VWRITE, (char *)0);
    if (error) {
        vput(vp);
        return (error);
    }

    if (vp->v_un == (struct specinfo *)0) {
        vput(vp);
        return (ECONNREFUSED);
    }
    /* THE ANSWER IS STORED LAST, AFTER vput.  `slotp' is a core-bank global the
     * next task's socket call rewrites, and vput sleeps in VOP_INACTIVE, so a
     * store before it can be overwritten before this call returns -- the caller
     * would then wire itself to whichever descriptor the other task was naming.
     * Nothing sleeps between this store and the caller's read of it. */
    slot = (unsigned short)((unsigned short)vp->v_un - 1);
    vput(vp);
    *slotp = slot;
    return (0);
}
