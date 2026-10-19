/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/vfs_lookup.c
 *   Ported from kern/vfs_lookup.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* vfs_lookup.c -- namei and lookup: turning a pathname into a vnode.
 *
 * Ported from 4.3BSD-Reno kern/vfs_lookup.c.  UFS 1.6b.
 *
 * TWO ROUTINES AND A CLEAN SPLIT.  namei() owns the pathname -- where it came
 * from, where the walk starts, and (in Reno) restarting the whole thing when a
 * symlink rewrites it.  lookup() owns the WALK: one component at a time, from
 * a directory vnode, until the path runs out.  Keeping them apart is what lets
 * a symlink restart the path without the walk knowing symlinks exist.
 *
 * THE FILESYSTEM RESOLVES THE NAME; lookup() RESOLVES THE NAMESPACE.  That
 * division is the whole design and it is easy to get backwards.  VOP_LOOKUP is
 * handed one component and searches one directory -- including "." and "..",
 * which are ordinary entries on a real Unix volume and which a filesystem
 * therefore answers like any other name.  What lookup() does that no
 * filesystem can is decide WHICH directory to ask next: crossing DOWN into a
 * mounted filesystem, crossing UP out of one (the parent of a mount point
 * belongs to whoever mounted it, not to the filesystem being left), and
 * stopping ".." at the root so a path cannot escape it.  ni_isdotdot exists to
 * carry that decision, not to tell a filesystem to skip a name.
 *
 *----------------------------------------------------------------------------
 * WHAT IS DELIBERATELY NOT HERE, each with the thing it is waiting for.  These
 * are gaps, not simplifications, and naming them is cheaper than rediscovering
 * them:
 *
 *   SYMLINKS AND MOUNT POINTS WERE BOTH ON THIS LIST AND ARE BOTH HERE NOW.
 *   The entries stayed after the code landed, and a reader who trusts a
 *   contract block over the file under it is reading a 1.10-era kernel that no
 *   longer exists.  Symlinks: `nexpand' (:366) is Reno's splice, namei loops
 *   on it with ni_loopcnt and MAXSYMLINKS, lookup() stops the walk on Reno's
 *   own two-clause VLNK condition (:831), and ufs_symlink/ufs_readlink are
 *   REAL entries in the ufs vnodeops table (ufs_vnops.c:1961, :1963).  Mount
 *   points: the descent through `v_un' is the while-loop at :834 and the ".."
 *   ascent through mnt_vnodecovered is at :776.  What each still lacks is
 *   named at the code, not here.
 *
 *   CREDENTIALS.  No VOP_ACCESS call here, and it is not owed: Reno checks
 *   execute permission on every directory it descends into, and 2.6 put that
 *   check where BOTH upstreams put it -- `ufs_access(dvp, VEXEC, 0)' inside
 *   ufs_lookup (ufs_lookup.c:418), called directly rather than through
 *   VOP_ACCESS, which is Reno's own arrangement.  What is still absent here is
 *   the rdonly check, no filesystem reached this way being read-only.
 *
 *   copyin.  ni_segflg distinguishes a user pathname from a kernel one and
 *   this only handles the kernel one: the syscall layer copies every pathname
 *   into a kernel buffer before it calls namei.  A user pointer is REFUSED rather than
 *   dereferenced -- reading it as if it were a kernel address is how a wrong
 *   answer becomes a wild pointer.
 *
 *----------------------------------------------------------------------------
 * THE PATHNAME BUFFER IS THE CALLER'S, and that is a deliberate departure from
 * Reno, which mallocs one per walk.  A static buffer here would be exactly the
 * singleton the campaign's own reentrancy audit warns about: this walk CAN
 * sleep the moment a real filesystem is under it, and a shared work area
 * crossing a sleep is the shape of apple/fgx#41.  There is no per-process
 * u-area to hang it off until 1.7, so the ownership question is handed to the
 * caller rather than answered wrongly now.
 */

#include "fsparam.h"
#include "vnode.h"
#include "mount.h"
#include "vfsops.h"
#include "namei.h"

extern void vref();
extern void vrele();
extern void vput();      /* VOP_UNLOCK + vrele, as Reno's is */
/* DECLARED, AND K&R C IS WHY.  An undeclared function defaults to returning
 * `int' -- 16 bits here -- and ndslot returns a POINTER.  This file never
 * called it until vfs_chdir did, and without this the nameidata address
 * arrives truncated: namei appears to run, the ni_vp it hands back is junk,
 * and the first dereference of it takes the machine down between `boot:
 * loading shell' and /etc/rc.  THIRD instance of the class filed as
 * apple/fgx#293, after root_ump and vfs_vnops.c's own missing ndslot. */
extern struct nameidata *ndslot();

int lookup();

/* THE ROOT OF THE NAMESPACE.  Set by whoever mounts the root filesystem
 * (Reno: rootdir = VFS_ROOT(mp) after mounting rootdev), and read here for any
 * path beginning with '/'.  Zero until then, which namei reports as ENOENT
 * rather than dereferencing -- a machine with no root cannot resolve an
 * absolute path, and saying so beats faulting. */
struct vnode *rootdir;

/* THE /dev MOUNT'S ROOT IS NOT KEPT HERE, and that is the correction UFS 1.7d
 * I3 made to its own first cut.  It was a `struct vnode *devroot' beside
 * `rootdir' above, on the reasoning that /dev is a SECOND NAMESPACE ROOT --
 * root is still ProDOS and /dev is a UFS filesystem mounted beneath a name the
 * legacy resolver still owns.
 *
 * It is an OUTPUT of vfs_devroot instead, because the far bank already owns
 * every other piece of that mount -- `dev_mnt', `dev_ump', `dev_devvp' in
 * dev_mount.c -- and the hook that opens a name under /dev runs there.  A copy
 * here would be a second authority on the same fact, which is #114's lesson
 * exactly: a path model with two authorities is worse than one honestly
 * absent.
 *
 * WHAT IT IS NOT is namei's `ni_rdir'.  A walk rooted at /dev's root is an
 * ordinary walk with ni_cdir set and a RELATIVE name -- "null", not "/null" --
 * so no chroot machinery is involved and ni_rdir stays 0.  At Phase 2.5 this
 * folds into the UFS root and the whole arrangement goes away.
 */

/* vfs_devroot -- take `mp's root and hand it back, unlocked.
 *
 * IT LIVES IN vfs.mod, beside the vput its refusal arm calls and the vnode
 * layer it answers for.  The far bank mounts and hands the mount here.
 *
 * AND IT MUST BE UNLOCKED, which ufs_root's own header states as the caller's
 * job: "Callers that want to HOLD the root -- as a cwd, as rootdir -- must
 * VOP_UNLOCK it first, because namei locks every directory it descends into
 * and the first of those is the one it was given."  Holding it locked would
 * deadlock the first lookup against a lock this process owns, which is the
 * `lockself' panic the directory layer has already produced twice.
 */
int
vfs_devroot(mp, vpp)
struct mount  *mp;
struct vnode **vpp;
{
    struct vnode *vp;
    int           error;

