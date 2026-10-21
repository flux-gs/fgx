/* vnode.h -- the FGX vnode, from 4.3BSD-Reno, sized for a 65816.
 *
 * Reno's struct vnode is written for a VAX with 32-bit ints, 32-bit pointers
 * and a virtual-memory system.  Imported straight it would be ~300 bytes on a
 * machine whose entire kernel bank is 57,968.  Every Reno FIELD is kept -- the
 * governing principle of this campaign is to hold the BSD shape so future
 * imports compile -- but the ones the machine bounds are narrowed.
 *
 * Sizes and offsets are pinned by toolchain/tests/M37/vfslayout.c, which
 * INCLUDES this header.  That is deliberate: a conformance fixture that
 * redeclared these structures would be a second source of truth, and the two
 * would drift the first time someone edited one of them.
 */
#ifndef _VNODE_H_
#define _VNODE_H_

#include "fsparam.h"

/* The private area a vnode lends to its filesystem.  Asserted by the fixture
 * to be large enough for the UFS in-core inode, which is the only client that
 * matters until a second filesystem type exists.
 *
 * THE LOAD-BEARING ASSERTION IS NOT A SIZE, IT IS A RELATIONSHIP:
 *     sizeof(struct inode) <= VN_MAXPRIVATE
 * Pinning this to a number chosen up front would pass forever and prove
 * nothing; asserting that the private area still FITS the thing it exists to
 * hold goes red the day someone adds an inode field. */
#define VN_MAXPRIVATE   104

/* enum vtype.  #defines rather than an enum because fcc is K&R and the rest of
 * this header already declares the fields as int with the enum named in a
 * comment; introducing one enum here would make the file inconsistent with
 * itself.  Reno's order is kept -- VBAD last -- so a value read from a Reno
 * listing means the same thing. */
#define VNON            0
#define VREG            1
#define VDIR            2
#define VBLK            3
#define VCHR            4
#define VLNK            5
#define VSOCK           6
#define VFIFO           7
#define VBAD            8

/* ACCESS MODES for VOP_ACCESS, from Reno's sys/vnode.h:226-228 verbatim.  They
 * are the OWNER permission bits of a mode word, which is what makes ufs_access
 * able to shift them right by 3 for group and 6 for other. */
#define VREAD           0400
#define VWRITE          0200
#define VEXEC           0100

/* THE SET-ID BITS, from Reno's sys/vnode.h:223-225 verbatim.  exec(2) reads
 * them off va_mode to decide whose credentials the new image runs with;
 * VSVTX is here for the numbering's sake and has no reader. */
#define VSUID           04000
#define VSGID           02000
#define VSVTX           01000

/* access(2)'s OWN bits, which are NOT these.  The caller names R_OK/W_OK/X_OK
 * and the filesystem is asked in VREAD/VWRITE/VEXEC; vfs_access is where the
 * two meet.  Values agree with toolchain/include/unistd.h:25-28, which is the
 * copy userland compiles against -- the same rule fsparam.h's errnos follow.
 * F_OK is 0 and means "exists", which is why it needs no V-bit. */
#define F_OK            0
#define X_OK            1
#define W_OK            2
#define R_OK            4

/* enum vtagtype.  Which FILESYSTEM owns v_data -- a debugging aid in Reno and
 * a real discriminator here, since specfs vnodes (1.5) share the pool with UFS
 * ones and their private areas are not interchangeable. */
#define VT_NON          0
#define VT_UFS          1
#define VT_SPEC         2
#define VT_PRODOS       3       /* FGX-local: no BSD has a ProDOS tag */
#define VT_ISOFS        4       /* netbsd-0-9's isofs; FGX-local number */

/* v_flag bits.
 *
 * VXLOCK and VXWANT are the teardown pair: vclean sets VXLOCK while it tears a
 * vnode away from its filesystem, and anyone who finds it set sets VXWANT and
 * sleeps.  Both are declared here at 1.4a although only vget reads VXLOCK so
 * far -- slice b's vclean is what sets them.  Declaring the contract up front
 * means callers are written against it instead of audited for it later.
 *
 * VALIASED marks a device vnode that shares its (major, minor) with another --
 * two paths to the same device node, which specfs has to keep coherent.
 *
 * VEXLOCK, VSHLOCK and VLWAIT are flock(2)'s: the vnode carries an exclusive
 * lock, or shared ones (v_exlockc, v_shlockc count them), and VLWAIT says
 * someone is asleep waiting for one to go (vn_lock, vfs_vnops.c).
 *
 * THE VALUES ARE RENO'S, INCLUDING THE GAPS.  Unused slots are left empty
 * rather than closed up: a flag word read out of a Reno listing, or lifted
 * from a later import, has to mean the same thing here.  VALIASED sat at
 * 0x0400 until VBWAIT arrived and showed the collision -- Reno's VALIASED is
 * 0x0800 and always was. */
