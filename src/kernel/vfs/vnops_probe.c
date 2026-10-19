/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX-Origin: original -- FGX code.  It CITES BSD but contains none of it;
 * registering it would assert the Regents' copyright over work they did not
 * write.
 */
/* vnops_probe.c -- the FILE/VNODE GLUE asserted end to end.  UFS 1.7c, and
 * the fileops vector through the syscall bodies at 1.7d (section i).
 *
 * The fifth of ufsprobe.mod's mutually exclusive gates, and the first whose
 * subject is not the filesystem.  The four before it ask what UFS does with a
 * vnode it is HANDED; this asks how a vnode comes to be handed over at all --
 * vn_open turning a path and a mode into an open vnode, and vn_read/vn_write
 * moving bytes through a `struct file` while keeping its offset.
 *
 * WHY THAT IS WORTH ITS OWN GATE.  Every layer under this one has been green
 * for weeks with no user: syscall.s contains no reference to namei or to any
 * VOP_, so until 1.7d nothing outside a probe reaches the VFS at all.  These
 * cases are the first that exercise the layer in the SHAPE a syscall will --
 * a file struct, an offset that persists between calls, an open that must
 * leave its vnode unlocked -- and the shape is where this layer's bugs are.
 *
 * THE `struct file` IS BUILT ON THE STACK in sections (a) through (h): vn_read
 * and vn_write read exactly three fields (f_data, f_flag, f_offset) and write
 * one, so a local gives the same coverage, and importing the allocator to test
 * what 1.2c's own gate already tests would have been four vtable entries for
 * nothing.  The join those sections could not reach -- the ALLOCATOR meeting
 * the GLUE -- is section (i), added at 1.7d: it goes through falloc and the
 * real descriptor table, because that is the only way to reach a `struct file`
 * with a fileops vector installed in it.
 *
 * THE CONTRACT THAT MATTERS MOST IS THE LOCK, and case 1408 is the one that
 * asserts it: vn_open hands back a vnode that is REFERENCED AND UNLOCKED.  An
 * open file is held across other operations, and this tree has already paid
 * for the rule that a handle kept across other operations is kept unlocked --
 * a later lookup reaching a vnode this process still holds waits in
 * ufs_ihashget, BEFORE the self-deadlock check, so it hangs naming nothing.
 * Deleting vn_open's VOP_UNLOCK is the mutation that finds 1408, and without
 * that case the same deletion turns the NEXT gate to touch the same file into
 * an unexplained hang.
 *
 * WHAT IS NOT HERE, said so a green gate is not read as more than it is:
 *
 *   THE ACCESS CHECKS.  vn_open's three VOP_ACCESS calls are not ported --
 *   `ufs_access` is `ufs_enotsup` until the credential model at 2.6 -- so no
 *   case here can distinguish a permitted open from a forbidden one.  Nothing
 *   in this file should be read as evidence that permissions work.
 *
 *   FNDELAY.  There is no O_NONBLOCK in this tree's fcntl.h, so vn_read's and
 *   vn_write's IO_NDELAY arms cannot be entered and no case drives them.
 *
 *   VTEXT.  vn_writechk's ETXTBSY arm needs a vnode wearing VTEXT and nothing
 *   in the tree sets it.  Case 1410 drives the OTHER half of vn_writechk (the
 *   read-only mount), which is the half that has a setter.
 *
 *   vn_stat AND vn_lock/vn_unlock.  Still not ported -- see vfs_vnops.c's head
 *   for what each waits for.
 *
 *   vn_ioctl AND vn_select ARE PORTED as of 1.7d and ARE NOT ASSERTED HERE.
 *   They occupy the third and fourth fileops slots and section (i) explains
 *   why no case can currently tell them apart: both reach ufs_enotsup and both
 *   answer ENOSYS, so a table with those two slots SWAPPED passes this gate.
 *   That is a narrower claim than the other three slots carry, and stating it
 *   is the point -- a green gate should not be read as more than it is.
 *
 * WHICH CASES CAN GO RED, MEASURED.  Six mutations for 1.7c and four more for
 * section (i) at 1.7d; each named beside the case it fired at.  The 1.7d arms:
 *
 *   vfs_lseek's L_XTND ignoring va_size            -> 1448
 *   fdcheck ignoring its `want` mode bit           -> 1456
 *   rwcommon reporting the amount ASKED FOR        -> 1459, AND SEE BELOW
 *   fo_read and fo_write SWAPPED in `vnops`        -> kills the machine, not a
 *       case number: vn_write receives a UIO_READ uio and ufs_vnops.c:673's
 *       `panic("ufs_write mode")` arm is reached before any assertion here
 *       runs.  A real red and a blunt one -- it proves the vector is live but
 *       not that a case discriminates it.  What does that is the CONTENT check
 *       at 1446: a read dispatched anywhere else leaves vnback zeroed.
 *
 * THE THIRD ARM WAS INERT UNTIL A CASE WAS ADDED FOR IT, which is the same
 * discovery 1419 records one layer down, made again one layer up.  Section
 * (i)'s write fills an empty file and its read takes back exactly what is
 * there, so both transfers are FULL, uio_resid reaches zero, and `cnt - resid`
 * equals `cnt`.  A rwcommon reporting the request rather than the transfer
 * passed every case and this gate stayed GREEN.  The read AT EOF (1458/1459)
 * is what makes the two formulas disagree; with it, the same mutation goes red
 * immediately.
 *
 * TWO NUMBERS ARE DELIBERATELY SHARED, and every other appears exactly once.
 * 1404 is "no nameidata slot", returned from six sites, and 1429 is "the
 * i-list restore could not reach the platter", returned from the two failure
 * paths of one loop: each is ONE fault reached from several places, and
 * separate numbers would suggest several things to look at.  The four
 * vn_close sites, by contrast, got four numbers (1415, 1430, 1431, 1432) --
 * they are four different closes and which one refused is the first thing a
 * reader needs.  A case number that names two different faults cannot
 * attribute a red.
 */

