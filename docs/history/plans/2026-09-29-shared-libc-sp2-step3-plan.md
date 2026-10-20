# Shared libc SP2 step 3: the libc.so link -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `make -C toolchain libc_so` links step 2's library-mode output into
`lib/libc.so.1.0`: an FGX3 file of N code banks, a core template assembled
where the core sits in every process, and a block-template segment, followed
by a trailer holding the export table and its checksum, the member-block
table and the per-process fixup list.  `tools/libc_so_check.py` proves what
the file holds, with a positive control.

**Architecture:** A new driver, `toolchain/src/ld/fgx_libso.py`, does what
fgx_ld cannot (fgx_ld takes pre-assembled segments): it splits
`lib/libc_so.s` into its `FGX_SECT` sections, measures each with Merlin32,
packs the functions into banks first-fit by decreasing size, gives each bank
a copy of every string literal its functions name (the first bank's copy is
the one exported, so data pointers land there), assembles the core at
`HEAP_LIM - core size` and the templates at 0, assembles every bank and
checks each came out the size predicted, then runs fgx_ld on a manifest.
fgx_ld gains two things: a per-segment `org` (a segment assembled away from
address 0), and a `library` manifest block that turns core-to-core relocs
into fixups, refuses pointers into or out of blocks, enforces `core.list`,
cross-checks the blocks file against the template segment, and appends the
trailer.

**Tech Stack:** Python 3 (`fgx_libso.py`, `fgx_ld.py`, the checker), C (one
fcc fix in `main.c`), Merlin32, make.

**Spec:** `docs/history/plans/2026-09-28-shared-libc-sp2-design.md`, sections
3, 4, 7 item 3 and 8.  Found while planning, and settled here:

