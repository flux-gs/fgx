

/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX-Origin: original -- FGX code.  It CITES BSD but contains none of it;
 * registering it would assert the Regents' copyright over work they did not
 * write.
 */
/* ufs_devprobe.c -- the FILESYSTEM asserted through DEVICE FILES.  UFS 1.13a.
 *
 * The fourth and last of ufsprobe.mod's mutually exclusive gates, and the
 * first one split for the PROBE module's size rather than the module under
 * test's: with kernel.ufswprobe = 1 ufsprobe.mod is 64,295 bytes of 65,536,
 * so the next case of any size does not link whichever file it goes in.
 *
 * WHAT A DEVICE FILE IS, and it is the whole reason these cases are not just
 * more of ufs_wprobe's: it is an inode that names a DRIVER instead of blocks.
 * Everything the filesystem knows about it -- mode, owner, link count,
 * timestamps -- is ordinary, and the one field that is not, the device number,
 * lives in the WORD A REGULAR FILE KEEPS ITS FIRST BLOCK ADDRESS IN.  So the
 * format cases below read the platter raw: a getattr that reported di_addr[0]
 * unconditionally would look perfect through the vnode layer and hand back a
 * device made out of a block number.
 *
 * AND WHY checkalias EXISTS, which is the other half: two names for one device
 * must reach ONE vnode.  /dev/console and /dev/tty0 can be the same driver,
 * and the root disk is already open through bdevvp -- with no name at all --
 * before /dev exists.  Two independent vnodes for one device means the
 * driver's last close arrives while another path still has it open.
 *
 * WHICH CASES CAN GO RED, MEASURED.  Ten mutations, eight of which fired at
 * the case they were aimed at:
 *
 *   both rdev accessors moved to the HIGH word    -> 1316
 *   ufs_setrdev leaving junk in the high word     -> 1317
 *   ufs_getattr always reporting NODEV            -> 1311
 *   vcount ignoring VALIASED                      -> 1327
 *   checkalias marking only the newcomer          -> 1324
 *   checkalias marking only the older             -> 1325
 *   checkalias never reviving a VT_NON vnode      -> 1346
 *   spec_inodeops' reclaim replaced by a nullop   -> 1338
 *
 *   ufs_getrdev ALONE moved to the high word      -> 1308, honestly earlier:
 *       the kernel then disagrees with itself and the vnode's v_rdev catches
 *       it before the platter does.  Moving BOTH accessors is the mutation
 *       that reaches 1316, because only then is the kernel self-consistent
 *       and the FORMAT the sole thing that is wrong.
 *   checkalias ignoring v_type                    -> a panic, `vgone: missing
 *       alias`, before case 1334: aliasing a block device to a character one
 *       corrupts the chain, and vgone finds that first.
 *
 * ONE OF THOSE ARMS CHANGED A CASE.  Replacing the reclaim entry with a nullop
 * left this gate GREEN in its first form, because ufs_inactive had already
 * zeroed the mode and the stale hash entry was indistinguishable from a freed
 * inode.  Freeing the i-list slot and taking the inode off its bucket are two
 * different obligations; case 1338 was added for the second, and the comment
 * that had claimed one case covered both was wrong.
 *
 * THE DRIVER SECTION'S ARMS, measured.  Four mutations, all landing where
 * aimed:
 *
 *   spec_chread treating EOF as a byte              -> 1356
 *   spec_chwrite returning without consuming the uio -> 1359
 *   the kernel arm's cross-bank name copy disabled   -> 1350
 *   the kernel arm's record-device refusal removed
 *       (_Chardev_Bulk's BCC -> BRA, size-preserving) -> 1363
 *
 * The first also covers a kc_cdread shim that always answered "byte 0": the
 * loop would move eight zeroes and uio_resid would reach zero.  WHAT NO ARM
 * HERE COVERS is spec_open's dispatch -- /dev/null's open cannot fail, so a
 * spec_open that returned 0 without reaching the driver passes every case in
 * this file.  It is the wrong device to prove that with, and the right one is
 * a driver with state; said rather than left to be assumed.
 *
 * THE FOURTH WAS MEASURED TWICE OVER, because "1363 went red" only says the
 * answer was not EIO and the interesting part is WHICH answer it was.  A
 * temporary arm returning 1400 + errno reported 1400, and one returning
 * 1500 + uio_resid reported 1500: with the refusal removed the read
 * SUCCEEDS and consumes all eight bytes.  That is apple/fgx#198's silent
 * half in one line -- the caller is told it read eight bytes of capture that
 * bpf never produced.
 *
 * AND THE bpf0 SECTION PROVED IT RUNS AT ALL before any of that, by the one
 * mutation a `lkidx >= 0' guard makes necessary: inverting its own assertion
 * (!= EIO -> == EIO) went red at 1363, so the device is registered by the
 * time this probe runs and the block is not being skipped.
 *
 * WHAT IS NOT HERE, stated so a green gate is not read as more than it is:
 * IOCTL AND SELECT.  spec_ioctl and spec_select on a character device still
 * reach `kc_panic("the character device switch is 1.13")` -- ioctl's argument
 * is a pointer into the caller's bank and select's is a per-process wait
 * record, and both need a marshalling decision read and write did not.  And
 * no TTY is driven here: /dev/tty needs a controlling terminal, which is its
 * own question (apple/fgx#60, #117).
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
#include "file.h"       /* FREAD/FWRITE -- VOP_SELECT's `which' */