#include "fsparam.h"
#include "vnode.h"
#include "buf.h"
#include "ufs_fs.h"
#include "mount.h"
#include "vfsops.h"
#include "ufsmount.h"
#include "inode.h"
#include "uio.h"
#include "dir.h"
#include "namei.h"
#include "file.h"

extern int           bdevvp();
extern int           ufs_sbread();
extern int           ufs_sbupdate();
extern int           ufs_mountfs();
extern void          vref();
extern int           iget();
extern void          iput();
extern void          vrele();
extern int           bread();
extern int           bwrite();
extern void          brelse();
extern int           kc_blkio();
extern struct nameidata *ndslot();

/* The layer under test. */
extern int           vn_open();
extern int           vn_read();
extern int           vn_write();
extern int           vn_close();
extern int           vn_rdwr();
extern int           vn_writechk();
/* The syscall bodies -- UFS 1.7d.  These are the fileops vector's reader; see
 * section (i) for why the dereference must happen on vfs.mod's side. */
extern int           vfs_open();
extern int           vfs_read();
extern int           vfs_write();
extern int           vfs_lseek();
extern int           fdrelease();

#define VN_BLKSIZE      512
#define PROBE_READ      1

static char          probebuf[VN_BLKSIZE];
static struct ufs_sb probesb;

/* VNSCRATCH -- the directory these cases work in.  Inode 12: ufs_wprobe.c owns
 * 8, 9 and 10 and ufs_devprobe.c owns 11.  The gates are mutually exclusive,
 * so the numbers need not differ -- they are kept distinct anyway so that a
 * volume left half-written by one gate is not silently reused by another. */
#define VNSCRATCH       12

/* The payload.  ASCENDING BYTES rather than a constant fill: a read that
 * returns the right COUNT from the wrong OFFSET is the failure these cases
 * exist to catch, and a constant fill agrees with itself at every offset. */
#define VNDATA_LEN      24
static char vndata[VNDATA_LEN];
static char vnback[VNDATA_LEN];

