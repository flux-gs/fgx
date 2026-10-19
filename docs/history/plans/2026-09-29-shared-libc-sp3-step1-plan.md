# Shared libc SP3 step 1: the libraries, generalised -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `libtermlib.so.1.0` and `libcurses.so.1.0` beside
`libc.so.1.0` by SP2's path, generalised by library name, each with an
import table (its calls, pointer cells and data references into the
libraries below it) and the list of its core-relative sites -- and fix
what that needs on the way: the helper census's fall-through units, K&R
common symbols where a library is involved, termlib owning `UP`/`BC`/`PC`/
`ospeed`, and a versioned library trailer with data-export sizes.

**Architecture:** fgx_libso gains a table of libraries (sources, data
files, bank-0 files, exports, core list, the libraries below).  A library
above libc assembles its core at the base it would stack at under the
libraries it was built against, links against their trailers (fgx_ld
resolves a name no segment defines to an export of a lower library and
records the site), and finds its data sites -- its own core's and its data
imports' -- by linking twice with every data address moved down by one
delta and diffing the linked segments (`fgx_sites.py`).  The import table
and core-relative sites ride tagged blocks in the library trailer
(`fgx_imports.py` encodes them; programs reuse the encoding in step 3).

**Tech Stack:** Python 3 (fgx_ld, fgx_libso, fgx_gc, the new
`fgx_imports.py` and `fgx_sites.py`, helper_census, libc_so_check), C (fcc
`--libso-name`; termlib and curses sources), Merlin32, ninja, MAME via
`tools/mame_test/run.py` (vi tests only).

**Spec:** `docs/history/plans/2026-09-29-shared-libc-sp3-design.md`,
sections 2, 2a, 3 ("Library trailer", "Finding data sites", "The fcc
runtime" -- fsub), 5 (host checks), 6 item 1.  Revised the same day for
an adversarial review (Fable), fourteen findings adopted.  Settled here,
from reading the code:

- **fcc's library mode already compiles termlib and curses** (measured
  2026-09-29): termlib has one block (`libtermlib`, 74 bytes); curses fails
  only on `cr_tty.c`'s `sstrs[] = { ..., &_PC, ... }` until `sflags`,
  `sstrs` and `_PC` are in its `core.list`, then has five blocks, 1,657
  bytes.  The block-cell and block-table names are libc's
  (`_libc_blk_<m>`, `_libc_blktab`), so fcc gains `--libso-name NAME`
  (default `libc`, byte-identical) and fgx_libso names the table
  `_<name>_blktab`.
- **A library above libc assembles its core at its stacked base**, not the
  spec's nominal `$8000`: the base it gets under the libraries it was built
  against (libc's core base minus its own size, and so on).  Then a boot
  with those same libraries patches nothing; the sites are there for a
  boot where a lower library's core size differs.  Both keep every
  operand above `$100`.  (Recorded in the spec in Task 10.)
- **Sites are found in the LINKED segments**, not Merlin's output: fgx_ld
  writes the offset of every `FGX2_LONG_PTR` itself (curses's `sflags[]`
  holds `&AM`...), so only a diff after fgx_ld sees it.  The delta is
  `$1010`, so both bytes of every site change and the first differing byte
  is the site's low byte.
- **Commons, static side, needs one rule in fgx_gc and one pass in elvis.**
  The ninja tool path prunes every library's data through fgx_gc
  (`<lib>.sel.data.s`), and the program's `.data.s` is a root; elvis and
  tcsh PUT `libtermlib_data.s` whole, and tcsh already runs gen_commons
  with it as `--extern-defs`.  fcc emits a tentative definition as a lone
  `<name> DS <n>` (measured: `char *UP;` -> `UP DS 4`; `char *BC = 0;` ->
  two `DA` rows; a `static` gets the TU prefix, so it never collides).
- **Library code reaches its data bank from `&UP`**: fcc builds the address
  of a data object with `PHB` (measured), so `(unsigned long)&UP & 0xFF0000`
  is the process's bank -- the same idiom as the libcso probe's `bankof()`.
- **The fsub unit.**  `fgx_libso.runtime_units` makes `_fcc_fsub` one unit
  with `_fcc_fadd` (the self-test asserts it), fcc JSRs `_fcc_fadd`
  directly (`emit.c:2375, 4566`), so a far fsub would leave fadd with no
  near body.  The census refuses a unit any of whose inner labels
  (every label but the first) fcc or compiled code names.  The spec's
  other clause -- size such a unit by its first label -- is then moot: a
  unit it would apply to is never chosen.
- **What each library's core carries**: libc's as today; termlib's and
  curses's: `fcc_runtime_data.s` (their near helpers and inline `__asm`
  name `_fcc_*` and `__asm_*` cells, which may not be libc's private
  ones), their compiled data (exports, core-list statics, the block cells
  and `_<name>_blktab`), and termlib's `libtermlib_helpers_data.s`.
- **Out of this step**: startup (`_libc_start`, library init with a
  bitmap) is step 2; the program link is step 3; nothing here runs a
  library on the machine.  The shipped change is Task 3's (termlib owning
  its four names, commons), proven by the gate and the vi tests.

## Global Constraints

- ASCII only; comments describe the current state; K&R and BSD quoted from
  the page and named in commits; commit bodies informational, ending with
- Toolchain-first: a construct fcc or the linkers cannot handle is fixed
  there, never worked around in a source.
- `libc.so.1.0` stays byte-identical except for Task 1 (nine far helpers)
  and Task 4 (trailer v2); `fcc --libso` without `--libso-name` is
  byte-identical (Task 5 checks it).
- Every shipped binary is unchanged except by Task 3; the gate proves it.
- Never `git checkout` a generated file; announce every rebuild and MAME
  run; MAME headless (`run.py`).
- Branch `feat/shared-libc`, not pushed.

## Review Focus

1. A program that defines `UP` AND has it initialised (`char *UP = 0;`) --
   under K&R A.10.2 the program's initialised definition IS the definition
   and termlib's tentative `UP DS 4` becomes a declaration, so fgx_gc keeps
   the program's; only two initialised definitions are refused (Task 2: the
   root-wins and "two initialised" cases).  A whole-pile link (elvis, tcsh)
   PUTs termlib's data, which cannot yield, so there an initialised `UP` is
   a loud Merlin duplicate label.  (Corrected after the final review: this
   line first named the refusal as the outcome.)
2. Two libraries that both carry a tentative `PC` (curses and termlib, in
   robots and worm) -- exactly one survives, and it is the larger if the
   sizes differ (Task 2: "two commons" case; Task 3 builds robots and worm).
3. A site whose value is one past its object (`&x + sizeof x`) -- attributed
   to x, not refused; and one that is the NEXT object's start goes to that
   object (Task 7: both cases).
4. A curses data reference to termlib's `UP` -- a data import whose prebound
   address depends on libc's core size; the mismatched boot's patch must
   land (Task 8: the curses build shows a data site for `UP` attributed to
   termlib; step 4 runs it).
