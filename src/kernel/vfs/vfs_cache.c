/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/vfs_cache.c
 *   Ported from kern/vfs_cache.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 */
/* vfs_cache.c -- the name cache.
 *
 * Ported from 4.3BSD-Reno kern/vfs_cache.c.  See namei.h for what the cache is
 * for and why staleness, not lookup, is the hard part.
 *
 * THREE LISTS, AND EACH ONE ANSWERS A DIFFERENT QUESTION.  This is the piece
 * worth holding in mind before reading anything below:
 *
 *   the hash chain   "is <name> in <directory>?"  -- the lookup path.
 *   the LRU chain    "which entry should the next insertion take?"  Entries
 *                    are used from the HEAD and returned to the TAIL, so the
 *                    head is always the least recently useful.
 *   nc_prev          the LRU chain's back-link, and it holds the ADDRESS OF
 *                    the pointer that references this entry -- the same idiom
 *                    the vnode free list and the buffer vnode lists use, so
 *                    one store unlinks head or middle alike.
 *
 * An entry is on the hash chain only while it holds a name.  A freed one is
 * given a chain of ITSELF -- Reno's "dummy hash chain" -- so a later remque on
 * it unlinks nothing rather than corrupting a real bucket.  That is not
 * defensive coding; cache_lookup's drop path and cache_enter's reuse path both
 * reach entries in that state.
 *
 * A HIT IS NOT A POINTER MATCH.  Every hit is checked against the capability
 * number recorded when the entry was made, on BOTH ends -- the directory and
 * the file.  A cache that skipped that would answer with whatever file now
 * occupies a recycled vnode slot, with no error anywhere.
 */

#include "fsparam.h"
#include "vnode.h"
#include "mount.h"
#include "namei.h"

/* Monotonic capability counter behind v_id.  cache_purge bumps it, which is
 * what makes a rename invalidate every cached name for a vnode without the
 * cache being told and without walking anything.
 *
 * IT IS THE CACHE'S, WHICH IS ALSO WHERE RENO KEEPS IT -- `nextvnodeid',
 * declared in sys/namei.h:127 beside the namecache structure and touched by
 * nothing but cache_purge.  It sat in vfs_subr.c while both files were one
 * bank; the move here is what lets cache_purge run entirely in this module,
 * because a module reads its globals DBR-relatively and vfs.mod's are not
 * reachable from ufsdir's bank.
 *
 * 32-bit on purpose (see vnode.h): it must not wrap while a stale cached
 * pointer to a recycled vnode exists, and 16 bits would wrap after 65536
 * reuses on a machine that can easily do that in an afternoon.
 *
 * STARTS AT 1, not 0, and nchinit is what sets it: zero is the value a
 * never-minted vnode carries out of a zeroed arena, so an id of zero must
 * never be a LIVE one or the staleness test would pass on it by accident. */
unsigned long vnode_next_id;

/* nchinit RETURNS A POINTER -- the end of its own carve -- so this declaration
 * must say so: defaulted to int, the bank byte would be dropped on the way.
 *
 * NOTHING CHAINS IT ANY MORE.  It was the middle link of vfs_init's
 * `ndinit(nchinit(vntblinit(arena)))' while the cache was vfs.mod's; ufsdir.mod
 * carves this pool by itself, from its own Kmalloc, at mod_init.  The return
 * value is kept because it costs nothing and a carve that cannot say where it
 * ended is a carve nothing can check. */
char *nchinit();

/* The pool.  A flat array rather than Reno's malloc-until-desiredvnodes: the
 * count is a compile-time knob like every other size in this campaign, and
 * every entry is on exactly one of the two chains from init onwards -- a free
 * entry is simply one sitting at the head of the LRU with no name.
 *
 * THE STORAGE IS NOT DECLARED HERE, for the reason vnode_pool records: 2,048
 * bytes of it, in the one bank that is scarce.  nchinit takes the base. */
struct namecache *namecache_pool;

/* The buckets.  Two pointers each, aliasing a namecache's first two fields;
 * the chain walk casts a bucket to a namecache so the bucket is its own
 * sentinel.  See namei.h.
 *
 * These STAY here.  They are 128 bytes of list heads, not a pool, and nchash()
 * takes their address on every lookup -- moving them would put a runtime
 * indirection on the hot path to save a rounding error. */
struct nchash nchashtbl[NCHASH];

