# Shared libc SP2 step 4: `_libc_init`, the static link path, and the libcso probe -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A program can be linked statically against libc's library-mode
compile, its startup gives it its own copy of every libc block it reaches,
and a probe proves on the machine that libc works that way: core state,
stateful members, literals, initialised and zeroed statics, fork and vfork,
a signal handler, a libc slice across two code banks, and a clean refusal
when the blocks do not fit.

**Architecture:** `_libc_init` is a new libc member (`libc_c/libc_init.c`,
C): it walks `_libc_blktab` -- per reached member the block cell's address,
a far pointer to the member's template, the block's size -- carves each
block below `HEAP_LIM`, copies the template into it, points the cell at
it, and lowers `HEAP_LIM` so neither the heap nor fork's two ranges lose
it.  libc.so's core carries a full `_libc_blktab` (step 3's link writes it).
A static program gets one from `toolchain/src/ld/fgx_static.py`, which
collects libc's sections the program reaches (fgx_gc, plus a member's
template whenever its cell is live), puts libc's core cells and those
templates in the program's data segment, packs libc's code into banks
behind the program's own (fgx_libso's packer), and enters at a new
`_crt0_libso` (`toolchain/lib/crt0_libso.s`) that calls `_libc_init` and
then jumps to crt0's usual start.  The probe `libcso` is built that way and
run headless in MAME.

**Tech Stack:** C (libc member, probe), 65816 assembly (a 7-row entry
stub), Python 3 (`fgx_static.py`, `fgx_libso.py`, `fgx_ld.py`, the checker,
ninja generator), Merlin32, MAME via `tools/mame_test/run.py`.

**Spec:** `docs/history/plans/2026-09-28-shared-libc-sp2-design.md`, sections
3 ("Static programs", "Startup"), 4, 7 item 4 and 8.  Settled here:

- **Where a static program's core sits.**  Spec section 3 says both "the
  loader has already placed the core image (it is part of the program's data
  segment)" and "core at the top of the data bank".  The loader puts a data
  segment at offset 0 of its bank (`src/kernel/far/loader.s`), so a core at
  the top would need a ~60 KB run of zeros in every static file.  The core
  stays in the data segment where the loader places it; the BLOCKS go at the
  top, below `HEAP_LIM`, which is what fork's `[HEAP_LIM, $FFFF]` range and
  the heap's ceiling need.  A dynamic program's core (sub-project 4) is where
  the binder copies it; `_libc_init` runs the same either way, because every
  core label is a link-time address.
- **The call hook.**  crt0 cannot test for a flag only these links define
  (Merlin32: `DO` on an undefined symbol is an error, measured).  A separate
  entry, `_crt0_libso`, named by the manifest's entry offset, calls
  `_libc_init` and jumps to `_crt0_start`, so crt0 and every other binary
  are unchanged.  `_libc_init` running before crt0's DP seeds is safe:
  `_fcc_dbr` has no reader left (`fcc_runtime.s` `_fcc_bank_for_int` reads
  DBR live), and `_libc_init` has no soft frame.
- **Per-process fixups.**  A static program has none: its data segment is
  per-process, so the loader relocates `stdin`/`stdout`/`stderr` like any
  other pointer.  The fixup list is the binder's (sub-project 4).
- **Pointers into templates.**  Step 3's link refused every pointer into the
  template segment.  The core's `_libc_blktab` points into it by design --
  templates are read-only initial bytes, the same for every process -- so a
  pointer FROM THE CORE into a template is allowed; from code or from a
  template it is still refused.
