# Shared libc SP2 step 5: the fcc runtime in libc.so, and what it costs -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each libc.so code bank carries only the fcc runtime helpers its own
functions use; libc.so exports far entries for the big, cold helpers chosen
by a measured rule; and the costs the spec asked to measure -- a getc/putc
byte loop built today and through the new path, and a block static's access
cost against a core one -- are recorded.

**Architecture:** `fgx_libso` splits `fcc_runtime.s` into units in memory --
at each `_fcc_` helper label, a unit that falls through absorbing the next --
without touching the file, which the kernel's `fcc_rt.s`, every link
template and three shell builds also read.  Those units join the string
literals as a bank's *shared* sections: a function is charged, in the bank
that first needs it, for every literal and helper it reaches, transitively.
`tools/helper_census.py` measures each helper (bytes, which programs call
it, how many banks carry it today) against the recorded profile shares and
writes the far-entry stubs of the ones it chooses to
`toolchain/lib/libc_so_helpers.s`, which libc.so's bank 0 carries.  A
`bytecat` program, built as today and statically against libc.so's compile,
times the byte loop in MAME.

**Tech Stack:** Python 3 (`fgx_libso.py`, `fgx_static.py`, the census, the
checker), 65816 assembly (the stubs, generated), C (`bytecat`), Merlin32,
MAME via `tools/mame_test/run.py`.

**Spec:** `docs/history/plans/2026-09-28-shared-libc-sp2-design.md`, sections
6, 7 item 5, 8 ("Measurement") and 10.  Settled here:

