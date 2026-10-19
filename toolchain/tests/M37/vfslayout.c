/* vfslayout.c -- UFS campaign 1.1: the VFS layer's conformance fixture.
 *
 * This USED TO DECLARE the structures it checks.  It no longer does: it
 * includes the real kernel headers, so there is one definition of a vnode in
 * the tree rather than two that agree until someone edits one of them.  That
 * was a live risk -- the fixture was written first, deliberately, as an
 * executable specification, and a header written later to match it would have
 * been a second source of truth from the day it landed.
 *
 * WHAT IT IS FOR, now that the headers exist:
 *
 *   1. fcc regression.  Every offset below is a fact about how this compiler
 *      lays out structures.  An alignment change, a pointer-width change or a
 *      field-order slip fails here loudly, in the same way M37/pdplayout.c
 *      pins the on-disk format.
 *   2. Budget conformance.  The pool sizes are KNOBS (see fsparam.h).  What is
 *      asserted is the RELATIONSHIPS -- floors that must hold, ceilings that
 *      must not be crossed -- so turning a knob does not require editing this
 *      file, while turning one somewhere illegal fails immediately.
 *
 * Scalar widths, MEASURED not assumed: short 2, int 2, long 4, POINTERS 4.
 * A first draft of this fixture took pointers to be 2 bytes and every
 * structure came out 10 to 18 bytes short.  FGX2 is multi-bank, so an fcc
 * pointer carries a bank; that is why the in-core inode is 98 bytes rather
 * than 88, and why the vnode is 164 rather than 146.
 *
 * Exit 42 = pass; every other code identifies the failing property.  The list
 * has outgrown its own pass value, so codes 43 and up are failures like any
 * other -- only 42 means success, and nothing reads the ordering.
 */

#include "../../../src/kernel/vfs/fsparam.h"
#include "../../../src/kernel/vfs/inode.h"
#include "../../../src/kernel/vfs/vnode.h"
#include "../../../src/kernel/vfs/mount.h"
#include "../../../src/kernel/vfs/buf.h"
#include "../../../src/kernel/vfs/specdev.h"
#include "../../../src/kernel/vfs/namei.h"
#include "../../../src/kernel/vfs/file.h"

struct dinode  gdi;
struct inode   gin;
struct vnode   gvn;
struct mount   gmn;
struct statfs  gsf;
struct buf     gbf;
struct specinfo gsi;
struct namecache gnc;
struct file    gfl;
struct uio     gui;

#define OFF(obj, mem)  ((int)((char *)&(obj).mem - (char *)&(obj)))

