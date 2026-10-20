# Library function-level GC -- implementation plan

> For agentic workers: execute task by task, in order; each task ends green,
> gated and committed.  Checkboxes track progress.  REQUIRED SUB-SKILL:
> superpowers:executing-plans.  fcc and 65816 changes stay with the main
> session.

**Goal:** each tool links only the library functions and data items it can
reach (apple/fgx#457), so the libc time-zone work fits.

**Architecture:** `fcc --sections` wraps each function and data item of a
library pile in inert `FGX_SECT`/`FGX_ENDS` macros; `fgx_gc` computes
reachability from the tool's fixed text over label occurrences and writes
pruned copies that the link files `PUT`.

**Tech stack:** fcc (C), Python 3 (`toolchain/src/ld/`, `tools/ninja/gen.py`),
Merlin32, the MAME harness.

**Spec:** `docs/history/plans/2026-09-25-libc-gc-design.md`.

## Global constraints

- ASCII only; source comments describe the current state only.
- An fcc change quotes the K&R sentence that governs it, or says it has none
  (this is a linkage mechanism, not a language feature: none expected).
- Without `--sections` fcc's output is byte-identical: goldens must not move.
- `FGX_NO_GC=1` must always produce a working, unpruned build.
- Never push without asking; never merge.  Announce every checkout and
  rebuild.  Branch: `feat/457-libc-gc` from `main` `d5b0cb0d8`.
- Commit bodies are changelog; trailers as usual.

## As built (2026-09-25)

Departures from the tasks below, all recorded in their commits:

- **Data sections** are marked where fcc finishes the data segment
  (`data_sections` in `main.c`), not at each global's emit site: the globals
  emitter has many early-`continue` paths, and a column-1 label is fcc's own
  guarantee of where an item starts.
- **fgx_gc does not read comments** as references (the runtime's prose kept 32
  of su's sections alive), and ignores `seg1_layout.s` (an EQU per data label).
- **The templates are unchanged**: gen.py substitutes the `.gc.s` names when it
  instantiates them for the ninja-built tools, so elvis's PUT-list check, the
  shells and `lib/build_common.sh` see them as before.
- **`--root`** was added for tcsh, elvis and bsh, whose code-bank links exist
  only after packing.
- **No checker changed**: stack_measure charges the deepest libc function a
  tool can reach over the whole `libc_c.s`, and a dropped function is one no
  tool can reach.
- **Found along the way:** apple/fgx#497 (malloc grew the break past the bank;
  fixed with 2.11BSD malloc.c:141's wrap check, in its own commit before the
  wiring); apple/fgx#498 (the console login has no utmp record, wuptime red;
  filed, predates the GC).
- **Sharing:** the libc pile files on the root went from 89 classes and
  3,627,933 bytes to 142 classes and 2,953,428 bytes -- more of them, each
  smaller -- so no rounding option was needed.

## Facts measured while planning (2026-09-25)

- su links `libc.s`, `fcc_libc_shims.s`, `libc.sel.s`, `llong.sel.s`,
  `double.sel.s`, `libfgx.s`, `fcc_runtime.s` in seg2 and the data halves in
  seg1 (`tools/su-fgx2/seg{1,2}.link.s`, from `tools/fgx2/*.link.s.in`).
- fcc pile function shape: `FGX2_EXPORT name` (public only), `name ENT`, body,
  `name_FRAMESIZE EQU n`, `name_STKGUARD EQU n` -- e.g. `getopt`,
  `toolchain/lib/libc_c.s:69528` to `:70247`.
- Baselines to beat (seg2 free before time zones): su 8,125 B, syslogd
  10,356, fsck 13,028, reboot 13,553, slogprobe 14,233.
- #457: su's selection is 199 functions, 55,710 bytes, 19,097 unreachable.

---

### Task 1: `fcc --sections`

**Files:** `toolchain/src/cc/` (the function prologue/epilogue emit and the
data-segment emit; find them from where `ENT` and `_FRAMESIZE EQU` are
printed), `toolchain/src/cc/main.c` (flag), `toolchain/lib/macros.s` and
`include/macros.s` (the two macros).

**Produces:** in `.s` and `.data.s`, each function / data item enclosed as

```
                FGX_SECT getopt
                FGX2_EXPORT getopt
getopt            ENT
...
getopt_STKGUARD    EQU     0
                FGX_ENDS
```

- [x] **Step 1: macros.**  In both macros files:

```
* FGX_SECT <label> / FGX_ENDS -- a section of a library pile (fcc
* --sections): what fgx_gc keeps or drops as a unit.  No bytes.
FGX_SECT        MAC
                <<<
FGX_ENDS        MAC
                <<<
```

