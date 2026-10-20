/* SPDX-License-Identifier: BSD-2-Clause
 * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the FGX contributors
 * FGX-Provenance: 4.3BSD-Reno kern/vfs_syscalls.c
 *   Ported from kern/vfs_syscalls.c (fchmod, fchown), 4.3BSD-Reno.  Original
 *   work:
 *   Copyright (c) 1989 The Regents of the University of California.
 *   All rights reserved.
 */
/* kern_fsetattr.c -- fchmod(2) and fchown(2) on a vnode file.
 *
 * ONE FUNCTION FOR TWO SYSCALLS, vfs_setattr's shape for chmod and chown one
 * level up: Reno's fchmod (kern/vfs_syscalls.c:1164) and fchown (:1234) are
 * the same lines with a different vattr field set, and VA_UNSET in a field
 * the caller does not mean leaves it alone.
 *
 * WHERE IT LIVES.  Reno's are in vfs_syscalls.c beside chmod and chown, and
 * here those bodies are vfs.mod's vfs_setattr -- but vfs.mod has no room left,
 * so this is ufs.mod's bank, as kern_flock.c is, reached from the far bank
 * through ufs_import.s.  The descriptor lookup and the vnode test before it
 * (Reno's getvnode) are the core bank's _Sys_VnodeFp, where the descriptor
 * table is read; this is the rest.  vattr_null is vfs.mod's, imported.
 */

#include "fsparam.h"
#include "vnode.h"
#include "mount.h"
#include "file.h"

extern void vattr_null();


/* vn_fsetattr -- fchmod(2) and fchown(2) past getvnode.
 *
 * NO VOP_LOCK, for the reason vfs_setattr gives: this port takes no vnode
 * locks, so the pair around VOP_SETATTR has nothing to take.  The credential
 * is vfs_setattr's (char *)0 where Reno passes fp->f_cred: ufs_chmod1 and
 * ufs_chown1 take the caller's ids from kc_curuid/kc_curgid, and answer EPERM
 * as Reno's do.  -1 in either id leaves it alone: VA_UNSET is vnode.h's -1,
 * and ufs_chown1 fills a missing half from the inode, as chown(2)'s does.
 */
int
vn_fsetattr(fp, mode, uid, gid)
register struct file *fp;
int mode;
int uid;
int gid;
{
    struct vattr vattr;
    struct vnode *vp;

    vattr_null(&vattr);
    if (mode != VA_UNSET)
        vattr.va_mode = (unsigned short)(mode & 07777);
    vattr.va_uid = (uid_t)uid;
    vattr.va_gid = (gid_t)gid;
    vp = (struct vnode *)fp->f_data;
    if (vp->v_mount != (struct mount *)0 &&
        (vp->v_mount->mnt_flag & MNT_RDONLY))
        return (EROFS);
    return (VOP_SETATTR(vp, &vattr, (char *)0));
}