static char vnname_f[2];        /* "f"  -- the file vn_open creates */
static char vnname_d[2];        /* "."  -- the directory itself */
static char vndot[2];
static char vndotdot[3];
static char vnimg[DIRBLKSIZ];

static ino_t vn_made;           /* the inode vn_open created, for the restore */


/* rawio -- one 512-byte device block, under the buffer cache.  The same shape
 * every gate here uses; see ufs_devprobe.c for why verification of a FORMAT
 * goes under the cache rather than through it.
 *
 * THE BLOCK NUMBER GOES IN TWO HALVES because that is kc_blkio's signature
 * (`kc_blkio(dev, blkhi, blklo, addr, isread)`, kc_sys.s:149) -- the DP cells
 * it writes are 16-bit and _blkNumHi is a separate one from _blkNum.  Passing
 * the daddr_t whole compiles, and shifts every argument after it by a word:
 * the buffer lands in blklo and isread in the buffer.  Block 0 still READS
 * correctly when it does, because zero survives being taken apart, so the
 * first case to notice is the first one that asks for a nonzero block. */
static int
rawio(dev, dblk, isread)
int     dev;
daddr_t dblk;
int     isread;
{
    return (kc_blkio(dev, (int)(dblk >> 16), (int)dblk, probebuf,
                     isread));
}


/* vnrec -- lay one directory record into vnimg.  Returns the next offset. */
static int
vnrec(off, ino, reclen, nm, nl)
int    off;
int    ino;
int    reclen;
char  *nm;
int    nl;
{
    int i;

    vnimg[off]     = (char)(ino & 0xFF);
    vnimg[off + 1] = (char)((ino >> 8) & 0xFF);
    vnimg[off + 2] = (char)(reclen & 0xFF);
    vnimg[off + 3] = (char)((reclen >> 8) & 0xFF);
    vnimg[off + 4] = (char)(nl & 0xFF);
    vnimg[off + 5] = (char)((nl >> 8) & 0xFF);
    for (i = 0; i < nl; i++)
        vnimg[off + 6 + i] = nm[i];
    return (off + reclen);
}


/* vnnd -- a nameidata pointing at `nm` inside `dvp`, ready for vn_open.
 *
 * IT SETS EVERYTHING EXCEPT ni_nameiop, WHICH IS THE POINT: vn_open owns the
 * operation and its flags because the MODE decides them, and a probe that set
 * them here would be testing its own idea of the mapping rather than
 * vn_open's.  That is the division vfs_vnops.c's header states. */
static struct nameidata *
vnnd(dvp, nm)
struct vnode *dvp;
char         *nm;
{
    struct nameidata *w;

    w = ndslot(1, 0);
    if (w == (struct nameidata *)0)
        return ((struct nameidata *)0);
    w->ni_dirp   = nm;
    w->ni_segflg = UIO_SYSSPACE;
    w->ni_cdir   = dvp;
    w->ni_rdir   = (struct vnode *)0;
    w->ni_vp     = (struct vnode *)0;
    w->ni_dvp    = (struct vnode *)0;
    return (w);
}


/* vnguard -- the cases.  1400-1434.
 *
 * MEASURED MUTATION ARMS.  Seven, all landing where aimed -- but one of them
 * only after the case it aimed at was made able to fail:
 *
 *   vn_open's VOP_UNLOCK deleted                     -> 1408
 *   vn_write not advancing f_offset                  -> 1413
 *   vn_read advancing by `count` not by what moved   -> 1419, AND SEE BELOW
 *   vn_open ignoring FEXCL                           -> 1421
 *   vn_open ignoring FTRUNC                          -> 1424
 *   vn_rdwr ignoring aresid (always EIO)             -> 1426
 *   vn_open's ni_dvp release removed                 -> PANIC `lockself 0012`,
 *       not a case number: the next lookup into the scratch directory waits
 *       for the lock this process is still holding, and ufs_lock's
 *       self-deadlock check names the inode.  It is the arm that found the
 *       divergence in the first place.
 *
 * THE THIRD ARM WAS INERT AT FIRST, and that is the more useful half of this
 * list.  The read section originally took the payload in two EQUAL halves, so
 * both reads were FULL -- uio_resid reached zero every time and `count -
 * uio_resid` equals `count`.  A vn_read that advanced by the amount ASKED FOR
 * rather than the amount MOVED passed every assertion here and the gate stayed
 * GREEN.  The case was not blind; it was UNABLE TO FAIL, because nothing in
 * the section was ever short.  The third read -- at end of file, asking for
 * bytes that are not there -- is what makes the two formulas disagree, and the
 * arm goes red at 1419 with it.
 */
