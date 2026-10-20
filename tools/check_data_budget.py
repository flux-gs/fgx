#!/usr/bin/env python3
"""check_data_budget.py - how much program does a task's DATA bank hold?

WHAT CHANGED, AND WHY THIS IS NOT THE SAME TOOL.  Increments 1.2/1.3 originally
put exiled locals in the task's data bank, so this file's job was to check that
the soft stack, the statics and the sbrk heap all fitted in 64 KB together.  The
soft stack MOVED OUT on 2026-08-02 -- it has its own bank now (apple/fgx#12) --
so that three-way sum is gone and the data bank has exactly two tenants:

    [0, end)        statics
    [end, $FFFE)    the sbrk heap, growing up

The old version also measured the wrong thing on its own terms: it computed the
projected soft peak from the call graph and compared it against `end`, i.e.
against the STATICS, never against the live break.  It reported "sh: 386 turns,
ok" for a configuration that died at the SEVENTH sourced command.  A budget tool
that cannot fail on a build that fails is worse than no budget tool, which is
why the numbers below are per-command MEASUREMENTS rather than a model.

WHAT IT ANSWERS NOW.  bsh's binding limit is this bank.  Its `.` builtin parses
the WHOLE sourced file into the stak arena before executing a line, and the
arena grows with the parse tree -- so the data bank sets a hard ceiling on how
long a sourced script can be.  Past it the read is silently TRUNCATED: the shell
stops, waits for input, and reports nothing.  This prints the ceiling so that
limit is visible at build time instead of at command 184 on real hardware.

THE PER-COMMAND FIGURES ARE MEASURED, not derived.  bsh: the break reached
$FB90 with `end` at $3690 after 184 sourced commands => (64400-13968)/184 = 274
bytes of arena per command.  Re-measure by running srcdepth_loud with the
soft-frame overflow report enabled and reading `brk=` out of the kill line.

Usage:
    check_data_budget.py               report every built binary
    check_data_budget.py --self-test
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "toolchain", "src", "ld"))
import fgx_ld  # noqa: E402

BANK = 65536
CURSOR = 2               # the break cursor occupies dataBank:$FFFE-$FFFF
END_RE = re.compile(r"^end\s+EQU\s+\$?([0-9A-Fa-f]+)", re.M)
# Any seg1_layout.s label, not just `end' -- a dynamic program that never
# names `end' has no end label: fgx_dyn.py computes its `end' equivalent,
# len(seg1), at link time and never writes it out as a label, so a dynamic
# layout's highest EQU'd address stands in for it (statics_of below).
EQU_RE = re.compile(r"^\S+\s+EQU\s+\$?([0-9A-Fa-f]+)", re.M)

# Heap a binary must be left after its own arena growth, for malloc/stdio.  A
# policy floor, named so it can be argued with rather than discovered.
MIN_HEAP = 8 * 1024

# Measured bytes of stak arena per sourced command.  Only the Bourne shell
# parses a whole file up front, so only it has a depth ceiling worth printing;
# anything else gets its headroom reported without a depth claim.
ARENA_PER_CMD = {"sh": 274}


def _statics_from_layout(text):
    """Bytes of statics a seg1_layout.s claims: its `end' label when there is
    one, else the highest address any label in it EQUs to (within a label's
    width of the true figure -- close enough to see whether the heap has
    room).  None if the file has no labels at all."""
    m = END_RE.search(text)
    if m:
        return int(m.group(1), 16)
    addrs = [int(a, 16) for a in EQU_RE.findall(text)]
    return max(addrs) if addrs else None


def _mode_of_header(head):
    """"dyn.ld" or "static.ld" per a built .bin's own header flags
    (fgx_ld.DYN_FLAG, byte 10 bit 2); None if `head' is not a recognized
    FGX2/FGX3 header (too short, missing binary, wrong magic)."""
    if len(head) < 11 or head[:4] not in (fgx_ld.FGX2_MAGIC, fgx_ld.FGX3_MAGIC):
        return None
    return "dyn.ld" if head[10] & fgx_ld.DYN_FLAG else "static.ld"


def _pick_ld(present, mode, mtime):
    """Which of the `present' ld dirs to read.  `mode' (the binary's own
    link mode, or None) wins when it is among them -- a binary that changed
    link mode leaves its OLD mode's dir behind (gitignored, never cleaned),
    and that stale layout must lose even if it is the newer file.  Failing
    that, when more than one dir is present, the newer by `mtime' (a
    dir-name -> number function); otherwise whichever one there is."""
    if mode in present:
        return mode
    if len(present) > 1:
        return max(present, key=mtime)
    return present[0] if present else None


def statics_of(binary):
    """Bytes of the data bank the statics occupy (`end` = base of the heap),
    from the data segment's layout as fgx_static (static.ld) or fgx_dyn
    (dyn.ld) wrote it; None for a binary with no layout at all."""
    base = os.path.join(ROOT, "tools", "%s-fgx2" % binary)
    present = [ld for ld in ("static.ld", "dyn.ld")
               if os.path.exists(os.path.join(base, ld, "seg1_layout.s"))]
    if not present:
        return None
    bp = os.path.join(ROOT, "bin", "%s.bin" % binary)
    mode = _mode_of_header(open(bp, "rb").read(fgx_ld.HEADER_SZ)) if os.path.exists(bp) else None
    ld = _pick_ld(present, mode,
                  lambda d: os.path.getmtime(os.path.join(base, d, "seg1_layout.s")))
    text = open(os.path.join(base, ld, "seg1_layout.s"), errors="replace").read()
    return _statics_from_layout(text)


def _self_test():
    fails = 0
    if END_RE.search("end             EQU     $3690\n") is None:
        print("  SELFTEST FAIL: `end` EQU not parsed")
        fails += 1
    elif int(END_RE.search("end             EQU     $3690\n").group(1), 16) != 0x3690:
        print("  SELFTEST FAIL: end parsed wrong")
        fails += 1
    # A near-miss symbol must NOT read as `end`: `_end`, `endptr` and `ends` all
    # appear in real layouts, and taking one reports the wrong statics figure in
    # the reassuring direction.
    for bad in ("_end            EQU     $1000\n", "endptr          EQU     $1000\n"):
        if END_RE.search(bad):
            print("  SELFTEST FAIL: matched a near-miss symbol: %r" % bad)
            fails += 1
    # The arithmetic, against the numbers actually measured on hardware: bsh's
    # break reached $FB90 from an `end` of $3690 after 184 sourced commands.
    heap = BANK - CURSOR - 0x3690
    if heap != 51566:
        print("  SELFTEST FAIL: heap span %d, want 51566" % heap)
        fails += 1
    if round((0xFB90 - 0x3690) / 184) != 274:
        print("  SELFTEST FAIL: per-command arena figure drifted")
        fails += 1
    # The depth a full span buys must exceed what srcdepth asserts (55) and fall
    # short of nothing in particular -- this pins the direction, not the value.
    if (heap - MIN_HEAP) // 274 <= 55:
        print("  SELFTEST FAIL: computed depth does not cover srcdepth's 55")
        fails += 1
    # _mode_of_header: the control is a header that names neither mode (short,
    # or the wrong magic) -- it must say None, not default to either guess.
    dyn_head = b"FGX3\0\0\0\0\0\0" + bytes([fgx_ld.DYN_FLAG]) + b"\0\0\0\0\0"
    static_head = b"FGX3\0\0\0\0\0\0\0\0\0\0\0\0"
    if _mode_of_header(dyn_head) != "dyn.ld":
        print("  SELFTEST FAIL: DYN_FLAG header not read as dyn.ld")
        fails += 1
    if _mode_of_header(static_head) != "static.ld":
        print("  SELFTEST FAIL: clear-flag header not read as static.ld")
        fails += 1
    if _mode_of_header(b"????\0\0\0\0\0\0\0\0\0\0\0\0") is not None:
        print("  SELFTEST FAIL: wrong magic must not guess a mode")
        fails += 1
    # _pick_ld: a binary that changed link mode leaves its old mode's dir
    # behind, possibly newer (an edit can touch it after the rebuild moved on)
    # -- the mode match must win over mtime, not just break a tie.
    if _pick_ld(["static.ld", "dyn.ld"], "dyn.ld",
                {"static.ld": 200, "dyn.ld": 100}.get) != "dyn.ld":
        print("  SELFTEST FAIL: mode match lost to the newer stale dir")
        fails += 1
    # With no mode to go on (no .bin yet), the newer file is the best guess.
    if _pick_ld(["static.ld", "dyn.ld"], None,
                {"static.ld": 100, "dyn.ld": 200}.get) != "dyn.ld":
        print("  SELFTEST FAIL: mtime fallback did not pick the newer dir")
        fails += 1
    # _statics_from_layout: a dynamic layout defines no `end' label (fgx_dyn.py
    # computes it, len(seg1), and never EQUs it) -- the control is the same
    # text WITH an `end' line, which must still win over the EQU scan.
    dyn_layout = "ibuf      EQU     $0184\ntbuf      EQU     $1918\n"
    if _statics_from_layout(dyn_layout) != 0x1918:
        print("  SELFTEST FAIL: no-`end' layout did not fall back to highest EQU")
        fails += 1
    if _statics_from_layout("end       EQU     $3690\n" + dyn_layout) != 0x3690:
        print("  SELFTEST FAIL: an `end' label must still win over the EQU scan")
        fails += 1
    if fails:
        print("check_data_budget self-test: %d FAILURE(S)" % fails)
        return 1
    print("check_data_budget self-test: OK (14 cases)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return _self_test()
    print("data bank = %d B; break cursor takes %d; reserving %d B of heap\n"
          % (BANK, CURSOR, MIN_HEAP))
    print("%-10s %9s %10s %12s   %s"
          % ("binary", "statics", "heap span", "usable", "sourced-command ceiling"))
    rc = 0
    for b in ARENA_PER_CMD:
        if statics_of(b) is None:
            # Skipping it would turn the ceiling check below into a pass.
            print("!! %s: no data-segment layout with `end' under tools/%s-fgx2"
                  % (b, b))
            rc = 1
    for d in sorted(glob.glob(os.path.join(ROOT, "tools", "*-fgx2"))):
        b = os.path.basename(d)[:-5]
        st = statics_of(b)
        if st is None:
            continue
        span = BANK - CURSOR - st
        usable = span - MIN_HEAP
        note = "-"
        if b in ARENA_PER_CMD:
            n = usable // ARENA_PER_CMD[b]
            note = "~%d commands (%d B/cmd, measured)" % (n, ARENA_PER_CMD[b])
            # Past this the sourced read truncates in SILENCE, so the shell's
            # bank-0 stack reservation is deliberately sized to trip its guard
            # first (the link's stack_pad, fgx_static --stack-pad).  If that
            # ordering ever inverts, a runaway script stops saying anything
            # at all.
            if n < 55:
                print("!! %s: ceiling %d is below srcdepth's 55-command test"
                      % (b, n))
                rc = 1
        if usable < 0:
            print("!! %s: statics leave no room for the heap" % b)
            rc = 1
        print("%-10s %9d %10d %12d   %s" % (b, st, span, usable, note))
    print("\nThe soft-frame stack is NOT here: it has its own bank since\n"
          "2026-08-02, which is why this file no longer sums three tenants.")
    return rc


if __name__ == "__main__":
    sys.exit(main())
