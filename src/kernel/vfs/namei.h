/* namei.h -- the name cache, and the state a path walk carries.
 *
 * From 4.3BSD-Reno sys/namei.h.  This slice (1.6a) brings the CACHE; the walk
 * itself -- namei and lookup -- is 1.6b, and `struct nameidata` is declared
 * here now because the cache is written in terms of it, exactly as Reno writes
 * it.  The fields 1.6b adds are named in the comment below rather than left to
 * be discovered.
 *
 * WHAT THE CACHE IS FOR, and why it is not an optimisation.  Resolving
 * /usr/src/sys/kern/vfs_cache.c means five directory lookups, and a directory
 * lookup is a linear scan of directory blocks -- disk reads on a machine whose
 * disk is a 7 MHz SmartPort PIO transfer.  Without the cache the same five
 * scans happen for every path, forever.  BSD has had it since 4.2 for that
 * reason.
 *
 * THE HARD PART IS NOT LOOKUP, IT IS STALENESS.  A cache entry names a vnode
 * that can be recycled underneath it: the file is deleted, the vnode goes back
 * to the pool, and the next getnewvnode hands the same slot to a different
 * file.  A cache that compared pointers would then answer with the WRONG FILE
 * -- silently, and with no I/O error to notice.
 *
 * v_id is the answer, and it is why vnode.h keeps that field 32 bits wide
 * against every other narrowing in this campaign.  Every vnode handout mints a
 * fresh capability number; a cache entry records the number it saw; a hit is
 * only a hit if the number still matches.  Recycling a vnode invalidates every
 * cached name for it without the cache being told, and without walking
 * anything.
 */
#ifndef _NAMEI_H_
#define _NAMEI_H_

#include "fsparam.h"
#include "uio.h"          /* UIO_USERSPACE/UIO_SYSSPACE, which used to be here */
#include "dir.h"          /* 1.12c: ni_dent is an on-disk directory entry */

/* nameiop -- what the caller intends to DO with what it finds.  The last
 * component is treated differently for each: CREATE and RENAME want the parent
 * directory and a failed lookup is not an error, DELETE wants the entry gone
 * from the cache rather than kept. */
#define LOOKUP          0       /* perform name lookup only */
#define CREATE          1       /* setup for file creation */
#define DELETE          2       /* setup for file deletion */
#define RENAME          3       /* setup for file renaming */
#define OPMASK          3       /* mask for operation */

/* nameiop flags, Reno's values including the gaps. */
#define LOCKLEAF        0x004   /* lock leaf vnode on return */
#define LOCKPARENT      0x008   /* want parent vnode returned locked */
#define WANTPARENT      0x010   /* want parent vnode returned unlocked */
#define NOCACHE         0x020   /* name must not be left in cache */
#define FOLLOW          0x040   /* follow symbolic links */
#define NOFOLLOW        0x000   /* do not follow symbolic links (pseudo) */
#define NOCROSSMOUNT    0x080   /* do not cross mount points */
#define REMOTE          0x100   /* lookup for remote filesystem servers */
#define HASBUF          0x200   /* has preallocated pathname buffer */

/* enum uio_seg -- WHERE a pathname pointer points -- LIVES IN uio.h NOW.
 * 1.6a parked UIO_USERSPACE and UIO_SYSSPACE here so ni_segflg could mean
 * something before struct uio existed, and said they would move when it
 * arrived.  It arrived at 1.7a, so they moved rather than becoming a second
 * copy that can drift.  The ordering note went with them: USERSPACE is 0, so a
 * zeroed nameidata describes a USER pointer, which is refused rather than
 * dereferenced.
 */

