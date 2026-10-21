/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno miscfs/specfs/spec_vnops.c
 *   Ported from miscfs/specfs/spec_vnops.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 */
/* spec_vnops.c -- specfs: the filesystem a DEVICE belongs to.
 *
 * Ported from 4.3BSD-Reno kern/spec_vnops.c.
 *
 * WHAT SPECFS IS FOR.  A device node is a file in some filesystem -- an inode
 * with a mode, an owner and a link count -- but reading it must reach a driver
 * rather than the filesystem's data blocks.  specfs is how BSD resolves that:
 * the vnode keeps its inode in v_data and its filesystem's identity in v_tag,
 * but wears THIS vector, so every operation on it is answered by the device
 * layer instead of by the filesystem that merely names it.  That is why
 * checkalias swaps in `spec_vnodeops` and not something UFS-specific, and why
 * a device keeps working across a forced unmount of the filesystem it came
 * from: the vector does not belong to that filesystem in the first place.
 *
 * WHAT IT DOES NOT YET DO, AND WHY.  The buffer cache still calls
 * bio_strategy by NAME rather than issuing VOP_STRATEGY on the buffer's vnode.
 * That change is written and reverted, not forgotten: it works in the fcc
 * fixtures and cannot work in the FAR BANK, because an ops vector compiled
 * there is ALL ZEROES -- fcc emits each entry as FGX2_LONG_PTR, whose offset
 * is resolved by fgx_ld and whose bank byte is written by the FGX2 loader, and
 * the far kernel bank is a Merlin link that goes through neither.
 * apple/fgx#88 has the measurement.
 *
 * THE SECOND HALF OF THAT PARAGRAPH WAS STALE AND IS CORRECTED HERE: it said
 * this file was "fixture-verified and not in the kernel's source list".  It
 * has been in vfs.mod since the VFS became a module, and a MODULE's ops vector
 * does work -- fcc's &function cells become MOD_FN_PTR and _Mod_StampFnPtrs
 * writes the bank at load time (apple/fgx#173, #178).  Every VOP_ dispatch in
 * the UFS probes goes through vectors built exactly that way.  What #88
 * describes is a FAR-BANK limitation, and the far bank is not where this
 * lives.
 *
 * What DID land from that seam is the half that needs no dispatch: bgetvp
 * reads b_dev from v_rdev for a device vnode, so a buffer belonging to a
 * device carries it without anyone naming it.
 *
 *----------------------------------------------------------------------------
 * FGX HAS A bdevsw AND NO cdevsw, AND THAT SHAPES THESE OPERATIONS.
 *
 * Reno dispatches through two device-switch tables indexed by major number.
 * FGX's block side is 2.11BSD's bdevsw, in bio_strategy.c: `dev_t' is a major
 * and a minor (fsparam.h), and the major picks the driver.  Its character
 * devices are a REGISTRY reached by index (src/kernel/chardev.s), so a VCHR
 * vnode's v_rdev is a registry index in a single-major space: major(dev) is a
 * constant and minor(dev) is dev.
 *
 * THE CHARACTER ARMS ARE LIVE AS OF UFS 1.13b.  open, close, read and write
 * dispatch through kc_cdopen/kc_cdclose/kc_cdread/kc_cdwrite onto that
 * registry, so a VCHR vnode reaches the same drivers syscall.s reaches.  What
 * makes a VCHR vnode exist at all is 1.13a: mknod, an on-disk IFCHR inode, and
 * an iget that joins the device alias chain.
 *
 * IOCTL AND SELECT DISPATCH AS OF UFS 1.7d I4, AND THE PANIC THIS REPLACES
 * ASKED A QUESTION THAT HAS AN ANSWER.  It said both needed "a marshalling
 * decision that read and write do not", ioctl's argument being a pointer into
 * the CALLER's bank and select's a per-process wait record.  Neither survives
 * contact with how FGX actually builds them:
 *
 *   ioctl's pointer is never dereferenced on this road.  It reaches the
 *   driver's op through _Sys_IoctlArgLo/_Sys_IoctlArgBank, which _Sys_Ioctl
 *   stages in its first four instructions -- before it classifies the
 *   descriptor, so they already hold THIS ioctl's arg whichever road follows.
 *   There is no second decision to make; there is one already made upstream of
 *   both roads.  See include/modules.s at KSVC_CDIOCTL.
 *
 *   select has no per-process wait record to marshal.  Reno's ttselect parks
 *   u.u_procp in tp->t_rsel and selwakeup() wakes that one selector; FGX's
 *   select(2) registers on nothing -- _Sys_Select is a poll-and-yield loop on
 *   the single WCHAN_SELECT, which far_shims.s's _FarSh_SelWakeup records at
 *   length.  There is one channel and no registration.
 *
 * So what was owed was not a decision but a DOOR: a module could not reach
 * _Chardev_Ioctl/_Chardev_Poll at all (a scraped kernel address dispatches on
 * the module's direct page -- kc_chardev.s's note), and the switch itself has
 * been dispatching COPS_Ioctl and COPS_Poll for the registry road since T2.
 * KSVC_CDIOCTL and KSVC_CDPOLL are that door.
 *
 * Where Reno calls a switch entry this either does the equivalent directly
 * (spec_strategy -> bio_strategy) or reaches the registry through the same
 * gateway the other character arms use.  Nothing here silently returns success
 * for an operation it did not perform.
 *
 * SPEC_READ AND SPEC_WRITE ARRIVED AT 1.7b.  They stood as a panic naming
 * `struct uio` from 1.5 until 1.7a supplied it -- deliberately, because
 * writing a uio loop before the structure existed would have meant inventing
 * it ahead of its only caller.  See their own header further down for what
 * Reno's version does that this one does not need.
 */

