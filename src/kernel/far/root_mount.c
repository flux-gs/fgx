/* root_mount.c -- mount the boot volume as the root filesystem.
 * UFS campaign 2.4b.
 *
 * FGX-Origin: no upstream counterpart in the shape.  4.3BSD-Reno's equivalent
 * is kern/vfs_conf.c + the `mountroot' vector called from init_main.c, which
 * consults a compiled-in table of root filesystem types and a `rootdev' the
 * boot block passed in.  FGX has one candidate filesystem and one boot device,
 * so the table and the vector would both hold exactly one entry; what is
 * PORTED is the SEQUENCE -- bdevvp the root device, VFS_MOUNT it, take
 * VFS_ROOT and keep it as rootdir -- which is Reno's, function for function.
 * See docs/PROVENANCE.md.
 *
 *----------------------------------------------------------------------------
 * IT PROBES BY MOUNTING, AND THAT IS SAFE BECAUSE THE MOUNT VALIDATES.
 *
 * The boot volume is ProDOS on one image and 2.11BSD on the other, and the
 * kernel is not told which.  Rather than carry a second format sniffer beside
 * stage 1's, this attempts the mount and treats a refusal as the answer:
 * ufs_sbvalid (ufs_sb.c) bounds sb_volblocks, sb_isize, sb_nfree, sb_ninode
 * and sb_tfree against each other and against the device's real size, and a
 * ProDOS volume fails it at the first test -- its block 1 is the volume
 * directory, whose first word is the previous-block pointer, zero, and
 * sb_isize must exceed 2.
 *
 * A REFUSAL IS NOT AN ERROR HERE.  A machine whose boot volume is ProDOS is
 * every FGX before this one: rootdir stays null, namei answers ENOENT for an
 * absolute path exactly as its own header says it will, and the legacy
 * resolver keeps serving every path syscall.  Nothing is routed at namei yet,
 * so this increment can only add a capability, never take one away.  That is
 * deliberate: it is what lets the root swap land while the ProDOS image is
 * still the one the suite boots.
 *
 *----------------------------------------------------------------------------
 * WHY THE TWO HALVES ARE IN DIFFERENT BANKS.
 *
 * ufs_mountfs is here, in the far bank, with the rest of the UFS vfsops.
 * Taking the mount's root is VFS_ROOT, and the answer belongs in `rootdir',
 * which is vfs.mod's own storage -- this bank would have nowhere to put it.
 * So the mount happens here and vfs_setroot does the rest, over the same seam
 * vfs_devroot crosses.
 */

#include "../vfs/fsparam.h"
#include "../vfs/vnode.h"
#include "../vfs/ufs_fs.h"
#include "../vfs/mount.h"
#include "../vfs/ufsmount.h"

extern int  bdevvp();           /* vfs.mod, through vfs_import.s */
extern void vref();
extern void vrele();
extern int  ufs_mountfs();      /* ufs.mod, through ufs_import.s */
extern int  vfs_setroot();      /* vfs.mod: takes the root and keeps it */
extern int  vfs_openat();       /* this bank: open(2)'s second half */
extern void vfs_cdirinit();     /* vfs.mod: the cwd table, zeroed */
extern void kc_setfstime();     /* kc_sys.s: fs_time for the core's inittodr */
extern struct vnode *vfs_cdir();/* vfs.mod: the cwd vnode, Reno's u.u_cdir */
extern int  vfs_chdir();        /* vfs.mod: chdir(2)'s body */
extern int  vfs_unlink();       /* this bank: unlink(2)'s second half */
extern int  vfs_rename();   /* vfs.mod, VFSCORE_Rename -- 2026-09-05 */
extern int  vfs_symlink();  /* vfs.mod, VFSCORE_Symlink -- 2026-09-05 */
extern int  vfs_setattr();  /* vfs.mod, VFSCORE_Setattr -- chmod/chown, 2.6 */
extern int  vfs_link();     /* vfs.mod, VFSCORE_Link    -- link(2),    2.6 */
extern int  vfs_mkdir();        /* this bank: mkdir(2)'s */
extern int  vfs_rmdir();        /* this bank: rmdir(2)'s */
extern int  vfs_access();       /* this bank: access(2)'s.  UFS 2.6 */
extern void vfs_cdirfork();     /* vfs.mod: the cwd's fork half */
extern void vfs_cdirexit();     /* vfs.mod: the cwd's exit half */
extern void vfs_mountinit();    /* UFS 1.8b-2 -- the mount(2) table */
extern void vfs_mountlist_root();   /* this bank: the list head, Reno's */
extern int  vfs_statfs();       /* vfs.mod, VFSCORE_Statfs -- apple/fgx#329 */

