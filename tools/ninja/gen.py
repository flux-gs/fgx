#!/usr/bin/env python3
"""gen.py -- emit build.ninja for FGX.

WHY
    build.sh + lib/build_common.sh are 2,056 lines with 18 hand-written
    staleness sites and three near-copies of _*_stale().  Every recent
    build-system failure in the ledger was a missing or wrong edge in that
    hand-maintained model -- including a STALE BINARY guard that correctly
    detected a stale tcsh.bin, told the user to delete it, and had no rule to
    rebuild it.  A real dependency graph cannot express that bug: staleness and
    the rebuild rule are the same edge.

SCOPE
    The kernel, the modules, every userland tool in manifest.json (the
    shells included), the linker probes that build through their own scripts
    (SHELLS), staging, and the disk image.

DEPENDENCY SOURCES -- three, because no single tool provides them
    .c  -> .s    fcc -MD/-MF          (added 2026-07-28)
    .s  -> bin   putdeps PUT scanner  (merlin32 has NO depfile support; its
                                       whole interface is
                                       `[-v] [-s] [macro_dir] <src>`)
    .s  -> bin   fas -MD              (not in the main path; merlin32 assembles)

Usage:
    gen.py [-o build.ninja]     write the graph
    gen.py --report             what is covered vs left to build.sh
"""
import os
import glob
import json
import shlex
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import putdeps                                        # noqa: E402
# The module placement ORDER is imported rather than restated: it decides where
# each module lands in the shared bank, and a build wired in a different order
# than the generator assumes would place two modules at the same offset.
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_modplace                                   # noqa: E402

# The VFS translation units, compiled into the FAR bank.  One list, used twice:
# to declare the kernelc build rules and to name their outputs as far-link
# dependencies, which the PUT-closure scan cannot supply because these are
# GENERATED files and it can only see what already exists.
#
# ORDER MATCHES far.s's PUT order where it matters: the two ops vectors are
# assembled before the file that references them.
# THE DESCRIPTOR LAYER IS NOT IN THIS LIST ANY MORE (UFS 1.7d I2b).
# vfs_file.c and vfs_syscalls.c compile into the FAR KERNEL BANK
# -- see _KERNEL_FAR_C below and the reason there.  In one line: Mod_LoadConf
# opens files through _Fcb_Alloc, and Mod_LoadConf is what loads vfs.mod, so a
# file table inside vfs.mod is a boot that cannot start.
# The far bank's kernel C, and the descriptor layer it PUTs from src/kernel/vfs.
# Named once: the kernelc edges below build them, and the far link's PUT scan
# names their outputs as generated, since none of them exists in a clean
# checkout (apple/fgx#385).
_FAR_C = ("kc_probe", "vfs_seam", "dev_mount", "dev_nodes", "root_mount",
          "root_sysctl")
_FAR_VFS_C = ("vfs_file", "vfs_syscalls")
_VFS_C = ("vfs_bio", "bio_strategy", "dead_vnops",
          "vfs_subr", "kern_subr",
          "vfs_init", "vfs_lookup", "vfs_vnops",
          "vfs_probe", "dev_chrtoblk")

# The UFS half, in ufs.mod since apple/fgx#169.  Same `kernelc` rule, same
# flags; the split is about which module LINKS them, not how they are built.
_UFS_C = ("kern_time", "kern_flock", "kern_fsetattr", "ufs_sb", "ufs_dinode", "ufs_vfsops",
          "ufs_alloc", "ufs_bmap", "ufs_inode")

# ...and the NAME half, in ufsdir.mod since the UFS bank split.  Same `kernelc` rule and
# the same flags -- what changed is which module's link picks the .s up.  The
# seam was measured rather than chosen: 42 pile calls cross from these two
# translation units into the six above, and none come back.
_UFSDIR_C = ("ufs_vnops", "ufs_lookup", "spec_vnops", "vfs_cache")
# The ProDOS filesystem type, in prodos.mod (ProDOS FST P2).  Same rule, same
# flags.  Its write half is prodosw.mod since P6, when the two no longer fitted
# one bank; kern_time is the write half's clock, and kern_epoch the read
# half's date arithmetic.
_PRODOS_C = ("kern_epoch", "prodos_node", "prodos_vfsops", "prodos_vnops")
_PRODOSW_C = ("kern_time", "prodos_write")
# The ISO 9660 filesystem type, in isofs.mod.  Same rule, same flags;
# kern_epoch is its recording-date arithmetic, as it is prodos.mod's.
_ISOFS_C = ("kern_epoch", "isofs_node", "isofs_vfsops", "isofs_vnops",
            "isofs_rrip")
# spec_vnops JOINED ufsdir on 2026-09-05 and the move DELETED code rather than
# adding any.  ufs_vnops.c is its only caller -- it names all ten spec_* in its
# device-vnode ops vector -- and it lives here, so those ten were ten cross-bank
# shims in ufsdir/vfs_import.s reaching back into vfs.mod.  Same bank now: the
# shims are gone, the calls are direct, and the VFS bank gets back 5,482 bytes it
# had 267 of.  2.11BSD would not have asked which module OWNS the device vnodes;
# its own kernel config splits by call frequency and co-residency (vendored at
# vendor/2.11BSD/usr/sys/conf/Make.nsunix), and the caller is the co-resident.
#
# THE NAME CACHE IS HERE ON THE SAME RULE, and that is what made wiring it
# possible at all.  cache_lookup and cache_enter are called from ufs_lookup.c
# and from nowhere else, and every one of those calls reads the cache's state
# -- the buckets, the LRU, the pool.  Module C reaches its globals
# DBR-relatively, so the two halves cannot sit in different banks; the cache
# goes wherever its caller is, whole.  vfs.mod had 94 bytes free, which left
# one answer.  What crosses instead is the RARE direction: cache_purge on the
# vnode-id wrap and cache_purgevfs on unmount, both handed to vfs.mod by
# ufs_dirinit.

# ufsprobe.mod's C: the three probe gates, in their own bank since UFS 1.12c.
# Compiled by the SAME modulec_bank rule -- --module-bank takes no bank number,
# it marks the &function cells for _Mod_StampFnPtrs to fill at load time, so one
# compilation is correct in any module bank.
_UFSPROBE_C = ("ufs_probe", "ufs_vnprobe", "ufs_wprobe", "ufs_devprobe",
                "vnops_probe")

# The gates whose code is compiled into ufsprobe.mod.  The module is built and
# shipped only when one is on: with all of them off it has nothing to do, and
# loading it would hold a pool bank for nothing.  /etc/rc loads it when the
# image carries it.  tools/tryprobe.sh re-runs this generator after setting a
# gate.
_UFSPROBE_GATES = ("kernel.ufsprobe", "kernel.ufsvnprobe", "kernel.ufswprobe",
                   "kernel.ufsdevprobe", "kernel.vnopsprobe")


def _cfg_values(path="cfg/system.cfg"):
    """cfg/system.cfg's `key = value' lines, as tools/ninja/genconfig.py reads
    them."""
    vals = {}
    with open(os.path.join(ROOT, path)) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            vals[key.strip()] = val.strip()
    return vals



# ---------------------------------------------------------------------------
# THE /dev VOLUME'S NODES -- ONE SOURCE.  UFS 1.7d I3.
#
# Every number here is a CHARDEV REGISTRY INDEX, and a registry index is handed
# out in REGISTRATION ORDER: src/kernel/chardev.s's built-in block first, then
# whatever /etc/modload.conf loads, in its order.  Both are tracked, so the
# numbers are deterministic -- but NOTHING WOULD NOTICE IF EITHER MOVED, and
# the failure is a /dev/null that is silently a pty.
#
# So this list is the only place they are written down, and it feeds two
# things: the `mknod` commands that build disk/fgxdev.fs, and the generated
# src/kernel/far/dev_nodes.c the kernel checks against the LIVE registry at
# boot.  The image and the kernel's expectation cannot disagree; what boot
# tests is whether either of them still matches the machine.
#
# It does NOT catch fgxfs writing a different number than it was handed -- the
# ninja command and the generated table come from this one list, so that would
# be a defect in fgxfs, and ufs_devprobe's section (f) is where the platter's
# own rdev is asserted.
DEV_NODES = [
    ("null",    0),
    ("ptyp0",   1),
    ("ttyp0",   2),
    ("ptyp1",   3),
    ("ttyp1",   4),
    ("ttyv1",   5),
    ("ttyv2",   6),
    ("console", 7),
    ("tty",     8),
    ("tty01",  18),     # serial.mod, first in modload.conf of the two
    ("bpf0",   19),     # bpf.mod
]

# THE CARD'S CONSOLE -- /dev/ttyv3, VC_CARD, the last built-in (index 9) so
# console and tty keep theirs.  On the root only, for the reason
# RAW_DISK_NODES gives below: the separate /dev volume has no inode for it.
VC_DEV_NODES = [("ttyv3", 9)]


# Second names for one inode, made after every staged file is down.
# `(newpath, existingpath)'.
#
# uptime(1) IS w(1), which is how 2.11BSD ships it: `ln ${DESTDIR}/usr/ucb/w
# ${DESTDIR}/usr/ucb/uptime' (usr/ucb/Makefile:63, the same idiom as f ->
# finger), with w.c choosing the header-only form from argv[0].  A second copy
# of the binary would also work, and would be 61 KB of volume and a second
# inode, and `ls -l' would report link count 1 on both where a real system
# reports 2.
HARD_LINKS = [
    ("/bin/uptime", "/bin/w"),
    # `[' IS test(1): `ln ${DESTDIR}/bin/test ${DESTDIR}/bin/[' (usr/bin/test/
    # Makefile:25), with test.c requiring the closing `]' when argv[0] ends in
    # `['.  /etc/rc's autoboot arm is its first caller.
    ("/bin/[", "/bin/test"),
    # ree IS ee in restricted mode: `LINKS= ${BINDIR}/ee ${BINDIR}/ree'
    # (FreeBSD 2.2.8 usr.bin/ee/Makefile), ee.c testing argv[0] for "ree".
    ("/bin/ree", "/bin/ee"),
]


# THE MOUNT FIXTURE -- UFS 1.8b-2.  Two entries that are not devices in the
# sense the list above is, and are kept out of DEV_NODES for exactly that
# reason: every row of that list names a chardev registry index, and neither of
# these has one.
#
#   /mnt      an empty directory, because mount(2) needs something to cover and
#             the /dev volume had no directory but its own root.  Covering the
#             root is refused by upstream's reference-count test (Reno
#             `v_usecount != 1', 2.11BSD `i_count != 1'), and rightly.
#
#   /sd2      a BLOCK node naming the scratch volume, because getmdev resolves
#             the device by PATH and refuses anything but VBLK -- so a mount
#             cannot be driven at all without one.
#
# ITS UNIT IS BAKED AND THAT IS THE ONE THING THIS TREE DOES NOT DO.  mknod
# writes a number into an inode, and probe_dev.s says why a number is not
# evidence: "the emulator's numbering is not a promise about which image
# answers where", after an earlier probe wrote to whatever answered at index 1.
# The fixture cannot scan -- it is built on the host -- so the PROBE scans, and
# refuses with a case of its own when what it finds disagrees with what is
# baked here.  A baked number that is checked against a scan is evidence; a
# baked number that is trusted is the defect that rule exists to stop.
#
# Unit 2 is the harness's third spindle: 0 is the boot disk, 1 is this volume,
# and `extra_hards' appends the scratch after it (tools/mame_test/run.py).
DEV_MOUNTDIR = "mnt"
# THE SECOND MOUNT POINT IS `lost+found', WHICH mkfs ALREADY MADE.  The
# duplicate-device refusal (apple/fgx#269) cannot be asked on one directory:
# there, "this device is already mounted" and "this directory is already
# covered" are the same answer.  A second `mkdir' here is what the first cut
# did, and this volume is `mkfs --size 64' with SIXTEEN usable inodes, all of
# which are now spoken for -- `fgxfs mknod: out of inodes'.  Growing the
# volume would move the two words dev_mount.c IDENTIFIES it by, so the probe
# borrows the directory that was always there instead.  Nothing uses it: it is
# fsck's orphanage and there is no fsck on target.
DEV_BLKNODE  = "sd2"
DEV_BLKUNIT  = 2

# THE ROOT'S DISK NODES -- ONE PER UNIT THE BUS CAN CARRY, ATTACHED OR NOT.
#
# THIS IS MAKEDEV'S MODEL AND NOT A CONVENIENCE.  2.11BSD's
# `usr/etc/MAKEDEV' takes a unit and mints its nodes without asking whether a
# drive is there: its disk arm accepts `0|1|2|...|31' and runs
# `mknod ${name}${unit}a b $blk `expr $unit \'*\' 8 + 0`' through `h', so
# `sh MAKEDEV ra5' makes /dev/ra5a whether or not an RA5 exists.  The proof is
# on the volume this tree now mounts: the 2.11BSD machine's own /dev carries
# ra0 through ra6 and hk0 through hk1, while its /etc/fstab names only ra0 and
# ra1.  Five of those seven units have nothing behind them, and touching one
# answers EIO -- `mount /dev/ra5a /mnt' -> "Input/output error" -- rather than
# ENOENT.  THE NODE NAMES AN ADDRESS ON THE BUS.  It is not a claim that
# something answers there.
#
# WHAT THIS REPLACES, because the old shape is the reason a spacer disk
# existed.  There was ONE extra node, `sd2', baked at the unit the TEST HARNESS
# happened to leave free: run.py attaches disk/fgxdev.fs unconditionally, so
# the boot disk took unit 0, that volume took unit 1, and a test's own spindle
# landed on unit 2.  The node was cut to fit that, and its comment said as much
# -- "unit 2 is the harness's third spindle".  The cost was paid by anyone NOT
# running the harness: `mame-hd.sh <boot> <volume>' puts the volume on s7d2,
# which is unit 1, which had no node -- so the volume could not be named at
# all, and the workaround was to pass a disk nobody wanted in between.  A
# device node numbered for one caller's layout is not a device node.
#
# EIGHT, because that is what the slot-7 card carries: retronet and the
# MicroDrive both take -hard1..-hard8 (mame-hd.sh, MAXDISKS), so unit 7 is the
# last one a drive can occupy on this machine.  The SmartPort BUS addresses far
# more -- dev.s scans to $7E, SmartPort's own maximum -- and 126 nodes would be
# 126 inodes and directory entries to describe drives no card here can hold.
# MAKEDEV stops at 32 for the same kind of reason and a real /dev stops lower
# still; a well-stocked IIgs has seven.
#
# UNIT 0 IS STRUCTURAL AND THE REST ARE ENUMERATED, which is worth keeping
# straight now that they are one list.  root_mount.c bakes `ROOT_UNIT 0' with
# the reason "THE BOOT DEVICE IS UNIT 0 AND IS NOT SCANNED FOR.  Blk_Init
# registers it as _devTable[0] before any enumeration runs."  So /dev/sd0 is
# the volume the machine booted from by construction, and sd1..sd7 name
# whatever the scan finds -- or nothing.  ufs_statfs still derives the name it
# prints from the mounted device's own rdev rather than from this list, so
# df(1) cannot disagree with the device the filesystem is actually on.
#
# NOT ON disk/fgxdev.fs.  That volume is `mkfs --size 64' with sixteen inodes,
# all of them already spoken for -- `fgxfs mknod: out of inodes' is what the
# last attempt to add one said.  It is also the ProDOS-era separate /dev, which
# the root's own /dev replaced; adding to it would be growing the thing being
# retired.
ROOT_BLKUNITS = range(0, 8)

# THE RAW DISKS -- /dev/rsd<u>, one per ROOT_BLKUNITS node.  apple/fgx#330.
#
# A SECOND LIST AND NOT MORE DEV_NODES ROWS, because that list feeds three
# consumers and these belong to only two of them.  dev_nodes.c must carry them
# (it is this list's statement of what the image holds) and the ROOT must carry
# them (fsck rawifies the name of every filesystem that is not the mounted
# root, so /dev/rsd<u> is the node it opens).  The separate /dev VOLUME must
# NOT: disk/fgxdev.fs is `mkfs --size 64' with sixteen inodes and every one is
# spoken for -- `fgxfs mknod: out of inodes' is what the last attempt to add
# one said -- and it is the ProDOS-era volume the root's own /dev replaced.
#
# THE INDICES FOLLOW THE BUILT-INS AND PRECEDE THE MODULES, because that is the
# order the machine registers in: _Chardev_InitBuiltins takes 0..9 (ttyv3 is
# its last), the raw disks are registered from the same boot sequence right
# after it, and modload.conf's chardevs are loaded by /sbin/modload out of
# /etc/rc -- after the whole kernel init -- so serial.mod and bpf.mod land at
# 18 and 19.  That is why DEV_NODES gives tty01 and bpf0 those numbers rather
# than 10 and 11.
RAW_DISK_NODES = [(f"rsd{u}", 10 + u) for u in ROOT_BLKUNITS]

# MODULE DEVICES THAT ARRIVED AFTER THE /dev VOLUME FILLED -- on the root only,
# for the reason RAW_DISK_NODES is: disk/fgxdev.fs has no inode left for them.
# Mode 600 for cda: loading a desk accessory is root's business, as BSD's
# /dev/lkm is.
#
# A MODULE'S NUMBER IS FIXED, NOT ITS REGISTRATION ORDER.  These numbers, with
# DEV_NODES' tty01 and bpf0, are generated into include/devnodes.s
# (write_devnodes_s below), and each module registers AT its number
# (CDF_FIXED, include/chardev.s) -- the way a BSD driver's cdevsw major is a
# compile-time constant.  Until 2026-09-18 the registry handed a module the
# next free index and these lists merely predicted the order: on a machine
# whose control panel gives slot 7 to a card rather than AppleTalk, serial.mod
# attaches SCC channel A as tty00 before channel B, every later index moved up
# by one, and /dev/cda named bpf0 -- loadcda's `Inappropriate ioctl for
# device', seen on the second machine and on none of the harness runs.
# tty00 exists only on such a machine; its slot stays empty elsewhere, and
# opening the node answers ENXIO (_Chardev_Open).
MODULE_DEV_NODES = [("cda", 20), ("tty00", 21), ("klog", 22)]
MODULE_DEV_MODES = {"cda": 600}      # the rest are 666, as tty01 is



def devvol_command(img):
    """The mknod pipeline that builds the /dev volume, from DEV_NODES.

    THE IMAGE PATH IS SPELLED OUT rather than `$out`: ninja makes $in/$out
    available inside a rule's `command`, not inside an EDGE-level variable
    binding, so a $out here expands to nothing and mkfs is handed its next
    argument as a filename.  Measured, not assumed -- that is what the first
    cut did, and `fgxfs mkfs: unknown option 64` is what it said.
    """
    parts = [f"python3 tools/fgxfs.py mkfs {img} --size 64"]
    parts += [f"python3 tools/fgxfs.py mknod {img} /{n} c {r} 666"
              for n, r in DEV_NODES]
    parts += [f"python3 tools/fgxfs.py mkdir {img} /{DEV_MOUNTDIR}"]
    parts += [f"python3 tools/fgxfs.py mknod {img} /{DEV_BLKNODE} b "
              f"{DEV_BLKUNIT} 600"]
    return " && ".join(parts)


