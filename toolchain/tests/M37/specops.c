/* specops.c -- UFS 1.5: specfs, on real hardware.
 *
 * WHAT THIS SLICE IS ABOUT.  A device node is a file in some filesystem and a
 * reference to a driver at the same time.  specfs is how BSD keeps those apart:
 * the vnode keeps its inode and its filesystem's tag, but wears specfs's
 * VECTOR, so every operation on it is answered by the device layer rather than
 * by the filesystem that merely names it.
 *
 * THE VECTOR IS THE THING UNDER TEST, AND IT IS POSITIONAL.  Thirty-two slots
 * initialised in order, dispatched through a struct field offset -- two
 * recorded fcc defect families meet exactly there (far function pointers in a
 * DATA INITIALIZER, and struct fn-ptr field offset drift past 120 bytes).  A
 * vector off by one slot still runs something and still returns a number, so
 * every assertion below names the slot it is checking through the VOP_ macro
 * that reaches it, not by calling spec_* directly.  Calling the functions by
 * name would test the functions and skip the layout, which is the half that
 * has actually broken here before.
 *
 * THE THREE FAILURE MODES ARE NOT INTERCHANGEABLE, and telling them apart is
 * most of what a spec vector is:
 *
 *   spec_badop    meaningless on a device -- creating a file inside /dev/rd0.
 *                 Panics; there is no correct errno for "cannot be asked".
 *   spec_ebadf    meaningful, but not through this vnode.  EBADF.
 *   spec_nullop   meaningful, and there is genuinely nothing to do.  Zero.
 *
 * A vector that answered every one of them with zero would pass a test that
 * only asked "did it return".
 *
 * Exit 42 = pass; 99 = a panic stub was reached; every other value is
 * 50 + the case number, so no failure can land on the pass code.
 */

#include "../../../src/kernel/vfs/fsparam.h"
#include "../../../src/kernel/vfs/vnode.h"
#include "../../../src/kernel/vfs/mount.h"
#include "../../../src/kernel/vfs/specdev.h"
#include "../../../src/kernel/vfs/buf.h"
#include "../../../src/kernel/vfs/uio.h"

/* PANICS ARE COUNTED, NOT FATAL.  spec_badop panics by design and this file
 * has to prove it does -- so the stub records the call and returns, and the
 * cases that expect one check the counter.  A stub that exited would make the
 * first badop assertion the last thing this fixture ever tested.
 *
 * The trade is that a panic which was NOT expected returns instead of exiting,
 * so the final case asserts the total: any extra panic anywhere shows up as a
 * count that does not match, and the fixture fails. */
static int npanic = 0;
static int nslept = 0;

void kc_panic(msg)  char *msg;  { npanic++; }
void kc_sleep(chan) char *chan; { nslept++; }
void kc_wakeup(chan) char *chan; { }
/* UFS 1.2: vfs_subr.c's ndget asks the kernel which process is running.
 * A fixture is single-process, so pid 1 -- a VALID pid, not a sentinel:
 * ndslot refuses anything outside 1..VFS_NPROC, so 0 here would make
 * every ndget return null and the fixture would test the refusal path
 * instead of the thing it is about. */
int kc_curpid() { return (1); }

/* THE CHARACTER DEVICE REGISTRY, faked (UFS 1.13b).  spec_vnops.c's VCHR arms
 * dispatch through these four; on the machine they are KSVC shims onto
 * src/kernel/chardev.s, and here they are a counted /dev/null: read is
 * immediate EOF, write accepts and discards, open and close succeed.
 *
 * THE COUNTS ARE THE POINT, not the behaviour.  What this fixture can see and
 * the on-target probe cannot is how MANY times the arm reached the driver --
 * the probe observes a uio and infers the loop, while these say it directly.
 * cd_last_idx is here for the same reason: a spec arm that dispatched the
 * wrong device index would satisfy every uio assertion. */
static int cd_opens   = 0;
static int cd_closes  = 0;
static int cd_reads   = 0;
static int cd_writes  = 0;
static int cd_last_idx = -1;
static int cd_last_byte = -1;

int kc_cdopen(idx)  int idx; { cd_opens++;  cd_last_idx = idx; return (0); }
int kc_cdclose(idx) int idx; { cd_closes++; cd_last_idx = idx; return (0); }
/* status 1 in the high byte: end of file, which is /dev/null's read. */
/* THE ioflag IS THE FOURTH ARGUMENT OF cdevsw's d_read upstream and the third
 * of these seam ops here (apple/fgx#310).  The stubs record it so a caller
 * that drops it -- which spec_read did, for a VCHR vnode -- is visible to a
 * host fixture rather than only to a machine that blocks for ever. */
int cd_last_flag  = -1;
int cd_dlast_flag = -1;

int kc_cdread(idx, flag)  int idx; int flag;
{ cd_reads++;  cd_last_idx = idx; cd_last_flag = flag; return (0x0100); }
int kc_cdwrite(idx, b, flag) int idx; int b; int flag;
{
    cd_writes++;
    cd_last_idx  = idx;
    cd_last_byte = b;
    cd_last_flag = flag;
    return (0);
}

