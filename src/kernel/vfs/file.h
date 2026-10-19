/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno sys/file.h
 *   Ported from sys/file.h, 4.3BSD-Reno.  Original work:
 *   Copyright (c) 1982, 1986, 1989 Regents of the University of California.
 *   All rights reserved.
 */
/* file.h -- the open-file table.  UFS 1.2c.
 *
 * THREE TABLES, NOT ONE, and confusing them is the classic Unix mistake:
 *
 *   the DESCRIPTOR   u_ofile[fd] -- per process, an index into nothing; it
 *                    just points at a file struct.  dup(2) copies this.
 *   the FILE         struct file -- SHARED by every descriptor that came from
 *                    one open(2), which is what makes an inherited offset
 *                    inherited.  fork(2) shares these, so f_count is a count
 *                    of DESCRIPTORS, across all processes.
 *   the VNODE        the file itself.  Two independent open(2)s of one path
 *                    are TWO file structs and ONE vnode -- which is why the
 *                    two tables are sized separately below, and why an offset
 *                    lives here rather than in the vnode.
 *
 * Reno keeps the first in the u-area and the second in one global array.  FGX
 * has no u-area for kernel C, so both are carved from the VFS pool arena and
 * indexed by pid, exactly as the nameidata slots are (UFS 1.2b, vfs_subr.c) --
 * see vfs_file.c for why that is a placement change and not a design one.
 *
 *----------------------------------------------------------------------------
 * WHAT IS DELIBERATELY NOT HERE.  These are gaps, not simplifications, and the
 * campaign's rule is to name them rather than let them be rediscovered:
 *
 *   f_cred IS ALWAYS 0, AND THAT IS THE DESIGN RATHER THAN A GAP.  This is
 *   the canonical statement of it; the rest of the VFS points here.
 *
 *   Reno's falloc does `fp->f_cred = u.u_cred; crhold(fp->f_cred);`
 *   (kern_descrip.c:379), because a 4.3BSD credential is a REFCOUNTED OBJECT
 *   that outlives the call: a file holds one, exec copies one (`u.u_cred =
 *   crcopy(cred)`, kern_exec.c:649), and NFS ships one over a wire.
 *
 *   FGX FOLLOWS 2.11BSD HERE, AND 2.11BSD HAS NO `struct ucred' AT ALL -- not
 *   one in its whole kernel.  Its access check is `access(ip, mode)'
 *   (usr/sys/sys/ufs_fio.c:32), taking no credential and reading `u.u_uid'
 *   and `u.u_groups' out of the u-area.  That is FGX's model too: the ids live
 *   in the u-area (U_Ruid/U_Uid/U_Svuid and the gid triple, include/kernel.s)
 *   and the filesystem reads them through kc_curuid/kc_curgid.  A credential
 *   is a property of the RUNNING PROCESS here, not of a file.
 *
 *   This tree is a 2.11BSD system with a Reno VFS in it -- Reno only because
 *   2.11BSD has no vnodes to port -- and the credential falls on that seam.
 *   Taking Reno's side of it would mean a refcounted heap object reached by
 *   pointer from the u-area and passed INTO module banks, which is the hazard
 *   apple/fgx#417 measured.  Nothing here needs a credential that outlives its
 *   caller; when something does, the 2.11BSD answer is `saccess`'s, which
 *   swaps the real ids into the u-area around the call and restores them
 *   (usr/sys/sys/ufs_syscalls.c:383) and needs no such object.
 *
 *   The field stays, carried at Reno's offset so the layout is his, typed
 *   `char *` for the reason namei.h's ni_cred is: the pointer has the right
 *   SIZE and the wrong type stops anything dereferencing it by accident.
 *
 *   f_ops IS THE DISPATCH.  `struct fileops` is below; the `vnops` vector is
 *   in vfs_syscalls.c, and vfs_openat sets `f_ops = &vnops` on the descriptor
 *   open(2) allocated.  read/write, ioctl and select call through
 *   `fp->f_ops` (vfs_syscalls.c), and closef calls fo_close through a guard
 *   for a null f_ops (vfs_file.c).
 *
 *   THE FCB AND THIS TABLE ARE BOTH LIVE.  The core still allocates the
 *   descriptor and its FCB (src/drivers/fs/fcb.s); the `struct file` here is
 *   its mirror, and an open with no mirror entry fails (fcb.s, vfs_openat's
 *   getf).
 */

#ifndef _FGX_FILE_H_
#define _FGX_FILE_H_

#include "fsparam.h"            /* off_t, NFILE, VFS_NPROC, FS_MAX_FDS */

