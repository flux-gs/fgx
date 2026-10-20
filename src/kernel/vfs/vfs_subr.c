/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/vfs_subr.c
 *   Ported from kern/vfs_subr.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 */
/* vfs_subr.c -- the FGX vnode layer: the pool, the free list, the per-mount
 * list, reference counting, and reclaim.
 *
 * Ported from 4.3BSD-Reno kern/vfs_subr.c, with 2.11BSD as the guide wherever
 * Reno assumes a machine FGX is not.  Same rule the buffer cache was written
 * to, and for the same reason: hold the BSD shape so later imports compile
 * against a familiar structure, and narrow only what the machine bounds.
 *
 * WHAT IS STILL NOT HERE.  spec_vnodeops -- the vector a device vnode wears --
 * arrives with specfs at 1.5.  bdevvp and vflush's forced-unmount arm both
 * name it, so this file does not link into a kernel that has no specfs; that
 * is why it is still fixture-verified rather than in tools/ninja/gen.py's `_vc`
 * loop, and the fixtures supply a vector of their own.  Everything the alias
 * machinery itself needs is here.
 *
 * THE OPS VECTOR IS THE SPINE.  vclean does not know what a filesystem is.  It
 * calls VOP_LOCK, VOP_CLOSE, VOP_INACTIVE and VOP_RECLAIM through the vector
 * the vnode carries, then swaps that vector for dead_vnodeops so every later
 * call fails instead of reaching a filesystem that no longer owns the vnode.
 * That swap is why this file needs no knowledge of UFS, and why callers holding
 * a stale reference do not need to be found and fixed -- they keep their
 * pointer and it stops working, which is the outcome that can be reasoned
 * about.
 *
 * THE FREE LIST HOLDS VNODES THAT ARE STILL VALID.  This is the piece of Reno
 * most often misread.  A vnode with v_usecount == 0 is on the free list but
 * its identity, its filesystem private data and its cached blocks are all
 * still live -- it is a CACHE of recently-used vnodes, not a pool of blanks.
 * That is what makes vget's "resurrect from the free list" path meaningful,
 * and it is why v_id exists: the name cache can hold a pointer to a vnode that
 * has since been recycled, and comparing v_id is how it finds out.
 */

#include "fsparam.h"
#include "vnode.h"
#include "mount.h"
#include "specdev.h"
#include "namei.h"      /* struct nameidata, for the ndinit/ndget pool below */
#include "vfsops.h"     /* VFS_UNMOUNT, which vfs_dounmount dispatches */

extern void kc_panic();
extern void kc_sleep();
extern void kc_wakeup();

/* From vfs_bio.c.  vclean's first act under DOCLOSE is to write out and detach
 * every buffer the vnode owns; without it a reclaimed vnode hands its buffers
 * to the next file that lands on the same slot, and the cache -- keyed by
 * (b_vp, b_lblkno) -- answers that file's reads with the old file's bytes. */
extern int vinvalbuf();
/* dev_chrtoblk.c, this module -- GENERATED from the same lists that mknod
 * the raw-disk nodes onto the root. */
dev_t chrtoblk();

/* THE NAME CACHE IS IN ufsdir.mod, so neither of the two entries this file
 * needs can be called by name: a module reads its own bank, and a call to
 * another one has to carry that bank.  Both arrive in a table whose cells
 * ufs_dirinit fills, and are dispatched through it below.  namei.h carries
 * the argument for why it is a table.
 *
 * NULL UNTIL ufsdir's mod_init RUNS, which is the same state vfs_specops is
 * in and for the same reason -- but nothing here has to refuse, because
 * nothing can reach these two first.  The root mount is what mints the first
 * vnode, and it runs after all three modules are staged (src/kernel/main.s:683,
 * and iget refuses to mint until ufs_dirinit has run).  The guards below are
 * therefore about a module that failed to come up, not about ordering. */
static struct cacheops *vfs_cacheops;

void
vfs_setcacheops(c)
struct cacheops *c;
{
    vfs_cacheops = c;
}

/* The vector a cleaned vnode wears, from dead_vnops.c. */
extern struct vnodeops dead_vnodeops;

/* The vector a DEVICE vnode wears, from specfs at 1.5.  Named here by bdevvp
 * and by vflush's forced-unmount arm, and defined nowhere yet -- which is the
 * honest state of things and the reason this file is not in the kernel's
 * source list.  Faking it here to make the file self-contained would mean the
 * kernel silently linked a device vnode to a vector that does nothing. */
/* THE DEVICE-VNODE OPS TABLE IS NOT IN THIS BANK ANY MORE (2026-09-05).
 * spec_vnops.c moved to ufsdir.mod, beside ufs_vnops.c, which names all ten
 * spec_* in its own device vector and was reaching them through ten cross-bank
 * shims; same bank now, and this bank got back the 5,482 bytes it had 267 of.
 *
 * So the table arrives the way ufs.mod's two already do -- handed over once,
 * from the owning module's mod_init -- rather than by taking an address this
 * bank can no longer form.  ufs_inode.c:316 and :341 are the same arrangement
 * and say why at length: the pointer is FAR and stays far, and its bank is the
 * owning module's, which is what makes cross-bank VOP_ dispatch work at all
 * (apple/fgx#178).
 *
 * NULL UNTIL ufsdir's mod_init RUNS, and both readers below refuse rather than
 * dispatch through it -- iget's rule, for iget's reason: a null table would be
 * dispatched on the first VOP_ and come apart a long way from the cause. */
static struct vnodeops *vfs_specops;

void
vfs_setspecops(v)
struct vnodeops *v;
{
    vfs_specops = v;
}

/* Forward declarations, in the same style vfs_bio.c uses: fcc is K&R and would
 * accept the implicit int, but a file that calls before it defines should say
 * so rather than rely on that. */
void vfree();
void vremfree();
void insmntque();
void vref();
void vrele();
void vclean();
void vgone();
void vput();
struct vnode *checkalias();

/* The pool.  A flat array rather than Reno's malloc'd chain: FGX has a fixed
 * NPROC and a fixed buffer arena, the vnode count is a compile-time knob like
 * every other size in this campaign, and a flat array makes the fixture's
 * bounds checks trivial.
 *
 * THE STORAGE IS NOT DECLARED HERE.  It used to be `struct vnode
 * vnode_pool[VNODE_POOL]`, which put 5,248 bytes in whatever bank this
 * translation unit lands in -- and the bank the VFS code lives in is the one
 * thing that is scarce.  vntblinit takes the base address instead, exactly as
 * bufinit takes the buffer arena, so the pool follows the heap rather than the
 * code.  The array count stays a compile-time knob; only its address moved. */
struct vnode *vnode_pool;

/* Free-list head and tail.  Reno keeps these as a queue so vnodes are reused
 * OLDEST FIRST -- take from the head, return to the tail.  That ordering is
 * the whole cache policy: LRU falls out of it for free, and reversing it would
 * turn the pool into a stack that reuses the hottest vnode every time. */
struct vnode  *vnode_free_head;
struct vnode **vnode_free_tail;

/* Statistics, with Reno's meanings.  numvnodes is how many vnodes EXIST --
 * constant here, because the pool is fixed where Reno grows one by malloc up
 * to desiredvnodes.  freevnodes is how many are on the free list. */
int numvnodes;
int freevnodes;

/* The device alias hash, and the specinfo pool behind it.
 *
 * Reno declares speclisth in specdev.h, as a definition in a header -- a
 * pre-ANSI common symbol, which this toolchain has no equivalent for.  It is
 * defined here and externed there instead; nothing else changes. */
struct vnode *speclisth[SPECHSZ];

/* The specinfo pool moved to the heap with the vnode pool and for the same
 * reason; vntblinit carves it from the same base.  speclisth STAYS here: it is
 * SPECHSZ bucket HEADS, 32 bytes, and moving it would buy nothing while making
 * every alias walk start from a runtime address. */
struct specinfo *specinfo_pool;


