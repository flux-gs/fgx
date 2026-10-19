/* vreclaim.c -- UFS 1.4b: reclaim, on real hardware.
 *
 * WHAT MAKES THIS DIFFERENT FROM vnodepool.c.  That fixture tests the vnode
 * layer with a FAKE buffer cache and a fake ops vector, because the pool is
 * pure list logic and does not need either.  Reclaim is the opposite: its
 * whole job is to make three separate pieces agree, and each of them faked is
 * a piece not tested.  So this composes the REAL vfs_bio.c, the REAL
 * vfs_subr.c and the REAL dead_vnops.c into one translation unit, and the only
 * things stubbed are the kernel's sleep, wakeup and panic.
 *
 * THE CLAIM UNDER TEST is the one apple/fgx#84 was filed about: reclaiming a
 * vnode must take its buffers with it.  The cache is keyed by (b_vp,
 * b_lblkno), so a buffer left chained to a recycled vnode answers the NEXT
 * file's reads with the PREVIOUS file's bytes -- silent data corruption, no
 * crash, no error, and nothing a boot test can see.  Case 6 is that exact
 * sequence end to end: write bytes through one vnode, reclaim it, hand the
 * same vnode slot to a different file, and require the read to reach the disk.
 *
 * DISPATCH THROUGH THE VECTOR IS THE OTHER HALF.  vclean calls VOP_LOCK,
 * VOP_CLOSE, VOP_INACTIVE and VOP_RECLAIM through whatever vector the vnode
 * carries, then swaps in dead_vnodeops.  Every one of those is a call through
 * a function pointer read out of a 128-byte struct -- two recorded fcc defect
 * families -- so the counters below assert not just THAT reclaim happened but
 * that each slot dispatched to the function it names.  A vector off by one
 * slot would still run something and still return zero.
 *
 * Exit 42 = pass; 99 = the panic stub was reached; every other value is
 * 50 + the case number, so no failure can land on the pass code.
 */

#include "../../../src/kernel/vfs/fsparam.h"
#include "../../../src/kernel/vfs/vnode.h"
#include "../../../src/kernel/vfs/specdev.h"
#include "../../../src/kernel/vfs/buf.h"
#include "../../../src/kernel/vfs/mount.h"

static int nslept = 0;

void kc_panic(msg)  char *msg;  { exit(99); }
void kc_sleep(chan) char *chan; { nslept++; }
void kc_wakeup(chan) char *chan; { }
/* UFS 1.2: vfs_subr.c's ndget asks the kernel which process is running.
 * A fixture is single-process, so pid 1 -- a VALID pid, not a sentinel:
 * ndslot refuses anything outside 1..VFS_NPROC, so 0 here would make
 * every ndget return null and the fixture would test the refusal path
 * instead of the thing it is about. */
int kc_curpid() { return (1); }

void biodone();

/* A fake disk, as in biocache.c: one byte per block is enough to prove which
 * bytes moved in which direction, and the CALL COUNTS are what the assertions
 * are really about.  Synchronous, calling biodone before returning, which is
 * the contract the real strategy has on SmartPort PIO. */
#define FAKEBLKS  64
static char fake_disk[FAKEBLKS];
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

#include "../../../src/kernel/vfs/vfs_bio.c"

/* A filesystem, faked -- but only just.  Each operation records that it ran,
 * in ORDER, so the test can assert the sequence vclean is specified to
 * perform rather than only its end state.  The order matters: a vclean that
 * reclaimed before deactivating would leave the same counters and the same
 * final flags. */
#define TRACE_MAX 16
static int trace[TRACE_MAX];
static int n_trace = 0;

#define T_LOCK      1
#define T_UNLOCK    2
#define T_CLOSE     3
#define T_INACTIVE  4
#define T_RECLAIM   5

static void
note(what)
    int what;
{
    if (n_trace < TRACE_MAX)
        trace[n_trace++] = what;
}

static int fs_reclaim_fails = 0;

