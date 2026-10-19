#!/usr/bin/env python3
"""Census of the kernel direct page: who uses each cell, and HOW.

Phase 1 of the bank-0 / kernel-scratch assessment
(docs/history/plans/2026-08-13-bank0-and-kernel-scratch-assessment.md).

The point of this tool is the ADDRESSING-MODE column, not the use count.

The 65816 has stack-relative (`sr,S`) and stack-relative indirect indexed
(`(sr,S),Y`) addressing, but NO stack-relative indirect LONG mode.  So a cell
that is DEREFERENCED as `[cell]` or `[cell],Y` -- a 24-bit far pointer -- has no
automatic-on-the-kernel-stack equivalent AT ANY STACK SIZE.  Those cells are
DP-IRREDUCIBLE: no amount of recovered bank 0 changes their answer, and any
migration plan that routes them to the stack is proposing something the
hardware does not have.

A cell only ever read/written directly (`LDA cell` / `STA cell`) is
DP-REDUCIBLE in principle: it could live in an absolute kernel-bank static, at
+1 byte per site, or as a stack automatic.

Emits a table to stdout, and `--json` for downstream phases.
"""

import argparse
import collections
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
DPMAP = REPO / "include" / "dpmap.s"

# Source trees the kernel and its modules are built from.
SEARCH_DIRS = ["src", "include"]
SRC_SUFFIXES = {".s", ".c", ".h"}

# A cell declaration in the DUM block: `_name  DS  n` or `_name  EQU  expr`.
DECL_RE = re.compile(r"^([_A-Za-z][A-Za-z0-9_]*)\s+(DS|EQU)\s+(\S+)")

# Sleep / yield primitives.  A live range crossing one of these is the
# population of interest -- NOT all 694 uses.
# Two spellings, and MISSING THE SECOND ONE UNDER-REPORTED THE WHOLE CENSUS.
#
#   1. the sleep primitive as a JUMP OPERAND      -- `JSR _sleep`
#   2. the sleep SELECTOR IN A REGISTER           -- `LDX #KSVC_SLEEP` then
#                                                    `JSL SYS_KCALL`
#
# Form 2 is how EVERY module sleeps: pty.mod (`pty.s:176-178`) and vfs.mod
# (`kc_sys.s:121-127`) both put the service number in X and call the one
# multiplexed kernel entry, so the sleep's NAME never appears as a jump target.
# A name-only regex reports those files as sleep-free -- and pty is where
# apple/fgx#41, this bug class's other historical defect, actually lived.
SLEEP_RE = re.compile(
    r"\b(JSR|JSL|JMP|JML)\s+_?(sleep|sleepUn|Sleep|swtch|_Sched_Yield|"
    r"SYS_NETKC_SLEEP|_NlKC_Sleep|kc_sleep)\b"
    r"|#\s*(KSVC_SLEEP|KSVC_SLEEPUN)\b"
)


def strip_comment(line):
    """Merlin comments start at ';' or a line beginning with '*'."""
    if line.lstrip().startswith("*"):
        return ""
    i = line.find(";")
    return line if i < 0 else line[:i]


def parse_cells():
    """Return {name: {'off': int|None, 'size': int|None, 'decl_line': int}}."""
    cells = {}
    off = None
    in_dum = False
    for n, raw in enumerate(DPMAP.read_text().splitlines(), 1):
        code = strip_comment(raw)
        s = code.strip()
        if re.match(r"^DUM\s+", s):
            in_dum = True
            try:
                off = int(s.split()[1].lstrip("$"), 16)
            except (IndexError, ValueError):
                off = None
            continue
        if s.startswith("DEND"):
            in_dum = False
            continue
        if not in_dum:
            continue
        m = DECL_RE.match(code)
        if not m:
            # Anonymous padding: `DS  n` with no label still advances the cursor.
            m2 = re.match(r"^\s+DS\s+(\S+)", code)
            if m2 and off is not None:
                sz = parse_size(m2.group(1))
                if sz is not None:
                    off += sz
            continue
        name, kind, arg = m.group(1), m.group(2), m.group(3)
        size = parse_size(arg) if kind == "DS" else 0
        cells[name] = {"off": off, "size": size, "decl_line": n}
        if kind == "DS" and off is not None and size is not None:
            off += size
    return cells


def parse_size(tok):
    tok = tok.strip()
    try:
        if tok.startswith("$"):
            return int(tok[1:], 16)
        return int(tok)
    except ValueError:
        return None


def iter_sources():
    for d in SEARCH_DIRS:
        for p in (REPO / d).rglob("*"):
            if p.suffix in SRC_SUFFIXES and p.is_file():
                yield p


