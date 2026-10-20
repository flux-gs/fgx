#!/usr/bin/env python3
"""helper_census.py - which fcc runtime helpers libc.so exports far
(shared libc SP2 spec, section 6).

For each helper unit of toolchain/lib/fcc_runtime.s (split as fgx_libso
splits it): its assembled size; how many programs' own code calls it; how
many code banks carry the whole runtime today (every code segment of every
program, and each pile); and its share of the recorded profiles.  A far
entry costs about 14 cycles a call more than a near one (spec section 6),
so a helper is exported far when it is BIG (>= MIN_BYTES) and COLD (no
recorded share >= MAX_SHARE, and not reached by a helper that has one),
reads no caller-pushed stack argument, and exchanges nothing through a data
cell -- neither one compiled code names (_fcc_tmp_b) nor one it shares with
a helper that calls it (_fcc_long_div_rem_*, which _fcc_long_modu reads
after _fcc_long_divu): the helper would use libc.so's copy of the cell and
its caller the program's.  Nor is a unit exported that has an inner label
fcc or compiled code names (a unit that falls through into one: fsub runs
into fadd, which fcc calls itself).

The shares are the recorded profiles the spec names, with provenance; no
tool in the tree attributes samples across a program's banks yet.

Run: helper_census.py            print the census and the choice
     helper_census.py --write    write toolchain/lib/libc_so_helpers.s
     helper_census.py --check    fail if that file is not the choice
     helper_census.py --self-test
"""
import glob
import json
import os
import re
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TC = os.path.join(ROOT, "toolchain")
sys.path.insert(0, os.path.join(TC, "src", "ld"))
import fgx_gc  # noqa: E402
import fgx_libso  # noqa: E402

OUT = os.path.join(TC, "lib", "libc_so_helpers.s")
MIN_BYTES = 48
MAX_SHARE = 0.1          # percent of a profiled run
# Recorded PC-sample shares, percent of the run:
#   2026-09-27 mixed workload (ls -l, wc, grep, od -c, cmp), main 75f05713f
#   2026-09-10 campperf five-exec workload, main 4e6388f12
SHARES = {"_fcc_mods16": 5.0, "_fcc_ltof": 2.0, "_fcc_long_mul": 1.92,
          "_fcc_long_shr": 0.99, "_fcc_long_shl": 0.36}


def shared_cell_callees(deps, cells):
    """Helpers another helper calls and then shares a data cell with.  The
    caller reads (or writes) the cell around the call -- _fcc_long_modu JSRs
    _fcc_long_divu, then reads the remainder divu leaves in
    _fcc_long_div_rem_* -- so a far callee would use libc's core copy while
    a near caller uses the program's."""
    return {h for n, hs in deps.items() for h in hs
            if cells.get(n, set()) & cells.get(h, set())}


def inner_called(units, order, text):
    """Units that fall through into a label named outside them: fsub runs
    into fadd, and fcc JSRs _fcc_fadd itself.  A far entry replaces the
    unit's near body in a program's segment, so every label in it but the
    first would be left with none."""
    named = set(fgx_gc.IDENT.findall(text))
    return {u for u in order
            if (fgx_gc.defined_labels(units[u]) - {u}) & named}


def settle(sizes, shares, excluded, deps, cells):
    """(far list, excluded): choose, then drop any far helper a near helper
    calls and shares a data cell with, until nothing changes."""
    excluded = set(excluded)
    while True:
        pick = choose(sizes, shares, excluded, deps)
        near = {n: hs for n, hs in deps.items() if n not in pick}
        bad = shared_cell_callees(near, cells) & set(pick)
        if not bad:
            return pick, excluded
        excluded |= bad


def choose(sizes, shares, stackargs, deps):
    """Big, cold helpers.  Hot is a recorded share of MAX_SHARE or more, or
    being reached by a hot helper: the profiles list only their top items,
    and a sample in _fcc_divs16 on _fcc_mods16's behalf is not listed."""
    hot = {h for h in sizes if shares.get(h, 0.0) >= MAX_SHARE}
    for h in list(hot):
        hot |= set(deps.get(h, ()))
    return sorted(h for h, n in sizes.items()
                  if n >= MIN_BYTES and h not in hot and h not in stackargs)


