#!/usr/bin/env python3
"""ufscorrupt -- build DELIBERATELY BROKEN 2.11BSD filesystems, for fsck to find.

WHY THIS EXISTS.  UFS 2.1 put 2.11BSD's fsck on the 65816 and it reported a
clean filesystem clean.  That is not yet evidence: five phases that find nothing
are indistinguishable from five phases that DO nothing, and the campaign's own
rule is that a test which cannot go red is not coverage.  So each image here
carries exactly one fault, and the on-target fsck has to name it, repair it, and
leave a volume that the OTHER implementation calls clean.

THE FAULTS ARE tools/fgxfs.py's OWN MUTATION ARMS, deliberately.  Its self-test
already proves the host fsck catches all five; using the same five asks whether
the ported one agrees, which is the same two-implementations question goal 2
rests on -- now pointed at the checker instead of the format.

ONE FAULT PER IMAGE, not one image with five.  fsck repairs as it goes, and a
later pass acting on an earlier pass's repair would make it impossible to say
which complaint came from which fault.  Separate volumes keep each case a
single claim.
"""
import os, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fgxfs
from fgxfs import Volume, mkfs, DEV_BSIZE, IFREG


def _base(path, size, tmp):
    """A small, clean filesystem with two files and a directory to break.

    big.dat is deliberately past the four direct blocks so an INDIRECT block is
    in play: the dup and lost-block cases below reach through one, and a fsck
    that never followed an indirect would pass them both by not looking."""
    mkfs(path, size)
    small = b"the quick brown fox\n"
    big = bytes((i * 7 + 3) & 0xFF for i in range(DEV_BSIZE * 9 + 17))
    for name, payload in (("small.txt", small), ("big.dat", big)):
        src = os.path.join(tmp, name)
        with open(src, "wb") as f:
            f.write(payload)
        if fgxfs.main(["fgxfs", "put", path, src, "/" + name]) != 0:
            raise SystemExit("ufscorrupt: could not write " + name)
    if fgxfs.main(["fgxfs", "mkdir", path, "/sub"]) != 0:
        raise SystemExit("ufscorrupt: could not mkdir /sub")
    src = os.path.join(tmp, "small.txt")
    if fgxfs.main(["fgxfs", "put", path, src, "/sub/nested"]) != 0:
        raise SystemExit("ufscorrupt: could not write /sub/nested")


def cross_link(v):
    """Two inodes claiming one block -- fsck phase 1: DUP."""
    a, b = v.namei("/small.txt"), v.namei("/big.dat")
    a.addr[0] = b.addr[0]
    v.iput(a)


def lost_block(v):
    """A block owned by nobody and not on the free list -- phase 5: MISSING."""
    a = v.namei("/big.dat")
    a.addr[1] = 0
    a.size = DEV_BSIZE * 9 + 17
    v.iput(a)


def bad_nlink(v):
    """A link count that disagrees with the directory tree -- phase 4."""
    a = v.namei("/small.txt")
    a.nlink = 7
    v.iput(a)


def orphan(v):
    """A REAL FILE whose directory entry is gone -- phase 4: UNREF, reconnected
    into lost+found.

    Not `v.ialloc()' alone, which was the first attempt and tested something
    else: a bare ialloc leaves an inode with size 0 and stale block pointers, so
    fsck caught it in PHASE 1 as "SIZE=0 FILE HAS ALLOCATED BLOCKS" and cleared
    it there, never reaching phase 4.  The interesting path is the one that
    reconnects a file that is real and merely unnamed, because that is the case
    lost+found exists for.  So /sub/nested keeps its inode and loses its
    directory entry, by zeroing the entry's d_ino -- which is exactly how
    2.11BSD deletes a name."""
    parent = v.namei("/sub")
    blk = parent.addr[0]
    data = bytearray(v.bread(blk))
    off = 0
    while off < len(data):
        reclen = data[off + 2] | (data[off + 3] << 8)
        namlen = data[off + 4] | (data[off + 5] << 8)
        name = bytes(data[off + 6:off + 6 + namlen])
        if name == b"nested":
            data[off] = 0                 # d_ino = 0: the name is gone,
            data[off + 1] = 0             # the inode is not
            break
        if reclen <= 0:
            raise SystemExit("ufscorrupt: bad directory record in /sub")
        off += reclen
    else:
        raise SystemExit("ufscorrupt: /sub/nested not found to orphan")
    v.bwrite(blk, bytes(data))


def bad_tfree(v):
    """A superblock free count that disagrees with the list -- phase 5."""
    v.sb.tfree += 1


CASES = [
    ("dup",    cross_link),
    ("lost",   lost_block),
    ("nlink",  bad_nlink),
    ("unref",  orphan),
    ("tfree",  bad_tfree),
]