- **The runtime is split in memory, not edited.**  Section 6 says each bank
  carries "the helpers its own functions use ... once `fcc_runtime.s` is
  sectioned".  Section markers in the file would reach every consumer --
  `tools/gen_fcc_rt.py` (the kernel's copy), `tools/fgx2/*.link.s.in`,
  `tools/{sh,tcsh}-fgx2`, `tools/elvis-fgx2`, `tools/fas` -- so libc.so's
  link splits it instead, and every other binary is unchanged.  Measured
  (a simulation of this plan's splitter over the real file): 67 units, all
  starting in `MX %00`, the head (EQUs and comments) emitting nothing;
  `_fcc_fsub` falls into `_fcc_fadd`, `_fcc_utof` into `_fcc_ultof`,
  `_fcc_ltof` into `_fcc_ltof_mag`, so each pair is one unit.  The trap
  helpers do not chain: `_fcc_sfoflow` and `_fcc_stkoflow` end in a
  branch-to-self, `_fcc_safepoint` in RTS.  Helpers that CALL others:
  `_fcc_long_mods` -> `_fcc_long_divs`, `_fcc_les16` -> `_fcc_gts16` ->
  `_fcc_lts16`, `_fcc_utof` -> `_fcc_ltof` -> `_fcc_fround`, and the float
  helpers -> `_fcc_fround`.  No helper reads a caller-pushed stack argument
  (no `,S` operand).
- **A far entry's inputs must reach it.**  The 16-bit helpers take their
  right operand in `_fcc_tmp_b`, a cell of the process's DATA
  (`fcc_runtime_data.s`), not in a register or direct page: the caller
  stores it and JSRs.  libc.so's copy of a helper resolves the cell to
  libc's core, so a program storing into its own `_fcc_tmp_b` and JSLing a
  far entry would feed it garbage.  The census therefore keeps near every
  helper that names a data cell compiled code names (`_fcc_tmp_b`,
  `_fcc_q2`/`q3`/`qb2`/`qb3` today) -- scratch cells only the helper uses are
  its own business.  Sub-project 3 can lift this by resolving a program's
  runtime cells to libc.so's core.
- **The dynamic input is the recorded profiles**, as section 6 says: "the
  PC-sample profiles from the 2026-09-27 cache study".  No tool in the tree
  attributes samples across a program's banks (`tools/profile/
  profile_report.py` resolves one bank), and building one is its own work.
  The census carries the recorded shares with their provenance:
  2026-09-27 mixed workload on main 75f05713f -- `_fcc_mods16` 5.0% (in
  libc), `_fcc_ltof_mag` 2.0% (in cmp); 2026-09-10 campperf on main
  4e6388f12 -- `_fcc_long_mul` 1.92%, `_fcc_long_shr` 0.99%,
  `_fcc_long_shl` 0.36%, all of `fcc_rt.s` 5.26%.
- **The rule** (section 6: "the big, cold helpers"): export a far entry for
  a helper of at least 48 bytes with no recorded share of 0.1% or more, not
  reached by a helper that has one, and taking no input through a data
  cell.  A
  far call costs about 14 cycles more than a near one (section 6), which a
  helper at 1% of the run pays on every call; a cold one does not show.
  Section 6 expected long multiply to move; it is 1.92% of a measured run,
  so the rule keeps it near.
- **The program side** (calling the far entries) is sub-project 3's link
  mode, as section 6 says; this step delivers the exports and the list, and
  checks each stub's shape on the host.
- **Per-access cost** is computed from the code fcc emits for each access,
  with cycle counts read from the 65816 documentation, and says so; the
  byte loop is measured.  It copies `/bin/sh`, 96 KB, not the spec's 64 KB,
  and the timed command includes the `cmp` that proves the copy (another
  192 KB read), which dilutes the ratio between the two builds but leaves
  their difference exact.

## Global Constraints

- ASCII only; comments describe the current state; commit bodies
  informational, ending with
- `fcc_runtime.s` is not edited; every binary other than libc.so and the
  fgx_static links is unchanged (the gate proves it).
- Every bank still assembles to exactly the size its sections measured.
- The measurements are not tests: their manifests are not in the gate.
  MAME runs headless (`run.py`); a frames number is comparable only within
  one `FGX_MAME_PRIMARY` and is `frame - paste_frame` from `dump.json`.
- Branch `feat/shared-libc`, not pushed; announce every rebuild and MAME run.

## Review Focus

1. A helper reached only through another helper (`_fcc_long_mods` calls
   `_fcc_long_divs`) -- the bank must carry both, or the bank fails to
   assemble (Task 1: the closure is transitive; the self-test has a
   two-level chain and checks the real `long_mods` -> `long_divs`).
2. A helper reached only from bank 0's fixed files -- bank 0 must carry it
   before any function is packed.  Today libc's hand-written files call no
   runtime helper (their `_fcc_ll_*`/`_fcc_d*` are their own), so bank 0's
   starting set is EMPTY until Task 3's far stubs join it; do not debug an
   empty `pre0` in Task 1.
3. A fall-through chain split across banks -- impossible by construction
   (one unit), and the self-test checks the merge on the real file.
4. A far stub whose helper is not in bank 0 -- the stub is in bank 0, so the
   closure puts the helper there too; the checker checks every stub's bytes
   (Task 3).
5. Two byte-loop timings from runs under different input modes -- both
   manifests fix `primary_input` and are otherwise identical (Task 4).

---

### Task 1: each libc.so bank carries the helpers it uses

**Files:**
- Modify: `toolchain/src/ld/fgx_libso.py`
- Modify: `toolchain/src/ld/fgx_static.py`

**Interfaces:**
- Produces: `runtime_units(lines) -> (head rows, {unit: rows}, [unit])`
  (each unit's rows wrapped in `FGX_SECT <unit>` / `FGX_ENDS`);
  `shared_owner(units, shared) -> {label: unit}`;
  `shared_refs(units, names, own) -> {name: sorted [shared unit]}`
  (transitive); `pack(..., pre=())` and `pack_min(..., pre=())` start bank
  0 holding `pre`.  Banks PUT `rt_head.s` (the runtime's EQU and comment
  rows; zero bytes) instead of `fcc_runtime.s`.

- [ ] **Step 1: Write the failing self-test** (in `fgx_libso.self_test`):

```python
    rt = ["; head comment", "_FCC_X          EQU     3",
          "_fcc_a          MX      %00", "                JSR     _fcc_b",
          "                RTS",
          "_fcc_b          MX      %00", "                LDA     #_FCC_X",
          "                JSR     _fcc_c", "                RTS",
          "_fcc_c          MX      %00", "                PHA",
          "_fcc_d          MX      %00", "                PLA", "                RTS"]
    head, ru, ro = runtime_units(rt)
    assert ro == ["_fcc_a", "_fcc_b", "_fcc_c"], ro
    assert "_FCC_X          EQU     3" in head
    assert ru["_fcc_c"][0].split() == ["FGX_SECT", "_fcc_c"]
    assert any(r.startswith("_fcc_d") for r in ru["_fcc_c"])   # c falls into d
    own = shared_owner(ru, ro)
    assert own["_fcc_d"] == "_fcc_c"
    fu = {"f": ["                FGX_SECT f", "f   ENT", "    JSR _fcc_a",
                "    JSR _fcc_d", "    RTL", "                FGX_ENDS"]}
    fu.update(ru)
    assert shared_refs(fu, ["f"], own) == {"f": ["_fcc_a", "_fcc_b", "_fcc_c"]}
    got = pack({"f": 10}, {"f": []}, {"_fcc_a": 5}, [20], pre={"_fcc_a"})
    assert got[1] == [{"_fcc_a"}] and got[2] == [5], got
    real = runtime_units(open(RUNTIME).read().split("\n"))
    assert "_fcc_fadd" not in real[1] and any(
        r.startswith("_fcc_fadd") for r in real[1]["_fcc_fsub"])
    assert not any(r.split()[:1] == ["_fcc_stkoflow"] for r in real[0])
    assert len(real[2]) == 67, len(real[2])
    rown = shared_owner(real[1], real[2])
    rdeps = shared_refs(real[1], real[2], rown)
    assert rdeps["_fcc_long_mods"] == ["_fcc_long_divs"], rdeps["_fcc_long_mods"]
```

Run: `cd toolchain && python3 src/ld/fgx_libso.py --self-test`
Expected: FAIL -- `NameError: name 'runtime_units' is not defined`.

- [ ] **Step 2: Implement.**  Add to `fgx_libso.py`:

```python
LEAVES = ("RTS", "RTL", "JMP", "JML", "BRA", "BRL")
RT_LABEL = re.compile(r"^(_fcc_[A-Za-z0-9_]+)(\s|$)")


def _op(row):
    """A row's operation, or None for a blank, comment or label-only row."""
    s = fgx_gc.COMMENT.sub("", row).rstrip()
    if not s.strip() or s.lstrip()[0] in ";*":
        return None
    t = s.split()
    if row[0] not in " \t":
        t = t[1:]
    return t[0].upper() if t else None


def runtime_units(lines):
    """fcc_runtime.s as sections, split in memory (the file is shared with
    the kernel's fcc_rt.s and every link template, so it carries no
    markers).  A unit starts at a column-1 _fcc_ label and runs to the
    next; one whose last instruction does not leave (RTS, RTL, JMP, JML,
    BRA, BRL) falls into the next, so the two are one unit.  EQU rows, and
    everything before the first label, are the head every bank PUTs."""
    head, units, order, cur = [], {}, [], None
    for ln in lines:
        op = _op(ln)
        if op in ("EQU", "="):
            head.append(ln)
            continue
        m = RT_LABEL.match(ln)
        if m:
            last = [o for o in map(_op, units[cur]) if o] if cur else []
            if cur is None or (last and last[-1] in LEAVES):
                cur = m.group(1)
                units[cur] = ["                FGX_SECT %s" % cur]
                order.append(cur)
        (units[cur] if cur else head).append(ln)
    for u in order:
        units[u].append("                FGX_ENDS")
    return head, units, order


def shared_owner(units, shared):
    """{label: the shared unit that defines it}."""
    own = {}
    for s in shared:
        for lab in fgx_gc.defined_labels(units[s]) | {s}:
            own[lab] = s
    return own


def shared_refs(units, names, own):
    """{name: every shared unit it reaches, directly or through another}."""
    def direct(n):
        return {own[t] for t in fgx_gc.IDENT.findall(fgx_gc.code_of(units[n]))
                if t in own and own[t] != n}
    out = {}
    for n in names:
        seen, todo = set(), list(direct(n))
        while todo:
            s = todo.pop()
            if s not in seen:
                seen.add(s)
                todo += direct(s)
        out[n] = sorted(seen)
    return out
```

  `pack(sizes, refs, lsizes, budgets, pre=())`: start with
  `held[0] = set(pre)` and `free[0] -= sum(lsizes[l] for l in pre)`
  (return None if that is negative).  `pack_min(..., orphans=(), pre=())`
  passes `pre` through.  In `build`, AFTER the two lines that derive
  `funcs` and `lits` from `order` (fgx_libso.py `funcs = [n for n in order
  if not LIT.match(n)]` / `lits = ...`; the same pair in fgx_static.py) and
  BEFORE `measure` -- added earlier, the runtime units would be packed as
  functions, once each in one bank, and every other bank would fail its
  size check:

```python
    rt_head, rt_units, rt_order = runtime_units(open(RUNTIME).read().split("\n"))
    with open(os.path.join(d, "rt_head.s"), "w") as f:
        f.write("\n".join(rt_head) + "\n")
    units.update(rt_units)
    order += rt_order
    shared = lits + rt_order
    own = shared_owner(units, shared)
    bank0_text = "\n".join(open(p).read() for p in BANK0)   # empty closure today
    pre0 = shared_refs({"bank0": bank0_text.split("\n"), **units}, ["bank0"],
                       own)["bank0"]
```

  and use `shared` where `lits` was passed to `measure` (its links PUT
  `rt_head.s` instead of `RUNTIME`), `refs = shared_refs(units, funcs,
  own)`, `pack_min(..., pre=pre0)`, and PUT `"rt_head.s"` instead of
  `RUNTIME` in the `ov0`, `ovn` and bank links.  `ov0`/`ovn` then measure
  only the fixed files; assert `ovn == 0` ("the runtime head emits no
  bytes").  `bank_rows` already copies every held shared unit in `order`
  and strips exports only from literals.  `fgx_static.build` takes the same
  changes for its libc banks (its segment 0 keeps the whole `RUNTIME`:
  the program's own code near-JSRs helpers there).

- [ ] **Step 3: Run.**  Announce: "rebuilding libc.so and the libcso probe".

Run: `cd toolchain && python3 src/ld/fgx_libso.py --self-test && python3 src/ld/fgx_static.py --self-test && make libc_so 2>&1 | tail -1 && python3 ../tools/libc_so_check.py && python3 tests/libso/test_libso.py | tail -1`
Expected: self-tests OK; the `libc.so:` line with smaller bank totals than
step 4's (65535, 65535, 41640); the checker clean; `libso checks passed`.
Record the new bank sizes.

Run: `cd .. && ninja > /dev/null && python3 tools/mame_test/run.py libcso libcsofull`
Expected: `2 passed, 0 failed`.

- [ ] **Step 4: Commit.**

```bash
git add toolchain/src/ld/fgx_libso.py toolchain/src/ld/fgx_static.py
git commit -m "feat(ld): each libc.so bank carries only the fcc helpers it uses

fgx_libso splits fcc_runtime.s into units in memory -- the file also feeds
the kernel's fcc_rt.s and every link template, so it carries no markers --
at each _fcc_ label, a unit that falls through absorbing the next (fsub
into fadd, utof into ultof, ltof into ltof_mag, the three trap helpers).
The units join the string literals as a bank's shared sections: a function
is charged, in the bank that first needs it, for every helper it reaches,
through other helpers too, and bank 0 starts with the ones libc's
hand-written code calls.  <bank sizes before -> after>.

```

---

### Task 2: the helper census and its list

**Files:**
- Create: `tools/helper_census.py`
- Create (generated, tracked): `toolchain/lib/libc_so_helpers.s`
- Modify: `toolchain/src/ld/fgx_libso.py` (`core_link(d)`, factored out of
  `build`)

**Interfaces:**
- Consumes: `fgx_libso.runtime_units`, `fgx_libso.shared_owner`,
  `fgx_libso.shared_refs`, `fgx_libso.write_units`, `fgx_libso.write_link`,
  `fgx_libso.run_merlin`, `fgx_libso.section_sizes`, and
  `fgx_libso.core_link(d) -> (core size, core base)`: `build`'s own steps --
  split `lib/libc_so_data.s` into `core.s`/`tmpl.s` (with `_libc_blktab`),
  assemble the core at 0 and again at `HEAP_LIM - size`, and write
  `d/core_layout.s` -- moved into a function `build` now calls.  The
  runtime names ~50 cells of `fcc_runtime_data.s`, so no link of it
  assembles without that layout.
- Produces: `helper_census.py [--write | --check | --self-test]`;
  `choose(sizes, shares, stackargs, deps) -> sorted [helper]` (`deps`:
  `fgx_libso.shared_refs` over the units -- a helper a hot helper reaches
  is hot too);
  `stubs(names) -> [rows]`, one per helper:
  `FGX2_EXPORT <h>_far` / `<h>_far JSR <h>` / `RTL`.

- [ ] **Step 1: The self-test first.**

```python
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
    print("helper_census: self-test OK")
```

Run: `python3 tools/helper_census.py --self-test`
Expected: FAIL (file missing / `NameError`).

- [ ] **Step 2: Implement.**  First move `build`'s core steps into
  `fgx_libso.core_link(d)` (no behaviour change: `make libc_so` must give a
  byte-identical `lib/libc.so.1.0` -- `cmp` it against a copy taken before).
  Then:

```python
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
reads no caller-pushed stack argument, and takes no input through a data
cell -- a cell compiled code names, such as _fcc_tmp_b, would be libc.so's
copy in the helper and the program's copy in the caller.

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
# Recorded PC-sample shares, percent of the run (the project notes group fgx):
#   2026-09-27 mixed workload (ls -l, wc, grep, od -c, cmp), main 75f05713f
#   2026-09-10 campperf five-exec workload, main 4e6388f12
SHARES = {"_fcc_mods16": 5.0, "_fcc_ltof": 2.0, "_fcc_long_mul": 1.92,
          "_fcc_long_shr": 0.99, "_fcc_long_shl": 0.36}


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
    dataargs = {u for u in order if shared_cells & set(
        fgx_gc.IDENT.findall("\n".join(code_rows(u))))}
    own = fgx_libso.shared_owner(units, order)
    users = {u: 0 for u in order}
    # Banks that carry the whole runtime today: every CODE segment, plus one
    # per distinct shared pile (a LIBCREF names a pile class, not a copy).
    banks = len(glob.glob(os.path.join(ROOT, "build", "piles", "libc.so.*")))
    for m in glob.glob(os.path.join(ROOT, "tools", "*-fgx2", "*.json")):
        try:
            segs = json.load(open(m)).get("segments", [])
        except (ValueError, OSError):
            continue
        banks += sum(1 for s in segs if s.get("kind") == "CODE")
        own_code = [p for p in glob.glob(os.path.join(os.path.dirname(m), "*.s"))
                    if not p.endswith((".link.s", "_layout.s", ".gc.s", ".sel.s",
                                       ".data.s"))]
        seen = set()
        for p in own_code:
            seen |= {own[t] for t in fgx_gc.IDENT.findall(open(p, errors="replace").read())
                     if t in own}
        for u in seen:
            users[u] += 1
    deps = fgx_libso.shared_refs(units, order, own)
    return order, sizes, stackargs | dataargs, users, banks, deps, dataargs


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    order, sizes, stackargs, users, banks, deps, dataargs = census()
    pick = choose(sizes, SHARES, stackargs, deps)
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
            "far" if u in pick else ("data" if u in dataargs else
                                     ("stack" if u in stackargs else ""))))
    print("%d code banks carry the whole runtime today; far: %d helpers, "
          "%d bytes" % (banks, len(pick), sum(sizes[u] for u in pick)))
    return 0
