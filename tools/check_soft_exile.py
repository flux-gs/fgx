#!/usr/bin/env python3
"""check_soft_exile.py - a soft function must not touch the hardware stack.

Bank-0 stack campaign 1.3 gives recursion-cycle functions their locals in the
task's DATA bank.  The invariant that makes that safe is narrow and total:

    for every function named in src/softscc/<binary>.txt,
    NO local is accessed via `n,S`, and NO frame address is minted from _fcc_fb.

A function that half-obeys is worse than one that does not obey at all.  Its
locals live in two banks at once, writes land in one and reads in the other, and
the arithmetic still comes out right whenever a wrong base is used consistently
-- which is why the runtime fixture could not see it.  This is the check that
can.

WHAT IT ALREADY CAUGHT.  fcc decided softness from the C-level function name
while the list -- generated FROM THE ASSEMBLY -- holds emitted symbols, and a
static function emits `<tu_prefix>_<name>`.  34 of bsh's 52 cycle members were
exiled and 18 silently were not.  Every test passed.  The half-exiled shell then
died at the 7th sourced command for reasons that looked like a memory bug.

PARAMS ARE NOT LOCALS, AND TELLING THEM APART IS THE WHOLE JOB.  Each hardware
slot access carries `; fccstk d=<delta> b=<base>`, and a PARAM's ends in ` fs`.
Excluding params with a negative lookahead -- `b=(\\d+)(?!\\s*fs)` -- is WRONG:
on `b=10 fs` the greedy `\\d+` backtracks to `1`, the lookahead sees `0 fs`, and
the param counts as a local.  Single-digit offsets cannot backtrack, so a
self-test written with `b=6 fs` passes while every multi-digit param is
miscounted.  That bug lived in stack_exile_cost.py and made this very check
report 24 phantom violations in bsh's execute().  Capture the suffix; do not
look ahead past a greedy group.

Usage:
    check_soft_exile.py                 check every binary with a list
    check_soft_exile.py --self-test
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ENT_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+ENT", re.M)
# Capture the ` fs` param marker rather than excluding it -- see the docstring.
SLOT_RE = re.compile(r",S\s*;\s*fccstk\s+d=(-?\d+)\s+b=(\d+)(?P<fs>\s+fs)?")
# A frame address minted from the HARDWARE frame base.  `LDA _fcc_fb` alone:
# the prologue/epilogue touch _fcc_fb via PEI/STA/INC, which are legitimate in a
# soft function (the hardware frame still exists, it is just empty).
FB_RE = re.compile(r"^\s*LDA\s+_fcc_fb\s*$", re.M)


def members(path):
    out = set()
    for line in open(path):
        line = line.strip()
        if line and not line.startswith("#"):
            out.add(line)
    return out


def scan(binary, soft):
    """[(func, n_local_slots, n_fb_mints, srcfile)] for violations."""
    bad = []
    d = os.path.join(ROOT, "tools", "%s-fgx2" % binary)
    for p in sorted(glob.glob(os.path.join(d, "*.s"))):
        if p.endswith(".link.s") or p.endswith(".data.s"):
            continue
        text = open(p, errors="replace").read()
        ents = list(ENT_RE.finditer(text))
        for i, m in enumerate(ents):
            if m.group(1) not in soft:
                continue
            end = ents[i + 1].start() if i + 1 < len(ents) else len(text)
            body = text[m.start():end]
            slots = sum(1 for x in SLOT_RE.finditer(body) if not x.group("fs"))
            fbs = len(FB_RE.findall(body))
            if slots or fbs:
                bad.append((m.group(1), slots, fbs, os.path.basename(p)))
    return bad


def _self_test():
    fails = 0
    cases = [
        ("   STA  7,S   ; fccstk d=0 b=7",            True),
        ("   LDA  10,S   ; fccstk d=0 b=10",          True),
        ("   LDA  6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs",   False),
        # The multi-digit param -- the case a lookahead gets wrong, and the one
        # that produced 24 phantom violations before this file existed.
        ("   LDA  10+f_FRAMESIZE,S   ; fccstk d=0 b=10 fs", False),
        ("   LDA  18+f_FRAMESIZE,S   ; fccstk d=8 b=10 fs", False),
    ]
    for text, want_local in cases:
        m = SLOT_RE.search(text)
        got = bool(m) and not m.group("fs")
        if got != want_local:
            print("  SELFTEST FAIL: %r -> local=%s, want %s"
                  % (text, got, want_local))
            fails += 1
    # The prologue's own _fcc_fb traffic must NOT read as a mint, or every soft
    # function reports a violation and the check gets switched off.
    if FB_RE.search("                PEI     _fcc_fb\n") or \
       FB_RE.search("                STA     _fcc_fb\n") or \
       FB_RE.search("                INC     _fcc_fb\n"):
        print("  SELFTEST FAIL: prologue _fcc_fb traffic counted as a mint")
        fails += 1
    if not FB_RE.search("                LDA     _fcc_fb\n"):
        print("  SELFTEST FAIL: a real _fcc_fb mint was not detected")
        fails += 1
    # A near-miss symbol must not match (_fcc_fb_lo etc. live in the float code).
    if FB_RE.search("                LDA     _fcc_fb_lo\n"):
        print("  SELFTEST FAIL: _fcc_fb_lo matched as _fcc_fb")
        fails += 1
    if fails:
        print("check_soft_exile self-test: %d FAILURE(S)" % fails)
        return 1
    print("check_soft_exile self-test: OK (%d cases)" % (len(cases) + 3))
    return 0


def main():
    if "--self-test" in sys.argv:
        return _self_test()
    lists = sorted(glob.glob(os.path.join(ROOT, "src", "softscc", "*.txt")))
    if not lists:
        print("no soft-frame lists -- nothing exiled, nothing to check")
        return 0
    rc = 0
    for lp in lists:
        binary = os.path.basename(lp)[:-4]
        soft = members(lp)
        if not os.path.isdir(os.path.join(ROOT, "tools", "%s-fgx2" % binary)):
            print("!! %s: listed but not built" % binary)
            rc = 1
            continue
        bad = scan(binary, soft)
        # A list whose names match NOTHING is the silent failure this exists to
        # stop: zero violations because zero functions were examined.
        built = set()
        for p in glob.glob(os.path.join(ROOT, "tools", "%s-fgx2" % binary, "*.s")):
            if not p.endswith((".link.s", ".data.s")):
                built |= {m.group(1) for m in
                          ENT_RE.finditer(open(p, errors="replace").read())}
        missing = sorted(soft - built)
        if missing:
            print("!! %s: %d listed function(s) are not in the built assembly "
                  "-- the list and the binary disagree: %s"
                  % (binary, len(missing), missing[:6]))
            rc = 1
        if bad:
            print("!! %s: %d soft function(s) still touch the hardware stack"
                  % (binary, len(bad)))
            for fn, slots, fbs, src in sorted(bad, key=lambda t: -t[1] - t[2])[:12]:
                print("     %-26s n,S locals=%-4d _fcc_fb mints=%-3d (%s)"
                      % (fn, slots, fbs, src))
            rc = 1
        elif not missing:
            print("   %s: %d soft functions, none touch the hardware stack"
                  % (binary, len(soft)))
    return rc


if __name__ == "__main__":
    sys.exit(main())