def _assert_not_clean(path, case):
    """A broken image must not carry MNT_CLEAN.

    THE STRUCTURAL CHECK CANNOT SEE THIS.  fgxfs.fsck() walks the filesystem
    and answers non-zero for a planted fault whatever the superblock's flags
    say, so the "still CLEAN" control below stays green on an image that tells
    the TARGET's fsck there is nothing to look at -- and the target's fsck,
    which honours update #456, then skips it and the fixture asserts a
    complaint that can no longer be printed.  Measured: disk/ufsbadspin.fs
    shipped stamped clean and fsckraw's `UNREF FILE' arm went dark.
    """
    v = fgxfs.Volume(path)
    flags = v.sb.flags
    v.close()
    if flags & (fgxfs.MNT_CLEAN | fgxfs.MNT_WASCLEAN):
        raise SystemExit("ufscorrupt: %s carries MNT_CLEAN, so the target's "
                         "fsck would skip it and the case would be vacuous"
                         % case)


def build(outdir, size=256):
    os.makedirs(outdir, exist_ok=True)
    clean = os.path.join(outdir, "_clean.tmp")
    _base(clean, size, outdir)
    made = []
    for name, fn in CASES:
        dst = os.path.join(outdir, "ufsbad%s.img" % name)
        shutil.copyfile(clean, dst)
        v = Volume(dst, writable=True)
        fn(v)
        v.sbsync(clean=False)
        v.close()
        # POSITIVE CONTROL, and the reason this script is trustworthy at all:
        # the host fsck must call every image BROKEN before it is handed over.
        # An image that is accidentally still clean would make the on-target
        # test pass by finding nothing -- the exact failure being guarded
        # against.  fsck() returns non-zero on an unclean volume.
        rc = fgxfs.fsck(dst, verbose=False)
        if rc == 0:
            raise SystemExit("ufscorrupt: %s is still CLEAN -- the mutation "
                             "did not take, so the case would be vacuous" % name)
        _assert_not_clean(dst, name)
        made.append((name, dst))
    # And the clean base must be clean, or the faults above prove nothing.
    if fgxfs.fsck(clean, verbose=False) != 0:
        raise SystemExit("ufscorrupt: the BASE image is not clean")
    shutil.copyfile(clean, os.path.join(outdir, "ufsgood.img"))
    os.unlink(clean)
    for name, dst in made:
        print("ufscorrupt: %-6s -> %s (%d bytes)" % (name, dst, os.path.getsize(dst)))
    print("ufscorrupt: ufsgood.img is clean; all %d faults confirmed by the "
          "host fsck before hand-off" % len(made))


def build_one(case, out, size):
    """ONE fault, at any size, written to an exact path.

    For a fault that has to arrive as a SPINDLE rather than as a file on the
    root: fsck -n cannot check a regular file at all -- 2.11BSD's reply()
    returns 0 under nflag (usr/sbin/fsck/utilities.c:49), so setup() answers
    " no" to "file is not a block or character device" and never opens the
    filesystem.  The read-only claim is therefore only testable against a
    block device node, which means a whole volume on its own unit.

    THE POSITIVE CONTROL IS THE SAME ONE build() USES and it is the point:
    the host fsck must call the image BROKEN before it is handed over, or the
    on-target test would pass by finding nothing.
    """
    fn = dict(CASES).get(case)
    if fn is None:
        raise SystemExit("ufscorrupt: no such case %r (have: %s)"
                         % (case, ", ".join(n for n, _ in CASES)))
    tmp = os.path.dirname(os.path.abspath(out)) or "."
    os.makedirs(tmp, exist_ok=True)
    _base(out, size, tmp)
    if fgxfs.fsck(out, verbose=False) != 0:
        raise SystemExit("ufscorrupt: the BASE image is not clean, so the "
                         "fault below would prove nothing")
    v = Volume(out, writable=True)
    fn(v)
    v.sbsync(clean=False)
    v.close()
    if fgxfs.fsck(out, verbose=False) == 0:
        raise SystemExit("ufscorrupt: %s is still CLEAN -- the mutation did "
                         "not take, so the case would be vacuous" % case)
    _assert_not_clean(out, case)
    print("ufscorrupt: %s -> %s (%d bytes, %d blocks), confirmed broken by "
          "the host fsck" % (case, out, os.path.getsize(out), size))


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--one"]:
        if len(a) not in (3, 4):
            raise SystemExit("usage: ufscorrupt.py --one CASE OUT [SIZE_BLOCKS]")
        build_one(a[1], a[2], int(a[3]) if len(a) > 3 else 256)
    elif a:
        build(a[0], int(a[1]) if len(a) > 1 else 256)
    else:
        raise SystemExit("usage: ufscorrupt.py OUTDIR [SIZE_BLOCKS]\n"
                         "       ufscorrupt.py --one CASE OUT [SIZE_BLOCKS]")