def stubs(names):
    rows = []
    for h in names:
        rows += ["                FGX2_EXPORT %s_far" % h,
                 "%s_far JSR    %s" % (h, h),
                 "                RTL"]
    return rows


def census():
    head, units, order = fgx_libso.runtime_units(
        open(fgx_libso.RUNTIME).read().split("\n"))
    d = tempfile.mkdtemp(prefix="census_")
    fgx_libso.core_link(d)                      # d/core_layout.s
    with open(os.path.join(d, "rt_head.s"), "w") as f:
        f.write("\n".join(head) + "\n")
    fgx_libso.write_units(os.path.join(d, "lits.s"), order, units)
    link = fgx_libso.write_link(d, "m0", 0, fgx_libso.CODE_EQUS + fgx_libso.DP_EQUS,
                                [fgx_libso.MACROS, "core_layout.s", "rt_head.s",
                                 "lits.s"])
    if fgx_libso.run_merlin(d, link) is None:
        sys.exit("helper_census: the runtime is over 64 KB?")
    sizes = fgx_libso.section_sizes(os.path.join(d, "m0_Output.txt"), "lits.s")
    def code_rows(u):
        return [fgx_gc.COMMENT.sub("", r) for r in units[u]
                if r.strip() and r.lstrip()[0] not in ";*"]
    stackargs = {u for u in order if any(re.search(r",\s*S\b", r)
                                         for r in code_rows(u))}
    # Data cells compiled code names: a helper naming one takes input (or
    # gives output) through the process's data, which a far call cannot
    # carry across (libc.so's copy would read libc's core cell).
    rt_cells = fgx_gc.defined_labels(open(os.path.join(
        TC, "lib", "fcc_runtime_data.s")).read().split("\n"))
    compiled = open(os.path.join(TC, "lib", "libc_so.s")).read()
    for p in glob.glob(os.path.join(ROOT, "tools", "*-fgx2", "*.s")):
        if not p.endswith((".link.s", "_layout.s", ".gc.s", ".sel.s", ".data.s")):
            compiled += open(p, errors="replace").read()
    shared_cells = rt_cells & set(fgx_gc.IDENT.findall(compiled))
    fcc_src = "\n".join(open(p).read() for p in
                        glob.glob(os.path.join(TC, "src", "cc", "*.c")))
    inner = inner_called(units, order, compiled + fcc_src)
    dataargs = {u for u in order if shared_cells & set(
        fgx_gc.IDENT.findall("\n".join(code_rows(u))))}
    own = fgx_libso.shared_owner(units, order)
    users = {u: 0 for u in order}
    # Banks that carry the whole runtime today: every CODE segment.
    banks = 0
    for m in (glob.glob(os.path.join(ROOT, "tools", "*-fgx2", "*.json")) +
              glob.glob(os.path.join(ROOT, "tools", "*-fgx2", "*.ld", "*.json"))):
        try:
            segs = json.load(open(m)).get("segments", [])
        except (ValueError, OSError):
            continue
        banks += sum(1 for s in segs if s.get("kind") == "CODE")
        # A shell's manifest now lives under its build dir's dyn.ld/static.ld
        # (the fgx2 dir is the manifest's grandparent, not its parent); own
        # code is still the shell's own .s files, not the .ld dir's.
        own_dir = os.path.dirname(m)
        if os.path.basename(own_dir) in ("dyn.ld", "static.ld"):
            own_dir = os.path.dirname(own_dir)
        own_code = [p for p in glob.glob(os.path.join(own_dir, "*.s"))
                    if not p.endswith((".link.s", "_layout.s", ".gc.s", ".sel.s",
                                       ".data.s"))]
        seen = set()
        for p in own_code:
            seen |= {own[t] for t in fgx_gc.IDENT.findall(open(p, errors="replace").read())
                     if t in own}
        for u in seen:
            users[u] += 1
    deps = fgx_libso.shared_refs(units, order, own)
    cells = {u: rt_cells & set(fgx_gc.IDENT.findall("\n".join(code_rows(u))))
             for u in order}
    return order, sizes, stackargs, users, banks, deps, dataargs, cells, inner