5. A library naming libc's private cell (termlib's old `args_env`) -- refused
   by name, not by an assembler "undefined label" alone (Task 6: the
   private-name case).

---

### Task 1: the census refuses a fall-through unit fcc calls inside

**Files:**
- Modify: `tools/helper_census.py` (`choose`, `census`, `self_test`, `main`)
- Regenerate: `toolchain/lib/libc_so_helpers.s` (via `--write`)
- Rebuild: `toolchain/lib/libc.so.1.0` (`make -C toolchain libc_so`)

**Interfaces:**
- Produces: `inner_called(units, order, text) -> set[str]` -- the units
  some of whose non-first labels appear in `text`; `choose(sizes, shares,
  excluded, deps)` unchanged in signature (callers pass the inner-called
  set inside `excluded`).

- [ ] **Step 1: The failing self-test.**  Add to `self_test()`:

```python
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
```

- [ ] **Step 2: Run it.**

Run: `python3 tools/helper_census.py --self-test`
Expected: FAIL, `NameError: name 'inner_called' is not defined`.

- [ ] **Step 3: Implement.**  Beside `shared_cell_callees`:

```python
def inner_called(units, order, text):
    """Units that fall through into a label named outside them: fsub runs
    into fadd, and fcc JSRs _fcc_fadd itself.  A far entry replaces the
    unit's near body in a program's segment, so every label in it but the
    first would be left with none."""
    named = set(fgx_gc.IDENT.findall(text))
    return {u for u in order
            if (fgx_gc.defined_labels(units[u]) - {u}) & named}
```

In `census()`, after `compiled` is built, read fcc's emitter too (it names
helpers as strings) and return the set as a ninth value:

```python
    fcc_src = "\n".join(open(p).read() for p in
                        glob.glob(os.path.join(TC, "src", "cc", "*.c")))
    inner = inner_called(units, order, compiled + fcc_src)
```

and `return order, sizes, stackargs, users, banks, deps, dataargs, cells, inner`.
In `main()`: unpack `inner`, pass `stackargs | dataargs | inner` to
`settle`, and in the table print `"inner"` for a unit in `inner` (before
the `data`/`stack` labels).  Extend the module docstring's rule sentence
with ", and has no inner label fcc or compiled code names (a unit that
falls through into one: fsub runs into fadd)".

- [ ] **Step 4: Run the self-test and the census.**