- fcc's data sectioning splits every block template apart: `--sections`'
  post-pass (`main.c` `data_sections`) wraps each template static in its own
  section and leaves the last block cell's section open, so
  `fgx_gc.split_sections` dies on `lib/libc_so_data.s` ("FGX_SECT inside
  section _libc_blk_syslog").  Task 1 fixes it; nothing links libc_so yet, so
  no shipped binary changes.
- `fcc_runtime.s` has no sections, so a bank cannot take only the helpers its
  functions use (spec section 6).  Every bank carries the whole runtime, as
  each tcsh bank does today; selecting per bank needs `fcc_runtime.s`
  sectioned, which belongs with step 5's helper measurement.
- Merlin32 refuses an object over 64 KB ("Object code size > 64 KB"), so the
  sections are measured in several assemblies.
- fcc's string members (`memcmp`, `memcpy`, `strcat`, ...) name the shims'
  direct-page cells `c_strcmp_a`/`c_strcmp_b` (`fcc_libc_shims.s:70-71`) on
  63 rows, so every code bank without the shims defines them, as tcsh's banks
  define `LIBC_DP_*` (`tools/tcsh-fgx2/seg3.link.s`).
- A core assembled at `HEAP_LIM - size` puts listing addresses at `$Fxxx`,
  where fgx_ld reads them as segment offsets: hence the per-segment `org`.
  A pointer INTO such a segment still needs the address, so where fgx_ld
  patches one it adds the target segment's `org` back.
- The data exports are exactly spec section 4's list -- the extern data
  libc's public headers declare -- kept in `toolchain/lib/libc_c/data.exports`.
  The link refuses one the core does not define.  The rest of the core
  (~290 hand-written cells, `_libc_FILE_table`, `__sys_c`, ...) is libc's own
  and stays out of the table, so editing one does not move the checksum
  programs are prebound against.
- Spec section 8's "every member whose code names slot S has S's owner in its
  closure" is about the members a static program selects; libc.so holds every
  member, so it is step 4's check.

## Global Constraints

- ASCII only; comments describe the current state; commit bodies
  informational, ending with
- Any fcc parser/codegen change quotes the deciding K&R Appendix A sentence
  in its commit, read via gs-mcp `kr_c`.  Task 1 changes output packaging,
  not C semantics; its commit says so.
- fgx_ld without `org` or `library` is byte-identical: relinking cat, sh and
  tcsh from their manifests gives the same bytes before and after (Task 3).
- The library link fails loudly on anything it cannot place: a function
  larger than a bank, a section that assembles to a different size than
  measured, a `core.list` name no member defines, a pointer into a block, a
  template whose size disagrees with the blocks file -- a message naming it,
  never a silent output.
- Data exports are `toolchain/lib/libc_c/data.exports` and nothing else;
  code exports are every non-static code name.
- Container: FGX3 as every FGX3 binary; libc's version (1.0) is in the
  trailer.  Header flags bit 1 (`$02`) says a library trailer follows the
  relocs.  At most 6 code banks: fgx_ld allows 9 segments only when the
  ninth is a LIBC segment, so 8, less the core and the templates.
- Host checks only; nothing new in MAME.  `make test-archives` runs the new
  checks.  The gate runs once at the end (fgx_ld links every binary).
- Branch `feat/shared-libc`, not pushed; announce every rebuild.

## Trailer format (written by Task 5, read by Task 6)

After the reloc table, when header flags bit 1 is set.  Little-endian.

| Field | Bytes |
|---|---|
| magic `FGXL` | 4 |
| libc major, minor | 1, 1 |
| core segment index, template segment index | 1, 1 |
| core base (its address in every process's data bank), core size | 2, 2 |
| export count, block count, fixup count | 2, 2, 2 |
| checksum: CRC-32 of the export records as stored | 4 |
| exports, sorted by name, index = ordinal: name length, name, kind (0 code, 1 data), segment, value (code: segment offset; data: data-bank address). Data exports are `data.exports`' names only | 1+n+1+1+2 each |
| blocks, by member name: cell address in the core, template offset in the template segment, size | 2+2+2 each |
| fixups: core segment offset of a far pointer's bank byte, where `_libc_init` writes the process's data bank | 2 each |

## Review Focus

1. A literal named by functions in two banks -- both banks hold a copy, only
   the first exports it, and a data pointer to it lands on that copy (Task 2
   self-test; fgx_ld refuses a name two segments export, so a second exported
   copy fails the link instead of binding one at random).
2. A section that assembles to a different size inside its bank than when
   measured (Merlin choosing an operand width by a label's value) -- the
   driver must die naming the bank and both sizes, never ship (Task 4).
3. A segment assembled at a nonzero `org` -- every listing address fgx_ld
   reads (relocs, exports, farcalls) must become a segment offset, and every
   pointer patched to point INTO it must get the address (offset + org); one
   missed patches the wrong byte or writes the wrong value (Task 3's
   assembled fixture checks the patched bytes).
4. A blocks file out of step with the data file (a stale `libc_so.blocks.json`)
   -- the template sizes must disagree and the link must die (Task 5 test).
5. A new core-to-core pointer in libc (`static char *p = buf;` made core) --
   it becomes a fixup automatically; the checker lists every fixup by label
   so a new one is seen (Task 6).

---

### Task 1: fcc -- a block template is one data section

**Files:**
- Modify: `toolchain/src/cc/main.c` (`data_sections`, around lines 52-137)
- Test: `toolchain/tests/libso/test_libso.py`

**Interfaces:**
- Produces: with `--libso --sections`, each `<member>__BT` template is ONE
  section holding the template label and every static of that member, and
  every `_libc_blk_<member>` cell is its own closed section.
  `fgx_gc.split_sections` accepts the data file.

- [ ] **Step 1: Write the failing test.**  In `test_libso.py`, before the
  run list at the bottom, add:

```python
def template_sections():
    r, d, _ = fcc("umb.c", "--sections")
    check(r.returncode == 0, "umb.c compiles with --sections", r.stderr.strip()[:200])
    if r.returncode:
        return
    sys.path.insert(0, os.path.join(ROOT, "src", "ld"))
    import fgx_gc
    lines = open(os.path.join(d, "o.data.s")).read().split("\n")
    try:
        units = fgx_gc.split_sections(lines, "o.data.s")
    except SystemExit:
        check(False, "fgx_gc splits the library-mode data file")
        return
    sects = [u for u in units if u[0] == "sect"]
    names = [u[1] for u in sects]
    check(len(names) == len(set(names)), "no data section name repeats",
          str(sorted(n for n in names if names.count(n) > 1)))
    a = [u for u in sects if u[1] == "a__BT"]
    body = "\n".join(a[0][2]) if a else ""
    check(len(a) == 1 and "a_count" in body and "a_buf" in body and "calls" in body,
          "member a's template is one section holding all its statics")
```

  and add `template_sections()` to the run list after `macro_owner()`.

- [ ] **Step 2: Run it and watch it fail.**

Run: `cd toolchain && python3 tests/libso/test_libso.py`
Expected: `FAIL fgx_gc splits the library-mode data file` (fgx_gc prints
"FGX_SECT inside section _libc_blk_b" first).

- [ ] **Step 3: Pass an emitter-delimited section through whole.**  In
  `data_sections`, declare `int verbatim = 0;` beside `open`, and insert
  this in the `for` body right after its two declarations
  (`const char *l = ln[i];` and `const char *lab = NULL;`):

```c
        if (verbatim) {
            fprintf(g_data_out, "%s\n", l);
            if (dsec_starts(l, "FGX_ENDS"))
                verbatim = 0;
            continue;
        }
        if (dsec_starts(l, "FGX_SECT")) {
            if (open)
                fprintf(g_data_out, "                FGX_ENDS\n");
            open = 0;
            verbatim = 1;
            fprintf(g_data_out, "%s\n", l);
            continue;
        }
```

  Add to the function's header comment: "A section fcc delimited itself -- a --libso
  block template, whose statics sit at offsets the code has compiled in --
  passes through whole."

- [ ] **Step 4: Run the tests.**

Run: `cd toolchain && make fcc && python3 tests/libso/test_libso.py && python3 tests/sections.py && make libc_so && python3 ../tools/check_libso_identity.py && python3 -c "import sys; sys.path.insert(0,'src/ld'); import fgx_gc; u=fgx_gc.split_sections(open('lib/libc_so_data.s').read().split(chr(10)),'d'); print(sum(1 for x in u if x[0]=='sect' and x[1].endswith('__BT')))"`
Expected: `libso checks passed`; sections.py passes; identity clean (88 /
478); the last line prints `37`.

- [ ] **Step 5: Commit.**

```bash
git add toolchain/src/cc/main.c toolchain/tests/libso/test_libso.py
git commit -m "fix(fcc): a library-mode block template is one data section

--sections' data pass wrapped each static of a --libso block template in a
section of its own and left the last block cell's section open, so fgx_gc
refused lib/libc_so.s's data file and could have dropped a template's
statics apart from the offsets the code uses.  A section fcc delimits itself
now passes through whole.  Output packaging only: no K&R section governs the
section markers, and nothing outside --libso emits one into the data file.

```

---

### Task 2: fgx_libso.py -- split, literal map, packing

**Files:**
- Create: `toolchain/src/ld/fgx_libso.py`

**Interfaces:**
- Consumes: `fgx_gc.split_sections(lines, path)`, `fgx_gc.code_of(rows)`,
  `fgx_gc.IDENT`, `fgx_gc.fgx2_rows(rows)`.
- Produces (used by Task 4):
  - `PREFIX = "_libc_c_"`, `LIT = re.compile(r"^_libc_c_S\d+$")`
  - `split_code(lines, path) -> (units: {name: [rows]}, order: [name])`
  - `literal_refs(units, names) -> {name: sorted [literal]}`
  - `pack(sizes, refs, lsizes, budgets) -> (banks, held, free) | None`
  - `pack_min(sizes, refs, lsizes, budget0, budgetn, nmax) -> (banks, held, free)`
  - `place_orphans(need, held, free, lsizes) -> None` (updates held/free)
  - `canonical(held) -> {literal: bank}`
  - `bank_rows(units, order, funcs, held_b, canon, b) -> [rows]`

- [ ] **Step 1: Write the module with its self-test first, functions as
  stubs raising `NotImplementedError`,** then run it and watch the self-test
  fail.  The self-test (the module's `--self-test`):

```python
def self_test():
    units = {
        "f": ["                FGX_SECT f", "                FGX2_EXPORT f",
              "f   ENT", "    LDA #_libc_c_S1", "    RTL", "                FGX_ENDS"],
        "g": ["                FGX_SECT g", "                FGX2_EXPORT g",
              "g   ENT", "    LDA #_libc_c_S1", "    LDA #_libc_c_S2",
              "    FGX2_FARCALL f", "    RTL", "                FGX_ENDS"],
        "h": ["                FGX_SECT h", "                FGX2_EXPORT h",
              "h   ENT", "    RTL", "                FGX_ENDS"],
        "_libc_c_S1": ["                FGX_SECT _libc_c_S1",
                       "                FGX2_EXPORT _libc_c_S1",
                       "_libc_c_S1  HEX 41,00", "                FGX_ENDS"],
        "_libc_c_S2": ["                FGX_SECT _libc_c_S2",
                       "                FGX2_EXPORT _libc_c_S2",
                       "_libc_c_S2  HEX 42,00", "                FGX_ENDS"],
    }
    order = ["f", "g", "h", "_libc_c_S1", "_libc_c_S2"]
    refs = literal_refs(units, ["f", "g", "h"])
    assert refs == {"f": ["_libc_c_S1"], "g": ["_libc_c_S1", "_libc_c_S2"], "h": []}, refs
    sizes = {"f": 100, "g": 60, "h": 50}
    lsizes = {"_libc_c_S1": 10, "_libc_c_S2": 5}
    # f (110 with S1) fills bank 0 to 20 free; g (75 with both) goes to bank 1;
    # h (50) does not fit bank 0's 20 and takes bank 1's last 55.
    banks, held, free = pack(sizes, refs, lsizes, [130, 130])
    assert banks == [["f"], ["g", "h"]], banks
    assert held == [{"_libc_c_S1"}, {"_libc_c_S1", "_libc_c_S2"}], held
    assert free == [20, 5], free
    assert pack(sizes, refs, lsizes, [100, 100]) is None      # f + S1 fits nowhere
    assert pack_min(sizes, refs, lsizes, 130, 130, 4)[0] == banks
    canon = canonical(held)
    assert canon == {"_libc_c_S1": 0, "_libc_c_S2": 1}, canon
    rows1 = bank_rows(units, order, banks[1], held[1], canon, 1)
    text1 = "\n".join(rows1)
    assert "FGX2_EXPORT _libc_c_S2" in text1
    assert "FGX2_EXPORT _libc_c_S1" not in text1 and "_libc_c_S1  HEX" in text1
    assert rows1[-1].split() == ["FGX2_RELOC_COUNT", str(fgx_gc.fgx2_rows(rows1[:-1]))]
    rows0 = bank_rows(units, order, banks[0], held[0], canon, 0)
    assert "FGX2_EXPORT _libc_c_S1" in "\n".join(rows0)
    held2, free2 = [set(), set()], [3, 20]
    place_orphans({"_libc_c_S2", "_libc_c_S1"}, held2, free2, lsizes)
    assert held2 == [set(), {"_libc_c_S1", "_libc_c_S2"}] and free2 == [3, 5]
    lines = ["                FGX2_MODE 2", "                MX      %00"] + \
        units["f"] + units["_libc_c_S1"] + ["]__lc_fltused   =       1"]
    u, o = split_code(lines, "t.s")
    assert o == ["f", "_libc_c_S1"] and u["f"] == units["f"], o
    try:
        split_code(["x  EQU 1"], "t.s")
    except SystemExit:
        pass
    else:
        raise AssertionError("an unsectioned definition must be refused")
    print("fgx_libso: self-test OK")
```

Run: `cd toolchain && python3 src/ld/fgx_libso.py --self-test`
Expected: FAIL with `NotImplementedError`.

- [ ] **Step 2: Implement the functions.**

```python
#!/usr/bin/env python3
"""fgx_libso.py - link libc's library-mode compile into libc.so (shared libc
SP2 spec, sections 3 and 4).

fgx_ld links segments that are already assembled; libc.so's code is one
compile of every member, far larger than a bank.  This driver splits
lib/libc_so.s into its FGX_SECT sections, measures each, packs the functions
into banks, gives each bank a copy of every string literal its functions
push with PHK, assembles the core template where the core sits in every
process and the block templates, assembles each bank, and hands the
segments to fgx_ld.

A literal used from two banks is in both.  Only the copy in the first bank
that holds it is exported, so a data-segment pointer to it (FGX2_LONG_PTR)
resolves there; nothing in libc compares literal addresses (K&R A.2.6 leaves
identical literals' distinctness to the implementation).

Run: python3 src/ld/fgx_libso.py [--self-test]      (from toolchain/)
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fgx_gc  # noqa: E402

PREFIX = "_libc_c_"                      # fcc's static and literal prefix for libc_c.c
LIT = re.compile(r"^_libc_c_S\d+$")      # a string literal's section
LOOSE_OK = ("MX", "FGX2_MODE", "FGX2_RELOC_COUNT")


def die(msg):
    sys.exit("fgx_libso: " + msg)


def split_code(lines, path):
    """({section: rows}, [section, ...] in file order).  Outside a section
    only comments, MX, the MODE/RELOC_COUNT rows and Merlin variables may
    stand; anything else would be lost from every bank."""
    units, order = {}, []
    for u in fgx_gc.split_sections(lines, path):
        if u[0] == "sect":
            units[u[1]] = u[2]
            order.append(u[1])
            continue
        for ln in u[1]:
            t = ln.split()
            if not t or t[0][0] in ";*]" or t[0] in LOOSE_OK:
                continue
            die("%s: '%s' stands outside every section" % (path, ln.strip()))
    return units, order


def literal_refs(units, names):
    """{section: sorted literals its code names}."""
    return {n: sorted({t for t in fgx_gc.IDENT.findall(fgx_gc.code_of(units[n]))
                       if LIT.match(t)})
            for n in names}


def pack(sizes, refs, lsizes, budgets):
    """First fit by decreasing size (name breaks ties).  A function costs its
    bytes plus each literal it names that its bank does not hold yet.
    (banks, held, free), or None if a function fits no bank."""
    banks = [[] for _ in budgets]
    held = [set() for _ in budgets]
    free = list(budgets)
    for f in sorted(sizes, key=lambda n: (-sizes[n], n)):
        for b in range(len(budgets)):
            new = [l for l in refs[f] if l not in held[b]]
            cost = sizes[f] + sum(lsizes[l] for l in new)
            if cost <= free[b]:
                banks[b].append(f)
                held[b].update(new)
                free[b] -= cost
                break
        else:
            return None
    return banks, held, free


def pack_min(sizes, refs, lsizes, budget0, budgetn, nmax):
    """The fewest banks that hold every function; bank 0 carries libc's
    hand-written code, so its budget is its own."""
    for n in range(1, nmax + 1):
        got = pack(sizes, refs, lsizes, [budget0] + [budgetn] * (n - 1))
        if got:
            return got
    big = max(sizes, key=lambda n: sizes[n])
    die("libc does not fit %d code banks (largest function %s, %d bytes)"
        % (nmax, big, sizes[big]))


def place_orphans(need, held, free, lsizes):
    """Literals only data points at: first bank with room."""
    for l in sorted(need):
        if any(l in h for h in held):
            continue
        for b in range(len(held)):
            if lsizes[l] <= free[b]:
                held[b].add(l)
                free[b] -= lsizes[l]
                break
        else:
            die("no bank has room for literal %s" % l)


def canonical(held):
    """{literal: the first bank that holds it}, the copy that is exported."""
    canon = {}
    for b, h in enumerate(held):
        for l in h:
            canon.setdefault(l, b)
    return canon


def bank_rows(units, order, funcs, held_b, canon, b):
    """Bank b's source rows: its functions and literal copies in file order,
    a copy's export row only where the copy is canonical, and the RELOC_COUNT
    fgx_ld checks the listing against."""
    keep = set(funcs) | set(held_b)
    rows = ["                FGX2_MODE 2", "                MX      %00"]
    for n in order:
        if n not in keep:
            continue
        for ln in units[n]:
            if LIT.match(n) and canon[n] != b and ln.split()[:1] == ["FGX2_EXPORT"]:
                continue
            rows.append(ln)
    rows.append("                FGX2_RELOC_COUNT %d" % fgx_gc.fgx2_rows(rows))
    return rows


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    die("usage: fgx_libso.py --self-test")


if __name__ == "__main__":
    sys.exit(main())
```

  (`self_test` from Step 1 sits above `main`.)

- [ ] **Step 3: Run the self-test.**

Run: `cd toolchain && python3 src/ld/fgx_libso.py --self-test`
Expected: `fgx_libso: self-test OK`

- [ ] **Step 4: Commit.**

```bash
git add toolchain/src/ld/fgx_libso.py
git commit -m "feat(ld): fgx_libso packs libc's library-mode sections into banks

The first half of the libc.so link: split lib/libc_so.s into its sections,
map each function to the string literals it pushes with PHK, pack the
functions first-fit by decreasing size with each literal charged to the bank
that first needs it, and write each bank's source with a copy of every
literal its functions name.  Only a literal's first copy is exported, so a
data pointer to it resolves there (K&R A.2.6: whether identical string
literals are distinct is implementation-defined).

```

---

### Task 3: fgx_ld -- a segment assembled away from address 0

**Files:**
- Modify: `toolchain/src/ld/fgx_ld.py` (`scan_listing`, its call in `main`,
  the DATA heap-limit check, the manifest docstring)
- Create: `toolchain/src/ld/test_fgx_ld_library.py`

**Interfaces:**
- Produces: manifest segment key `"org"` (default 0): the address the
  segment was assembled at within its bank.
  `scan_listing(path, n_segs, libc=False, org=0)` returns segment offsets
  (listing address minus `org`) everywhere it returns addresses, and dies on
  a row below `org`.  Where `main` patches a pointer's LL/HH (FGX2_IMPORT_JSL,
  FGX2_LONG_PTR, FGX2_ABS_OFFSET, FGX2_FARCALL/FARJUMP) the value is the
  target's offset plus the target segment's `org`: the address.
- Produces (test helpers Task 5 extends): in `test_fgx_ld_library.py`,
  `assemble(d, name, org, body)` and `link(d, segs, n_data, extra=None) ->
  (returncode, file bytes)`.

- [ ] **Step 1: Record the byte-identity baseline** (fgx_ld unchanged yet):

```bash
SP=<scratch>
mkdir -p $SP && cd ~/projects/Retro/Apple/fgx
for t in cat-fgx2/cat_fgx sh-fgx2/sh tcsh-fgx2/tcsh; do
  python3 toolchain/src/ld/fgx_ld.py tools/$t.json -o $SP/$(basename $t).before --pile-dir $SP/p || echo "FAILED $t"
done
```

Expected: three `.before` files, no FAILED line.

- [ ] **Step 2: Write the failing test.**

```python
#!/usr/bin/env python3
"""test_fgx_ld_library.py - fgx_ld's library link (shared libc SP2 step 3).

Run from toolchain/: python3 src/ld/test_fgx_ld_library.py
"""
import json
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_ld  # noqa: E402

MACROS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "lib", "macros.s")
fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def dies(fn):
    try:
        fn()
    except SystemExit:
        return True
    return False


ROW = ("    %d |  1 core.s      %d | Macro       | 00 |         |    4 "
       "| 0B/%04X : 00 00 00 00 | %s\n")


def listing(rows):
    p = os.path.join(tempfile.mkdtemp(prefix="ldlib_"), "l.txt")
    with open(p, "w") as f:
        for i, (addr, src) in enumerate(rows, 1):
            f.write(ROW % (i, i, addr, src))
    return p


def assemble(d, name, org, body):
    """One segment, assembled with Merlin32 at `org' in bank $0B.  The PUT
    path is relative to the real directory: macOS's temp dir is behind the
    /var -> /private/var link, and Merlin resolves from where it runs."""
    with open(os.path.join(d, name + ".link.s"), "w") as f:
        f.write("                TYP    $06\n                DSK    %s\n"
                "                ORG    $0B%04X\n                MX     %%00\n"
                "                PUT    %s\n%s\n"
                % (name, org, os.path.relpath(MACROS, os.path.realpath(d)), body))
    subprocess.run(["merlin32", "-V", ".", name + ".link.s"], cwd=d,
                   check=True, capture_output=True)


def link(d, segs, n_data, extra=None):
    """fgx_ld over `segs' [(name, kind, org)]; (returncode, output bytes)."""
    m = {"output": "t", "format": "FGX3", "n_data_segment": n_data,
         "entry_offset": 0, "flags": 0,
         "segments": [dict({"bin": n, "listing": n + "_Output.txt",
                            "kind": k, "bss": 0}, **({"org": o} if o else {}))
                      for n, k, o in segs]}
    m.update(extra or {})
    mp = os.path.join(d, "t.json")
    with open(mp, "w") as f:
        json.dump(m, f)
    r = subprocess.run([sys.executable, os.path.join(HERE, "fgx_ld.py"), mp],
                       capture_output=True, text=True)
    out = os.path.join(d, "t")
    return r.returncode, (open(out, "rb").read() if r.returncode == 0 else r.stderr)


def seg_bytes(data, i):
    n = data[6]
    pos = 16 + 8 * n
    for k in range(i):
        pos += struct.unpack_from("<H", data, 16 + 8 * k)[0]
    return data[pos:pos + struct.unpack_from("<H", data, 16 + 8 * i)[0]]


CODE0 = """                FGX2_MODE 2
                FGX2_EXPORT f0
f0              RTL
                FGX2_RELOC_COUNT 2"""
DATA0 = """                FGX2_MODE 2
                FGX2_EXPORT cell
cell            DA      0
pself           FGX2_LONG_PTR _a;cell;0
pcode           FGX2_LONG_PTR _b;f0;0
_libc_blk_m     DA      0
                FGX2_RELOC_COUNT 4"""


def org():
    p = listing([(0xF004, "stdin   FGX2_LONG_PTR _Fa;foo;0"),
                 (0xF010, "        FGX2_EXPORT bar")])
    s = fgx_ld.scan_listing(p, 2, org=0xF000)
    check(s["longptr"] == [(4, "foo", 0)], "an org'd LONG_PTR row is at its segment offset")
    check(s["exports"] == {"bar": 0x10}, "an org'd export is at its segment offset")
    check(fgx_ld.scan_listing(p, 2)["exports"] == {"bar": 0xF010},
          "without org the listing address is the offset")
    check(dies(lambda: fgx_ld.scan_listing(p, 2, org=0xF008)),
          "a row below the segment's org is refused")


def org_link():
    d = tempfile.mkdtemp(prefix="ldlib_asm_")
    assemble(d, "code0", 0, CODE0)
    assemble(d, "data", 0xF000, DATA0)
    rc, out = link(d, [("code0", "CODE", 0), ("data", "DATA", 0xF000)], 1)
    check(rc == 0, "an org'd data segment links", "" if rc == 0 else out[-300:])
    if rc:
        return
    data = seg_bytes(out, 1)
    check(data[2:4] == b"\x00\xF0", "a pointer into the org'd segment holds its "
          "address $F000, not its offset", data[2:4].hex())
    check(data[6:8] == b"\x00\x00", "a pointer into an org-0 segment holds the offset",
          data[6:8].hex())


org()
org_link()
print("FAIL: %d" % len(fails) if fails else "fgx_ld library checks passed")
sys.exit(1 if fails else 0)
```

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py`
Expected: FAIL -- `TypeError: scan_listing() got an unexpected keyword
argument 'org'` (org_link fails after it: without `org` fgx_ld indexes the
data segment at `$F004`).

- [ ] **Step 3: Implement `org`.**
  - `def scan_listing(path, n_segs, libc=False, org=0):` and, right after
    `macro_name, args, addr, srcfile = parsed`:

```python
        if addr < org:
            die(f"{path}: row at {addr:#06x} lies below the segment's org "
                f"{org:#06x}")
        addr -= org
```

  - In `main`, the scan call becomes
    `scan_listing(listing_path, n_segs, libc=..., org=s.get("org", 0))`.
  - At the four sites that patch a pointer's LL/HH, add the target
    segment's org right after the target offset is found:
    FGX2_IMPORT_JSL `tgt_off = exports_by_seg[tgt][name] +
    segs[tgt].get("org", 0)`; FGX2_LONG_PTR, after `resolve_precedence`,
    `tgt_off += segs[rseg].get("org", 0)`; FGX2_ABS_OFFSET `tgt_off =
    exports_by_seg[tgt][name] + segs[tgt].get("org", 0)`;
    FGX2_FARCALL/FARJUMP, after `resolve_precedence`, `tgt_off +=
    segs[tgt].get("org", 0)`.  The existing 16-bit range checks follow and
    stay.
  - The DATA heap-limit check uses the segment's end address:
    `if kind_name == "DATA" and s.get("org", 0) + size + bss > HEAP_LIM:`
    with the message naming `org` too.
  - Docstring manifest schema: add
    `"org": 0,  # address the segment was assembled at in its bank (default 0)`
    to the segment entry.

- [ ] **Step 4: Run the test and the byte-identity check.**

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py`
Expected: `fgx_ld library checks passed`

Run (same `$SP`):

```bash
cd ~/projects/Retro/Apple/fgx
for t in cat-fgx2/cat_fgx sh-fgx2/sh tcsh-fgx2/tcsh; do
  n=$(basename $t)
  python3 toolchain/src/ld/fgx_ld.py tools/$t.json -o $SP/$n.after --pile-dir $SP/p && cmp $SP/$n.before $SP/$n.after && echo "same $n"
done
```

Expected: `same cat_fgx`, `same sh`, `same tcsh`.

- [ ] **Step 5: Commit.**

```bash
git add toolchain/src/ld/fgx_ld.py toolchain/src/ld/test_fgx_ld_library.py
git commit -m "feat(ld): a segment may be assembled away from address 0

A manifest segment's \"org\" is the address it was assembled at within its
bank.  fgx_ld reads every reloc, export and import from the listing's
address column, so it now subtracts the org to get the segment offset, and
refuses a row below it; a pointer patched to point into such a segment gets
the offset plus the org, its address.  libc.so's core template is assembled
at the top of the data bank, where it sits in every process.  Without an org
the output is unchanged: cat, sh and tcsh relink byte for byte.

```

---

### Task 4: fgx_libso.py -- measure, assemble, link

**Files:**
- Modify: `toolchain/src/ld/fgx_libso.py` (the driver)
- Modify: `toolchain/Makefile` (the `libc_so` rule)
- Modify: `.gitignore` (beside line 439, `toolchain/lib/libc_so.s`)

**Interfaces:**
- Consumes: Task 2's functions; Task 3's `org`;
  `toolchain/tools/gen_seg1_layout.py <listing> <out.s>`; `fgx_ld.HEAP_LIM`.
- Produces: `lib/libc.so.1.0` and `lib/libc_so.d/` holding `bank<k>.s`,
  `bank<k>.link.s`, `bank<k>_Output.txt` (k = 0..N-1, segments 0..N-1),
  `core.s`/`core_Output.txt` (segment N, `org` = core base),
  `tmpl.s`/`tmpl_Output.txt` (segment N+1), `core_layout.s`,
  `libc_so.json`.  `section_sizes(listing_path, src_name) -> {name: bytes}`.

- [ ] **Step 1: Write the failing test.**  Add to `self_test()`:

```python
    lst = os.path.join(tempfile.mkdtemp(prefix="libso_st_"), "m_Output.txt")
    row = ("  %d |  2   c.s   %d | Macro       | 00 |         |    0 "
           "| 0B/%04X               |          %s\n")
    with open(lst, "w") as f:
        f.write(row % (1, 2, 0x0120, "FGX_SECT          f"))
        f.write(row % (2, 9, 0x0188, "FGX_ENDS"))
        f.write(row % (3, 10, 0x0188, "FGX_SECT          g"))
        f.write(row % (4, 14, 0x01F0, "FGX_ENDS"))
        f.write(row.replace("c.s", "x.s") % (5, 2, 0x0300, "FGX_SECT          h"))
    assert section_sizes(lst, "c.s") == {"f": 0x68, "g": 0x68}
```

  (and `import tempfile` at the top).

Run: `cd toolchain && python3 src/ld/fgx_libso.py --self-test`
Expected: FAIL -- `NameError: name 'section_sizes' is not defined`.

- [ ] **Step 2: Implement the driver.**  Add to `fgx_libso.py`:

```python
import json
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TC = os.path.dirname(os.path.dirname(HERE))              # toolchain/
LIB = os.path.join(TC, "lib")
sys.path.insert(0, HERE)
import fgx_ld  # noqa: E402

CAP = 0xFFFF                     # fgx_ld's largest segment
MAX_CODE_BANKS = 6               # 8 segments (a 9th must be LIBC) less core, templates
MACROS = os.path.join(LIB, "macros.s")
RUNTIME = os.path.join(LIB, "fcc_runtime.s")
LLONG = sorted(os.path.join(LIB, "libllong", f)
               for f in os.listdir(os.path.join(LIB, "libllong"))
               if f.endswith(".s") and not f.endswith(".data.s"))
LLONG_DATA = sorted(os.path.join(LIB, "libllong", f)
                    for f in os.listdir(os.path.join(LIB, "libllong"))
                    if f.endswith(".data.s"))
BANK0 = [os.path.join(LIB, "libc.s"), os.path.join(LIB, "fcc_libc_shims.s")] \
    + LLONG + [os.path.join(LIB, "libdouble", "d_stub.s")]
DATA = [os.path.join(LIB, f) for f in ("libc_data.s", "args_data.s",
                                       "fcc_runtime_data.s")] + LLONG_DATA
# As the shared pile's link file has them (tools/fgx2/seg2.link.s.in).
CODE_EQUS = [("SYS_EXIT", "1"), ("SYS_WRITE", "4"), ("SYS_TRAMP", "$000328"),
             ("LIBC_FAR", "1")]
# The direct-page cells fcc's string members share with the shims
# (fcc_libc_shims.s:70-71), which define them in bank 0; every other bank's
# code names them too.
DP_EQUS = [("c_strcmp_a", "$F2"), ("c_strcmp_b", "$F5")]
# As the data segment's link file has them (tools/fgx2/seg1.link.s.in).
DATA_EQUS = [("_IOREAD", "$0001"), ("_IOWRT", "$0002"), ("LIBC_NFILE", "8"),
             ("__sFILE_file", "0"), ("__sFILE_flag", "2"), ("__sFILE_size", "4"),
             ("ARGS_MAX", "16"), ("ARGS_INPUT_MAX", "128")]


def write_link(d, name, org, equs, puts):
    """<name>.link.s: one segment, assembled at `org' in bank $0B."""
    with open(os.path.join(d, name + ".link.s"), "w") as f:
        f.write("                TYP    $06\n                DSK    %s\n" % name)
        f.write("                ORG    $0B%04X\n                MX     %%11\n" % org)
        for k, v in equs:
            f.write("%-18s EQU    %s\n" % (k, v))
        for p in puts:
            f.write("                PUT    %s\n" % (p if not os.path.isabs(p)
                                                     else os.path.relpath(p, d)))
    return name + ".link.s"


def run_merlin(d, link):
    """The segment's bytes, or None when it is over 64 KB."""
    dsk = link[:-len(".link.s")]
    for f in (dsk, dsk + "_Output.txt", "error_output.txt"):
        try:
            os.remove(os.path.join(d, f))
        except OSError:
            pass
    r = subprocess.run(["merlin32", "-V", ".", link], cwd=d,
                       capture_output=True, text=True)
    out = os.path.join(d, dsk)
    if r.returncode == 0 and os.path.exists(out):
        return open(out, "rb").read()
    err = os.path.join(d, "error_output.txt")
    text = (open(err).read() if os.path.exists(err) else "") + r.stdout
    if "Object code size > 64 KB" in text:
        return None
    die("%s does not assemble:\n%s" % (link, text[-1200:]))


def section_sizes(listing, src_name):
    """{section: bytes} from the FGX_SECT/FGX_ENDS rows `src_name' contributes
    to a listing: the gap between the two rows' addresses."""
    sizes, cur = {}, None
    for raw in open(listing, errors="replace"):
        parts = [p.strip() for p in raw.split("|")]
        if len(parts) < 8 or parts[2] != "Macro":
            continue
        where = parts[1].split()
        tok = parts[7].split()
        if len(where) < 2 or where[1] != src_name or not tok:
            continue
        bank, off = parts[6].split()[0].split("/")
        addr = int(bank, 16) << 16 | int(off, 16)
        if tok[0] == "FGX_SECT" and len(tok) > 1:
            cur = (tok[1], addr)
        elif tok[0] == "FGX_ENDS" and cur:
            sizes[cur[0]] = addr - cur[1]
            cur = None
    return sizes


def write_units(path, names, units):
    rows = ["                MX      %00"]
    for n in names:
        rows += units[n]
    with open(path, "w") as f:
        f.write("\n".join(rows) + "\n")


def measure(d, funcs, lits, units, layout):
    """({function: bytes}, {literal: bytes}), halving any run over 64 KB.
    Every run carries all the literals, so each `LDA #literal' resolves."""
    write_units(os.path.join(d, "lits.s"), lits, units)
    sizes, lsizes, todo, k = {}, {}, [list(funcs)], 0
    while todo:
        part = todo.pop()
        src = "m%d.s" % k
        write_units(os.path.join(d, src), part, units)
        link = write_link(d, "m%d" % k, 0, CODE_EQUS + DP_EQUS,
                          [MACROS, layout, src, "lits.s", RUNTIME])
        k += 1
        if run_merlin(d, link) is None:
            if len(part) == 1:
                die("function %s alone is over 64 KB" % part[0])
            todo += [part[:len(part) // 2], part[len(part) // 2:]]
            continue
        lst = os.path.join(d, link[:-len(".link.s")] + "_Output.txt")
        sizes.update(section_sizes(lst, src))
        if not lsizes:
            lsizes = section_sizes(lst, "lits.s")
    missing = [n for n in list(funcs) + list(lits) if n not in sizes and n not in lsizes]
    if missing:
        die("no size measured for %s" % missing[:5])
    return sizes, lsizes


def write_data(path, units):
    rows = ["                FGX2_MODE 2"]
    for u in units:
        rows += u[2]
    rows.append("                FGX2_RELOC_COUNT %d" % fgx_gc.fgx2_rows(rows))
    with open(path, "w") as f:
        f.write("\n".join(rows) + "\n")


def build(out, d):
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):              # a rerun may pack fewer banks
        os.remove(os.path.join(d, f))
    code_path = os.path.join(LIB, "libc_so.s")
    data_path = os.path.join(LIB, "libc_so_data.s")
    units, order = split_code(open(code_path).read().split("\n"), code_path)
    dunits = fgx_gc.split_sections(open(data_path).read().split("\n"), data_path)
    for u in dunits:
        if u[0] == "loose":
            split_code(u[1], data_path)          # the same loose-row rule
    sects = [u for u in dunits if u[0] == "sect"]
    write_data(os.path.join(d, "core.s"), [u for u in sects if not u[1].endswith("__BT")])
    write_data(os.path.join(d, "tmpl.s"), [u for u in sects if u[1].endswith("__BT")])

    # The core: measured at 0, then assembled where it ends at HEAP_LIM.
    core_puts = [MACROS] + DATA + ["core.s"]
    size = len(run_merlin(d, write_link(d, "core", 0, DATA_EQUS, core_puts)))
    base = fgx_ld.HEAP_LIM - size
    core = run_merlin(d, write_link(d, "core", base, DATA_EQUS, core_puts))
    if len(core) != size:
        die("the core is %d bytes at $%04X but %d at 0" % (len(core), base, size))
    subprocess.run([sys.executable, os.path.join(TC, "tools", "gen_seg1_layout.py"),
                    os.path.join(d, "core_Output.txt"),
                    os.path.join(d, "core_layout.s")], check=True)
    tmpl = run_merlin(d, write_link(d, "tmpl", 0, DATA_EQUS,
                                    [MACROS, "core_layout.s", "tmpl.s"]))

    funcs = [n for n in order if not LIT.match(n)]
    lits = [n for n in order if LIT.match(n)]
    sizes, lsizes = measure(d, funcs, lits, units, "core_layout.s")
    ov0 = len(run_merlin(d, write_link(d, "ov0", 0, CODE_EQUS,
                                       [MACROS, "core_layout.s"] + BANK0 + [RUNTIME])))
    ovn = len(run_merlin(d, write_link(d, "ovn", 0, CODE_EQUS + DP_EQUS,
                                       [MACROS, "core_layout.s", RUNTIME])))
    refs = literal_refs(units, funcs)
    banks, held, free = pack_min(sizes, refs, lsizes, CAP - ov0, CAP - ovn,
                                 MAX_CODE_BANKS)
    data_text = open(os.path.join(d, "core.s")).read() + open(os.path.join(d, "tmpl.s")).read()
    place_orphans({t for t in fgx_gc.IDENT.findall(data_text) if LIT.match(t)},
                  held, free, lsizes)
    canon = canonical(held)

    segs = []
    for b, fs in enumerate(banks):
        rows = bank_rows(units, order, fs, held[b], canon, b)
        with open(os.path.join(d, "bank%d.s" % b), "w") as f:
            f.write("\n".join(rows) + "\n")
        puts = [MACROS, "core_layout.s"] + (BANK0 if b == 0 else []) \
            + ["bank%d.s" % b, RUNTIME]
        equs = CODE_EQUS if b == 0 else CODE_EQUS + DP_EQUS
        got = run_merlin(d, write_link(d, "bank%d" % b, 0, equs, puts))
        want = (ov0 if b == 0 else ovn) + sum(sizes[f] for f in fs) \
            + sum(lsizes[l] for l in held[b])
        if got is None or len(got) != want:
            die("bank %d assembled to %s bytes; its sections measured %d"
                % (b, "over 64K" if got is None else len(got), want))
        segs.append({"bin": "bank%d" % b, "listing": "bank%d_Output.txt" % b,
                     "kind": "CODE", "bss": 0})
    n_core = len(segs)
    segs.append({"bin": "core", "listing": "core_Output.txt", "kind": "DATA",
                 "bss": 0, "org": base})
    segs.append({"bin": "tmpl", "listing": "tmpl_Output.txt", "kind": "RODATA",
                 "bss": 0})
    manifest = {"output": os.path.basename(out), "format": "FGX3",
                "n_data_segment": n_core, "entry_offset": 0, "flags": 0,
                "segments": segs}
    mpath = os.path.join(d, "libc_so.json")
    with open(mpath, "w") as f:
        json.dump(manifest, f, indent=1)
    subprocess.run([sys.executable, os.path.join(HERE, "fgx_ld.py"), mpath,
                    "-o", out], check=True)
    print("libc.so: %d code banks (%s bytes), core %d bytes at $%04X, "
          "templates %d bytes" % (len(banks), ", ".join(
              str(CAP - f) for f in free), size, base, len(tmpl)))
```

  `main` gains the build:

```python
def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    if len(sys.argv) != 5 or sys.argv[1] != "--out" or sys.argv[3] != "--dir":
        die("usage: fgx_libso.py --out FILE --dir DIR | --self-test")
    build(os.path.abspath(sys.argv[2]), os.path.abspath(sys.argv[4]))
    return 0
```

- [ ] **Step 3: Run the self-test.**

Run: `cd toolchain && python3 src/ld/fgx_libso.py --self-test`
Expected: `fgx_libso: self-test OK`

- [ ] **Step 4: Wire the build.**  In `toolchain/Makefile`, after the
  `lib/libc_so_data.s` rule, replace `libc_so: lib/libc_so.s` with:

```make
# libc.so: the library-mode compile, packed into banks and linked with its
# core and block templates (src/ld/fgx_libso.py; lib/libc_so.d holds the
# segments, listings and fgx_ld manifest).
lib/libc.so.1.0: lib/libc_so.s lib/libc_so_data.s lib/libc.s lib/fcc_libc_shims.s \
		lib/fcc_runtime.s lib/libc_data.s lib/args_data.s lib/fcc_runtime_data.s \
		$(wildcard lib/libllong/*.s) lib/libdouble/d_stub.s lib/macros.s \
		src/ld/fgx_libso.py src/ld/fgx_ld.py src/ld/fgx_gc.py tools/gen_seg1_layout.py
	python3 src/ld/fgx_libso.py --out lib/libc.so.1.0 --dir lib/libc_so.d
libc_so: lib/libc_so.s lib/libc.so.1.0
```

  and beside `lib/libc_so_data.s: lib/libc_so.s` add
  `lib/libc_so.blocks.json: lib/libc_so.s` (Task 5 names it as a
  prerequisite; without a rule a fresh tree stops "No rule to make target").

  In `.gitignore`, after `toolchain/lib/libc_so.s`, add
  `toolchain/lib/libc.so.1.0` and `toolchain/lib/libc_so.d/`.

- [ ] **Step 5: Build it.**  Announce: "building libc.so in toolchain/ (no
  shipped binary changes)".

Run: `cd toolchain && make libc_so && git -C .. status --short`
Expected: the `libc.so:` summary line (N banks with N between 2 and 6, core
at `$F` something, templates 9,443 bytes -- the blocks file's total); `git
status` shows only the plan's modified files, nothing from `lib/`.  If a
bank dies with a size mismatch, that is Review Focus 2: find the operand
whose width changed, do not add slack.  tcsh's packer has seen a TU measure
differently alone than in its bank (`gen_tcsh_link.py`'s drift pad), so
expect it; look first at a backward reference to a label below `$0100`
that Merlin folds to direct page (banks 1-N start their first function at
`$0000`), then at a section that does not end in `MX %00`.

- [ ] **Step 6: Commit.**

```bash
git add toolchain/src/ld/fgx_libso.py toolchain/Makefile .gitignore
git commit -m "feat(ld): make libc_so links lib/libc.so.1.0

fgx_libso measures every section of the library-mode compile (Merlin
refuses an object over 64 KB, so in runs halved until each fits), packs the
functions into the fewest banks, and checks each bank assembles
to exactly the size its sections measured.  The core template is assembled
where it ends at HEAP_LIM, as it sits in every process; the block templates
are their own segment.  Each bank carries the whole fcc runtime:
fcc_runtime.s has no sections to select from.  Banks without the shims
define the direct-page cells c_strcmp_a/b that fcc's string members name.

```

---

### Task 5: fgx_ld -- the library trailer

**Files:**
- Modify: `toolchain/src/ld/fgx_ld.py`
- Modify: `toolchain/src/ld/test_fgx_ld_library.py`
- Modify: `toolchain/src/ld/fgx_libso.py` (the manifest's `library` block)
- Create: `toolchain/lib/libc_c/data.exports`
- Modify: `toolchain/Makefile` (`lib/libc.so.1.0` prerequisites)

**Interfaces:**
- Consumes: Task 3's `org` and its test helpers `assemble`, `link`,
  `seg_bytes`, `CODE0`, `DATA0`; Task 4's manifest and `lib/libc_so.d`
  listings.
- Produces (Task 6 imports these):
  - `LIB_FLAG = 0x02`, `LIB_MAGIC = b"FGXL"`
  - `split_fixups(relocs, core, tmpl) -> (relocs, [fixup offset])`
  - `read_names(path) -> [name]` (one per line, `#` comments)
  - `library_exports(segs, exports_by_seg, core_labels, core, prefix, data_names) -> [(name, kind, seg, value)]`
  - `block_table(members, cells, tmpl_exports, tmpl_len) -> [(cell, tmpl_off, size)]`
  - `check_core_list(path, core_names, prefix) -> None`
  - `library_trailer(version, core, tmpl, core_base, core_size, exports, blocks, fixups) -> bytes`
  - `read_trailer(data) -> dict` with keys `major, minor, core, templates,
    core_base, core_size, checksum, crc, exports, blocks, fixups` (`crc` is
    recomputed over the export records as read; `checksum` is the stored one)
  - manifest `"library": {"core": i, "templates": j, "blocks": path,
    "core_list": path, "data_exports": path, "static_prefix": "_libc_c_",
    "version": [1, 0]}`

- [ ] **Step 1: Write the failing tests.**  Add to
  `test_fgx_ld_library.py`, before the run lines, and call each after
  `org_link()` (`fixups()`, `exports()`, `blocks()`, `core_list()`,
  `trailer()`, `library_link()`):

```python
def fixups():
    relocs = [(0, 3, 1, "farcall"), (2, 6, 2, "libc_data_ptr"), (2, 10, 0, "long_ptr")]
    kept, fx = fgx_ld.split_fixups(relocs, 2, 3)
    check(kept == [(0, 3, 1, "farcall"), (2, 10, 0, "long_ptr")] and fx == [6],
          "a core pointer into the core is a fixup, others stay relocs")
    check(dies(lambda: fgx_ld.split_fixups([(0, 3, 3, "long_ptr")], 2, 3)),
          "a pointer into a block template is refused")
    check(dies(lambda: fgx_ld.split_fixups([(3, 3, 2, "long_ptr")], 2, 3)),
          "a block template pointing into the core is refused")


def exports():
    segs = [{"kind": "CODE"}, {"kind": "CODE"}, {"kind": "DATA"}, {"kind": "RODATA"}]
    by_seg = [{"printf": 5, "_libc_c_S1": 9, "_libc_c_helper": 12},
              {"strtok": 0}, {"_libc_blk_a": 0}, {"a__BT": 0}]
    core_labels = [(0xF000, "errno"), (0xF002, "_libc_c___lc_pf_n"),
                   (0xF004, "_libc_blk_a"), (0xF006, "_libc_FILE_table")]
    got = fgx_ld.library_exports(segs, by_seg, core_labels, 2, "_libc_c_", ["errno"])
    check(got == [("errno", 1, 2, 0xF000), ("printf", 0, 0, 5), ("strtok", 0, 1, 0)],
          "exports: public code names and the listed data names, sorted; statics, "
          "cells, templates and unlisted core cells out")
    check(dies(lambda: fgx_ld.library_exports(
        segs, by_seg, core_labels, 2, "_libc_c_", ["errno", "environ"])),
        "a listed data export the core does not define is refused")
    check(dies(lambda: fgx_ld.library_exports(
        segs, by_seg, core_labels + [(0xF008, "printf")], 2, "_libc_c_",
        ["errno", "printf"])),
        "a name both code and data is refused")


def blocks():
    members = {"a": {"size": 4}, "b": {"size": 6}}
    cells = {"_libc_blk_a": 0xF010, "_libc_blk_b": 0xF012}
    got = fgx_ld.block_table(members, cells, {"a__BT": 0, "b__BT": 4}, 10)
    check(got == [(0xF010, 0, 4), (0xF012, 4, 6)], "the block table, by member")
    check(dies(lambda: fgx_ld.block_table(members, cells, {"a__BT": 0, "b__BT": 4}, 12)),
          "a template whose listed size disagrees with the blocks file is refused")
    check(dies(lambda: fgx_ld.block_table(members, {"_libc_blk_a": 1},
                                          {"a__BT": 0, "b__BT": 4}, 10)),
          "a member with no block cell is refused")


def core_list():
    p = os.path.join(tempfile.mkdtemp(prefix="ldlib_"), "core.list")
    with open(p, "w") as f:
        f.write("# comment\n_lc_buf\nerrno\n")
    names = {"_libc_c__lc_buf", "errno"}
    check(not dies(lambda: fgx_ld.check_core_list(p, names, "_libc_c_")),
          "core.list names defined as statics or plain names pass")
    check(dies(lambda: fgx_ld.check_core_list(p, {"errno"}, "_libc_c_")),
          "a core.list name no member defines is refused")


def trailer():
    ex = [("errno", 1, 2, 0xF000), ("printf", 0, 0, 5)]
    t = fgx_ld.library_trailer((1, 0), 2, 3, 0xF000, 0x0FF8, ex, [(0xF010, 0, 4)], [6])
    r = fgx_ld.read_trailer(t)
    check((r["major"], r["minor"], r["core"], r["templates"], r["core_base"],
           r["core_size"]) == (1, 0, 2, 3, 0xF000, 0x0FF8), "trailer header round-trips")
    check(r["exports"] == ex and r["blocks"] == [(0xF010, 0, 4)] and r["fixups"] == [6],
          "trailer tables round-trip")
    t2 = fgx_ld.library_trailer((1, 0), 2, 3, 0xF000, 0x0FF8,
                                [ex[0], ("printf", 0, 0, 6)], [(0xF010, 0, 4)], [6])
    check(fgx_ld.read_trailer(t2)["checksum"] != r["checksum"],
          "moving one export changes the checksum")
    check(r["crc"] == r["checksum"], "the stored checksum is the records' CRC")
    bad = bytearray(t)
    bad[bad.index(b"errno")] ^= 0x20
    r3 = fgx_ld.read_trailer(bytes(bad))
    check(r3["crc"] != r3["checksum"], "a corrupted export record fails its CRC")


TMPL = """                FGX2_MODE 2
                FGX2_EXPORT m__BT
m__BT           DA      0
                FGX2_RELOC_COUNT 2"""


def library_link():
    """fgx_ld's library path end to end, over assembled segments: the core
    at org $F000 with a pointer into itself (a fixup), one into code (a
    reloc) and one member's block cell; a two-byte template."""
    d = tempfile.mkdtemp(prefix="ldlib_lib_")
    assemble(d, "code0", 0, CODE0)
    assemble(d, "data", 0xF000, DATA0)
    assemble(d, "tmpl", 0, TMPL)
    with open(os.path.join(d, "blocks.json"), "w") as f:
        json.dump({"members": {"m": {"statics": [{"name": "m_x", "offset": 0,
                                                  "bytes": 2, "init": False}],
                                     "size": 2}}}, f)
    for name, text in (("core.list", "cell\n"), ("data.exports", "cell\n")):
        with open(os.path.join(d, name), "w") as f:
            f.write(text)
    lib = {"library": {"core": 1, "templates": 2, "blocks": "blocks.json",
                       "core_list": "core.list", "data_exports": "data.exports",
                       "static_prefix": "_libc_c_", "version": [1, 0]}}
    segs = [("code0", "CODE", 0), ("data", "DATA", 0xF000), ("tmpl", "RODATA", 0)]
    rc, out = link(d, segs, 1, lib)
    check(rc == 0, "a library links", "" if rc == 0 else out[-300:])
    if rc:
        return
    check(out[10] & fgx_ld.LIB_FLAG, "the header flags a library")
    nrel = struct.unpack_from("<H", out, 11)[0]
    check(nrel == 1, "the core's pointer into code stays the one reloc", str(nrel))
    end = 16 + 8 * 3 + sum(struct.unpack_from("<H", out, 16 + 8 * i)[0]
                           for i in range(3)) + 4 * nrel
    t = fgx_ld.read_trailer(out[end:])
    check(t["exports"] == [("cell", 1, 1, 0xF000), ("f0", 0, 0, 0)],
          "exports: the code name and the listed data name", str(t["exports"]))
    check(t["blocks"] == [(0xF00A, 0, 2)], "the block row: cell, template, size",
          str(t["blocks"]))
    check(t["fixups"] == [4], "the core's pointer into itself is a fixup at "
          "its bank byte", str(t["fixups"]))
    check((t["core_base"], t["core_size"]) == (0xF000, 12), "the core's base and size")
    assemble(d, "data", 0xF000, DATA0.replace(
        "_libc_blk_m     DA      0",
        "_libc_blk_m     DA      0\npbad            FGX2_LONG_PTR _c;m__BT;0").replace(
        "FGX2_RELOC_COUNT 4", "FGX2_RELOC_COUNT 5"))
    rc, out = link(d, segs, 1, lib)
    check(rc == 2 and "block template" in out,
          "a core pointer into a block template is refused", str(rc))
```

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py`
Expected: FAIL -- `AttributeError: module 'fgx_ld' has no attribute 'split_fixups'`.

- [ ] **Step 2: Implement.**  In `fgx_ld.py`, add `import zlib`, then
  `sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
  os.path.dirname(os.path.abspath(__file__)))), "tools"))` and
  `import gen_seg1_layout  # noqa: E402` beside the `stack_measure` import,
  and these functions above `main`:

```python
# A library (libc.so, shared libc SP2 spec section 3): header flags bit 1
# says a trailer follows the relocs -- export table, its checksum, the
# member-block table and the per-process fixups.  Keep the layout in step
# with read_trailer.
LIB_FLAG = 0x02
LIB_MAGIC = b"FGXL"


def split_fixups(relocs, core, tmpl):
    """A reloc from the core template into itself becomes a fixup: the core
    is copied into every process's data bank, so its bank is the process's.
    A pointer into a block template, or from one into the core, is refused:
    both addresses are per-process and no reloc can hold them."""
    kept, fixups = [], []
    for src, off, tgt, prov in relocs:
        if tgt == tmpl:
            die(f"library: segment {src} offset {off:#06x} points into a "
                f"block template ({prov}); a block's address is per-process")
        if src == tmpl and tgt == core:
            die(f"library: block template offset {off:#06x} points into the "
                f"core ({prov}); the core's bank is per-process")
        if src == core and tgt == core:
            fixups.append(off)
        else:
            kept.append((src, off, tgt, prov))
    return kept, sorted(fixups)


def read_names(path):
    """The names in a list file: one per line, `#' starts a comment."""
    out = []
    for line in open(path):
        n = line.split("#")[0].strip()
        if n:
            out.append(n)
    return out


def library_exports(segs, exports_by_seg, core_labels, core, prefix,
                    data_names):
    """(name, kind, segment, value) sorted by name: kind 0 is every public
    code export at its segment offset, kind 1 each of `data_names' -- the
    extern data libc's headers declare -- at its core address.  Statics
    (prefix), block cells and templates are not exported (the block table
    carries the cells), nor is the rest of the core, which is libc's own."""
    def public(n):
        return not (n.startswith(prefix) or n.startswith("_libc_blk_")
                    or n.endswith("__BT"))
    out = {}
    for i, s in enumerate(segs):
        if s.get("kind", "CODE") != "CODE":
            continue
        for n, off in exports_by_seg[i].items():
            if public(n):
                if n in out:
                    die(f"library: '{n}' is exported by segments "
                        f"{out[n][2]} and {i}")
                out[n] = (n, 0, i, off)
    addr_of = {n: a for a, n in core_labels}
    for n in data_names:
        if n not in addr_of:
            die(f"library: data export '{n}' is not in the core")
        if n in out:
            die(f"library: '{n}' names both code and core data")
        out[n] = (n, 1, core, addr_of[n])
    return [out[n] for n in sorted(out)]


def block_table(members, cells, tmpl_exports, tmpl_len):
    """(cell address, template offset, size) per member, in name order.
    The templates lie back to back, so each one's listed size is the gap to
    the next, which must equal the blocks file's size."""
    rows = []
    for m in sorted(members):
        cell = cells.get("_libc_blk_" + m)
        t = tmpl_exports.get(m + "__BT")
        if cell is None or t is None:
            die(f"library: member {m} has no block cell or template "
                f"(cell {cell}, template {t})")
        rows.append((m, cell, t, members[m]["size"]))
    by_off = sorted(rows, key=lambda r: r[2])
    for i, (m, _c, t, size) in enumerate(by_off):
        end = by_off[i + 1][2] if i + 1 < len(by_off) else tmpl_len
        if end - t != size:
            die(f"library: member {m}'s template is {end - t} bytes in the "
                f"listing but {size} in the blocks file (stale blocks file?)")
    return [(c, t, sz) for _m, c, t, sz in rows]


def check_core_list(path, core_names, prefix):
    """Every name core.list gives must be defined in the core."""
    for n in read_names(path):
        if n not in core_names and prefix + n not in core_names:
            die(f"library: {path} names '{n}', which no libc member defines "
                f"in the core")


def library_trailer(version, core, tmpl, core_base, core_size, exports,
                    blocks, fixups):
    rec = b""
    for n, kind, seg, val in exports:
        b = n.encode("ascii")
        if len(b) > 255:
            die(f"library: export name '{n}' is over 255 bytes")
        rec += bytes([len(b)]) + b + struct.pack("<BBH", kind, seg, val)
    out = LIB_MAGIC + struct.pack("<BBBBHHHHHI", version[0], version[1], core,
                                  tmpl, core_base, core_size, len(exports),
                                  len(blocks), len(fixups), zlib.crc32(rec))
    out += rec
    for cell, t, size in blocks:
        out += struct.pack("<HHH", cell, t, size)
    for f in fixups:
        out += struct.pack("<H", f)
    return out


def read_trailer(data):
    if data[:4] != LIB_MAGIC:
        raise ValueError("no library trailer")
    (major, minor, core, tmpl, base, size, ne, nb, nf,
     ck) = struct.unpack_from("<BBBBHHHHHI", data, 4)
    pos = start = 4 + struct.calcsize("<BBBBHHHHHI")
    exports = []
    for _ in range(ne):
        n = data[pos]
        name = data[pos + 1:pos + 1 + n].decode("ascii")
        kind, seg, val = struct.unpack_from("<BBH", data, pos + 1 + n)
        exports.append((name, kind, seg, val))
        pos += 1 + n + 4
    crc = zlib.crc32(data[start:pos])
    blocks = [struct.unpack_from("<HHH", data, pos + 6 * i) for i in range(nb)]
    pos += 6 * nb
    fixups = [struct.unpack_from("<H", data, pos + 2 * i)[0] for i in range(nf)]
    return {"major": major, "minor": minor, "core": core, "templates": tmpl,
            "core_base": base, "core_size": size, "checksum": ck, "crc": crc,
            "exports": exports, "blocks": blocks, "fixups": fixups}
```

  In `main`, after the LIBC gate loop and before `libcref = None`:

```python
    trailer = b""
    lib = m.get("library")
    if lib:
        core, tmpl = lib["core"], lib["templates"]
        relocs, fixups = split_fixups(relocs, core, tmpl)
        core_labels = gen_seg1_layout.extract_labels(
            os.path.join(manifest_dir, segs[core]["listing"]))
        core_names = {n for _a, n in core_labels}
        prefix = lib["static_prefix"]
        check_core_list(os.path.join(manifest_dir, lib["core_list"]),
                        core_names, prefix)
        with open(os.path.join(manifest_dir, lib["blocks"])) as f:
            members = json.load(f)["members"]
        for mem, v in members.items():
            for st in v["statics"]:
                if st["name"] in core_names:
                    die(f"library: {st['name']} is in member {mem}'s block "
                        f"and in the core")
        exports = library_exports(
            segs, exports_by_seg, core_labels, core, prefix,
            read_names(os.path.join(manifest_dir, lib["data_exports"])))
        blocks = block_table(members, {n: a for a, n in core_labels},
                             exports_by_seg[tmpl], len(seg_data[tmpl]))
        trailer = library_trailer(lib["version"], core, tmpl,
                                  segs[core].get("org", 0),
                                  len(seg_data[core]), exports, blocks, fixups)
        flags |= LIB_FLAG
```

  and after the reloc records are appended to `out`: `out += trailer`.
  Docstring: add the `library` manifest block and one line that the trailer
  layout is `library_trailer`'s.

- [ ] **Step 3: Run the tests.**

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py`
Expected: `fgx_ld library checks passed`

- [ ] **Step 4: The driver asks for the trailer.**  In `fgx_libso.py`
  `build`, add to `manifest` before it is written:

```python
    manifest["library"] = {
        "core": n_core, "templates": n_core + 1,
        "blocks": os.path.relpath(os.path.join(LIB, "libc_so.blocks.json"), d),
        "core_list": os.path.relpath(os.path.join(LIB, "libc_c", "core.list"), d),
        "data_exports": os.path.relpath(os.path.join(LIB, "libc_c", "data.exports"), d),
        "static_prefix": PREFIX, "version": [1, 0]}
```

  and add `lib/libc_so.blocks.json lib/libc_c/core.list
  lib/libc_c/data.exports` to the `lib/libc.so.1.0` prerequisites in the
  Makefile.  Create `toolchain/lib/libc_c/data.exports`:

```
# libc.so's data exports: the extern data libc's public headers declare
# (shared libc SP2 spec, section 4).  fgx_ld's library link exports exactly
# these, each from the core, and refuses the link if the core lacks one.
# Every other core cell is libc's own and is not in the export table.
errno
environ
stdin
stdout
stderr
optarg
optind
opterr
optopt
optreset
_ctype_
sys_siglist
tzname
h_errno
```

Run: `cd toolchain && make libc_so && python3 -c "import sys; sys.path.insert(0,'src/ld'); import fgx_ld, struct; d=open('lib/libc.so.1.0','rb').read(); n=d[6]; nr=struct.unpack_from('<H',d,11)[0]; p=16+8*n+sum(struct.unpack_from('<H',d,16+8*i)[0] for i in range(n))+4*nr; t=fgx_ld.read_trailer(d[p:]); print(d[10], len(t['exports']), len(t['blocks']), len(t['fixups']))"`
Expected: `2 <exports> 37 3` -- flag set, 37 blocks, three fixups
(stdin, stdout, stderr); of the exports, exactly 14 are data.

Run the byte-identity check from Task 3 Step 4 again.
Expected: `same cat_fgx`, `same sh`, `same tcsh`.

- [ ] **Step 5: Commit.**

```bash
git add toolchain/src/ld/fgx_ld.py toolchain/src/ld/test_fgx_ld_library.py \
        toolchain/src/ld/fgx_libso.py toolchain/Makefile \
        toolchain/lib/libc_c/data.exports
git commit -m "feat(ld): libc.so carries its export table, block table and fixups

A manifest's library block makes fgx_ld append a trailer after the relocs,
flagged by header flags bit 1: libc's version, the core's base and size, the
export table (every public code name and the fourteen data names libc's
headers declare extern, lib/libc_c/data.exports, sorted, the index its
ordinal) with a CRC-32 over it for prebinding, one row per stateful member
(block cell, template offset, size) and the fixups.  A reloc from the core
into itself -- stdin, stdout and stderr pointing into the FILE table -- is a
fixup, since the core's bank is each process's.  The link refuses a pointer
into a block or from a block into the core, a data export or core.list
name the core does not define, a static in both a block and the core, and a
template whose listed size disagrees with the blocks file.  Its test links
assembled segments end to end, core at $F000.

```

---

### Task 6: tools/libc_so_check.py, with its positive control

**Files:**
- Create: `tools/libc_so_check.py`
- Modify: `toolchain/Makefile` (`test-archives`)

**Interfaces:**
- Consumes: `fgx_ld.read_trailer`, `fgx_ld.library_trailer`,
  `fgx_ld.scan_listing`, `fgx_ld.LIB_FLAG`, `fgx_ld.read_names`,
  `gen_seg1_layout.extract_labels`; `toolchain/lib/libc.so.1.0` and
  `toolchain/lib/libc_so.d/` from Task 4.
- Produces: `check(data, d) -> [error strings]`; exit 0 and a size report
  when clean.

- [ ] **Step 1: Write the checker with its self-test.**

```python
#!/usr/bin/env python3
"""libc_so_check.py - what libc.so.1.0 must hold (shared libc SP2 spec,
section 8).

  - every export resolves inside its segment (code) or the core (data), the
    data exports are exactly lib/libc_c/data.exports, and the stored
    checksum is the export records' CRC;
  - the boundary holds: libc.so exports no libfgx or libutil name, and no
    bank source uses PILE_CALL;
  - every FGX2_FARCALL/FARJUMP a bank's listing shows has its bank reloc;
  - nothing points into a block template, and no template points into the
    core;
  - the templates tile their segment and every block cell is in the core;
  - every fixup is in the core, and there is at least one (stdin, stdout,
    stderr).

--self-test runs the checks on the built file (clean) and on three broken
copies that must fail: one JSL's reloc removed, one export moved past its
segment's end, one byte of an export name changed under its checksum.

Run: python3 tools/libc_so_check.py [--self-test]   (after make -C toolchain libc_so)
"""
import glob
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TC = os.path.join(ROOT, "toolchain")
sys.path.insert(0, os.path.join(TC, "src", "ld"))
sys.path.insert(0, os.path.join(TC, "tools"))
import fgx_ld  # noqa: E402
import gen_seg1_layout  # noqa: E402

SO = os.path.join(TC, "lib", "libc.so.1.0")
D = os.path.join(TC, "lib", "libc_so.d")


def parse(data):
    """Header fields, segments, kinds, relocs, the reloc table's offset and
    the trailer (None when the flag is clear)."""
    n, flags = data[6], data[10]
    nrel = struct.unpack_from("<H", data, 11)[0]
    segs, kinds, pos = [], [], 16 + 8 * n
    for i in range(n):
        size, _bss, kind = struct.unpack_from("<HHB", data, 16 + 8 * i)
        segs.append(data[pos:pos + size])
        kinds.append(kind)
        pos += size
    relpos = pos
    relocs = [struct.unpack_from("<BHB", data, pos + 4 * i) for i in range(nrel)]
    pos += 4 * nrel
    tr = fgx_ld.read_trailer(data[pos:]) if flags & fgx_ld.LIB_FLAG else None
    return {"segs": segs, "kinds": kinds, "relocs": relocs, "relpos": relpos,
            "trailer": tr, "trailer_pos": pos}


def boundary_names():
    names = set()
    for p in [os.path.join(TC, "lib", "libfgx.s")] + \
            glob.glob(os.path.join(TC, "lib", "util.fgxa", "*.s")):
        for ln in open(p, errors="replace"):
            t = ln.split()
            if t[:1] == ["FGX2_EXPORT"] and len(t) > 1:
                names.add(t[1])
    return names


def check(data, d):
    p = parse(data)
    tr, segs, kinds = p["trailer"], p["segs"], p["kinds"]
    if tr is None:
        return ["no library trailer (header flags bit 1 clear)"]
    errs = []
    core, tmpl = tr["core"], tr["templates"]
    lo, hi = tr["core_base"], tr["core_base"] + tr["core_size"]
    for name, kind, seg, val in tr["exports"]:
        if kind == 0 and (seg >= len(segs) or kinds[seg] != 0 or val >= len(segs[seg])):
            errs.append("export %s resolves outside its code segment (%d:%#06x)"
                        % (name, seg, val))
        if kind == 1 and not lo <= val < hi:
            errs.append("data export %s at %#06x is outside the core" % (name, val))
    if tr["crc"] != tr["checksum"]:
        errs.append("export table CRC %08x is not the stored checksum %08x"
                    % (tr["crc"], tr["checksum"]))
    listed = set(fgx_ld.read_names(os.path.join(TC, "lib", "libc_c", "data.exports")))
    data_ex = {e[0] for e in tr["exports"] if e[1] == 1}
    if data_ex != listed:
        errs.append("data exports differ from data.exports: %s"
                    % sorted(data_ex ^ listed))
    for n in sorted({e[0] for e in tr["exports"]} & boundary_names()):
        errs.append("libc.so exports %s, a libfgx/libutil name" % n)
    for src in sorted(glob.glob(os.path.join(d, "bank*.s"))):
        if "PILE_CALL" in open(src).read():
            errs.append("%s uses PILE_CALL" % os.path.basename(src))
    have = {(s, o) for s, o, _t in p["relocs"]}
    for k, kind in enumerate(kinds):
        if kind != 0:
            continue
        scan = fgx_ld.scan_listing(os.path.join(d, "bank%d_Output.txt" % k),
                                   len(segs), libc=True)
        for addr, name, mac in scan["farcalls"]:
            if (k, addr + 3) not in have:
                errs.append("bank %d: %s %s at %#06x has no reloc" % (k, mac, name, addr))
    for s, o, t in p["relocs"]:
        if t == tmpl or (s == tmpl and t == core):
            errs.append("reloc %d:%#06x -> %d crosses a block boundary" % (s, o, t))
    offs = sorted(b[1:] for b in tr["blocks"])
    pos = 0
    for t, size in offs:
        if t != pos:
            errs.append("block templates do not tile: gap or overlap at %#06x" % pos)
        pos = t + size
    if pos != len(segs[tmpl]):
        errs.append("block templates cover %d of %d bytes" % (pos, len(segs[tmpl])))
    for cell, _t, _s in tr["blocks"]:
        if not lo <= cell < hi:
            errs.append("block cell %#06x is outside the core" % cell)
    for f in tr["fixups"]:
        if not 0 <= f < tr["core_size"]:
            errs.append("fixup %#06x is outside the core" % f)
    if not tr["fixups"]:
        errs.append("no per-process fixups (stdin, stdout, stderr need three)")
    return errs


def report(data, d):
    p = parse(data)
    tr = p["trailer"]
    labels = sorted(gen_seg1_layout.extract_labels(os.path.join(d, "core_Output.txt")))
    def label_of(addr):
        return max((l for l in labels if l[0] <= addr), default=(0, "?"))[1]
    code = [len(s) for s, k in zip(p["segs"], p["kinds"]) if k == 0]
    nd = sum(1 for e in tr["exports"] if e[1] == 1)
    print("libc_so_check: clean -- %d code banks (%s bytes), core %d bytes at "
          "$%04X, %d blocks (%d bytes), %d exports (%d code, %d data), fixups: %s"
          % (len(code), ", ".join(map(str, code)), tr["core_size"],
             tr["core_base"], len(tr["blocks"]), sum(b[2] for b in tr["blocks"]),
             len(tr["exports"]), len(tr["exports"]) - nd, nd,
             ", ".join(label_of(tr["core_base"] + f) for f in tr["fixups"])))


def self_test():
    data = open(SO, "rb").read()
    errs = check(data, D)
    assert not errs, errs
    p = parse(data)
    # Control 1: remove the reloc of the first JSL in bank 0.
    idx = next(i for i, (s, o, _t) in enumerate(p["relocs"])
               if s == 0 and p["segs"][0][o - 3] == fgx_ld.JSL_OPCODE)
    rel = p["relpos"] + 4 * idx
    nrel = struct.unpack_from("<H", data, 11)[0]
    bad = bytearray(data[:rel] + data[rel + 4:])
    struct.pack_into("<H", bad, 11, nrel - 1)
    assert any("has no reloc" in e for e in check(bytes(bad), D)), \
        "a JSL with no reloc was not caught"
    # Control 2: an export moved past its segment's end.
    tr = p["trailer"]
    ex = list(tr["exports"])
    i = next(i for i, e in enumerate(ex) if e[1] == 0)
    ex[i] = (ex[i][0], 0, ex[i][2], len(p["segs"][ex[i][2]]))
    t2 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"],
                                tr["templates"], tr["core_base"], tr["core_size"],
                                ex, tr["blocks"], tr["fixups"])
    bad2 = data[:p["trailer_pos"]] + t2
    assert any("resolves outside" in e for e in check(bad2, D)), \
        "an export past its segment was not caught"
    # Control 3: one byte of the first export's name changed, checksum kept.
    bad3 = bytearray(data)
    first = p["trailer_pos"] + 4 + struct.calcsize("<BBBBHHHHHI") + 1
    bad3[first] ^= 0x20
    assert any("CRC" in e for e in check(bytes(bad3), D)), \
        "a corrupted export record was not caught"
    print("libc_so_check: self-test OK (clean file passes, three broken copies fail)")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    data = open(SO, "rb").read()
    errs = check(data, D)
    for e in errs:
        print("libc_so_check: " + e)
    if errs:
        return 1
    report(data, D)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run it before the controls can pass trivially -- break the
  checker and watch the self-test fail.**  Temporarily change
  `if (k, addr + 3) not in have:` to `if False:`.

Run: `python3 tools/libc_so_check.py --self-test`
Expected: `AssertionError: a JSL with no reloc was not caught`.  Restore
the line.

- [ ] **Step 3: Run it for real.**

Run: `python3 tools/libc_so_check.py --self-test && python3 tools/libc_so_check.py`
Expected: `self-test OK`, then the `clean --` report, whose fixups line
reads `stdin, stdout, stderr`.

- [ ] **Step 4: Wire into `test-archives`.**  Add `lib/libc.so.1.0` to its
  prerequisites and these lines after `check_libso_identity.py`:

```make
	python3 src/ld/fgx_libso.py --self-test
	python3 src/ld/test_fgx_ld_library.py
	python3 ../tools/libc_so_check.py --self-test
	python3 ../tools/libc_so_check.py
```

Run: `cd toolchain && make test-archives 2>&1 | tail -15`
Expected: every check passes; the last lines include the libc_so_check
report.

- [ ] **Step 5: Commit.**

```bash
git add tools/libc_so_check.py toolchain/Makefile
git commit -m "test(ld): libc_so_check proves what libc.so.1.0 holds

Every export resolves, the data exports are exactly data.exports and the
stored checksum is the records' CRC, libc.so exports no libfgx or libutil
name, no bank uses a pile call, every JSL a bank's listing shows has its
bank reloc, nothing points into a block or from a block into the core, the
templates tile their segment, and the fixups are in the core.  The
self-test runs on the built file and on three broken copies -- a JSL's
reloc removed, an export moved past its segment, an export name corrupted
under its checksum -- which must fail.  Runs in make test-archives.

```

---

### Task 7: record the step, run the gate

**Files:**
- Modify: `docs/history/plans/2026-09-28-shared-libc-sp2-design.md`
  (section 3's runtime sentence, section 10)

- [ ] **Step 1: The spec.**  In section 6, after "each code bank carries the
  helpers its own functions use, selected per bank by fgx_gc (as tcsh's banks
  do)", add: "-- once `fcc_runtime.s` is sectioned (step 5); until then each
  bank carries the whole runtime, as each tcsh bank does."  In section 10,
  add a bullet: "Step 3 landed <date> (plan
  `2026-09-29-shared-libc-sp2-step3-plan.md`): `make libc_so` links
  `lib/libc.so.1.0`" with the numbers from the libc_so_check report (banks and
  sizes, core size and base, exports, blocks, fixups), and the findings: the
  data-sectioning fix, Merlin's 64 KB object limit, the direct-page cells
  every bank defines, the per-segment `org` (offsets in, addresses out), and
  the data exports held to section 4's list in `data.exports`.

- [ ] **Step 2: The gate.**  Announce: "running the gate on feat/shared-libc
  at <HEAD> -- it rebuilds every binary".

Run: `tools/gate.sh 2>&1 | tail -5`
Expected: `GATE GREEN`.  If the seconds ratchet (`gate_budget.py`) refuses
the added host checks, stop and ask: adding to the gate means taking
something out.

- [ ] **Step 3: Commit, and record in the project notes** (`group_id="fgx"`, triplets):
  "fgx_libso SUPERSEDES the step 3 NEXT pointer"; "fcc's compiled string
  members name the shims' DP cells c_strcmp_a/b, so every libc.so bank
  defines them"; "fcc_runtime.s has no sections (each libc.so bank carries
  it whole)"; "libc.so data exports are lib/libc_c/data.exports only".

```bash
git add docs/history/plans/2026-09-28-shared-libc-sp2-design.md
git commit -m "docs(plans): shared libc SP2 step 3 landed

```
