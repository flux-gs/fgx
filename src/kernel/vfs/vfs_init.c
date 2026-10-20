/* FGX-Origin: original -- FGX code.  Reno has no vfs_init function to port:
 * its pools are initialised from init_main's boot path and each filesystem
 * gets a vfs_init through vfssw, so the composition root below is FGX's own
 * and contains none of the Regents' work.
 * vfs_init.c -- the VFS's composition root.  UFS 1.2c.
 *
 * ONE FUNCTION, AND IT IS IN A FILE OF ITS OWN FOR A REASON THE TREE PAID FOR.
 * This used to live in vfs_cache.c, whose comment explained the choice: keeping
 * it out of vfs_subr.c meant a fixture wanting only the vnode layer could
 * include vfs_subr.c alone.  That reasoning was right and its conclusion was
 * one file short -- it moved the problem rather than solving it, and 1.2c is
 * where the bill came in.
 *
 * A COMPOSITION ROOT REFERENCES EVERY POOL, so whatever translation unit holds
 * it drags the whole VFS into anything that includes that unit -- whether or
 * not the including code ever calls it, because a linker resolves SYMBOLS and
 * not call graphs.  Five fcc fixtures include vfs_cache.c for the name cache
 * and none of them calls vfs_init; when this chain grew a fourth link (finit),
 * all five stopped linking, and vreclaim -- which was already close to the
 * 64 KB segment ceiling -- went over it once the file table was pulled in to
 * satisfy a symbol it never calls.
 *
 * So the root lives alone.  Adding a fifth pool now touches this file and the
 * generator, and nothing that merely uses a pool.
 */

#include "fsparam.h"

/* ALL FOUR RETURN A POINTER -- the end of their own carve -- so all four
 * declarations must say so.  Defaulted to int, the bank byte of the address
 * being handed to the next link would be dropped on the way: the arena is in
 * a different bank from this code by design. */
extern char *vntblinit();       /* the vnode and specinfo pools, vfs_subr.c */
extern char *ndinit();          /* the nameidata slots, vfs_subr.c (1.2b) */


/* vfs_init -- bring the VFS's in-core state up.
 *
 * The buffer arena is NOT here, and that is not an oversight: it is 16 KB of
 * heap the core kernel allocates and hands down, so bufinit takes an argument
 * and keeps its own entry point.
 *
 * arena: VFS_POOL_BYTES of heap, sized by tools/gen_vfs_equ.py for the
 * assembly that allocates it.  THE CARVE ORDER HERE IS THAT GENERATOR'S ORDER
 * -- vnode pool and specinfo pool, then the name cache, then the per-process
 * nameidata slots and their pathname buffers (UFS 1.2b), then the open-file
 * table and the per-process descriptor arrays (UFS 1.2c).
 *
 * THE POOLS ARE CHAINED rather than each given a computed offset: vntblinit
 * returns the first byte after its own carve, so there is exactly ONE place
 * that knows how big a vnode pool is.  A second copy of that arithmetic here
 * would be a number that can disagree with the generator's, and the symptom of
 * disagreeing is the last pool running off the end of the allocation -- heap
 * corruption a long way from the edit that caused it.
 *
 * READ THE NESTING OUTWARD-IN: vntblinit carves first and ndinit carves last,
 * so ndinit is the pool that overruns the allocation if the generator's sum is
 * short.  That is why tools/gen_vfs_equ.py's nameidata term is the one whose
 * literals are spelled out in its self-test.
 */
void vfs_init(arena)
char *arena;
{
    /* TWO LINKS.  The chain has lost one at each end for the same kind of
     * reason -- the pool belongs to the bank that USES it, not to whichever
     * composition root happened to reach it first.
     *
     * finit went at UFS 1.7d I2b: Mod_LoadConf opens files through _Fcb_Alloc
     * and Mod_LoadConf is what LOADS this module, so a file table carved here
     * would not exist yet the first time something opened a file.  The far
     * kernel bank owns it now and carves it from its own static, well before
     * any module loads.  See src/kernel/far/vfs_seam_entry.s.
     *
     * nchinit went with the name cache to ufsdir.mod, beside ufs_lookup.c --
     * its only caller, and the reason the cache could be wired at all.  A
     * carve cannot be split across banks, so ufsdir carves its own from its
     * own Kmalloc at mod_init rather than taking a pointer into this arena. */
    ndinit(vntblinit(arena));
}
