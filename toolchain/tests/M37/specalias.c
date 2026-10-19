/* specalias.c -- UFS 1.4c: device vnodes and their aliases, on real hardware.
 *
 * WHAT THIS SLICE IS ABOUT.  Two names for one device are two files, two
 * inodes and two vnodes -- but one driver, with one state.  checkalias is what
 * keeps the vnode layer honest about that: it puts every device vnode on a
 * hash chain keyed by (major, minor), marks the set VALIASED, and vgone takes
 * one back off again.  vcount then sums references across the set, which is
 * how a driver eventually learns that its LAST close has happened rather than
 * merely one of several.
 *
 * WHY IT NEEDS A FIXTURE AND NOT A BOOT TEST.  Every failure in this code is
 * silent.  A freed vnode left on a live chain is handed out by the next
 * checkalias as an authority for a device it no longer represents.  A VALIASED
 * flag left set on the last survivor makes vcount walk a chain of one and
 * still answer as though the device had two openers, so a driver's last close
 * never arrives.  A chain unlink that stitches the wrong neighbour leaves a
 * list that still walks.  None of these crash, and none of them are visible
 * from userland until data is already wrong.
 *
 * THE MIDDLE-OF-CHAIN UNLINK IS THE ONE TO WATCH.  v_hashchain holds the
 * address of the BUCKET, not -- unlike v_freeb and v_mountb -- the address of
 * the pointer that references this vnode, so vgone cannot do the one-store
 * unlink the other two lists get and has to walk to find the predecessor.
 * Case 8 removes a vnode from the middle of a four-deep chain for exactly that
 * reason; removing only the head would leave that walk unexecuted.
 *
 * DEV_A and DEV_B HASH TO THE SAME BUCKET on purpose (both bucket 1 at
 * SPECHSZ 8).  A chain that mixes devices is the case where "same chain" and
 * "same device" can be confused, and a checkalias that tested only the chain
 * would alias two unrelated devices together.  DEV_C is in another bucket.
 *
 * Exit 42 = pass; 99 = the panic stub was reached; every other value is
 * 50 + the case number, so no failure can land on the pass code.
 */

#include "../../../src/kernel/vfs/fsparam.h"
#include "../../../src/kernel/vfs/vnode.h"
#include "../../../src/kernel/vfs/mount.h"
#include "../../../src/kernel/vfs/specdev.h"

/* Three device numbers.  The first two share a hash bucket, the third does
 * not; the assertions below spell out which is which rather than trusting the
 * arithmetic, so a change to SPECHSZ turns the intent into a failure instead
 * of quietly making two cases identical. */
#define DEV_A   ((dev_t)0x0301)
#define DEV_B   ((dev_t)0x0309)
#define DEV_C   ((dev_t)0x0302)

void kc_panic(msg)
    char *msg;
{
    exit(99);
}

/* UFS 1.2: vfs_subr.c's ndget asks the kernel which process is running.
 * A fixture is single-process, so pid 1 -- a VALID pid, not a sentinel:
 * ndslot refuses anything outside 1..VFS_NPROC, so 0 here would make
 * every ndget return null and the fixture would test the refusal path
 * instead of the thing it is about. */
int kc_curpid() { return (1); }

/* Counted, not silent: nothing in this file is supposed to block, and a stub
 * that just returned would make "it never slept" an assumption. */
static int nslept = 0;

void kc_sleep(chan)  char *chan; { nslept++; }
void kc_wakeup(chan) char *chan; { }

/* vclean's buffer flush.  The buffer cache is not what this fixture is about
 * -- toolchain/tests/M37/vreclaim.c composes it for real -- so it is stubbed
 * and counted. */
static int invalbufs = 0;

int vinvalbuf(vp, save)
    struct vnode *vp;
    int save;
{
    invalbufs++;
    return (0);
}

/* TWO VECTORS THAT CAN BE TOLD APART.  This matters more here than in the
 * other VFS fixtures: checkalias's revive path cleans a vnode through the
 * vector it USED to carry -- specfs's -- and then gives it the filesystem's.
 * A trace that only recorded the filesystem's operations would show nothing at
 * all for that clean and every assertion about it would pass vacuously. */
#define TRACE_MAX      24
static int trace[TRACE_MAX];
static int n_trace = 0;

#define T_FSCLOSE      1
#define T_FSINACTIVE   2
#define T_FSRECLAIM    3
#define T_SPCLOSE      4
#define T_SPLOCK       5
#define T_SPUNLOCK     6
#define T_SPINACTIVE   7
#define T_SPRECLAIM    8

static void
note(what)
    int what;
{
    if (n_trace < TRACE_MAX)
        trace[n_trace++] = what;
}

static int
saw(what)
    int what;
{
    register int i;

    for (i = 0; i < n_trace; i++)
        if (trace[i] == what)
            return (1);
    return (0);
}