/* The state a path walk carries.
 *
 * INCOMPLETE ON PURPOSE, and the missing fields are named so the gap is a fact
 * rather than a surprise:
 *
 *   ni_cred    Reno's `struct ucred *`, and permanently null: this kernel
 *              follows 2.11BSD, which has no ucred and reads the ids from the
 *              u-area -- file.h's f_cred note is the canonical statement.
 *              Declared as char * so the field and its position are real, the
 *              same way spec_open takes its cred argument.
 *   ni_dent    Reno's `struct direct` -- the final component's directory
 *              entry, which needs the on-disk directory format (1.10).
 *   ni_nd      Reno's UFS-specific `ndirinfo`: a struct uio and iovec
 *              remembering where a new entry would be written.  uio arrives
 *              with the syscall layer at 1.7 and this is only read by the
 *              write path at 1.12.
 *
 * Everything the CACHE reads is here, which is what 1.6a needs.
 *
 * WHEN ni_dent AND ni_nd LAND, ZEROING THE SLOT IS NOT ENOUGH -- read this
 * before adding them.  ndslot clears the whole struct on hand-out, which is
 * exactly what Reno's ndinit does FIRST (vfs_subr.c:160: `bzero(ndp,
 * sizeof *ndp)`).  But ndinit then sets FIVE fields, and three of them to
 * NONZERO values:
 *
 *      ndp->ni_iov     = &ndp->ni_nd.nd_iovec;   SELF-POINTER
 *      ndp->ni_iovcnt  = 1;
 *      ndp->ni_base    = (caddr_t)&ndp->ni_dent; SELF-POINTER
 *      ndp->ni_rw      = UIO_WRITE;
 *      ndp->ni_uioseg  = UIO_SYSSPACE;
 *
 * For two of those, ZERO IS NOT A SAFE DEFAULT -- it is a MEANINGFUL AND
 * OPPOSITE value.  Reno's enums (sys/uio.h:31,36) put UIO_READ at 0 and
 * UIO_USERSPACE at 0, so a zeroed slot describes a READ from USER SPACE where
 * the directory-entry write path needs a WRITE from SYSTEM space.  ni_iovcnt
 * of 0 means "no iovecs", i.e. a transfer of nothing.
 *
 * ufs_direnter is the consumer (Reno's ufs/ufs_lookup.c reads ni_offset,
 * ni_count, ni_endoff and ni_dent throughout).  BE PRECISE ABOUT WHAT EACH
 * WRONG VALUE DOES, because they differ: a zeroed ni_rw is caught loudly --
 * `panic("ufs_write mode")` at ufs_vnops.c:673 -- while a zeroed ni_uioseg is
 * NOT checked anywhere and would have the transfer read its bytes from user
 * space.  One announces itself, the other does not.
 *
 * The two SELF-POINTERS also have to be re-established on every hand-out, not
 * seeded once: ndslot clears the struct each time, so they are in exactly the
 * position ni_pnbuf is, and take the same treatment -- DERIVE, do not
 * preserve.  See the note on ndslot in vfs_subr.c for why that rule exists.
 *
 * ---------------------------------------------------------------------------
 * TWO CONSEQUENCES OF CLEAR-ON-HAND-OUT THAT THE PORTS MUST RESPECT.
 *
 * 1. ni_cdir AND ni_rdir CANNOT LIVE IN THE SLOT.  In Reno the nameidata IS
 *    the u-area's, so it persists, and chdir/chroot write the process's
 *    current and root directory straight into it and leave them there
 *    (vfs_syscalls.c:458, 482).  A slot that is wiped on every hand-out cannot
 *    hold that: the cwd would survive exactly until the next path resolution.
 *    FGX's cwd therefore belongs in the u-area proper -- which is also what
 *    the campaign already decided ("cwd IS a held vnode", a v_usecount
 *    reference) -- and the walk COPIES it into the slot on the way in, as
 *    namei's callers already do.
 *
 * 2. rename(2) MUST OBTAIN SLOT 0 EXACTLY ONCE.  Its from-walk leaves commit
 *    state in the slot that has to survive the whole to-walk
 *    (vfs_syscalls.c:1419-1440).  namei_probe's walk() helper re-obtains its
 *    slot on EVERY call, which is right for a probe driving independent walks
 *    and WRONG as a model for rename -- copying that idiom would zero the
 *    from-walk's state before VOP_RENAME ever saw it. */
struct nameidata {
    /* arguments to namei, and the context it runs in */
    char           *ni_dirp;        /* pathname pointer */
    int             ni_segflg;      /* enum uio_seg: where ni_dirp points */
    short           ni_nameiop;     /* op | flags, above */
    struct vnode   *ni_cdir;        /* current directory */
    struct vnode   *ni_rdir;        /* root directory, if not the normal root */
    char           *ni_cred;        /* Reno: struct ucred * */