```

  Note `SHARES` keys are unit names: `_fcc_ltof_mag`'s share belongs to the
  `_fcc_ltof` unit it sits in.

- [ ] **Step 3: Run it and write the list.**

Run: `python3 tools/helper_census.py --self-test && python3 tools/helper_census.py --write && python3 tools/helper_census.py --check && cat toolchain/lib/libc_so_helpers.s | head -20`
Expected: the census table (every helper, its bytes, users, the bytes all
banks spend on it today, its share, far / data / stack / near) and the
file.  A simulation of this rule before the data-cell filter picked 14
(2,435 bytes): fsub 483, fdiv 398, fmul 344, long_divs 223, ftol 130, ftoi
122, divs16 121, long_divu 112, ffloor 108, fcmp 106, itof 100, divu16 64,
modu16 64, long_mods 60.  With it, divs16, divu16 and modu16 (they read
`_fcc_tmp_b`) should show "data" and stay near; any other difference from
that list is a finding to explain before committing.  `_fcc_mods16`,
`_fcc_ltof` (and `_fcc_fround`, which it reaches), `_fcc_long_mul`,
`_fcc_long_shr` and `_fcc_long_shl` stay near as hot.  Keep the summary
line for the commit and spec.

- [ ] **Step 4: Commit.**

```bash
git add tools/helper_census.py toolchain/lib/libc_so_helpers.s toolchain/src/ld/fgx_libso.py
git commit -m "feat(libc): the census chooses which fcc helpers libc.so exports far

