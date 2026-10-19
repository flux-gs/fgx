/* vnodepool.c -- UFS 1.4a: the vnode pool, its free list and reference
 * counting, on real hardware.
 *
 * WHY A FIXTURE.  Same reasoning as biocache.c one deliverable earlier: this
 * slice is pure data-structure code -- a queue, two counters and a pointer-to-
 * pointer unlink -- and none of it needs a disk, a filesystem or a kernel.  It
 * is also exactly the kind of code that is wrong in ways a boot test cannot
 * see: a queue that unlinks the wrong neighbour still boots, and a refcount
 * that leaks only shows up as a pool that runs out days later.
 *
 * THE POINTER-TO-POINTER UNLINK IS THE POINT.  Reno's free and mount lists
 * store `struct vnode **` back-links -- the address OF the pointer that
 * references this vnode -- so one store unlinks a node whether it is at the
 * head or in the middle.  On this machine a pointer is four bytes and carries
 * a BANK, and taking the address of a field inside an array element is
 * precisely the construct that has produced multibank codegen bugs before.  So
 * this exercises the middle-of-list unlink, not just the head.
 *
 * It INCLUDES the implementation rather than linking it, which is how a unit
 * test reaches statics.  The stub below stands in for the kernel's panic;
 * reaching it is a FAILURE, so it exits with a distinct code rather than
 * returning, and no case here is supposed to trip it.
 *
 * Exit codes are the verdict.  42 = pass, which is this suite's convention;
 * 99 = the panic stub was reached; every other value is 50 + the case number
 * below.  The offset is not decoration: numbering the cases from 1 would put
 * case 42 on the pass code, and a failing test that reports success is the one
 * outcome a test must never produce.
 */

#include "../../../src/kernel/vfs/fsparam.h"
#include "../../../src/kernel/vfs/vnode.h"
#include "../../../src/kernel/vfs/specdev.h"
#include "../../../src/kernel/vfs/mount.h"

/* The kernel's panic, stubbed.  99 rather than a return, so a panic cannot be
 * mistaken for whatever the caller would have done next. */
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

/* Sleep and wakeup, stubbed and COUNTED.  vgone sleeps when it finds a
 * teardown already running and vclean wakes the waiters when one finishes;
 * nothing in this file is supposed to reach either, and a stub that silently
 * returned would turn "it never blocked" into an assumption rather than a
 * result.  A sleep on a single-threaded fixture is a hang in the real kernel. */
static int nslept = 0;
static int nvxsleeps = 0;

void kc_sleep(chan)  char *chan; { nslept++; }
void kc_wakeup(chan) char *chan; { }

/* vinvalbuf, which vclean calls under DOCLOSE.  This fixture has no buffer
 * cache -- toolchain/tests/M37/vreclaim.c composes the two for real -- so this
 * stands in and COUNTS, because "vclean invalidated the buffers" is a claim
 * this file makes and must not merely assume. */
static int invalbufs = 0;

int vinvalbuf(vp, save)
    struct vnode *vp;
    int save;
{
    invalbufs++;
    return (0);
}

/* The ops vector, faked.  vrele calls VOP_INACTIVE and vclean calls four more
 * through the vector, so a null v_op is no longer a legal way to hand out a
 * vnode -- it would be a call through a null pointer on the first vrele.  Each
 * slot that this file's paths actually reach COUNTS its calls, so the tests can
 * assert the reclaim sequence rather than just its result. */
static int nlock = 0, nunlock = 0, ninactive = 0, nreclaim = 0, nclose = 0;

static int op_nop()      { return 0; }
static int op_lock()     { nlock++;     return 0; }
static int op_unlock()   { nunlock++;   return 0; }
static int op_inactive() { ninactive++; return 0; }
static int op_reclaim()  { nreclaim++;  return 0; }
static int op_close()    { nclose++;    return 0; }

