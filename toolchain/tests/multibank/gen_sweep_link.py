#!/usr/bin/env python3
"""Link the far-pointer sweep with explicit placement from bankmap.json.

bankmap.json's first code segment is the program's segment 0; each further
one is an fgx_static --code-seg, so group i (i >= 1) is segment i+1 (segment
1 is the data).  A ballast entry is a 12,288-byte DS block: inert bytes that
keep the code banks realistically full.  Also LINTS that every declared
[caller, callee] pair sits in DIFFERENT groups (a same-segment callee makes a
"cross-bank" call intra-bank -> false green).

fgx_static measures the stack over every code file and every libc bank it
links, so libc's deepest frame (getwd, 384 bytes) is counted.

Run from toolchain/tests/multibank/ AFTER build_sweep.sh compiles the TUs.
Writes multibank.bin, with the link's files in ld/.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import fixture_link  # noqa: E402

BALLAST_DS = 12288


def lint(bm):
    seg_of = {}
    for i, seg in enumerate(bm["code_segments"]):
        for tu in seg:
            seg_of[tu] = i
    for i, seg in enumerate(bm["code_segments"]):
        # fgx_ld refuses an FGX3 code segment with no FGX2_MODE stamp, which
        # only fcc output carries: a group of ballast alone cannot link.
        if all(t.startswith("ballast/") for t in seg):
            sys.exit("LINT FAIL: group %d holds only ballast; it needs a TU." % i)
    for caller, callee in bm.get("callees", []):
        if caller not in seg_of:
            sys.exit("LINT FAIL: caller TU '%s' not placed in any segment." % caller)
        if callee not in seg_of:
            sys.exit("LINT FAIL: callee TU '%s' not placed in any segment." % callee)
        if seg_of[caller] == seg_of[callee]:
            sys.exit("LINT FAIL: %s and its callee %s share group %d -> the call "
                     "would be intra-bank (false green)." % (caller, callee, seg_of[caller]))


def ballast(tu):
    name = "ballast_%s.s" % tu.split("/", 1)[1]
    with open(os.path.join(HERE, name), "w") as f:
        f.write("                DS     %d\n" % BALLAST_DS)
    return name


def link(bm):
    groups, data = [], []
    for seg in bm["code_segments"]:
        g = []
        for t in seg:
            if t.startswith("ballast/"):
                g.append(ballast(t))
            else:
                g.append(t + ".code.s")
                data.append(t + ".data.s")
        groups.append(g)
    ok, log = fixture_link.link(HERE, os.path.join(HERE, "ld"), groups[0], data,
                                os.path.join(HERE, "multibank.bin"),
                                name="multibank", code_segs=groups[1:])
    sys.stdout.write(log)
    if not ok:
        sys.exit("LINK FAIL (see above)")


if __name__ == "__main__":
    bm = json.load(open(os.path.join(HERE, "bankmap.json")))
    lint(bm)
    link(bm)
