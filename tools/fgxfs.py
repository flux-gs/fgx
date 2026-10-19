#!/usr/bin/env python3
"""fgxfs -- host-side reader, writer and fsck for the 2.11BSD filesystem.

WHAT THIS IS FOR.  The UFS migration campaign's goal 2 is that an FGX volume
mounts on a real 2.11BSD PDP-11/70 and vice versa.  That is a claim about bytes,
and the only way to hold it is to have an INDEPENDENT implementation of the same
format that can be pointed at anything FGX writes.  This is that implementation.
It is deliberately NOT a port of FGX's kernel code and shares no source with it:
two implementations agreeing is evidence, one implementation agreeing with
itself is not.

BYTE ORDER IS THE WHOLE GAME.  Measured on the real machine 2026-08-09 (kernel
#18), not inferred from headers: the long 0x01020304 stores as the bytes
02 01 04 03 -- HIGH WORD FIRST, little-endian within each word.  A short stores
as 02 01, so 16-bit fields overlay a 65816 directly and only 32-bit fields need
converting.  The conversion is exactly a 16-bit half-swap.  Every 32-bit field
in this file goes through u32()/p32() and none is ever read with '<I'.

  16-bit, direct overlay: di_mode di_nlink di_uid di_gid di_flags
                          d_ino d_reclen d_namlen fs_isize fs_ninode
                          fs_nfree fs_step fs_cyl fs_tinode fs_lasti
                          fs_nbehind fs_flags
  32-bit, half-swapped:   di_size di_addr[7] di_atime di_mtime di_ctime
                          fs_fsize fs_free[50] fs_time fs_tfree
                          -- and every indirect block, which is 256 raw
                             daddr_t and nothing else.

BLOCK SIZES.  Two of them, and confusing them corrupts volumes.  The FILESYSTEM
block is 1024 bytes and is what every daddr_t in this file counts.  The DEVICE
sector is 512 bytes; fsbtodb(b) == b<<1 converts.  This tool addresses the image
in filesystem blocks throughout, exactly as 2.11BSD's own mkfs does
(`lseek(fso, bno*DEV_BSIZE, 0)` with DEV_BSIZE == 1024).  DIRBLKSIZ is a THIRD
size, 512, and is neither of the others: a directory's 1024-byte block holds two
independent 512-byte directory blocks and an entry may not straddle them.

Usage:
  fgxfs.py mkfs IMAGE --size BLOCKS [--bytes-per-inode N]
  fgxfs.py ls IMAGE [PATH]
  fgxfs.py cat IMAGE PATH                  # to stdout, bytes-exact
  fgxfs.py put IMAGE SRC PATH [MODE]        # MODE octal, default by destination
  fgxfs.py mkfile IMAGE PATH --blocks N    # deterministic per-block fill
  fgxfs.py mkdir IMAGE PATH
  fgxfs.py symlink IMAGE TARGET PATH
  fgxfs.py link IMAGE EXISTING NEWPATH      # hard link; directories refused
  fgxfs.py mknod IMAGE PATH c|b DEV [MODE]  # MODE octal, default 666
  fgxfs.py chown IMAGE PATH UID GID
  fgxfs.py fsck IMAGE
  fgxfs.py dump IMAGE                      # superblock summary
  fgxfs.py --self-test
"""
import os
import stat as statmod
import sys
import time

# ---------------------------------------------------------------------------
# Format constants.  From examples/2.11BSD/usr/sys/h/{fs.h,inode.h,dir.h} and
# confirmed against the live PDP-11/70 measurement in the campaign plan.
# ---------------------------------------------------------------------------
DEV_BSIZE = 1024                # filesystem block
SECTOR = 512                    # device sector; fsbtodb(b) == b<<1
DIRBLKSIZ = 512                 # directory sub-block
MAXNAMLEN = 63
NICFREE = 50                    # daddr_t in the superblock free cache
NICINOD = 100                   # ino_t in the superblock inode cache
INOPB = 16                      # dinode per filesystem block
NINDIR = DEV_BSIZE // 4         # 256 daddr_t per indirect block
NDADDR = 4
NIADDR = 3
DINODE_SZ = 64
SBLOCK = 1                      # superblock lives in filesystem block 1
ROOTINO = 2
LOSTFOUNDINO = 3
MAXMNTLEN = 12
SB_SIZE = 446                   # sizeof(struct fs), measured

IFMT = 0o170000
IFDIR = 0o040000
IFCHR = 0o020000
IFBLK = 0o060000
IFREG = 0o100000
IFLNK = 0o120000
ISUID = 0o4000
ISGID = 0o2000
ISVTX = 0o1000

# ---------------------------------------------------------------------------
# INSTALL MODES.  A file's mode comes from where it is being installed, which
# is how 2.11BSD assigns one: `install -s -m 751 -g staff ${STD} ${NSTD}
# ${DESTDIR}/bin' (vendor/2.11BSD/usr/bin/Makefile:65), `install -m 755 -c
# $$i.csh ${DESTDIR}/usr/ucb/$$i' (usr/ucb/Makefile:55), and the setuid
# programs named one by one -- `SETUID= mail rcp su' (usr/bin/Makefile:34),
# installed `-o root -m 4751' (:70), with login and passwd spelling the same
# thing 4755 in their own Makefiles (usr/bin/login/Makefile:40,
# usr/bin/passwd/Makefile:44).  There is no install(1) on this volume and no
# mode on the host copy either -- every staged binary is 0644 in disk_src --
# so `put' is where the rule has to live, and putting it here rather than in
# make_ufsboot.sh covers the test harness's own staging too.
#
# 755 WHERE 2.11BSD USES 751, deliberately.  Load_Binary reads an image
# through a descriptor opened FREAD, where Reno's exec reads the vnode
# directly (`vn_rdwr(UIO_READ, vp, ... IO_UNIT|IO_NODELOCKED, cred, &resid)',
# vendor/4.3BSD-Reno/kern/kern_exec.c:156).  A 751 binary is unreadable to
# `other' and would therefore be unexecutable by them here, which is not what
# 751 means anywhere else.
# ---------------------------------------------------------------------------
EXEC_DIRS = ("/bin/", "/sbin/", "/testbin/", "/tests/fcc/", "/usr/fgx/bin/")
SETUID_FILES = ("/bin/su", "/bin/passwd", "/bin/login", "/bin/crontab")


def install_mode(path):
    """The permission bits a file gets when staged at PATH."""
    if path in SETUID_FILES:
        return 0o4755
    for d in EXEC_DIRS:
        if path.startswith(d):
            return 0o755
    return 0o644


# THE TEMP DIRECTORIES ARE STICKY, and they have to be BEFORE ufs_lookup asks
# VWRITE of a parent (apple/fgx#419): the moment that check exists, a 0755
# /tmp is a /tmp no unprivileged account can write, and vi, sh and half the
# suite write there.  0777 is what makes it usable and ISVTX is what keeps it
# from being a way to delete other people's files -- 2.11BSD's own words for
# the rule it enforces are "if directory is sticky, then user must own the
# directory, or the file in it, else he may not delete it (unless he's root).
# This implements append-only directories" (usr/sys/sys/ufs_namei.c:615-619).
#
# NO UPSTREAM FILE IS CITED FOR THE NUMBER ITSELF and that is deliberate: the
# vendored tree carries no /etc/rc and no hierarchy file, so there is nothing
# here to quote for "/tmp is 1777".  The kernel rule above is the evidence
# that ISVTX belongs on a world-writable directory; the 0777 half is what the
# CREATE check requires of a directory everyone writes in.
STICKY_DIRS = ("/tmp", "/var/tmp")

# cron's spool is its and root's alone: cron(8) makes both directories 0700
# when they are missing (2.11BSD usr.sbin/cron/misc.c, set_cron_cwd), and
# crontab(1), setuid root, is how anyone else reaches them.
PRIVATE_DIRS = ("/var/cron", "/var/cron/tabs")


def install_dirmode(path):
    """The permission bits a DIRECTORY gets when staged at PATH."""
    if path in STICKY_DIRS:
        return 0o1777
    if path in PRIVATE_DIRS:
        return 0o700
    return 0o755

# mkfs's own defaults (usr/sbin/mkfs/mkfs.c)
DEF_BYTES_PER_INODE = 4096
DEF_N = 100                     # interleave modulus
DEF_M = 2                       # interleave step
MAXFN = 750


def dirsiz(namlen):
    """DIRSIZ from dir.h: a 6-byte header plus the name, rounded TOGETHER.

    Reno rounds an 8-byte header and the name SEPARATELY, which is why
    ufs_lookup.c's reclen arithmetic is a rewrite and not a copy.  Getting this
    wrong produces directories that mount and read fine on FGX and that
    2.11BSD's fsck rejects.
    """
    return ((6 + namlen + 1) + 3) & ~3


def itod(ino):
    """Filesystem block holding inode `ino`.  Block 2 holds inodes 1..16."""
    return (ino + 2 * INOPB - 1) // INOPB


def itoo(ino):
    """Slot of inode `ino` within its block."""
    return (ino + 2 * INOPB - 1) % INOPB


# ---------------------------------------------------------------------------
# PDP-11 32-bit accessors.  High word first, little-endian within each word.
# ---------------------------------------------------------------------------
def u32(buf, off):
    hi = buf[off] | (buf[off + 1] << 8)
    lo = buf[off + 2] | (buf[off + 3] << 8)
    return (hi << 16) | lo


def p32(buf, off, val):
    val &= 0xFFFFFFFF
    hi, lo = val >> 16, val & 0xFFFF
    buf[off] = hi & 0xFF
    buf[off + 1] = (hi >> 8) & 0xFF
    buf[off + 2] = lo & 0xFF
    buf[off + 3] = (lo >> 8) & 0xFF


def u16(buf, off):
    return buf[off] | (buf[off + 1] << 8)


def p16(buf, off, val):
    val &= 0xFFFF
    buf[off] = val & 0xFF
    buf[off + 1] = (val >> 8) & 0xFF


class FsError(Exception):
    pass


# ---------------------------------------------------------------------------
# Superblock.  Offsets are the MEASURED ones; struct fs packs contiguously to
# exactly 446 with no interior padding, because a PDP-11 long is 2-aligned and
# not 4-aligned.  fs_fsize at offset 2 rather than 4 is the load-bearing case.
# ---------------------------------------------------------------------------
SB_ISIZE = 0        # u_short  first block after the i-list
SB_FSIZE = 2        # daddr_t  size in blocks of the entire volume
SB_NFREE = 6        # short
SB_FREE = 8         # daddr_t[50]
SB_NINODE = 208     # short
SB_INODE = 210      # ino_t[100]
SB_FLOCK = 410
SB_FMOD = 411
SB_ILOCK = 412
SB_RONLY = 413
SB_TIME = 414       # time_t
SB_TFREE = 418      # daddr_t
SB_TINODE = 422     # ino_t
SB_STEP = 424       # short
SB_CYL = 426        # short
SB_FSMNT = 428      # char[12]
SB_LASTI = 440      # ino_t
SB_NBEHIND = 442    # ino_t
SB_FLAGS = 444      # u_short
MNT_CLEAN    = 0x2000   # fs_flags: cleanly unmounted (2.11BSD update #456)
MNT_WASCLEAN = 0x4000   # fs_flags: was clean at mount