/* zerobytes -- Reno's `bzero', for the two pools this file carves.
 *
 * IT IS LOCAL AND NOT libc's.  This bank has no libc: kernel C reaches the
 * outside world through the KSVC/VFSCORE seams and nothing else, and a byte
 * loop is smaller than a seam slot would be.  `unsigned' for the count and not
 * `int' because fcc's int is 16 bits and signed -- the vnode pool is already
 * larger than 32,767 bytes on some configurations, and a signed count would
 * wrap into an immediate return.
 *
 * The caller's pointers are FAR (a different bank from this code, by design --
 * see vntblinit), so the parameter is `char *' and the arithmetic is on the
 * pointer rather than on an int index cast back. */
static void
zerobytes(p, n)
char     *p;
unsigned  n;
{
    while (n-- > 0)
        *p++ = 0;
}


/* vntblinit -- build the free list.  Every vnode starts free, in index order,
 * so a fresh pool hands out vnode_pool[0] first and the fixture can predict
 * it.  Reno calls this from vfs_init; FGX calls it from the kernel's VFS boot
 * path once mounts exist. */
/* arena: VNODE_POOL vnodes followed by NSPECINFO specinfos, supplied by the
 * caller.  The two are carved from ONE base because they are allocated
 * together and freed never; tools/gen_vfs_equ.py sums them in this order for
 * the assembly that makes the allocation, and a carve that disagrees with that
 * sum runs off the end of it.
 *
 * `&arena[n]`, NOT `arena + n`.  Pointer arithmetic has dropped the bank byte
 * here before, and the arena is in a different bank from this code BY DESIGN
 * -- the same note vfs_bio.c's bufinit carries, for the same reason. */
char *vntblinit(arena)
char *arena;
{
    register int i;
    register struct vnode *vp;

    vnode_pool = (struct vnode *)arena;
    specinfo_pool = (struct specinfo *)
                    &arena[VNODE_POOL * sizeof(struct vnode)];

    for (i = 0; i < SPECHSZ; i++)
        speclisth[i] = 0;
    /* si_hashchain == 0 is the FREE marker for a pool entry.  A specinfo in
     * use always has one -- checkalias sets it in the same statement that
     * takes the entry -- so there is no window in which a live entry looks
     * free, which a separate flag or a free-list link would both have.
     *
     * THE WHOLE ENTRY IS ZEROED AND NOT JUST THAT FIELD, for the reason the
     * vnode loop below gives at length. */
    zerobytes((char *)specinfo_pool,
              (unsigned)(NSPECINFO * sizeof(struct specinfo)));

    vnode_free_head = 0;
    vnode_free_tail = &vnode_free_head;
    numvnodes = VNODE_POOL;
    freevnodes = 0;
    /* EVERY BYTE, WHICH IS RENO'S `bzero' AND NOT A FIELD LIST.  Upstream has
     * no pool: getnewvnode mallocs each vnode and immediately
     * `bzero((char *)vp, sizeof *vp)' (vendor/4.3BSD-Reno/kern/vfs_subr.c:251).
     * This carve replaced that allocation, and it replaced the bzero with the
     * nine fields below -- which agreed with upstream only because the arena
     * happened to be zero.
     *
     * IT DOES NOT HAPPEN TO BE ZERO ON A REAL MACHINE.  MAME zero-fills RAM at
     * power-on and an Apple IIgs does not, so v_data, v_specnext, v_freef,
     * v_freeb, v_cleanblkhd, v_dirtyblkhd and the rest came up holding
     * whatever was there.  tests/coldgarbage.json boots with RAM poisoned by a
     * seeded LCG, which is what a cold power-on leaves, and it PANICKED in
     * `vrele: zero usecount' during /etc/rc.
     *
     * A field list is also the wrong shape even when it is complete: it rots
     * silently the next time a field is added to the structure, and
     * vfs_vnops.c's vattr_null already says what that costs -- a missed field
     * "does not fail loudly".  Zeroing the object cannot rot. */
    zerobytes((char *)vnode_pool,
              (unsigned)(VNODE_POOL * sizeof(struct vnode)));
    for (i = 0; i < VNODE_POOL; i++) {
        vp = &vnode_pool[i];
        /* VBAD, not VNON, and it is the one field the zero above gets wrong:
         * Reno's getnewvnode reuses a free vnode without calling vgone only
         * when v_type == VBAD, which is the mark vgone leaves.  A pool vnode
         * that has never belonged to a filesystem is in exactly that state, so
         * saying so lets the Reno condition work unmodified instead of
         * substituting an FGX-specific test.  Every other field this loop used
         * to set -- v_flag, v_usecount, v_holdcnt, v_tag (VT_NON), v_mount,
         * v_mountf, v_mountb, v_id -- wants zero and now gets it above. */
        vp->v_type = VBAD;
        vfree(vp);
    }

    /* Where this carve ended, so the caller can place the next pool without
     * repeating the arithmetic -- and, more to the point, without needing
     * `struct specinfo` to be a complete type where it is written. */
    return (&arena[VNODE_POOL * sizeof(struct vnode)
                 + NSPECINFO * sizeof(struct specinfo)]);
}


/* vfree -- put a vnode on the TAIL of the free list.
 *
 * Split out of vrele because getnewvnode and vntblinit need it too, and
 * because the tail insertion is the LRU policy: a caller that used insertion
 * at the head here would silently convert the cache to most-recently-used and
 * nothing would fail, it would just thrash. */
void vfree(vp)
    register struct vnode *vp;
{
    vp->v_freef = 0;
    vp->v_freeb = vnode_free_tail;
    *vnode_free_tail = vp;
    vnode_free_tail = &vp->v_freef;
    freevnodes++;
}


/* vremfree -- take a specific vnode OFF the free list.
 *
 * Not just the head: vget resurrects a vnode somebody still had a pointer to,
 * which can sit anywhere in the queue.  v_freeb holds the ADDRESS OF the
 * pointer that references this vnode -- &vnode_free_head at the head, the
 * previous vnode's v_freef otherwise -- so `*vp->v_freeb = vp->v_freef`
 * unlinks either case without a branch.  That is Reno's idiom and the reason
 * the field is `struct vnode **`; the tail pointer needs the same shape,
 * because it is what the next insertion writes through. */
void vremfree(vp)
    register struct vnode *vp;
{
    *vp->v_freeb = vp->v_freef;
    if (vp->v_freef)
        vp->v_freef->v_freeb = vp->v_freeb;
    else
        vnode_free_tail = vp->v_freeb;
    vp->v_freef = 0;
    vp->v_freeb = 0;
    freevnodes--;
}


/* getnewvnode -- hand out a vnode for a filesystem to fill in.
 *
 * Returns 0 on success with *vpp set, or ENFILE when the pool is exhausted.
 *
 * RECLAIM IS THE WHOLE POINT OF THE FREE LIST.  The head is taken
 * unconditionally, and if it still belongs to a filesystem -- `v_type != VBAD`
 * -- vgone tears it away first.  Slice a kept this exact CONDITION but SKIPPED
 * such a vnode instead of reclaiming it, because reclaiming needs the ops
 * vector; the pool behaved like a smaller pool and reported ENFILE.  Now that
 * the vector exists the skip becomes the call, and the test did not have to
 * change -- which is why it was written as Reno's test rather than an
 * invention.
 *
 * The order matters: vremfree FIRST, then vgone.  vgone moves a vnode that is
 * still on the free list to the head of it, and this one must not be -- it has
 * just been handed out.  Taking it off first makes vgone's re-insertion arm a
 * no-op, which is exactly what Reno relies on.
 */
int getnewvnode(tag, mp, vops, vpp)
    int tag;
    struct mount *mp;
    struct vnodeops *vops;
    struct vnode **vpp;
{
    register struct vnode *vp;

    vp = vnode_free_head;
    if (vp == 0) {
        *vpp = 0;
        return (ENFILE);
    }
    /* Reno's invariant, kept: a vnode on the free list with users is a vnode
     * two owners believe they hold. */
    if (vp->v_usecount)
        kc_panic("getnewvnode: free vnode isn't");
    vremfree(vp);
    if (vp->v_type != VBAD)
        vgone(vp);