#include "fsparam.h"
#include "vnode.h"
#include "mount.h"
#include "specdev.h"
#include "buf.h"
#include "uio.h"
#include "file.h"       /* FREAD/FWRITE -- spec_select's `which' */

extern int          bread();
extern struct buf  *getblk();
extern void         brelse();
extern int          bawrite();
extern int          bdwrite();
extern int          uiomove();

extern void kc_panic();

/* The disk, in bio_strategy.c beside this file. */
extern void bio_strategy();

/* From vfs_bio.c: the buffer work a last close on a block device has to do. */
extern int  vflushbuf();
extern int  vinvalbuf();

/* From vfs_subr.c: the reference count across every vnode naming this device,
 * which is the only count a last close can be decided on. */
extern int  vcount();

int spec_lookup();
/* The character device switch, UFS 1.13b -- src/modules/common/kc_sys.s.
 * Reno dispatches cdevsw[major(dev)]; FGX has one major and an INDEX into the
 * chardev registry, and v_rdev IS that index for a VCHR vnode. */
/* vfs.mod, through this module's vfs_import.s: the securelevel gate.  The
 * level and the raw-to-block mapping both live there. */
extern int spec_securechr();
extern int kc_cdopen();
extern int kc_cdclose();
extern int kc_cdread();
extern int kc_cdwrite();
extern int kc_cddread();
extern int kc_cddwrite();
extern int kc_cdioctl();        /* d_ioctl -- UFS 1.7d I4 */
extern int kc_cdpoll();         /* d_select, as a POLL* mask -- UFS 1.7d I4 */

/* POLLIN and POLLOUT, from include/chardev.s.  Restated for the reason the
 * errnos and NTTY are: kernel C cannot include an assembly header, and
 * tools/check_chardev_ops.py holds the copies together -- a drift here is
 * silent, since a wrong bit makes select answer confidently about the wrong
 * direction and nothing fails to build. */
#define POLLIN          0x0001
#define POLLOUT         0x0004

static int spec_chread();
static int spec_chwrite();

int spec_open();
int spec_close();
int spec_read();
int spec_write();
int spec_ioctl();
int spec_select();
int spec_strategy();
int spec_bmap();
int spec_lock();
int spec_unlock();
int spec_print();
int spec_ebadf();
int spec_badop();
int spec_nullop();

/* THE VECTOR.  Positional, in the order struct vnodeops declares -- a slot
 * added or removed here shifts every entry after it and still runs something.
 *
 * Reno's three failure modes are kept distinct, exactly as dead_vnops.c keeps
 * them, because they are not interchangeable:
 *
 *   spec_badop    the operation is MEANINGLESS on a device.  Creating a file
 *                 inside /dev/rd0, or reading it as a directory, is a caller
 *                 that has lost track of what it holds -- a panic, because
 *                 there is no correct errno for "this cannot be asked".
 *   spec_ebadf    the operation is meaningful but the caller has no business
 *                 doing it through this vnode; EBADF.
 *   spec_nullop   the operation is meaningful and there is genuinely nothing
 *                 to do; success.
 */
struct vnodeops spec_vnodeops = {
    spec_lookup,        /* lookup */
    spec_badop,         /* create */
    spec_badop,         /* mknod */
    spec_open,          /* open */
    spec_close,         /* close */
    spec_ebadf,         /* access */
    spec_ebadf,         /* getattr */
    spec_ebadf,         /* setattr */

    spec_read,          /* read */
    spec_write,         /* write */
    spec_ioctl,         /* ioctl */
    spec_select,        /* select */
    spec_badop,         /* mmap */
    spec_nullop,        /* fsync */
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
    spec_nullop,        /* inactive */
    spec_nullop,        /* reclaim */
    spec_lock,          /* lock */
    spec_unlock,        /* unlock */