class Super:
    """The in-core superblock, decoded.  Field names match 2.11BSD's.

    fs_fsize is NOT renamed here even though the campaign plan mandates a
    field-name firewall: that firewall exists for the KERNEL port, where Reno
    code using fs_fsize-as-fragment-size would be compiled against 2.11BSD's
    fs_fsize-as-volume-size.  This file contains no Reno code at all, so the
    collision cannot occur, and matching the vendor header exactly is what makes
    this readable next to it.
    """

    def __init__(self, raw):
        b = bytearray(raw)
        self.isize = u16(b, SB_ISIZE)
        self.fsize = u32(b, SB_FSIZE)
        self.nfree = u16(b, SB_NFREE)
        self.free = [u32(b, SB_FREE + 4 * i) for i in range(NICFREE)]
        self.ninode = u16(b, SB_NINODE)
        self.inode = [u16(b, SB_INODE + 2 * i) for i in range(NICINOD)]
        self.time = u32(b, SB_TIME)
        self.tfree = u32(b, SB_TFREE)
        self.tinode = u16(b, SB_TINODE)
        self.step = u16(b, SB_STEP)
        self.cyl = u16(b, SB_CYL)
        self.fsmnt = bytes(b[SB_FSMNT:SB_FSMNT + MAXMNTLEN])
        self.lasti = u16(b, SB_LASTI)
        self.nbehind = u16(b, SB_NBEHIND)
        self.flags = u16(b, SB_FLAGS)

    def pack(self):
        b = bytearray(DEV_BSIZE)
        p16(b, SB_ISIZE, self.isize)
        p32(b, SB_FSIZE, self.fsize)
        p16(b, SB_NFREE, self.nfree)
        for i in range(NICFREE):
            p32(b, SB_FREE + 4 * i, self.free[i])
        p16(b, SB_NINODE, self.ninode)
        for i in range(NICINOD):
            p16(b, SB_INODE + 2 * i, self.inode[i])
        p32(b, SB_TIME, self.time)
        p32(b, SB_TFREE, self.tfree)
        p16(b, SB_TINODE, self.tinode)
        p16(b, SB_STEP, self.step)
        p16(b, SB_CYL, self.cyl)
        b[SB_FSMNT:SB_FSMNT + MAXMNTLEN] = self.fsmnt.ljust(MAXMNTLEN, b"\0")
        p16(b, SB_LASTI, self.lasti)
        p16(b, SB_NBEHIND, self.nbehind)
        p16(b, SB_FLAGS, self.flags)
        return bytes(b)


# ---------------------------------------------------------------------------
# dinode.  64 bytes: mode@0 nlink@2 uid@4 gid@6 size@8 addr@12 reserved@40
# flags@50 atime@52 mtime@56 ctime@60.
# ---------------------------------------------------------------------------
class Dinode:
    def __init__(self, raw=None, ino=0):
        self.ino = ino
        if raw is None:
            self.mode = self.nlink = self.uid = self.gid = 0
            self.size = 0
            self.addr = [0] * (NDADDR + NIADDR)
            self.flags = 0
            self.atime = self.mtime = self.ctime = 0
            return
        b = bytearray(raw)
        self.mode = u16(b, 0)
        self.nlink = u16(b, 2)
        self.uid = u16(b, 4)
        self.gid = u16(b, 6)
        self.size = u32(b, 8)
        self.addr = [u32(b, 12 + 4 * i) for i in range(NDADDR + NIADDR)]
        self.flags = u16(b, 50)
        self.atime = u32(b, 52)
        self.mtime = u32(b, 56)
        self.ctime = u32(b, 60)

    def pack(self):
        b = bytearray(DINODE_SZ)
        p16(b, 0, self.mode)
        p16(b, 2, self.nlink)
        p16(b, 4, self.uid)
        p16(b, 6, self.gid)
        p32(b, 8, self.size)
        for i in range(NDADDR + NIADDR):
            p32(b, 12 + 4 * i, self.addr[i])
        p16(b, 50, self.flags)
        p32(b, 52, self.atime)
        p32(b, 56, self.mtime)
        p32(b, 60, self.ctime)
        return bytes(b)

    @property
    def ifmt(self):
        return self.mode & IFMT

    def isdir(self):
        return self.ifmt == IFDIR

    def isreg(self):
        return self.ifmt == IFREG

    def isdev(self):
        return self.ifmt in (IFCHR, IFBLK)


