#!/usr/bin/env python3
"""pdwrite_check -- what the machine wrote to a ProDOS volume, read by others.

tests/pdwrite runs /testdata/pdwrite against disk/pdscratch.po mounted with
`-o write'.  This reads the staged copy the machine wrote (scratch/vols) and
holds it to three readers, two of which nobody here wrote:

  1. `cadius CHECKVOLUME' must say nothing: every block the bitmap calls used
     is referenced and every referenced block is marked used.  A positive
     control is run first -- the same volume with block 2, the volume
     directory's key block, marked free -- and must be reported, or the
     checker itself is not checking.
  2. `cadius EXTRACTVOLUME' must give back, byte for byte, the files the
     script's writes make of tools/mkpdscratch.py's contents, replayed here.
  3. This file's own reading of the entries: storage types the growth should
     have promoted to, blocks used equal to the blocks each file reaches, the
     backup bit on every written entry and not on an unwritten one, a new
     modification date on every written entry, and the ripple -- SUB's and
     INNER's entries re-dated because a file under them was written.

f09's write runs the volume out of space; how far it got is read from the
screen, and the file must hold exactly that many bytes.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(REPO / "tools"))
import mkpdscratch as gen  # noqa: E402

VOL = "pdscratch.po"
w = gen.w


def pattern(off, n, seed):
    return bytes(((pos * 31 + seed * 17) ^ (pos >> 7)) & 255
                 for pos in range(off, off + n))


def put(data, off, blob):
    data = bytearray(data)
    if len(data) < off:
        data += bytes(off - len(data))
    data[off:off + len(blob)] = blob
    return bytes(data)


def fail(msg):
    print("pdwrite: FAIL " + msg)
    sys.exit(1)


def entries(img, key, path=""):
    """(path, block, slot, entry bytes) for every live entry under key."""
    out = []
    blk = key
    while blk:
        b = img[blk * 512:(blk + 1) * 512]
        for s in range(13):
            e = b[4 + s * 39:4 + (s + 1) * 39]
            st = e[0] >> 4
            if st in (0, 0xE, 0xF):
                continue
            p = path + "/" + e[1:1 + (e[0] & 15)].decode()
            out.append((p, blk, s, e))
            if st == 0xD:
                out += entries(img, w(e, 0x11), p)
        blk = w(b, 2)
    return out


def reach(img, st, key):
    """Blocks a fork owns: its index blocks and its data blocks."""
    if key == 0:
        return 0
    if st == 1:
        return 1
    b = img[key * 512:(key + 1) * 512]
    idx = [b[i] | b[256 + i] << 8 for i in range(256)]
    if st == 2:
        return 1 + sum(1 for x in idx if x)
    return 1 + sum(reach(img, 2, x) for x in idx[:128] if x)


def dirfail(img, key, parent=None, path=""):
    """What is wrong with the directory at `key' and every one under it, or
    None: its chain's previous links, its header's file_count against its live
    entries, each entry's header_pointer, and for a subdirectory the header's
    way back (parent_pointer, parent_entry from 1, $27) and its entry's blocks
    used and EOF against the chain.  `parent' is (block, slot, entry)."""
    blks, blk, prev = [], key, 0
    while blk and len(blks) < 65536:
        if w(img, blk * 512) != prev:
            return "%s: block %d's previous link is %d, not %d" % (
                path or "/", blk, w(img, blk * 512), prev)
        blks.append(blk)
        prev, blk = blk, w(img, blk * 512 + 2)
    h = img[key * 512 + 4:key * 512 + 43]
    live = [(b, s, img[b * 512 + 4 + s * 39:b * 512 + 43 + s * 39])
            for b in blks for s in range(13) if not (b == key and s == 0)]
    live = [x for x in live if x[2][0] >> 4]
    if w(h, 0x21) != len(live):
        return "%s: file_count %d, %d entries" % (path or "/", w(h, 0x21),
                                                  len(live))
    if parent:
        pb, ps, pe = parent
        if (w(h, 0x23), h[0x25], h[0x26]) != (pb, ps + 1, 0x27):
            return "%s: parent %d/%d/$%02X, entry at %d/%d" % (
                path, w(h, 0x23), h[0x25], h[0x26], pb, ps + 1)
        eof = pe[0x15] | pe[0x16] << 8 | pe[0x17] << 16
        if (w(pe, 0x13), eof) != (len(blks), 512 * len(blks)):
            return "%s: blocks used %d, EOF %d, chain of %d" % (
                path, w(pe, 0x13), eof, len(blks))
    for b, s, e in live:
        name = path + "/" + e[1:1 + (e[0] & 15)].decode()
        if w(e, 0x25) != key:
            return "%s: header_pointer %d, not %d" % (name, w(e, 0x25), key)
        if e[0] >> 4 == 0xD:
            bad = dirfail(img, w(e, 0x11), (b, s, e), name)
            if bad:
                return bad
    return None