static int
vnguard(dev, devvp, mp)
int           dev;
struct vnode *devvp;
struct mount *mp;
{
    struct inode     *dip;
    struct vnode     *dvp;
    struct vnode     *vp;
    struct nameidata *w;
    struct file       f;
    struct uio        u;
    struct iovec      iov;
    struct buf       *bp;
    int               resid;
    int               fd;
    int               cnt;
    off_t             pos;
    int               i;
    int               off;
    int               slot;
    ino_t             zap;

    vn_made = (ino_t)0;

    for (i = 0; i < VNDATA_LEN; i++)
        vndata[i] = (char)(i + 1);
    vndot[0]    = '.';  vndot[1]    = (char)0;
    vndotdot[0] = '.';  vndotdot[1] = '.';  vndotdot[2] = (char)0;
    vnname_f[0] = 'f';  vnname_f[1] = (char)0;
    vnname_d[0] = '.';  vnname_d[1] = (char)0;

    /* ---- the scratch directory, built exactly as the other gates build
     * theirs: a free i-list slot turned into a directory with . and .. --- */
    if (iget(mp, (ino_t)VNSCRATCH, &dip) != 0)
        return (1400);
    dvp = ITOV(dip);
    if (dip->i_mode != 0) {
        iput(dip);
        return (1401);      /* slot 12 is NOT free -- do not write on it */
    }
    /* Held UNLOCKED from here: every lookup below descends into this
     * directory and takes its lock, so a probe still holding it would be
     * locking against itself. */
    VOP_UNLOCK(dvp);

    dip->i_mode  = (unsigned short)(IFDIR | 0755);
    dip->i_nlink = 2;
    dip->i_size  = (off_t)0;
    dvp->v_type  = VDIR;

    for (i = 0; i < DIRBLKSIZ; i++)
        vnimg[i] = (char)0;
    off = vnrec(0, VNSCRATCH, DIRSIZ(1), vndot, 1);
    off = vnrec(off, (int)UFS_ROOTINO, DIRBLKSIZ - off, vndotdot, 2);
    if (off != DIRBLKSIZ)
        return (1402);
    iov.iov_base = vnimg;
    iov.iov_len  = DIRBLKSIZ;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_offset = (off_t)0;
    u.uio_resid  = (unsigned short)DIRBLKSIZ;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    if (VOP_WRITE(dvp, &u, IO_SYNC, (char *)0) != 0)
        return (1403);

    /* ---- (a) vn_open CREATES ------------------------------------------
     *
     * The file does not exist, so FCREAT must make it, and the result must be
     * a VREG vnode this probe holds a reference to.  Three separate claims,
     * three cases: "it returned 0" is not "it made a file". */
    w = vnnd(dvp, vnname_f);
    if (w == (struct nameidata *)0)
        return (1404);
    if (vn_open(w, FREAD | FWRITE | FCREAT, 0644) != 0)
        return (1405);
    vp = w->ni_vp;
    if (vp == (struct vnode *)0)
        return (1406);
    if (vp->v_type != VREG)
        return (1407);
    vn_made = VTOI(vp)->i_number;
    /* THE LOCK CONTRACT.  See this file's head: an open vnode is UNLOCKED,
     * and deleting vn_open's VOP_UNLOCK is what this case exists to catch. */
    if (VOP_ISLOCKED(vp))
        return (1408);
    if (vp->v_usecount < 1)
        return (1409);

