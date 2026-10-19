#!/usr/bin/env python3
"""pdrename_check -- what the machine's renames and truncations left.

tests/pdrename runs /testdata/pdrename against a fresh disk/pdscratch.po
mounted with `-o write'.  This reads the staged copy the machine wrote
(scratch/vols) against the generator's volume:

  1. `cadius CHECKVOLUME' must say nothing, after flagging a control: a block
     a truncation forgot is "in use but not referenced", and a block two files
     reach -- what a moved file's stale node would write through -- is
     "already used".
  2. Every directory is whole (pdwrite_check's dirfail) and holds no name
     twice, which a rename that did not remove the name it replaced leaves.
  3. Each renamed or moved entry is at its new name with its OLD key block,
     the new name's case word and the backup bit; the moved directory's
     header carries the new name (its way back is dirfail's).
  4. The truncated files' storage types, EOFs and blocks used, and every file
     byte-identical in cadius's extraction.

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


def fail(msg):
    print("pdrename: FAIL " + msg)
    sys.exit(1)


def eof(e):
    return e[0x15] | e[0x16] << 8 | e[0x17] << 16


def main():
    if len(sys.argv) != 2:
        print("usage: pdrename_check.py dump.json")
        return 2
    scratch = pathlib.Path(sys.argv[1]).parent
    vol = scratch / "vols" / VOL
    if not vol.exists():
        print("pdrename: no staged volume at %s" % vol)
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
            print("pdrename: cadius CHECKVOLUME did not flag the control")
            return 2
    problems = pw.checkvolume(vol)
    if problems:
        fail("cadius CHECKVOLUME: " + "; ".join(problems[:4]))

    # 2. Whole directories, no name twice.
    bad = pw.dirfail(img, 2)
    if bad:
        fail(bad)
    rows = pw.entries(img, 2)
    paths = [p for p, _, _, _ in rows]
    twice = sorted({p for p in paths if paths.count(p) > 1})
    if twice:
        fail("a name appears twice: %s" % ", ".join(twice))
    now = {p: e for p, _, _, e in rows}
    was = {p: e for p, _, _, e in pw.entries(before, 2)}

    # 3. Renamed and moved entries.
    for path in ("/HELLO", "/F01", "/F04", "/SUB/INNER", "/SUB/DEEPER"):
        if path in now:
            fail("%s is still there" % path)
    moves = {"/GREETING": ("/HELLO", "Greeting"), "/SUB/MOVED": ("/F01", "Moved"),
             "/TOP": ("/SUB/INNER", "Top"), "/F05": ("/F04", "f05")}
    for path, (old, name) in moves.items():
        e = now.get(path)
        if e is None:
            fail("%s was not made" % path)
        if w(e, 0x11) != w(was[old], 0x11):
            fail("%s: key block %d, %s's was %d" % (path, w(e, 0x11), old,
                                                    w(was[old], 0x11)))
        if w(e, 0x1C) != pw.caseword(name) or not e[0x1E] & 0x20:
            fail("%s: case word $%04X access $%02X" % (path, w(e, 0x1C),
                                                       e[0x1E]))
    h = img[w(now["/TOP"], 0x11) * 512 + 4:][:16]
    if h[0] != 0xE3 or h[1:4] != b"TOP":
        fail("TOP's header is not named TOP")
    if "/FRESH" not in now or w(now["/FRESH"], 0x11) == w(was["/F01"], 0x11):
        fail("FRESH does not have a key block of its own")

    # 4. Truncations.
    shapes = {"/TREE": (2, 100000), "/SAP": (1, 300), "/F06": (1, 70000),
              "/F07": (1, 4)}
    for path, (st, n) in shapes.items():
        e = now[path]
        if (e[0] >> 4, eof(e)) != (st, n):
            fail("%s: storage %d EOF %d, expected %d %d" % (path, e[0] >> 4,
                                                        eof(e), st, n))
        if w(e, 0x13) != pw.reach(img, st, w(e, 0x11)):
            fail("%s: blocks used %d, owns %d" % (path, w(e, 0x13),
                  pw.reach(img, st, w(e, 0x11))))
    x = img[w(now["/EXT"], 0x11) * 512:]
    if (x[0], x[5] | x[6] << 8 | x[7] << 16) != (1, 0):
        fail("EXT's data fork is storage %d EOF %d, not an empty seedling" %
             (x[0], x[5] | x[6] << 8 | x[7] << 16))

    orig = dict(gen.contents())
    want = {"Greeting": orig["HELLO"], "Moved": orig["F01"],
            "fresh": pw.pattern(0, 700, 31), "f05": orig["F04"],
            "TREE": orig["TREE"][:100000], "SAP": orig["SAP"][:300],
            "F06": orig["F06"] + bytes(70000 - len(orig["F06"])),
            "F07": b"new\n", "DEEP": b"deep file\n", "EXT": b""}
    for n in ("F02", "F03", "F08", "F09"):
        want[n] = orig[n]
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["cadius", "EXTRACTVOLUME", str(vol), tmp + "/"],
                       check=True, capture_output=True)
        got, rsrc = {}, None
        for root, _, files in os.walk(tmp):
            for f in files:
                if f.startswith("EXT#") and f.endswith("_ResourceFork.bin"):
                    rsrc = pathlib.Path(root, f).read_bytes()
                elif "#" in f:
                    got[f.split("#")[0].upper()] = pathlib.Path(root, f)
        for name, data in want.items():
            f = got.get(name.upper())
            if f is None:
                fail("cadius did not extract %s" % name)
            if f.read_bytes() != data:
                fail("%s: cadius read different bytes" % name)
        if rsrc != gen.EXT_RSRC:
            fail("EXT's resource fork changed")
    print("pdrename: cadius clean, %d files as expected, %d renames in place "
          "and moved" % (len(want), len(moves)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
