/* inode.h -- the UFS on-disk and in-core inode.
 *
 * The on-disk half (struct dinode) is the 2.11BSD FORMAT CONTRACT, measured on
 * a live PDP-11/70 and pinned independently by toolchain/tests/M37/pdplayout.c:
 * 64 bytes, di_addr at offset 12.  Nothing here is ours to choose.
 *
 * The in-core half is Reno's shape wrapped around that body.  Dropped from
 * Reno's version, a campaign non-goal: i_dquot[MAXQUOTAS] (quotas).  Narrowed:
 * i_flag from u_long, because the flag set is under sixteen bits.  Renamed:
 * Reno's i_spare0 is i_lockholder here, because that is what it holds and
 * "spare" is what it was called before it did (ufs/ufs_inode.c's ilock is the
 * only reader).  Reno's i_spare1 -- the WAITER's pid -- is not kept: nothing
 * reads it there either.  Everything else keeps Reno's field names so ufs_*.c
 * ports read against a familiar structure.
 *
 * The whole in-core inode has to fit VN_MAXPRIVATE, since that is the area a
 * vnode lends its filesystem.  toolchain/tests/M37/vfslayout.c asserts the
 * RELATIONSHIP rather than the number, so it goes red the day a field is added
 * rather than passing forever on a number chosen up front.
 */
#ifndef _INODE_H_
#define _INODE_H_

#include "fsparam.h"

struct icommon1 {
    unsigned short  ic_mode;
    unsigned short  ic_nlink;
    uid_t           ic_uid;
    gid_t           ic_gid;
    off_t           ic_size;
};

struct icommon2 {
    time_t          ic_atime;
    time_t          ic_mtime;
    time_t          ic_ctime;
};

struct dinode {
    struct icommon1 di_icom1;
    daddr_t         di_addr[NADDR];
    unsigned short  di_reserved[5];
    unsigned short  di_flags;
    struct icommon2 di_icom2;
};

struct inode {
    struct inode   *i_chain[2];     /* hash chain, MUST be first: the hash walk
                                     * casts the inode to its chain */
    struct vnode   *i_vnode;        /* vnode associated with this inode */
    struct vnode   *i_devvp;        /* vnode for block I/O */
    unsigned short  i_flag;
    short           i_lockholder;   /* pid holding ILOCKED, or 0.  Reno's
                                     * i_spare0; see ufs_lock. */
    dev_t           i_dev;          /* device where inode resides */
    ino_t           i_number;       /* i number */
    struct fs      *i_fs;           /* filesystem this inode belongs to */
    long            i_diroff;       /* offset of last found dir entry */
    off_t           i_endoff;       /* end of useful stuff in directory */
    struct dinode   i_din;          /* the on-disk inode */
};

/* RENO'S FIELD SHORTHAND (ufs/inode.h:53-72), and it is what makes a port read
 * against the listing it came from: upstream writes `ip->i_size`, never
 * `ip->i_din.di_icom1.ic_size`, so a file that spells it the long way has to be
 * read twice -- once for what it does and once to check it against Reno.
 *
 * The 2.11BSD dinode nests where Reno's is flat (icommon1/icommon2 around the
 * address array), which is exactly why the shorthand is worth having here and
 * not only there.
 *
 * i_flag AND i_flags ARE DIFFERENT FIELDS, one letter apart, and both are
 * Reno's names.  `i_flag` is the IN-CORE state below -- ILOCKED, IACC, IUPD --
 * and is lost when the inode leaves core.  `i_flags` is the ON-DISK user flags
 * word, `di_flags`, and persists.  Nothing here can stop the confusion; naming
 * them apart from upstream would trade it for a worse one.
 *
 * ABSENT, because the format has no such field: i_blocks and i_gen -- Reno's
 * FFS dinode carries both and 2.11BSD's 64-byte dinode carries neither.
 *
 * i_rdev IS NOT A MACRO HERE AND IS ONE IN BOTH UPSTREAMS, because on this
 * side it is HALF of a field rather than a field.  The device number of a
 * special file lives in di_addr[0], and where exactly is a FORMAT question
 * that was read out of the source rather than recalled:
 *
 *   2.11BSD's in-core inode overlays the address array with
 *       struct { u_short I_dummy; dev_t I_rdev; } i_d;
 *   (usr/sys/h/inode.h:56-65), and its iget/iput copy the array to and from
 *   the dinode with a straight bcopy of NADDR daddr_t (usr/sys/sys/
 *   ufs_inode.c:236 and :412) -- no packing, despite what the "de/compression"
 *   comment beside I_dummy suggests.  So on the PLATTER the device number is
 *   the second 16-bit word of di_addr[0] and the first word is zero.
 *
 *   A PDP-11 daddr_t is stored HIGH WORD FIRST, little-endian within each word
 *   (ufs_sb.c's sb_u32 is this port's decoder and says so).  The second word
 *   is therefore the LOW half of the long.
 *
 * Hence: i_rdev == the low 16 bits of i_addr[0], with the high 16 bits zero.
 * ufs_getrdev/ufs_setrdev in ufs_inode.c are the only two places that know it,
 * and a probe case reads the bytes back off the platter so the claim is
 * checked against the volume rather than against this comment. */