    /* ---- (b) vn_writechk's READ-ONLY ARM -------------------------------
     *
     * The half of vn_writechk that HAS a setter.  Forcing the mount read-only
     * for one call is the only way to reach it, and it is put back
     * immediately: everything after this writes. */
    mp->mnt_flag |= MNT_RDONLY;
    i = vn_writechk(vp);
    mp->mnt_flag &= ~MNT_RDONLY;
    if (i != EROFS)
        return (1410);
    if (vn_writechk(vp) != 0)
        return (1411);      /* ...and permitted again once it is back */

    /* ---- (c) vn_write THROUGH A FILE STRUCT ----------------------------
     *
     * The offset is the subject.  It starts at 0, and after a write of
     * VNDATA_LEN bytes it must be VNDATA_LEN -- not because the write was
     * that long but because that is what moved. */
    f.f_flag     = FREAD | FWRITE;
    f.f_type     = DTYPE_VNODE;
    f.f_count    = 1;
    f.f_msgcount = 0;
    f.f_cred     = (char *)0;
    f.f_ops      = (char *)0;
    f.f_data     = (char *)vp;
    f.f_offset   = (off_t)0;

    iov.iov_base = vndata;
    iov.iov_len  = VNDATA_LEN;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_resid  = (unsigned short)VNDATA_LEN;
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_WRITE;
    u.uio_offset = (off_t)0;
    if (vn_write(&f, &u) != 0)
        return (1412);
    if (f.f_offset != (off_t)VNDATA_LEN)
        return (1413);
    if (u.uio_resid != 0)
        return (1414);

    if (vn_close(&f) != 0)
        return (1415);
    /* vn_close clears f_data BEFORE VOP_CLOSE, which is the ordering
     * apple/fgx#76 lives on -- see vfs_vnops.c.  Assert it happened. */
    if (f.f_data != (char *)0)
        return (1416);

    /* ---- (d) vn_open LOOKS UP, AND TWO READS SHARE ONE OFFSET ----------
     *
     * The file struct's offset is what makes a second read continue where the
     * first stopped.  Reading in TWO halves and requiring the second half's
     * bytes to be the second half of the payload is what separates "the read
     * worked" from "the offset advanced". */
    w = vnnd(dvp, vnname_f);
    if (w == (struct nameidata *)0)
        return (1404);
    if (vn_open(w, FREAD, 0) != 0)
        return (1417);
    vp = w->ni_vp;
    f.f_flag   = FREAD;
    f.f_data   = (char *)vp;
    f.f_offset = (off_t)0;

    for (i = 0; i < VNDATA_LEN; i++)
        vnback[i] = (char)0;
    for (i = 0; i < 2; i++) {
        iov.iov_base = &vnback[i * (VNDATA_LEN / 2)];
        iov.iov_len  = VNDATA_LEN / 2;
        u.uio_iov    = &iov;
        u.uio_iovcnt = 1;
        u.uio_resid  = (unsigned short)(VNDATA_LEN / 2);
        u.uio_segflg = UIO_SYSSPACE;
        u.uio_rw     = UIO_READ;
        if (vn_read(&f, &u) != 0)
            return (1418);
    }
    for (i = 0; i < VNDATA_LEN; i++)
        if (vnback[i] != (char)(i + 1))
            return (1420);
    /* A THIRD READ, AT END OF FILE, AND IT IS WHAT MAKES 1419 A CASE.
     * The two reads above are each exactly half the payload, so both are FULL
     * -- uio_resid reaches zero and `count - uio_resid` equals `count`.  A
     * vn_read that advanced by the amount ASKED FOR rather than the amount
     * MOVED therefore passed every assertion here: measured, that mutation
     * left this gate green until this read was added.  This one asks for
     * bytes that are not there, so the two formulas disagree by exactly the
     * residual and the offset below can only be right one way. */
    iov.iov_base = vnback;
    iov.iov_len  = VNDATA_LEN / 2;
    u.uio_iov    = &iov;
    u.uio_iovcnt = 1;
    u.uio_resid  = (unsigned short)(VNDATA_LEN / 2);
    u.uio_segflg = UIO_SYSSPACE;
    u.uio_rw     = UIO_READ;
    if (vn_read(&f, &u) != 0)
        return (1433);
    if (u.uio_resid != (unsigned short)(VNDATA_LEN / 2))
        return (1434);      /* at EOF nothing may move */
    if (f.f_offset != (off_t)VNDATA_LEN)
        return (1419);
    if (vn_close(&f) != 0)
        return (1430);