int main()
{
    int priv;

    /* ---- the on-disk inode is the format contract, unchanged from 0.2 ---- */
    if (sizeof(struct dinode) != 64)            return 1;
    if (OFF(gdi, di_addr) != 12)                return 2;

    /* ---- THE LOAD-BEARING ASSERTION ----
     * The vnode's private area must hold the whole in-core inode.  If this
     * ever fails, either shrink the inode or raise VN_MAXPRIVATE -- but do not
     * silently truncate, because the overflow lands in v_tag and the
     * corruption presents as a vnode of the wrong type. */
    if (sizeof(struct inode) > VN_MAXPRIVATE)   return 3;

    /* The dinode must sit inside the in-core inode, not alias its head:
     * i_chain MUST be first (the hash walk casts the inode to its chain). */
    if (OFF(gin, i_chain) != 0)                 return 4;
    if (OFF(gin, i_din) + 64 > (int)sizeof(struct inode)) return 5;

    /* ---- the in-core inode, pinned ----
     * 100 bytes: 36 of bookkeeping plus the 64-byte on-disk body.  The
     * bookkeeping is pointer-heavy (five pointers at 4 bytes each), which is
     * where a 16-bit-pointer estimate goes wrong.
     *
     * IT WAS 98 UNTIL 1.12d, when the inode lock added i_lockholder -- Reno's
     * i_spare0, the pid holding ILOCKED, which is what turns a self-deadlock
     * into a panic instead of a hang.  Every offset from i_dev down moved by
     * two, and this file going red is the whole of how that gets noticed. */
    if (sizeof(struct inode) != 100)            return 6;
    if (OFF(gin, i_vnode)      !=  8)           return 7;
    if (OFF(gin, i_devvp)      != 12)           return 8;
    if (OFF(gin, i_flag)       != 16)           return 9;
    if (OFF(gin, i_lockholder) != 18)           return 43;
    if (OFF(gin, i_dev)        != 20)           return 10;
    if (OFF(gin, i_number)     != 22)           return 11;
    if (OFF(gin, i_fs)         != 24)           return 12;
    if (OFF(gin, i_diroff)     != 28)           return 13;
    if (OFF(gin, i_endoff)     != 32)           return 14;
    if (OFF(gin, i_din)        != 36)           return 15;

    /* ---- the vnode ---- */
    if (OFF(gvn, v_flag)     !=  0)             return 16;
    if (OFF(gvn, v_usecount) !=  2)             return 17;
    if (OFF(gvn, v_lastr)    != 10)             return 18;
    if (OFF(gvn, v_id)       != 14)             return 19;
    if (OFF(gvn, v_mount)    != 18)             return 20;
    if (OFF(gvn, v_op)       != 22)             return 21;
    if (OFF(gvn, v_data)     != 60)             return 22;
    if (sizeof(struct vnode) != 60 + VN_MAXPRIVATE) return 23;

    /* The private area is the vnode's TAIL, so a filesystem that overruns it
     * runs off the end of the structure rather than into another field. */
    priv = (int)sizeof(struct vnode) - OFF(gvn, v_data);
    if (priv != VN_MAXPRIVATE)                  return 24;

    /* ---- mount + statfs ---- */
    if (sizeof(struct statfs) != 100)           return 25;
    if (OFF(gsf, f_fsize)      !=   4)          return 26;
    if (OFF(gsf, f_mntonname)  !=  36)          return 27;
    if (OFF(gsf, f_mntfromname)!=  68)          return 28;
    if (sizeof(struct mount) != 130)            return 29;
    if (OFF(gmn, mnt_stat)   != 26)             return 30;
    /* mnt_flag must stay 32 bits.  Reno's kernel-state flags live in bits 20
     * through 24 -- MNT_MPBUSY is 0x00400000 -- so a 16-bit field cannot hold
     * them at all: every test would read zero and every set would be
     * discarded, with no diagnostic anywhere.  That is what this was before,
     * and the reason a size assertion is not enough on its own. */
    /* ---- EVERY FLAG FIELD MUST HOLD ITS WIDEST FLAG ----
     *
     * Written as a ROUND TRIP through the real field rather than as a sizeof,
     * because the size is a proxy and the round trip is the property: store
     * the highest constant defined for the field and require it to read back.
     *
     * This section exists because two fields did NOT satisfy it, and neither
     * failure was visible.  VALIASED had been given Reno's VBWAIT bit, so the
     * two aliased the moment VBWAIT was needed.  mnt_flag was sixteen bits
     * wide while Reno puts its kernel-state flags in bits 20 through 24, so
     * MNT_MPBUSY could not be represented at all -- every test of it would
     * have read zero, every set would have been discarded, and nothing
     * anywhere would have said so.
     *
     * Both were found by reading the vendored headers by hand.  That is not a
     * check: it happens once, by whoever thinks to do it.  This runs on every
     * build, and it goes red for BOTH ways the property can break -- a field
     * narrowed, or a flag added above the width of the field that holds it. */
    gvn.v_flag = VALIASED;
    if (gvn.v_flag != VALIASED)                 return 52;
    gbf.b_flags = B_LOCKED;
    if (gbf.b_flags != B_LOCKED)                return 53;
    gmn.mnt_flag = MNT_UNMOUNT;
    if (gmn.mnt_flag != MNT_UNMOUNT)            return 54;
    gsi.si_flags = SI_MOUNTEDON;
    if (gsi.si_flags != SI_MOUNTEDON)           return 55;

    /* And the size assertion is kept ALONGSIDE the round trip, not instead of
     * it: the round trip proves the widest CURRENT flag fits, while this
     * pins the field at the width Reno gives it, so narrowing it back fails
     * even during a window when no flag happens to need the top bits. */
    if (sizeof(gmn.mnt_flag) != 4)              return 48;

    /* The one relationship that cannot be round-tripped: v_flag and the
     * buffer flags share no field, but VBWAIT and VALIASED share a WORD, and
     * a future flag placed on an occupied bit reads back perfectly.  So the
     * distinctness of the v_flag set is asserted directly. */
    if (VBWAIT == VALIASED)                     return 49;
    if (VXLOCK == VXWANT)                       return 50;
    if ((VROOT | VTEXT | VSYSTEM | VXLOCK | VXWANT | VBWAIT | VALIASED) !=
        (VROOT + VTEXT + VSYSTEM + VXLOCK + VXWANT + VBWAIT + VALIASED))
        return 51;                              /* any two overlapping bits */

    /* ---- specinfo: the device half of a vnode ----
     *
     * si_hashchain is a pointer to a POINTER and si_specnext a pointer to a
     * vnode, and both must be four bytes: this structure lives in a pool in
     * one bank while the vnodes it links live in another, so a link that lost
     * its bank byte would resolve to whatever sits at the same offset in the
     * pool's bank -- a walk that finds a plausible structure rather than
     * failing. */
    if (sizeof(struct specinfo) != 14)          return 56;
    if (OFF(gsi, si_hashchain) !=  0)           return 57;
    if (OFF(gsi, si_specnext)  !=  4)           return 58;
    if (OFF(gsi, si_flags)     !=  8)           return 59;
    if (OFF(gsi, si_rdev)      != 12)           return 60;
    if (sizeof(gsi.si_hashchain) != 4)          return 61;
    if (sizeof(gsi.si_specnext) != 4)           return 62;
    /* v_un is the specinfo POINTER, not the structure: a vnode that is not a
     * device carries four bytes here, not fourteen. */
    if (sizeof(gvn.v_un) != 4)                  return 63;

    /* The hash must stay a power of two -- SPECHASH's mask form is the only
     * one kept, and with a non-power-of-two size it would index off the end of
     * the bucket array rather than wrap. */
    if ((SPECHSZ & (SPECHSZ - 1)) != 0)         return 64;

    /* ---- the name cache entry ----
     * 64 is not decoration here.  The three VFS pools are carved from ONE
     * heap allocation whose size tools/gen_vfs_equ.py derives for the
     * assembly that allocates it, and that derivation multiplies this number
     * by NNAMECACHE.  sizeof(struct vnode) and sizeof(struct specinfo) are
     * already pinned above; without this one, the arena could come out short
     * and the LAST pool carved would overlap whatever follows the allocation
     * -- corruption at a distance from the edit that caused it.
     *
     * The hash must also stay a power of two: nchash() masks rather than
     * divides, so a non-power-of-two size indexes off the end of the bucket
     * array instead of wrapping. */
    if (sizeof(struct namecache) != 64)         return 65;
    if ((NCHASH & (NCHASH - 1)) != 0)           return 66;

    /* ---- the nameidata slot (UFS 1.2) ----
     * Pinned for exactly the reason the namecache entry above is: ndinit
     * carves VFS_NPROC * VFS_NDPERPROC of these plus a paired MAXPATHLEN
     * buffer each, from the SAME single allocation, and it is carved LAST --
     * so if this number grows without the generator following, this pool is
     * the one that runs off the end.
     *
     * 52 is the sum of a packed layout with 4-byte pointers, and it is a
     * SUM rather than a round number, so it moves the moment a field is
     * added.  That is the point: the campaign has already deferred three
     * fields out of this struct (ni_dent, ni_nd, and a real ucred for
     * ni_cred), and every one of them will grow it when it lands. */
    /* 158 SINCE THE SYMLINK ARM, 154 at UFS 1.12c, 52 before it.  The
     * last four are ni_pnalt, the second pathname buffer Reno's symlink
     * expansion needs live at the same time as the first.  The growth is
     * otherwise direnter's
     * requirements arriving in the slot: ni_dent is an on-disk `struct direct`
     * whose d_name is MAXNAMLEN+1 = 64 bytes (70 of the 102), plus the uio and
     * iovec that write it and the three offsets that say where.  This number
     * is what tools/gen_vfs_equ.py sizes the nameidata pool from, so a change
     * here that is not made there undersizes the arena and the LAST pool
     * carved from it runs off the end -- heap corruption a long way from the
     * edit.  That is why this assertion exists and why it is exact. */
    if (sizeof(struct nameidata) != 158)        return 70;
    /* The buffer is PAIRED with the slot rather than allocated per call, so
     * the arena arithmetic depends on this too. */
    if (MAXPATHLEN != 128)                      return 71;
    if (VFS_NDPERPROC < 2)                      return 72;

    /* ---- the open file (UFS 1.2c) ----
     * Pinned for the same reason, and it now carves LAST: finit takes the
     * file table and the per-process descriptor arrays from what ndinit
     * leaves, so this is the pool that runs off the end of the allocation if
     * the struct grows without tools/gen_vfs_equ.py's FILE_SIZE following.
     *
     * 24 is a SUM of a packed layout -- four shorts then four 4-byte members
     * -- so it moves the moment a field is added, which is the point: two
     * fields in it are deliberately dead today (f_cred wants a ucred, f_ops
     * wants 1.7's dispatch) and neither changes the size when it comes alive,
     * but anything genuinely new does.
     *
     * A DESCRIPTOR IS A POINTER TO ONE OF THESE, not one of these, and the
     * arena arithmetic multiplies the two by DIFFERENT counts -- NFILE for
     * the table, VFS_NPROC * FS_MAX_FDS for the arrays.  The relationship
     * that must hold is the over-subscription: more possible descriptors than
     * file structs, because dup and fork share a struct. */
    if (sizeof(struct file) != 24)              return 73;
    if (sizeof(struct file *) != 4)             return 74;

    /* EVERY FIELD OFFSET, because UFS 1.7d-I2 puts the syscall layer's
     * ASSEMBLY on this structure.  The size assertion above catches a field
     * being added; it does not catch two being reordered, and a reorder is
     * invisible to the C -- both sides still say `fp->f_data` -- while the
     * assembly reads a fixed number.  include/vfs_equ.s carries these same
     * numbers as F_* EQUs, generated from tools/gen_vfs_equ.py, and this is
     * what stops the two copies drifting.
     *
     * The layout is Reno's: four shorts, then four 4-byte members. */
    if (OFF(gfl, f_flag) != 0)                  return 77;
    if (OFF(gfl, f_type) != 2)                  return 78;
    if (OFF(gfl, f_count) != 4)                 return 79;
    if (OFF(gfl, f_msgcount) != 6)              return 80;
    if (OFF(gfl, f_cred) != 8)                  return 81;
    if (OFF(gfl, f_ops) != 12)                  return 82;
    if (OFF(gfl, f_data) != 16)                 return 83;
    if (OFF(gfl, f_offset) != 20)               return 84;
    if (NFILE < 3 + VFS_NPROC)                  return 75;
    if (VFS_NPROC * FS_MAX_FDS <= NFILE)        return 76;

    /* ---- the buffer header ----
     * The pointer-heavy shape is the point: seven 4-byte pointers in a
     * structure 2.11BSD fits into 24 bytes with 2-byte pointers. */
    if (sizeof(struct buf) != 50)               return 31;
    if (OFF(gbf, b_forw)   !=  2)               return 32;
    if (OFF(gbf, b_dev)    != 22)               return 33;
    if (OFF(gbf, b_addr)   != 24)               return 34;
    if (OFF(gbf, b_lblkno) != 28)               return 35;
    if (OFF(gbf, b_blkno)  != 32)               return 44;
    if (OFF(gbf, b_vp)     != 38)               return 36;
    if (OFF(gbf, b_blockf) != 42)               return 45;
    if (OFF(gbf, b_blockb) != 46)               return 46;

    /* b_blockb is a pointer to a POINTER, and on this machine that is not a
     * pedantic distinction: it holds the address of a field inside an array
     * element, which is the construct that has silently dropped a bank byte
     * here.  A 2-byte b_blockb would still compile and would still unlink the
     * head of a list correctly, failing only on a middle-of-list unlink into
     * another bank. */
    if (sizeof(gbf.b_blockb) != 4)              return 47;

    /* BOTH block numbers must stay 32-bit.  b_blkno carries what deliverable
     * 1.0 widened the block layer to accept, and b_lblkno is the cache key; a
     * 16-bit either would silently reintroduce the 32 MB ceiling one layer
     * above where it was just removed. */
    if (sizeof(gbf.b_blkno) != 4)               return 37;
    if (sizeof(gbf.b_lblkno) != 4)              return 43;

    /* ---- THE BUDGET, as relationships rather than totals ----
     *
     * FLOOR: cwd is a held vnode and every mount holds its root, so those are
     * pinned for the lifetime of the process or mount and can never be
     * reclaimed under pressure.  A pool below that line cannot make progress;
     * a pool above it degrades to ENFILE, which is what 2.11BSD does.
     *
     * This deliberately does NOT require VNODE_POOL >= FS_MAX_FDS.  The live
     * machine disproves that rule: 176 inode slots serve 122 processes at
     * NOFILE=30, because the table is keyed by (dev, inum) and descriptors on
     * the same file share one entry. */
    if (VNODE_POOL < VFS_NPROC + VFS_NMOUNT)    return 38;

    /* CEILING: the pools live in a module bank, so the binding constraint is
     * that the tables plus the buffer arena still fit one 64 KB bank with room
     * for the code that uses them.  Long arithmetic -- fcc's int is 16 bits
     * and these sums exceed it. */
    if ((long)VNODE_POOL * (long)sizeof(struct vnode)
      + (long)VFS_NMOUNT * (long)sizeof(struct mount)
      + (long)NBUF       * (long)sizeof(struct buf) > VFS_TABLE_MAX) return 39;

    /* The buffer arena is separately placed -- headers do not embed their data
     * -- but it still has to fit a bank on its own. */
    if ((long)NBUF * (long)FS_BLKSIZE > BANK_SIZE) return 40;

    /* A buffer holds exactly one filesystem block, and that block size is not
     * ours to choose: 1024 was MEASURED on the 2.11BSD volume in 0.3 and is
     * pinned by the on-disk format.  This is the knob that looks adjustable
     * and is not -- it is here so that anyone turning it to tune the cache
     * finds out immediately that they are changing the disk format. */
    if (FS_BLKSIZE != 1024)                     return 41;

    /* ---- struct uio, because ASSEMBLY now reads one ----------------------
     *
     * apple/fgx#198.  A chardev's bulk read op is assembly in a driver module
     * and has to bound its drain by uio_resid before it dequeues anything --
     * uiomove clamps to resid and DISCARDS the excess (kern_subr.c:142), so a
     * driver that over-drains loses those bytes off the ring.  Reno's ptcread
     * does the same thing for the same reason: `cc = MIN(uio->uio_resid,
     * sizeof(buf))` (kern/tty_pty.c).
     *
     * That makes the offset a fact assembly depends on, and the rule for those
     * in this campaign is that they are PINNED HERE and never derived.  These
     * numbers were read off fcc's own output for uiomove -- LDY #10 for the
     * uio_resid test, LDY #12 for uio_segflg, LDY #14 for uio_rw -- not
     * counted up from the declaration.
     *
     * uio_resid is `unsigned short` and NOT Reno's 32-bit int, so the read is
     * a 16-bit one; see uio.h on why 2.11BSD is the precedent. */
    if (sizeof(struct uio) != 16)               return 77;
    if (OFF(gui, uio_iov)    !=  0)             return 78;
    if (OFF(gui, uio_iovcnt) !=  4)             return 79;
    if (OFF(gui, uio_offset) !=  6)             return 80;
    if (OFF(gui, uio_resid)  != 10)             return 81;
    if (OFF(gui, uio_segflg) != 12)             return 82;
    if (OFF(gui, uio_rw)     != 14)             return 83;

    /* And the iovec, for the same reason one day; asserted now because it is
     * the other half of the same layout and costs nothing to state. */
    if (sizeof(struct iovec) != 6)              return 84;
    if (OFF(gui, uio_iov) != 0)                 return 85;

    return 42;
}
