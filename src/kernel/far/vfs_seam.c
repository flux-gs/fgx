/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 */
/* FGX-Origin: original -- FGX code.  It CITES BSD but contains none of it.
 */
/* vfs_seam.c -- the inward seam's proof, in C because that is the point.
 * UFS 1.7d.
 *
 * WHY THIS IS C AND NOT ASSEMBLY.  vfs_import.s's shims each state their own
 * precondition -- "entered from C, which left DBR on our bank" -- and the
 * callee on the far side is fcc-compiled C that reads its register file off
 * FGX_DP_KERNELC.  A C caller in this bank satisfies both by construction: the
 * direct page, the register file and the stack discipline are whatever the far
 * bank's own C already runs with, because this IS that C.
 *
 * The first version of this seam was core-bank assembly with a hand-rolled
 * PHD/TCD bracket around the call.  It killed the boot with no output at all,
 * and the three probe gates stayed green while 33 of 34 suite tests could not
 * reach a shell.  Re-implementing the C entry convention by hand is what that
 * bracket was; not doing it is what this file is.
 *
 *----------------------------------------------------------------------------
 * WHAT IT ASSERTS, AND WHY TWO CALLS RATHER THAN ONE.
 *
 * A seam with no caller is a table nothing checks -- the mistake 1.7c declined
 * to make with the fileops vector, and equally available here: the resolve can
 * succeed, every cell can hold a plausible number, and the first real call can
 * still land in the wrong place.
 *
 * So this makes two calls whose answers must DISAGREE.  ndslot(pid, which) is
 * the probe because it discriminates for free: pid 1 slot 0 is a real
 * per-process nameidata slot and must come back NON-NULL, while pid 0 is
 * refused by ndslot's own `pid < 1` guard and must come back NULL.  A shim
 * returning a constant -- null, an errno, or a stray pointer -- fails one of
 * the two.  Asserting only the non-null answer would pass on a seam that
 * returned garbage, which is exactly the failure this is here to catch.
 *
 * It is also the CHEAPEST honest probe: ndslot allocates nothing, writes
 * nothing, and touches no device, so running it on the boot path costs a
 * bounds check and a multiply.
 */

/* The descriptor's shape, from the VFS headers rather than a second copy of
 * it here.  toolchain/tests/M37/vfslayout.c pins every offset at runtime and
 * include/vfs_equ.s carries the same numbers for the assembly, so all three
 * readers of `struct file` follow one authority. */
#include "../vfs/fsparam.h"
#include "../vfs/file.h"
#include "../vfs/uio.h"

extern int   fddup();           /* vfs_file.c -- the lifecycle operations */
extern int   fdmove();
extern int   fdcopy();
extern int   fdfreeall();
extern int   fdrelease();
extern char *ndslot();          /* vfs.mod, through vfs_import.s */
extern char *fdbase();          /* likewise -- the descriptor array, I2b */
extern struct file *getf();     /* likewise -- resolve one descriptor */

/* A distinctive address to hand through f_data and get back.  Its VALUE is
 * the point, not its contents -- nothing dereferences it at this step. */
int vfs_seam_marker;

#define SEAM_OK   1
#define SEAM_BAD  0


/* A fileops nothing in the system can reach, so that the syscall bodies can be
 * driven without a vnode.  See the section in vfs_seam_check that uses it.
 *
 * seam_moved IS HOW MUCH IT PRETENDS TO TRANSFER, and the caller sets it below
 * the amount requested on purpose: a body that reports the request rather than
 * the transfer is invisible to a full one. */
int seam_moved;
struct fileops seam_ops;

int
seam_rw(fp, uio)
struct file *fp;
struct uio  *uio;
{
    uio->uio_resid -= (unsigned short)seam_moved;
    return (0);
}

