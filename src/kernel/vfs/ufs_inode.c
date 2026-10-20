/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno ufs/ufs_inode.c
 *   Ported from ufs/ufs_inode.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* ufs_inode.c -- the in-core inode.  UFS 1.11a.
 *
 * AN INODE IS A FILE'S IDENTITY AND A VNODE IS ITS HANDLE, and the whole of
 * this file is about keeping exactly one of the first for each of the second.
 * Two processes that open the same file must reach the same in-core inode, or
 * they get two link counts, two sizes, and two answers to "how big is it".
 *
 * WHERE IT LIVES.  Inside the vnode, not beside it.  1.1 sized `struct inode`
 * to fit VN_MAXPRIVATE -- the area a vnode lends its filesystem -- and
 * toolchain/tests/M37/vfslayout.c asserts the RELATIONSHIP rather than the
 * number, so adding a field here goes red rather than silently overflowing.
 * That is why there is no inode pool: getnewvnode allocates both at once.
 *
 * THE HASH IS RENO'S AND SO IS THE REASON FOR IT.  A vnode cannot be found by
 * (device, inode number) -- the vnode layer indexes nothing -- so iget keeps
 * its own table.  `i_chain[2]` has been the first field of `struct inode` since
 * 1.1 for exactly this: the hash walk casts the head to an inode and follows
 * the same two words.
 *
 * INOHSZ IS 16, WHERE RENO USES 512.  Reno sizes its table for a machine with
 * thousands of inodes in core; the ceiling here is the VNODE POOL, which is 32.
 * A 512-entry table would be 2 KB of module bank to hold at most 32 entries,
 * and the chains would be empty rather than short.  16 is the next power of two
 * below the ceiling, so the mask form of INOHASH still applies.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "mount.h"
#include "vfsops.h"
#include "ufs_fs.h"
#include "ufsmount.h"
#include "inode.h"

extern int          bread();
extern void         brelse();
extern int          getnewvnode();
extern int          vget();
extern void         vrele();
extern void         vref();
extern long         ufs_dget32();
extern void         ufs_dput32();
extern void         ufs_idecode();     /* both in ufs_sb.c since UFS 2.1 */
extern void         ufs_iencode();
extern int          bwrite();
extern struct buf  *getblk();
extern void         clrbuf();
extern int          ufs_ifmttovt();  /* ufs_vnops.c, in the other half */
extern void         vinvalbuf();
extern int          ufs_bfree();
extern int          ufs_bmapx();
extern void         kc_panic();
/* 1.12d.  iget waits on the inode lock without taking it (ufs_ihashget) and
 * holds it across its own read; the lock itself is ufs_vnops.c's, reached
 * through the ops vector like every other VOP_. */
extern void         kc_sleep();
extern int          kc_curpid();
extern struct vnode *checkalias();   /* vfs.mod, 1.13a */
extern void         iput();          /* defined below; iget's alias arm uses
                                      * it to discard the vnode it built */

/* ufs_panicino -- the twin of ufs_vnops.c's, and it is a twin rather than a
 * shared function because the two halves of UFS are two MODULES: reaching
 * across would be a new entry in an ABI for a debugging aid.  See there for
 * why the inode number is in the string at all. */
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
extern long         kern_time();


#define INOHSZ      16
#define INOHASH(dev, ino)   ((((int)(dev)) + ((int)(ino))) & (INOHSZ - 1))

/* THE HASH HEADS ARE FAKE INODES, which is Reno's trick and reads as a hack
 * until the alternative is written out.  A chain needs a head that can be
 * pointed AT by the first real entry's i_chain[1]; making the head a whole
 * inode would cost 16 of them, and making it a bare pointer means the insert
 * and remove need two cases instead of one.  Reno's `union ihead` overlays two
 * pointers on the front of an inode so the head IS a link cell.
 *
 * Here the same thing is spelled without the union, because fcc's union support
 * is not something this campaign wants to lean on: the table is an array of
 * two-pointer cells, and the cast at the use sites says what is happening. */
struct ihead {
    struct inode *ih_chain[2];
};

static struct ihead ihashtbl[INOHSZ];



/* ufs_ihashinit -- every chain empty means every chain points at itself.
 *
 * A CIRCULAR list, so "empty" is not a null pointer but a head whose forward
 * and back links are both the head.  That is what lets insert and remove run
 * without testing for the ends. */
void
ufs_ihashinit()
{
    int i;

    for (i = 0; i < INOHSZ; i++) {
        ihashtbl[i].ih_chain[0] = (struct inode *)&ihashtbl[i];
        ihashtbl[i].ih_chain[1] = (struct inode *)&ihashtbl[i];
    }
}


/* ufs_iflushall -- write back every in-core inode that is dirty.  UFS 2.6,
 * apple/fgx#332's second half.
 *
 * THIS IS `update()', AND IT WALKS THE HASH BECAUSE THE HASH IS WHAT THERE IS.
 * 2.11BSD's update walks the whole inode table (`for (ip = inode; ip <
 * inode+NINODE; ip++)') and 4.3BSD-Reno walks each mount's own vnode list
 * (`mp->mnt_mounth', ufs/ufs_vfsops.c:557).  This tree keeps neither -- it
 * keeps ufs_ihashtbl, sixteen circular chains that between them hold every
 * in-core inode, which is the same set reached a third way.
 *
 * WHY IT IS NEEDED AND WHY ufs_inactive IS NOT ENOUGH.  Every operation that
 * changes an inode without changing its SIZE marks it ICHG and leaves the
 * write to somebody else: rmdir decrementing the parent`s link count, rename
 * adjusting "..", chmod, chown, link.  The somebody else is ufs_inactive, and
 * inactive only runs when the last reference goes -- so an inode that stays
 * referenced, like the process`s own working directory, never reaches the
 * platter at all.  MEASURED: `mkdir d; rmdir d' in /tmp left /tmp with an
 * on-disk link count of 3 and two entries naming it, which fgxfs reported as
 * `inode 340: link count is 3 but 2 directory entries name it`.  It is the
 * same defect as the superblock`s and it needed the same answer.
 *
 * EVERY ERROR IS KEPT AND THE WALK DOES NOT STOP, which is upstream`s
 * `allerror` in both ancestors: one unwritable inode is not a reason to leave
 * the other fifteen chains dirty, and the caller gets the first failure.
 */
int
ufs_iflushall(waitfor)
int waitfor;
{
    struct ihead *hd;
    struct inode *ip;
    int           i;
    int           error;
    int           allerror;

    allerror = 0;
    for (i = 0; i < INOHSZ; i++) {
        hd = &ihashtbl[i];
        for (ip = hd->ih_chain[0]; ip != (struct inode *)hd;
             ip = ip->i_chain[0]) {
            if ((ip->i_flag & (IMOD | IACC | IUPD | ICHG)) == 0)
                continue;
            error = iupdat(ip, waitfor);
            if (error && allerror == 0)
                allerror = error;
        }
    }
    return (allerror);
}


/* ufs_idecode and ufs_iencode MOVED TO ufs_sb.c at UFS 2.1, and the move is
 * the on-target fsck's doing rather than a tidying.  That file's selection
 * rule -- "hand it a block of bytes and it tells you what the PDP-11 meant by
 * them" -- already described this codec exactly, and its no-outward-call
 * property is what lets a NON-KERNEL build compile it: src/userland/fsck
 * needs the same dinode field list the kernel uses, and the alternative was a
 * second copy of it.  This file's own comment on ufs_iencode says why that
 * would be a defect waiting to happen: "the two lists must stay identical".
 */


