/* specdev.h -- what a vnode knows about a DEVICE, from 4.3BSD-Reno.
 *
 * A device node is two things at once.  It is a file in a filesystem -- an
 * inode with a mode, an owner and a link count, living in v_data like any
 * other -- and it is a reference to a driver.  The second half is what this
 * header holds, and it is separate because the two halves have different
 * lifetimes: /dev/rd0 and a second link to the same device are TWO files and
 * TWO vnodes, but ONE device, and opening either must reach the same driver
 * state.
 *
 * That is what the alias machinery below is for.  Every device vnode is on a
 * hash chain keyed by its (major, minor), so checkalias can find the ones that
 * already exist for a device and mark the whole set VALIASED.  vcount then
 * counts the references across all of them, which is how a driver learns its
 * LAST close has happened rather than merely one of several.
 *
 * Reno allocates a specinfo with MALLOC and frees it in vgone.  FGX has a
 * fixed pool instead -- the same choice the vnode pool and the buffer arena
 * made, for the same reason: the count is a compile-time knob (NSPECINFO in
 * fsparam.h), and exhaustion is a loud panic rather than a silent overrun.
 */
#ifndef _SPECDEV_H_
#define _SPECDEV_H_

#include "fsparam.h"

/* The device half of a vnode.  Reno's fields, Reno's order.
 *
 * si_hashchain is a POINTER TO A POINTER, and it holds the address of the
 * HASH BUCKET this vnode's chain starts at -- not the address of the pointer
 * that references this vnode, which is what v_freeb and v_mountb hold.  The
 * difference is not pedantic: vgone's unlink walks the chain from the bucket
 * to find the predecessor, precisely because this back-link does not name it.
 * Reno is inconsistent here and this keeps the inconsistency, because
 * vgoneall and vcount both restart their walks from *v_hashchain and would
 * have to be rewritten if the field meant something else.
 *
 * si_flags stays a long, at Reno's width.  Only SI_MOUNTEDON is defined for
 * it today and a short would hold that -- but a field narrowed to the flags
 * anyone had USED, rather than to the flags BSD DEFINES, is exactly the
 * mistake this campaign made twice (VALIASED on Reno's VBWAIT bit, mnt_flag
 * at 16 bits against Reno's bit-20 kernel-state flags).  Two bytes times
 * NSPECINFO is not worth making it a third. */
struct specinfo {
    struct vnode  **si_hashchain;   /* the hash bucket this chain hangs from */
    struct vnode   *si_specnext;    /* next vnode aliasing this device */
    long            si_flags;
    dev_t           si_rdev;        /* the device itself */
};

/* Reno's exported shorthand, kept verbatim in SPELLING as well as meaning:
 * `vp->v_rdev` is how every BSD listing reads a device number, and code
 * imported later must not have to be edited to say something else.
 *
 * These expand to a member chain (`v_un->si_rdev`), which is why struct
 * vnode declares v_un as a `struct specinfo *` rather than the `char *` it
 * was: a macro that expanded to a CAST could not be written after `vp->`. */
#define v_specinfo      v_un
#define v_rdev          v_specinfo->si_rdev
#define v_hashchain     v_specinfo->si_hashchain
#define v_specnext      v_specinfo->si_specnext
#define v_specflags     v_specinfo->si_flags

/* Flags for si_flags. */
#define SI_MOUNTEDON    0x0001  /* block device is mounted on */

/* The device hash.  SPECHSZ must stay a power of two -- the mask form below
 * is Reno's fast path and the only one kept, since the modulo variant exists
 * in Reno solely to tolerate a non-power-of-two and nothing here needs that.
 *
 * The (rdev >> 5) term is what makes the hash useful on this machine: FGX
 * device numbers cluster in the low bits (one major, a handful of minors), so
 * folding the majors down onto the minors spreads a chain that would
 * otherwise be one bucket deep and NSPECINFO long. */
#define SPECHASH(rdev)  ((((rdev) >> 5) + (rdev)) & (SPECHSZ - 1))

extern struct vnode *speclisth[SPECHSZ];

#endif /* _SPECDEV_H_ */