/* LRU chain.  Head is the next entry to be taken, tail is where a
 * freshly-used one goes back. */
struct namecache  *nchhead;
struct namecache **nchtail;

struct nchstats nchstats;

/* Reno keeps this as a tunable and so does this: a machine that is behaving
 * strangely can have the cache turned off without a rebuild, and the two
 * behaviours are then directly comparable.  A cache is exactly the kind of
 * thing that hides a bug elsewhere by answering before the bug runs. */
int doingcache = 1;


/* The bucket a hash lands in, as a namecache so it can be a list sentinel. */
static struct namecache *
nchbucket(hash)
    unsigned long hash;
{
    return ((struct namecache *)&nchashtbl[(int)(hash & (unsigned long)(NCHASH - 1))]);
}


/* insque/remque, which Reno gets from the VAX instruction set.
 *
 * Spelled out here rather than hidden in a macro because the buffer cache
 * beside this file already writes them out (binshash/bremhash) and one idiom
 * per tree is worth more than brevity. */
static void
ncinshash(ncp, dp)
    register struct namecache *ncp;
    register struct namecache *dp;
{
    ncp->nc_forw = dp->nc_forw;
    ncp->nc_back = dp;
    dp->nc_forw->nc_back = ncp;
    dp->nc_forw = ncp;
}


static void
ncremhash(ncp)
    register struct namecache *ncp;
{
    ncp->nc_back->nc_forw = ncp->nc_forw;
    ncp->nc_forw->nc_back = ncp->nc_back;
}


/* Move an entry to the TAIL of the LRU -- "this one was useful".
 *
 * Reno guards this with `if (ncp->nc_nxt)`, which reads as a null check and is
 * not one: nc_nxt is null exactly when the entry is ALREADY at the tail, and
 * unlinking it would then leave nchtail pointing into a removed entry.  The
 * guard is the already-there case, not a safety net. */
static void
nclru_totail(ncp)
    register struct namecache *ncp;
{
    if (ncp->nc_nxt == 0)
        return;
    *ncp->nc_prev = ncp->nc_nxt;
    ncp->nc_nxt->nc_prev = ncp->nc_prev;
    ncp->nc_nxt = 0;
    ncp->nc_prev = nchtail;
    *nchtail = ncp;
    nchtail = &ncp->nc_nxt;
}


/* Take an entry off the LRU wherever it is.  nc_prev holds the address of the
 * pointer that references this entry, so the unlink needs no branch; only the
 * tail pointer has to be repaired when the entry was last. */
static void
nclru_remove(ncp)
    register struct namecache *ncp;
{
    *ncp->nc_prev = ncp->nc_nxt;
    if (ncp->nc_nxt)
        ncp->nc_nxt->nc_prev = ncp->nc_prev;
    else
        nchtail = ncp->nc_prev;
}


/* Put an entry at the HEAD of the LRU -- "take this one next".  Where a
 * dropped or invalidated entry goes, which is the opposite end from a useful
 * one and is the whole of the replacement policy. */
static void
nclru_tohead(ncp)
    register struct namecache *ncp;
{
    ncp->nc_nxt = nchhead;
    ncp->nc_prev = &nchhead;
    if (nchhead)
        nchhead->nc_prev = &ncp->nc_nxt;
    else
        nchtail = &ncp->nc_nxt;
    nchhead = ncp;
}


/* Detach an entry from its bucket and leave it pointing at itself.
 *
 * The self-chain matters: a freed entry is still reachable through the LRU,
 * and cache_enter will remque it again when it takes it.  Without this that
 * second remque would write through stale neighbours into a live bucket. */
static void
ncdetach(ncp)
    register struct namecache *ncp;
{
    ncremhash(ncp);
    ncp->nc_forw = ncp;
    ncp->nc_back = ncp;
}


/* vfs_init IS NOT HERE ANY MORE.  It moved to vfs_init.c: a composition
 * root references every pool, so whatever file holds it drags the whole
 * VFS into anything that includes that file -- and five fcc fixtures
 * include THIS one for the name cache without ever calling vfs_init.
 * See vfs_init.c for what that cost. */



/* nchinit -- build both chains.  Every entry starts free, in index order, so
 * a fresh cache hands out namecache_pool[0] first and a fixture can predict
 * it.  Reno calls this from vfs_init; FGX calls it from the kernel's VFS boot
 * path beside vntblinit. */