#define VROOT           0x0001  /* root of its filesystem */
#define VTEXT           0x0002  /* vnode is a pure text prototype */
#define VSYSTEM         0x0004  /* in use by the kernel; unmount skips it */
#define VEXLOCK         0x0010  /* exclusive lock */
#define VSHLOCK         0x0020  /* shared lock */
#define VLWAIT          0x0040  /* proc is waiting on shared or excl. lock */
#define VXLOCK          0x0100  /* vnode is being torn down */
#define VXWANT          0x0200  /* someone is waiting for VXLOCK to clear */
#define VBWAIT          0x0400  /* waiting for output to complete */
#define VALIASED        0x0800  /* vnode has an alias */

/* The operations vector -- Reno's, all 32 slots, in Reno's order.
 *
 * EVERY SLOT IS KEPT, including the ones this machine can never implement.
 * vn_mmap has no meaning without a VM system and vn_select none without
 * pollable vnodes, but the slots stay because the ORDER is the interface: a
 * filesystem's ops table lifted from a BSD listing initialises positionally,
 * and a vector with a slot removed silently shifts every entry after it.  A
 * slot with no implementation costs four bytes and points at dead_badop.
 *
 * Reno writes the members as `int (*vn_x)(/-- args --/)` -- K&R, no parameter
 * types -- and so does this.  It is not laziness in either place: the
 * arguments differ per operation, and one of the types named in them (ucred)
 * does not exist here at all -- 2.11BSD has none either and this kernel takes
 * its model (file.h) -- so an empty list is the only honest declaration.
 *
 * 32 slots at 4 bytes per far function pointer is 128 bytes per vector, and
 * there are only a handful of vectors (one per filesystem type plus
 * dead_vnodeops), so the table is not a budget item.  The SHAPE is already
 * proven on the 65816 by toolchain/tests/M18/fnptr_vnodeops, which exists
 * because two recorded fcc defect families live exactly here: far function
 * pointers in a DATA INITIALIZER, and struct fn-ptr field offset drift past
 * 120 bytes. */
struct vnodeops {
    int (*vn_lookup)();         /* ndp */
    int (*vn_create)();         /* ndp, vap */
    int (*vn_mknod)();          /* ndp, vap, cred */
    int (*vn_open)();           /* vp, fflags, cred */
    int (*vn_close)();          /* vp, fflags, cred */
    int (*vn_access)();         /* vp, fflags, cred */
    int (*vn_getattr)();        /* vp, vap, cred */
    int (*vn_setattr)();        /* vp, vap, cred */

    int (*vn_read)();           /* vp, uiop, ioflag, cred */
    int (*vn_write)();          /* vp, uiop, ioflag, cred */
    int (*vn_ioctl)();          /* vp, com, data, fflag, cred */
    int (*vn_select)();         /* vp, which, fflags, cred */
    int (*vn_mmap)();           /* vp, cred */
    int (*vn_fsync)();          /* vp, fflags, cred, waitfor */
    int (*vn_seek)();           /* vp, oldoff, newoff, cred */

    int (*vn_remove)();         /* ndp */
    int (*vn_link)();           /* vp, ndp */
    int (*vn_rename)();         /* sndp, tndp */
    int (*vn_mkdir)();          /* ndp, vap */
    int (*vn_rmdir)();          /* ndp */
    int (*vn_symlink)();        /* ndp, vap, target */
    int (*vn_readdir)();        /* vp, uiop, cred, eofflagp */
    int (*vn_readlink)();       /* vp, uiop, cred */

    int (*vn_abortop)();        /* ndp */
    int (*vn_inactive)();       /* vp */
    int (*vn_reclaim)();        /* vp */
    int (*vn_lock)();           /* vp */
    int (*vn_unlock)();         /* vp */