/* ufs_ifind -- is this inode in core?  LOOK, DO NOT TOUCH.
 *
 * 2.11BSD's `ifind` (usr/sys/sys/ufs_inode.c:70), and the no-reference part is
 * the whole of its purpose rather than an optimisation.  Its one upstream
 * caller is ialloc's i-list scan, which is asking "is this number already
 * spoken for by something that has not written it to disk yet" -- a question
 * about the TABLE, not a claim on the inode.  Taking a reference there would
 * pin an inode the allocator has no business holding, and the scan has nowhere
 * to release it.
 *
 * So this is the bare walk, and ufs_ihashget below is it plus the reference.
 * Upstream writes the walk out twice, once in `ifind` and once inlined in
 * `iget`; one copy is the same code and one fewer place to fix. */
struct inode *
ufs_ifind(dev, ino)
dev_t dev;
ino_t ino;
{
    struct ihead *ih;
    struct inode *ip;

    ih = &ihashtbl[INOHASH(dev, ino)];
    for (ip = ih->ih_chain[0];
         ip != (struct inode *)ih;
         ip = ip->i_chain[0]) {
        if (ip->i_number == ino && ip->i_dev == dev)
            return (ip);
    }
    return ((struct inode *)0);
}


/* ufs_ihashget -- is this inode already in core, and if so make it mine?
 *
 * Returns the inode with a REFERENCE TAKEN, or null.  Reno's iget does this
 * inline (ufs/ufs_inode.c:100-115) and this is that loop, written out.
 *
 * IT WAITS ON THE LOCK AND DOES NOT TAKE IT, and the split is worth being
 * exact about because upstream does both in one place.  Reno sleeps on ILOCKED
 * here and acquires the lock further down the same function; the wait is
 * factored out to this side of the seam and the acquisition stays in iget,
 * where the OTHER path -- the newly built inode -- also takes it.  One
 * acquisition site rather than two.
 *
 * WHY THE WAIT IS HERE AT ALL, rather than being left to iget's VOP_LOCK,
 * which would block on the same bit anyway: vget comes between them.  vget
 * resurrects an idle vnode and can sleep, and an inode that is ILOCKED may be
 * one whose dinode has not been read yet -- ILOCKED marks CONSTRUCTION as well
 * as ownership (see iget).  Waiting first is what keeps a half-built inode
 * from being pulled off the free list and handed a reference.
 *
 * The retry is a loop rather than Reno's `goto loop` into iget's body because
 * the walk is a function here; after a sleep the inode may have been recycled
 * entirely, so the search starts again from ufs_ifind. */
static struct inode *
ufs_ihashget(dev, ino)
dev_t dev;
ino_t ino;
{
    struct inode *ip;

    for (;;) {
        ip = ufs_ifind(dev, ino);
        if (ip == (struct inode *)0)
            return ((struct inode *)0);
        if ((ip->i_flag & ILOCKED) != 0) {
            /* THE SELF-DEADLOCK CHECK BELONGS HERE TOO, and upstream does not
             * have it.  Reno's iget sleeps on ILOCKED without asking whose
             * lock it is (ufs/ufs_inode.c:106-109) and only ilock, further
             * down, panics on "locking against myself" -- so a process that
             * igets an inode it already holds never reaches the check.  It
             * waits, on a channel only it could wake, forever.
             *
             * That is not a theoretical ordering.  It is what a caller
             * holding a vnode across a lookup that reaches the same vnode
             * does, and it cost this increment several on-target runs whose
             * only symptom was a machine that stopped.  A hang is a harness
             * timeout naming no function; the panic names the inode. */
            if (ip->i_lockholder == (short)kc_curpid())
                ufs_panicino("igetself", ino);
            ip->i_flag |= IWANT;
            kc_sleep((char *)ip);
            continue;
        }
        /* vget takes the reference and refuses a vnode that is being
         * reclaimed; a null return means "try again", and unlike the ILOCKED
         * arm above it is Reno's own `goto loop` for the same reason. */
        if (vget(ip->i_vnode) != 0)
            continue;
        return (ip);
    }
}


/* ufs_ihashins / ufs_ihashrem -- Reno's insque/remque, written out.
 *
 * fcc links no libc and the kernel has no insque, and open-coding four pointer
 * stores is clearer here than a general-purpose queue primitive would be:
 * these are the only two callers there will ever be. */
static void
ufs_ihashins(ip)
struct inode *ip;
{
    struct ihead *ih;
    struct inode *next;

    ih = &ihashtbl[INOHASH(ip->i_dev, ip->i_number)];
    next = ih->ih_chain[0];
    ip->i_chain[0] = next;
    ip->i_chain[1] = (struct inode *)ih;
    next->i_chain[1] = ip;
    ih->ih_chain[0] = ip;
}


void
ufs_ihashrem(ip)
struct inode *ip;
{
    struct inode *next;
    struct inode *prev;

    next = ip->i_chain[0];
    prev = ip->i_chain[1];
    prev->i_chain[0] = next;
    next->i_chain[1] = prev;
    ip->i_chain[0] = ip;
    ip->i_chain[1] = ip;
}


/* iget -- the in-core inode for (this mount, this number).
 *
 * THE MOUNT IS THE FIRST ARGUMENT WHERE RENO PASSES ANOTHER INODE.  Reno's
 * `iget(xp, ino, ipp)` takes any inode on the same filesystem and reaches
 * through it for the device and the mount -- which works because its callers
 * always have one to hand.  ufs_root does not: it is the first inode on the
 * filesystem, and there is nothing to reach through.  Reno gets away with that
 * because ufs_mountfs builds a fake inode for the purpose; passing the mount
 * says the same thing without the fake.
 *
 * Out: 0 and *ipp with a reference held AND THE INODE LOCKED, or an errno with
 * *ipp null.
 *
 * THE LOCKED RETURN IS UPSTREAM'S CONTRACT AND IS LIVE AS OF 1.12d: "in all
 * cases, a pointer to a locked inode structure is returned"
 * (ufs/ufs_inode.c:76-82).  It reads like a detail and is the hinge the whole
 * increment turns on, for two separate reasons:
 *
 *   THE READ BELOW HAPPENS ON THE CHAIN.  The inode goes onto its hash bucket
 *   before its dinode is read, deliberately (see below), so a second caller
 *   can find it while this one sleeps in bread.  ILOCKED is what tells that
 *   caller the fields are not filled in yet; without it the second caller gets
 *   a file with the previous tenant's mode and size and no way to tell.
 *
 *   AND IT IS WHAT MAKES iput MEAN SOMETHING.  iput unlocks and releases, so
 *   every `iget ... iput` pair in the tree is a lock held across the work
 *   between them -- which for the directory layer is exactly "read a block,
 *   change a slot, write it back".  The pairs were written that way from 1.11a
 *   on, against vnode-op slots that were still ufs_nullop; this is where they
 *   start being true.
 *
 * SO A CALLER THAT WANTS ONLY A REFERENCE MUST SAY SO.  ufs_checkpath walks
 * upward and reads one block per ancestor; it takes the lock like everything
 * else and gives it back with iput.  A caller that must NOT hold the lock --
 * there is none today -- would have to VOP_UNLOCK and release with vrele.
 */
/* ufs_setvnodeops -- the vnode-ops table, handed over at load time.
 *
 * THE TABLE IS IN THE OTHER HALF OF UFS.  iget is the only thing on this side
 * that needs it -- it is what getnewvnode stamps into v_op -- and taking its
 * address directly would be the one remaining reference from the block half to
 * the directory half, which is the whole of what a bank split has to remove.
 *
 * So the DIRECTORY module hands it over from its own mod_init, exactly as it
 * resolves everything else here, and iget refuses until it has: a null table
 * would be dispatched through on the first VOP_ call and the machine would
 * come apart a long way from the cause.  That is _Ufs_ResolveVfs's rule, in C.
 *
 * The pointer is far and stays far.  Its bank is the directory module's, which
 * is what makes cross-bank VOP_ dispatch work at all (apple/fgx#178).
 */