Run: `python3 tools/helper_census.py --self-test && python3 tools/helper_census.py | tail -12`
Expected: `self-test OK`; `_fcc_fsub` and `_fcc_utof` marked `inner`
(utof falls into `_fcc_ultof`, which `emit.c:4217` names; utof never
qualified, so the list still loses only fsub); last line
`far: 9 helpers, 1591 bytes` (2,074 less fsub's unit, 483).

- [ ] **Step 5: Regenerate, rebuild, check.**  Announce the libc.so rebuild.

Run: `python3 tools/helper_census.py --write && make -C toolchain libc_so 2>&1 | tail -2 && python3 tools/libc_so_check.py --self-test && python3 tools/helper_census.py --check`
Expected: `libc_so_helpers.s` loses the `_fcc_fsub_far` rows; `libc.so: 3
code banks`; `self-test OK (clean file passes, five broken copies fail)`;
`--check` silent, exit 0.

- [ ] **Step 6: Commit.**

```bash
git add tools/helper_census.py toolchain/lib/libc_so_helpers.s
git commit -F - <<'EOF'
fix(libc): the census keeps near a unit fcc calls inside

_fcc_fsub falls through into _fcc_fadd, which fcc calls by name
(emit.c:2375, 4566), so a far fsub would leave fadd with no near body in
a program's segment; fsub qualified only because the census sized the
whole unit.  helper_census refuses a unit any of whose inner labels fcc
or compiled code names.  libc.so's far entries: nine, 1,591 bytes.

EOF
```

---

### Task 2: common symbols in fgx_gc

**Files:**
- Modify: `toolchain/src/ld/fgx_gc.py` (`graph`, new `is_common`, `self_test`)

**Interfaces:**
- Produces: `is_common(rows) -> (name, size) | None` -- a section's rows
  are a tentative definition: exactly one label row `<name> DS <n>` and
  otherwise only `FGX_SECT`/`FGX_ENDS`/`FGX2_EXPORT`/comment/blank rows.
  Used again by fgx_libso (Task 8).
- `graph(files, order, prune)`: the rule is for DATA only (sections of a
  file `is_data_path` accepts, against labels of root DATA files).  A
  pruned data section that `is_common` defines as `name` is skipped
  (registered nowhere, so never live, never written) when a root data file
  defines `name` or another data section defines it non-commonly; of
  several common sections for one name the largest is kept (the first in
  file order on a tie).  Code is untouched: a root code file may define a
  name a pruned code section also defines, as today (the overlay tools'
  `libcovl_thunks.s` defines `strlen`, `open`...; chmod's own `abs`
  shadows libc's).  Root labels are column-1 labels only -- never a
  Merlin variable (`]__lc_fltused = 1`, which fcc emits into every float
  TU, `main.c:868`) or a local (`:x`), so libc's live common
  `__lc_fltused DS 2` keeps its owner.

- [ ] **Step 1: Failing self-test cases.**  Add to `self_test()`:

```python
    # K&R A.10.2 common extension: a pruned tentative definition yields.
    common = ["                FGX_SECT UP", "UP              DS      4",
              "                FGX_ENDS"]
    init = ["                FGX_SECT UP", "                FGX2_EXPORT UP",
            "UP              DA      0", "                DA      0",
            "                FGX_ENDS"]
    assert is_common(common) == ("UP", 4)
    assert is_common(init) is None
    assert is_common(["                FGX_SECT _t_priv",
                      "_t_priv         DS      2", "x DS 2",
                      "                FGX_ENDS"]) is None
    user = ["main    JSR tgoto", "UP              DS      4"]    # a root
    lib_code = ["                FGX_SECT tgoto", "tgoto   LDA UP",
                "                RTL", "                FGX_ENDS"]
    files = {"p.s": user, "l.s": lib_code, "l.data.s": common}
    units, owner, body, is_data, roots = graph(
        files, ["p.s", "l.s", "l.data.s"], {"l.s", "l.data.s"})
    assert "UP" not in owner                      # the root's definition wins
    # Two libraries' commons: the larger survives.
    big = ["                FGX_SECT PC", "PC              DS      2",
           "                FGX_ENDS"]
    small = ["                FGX_SECT PC", "PC              DS      1",
             "                FGX_ENDS"]
    units, owner, *_ = graph({"a.data.s": small, "b.data.s": big, "r.s": ["x LDA PC"]},
                             ["r.s", "a.data.s", "b.data.s"],
                             {"a.data.s", "b.data.s"})
    assert owner["PC"][0] == "b.data.s", owner["PC"]
    # A common yields to an initialised pruned definition.
    units, owner, *_ = graph({"a.data.s": init, "b.data.s": common, "r.s": ["x LDA UP"]},
                             ["r.s", "b.data.s", "a.data.s"],
                             {"a.data.s", "b.data.s"})
    assert owner["UP"][0] == "a.data.s", owner["UP"]
    # Code is out of the rule: a root code label beside a pruned code
    # section of the same name (the overlay thunks) is not an error.
    units, owner, *_ = graph({"t.s": ["strlen  JML strlen_far"],
                              "l.s": ["                FGX_SECT strlen",
                                      "strlen  RTL", "                FGX_ENDS"]},
                             ["t.s", "l.s"], {"l.s"})
    assert owner["strlen"][0] == "l.s"
    # A Merlin variable in a root is not a definition.
    units, owner, *_ = graph({"r.s": ["]__lc_fltused   =       1", "x LDA __lc_fltused"],
                              "l.data.s": ["                FGX_SECT __lc_fltused",
                                           "__lc_fltused    DS      2",
                                           "                FGX_ENDS"]},
                             ["r.s", "l.data.s"], {"l.data.s"})
    assert owner["__lc_fltused"][0] == "l.data.s"
    # Two initialised definitions, one in a root: still an error.
    expect_die(lambda: graph({"r.data.s": ["UP  DA 0", "  DA 0"],
                              "a.data.s": init},
                             ["r.data.s", "a.data.s"], {"a.data.s"}),
               ["UP", "defined"])
```

- [ ] **Step 2: Run it.**

Run: `python3 toolchain/src/ld/fgx_gc.py --self-test`
Expected: FAIL, `NameError: name 'is_common' is not defined`.

- [ ] **Step 3: Implement.**  Beside `defined_labels`:

```python
DS_ROW = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+DS\s+(\d+)\s*$")
SECT_ROWS = ("FGX_SECT", "FGX_ENDS", "FGX2_EXPORT")


def is_common(rows):
    """(name, size) when a section is a K&R tentative definition -- fcc emits
    `char *UP;' as the one row `UP DS 4' -- else None.  K&R A.10.2 (p. 187):
    in the common extension "if a definition occurs somewhere in the
    program, then the tentative definitions become merely declarations"."""
    found = None
    for r in rows:
        s = COMMENT.sub("", r).rstrip()
        if not s.strip() or s.lstrip()[0] in ";*":
            continue
        if s[0] in " \t":
            if s.split()[0] in SECT_ROWS:
                continue
            return None
        m = DS_ROW.match(s)
        if not m or found:
            return None
        found = (m.group(1), int(m.group(2)))
    return found
```

In `graph()`: first collect the root data labels with
`ROOT_LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\b")` over every row of
each root file `is_data_path` accepts (column 1 only; `]` and `:` rows
never match) -- not `defined_labels`, which strips `]` and `:`.
Then build the pruned units in two passes: pass 1 records, per label, each
section key with its `is_common` result; pass 2 picks the owner per label
(for code sections, and data labels no other data defines, exactly as
today):
a non-common section if there is exactly one (die if two, or if the label
is in `root_labels`: `"%s defined in two places (%s, %s)"`); else, if the
label is in `root_labels`, no owner; else the largest common (first on a
tie).  A skipped common section is left out of `owner` and `body`; its
key stays in `units` (so indices do not shift) but is never live.  Keep
the existing loose-row and `body`/`is_data` handling for every kept key.

- [ ] **Step 4: Run the self-test.**

Run: `python3 toolchain/src/ld/fgx_gc.py --self-test`
Expected: `fgx_gc: self-test OK`.

- [ ] **Step 5: Nothing shipped moves.**  No data definition is
  duplicated today except the tentatives this rule leaves alone, so every
  pruned output and binary is the same.  Tool outputs are untracked, so
  `git status` cannot show a change; checksum them.  Announce the rebuild.

Run: `S=<scratch> git stash -q -- toolchain/src/ld/fgx_gc.py && ninja >/dev/null && shasum tools/*-fgx2/*.bin tools/*-fgx2/*.gc.s disk_src/lib/libc.so.* 2>/dev/null | sort -k2 > $S/gc.before; git stash pop -q && ninja >/dev/null && shasum tools/*-fgx2/*.bin tools/*-fgx2/*.gc.s disk_src/lib/libc.so.* 2>/dev/null | sort -k2 > $S/gc.after; diff $S/gc.before $S/gc.after && echo SAME`
Expected: `SAME` (every binary, pruned output and pile unchanged).  A
control: the "before" build is the old rule, so if the new rule dropped a
live section (the `__lc_fltused` case) some `.gc.s` differs here.

- [ ] **Step 6: Commit.**

```bash
git add toolchain/src/ld/fgx_gc.py
git commit -F - <<'EOF'
feat(ld): fgx_gc merges common symbols

K&R A.10.2 (p. 187): "In the alternate formulation, which is usual in
UNIX systems and recognized as a common extension by the Standard, all
the tentative definitions for an externally linked object ... are
considered together ... If a definition occurs somewhere in the program,
then the tentative definitions become merely declarations."  A pruned
section holding only `<name> DS <n>', fcc's emission of a tentative
definition, yields to a definition in a root file or an initialised
section; of several, the largest survives.  Two initialised definitions
are still refused.

EOF
```

---

### Task 3: termlib owns UP, BC, PC and ospeed (shipped)

**Files:**
- Modify: `toolchain/lib/libtermlib_c/libtermlib.c` (definitions, header
  comment, `args_env` -> `&UP`)
- Modify: `toolchain/lib/libcurses_c/cr_tty.c:60` (`short ospeed;`)
- Modify: `tools/elvis-fgx2/build_elvis.sh` (compile with `--commons`, run
  gen_commons, PUT `commons.data.s` in the data segment)
- Modify: `tools/elvis-fgx2/dataseg.link.s` (tracked; PUT `commons.data.s`)
- Modify: `tools/ninja/gen.py` elvis entry `extra=` (add
  `toolchain/tools/gen_commons.py`, as bsh and tcsh have)

**Interfaces:**
- Consumes: Task 2's common rule (ninja tools: clear, more, tctest, tput,
  ul, robots, worm).
- Produces: termlib's archive, pile and (Task 8) library define `char *UP;
  char *BC; char PC; short ospeed;`.

- [ ] **Step 1: Read upstream.**  `examples/2.11BSD/usr/usr.lib/libtermlib/tgoto.c:14-15`
  (`char *UP; char *BC;`), `tputs.c:24-25` (`short ospeed; char PC;`),
  `examples/2.11BSD/usr/usr.lib/libcurses/cr_tty.c:48` (`short ospeed = -1;`)
  and `:57` (gettmode assigns it).  Quote them in the commit.

- [ ] **Step 2: The failing link.**  In `libtermlib.c`, replace the two
  `extern char *UP; extern char *BC;` lines and their comment with

```c
/* tgoto's cursor-up and backspace strings and tputs's pad character and
 * speed, defined here as 2.11BSD's libtermlib defines them (tgoto.c,
 * tputs.c).  A program or curses that also defines them tentatively
 * shares these cells (K&R A.10.2's common extension). */
char *UP;
char *BC;
char  PC;
short ospeed;
```

and rewrite the header comment's "UP/BC are EXTERN here" paragraph to say
the same in the present tense.  Announce the rebuild, then:

Run: `make -C toolchain archives 2>&1 | tail -2 && ninja 2>&1 | grep -iE 'elvis|FAILED|error' | head`
Expected: the ninja tools link (Task 2 lets their `char *UP;` yield);
elvis FAILS in its data segment with Merlin's duplicate-label error for
`UP` (its vendored `curses.c` and termlib's data both define it).

- [ ] **Step 3: elvis gets the commons pass.**  In `build_elvis.sh`, as
  `build_tcsh_link.sh` does: add `--commons "$t.comm"` to both fcc loops
  (PRISTINE and TRACKED); after the fgx_gc step run

```bash
echo "== 1d. coalesce K&R tentative definitions =="
python3 "$REPO/toolchain/tools/gen_commons.py" \
    --extern-defs "$REPO/toolchain/lib/libc_data.s" \
    --extern-defs libc.sel.data.gc.s \
    --extern-defs libfgx_data.gc.s \
    --extern-defs "$REPO/toolchain/lib/libtermlib_data.s" \
    --extern-defs "$REPO/toolchain/lib/args_data.s" \
    --extern-defs "$REPO/toolchain/lib/fcc_runtime_data.s" \
    commons.data.s *.comm || { echo "gen_commons FAIL"; exit 1; }
```

  (use the file names elvis's fgx_gc step actually writes -- check with
  `ls tools/elvis-fgx2/*.gc.s`), PUT `commons.data.s` in elvis's data
  segment link (`tools/elvis-fgx2/dataseg.link.s`) after the TU data files, and add `*.comm commons.data.s`
  to the script's clean list.  Add `toolchain/tools/gen_commons.py` to the
  elvis entry's `extra` in `tools/ninja/gen.py`, as bsh and tcsh have it
  (`gen.py:1420-1421, 1453`; `links` are PUT link files).

- [ ] **Step 4: termlib's data bank from `&UP`; curses's `ospeed`.**  In
  `libtermlib.c`, delete `extern char args_env[];` and its comment, and in
  tgetstr return

```c
    /* Cap strings (tc_*) live in the DATA bank; &UP is built with PHB, so
     * its bank is the process's data bank. */
    return (char *)(((unsigned long)(char *)&UP >> 16 << 16)
                    | (unsigned)__asm_w0);
```

  In `cr_tty.c:60` change `short	ospeed = -1;` to `short	ospeed;` with the
  comment `/* FGX: termlib owns ospeed; gettmode assigns it before any
  read (2.11BSD initialises it to -1 here). */`.

- [ ] **Step 5: Build everything.**  Announce the rebuild.

Run: `make -C toolchain archives piles 2>&1 | tail -2 && ninja 2>&1 | tail -1`
Expected: success; `grep -c 'UP ' tools/elvis-fgx2/commons.data.s` is 0
(elvis's `UP` yielded to termlib's) and the gen_commons line lists `UP`,
`BC`, `PC` and `ospeed` among "dropped" (elvis's vendored `curses.c:57, 62`
defines `ospeed` and `PC` tentatively, `system.c:119` `BC`).

- [ ] **Step 6: The vi tests.**  Announce the MAME runs.

Run: `python3 tools/mame_test/run.py --fresh ufsvi && python3 tools/mame_test/run.py --fresh vivc`
Expected: both PASS (elvis's cursor motion goes through tgoto's `UP`).

- [ ] **Step 7: The gate.**  Announce it.

Run: `tools/gate.sh 2>&1 | tail -3`
Expected: `GATE GREEN`.

- [ ] **Step 8: Commit** (quote the three upstream lines from Step 1).

```bash
git add toolchain/lib/libtermlib_c/libtermlib.c toolchain/lib/libcurses_c/cr_tty.c \
        tools/elvis-fgx2/build_elvis.sh tools/ninja/gen.py tools/elvis-fgx2/dataseg.link.s
git commit -F - <<'EOF'
fix(termlib): termlib defines UP, BC, PC and ospeed, as 2.11BSD's does

2.11BSD usr.lib/libtermlib/tgoto.c:14-15 `char *UP; char *BC;' and
tputs.c:24-25 `short ospeed; char PC;'.  Programs and curses that also
define them tentatively share the cells under K&R A.10.2's common
extension: fgx_gc merges the ninja tools' links, and elvis now runs the
gen_commons pass tcsh and sh run, so its vendored curses.c stays as it
is.  curses's `short ospeed = -1;' (libcurses/cr_tty.c:48) loses its
initialiser: gettmode assigns it before any read.  tgetstr takes the
data bank from &UP instead of libc's private args_env.

EOF
```

---

### Task 4: the library trailer, version 2

**Files:**
- Modify: `toolchain/src/ld/fgx_ld.py` (`library_exports`,
  `library_trailer`, `read_trailer`, the library block of `main`)
- Modify: `toolchain/src/ld/test_fgx_ld_library.py`
- Modify: `tools/libc_so_check.py` (`check`, `self_test` controls 2, 3, 5)

**Interfaces:**
- Produces, `library_exports(...) -> [(name, kind, seg, val, size)]`
  (size: 0 for code; for data, the bytes to the next core label, from the
  core listing);
  `library_trailer(version, core, tmpl, core_base, core_size, exports,
  blocks, fixups, extra=b"") -> bytes` and `read_trailer(data) -> dict`
  with the old keys (exports now 5-tuples) plus `"version": 2`,
  `"blocks_raw": {tag: payload}`.
- Layout (all little-endian):

```
"FGXL"  version=2 (B)  major (B)  minor (B)  core (B)  tmpl (B)
        core_base (H)  core_size (H)  crc (I)
then tagged blocks until the end: tag (4 ASCII)  length (I)  payload
  "EXPT"  per export: namelen (B) name kind (B) seg (B) val (H) size (H)
  "BLKS"  per member: cell (H) template offset (H) size (H)
  "FIXS"  per fixup: core offset (H)
  "IMPS"  a library's own imports (Task 6's encoding)
  "CSIT"  core-relative sites: per site seg (B) off (H)
crc = CRC-32 of the EXPT payload; a reader skips a tag it does not know.
```

- [ ] **Step 1: Failing round-trip test.**  In `test_fgx_ld_library.py` add:

```python
def test_trailer_v2():
    ex = [("errno", 1, 3, 0xF800, 2), ("puts", 0, 0, 0x0123, 0)]
    t = fgx_ld.library_trailer((1, 0), 3, 4, 0xF700, 0x0900, ex,
                               [(0xF810, 0, 6)], [0x10], extra=b"CSIT" +
                               struct.pack("<I", 3) + bytes([1, 0x34, 0x12]))
    r = fgx_ld.read_trailer(t)
    check(r["version"] == 2, "trailer version 2")
    check(r["exports"] == ex, "exports round-trip with sizes", str(r["exports"]))
    check(r["blocks"] == [(0xF810, 0, 6)] and r["fixups"] == [0x10],
          "blocks and fixups round-trip")
    check(r["crc"] == r["checksum"], "crc over the export records")
    check(r["blocks_raw"]["CSIT"] == bytes([1, 0x34, 0x12]), "unknown-to-core block kept")
    bad = bytearray(t)
    bad[4] = 1
    check(_raises(lambda: fgx_ld.read_trailer(bytes(bad))), "version 1 refused")
```

  with `_raises(fn)` returning True when `fn()` raises `ValueError`
  (`dies` catches only `SystemExit`, and read_trailer raises); call
  `test_trailer_v2()` from the file's main sequence.

- [ ] **Step 2: Run it.**

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py`
Expected: FAIL (TypeError on the 5-tuple exports / missing `extra`).

- [ ] **Step 3: Implement.**  `library_exports`: kind-1 rows get
  `size = next core label's address - this one's` (the core listing's
  labels sorted by address; the last runs to `core_base + core_size`);
  kind-0 rows size 0.  `library_trailer` writes the layout above
  (`struct.pack("<4sBBBBBHHI", b"FGXL", 2, major, minor, core, tmpl,
  core_base, core_size, crc)` then the blocks, `extra` appended verbatim
  as already-tagged blocks).  `read_trailer` raises `ValueError` for a
  magic or version it does not know, walks the tags, decodes EXPT/BLKS/
  FIXS into the old keys and keeps every payload in `blocks_raw`.  In
  `main`'s library block, pass the new tuples through; `extra` stays empty
  until Task 8.

- [ ] **Step 4: libc_so_check follows.**  Unpack 5-tuples everywhere
  (`for name, kind, seg, val, _size in tr["exports"]`); add the check
  "a data export's size is non-zero and `val + size <= core_base +
  core_size`"; control 3 flips a byte inside the EXPT payload (its offset
  is `trailer_pos + 4 + struct.calcsize("<BBBBBHHI") + 8 + 1`); controls
  2 and 5 rebuild the trailer with 5-tuples.

- [ ] **Step 5: Rebuild and run everything that reads the trailer.**
  Announce the libc.so rebuild.

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py && make libc_so 2>&1 | tail -1 && python3 ../tools/libc_so_check.py --self-test && python3 ../tools/libc_so_check.py`
Expected: all `ok`; `self-test OK`; the clean report (`14 data` exports).
Then: `grep -rn 'read_trailer\|library_trailer' --include=*.py . | grep -v '^./toolchain/src/ld/fgx_ld.py'`
Expected: only `libc_so_check.py` and the test (fix any other reader the
same way).

- [ ] **Step 6: Commit.**

```bash
git add toolchain/src/ld/fgx_ld.py toolchain/src/ld/test_fgx_ld_library.py tools/libc_so_check.py
git commit -F - <<'EOF'
feat(ld): library trailer version 2, with data-export sizes

The FGXL trailer gains a version byte and tagged, length-prefixed blocks
(EXPT, BLKS, FIXS; IMPS and CSIT for a library that imports), so a reader
skips what it does not know.  Each data export carries its size, the
bytes to the next core label, which attributes an addend such as
stdout+2 to its object.  The CRC still covers the export records only.

EOF
```

---

### Task 5: fcc `--libso-name`

**Files:**
- Modify: `toolchain/src/cc/main.c` (option, usage), `globals.c`/`fcc.h`
  (`const char *g_libso_name = "libc";`), `emit.c:5702, 5707, 5709, 6309`
  and every other `_libc_blk_` emission (`grep -n '_libc_blk_' toolchain/src/cc/*.c`)
- Test: `toolchain/tests/libso/test_libso.py` (the existing library-mode
  fixture runner; add one case)

**Interfaces:**
- Produces: `fcc --libso --libso-name NAME` names block cells
  `_NAME_blk_<member>`; without it, `_libc_blk_<member>` as today.

- [ ] **Step 1: Failing fixture.**  In `test_libso.py`, compile a
  two-line source with one file-scope static
  (`static int n; int f() { return n++; }`) with
  `--libso --libso-name libtermlib --sections` and assert the code names
  `_libtermlib_blk_` and not `_libc_blk_`; and compile it again without
  the option and assert the reverse.

Run: `cd toolchain && python3 tests/libso/test_libso.py`
Expected: FAIL (`--libso-name` is an unknown option).

- [ ] **Step 2: Implement.**  `main.c`: `--libso-name NAME` sets
  `g_libso_name` and implies `g_libso`; add it to the usage text beside
  `--libso`.  Every
  `"_libc_blk_%s"` / `"_libc_blk_%-5s"` format becomes
  `"_%s_blk_%s"` / `"_%s_blk_%-5s"` with `g_libso_name` first.  The
  comments name the cell `_<lib>_blk_<member>`.

- [ ] **Step 3: Byte-identical without it.**

Run: `cd toolchain && make fcc && python3 tests/libso/test_libso.py && make libc_so 2>&1 | tail -1 && git status --short lib/`
Expected: tests pass; `libc_so.s`, `libc_so_data.s`, `libc.so.1.0` not
listed as modified (libc's compile is unchanged).

- [ ] **Step 4: Commit.**

```bash
git add toolchain/src/cc/*.c toolchain/src/cc/fcc.h toolchain/tests/libso/test_libso.py
git commit -F - <<'EOF'
feat(fcc): --libso-name names a library's block cells

A library other than libc names its block cells _<name>_blk_<member>, so
libtermlib.so and libcurses.so carry their own; without the option the
cells are _libc_blk_<member> and libc's compile is byte-identical.

EOF
```

---

### Task 6: imports in a library link

**Files:**
- Create: `toolchain/src/ld/fgx_imports.py` (encode/decode, `Resolver`)
- Modify: `toolchain/src/ld/fgx_ld.py` (manifest `"imports"`; the
  FARCALL/FARJUMP and LONG_PTR loops; the library block writes `IMPS`;
  the library block's `"blk_prefix"` (default `"_libc_blk_"`) replaces the
  hard-coded prefix in `block_table` (`fgx_ld.py:749`) and in
  `library_exports`'s `public()` (`:721`); `"core_list"` becomes optional
  (`:1210`))
- Test: `toolchain/src/ld/test_fgx_ld_library.py`

**Interfaces:**
- `fgx_imports.Resolver(libs)`: `libs` is `[(so_path, core_listing)]`,
  lower libraries in load order (the build directory is the LIBS row's
  `dir`, e.g. `lib/libc_so.d/core_Output.txt`; nothing is inferred from the
  `.so`'s name); loads each trailer (`read_trailer`); `.code(name) -> (lib, ordinal,
  seg, off) | None`, `.data(name) -> (lib, ordinal, addr, size) | None`;
  `.private(name) -> lib name | None` for a name a lower library's CORE
  LISTING defines but does not export, excluding the names in `own` (a
  set the caller passes: labels the importing library's own core defines,
  e.g. its `_fcc_*` and `__asm_*` cells, which libc's core also has);
  `.use(kind, name, site_kind, seg, off)` records a
  site; `.pack() -> bytes` (the IMPS payload).
- IMPS payload:

```
n_libs (B); per lib: namelen (B) name major (B) minor (B) crc (I) core_base (H) bitmap_len (B) bitmap
n_imports (H); per import: lib (B) ordinal (H) namelen (B) name kind (B) seg (B) val (H) size (H)
per import, in the same order: n_call (H) [seg (B) off (H)]*  n_ptr (H) [...]*  n_data (H) [...]*
```

  (a library's bitmap_len is 0; programs fill it in step 3).
  `fgx_imports.unpack(payload) -> dict` is the inverse.
- fgx_ld: when a manifest has `"imports": [[so_path, core_listing], ...]`, a FARCALL/FARJUMP
  or LONG_PTR name no segment exports resolves through `Resolver.code`:
  the operand gets the prebound offset, no reloc is emitted (the bank is
  the binder's), and a `call` (operand address = `addr + 1`) or `ptr`
  (`addr`) site is recorded.  A name that is `.private` dies with
  `"<name> is <lib>'s private cell; a library may import only exports"`;
  a name found nowhere dies as today.

- [ ] **Step 1: Failing tests.**  Round-trip `pack`/`unpack` of a
  two-library, three-import table with every site kind; and a link test:
  build a fake lower library with `library_trailer` exporting `strcpy`
  (code, seg 0, `0x0200`) and `errno` (data, `0xF800`, 2), write it as
  `lower.so` and a core listing in a directory NOT named after it
  (`lowerbuild/core_Output.txt`) that also has `args_env`; link a
  one-segment library whose code is `FGX2_FARCALL strcpy` then `RTL` with
  `"imports": [["lower.so", "lowerbuild/core_Output.txt"]]`; assert
  the JSL operand bytes are `00 02` + bank `00`, no reloc at `addr + 3`,
  and IMPS lists one `call` site at `(0, addr + 1)`.  A second link with
  `FGX2_FARCALL args_env` must die with "private cell".  A third library
  link with `"blk_prefix": "_libtermlib_blk_"`, a cell
  `_libtermlib_blk_m` and no `"core_list"` must link and list member `m`'s
  block (today it dies "has no block cell", then KeyError).

Run: `cd toolchain && python3 src/ld/test_fgx_ld_library.py`
Expected: FAIL (`No module named fgx_imports`).

- [ ] **Step 2: Implement** `fgx_imports.py` (struct packing as above,
  self-test for the round trip) and the fgx_ld hooks: build the Resolver
  once after pass 1 when `m.get("imports")`; in the two loops, before
  `die(... unresolved ...)`, try the resolver; after the loops, if the
  resolver recorded anything, append `b"IMPS" + struct.pack("<I", len(p))
  + p` to the library trailer's `extra`.

- [ ] **Step 3: Run.**

Run: `cd toolchain && python3 src/ld/fgx_imports.py --self-test && python3 src/ld/test_fgx_ld_library.py`
Expected: both OK.

- [ ] **Step 4: Commit.**

```bash
git add toolchain/src/ld/fgx_imports.py toolchain/src/ld/fgx_ld.py toolchain/src/ld/test_fgx_ld_library.py
git commit -F - <<'EOF'
feat(ld): a library link imports from the libraries below it

A call, jump or pointer cell naming a function no segment defines binds
to a lower library's export: fgx_ld writes the prebound offset, leaves
the bank to the binder and records the site in the trailer's IMPS block
(fgx_imports.py).  A name that is a lower library's private core cell is
refused: a library is patched once for every process, so it may import
only exports.

EOF
```

---

### Task 7: the site finder

**Files:**
- Create: `toolchain/src/ld/fgx_sites.py`

**Interfaces:**
- `DELTA = 0x1010`
- `diff_sites(a: bytes, b: bytes, delta=DELTA) -> [(off, value)]`: `a` and
  `b` are one segment linked with every data address at its prebound
  value and moved down by `delta`; returns each 16-bit site's offset and
  its value in `a`.  Dies when the lengths differ, or on any differing
  byte that does not start a word differing by exactly `delta` (mod
  `$10000`).
- `attribute(sites, objects) -> {object name: [off, ...]}` where
  `objects` is `[(name, addr, size)]`; a value `v` belongs to the object
  with `addr <= v < addr + size`; failing that, to the one with
  `v == addr + size` (one past the end -- C allows that pointer); a value
  in none dies naming segment offset and value.  An exact position inside
  an object always wins over one past another's end: `&x` right after
  `errno` is x's, or the binder would move it by errno's delta.

- [ ] **Step 1: Failing self-test** (in the module, `--self-test`):

```python
def self_test():
    a = bytes([0xAD, 0x00, 0xF8, 0xEA, 0xA9, 0x02, 0xF8, 0x00])   # LDA errno; LDA #errno+2
    b = bytes([0xAD, 0xF0, 0xE7, 0xEA, 0xA9, 0xF2, 0xE7, 0x00])
    assert diff_sites(a, b) == [(1, 0xF800), (5, 0xF802)]
    assert attribute([(1, 0xF800), (5, 0xF802)],
                     [("errno", 0xF800, 2), ("x", 0xF802, 4)]) == \
        {"errno": [1], "x": [5]}              # x's start, not one past errno
    assert attribute([(5, 0xF802)], [("errno", 0xF800, 2)]) == \
        {"errno": [5]}                        # one past the end: errno's
    expect_die(lambda: diff_sites(a, b[:-1]), "length")
    expect_die(lambda: diff_sites(a, bytes([0xAD, 0x00, 0xE7]) + a[3:]), "not a word")
    # A hand-written LDA #>errno: the lone high byte moves.
    expect_die(lambda: diff_sites(bytes([0xA9, 0xF8, 0x00]),
                                  bytes([0xA9, 0xE7, 0x00])), "not a word")
    expect_die(lambda: attribute([(1, 0x1234)], [("errno", 0xF800, 2)]), "no import")
    print("fgx_sites: self-test OK")
```

  (the second `expect_die` changes only the high byte of the first word;
  `expect_die(fn, word)` asserts `SystemExit` whose text contains `word`.)

Run: `python3 toolchain/src/ld/fgx_sites.py --self-test`
Expected: FAIL (file does not exist).

- [ ] **Step 2: Implement.**

```python
def diff_sites(a, b, delta=DELTA):
    if len(a) != len(b):
        die("the two links differ in length (%d, %d): an operand changed "
            "size, so the delta moved something it must not" % (len(a), len(b)))
    out, i = [], 0
    while i < len(a):
        if a[i] == b[i]:
            i += 1
            continue
        if i + 1 >= len(a):
            die("offset %#06x: a lone byte differs, not a word" % i)
        va, vb = a[i] | a[i + 1] << 8, b[i] | b[i + 1] << 8
        if (va - vb) & 0xFFFF != delta:
            die("offset %#06x: %#06x vs %#06x is not a word moved by %#06x "
                "(a high- or low-byte operand?)" % (i, va, vb, delta))
        out.append((i, va))
        i += 2
    return out
```

  `attribute` as specified.

- [ ] **Step 3: Run.**

Run: `python3 toolchain/src/ld/fgx_sites.py --self-test`
Expected: `fgx_sites: self-test OK`.

- [ ] **Step 4: Commit** (`feat(ld): fgx_sites finds data sites by linking twice`,
  body: the delta, why down, the three refusals, one-past-the-end; trailers).

---

### Task 8: fgx_libso builds any library; termlib and curses

**Files:**
- Modify: `toolchain/src/ld/fgx_libso.py` (a `LIBS` table; `core_link`,
  `build`, `blktab`, `OUTPUT` take the library; a second link for sites)
- Create: `toolchain/lib/libtermlib_c/data.exports` (`UP BC PC ospeed`),
  `toolchain/lib/libcurses_c/data.exports` (Step 1), `toolchain/lib/libcurses_c/core.list`
  (`sflags`, `sstrs`, `_PC`)
- Modify: `toolchain/Makefile` (library-mode compiles and links of both;
  `.gitignore` for their outputs, as libc's)

**Interfaces:**
- Consumes: Task 2 `is_common`; Task 4 trailer; Task 5 `--libso-name`;
  Task 6 `"imports"`; Task 7 `diff_sites`, `attribute`.
- `LIBS[name]` = dict(code, data, blocks, core_list (or None), exports,
  prefix, bank0 (files), data_files, below (names), version, dir (its
  build directory, whose `core_Output.txt` a library above reads), equs
  (extra code EQUs)).  libc's row
  is today's constants.  termlib: code `lib/libtermlib_so.s`, data
  `lib/libtermlib_so_data.s`, prefix `_libtermlib_`, bank0
  `[libtermlib_helpers.s]`, data_files `[fcc_runtime_data.s,
  libtermlib_helpers_data.s]`, below `["libc"]`.  curses: code
  `lib/libcurses_so.s`, prefix `_libcurses_`, bank0 `[]`, data_files
  `[fcc_runtime_data.s]`, below `["libc", "libtermlib"]`.  termlib's and
  curses's `equs` are `LIBC_DP_LP0 $EB` and `LIBC_DP_DST $E6` (defined
  only in `libc.s:61, 16`, which a library above libc does not PUT;
  termlib's inline `__asm` and `libtermlib_helpers.s` name them).
- `OUTPUT` becomes a function of the library: `<name>_so.json`,
  `imports_layout.s` and every file the second (site) link writes, so
  `clear_outputs` accepts a rerun of any library.
- Bank 0 co-residency: a function that names a label a `bank0` file
  defines (termlib's `tget*` near-JSR `_tc_*` in `libtermlib_helpers.s`)
  is packed into bank 0, as `pre0`'s helpers are; `pack` is given those
  functions pre-placed.  A self-test case pins it.
- `build(name, out, d)`; CLI `fgx_libso.py --lib NAME --out FILE --dir DIR`
  (`--lib` defaults to `libc`).

- [ ] **Step 1: curses's exports.**  Generate the list the way the
  Makefile's `curses.fgxa.public` rule does, less termlib's four:

Run: `grep -hE 'extern ' toolchain/lib/libcurses_c/curses.ext toolchain/include/curses.h | grep -oE '[A-Za-z_][A-Za-z0-9_]*' | grep -vE '^(extern|char|int|bool|short|long|unsigned|struct|SGTTY|WINDOW|FILE|void|UP|BC|PC|ospeed)$' | sort -u`
then keep only the names that are data (drop any that `grep -n '^<name>(' toolchain/lib/libcurses_c/*.c`
finds as a function) and add `stdscr`, `curscr`; write the result with a
header comment to `libcurses_c/data.exports`.

- [ ] **Step 2: Makefile compiles.**  Beside `lib/libc_so.s`:

```make
lib/libtermlib_so.s: $(wildcard lib/libtermlib_c/*.c) $(wildcard include/*.h) fcc
	./fcc --libso --libso-name libtermlib --sections --emit-blocks lib/libtermlib_so.blocks.json -Ilib/libtermlib_c lib/libtermlib_c/libtermlib.c -o lib/libtermlib_so.s --data-segment lib/libtermlib_so_data.s
lib/libcurses_so.s: $(wildcard lib/libcurses_c/*.c) lib/libcurses_c/curses.ext lib/libcurses_c/core.list $(wildcard include/*.h) fcc
	./fcc --libso --libso-name libcurses --sections -DNOSCCS --core-list lib/libcurses_c/core.list --emit-blocks lib/libcurses_so.blocks.json -Ilib/libcurses_c lib/libcurses_c/libcurses.c -o lib/libcurses_so.s --data-segment lib/libcurses_so_data.s
```

Run: `make -C toolchain lib/libtermlib_so.s lib/libcurses_so.s 2>&1 | grep -v 'implicit declaration' | tail -3`
Expected: both compile (curses's implicit-declaration warnings are
upstream's K&R style and unchanged).

- [ ] **Step 3: Generalise fgx_libso, libc byte-identical.**  Move every
  libc-specific constant into `LIBS["libc"]` and thread `lib` through
  `core_link`, `build` and `blktab` (`_<name>_blktab`, `_<name>_blk_<m>`).
  Nothing else changes for libc.

Before the edit: `cp toolchain/lib/libc.so.1.0 <scratch>`
(`libc.so.1.0` is gitignored, so git holds no copy).

Run: `cd toolchain && python3 src/ld/fgx_libso.py --self-test && make libc_so 2>&1 | tail -1 && cmp lib/libc.so.1.0 <scratch> && python3 ../tools/libc_so_check.py`
Expected: self-test OK; `cmp` silent; libc_so_check clean.

- [ ] **Step 4: A library above libc.**  For a library with `below`:
  1. read each lower `.so`'s trailer; the core base is the lowest lower
     core's base minus this core's size (measured at 0 first, as libc's);
  2. the core's data is the library's `*_so_data.s` sections, less every
     `is_common` section whose name a lower library exports as data (it is
     an import), plus `data_files`;
  3. write `imports_layout.s`: one `EQU` per lower library data export at
     its prebound address (libc: its trailer's address; termlib, for
     curses: termlib's trailer address, which is its stacked base plus
     offset);
  4. assemble and link as libc does, with `"imports": [lower .so paths]`
     in the manifest -- once at the prebound addresses (the output) and
     once with the core org and every `imports_layout.s` value lowered by
     `fgx_sites.DELTA` (a scratch output);
  5. per segment, `diff_sites(out_seg, scratch_seg)`, then `attribute`
     against the objects `[("core", base, size)] + [data imports]`; the
     `core` sites become the `CSIT` block, the rest become `data` sites in
     the IMPS table (add them to the resolver's record before packing).
  A library naming a lower library's private cell dies in fgx_ld (Task 6)
  for code and pointers, and in Merlin as an undefined label for data --
  check first: scan the library's code for identifiers a lower core
  listing defines but `imports_layout.s` lacks AND the library's own core
  and `data_files` do not define (its own `_fcc_*`/`__asm_*` cells share
  names with libc's), and die naming them.

- [ ] **Step 5: Build both.**  Makefile rules beside `lib/libc.so.1.0`:

```make
lib/libtermlib.so.1.0: lib/libtermlib_so.s lib/libtermlib_so_data.s lib/libtermlib_helpers.s lib/libtermlib_helpers_data.s lib/libtermlib_c/data.exports lib/libc.so.1.0 src/ld/fgx_libso.py src/ld/fgx_ld.py src/ld/fgx_imports.py src/ld/fgx_sites.py
	python3 src/ld/fgx_libso.py --lib libtermlib --out lib/libtermlib.so.1.0 --dir lib/libtermlib_so.d
lib/libcurses.so.1.0: lib/libcurses_so.s lib/libcurses_so_data.s lib/libcurses_c/data.exports lib/libcurses_c/core.list lib/libc.so.1.0 lib/libtermlib.so.1.0 src/ld/fgx_libso.py src/ld/fgx_ld.py src/ld/fgx_imports.py src/ld/fgx_sites.py
	python3 src/ld/fgx_libso.py --lib libcurses --out lib/libcurses.so.1.0 --dir lib/libcurses_so.d
libso_all: libc_so lib/libtermlib.so.1.0 lib/libcurses.so.1.0
```

Announce the builds.

Run: `make -C toolchain libso_all 2>&1 | tail -3`
Expected: three summary lines; libtermlib: 1 code bank, core ~0.5 KB
(its data exports, `_fcc_*` cells, the baked tables), 1 block (74 bytes),
imports `strcpy`, `strcat` and the rest of libc it calls; libcurses: 1-2
code banks, core ~4.5 KB (measured: 146 core sections, 4,044 bytes of
`DS` -- `cr_tty.c`'s extern-linkage `char _tspace[2048]`, `ttytype[50]`
-- plus `_unctrl`'s 128 pointers, 512 bytes and 128 core-to-code relocs;
`_tspace` is not static, so it is core, and a block would cost every
curses program the same bytes, since each reaches `cr_tty`), 5 blocks
(1,657 bytes), imports from libc and
termlib including data `UP`, `BC`, `PC`, `ospeed`, with data sites for
each.  Record the real numbers for Task 10.

- [ ] **Step 6: Commit** (`feat(libc): libtermlib.so and libcurses.so`,
  body: the LIBS table, stacked bases, imports, the two-link site finder,
  sizes and import counts measured; trailers).

---

### Task 9: libc_so_check covers three libraries

**Files:**
- Modify: `tools/libc_so_check.py` (a `--lib NAME` per library; checks
  and controls below), `toolchain/Makefile` (`test-archives` runs it for
  all three)

- [ ] **Step 1: Failing controls first.**  Add controls that must fail on
  a broken copy of libtermlib.so: (9) a `JSL` whose operand is neither
  relocated nor an IMPS call site (drop one IMPS call site from the
  trailer); (6) an IMPS call site whose operand
  bytes are not the import's prebound offset; (7) a CSIT site whose word
  lies outside `[core_base, core_base + core_size]`; (8) an import naming
  an ordinal whose name differs from the lower library's export at that
  ordinal.  Run `python3 tools/libc_so_check.py --lib libtermlib --self-test`
  and watch them fail as "not caught" before the checks exist (control 9
  fails today the other way: the unchanged check reports every termlib
  import call as "has no reloc", so the clean file itself fails first).

- [ ] **Step 2: Checks.**  The "every FGX2_FARCALL/FARJUMP has its bank
  reloc" check (`libc_so_check.py:113-121`) accepts a farcall whose
  `(seg, addr + 1)` is an IMPS call site -- a library's calls into a lower
  library have no reloc by design (Task 6) -- and still fails one with
  neither.  For every library: the existing checks, with
  the data-export list from that library's `data.exports` and the
  far-helper and fixup checks libc-only (termlib has no fixups; curses has
  `sflags`/`sstrs` core-to-core ones -- check it has at least one); for a
  library with IMPS: every import resolves in the named lower library at
  that ordinal and name; every call site's operand bytes equal the
  prebound offset and its opcode byte (`off - 1`) is `JSL` or `JML`; every
  pointer site's two bytes equal the prebound offset; every data site's
  word lies in its import's `[addr, addr + size]`; every CSIT word lies in
  the library's own core; no import names a lower library's private cell.
  Report: code banks, core size and base, blocks, exports, imports by
  kind and site counts.

- [ ] **Step 3: Run.**

Run: `for l in libc libtermlib libcurses; do python3 tools/libc_so_check.py --lib $l --self-test && python3 tools/libc_so_check.py --lib $l; done`
Expected: three `self-test OK` lines and three clean reports.  Add the
loop to `test-archives` in `toolchain/Makefile`.

Run: `make -C toolchain test-archives 2>&1 | tail -3`
Expected: green.

- [ ] **Step 4: Commit** (`test(libc): libc_so_check covers libtermlib.so and libcurses.so`).

---

### Task 10: record the step, run the gate

- [ ] **Step 1: The spec.**  Section 2: termlib's core is at its stacked
  base, not `$8000` (the reason from this plan's header); the measured
  core, block and import numbers for both libraries.  Section 8: "Step 1
  landed <date>" with those numbers.  The umbrella's section 6 item 3:
  "step 1 landed".

- [ ] **Step 2: The gate** (Tasks 4-9 changed fgx_ld and fcc).  Announce it.

Run: `tools/gate.sh 2>&1 | tail -3`
Expected: `GATE GREEN`.

- [ ] **Step 3: Commit and the project notes** (`group_id="fgx"`): step 1 landed;
  termlib owns UP/BC/PC/ospeed (SUPERSEDES "termlib's UP/BC are
  client-owned"); fgx_gc merges commons; the trailer v2 layout; the site
  finder's delta; the far list is nine.

```bash
git add docs/history/plans/2026-09-29-shared-libc-sp3-design.md docs/history/plans/2026-09-28-shared-libc-design.md
git commit -F - <<'EOF'
docs(plans): shared libc SP3 step 1 landed

EOF
```
