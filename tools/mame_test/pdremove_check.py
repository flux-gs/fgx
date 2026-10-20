#!/usr/bin/env python3
"""pdremove_check -- what the machine's removals left on a ProDOS volume.

tests/pdremove runs /testdata/pdremove against a fresh disk/pdscratch.po
mounted with `-o write'.  This reads the staged copy the machine wrote
(scratch/vols) against the generator's volume:

  1. `cadius CHECKVOLUME' must say nothing, after flagging a control: a block
     a removal forgot to free is "in use but not referenced", and a live block
     freed is "referenced but free".
  2. The removed entries are gone, the refused ones are byte-identical, and
     every directory's file_count, links and pointers hold (pdwrite_check's
     dirfail).
  3. `cadius EXTRACTVOLUME' gives back every surviving file byte for byte, and
     big as written.
  4. big's blocks all belonged to removed files -- the generator leaves no free
     block below 4096, so a first-fit allocator can only have found them if
     the removals freed them.
  5. Each index block of a removed file that nothing reused was written back
     FLIPPED -- every entry's low and high bytes swapped -- as ProDOS 8's
     destroy and GS/OS's FST leave a deleted index block.  At least one must
     be checkable, or the check is vacuous.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import os
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import pdwrite_check as pw  # noqa: E402

gen, w = pw.gen, pw.w
VOL = "pdscratch.po"
GONE = ("/HELLO", "/TREE", "/EXT", "/F01", "/F03", "/SUB/INNER",
        "/SUB/INNER/DEEP")


def fail(msg):
    print("pdremove: FAIL " + msg)
    sys.exit(1)


def blocks(img, st, key, index=None):
    """Every block a fork owns; index blocks also go into `index'."""
    if key == 0:
        return set()
    if st == 1:
        return {key}
    b = img[key * 512:(key + 1) * 512]
    kids = [x for x in (b[i] | b[256 + i] << 8 for i in range(256)) if x]
    if index is not None:
        index.add(key)
    out = {key}
    for k in kids:
        out |= blocks(img, 2, k, index) if st == 3 else {k}
    return out


def owned(img, e, index=None):
    """The blocks an entry owns, whatever its storage type."""
    st, key = e[0] >> 4, w(e, 0x11)
    if st == 5:
        x = img[key * 512:]
        return ({key} | blocks(img, x[0], w(x, 1), index) |
                blocks(img, x[256], w(x, 257), index))
    if st == 0xD:
        out, blk = set(), key
        while blk:
            out.add(blk)
            blk = w(img, blk * 512 + 2)
        return out
    return blocks(img, st, key, index)


def main():
    if len(sys.argv) != 2:
        print("usage: pdremove_check.py dump.json")
        return 2
    scratch = pathlib.Path(sys.argv[1]).parent
    vol = scratch / "vols" / VOL
    if not vol.exists():
        print("pdremove: no staged volume at %s" % vol)
        return 2
    img = vol.read_bytes()
    before = (pw.REPO / "disk" / VOL).read_bytes()

    # 1. cadius CHECKVOLUME, with its positive control.
    with tempfile.TemporaryDirectory() as tmp:
        bad = bytearray(img)
        bad[w(img, 2 * 512 + 4 + 0x23) * 512] |= 0x20
        ctl = pathlib.Path(tmp) / "ctl.po"
        ctl.write_bytes(bad)
        if not pw.checkvolume(ctl):
            print("pdremove: cadius CHECKVOLUME did not flag the control")
            return 2
    problems = pw.checkvolume(vol)
    if problems:
        fail("cadius CHECKVOLUME: " + "; ".join(problems[:4]))

    # 2. The entries.
    now = {p: (b, s, e) for p, b, s, e in pw.entries(img, 2)}
    was = {p: (b, s, e) for p, b, s, e in pw.entries(before, 2)}
    for path in GONE:
        if path in now:
            fail("%s is still there" % path)
    for path in ("/SAP", "/F02", "/SUB"):
        if path not in now:
            fail("%s is gone" % path)
    for path in ("/SAP", "/F02"):
        if now[path][2] != was[path][2]:
            fail("%s: a refused removal changed its entry" % path)
    bad = pw.dirfail(img, 2)
    if bad:
        fail(bad)

    # 3. Every surviving file, and big, through cadius.
    want = {n: d for n, d in gen.contents()
            if "/" + n not in GONE}
    want["big"] = pw.pattern(0, 20000, 21)
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["cadius", "EXTRACTVOLUME", str(vol), tmp + "/"],
                       check=True, capture_output=True)
        got = {}
        for root, _, files in os.walk(tmp):
            for f in files:
                if "#" in f:
                    got[f.split("#")[0].upper()] = pathlib.Path(root, f)
        for name, data in want.items():
            f = got.get(name.upper())
            if f is None:
                fail("cadius did not extract %s" % name)
            if f.read_bytes() != data:
                fail("%s: cadius read different bytes" % name)
        for name in ("EXT", "HELLO", "TREE", "DEEP"):
            if name in got:
                fail("cadius extracted the removed %s" % name)

    # 4. big took freed blocks.
    freed, index = set(), set()
    for path in GONE:
        freed |= owned(before, was[path][2], index)
    bigb = owned(img, now["/BIG"][2])
    if not bigb <= freed:
        fail("big holds blocks no removed file owned: %s" %
             sorted(bigb - freed)[:6])

    # 5. Removed index blocks nothing reused are flipped.
    live = set()
    for p, (b, s, e) in now.items():
        live |= owned(img, e)
    checked = 0
    for blk in sorted(index - live):
        o = before[blk * 512:(blk + 1) * 512]
        if img[blk * 512:(blk + 1) * 512] != o[256:] + o[:256]:
            fail("removed index block %d was not written back flipped" % blk)
        checked += 1
    if checked == 0:
        fail("no removed index block was left to check for a flip")
    print("pdremove: cadius clean, %d files as expected, big in %d freed "
          "blocks, %d index blocks flipped" % (len(want), len(bigb), checked))
    return 0


if __name__ == "__main__":
    sys.exit(main())