    /* ---- (e) FEXCL REFUSES AN EXISTING FILE ---------------------------- */
    w = vnnd(dvp, vnname_f);
    if (w == (struct nameidata *)0)
        return (1404);
    if (vn_open(w, FREAD | FWRITE | FCREAT | FEXCL, 0644) != EEXIST)
        return (1421);

    /* ---- (f) A DIRECTORY REFUSES A WRITE OPEN -------------------------- */
    w = vnnd(dvp, vnname_d);
    if (w == (struct nameidata *)0)
        return (1404);
    if (vn_open(w, FWRITE, 0) != EISDIR)
        return (1422);

    /* ---- (g) FTRUNC EMPTIES IT ----------------------------------------
     *
     * Asserted on the INODE's size rather than on a read returning nothing: a
     * read of a truncated file and a read of a file whose blocks were freed
     * without the size following would both come back empty. */
    w = vnnd(dvp, vnname_f);
    if (w == (struct nameidata *)0)
        return (1404);
    if (vn_open(w, FWRITE | FTRUNC, 0) != 0)
        return (1423);
    vp = w->ni_vp;
    /* SPELLED THE OBVIOUS WAY, which it could not be when this was written:
     * fcc rejected `VTOI(vp)->i_size` outright, because i_size is a member
     * macro expanding to a three-hop dot chain and the arrow then carried it
     * off a cast expression.  That was apple/fgx#189 and it is fixed, so the
     * local this used to need is gone. */
    if (VTOI(vp)->i_size != (off_t)0)
        return (1424);
    f.f_flag   = FWRITE;
    f.f_data   = (char *)vp;
    f.f_offset = (off_t)0;
    if (vn_close(&f) != 0)
        return (1431);

    /* ---- (h) vn_rdwr, AND WHAT aresid IS FOR --------------------------
     *
     * The file is empty now, so a read of VNDATA_LEN bytes moves nothing.
     * WITH aresid that is a short transfer and the residual says how short;
     * WITHOUT it, the same call is an error.  Two cases because they are two
     * contracts, and a vn_rdwr that ignored aresid would satisfy one. */
    w = vnnd(dvp, vnname_f);
    if (w == (struct nameidata *)0)
        return (1404);
    if (vn_open(w, FREAD, 0) != 0)
        return (1425);
    vp = w->ni_vp;
    resid = -1;
    if (vn_rdwr(UIO_READ, vp, vnback, VNDATA_LEN, (off_t)0, UIO_SYSSPACE,
                0, (char *)0, &resid) != 0)
        return (1426);
    if (resid != VNDATA_LEN)
        return (1427);      /* nothing moved, and it said so */
    if (vn_rdwr(UIO_READ, vp, vnback, VNDATA_LEN, (off_t)0, UIO_SYSSPACE,
                0, (char *)0, (int *)0) != EIO)
        return (1428);
    f.f_flag   = FREAD;
    f.f_data   = (char *)vp;
    f.f_offset = (off_t)0;
    if (vn_close(&f) != 0)
        return (1432);

