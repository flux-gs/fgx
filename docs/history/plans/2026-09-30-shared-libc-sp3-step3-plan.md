# Shared libc SP3 step 3: fgx_ld's dynamic link mode -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Link a program against `libc.so.1.0` (and `libtermlib.so.1.0`,
`libcurses.so.1.0`) without copying them in: a dynamic FGX3 file (header
flags bit 2) whose `FGXD` trailer names the libraries it needs, their
reachability bitmaps, its imports and every call, pointer and data site --
with the far-helper thunks, the fit rule, the shadowing warning, K&R
commons against library exports, and stack sizing that reads the
libraries' code.

**Architecture:** A driver, `toolchain/src/ld/fgx_dyn.py`, does for a
dynamic program what `fgx_static.py` does for a static one: it assembles
segment 0 (crt0_lib.s, the program, the fcc runtime with the far helpers
replaced by thunks, `_crt0_inits`) and segment 1 (the program's data, its
own runtime cells, the bitmaps), with the needed libraries' data exports
as `EQU`s at their prebound addresses, and hands them to fgx_ld with
`"imports"` and `"dynamic": true`.  fgx_ld binds unresolved calls, jumps
and pointer cells through step 1's resolver and writes the `FGXD`
trailer.  The driver then links a second time with the data `EQU`s moved
down by `$1010`, diffs the two (step 1's `fgx_sites`), and adds the data
sites and bitmaps to the trailer.

**Tech Stack:** Python 3 (fgx_ld, the new fgx_dyn, fgx_gc, fgx_imports,
fgx_sites, stack_measure), Merlin32, fcc (fixtures).

**Spec:** `docs/history/plans/2026-09-29-shared-libc-sp3-design.md`,
section 3 ("Dynamic program", "Finding data sites", "The fcc runtime",
"Link-time checks") and 2a (commons, dynamic links), section 6 item 3.
Revised the same day for an adversarial review (Fable, which prototyped
the link: hello assembles, binds and diffs as planned), twelve findings
adopted.  Settled here, from reading the code:

- **One code segment and the data segment.**  The driver puts all of a
  program's code in segment 0, as fgx_static does; programs whose code
  needs several banks (tcsh, vi, frotz) are linked dynamically in
  sub-project 5, through the ninja/tool machinery that already packs
  them.  The trailer and fgx_ld's binding are per segment, so nothing here
  assumes one segment.
- **The trailer.**  `FGXD`, a version byte (1), then tagged length-prefixed
  blocks as the library trailer's: `IMPS` (step 1's encoding, whose
  needed-library records already carry `bitmap`).  Header flags bit 2
  (`DYN_FLAG = 0x04`).  A reader: `fgx_ld.read_dyn_trailer`.
- **Commons.**  A program's tentative definition (`<name> DS <n>` in its
  data file) of a needed library's data export is dropped from the data
  the driver assembles, and the name resolves to the library's through its
  `EQU` (spec 2a).  An initialised definition, or a function, shadows: the
  program keeps its own (its references bind to it), a warning names both,
  and the name gets no `EQU`.
- **The bitmap.**  fgx_gc's reachability over every needed library's
  library-mode code and data (`lib/<lib>_so.s`, `_so_data.s`), rooted at
  the names the program imports; a live cell `_<lib>_blk_<m>` sets member
  m's bit, m's index being its row in `_<lib>_blktab` (sorted member
  names, `fgx_libso.blktab`).  A shadowed name is still a root (fgx_gc
  cannot tell the program's definition from the library's): the member is
  built needlessly, stated (spec section 3).
- **The fit rule.**  `LIM` = the lowest needed core's prebound base minus
  the reached blocks' sizes; the data segment's bytes must end at or below
  it (a dynamic program's data segment has no bss: fcc emits its zeroed
  data as `DS` rows).  Refused with the three numbers.
- **Thunks.**  The program's runtime is `fcc_runtime.s` split by
  `fgx_libso.runtime_units`, each far helper's unit (the nine
  `_fcc_*_far` exports in `lib/libc_so_helpers.s`) replaced by
  `<helper> MX %00 / FGX2_FARCALL <helper>_far / RTS`.