char *
nchinit(arena)
char *arena;
{
    register int i;
    register struct namecache *ncp;
    register struct nchash *nhp;

    namecache_pool = (struct namecache *)arena;

    /* The capability counter comes up with the table it protects.  vntblinit
     * set it while the two lived in one bank; it is this file's now, and this
     * is the init that runs before any vnode is minted. */
    vnode_next_id = 1;

    nchstats.ncs_goodhits = 0;
    nchstats.ncs_neghits = 0;
    nchstats.ncs_badhits = 0;
    nchstats.ncs_falsehits = 0;
    nchstats.ncs_miss = 0;
    nchstats.ncs_long = 0;
    nchstats.ncs_pass2 = 0;
    nchstats.ncs_2passes = 0;

    for (i = 0; i < NCHASH; i++) {
        nhp = &nchashtbl[i];
        nhp->nch_forw = (struct namecache *)nhp;
        nhp->nch_back = (struct namecache *)nhp;
    }

    nchhead = 0;
    nchtail = &nchhead;

    /* A NULL ARENA IS A LEGAL CALL AND LEAVES A WELL-FORMED EMPTY CACHE.
     * ufsdir.mod's mod_init carves this pool from Kmalloc and that can fail;
     * the module still comes up, because a filesystem with no name cache is
     * the filesystem this tree shipped before the cache was wired -- correct,
     * and slower.
     *
     * IT MUST STILL RUN THE LOOP ABOVE, and that is the whole reason this arm
     * is here rather than a bail-out at the top.  An untouched nchashtbl holds
     * NULL, not self-sentinels, so cache_lookup's `for (ncp = dp->nc_forw;
     * ncp != dp; ...)' would take the first iteration and dereference zero.
     * cache_purgevfs walks the same buckets on every unmount and cache_purge
     * walks them on the counter wrap.  Turning the cache off does not make
     * those walks stop; giving them an empty, closed table does.
     *
     * doingcache IS CLEARED TOO, so the two hot entries return before they
     * reach a pool that is not there.  vnode_next_id is already set above:
     * the capability mint is NOT the cache's to switch off, because
     * getnewvnode calls through here for it on every handout. */
    if (namecache_pool == (struct namecache *)0) {
        doingcache = 0;
        return ((char *)0);
    }

    /* Backwards, so that walking the finished LRU from the head yields the
     * pool in index order. */
    for (i = NNAMECACHE - 1; i >= 0; i--) {
        ncp = &namecache_pool[i];
        ncp->nc_dvp = 0;
        ncp->nc_vp = 0;
        ncp->nc_dvpid = 0;
        ncp->nc_vpid = 0;
        ncp->nc_nlen = 0;
        ncp->nc_forw = ncp;         /* a dummy chain: on no bucket */
        ncp->nc_back = ncp;
        nclru_tohead(ncp);
    }
    return ((char *)&namecache_pool[NNAMECACHE]);
}


/* namehash -- the discriminator for a component name.
 *
 * Reno computes this in namei, which is 1.6b; it lives here so the cache's two
 * entry points can be used before the walker exists, and so the hash and the
 * comparison that depends on it stay in one file.
 *
 * The mix is the classic shift-and-add.  What matters is not its quality but
 * that the SAME function is used to place an entry and to find it -- so it is
 * one function, rather than a line repeated at both call sites. */
unsigned long namehash(name, len)
    register char *name;
    register int len;
{
    register unsigned long h;
    register int i;

    h = 0;
    for (i = 0; i < len; i++)
        h = (h << 4) + (h >> 12) + (unsigned long)(unsigned char)name[i];
    return (h);
}


static int
namecmp(a, b, len)
    register char *a;
    register char *b;
    register int len;
{
    while (len--) {
        if (*a++ != *b++)
            return (1);
    }
    return (0);
}


/* THE READ AND WRITE HALVES, cache_lookup and cache_enter.
 *
 * THEY WERE A FILE OF THEIR OWN between 2026-09-06 and the wiring, and the
 * reason was a bank ceiling rather than a porting one: vfs.mod is a single
 * 64 KB bank, link(2) put it over the top, and these two were 2,398 bytes that
 * nothing called -- ufs_lookup did not consult the cache.  Keeping them out of
 * `_VFS_C` was how the shipping module stopped carrying code it could not
 * reach.
 *
 * BOTH REASONS ARE GONE AT ONCE.  ufs_lookup calls them now, and the cache
 * moved to ufsdir.mod to be in the same bank as that caller, which is also
 * where the space was.  Reno keeps all five entries in one kern/vfs_cache.c
 * and so does this again. */