/* THE BOOT DEVICE IS UNIT 0 AND IS NOT SCANNED FOR.  Blk_Init registers it as
 * _devTable[0] before any enumeration runs, which is the reason a 32 MB volume
 * that could not be enumerated as a second SmartPort unit still booted
 * (apple/fgx#80).  dev_mount SCANS because /dev is some other volume whose
 * unit nobody knows; the root is the one we came from. */
#define ROOT_UNIT       0

struct mount     root_mnt;
/* A STRUCT AND NOT A POINTER, which is `dev_ump's shape and was not this
 * one's.  ufs_mountfs takes `struct ufsmount *' and immediately does
 * `ufs_sbread(devvp, &ump->um_sb, 0)' -- so passing `&root_ump' when
 * root_ump was a POINTER handed it the address of the pointer, and the
 * superblock read landed at root_ump+10: over root_devvp, root_mounted,
 * root_status and everything after them in this bank.  On EVERY boot, before
 * any validation, whatever the volume turned out to be.
 *
 * K&R C CANNOT CATCH IT: `extern int ufs_mountfs();' is an untyped
 * declaration, so a `struct ufsmount **' passes silently where a
 * `struct ufsmount *' is wanted.  It surfaced only when root_mount was moved
 * AHEAD of dev_mount and the scribble started landing before dev_mount's
 * statics were read instead of after. */
struct ufsmount root_ump;
struct vnode    *root_devvp;
int              root_mounted;

/* WHY IT DID NOT MOUNT, kept because 0/1 cannot say.  The three failures are
 * three different places to look and the boot log cannot afford to print any
 * of them (the core bank has 43 bytes free), so the fact lives here where a
 * test reads it directly:
 *
 *    0  NEVER RAN.  It is the value the far-bank image carries at this
 *       address, and it has to mean that: this bank is not zeroed at load,
 *       every static here holds whatever the image happens to hold, and a
 *       success code of 0 would be indistinguishable from a call that did
 *       not happen.  It read as success once, for exactly that reason.
 *    1  mounted, and rootdir is this volume's root
 *   -1  bdevvp refused the boot device
 *   -2  ufs_mountfs refused the volume -- the ordinary ProDOS case
 *   -3  it mounted, and vfs_setroot could not take its root
 */
int              root_status;

/* root_mount -- 0 if the boot volume is now the root, negative otherwise.
 *
 *   -1  bdevvp refused the boot device
 *   -2  the boot volume is not a 2.11BSD filesystem (the ordinary ProDOS case)
 *   -3  it is, and its root vnode could not be taken
 */