/* THE DESCRIPTOR TYPES ARE DEFINED TWICE, HERE AND IN ASSEMBLY, and the two
 * copies MUST agree: include/fs.s:819-823 carries the same five for the 1.2a
 * dispatch ladder, which is what classifies a live descriptor today.  A silent
 * divergence would route a socket down the vnode arm.
 *
 * tools/gen_vfs_equ.py --check compares the two and fails the build if they
 * disagree, so this comment is not the only thing holding them together.
 *
 * Upstream: DTYPE_VNODE and DTYPE_SOCKET are Reno's (sys/file.h:33); DTYPE_PIPE
 * is 2.11BSD's (usr/sys/h/file.h:74), because Reno has no pipe type at all --
 * it makes pipe(2) a socketpair.  4 and 5 were FGX's console and chardev-switch
 * pseudo-descriptors, both retired: a device is a vnode, as in BSD. */
#define DTYPE_VNODE     1       /* a file or directory -- BSD */
#define DTYPE_SOCKET    2       /* communications endpoint -- BSD */
#define DTYPE_PIPE      3       /* pipe -- 2.11BSD */

/* f_flag.  Reno's sys/file.h:54: FREAD 1, FWRITE 2, and the open(2) mode is
 * converted into them by `fflags = mode - FOPEN` at the open site.
 *
 * THE REST ARRIVE WITH 1.7c, AND THEY COST NO CONVERSION, which is worth
 * stating because it looks like it should.  Reno spells them through <fcntl.h>
 * in octal (sys/file.h:59-65 aliasing O_CREAT 01000, O_TRUNC 02000, O_EXCL
 * 04000, O_APPEND 010) and this tree's userland spells them in hex
 * (toolchain/include/fcntl.h:20-23: 0x0008, 0x0200, 0x0400, 0x0800).  Those
 * are the SAME NUMBERS -- 0x200 is 01000 -- so `fflags = mode - FOPEN` carries
 * a userland open mode into these bits exactly as upstream's does, and no
 * translation table is needed or wanted.  A table would be a second place for
 * the two sets to drift apart.
 *
 * FNDELAY HAS A SETTER NOW -- ioctl(FIONBIO), which vfs_ioctl answers the way
 * Reno's fset does.  It still has no OPEN-TIME spelling: there is no
 * O_NONBLOCK in toolchain/include/fcntl.h, and the bit is carried at Reno's
 * value so that adding one is a change in fcntl.h rather than a renumbering.
 *
 * SETTING IT IS NOT THE SAME AS HONOURING IT.  vn_read passes IO_NDELAY on to
 * VOP_READ, and spec_read drops that ioflag for a VCHR vnode -- it calls
 * spec_chread(vp, uio) and the chardev seam ops carry no flag -- so a
 * character device opened under /dev still blocks.  apple/fgx#310.
 *
 * FSHLOCK AND FEXLOCK ARE flock(2)'s: this file holds a shared or an exclusive
 * advisory lock on its vnode (vn_lock, vfs_vnops.c).  Reno's values, O_SHLOCK
 * 00200 and O_EXLOCK 00400 (sys/fcntl.h:78-79) -- 0x80 and 0x100, clear of
 * FCREAT's 0x200, which is the collision a first cut of this block made. */
#define FREAD           1
#define FWRITE          2
#define FNDELAY         0x0004  /* Reno: O_NONBLOCK.  Set by ioctl(FIONBIO) */

/* FIONBIO, the one ioctl this layer reads rather than forwarding blind.  The
 * VALUE IS USERLAND'S: toolchain/include/sys/ioctl.h defines it 0x667e and
 * include/socket.s carries the same for the legacy road, so all three must
 * agree or a caller's FIONBIO simply falls through as an unknown command. */
#define FIONBIO         0x667e
#define FAPPEND         0x0008  /* Reno: O_APPEND */
#define FCREAT          0x0200  /* Reno: O_CREAT  (01000) */
#define FTRUNC          0x0400  /* Reno: O_TRUNC  (02000) */
#define FEXCL           0x0800  /* Reno: O_EXCL   (04000) */
#define FSHLOCK         0x0080  /* Reno: O_SHLOCK (00200) */
#define FEXLOCK         0x0100  /* Reno: O_EXLOCK (00400) */

/* flock(2)'s operations, Reno sys/fcntl.h:49-52.  toolchain/include/sys/file.h
 * carries the same four for userland. */
#define LOCK_SH         0x01    /* shared file lock */
#define LOCK_EX         0x02    /* exclusive file lock */
#define LOCK_NB         0x04    /* don't block when locking */
#define LOCK_UN         0x08    /* unlock file */

/* THE FLAGS AN OPEN DESCRIPTOR KEEPS.  Reno sys/file.h:68 is
 *
 *     #define FMASK  (FREAD|FWRITE|O_APPEND|O_ASYNC|O_NONBLOCK)
 *
 * and kern/vfs_syscalls.c:578 is `fp->f_flag = fmode & FMASK'.  This port
 * masked to (FREAD|FWRITE) alone until 2026-09-05, which dropped FAPPEND at
 * the open and made vn_write's `if (vp->v_type == VREG && (fp->f_flag &
 * FAPPEND))' unreachable -- so O_APPEND was accepted, carried through
 * vn_open, and silently discarded one line later.  `echo B >> f' wrote at
 * offset 0, and so did fopen(path, "a").
 *
 * O_ASYNC is not here because FGX has no SIGIO-on-descriptor.  FNDELAY is
 * Reno's O_NONBLOCK and is carried at Reno's position even though
 * toolchain/include/fcntl.h defines no O_NONBLOCK for a caller to pass --
 * matching upstream's set costs nothing and the alternative is a mask that
 * has to be revisited the day the flag gets a spelling. */
