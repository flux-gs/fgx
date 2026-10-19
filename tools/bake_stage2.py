#!/usr/bin/env python3
"""bake_stage2.py -- patch stage 2's block list into stage 1's sector.

UFS campaign deliverable 2.2.  Stage 1 owns SECTOR 0 AND NOTHING ELSE --
2.11BSD's h/disklabel.h:53 puts the disklabel at LABELSECTOR 1 -- so it is 512
bytes and has no room for a name lookup.  It therefore reads stage 2 from a
baked list of device block numbers, written here into the descriptor stage 1
carries behind the magic FGXSTG2!.

STAGE 2 IS A REAL FILE, NOT A RESERVED RANGE.  Blocks owned by no inode and
absent from the free list are exactly what fsck salvages back into the free
list and then hands out again, so a reserved range would be reclaimed and
overwritten -- by our own on-target fsck, or by a real 2.11BSD system fscking
an FGX volume, which is campaign goal 2.  So the file is resolved THROUGH the
filesystem.

A LIST AND NOT AN EXTENT, AND THAT WAS A MEASUREMENT.  The campaign plan says
stage 2 is "a REAL FILE whose blocks mkfs guarantees contiguous".  It is not:
mkfs builds the free list with a rotational interleave -- 2.11BSD mkfs.c:214
defaults f_m = 3 when there is no disklabel to read a step from, and fgxfs uses
2 -- so blocks leave the list every f_m'th and a fresh file is systematically
non-consecutive.  On a volume fgxfs made, /boot got filesystem blocks 70, 72,
74.  Upstream reaches the same conclusion in its own boot block: rauboot.s
walks the inode's four direct addresses one at a time rather than a run.

So the bound here is not contiguity but LENGTH: at most S2MAX device blocks,
which is 4 KB, which is NDADDR -- 2.11BSD's entire direct-block count and
exactly what rauboot.s reads.  A stage 2 past that has outgrown what a 2.11BSD
boot block could reach either, and this fails the BUILD rather than warning:
an unbootable image is worth less than a red build.

Usage:
    bake_stage2.py <image.po> <FILENAME>         # ProDOS volume, root file
    bake_stage2.py --ufs <image.po> <PATH>       # 2.11BSD volume, full path
    bake_stage2.py --verify <src> ...            # ...and read the list back
    bake_stage2.py --self-test

--verify is the positive control on the whole chain rather than on this tool:
it re-reads the image at the block numbers it just wrote, in the order it
wrote them, and requires the bytes to be the file that was staged.  Following
the descriptor is exactly what stage 1 does, so a list that passes this is one
stage 1 can boot -- which is otherwise only observable as a blank screen.

The ProDOS reader here is deliberately small and read-only.  It goes away at
campaign 2.4, when disk_src staging moves to fgxfs entirely.
"""

import os
import sys

BLKSZ = 512
MAGIC = b"FGXSTG2!"

# Device blocks stage 1 will chase; loader.s carries the same S2MAX.  The
# bound is the room the list takes in sector 0, not a filesystem limit: the
# extent comes off the whole inode, indirect blocks included.
S2MAX = 16

# ProDOS storage types (high nibble of the entry's first byte).
ST_SEEDLING = 1
ST_SAPLING = 2
ST_TREE = 3

VOLDIR_BLOCK = 2        # ProDOS volume directory always starts at block 2
ENTRY_LEN = 39
FIRST_ENTRY = 4         # past the block's prev/next pointers


class BakeError(Exception):
    pass


def _blk(img, n):
    off = n * BLKSZ
    b = img[off:off + BLKSZ]
    if len(b) != BLKSZ:
        raise BakeError("block %d is past the end of the image" % n)
    return b


def _index_entries(img, n):
    """A ProDOS index block: 256 lo bytes then 256 hi bytes."""
    b = _blk(img, n)
    return [b[i] | (b[256 + i] << 8) for i in range(256)]