- **Measurement** (spec section 8's byte loop and per-access cost) moves to
  step 5 with the helper measurement: it needs this step's static path and
  nothing in this step needs it.
- **Code-closure check** ("every member whose code names slot S has S's
  owner in its closure"): `fgx_static` keeps a member's template exactly when
  its cell is reached, and the probe build checks every live cell has a
  table row.

## Global Constraints

- ASCII only; comments describe the current state; commit bodies
  informational, ending with
- A libc change names its BSD counterpart or says there is none, in the
  source and the commit.  `_libc_init` has none: 2.11BSD links libc
  statically and its data is the program's.  K&R A.8.7 is quoted from the
  page where the zeroing is explained.
- Every existing binary is unchanged: crt0_far.s is not edited, and
  `libc_init.c` is an ordinary member the pile archive only selects for a
  program that reaches it.  The gate proves it.
- Fail loudly: `_libc_init` that cannot fit the blocks writes
  `libc: no room for its data` to fd 2 and exits 1 before `main`;
  `fgx_static` dies naming anything it cannot place.
- The probe is not in the gate (spec section 8).  MAME runs headless only
  (`tools/mame_test/run.py`, which sets the dummy video driver).
- Branch `feat/shared-libc`, not pushed; announce every rebuild and every
  MAME run.

## Review Focus

1. A program that reaches no stateful member -- `_libc_blktab` is just its
   end mark, `_libc_init` must do nothing and not touch `HEAP_LIM` (Task 2
   self-test builds that table; Task 3's host smoke links such a program).
2. A pointer computed INTO a block (asctime's result, gmtime's `tm_zone`)
   must land in the process's block, not the template -- the probe checks the
   address against the member's cell, not only the text (Task 4).
3. The heap after `_libc_init`: `sbrk` must stop at the lowered `HEAP_LIM`,
   never reaching a block (Task 4 probe: grow to the limit, one more byte
   fails, and asctime's block still answers correctly).
4. fork after `_libc_init`: the child's blocks are its own (they lie in
   `[HEAP_LIM, $FFFF]`, which fork carries); vfork's child shares them, as
   BSD's does (Task 4).
5. A stale `libc_so` build (the `.s` newer than the blocks file, or the
   blocks file missing from ninja's graph) -- the probe edge must depend on
   `libc_so.blocks.json`, and ninja must know which edge writes it (Task 4
   step wiring).

---

### Task 1: `_libc_init`, and libc.so's `_libc_blktab`

**Files:**
- Create: `toolchain/lib/libc_c/libc_init.c`
- Modify: `toolchain/lib/libc_c/libc_c.c` (include the member)
- Modify: `toolchain/src/ld/fgx_libso.py` (`blktab`, and the core gets it)
- Modify: `toolchain/src/ld/fgx_ld.py` (`split_fixups`)
- Modify: `toolchain/src/ld/test_fgx_ld_library.py`
- Modify: `tools/libc_so_check.py`

**Interfaces:**
- Produces: C `void _libc_init()`; data label `_libc_blktab`, rows of four
  words `{cell address, template offset, template bank (low byte), size}`,
  ended by a zero word.  `fgx_libso.blktab(members, sizes) -> [rows]`
  (Merlin source rows, label row first).  `fgx_ld.split_fixups` allows
  `src == core and tgt == tmpl`.

- [ ] **Step 1: Write the failing tests.**  In `test_fgx_ld_library.py`
  `fixups()`, replace the check "a pointer into a block template is refused"
  with:

```python
    check(dies(lambda: fgx_ld.split_fixups([(0, 3, 3, "long_ptr")], 2, 3)),
          "a code pointer into a block template is refused")
    try:
        kept, fx = fgx_ld.split_fixups([(2, 12, 3, "long_ptr")], 2, 3)
    except SystemExit:
        kept, fx = None, None
    check(kept == [(2, 12, 3, "long_ptr")] and fx == [],
          "the core's pointer into a template (its block table) stays a reloc")
```

  In `library_link()`, replace the final variant (the `pbad` link that must
  exit 2) with:

```python
    assemble(d, "data", 0xF000, DATA0.replace(
        "_libc_blk_m     DA      0",
        "_libc_blk_m     DA      0\npbad            FGX2_LONG_PTR _c;m__BT;0").replace(
        "FGX2_RELOC_COUNT 4", "FGX2_RELOC_COUNT 5"))
    rc, out = link(d, segs, 1, lib)
    check(rc == 0 and struct.unpack_from("<H", out, 11)[0] == 2,
          "the core's pointer into a template links as a reloc", str(rc))
    code_bad = CODE0.replace("f0              RTL",
                             "f0              RTL\ncbad            FGX2_LONG_PTR _c;m__BT;0"
                             ).replace("FGX2_RELOC_COUNT 2", "FGX2_RELOC_COUNT 3")
    assemble(d, "code0", 0, code_bad)
    assemble(d, "data", 0xF000, DATA0)
    rc, out = link(d, segs, 1, lib)
    check(rc == 2 and "block template" in out,
          "a code pointer into a block template is refused", str(rc))
```

  In `tools/libc_so_check.py` `check()`, after the block-table checks, add
  the core table's cross-check, and replace the "crosses a block boundary"
  loop:

```python
    for s, o, t in p["relocs"]:
        if (t == tmpl and s != core) or (s == tmpl and t == core):
            errs.append("reloc %d:%#06x -> %d crosses a block boundary" % (s, o, t))
    labels = dict((n, a) for a, n in gen_seg1_layout.extract_labels(
        os.path.join(d, "core_Output.txt")))
    if "_libc_blktab" not in labels:
        errs.append("the core has no _libc_blktab")
    else:
        pos, rows = labels["_libc_blktab"] - lo, []
        seg = segs[core]
        while struct.unpack_from("<H", seg, pos)[0]:
            cell, toff, _bank, size = struct.unpack_from("<HHHH", seg, pos)
            if (core, pos + 4) not in have:
                errs.append("_libc_blktab row at %#06x has no bank reloc" % pos)
            rows.append((cell, toff, size))
            pos += 8
        if rows != [tuple(b) for b in tr["blocks"]]:
            errs.append("_libc_blktab's %d rows differ from the trailer's %d "
                        "blocks" % (len(rows), len(tr["blocks"])))
```

  (`have` is the `{(src, off)}` set the farcall check already builds; move
  its definition above this block if it is below.)

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py; python3 ../tools/libc_so_check.py`
Expected: the fgx_ld test FAILs "the core's pointer into a template (its
block table) stays a reloc" (split_fixups dies); the checker reports "the
core has no _libc_blktab".

- [ ] **Step 2: Write `_libc_init`.**  First read
  `examples/4.3BSD-Reno/lib/libc/sys/vfork.2` and K&R A.8.7 (gs-mcp
  `kr_c`, page 179-180) so the comment and Task 4's vfork check quote them
  from the page.  `toolchain/lib/libc_c/libc_init.c`:

```c
/*
 * _libc_init -- give this process its own copy of each libc block.
 *
 * libc's statics outside the core live in per-member blocks (shared libc SP2
 * spec, section 4).  Code reaches member m's statics through the core cell
 * _libc_blk_<m>, which must hold the address of THIS process's block.
 * _libc_blktab lists, per member the program reaches, four words: the
 * cell's address, a far pointer to the member's template (offset, then
 * bank) and the block's size; a zero word ends it.  A template holds every
 * static's initial bytes and zeros for the rest, which is K&R A.8.7's
 * rule, "A static object not explicitly initialized is initialized as if it
 * (or its members) were assigned the constant 0", so copying it is the
 * whole initialisation.
 *
 * The blocks go at the top of the heap's room, just below HEAP_LIM, and
 * HEAP_LIM comes down to the lowest of them: sbrk stops there, and fork
 * carries [HEAP_LIM, $FFFF] with the data below the break
 * (include/kernel.s), so a child gets its own copy.  crt0 runs this before
 * it fills any core cell; it reads nothing but the table.  Everything here
 * is in the process's data bank, the one _libc_blktab is in.
 *
 * No BSD counterpart: 2.11BSD links libc statically and its data is the
 * program's.
 */
extern unsigned _libc_blktab[];
extern int write();
extern void _exit();

void
_libc_init()
{
    unsigned *t, *lim;
    unsigned long bank;
    unsigned top, need, n;
    char *blk, *tmpl;

    bank = (unsigned long)(char *)_libc_blktab & 0xFF0000L;
    lim = (unsigned *)(bank | 0xFFF8L);                 /* HEAP_LIM */
    need = 0;
    for (t = _libc_blktab; t[0]; t += 4)
        need += t[3];
    if (need == 0)
        return;
    top = *lim;
    if (need > top - *(unsigned *)(bank | 0xFFFEL)) {   /* HEAP_BRK */
        write(2, "libc: no room for its data\n", 27);
        _exit(1);
    }
    for (t = _libc_blktab; t[0]; t += 4) {
        top -= t[3];
        blk = (char *)(bank | top);
        tmpl = (char *)(((unsigned long)t[2] << 16) | t[1]);
        for (n = 0; n < t[3]; n++)
            blk[n] = tmpl[n];
        *(unsigned *)(bank | t[0]) = top;
    }
    *lim = top;
}
```

  In `libc_c.c`, add `#include "libc_init.c"` after the last member
  include.

- [ ] **Step 3: libc.so's core carries the table.**  In `fgx_libso.py`, add
  beside `write_data`:

```python
def blktab(members, sizes):
    """_libc_blktab: per member (sorted), its cell's address, a far pointer
    to its template and its size; a zero word ends it (libc_c/libc_init.c
    reads it)."""
    rows = ["_libc_blktab    ANOP"]
    for m in sorted(members):
        rows += ["                DA      _libc_blk_%s" % m,
                 "                FGX2_LONG_PTR _bt;%s__BT;0" % m,
                 "                DA      %d" % sizes[m]]
    rows.append("                DA      0")
    return rows
```

  and in `build`, write the core with it: load the blocks file once,
  `members = json.load(open(os.path.join(LIB, "libc_so.blocks.json")))["members"]`,
  and replace the `write_data(... "core.s" ...)` call with

```python
    core_units = [u for u in sects if not u[1].endswith("__BT")]
    core_units.append(("sect", "_libc_blktab",
                       blktab(members, {m: v["size"] for m, v in members.items()})))
    write_data(os.path.join(d, "core.s"), core_units)
```

  Add to `self_test()`:

```python
    rows = blktab(["b", "a"], {"a": 4, "b": 6})
    assert rows == ["_libc_blktab    ANOP",
                    "                DA      _libc_blk_a",
                    "                FGX2_LONG_PTR _bt;a__BT;0",
                    "                DA      4",
                    "                DA      _libc_blk_b",
                    "                FGX2_LONG_PTR _bt;b__BT;0",
                    "                DA      6",
                    "                DA      0"], rows
    assert blktab([], {}) == ["_libc_blktab    ANOP", "                DA      0"]
```

- [ ] **Step 4: fgx_ld allows the core's pointers into templates.**  In
  `split_fixups`, replace the first refusal:

```python
        if tgt == tmpl and src != core:
            die(f"library: segment {src} offset {off:#06x} points into a "
                f"block template ({prov}); only the core's block table may")
```

  and extend its docstring: "The core's block table points into the
  templates, which are read-only and the same in every process, so that
  pointer is an ordinary reloc."

- [ ] **Step 5: Run everything.**  Announce: "rebuilding toolchain piles and
  libc.so (feat/shared-libc)".

Run: `cd toolchain && make fcc piles archives 2>&1 | tail -3 && python3 src/ld/fgx_libso.py --self-test && python3 src/ld/test_fgx_ld_library.py | tail -1 && python3 ../tools/libc_so_check.py --self-test && python3 ../tools/libc_so_check.py && make test-archives 2>&1 | tail -2`
Expected: `fgx_libso: self-test OK`, `fgx_ld library checks passed`,
`libc_so_check: self-test OK ...`, the clean report (still three fixups),
test-archives green.  `libc_init` is a libc member (`ls lib/libc.fgxa/ |
grep libc_init`).  Nothing assembles the whole pile (fixtures assemble the
selected members, and fgx_ar selects `libc_init` only for a program that
names `_libc_init`), so `_libc_blktab` needs no definition outside libc.so
and static links.

- [ ] **Step 6: Commit.**

```bash
git add toolchain/lib/libc_c/libc_init.c toolchain/lib/libc_c/libc_c.c \
        toolchain/src/ld/fgx_libso.py toolchain/src/ld/fgx_ld.py \
        toolchain/src/ld/test_fgx_ld_library.py tools/libc_so_check.py
git commit -m "feat(libc): _libc_init gives each process its own libc blocks

_libc_init walks _libc_blktab -- per member the program reaches, the block
cell's address, a far pointer to the member's template and the block's
size -- carves each block below HEAP_LIM, copies the template in, points
the cell at it and lowers HEAP_LIM, so the heap stops short of the blocks
and fork carries them (include/kernel.s).  A template's zeros are K&R
A.8.7's initialisation.  libc.so's core carries the full table; its
pointers into the read-only templates are ordinary relocs, and
libc_so_check holds the table to the trailer's block rows.  No BSD
counterpart: 2.11BSD links libc statically.

```

---

### Task 2: fgx_static.py -- what a static program keeps

**Files:**
- Create: `toolchain/src/ld/fgx_static.py`
- Modify: `toolchain/src/ld/fgx_libso.py` (`clear_outputs` takes its
  pattern)

**Interfaces:**
- Consumes: `fgx_gc.graph`, `fgx_gc.reach`, `fgx_libso.blktab`.
- Produces: `collect(files, order, prune) -> (units, live)` (fgx_gc's
  shapes: `units[path]` a list of `('sect', label, rows)` /
  `('loose', rows)`, `live` a set of `(path, index)`);
  `squeeze_bss(data_size, need) -> int`;
  `fgx_libso.clear_outputs(d, pattern=OUTPUT)`.

- [ ] **Step 1: Write the module's self-test first** (functions stubbed to
  raise `NotImplementedError`) and watch it fail:

```python
def self_test():
    files = {
        "p.s": ["main    ENT", "        FGX2_FARCALL strtok", "        RTL"],
        "l.s": ["                FGX_SECT strtok", "strtok  ENT",
                "        LDA     _libc_blk_strtok", "        RTL",
                "                FGX_ENDS",
                "                FGX_SECT unused", "unused  ENT", "        RTL",
                "                FGX_ENDS"],
        "l_data.s": ["                FGX_SECT _libc_blk_strtok",
                     "_libc_blk_strtok DA 0", "                FGX_ENDS",
                     "                FGX_SECT _libc_blk_unused",
                     "_libc_blk_unused DA 0", "                FGX_ENDS",
                     "                FGX_SECT strtok__BT",
                     "strtok__BT      ANOP", "strtok_sl_last  DS 4",
                     "                FGX_ENDS",
                     "                FGX_SECT unused__BT",
                     "unused__BT      ANOP", "                DS 2",
                     "                FGX_ENDS"],
    }
    units, live = collect(files, ["p.s", "l.s", "l_data.s"], {"l.s", "l_data.s"})
    names = sorted(units[p][i][1] for p, i in live)
    assert names == ["_libc_blk_strtok", "strtok", "strtok__BT"], names
    assert squeeze_bss(1000, 100) == 0xFFF8 - 1000 - 98
    d = tempfile.mkdtemp(prefix="static_clr_")
    open(os.path.join(d, "seg0.link.s"), "w").close()
    fgx_libso.clear_outputs(d, OUTPUT)
    assert os.listdir(d) == []
    print("fgx_static: self-test OK")
```

Run: `cd toolchain && python3 src/ld/fgx_static.py --self-test`
Expected: FAIL with `NotImplementedError`.

- [ ] **Step 2: Implement.**

```python
#!/usr/bin/env python3
"""fgx_static.py - link a program statically against libc's library-mode
compile (shared libc SP2 spec, section 3, "Static programs").

Segment 0 holds crt0, the program's code, the fcc runtime and libc's
hand-written code; segment 1 the program's data, libc's hand-written data,
the core cells and block templates of the libc members the program
reaches, and _libc_blktab; segments 2 and up the libc functions and string
literals it reaches, packed as libc.so's are (fgx_libso).  The program
enters at _crt0_libso (lib/crt0_libso.s), which runs _libc_init
(lib/libc_c/libc_init.c) and then crt0.

Code reaches a member's statics only through the member's cell, so nothing
names its template: a template is kept exactly when its cell is.

Run: fgx_static.py --name N --dir D --code a.s --data a.data.s --out F
                   [--libc-bank-cap BYTES] [--squeeze]
     fgx_static.py --self-test
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_gc  # noqa: E402
import fgx_ld  # noqa: E402
import fgx_libso  # noqa: E402

LIB = fgx_libso.LIB
TC = fgx_libso.TC
CRT0 = os.path.join(LIB, "crt0_far.s")
CRT0_LIBSO = os.path.join(LIB, "crt0_libso.s")
BLK = re.compile(r"^_libc_blk_(\w+)$")
# Every file build() and Merlin32 write in the program's link directory.
OUTPUT = re.compile(r"^(?:(?:seg[01]|bank\d+|m\d+|ovn|lits|seg1_layout|libc|"
                    r"libc\.data)(?:\.s|\.link\.s|_Output\.txt)?|static\.json|"
                    r"error_output\.txt|_FileInformation\.txt)$")
SEG0_EQUS = fgx_libso.CODE_EQUS + [("ARGS_MAX", "16"), ("ARGS_INPUT_MAX", "128")]


def die(msg):
    sys.exit("fgx_static: " + msg)


def collect(files, order, prune):
    """fgx_gc's reachability over `files', with each block cell's section
    also reaching its member's template."""
    units, owner, body, is_data, roots = fgx_gc.graph(files, order, prune)
    for lab, key in list(owner.items()):
        m = BLK.match(lab)
        if m and m.group(1) + "__BT" in owner:
            body[key] += "\n" + m.group(1) + "__BT"
    return units, fgx_gc.reach(roots, owner, body, is_data)


def squeeze_bss(data_size, need):
    """bss that leaves two bytes too few between the data's end (the first
    break) and HEAP_LIM for blocks of `need' bytes."""
    return fgx_ld.HEAP_LIM - data_size - (need - 2)
```

  (`self_test` and a `main` that runs it on `--self-test` follow.)  In
  `fgx_libso.py`, give `clear_outputs` a pattern parameter:
  `def clear_outputs(d, pattern=OUTPUT):` and use `pattern.match(n)` in it.

- [ ] **Step 3: Run the self-tests.**

Run: `cd toolchain && python3 src/ld/fgx_static.py --self-test && python3 src/ld/fgx_libso.py --self-test`
Expected: `fgx_static: self-test OK`, `fgx_libso: self-test OK`.

- [ ] **Step 4: Commit.**

```bash
git add toolchain/src/ld/fgx_static.py toolchain/src/ld/fgx_libso.py
git commit -m "feat(ld): fgx_static keeps a block template exactly when its cell is live

The first half of the static link against libc's library-mode compile:
fgx_gc's reachability, with each block cell's section reaching its member's
template -- code names only the cell, so nothing else would keep it -- and
the bss that leaves a program too little room for its blocks, for the probe
that must see _libc_init refuse.

```

---

### Task 3: `_crt0_libso` and the static link

**Files:**
- Create: `toolchain/lib/crt0_libso.s`
- Modify: `toolchain/src/ld/fgx_static.py` (`build`, `main`)
- Modify: `toolchain/src/ld/fgx_libso.py` (`write_link` takes a `pad`)
- Create: `toolchain/tests/libso/static_min.c` (host smoke program)
- Modify: `toolchain/tests/libso/test_libso.py` (the smoke)

**Interfaces:**
- Consumes: Task 1's `blktab`, Task 2's `collect`/`squeeze_bss`/
  `clear_outputs`; fgx_libso's `split_code`, `measure`, `literal_refs`,
  `pack_min`, `place_orphans`, `canonical`, `bank_rows`, `write_link`,
  `run_merlin`, `write_data`, `CODE_EQUS`, `DP_EQUS`, `DATA_EQUS`, `MACROS`,
  `RUNTIME`, `BANK0`, `DATA`, `CAP`.
- Produces: `fgx_static.py --name N --dir D --code ... --data ... --out F
  [--libc-bank-cap B] [--squeeze]` writing F and `D/static.json`; prints
  `static N: seg0 X bytes, data Y bytes, libc banks [..], blocks Z bytes
  for K members`.

- [ ] **Step 1: The smoke test first.**  `toolchain/tests/libso/static_min.c`:

```c
/* static_min.c -- the smallest program fgx_static links: one call into
 * libc with no block (strlen), one with one (strtok). */
extern char *strtok();
extern int strlen();

int
main()
{
    char buf[8];

    buf[0] = 'a'; buf[1] = ' '; buf[2] = 'b'; buf[3] = 0;
    return strlen(strtok(buf, " "));
}
```

  In `test_libso.py`, add and run (after `template_sections()`):

```python
def static_link():
    d = tempfile.mkdtemp(prefix="libso_static_")
    src = os.path.join(ROOT, "tests", "libso", "static_min.c")
    r = subprocess.run([FCC, "--data-segment", os.path.join(d, "p.data.s"),
                        "-o", os.path.join(d, "p.s"), src],
                       capture_output=True, text=True)
    check(r.returncode == 0, "static_min.c compiles", r.stderr[-200:])
    if r.returncode:
        return
    out = os.path.join(d, "p.bin")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_static.py"),
                        "--name", "p", "--dir", os.path.join(d, "p.ld"),
                        "--code", os.path.join(d, "p.s"),
                        "--data", os.path.join(d, "p.data.s"), "--out", out],
                       capture_output=True, text=True)
    check(r.returncode == 0, "fgx_static links it", (r.stdout + r.stderr)[-300:])
    if r.returncode:
        return
    m = json.load(open(os.path.join(d, "p.ld", "static.json")))
    data = open(out, "rb").read()
    seg0 = 16 + 8 * data[6]
    entry = struct.unpack_from("<H", data, 8)[0]
    check(entry != 0 and data[seg0 + entry:seg0 + entry + 2] == b"\xC2\x30",
          "the entry is _crt0_libso (REP #$30), not crt0's JMP at 0", hex(entry))
    rows = open(os.path.join(d, "p.ld", "libc.data.s")).read()
    check("_libc_blk_strtok" in rows and "strtok__BT" in rows,
          "strtok's cell and template are kept, with a table row")
    check("_libc_blk_ctime" not in rows, "an unreached member's block is not")
    check(len(m["segments"]) >= 3 and m["segments"][2]["kind"] == "CODE",
          "libc's reached code is its own bank")
```

  (add `import struct` to the test's imports.)

Run: `cd toolchain && python3 tests/libso/test_libso.py`
Expected: FAIL "fgx_static links it" (no `--name`: the driver has only
`--self-test`).

- [ ] **Step 2: `crt0_libso.s`.**

```
;==============================================================================
; crt0_libso.s - the entry of a program statically linked against libc's
; library-mode compile (toolchain/src/ld/fgx_static.py).  PUT after
; crt0_far.s; the manifest's entry offset names _crt0_libso, so crt0's own
; entry at offset 0 and its pinned scratch cells are untouched.
;
; _libc_init (lib/libc_c/libc_init.c) gives the process its own copy of
; each libc block before crt0 fills any core cell (shared libc SP2 spec,
; section 3).  It reads the block table and writes the blocks, the cells and
; HEAP_LIM, all in the data bank the loader set as DBR, and leaves the stack
; as it found it -- the argv frame crt0 walks.  Then crt0 starts as it does
; for every program, in the state the loader hands it: native, MX %11.
;==============================================================================
                FGX2_EXPORT _crt0_libso
_crt0_libso     MX      %11
                REP     #$30
                MX      %00
                FGX2_FARCALL _libc_init
                SEP     #$30
                MX      %11
                JMP     _crt0_start
```

- [ ] **Step 3: The driver.**  Add to `fgx_static.py`:

```python
def read(p):
    return open(p, errors="replace").read().split("\n")


def build(name, d, code, data, out, bank_cap=None, squeeze=False):
    os.makedirs(d, exist_ok=True)
    fgx_libso.clear_outputs(d, OUTPUT)
    lib_code = os.path.join(LIB, "libc_so.s")
    lib_data = os.path.join(LIB, "libc_so_data.s")
    seg0_fixed = [CRT0, CRT0_LIBSO, fgx_libso.RUNTIME] + fgx_libso.BANK0
    order = code + seg0_fixed + data + fgx_libso.DATA + [lib_code, lib_data]
    files = {p: read(p) for p in order}
    units, live = collect(files, order, {lib_code, lib_data})

    # libc's data: the live core sections, the live templates, the table.
    keep = [units[lib_data][i] for p, i in sorted(live) if p == lib_data]
    members = json.load(open(os.path.join(LIB, "libc_so.blocks.json")))["members"]
    cells = [BLK.match(u[1]).group(1) for u in keep if BLK.match(u[1])]
    tmpls = {u[1][:-len("__BT")] for u in keep if u[1].endswith("__BT")}
    if set(cells) != tmpls:
        die("cells %s and templates %s disagree" % (sorted(cells), sorted(tmpls)))
    need = sum(members[m]["size"] for m in cells)
    tab = fgx_libso.blktab(cells, {m: members[m]["size"] for m in cells})
    fgx_libso.write_data(os.path.join(d, "libc.data.s"),
                         keep + [("sect", "_libc_blktab", tab)])

    # Segment 1: the data.  Its listing gives every code segment its labels.
    # The 256-byte pad keeps every data label at $0100 or above, as every
    # program's data segment does (tools/fgx2/seg1.link.s.in), and absorbs
    # crt0's DBR-relative scratch writes.
    link = fgx_libso.write_link(d, "seg1", 0, fgx_libso.DATA_EQUS,
                                [fgx_libso.MACROS] + fgx_libso.DATA
                                + ["libc.data.s"] + data, pad=256)
    seg1 = fgx_libso.run_merlin(d, link)
    if seg1 is None:
        die("the data segment is over 64 KB")
    subprocess.run([sys.executable, os.path.join(TC, "tools", "gen_seg1_layout.py"),
                    os.path.join(d, "seg1_Output.txt"),
                    os.path.join(d, "seg1_layout.s")], check=True,
                   stdout=subprocess.DEVNULL)

    # Segment 0: crt0 first (its entry and pinned cells sit at offset 0).
    seg0 = fgx_libso.run_merlin(d, fgx_libso.write_link(
        d, "seg0", 0, SEG0_EQUS,
        [fgx_libso.MACROS, "seg1_layout.s", CRT0] + code
        + [CRT0_LIBSO, fgx_libso.RUNTIME] + fgx_libso.BANK0))
    if seg0 is None:
        die("segment 0 (crt0, the program, libc's hand-written code) is over 64 KB")

    # libc's reached code, in banks of its own.
    cunits, corder = fgx_libso.split_code(files[lib_code], lib_code)
    live_code = {units[lib_code][i][1] for p, i in live if p == lib_code}
    funcs = [n for n in corder if n in live_code and not fgx_libso.LIT.match(n)]
    lits = [n for n in corder if fgx_libso.LIT.match(n)]
    sizes, lsizes = fgx_libso.measure(d, funcs, lits, cunits, "seg1_layout.s")
    ovn = len(fgx_libso.run_merlin(d, fgx_libso.write_link(
        d, "ovn", 0, fgx_libso.CODE_EQUS + fgx_libso.DP_EQUS,
        [fgx_libso.MACROS, "seg1_layout.s", fgx_libso.RUNTIME])))
    budget = fgx_libso.CAP - ovn
    if bank_cap:
        budget = min(budget, bank_cap)
    refs = fgx_libso.literal_refs(cunits, funcs)
    banks, held, free = fgx_libso.pack_min(sizes, refs, lsizes, budget, budget, 6)
    need_lits = {t for t in fgx_gc.IDENT.findall(
        open(os.path.join(d, "libc.data.s")).read()) if fgx_libso.LIT.match(t)}
    fgx_libso.place_orphans(need_lits, held, free, lsizes)
    canon = fgx_libso.canonical(held)

    segs = [{"bin": "seg0", "listing": "seg0_Output.txt", "kind": "CODE", "bss": 0},
            {"bin": "seg1", "listing": "seg1_Output.txt", "kind": "DATA", "bss": 0}]
    frames = list(code)
    for b, fs in enumerate(banks):
        rows = fgx_libso.bank_rows(cunits, corder, fs, held[b], canon, b)
        with open(os.path.join(d, "bank%d.s" % b), "w") as f:
            f.write("\n".join(rows) + "\n")
        got = fgx_libso.run_merlin(d, fgx_libso.write_link(
            d, "bank%d" % b, 0, fgx_libso.CODE_EQUS + fgx_libso.DP_EQUS,
            [fgx_libso.MACROS, "seg1_layout.s", "bank%d.s" % b, fgx_libso.RUNTIME]))
        want = ovn + sum(sizes[f] for f in fs) + sum(lsizes[l] for l in held[b])
        if got is None or len(got) != want:
            die("libc bank %d assembled to %s bytes; its sections measured %d"
                % (b, "over 64K" if got is None else len(got), want))
        segs.append({"bin": "bank%d" % b, "listing": "bank%d_Output.txt" % b,
                     "kind": "CODE", "bss": 0})
        frames.append(os.path.join(d, "bank%d.s" % b))
    if squeeze:
        segs[1]["bss"] = squeeze_bss(len(seg1), need)
        if segs[1]["bss"] < 0 or need < 4:
            die("--squeeze needs blocks and room to squeeze (need %d)" % need)
    entry = fgx_ld.scan_listing(os.path.join(d, "seg0_Output.txt"), len(segs),
                                libc=True)["exports"].get("_crt0_libso")
    if entry is None:
        die("seg0 exports no _crt0_libso")
    manifest = {"output": os.path.basename(out), "format": "FGX3",
                "n_data_segment": 1, "entry_offset": entry, "flags": 0,
                "stack_frames": [os.path.relpath(f, d) for f in frames],
                "segments": segs}
    mpath = os.path.join(d, "static.json")
    with open(mpath, "w") as f:
        json.dump(manifest, f, indent=1)
    subprocess.run([sys.executable, os.path.join(HERE, "fgx_ld.py"), mpath,
                    "-o", out], check=True)
    print("static %s: seg0 %d bytes, data %d bytes, libc banks [%s], blocks "
          "%d bytes for %d members" % (name, len(seg0), len(seg1), ", ".join(
              str(budget - f + ovn) for f in free), need, len(cells)))
```

  and `main`:

```python
def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--code", required=True, help="comma-separated .s files")
    ap.add_argument("--data", required=True, help="comma-separated .data.s files")
    ap.add_argument("--out", required=True)
    ap.add_argument("--libc-bank-cap", type=int)
    ap.add_argument("--squeeze", action="store_true")
    a = ap.parse_args()
    build(a.name, os.path.abspath(a.dir),
          [os.path.abspath(p) for p in a.code.split(",")],
          [os.path.abspath(p) for p in a.data.split(",")],
          os.path.abspath(a.out), a.libc_bank_cap, a.squeeze)
    return 0
```

  In `fgx_libso.py`, `write_link` gains `pad=0`: after the EQU rows, when
  `pad` is nonzero, it writes `                DS     <pad>` (macros.s emits
  no bytes, so the pad before its PUT is the pad before the data).

- [ ] **Step 4: Run the smoke.**

Run: `cd toolchain && python3 src/ld/fgx_static.py --self-test && python3 tests/libso/test_libso.py | tail -6`
Expected: `libso checks passed`, the new checks ok.

- [ ] **Step 5: Commit.**

```bash
git add toolchain/lib/crt0_libso.s toolchain/src/ld/fgx_static.py \
        toolchain/tests/libso/static_min.c toolchain/tests/libso/test_libso.py
git commit -m "feat(ld): fgx_static links a program against libc's library-mode compile

Segment 0 carries crt0, the program, the fcc runtime and libc's hand-written
code; the data segment carries the program's data, libc's hand-written
cells, the core cells and templates of the members the program reaches and
their _libc_blktab; libc's reached functions and literals are packed into
banks of their own as libc.so's are.  The program enters at _crt0_libso,
which calls _libc_init and jumps to crt0's start, so crt0 and every other
binary are unchanged.

```

---

### Task 4: the libcso probe, on the machine

**Files:**
- Create: `src/userland/libcso/libcso.c`
- Create: `tools/libcso-fgx2/build_libcso.sh`
- Modify: `tools/ninja/gen.py` (`SHELLS` entries; `libc_so.blocks.json` on
  the `tclibs` edge)
- Modify: `tools/ninja/manifest.json` (staging)
- Create: `tools/mame_test/tests/libcso.json`, `tools/mame_test/tests/libcsofull.json`

**Interfaces:**
- Consumes: Task 3's `fgx_static.py`.
- Produces: `/testbin/libcso` (prints `CSO <check> ok` per check, then
  `CSO ok`, or `CSO FAIL <check> ...`) and `/testbin/libcsofull` (refuses at
  startup).

- [ ] **Step 1: The probe.**  `src/userland/libcso/libcso.c`:

```c
/*
 * libcso -- shared libc SP2's machine probe: a program statically linked
 * against libc's library-mode compile (toolchain/src/ld/fgx_static.py), whose
 * startup gave it its own copy of every libc block it reaches
 * (lib/libc_c/libc_init.c).  One line per check, `CSO <check> ok' or
 * `CSO FAIL <check> ...', then `CSO ok' if all passed.  Spec:
 * docs/history/plans/2026-09-28-shared-libc-sp2-design.md, section 8.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>

extern char *strtok(), *strerror(), *asctime(), *sbrk();
extern struct tm *gmtime();
extern int open(), rand(), fork(), vfork(), wait(), alarm(), pause();
extern void srand(), _exit();
extern unsigned _libc_blk_strtok, _libc_blk_ctime;

static int fails;
static char sigbuf[8];
static int anchor;

static void
say(what, ok)
char *what;
int ok;
{
    printf(ok ? "CSO %s ok\n" : "CSO FAIL %s\n", what);
    if (!ok)
        fails++;
}

static unsigned long
bankof()
{
    return (unsigned long)(char *)&anchor & 0xFF0000L;
}

static unsigned
heaplim()
{
    return *(unsigned *)(bankof() | 0xFFF8L);
}

static unsigned
lo(p)
char *p;
{
    return (unsigned)((unsigned long)p & 0xFFFFL);
}

static void
onalarm(sig)
int sig;
{
    sprintf(sigbuf, "%d", 42);
}

int
main()
{
    char b1[16], b2[16], b3[16];
    char *s1, *s2;
    long t;
    int a, pid, st;
    unsigned lim;

    /* A zeroed static in a block: strtok's saved position starts NULL. */
    say("zero", strtok((char *)0, " ") == (char *)0);

    /* An initialised one: rand's state starts as srand(1) leaves it. */
    a = rand();
    srand(1);
    say("init", a == rand());

    /* The core: errno, and stdout (every line here). */
    errno = 0;
    say("errno", open("/nonexistent/x", 0) < 0 && errno == ENOENT);

    /* A literal, from libc's banks. */
    say("literal", strcmp(strerror(ENOENT), "No such file or directory") == 0);

    /* A stateful member across calls. */
    strcpy(b1, "a b c");
    s1 = strtok(b1, " ");
    s2 = strtok((char *)0, " ");
    say("strtok", strcmp(s1, "a") == 0 && strcmp(s2, "b") == 0 &&
        strcmp(strtok((char *)0, " "), "c") == 0);

    /* ctime's member: the same result buffer, in THIS process's block. */
    t = 0;
    s1 = asctime(gmtime(&t));
    say("asctime", strcmp(s1, "Thu Jan  1 00:00:00 1970\n") == 0);
    t = 86400L;
    s2 = asctime(gmtime(&t));
    say("again", s1 == s2 && strcmp(s2, "Fri Jan  2 00:00:00 1970\n") == 0);
    lim = heaplim();
    say("place", lim < 0xFFF8 && _libc_blk_ctime >= lim &&
        (unsigned long)(char *)s1 >> 16 == bankof() >> 16 &&
        lo(s1) >= _libc_blk_ctime && lo(s1) < 0xFFF8 &&
        strcmp(gmtime(&t)->tm_zone, "GMT") == 0 &&
        lo(gmtime(&t)->tm_zone) >= _libc_blk_ctime);

    /* fork: the child's blocks are its own. */
    strcpy(b2, "p1 p2 p3");
    strtok(b2, " ");
    pid = fork();
    if (pid == 0)
        _exit(strcmp(strtok((char *)0, " "), "p2") == 0 ? 0 : 1);
    wait(&st);
    say("fork", st == 0 && strcmp(strtok((char *)0, " "), "p2") == 0);

    /* vfork: the child borrows the parent's memory, blocks included. */
    strcpy(b3, "v1 v2 v3");
    strtok(b3, " ");
    pid = vfork();
    if (pid == 0) {
        strtok((char *)0, " ");
        _exit(0);
    }
    wait(&st);
    say("vfork", strcmp(strtok((char *)0, " "), "v3") == 0);

    /* A signal handler that calls libc. */
    /* FGX's pause() is a 60-tick sleep (libc_c/syscall_misc.c) and alarm(1)
     * is 60 ticks, so one pause can end before the alarm is delivered. */
    signal(SIGALRM, onalarm);
    alarm(1);
    for (a = 0; a < 5 && !sigbuf[0]; a++)
        pause();
    say("signal", strcmp(sigbuf, "42") == 0);

    /* Last, because it fills the heap: sbrk stops at the lowered limit. */
    s1 = sbrk(0);
    s2 = sbrk(lim - lo(s1));
    say("sbrk", s2 != (char *)-1 && sbrk(1) == (char *)-1 &&
        heaplim() == lim &&
        strcmp(asctime(gmtime(&t)), "Fri Jan  2 00:00:00 1970\n") == 0);

    printf(fails ? "CSO FAIL %d\n" : "CSO ok\n", fails);
    return fails != 0;
}
```

  Check the vfork line against `examples/4.3BSD-Reno/lib/libc/sys/vfork.2`
  (read in Task 1): if the page says the parent sees the child's changes to
  its data, keep the check and quote the sentence in the commit; if not,
  change the check to what the page says and ledger it.

- [ ] **Step 2: The build script.**  `tools/libcso-fgx2/build_libcso.sh`:

```bash
#!/bin/bash
# libcso: shared libc SP2's machine probe, statically linked against libc's
# library-mode compile (toolchain/src/ld/fgx_static.py).  $1 names the
# binary: libcso (libc's reached code capped at 8 KB a bank, so it spans
# several code banks) or libcsofull (its heap room squeezed below its
# blocks' size, so _libc_init must refuse before main).
set -eu
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
name="$1"
"$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
    --data-segment "$name.data.s" -o "$name.s" "$REPO/src/userland/libcso/libcso.c"