static struct vnodeops *ufs_ops;

void
ufs_setvnodeops(v)
struct vnodeops *v;
{
    ufs_ops = v;
}


/* ufs_setspecops -- the OTHER vnode-ops table, for device files.  UFS 1.13a.
 *
 * A DEVICE FILE HAS AN INODE AND A DEVICE, AND NO ONE VECTOR SERVES BOTH.  Its
 * mode, owner and timestamps are the filesystem's and its read, write and
 * ioctl are the driver's -- so 4.3BSD-Reno gives it a third table,
 * spec_inodeops (ufs/ufs_vnops.c:125), whose device half is spec_* and whose
 * inode half is ufs_*.  Wearing plain spec_vnodeops instead is not a lesser
 * version of that, it is broken in a way this tree has already paid for:
 * spec_vnodeops has spec_nullop in its RECLAIM slot, and a nullop reclaim
 * leaves the inode on its hash bucket when the vnode is recycled, which is
 * apple/fgx#175 exactly.  Its getattr is spec_ebadf, so `ls -l /dev` would
 * fail on every entry.
 *
 * Handed over from the directory module's mod_init for the same reason
 * ufs_ops is, and iget refuses a device inode until it has one. */
static struct vnodeops *ufs_specops;

void
ufs_setspecops(v)
struct vnodeops *v;
{
    ufs_specops = v;
}


/* ufs_getrdev / ufs_setrdev -- the device number of a special file.
 *
 * THE LOW 16 BITS OF di_addr[0], and inode.h carries the whole derivation from
 * the two upstream sources.  These exist as functions rather than as Reno's
 * `#define i_rdev i_din.di_db[0]` because here it is half of a long, so there
 * is no lvalue to alias -- and because two functions are two places to put the
 * format argument rather than none. */
dev_t
ufs_getrdev(ip)
struct inode *ip;
{
    return ((dev_t)(ip->i_din.di_addr[0] & 0xFFFFL));
}

void
ufs_setrdev(ip, dev)
struct inode *ip;
dev_t         dev;
{
    /* THE HIGH WORD GOES TO ZERO EXPLICITLY.  It is 2.11BSD's i_dummy, and
     * mknod sets it to zero there in the same breath as the device number
     * (usr/sys/sys/ufs_syscalls.c:229) -- because the slot may have held a
     * block address a moment ago and half of one is not a device. */
    ip->i_din.di_addr[0] = (long)((unsigned long)dev & 0xFFFFL);
}


int
iget(mp, ino, ipp)
struct mount  *mp;
ino_t          ino;
struct inode **ipp;
{
    struct ufsmount *ump;
    struct inode    *ip;
    struct inode    *iq;
    struct vnode    *nvp;
    struct vnode    *avp;
    struct buf      *bp;
    daddr_t          blk;
    int              error;

    ump = VFSTOUFS(mp);
    *ipp = (struct inode *)0;

    /* Already in core?  Then this is the whole of the work, and it is the case
     * that matters: two opens of one file MUST reach one inode. */
    ip = ufs_ihashget(ump->um_dev, ino);
    if (ip != (struct inode *)0) {
        VOP_LOCK(ITOV(ip));
        *ipp = ip;
        return (0);
    }

    /* BOTH TABLES, because the mode that picks one is not read yet.  Reno
     * needs no guard -- ufs_vnodeops and spec_inodeops are its own statics --
     * but here both come from the directory half's mod_init, and a device
     * inode minted before spec_inodeops arrives would carry a null v_op onto
     * the alias chain looking fully built (apple/fgx#466). */
    if (ufs_ops == (struct vnodeops *)0 || ufs_specops == (struct vnodeops *)0)
        return (ENXIO);         /* the directory half never loaded */
    error = getnewvnode(VT_UFS, mp, ufs_ops, &nvp);
    if (error)
        return (error);

    ip = VTOI(nvp);
    ip->i_vnode  = nvp;
    /* HOLD A REFERENCE ON THE DEVICE VNODE, and drop it in ufs_reclaim.  Reno
     * pairs the two lines -- `ip->i_devvp = VFSTOUFS(mntp)->um_devvp; VREF(
     * ip->i_devvp);` (vendor/4.3BSD-Reno/ufs/ufs_inode.c:212-213) against
     * `if (ip->i_devvp) { vrele(ip->i_devvp); ip->i_devvp = 0; }` (:307-310) --
     * and the reason is the lifetime, not the bookkeeping: an inode outlives
     * its iput, staying hashed until its vnode is recycled, so between those
     * moments a bare pointer here would name a device vnode nobody is keeping
     * alive.  1.12 writes through exactly that pointer.
     *
     * THIS WAS BACKED OUT ONCE (apple/fgx#175) after the vref alone hung the
     * probe.  It was not the vref: the reclaim slot was `ufs_nullop` at the
     * time, so the inode hash rotted on the first recycle and the extra
     * reference only changed which handout tripped the resulting endless chain
     * walk.  With the real ufs_reclaim in place (8d099558e) the pair is green,
     * and the probe's case 752 holds it so -- see there. */
    ip->i_devvp  = ump->um_devvp;
    vref(ip->i_devvp);
    ip->i_dev    = ump->um_dev;
    ip->i_number = ino;
    ip->i_flag   = 0;
    ip->i_diroff = 0L;
    ip->i_endoff = 0L;
    ip->i_fs     = (struct fs *)ump;

    /* THE ROOT OF ITS FILESYSTEM SAYS SO, and where this line goes is the
     * whole of what it is worth reading about.  Reno sets it HERE, in iget --
     * `if (ino == ROOTINO) vp->v_flag |= VROOT;' (4.3BSD-Reno
     * ufs/ufs_inode.c:206-207) -- and not in ufs_root, which is the obvious
     * place and is wrong.  ufs_root is only ONE of the ways a root vnode is
     * minted: a `..' walk that lands on inode 2, or any lookup that reaches
     * it, comes through here too, and would hand back a root with the flag
     * clear.
     *
     * BOTH READERS TEST EXACTLY THIS BIT.  lookup's `..' arm ascends through
     * `mnt_vnodecovered' only when VROOT is set, and unmount(2) refuses any
     * vnode without it -- so a root that forgot to say so is a mount you can
     * walk out of the wrong way and cannot detach.  UFS 1.8b-3.
     *
     * The vnode, not the inode: this is a vnode flag and `nvp' is the vnode
     * getnewvnode just minted for it. */
    if (ino == (ino_t)UFS_ROOTINO)
        nvp->v_flag |= VROOT;

    /* ON THE CHAIN BEFORE THE READ, which is Reno's order and not an accident:
     * the read can sleep, and a second caller arriving during it must find this
     * inode rather than start a second one.  Nothing sleeps here yet -- see
     * ufs_ihashget -- but the order costs nothing and is the one that survives
     * 1.12. */
    ufs_ihashins(ip);

    /* AND LOCKED BEFORE THE READ, which is the other half of that order and is
     * Reno's `insque(ip, ih); ILOCK(ip);` (ufs/ufs_inode.c:141-142).  The
     * chain entry says "this inode number is spoken for"; the lock says "and
     * it is not filled in yet".  Without the second one a finder arriving
     * during the bread below gets a struct full of the previous tenant's
     * fields and no way to tell. */
    VOP_LOCK(nvp);