def prodos_data_blocks(img, name):
    """Device block numbers holding NAME's data, in file order.

    Sparse holes (block 0) are dropped, which is the same thing the file's
    reader would see: stage 2 is a linked binary and has none.
    """
    want = name.upper().encode("ascii")
    blk = VOLDIR_BLOCK
    while blk:
        d = _blk(img, blk)
        nxt = d[2] | (d[3] << 8)
        off = FIRST_ENTRY
        while off + ENTRY_LEN <= BLKSZ:
            e = d[off:off + ENTRY_LEN]
            stype, nlen = e[0] >> 4, e[0] & 0x0F
            if stype and nlen and e[1:1 + nlen].upper() == want:
                return _blocks_of(img, stype, e[0x11] | (e[0x12] << 8),
                                  e[0x15] | (e[0x16] << 8) | (e[0x17] << 16),
                                  name)
            off += ENTRY_LEN
        blk = nxt
    raise BakeError("/%s not found in the volume directory" % name)


def _blocks_of(img, stype, key, eof, name):
    need = (eof + BLKSZ - 1) // BLKSZ
    if stype == ST_SEEDLING:
        blocks = [key]
    elif stype == ST_SAPLING:
        blocks = _index_entries(img, key)
    elif stype == ST_TREE:
        blocks = []
        for sub in _index_entries(img, key):
            if sub:
                blocks.extend(_index_entries(img, sub))
            else:
                blocks.extend([0] * 256)
    else:
        raise BakeError("/%s has storage type %d, which is not a file"
                        % (name, stype))
    blocks = blocks[:need]
    if len(blocks) != need:
        raise BakeError("/%s: EOF %d needs %d blocks, the index names only %d"
                        % (name, eof, need, len(blocks)))
    return blocks


