# libc overlay segment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tool whose libc selection exceeds the one 64 KB libc bank links, by
moving the libc members it names into a private overlay segment -- then cron
and crontab, the first two such tools, are ported on it.

**Architecture:** fgx_gc, which already builds the section reference graph of
a tool's libc, splits the live libc code sections into seg2 (shared, unchanged
in kind) and an overlay (private CODE), refuses a split that seg2 would call
into, and writes a 4-byte `FGX2_FARJUMP` thunk for each seg2 routine the
overlay calls.  fgx_ld learns `FGX2_FARJUMP` (a JML resolved like a JSL
FARCALL) and stops counting `LIBC_EXPORT` outside LIBC segments.  gen.py wires
a per-tool manifest key `libc_overlay` into the link.

**Tech Stack:** Python 3 (fgx_gc.py, fgx_ld.py, gen.py), Merlin32 link files,
fcc pile code (unchanged), ninja, MAME headless via tools/mame_test/run.py.

**Spec:** `docs/history/plans/2026-09-27-libc-overlay-design.md`

## Global Constraints

- seg2 stays kind LIBC, shared, and carries ZERO relocations (fgx_ld's LIBC gate).
- A tool without `libc_overlay` links BYTE-IDENTICALLY to before.
- The overlay's unit of declaration is the libc MEMBER (archive `id` == source stem).
- No kernel or loader change.
- ASCII only in every file.  Comments describe the current state only.
- Toolchain-first: fix fcc/libc/fgx_ld, never work around them in a tool.
- Read BSD/K&R before changing behaviour with an upstream counterpart; name the file in the commit.
- Tests are the tail: no new GATE test (the gate has a seconds ratchet); self-tests and a smoke manifest outside the gate only.
- MAME runs headless via `python3 tools/mame_test/run.py` only.
- Announce every checkout/rebuild of the tree.  Never self-merge; ask before pushing.

## Review Focus

- A member named in `libc_overlay` that the tool does not select at all -- expect a refusal naming it, not a silent no-op.
- A libc function reached ONLY through a function pointer stored in libc data (a table) whose member is overlaid -- expect it to link and run (data-segment pointers resolve globally), not a refusal and not a thunk.
- A seg2 routine the overlay calls that is itself `static` in its member -- expect a thunk to its mangled exported name, and a working call.
- A tool with BOTH `libs` (seg3) and `libc_overlay` -- expect both segments present and the manifest segment order valid.
- `FGX_NO_GC=1` (fgx_gc `--copy`) with `libc_overlay` set -- expect a clear refusal (a copy cannot partition), not a broken link.

Each line's test lives in the task that owns the code: lines 1-3 in Task 2's
self-test, line 4 in Task 3's generator check, line 5 in Task 2.

---

## File Structure

| File | Responsibility |
|---|---|
| `toolchain/lib/macros.s` | `FGX2_FARJUMP` macro (JML placeholder) |
| `toolchain/src/ld/fgx_ld.py` | resolve/patch/reloc FARJUMP; LIBC_EXPORT only in LIBC segments |
| `toolchain/tests/ld/test_farjump.py` | hermetic tests for both fgx_ld changes |
| `toolchain/src/ld/fgx_gc.py` | the partition, the closure check, the two outputs, the thunk file |
| `toolchain/tests/gc/ovl/*` | overlay self-test fixture |
| `tools/fgx2/segovl.link.s.in` | the overlay segment's link template |
| `tools/ninja/gen.py` | `libc_overlay` key -> link files, manifest, ninja edges |
| `tools/ninja/manifest.json` | cron and crontab entries |
| `src/userland/cron/*`, `src/userland/crontab/*` | the port (already laid out, untracked) |
| `docs/fgx2-linker.md` | the overlay documented where the linker is |

---

### Task 1: fgx_ld -- `FGX2_FARJUMP`, and `LIBC_EXPORT` only in LIBC segments

**Files:**
- Modify: `toolchain/lib/macros.s` (after `FGX2_FARCALL`, ~line 721)
- Modify: `toolchain/src/ld/fgx_ld.py` (`scan_listing` ~406-520, its call ~763, FARCALL patch loop ~931)
- Create: `toolchain/tests/ld/test_farjump.py`
- Modify: `toolchain/Makefile` (test target, ~line 207)

**Interfaces:**
- Produces: macro `FGX2_FARJUMP <name>` (4 bytes, `$5C 00 00 00`); `scan_listing(path, n_segs, libc=False)`.

- [ ] **Step 1: Write the failing test** -- `toolchain/tests/ld/test_farjump.py`, in `test_weak_strong.py`'s hermetic style (synthetic segments and Merlin -V listing rows, no merlin32):

```python
#!/usr/bin/env python3
"""test_farjump.py -- fgx_ld: FGX2_FARJUMP, and LIBC_EXPORT's scope.

  farjump_resolves     a JML placeholder resolves like a FARCALL: linked
                       when the target is exported ...
  farjump_unresolved   ... and REFUSED when it is not (today's fgx_ld counts
                       the row, resolves nothing, and ships $000000).
  libc_export_in_code  a LIBC_EXPORT row in a CODE segment is not an export:
                       a FARCALL binds to the LIBC segment's definition.
  libc_export_counts   that row still counts toward its file's
                       FGX2_RELOC_COUNT (the link would die otherwise).
Run: python3 tests/ld/test_farjump.py
"""
import json, os, subprocess, sys, tempfile

LD = os.path.join(os.path.dirname(__file__), "..", "..", "src", "ld", "fgx_ld.py")
JML = bytes([0x5C, 0x00, 0x00, 0x00])
JSL_RTS = bytes([0x22, 0x00, 0x00, 0x00, 0x60])
LEAF = bytes([0xEA, 0xEA, 0x6B])      # NOP NOP RTL: the export sits at +2


def row(n, src, off, text, typ="Macro"):
    return (f" {n} |  1      {src}    1 | {typ:<11} | 00 |"
            f"         |    0 | 00/{off:04X}               | {text}\n")


def link(d, segs):
    m = {"output": "out", "format": "FGX3", "n_data_segment": 1,
         "entry_offset": 0, "flags": 0, "stack_frames": [], "segments": []}
    for i, (kind, data, rows) in enumerate(segs):
        open(os.path.join(d, f"s{i}"), "wb").write(data)
        open(os.path.join(d, f"s{i}.lst"), "w").write("".join(rows))
        m["segments"].append({"bin": f"s{i}", "listing": f"s{i}.lst",
                              "kind": kind, "bss": 0})
    open(os.path.join(d, "m.json"), "w").write(json.dumps(m))
    return subprocess.run([sys.executable, LD, os.path.join(d, "m.json"),
                           "--pile-dir", d, "-v"],
                          capture_output=True, text=True)


def main():
    fails = 0
    with tempfile.TemporaryDirectory() as d:
        # seg0: a thunk `leaf FGX2_FARJUMP leaf`; seg1 data; seg2 LIBC exports leaf
        r = link(d, [
            ("CODE", JML, [row(1, "t.s", 0, "leaf FGX2_FARJUMP leaf"),
                           row(2, "t.s", 0, "FGX2_RELOC_COUNT 1")]),
            ("DATA", b"\x00\x00", []),
            ("LIBC", LEAF, [row(1, "p.s", 2, "LIBC_EXPORT leaf"),
                            row(2, "p.s", 0, "FGX2_RELOC_COUNT 1")]),
        ])
        if r.returncode != 0:
            print("FAIL farjump_resolves:", r.stderr.strip()[-300:]); fails += 1
        r = link(d, [
            ("CODE", JML, [row(1, "t.s", 0, "leaf FGX2_FARJUMP leaf"),
                           row(2, "t.s", 0, "FGX2_RELOC_COUNT 1")]),
            ("DATA", b"\x00\x00", []),
            ("LIBC", LEAF, [row(1, "p.s", 2, "LIBC_EXPORT other"),
                            row(2, "p.s", 0, "FGX2_RELOC_COUNT 1")]),
        ])
        if r.returncode == 0 or "unresolved" not in r.stderr:
            print("FAIL farjump_unresolved: linked with no 'leaf' anywhere")
            fails += 1
        # seg0 calls getpid; seg3 (CODE) has a LIBC_EXPORT getpid copy;
        # seg2 (LIBC) has the real one.  Must bind to seg2, not die "multiple".
        r = link(d, [
            ("CODE", JSL_RTS, [row(1, "c.s", 0, "FGX2_FARCALL getpid"),
                               row(2, "c.s", 0, "FGX2_RELOC_COUNT 1")]),
            ("DATA", b"\x00\x00", []),
            ("LIBC", LEAF, [row(1, "p.s", 2, "LIBC_EXPORT getpid"),
                            row(2, "p.s", 0, "FGX2_RELOC_COUNT 1")]),
            ("CODE", LEAF, [row(1, "q.s", 2, "LIBC_EXPORT getpid"),
                            row(2, "q.s", 0, "FGX2_RELOC_COUNT 1")]),
        ])
        if r.returncode != 0:
            print("FAIL libc_export_in_code / libc_export_counts:",
                  r.stderr.strip()[-300:]); fails += 1
    print("test_farjump: %s" % ("FAILED" if fails else "ok"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd toolchain && python3 tests/ld/test_farjump.py`
Expected: `FAIL farjump_unresolved` (an unknown FGX2_* row is counted but never resolved, so the link succeeds with a $000000 operand) and `FAIL libc_export_in_code` (`symbol 'getpid' defined by multiple segments` -- the CODE copy counts as strong).

- [ ] **Step 3: Add the macro** -- `toolchain/lib/macros.s`, directly after `FGX2_FARCALL`'s `<<<`:

```
;------------------------------------------------------------------------------
; FGX2_FARJUMP <name> - cross-bank JUMP to a routine the linker resolves
; GLOBALLY, as FGX2_FARCALL resolves a call.  Emits `JML $000000'; fgx_ld
; patches the operand offset (+1,+2) and emits a bank reloc (+3).  It pushes
; nothing: the libc overlay's thunks (fgx_gc --overlay) are reached by a pile
; call that has already built the JSL-shaped frame the target's RTL returns
; through.
;
; Params:
;   ]1  routine name (must match an FGX2_EXPORT in some segment)
;------------------------------------------------------------------------------
FGX2_FARJUMP    MAC
                JML     $000000                 ; LL,HH,BB PATCHED by linker
                <<<
