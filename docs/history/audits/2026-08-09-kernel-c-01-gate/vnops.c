/* vnops.c -- the vnode-layer shape, for measurement.
 *
 * Reno dispatches every filesystem operation through a 32-entry vnodeops
 * vector (`struct vnodeops`, vnode.h), reached as (*vp->v_op->vn_xxx)().  The
 * gate needs to know what that indirection costs on a 65816, and what a
 * lifecycle routine's frame looks like, so this is the dispatch plus vget/vput
 * in Reno's shape -- reference counting, a free list, and the flag handling.
 */
#include "fsgate.h"

struct vnode;

struct vnodeops {
    int (*vn_lookup)();  int (*vn_create)();  int (*vn_mknod)();
    int (*vn_open)();    int (*vn_close)();   int (*vn_access)();
    int (*vn_getattr)(); int (*vn_setattr)(); int (*vn_read)();
    int (*vn_write)();   int (*vn_ioctl)();   int (*vn_select)();
    int (*vn_mmap)();    int (*vn_fsync)();   int (*vn_seek)();
    int (*vn_remove)();  int (*vn_link)();    int (*vn_rename)();
    int (*vn_mkdir)();   int (*vn_rmdir)();   int (*vn_symlink)();
    int (*vn_readdir)(); int (*vn_readlink)();int (*vn_abortop)();
    int (*vn_inactive)();int (*vn_reclaim)(); int (*vn_lock)();
    int (*vn_unlock)();  int (*vn_bmap)();    int (*vn_strategy)();
    int (*vn_print)();   int (*vn_islocked)();
};

struct vnode {
    unsigned short   v_flag;
    short            v_usecount;
    short            v_writecount;
    short            v_type;
    struct vnodeops *v_op;
    struct vnode    *v_freef;
    struct vnode    *v_freeb;
    struct inode    *v_data;
};

#define VROOT 0x0001
#define VXLOCK 0x0100

extern struct vnode *vfreeh;
extern struct vnode *vfreet;

/* The dispatch itself: what every VOP_ macro expands to. */
int
vop_bmap(vp, bn, bnp)
struct vnode *vp;
daddr_t bn;
daddr_t *bnp;
{
    return (*vp->v_op->vn_bmap)(vp, bn, bnp);
}

int
vop_read(vp, off, len)
struct vnode *vp;
off_t off;
int len;
{
    return (*vp->v_op->vn_read)(vp, off, len);
}

/* vget: take a reference, pulling the vnode off the free list if idle. */
int
vget(vp)
struct vnode *vp;
{
    if (vp->v_flag & VXLOCK)
        return (1);
    if (vp->v_usecount == 0) {
        if (vp->v_freeb != 0)
            vp->v_freeb->v_freef = vp->v_freef;
        else
            vfreeh = vp->v_freef;
        if (vp->v_freef != 0)
            vp->v_freef->v_freeb = vp->v_freeb;
        else
            vfreet = vp->v_freeb;
        vp->v_freef = 0;
        vp->v_freeb = 0;
    }
    vp->v_usecount = vp->v_usecount + 1;
    return (0);
}

/* vput: drop a reference, returning the vnode to the tail of the free list. */
void
vput(vp)
struct vnode *vp;
{
    vp->v_usecount = vp->v_usecount - 1;
    if (vp->v_usecount > 0)
        return;
    (*vp->v_op->vn_inactive)(vp);
    vp->v_freef = 0;
    vp->v_freeb = vfreet;
    if (vfreet != 0)
        vfreet->v_freef = vp;
    else
        vfreeh = vp;
    vfreet = vp;
}