tools/helper_census.py measures each fcc runtime helper -- assembled size,
how many programs call it, the bytes every code bank spends on it today --
against the recorded profiles (2026-09-27 mixed workload, 2026-09-10
campperf), and exports far the big, cold ones (spec section 6): at least
48 bytes, no recorded share of 0.1% or more and not reached by a helper
that has one, reading no caller-pushed stack argument and taking no input
through a data cell (the 16-bit helpers' _fcc_tmp_b would be libc.so's
copy in the helper and the program's in the caller).  <summary line>.  Long multiply stays near: it is 1.92% of
a measured run, where a far call's 14 extra cycles would show.

```

---

### Task 3: libc.so carries the far entries

**Files:**
- Modify: `toolchain/src/ld/fgx_libso.py` (`LIBSO_BANK0`)
- Modify: `toolchain/Makefile` (`lib/libc.so.1.0` prerequisites;
  `test-archives` runs `helper_census.py --check`)
- Modify: `tools/libc_so_check.py`

**Interfaces:**
- Produces: libc.so code exports `<helper>_far`, each at bytes
  `20 LL HH 6B` (JSR abs, RTL) in bank 0.

- [ ] **Step 1: The checker first.**  In `check()`:

```python
    far = [e for e in tr["exports"] if e[0].endswith("_far") and e[1] == 0]
    listed = [l.split()[1] for l in open(os.path.join(TC, "lib",
              "libc_so_helpers.s")) if l.split()[:1] == ["FGX2_EXPORT"]]
    if sorted(e[0] for e in far) != sorted(listed):
        errs.append("far helper exports %s differ from libc_so_helpers.s's %s"
                    % (sorted(e[0] for e in far), sorted(listed)))
    targets = label_addrs(os.path.join(d, "bank0_Output.txt"),
                          {e[0][:-len("_far")] for e in far})
    for name, _k, seg, off in far:
        b = segs[seg][off:off + 4]
        if len(b) < 4 or b[0] != 0x20 or b[3] != 0x6B:
            errs.append("far helper %s is not JSR/RTL (%s)" % (name, b.hex()))
        elif b[1] | b[2] << 8 != targets.get(name[:-len("_far")]):
            errs.append("far helper %s JSRs %#06x, not its helper at %s"
                        % (name, b[1] | b[2] << 8,
                           targets.get(name[:-len("_far")])))
```

  with, beside `parse`:

```python
def label_addrs(listing, names):
    """{label: its address} for the column-1 labels `names' in a listing."""
    out = {}
    for raw in open(listing, errors="replace"):
        parts = [p.strip() for p in raw.split("|")]
        if len(parts) < 8 or "/" not in parts[6]:
            continue
        tok = parts[7].split()
        if tok and tok[0] in names:
            out.setdefault(tok[0], int(parts[6].split()[0].split("/")[1], 16))
    return out
```

  and a fifth control in `self_test()`, before its final print:

```python
    # Control 5: a far entry's export moved one byte off its JSR.
    ex5 = list(tr["exports"])
    i5 = next(i for i, e in enumerate(ex5) if e[0].endswith("_far"))
    ex5[i5] = (ex5[i5][0], 0, ex5[i5][2], ex5[i5][3] + 1)
    t5 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"],
                                tr["templates"], tr["core_base"],
                                tr["core_size"], ex5, tr["blocks"],
                                tr["fixups"])
    assert any("is not JSR/RTL" in e for e in
               check(data[:p["trailer_pos"]] + t5, D)), \
        "a far entry off its JSR was not caught"