```

- [ ] **Step 4: Teach fgx_ld** -- in `scan_listing`, give it the segment's kind and record FARJUMPs with FARCALLs:

```python
def scan_listing(path, n_segs, libc=False):
```

replace the export arm:

```python
        if macro_name in ("FGX2_EXPORT", "LIBC_EXPORT"):
            # LIBC_EXPORT is the shared-libc pile's self-defined twin of
            # FGX2_EXPORT, and it is an export only IN the pile: a private
            # copy of libc.s (the libc overlay carries one for its near
            # references) must not re-export the pile's names, or they would
            # bind as strong definitions over the LIBC segment's.
            if len(args) < 1 or not args[0]:
                die(f"{path}: {macro_name} missing symbol name (addr {addr:#06x})")
            if macro_name == "LIBC_EXPORT" and not libc:
                continue
            name = args[0]
            if name in exports:
                die(f"{path}: {macro_name} '{name}' duplicated "
                    f"(first at {exports[name]:#06x}, again at {addr:#06x})")
            exports[name] = addr
            continue
```

and beside the `FGX2_FARCALL` arm:

```python
        if macro_name in ("FGX2_FARCALL", "FGX2_FARJUMP"):
            # Cross-bank call (JSL) or jump (JML), GLOBAL resolution.  The
            # two share an operand layout, so one list and one patch loop.
            if len(args) < 1 or not args[0]:
                die(f"{path}: {macro_name} at {addr:#06x} missing symbol name")
            farcalls.append((addr, args[0]))
            continue
```

(delete the old single-name `FGX2_FARCALL` arm).  At the call site (~763):

```python
            scan = scan_listing(listing_path, n_segs,
                                libc=s.get("kind") in LIBC_KINDS)