int
root_mount()
{
    struct vnode *devvp;
    int           error;

    /* THE FAR BANK'S STATICS ARE NOT ZEROED AT LOAD.  memmap.s's discipline is
     * that an owner zero-fills its own region at Init time and there is no
     * global BSS clear, so every field read below is written first.  This is
     * dev_mount.c's lesson at :847 applied before it can cost a second boot:
     * there, a `mounted' guard read a garbage flag and refused to mount. */
    root_mounted = 0;
    root_devvp   = (struct vnode *)0;

    /* THE MOUNT(2) TABLE IS CLEARED HERE NOW, moved from dev_mount when the
     * two swapped places.  It still needs the once-per-boot zeroing that
     * depends on no byte of the storage it clears (vfs_syscalls.c's own
     * reason), and it still happens on the far bank's boot path before
     * anything can call mount(2) -- but dev_mount no longer runs on every
     * machine, and this does.  Neither of the two boot mounts goes through
     * that table: both carve a static, for the reason `dev_mnt' states. */
    /* THE MOUNT(2) TABLE IS CLEARED HERE NOW, moved from dev_mount when the
     * two swapped places.  It still needs the once-per-boot zeroing that
     * depends on no byte of the storage it clears (vfs_syscalls.c's own
     * reason), and it still happens on the far bank's boot path before
     * anything can call mount(2) -- but dev_mount no longer runs on every
     * machine, and this does.  Neither boot mount goes through that table:
     * both carve a static, for the reason `dev_mnt' states. */
    vfs_mountinit();

    /* AND THE CWD TABLE, for vfs_mountinit's reason one bank over: vfs.mod's
     * statics are not zeroed at load either, and a garbage vnode pointer there
     * would be vrele'd by the first chdir.  Zeroed here because this is the
     * boot path that runs on every machine, which is the same argument that
     * moved vfs_mountinit into this function. */
    vfs_cdirinit();

    /* AND THE MOUNT STRUCTURE, which is the same bug one level up and cost
     * apple/fgx#219: ufs_mountfs does `mp->mnt_flag |= MNT_RDONLY', an OR into
     * whatever the far-bank image happens to carry at this address, and a
     * surviving MNT_NODEV bit made spec_open refuse every node on a filesystem
     * nobody mounted nodev. */
    /* AND THE ROOT COMES UP READ-ONLY, which is Reno's own line --
     * `mp->mnt_flag = MNT_RDONLY' in ufs_mountroot (ufs/ufs_vfsops.c:87) --
     * and the reason BSD's boot can fsck the root at all: a check that runs
     * against a filesystem something else is writing reports what it saw
     * halfway through, and `fsck -p' would then "repair" a healthy volume.
     *
     * /etc/rc TAKES IT BACK with `mount -u -w /' once the check has passed,
     * which is why this could not land before MNT_UPDATE: a read-only root
     * with no way to remount it is an unwritable machine.
     *
     * IT IS ALSO WHAT KEEPS THE CLEAN FLAG READABLE.  ufs_mountfs clears
     * MNT_CLEAN on the platter when it mounts a volume writable; a read-only
     * mount writes nothing, so the flag survives for fsck to see and skip on
     * (2.11BSD update #456).  The remount then dirties it, and the first
     * superblock write carries that. */
    root_mnt.mnt_flag   = MNT_RDONLY;
    root_mnt.mnt_exroot = 0;
    root_mnt.mnt_mounth = (struct vnode *)0;

    if (bdevvp(ROOT_UNIT, &devvp) != 0) {
        root_status = -1;
        return (-1);
    }
    /* The mount holds a reference for as long as it is mounted. */
    vref(devvp);
    error = ufs_mountfs(devvp, &root_mnt, &root_ump);
    if (error) {
        vrele(devvp);
        root_status = -2;       /* not 2.11BSD: the ProDOS root stands */
        return (-1);
    }
    root_devvp = devvp;
    kc_setfstime(root_ump.um_sb.sb_time);   /* inittodr's base: 2.11BSD
                                             * init_main.c:197 */

    error = vfs_setroot(&root_mnt);
    if (error) {
        root_status = -3;
        return (-2);
    }
    /* AND THE MOUNT POINT IS THIS CALLER'S TO SET.  ufs_mountfs fills
     * f_mntfromname from the device it mounted and deliberately leaves this
     * one empty, because it serves three callers and only this one mounts on
     * the root.  Reno's ufs_mountroot writes the same '/' (ufs_vfsops.c:107,
     * via fs_fsmnt) for the same reason. */
    root_mnt.mnt_stat.f_mntonname[0] = '/';
    root_mnt.mnt_stat.f_mntonname[1] = 0;

    /* AND IT BECOMES THE MOUNT LIST.  Reno's ufs_mountroot does this
     * (ufs/ufs_vfsops.c:101-103) and every list walk in vfs_syscalls.c starts
     * from the head it sets; getfsstat(2) is the first walker FGX has.  AFTER
     * vfs_setroot, deliberately: a root that mounted but was not taken is
     * root_status -3, and a list head pointing at a mount nothing else
     * believes in would have df(1) reporting a filesystem the namespace
     * cannot reach. */
    vfs_mountlist_root(&root_mnt);

    root_mounted = 1;
    root_status  = 1;
    return (0);
}


