#!/usr/bin/env python3
"""Generate a module's CALL SHIMS into another module's exported vtable.

WHY A GENERATOR AND NOT A MACRO.  src/modules/ufs/vfs_import.s says it, having
tried: "a Merlin macro cannot define the label its own body forward-references
-- `PEA ufsimp_brd-1` inside the expansion reports 'Can't find format for
element' whether the label is `@`-local or global, because the macro body is
not in the scope that would resolve it."  So the thirteen shims in that file
are written out by hand, identical but for two numbers.

A generator is not a macro and does not have that problem.  It became worth
building at UFS 1.12c, when the probes moved into their own module and needed
twenty-nine more of the same thing -- which is the point at which hand-writing
65816 that differs only in an argument count stops being careful and starts
being a place for a typo to hide.

THE SHAPE IS vfs_import.s's, VERBATIM, and that file's header is the spec:

  1. copy the arguments, `LDA <argbytes+2>,S / PHA` repeated argbytes/2 times
  2. read the target offset into X, while DBR is still ours
  3. PHA/PLB the target bank -- net zero on the stack
  4. PHK / PEA return-1        the return address, in OUR bank
  5. PHB / PEA target-1        the target, in the callee's
  6. RTL                       the pile call
  7. drop the copied arguments, PHK/PLB our DBR back, RTL

THE `LDA n,S` OFFSET IS CONSTANT WITHIN A SHIM because every PHA moves S down
by two, bringing the next source word to the offset the last was read from.  It
is argbytes + 2: arguments start at 4,S above the three-byte return address,
and the last WORD begins two bytes below their end.

VALIDATED AGAINST THE HAND-WRITTEN FILE.  --check-against compares the emitted
CODE (comments and blank lines ignored) with an existing shim file, so the
thirteen shims that were hand-written and have been running since 1.10 are the
generator's test.  A generator whose output is asserted only by its own
expectations would be worth nothing.

Usage:
    gen_mod_imports.py <table-name> <out.s>
    gen_mod_imports.py --check-against <table-name> <existing.s>
"""
import re
import os
import sys