extern int          bdevvp();
extern int          ufs_sbread();
extern int          ufs_sbupdate();
extern int          ufs_mountfs();
extern void         vref();
extern int          iget();
extern void         iput();
extern void         vrele();
extern int          bread();
extern int          bwrite();
extern void         brelse();
extern int          kc_blkio();
extern int          vcount();
extern int          ufs_itrunc();   /* the truncate whose level-1 walk is #193 */
extern int          kc_cdlookup();   /* the chardev registry, 1.13b */
extern dev_t        ufs_getrdev();
extern struct inode *ufs_ifind();

#define DEV_BLKSIZE     512
#define PROBE_READ      1

static char          probebuf[DEV_BLKSIZE];
static struct ufs_sb probesb;

/* DEVSCRATCH -- the directory these cases build their /dev in.  Inode 11: the
 * three directory guards in ufs_wprobe.c own 8, 9 and 10, and although the
 * gates are mutually exclusive the numbers are kept distinct so that a volume
 * left half-written by one gate is not silently reused by another. */
#define DEVSCRATCH      11

/* The device numbers these cases make up.  They name NOTHING -- no driver is
 * opened here -- and they are chosen to be distinguishable in a raw dump. */
#define DEVMAJ_A        0x1234
#define DEVMAJ_B        0x5678

static int
rawio(dev, dblk, isread)
    int     dev;
    daddr_t dblk;
    int     isread;
{
    return (kc_blkio(dev, (int)(dblk >> 16), (int)dblk, probebuf, isread));
}

static struct nameidata dev_nd;
static struct nameidata dev_nd2;
static char             dev_nameend[1];
static struct vattr     devva;

static char dnchar[3]  = { 'c', 'h', 'r' };
static char dnchar2[4] = { 'c', 'h', 'r', '2' };
static char dnblk[3]   = { 'b', 'l', 'k' };
static char dnblk2[4]  = { 'b', 'l', 'k', '2' };
/* NUL-terminated: kc_cdlookup is handed a C string, not a counted one, because
 * the kernel arm has to measure it on the way across the bank. */
static char dnnull[5]  = { 'n', 'u', 'l', 'l', 0 };
static char dnbpf[5]   = { 'b', 'p', 'f', '0', 0 };
static char devbuf[8];
static char dndot[1]   = { '.' };
static char dndotdot[2] = { '.', '.' };

static char  devimg[DIRBLKSIZ];
static ino_t dev_made[8];
static int   dev_nmade;

/* ---- the same helpers the directory guards use, and for the same reasons --
 *
 * devlook is ufs_wprobe's dirlook: it takes the parent lock for the search and
 * gives it back, because a directory these cases KEEP cannot be one they hold
 * locked -- iget returns a locked inode, so a lookup that reaches a directory
 * this process already holds waits in ufs_ihashget for its own lock. */
static int devlookerr;

static int
devlook(dvp, ndp, nm, n, op)
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
    ndp->ni_next     = dev_nameend;
    ndp->ni_nameiop  = (short)(op | LOCKPARENT);
    ndp->ni_vp       = (struct vnode *)0;
    ndp->ni_dvp      = dvp;
    ndp->ni_isdotdot = 0;
    ndp->ni_offset   = (off_t)0;
    ndp->ni_count    = 0;
    ndp->ni_endoff   = (off_t)0;
    ndp->ni_dent.d_namlen = (unsigned short)n;
    d = (char *)&ndp->ni_dent + DIRHDRSIZ;
    for (i = 0; i < n; i++)
        d[i] = nm[i];
    d[n] = (char)0;

    VOP_LOCK(dvp);
    devlookerr = VOP_LOOKUP(dvp, ndp);
    VOP_UNLOCK(dvp);
    return (devlookerr);
}

/* devrec -- one directory record into devimg, as ufs_wprobe's dirrec does. */
static int
devrec(off, ino, reclen, nm, n)
int   off;
int   ino;
int   reclen;
char *nm;
int   n;
{
    struct direct *e;
    char          *d;
    int            i;

    e = (struct direct *)&devimg[off];
    e->d_ino    = (ino_t)ino;
    e->d_reclen = (unsigned short)reclen;
    e->d_namlen = (unsigned short)n;
    d = (char *)e + DIRHDRSIZ;
    for (i = 0; i < n; i++)
        d[i] = nm[i];
    d[n] = (char)0;
    return (off + reclen);
}

/* devmknod -- make a device node and record its inode number for the restore.
 *
 * ni_vp IS EXPECTED NULL, which is the property ufs_mknod's header explains:
 * the vnode maknode built is the WRONG one for a device file -- it was minted
 * from a mode of zero, so it never went near checkalias -- and mknod discards
 * it so the next lookup builds a right one.  A mknod that handed one back
 * would be handing back a vnode with the ordinary ufs_vnodeops. */
static int
devmknod(dvp, nm, n, type, rdev)
struct vnode *dvp;
char         *nm;
int           n;
int           type;
dev_t         rdev;
{
    if (devlook(dvp, &dev_nd, nm, n, CREATE) != ENOENT)
        return (1);
    devva.va_type = type;
    devva.va_mode = 0666;
    devva.va_rdev = rdev;
    if (VOP_MKNOD(&dev_nd, &devva) != 0)
        return (1);
    if (dev_nd.ni_vp != (struct vnode *)0)
        return (1);
    return (0);
}

/* devraw -- the dinode of `ino`, read RAW off the platter into probebuf.
 *
 * UNDER THE BUFFER CACHE, which is this campaign's standing rule and matters
 * more here than anywhere: the whole subject is a FORMAT, and a read through
 * bread would hand back the bytes this kernel just encoded rather than the
 * bytes a PDP-11 would find.  Returns the byte offset of the dinode within
 * probebuf, or -1. */
