#!/usr/bin/env python3
"""check_probe_offsets.py - a test probe must name a direct-page cell that
still EXISTS, at the offset it names.

THE FAILURE THIS PREVENTS.  A manifest addresses kernel state as
`CFG_DP_KKERN+B0`.  The constant tracks the block wherever the block moves --
that much was already solved.  What it cannot track is the CELL moving inside
the block, or out of it entirely.

apple/fgx#102: apple/fgx!159 moved `_conTopRow` out of the direct page, and
vccursor.json went on reading offset `$C2`.  Nothing failed.  The offset still
resolved, the read returned two unrelated bytes, and those bytes happened to be
0 -- which is exactly what the pre-apple/fgx#94 code assumed, so the check kept
passing while the fix it existed to hold in place was inert.  The whole suite
was green with it broken.

That is the shape this catches: an offset that outlives its cell.  Renames are
already loud (run.py's _addr refuses an unknown constant); it is the SURVIVING
offset with a changed meaning that is silent.

WHAT IS CHECKED.  Every `CFG_DP_KKERN+<hex>` in tools/mame_test must be the
FIRST byte of a cell declared in include/dpmap.s, which is the authoritative
kernel direct-page layout.  Landing mid-cell is an error too: a probe reading
the high byte of a word is almost always a probe whose cell moved under it by
one, and saying "that is inside _foo, not the start of it" is more useful than
letting it read a plausible number.

NOT CHECKED, DELIBERATELY: a task's USER direct page (the first page of its
stack reservation, TCB_DirectPage).  Its layout is fcc's register file,
generated in fcc_dp.s rather than declared here, and no live probe currently
names one.  If one appears, teach this checker that map rather than exempting
it -- an exemption is how the class comes back.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DPMAP = os.path.join(ROOT, "include", "dpmap.s")
PROBE_DIR = os.path.join(ROOT, "tools", "mame_test")

# `NAME DS n` advances the cursor; `NAME EQU expr` is an alias at the cursor or
# at another symbol and never advances it.  A bare `DS n` (no label) is padding
# and advances without naming anything -- which is precisely what $C0-$CF
# became when the console scalars left, and precisely what a stale probe must
# not be allowed to point at.
# THREE OPERAND FORMS, and missing one silently shifts every later cell.  The
# first cut matched only decimal, so `DS $0D` did not advance the cursor and
# every offset past $03 came out 13 bytes low -- which made the checker flag all
# 28 live probes as "one byte inside the previous cell".  A checker that is
# wrong about everything gets switched off, so the parser is cross-checked
# against dpmap.s's own `; $XX` comments below.
#
#   DS 2          advance 2
#   DS $0D        advance 13
#   DS $50-{*}    PAD TO $50 (set the cursor, do not advance by it)
#   DS $FF-{*}+1  pad to $FF inclusive
DS_RE = re.compile(r"^(\w*)\s+DS\s+(\S+)\s*(?:;.*)?$")
PAD_RE = re.compile(r"^\$?([0-9A-Fa-f]+)-\{\*\}(?:\+(\d+))?$")
DUM_RE = re.compile(r"^\s*DUM\s+\$?([0-9A-Fa-f]+)")
PROBE_RE = re.compile(r"CFG_DP_KKERN\s*\+\s*\$?([0-9A-Fa-f]+)")


def dp_cells(path=DPMAP):
    """[(offset, length, name)] for every NAMED cell, in declaration order."""
    cells, off, started = [], 0, False
    with open(path, errors="replace") as f:
        for line in f:
            code = line.split(";")[0].rstrip()
            m = DUM_RE.match(code)
            if m:
                off, started = int(m.group(1), 16), True
                continue
            if not started:
                continue
            m = DS_RE.match(code)
            if m:
                name, operand = m.group(1), m.group(2)
                pad = PAD_RE.match(operand)
                if pad:
                    off = int(pad.group(1), 16) + int(pad.group(2) or 0)
                    continue
                try:
                    n = (int(operand[1:], 16) if operand.startswith("$")
                         else int(operand))
                except ValueError:
                    continue
                if name:
                    cells.append((off, n, name))
                off += n
    return cells


# THE FILE'S OWN STATED GROUND TRUTH, and the reason it is not the per-line
# comments.  include/dpmap.s says outright:
#
#   "the per-line '$xx' address comments in this block run +4 vs the actual
#    location counter (the $00-$1F transients region overflows to $24).  The
#    build listing is ground truth: dev_table_ptr=$2C .. _sigHndPtr=$40 ..
#    _bm_ptr=$4C.  Trust the listing, not these comments."
#
# So the inline comments are a KNOWN-STALE oracle, and a parser checked against
# them would be "corrected" into agreeing with them -- i.e. broken to match the
# documentation rather than the layout.  These three anchors are what the file
# asserts about itself, one before the +4 region, one inside it and one after,
# so a cursor that drifts anywhere across that span fails at least one.
ANCHORS = {"dev_table_ptr": 0x2C, "_sigHndPtr": 0x40, "_bm_ptr": 0x4C}


def check(cells, probes):
    """probes = [(where, offset)] -> list of complaints."""
    starts = {o: (n, nm) for o, n, nm in cells}
    inside = {}
    for o, n, nm in cells:
        for k in range(o, o + n):
            inside[k] = (o, nm)
    bad = []
    for where, off in sorted(set(probes)):
        if off in starts:
            continue
        if off in inside:
            base, nm = inside[off]
            bad.append(f"{where}: CFG_DP_KKERN+${off:02X} is INSIDE {nm} "
                       f"(${base:02X}), not its first byte -- if the cell moved "
                       f"under this probe by a byte, the read still succeeds "
                       f"and returns a plausible number")
        else:
            bad.append(f"{where}: CFG_DP_KKERN+${off:02X} names no declared "
                       f"cell in include/dpmap.s -- it is padding or free "
                       f"space, so this probe reads whatever happens to be "
                       f"there.  A cell that moved out of the direct page "
                       f"leaves exactly this behind (apple/fgx#102)")
    return bad


def collect(root=PROBE_DIR):
    probes = []
    for dirpath, _dirs, files in os.walk(root):
        for f in files:
            if not f.endswith((".json", ".py")):
                continue
            p = os.path.join(dirpath, f)
            with open(p, errors="replace") as fh:
                for n, line in enumerate(fh, 1):
                    if line.lstrip().startswith(("#", "//")):
                        continue
                    for m in PROBE_RE.finditer(line):
                        probes.append((f"{os.path.relpath(p, ROOT)}:{n}",
                                       int(m.group(1), 16)))
    return probes


def selftest():
    cells = [(0x00, 3, "_fsPathPtr"), (0xA4, 3, "_schedTblPtr"),
             (0xB0, 3, "_kLogBufPtr")]
    # $C0 is padding here, standing in for the run of free bytes the console
    # scalars left behind -- the apple/fgx#102 shape.
    cases = [
        ("a declared cell's first byte", [("m", 0xB0)], 0),
        ("free space / padding", [("m", 0xC0)], 1),
        ("inside a cell, not its start", [("m", 0xB1)], 1),
        ("several, one bad", [("m", 0xA4), ("m", 0xC0)], 1),
    ]
    rc = 0
    for name, probes, want in cases:
        got = len(check(cells, probes))
        if got != want:
            print(f"SELFTEST FAIL: {name}: {got} complaint(s), wanted {want}",
                  file=sys.stderr)
            rc = 1
    # The parser must find real cells in the real file, or every check above is
    # vacuous -- a map that parsed to nothing would accept every probe.
    # THE PARSER IS PINNED TO THE ANCHORS THE FILE ASSERTS ABOUT ITSELF.
    # Without this the whole checker rests on an unverified cursor, and a
    # cursor that is wrong produces a checker that is confidently wrong about
    # every probe -- which is worse than none, because it gets switched off.
    real = dp_cells()
    computed = {nm: o for o, _n, nm in real}
    for nm, want in sorted(ANCHORS.items()):
        got = computed.get(nm)
        if got != want:
            print(f"SELFTEST FAIL: {nm}: dpmap states ${want:02X}, parser "
                  f"computed {('$%02X' % got) if got is not None else 'nothing'}"
                  f" -- the DS cursor is wrong (check the DS operand forms: "
                  f"decimal, $hex, and the `X-{{*}}` pad-to-offset)",
                  file=sys.stderr)
            rc = 1
    if len(real) < 40:
        print(f"SELFTEST FAIL: parsed only {len(real)} cells from dpmap.s "
              f"-- the parser is broken, and a parser that finds nothing "
              f"accepts everything", file=sys.stderr)
        rc = 1
    if rc == 0:
        print(f"check_probe_offsets selftest: OK (red on padding and on "
              f"mid-cell; {len(real)} cells parsed, cursor pinned to "
              f"dpmap's {len(ANCHORS)} stated anchors)")
    return rc


def main():
    if "--self-test" in sys.argv or "--selftest" in sys.argv:
        return selftest()
    cells = dp_cells()
    if len(cells) < 40:
        print(f"check_probe_offsets: only {len(cells)} cells parsed from "
              f"include/dpmap.s -- refusing to check against a map that did "
              f"not parse", file=sys.stderr)
        return 1
    probes = collect()
    bad = check(cells, probes)
    for b in bad:
        print("check_probe_offsets: " + b, file=sys.stderr)
    if bad:
        print("A probe offset outlived its cell.  Repoint it at the cell it "
              "means, or -- if the state left the direct page -- at wherever "
              "it went (a farbank region, a kernel-bank symbol).",
              file=sys.stderr)
        return 1
    print(f"    probe offsets OK: {len(set(probes))} distinct kernel-DP "
          f"probe(s), all naming declared cells")
    return 0


if __name__ == "__main__":
    sys.exit(main())