    int (*vn_bmap)();           /* vp, bn, vpp, bnp */
    int (*vn_strategy)();       /* bp */

    int (*vn_print)();          /* vp */
    int (*vn_islocked)();       /* vp */
};

/* The VOP_ dispatch macros.
 *
 * VOP_LOOKUP ARRIVED WITH 1.6b and is below with the rest.  It takes the
 * DIRECTORY VNODE FIRST and the nameidata second -- `(*(dvp->v_op->vn_lookup))
 * (dvp, ndp)` -- which is Reno's signature and the one spec_lookup(vp, ndp)
 * was already written to.  The slot comment above says `/* ndp *\/` and is
 * shorthand; the vnode is not optional, because a filesystem's lookup needs
 * the directory it is searching and nameidata does not carry it on the way IN
 * (ni_dvp is a RESULT).
 *
 * Reno's nameidata-taking macros arrive WITH THEIR CALLERS, which is why they
 * did not exist before 1.12: a macro nobody uses is a macro nobody has
 * checked.  CREATE and REMOVE came at 1.12c-a, LINK, MKDIR, RMDIR and SYMLINK
 * at 1.12c-b, RENAME at 1.12c-c.  VOP_ABORTOP is still absent for the
 * original reason.  The SLOTS above have all been present throughout, so nothing about
 * the vector's layout ever waited on this. */
#define VOP_OPEN(v,f,c)     (*((v)->v_op->vn_open))((v),(f),(c))
#define VOP_CLOSE(v,f,c)    (*((v)->v_op->vn_close))((v),(f),(c))
#define VOP_ACCESS(v,f,c)   (*((v)->v_op->vn_access))((v),(f),(c))
#define VOP_GETATTR(v,a,c)  (*((v)->v_op->vn_getattr))((v),(a),(c))
#define VOP_SETATTR(v,a,c)  (*((v)->v_op->vn_setattr))((v),(a),(c))
#define VOP_READ(v,u,i,c)   (*((v)->v_op->vn_read))((v),(u),(i),(c))
#define VOP_WRITE(v,u,i,c)  (*((v)->v_op->vn_write))((v),(u),(i),(c))
#define VOP_IOCTL(v,o,d,f,c) (*((v)->v_op->vn_ioctl))((v),(o),(d),(f),(c))
#define VOP_SELECT(v,w,f,c) (*((v)->v_op->vn_select))((v),(w),(f),(c))
#define VOP_MMAP(v,c)       (*((v)->v_op->vn_mmap))((v),(c))
#define VOP_FSYNC(v,f,c,w)  (*((v)->v_op->vn_fsync))((v),(f),(c),(w))
#define VOP_SEEK(v,p,o,c)   (*((v)->v_op->vn_seek))((v),(p),(o),(c))
#define VOP_READDIR(v,u,c,e) (*((v)->v_op->vn_readdir))((v),(u),(c),(e))
#define VOP_READLINK(v,u,c) (*((v)->v_op->vn_readlink))((v),(u),(c))
#define VOP_INACTIVE(v)     (*((v)->v_op->vn_inactive))(v)
#define VOP_RECLAIM(v)      (*((v)->v_op->vn_reclaim))(v)
#define VOP_LOCK(v)         (*((v)->v_op->vn_lock))(v)
#define VOP_UNLOCK(v)       (*((v)->v_op->vn_unlock))(v)
#define VOP_BMAP(v,s,p,n)   (*((v)->v_op->vn_bmap))((v),(s),(p),(n))
#define VOP_STRATEGY(b)     (*((b)->b_vp->v_op->vn_strategy))(b)
#define VOP_PRINT(v)        (*((v)->v_op->vn_print))(v)
#define VOP_ISLOCKED(v)     (*((v)->v_op->vn_islocked))(v)
/* Directory first, nameidata second -- see the note above.  The filesystem
 * reads ni_ptr/ni_namelen/ni_nameiop out of the nameidata and writes ni_vp. */
#define VOP_LOOKUP(d,n)     (*((d)->v_op->vn_lookup))((d),(n))
/* ...AND THESE TWO TAKE NO VNODE AT ALL, which is upstream's shape rather than
 * an omission: a create is dispatched on the DIRECTORY the name goes into and a
 * remove on the vnode being unlinked, and the nameidata is already carrying
 * both.  Reno spells them the same way.  UFS 1.12c-a. */