    spec_bmap,          /* bmap */
    spec_strategy,      /* strategy */

    spec_print,         /* print */
    spec_nullop         /* islocked */
};


/* mountedon -- is a filesystem mounted on this block device?
 *
 * Reno keeps this in ufs_vfsops.c; it lives here because it is a property of
 * the DEVICE, not of UFS, and every filesystem type would otherwise carry a
 * copy.  It is also the first real reader of si_flags.
 *
 * THE ALIAS WALK IS THE POINT.  SI_MOUNTEDON is set on whichever vnode the
 * mount happened through, and a second name for the same device is a different
 * vnode with its own specinfo.  Testing only this vnode's flag would let a
 * device be opened for writing through its other name while a filesystem is
 * mounted on it -- which corrupts the mounted filesystem underneath itself,
 * silently, with no error anywhere. */
int mountedon(vp)
    register struct vnode *vp;
{
    register struct vnode *vq;

    if (vp->v_specflags & SI_MOUNTEDON)
        return (EBUSY);
    if (vp->v_flag & VALIASED) {
        for (vq = *vp->v_hashchain; vq; vq = vq->v_specnext) {
            if (vq->v_rdev != vp->v_rdev || vq->v_type != vp->v_type)
                continue;
            if (vq->v_specflags & SI_MOUNTEDON)
                return (EBUSY);
        }
    }
    return (0);
}


/* spec_lookup -- a device is not a directory.
 *
 * Reno also stores the result into the nameidata the caller passed, which
 * arrives with namei at 1.6.  The RETURN is the operative half and is what
 * makes a path like /dev/rd0/foo fail at the right component. */
int spec_lookup(vp, ndp)
    struct vnode *vp;
    char *ndp;
{
    return (ENOTDIR);
}


/* spec_open -- validate before any I/O.
 *
 * Reno calls the device switch's d_open here.  FGX's block layer has no open
 * entry point -- kc_blkio is stateless per call -- so what remains is the
 * VALIDATION, and it is not a formality:
 *
 *   MNT_NODEV   the filesystem this node was read from is not trusted to name
 *               devices.  A removable volume carrying a /dev/mem owned by root
 *               is the attack this flag exists to stop, and the check belongs
 *               here rather than at mount time because the node is only
 *               dangerous when someone opens it.
 *   mountedon   a block device with a filesystem mounted on it cannot also be
 *               opened as a raw device; writing to it would corrupt the mount.
 *   securechr   and the same corruption through the CHARACTER face, which is
 *               the one fsck(8) opens.  Refused only at securelevel 1, which
 *               is what makes a read-write fsck of the root legal from
 *               /etc/rc and refused once init has gone multiuser.
 *   NODEV       a device vnode that names no device would index off the end of
 *               the device table.  bio_strategy rejects it too, but by then
 *               the caller believes the open succeeded.
 *   NBLKDEV     a block major no driver claims is getmdev's ENXIO (2.11BSD
 *               usr/sys/sys/ufs_mount.c:346), and for the same reason. */
int spec_open(vp, mode, cred)
    register struct vnode *vp;
    int mode;
    char *cred;
{
    int error;

    if (vp->v_mount && (vp->v_mount->mnt_flag & MNT_NODEV))
        return (ENXIO);

    if (vp->v_type != VCHR && vp->v_type != VBLK)
        return (ENXIO);
    if (vp->v_rdev == NODEV)
        return (ENXIO);

    if (vp->v_type == VBLK) {
        if (major(vp->v_rdev) >= NBLKDEV)
            return (ENXIO);
        error = mountedon(vp);
        if (error)
            return (error);
        return (0);
    }

    /* THE SECURELEVEL GATE, and it is the WRITE that is refused.
     *
     * 2.11BSD's openi, usr/sys/sys/sys_inode.c:650-670: the whole clause sits
     * inside `if (mode & FWRITE)', so reading a mounted filesystem's raw
     * device stays legal at every level.  That asymmetry is the design and not
     * an oversight -- `fsck -n /dev/rsd0' on a live root is how you find out
     * whether the machine needs single user, and a read cannot hurt the mount.
     *
     * AFTER THE NODEV AND MNT_NODEV TESTS, which is upstream's order: a node
     * that names no device is ENXIO whatever the level, and a filesystem that
     * is not trusted to name devices is refused before anything asks which
     * device this is. */
    if (mode & FWRITE) {
        error = spec_securechr((int)vp->v_rdev);
        if (error)
            return (error);
    }

    /* THE DRIVER'S OPEN RUNS ON EVERY open(2), which is BSD's asymmetry and
     * not an oversight: openi() calls d_open unconditionally while closei()
     * calls d_close only once nothing else holds the device.  The registry
     * counts for the close; this side does not count at all. */
    return (kc_cdopen((int)vp->v_rdev));
}