static int
devraw(dev, ino)
int   dev;
ino_t ino;
{
    daddr_t blk;
    int     slot;

    blk  = itod(ino);
    slot = itoo(ino) * UFS_DINODESIZE;
    /* itod gives a 1024-byte filesystem block; rawio moves 512, so the sector
     * is chosen here exactly as ufs_wprobe's dirat does it. */
    if (rawio(dev, blk * (daddr_t)2 + (daddr_t)(slot / DEV_BLKSIZE),
              PROBE_READ) != 0)
        return (-1);
    return (slot % DEV_BLKSIZE);
}

static int
devguard(dev, devvp, mp)
int           dev;
struct vnode *devvp;
struct mount *mp;
{
    struct inode    *dip;
    struct vnode    *dvp;
    struct inode    *ip;
    struct vnode    *vp;
    struct vnode    *vp2;
    struct vnode    *bvp;
    struct ufsmount *ump;
    struct buf      *bp;
    struct vattr     va;
    ino_t            chrino;
    ino_t            blkino;
    ino_t            zap;
    struct uio       u;
    struct iovec     iov;
    int              lkidx;
    int              off;
    int              i;
    int              slot;

    dev_nmade = 0;

    if (iget(mp, (ino_t)DEVSCRATCH, &dip) != 0)
        return (1300);
    dvp = ITOV(dip);
    if (dip->i_mode != 0) {
        iput(dip);
        return (1301);      /* slot 11 is NOT free -- do not write on it */
    }
    /* Held UNLOCKED from here: devlook takes the parent lock per search and
     * gives it back.  ufs_wprobe's dirlook header carries the argument. */
    VOP_UNLOCK(dvp);
    ump = ITOUMP(dip);

    dip->i_mode  = (unsigned short)(IFDIR | 0755);
    dip->i_nlink = 2;
    dip->i_size  = (off_t)0;
    dvp->v_type  = VDIR;

    for (i = 0; i < DIRBLKSIZ; i++)
        devimg[i] = (char)0;
    off = devrec(0, DEVSCRATCH, DIRSIZ(1), dndot, 1);
    off = devrec(off, (int)UFS_ROOTINO, DIRBLKSIZ - off, dndotdot, 2);
    if (off != DIRBLKSIZ)
        return (1302);
    {
        struct uio   u;
        struct iovec iov;

        iov.iov_base = devimg;
        iov.iov_len  = DIRBLKSIZ;
        u.uio_iov    = &iov;
        u.uio_iovcnt = 1;
        u.uio_offset = (off_t)0;
        u.uio_resid  = (unsigned short)DIRBLKSIZ;
        u.uio_segflg = UIO_SYSSPACE;
        u.uio_rw     = UIO_WRITE;
        /* THROUGH THE VECTOR, not by name.  ufs_write lives in ufsdir.mod and
         * this probe imports from ufs.mod and vfs.mod; VOP_WRITE is how every
         * caller outside that module reaches it anyway, and the vector entry
         * carries the callee's bank. */
        if (VOP_WRITE(dvp, &u, IO_SYNC, (char *)0) != 0)
            return (1303);
    }

    /* ---- (a) THE FORMAT: mknod PUTS A DEVICE NUMBER ON THE PLATTER ------
     *
     * The case the whole deliverable is for, and the only one that can catch a
     * device number written to the wrong HALF of di_addr[0].  A PDP-11 daddr_t
     * is stored high word first (ufs_sb.c's sb_u32 is this port's decoder), and
     * 2.11BSD's in-core inode overlays the address array with `u_short
     * I_dummy; dev_t I_rdev;` -- so the device number is the SECOND 16-bit word
     * on disk and the first is zero.  inode.h carries the whole derivation.
     *
     * Getting it backwards is invisible everywhere else: this kernel would
     * write the high word, read the high word, and agree with itself
     * perfectly.  Only the platter, or a PDP-11, can say otherwise.
     */
    if (devmknod(dvp, dnchar, 3, VCHR, (dev_t)DEVMAJ_A))
        return (1304);
    if (devlook(dvp, &dev_nd, dnchar, 3, LOOKUP) != 0)
        return (1305);
    chrino = VTOI(dev_nd.ni_vp)->i_number;
    dev_made[dev_nmade] = chrino;
    dev_nmade = dev_nmade + 1;

    /* ...and the vnode it comes back on is the DEVICE's, not a file's. */
    vp = dev_nd.ni_vp;
    if (vp->v_type != VCHR)
        return (1306);
    /* AND IT WEARS THE DEVICE-FILE TABLE.  Asserted by what the table DOES,
     * not by comparing v_op to a pointer: spec_inodeops is data in ufsdir.mod
     * and this probe is another module, so the symbol is not reachable -- and
     * the observable property is the better assertion anyway.
     *
     * THIS ONE ASSERTS THE INODE HALF.  iget hands back a LOCKED inode
     * (1.12d), and spec_inodeops answers islocked with ufs_islocked, which
     * knows that.  Plain spec_vnodeops answers with spec_nullop, which returns
     * zero however the inode is held -- so a device file given the ordinary
     * spec table fails HERE.  The other two halves have cases of their own:
     * 1311 is getattr (spec_vnodeops answers EBADF) and 1334 is reclaim
     * (spec_vnodeops answers nullop and the i-list slot never comes back). */
    if (!VOP_ISLOCKED(vp))
        return (1307);
    if (vp->v_rdev != (dev_t)DEVMAJ_A)
        return (1308);      /* checkalias put the number on the vnode */
    if (ufs_getrdev(VTOI(vp)) != (dev_t)DEVMAJ_A)
        return (1309);      /* ...and the inode still agrees with it */

    /* getattr reports it, and reports it only for a device. */
    if (VOP_GETATTR(vp, &va, (char *)0) != 0)
        return (1310);
    if (va.va_rdev != (dev_t)DEVMAJ_A)
        return (1311);
    if (va.va_type != VCHR)
        return (1312);
    if ((va.va_mode & 0777) != 0666)
        return (1313);
    iput(VTOI(vp));