def check_length(blocks, name):
    """Refuse a list stage 1 cannot hold.  Contiguity is NOT required."""
    if not blocks:
        raise BakeError("/%s is empty" % name)
    if len(blocks) > S2MAX:
        raise BakeError(
            "/%s needs %d device blocks; stage 1 holds %d (%d KB, which is "
            "NDADDR -- 2.11BSD's whole direct-block count, and all upstream's "
            "own boot block reads).  Shrink stage 2 or teach stage 1 an "
            "indirect block." % (name, len(blocks), S2MAX, S2MAX // 2))
    for b in blocks:
        if b > 0xFFFFFF:
            raise BakeError("/%s touches block %d, past the 24-bit baked field"
                            % (name, b))
    return blocks


def find_descriptor(sector0):
    """Offset of the four patchable bytes, refusing an ambiguous sector."""
    n = sector0.count(MAGIC)
    if n == 0:
        raise BakeError("stage 1 carries no %s descriptor -- sector 0 is not "
                        "an FGX loader, or the loader was not rebuilt"
                        % MAGIC.decode())
    if n != 1:
        raise BakeError("%s appears %d times in sector 0; the descriptor must "
                        "be unique" % (MAGIC.decode(), n))
    return sector0.index(MAGIC) + len(MAGIC)


def ufs_data_blocks(path, name):
    """Device block numbers holding NAME's data, from the 2.11BSD inode.

    fgxfs is the independent implementation the campaign already trusts as its
    oracle; the extent comes from it rather than from a second reader written
    here.  Its blocks_of() counts FILESYSTEM blocks, and fsbtodb(b) == b << 1.
    """
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import fgxfs
    vol = fgxfs.Volume(path)
    try:
        dp = vol.namei(name)
        if dp is None:
            raise BakeError("%s not found on the volume" % name)
        if not dp.isreg():
            raise BakeError("%s is not a regular file" % name)
        # A zero is a HOLE and is baked as one: stage 1 zero-fills it.  Both
        # filesystems omit an all-zero block, and stage 2's own tail is one.
        return [x for b in vol.blocks_of(dp)
                for x in ((b * 2, b * 2 + 1) if b else (0, 0))]
    finally:
        vol.close()


def verify(path, name, blocks, src):
    """Read the baked list back and require the staged bytes.

    Deliberately NOT through the filesystem reader that produced the list --
    that would be the tool agreeing with itself.  This walks the raw image the
    way stage 1 will, and compares against the file on the build host.
    """
    want = open(src, "rb").read()
    with open(path, "rb") as f:
        got = b""
        for b in blocks:
            if not b:
                got += bytes(BLKSZ)      # a hole: what stage 1 will write
                continue
            f.seek(b * BLKSZ)
            got += f.read(BLKSZ)
    if len(got) < len(want) or got[:len(want)] != want:
        n = next((i for i in range(min(len(got), len(want)))
                  if got[i] != want[i]), min(len(got), len(want)))
        raise BakeError(
            "the baked list does not read back %s: %d bytes of blocks %s "
            "against %d bytes staged, first difference at offset %d.  Stage 1 "
            "would load these bytes and jump into them."
            % (name, len(got), blocks, len(want), n))


def bake(path, name, ufs=False):
    blocks = (ufs_data_blocks(path, name) if ufs
              else prodos_data_blocks(open(path, "rb").read(), name))
    blocks = check_length(blocks, name)
    with open(path, "r+b") as f:
        at = find_descriptor(f.read(BLKSZ))
        f.seek(at)
        f.write(bytes([len(blocks)]))
        for b in blocks:
            f.write(bytes((b & 0xFF, (b >> 8) & 0xFF, (b >> 16) & 0xFF)))
    return blocks


#------------------------------------------------------------------------------
# Self-test.  THE POSITIVE CONTROL IS THE POINT: a checker that cannot call a
# bad image bad reads exactly like one that passes everything.  Each arm below
# is an input this must REJECT, plus the one it must accept.
#------------------------------------------------------------------------------

def _mkvol(nblocks=64):
    return bytearray(BLKSZ * nblocks)


def _put_entry(img, idx, name, stype, key, eof):
    off = VOLDIR_BLOCK * BLKSZ + FIRST_ENTRY + idx * ENTRY_LEN
    img[off] = (stype << 4) | len(name)
    img[off + 1:off + 1 + len(name)] = name.encode("ascii")
    img[off + 0x11] = key & 0xFF
    img[off + 0x12] = (key >> 8) & 0xFF
    img[off + 0x15] = eof & 0xFF
    img[off + 0x16] = (eof >> 8) & 0xFF
    img[off + 0x17] = (eof >> 16) & 0xFF


def _put_index(img, blk, blocks):
    off = blk * BLKSZ
    for i, b in enumerate(blocks):
        img[off + i] = b & 0xFF
        img[off + 256 + i] = (b >> 8) & 0xFF


def _sector0_with_magic(img, dup=False):
    img[0x100:0x100 + len(MAGIC) + 4] = MAGIC + b"\0\0\0\0"
    if dup:
        img[0x180:0x180 + len(MAGIC)] = MAGIC


def _bake_tmp(img, name="BOOT"):
    """Write IMG to a temp file, bake it, and hand back (path, result)."""
    import tempfile
    fd, p = tempfile.mkstemp()
    os.write(fd, bytes(img))
    os.close(fd)
    return p, bake(p, name)


def _expect(label, fn, want_ok):
    try:
        fn()
        ok = True
        why = ""
    except BakeError as e:
        ok = False
        why = str(e)
    if ok != want_ok:
        print("  FAIL  %s: expected %s, got %s%s"
              % (label, "accept" if want_ok else "reject",
                 "accept" if ok else "reject",
                 (" -- " + why) if why else ""))
        return False
    print("  ok    %s%s" % (label, ("  (%s)" % why.split(":")[0]) if why else ""))
    return True


def self_test():
    passed = True

    def volume(blocks, dup_magic=False, eof=2690, stype=ST_SAPLING):
        img = _mkvol()
        _sector0_with_magic(img, dup_magic)
        _put_index(img, 20, blocks)
        _put_entry(img, 0, "BOOT", stype, 20, eof)
        return img

    def run(img, name="BOOT"):
        p, res = _bake_tmp(img, name)
        os.unlink(p)
        return res

    # 1. The case that must WORK, and the values it must produce.  A checker
    #    whose accept arm is never exercised on real bytes is not a checker.
    #    THE BLOCKS ARE DELIBERATELY NOT CONSECUTIVE -- that is what a 2.11BSD
    #    free list hands out, and the first cut of this tool refused it.
    p, blocks = _bake_tmp(volume([30, 32, 34, 36, 38, 40]))
    try:
        img = open(p, "rb").read()
        at = find_descriptor(img[:BLKSZ])
        got = img[at:at + 1 + 3 * len(blocks)]
    finally:
        os.unlink(p)
    want = bytes([6]) + b"".join(bytes((b, 0, 0)) for b in (30, 32, 34, 36, 38, 40))
    if blocks == [30, 32, 34, 36, 38, 40] and got == want:
        print("  ok    an interleaved (non-consecutive) file bakes to its "
              "6-block list, and the bytes landed")
    else:
        print("  FAIL  interleaved file: got %r / %r" % (blocks, got))
        passed = False

    # 2. Too long for the descriptor -- the bound that replaced contiguity.
    passed &= _expect("over-length file refused",
                      lambda: run(volume(list(range(30, 30 + 2 * (S2MAX + 2))),
                                         eof=BLKSZ * (S2MAX + 1))), False)

    # 3. A HOLE is baked as a zero, not refused -- stage 1 fills it, the way
    #    stage 2's own loop has since apple/fgx#225.  Skipping it instead
    #    would leave whatever was in the destination.
    passed &= _expect("hole kept as a zero entry",
                      lambda: run(volume([30, 32, 0, 36, 38, 40])), True)

    # 4. No descriptor in sector 0 -- an image whose loader predates 2.2.
    def no_magic():
        img = _mkvol()
        _put_index(img, 20, [30, 31, 32, 33, 34, 35])
        _put_entry(img, 0, "BOOT", ST_SAPLING, 20, 2690)
        return run(img)
    passed &= _expect("missing descriptor refused", no_magic, False)

    # 5. Two descriptors -- the baker must not guess which one stage 1 reads.
    passed &= _expect("duplicate descriptor refused",
                      lambda: run(volume([30, 31, 32, 33, 34, 35],
                                         dup_magic=True)), False)

    # 6. A name that is not there.
    passed &= _expect("missing file refused",
                      lambda: run(volume([30, 31, 32, 33, 34, 35]), "NOSUCH"),
                      False)

    # 7. A seedling (single block) is a legitimate stage 2 and must pass.
    def seed():
        img = _mkvol()
        _sector0_with_magic(img)
        _put_entry(img, 0, "BOOT", ST_SEEDLING, 41, 400)
        return run(img)
    passed &= _expect("seedling accepted", seed, True)

    # 8. --verify must go RED when the list is wrong.  It is a positive control
    #    on stage 1's path, so it needs one of its own.
    passed &= _verify_arm()

    # 9. THE UFS ARM, ON A VOLUME fgxfs ACTUALLY MADE.  The ProDOS arms above
    #    are synthetic bytes; this one is the format the campaign is moving to,
    #    and it is the arm that would have caught the contiguity mistake.
    passed &= _ufs_arm()

    print("bake_stage2 self-test: %s" % ("PASS" if passed else "FAIL"))
    return 0 if passed else 1


def _verify_arm():
    import tempfile
    img = _mkvol()
    _sector0_with_magic(img)
    _put_index(img, 20, [30, 32, 34])
    _put_entry(img, 0, "BOOT", ST_SAPLING, 20, 1200)
    payload = bytes(range(200)) * 6                      # 1200 bytes
    for i, b in enumerate((30, 32, 34)):
        img[b * BLKSZ:(b + 1) * BLKSZ] = (
            payload[i * BLKSZ:(i + 1) * BLKSZ].ljust(BLKSZ, b"\0"))
    p, blocks = _bake_tmp(img)
    fd, srcp = tempfile.mkstemp()
    os.write(fd, payload)
    os.close(fd)
    try:
        verify(p, "BOOT", blocks, srcp)
    except BakeError as e:
        print("  FAIL  verify arm: rejected a correct list -- %s" % e)
        os.unlink(p); os.unlink(srcp)
        return False
    try:
        verify(p, "BOOT", [blocks[0], blocks[2], blocks[1]], srcp)
    except BakeError:
        print("  ok    verify reads the list back, and refuses it reordered")
        return True
    finally:
        os.unlink(p); os.unlink(srcp)
    print("  FAIL  verify arm: accepted a REORDERED list, so it proves nothing")
    return False


def _ufs_arm():
    import tempfile
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    try:
        import fgxfs
    except ImportError:
        print("  SKIP  ufs arm: fgxfs not importable")
        return False
    d = tempfile.mkdtemp()
    img = os.path.join(d, "ufsboot.po")
    payload = os.path.join(d, "boot")
    try:
        with open(payload, "wb") as f:
            f.write(bytes(range(256)) * 10)          # 2560 bytes, 3 fs blocks
        fgxfs.mkfs(img, 4096)
        # Through the CLI rather than the writer's internals: this arm is about
        # the extent a real volume hands out, not about fgxfs's API.
        import subprocess
        me = os.path.abspath(__file__)
        fs = os.path.join(os.path.dirname(me), "fgxfs.py")
        subprocess.run([sys.executable, fs, "put", img, payload, "/boot"],
                       check=True, capture_output=True)
        with open(img, "r+b") as f:
            sec = bytearray(f.read(BLKSZ))
            sec[0x100:0x100 + len(MAGIC)] = MAGIC
            f.seek(0)
            f.write(sec)
        blocks = bake(img, "/boot", ufs=True)
        vol = fgxfs.Volume(img)
        try:
            want = []
            for b in vol.blocks_of(vol.namei("/boot")):
                want.extend((b * 2, b * 2 + 1))
        finally:
            vol.close()
        if blocks != want:
            print("  FAIL  ufs arm: baked %r, inode says %r" % (blocks, want))
            return False
        if want == list(range(want[0], want[0] + len(want))):
            print("  FAIL  ufs arm: the volume handed out a CONSECUTIVE run, "
                  "so this arm cannot show that a list is needed")
            return False
        print("  ok    ufs arm: /boot bakes to %r off a real fgxfs volume "
              "(non-consecutive, which is the point)" % (blocks,))
        return True
    finally:
        import shutil
        shutil.rmtree(d, ignore_errors=True)


def main(argv):
    argv = argv[1:]
    if argv == ["--self-test"]:
        return self_test()
    ufs = False
    src = None
    while argv and argv[0].startswith("--"):
        if argv[0] == "--ufs":
            ufs, argv = True, argv[1:]
        elif argv[0] == "--verify" and len(argv) > 1:
            src, argv = argv[1], argv[2:]
        else:
            sys.stderr.write("bake_stage2: unknown option %s\n" % argv[0])
            return 2
    if len(argv) != 2:
        sys.stderr.write(__doc__)
        return 2
    try:
        blocks = bake(argv[0], argv[1], ufs=ufs)
        if src is not None:
            verify(argv[0], argv[1], blocks, src)
    except BakeError as e:
        sys.stderr.write("bake_stage2: %s\n" % e)
        return 1
    print("    baked %s -> %d block(s): %s%s"
          % (argv[1], len(blocks), " ".join(str(b) for b in blocks),
             "  (read back and verified)" if src is not None else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