#define i_mode          i_din.di_icom1.ic_mode
#define i_nlink         i_din.di_icom1.ic_nlink
#define i_uid           i_din.di_icom1.ic_uid
#define i_gid           i_din.di_icom1.ic_gid
#define i_size          i_din.di_icom1.ic_size
#define i_addr          i_din.di_addr
#define i_flags         i_din.di_flags
#define i_atime         i_din.di_icom2.ic_atime
#define i_mtime         i_din.di_icom2.ic_mtime
#define i_ctime         i_din.di_icom2.ic_ctime
/* The ON-DISK inode's field aliases, 2.11BSD h/inode.h:131-140 verbatim.
 * Upstream's own spelling, and the counterpart of the i_* set above: code that
 * holds a `struct dinode' rather than an in-core inode reaches its fields
 * through these.  Absent until UFS 2.1 because nothing in the kernel held a
 * bare dinode for long -- iget decodes straight into i_din, so the i_* aliases
 * covered every reader.  src/userland/fsck holds them by the thousand.
 *
 * di_ic1/di_ic2 are carried as well, and are upstream's indirection rather
 * than a convenience: ported 2.11BSD code says `dp->di_ic1 = tip->i_ic1' and
 * would otherwise not compile against this header at all. */
#define di_ic1          di_icom1
#define di_ic2          di_icom2
#define di_mode         di_ic1.ic_mode
#define di_nlink        di_ic1.ic_nlink
#define di_uid          di_ic1.ic_uid
#define di_gid          di_ic1.ic_gid
#define di_size         di_ic1.ic_size
#define di_atime        di_ic2.ic_atime
#define di_mtime        di_ic2.ic_mtime
#define di_ctime        di_ic2.ic_ctime

#define i_forw          i_chain[0]
#define i_back          i_chain[1]

/* i_flag -- the IN-CORE flags, Reno's ufs/inode.h:105-111.
 *
 * ILOCKED/IWANT ARE LIVE AS OF 1.12d.  They were declared unused from the
 * start so the bit VALUES would be Reno's -- a flag word that is renumbered
 * once it has on-disk consequences is a migration -- and the lock they name
 * arrived with the write path, which is where an inode is first held across an
 * I/O.  ufs_lock/ufs_unlock in ufs_vnops.c are the only writers of either bit.
 * IRENAME is still only a marker: ufs_rename sets and clears it and nothing
 * tests it, exactly as upstream leaves it.
 *
 * IACC/IUPD/ICHG say "this timestamp is stale".  Nothing converts them into
 * timestamps yet, because kernel C has no clock (apple/fgx#167) -- Reno's
 * ITIMES reads `time.tv_sec`, and there is no `time` here.  Setting them is
 * still right: the day a clock exists, iupdat has a correct set of dirty
 * stamps to write, and until then a reader can see that the file was read.
 * That divergence is stated in ufs_getattr, which is where it shows. */
#define ILOCKED         0x0001      /* inode is locked */
#define IWANT           0x0002      /* some process waiting on the lock */
#define IRENAME         0x0004      /* inode is being renamed */
#define IUPD            0x0010      /* file has been modified */
#define IACC            0x0020      /* access time to be updated */
#define ICHG            0x0040      /* inode has been changed */
#define IMOD            0x0080      /* inode needs writing back */

/* IFMT and friends -- the on-disk type bits, from 2.11BSD h/inode.h.  These are
 * the FORMAT's, not this system's: a vnode's v_type is what the VFS above works
 * in, and ufs_ifmttovt is the one place the two meet. */
#define IFMT            0170000
#define IFIFO           0010000
#define IFCHR           0020000
#define IFDIR           0040000
#define IFBLK           0060000
#define IFREG           0100000
#define IFLNK           0120000
#define IFSOCK          0140000

/* The set-id and sticky bits, i_mode's spelling of them -- 2.11BSD
 * h/inode.h:204-206, and 4.3BSD-Reno ufs/dinode.h:67-69 word for word.
 * vnode.h's VSUID/VSGID/VSVTX are the same three values seen through a vattr;
 * both spellings exist upstream and each belongs to its own side of the VFS. */
#define ISUID           04000
#define ISGID           02000
#define ISVTX           01000

/* Reno's spelling for crossing between the two halves.  v_data is an INLINE
 * private area here rather than Reno's pointer (see PROVENANCE on vfs_subr),
 * so VTOI is a cast of an address rather than a dereference -- which is also
 * why the inode has to fit VN_MAXPRIVATE and why vfslayout.c asserts it. */
#define VTOI(vp)        ((struct inode *)((vp)->v_data))
#define ITOV(ip)        ((ip)->i_vnode)

#endif /* _INODE_H_ */
