#!/usr/bin/env python3
"""stack_exile_cost.py - what increment 1.2 would cost in CODE bytes, counted
from the built assembly instead of estimated.

1.2 moves every `addr_taken || raw_accessed` local off the bank-0 hardware stack
into the task's data bank.  Each access to such a local changes from

    LDA  n,S                     2 bytes
to
    LDY  #off                    3 bytes
    LDA  (_fcc_sfp),Y            2 bytes

so every converted access costs **+3 bytes of code**, and the campaign's stated
gate for 1.2 is that per-segment code size stays inside the 64 KB cliff margin.
tcsh already lives against that cliff: adding 14 bytes per code segment to
fcc_runtime.s pushed it past its 7-bank cap outright on 2026-08-02.

This is not a new risk, it is the one that killed the last soft stack.  The
2026-07-05 attempt used `LDY #off / LDA [_fcc_ssp],Y` -- the same +3 -- and jsh
overflowed FGX1's 64 KB single-bank cap.  It was found by building, not by
predicting.  So: count it before writing the codegen.

METHOD.  Two inputs, no new compiler pass:
  1. `FCC_STACK_CENSUS=<file> ninja all` -- fcc appends one line per function
     including `exrange=lo:hi,...`, the frame-byte ranges of its exiled locals.
     The census emits nothing into the .s, so goldens stay byte-identical.
  2. The built .s, where every hardware-stack slot access already carries a
     `; fccstk d=<delta> b=<base>` annotation.  `b` is the delta-free,
     FRAMESIZE-free slot displacement, i.e. `2*slot_first + 1 + off`, so the
     frame byte an access touches is `b - 1`.

An access converts iff its frame byte falls inside one of that function's exiled
ranges.  Params are excluded: they carry the `fs` marker and stay on the
hardware stack in 1.2 by design.

Usage:  tools/stack_exile_cost.py /tmp/census.txt
        tools/stack_exile_cost.py --self-test
"""
import collections
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# `<op> <disp>,S   ; fccstk d=<delta> b=<base>` -- a LOCAL access.  A PARAM's
# annotation ends in ` fs`, and params do not move, so telling them apart is
# load-bearing rather than tidy.
#
# This CAPTURES the ` fs` suffix instead of excluding it with a lookahead.  The
# lookahead form -- `b=(\d+)(?!\s*fs)` -- was wrong in a way its own self-test
# could not see: on `b=10 fs` the greedy `\d+` backtracks to match just `1`,
# the lookahead then sees `0 fs` (which is not `\s*fs`), and the PARAM is
# counted as a local.  Single-digit offsets cannot backtrack, so a self-test
# written with `b=6 fs` passes while every multi-digit param is miscounted --
# and offsets past 9 are the common case in any real function.  Measured
# 2026-08-02: this inflated tcsh's projected exile cost.
ACCESS_RE = re.compile(r";\s*fccstk\s+d=(-?\d+)\s+b=(\d+)(?P<fs>\s+fs)?")
ENT_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+ENT", re.M)
BYTES_PER_CONVERTED_ACCESS = 3


def read_census(path):
    """{(tu_basename, func): [(lo, hi), ...]} of exiled frame-byte ranges."""
    out = {}
    with open(path) as f:
        for line in f:
            parts = line.split()
            if len(parts) < 3 or not parts[2].startswith("frame="):
                continue
            tu, func = os.path.basename(parts[0]), parts[1]
            rngs, agg = [], []
            for tok in parts:
                for tag, dst in (("exrange=", rngs), ("agrange=", agg)):
                    if tok.startswith(tag):
                        for r in tok[len(tag):].split(","):
                            if ":" in r:
                                lo, hi = r.split(":")
                                dst.append((int(lo), int(hi)))
            out[(tu, func)] = (rngs, agg)
    return out


def tu_of(path):
    """tools/sh-fgx2/expand.code.s -> expand.c, the census's own key.

    fcc records the .c it compiled; the assembler output drops the extension
    and may carry a `.code` infix.  Reconstructing the .c name is what lets the
    two be joined per translation unit rather than per bare symbol.
    """
    stem = os.path.basename(path)[:-2]           # strip ".s"
    if stem.endswith(".code"):
        stem = stem[:-5]
    return stem + ".c"