/* THE BULK ARMS, faked too -- cdevsw's d_read / d_write (apple/fgx#108 T2.2b).
 * On the machine these are KSVC_CDDREAD / KSVC_CDDWRITE onto _Chardev_Bulk,
 * which bounds-checks the index, tests whether the device fills the slot, and
 * only then dispatches.  The answer is a STATUS BYTE over a value, never an
 * errno sentinel: nodev() in the line-discipline switch returns ENODEV, and
 * that switch is where tty bulk reads route once the discipline lands, so
 * "this device has no bulk op" and "the driver refused" must not be the same
 * word.
 *
 *   0x00xx  the op ran; the low byte is its errno, 0 for success
 *   0x0100  the device has no bulk op -- use the per-byte loop
 *   0x02xx  the index names no device; the low byte is ENODEV
 *
 * cd_dstatus is what the fake answers, so the three arms can each be driven.
 * The COUNTS are the point here exactly as they are for the per-byte pair:
 * whether the per-byte loop ALSO ran behind a bulk op that already filled the
 * buffer is apple/fgx#198's silent half, and it is invisible from a uio. */
static int cd_dreads    = 0;
static int cd_dwrites   = 0;
static int cd_dlast_idx = -1;
static int cd_dstatus   = 0x0100;

int kc_cddread(idx, uio, flag) int idx; struct uio *uio; int flag;
{
    cd_dreads++;
    cd_dlast_idx  = idx;
    cd_dlast_flag = flag;
    return (cd_dstatus);
}

int kc_cddwrite(idx, uio, flag) int idx; struct uio *uio; int flag;
{
    cd_dwrites++;
    cd_dlast_idx  = idx;
    cd_dlast_flag = flag;
    return (cd_dstatus);
}

/* d_ioctl AND d_select, faked (UFS 1.7d I4).  On the machine these are
 * KSVC_CDIOCTL / KSVC_CDPOLL onto _Chardev_Ioctl / _Chardev_Poll; here they
 * are a device whose answers the test chooses.
 *
 * THIS IS WHERE THE IOCTL ARM CAN ACTUALLY BE PROVEN, and ufs_devprobe says so
 * against itself: every chardev that probe can reach answers ENOTTY to every
 * command, and ENOTTY is also what spec_ioctl returns for a vnode that is not
 * a device -- so on target a stubbed `return (ENOTTY)' passes.  Here the
 * device's answer is a variable and cd_last_idx says which device was asked,
 * so both halves of the claim are observable: the value came FROM the driver,
 * and from the RIGHT one.
 *
 * cd_pollmask is likewise the device's answer rather than a constant, which is
 * what lets one call ask for POLLIN and another for POLLOUT off the same mask
 * -- the `which' mapping is spec_select's own work and nothing else tests it. */
static int cd_ioctls   = 0;
static int cd_polls    = 0;
static int cd_ioctlret = ENOTTY;
static int cd_pollmask = 0;

int kc_cdioctl(idx) int idx; { cd_ioctls++; cd_last_idx = idx; return (cd_ioctlret); }
int kc_cdpoll(idx)  int idx; { cd_polls++;  cd_last_idx = idx; return (cd_pollmask); }

/* The block switch's two ops, d_close and d_ioctl (modules/common/
 * kc_blkdev.s).  Counted, with the dev each was given, for the same reason
 * the chardev ones are: a VBLK arm that stopped dispatching would otherwise
 * return the same 0 or ENOTTY these do. */
static int blk_closes   = 0;
static int blk_ioctls   = 0;
static int blk_last     = -1;
static int blk_ioctlret = ENOTTY;

int kc_blkstale(dev) int dev; { blk_closes++; blk_last = dev; return (0); }
int kc_blkioctl(dev) int dev; { blk_ioctls++; blk_last = dev; return (blk_ioctlret); }

void biodone();

/* A fake disk, as in biocache.c and vreclaim.c: one byte per block is enough
 * to say which bytes moved in which direction, and the CALL COUNT is what the
 * strategy assertions are really about. */
#define FAKEBLKS  64
static char fake_disk[FAKEBLKS];
static char fake_buf[4];
static struct iovec fake_iov;
static int  fake_reads  = 0;
static int  fake_writes = 0;

void
bio_strategy(bp)
    struct buf *bp;
{
    int b;

    b = (int)bp->b_blkno;
    if (b < 0 || b >= FAKEBLKS) {
        bp->b_flags |= B_ERROR; bp->b_error = EIO; biodone(bp); return;
    }
    if (bp->b_flags & B_READ) { fake_reads++;  bp->b_addr[0] = fake_disk[b]; }
    else                      { fake_writes++; fake_disk[b] = bp->b_addr[0]; }
    biodone(bp);
}