    vp->v_flag = 0;
    vp->v_usecount = 1;
    vp->v_holdcnt = 0;
    vp->v_type = VNON;
    vp->v_tag = tag;
    vp->v_lastr = 0;
    vp->v_numoutput = 0;
    vp->v_shlockc = 0;
    vp->v_exlockc = 0;
    vp->v_cleanblkhd = 0;
    vp->v_dirtyblkhd = 0;
    vp->v_un = 0;
    vp->v_op = vops;
    vp->v_mount = 0;
    /* A NEW IDENTITY, always.  Every handout gets a fresh v_id even when the
     * vnode was never used, because the name cache's staleness test is "same
     * pointer AND same id", and reusing an id would make a cached entry
     * pointing at the previous incarnation look valid.
     *
     * THE MINT IS cache_purge's, not a line here, and that is Reno's shape for
     * a reason worth keeping: bumping the number is only MOST of the job.  The
     * counter can wrap, and on the turn a stale entry holding the old number
     * would match a new vnode by coincidence -- so the wrap has to zero every
     * recorded id, and that arm lives with the table it walks.  An inline
     * `v_id = next++` here would be right for 4,294,967,295 handouts out of
     * every 4,294,967,296.
     *
     * SO THE CALL CROSSES A BANK, and it is worth being plain about the cost:
     * this is the ONE hot-ish caller the cache move puts on the far side of a
     * pile call.  It is once per vnode HANDOUT, not once per lookup -- the
     * lookups it pays for are all same-bank in ufsdir -- and every cross-bank
     * shim in the system measured together came to 0.69% of a run
     * (apple/fgx#381), against the 3.8% the wired cache returns.
     *
     * BEFORE the vnode is handed out, not after, or a lookup can race onto the
     * previous incarnation. */
    if (vfs_cacheops)
        (*vfs_cacheops->co_purge)(vp);
    insmntque(vp, mp);
    *vpp = vp;
    return (0);
}


/* vref -- one more user of a vnode that already has one.
 *
 * Reno panics on a zero count here and so does this: a vnode with no users is
 * on the free list, and taking a reference to it without removing it leaves it
 * simultaneously in use and reusable.  That is silent corruption of whatever
 * file gets handed the same vnode next, so it fails loudly instead. */
void vref(vp)
    register struct vnode *vp;
{
    if (vp->v_usecount <= 0)
        kc_panic("vref: zero usecount");
    vp->v_usecount++;
}


/* vget -- claim a vnode that may currently be idle.
 *
 * This is the resurrect path: somebody held a pointer to a vnode whose count
 * fell to zero, and wants it back before it is recycled.  Taking it off the
 * free list is what makes that safe.
 *
 * VXLOCK -- "this vnode is being torn down" -- IS WAITED FOR AS OF 1.12d.  The
 * wait was left out when this was written because nothing set the flag then;
 * vclean sets it now, and vclean's tail is the waker (VXWANT, kc_wakeup on the
 * vnode), so the sleep has one.
 *
 * WHAT MADE IT NECESSARY RATHER THAN MERELY FAITHFUL: ufs_ihashget's retry.
 * That loop re-scans the inode hash when vget refuses, because a refusal means
 * "this one is going away, look again".  Refusing WITHOUT sleeping turns the
 * retry into a spin -- the caller re-finds the same vnode, still VXLOCKed,
 * with nothing between the two attempts that could ever change the answer,
 * because the process holding it can only make progress if this one sleeps.
 * The old comment called returning-without-sleeping "the honest partial"; it
 * was honest while the only caller returned null on a refusal, and stopped
 * being so the moment one retried. */
int vget(vp)
    register struct vnode *vp;
{
    /* Reno's, exactly (kern/vfs_subr.c:425-429): sleep until the teardown
     * finishes, then return 1 -- "the vnode you asked for is not usable; find
     * out what replaced it".  The nonzero return is not an error code and no
     * caller treats it as one. */
    if (vp->v_flag & VXLOCK) {
        vp->v_flag |= VXWANT;
        kc_sleep((char *)vp);
        return (1);
    }
    if (vp->v_usecount == 0)
        vremfree(vp);
    vp->v_usecount++;
    return (0);
}


/* vrele -- drop a reference; the vnode goes idle at zero.
 *
 * VOP_INACTIVE IS CALLED AFTER THE VNODE IS ALREADY ON THE FREE LIST, which
 * looks backwards and is Reno's order for a reason.  Inactive is where a
 * filesystem does the work a last close implies -- for UFS, writing the inode
 * back and truncating a file whose link count reached zero -- and that work can
 * sleep.  A vnode that is on the free list during that sleep can be found and
 * resurrected by vget, which is correct; one that is on neither list is
 * invisible to everything and would be leaked if the sleeper never returned. */
void vrele(vp)
    register struct vnode *vp;
{
    if (vp->v_usecount <= 0)
        kc_panic("vrele: zero usecount");
    vp->v_usecount--;
    if (vp->v_usecount > 0)
        return;
    vfree(vp);
    VOP_INACTIVE(vp);
}


/* vhold / holdrele -- the BUFFER reference, which is not the user reference.
 *
 * Two counts, and the distinction is load-bearing.  v_usecount says a process
 * or the kernel is USING this file; v_holdcnt says the buffer cache still has
 * blocks hanging off v_cleanblkhd/v_dirtyblkhd.  A vnode can have zero users
 * and non-zero holds -- that is exactly a closed file whose dirty blocks have
 * not been written yet -- and recycling it then would strand those buffers on
 * a vnode that has become somebody else's.  Slice b's vgone is what consults
 * this; keeping the counts correct from the start is what lets it. */
void vhold(vp)
    register struct vnode *vp;
{
    vp->v_holdcnt++;
}


void holdrele(vp)
    register struct vnode *vp;
{
    if (vp->v_holdcnt <= 0)
        kc_panic("holdrele: zero holdcnt");
    vp->v_holdcnt--;
}


/* insmntque -- move a vnode onto a mount's vnode list, or off it entirely.
 *
 * mp == 0 detaches.  The list is what vflush walks at unmount time to find
 * every vnode belonging to a filesystem, so a vnode that is not on it is a
 * vnode unmount cannot see -- which is why getnewvnode calls this even for the
 * mp == 0 case rather than leaving the links whatever they were. */
void insmntque(vp, mp)
    register struct vnode *vp;
    register struct mount *mp;
{
    /* Unlink from the old mount, if any.  v_mountb points at the POINTER that
     * references this vnode -- mnt_mounth for the first on the list, the
     * previous vnode's v_mountf otherwise -- so one store unlinks either case
     * without asking which it is.  That is Reno's idiom throughout, and it is
     * why v_mountb and v_freeb are declared `struct vnode **`. */
    if (vp->v_mountb) {
        *vp->v_mountb = vp->v_mountf;
        if (vp->v_mountf)
            vp->v_mountf->v_mountb = vp->v_mountb;
    }
    vp->v_mountf = 0;
    vp->v_mountb = 0;
    vp->v_mount = mp;
    if (mp == 0)
        return;
    vp->v_mountf = mp->mnt_mounth;
    if (mp->mnt_mounth)
        mp->mnt_mounth->v_mountb = &vp->v_mountf;
    mp->mnt_mounth = vp;
    vp->v_mountb = &mp->mnt_mounth;
}


/* ---- device vnodes ---------------------------------------------------------
 *
 * TWO FILES, ONE DEVICE.  /dev/rd0 and any other name for the same (major,
 * minor) are separate files with separate inodes and separate vnodes, but the
 * driver behind them is one thing with one state.  The alias hash is how the
 * vnode layer keeps that straight: every device vnode hangs off a bucket keyed
 * by its device number, so the set of vnodes naming a device is enumerable and
 * can be marked, counted and torn down together.
 *
 * Nothing calls this yet.  UFS's VOP_LOOKUP calls checkalias when it reads an
 * inode whose mode says VBLK or VCHR, and mount calls bdevvp for the device it
 * is mounting -- both at 1.5 and later.  It lands now because vgone's third arm
 * cannot be written without it, and a vgone missing an arm is a reclaim that
 * silently leaves a freed vnode on a live hash chain.
 */