/* cache_purge -- invalidate every cached name for one vnode.
 *
 * IT DOES NOT WALK THE CACHE, and that is the design rather than a shortcut.
 * Bumping the vnode's capability number makes every entry that recorded the
 * old one fail its check on the next lookup -- so a rename costs one increment
 * instead of a scan of the whole table.
 *
 * Reno pre-increments; this post-increments, so the numbering is unchanged
 * from what getnewvnode minted inline before this function existed and no
 * fixture expectation moves.  The wrap test moves with it: the id that was
 * just ASSIGNED being zero is the turn.
 *
 * The table walk exists only for the WRAP.  When the counter returns to zero
 * the numbers start repeating, and an entry holding a stale id could match a
 * new one by coincidence; every recorded id is zeroed so nothing can.  On a
 * 32-bit counter that is a once-in-4-billion-handouts event, which is exactly
 * why v_id is not 16 bits -- at that width it would be a routine occurrence
 * and this walk would be a regular cost. */
void cache_purge(vp)
    struct vnode *vp;
{
    register struct namecache *ncp;
    register struct namecache *dp;
    register int i;

    vp->v_id = vnode_next_id++;
    if (vp->v_id != 0)
        return;

    for (i = 0; i < NCHASH; i++) {
        dp = (struct namecache *)&nchashtbl[i];
        for (ncp = dp->nc_forw; ncp != dp; ncp = ncp->nc_forw) {
            ncp->nc_vpid = 0;
            ncp->nc_dvpid = 0;
        }
    }
    vp->v_id = vnode_next_id++;
}


/* cache_purgevfs -- drop every entry belonging to one mount.
 *
 * Unmount.  Unlike cache_purge this cannot use the capability number: the
 * vnodes are going away entirely, so there is nothing left to re-number, and
 * the entries have to be found and freed.
 *
 * Reno walks the LRU and restarts it after every removal, and its comment
 * cheerfully admits the result is O(n^2).  This walks the HASH TABLE instead,
 * which visits every entry exactly once: the restart exists in Reno because
 * removal edits the list being walked, and taking the next pointer before
 * removing removes the need for it.  Same set of entries, same end state. */
void cache_purgevfs(mp)
    register struct mount *mp;
{
    register struct namecache *ncp;
    register struct namecache *nxt;
    register struct namecache *dp;
    register int i;

    for (i = 0; i < NCHASH; i++) {
        dp = (struct namecache *)&nchashtbl[i];
        for (ncp = dp->nc_forw; ncp != dp; ncp = nxt) {
            nxt = ncp->nc_forw;
            if (ncp->nc_dvp == 0 || ncp->nc_dvp->v_mount != mp)
                continue;
            ncp->nc_vp = 0;
            ncp->nc_dvp = 0;
            ncp->nc_nlen = 0;
            ncdetach(ncp);
            nclru_remove(ncp);
            nclru_tohead(ncp);
        }
    }
}





/* cache_lookup -- is this name in this directory?
 *
 * THREE RETURN VALUES, and they are not a scale:
 *
 *   -1      HIT.  ndp->ni_vp is the answer.
 *    ENOENT NEGATIVE HIT.  The name is known NOT to exist.  This is not a
 *           failure to answer -- it is an answer, and it is what stops a
 *           shell's PATH search re-reading every directory for a command that
 *           is not in the first four of them.
 *    0      MISS.  The caller must go to the filesystem.
 *
 * A caller that treated ENOENT and 0 alike would still be correct and would
 * throw away half the point of the cache.
 */