case "$name" in
  libcso) extra="--libc-bank-cap 8192" ;;
  libcsofull) extra="--squeeze" ;;
  *) echo "build_libcso.sh: libcso or libcsofull" >&2; exit 2 ;;
esac
python3 "$REPO/toolchain/src/ld/fgx_static.py" --name "$name" --dir "$name.ld" \
    --code "$name.s" --data "$name.data.s" --out "$name.bin" $extra
if [ "$name" = libcso ]; then
    python3 -c "import json,sys; n=len(json.load(open('$name.ld/static.json'))['segments'])-2; sys.exit(0 if n >= 2 else 'libcso: libc spans %d bank(s), the probe needs 2' % n)"
fi
```

  `chmod +x` it.

- [ ] **Step 3: Wire it into ninja.**  In `tools/ninja/gen.py`, add to
  `SHELLS`:

```python
    # Shared libc SP2's machine probe, linked statically against libc's
    # library-mode compile.  Two binaries from one source (build_libcso.sh).
    "libcso": dict(
        out="tools/libcso-fgx2/libcso.bin",
        script="tools/libcso-fgx2/build_libcso.sh libcso",
        gate="src/userland/libcso",
        links=["tools/libcso-fgx2/build_libcso.sh"],
        globs=["src/userland/libcso/*"],
        extra=["toolchain/src/ld/fgx_static.py", "toolchain/src/ld/fgx_libso.py",
               "toolchain/lib/crt0_libso.s", "toolchain/lib/libc_c/core.list"],
        hard=["toolchain/lib/libc_so.s", "toolchain/lib/libc_so_data.s",
              "toolchain/lib/libc_so.blocks.json", "build/libc.sigs"],
    ),
    "libcsofull": dict(
        out="tools/libcso-fgx2/libcsofull.bin",
        script="tools/libcso-fgx2/build_libcso.sh libcsofull",
        gate="src/userland/libcso",
        links=["tools/libcso-fgx2/build_libcso.sh"],
        globs=["src/userland/libcso/*"],
        extra=["toolchain/src/ld/fgx_static.py", "toolchain/src/ld/fgx_libso.py",
               "toolchain/lib/crt0_libso.s", "toolchain/lib/libc_c/core.list"],
        hard=["toolchain/lib/libc_so.s", "toolchain/lib/libc_so_data.s",
              "toolchain/lib/libc_so.blocks.json", "build/libc.sigs"],
    ),
