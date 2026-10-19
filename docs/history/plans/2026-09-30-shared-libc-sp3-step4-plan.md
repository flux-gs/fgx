# Shared libc SP3 step 4: fgx_bind and the machine probes -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bind a dynamic program (step 3's `fgx_dyn` output) to the shared
libraries on the host, writing an ordinary FGX3 image the existing kernel
loader runs, and prove it in headless MAME: `dynso` (prebound), `dynsomis`
(bound by name against a libc.so whose core moved), `dynsonodata` (the same
with data-site patching off: must fail) and `cursso` (all three libraries).

**Architecture:** `toolchain/src/ld/fgx_bind.py` reads the program's `FGXD`
trailer, finds each needed library by name and major, stacks their cores
below `HEAP_LIM` in load order, and lays out one image: the program's
segments, then each library's code banks as `CODE` segments, the library's
core template and block templates appended to its last bank.  It rewrites
the libraries' relocs for the new segment numbers, turns each library's
per-process fixups into relocs to the program's data segment, applies each
library's core-relative sites, binds each library's imports and then the
program's (prebound when the record's CRC and core base match, by name when
not), and appends to segment 0 a startup routine that copies every core
template to its base with `MVN`, writes `HEAP_LIM` and jumps to `_crt0_lib`.
The probes are built by one script per ninja entry and staged to
`/testbin`, as SP2's libcso is.

**Tech Stack:** Python 3 (fgx_bind, fgx_libso, tests), 65816 machine code
emitted by the binder (cross-checked against Merlin32), fcc (probes), ninja
(`tools/ninja/gen.py`), headless MAME (`tools/mame_test/run.py`).

**Spec:** `docs/history/plans/2026-09-29-shared-libc-sp3-design.md`, section 4
("The host binder"), section 5 (the machine probes), section 6 item 4; the
umbrella `2026-09-28-shared-libc-design.md` 5.4 (versions).  Revised the
same day for an adversarial review (Fable, which ran the plan's code
against the built libraries: with `add_lib`'s map fixed every host check
passed, dynso bound to 5 segments and cursso to 7), twelve findings
adopted.  Settled here
from reading the code (file:line as of bbf095ebe..f9ed84ea8):

- **The loader needs nothing new.**  It gives every segment its own bank at
  offset 0 (`src/kernel/far/loader.s:1224, 1545`), at most 9 segments, the 9th
  `LIBC` only (`loader.s:908-917`; `fgx_ld.py:913`; `TCB_BankList` has 8
  rows, `include/loader.s:86-101`), treats `CODE`, `DATA` and `RODATA` alike
  (`loader.s:1044-1046`), and applies each 4-byte reloc `(src_seg, offset,
  tgt_seg)` by writing the target segment's bank into one byte, with no
  bounds check (`loader.s:1370-1393`, `include/loader.s:183-185`).  It never
  reads the flags byte.  So the image's library banks are plain `CODE`
  segments and fgx_bind checks every reloc offset itself.
- **Entry.**  The loader enters segment 0 at the header's entry offset with
  DBR = the data segment's bank and only the kernel's argv frame on the
  stack (`loader.s:1411-1419, 1910-1999`; `src/kernel/sched.s:546-556`,
  where `_Task_FirstRun` enters in MX %00 -- the routine does not depend on
  the widths, since it saves P and sets its own).  It seeds
  `HEAP_BRK`/`HEAP_HWM`/`HEAP_BASE` to the data segment's end and
  `HEAP_LIM` ($FFF8) to $FFF8 (`loader.s:1655-1666`; `include/kernel.s:983-992`).
  `crt0_lib.s` JSLs `_libc_start` before pushing anything, and `_libc_start`
  reads the frame at `S+4` -- so the startup routine must leave S, P and DBR
  as it found them.  It does: `PHP` / `REP #$30` / ... / `PLP` / `JMP
  _crt0_lib`, and `MVN` leaves DBR = its destination bank, the data bank
  ("The data bank register holds the value of the destination bank value",
  *Programming the Apple IIgs* part 2, p. 157).
- **`MVN`'s bytes.**  Opcode `$54`, then the DESTINATION bank, then the
  SOURCE bank: "The first operand specifies the bank containing the block to
  be moved, and the second specifies the bank to which the block will be
  moved ... When the instruction is assembled into machine code, however,
  this order is reversed" (op. cit. pp. 157-158); X = source offset, Y =
  destination offset, C = length - 1.  FGX's own `block.s:926-932` patches
  the destination bank at `MVN+1`.  So the binder puts a reloc to the data
  segment at `+1` and one to the library's last bank at `+2`, and Task 3's
  test assembles the same routine with Merlin32 to prove the order.