/* spec_close -- and on a block device's LAST close, drop its cached blocks.
 *
 * THE FLUSH IS NOT HOUSEKEEPING.  The buffer cache is keyed by (vnode, logical
 * block), so blocks cached against a device vnode survive the close that ended
 * the caller's interest in them.  Change the medium -- a different volume on
 * the same SmartPort unit -- and the next read is answered from the cache with
 * the OLD volume's bytes.  That is the same corruption shape apple/fgx#84 was
 * about, one level up: silent, no error, and invisible until the data is wrong.
 *
 * THE FLUSH DOES NOT WAIT FOR THE LAST CLOSE, and Reno's comment and Reno's
 * code disagree about that.  The comment says "on last close ... we must
 * invalidate any in core blocks"; the code invalidates BEFORE it consults
 * vcount, so every close drops the cache and only the DRIVER close is withheld
 * until the last one.  This follows the code, because that is the behaviour
 * every BSD has shipped and the one a caller would have been written against.
 *
 * LAST CLOSE IS vcount, NOT v_usecount.  Two vnodes can name one device, and
 * either one's count reaching zero says nothing about the other's.  VXLOCK
 * overrides the count, because a vnode being torn down is being closed whether
 * or not anyone else holds it -- that is a forced revoke.
 *
 * ON FGX THAT BRANCH IS CURRENTLY UNOBSERVABLE, and saying so is better than
 * letting it look tested: what it guards is the driver close, and kc_blkio is
 * stateless, so there is nothing for a last close to release.  It is kept
 * because it is the condition the day a character-device switch arrives, and
 * because deleting it would mean rediscovering that vcount is the right
 * question. */
int spec_close(vp, flag, cred)
    register struct vnode *vp;
    int flag;
    char *cred;
{
    switch (vp->v_type) {

    case VCHR:
        /* TWO COUNTS, AND THEY ANSWER DIFFERENT QUESTIONS.  vcount asks how
         * many VNODES name this device -- /dev/console and /dev/tty0 can be
         * two -- and returning early here is what stops one path's close
         * tearing the driver down under another.  The registry keeps its own
         * count of OPENS and gates the driver's teardown on that.  Neither
         * subsumes the other, and apple/fgx#76 is what happens when the second
         * is mistaken for "the last close of a file handle". */
        if (vcount(vp) > 1 && (vp->v_flag & VXLOCK) == 0)
            return (0);
        return (kc_cdclose((int)vp->v_rdev));

    case VBLK:
        vflushbuf(vp, 0);
        if (vinvalbuf(vp, 1))
            return (0);
        if (vcount(vp) > 1 && (vp->v_flag & VXLOCK) == 0)
            return (0);
        /* Reno calls bdevsw[].d_close here.  kc_blkio is stateless, so there
         * is no driver state to release -- the cache invalidation above IS the
         * whole of what closing this device means on FGX. */
        return (0);
    }
    kc_panic("spec_close: not special");
    return (0);
}


/* spec_ioctl.  Reno: `(*cdevsw[major(dev)].d_ioctl)(dev, com, data, fflag)'
 * for VCHR, the block switch for VBLK, and panic("spec_ioctl") in the default
 * arm (4.3BSD-Reno kern/spec_vnops.c:319).
 *
 * `com', `data' AND `fflag' ARE NOT PASSED ON, AND THEY ARE NOT DROPPED.  The
 * chardev op reads cmd and arg from the kernel singletons _Sys_Ioctl stages
 * ahead of any dispatch, so the values below and the values the op will read
 * are the same values -- these arrived by the longer road.  Forwarding them
 * would mean re-staging a copy over the original, which is a write that can
 * only be wrong.  The full argument is at KSVC_CDIOCTL in include/modules.s,
 * including what it would take to pass them properly and why that is a change
 * to every driver's ioctl entry rather than to this line.
 *
 * FGX HAS NO BLOCK IOCTL, so VBLK keeps the answer it had.  Reno's block arm
 * carries a B_TAPE special case ahead of the switch call; there is no tape,
 * and ENOTTY is what BSD returns for a request a device does not implement.
 *
 * THE DEFAULT ARM DOES NOT PANIC WHERE RENO'S DOES.  Reno reaches this only
 * through a device vnode, so "neither VCHR nor VBLK" is impossible and panic
 * says so.  On FGX spec_ioctl is reachable through vnops for any vnode
 * fo_ioctl is called on, so the same condition is merely an ioctl on something
 * that is not a device -- ENOTTY, the answer ioctl(2) on a regular file has
 * always given. */