# A table is (impbase, bankvar, retprefix, [(shim, offset_symbol, argbytes,
# signature), ...]).  impbase and bankvar are the module-local cells its
# mod_init fills from Mod_FindVtable.
TABLES = {
    # What ufs.mod imports from vfs.mod.  Transcribed from the hand-written
    # src/modules/ufs/vfs_import.s, which is what --check-against compares to.
    'ufs_from_vfs': ('_ufsImp', '_ufsVfsBank', 'ufsret_', [
        ('bread',       'VFSCORE_Bread',       12, 'bread(vp, blkno, bpp) -> errno'),
        ('bwrite',      'VFSCORE_Bwrite',       4, 'bwrite(bp) -> errno'),
        ('brelse',      'VFSCORE_Brelse',       4, 'brelse(bp)'),
        ('getblk',      'VFSCORE_Getblk',       8, 'getblk(vp, blkno) -> struct buf *'),
        ('bdevvp',      'VFSCORE_Bdevvp',       6, 'bdevvp(dev, vpp) -> errno'),
        ('vinvalbuf',   'VFSCORE_Vinvalbuf',    6, 'vinvalbuf(vp, save)'),
        ('vgone',       'VFSCORE_Vgone',        4, 'vgone(vp)'),
        ('vrele',       'VFSCORE_Vrele',        4, 'vrele(vp)'),
        ('checkalias',  'VFSCORE_Checkalias',  10,
         'checkalias(nvp, rdev, mp) -> struct vnode *'),
        ('vref',        'VFSCORE_Vref',         4, 'vref(vp)'),
        ('getnewvnode', 'VFSCORE_Getnewvnode', 14, 'getnewvnode(tag, mp, vops, vpp) -> errno'),
        ('vget',        'VFSCORE_Vget',         4, 'vget(vp) -> errno'),
        ('uiomove',     'VFSCORE_Uiomove',     10, 'uiomove(cp, n, uio) -> errno'),
        ('biodone',     'VFSCORE_Biodone',      4, 'biodone(bp)'),
        # ufs_init's vfssw[] row: MOUNT_UFS and &ufs_vfsops, handed over the
        # way ufsdir.mod hands over its two tables.
        ('vfs_setvfsops', 'VFSCORE_Setvfsops',  6, 'vfs_setvfsops(type, ops) -> errno'),
            # Untabled until 2026-09-05, for kernel_from_vfs's reason (#328).
        ('namei', 'VFSCORE_Namei', 4,
         'namei(ndp) -> errno.  One pointer, an int back',
         [
          'frame exactly, which is what this is copied from.',
          '',
          'UFS 1.8b-1, AND THE FIRST TIME ANYTHING OUTSIDE vfs.mod HAS NEEDED namei.',
          'The slot has been exported since the name cache landed (VFSCORE_Namei, 26);',
          'nothing imported it, because nothing outside that module had a pathname to',
          "resolve.  `getmdev' does: a mount names its device as a PATH -- `mount",
          "/dev/rd0 /mnt' -- and only namei turns one into a vnode.",
         ]),
        ('vflush', 'VFSCORE_Vflush', 10,
         'vflush(mp, skipvp, flags) -> errno',
         [
          "RENO CALLS IT FROM THE FILESYSTEM'S UNMOUNT and so does this: ufs_unmount",
          "opens with `if (error = vflush(mp, NULLVP, flags)) return (error);', which is",
          'the filesystem deciding whether its vnodes may be taken away.  It could have',
          'been called from vfs_dounmount instead, for free, both being in vfs.mod --',
          "and that would make flush policy the VFS's for every filesystem, which is not",
          'the shape upstream has.  include/modules.s says the same at VFSCORE_Vflush.',
          '',
          'ITS ABSENCE HAD A STATED REASON THAT EXPIRED.  ufs_unmount carried "vflush',
          '(1.11 -- no vnode has been produced from this mount until iget exists)" from',
          '1.8a, and it was true until 1.8b-3a taught lookup to cross into a mount.',
         ]),
        ('vattr_null', 'VFSCORE_VattrNull', 4, 'vattr_null(vap)',
         [
          "fchmod(2)'s and fchown(2)'s vattr, kern_fsetattr.c: Reno's VATTR_NULL, which",
          'must reach every field, so the one vfs.mod has rather than a copy.',
         ]),
]),

    # What prodos.mod imports from vfs.mod -- ProDOS FST P2: the buffer cache,
    # the vnode pool and namei, and the vfssw[] handover.  Argument byte counts
    # are ufs_from_vfs's rows for the same entries.
    'prodos_from_vfs': ('_pdVImp', '_pdVfsBank', 'pdvret_', [
        ('bread',         'VFSCORE_Bread',       12, 'bread(vp, blkno, bpp) -> errno'),
        ('bwrite',        'VFSCORE_Bwrite',       4, 'bwrite(bp) -> errno'),
        ('brelse',        'VFSCORE_Brelse',       4, 'brelse(bp)'),
        ('getnewvnode',   'VFSCORE_Getnewvnode', 14, 'getnewvnode(tag, mp, vops, vpp) -> errno'),
        ('vget',          'VFSCORE_Vget',         4, 'vget(vp) -> errno'),
        ('vref',          'VFSCORE_Vref',         4, 'vref(vp)'),
        ('vrele',         'VFSCORE_Vrele',        4, 'vrele(vp)'),
        ('vgone',         'VFSCORE_Vgone',        4, 'vgone(vp)'),
        ('namei',         'VFSCORE_Namei',        4, 'namei(ndp) -> errno'),
        ('vflush',        'VFSCORE_Vflush',      10, 'vflush(mp, skipvp, flags) -> errno'),
        ('vfs_setvfsops', 'VFSCORE_Setvfsops',    6, 'vfs_setvfsops(type, ops) -> errno'),
        ('uiomove',       'VFSCORE_Uiomove',     10, 'uiomove(cp, n, uio) -> errno'),
    ]),

    # What prodosw.mod, the ProDOS write half, imports from vfs.mod -- ProDOS FST
    # P6: every vfs.mod entry prodos_write.c calls.  Byte counts are
    # prodos_from_vfs's rows.
    'prodosw_from_vfs': ('_pwVImp', '_pwVfsBank', 'pwvret_', [
        ('bread',         'VFSCORE_Bread',       12, 'bread(vp, blkno, bpp) -> errno'),
        ('bwrite',        'VFSCORE_Bwrite',       4, 'bwrite(bp) -> errno'),
        ('brelse',        'VFSCORE_Brelse',       4, 'brelse(bp)'),
        ('vrele',         'VFSCORE_Vrele',        4, 'vrele(vp)'),
        ('uiomove',       'VFSCORE_Uiomove',     10, 'uiomove(cp, n, uio) -> errno'),
    ]),

    # ...and from prodos.mod, the read half, through VT_PDCORE: the node-layer
    # functions the write half calls, and the handover.  int and unsigned are 2
    # bytes, pointers 4.
    'prodosw_from_prodos': ('_pwPImp', '_pwPdBank', 'pwpret_', [
        ('pdget',          'PDCORE_Pdget',       12, 'pdget(pmp, dirblk, idx, pdpp) -> errno'),
        ('pd_fork',        'PDCORE_Fork',         4, 'pd_fork(pd) -> errno'),
        ('pd_entsync',     'PDCORE_Entsync',      4, 'pd_entsync(pd)'),
        ('pd_twin',        'PDCORE_Twin',         4, 'pd_twin(pd) -> struct pdnode *'),
        ('pd_rekey',       'PDCORE_Rekey',        8, 'pd_rekey(pd, blk, idx)'),
        ('pd_bmap',        'PDCORE_Bmap',        10, 'pd_bmap(pd, lbn, blkp) -> errno'),
        ('pd_unlock',      'PDCORE_Unlock',       4, 'pd_unlock(vp)'),
        ('pd_setwriteops', 'PDCORE_Setwriteops',  8, 'pd_setwriteops(struct pdwops *, struct vnodeops *)'),
    ]),

    # What ufsprobe.mod imports from ufs.mod.  UFS 1.12c: the probes moved to
    # their own bank and reach back through VT_UFSCORE.  Argument byte counts
    # are fcc's -- int and the *_t shorts are 2, every pointer and every long
    # (daddr_t, off_t, time_t) is 4.
    'ufsprobe_from_ufs': ('_upImp', '_upUfsBank', 'upret_', [
        ('iget',         'UFSCORE_Iget',     10, 'iget(mp, ino, ipp) -> errno'),
        ('iput',         'UFSCORE_Iput',      4, 'iput(ip)'),
        ('ufs_balloc',   'UFSCORE_Balloc',   12, 'ufs_balloc(devvp, sb, resultbno) -> errno'),
        ('ufs_bfree',    'UFSCORE_Bfree',    12, 'ufs_bfree(devvp, sb, bno) -> errno'),
        ('ufs_bmap',     'UFSCORE_Bmap',     16, 'ufs_bmap(devvp, addr, lbn, resultbno) -> errno'),
        ('ufs_dget32',   'UFSCORE_Dget32',    6, 'ufs_dget32(b, off) -> long'),
        ('ufs_ialloc',   'UFSCORE_Ialloc',   12, 'ufs_ialloc(devvp, sb, resultino) -> errno'),
        ('ufs_ifind',    'UFSCORE_Ifind',     4, 'ufs_ifind(dev, ino) -> struct inode *'),
        ('ufs_ifree',    'UFSCORE_Ifree',     6, 'ufs_ifree(sb, ino)'),
        ('ufs_itrunc',   'UFSCORE_Itrunc',   14, 'ufs_itrunc(oip, length, flags, countp) -> errno'),
        ('ufs_mountfs',  'UFSCORE_Mountfs',  12, 'ufs_mountfs(devvp, mp, ump) -> errno'),
        ('ufs_sbdecode', 'UFSCORE_Sbdecode',  8, 'ufs_sbdecode(b, sb)'),
        ('ufs_sbencode', 'UFSCORE_Sbencode',  8, 'ufs_sbencode(sb, b)'),
        ('ufs_sbread',   'UFSCORE_Sbread',   12, 'ufs_sbread(devvp, sb, blk) -> errno'),
        ('ufs_sbupdate', 'UFSCORE_Sbupdate',  8, 'ufs_sbupdate(devvp, sb) -> errno'),
        ('ufs_sbvalid',  'UFSCORE_Sbvalid',   8, 'ufs_sbvalid(sb, volblocks) -> int'),
        ('kern_time',    'UFSCORE_KernTime',  0, 'kern_time() -> long'),
        # The device number of a special file -- UFS 1.13a.  The probe asserts
        # it in three places that can disagree: the in-core inode (this), the
        # vnode's v_rdev, and the bytes on the platter.
        ('ufs_getrdev', 'UFSCORE_Getrdev', 4, 'ufs_getrdev(ip) -> dev_t'),
    ]),

    # What ufsdir.mod imports from ufs.mod.  the UFS bank split: the filesystem's two
    # halves separated at the measured seam -- 42 call sites cross in this
    # direction, ZERO in the other, which is why the split is here and not at
    # some tidier-sounding subject boundary.
    'ufsdir_from_ufs': ('_udImp', '_udUfsBank', 'udret_', [
        ('clrbuf',          'UFSCORE_Clrbuf',       4, 'clrbuf(bp)'),
        ('iget',            'UFSCORE_Iget',        10, 'iget(mp, ino, ipp) -> errno'),
        ('iput',            'UFSCORE_Iput',         4, 'iput(ip)'),
        ('iupdat',          'UFSCORE_Iupdat',       6, 'iupdat(ip, waitfor) -> errno'),
        ('ufs_bmap',        'UFSCORE_Bmap',        16, 'ufs_bmap(devvp, addr, lbn, resultbno) -> errno'),
        ('ufs_bmapx',       'UFSCORE_Bmapx',       26, 'ufs_bmapx(devvp, addr, lbn, rwflg, ip, resultbno, freshp) -> errno'),
        ('ufs_ialloc',      'UFSCORE_Ialloc',      12, 'ufs_ialloc(devvp, sb, resultino) -> errno'),
        ('ufs_ifmttovt',    'UFSCORE_Ifmttovt',     2, 'ufs_ifmttovt(mode) -> enum vtype'),
        ('ufs_ifree',       'UFSCORE_Ifree',        6, 'ufs_ifree(sb, ino)'),
        ('ufs_itimes',      'UFSCORE_Itimes',       4, 'ufs_itimes(ip)'),
        ('ufs_itrunc',      'UFSCORE_Itrunc',      14, 'ufs_itrunc(oip, length, flags, countp) -> errno'),
        ('ufs_setvnodeops', 'UFSCORE_Setvnodeops',  4, 'ufs_setvnodeops(vnodeops *)'),
        ('ufs_reclaim',     'UFSCORE_Reclaim',      4, 'ufs_reclaim(vp) -> errno'),
        # The device number of a special file, and the second ops table --
        # UFS 1.13a.  The block half owns the on-disk representation; see
        # include/modules.s.
        ('ufs_getrdev',     'UFSCORE_Getrdev',     4, 'ufs_getrdev(ip) -> dev_t'),
        ('ufs_setrdev',     'UFSCORE_Setrdev',     6, 'ufs_setrdev(ip, dev)'),
        ('ufs_setspecops',  'UFSCORE_Setspecops',  4, 'ufs_setspecops(vnodeops *)'),
    ]),

    # ...and what it imports from vfs.mod.  Measured the same way: these nine
    # are every vfs.mod entry the name half actually calls.
    # THE TEN spec_* ROWS WENT on 2026-09-05: spec_vnops.c moved into THIS module,
    # beside ufs_vnops.c which is its only caller, so those calls are same-bank
    # and need no shim at all.  vfs.mod's VFSCORE slots for them are dead and
    # still numbered -- a slot number is ABI.
    'ufsdir_from_vfs': ('_udVImp', '_udVfsBank', 'udvret_', [
        ('bread',    'VFSCORE_Bread',    12, 'bread(vp, blkno, bpp) -> errno'),
        ('bwrite',   'VFSCORE_Bwrite',    4, 'bwrite(bp) -> errno'),
        ('brelse',   'VFSCORE_Brelse',    4, 'brelse(bp)'),
        ('getblk',   'VFSCORE_Getblk',    8, 'getblk(vp, blkno) -> struct buf *'),
        ('vrele',    'VFSCORE_Vrele',     4, 'vrele(vp)'),
        ('vref',     'VFSCORE_Vref',      4, 'vref(vp)'),
        # The name cache's HIT arm claims the vnode it was handed rather than
        # going through iget: vget resurrects it if it had gone idle, and vput
        # gives it back when the capability check says it was recycled while
        # the inode lock slept.  Both slots already existed; only ufsdir's
        # shims are new.
        ('vget',     'VFSCORE_Vget',      4, 'vget(vp) -> int'),
        ('vput',     'VFSCORE_Vput',      4, 'vput(vp)'),
        ('uiomove',  'VFSCORE_Uiomove',  10, 'uiomove(cp, n, uio) -> errno'),
        ('biodone',  'VFSCORE_Biodone',   4, 'biodone(bp)'),
        ('vgone',    'VFSCORE_Vgone',     4, 'vgone(vp)'),
        # The device-vnode ops table goes the OTHER WAY.  spec_vnops.c lives in
        # THIS module since 2026-09-05, so vfs.mod's bdevvp and checkalias --
        # which used to take &spec_vnodeops directly -- are handed it from this
        # module's mod_init instead, the way ufs.mod's two tables already are.
        ('vfs_setspecops', 'VFSCORE_Setspecops', 4, 'vfs_setspecops(vnodeops *)'),
        # The name cache's two RARE entries go the other way too, and for the
        # same reason: vfs_cache.c lives in THIS module, beside the ufs_lookup.c
        # that is its only hot-path caller, so vfs.mod's getnewvnode and
        # vfs_dounmount cannot name cache_purge and cache_purgevfs.  They are
        # handed a table of the two at mod_init and dispatch through it.
        ('vfs_setcacheops', 'VFSCORE_Setcacheops', 4, 'vfs_setcacheops(cacheops *)'),
        # WHAT spec_vnops.c ITSELF CALLS BACK.  These were same-bank while it
        # lived in vfs.mod and are the seam now -- six against the ten shims the
        # move deleted, and vfs.mod keeps the 5,482 bytes either way.
        ('vcount',       'VFSCORE_Vcount',      4, 'vcount(vp) -> int'),
        ('vinvalbuf',    'VFSCORE_Vinvalbuf',   6, 'vinvalbuf(vp, save)'),
        ('bawrite',      'VFSCORE_Bawrite',     4, 'bawrite(bp) -> errno'),
        ('bdwrite',      'VFSCORE_Bdwrite',     4, 'bdwrite(bp)'),
        ('vflushbuf',    'VFSCORE_Vflushbuf',   6, 'vflushbuf(vp, flags)'),
        ('bio_strategy', 'VFSCORE_BioStrategy', 4, 'bio_strategy(bp)'),
        # THE securelevel GATE (apple/fgx#410).  spec_open asks this before it
        # lets a write-open of a character device reach the driver; the level
        # and the device-to-device mapping are both vfs.mod's.
        ('spec_securechr', 'VFSCORE_SpecSecurechr', 4,
         'spec_securechr(dev) -> 0 or errno'),
        # THE TEN spec_* ROWS THAT WERE HERE ARE GONE, and the reason they
        # existed is the reason they could go.  They were never CALLED from this
        # module's C: they were the cells of spec_inodeops, the vector a device
        # file wears, and a vtable cell must name a function in the module that
        # OWNS the cell (a MOD_FN_PTR carries the owning module's bank) -- so
        # each cell named its own SHIM and the shim crossed into vfs.mod.  With
        # spec_vnops.c in this bank the cells name the real functions and the
        # crossing is gone.
    ]),

    # ...and from vfs.mod.  A SUBSET of ufs.mod's list: the probes take vnodes
    # and buffers but never mint a vnode or move a uio themselves.
    # What the KERNEL's FAR BANK imports from vfs.mod -- UFS 1.7d, the inward
    # seam.  The first table here whose importer is not a module: src/modules/
    # vfs/vfs.s's VTDR note said VT_VFSCORE "points SIDEWAYS rather than up",
    # and this is the entry that stops being true.  Same shim shape, because
    # the direction does not change the problem -- a bank switch with the
    # arguments on the stack.
    #
    # Shaped by the DESCRIPTOR LAYER, which is the seam's customer: falloc and
    # ufalloc make an fd, getf resolves one, closef and fdrelease retire one.
    #
    # IT LIVES IN THE FAR BANK BECAUSE THESE SHIMS MUST BE ENTERED FROM C.
    # Every one of them says so -- "entered from C, which left DBR on our
    # bank" -- and the callee needs fcc's direct page and register file, which
    # the far bank establishes and the core bank does not.  Built in core
    # first, called from assembly with a hand-rolled D bracket, it killed the
    # boot with no output; see the 1.7d RESUME.
    'kernel_from_vfs': ('_kVfsImp', '_kVfsBank', 'kvfsret_', [
        ('ndslot',    'VFSCORE_Ndslot',     4, 'ndslot(pid, which) -> nameidata *'),
        # The five vnops targets.  `vnops` itself lives in the far bank with
        # its dispatcher; these are what its entries point at, so a call
        # through f_ops is same-bank and only the shim crosses.
        ('vn_read',   'VFSCORE_VnRead',     8, 'vn_read(fp, uio) -> errno'),
        ('vn_write',  'VFSCORE_VnWrite',    8, 'vn_write(fp, uio) -> errno'),
        ('vn_ioctl',  'VFSCORE_VnIoctl',   10, 'vn_ioctl(fp, com, data) -> errno'),
        ('vn_select', 'VFSCORE_VnSelect',   6, 'vn_select(fp, which) -> errno'),
        ('vn_close',  'VFSCORE_VnClose',    4, 'vn_close(fp) -> errno'),
        ('vn_open',   'VFSCORE_VnOpen',     8, 'vn_open(ndp, fmode, cmode) -> errno'),
        ('vn_getattr','VFSCORE_VnGetattr',  8, 'vn_getattr(vp, vap) -> errno'),
        # access(2), UFS 2.6.  SIX bytes -- a vnode pointer and an int.  It is
        # in vfs.mod rather than here because it needs BOTH the VOP_ACCESS
        # dispatch (through v_op, which carries a module's bank) and
        # vn_writechk, which lives beside it; doing the per-bit walk there
        # costs one VFSCORE slot instead of two shims.
        ('vn_access', 'VFSCORE_VnAccess',   6, 'vn_access(vp, fmode) -> errno'),
        # exec(2), apple/fgx#416.  FOUR bytes -- one vnode pointer -- and it
        # answers an errno, deliberately taking no vattr: see vn_setsize's row
        # below, and apple/fgx#417, which is the measured half.  Both of
        # exec's tests run on vfs.mod's side so the structure never crosses.
        ('vn_execchk','VFSCORE_VnExecchk', 4, 'vn_execchk(vp) -> errno'),
        # ...and its companion, SIX bytes -- a vnode pointer and the selector.
        ('vn_execsugid','VFSCORE_VnExecsugid', 6,
         'vn_execsugid(vp, want) -> id or -1'),
        # ftruncate(2), UFS 2.7.  vn_getattr's row exactly -- four words and
        # an eight-byte drop -- and there for the same reason: a VOP_ is
        # dispatched in the module that owns the vnode layer.  It takes a SIZE
        # and not a vattr because
        # `vattr_null' is vfs.mod's, beside the structure it fills; see
        # vn_setsize's own header for why a half-initialised vattr is the
        # failure worth designing out.
        ('vn_setsize','VFSCORE_VnSetsize',  8, 'vn_setsize(vp, length) -> errno'),
        # fchdir(2), UFS 2.7.  The far bank owns the DESCRIPTOR -- fdcheck and
        # f_data -- and vfs.mod owns the cwd table and vref/vrele, which is
        # chdir(2)'s split.  Six bytes: a pid and one vnode pointer.
        ('vfs_fchdir','VFSCORE_Fchdir',      6, 'vfs_fchdir(pid, vp) -> errno'),
        # UFS 1.7d I3: the kernel mounts /dev itself, which needs a device
        # vnode for the second unit and a reference on it to hand the mount.
        ('bdevvp',    'VFSCORE_Bdevvp',     6, 'bdevvp(dev, vpp) -> errno'),
        ('vref',      'VFSCORE_Vref',       4, 'vref(vp)'),
        ('vrele',     'VFSCORE_Vrele',      4, 'vrele(vp)'),
        # ...and the mount's root, held unlocked for namei's ni_rdir.  It is
        # vfs.mod's because finding it needs VOP dispatch, which only a module
        # can do -- see VFSCORE_DevRoot in include/modules.s.
        ('vfs_devroot','VFSCORE_DevRoot',   8,
         'vfs_devroot(mp, vpp) -> errno'),
        # rename(2)'s body.  TEN argument bytes: an int and two far pointers.
        ('vfs_rename', 'VFSCORE_Rename', 18,
         'vfs_rename(pid, fdvp, from, tdvp, to) -> errno'),
        # symlink's body: an int, THREE far pointers and the mode -- sixteen.
        ('vfs_symlink', 'VFSCORE_Symlink', 16,
         'vfs_symlink(pid, dvp, path, target, mode) -> errno'),
        # readlink, WHOLE: pid, path, buf, count -- TWELVE bytes, which is
        # vfs_listdir's shape to the byte, and deliberately so (see #326).
        ('vfs_readlink', 'VFSCORE_Readlink', 12,
         'vfs_readlink(pid, path, buf, count) -> count or -errno'),
        # statfs(2)'s two halves (apple/fgx#329).  EIGHT bytes for statfs1 --
        # two far pointers, no int -- and TEN for statfs, which adds the pid.
        ('vfs_statfs1', 'VFSCORE_Statfs1', 8,
         'vfs_statfs1(mp, sbp) -> errno',
         [
          "The per-mount half of getfsstat(2).  Its WALK is in this bank, in",
          'vfs_syscalls.c beside the mount list it walks; this is the one step of',
          'it that has to happen over there, because refreshing a mount means',
          'VFS_STATFS and that is a dispatch through a module bank.',
          '',
          'IT TAKES A `struct mount *` FROM THIS BANK and dereferences it over',
          "there, which is fine and is what vfs_devroot(mp, vpp) already does: a",
          'pointer is four bytes with its bank in it.  What may NOT cross is the',
          'vtable CELL inside it -- see the slot comment in include/modules.s.',
         ]),
        ('vfs_statfs', 'VFSCORE_Statfs', 10,
         'vfs_statfs(pid, path, sbp) -> errno'),
        ('vfs_sync1', 'VFSCORE_Sync1', 4,
         'vfs_sync1(mp) -> errno',
         [
          "sync(2)'s per-mount half.  FOUR BYTES: one `struct mount *'.",
          "vfs_statfs1's twin -- the walk is the far bank's, the dispatch is",
          'vfs.mod\'s, because the vector cell carries a module bank.',
         ]),
        ('vfs_link', 'VFSCORE_Link', 10,
         'vfs_link(pid, target, linkname) -> errno',
         [
          'link(2).  TEN BYTES: a pid and two fcc pointers.  No starting',
          "directory crosses -- vfs_link asks vfs_cdir itself, both paths being",
          'the caller\'s, which is vfs_setattr\'s shape one row up.',
         ]),
        ('vfs_setattr', 'VFSCORE_Setattr',   22, 'vfs_setattr(pid,path,follow,mode,uid,gid,atime,mtime) -> errno',
         [
          'chmod(2), chown(2) and utimes(2).  TWENTY-TWO BYTES: a pid, an fcc',
          'pointer at four, four ints -- follow, mode, uid, gid -- at two each,',
          'and two time_t at four.  VA_UNSET in a field means LEAVE IT, which is',
          'what lets ONE entry serve three syscalls without three slots.  Reno',
          'has them as three calls that differ only in which field of the vattr',
          'they fill, all ending in one VOP_SETATTR (chmod1 :1148, chown1 :1189,',
          'utimes :1269), so the sharing is upstream\'s shape and not a saving.',
          'utimes joined at UFS 2.7 (apple/fgx#343): it was the LAST path-taking',
          'syscall still dispatching into prodos.mod, and on a UFS root -- where',
          'prodos.mod is not loaded -- it simply failed, untested by anything.',
         ]),
            # THE THIRTEEN THAT WERE NOT IN THIS TABLE UNTIL 2026-09-05 (#328).
        # They were generated once, annotated by hand, and their rows dropped --
        # so this file said GENERATED and could not be regenerated without
        # deleting the annotations.  The `note' column is where the annotation
        # lives now; the argument count is NOT allowed in it.
        ('namei', 'VFSCORE_Namei', 4,
         'namei(ndp) -> errno',
         [
          'THE SECOND IMPORTER OF namei AND THE SECOND THIS WEEK.  ufs.mod took the',
          "first at 1.8b-1, for `getmdev'; this bank needs it for the other half of the",
          'same syscall -- mount(2) resolves the DIRECTORY it covers, where getmdev',
          'resolves the DEVICE.  Until 1.8b nothing outside vfs.mod had a pathname to',
          'resolve at all, which is why a slot exported since the name cache had no',
          'importer for weeks.',
         ]),
        ('vfs_listdir', 'VFSCORE_VfsListdir', 12,
         'vfs_listdir(path, buf, size) -> bytes written, or -errno',
         [
          'two fcc pointers at four each, plus the size at two.  ONE CROSSING FOR THE',
          'WHOLE CALL.  The alternative -- crossing per directory block -- is what',
          "putting the record walk in the far bank would have cost, and vfs_listdir's",
          'header carries why it is not there.',
         ]),
        ('vfs_cdir', 'VFSCORE_Cdir', 2,
         'vfs_cdir(pid) -> struct vnode *',
         [
          'relative walk starts from; rootdir when the process has chosen nothing.',
         ]),
        ('vfs_chdir', 'VFSCORE_Chdir', 6,
         'vfs_chdir(pid, path) -> 0 or errno',
         [
          'pointer.',
         ]),
        ('vfs_cdirinit', 'VFSCORE_Cdirinit', 0,
         'vfs_cdirinit() -- zero the cwd table.  No arguments',
         ),
        ('vfs_unlink', 'VFSCORE_Unlink', 10,
         'vfs_unlink()',
         [
          "vrele's thunk above, slot for slot -- the ONLY things that move are the",
          'argument width and the two numbers that must move together with it: the',
          'source offset 12,S (which is 4 + 2N - 2, and stays put because each PHA',
          'walks the stack down past the word it just copied) and the ADC #10 that',
          'drops the copy afterwards.',
         ]),
        ('vfs_mkdir', 'VFSCORE_Mkdir', 12,
         'vfs_mkdir()',
         [
          "vrele's thunk above, slot for slot -- the ONLY things that move are the",
          'argument width and the two numbers that must move together with it: the',
          'source offset 14,S (which is 4 + 2N - 2, and stays put because each PHA',
          'walks the stack down past the word it just copied) and the ADC #12 that',
          'drops the copy afterwards.',
         ]),
        ('vfs_rmdir', 'VFSCORE_Rmdir', 10,
         'vfs_rmdir()',
         [
          "vrele's thunk above, slot for slot -- the ONLY things that move are the",
          'argument width and the two numbers that must move together with it: the',
          'source offset 12,S (which is 4 + 2N - 2, and stays put because each PHA',
          'walks the stack down past the word it just copied) and the ADC #10 that',
          'drops the copy afterwards.',
         ]),
        ('vput', 'VFSCORE_Vput', 4,
         'vput(vp)',
         [
          "vrele's thunk above, slot for slot, and it exists for a reason vrele cannot",
          'serve: vput is VOP_UNLOCK followed by vrele, and it is vfs.mod\'s.  A far-bank',
          'caller that asked namei for LOCKLEAF puts the vnode down through this.',
         ]),
        ('vfs_cdirfork', 'VFSCORE_CdirFork', 4,
         'vfs_cdirfork(ppid, cpid)',
         [
          'TWO WORDS AND THEY GO DOWN IN ORDER.  fcc reads its arguments right to left,',
          'so the caller pushed cpid then ppid and the deepest word is ppid at 6,S; each',
          "PHA below moves the frame one word, which is why the SAME `6,S' reads the",
          "next argument rather than the same one twice.  `vfs_chdir' below has the",
          'three-word version of this and is where the idiom is stated.',
         ]),
        ('vfs_cdirexit', 'VFSCORE_CdirExit', 2,
         'vfs_cdirexit(pid)',
         ),
        ('vfs_setroot', 'VFSCORE_SetRoot', 4,
         'vfs_setroot(mp) -> errno',
         ),
        ('vfs_dounmount', 'VFSCORE_Dounmount', 6,
         'vfs_dounmount(mp, flags) -> errno',
         [
          'THE OTHER HALF OF unmount(2).  This bank resolves the path and checks that it',
          'named a mount ROOT; everything after that is vfs.mod\'s -- cache_purgevfs, the',
          'vnode pool, and the VFS_UNMOUNT beside them.  vfs_devroot above is the same',
          'seam in the same direction.',
         ]),
        ('vfs_getvfsops', 'VFSCORE_Getvfsops', 2,
         'vfs_getvfsops(type) -> struct vfsops *',
         [
          "mount(2)'s vfssw[] row.  TWO BYTES in, a far pointer out.  A lookup",
          'that returns before the mount starts, so nothing of it is on the stack',
          'under VFS_MOUNT, which vfs_mountat dispatches from here.',
         ]),
        ('vfs_getsecurelevel', 'VFSCORE_GetSecurelevel', 0,
         'vfs_getsecurelevel() -> int',
         [
          "THE KERN_SECURELVL LEAF'S TWO HALVES (apple/fgx#410).  sysctl(2)'s body is",
          'this bank\'s, the variable is vfs.mod\'s -- it lives beside spec_open\'s gate',
          'because that is the reader on the hot path, and this is the rare direction.',
         ]),
        ('vfs_setsecurelevel', 'VFSCORE_SetSecurelevel', 2,
         'vfs_setsecurelevel(level) -> 0 or errno',
         ),
        ('bflush', 'VFSCORE_Bflush', 2,
         'bflush(dev)',
         [
          "sync(2)'s LAST ACT (apple/fgx#398).  4.3BSD-Reno flushes a delayed write by",
          'walking the mount\'s own vnode list and then its device vnode; this tree keeps',
          'no such list, and the buffers that are actually left dirty are on UNMOUNTED',
          'spindles that no mount-list walk visits.  So the flush is keyed on the device',
          'and issued once, from here, for every device at once.',
         ]),
]),

    # What the FAR KERNEL BANK imports from ufs.mod -- UFS 1.7d I3.
    #
    # The kernel mounts its root at boot by calling UFS's ufs_mountfs directly,
    # which is 4.3BSD-Reno's ufs_mountroot: the root mount never goes through
    # vfssw[], and neither does it here.  mount(2) does, in vfs_mountat.
    #
    # IT CANNOT BE DONE FROM A MODULE'S mod_init instead.  ufs.mod's own
    # mod_init runs before ufsdir.mod loads, and iget refuses to mint a vnode
    # until ufsdir is up -- so a mount there would find no root.  After
    # Mod_LoadConf is the first moment the filesystem is whole, and that is
    # kernel code.
    'kernel_from_ufs': ('_kUfsImp', '_kUfsBank', 'kufsret_', [
        ('ufs_mountfs', 'UFSCORE_Mountfs', 12, 'ufs_mountfs(devvp, mp, ump) -> errno'),
            # Untabled until 2026-09-05, for kernel_from_vfs's reason (#328).
        ('ufs_fsyncvp', 'UFSCORE_Fsync', 6,
         'ufs_fsyncvp(vp, fflags) -> errno',
         [
          "fsync(2)'s last hop -- apple/fgx#355.  A one-line VOP_FSYNC dispatch, in",
          'ufs.mod because ufsdir.mod, where ufs_fsync lives, exports nothing by design.',
         ]),
        ('vn_flock', 'UFSCORE_VnFlock', 6, 'vn_flock(fp, how) -> errno',
         [
          "flock(2) past the descriptor lookup; kern_flock.c, in ufs.mod because",
          'vfs.mod is full.',
         ]),
        ('vn_unlock', 'UFSCORE_VnUnlock', 6, 'vn_unlock(fp, kind) -> 0',
         [
          "closef's drop of a flock(2) lock with a file's last reference, as",
          "2.11BSD's closef does (kern_descrip.c:359).",
         ]),
        ('vn_fsetattr', 'UFSCORE_VnFsetattr', 10,
         'vn_fsetattr(fp, mode, uid, gid) -> errno',
         [
          "fchmod(2) and fchown(2) past the descriptor lookup; kern_fsetattr.c, in",
          'ufs.mod because vfs.mod is full.',
         ]),
]),

    'ufsprobe_from_vfs': ('_upVImp', '_upVfsBank', 'upvret_', [
        ('bread',  'VFSCORE_Bread',  12, 'bread(vp, blkno, bpp) -> errno'),
        ('bwrite', 'VFSCORE_Bwrite',  4, 'bwrite(bp) -> errno'),
        ('brelse', 'VFSCORE_Brelse',  4, 'brelse(bp)'),
        ('bdevvp', 'VFSCORE_Bdevvp',  6, 'bdevvp(dev, vpp) -> errno'),
        ('vref',   'VFSCORE_Vref',    4, 'vref(vp)'),
        ('vrele',  'VFSCORE_Vrele',   4, 'vrele(vp)'),
        ('namei',  'VFSCORE_Namei',   4, 'namei(ndp) -> errno'),
        ('ndslot', 'VFSCORE_Ndslot',  4, 'ndslot(pid, which) -> nameidata *'),
        ('vcount', 'VFSCORE_Vcount',  4, 'vcount(vp) -> int'),
        # The file/vnode glue -- UFS 1.7c.  vn_rdwr's 28 bytes are its nine
        # arguments at fcc's widths: int and enum are 2, every pointer and the
        # off_t are 4.
        ('vn_open',  'VFSCORE_VnOpen',   8, 'vn_open(ndp, fmode, cmode) -> errno'),
        ('vn_read',  'VFSCORE_VnRead',   8, 'vn_read(fp, uio) -> errno'),
        ('vn_write', 'VFSCORE_VnWrite',  8, 'vn_write(fp, uio) -> errno'),
        ('vn_close', 'VFSCORE_VnClose',  4, 'vn_close(fp) -> errno'),
        ('vn_rdwr',  'VFSCORE_VnRdwr',  28,
         'vn_rdwr(rw, vp, base, len, offset, segflg, ioflg, cred, aresid) -> errno'),
        ('vn_writechk', 'VFSCORE_VnWritechk', 4, 'vn_writechk(vp) -> errno'),
        # The syscall bodies are NOT here any more -- UFS 1.7d I2b moved them
        # to the far kernel bank with the file table, and a module cannot reach
        # the far bank.  vnops_probe.c's section (i) went with them; what is
        # owed to get it back is KSVC service numbers, which is apple/fgx#196.
    ]),
}