- **Where a library's data goes.**  A `.so` (fgx_libso) is its code banks
  (`kind` 0), its core (`kind` 1, assembled at its base) and its block
  templates (`kind` 2), in that order: libc 3 banks (65,534, 65,535, 36,058
  bytes) + core 2,389 + templates 9,443; termlib 3,264 + 449 + 74; curses
  38,891 + 3,536 + 1,657.  The core and templates go on the end of the last
  bank (libc's becomes 47,890 bytes).  Its relocs, measured: code to code;
  core to code (libc 38, curses 158: function pointers); core to templates
  (the block table: libc 37, termlib 1, curses 5); templates to code (libc
  92).  A reloc into the templates has its 16-bit offset word two bytes
  before the bank byte (`FGX2_LONG_PTR`, `macros.s:782-786`; the block-table
  row `cell, tmpl offset, tmpl bank, size`, `libc_init.c`), and that word
  gains the templates' new offset.  No reloc targets the core: fgx_ld turned
  those into `FIXS` (`fgx_ld.py` `split_fixups`), offsets of the bank bytes
  that must be the process's data bank -- here a reloc to the program's data
  segment on the template copy, which `MVN` then carries into the core.
- **Bases.**  libc's core ends at `HEAP_LIM`; each library above stacks
  directly below the one before (spec section 2): base = previous base -
  core size.  A library's core delta is its actual base less the base its
  `.so` was assembled at (0 unless a library below changed size), applied
  to its `CSIT` sites.
- **Prebound or by name**, per needed library of each importing object
  (library or program): prebound when the record's CRC equals the library's
  and the record's core base equals the library's actual base -- then every
  recorded value is right and no name is looked up; otherwise every import
  from it is looked up by name.  Either way every call and pointer site gets
  its bank from a reloc to the image segment holding the export's bank.  A
  data site gains `actual address - recorded value`.
- **Versions** (umbrella 5.4, SunOS text): the library is found as
  `<name>.so.<major>.<minor>` in the library directory, highest minor of the
  recorded major (SunOS `cache_rtld.c:145-183`, "the highest versioned
  object is the .so with a matching major number but the highest minor
  number"); none: `ld.so: <name>.so.<major>: not found` (`rtld.c:612-615`);
  an older minor than recorded binds with `ld.so: warning: <file> has older
  revision than expected <minor>` (`cache_rtld.c:178-181`).
- **The bitmap's rows** are the library's block-table rows; a library
  bound by name whose table has a different row count is refused -- the
  table carries no names to remap by.  Stated divergence, SP4 may add them.
- **`HEAP_LIM` in the probe.**  A dynamic program cannot name a block cell
  (they are not exports), so `dynso` checks the carve through
  `_libc_blktab` (a data export) and its own `_dyn_bits_libc`: the reached
  rows' blocks lie back to back from `HEAP_LIM` to a top no higher than any
  libc core address it names, and add up to the bitmap's need.  The exact
  value -- the lowest core base -- is checked on the host (Task 3: the
  routine's `LDA #` operand).
- **Nothing staged carries flags bit 1 or 2**: fgx_bind clears both and its
  test checks the header.
- **Out of this step:** the loader's refusal of bits 1 and 2 and the kernel
  binder (SP4); sharing library banks between processes (SP4: each bound
  image carries its own copy); multi-segment dynamic programs (SP5).

## Global Constraints

- ASCII only; comments describe the current state; commit bodies
  informational, ending with
- Every shipped binary is unchanged (fgx_libso's `--core-pad` defaults to
  0; the gate proves it).
- Headless MAME only, through `tools/mame_test/run.py`; announce every
  rebuild and every MAME run; the probes are testbin, not gate tests.
- Branch `feat/shared-libc`, not pushed.

## Review Focus

1. A library's block-table pointer into its templates -- its offset word
   moves by the templates' new offset and its bank is the last bank's
   (Task 1: every core-to-template reloc checked; MAME: `dynso`'s `init`
   and `strtok` read blocks copied from those templates).
2. A per-process fixup (libc's `stdin`/`stdout`/`stderr` pointing at its
   own `_iob`) -- a reloc to the program's data segment on the template copy
   (Task 1: three relocs; MAME: every `printf` line).
3. A by-name data site whose change is negative -- the word wraps mod
   65,536 (Task 2: a trailer with every data export moved down 2; MAME:
   `dynsomis`).
4. The startup routine's effect on the entry frame -- S, P and DBR as the
   loader left them (Task 3: `PHP`/`PLP`, no net push; MAME: `dynso`'s
   `argv` and `progname`, which read the frame at a fixed depth).
5. A program's bitmap against a library whose block table changed size --
   refused, not mis-built (Task 2 test).

---

### Task 1: fgx_bind lays out the image: segments, relocs, fixups, core sites

**Files:**
- Create: `toolchain/src/ld/fgx_bind.py` (module docstring, `parse`,
  `Image`, `Image.add_lib`, `Image.reloc`, `Image.word_add`, `Image.word_set`)
- Create: `toolchain/tests/dyn/test_bind.py`

**Interfaces:**
- Produces:
  - `parse(data: bytes) -> {"head": bytes(16), "segs": [(bytearray, bss,
    kind)], "relocs": [(src, off, tgt)], "trailer": bytes}`.
  - `Image(prog)`: `.segs` [bytearray], `.bss` [int], `.kinds` [int],
    `.relocs` [(src, off, tgt)], `.n_data` (the program's data segment).
  - `Image.add_lib(name, lib, tr) -> Placed`: appends the library's code
    banks with its core and templates on the last; returns
    `Placed(seg_of={so code seg: image seg}, place={so seg: (image seg,
    offset)}, last, core_at, tmpl_at)`.
  - `Image.reloc(seg, off, tgt)` (dies when `off` is outside `seg`),
    `Image.word_add(seg, off, n)` (mod 65,536), `Image.word_set(seg, off, v)`.

- [ ] **Step 1: Failing test.**  `tests/dyn/test_bind.py`, run from the
  toolchain root, in test_dyn's style (`check()`, `fails`, a summary line):

```python
#!/usr/bin/env python3
"""test_bind.py - fgx_bind's host checks (shared libc SP3 step 4).  Needs a
built tree (build/libc.sigs, lib/*.so.1.0).

Run from the toolchain root: python3 tests/dyn/test_bind.py
"""
import os
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO = os.path.dirname(ROOT)
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "src", "ld"))
import fgx_bind  # noqa: E402
import fgx_imports  # noqa: E402
import fgx_ld  # noqa: E402
import fgx_libso  # noqa: E402
fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def so(name):
    data = open(fgx_libso.so_path(name), "rb").read()
    lib = fgx_bind.parse(data)
    return lib, fgx_ld.read_trailer(lib["trailer"])


def layout():
    """libc's banks, core and templates placed; its relocs renumbered."""
    prog = fgx_bind.parse(open(dyn("hello", os.path.join(HERE, "hello.c"), "libc"),
                               "rb").read())
    img = fgx_bind.Image(prog)
    lib, tr = so("libc")
    p = img.add_lib("libc", lib, tr)
    check(len(img.segs) == 5 and p.seg_of == {0: 2, 1: 3, 2: 4} and p.last == 4,
          "libc's three banks are image segments 2-4", str(p.seg_of))
    core, tmpl = lib["segs"][tr["core"]][0], lib["segs"][tr["templates"]][0]
    last = img.segs[4]
    check(p.core_at == len(lib["segs"][2][0]) and p.tmpl_at == p.core_at + len(core)
          and len(last) == p.tmpl_at + len(tmpl),
          "the core and the templates follow bank 2's bytes", "%d %d %d"
          % (p.core_at, p.tmpl_at, len(last)))
    fx = [(s, o) for s, o, t in img.relocs if t == img.n_data and s == 4]
    check(sorted(o - p.core_at for _s, o in fx) == sorted(tr["fixups"]) and len(fx) == 3,
          "libc's three fixups are relocs to the program's data segment", str(fx))
    moved = [(o, t) for s, o, t in lib["relocs"] if s == tr["core"] and t == tr["templates"]]
    good = all(struct.unpack_from("<H", last, p.core_at + o - 2)[0]
               == (struct.unpack_from("<H", core, o - 2)[0] + p.tmpl_at) & 0xFFFF
               and (4, p.core_at + o, 4) in img.relocs for o, _t in moved)
    check(moved and good, "each block-table pointer's offset moved by the "
          "templates' offset, its bank the last bank's", "%d rows" % len(moved))
    lost = [(s, o, t) for s, o, t in lib["relocs"]
            if (p.place[s][0], p.place[s][1] + o, p.place[t][0]) not in img.relocs]
    check(not lost and sum(1 for s, o, t in img.relocs if s >= 2)
          == len(lib["relocs"]) + 3,
          "every libc reloc is carried at its new place with its new target",
          str(lost[:4]))
    try:
        img.reloc(2, len(img.segs[2]), 3)
    except SystemExit as e:
        check("outside" in str(e), "a reloc past its segment's end is refused", str(e))
    else:
        check(False, "a reloc past its segment's end is refused")


def dyn(name, src, libs):
    """Compile and dynamically link `src'; the fgx_dyn output's path."""
    d = tempfile.mkdtemp(prefix="bind_%s_" % name)
    code, data = os.path.join(d, name + ".s"), os.path.join(d, name + ".data.s")
    subprocess.run([os.path.join(ROOT, "fcc"), "--sigs",
                    os.path.join(REPO, "build", "libc.sigs"),
                    "--data-segment", data, "-o", code, src], check=True)
    out = os.path.join(d, name + ".dyn")
    subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_dyn.py"),
                    "--name", name, "--dir", os.path.join(d, "ld"), "--code", code,
                    "--data", data, "--lib", libs, "--out", out],
                   check=True, stdout=subprocess.DEVNULL)
    return out


layout()
print("FAIL: %d" % len(fails) if fails else "bind checks passed")
sys.exit(1 if fails else 0)
```

Run: `cd toolchain && python3 tests/dyn/test_bind.py`
Expected: `ModuleNotFoundError: No module named 'fgx_bind'`.

- [ ] **Step 2: Implement.**

```python
#!/usr/bin/env python3
"""fgx_bind.py - bind a dynamic program to its shared libraries on the host
(shared libc SP3 spec, section 4): what sub-project 4's ldload does once per
boot (place and bind the libraries) and its binder does at exec (bind the
program), written out as an ordinary FGX3 image the loader runs.

The image is the program's segments, then each library's code banks as CODE
segments, its core template and block templates on the end of its last
bank.  A startup routine at the end of segment 0 copies each core to its
base below HEAP_LIM, sets HEAP_LIM to the lowest, and enters _crt0_lib.

Run: fgx_bind.py --prog P --out F [--lib-dir D] [--so NAME=PATH ...]
                 [--trace] [--no-data-sites]
"""
import argparse
import glob
import os
import re
import struct
import sys
from collections import namedtuple

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_imports  # noqa: E402
import fgx_ld  # noqa: E402

HEADER = 16
KIND_CODE = fgx_ld.KIND_MAP["CODE"]
MAX_SEGS = 8                    # a 9th segment must be LIBC (fgx_ld)
Placed = namedtuple("Placed", "seg_of place last core_at tmpl_at")


def die(msg):
    sys.exit("fgx_bind: " + msg)


def parse(data):
    """A linked FGX2/FGX3 file: header, segments, relocs, trailer bytes."""
    n = data[6]
    segs, pos = [], HEADER + 8 * n
    for i in range(n):
        size, bss, kind = struct.unpack_from("<HHB", data, HEADER + 8 * i)
        segs.append((bytearray(data[pos:pos + size]), bss, kind))
        pos += size
    nrel = struct.unpack_from("<H", data, 11)[0]
    relocs = [struct.unpack_from("<BHB", data, pos + 4 * i) for i in range(nrel)]
    return {"head": bytes(data[:HEADER]), "segs": segs, "relocs": relocs,
            "trailer": bytes(data[pos + 4 * nrel:])}


class Image:
    """The bound image being built: the program's segments first."""

    def __init__(self, prog):
        self.segs = [bytearray(s) for s, _b, _k in prog["segs"]]
        self.bss = [b for _s, b, _k in prog["segs"]]
        self.kinds = [k for _s, _b, k in prog["segs"]]
        self.relocs = list(prog["relocs"])
        self.n_data = prog["head"][7]

    def reloc(self, seg, off, tgt):
        if not 0 <= off < len(self.segs[seg]):
            die("a reloc at segment %d offset %#06x is outside it (%d bytes)"
                % (seg, off, len(self.segs[seg])))
        self.relocs.append((seg, off, tgt))

    def word_add(self, seg, off, n):
        v = struct.unpack_from("<H", self.segs[seg], off)[0]
        struct.pack_into("<H", self.segs[seg], off, (v + n) & 0xFFFF)

    def word_set(self, seg, off, v):
        struct.pack_into("<H", self.segs[seg], off, v & 0xFFFF)

    def add_lib(self, name, lib, tr):
        """The library's code banks as CODE segments, its core template
        and block templates on the end of the last; its relocs renumbered.
        A pointer into the templates gains their new offset; a fixup (a
        core pointer into the core) is a reloc to the program's data
        segment, whose bank the core is copied into."""
        core, tmpl = tr["core"], tr["templates"]
        code = [i for i, (_s, _b, k) in enumerate(lib["segs"]) if k == KIND_CODE]
        if code != list(range(core)) or tmpl != core + 1:
            die("%s: segments %s are not code banks, core, templates"
                % (name, [k for _s, _b, k in lib["segs"]]))
        first = len(self.segs)
        seg_of = {i: first + i for i in code}
        last = first + len(code) - 1
        for i in code:
            self.segs.append(bytearray(lib["segs"][i][0]))
            self.bss.append(0)
            self.kinds.append(KIND_CODE)
        core_at = len(self.segs[last])
        self.segs[last] += lib["segs"][core][0]
        tmpl_at = len(self.segs[last])
        self.segs[last] += lib["segs"][tmpl][0]
        if len(self.segs[last]) > 0xFFFF:
            die("%s: its last bank, core and templates are %d bytes"
                % (name, len(self.segs[last])))
        place = {i: (seg_of[i], 0) for i in code}
        place[core] = (last, core_at)
        place[tmpl] = (last, tmpl_at)
        for src, off, tgt in lib["relocs"]:
            if tgt == core:
                die("%s: a reloc into its core (segment %d offset %#06x); "
                    "fgx_ld makes those fixups" % (name, src, off))
            s, o = place[src]
            t, to = place[tgt]
            if to:
                self.word_add(s, o + off - 2, to)
            self.reloc(s, o + off, t)
        for off in tr["fixups"]:
            self.reloc(last, core_at + off, self.n_data)
        return Placed(seg_of, place, last, core_at, tmpl_at)
```

Run: `cd toolchain && python3 tests/dyn/test_bind.py`
Expected: every check `ok`, `bind checks passed`.

- [ ] **Step 3: Commit** (`feat(ld): fgx_bind lays a library's banks, core and templates into an image`,
  body: the layout, the template pointers, the fixups as relocs to the data
  segment, the loader facts it rests on with file:line; trailers).

---

### Task 2: fgx_bind binds imports: versions, bases, prebound or by name, the trace

**Files:**
- Modify: `toolchain/src/ld/fgx_bind.py` (`find_so`, `Lib`, `bases`,
  `bind_sites`, `fit`, `bind`)
- Modify: `toolchain/tests/dyn/test_bind.py`

**Interfaces:**
- Consumes: Task 1's `parse`, `Image`, `Placed`.
- Produces:
  - (test `delta()`: the one host case where a core moves -- a libc two
    bytes larger under the shipped termlib; `dynsomis` moves libc, which
    has no core sites and nothing above it.)
  - `find_so(name, major, minor, lib_dir, override) -> path` (dies
    `ld.so: <name>.so.<major>: not found`; warns on an older minor).
  - `Lib` = `namedtuple("Lib", "name path lib tr exports placed base delta")`,
    `exports` = `{name: (kind, seg, val, size)}`.
  - `bind(prog_path, lib_dir, override={}, trace=None, patch_data=True) ->
    (Image, entry, report)` -- `trace` a writable file or None; `report`
    `{"libs": {name: "prebound"|"by name"}, "lookups": int, "sites":
    {"call": n, "ptr": n, "data": n}, "lim": int, "lowest": int, "copies":
    [(image seg, core template offset, core base, core size)] in load
    order}`.  (Task
    3 adds the startup routine and the writer.)

- [ ] **Step 1: Failing tests** (append to `test_bind.py`; call `binding()`
  and `delta()` after `layout()`, before the summary):

```python
def repack(path, out, fn):
    """Copy a dynamic program with its IMPS table changed by fn(table)."""
    data = open(path, "rb").read()
    p = fgx_bind.parse(data)
    end = len(data) - len(p["trailer"])
    t = fgx_imports.unpack(fgx_ld.read_dyn_trailer(p["trailer"])["blocks_raw"]["IMPS"])
    fn(t)
    with open(out, "wb") as f:
        f.write(data[:end] + fgx_ld.dyn_trailer(fgx_ld.block(b"IMPS", fgx_imports.pack(t))))
    return out


def moved_libc(d, by):
    """d/libc.so.1.0: libc.so with every data export's address moved by
    `by' in its trailer -- a different CRC, the same core."""
    data = open(fgx_libso.so_path("libc"), "rb").read()
    p = fgx_bind.parse(data)
    tr = fgx_ld.read_trailer(p["trailer"])
    ex = [(n, k, s, (v + by) & 0xFFFF if k == 1 else v, sz)
          for n, k, s, v, sz in tr["exports"]]
    extra = b"".join(fgx_ld.block(t.encode(), b) for t, b in tr["blocks_raw"].items()
                     if t not in ("EXPT", "BLKS", "FIXS"))
    t2 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"], tr["templates"],
                                tr["core_base"], tr["core_size"], ex, tr["blocks"],
                                tr["fixups"], extra)
    out = os.path.join(d, "libc.so.1.0")
    with open(out, "wb") as f:
        f.write(data[:len(data) - len(p["trailer"])] + t2)
    return out


def grown_libc(d):
    """d/libc.so.1.0 and d/libtermlib.so.1.0: a libc whose core is two bytes
    larger -- two bytes on its end, its base and every data export two
    lower, so its CRC differs -- beside the shipped termlib, which must then
    stack two bytes lower and move its core sites."""
    data = open(fgx_libso.so_path("libc"), "rb").read()
    p = fgx_bind.parse(data)
    tr = fgx_ld.read_trailer(p["trailer"])
    segs = [bytearray(s) for s, _b, _k in p["segs"]]
    segs[tr["core"]] += b"\0\0"
    ex = [(n, k, s, (v - 2) & 0xFFFF if k == 1 else v, sz)
          for n, k, s, v, sz in tr["exports"]]
    t2 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"], tr["templates"],
                                tr["core_base"] - 2, tr["core_size"] + 2, ex,
                                tr["blocks"], tr["fixups"])
    head = bytearray(p["head"])
    body = bytearray()
    for (s, b, k), seg in zip(p["segs"], segs):
        body += struct.pack("<HHB3x", len(seg), b, k)
    body += b"".join(segs)
    body += b"".join(struct.pack("<BHB", *r) for r in p["relocs"])
    with open(os.path.join(d, "libc.so.1.0"), "wb") as f:
        f.write(head + body + t2)
    shutil.copy(fgx_libso.so_path("libtermlib"), d)


def delta():
    """A library below that grew moves the one above: termlib's base and its
    core sites two lower, the program's termlib data sites too."""
    tc = dyn("tctest", os.path.join(REPO, "src", "userland", "tctest", "tctest.c"),
             "libc,libtermlib")
    a, _e, ra = fgx_bind.bind(tc, fgx_libso.LIB)
    d = tempfile.mkdtemp(prefix="bind_grown_")
    grown_libc(d)
    b, _e, rb = fgx_bind.bind(tc, d)
    check(rb["libs"] == {"libc": "by name", "libtermlib": "by name"},
          "both libraries bind by name", str(rb["libs"]))
    _lt, ttr = so("libtermlib")
    check(rb["copies"][1][2] == ttr["core_base"] - 2, "termlib stacks two lower",
          "%04X" % rb["copies"][1][2])
    csit = ttr["blocks_raw"]["CSIT"]
    sites = [struct.unpack_from("<BH", csit, 3 * i) for i in range(len(csit) // 3)]
    place = {0: (5, 0), 1: (5, len(_lt["segs"][0][0]))}
    bad = [(s, o) for s, o in sites
           if struct.unpack_from("<H", b.segs[place[s][0]], place[s][1] + o)[0]
           != (struct.unpack_from("<H", a.segs[place[s][0]], place[s][1] + o)[0] - 2) & 0xFFFF]
    check(sites and not bad, "every termlib core site moved by -2",
          "%d sites, %d wrong" % (len(sites), len(bad)))
    t = fgx_imports.unpack(fgx_ld.read_dyn_trailer(
        fgx_bind.parse(open(tc, "rb").read())["trailer"])["blocks_raw"]["IMPS"])
    up = [im for im in t["imports"] if im["name"] == "UP"][0]
    check(all(struct.unpack_from("<H", b.segs[s], o)[0]
              == (struct.unpack_from("<H", a.segs[s], o)[0] - 2) & 0xFFFF
              for s, o in up["data"]),
          "the program's UP sites moved by -2", "%d sites" % len(up["data"]))


def binding():
    hello = dyn("hello", os.path.join(HERE, "hello.c"), "libc")
    t = fgx_imports.unpack(fgx_ld.read_dyn_trailer(
        fgx_bind.parse(open(hello, "rb").read())["trailer"])["blocks_raw"]["IMPS"])
    out = tempfile.mkstemp(prefix="trace_")[1]
    with open(out, "w") as tf:
        img, entry, rep = fgx_bind.bind(hello, fgx_libso.LIB, trace=tf)
    text = open(out).read()
    check(rep["libs"] == {"libc": "prebound"} and rep["lookups"] == 0,
          "hello binds libc prebound, no name looked up", str(rep["libs"]))
    check("libc.so.1 => " in text and "prebound" in text, "the trace names the path",
          text.split("\n")[0])
    lib, tr = so("libc")
    ex = {e[0]: e for e in tr["exports"]}
    bad = []
    for im in t["imports"]:
        for s, o in (im["call"] + im["ptr"] if im["kind"] == 0 else []):
            e = ex[im["name"]]
            if struct.unpack_from("<H", img.segs[s], o)[0] != e[3] \
                    or (s, o + 2, 2 + e[2]) not in img.relocs:
                bad.append(im["name"])
    check(not bad, "every call and pointer site holds its export's offset and "
          "a reloc to its bank's segment", str(bad))
    bm = t["libs"][0]["bitmap"]
    need = sum(sz for i, (_c, _t, sz) in enumerate(tr["blocks"])
               if bm[i >> 3] & (1 << (i & 7)))
    check(rep["lowest"] == tr["core_base"] and rep["lim"] == tr["core_base"] - need,
          "LIM is libc's base less the reached blocks", "%04X" % rep["lim"])

    d = tempfile.mkdtemp(prefix="bind_mis_")
    moved_libc(d, -2)
    img2, _e, rep2 = fgx_bind.bind(hello, d)
    check(rep2["libs"] == {"libc": "by name"} and rep2["lookups"] == len(t["imports"]),
          "against a libc whose data moved, every import is looked up by name",
          "%s %d" % (rep2["libs"], rep2["lookups"]))
    diff = [(s, o) for im in t["imports"] for s, o in im["data"]
            if struct.unpack_from("<H", img2.segs[s], o)[0]
            != (struct.unpack_from("<H", img.segs[s], o)[0] - 2) & 0xFFFF]
    check(not diff and rep2["sites"]["data"] > 0,
          "every data site moved down 2, mod 65,536", str(diff[:4]))
    img3, _e, _r = fgx_bind.bind(hello, d, patch_data=False)
    check(all(img3.segs[s][o:o + 2] == img.segs[s][o:o + 2]
              for im in t["imports"] for s, o in im["data"]),
          "--no-data-sites leaves the data sites as linked")

    older = repack(hello, os.path.join(d, "older.dyn"),
                   lambda tb: tb["libs"][0].update(minor=1))
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_bind.py"),
                        "--prog", older, "--out", os.path.join(d, "o.bin")],
                       capture_output=True, text=True)
    check(r.returncode == 0 and "ld.so: warning: libc.so.1.0 has older revision "
          "than expected 1" in r.stderr, "an older minor binds with SunOS's warning",
          r.stderr.strip()[-200:])
    major = repack(hello, os.path.join(d, "major.dyn"),
                   lambda tb: tb["libs"][0].update(major=2))
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_bind.py"),
                        "--prog", major, "--out", os.path.join(d, "o.bin")],
                       capture_output=True, text=True)
    check(r.returncode != 0 and "ld.so: libc.so.2: not found" in r.stderr,
          "a major with no library is not found", r.stderr.strip()[-200:])
    rows = repack(hello, os.path.join(d, "rows.dyn"),
                  lambda tb: tb["libs"][0].update(bitmap=tb["libs"][0]["bitmap"] + b"\0",
                                                  crc=0))
    try:
        fgx_bind.bind(rows, fgx_libso.LIB)
    except SystemExit as e:
        check("rows" in str(e), "a bitmap for a different block table is refused", str(e))
    else:
        check(False, "a bitmap for a different block table is refused")

    tc = dyn("tctest", os.path.join(REPO, "src", "userland", "tctest", "tctest.c"),
             "libc,libtermlib")
    img4, _e, rep4 = fgx_bind.bind(tc, fgx_libso.LIB)
    check(len(img4.segs) == 6 and rep4["libs"] == {"libc": "prebound",
                                                   "libtermlib": "prebound"},
          "tctest binds libc and libtermlib: six segments", str(rep4["libs"]))
    lt, ttr = so("libtermlib")
    tt = fgx_imports.unpack(ttr["blocks_raw"]["IMPS"])
    calls = [(5, o) for im in tt["imports"] for s, o in im["call"]]
    check(calls and all(any(r[0] == 5 and r[1] == o + 2 and 2 <= r[2] <= 4
                            for r in img4.relocs) for _s, o in calls),
          "termlib's calls into libc get libc's banks", "%d sites" % len(calls))