int spec_ioctl(vp, com, data, fflag, cred)
    struct vnode *vp;
    int com;
    char *data;
    int fflag;
    char *cred;
{
    if (vp->v_type == VCHR)
        return (kc_cdioctl((int)vp->v_rdev));
    return (ENOTTY);
}


/* spec_select.  Reno: `(*cdevsw[major(dev)].d_select)(dev, which)' for VCHR
 * and `return (1)' in the default arm (4.3BSD-Reno kern/spec_vnops.c:346).
 *
 * Reno's default arm answers "ready" for everything that is not a character
 * device, and a block device genuinely is: the transfer is synchronous
 * SmartPort PIO, so there is never a moment at which it would not complete
 * immediately.
 *
 * ONE DISPATCH ANSWERS BOTH DIRECTIONS, WHERE RENO'S ANSWERS ONE.  Reno's
 * d_select takes `which' and returns a readiness for that direction alone;
 * FGX's COPS_Poll returns a POLLIN|POLLOUT mask and the caller picks its bit.
 * So `which' is applied
 * HERE rather than passed down.
 *
 * THE THIRD QUESTION, `which' 0, IS ANSWERED 0 FOR EVERY CHARACTER DEVICE, and
 * that is upstream's answer only for a tty.  2.11BSD asks the driver
 * (usr/sys/pdp/conf.c): ttyselect's switch knows FREAD and FWRITE, and any
 * other `rw' falls out of it to `return (0)' (usr/sys/sys/tty.c:606-640); but
 * seltrue -- the memory devices, /dev/null among them, and the raw disks --
 * answers 1 (usr/sys/sys/sys_generic.c:496), and ptcselect answers 1 when a
 * packet-mode pty master has a control byte pending (usr/sys/sys/
 * tty_pty.c:346-350).  COPS_Poll's mask carries POLLIN and POLLOUT and nothing
 * else, so no driver has a way to give its own answer here (apple/fgx#445).
 *
 * A BAD INDEX IS ALSO "NOT READY", NOT AN ERROR.  select(2) has nowhere to put
 * an errno for one descriptor of a set -- this function returns a readiness,
 * not a status -- so kc_cdpoll answers a zero mask for an index that names no
 * device and the caller blocks or times out rather than being told a lie. */
int spec_select(vp, which, fflags, cred)
    struct vnode *vp;
    int which;
    int fflags;
    char *cred;
{
    int mask;

    if (vp->v_type != VCHR)
        return (1);

    mask = kc_cdpoll((int)vp->v_rdev);
    if (which == FREAD)
        return ((mask & POLLIN) != 0);
    if (which == FWRITE)
        return ((mask & POLLOUT) != 0);
    return (0);
}


/* spec_strategy -- hand the buffer to the disk.
 *
 * Reno indexes bdevsw by major(bp->b_dev) here; bio_strategy does, so this
 * calls it.  The indirection is what lets the buffer cache issue I/O without
 * knowing whether the vnode it holds is a device or a file, and it is the seam
 * a filesystem's own strategy (ufs_strategy, which fills b_dev from the
 * inode's i_devvp and then reaches this one) plugs into. */
int spec_strategy(bp)
    struct buf *bp;
{
    bio_strategy(bp);
    return (0);
}


/* spec_bmap -- logical block to physical block, which on a device is identity.
 *
 * A file's blocks are scattered and bmap consults the inode; a device IS its
 * own block space, so block n is block n.  Returning the vnode unchanged in
 * *vpp is the other half: for a file, bmap returns the DEVICE vnode the I/O
 * should be issued against, and for a device that is this vnode. */
int spec_bmap(vp, bn, vpp, bnp)
    struct vnode *vp;
    daddr_t bn;
    struct vnode **vpp;
    daddr_t *bnp;
{
    if (vpp)
        *vpp = vp;
    if (bnp)
        *bnp = bn;
    return (0);
}


/* spec_lock / spec_unlock.  Reno does no locking on device vnodes and neither
 * does this.  They are not spec_nullop: vclean calls them through the vector
 * and a reader tracing that path should find a function named for what it is
 * being asked to do, not a shared success stub. */
int spec_lock(vp)
    struct vnode *vp;
{
    return (0);
}


int spec_unlock(vp)
    struct vnode *vp;
{
    return (0);
}


/* spec_print.  Reno prints the device's major and minor; FGX has no kernel
 * printf reachable from here, and the operation exists to be called from a
 * debugger rather than from code. */
int spec_print(vp)
    struct vnode *vp;
{
    return (0);
}