/* root_open -- open an ABSOLUTE path against the mounted root, into a
 * descriptor the core already holds.  UFS campaign 2.4.
 *
 * dev_open's sibling, and the two differences are the ones that matter.
 *
 * `name' IS ABSOLUTE here -- "/etc/init", not "etc/init" -- where dev_open's is
 * relative because the core strips a prefix it had to parse anyway.  There is
 * no prefix to strip for the root, and vfs_openat's header says an absolute
 * path behaves the same whichever way `dvp' is passed.
 *
 * AND `dvp' IS ZERO RATHER THAN A VNODE THIS FILE HOLDS, which is not a
 * shortcut: zero is namei's own convention for "start at the system root"
 * (vfs_openat's header, and vfs_lookup.c:261 falling back to `rootdir').
 * root_mount handed the root to vfs_setroot, which put it in vfs.mod's
 * `rootdir'; reading it back across the seam to pass it in again would be a
 * SECOND AUTHORITY for the same fact, which apple/fgx#114 records as worse
 * than one honestly absent.
 *
 * ENXIO FOR AN UNMOUNTED ROOT, for dev_open's reason exactly: the core's hook
 * FALLS THROUGH on any error rather than failing the open, so a machine whose
 * boot volume is ProDOS is a machine whose every path still reaches the legacy
 * resolver.  This errno is a routing answer, not a user-visible one.
 *
 * root_status AND NOT root_mounted, because they are not the same claim:
 * root_mounted says ufs_mountfs succeeded, root_status == 1 says vfs_setroot
 * took the root as well.  A walk needs the second.
 *
 * `cmode' USED TO BE A HARDCODED ZERO HERE, AND THAT IS WHY EVERY FILE THIS
 * SYSTEM CREATED HAD MODE 0.  vn_open passes it to vn_mknode on the not-found
 * arm, vn_mknode puts it in va_mode, and ufs_makeinode writes it into the
 * inode -- so the whole chain was intact and carrying a zero.  It now arrives
 * from open(2)'s third argument, masked by the caller's umask in the core;
 * _Sys_ApplyCmask's header carries the reasoning and the Reno citations.
 */
int
root_open(pid, fd, name, fmode, cmode)
int   pid;
int   fd;
char *name;
int   fmode;
int   cmode;
{
    if (root_status != 1)
        return (ENXIO);
    /* THE STARTING DIRECTORY, WHICH IS ALL A RELATIVE PATH EVER NEEDED.
     * vfs_openat's own header called this out -- "when there is a per-process
     * cwd, I3 passes it here and nothing else changes" -- and this is that.
     * Zero still means the system root for an absolute name, which is namei's
     * convention, so that path is unchanged byte for byte. */
    return (vfs_openat(pid, fd,
                       (*name == '/') ? (struct vnode *)0 : vfs_cdir(pid),
                       name, fmode, cmode));
}


/* root_chdir -- chdir(2) against the mounted root.  UFS campaign, the cwd port.
 *
 * root_open's sibling, and the same three lines for the same reason: the
 * ROUTING decision is this bank's, because `root_status' is this file's
 * storage, and the WORK is vfs.mod's, because namei and the cwd table both
 * are.  vfs_chdir's header carries Reno's four operations and the deltas.
 *
 * ENXIO FOR AN UNMOUNTED ROOT, the routing answer the core's hook falls
 * through on, exactly as root_open and root_stat give it.
 */
int
root_chdir(pid, path)
int   pid;
char *path;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_chdir(pid, path));
}


/* root_cdirfork / root_cdirexit -- the cwd's other two lifetime events, from
 * the core.  The cwd port's fork and exit halves.
 *
 * root_chdir's siblings WITHOUT its root_status gate, and the difference is
 * the point rather than an omission.  root_open, root_stat, root_listdir and
 * root_chdir all ROUTE: they answer ENXIO when the boot volume is not a
 * filesystem this kernel mounted, and the core's hook falls through to the
 * legacy resolver on that.  These two decide nothing.  They are bookkeeping on
 * a table that is EMPTY on a machine with no mounted root -- every entry null,
 * because nothing could have chdir'd -- so the gate would be a test whose two
 * arms do the same thing, and the gate is what would have to be kept correct
 * afterwards.  vfs_cdirfork on an empty table copies null to null; vfs_cdirexit
 * on an empty slot returns at its first test.
 *
 * WHICH IS ALSO WHY THEY RETURN NOTHING.  Reno's are `VREF(u.u_cdir)' and
 * `vput(u.u_cdir)' -- two statements in the middle of fork and exit, neither
 * of which can fail and neither of which anybody checks.  A fork that could
 * fail on its cwd would be a fork with a rollback path for it, and upstream
 * has none because there is nothing to roll back.
 */