- [x] **Step 2: failing check.**  `toolchain/tests/sections.sh`: compile
  `lib/libfgx_c/libfgx.c` with and without `--sections`; assert (a) stripping
  every `FGX_SECT`/`FGX_ENDS` line from the `--sections` output gives the
  plain output byte for byte, for `.s` and `.data.s`; (b) every `ENT` label
  and every column-1 data label lies inside exactly one section; (c) sections
  never nest and every `FGX_SECT` has its `FGX_ENDS`.  Run: expect FAIL
  (unknown flag).
- [x] **Step 3: implement** the flag and the two emit sites.  Function: open
  before the `FGX2_EXPORT`/`ENT`, close after the last trailing `EQU` of that
  function.  Data: open at each item's label, close before the next label or
  region header.
- [x] **Step 4:** `sections.sh` green; `./run.sh` (all goldens) unchanged;
  also assemble one tool with a `--sections` libfgx and `cmp` its seg2 against
  the plain build: identical bytes.
- [x] **Step 5:** add `sections.sh` to the gate's fcc stage; gate; commit
  `"feat(fcc): --sections marks each function and data item of a pile"`.

---

### Task 2: `fgx_gc` and its self-test

**Files:** Create `toolchain/src/ld/fgx_gc.py`,
`toolchain/tests/gc/` (the synthetic pile).

**Interfaces:**
- `fgx_gc.py --link seg0.link.s,seg1.link.s,seg2.link.s[,seg3...]
  --prune libc.sel.s,libc.sel.data.s,../../toolchain/lib/libfgx.s,...
  --out-suffix .gc` -- reads every file the link files `PUT` (resolving paths
  relative to each link file), treats `--prune` files as sectioned, writes
  `<stem>.gc.s` beside the TOOL for each, prints a one-line summary (kept /
  dropped sections and bytes of source), exits 2 naming any label that a kept
  section references but only a dropped section defines.
- `fgx_gc.py --self-test`.

- [x] **Step 1: the synthetic pile first** (`toolchain/tests/gc/`): a tiny
  `pile.s`/`pile.data.s` in fcc's `--sections` shape with: `keep_direct`
  (named by the root file), `keep_fptr` (named only in data item
  `tbl` = `DA keep_fptr`, and `tbl` named by `keep_direct`), `shared_static`
  (data item named by `keep_direct` and by `drop_me`), `str1` (string item
  named only by `keep_direct`), `drop_me` (named by nobody), and a root file
  `root.s` naming `keep_direct`.
- [x] **Step 2: the core** (then the CLI around it):

```python
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

def sections(lines):
    """[(label, [lines])] and the unsectioned lines, from FGX_SECT/FGX_ENDS."""
    out, loose, cur = [], [], None
    for ln in lines:
        tok = ln.split()
        if len(tok) >= 2 and tok[0] == "FGX_SECT":
            assert cur is None, "nested FGX_SECT"
            cur = (tok[1], [])
        elif tok[:1] == ["FGX_ENDS"]:
            out.append(cur); cur = None
        elif cur is not None:
            cur[1].append(ln)
        else:
            loose.append(ln)
    assert cur is None, "unterminated FGX_SECT"
    return out, loose

def reach(roots_text, secs):
    """Labels of the sections reachable from the fixed text."""
    body = {lab: "".join(ls) for lab, ls in secs}
    live, todo = set(), [t for t in IDENT.findall(roots_text) if t in body]
    while todo:
        lab = todo.pop()
        if lab in live:
            continue
        live.add(lab)
        todo += [t for t in IDENT.findall(body[lab]) if t in body and t not in live]
    return live
```

  A section is named by ANY of the labels it defines, not only its header
  label: collect each section's column-1 labels and map them all to it
  (a function's local labels, a data item's continuation labels).
- [x] **Step 3: self-test** asserts kept == {keep_direct, keep_fptr, tbl,
  shared_static, str1} and dropped == {drop_me}; then monkeypatches `reach`
  to skip data sections and asserts the self-test now FAILS (the positive
  control).  Run: `python3 toolchain/src/ld/fgx_gc.py --self-test`.
- [x] **Step 4:** add the self-test to `tools/gate.sh`'s checker self-tests;
  commit `"feat(ld): fgx_gc -- reachability over a tool's sectioned piles"`.

---

### Task 3: collect libc and libfgx in the template-built tools