/* vfs_seam_check -- returns SEAM_OK only if BOTH answers are right.
 *
 * THE RETURN IS A VALUE, NOT A LOG.  Logging from here would need the console,
 * which is core, which is a second far-to-core shim for a diagnostic; the
 * assembly that called us already has one.  It also keeps this function
 * testable by inspection: it has one job and one answer. */
int
vfs_seam_check()
{
    char *bad;
    char *good;

    /* pid 0 is invalid.  ndslot rejects `pid < 1`, so a seam that reaches the
     * real function answers null here -- and a seam that does not reach it
     * answers whatever the shim left in A. */
    bad = ndslot(0, 0);
    if (bad != (char *)0)
        return (SEAM_BAD);

    /* pid 1 slot 0 is a real slot, so this must be a live pointer into the VFS
     * pool arena.  Null here means the call went somewhere, but not there. */
    good = ndslot(1, 0);
    if (good == (char *)0)
        return (SEAM_BAD);

    /* AND THE DESCRIPTOR ARRAY -- UFS 1.7d-I2b.  Asserted the same way and for
     * the same reason: fdbase refuses `pid < 1 || pid > VFS_NPROC` exactly as
     * ndslot does, so pid 0 must be null and pid 1 must not.  A second op
     * through the seam is also the cheapest evidence that the vtable ORDER is
     * right -- one op could be reached by an off-by-one that happened to land
     * somewhere callable, two cannot as easily. */
    if (fdbase(0) != (char *)0)
        return (SEAM_BAD);
    if (fdbase(1) == (char *)0)
        return (SEAM_BAD);

    /* THE DESCRIPTOR SERVICE, ROUND-TRIPPED -- I2b.  kdesc_alloc and
     * kdesc_free are what the core bank's FS layer will call, and a service
     * with no caller is a table nothing checks; this is the caller until
     * fcb.s becomes one.
     *
     * IT RUNS AT BOOT AND MUST LEAVE NOTHING BEHIND.  pid 1 starts with no
     * descriptors, so the array is empty here and the descriptor taken is
     * given back before this returns.  A leak would show up as the shell's stdin arriving on the
     * wrong number, which is a long way from here.
     *
     * THE ASSERTION IS THAT f_data COMES BACK, not that the call returned 0.
     * A kdesc_alloc that allocated a descriptor and dropped the FCB on the
     * floor returns 0 and looks perfect; what catches it is asking getf for
     * the file and finding the pointer we handed in.  `marker` is a distinctive
     * non-null value rather than a real FCB -- nothing dereferences f_data at
     * this step, and using a real one would test the FS layer instead of the
     * service. */
    {
        char        *marker;
        struct file *fp;
        int          fd;

        marker = (char *)&vfs_seam_marker;
        fd = FS_MAX_FDS - 1;    /* the HIGHEST descriptor, deliberately: the
                                 * array is empty here, so 0 would pass on an
                                 * implementation that ignored the argument and
                                 * always used the first slot. */
        if (kdesc_alloc(1, marker, fd) != 0)
            return (SEAM_BAD);

        fp = getf(1, fd);
        if (fp == (struct file *)0)
            return (SEAM_BAD);
        if (fp->f_data != marker)
            return (SEAM_BAD);      /* allocated, but forgot what it names */

        if (kdesc_free(1, fd) != 0)
            return (SEAM_BAD);
        if (getf(1, fd) != (struct file *)0)
            return (SEAM_BAD);      /* freed, but the descriptor still answers */
    }

    /* THE LIFECYCLE OPERATIONS -- I2c, and this is the only thing that can
     * fail if they are wrong.
     *
     * fddup, fdmove, fdcopy and fdfreeall are called from the fd table's five
     * writers, but NOTHING READS the file table yet: the f_type ladder still
     * classifies from FCB_Flags, so a mirror that silently did nothing would
     * pass all 34 suite tests.  It was measured, not assumed -- gutting fdcopy
     * and fdfreeall to `return 0' left the gate green 34/34.  Until the
     * dispatch converts, this is their entire witness, so it asserts the
     * OBSERVABLE DIFFERENCE between each operation and its neighbours rather
     * than that the call returned 0.
     *
     * PID 2 AND PID 3, not pid 1: the seam runs at boot, so every array is
     * empty here, and using two of them is what lets fdcopy be
     * distinguished from a no-op.  Everything taken is given back.
     *
     * dup and move differ in EXACTLY TWO WAYS and both are checked, because
     * either one alone would pass the other's implementation: dup leaves the
     * source live and raises f_count, move clears the source and does not. */
    {
        char        *marker;
        struct file *fp;
        struct file *dup;

        marker = (char *)&vfs_seam_marker;

        /* --- fddup: a second reference to ONE struct file --------------- */
        if (kdesc_alloc(2, marker, 5) != 0)
            return (SEAM_BAD);
        fp = getf(2, 5);
        if (fp == (struct file *)0 || fp->f_count != 1)
            return (SEAM_BAD);
        if (fddup(2, 5, 7) != 0)
            return (SEAM_BAD);
        dup = getf(2, 7);
        if (dup != fp)
            return (SEAM_BAD);      /* a COPY of the struct would fail here */
        if (fp->f_count != 2)
            return (SEAM_BAD);      /* shared, but nobody counted the sharer */
        if (getf(2, 5) != fp)
            return (SEAM_BAD);      /* dup must not disturb the source */

        /* ...and closing one of two references closes neither file. */
        if (fdrelease(2, 7) != 0)
            return (SEAM_BAD);
        if (getf(2, 5) != fp || fp->f_count != 1)
            return (SEAM_BAD);

        /* --- fdmove: the SAME reference, at a different number ---------- */
        if (fdmove(2, 5, 9) != 0)
            return (SEAM_BAD);
        if (getf(2, 9) != fp)
            return (SEAM_BAD);
        if (getf(2, 5) != (struct file *)0)
            return (SEAM_BAD);      /* a move that dup'd would fail here */
        if (fp->f_count != 1)
            return (SEAM_BAD);      /* a move must not add a reference */

        /* --- fdcopy: another PROCESS holding the same files ------------- */
        if (fdcopy(2, 3) != 0)
            return (SEAM_BAD);
        if (getf(3, 9) != fp)
            return (SEAM_BAD);      /* the child did not inherit it */
        if (fp->f_count != 2)
            return (SEAM_BAD);      /* inherited without counting the holder */

        /* --- fdfreeall: and giving a whole process's descriptors back --- */
        if (fdfreeall(3) != 0)
            return (SEAM_BAD);
        if (getf(3, 9) != (struct file *)0)
            return (SEAM_BAD);
        if (getf(2, 9) != fp || fp->f_count != 1)
            return (SEAM_BAD);      /* it freed the OTHER process's too */

        if (fdfreeall(2) != 0)
            return (SEAM_BAD);
        if (getf(2, 9) != (struct file *)0)
            return (SEAM_BAD);
    }


    /* THE SYSCALL BODIES -- restoring what apple/fgx#196 records as owed.
     *
     * vnops_probe's cases 1440-1459 drove vfs_read/vfs_write/vfs_lseek and
     * were removed when I2b moved those bodies from vfs.mod into this bank:
     * ufsprobe.mod reaches the kernel through SYS_KCALL, not through the far
     * bank, so its cases lost their callees.  The issue proposed KSVC service
     * numbers to give them back.  They are not needed -- THIS IS THE SAME BANK
     * the bodies live in, so it can simply call them.
     *
     * WHAT MADE THAT HARD WAS THE VNODE, not the bank.  vfs_read reaches
     * fo_read, and a real fileops would take f_data for a vnode and vrele it;
     * the descriptor round-trip above says so, and is why it stops short of
     * installing f_ops.  A STUB fileops removes the difficulty rather than
     * working around it: seam_ops' fo_read and fo_write touch nothing but the
     * uio, so the bodies can be driven with f_data left as a marker.
     *
     * WHAT THIS COVERS, and it is three of the four arms #196 lists:
     *   - fdcheck's `want' bit (1456): a read-only descriptor must refuse a
     *     write with EBADF;
     *   - rwcommon reporting MOVED and not ASKED (1459);
     *   - the null-f_ops refusal.
     * vfs_lseek's L_XTND (1448) is the fourth and is NOT covered: it needs
     * VOP_GETATTR's va_size, which needs a real vnode, which arrives at I3.
     *
     * THE STUB MOVES LESS THAN ASKED, DELIBERATELY.  This is exactly where the
     * mutation went inert at 1.7c: with a transfer that is always full,
     * `cnt - resid' and `cnt' are the same number and a body reporting the
     * request rather than the transfer passes.  A partial is the only shape
     * that can tell them apart, so the stub always leaves some behind. */
    {
        struct file *fp;
        int          fd;
        int          error;
        int          cnt;
        char        *marker;

        marker = (char *)&vfs_seam_marker;
        fd = FS_MAX_FDS - 2;
        if (kdesc_alloc(1, marker, fd) != 0)
            return (SEAM_BAD);
        fp = getf(1, fd);
        if (fp == (struct file *)0)
            return (SEAM_BAD);

        /* A descriptor with no f_ops is refused, whatever its mode says. */
        fp->f_flag = FREAD | FWRITE;
        fp->f_ops  = (struct fileops *)0;
        cnt = -1;
        if (vfs_read(1, fd, marker, 8, &cnt) != EBADF)
            return (SEAM_BAD);

        /* Now give it the stub.  The assignments are at RUNTIME because a
         * kernel-C global cannot carry an initialised pointer (apple/fgx#88). */
        seam_ops.fo_read   = seam_rw;
        seam_ops.fo_write  = seam_rw;
        seam_ops.fo_ioctl  = 0;
        seam_ops.fo_select = 0;
        seam_ops.fo_close  = 0;
        fp->f_ops = &seam_ops;

        /* THE MODE BIT.  Read-only, so a write must be refused -- and refused
         * by fdcheck rather than by the stub, which would happily "move". */
        fp->f_flag = FREAD;
        seam_moved = 4;
        cnt = -1;
        if (vfs_write(1, fd, marker, 8, &cnt) != EBADF)
            return (SEAM_BAD);
        if (cnt != -1)
            return (SEAM_BAD);      /* refused, but wrote through cntp anyway */

        /* MOVED, NOT ASKED.  8 requested, 4 moved: the two are different
         * numbers only because the stub leaves a remainder. */
        seam_moved = 4;
        cnt = -1;
        error = vfs_read(1, fd, marker, 8, &cnt);
        if (error != 0)
            return (SEAM_BAD);
        if (cnt != 4)
            return (SEAM_BAD);      /* reported the request, not the transfer */

        /* And with the mode bit present, a write goes through the same way. */
        fp->f_flag = FREAD | FWRITE;
        seam_moved = 3;
        cnt = -1;
        if (vfs_write(1, fd, marker, 8, &cnt) != 0)
            return (SEAM_BAD);
        if (cnt != 3)
            return (SEAM_BAD);

        fp->f_ops = (struct fileops *)0;    /* leave nothing behind */
        if (kdesc_free(1, fd) != 0)
            return (SEAM_BAD);
    }

    return (SEAM_OK);
}