# The return-label suffix, when the shim name is too long for Merlin's symbol
# column to stay readable.  vinvalbuf's was shortened by hand and the generator
# keeps that spelling so --check-against has nothing spurious to report.
RETNAME = {'vinvalbuf': 'vinval',
           # The four the cwd/mount work shortened by hand, kept so bringing
           # these shims into the table (2026-09-05, apple/fgx#328) changes
           # no label a listing or a patch table already names.
           'vfs_cdirfork':  'cdirfork',
           'vfs_cdirexit':  'cdirexit',
           'vfs_setroot':   'setroot',
           'vfs_dounmount': 'dounmount'}


def shim(name, sym, argbytes, sig, impbase, bankvar, retprefix, note=None):
    """One import shim.

    `note` is the prose some shims carry -- why this module imports this
    function, what it cost to learn, which increment added it.  It exists
    because THIRTEEN SHIMS IN far/vfs_import.s WERE NOT IN ANY TABLE (2026-09-05,
    apple/fgx#328): the file's own header says "GENERATED ... edit the table
    there, not this file", and it was not, because a generator with nowhere to
    put a paragraph loses the paragraph.  So whoever needed to say something
    generated once, annotated by hand, and dropped the row -- and after that the
    file could not be regenerated without deleting the annotations.

    THE ARGUMENT COUNT IS NOT ALLOWED IN THE NOTE.  It is emitted from the
    `argbytes` column, once, so it cannot drift from the copy loop the same
    column generates.  It had already drifted: vfs_listdir's hand-written header
    said 10 argument bytes over a loop that pushes 12."""
    if argbytes % 2:
        sys.exit(f"gen_mod_imports: {name} has {argbytes} argument bytes; "
                 f"the copy loop moves WORDS and an odd count would leave the "
                 f"callee's frame misaligned by one")
    ret = retprefix + RETNAME.get(name, name)
    out = []
    out.append(';' + '-' * 78)
    out.append(f'; {sig}.  {argbytes} argument bytes.')
    if note:
        out.append(';')
        for line in note:
            out.append(('; ' + line).rstrip())
    out.append(';' + '-' * 78)
    out.append(f'{name:<15} MX      %00')
    for _ in range(argbytes // 2):
        out.append(f'                LDA     {argbytes + 2},S')
        out.append(f'                PHA')
    out.append(f'                LDA     |{impbase}+{sym}')
    out.append( '                                        ; MODBANK-OK: entered from C, which left')
    out.append( '                                        ;   DBR on our bank -- and read HERE,')
    out.append( '                                        ;   before the switch below, for exactly')
    out.append( '                                        ;   that reason')
    out.append( '                TAX                             ; X = target offset in the callee')
    out.append( '                SEP     #$20')
    out.append( '                MX      %10')
    out.append(f'                LDA     |{bankvar}    ; MODBANK-OK: same, still before the')
    out.append( '                                        ;   switch')
    out.append( '                PHA                             ; one byte on...')
    out.append( '                PLB                             ; ...and straight off: DBR = the')
    out.append( '                                                ;   callee.  NET ZERO, which is')
    out.append( '                                                ;   why it can follow the copy.')
    out.append( '                REP     #$30')
    out.append( '                MX      %00')
    out.append(f'                PHK                             ; {ret} is in OUR bank')
    out.append(f'                PEA     {ret}-1')
    out.append( '                PHB                             ; target bank: DBR is the callee\'s')
    out.append( '                                                ;   now, and PHB is exactly the')
    out.append( '                                                ;   one byte RTL wants')
    out.append( '                TXA')
    out.append( '                DEC     A')
    out.append( '                PHA                             ; target - 1')
    out.append( '                RTL                             ; PILECALL')
    if argbytes == 0:
        # NOTHING WAS COPIED, so there is nothing to drop and the return value
        # can stay in A.  The three-instruction stack fix below would be
        # `ADC #0` -- a no-op that reads as though it were doing something.
        out.append(f'{ret:<15} PHK')
        out.append( '                PLB                             ; DBR ours again, recovered from')
        out.append( '                                                ;   PB rather than saved')
        out.append( '                RTL')
        return '\n'.join(out)
    out.append(f'{ret:<15} TAY                             ; park the return value; the stack')
    out.append( '                                                ;   fix needs the register')
    out.append( '                TSC')
    out.append( '                CLC')
    out.append(f'                ADC     #{argbytes}')
    out.append( '                TCS')
    out.append( '                TYA')
    out.append( '                PHK')
    out.append( '                PLB                             ; DBR ours again, recovered from')
    out.append( '                                                ;   PB rather than saved')
    out.append( '                RTL')
    return '\n'.join(out)


def code_only(text):
    """Just the instructions: comments, blank lines and indentation dropped."""
    out = []
    for line in text.split('\n'):
        line = line.split(';')[0].rstrip()
        if line.strip():
            out.append(' '.join(line.split()))
    return out


def generate(table):
    impbase, bankvar, retprefix, entries = TABLES[table]
    # SIZED FROM THE EXPORTER'S COUNT, NOT len(entries), AND THAT IS THE WHOLE
    # POINT.  The shims index this block by the exporter's ABSOLUTE offsets
    # (_upVImp+VFSCORE_Vref), and mod_init's resolver copies the WHOLE vtable
    # into it -- so a table that imports a SUBSET still needs the full-table
    # footprint.  Sizing it by the subset laid 26 bytes of vfs.mod's vtable into
    # a 12-byte cell and overwrote the first 14 bytes of the `bread` shim that
    # followed it, which is a wedge on the first bread and nowhere near the
    # cause.  ufs.mod's hand-written file always spelled this `DS
    # VFSCORE_COUNT*2`; --check-against could not catch the difference because
    # for that table len(entries) == VFSCORE_COUNT.
    prefixes = {e[1].split('_')[0] for e in entries}
    if len(prefixes) != 1:
        sys.exit(f"gen_mod_imports: {table} mixes vtables {sorted(prefixes)}; "
                 f"the storage below can only be sized from one COUNT")
    count_sym = prefixes.pop() + '_COUNT'
    head = [
        ';' + '=' * 78,
        f'; {impbase} / {bankvar} -- the callee module\'s bank, and the',
        '; entry points inside it.  GENERATED by tools/gen_mod_imports.py; edit the',
        '; table there, not this file.',
        ';',
        '; POPULATED ONCE, AT mod_init, from the vtable the loader resolves.  Zero',
        '; until then, which is why the module refuses to run any C when a resolve',
        '; fails -- a shim reading a zero would pile-call bank 0 offset $FFFF and the',
        '; machine would come apart a long way from the cause.',
        ';' + '=' * 78,
        f'{bankvar:<15} DS      2               ; the callee\'s bank, in the low byte',
        f'{impbase:<15} DS      {count_sym}*2',
        '',
    ]
    return ('\n'.join(head) + '\n'
            + '\n\n'.join(shim(e[0], e[1], e[2], e[3], impbase, bankvar,
                                    retprefix, e[4] if len(e) > 4 else None)
                          for e in entries) + '\n')


def check_against(table, path):
    impbase, bankvar, retprefix, entries = TABLES[table]
    have = open(path).read()
    bad = 0
    for e in entries:
        name, sym, argbytes, sig = e[0], e[1], e[2], e[3]
        note = e[4] if len(e) > 4 else None
        m = re.search(r'^' + name + r'\s+MX\s+%00\n.*?\n\s+RTL\n', have, re.S | re.M)
        if not m:
            print(f"gen_mod_imports: {path} has no shim named {name}", file=sys.stderr)
            bad = 1
            continue
        want = code_only(shim(name, sym, argbytes, sig, impbase, bankvar,
                              retprefix, note))
        got = code_only(m.group(0))
        if want != got:
            print(f"gen_mod_imports: {name} DIFFERS", file=sys.stderr)
            for i, (w, g) in enumerate(zip(want, got)):
                if w != g:
                    print(f"    line {i}: generated {w!r} != file {g!r}", file=sys.stderr)
            if len(want) != len(got):
                print(f"    lengths {len(want)} != {len(got)}", file=sys.stderr)
            bad = 1
    # THE CHECK IS TOTAL, AND IT WAS NOT UNTIL 2026-09-05 (apple/fgx#328).
    #
    # Everything above verifies that each row in the TABLE is present and
    # correct in the FILE.  That is a check over the table, and it was read --
    # by me, and the file's own header invites it -- as a check over the FILE.
    # It is not: src/kernel/far/vfs_import.s held 25 shims against 12 rows, and
    # `12 generated shims match ... instruction for instruction' is a true
    # sentence that says nothing about the other 13.  Regenerating on the
    # strength of it deleted them.
    #
    # So the file is enumerated too.  A shim the table does not own is a
    # failure, not a silence: either it belongs in the table or it does not
    # belong in a file whose header says GENERATED.
    # A HEADER COMMENT IS ONLY A SHIM IF THE SHIM IS ALSO THERE.  The scrape
    # used to be `^; ([a-z_]+)\(' alone, which reads any prose line opening
    # `chmod(2) and chown(2) ...' as a declaration and fails the build naming a
    # shim nobody wrote.  Requiring the LABEL as well keeps every bit of the
    # strictness apple/fgx#328 bought -- a hand-written stray still has its
    # `name MX %00' -- and stops the note column tripping it.
    owned = {e[0] for e in entries}
    labels = set(re.findall(r'^([a-z_]+)\s+MX\s+%00', have, re.M))
    infile = set(re.findall(r'^; ([a-z_]+)\(', have, re.M)) & labels
    stray = sorted(infile - owned)
    if stray:
        print(f"gen_mod_imports: {path} holds {len(stray)} shim(s) NO TABLE OWNS: "
              f"{', '.join(stray)}", file=sys.stderr)
        print(f"  The file's header says GENERATED.  Add a row for each in "
              f"MOD_IMPORTS[{table!r}] -- the `note' column takes the prose --",
              file=sys.stderr)
        print(f"  or delete the shim.  DO NOT REGENERATE OVER THEM: that is how "
              f"thirteen were lost once already.", file=sys.stderr)
        bad = 1
    if bad:
        sys.exit(1)
    print(f"gen_mod_imports: {len(entries)} shims in {path}, all owned by the "
          f"table and matching instruction for instruction")


# WHICH TABLE GENERATES WHICH FILE.  It lives here, beside the tables, because
# the pairing is the same fact as the table: a table with no file is dead and a
# file with no table is what apple/fgx#328 was.  --check-all walks it, so the
# build verifies every pair rather than whichever ones somebody remembered.
PAIRS = [
    ('kernel_from_vfs',   'src/kernel/far/vfs_import.s'),
    ('kernel_from_ufs',   'src/kernel/far/ufs_import.s'),
    ('ufs_from_vfs',      'src/modules/ufs/vfs_import.s'),
    ('ufsdir_from_vfs',   'src/modules/ufsdir/vfs_import.s'),
    ('ufsdir_from_ufs',   'src/modules/ufsdir/ufs_import.s'),
    ('ufsprobe_from_vfs', 'src/modules/ufsprobe/vfs_import.s'),
    ('ufsprobe_from_ufs', 'src/modules/ufsprobe/ufs_import.s'),
    ('prodos_from_vfs',   'src/modules/prodos/vfs_import.s'),
    ('prodosw_from_vfs',  'src/modules/prodosw/vfs_import.s'),
    ('prodosw_from_prodos', 'src/modules/prodosw/prodos_import.s'),
]


def check_all(root):
    """Every table against its file, and every table HAS a file."""
    named = {t for t, _ in PAIRS}
    orphan = sorted(set(TABLES) - named)
    if orphan:
        print(f"gen_mod_imports: {len(orphan)} table(s) generate no file: "
              f"{', '.join(orphan)}.  Add them to PAIRS or delete them.",
              file=sys.stderr)
        sys.exit(1)
    n = 0
    for table, path in PAIRS:
        check_against(table, os.path.join(root, path))
        n += len(TABLES[table][3])
    print(f"gen_mod_imports: {len(PAIRS)} import files, {n} shims, "
          f"every one owned by a table")


if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == '--check-all':
        check_all(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    elif len(sys.argv) == 4 and sys.argv[1] == '--check-against':
        check_against(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 3:
        open(sys.argv[2], 'w').write(generate(sys.argv[1]))
    else:
        sys.exit(__doc__)