def write_devnodes_s(path="include/devnodes.s"):
    """Emit the device numbers as assembler EQUs for the modules that register
    at them.  One row per node of every list, DEVNODE_<NAME> in upper case,
    so a module's registration and the mknod that made its node come from
    the same line of this file."""
    out = []
    out.append("; devnodes.s -- the /dev nodes' device numbers, as the build made them.")
    out.append(";")
    out.append("; WRITTEN BY tools/ninja/gen.py FROM ITS DEV_NODES LISTS.  Edit the lists")
    out.append("; there; this file is regenerated whenever build.ninja is.  A module that")
    out.append("; owns one of these nodes registers AT this number (CDF_FIXED,")
    out.append("; include/chardev.s), so the number on the volume and the slot in the")
    out.append("; live registry cannot drift apart with the order modules load in.")
    for n, r in DEV_NODES + VC_DEV_NODES + RAW_DISK_NODES + MODULE_DEV_NODES:
        out.append("DEVNODE_%-12s EQU     %d" % (n.upper(), r))
    write_if_changed(path, "\n".join(out) + "\n")


def write_dev_nodes_c(path="src/kernel/far/dev_nodes.c"):
    """Emit the far bank's copy of DEV_NODES, as C the kernel walks at boot.

    A FUNCTION AND NOT A TABLE, because kernel C cannot hold an initialised
    aggregate with pointers in it (apple/fgx#88) and a name IS a pointer.  An
    if-chain returning string literals is what fcc will take.
    """
    out = []
    out.append("/* SPDX-License-Identifier: BSD-2-Clause")
    out.append(" * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the"
               " FGX contributors")
    out.append(" */")
    out.append("/* FGX-Origin: original -- FGX code.  GENERATED, do not edit.")
    out.append(" */")
    out.append("/* dev_nodes.c -- the /dev volume's nodes, as the build made"
               " them.  UFS 1.7d I3.")
    out.append(" *")
    out.append(" * WRITTEN BY tools/ninja/gen.py FROM DEV_NODES.  Edit the"
               " list there; this")
    out.append(" * file is regenerated whenever build.ninja is, and the same"
               " list writes the")
    out.append(" * mknod commands that put these numbers on the volume -- so"
               " the image and")
    out.append(" * this table cannot disagree with each other.  The built-in"
               " and raw-disk")
    out.append(" * indices are the kernel's registration order, which is"
               " fixed; a module's")
    out.append(" * is the number it registers AT (CDF_FIXED, from the same"
               " list through")
    out.append(" * include/devnodes.s), so modload.conf's order cannot"
               " move it.")
    out.append(" */")
    out.append("")
    out.append("/* dev_nodeat -- the i'th node's name, with its rdev through"
               " `rdevp'.")
    out.append(" * Returns 0 past the end, which is how the caller's loop"
               " terminates. */")
    out.append("char *")
    out.append("dev_nodeat(i, rdevp)")
    out.append("int  i;")
    out.append("int *rdevp;")
    out.append("{")
    for k, (n, r) in enumerate(DEV_NODES + VC_DEV_NODES + RAW_DISK_NODES
                               + MODULE_DEV_NODES):
        out.append(f'    if (i == {k:2d}) {{ *rdevp = {r:2d}; '
                   f'return ("{n}"); }}')
    out.append("    return ((char *)0);")
    out.append("}")
    out.append("")
    write_if_changed(path, "\n".join(out))


def write_dev_chrtoblk_c(path="src/kernel/vfs/dev_chrtoblk.c"):
    """Emit chrtoblk(), the raw-disk node's block counterpart.

    2.11BSD keeps this mapping in a per-machine table (usr/sys/pdp/conf.c's
    `chrtoblktbl', indexed by CHARACTER MAJOR, yielding a BLOCK MAJOR with the
    minor carried across).  FGX has no major/minor split -- an rdev IS the
    device index -- so the pair that table encodes, "which driver and which
    unit", is the pair RAW_DISK_NODES and ROOT_BLKUNITS already state.

    GENERATED FOR THE REASON dev_nodes.c IS.  The character index depends on
    how many built-in chardevs registered ahead of the raw disks, and that
    count moves when chardev.s is reordered -- silently, since nothing about a
    wrong answer here looks wrong.  Writing it from the same two lists that
    mint the nodes means the mapping cannot disagree with the image; nothing
    checks at boot whether those lists still agree with the live registry.
    """
    out = []
    out.append("/* SPDX-License-Identifier: BSD-2-Clause")
    out.append(" * SPDX-FileCopyrightText: Copyright (c) 2026 flux and the"
               " FGX contributors")
    out.append(" */")
    out.append("/* FGX-Origin: original -- FGX code.  GENERATED, do not edit.")
    out.append(" */")
    out.append("/* dev_chrtoblk.c -- a raw disk's block counterpart."
               "  apple/fgx#410.")
    out.append(" *")
    out.append(" * WRITTEN BY tools/ninja/gen.py FROM RAW_DISK_NODES and"
               " ROOT_BLKUNITS.  Edit")
    out.append(" * the lists there; the same lists mknod the nodes onto the"
               " root, so this")
    out.append(" * table and the image cannot disagree.")
    out.append(" *")
    out.append(" * THE ONLY CALLER IS spec_securechr, the securelevel gate:"
               " a character")
    out.append(" * device may not be opened for writing at level 1 while a"
               " filesystem is")
    out.append(" * mounted on the block device behind it, and this is what"
               " says which block")
    out.append(" * device that is.")
    out.append(" */")
    out.append("")
    out.append("#include \"vnode.h\"")
    out.append("")
    out.append("/* chrtoblk -- the block rdev behind a character rdev, or"
               " NODEV.")
    out.append(" * 2.11BSD usr/sys/pdp/conf.c:563. */")
    out.append("dev_t")
    out.append("chrtoblk(dev)")
    out.append("dev_t dev;")
    out.append("{")
    for name, chr_rdev in RAW_DISK_NODES:
        blk = int(name[len("rsd"):])
        out.append(f"    if (dev == {chr_rdev:2d}) return ((dev_t){blk:2d});"
                   f"   /* {name} -> sd{blk} */")
    out.append("    return ((dev_t)NODEV);")
    out.append("}")
    out.append("")
    write_if_changed(path, "\n".join(out))


def sh(cmd):
    return subprocess.run(cmd, cwd=ROOT, shell=True, capture_output=True,
                          text=True).stdout


def parse_tools():
    """Read the tool table from tools/ninja/manifest.json.

    This USED to parse build.sh directly.  The manifest was extracted from it
    once (2026-07-28) and is now the source of truth, which is what let build.sh
    be deleted rather than merely shrunk.  Extraction beat retyping: the graph
    started from exactly what build.sh built, and proved it -- 131
    byte-identical binaries and identical disk catalogs.

    Fields: name, flags (fcc), fmt (default FGX3), tu_list, libs, seg3_tus,
    seg4_tus, yacc, static, main (the entry TU when it is not
    src/userland/<name>/<name>.c), commons (K&R tentative definitions shared
    across TUs, coalesced by gen_commons), pack (the linker packs every TU but
    the entry into code segments itself), split (one entry TU too big for a
    bank: compiled with --sections and its functions packed one by one),
    stack_pad (bytes), gen + gen_script
    (headers the script writes, given their directory, before any compile;
    gen_deps are what it reads)."""
    man = json.load(open(os.path.join(HERE, "manifest.json")))
    covered = {}
    for t in man["tools"]:
        covered[t["name"]] = dict(
            name=t["name"], flags=t.get("flags", ""), fmt=t.get("fmt", "FGX3"),
            tu_list=t.get("tu_list", ""), libs=t.get("libs", ""),
            seg3_tus=t.get("seg3_tus", []),
            seg4_tus=t.get("seg4_tus", []),
            yacc=t.get("yacc", False),
            static=t.get("static", False),
            main=t.get("main", ""), commons=t.get("commons", False),
            pack=t.get("pack", False), split=t.get("split", False),
            stack_pad=t.get("stack_pad", 0),
            gen=t.get("gen", []), gen_script=t.get("gen_script", ""),
            gen_deps=t.get("gen_deps", []))
    return covered, {}


def direct_link_edges(lines, name, kind, src, tus, rec):
    """The compile edges of a tool linked by fgx_dyn or fgx_static, and its
    segment lists: (code0, codesegs, data, alls).  seg3_tus and seg4_tus
    become further code segments."""
    b = f"tools/{name}-fgx2"
    os.makedirs(os.path.join(ROOT, b), exist_ok=True)
    tu_stems = [os.path.basename(t)[:-2] for t in tus]
    flags = (" " + rebase_flags(rec["flags"])) if rec["flags"] else ""
    if rec["split"]:
        if kind == "static":
            raise SystemExit(f"{name}: split is fgx_dyn's (a dynamic tool)")
        if tus or rec["pack"]:
            raise SystemExit(f"{name}: split packs the entry TU's functions; "
                             f"it takes no tu_list or pack")
        flags += " --sections"
    scc = os.path.join("src", "softscc", f"{name}.txt")
    softscc = ("$$PWD/" + scc) if os.path.exists(os.path.join(ROOT, scc)) else ""
    sccdep = f" {scc}" if softscc else ""
    lines.append(f"\n# ---- {name} ({kind}) " + "-" * 40)
    gen = "".join(" " + g for g in rec["gen"])
    if rec["gen"]:
        gdeps = sorted({rel(p) for g in rec["gen_deps"]
                        for p in glob.glob(os.path.join(ROOT, g))})
        lines.append(f"build{gen}: genhdr {rec['gen_script']} | {' '.join(gdeps)}\n"
                     f"  dir = {os.path.dirname(rec['gen'][0])}")
    sigs = f"{b}/{name}.sigs"
    lines.append(f"build {sigs}: progsigs {src} {' '.join(tus)} | $fcc build/libc.sigs{gen}\n"
                 f"  flags ={flags}")
    comms = []
    for s_, stem in [(src, name)] + list(zip(tus, tu_stems)):
        comm = f"{b}/{stem}.comm" if rec["commons"] else ""
        comms += [comm] if comm else []
        lines.append(
            f"build {b}/{stem}.s | {b}/{stem}.data.s{' ' + comm if comm else ''}: "
            f"fcc_c {s_} | $fcc {sigs}{sccdep}{gen}\n"
            f"  data = {b}/{stem}.data.s\n  flags ={flags}\n  softscc = {softscc}\n"
            f"  sigs = {sigs}" + (f"\n  commons = --commons {comm}" if comm else ""))
    seg3 = set(rec.get("seg3_tus", []))
    seg4 = set(rec.get("seg4_tus", []))
    unknown = (seg3 | seg4) - set(tu_stems)
    if unknown:
        raise SystemExit(f"{name}: seg3_tus/seg4_tus names TUs not in the "
                         f"tu.list: {sorted(unknown)}")
    if seg3 & seg4:
        raise SystemExit(f"{name}: TUs in BOTH seg3_tus and seg4_tus: "
                         f"{sorted(seg3 & seg4)}")
    if rec["pack"] and (seg3 or seg4):
        raise SystemExit(f"{name}: pack places every TU itself; drop seg3_tus/seg4_tus")
    if rec["pack"]:
        # fgx_pack fills segment 0's room after the entry TU, then further
        # code segments, so no hand-kept segment lists go stale.
        code0 = [f"{b}/{name}.s"]
        codesegs = " --pack " + ",".join(f"{b}/{t}.s" for t in tu_stems)
    else:
        code0 = [f"{b}/{name}.s"] + [f"{b}/{t}.s" for t in tu_stems if t not in seg3 | seg4]
        codesegs = "".join(
            " --code-seg " + ",".join(f"{b}/{t}.s" for t in tu_stems if t in grp)
            for grp in (seg3, seg4) if grp)
    stub = os.path.join("src/userland", name, f"{name}_stubs.s")
    if os.path.isfile(os.path.join(ROOT, stub)):
        code0.append(stub)
    if rec["split"]:
        codesegs += " --split"
    if rec["stack_pad"]:
        codesegs += f" --stack-pad {int(rec['stack_pad'])}"
    data = [f"{b}/{name}.data.s"] + [f"{b}/{t}.data.s" for t in tu_stems]
    if comms:
        # A tentative yields to a definition the linker assembles unpruned:
        # fgx_static keeps fgx_libso's DATA and crt0_lib_data.s (not
        # libc_so_data.s or libfgx's data, which it prunes -- a tentative
        # yielding to a pruned datum would leave the label undefined).
        # fgx_dyn binds library data exports itself, so only the runtime's.
        if kind == "static":
            out = subprocess.run(["python3", "toolchain/src/ld/fgx_libso.py", "--print-data"],
                                 cwd=ROOT, check=True, capture_output=True, text=True).stdout
            ext = [os.path.relpath(f, ROOT) for f in out.split()] + ["toolchain/lib/crt0_lib_data.s"]
        else:
            ext = ["toolchain/lib/fcc_runtime_data.s"]
        lines.append(f"build {b}/commons.data.s: gencommons {' '.join(comms)} | "
                     f"toolchain/tools/gen_commons.py {' '.join(ext)}\n"
                     f"  ext = {' '.join('--extern-defs ' + e for e in ext)}")
        data.append(f"{b}/commons.data.s")
    alls = code0 + ([f"{b}/{t}.s" for t in tu_stems] if rec["pack"] else
                    [f"{b}/{t}.s" for t in tu_stems if t in seg3 | seg4])
    return code0, codesegs, data, alls


def derived_map():
    """Fixtures minted from another binary by editing bytes -- see derive.py."""
    man = json.load(open(os.path.join(HERE, "manifest.json")))
    return [(d["name"], d["from"], d.get("what", d["name"]))
            for d in man.get("derived", [])]


def staging_map():
    """source -> disk_src destination, from the same manifest."""
    man = json.load(open(os.path.join(HERE, "manifest.json")))
    return [(e["src"], e["dst"]) for e in man["staging"]]


def rebase_flags(flags):
    """Translate build.sh's fcc flags from build-dir-relative to root-relative.

    build.sh runs fcc with cwd=tools/<name>-fgx2, so its paths are written
    `-I../../examples/...`; ninja runs every command from the REPO ROOT, where
    that resolves two levels too high.  Same root cause as the --data-segment
    bug that produced a false byte-identical result: any path inherited from
    build.sh carries build.sh's cwd assumption and must be rebased."""
    out = []
    for tok in shlex.split(flags):
        for pre in ("-I", "-L"):
            if tok.startswith(pre) and tok[len(pre):].startswith("../../"):
                tok = pre + tok[len(pre) + 6:]
                break
        out.append(tok)
    return " ".join(out)


def read_tu_list(path):
    """One repo-relative .c per line, '#' comments -- same as build.sh."""
    out = []
    for line in open(os.path.join(ROOT, path)):
        line = line.split("#")[0].strip()
        if line:
            out.append(line)
    return out


def local_tz():
    """The zone named in .fgx_tz (untracked, one line), or None."""
    try:
        with open(os.path.join(ROOT, ".fgx_tz")) as f:
            return f.read().strip() or None
    except OSError:
        return None


def write_if_changed(path, text):
    """Write only when the content actually differs.

    The generator rewrites files that are INPUTS to build edges (build.ninja,
    the staged lists).  Rewriting them unconditionally makes every
    regeneration newer than every output, so the whole graph goes dirty --
    which silently defeated test SELECTION: running gen.py before measuring
    turned a 1-test change into 302.  The disk image's /etc/rc has the same
    self-invalidation shape."""
    try:
        if open(path).read() == text:
            return False
    except OSError:
        pass
    # The destination directory may not exist yet.  build/ is gitignored, so it
    # is present on any machine that has ever built and ABSENT in a clean
    # checkout -- which is why `build/staged.list` broke CI (job 479) while
    # every local run was fine.  Create it rather than assuming it.
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as fh:
        fh.write(text)
    return True



def write_dev_nodes_list(path="build/dev_nodes.list"):
    """Emit DEV_NODES as a table tools/make_ufsboot.sh can drive mknod from.

    THE SAME LIST, A THIRD CONSUMER.  DEV_NODES already writes the mknod
    pipeline for the separate /dev volume and dev_nodes.c for the kernel's own
    walk; campaign 2.5 puts the nodes in the ROOT instead, and a shell script
    cannot import this module.  So the list is emitted rather than retyped:
    a second copy in make_ufsboot.sh is exactly the disagreement dev_nodecheck
    exists to catch, and it would be one nobody could see until a device node
    opened the wrong driver.

    One entry per line, `type path dev mode', with `d' for the directory the
    mount fixture needs and no dev number of its own.
    """
    out = ["# GENERATED by tools/ninja/gen.py from DEV_NODES -- do not edit.",
           "d /dev - -"]
    out += [f"c /dev/{n} {r} 666" for n, r in DEV_NODES]
    # NO MOUNT DIRECTORY HERE, AND THAT IS THE DIFFERENCE BETWEEN THE TWO
    # VOLUMES.  devvol_command makes one because the /dev volume had no
    # directory but its own root to cover, so its fixture mount point could
    # only be `/mnt' ON THAT VOLUME -- reached as /dev/mnt once it was mounted
    # at /dev.  The ROOT already has `/mnt', staged from disk_src/mnt (kept by
    # a .gitkeep, so it is not an artifact of one machine's tree), and that is
    # the one every mount test names: ufsmount.json mounts on /mnt and reads
    # the second filesystem back through it.
    #
    # Emitting the row here anyway put a SECOND, unreferenced `mnt' inside
    # /dev, which is what this line used to do.  Nothing mounted on it and
    # nothing looked for it: the /dev VOLUME's boot mount is gone (main.s
    # mounts the root and nothing else, as 2.11BSD's kernel does), so the path
    # it was named for cannot be reached at all.
    out += [f"b /dev/sd{u} {u} 600" for u in ROOT_BLKUNITS]
    # THE RAM DISK, block major 1 (RAM_MAJOR, src/kernel/vfs/fsparam.h) minor
    # 0: 256.  The sd nodes are major 0 (SD_MAJOR), so their number is the
    # unit alone.
    out += ["b /dev/ram0 256 600"]
    # THE CD-ROMS, block major 2 (CD_MAJOR): one node per unit the scan can
    # attach (BDEV_NCD in include/fs.s), attached or not, as the sd nodes are.
    # 400: the medium is read-only.
    out += [f"b /dev/cd{u} {512 + u} 400" for u in range(4)]
    # The raw disks beside the block nodes they name -- see RAW_DISK_NODES.
    # 600 like the block nodes: reading a spindle past the filesystem on it is
    # root's business, which is 2.11BSD's own mode for /dev/rra0a.
    out += [f"c /dev/{n} {r} 666" for n, r in VC_DEV_NODES]
    out += [f"c /dev/{n} {r} 600" for n, r in RAW_DISK_NODES]
    out += [f"c /dev/{n} {r} {MODULE_DEV_MODES.get(n, 666)}"
            for n, r in MODULE_DEV_NODES]
    # THE SYMLINK FIXTURE.  A `l' row's dev column is the TARGET, since a link
    # has no device number -- make_ufsboot passes it as the target and the
    # mode column is unused (a symlink is always 0777).
    #
    # /etc/pw-link EXISTS TO BE STATTED, and there is no other symlink on the
    # volume to do it with: lstat(2), readlink(2) and ls's 'l' arm are all
    # unobservable without one, and ufs_symlink has been a live vnodeop since
    # UFS 1.13a with nothing on any FGX volume exercising it.  /etc/passwd is
    # the target because it is small, shipped and stable.
    out.append("l /etc/pw-link /etc/passwd -")
    # HARD LINKS.  An `h' row's dev column is the EXISTING path; the mode
    # column is unused, a link having no attributes of its own -- the inode
    # already carries them.  The row must come after the file it names is on
    # the volume, which it does: this table is walked once every staged file
    # is down.
    out += [f"h {new} {old} -" for new, old in HARD_LINKS]
    # THE TEST ACCOUNT'S HOME.  `fgx' is the user /etc/passwd carries for
    # testing (uid 100, group staff, wheel, /bin/tcsh).  Its home is made here
    # rather than staged from disk_src for two reasons.  A staged directory
    # needs a .gitkeep to survive git, and that file would ship -- /root
    # already carries one and it is the only thing on the volume nobody asked
    # for.  And a staged inode is root-owned: ialloc takes a mode and no owner,
    # so a home made that way is one its user cannot write in, which is not a
    # test account.
    #
    # AN `o' ROW IS A chown, and it must follow the `d' rows that make the
    # path.  make_ufsboot.sh walks this table in order.
    #
    # /home AND NOT 2.11BSD's /usr/guest (2026-09-13).  The shipped
    # /etc/passwd still carries `/usr/guest/operator' from upstream and that
    # row is left alone -- it is a pseudo-account with no password and no
    # directory on this volume -- but a real login directory goes where anyone
    # would look for one.
    out.append("d /home - -")
    out.append("d /home/fgx - -")
    out.append("o /home/fgx 100 10")
    write_if_changed(os.path.join(ROOT, path), "\n".join(out) + "\n")