**Files:** `toolchain/Makefile` (libfgx pile and the per-tool select compile
get `--sections`), `toolchain/src/ld/fgx_ar.py` (`select` passes
`--sections` to fcc), `tools/fgx2/seg{1,2}.link.s.in` (PUT the `.gc` copies),
`tools/ninja/gen.py` (a `gc` edge per tool between select and the seg1
assembly; `FGX_NO_GC`), the checkers that read `libc.sel.s`/`libfgx.s`
(`toolchain/src/ld/stack_measure.py` callers, `tools/check_stack_budget.py`,
`tools/check_libc_piles.py`, `tools/stack_baseline.py`), a new test
`src/userland/gcprobe/gcprobe.c` + `tools/mame_test/tests/gcprobe.json`.

- [x] **Step 1: baseline.**  On the current build: `python3
  tools/bank_pressure.py > /tmp/bp.before`; `python3
  tools/check_data_budget.py > /tmp/db.before`; count `/lib/libc.so.*`
  classes on the image.  Record in the commit body.
- [x] **Step 2: gcprobe first.**  A program whose only paths into libc are
  `qsort(a, n, sizeof a[0], cmp)` with a local `cmp` that calls `strcmp`, a
  `signal(SIGALRM, h)` + `alarm(1)` + `pause()` where `h` calls `write`, and
  `atexit(f)` where `f` prints `GC VERDICT PASS`.  Expected on the screen: the
  sorted words, `GC H ok`, `GC VERDICT PASS`.  Green on today's build (it tests
  nothing yet); it must stay green after.
- [x] **Step 3: wire.**  The per-tool `gc` edge runs
  `fgx_gc.py --link seg0.link.s,seg1.link.s,seg2.link.s --prune
  libc.sel.s,libc.sel.data.s,../../toolchain/lib/libfgx.s,
  ../../toolchain/lib/libfgx_data.s` and outputs `libc.sel.gc.s`,
  `libc.sel.gc.data.s`, `libfgx.gc.s`, `libfgx.gc.data.s` in the tool dir;
  the link templates `PUT` those.  With `FGX_NO_GC=1` gen.py emits a copy
  edge instead (the unpruned files under the same names), so the link files
  never change shape.
- [x] **Step 4: build everything** (announce).  Every tool must assemble.  A
  failure is either a `fgx_gc` missing-label report (a scanning gap: fix the
  scanner, add the shape to the synthetic pile) or a merlin32 undefined
  label (the same, caught later).  Never hand-keep a symbol.
- [x] **Step 5: measure** as Step 1; su's seg2 free is the headline.
- [x] **Step 6: run** `gcprobe`, then the gate, then the full MAME suite
  (`run.py --fresh` over all tests; announce, headless).  Any runtime
  difference: rebuild with `FGX_NO_GC=1` to confirm it is GC, then find the
  missed reference.
- [x] **Step 7: commit** `"feat(ld): tools link only the libc and libfgx
  functions they reach"` with the before/after table.

---

### Task 4: the optional archives

**Files:** `tools/fgx2/seg3libs.link.s.in`, `tools/ninja/seg3.py`,
`toolchain/tools/mk_fgxa.sh` (members compiled with `--sections`),
`tools/ninja/gen.py`.

- [x] Extend the `gc` edge's `--link`/`--prune` to seg3 and its selected
  curses/termlib/resolv members; rebuild; every seg3 tool (`worm`, `robots`,
  the curses games, anything with `libs`) assembles; measure seg3; gate;
  commit `"feat(ld): the optional archives are collected too"`.

---

### Task 5: tcsh, elvis, bsh

**Files:** the generators of their link files (`gen_elvis_link.py`, the
shells' link generation in `tools/ninja/gen.py`).

- [x] Read how each builds its banks; route their library inputs through
  `fgx_gc` the same way; rebuild; measure tcsh's banks against its cap; run
  the shell tests and the tcsh-using MAME tests; gate; commit.

---

### Task 6: sharing, documentation, #457

- [x] Count `/lib/libc.so.*` classes and their bytes on the image, before
  (Task 3 Step 1) and after; if disk grew materially, write it up for the maintainer
  with the rounding option -- do not implement it.
- [x] `docs/userland-abi.md` / the linker doc: sections and `fgx_gc`, where
  `FGX_NO_GC` is.  ROADMAP pointer; design status implemented; plan boxes.
- [x] the project notes episode; close #457 with the measured result (note it on the
  issue, do not close #456 separately if it is already closed).
- [x] Report to the maintainer; ask before pushing and opening the MR.
- [x] Then: rebase `feat/libc-time-zones` (and `wip/libc-tz-task3`) onto the
  merged result and resume its Task 3 at the size measurement.
