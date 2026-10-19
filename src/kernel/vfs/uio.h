/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno sys/uio.h
 *   Ported from sys/uio.h, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986 The Regents of the University of California.
 *   All rights reserved.
 */
/* uio.h -- a transfer in progress.  UFS 1.7a.
 *
 * WHAT A uio IS FOR, and it is not "a buffer pointer with a length".  One
 * describes a transfer that may be SCATTERED across several regions, may be
 * only PARTIALLY satisfied, and may be going either direction between the
 * kernel and somewhere else.  The reason every vnode read and write takes one
 * instead of (buf, len) is that all three of those are the normal case:
 *
 *   readv(2) hands the kernel several disjoint regions at once, which is the
 *   iovec array;
 *   a read that hits end-of-file transfers less than was asked, and the
 *   caller learns how much from what is LEFT (uio_resid), not from a return
 *   value;
 *   the same code serves a user-space caller and a kernel-internal one, which
 *   is uio_segflg.
 *
 * THE STRUCTURE IS CONSUMED AS IT IS USED.  uiomove ADVANCES it -- iov_base
 * forward, iov_len and uio_resid down, uio_offset up -- so a uio is a cursor,
 * not a description.  A caller that wants to know how much moved compares
 * uio_resid before and after; a caller that reuses one without resetting it
 * transfers nothing the second time.  This is the single most common way to
 * get a uio wrong, so it is stated here rather than left to be discovered.
 *
 *----------------------------------------------------------------------------
 * TWO DIVERGENCES FROM RENO, both deliberate and both stated rather than
 * discovered:
 *
 *   ENUMS BECOME int PLUS #define.  Reno declares `enum uio_rw` and
 *   `enum uio_seg` and uses them as field types (sys/uio.h:31,36).  fcc has
 *   enums, but every other structure in this campaign declares such a field as
 *   a plain int naming its enum in a trailing comment -- namei.h:134's
 *   ni_segflg is the precedent, written before this header existed -- and the
 *   VALUES are what any of this depends on.  Keeping one convention matters
 *   more than matching a keyword.
 *
 *   UIO_USERISPACE IS ABSENT.  Reno's third segment flag reads from a
 *   process's INSTRUCTION space, which is a PDP-11 split-I/D concept with no
 *   meaning on a 65816: there is one address space per bank and no separate I
 *   space to name.  Reno's uiomove treats it identically to UIO_USERSPACE
 *   anyway (kern_subr.c:36-37 fall through to the same arm), so nothing is
 *   lost but a name that could only ever be wrong here.
 */

#ifndef _FGX_UIO_H_
#define _FGX_UIO_H_

#include "fsparam.h"            /* off_t */

/* enum uio_rw.  UIO_READ IS 0 AND THAT IS LOAD-BEARING: a zeroed uio therefore
 * describes a READ, and the write path must set the field explicitly.  Reno
 * relies on this the other way round -- `panic("ufs_write mode")` at
 * ufs_vnops.c:673 catches a write that arrived with a zeroed uio_rw -- so the
 * order is a contract with upstream code, not a preference. */
#define UIO_READ        0
#define UIO_WRITE       1

/* enum uio_seg.  These MOVED HERE FROM namei.h at 1.7a, where 1.6a parked them
 * so ni_segflg could mean something before this header existed; namei.h now
 * includes this file rather than carrying a second copy.  UIO_USERSPACE is 0,
 * so a zeroed uio describes a USER pointer -- the safe default, because a user
 * pointer is REFUSED rather than dereferenced while there is no copyin. */
#define UIO_USERSPACE   0       /* from the user's address space */
#define UIO_SYSSPACE    1       /* from the kernel's */

/* One region of a scattered transfer.  Reno's <sys/uio.h> struct iovec, which
 * is also readv(2)'s and writev(2)'s user-visible argument type -- so this
 * layout is an ABI, not an internal choice, the day those syscalls land. */
struct iovec {
    char           *iov_base;   /* Reno: caddr_t */
    unsigned short  iov_len;    /* Reno: int.  2.11BSD: size_t.  See below. */
};