int cache_lookup(ndp)
    register struct nameidata *ndp;
{
    register struct namecache *ncp;
    register struct namecache *dp;
    struct vnode *dvp;

    if (!doingcache)
        return (0);
    if (ndp->ni_namelen > NCHNAMLEN) {
        nchstats.ncs_long++;
        /* Not merely uncached but unCACHEABLE: tell the caller not to offer it
         * back, or every long-name lookup would insert an entry that the next
         * lookup of the same name is guaranteed to skip. */
        ndp->ni_makeentry = 0;
        return (0);
    }

    dvp = ndp->ni_dvp;
    dp = nchbucket(ndp->ni_hash);
    for (ncp = dp->nc_forw; ncp != dp; ncp = ncp->nc_forw) {
        if (ncp->nc_dvp == dvp &&
            ncp->nc_dvpid == dvp->v_id &&
            ncp->nc_nlen == ndp->ni_namelen &&
            namecmp(ncp->nc_name, ndp->ni_ptr, (int)ncp->nc_nlen) == 0)
            break;
    }
    if (ncp == dp) {
        nchstats.ncs_miss++;
        return (0);
    }

    if (!ndp->ni_makeentry) {
        /* The caller is about to delete or rewrite this name, so the entry is
         * about to be wrong whatever it says.  Counted as a bad hit and
         * dropped below rather than returned. */
        nchstats.ncs_badhits++;
    } else if (ncp->nc_vp == 0) {
        nchstats.ncs_neghits++;
        nclru_totail(ncp);
        return (ENOENT);
    } else if (ncp->nc_vpid != ncp->nc_vp->v_id) {
        /* THE STALENESS CASE.  The name still matches and the pointer is still
         * a vnode -- but a different file's vnode.  Counted separately from a
         * miss precisely because the two are indistinguishable to a caller and
         * very different to anyone asking why the cache is not helping. */
        nchstats.ncs_falsehits++;
    } else {
        nchstats.ncs_goodhits++;
        nclru_totail(ncp);
        ndp->ni_vp = ncp->nc_vp;
        return (-1);
    }

    /* Fall-through: the entry is unusable.  Free it -- off the bucket, and to
     * the HEAD of the LRU so it is the next one reused. */
    nclru_remove(ncp);
    ncdetach(ncp);
    nclru_tohead(ncp);
    return (0);
}


/* cache_enter -- remember what a lookup found.
 *
 * ni_vp == 0 IS NOT AN ERROR PATH.  It records that the name does NOT exist,
 * which is the negative entry cache_lookup returns ENOENT for.  Reno caches
 * both and so does this. */
void cache_enter(ndp)
    register struct nameidata *ndp;
{
    register struct namecache *ncp;

    if (!doingcache)
        return;
    if (ndp->ni_namelen > NCHNAMLEN)
        return;

    /* The head of the LRU is the victim.  Unlike Reno there is no "allocate
     * until the pool is full" arm: every entry is on the LRU from nchinit, so
     * a cache that has never been used hands out its unused entries in index
     * order through this same path. */
    ncp = nchhead;
    if (ncp == 0)
        return;
    nclru_remove(ncp);
    ncremhash(ncp);

    ncp->nc_vp = ndp->ni_vp;
    if (ndp->ni_vp)
        ncp->nc_vpid = ndp->ni_vp->v_id;
    else
        ncp->nc_vpid = 0;
    ncp->nc_dvp = ndp->ni_dvp;
    ncp->nc_dvpid = ndp->ni_dvp->v_id;
    ncp->nc_nlen = (char)ndp->ni_namelen;
    {
        register int i;
        for (i = 0; i < ndp->ni_namelen; i++)
            ncp->nc_name[i] = ndp->ni_ptr[i];
    }

    /* Newly useful, so the TAIL. */
    ncp->nc_nxt = 0;
    ncp->nc_prev = nchtail;
    *nchtail = ncp;
    nchtail = &ncp->nc_nxt;

    ncinshash(ncp, nchbucket(ndp->ni_hash));
}


/* THE TWO ENTRIES vfs.mod STILL NEEDS, as a table it can dispatch through.
 *
 * The cache is this module's, beside the ufs_lookup.c that is its only hot-path
 * caller.  vfs.mod keeps the two RARE reasons to disturb it -- getnewvnode
 * mints a capability number on every vnode handout, vfs_dounmount drops a whole
 * filesystem's entries -- and a module cannot call a function in another bank
 * by name.
 *
 * SO IT IS A TABLE OF &function CELLS, which is the one thing in this tree that
 * carries a bank across the seam: fcc emits MOD_FN_PTR for each and
 * _Mod_StampFnPtrs fills the bank byte at load time, exactly as it does for the
 * vnodeops tables beside it.  ufs_dirinit hands the address to vfs.mod once;
 * namei.h carries the argument for the shape.
 *
 * THE ORDER IS namei.h's, not this file's -- it is a structure, and a cell in
 * the wrong slot would call cache_purgevfs with a vnode. */
struct cacheops ufs_cacheops = {
    cache_purge,
    cache_purgevfs
};