```

The patch loop needs no change: a JML's operand is laid out as a JSL's (+1,+2
offset, +3 bank), and the reloc kind stays `"farcall"`.

- [ ] **Step 5: Run the new test and the existing ld tests**

Run: `cd toolchain && python3 tests/ld/test_farjump.py && python3 tests/ld/test_weak_strong.py && python3 tests/ld/test_d1_gate.py && python3 tests/ld/test_libc_archive.py && python3 tests/ld/test_asm_archive.py`
Expected: `test_farjump: ok` and every existing test passing unchanged.

- [ ] **Step 6: Add the test to the Makefile's test target** (beside `python3 tests/ld/test_asm_archive.py`):

```
	python3 tests/ld/test_farjump.py
```

- [ ] **Step 7: Prove byte identity** -- rebuild everything and compare every binary with main's.

Announce: "Rebuilding the tree on feat/libc-overlay."
Run: `git stash -u -- toolchain && ninja && shasum bin/*.bin disk_src/lib/modules/* > <scratch> && git stash pop && ninja && shasum bin/*.bin disk_src/lib/modules/* > <scratch> && diff <scratch> <scratch> && echo IDENTICAL`
Expected: `IDENTICAL` (no tool uses FARJUMP yet, and no CODE segment carries a LIBC_EXPORT today).  If the stash approach trips the stale-fcc trap (memory: "a before/after needs two different builds"), build the before set on a clean `git worktree` of main instead.

- [ ] **Step 8: Commit**

```bash
git add toolchain/lib/macros.s toolchain/src/ld/fgx_ld.py toolchain/tests/ld/test_farjump.py toolchain/Makefile
git commit   # feat(ld): FGX2_FARJUMP, and LIBC_EXPORT counts only in a LIBC segment
```

---

### Task 2: fgx_gc -- the overlay partition

**Files:**
- Modify: `toolchain/src/ld/fgx_gc.py`
- Create: `toolchain/tests/gc/ovl/root.link.s`, `root.s`, `ovl.link.s`, `pile.s`, `pile.data.s`, `index.json`

**Interfaces:**
- Consumes: `FGX2_FARJUMP` (Task 1) -- written into the thunk file.
- Produces: CLI `fgx_gc.py --link ... --prune ... --overlay m1,m2 --member-index INDEX --member-prefix FROM:TO`; outputs in `--outdir`: `libc.sel.gc.s` (seg2's sections), `libcovl.gc.s` (the overlay's), `libcovl_thunks.s`.  Python: `run(..., overlay=(), member_index=None, member_prefix=None)` returning `(stats, units, live, part)` where `part = {"seg2": set(keys), "ovl": set(keys), "thunks": [labels]}` (empty sets when no overlay).

The pruned file partitioned is the FIRST `--prune` entry (`libc.sel.s`); its
code sections are the only candidates.  Data sections never move.

- [ ] **Step 1: Write the fixture** -- `toolchain/tests/gc/ovl/`.  Members: `tz` (functions `localtime`, static `_libc_sel_tzload`), `log` (`syslog`, which calls `localtime`), `str` (`strlen`, called by both sides, and its static `_libc_sel_strhelp`, which strlen and localtime both call), `tbl` (`qsort_cmp`, reached only through a data table), and `lonely` (never selected by the tool).

`index.json`:
```json
{"lib": "libc", "cc": "", "aggregate": "",
 "members": [
  {"id": "tz",  "s": "tz.s",  "data_s": "", "imports": [],
   "exports": ["localtime", "_libc_c_tzload"]},
  {"id": "log", "s": "log.s", "data_s": "", "imports": [], "exports": ["syslog"]},
  {"id": "str", "s": "str.s", "data_s": "", "imports": [],
   "exports": ["strlen", "_libc_c_strhelp"]},
  {"id": "tbl", "s": "tbl.s", "data_s": "", "imports": [], "exports": ["qsort_cmp"]},
  {"id": "lonely", "s": "l.s", "data_s": "", "imports": [], "exports": ["lonely_fn"]}
 ]}
```

`pile.s` (the tool's libc.sel.s):
```
                FGX2_MODE 2
                FGX_SECT localtime
                FGX2_EXPORT localtime
localtime       ENT
                PHK
                PEA     localtime_r-1
                PHK
                PEA     _libc_sel_tzload-1
                RTL
localtime_r     PHK
                PEA     localtime_r2-1
                PHK
                PEA     strlen-1
                RTL
localtime_r2    PHK
                PEA     localtime_r3-1
                PHK
                PEA     _libc_sel_strhelp-1
                RTL
localtime_r3    RTL
                FGX_ENDS
                FGX_SECT _libc_sel_tzload
                FGX2_EXPORT _libc_sel_tzload
_libc_sel_tzload ENT
                RTL
                FGX_ENDS
                FGX_SECT syslog
                FGX2_EXPORT syslog
syslog          ENT
                PHK
                PEA     syslog_r-1
                PHK
                PEA     localtime-1
                RTL
syslog_r        RTL
                FGX_ENDS
                FGX_SECT strlen
                FGX2_EXPORT strlen
strlen          ENT
                PHK
                PEA     strlen_r-1
                PHK
                PEA     _libc_sel_strhelp-1
                RTL
strlen_r        RTL
                FGX_ENDS
                FGX_SECT _libc_sel_strhelp
                FGX2_EXPORT _libc_sel_strhelp
_libc_sel_strhelp ENT
                RTL
                FGX_ENDS
                FGX_SECT qsort_cmp
                FGX2_EXPORT qsort_cmp
qsort_cmp       ENT
                RTL
                FGX_ENDS
                FGX2_RELOC_COUNT 7
```

`pile.data.s`:
```
                FGX2_MODE 2
                FGX_SECT cmptab
cmptab          DA      qsort_cmp
                FGX_ENDS
                FGX2_RELOC_COUNT 1
```

`root.s` (the tool's code: calls syslog and strlen, reads cmptab):
```
                FGX2_MODE 2
main            ENT
                FGX2_FARCALL syslog
                FGX2_FARCALL strlen
                LDA     cmptab
                RTL
```

`root.link.s`:
```
                PUT    root.s
                PUT    pile.s
                PUT    pile.data.s
```

`ovl.link.s` (the overlay's link file, PUTting the outputs by name):
```
                PUT    libcovl.gc.s
                PUT    libcovl_thunks.s
```

- [ ] **Step 2: Write the failing self-test cases** -- extend `self_test()` in fgx_gc.py (after the existing checks, before the summary print):

```python
    ovl = os.path.join(gc, "ovl")
    olink = [os.path.join(ovl, "root.link.s"), os.path.join(ovl, "ovl.link.s")]
    idx = os.path.join(ovl, "index.json")
    oprune = ["pile.s", "pile.data.s"]

    def labels(units, keys):
        return {u[1] for p, us in units.items() for i, u in enumerate(us)
                if u[0] == "sect" and (p, i) in keys}

    with tempfile.TemporaryDirectory() as t:
        # 1. a closed list: log + tz move; strlen and its static helper stay
        #    (reached from both); qsort_cmp stays (a data table reaches it);
        #    the thunks are exactly the two seg2 routines the overlay calls,
        #    the static one under its mangled, exported name.
        _, u, _, part = run(olink, oprune, t, overlay=("log", "tz"),
                            member_index=idx,
                            member_prefix=("_libc_c_", "_libc_sel_"),
                            ignore=("seg1_layout.s", "libcovl_thunks.s"))
        ok_split = (labels(u, part["ovl"]) ==
                    {"syslog", "localtime", "_libc_sel_tzload"}
                    and "strlen" in labels(u, part["seg2"])
                    and "qsort_cmp" in labels(u, part["seg2"])
                    and part["thunks"] == ["_libc_sel_strhelp", "strlen"])
        thunks = open(os.path.join(t, "libcovl_thunks.s")).read()
        ok_split = ok_split and "strlen" in thunks and "FGX2_FARJUMP" in thunks
        ovl_src = open(os.path.join(t, "libcovl.gc.s")).read()
        seg2_src = open(os.path.join(t, "pile.gc.s")).read()
        ok_split = (ok_split and "syslog" in ovl_src
                    and "syslog          ENT" not in seg2_src)
    # 2. tz alone is NOT closed: syslog (seg2) calls localtime.
    ok_refuse = expect_die(lambda: run(olink, oprune, tempfile.mkdtemp(),
                           overlay=("tz",), member_index=idx,
                           member_prefix=("_libc_c_", "_libc_sel_"),
                           ignore=("seg1_layout.s", "libcovl_thunks.s")),
                           ["syslog", "localtime", "log"])
    # 3. a member the tool does not select is refused by name.
    ok_unsel = expect_die(lambda: run(olink, oprune, tempfile.mkdtemp(),
                          overlay=("log", "tz", "lonely"), member_index=idx,
                          member_prefix=("_libc_c_", "_libc_sel_"),
                          ignore=("seg1_layout.s", "libcovl_thunks.s")),
                          ["lonely", "not in this tool's libc"])
    # 5. an overlaid function reached only through a libc DATA table moves
    #    with its member and is not refused: data never moves, and a data
    #    pointer resolves globally.
    with tempfile.TemporaryDirectory() as t:
        _, u5, _, p5 = run(olink, oprune, t, overlay=("log", "tz", "tbl"),
                           member_index=idx,
                           member_prefix=("_libc_c_", "_libc_sel_"),
                           ignore=("seg1_layout.s", "libcovl_thunks.s"))
        ok_table = "qsort_cmp" in labels(u5, p5["ovl"])
    # 4. --copy cannot partition.
    ok_copy = expect_die(lambda: run(olink, oprune, tempfile.mkdtemp(),
                         overlay=("log", "tz"), member_index=idx,
                         member_prefix=("_libc_c_", "_libc_sel_"), copy=True),
                         ["--copy", "overlay"])
    for name, flag in (("closed split", ok_split), ("unclosed refused", ok_refuse),
                       ("unselected refused", ok_unsel), ("copy refused", ok_copy),
                       ("data-table member moved", ok_table)):
        if not flag:
            print("fgx_gc: SELF-TEST FAILED: overlay %s" % name)
            return 1
```

with a helper above `self_test`:

```python
def expect_die(fn, words):
    """True if fn() exits through die() with every word in its message."""
    import io
    err, old = io.StringIO(), sys.stderr
    sys.stderr = err
    try:
        fn()
    except SystemExit:
        msg = err.getvalue()
        return all(w in msg for w in words)
    finally:
        sys.stderr = old
    return False
```

and the existing three `run(...)` calls unpacked as four values
(`stats, units, live, _ = run(...)`).

- [ ] **Step 3: Run it to verify it fails**

Run: `python3 toolchain/src/ld/fgx_gc.py --self-test`
Expected: FAIL -- `run() got an unexpected keyword argument 'overlay'`.

- [ ] **Step 4: Implement** -- in fgx_gc.py.  Split `collect` into a graph builder and a reachability walk (the existing `collect` becomes their composition, so the old self-test is unchanged):

```python
def graph(files, order, prune):
    """(units, owner, body, is_data, root_texts) for the sectioned files."""
    units, owner, body, is_data = {}, {}, {}, {}
    roots = []
    for p in order:
        if p not in prune:
            roots.append(code_of(files[p]))
            continue
        units[p] = split_sections(files[p], p)
        for idx, u in enumerate(units[p]):
            if u[0] == "loose":
                roots.append(code_of(u[1]))
                continue
            key = (p, idx)
            body[key] = code_of(u[2])
            is_data[key] = is_data_path(p)
            for lab in defined_labels(u[2]) | {u[1]}:
                if lab in owner and owner[lab] != key:
                    die("%s defined in two sections (%s, %s)"
                        % (lab, owner[lab][0], p))
                owner[lab] = key
    return units, owner, body, is_data, roots


def reach(root_texts, owner, body, is_data, follow_data=True,
          blocked=frozenset()):
    """Section keys reachable from the roots, never ENTERING `blocked'."""
    live, todo = set(), []
    for text in root_texts:
        todo += [owner[t] for t in IDENT.findall(text) if t in owner]
    while todo:
        key = todo.pop()
        if key in live or key in blocked:
            continue
        live.add(key)
        if is_data[key] and not follow_data:
            continue
        todo += [owner[t] for t in IDENT.findall(body[key])
                 if t in owner and owner[t] not in live]
    return live


def collect(files, order, prune, follow_data=True):
    units, owner, body, is_data, roots = graph(files, order, prune)
    return units, reach(roots, owner, body, is_data, follow_data)


def member_map(index_path, prefix):
    """Section label -> libc member id, from the archive index.  A member's
    exports include its statics under the archive's own mangling (`_libc_c_'
    in libc.fgxa); a tool's selection is compiled as libc.sel.c, so they
    carry `_libc_sel_' there -- `prefix' is that (from, to) pair."""
    import json
    frm, to = prefix or ("", "")
    m = {}
    for mem in json.load(open(index_path))["members"]:
        for lab in mem.get("exports", []):
            if frm and lab.startswith(frm):
                lab = to + lab[len(frm):]
            m[lab] = mem["id"]
    return m


def partition(units, owner, body, is_data, roots, live, sel, overlay, mmap):
    """Split `sel''s live code sections into seg2 and the overlay.

    The overlay is the listed members' sections and whatever only they reach;
    seg2 is what the roots reach without entering a listed member.  Refused
    unless it is upward-closed: nothing in seg2 may reference the overlay,
    because seg2 is shared and reloc-free and so cannot find it."""
    def member(key):
        return mmap.get(units[key[0]][key[1]][1], "?")
    code = {k for k in live if k[0] == sel and not is_data[k]}
    have = {member(k) for k in code}
    for m in overlay:
        if m not in have:
            die("libc_overlay: `%s' is in libc_overlay but not in this "
                "tool's libc" % m)
    seeds = {k for k in code if member(k) in overlay}
    seg2 = reach(roots, owner, body, is_data, blocked=seeds)
    ovl = code - seg2
    for k in sorted(seg2):
        if is_data[k]:
            continue
        for t in IDENT.findall(body[k]):
            o = owner.get(t)
            if o in ovl:
                die("libc_overlay is not closed: %s (member %s) references "
                    "%s (member %s), and seg2 cannot reach the overlay; add "
                    "`%s' to libc_overlay"
                    % (units[k[0]][k[1]][1], member(k), t, member(o),
                       member(k)))
    thunks = sorted({t for k in ovl for t in IDENT.findall(body[k])
                     if t in owner and owner[t] not in ovl
                     and not is_data[owner[t]]
                     and units[owner[t][0]][owner[t][1]][1] == t})
    return {"seg2": live - ovl, "ovl": ovl, "thunks": thunks}


def write_split(units, sel, part, outdir):
    """Write the partitioned file twice -- seg2's sections under its usual
    .gc.s name, the overlay's as libcovl.gc.s -- each keeping the file's
    loose rows and lowering its FGX2_RELOC_COUNT by what it dropped; and the
    thunk file."""
    for name, keep in ((gc_name(sel), part["seg2"]), ("libcovl.gc.s", part["ovl"])):
        out, dropped_rows = [], 0
        for idx, u in enumerate(units[sel]):
            if u[0] == "loose":
                out += u[1]
            elif (sel, idx) in keep:
                out += u[2]
            else:
                dropped_rows += fgx2_rows(u[2])
        for i, ln in enumerate(out):
            t = ln.split()
            if t[:1] == ["FGX2_RELOC_COUNT"] and len(t) > 1:
                out[i] = ln.replace(t[1], str(int(t[1]) - dropped_rows), 1)
        with open(os.path.join(outdir, name), "w") as f:
            f.write("\n".join(out))
    rows = ["* GENERATED by fgx_gc --overlay: one FGX2_FARJUMP per seg2 routine",
            "* the libc overlay calls (docs/fgx2-linker.md, libc overlay).",
            "                FGX2_RELOC_COUNT %d" % len(part["thunks"])]
    rows += ["%-15s FGX2_FARJUMP %s" % (t, t) for t in part["thunks"]]
    with open(os.path.join(outdir, "libcovl_thunks.s"), "w") as f:
        f.write("\n".join(rows) + "\n")
```

`run` gains the three arguments and returns `part`:

```python
def run(link, prune, outdir, follow_data=True, ignore=("seg1_layout.s",),
        copy=False, roots=(), overlay=(), member_index=None,
        member_prefix=None):
    base = (os.path.dirname(os.path.abspath(link[0])) if link
            else os.getcwd())
    prune_abs = [os.path.normpath(os.path.join(base, q)) for q in prune]
    if copy:
        if overlay:
            die("--copy cannot partition a libc overlay (FGX_NO_GC=1 with "
                "libc_overlay set)")
        for a in prune_abs:
            with open(os.path.join(outdir, gc_name(a)), "w") as f:
                f.write(open(a).read())
        return {a: (0, 0, gc_name(a)) for a in prune_abs}, {}, set(), {}
    outmap = {gc_name(a): a for a in prune_abs}
    if overlay:
        outmap["libcovl.gc.s"] = prune_abs[0]
    files, order = read_tree(link, ignore, outmap, roots)
    ...   # unchanged through the --prune check
    prune_set = set(prune_abs)
    units, owner, body, is_data, root_texts = graph(files, order, prune_set)
    live = reach(root_texts, owner, body, is_data, follow_data)
    part = {"seg2": set(), "ovl": set(), "thunks": []}
    if overlay:
        mmap = member_map(member_index, member_prefix)
        part = partition(units, owner, body, is_data, root_texts, live,
                         prune_abs[0], set(overlay), mmap)
    stats = write_pruned({p: us for p, us in units.items()
                          if not (overlay and p == prune_abs[0])},
                         live, outdir)
    if overlay:
        write_split(units, prune_abs[0], part, outdir)
    return stats, units, live, part
```

`main` gains the options and passes them:

```python
    ap.add_argument("--overlay", default="",
                    help="comma-separated libc members to move into the "
                    "libc overlay (the first --prune file is split)")
    ap.add_argument("--member-index", help="the libc archive index.json")
    ap.add_argument("--member-prefix", default="_libc_c_:_libc_sel_",
                    help="FROM:TO static-name mangling, archive -> selection")
    ...
    ovl = tuple(x for x in a.overlay.split(",") if x)
    if ovl and not a.member_index:
        ap.error("--overlay needs --member-index")
    stats, _, _, part = run(link, a.prune.split(","), outdir,
                            ignore=tuple(x for x in a.ignore.split(",") if x),
                            copy=a.copy, roots=a.root, overlay=ovl,
                            member_index=a.member_index,
                            member_prefix=tuple(a.member_prefix.split(":", 1)))
    if ovl:
        print("fgx_gc: overlay %d sections, %d thunks"
              % (len(part["ovl"]), len(part["thunks"])))
```

(`stats, _, _ = run(...)` in `main` becomes the four-value form above;
`write_pruned` is unchanged.)

- [ ] **Step 5: Run the self-test**

Run: `python3 toolchain/src/ld/fgx_gc.py --self-test`
Expected: `fgx_gc: self-test ok (...)`.

- [ ] **Step 6: Confirm the collector is unchanged for real tools** -- regenerate one tool's GC output and compare.

Announce: "Rebuilding syslogd's link on feat/libc-overlay."
Run: `cp tools/syslogd-fgx2/libc.sel.gc.s <scratch> && ninja -t clean tools/syslogd-fgx2/libc.sel.gc.s >/dev/null; ninja tools/syslogd-fgx2/libc.sel.gc.s && cmp <scratch> tools/syslogd-fgx2/libc.sel.gc.s && echo SAME`
Expected: `SAME`.  (A single-target `-t clean` is fine; the whole-tree `ninja -t clean` is forbidden.)

- [ ] **Step 7: Commit**

```bash
git add toolchain/src/ld/fgx_gc.py toolchain/tests/gc/ovl
git commit   # feat(ld): fgx_gc --overlay -- the libc overlay partition and its thunks
```

---

### Task 3: the overlay segment in the build

**Files:**
- Create: `tools/fgx2/segovl.link.s.in`
- Modify: `tools/ninja/gen.py` (`covered_tools` ~521, `materialize_links` ~601, the per-tool block ~2080-2240, `rule fgxgc` ~1029)

**Interfaces:**
- Consumes: fgx_gc `--overlay/--member-index` and its outputs (Task 2); `FGX2_FARJUMP` (Task 1).
- Produces: manifest key `"libc_overlay": [member ids]` on a tool entry; per-tool `segovl.link.s`, `segovl`, `segovl.lst`; a CODE segment `segovl` appended to `<tool>_fgx.json`.

- [ ] **Step 1: The template** -- `tools/fgx2/segovl.link.s.in`:

```
*==============================================================================
*  segovl.link.s - @NAME@ LIBC OVERLAY segment (2.11BSD ld -Z for the pile).
*
*  GENERATED by tools/ninja/gen.py from tools/fgx2/segovl.link.s.in -- do NOT
*  edit the copy in tools/@NAME@-fgx2/; edit this template instead.
*
*  The libc members the tool names in `libc_overlay', and what only they
*  reach, moved out of seg2 by fgx_gc --overlay (docs/fgx2-linker.md).  An
*  ordinary CODE segment: private, relocs allowed.  seg2 never calls in here
*  (fgx_gc refuses a list that would); calls OUT go through libcovl_thunks.s,
*  one FGX2_FARJUMP per seg2 routine the overlay calls.
*
*  The pile's near references need their targets in THIS bank, so it carries
*  its own copies of the stateless hand-written files seg2 carries: libc.s
*  (_libc_strerr, and vfork/getpid/setjmp/longjmp called from here run here;
*  its LIBC_EXPORT rows are not exports outside a LIBC segment), the shims,
*  the llong/double runtime selections and fcc_runtime.s.  Data stays in
*  seg1, reached through seg1_layout.s like all cross-segment data.
*==============================================================================
                TYP    $06
                DSK    segovl
                ORG    $0B0000
                MX     %11
SYS_EXIT        EQU    1
SYS_WRITE       EQU    4
SYS_TRAMP       EQU    $000328
LIBC_FAR        EQU    1                        ; far flavor: JSL entry / LIBC_RET=RTL
PF_FD_BUFSZ     EQU    128
                PUT    ../../toolchain/lib/macros.s
                FGX2_MODE 2
                FGX2_RELOC_COUNT 1
                PUT    seg1_layout.s
                PUT    ../../toolchain/lib/libc.s
                PUT    ../../toolchain/lib/fcc_libc_shims.s
                PUT    libcovl.gc.s
                PUT    libcovl_thunks.s
                PUT    llong.sel.s
                PUT    double.sel.s
                PUT    ../../toolchain/lib/fcc_runtime.s
```

- [ ] **Step 2: Read the key** -- in `covered_tools`, beside `seg4_tus`:

```python
            libc_overlay=t.get("libc_overlay", []),
```

- [ ] **Step 3: `materialize_links`** gains `libc_overlay=()` and, after the seg4 block:

```python
    if libc_overlay:
        # The libc overlay (fgx_gc --overlay): 2.11BSD's `ld -Z' for the pile.
        tplo = open(os.path.join(ROOT, "tools/fgx2", "segovl.link.s.in")).read()
        segs["segovl"] = tplo.replace("@NAME@", name)
        manifest = manifest.replace(
            ', "bss": 0 }\n  ]',
            ', "bss": 0 },\n'
            '    { "bin": "segovl", "listing": "segovl.lst", "kind": "CODE", '
            '"bss": 0 }\n  ]')
```

and its call passes `rec.get("libc_overlay", [])`.

- [ ] **Step 4: The ninja edges** -- the `fgxgc` rule gains `$overlay`:

```
rule fgxgc
  command = cd $dir && python3 $$OLDPWD/toolchain/src/ld/fgx_gc.py --link $links --prune $prune $overlay $mode > /dev/null
  description = fgx_gc $dir
```

In the per-tool block, after `gc_prune`:

```python
        ovl = rec.get("libc_overlay", [])
        if ovl and GC_MODE:
            raise SystemExit(f"{name}: libc_overlay cannot build with "
                             f"FGX_NO_GC=1 (a copy cannot partition)")
        gc_ovl = f"{b}/libcovl.gc.s {b}/libcovl_thunks.s" if ovl else ""
        overlay_arg = (
            f"--overlay {','.join(ovl)} "
            f"--member-index $$OLDPWD/toolchain/lib/libc.fgxa/index.json "
            f"--ignore seg1_layout.s,libcovl_thunks.s") if ovl else ""
        if ovl:
            gen |= {f"{b}/libcovl.gc.s", f"{b}/libcovl_thunks.s"}
```

after the seg4 edge:

```python
        if ovl:
            po = static_puts(os.path.join(bdir, "segovl.link.s"), gen)
            lines.append(
                f"build {b}/segovl {b}/segovl.lst: merlin {b}/segovl.link.s | "
                f"{b}/seg1_layout.s {gc_ovl} "
                + "".join(f"{b}/{l}.sel.s " for l in PILE_LIBS)
                + " ".join(po) + "\n"
                f"  dir = {b}\n  link = segovl.link.s\n  seg = segovl")
            link_extra += f" {b}/segovl {b}/segovl.lst"
        else:
            po = []
```

`gc_links` appends `"segovl.link.s"` when `ovl`; `gc_in` includes `po`; the
fgxgc build line's outputs gain `{gc_ovl}` and its variables gain
`  overlay = {overlay_arg}\n`.

- [ ] **Step 5: A generator check for the Review Focus line on seg3 + overlay** -- add to gen.py's existing self-checks, or as a one-off run: a throwaway manifest entry with both `libs` and `libc_overlay` must materialize five segments (`seg0, seg1, seg2, seg3, segovl`) with LIBC not required last (under nine segments).

Run: `python3 - <<'EOF'
import sys; sys.path.insert(0, "tools/ninja"); import gen, json, os
d = gen.materialize_links("ovlcheck", "FGX3", [], ["termlib"], [], [], ["ctime"])
m = json.load(open(os.path.join(d, "ovlcheck_fgx.json")))
print([s["bin"] for s in m["segments"]], [s["kind"] for s in m["segments"]])
EOF
rm -rf tools/ovlcheck-fgx2`
Expected: `['seg0', 'seg1', 'seg2', 'seg3', 'segovl'] ['CODE', 'DATA', 'LIBCREF', 'CODE', 'CODE']`.

- [ ] **Step 6: Byte identity** -- no tool has the key yet, so every binary must be unchanged.

Announce: "Rebuilding the tree on feat/libc-overlay."
Run: `python3 tools/ninja/gen.py && ninja && shasum bin/*.bin disk_src/lib/modules/* > <scratch> && diff <scratch> <scratch> && echo IDENTICAL`
Expected: `IDENTICAL` (`bins.before` from Task 1 Step 7).

- [ ] **Step 7: Commit**

```bash
git add tools/fgx2/segovl.link.s.in tools/ninja/gen.py
git commit   # feat(build): a tool's libc_overlay becomes a private overlay segment
```

---

### Task 4: cron and crontab link on the overlay

**Files:**
- Modify: `tools/ninja/manifest.json` (cron and crontab entries; the saved patch at `docs/history/wip-2026-09-27/cron-manifest.patch` has the rest)
- Add: `src/userland/cron/*`, `src/userland/crontab/*`, `vendor/2.11BSD/usr/usr.sbin/cron/*` (already on disk, untracked)

**Interfaces:**
- Consumes: the `libc_overlay` key (Task 3).

- [ ] **Step 1: Apply the saved manifest entries** and add the key:

Run: `git apply docs/history/wip-2026-09-27/cron-manifest.patch` (untracked; delete it after applying)
Then add `"libc_overlay": ["ctime"]` to both the `cron` and the `crontab` tool entries.

- [ ] **Step 2: Build and read the refusal** -- the expected first answer is fgx_gc naming the members that still call into ctime.

Run: `python3 tools/ninja/gen.py >/dev/null && ninja bin/cron.bin bin/crontab.bin 2>&1 | grep -E "libc_overlay|FAILED|Error"`
Expected: `libc_overlay is not closed: ... (member syslog) references ctime ...; add `syslog' ...` (or strftime).  Add each member the message names, one at a time, until the link completes.  Record the final lists.

- [ ] **Step 3: Measure both banks** -- seg2 and segovl must each be under 65,536 bytes with room.

Run: `for t in cron crontab; do printf "%-8s seg2=%6d segovl=%6d\n" $t $(stat -f %z tools/$t-fgx2/seg2) $(stat -f %z tools/$t-fgx2/segovl); done`
Expected: both segments present, each < 65536.  If seg2 is still over, the Merlin error comes first -- add the heaviest remaining member family (the scanf family: `doscan`, `scanf`, `atof`, `ldexp`) and repeat Step 2.

- [ ] **Step 4: The rest of the build is unchanged**

Run: `ninja && shasum bin/*.bin disk_src/lib/modules/* | grep -v -E "bin/(cron|crontab).bin" > <scratch> && grep -v -E "bin/(cron|crontab).bin" <scratch> | diff - <scratch> && echo IDENTICAL`
Expected: `IDENTICAL`.

- [ ] **Step 5: Commit** (the port's sources, as vendored and laid out, with the manifest entries; the port's own deltas come in Task 5)

```bash
git add tools/ninja/manifest.json src/userland/cron src/userland/crontab vendor/2.11BSD/usr/usr.sbin/cron vendor/2.11BSD/usr/etc/crontab
git commit   # feat(cron): 2.11BSD's cron and crontab build, their libc split by libc_overlay
```

---

### Task 5: the port -- upstream defects, staging, boot

**Files:**
- Modify: `src/userland/cron/entry.c` (the `@` keywords, ~lines 125-160)
- Create: `disk_src/etc/crontab`, `disk_src/var/cron/tabs/.keep` (or the staging idiom syslogd's `/var/run` uses -- read `git show 1a0c8fb89 --stat` first)
- Modify: `disk_src/etc/rc.in` (start cron after syslogd), `tools/fgxfs.py` (`SETUID_FILES` += `/bin/crontab`), `docs/PROVENANCE.md`
- Create: `src/userland/man/pages/cat1/crontab.0`, `cat5/crontab.0`, `cat8/cron.0` (from `examples/2.11BSD/usr/man/cat*/`, vendored in the same commit)

- [ ] **Step 1: The two upstream range defects, own commit.**  `bit_nset(name, start, stop)` sets `start..stop` INCLUSIVE (bitstring.h's loop runs to `_stopbyte` and masks `0xff >> (7 - (stop&7))`).  entry.c passes `(LAST_DOW-FIRST_DOW+1)` = 8 for the day-of-week map, whose `DOW_COUNT` is 8 bits (0..7): bit 8 is the first bit of the NEXT field.  And `@hourly` does `bit_set(e->hour, (LAST_HOUR-FIRST_HOUR+1))`: bit 24 of a 24-bit map -- no hour is set, so an `@hourly` entry never runs.  2.11BSD's and NetBSD 0.9's (`examples/netbsd-0-9/libexec/crond/entry.c:120-144`) are identical; the numeric-field path (`get_list`, `bit_nclear(bits, 0, (high-low))`) shows the intended stop is `high-low`.  Change every `(LAST_DOW-FIRST_DOW+1)` in the `@` block to `(LAST_DOW-FIRST_DOW)`, and `@hourly`'s hour line to `bit_nset(e->hour, 0, (LAST_HOUR-FIRST_HOUR));`.  Commit: `fix(cron): the @ keywords set the ranges they name`.

- [ ] **Step 2: Stage and start it** -- `disk_src/etc/crontab` is 2.11BSD's `usr/etc/crontab` with the lines whose programs FGX lacks removed (`/usr/libexec/atrun`, `/usr/adm/daily|weekly|monthly` -- check each with `ls disk_src/...` first and keep any that exist) and FreeBSD's adjkerntz line added:

```
# 2.11BSD's /etc/crontab, with the lines for programs this system lacks
# removed.  Every half hour from midnight to five, adjkerntz follows a
# daylight-saving change the machine is up across (FreeBSD's entry).
1,31	0-5	*	*	*	root	adjkerntz -a
```

`rc.in` starts `/usr/sbin/cron` -- here `/sbin/cron` -- without `&`, after syslogd, where 2.11BSD's `/etc/rc` starts it (read `examples/2.11BSD/etc/rc` for the position).  `/var/cron` and `/var/cron/tabs` exist at mode 0700 (cron creates them otherwise, noisily).  `/bin/crontab` is setuid root (`SETUID_FILES` in tools/fgxfs.py; 2.11BSD installs it `-m 4111`).

- [ ] **Step 3: Man pages and PROVENANCE** -- the three cat pages copied from `examples/2.11BSD/usr/man/`, vendored under `vendor/2.11BSD/usr/man/`, `tools/check_man_overstrike.py` clean.  PROVENANCE rows for `src/userland/cron/*` and `src/userland/crontab/crontab.c` (upstream `vendor/2.11BSD/usr/usr.sbin/cron/`, the entry.c fix named) and the pages; `python3 tools/check_provenance.py` OK.

- [ ] **Step 4: Commit**: `feat(cron): cron runs at boot, with /etc/crontab and its pages`.

---

### Task 6: on FGX

**Files:**
- Create: `tools/mame_test/tests/cron.json` (not in the gate)

- [ ] **Step 1: The smoke manifest** -- a job one minute out, via crontab(1) from a file, then checks the job ran and crontab -l lists it:

```json
{
 "name": "cron",
 "description": "cron(8) from boot runs a crontab(1) entry within two minutes, and crontab -l lists it.  The libc overlay's first tool: localtime, syslog and the pid-file flock all run from the overlay segment.",
 "command": "echo '* * * * * /bin/date > /tmp/cronran' > /tmp/ct; crontab /tmp/ct; crontab -l; sleep 130; cat /tmp/cronran && echo CRON RAN",
 "timeout_s": 240,
 "expect": {
  "screen_contains": ["* * * * * /bin/date", "CRON RAN"],
  "screen_lacks": ["PANIC", "BRK", "No such file"]
 }
}
```

- [ ] **Step 2: Run it**

Run: `python3 tools/mame_test/run.py cron cloexec flockt`
Expected: `3 passed, 0 failed`.

- [ ] **Step 3: Positive control** -- the same manifest with cron's `rc.in` line removed must fail on `CRON RAN`.  Run once, restore, rebuild.

- [ ] **Step 4: Commit**: `test(cron): a crontab entry runs on FGX`.

---

### Task 7: documentation, gate

**Files:**
- Modify: `docs/fgx2-linker.md` (a "libc overlay" section after "Library selection and GC")
- Modify: `docs/ROADMAP.md` (the clock entry: sub-project 3's cron half done; the overlay under Toolchain / self-host)

- [ ] **Step 1: docs/fgx2-linker.md** -- the mechanism in the spec's words: the key, the partition and its refusal, the thunks, `FGX2_FARJUMP`, LIBC_EXPORT's scope, the private bank and the ROADMAP follow-up.

- [ ] **Step 2: ROADMAP** -- the clock entry says cron is done and adjkerntz -a runs from it; a Toolchain / self-host line for the overlay beside the GC entry.

- [ ] **Step 3: Gate**

Run: `tools/gate.sh`
Expected: `GATE GREEN`.

- [ ] **Step 4: Commit**: `docs: the libc overlay in the linker guide; cron in the roadmap`.

---

## Self-review notes

- Spec 4.1 (declaration) -> Task 3 Step 2 and Task 4 Step 1.  4.2 (partition,
  refusal) -> Task 2.  4.3 (segment) -> Task 3 Step 1.  4.4 (thunks) -> Task 2
  (`write_split`) and Task 1 (macro).  4.5 (fgx_ld) -> Task 1.  4.6 (build) ->
  Task 3.  4.7 (no kernel change) -> nothing to do; Task 6 exercises it.  4.8
  (errors) -> Task 2 (unselected, unclosed, copy), Task 4 Step 3 (seg2 still
  over).  5 (testing) -> Task 2 self-test, Tasks 1/3/4 byte identity, Task 6.
- The spec says the overlay also takes "every selected member that only they
  reach"; the partition does this at SECTION granularity (finer, and still
  closed by the same check).  Noted in `partition`'s docstring.