    if (mp == (struct mount *)0 || vpp == (struct vnode **)0)
        return (EINVAL);
    *vpp = (struct vnode *)0;
    error = VFS_ROOT(mp, &vp);
    if (error)
        return (error);
    if (vp == (struct vnode *)0)
        return (EIO);
    /* IT MUST BE A DIRECTORY.  VFS_ROOT returning 0 says the call worked, not
     * that what came back is a namespace root -- and a walk given a
     * non-directory root fails somewhere further along, where the cause is no
     * longer visible.  The vnode's type comes from the inode's mode bits, so
     * this also says the mount decoded a real 2.11BSD inode. */
    if (vp->v_type != VDIR) {
        vput(vp);
        return (ENOTDIR);
    }
    VOP_UNLOCK(vp);
    *vpp = vp;                  /* the reference VFS_ROOT took is the one the
                                 * mount keeps; there is no matching vrele
                                 * until unmount, which is Phase 2.5's. */
    return (0);
}


/* vfs_setroot -- make `mp's root THE root of the namespace.  UFS 2.4b.
 *
 * The far bank mounts the boot volume and calls this, because `rootdir' is
 * this file's storage: the far bank would have nowhere to put the answer.
 *
 * IT TAKES THE ROOT UNLOCKED, which is vfs_devroot's whole contract and the
 * reason that function exists in the shape it does: its header already names
 * "as rootdir" as one of the two things a caller might hold the root for.
 * namei locks every directory it descends into, starting with the one it is
 * given, so a locked rootdir deadlocks the first absolute path against a lock
 * this process already owns.
 *
 * NO vrele ANYWHERE.  The reference VFS_ROOT took is the one the mount keeps,
 * exactly as vfs_devroot documents, and the root filesystem is not unmounted.
 * If it ever is, that release belongs with the unmount and not here.
 *
 * A SECOND CALL WOULD LEAK the first root's reference and is not defended
 * against, because there is one caller and a second would be its bug -- the
 * same reasoning dev_mount.c gives for dropping its own once-guard, and for
 * the same reason: a guard on uninitialised storage is worse than none.
 */
int
vfs_setroot(mp)
struct mount *mp;
{
    struct vnode *vp;
    int           error;

    error = vfs_devroot(mp, &vp);
    if (error)
        return (error);
    rootdir = vp;
    return (0);
}


/* ---------------------------------------------------------------------------
 * THE PROCESS'S WORKING DIRECTORY, AS A VNODE.  UFS campaign, the cwd port.
 *
 * PORTED FROM 4.3BSD-Reno, which is four operations on one vnode and nothing
 * else:
 *
 *   init_main.c:183   u.u_cdir = rootdir;  VREF(u.u_cdir);
 *   vfs_syscalls.c:481   vrele(ndp->ni_cdir);  ndp->ni_cdir = ndp->ni_vp;
 *   kern_fork.c:272   VREF(u.u_cdir);
 *   kern_exit.c:139   VOP_LOCK(u.u_cdir);  vput(u.u_cdir);
 *
 * THERE IS NO PATH RESOLVER TO WRITE, and that is the finding this replaces a
 * plan with.  namei already walks a relative name -- `dp = ndp->ni_cdir' below
 * is Reno's own line -- so what was missing was never a canonicaliser but the
 * DIRECTORY a relative walk starts from.  FGX's `Path_Resolve' has no upstream
 * counterpart at all; it exists because the ProDOS FST needs a canonical
 * UPPERCASE string, and it cannot serve a 2.11BSD root for exactly that reason
 * (path.s:567 folds every component; 2.11BSD names are bytes).
 *
 * IT IS NOT IN THE ndslot, WHICH IS WHERE RENO PUTS IT.  Upstream's cwd lives
 * in `u.u_nd.ni_cdir' because the u-area is per-process and persists; this
 * tree's `ndslot' ZEROES a nameidata on every hand-out (vfs_subr.c), so it is
 * per-WALK scratch and anything left there dies at the next call.  A table of
 * its own, indexed the same way, is the honest home.
 *
 * AND IT IS IN vfs.mod RATHER THAN THE FAR BANK, beside `rootdir' and namei.
 * root_mount.c:185 declines to copy `rootdir' across the seam because that
 * would be a SECOND AUTHORITY for one fact (apple/fgx#114); a getter is the
 * opposite of that -- one authority, asked.
 * ------------------------------------------------------------------------ */

static struct vnode *cdir_vp[VFS_NPROC];

/* vfs_cdir -- the directory a relative walk starts from, for `pid'.
 *
 * A NULL ENTRY MEANS THE ROOT, which is Reno's init_main.c line expressed as a
 * default rather than a boot-time write: every process starts at `/' and says
 * so by having chosen nothing else.  It also means this table needs no
 * initialisation pass in a bank whose statics are not zeroed -- the value that
 * a cold image happens to hold is the only thing that could be wrong, and
 * vfs_cdirinit below is what makes sure it is not.
 */
struct vnode *
vfs_cdir(pid)
int pid;
{
    if (pid < 1 || pid > VFS_NPROC)
        return (rootdir);
    if (cdir_vp[pid - 1] == (struct vnode *)0)
        return (rootdir);
    return (cdir_vp[pid - 1]);
}

/* vfs_cdirfork -- the child inherits the parent's working directory.
 *
 * 4.3BSD-Reno kern_fork.c:272, `VREF(u.u_cdir)', in the block upstream heads
 * "Increase reference counts on shared objects" -- the same block that has
 * just walked the parent's open files bumping `fp->f_count'.  FGX's counterpart
 * to that walk is `_Task_CopyParentFds', and this is called from
 * `Task_InheritCwd' immediately after it, which is where the string cwd is
 * already copied.
 *
 * TWO PIDS WHERE UPSTREAM NEEDS NONE, and that is the whole difference.  Reno's
 * cwd lives in the u-area, so `procdup' copies the POINTER as a side effect of
 * copying the u-area and the only thing left to do is count the new reference.
 * This table is PID-INDEXED (see vfs_cdir's header for why), so the copy has to
 * be written out, and the copy needs to be told which two slots.
 *
 * AN OUT-OF-RANGE PARENT IS NOT AN ERROR: it is `init'.  Boot launches pid 1
 * directly rather than through spawn, and reaches Task_InheritCwd with
 * `_curTask' still 0 (main.s:1067).  A null entry means the root, so leaving
 * the child null IS Reno's `u.u_cdir = rootdir' at init_main.c:183 -- the same
 * default vfs_cdir already documents, arrived at by the same route.
 *
 * THE CHILD'S SLOT MAY NOT BE EMPTY, which Reno's u-area cannot be.  A pid is
 * recycled, and while `vfs_cdirexit' clears the slot on the way out, a spawn
 * that ROLLS BACK reaches Task_Free without ever running _Sys_Exit
 * (task.s:1111 records that asymmetry for the fd table).  So a stale reference
 * can outlive its owner, and dropping it here is safe for the one reason that
 * matters: the pid was just allocated to this child, so nothing else can be
 * holding the slot.  Leaving it would pin an inode for the life of the boot.
 */