static int fs_nop()      { return 0; }
static int fs_lock()     { note(T_LOCK);     return 0; }
static int fs_unlock()   { note(T_UNLOCK);   return 0; }
static int fs_close()    { note(T_CLOSE);    return 0; }
static int fs_inactive() { note(T_INACTIVE); return 0; }
static int fs_reclaim()  { note(T_RECLAIM);  return (fs_reclaim_fails); }

/* The cache issues VOP_STRATEGY rather than calling bio_strategy by name, so a
 * filesystem's vector has to reach the disk.  This is the slot a real
 * ufs_strategy occupies: it would fill in b_dev from the inode's device vnode
 * first, which this fixture has no inode to do. */
static int fs_strategy(bp)
    struct buf *bp;
{
    bio_strategy(bp);
    return (0);
}

struct vnodeops fsops = {
    fs_nop, fs_nop, fs_nop, fs_nop, fs_close, fs_nop, fs_nop, fs_nop,
    fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop,
    fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop,
    fs_nop, fs_inactive, fs_reclaim, fs_lock, fs_unlock,
    fs_nop, fs_strategy,
    fs_nop, fs_nop
};

/* specfs's vector, named by bdevvp and by vflush's forced-unmount arm and not
 * defined until 1.5.  No vnode here is VBLK or VCHR, so this exists to link;
 * toolchain/tests/M37/specalias.c is where it is dispatched through. */
struct vnodeops spec_vnodeops = {
    fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop,
    fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop,
    fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop, fs_nop,
    fs_nop, fs_nop, fs_nop, fs_nop, fs_nop,
    fs_nop, fs_nop,
    fs_nop, fs_nop
};

#include "../../../src/kernel/vfs/dead_vnops.c"
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

/* Bounded walk of a vnode's block list, checking the back-links as it goes --
 * the same reasoning as biocache.c's: a wrong back-link leaves the forward
 * walk perfectly traversable. */
static int
blkcount(headp)
    struct buf **headp;
{
    register struct buf *bp;
    register int n;

    n = 0;
    for (bp = *headp; bp; bp = bp->b_blockf) {
        if (bp->b_blockb == 0 || *bp->b_blockb != bp)
            return (-1);
        if (++n > NBUF + 4)
            return (-1);
    }
    return (n);
}

static void
reset()
{
    bufinit(fixarena);
    vntblinit(vn_arena);
    mnt_a.mnt_mounth = 0;
    mnt_a.mnt_flag = 0;
    n_trace = 0;
    fake_reads = 0;
    fake_writes = 0;
    fs_reclaim_fails = 0;
}