    /* itod gives the i-list block, itoo the slot within it. */
    blk = itod(ino);
    error = bread(ump->um_devvp, blk, &bp);
    if (error) {
        brelse(bp);
        /* THE INODE CONTAINS NOTHING USEFUL, so leaving it on the chain would
         * be worse than not having it: the next lookup would find it and
         * believe it.  Reno says the same thing in the same place.
         *
         * OFF THE CHAIN FIRST, THEN UNLOCK.  The unlock is what wakes anyone
         * who found this entry and slept on it; waking them while it is still
         * on the chain would hand them the very inode this arm has just
         * decided is unusable. */
        ufs_ihashrem(ip);
        VOP_UNLOCK(nvp);
        vrele(nvp);
        return (error);
    }
    ufs_idecode(bp->b_addr + itoo(ino) * UFS_DINODESIZE, &ip->i_din);
    brelse(bp);

    /* THE VNODE'S TYPE COMES FROM THE INODE'S MODE, and this is the seam
     * between the filesystem and the VFS: everything above works in vnode
     * types, everything below in 2.11BSD mode bits. */
    nvp->v_type = ufs_ifmttovt(ip->i_din.di_icom1.ic_mode);

    /* ---- A DEVICE FILE IS TWO THINGS AT ONCE (UFS 1.13a) ---------------
     *
     * 4.3BSD-Reno ufs/ufs_inode.c:183-207.  An inode whose mode says IFCHR or
     * IFBLK names a DRIVER, and from here on the vnode has to answer for the
     * driver as well as for the inode -- so it wears spec_inodeops instead of
     * the ordinary table (see ufs_setspecops above for why a third table and
     * not spec_vnodeops), and it joins the device alias chain.
     *
     * WHAT checkalias IS FOR, in one sentence: two names for one device must
     * reach ONE vnode, or the driver's last close arrives while another path
     * still has it open.  /dev/tty and /dev/console can be the same device,
     * and a block device already open through bdevvp -- which is how the root
     * disk is opened before anything is mounted -- must not become a second,
     * independent handle the moment /dev appears and someone opens it by name.
     *
     * THE SECOND RETURN IS THE INTERESTING ONE.  A non-null answer means an
     * older vnode already speaks for this device and is the one to keep; this
     * inode's CONTENTS move into it and the vnode built above is discarded.
     * Reno's comment calls it "reinitialize aliased inode".
     */
    if (nvp->v_type == VCHR || nvp->v_type == VBLK) {
        nvp->v_op = ufs_specops;
        avp = checkalias(nvp, ufs_getrdev(ip), mp);
        if (avp != (struct vnode *)0) {
            iq = VTOI(avp);
            iq->i_vnode  = avp;
            iq->i_flag   = 0;
            /* LOCKED, because it is about to be handed out as this call's
             * result and iget's contract is that it is locked.  Reno's
             * ILOCK(iq) in the same place. */
            VOP_LOCK(avp);
            /* THE WHOLE dinode, which is the on-disk format moving from the
             * vnode being discarded into the one being kept.  It is the first
             * whole-struct assignment in this tree; toolchain/tests/M37/
             * structassign.c pins the construct on the machine, because a
             * word-copy loop that got the last word wrong would show up here
             * as a device file with the wrong mode and nothing to suspect. */
            iq->i_din    = ip->i_din;
            iq->i_dev    = ip->i_dev;
            iq->i_number = ino;
            iq->i_fs     = ip->i_fs;
            iq->i_diroff = 0L;
            iq->i_endoff = 0L;
            /* ITS OWN REFERENCE ON THE DEVICE VNODE.  ufs_reclaim drops one
             * per inode, so the kept inode needs one of its own rather than
             * inheriting the discarded inode's -- which iput below is about to
             * give back. */
            iq->i_devvp  = ump->um_devvp;
            vref(iq->i_devvp);
            ufs_ihashins(iq);
            /* AND THE DISCARDED ONE GOES, mode first.  A zero mode is what
             * makes ufs_inactive vgone it on the spot instead of writing it
             * back -- it describes an inode that is about to be described by
             * somebody else, and writing it would put a zeroed dinode on the
             * platter over a live device file. */
            ip->i_mode = 0;
            iput(ip);
            ip = iq;
        }
    }

    /* AND IT GOES BACK STILL LOCKED, which is the header's contract: the lock
     * taken above to cover the read is the same one the caller is owed.  There
     * is no moment between them when another process could find this inode
     * half-built. */
    *ipp = ip;
    return (0);
}


/* ufs_itimes -- turn the dirty-stamp flags into timestamps.  apple/fgx#167.
 *
 * 4.3BSD-Reno's ITIMES (ufs/inode.h:136-146), which is a macro there because
 * it reads the kernel's `time` global and a macro costs nothing:
 *
 *     if ((ip)->i_flag&(IUPD|IACC|ICHG)) {
 *         (ip)->i_flag |= IMOD;
 *         if ((ip)->i_flag&IACC) (ip)->i_atime = (t1)->tv_sec;
 *         if ((ip)->i_flag&IUPD) (ip)->i_mtime = (t2)->tv_sec;
 *         if ((ip)->i_flag&ICHG) (ip)->i_ctime = time.tv_sec;
 *         (ip)->i_flag &= ~(IACC|IUPD|ICHG);
 *     }
 *
 * A FUNCTION HERE, AND THE GUARD IS THE REASON.  There is no `time` global to
 * read (kern_time.c says why), so the source is a ROM excursion.  Reno's own
 * flag test therefore stops being a micro-optimisation and becomes the thing
 * that keeps a stat(2) of a file nobody has touched from reaching the Toolbox
 * at all -- so it must run BEFORE the clock is read, which a macro taking
 * `&time` cannot express.
 *
 * ONE READ FOR ALL THREE, where Reno reads `t1`, `t2` and `time` separately.
 * Upstream passes distinct times because `iupdat` can be called with an access
 * time that is not now (it takes t1/t2 as arguments for exactly that); every
 * caller in this port passes "now" three times, and one excursion is both
 * cheaper and more truthful -- three reads a few hundred microseconds apart
 * would stamp a file's atime and mtime with different seconds for no reason.
 *
 * A CLOCK THAT CANNOT BE READ LEAVES THE STAMPS ALONE.  kern_time returns 0
 * for an unset or impossible RTC, and writing that would date every file to
 * 1970 -- worse than the platter's own value, which at least came from a
 * machine that knew what time it was.  The flags stay dirty so a later call
 * with a working clock still has the work to do.
 */
void
ufs_itimes(ip)
struct inode *ip;
{
    long now;

    if ((ip->i_flag & (IUPD | IACC | ICHG)) == 0)
        return;
    now = kern_time();
    if (now == 0L)
        return;
    ip->i_flag |= IMOD;
    if (ip->i_flag & IACC)
        ip->i_atime = now;
    if (ip->i_flag & IUPD)
        ip->i_mtime = now;
    if (ip->i_flag & ICHG)
        ip->i_ctime = now;
    ip->i_flag &= ~(IACC | IUPD | ICHG);
}