def rel(p):
    return os.path.relpath(p, ROOT)


HEADER = """\
# GENERATED by tools/ninja/gen.py -- do not edit.
# Regenerate:  python3 tools/ninja/gen.py
ninja_required_version = 1.10

fcc     = toolchain/fcc
scheck  = toolchain/tools/stack_check.py
flags   =
sigs    = build/libc.sigs
commons =

# fcc emits its own header deps (-MD), so ninja tracks #include edges natively.
#
# $softscc (bank-0 stack campaign 1.3) names the committed list of this
# binary's recursion-cycle functions, which fcc gives data-bank frames.  It
# defaults EMPTY, and an empty FCC_SOFT_SCC means nothing is soft and codegen
# is bit-identical -- so a binary with no src/softscc/<name>.txt is untouched.
# THE LIBC SIGNATURE SIDECAR (apple/fgx#327).  K&R C has no prototypes, so a
# source that calls a libc function it never declared -- which is every verbatim
# 2.11BSD port -- pushes each argument at its OWN width.  On a PDP-11 that is
# harmless (int, pointer and size are all 2 bytes).  Here a pointer is 4 and
# malloc's size is 4, so `realloc(p, n)' sends two bytes where the callee reads
# four, the high half is stack residue, and realloc rejects any size >= $F000:
# `ls: out of memory' on a 21 KB binary with a 64 KB heap.
#
# fcc already does the right thing when it KNOWS the parameter types; all that
# was missing was the knowledge.  --emit-sigs/--sigs (symtab.c) carries it
# across translation units, so libc's are harvested once:
# one pass over the pile harvests its signatures, and one over libfgx's (spawnv,
# ticks, mm_alloc, ...), and every userland TU loads them.
# The TU's OWN declarations still win (funcs_declare promotes a definition in
# place and a real prototype overwrites), so a port that declares malloc itself
# is unaffected -- an empty-paren `char *malloc();' correctly keeps the richer
# loaded one, which is the whole point.
#
# Measured over all 241 fcc_c edges: 4 change codegen, and all four are latent
# bugs the sidecar fixes -- dstest's `time(0)' (param is long *), fsck pass1's
# `bcmp(dp->di_addr, ...)' (int where a pointer is read), and midwrite's and
# touch's `lseek(...)' comparisons, which were being done SIXTEEN BITS WIDE
# against a 32-bit offset.  The other 237 are byte-identical.
rule libcsigs
  command = rm -f $sigs $out.d.new && for f in $in; do $fcc --emit-sigs $sigs --pile $$f -o $out --data-segment /dev/null -MD -MF $out.d.tmp || exit 1; sed "1s|^[^:]*:|$out:|" $out.d.tmp >> $out.d.new; done && mv $out.d.new $out.d && rm -f $out.d.tmp
  depfile = $out.d
  deps = gcc
  description = libc signatures -> $sigs

build build/libc.sigs.s | build/libc.sigs: libcsigs toolchain/lib/libc_c/libc_c.c toolchain/lib/libfgx_c/libfgx.c | $fcc
  sigs = build/libc.sigs

# A tool's OWN functions need the same: a call into another of its TUs, or to a
# function defined further down the same file, is just as unprototyped.  Each
# tool's table is every definition in its TUs, then libc's; all of its TUs
# compile against it.  The tool's own come FIRST because the first line for a
# name wins, and a program's definition of a name libc also has is the one the
# linker binds (strong over LIBC).  --emit-sigs appends, hence the rm.
# Headers a port's own build makes from its source (tcsh's, as its Makefile
# makes them), written before any of its TUs compile.
rule genhdr
  command = sh $in $dir
  description = generated headers -> $dir

# K&R A.10.2: a program's tentative definitions across all of its TUs are
# considered together -- one zeroed definition each, unless some TU or a
# library datum defines it.  fcc --commons writes each TU's to a sidecar.
rule gencommons
  command = rm -f $out && python3 toolchain/tools/gen_commons.py $ext $out $in > /dev/null
  description = commons -> $out

rule progsigs
  command = rm -f $out.tmp $out.d.new && for f in $in; do $fcc $flags --emit-sigs $out.tmp --data-segment /dev/null -o /dev/null $$f -MD -MF $out.tmp.d || exit 1; sed "1s|^[^:]*:|$out:|" $out.tmp.d >> $out.d.new; done && cat build/libc.sigs >> $out.tmp && mv $out.d.new $out.d && rm -f $out.tmp.d && mv $out.tmp $out
  depfile = $out.d
  deps = gcc
  description = signatures -> $out

rule fcc_c
  command = FCC_SOFT_SCC=$softscc $fcc $flags $commons --sigs $sigs --data-segment $data -o $out $in -MD -MF $out.d && python3 $scheck $out > /dev/null
  depfile = $out.d
  deps = gcc
  description = fcc $in

# merlin32 has no depfile support, so PUT-closure deps are computed at
# generation time and listed explicitly on each edge.  It also insists on
# writing <seg>_Output.txt beside the source, hence the cd + mv.
rule merlin
  command = cd $dir && merlin32 -V . $link > /dev/null 2>&1 && mv ${seg}_Output.txt ${seg}.lst
  description = merlin32 $link

# merlin32 assembles the kernel from the repo root and litters its listings
# there; move them into build/ so the tree stays clean (build.sh did the same).
#
# THIS EDGE COULD NOT FAIL until 2026-07-31.  It was
#   merlin32 ... > /dev/null 2>&1 && mv fgx bin/fgx.bin && for ...; done; true
# -- output discarded, and a trailing `; true` (there to absorb the for-loop's
# status when the last [ -f ] test is false) that ALSO absorbed merlin32's.  A
# kernel that failed to assemble left the PREVIOUS bin/fgx.bin in place and
# reported success, so every downstream edge, the smoke test and the gate all
# ran green against a stale kernel.  Found because memmap.s's new arena/DP
# geometry ERR guards fired correctly in merlin32 and the build stayed green
# anyway -- i.e. the bug was hiding the very guards added to catch it.
#
# Now: capture the status, ALWAYS move the listings (they are the diagnosis, and
# merlin32 writes error_output.txt only on failure), print the log and exit
# non-zero if it failed, and only then publish bin/fgx.bin.
rule kernel
  command = L=src/kernel/link/core; rm -f $$L/fgx_S01_KernelMain_Output.txt $$L/fgx_S02_BlockDriver_Output.txt $$L/_FileInformation.txt $$L/error_output.txt build/_FileInformation.txt build/error_output.txt; rc=0; merlin32 -V $$L/fgx.link.s > build/merlin_kernel.log 2>&1 || rc=$$?; for f in fgx_S01_KernelMain_Output.txt fgx_S02_BlockDriver_Output.txt _FileInformation.txt error_output.txt; do [ -f "$$L/$$f" ] && mv "$$L/$$f" build/; done; if [ $$rc -ne 0 ]; then cat build/merlin_kernel.log; exit $$rc; fi; mv $$L/fgx bin/fgx.bin
  description = merlin32 kernel

# EVERY STATIC LINK CLEARS THE SHARED DIAGNOSTIC NAMES FIRST -- apple/fgx#203's
# residual, measured 2026-08-26.  merlin32 writes `_FileInformation.txt' and
# `error_output.txt' beside the link file and all three rules move them into build/,
# but a link that SUCCEEDS writes no error listing at all -- so the last FAILED
# build's copy survived and read as if it belonged to the current one.  Measured:
# build/error_output.txt stamped 15:39 (a deliberate kcprobe=0 failure) still sat
# beside a bin/fgx.bin from 16:04, eleven megabytes of it.  A reader diagnosing a
# build opens that file.  Clearing both the root staging names AND the build/
# destinations means its PRESENCE is now evidence that this build wrote it.
#
# EACH LINK FILE HAS A DIRECTORY OF ITS OWN (src/kernel/link/{core,far,tty}).
# Merlin32 resolves a link file's ASM paths, and writes its image and listings,
# relative to the link file's directory, so no two links write the same name.
#
# The listings themselves cannot be mixed up between banks any more: the far link
# consumes src/kernel/far/kernel_exports.s, which is generated from the kernel
# link's own listing, so the three static links are already strictly ordered --
# kernel, then far (see the order-only edge on the tty link below).
#
# The FAR kernel bank (docs/history/plans/far-kernel-bank.md): a SECOND link unit, not a third
# segment of the core link.  Merlin32 concatenates a link file's segments into ONE
# image at ONE ORG, so a third segment would share the core bank's ceiling and
# buy nothing; a separate link gets its own ceiling and its own listing.
#
# Same failure discipline as `kernel` above -- capture the status, ALWAYS move
# the listing, print the log and exit non-zero on failure, publish only then.
# Single-segment links emit _Output.txt (not fgxfar_S01_*), same as the modules.
#
# Each writes `_Output.txt' in its own link directory, so the two listings
# cannot cross.  When both links ran at the repo root they did: the tty bank's
# listing arrived as build/fgxfar_Output.txt, and the far bankpatch check then
# reported the table "drifted" from 40 entries to 8 -- a regenerated table of
# the wrong bank's addresses, which _Mod_StampFnPtrs turns into one byte of
# corruption at N arbitrary offsets.  The two links still share the build/
# names their diagnostics are moved to, so the tty edge keeps an order-only
# dependency on bin/fgxfar.bin (see the edge itself).
#
# The `rm -f` is the second half: a stale _Output.txt left by a link that died
# before writing one would otherwise be published as this run's listing.
rule kernelfar
  command = L=src/kernel/link/far; rm -f $$L/_Output.txt $$L/_FileInformation.txt $$L/error_output.txt build/_FileInformation.txt build/error_output.txt; rc=0; merlin32 -V $$L/fgxfar.link.s > build/merlin_kernelfar.log 2>&1 || rc=$$?; [ -f $$L/_Output.txt ] && mv $$L/_Output.txt build/fgxfar_Output.txt; for f in _FileInformation.txt error_output.txt; do [ -f "$$L/$$f" ] && mv "$$L/$$f" build/; done; if [ $$rc -ne 0 ]; then cat build/merlin_kernelfar.log; exit $$rc; fi; mv $$L/fgxfar bin/fgxfar.bin
  description = merlin32 far kernel bank

# The TTY kernel bank (docs/history/plans/tty-kernel-bank.md): a THIRD link unit, same shape.
rule kerneltty
  command = L=src/kernel/link/tty; rm -f $$L/_Output.txt $$L/_FileInformation.txt $$L/error_output.txt build/_FileInformation.txt build/error_output.txt; rc=0; merlin32 -V $$L/fgxtty.link.s > build/merlin_kerneltty.log 2>&1 || rc=$$?; [ -f $$L/_Output.txt ] && mv $$L/_Output.txt build/fgxtty_Output.txt; for f in _FileInformation.txt error_output.txt; do [ -f "$$L/$$f" ] && mv "$$L/$$f" build/; done; if [ $$rc -ne 0 ]; then cat build/merlin_kerneltty.log; exit $$rc; fi; mv $$L/fgxtty bin/fgxtty.bin
  description = merlin32 tty kernel bank

# The five kernel validations, as ONE edge gated on a stamp.  Kept separate
# from the assembly so a failing check names itself rather than failing "the
# kernel build" -- the class of message that sent me deleting tcsh.bin.
# Every checker proves it can FAIL before its silence is trusted.  A gate that
# passes by finding nothing is indistinguishable from one that stopped looking;
# --self-test is the positive evidence that it is still looking.
# The checked-in libc piles are GENERATED (toolchain/Makefile) but consumed here
# as plain sources, so editing libc_c.c and running `ninja all` used to report
# "no work to do" and link the OLD libc.  Its own edge rather than a member of
# kchecks: this is a toolchain-tree consistency claim, not a kernel validation,
# and a failure should name itself.
# Co-resident task stacks vs the bank-0 arena.  Reads the STAGED binaries (what
# actually ships) rather than bin/*.bin, because the shells live in
# tools/*-fgx2/ and only the staged copies are the real artifacts.  Gates the
# disk image: a disk whose shell cannot spawn its own tools is not shippable.
rule stkbudget
  command = python3 tools/check_stack_budget.py --self-test > /dev/null && python3 tools/check_stack_budget.py && touch $out
  description = stack arena budget

rule libcchk
  command = python3 tools/check_libc_piles.py --self-test > /dev/null && python3 tools/check_libc_piles.py && touch $out
  description = libc pile freshness

# Provenance (docs/PROVENANCE.md): every registered port carries its markers,
# no unregistered port does.  ITS OWN STAMP, whose inputs are the files the
# check reads -- it names them itself (--inputs).  Riding on the kernel checks
# made a new userland port invisible to it until the kernel next changed.
rule provcheck
  command = python3 tools/check_provenance.py --self-test > /dev/null && python3 tools/check_provenance.py && touch $out
  description = provenance

rule kchecks
  command = python3 tools/check_mx.py --self-test > /dev/null && python3 tools/check_baked_addrs.py --self-test > /dev/null && python3 tools/check_bsd_enforcement.py --self-test > /dev/null && python3 tools/check_chardev_ops.py --self-test > /dev/null && python3 tools/gen_syscall_table.py --self-test > /dev/null && python3 tools/gen_w5100_patchsites.py --self-test > /dev/null && python3 tools/gen_mod_bankpatch.py --self-test > /dev/null && python3 tools/gen_kernel_exports.py --self-test > /dev/null && python3 tools/check_kernel_ceiling.py --self-test > /dev/null && python3 tools/check_bank0_geometry.py --self-test > /dev/null && python3 tools/check_stage2_mirrors.py --self-test > /dev/null && python3 tools/mkfgxunix.py --self-test > /dev/null && python3 tools/check_stat_layout.py --self-test > /dev/null && python3 tools/check_statfs_layout.py --self-test > /dev/null && python3 tools/check_argv_caps.py --self-test > /dev/null && python3 tools/check_probe_offsets.py --self-test > /dev/null && python3 tools/check_far_calls.py --self-test > /dev/null && python3 tools/check_far_rtl_calls.py --self-test > /dev/null && python3 tools/check_selfbank_jsl.py --self-test > /dev/null && python3 tools/check_man_overstrike.py --self-test > /dev/null && python3 tools/check_path_copy.py --self-test > /dev/null && python3 tools/check_sock_argblk.py --self-test > /dev/null && python3 tools/gen_far_bankpatch.py --self-test > /dev/null && python3 tools/check_kc_dbr.py --self-test > /dev/null && python3 tools/check_kernelc_errno.py --self-test > /dev/null && python3 tools/gen_mod_imports.py --check-all > /dev/null && python3 tools/check_hb_scratch.py --self-test > /dev/null && python3 tools/check_spl_balance.py --self-test > /dev/null && python3 tools/check_ntty.py --self-test > /dev/null && python3 tools/check_canaries.py --self-test > /dev/null && python3 tools/check_vnodeops.py --self-test > /dev/null && python3 tools/gen_vfs_equ.py --selftest > /dev/null && python3 tools/check_kernel_bank_emission.py --selftest > /dev/null 2>&1 && python3 tools/check_kernel_bank_emission.py && python3 tools/check_kc_dbr.py && python3 tools/gen_mod_imports.py --check-all && python3 tools/check_kernelc_errno.py && python3 tools/check_hb_scratch.py && python3 tools/check_spl_balance.py && python3 tools/check_ntty.py && python3 tools/check_canaries.py && python3 tools/check_vnodeops.py && python3 tools/check_mx.py build/fgx_S01_KernelMain_Output.txt build/fgx_S02_BlockDriver_Output.txt build/fgxfar_Output.txt build/fgxtty_Output.txt && python3 tools/check_baked_addrs.py && python3 tools/check_bsd_enforcement.py && python3 tools/check_chardev_ops.py && python3 tools/gen_syscall_table.py --check && python3 tools/gen_w5100_patchsites.py build/fgx_S01_KernelMain_Output.txt src/kernel/w5100_patchsites.s --anchor _w5SiteBase --check && python3 tools/check_kernel_ceiling.py && python3 tools/check_bank0_geometry.py && python3 tools/check_stage2_mirrors.py build/fgx_S01_KernelMain_Output.txt && python3 tools/check_stat_layout.py && python3 tools/check_statfs_layout.py && python3 tools/check_argv_caps.py && python3 tools/check_probe_offsets.py && python3 tools/check_far_calls.py build/fgx_S01_KernelMain_Output.txt && python3 tools/check_far_rtl_calls.py && python3 tools/check_selfbank_jsl.py && python3 tools/check_man_overstrike.py && python3 tools/check_path_copy.py && python3 tools/check_sock_argblk.py && python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt src/kernel/far_patchsites.s core --check && python3 tools/gen_far_bankpatch.py build/fgxfar_Output.txt src/kernel/far/core_patchsites.s far --check && python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt src/kernel/tty_patchsites.s core-tty --check && python3 tools/gen_far_bankpatch.py build/fgxtty_Output.txt src/kernel/tty/core_patchsites.s tty --check && python3 tools/gen_mod_bankpatch.py build/fgxfar_Output.txt src/kernel/far/fnptr_patchsites.s --bank 08 --macro KFAR_FN_PTR --check && python3 tools/gen_mod_bankpatch.py build/fgxtty_Output.txt src/kernel/tty/fnptr_patchsites.s --bank 09 --macro KFAR_FN_PTR --check && python3 tools/gen_wavee_bankpatch.py build/fgx_S01_KernelMain_Output.txt --check && touch $out
  description = kernel checks

# Each linker probe's own script builds it; ninja supplies the dependency set.
rule shellbuild
  command = bash $script > /dev/null 2>&1 || { bash $script; false; }
  description = $name (probe)

# stage-2 bootloader: merlin32 writes `stage2` beside the source.
rule stage2
  command = cd src/boot && merlin32 stage2.s > /dev/null 2>&1 && mv stage2 $$OLDPWD/$out && rm -f stage2_Output.txt
  description = stage2 bootloader

# stage-1 bootloader.  The ninja migration ported stage2 but NOT this one, so
# the loader was assembled inside make_disk.sh and build/loader_padded.bin
# existed only as a SIDE EFFECT of building a hard-disk image -- while
# tools/make_floppy.sh consumed it with no declared dependency.  That is a race:
# `ninja release` builds the release image and the floppy concurrently, and on a
# clean tree the floppy can lose. It never failed locally because a stale
# loader_padded.bin from the build.sh era sits in the (gitignored) build/ dir
# forever; CI has no such leftover, so main went red.  Same shape as merlin32
# writing beside the source, so the same mv dance as stage2.
rule loader
  command = cd src/boot && merlin32 loader.s > /dev/null 2>&1 && mv loader $$OLDPWD/$out && rm -f loader_Output.txt
  description = stage1 bootloader

# Pad the loader to EXACTLY 512 bytes -- ONE boot sector.  The size check is a
# real guard, not decoration: a loader over its sector would be silently
# truncated and the disk would not boot.  It lived in make_disk.sh; it moves
# with the step it guards.
#
# 512 AND NOT 1024 SINCE UFS 2.2: 2.11BSD's disklabel owns sector 1
# (h/disklabel.h:53, LABELSECTOR 1), so the second block stopped being the
# loader's to self-load.  loader.s asserts the same bound at assembly time from
# its own labels; this catches what that expression cannot see.
rule loaderpad
  command = sz=$$(wc -c < $in); if [ "$$sz" -gt 512 ]; then echo "loader too large: $$sz bytes, max 512 (it must fit boot sector 0; sector 1 is the disklabel)" >&2; exit 1; fi; dd if=/dev/zero bs=512 count=1 of=$out 2>/dev/null && dd if=$in of=$out conv=notrunc 2>/dev/null
  description = pad loader to 512 B

# Copy ONLY when the bytes differ, and let ninja re-stat the result.
#
# This is the choke point that decides whether a source edit reaches the disk
# image.  ninja compares MTIMES, so a relink always looked like a change even
# when it produced an identical binary: a comment-only edit to uname.c rebuilt
# uname.bin (byte-identical, verified), restaged it, and rebuilt the whole image
# -- which then dragged in the boot test.  With `cmp` guarding the copy the
# staged file's mtime does not move, and `restat` lets ninja prune everything
# downstream.  Net effect: an edit that changes no artifact costs one recompile
# and stops there.
rule stagecp
  command = cmp -s $in $out 2>/dev/null || cp $in $out
  restat = 1
  description = stage $out

# 2.11BSD nroff 'cat' pages -> FGX console form (overstrike to SGR, tabs
# expanded, LF kept).  One edge per section so a page edit rebuilds only its
# own section, and the outputs are declared so ninja knows what it produces.
rule manfmt
  command = mkdir -p $dstdir && python3 tools/man_preformat.py $srcdir $dstdir > /dev/null
  description = man $srcdir

# cfg/system.cfg -> include/config.s.  Tracked OUTPUT of a tracked input, so a
# knob change shows up as a reviewable diff; write-if-changed inside the script
# keeps the tree clean and the kernel out of a needless rebuild.
rule genconfig
  command = python3 tools/ninja/genconfig.py $in $out
  restat = 1
  description = config.s from $in

# Loadable kernel modules (FGXM).  They BAKE KERNEL ADDRESSES, resolved from
# the kernel's own build listing -- so a kernel change that moves a symbol and
# does not rebuild these ships modules pointing at the old addresses.  That is
# runtime corruption, not a build error, which is why these belong in the graph
# rather than in a script someone remembers to run.
# restat: the exported addresses usually do NOT move when the kernel is rebuilt,
# and without this every kernel build would relink all five modules.
rule fccrt
  command = python3 tools/gen_fcc_rt.py $in $out
  restat = 1
  description = fcc runtime -> kernel

# THE COMPILER IS AN INPUT TO 44 EDGES AND NOTHING BUILT IT until 2026-09-10.
# `toolchain/fcc` was named `| toolchain/fcc` on every compile, so a NEWER fcc
# correctly rebuilt everything -- but no edge PRODUCED it, so editing
# toolchain/src/cc/*.c and running `ninja all` recompiled the whole tree with
# the STALE compiler and said nothing.  Ninja only complained when the binary
# was absent ("no known rule to make it"); stale was silent, and the result is
# indistinguishable from a codegen change that had no effect -- the same shape
# as the stack_measure.py gap fixed on 2026-08-02, one file over.
#
# IT DELEGATES TO THE MAKEFILE rather than restating the recipe: FCC_VERSION
# comes from `git describe`, and a second copy of that would drift.  make is a
# no-op when the sources have not moved, so the edge costs nothing per build.
#
# restat, because toolchain/Makefile is an input here and not one of make's
# own prerequisites for fcc: an edit to the Makefile runs this edge, make
# leaves fcc alone, and without restat ninja took the untouched fcc as new and
# recompiled every consumer -- on every build, since fcc stayed older than the
# Makefile for good.
rule fccbuild
  command = make -s -C toolchain fcc
  description = fcc <- toolchain/src/cc
  restat = 1

# THE LIBC PILES AND ARCHIVES, the same way and for the same reason: they are
# build outputs since apple/fgx#385, and the Makefile owns their recipes and
# their fingerprints.  restat: make rewrites only what is stale, so an output it
# leaves alone must not rebuild everything that links against it.
rule tclibs
  command = make -s -C toolchain piles
  description = libc piles <- toolchain/lib
  restat = 1

# termlib, curses, libfgx and libutil as shared libraries, linked against
# libc.so, which `piles' already makes.  restat for the same reason.
rule libso
  command = make -s -C toolchain libso_all
  description = libtermlib.so + libcurses.so + libfgx.so + libutil.so <- toolchain/lib
  restat = 1

# A manifest tool not marked "static": linked by fgx_dyn against the shared
# libraries.  Its summary
# line goes to $out.log; on failure the log is shown.
rule dynlink
  command = python3 toolchain/src/ld/fgx_dyn.py --name $name --dir $dir --code $code $codesegs --data $data --lib $libs --out $out > $out.log 2>&1 || (cat $out.log; false)
  description = fgx_dyn $name

# A manifest tool marked "static": linked by fgx_static against libc's
# library-mode compile, with libfgx and libutil as program-mode sections
# fgx_static prunes as it prunes libc.  Nothing shared need be resident.
rule staticlink
  command = python3 toolchain/src/ld/fgx_static.py --name $name --dir $dir --code $code $codesegs $libs --data $data --out $out > $out.log 2>&1 || (cat $out.log; false)
  description = fgx_static $name

# What ld_load leaves in libc's, termlib's and curses's banks, loaded in that
# order ($pad: arena held between libc and termlib), for lddig (testbin) to
# check on the machine.
# fgx_bind's digest of a dynamic program's binding against the libraries the
# machine has resident, for the binder's LD_BIND_DIGEST to match.
rule dyndigest
  command = python3 toolchain/src/ld/fgx_bind.py --prog $in --digest > $out
  description = $out <- fgx_bind --digest

rule lddigest
  command = python3 toolchain/src/ld/fgx_lddigest.py --out $out --boot $pad libtermlib=toolchain/lib/libtermlib.so.1.0 libcurses=toolchain/lib/libcurses.so.1.0
  description = $out <- the shared libraries

rule kernelc
  command = ./toolchain/fcc -fno-safepoints --pile --kernel-bank -o $out $in -MD -MF $out.d && python3 tools/check_kernelc_calls.py $out
  depfile = $out.d
  deps = gcc
  description = fcc kernel C $in

rule modulec_bank
  command = ./toolchain/fcc -fno-safepoints --pile --module-bank -o $out $in -MD -MF $out.d && python3 tools/check_kernelc_calls.py $out
  depfile = $out.d
  deps = gcc
  description = fcc module C $in

rule fccdp
  command = python3 tools/gen_fcc_dp.py $in $out
  restat = 1
  description = fcc DP map -> kernel

rule vfsequ
  command = python3 tools/gen_vfs_equ.py $in $out
  restat = 1
  description = vfs geometry -> kernel

# The PRODOS volume prodos.mod's tests mount, built by cadius -- an
# implementation of ProDOS nobody here wrote.  tools/mkpdscratch.py says what is
# on it and asserts the directory layout the tests depend on.

rule pdscratch
  command = python3 tools/mkpdscratch.py $out >/dev/null
  description = ProDOS scratch volume

rule ufsscratch
  command = python3 tools/fgxfs.py mkfs $out --size 4096 && python3 tools/fgxfs.py mkfile $out /big --blocks 300
  description = ufs scratch volume

# A VOLUME THAT IS ALWAYS SHORT OF INODES.  --bytes-per-inode 8192 over 400
# blocks gives 45 in total, so it is permanently under NICINOD (100) free and
# every ufs_ialloc on it takes the rescan-from-the-top path.  Filling it drives
# the create-fails-with-ENOSPC arm, which nothing else in the suite reaches.
rule ufsfewino
  command = python3 tools/fgxfs.py mkfs $out --size 400 --bytes-per-inode 8192
  description = ufs volume with 45 inodes (inode-exhaustion arm)

# A BROKEN filesystem ON ITS OWN SPINDLE, for `fsck -n'.  It has to be a whole
# volume rather than a file on the root: 2.11BSD's reply() returns 0 under
# nflag (usr/sbin/fsck/utilities.c:49), so `fsck -n' on a REGULAR FILE answers
# " no" to "file is not a block or character device" and never opens the
# filesystem at all -- which is why fsckro asserted a complaint it could not
# reach.  A block device node asks no such question.  ufscorrupt asserts at
# build time that the host fsck calls this broken.
rule ufsbadspin
  command = python3 tools/ufscorrupt.py --one unref $out 4096
  description = broken ufs volume on a spindle (fsck -n)

# THE /dev VOLUME -- UFS 1.7d I3.  A real 2.11BSD filesystem of real IFCHR
# inodes, which is the campaign's device-model decision in one line: "there is
# no synthesized /dev".  It is mounted at /dev while root is still ProDOS, and
# folds into the UFS root at Phase 2.5.
#
# EVERY NUMBER HERE IS A REGISTRY INDEX, and that is the fragile part rather
# than the sizes.  1.13b made v_rdev the chardev registry's index, and the
# registry is filled in REGISTRATION ORDER: chardev.s's built-in block first
# (null, the two pty pairs, the two VCs, console, tty), then whatever the
# modules register in modload.conf's order (serial's tty01, then bpf0).  Both
# are tracked and deterministic, so these are correct today -- and nothing
# notices if either moves: no boot check compares these numbers with the live
# registry, so a drift would quietly give somebody a /dev/null that is really a
# pty.  A module that logs the index it was given (cda.mod does) is the one
# place a drift shows.
#
# Small on purpose: 64 blocks is more than a dozen inodes need, and a /dev
# that costs nothing is one nobody is tempted to synthesize.

rule devvol
  command = $devvol_cmd
  description = /dev volume

rule kexports
  command = python3 tools/gen_kernel_exports.py $listing $module $out
  restat = 1
  description = kernel exports $module

rule kbuildid
  command = python3 tools/gen_kernel_exports.py --kernel-id $out
  restat = 1
  description = kernel build identity

rule buildidcheck
  command = python3 tools/check_build_id.py --self-test > /dev/null && python3 tools/check_build_id.py && touch $out
  description = build identity agreement

# A module image with a deliberately WRONG build id, for the runtime test that
# proves Mod_Load refuses one.  Built, never shipped: it exists only in build/
# and the test stages it onto its own disk copy.
rule module
  command = mkdir -p disk_src/lib/modules build && cd src/modules/$name && merlin32 -V $name.link.s > /dev/null 2>&1 && mv $name $$OLDPWD/disk_src/lib/modules/$name && mv _Output.txt $$OLDPWD/build/module_${name}_Output.txt && rm -f *_Output.txt _FileInformation.txt
  description = module $name

# Where a module sits in the SHARED module bank.  Its offset is the running
# cursor over the MEASURED footprints of the modules placed before it, so this
# edge takes those modules' built images as its inputs -- which is also what
# serialises the module builds into placement order.
rule modulec
  command = ./toolchain/fcc -fno-safepoints --pile --kernel-bank -o $out $in
  description = fcc module C $in

rule modplace
  command = python3 tools/gen_modplace.py $module $out $in
  restat = 1
  description = module placement $module

rule modpackcheck
  command = python3 tools/gen_modplace.py --verify $in && touch $out
  description = module bank packing

# A module image placed on top of the pre-staged one, for the runtime test
# that Mod_Load refuses an overlapping load.  Built, never shipped.
# The W5100 slot-bind self-mod tables PUT into net.mod / bpf.mod, checked
# against each module's OWN listing (--bank 05: modules ORG at $050000 for
# assembly; at runtime the bank comes from PHK, never the assembly-only $05).
rule modcheck
  command = python3 tools/gen_w5100_patchsites.py build/module_${module}_Output.txt --bank 05 src/modules/$module/w5100_patchsites.s --check && touch $out
  description = w5100 patch-sites $module

# The &function bank-patch table (apple/fgx#173).  --module-bank leaves every
# MOD_FN_PTR cell's bank byte zero, because a module's bank is Bank_Alloc's to
# choose at load; _Mod_StampFnPtrs writes it at mod_init from PHK.  This edge
# is what stops the TABLE going stale against the cells -- a cell added by new
# C and missing from the table is a dispatch to bank $00, and nothing else in
# the build would say so.  Each module's OWN ordinal, not $05: unlike the
# w5100 sites these are addresses within the module's own listing.
rule modmx
  command = python3 tools/check_mx.py build/module_${module}_Output.txt && touch $out
  description = MX check $module

rule modfnptr
  command = python3 tools/gen_mod_bankpatch.py build/module_${module}_Output.txt src/modules/$module/fnptr_patchsites.s --bank $ordinal $emptyok --check && touch $out
  description = fn-ptr bank patch $module

# Module-local DATA must not be read DBR-relative: a module runs with DBR = the
# KERNEL bank, so `LDA mytable,X` reads the KERNEL at that offset.  apple/fgx#93
# was exactly this and presented as "two bytes of padding break networking".
rule thunkyargs
  command = python3 tools/check_thunk_y_args.py --self-test > /dev/null && python3 tools/check_thunk_y_args.py && touch $out
  description = dispatch wrappers re-stage Y

rule moddatarefs
  command = python3 tools/check_module_data_refs.py --self-test > /dev/null && python3 tools/check_module_data_refs.py && touch $out
  description = module-local data bank check

# yacc-sourced tools (manifest.json "yacc": true; today expr).  Two host steps ahead of the ordinary FGX2
# build: compile 2.11BSD yacc for the host, then run it over <name>.y.
rule hostyacc
  command = bash tools/ninja/yacc.sh host
  description = host yacc

# The IANA zic, built for the host from vendor/tzcode-2026d (tools/ninja/tz.sh).
rule hostzic
  command = bash tools/ninja/tz.sh host
  description = host zic

# The zone files and /etc/localtime (tools/ninja/tz.sh zones).
rule tzzones
  command = bash tools/ninja/tz.sh zones $zone
  description = zoneinfo ($zone)

rule yaccgen
  command = bash tools/ninja/yacc.sh gen $name
  description = yacc $in

# The two deliberately-broken fixtures, minted by editing one byte of a good
# binary.  See tools/ninja/derive.py for why this is not a linker option.
rule derive
  command = python3 tools/ninja/derive.py $what $in $out
  description = derive $out

# fas built FOR FGX -- the assembler, cross-compiled to run on the IIgs.
rule fasfgx
  command = bash tools/ninja/fasfgx.sh > /dev/null 2>&1 || { bash tools/ninja/fasfgx.sh; false; }
  description = fas (FGX-hosted)

# make_disk.sh assembles the ProDOS image from the disk_src tree.  Depends on
# every staged file, so a rebuilt binary reaches the image without a hand-kept
# list -- build.sh's staleness guard could only WARN that a staged binary was
# older than the toolchain; here it simply cannot be.
# Both image variants rewrite the single generated disk_src/etc/rc, so they
# must not run concurrently.
pool image_pool
  depth = 1

rule prunestaged
  command = python3 tools/prune_staged.py --stamp $out
  description = prune stale staged files

# The 800K floppy is its OWN edge, so an overflow fails the build and names
# itself.  Inside make_disk.sh it was "non-fatal", which is how an overflowing
# floppy once silently shipped without /etc, /lib, /sbin or INIT.
# PARKED 2026-09-06 -- no edge uses this rule; see the note beside the
# commented `disk/fgx-floppy.po' edge.  Kept so un-parking is one line.
rule floppy
  command = bash tools/ninja/mkimage.sh floppy $out
  pool = image_pool
  description = 800K floppy -> $out

# THE SYSTEM DISK: disk/fgxroot.fs, a bootable 2.11BSD UFS volume.  It carries
# the boot chain (/boot, /fgxunix, /etc/boot.conf) and the staged disk_src
# tree as the root filesystem.  Its own script fscks it with fgxfs before
# shipping.
rule ufsboot
  command = bash tools/make_ufsboot.sh $out
  pool = image_pool
  description = UFS boot volume -> $out

# ONE KERNEL IMAGE, the way 2.11BSD ships one /unix.  Core, far, tty and the
# three boot modules, with a segment table at the front; stage 2 places each
# segment in the bank the table names.  See tools/mkfgxunix.py.
rule fgxunix
  command = python3 tools/mkfgxunix.py $out > /dev/null
  description = one kernel image -> $out

"""