    /* AND NOW THE PLATTER.  Two assertions, and the second is the one a
     * wrong-half implementation fails: the low word carries the number and the
     * HIGH word is zero.  2.11BSD's mknod zeroes it explicitly (i_dummy = 0,
     * usr/sys/sys/ufs_syscalls.c:229) because the slot may have held a block
     * address a moment ago, and half of one is not a device. */
    slot = devraw(dev, chrino);
    if (slot < 0)
        return (1314);
    {
        unsigned short mode;
        unsigned short hi;
        unsigned short lo;

        mode = (unsigned short)((unsigned char)probebuf[slot] |
               (((unsigned char)probebuf[slot + 1]) << 8));
        if ((mode & IFMT) != IFCHR)
            return (1315);
        /* di_addr is at offset 12 of the dinode -- pdplayout.c pins that on
         * the machine -- and its first long's two words are the next four
         * bytes, high word first. */
        hi = (unsigned short)((unsigned char)probebuf[slot + 12] |
             (((unsigned char)probebuf[slot + 13]) << 8));
        lo = (unsigned short)((unsigned char)probebuf[slot + 14] |
             (((unsigned char)probebuf[slot + 15]) << 8));
        if (lo != (unsigned short)DEVMAJ_A)
            return (1316);      /* the number is in the LOW word */
        if (hi != 0)
            return (1317);      /* ...and 2.11BSD's i_dummy is zero */
    }

    /* ---- (b) TWO NAMES FOR ONE DEVICE: TWO VNODES, AND vcount ----------
     *
     * THE FIRST VERSION OF THIS CASE ASSERTED THE OPPOSITE AND THE PROBE SAID
     * SO, which is worth writing down because the wrong reading is the
     * intuitive one.  checkalias does NOT collapse two device files onto one
     * vnode.  Two names are two INODES -- different i-list slots, different
     * link counts, different timestamps -- and each gets its own vnode; what
     * checkalias does is put them on one chain and mark the SET, so that the
     * question "is anybody still using this DEVICE" has an answer.
     *
     * AND THAT ANSWER IS vcount, WHICH IS THE WHOLE POINT (apple/fgx#76).  A
     * driver's last close is where it may reset the hardware, and with two
     * vnodes naming one device neither v_usecount reaching zero means
     * anything.  The pair below is the case: v_usecount says ONE and vcount
     * says TWO, at the same instant, on the same vnode.  A spec_close that
     * asked v_usecount would close the driver here, under a process that
     * still has the other name open.
     */
    if (devmknod(dvp, dnchar2, 4, VCHR, (dev_t)DEVMAJ_A))
        return (1318);
    if (devlook(dvp, &dev_nd, dnchar, 3, LOOKUP) != 0)
        return (1319);
    vp = dev_nd.ni_vp;
    if (devlook(dvp, &dev_nd2, dnchar2, 4, LOOKUP) != 0)
        return (1320);
    vp2 = dev_nd2.ni_vp;
    dev_made[dev_nmade] = VTOI(vp2)->i_number;
    dev_nmade = dev_nmade + 1;

    if (VTOI(vp)->i_number == VTOI(vp2)->i_number)
        return (1321);      /* two NAMES, so two inodes -- without this the
                             * cases below could be about one file */
    if (vp2 == vp)
        return (1322);      /* ...and therefore two vnodes */
    if (vp->v_rdev != vp2->v_rdev)
        return (1323);      /* naming ONE device */
    /* BOTH ENDS ARE MARKED, because VALIASED is a property of the SET and
     * vcount tests it on whichever vnode it happens to hold -- marking only
     * the newcomer would make the answer depend on which name you came in
     * through. */
    if ((vp->v_flag & VALIASED) == 0)
        return (1324);
    if ((vp2->v_flag & VALIASED) == 0)
        return (1325);

    if (vp->v_usecount != 1)
        return (1326);      /* one reference through THIS name... */
    if (vcount(vp) != 2)
        return (1327);      /* ...and two to the DEVICE.  #76 in two lines. */
    if (vcount(vp2) != 2)
        return (1328);      /* the same answer from the other end */

    iput(VTOI(vp2));
    /* AND WHEN ONE GOES, THE COUNT FOLLOWS.  Without this the pair above is
     * satisfied by a vcount that returns a constant 2. */
    if (vcount(vp) != 1)
        return (1329);
    iput(VTOI(vp));

    /* ---- (c) A BLOCK DEVICE WITH THE SAME NUMBER IS A DIFFERENT DEVICE --
     *
     * The alias chain is keyed on (rdev, TYPE) and not on rdev alone -- both
     * checkalias and vcount test both -- because the major number spaces are
     * separate: block major 3 and character major 3 are different drivers.
     * Keying on the number alone would alias a disk to a terminal.
     */
    if (devmknod(dvp, dnblk, 3, VBLK, (dev_t)DEVMAJ_A))
        return (1330);
    if (devlook(dvp, &dev_nd, dnblk, 3, LOOKUP) != 0)
        return (1331);
    vp2 = dev_nd.ni_vp;
    blkino = VTOI(vp2)->i_number;
    dev_made[dev_nmade] = blkino;
    dev_nmade = dev_nmade + 1;
    if (vp2->v_type != VBLK)
        return (1332);
    if (devlook(dvp, &dev_nd2, dnchar, 3, LOOKUP) != 0)
        return (1333);
    vp = dev_nd2.ni_vp;
    /* NOT ALIASED TO IT: same number, different type.  vcount is the
     * observation, because it is what a close would ask -- the block node has
     * ONE reference to its device even though a character device with the
     * same number has one too. */
    if (vcount(vp2) != 1)
        return (1334);
    iput(VTOI(vp));
    iput(VTOI(vp2));