def self_test():
    sizes = {"_fcc_big_cold": 200, "_fcc_big_hot": 300, "_fcc_small": 20,
             "_fcc_big_stack": 90, "_fcc_big_dep": 150}
    shares = {"_fcc_big_hot": 1.2}
    deps = {"_fcc_big_hot": ["_fcc_big_dep"]}
    assert choose(sizes, shares, {"_fcc_big_stack"}, deps) == ["_fcc_big_cold"]
    rows = stubs(["_fcc_big_cold"])
    assert rows == ["                FGX2_EXPORT _fcc_big_cold_far",
                    "_fcc_big_cold_far JSR    _fcc_big_cold",
                    "                RTL"], rows
    # A helper another calls and then shares a data cell with (long_modu
    # JSRs long_divu, then reads the remainder divu left in a data cell).
    assert shared_cell_callees({"_m": ["_d"], "_x": ["_d"]},
                               {"_m": {"rem"}, "_d": {"rem"}, "_x": set()}) == {"_d"}
    assert shared_cell_callees({"_m": ["_d"]}, {"_m": {"a"}, "_d": {"b"}}) == set()
    # The hazard is a NEAR caller: one that is far itself runs in libc.so
    # beside its callee, on the same cells.
    sz = {"_m": 60, "_d": 100}
    c = {"_m": {"rem"}, "_d": {"rem"}}
    assert settle(sz, {}, set(), {"_m": ["_d"]}, c)[0] == ["_d", "_m"]
    assert settle(dict(sz, _m=20), {}, set(), {"_m": ["_d"]}, c)[0] == []
    # A unit that falls through into a helper fcc calls by name (fsub into
    # fadd): exporting it far would leave the inner label with no near body.
    units = {"_fcc_fsub": ["                FGX_SECT _fcc_fsub",
                           "_fcc_fsub       MX      %00",
                           "                EOR     #$8000",
                           "_fcc_fadd       MX      %00",
                           "                RTS", "                FGX_ENDS"],
             "_fcc_fdiv": ["                FGX_SECT _fcc_fdiv",
                           "_fcc_fdiv       MX      %00",
                           "@loop           RTS", "                FGX_ENDS"]}
    assert inner_called(units, ["_fcc_fsub", "_fcc_fdiv"],
                        "  JSR _fcc_fadd\n  JSR _fcc_fdiv\n") == {"_fcc_fsub"}
    assert inner_called(units, ["_fcc_fsub"], "  JSR _fcc_fsub\n") == set()
    print("helper_census: self-test OK")

def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    order, sizes, stackargs, users, banks, deps, dataargs, cells, inner = census()
    pick, excl = settle(sizes, SHARES, stackargs | dataargs | inner, deps, cells)
    dataargs = excl - stackargs - inner
    rows = ["; libc_so_helpers.s -- far entries for the fcc runtime helpers",
            "; libc.so exports (tools/helper_census.py writes this file; do",
            "; not edit it).  Each is JSL-reachable: JSR the helper, RTL.",
            ""] + stubs(pick)
    text = "\n".join(rows) + "\n"
    if "--write" in sys.argv:
        open(OUT, "w").write(text)
    elif "--check" in sys.argv:
        if not os.path.exists(OUT) or open(OUT).read() != text:
            print("helper_census: %s is not the census's choice; run --write" % OUT)
            return 1
    print("%-20s %6s %6s %8s %7s  %s" % ("helper", "bytes", "users", "sys B", "share", "far"))
    for u in sorted(order, key=lambda u: -sizes[u]):
        print("%-20s %6d %6d %8d %6.2f%%  %s" % (
            u, sizes[u], users[u], sizes[u] * banks, SHARES.get(u, 0.0),
            "far" if u in pick else "inner" if u in inner else ("data" if u in dataargs else
                                     ("stack" if u in stackargs else ""))))
    print("%d code banks carry the whole runtime today; far: %d helpers, "
          "%d bytes" % (banks, len(pick), sum(sizes[u] for u in pick)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