# --- the linker probes ---------------------------------------------------
# Machine probes for the shared-library and loader work, each linked by its
# own script in a mode no userland tool uses.  Ninja wraps each as ONE edge
# and supplies its dependency set: the staleness test and the rebuild rule are
# the same edge.
# What fgx_dyn runs or reads besides the program's own sources: its modules,
# the crt0 and runtime files it assembles in, the helper and data files it
# reads, the seg1 layout tool, and the libraries.  A dynamic tool's link
# depends on all of it, or an edit to one leaves the tool stale on the disk.
# The dynamic SHELLS entries depend on this list, and check_shell_linker_inputs
# holds them to it.
DYN_INPUTS = [
    "toolchain/src/ld/fgx_dyn.py", "toolchain/src/ld/fgx_imports.py",
    "toolchain/src/ld/fgx_sites.py", "toolchain/src/ld/fgx_static.py",
    "toolchain/src/ld/fgx_ld.py", "toolchain/src/ld/fgx_libso.py",
    "toolchain/src/ld/fgx_bind.py", "toolchain/src/ld/fgx_gc.py",
    "toolchain/src/ld/fgx_pack.py", "toolchain/lib/crt0_dyn.s", "toolchain/lib/crt0_lib.s",
    "toolchain/lib/crt0_lib_data.s", "toolchain/lib/fcc_runtime.s",
    "toolchain/lib/fcc_runtime_data.s", "toolchain/lib/libc_so_helpers.s",
    "toolchain/lib/macros.s", "toolchain/lib/libc_data.s",
    "toolchain/tools/gen_seg1_layout.py",
    "toolchain/lib/libc.so.1.0", "toolchain/lib/libtermlib.so.1.0",
    "toolchain/lib/libcurses.so.1.0", "toolchain/lib/libfgx.so.1.0",
    "toolchain/lib/libutil.so.1.0",
] + sorted(glob.glob("toolchain/lib/libllong/*.s")) + [
    "toolchain/lib/libdouble/d_stub.s",
]