```

Run: `cd toolchain && python3 tests/dyn/test_bind.py`
Expected: `AttributeError: module 'fgx_bind' has no attribute 'bind'`.

- [ ] **Step 3: Implement.**

```python
Lib = namedtuple("Lib", "name path lib tr exports placed base delta")


def find_so(name, major, minor, lib_dir, override):
    """The library's file: `override' by name, else the highest minor of
    `major' in lib_dir (SunOS cache_rtld.c:145-183)."""
    if name in override:
        path = override[name]
    else:
        pat = re.compile(r"%s\.so\.%d\.(\d+)$" % (re.escape(name), major))
        found = [(int(m.group(1)), p) for p in glob.glob(os.path.join(
            lib_dir, "%s.so.%d.*" % (name, major)))
            for m in [pat.search(os.path.basename(p))] if m]
        if not found:
            die("ld.so: %s.so.%d: not found" % (name, major))
        path = max(found)[1]
    return path


def open_lib(name, major, minor, lib_dir, override):
    path = find_so(name, major, minor, lib_dir, override)
    lib = parse(open(path, "rb").read())
    if not lib["head"][10] & fgx_ld.LIB_FLAG:
        die("%s is not a library" % path)
    tr = fgx_ld.read_trailer(lib["trailer"])
    if tr["major"] != major:
        die("ld.so: %s is version %d; expected %d" % (path, tr["major"], major))
    if tr["minor"] < minor:
        sys.stderr.write("ld.so: warning: %s has older revision than expected "
                         "%d\n" % (os.path.basename(path), minor))
    return path, lib, tr