def scan_sources(census):
    """Per code segment: converted accesses, and the code bytes 1.2 would add."""
    per_binary = collections.Counter()
    per_binary_agg = collections.Counter()
    per_file = collections.Counter()
    unmatched = collections.Counter()
    for path in glob.glob(os.path.join(ROOT, "tools", "*-fgx2", "*.s")):
        if path.endswith(".link.s") or path.endswith(".data.s"):
            continue
        binary = os.path.basename(os.path.dirname(path))[:-5]
        text = open(path, errors="replace").read()
        ents = list(ENT_RE.finditer(text))
        for i, m in enumerate(ents):
            end = ents[i + 1].start() if i + 1 < len(ents) else len(text)
            body = text[m.start():end]
            # Match on (TU, function), never on the function name alone:
            # every binary has a `main`, and taking whichever census line
            # happened to be first would score one binary's frame layout
            # against another's assembly.
            got = census.get((tu_of(path), m.group(1)))
            if got is None:
                unmatched[binary] += 1
                continue
            rngs, agg = got
            if not rngs:
                continue
            for m in ACCESS_RE.finditer(body):
                if m.group("fs"):
                    continue                     # param: stays on the hw stack
                byte = int(m.group(2)) - 1
                if any(lo <= byte < hi for lo, hi in rngs):
                    per_binary[binary] += 1
                    per_file[path] += 1
                if any(lo <= byte < hi for lo, hi in agg):
                    per_binary_agg[binary] += 1
    return per_binary, per_binary_agg, per_file, unmatched


def _self_test():
    fails = 0
    # The annotation parser must take LOCALS and reject PARAMS -- params keep
    # their hardware slot in 1.2, and counting them would inflate the estimate
    # in the reassuring direction (a bigger predicted cost is not the dangerous
    # error; a smaller one is, so check both).
    if not ACCESS_RE.search("   LDA  6,S   ; fccstk d=0 b=7"):
        print("  SELFTEST FAIL: a LOCAL annotation was not matched")
        fails += 1
    m = ACCESS_RE.search("   LDA  6+f_FRAMESIZE,S   ; fccstk d=0 b=6 fs")
    if m is None or not m.group("fs"):
        print("  SELFTEST FAIL: a PARAM annotation was counted as a local")
        fails += 1
    # THE case the old self-test missed: a MULTI-DIGIT param offset.  The
    # previous lookahead form passed the single-digit check above and failed
    # this one, because `\d+` can backtrack when there is more than one digit.
    m = ACCESS_RE.search("   LDA  10+f_FRAMESIZE,S   ; fccstk d=0 b=10 fs")
    if m is None or not m.group("fs"):
        print("  SELFTEST FAIL: a multi-digit PARAM was counted as a local")
        fails += 1
    m = ACCESS_RE.search("   LDA  10,S   ; fccstk d=0 b=10")
    if m is None or m.group("fs"):
        print("  SELFTEST FAIL: a multi-digit LOCAL was not matched")
        fails += 1
    m = ACCESS_RE.search("; fccstk d=-4 b=11")
    if m is None or m.group(1) != "-4" or m.group(2) != "11" or m.group("fs"):
        print("  SELFTEST FAIL: negative delta not parsed: %r"
              % (m.groups() if m else None,))
        fails += 1
    # Range membership: b=7 -> frame byte 6, inside [4,8) and not [8,12).
    if not (4 <= 6 < 8) or (8 <= 6 < 12):
        print("  SELFTEST FAIL: range arithmetic")
        fails += 1
    if fails:
        print("stack_exile_cost self-test: %d FAILURE(S)" % fails)
        return 1
    print("stack_exile_cost self-test: OK (6 cases)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return _self_test()
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    census = read_census(sys.argv[1])
    if not census:
        print("!! census file has no function lines -- was it produced with "
              "FCC_STACK_CENSUS set on a FULL build?  An empty census scores "
              "every binary at zero cost, which is the answer you want to see "
              "and therefore the one to distrust.")
        return 1
    per_binary, per_binary_agg, per_file, unmatched = scan_sources(census)
    print("census: %d functions" % len(census))
    print("\n%-10s %12s %14s" % ("binary", "ALL exiled", "aggregates only"))
    for b, n in sorted(per_binary.items(), key=lambda kv: -kv[1])[:12]:
        a = per_binary_agg[b]
        print("%-10s %+11d B %+13d B" % (b, n * BYTES_PER_CONVERTED_ACCESS,
                                         a * BYTES_PER_CONVERTED_ACCESS))
    print("\nworst single .s (a code SEGMENT is the 64 KB unit):")
    for p, n in sorted(per_file.items(), key=lambda kv: -kv[1])[:8]:
        print("  %-46s %5d  -> +%d B" % (os.path.relpath(p, ROOT), n,
                                         n * BYTES_PER_CONVERTED_ACCESS))
    if unmatched:
        print("\nfunctions with no census line (not counted): %s"
              % dict(unmatched.most_common(5)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