/* specalloc -- take a specinfo out of the pool, marked in use by the bucket it
 * belongs to.  The bucket is the argument rather than something the caller
 * fills in afterwards precisely so there is no window: the entry is never
 * simultaneously taken and indistinguishable from free.
 *
 * Reno MALLOCs with M_WAITOK, which cannot fail.  A fixed pool can, and the
 * answer is a panic rather than an error return, because every caller has
 * already committed to the vnode by the time it gets here -- there is no
 * unwind path to hand a failure to.  If this ever fires, NSPECINFO is too
 * small; it is a knob for exactly that reason. */
static struct specinfo *specalloc(vpp)
    struct vnode **vpp;
{
    register int i;

    for (i = 0; i < NSPECINFO; i++) {
        if (specinfo_pool[i].si_hashchain == 0) {
            specinfo_pool[i].si_hashchain = vpp;
            return (&specinfo_pool[i]);
        }
    }
    kc_panic("checkalias: out of specinfo");
    return ((struct specinfo *)0);
}


/* specfree -- return one to the pool.  A linear scan is what allocation costs,
 * so this only has to undo the marker. */
static void specfree(sip)
    register struct specinfo *sip;
{
    sip->si_hashchain = 0;
    sip->si_specnext = 0;
    sip->si_flags = 0;
    sip->si_rdev = NODEV;
}


/* checkalias -- give a new device vnode its specinfo, or hand back the vnode
 * that already speaks for this device.
 *
 * TWO RETURNS, AND THEY MEAN OPPOSITE THINGS.  This is the part of Reno most
 * easily misread:
 *
 *   0    the caller's vnode nvp is now the/an authority for the device.  It
 *        has been given a specinfo and put on the hash chain, and if another
 *        vnode was already there both are marked VALIASED.  KEEP nvp.
 *
 *   vp   an existing vnode was found that has no filesystem behind it -- a
 *        device that was opened before anything was mounted, so it was created
 *        as VT_NON.  It has been reattached to the caller's filesystem and
 *        mount, and IT is the vnode to use.  DISCARD nvp.
 *
 * The second case is what makes a device work before its filesystem is
 * mounted and keep working after: the vnode identity survives, so an open
 * descriptor does not stop referring to the device the moment the filesystem
 * that names it appears.
 *
 * The loop restarts rather than continues after vgone or a failed vget,
 * because both can sleep and the chain can be rearranged underneath. */
struct vnode *checkalias(nvp, nvp_rdev, mp)
    register struct vnode *nvp;
    dev_t nvp_rdev;
    struct mount *mp;
{
    register struct vnode *vp;
    struct vnode **vpp;

    if (nvp->v_type != VBLK && nvp->v_type != VCHR)
        return ((struct vnode *)0);

    vpp = &speclisth[SPECHASH(nvp_rdev)];
loop:
    for (vp = *vpp; vp; vp = vp->v_specnext) {
        if (nvp_rdev != vp->v_rdev || nvp->v_type != vp->v_type)
            continue;
        /* An alias nobody is using is not worth keeping: reclaim it and start
         * again, which is how a stale device vnode gets collected rather than
         * accumulating one per open. */
        if (vp->v_usecount == 0) {
            vgone(vp);
            goto loop;
        }
        if (vget(vp))
            goto loop;
        break;
    }

    if (vp == 0 || vp->v_tag != VT_NON) {
        nvp->v_specinfo = specalloc(vpp);
        nvp->v_rdev = nvp_rdev;
        nvp->v_specnext = *vpp;
        nvp->v_specflags = 0;
        *vpp = nvp;
        if (vp != 0) {
            /* BOTH ends get the flag.  VALIASED is a property of the SET, and
             * vcount and vgoneall both test it on whichever vnode they happen
             * to hold; marking only the newcomer would make the answer depend
             * on which one the caller reached the device through. */
            nvp->v_flag |= VALIASED;
            vp->v_flag |= VALIASED;
            /* vrele AND NOT vput, WHICH IS A REAL DIFFERENCE FROM UPSTREAM AND
             * NOT A TYPO.  Reno writes vput here because ITS vget locks
             * (kern/vfs_subr.c:440 calls VOP_LOCK), so the vput is releasing
             * the lock its own vget took twenty lines above.  This tree's vget
             * does not lock -- namei takes every directory lock explicitly
             * instead, and both would be a double lock -- so there is nothing
             * here to release, and vput would unlock a vnode nobody locked.
             *
             * IT WAS HARMLESS UNTIL UFS 1.13a AND IS NOT NOW.  Every vnode
             * that could reach this line used to wear spec_vnodeops, whose
             * unlock is a no-op; a device FILE wears spec_inodeops, whose
             * unlock is ufs_unlock, and that panics on a vnode that is not
             * locked.  The probe found it on the second device node with a
             * shared device number -- the first moment two aliases exist. */
            vrele(vp);
        }
        return ((struct vnode *)0);
    }

    /* The revive path.  The found vnode has no filesystem (VT_NON), so it is
     * cleaned WITHOUT DOCLOSE -- the device is not going away, it is changing
     * hands -- and then wears the caller's vector, tag and mount.  nvp is set
     * VNON so the caller's disposal of it releases a vnode that owns nothing.
     *
     * RENO UNLOCKS HERE AND THIS DOES NOT, for the reason the alias arm above
     * gives at length: the unlock is releasing the lock Reno's vget took, and
     * this tree's vget takes none.  vclean takes its own lock either way. */
    vclean(vp, 0);
    vp->v_op = nvp->v_op;
    vp->v_tag = nvp->v_tag;
    nvp->v_type = VNON;
    insmntque(vp, mp);
    return (vp);
}


/* bdevvp -- a vnode for a block device that no filesystem named.
 *
 * This is how the kernel gets a handle on the disk it is about to mount, and
 * on the root device before any filesystem exists to look a name up in.  The
 * vnode is VT_NON on purpose: it belongs to no filesystem, which is exactly
 * the condition checkalias's revive path tests for when the real /dev entry
 * turns up later. */
int bdevvp(dev, vpp)
    dev_t dev;
    struct vnode **vpp;
{
    register struct vnode *vp;
    struct vnode *nvp;
    int error;

    if (vfs_specops == (struct vnodeops *)0) {
        *vpp = 0;                       /* ufsdir has not handed the table over */
        return (ENXIO);
    }
    error = getnewvnode(VT_NON, (struct mount *)0, vfs_specops, &nvp);
    if (error) {
        *vpp = 0;
        return (error);
    }
    vp = nvp;
    vp->v_type = VBLK;
    /* Reno writes this as an assignment inside the test.  Split, because the
     * two returns mean opposite things (see checkalias) and the reader should
     * not have to recover that from an assignment in a condition. */
    nvp = checkalias(vp, dev, (struct mount *)0);
    if (nvp) {
        vput(vp);
        vp = nvp;
    }
    *vpp = vp;
    return (0);
}


/* vfinddev -- the vnode for a device, if one exists.
 *
 * Answers "is this device open" without creating anything, which is what
 * mount needs before it will let a filesystem onto a device and what a driver
 * needs to find its vnode from a device number.  ANY of a device's aliases is
 * an acceptable answer -- they all name the same driver -- so this returns the
 * first on the chain rather than trying to choose. */
int vfinddev(dev, type, vpp)
    dev_t dev;
    int type;
    struct vnode **vpp;
{
    register struct vnode *vp;

    for (vp = speclisth[SPECHASH(dev)]; vp; vp = vp->v_specnext) {
        if (dev != vp->v_rdev || type != vp->v_type)
            continue;
        *vpp = vp;
        return (0);
    }
    return (1);
}