    /* ---- (d) A DEVICE FILE IS STILL A FILE -----------------------------
     *
     * Unlink it, and TWO different things have to happen: ufs_inactive frees
     * the i-list slot, and ufs_reclaim takes the in-core inode off its hash
     * bucket.  spec_inodeops supplies both from the filesystem; plain
     * spec_vnodeops answers both with spec_nullop.
     *
     * THEY NEED TWO CASES AND THE FIRST VERSION OF THIS ONLY HAD ONE.  A
     * mutation replacing the reclaim entry with a nullop left this gate GREEN,
     * because inactive had already zeroed the mode -- so the stale hash entry
     * iget found was indistinguishable from a correctly freed inode.  Measured,
     * not reasoned: the comment here used to claim this case covered reclaim
     * and it did not.  ufs_ifind is the observation that separates them; it
     * answers "is this inode in core" without taking a reference or a lock,
     * which is why it exists apart from ufs_ihashget.
     */
    if (devlook(dvp, &dev_nd, dnblk, 3, DELETE) != 0)
        return (1335);
    if (VOP_REMOVE(&dev_nd) != 0)
        return (1336);
    if (devlook(dvp, &dev_nd, dnblk, 3, LOOKUP) != ENOENT)
        return (1337);
    /* ufs_reclaim's: off the hash.  A nullop here is apple/fgx#175 exactly --
     * latent until the vnode pool wraps and the stale entry is handed back for
     * a DIFFERENT inode number, which is a great deal further from the cause
     * than this line. */
    if (ufs_ifind(devvp->v_rdev, blkino) != (struct inode *)0)
        return (1338);
    /* ufs_inactive's: the i-list slot went back. */
    if (iget(mp, blkino, &ip) != 0)
        return (1339);
    if (ip->i_mode != 0)
        return (1340);
    iput(ip);

    /* ---- (e) A DEVICE OPENED BEFORE ITS NAME EXISTED -------------------
     *
     * checkalias's OTHER return, and the one the whole mechanism is built
     * around.  The root disk is opened through bdevvp before any filesystem is
     * mounted -- it has no name, no inode and no mount, and its vnode is
     * VT_NON.  When /dev finally appears and somebody opens the same device BY
     * NAME, the new inode must attach to THAT vnode rather than mint a second
     * one, or an already-open descriptor stops referring to the device the
     * moment its name shows up.
     *
     * SO THIS ONE ASSERTS POINTER IDENTITY, where (b) asserts the opposite:
     * two device FILES are two vnodes, but a device file and a nameless open
     * of the same device are ONE.  The difference is v_tag -- a vnode with no
     * filesystem behind it is the only kind checkalias will hand over.
     *
     * A NUMBER NOTHING ELSE USES, deliberately: doing this to the scratch
     * volume's own device vnode would re-identify the vnode this probe reads
     * the platter through, half way through the run.
     */
    if (bdevvp((int)DEVMAJ_B, &bvp) != 0)
        return (1342);
    if (bvp->v_tag != VT_NON)
        return (1343);      /* the precondition: no filesystem behind it */
    if (devmknod(dvp, dnblk2, 4, VBLK, (dev_t)DEVMAJ_B))
        return (1344);
    if (devlook(dvp, &dev_nd, dnblk2, 4, LOOKUP) != 0)
        return (1345);
    dev_made[dev_nmade] = VTOI(dev_nd.ni_vp)->i_number;
    dev_nmade = dev_nmade + 1;
    if (dev_nd.ni_vp != bvp)
        return (1346);      /* THE SAME VNODE the device was opened on */
    if (bvp->v_tag != VT_UFS)
        return (1347);      /* ...and it now belongs to a filesystem */
    if (bvp->v_type != VBLK)
        return (1348);
    if (bvp->v_rdev != (dev_t)DEVMAJ_B)
        return (1349);
    iput(VTOI(bvp));        /* the lookup's reference and lock */
    vrele(bvp);             /* bdevvp's */

    /* ---- (f) AND NOW A REAL DRIVER (UFS 1.13b) --------------------------
     *
     * Everything above builds a device file and finds it; nothing above asks
     * one to do any I/O.  This section does, through /dev/null -- the one
     * driver whose behaviour is written down beside its code (chardev.s: read
     * is immediate EOF, write discards, open and close always succeed) and the
     * one that cannot disturb the console, the harness or the volume.
     *
     * THE INDEX IS LOOKED UP, NOT BAKED.  A registry index is handed out in
     * registration ORDER, so `null` is index 0 today and is not guaranteed to
     * be tomorrow -- the ttyv, pty and serial modules all register at boot.
     * Asserting a number here would be asserting a boot order.
     */
    if ((lkidx = kc_cdlookup(dnnull)) < 0)
        return (1350);      /* no /dev/null registered: the case is void */
    if (devmknod(dvp, dnnull, 4, VCHR, (dev_t)lkidx))
        return (1351);
    if (devlook(dvp, &dev_nd, dnnull, 4, LOOKUP) != 0)
        return (1352);
    vp = dev_nd.ni_vp;
    dev_made[dev_nmade] = VTOI(vp)->i_number;
    dev_nmade = dev_nmade + 1;
    if (vp->v_rdev != (dev_t)lkidx)
        return (1353);

    if (VOP_OPEN(vp, 0, (char *)0) != 0)
        return (1354);