```

  (the self-test's print then says five broken copies).

Run: `python3 tools/libc_so_check.py`
Expected: FAIL -- "far helper exports [] differ from libc_so_helpers.s's [...]".

- [ ] **Step 2: Put the stubs in bank 0.**  In `fgx_libso.py`:
  `LIBSO_BANK0 = BANK0 + [os.path.join(LIB, "libc_so_helpers.s")]`, used by
  libc.so's `build` (for `ov0`, bank 0's PUTs and `pre0`) and NOT by
  `fgx_static` (a static program calls its helpers near).  Makefile: add
  `lib/libc_so_helpers.s` to `lib/libc.so.1.0`'s prerequisites and
  `python3 ../tools/helper_census.py --check` to `test-archives`.

- [ ] **Step 3: Run.**

Run: `cd toolchain && make libc_so 2>&1 | tail -1 && python3 ../tools/libc_so_check.py --self-test && python3 ../tools/libc_so_check.py && make test-archives 2>&1 | tail -2`
Expected: clean, with the far exports counted in the export total; the
self-test's five controls fail as they must.

- [ ] **Step 4: Commit.**

```bash
git add toolchain/src/ld/fgx_libso.py toolchain/Makefile tools/libc_so_check.py
git commit -m "feat(libc): libc.so exports far entries for the big, cold fcc helpers