#define VOP_CREATE(n,a)     (*((n)->ni_dvp->v_op->vn_create))((n),(a))
/* THROUGH ni_dvp, like create and mkdir: mknod makes a NEW name, so there is
 * no ni_vp to dispatch on -- the directory is what has a filesystem.  UFS
 * 1.13a. */
#define VOP_MKNOD(n,a)      (*((n)->ni_dvp->v_op->vn_mknod))((n),(a))
/* THROUGH ni_dvp, ALL THREE OF THEM, AND TWO OF THEM WERE NOT (UFS 1.13a).
 *
 * Removing a name, renaming one and adding one are the DIRECTORY's operations:
 * they change directory entries, and the only vnode that knows what a
 * directory entry is is the directory's.  The leaf is whatever the name
 * happens to point at, and from 1.13a it can be a DEVICE FILE, whose vector is
 * spec_inodeops -- which answers remove, link and rmdir with spec_badop,
 * because upstream never reaches those slots.  That is not an omission in
 * spec_inodeops; it is the consequence of dispatching correctly.
 *
 * VOP_REMOVE and VOP_RMDIR dispatched on ni_vp here, and VOP_LINK on the
 * source vnode, and all three were right by accident for as long as every
 * leaf was an ordinary UFS file.  The first `rm` of a device file panicked in
 * spec_badop and that is how they were found.  4.3BSD-Reno sys/vnode.h:158-163
 * has all three on ni_dvp; so does VOP_RENAME, which this tree already had
 * right. */
#define VOP_REMOVE(n)       (*((n)->ni_dvp->v_op->vn_remove))(n)
/* UFS 1.12c-b.  LINK IS THE ODD ONE: it takes the vnode being linked TO as
 * well as the nameidata, because the nameidata's ni_vp is empty on a create
 * and the operation needs to be told which inode gains the name.  mkdir and
 * symlink dispatch on the directory; rmdir on the directory being removed. */
#define VOP_LINK(v,n)       (*((n)->ni_dvp->v_op->vn_link))((v),(n))
#define VOP_MKDIR(n,a)      (*((n)->ni_dvp->v_op->vn_mkdir))((n),(a))
#define VOP_RMDIR(n)        (*((n)->ni_dvp->v_op->vn_rmdir))(n)
#define VOP_SYMLINK(n,a,t)  (*((n)->ni_dvp->v_op->vn_symlink))((n),(a),(t))
/* UFS 1.12c-c.  RENAME TAKES TWO NAMEIDATA and dispatches on the SOURCE's
 * directory: the source is the inode that moves, and both walks are of one
 * filesystem -- upstream's namei can cross a mount point and refuses that
 * itself, well above this vector. */
#define VOP_RENAME(f,t)     (*((f)->ni_dvp->v_op->vn_rename))((f),(t))

/* Flags to vflush and vclean, Reno's values.
 *
 * DOCLOSE is the one that matters, and it is why these are flags rather than a
 * boolean: vclean(vp, DOCLOSE) means "this file is going away, write its data
 * out and close it", while vclean(vp, 0) means "detach the vnode but leave the
 * file alone", which is what a forced unmount does to a device so the device
 * keeps working under a different vector. */
/* ioflag -- the third argument to VOP_READ and VOP_WRITE.  4.3BSD-Reno
 * sys/vnode.h:179-183, and the values are Reno's exactly.  UFS 1.12a.
 *
 * ufs_read has taken an `ioflag` since 1.11b and IGNORED it, because until
 * there was a write path none of these meant anything: Reno's read consults
 * only IO_NDELAY, which needs a syscall layer that can set FNDELAY.  1.12a
 * gives IO_APPEND and IO_SYNC their first reader in ufs_write.
 *
 * IO_UNIT and IO_NODELOCKED ARE CARRIED WITHOUT A READER, deliberately: they
 * are Reno's numbers, and defining three of five would leave the other two to
 * be invented later against whatever was free.  IO_UNIT's consumer is itrunc
 * (1.12b), which rolls a failed write back; IO_NODELOCKED's is the inode lock,
 * which this port does not have yet.
 */