main()
{
    struct vnode *v0, *v1, *vp;
    struct buf *bp;
    int i, n;

    /* ---- 1. vclean runs the filesystem's operations, IN ORDER ---- */
    reset();
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (51);
    v0->v_type = VREG;
    vclean(v0, DOCLOSE);
    /* Idle vnode (usecount 1 from getnewvnode, so ACTIVE): lock, unlock,
     * close, inactive, reclaim.  Reno's order exactly -- unlock comes BEFORE
     * close and inactive, because a filesystem is entitled to expect those on
     * an unlocked vnode. */
    if (n_trace != 5)                           return (52);
    if (trace[0] != T_LOCK)                     return (53);
    if (trace[1] != T_UNLOCK)                   return (54);
    if (trace[2] != T_CLOSE)                    return (55);
    if (trace[3] != T_INACTIVE)                 return (56);
    if (trace[4] != T_RECLAIM)                  return (57);
    /* The vector was swapped, and the tag says no filesystem owns it. */
    if (v0->v_op != &dead_vnodeops)             return (58);
    if (v0->v_tag != VT_NON)                    return (59);
    /* VXLOCK was set during the teardown and cleared after it. */
    if (v0->v_flag & VXLOCK)                    return (60);

    /* ---- 2. an operation on a cleaned vnode FAILS instead of reaching the
     *         filesystem that no longer owns it ---- */
    n = n_trace;
    if (VOP_ACCESS(v0, 0, (char *)0) != EBADF)  return (61);
    if (VOP_READ(v0, (char *)0, 0, (char *)0) != EIO)
        return (62);                            /* not VCHR -> EIO */
    if (VOP_CLOSE(v0, 0, (char *)0) != 0)       return (63);   /* nullop */
    if (n_trace != n)                           return (64);   /* fs untouched */

    /* A dead CHARACTER device reads as end-of-file rather than as an error:
     * the stream ended, it did not break. */
    v0->v_type = VCHR;
    if (VOP_READ(v0, (char *)0, 0, (char *)0) != 0)
        return (65);
    v0->v_type = VREG;

    /* ---- 3. vclean without DOCLOSE does NOT close the file ---- */
    reset();
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (66);
    v0->v_type = VREG;
    vclean(v0, 0);
    if (n_trace != 4)                           return (67);
    for (i = 0; i < n_trace; i++)
        if (trace[i] == T_CLOSE)                return (68);

    /* ---- 4. vgone unlinks from the mount and MOVES the vnode to the HEAD of
     *         the free list -- a just-reclaimed vnode caches nothing worth
     *         keeping, so it should be the next one handed out, which is the
     *         opposite of vfree's tail insertion.
     *
     *         Both vnodes are released FIRST.  vgone does not free a vnode
     *         somebody still holds: vclean takes its own reference across the
     *         teardown and drops it at the end, leaving the count where it
     *         was.  Such a vnode is marked VBAD and detached, and reaches the
     *         free list when its last real user lets go -- which is why this
     *         asserts a MOVE (count unchanged) rather than an insertion. */
    reset();
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (69);
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v1) != 0)
        return (70);
    v0->v_type = VREG;
    v1->v_type = VREG;
    vrele(v1);                                  /* idle, on the free TAIL */
    vrele(v0);                                  /* idle, behind v1 */
    if (vnode_free_head == v0)                  return (114);  /* not yet head */
    n = freevnodes;
    vgone(v0);
    if (freevnodes != n)                        return (71);   /* moved, not added */
    if (vnode_free_head != v0)                  return (72);   /* head, not tail */
    if (v0->v_type != VBAD)                     return (73);
    if (v0->v_mount != 0)                       return (74);
    if (mnt_a.mnt_mounth == v0)                 return (75);
    /* The free list must still walk, with v1 still on it. */
    n = 0;
    for (vp = vnode_free_head; vp; vp = vp->v_freef) {
        if (++n > VNODE_POOL + 2)               return (76);
    }
    if (n != freevnodes)                        return (77);

    /* ---- 5. vgone on a vnode ALREADY being torn down waits rather than
     *         reclaiming twice.  A second reclaim would release a private area
     *         the filesystem has already given up. ---- */
    reset();
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (78);
    v0->v_type = VREG;
    v0->v_flag |= VXLOCK;                       /* pretend a clean is running */
    n = n_trace;
    i = nslept;
    vgone(v0);
    if (nslept != i + 1)                        return (79);   /* it waited */
    if (n_trace != n)                           return (80);   /* did nothing */
    if ((v0->v_flag & VXWANT) == 0)             return (81);
    v0->v_flag &= ~(VXLOCK | VXWANT);

    /* ---- 6. THE HAZARD apple/fgx#84 EXISTS FOR ----
     *
     * A vnode with a DIRTY buffer is reclaimed, and its slot is then handed to
     * a different file that happens to want the same logical block.  If the
     * buffer stayed chained to the vnode, getblk would find it by (b_vp,
     * b_lblkno) and hand back the OLD file's bytes.  The assertion is not that
     * the lists are empty -- that is a proxy -- but that the second file's
     * read GOES TO THE DISK and returns what the disk holds. */
    reset();
    fake_disk[20] = (char)0x77;                 /* what block 20 really holds */
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (82);
    v0->v_type = VREG;
    bp = getblk(v0, (daddr_t)20);
    bp->b_addr[0] = (char)0x88;                 /* the first file's bytes */
    bdwrite(bp);                                /* dirty, not yet on disk */
    if (blkcount(&v0->v_dirtyblkhd) != 1)       return (83);
    if (v0->v_holdcnt != 1)                     return (84);

    /* Release it first, so vgone's free-list arm can move it to the HEAD and
     * the next getnewvnode returns this same slot.  That is what makes the
     * read below a real test: if a different vnode came back, the stale buffer
     * could not be found by key anyway and the check would pass vacuously. */
    vrele(v0);

    /* vclean under DOCLOSE writes the dirty buffer out and detaches it. */
    n = fake_writes;
    vgone(v0);
    if (fake_writes != n + 1)                   return (85);   /* saved, not lost */
    if (fake_disk[20] != (char)0x88)            return (86);
    if (blkcount(&v0->v_dirtyblkhd) != 0)       return (87);
    if (blkcount(&v0->v_cleanblkhd) != 0)       return (88);
    if (v0->v_holdcnt != 0)                     return (89);

    /* Now the same vnode SLOT becomes a different file.  It must come back
     * from the free list -- vgone put it at the head -- and its block 20 must
     * come from the disk. */
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v1) != 0)
        return (90);
    if (v1 != v0)                               return (91);   /* same slot */
    v1->v_type = VREG;
    n = fake_reads;
    if (bread(v1, (daddr_t)20, &bp) != 0)       return (92);
    if (fake_reads != n + 1)                    return (93);   /* went to disk */
    if (bp->b_addr[0] != (char)0x88)            return (94);   /* what IS on disk */
    brelse(bp);

    /* ---- 7. the DISCARD path: a buffer whose data is being thrown away
     *         deliberately must not be written back ---- */
    reset();
    fake_disk[21] = (char)0x11;
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (95);
    v0->v_type = VREG;
    bp = getblk(v0, (daddr_t)21);
    bp->b_addr[0] = (char)0x22;
    bdwrite(bp);
    if (vinvalbuf(v0, 0) != 0)                  return (96);   /* nothing saved */
    if (fake_writes != 0)                       return (97);
    if (fake_disk[21] != (char)0x11)            return (98);   /* disk intact */

    /* ---- 8. vflush reclaims a whole mount, and reports EBUSY rather than
     *         taking a vnode away from a user who still holds it ---- */
    reset();
    mnt_a.mnt_flag = MNT_MPBUSY;
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (100);
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v1) != 0)
        return (101);
    v0->v_type = VREG;
    v1->v_type = VREG;
    vrele(v1);                                  /* idle: reclaimable */
    /* v0 is still held, so a plain vflush must refuse. */
    if (vflush(&mnt_a, (struct vnode *)0, 0) != EBUSY)
        return (102);
    if (v0->v_type != VREG)                     return (103);  /* untouched */
    if (v1->v_type != VBAD)                     return (104);  /* idle one went */

    /* FORCECLOSE takes the busy one too. */
    if (vflush(&mnt_a, (struct vnode *)0, FORCECLOSE) != 0)
        return (105);
    if (v0->v_type != VBAD)                     return (106);
    if (mnt_a.mnt_mounth != 0)                  return (107);

    /* ---- 9. skipvp is spared, and so is a VSYSTEM vnode ---- */
    reset();
    mnt_a.mnt_flag = MNT_MPBUSY;
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (108);
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v1) != 0)
        return (109);
    v0->v_type = VREG;
    v1->v_type = VREG;
    vrele(v0);
    vrele(v1);
    v1->v_flag |= VSYSTEM;
    if (vflush(&mnt_a, v0, SKIPSYSTEM) != 0)    return (110);
    if (v0->v_type != VREG)                     return (111);  /* skipvp */
    if (v1->v_type != VREG)                     return (112);  /* VSYSTEM */

    /* ---- 10. nothing above should have blocked except case 5 ---- */
    if (nslept != 1)                            return (113);

    return (42);
}