/* iupdat -- write the in-core inode back to its slot in the i-list.  UFS 1.12a.
 *
 * 2.11BSD usr/sys/sys/ufs_inode.c `iupdat`, and 4.3BSD-Reno ufs/ufs_inode.c:330.
 * The two agree on the shape; the deltas below are all this port's.
 *
 * NO ta/tm ARGUMENTS.  Both originals take an access time and a modify time so
 * a caller can update an inode with a stamp that is not now, and every caller
 * in both trees passes `&time, &time` anyway.  ufs_itimes above already owns
 * that half here and reads the clock ONCE for all three stamps -- its header
 * says why -- so this calls it and takes no times.  A caller that genuinely
 * needs a chosen timestamp writes the field and sets the flag itself, which is
 * what utimes(2) does upstream.
 *
 * IT CONSULTS sb_ronly, THE ON-DISK FLAG, WHICH IS 2.11BSD'S CHOICE OF THE TWO
 * UPSTREAM MAKES.  Reno guards with the mount flag -- `if (vp->v_mount
 * ->mnt_flag & MNT_RDONLY) return (0);` -- and 2.11BSD with the volume's own
 * -- `if (tip->i_fs->fs_ronly) return;`.  They are different questions: the
 * mount flag says how this mount was asked for, sb_ronly says what the volume
 * itself is, and a volume whose superblock says read-only must not be written
 * through however it was mounted.
 *
 * THE MOUNT FLAG IS REAL NOW, so the second half of the guard is no longer
 * blocked: ufs_mountfs stopped forcing MNT_RDONLY when the 1.12 write path
 * landed, vfs_syscalls.c sets it from what the mount(2) caller asked for, and
 * namei carries both of Reno's EROFS gates -- so Reno's line would mean what
 * it says here.  Checking both is what this should do; it checks the on-disk
 * flag alone, which is the narrower half.
 *
 * WHAT IT COSTS IS A FAILURE THAT LOOKS LIKE A PASS, which is why it is worth
 * a paragraph: a write that never reaches the platter corrupts nothing, leaves
 * fsck clean, and passes every test that asks whether the volume survived.
 * Only a test that reads the bytes BACK can tell the two apart, and the
 * probe's 1.12a section is built that way for exactly that reason.
 *
 * IT WRITES SYNCHRONOUSLY.  Upstream chooses on `waitfor` between bwrite and
 * bdwrite; ufs.mod imports four buffer-cache entries from vfs.mod -- bread,
 * bwrite, brelse and getblk (src/modules/ufs/vfs_import.s) -- and bdwrite is
 * not among them.  The parameter is carried because callers upstream pass it
 * and 1.12b/1.12c will want the distinction, but today both arms are bwrite.
 * ponytail: synchronous always; import bdwrite when a measurement says the
 * inode write-back is what costs, not before.
 *
 * Returns 0 when there was nothing to do, which is upstream's answer too.
 */
int
iupdat(ip, waitfor)
struct inode *ip;
int           waitfor;
{
    struct ufsmount *ump;
    struct buf      *bp;
    int              error;

    /* THE STAMPS FIRST, because ufs_itimes is what turns IACC/IUPD/ICHG into
     * IMOD.  Reno does the same work inline between its two guards; splitting
     * it out is #167's arrangement, not a reordering.
     *
     * THE GUARD TESTS ALL FOUR FLAGS, WHICH IS UPSTREAM'S TEST AND NOT A
     * TIDIER SPELLING OF "IMOD".  2.11BSD writes
     * `if ((tip->i_flag & (IUPD|IACC|ICHG|IMOD)) == 0) return;` and Reno's is
     * the same four (ufs/ufs_inode.c:341).  Testing IMOD alone is wrong HERE
     * in a way it is not upstream, because ufs_itimes can decline to set it:
     * when kern_time() cannot read the clock it returns 0 and ufs_itimes
     * leaves the stamps and the flags alone deliberately -- its own header
     * says why, and says the flags stay dirty so a later call still has the
     * work to do.
     *
     * So on a machine whose RTC is unset, an IMOD-only guard would see a clean
     * inode, return 0, and write NOTHING -- while ufs_write had already taken
     * blocks off the free list and marked IUPD|ICHG.  The volume would carry
     * blocks owned by an on-disk inode that still says size zero, which is
     * what fsck calls unreferenced.  A dead clock is not an exotic state; it
     * is a machine nobody has set the time on.
     *
     * NOT PROBE-COVERED, and stated rather than implied: the probe runs under
     * an emulator whose clock always reads, so ufs_itimes always sets IMOD and
     * the two guards agree on every case the probe can reach.  This one is
     * held by the upstream text, not by a red arm. */
    ufs_itimes(ip);
    if ((ip->i_flag & (IUPD | IACC | ICHG | IMOD)) == 0)
        return (0);

    ump = ITOUMP(ip);
    if (ump->um_sb.sb_ronly)
        return (0);

    error = bread(ip->i_devvp, itod(ip->i_number), &bp);
    if (error) {
        brelse(bp);
        return (error);
    }

    /* CLEAR ALL FOUR BEFORE THE WRITE, which is upstream's line
     * (`tip->i_flag &= ~(IUPD|IACC|ICHG|IMOD)`) and upstream's order.  All
     * four, because the dead-clock path above can arrive here with IUPD or
     * ICHG still set -- ufs_itimes only clears them when it has a time to put
     * in their place -- and leaving them would make every later iupdat rewrite
     * an inode nothing had changed.
     *
     * BEFORE the write, because the write can fail; leaving the flags set on a
     * failure would mean the next iupdat rewrites bytes the disk already
     * refused, and the error is returned to a caller that can act on it. */
    ip->i_flag &= ~(IUPD | IACC | ICHG | IMOD);
    ufs_iencode(&ip->i_din, bp->b_addr + itoo(ip->i_number) * UFS_DINODESIZE);

    /* bwrite RELEASES THE BUFFER either way, including on error -- vfs_bio.c
     * says so at its head -- so there is no brelse on this path. */
    return (bwrite(bp));
}


/* ufs_reclaim -- this vnode is being taken away; let go of everything.
 *
 * 4.3BSD-Reno ufs/ufs_inode.c:288-317.  THE FIRST LINE IS THE WHOLE REASON IT
 * EXISTS, and upstream says so in a comment of its own: "Remove the inode from
 * its hash chain."
 *
 * WITHOUT IT THE HASH ROTS ON THE FIRST RECYCLE, which is how this port shipped
 * 1.11a for a few hours.  The reclaim slot was `ufs_nullop`, and the path that
 * needs it is not exotic: getnewvnode takes the free-list head and, if it still
 * belongs to a filesystem, calls vgone -> vclean -> the vnode's OWN reclaim
 * (vfs_subr.c, through `origops` saved before the vector is swapped for
 * dead_vnodeops).  A nullop there leaves the inode on its old bucket; iget then
 * fills the same memory with a different (dev, ino) and ufs_ihashins re-points
 * its links WITHOUT unlinking the old ones -- so the old bucket's neighbours
 * still point into it, a walk crosses from one chain into another and never
 * meets its head sentinel, and ufs_ihashget/ufs_ifind spin forever.  Before
 * that it is quieter and worse: ufs_ifind answers about a file that no longer
 * exists, which is precisely what ufs_ialloc's guards trust (apple/fgx#168).
 *
 * Latent only because the vnode pool has to wrap first.  1.11b's per-open iget
 * makes it routine.
 *
 * THE devvp RELEASE IS RENO'S (:307-310) AND IS THE OTHER HALF OF iget's VREF
 * (:212-213).  Neither half means anything alone: without the vref this would
 * hand back a reference nobody took and drive the device vnode's usecount
 * through zero; without this release every inode ever brought into core would
 * leak one, and the pool recycles, so the count would climb without bound.
 * The probe's case 752 measures exactly that -- see ufs_probe.c.  Both halves
 * were backed out once and are back together; apple/fgx#175 has the history.
 *
 * TWO DELTAS FROM UPSTREAM, both because the work is done elsewhere here:
 *
 *   cache_purge is Reno's line and is NOT repeated, because FGX's getnewvnode
 *   already calls it on every handout, AFTER the vgone that brings us here --
 *   see vfs_subr.c's "THE MINT IS cache_purge's".  Calling it twice would be
 *   harmless and misleading about who owns the invariant.
 *
 *   i_dquot is a campaign non-goal, so the quota release loop is absent for the
 *   reason inode.h drops the field.
 *
 * Returns 0.  A non-zero return makes vclean panic ("cannot reclaim"), which is
 * the right shape: a filesystem that cannot release its private area has lost
 * track of it.
 */