/* THE SYSTEM SECURITY LEVEL, and the one rule FGX enforces with it.
 *
 * 2.11BSD's doctrine, usr/sys/h/systm.h:12-38, which is 4.4BSD-Lite's:
 *
 *      -1  permannently insecure mode - always run system in level 0 mode.
 *       0  insecure mode - immutable and append-only flags make be turned off.
 *          All devices may be read or written subject to permission modes.
 *       1  secure mode - immutable and append-only flags may not be changed;
 *          raw disks of mounted filesystems, /dev/mem, and /dev/kmem are
 *          read-only.
 *       2  highly secure mode - same as (1) plus raw disks are always
 *          read-only whether mounted or not.
 *
 *      In normal operation, the system runs in level 0 mode while single user
 *      and in level 1 mode while multiuser.
 *
 * 4.3BSD-Reno, which the rest of this tree ports from, has no securelevel
 * anywhere in the distribution: it permits a read-write fsck of a mounted root
 * because the mechanism did not exist yet.  This is the later design, and the
 * clause FGX implements is the middle one -- raw disks of mounted filesystems
 * are read-only at level 1.  The other two clauses have nothing to gate:
 * /dev/mem and /dev/kmem do not exist here, and the immutable and append-only
 * flags arrive with chflags(2).
 *
 * LEVEL 2 IS REFUSED RATHER THAN ACCEPTED AND IGNORED -- vfs_setsecurelevel
 * below.  Accepting it would leave a knob that reads as protection and is
 * none, which is what apple/fgx#406 turned out to be.
 *
 * IT STARTS AT 0 AND IS WRITTEN HERE, not left to the loader: a module's data
 * segment arrives with the image, so the initialiser is real, and saying it
 * out loud is what makes "/etc/rc runs at level 0" a statement about this file
 * rather than about a zeroed bank. */
int securelevel = 0;


/* spec_securechr -- may this character device be opened for WRITING?
 *
 * 2.11BSD's openi, usr/sys/sys/sys_inode.c:650-670, the IFCHR arm, inside
 * `if (mode & FWRITE)':
 *
 *      if (securelevel >= 1) {
 *              if ((bdev = chrtoblk(dev)) != NODEV &&
 *                      (error = ufs_mountedon(bdev)))
 *                              return(error);
 *              if (iskmemdev(dev))
 *                      return(EPERM);
 *      }
 *
 * The iskmemdev half has nothing to gate on FGX.  What remains is the first:
 * find the block device this character device is the raw face of, and refuse
 * the write-open if a filesystem is mounted on it.  READING STAYS LEGAL, which
 * is deliberate and is how `fsck -n /dev/rsd0' still answers on a live root --
 * it is how you find out whether you need single user, and it cannot hurt
 * anything.
 *
 * THE WALK IS vfinddev'S PLUS ONE TEST, rather than vfinddev followed by
 * mountedon().  Two reasons.  SI_MOUNTEDON sits on whichever vnode the mount
 * happened through, and vfinddev answers with the FIRST vnode naming the
 * device -- which need not be that one -- so the composition would have to
 * lean on mountedon's alias walk to recover; and mountedon() lives in
 * ufsdir.mod with spec_open, so calling it from here is a bank crossing in the
 * direction nothing else takes.  Testing every vnode on the bucket is the same
 * question asked once.
 *
 * Upstream answers this with a MOUNT TABLE walk (ufs_mountedon, ufs_fio.c:188,
 * `mp->m_dev == dev').  FGX's mount list lives in the far kernel bank, which
 * this module cannot reach; the flag is the same fact recorded on the device
 * instead, set by ufs_mountfs and cleared by ufs_unmount.
 *
 * Out: 0 if the open may proceed, or the errno that refuses it. */
int
spec_securechr(dev)
    dev_t dev;
{
    register struct vnode *vp;
    dev_t bdev;

    if (securelevel < 1)
        return (0);
    bdev = chrtoblk(dev);
    if (bdev == (dev_t)NODEV)
        return (0);
    for (vp = speclisth[SPECHASH(bdev)]; vp; vp = vp->v_specnext) {
        if (vp->v_rdev != bdev || vp->v_type != VBLK)
            continue;
        if (vp->v_specflags & SI_MOUNTEDON)
            return (EBUSY);
    }
    return (0);
}


/* vfs_getsecurelevel / vfs_setsecurelevel -- the KERN_SECURELVL leaf's two
 * halves, for the far bank's sysctl(2).
 *
 * THE PERMISSION RULES ARE NOT HERE.  Upstream puts them in kern_sysctl.c --
 * the suser() test on any write (kern_sysctl.c:100) and `level < securelevel
 * && u.u_procp->p_pid != 1' (kern_sysctl.c:233) -- because they are about the
 * CALLER, and the caller is what the syscall layer knows.  This side owns the
 * variable and the one value it refuses.
 *
 * -1 IS ACCEPTED.  Upstream's "permanently insecure" is a compile-time
 * initialiser rather than a settable value there, but nothing enforces that,
 * and refusing it here would be a rule upstream does not have. */
int
vfs_getsecurelevel()
{
    return (securelevel);
}

int
vfs_setsecurelevel(level)
    int level;
{
    if (level > 1)
        return (EINVAL);
    securelevel = level;
    return (0);
}


/* vcount -- how many references exist to a DEVICE, across every vnode naming
 * it.
 *
 * THE REASON THIS IS NOT v_usecount.  A driver's last close is the point at
 * which it may reset the hardware, and with two vnodes naming one device the
 * count on either one reaching zero means nothing -- the other path may still
 * be open.  Summing the set is the only correct answer, and getting it wrong
 * is a device that resets itself under a process still using it.
 *
 * Unreferenced aliases are collected on the way past, which is Reno's; it is
 * also why the walk restarts, since vgone can sleep. */
int vcount(vp)
    register struct vnode *vp;
{
    register struct vnode *vq;
    int count;

    if ((vp->v_flag & VALIASED) == 0)
        return (vp->v_usecount);
loop:
    count = 0;
    for (vq = *vp->v_hashchain; vq; vq = vq->v_specnext) {
        if (vq->v_rdev != vp->v_rdev || vq->v_type != vp->v_type)
            continue;
        if (vq->v_usecount == 0) {
            vgone(vq);
            goto loop;
        }
        count += vq->v_usecount;
    }
    return (count);
}


/* ---- reclaim ---------------------------------------------------------------
 *
 * Taking a vnode away from its filesystem so the slot can hold a different
 * file.  Three functions, and the split is Reno's:
 *
 *   vclean  does the work -- flush, close, deactivate, reclaim, swap in the
 *           dead vector.  It does NOT touch the free list or the mount list.
 *   vgone   is vclean plus the unlinking: off the mount, back on the free
 *           list, type set to VBAD.  This is what callers use.
 *   vflush  is vgone applied to every vnode of one mount, with a policy for
 *           the ones still in use.
 *
 * The separation exists because a forced unmount cleans a device vnode without
 * discarding it -- vclean(vp, 0), then a new vector -- so the device keeps
 * working while its filesystem goes away.  A single merged function could not
 * express that.
 */

/* vput -- release a vnode that is LOCKED.
 *
 * The whole of it is "unlock, then release", and it exists as its own function
 * because getting the order wrong is a real bug: vrele can call VOP_INACTIVE,
 * which a filesystem is entitled to expect on an unlocked vnode.  Callers that
 * hold an unlocked reference use vrele; callers that hold a locked one use
 * this, and the name is the reminder. */
void vput(vp)
    register struct vnode *vp;
{
    VOP_UNLOCK(vp);
    vrele(vp);
}


/* vclean -- disconnect a vnode from its filesystem.
 *
 * Under DOCLOSE the file is going away for good: its buffers are written out
 * and invalidated, and the filesystem is told to close it.  Without DOCLOSE
 * the vnode is merely being detached and the file itself is left alone.
 *
 * THE ORDER IS THE ALGORITHM, and every step is load-bearing:
 *
 *   1. Reference an ACTIVE vnode before touching it.  If someone still holds
 *      it, its count could otherwise fall to zero part-way through and race
 *      this very function to recycle it.
 *   2. Set VXLOCK.  vget refuses a vnode carrying it, so nobody new can pick
 *      this one up while it is half-detached.
 *   3. VOP_LOCK before the flush.  Even an idle vnode may have a VOP_INACTIVE
 *      still running inside the filesystem; the lock is how this waits for it.
 *   4. Swap the vector BEFORE calling close/inactive/reclaim, and call those
 *      through the SAVED one.  That is the subtle step: the old operations
 *      still have to run, but any NEW call that arrives while they are running
 *      must land on dead_vnodeops instead of re-entering a filesystem that is
 *      already tearing this vnode down.
 *   5. Clear VXLOCK and wake the waiters, whatever happened.
 */