Bank 0 carries libc_so_helpers.s, the census's list, so each far entry and
the helper it JSRs sit in one bank; a program linked against libc.so in
sub-project 3 JSLs them.  libc_so_check holds the exports to the list and
each entry to JSR/RTL, with a control that must fail; make test-archives
fails if the list is not the census's current choice.

```

---

### Task 4: the byte loop, measured

**Files:**
- Create: `src/userland/bytecat/bytecat.c`
- Modify: `tools/ninja/manifest.json` (tool `bytecat`, staged to testbin)
- Modify: `tools/libcso-fgx2/build_libcso.sh` (a `bytecatso` binary)
- Modify: `tools/ninja/gen.py` (`SHELLS` entry `bytecatso`)
- Create: `tools/mame_test/tests/bytecat.json`, `tools/mame_test/tests/bytecatso.json`

- [ ] **Step 1: The program.**  `src/userland/bytecat/bytecat.c`:

```c
/*
 * bytecat -- copy stdin to stdout a byte at a time through getc and putc:
 * shared libc SP2's byte loop (spec section 8, "Measurement"), built once
 * as every program is and once statically against libc's library-mode
 * compile (bytecatso), so the two can be timed on the same input.
 */
#include <stdio.h>

int
main()
{
    int c;

    while ((c = getc(stdin)) != EOF)
        putc(c, stdout);
    return 0;
}
```

- [ ] **Step 2: Both builds.**  manifest.json `tools`: `{"name": "bytecat"}`;
  `staging`: `bin/bytecat.bin` -> `disk_src/testbin/bytecat`,
  `tools/libcso-fgx2/bytecatso.bin` -> `disk_src/testbin/bytecatso`.
  build_libcso.sh: take the source by name (`src=src/userland/libcso/libcso.c`,
  or `src/userland/bytecat/bytecat.c` for `bytecatso`), and
  `bytecatso) extra="" ;;`.  gen.py `SHELLS`: a `bytecatso` entry like
  `libcso`'s, with `gate="src/userland/bytecat"`, `globs=["src/userland/bytecat/*"]`.

- [ ] **Step 3: The two timing manifests**, identical but for the binary:

```json
{
 "name": "bytecat",
 "description": "Shared libc SP2 byte loop: /bin/sh copied through getc/putc by bytecat as every program links libc today.  Timing: frame - paste_frame in dump.json, primary_input inject; compare with bytecatso.  Not in the gate.",
 "command": "/testbin/bytecat < /bin/sh > /tmp/bc; cmp /bin/sh /tmp/bc && echo BC same",
 "primary_input": "inject",
 "serial": true,
 "timeout_s": 300,
 "expect": {"screen_contains": ["BC same"], "screen_lacks": ["PANIC", "BRK"]}
}
```

  (`bytecatso.json`: `"name": "bytecatso"`, `/testbin/bytecatso`, the
  description says "statically against libc's library-mode compile".)

- [ ] **Step 4: Run and read the frames.**  Announce the build and runs.

Run: `python3 tools/ninja/gen.py > /dev/null && ninja > /dev/null && for i in 1 2; do python3 tools/mame_test/run.py --fresh bytecat bytecatso && for n in bytecat bytecatso; do python3 -c "import json; d=json.load(open('/tmp/fgx_test_$n/dump.json')); assert d.get('_exit_reason') == 'prompt', d.get('_exit_reason'); print('$n', d['frame'] - d['paste_frame'])"; done; done`
Expected: both pass ("BC same") both times, each run ended at the prompt
(not the frame cap, which would report the cap), and each binary gives the
same frame count twice -- MAME is deterministic, so a difference means the
measurement is not what it seems.  `--fresh` is required: without it the
second run is a cached verdict that re-reads the first run's dump
(`--no-state` only skips the boot save-state).

- [ ] **Step 5: Per-access cost, computed.**  From `lib/libc_so.s`, take one
  block-static read (the `LDA _libc_blk_<m> / CLC / ADC #off` address and
  the load through it) and one core read (`LDA abs`) as fcc emits them, and
  total their cycles from the 65816 cycle table (gs-mcp: search the IIgs
  docs for the 65816 instruction timing table and cite the page).  State
  the two totals and that they are computed, not measured.