/* ufs_fsyncvp -- dispatch VOP_FSYNC for one vnode.  fsync(2)'s last hop.
 * apple/fgx#355.
 *
 * IT IS A DISPATCH AND NOTHING ELSE.  The work is `ufs_fsync'
 * (ufs_vnops.c:673, from 4.3BSD-Reno ufs/ufs_vnops.c:791) and the descriptor
 * checks are `root_fsync's, in the far bank where the file table is.
 * `ufs_fsync' is in ufsdir.mod, whose VTDR is deliberately EMPTY -- that
 * module's own header says "nothing calls into this module", and giving it an
 * export would undo the seam it was split to create -- so the far bank reaches
 * it through this entry.
 *
 * THIS MODULE already dispatches through the same table: `iget' and
 * `ufs_ihashget' above dispatch VOP_LOCK and VOP_UNLOCK through it, and the
 * note at `ufs_setvnodeops' explains why that works -- the pointer is far and
 * stays far, its bank being the directory module's.
 *
 * MNT_WAIT, not MNT_NOWAIT.  sync(2) sweeps every mount and does not wait;
 * a caller who named one descriptor is asking to be told when it is down.
 * `cred' is null here as it is at every other FGX VOP call site.
 */
int
ufs_fsyncvp(vp, fflags)
struct vnode *vp;
int           fflags;
{
    return (VOP_FSYNC(vp, fflags, (char *)0, MNT_WAIT));
}


int
ufs_reclaim(vp)
struct vnode *vp;
{
    struct inode *ip;

    ip = VTOI(vp);
    ufs_ihashrem(ip);
    if (ip->i_devvp) {
        vrele(ip->i_devvp);
        ip->i_devvp = (struct vnode *)0;
    }
    ip->i_flag = 0;
    return (0);
}


/* SINGLE, DOUBLE, TRIPLE -- the indirect levels, by the names both upstreams
 * use (Reno ufs/ufs_inode.c:415-417).  They index i_addr's indirect half, so
 * i_addr[NDADDR + level] is Reno's i_ib[level]. */
#define SINGLE          0
#define DOUBLE          1
#define TRIPLE          2


/* THE INDIRECT-BLOCK COPY, ONE PER LEVEL.  UFS 1.12b.
 *
 * indirtrunc below has to zero an indirect block's tail and write it to the
 * platter BEFORE it frees the blocks that tail named -- otherwise a crash
 * between the two leaves the volume with blocks that are on the free list AND
 * reachable from a file, which is the one kind of damage fsck cannot repair
 * without choosing. So it needs a private copy of the entries to walk while
 * the buffer it came from goes back out zeroed.
 *
 * NEITHER UPSTREAM'S ANSWER IS AVAILABLE HERE.  Reno MALLOCs fs_bsize bytes
 * from M_TEMP; 2.11BSD takes a whole spare buffer with geteblk().  Kernel C
 * has no allocator at all -- every VFS pool is carved by assembly and handed
 * to C -- and this port's vfs_bio has no geteblk.
 *
 * A FIXED TABLE IS AVAILABLE, and it is affordable precisely because the
 * recursion depth is not a variable: a 2.11BSD inode has exactly NIADDR
 * indirect levels, so indirtrunc is called at most NIADDR deep and `level`
 * indexes a slot that no other frame on the stack can be using.  Three
 * kilobytes of module BSS against a bank with thirty-two free.
 *
 * THAT LAST NUMBER WENT TO FIVE AND CAME BACK.  At 1.12c the directory layer
 * took ufs.mod to 60,211 bytes of 65,536 and this table was 3,072 of the
 * 5,325 that were left -- the largest single thing in the bank that was not
 * code.  The bank SPLIT is what restored the sentence above.
 *
 * MOVING IT OFF-BANK IS AVAILABLE AND WAS DEFERRED, NOT BLOCKED, and an
 * earlier version of this comment had that wrong: it claimed a module cannot
 * reach the kernel heap.  It can.  KSVC_KMALLOC is the first service in the
 * list (include/modules.s), and vfs.mod has been using it since 1.6a --
 * _Vfs_PoolInit allocates the whole vnode pool that way from its own mod_init,
 * checks the result does not straddle a bank, and hands (offset, bank) into C
 * as a far pointer.  ufs.mod's mod_init could do the same for this table in
 * about twenty lines, and the only thing genuinely missing is a C-CALLABLE
 * shim: the call is made in assembly at init and the pointer passed in, which
 * is all vfs.mod needs and all this would need.
 *
 * BOTH VENDORS ALLOCATE IT RATHER THAN CARRY IT.  2.11BSD takes a geteblk
 * buffer (usr/sys/sys/ufs_inode.c:639, `cpy = geteblk()`), Reno mallocs
 * (ufs/ufs_inode.c:604, `MALLOC(copy, daddr_t *, fs->fs_bsize, M_TEMP,
 * M_WAITOK)`).  Neither spends image on it, because on a PDP-11 the image is
 * the scarce thing -- which is the same reason this file cares.
 *
 * So: three kilobytes against thirty-two thousand free is not worth a change
 * today, and that is the whole of the argument.  When it is, _Vfs_PoolInit is
 * the pattern to copy.
 *
 * (2.11BSD's own comment at the same spot is worth keeping in mind: it splits
 * `trsingle` out of indirtrunc because the copy "requires 1K of kernel stack
 * to get around the problem and that doesn't work well with recursion". The
 * problem is the same one; a static table is the answer a fixed depth allows.)
 */
static daddr_t indircopy[NIADDR][NINDIR];


/* ufs_indirtrunc -- free the blocks an indirect block names, from the end back
 * to lastbn.  UFS 1.12b.
 *
 * 4.3BSD-Reno ufs/ufs_inode.c's indirtrunc for the SHAPE (an errno return, the
 * released count through a pointer) and 2.11BSD usr/sys/sys/ufs_inode.c's for
 * the arithmetic, which is the same split ufs_bmap.c already documents: the
 * level factor is NINDIR to a power and 2.11BSD reaches it with a switch on
 * level rather than Reno's `for (i = SINGLE; i < level; i++) factor *= NINDIR`,
 * which on fcc is a 32-bit multiply per level per call.
 *
 * THE ORDER IS THE WHOLE ALGORITHM, and it is upstream's comment verbatim
 * because there is no better way to say it: "Get buffer of block pointers,
 * zero those entries corresponding to blocks to be free'd, and update on disk
 * copy first."  Zero-then-write-then-free means a crash in the middle loses
 * blocks to the free list's accounting -- which fsck repairs silently -- where
 * free-then-zero would leave a file pointing at blocks somebody else owns,
 * which it cannot.
 *
 * IT IS RECURSIVE, on a 512-byte per-task kernel stack, and that is a
 * deliberate risk rather than an oversight.  Depth is bounded at NIADDR = 3 by
 * the format, the copy is out of frame (see indircopy above), and the locals
 * are the smallest set that works.  The probe's stack instrument is what says
 * whether that was affordable: `probe: stack reached ktasks+NNNN` moves when
 * this runs, and if it ever stops fitting the answer is 2.11BSD's -- split the
 * SINGLE level out into a non-recursive routine, which is exactly why upstream
 * has trsingle.
 *
 * In:  bn = the indirect block; lastbn = the last logical block to KEEP,
 *      relative to this subtree, or -1 to free the lot; level = SINGLE/DOUBLE/
 *      TRIPLE.
 * Out: errno; *countp = blocks released, counted in FILESYSTEM blocks where
 *      Reno counts device blocks (`nblocks = btodb(fs->fs_bsize)`).  Nothing
 *      in this port consumes it the way upstream does -- there is no i_blocks
 *      in a 2.11BSD dinode and no quota system -- so it exists for the PROBE,
 *      which can then assert that truncating a file of a known size released
 *      the number of blocks that file was known to occupy.  A reclaim that
 *      quietly frees too few is otherwise invisible until the volume fills.
 */
