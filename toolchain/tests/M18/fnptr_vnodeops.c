/* fnptr_vnodeops: a 32-slot struct of function pointers, statically
 * initialised, dispatched through a pointer-to-struct.  This is 4.3BSD-Reno's
 * `struct vnodeops` verbatim in shape (sys/vnode.h), and the filesystem
 * campaign's entire VFS dispatch rides on it: every operation is
 * `(*vp->v_op->vn_x)(...)`.
 *
 * Existing coverage stops short of this.  M18's fnptr_tyarr covers ARRAYS of
 * fn-ptrs, and m18_fnptr covers a TWO-field struct; neither reaches the two
 * properties that matter here:
 *
 *   1. Field offsets past 120 bytes.  At 4 bytes per far pointer, slot 31 sits
 *      at offset 124 -- well beyond anything the existing fixtures exercise,
 *      and field-offset arithmetic on fn-ptr members is a recorded fcc defect
 *      family (struct-fnptr field promote drift, far-fnptr in a data
 *      initialiser).
 *   2. Two levels of indirection at the call site.  Not `tbl[i]()` but
 *      `p->ops->slot()`, which is how every VOP call is written.
 *
 * The test discriminates rather than merely exercising: each slot returns its
 * own index, so a call that lands on the wrong slot returns the wrong number.
 * Low, middle and high slots are all called, and the expected total is the sum
 * of exactly those indices -- offset drift anywhere in the table changes it.
 * -> 42.
 */

struct vnodeops {
    int (*vn_lookup)();  int (*vn_create)();   int (*vn_mknod)();
    int (*vn_open)();    int (*vn_close)();    int (*vn_access)();
    int (*vn_getattr)(); int (*vn_setattr)();  int (*vn_read)();
    int (*vn_write)();   int (*vn_ioctl)();    int (*vn_select)();
    int (*vn_mmap)();    int (*vn_fsync)();    int (*vn_seek)();
    int (*vn_remove)();  int (*vn_link)();     int (*vn_rename)();
    int (*vn_mkdir)();   int (*vn_rmdir)();    int (*vn_symlink)();
    int (*vn_readdir)(); int (*vn_readlink)(); int (*vn_abortop)();
    int (*vn_inactive)();int (*vn_reclaim)();  int (*vn_lock)();
    int (*vn_unlock)();  int (*vn_bmap)();     int (*vn_strategy)();
    int (*vn_print)();   int (*vn_islocked)();
};

/* Each slot answers with its own index, so a misdispatch is visible as a
 * wrong VALUE rather than as a crash. */
static int s0()  { return 0;  }   static int s1()  { return 1;  }
static int s2()  { return 2;  }   static int s3()  { return 3;  }
static int s4()  { return 4;  }   static int s5()  { return 5;  }
static int s6()  { return 6;  }   static int s7()  { return 7;  }
static int s8()  { return 8;  }   static int s9()  { return 9;  }
static int s10() { return 10; }   static int s11() { return 11; }
static int s12() { return 12; }   static int s13() { return 13; }
static int s14() { return 14; }   static int s15() { return 15; }
static int s16() { return 16; }   static int s17() { return 17; }
static int s18() { return 18; }   static int s19() { return 19; }
static int s20() { return 20; }   static int s21() { return 21; }
static int s22() { return 22; }   static int s23() { return 23; }
static int s24() { return 24; }   static int s25() { return 25; }
static int s26() { return 26; }   static int s27() { return 27; }
static int s28() { return 28; }   static int s29() { return 29; }
static int s30() { return 30; }   static int s31() { return 31; }

/* The static initialiser: the far-fnptr-in-data-initialiser construct. */
struct vnodeops ufs_vnodeops = {
    s0,  s1,  s2,  s3,  s4,  s5,  s6,  s7,
    s8,  s9,  s10, s11, s12, s13, s14, s15,
    s16, s17, s18, s19, s20, s21, s22, s23,
    s24, s25, s26, s27, s28, s29, s30, s31
};

/* A vnode carrying a pointer to its op vector, exactly as BSD does it. */
struct vnode {
    int              v_flag;
    struct vnodeops *v_op;
    int              v_tag;
};

struct vnode a_vnode;

int
main()
{
    struct vnode *vp;
    struct vnodeops *ops;
    int total;

    a_vnode.v_flag = 0;
    a_vnode.v_op   = &ufs_vnodeops;
    a_vnode.v_tag  = 0;
    vp = &a_vnode;

    /* Two levels of indirection, the VOP call shape.  Slots chosen across the
     * whole table: first, an early-middle one, one either side of the 64-byte
     * (16-slot) boundary, and the last. */
    total  = (*vp->v_op->vn_lookup)();     /* slot 0,  offset 0   */
    total += (*vp->v_op->vn_read)();       /* slot 8,  offset 32  */
    total += (*vp->v_op->vn_remove)();     /* slot 15, offset 60  */
    total += (*vp->v_op->vn_rename)();     /* slot 17, offset 68  */
    total += (*vp->v_op->vn_islocked)();   /* slot 31, offset 124 -- the last */
    /* 0 + 8 + 15 + 17 + 31 == 71 */

    /* Through an intermediate pointer variable -- the same two-level shape,
     * but with the vnode reached via a local, which is how namei and the
     * syscall layer hold it.
     *
     * NOT tested, because fcc does not accept it and the port does not need
     * it: the BARE spelling `vp->v_op->vn_bmap()` without an explicit
     * dereference is rejected ("expected ';'").  Reno never writes it that
     * way -- every VOP_/VFS_ macro in sys/vnode.h and sys/mount.h uses the
     * explicit `(*((v)->v_op->vn_x))(...)` form, and the kern tier contains no
     * bare call at all.  So this is a real fcc limit with no bearing here. */
    ops = vp->v_op;
    total += (*ops->vn_bmap)();            /* slot 28, offset 112 */
    /* 71 + 28 == 99 */

    return total - 57;                     /* 99 - 57 == 42 */
}