    /* shared between namei, the lookup routines and the commit routines */
    char           *ni_pnbuf;       /* pathname buffer */
    /* THE SECOND BUFFER, AND SYMLINKS ARE WHY.  Reno's expansion needs TWO
     * MAXPATHLEN buffers live at once whenever path remains after the link: it
     * reads the target into a fresh one, copies the un-walked remainder in
     * behind it, and only then swaps (vfs_lookup.c:287-321).  Reno mallocs the
     * second per call; a slot here owns both and namei swaps ni_pnbuf and
     * ni_pnalt between them, which fsparam.h costed at +MAXPATHLEN per slot
     * against a per-call allocator's free-list walk and its ENOMEM path.
     * Both are DERIVED by ndslot on every hand-out -- see vfs_subr.c. */
    char           *ni_pnalt;       /* the other one */
    char           *ni_ptr;         /* current location in the pathname */
    char           *ni_next;        /* next location in the pathname */
    unsigned short  ni_pathlen;     /* remaining chars in the path */
    /* THE HASH STAYS 32 BITS.  It is not a table index -- the index is
     * (ni_hash & nchash) -- it is the discriminator that keeps a bucket walk
     * from comparing every name in the bucket byte by byte.  Narrowed to 16
     * it would still WORK and would simply collide more, which is the kind of
     * regression that shows up as the machine feeling slow. */
    unsigned long   ni_hash;        /* hash of the current component */
    short           ni_namelen;     /* length of the current component */
    short           ni_loopcnt;     /* symlinks encountered so far */
    char            ni_makeentry;   /* 1 => add this entry to the cache */
    char            ni_isdotdot;    /* 1 => the component is ".." */

    /* results */
    struct vnode   *ni_vp;          /* the vnode found */
    struct vnode   *ni_dvp;         /* the directory it was found in */

    /* WHERE THE ENTRY IS, OR WHERE ONE WOULD GO.  UFS 1.12c, and these are
     * what turn a lookup that FOUND something into a lookup something can act
     * on.  ufs_lookup fills them for CREATE, DELETE and RENAME on the last
     * component; direnter, dirremove and dirrewrite read them and never scan
     * the directory again.  Reno keeps them in the INODE (i_offset, i_count,
     * i_endoff) because its nameidata is the u-area's and one inode is locked
     * across the pair; this port keeps them in the nameidata, where the rest
     * of the walk's state already lives and where a per-process slot bounds
     * their lifetime to the walk that produced them.
     *
     * ni_count IS TWO DIFFERENT THINGS depending on the operation, and reading
     * it as one is the way to corrupt a directory.  On a CREATE it is the SIZE
     * of the space at ni_offset that the new entry may use, and ZERO means "no
     * space was found, put it at the end".  On a DELETE it is the DISTANCE
     * BACK to the previous entry in the same block, and ZERO means "this is
     * the first entry in its block, so just clear d_ino".  Upstream overloads
     * the field the same way and says so in dirremove's header. */
    off_t           ni_offset;      /* where the entry is, or goes */
    int             ni_count;       /* see above -- MEANS TWO THINGS */
    off_t           ni_endoff;      /* end of useful directory contents */

    /* THE ENTRY ITSELF, and the uio that writes it.  Reno calls the second
     * one `ndirinfo` and reaches it as ni_nd; the accessors below are its
     * ni_uio, ni_base, ni_iov and so on, which is how upstream's direnter
     * spells the same thing.
     *
     * EVERY ONE OF THESE IS RE-ESTABLISHED BY ndslot ON HAND-OUT, NOT SEEDED
     * ONCE -- two are SELF-POINTERS into this struct and would name the
     * previous holder's copy, and two more have a zero value that is
     * MEANINGFUL AND WRONG (a zeroed ni_uioseg is UIO_USERSPACE, which is not
     * checked anywhere and would take the bytes from user space).  The note
     * above this struct is the long version and was written at 1.6a for this
     * moment. */
    struct direct   ni_dent;        /* the final component's entry */
    struct iovec    ni_iovec;       /* Reno: ni_nd.nd_iovec */
    struct uio      ni_uio;         /* Reno: ni_nd.nd_uio */
};