/*============================================================================
 * THE DESCRIPTOR SERVICE -- UFS 1.7d I2b.
 *
 * The core bank's descriptor layer (src/drivers/fs/fcb.s) needs to make and
 * retire `struct file`s, and it cannot call vfs.mod: only this bank can.  So
 * the service is here, in C, and the core reaches it through a far export
 * slot -- the same route _KcProbe uses, and the one the seam proved.
 *
 * WHO CHOOSES THE DESCRIPTOR NUMBER: the CORE, and this table follows it.
 * There is one authority, as there has to be -- lowest-free is a contract that
 * dup2 and the shell's redirection both depend on, not an implementation
 * detail -- and the reason it is the core's rather than this one's is that a
 * third writer already exists and knows only about the core's table.  _Fd_Dup
 * (syscall.s:1746) installs an FCB into the fd table directly and never
 * reaches _Fcb_Alloc, so a number free HERE can be live THERE.  See fallocat
 * in vfs_file.c, and kdesc_alloc below, for what that cost when it was the
 * other way round.
 *===========================================================================*/

extern int   fallocat();        /* vfs_file.c: a file struct at a given fd */
extern int   fdrelease();       /* vfs_file.c: fdrelease(pid, fd) */

/* kdesc_alloc -- a `struct file` for descriptor `fd`, with the caller's FCB in
 * it.
 *
 * `fcb` IS THE CORE BANK'S 24-BIT FCB POINTER, carried as the char * fcc gives
 * us, and it goes straight into f_data.  Nothing here dereferences it: the FCB
 * lives in the heap and belongs to the FS layer, and this bank has no business
 * reading it.  Carrying it is the whole of what f_data means at this step --
 * the descriptor becomes a `struct file` whose private data is the FCB, which
 * is what lets the f_type ladder keep working unchanged.
 *
 * THE fd COMES FROM THE CALLER, and that is the opposite of what this function
 * did when it was written.  It called falloc, so the FILE TABLE chose the
 * number -- on the argument that lowest-free is a contract (dup2 and the
 * shell's redirection depend on it) and two scans would agree only by luck.
 * The argument is sound and the conclusion was wrong, because there is a third
 * writer neither scan knows about: _Fd_Dup (syscall.s:1746) installs an FCB
 * directly into the core's fd table and never reaches _Fcb_Alloc.  So the file
 * table can believe a number is free while it is live over there, and it does
 * -- getty dup2s its tty onto 0, after which the next open(2) was handed fd 0
 * and overwrote stdin.  The machine could not start a shell.
 *
 * There is still exactly one authority for the number; it is the core's fd
 * table, until dup, dup2 and file_actions convert too.  See fallocat.
 *
 * Returns 0, or an errno.
 */
