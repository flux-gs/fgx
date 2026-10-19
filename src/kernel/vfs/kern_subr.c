/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/kern_subr.c
 *   Ported from kern/kern_subr.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986 Regents of the University of California.
 *   All rights reserved.
 */
/* kern_subr.c -- uiomove, the one primitive every vnode read and write is
 * built on.  UFS 1.7a.
 *
 * IT MOVES BYTES AND IT ADVANCES THE CURSOR, and the second half is the half
 * that gets forgotten.  Every caller in Reno relies on the uio being consumed:
 * spec_read loops `while (error == 0 && uio->uio_resid > 0 && n != 0)` and
 * would spin forever if uiomove did not lower uio_resid.  So the advancing is
 * not bookkeeping around the copy -- it IS the interface, and the probe
 * asserts every field it touches rather than just the bytes.
 *
 * WHAT IS DELIBERATELY NOT HERE, named rather than left to be discovered:
 *
 *   (UIO_USERSPACE used to be listed here as failing rather than copying.  It
 *   is not: uiomove's arm changed at T3 stage 3 and ureadc's at stage 4, when
 *   each grew a caller that hands it a calling process's own buffer.  The
 *   reasoning is at the two arms.)
 *
 *   uwritec IS NOT HERE.  It has NO caller anywhere in Reno's kern/ at all: it
 *   is already dead code upstream, and adding it would be a routine with no
 *   witness and no user.
 *
 *   ureadc WAS NOT HERE EITHER, on the grounds that "FGX reaches its consoles
 *   through kernel assembly rather than through a vnode, so it would have no
 *   caller here".  THAT CEASED TO BE TRUE at apple/fgx#108 T3: tty.c's ttread
 *   is ported into the tty bank and calls it, and T4's tty_pty.c calls it four
 *   times more.  Two callers in two different banks is exactly why it belongs
 *   beside uiomove rather than in either of them -- which is where BSD puts it.
 */

#include "fsparam.h"
#include "uio.h"

extern void kc_panic();


/* uio_copy -- Reno's bcopy(3).  IT IS ASSEMBLY, in src/modules/vfs/uio_copy.s,
 * and so is upstream's: uiomove's SYSSPACE arm calls bcopy (Reno
 * kern/kern_subr.c:48,50) and no vendored tree carries a C definition of it,
 * because every port has a block move worth reaching.  The 65816's is MVN.
 *
 * IT WAS A BYTE LOOP HERE UNTIL apple/fgx#307, and the version that stood here
 * predicted its own replacement: "IT IS SLOW AND THAT IS A KNOWN CEILING ...
 * Nothing measures as slow yet because nothing calls this on a hot path -- the
 * only caller is the probe."  The vnode read path became that caller.  fcc
 * spent about 45 instructions per byte on the loop; MVN is seven cycles a byte
 * and no loop.
 *
 * The contract is unchanged and the assembly file carries it in full: no
 * overlap (MVN increments, and a uio's two sides are a buffer-cache block and
 * a caller's buffer), and a zero length returns before the decrement that
 * would otherwise ask for 65536 bytes. */
extern void uio_copy();