static int
ufs_indirtrunc(ip, bn, lastbn, level, countp)
struct inode *ip;
daddr_t       bn;
daddr_t       lastbn;
int           level;
long         *countp;
{
    struct ufsmount *ump;
    struct buf      *bp;
    daddr_t         *cp;
    daddr_t          nb;
    daddr_t          last;
    long             factor;
    long             blkcount;
    long             released;
    int              i;
    int              error;
    int              allerror;

    *countp  = 0L;
    released = 0L;
    allerror = 0;
    ump = ITOUMP(ip);

    /* The index in THIS block of the last entry to keep.  -1 means the whole
     * block goes, and the division is skipped rather than done on -1. */
    if (level == SINGLE)
        factor = 1L;
    else if (level == DOUBLE)
        factor = (long)NINDIR;
    else
        factor = (long)NINDIR * (long)NINDIR;
    last = lastbn;
    if (lastbn > (daddr_t)0)
        last = lastbn / (daddr_t)factor;

    error = bread(ip->i_devvp, bn, &bp);
    if (error) {
        brelse(bp);
        return (error);
    }

    /* COPY OUT, THEN ZERO THE TAIL, THEN WRITE.  The entries are PDP-11 longs
     * on the platter, so the copy decodes and the zeroing writes zeroes --
     * which need no encoding, but go through ufs_dput32 anyway so that every
     * on-disk long in this port has exactly one writer. */
    cp = indircopy[level];
    for (i = 0; i < NINDIR; i++)
        cp[i] = ufs_dget32(bp->b_addr, i * 4);
    for (i = (int)last + 1; i < NINDIR; i++)
        ufs_dput32(bp->b_addr, i * 4, (daddr_t)0);
    error = bwrite(bp);
    if (error)
        allerror = error;

    /* Whole subtrees, from the end back.  LIFO is upstream's order and it is
     * the one that keeps the free list's rotational pattern going backwards
     * the way mkfs built it. */
    for (i = NINDIR - 1; i > (int)last; i--) {
        nb = cp[i];
        if (nb == (daddr_t)0)
            continue;
        if (level > SINGLE) {
            error = ufs_indirtrunc(ip, nb, (daddr_t)-1, level - 1, &blkcount);
            if (error)
                allerror = error;
            released += blkcount;
        }
        error = ufs_bfree(ip->i_devvp, &ump->um_sb, nb);
        if (error)
            allerror = error;
        else
            released += 1L;
    }

    /* And the one partial subtree at the boundary, which keeps its head. */
    if (level > SINGLE && lastbn >= (daddr_t)0) {
        /* `i` IS THE INDEX, not a recomputation of it: the loop above exits
         * with i == last, which is upstream's `nb = bap[i]` after the same
         * loop.  Recomputing lastbn/factor here would be the same number and a
         * second place for it to be wrong. */
        last = lastbn % (daddr_t)factor;
        nb = cp[i];
        if (nb != (daddr_t)0) {
            error = ufs_indirtrunc(ip, nb, last, level - 1, &blkcount);
            if (error)
                allerror = error;
            released += blkcount;
        }
    }

    *countp = released;
    return (allerror);
}


/* ufs_itrunc -- shorten a file to `length` and give its blocks back.  1.12b.
 *
 * 4.3BSD-Reno ufs/ufs_inode.c:378 for the shape and the ORDER, 2.11BSD
 * usr/sys/sys/ufs_inode.c's itrunc for what a volume without fragments needs.
 * Reno's last section -- "look for a change in size of the last direct block;
 * release any frags" -- has no counterpart at all here and is absent for that
 * reason, not deferred.
 *
 * THE ORDER IS THE CRASH-SAFETY ARGUMENT, and it is upstream's comment: the
 * inode is written to the platter with its new size and its dropped addresses
 * ALREADY ZEROED, and only then are the blocks freed.  A crash in between
 * leaves blocks that belong to nobody, which fsck reclaims; the reverse order
 * leaves blocks that belong to two files, which it cannot.  That is why the
 * old addresses are copied out first: the freeing walk needs them after the
 * live inode has been cleaned.
 *
 * GROWING IS RENO'S BEHAVIOUR, NOT 2.11BSD'S, and this is a real divergence.
 * 2.11BSD's itrunc extends a file by bmap'ing the last block with B_WRITE, so
 * ftruncate-to-larger ALLOCATES; Reno returns early on `i_size <= length` and
 * simply records the size, leaving a hole.  Both satisfy POSIX -- the extended
 * region reads as zeroes either way -- and Reno's costs no blocks, needs no
 * error path, and is what ufs_read already implements for a hole.  Taken
 * deliberately; the campaign's stated VFS source is Reno and this is the VFS's
 * side of the seam.
 *
 * vinvalbuf IS RENO'S LINE AND IS LOAD-BEARING HERE.  The buffer cache is keyed
 * by (vnode, LOGICAL block), so after this returns, the cache can still hold
 * buffers for logical blocks whose physical blocks are now on the free list.
 * They are clean -- everything in this port writes synchronously -- so they
 * cannot corrupt anything by being written back.  They corrupt by being READ:
 * a truncate followed by a re-growth calls getblk for the same logical number,
 * finds the stale buffer with B_DONE set, and returns the previous contents of
 * a block that now belongs to another file.  That is what made 1.12b add
 * VFSCORE_Vinvalbuf to the module ABI (include/modules.s).
 *
 * WHAT IS ABSENT: i_blocks (a 2.11BSD dinode has no such field, so there is
 * nothing to decrement), quotas (a campaign non-goal), and Reno's DIAGNOSTIC
 * paranoia loops -- which check this function for a bug using a copy this
 * function made, and would catch nothing the probe's block-count assertion
 * does not.
 *
 * In:  length in bytes; flags carries IO_SYNC.
 * Out: errno.  *countp, when not null, is the number of filesystem blocks
 *      released -- see ufs_indirtrunc on why that is the probe's handle.
 */