#define FMASK           (FREAD | FWRITE | FAPPEND | FNDELAY)

/* UF_EXCLOSE, close-on-exec: the one descriptor flag, kept per descriptor in
 * pofile_pool (vfs_file.c) as Reno keeps it in u.u_pofile (sys/user.h:83). */
#define UF_EXCLOSE      0x01

/* lseek(2) whences.  Reno's sys/file.h:L_SET/L_INCR/L_XTND, and they agree
 * with this tree's userland spelling for the same reason the open flags above
 * do: toolchain/include/sys/file.h carries the same three names at the same
 * three values, and toolchain/include/unistd.h's SEEK_SET/CUR/END are aliases
 * of them.  One set of numbers, spelled twice, so no translation is wanted --
 * a mapping table would be a second place for them to drift.
 *
 * BSD's spelling rather than POSIX's is used HERE because this is the kernel
 * side and vfs_lseek is a port of Reno's lseek; a reader with that file open
 * should see the same three tokens. */
#define L_SET           0       /* absolute */
#define L_INCR          1       /* relative to the current offset */
#define L_XTND          2       /* relative to the end of the file */

/* struct fileops -- what a descriptor can be asked to do, independent of WHAT
 * it names.  Reno declares it inline inside struct file (sys/file.h:44-50);
 * it is hoisted out here only so `struct file`'s f_ops field can be typed,
 * which is the same declaration in a different order and not a divergence.
 *
 * SLOT ORDER IS RENO'S AND ALL FIVE ARE CARRIED.  vfsops.h drops five of
 * Reno's ten vfsops slots because FGX has no notion of quotas or NFS file
 * handles -- there is nothing those could ever dispatch to.  That argument
 * does NOT apply here: ioctl(2) and select(2) are live FGX syscalls with real
 * implementations today, reached through a different route.  A dropped slot
 * would have to be re-inserted at I2 when every fd operation starts
 * dispatching through this vector, and re-inserting into a table means
 * renumbering one that other code already indexes.
 *
 * THE ARGUMENT LISTS ARE NOT RENO'S, AND THE DIFFERENCE IS cred.  Reno passes
 * `struct ucred *` to fo_read/fo_write/fo_select; this kernel has no ucred by
 * design (see f_cred above), so those arguments are dropped rather than passed
 * as a null nothing may dereference.  They are not owed back: 2.11BSD's own
 * read and write take no credential either, the ids being the running
 * process's and reachable from anywhere in the kernel. */
struct fileops {
    int (*fo_read)();           /* fp, uio */
    int (*fo_write)();          /* fp, uio */
    int (*fo_ioctl)();          /* fp, com, data */
    int (*fo_select)();         /* fp, which */
    int (*fo_close)();          /* fp */
};

/* struct file -- 24 bytes, and the layout is Reno's field for field.
 *
 * THE SIZE IS PINNED by toolchain/tests/M37/vfslayout.c and by
 * tools/gen_vfs_equ.py's FILE_SIZE, which sizes the arena.  If a field is
 * added here and those are not updated, the last pool carved from the arena
 * runs off the end of the allocation -- heap corruption a long way from the
 * edit that caused it.  The fixture is what stops that being discovered at
 * runtime.
 *
 * f_count IS A REFERENCE COUNT ACROSS ALL PROCESSES, not within one.  A fork
 * doubles it without opening anything, and a slot is free when it reaches
 * zero -- which is why falloc scans for `f_count == 0` rather than keeping a
 * free list.  Reno does the same and for the same reason: the count has to be
 * consulted anyway, so a list would be a second thing to keep true.
 *
 * f_msgcount is Reno's count of references held by messages in flight on a
 * unix-domain socket.  FGX has no such sockets, so it is always 0; it is kept
 * because closef consults it upstream and 1.7's closef should read like the
 * one it came from. */
struct file {
    short   f_flag;             /* FREAD and/or FWRITE */
    short   f_type;             /* DTYPE_* */
    short   f_count;            /* descriptors referencing this, all procs */
    short   f_msgcount;         /* references from a message queue; see above */
    char   *f_cred;             /* Reno: struct ucred *.  Always 0 -- see head */
    struct fileops *f_ops;      /* vnops for a vnode fd; 0 until I2 -- see head */
    char   *f_data;             /* the vnode, socket or pipe this names */
    off_t   f_offset;           /* the seek pointer this open(2) carries */
};

#endif /* _FGX_FILE_H_ */