/* uiomove -- move n bytes between `cp` and wherever the uio points.
 *
 * Reno's kern/kern_subr.c:13.  DIRECTION IS THE uio's, not the caller's: on a
 * UIO_READ the bytes go FROM cp INTO the iovecs (the kernel is answering a
 * read), and on UIO_WRITE they come the other way.  Getting this backwards
 * compiles and silently transfers garbage in the right quantity, which is why
 * Reno panics on a third value rather than defaulting.
 *
 * THE ZERO-LENGTH IOVEC IS SKIPPED WITHOUT CONSUMING n, and it is a `continue`
 * rather than an advance-and-copy for a reason worth keeping: readv(2) may
 * legally hand the kernel an empty region in the middle of an array, and an
 * implementation that treated it as end-of-list would silently drop every
 * region after it.
 *
 * `n` IS THE CALLER'S CEILING AND uio_resid IS NOT A SECOND ONE.  n is how
 * much the CALLER has available -- one buffer-cache block, say -- and the copy
 * is `cnt = min(iov_len, n)`.  uio_resid appears only in the LOOP CONDITION,
 * which is what lets spec_read hand over one block at a time without either
 * side knowing the other's size.
 *
 * THAT WORKS BECAUSE uio_resid IS DEFINED AS THE SUM OF THE REMAINING iov_len,
 * and it is a CALLER'S invariant that nothing here defends.  Hand uiomove a
 * uio whose uio_resid is smaller than its regions -- iov_len 20 against
 * uio_resid 6 -- and it copies min(20, n) bytes and drives uio_resid NEGATIVE.
 * Reno is identical (kern_subr.c:26-33) and equally undefended.
 *
 * This is written down because the first cut of the probe asserted the
 * opposite, from reasoning rather than from the source: it built exactly that
 * malformed uio expecting uio_resid to cap the copy, and reported a bug in an
 * implementation that was right.
 *
 * THE OTHER DIRECTION IS THE DANGEROUS ONE AND WAS NOT STATED AT ALL.  If
 * uio_resid EXCEEDS the sum of the regions, the skip arm below never consults
 * uio_iovcnt: it walks uio_iov PAST THE END of the array and reads whatever
 * follows as an iovec, then writes through it.  On this machine that is a wild
 * kernel write, not a fault.  Reno is identical (kern_subr.c:27-31) and
 * equally undefended -- uio_iovcnt is decremented but never tested -- so this
 * is faithful rather than a porting slip, but it is a PRECONDITION the caller
 * must meet and 1.7b inherits it.
 *
 * THE INVARIANT BELONGS TO WHOEVER FILLS THE STRUCTURE IN, and in Reno that is
 * the syscall layer: sys_generic.c:131-142 (readv) sets `auio.uio_resid = 0`
 * and accumulates `auio.uio_resid += iov->iov_len` across the regions, failing
 * EINVAL on a negative length or an overflowing total.  The single-region case
 * does it by construction -- vfs_vnops.c:177-178 (vn_rdwr) assigns the same
 * `len` to both.  Here that layer arrives at 1.7b, so until then the only
 * builder of a uio is the probe.
 */
int
/* ureadc -- give the next character to the reader, as the result of a read.
 *
 * 2.11BSD usr/sys/sys/kern_subr.c:89, and Reno's is the same routine.
 *
 * IT IS NOT uiomove WITH n = 1, and the difference is worth stating because the
 * shortcut is tempting: uiomove panics on a uio whose uio_rw is neither READ
 * nor WRITE, walks a loop, and clamps against n; this advances past empty
 * iovecs and stores ONE byte.  ttread calls it once per character in its inner
 * loop, which is why upstream keeps the cheap one.
 *
 * UIO_USERSPACE STORES, exactly as uiomove's arm does and for the same reason,
 * which is written out in full there.  This arm refused until T3 STAGE 4, on
 * the grounds that there was no fault-safe copy and no caller to witness a
 * change; stage 4 supplies the caller.  `ttread' hands this routine the
 * reading process's own buffer one character at a time, so a refusal here is
 * a read(2) that returns EFAULT for every tty read in the system.
 *
 * UPSTREAM STORES TOO.  2.11BSD's `usr/sys/sys/kern_subr.c:89' and Reno's
 * `kern/kern_subr.c' are the same routine, and both spell the user arm
 * `if (subyte(iov->iov_base, c) < 0) return (EFAULT);' -- a STORE that can
 * fail, not a refusal.  subyte is machine-dependent and its FGX counterpart is
 * the direct store below, for the reason uiomove's arm gives: there is one
 * banked address space here, so copyin and copyout coincide with a plain copy
 * and Reno's two arms do too.  What was missing was never the mechanism.
 *
 * UIO_USERISPACE IS DROPPED, not forgotten: it is the PDP-11's separate
 * instruction space, which a 65816 does not have.  The switch becomes an if,
 * and an unknown segflg lands in the same refusal as USERSPACE rather than
 * falling through and storing.
 *
 * THE PANIC IS UPSTREAM'S.  A uio with no iovecs left and a caller still
 * offering characters is a broken interface, not a runtime error to report --
 * ttread's loops all test uio_resid before calling.
 */