void vclean(vp, flags)
    register struct vnode *vp;
    int flags;
{
    struct vnodeops *origops;
    int active;

    active = vp->v_usecount;
    if (active)
        vref(vp);
    if (vp->v_flag & VXLOCK)
        kc_panic("vclean: deadlock");
    vp->v_flag |= VXLOCK;

    VOP_LOCK(vp);
    if (flags & DOCLOSE)
        vinvalbuf(vp, 1);

    origops = vp->v_op;
    vp->v_op = &dead_vnodeops;
    vp->v_tag = VT_NON;

    (*(origops->vn_unlock))(vp);
    if (active) {
        if (flags & DOCLOSE)
            (*(origops->vn_close))(vp, 0, (char *)0);
        (*(origops->vn_inactive))(vp);
    }
    /* A filesystem that cannot release its private area has lost track of it,
     * and continuing would hand the area to the next file to use this vnode. */
    if ((*(origops->vn_reclaim))(vp))
        kc_panic("vclean: cannot reclaim");
    if (active)
        vrele(vp);

    vp->v_flag &= ~VXLOCK;
    if (vp->v_flag & VXWANT) {
        vp->v_flag &= ~VXWANT;
        kc_wakeup((char *)vp);
    }
}


/* vgone -- clean a vnode and return it to the pool.
 *
 * Three unlinks, in this order: off the mount list, off the device alias chain
 * if it is a device, and onto the head of the free list.  The middle one is
 * what 1.4b left as a comment, and it is not optional bookkeeping -- a freed
 * vnode left on a live hash chain is found by the next checkalias for that
 * device and handed out as an authority for it. */
void vgone(vp)
    register struct vnode *vp;
{
    register struct vnode *vq;
    struct vnode *vx;
    int count;

    /* A teardown already running.  Wait for it and return -- the vnode will
     * have been gone'd by whoever got here first, and doing it twice would
     * reclaim a filesystem's private area that has already been released. */
    if (vp->v_flag & VXLOCK) {
        vp->v_flag |= VXWANT;
        kc_sleep((char *)vp);
        return;
    }

    vclean(vp, DOCLOSE);

    /* Off the mount list.  insmntque(vp, 0) is the same unlink, and using it
     * keeps one copy of the pointer-to-pointer dance. */
    insmntque(vp, (struct mount *)0);

    /* Off the device alias chain.
     *
     * v_hashchain names the BUCKET, not the pointer that references this
     * vnode -- unlike v_freeb and v_mountb, which is why this cannot be the
     * one-store unlink those get and has to walk to find the predecessor.
     * The walk running off the end means the chain and the vnode disagree
     * about which bucket it is in, which is corruption rather than a
     * not-found: it fails loudly instead of leaving the vnode linked.
     *
     * Then the VALIASED bookkeeping.  The flag means "this device has more
     * than one vnode", so removing one can make it false -- and it becomes
     * false for the SURVIVOR, which is why the count is taken over the whole
     * chain rather than decremented.  Exactly one left clears it there; this
     * vnode clears its own either way. */
    if (vp->v_type == VBLK || vp->v_type == VCHR) {
        /* THE SPECINFO BEFORE THE CHAIN, because `v_hashchain' IS
         * `v_un->si_hashchain' -- specdev.h's shorthand expands through the
         * union word.  So a VBLK/VCHR vnode whose v_un is null does not read an
         * empty chain here, it dereferences NULL: the walk below reads bank 0 as
         * a chain of vnodes, finds nothing, and arrives at Reno's
         * panic("missing bdev") having diagnosed the wrong thing.
         *
         * Reno has one string for this arm (kern/vfs_subr.c, the same walk), and
         * that is fine upstream because a vnode cannot reach it without a
         * specinfo.  Splitting the two says whether the defect is a vnode typed
         * as a device with no specinfo, or a specinfo whose chain no longer holds
         * the vnode -- different bugs in different places.  apple/fgx#463
         * presented as the first of those, and neither the arrival nor the walk
         * was at fault: a wild store from net.mod's _Pipe_FreeSlot had zeroed
         * this word while the vnode sat idle on the free list. */
        if (vp->v_un == (struct specinfo *)0)
            kc_panic("vgone: device vnode with no specinfo");
        if (*vp->v_hashchain == vp) {
            *vp->v_hashchain = vp->v_specnext;
        } else {
            for (vq = *vp->v_hashchain; vq; vq = vq->v_specnext) {
                if (vq->v_specnext != vp)
                    continue;
                vq->v_specnext = vp->v_specnext;
                break;
            }
            if (vq == 0)
                kc_panic("vgone: missing bdev");
        }
        if (vp->v_flag & VALIASED) {
            count = 0;
            vx = 0;
            for (vq = *vp->v_hashchain; vq; vq = vq->v_specnext) {
                if (vq->v_rdev != vp->v_rdev || vq->v_type != vp->v_type)
                    continue;
                count++;
                vx = vq;
            }
            /* VALIASED with nothing left to be aliased to is the flag and the
             * chain disagreeing, which is the same class of corruption as the
             * missing predecessor above. */
            if (count == 0)
                kc_panic("vgone: missing alias");
            if (count == 1)
                vx->v_flag &= ~VALIASED;
            vp->v_flag &= ~VALIASED;
        }
        specfree(vp->v_specinfo);
        vp->v_specinfo = 0;
    }

    /* If it is on the free list, move it to the HEAD.  A vnode that has just
     * been reclaimed holds nothing worth caching, so it should be the next one
     * handed out rather than the last -- the opposite of vfree's tail
     * insertion, and the reason the two are not the same function.
     *
     * A vnode reached through getnewvnode is NOT on the list -- vremfree took
     * it off first -- so this arm is skipped there, which is exactly what that
     * ordering is for. */
    if (vp->v_freeb) {
        vremfree(vp);
        vp->v_freef = vnode_free_head;
        vp->v_freeb = &vnode_free_head;
        if (vnode_free_head)
            vnode_free_head->v_freeb = &vp->v_freef;
        else
            vnode_free_tail = &vp->v_freef;
        vnode_free_head = vp;
        freevnodes++;
    }
    /* VBAD is what getnewvnode tests: this vnode belongs to no filesystem and
     * can be handed out without being reclaimed again. */
    vp->v_type = VBAD;
}


/* vflush -- reclaim every vnode belonging to one mount.
 *
 * This is unmount.  skipvp is the one vnode the caller still needs -- the
 * filesystem's root, which it holds for the duration -- and the flags choose
 * what happens to vnodes that are still in use:
 *
 *   default       report EBUSY and change nothing.  umount without -f.
 *   FORCECLOSE    take them away from their users anyway.  umount -f.
 *   SKIPSYSTEM    leave the kernel's own vnodes alone.
 *
 * The loop restarts whenever it finds a vnode that has moved off this mount,
 * because vgone can sleep and the list can be rearranged underneath the walk.
 */