void
root_cdirfork(ppid, cpid)
int ppid;
int cpid;
{
    vfs_cdirfork(ppid, cpid);
}

void
root_cdirexit(pid)
int pid;
{
    vfs_cdirexit(pid);
}


/* root_unlink / root_mkdir / root_rmdir -- the namespace operations against
 * the mounted root.  apple/fgx#318's second half.
 *
 * root_open's siblings and they route the same way: root_status decides
 * whether this kernel has a root to act on, and the WORK is vfs_syscalls.c's,
 * one function per syscall, ported from Reno.  ENXIO for an unmounted root is
 * the routing answer the core's hook falls through on, exactly as root_open,
 * root_stat, root_listdir and root_chdir give it.
 *
 * THE STARTING DIRECTORY IS CHOSEN HERE, as root_open chooses it: an absolute
 * name walks from the system root (namei's convention for a null dvp) and a
 * relative one from the PROCESS's cwd, which vfs.mod keeps.  `rm foo' and
 * `mkdir foo' are the ordinary case and neither would mean anything without
 * it.
 *
 * NO SEAM AND NO IMPORT SHIM, unlike vfs_chdir above: vfs_syscalls.c compiles
 * into THIS bank (tools/ninja/gen.py:59), so these are plain calls.  The
 * cross-bank hop these operations make is the one on the way IN, from the
 * core's syscall stub to the far slot.
 */
int
root_unlink(pid, path)
int   pid;
char *path;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_unlink(pid, (*path == '/') ? (struct vnode *)0 : vfs_cdir(pid),
                       path));
}

/* root_rename -- rename(2) against the mounted root.  UFS, 2026-09-05.
 *
 * TWO PATHS, EACH RESOLVED FROM ITS OWN STARTING DIRECTORY, which is why the
 * cwd test appears twice: an absolute path starts at the root and a relative
 * one at this process's cwd, exactly as root_unlink above decides it for one
 * path.  Getting that wrong is not a compile error and not a crash -- it is
 * `mv a b' quietly renaming something in the wrong directory.
 *
 * EXDEV is unreachable today, there being one UFS mount, and vfs_rename checks
 * for it anyway because it is upstream's check and the day a second volume is
 * renamable across, a missing test is a silent wrong answer rather than a
 * refusal.
 */
/* root_symlink -- symlink(2) against the mounted root.  UFS, 2026-09-05.
 *
 * ONE PATH IS WALKED AND ONE IS NOT.  `linkname' is the name being created and
 * gets the cwd test every other hook here does; `target' is the link's
 * CONTENTS -- an uninterpreted string written into the inode -- so it is
 * neither resolved nor made absolute, which is what makes a symlink a symlink
 * rather than a hard link.  A relative target is resolved at every future
 * lookup, from wherever the link is then found.
 *
 * `mode' is the link's, the core's `0777 &~ u_cmask' (Reno vfs_syscalls.c:805).
 */
int
root_symlink(pid, target, linkname, mode)
int   pid;
char *target;
char *linkname;
int   mode;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_symlink(pid,
                        (*linkname == '/') ? (struct vnode *)0 : vfs_cdir(pid),
                        linkname, target, mode));
}

/* root_setattr -- chmod(2) and chown(2) against the mounted root.  UFS 2.6.
 *
 * root_unlink's shape, and the cwd test is root_unlink's for its reason: an
 * absolute name starts at the system root and a relative one at this
 * process's directory.  `chmod 644 f' is the ordinary case.
 *
 * EXCEPT THAT THE STARTING DIRECTORY IS NOT PASSED, unlike every sibling
 * above.  vfs_setattr takes the pid and asks vfs_cdir itself, over in
 * vfs.mod -- one crossing rather than two, and the fourteen argument bytes
 * this already costs are the reason to care.
 */
/* root_link -- link(2) against the mounted root.  UFS 2.6.
 *
 * root_setattr's shape, and the starting directory is not passed for its
 * reason: vfs_link resolves BOTH paths against this process's directory and
 * asks vfs_cdir itself, one crossing rather than two for the same fact.
 */