def bind_sites(img, where, table, libs, obj, trace, patch_data, report):
    """Bind one object's imports: `where' maps its segments to (image
    segment, offset); `table' is its IMPS table."""
    paths = []
    for rec in table["libs"]:
        L = libs.get(rec["name"])
        if L is None:
            die("%s needs %s, which is not bound" % (obj, rec["name"]))
        pre = rec["crc"] == L.tr["crc"] and rec["core_base"] == L.base
        paths.append(pre)
        if trace:
            trace.write("\t%s.so.%d => %s (core $%04X): %s\n" % (
                L.name, L.tr["major"], L.path, L.base, "prebound" if pre else
                "by name (crc %08x, $%04X; linked against %08x, $%04X)"
                % (L.tr["crc"], L.base, rec["crc"], rec["core_base"])))
    for im in table["imports"]:
        rec = table["libs"][im["lib"]]
        L = libs[rec["name"]]
        if paths[im["lib"]]:
            kind, seg, val = im["kind"], im["seg"], im["val"]
            addr = val
        else:
            e = L.exports.get(im["name"])
            report["lookups"] += 1
            if e is None or e[0] != im["kind"]:
                die("ld.so: %s: %s is not a %s export of %s" % (
                    obj, im["name"], "data" if im["kind"] else "code", L.name))
            kind, seg, val, size = e
            if kind == 1 and size < im["size"]:
                die("ld.so: %s: %s is %d bytes in %s; linked against %d"
                    % (obj, im["name"], size, L.name, im["size"]))
            addr = val + L.delta
        if kind == 0:
            tgt = L.placed.seg_of[seg]
            for s, o in im["call"] + im["ptr"]:
                S, O = where[s]
                img.word_set(S, O + o, val)
                img.reloc(S, O + o + 2, tgt)
        elif patch_data:
            for s, o in im["data"]:
                S, O = where[s]
                img.word_add(S, O + o, addr - im["val"])
        for k in fgx_imports.SITES:
            report["sites"][k] += len(im[k])
        if trace:
            trace.write("\t\t%s => %s %s $%04X\n" % (
                im["name"], L.name, "bank %d" % seg if kind == 0 else "data", addr
                if kind else val))