void
vfs_cdirfork(ppid, cpid)
int ppid;
int cpid;
{
    struct vnode *vp;

    if (cpid < 1 || cpid > VFS_NPROC)
        return;

    vp = cdir_vp[cpid - 1];
    if (vp != (struct vnode *)0)
        vrele(vp);                      /* a slot its owner never gave back */

    if (ppid < 1 || ppid > VFS_NPROC) {
        cdir_vp[cpid - 1] = (struct vnode *)0;  /* init: the root, by default */
        return;
    }

    vp = cdir_vp[ppid - 1];
    cdir_vp[cpid - 1] = vp;
    if (vp != (struct vnode *)0)
        vref(vp);                       /* Reno's VREF(u.u_cdir) */
}


/* vfs_cdirexit -- give the working directory back.  Reno kern_exit.c:139:
 *
 *     VOP_LOCK(u.u_cdir);
 *     vput(u.u_cdir);
 *
 * THE LOCK IS UPSTREAM'S AND IS CARRIED RATHER THAN COLLAPSED.  `vput' is
 * VOP_UNLOCK followed by vrele, so LOCK-then-vput is a lock/unlock cycle around
 * a vrele and the net reference arithmetic is a bare vrele's.  What the cycle
 * buys is the serialisation: it waits out whoever else holds the vnode before
 * the reference that may be the last one is dropped, which is the same reason
 * `vput' exists as its own function rather than as two calls (vfs_subr.c:712).
 * Writing `vrele(vp)' here would be a divergence with no note, and this tree
 * has just spent a sweep on those.
 *
 * THE SLOT IS CLEARED BEFORE THE RELEASE, not after: vrele may reach
 * VOP_INACTIVE and the vnode can be reclaimed under it, so a table still
 * naming it would be naming freed storage for as long as the call takes.
 *
 * CALLED FROM _Sys_Exit BESIDE _Sys_CloseAllFds, which is where upstream puts
 * it too -- kern_exit.c releases the open files a few lines above these two.
 */
void
vfs_cdirexit(pid)
int pid;
{
    struct vnode *vp;

    if (pid < 1 || pid > VFS_NPROC)
        return;
    vp = cdir_vp[pid - 1];
    if (vp == (struct vnode *)0)
        return;
    cdir_vp[pid - 1] = (struct vnode *)0;
    VOP_LOCK(vp);
    vput(vp);
}


/* vfs_cdirinit -- zero the table.  THE FAR BANK'S AND THE MODULE'S STATICS ARE
 * NOT ZEROED AT LOAD (memmap.s's discipline: an owner zero-fills its own
 * region at Init time), and a garbage vnode pointer here would be vrele'd on
 * the first chdir.  apple/fgx#120's lesson, and dev_mount.c's at :847.
 */
void
vfs_cdirinit()
{
    register int i;

    for (i = 0; i < VFS_NPROC; i++)
        cdir_vp[i] = (struct vnode *)0;
}

/* vfs_fchdir -- Reno's fchdir(2) body.  kern/vfs_syscalls.c:433.  UFS 2.7.
 *
 * IT LIVES HERE AND NOT IN THE FAR BANK because `cdir_vp' is this module's
 * data and `vref'/`vrele' are its functions -- the same reason vfs_chdir
 * below is here.  The far bank owns the DESCRIPTOR half (root_fchdir) and
 * hands over the vnode it found, which is the split every other syscall in
 * this layer uses.
 *
 * NO namei, WHICH IS THE WHOLE POINT.  chdir(2) resolves a path; fchdir(2)
 * starts from a descriptor that is already open on a directory, so there is
 * nothing to walk and the vnode arrives ready.  libc's stub said what this
 * would cost -- "it needs the file table's vnode handed to vfs.mod's cwd
 * table, which is a KFAR slot and a seam entry of its own.  The far bank has
 * 86 bytes free, which is the whole reason this is a stub today" -- and that
 * figure is from a tree three campaigns ago; the far bank has over 9,000.
 *
 * VREF BEFORE VRELE, and the order is upstream's for a reason that is easy to
 * lose: `fchdir(fd)' where fd is ALREADY the cwd would, in the other order,
 * release the last reference and then take one on a vnode that had just been
 * recycled.  Reno writes `VREF(vp); vrele(ndp->ni_cdir); ndp->ni_cdir = vp;'
 * and this keeps that sequence.
 *
 * VOP_ACCESS ON THE DIRECTORY ITSELF, which is Reno's kern/vfs_syscalls.c:452:
 * `error = VOP_ACCESS(vp, VEXEC, ndp->ni_cred)', between the VDIR test and the
 * reference.  A descriptor open on a directory is not permission to stand in
 * it -- open(2) asked VREAD and this asks VEXEC, which are different bits, and
 * nothing else on this path asks: fchdir does no walk, so the per-component
 * VEXEC in ufs_lookup never runs.  Upstream brackets the call with
 * VOP_LOCK/VOP_UNLOCK; this port takes no locks, as everywhere else in it.
 */
int
vfs_fchdir(pid, vp)
int           pid;
struct vnode *vp;
{
    int error;

    if (pid < 1 || pid > VFS_NPROC)
        return (EINVAL);
    if (vp == (struct vnode *)0)
        return (EBADF);
    if (vp->v_type != VDIR)
        return (ENOTDIR);

    error = VOP_ACCESS(vp, VEXEC, (char *)0);
    if (error)
        return (error);

    vref(vp);
    if (cdir_vp[pid - 1] != (struct vnode *)0)
        vrele(cdir_vp[pid - 1]);
    cdir_vp[pid - 1] = vp;
    return (0);
}


/* vfs_chdir -- Reno's chdir(2) body, which is chdirec plus two lines.
 *
 * 4.3BSD-Reno kern/vfs_syscalls.c:466-484.  Upstream is
 *
 *     ndp->ni_nameiop = LOOKUP | FOLLOW | LOCKLEAF;
 *     if (error = chdirec(ndp)) return (error);
 *     vrele(ndp->ni_cdir);  ndp->ni_cdir = ndp->ni_vp;
 *
 * and chdirec (:516) is namei, a VDIR test, VOP_ACCESS (:528), VOP_UNLOCK and
 * a vrele on failure.  All five are here, in that order.  The cred argument is
 * carried at Reno's position and passed null, which is this tree's rule
 * everywhere else.
 *
 * THE VEXEC IS ON THE LEAF AND THE WALK DOES NOT COVER IT.  ufs_lookup asks
 * VEXEC of each directory it SEARCHES, so a chdir to /a/b has been asked for
 * / and for /a and never for /a/b -- the one the caller ends up standing in.
 * Without this line an account could stand in a directory it had no right to
 * search; dirperm's `cd' arm is what says it cannot.
 *
 * LOCKLEAF AND THEN UNLOCK, which is upstream's shape and not redundant: the
 * type test has to read v_type on a vnode nothing else can be changing, and
 * the REFERENCE is what outlives the call.
 */