# ---------------------------------------------------------------------------
# The volume.
# ---------------------------------------------------------------------------
class Volume:
    def __init__(self, path, writable=False):
        self.path = path
        self.f = open(path, "r+b" if writable else "rb")
        self.writable = writable
        self.sb = Super(self.bread(SBLOCK))

    def close(self):
        self.f.close()

    # -- raw block IO, addressed in FILESYSTEM blocks ------------------------
    def bread(self, bno):
        self.f.seek(bno * DEV_BSIZE)
        d = self.f.read(DEV_BSIZE)
        if len(d) != DEV_BSIZE:
            raise FsError(f"short read of block {bno} "
                          f"({len(d)} of {DEV_BSIZE}) -- image truncated?")
        return d

    def bwrite(self, bno, data):
        if len(data) != DEV_BSIZE:
            raise FsError(f"bwrite of {len(data)} bytes to block {bno}; "
                          f"blocks are {DEV_BSIZE}")
        self.f.seek(bno * DEV_BSIZE)
        self.f.write(data)

    def sbsync(self, clean=True):
        # THE IMAGE THIS TOOL WRITES IS CLEAN, and saying so is what makes the
        # boot fsck affordable.  2.11BSD update #456 ("filesystem clean",
        # Johnny Billquist) adds MNT_CLEAN 0x2000 to the superblock's fs_flags
        # and MNT_WASCLEAN 0x4000 beside it; fsck(8) skips a filesystem
        # carrying them unless -f.  A volume this tool has just finished
        # writing is consistent by construction -- it is the same statement a
        # clean unmount makes, made by the program that did the writing.
        #
        # MEASURED, which is why it is here rather than left to the machine:
        # /etc/rc's fsck on a 32000-block root reads the whole i-list and every
        # block of every file through a single-block read path, and took the
        # boot from under 45 seconds to over 90.  The suite never shuts a
        # machine down cleanly -- every test boots a fresh copy of this image
        # -- so without this line every one of them would pay that.
        #
        # The kernel CLEARS it on the first writable mount and puts it back on
        # a clean unmount, so an image that is then modified by a running FGX
        # stops claiming to be clean the moment it is mounted read-write.
        #
        # `clean=False' IS FOR THE CALLER THAT KNOWS THE PREMISE IS FALSE.
        # "Consistent by construction" holds for a volume this tool built and
        # nothing else touched; tools/ufscorrupt.py plants a fault on purpose,
        # and an image that carries one must not tell fsck there is nothing to
        # look at -- fsck skips a clean filesystem, so it would never reach the
        # fault the image exists to present.
        if clean:
            self.sb.flags |= MNT_CLEAN | MNT_WASCLEAN
        else:
            self.sb.flags &= ~(MNT_CLEAN | MNT_WASCLEAN)
        self.bwrite(SBLOCK, self.sb.pack())

    # -- inodes -------------------------------------------------------------
    def iget(self, ino):
        if ino < 1:
            raise FsError(f"inode {ino}: inode numbers start at 1")
        d = itod(ino)
        if d >= self.sb.isize:
            raise FsError(f"inode {ino} is past the i-list "
                          f"(block {d} >= isize {self.sb.isize})")
        blk = self.bread(d)
        off = itoo(ino) * DINODE_SZ
        return Dinode(blk[off:off + DINODE_SZ], ino)

    def iput(self, dp):
        d = itod(dp.ino)
        if d >= self.sb.isize:
            raise FsError(f"inode {dp.ino} is past the i-list")
        blk = bytearray(self.bread(d))
        off = itoo(dp.ino) * DINODE_SZ
        blk[off:off + DINODE_SZ] = dp.pack()
        self.bwrite(d, bytes(blk))

    def ninodes(self):
        """Highest valid inode number.  Block 2 holds 1..16, so this is
        (isize - 2) * INOPB and inode 0 does not exist."""
        return (self.sb.isize - 2) * INOPB

    # -- the free list ------------------------------------------------------
    #
    # v7's design, unchanged in 2.11BSD: the superblock caches up to NICFREE
    # addresses, and when it drains, the LAST address taken is itself a block
    # holding the next batch (struct fblk).  So an fblk container is also a free
    # block -- it is on the list, and its contents matter only while it is.
    # fs_free[0] == 0 terminates.
    def free_blocks(self):
        nfree, free = self.sb.nfree, list(self.sb.free)
        seen = set()
        while nfree > 0:
            nfree -= 1
            bno = free[nfree]
            if bno == 0:
                return
            if bno in seen:
                raise FsError(f"free list loops at block {bno}")
            seen.add(bno)
            yield bno
            if nfree <= 0:
                fb = self.bread(bno)
                nfree = u16(fb, 0)
                if nfree > NICFREE:
                    raise FsError(f"fblk at block {bno} claims {nfree} entries "
                                  f"(max {NICFREE})")
                free = [u32(fb, 2 + 4 * i) for i in range(NICFREE)]

    def alloc(self):
        """Take one block off the free list.  Mirrors mkfs.c's alloc()."""
        sb = self.sb
        if sb.nfree <= 0:
            raise FsError("out of free space (nfree is 0)")
        sb.nfree -= 1
        bno = sb.free[sb.nfree]
        if bno == 0:
            raise FsError("out of free space (hit the terminator)")
        if sb.nfree <= 0:
            fb = self.bread(bno)
            sb.nfree = u16(fb, 0)
            sb.free = [u32(fb, 2 + 4 * i) for i in range(NICFREE)]
        sb.tfree -= 1
        self.bwrite(bno, bytes(DEV_BSIZE))
        return bno

    def bfree(self, bno):
        """Return a block to the free list.  Mirrors mkfs.c's bfree()."""
        sb = self.sb
        if bno != 0:
            sb.tfree += 1
        if sb.nfree >= NICFREE:
            fb = bytearray(DEV_BSIZE)
            p16(fb, 0, sb.nfree)
            for i in range(NICFREE):
                p32(fb, 2 + 4 * i, sb.free[i])
            self.bwrite(bno, bytes(fb))
            sb.nfree = 0
        sb.free[sb.nfree] = bno
        sb.nfree += 1

    def ialloc(self, mode):
        """Allocate an inode.  Scans the i-list for a free slot.

        The superblock's fs_inode[] cache is deliberately NOT consulted or
        refilled: mkfs leaves it empty (fs_ninode == 0) and the kernel refills it
        by scanning, so a host tool that only ever scans stays correct and cannot
        hand out an inode the cache also holds.
        """
        for ino in range(ROOTINO, self.ninodes() + 1):
            dp = self.iget(ino)
            if dp.mode == 0 and dp.nlink == 0:
                fresh = Dinode(ino=ino)
                fresh.mode = mode
                fresh.nlink = 1
                fresh.atime = fresh.mtime = fresh.ctime = self.sb.time
                self.iput(fresh)
                self.sb.tinode -= 1
                return fresh
        raise FsError("out of inodes")

    # -- bmap: 4 direct + 3 indirect ---------------------------------------
    def bmap(self, dp, lbn, alloc=False):
        """Logical block -> physical block.  Returns 0 for a hole when not
        allocating.  Indirect blocks are 256 raw daddr_t and nothing else, so
        every entry is half-swapped."""
        if lbn < NDADDR:
            if dp.addr[lbn] == 0 and alloc:
                dp.addr[lbn] = self.alloc()
            return dp.addr[lbn]
        lbn -= NDADDR
        # Pick the indirect level: single covers NINDIR, double NINDIR**2, ...
        for level in range(NIADDR):
            span = NINDIR ** (level + 1)
            if lbn < span:
                return self._bmap_indirect(dp, NDADDR + level, level, lbn, alloc)
            lbn -= span
        raise FsError("block number beyond the 3-level indirect range")

    def _bmap_indirect(self, dp, slot, level, lbn, alloc):
        bno = dp.addr[slot]
        if bno == 0:
            if not alloc:
                return 0
            bno = self.alloc()
            dp.addr[slot] = bno
        for lvl in range(level, -1, -1):
            idx = (lbn // (NINDIR ** lvl)) % NINDIR
            blk = bytearray(self.bread(bno))
            nxt = u32(blk, 4 * idx)
            if nxt == 0:
                if not alloc:
                    return 0
                nxt = self.alloc()
                p32(blk, 4 * idx, nxt)
                self.bwrite(bno, bytes(blk))
            bno = nxt
        return bno

    def blocks_of(self, dp):
        """Every block an inode owns: data blocks AND the indirect blocks
        themselves.  fsck needs both or it reports the indirects as missing."""
        if dp.isdev():
            return
        nblocks = (dp.size + DEV_BSIZE - 1) // DEV_BSIZE
        for i in range(min(nblocks, NDADDR)):
            if dp.addr[i]:
                yield dp.addr[i]
        if nblocks <= NDADDR:
            return
        remaining = nblocks - NDADDR
        for level in range(NIADDR):
            if remaining <= 0:
                break
            span = NINDIR ** (level + 1)
            take = min(remaining, span)
            if dp.addr[NDADDR + level]:
                yield from self._walk_indirect(dp.addr[NDADDR + level],
                                               level, take)
            remaining -= take

    def _walk_indirect(self, bno, level, count):
        yield bno
        blk = self.bread(bno)
        if level == 0:
            for i in range(min(count, NINDIR)):
                v = u32(blk, 4 * i)
                if v:
                    yield v
            return
        per = NINDIR ** level
        i = 0
        while count > 0 and i < NINDIR:
            v = u32(blk, 4 * i)
            take = min(count, per)
            if v:
                yield from self._walk_indirect(v, level - 1, take)
            count -= take
            i += 1

    # -- file data ----------------------------------------------------------
    def read_file(self, dp):
        out = bytearray()
        remaining = dp.size
        lbn = 0
        while remaining > 0:
            bno = self.bmap(dp, lbn)
            chunk = min(remaining, DEV_BSIZE)
            # A hole reads as zeroes, which is what 2.11BSD does.
            out += self.bread(bno)[:chunk] if bno else bytes(chunk)
            remaining -= chunk
            lbn += 1
        return bytes(out)

    def write_file(self, dp, data):
        for lbn in range((len(data) + DEV_BSIZE - 1) // DEV_BSIZE):
            chunk = data[lbn * DEV_BSIZE:(lbn + 1) * DEV_BSIZE]
            bno = self.bmap(dp, lbn, alloc=True)
            self.bwrite(bno, chunk.ljust(DEV_BSIZE, b"\0"))
        dp.size = len(data)
        self.iput(dp)

    # -- directories --------------------------------------------------------
    def readdir(self, dp):
        """Yield (ino, name, reclen, offset).  Entries never straddle a
        DIRBLKSIZ boundary, so each 512-byte sub-block is scanned on its own."""
        if not dp.isdir():
            raise FsError(f"inode {dp.ino} is not a directory")
        data = self.read_file(dp)
        for base in range(0, len(data), DIRBLKSIZ):
            sub = data[base:base + DIRBLKSIZ]
            off = 0
            while off + 6 <= len(sub):
                ino = u16(sub, off)
                reclen = u16(sub, off + 2)
                namlen = u16(sub, off + 4)
                if reclen == 0:
                    raise FsError(f"inode {dp.ino}: zero d_reclen at "
                                  f"offset {base + off} -- directory is corrupt "
                                  f"and scanning it would not terminate")
                if reclen % 4 or off + reclen > len(sub):
                    raise FsError(f"inode {dp.ino}: d_reclen {reclen} at offset "
                                  f"{base + off} runs past the {DIRBLKSIZ}-byte "
                                  f"directory block or is not 4-aligned")
                if ino != 0:
                    if namlen > MAXNAMLEN or dirsiz(namlen) > reclen:
                        raise FsError(f"inode {dp.ino}: d_namlen {namlen} does "
                                      f"not fit d_reclen {reclen}")
                    name = bytes(sub[off + 6:off + 6 + namlen])
                    yield ino, name.decode("ascii", "replace"), reclen, base + off
                off += reclen

    def lookup(self, dp, name):
        for ino, nm, _, _ in self.readdir(dp):
            if nm == name:
                return ino
        return 0

    def namei(self, path):
        dp = self.iget(ROOTINO)
        for comp in [c for c in path.split("/") if c]:
            ino = self.lookup(dp, comp)
            if ino == 0:
                raise FsError(f"{path}: no such file or directory ({comp})")
            dp = self.iget(ino)
        return dp

    def direnter(self, dirp, name, ino):
        """Add an entry, reusing a free slot if one fits.

        This is the reclen arithmetic the campaign plan flags as the part that
        does NOT cross over from Reno: a 6-byte header rounded together with the
        name, not an 8-byte header rounded separately.
        """
        need = dirsiz(len(name))
        if len(name) > MAXNAMLEN:
            raise FsError(f"{name!r}: longer than MAXNAMLEN ({MAXNAMLEN})")
        data = bytearray(self.read_file(dirp))
        for base in range(0, len(data), DIRBLKSIZ):
            off = 0
            while off < DIRBLKSIZ:
                p = base + off
                eino = u16(data, p)
                reclen = u16(data, p + 2)
                namlen = u16(data, p + 4)
                used = 0 if eino == 0 else dirsiz(namlen)
                if reclen - used >= need:
                    if used:
                        p16(data, p + 2, used)      # shrink the live entry
                        p = p + used
                        reclen = reclen - used
                    self._put_dirent(data, p, ino, reclen, name)
                    self.write_file(dirp, bytes(data))
                    return
                off += reclen
        # No slot anywhere: grow by one directory block.
        blk = bytearray(DIRBLKSIZ)
        self._put_dirent(blk, 0, ino, DIRBLKSIZ, name)
        data += blk
        self.write_file(dirp, bytes(data))

    @staticmethod
    def _put_dirent(buf, off, ino, reclen, name):
        p16(buf, off, ino)
        p16(buf, off + 2, reclen)
        p16(buf, off + 4, len(name))
        raw = name.encode("ascii")
        buf[off + 6:off + 6 + len(raw)] = raw
        # Names are guaranteed null terminated; pad the rounded slack too.
        for i in range(off + 6 + len(raw), off + dirsiz(len(name))):
            buf[i] = 0

    def mkdir(self, parent, name, mode=0o755):
        dp = self.ialloc(IFDIR | mode)
        dp.nlink = 2
        blk = bytearray(DIRBLKSIZ)
        self._put_dirent(blk, 0, dp.ino, dirsiz(1), ".")
        self._put_dirent(blk, dirsiz(1), parent.ino,
                         DIRBLKSIZ - dirsiz(1), "..")
        self.write_file(dp, bytes(blk))
        self.direnter(parent, name, dp.ino)
        parent.nlink += 1
        self.iput(parent)
        self.iput(dp)
        return dp

    def mknod(self, parent, name, mode, dev):
        """Make a device node.

        THE DEVICE NUMBER IS NOT A BLOCK NUMBER, IT IS THE SAME BYTES.
        2.11BSD's inode carries `i_rdev` in a union laid over the address
        array (h/inode.h:60-63):

            union {
                daddr_t I_addr[NADDR];
                struct { u_short I_dummy; dev_t I_rdev; } i_d;
            } i_un2;

        so `I_dummy` occupies the first two bytes of `di_addr[0]` and `I_rdev`
        the next two.  With this format's word order -- high word first -- the
        first two bytes ARE the high half, which makes the device number the
        LOW half of di_addr[0] and i_dummy the high half.  mknod() writes
        exactly that pair (ufs_syscalls.c:220-231: `ip->i_rdev = uap->dev;
        ip->i_dummy = 0;`), and it is the encoding ufs_setrdev() writes on the
        target, so a node made here and a node made by the kernel are the same
        bytes.
        """
        if (mode & IFMT) not in (IFCHR, IFBLK):
            raise FsError(f"mknod: mode 0{mode:o} is neither IFCHR nor IFBLK")
        dp = self.ialloc(mode)
        dp.addr[0] = dev & 0xFFFF           # i_rdev; i_dummy stays zero
        self.iput(dp)
        self.direnter(parent, name, dp.ino)
        return dp


# ---------------------------------------------------------------------------
# mkfs.  Follows usr/sbin/mkfs/mkfs.c step for step, including the interleaved
# free-list construction, so a volume this produces is one 2.11BSD would.
# ---------------------------------------------------------------------------
def mkfs(path, size, bytes_per_inode=DEF_BYTES_PER_INODE,
         f_m=DEF_M, f_n=DEF_N, mtime=0):
    if size < 8:
        raise FsError(f"size {size} blocks is too small for a filesystem")
    if f_n <= 0 or f_n >= MAXFN:
        f_n = MAXFN
    if f_m <= 0 or f_m > f_n:
        f_m = 3

    n = (size * DEV_BSIZE // bytes_per_inode) // INOPB
    n = max(n, 1)
    n = min(n, 65500 // INOPB)
    isize = n + 2
    if isize >= size:
        raise FsError(f"{size}/{isize - 2}: bad ratio -- the i-list would fill "
                      f"the volume; raise --bytes-per-inode or --size")

    with open(path, "wb") as f:
        f.truncate(size * DEV_BSIZE)

    vol = object.__new__(Volume)
    vol.path = path
    vol.f = open(path, "r+b")
    vol.writable = True
    sb = object.__new__(Super)
    sb.isize, sb.fsize = isize, size
    sb.nfree, sb.free = 0, [0] * NICFREE
    sb.ninode, sb.inode = 0, [0] * NICINOD
    sb.time, sb.tfree, sb.tinode = mtime, 0, 0
    sb.step, sb.cyl = f_m, f_n
    sb.fsmnt = b"/"
    sb.lasti, sb.nbehind, sb.flags = 1, 0, 0
    vol.sb = sb

    # Zero the i-list.  Every slot counts as a free inode until iput takes one.
    for b in range(2, isize):
        vol.bwrite(b, bytes(DEV_BSIZE))
        sb.tinode += INOPB

    _bflist(vol, f_m, f_n)
    _fsinit(vol, mtime)

    sb.time = mtime
    vol.sbsync()
    vol.f.close()


def _bflist(vol, f_m, f_n):
    """mkfs.c's bflist(): free every data block, in the interleaved order the
    rotational-latency pattern wants, walking the volume BACKWARDS."""
    sb = vol.sb
    flg = [0] * f_n
    adr = [0] * f_n
    i = 0
    for j in range(f_n):
        while flg[i]:
            i = (i + 1) % f_n
        adr[j] = i + 1
        flg[i] = 1
        i = (i + f_m) % f_n

    vol.bfree(0)                       # the terminator; does not count as free
    d = sb.fsize - 1
    while d % f_n:
        d += 1
    while d > 0:
        for i in range(f_n):
            f = d - adr[i]
            if sb.isize <= f < sb.fsize:
                vol.bfree(f)
        d -= f_n

    # inode 1 is a historical hack: bad blocks were once linked to it, and dump
    # tapes still assume it exists, so mkfs marks it allocated and empty.
    ihack = Dinode(ino=1)
    ihack.mode = IFREG
    vol.iput(ihack)
    sb.tinode -= 1


def _fsinit(vol, mtime):
    """mkfs.c's fsinit(): lost+found first, then the root."""
    sb = vol.sb

    # lost+found -- a full 1024-byte block, with the second 512-byte directory
    # block holding one empty entry that claims all of it.
    buf = bytearray(DEV_BSIZE)
    Volume._put_dirent(buf, 0, LOSTFOUNDINO, dirsiz(1), ".")
    Volume._put_dirent(buf, dirsiz(1), ROOTINO, DIRBLKSIZ - dirsiz(1), "..")
    for off in range(DIRBLKSIZ, DEV_BSIZE, DIRBLKSIZ):
        p16(buf, off, 0)
        p16(buf, off + 2, DIRBLKSIZ)
        p16(buf, off + 4, 0)
    lf = Dinode(ino=LOSTFOUNDINO)
    lf.mode = IFDIR | 0o755
    lf.nlink = 2
    lf.size = DEV_BSIZE
    lf.atime = lf.mtime = lf.ctime = mtime
    lf.addr[0] = vol.alloc()
    vol.bwrite(lf.addr[0], bytes(buf))
    vol.iput(lf)
    sb.tinode -= 1

    # root -- one 512-byte directory block: ".", "..", "lost+found".
    buf = bytearray(DEV_BSIZE)
    off = 0
    Volume._put_dirent(buf, off, ROOTINO, dirsiz(1), ".")
    off += dirsiz(1)
    Volume._put_dirent(buf, off, ROOTINO, dirsiz(2), "..")
    off += dirsiz(2)
    Volume._put_dirent(buf, off, LOSTFOUNDINO, DIRBLKSIZ - off, "lost+found")
    root = Dinode(ino=ROOTINO)
    root.mode = IFDIR | 0o755
    root.nlink = 3                     # ".", "..", and lost+found's ".."
    root.size = DIRBLKSIZ
    root.atime = root.mtime = root.ctime = mtime
    root.addr[0] = vol.alloc()
    vol.bwrite(root.addr[0], bytes(buf))
    vol.iput(root)
    sb.tinode -= 1


# ---------------------------------------------------------------------------
# fsck -- THE ORACLE.  Every claim FGX makes about a volume it wrote is checked
# here by code that shares nothing with it.  This must be able to FAIL: see the
# mutation arms in the self-test, which corrupt a volume five different ways and
# require a non-zero exit from each.
# ---------------------------------------------------------------------------
def fsck(path, verbose=True):
    vol = Volume(path)
    errs = []
    sb = vol.sb

    def bad(msg):
        errs.append(msg)

    # -- phase 0: the superblock is self-consistent -------------------------
    real_blocks = os.path.getsize(path) // DEV_BSIZE
    if sb.fsize > real_blocks:
        bad(f"superblock says {sb.fsize} blocks, image holds {real_blocks}")
    if not 2 < sb.isize < sb.fsize:
        bad(f"isize {sb.isize} is not inside (2, fsize {sb.fsize})")
    if sb.nfree > NICFREE:
        bad(f"fs_nfree {sb.nfree} exceeds NICFREE {NICFREE}")
    if sb.ninode > NICINOD:
        bad(f"fs_ninode {sb.ninode} exceeds NICINOD {NICINOD}")
    if errs:
        # Everything below indexes off these; keep going and it just lies.
        return _fsck_report(path, errs, verbose)

    data_lo, data_hi = sb.isize, sb.fsize

    # -- phase 1: blocks claimed by inodes ----------------------------------
    owner = {}
    links = {}
    inodes = {}
    for ino in range(1, vol.ninodes() + 1):
        dp = vol.iget(ino)
        inodes[ino] = dp
        if dp.mode == 0:
            if dp.nlink or dp.size or any(dp.addr):
                bad(f"inode {ino}: mode 0 but nlink={dp.nlink} "
                    f"size={dp.size} addr={[a for a in dp.addr if a]}")
            continue
        if dp.isdev():
            # A DEVICE INODE OWNS NO BLOCKS, BUT IT IS NOT EXEMPT FROM THE
            # SCAN.  di_addr[0] is the rdev pair and must not be read as a
            # block; every OTHER slot must be zero.  2.11BSD's own fsck says
            # so by arithmetic rather than by a special case
            # (usr/sbin/fsck/pass1.c:66-104):
            #
            #     ndb = howmany(dp->di_size, DEV_BSIZE);
            #     if (SPECIAL(dp)) ndb++;
            #     for (lj = ndb; lj < NDADDR; lj++)
            #         if (dp->di_addr[j] != 0) goto unknown;
            #
            # -- size 0 gives ndb 0, SPECIAL bumps it to 1, so slot 0 is
            # exempt and slots 1..3 plus all three indirects are checked.  An
            # inode this tool skipped entirely would pass here and be CLEARED
            # by the referee, which is the one failure goal 2 cannot tolerate.
            stray = [i for i in range(1, NDADDR + NIADDR) if dp.addr[i]]
            if stray:
                bad(f"inode {ino}: device node with block addresses in "
                    f"di_addr{stray} (2.11BSD fsck clears this inode)")
            if dp.size:
                bad(f"inode {ino}: device node has size {dp.size}, not 0")
            continue
        try:
            blks = list(vol.blocks_of(dp))
        except FsError as e:
            bad(f"inode {ino}: {e}")
            continue
        for b in blks:
            if not (data_lo <= b < data_hi):
                bad(f"inode {ino}: block {b} is outside the data area "
                    f"[{data_lo}, {data_hi})")
                continue
            if b in owner:
                bad(f"block {b} is claimed by BOTH inode {owner[b]} "
                    f"and inode {ino} (cross-linked)")
            else:
                owner[b] = ino

    # -- phase 2: the directory tree ----------------------------------------
    seen = set()
    stack = [(ROOTINO, "/")]
    while stack:
        ino, path_so_far = stack.pop()
        if ino in seen:
            continue
        seen.add(ino)
        dp = inodes.get(ino)
        if dp is None:
            bad(f"{path_so_far}: inode {ino} is past the i-list")
            continue
        if not dp.isdir():
            continue
        try:
            entries = list(vol.readdir(dp))
        except FsError as e:
            bad(f"{path_so_far}: {e}")
            continue
        names = [nm for _, nm, _, _ in entries]
        if names[:2] != [".", ".."]:
            bad(f"{path_so_far}: first two entries are {names[:2]}, "
                f"expected ['.', '..']")
        for eino, nm, _, _ in entries:
            links[eino] = links.get(eino, 0) + 1
            if not 1 <= eino <= vol.ninodes():
                bad(f"{path_so_far}{nm}: inode {eino} is out of range")
                continue
            if nm not in (".", ".."):
                child = inodes[eino]
                if child.mode == 0:
                    bad(f"{path_so_far}{nm}: names unallocated inode {eino}")
                if child.isdir():
                    stack.append((eino, f"{path_so_far}{nm}/"))

    # -- phase 3: link counts -----------------------------------------------
    for ino, dp in inodes.items():
        if dp.mode == 0 or ino == 1:
            continue
        got = links.get(ino, 0)
        if got == 0:
            bad(f"inode {ino}: allocated (mode {dp.mode:o}) but UNREFERENCED "
                f"-- no directory entry names it")
        elif got != dp.nlink:
            bad(f"inode {ino}: link count is {dp.nlink} but {got} directory "
                f"entries name it")

    # -- phase 4: the free list, and every block accounted exactly once -----
    free = []
    try:
        free = list(vol.free_blocks())
    except FsError as e:
        bad(str(e))
    freeset = set()
    for b in free:
        if not (data_lo <= b < data_hi):
            bad(f"free list holds block {b}, outside the data area "
                f"[{data_lo}, {data_hi})")
            continue
        if b in owner:
            bad(f"block {b} is on the FREE LIST and also owned by "
                f"inode {owner[b]}")
        freeset.add(b)
    if len(free) != len(freeset):
        bad(f"the free list holds {len(free)} entries but only "
            f"{len(freeset)} distinct blocks -- duplicates")

    missing = set(range(data_lo, data_hi)) - freeset - set(owner)
    if missing:
        s = sorted(missing)
        bad(f"{len(missing)} block(s) are neither free nor owned by any inode "
            f"(first few: {s[:8]}) -- 2.11BSD's fsck salvages these back onto "
            f"the free list, so anything relying on them staying put, such as a "
            f"reserved range for stage2, WILL be overwritten")

    if sb.tfree != len(freeset):
        bad(f"fs_tfree says {sb.tfree} free blocks, the list holds "
            f"{len(freeset)}")
    # fs_tinode IS NOT AN FSCK QUESTION, AND THIS USED TO SAY IT WAS.
    #
    # The check above it -- fs_tfree against the counted free list -- is
    # upstream's, `pass5.c`:
    #
    #     else if (n_free != sblock.fs_tfree &&
    #        dofix(&idesc,"FREE BLK COUNT WRONG IN SUPERBLOCK")) {
    #             sblock.fs_tfree = n_free;
    #             sbdirty();
    #     }
    #
    # This one was written by symmetry with it and has NO upstream counterpart.
    # Read in vendor/2.11BSD, not recalled:
    #
    #   - fsck's inode half of pass 5 is `ifreechk()', and it validates
    #     something else entirely: that the superblock's CACHED free-inode list
    #     `fs_inode[0..fs_ninode]' holds no ALLOCATED inode.  It never counts
    #     the i-list.
    #   - `fs_tinode' appears in the whole tool exactly once, and not as a
    #     check -- `main.c:234', inside `if (debug)'.  It is never written:
    #     `makefree()' rebuilds the free list and sets `fs_ninode = 0', leaving
    #     fs_tinode alone.  So upstream neither validates nor repairs it.
    #   - The KERNEL treats it as a running statistic and nothing more:
    #     `ufs_alloc.c:170' decrements it in ialloc, `:292' increments it in
    #     ifree, and `ufs_syscalls2.c:76' hands it to statfs as `f_ffree'.
    #     Nothing consults it to make a decision -- ialloc finds a free inode by
    #     SCANNING -- so a stale value costs df's accuracy and nothing else.
    #
    # WHICH IS WHY IT MATTERS THAT THIS TOOL AGREES.  The oracle's authority is
    # that it speaks for 2.11BSD about bytes; a rule upstream does not have will
    # call volumes broken that 2.11BSD calls fine.  It did, on the first real
    # one it ever met: examples/pdp11/2.11BSD_rq.dsk, a live system's root, has
    # fs_tinode 1373 against 1397 free in its i-list -- and a tcsh.core in / to
    # suggest why.  apple/fgx#271.
    #
    # KEPT AS A NOTE rather than deleted, because the disagreement is still
    # worth seeing on a volume FGX WROTE: this tool's own writers maintain
    # fs_tinode exactly, so a difference there means FGX's ialloc/ifree have
    # stopped keeping 2.11BSD's statistic. Upstream prints it under `debug' and
    # this prints it under `verbose'; neither calls it a problem.
    nfree_inodes = sum(1 for dp in inodes.values() if dp.mode == 0)
    notes = []
    if sb.tinode != nfree_inodes:
        notes.append(f"fs_tinode says {sb.tinode} free inodes, the i-list "
                     f"holds {nfree_inodes} -- a df statistic, not a defect: "
                     f"2.11BSD's fsck neither checks nor repairs it")

    return _fsck_report(path, errs, verbose, vol, len(owner), len(freeset),
                        notes)


def _fsck_report(path, errs, verbose, vol=None, used=0, free=0, notes=None):
    """NOTES ARE NOT PROBLEMS AND DO NOT CHANGE THE STATUS.  The distinction is
    upstream's: 2.11BSD's fsck repairs what it can prove wrong and merely
    PRINTS what it cannot -- `fs_tinode' being the case that made this
    necessary (apple/fgx#271).  A note that could fail a run would put this
    tool back to rejecting volumes 2.11BSD calls clean."""
    if errs:
        print(f"fgxfs fsck {path}: {len(errs)} PROBLEM(S)", file=sys.stderr)
        for e in errs:
            print(f"  {e}", file=sys.stderr)
        return 1
    if verbose and vol is not None:
        sb = vol.sb
        print(f"fgxfs fsck {path}: clean -- {sb.fsize} blocks "
              f"({used} used, {free} free), i-list {sb.isize - 2} blocks "
              f"({vol.ninodes()} inodes, {sb.tinode} free)")
        for n in (notes or []):
            print(f"  note: {n}")
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def _mode_str(dp):
    kind = {IFDIR: "d", IFCHR: "c", IFBLK: "b", IFREG: "-", IFLNK: "l"}
    out = [kind.get(dp.ifmt, "?")]
    out += [(c if dp.mode & bit else "-")
            for c, bit in zip("rwxrwxrwx", (0o400, 0o200, 0o100, 0o40, 0o20,
                                            0o10, 0o4, 0o2, 0o1))]
    # ls(1) spells the set-id bits over the execute column they modify: `s'
    # where the x is also set, `S' where it is not (2.11BSD usr/bin/ls/ls.c).
    # Without this a 4755 binary reads as 0755 here and the one thing this
    # listing is used to check would be invisible.
    if dp.mode & ISUID:
        out[3] = "s" if dp.mode & 0o100 else "S"
    if dp.mode & ISGID:
        out[6] = "s" if dp.mode & 0o10 else "S"
    # And ISVTX over the OTHER execute column, `t' with the x and `T' without,
    # which is ls's ninth mode word: `{ 3, S_ISVTX|(S_IEXEC>>6), 't', S_ISVTX,
    # 'T', S_IEXEC>>6, 'x', '-' }' (2.11BSD usr/bin/ls/ls.c:622).  A sticky
    # /tmp reads drwxrwxrwt, which is the one thing this listing is used to
    # check for apple/fgx#419.
    if dp.mode & ISVTX:
        out[9] = "t" if dp.mode & 0o1 else "T"
    return "".join(out)


def cmd_ls(vol, path):
    dp = vol.namei(path)
    if not dp.isdir():
        print(f"{_mode_str(dp)} {dp.nlink:3d} {dp.size:8d} {path}")
        return 0
    for ino, name, _, _ in vol.readdir(dp):
        e = vol.iget(ino)
        print(f"{_mode_str(e)} {e.nlink:3d} {e.size:8d} {ino:6d} {name}")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    if len(argv) < 2:
        print(__doc__.rstrip(), file=sys.stderr)
        return 2

    cmd, args = argv[1], argv[2:]
    try:
        if cmd == "mkfs":
            image = args[0]
            size = None
            bpi = DEF_BYTES_PER_INODE
            i = 1
            while i < len(args):
                if args[i] == "--size":
                    size = int(args[i + 1]); i += 2
                elif args[i] == "--bytes-per-inode":
                    bpi = int(args[i + 1]); i += 2
                else:
                    raise FsError(f"unknown option {args[i]}")
            if size is None:
                raise FsError("mkfs needs --size BLOCKS (1024-byte blocks)")
            mkfs(image, size, bpi)
            print(f"fgxfs mkfs {image}: {size} blocks")
            return 0
        if cmd == "fsck":
            return fsck(args[0])
        if cmd == "ls":
            vol = Volume(args[0])
            return cmd_ls(vol, args[1] if len(args) > 1 else "/")
        if cmd == "cat":
            vol = Volume(args[0])
            sys.stdout.buffer.write(vol.read_file(vol.namei(args[1])))
            return 0
        if cmd == "put":
            # put [--replace] <image> <hostfile> <destpath>
            #
            # --replace OVERWRITES A NAME THAT IS ALREADY THERE, in place, and
            # exists because the test harness stages fixtures over shipped
            # config files (tools/mame_test/run.py `stage_files').  Without it
            # a second `put' of /etc/ttys adds a SECOND directory entry of that
            # name: namei answers with whichever it meets first, so the fixture
            # would apply or not depending on directory order.
            #
            # THE OLD BLOCKS ARE FREED RATHER THAN ORPHANED.  Writing over the
            # inode and setting the new size would leave every block past it
            # allocated and unreferenced, and fsck counts those -- the harness
            # runs ufsfsck_check.py on the same images this writes.
            #
            # EVERY BLOCK, INDIRECTS INCLUDED.  This used to free the four
            # direct addresses and refuse anything larger, because the loop did
            # not descend an indirect block and a bigger replacement would have
            # leaked the tree.  `blocks_of' already yields the whole set --
            # data blocks AND the indirect blocks themselves, which is what
            # fsck counts -- so the refusal was a limit standing in for a
            # missing call.  apple/fgx#335 (credprobe) is where it bit:
            # bin/credprobe.bin outgrew four blocks.
            #
            # THE WALK IS MATERIALISED BEFORE THE FIRST bfree.  `blocks_of' is
            # a generator that READS each indirect block as it goes, so freeing
            # while iterating would have it parse blocks whose bitmap bits it
            # had just released.
            replace = False
            if args and args[0] == "--replace":
                replace = True
                args = args[1:]
            vol = Volume(args[0], writable=True)
            with open(args[1], "rb") as f:
                data = f.read()
            # THE HOST FILE'S mtime BECOMES THE INODE'S, and every file on the
            # volume read `Jan  1  1970' until it did.  ialloc stamps a fresh
            # inode from sb.time, mkfs defaults sb.time to 0, and nothing ever
            # passed one -- so the whole tree was epoch zero and `ls -l' said
            # so.  That looked like apple/fgx#319 (the kernel's stat image had
            # nowhere to put an epoch) and outlived its fix, because the times
            # the fixed kernel now reports faithfully were genuinely zero.
            # Taking them from the source file makes them mean something and
            # keeps them stable across rebuilds of an unchanged tree.
            hostmtime = int(os.path.getmtime(args[1]))
            dirpath, _, name = args[2].rpartition("/")
            parent = vol.namei(dirpath or "/")
            dp = None
            if replace:
                try:
                    dp = vol.namei(args[2])
                except Exception:
                    dp = None
            if dp is not None:
                for bno in list(vol.blocks_of(dp)):
                    vol.bfree(bno)
                for i in range(NDADDR + NIADDR):
                    dp.addr[i] = 0
                dp.size = 0
                vol.write_file(dp, data)
            else:
                mode = (int(args[3], 8) if len(args) > 3
                        else install_mode(args[2]))
                dp = vol.ialloc(IFREG | mode)
                vol.write_file(dp, data)
                vol.direnter(parent, name, dp.ino)
            dp.atime = dp.mtime = dp.ctime = hostmtime
            vol.iput(dp)
            vol.sbsync()
            vol.close()
            return 0
        if cmd == "mkfile":
            # A DETERMINISTIC FILE, sized in blocks, for the kernel's bmap and
            # read-path probes to walk.  `put` needs a source file on the host;
            # this needs nothing, so the build rule stays one line and the
            # artifact stays byte-identical between builds -- which is what lets
            # ninja prune it and the gate's staleness checks mean anything.
            #
            # THE CONTENT IS A FUNCTION OF THE LOGICAL BLOCK NUMBER, two bytes
            # per block repeated: lbn low byte, lbn high byte.  So a reader that
            # returns the right BYTES from the wrong BLOCK is caught, which a
            # constant fill or a random fill would both miss -- the first has no
            # per-block identity and the second cannot be predicted by the
            # kernel-side probe without shipping a copy of it.
            vol = Volume(args[0], writable=True)
            nblocks = None
            i = 2
            while i < len(args):
                if args[i] == "--blocks":
                    nblocks = int(args[i + 1]); i += 2
                else:
                    raise FsError(f"unknown option {args[i]}")
            if nblocks is None:
                raise FsError("mkfile needs --blocks N")
            data = bytearray()
            for lbn in range(nblocks):
                data += bytes([lbn & 0xFF, (lbn >> 8) & 0xFF]) * (DEV_BSIZE // 2)
            dirpath, _, name = args[1].rpartition("/")
            parent = vol.namei(dirpath or "/")
            dp = vol.ialloc(IFREG | 0o644)
            vol.write_file(dp, bytes(data))
            vol.direnter(parent, name, dp.ino)
            vol.sbsync()
            vol.close()
            print(f"fgxfs mkfile {args[0]}:{args[1]} = {nblocks} blocks, ino {dp.ino}")
            return 0
        if cmd == "mkdir":
            # EXISTING DIRECTORY IS SUCCESS, `mkdir -p' STYLE, AND A DUPLICATE
            # IS NOT POSSIBLE.  direnter appends unconditionally, so a second
            # mkdir of the same name used to make a SECOND directory with that
            # name in the same parent -- and fsck does not call that an error,
            # so the image shipped.  disk/fgxufs.po carried two `/dev's: one
            # staged from disk_src (holding PROOF) and one made by the
            # dev_nodes.list loop (holding every device node).  A lookup finds
            # whichever comes first, so /dev/null resolved into the directory
            # that has no nodes.  Both callers want "make sure it is there".
            vol = Volume(args[0], writable=True)
            dirpath, _, name = args[1].rpartition("/")
            parent = vol.namei(dirpath or "/")
            # THE MODE IS A FUNCTION OF THE PATH, as `put's is -- so /tmp is
            # sticky whichever caller makes it, the disk_src walk or a `d' row
            # in dev_nodes.list, and neither has to know.  An explicit octal
            # third argument overrides, which is what `put' takes too.
            mode = (int(args[2], 8) if len(args) > 2
                    else install_dirmode(args[1]))
            existing = vol.lookup(parent, name)
            if existing:
                ip = vol.iget(existing)
                if (ip.mode & IFMT) != IFDIR:
                    sys.stderr.write(f"fgxfs mkdir: {args[1]} exists and is "
                                     f"not a directory\n")
                    vol.close()
                    return 1
                # AN EXISTING DIRECTORY STILL TAKES THE MODE, so the answer
                # does not depend on which caller got there first.  Both the
                # disk_src walk and dev_nodes.list can name the same path, and
                # "mkdir -p style" must not mean "whoever ran first decides
                # whether /tmp is writable".
                if (ip.mode & 0o7777) != mode:
                    ip.mode = (ip.mode & ~0o7777) | mode
                    vol.iput(ip)
                    vol.sbsync()
                vol.close()
                return 0
            vol.mkdir(parent, name, mode)
            vol.sbsync()
            vol.close()
            return 0
        if cmd == "symlink":
            # symlink <image> <target> <linkpath>
            #
            # THE TARGET IS THE FILE'S CONTENT, which is all a 2.11BSD symlink
            # is: an IFLNK inode whose data bytes are the path it names and
            # whose size is that path's length.  ufs_readlink reads it with the
            # ordinary read path for exactly that reason.
            #
            # NO FAST SYMLINKS.  4.4BSD stores a short target in the di_addr
            # array itself; 2.11BSD does not, and this writes a data block like
            # any other file so the volume stays one a PDP-11/70 can read.
            vol = Volume(args[0], writable=True)
            target = args[1]
            dirpath, _, name = args[2].rpartition("/")
            parent = vol.namei(dirpath or "/")
            dp = vol.ialloc(IFLNK | 0o777)
            vol.write_file(dp, target.encode("ascii"))
            dp.atime = dp.mtime = dp.ctime = int(time.time())
            vol.iput(dp)
            vol.direnter(parent, name, dp.ino)
            vol.sbsync()
            vol.close()
            print("fgxfs symlink %s:%s -> %s, ino %d"
                  % (args[0], args[2], target, dp.ino))
            return 0
        if cmd == "link":
            # link <image> <existing> <newpath>
            #
            # A hard link is a second DIRECTORY ENTRY for one inode, which is
            # all this does: no data is copied and no inode is allocated.  The
            # link count on the inode is what makes the two names equal, so it
            # goes up with the entry -- ufs_link does the same two things
            # (4.3BSD-Reno ufs/ufs_vnops.c), and fsck counts entries against
            # di_nlink, so an entry without the increment is a corrupt volume.
            #
            # DIRECTORIES ARE REFUSED.  2.11BSD's link(2) allows one only for
            # the superuser and 4.3BSD-Reno's ufs_link refuses it outright
            # (EPERM); a linked directory makes a cycle that fsck cannot
            # untangle, and nothing here needs one.
            vol = Volume(args[0], writable=True)
            dp = vol.namei(args[1])
            if (dp.mode & IFMT) == IFDIR:
                raise FsError("%s: is a directory -- hard links to "
                              "directories are refused" % args[1])
            dirpath, _, name = args[2].rpartition("/")
            parent = vol.namei(dirpath or "/")
            dp.nlink += 1
            dp.ctime = int(time.time())
            vol.iput(dp)
            vol.direnter(parent, name, dp.ino)
            vol.sbsync()
            vol.close()
            print("fgxfs link %s:%s -> ino %d (nlink %d)"
                  % (args[0], args[2], dp.ino, dp.nlink))
            return 0
        if cmd == "mknod":
            # DEV is the whole device number, not a major/minor pair: FGX has
            # one major and the chardev registry is indexed by registration
            # order, so v_rdev IS that index (spec_vnops.c).  The argument is
            # accepted as one number for that reason rather than for brevity.
            vol = Volume(args[0], writable=True)
            kind = args[2]
            if kind not in ("c", "b"):
                raise FsError(f"mknod: type must be 'c' or 'b', not {kind!r}")
            dev = int(args[3], 0)
            perm = int(args[4], 8) if len(args) > 4 else 0o666
            dirpath, _, name = args[1].rpartition("/")
            parent = vol.namei(dirpath or "/")
            fmt = IFCHR if kind == "c" else IFBLK
            dp = vol.mknod(parent, name, fmt | (perm & 0o7777), dev)
            # A DEVICE NODE GETS A DATE TOO, for `put's reason one screen up:
            # ialloc stamps from sb.time, which is 0, so every /dev entry read
            # `Jan  1  1970' while the regular files beside them read real
            # dates.  There is no source file to take one from here, so the
            # build time is the honest answer -- it IS when the node was made.
            dp.atime = dp.mtime = dp.ctime = int(time.time())
            vol.iput(dp)
            vol.sbsync()
            vol.close()
            print(f"fgxfs mknod {args[0]}:{args[1]} = {kind} {dev}, "
                  f"ino {dp.ino}")
            return 0
        if cmd == "chown":
            # chown <image> <path> <uid> <gid>
            #
            # WHY A HOST-SIDE chown EXISTS AT ALL.  Every inode this program
            # makes is owned by root, because ialloc takes a mode and nothing
            # else -- which is right for /dev, /bin and /etc, and wrong for the
            # first thing on the image that belongs to somebody: a home
            # directory.  A staged tree that can only be root-owned is a system
            # where no ordinary user can write in their own home, and there is
            # nowhere else to fix it -- make_ufsboot.sh runs before the machine
            # has ever booted, so there is no chown(8) to call.
            #
            # NO mode ARGUMENT, deliberately.  The staging already sets one,
            # and a second way to set it would be a second place for the two to
            # disagree.  This changes ownership and nothing else, which is what
            # chown(8) does.
            vol = Volume(args[0], writable=True)
            dp = vol.namei(args[1])     # namei answers the INODE, not its number
            dp.uid = int(args[2], 0)
            dp.gid = int(args[3], 0)
            # ctime AND NOT mtime, which is what chown(2) touches: the inode
            # changed and the file did not.  ufs_setattr does the same.
            dp.ctime = int(time.time())
            vol.iput(dp)
            vol.sbsync()
            vol.close()
            print(f"fgxfs chown {args[0]}:{args[1]} = {dp.uid}:{dp.gid}")
            return 0
        if cmd == "dump":
            sb = Volume(args[0]).sb
            print(f"fsize   {sb.fsize}\nisize   {sb.isize}\n"
                  f"nfree   {sb.nfree}\nninode  {sb.ninode}\n"
                  f"tfree   {sb.tfree}\ntinode  {sb.tinode}\n"
                  f"step/cyl {sb.step}/{sb.cyl}\ntime    {sb.time}")
            return 0
    except (FsError, IndexError, ValueError) as e:
        print(f"fgxfs {cmd}: {e}", file=sys.stderr)
        return 1

    print(f"fgxfs: unknown command {cmd!r}", file=sys.stderr)
    return 2


# ---------------------------------------------------------------------------
# Self-test.  Two halves, and the second is the one that matters.
#
# The first half proves the tool can build and read a volume.  The second
# MUTATES a known-good volume five ways and requires fsck to reject each: an
# fsck that cannot fail is not an oracle, and this campaign's whole attribution
# argument rests on it being one.
# ---------------------------------------------------------------------------
TESTDATA = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "testdata", "211bsd")


def foreign_volume_test():
    """Read blocks off a REAL 2.11BSD volume and check every field against what
    that machine's own tools reported.

    THIS IS THE ONLY ARM THAT IS NOT SELF-REFERENTIAL.  Everything else in the
    self-test proves fgxfs agrees with fgxfs.  These three blocks were lifted
    read-only from a live PDP-11/70 (kernel #18, root on /dev/rra0a) on
    2026-08-09, and the values asserted below were reported INDEPENDENTLY by
    df(1), ls(1) and wc(1) on that machine in the same session:

        df /            7.6M total, 4.6M avail   -> fs_fsize 7942, fs_tfree 4739
        ls -ai / | wc -l            35 entries   -> 35 dirents parsed here
        ls -l / | grep ^d | wc -l   13 subdirs   -> root nlink 15 == 13 + 2
        ls -ai /                    inode numbers -> matched entry for entry

    If fgxfs's offsets, its half-swap, or its DIRSIZ arithmetic were wrong, the
    numbers below would not be these numbers.  A pure format change in fcc or in
    this file cannot make them agree by accident.
    """
    sb = Super(open(os.path.join(TESTDATA, "super.bin"), "rb").read())
    ilist = open(os.path.join(TESTDATA, "ilist2.bin"), "rb").read()
    rootblk = open(os.path.join(TESTDATA, "rootdir.bin"), "rb").read()

    # -- superblock, against df(1) -----------------------------------------
    assert sb.fsize == 7942, sb.fsize          # df: 7.6M
    assert sb.tfree == 4739, sb.tfree          # df: 4.6M avail
    assert sb.isize == 126, sb.isize
    assert sb.nfree == 40 and sb.ninode == 92
    assert sb.fsmnt.startswith(b"/"), sb.fsmnt
    # The half-swap is what makes fsize 7942 rather than nonsense.  Read the
    # same four bytes natively and the volume becomes 520 GB.
    raw = open(os.path.join(TESTDATA, "super.bin"), "rb").read()
    assert int.from_bytes(raw[2:6], "little") != sb.fsize, \
        "fs_fsize reads the same under PDP and native order in this sample, " \
        "so this arm cannot detect a byte-order regression"

    # -- inode block 2 holds inodes 1..16 ----------------------------------
    ihack = Dinode(ilist[itoo(1) * DINODE_SZ:itoo(1) * DINODE_SZ + DINODE_SZ], 1)
    root = Dinode(ilist[itoo(2) * DINODE_SZ:itoo(2) * DINODE_SZ + DINODE_SZ], 2)
    lf = Dinode(ilist[itoo(3) * DINODE_SZ:itoo(3) * DINODE_SZ + DINODE_SZ], 3)
    # mkfs's historical hack, still there decades later.
    assert ihack.mode == IFREG and ihack.nlink == 0, (ihack.mode, ihack.nlink)
    assert root.mode == (IFDIR | 0o755), oct(root.mode)
    assert root.nlink == 15, root.nlink        # 13 subdirs + "." + ".."
    assert root.size == DEV_BSIZE, root.size
    assert lf.mode == (IFDIR | 0o755) and lf.nlink == 2
    # lost+found is allocated before the root, so it holds the FIRST data block
    # -- which is what this tool's own mkfs does, because mkfs.c does it.
    assert lf.addr[0] == sb.isize, (lf.addr[0], sb.isize)

    # -- the root directory, through the same reclen arithmetic ------------
    entries = []
    for base in range(0, len(rootblk), DIRBLKSIZ):
        sub = rootblk[base:base + DIRBLKSIZ]
        off = 0
        while off + 6 <= len(sub):
            ino = u16(sub, off)
            reclen = u16(sub, off + 2)
            namlen = u16(sub, off + 4)
            assert reclen and reclen % 4 == 0 and off + reclen <= len(sub), \
                f"reclen {reclen} at {base + off} is not a valid record"
            if ino:
                assert dirsiz(namlen) <= reclen, (namlen, reclen)
                entries.append((ino, bytes(sub[off + 6:off + 6 + namlen])
                                .decode("ascii")))
            off += reclen
    assert len(entries) == 35, len(entries)    # ls -ai / | wc -l
    assert entries[0] == (ROOTINO, "."), entries[0]
    assert entries[1] == (ROOTINO, ".."), entries[1]
    assert entries[2] == (LOSTFOUNDINO, "lost+found"), entries[2]
    names = dict((nm, ino) for ino, nm in entries)
    # Inode numbers ls(1) printed on the machine itself.
    for nm, ino in (("bin", 103), ("dev", 33), ("etc", 454), ("home", 319),
                    ("lib", 592), ("sbin", 548), ("sys", 505)):
        assert names[nm] == ino, (nm, names[nm], ino)
    # The 13 subdirectories `ls -l / | grep ^d` reported on the machine.  Note
    # that "sys" is NOT among them -- it is a symlink, and assuming otherwise
    # made this arm off by one before it was measured.
    dirs = ("bin", "dev", "etc", "home", "juarez", "lib", "lost+found",
            "mdec", "mnt", "sbin", "tmp", "usr", "var")
    assert all(d in names for d in dirs), \
        [d for d in dirs if d not in names]
    # Each subdirectory's ".." links back, plus root's own "." and "..".
    assert root.nlink == len(dirs) + 2, (root.nlink, len(dirs))
    return len(entries)


def self_test():
    import tempfile

    # -- format constants, against the measured PDP-11/70 layout ------------
    assert dirsiz(1) == 8, dirsiz(1)            # "."
    assert dirsiz(2) == 12, dirsiz(2)           # ".."
    assert dirsiz(10) == 20, dirsiz(10)         # "lost+found"
    assert dirsiz(MAXNAMLEN) == 72, dirsiz(MAXNAMLEN)
    assert itod(1) == 2 and itoo(1) == 0
    assert itod(2) == 2 and itoo(2) == 1        # root is block 2, slot 1
    assert itod(16) == 2 and itoo(16) == 15
    assert itod(17) == 3 and itoo(17) == 0
    assert NINDIR == 256 and INOPB == 16

    # -- byte order: the measured case, both directions ---------------------
    b = bytearray(4)
    p32(b, 0, 0x01020304)
    assert bytes(b) == b"\x02\x01\x04\x03", bytes(b)
    assert u32(b, 0) == 0x01020304
    b2 = bytearray(2)
    p16(b2, 0, 0x0102)
    assert bytes(b2) == b"\x02\x01", bytes(b2)
    # A 32-bit field must NOT come out as native little-endian.  If this ever
    # passes, someone has "simplified" u32 into struct.unpack('<I') and every
    # volume this tool writes has become unreadable on a PDP-11.
    assert bytes(b) != (0x01020304).to_bytes(4, "little")

    # -- struct sizes -------------------------------------------------------
    assert len(Dinode().pack()) == DINODE_SZ == 64
    assert SB_FLAGS + 2 == SB_SIZE == 446, SB_SIZE
    assert SB_FSIZE == 2, "fs_fsize must sit at offset 2, not 4"
    d = Dinode()
    d.mode, d.size, d.ctime = IFREG | 0o644, 0x01020304, 0x0A0B0C0D
    d.addr[0] = 0x00010002
    r = Dinode(d.pack())
    assert (r.mode, r.size, r.ctime, r.addr[0]) == \
           (IFREG | 0o644, 0x01020304, 0x0A0B0C0D, 0x00010002)

    # -- the install rule, and that ls spells the set-id bit ----------------
    assert install_mode("/bin/ls") == 0o755, oct(install_mode("/bin/ls"))
    assert install_mode("/sbin/init") == 0o755
    assert install_mode("/testbin/credtest") == 0o755
    assert install_mode("/usr/fgx/bin/hello") == 0o755
    assert install_mode("/bin/su") == 0o4755
    assert install_mode("/etc/passwd") == 0o644
    assert install_mode("/etc/rc") == 0o644
    assert install_mode("/root/big300") == 0o644
    assert install_dirmode("/tmp") == 0o1777, oct(install_dirmode("/tmp"))
    assert install_dirmode("/var/tmp") == 0o1777
    assert install_dirmode("/var") == 0o755
    assert install_dirmode("/etc") == 0o755
    assert install_dirmode("/tmpfoo") == 0o755   # prefix, not the directory
    # A directory named like an exec dir but deeper is still not one of them.
    assert install_mode("/usr/share/bin") == 0o644
    d = Dinode()
    d.mode = IFREG | 0o4755
    assert _mode_str(d) == "-rwsr-xr-x", _mode_str(d)
    d.mode = IFREG | 0o4644
    assert _mode_str(d) == "-rwSr--r--", _mode_str(d)
    d.mode = IFREG | 0o2755
    assert _mode_str(d) == "-rwxr-sr-x", _mode_str(d)

    tmp = tempfile.mkdtemp(prefix="fgxfs-")
    img = os.path.join(tmp, "test.fs")

    # -- build a volume and read it back ------------------------------------
    mkfs(img, 2048, mtime=802671684)
    assert fsck(img, verbose=False) == 0, "a fresh mkfs must fsck clean"

    vol = Volume(img)
    root = vol.iget(ROOTINO)
    names = [nm for _, nm, _, _ in vol.readdir(root)]
    assert names == [".", "..", "lost+found"], names
    assert root.nlink == 3, root.nlink
    lf = vol.iget(vol.lookup(root, "lost+found"))
    assert lf.isdir() and lf.size == DEV_BSIZE, (lf.mode, lf.size)
    vol.close()

    # -- write files, including one big enough to need indirect blocks ------
    small = b"the quick brown fox\n"
    # 4 direct + 3 single-indirect blocks' worth: forces the first indirect.
    big = bytes((i * 7 + 3) & 0xFF for i in range(DEV_BSIZE * 9 + 17))
    for name, payload in (("small.txt", small), ("big.dat", big)):
        src = os.path.join(tmp, name)
        with open(src, "wb") as f:
            f.write(payload)
        assert main(["fgxfs", "put", img, src, "/" + name]) == 0
    assert main(["fgxfs", "mkdir", img, "/sub"]) == 0
    src = os.path.join(tmp, "small.txt")
    assert main(["fgxfs", "put", img, src, "/sub/nested"]) == 0
    assert fsck(img, verbose=False) == 0, "fsck must stay clean after writes"

    vol = Volume(img)
    assert vol.read_file(vol.namei("/small.txt")) == small
    assert vol.read_file(vol.namei("/big.dat")) == big, "indirect readback"
    assert vol.read_file(vol.namei("/sub/nested")) == small
    bigdp = vol.namei("/big.dat")
    assert bigdp.addr[NDADDR] != 0, "a 10-block file must use an indirect"
    # The indirect block is owned too, or fsck would call it missing.
    assert bigdp.addr[NDADDR] in set(vol.blocks_of(bigdp))
    sub = vol.namei("/sub")
    assert [nm for _, nm, _, _ in vol.readdir(sub)] == [".", "..", "nested"]
    assert vol.iget(ROOTINO).nlink == 4, "mkdir must bump the parent's nlink"
    vol.close()

    # -- put --replace over a file that OWNS AN INDIRECT BLOCK --------------
    # THE SUBJECT IS THE INDIRECT TREE, so the arm has to replace a file that
    # has one: /big.dat is 10 blocks and asserted above to hold a non-zero
    # di_addr[NDADDR].  Replacing it with 20 bytes must give back all ten data
    # blocks AND the indirect block that addressed six of them.
    #
    # THE ASSERTION IS THE BLOCK ACCOUNTING, not "it did not raise".  A replace
    # that freed only the four direct addresses returns 4 blocks where 11 are
    # owed, and fsck reports the other 7 as allocated-but-unreferenced -- so
    # the fsck arm and the count arm fail for the same defect from two
    # directions.  Before this call descended the indirect it REFUSED outright
    # (apple/fgx#335, credprobe), which is the third direction.
    #
    # IT GETS ITS OWN FILE rather than replacing /big.dat, because the mutation
    # arms below reach into /big.dat's tenth block by hand and a replaced one
    # would silently stop discriminating.
    _bigsrc = os.path.join(tmp, "rep.dat")
    with open(_bigsrc, "wb") as f:
        f.write(big)
    assert main(["fgxfs", "put", img, _bigsrc, "/rep.dat"]) == 0
    _v = Volume(img)
    _owned = len(list(_v.blocks_of(_v.namei("/rep.dat"))))
    _freed_before = len(list(_v.free_blocks()))
    _v.close()
    assert _owned == 11, _owned          # 10 data + 1 single indirect
    assert main(["fgxfs", "put", "--replace", img, src, "/rep.dat"]) == 0
    assert fsck(img, verbose=False) == 0, "fsck clean after an indirect replace"
    _v = Volume(img)
    assert _v.read_file(_v.namei("/rep.dat")) == small, "replaced content"
    _rp = _v.namei("/rep.dat")
    assert _rp.size == len(small), _rp.size
    assert _rp.addr[NDADDR] == 0, "the indirect address must be cleared"
    assert len([nm for _i, nm, _a, _b in _v.readdir(_v.namei("/"))
                if nm == "rep.dat"]) == 1, "--replace must not add a 2nd entry"
    _delta = len(list(_v.free_blocks())) - _freed_before
    _v.close()
    assert _delta == _owned - 1, (_delta, _owned)   # 11 back, 1 taken again

    # -- enough small files to force a second directory block ---------------
    for i in range(40):
        assert main(["fgxfs", "put", img, src, f"/f{i:02d}"]) == 0
    assert fsck(img, verbose=False) == 0, "fsck clean after directory growth"
    vol = Volume(img)
    got = [nm for _, nm, _, _ in vol.readdir(vol.iget(ROOTINO))]
    assert all(f"f{i:02d}" in got for i in range(40)), "entries went missing"
    assert vol.namei("/small.txt") is not None
    vol.close()

    # -- device nodes, asserted on the PLATTER rather than through Dinode ---
    # The encoding claim is about where two bytes land, so the assertion has to
    # read those two bytes.  Going through .addr[0] would agree with p32/u32 no
    # matter which half the number went into, and the half is the whole point:
    # a PDP-11 reads di_addr[0]'s first two bytes as i_dummy and the next two
    # as i_rdev, so a swapped pair is a device number of zero over there.
    assert main(["fgxfs", "mkdir", img, "/dev"]) == 0
    # A SECOND mkdir MUST NOT MAKE A SECOND DIRECTORY.  direnter appends
    # unconditionally and fsck does not call a duplicate name an error, so
    # without the guard this ships an image where a lookup finds whichever
    # entry comes first -- which is how disk/fgxufs.po ended up with two
    # /dev's, the nodes in one and PROOF in the other.
    assert main(["fgxfs", "mkdir", img, "/dev"]) == 0
    _v = Volume(img)
    assert len([nm for _i, nm, _a, _b in _v.readdir(_v.namei("/"))
                if nm == "dev"]) == 1, "mkdir must not duplicate an entry"
    _v.close()
    assert main(["fgxfs", "mknod", img, "/dev/null", "c", "0"]) == 0
    assert main(["fgxfs", "mknod", img, "/dev/console", "c", "7", "600"]) == 0
    assert main(["fgxfs", "mknod", img, "/dev/sd0", "b", "0x102"]) == 0
    assert fsck(img, verbose=False) == 0, "fsck must stay clean after mknod"

    vol = Volume(img)
    for path, fmt, dev, perm in (("/dev/null", IFCHR, 0, 0o666),
                                 ("/dev/console", IFCHR, 7, 0o600),
                                 ("/dev/sd0", IFBLK, 0x102, 0o666)):
        dp = vol.namei(path)
        assert dp.ifmt == fmt, (path, oct(dp.mode))
        assert dp.mode & 0o7777 == perm, (path, oct(dp.mode))
        assert dp.isdev() and dp.size == 0 and dp.nlink == 1, path
        assert list(vol.blocks_of(dp)) == [], f"{path} must own no blocks"
        # THE PLATTER FIRST.  `dp.addr[0] == dev` below is true for either
        # half-placement of a small number and is a decoded value besides, so
        # asserting it first would absorb the arm this pair exists to catch.
        raw = vol.bread(itod(dp.ino))
        off = itoo(dp.ino) * DINODE_SZ
        assert u16(raw, off + 12) == 0, f"{path}: i_dummy must be zero"
        assert u16(raw, off + 14) == dev, \
            f"{path}: i_rdev is not in the second half of di_addr[0]"
        assert dp.addr[0] == dev, (path, dp.addr[0])
        assert all(a == 0 for a in dp.addr[1:]), (path, dp.addr)
    # /dev/sd0's halves differ (0x0102), so a swap would be visible.  Say so
    # here rather than trusting the three above to be non-degenerate.
    sd0 = vol.namei("/dev/sd0")
    assert (sd0.addr[0] >> 16) != (sd0.addr[0] & 0xFFFF), \
        "the block-device arm's test value is degenerate"
    assert [nm for _, nm, _, _ in vol.readdir(vol.namei("/dev"))] == \
        [".", "..", "null", "console", "sd0"]
    vol.close()

    # -- MUTATION ARMS.  fsck must reject every one of these. ---------------
    def mutate(label, fn):
        m = os.path.join(tmp, "mut.fs")
        with open(img, "rb") as a, open(m, "wb") as b:
            b.write(a.read())
        v = Volume(m, writable=True)
        fn(v)
        v.sbsync()
        v.close()
        rc = fsck(m, verbose=False)
        assert rc != 0, f"MUTATION NOT CAUGHT: {label} -- fsck returned clean"

    def cross_link(v):
        # Point small.txt's first block at big.dat's first block.
        a, b_ = v.namei("/small.txt"), v.namei("/big.dat")
        a.addr[0] = b_.addr[0]
        v.iput(a)
    mutate("cross-linked block", cross_link)

    def lost_block(v):
        # Drop a block from a file without freeing it: now nothing owns it.
        a = v.namei("/big.dat")
        a.addr[1] = 0
        a.size = DEV_BSIZE * 9 + 17
        v.iput(a)
    mutate("block owned by nobody", lost_block)

    def bad_nlink(v):
        a = v.namei("/small.txt")
        a.nlink = 7
        v.iput(a)
    mutate("wrong link count", bad_nlink)

    def orphan(v):
        # Allocate an inode that no directory entry names.
        v.ialloc(IFREG | 0o644)
    mutate("unreferenced inode", orphan)

    def bad_tfree(v):
        v.sb.tfree += 1
    mutate("fs_tfree disagrees with the free list", bad_tfree)

    # -- AND ITS OPPOSITE NUMBER, which is the arm that keeps apple/fgx#271
    # -- fixed.  fs_tfree above MUST fail, because 2.11BSD's pass5 checks and
    # repairs it.  fs_tinode MUST NOT, because 2.11BSD's fsck never looks at it:
    # its inode half is ifreechk(), which validates the CACHED free-inode list
    # rather than counting the i-list, and fs_tinode appears in the whole tool
    # once, in an `if (debug)' printf.  The kernel treats it as a df statistic
    # -- ialloc decrements, ifree increments, statfs reports it as f_ffree, and
    # nothing reads it to decide anything.  A tool stricter than the
    # implementation it speaks for rejects real volumes, and this one did.
    def stale_tinode(v):
        v.sb.tinode += 1
    m = os.path.join(tmp, "mut.fs")
    with open(img, "rb") as a, open(m, "wb") as b:
        b.write(a.read())
    v = Volume(m, writable=True)
    stale_tinode(v)
    v.sbsync()
    v.close()
    assert fsck(m, verbose=False) == 0, \
        "fs_tinode disagreeing with the i-list was reported as a PROBLEM -- " \
        "2.11BSD's fsck neither checks nor repairs that field, so this tool " \
        "must not fail a volume for it (apple/fgx#271)"

    def free_and_owned(v):
        # Put an owned block back on the free list.
        a = v.namei("/small.txt")
        v.bfree(a.addr[0])
    mutate("block both free and owned", free_and_owned)

    def truncated_image(v):
        v.sb.fsize += 4096
    mutate("superblock larger than the image", truncated_image)

    def dev_with_blocks(v):
        # A device inode whose SECOND address slot is a block number.  This is
        # the arm the old `if isdev(): continue` could not fail: the block is
        # also on the free list, so a kernel that allocates it hands out a
        # block another inode claims -- and 2.11BSD's fsck answers by CLEARING
        # the node, which is a /dev that empties itself on the referee.
        a = v.namei("/dev/null")
        a.addr[1] = v.sb.isize + 1
        v.iput(a)
    mutate("device node claiming a block", dev_with_blocks)

    def dev_with_size(v):
        a = v.namei("/dev/console")
        a.size = DEV_BSIZE
        v.iput(a)
    mutate("device node with a nonzero size", dev_with_size)

    # -- byte-order regression: a volume must NOT read back under native LE -
    vol = Volume(img)
    raw = vol.bread(itod(ROOTINO))
    off = itoo(ROOTINO) * DINODE_SZ
    native = int.from_bytes(raw[off + 12:off + 16], "little")
    assert native != vol.iget(ROOTINO).addr[0], \
        "root's first block reads the same under PDP and native order -- the " \
        "test value is degenerate, so this arm proves nothing; pick a block " \
        "number whose halves differ"
    vol.close()

    # -- the foreign volume.  The only non-self-referential evidence here. ---
    nents = foreign_volume_test()

    # -- AND THE WHOLE OF ONE, fscked.  The three blocks above are read field by
    # field; this runs every phase against a REAL 2.11BSD root and requires it
    # clean.  It is the arm that would have caught apple/fgx#271 on the day the
    # fs_tinode rule was written: that volume has fs_tinode 1373 against 1397
    # free in its i-list, and 2.11BSD calls it fine.
    #
    # SAID OUT LOUD WHEN IT DOES NOT RUN.  The image lives under gitignored
    # examples/, so a fresh clone has no copy -- and a check that silently
    # skips is indistinguishable from one that passed, which is the failure
    # this suite has a rule about.  The summary line below reports which.
    foreign = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "examples", "pdp11", "2.11BSD_rq.dsk")
    if os.path.exists(foreign):
        assert fsck(foreign, verbose=False) == 0, \
            "a REAL 2.11BSD root was reported broken -- this tool is stricter " \
            "than the implementation it speaks for (apple/fgx#271)"
        foreign_note = "a REAL 2.11BSD root fscked CLEAN end to end"
    else:
        foreign_note = ("NO whole-volume fsck arm -- examples/pdp11/"
                        "2.11BSD_rq.dsk is absent, so that arm did NOT run")

    import shutil
    shutil.rmtree(tmp)
    print(f"fgxfs --self-test: OK (format constants, byte order, mkfs, "
          f"read/write incl. indirect blocks, directory growth, device "
          f"nodes asserted on the platter, "
          f"9 mutation arms all caught, fs_tinode correctly NOT among them, "
          f"and a REAL 2.11BSD volume read: "
          f"{nents} root entries agreeing with that machine's own df/ls; "
          f"{foreign_note})")
    return 0


if __name__ == "__main__":
    # sys.exit: main() RETURNS its status, and a check that cannot fail the
    # build is exactly the defect it exists to catch.
    sys.exit(main(sys.argv) or 0)