    /* READ: immediate EOF, so nothing moves and the count is untouched.  A
     * VCHR arm that still panicked would not reach this; one that fell through
     * to the BLOCK path would try to bread a device index as a filesystem
     * block, which on this volume is a real read of somebody else's data. */
    for (i = 0; i < 8; i++)
        devbuf[i] = (char)0xEE;
    iov.iov_base = devbuf;
    iov.iov_len  = 8;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = 8;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (VOP_READ(vp, &u, 0, (char *)0) != 0)
        return (1355);
    if (u.uio_resid != 8)
        return (1356);      /* EOF moved nothing... */
    if (devbuf[0] != (char)0xEE)
        return (1357);      /* ...and wrote nothing into the buffer */

    /* WRITE: every byte accepted and discarded, so the whole count goes.  The
     * pair is what separates "the write path is wired" from "the write path
     * returns success": a stub returning 0 without consuming the uio fails
     * 1359, and one that consumed it without reaching the driver would need
     * the driver's own count to catch -- which /dev/null, having no state, is
     * exactly the wrong device to provide.  Said rather than implied. */
    for (i = 0; i < 8; i++)
        devbuf[i] = (char)(0x40 + i);
    iov.iov_base = devbuf;
    iov.iov_len  = 8;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = 8;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(vp, &u, 0, (char *)0) != 0)
        return (1358);
    if (u.uio_resid != 0)
        return (1359);      /* all eight consumed */

    /* IOCTL AND SELECT ON THE SAME OPEN VNODE (UFS 1.7d I4).
     *
     * Until I4 both of these kc_panic'd on VCHR, so a build without the
     * character-device door does not fail these cases -- it HALTS here, which
     * is a red of the loudest kind but not an assertion.  What the assertions
     * below add is that the dispatch reaches THE RIGHT DEVICE and applies
     * `which', neither of which a halt could have told us.
     *
     * THE IOCTL CASE IS THE WEAK ONE AND SAYING SO IS THE POINT.  /dev/null's
     * d_ioctl answers ENOTTY for every command, and ENOTTY is also what
     * spec_ioctl returns for a vnode that is not a device -- so a spec_ioctl
     * that had been stubbed `return (ENOTTY)' passes 1366 too.  bpf's d_ioctl
     * is the same constant, so no device this probe can reach discriminates
     * it.  What would: a device with a real d_ioctl, which is a tty, which is
     * reachable only once ioctl(2) routes through the vnode fileops.  Until
     * then 1366 is worth what it is worth -- the panic is gone and the call
     * returns -- and no more, which is better than a case that looks stronger
     * than it is.
     *
     * THE SELECT CASES DISCRIMINATE PROPERLY, and they need two devices to do
     * it.  /dev/null's d_select answers POLLOUT and never POLLIN; bpf's
     * answers POLLIN or nothing and NEVER POLLOUT (bpf.s, bpf_poll).  So 1367
     * and 1369 ask the same question of two devices and get opposite answers,
     * which no constant return satisfies -- that is what proves the mask came
     * from the device rather than from spec_select.  1368 is the other half:
     * the OLD spec_select returned 1 unconditionally for everything it did not
     * panic on, and a `which' that is not applied fails it.
     *
     * 1369 DOES NOT DEPEND ON A W5100 BEING PRESENT.  bpf_poll reads the chip's
     * RX count and answers POLLIN when it is non-zero; on a machine with no
     * Uthernet card that read is a floating bus and its value is not something
     * to assert on.  The assertion is only that POLLOUT is ABSENT, which is
     * true of both of bpf_poll's returns and so is true whatever the wire says.
     */
    if (VOP_IOCTL(vp, 0, (char *)0, 0, (char *)0) != ENOTTY)
        return (1366);
    if (VOP_SELECT(vp, FWRITE, 0, (char *)0) != 1)
        return (1367);      /* null says POLLOUT: writable */
    if (VOP_SELECT(vp, FREAD, 0, (char *)0) != 0)
        return (1368);      /* and never POLLIN: not readable */

    if (VOP_CLOSE(vp, 0, (char *)0) != 0)
        return (1360);
    iput(VTOI(vp));

    /* ---- A RECORD DEVICE THROUGH THE SAME ROAD -------------------------
     *
     * apple/fgx#198's SILENT half, and /dev/null cannot show it: null is a
     * per-byte device, so falling through to spec_chread's own loop is the
     * right answer for it.  /dev/bpf0 is the opposite -- registered with
     * CDF_RECORD, and its d_read slot is still EMPTY -- so the fallback
     * instruction is wrong for it, and the kernel arm has to say so instead
     * of handing the loop a driver that fills a whole buffer and answers a
     * count.
     *
     * WHY bpf AND NOT THE PTY MASTER, which is the device this campaign is
     * actually about: pty.mod's ops are installed by _Pty_LoadOpsPtr at
     * main.s:628, AFTER Mod_LoadConf, and this probe runs FROM ufsprobe's
     * mod_init, i.e. inside it.  Every pty OPEN here answers ENXIO (measured:
     * errno 6) -- though its bulk read would now answer EIO, since the
     * master is CDF_RECORD and its unpatched slot is zero, which is this
     * same refusal and not the driver.  bpf.mod registers its own chardev in
     * its own mod_init and loads before ufsprobe, so it is live by the time
     * this runs and needs no such window described.
     *
     * THE MUTATION, and it discriminates cleanly rather than by crashing.
     * With the refusal removed the loop runs bpf_read, which reads _Sys_RdMax
     * -- a syscall-layer singleton no vnode caller sets, and zero this early
     * in boot -- returns "byte 0" eight times, and this section reports a
     * SUCCESSFUL read of eight bytes: 1363 goes red, then 1364.  That is the
     * defect exactly: silent success over data nobody wrote.
     */
    if ((lkidx = kc_cdlookup(dnbpf)) >= 0) {
        if (devmknod(dvp, dnbpf, 4, VCHR, (dev_t)lkidx))
            return (1361);
        if (devlook(dvp, &dev_nd, dnbpf, 4, LOOKUP) != 0)
            return (1362);
        vp = dev_nd.ni_vp;
        dev_made[dev_nmade] = VTOI(vp)->i_number;
        dev_nmade = dev_nmade + 1;

        /* NO VOP_OPEN.  bpf's open starts a W5100 capture, and this machine
         * need not have an Uthernet card; the refusal under test is in the
         * read path and does not depend on the device being open. */
        for (i = 0; i < 8; i++)
            devbuf[i] = (char)0xEE;
        iov.iov_base = devbuf;
        iov.iov_len  = 8;
        u.uio_iov    = &iov;
        u.uio_iovcnt = 1;
        u.uio_offset = (off_t)0;
        u.uio_resid  = 8;
        u.uio_segflg = UIO_SYSSPACE;
        u.uio_rw     = UIO_READ;
        if (VOP_READ(vp, &u, 0, (char *)0) != EIO)
            return (1363);      /* refused, and refused with EIO */
        if (u.uio_resid != 8)
            return (1364);      /* nothing moved... */
        if (devbuf[0] != (char)0xEE)
            return (1365);      /* ...and nothing was written */

        /* THE OTHER HALF OF THE SELECT PAIR -- see the note at 1367.  bpf_poll
         * cannot answer POLLOUT; /dev/null cannot answer anything else.  One
         * spec_select serving both is the only way both cases pass. */
        if (VOP_SELECT(vp, FWRITE, 0, (char *)0) != 0)
            return (1369);
        iput(VTOI(vp));
    }

    /* ---- PUT IT ALL BACK, on the terms every writing section here uses --- */
    dip->i_nlink = 0;
    dip->i_flag |= ICHG;
    vrele(ITOV(dip));

    for (i = 0; i <= dev_nmade; i++) {
        if (i == dev_nmade)
            zap = (ino_t)DEVSCRATCH;
        else
            zap = dev_made[i];
        if (bread(devvp, itod(zap), &bp) != 0) {
            brelse(bp);
            return (1335);
        }
        slot = itoo(zap) * UFS_DINODESIZE;
        for (off = 0; off < UFS_DINODESIZE; off++)
            bp->b_addr[slot + off] = (char)0;
        if (bwrite(bp) != 0)
            return (1335);
    }
    return (0);
}