def fit(prog_img, prog_table, libs, lowest):
    """LIM = the lowest core less the blocks the program's bitmaps reach,
    against the libraries bound; the data must end at or below it."""
    need = 0
    for rec in prog_table["libs"]:
        L = libs[rec["name"]]
        rows = L.tr["blocks"]
        if len(rec["bitmap"]) != (len(rows) + 7) // 8:
            die("%s's bitmap is for %d rows; its block table has %d (relink "
                "the program)" % (L.name, len(rec["bitmap"]) * 8, len(rows)))
        need += sum(sz for i, (_c, _t, sz) in enumerate(rows)
                    if rec["bitmap"][i >> 3] & (1 << (i & 7)))
    lim = lowest - need
    end = len(prog_img.segs[prog_img.n_data]) + prog_img.bss[prog_img.n_data]
    if end > lim:
        die("the program's data ends at $%04X, above LIM $%04X (cores from "
            "$%04X, %d bytes of blocks)" % (end, lim, lowest, need))
    return lim


def bind(prog_path, lib_dir, override=None, trace=None, patch_data=True):
    override = override or {}
    prog = parse(open(prog_path, "rb").read())
    if not prog["head"][10] & fgx_ld.DYN_FLAG:
        die("%s is not a dynamic program" % prog_path)
    table = fgx_imports.unpack(fgx_ld.read_dyn_trailer(prog["trailer"])["blocks_raw"]["IMPS"])
    img = Image(prog)
    report = {"libs": {}, "lookups": 0, "sites": {k: 0 for k in fgx_imports.SITES}}
    libs, base = {}, fgx_ld.HEAP_LIM
    if trace:
        trace.write("%s:\n" % os.path.basename(prog_path))
    copies = []
    for rec in table["libs"]:                       # load order
        path, lib, tr = open_lib(rec["name"], rec["major"], rec["minor"],
                                 lib_dir, override)
        base -= tr["core_size"]
        placed = img.add_lib(rec["name"], lib, tr)
        copies.append((placed.last, placed.core_at, base, tr["core_size"]))
        delta = base - tr["core_base"]
        csit = tr["blocks_raw"].get("CSIT", b"")
        for i in range(len(csit) // 3):
            s, o = struct.unpack_from("<BH", csit, 3 * i)
            S, O = placed.place[s]
            img.word_add(S, O + o, delta)
        L = Lib(rec["name"], path, lib, tr,
                {e[0]: tuple(e[1:]) for e in tr["exports"]}, placed, base, delta)
        if "IMPS" in tr["blocks_raw"]:
            if trace:
                trace.write("%s.so.%d:\n" % (rec["name"], tr["major"]))
            bind_sites(img, placed.place, fgx_imports.unpack(tr["blocks_raw"]["IMPS"]),
                       libs, L.name, trace, True, {"lookups": 0, "sites":
                                                   {k: 0 for k in fgx_imports.SITES}})
        libs[L.name] = L
    bind_sites(img, {i: (i, 0) for i in range(len(prog["segs"]))}, table, libs,
               os.path.basename(prog_path), trace, patch_data, report)
    for rec in table["libs"]:
        L = libs[rec["name"]]
        report["libs"][L.name] = ("prebound" if rec["crc"] == L.tr["crc"]
                                  and rec["core_base"] == L.base else "by name")
    report["lowest"] = base
    report["copies"] = copies
    report["lim"] = fit(img, table, libs, base)
    if trace:
        trace.write("\t%d names looked up\n" % report["lookups"])
    return img, struct.unpack_from("<H", prog["head"], 8)[0], report
```

  A library's own imports bind with data patching always on (its sites are
  not the probe's control) and are traced under the library's name.

Run: `cd toolchain && python3 tests/dyn/test_bind.py`
Expected: every check `ok`.

- [ ] **Step 4: Commit** (`feat(ld): fgx_bind binds a program and its libraries, prebound or by name`,
  body: the stacked bases, core deltas and CSIT, the two paths and when each
  is taken, the SunOS version texts quoted with file:line, the bitmap's row
  rule; trailers).

---

### Task 3: the startup routine and the image

**Files:**
- Modify: `toolchain/src/ld/fgx_bind.py` (`startup`, `write`, `main`)
- Modify: `toolchain/tests/dyn/test_bind.py`

**Interfaces:**
- Consumes: Task 2's `bind`.
- Produces: `startup(copies, lowest, entry) -> (bytes, [(offset, target)])`
  with `copies` = `[(image seg of the template, template offset, core base,
  core size)]` and `target` an image segment or the string `"data"`;
  `write(img, head, entry, out)`; the CLI in the module docstring.

- [ ] **Step 1: Failing tests.**

```python
MERLIN_START = """                MX      %%00
                PHP
                REP     #$30
                LDX     #$%04X
                LDY     #$%04X
                LDA     #$%04X
                MVN     $07,$01
                LDA     #$%04X
                STA     $FFF8
                PLP
                JMP     $%04X
"""


def startup():
    """The routine's bytes are what Merlin32 assembles from the same source,
    with MVN's banks in machine order: destination, then source."""
    b, rel = fgx_bind.startup([(4, 0x8CDA, 0xF6A3, 2389)], 0xF6A3, 0x0123)
    d = tempfile.mkdtemp(prefix="bind_start_")
    with open(os.path.join(d, "s.link.s"), "w") as f:
        f.write("                TYP    $06\n                DSK    s\n"
                "                ORG    $0B0000\n" + MERLIN_START
                % (0x8CDA, 0xF6A3, 2388, 0xF6A3, 0x0123))
    subprocess.run(["merlin32", "-V", ".", "s.link.s"], cwd=d, check=True,
                   capture_output=True)
    m = bytearray(open(os.path.join(d, "s"), "rb").read())
    i = 12                      # PHP, REP, LDX, LDY, LDA: 1 + 2 + 3 + 3 + 3
    check(m[i + 1:i + 3] == b"\x01\x07", "Merlin assembles MVN src,dst as 54 dst src",
          m[i:i + 3].hex())
    m[i + 1:i + 3] = b"\0\0"
    check(bytes(b) == bytes(m), "fgx_bind's routine is Merlin's", b.hex())
    check(rel == [(i + 1, "data"), (i + 2, 4)],
          "MVN's destination is the data bank, its source the template's", str(rel))


def image():
    hello = dyn("hello", os.path.join(HERE, "hello.c"), "libc")
    d = tempfile.mkdtemp(prefix="bind_img_")
    out = os.path.join(d, "hello.bin")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_bind.py"),
                        "--prog", hello, "--out", out, "--trace"],
                       capture_output=True, text=True)
    check(r.returncode == 0, "fgx_bind writes hello's image", r.stderr[-300:])
    if r.returncode:
        return
    data = open(out, "rb").read()
    p = fgx_bind.parse(data)
    check(data[10] & (fgx_ld.LIB_FLAG | fgx_ld.DYN_FLAG) == 0 and not p["trailer"],
          "flags bits 1 and 2 clear, no trailer", hex(data[10]))
    check(data[6] == 5 and data[7] == 1 and [k for _s, _b, k in p["segs"]] == [0, 1, 0, 0, 0],
          "five segments: code, data, libc's three banks")
    prog = fgx_bind.parse(open(hello, "rb").read())
    entry = struct.unpack_from("<H", data, 8)[0]
    seg0, old = p["segs"][0][0], struct.unpack_from("<H", prog["head"], 8)[0]
    check(entry == len(prog["segs"][0][0]) and seg0[entry:entry + 3] == b"\x08\xC2\x30",
          "the entry is the routine at segment 0's end: PHP, REP #$30")
    check(seg0[-3] == 0x4C and struct.unpack_from("<H", seg0, len(seg0) - 2)[0] == old,
          "it ends in JMP to _crt0_lib")
    lim = struct.unpack_from("<H", seg0, seg0.index(b"\x8D\xF8\xFF", entry) - 2)[0]
    _lib, tr = so("libc")
    check(lim == tr["core_base"], "it sets HEAP_LIM to libc's core base", "%04X" % lim)
    check(data[13:16] == prog["head"][13:16], "ABI, stack and soft-bank bytes kept")