ureadc(c, uio)
register int c;
register struct uio *uio;
{
    register struct iovec *iov;

again:
    if (uio->uio_iovcnt == 0)
        kc_panic("ureadc");
    iov = uio->uio_iov;
    if (iov->iov_len == 0 || uio->uio_resid == 0) {
        uio->uio_iovcnt--;
        /* `&uio->uio_iov[1]`, NOT `uio->uio_iov + 1` -- the same bank-byte
         * reason uiomove below gives for the identical step. */
        uio->uio_iov = &uio->uio_iov[1];
        goto again;
    }
    /* THE ASYMMETRY WITH uiomove IS GONE, and the two routines now answer the
     * same way for the same segflg.  It was deliberate while it lasted: the
     * write path witnessed uiomove's arm at stage 3 and `ureadc' had no caller
     * at all, so accepting USERSPACE here would have been an unwitnessed
     * change to a routine nothing ran.  Stage 4 is the caller.
     *
     * `tty_probe3' cases 397-399 moved WITH this arm rather than being
     * deleted: they used to pin the refusal and that no store happened, and
     * they now pin the STORE and every uio field it advances.  A probe that
     * pins a divergence has to move when the divergence does, or it pins the
     * old answer against the new code. */
    if (uio->uio_segflg != UIO_SYSSPACE &&
        uio->uio_segflg != UIO_USERSPACE)
        return (EFAULT);
    *iov->iov_base = (char)c;
    iov->iov_base = &iov->iov_base[1];
    iov->iov_len--;
    uio->uio_resid--;
    uio->uio_offset++;
    return (0);
}


uiomove(cp, n, uio)
char *cp;
int n;
struct uio *uio;
{
    register struct iovec *iov;
    /* UNSIGNED, as Reno's `u_int cnt` (kern_subr.c:19).  The first cut wrote
     * `int` and did not say so, which was a divergence with a worse failure
     * than Reno's: on a malformed negative length Reno's unsigned compare
     * clamps cnt to n and copies a BOUNDED amount, where a signed cnt skips
     * the copy, then runs `n -= cnt` with cnt negative so n GROWS -- an
     * unbounded walk off the iovec array.  It is also now load-bearing rather
     * than stylistic: iov_len is `unsigned short` and can hold 65535, which a
     * signed 16-bit int cannot represent at all. */
    register unsigned cnt;

    if (uio->uio_rw != UIO_READ && uio->uio_rw != UIO_WRITE)
        kc_panic("uiomove: mode");

    while (n > 0 && uio->uio_resid) {
        iov = uio->uio_iov;
        cnt = iov->iov_len;
        if (cnt == 0) {
            /* `&uio->uio_iov[1]`, NOT `uio->uio_iov + 1`.  Pointer arithmetic
             * has dropped the bank byte in this campaign before, and a uio's
             * iovec array can live in a different bank from this code. */
            uio->uio_iov = &uio->uio_iov[1];
            uio->uio_iovcnt--;
            continue;
        }
        if (cnt > n)
            cnt = n;

        /* UIO_USERSPACE COPIES TOO, and this replaces the EFAULT the head of
         * this file described as waiting on a syscall layer.  apple/fgx#108
         * T3 STAGE 3 IS THAT CALLER: write(2) hands the tty discipline a uio
         * whose iov_base is the calling process's own buffer.
         *
         * Reno splits the two arms because a VAX user pointer names a
         * DIFFERENT ADDRESS SPACE and the copy can fault, so it needs
         * copyin/copyout.  ON FGX IT IS NEITHER.  There is one banked address
         * space; a caller's buffer is a far pointer the kernel already
         * dereferences directly in every read and write op it has
         * (`LDA [_libcTmp2]' in syscall.s is exactly that); and there are no
         * page faults to be safe against.  So copyin and copyout ARE uio_copy
         * here and Reno's two arms coincide.
         *
         * THE FLAG STILL RECORDS WHOSE BUFFER IT IS, which is what it is for.
         * The write path sets USERSPACE honestly rather than claiming
         * SYSSPACE to get past a refusal -- the day this kernel grows a
         * validating copyin, the arm to change is here and the callers already
         * say which kind they are. */
        if (uio->uio_segflg != UIO_SYSSPACE &&
            uio->uio_segflg != UIO_USERSPACE)
            return (EFAULT);

        if (uio->uio_rw == UIO_READ)
            uio_copy(cp, iov->iov_base, cnt);
        else
            uio_copy(iov->iov_base, cp, cnt);

        iov->iov_base = &iov->iov_base[cnt];
        iov->iov_len -= cnt;
        uio->uio_resid -= cnt;
        uio->uio_offset += cnt;
        cp = &cp[cnt];
        n -= cnt;
    }
    return (0);
}