def census(cells):
    """Walk the sources once, attributing each use to a cell and a mode."""
    names = sorted(cells, key=len, reverse=True)
    alt = "|".join(re.escape(n) for n in names)
    # Order matters: the long-indirect forms must be tried before the plain one.
    pats = [
        ("long_ind_y", re.compile(r"\[\s*(" + alt + r")\s*\]\s*,\s*[YyXx]")),
        ("long_ind", re.compile(r"\[\s*(" + alt + r")\s*\]")),
        ("ind_y", re.compile(r"\(\s*(" + alt + r")\s*\)\s*,\s*[YyXx]")),
        ("ind", re.compile(r"\(\s*(" + alt + r")\s*\)")),
        ("direct", re.compile(r"\b(" + alt + r")\b")),
    ]

    # A store/modify whose operand is the cell ITSELF (`STA _libcTmp2`) writes
    # the cell.  A store THROUGH it (`STA [_libcTmp2],Y`) does not -- it writes
    # the pointee.  The distinction is what separates a table base pointer
    # established once from a per-call transient re-aimed constantly.
    store_re = re.compile(
        r"\b(STA|STX|STY|STZ|INC|DEC|TSB|TRB|ASL|LSR|ROL|ROR)\s+"
        r"\|?<?(" + alt + r")\b(?!\s*[\],])")

    uses = collections.defaultdict(lambda: collections.Counter())
    files = collections.defaultdict(set)
    writes = collections.Counter()
    write_files = collections.defaultdict(set)
    sleep_files = set()
    sleep_sites = []

    for path in iter_sources():
        rel = str(path.relative_to(REPO))
        try:
            text = path.read_text(errors="replace")
        except OSError:
            continue
        for lineno, raw in enumerate(text.splitlines(), 1):
            if SLEEP_RE.search(strip_comment(raw)):
                sleep_files.add(rel)
                sleep_sites.append({"file": rel, "line": lineno,
                                    "text": raw.strip()[:110]})
            code = strip_comment(raw)
            if not code:
                continue
            for m in store_re.finditer(code):
                writes[m.group(2)] += 1
                write_files[m.group(2)].add(rel)
            rest = code
            for mode, pat in pats:
                consumed = []
                for m in pat.finditer(rest):
                    uses[m.group(1)][mode] += 1
                    files[m.group(1)].add(rel)
                    consumed.append((m.start(), m.end()))
                # Blank out what this mode matched so a weaker mode cannot
                # re-count the same text (`[_x],Y` must not also count as
                # `direct _x`).
                for a, b in reversed(consumed):
                    rest = rest[:a] + " " * (b - a) + rest[b:]
    return uses, files, writes, write_files, sleep_files, sleep_sites


def classify(counts):
    """DP-IRREDUCIBLE iff the cell is dereferenced as a 24-bit far pointer."""
    if counts.get("long_ind", 0) or counts.get("long_ind_y", 0):
        return "DP-IRREDUCIBLE"
    if counts.get("ind", 0) or counts.get("ind_y", 0):
        return "DP-INDIRECT-16"
    return "DP-REDUCIBLE"


def aim_kind(r):
    """How often is the cell RE-AIMED, and from how many places?

    A table base pointer is stored once (or in one place) and read everywhere:
    every task sees the same value, so holding it across a sleep is harmless.
    A per-call transient is re-aimed from many places, which is the hazard
    class #100 belongs to.  The boundary is deliberately crude -- it ranks the
    range walk, it does not replace it.
    """
    w, wf = r["writes"], r["write_files"]
    if w == 0:
        return "READ-ONLY"
    if wf <= 1 and w <= 3:
        return "BASE-PTR"
    if wf <= 2:
        return "SEMI-STABLE"
    return "TRANSIENT"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", metavar="PATH")
    ap.add_argument("--min-uses", type=int, default=1)
    args = ap.parse_args()

    cells = parse_cells()
    uses, files, writes, write_files, sleep_files, sleep_sites = census(cells)

    rows = []
    for name, info in cells.items():
        c = uses.get(name, collections.Counter())
        total = sum(c.values())
        if total < args.min_uses:
            continue
        touching = sorted(files.get(name, ()))
        rows.append({
            "cell": name,
            "off": info["off"],
            "size": info["size"],
            "class": classify(c),
            "uses": total,
            "modes": dict(c),
            "files": len(touching),
            # A cell used in a file that also contains a sleep site is where a
            # live range COULD cross a switch.  It is a candidate list, not a
            # verdict: the range still has to be walked.
            "files_with_sleep": sorted(set(touching) & sleep_files),
            "writes": writes.get(name, 0),
            "write_files": len(write_files.get(name, ())),
        })

    for r in rows:
        r["kind"] = aim_kind(r)
    rows.sort(key=lambda r: (-r["uses"], r["cell"]))

    print(f"{'cell':<20} {'off':>5} {'sz':>3} {'class':<16} "
          f"{'uses':>5} {'wr':>4} {'wrf':>4} {'kind':<11} sleep-files")
    print("-" * 110)
    for r in rows:
        off = f"${r['off']:02X}" if r["off"] is not None else "?"
        sl = ",".join(pathlib.Path(f).name for f in r["files_with_sleep"]) or "-"
        print(f"{r['cell']:<20} {off:>5} {str(r['size']):>3} {r['class']:<16} "
              f"{r['uses']:>5} {r['writes']:>4} {r['write_files']:>4} "
              f"{r['kind']:<11} {sl}")

    tot = collections.Counter(r["class"] for r in rows)
    print("-" * 96)
    print(f"{len(rows)} cells in use of {len(cells)} declared;  "
          + ";  ".join(f"{k}: {v}" for k, v in sorted(tot.items())))
    print(f"{len(sleep_sites)} sleep/yield sites in "
          f"{len(sleep_files)} files")

    at_risk = [r for r in rows if r["files_with_sleep"]]
    print(f"{len(at_risk)} cells are used in a file that also sleeps "
          f"-- the ranges to walk")

    if args.json:
        pathlib.Path(args.json).write_text(json.dumps(
            {"cells": rows, "sleep_sites": sleep_sites}, indent=1))
        print(f"wrote {args.json}", file=sys.stderr)


if __name__ == "__main__":
    main()