int vflush(mp, skipvp, flags)
    register struct mount *mp;
    struct vnode *skipvp;
    int flags;
{
    register struct vnode *vp;
    struct vnode *nvp;
    int busy;

    if ((mp->mnt_flag & MNT_MPBUSY) == 0)
        kc_panic("vflush: not busy");
    busy = 0;
loop:
    for (vp = mp->mnt_mounth; vp; vp = nvp) {
        if (vp->v_mount != mp)
            goto loop;
        nvp = vp->v_mountf;
        if (vp == skipvp)
            continue;
        if ((flags & SKIPSYSTEM) && (vp->v_flag & VSYSTEM))
            continue;
        /* Nobody is using it: reclaiming is all there is to do. */
        if (vp->v_usecount == 0) {
            vgone(vp);
            continue;
        }
        if (flags & FORCECLOSE) {
            /* A DEVICE KEEPS WORKING ACROSS A FORCED UNMOUNT, and this is the
             * one place vclean's flags argument earns its existence.  A
             * regular file is gone with its filesystem, so vgone.  A device is
             * not: the filesystem that named it is going away, but the driver
             * behind it is still there and a process holding the descriptor
             * still expects to reach it.  So it is cleaned WITHOUT DOCLOSE --
             * detached from the filesystem, not closed -- and given the
             * anonymous device vector, which is what "revert to an anonymous
             * device" means.  It stays on its alias chain throughout; only the
             * mount link goes. */
            if (vp->v_type != VBLK && vp->v_type != VCHR) {
                vgone(vp);
            } else {
                vclean(vp, 0);
                /* No table means no device vnodes were ever minted, so
                 * nothing can be wearing this vector and there is nothing to
                 * revert -- vgone it, which is the arm above. */
                if (vfs_specops == (struct vnodeops *)0) {
                    vgone(vp);
                    continue;
                }
                vp->v_op = vfs_specops;
                insmntque(vp, (struct mount *)0);
            }
            continue;
        }
        busy++;
    }
    if (busy)
        return (EBUSY);
    return (0);
}


/* ===========================================================================
 * PER-PROCESS NAMEIDATA (UFS 1.2).
 *
 * WHERE THIS SITS IN RENO.  Reno keeps its nameidata helpers -- ndinit, nddup,
 * ndrele -- in this file (kern/vfs_subr.c:160-205), so these live here too.
 * nddup and ndrele are NOT ported: both exist to serve rename(2), and nddup's
 * whole body is a crhold of a ucred this kernel does not have and will not --
 * there is no refcount to take when the ids belong to the running process
 * (file.h).  Naming them
 * here rather than inventing a different shape is the point.
 *
 * WHAT THIS REPLACES.  1.6b's namei took its pathname buffer from the CALLER
 * (`ni_pnbuf` had to be a MAXPATHLEN buffer the caller owned), because there
 * was no per-process storage to hang one off and a static inside namei would
 * be a shared work area crossing a sleep -- apple/fgx#41's shape, and every
 * VFS wait sleeps.  The ownership question was handed to the caller rather
 * than answered wrongly.  This answers it.
 *
 * THE DIFFERENCE FROM RENO, STATED.  Reno's buffer is MALLOC(M_NAMEI, M_WAITOK)
 * per call, freed on the way out; only the nameidata is in the u-area.  Kernel
 * C here has no malloc, and at MAXPATHLEN 128 rather than Reno's 1024 it does
 * not need one: the buffer is PAIRED with its slot for the life of the system.
 * A slot therefore arrives with ni_pnbuf already set, and namei no longer has
 * a buffer to acquire or release -- which also means Reno's HASBUF flag has
 * nothing to do here yet.  It keeps its bit in namei.h against the caller that
 * needs it (a symlink re-walk rewrites the buffer in place).
 * =========================================================================== */

/* Which process is running.  A KERNEL SERVICE, not a read: _curTask is a
 * kernel DIRECT PAGE cell, and kernel C runs on FGX_DP_KERNELC where that
 * offset is a slot in fcc's register file.  See kc_sys.s. */
extern int kc_curpid();

/* The slots and their buffers, carved from the VFS pool arena.  Uninitialised
 * pointers on purpose: kernel C cannot hold an initialised pointer-to-data
 * global (apple/fgx#88), and these are set by ndinit at boot. */
struct nameidata *nd_pool;
char             *nd_bufs;


/* ndinit -- carve the nameidata slots and pair each with its buffer.
 *
 * Third and last link in vfs_init's chain, and it returns the end of its own
 * carve for the same reason the others do: exactly one place knows how big
 * this pool is, so nothing here can disagree with the generator that sized the
 * allocation.
 */
char *
ndinit(arena)
char *arena;
{
    register int i;
    register int n;

    n = VFS_NPROC * VFS_NDPERPROC;
    nd_pool = (struct nameidata *)arena;
    nd_bufs = (char *)&nd_pool[n];

    /* The slots are NOT seeded with their buffers here.  ndslot derives the
     * pairing from the index on every hand-out, so seeding it would be a
     * second copy of that arithmetic -- and the copy that goes stale is the
     * one nothing re-runs.
     *
     * `&nd_bufs[...]`, NOT `nd_bufs + ...`.  Pointer arithmetic has dropped
     * the bank byte in this campaign before, and the arena is in a different
     * bank from this code BY DESIGN -- the same note vntblinit carries. */
    return (&nd_bufs[n * 2 * MAXPATHLEN]);
}


/* ndslot -- process `pid`'s nameidata slot `which`, cleared and ready.
 *
 * THE INDEXING, SEPARATED FROM WHOSE IT IS.  ndget below is the interface
 * every real caller uses; this exists because the pid and the arithmetic fail
 * for different reasons and a probe cannot exercise the arithmetic through a
 * function that first demands a running process.  It is not a back door: a
 * caller that passes a pid other than its own gets another process's storage,
 * which is why nothing outside this file and the probe calls it.
 *
 * EVERY FIELD IS CLEARED, AND THE PAIRING IS RE-DERIVED RATHER THAN PRESERVED.
 * Clearing matters most for ni_rdir: a walk that forgot to set it would
 * otherwise silently adopt the PREVIOUS walk's chroot -- a containment escape
 * rather than a wrong answer.  Clearing is cheap; reasoning about which stale
 * field is harmless is not.
 *
 * ni_pnbuf is then recomputed from the index, NOT carried across.  Preserving
 * the field was the first shape and it was wrong: a caller that nulls or
 * corrupts ni_pnbuf would break that slot for the life of the system, with no
 * way to repair it -- every later hand-out would faithfully preserve the
 * damage.  The buffer's address is a function of the slot, so deriving it is
 * both cheaper to reason about and self-healing.  (The probe found this: its
 * "a missing buffer is refused" case nulls the field on purpose, and every
 * subsequent walk in that process then failed.)
 *
 * Returns 0 for a pid or a `which` this build has no slot for.  A caller that
 * gets 0 has asked for storage that does not exist and must fail rather than
 * proceed -- there is no fallback buffer to lend it.
 *
 * THE PID RANGE CHECK IS LOAD-BEARING, NOT DEFENSIVE.  _curTask is not written
 * until main.s:671, and at mod_init it holds uninitialised boot data -- MEASURED
 * as 2048.  So the boot path really does reach ndget with a "pid" of 2048, and
 * this check is the only thing between that and an index 2047 slots past the
 * end of a 22-slot pool.
 */