int
vfs_chdir(pid, path)
int   pid;
char *path;
{
    struct nameidata *ndp;
    struct vnode     *vp;
    int               error;

    if (pid < 1 || pid > VFS_NPROC)
        return (EINVAL);
    if (rootdir == (struct vnode *)0)
        return (ENXIO);

    ndp = ndslot(pid, 0);
    if (ndp == (struct nameidata *)0)
        return (EINVAL);

    ndp->ni_dirp    = path;
    ndp->ni_segflg  = UIO_SYSSPACE;
    /* LOCKLEAF, WHICH IS UPSTREAM'S SHAPE AND WORKS HERE.  An earlier version
     * of this line was a plain LOOKUP, with a comment claiming lookup()
     * unlocks on the way out regardless so LOCKLEAF would double-unlock.  That
     * was WRONG and this file says so eight hundred lines down: "ni_vp is
     * returned referenced, and locked only if LOCKLEAF", and the unlock is
     * `if ((ndp->ni_nameiop & LOCKLEAF) == 0) VOP_UNLOCK(dp)'.  With the flag
     * set the leaf comes back LOCKED, exactly as Reno's does.
     *
     * IT WAS DROPPED CHASING THE WRONG BUG.  The boot died between `boot:
     * loading shell' and /etc/rc, LOCKLEAF was the first suspect, and removing
     * it did not help -- the cause was `ndslot' undeclared in this file, an
     * untyped-extern truncation (apple/fgx#293).  Restored once the real
     * defect was found, because the type test below genuinely wants v_type
     * read on a vnode nothing else can be changing, which is what upstream's
     * chdirec asks for and why.
     *
     * AND `FOLLOW', WHICH THE HEADER ABOVE HAS QUOTED FROM RENO SINCE THE DAY
     * THIS WAS WRITTEN while the line itself did not set it.  It governs the
     * LAST component only -- lookup() follows an interior symlink whatever the
     * caller asked (:831, upstream's second clause) -- so without it `cd' on a
     * symlink to a directory reached the LINK, and the VDIR test below then
     * answered ENOTDIR for a name that names a directory.  That was reachable
     * rather than theoretical: ufs_symlink and ufs_readlink are REAL entries
     * in the ufs vnodeops table (ufs_vnops.c:1961, :1963) and 2.11BSD roots
     * ship symlinks (/sys is one).  It is the difference between chdir and a
     * chdir that behaves like lstat. */
    ndp->ni_nameiop = LOOKUP | FOLLOW | LOCKLEAF;
    ndp->ni_cdir    = vfs_cdir(pid);
    ndp->ni_rdir    = (struct vnode *)0;
    ndp->ni_vp      = (struct vnode *)0;
    ndp->ni_dvp     = (struct vnode *)0;

    error = namei(ndp);
    if (error)
        return (error);
    /* UNLOCK AND KEEP THE REFERENCE, which is chdirec's own last two lines:
     * the LOCK was for the type test, the REFERENCE is what the cwd table
     * holds afterwards. */
    vp = ndp->ni_vp;
    if (vp->v_type != VDIR) {
        VOP_UNLOCK(vp);
        vrele(vp);
        return (ENOTDIR);
    }
    /* UNDER THE LOCK, AND THE UNLOCK IS UNCONDITIONAL, which is chdirec's
     * shape: the mode is read on a vnode nothing else can be changing, and the
     * reference is given back only after the lock is. */
    error = VOP_ACCESS(vp, VEXEC, (char *)0);
    VOP_UNLOCK(vp);
    if (error) {
        vrele(vp);
        return (error);
    }

    /* THE OLD ONE IS RELEASED AND THE NEW ONE IS ALREADY HELD -- namei handed
     * back the reference the walk took, which is the one this table keeps.
     * Releasing before storing is upstream's order and matters: they can be
     * the SAME vnode (`cd .'), and dropping the last reference after storing
     * would leave the table naming a freed one. */
    if (cdir_vp[pid - 1] != (struct vnode *)0)
        vrele(cdir_vp[pid - 1]);
    cdir_vp[pid - 1] = vp;
    return (0);
}


/* ---------------------------------------------------------------------------
 * namei -- resolve ndp->ni_dirp to a vnode.
 *
 * IN:   ni_dirp     the pathname
 *       ni_segflg   UIO_SYSSPACE only, for now (see above)
 *       ni_nameiop  op | flags
 *       ni_cdir     directory a relative path starts from
 *       ni_rdir     this walk's root, or 0 for the system root
 *       ni_pnbuf    a caller-owned buffer of MAXPATHLEN bytes
 *
 * OUT:  0 and ni_vp (referenced; locked if LOCKLEAF), plus ni_dvp when
 *       LOCKPARENT or WANTPARENT was asked for.  Otherwise an errno, and
 *       ni_vp is 0.
 */
/* nexpand -- replace the symlink at ni_vp with what it points at.
 *
 * 4.3BSD-Reno kern/vfs_lookup.c:287-321, the block after "Check for symbolic
 * link".  The path so far has been walked; ni_vp is the link; ni_next is what
 * is left of the pathname behind it.  On return ni_ptr names a path that
 * starts with the link's TARGET and continues with that remainder, and the
 * caller restarts the walk on it.
 *
 * TWO BUFFERS ARE LIVE AT ONCE and that is the whole reason a slot owns two.
 * The target is read into the OTHER buffer, the un-walked remainder is copied
 * in BEHIND it out of the current one, and only then do the two swap.  Doing
 * it in one buffer would overwrite the remainder with the target before it had
 * been copied.  Reno mallocs the second per call and frees the first;
 * fsparam.h records why this tree pays MAXPATHLEN per slot instead.
 *
 * THE DEGENERATE CASE IS THE ONE THAT FITS IN PLACE: when the link is the LAST
 * component (ni_pathlen 1 -- just the NUL) there is no remainder, so the
 * target can go straight into the current buffer and no swap happens.  That is
 * upstream's `ndp->ni_pnbuf[linklen] = '\0'`, and it is the common case:
 * every `cat /a/symlink` takes it.
 */
static int
nexpand(ndp)
struct nameidata *ndp;
{
    struct uio    auio;
    struct iovec  aiov;
    char         *cp;
    char         *src;
    int           linklen;
    int           error;
    int           i;

    /* `ln -s a b; ln -s b a` is otherwise a kernel that does not come back. */
    ndp->ni_loopcnt++;
    if (ndp->ni_loopcnt > MAXSYMLINKS)
        return (ELOOP);

    cp = (ndp->ni_pathlen > 1) ? ndp->ni_pnalt : ndp->ni_pnbuf;

    aiov.iov_base  = cp;
    aiov.iov_len   = MAXPATHLEN;
    auio.uio_iov   = &aiov;
    auio.uio_iovcnt = 1;
    auio.uio_offset = (off_t)0;
    auio.uio_resid = (unsigned short)MAXPATHLEN;
    auio.uio_segflg = UIO_SYSSPACE;
    auio.uio_rw    = UIO_READ;
    error = VOP_READLINK(ndp->ni_vp, &auio, (char *)0);
    if (error)
        return (error);

    linklen = MAXPATHLEN - (int)auio.uio_resid;
    /* A LINK OF ZERO BYTES NAMES NOTHING.  Upstream does not test it because
     * its MAXPATHLEN is 1024 and the arithmetic below cannot reach zero
     * usefully either way; here it would restart the walk on an empty path,
     * which the caller resolves as "the directory itself" -- a symlink that
     * silently means ".". */
    if (linklen == 0)
        return (ENOENT);
    if (linklen + (int)ndp->ni_pathlen >= MAXPATHLEN)
        return (ENAMETOOLONG);

