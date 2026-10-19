#!/usr/bin/env python3
"""psstack_check -- ps(1)'s bank-0 stack columns describe the real arena.

WHY A SCRIPT AND NOT screen_contains
    The interesting claims are RELATIONSHIPS between numbers, and a substring
    match cannot express one.  Three of them, each covering a distinct way this
    feature can rot into a table of plausible-looking garbage:

    1. FIELD ALIGNMENT.  procinfo is a FIXED-SIZE record crossing the syscall
       boundary with no version tag: include/kernel.s picks the offsets, and
       src/userland/ps/ps.c re-declares them as a C struct.  If those two ever
       disagree, ps still prints a full table -- of the wrong cells.  The
       footer's DENOMINATOR is the tell, because it is the one number whose
       correct value is known independently: it must equal
       CFG_STK_ARENA_PAGES, which this script reads out of include/config.s
       rather than hardcoding, so resizing the arena does not need a test edit.

    2. THE MEASUREMENT IS LIVE.  The STK_PAINT high-water scan has existed
       since bank0-stack 0.1, but only ever ran at FREE time -- the mark could
       be read for a process that had already exited, and for no other.  ps's
       own row proves the scan now runs against a task that is still on the
       arena: it must carry a NUMERIC hwm, greater than zero (a running process
       has touched its stack) and no greater than its reservation (an hwm above
       the reservation means the guard page was entered).

    3. THE ROWS AGREE WITH THE ALLOCATOR.  The footer is counted from
       _stkArenaMap, the allocator's own bitmap; the rows come from each task's
       TCB.  They are independent sources for the same fact, so summing the
       arena-backed rows and finding MORE pages than the bitmap says are
       allocated means one of the two is lying.

    Deliberately NOT asserted: any specific page or byte count.  Those move
    with every codegen change, and pinning them would turn unrelated work red.

Exit 0 = pass, 1 = fail, 2 = inconclusive (no charbuf; misconfigured test).
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG_INC = HERE.parent.parent / "include" / "config.s"

# "    7     5  R    22   1104  60062 vi"  /  "    1     0  S     -      -      - init"
ROW = re.compile(r"^\s*(\d+)\s+(\d+)\s+([RSZT?])\s+(-|\d+)\s+(-|\d+)\s+(-|\d+)\s+(\S+)\s*$")
FOOTER = re.compile(r"^stack arena:\s*(\d+)/(\d+) pages used\s*$")


def arena_pages_from_source():
    """The arena size as the BUILD defines it -- the independent value.

    Read from include/config.s, where kernel.nproc derives it; include/kernel.s
    only aliases the name, so the old `EQU (\\d+)` match there now finds
    nothing.
    """
    m = re.search(r"^CFG_STK_ARENA_PAGES\s+EQU\s+(\d+)",
                  CONFIG_INC.read_text(), re.M)
    return int(m.group(1)) if m else None


def main(path):
    d = json.load(open(path))
    cb = (d.get("memory") or {}).get("charbuf")
    if not cb or not cb.get("hex"):
        print("INCONCLUSIVE: no charbuf in dump -- nothing to read")
        return 2
    raw = bytes(b & 0x7F for b in bytes.fromhex(cb["hex"]))
    text = raw.decode("ascii", "replace")
    rows = [text[i:i + 80].rstrip() for i in range(0, len(text), 80)]

    fails = []
    procs = []
    used = total = None
    for line in rows:
        m = ROW.match(line)
        if m:
            procs.append({
                "pid": int(m.group(1)),
                "stk": None if m.group(4) == "-" else int(m.group(4)),
                "hwm": None if m.group(5) == "-" else int(m.group(5)),
                "heap": None if m.group(6) == "-" else int(m.group(6)),
                "cmd": m.group(7),
            })
            continue
        m = FOOTER.match(line)
        if m:
            used, total = int(m.group(1)), int(m.group(2))

    if not procs:
        print("FAIL no ps table rows parsed -- ps printed nothing, or its "
              "column layout changed and this script no longer reads it")
        return 1

    # 1. Field alignment, via the one number known independently.
    want = arena_pages_from_source()
    if total is None:
        fails.append("no 'stack arena: U/T pages used' footer")
    elif want is None:
        fails.append("could not read CFG_STK_ARENA_PAGES from %s" % CONFIG_INC)
    elif total != want:
        fails.append("arena total is %d, but include/config.s says "
                     "CFG_STK_ARENA_PAGES = %d -- the record fields are "
                     "misaligned between the kernel and ps" % (total, want))
    elif not 0 < used <= total:
        fails.append("arena used = %d of %d, which is not a possible "
                     "occupancy" % (used, total))

    # 2. The high-water scan ran against a LIVE task: ps's own row.
    me = [p for p in procs if p["cmd"] == "ps"]
    if not me:
        fails.append("ps does not appear in its own output")
    else:
        p = me[0]
        if p["stk"] is None:
            fails.append("ps row has no reservation")
        elif p["hwm"] is None:
            fails.append("ps row shows hwm '-': the paint scan did not run on "
                         "a live task (or its stack is not arena-backed)")
        elif p["hwm"] <= 0:
            fails.append("ps hwm = %d: a running process has touched its stack"
                         % p["hwm"])
        elif p["hwm"] > p["stk"] * 256:
            fails.append("ps hwm %d B exceeds its %d-page reservation -- the "
                         "guard page was entered" % (p["hwm"], p["stk"]))

    # 3. The rows and the allocator bitmap agree.  Only rows with a measured
    #    hwm are arena-backed (an unpainted region reports '-'), so those are
    #    the ones the bitmap should account for.
    if used is not None:
        rowsum = sum(p["stk"] for p in procs
                     if p["stk"] is not None and p["hwm"] is not None)
        if rowsum > used:
            fails.append("arena-backed rows total %d pages but the allocator "
                         "bitmap says %d are in use" % (rowsum, used))

    # 4. The heap column is the allocator's own break cursor, read back.
    #    Two properties, both independent of any particular byte count:
    #    every live process must report a heap inside the bank, and bsh must
    #    have LESS of it left than ps -- bsh sbrk()s a stak arena into its data
    #    bank and ps never calls sbrk at all.  A wrong bank or a wrong offset
    #    reads a value with no reason to satisfy either.
    for p in procs:
        if p["heap"] is not None and not 0 < p["heap"] <= 65534:
            fails.append("%s: heap %d is not a possible break cursor"
                         % (p["cmd"], p["heap"]))
    def heap_of(name):
        r = [p for p in procs if p["cmd"] == name and p["heap"] is not None]
        return r[0]["heap"] if r else None
    h_sh, h_ps = heap_of("sh"), heap_of("ps")
    if h_ps is None:
        fails.append("ps reports no heap of its own")
    elif h_sh is not None and h_sh >= h_ps:
        fails.append("sh has %d B of heap left and ps has %d -- bsh grows a "
                     "stak arena by sbrk and ps never calls it, so sh must have "
                     "less" % (h_sh, h_ps))

    for p in procs:
        print("  pid %-4d %-10s stk=%s hwm=%s heap=%s"
              % (p["pid"], p["cmd"],
                 "-" if p["stk"] is None else p["stk"],
                 "-" if p["hwm"] is None else p["hwm"],
                 "-" if p["heap"] is None else p["heap"]))
    if fails:
        for f in fails:
            print("FAIL " + f)
        return 1
    print("PSSTACK PASS: %d rows, arena %d/%d pages" % (len(procs), used, total))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "dump.json"))