#define IO_UNIT         0x01    /* do I/O as an atomic unit */
#define IO_APPEND       0x02    /* append write to end */
#define IO_SYNC         0x04    /* do I/O synchronously */
#define IO_NODELOCKED   0x08    /* underlying node already locked */
#define IO_NDELAY       0x10    /* FNDELAY flag set in file table */

#define SKIPSYSTEM      0x0001  /* vflush: skip vnodes marked VSYSTEM */
#define FORCECLOSE      0x0002  /* vflush: close files rather than fail busy */
#define DOCLOSE         0x0004  /* vclean: this file is going away */

struct vnode {
    unsigned short  v_flag;         /* vnode flags (Reno: u_long) */
    short           v_usecount;     /* reference count of users */
    short           v_holdcnt;      /* buffer references */
    unsigned short  v_shlockc;      /* count of shared locks */
    unsigned short  v_exlockc;      /* count of exclusive locks */
    off_t           v_lastr;        /* last read (read-ahead) */
    /* v_id stays 32-bit ON PURPOSE.  It is the capability identifier the name
     * cache uses to notice a vnode was recycled underneath a cached entry;
     * narrowing it to 16 bits would make that wrap after 65536 reuses and turn
     * a correctness check into a probabilistic one.  Two bytes per vnode is
     * the wrong place to economise. */
    unsigned long   v_id;
    struct mount   *v_mount;
    struct vnodeops *v_op;
    struct vnode   *v_freef;        /* vnode freelist forward */
    struct vnode  **v_freeb;        /* vnode freelist back */
    struct vnode   *v_mountf;       /* mountlist forward */
    struct vnode  **v_mountb;       /* mountlist back */
    struct buf     *v_cleanblkhd;   /* clean blocklist head */
    struct buf     *v_dirtyblkhd;   /* dirty blocklist head */
    short           v_numoutput;    /* writes in progress */
    int             v_type;         /* enum vtype */
    /* Reno's `v_un` union: the mounted-on mount for a covered directory, the
     * socket for a VSOCK, the specinfo for a VBLK or VCHR.  Declared here as
     * the SPECINFO arm rather than as a union or a `char *`, because
     * specdev.h's shorthand (`vp->v_rdev` -> `vp->v_un->si_rdev`) expands to
     * a member chain and a macro cannot insert a cast after `vp->`.  The
     * MOUNTEDHERE ARRIVED AT 1.8b-2 AND CASTS, exactly as this note said it
     * would.  vfs_syscalls.c:vfs_mountat writes `(struct specinfo *)mp' and
     * tests the word against null to mean "nothing is mounted here"; those
     * are the only two sites, and the cast is at both.  Nothing was added to
     * this structure for it, because Reno's v_mountedhere is an ARM of this
     * same union and not a member of its own -- so sizeof(struct vnode) is
     * unchanged and vfslayout.c's boot assertion still holds.
     *
     * NO TWO ARMS CAN BE LIVE AT ONCE, which is what makes one word enough: a
     * covered directory is VDIR and a VDIR has no specinfo, and a VSOCK is
     * neither.  The SOCKET arm is live -- an AF_UNIX socket bound by unp_bind
     * keeps its descriptor index here, cast the way vfs_mountat casts for
     * mountedhere -- and it too adds nothing to this structure, so
     * sizeof(struct vnode) is still 60 + VN_MAXPRIVATE and the assertion in
     * toolchain/tests/M37/vfslayout.c (rc 23) still holds. */
    struct specinfo *v_un;          /* mountedhere / socket / specinfo */
    int             v_tag;          /* enum vtagtype */
    /* v_data is the TAIL, so a filesystem that overruns its private area runs
     * off the end of the structure rather than into another field.  That is
     * the difference between a detectable overrun and silent corruption of
     * v_tag, and it is why this is declared last. */
    char            v_data[VN_MAXPRIVATE];
};