static int op_nop()       { return 0; }

static int fs_close()     { note(T_FSCLOSE);    return 0; }
static int fs_inactive()  { note(T_FSINACTIVE); return 0; }
static int fs_reclaim()   { note(T_FSRECLAIM);  return 0; }

static int sp_close()     { note(T_SPCLOSE);    return 0; }
static int sp_lock()      { note(T_SPLOCK);     return 0; }
static int sp_unlock()    { note(T_SPUNLOCK);   return 0; }
static int sp_inactive()  { note(T_SPINACTIVE); return 0; }
static int sp_reclaim()   { note(T_SPRECLAIM);  return 0; }

struct vnodeops fsops = {
    op_nop, op_nop, op_nop, op_nop, fs_close, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, fs_inactive, fs_reclaim, op_nop, op_nop,
    op_nop, op_nop,
    op_nop, op_nop
};

/* Standing in for specfs's vector until 1.5 defines it.  It is a REAL vector
 * here rather than a placeholder, because bdevvp installs it and vflush's
 * forced-unmount arm reverts to it, and both of those are claims this file
 * makes: `v_op == &spec_vnodeops` is only meaningful if the vector is
 * distinguishable from the filesystem's. */
struct vnodeops spec_vnodeops = {
    op_nop, op_nop, op_nop, op_nop, sp_close, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, sp_inactive, sp_reclaim, sp_lock, sp_unlock,
    op_nop, op_nop,
    op_nop, op_nop
};

/* Nothing here calls through the dead vector; it only has to exist for v_op to
 * point at between vclean's swap and checkalias's re-assignment. */
struct vnodeops dead_vnodeops = {
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop,
    op_nop, op_nop
};

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


struct mount mnt_a;

/* How many specinfo entries are out.  The pool's in-use marker is a non-null
 * si_hashchain, so this counts the same property allocation sets and vgone
 * clears -- a leak and a double free are both visible here, and neither is
 * visible anywhere else. */
static int
spec_inuse()
{
    register int i, n;

    n = 0;
    for (i = 0; i < NSPECINFO; i++)
        if (specinfo_pool[i].si_hashchain != 0)
            n++;
    return (n);
}

/* Bounded walk of one hash bucket.  Bounded because a mis-stitched unlink can
 * make a chain circular, and an unbounded walk would hang the machine rather
 * than fail the test. */
static int
chainlen(bucket)
    int bucket;
{
    register struct vnode *vp;
    register int n;

    n = 0;
    for (vp = speclisth[bucket]; vp; vp = vp->v_specnext) {
        if (++n > NSPECINFO + 2)
            return (-1);
    }
    return (n);
}

static void
reset()
{
    vntblinit(vn_arena);
    /* THE HAND-OVER ufsdir's mod_init DOES ON THE MACHINE -- see specops.c's
     * reset() for the whole story.  vfs_subr.c reaches spec_vnops.c through a
     * pointer since 2026-09-05 and refuses while it is null, so without this
     * the bdevvp at case 104 answers ENXIO. */
    vfs_setspecops(&spec_vnodeops);
    mnt_a.mnt_mounth = 0;
    mnt_a.mnt_flag = 0;
    n_trace = 0;
    invalbufs = 0;
}