# What fgx_static runs or reads besides the program's own sources and the
# libraries' program-mode compiles.  The static SHELLS entries depend on this
# list, and check_shell_linker_inputs holds them to it.
STATIC_INPUTS = [
    "toolchain/src/ld/fgx_static.py", "toolchain/src/ld/fgx_libso.py",
    "toolchain/src/ld/fgx_ld.py", "toolchain/src/ld/fgx_gc.py",
    "toolchain/src/ld/fgx_pack.py",
    "toolchain/lib/crt0_lib.s", "toolchain/lib/crt0_lib_data.s",
    "toolchain/lib/libc_start.s", "toolchain/lib/libc_start_data.s",
    "toolchain/lib/libc_c/core.list", "toolchain/lib/libc.s",
    "toolchain/lib/fcc_libc_shims.s", "toolchain/lib/ld_bind_asm.s",
    "toolchain/lib/fcc_runtime.s", "toolchain/lib/fcc_runtime_data.s",
    "toolchain/lib/macros.s", "toolchain/lib/libc_data.s",
    "toolchain/lib/args_data.s", "toolchain/tools/gen_seg1_layout.py",
    "toolchain/lib/libc_so.s", "toolchain/lib/libc_so_data.s",
    "toolchain/lib/libc_so.blocks.json", "build/libc.sigs",
    "build/static_libs/ffltpr.s", "build/static_libs/ffltpr.data.s",
] + sorted(glob.glob("toolchain/lib/libllong/*.s")) + [
    "toolchain/lib/libdouble/d_stub.s",
]