- [ ] **Step 6: Commit** the program, builds and manifests:

```bash
git add src/userland/bytecat/bytecat.c tools/ninja/manifest.json tools/ninja/gen.py \
        tools/libcso-fgx2/build_libcso.sh tools/mame_test/tests/bytecat.json \
        tools/mame_test/tests/bytecatso.json
git commit -m "test(libc): bytecat times the getc/putc byte loop both ways

bytecat copies stdin through getc and putc; bytecatso is the same source
linked statically against libc's library-mode compile.  Copying /bin/sh:
<N> frames today, <M> through the new path (primary_input inject, frame -
paste_frame).  Not in the gate.

```

---

### Task 5: record the step, run the gate

- [ ] **Step 1: The spec.**  Section 6: the runtime is split in memory, each
  bank carries its helpers, and the far list is the census's (bytes, the
  rule, the recorded shares).  Its sentence "The helpers read no
  caller-pushed stack arguments, so the extra return address is harmless"
  gains the caveat: the 16-bit helpers take their right operand in the
  data cell `_fcc_tmp_b`, which a far entry would read from libc.so's core,
  so they stay near until sub-project 3 resolves a program's runtime cells
  to that core.  Section 8's byte loop: `/bin/sh` is 96 KB, and the timed
  command includes the `cmp`.  Section 10: "Step 5 landed <date>" with the
  bank sizes before and after, the census summary, the byte-loop frames and
  the computed per-access cycles; and "SP2 complete: next is sub-project 3
  (the dynamic link mode)".

- [ ] **Step 2: The gate.**  Announce it.

Run: `tools/gate.sh 2>&1 | tail -3`
Expected: `GATE GREEN`.

- [ ] **Step 3: Commit, and the project notes** (`group_id="fgx"`): step 5 landed,
  SUPERSEDES the step 5 NEXT pointer; the census rule and list; the byte
  loop's two numbers.

```bash
git add docs/history/plans/2026-09-28-shared-libc-sp2-design.md
git commit -m "docs(plans): shared libc SP2 step 5 landed

```