main()
{
    struct vnode *v0, *v1, *v2, *v3, *v4, *vp;
    int n, bkt;

    reset();

    /* ---- 1. the device numbers are laid out as the comments claim ----
     * Asserted rather than assumed: DEV_A and DEV_B sharing a bucket is what
     * makes cases 4 and 8 test anything, and if SPECHSZ moves they silently
     * stop doing so. */
    if (SPECHASH(DEV_A) != SPECHASH(DEV_B))     return (51);
    if (SPECHASH(DEV_A) == SPECHASH(DEV_C))     return (52);
    bkt = SPECHASH(DEV_A);

    /* ---- 2. a non-device is not a device.  checkalias must decline it and
     *         allocate nothing -- a specinfo attached to a VREG is a pool
     *         entry that nothing will ever free. ---- */
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (53);
    v0->v_type = VREG;
    if (checkalias(v0, DEV_A, &mnt_a) != 0)     return (54);
    if (spec_inuse() != 0)                      return (55);

    /* ---- 3. the first vnode for a device: given a specinfo, on the chain,
     *         and NOT aliased -- one is not a set. ---- */
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v1) != 0)
        return (56);
    v1->v_type = VBLK;
    if (checkalias(v1, DEV_A, &mnt_a) != 0)     return (57);
    if (spec_inuse() != 1)                      return (58);
    if (v1->v_rdev != DEV_A)                    return (59);
    if (v1->v_hashchain != &speclisth[bkt])     return (60);
    if (speclisth[bkt] != v1)                   return (61);
    if (v1->v_specnext != 0)                    return (62);
    if (v1->v_flag & VALIASED)                  return (63);
    if (v1->v_specflags != 0)                   return (64);

    /* ---- 4. a SECOND vnode for the SAME device.  Both ends get VALIASED,
     *         because the flag describes the set and vcount reads it from
     *         whichever member the caller happens to hold. ---- */
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v2) != 0)
        return (65);
    v2->v_type = VBLK;
    n = v1->v_usecount;
    if (checkalias(v2, DEV_A, &mnt_a) != 0)     return (66);
    /* checkalias takes a reference on the vnode it finds and drops it again.
     * A leak here would pin the vnode forever and never be noticed. */
    if (v1->v_usecount != n)                    return (67);
    if ((v1->v_flag & VALIASED) == 0)           return (68);
    if ((v2->v_flag & VALIASED) == 0)           return (69);
    if (speclisth[bkt] != v2)                   return (70);
    if (v2->v_specnext != v1)                   return (71);
    if (spec_inuse() != 2)                      return (72);

    /* ---- 5. a DIFFERENT device in the SAME bucket must not alias.  This is
     *         the case a chain-only test would get wrong. ---- */
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v3) != 0)
        return (73);
    v3->v_type = VBLK;
    if (checkalias(v3, DEV_B, &mnt_a) != 0)     return (74);
    if (v3->v_flag & VALIASED)                  return (75);
    if (speclisth[bkt] != v3)                   return (76);
    if (v3->v_specnext != v2)                   return (77);

    /* ---- 6. the same NUMBER with a different TYPE is a different device.
     *         A block device and a character device may share (major, minor)
     *         and reach entirely different drivers. ---- */
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v4) != 0)
        return (78);
    v4->v_type = VCHR;
    if (checkalias(v4, DEV_A, &mnt_a) != 0)     return (79);
    if (v4->v_flag & VALIASED)                  return (80);
    /* The bucket now holds, newest first: v4 (VCHR A), v3 (B), v2 (A), v1 (A). */
    if (speclisth[bkt] != v4)                   return (81);
    if (v4->v_specnext != v3)                   return (99);
    if (chainlen(bkt) != 4)                     return (149);

    /* ---- 7. vfinddev and vcount ----
     *
     * vcount is the reason the whole alias apparatus exists: with two vnodes
     * naming one device, neither one's v_usecount means anything on its own,
     * and a driver that reset its hardware on the wrong zero would do it under
     * a process still using it. */
    vp = 0;
    if (vfinddev(DEV_A, VBLK, &vp) != 0)        return (82);
    if (vp != v2 && vp != v1)                   return (83);  /* either alias */
    vp = 0;
    if (vfinddev(DEV_A, VCHR, &vp) != 0)        return (84);
    if (vp != v4)                               return (85);
    if (vfinddev(DEV_C, VBLK, &vp) != 1)        return (86);  /* absent */

    if (vcount(v1) != 2)                        return (87);
    vref(v2);
    if (vcount(v1) != 3)                        return (88);
    if (vcount(v2) != 3)                        return (89);  /* same answer */
    vrele(v2);
    /* Not aliased: the answer is its own count and the chain is not walked. */
    if (vcount(v3) != v3->v_usecount)           return (90);

    /* ---- 8. vgone from the MIDDLE of the chain ----
     *
     * v2 sits between v3 and v1, so this is the arm that walks to find the
     * predecessor.  Afterwards v1 is the only vnode left for DEV_A, so VALIASED
     * must come OFF it -- a survivor still carrying the flag makes vcount walk
     * a chain of one forever and answer as though the device had two openers. */
    n = spec_inuse();
    vgone(v2);
    if (spec_inuse() != n - 1)                  return (91);  /* freed */
    if (v2->v_specinfo != 0)                    return (92);
    if (v2->v_flag & VALIASED)                  return (93);
    if (v1->v_flag & VALIASED)                  return (94);  /* last survivor */
    if (speclisth[bkt] != v4)                   return (95);  /* head untouched */
    if (v4->v_specnext != v3)                   return (96);
    if (v3->v_specnext != v1)                   return (97);  /* stitched over */
    if (v1->v_specnext != 0)                    return (98);
    if (chainlen(bkt) != 3)                     return (100);
    if (v2->v_type != VBAD)                     return (101);

    /* ---- 9. and from the HEAD, which is the other arm: one store on the
     *         bucket rather than a walk. ---- */
    vgone(v4);
    if (speclisth[bkt] != v3)                   return (102);
    if (chainlen(bkt) != 2)                     return (103);

    /* ---- 10. THE REVIVE PATH: a device opened before its filesystem exists.
     *
     * bdevvp makes a vnode for a device nobody has named -- the root device,
     * or the disk a mount is about to happen on.  It has no filesystem, so its
     * tag is VT_NON.  When the filesystem later turns up with a real /dev
     * entry, checkalias hands back THAT SAME VNODE rather than making a second
     * one, so a descriptor already open on the device keeps working.
     *
     * The vnode is cleaned WITHOUT DOCLOSE on the way through, and that is the
     * assertion with teeth: the filesystem is changing, the device is not, and
     * closing it here would reset hardware underneath an open descriptor.
     * Checked through the SPEC vector's own trace marks, because at that
     * moment the vnode still wears spec_vnodeops -- a check against the
     * filesystem's marks could not have failed. */
    reset();
    if (bdevvp(DEV_C, &v0) != 0)                return (104);
    if (v0->v_type != VBLK)                     return (105);
    if (v0->v_tag != VT_NON)                    return (106);
    if (v0->v_op != &spec_vnodeops)             return (107);
    if (v0->v_rdev != DEV_C)                    return (108);
    if (v0->v_mount != 0)                       return (109);
    if (spec_inuse() != 1)                      return (110);

    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v1) != 0)
        return (111);
    v1->v_type = VBLK;
    n_trace = 0;
    vp = checkalias(v1, DEV_C, &mnt_a);
    if (vp != v0)                               return (112);  /* the same one */
    if (v1->v_type != VNON)                     return (113);  /* owns nothing */
    if (v0->v_op != &fsops)                     return (114);  /* now the fs's */
    if (v0->v_tag != VT_UFS)                    return (115);
    if (v0->v_mount != &mnt_a)                  return (116);
    if (v0->v_rdev != DEV_C)                    return (117);  /* identity kept */
    if (spec_inuse() != 1)                      return (118);  /* not a second */
    if (v0->v_flag & VALIASED)                  return (119);  /* still one */
    if (saw(T_SPRECLAIM) == 0)                  return (120);  /* it WAS cleaned */
    if (saw(T_SPCLOSE))                         return (121);  /* but not closed */
    if (invalbufs != 0)                         return (122);  /* nor flushed */
    vput(v1);

    /* ---- 11. an alias nobody is using is COLLECTED, not accumulated.  Two
     *          opens of the same device over a machine's lifetime must not
     *          leave two entries on its chain. ---- */
    reset();
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (123);
    v0->v_type = VBLK;
    if (checkalias(v0, DEV_A, &mnt_a) != 0)     return (124);
    vrele(v0);                                  /* idle, still on the chain */
    if (speclisth[bkt] != v0)                   return (125);
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v1) != 0)
        return (126);
    if (v1 == v0)                               return (127);  /* a second slot */
    v1->v_type = VBLK;
    if (checkalias(v1, DEV_A, &mnt_a) != 0)     return (128);
    if (v0->v_type != VBAD)                     return (129);  /* collected */
    if (v1->v_flag & VALIASED)                  return (130);  /* nothing left */
    if (speclisth[bkt] != v1)                   return (131);
    if (v1->v_specnext != 0)                    return (132);
    if (spec_inuse() != 1)                      return (133);

    /* ---- 12. FORCED UNMOUNT REVERTS A DEVICE, it does not destroy it.
     *
     * This is the arm 1.4b left as a panic.  A regular file goes away with its
     * filesystem; a device does not, because the driver behind it is still
     * there and a process holding the descriptor still expects to reach it.
     * So it is cleaned without DOCLOSE, wears the anonymous device vector, and
     * KEEPS its place on the alias chain -- only the mount link goes. */
    reset();
    mnt_a.mnt_flag = MNT_MPBUSY;
    if (getnewvnode(VT_UFS, &mnt_a, &fsops, &v0) != 0)
        return (134);
    v0->v_type = VBLK;
    if (checkalias(v0, DEV_A, &mnt_a) != 0)     return (135);
    /* Still held, so an ordinary unmount must refuse rather than take it. */
    if (vflush(&mnt_a, (struct vnode *)0, 0) != EBUSY)
        return (136);
    if (v0->v_op != &fsops)                     return (137);  /* untouched */

    n_trace = 0;
    if (vflush(&mnt_a, (struct vnode *)0, FORCECLOSE) != 0)
        return (138);
    if (v0->v_type != VBLK)                     return (139);  /* still a device */
    if (v0->v_op != &spec_vnodeops)             return (140);
    if (v0->v_mount != 0)                       return (141);
    if (mnt_a.mnt_mounth != 0)                  return (142);
    if (speclisth[bkt] != v0)                   return (143);  /* still chained */
    if (v0->v_rdev != DEV_A)                    return (144);
    if (spec_inuse() != 1)                      return (145);  /* NOT freed */
    if (saw(T_FSCLOSE))                         return (146);  /* not closed */
    if (saw(T_FSRECLAIM) == 0)                  return (147);  /* was cleaned */

    /* ---- 13. nothing above should have blocked ---- */
    if (nslept != 0)                            return (148);

    return (42);
}
