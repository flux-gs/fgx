/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/kern_descrip.c
 *   Ported from kern/kern_descrip.c, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* vfs_file.c -- the open-file table and its allocator.  UFS 1.2c.
 *
 * Ported from 4.3BSD-Reno kern/kern_descrip.c (ufalloc, falloc, closef) and
 * 2.11BSD usr/sys/sys/kern_descrip.c (getf, which Reno writes inline at every
 * call site instead of factoring out).  See file.h for what the three tables
 * are and which of them this file owns.
 *
 * THE ONE STRUCTURAL DEPARTURE, AND IT IS PLACEMENT RATHER THAN DESIGN.
 * Reno's descriptor array is `u.u_ofile[]` -- in the u-area, so "this process"
 * is implicit in every reference and the functions take no pid.  Kernel C here
 * has no u-area: it runs on FGX_DP_KERNELC with fcc's register file where the
 * u-area's offsets would be, and _curTask is a kernel direct-page cell reached
 * through a service call (kc_sys.s).  So the array is carved from the VFS pool
 * arena and indexed by pid, and every function below takes the pid Reno takes
 * implicitly.  UFS 1.2b's nameidata slots made exactly this move for exactly
 * this reason (vfs_subr.c's ndslot/ndget), and this follows it deliberately --
 * a second shape for per-process VFS storage would be one more thing to keep
 * true.
 *
 * WHAT THAT COSTS, stated rather than discovered: a caller can pass a pid that
 * is not its own and get another process's descriptors.  ndslot carries the
 * same hazard and answers it the same way -- ndget is the interface real
 * callers use and asks kc_curpid itself.  fdcurrent() below is that interface
 * here, and the pid-taking forms exist because the arithmetic and the "who am
 * I" question fail for different reasons and a probe cannot exercise the first
 * through a function that demands the second (there is no current process on
 * the boot path).
 */

#include "fsparam.h"
#include "file.h"

extern int kc_curpid();
extern int vn_unlock();         /* kern_flock.c, in ufs.mod, via ufs_import.s */

/* The two tables, carved from the VFS pool arena by finit.  UNINITIALISED
 * POINTERS ON PURPOSE: kernel C cannot hold an initialised pointer-to-data
 * global (apple/fgx#88), which is the same reason nd_pool and nd_bufs are
 * declared this way in vfs_subr.c. */
struct file  *file_pool;        /* NFILE shared open-file structs */
struct file **ofile_pool;       /* VFS_NPROC * FS_MAX_FDS descriptors */
char         *pofile_pool;      /* VFS_NPROC * FS_MAX_FDS descriptor flags */

/* Reno's rotating allocation cursor (kern_descrip.c:350, `struct file *lastf`).
 *
 * IT IS A HINT, NOT A FREE LIST, and the distinction is the reason falloc
 * scans twice below.  Starting each search where the last one stopped turns
 * the common case -- open, open, open -- from a scan of the whole table into a
 * single step, without anything having to be kept true when a slot is freed.
 * A free list would be faster still and would be a second structure that
 * closef, fork and exit would each have to maintain correctly. */
struct file *lastf;


/* finit -- carve the file table and the per-process descriptor arrays.
 *
 * Fourth link in vfs_init's chain, and like the other three it returns the
 * first byte after its own carve so that exactly ONE place knows how big this
 * pool is.  tools/gen_vfs_equ.py computes the same sum for the assembly that
 * allocates the arena; if the two disagree the last pool runs off the end of
 * the allocation, which is heap corruption a long way from the edit.
 *
 * EVERYTHING STARTS ZEROED, and that is load-bearing rather than tidy: falloc
 * finds a slot by `f_count == 0` and ufalloc finds a descriptor by a null
 * pointer, so a pool that arrived dirty would hand out a slot that is already
 * in use.  The arena is heap and heap is not guaranteed zero.
 */
char *
finit(arena)
char *arena;
{
    register int i;
    register int n;

    file_pool = (struct file *)arena;
    for (i = 0; i < NFILE; i++) {
        file_pool[i].f_flag = 0;
        file_pool[i].f_type = 0;
        file_pool[i].f_count = 0;
        file_pool[i].f_msgcount = 0;
        file_pool[i].f_cred = (char *)0;
        file_pool[i].f_ops = (struct fileops *)0;
        file_pool[i].f_data = (char *)0;
        file_pool[i].f_offset = 0;
    }
    lastf = &file_pool[0];

    /* `&file_pool[NFILE]`, NOT `file_pool + NFILE`.  Pointer arithmetic has
     * dropped the bank byte in this campaign before, and the arena is in a
     * different bank from this code BY DESIGN -- the same note vntblinit and
     * ndinit both carry. */
    ofile_pool = (struct file **)&file_pool[NFILE];
    n = VFS_NPROC * FS_MAX_FDS;
    for (i = 0; i < n; i++)
        ofile_pool[i] = (struct file *)0;

    /* Reno's u_pofile, one flag byte per descriptor, carved after the
     * descriptor arrays and indexed the same way. */
    pofile_pool = (char *)&ofile_pool[n];
    for (i = 0; i < n; i++)
        pofile_pool[i] = 0;

    return (&pofile_pool[n]);
}


/* fdbase -- process `pid`'s descriptor array, or 0 if there is no such pid.
 *
 * PIDS ARE 1-BASED and the array is not, which is the off-by-one this function
 * exists to have in exactly one place.  ndslot makes the same check the same
 * way (`pid < 1 || pid > VFS_NPROC`).
 */
struct file **
fdbase(pid)
int pid;
{
    if (ofile_pool == (struct file **)0)
        return ((struct file **)0);
    if (pid < 1 || pid > VFS_NPROC)
        return ((struct file **)0);
    return (&ofile_pool[(pid - 1) * FS_MAX_FDS]);
}


/* fdcurrent -- the running process's descriptor array.
 *
 * The interface real callers use, exactly as ndget is for nameidata slots.
 * Returns 0 when there is no current process, which is the boot path: a caller
 * there has no descriptors and must be told so rather than handed slot 0's.
 */
struct file **
fdcurrent()
{
    return (fdbase(kc_curpid()));
}


/* pobase -- process `pid`'s descriptor FLAGS, Reno's `u.u_pofile[]`, or 0.
 *
 * One byte per descriptor, beside the descriptor array fdbase answers for and
 * indexed identically.  The only flag is UF_EXCLOSE, close-on-exec (Reno
 * sys/user.h:83), which fcntl(F_SETFD) and ioctl(FIOCLEX) set and exec reads --
 * all three in the core bank, which addresses these bytes itself (_Fd_Pop,
 * src/drivers/fs/fcb.s) at VFS_POFILE_OFF past ofile_pool.
 * Every writer of a descriptor slot below writes its flag byte too, as Reno's
 * do: a new descriptor starts with the bit clear (ufalloc's `u.u_pofile[i] =
 * 0', dupit's `*pop &~ UF_EXCLOSE'), fork copies it with the u-area, and a
 * closed one has nothing to carry.
 */
static char *
pobase(pid)
int pid;
{
    if (fdbase(pid) == (struct file **)0)
        return ((char *)0);
    return (&pofile_pool[(pid - 1) * FS_MAX_FDS]);
}


/* ufalloc -- lowest free descriptor >= want, for `pid`.
 *
 * Reno's kern_descrip.c:320, less the u_pofile and u_lastfile bookkeeping.
 * u_lastfile is a scan-limit hint this tree does not keep.  u_pofile's clear is
 * made where the slot is written instead -- fallocat below -- because the core
 * bank chooses descriptor numbers and this table mirrors them, so a number
 * found here is not the one that gets filled.
 *
 * LOWEST-FREE IS THE CONTRACT, not an implementation detail: dup2 and the
 * shell's redirection both depend on open(2) returning the smallest free
 * number, which is why this is a scan from `want` rather than a cursor like
 * falloc's.  A rotating hint here would be observably wrong.
 */
int
ufalloc(pid, want, result)
int pid;
int want;
int *result;
{
    register struct file **fdp;
    register int i;

    fdp = fdbase(pid);
    if (fdp == (struct file **)0)
        return (EINVAL);
    for (i = want; i < FS_MAX_FDS; i++) {
        if (fdp[i] == (struct file *)0) {
            *result = i;
            return (0);
        }
    }
    return (EMFILE);
}


/* falloc -- a descriptor AND a file struct, wired together.
 *
 * Reno's kern_descrip.c:357.  The two-pass scan is his and is not defensive
 * padding: the cursor divides the table into "after lastf" and "before lastf",
 * and both halves have to be searched before the table is genuinely full, or a
 * long-lived slot near the end would make every later open report ENFILE with
 * the table half empty.
 *
 * THE DESCRIPTOR IS TAKEN FIRST, and the order matters.  If the file table is
 * full, this returns having touched nothing -- the descriptor is still null,
 * because it is only written at `slot:` once a struct is certain.  The reverse
 * order would need the struct handed back on the EMFILE path, which is the
 * kind of unwind that gets forgotten.
 *
 * f_cred IS NOT SET, AND NOTHING WILL SET IT.  Reno does `fp->f_cred =
 * u.u_cred; crhold(fp->f_cred);` here because a 4.3BSD credential outlives the
 * call that made it; this kernel follows 2.11BSD, where a credential is a
 * property of the running process and lives in the u-area.  file.h's f_cred
 * note is the canonical statement.
 */
int
falloc(pid, resultfp, resultfd)
int pid;
struct file **resultfp;
int *resultfd;
{
    int error;
    int i;

    if (file_pool == (struct file *)0)
        return (EINVAL);
    error = ufalloc(pid, 0, &i);
    if (error)
        return (error);
    return (fallocat(pid, i, resultfp, resultfd));
}


/* fallocat -- a file struct for descriptor `fd' of `pid', where the CALLER has
 * already chosen fd.  UFS 1.7d I2b.
 *
 * This is the second half of Reno's falloc, lifted out whole: upstream calls
 * ufalloc and then scans the file table, and falloc above is now exactly those
 * two calls.  Nothing moved, so the rotating-cursor behaviour and the field
 * initialisation are unchanged; they simply have a second entry point.
 *
 * WHY A SECOND ENTRY POINT AT ALL, and it is worth stating because upstream
 * needs none.  During the descriptor conversion FGX has TWO descriptor tables
 * -- the core bank's fd table, which every existing caller reads, and this one
 * -- and only ONE of them can decide which numbers are free.  The core's is
 * that one, because dup(2) is already written against it: _Fd_Dup
 * (syscall.s:1746) installs an FCB straight into the fd table and never
 * reaches _Fcb_Alloc, so a number this table believes is free can be live over
 * there.  Measured, not assumed -- a dup2 onto 0 in getty's tty setup made the
 * next open(2) hand out fd 0 and overwrite stdin, and the machine could not
 * start a shell.
 *
 * So this table MIRRORS the core's rather than deciding for it, and the mirror
 * direction is what makes the conversion incremental: every open still gets a
 * `struct file', which is what the f_ops dispatch (I2c) needs, without dup,
 * dup2 and posix_spawn's file_actions all having to convert in the same
 * commit.  When they do, falloc above becomes the only caller again and this
 * one goes away.
 *
 * AN OCCUPIED SLOT IS CLEARED, NOT REFUSED.  The core's table says this fd is
 * free; a `struct file' still sitting here is therefore stale -- it belongs to
 * a descriptor that went away through one of the paths that does not reach
 * _Fcb_Free yet.  Refusing would deny a legitimate open on the strength of the
 * table that is NOT authoritative, and leaving it would leak the struct.  This
 * is a property of the transitional mirror and goes away with it.
 */
int
fallocat(pid, fd, resultfp, resultfd)
int pid;
int fd;
struct file **resultfp;
int *resultfd;
{
    register struct file *fp;
    register struct file **fdp;

    if (file_pool == (struct file *)0)
        return (EINVAL);
    if (fd < 0 || fd >= FS_MAX_FDS)
        return (EBADF);
    fdp = fdbase(pid);
    if (fdp == (struct file **)0)
        return (EBADF);
    if (fdp[fd] != (struct file *)0)
        (void) fdrelease(pid, fd);      /* stale -- see the note above */

    for (fp = lastf; fp < &file_pool[NFILE]; fp++)
        if (fp->f_count == 0)
            goto slot;
    for (fp = &file_pool[0]; fp < lastf; fp++)
        if (fp->f_count == 0)
            goto slot;
    return (ENFILE);

slot:
    fdp[fd] = fp;
    pobase(pid)[fd] = 0;
    fp->f_count = 1;
    fp->f_flag = 0;
    fp->f_type = 0;
    fp->f_msgcount = 0;
    fp->f_data = (char *)0;
    fp->f_offset = 0;
    fp->f_cred = (char *)0;
    fp->f_ops = (struct fileops *)0;
    lastf = &fp[1];
    if (resultfp)
        *resultfp = fp;
    if (resultfd)
        *resultfd = fd;
    return (0);
}


/* getf -- the file struct descriptor `fd` of `pid` names, or 0.
 *
 * 2.11BSD's kern_descrip.c:331, which Reno writes inline at each call site as
 * `if ((unsigned)uap->fdes >= NOFILE || (fp = u.u_ofile[uap->fdes]) == NULL)`.
 * Factored out here because there is no u-area to make the inline form short.
 *
 * 2.11BSD sets u.u_error = EBADF and returns NULL; there is no u_error here,
 * so the null return IS the error and the caller supplies EBADF.  Stated
 * because a caller that forgets will fault rather than return a code.
 *
 * THE UNSIGNED CAST IS THE NEGATIVE CHECK.  `(unsigned)fd >= FS_MAX_FDS` is
 * one comparison where `fd < 0 || fd >= FS_MAX_FDS` is two, and dropping it
 * lets fd = -1 index behind the array.  It is written out longhand here rather
 * than cast, because fcc's int is 16 bits and the cast idiom is easy to read
 * past.
 */
struct file *
getf(pid, fd)
int pid;
int fd;
{
    register struct file **fdp;

    if (fd < 0 || fd >= FS_MAX_FDS)
        return ((struct file *)0);
    fdp = fdbase(pid);
    if (fdp == (struct file **)0)
        return ((struct file *)0);
    return (fdp[fd]);
}


/* closef -- drop one reference to a file struct.
 *
 * Reno's kern_descrip.c:394.  THE COUNT IS ACROSS ALL PROCESSES, so this is
 * not "process pid is done with it" -- it is "one descriptor somewhere is
 * gone".  Only the last one closes anything.
 *
 * THE fo_close CALL ARRIVED WITH 1.7d and is the first thing in this tree to
 * dispatch through `f_ops`.  The note that used to be here said there was no
 * fileops vector and that a null f_ops would fault; the vector exists now
 * (vfs_vnops.c) and the fault is what the guard below is for, because the null
 * case did not go away -- it just stopped being universal.
 *
 * `crfree(fp->f_cred)` IS ABSENT AND HAS NOTHING TO FREE: there is no ucred
 * and no refcount, the ids being the process's own.  file.h says why.
 *
 * Reno panics on `f_count < 1`.  Returning EINVAL instead is deliberate: this
 * is reachable from a probe before there is a console to panic to, and a
 * double close should be diagnosable rather than fatal on a machine whose
 * whole file table is still under construction.
 */
int
closef(fp)
struct file *fp;
{
    int error;

    if (fp == (struct file *)0)
        return (0);
    if (fp->f_count > 1) {
        fp->f_count--;
        return (0);
    }
    if (fp->f_count < 1)
        return (EINVAL);

    /* A flock(2) lock goes with the last reference: 2.11BSD's closef
     * (kern_descrip.c:359), `if ((fp->f_flag & (FSHLOCK|FEXLOCK)) &&
     * fp->f_type == DTYPE_INODE) ino_unlock(fp, FSHLOCK|FEXLOCK)'.  Reno does
     * it in vn_close, which is vfs.mod's and full. */
    if ((fp->f_flag & (FSHLOCK|FEXLOCK)) && fp->f_type == DTYPE_VNODE)
        (void) vn_unlock(fp, FSHLOCK|FEXLOCK);

    /* THE fo_close CALL IS UPSTREAM'S (kern_descrip.c: `error =
     * (*fp->f_ops->fo_close)(fp)`) AND IT IS GUARDED, WHICH UPSTREAM'S IS NOT.
     *
     * Reno can dereference f_ops unconditionally because every descriptor it
     * can reach has one -- falloc's callers set it before the struct is
     * visible.  Here the file table is shared with descriptor types that do
     * not have a vector yet: until the descriptor conversion (plan I2), only
     * a vnode open installs `vnops` and console/pipe/socket/chardev fds still
     * route through the f_type ladder with f_ops left null.  An unguarded call
     * would be a JSL through zero on the first close of any of them.
     *
     * THE SLOT IS TESTED, NOT JUST THE TABLE, and that is UFS 1.7d I2c's
     * doing rather than caution.  Every descriptor has an f_ops now, but the
     * legacy ones are CORE-BANK tables holding CORE-BANK routines, and this is
     * the far bank: a pile call into an assembly arm that ends SEC/RTS would
     * return into this frame with a byte missing.  Testing only the table
     * turned every close of a descriptor select had touched into a call
     * through a null -- which is exactly what it did, and it took the socket
     * tests with it while the rest of the suite stayed green.
     *
     * SO fo_close IS THE ONE SLOT A LEGACY TABLE MUST LEAVE NULL, permanently,
     * for as long as closef is its caller.  The core's own close dispatch
     * (Fs_Close's @fc_opsTbl) is where a legacy type's teardown lives, and it
     * is core code calling core code.  What fills this slot is a VNODE, whose
     * ops are C in vfs.mod -- which is what "closef's fo_close becomes
     * vnode-only" means.  The guard stops being a guard when the only
     * descriptors reaching it are vnodes. */
    if (fp->f_ops != (struct fileops *)0 &&
        fp->f_ops->fo_close != 0)
        error = (*fp->f_ops->fo_close)(fp);
    else
        error = 0;

    /* THE STRUCT IS RELEASED WHETHER OR NOT fo_close SUCCEEDED, and Reno does
     * the same (it assigns f_count = 0 after taking the error, and returns the
     * error rather than acting on it).  A close that reports an error has
     * still closed: leaving the slot allocated on an error path would leak a
     * file struct on exactly the runs least able to afford it. */
    fp->f_count = 0;
    fp->f_data = (char *)0;
    fp->f_ops = (struct fileops *)0;
    fp->f_type = 0;
    fp->f_flag = 0;
    fp->f_offset = 0;
    return (error);
}


/* fddup -- make `newfd` name what `oldfd` names.  UFS 1.7d I2c.
 *
 * Reno's dup(2) (kern_descrip.c, `dupit'): `u.u_ofile[new] = fp; fp->f_count++'
 * -- the descriptor is a second reference to the SAME file struct, which is
 * why dup'd descriptors share a file offset and a close of one does not close
 * the other.  That sharing is the whole observable point of dup.
 *
 * THE DESTINATION IS EXPECTED FREE.  Both callers close it first: _Sys_Dup2
 * (syscall.s) routes through Fs_Close rather than _Fcb_Free precisely so the
 * socket, pipe and chardev teardowns run (apple/fgx#134), and
 * _Sys_ApplyFdActions does the same.  A survivor here is therefore stale, and
 * is released rather than leaked -- the same argument fallocat makes.
 */
int
fddup(pid, oldfd, newfd)
int pid;
int oldfd;
int newfd;
{
    register struct file **fdp;
    register struct file *fp;

    if (oldfd < 0 || oldfd >= FS_MAX_FDS)
        return (EBADF);
    if (newfd < 0 || newfd >= FS_MAX_FDS)
        return (EBADF);
    fdp = fdbase(pid);
    if (fdp == (struct file **)0)
        return (EBADF);
    if (oldfd == newfd)
        return (0);
    fp = fdp[oldfd];
    if (fp == (struct file *)0)
        return (EBADF);
    if (fdp[newfd] != (struct file *)0)
        (void) fdrelease(pid, newfd);   /* stale -- see the note above */
    fdp[newfd] = fp;
    pobase(pid)[newfd] = 0;             /* dupit: `*pop &~ UF_EXCLOSE' */
    fp->f_count++;
    return (0);
}


/* fdmove -- rename descriptor `oldfd` to `newfd`.  UFS 1.7d I2c.
 *
 * NOT a dup: the reference moves rather than multiplying, so f_count is
 * untouched and the source is cleared.  posix_spawn's file_actions needs it
 * (src/kernel/process.s, the @afa move case) to shuffle a child's descriptors
 * into place before exec, and the fd table has always done exactly this --
 * copy three bytes, zero the source.  This is that, one table over.
 *
 * BSD has no counterpart because it has no file_actions: 4.3BSD spawns by
 * fork-and-fiddle in the child, where the shuffling is ordinary dup2 and
 * close(2) calls made BY the child.  FGX applies them from the parent, which
 * is also why the pid here cannot be the current task -- see _Fcb_OwnerPid.
 */
int
fdmove(pid, oldfd, newfd)
int pid;
int oldfd;
int newfd;
{
    register struct file **fdp;

    if (oldfd < 0 || oldfd >= FS_MAX_FDS)
        return (EBADF);
    if (newfd < 0 || newfd >= FS_MAX_FDS)
        return (EBADF);
    fdp = fdbase(pid);
    if (fdp == (struct file **)0)
        return (EBADF);
    if (oldfd == newfd)
        return (0);
    if (fdp[newfd] != (struct file *)0)
        (void) fdrelease(pid, newfd);
    fdp[newfd] = fdp[oldfd];
    fdp[oldfd] = (struct file *)0;
    pobase(pid)[newfd] = 0;             /* dup2 then close, as the child would */
    pobase(pid)[oldfd] = 0;
    return (0);
}


/* fdcopy -- give `topid` the descriptors `frompid` holds.  UFS 1.7d I2b.
 *
 * Reno has no function for this because fork gets half of it for free: procdup
 * copies the whole u-area, and u_ofile[] rides along.  All kern_fork.c:264
 * then has to do is the reference bump, under the comment "Increase reference
 * counts on shared objects":
 *
 *     for (n = 0; n <= u.u_lastfile; n++) {
 *         fp = u.u_ofile[n];
 *         if (fp == NULL)
 *             continue;
 *         fp->f_count++;
 *     }
 *
 * The array here is indexed by pid instead of living in a u-area (see the file
 * header), so the copy procdup did implicitly has to be written out; the bump
 * is upstream's, unchanged.
 *
 * THE TWO HALVES ARE ONE FUNCTION because they must not be separable.  A copy
 * without the bump hands two processes descriptors that share one reference,
 * and the first exit to run closes files the survivor still holds -- which
 * surfaces as the other process's reads failing, a long way from fork.
 *
 * THE COUNTERPART IS ALREADY CORRECT: closef decrements while f_count > 1 and
 * only the last reference closes anything, so the child's exit-time fdrelease
 * drops a reference rather than the file.
 *
 * The destination is expected EMPTY -- a pid's descriptors are released when
 * its fd table is freed (fdfreeall below) -- and a non-null slot here is
 * therefore a leak upstream rather than a case to handle.  It is not silently
 * closed: papering over it at this end would hide the bug and keep the count
 * wrong anyway.
 */
int
fdcopy(frompid, topid)
int frompid;
int topid;
{
    register struct file **src;
    register struct file **dst;
    register struct file *fp;
    register int i;

    src = fdbase(frompid);
    if (src == (struct file **)0)
        return (EINVAL);
    dst = fdbase(topid);
    if (dst == (struct file **)0)
        return (EINVAL);
    if (src == dst)
        return (0);

    for (i = 0; i < FS_MAX_FDS; i++) {
        fp = src[i];
        dst[i] = fp;
        pobase(topid)[i] = pobase(frompid)[i];  /* u_pofile rides the u-area */
        if (fp != (struct file *)0)
            fp->f_count++;
    }
    return (0);
}


/* fdfreeall -- release every descriptor `pid` holds.  UFS 1.7d I2b.
 *
 * Reno's exit1 (kern_exit.c:106), which clears the slot and then closes:
 *
 *     for (i = 0; i <= u.u_lastfile; i++) {
 *         f = u.u_ofile[i];
 *         if (f) {
 *             u.u_ofile[i] = NULL;
 *             u.u_pofile[i] = 0;
 *             (void) closef(f);
 *         }
 *     }
 *
 * -- which is fdrelease per descriptor, so that is what this calls, and
 * fdrelease clears the flag byte with the slot.
 *
 * ERRORS ARE DISCARDED, exactly as upstream's `(void) closef` discards them.
 * EBADF is the ORDINARY answer here rather than a failure: at a normal exit
 * the core bank's _Sys_CloseAllFds has already closed every slot one at a
 * time, so this runs over an array that is already null and does nothing.  The
 * path it exists for is the FAILED-SPAWN ROLLBACK, which reaches Task_Free
 * without ever calling _Sys_CloseAllFds -- the same asymmetry that made
 * _Fcb_DropRefs necessary for the FCBs one layer up, and it leaks file structs
 * here for the same reason.  NFILE is 32 and an execvp-style $PATH search
 * spawns and fails several times per command, so the leak is measured in
 * seconds of uptime, not days.
 */
int
fdfreeall(pid)
int pid;
{
    register struct file **fdp;
    register int i;

    fdp = fdbase(pid);
    if (fdp == (struct file **)0)
        return (EINVAL);
    for (i = 0; i < FS_MAX_FDS; i++)
        if (fdp[i] != (struct file *)0)
            (void) fdrelease(pid, i);
    return (0);
}


/* fdrelease -- give up descriptor `fd` of `pid`, dropping its file reference.
 *
 * Reno spells this inline in close(2) as `u.u_ofile[fd] = NULL` followed by
 * closef.  It is one function here because the two halves must not be
 * separable: a descriptor cleared without the closef leaks a file struct that
 * nothing will ever find again, and a closef without clearing the descriptor
 * leaves a dangling pointer that the next getf hands out.
 */
int
fdrelease(pid, fd)
int pid;
int fd;
{
    register struct file **fdp;
    register struct file *fp;

    if (fd < 0 || fd >= FS_MAX_FDS)
        return (EBADF);
    fdp = fdbase(pid);
    if (fdp == (struct file **)0)
        return (EBADF);
    fp = fdp[fd];
    if (fp == (struct file *)0)
        return (EBADF);
    fdp[fd] = (struct file *)0;
    pobase(pid)[fd] = 0;
    return (closef(fp));
}