```

  Add `startup()` and `image()` to the calls.

Run: `cd toolchain && python3 tests/dyn/test_bind.py`
Expected: `AttributeError: module 'fgx_bind' has no attribute 'startup'`.

- [ ] **Step 2: Implement.**

```python
def startup(copies, lowest, entry):
    """The bound image's startup, at the end of segment 0: copy each core
    template to its base in the data bank, set HEAP_LIM to the lowest base,
    enter _crt0_lib.  S, P and DBR are left as the loader set them (MVN
    leaves DBR = its destination, the data bank), so _libc_start still
    finds the kernel's frame at S+4.  MVN's operand bytes are the
    destination bank, then the source bank; both are relocs."""
    b, rel = bytearray(b"\x08\xC2\x30"), []             # PHP; REP #$30
    for seg, off, base, size in copies:
        b += b"\xA2" + struct.pack("<H", off)           # LDX #template
        b += b"\xA0" + struct.pack("<H", base)          # LDY #core base
        b += b"\xA9" + struct.pack("<H", size - 1)      # LDA #size-1
        rel += [(len(b) + 1, "data"), (len(b) + 2, seg)]
        b += b"\x54\x00\x00"                            # MVN
    b += b"\xA9" + struct.pack("<H", lowest)            # LDA #lowest core
    b += b"\x8D" + struct.pack("<H", fgx_ld.HEAP_LIM)   # STA HEAP_LIM
    b += b"\x28"                                        # PLP
    b += b"\x4C" + struct.pack("<H", entry)             # JMP _crt0_lib
    return bytes(b), rel