/* ufs_probe -- the entry point probe_dev.s calls in a UFSDEVPROBE build.
 *
 * IT SHARES ITS NAME WITH THE OTHER THREE GATES', deliberately: they are
 * mutually exclusive and ufsprobe.s PUTs exactly one, so the driver needs no
 * conditional.  fsblk is unused here, as it is in two of the others. */
/* ---- THE DOUBLE-INDIRECT TRUNCATE (apple/fgx#193) ----------------------
 *
 * EVERY OTHER TRUNCATE CASE IN THIS TREE STAYS AT LEVEL 0, AND LEVEL 0 IS
 * EXACTLY WHERE A WRONG ROW STRIDE CANNOT BE SEEN.  `ufs_indirtrunc' copies
 * the indirect block it is walking into `indircopy[level]', a
 * `daddr_t[NIADDR][NINDIR]' whose row is 1024 bytes; fcc emitted 512, because
 * the multi-dimensional stride hardcoded an element size of 2
 * (apple/fgx#192).  At level 0 the offset is zero and ANY stride multiplies
 * to the right answer.  At level 1 the copy landed in the MIDDLE of level 0's
 * row and at level 2 over the whole of it -- and the block free list is built
 * FROM that copy, so a truncate would have handed the allocator blocks it did
 * not own.  The compiler defect is fixed; this is the case that would have
 * caught it, and its absence is why it had to be found by reading.
 *
 * WHY IT IS IN THE DEVICE GATE, WHICH IS NOT WHERE IT BELONGS.  Its home is
 * `ufs_wprobe', beside the other truncate cases -- and that gate has 571
 * bytes of its 64 KB module bank left (measured), which this case does not
 * fit in.  Of the three gates that build a `struct mount' and so can call
 * `ufs_itrunc' at all, this is the one with both the room (44,982 free) and
 * an established write-and-restore discipline.  `ufsprobe' has 44,945 free
 * and no mount, which is the split that made it `ufsvnprobe' at 1.12a.  Move
 * it back when the truncate gate is rebalanced (apple/fgx#193 records this).
 *
 * LOGICAL 260 IS THE FIRST DOUBLE-INDIRECT BLOCK, and the number is
 * arithmetic rather than a guess: NDADDR (4) direct blocks, then NINDIR (256)
 * reached through the single indirect, so 0..3 are direct, 4..259 are single,
 * and 260 is the first block that cannot be named without `i_ib[1]'.
 *
 * IT COSTS FIVE BLOCKS, not five hundred and seventeen, and that is what
 * makes it affordable: everything not written stays a HOLE.  Two data blocks,
 * the two level-0 indirects that name them, and the double indirect above
 * both.  Naming the number is the point -- "it went up" would pass a reclaim
 * that returned four of the five, and only the exact count says the level-1
 * walk enumerated the right tree.
 *
 * THE SINGLE INDIRECT MUST STAY EMPTY, and 1372 says so.  If the write at
 * logical 260 allocated `i_ib[0]' as well then the cost would be four, the
 * case would still pass a "three or more" test, and which level it actually
 * reached would be unproven -- which is the blindness this case exists to end.
 *
 * INODE 40, CHECKED FREE FIRST, on the discipline every writing section here
 * uses: a volume whose layout ever changes stops the probe rather than being
 * written on.  It is well clear of DEVSCRATCH (11) and of everything devguard
 * allocates.  The blocks come off the free list and go back onto it, and the
 * i-list slot is zeroed at the end, so the volume is exactly as it was.
 */