/* THE THREE FAILURE MODES, kept distinct (see the vector above). */
int spec_ebadf()
{
    return (EBADF);
}


int spec_badop()
{
    kc_panic("spec_badop called");
    return (0);
}


int spec_nullop()
{
    return (0);
}


/* spec_read and spec_write -- the block-device transfer path.  UFS 1.7b.
 *
 * Ported from vendor/4.3BSD-Reno/kern/spec_vnops.c's spec_read (:150) and
 * spec_write (:222).  These replace the spec_nouio panic that has stood in for
 * them since 1.5, which named `struct uio` as what was missing; 1.7a supplied
 * it.
 *
 * ONE BLOCK SIZE, SO RENO'S NEGOTIATION IS GONE.  Reno asks the driver for the
 * partition geometry (DIOCGPART) and derives bsize from the filesystem's frag
 * size, falling back to BLKDEV_IOSIZE -- because a 4.3BSD disk carries several
 * filesystems with different fragment sizes.  FGX has one block size,
 * FS_BLKSIZE, fixed at 1024 and baked into the buffer cache: `bread(vp, blkno,
 * &bp)` takes no size argument because there is nothing to choose.  So the
 * whole partinfo dance drops out, and with it the CLBYTES clustering and the
 * munhash loop, neither of which has anything to index here.
 *
 * THE LOOP IS RENO'S AND THE TERMINATION IS THE POINT.  Each turn reads (or
 * claims) the block containing uio_offset, hands uiomove the run from `on` to
 * the end of that block, and goes round -- uiomove having advanced the cursor,
 * which is what makes the next turn address the next block.  A uiomove that
 * copied correctly and advanced nothing would spin here forever, which is why
 * 1.7a's probe asserts the cursor separately from the bytes.
 *
 *----------------------------------------------------------------------------
 * WHAT IS DELIBERATELY NOT HERE:
 *
 *   THE VCHR ARM.  Reno dispatches `cdevsw[major(v_rdev)].d_read`.  FGX has no
 *   cdevsw -- see the head of this file -- and reaches its character devices by
 *   INDEX from the syscall layer rather than through a vnode, so no VCHR vnode
 *   can exist to arrive here until mknod and a real /dev do at 1.13.  It panics
 *   rather than returning an errno, for the reason spec_nouio did: an errno
 *   would let an impossible path return a plausible failure and hide itself.
 *
 *   b_resid IS ALWAYS ZERO, so Reno's short-read clamp is inert.  Reno writes
 *   `n = MIN(n, bsize - bp->b_resid)` to shorten the transfer when the driver
 *   moved less than a full block.  Every assignment to b_resid in vfs_bio.c is
 *   `= 0` (four sites) -- nothing ever reports a partial transfer, because the
 *   block layer's SmartPort PIO either completes a block or fails the whole
 *   request.  The clamp is CARRIED ANYWAY rather than dropped: it costs two
 *   instructions, and the day the block layer learns to report a short read is
 *   the day its absence would silently truncate every transfer that hit one.
 *   The `n != 0` loop guard is dead for the same reason and kept for the same
 *   one -- it is what stops the loop spinning once a short read is possible.
 */

/* spec_chread / spec_chwrite -- the CHARACTER device arms.  UFS 1.13b.
 *
 * THE ioflag IS PASSED ON, which is Reno's shape -- its VCHR arm is one call,
 * `(*cdevsw[major(vp->v_rdev)].d_read)(vp->v_rdev, uio, ioflag)'
 * (kern/spec_vnops.c:178), and the flag is the third argument of it.  It was
 * dropped here until apple/fgx#310: spec_read took an ioflag and called
 * spec_chread(vp, uio), so IO_NDELAY died one level above the device and no
 * character device opened under /dev could be non-blocking.  The seam ops
 * carry it now, in the free bit 4 of the index byte (../../modules/vfs/
 * kc_chardev.s), because no register was left to put it in.
 *
 * A BYTE AT A TIME, WHICH IS THE REGISTRY'S SHAPE AND NOT A SIMPLIFICATION.
 * Reno hands the whole uio to cdevsw[].d_read and lets the driver move it;
 * FGX's chardev ops take and return one byte (include/chardev.s documents the
 * op ABI).  A
 * block-at-a-time seam would have to be invented at the DRIVER end first, and
 * there is nothing to gain from inventing it before a driver that could use it
 * exists.
 *
 * uiomove IS STILL WHAT MOVES THE BYTE, one at a time, because it is what
 * knows whether the destination is in the kernel or in a user bank -- this
 * loop must not learn that.  It also advances the cursor, which is what makes
 * the loop terminate.
 *
 * A SHORT READ IS NOT AN ERROR AND STOPS THE LOOP.  End of file after n bytes
 * returns success with n moved and uio_resid holding the rest; that is read(2)
 * and it is what a caller distinguishes EOF by.  An errno on the FIRST byte is
 * returned; an errno after some bytes have moved is swallowed in favour of the
 * short count, which is upstream's rule everywhere and the reason ufs_read has
 * the same shape.
 */