/* THE LARGEST TRANSFER uio_resid AND iov_len CAN EXPRESS.  apple/fgx#165.
 *
 * It exists so the syscall layer's refusal is written against the FIELD rather
 * than against fcc's `int', which is what makes it survive the change it
 * guards: today `len' is a 16-bit signed int, the `len < 0' refusal takes the
 * top half of the range, and every value that survives round-trips through
 * unsigned short exactly -- so the guard is provably never taken.  The moment
 * `len' widens (a `long len' is a reasonable thing to want on a machine with
 * 64 KB banks) a positive value can exceed this, and the cast that follows it
 * would take the low half in SILENCE: uiomove's signed `n' goes negative, its
 * `n > 0 && uio->uio_resid' is false at once, and it returns 0 having moved
 * nothing -- a successful zero-byte transfer with no error anywhere.
 *
 * 2.11BSD's rwuio does the same job the same way for the SUMMING case, which
 * is what readv/writev will need: it accumulates into a 32-bit `off_t total'
 * and compares `uio->uio_resid != total' to catch the wrap
 * (usr/sys/sys/sys_generic.c:145-153).  Reno cannot -- its readv sums into a
 * signed field and tests the sign, which an unsigned field makes
 * inexpressible.  When those calls arrive they take 2.11BSD's shape, and this
 * is the constant they compare against.
 */
#define UIO_MAXRESID    65535U


/* A transfer in progress.
 *
 * WHY K&R A.7.7 GOVERNS ANY POINTER WALK OVER THIS.  A.7.3.1 (p.162) makes the
 * subscript an addition BY DEFINITION -- "The expression E1[E2] is identical
 * (by definition) to *((E1)+(E2))" -- so `&uio->uio_iov[1]` IS `uio->uio_iov +
 * 1`, and A.7.7 (p.166) then fixes the scale: "The latter is converted to an
 * address offset by multiplying it by the size of the object to which the
 * pointer points."  fcc got that wrong for exactly this structure
 * (apple/fgx#163), and because a mis-scaled address is a WILD POINTER rather
 * than a diagnostic, the symptom was a machine with a blank screen.
 *
 * uio_resid IS THE SUM OF THE REMAINING iov_len, and that is a CALLER'S
 * invariant which nothing here defends -- see kern_subr.c.  Reno establishes it
 * in the syscall layer: sys_generic.c:131-142 (readv) sets `auio.uio_resid = 0`
 * and then `auio.uio_resid += iov->iov_len` per region, rejecting a negative
 * length and an overflowing total as EINVAL.  For the single-region case
 * vfs_vnops.c:177-178 (vn_rdwr) simply sets both to the same `len`.
 *
 * THE COUNTS ARE 16-BIT AND UNSIGNED, AND 2.11BSD IS WHY.  Reno's uio_resid
 * and iov_len are 32-bit ints; this machine has neither the width nor a reason
 * to want it.  The BSD that faced exactly this constraint already answered it,
 * and its own header records the decision -- vendor/2.11BSD/usr/sys/h/uio.h:34
 * -37: "Copied from 4.4-Lite and modified for 2.11BSD.  Modifications were
 * removal of prototypes, limits for dynamic allocation of iovec structs and
 * changing uio_resid to u_short from int."  Its iovec carries `size_t iov_len`
 * (:47-50), unsigned likewise.
 *
 * UNSIGNED IS NOT A DETAIL HERE.  Signed 16-bit would cap a transfer at 32767,
 * which is BELOW a full 64 KB bank -- so the obvious justification, that a
 * read(2) is bounded by the caller's buffer in one bank, would have argued for
 * a limit the type could not actually express.  Unsigned reaches 65535 and
 * covers it.  The tree already spells transfer counts this way: buf.h's
 * b_bcount and b_resid are `unsigned short` for the same reason.
 *
 * WHAT IS GIVEN UP is Reno's overflow tell: readv checks `uio_resid < 0` after
 * summing the regions (sys_generic.c:138-141), which an unsigned field cannot
 * express.  2.11BSD replaces it rather than dropping it -- rwuio accumulates
 * into a 32-bit total and compares (sys_generic.c:145-153).  THE SYSCALL LAYER
 * THAT MUST DO THAT ARRIVES AT 1.7b; until then the only builder of a uio is
 * the probe.  Tracked, so it is an obligation rather than a comment.
 *
 * uio_offset stays off_t (long, 32 bits) because a FILE offset genuinely
 * exceeds 16 bits: a volume is millions of bytes even though no single
 * transfer is.  That split -- 32-bit offset, 16-bit count -- is the same one
 * the campaign made for daddr_t at 1.0, and for the same reason. */
struct uio {
    struct iovec   *uio_iov;    /* the regions, in order */
    int             uio_iovcnt; /* how many remain */
    off_t           uio_offset; /* where in the FILE; advanced as it moves */
    unsigned short  uio_resid;  /* bytes still to transfer; see above */
    int             uio_segflg; /* enum uio_seg: whose address space */
    int             uio_rw;     /* enum uio_rw: which direction */
};

#endif /* _FGX_UIO_H_ */