- **What each segment holds.**  Segment 0: `macros.s`, `seg1_layout.s`,
  `imports_layout.s`, crt0_lib.s, the program's code, the thunked runtime,
  `inits.s`.  Segment 1: the 256-byte pad, `dataptr_mac.s` (the
  `LIBC_DATA_PTR` macro fcc's `&errno` initialisers use, extracted from
  `libc_data.s` by `fgx_libso.write_dataptr_mac`), `imports_layout.s`
  (so `LIBC_DATA_PTR _Spg;errno` resolves; gen_seg1_layout ignores EQU
  rows, so segment 0 does not see them twice), `fcc_runtime_data.s` (the
  program's own runtime cells), the program's data (commons dropped),
  `dyn.data.s` (one bitmap per needed library, `_dyn_bits_<lib>`).  No
  `libc_data.s`/`args_data.s`: those cells are libc's core.
- **Stack sizing.**  `stack_frames` lists the program's `.s` and the
  library code the program reaches -- the live sections of the bitmap pass,
  written to `d/<lib>_reach.s` -- so a call into a library is priced from
  its code (spec section 3).  Not the whole library `.s`: libc's own
  `syslog`/`vsyslog` cycle would warn on every link.  Measured by the
  review: 0.1-0.2 s for all three libraries.  The shifted link omits
  `stack_frames` (only segment bytes are diffed).
- **Library order.**  `--lib` names the libraries the program uses; the
  driver adds the ones below them (`fgx_libso.LIBS[n]["below"]`) and
  orders them for loading.
- **The runtime is pruned.**  fgx_gc keeps only the runtime units the
  program's code, crt0_lib.s and inits.s reach, so a program imports a far
  helper exactly when it uses it.
- **`build/libc.sigs`** (a ninja product) is what the fixtures compile
  against: the tests run inside the gate after `ninja all`; run alone,
  they need a built tree.
- **Out of this step:** running it (step 4's host binder and MAME), the
  copy step, multi-segment dynamic programs (sub-project 5).

## Global Constraints

- ASCII only; comments describe the current state; commit bodies
  informational, ending with
- Every shipped binary is unchanged (fgx_ld's existing paths byte-identical;
  the gate proves it).
- Branch `feat/shared-libc`, not pushed; announce every rebuild.

## Review Focus

1. `LDA stdout+2` in a program -- a data site attributed to `stdout`,
   moved by stdout's delta, not refused (Task 4: hello's
   `fflush(stdout)` loads both halves of the pointer).
2. A program whose tentative `char *UP;` meets termlib's `UP` -- no
   warning, no duplicate label, `UP` an import with data sites (Task 5:
   tctest).
3. A program defining `fflush` -- a warning naming libc, and its own
   calls bind to its own (Task 5: ul; the call sites of `fflush` in ul are
   not IMPS call sites).
4. A far helper reached from the program -- a thunk in segment 0 and an
   IMPS call site for `<helper>_far`; `_fcc_fadd` keeps its body (Task 2,
   Task 4's hello does a `long` divide).
5. A program whose bss leaves no room for its libraries' cores and
   blocks -- refused with the numbers, not linked (Task 5: fit fixture).

---

### Task 1: fgx_ld writes a dynamic program's trailer

**Files:**
- Modify: `toolchain/src/ld/fgx_ld.py` (`DYN_FLAG`, `DYN_MAGIC`,
  `dyn_trailer`, `read_dyn_trailer`; `main` writes it when the manifest
  says `"dynamic": true`)
- Test: `toolchain/src/ld/test_fgx_ld_library.py` (`dynamic_link()`)

**Interfaces:**
- Produces: `fgx_ld.DYN_FLAG = 0x04`, `fgx_ld.DYN_MAGIC = b"FGXD"`,
  `dyn_trailer(extra: bytes) -> bytes` (`FGXD`, version byte 1, then the
  tagged blocks in `extra`), `read_dyn_trailer(data) -> {"version": 1,
  "blocks_raw": {tag: payload}}` (ValueError on a bad magic or version).
  A manifest with `"dynamic": true` and `"imports"` gets header flags bit
  2 and a trailer holding an `IMPS` block (possibly with no imports).

- [ ] **Step 1: Failing test.**  In `test_fgx_ld_library.py`, a
  `dynamic_link()` reusing `lower_so(d)`: one code segment
  `FGX2_FARCALL strcpy` / `RTL` and one data segment, manifest
  `{"dynamic": true, "imports": [[so, lst]]}`, no `"library"`; assert
  `out[10] & fgx_ld.DYN_FLAG`, not `LIB_FLAG`; the trailer after the relocs
  reads with `read_dyn_trailer`; its IMPS lists `strcpy` with a call site
  at `(0, 1)`; no reloc at `(0, 3)`.  And `read_dyn_trailer(b"FGXL...")`
  raises ValueError.  Call it from the file's main sequence.

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py | grep -E 'FAIL|passed'`
Expected: an AttributeError traceback (`fgx_ld` has no `DYN_FLAG`).

- [ ] **Step 2: Implement.**

```python
DYN_FLAG = 0x04
DYN_MAGIC = b"FGXD"
DYN_VERSION = 1


def dyn_trailer(extra):
    """A dynamic program's trailer: FGXD, a version byte, then tagged
    blocks (IMPS: the libraries it needs with their bitmaps, its imports
    and their sites; shared libc SP3 spec, section 3)."""
    return DYN_MAGIC + bytes([DYN_VERSION]) + extra


def read_dyn_trailer(data):
    if data[:4] != DYN_MAGIC:
        raise ValueError("no dynamic trailer")
    if data[4] != DYN_VERSION:
        raise ValueError(f"dynamic trailer version {data[4]}; this reader "
                         f"knows {DYN_VERSION}")
    pos, raw = 5, {}
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4].decode("ascii")
        n = struct.unpack_from("<I", data, pos + 4)[0]
        raw[tag] = data[pos + 8:pos + 8 + n]
        pos += 8 + n
    return {"version": DYN_VERSION, "blocks_raw": raw}
```

  In `main`, after the library block: `if m.get("dynamic"):` -- die if
  `"library"` is also set ("a library is not a dynamic program") or
  `"imports"` is missing; `trailer = dyn_trailer(block(b"IMPS",
  resolver.pack()))`; `flags |= DYN_FLAG`.

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py | grep -E 'FAIL|passed'`
Expected: `fgx_ld library checks passed`.

- [ ] **Step 3: Commit** (`feat(ld): fgx_ld writes a dynamic program's FGXD trailer`,
  body: flags bit 2, the trailer's layout, the IMPS block; trailers).

---

### Task 2: the program's runtime, with thunks for the far helpers

**Files:**
- Create: `toolchain/src/ld/fgx_dyn.py` (module docstring, `far_helpers`,
  `thunked_runtime`, `self_test`)

**Interfaces:**
- Produces: `far_helpers(path=LIB/libc_so_helpers.s) -> [str]` (the
  helper names, `_fcc_fdiv` for `_fcc_fdiv_far`);
  `thunked_runtime(far, roots=None) -> [str]` (fcc_runtime.s's rows: its
  head, then the units in order -- each far helper's replaced by three
  rows -- and, when `roots` (text) is given, only the units it reaches).

- [ ] **Step 1: Failing self-test.**

```python
def self_test():
    far = far_helpers()
    assert "_fcc_fdiv" in far and "_fcc_fsub" not in far and len(far) == 9, far
    rows = thunked_runtime(far)
    text = "\n".join(rows)
    i = rows.index("_fcc_fdiv       MX      %00")
    assert rows[i + 1].split() == ["FGX2_FARCALL", "_fcc_fdiv_far"]
    assert rows[i + 2].split() == ["RTS"]
    assert any(r.startswith("_fcc_fadd") for r in rows)       # fsub's unit kept
    assert text.count("_fcc_fdiv       MX") == 1
    few = "\n".join(thunked_runtime(far, "  JSR _fcc_fdiv\n"))
    assert "FGX2_FARCALL _fcc_fdiv_far" in few
    assert "_fcc_fmul" not in few and "_fcc_long_divs" not in few  # unreached
    print("fgx_dyn: self-test OK")
```

Run: `python3 toolchain/src/ld/fgx_dyn.py --self-test`
Expected: FAIL (the file does not exist).

- [ ] **Step 2: Implement.**

```python
def far_helpers(path=os.path.join(LIB, "libc_so_helpers.s")):
    """The helpers libc.so exports far (tools/helper_census.py)."""
    out = []
    for ln in open(path):
        t = ln.split()
        if t[:1] == ["FGX2_EXPORT"] and t[1].endswith("_far"):
            out.append(t[1][:-len("_far")])
    return out


def thunked_runtime(far, roots=None):
    """fcc_runtime.s for a dynamic program: each far helper's unit becomes
    a thunk to libc.so's far entry, so fcc's JSR stays as it is (shared
    libc SP3 spec, section 3); the helpers are cold by the census's rule,
    so the thunk's JSR/RTS is on no measured path.  Given `roots' (the text
    of the program's code, crt0 and inits), only the units it reaches are
    kept, so the program imports a far entry exactly when it uses it."""
    head, units, order = fgx_libso.runtime_units(
        open(fgx_libso.RUNTIME).read().split("\n"))
    for u in far:
        units[u] = [units[u][0], "%-15s MX      %%00" % u,
                    "                FGX2_FARCALL %s_far" % u,
                    "                RTS", units[u][-1]]
    keep = set(order)
    if roots is not None:
        files = {"__roots__": roots.split("\n"), "__rt__": sum(
            (units[u] for u in order), [])}
        g_units, owner, body, is_data, rts = fgx_gc.graph(
            files, ["__roots__", "__rt__"], {"__rt__"})
        keep = {g_units["__rt__"][i][1] for p, i in
                fgx_gc.reach(rts, owner, body, is_data)}
    rows = list(head)
    for u in order:
        if u in keep:
            rows += units[u][1:-1]                # drop FGX_SECT/FGX_ENDS
    return rows
```

Run: `python3 toolchain/src/ld/fgx_dyn.py --self-test`
Expected: `fgx_dyn: self-test OK`.

- [ ] **Step 3: Commit** (`feat(ld): a dynamic program's runtime thunks the far helpers`).

---

### Task 3: which names the program imports, commons and shadows, the bitmap

**Files:**
- Modify: `toolchain/src/ld/fgx_dyn.py` (`Libs`, `program_names`,
  `split_data`, `bitmaps`, self-test cases)

**Interfaces:**
- Produces:
  - `Libs(names)` -- the named libraries and every one below them, in load
    order (`["libtermlib"]` gives `["libc", "libtermlib"]`): `.names`;
    `.libs` = `[(so_path, core_listing, trailer)]` in load order (via
    `fgx_libso.so_path`, `LIBS[n]["dir"]`); `.data` = `{name: (addr,
    size)}` of their data exports; `.code` = set of code exports;
    `.lowest` = the lowest core base.
  - `program_names(code_rows, data_rows) -> (defined_code, defined_data,
    referenced)`: FGX2_EXPORT names in the code, column-1 labels in the
    data, and every identifier the code and data name.
  - `split_data(data_rows, libs, code_exports) -> (rows, dropped,
    shadowed)`: rows with
    each `<name> DS <n>` row whose name is a library data export removed
    (`dropped`; one larger than the export dies naming both sizes), and
    `shadowed` = the program's other definitions -- data labels and
    `code_exports` -- of a
    library export (data labels that are not dropped, code exports).
  - `bitmaps(libs, roots) -> (bits {lib: bytes}, need {lib: int},
    live {lib: [section rows]})` -- the bitmaps, the reached block bytes,
    and the live code sections of each library (for stack sizing).

- [ ] **Step 1: Failing self-test cases** (in `self_test`, over the built
  libraries -- the test runs after `make libso_all`):

```python
    libs = Libs(["libc"])
    assert "errno" in libs.data and "printf" in libs.code
    rows, dropped, shadowed = split_data(
        ["errno           DS      2", "mine            DS      2",
         "optind          DA      1"], libs, {"fflush", "main"})
    assert dropped == ["errno"] and rows[0].startswith("mine")
    assert shadowed == ["fflush", "optind"]
    try:
        split_data(["errno           DS      64"], libs, set())
    except SystemExit as e:
        assert "64" in str(e) and "2" in str(e)
    else:
        raise AssertionError("a common larger than the export must be refused")
    bits, need, live = bitmaps(libs, {"strtok"})
    assert any(r.split()[:1] == ["strtok"] or "strtok" in r.split()[:1]
               for r in sum(live["libc"], []))
    members = sorted(json.load(open(fgx_libso.lib_file("libc", "blocks")))["members"])
    i = members.index("strtok")
    assert bits["libc"][i >> 3] & (1 << (i & 7))
    j = members.index("ctime")
    assert not bits["libc"][j >> 3] & (1 << (j & 7))       # unreached
    assert need["libc"] == json.load(open(fgx_libso.lib_file(
        "libc", "blocks")))["members"]["strtok"]["size"]
```

Run: `python3 toolchain/src/ld/fgx_dyn.py --self-test`
Expected: FAIL (`Libs` undefined).

- [ ] **Step 2: Implement.**

```python
LABEL = re.compile(r"^([A-Za-z_]\w*)\b")


class Libs:
    """The libraries a program needs, in load order."""

    def __init__(self, names):
        want = set()
        def add(n):
            if n not in want:
                want.add(n)
                for b in fgx_libso.LIBS[n]["below"]:
                    add(b)
        for n in names:
            add(n)
        self.names = [n for n in fgx_libso.LIBS if n in want]   # load order
        self.libs = [(fgx_libso.so_path(n),
                      os.path.join(LIB, fgx_libso.LIBS[n]["dir"], "core_Output.txt"),
                      fgx_imports.file_trailer(open(fgx_libso.so_path(n), "rb").read()))
                     for n in names]
        self.data = {e[0]: (e[3], e[4]) for _s, _l, tr in self.libs
                     for e in tr["exports"] if e[1] == 1}
        self.code = {e[0] for _s, _l, tr in self.libs
                     for e in tr["exports"] if e[1] == 0}
        self.lowest = min(tr["core_base"] for _s, _l, tr in self.libs)


def program_names(code_rows, data_rows):
    code = set(fgx_gc.exported_names(code_rows))
    data = {m.group(1) for r in data_rows for m in [LABEL.match(r)] if m}
    refs = set(fgx_gc.IDENT.findall(fgx_gc.code_of(code_rows + data_rows)))
    return code, data, refs


DS_SIZE = re.compile(r"^([A-Za-z_]\w*)\s+DS\s+(\d+)\s*$")


def split_data(data_rows, libs, code_exports):
    """K&R A.10.2's common extension against the libraries: a tentative
    definition of a library data export is a declaration (dropped; the
    name binds to the library's EQU) -- unless it is larger than the
    export, which would write past it into the library's next cell.  Any
    other definition of a library export, data or function, shadows it."""
    rows, dropped = [], []
    for r in data_rows:
        m = DS_SIZE.match(r)
        if m and m.group(1) in libs.data:
            n, size = m.group(1), int(m.group(2))
            if size > libs.data[n][1]:
                die("the program's tentative %s is %d bytes; the library's "
                    "is %d" % (n, size, libs.data[n][1]))
            dropped.append(n)
            continue
        rows.append(r)
    labels = {m.group(1) for r in rows for m in [LABEL.match(r)] if m}
    shadowed = sorted((labels | set(code_exports))
                      & (set(libs.data) | libs.code))
    return rows, dropped, shadowed


def bitmaps(libs, roots):
    """Each needed library's reachability bitmap over its block-table rows
    (sorted member names), from the names the program imports, through
    every needed library's library-mode code and data."""
    files, order = {}, []
    for n in libs.names:
        for k in ("code", "data"):
            p = fgx_libso.lib_file(n, k)
            files[p] = open(p).read().split("\n")
            order.append(p)
    root = "__roots__"
    files[root] = ["        " + " ".join(sorted(roots))]
    units, owner, body, is_data, rts = fgx_gc.graph(files, [root] + order, set(order))
    live = fgx_gc.reach(rts, owner, body, is_data)
    names = {units[p][i][1] for p, i in live}
    bits, need, code = {}, {}, {}
    for n in libs.names:
        cp = fgx_libso.lib_file(n, "code")
        code[n] = [units[cp][i][2] for p, i in sorted(live) if p == cp]
        members = json.load(open(fgx_libso.lib_file(n, "blocks")))["members"]
        order_m = sorted(members)
        b = bytearray((len(order_m) + 7) // 8)
        need[n] = 0
        for i, m in enumerate(order_m):
            if "_%s_blk_%s" % (n, m) in names:
                b[i >> 3] |= 1 << (i & 7)
                need[n] += members[m]["size"]
        bits[n] = bytes(b)
    return bits, need, code
```

Run: `make -C toolchain libso_all >/dev/null && python3 toolchain/src/ld/fgx_dyn.py --self-test`
Expected: `fgx_dyn: self-test OK`.

- [ ] **Step 3: Commit** (`feat(ld): a dynamic program's imports, commons, shadows and bitmaps`).

---

### Task 4: fgx_dyn links a program

**Files:**
- Modify: `toolchain/src/ld/fgx_dyn.py` (`inits`, `link_once`, `build`,
  `main`), `toolchain/src/ld/fgx_static.py` (`inits` gains a `bits`
  argument)
- Create: `toolchain/tests/dyn/hello.c`, `toolchain/tests/dyn/test_dyn.py`

**Interfaces:**
- Consumes: Tasks 1-3; step 1's `fgx_sites.diff_sites`/`attribute`,
  `fgx_imports.Resolver`/`pack`/`unpack`.
- Produces: `fgx_static.inits(tables, bits=None)` -- `bits` a list of
  bitmap labels parallel to `tables` (None: NULL for every row, as
  fgx_static passes); `fgx_dyn.build(name, d, code, data, out, libs,
  shift=0) -> dict`; CLI `fgx_dyn.py --name N --dir D --code a.s --data
  a.data.s --lib libc[,libtermlib...] --out F`.

- [ ] **Step 1: The fixture and the failing test.**  `tests/dyn/hello.c`:

```c
/* A dynamic link's fixture (shared libc SP3 step 3): a call, a pointer
 * cell, data with and without an addend, a far helper. */
#include <stdio.h>
#include <string.h>
#include <errno.h>
static char *v[] = { "b", "a" };
int *ep = &errno;
int
main()
{
    long q = 1000L;
    int n = 7;
    *ep = 0;
    errno = 0;
    qsort(v, 2, sizeof v[0], strcmp);
    q = q / (long)n;
    printf("%s%s %ld\n", v[0], v[1], q);
    fflush(stdout);
    return errno;
}
```

  (FILE is opaque in FGX's `<stdio.h>`; passing `stdout` compiles to
  `LDA stdout+2` / `LDA stdout`, as bytecatso's code shows, so
  `fflush(stdout)` gives a data site with an addend.)
  `tests/dyn/test_dyn.py` compiles it with `../../fcc
  --sigs ../../../build/libc.sigs`, links it with `fgx_dyn.py --lib libc`,
  and checks: header flag bit 2; the trailer's IMPS names libc with
  libc.so's CRC; imports include `qsort`, `printf`, `strcmp` (a `ptr`
  site), `_fcc_long_divs_far` (a `call` site), `errno` and `stdout`
  (data sites; one of stdout's holds stdout's address + 2), `_libc_start`, `_lib_init`, `_libc_blktab`; every
  `FGX2_FARCALL` row of seg0's listing naming a name the program does not
  define is a call site; the bitmap has `malloc`'s and `proc`'s bits set
  (reached: printf's buffers, the exit path) and `ctime`'s clear; a data
  site in segment 1 for `errno` (`ep`'s `LIBC_DATA_PTR`); the imports
  include `_fcc_long_divs_far` and not `_fcc_fdiv_far` (hello divides
  longs and never floats); `_dyn_bits_libc` in segment 1 holds
  the trailer's bitmap.

Run: `cd toolchain && python3 tests/dyn/test_dyn.py`
Expected: a traceback (`fgx_dyn` has no `build`).

- [ ] **Step 2: `inits` with bitmaps** (fgx_static): when `bits` is given,
  the first two pushes become the bitmap's far pointer, pushed the same way
  as the table's -- bank (`SEP #$20 / PHB / PLA / REP #$20 / AND #$00FF /
  PHA`) then `PEA <bits label>`.  fgx_static keeps calling `inits([...])`;
  its self-test is unchanged and still passes.

- [ ] **Step 3: `build`.**

```python
SEG0_EQUS = fgx_static.SEG0_EQUS


def link_once(name, d, code, data_rows, libs, shift, shadowed, gen):
    """Assemble segments 0 and 1 in d with the libraries' data EQUs `shift'
    below their prebound addresses, and link.  `gen' is {file: text} of the
    generated sources (rt.s, inits.s, dyn.data.s), written here so each link
    directory has its own.  Returns the output path."""
    os.makedirs(d, exist_ok=True)
    fgx_libso.clear_outputs(d, OUTPUT)
    for fn, text in gen.items():
        with open(os.path.join(d, fn), "w") as f:
            f.write(text)
    fgx_libso.write_dataptr_mac(d)
    with open(os.path.join(d, "imports_layout.s"), "w") as f:
        for n, (a, _sz) in sorted(libs.data.items()):
            if n not in shadowed:
                f.write("%-18s EQU    $%04X\n" % (n, a - shift))
    with open(os.path.join(d, "prog.data.s"), "w") as f:
        f.write("\n".join(data_rows) + "\n")
    seg1 = fgx_libso.run_merlin(d, fgx_libso.write_link(
        d, "seg1", 0, fgx_libso.DATA_EQUS,
        [fgx_libso.MACROS, "dataptr_mac.s", "imports_layout.s",
         os.path.join(LIB, "fcc_runtime_data.s"), "prog.data.s", "dyn.data.s"],
        pad=256))
    subprocess.run([sys.executable, os.path.join(TC, "tools", "gen_seg1_layout.py"),
                    os.path.join(d, "seg1_Output.txt"),
                    os.path.join(d, "seg1_layout.s")], check=True,
                   stdout=subprocess.DEVNULL)
    seg0 = fgx_libso.run_merlin(d, fgx_libso.write_link(
        d, "seg0", 0, SEG0_EQUS,
        [fgx_libso.MACROS, "seg1_layout.s", "imports_layout.s",
         fgx_static.CRT0] + code + ["rt.s", "inits.s"]))
    if seg0 is None:
        die("segment 0 is over 64 KB; a program whose code needs several "
            "banks links dynamically through the tool build (sub-project 5)")
    # ... the manifest (item 7) and fgx_ld, into d/<name>.
```

  `OUTPUT` (for `clear_outputs`) matches every file `link_once` and
  Merlin32 write: `seg[01]`, `rt`, `inits`, `dyn.data`, `prog.data`,
  `imports_layout`, `dataptr_mac`, `seg1_layout`, `<lib>_reach` (`.s`,
  `.link.s`, `_Output.txt`), `dyn.json`, `shift`, the output, and Merlin's
  `error_output.txt`/`_FileInformation.txt`.

```
```

  The rest of `build`, in order:
  1. `libs = Libs(lib_names)`; read the program's code and data rows;
     `code_exports, _, refs = program_names(...)`; `split_data(data_rows,
     libs, code_exports)` -> rows, dropped, shadowed; warn once per
     shadowed name:
     `fgx_dyn: warning: <prog> defines <name>, which <lib> exports; its
     own references bind to its own, <lib>'s internal ones to <lib>'s`.
  2. `roots = (refs | crt0_lib's and inits' names) & (set(libs.data) |
     libs.code)` -- shadowed names stay roots (the stated
     over-approximation); `bits, need, live = bitmaps(libs, roots)`; write
     each library's live code to `d/<lib>_reach.s` (MODE stamp and each
     section's rows) for stack sizing.
  3. `gen` = `rt.s` (`thunked_runtime(far_helpers(), text of the program's
     code + crt0_lib.s + inits.s)`), `inits.s`
     (`fgx_static.inits(["_%s_blktab" % n for n in names],
     ["_dyn_bits_%s" % n for n in names])`), `dyn.data.s`
     (`_dyn_bits_<lib>  HEX <bytes>` per library).
  4. `link_once(..., shift=0, gen)` into `d`, then again with `shift=
     fgx_sites.DELTA` into `d/shift` (its manifest has no
     `stack_frames`); the two must have equal segment sizes.
  5. The fit rule: `lim = libs.lowest - sum(need.values())`; `end =
     len(seg1)`; die `"<prog>'s data ends at $%04X, above LIM $%04X
     (cores from $%04X, %d bytes of blocks)"` when `end > lim`.
  6. Diff each segment (`fgx_sites.diff_sites`), `attribute` against
     `[(n, a, sz) for n, (a, sz) in libs.data.items()]`; rebuild the IMPS
     table from fgx_ld's (replay its call/ptr sites into a fresh
     `Resolver`, add each data site with `use(1, name, "data", seg,
     off)`), set each library's `bitmap` in the table, and rewrite the
     trailer with `fgx_ld.dyn_trailer(fgx_ld.block(b"IMPS", pack(table)))`
     -- written to `out + ".tmp"` and renamed, as fgx_libso does.
  7. The manifest for fgx_ld: two segments (CODE, DATA), `n_data_segment`
     1, entry from the `_crt0_lib` export, `"dynamic": true`,
     `"imports": [[so, listing] ...]`, `stack_frames` = the program's
     `.s` plus each `d/<lib>_reach.s`.
  8. Print `dyn <name>: seg0 %d bytes, data %d bytes, %d imports (%d
     call, %d pointer, %d data sites), LIM $%04X`.

Run: `cd toolchain && python3 tests/dyn/test_dyn.py`
Expected: every check `ok`.

- [ ] **Step 4: Commit** (`feat(ld): fgx_dyn links a program against the shared libraries`,
  body: the two segments, commons and shadows, the bitmap, the fit rule,
  thunks, stack frames and their cost; trailers).

---

### Task 5: the link-time checks, each with a case that goes red

**Files:**
- Modify: `toolchain/tests/dyn/test_dyn.py`; create
  `toolchain/tests/dyn/fit.c`
- Modify: `toolchain/Makefile` (`test-archives` runs `fgx_dyn.py
  --self-test` and `tests/dyn/test_dyn.py`)

- [ ] **Step 1: The cases.**
  - **Shadowing** (`src/userland/ul/ul.c`, `--lib libc,libtermlib`): the
    link warns for `fflush` and `puts` naming libc; neither is an IMPS
    import; ul's `FGX2_FARCALL fflush` rows are not call sites.
  - **Commons** (`src/userland/tctest/tctest.c`, `--lib libc,libtermlib`):
    no warning for `UP` or `BC`; both are dropped; `UP` is a data import
    from libtermlib with data sites (the review measured 10); `BC`, which
    tctest never names again, is not an import; segment 1's listing has
    no `UP` or `BC` label.
  - **Fit** (`tests/dyn/fit.c`: `static char big[64000]; int main() {
    return big[0]; }`): the data ends at about `$FB81`, below fgx_ld's
    `$FFF8` gate and above libc's `LIM` (about `$F69D`), so the link fails
    with "above LIM"; the same source with `big[1000]` links.
  - **Bitmap**: for hello, a member the program does not reach
    (`ctime`) has its bit clear, and the bitmap equals `bitmaps()` over
    the imports the trailer lists.

Run: `cd toolchain && python3 tests/dyn/test_dyn.py`
Expected: all `ok`.

- [ ] **Step 2: Controls.**  Temporarily make `split_data` keep every row
  (commons off): tctest's link must fail (duplicate label `UP`, or a
  shadow warning) -- watch it, restore.  Temporarily drop the fit check:
  the fit case must go red -- watch it, restore.

- [ ] **Step 3: test-archives.**  Add `python3 src/ld/fgx_dyn.py
  --self-test` and `python3 tests/dyn/test_dyn.py` after the libso
  checks.

Run: `make -C toolchain test-archives 2>&1 | tail -3`
Expected: green.

- [ ] **Step 4: Commit** (`test(ld): the dynamic link's checks, each with a case that fails`).

---

### Task 6: record the step, run the gate

- [ ] **Step 1: The spec.**  Section 3: the driver (`fgx_dyn.py`), the
  `FGXD` layout as built, one code segment until sub-project 5, the
  thunk's rows.  Section 8: "Step 3 landed <date>" with hello's, ul's and
  tctest's numbers (imports, sites, LIM, segment sizes) and the stack
  sizing cost.

- [ ] **Step 2: The gate** (fgx_ld changed).  Announce it.

Run: `tools/gate.sh 2>&1 | tail -3`
Expected: `GATE GREEN`.

- [ ] **Step 3: Commit and the project notes** (`group_id="fgx"`): step 3 landed;
  the FGXD layout; fgx_dyn's two segments; commons against library
  exports.

```bash
git add docs/history/plans/2026-09-29-shared-libc-sp3-design.md
git commit -F - <<'EOF'
docs(plans): shared libc SP3 step 3 landed

EOF
```