    if (ndp->ni_pathlen > 1) {
        /* The remainder INCLUDES its NUL, which is what ni_pathlen counts. */
        src = ndp->ni_next;
        for (i = 0; i < (int)ndp->ni_pathlen; i++)
            cp[linklen + i] = src[i];
        /* ...and now the two change places. */
        ndp->ni_pnalt = ndp->ni_pnbuf;
        ndp->ni_pnbuf = cp;
    } else {
        cp[linklen] = '\0';
    }

    ndp->ni_ptr = cp;
    ndp->ni_pathlen = ndp->ni_pathlen + (unsigned short)linklen;
    return (0);
}


int namei(ndp)
    register struct nameidata *ndp;
{
    register char *cp;
    register char *dst;
    register int n;
    register int error;
    struct vnode *dp;

    ndp->ni_vp = (struct vnode *)0;
    ndp->ni_dvp = (struct vnode *)0;
    ndp->ni_loopcnt = 0;

    if (ndp->ni_pnbuf == (char *)0)
        return (EINVAL);
    /* A user-space pathname needs copyinstr, which needs a syscall layer.
     * Refusing is the only safe answer -- see the note above. */
    if (ndp->ni_segflg != UIO_SYSSPACE)
        return (EINVAL);

    /* Copy the path into the slot's buffer and measure it as we go.  Reno uses
     * copystr for exactly this, because the walk MUTATES the buffer's
     * neighbourhood -- ni_ptr and ni_next index into it.
     *
     * AN EARLIER VERSION OF THIS COMMENT ADDED "and a symlink will one day
     * rewrite it in place".  THAT IS NOT WHAT RENO DOES, and it matters for
     * sizing rather than style.  vfs_lookup.c:287-321: when a symlink is hit
     * with path still remaining (ni_pathlen > 1), Reno MALLOCS A SECOND
     * MAXPATHLEN BUFFER, reads the link into it, copies the un-walked
     * remainder out of the OLD buffer behind it, and only then frees the old
     * one and swaps.  Two buffers are live at once.  It rewrites in place only
     * in the degenerate case where the symlink is the last component
     * (ni_pathlen <= 1), which is the one-line `ni_pnbuf[linklen] = '\0'`.
     *
     * So when symlinks land (see the SYMLINKS note at the head of this file --
     * nothing can produce a VLNK vnode yet), one buffer per slot is NOT
     * enough.  It will need a second scratch buffer, or a kmalloc for the
     * transient, or an in-place algorithm Reno does not use.  Recorded here
     * and in fsparam.h so that lands as a decision rather than a surprise.
     *
     * Reno also `panic("namei: unexpected symlink")` when HASBUF is set, so
     * HASBUF and symlink-following are mutually exclusive upstream. */
    cp = ndp->ni_dirp;
    dst = ndp->ni_pnbuf;
    n = 0;
    while (n < MAXPATHLEN) {
        *dst = *cp;
        if (*cp == '\0')
            break;
        dst++;
        cp++;
        n++;
    }
    if (n >= MAXPATHLEN)
        return (ENAMETOOLONG);
    /* ni_pathlen COUNTS THE NUL, as Reno's copystr reports it: the walk
     * decrements it per component and the terminator has to be in the total or
     * the last component comes up one short. */
    ndp->ni_pathlen = n + 1;

    /* THE EMPTY PATH IS NOT SCREENED, AND NEITHER UPSTREAM SCREENS IT.  A
     * guard stood here answering ENOENT, on the reasoning its comment gave:
     * "the empty path is not the root".  The premise is true and does not
     * reach the conclusion -- without the guard "" does not become the root,
     * it becomes ni_cdir, because the leading-'/' arm below is what selects a
     * root and "" does not enter it.
     *
     * BOTH VENDORED TREES SAY THE SAME THING IN THE SAME WORDS.  4.3BSD-Reno
     * kern/vfs_lookup.c:198 and 2.11BSD usr/sys/sys/ufs_namei.c:226 both open
     * the arm with "Check for degenerate name (e.g. / or \"\") which is a way
     * of talking about a directory, e.g. like \"/.\" or \".\"", and neither
     * namei rejects the name before reaching it.  This tree PORTED that arm --
     * it is the `*ndp->ni_ptr == '\0'' block in the loop below, EISDIR case
     * and all -- and then put a guard in front that made half of it
     * unreachable: only a path emptied by STRIPPING SLASHES could arrive, so
     * the `or ""' in its own comment described code that could not run.
     *
     * THE USERLAND DEPENDS ON THE UPSTREAM ANSWER.  2.11BSD's sh globs by
     * stat-ing the directory part of the pattern, and for a pattern with no
     * '/' in it that part is the EMPTY STRING (usr/bin/sh/expand.c:61,
     * `s=nullstr'), followed by `stat(s)' and `opendir(s)'.  With ENOENT both
     * fail, nothing is scanned, and sh leaves the word literal -- which is why
     * `echo *' printed `*' rather than erroring (apple/fgx#298).
     *
     * A NULL ni_cdir IS STILL ENOENT, from the `dp == 0' test below, which is
     * the answer a process with no directory should get and the only thing the
     * guard was really covering. */
    ndp->ni_ptr = ndp->ni_pnbuf;

    /* WHERE THE WALK STARTS.  A leading '/' means this walk's root -- ni_rdir
     * if the caller set one (chroot), else the system root.  Anything else is
     * relative to ni_cdir.
     *
     * THIS IS DECIDED AGAIN AFTER EVERY SYMLINK, which is why it sits where it
     * does: an absolute link target restarts at the root, a relative one
     * restarts in the directory the link was found in.  Reno labels the same
     * point `start:` and jumps back to it.
     *
     * THE LOOP OWNS dp FROM HERE, exactly one reference, and lookup() consumes
     * it.  After a symlink the parent BECOMES dp and arrives already owned --
     * which is why the absolute-target arm below releases it before taking the
     * root instead.  Getting this wrong leaks a vnode per symlink, invisible
     * until the pool runs dry in an unrelated program hours later. */
    if (*ndp->ni_ptr == '/') {
        while (*ndp->ni_ptr == '/') {
            ndp->ni_ptr++;
            ndp->ni_pathlen--;
        }
        dp = ndp->ni_rdir ? ndp->ni_rdir : rootdir;
    } else {
        dp = ndp->ni_cdir;
    }
    if (dp == (struct vnode *)0)
        return (ENOENT);
    vref(dp);

    for (;;) {
        /* "/" ALONE RESOLVES TO THE ROOT and never enters the walk: there is
         * no component to look up, and a walk given an empty one would ask a
         * filesystem for a zero-length name.  A symlink whose target is "/"
         * arrives here too, on the round after it.
         *
         * BUT ONLY FOR A PLAIN LOOKUP.  A degenerate name is "a way of talking
         * about a directory" (Reno's words), so create("/"), unlink("/") and
         * rename("/") are EISDIR, and so is any caller wanting the PARENT --
         * the root has no parent to hand back. */
        if (*ndp->ni_ptr == '\0') {
            if ((ndp->ni_nameiop & OPMASK) != LOOKUP ||
                (ndp->ni_nameiop & (LOCKPARENT | WANTPARENT))) {
                vrele(dp);
                return (EISDIR);
            }
            if (ndp->ni_nameiop & LOCKLEAF)
                VOP_LOCK(dp);
            ndp->ni_vp = dp;        /* the loop's reference goes to the caller */
            return (0);
        }

        VOP_LOCK(dp);
        error = lookup(ndp, dp);    /* consumes dp, however it ends */
        if (error)
            return (error);

        /* NOT A SYMLINK THIS WALK MUST FOLLOW: the answer is what was found.
         * The condition is lookup()'s, re-read rather than carried in a flag
         * -- and the `*ni_next == '/'` half is why a link in the middle of a
         * path is followed whether or not the caller asked. */
        if (ndp->ni_vp == (struct vnode *)0)
            return (0);             /* a CREATE or RENAME miss */
        if (ndp->ni_vp->v_type != VLNK)
            return (0);
        if ((ndp->ni_nameiop & FOLLOW) == 0 && *ndp->ni_next != '/')
            return (0);

        error = nexpand(ndp);
        if (error) {
            /* Both vnodes are still held: the link and its directory. */
            vput(ndp->ni_vp);
            vrele(ndp->ni_dvp);
            ndp->ni_vp = (struct vnode *)0;
            ndp->ni_dvp = (struct vnode *)0;
            return (error);
        }

        /* The link is done with; its DIRECTORY is where a relative target
         * resolves from, and it is already owned. */
        vput(ndp->ni_vp);
        ndp->ni_vp = (struct vnode *)0;
        dp = ndp->ni_dvp;
        ndp->ni_dvp = (struct vnode *)0;

        if (*ndp->ni_ptr == '/') {
            vrele(dp);              /* an ABSOLUTE target ignores it */
            while (*ndp->ni_ptr == '/') {
                ndp->ni_ptr++;
                ndp->ni_pathlen--;
            }
            dp = ndp->ni_rdir ? ndp->ni_rdir : rootdir;
            if (dp == (struct vnode *)0)
                return (ENOENT);
            vref(dp);
        }
    }
}