int
ufs_itrunc(oip, length, flags, countp)
struct inode *oip;
off_t         length;
int           flags;
long         *countp;
{
    struct ufsmount *ump;
    struct buf      *bp;
    daddr_t          oldaddr[NADDR];
    daddr_t          lastblock;
    daddr_t          lastiblock[NIADDR];
    daddr_t          bn;
    daddr_t          lbn;
    long             count;
    long             released;
    int              offset;
    int              level;
    int              i;
    int              fresh;
    int              error;
    int              allerror;

    if (countp != (long *)0)
        *countp = 0L;
    released = 0L;
    ump = ITOUMP(oip);

    /* GROWING, OR NOT MOVING.  Reno's early return: record the size and stamp
     * the inode.  Everything past here is the shrink. */
    if (oip->i_size <= length) {
        oip->i_size = length;
        oip->i_flag |= ICHG | IUPD;
        return (iupdat(oip, 1));
    }

    /* The index of the last block to KEEP.  -1 when truncating to zero. */
    lastblock = lblkno(length + (off_t)FS_BLKSIZE - 1L) - (daddr_t)1;
    lastiblock[SINGLE] = lastblock - (daddr_t)NDADDR;
    lastiblock[DOUBLE] = lastiblock[SINGLE] - (daddr_t)NINDIR;
    /* 65536 rather than NINDIR * NINDIR: both are longs here, so the product
     * would be a 32-bit MULTIPLY at run time -- one of fcc's software
     * routines -- to compute a constant.  ufs_fs.h pins NINDIR at 256 and the
     * ERR beside it is what keeps this in step. */
    lastiblock[TRIPLE] = lastiblock[DOUBLE] - (daddr_t)65536L;

    /* A PARTIAL LAST BLOCK MUST BE ZEROED BEYOND THE NEW EOF, and upstream
     * says why: the file may grow again, and those bytes would become readable
     * a second time.  Truncating to a block boundary skips it. */
    offset = (int)blkoff(length);
    if (offset != 0) {
        lbn = lblkno(length);
        error = ufs_bmapx(oip->i_devvp, (daddr_t *)0, lbn, B_WRITE, oip,
                          &bn, &fresh);
        if (error)
            return (error);
        if (fresh) {
            bp = getblk(ITOV(oip), lbn);
            clrbuf(bp);
        } else {
            error = bread(ITOV(oip), lbn, &bp);
            if (error) {
                brelse(bp);
                return (error);
            }
        }
        bp->b_blkno = bn;
        for (i = offset; i < FS_BLKSIZE; i++)
            bp->b_addr[i] = (char)0;
        error = bwrite(bp);
        if (error)
            return (error);
    }

    /* THE LIVE INODE IS CLEANED AND WRITTEN FIRST; the copy keeps the
     * addresses the freeing walk needs.  lastiblock is normalised to -1 at the
     * same time, which is what ufs_indirtrunc reads as "all of it".
     *
     * ONLY THE ADDRESS ARRAY IS COPIED, where Reno copies the whole inode
     * (`tip = *oip`) and re-points `ip` at the copy.  The addresses are the
     * only thing the freeing walk reads out of it -- everything else it needs
     * (i_devvp, the superblock) is identical in both and is taken from the live
     * inode.  Twenty-eight bytes of frame against a hundred-odd, which matters
     * on a 512-byte kernel stack that a recursive ufs_indirtrunc is about to
     * stand on.  It also happens to avoid a whole-struct assignment, which
     * nothing in this tree's kernel C does and which therefore has no fixture
     * saying fcc gets it right. */
    for (i = 0; i < NADDR; i++)
        oldaddr[i] = oip->i_addr[i];
    oip->i_size = length;
    for (level = TRIPLE; level >= SINGLE; level--)
        if (lastiblock[level] < (daddr_t)0) {
            oip->i_addr[NDADDR + level] = (daddr_t)0;
            lastiblock[level] = (daddr_t)-1;
        }
    for (i = NDADDR - 1; (daddr_t)i > lastblock; i--)
        oip->i_addr[i] = (daddr_t)0;
    oip->i_flag |= ICHG | IUPD;

    /* Before the inode goes out, and before anything is freed: drop the cached
     * buffers for the blocks about to stop belonging to this file.  `length >
     * 0` is Reno's second argument -- keep dirty buffers only if the file
     * survives at all -- and it is inert here, nothing being dirty. */
    vinvalbuf(ITOV(oip), (length > 0L));

    allerror = iupdat(oip, 1);

    /* Indirect blocks first, deepest level first. */
    for (level = TRIPLE; level >= SINGLE; level--) {
        bn = oldaddr[NDADDR + level];
        if (bn != (daddr_t)0) {
            error = ufs_indirtrunc(oip, bn, lastiblock[level], level, &count);
            if (error)
                allerror = error;
            released += count;
            if (lastiblock[level] < (daddr_t)0) {
                error = ufs_bfree(oip->i_devvp, &ump->um_sb, bn);
                if (error)
                    allerror = error;
                else
                    released += 1L;
            }
        }
        if (lastiblock[level] >= (daddr_t)0)
            goto done;
    }

    /* Then the whole direct blocks. */
    for (i = NDADDR - 1; (daddr_t)i > lastblock; i--) {
        bn = oldaddr[i];
        if (bn == (daddr_t)0)
            continue;
        error = ufs_bfree(oip->i_devvp, &ump->um_sb, bn);
        if (error)
            allerror = error;
        else
            released += 1L;
    }

done:
    oip->i_flag |= ICHG;
    if (countp != (long *)0)
        *countp = released;
    return (allerror);
}


/* iput -- give a LOCKED inode back.
 *
 * Reno's iput asserts ILOCKED, unlocks, and vreles (ufs/ufs_inode.c:232-239),
 * and as of 1.12d so does this -- the assert being VOP_UNLOCK's own panic,
 * which fires for every caller rather than only for this one.
 *
 * IT IS NOT THE OPPOSITE OF iget, AND THE NAMES ARE UPSTREAM'S.  iget returns
 * an UNLOCKED reference here (see its header); iput releases a LOCKED one.  So
 * the two do not pair, and the call sites do not balance -- ufs_vnops.c has
 * three igets against eleven iputs.  What pairs with iput is not iget but the
 * LOCK CONTRACT: namei hands back ni_vp locked, VOP_LOOKUP hands back the
 * inode it found locked, and an operation given one of those gives it back
 * with iput.  An inode obtained from iget and never locked is released with
 * vrele instead, which is what ufs_remove's `dp == ip` arm does and says.
 *
 * This is exactly vput(ITOV(ip)) and is written out rather than calling it,
 * because vput lives in vfs.mod and reaching it would be a new entry in an ABI
 * two modules agree on for two lines that are not going to change. */
void
iput(ip)
struct inode *ip;
{
    struct vnode *vp;

    vp = ip->i_vnode;
    VOP_UNLOCK(vp);
    vrele(vp);
}


/* ufs_ifmttovt -- 2.11BSD's IFMT bits to the VFS's enum.
 *
 * Reno keeps this as a table indexed by `(mode & IFMT) >> 12`; a switch is
 * smaller here and, more usefully, an unknown type falls through to VBAD rather
 * than off the end of a fifteen-entry array.  A corrupt mode field is exactly
 * the case where a table lookup stops being safe.
 */
int
ufs_ifmttovt(mode)
unsigned short mode;
{
    switch (mode & IFMT) {
    case IFREG:  return (VREG);
    case IFDIR:  return (VDIR);
    case IFBLK:  return (VBLK);
    case IFCHR:  return (VCHR);
    case IFLNK:  return (VLNK);
    case IFSOCK: return (VSOCK);
    case IFIFO:  return (VFIFO);
    /* IFMT ITSELF IS THE ONLY VBAD, and the difference is load-bearing rather
     * than pedantic.  Reno's table (vendor/4.3BSD-Reno/ufs/ufs_vnops.c:209)
     * reads
     *
     *   VNON, VFIFO, VCHR, VNON, VDIR, VNON, VBLK, VNON,
     *   VREG, VNON, VLNK, VNON, VSOCK, VNON, VNON, VBAD,
     *
     * indexed by (mode & IFMT) >> 12 -- so index 0, a FREE inode, is VNON, and
     * only index 15 is VBAD.  This port returned VBAD for every unrecognised
     * mode, free inodes included.
     *
     * VBAD IS NOT "unknown", IT IS A CLAIM ABOUT OWNERSHIP: getnewvnode reads
     * it as "this vnode belongs to no filesystem" and SKIPS vgone
     * (vfs_subr.c: `if (vp->v_type != VBAD) vgone(vp);`).  So an inode read
     * with mode 0 -- which iget does whenever it is handed a free number --
     * produced a vnode that was hashed but marked unowned, and the pool
     * recycled it without ever calling ufs_reclaim.  The stale entry then
     * corrupted its bucket, and a chain walk that crosses buckets never meets
     * its head sentinel.  Found by the recycle case in ufs_probe, which is
     * exactly what that case exists for. */
    case IFMT:   return (VBAD);
    }
    return (VNON);
}