static int
indirguard(dev, devvp, mp)
int           dev;
struct vnode *devvp;
struct mount *mp;
{
    struct inode    *gip;
    struct vnode    *gvp;
    struct ufsmount *gump;
    struct uio       u;
    struct iovec     iov;
    struct buf      *bp;
    daddr_t          before;
    long             grel;
    int              i;
    int              slot;

    if (iget(mp, (ino_t)40, &gip) != 0)
        return (1370);
    gvp = ITOV(gip);
    if (gip->i_mode != 0) {
        iput(gip);
        return (1371);      /* slot 40 is NOT free -- do not write on it */
    }
    gump = ITOUMP(gip);

    gip->i_mode  = (unsigned short)(IFREG | 0644);
    gip->i_nlink = 1;
    gip->i_size  = 0L;
    gvp->v_type  = VREG;

    for (i = 0; i < 8; i++)
        devbuf[i] = (char)(0x60 + i);

    before = gump->um_sb.sb_tfree;

    iov.iov_base = devbuf;
    iov.iov_len  = 8;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)(260L * 1024L);
    u.uio_resid  = 8;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(gvp, &u, 0, (char *)0) != 0)
        return (1372);

    /* AND A SECOND CHILD, WHICH IS THE HALF THAT MAKES THIS DISCRIMINATE.
     * MEASURED: with only logical 260 written, the level-1 block has ONE live
     * entry, at index 0.  ufs_indirtrunc scans its copy downward and recurses
     * on that entry LAST, so a recursion that clobbers the parent's copy is
     * never read back and the case stays GREEN -- verified by aliasing
     * `indircopy[level]' onto `indircopy[0]' by hand, which is #192's
     * collision, and watching it pass.  Logical 516 is 260 + NINDIR, so it
     * lands in child 1: now the walk recurses at index 1 and must still read
     * index 0 correctly afterwards.  That is the read a clobbered copy gets
     * wrong. */
    iov.iov_base = devbuf;
    iov.iov_len  = 8;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)(516L * 1024L);
    u.uio_resid  = 8;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(gvp, &u, 0, (char *)0) != 0)
        return (1372);

    if (gip->i_addr[NDADDR + 1] == (daddr_t)0)
        return (1373);      /* no i_ib[1]: nothing here would reach level 1 */
    if (gip->i_addr[NDADDR] != (daddr_t)0)
        return (1374);      /* the single indirect was built too -- see above */
    if (before - gump->um_sb.sb_tfree != (daddr_t)5)
        return (1375);      /* i_ib[1], two level-0 children, two data blocks */

    /* ---- AND NOW THE WALK THAT NOTHING HAS EVER RUN ------------------- */
    if (ufs_itrunc(gip, (off_t)0, 0, &grel) != 0)
        return (1376);
    if (grel != 5L)
        return (1377);      /* the level-1 walk counted the wrong tree */
    if (gump->um_sb.sb_tfree != before)
        return (1378);      /* THE RECLAIM LEAKED through the double indirect */
    if (gip->i_addr[NDADDR + 1] != (daddr_t)0)
        return (1379);      /* i_ib[1] survived its own truncate */

    /* ---- PUT SLOT 40 BACK ---------------------------------------------- */
    gip->i_nlink = 0;
    gip->i_flag |= ICHG;
    iput(gip);              /* last reference -> VOP_INACTIVE -> ifree */

    slot = itoo((ino_t)40) * UFS_DINODESIZE;
    if (bread(devvp, itod((ino_t)40), &bp) != 0) {
        brelse(bp);
        return (1380);
    }
    for (i = 0; i < UFS_DINODESIZE; i++)
        bp->b_addr[slot + i] = (char)0;
    if (bwrite(bp) != 0)
        return (1380);

    return (0);
}


int
ufs_probe(dev, fsblk)
    int     dev;
    daddr_t fsblk;
{
    struct vnode *devvp;

    /* IDENTIFY THE VOLUME BEFORE WRITING A SINGLE BYTE -- the same check and
     * the same two superblock words every writing gate here makes, for the
     * same reason: a device index is not proof of which image answers. */
    if (rawio(dev, (daddr_t)2, PROBE_READ) != 0)
        return (60);
    if (probebuf[0] != (char)0x42 || probebuf[1] != (char)0x00 ||
        probebuf[4] != (char)0x00 || probebuf[5] != (char)0x10)
        return (61);

    if (bdevvp(dev, &devvp) != 0)
        return (62);

    {
        static struct mount    pmnt;
        static struct ufsmount pump;
        int                    g;

        vref(devvp);
        if (ufs_mountfs(devvp, &pmnt, &pump) != 0)
            return (1290);

        if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
            return (1291);
        g = devguard(dev, devvp, &pmnt);
        if (g == 0)
            g = indirguard(dev, devvp, &pmnt);
        /* The blocks go back with the superblock, exactly as the directory
         * guards' do; the i-list slots devguard zeroed are its own. */
        if (ufs_sbupdate(devvp, &probesb) != 0)
            return (1292);
        if (g)
            return (g);

        /* Out of service first: ufs_unmount calls vflush, and vflush asserts
         * MNT_MPBUSY (Reno's panic, vfs_subr.c:537).  Reno's publisher is
         * vfs_busy; FGX's is vfs_dounmount, which a probe does not go through
         * because it drives the vector on a mount of its own.  See
         * ufs_wprobe.c's copy of this for the whole reasoning, and
         * apple/fgx#272 for what it cost. */
        pmnt.mnt_flag |= MNT_MPBUSY;
        if (VFS_UNMOUNT(&pmnt, 0) != 0)
            return (1293);
    }

    vrele(devvp);
    return (0);
}