/* ---------------------------------------------------------------------------
 * lookup -- walk the components of ni_ptr, starting at dp.
 *
 * dp ARRIVES REFERENCED AND LOCKED and this routine owns it from that moment:
 * every exit, success or failure, disposes of it.  Getting that wrong leaks a
 * vnode per failed path, which is invisible until the pool runs dry hours
 * later in an unrelated program.
 */
int lookup(ndp, dp)
    register struct nameidata *ndp;
    register struct vnode *dp;
{
    register char *cp;
    register char *dst;
    register int error;
    register int n;
    int flag;
    int wantparent;
    int lockparent;
    int docache;
    int lastcomponent;

    flag = ndp->ni_nameiop & OPMASK;
    lockparent = ndp->ni_nameiop & LOCKPARENT;
    wantparent = ndp->ni_nameiop & (LOCKPARENT | WANTPARENT);
    /* NOCACHE is expressed as "do not leave this name in the cache", so the
     * sense is inverted on the way in.  DELETE never caches: the whole point
     * of the operation is that the name is about to stop being true. */
    docache = (ndp->ni_nameiop & NOCACHE) ? 0 : 1;
    /* AND FOR wantparent TOO, which was dropped.  Reno:
     * `if (flag == DELETE || wantparent) docache = 0;`.  A caller that asked
     * for the parent is about to change the directory -- create into it,
     * remove from it, rename through it -- so leaving the name it just
     * resolved in the cache is caching an answer that is about to stop being
     * true.  Latent while nothing consults the cache; wrong the day something
     * does. */
    if (flag == DELETE || wantparent)
        docache = 0;
    ndp->ni_dvp = (struct vnode *)0;

dirloop:
    /* --- carve out one component ------------------------------------------
     * ni_ptr is its first character and ni_next its terminator, which is
     * either a '/' or the NUL.  The buffer is NOT cut here: the component is a
     * (pointer, length) pair, because a filesystem must be able to see the
     * rest of the path -- and because writing a NUL into the buffer is what
     * makes a symlink restart impossible to get right later. */
    /* EACH BYTE IS WEIGHTED BY ITS POSITION, which is Reno's
     * `ndp->ni_hash += (unsigned char)*cp * i;` (kern/vfs_lookup.c:180) with
     * i the 1-BASED index -- upstream increments it in the d_name store on the
     * line above, so the first character is multiplied by one.
     *
     * THE WEIGHT IS THE WHOLE POINT.  A plain sum of the bytes gives every
     * anagram the same hash, so with NCHASH at 16 a directory of names built
     * from the same letters walks one bucket.  That is not a correctness bug
     * and no functional test can see it -- namei.h says why in the paragraph
     * on ncs_falsehits: a cache that is merely present answers correctly and
     * slowly.  It was invisible while nothing called cache_lookup. */
    ndp->ni_hash = 0;
    n = 0;
    for (cp = ndp->ni_ptr; *cp != '\0' && *cp != '/'; cp++) {
        n++;
        ndp->ni_hash += (unsigned long)(unsigned char)*cp * (unsigned long)n;
    }
    ndp->ni_namelen = cp - ndp->ni_ptr;
    if (ndp->ni_namelen > MAXNAMLEN) {
        error = ENAMETOOLONG;
        goto bad;
    }
    ndp->ni_next = cp;
    ndp->ni_pathlen -= ndp->ni_namelen;

    /* THE COMPONENT IS COPIED INTO ni_dent, AND THAT IS WHAT WIRES THE WRITE
     * PATH TO THE WALK.  ufs_dirscan fills d_ino and d_reclen on a HIT;
     * d_namlen and d_name are the CALLER's half, and ufs_direnter reads
     * DIRSIZ(d_namlen) bytes starting at &ni_dent when it writes the entry.
     * Until now nothing set them -- the UFS probe did it by hand, which is
     * how a probe tells you a layer is not connected yet.  Reno does it here,
     * in this loop, for this reason (kern/vfs_lookup.c, dirloop).
     *
     * Through a char pointer rather than ni_dent.d_name[i]: arrow-dot-subscript
     * is one of the member shapes fcc is missing (apple/fgx#171).  The
     * MAXNAMLEN refusal above is what bounds the copy. */
    dst = (char *)&ndp->ni_dent + DIRHDRSIZ;
    for (n = 0; n < ndp->ni_namelen; n++)
        dst[n] = ndp->ni_ptr[n];
    dst[ndp->ni_namelen] = '\0';
    ndp->ni_dent.d_namlen = (unsigned short)ndp->ni_namelen;

    /* ".." is flagged for THIS routine's benefit, not the filesystem's -- see
     * the header.  The filesystem still resolves the name. */
    ndp->ni_isdotdot = (ndp->ni_namelen == 2 &&
                        ndp->ni_ptr[0] == '.' && ndp->ni_ptr[1] == '.');

    /* TRAILING SLASHES DO NOT MAKE A COMPONENT.  "/a/b/" and "/a/b" name the
     * same thing, so the run of slashes is consumed here and what follows
     * decides whether this was the last component. */
    cp = ndp->ni_next;
    while (*cp == '/') {
        cp++;
        ndp->ni_pathlen--;
    }
    lastcomponent = (*cp == '\0');

    /* Only the last component may be left in the cache, and only if the
     * operation wants it there. */
    ndp->ni_makeentry = 1;
    if (lastcomponent && docache == 0)
        ndp->ni_makeentry = 0;

    /* --- ".." STOPS AT THE ROOT -------------------------------------------
     * "/.." is "/", and so is "/../../..".  Reno checks this before asking the
     * filesystem, because the filesystem's own ".." entry points at the parent
     * on ITS volume and would happily walk out of a chroot.
     *
     * WHERE MOUNT-CROSSING GOES (1.8): if dp is a mount ROOT and we are going
     * up, Reno replaces dp with mnt_vnodecovered and retries -- the parent of
     * a mount point belongs to the filesystem that was covered, not to this
     * one.  There are no mounts yet, so there is nothing to cross. */
    if (ndp->ni_isdotdot) {
        for (;;) {
            if (dp == (ndp->ni_rdir ? ndp->ni_rdir : rootdir)) {
                /* BOTH, exactly as Reno does: the answer is this directory,
                 * and it is also its own parent.  The extra reference is what
                 * the disposal below releases, so the caller's dp is not
                 * lost.
                 *
                 * RENO WRITES TWO COMPARISONS -- `dp == ndp->ni_rdir || dp ==
                 * rootdir' -- and this writes one, which is the same test only
                 * while ni_rdir is always zero.  It is: chroot(2) does not
                 * exist here and vfs_openat says so where it clears the field.
                 * The day it does, upstream's form stops at the REAL root as
                 * well as at the chroot root, and this one would walk past it;
                 * the two comparisons come back with chroot and not before,
                 * because a backstop nothing can reach is a backstop nobody
                 * maintains. */
                ndp->ni_dvp = dp;
                ndp->ni_vp = dp;
                vref(dp);
                goto nextname;
            }
            /* NOT A MOUNT ROOT, so its `..' is the filesystem's own and the
             * loop is done.  NOCROSSMOUNT stops the ascent for the same
             * caller that stops the descent. */
            if ((dp->v_flag & VROOT) == 0 ||
                (ndp->ni_nameiop & NOCROSSMOUNT) != 0)
                break;
            /* A MOUNT ROOT WITH NO COVER, WHICH RENO CANNOT HAVE AND THIS CAN.
             *
             * Upstream's loop dereferences `mnt_vnodecovered' the moment VROOT
             * is set, and it is safe there because the only mount without a
             * cover is the ROOT filesystem's -- caught one test earlier by
             * `dp == rootdir'.  FGX breaks that invariant twice over: `rootdir'
             * is still zero, so the test above never fires, and the /dev mount
             * is carved by dev_mount.c and covers NO vnode at all -- it is
             * reached by a ProDOS-path syscall hook, not by a directory.  Since
             * 1.8b-3a set VROOT in iget, `dev_root' is exactly that shape: a
             * mount root whose cover is null.
             *
             * So a faithful port dies on `..' anywhere at /dev's root, and
             * this guard is the divergence that keeps it standing.  MEASURED,
             * because "would crash" is a prediction and this is not: remove
             * the guard and the boot reports `vref: zero usecount' and PANICs
             * before /dev is even mounted.  vref's own assertion is what
             * catches it -- dp becomes null, and reading a usecount at address
             * zero finds zero -- so the damage stops at a named halt rather
             * than a wild write, which is the only good thing about it.
             *
             * IT GOES WHEN ROOT BECOMES UFS and rootdir is real, at which point
             * upstream's own `dp == rootdir' test catches the case again and
             * this guard is dead code that should be deleted with it. */
            if (dp->v_mount == (struct mount *)0 ||
                dp->v_mount->mnt_vnodecovered == (struct vnode *)0)
                break;
            /* UP THROUGH THE COVER.  Reno parks the old dp in a `tdp' local;
             * this parks the NEW one in ni_vp instead and releases through dp
             * before overwriting it, which is the same two moves in the other
             * order and costs no frame -- lookup's stack is the scarce thing
             * (the ratchet caught 1.8b-3a at eight bytes).  ni_vp is free to
             * borrow: every exit from this arm rewrites it, here or in the
             * VOP_LOOKUP below or in `bad'. */
            ndp->ni_vp = dp->v_mount->mnt_vnodecovered;
            vput(dp);
            dp = ndp->ni_vp;
            vref(dp);
            VOP_LOCK(dp);
        }
    }

    /* --- ask the filesystem -----------------------------------------------
     * THE CONTRACT, and it is the filesystem's half as much as ours
     * (vendor/4.3BSD-Reno/kern/vfs_lookup.c:66):
     *
     *   in    dp is the directory, LOCKED.
     *   out   ni_dvp is the directory -- THE FILESYSTEM SETS IT, first thing
     *         and whether or not it then fails (ufs_lookup.c:95) -- unlocked
     *         unless LOCKPARENT and this is the last component.
     *         ni_vp is what was found, and it is LOCKED.
     *
     * From here on `dp` becomes the FOUND vnode and ni_dvp is the parent.
     * That swap is why the disposal below reads the way it does. */
    error = VOP_LOOKUP(dp, ndp);
    if (error) {
        /* CREATE and RENAME on the LAST component are allowed to miss: that is
         * how a file gets made.  The caller gets the parent -- which the
         * filesystem has already put in ni_dvp, and has already unlocked
         * unless LOCKPARENT -- and a null ni_vp meaning "the name is free".
         *
         * The parent's lock is HELD in that case and released in every other,
         * which is the asymmetry callers most often get wrong. */
        if (error == ENOENT && lastcomponent &&
            (flag == CREATE || flag == RENAME)) {
            /* NOT ON A READ-ONLY MOUNT, and this gate was MISSING from this
             * port.  Reno checks the PARENT's mount here, between deciding
             * the miss is legal and reporting the name free (kern/
             * vfs_lookup.c:260, `if (ndp->ni_dvp->v_mount->mnt_flag & rdonly)
             * { error = EROFS; goto bad; }').  Its `rdonly' is
             * MNT_RDONLY | MNT_EXRDONLY; this tree has no NFS export, so the
             * bit is MNT_RDONLY alone.
             *
             * WITHOUT IT MNT_RDONLY MEANT NOTHING ON THE CREATE PATH.  Only
             * vn_open's non-FCREAT arm consulted it, through vn_writechk, so
             * a create SUCCEEDED on a read-only mount while opening the same
             * file for writing afterwards returned EROFS -- which is how
             * apple/fgx#318's first fix passed its own test and still left
             * `vi' broken: elvis creates the temp file and then REOPENS it. */
            if (ndp->ni_dvp->v_mount->mnt_flag & MNT_RDONLY) {
                error = EROFS;
                goto bad;
            }
            if (wantparent) {
                ndp->ni_vp = (struct vnode *)0;
                return (0);
            }
        }
        goto bad;
    }

    /* The swap: dp is now what we found, locked; ni_dvp is the directory. */
    dp = ndp->ni_vp;

    /* --- A SYMLINK STOPS THE WALK HERE, for namei to expand ---------------
     *
     * THE CONDITION IS NOT "FOLLOW IS SET".  Reno's is
     * `(dp->v_type == VLNK) && ((ni_nameiop & FOLLOW) || *ni_next == '/')`,
     * and the second half is the one worth reading twice: a symlink in the
     * MIDDLE of a path is ALWAYS followed, whatever the caller asked, because
     * there is no other way to reach what comes after it.  FOLLOW governs the
     * LAST component only -- it is the difference between stat and lstat, not
     * a global switch.  Porting the loop shape without this line gives a
     * kernel where `cat /usr/link/file` fails and nobody can say why.
     *
     * The references are left exactly as they are on any other successful
     * component: ni_vp referenced and locked, ni_dvp the parent.  namei reads
     * the same condition again to decide what it is looking at -- one test in
     * two places rather than a flag in the nameidata to carry it. */
    if (dp->v_type == VLNK &&
        ((ndp->ni_nameiop & FOLLOW) != 0 || *ndp->ni_next == '/'))
        return (0);

    /* --- CROSS INTO A MOUNTED FILESYSTEM ----------------------------------
     * UFS 1.8b-3, and this is the line that makes a mount visible at all.
     * 4.3BSD-Reno kern/vfs_lookup.c:336-349, its `mntloop'.
     *
     * IT IS BEFORE `nextname' AND NOT INSIDE THE `lastcomponent == 0' ARM,
     * and the marker this replaces said otherwise -- "before treating dp as a
     * directory to continue into".  That reading crosses only for components
     * with something after them, and it is wrong in the case a user meets
     * first: `stat("/mnt")' and `cd /mnt' would answer with the COVERED
     * directory, reporting the mount point's old contents while the mounted
     * filesystem sat behind it.  Reno's loop updates `ni_vp', which is the
     * leaf, and that is the tell.
     *
     * A `while' AND NOT AN `if', which is also upstream's: a filesystem may be
     * mounted on the ROOT of another, and one step would stop in the middle of
     * that stack.
     *
     * `v_un' IS RENO'S `v_mountedhere', the union arm vnode.h describes -- so
     * the VDIR test is not defensive, it is what makes the word mean a mount
     * rather than a specinfo.
     *
     * WHAT IS NOT CARRIED: Reno waits out MNT_MLOCK here --
     * `while (mp->mnt_flag & MNT_MLOCK) { mp->mnt_flag |= MNT_MWAIT;
     * sleep(...); goto mntloop; }' -- because its mount(2) holds that lock
     * across VFS_MOUNT.  Nothing here takes it: vfs_syscalls.c says why at
     * vfs_mountat, and the day something does, this loop needs the wait and
     * the `goto' that re-tests after the sleep.
     *
     * VFS_ROOT IS DISPATCHED, AND ONLY A MODULE MAY.  It is an indirect call
     * through mp->mnt_op->vfs_root, whose cell carries a MODULE's bank; this
     * file is in vfs.mod and can, and the far kernel bank cannot (apple/fgx
     * #178).  That asymmetry is why `vfs_devroot' below exists at all -- and
     * this is NOT that call, because devroot hands the root back UNLOCKED and
     * the contract here is that ni_vp comes back LOCKED. */
    /* NEITHER `mp' NOR `tdp' IS A LOCAL, AND THAT IS MEASURED RATHER THAN
     * TIDY.  Reno keeps both -- `mp' for the condition and `tdp' to hold the
     * root while dp is released -- and two 4-byte pointers in THIS frame cost
     * eight bytes of the deepest per-task kernel stack, which is 512 total.
     * The gate's ratchet caught it at once: slice 7 went from 482 bytes used
     * (30 spare) to 490 (22), under the 24-byte floor.  `lookup' is the wrong
     * frame to spend stack in -- namei loops over it for every component of
     * every path, under whatever the caller already has on the stack.
     *
     * So the mount is read from `v_un' twice rather than cached, and the root
     * is written straight into `ni_vp' -- which is where it has to end up
     * anyway.  On the error arm `bad' clears ni_vp, so a half-written value
     * cannot escape. */
    while (dp->v_type == VDIR &&
           dp->v_un != (struct specinfo *)0 &&
           (ndp->ni_nameiop & NOCROSSMOUNT) == 0) {
        error = VFS_ROOT((struct mount *)dp->v_un, &ndp->ni_vp);
        if (error)
            goto bad2;
        /* THE COVERED DIRECTORY IS PUT, NOT MERELY RELEASED: this walk locked
         * it and the root that replaces it arrives locked from iget, so the
         * one lock the caller is owed is handed straight on. */
        vput(dp);
        dp = ndp->ni_vp;
    }

nextname:
    if (lastcomponent == 0) {
        /* What we found must be a directory.  Checking here rather than
         * letting the next VOP_LOOKUP fail gives ENOTDIR against the component
         * that is actually not a directory, which is what a user needs. */
        if (dp->v_type != VDIR) {
            error = ENOTDIR;
            goto bad2;
        }
        /* ADVANCE BY RELEASING THE PARENT, not by releasing dp: dp is already
         * the next directory and is already locked, so the walk carries it
         * straight into the next round.  A walk that held every directory it
         * passed through would pin the whole path. */
        vrele(ndp->ni_dvp);
        ndp->ni_ptr = cp;
        goto dirloop;
    }

    /* THE LOCK DISCIPLINE, and it is the part callers depend on:
     *   ni_vp is returned referenced, and locked only if LOCKLEAF.
     *   ni_dvp is returned only if the caller asked (WANTPARENT/LOCKPARENT);
     *          the FILESYSTEM already decided its lock.
     *   Anything not returned is released here, not by the caller. */
    /* AND THE OTHER HALF OF THE SAME MISSING GATE: an unlink or a rename of a
     * name that EXISTS, on a read-only mount (Reno kern/vfs_lookup.c:373).
     * Reno tests the LEAF's mount and, when the caller wanted the parent, the
     * PARENT's too -- they can differ across a mount point, which is the case
     * the second half is there for.  bad2 and not bad: VOP_LOOKUP succeeded,
     * so there are two vnodes to let go and this file keeps the labels
     * separate for exactly that reason. */
    if (flag == DELETE || flag == RENAME) {
        if ((dp->v_mount->mnt_flag & MNT_RDONLY) ||
            (wantparent && (ndp->ni_dvp->v_mount->mnt_flag & MNT_RDONLY))) {
            error = EROFS;
            goto bad2;
        }
    }

    if (wantparent == 0)
        vrele(ndp->ni_dvp);
    if ((ndp->ni_nameiop & LOCKLEAF) == 0)
        VOP_UNLOCK(dp);
    return (0);

bad2:
    /* An error AFTER a successful VOP_LOOKUP, so there are TWO vnodes to let
     * go: the parent in ni_dvp, and the leaf which is now dp.  Reno keeps
     * these labels separate for exactly that reason. */
    if (lockparent && lastcomponent)
        VOP_UNLOCK(ndp->ni_dvp);
    vrele(ndp->ni_dvp);

bad:
    /* Reached from a FAILED VOP_LOOKUP, where dp is still the directory and
     * ni_dvp names that same vnode -- so it is released once, here, and not
     * again through ni_dvp. */
    VOP_UNLOCK(dp);
    vrele(dp);
    ndp->ni_vp = (struct vnode *)0;
    ndp->ni_dvp = (struct vnode *)0;
    return (error);
}