SHELLS = {
    # Shared libc SP2's machine probe, linked statically against libc's
    # library-mode compile.  Two binaries from one source (build_libcso.sh).
    "libcso": dict(
        out="tools/libcso-fgx2/libcso.bin",
        script="tools/libcso-fgx2/build_libcso.sh libcso",
        gate="src/userland/libcso",
        links=["tools/libcso-fgx2/build_libcso.sh"],
        globs=["src/userland/libcso/*"],
        extra=[],
        hard=STATIC_INPUTS,
    ),
    # ldload(8): libc and ld.so.conf's libraries resident at boot.  Static
    # (fgx_static): nothing shared is resident when it runs.
    "ldload": dict(
        out="tools/ldload-fgx2/ldload.bin",
        script="tools/ldload-fgx2/build_ldload.sh",
        gate="src/userland/ldload",
        links=["tools/ldload-fgx2/build_ldload.sh"],
        globs=["src/userland/ldload/*"],
        extra=[],
        hard=STATIC_INPUTS,
    ),
    # Shared libc SP2's byte loop through the new path (bytecat is the same
    # source built as every program is).
    "bytecatso": dict(
        out="tools/libcso-fgx2/bytecatso.bin",
        script="tools/libcso-fgx2/build_libcso.sh bytecatso",
        gate="src/userland/bytecat",
        links=["tools/libcso-fgx2/build_libcso.sh"],
        globs=["src/userland/bytecat/*"],
        extra=[],
        hard=STATIC_INPUTS,
    ),
    # Shared libc SP3's machine probes: linked dynamically (fgx_dyn) and bound
    # on the host (fgx_bind).  One source, three binds (build_dynso.sh).
    "dynso": dict(
        out="tools/dynso-fgx2/dynso.bin",
        script="tools/dynso-fgx2/build_dynso.sh dynso",
        gate="src/userland/dynso",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/dynso/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "dynsodyn": dict(
        out="tools/dynso-fgx2/dynsodyn.bin",
        script="tools/dynso-fgx2/build_dynso.sh dynsodyn",
        gate="src/userland/dynso",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/dynso/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "dynsomisdyn": dict(
        out="tools/dynso-fgx2/dynsomisdyn.bin",
        script="tools/dynso-fgx2/build_dynso.sh dynsomisdyn",
        gate="src/userland/dynso",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/dynso/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "dyntrue": dict(
        out="tools/dynso-fgx2/dyntrue.bin",
        script="tools/dynso-fgx2/build_dynso.sh dyntrue",
        gate="src/userland/dyntrue",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/dyntrue/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "dynmulti": dict(
        out="tools/dynso-fgx2/dynmulti.bin",
        script="tools/dynso-fgx2/build_dynso.sh dynmulti",
        gate="src/userland/dynmulti",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/dynmulti/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "dynrebind": dict(
        out="tools/dynso-fgx2/dynrebind.bin",
        script="tools/dynso-fgx2/build_dynso.sh dynrebind",
        gate="src/userland/dynrebind",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/dynrebind/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "dyntabseg": dict(
        out="tools/dynso-fgx2/dyntabseg.bin",
        script="tools/dynso-fgx2/build_dynso.sh dyntabseg",
        gate="src/userland/dyntabseg",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/dyntabseg/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "fitover": dict(
        out="tools/dynso-fgx2/fitover.bin",
        script="tools/dynso-fgx2/build_dynso.sh fitover",
        gate="src/userland/fitso",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/fitso/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "fitunder": dict(
        out="tools/dynso-fgx2/fitunder.bin",
        script="tools/dynso-fgx2/build_dynso.sh fitunder",
        gate="src/userland/fitso",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/fitso/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "dyntruebound": dict(
        out="tools/dynso-fgx2/dyntruebound.bin",
        script="tools/dynso-fgx2/build_dynso.sh dyntruebound",
        gate="src/userland/dyntrue",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/dyntrue/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "cursso": dict(
        out="tools/dynso-fgx2/cursso.bin",
        script="tools/dynso-fgx2/build_dynso.sh cursso",
        gate="src/userland/cursso",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/cursso/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "curssodyn": dict(
        out="tools/dynso-fgx2/curssodyn.bin",
        script="tools/dynso-fgx2/build_dynso.sh curssodyn",
        gate="src/userland/cursso",
        links=["tools/dynso-fgx2/build_dynso.sh"],
        globs=["src/userland/cursso/*"],
        extra=[],
        hard=DYN_INPUTS + ["disk_src/etc/ld.so.conf", "build/libc.sigs"],
    ),
    "libcsofull": dict(
        out="tools/libcso-fgx2/libcsofull.bin",
        script="tools/libcso-fgx2/build_libcso.sh libcsofull",
        gate="src/userland/libcso",
        links=["tools/libcso-fgx2/build_libcso.sh"],
        globs=["src/userland/libcso/*"],
        extra=[],
        hard=STATIC_INPUTS,
    ),
}

TOOLCHAIN_DEPS = ["toolchain/fcc", "toolchain/src/ld/fgx_ld.py",
                  # fgx_ld IMPORTS stack_measure, and its output -- the FGX2
                  # header's stack-pages hint -- is entirely that module's
                  # verdict.  It was missing here until 2026-08-02, so editing
                  # the stack model rebuilt NOTHING: `ninja` said "no work to
                  # do" and the old reservations kept shipping, which reads
                  # exactly like a change that had no effect.
                  "toolchain/src/ld/stack_measure.py",
                  # AND libc's OWN .s, since apple/fgx#404: stack_measure
                  # charges each binary for the deepest libc function it
                  # actually reaches, so a libc whose call depth grows changes
                  # every reservation in the system.  Without this edge the
                  # hints would go stale exactly the way they did when
                  # stack_measure itself was missing from this list.
                  "toolchain/lib/libc_c.s",
                  "toolchain/tools/gen_seg1_layout.py"]


def shell_deps(spec):
    """Dependency closure for one shell.

    The generated seg*.link.s are scanned when present -- they carry the PUT
    closure of the libc/runtime piles, which is where the code/DATA distinction
    build.sh got wrong lives."""
    deps = set()
    bdir = os.path.dirname(spec["links"][0])
    roots = [os.path.join(ROOT, l) for l in spec["links"]]
    generated = sorted(glob.glob(os.path.join(ROOT, bdir, "seg*.link.s")))
    roots += generated
    roots = [r for r in roots if os.path.isfile(r)]
    if roots:
        deps |= {rel(d) for d in putdeps.scan(roots, allow_missing=True)}
    # fgx_pack.py/fgx_static.py/fgx_dyn.py pack the shells, `links` names the
    # build script only (used above to derive `bdir`), and no current shell
    # build writes a seg*.link.s.  The glob and exclusion are the guard: if a
    # build dir ever generates one, listing it as an input would make the
    # build invalidate itself (the script rewrites it, it becomes newer than
    # the .bin, ninja rebuilds forever), so only its PUT CLOSURE is kept and
    # the generated file itself is dropped.  dataseg.link.s is TRACKED source and stays;
    # anything else the build dir generates is dropped for the same reason.
    deps -= {rel(g) for g in generated}
    deps = {d for d in deps
            if not (d.startswith(bdir + "/") and
                    os.path.basename(d) not in
                    {os.path.basename(l) for l in spec["links"]})}
    for g in spec["globs"]:
        deps |= {rel(p) for p in glob.glob(os.path.join(ROOT, g))}
    for e in spec["extra"] + TOOLCHAIN_DEPS + [spec["script"]]:
        if os.path.exists(os.path.join(ROOT, e)):
            deps.add(e)
    # "hard" deps are BUILD PRODUCTS, so they are added unconditionally -- the
    # exists() filter above is right for source files but would silently drop a
    # not-yet-built output on a clean clone, leaving the graph thinner exactly
    # where this function's docstring says it must not be.
    deps |= set(spec.get("hard", ()))
    return sorted(deps)


def check_shell_linker_inputs():
    """A SHELLS entry whose build script runs fgx_static or fgx_dyn depends on
    that linker's whole input list, or an edit to one of its modules leaves
    the binary stale on the disk."""
    bad = []
    for name, spec in sorted(SHELLS.items()):
        # Every shell script the entry's command runs.
        paths = {t for t in spec["script"].split() if t.endswith(".sh")}
        paths |= set(spec["links"])
        script = "".join(open(os.path.join(ROOT, t)).read() for t in sorted(paths))
        deps = set(shell_deps(spec))
        for tool, inputs in (("fgx_static.py", STATIC_INPUTS), ("fgx_dyn.py", DYN_INPUTS)):
            if tool in script:
                missing = sorted(set(inputs) - deps)
                if missing:
                    bad.append("%s (%s): %s" % (name, tool, ", ".join(missing)))
    if bad:
        raise SystemExit("SHELLS entries missing their linker's inputs:\n  "
                         + "\n  ".join(bad))


def emit(tools, out_path):
    lines = [HEADER]

    # ---- kernel ----------------------------------------------------------
    # merlin32 assembles the whole kernel from src/kernel/link/core/fgx.link.s
    # (its ASM/PUT closure) in ONE invocation, and writes its per-segment
    # listings beside the link file.  The five validation scripts read those
    # listings, so they are separate edges gated on a stamp rather than folded
    # into the assembly command -- a failing check then names itself instead of
    # failing "the kernel build".
    # main.s PUTs src/kernel/kernel_build_id.s, which the kbuildid edge below
    # generates -- so it is absent in a clean checkout and the strict scan would
    # refuse to write build.ninja at all.  Named as GENERATED for the same
    # reason as the far bank's kernel_exports.s below.
    kdeps = " ".join(rel(d) for d in putdeps.scan(
        [os.path.join(ROOT, "src/kernel/link/core/fgx.link.s")],
        generated=[os.path.join(ROOT, "src/kernel/kernel_build_id.s")]))
    lines.append("\n# ---- the compiler " + "-" * 51)
    # Every compile edge names `| toolchain/fcc` as a real input, so a NEWER
    # compiler rebuilds the tree.  This is the edge that MAKES it newer: without
    # it, editing toolchain/src/cc/*.c left every consumer compiling with the
    # stale binary and ninja reporting no work to do.
    # Every header counts as a source: tword.h alone defines the type words.
    _cc_srcs = sorted(glob.glob("toolchain/src/cc/*.c") +
                      glob.glob("toolchain/src/cc/*.h"))
    lines.append(
        "build toolchain/fcc: fccbuild " + " ".join(_cc_srcs) +
        " toolchain/Makefile")
    # ONE EDGE FOR EVERY PILE, so a tool that PUTs any of them (a PUT the scan
    # cannot see on a clean tree) is still ordered after all of them: every
    # tool already depends on libc.so.1.0, which this edge writes.
    _libs_out = (
        [f"toolchain/lib/{b}{x}.s" for b in ("libc_c", "libc_so", "libfgx",
                                             "libcurses", "libtermlib")
         for x in ("", "_data")]
        + ["toolchain/lib/libc_so.blocks.json", "toolchain/lib/libc.so.1.0"]
        + ["toolchain/lib/libdouble/softdouble.s",
           "toolchain/lib/libdouble/softdouble.data.s"]
        + [f"toolchain/lib/{f}.srcsha"
           for f in ("libc_c", "libc_so", "libfgx", "libcurses",
                     "libtermlib")])
    _libs_in = sorted(
        glob.glob("toolchain/lib/*_c/*.c")
        # llong's members are hand-written .s, libc.so.1.0's prerequisites.
        + glob.glob("toolchain/lib/libllong/*.s")
        # double: the soft double's C source and the hand-written glue.
        + ["toolchain/lib/libdouble/softdouble.c",
           "toolchain/lib/libdouble/d_glue.s",
           "toolchain/lib/libdouble/d_stub.s"]
        + glob.glob("toolchain/include/**/*.h", recursive=True)
        + ["toolchain/lib/libcurses_c/curses.ext",
           "tools/check_libc_piles.py"]
        # libc.so.1.0's own prerequisites (toolchain/Makefile), which `piles'
        # rebuilds it from.
        + [f"toolchain/lib/{f}" for f in (
            "libc.s", "fcc_libc_shims.s", "fcc_runtime.s", "libc_data.s",
            "args_data.s", "fcc_runtime_data.s", "macros.s", "libc_so_helpers.s",
            "ld_bind_asm.s", "ld_bind_entry.s",
            "libc_start.s", "libc_start_data.s", "libc_c/core.list",
            "libc_c/data.exports")]
        + [f"toolchain/src/ld/{f}.py" for f in ("fgx_libso", "fgx_ld", "fgx_gc")]
        + ["toolchain/tools/gen_seg1_layout.py"])
    lines.append(
        "build " + " ".join(_libs_out) + ": tclibs " + " ".join(_libs_in) +
        " | toolchain/fcc")
    # What only `make libso_all' makes: termlib's, curses's, libfgx's and
    # libutil's library-mode compiles and their .so files.  Downstream of tclibs, so no two makes
    # share the tree.
    _so_out = [f"toolchain/lib/{b}{x}" for b in ("libtermlib", "libcurses",
                                                    "libfgx", "libutil")
               for x in ("_so.s", "_so_data.s", "_so.blocks.json", ".so.1.0")]
    _so_in = sorted(
        _libs_out
        + glob.glob("toolchain/lib/libtermlib_c/*.c")
        + glob.glob("toolchain/lib/libcurses_c/*.c")
        + glob.glob("toolchain/lib/libfgx_c/*.c")
        + glob.glob("toolchain/lib/libutil_c/*.c")
        + glob.glob("toolchain/include/*.h")
        + ["toolchain/lib/libcurses_c/curses.ext",
           "toolchain/lib/libcurses_c/core.list",
           "toolchain/lib/libtermlib_c/data.exports",
           "toolchain/lib/libcurses_c/data.exports",
           "toolchain/lib/libfgx_c/data.exports",
           "toolchain/lib/libutil_c/data.exports",
           "toolchain/lib/libtermlib_helpers.s",
           "toolchain/lib/libtermlib_helpers_data.s"]
        + [f"toolchain/src/ld/{f}.py" for f in ("fgx_libso", "fgx_ld", "fgx_gc",
                                                "fgx_imports", "fgx_sites")]
        + ["toolchain/tools/gen_seg1_layout.py"])
    lines.append(
        "build " + " ".join(_so_out) + ": libso " + " ".join(_so_in) +
        " | toolchain/fcc")
    _dg_in = ("toolchain/lib/libc.so.1.0 toolchain/lib/libtermlib.so.1.0 "
              "toolchain/lib/libcurses.so.1.0 | toolchain/lib/libfgx.so.1.0 "
              "disk_src/etc/ld.so.conf "
              + " ".join(f"toolchain/src/ld/{f}.py" for f in
                         ("fgx_lddigest", "fgx_bind", "fgx_imports", "fgx_ld")))
    lines.append("build build/ld.digest: lddigest " + _dg_in + "\n  pad =")
    lines.append("build build/ld.digest.pad: lddigest " + _dg_in + "\n  pad = pad=100")
    for _n in ("dynsodyn", "dynsomisdyn", "curssodyn"):
        lines.append("build build/%s.digest: dyndigest tools/dynso-fgx2/%s.bin | "
                     "toolchain/lib/libc.so.1.0 toolchain/lib/libtermlib.so.1.0 "
                     "toolchain/lib/libcurses.so.1.0 toolchain/lib/libfgx.so.1.0 "
                     "disk_src/etc/ld.so.conf toolchain/src/ld/fgx_bind.py "
                     "toolchain/src/ld/fgx_imports.py toolchain/src/ld/fgx_ld.py"
                     % (_n, _n))

    lines.append("\n# ---- kernel " + "-" * 58)
    # The core build identity.  Purely SYMBOLIC (a sum of kernel labels, which
    # Merlin resolves), so it derives from the manifests in the generator and
    # NOT from the kernel listing -- which is what lets it be an INPUT to the
    # kernel assembly instead of a chicken-and-egg.  The module side of the
    # same sum is resolved from the listing by the kexports edges below.
    lines.append(
        "build src/kernel/kernel_build_id.s: kbuildid | "
        "tools/gen_kernel_exports.py")
    lines.append(
        "build bin/fgx.bin build/fgx_S01_KernelMain_Output.txt "
        "build/fgx_S02_BlockDriver_Output.txt: kernel | "
        "src/kernel/kernel_build_id.s " + kdeps)

    # The FAR kernel bank -- a SECOND link unit, its own image, its own ceiling.
    # Deps come from the same PUT-closure scan, so a new subsystem PUT into
    # far.s is tracked without touching this generator.
    #
    # far.s PUTs kernel_exports.s, which the kexports edge below GENERATES from
    # the core kernel's listing, so in a clean checkout it does not exist when
    # this scan runs -- and the scan is strict, so gen.py died before writing
    # build.ninja at all ("unresolved PUT 'kernel_exports.s'").  Nobody saw it
    # because a built tree has the file; it became reachable when the far bank's
    # copy stopped being tracked (apple/fgx#79), which left the same hole the
    # four modules already had (CI job 479, below).  Naming it as GENERATED is
    # what the modules wanted and could not say: the edge is still emitted, so
    # merlin32 cannot run before the file is written, and every OTHER unresolved
    # PUT in the far bank is still a hard error.
    # The VFS translation units are the same case: fcc writes them at BUILD
    # time from the kernelc edges below, so on a clean tree they are PUT but
    # absent.  Named here for the same reason and with the same effect -- the
    # edge is emitted, and anything NOT named stays a hard error.
    # The VFS translation units are no longer named here: they left this bank
    # for src/modules/vfs/vfs.mod, and the amnesty list is for files this link
    # PUTs that do not exist yet in a clean checkout.  Listing one it no longer
    # PUTs would quietly re-grant the amnesty the day someone PUT it back.
    fdeps = " ".join(rel(d) for d in putdeps.scan(
        [os.path.join(ROOT, "src/kernel/link/far/fgxfar.link.s")],
        generated=([os.path.join(ROOT, "src/kernel/far/kernel_exports.s")]
                   + [os.path.join(ROOT, "src/kernel/far", _c + _x)
                      for _c in _FAR_C for _x in (".s", ".data.s")]
                   + [os.path.join(ROOT, "src/kernel/vfs", _c + _x)
                      for _c in _FAR_VFS_C for _x in (".s", ".data.s")])))
    # fcc's DP slot map, extracted from the compiler's own runtime.  Merlin
    # resolves PUT against the LINK file's directory, so a shared file cannot
    # be PUT from both toolchain/lib and here -- it is generated instead, the
    # same way kernel_exports.s is.
    lines.append(
        "build src/kernel/far/fcc_dp.s: fccdp toolchain/lib/fcc_runtime.s "
        "| tools/gen_fcc_dp.py")
    # fcc's helper routines, from _fcc_mul16 on -- the region with no syscall,
    # no libc and no other outside call.  The three above it exit or yield
    # through SYS_TRAMP; src/kernel/far/fcc_ktrap.s replaces them.
    lines.append(
        "build src/kernel/far/fcc_rt.s: fccrt toolchain/lib/fcc_runtime.s "
        "| tools/gen_fcc_rt.py")
    lines.append(
        "build include/vfs_equ.s: vfsequ src/kernel/vfs/fsparam.h "
        "src/kernel/vfs/vnode.h | tools/gen_vfs_equ.py cfg/system.cfg")
    # cfg/system.cfg IS AN INPUT because gen_vfs_equ.py reads it: the
    # VFS_NPROC-vs-kernel.nproc guard (apple/fgx#162) compares the two, and
    # without this edge a change to kernel.nproc ALONE -- which is exactly
    # how #162 was created -- would not rerun the guard that exists to catch
    # it.  The guard would fire only on the next fsparam.h touch or clean
    # build, i.e. long after the damage.
    lines.append(
        "build disk/ufsscratch.fs: ufsscratch | tools/fgxfs.py")
    lines.append(
        "build disk/ufsfewino.fs: ufsfewino | tools/fgxfs.py")
    lines.append(
        "build disk/ufsbadspin.fs: ufsbadspin | tools/ufscorrupt.py "
        "tools/fgxfs.py")
    # THE REAL 2.11BSD ROOT, and the edge exists only when the source does.
    #
    # NO EDGE CARVES A 2.11BSD VOLUME ANY MORE.  Phase 1's gate arm 4 -- "an
    # image WRITTEN BY 2.11BSD mounts and reads on FGX" -- was checked by the
    # `bsd211mnt' manifest against a filesystem carved out of
    # examples/pdp11/2.11BSD_rq.dsk.  The manifest is retired (the
    # feature is known to work), so the 7.8 MB artifact had no
    # reader left.
    #
    # `tools/bsd211vol.py' STAYS, with its --self-test, because it is the
    # procedure rather than the product: carve a volume and attach it through
    # `extra_hards' when a foreign-filesystem question comes up again.  Nothing
    # builds it unasked, and examples/ is never tracked, so a fresh clone was
    # never getting this edge anyway.
    lines.append(
        "build disk/fgxdev.fs: devvol | tools/fgxfs.py\n  devvol_cmd = "
        + devvol_command("disk/fgxdev.fs"))
    # THE ProDOS VOLUME tests/pdmount mounts as a second spindle.
    lines.append(
        "build disk/pdscratch.po: pdscratch | tools/mkpdscratch.py")
    # Kernel C translation units.  -fno-safepoints because a safepoint is a
    # SYS_YIELD, and kernel C runs to completion inside a syscall.
    #
    # --pile is what makes a MULTI-FUNCTION kernel C translation unit possible.
    # fcc's default is FGX2 userland: every user-function call is an
    # FGX2_FARCALL, a `JSL $000000` whose operand fgx_ld patches at link time.
    # The kernel far bank is assembled by Merlin32 and never sees fgx_ld, so
    # those three zero bytes survive into the image and the call lands in bank
    # 0 -- the same silent failure shape as an unregenerated _kfp table.
    # --pile switches user calls to the PHK/PEA/PHK/PEA/RTL idiom, which reaches
    # an RTL-terminated target in the CURRENT bank and is therefore relocation
    # safe.  --kernel-bank applies the SAME rule to an INDIRECT call and makes a
    # &function data cell resolve here instead of waiting for a linker that
    # never runs -- apple/fgx#88, where an ops vector was 32 zero pointers.  It
    # is separate from --pile because a libc pile is also one segment but its
    # function pointers can name a user callback outside it.  kc_probe is byte-identical either way (it calls no user function),
    # which is why a single-function probe could never have caught this.
    # THE FAR BANK'S C.  kc_probe is the kernel-C seam's own self-test; vfs_seam
    # is the inward seam.  The other three arrived at UFS 1.7d I2b and are the
    # DESCRIPTOR LAYER, moved out of vfs.mod:
    #
    #   Mod_LoadConf opens files through _Fcb_Alloc (modload.s:174 -> Fs_Open),
    #   and Mod_LoadConf is what LOADS vfs.mod.  So the descriptor layer has to
    #   work before vfs.mod exists, and the file table cannot live inside it.
    #   BSD puts this in kern_descrip.c, which is kernel code and not
    #   filesystem code; keeping it in a loadable filesystem module was the
    #   divergence, and the circularity is what made it show.
    #
    # They are compiled from src/kernel/vfs/ (shared with the fcc fixtures,
    # which #include them) but LINKED into the far bank -- the same split
    # vfs_lookup and friends have in the other direction.
    for _kc in _FAR_C:
        lines.append(
            # The data segment is an IMPLICIT output: fcc derives its name from
            # -o and writes it alongside, so it must not appear in $out.
            f"build src/kernel/far/{_kc}.s | src/kernel/far/{_kc}.data.s: "
            f"kernelc src/kernel/far/{_kc}.c | toolchain/fcc")
    # The DESCRIPTOR layer -- built like any VFS translation unit (same rule,
    # same flags, .s beside the source) and PUT by far.s instead of vfs.s.
    for _kd in _FAR_VFS_C:
        lines.append(
            f"build src/kernel/vfs/{_kd}.s | src/kernel/vfs/{_kd}.data.s: "
            f"kernelc src/kernel/vfs/{_kd}.c | toolchain/fcc")

    # The TTY BANK's kernel C.  Same rule, same flags -- a bank is a bank as far
    # as fcc is concerned; what differs is which link unit PUTs the output.
    for _kt in ("tty_subr", "tty_conf", "tty_dev", "tty", "kern_time"):
        lines.append(
            f"build src/kernel/tty/{_kt}.s | src/kernel/tty/{_kt}.data.s: "
            f"kernelc src/kernel/tty/{_kt}.c | toolchain/fcc")

    # The VFS translation units.  They live under src/kernel/vfs (shared with
    # the fcc fixtures, which #include them) and are compiled INTO the far bank
    # here, so the generated .s lands beside the source rather than in far/.
    #
    # THE HEADERS ARE ORDER-ONLY-FREE INPUTS, and listing them is not
    # housekeeping: without them a change to fsparam.h or any struct header
    # recompiles NOTHING, and every .s in this directory keeps whatever
    # constants and offsets it was built with.  That is a silent wrong answer
    # rather than a build error -- measured 2026-08-18, when VFS_NPROC went
    # 11 -> 12 and one translation unit went on calling fdbase(11 + 1) while
    # vfs_file.s (touched for an unrelated reason, so recompiled) used 12.
    # It reported a table bug that did not exist.
    #
    # THE HEADERS COME FROM A DEPFILE, not from a glob here.  The first cut of
    # this fix listed every src/kernel/vfs/*.h against every translation unit,
    # on the belief that fcc emits no depfile.  It does: the `fcc_c` rule above
    # has always passed `-MD -MF $out.d` with `depfile =`/`deps = gcc`, and the
    # same flags work in --kernel-bank --pile mode (verified: the depfile lists
    # exactly the headers the unit includes).  The glob was also WORSE than
    # wrong-in-principle -- it is evaluated when build.ninja is GENERATED, so a
    # header added later is silently absent from every edge until someone
    # regenerates, which is the same stale-input defect one level up.
    # dict.fromkeys: a unit two modules PUT (kern_epoch) is compiled once.
    # The probe gates' C has an edge only when ufsprobe.mod is built: an edge
    # nothing reaches is a .s a built tree never has, and the checkers that
    # look for every compiled unit's .s would read that as an unbuilt tree.
    _probes = any(_cfg_values().get(g, "0") != "0" for g in _UFSPROBE_GATES)
    for _vc in dict.fromkeys(_VFS_C + _UFS_C + _UFSDIR_C +
                             (_UFSPROBE_C if _probes else ()) +
                             _PRODOS_C + _PRODOSW_C + _ISOFS_C):
        lines.append(
            f"build src/kernel/vfs/{_vc}.s | src/kernel/vfs/{_vc}.data.s: "
            # `| toolchain/fcc`, a REAL input, not `|| toolchain/fcc`.
            # Order-only sequences the build and never triggers a rebuild, so a
            # changed COMPILER left every kernel-C object exactly as it was --
            # measured 2026-08-18, when an fcc codegen fix was rebuilt at 22:50
            # and kern_subr.s stayed at its 22:10 content, still carrying the
            # bug.  The userland fcc_c edges already spell this `| $fcc`; these
            # were the outlier.
            f"modulec_bank src/kernel/vfs/{_vc}.c | toolchain/fcc")
    lines.append(
        "build src/kernel/far/kernel_exports.s: kexports "
        "build/fgx_S01_KernelMain_Output.txt | tools/gen_kernel_exports.py\n"
        "  listing = build/fgx_S01_KernelMain_Output.txt\n  module = far")
    lines.append(
        "build bin/fgxfar.bin build/fgxfar_Output.txt: kernelfar | " + fdeps)

    # The TTY kernel bank.  Same PUT-closure scan and the same clean-checkout
    # amnesty as the far bank: kernel_exports.s is written by the kexports edge
    # below, so it is PUT but absent until the first build.
    # The amnesty list is files this link PUTs that a CLEAN CHECKOUT does not
    # have: kernel_exports.s comes from the kexports edge and the two kernel-C
    # translation units from the kernelc edges, all below.  Naming them keeps
    # the edge (so merlin32 still cannot run before they are written) while
    # letting the strict scan proceed; anything NOT named here is still a hard
    # error, which is the point of the list.
    #
    # THEY ARE GITIGNORED RATHER THAN TRACKED, unlike the far bank's kc_probe.s.
    # A generated .s in git is a file that can be stale in a working tree and
    # green in the build that reads it -- this tree has lost a session to
    # exactly that -- and apple/fgx#79 already moved kernel_exports.s off the
    # tracked side for the same reason.
    tdeps = " ".join(rel(d) for d in putdeps.scan(
        [os.path.join(ROOT, "src/kernel/link/tty/fgxtty.link.s")],
        generated=[os.path.join(ROOT, "src/kernel/tty/kernel_exports.s"),
                   os.path.join(ROOT, "src/kernel/tty/tty_subr.s"),
                   os.path.join(ROOT, "src/kernel/tty/tty_subr.data.s"),
                   os.path.join(ROOT, "src/kernel/tty/tty_conf.s"),
                   os.path.join(ROOT, "src/kernel/tty/tty_conf.data.s"),
                   os.path.join(ROOT, "src/kernel/tty/tty_dev.s"),
                   os.path.join(ROOT, "src/kernel/tty/tty_dev.data.s"),
                   os.path.join(ROOT, "src/kernel/tty/tty.s"),
                   os.path.join(ROOT, "src/kernel/tty/tty.data.s"),
                   os.path.join(ROOT, "src/kernel/tty/kern_time.s"),
                   os.path.join(ROOT, "src/kernel/tty/kern_time.data.s"),]))
    lines.append(
        "build src/kernel/tty/kernel_exports.s: kexports "
        "build/fgx_S01_KernelMain_Output.txt | tools/gen_kernel_exports.py\n"
        "  listing = build/fgx_S01_KernelMain_Output.txt\n  module = tty")
    lines.append(
        # ORDER-ONLY on bin/fgxfar.bin: both links move their diagnostics to
        # build/_FileInformation.txt and build/error_output.txt, so they must
        # not overlap.  See the kernelfar rule's comment.
        # Order-only rather than an input, because a far-bank rebuild is not a
        # reason to relink this bank.
        "build bin/fgxtty.bin build/fgxtty_Output.txt: kerneltty | " + tdeps
        + " || bin/fgxfar.bin")

    lines.append(
        # bin/fgx.bin and include/kernel.s are inputs because check_kernel_ceiling
        # measures the former against FGX_DATA-FGX_CODE parsed from the latter --
        # so a geometry change re-runs the check without a clean build.
        # bin/fgxfar.bin likewise, against FGX_KFAR_DATA-FGX_KFAR_CODE.
        "build build/.kernel_checked: kchecks build/fgx_S01_KernelMain_Output.txt "
        "build/fgx_S02_BlockDriver_Output.txt bin/fgx.bin bin/fgxfar.bin "
        "bin/fgxtty.bin "
        # THE FAR AND TTY LISTINGS ARE INPUTS, not merely co-produced.
        # check_mx reads all four banks now, and a rule that does not name
        # a file it reads does not re-run on the edit that breaks it.
        "build/fgxfar_Output.txt build/fgxtty_Output.txt "
        "| tools/check_mx.py "
        "tools/check_baked_addrs.py "
        "tools/check_chardev_ops.py include/chardev.s "
        "tools/gen_syscall_table.py tools/gen_w5100_patchsites.py "
        "tools/check_kernel_ceiling.py tools/check_bank0_geometry.py "
        "tools/check_stage2_mirrors.py src/boot/stage2.s "
        "tools/mkfgxunix.py "
        "tools/check_stat_layout.py include/fs.s toolchain/include/sys/stat.h "
        "tools/check_statfs_layout.py src/kernel/vfs/mount.h src/kernel/vfs/fsparam.h "
        "tools/check_argv_caps.py toolchain/lib/args.s "
        "toolchain/src/ld/fgx_libso.py toolchain/src/ld/fgx_static.py "
        "tools/check_kernel_bank_emission.py toolchain/fcc "
        "tools/check_far_calls.py tools/check_far_rtl_calls.py "
        "tools/check_selfbank_jsl.py tools/check_man_overstrike.py "
        "tools/check_path_copy.py "
        "tools/check_sock_argblk.py toolchain/lib/libc_c/socket.c "
        "toolchain/lib/libc_c/socket_srv.c toolchain/lib/libc_data.s "
        "src/modules/net/net.s include/socket.s "
        "tools/gen_far_bankpatch.py tools/gen_wavee_bankpatch.py tools/check_kc_dbr.py "
        "tools/check_hb_scratch.py src/modules/serial/serial.s "
        "tools/check_spl_balance.py "
        "tools/check_ntty.py tools/check_canaries.py include/memmap.s "
        "tools/mame_test/tests/smoke.json "
        "tools/check_vnodeops.py src/kernel/vfs/vnode.h "
        # ...and the three files that check reads.  Without them the
        # rule never re-runs on the edit that breaks it, which is a
        # check that cannot fail -- the shape check_vacuous_assertions
        # exists for, one layer up.
        "src/kernel/tty/tty.c src/kernel/tty/tty_subr.c "
        "src/kernel/tty/tty_dev.c "
        "src/kernel/main.s "
        "include/kfar.s src/kernel/far_patchsites.s "
        "src/kernel/far/core_patchsites.s "
        "include/ktty.s src/kernel/tty_patchsites.s "
        "src/kernel/tty/core_patchsites.s "
        "include/kernel.s include/config.s src/boot/stage2.s "
        "src/kernel/w5100_patchsites.s")

    # ---- manual pages ----------------------------------------------------
    # Outputs are <UPPERNAME>.<N>, deterministic from the source names, so they
    # can be declared rather than discovered -- no dyndep needed.
    man_outs = []
    lines.append("\n# ---- man pages " + "-" * 54)
    for sect in sorted(glob.glob(os.path.join(ROOT, "src/userland/man/pages/cat[1-8]"))):
        n = os.path.basename(sect)[-1]
        srcs = sorted(glob.glob(os.path.join(sect, "*.0")))
        if not srcs:
            continue
        dstdir = f"disk_src/usr/man/cat{n}"
        # LOWERCASE, because man(1) builds /usr/man/cat<N>/<name>.<N>
        # verbatim from its argument and does not case-fold.  Staging
        # BASENAME.1 worked only because ProDOS is case-insensitive; on
        # a 2.11BSD root `man ls' answered "no entry for ls" while
        # `man LS' found it.  Lowercase resolves on both.
        outs = [f"{dstdir}/{os.path.basename(s)[:-2]}.{n}" for s in srcs]
        lines.append(
            "build " + " ".join(outs) + ": manfmt | " +
            " ".join(rel(s) for s in srcs) + " tools/man_preformat.py\n"
            f"  srcdir = {rel(sect)}\n  dstdir = {dstdir}")
        man_outs += outs
    lines.append("build man: phony " + " ".join(man_outs))

    # ---- generated kernel config -----------------------------------------
    lines.append("\n# ---- config " + "-" * 57)
    lines.append("build include/config.s: genconfig cfg/system.cfg | "
                 "tools/ninja/genconfig.py")

    # ---- loadable kernel modules (FGXM) ----------------------------------
    # Each reads kernel addresses out of the kernel's build listing.  Both
    # halves were outside the graph entirely, while disk_src/etc/modload.conf
    # (tracked) loads the results at boot.
    KEXPORTS = ("serial", "bpf", "net", "ramdisk", "pty", "cda", "sscon",
                "klog")
    cfg = _cfg_values()
    probes = any(cfg.get(g, "0") != "0" for g in _UFSPROBE_GATES)
    MODULES = tuple(m for m in ("serial", "bpf", "net", "ramdisk", "pty",
                                "vfs", "ufs", "ufsprobe", "ufsdir", "prodos",
                                "prodosw", "cda", "sscon", "klog", "fpsim",
                                "ld", "isofs")
                    if m != "ufsprobe" or probes)
    MODCHECK = ("net", "bpf")
    # Modules built from C IN PLACE: the .c compiles to <m>_c.s + <m>_c.data.s,
    # which the module root PUTs alongside the fcc runtime.  EMPTY since
    # 2026-09-07 -- hellokc.mod was the only one and it was a test fixture.
    # The mechanism is kept because it is the container vfs.mod and ufs.mod
    # rely on; theirs is the MODULEGEN path below, where the C is compiled by
    # the same `kernelc' edges the far bank uses and merely PUT here.
    MODULEC = ()
    # ...and modules whose C is compiled ELSEWHERE and merely PUT here.  vfs.mod
    # carries the same generated .s files the far bank does, from the same
    # `kernelc` edges: fcc runs with identical flags for both, so a second
    # compile would produce byte-identical output and a second chance to drift.
    # They are named as GENERATED for the PUT scan for the reason
    # kernel_exports.s is -- absent in a clean checkout, so a strict scan would
    # refuse to emit the edge at all.
    # ufs.mod's list is the UFS half of _VFS_C, moved rather than copied when
    # the filesystem got a module of its own (apple/fgx#169).  Both modules PUT
    # from the SAME `kernelc` edges -- there is no second compile and no second
    # chance to drift; only which module's link picks the .s up changed.
    MODULE_PUTS_KERNELC = {"vfs": _VFS_C, "ufs": _UFS_C,
                           "ufsprobe": _UFSPROBE_C, "ufsdir": _UFSDIR_C,
                           "prodos": _PRODOS_C, "prodosw": _PRODOSW_C,
                           "isofs": _ISOFS_C}
    lines.append("\n# ---- kernel modules " + "-" * 49)
    # Placement chain: module N's offset in the shared bank comes from the
    # MEASURED footprints of modules 1..N-1, so its placement edge takes their
    # built images as inputs.  That is also what orders the module builds --
    # they cannot run in parallel, and must not.
    placed = [m for m in gen_modplace.ORDER if m != "ufsprobe" or probes]
    for i, m in enumerate(placed):
        earlier = " ".join(f"disk_src/lib/modules/{e}" for e in placed[:i])
        lines.append(
            f"build src/modules/{m}/modplace.s: modplace {earlier}"
            f" | tools/gen_modplace.py\n  module = {m}")
    for m in MODULEC:
        lines.append(
            f"build src/modules/{m}/{m}_c.s | src/modules/{m}/{m}_c.data.s: "
            f"modulec src/modules/{m}/{m}.c || toolchain/fcc")
    for m in KEXPORTS:
        lines.append(
            f"build src/modules/{m}/kernel_exports.s: kexports "
            f"build/fgx_S01_KernelMain_Output.txt | tools/gen_kernel_exports.py\n"
            f"  listing = build/fgx_S01_KernelMain_Output.txt\n  module = {m}")
    mod_outs = []
    for m in MODULES:
        # kernel_exports.s is GENERATED by the kexports edge above, so in a
        # clean checkout it does not exist yet.  This used to scan with
        # allow_missing=True and then re-add the dep by hand, because a missing
        # operand was quietly DROPPED and the edge then had no ordering
        # constraint: merlin32 ran before the file was written and the build
        # failed with "Impossible to open Source file" (CI job 479).  A built
        # tree hid it, since the file was there.  Naming the generated source
        # says the same thing without the blanket amnesty -- the edge is
        # emitted, and any OTHER unresolved PUT in a module is a hard error
        # again instead of vanishing.
        # modplace.s is generated by the chain above and is PUT before the ORG,
        # so it is absent in a clean checkout for the same reason
        # kernel_exports.s is -- name it generated rather than loosening the
        # scan.
        mdeps = sorted(rel(d) for d in putdeps.scan(
            [os.path.join(ROOT, f"src/modules/{m}/{m}.link.s")],
            generated=([os.path.join(ROOT, f"src/modules/{m}/modplace.s")]
                       + ([os.path.join(ROOT, f"src/modules/{m}/kernel_exports.s")]
                          if m in KEXPORTS else [])
                       + ([os.path.join(ROOT, f"src/modules/{m}/{m}_c.s"),
                           os.path.join(ROOT, f"src/modules/{m}/{m}_c.data.s")]
                          if m in MODULEC else [])
                       + [os.path.join(ROOT, "src/kernel/vfs", _v + _x)
                          for _v in MODULE_PUTS_KERNELC.get(m, ())
                          for _x in (".s", ".data.s")]
                       # fpsim PUTs the soft double the libs edge writes.
                       + [os.path.join(ROOT, "toolchain/lib/libdouble", _x)
                          for _x in ("softdouble.s", "softdouble.data.s")])))
        out = f"disk_src/lib/modules/{m}"
        lines.append(
            f"build {out} build/module_{m}_Output.txt: module | "
            + " ".join(mdeps) + f"\n  name = {m}\n  upper = {m.upper()}")
        mod_outs.append(out)
    mod_checked = []
    # Modules whose C is compiled --module-bank carry a MOD_FN_PTR table.
    # ufsprobe carries NO &function cells at the shipping configuration -- its
    # only C is the three probe gates, and with all of them off the module is a
    # header, the import shims and the fcc runtime.  --allow-empty says that is
    # expected there and nowhere else: an empty table in vfs.mod or ufs.mod
    # would mean every function pointer in it dispatching to bank 0.
    for m, _ord in (("vfs", "06"), ("ufs", "07"), ("ufsprobe", "08"),
                    ("ufsdir", "09"), ("prodos", "0A"), ("prodosw", "0B"),
                    ("isofs", "0C")):
        if m not in MODULES:
            continue
        emptyok = " --allow-empty" if m == "ufsprobe" else ""
        lines.append(
            f"build build/.module_{m}_fnptr: modfnptr "
            f"build/module_{m}_Output.txt | tools/gen_mod_bankpatch.py "
            f"src/modules/{m}/fnptr_patchsites.s\n  module = {m}\n"
            f"  ordinal = {_ord}\n  emptyok ={emptyok}")
        mod_checked.append(f"build/.module_{m}_fnptr")
    # EVERY MODULE'S LISTING GOES THROUGH check_mx, as the kernel banks' do.
    # It read only the kernel listings, and a klog.mod MX bug bricked the boot
    # on 2026-09-21; #465's own site, _Pipe_FreeSlot, is net.mod's.
    for m in MODULES:
        lines.append(
            f"build build/.module_{m}_mx: modmx build/module_{m}_Output.txt | "
            f"tools/check_mx.py\n  module = {m}")
        mod_checked.append(f"build/.module_{m}_mx")
    for m in MODCHECK:
        lines.append(
            f"build build/.module_{m}_checked: modcheck "
            f"build/module_{m}_Output.txt | tools/gen_w5100_patchsites.py "
            f"src/modules/{m}/w5100_patchsites.s\n  module = {m}")
        mod_checked.append(f"build/.module_{m}_checked")
    # Depends on the module BINARIES, so it re-runs whenever any module source
    # changes -- the kernel-checks bundle would only re-run on kernel changes.
    lines.append(
        # Reads SOURCES, not images: the question is whether a wrapper stages
        # Y before its call, which is answered in the text.  Depending on the
        # built module would also work and would re-run less precisely.
        "build build/.thunk_y_checked: thunkyargs "
        "src/modules/net/net.s src/modules/net/net_loop.s "
        "src/modules/net/net_xport.s src/modules/net/pipe.s "
        "src/modules/net/unp.s "
        "| tools/check_thunk_y_args.py")
    mod_checked.append("build/.thunk_y_checked")
    lines.append(
        "build build/.module_data_refs_checked: moddatarefs "
        + " ".join(mod_outs)
        + " | tools/check_module_data_refs.py")
    mod_checked.append("build/.module_data_refs_checked")
    # The kernel and the modules derive the same build id by two different
    # routes (see tools/check_build_id.py).  Verify they agree HERE, at build
    # time, rather than discovering it as a machine that boots with no
    # filesystem module, no serial and no network.
    lines.append(
        "build build/.buildid_checked: buildidcheck "
        "build/fgx_S01_KernelMain_Output.txt | tools/check_build_id.py "
        + " ".join(mod_outs)
        + " " + " ".join(f"src/modules/{m}/kernel_exports.s" for m in KEXPORTS))
    # The chain makes overlap impossible; this proves it from the built images
    # rather than from the reasoning, because a mis-wired edge looks exactly
    # like correct reasoning from the inside.
    lines.append(
        "build build/.modpack_checked: modpackcheck " + " ".join(mod_outs)
        + " | tools/gen_modplace.py")
    lines.append("build modules: phony " + " ".join(
        mod_outs + mod_checked + ["build/.buildid_checked",
                                  "build/.modpack_checked"]))

    # ---- host yacc -------------------------------------------------------
    # Only emitted when something needs it.  Its own sources are 2.11BSD's, so
    # the closure is the four .c files, the shared header, and the skeleton the
    # binary bakes an absolute path to.
    if any(tools[n]["yacc"] for n in tools):
        ysrc = " ".join(f"tools/yacc/src/{f}"
                        for f in ("y1.c", "y2.c", "y3.c", "y4.c", "dextern"))
        lines.append("\n# ---- host yacc " + "-" * 54)
        lines.append(f"build tools/yacc/yacc: hostyacc | {ysrc} "
                     f"tools/yacc/yaccpar tools/ninja/yacc.sh")

    # ---- host zic ----------------------------------------------------------
    # Always emitted: the zone files on every image are its output.
    lines.append("\n# ---- host zic " + "-" * 55)
    lines.append("build build/tz_host/zic: hostzic | vendor/tzcode-2026d/zic.c "
                 "vendor/tzcode-2026d/version tools/ninja/tz.sh")
    # /etc/localtime is FGX_TZ, else the zone named in the untracked .fgx_tz
    # (this machine's own setting, as disk_src/etc/dhclient.conf is), else UTC.
    # FGX_TZ is read HERE, so a change needs gen.py re-run before ninja, as
    # every environment knob here does; .fgx_tz is always a regen input, so
    # editing it re-runs gen.py by itself.
    fgx_tz = os.environ.get("FGX_TZ") or local_tz() or "UTC"
    lines.append("build build/.zoneinfo_staged disk_src/etc/localtime: tzzones | "
                 "build/tz_host/zic tools/ninja/tz.sh tools/check_tzlimits.py "
                 "vendor/tzdata-2026d/version toolchain/include/tzfile.h\n"
                 f"  zone = {fgx_tz}")

    # ---- userland --------------------------------------------------------
    # libfgx and libutil compiled as a program's source is, for the static
    # links (fgx_static --lib), which prune them.  libtermlib is compiled
    # the same way for the fcc fixtures' termlib recipe
    # (toolchain/tests/M38/_link.json); no static program links it, so it
    # has no consumer elsewhere in the graph and is added to `all` by hand.
    lines.append("\n# ---- static_libs " + "-" * 52)
    lines.append(
        "build build/static_libs/libfgx.s | build/static_libs/libfgx.data.s: fcc_c "
        "toolchain/lib/libfgx_c/libfgx.c | $fcc build/libc.sigs\n"
        "  data = build/static_libs/libfgx.data.s\n  flags = --sections\n  softscc =")
    # ffltpr: printf's float conversions for a static program with no
    # fltused marker (fgx_static links it in place of libc's fltpr).
    lines.append(
        "build build/static_libs/ffltpr.s | build/static_libs/ffltpr.data.s: fcc_c "
        "toolchain/lib/ffltpr.c | $fcc build/libc.sigs\n"
        "  data = build/static_libs/ffltpr.data.s\n  flags = --sections\n  softscc =")
    lines.append(
        "build build/static_libs/libutil.s | build/static_libs/libutil.data.s: fcc_c "
        "toolchain/lib/libutil_c/libutil.c | $fcc build/libc.sigs\n"
        "  data = build/static_libs/libutil.data.s\n"
        "  flags = --sections -Itoolchain/lib/libutil_c\n  softscc =")
    lines.append(
        "build build/static_libs/libtermlib.s | build/static_libs/libtermlib.data.s: fcc_c "
        "toolchain/lib/libtermlib_c/libtermlib.c | $fcc build/libc.sigs\n"
        "  data = build/static_libs/libtermlib.data.s\n"
        "  flags = --sections -Itoolchain/lib/libtermlib_c\n  softscc =")
    built, skipped_vendored = [], []
    for name in sorted(tools):
        rec = tools[name]
        src = rec["main"] or f"src/userland/{name}/{name}.c"
        if rec["yacc"]:
            # The .c is a BUILD PRODUCT (gitignored), so its absence on disk
            # says nothing about whether the tool is buildable -- the same
            # mistake that once let a missing /bin/sh build silently stage
            # another shell.  Gate on the tracked .y instead.
            grammar = f"src/userland/{name}/{name}.y"
            if not os.path.isfile(os.path.join(ROOT, grammar)):
                continue
            lines.append(f"\nbuild {src}: yaccgen {grammar} | "
                         f"tools/yacc/yacc tools/ninja/yacc.sh\n"
                         f"  name = {name}")
        elif not os.path.isfile(os.path.join(ROOT, src)):
            continue
        # A tool whose -I points into a VENDORED tree cannot build where that
        # tree is absent.  examples/ is gitignored and local-only, so a fresh
        # clone (and CI) has no elvis/2.11BSD sources.  build.sh gated addtest
        # behind `[[ -d vendor/netbsd-0-9/usr.bin/elvis ]]` and "skipped
        # loudly"; the graph has to do the same, or a cleanroom build dies on a
        # tool it was never able to build.  Found by tools/cleanroom.sh.
        missing_inc = [tok[2:] for tok in shlex.split(rec["flags"] or "")
                       if tok.startswith("-I")
                       and not os.path.isdir(os.path.join(
                           ROOT, tok[2:].replace("../../", "", 1)))]
        if missing_inc:
            skipped_vendored.append((name, missing_inc[0]))
            continue
        tus = read_tu_list(rec["tu_list"]) if rec["tu_list"] else []
        libs = [l for l in rec["libs"].split(",") if l]
        if rec["static"]:
            bad = [l for l in libs if l != "util"]
            if bad:
                raise SystemExit(f"{name}: static, but {bad} has no program-mode compile")
            b = f"tools/{name}-fgx2"
            code0, codesegs, data, alls = direct_link_edges(lines, name, "static",
                                                            src, tus, rec)
            slibs = ["libfgx"] + [{"util": "libutil"}[x] for x in libs]
            lines.append(
                f"build bin/{name}.bin: staticlink {' '.join(alls)} {' '.join(data)} "
                + " ".join(f"build/static_libs/{l}.s build/static_libs/{l}.data.s" for l in slibs)
                + " | " + " ".join(STATIC_INPUTS) + "\n"
                f"  name = {name}\n  dir = {b}/static.ld\n  code = {','.join(code0)}\n"
                f"  codesegs ={codesegs}\n  libs = "
                + " ".join(f"--lib build/static_libs/{l}.s,build/static_libs/{l}.data.s"
                           for l in slibs)
                + f"\n  data = {','.join(data)}")
            built.append(name)
            continue
        # Linked by fgx_dyn against libc.so, libfgx.so, and libtermlib.so,
        # libcurses.so, libutil.so for the libs it names; fgx_dyn keeps only
        # the libraries the program references.
        lib_map = {"termlib": "libtermlib", "curses": "libcurses", "util": "libutil"}
        bad = [l for l in libs if l not in lib_map]
        if bad:
            raise SystemExit(f"{name}: dynamic, but {bad} has no shared library")
        dlibs = ",".join(["libc", "libfgx"] + [lib_map[l] for l in libs])
        b = f"tools/{name}-fgx2"
        code0, codesegs, data, alls = direct_link_edges(lines, name, "dynamic",
                                                        src, tus, rec)
        lines.append(
            f"build bin/{name}.bin: dynlink {' '.join(alls)} {' '.join(data)} | "
            + " ".join(DYN_INPUTS) + "\n"
            f"  name = {name}\n  dir = {b}/dyn.ld\n  code = {','.join(code0)}\n"
            f"  codesegs ={codesegs}\n  data = {','.join(data)}\n  libs = {dlibs}")
        built.append(name)

    # ---- linker probes ----------------------------------------------
    check_shell_linker_inputs()
    probes_built = []
    for sname, spec in sorted(SHELLS.items()):
        if not os.path.isdir(os.path.join(ROOT, spec["gate"])):
            continue
        lines.append(f"\n# ---- {sname} (probe) " + "-" * 40)
        lines.append(
            f"build {spec['out']}: shellbuild | " + " ".join(shell_deps(spec)) + "\n"
            f"  script = {spec['script']}\n  name = {sname}")
        probes_built.append(spec["out"])

    # ---- derived fixtures --------------------------------------------
    # Minted from a binary this graph builds, so they track their source
    # automatically.  build.sh did this inline with a heredoc, which is how they
    # ended up outside the graph entirely.
    derived = []
    for dname, dfrom, what in derived_map():
        if dfrom not in built:
            print(f"gen: skipping derived {dname} -- {dfrom} is not built",
                  file=sys.stderr)
            continue
        lines.append(f"\nbuild bin/{dname}.bin: derive bin/{dfrom}.bin | "
                     f"tools/ninja/derive.py\n  what = {what}")
        derived.append(dname)

    # ---- fas, hosted on FGX ------------------------------------------
    # Staged to /usr/fgx/bin/fas.  A dynamic program, linked by fgx_dyn as the
    # manifest's dynamic tools are.
    lines.append("\n# ---- fas (FGX-hosted) " + "-" * 47)
    lines.append("build tools/fas/fas_fgx: fasfgx | tools/ninja/fasfgx.sh $fcc "
                 "toolchain/src/as/fas.c build/libc.sigs " + " ".join(DYN_INPUTS))

    if skipped_vendored:
        for n, inc in skipped_vendored:
            print(f"gen: skipping {n} -- vendored include tree absent ({inc})",
                  file=sys.stderr)

    lines.append("\nbuild probes: phony " + " ".join(probes_built))

    # ---- stage-2 bootloader ------------------------------------------
    s2deps = " ".join(rel(d) for d in putdeps.scan(
        [os.path.join(ROOT, "src/boot/stage2.s")], allow_missing=True))
    lines.append("\n# ---- disk staging " + "-" * 52)
    lines.append(f"build build/stage2.bin: stage2 | {s2deps}")

    # ---- stage-1 bootloader ------------------------------------------
    # Now a real build product with ONE declared producer, so make_disk.sh and
    # make_floppy.sh both CONSUME it instead of one of them making it as a
    # side effect. Same PUT-closure dependency scan as stage2.
    l1deps = " ".join(rel(d) for d in putdeps.scan(
        [os.path.join(ROOT, "src/boot/loader.s")], allow_missing=True))
    lines.append(f"build build/loader.bin: loader | {l1deps}")
    lines.append("build build/loader_padded.bin: loaderpad build/loader.bin")

    # ---- staged copies, parsed from build.sh -------------------------
    # One destination is still staged twice from the SAME file (disk_src/boot),
    # which is a harmless duplicate.
    # A staging source may be a BUILD PRODUCT this graph produces, so its
    # presence ON DISK at GENERATION time must not decide the graph.  Gating on
    # os.path.exists alone meant a clean tree (no bin/sh.bin yet)
    # silently fell back to staging jsh as /bin/sh -- the very substitution that
    # once made a missing /bin/sh look like a working build.  A source counts as
    # available if it exists OR the graph builds it.
    # BUILT, not the full manifest: a tool skipped for a missing vendored
    # include tree has no rule, so staging it would leave ninja with an
    # unbuildable input -- exactly what broke the first cleanroom run.
    produced = {f"bin/{n}.bin" for n in built} | {"build/stage2.bin"}
    produced |= {f"bin/{n}.bin" for n in derived}
    produced |= {"tools/fas/fas_fgx"}
    produced |= {"build/ld.digest", "build/ld.digest.pad",   # rule lddigest
                 "build/dynsodyn.digest", "build/dynsomisdyn.digest",
                 "build/curssodyn.digest"}                          # dyndigest
    produced |= {sp["out"] for sp in SHELLS.values()
                 if os.path.isdir(os.path.join(ROOT, sp["gate"]))}
    # The shared libraries (tclibs and libso_all, above): on a clean tree they
    # do not exist yet when this runs, and without them here the volume was
    # built with an empty /lib -- libc.so not loaded, every dynamic program
    # refusing to start -- while ninja reported success.
    produced |= {p for p in list(_libs_out) + _so_out if p.endswith(".so.1.0")}
    seen, staged = {}, []
    for src_, dst_ in staging_map():
        if src_ not in produced and not os.path.exists(os.path.join(ROOT, src_)):
            continue
        # A source that LOOKS like a tool binary but is not produced here was
        # skipped upstream; staging it would reintroduce the dangling input.
        if src_.startswith("bin/") and src_.endswith(".bin") and src_ not in produced:
            continue
        if dst_ in seen:
            prev = seen[dst_]
            if prev == src_:
                continue                       # exact duplicate
            prefer_shell = any(src_ == sp["out"] for sp in SHELLS.values())
            if not prefer_shell:
                continue                       # keep the first (preferred)
            lines[:] = [l for l in lines if not l.startswith(f"build {dst_}: ")]
        seen[dst_] = src_
        lines.append(f"build {dst_}: stagecp {src_}")
        if dst_ not in staged:
            staged.append(dst_)

    # ---- the disk image ----------------------------------------------
    # STALE STAGED FILES.  Nothing removes a file from disk_src when its
    # manifest entry goes away, and make_disk walks whatever is there -- so a
    # deleted tool keeps shipping.  Removing jsh left disk_src/bin/jsh behind
    # and it went straight onto the image; worse, deleting it did NOT dirty the
    # disk edge, because a file the graph never knew about cannot be an input.
    # The graph cannot express "delete this", so warn at generation time.
    stale = []
    for sd in ("disk_src/bin", "disk_src/sbin", "disk_src/testbin"):
        full = os.path.join(ROOT, sd)
        if not os.path.isdir(full):
            continue
        for f in sorted(os.listdir(full)):
            if f.startswith(("_", ".")):
                continue
            if f"{sd}/{f}" not in staged:
                stale.append(f"{sd}/{f}")
    if stale:
        print(f"gen: {len(stale)} stale staged file(s) with no manifest entry "
              f"(mkimage.sh will prune them):", file=sys.stderr)
        for s_ in stale[:10]:
            print(f"gen:   {s_}", file=sys.stderr)

    # THE EXPECTED CONTENTS of every generated disk_src directory.  ninja cannot
    # express "ensure this file is ABSENT", so removing a tool from the manifest
    # never unstaged it and deleting the leftover could not dirty the disk edge
    # -- a file the graph never knew about cannot be one of its inputs.  That is
    # how disk_src/bin/jsh shipped after jsh was deleted, and how
    # disk_src/usr/man/cat8/IFCONFIG.8 shipped from a build of a branch that was
    # never merged (its source was never on main at all, so "removed" understated
    # it -- an artifact with NO tracked source outlived every checkout).
    # mkimage.sh reads this list and prunes to it.
    write_if_changed(os.path.join(ROOT, "build/staged.list"),
                     "\n".join(sorted(staged + mod_outs + man_outs)) + "\n")

    # Everything else in disk_src that ships but is not a build product: the
    # tracked config, testdata and root files.  make_disk.sh copies the WHOLE
    # tree, so these reach the image; without them as inputs, editing
    # /etc/profile changed the image and rebuilt nothing.
    tree_inputs = []
    for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, "disk_src")):
        # TESTS is harness scratch, not tracked source: run_runtime.py and
        # tests/multibank/run_multibank.py stage fixture binaries into
        # disk_src/tests/fcc and clear it between runs.  Walking it baked
        # whatever a previous sweep happened to leave behind into the image
        # edge as a hard input with no rule to rebuild it, so the NEXT run --
        # which clears the directory first -- died with "missing and no known
        # rule to make it".  A test harness must not be able to poison the
        # disk dependency graph by running.  make_disk.sh copies the whole
        # tree at image time, so staged fixtures still reach the disk.
        dirnames[:] = [d for d in dirnames
                       if d not in ("bin", "sbin", "testbin", "modules", "man",
                                    "TESTS", "zoneinfo")]
        for f_ in sorted(filenames):
            # Anything mkimage.sh WRITES must not also be one of the image
            # edge's inputs, or the edge invalidates itself and the image
            # rebuilds forever.  rc, version, build and the cadius metadata are
            # all generated at image time.
            # localtime and zoneinfo/ are tz.sh's, tracked by
            # build/.zoneinfo_staged.
            if f_ in ("_FileInformation.txt", ".gitkeep", "rc",
                      "version", "build", "localtime"):
                continue
            p = rel(os.path.join(dirpath, f_))
            if p not in staged:
                tree_inputs.append(p)
    tree_inputs.sort()

    # The modules are written INTO disk_src, so they must be image inputs as
    # well as build outputs -- otherwise a rebuilt module never reaches the
    # image it is loaded from.
    # Arena budget over the staged binaries.  An input to the image edge, not a
    # bystander: an over-subscribed arena means the shell cannot spawn its own
    # tools, which is not a disk worth writing.  kernel.s and task.s are inputs
    # because the check derives FGX_STK_ARENA_PAGES and TASK_STACK_MAX_PAGES
    # from them, so a geometry change re-runs it without a clean build; the
    # ttys table and the generated config are inputs because the check holds
    # the consoles turned on against CFG_KERNEL_NPROC, which it reads from
    # include/config.s (the generated copy, so the edge orders after genconfig
    # and a stale copy is never what it reads); a fourth console turned on
    # without either re-running it left a red check under a green stamp.
    lines.append("\nbuild build/.stack_budget: stkbudget " + " ".join(staged) +
                 " | tools/check_stack_budget.py include/kernel.s "
                 "src/kernel/task.s disk_src/etc/ttys include/config.s")

    # STALE STAGED FILES, which ninja cannot express as an absence.  This ran
    # inside mkimage.sh until the ProDOS image was retired; it is not an image
    # concern at all but a staging one, so it outlived the thing it lived in.
    # It depends on every staged output so it cannot run before staging finishes,
    # and the image depends on IT so the image is never built over a leftover.
    lines.append("build build/.staged_pruned: prunestaged "
                 + " ".join(staged + mod_outs + man_outs)
                 + " | tools/prune_staged.py build/staged.list")
    # THE UFS IMAGE STAGES disk_src VERBATIM, so it depends on the same tree the
    # ProDOS images do.  It used to name only the modules and the kernel banks,
    # and the gap was not theoretical: /etc/rc is GENERATED from rc.in by
    # mkimage.sh, so whichever edge ran first decided what shipped -- a change
    # to rc.in reached disk/fgx.po and left disk/fgxroot.fs carrying the old
    # one, which read as "the change does nothing on UFS" (apple/fgx#315).
    # `staged' was missing for the same reason and is the wider half of it: a
    # rebuilt binary reached the ProDOS image and not this one.
    lines.append("build bin/fgxunix: fgxunix | bin/fgx.bin bin/fgxfar.bin "
                 "bin/fgxtty.bin disk_src/lib/modules/vfs "
                 "disk_src/lib/modules/ufs disk_src/lib/modules/ufsdir "
                 "tools/mkfgxunix.py")
    lines.append("build disk/fgxroot.fs: ufsboot | " +
                 " ".join(staged + mod_outs + mod_checked) +
                 " build/.staged_pruned build/.stack_budget bin/fgxunix "
                 "build/.zoneinfo_staged disk_src/etc/localtime "
                 "build/loader_padded.bin build/stage2.bin "
                 "disk_src/etc/rc.in disk_src/etc/boot.conf "
                 "tools/make_ufsboot.sh tools/fgxfs.py tools/bake_stage2.py "
                 "build/staged.list build/dev_nodes.list " +
                 " ".join(tree_inputs))
    # THE 800K FLOPPY IS PARKED (2026-09-06).  The rule, the edge and
    # tools/make_floppy.sh all STAY, commented rather than deleted: "if we
    # pursue a floppy image later it will be with a specific purpose", and the
    # purpose is what would decide what goes on it.
    #
    # It does not fit and has not for some time -- apple/fgx#340 measured it
    # over by `rm' + `sync', 75,261 bytes or about 147 ProDOS blocks, by
    # dropping binaries until the image built.  That is not campaign drift: the
    # whole of 2026-09-06's kernel growth was 517 bytes.  Each FGX2 binary
    # carries its own ~70 KB libc pile, so /bin is what fills it, and the three
    # UFS modules a rescue disk needs to read the filesystem it is meant to
    # repair are another ~150 KB.
    #
    # WHAT PARKING IT COSTS, stated rather than discovered later: `ninja
    # release' no longer produces disk/fgx-floppy.po, so CI's
    # release job publishes no fgx-floppy-X.Y.Z.po asset, tools/cleanroom.sh
    # does not check for one, and floppy_boot skips.  Those four places carry
    # the same note.  Un-parking means deciding what the floppy is FOR first --
    # a rescue disk, an installer, a demo -- because that decides the payload,
    # which is the thing that does not fit.
    #
    # lines.append("build disk/fgx-floppy.po: floppy | " + " ".join(staged + mod_outs) +
    #              " bin/fgx.bin bin/fgxfar.bin bin/fgxtty.bin build/loader_padded.bin tools/make_floppy.sh "
    #              "tools/ninja/mkimage.sh tools/bake_stage2.py disk_src/etc/rc.in")
    # THE FLOPPY IS PART OF `disk`, and therefore of the default build.
    #
    # It was only reachable through `release`, so a tree that had never built
    # it -- a fresh clone, or anything after `ninja -t clean` -- ran
    # floppy_boot against a file that did not exist.  The harness raised
    # FileNotFoundError and the suite came back 88/1/1: a red that says nothing
    # about the floppy boot path, on the FIRST run a new checkout ever does.
    # It costs ~2.4 s (apple/fgx#83).
    # THE 800K FLOPPY IS OFF THE DEFAULT BUILD (2026-08-21).  The rule
    # and its edge stay -- `ninja disk/fgx-floppy.po` still makes one, and the
    # release target still carries it, because CI publishes
    # fgx-floppy-X.Y.Z.po as a release asset.  What it is NOT any more is a
    # thing every campaign build has to keep fitting.
    #
    # It is the tightest artifact in the tree and nothing reported that until
    # it broke: 480 bytes of far bank added during UFS 1.7d overflowed it, and
    # the failure surfaced as `ADDFILE disk_src/bin/mkdir failed (image full?)`
    # from a probe gate -- a message about mkdir, from a change to the VFS.
    # Maintaining an 800K budget across a campaign that is moving banks around
    # is a tax on the campaign, not a check on it.
    #
    # Revisit when the VFS work settles.  It will be easier then than it is
    # now: the probe modules came off it in the same commit that found this,
    # so whoever picks it up starts with ~11 KB more room than this did.
    # /dev rides with the boot disk: it is part of the machine (UFS 1.7d I3),
    # and the harness attaches it to every test the way it attaches the boot
    # unit.  A `ninja disk` that did not build it would leave every run
    # without a /dev.
    # disk/ufsscratch.fs JOINS THE DEFAULT BUILD AT UFS 1.8b-2, because a test
    # in the ORDINARY SUITE now needs it.  It has existed since 1.10a and has
    # never been here: the five kernel.ufs*probe gates that use it are driven
    # by tools/tryprobe.sh, which builds it explicitly -- and DELETES it first,
    # because those probes WRITE to it and MAME is handed the image by path
    # with no per-run copy.  It joined the DEFAULT build for `mountprobe',
    # which was in GATE_TESTS and only read; that test was retired on
    # 2026-09-05 with the /dev volume it probed, and the image stays in the
    # default build because mount(8)'s test will want a second spindle and
    # because a fixture built only by a knob is a fixture a fresh clone lacks.
    # disk/fgxroot.fs joins them at UFS 2.3 for the same reason ufsscratch did:
    # `ufsboot' is an ordinary suite test, and a test whose fixture is not
    # built is a test that goes red on a fresh clone and nowhere else.
    lines.append("build disk: phony disk/fgxdev.fs "
                 "disk/ufsscratch.fs disk/ufsbadspin.fs disk/fgxroot.fs "
                 "disk/ufsfewino.fs disk/pdscratch.po")
    # `release' IS THE UFS IMAGE NOW.  It named disk/fgx-release.po, which was
    # the ProDOS variant -- a second image built from the same tree, differing
    # only in whether /etc/rc kept netstart.  Nothing booted it and nothing
    # shipped it: release.sh names no image at all.
    lines.append("build release: phony disk/fgxroot.fs")
    lines.append("\nbuild userland: phony " +
                 " ".join(f"bin/{n}.bin" for n in built))
    lines.append("build kernel: phony bin/fgx.bin bin/fgxfar.bin bin/fgxtty.bin build/.kernel_checked")
    # Inputs are the artifact sources AND the artifacts' own sidecars, so the
    # guard re-runs whether you edit a source or regenerate an artifact.
    # MUST MIRROR check_libc_piles.ARTIFACTS: an input this edge omits is one
    # whose change leaves the guard un-rerun, which is a guard that is green
    # because it did not look.  toolchain/src/cc/* is in the list because fcc is
    # a source of every one of these artifacts (apple/fgx#33).
    libc_pats = ("toolchain/lib/libc_c/*.c", "toolchain/lib/libc_c/core.list",
                 "toolchain/include/*.h",
                 "toolchain/include/sys/*.h", "toolchain/include/arpa/*.h",
                 "toolchain/include/netinet/*.h",
                 "toolchain/lib/libcurses_c/*.c", "toolchain/lib/libcurses_c/*.ext",
                 "toolchain/lib/libtermlib_c/*.c",
                 "toolchain/src/cc/*.c", "toolchain/src/cc/*.h")
    lines.append(
        "\nbuild build/.libc_checked: libcchk toolchain/lib/libc_c.s "
        "toolchain/lib/libc_c_data.s toolchain/lib/libc_c.srcsha "
        "toolchain/lib/libc_so.srcsha "
        "toolchain/lib/libcurses.srcsha toolchain/lib/libtermlib.srcsha | "
        "tools/check_libc_piles.py " +
        " ".join(sorted(
            rel(p) for pat in libc_pats
            for p in glob.glob(os.path.join(ROOT, pat)))))
    # ---- THE GENERATOR REGENERATES ITSELF (apple/fgx#171) ----------------
    #
    # Without this edge `build.ninja` is a file nothing rebuilds, and that is
    # not a tidiness problem -- it is a build that LIES.  The fcc output under
    # src/kernel/vfs is TRACKED and reaches a module through a PUT, so:
    # a C file is added to a source list here; gen.py is not re-run; there is
    # no rule to compile it; the stale committed .s assembles perfectly; and
    # ninja reports "no work to do" while every check passes.
    #
    # It cost a whole session on feat/ufs-1.11a-inode -- every edit to
    # ufs_inode.c and ufs_vnops.c compiled to nothing -- and worse, it produced
    # a CONFIDENT WRONG MEASUREMENT written into a RESUME as the narrowing for
    # the next session: an early `return` that "still hung" had never been
    # compiled.
    #
    # `generator = 1` is what makes this safe: ninja re-runs the edge when its
    # inputs change and, crucially, `ninja -t clean` does NOT delete build.ninja.
    #
    # THE `touch` IS LOAD-BEARING, and leaving it out is a subtler version of
    # the same bug.  write_if_changed deliberately does NOT restamp a file whose
    # content is unchanged, so a regeneration producing identical text leaves
    # build.ninja older than the input that triggered it -- and ninja then
    # considers it perpetually dirty and re-runs the generator on EVERY
    # invocation.  `ninja -n` never reaches "no work to do", which is exactly
    # what gate.sh's staleness guard requires, so the gate would fail on a clean
    # tree.  Measured: without it, `ninja -n` still reported the regen step
    # immediately after a successful `ninja`.
    #
    # Touching is safe HERE and only here: build.ninja is the output of this
    # edge and an input to no other (it appears exactly once in the emitted
    # graph), so advancing its mtime cannot cascade the way restamping a file
    # other edges read would -- the self-invalidation that once turned a
    # 1-test change into 302.
    #
    # THE INPUT LIST IS WHAT gen.py ACTUALLY READS.  A missed input is the same
    # silent staleness one level up, so the stubs are globbed rather than
    # typed: this module, the tool manifest, and each tool's companion
    # *_stubs.s, whose existence decides whether a link edge names it.
    # .fgx_tz IS ALWAYS AN INPUT, so writing a zone into it re-runs gen.py.  A
    # missing input with no rule stops ninja, so the file is made empty when it
    # is absent -- empty is UTC, as absent was -- and a zone set after the first
    # build is no longer ignored.
    tzp = os.path.join(ROOT, ".fgx_tz")
    if not os.path.exists(tzp):
        open(tzp, "w").close()
    # docs/PROVENANCE.md: a new row is a new input to the provenance stamp.
    gen_inputs = ["tools/ninja/gen.py", "tools/ninja/manifest.json", ".fgx_tz",
                  "docs/PROVENANCE.md"]
    gen_inputs += sorted(
        rel(p) for p in glob.glob(os.path.join(ROOT, "src/userland/*/*_stubs.s")))
    lines.append("rule regen_ninja\n"
                 "  command = python3 tools/ninja/gen.py -o $out && touch $out\n"
                 "  description = regenerating $out\n"
                 "  generator = 1\n")
    lines.append("build build.ninja: regen_ninja | " + " ".join(gen_inputs) + "\n")

    _prov = subprocess.run(
        [sys.executable, os.path.join(ROOT, "tools/check_provenance.py"),
         "--inputs"], cwd=ROOT, capture_output=True, text=True, check=True)
    lines.append("build build/.provenance_checked: provcheck | "
                 "tools/check_provenance.py " +
                 " ".join(_prov.stdout.split()) + "\n")
    lines.append("build all: phony kernel modules userland probes disk "
                 "build/.libc_checked build/.provenance_checked "
                 "build/static_libs/libtermlib.s\n")
    lines.append("# `ninja release` builds the CLEAN image + floppy\n")
    lines.append("default all\n")
    write_if_changed(os.path.join(ROOT, out_path), "\n".join(lines))
    return len(built)


def main(argv):
    covered, uncovered = parse_tools()
    if "--report" in argv:
        print(f"COVERED by the ninja graph ({len(covered)} C tools + kernel):")
        print("   ", " ".join(sorted(covered)))
        print(f"\nNOT covered -- still build.sh ({len(uncovered)} tools):")
        print("   ", " ".join(sorted(uncovered)) or "(none)")
        print("\nCOVERED: the linker probes (wrapped scripts + real dep sets),")
        print("         stage2, disk_src staging (147 copies parsed from build.sh),")
        print("         and disk/fgx.po via make_disk.sh --skip-kernel.")
        print("\nNOT covered: `build.sh release` (DISK_EXCLUDE + FGX_RELEASE_IMAGE),")
        print("             the 800K floppy, and cmd_verify.")
        return 0
    out = "build.ninja"
    if "-o" in argv:
        out = argv[argv.index("-o") + 1]
    # THE /dev NODE TABLE IS WRITTEN HERE, beside build.ninja and for the same
    # reason: both are derived from this file, so both are regenerated whenever
    # it is.  It is not a ninja edge because its only input is DEV_NODES above
    # -- an edge would need this script as its dependency, which is the
    # self-regen edge build.ninja itself deliberately does not have.
    write_dev_nodes_c()
    write_devnodes_s()
    write_dev_chrtoblk_c()
    write_dev_nodes_list()
    n = emit(covered, out)
    print(f"wrote {out}: {n} tools")
    print("covers: kernel, the manifest's tools, linker probes, staging, disk image."
          "  See --report for what is still build.sh's.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