static char specbyte;           /* one byte, staged for uiomove */

static int
spec_chread(vp, uio, ioflag)
    struct vnode *vp;
    struct uio *uio;
    int ioflag;
{
    int moved;
    int r;
    int st;
    int error;

    /* THE DEVICE'S OWN BULK READ FIRST, and the loop below only if it has
     * none.  A record-mode driver -- the pty master, bpf -- fills a buffer
     * whole and answers a COUNT, and the per-byte loop reads that count as one
     * byte's VALUE: the buffer arrives filled, uio_resid drops by one, and the
     * next call refills it from the top.  That is apple/fgx#198's silent half,
     * and cdevsw's d_read is where such a driver can say so.
     *
     * THE ANSWER CARRIES A STATUS BYTE, NOT AN errno SENTINEL.  Status 1 --
     * "this device has no bulk op" -- is the ordinary case and must not be
     * confused with an error the op itself returned; an errno cannot do that
     * job, because nodev() in the line-discipline switch returns ENODEV and
     * that switch is where tty bulk reads route once the discipline lands. */
    r = kc_cddread((int)vp->v_rdev, uio, ioflag);
    st = (r >> 8) & 0xFF;
    if (st != 1)
        return (r & 0xFF);          /* status 0, the op ran: its errno, 0 for
                                     * success.  Status 2: the index names no
                                     * device, and the low byte is ENODEV.
                                     * ONE test, because both answers are the
                                     * low byte -- an earlier cut wrote the two
                                     * as separate ifs returning the same
                                     * expression, so the first could be
                                     * mutated with no effect at all. */
    /* status 1 alone falls through: a per-byte device, so our own loop. */

    moved = 0;
    while (uio->uio_resid != 0) {
        r  = kc_cdread((int)vp->v_rdev, ioflag);
        st = (r >> 8) & 0xFF;
        if (st == 1)
            break;              /* end of file */
        if (st != 0) {
            if (moved != 0)
                break;          /* a short read, not a failure */
            return (r & 0xFF);  /* the errno, on the first byte */
        }
        specbyte = (char)(r & 0xFF);
        error = uiomove(&specbyte, 1, uio);
        if (error)
            return (error);
        moved = moved + 1;
    }
    return (0);
}

static int
spec_chwrite(vp, uio, ioflag)
    struct vnode *vp;
    struct uio *uio;
    int ioflag;
{
    int moved;
    int error;

    /* The write half of the same question -- see spec_chread. */
    error = kc_cddwrite((int)vp->v_rdev, uio, ioflag);
    if (((error >> 8) & 0xFF) != 1)
        return (error & 0xFF);

    moved = 0;
    while (uio->uio_resid != 0) {
        error = uiomove(&specbyte, 1, uio);
        if (error)
            return (error);
        error = kc_cdwrite((int)vp->v_rdev, (int)(unsigned char)specbyte,
                           ioflag);
        if (error) {
            /* GIVE THE BYTE BACK.  uiomove has taken it out of the uio
             * and the device has refused it, so without this the count
             * rwcommon computes -- `cnt -= auio.uio_resid' -- includes a byte
             * that went nowhere.  Upstream makes the same correction in as
             * many words, at ptcwrite's block label:
             *
             *     if (flag & IO_NDELAY) {
             *         -- adjust for data copied in but not written --
             *         uio->uio_resid += cc;
             *         if (cnt == 0)
             *             return (EWOULDBLOCK);
             *         return (0);
             *     }
             *
             * -- vendor/2.11BSD/usr/sys/sys/tty_pty.c:453-459.
             *
             * ABOVE THE `moved' TEST, so both exits pass it.  The `break'
             * below reports a SHORT write, and a short count that is one too
             * long is the same defect quietly: the caller believes a byte
             * landed and does not resend it. */
            uio->uio_resid = uio->uio_resid + 1;
            if (moved != 0)
                break;
            return (error);
        }
        moved = moved + 1;
    }
    return (0);
}