struct vnodeops fakeops = {
    op_nop, op_nop, op_nop, op_nop, op_close, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_inactive, op_reclaim, op_lock, op_unlock,
    op_nop, op_nop,
    op_nop, op_nop
};

/* dead_vnops.c supplies this in the kernel; here the reclaim path only needs
 * something for v_op to point AT after the swap, and this file never calls
 * through it.  vreclaim.c includes the real one and does. */
struct vnodeops dead_vnodeops = {
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop, op_nop, op_nop, op_nop,
    op_nop, op_nop,
    op_nop, op_nop
};

/* specfs's vector, which bdevvp and vflush's forced-unmount arm name.  It
 * arrives for real at 1.5; nothing in this file creates a device vnode, so
 * this only has to EXIST for the include below to link.
 * toolchain/tests/M37/specalias.c is the one that dispatches through it. */
struct vnodeops spec_vnodeops = {
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

/* THE NAME CACHE'S ARENA IS SEPARATE, and that is the kernel's shape rather
 * than a fixture convenience: the cache lives in ufsdir.mod, so it Kmallocs
 * its own base at that module's mod_init instead of taking a slice of vfs.mod's
 * carve.  This fixture wants the cache only because getnewvnode mints v_id
 * through it. */
static char nc_arena[NNAMECACHE * sizeof(struct namecache)];
extern char *nchinit();


struct mount mnt_a;
struct mount mnt_b;

main()
{
    struct vnode *v0, *v1, *v2, *vp;
    int i, n, err;

    vntblinit(vn_arena);
    /* THE NAME CACHE'S HANDOVER, which ufs_dirinit makes on the machine.
     * getnewvnode mints v_id through it -- the cache lives in ufsdir.mod and
     * vfs.mod cannot name cache_purge across a bank -- so the assertion below
     * that a handed-out vnode has a non-zero capability number depends on it.
     * nchinit is what sets the counter to 1, and it is the cache's now. */
    nchinit(nc_arena);
    vfs_setcacheops(&ufs_cacheops);

    /* 1. A fresh pool is entirely free, in index order. */
    if (freevnodes != VNODE_POOL)
        return (51);
    if (vnode_free_head != &vnode_pool[0])
        return (52);

    /* 2. getnewvnode hands out the head, with one reference and a fresh id. */
    err = getnewvnode(VT_UFS, (struct mount *)0, &fakeops, &v0);
    if (err != 0)
        return (53);
    if (v0 != &vnode_pool[0])
        return (54);
    if (v0->v_usecount != 1)
        return (55);
    if (v0->v_id == 0)
        return (56);
    if (freevnodes != VNODE_POOL - 1)
        return (57);

    /* 3. Every handout gets a DIFFERENT id, which is what the name cache's
     *    staleness test rests on. */
    err = getnewvnode(VT_UFS, (struct mount *)0, &fakeops, &v1);
    if (err != 0)
        return (58);
    if (v1->v_id == v0->v_id)
        return (59);

    /* 4. vref/vrele are symmetric, and the vnode only goes idle at zero. */
    vref(v0);
    if (v0->v_usecount != 2)
        return (60);
    vrele(v0);
    if (v0->v_usecount != 1)
        return (61);
    if (freevnodes != VNODE_POOL - 2)
        return (62);
    vrele(v0);
    if (v0->v_usecount != 0)
        return (63);
    if (freevnodes != VNODE_POOL - 1)
        return (64);

    /* 5. AN IDLE VNODE KEEPS ITS IDENTITY.  This is the property that makes
     *    the free list a cache rather than a pool of blanks, and the one most
     *    easily lost by "tidying up" in vrele. */
    if (v0->v_id == 0)
        return (65);
    if (v0->v_tag != VT_UFS)
        return (66);

    /* 6. vget resurrects it, and takes it back off the free list. */
    n = freevnodes;
    if (vget(v0) != 0)
        return (67);
    if (v0->v_usecount != 1)
        return (68);
    if (freevnodes != n - 1)
        return (69);

    /* 7. A vnode under teardown refuses vget rather than handing out a vnode
     *    that is about to become somebody else's.  Reno's return value is a
     *    bare 1, not an errno -- "no longer usable" rather than a reason.
     *
     *    AND IT SLEEPS FIRST, WHICH IS NEW AT UFS 1.12d.  It used to refuse
     *    immediately, and this case asserted the refusal without noticing the
     *    difference -- the only thing that caught the change was the global
     *    "nothing here should ever have blocked" at the end of the fixture,
     *    which reported a sleep and could not say whose.
     *
     *    THE WAIT IS THE POINT, NOT AN ADDITION TO IT.  A caller that RETRIES
     *    on a refusal -- ufs_ihashget does, since 1.12d -- re-finds the same
     *    vnode, still VXLOCKed, with nothing between the two attempts that
     *    could change the answer, because the process holding it can only make
     *    progress if this one sleeps.  Refusing without sleeping turns that
     *    retry into a spin.  So the sleep is counted here rather than
     *    forbidden, and case 108 below still says nothing ELSE blocked. */
    v0->v_flag |= VXLOCK;
    nvxsleeps = nslept;
    if (vget(v0) != 1)
        return (70);
    if (nslept != nvxsleeps + 1)
        return (71);        /* exactly one, and it was this call's */
    v0->v_flag &= ~VXLOCK;

    /* 8. THE MIDDLE-OF-LIST UNLINK.  Free three in a row so the queue holds
     *    them in order, then resurrect the MIDDLE one and check both
     *    neighbours still chain -- the case a head-only unlink passes and a
     *    wrong back-link corrupts silently. */
    vrele(v0);
    vrele(v1);
    err = getnewvnode(VT_UFS, (struct mount *)0, &fakeops, &v2);
    if (err != 0)
        return (71);
    vrele(v2);
    /* Walk to confirm all three are present before disturbing anything. */
    n = 0;
    for (vp = vnode_free_head; vp; vp = vp->v_freef)
        n++;
    if (n != freevnodes)
        return (72);

    /* Pick a vnode with a live neighbour on each side. */
    vp = vnode_free_head->v_freef;
    if (vp == 0 || vp->v_freef == 0)
        return (73);
    vremfree(vp);
    n = 0;
    for (vp = vnode_free_head; vp; vp = vp->v_freef)
        n++;
    if (n != freevnodes)
        return (74);
    /* The tail must still be reachable and still be the tail: walking to the
     * end and comparing against vnode_free_tail is what catches a stale tail
     * pointer, which a forward walk alone cannot see. */
    for (vp = vnode_free_head; vp && vp->v_freef; vp = vp->v_freef)
        ;
    if (vp == 0)
        return (75);
    if (vnode_free_tail != &vp->v_freef)
        return (76);

    /* 9. insmntque threads a vnode onto a mount and off again, and moving it
     *    between mounts leaves neither list holding it twice. */
    vntblinit(vn_arena);
    mnt_a.mnt_mounth = 0;
    mnt_b.mnt_mounth = 0;
    if (getnewvnode(VT_UFS, &mnt_a, &fakeops, &v0) != 0)
        return (77);
    if (mnt_a.mnt_mounth != v0)
        return (78);
    if (v0->v_mount != &mnt_a)
        return (79);
    insmntque(v0, &mnt_b);
    if (mnt_a.mnt_mounth != 0)
        return (80);
    if (mnt_b.mnt_mounth != v0)
        return (81);
    insmntque(v0, (struct mount *)0);
    if (mnt_b.mnt_mounth != 0)
        return (82);
    if (v0->v_mount != 0)
        return (83);

    /* 10. Two vnodes on one mount: removing the FIRST must leave the second
     *     as the head, which is the mount-list version of case 8. */
    vntblinit(vn_arena);
    mnt_a.mnt_mounth = 0;
    if (getnewvnode(VT_UFS, &mnt_a, &fakeops, &v0) != 0)
        return (84);
    if (getnewvnode(VT_UFS, &mnt_a, &fakeops, &v1) != 0)
        return (85);
    if (mnt_a.mnt_mounth != v1)
        return (86);
    insmntque(v1, (struct mount *)0);
    if (mnt_a.mnt_mounth != v0)
        return (87);
    insmntque(v0, (struct mount *)0);
    if (mnt_a.mnt_mounth != 0)
        return (88);

    /* 11. vhold is not vref: a held vnode with no users is the closed file
     *     whose dirty blocks have not been written, and the two counts must
     *     move independently. */
    vntblinit(vn_arena);
    if (getnewvnode(VT_UFS, (struct mount *)0, &fakeops, &v0) != 0)
        return (89);
    vhold(v0);
    if (v0->v_holdcnt != 1)
        return (90);
    if (v0->v_usecount != 1)
        return (91);
    vrele(v0);
    if (v0->v_usecount != 0)
        return (92);
    if (v0->v_holdcnt != 1)
        return (93);
    holdrele(v0);
    if (v0->v_holdcnt != 0)
        return (94);

    /* 12. THE POOL RUNS OUT ONLY WHEN EVERY VNODE IS IN USE.  Hand out the
     *     whole pool without releasing anything -- so nothing is on the free
     *     list to reclaim -- and the next request must report ENFILE rather
     *     than stealing a vnode somebody still holds.
     *
     *     THIS IS A DIFFERENT CLAIM FROM THE ONE SLICE A MADE.  There, the
     *     pool also refused when its vnodes were merely IDLE, because reclaim
     *     did not exist; case 14 is what that turned into. */
    vntblinit(vn_arena);
    mnt_a.mnt_mounth = 0;
    for (i = 0; i < VNODE_POOL; i++) {
        if (getnewvnode(VT_UFS, &mnt_a, &fakeops, &vp) != 0)
            return (95);
    }
    if (getnewvnode(VT_UFS, &mnt_a, &fakeops, &vp) != ENFILE)
        return (96);
    if (vp != 0)
        return (97);

    /* 13. ...and having refused, the pool is still coherent: every vnode is
     *     accounted for and none is on the free list. */
    if (freevnodes != 0)
        return (98);
    if (vnode_free_head != 0)
        return (100);       /* not 99 -- that is the panic stub's code */

    /* 14. AN IDLE POOL RECLAIMS INSTEAD OF FAILING.  Release one of the
     *     vnodes from case 12 and ask for another: it must come back, and it
     *     must have gone through vclean on the way -- close, inactive and
     *     reclaim all called, and the buffers invalidated.  Counting those is
     *     the point: a getnewvnode that simply reused the vnode without
     *     reclaiming it would satisfy every other assertion here while leaving
     *     the previous file's private data and cached blocks attached. */
    n = nreclaim;
    i = invalbufs;
    vrele(&vnode_pool[3]);
    if (freevnodes != 1)
        return (101);
    if (getnewvnode(VT_UFS, &mnt_a, &fakeops, &vp) != 0)
        return (102);
    if (vp != &vnode_pool[3])
        return (103);
    if (nreclaim != n + 1)
        return (104);       /* VOP_RECLAIM ran */
    if (invalbufs <= i)
        return (105);       /* vclean flushed the buffers */
    if (vp->v_usecount != 1)
        return (106);
    if (freevnodes != 0)
        return (107);

    /* Nothing here should ever have blocked EXCEPT case 7, whose one sleep is
     * counted there.  Written as a total rather than "no sleeps" since 1.12d:
     * the useful property is that the pool's ordinary paths -- getnewvnode,
     * vrele, vgone, vclean, the free-list surgery -- still run to completion,
     * and a second sleeper appearing anywhere in them is what this catches. */
    if (nslept != 1)
        return (108);

    return (42);
}