struct nameidata *
ndslot(pid, which)
int pid;
int which;
{
    register struct nameidata *ndp;
    register int idx;
    register int i;

    if (which < 0 || which >= VFS_NDPERPROC)
        return ((struct nameidata *)0);
    if (pid < 1 || pid > VFS_NPROC)
        return ((struct nameidata *)0);
    if (nd_pool == (struct nameidata *)0)
        return ((struct nameidata *)0);

    idx = (pid - 1) * VFS_NDPERPROC + which;
    ndp = &nd_pool[idx];

    for (i = 0; i < (int)sizeof(struct nameidata); i++)
        ((char *)ndp)[i] = 0;
    ndp->ni_pnbuf = &nd_bufs[idx * 2 * MAXPATHLEN];
    ndp->ni_pnalt = &nd_bufs[idx * 2 * MAXPATHLEN + MAXPATHLEN];

    /* THE FIVE FIELDS THE CLEAR ABOVE GETS WRONG.  UFS 1.12c, and namei.h has
     * carried the warning since 1.6a because the failure modes differ:
     *
     *   ni_iov and ni_base are SELF-POINTERS.  Left from a previous holder
     *   they would name that slot's copy; left zero they name nothing.  They
     *   are DERIVED here on every hand-out, which is the rule ni_pnbuf above
     *   already follows and for the same reason.
     *
     *   ni_rw zero is UIO_READ, and ufs_write answers that with
     *   `kc_panic("ufs_write mode")` -- loud, immediate, and therefore the
     *   safe one to get wrong.
     *
     *   ni_uioseg zero is UIO_USERSPACE, and NOTHING CHECKS IT.  A directory
     *   entry would be assembled from whatever that offset happens to address
     *   in the current process.  This is the one that would not announce
     *   itself, and it is the reason all five are set here rather than at the
     *   two or three call sites that could plausibly own them.
     *
     *   ni_iovcnt zero is "no iovecs" -- a transfer of nothing, which reads as
     *   a successful write of an entry that never appeared.
     *
     * Reno does exactly this in ndinit (vfs_subr.c:160, after its own bzero). */
    ndp->ni_uio.uio_iov    = &ndp->ni_iovec;
    ndp->ni_uio.uio_iovcnt = 1;
    ndp->ni_iovec.iov_base = (char *)&ndp->ni_dent;
    ndp->ni_uio.uio_rw     = UIO_WRITE;
    ndp->ni_uio.uio_segflg = UIO_SYSSPACE;
    return (ndp);
}


/* ndget -- THIS process's nameidata slot `which`.  Reno spells it `&u.u_nd`,
 * and gets rename's second one as a kernel stack local; FGX has neither a
 * u-area nor a kernel stack that can hold one, so both are indexed.
 *
 * THE PID IS READ FRESH, EVERY CALL, AND IS NEVER CACHED.  A pid latched
 * before a sleep names a different process after one, and here that would hand
 * out another process's slot -- the walk would then scribble a path into a
 * buffer some other task is reading.  That is apple/fgx#41 with a worse blast
 * radius, so the read stays inside this function and nothing stores it.
 *
 * IT RETURNS 0 ON THE BOOT PATH, AND THAT IS CORRECT RATHER THAN A LIMITATION.
 * Modules are loaded at main.s:397 and _curTask is not set until main.s:671,
 * so during mod_init there is NO current process and there is no honest slot
 * to hand back.  Nothing on that path needs one: the root mount reaches its
 * filesystem through bdevvp and VFS_ROOT, not through namei.  Inventing a slot
 * -- defaulting the pid to 1, say -- would hand boot code the storage that
 * init(8) is about to be given, and the collision would appear much later as a
 * corrupted path in an unrelated program.
 */
struct nameidata *
ndget(which)
int which;
{
    return (ndslot(kc_curpid(), which));
}



/* vfs_dounmount -- detach a mounted filesystem.  4.3BSD-Reno
 * kern/vfs_syscalls.c:dounmount(), plus the one line Reno keeps in
 * vfs_remove().  UFS 1.8b-3c.
 *
 * IT HAPPENS IN THIS MODULE because what it needs is here: the name cache's
 * cache_purgevfs through vfs_cacheops, and vrele for the covered vnode.  So
 * unmount(2) resolves the path and checks that it named a mount ROOT, and hands
 * the mount over.
 *
 * MNT_MPBUSY IS PUBLISHED BECAUSE vflush ASSERTS IT.  vfs_subr.c's vflush
 * opens with Reno's `if ((mp->mnt_flag & MNT_MPBUSY) == 0) panic("vflush: not
 * busy")', which is upstream's way of saying the caller must have taken the
 * mount out of service first -- vfs_busy in Reno, this line here.  Without it
 * the first unmount kc_panics, on the boot path, from inside the filesystem.
 * It is NOT the lock: MNT_MLOCK and its sleep are what vfs_lock takes, and
 * nothing here can be walking the mount concurrently for the reason
 * vfs_mountat gives.
 *
 * THE COVER IS CLEARED HERE AND RENO CLEARS IT IN vfs_remove.  Upstream's
 * dounmount reads at first as though it forgets -- it vreles the covered vnode
 * and frees the mount without touching v_mountedhere -- and it does not:
 * `vfs_remove' is the very next call, and its body is
 * `mp->mnt_vnodecovered->v_mountedhere = (struct mount *)0;'.  The rest of
 * vfs_remove unlinks the mount from a circular list this system does not have,
 * so the one line that is not about the list comes here instead.
 *
 * LEAVING IT SET IS FATAL HERE, AND MEASURED RATHER THAN ARGUED.  Reno frees
 * the mount to the heap, so a stale cover points at freed memory.  This hands
 * a STATIC SLOT back by clearing mnt_op, and lookup's descent tests the
 * covered vnode's own word and not mnt_op -- so the very next walk over that
 * directory dispatches VFS_ROOT through a null mnt_op.  Delete this line and
 * the machine does not reach `fs: /dev on unit' or a shell prompt at all: the
 * probe's own remount is the walk that does it, one case later.
 *
 * So this is the rare divergence in the OTHER direction -- upstream's line
 * matters MORE here than where it came from, because a freed slot is a
 * plausible pointer where freed memory is not.
 *
 * NOT CARRIED: vfs_busy/vfs_lock's sleeping and the MNT_UNMOUNT flag they
 * publish for other walkers; VFS_SYNC, which has no vfsops slot because
 * nothing writes until 1.12; and xumount, there being no text table.
 */
int vfs_dounmount(mp, flags)
    struct mount *mp;
    int flags;
{
    struct vnode *coveredvp;
    int           error;

    if (mp == (struct mount *)0 || mp->mnt_op == (struct vfsops *)0)
        return (EINVAL);        /* not a mounted filesystem */

    coveredvp = mp->mnt_vnodecovered;
    mp->mnt_flag |= MNT_MPBUSY;

    /* BEFORE THE FILESYSTEM GOES, not after: every entry names a vnode this
     * mount owns, and VFS_UNMOUNT is what takes them away. */
    if (vfs_cacheops)
        (*vfs_cacheops->co_purgevfs)(mp);

    error = VFS_UNMOUNT(mp, flags);
    if (error) {
        mp->mnt_flag &= ~MNT_MPBUSY;
        return (error);
    }

    /* RENO'S vfs_remove IS TWO THINGS AND THIS USED TO BE ONE OF THEM.
     * Upstream (kern/vfs_subr.c:42-52) reads:
     *
     *      if (mp == rootfs) panic("vfs_remove: unmounting root");
     *      mp->mnt_prev->mnt_next = mp->mnt_next;
     *      mp->mnt_next->mnt_prev = mp->mnt_prev;
     *      mp->mnt_vnodecovered->v_mountedhere = (struct mount *)0;
     *      vfs_unlock(mp);
     *
     * -- an UNLINK from the mount list and a COVER drop.  Only the cover half
     * was here, and the comment named the upstream line as though both were.
     * That was harmless exactly as long as there was no list; getfsstat(2)
     * built one (vfs_syscalls.c), so an unmount that skipped the unlink would
     * leave df(1) walking through a `struct mount' whose filesystem is gone
     * -- and, the slot being reusable, eventually a cycle. */
    if (mp->mnt_next != (struct mount *)0 &&
        mp->mnt_prev != (struct mount *)0) {
        mp->mnt_prev->mnt_next = mp->mnt_next;
        mp->mnt_next->mnt_prev = mp->mnt_prev;
        mp->mnt_next = (struct mount *)0;
        mp->mnt_prev = (struct mount *)0;
    }

    /* The cover is dropped only once the filesystem is really gone, so a
     * refused unmount leaves the mount reachable by the name it was mounted
     * on. */
    if (coveredvp != (struct vnode *)0) {
        coveredvp->v_un      = (struct specinfo *)0;
        mp->mnt_vnodecovered = (struct vnode *)0;
        vrele(coveredvp);       /* the reference the mount held since 1.8b-2 */
    }
    /* mnt_op is already null -- the filesystem's own unmount clears it, which
     * is what marks the table slot free.  The flag is cleared for tidiness;
     * mountalloc zeroes mnt_flag when the slot is next claimed. */
    mp->mnt_flag &= ~MNT_MPBUSY;
    return (0);
}