```

  and add `"toolchain/lib/libc_so.blocks.json"` to `_libs_out` (the
  `tclibs` edge writes it: `make piles` runs `libc_so`; without it ninja
  stops "no rule to make").  The script is a dependency through `links`:
  `shell_deps` adds `script` only when that path exists, and with its
  argument appended it does not -- keep `links` naming the script.  In
  `tools/ninja/manifest.json` `staging`, add

```json
  {
   "src": "tools/libcso-fgx2/libcso.bin",
   "dst": "disk_src/testbin/libcso"
  },
  {
   "src": "tools/libcso-fgx2/libcsofull.bin",
   "dst": "disk_src/testbin/libcsofull"
  },
```

  `.gitignore:167` (`tools/*-fgx2/*`) already ignores everything the build
  writes there -- and the script too.  Add
  `!tools/libcso-fgx2/build_libcso.sh` beside the elvis and tcsh exceptions
  that follow it, so the script can be committed.

- [ ] **Step 4: The two MAME tests.**  `tools/mame_test/tests/libcso.json`:

```json
{
 "name": "libcso",
 "description": "Shared libc SP2: a program statically linked against libc's library-mode compile, whose startup (_libc_init) gave it its own libc blocks.  Core state, a zeroed and an initialised block static, a literal, strtok and asctime across calls with results in the process's own block, sbrk stopping at the lowered HEAP_LIM, fork (child's blocks its own) and vfork (child borrows the parent's), a signal handler calling libc, libc's code across several banks.",
 "command": "/testbin/libcso",
 "timeout_s": 120,
 "expect": {
  "screen_contains": ["CSO ok"],
  "screen_lacks": ["CSO FAIL", "libc: no room", "PANIC", "BRK"]
 }
}
```

  `tools/mame_test/tests/libcsofull.json`:

```json
{
 "name": "libcsofull",
 "description": "Shared libc SP2: a static program whose data leaves too little room for its libc blocks; _libc_init must say so on fd 2 and exit 1 before main runs.",
 "command": "/testbin/libcsofull; echo status=$?",
 "timeout_s": 90,
 "expect": {
  "screen_contains": ["libc: no room for its data", "status=1"],
  "screen_lacks": ["CSO ", "PANIC", "BRK"]
 }
}
```

- [ ] **Step 5: Build.**  Announce: "regenerating ninja and building the
  disk on feat/shared-libc".

Run: `python3 tools/ninja/gen.py && ninja disk 2>&1 | tail -5 && ls -l tools/libcso-fgx2/*.bin`
Expected: both binaries built.  The `shellbuild` rule discards the
script's output, so for the `static libcso:` line (libc banks and block
bytes) run `bash tools/libcso-fgx2/build_libcso.sh libcso` by hand: two or
more libc banks.

- [ ] **Step 6: Watch the probe fail for the right reason.**  Temporarily
  change `*(unsigned *)(bank | t[0]) = top;` in `libc_init.c` to
  `*(unsigned *)(bank | t[0]) = t[1];` -- each cell points at its member's
  template instead of a block, so every check still runs on real bytes and
  only the placement check can tell (a template lies below the break, a
  block above `HEAP_LIM`).  Deleting the store instead would leave the cells
  0 and put ctime's 3,182-byte block over the data segment's first 3 KB --
  errno, the FILE table, stdio's cells -- a crash that erases its own
  evidence.  Rebuild and run.  Announce: "running libcso headless in MAME (mutated libc_init,
  expected to fail)".

Run: `ninja disk > /dev/null && python3 tools/mame_test/run.py libcso`
Expected: FAIL, with `CSO FAIL place` on the screen.  Restore the line.

- [ ] **Step 7: Run both for real.**  Announce the MAME runs.

Run: `ninja disk > /dev/null && python3 tools/mame_test/run.py libcso libcsofull`
Expected: both PASS; not "(cached)" -- if a verdict says cached, rerun with
`--no-state` or whatever run.py offers to force it (memory: a cached
verdict did not run).

- [ ] **Step 8: Commit.**

```bash
git add src/userland/libcso/libcso.c tools/libcso-fgx2/build_libcso.sh \
        tools/ninja/gen.py tools/ninja/manifest.json .gitignore \
        tools/mame_test/tests/libcso.json tools/mame_test/tests/libcsofull.json
git commit -m "test(libc): libcso runs libc's library-mode compile on the machine

A probe linked by fgx_static, with libc's reached code in several banks:
the core, a zeroed and an initialised block static, a literal, strtok and
asctime across calls with their results in the process's own block, sbrk
stopping at the lowered HEAP_LIM, fork giving the child its own blocks and
vfork lending the parent's (4.3BSD-Reno vfork(2): <quote>), and a signal
handler calling libc.  libcsofull, squeezed below its blocks' size, is
refused at startup.  With _libc_init not pointing the cells at the blocks,
libcso fails its placement check.  Not in the gate.

```

---

### Task 5: record the step, run the gate

**Files:**
- Modify: `docs/history/plans/2026-09-28-shared-libc-sp2-design.md`
  (sections 3 and 10)

- [ ] **Step 1: The spec.**  In section 3, "Static programs", replace "core
  at the top of the data bank, blocks below it" with "the core in the data
  segment where the loader places it, the blocks at the top below HEAP_LIM",
  and add the reason (a core at the top would put ~60 KB of zeros in every
  static file).  Under "Startup", add that the static entry is
  `_crt0_libso` (`lib/crt0_libso.s`), named by the manifest's entry offset.
  In section 10, add "Step 4 landed <date>" with the probe's result, the
  libc bank count and block bytes from the `static libcso:` line, and the
  settled items above (core placement, the entry hook, pointers from the
  core into templates, measurement moved to step 5), and two more: the
  block table is the linker's (spec section 3 had `_libc_init` "record it
  in the block table"; it now fills the cells the linker's table names),
  and section 8's host check "every member whose code names slot S has S's
  owner in its closure" is not in libc_so_check -- vacuous for libc.so,
  which ships every member -- and holds for a static program by
  construction (a template is kept exactly when its cell is).

- [ ] **Step 2: The gate.**  Announce: "running the gate on feat/shared-libc
  at <HEAD> -- it rebuilds every binary".

Run: `tools/gate.sh 2>&1 | tail -5`
Expected: `GATE GREEN`.  The seconds ratchet (`gate_budget.py`) sums the
gate's MAME tests' declared timeouts, and the probe is not one of them; the
two static links add seconds to `ninja all` only.  Record the gate's total
beside step 3's 654 s.

- [ ] **Step 3: Commit, and record in the project notes** (`group_id="fgx"`,
  triplets): step 4 landed, SUPERSEDES the step 4 NEXT pointer; "a static
  libc.so program enters at _crt0_libso, named by the manifest entry
  offset"; "Merlin32 DO on an undefined symbol is an error".

```bash
git add docs/history/plans/2026-09-28-shared-libc-sp2-design.md
git commit -m "docs(plans): shared libc SP2 step 4 landed

```