int
kdesc_alloc(pid, fcb, fd)
int    pid;
char  *fcb;
int    fd;
{
    struct file *fp;
    int          error;

    error = fallocat(pid, fd, &fp, (int *)0);
    if (error)
        return (error);

    /* fallocat has already wired ofile[fd] -> fp and set f_count to 1.  What
     * it cannot know is what this descriptor NAMES, which is the caller's. */
    fp->f_data = fcb;
    fp->f_type = DTYPE_VNODE;   /* provisional -- I2c's f_ops dispatch is what
                                 * makes the type mean anything.  The f_type
                                 * ladder in the core bank still classifies
                                 * from FCB_Flags, so nothing reads this yet;
                                 * it is set rather than left zero because a
                                 * zero type is not a type. */
    return (0);
}


/* kdesc_free -- retire descriptor `fd` of `pid`.
 *
 * fdrelease clears the descriptor AND drops the file reference, in that order,
 * because the two must not be separable: a descriptor cleared without the
 * closef leaks a struct file that nothing will find again, and a closef
 * without clearing the descriptor leaves a dangling pointer for the next getf
 * to hand out.  vfs_file.c makes exactly that argument.
 *
 * THE FCB IS NOT FREED HERE.  It is the core bank's, allocated by the FS layer
 * from the kernel heap, and freeing it from this side would be this bank
 * reaching into a lifetime it does not own.  The caller frees it, after this.
 */
int
kdesc_free(pid, fd)
int pid;
int fd;
{
    return (fdrelease(pid, fd));
}