/* THE REAL FILES, all four.  Nothing here is faked: reclaim's own fixture
 * proved vfs_subr against a fake filesystem, and this one has to prove specfs
 * against the REAL vnode layer, because the claims are about how the two meet
 * -- bdevvp hands out a vnode wearing spec_vnodeops, and vgone tears one down
 * through it. */
#include "../../../src/kernel/vfs/vfs_bio.c"
#include "../../../src/kernel/vfs/dead_vnops.c"
/* uiomove, which spec_read and spec_write are built on since UFS 1.7b.  BEFORE
 * spec_vnops.c: definition ahead of use keeps the listing readable, the same
 * reason probefs precedes namei_probe in the module.  A fixture that includes
 * spec_vnops.c must supply this -- the link fails with "unresolved symbol
 * 'uiomove'" otherwise, which is how this was found. */
#include "../../../src/kernel/vfs/kern_subr.c"

/* uio_copy IS ASSEMBLY IN THE KERNEL, so a fixture that includes kern_subr.c
 * has to supply it -- src/modules/vfs/uio_copy.s is linked by vfs.mod and not
 * by anything here, and the link fails "unresolved symbol 'uio_copy'"
 * otherwise, which is how this was found.  Same reason the note above gives
 * for uiomove itself, one layer down.
 *
 * THE BYTE LOOP IS THE POINT: it is what the kernel's MVN replaced
 * (apple/fgx#307), and a fixture wants the portable spelling rather than a
 * second copy of the machine one.  What it must NOT do is differ in effect --
 * n bytes from src to dst, no overlap. */
void uio_copy(src, dst, n)
char *src;
char *dst;
int n;
{
    register int i;

    for (i = 0; i < n; i++)
        dst[i] = src[i];
}
#include "../../../src/kernel/vfs/spec_vnops.c"
/* dev_chrtoblk.c is GENERATED by tools/ninja/gen.py and is vfs.mod's
 * co-resident: spec_securechr calls it, and vfs_subr.c below defines
 * spec_securechr.  Composed here for the same reason the rest is --
 * the fixture links what the module links. */
#include "../../../src/kernel/vfs/dev_chrtoblk.c"
#include "../../../src/kernel/vfs/vfs_subr.c"
/* The name cache comes with it: getnewvnode mints a vnode's capability
 * number through cache_purge, which is where the counter WRAP is handled. */
#include "../../../src/kernel/vfs/vfs_cache.c"

/* The vnode and specinfo pools are heap-based since 2026-08-12: vntblinit
 * takes their base rather than declaring arrays, so a fixture supplies its
 * own.  Sized from the same two products tools/gen_vfs_equ.py sums for the
 * kernel; a static is fine because a fixture owns its whole bank.
 *
 * vntblinit is DECLARED, not left implicit: an implicit declaration returns
 * int and would drop the bank byte of the pointer it returns. */
static char vn_arena[VNODE_POOL * sizeof(struct vnode)
                   + NSPECINFO  * sizeof(struct specinfo)];
extern char *vntblinit();


char fixarena[NBUF * FS_BLKSIZE];

struct mount mnt_a;

static void
reset()
{
    bufinit(fixarena);
    vntblinit(vn_arena);
    /* THE HAND-OVER ufsdir's mod_init DOES ON THE MACHINE.  spec_vnops.c moved
     * into ufsdir.mod on 2026-09-05, so vfs_subr.c can no longer form
     * &spec_vnodeops itself: it holds a pointer that starts null, and bdevvp
     * and vflush's forced-unmount arm both REFUSE rather than dispatch through
     * a null table.  ufs_dirinit (src/kernel/vfs/ufs_vnops.c) passes the
     * address over; a fixture stands in for the whole kernel, so it passes it
     * over too, and in reset() because it is the pools' initialiser.
     *
     * Without this every bdevvp below returns ENXIO -- which is what case 1
     * reported from the day the refusal landed, the runtime oracle having been
     * unable to boot at the time. */
    vfs_setspecops(&spec_vnodeops);
    mnt_a.mnt_mounth = 0;
    mnt_a.mnt_flag = 0;
    npanic = 0;
    fake_reads = 0;
    fake_writes = 0;
}

#define DEV_A   ((dev_t)0x0201)   /* cd unit 1: a block major bdevsw has */

/* A device vnode THE WAY A FILESYSTEM MAKES ONE: a vnode of its own, tagged
 * with the filesystem that named it, handed to checkalias.
 *
 * Not bdevvp, and the difference is load-bearing for every alias case below.
 * bdevvp's vnode is VT_NON -- it belongs to no filesystem, because it exists
 * before one does -- and checkalias REVIVES such a vnode rather than aliasing
 * it: a second caller gets the same vnode back, which is the whole point of
 * that path and the opposite of what an alias test needs.  Two aliases exist
 * only when two FILESYSTEM vnodes name one device, which is two /dev entries.
 *
 * Returns 0 when nvp became an authority for the device, as checkalias does. */
static int
mkdevvn(vpp)
    struct vnode **vpp;
{
    struct vnode *nvp;