/* spec_read -- fill the uio from the device, a block at a time. */
int spec_read(vp, uio, ioflag, cred)
    struct vnode *vp;
    struct uio *uio;
    int ioflag;
    char *cred;
{
    struct buf *bp;
    daddr_t bn;
    register int on, n;
    int error;

    if (uio->uio_rw != UIO_READ)
        kc_panic("spec_read mode");
    if (uio->uio_resid == 0)
        return (0);
    /* ONE ARM RUNS, which is Reno's switch and not a sequence of ifs.  A
     * VCHR vnode must report the missing character-device switch and nothing
     * else; with two independent tests it reports that AND "wrong type",
     * because VCHR is also not VBLK.  On the machine kc_panic halts so only
     * the first is ever seen, but a host fixture whose kc_panic counts and
     * returns sees both -- which is how this was found. */
    if (vp->v_type == VCHR) {
        /* DROP THE LOCK ACROSS THE DRIVER, which is upstream's shape and was
         * missing here: `VOP_UNLOCK(vp); d_read(...); VOP_LOCK(vp);'
         * (4.3BSD-Reno kern/spec_vnops.c:177-180).  A character read BLOCKS --
         * a tty read sleeps until the next keystroke -- and holding the inode
         * lock across it makes every other opener of that device wait for a
         * line to be typed.  On /dev/console that is every process with a
         * console fd, which is all of them.  apple/fgx#311. */
        VOP_UNLOCK(vp);
        error = spec_chread(vp, uio, ioflag);
        VOP_LOCK(vp);
        return (error);
    }
    else if (vp->v_type != VBLK)
        kc_panic("spec_read type");
    /* Reno allows a negative offset only for /dev/kmem, which this tree has no
     * way to name; every other negative offset is EINVAL there and here. */
    if (uio->uio_offset < 0)
        return (EINVAL);

    error = 0;
    do {
        bn = lblkno(uio->uio_offset);
        on = (int)blkoff(uio->uio_offset);
        n = FS_BLKSIZE - on;
        if (n > (int)uio->uio_resid)
            n = (int)uio->uio_resid;
        error = bread(vp, bn, &bp);
        /* bread sets *bpp BEFORE it can fail (it comes from getblk, which
         * blocks rather than failing), so the buffer is ours to release on the
         * error path too -- which is why Reno releases it here as well. */
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


/* spec_write -- drain the uio to the device, a block at a time. */
int spec_write(vp, uio, ioflag, cred)
    struct vnode *vp;
    struct uio *uio;
    int ioflag;
    char *cred;
{
    struct buf *bp;
    daddr_t bn;
    register int on, n;
    int error;

    if (uio->uio_rw != UIO_WRITE)
        kc_panic("spec_write mode");
    if (uio->uio_resid == 0)
        return (0);
    /* ONE ARM RUNS, which is Reno's switch and not a sequence of ifs.  A
     * VCHR vnode must report the missing character-device switch and nothing
     * else; with two independent tests it reports that AND "wrong type",
     * because VCHR is also not VBLK.  On the machine kc_panic halts so only
     * the first is ever seen, but a host fixture whose kc_panic counts and
     * returns sees both -- which is how this was found. */
    if (vp->v_type == VCHR) {
        /* The write half of the same rule -- Reno kern/spec_vnops.c:252-255. */
        VOP_UNLOCK(vp);
        error = spec_chwrite(vp, uio, ioflag);
        VOP_LOCK(vp);
        return (error);
    }
    else if (vp->v_type != VBLK)
        kc_panic("spec_write type");
    if (uio->uio_offset < 0)
        return (EINVAL);

    error = 0;
    do {
        bn = lblkno(uio->uio_offset);
        on = (int)blkoff(uio->uio_offset);
        n = FS_BLKSIZE - on;
        if (n > (int)uio->uio_resid)
            n = (int)uio->uio_resid;
        /* A WHOLE BLOCK IS CLAIMED, NOT READ.  Every byte is about to be
         * overwritten, so reading the old contents first is a device transfer
         * for bytes nobody will look at.  getblk hands back the buffer without
         * touching the disk; bread is only needed when the write is PARTIAL
         * and the untouched remainder has to be preserved.  Reno makes the
         * same split and it is the one real optimisation in this function. */
        if (n == FS_BLKSIZE) {
            bp = getblk(vp, bn);
        } else {
            error = bread(vp, bn, &bp);
            if (error) {
                brelse(bp);
                return (error);
            }
        }
        error = uiomove(&bp->b_addr[on], n, uio);
        /* A COMPLETED BLOCK GOES OUT NOW AND IS AGED; a partial one is left
         * dirty for the next writer to finish.  B_AGE says the buffer is least
         * useful to keep -- its bytes are on the disk and the writer has moved
         * on -- so it is the first the cache should recycle.  Neither arm
         * releases the buffer: bawrite and bdwrite own it from here. */
        if (n + on == FS_BLKSIZE) {
            bp->b_flags |= B_AGE;
            bawrite(bp);
        } else {
            bdwrite(bp);
        }
    } while (error == 0 && uio->uio_resid > 0 && n != 0);
    return (error);
}