def caseword(name):
    """GS/OS Technical Note #8's word for `name': bit 15 valid, then a set bit
    per lowercase character from bit 14."""
    return 0x8000 | sum(0x4000 >> i for i, c in enumerate(name) if c.islower())


def checkvolume(path):
    r = subprocess.run(["cadius", "CHECKVOLUME", str(path)],
                       capture_output=True, text=True)
    return [l.strip() for l in r.stdout.splitlines() if "=>" in l]


def main():
    if len(sys.argv) != 2:
        print("usage: pdwrite_check.py dump.json")
        return 2
    scratch = pathlib.Path(sys.argv[1]).parent
    vol = scratch / "vols" / VOL
    screen = (scratch / "dump.txt").read_text(errors="replace")
    if not vol.exists():
        print("pdwrite: no staged volume at %s" % vol)
        return 2
    img = vol.read_bytes()
    before = (REPO / "disk" / VOL).read_bytes()

    # 1. cadius CHECKVOLUME, with its positive control.
    with tempfile.TemporaryDirectory() as tmp:
        bad = bytearray(img)
        bm = w(img, 2 * 512 + 4 + 0x23) * 512
        bad[bm] |= 0x20             # block 2, the volume directory, marked free
        ctl = pathlib.Path(tmp) / "ctl.po"
        ctl.write_bytes(bad)
        if not checkvolume(ctl):
            print("pdwrite: cadius CHECKVOLUME did not flag the control")
            return 2
    problems = checkvolume(vol)
    if problems:
        fail("cadius CHECKVOLUME: " + "; ".join(problems[:4]))

    # The run's own results.
    m = re.search(r"PDWR f09 (\d+) errno=28", screen)
    if not m:
        fail("no `PDWR f09 N errno=28' on the screen")
    f09len = int(m.group(1))
    m = re.search(r"PDCN v (\d+) errno=28", screen)
    if not m:
        fail("no `PDCN v N errno=28' on the screen")
    nv = int(m.group(1))

    # 2. The expected files, and cadius's extraction of them.
    orig = dict(gen.contents())
    want = {
        "Hello": put(orig["HELLO"], 27, pattern(27, 600, 1)),
        "SAP": put(put(orig["SAP"], 20000, pattern(20000, 120000, 2)),
                   2100, pattern(2100, 100, 3)),
        "TREE": put(orig["TREE"], 0, pattern(0, 700, 4)),
        "EXT": put(gen.EXT_DATA, 1500, pattern(1500, 1000, 5)),
        "F01": put(orig["F01"], 4, pattern(4, 5, 7)),
        "DEEP": put(b"deep file\n", 0, pattern(0, 5000, 8)),
        "F09": put(orig["F09"], 0, pattern(0, f09len, 12)),
        "F03": orig["F03"],
        "F04": orig["F04"],
        "NewFile.Txt": pattern(0, 700, 13),
    }
    want.update(("f%d" % i, b"") for i in range(20))
    want.update(("v%d" % i, b"") for i in range(nv))
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["cadius", "EXTRACTVOLUME", str(vol), tmp + "/"],
                       check=True, capture_output=True)
        got = {}
        for root, _, files in os.walk(tmp):
            for f in files:
                if "#" in f and not f.endswith("_ResourceFork.bin"):
                    got[f.split("#")[0]] = pathlib.Path(root, f).read_bytes()
        for name, data in want.items():
            if name not in got:
                fail("cadius did not extract %s" % name)
            if got[name] != data:
                fail("%s: cadius read %d bytes, expected %d (first "
                     "difference at %s)" % (name, len(got[name]), len(data),
                     next((i for i, (a, b) in enumerate(zip(got[name], data))
                           if a != b), min(len(got[name]), len(data)))))
        rsrc = [pathlib.Path(r, f).read_bytes() for r, _, fs in os.walk(tmp)
                for f in fs if f.startswith("EXT#") and
                f.endswith("_ResourceFork.bin")]
        if rsrc != [gen.EXT_RSRC]:
            fail("EXT's resource fork changed")

    # 3. The entries.
    now = {p: (b, s, e) for p, b, s, e in entries(img, 2)}
    was = {p: (b, s, e) for p, b, s, e in entries(before, 2)}
    storage = {"/HELLO": 2, "/SAP": 3, "/TREE": 3, "/EXT": 5, "/F01": 1,
               "/SUB/INNER/DEEP": 2, "/F09": 3}
    for path, st in storage.items():
        if path not in now:
            fail("%s is gone" % path)
        e = now[path][2]
        if e[0] >> 4 != st:
            fail("%s: storage type %d, expected %d" % (path, e[0] >> 4, st))
        if not e[0x1E] & 0x20:
            fail("%s: backup bit clear after a write" % path)
        if e[0x21:0x25] == was[path][2][0x21:0x25] or e[0x21:0x23] == b"\0\0":
            fail("%s: modification date not revised" % path)
        if st == 5:
            x = img[w(e, 0x11) * 512:]
            owned = 1 + reach(img, x[0], w(x, 1)) + reach(img, x[256], w(x, 257))
            if x[0] != 2 or (x[5] | x[6] << 8 | x[7] << 16) != 2500:
                fail("EXT: data fork mini-entry storage %d eof %d" %
                     (x[0], x[5] | x[6] << 8 | x[7] << 16))
            if w(x, 3) != reach(img, x[0], w(x, 1)):
                fail("EXT: data fork blocks used %d, reaches %d" %
                     (w(x, 3), reach(img, x[0], w(x, 1))))
        else:
            owned = reach(img, st, w(e, 0x11))
        if w(e, 0x13) != owned:
            fail("%s: blocks used %d, owns %d" % (path, w(e, 0x13), owned))
    for path in ("/F02", "/F03", "/F04"):
        if now[path][2] != was[path][2]:
            fail("%s: an unwritten entry changed" % path)
    for path in ("/SUB", "/SUB/INNER"):
        if now[path][2][0x21:0x25] == was[path][2][0x21:0x25]:
            fail("%s: not re-dated by the write beneath it" % path)

    # 4. What create wrote.  Every directory is whole, the volume directory is
    # full, and each new entry is as ProDOS 8's create writes it.
    bad = dirfail(img, 2)
    if bad:
        fail(bad)
    if w(img, 2 * 512 + 4 + 0x21) != 51:
        fail("the volume directory holds %d entries after ENOSPC, not 51"
             % w(img, 2 * 512 + 4 + 0x21))
    made = {"/NEWFILE.TXT": ("NewFile.Txt", 2, 0x00),
            "/SUB/NEWDIR": ("NewDir", 0xD, 0x0F)}
    made.update(("/SUB/NEWDIR/F%d" % i, ("f%d" % i, 1, 0)) for i in range(20))
    made.update(("/V%d" % i, ("v%d" % i, 1, 0)) for i in range(nv))
    for path, (name, st, ftype) in made.items():
        if path not in now:
            fail("%s was not created" % path)
        e = now[path][2]
        got = (e[0] >> 4, e[0x10], w(e, 0x1C), e[0x1E])
        if got != (st, ftype, caseword(name), 0xE3):
            fail("%s: storage %d type $%02X case $%04X access $%02X" %
                 ((path,) + got))
        if e[0x18:0x1A] == b"\0\0" or e[0x21:0x23] == b"\0\0":
            fail("%s: no creation or modification date" % path)
        if st == 1 and (w(e, 0x13), e[0x15:0x18]) != (1, b"\0\0\0"):
            fail("%s: a new seedling is not one block, EOF 0" % path)
    h = img[w(now["/SUB/NEWDIR"][2], 0x11) * 512 + 4:][:39]
    if (h[0] >> 4, h[0x10:0x18], w(h, 0x1C), h[0x1E:0x21]) != (
            0xE, bytes([0x75, 0, 0, 0xC3, 0x27, 0x0D, 0, 0]), 0,
            bytes([0xC3, 0x27, 0x0D])):
        fail("NEWDIR's header is not the one ProDOS 8's create writes")
    if w(now["/SUB/NEWDIR"][2], 0x13) != 2:
        fail("NEWDIR did not grow a block for its thirteenth file")
    print("pdwrite: cadius clean, %d files as replayed, f09 %d bytes to "
          "ENOSPC, %d creates to a full volume directory" % (len(want), f09len,
                                                            nv))
    return 0


if __name__ == "__main__":
    sys.exit(main())