def write(img, head, entry, out):
    n = len(img.segs)
    if n > MAX_SEGS:
        die("the image needs %d segments; the loader takes %d" % (n, MAX_SEGS))
    rels = sorted(set(img.relocs))
    if len({(s, o) for s, o, _t in rels}) != len(rels):
        die("two relocs at one offset name different segments")
    if len(rels) > 0xFFFF:
        die("%d relocs" % len(rels))
    h = bytearray(head)
    h[6], h[7] = n, img.n_data
    struct.pack_into("<H", h, 8, entry)
    h[10] &= ~(fgx_ld.LIB_FLAG | fgx_ld.DYN_FLAG) & 0xFF
    struct.pack_into("<H", h, 11, len(rels))
    body = bytearray(h)
    for s, b, k in zip(img.segs, img.bss, img.kinds):
        body += struct.pack("<HHB3x", len(s), b, k)
    for s in img.segs:
        body += s
    for r in rels:
        body += struct.pack("<BHB", *r)
    tmp = out + ".tmp"
    try:
        with open(tmp, "wb") as f:
            f.write(body)
        os.replace(tmp, out)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prog", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--lib-dir", default=os.path.join(os.path.dirname(
        os.path.dirname(HERE)), "lib"))
    ap.add_argument("--so", action="append", default=[], help="NAME=PATH")
    ap.add_argument("--trace", action="store_true")
    ap.add_argument("--no-data-sites", action="store_true")
    a = ap.parse_args()
    override = dict(s.split("=", 1) for s in a.so)
    img, entry, rep = bind(a.prog, a.lib_dir, override,
                           sys.stdout if a.trace else None, not a.no_data_sites)
    code, rel = startup(rep["copies"], rep["lowest"], entry)
    at = len(img.segs[0])
    img.segs[0] += code
    if len(img.segs[0]) > 0xFFFF:
        die("segment 0 and the startup routine are %d bytes" % len(img.segs[0]))
    for off, tgt in rel:
        img.reloc(0, at + off, img.n_data if tgt == "data" else tgt)
    head = open(a.prog, "rb").read()[:HEADER]
    write(img, head, at, a.out)
    print("bind %s: %d segments, %d bytes, %d relocs; LIM $%04X"
          % (os.path.basename(a.out), len(img.segs), os.path.getsize(a.out),
             len(set(img.relocs)), rep["lim"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Run: `cd toolchain && python3 tests/dyn/test_bind.py`
Expected: every check `ok`.

- [ ] **Step 3: Makefile.**  `test-archives` runs `python3
  tests/dyn/test_bind.py` after `test_dyn.py`.

Run: `make -C toolchain test-archives 2>&1 | grep -E "bind checks|FAIL"`
Expected: `bind checks passed`.

- [ ] **Step 4: Commit** (`feat(ld): the bound image and its startup routine`,
  body: the routine instruction by instruction, MVN's byte order quoted from
  *Programming the Apple IIgs* p. 157-158 and FGX's block.s, S/P/DBR at
  entry, header flags cleared; trailers).

---

### Task 4: the shared libraries in the build, and `dynso` in MAME

**Files:**
- Modify: `tools/ninja/gen.py` (a `libso` rule and edge for the three `.so`;
  a `dynso` entry beside `libcso`), `tools/ninja/manifest.json` (staging)
- Create: `src/userland/dynso/dynso.c`, `tools/dynso-fgx2/build_dynso.sh`,
  `tools/mame_test/tests/dynso.json`

- [ ] **Step 1: The probe.**  `src/userland/dynso/dynso.c`: libcso.c's
  checks with the program's name read from argv (the same source runs as
  `dynso`, `dynsomis`, `dynsonodata`), the step-3 constructs, and the carve
  through the exported table; `DSO` prefixes its lines.

```c
/*
 * dynso -- shared libc SP3's machine probe: a program linked dynamically
 * (toolchain/src/ld/fgx_dyn.py) and bound on the host
 * (toolchain/src/ld/fgx_bind.py), run as an ordinary image.  One line per
 * check, `DSO <check> ok' or `DSO FAIL <check>', then `DSO ok'.  Built as
 * dynso (prebound), dynsomis (bound by name against a libc whose core
 * moved) and dynsonodata (the same without data-site patching, which must
 * fail).  Spec: docs/history/plans/2026-09-29-shared-libc-sp3-design.md,
 * section 5.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <signal.h>

extern char *strtok(), *strerror(), *asctime(), *sbrk(), *strrchr();
extern struct tm *gmtime();
extern int open(), rand(), fork(), vfork(), wait(), alarm(), pause();
extern void srand(), _exit(), qsort();
extern unsigned __progname;
extern unsigned _libc_blktab[];
extern unsigned char _dyn_bits_libc[];

static int fails;
static char sigbuf[8];
static int anchor;
static char *words[] = { "pear", "apple", "fig" };
int *ep = &errno;               /* a data site in the data segment */
static int (*cmpf)() = strcmp;  /* a pointer cell holding a libc function */

static void
say(what, ok)
char *what;
int ok;
{
    printf(ok ? "DSO %s ok\n" : "DSO FAIL %s\n", what);
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

/* qsort calls back into the program across the far seam. */
static int
bystr(a, b)
char **a, **b;
{
    return strcmp(*a, *b);
}

static void
onalarm(sig)
int sig;
{
    sprintf(sigbuf, "%d", 42);
}

/* _lib_init's carve: the rows the bitmap reaches lie back to back from
 * HEAP_LIM up, below every libc core cell this program names, and add up
 * to what the bitmap asks for. */
static int
carved()
{
    unsigned *t, i, b, need, top, low;

    need = 0;
    top = 0;
    low = 0xFFFF;
    for (t = _libc_blktab, i = 0; t[0]; t += 4, i++) {
        if (!(_dyn_bits_libc[i >> 3] & (1 << (i & 7))))
            continue;
        b = *(unsigned *)(bankof() | t[0]);
        need += t[3];
        if (b < low)
            low = b;
        if (b + t[3] > top)
            top = b + t[3];
    }
    return need > 0 && low == heaplim() && top - low == need &&
        top <= lo((char *)&errno) && top <= lo((char *)_libc_blktab) &&
        top <= lo((char *)&stdout);
}

int
main(argc, argv)
int argc;
char **argv;
{
    char b1[16], b2[16], b3[16], *me;
    char *s1, *s2;
    long t, q;
    int a, n, pid, st;
    unsigned lim;

    me = strrchr(argv[0], '/');
    me = me ? me + 1 : argv[0];
    say("argv", argc == 1 && strncmp(me, "dynso", 5) == 0);
    say("progname", strcmp((char *)(unsigned long)__progname, me) == 0);
    say("zero", strtok((char *)0, " ") == (char *)0);
    a = rand();
    srand(1);
    say("init", a == rand());
    errno = 0;
    say("errno", open("/nonexistent/x", 0, 0) < 0 && errno == ENOENT &&
        *ep == ENOENT);
    say("literal", strcmp(strerror(ENOENT), "No such file or directory") == 0);
    strcpy(b1, "a b c");
    s1 = strtok(b1, " ");
    s2 = strtok((char *)0, " ");
    say("strtok", strcmp(s1, "a") == 0 && strcmp(s2, "b") == 0 &&
        strcmp(strtok((char *)0, " "), "c") == 0);
    t = 0;
    s1 = asctime(gmtime(&t));
    say("asctime", strcmp(s1, "Thu Jan  1 00:00:00 1970\n") == 0);
    t = 86400L;
    s2 = asctime(gmtime(&t));
    say("again", s1 == s2 && strcmp(s2, "Fri Jan  2 00:00:00 1970\n") == 0);
    qsort(words, 3, sizeof words[0], bystr);
    say("qsort", strcmp(words[0], "apple") == 0 && strcmp(words[2], "pear") == 0);
    say("pointer", (*cmpf)("fig", "fig") == 0 && (*cmpf)("a", "b") < 0);
    say("stdout", fflush(stdout) == 0);     /* LDA stdout+2 / LDA stdout */
    q = 1000000L;
    n = 7;
    say("ldiv", q / (long)n == 142857L && -q / (long)n == -142857L);
    say("carve", carved());
    lim = heaplim();

    strcpy(b2, "p1 p2 p3");
    strtok(b2, " ");
    pid = fork();
    if (pid == 0)
        _exit(strcmp(strtok((char *)0, " "), "p2") == 0 ? 0 : 1);
    wait(&st);
    say("fork", st == 0 && strcmp(strtok((char *)0, " "), "p2") == 0);
    strcpy(b3, "v1 v2 v3");
    strtok(b3, " ");
    pid = vfork();
    if (pid == 0) {
        strtok((char *)0, " ");
        _exit(0);
    }
    wait(&st);
    say("vfork", strcmp(strtok((char *)0, " "), "v3") == 0);

    /* FGX's pause() is a 60-tick sleep and alarm(1) is 60 ticks, so one
     * pause can end before the alarm is delivered. */
    signal(SIGALRM, onalarm);
    alarm(1);
    for (a = 0; a < 5 && !sigbuf[0]; a++)
        pause();
    say("signal", strcmp(sigbuf, "42") == 0);

    s1 = sbrk(0);
    s2 = sbrk(lim - lo(s1));
    say("sbrk", s2 != (char *)-1 && sbrk(1) == (char *)-1 && heaplim() == lim &&
        strcmp(asctime(gmtime(&t)), "Fri Jan  2 00:00:00 1970\n") == 0);

    printf(fails ? "DSO FAIL %d\n" : "DSO ok\n", fails);
    return fails != 0;
}
```

- [ ] **Step 2: The build.**  `tools/dynso-fgx2/build_dynso.sh`, one binary
  per call, as build_libcso.sh is:

```bash
#!/bin/bash
# The shared libc SP3 machine probes: a program linked dynamically
# (toolchain/src/ld/fgx_dyn.py) and bound on the host
# (toolchain/src/ld/fgx_bind.py).  $1 names the binary: dynso (bound
# prebound), dynsomis (bound by name against a libc.so whose core is two
# bytes larger, so its CRC and every data address differ), dynsonodata
# (dynsomis's bind without data-site patching: must fail) or cursso
# (libcurses, libtermlib, libc).  The bind's trace is kept beside the binary.
set -eu
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
LD="$REPO/toolchain/src/ld"
name="$1"
case "$name" in
  dynso|dynsomis|dynsonodata) src=dynso/dynso.c; libs=libc ;;
  cursso) src=cursso/cursso.c; libs=libcurses ;;
  *) echo "build_dynso.sh: dynso, dynsomis, dynsonodata or cursso" >&2; exit 2 ;;
esac
"$REPO/toolchain/fcc" --sigs "$REPO/build/libc.sigs" \
    --data-segment "$name.data.s" -o "$name.s" "$REPO/src/userland/$src"
python3 "$LD/fgx_dyn.py" --name "$name" --dir "$name.ld" --code "$name.s" \
    --data "$name.data.s" --lib "$libs" --out "$name.dyn"
bind="--trace"
if [ "$name" = dynsomis ]; then
    rm -rf mis
    mkdir -p mis
    python3 "$LD/fgx_libso.py" --core-pad 2 --out mis/libc.so.1.0 --dir mis/ld
fi
case "$name" in
  dynsomis) bind="$bind --so libc=mis/libc.so.1.0" ;;
  dynsonodata)
    [ -f mis/libc.so.1.0 ] || { echo "build_dynso.sh: build dynsomis first" >&2; exit 2; }
    bind="$bind --so libc=mis/libc.so.1.0 --no-data-sites" ;;
esac
python3 "$LD/fgx_bind.py" --prog "$name.dyn" --out "$name.bin" $bind > "$name.trace"
case "$name" in
  dynso|cursso) grep -q "prebound" "$name.trace" && ! grep -q "by name" "$name.trace" ;;
  *) grep -q "libc.so.1 => .*by name" "$name.trace" ;;
esac
```

  (Task 5 adds `--core-pad` to fgx_libso; until then only `dynso` and
  `cursso` build.  The script's outputs -- `*.s`, `*.data.s`, `*.ld/`,
  `*.dyn`, `*.bin`, `*.trace`, `mis/` -- go in `.gitignore` beside
  `tools/libcso-fgx2`'s.)

- [ ] **Step 3: ninja.**  In `gen.py`, beside the `tclibs` edge: a rule
  `libso` whose command is `make -C toolchain libso_all`, with `restat = 1`
  (as `tclibs` has: make leaves an up-to-date `.so` untouched, and without
  restat the edge and every probe would be dirty on each `ninja all`).
  Its OUTPUTS are what only `libso_all` makes (Makefile:63-68 and the
  `.so` rules): `toolchain/lib/libtermlib_so.s`, `libtermlib_so_data.s`,
  `libtermlib_so.blocks.json`, `libcurses_so.s`, `libcurses_so_data.s`,
  `libcurses_so.blocks.json`, `libtermlib.so.1.0` and `libcurses.so.1.0`.
  `libc.so.1.0` is not among them: `tclibs` already makes it (`piles`
  depends on `libc_so`, Makefile:79, 122) as an undeclared side output;
  declare it as a `tclibs` output instead, so the probes can depend on it.
  Inputs: the `tclibs` outputs, `lib/libc.so.1.0`, `lib/libtermlib_helpers.s`,
  `lib/libtermlib_helpers_data.s`, each library's `data.exports` and
  `core.list`, `LIBSO_LD`'s Python, order-only on `toolchain/fcc`.  It is
  downstream of `tclibs` (itself downstream of `fccbuild`), so no two `make`
  runs share the tree.  Measured cost: termlib 0.4 s, curses 3.5 s (libc.so's
  23 s is already `tclibs`'s).
  A `dynso` entry beside `libcso`'s: `out="tools/dynso-fgx2/dynso.bin"`,
  `script="tools/dynso-fgx2/build_dynso.sh dynso"`,
  `links=["tools/dynso-fgx2/build_dynso.sh"]` (`shell_deps` reads
  `spec["links"][0]` unconditionally, gen.py:1525),
  `gate="src/userland/dynso"`, `globs=["src/userland/dynso/*"]`, `extra`
  = fgx_dyn.py, fgx_bind.py, fgx_imports.py, fgx_sites.py, fgx_static.py,
  crt0_lib.s, `hard` = the three `.so` and `build/libc.sigs`.
  `manifest.json` staging: `tools/dynso-fgx2/dynso.bin` ->
  `disk_src/testbin/dynso`.

- [ ] **Step 4: The manifest.**  `tools/mame_test/tests/dynso.json`:

```json
{
 "name": "dynso",
 "description": "Shared libc SP3: a program linked dynamically against libc.so and bound prebound on the host (fgx_bind), run as an ordinary image: libcso's checks plus a pointer cell (qsort/strcmp), &errno in data, stdout's pointer, a far helper through its thunk, and the carve below the copied core.",
 "command": "/testbin/dynso",
 "timeout_s": 120,
 "expect": {
  "screen_contains": ["DSO ok"],
  "screen_lacks": ["DSO FAIL", "libc: no room", "PANIC", "BRK"]
 }
}
```

- [ ] **Step 5: Build and run.**  Announce: `ninja all` on
  `feat/shared-libc`, then one headless MAME run.

Run: `ninja all 2>&1 | tail -3 && tools/dynso-fgx2/build_dynso.sh dynso >/dev/null; cat tools/dynso-fgx2/dynso.trace | head -3 && tools/mame_test/run.py dynso --fresh 2>&1 | tail -5`
Expected: the trace's `libc.so.1 => ... prebound`; the run passes (`DSO ok`).
If a check fails, the probe's lines say which; debug with
superpowers:systematic-debugging before touching the binder.

- [ ] **Step 6: Mutation.**  Temporarily drop the `PLP` from `startup`: the
  `PHP`'s byte stays on the stack, so `_libc_start` reads the kernel's
  frame one byte off and the run must fail `argv`/`progname`.  Announce the
  rebuild and the run; watch it fail; restore, rebuild, rerun green.

- [ ] **Step 7: Commit** (`test(dynso): a dynamically linked, host-bound probe runs in MAME`,
  body: what the probe checks, the ninja edge for the `.so` files, the run's
  result, the mutation; trailers).

---

### Task 5: `dynsomis` and its control `dynsonodata`

**Files:**
- Modify: `toolchain/src/ld/fgx_libso.py` (`--core-pad N`: `build(name,
  out, d, core_pad=0)`, `link_lib(..., core_pad=0)`, `core_link(...,
  core_pad=0)`)
- Modify: `tools/ninja/gen.py` (entries `dynsomis`, `dynsonodata`, each
  with dynso's fields including `links`; `dynsonodata` `hard` on
  `tools/dynso-fgx2/dynsomis.bin`),
  `tools/ninja/manifest.json`
- Create: `tools/mame_test/tests/dynsomis.json`, `dynsonodata.json`

- [ ] **Step 1: `--core-pad`.**  `core_link` appends, after the block
  table, a section `_<lib>_pad` holding `_<lib>_pad DS <n>` when `core_pad`
  is non-zero, so the core grows by `n` bytes and every core address moves
  down `n`; `main` accepts `--core-pad N` before `--out`.  With 0 the core
  is as before.

Run: `cd toolchain && python3 src/ld/fgx_libso.py --core-pad 2 --out /tmp/pad/libc.so.1.0 --dir /tmp/pad/ld && python3 -c "import sys; sys.path.insert(0,'src/ld'); import fgx_imports as i; a=i.file_trailer(open('lib/libc.so.1.0','rb').read()); b=i.file_trailer(open('/tmp/pad/libc.so.1.0','rb').read()); print(hex(a['core_base']), hex(b['core_base']), a['crc']!=b['crc'])"`
Expected: `0xf6a3 0xf6a1 True`.  The build takes about 23 s (the shipped
libc.so's link, measured): the cost dynsomis adds to `ninja all` whenever
libc's sources or the linker change.  Use the scratchpad, not `/tmp`, when executing.

- [ ] **Step 2: Build and run.**  Announce: `ninja all`, then two headless
  MAME runs.  Manifests: `dynsomis.json` as dynso's with
  `"command": "/testbin/dynsomis"`; `dynsonodata.json`:

```json
{
 "name": "dynsonodata",
 "description": "The control for dynsomis: the same by-name bind with data-site patching off must fail -- the probe's data reads land two bytes off in libc's moved core.",
 "command": "/testbin/dynsonodata; S=st; echo $S=$?",
 "timeout_s": 120,
 "expect": {
  "screen_contains": ["st="],
  "screen_lacks": ["DSO ok", "st=0", "PANIC"]
 }
}
```

  (The indirection is bytecat.json's: `check_vacuous_assertions.py`,
  gate.sh:309, refuses a needle that the typed command line itself shows.)

Run: `python3 tools/check_vacuous_assertions.py && tools/mame_test/run.py dynsomis --fresh 2>&1 | tail -3; tools/mame_test/run.py dynsonodata --fresh 2>&1 | tail -3`
Expected: both pass -- dynsomis prints `DSO ok` through the by-name path;
dynsonodata does not.

- [ ] **Step 3: Commit** (`test(dynso): bound by name against a moved libc core, with its control`).

---

### Task 6: `cursso`

**Files:**
- Create: `src/userland/cursso/cursso.c`, `tools/mame_test/tests/cursso.json`
- Modify: `tools/ninja/gen.py` (entry `cursso`, with dynso's fields
  including `links`), `tools/ninja/manifest.json`

- [ ] **Step 1: The probe.**  Read `toolchain/include/curses.h` for the
  `WINDOW` fields and `src/userland/tctest/tctest.c` for tgoto's argument
  order (tcdata's `5 10 -> ^[[11;6H`), then:

```c
/*
 * cursso -- a curses program linked dynamically against libcurses.so,
 * libtermlib.so and libc.so and bound on the host (shared libc SP3,
 * section 5): the screen through initscr/addstr/refresh/endwin, curses's
 * core data read by the program (LINES, COLS, stdscr), and termlib's
 * (UP, which curses's setterm fills and the program reads through its own
 * import).  `CURS <check> ok' per check, then `CURS ok'.
 */
#include <curses.h>
#include <string.h>

extern char *UP, *CM, *tgoto();
extern int tgetent();

static int fails;

static void
say(what, ok)
char *what;
int ok;
{
    printf(ok ? "CURS %s ok\n" : "CURS FAIL %s\n", what);
    if (!ok)
        fails++;
}

int
main()
{
    char buf[32];
    int lines, cols;

    initscr();
    move(1, 2);
    addstr("CURSSO");
    refresh();
    lines = LINES;
    cols = COLS;
    endwin();
    say("size", lines > 0 && cols > 0 && lines == LINES && cols == COLS);
    say("stdscr", stdscr != (WINDOW *)0 && stdscr->_maxy == LINES &&
        stdscr->_maxx == COLS);
    say("up", UP != (char *)0 && strcmp(UP, "\033[A") == 0);
    say("tgoto", strcmp(tgoto(CM, 5, 10), "\033[11;6H") == 0);
    say("tgetent", tgetent(buf, "vt100") == 1);
    printf(fails ? "CURS FAIL %d\n" : "CURS ok\n", fails);
    return fails != 0;
}
```

- [ ] **Step 2: Build and run.**  `cursso.json` as tcdata's (`boot_s` 45,
  `exit_on_prompt` `fgx#`), `screen_contains` `["CURS ok"]`,
  `screen_lacks` `["CURS FAIL", "PANIC", "BRK"]`.  Announce `ninja all`
  and one headless MAME run.

Run: `grep -c "prebound" tools/dynso-fgx2/cursso.trace; tools/mame_test/run.py cursso --fresh 2>&1 | tail -3`
Expected: 6 -- the program's three libraries, termlib's libc and curses's
libc and libtermlib, all prebound; the run passes.

- [ ] **Step 3: Commit** (`test(cursso): a curses program bound against all three libraries runs in MAME`).

---

### Task 7: measure, record, gate

- [ ] **Step 1: Measure.**  For dynso and cursso: the bound image's bytes
  against the same source linked by fgx_static (dynso only: fgx_static is
  libc-only), the program's own bytes (segments 0 and 1) in each, the
  per-process data (data segment + cores + reached blocks), and the sites
  of each kind from the trace.  `ninja all`'s added seconds, measured: the
  `libso` edge (~4 s), the four probes, dynsomis's second libc link
  (~23 s) -- against the gate's own time.

- [ ] **Step 2: The spec.**  Section 4: the binder as built (layout, the
  startup routine's bytes, the two paths, the bitmap-row rule).  Section
  5: `HEAP_LIM`'s exact value is checked on the host (the routine's `LDA #`
  operand), the carve below it on the machine -- say so beside the
  requirement.  Section 8:
  "Step 4 landed <date>" with the numbers and the four MAME results.

- [ ] **Step 3: The gate** (fgx_libso and gen.py changed).  Announce it.

Run: `tools/gate.sh 2>&1 | tail -3`
Expected: `GATE GREEN`.

- [ ] **Step 4: Commit and the project notes** (`group_id="fgx"`): step 4 landed;
  the bound image's layout; MVN's byte order; SP3 done.