/* struct vattr -- a file's attributes, in the VFS's terms rather than any one
 * filesystem's.  4.3BSD-Reno sys/vnode.h:190-207.
 *
 * IT IS THE POINT OF VOP_GETATTR EXISTING AT ALL: stat(2) must answer the same
 * questions about a UFS file, a device and a pipe, and none of those three
 * stores them the same way.  ufs_getattr copies out of the in-core inode;
 * spec_getattr will answer for a device; the syscall layer above turns this
 * into `struct stat` at 1.7/1.2c and is the only place that knows that shape.
 *
 * WHAT DIVERGES FROM RENO, AND WHY EACH:
 *
 *   va_qsize/va_qbytes are Reno's 64-bit quad pairs, reached through va_size /
 *   va_size_rsv macros chosen by byte order.  This tree's off_t is 32 bits and
 *   the 2.11BSD format's ic_size is too, so the quad and its reserved half
 *   would be a 64-bit spelling of a 32-bit fact.  `va_size` is an off_t.
 *
 *   va_bytes is ABSENT rather than narrowed.  Reno computes it from
 *   i_blocks, which the 2.11BSD dinode does not carry -- there is no field to
 *   read and no honest number to report, and a zero would read as "this file
 *   occupies nothing".  Its caller is stat(2)'s st_blocks, which arrives at
 *   1.7; the choice there is to compute it from the size or to leave it out,
 *   and that is a decision for the code that has to answer it.
 *
 *   va_gen is ABSENT: 2.11BSD has no generation number.  Reno uses it for NFS
 *   file handles, which this campaign has no goal for.
 *
 *   The three times are time_t, not struct timeval.  The format stores seconds;
 *   a tv_usec here would be a field that is structurally always zero.
 *
 * VA_UNSET is Reno's -1 fill (`vattr_null` writes VNOVAL), and it is what makes
 * a partially-filled vattr detectable instead of plausible.  A filesystem sets
 * what it knows; the caller can see what it did not. */
#define VA_UNSET        (-1)

struct vattr {
    int             va_type;        /* enum vtype */
    unsigned short  va_mode;        /* access mode, WITHOUT the IFMT bits */
    short           va_nlink;
    uid_t           va_uid;
    gid_t           va_gid;
    long            va_fsid;        /* the device the file lives on */
    long            va_fileid;      /* the inode number */
    off_t           va_size;
    long            va_blocksize;   /* the preferred I/O size */
    time_t          va_atime;
    time_t          va_mtime;
    time_t          va_ctime;
    unsigned short  va_flags;       /* the on-disk user flags word */
    dev_t           va_rdev;        /* the device a special file names */
};

/* RENO'S VATTR_NULL IS NOT HERE YET, and that is a decision rather than an
 * omission.  Upstream's `*(vap) = va_null` (sys/vnode.h:265) is called by
 * SETATTR's callers -- create, mkdir, chmod -- which fill in the two or three
 * fields they mean and leave the rest VNOVAL for the filesystem to skip.  All
 * of those are the write path (1.12).  `ufs_getattr` does not call it in Reno
 * either: it assigns every field it has, which is the whole structure here.
 *
 * Adding it now would cost a cross-module shim -- vfs_subr.c is vfs.mod and
 * ufs_getattr is ufs.mod -- for a function with no caller, and an unused entry
 * in that table is exactly the kind of thing that is never checked. */

/* unp_nameop's three operations.  The assembly side spells these in
 * include/socket.s and the two must agree; there is no shared header a KSVC arm
 * and a far-bank C function can both include. */
/* UNBIND IS ZERO ON PURPOSE, and it is a byte budget that says so.  The KSVC
 * arm has to know before it copies a path whether there is a path to copy, and
 * with UNBIND at 0 that test is `LDX _unpNameOp / BEQ' -- five bytes where a
 * CPX against a non-zero value is eight.  The core kernel bank had four bytes
 * free when this landed. */
#define UNP_OP_UNBIND   0
#define UNP_OP_BIND     1
#define UNP_OP_LOOKUP   2

/* HOW MANY BOUND SOCKETS CAN HOLD A VNODE AT ONCE -- SOCKD_MAX in
 * include/socket.s, and the two must agree for the same reason the opcodes
 * above do.  A mismatch cannot corrupt anything: unp_nameop range-checks the
 * slot and answers EINVAL, so a descriptor table grown past this refuses to
 * bind its high slots rather than writing off the end.
 *
 * It is a table HERE and not a field in net.mod's socket record because a
 * vnode pointer can only be named by the bank that holds vnodes.  This IS
 * Reno's per-unpcb `unp_vnode' (kern/uipc_usrreq.c): one vnode per bound
 * socket, held for the socket's life and released when it closes. */
#define UNP_NVNODE      12

#endif /* _VNODE_H_ */