int
root_link(pid, target, linkname)
int   pid;
char *target;
char *linkname;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_link(pid, target, linkname));
}

int
root_setattr(pid, path, follow, mode, uid, gid)
int   pid;
char *path;
int   follow;
int   mode;
int   uid;
int   gid;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_setattr(pid, path, follow, mode, uid, gid,
                        (time_t)VA_UNSET, (time_t)VA_UNSET));
}


/* root_utimes -- utimes(2) against the mounted root.  4.3BSD-Reno
 * kern/vfs_syscalls.c:1269.  UFS 2.7.
 *
 * IT WAS THE LAST PATH-TAKING SYSCALL STILL DISPATCHING INTO prodos.mod.
 * `_Fs_Utime's header said so in as many words -- "dispatches FOP_Utime into
 * prodos.mod, which walks the path to the dir entry, patches its DE_ModDate
 * (4 bytes = packed ProDOS date + time)" -- and prodos.mod is not loaded on a
 * UFS root, so utimes(2) answered a failure from the ProDOS resolver.  Nothing
 * reported it: no manifest mentions utime, and disk_src/testbin/utimetest has
 * been built and staged on every image and run by nothing.  apple/fgx#343.
 *
 * FOLLOW, LIKE UPSTREAM.  Reno's utimes uses `LOOKUP | FOLLOW | LOCKLEAF' --
 * it stamps the file a symlink names, not the link -- where lutimes (which
 * neither Reno nor this tree has) would not.  chmod(2) is the same and
 * root_setattr passes follow=1 for it.
 *
 * THE ACCESS TIME IS CARRIED, AND ProDOS COULD NOT.  The old path packed one
 * civil date+time into ProDOS's two 16-bit words in LIBC and dropped tv[0]
 * entirely, because a ProDOS directory entry has a mod date and nothing else.
 * A 2.11BSD inode has i_atime and i_mtime and ufs_setattr has honoured both
 * since 1.12b, so both go over now -- as two epoch time_t, which is what the
 * inode holds and what removes the conversion rather than moving it.
 */
int
root_utimes(pid, path, atime, mtime)
int    pid;
char  *path;
time_t atime;
time_t mtime;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_setattr(pid, path, 1, VA_UNSET, VA_UNSET, VA_UNSET,
                        atime, mtime));
}

int
root_rename(pid, from, to)
int   pid;
char *from;
char *to;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_rename(pid,
                       (*from == '/') ? (struct vnode *)0 : vfs_cdir(pid), from,
                       (*to   == '/') ? (struct vnode *)0 : vfs_cdir(pid), to));
}

int
root_mkdir(pid, path, dmode)
int   pid;
char *path;
int   dmode;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_mkdir(pid, (*path == '/') ? (struct vnode *)0 : vfs_cdir(pid),
                      path, dmode));
}

/* root_statfs -- statfs(2) against the mounted root.  apple/fgx#329, df(1).
 *
 * THE CWD TEST IS root_unlink's, for root_unlink's reason: an absolute path
 * starts at the system root and a relative one at this process's directory.
 * It matters more here than it looks, because `df .' is a thing people type
 * and a `.' resolved from the wrong directory would report the wrong
 * filesystem on a machine with more than one mounted -- silently, since every
 * answer is a plausible one.
 *
 * `sbp' IS THE CALLER'S BUFFER AND CROSSES UNTOUCHED.  Nothing on this side
 * dereferences it; vfs_statfs1 ends in uio_copy, whose MVN takes the
 * destination bank from the pointer.  include/kfar.s's slot comment carries
 * the argument for doing it this way rather than through a core scratch.
 */
int
root_statfs(pid, path, sbp)
int            pid;
char          *path;
struct statfs *sbp;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_statfs(pid, path, sbp));
}

/* root_access -- access(2) against the mounted root.  UFS 2.6. */
int
root_access(pid, path, fmode)
int   pid;
char *path;
int   fmode;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_access(pid, (*path == '/') ? (struct vnode *)0 : vfs_cdir(pid),
                       path, fmode));
}

int
root_rmdir(pid, path)
int   pid;
char *path;
{
    if (root_status != 1)
        return (ENXIO);
    return (vfs_rmdir(pid, (*path == '/') ? (struct vnode *)0 : vfs_cdir(pid),
                      path));
}