    if (getnewvnode(VT_UFS, &mnt_a, &spec_vnodeops, &nvp) != 0)
        return (-1);
    nvp->v_type = VBLK;
    *vpp = nvp;
    if (checkalias(nvp, DEV_A, &mnt_a) != 0)
        return (-2);                    /* revived something: not an alias */
    return (0);
}

main()
{
    struct vnode *vp, *v2;
    struct buf *bp;
    daddr_t bn;
    int n;
    /* For the read/write refusals below.  Only the fields those arms consult
     * before refusing are ever set -- none of these calls is meant to reach a
     * device, and the fixture has none. */
    struct uio u;

    /* ---- 1. bdevvp hands back a device vnode wearing THIS vector ---- */
    reset();
    if (bdevvp(DEV_A, &vp) != 0)                return (51);
    if (vp->v_op != &spec_vnodeops)             return (52);
    if (vp->v_type != VBLK)                     return (53);
    if (vp->v_rdev != DEV_A)                    return (54);

    /* ---- 2. THE SLOTS THAT MUST SUCCEED, reached through the macros ----
     * Every one of these dispatches through a different offset in a 128-byte
     * structure.  A vector shifted by one slot would answer some of them with
     * the neighbouring function and still return a plausible number, so the
     * values are checked, not merely the absence of a crash. */
    if (VOP_OPEN(vp, 0, (char *)0) != 0)        return (55);
    if (VOP_LOCK(vp) != 0)                      return (56);
    if (VOP_UNLOCK(vp) != 0)                    return (57);
    if (VOP_FSYNC(vp, 0, (char *)0, 0) != 0)    return (58);   /* nullop */
    if (VOP_ISLOCKED(vp) != 0)                  return (59);   /* nullop */
    if (VOP_PRINT(vp) != 0)                     return (60);
    if (VOP_SELECT(vp, 0, 0, (char *)0) != 1)   return (61);   /* always ready */
    if (VOP_IOCTL(vp, 0, (char *)0, 0, (char *)0) != ENOTTY)
        return (62);
    if (npanic != 0)                            return (63);   /* none so far */

    /* ---- 3. THE SLOTS THAT MUST FAIL, and fail DIFFERENTLY ----
     * EBADF where the operation is meaningful but not through this vnode. */
    if (VOP_ACCESS(vp, 0, (char *)0) != EBADF)  return (64);
    if (VOP_GETATTR(vp, (char *)0, (char *)0) != EBADF)
        return (65);
    if (VOP_SETATTR(vp, (char *)0, (char *)0) != EBADF)
        return (66);
    if (npanic != 0)                            return (67);   /* still none */

    /* A panic where the operation is meaningless.  Checked one at a time so a
     * badop slot answered by a NEIGHBOURING function -- which would return
     * without panicking -- is caught at the slot rather than in a total. */
    n = npanic;
    VOP_MMAP(vp, (char *)0);
    if (npanic != n + 1)                        return (68);
    VOP_SEEK(vp, (char *)0, (char *)0, (char *)0);
    if (npanic != n + 2)                        return (69);
    VOP_READDIR(vp, (char *)0, (char *)0, (char *)0);
    if (npanic != n + 3)                        return (70);
    VOP_READLINK(vp, (char *)0, (char *)0);
    if (npanic != n + 4)                        return (71);

    /* READ AND WRITE USED TO PANIC HERE, and this block is what noticed when
     * they stopped.  Until UFS 1.7b the slots held spec_nouio, which said
     * `struct uio` was missing rather than returning a plausible zero, and the
     * assertion was that they panicked -- with a comment saying it would go
     * red the day someone routed read(2) at a device without bringing uio.
     * 1.7b brought uio and implemented them, so it went red, correctly.
     *
     * What replaces it asserts the two refusals the real implementations owe,
     * both reachable without a device:
     *
     *   A DIRECTION MISMATCH IS FATAL.  spec_read given a uio marked WRITE has
     *   been handed a caller's bug, and Reno panics rather than transferring
     *   the right number of wrong bytes (spec_vnops.c:164).  This is the same
     *   assertion in the same spirit as the four badop slots above.
     *
     *   A CHARACTER DEVICE IS DISPATCHED, NOT REFUSED, AS OF UFS 1.13b -- and
     *   this block used to assert the refusal.  It said "no VCHR vnode can
     *   arrive here yet; the arm says so loudly", and 1.13a made VCHR vnodes
     *   while 1.13b gave the arms a registry to reach.  So it went red,
     *   correctly, for the second time in its life: 1.7b retired its first
     *   version the same way.  Checked by flipping v_type for the duration,
     *   because the fixture's vnode is the VBLK one everything else needs. */
    u.uio_rw = UIO_WRITE;                       /* wrong direction for a read */
    VOP_READ(vp, &u, 0, (char *)0);
    if (npanic != n + 5)                        return (72);
    u.uio_rw = UIO_READ;                        /* ...and for a write */
    VOP_WRITE(vp, &u, 0, (char *)0);
    if (npanic != n + 6)                        return (73);

    /* WHAT THIS FIXTURE CAN SEE AND THE ON-TARGET PROBE CANNOT: how many times
     * the arm reached the driver, and with what.  ufs_devprobe observes a uio
     * and infers the loop from it; these count the calls directly, so a spec
     * arm that satisfied every uio assertion without dispatching -- or that
     * dispatched the WRONG device index -- is caught here and only here. */
    vp->v_type = VCHR;
    vp->v_rdev = 7;
    cd_reads = 0;
    cd_writes = 0;
    cd_last_idx = -1;
    cd_last_byte = -1;
    cd_dreads = 0;
    cd_dwrites = 0;
    cd_dlast_idx = -1;

    /* READ: the fake registry answers EOF, so nothing moves and nothing
     * panics.  ONE call, because a loop that ignored end of file would go
     * round until resid ran out. */
    u.uio_rw = UIO_READ;
    u.uio_resid = 4;
    fake_iov.iov_base = fake_buf;
    fake_iov.iov_len = 4;
    u.uio_iov = &fake_iov;
    u.uio_iovcnt = 1;
    u.uio_offset = 0L;
    /* SYSSPACE explicitly: uiomove refuses anything else with EFAULT, and the
     * cases above left this uio pointed at whatever they needed. */
    u.uio_segflg = UIO_SYSSPACE;
    if (VOP_READ(vp, &u, 0, (char *)0) != 0)    return (118);
    if (npanic != n + 6)                        return (119);   /* none added */
    if (cd_reads != 1)                          return (120);
    if (u.uio_resid != 4)                       return (121);   /* EOF moved 0 */
    if (cd_last_idx != 7)                       return (122);   /* v_rdev, not
                                                                * some other
                                                                * device */

    /* THE BULK OP IS ASKED FIRST, and the fake answers "none" -- which is what
     * sent the read to the per-byte loop just asserted.  Asserting the ASK is
     * what separates a working fallback from a bulk arm that was never wired:
     * with kc_cddread never called, every assertion above still passes. */
    if (cd_dreads != 1)                         return (128);
    if (cd_dlast_idx != 7)                      return (129);   /* v_rdev again,
                                                                * on the bulk
                                                                * path's own
                                                                * argument */

    /* WRITE: every byte accepted, so four calls and an empty uio.  The BYTE is
     * asserted too -- a loop that dispatched the right number of times with
     * the wrong byte would satisfy the count. */
    fake_buf[0] = (char)0xC1;
    fake_buf[1] = (char)0xC2;
    fake_buf[2] = (char)0xC3;
    fake_buf[3] = (char)0xC4;
    fake_iov.iov_base = fake_buf;
    fake_iov.iov_len = 4;
    u.uio_iov = &fake_iov;
    u.uio_iovcnt = 1;
    u.uio_offset = 0L;
    u.uio_resid = 4;
    u.uio_rw = UIO_WRITE;
    u.uio_segflg = UIO_SYSSPACE;
    if (VOP_WRITE(vp, &u, 0, (char *)0) != 0)   return (123);
    if (npanic != n + 6)                        return (124);
    if (cd_writes != 4)                         return (125);
    if (u.uio_resid != 0)                       return (126);
    if (cd_last_byte != 0xC4)                   return (127);   /* the LAST one,
                                                                * so the loop
                                                                * advanced */
    if (cd_dwrites != 1)                        return (130);

    /* ---- IOCTL AND SELECT ON A CHARACTER DEVICE (UFS 1.7d I4) ----
     *
     * Both arms kc_panic'd on VCHR until I4.  What replaced the panic is a
     * dispatch onto the same registry the read and write arms above reach, and
     * these cases hold it to the three things a dispatch has to get right: it
     * must ASK the driver, ask the RIGHT one, and USE the answer.
     *
     * A CONSTANT ANSWER IS THE MUTATION TO BEAT, and two cases beat it from
     * different sides.  The ENOTTY a real /dev/null returns is exactly what a
     * stubbed spec_ioctl would return, so 139 alone proves nothing.  A stub
     * that returns ENOTTY without dispatching is caught at 140, which counts
     * the driver calls (measured: stubbing the VCHR arm `return (ENOTTY)'
     * exits 140).  A stub that DOES dispatch and then ignores the answer gets
     * as far as 142, because no constant is both ENOTTY and EINVAL.
     *
     * SELECT IS THE SAME SHAPE ONE LEVEL UP.  The mask is the device's and the
     * BIT is spec_select's: one mask of POLLIN|POLLOUT must answer yes to both
     * directions, and a mask of POLLOUT alone must answer yes to FWRITE and NO
     * to FREAD off the very same value.  A spec_select that ignored `which'
     * passes the first pair and fails the second. */
    cd_ioctls   = 0;
    cd_polls    = 0;
    cd_last_idx = -1;

    cd_ioctlret = ENOTTY;
    if (VOP_IOCTL(vp, 0, (char *)0, 0, (char *)0) != ENOTTY)
        return (139);
    if (cd_ioctls != 1)                         return (140);   /* it ASKED */
    if (cd_last_idx != 7)                       return (141);   /* v_rdev, not
                                                                 * the vnode or
                                                                 * a neighbour */
    cd_ioctlret = EINVAL;
    if (VOP_IOCTL(vp, 0, (char *)0, 0, (char *)0) != EINVAL)
        return (142);   /* the DRIVER's answer, not a constant */
    if (cd_ioctls != 2)                         return (143);
    cd_ioctlret = ENOTTY;

    cd_last_idx = -1;
    cd_pollmask = POLLIN | POLLOUT;
    if (VOP_SELECT(vp, FREAD, 0, (char *)0) != 1)   return (144);
    if (VOP_SELECT(vp, FWRITE, 0, (char *)0) != 1)  return (145);
    if (cd_polls != 2)                          return (146);
    if (cd_last_idx != 7)                       return (147);

    /* THE SAME MASK, THE OTHER TWO ANSWERS.  This is the pair that fails for a
     * spec_select which returns the old unconditional 1, and for one which
     * answers `mask != 0' without applying `which'. */
    cd_pollmask = POLLOUT;
    if (VOP_SELECT(vp, FWRITE, 0, (char *)0) != 1)  return (148);
    if (VOP_SELECT(vp, FREAD, 0, (char *)0) != 0)   return (149);
    cd_pollmask = POLLIN;
    if (VOP_SELECT(vp, FREAD, 0, (char *)0) != 1)   return (150);
    if (VOP_SELECT(vp, FWRITE, 0, (char *)0) != 0)  return (151);

    /* AN UNKNOWN `which' IS NOT READY, which is upstream's answer and not a
     * choice made here: Reno's ttselect switches on FREAD and FWRITE alone and
     * any other `rw' falls out of the switch to `return (0)' (4.3BSD-Reno
     * kern/tty.c).  The exceptional-condition select is that third case. */
    cd_pollmask = POLLIN | POLLOUT;
    if (VOP_SELECT(vp, 0, 0, (char *)0) != 0)       return (152);
    cd_pollmask = 0;

    /* AND NOT ONE PANIC IN ANY OF IT -- the thing I4 removed, stated as an
     * assertion rather than left to the absence of a crash. */
    if (npanic != n + 6)                        return (153);

    /* AND NOW THE OTHER WAY ROUND: a device that HAS a bulk op gets it, and
     * the per-byte loop must not run AT ALL.  That is apple/fgx#198's silent
     * half -- a record-mode driver fills the caller's buffer whole and answers
     * a COUNT, and a per-byte loop running behind it reads that count as one
     * byte's value.  ONLY THIS FIXTURE CAN SEE IT.  ufs_devprobe infers the
     * loop from a uio, and a bulk op that returns success without touching the
     * uio leaves that uio looking exactly like /dev/null's EOF -- measured:
     * pointing the kernel arm at a filled slot left the on-target read case
     * green. The write case there does discriminate; the read case does not. */
    cd_reads    = 0;
    cd_writes   = 0;
    cd_dreads   = 0;
    cd_dwrites  = 0;
    cd_dstatus  = 0x0000;                       /* status 0: the op ran, no error */

    fake_iov.iov_base = fake_buf;
    fake_iov.iov_len = 4;
    u.uio_iov = &fake_iov;
    u.uio_iovcnt = 1;
    u.uio_offset = 0L;
    u.uio_resid = 4;
    u.uio_rw = UIO_READ;
    u.uio_segflg = UIO_SYSSPACE;
    if (VOP_READ(vp, &u, 0, (char *)0) != 0)    return (131);
    if (cd_dreads != 1)                         return (132);
    if (cd_reads != 0)                          return (133);   /* NO per-byte
                                                                * loop behind it */

    fake_iov.iov_base = fake_buf;
    fake_iov.iov_len = 4;
    u.uio_iov = &fake_iov;
    u.uio_iovcnt = 1;
    u.uio_offset = 0L;
    u.uio_resid = 4;
    u.uio_rw = UIO_WRITE;
    u.uio_segflg = UIO_SYSSPACE;
    if (VOP_WRITE(vp, &u, 0, (char *)0) != 0)   return (134);
    if (cd_dwrites != 1)                        return (135);
    if (cd_writes != 0)                         return (136);

    /* STATUS 2 -- the index names no device -- IS AN ERROR, NOT A FALLBACK,
     * and this is the case an errno sentinel could not have expressed.  19 is
     * ENODEV; the low byte travels through unchanged and the per-byte loop
     * must not run. */
    cd_reads    = 0;
    cd_dreads   = 0;
    cd_dstatus  = 0x0200 + 19;
    fake_iov.iov_base = fake_buf;
    fake_iov.iov_len = 4;
    u.uio_iov = &fake_iov;
    u.uio_iovcnt = 1;
    u.uio_offset = 0L;
    u.uio_resid = 4;
    u.uio_rw = UIO_READ;
    u.uio_segflg = UIO_SYSSPACE;
    if (VOP_READ(vp, &u, 0, (char *)0) != 19)   return (137);
    if (cd_reads != 0)                          return (138);

    cd_dstatus = 0x0100;                        /* back to "no bulk op" for
                                                * everything below */
    /* PUT THE VNODE BACK, BOTH FIELDS.  Everything below is about the BLOCK
     * device this fixture is otherwise built around, and case 121 above needed
     * a device number of its own to prove the arm passes v_rdev rather than
     * something it happened to have.  Leaving it at 7 makes bgetvp stamp the
     * wrong b_dev sixty lines further down, which is a failure a long way from
     * its cause. */
    vp->v_type = VBLK;
    vp->v_rdev = DEV_A;

    /* A TRANSFER OF NOTHING IS NOT AN ERROR and must not reach the device --
     * Reno returns 0 before looking at v_type or the offset. */
    u.uio_rw = UIO_READ;
    u.uio_resid = 0;
    if (VOP_READ(vp, &u, 0, (char *)0) != 0)    return (79);
    u.uio_rw = UIO_WRITE;
    if (VOP_WRITE(vp, &u, 0, (char *)0) != 0)   return (80);
    /* n + 6, NOT n + 8, SINCE UFS 1.13b.  The two that used to be added here
     * were the VCHR read and write refusing to dispatch; they dispatch now,
     * and the block above asserts that they reached the driver instead. */
    if (npanic != n + 6)                        return (81);   /* still none */
    npanic = 0;

    /* ---- 4. bmap on a device is IDENTITY, and it returns the vnode ----
     * For a file, bmap answers with the DEVICE vnode the I/O should be issued
     * against; for a device, that is this vnode.  Both halves are checked
     * because a bmap that filled in only the block number would look correct
     * to the buffer cache and wrong to a filesystem. */
    bn = (daddr_t)0;
    v2 = 0;
    if (VOP_BMAP(vp, (daddr_t)7, &v2, &bn) != 0)
        return (74);
    if (bn != (daddr_t)7)                       return (75);
    if (v2 != vp)                               return (76);

    /* ---- 5. THE CLAIM THE WHOLE SLICE EXISTS FOR ----
     *
     * bread on a device vnode reaches the disk THROUGH THE VECTOR.  The cache
     * calls VOP_STRATEGY on the buffer's vnode and knows nothing about disks;
     * for a device vnode that lands in spec_strategy.
     *
     * b_dev is the other half: bgetvp reads it from v_rdev, which is what lets
     * the cache issue I/O for a device without anyone naming it -- and a b_dev
     * that did not survive bdevvp reaches the real bio_strategy as NODEV,
     * which it rejects.
     *
     * The slot's POSITION is under test as much as its behaviour: strategy is
     * the 30th of 32, past the offset where fcc's struct fn-ptr field access
     * has drifted before. */
    fake_disk[9] = (char)0xC3;
    n = fake_reads;
    if (bread(vp, (daddr_t)9, &bp) != 0)        return (77);
    if (fake_reads != n + 1)                    return (78);   /* went to disk */
    if (bp->b_addr[0] != (char)0xC3)            return (79);
    if (bp->b_dev != DEV_A)                     return (80);   /* from v_rdev */
    if (bp->b_vp != vp)                         return (81);
    brelse(bp);

    /* A regular file's buffer gets NODEV, because the device belongs to the
     * filesystem rather than to the file.  Asserted alongside, so the arm
     * above cannot pass by setting b_dev unconditionally. */
    if (getnewvnode(VT_UFS, &mnt_a, &spec_vnodeops, &v2) != 0)
        return (83);
    v2->v_type = VREG;
    bp = getblk(v2, (daddr_t)13);
    if (bp == 0)                                return (84);
    if (bp->b_dev != NODEV)                     return (85);
    brelse(bp);

    /* And a write, back down the same path. */
    if (bread(vp, (daddr_t)10, &bp) != 0)       return (82);
    bp->b_addr[0] = (char)0x5A;
    n = fake_writes;
    if (bwrite(bp) != 0)                        return (86);
    if (fake_writes != n + 1)                   return (87);
    if (fake_disk[10] != (char)0x5A)            return (88);

    /* ---- 6. spec_close DROPS THE CACHED BLOCKS on a last close ----
     *
     * The corruption this prevents: the cache is keyed by (vnode, block), so
     * blocks cached against a device vnode outlive the close.  Change the
     * medium and the next read is answered from the cache with the OLD
     * volume's bytes -- silent, and invisible until the data is wrong.
     *
     * Asserted by going back to the DISK, not by looking at the lists: the
     * claim is "the next read is a real read", and the list state is a proxy
     * for it. */
    fake_disk[11] = (char)0x11;
    if (bread(vp, (daddr_t)11, &bp) != 0)       return (115);
    brelse(bp);
    if (incore(vp, (daddr_t)11) == 0)           return (116);  /* cached now */
    blk_closes = 0;
    blk_last   = -1;
    if (VOP_CLOSE(vp, 0, (char *)0) != 0)       return (117);
    if (incore(vp, (daddr_t)11))                return (89);   /* dropped */
    /* AND THE DRIVER IS TOLD, with this device: the last close is when a
     * CD-ROM may take another disc. */
    if (blk_closes != 1)                        return (160);
    if (blk_last != (int)vp->v_rdev)            return (161);
    fake_disk[11] = (char)0x22;                 /* "a different volume" */
    n = fake_reads;
    if (bread(vp, (daddr_t)11, &bp) != 0)       return (90);
    if (fake_reads != n + 1)                    return (91);   /* went to disk */
    if (bp->b_addr[0] != (char)0x22)            return (92);   /* the NEW bytes */
    brelse(bp);

    /* ---- 6b. A BLOCK DEVICE'S IOCTL REACHES ITS DRIVER, and the answer is
     * the driver's: 0 for a request it carries, ENOTTY for one it does not.
     * Two answers, so a constant cannot pass both. */
    blk_ioctls   = 0;
    blk_ioctlret = 0;
    if (VOP_IOCTL(vp, 0, (char *)0, 0, (char *)0) != 0)       return (162);
    blk_ioctlret = ENOTTY;
    if (VOP_IOCTL(vp, 0, (char *)0, 0, (char *)0) != ENOTTY)  return (163);
    if (blk_ioctls != 2)                        return (164);
    if (blk_last != (int)vp->v_rdev)            return (165);

    /* ---- 7. THE FLUSH DOES NOT WAIT FOR THE LAST CLOSE ----
     *
     * Reno's comment says "on last close ... we must invalidate any in core
     * blocks"; Reno's CODE invalidates before it consults vcount at all, so
     * every close of a block device drops its cached blocks and only the
     * DRIVER close is withheld until the last one.  This follows the code.
     *
     * THE vcount BRANCH guards the driver close, kc_blkstale: a close while
     * another name still holds the device must not tell the driver the
     * medium is free.  Asserted below with both aliases open, after the
     * alias machinery it depends on is shown to work: vcount sees both
     * names.
     *
     * The aliases are made the way a filesystem makes them -- two vnodes of
     * its own -- because bdevvp's are VT_NON and checkalias revives those
     * instead of aliasing them. */
    reset();
    if (mkdevvn(&vp) != 0)                      return (93);
    if (mkdevvn(&v2) != 0)                      return (95);
    if ((vp->v_flag & VALIASED) == 0)           return (96);
    if ((v2->v_flag & VALIASED) == 0)           return (99);
    if (vcount(vp) < 2)                         return (97);
    if (vcount(v2) != vcount(vp))               return (98);   /* one device */

    fake_disk[12] = (char)0x33;
    if (bread(vp, (daddr_t)12, &bp) != 0)       return (100);
    brelse(bp);
    if (incore(vp, (daddr_t)12) == 0)           return (101);  /* cached */
    blk_closes = 0;
    if (VOP_CLOSE(vp, 0, (char *)0) != 0)       return (102);
    if (incore(vp, (daddr_t)12))                return (103);  /* dropped */
    if (blk_closes != 0)                        return (166);  /* not last */

    /* ---- 8. spec_open REFUSES what it is supposed to refuse ---- */
    reset();
    if (mkdevvn(&vp) != 0)                      return (104);

    /* A device named by an untrusted filesystem.  This is the check that stops
     * a removable volume carrying its own /dev/mem. */
    vp->v_mount = &mnt_a;
    mnt_a.mnt_flag = MNT_NODEV;
    if (VOP_OPEN(vp, 0, (char *)0) != ENXIO)    return (105);
    mnt_a.mnt_flag = 0;
    if (VOP_OPEN(vp, 0, (char *)0) != 0)        return (106);

    /* A block device with a filesystem mounted on it cannot also be opened
     * raw -- writing to it would corrupt the mount. */
    vp->v_specflags |= SI_MOUNTEDON;
    if (VOP_OPEN(vp, 0, (char *)0) != EBUSY)    return (107);
    vp->v_specflags &= ~SI_MOUNTEDON;

    /* AND THE FLAG IS FOUND THROUGH AN ALIAS, which is the half a per-vnode
     * test would miss: the mount happened through one name, and opening the
     * OTHER name raw would corrupt it just the same. */
    if (mkdevvn(&v2) != 0)                      return (108);
    v2->v_specflags |= SI_MOUNTEDON;
    if (VOP_OPEN(vp, 0, (char *)0) != EBUSY)    return (110);
    v2->v_specflags &= ~SI_MOUNTEDON;
    if (VOP_OPEN(vp, 0, (char *)0) != 0)        return (111);

    /* A vnode that names no device. */
    vp->v_rdev = NODEV;
    if (VOP_OPEN(vp, 0, (char *)0) != ENXIO)    return (112);

    /* ---- 9. nothing above panicked or slept unexpectedly ----
     * The badop counter was zeroed after case 3; anything since is a slot
     * answering with a function it should not be. */
    if (npanic != 0)                            return (113);
    if (nslept != 0)                            return (114);

    return (42);
}