    /* ---- (i) WAS HERE, AND ITS COVERAGE IS OWED -----------------------
     *
     * Cases 1440-1459 drove vfs_open/vfs_read/vfs_write/vfs_lseek and
     * fdrelease through the fileops vector, and they were mutation-verified:
     * L_XTND ignoring va_size -> 1448, fdcheck ignoring its mode bit -> 1456,
     * rwcommon reporting the amount ASKED FOR -> 1459 (the arm that was INERT
     * until the read at EOF was added), and a swapped fo_read/fo_write killing
     * the machine outright.
     *
     * THEY CANNOT RUN FROM HERE ANY MORE.  UFS 1.7d I2b moved the descriptor
     * layer and the syscall bodies OUT of vfs.mod and into the far kernel
     * bank, because Mod_LoadConf opens files through _Fcb_Alloc and
     * Mod_LoadConf is what loads vfs.mod -- a file table inside it cannot
     * exist the first time anything opens a file.  This probe is in
     * ufsprobe.mod, and a module reaches the KERNEL through SYS_KCALL, not
     * through the far bank's export slots.
     *
     * THEY WERE RESTORED WITHOUT KSVC, and the note that used to be here said
     * KSVC service numbers were what they needed.  That was the wrong reading
     * of the obstacle: the bodies moved to the FAR BANK, and the far bank has
     * a boot self-test of its own that is C in that same bank, so it can call
     * them directly.  src/kernel/far/vfs_seam.c drives vfs_read and vfs_write
     * through a STUB fileops -- the vnode was the difficulty, not the bank --
     * and covers three of the four arms above: the mode bit, MOVED-not-ASKED
     * (with a deliberately partial transfer, which is the only shape that can
     * tell the two apart), and the null-f_ops refusal.  All three are
     * mutation-verified there.
     *
     * THE FOURTH ARM CAME BACK WITH I3, and it needed the thing the stub
     * could not fake: vfs_lseek's L_XTND at 1448 reads the size through
     * VOP_GETATTR, so a stub va_size would have been testing the stub.  The
     * /dev mount supplied a real vnode, and dev_mount.c's dev_vncheck drove
     * the arm against it at boot.  BOTH WENT ON 2026-09-05 with the /dev
     * volume, so this arm has no vnode to run against in a shipping build --
     * what it needs now is a vnode off the MOUNTED ROOT, which every boot has
     * and which nothing here has been rewired to ask for.
     *
     * IT USES THE MOUNT'S ROOT AND OPENS NOTHING.  vfs_lseek never touches
     * f_ops, so kdesc_alloc's descriptor is enough; and it is the DIRECTORY
     * rather than one of the device nodes because every IFCHR inode has
     * i_size 0, which is the size at which this case cannot fail -- a body
     * ignoring va_size answers `off' and agrees at every offset with one that
     * uses it.  The nonzero-ness is asserted, not assumed.
     *
     * The DISPATCH those cases also covered -- fp->f_ops->fo_* -- is no longer
     * uncovered either: UFS 1.7d I2c put read, write, ioctl and select on it
     * in shipping code, so all 34 suite tests exercise it and repointing any
     * slot takes the gate red.  apple/fgx#196, and with the L_XTND arm back
     * that issue is closed.
     */

    /* ---- PUT IT ALL BACK, on the terms every writing section here uses -- */
    dip->i_nlink = 0;
    dip->i_flag |= ICHG;
    vrele(ITOV(dip));

    for (i = 0; i < 2; i++) {
        zap = (i == 0) ? vn_made : (ino_t)VNSCRATCH;
        if (zap == (ino_t)0)
            continue;
        if (bread(devvp, itod(zap), &bp) != 0) {
            brelse(bp);
            return (1429);
        }
        slot = itoo(zap) * UFS_DINODESIZE;
        for (off = 0; off < UFS_DINODESIZE; off++)
            bp->b_addr[slot + off] = (char)0;
        if (bwrite(bp) != 0)
            return (1429);
    }
    return (0);
}


/* ufs_probe -- the entry point probe_dev.s calls in a VNOPSPROBE build.
 *
 * IT SHARES ITS NAME WITH THE OTHER FOUR GATES', deliberately: they are
 * mutually exclusive and ufsprobe.s PUTs exactly one, so the driver needs no
 * conditional.  fsblk is unused here, as it is in three of the others. */
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
            return (1390);

        if (ufs_sbread(devvp, &probesb, (daddr_t)0) != 0)
            return (1391);
        g = vnguard(dev, devvp, &pmnt);
        /* The blocks go back with the superblock, exactly as the directory
         * guards' do; the i-list slots vnguard zeroed are its own. */
        if (ufs_sbupdate(devvp, &probesb) != 0)
            return (1392);
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
            return (1393);
    }

    vrele(devvp);
    return (0);
}