/* A cached name.
 *
 * nc_forw and nc_back MUST BE FIRST, and that is load-bearing rather than
 * decorative: a hash bucket is a `struct nchash` -- two pointers, not a whole
 * 64-byte entry -- and the chain walk casts the bucket to a namecache so the
 * bucket itself acts as the list's sentinel.  Reno spells this as a union;
 * the cast is the same trick with the same requirement.  toolchain/tests/M37/
 * namecache.c asserts the two layouts still agree.
 *
 * NCHNAMLEN IS DELIBERATELY SHORTER THAN A FILENAME.  The filesystem allows 63
 * (fgxfs.py's MAXNAMLEN, measured on the 2.11BSD volume); this caches 31.
 * Longer names are not cached at all -- Reno's choice, and the reasoning holds
 * here more strongly than there: a name field long enough for the worst case
 * would double the entry and spend a bank on storage for the rare case.  The
 * skipped lookups are COUNTED (ncs_long) rather than silently absorbed, so
 * "the cache is not helping" is a number somebody can read. */
#define NCHNAMLEN       31      /* longest name segment worth caching */

struct namecache {
    struct namecache  *nc_forw;     /* hash chain, MUST BE FIRST */
    struct namecache  *nc_back;     /* hash chain, MUST BE FIRST */
    struct namecache  *nc_nxt;      /* LRU chain forward */
    struct namecache **nc_prev;     /* LRU chain back */
    struct vnode      *nc_dvp;      /* the directory the name is in */
    unsigned long      nc_dvpid;    /* capability number of nc_dvp */
    struct vnode      *nc_vp;       /* the vnode the name refers to */
    unsigned long      nc_vpid;     /* capability number of nc_vp */
    char               nc_nlen;     /* length of the name */
    char               nc_name[NCHNAMLEN];
};

/* A hash bucket: the first two fields of a namecache and nothing else.  Reno
 * gets this from a union; fcc is K&R and a cast is clearer than a union whose
 * only purpose is the aliasing. */
struct nchash {
    struct namecache *nch_forw;
    struct namecache *nch_back;
};

/* Cache effectiveness, Reno's counters.  These are the only way to tell a
 * cache that is working from one that is merely present -- a lookup path with
 * a broken cache is CORRECT and slow, which no functional test detects.
 *
 * ncs_falsehits is the one to watch: it counts entries whose vnode was
 * recycled underneath them, which is the staleness the capability number
 * exists to catch.  A build where it is always zero and ncs_goodhits is huge
 * is not necessarily healthy -- it may mean v_id is not being minted. */
struct nchstats {
    long ncs_goodhits;      /* hits we can really use */
    long ncs_neghits;       /* negative hits we can use */
    long ncs_badhits;       /* hits we must drop */
    long ncs_falsehits;     /* hits whose capability number had moved */
    long ncs_miss;          /* misses */
    long ncs_long;          /* names too long to bother caching */
    long ncs_pass2;         /* names found with passes == 2 */
    long ncs_2passes;       /* number of times we attempt it */
};

/* THE TWO ENTRIES THAT CROSS A BANK, and the reason there is a table for two
 * functions rather than two pointers.
 *
 * The name cache lives in ufsdir.mod, beside the ufs_lookup.c that is its only
 * hot-path caller.  vfs.mod still owns the two RARE reasons to disturb it --
 * getnewvnode mints a capability number on every vnode handout, and unmount
 * drops a whole filesystem's entries -- so those two calls run the other way,
 * out of vfs.mod and into ufsdir's bank.
 *
 * A cross-bank call needs the callee's BANK, and the one mechanism in this
 * tree that carries one is an &function cell in a static table: fcc emits
 * MOD_FN_PTR for it and _Mod_StampFnPtrs fills the bank byte at load time,
 * which is exactly how a VOP_ dispatch reaches this module at all
 * (apple/fgx#178).  So the pair travels as a TABLE, handed over once by
 * ufs_dirinit, and vfs_subr.c dispatches through it the way vnode operations
 * are dispatched through v_op.  Two loose pointers would each need the same
 * treatment and would not be able to share the handover.
 */
struct cacheops {
    void (*co_purge)();         /* cache_purge(vp) -- mint a new v_id */
    void (*co_purgevfs)();      /* cache_purgevfs(mp) -- drop one mount's */
};

#endif /* _NAMEI_H_ */
