#!/usr/bin/env python3
"""bsd211vol -- carve the root filesystem out of a real 2.11BSD disk image.

WHY THIS EXISTS.  The UFS campaign's phase-1 gate has five arms, and the fourth
is "an image WRITTEN BY 2.11BSD mounts and reads on FGX".  Everything else in
the campaign is checked against `fgxfs`, which is an independent implementation
but still one written here; this arm is the only one whose bytes were laid down
by the system FGX claims compatibility with.

The material has been in the tree the whole time and was never used:
`examples/pdp11/2.11BSD_rq.dsk`, a 1 GB disk from a real 2.11BSD machine.  Its
root filesystem starts at block 0 with NO partition offset -- measured, not
assumed: `fgxfs dump` reads its superblock directly, and `fgxfs ls /` lists 35
root entries with the root's link count at 15, which is the same machine and the
same state as the three blocks in `tools/testdata/211bsd/` lifted from it on
2026-08-09.  So the provenance chain from that machine to this volume is intact.

WHY CARVE RATHER THAN ATTACH THE WHOLE THING.  Two reasons, both measured:
run.py stages every spindle into the per-test scratch directory now, so
attaching the 1 GB image would copy a gigabyte per test; and the filesystem is
7,942 KB of it, so 99% of that copy is a partition FGX has no business reading.

THE LENGTH IS READ FROM THE SUPERBLOCK, NOT BAKED.  `fs_fsize` says how many
filesystem blocks the volume claims, and taking anything else produces a volume
whose superblock disagrees with its own size -- which is exactly the mutation
`fgxfs`'s self-test uses to prove fsck can fail ("superblock says N blocks,
image holds M").  Reading it means this tool carves a DIFFERENT 2.11BSD image
correctly too, and means a wrong answer is loud rather than subtle.

NOT A GENERAL TOOL, and deliberately not part of `fgxfs`: fgxfs is the
campaign's ORACLE and shares no source with the kernel on purpose, so it stays
a reader/writer/checker of filesystems rather than growing a partition editor.
"""

import os
import sys

DEV_BSIZE = 512
FS_BSIZE = 1024
SBLOCK = 1               # filesystem block holding the superblock


def _u32(b, off):
    """A 2.11BSD 32-bit field: HIGH WORD FIRST, little-endian within each word.

    Measured on the real machine 2026-08-09 and recorded at the top of
    tools/fgxfs.py: the long 0x01020304 stores as the bytes 02 01 04 03.  So
    fs_fsize's high half is at off+0 and its low half at off+2, and reading it
    with '<I' gives a number that is wrong by a half-swap -- which for 7,942
    would come out as 0x1F060000 and carve 8 TB.
    """
    hi = b[off] | (b[off + 1] << 8)
    lo = b[off + 2] | (b[off + 3] << 8)
    return (hi << 16) | lo


def fsize_of(path):
    """fs_isize and fs_fsize off the superblock, in filesystem blocks."""
    with open(path, "rb") as f:
        f.seek(SBLOCK * FS_BSIZE)
        sb = f.read(8)
    if len(sb) < 8:
        raise SystemExit(f"bsd211vol: {path} is too short to hold a superblock")
    isize = sb[0] | (sb[1] << 8)
    return isize, _u32(sb, 2)


def carve(src, dst):
    isize, fsize = fsize_of(src)
    # The same sanity the kernel's own ufs_sbvalid applies, said here because a
    # nonsense superblock would otherwise carve a nonsense volume in silence.
    if not 2 < isize < fsize:
        raise SystemExit(f"bsd211vol: {src} has fs_isize {isize} and fs_fsize "
                         f"{fsize}; that is not a 2.11BSD filesystem at block 0")
    want = fsize * FS_BSIZE
    have = os.path.getsize(src)
    if have < want:
        raise SystemExit(f"bsd211vol: {src} holds {have} bytes but its "
                         f"superblock claims {fsize} blocks ({want} bytes)")
    with open(src, "rb") as a, open(dst, "wb") as b:
        left = want
        while left:
            chunk = a.read(min(1 << 20, left))
            if not chunk:
                raise SystemExit(f"bsd211vol: {src} ended early")
            b.write(chunk)
            left -= len(chunk)
    print(f"bsd211vol {dst}: {fsize} blocks ({want} bytes), i-list {isize}")
    return 0


def self_test():
    """Two arms, and the first is the one that would have been wrong.

    The half-swap arm is not decoration: reading fs_fsize with '<I' is the
    obvious thing to write and gives 0x1F060000 for a volume of 7,942 blocks.
    The second arm is the refusal, because a tool that carves whatever it is
    pointed at will happily produce a volume from a ProDOS image.
    """
    import tempfile

    fails = []
    tmp = tempfile.mkdtemp(prefix="bsd211vol_")

    # 1. fs_fsize is half-swapped.  Bytes for isize=126, fsize=7942, which are
    #    the real volume's -- 7E 00 | 00 00 06 1F -- so this arm is pinned to
    #    an observation rather than to a value chosen to make it pass.
    img = os.path.join(tmp, "sb.img")
    with open(img, "wb") as f:
        f.write(b"\0" * FS_BSIZE)
        f.write(bytes([0x7E, 0x00, 0x00, 0x00, 0x06, 0x1F, 0x12, 0x00]))
    isize, fsize = fsize_of(img)
    if (isize, fsize) != (126, 7942):
        fails.append(f"arm 1: read isize/fsize as {isize}/{fsize}, "
                     f"not 126/7942 -- the half-swap is wrong")

    # 2. A volume shorter than its superblock claims is REFUSED, not carved.
    #    Same shape as the truncation mutation fgxfs's fsck is proved with.
    try:
        carve(img, os.path.join(tmp, "out.fs"))
        fails.append("arm 2: carved a volume from an image far too short")
    except SystemExit:
        pass

    import shutil
    shutil.rmtree(tmp)
    if fails:
        for f in fails:
            print(f"SELF-TEST FAIL: {f}")
        return 1
    print("bsd211vol --self-test: OK (fs_fsize read half-swapped as 2.11BSD "
          "stores it, and a too-short image is refused rather than carved)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        sys.exit(self_test())
    if len(sys.argv) != 3:
        print("usage: bsd211vol.py SRC.dsk OUT.fs | --self-test",
              file=sys.stderr)
        sys.exit(2)
    sys.exit(carve(sys.argv[1], sys.argv[2]))
