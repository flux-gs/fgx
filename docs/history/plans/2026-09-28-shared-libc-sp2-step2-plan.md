# Shared libc SP2 step 2: fcc library mode (`--libso`) -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** fcc compiles libc's umbrella TU in a library mode whose output is
what libc.so needs: every call a `JSL`, string literals in code pushed with
`PHK`, core data addressed as today, and every other static reached through a
per-member block cell -- with the member-block layout written to a sidecar for
fgx_ld (step 3).

**Architecture:** A `--libso` flag.  The lexer stamps each token with its
source file, so every `Global` knows the member that defined it.  Statics that
are neither exported nor named in `core.list` become *block statics*: the data
file lays each member's statics out as one block template, and every access
computes the address `(*_libc_blk_<member>) + off` in the one place fcc
decides a global's address (`emit_fpr_addr_global`).  Block statics are
routed into fcc's uniform lvalue walker (`N_LV_CHAIN`), whose named base goes
through that function; every emitter that would address a block static by its
label dies instead, so any shape not yet routed fails the compile loudly.

**Tech Stack:** C (fcc, `toolchain/src/cc/*.c`), bash (`toolchain/tests/run.sh`),
Python 3 host tests, Merlin32 goldens.

**Spec:** `docs/history/plans/2026-09-28-shared-libc-sp2-design.md` sections 3,
4, 6 and 7 item 2.  Correction found while planning: the spec's "three `PHB`
literal sites" is one -- `emit_fpr_lit_str` (`emit.c:6589`); the other two
(`emit.c:1425`, `3845`) address globals, not literals.

## Global Constraints

- ASCII only; comments describe the current state; commit bodies
  informational, naming the K&R section or BSD file a change follows, ending
- **Every fcc parser/codegen change quotes the deciding K&R Appendix A
  sentence in its commit** (read via gs-mcp `kr_c`, never from memory).
- `--libso` changes NOTHING when absent: all 701 existing fixture goldens stay
  byte-identical (`bash toolchain/tests/run.sh` green) after every task.
- Library mode fails loudly on anything it cannot place: an unrouted
  block-static shape, a same-named static in two members, a data export
  missing from core -- `die()` with the name, never silent output.
- Fixtures: `toolchain/tests/M42/` compiles with `--libso` via a per-directory
  `_fcc.flags` sidecar; goldens by `REGEN=1 bash toolchain/tests/run.sh <names>`.
- Nothing added to the gate beyond what `make test`/`tests/run.sh` already run.
- The branch stays `feat/shared-libc`, not pushed; announce rebuilds.

## Review Focus

1. A block static reached by a shape no fixture names (e.g. `static struct
   tm tm; tm.tm_year++` through a pointer to it, or a static used as a
   `switch` operand) -- must die at compile, not emit a label access; Task 7's
   whole-libc compile is the net.
2. A function-local static in a function whose name makes its mangled label
   collide (`g_sl_seq` fallback names) -- attribution must use the declaring
   token's file, not the function's.
3. A macro that expands to a static's name from a header -- the token's file
   would be the header; statics are defined only in members, but a macro USE
   in member A of a static defined in A must still resolve to A's block.
4. An initialised block static whose initialiser is a pointer to a literal
   or function (`static char *p = "x"`) -- its template bytes carry a reloc,
   which step 3 applies; the sidecar must record it.
5. `sizeof` a block array -- must still be the array's size (K&R A.7.4.8).

---

### Task 1: `--libso`, and every Global knows its member

**Files:**
- Modify: `toolchain/src/cc/fcc.h` (`Tok.file`, `Global.member`,
  `extern int g_libso`, `extern const char *g_emit_blocks_path`),
  `toolchain/src/cc/globals.c` (definitions), `toolchain/src/cc/lex_pp.c`
  (stamp `g_cur.file`; intern include paths), `toolchain/src/cc/symtab.c`
  (`globals_declare` records the member; same-name-different-member check),
  `toolchain/src/cc/main.c` (`--libso`, `--emit-blocks FILE`)
- Create: `toolchain/tests/libso/test_libso.py`, `toolchain/tests/libso/umb/`
  (a two-member umbrella), `toolchain/Makefile` (`test-archives` runs it)

**Interfaces:**
- Produces: `Global.member` (`const char *`, the defining file's stem, e.g.
  `"strtok"`; NULL outside `--libso`); `g_libso`; the `--emit-blocks` JSON
  sidecar `{"members": {"<stem>": [{"name": "<gname>", "bytes": N}]}}` listing
  each member's non-extern statics in declaration order.  Task 4 extends each
  row with `"offset"`, `"core"` and `"init"`.

- [ ] **Step 1: Write the host test**

`toolchain/tests/libso/umb/umb.c`:
```c
/* two-member umbrella for fcc --libso host tests */
#include "a.c"
#include "b.c"
```
`toolchain/tests/libso/umb/a.c`:
```c
static int a_count;
static char a_buf[10];
int a_get() { static int calls; calls++; return a_count + a_buf[0] + calls; }
```
`toolchain/tests/libso/umb/b.c`:
```c
static int b_state = 7;
int b_get() { return b_state; }
```
`toolchain/tests/libso/umb/clash.c` (a second umbrella):
```c
#include "a.c"
#include "clash_b.c"
```
`toolchain/tests/libso/umb/clash_b.c`:
```c
static int a_count;
int clash() { return a_count; }
```
`toolchain/tests/libso/test_libso.py`:
```python
#!/usr/bin/env python3
"""test_libso.py - fcc --libso host checks (shared libc SP2 step 2).

Run from the toolchain root: python3 tests/libso/test_libso.py
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UMB = os.path.join(ROOT, "tests", "libso", "umb")
FCC = os.path.join(ROOT, "fcc")
fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def fcc(src, *extra):
    d = tempfile.mkdtemp(prefix="libso_")
    out = os.path.join(d, "o.s")
    blocks = os.path.join(d, "blocks.json")
    r = subprocess.run([FCC, "--libso", "--emit-blocks", blocks, "-I" + UMB,
                        *extra, os.path.join(UMB, src), "-o", out,
                        "--data-segment", os.path.join(d, "o.data.s")],
                       capture_output=True, text=True)
    return r, d, blocks


def attribution():
    r, d, blocks = fcc("umb.c")
    check(r.returncode == 0, "umb.c compiles in --libso", r.stderr.strip()[:200])
    if r.returncode:
        return
    m = json.load(open(blocks))["members"]
    names = {k: [row["name"] for row in v] for k, v in m.items()}
    check(set(names) == {"a", "b"}, "two members, named by file stem", str(names))
    check(any(n.endswith("a_count") for n in names.get("a", [])), "a_count is a's")
    check(any(n.endswith("a_buf") for n in names.get("a", [])), "a_buf is a's")
    check(any("calls" in n for n in names.get("a", [])),
          "a_get's function-local static is a's")
    check(any(n.endswith("b_state") for n in names.get("b", [])), "b_state is b's")
    sizes = {row["name"]: row["bytes"] for v in m.values() for row in v}
    buf = [s for n, s in sizes.items() if n.endswith("a_buf")]
    check(buf == [10], "a_buf is 10 bytes", str(buf))


def clash():
    r, _, _ = fcc("clash.c")
    check(r.returncode != 0 and "a_count" in r.stderr and "clash_b" in r.stderr,
          "a same-named static in two members is refused, naming both",
          r.stderr.strip()[:200])


attribution()
clash()
print("FAIL: %d" % len(fails) if fails else "libso checks passed")
sys.exit(1 if fails else 0)
```

- [ ] **Step 2: Run it red**

Run: `cd toolchain && make -s fcc && python3 tests/libso/test_libso.py`
Expected: FAIL on `umb.c compiles in --libso` (fcc prints usage for the
unknown flag) and on the clash check.

- [ ] **Step 3: Stamp tokens with their file**

`fcc.h`, in `Tok` after `int col;`:
```c
    const char *file;  /* the source file this token was scanned from
                        * (interned; the umbrella's path for its own lines) */
```
`lex_pp.c`: in `lex_set_source`, intern the path before storing it
(`g_cur_path = intern_path(path);` where `intern_path` is a new static helper
that `strdup`s once and caches the last result -- the include handler passes a
stack buffer, `char full[256]`, that dies when the include returns).  In
`scan_tok` beside `g_cur.line = g_line;` add `g_cur.file = g_cur_path;`.
Check `pp_next_tok_above` (macro expansion, lex_pp.c:~1946): an expanded
token must carry the INVOCATION's file; if it copies the definition token's
`file`, overwrite `file` with `g_cur_path` where it sets `line`/`col`.

- [ ] **Step 4: Record the member in `globals_declare`**

`fcc.h`, in `Global` after `int is_extern;`: `const char *member;` (the
defining member's file stem under `--libso`, else NULL).
`symtab.c`, `globals_declare`: when `!is_extern_decl && g_libso`, compute the
stem of `g_cur.file` (basename without `.c`) into an interned string.  If the
slot already has a different non-NULL `member` and both declarations are
definitions (`!is_extern_decl`), `die(line, col, ...)` with a message naming
the static and both members, e.g.
`"static 'a_count' is defined in members 'a' and 'clash_b'; libc.so needs one owner"`.
Otherwise set `g->member`.  (A function-local static goes through
`globals_declare` at parse_stmt.c:4182 while `g_cur` is at its declarator, so
it gets its member the same way.)

- [ ] **Step 5: The flags and the sidecar**

`globals.c`: `int g_libso = 0; const char *g_emit_blocks_path = NULL;`
(externs in `fcc.h` beside `g_pile_far_extern`).  `main.c`, beside
`--pile-far-extern`:
```c
        } else if (strcmp(argv[i], "--libso") == 0) {
            g_libso = 1;
        } else if (strcmp(argv[i], "--emit-blocks") == 0 && i + 1 < argc) {
            g_emit_blocks_path = argv[++i];
```
and add both to `usage()`.  After the TU is emitted (where `--emit-sigs` is
written), when `g_emit_blocks_path` is set write the JSON: for each member
stem in first-seen order, the non-extern globals whose `member` is that stem
and which are static (`is_static`, or a function-local static), as
`{"name": gname(g), "bytes": g->n_bytes}`.

- [ ] **Step 6: Run green; goldens unchanged**

Run: `cd toolchain && make -s fcc && python3 tests/libso/test_libso.py && bash tests/run.sh >/tmp/rs.log 2>&1; tail -2 /tmp/rs.log`
(use the session scratchpad for the log)
Expected: `libso checks passed`; run.sh `N passed, 0 failed` with N the
current fixture count (701).

- [ ] **Step 7: Wire and commit**

Add `python3 tests/libso/test_libso.py` to `test-archives` in
`toolchain/Makefile`.  Commit `feat(fcc): --libso, and a static knows the
member that defines it`, quoting K&R A.11.2 on internal linkage (read it:
`search_iigs_docs("internal linkage translation unit", ["kr_c"])`) for why two
members' same-named statics cannot share one libc.so.

### Task 2: Fixture flags, and every call is a `JSL`

**Files:**
- Modify: `toolchain/tests/run.sh` (per-directory `_fcc.flags`),
  `toolchain/src/cc/emit.c` (`emit_call`, `emit_libc_call`, `emit_ll_call`
  force far under `g_libso`)
- Create: `toolchain/tests/M42/` (copy `_seg0.link.s`, `_seg1.link.s`,
  `_fgx.json` from `tests/M41/`; `_fcc.flags` containing `--libso`),
  `toolchain/tests/M42/libso_calls.c` + goldens

- [ ] **Step 1: The fixture**

```c
/* M42: --libso calls.  Every call -- to a static function, to an extern, to
 * setjmp, and to the long long runtime -- is a JSL (FGX2_FARCALL): libc.so's
 * banks are relocated at load, so a call needs no pile trampoline. */
#include <setjmp.h>
static int helper(x) int x; { return x + 1; }
int ext();
static jmp_buf jb;
int main()
{
    long long a = 3, b = 5;
    if (setjmp(jb)) return 1;
    a = a * b;
    return helper((int)a) == 16 ? 42 : ext();
}
int ext() { return 0; }
```

- [ ] **Step 2: Flags sidecar in run.sh**

Beside `sigsarg`:
```bash
        dirflags=""
        [ -f "$dir/_fcc.flags" ] && dirflags=$(cat "$dir/_fcc.flags")
```
and pass `$dirflags` next to `$sigsarg` in the `"$FCC"` command.  A plain
string, not an array (bash 3.2 under `set -u`; see the comment above
`sigsarg`).

- [ ] **Step 3: Generate, and watch it show pile calls**

Run: `cd toolchain && REGEN=1 bash tests/run.sh libso_calls && grep -c "PILECALL" tests/M42/libso_calls.expected.s; grep -c "FGX2_FARCALL" tests/M42/libso_calls.expected.s`
Expected: if `--libso` alone leaves `g_pile` 0, FARCALL everywhere and no
PILECALL already -- then this step proves the property and Step 4 only adds
the guard.  If any PILECALL appears, Step 4 fixes it.

- [ ] **Step 4: Force far under `--libso`**

In `emit_call` treat `g_libso` as `is_far` for every target; in
`emit_libc_call` and `emit_ll_call` add `|| g_libso` to the far condition.
Also make `--libso` refuse `--pile` (`die` in main.c: "--libso and --pile are
exclusive: library mode calls by JSL").  Regenerate the golden; assert
`grep -c PILECALL` is 0.

- [ ] **Step 5: Goldens unchanged, commit**

Run: `bash tests/run.sh >$SCRATCH/rs.log 2>&1; tail -1 $SCRATCH/rs.log`
Expected: all pass, one more fixture than before.
Commit `feat(fcc): in library mode every call is a JSL`.

### Task 3: String literals live in code and are pushed with `PHK`

**Files:**
- Modify: `toolchain/src/cc/emit.c` (`emit_str_pool` to the code stream under
  `g_libso`, sectioned; `emit_fpr_lit_str` uses `emit_fpr_bank_pbr` under
  `g_libso`), `toolchain/tests/sections.py` (a sectioned code item may hold
  data, not only a function)
- Create: `toolchain/tests/M42/libso_lit.c` + goldens

- [ ] **Step 1: Read K&R A.2.6 and quote it in the commit**

`get_iigs_page("kr_c", 156)`: "the behavior of a program that attempts to
alter a string literal is undefined" -- the licence for read-only placement.

- [ ] **Step 2: The fixture**

```c
/* M42: --libso literals.  A string literal lives in the code bank and its
 * bank is pushed with PHK; a char array initialised from a literal is a
 * writable static and stays in data (K&R A.2.6, A.8.7). */
static char *msg = "lit-ptr";
static char arr[] = "arr-init";
int strlen();
int main()
{
    arr[0] = 'A';
    return strlen("expr-lit") + strlen(msg) + arr[0] == 8 + 7 + 65 ? 42 : 1;
}
```

- [ ] **Step 3: Generate and see literals in data (red by inspection)**

Run: `REGEN=1 bash tests/run.sh libso_lit; grep -c "_S[0-9]" tests/M42/libso_lit.expected.data.s; grep -B1 "LDA     #_libso_lit_S" tests/M42/libso_lit.expected.s | head -4`
Expected before the change: the pool rows (`_libso_lit_S0 HEX ...`) are in
`.data.s`, and the instruction before each `LDA #..._S<n>` sequence is `PHB`.

- [ ] **Step 4: Move the pool and push `PHK`**

In `emit_str_pool`, when `g_libso`: write through `ir_emitf` (code stream)
instead of `fprintf(g_data_out, ...)`, with `emit_mac_export(0, ...)`, and
bracket each item with `FGX_SECT <label>` / `FGX_ENDS` when `g_sections`.
In `emit_fpr_lit_str`, call `emit_fpr_bank_pbr(k)` when `g_libso`, else
`emit_fpr_bank_dbr(k)` as today.  The data-side references
(`FGX2_LONG_PTR _Sg/_Sa;<label>;0`, emit.c:5731/5902/6010) are unchanged:
fgx_ld resolves them by name, and step 3 relocates them at load.  Relax
`tests/sections.py` check 2 so a sectioned code item with a data directive
(`HEX`/`ASC`) and no `ENT` is accepted.

- [ ] **Step 5: Regenerate, assert, run all**

Run: `REGEN=1 bash tests/run.sh libso_lit; grep -c "HEX" tests/M42/libso_lit.expected.data.s; grep -c "_libso_lit_S0" tests/M42/libso_lit.expected.s; grep -B6 "LDA     #_libso_lit_S" tests/M42/libso_lit.expected.s | grep -c PHK; bash tests/run.sh >$SCRATCH/rs.log 2>&1; tail -1 $SCRATCH/rs.log; python3 tests/sections.py`
Expected: the data file keeps `arr`'s bytes (DFB/HEX rows for `arr-init`) but
no `_S<n>` row; the code file holds `_libso_lit_S0`...; PHK precedes each
literal address; all fixtures pass; sections OK.
Commit `feat(fcc): library mode keeps string literals in code`, quoting A.2.6.

### Task 4: Core, blocks, and the block layout

**Files:**
- Modify: `toolchain/src/cc/main.c` (`--core-list FILE`),
  `toolchain/src/cc/emit.c` (`emit_globals_section`: under `g_libso`, block
  statics are emitted per member as a block template), `symtab.c`
  (`is_block_static(g)`), the `--emit-blocks` writer (offsets, core, init)
- Create: `toolchain/lib/libc_c/core.list`, extend
  `toolchain/tests/libso/test_libso.py`

**Interfaces:**
- Produces: `int is_block_static(Global *g)` -- true iff `g_libso`,
  `!g->is_extern`, `g->member != NULL`, the global has internal linkage
  (file-scope `static` or function-local static) and its name is not in the
  core list.  Block statics are emitted as:
  ```
  _libc_blk_<member>  DA  0            ; in the core: this process's block address
  ...
  <member>__BT        ANOP             ; block template, one FGX_SECT per member
  <gname>__O          EQU  <offset>    ; each static's offset in its block
                      <its initial bytes, DS for zero-fill>
  ```
  The JSON rows gain `"offset"`, `"core": false` and `"init": true|false`,
  and each member gains `"size"`.  Core globals are emitted exactly as today.
- `core.list`: one symbol per line (unmangled C name), `#` comments.

- [ ] **Step 1: Extend the host test (red)**

Add to `test_libso.py`: compile `umb.c` with `--core-list` naming
`b_state`; assert member `a`'s rows have offsets 0, 2, 12 in declaration
order for `a_count` (2 bytes), `a_buf` (10 bytes), `calls` (2 bytes) and
`"size": 14`; assert `b_state` is absent from the block rows and still
emitted as a plain data label with its initial value 7; assert the data file
contains `_libc_blk_a` and `a__BT`.  Run: expected FAIL (no offsets yet).

- [ ] **Step 2: Implement**

`--core-list FILE` reads names into a small table (`g_core_names`,
`MAX_CORE_NAMES 64`, die when full).  `is_block_static` as above.  In
`emit_globals_section`, when `g_libso`, skip block statics in the normal loop;
afterwards, per member in first-seen order, emit the core cell
`_libc_blk_<member> DA 0` (with `FGX2_EXPORT`), then the template:
`FGX_SECT <member>__BT` (when `g_sections`), `<member>__BT ANOP`, and for each
of its block statics `<gname>__O EQU *-<member>__BT` followed by the same
initial-value directives the normal path emits for that global (reuse the
per-global emission body; factor it into a helper rather than copying it),
then `FGX_ENDS`.  A block static whose initialiser is an address
(`init_str_label`, `init_func_idx`, `init_global_idx`) is emitted through the
same `FGX2_LONG_PTR` macro, so the reloc travels with the template; record
`"init": true` for it.  A block static whose initialiser names ANOTHER block
static (`init_global_idx` pointing at a block static) dies: "block-to-block
pointer initialiser" (spec section 4).

- [ ] **Step 3: Seed `core.list`**

```
# Statics that stay in libc's per-process CORE rather than a member block
# (shared libc SP2 spec, section 4): the buffered-stdio and printf state
# every stdio program already carries and that getc/putc/printf touch per
# byte.  One unmangled name per line.
_lc_buf
_lc_bpos
_lc_blen
_lc_bfail
_lc_bfd
_lc_btty
_lc_small
_lc_wfd
_lc_wbuf
_lc_wcnt
_lc_wline
_lc_wready
_lc_wnomem
__lc_pf_mode
__lc_pf_fd
__lc_pf_out
__lc_pf_lim
__lc_pf_n
__lc_pf_fill
__lc_pf_fdbuf
__lc_pf_gbuf
__lc_pf_glen
```
Check each name against `stdio_core.c:92-108,242-248` and `printf.c:26-41`
before committing; the list is the source files' names, not this plan's.

- [ ] **Step 4: Green, goldens unchanged, commit**

Run: `make -s fcc && python3 tests/libso/test_libso.py && bash tests/run.sh >$SCRATCH/rs.log 2>&1; tail -1 $SCRATCH/rs.log`
Expected: passed; fixtures all pass.
Commit `feat(fcc): library mode lays each member's statics out as a block`.

### Task 5: A block static's address comes from its block cell; label paths die

**Files:**
- Modify: `toolchain/src/cc/emit.c` (`emit_fpr_addr_global`; a guard in each
  of the 17 functions that emit `gname(g)` as an operand for a variable
  access), `toolchain/src/cc/parse_stmt.c` (the 9 raw `gname` uses in
  `walk_stmt`: :998-1008, :1810-1820, :1935)
- Create: `toolchain/tests/M42/libso_addr.c` + goldens,
  `toolchain/tests/reject/libso_label.c`

- [ ] **Step 1: The address fixture**

```c
/* M42: --libso block-static address.  &s of a block static is its block
 * cell's value plus its offset, in the data bank. */
static int s = 5;
int deref(p) int *p; { return *p; }
int main() { return deref(&s) == 5 ? 42 : 1; }
```

- [ ] **Step 2: The reject fixture (must fail loudly)**

`tests/reject/libso_label.c` -- first line is the expected diagnostic:
```c
/* expect: block static 'n' */
static int n;
int main() { n = 3; return n; }
```
The reject runner compiles plain `fcc src`; give it the flag: extend
`tests/run_reject.sh` to read an optional second header line
`/* flags: --libso */` and pass it (a plain string, `set -u` safe).

- [ ] **Step 3: Run both red**

`REGEN=1 bash tests/run.sh libso_addr` then inspect: `&s` is `PHB` +
`LDA #_libso_addr_s` (label).  `bash tests/run_reject.sh`: `libso_label`
FAILS (compiles fine today).

- [ ] **Step 4: Implement the address and the guards**

`emit_fpr_addr_global`:
```c
void
emit_fpr_addr_global(int k, Global *g)
{
    emit_fpr_bank_dbr(k);
    if (is_block_static(g)) {
        /* A block static lives in this process's block for its member:
         * the block's address is in the core cell, the static is at a fixed
         * offset in it (shared libc SP2 spec, section 4). */
        ir_emitf("                LDA     _libc_blk_%s\n", g->member);
        ir_emitf("                CLC\n");
        ir_emitf("                ADC     #%s__O\n", gname(g));
    } else {
        ir_emitf("                LDA     #%s\n", gname(g));
    }
    ir_record_raw(IR_STA_CELL, 0, 0, (void *)cellp(fpr_name(k)));
}
```
A helper `void refuse_block_static(Global *g, const char *path)` that
`die(0, 0, "block static '<name>' reached <path>, which addresses it by
label; route it through the lvalue walker")` when `is_block_static(g)`.  Call
it at the top of every emitter that uses `gname(g)` as an access operand:
`emit_load_global`, `emit_store_global_int`, the `emit_*_lower` bodies,
`emit_addr_of_global`, `emit_load_global_field`, `emit_store_global_field`,
`emit_airg_tail`, `emit_binop_mem_global_lower`, `emit_fpr_load_global_ptr`,
`emit_fpr_store_global_ptr`, `emit_fpr_incdec_home_global`,
`emit_fpr_load_field`, and the three `walk_stmt` sites -- NOT
`emit_globals_section` (it emits storage, Task 4 handles block statics there).

- [ ] **Step 5: Green**

Run: `make -s fcc && REGEN=1 bash tests/run.sh libso_addr && grep -A3 "_libc_blk_libso_addr" tests/M42/libso_addr.expected.s | head -4; bash tests/run_reject.sh 2>&1 | tail -2; bash tests/run.sh >$SCRATCH/rs.log 2>&1; tail -1 $SCRATCH/rs.log`
Expected: `&s` is `LDA _libc_blk_libso_addr` / `CLC` / `ADC #..._s__O`; the
reject fixture passes (dies naming `n`); all fixtures pass.
Commit `feat(fcc): a block static's address is its block's plus its offset`.

### Task 6: Route every block-static shape through the lvalue walker

**Files:**
- Modify: `toolchain/src/cc/parse_expr.c` (the IDENT primary arm and the
  other `globals_lookup` sites that build variable-access nodes),
  `toolchain/src/cc/parse_stmt.c` (statement-level store/incdec/compound
  sites)
- Create: `toolchain/tests/M42/libso_shapes.c` + goldens

**Interfaces:**
- Consumes: `is_block_static` (Task 4), `emit_fpr_addr_global` (Task 5):
  an `N_LV_CHAIN` whose head has `c = -1, sym_gv = g` addresses `g` through
  `fpr_addr_sym` -> `emit_fpr_addr_global`, so every lvalue-walker node
  (`N_LV_LOAD_E`, `N_LV_STORE_E`, `N_LV_INCDEC_E`, `N_ADDR_LV_E`,
  `S_LV_STORE`, `S_LV_INCDEC`) reaches a block static by its block address.

- [ ] **Step 1: The shapes fixture (all in one, K&R shapes libc uses)**

```c
/* M42: --libso block-static shapes, each through the lvalue walker. */
struct pt { int x; int y; };
static int n;                 /* scalar */
static int arr[4];            /* array element, zero-initialised (A.8.7) */
static struct pt p;           /* struct field */
static long big = 70000L;     /* long */
static char buf[8];           /* char array, sizeof */
int sink();
int fls() { static int calls; return ++calls; }   /* function-local static */
int main()
{
    int i = 2;
    n = 3; n += 4; n++;                        /* store, op=, ++ */
    arr[i] = n; arr[i + 1] = arr[i] + 1;       /* index store/load, mixed */
    arr[i] += sink(arr[0]);                    /* op= with a call on the rhs */
    p.x = 5; p.y = p.x * 2;                    /* field store/load */
    big += 1;
    buf[sizeof(buf) - 1] = 'z';                /* sizeof is the array's */
    fls(); fls();
    return (n == 8 && arr[2] == 8 && arr[3] == 9 && p.y == 10 &&
            big == 70001L && buf[7] == 'z' && sizeof(buf) == 8 &&
            fls() == 3 && arr[0] == 0) ? 42 : 1;
}
int sink(v) int v; { return v; }
```

- [ ] **Step 2: Compile it -- it dies at the first unrouted shape**

Run: `REGEN=1 bash tests/run.sh libso_shapes; cat tests/M42/.diff.out | head -3`
Expected: FAIL at compile with Task 5's message, naming the first path
(e.g. `emit_store_global_int`).

- [ ] **Step 3: Route the IDENT primary arm**

In parse_expr.c's IDENT arm, directly after `lgv`/`gv` is resolved and before
any shape-specific branch (the long-long arm at ~3919 is the model), add:
```c
            if (lgv && is_block_static(lgv)) {
                int head = ast_new(N_LV_CHAIN, line, col);
                g_ast[head].c = -1;                /* named base: its address */
                g_ast[head].sym_lc = NULL; g_ast[head].sym_gv = lgv;
                build_lvalue_suffixes(head, lgv->type, lgv->struct_id);
                return finish_lvalue_chain(head, line, col);
            }
```
where `finish_lvalue_chain` is the tail the long-long arm and the
mid-chain-dot arm (~4170) already share for `++`/`--`, `=`, `op=`, `&` and a
plain load: factor it out of those two arms (they are the same code) rather
than writing a third copy.  An array-typed leaf decays per the existing
"array leaf" arm (K&R A.7.1); `sizeof` still reads the `Global` (A.7.4.8).

- [ ] **Step 4: Route the statement-level sites**

Re-run Step 2's command; for each site it now names, find the
`globals_lookup` that feeds it in parse_stmt.c (36 sites; start from the
statement store/incdec dispatch: `S_ARR_STORE` at :1935, the long `++` at
:998/:1810) and divert a block static into the same `N_LV_CHAIN` +
`S_LV_STORE`/`S_LV_INCDEC` path the statement walker already has.  Repeat
until `libso_shapes` compiles.  Record each diverted site in the commit body.

- [ ] **Step 5: Positive control**

Temporarily make `is_block_static` return 0 (the rewrite off): regenerate
`libso_shapes` and confirm its golden changes to label addressing
(`LDA n`-style operands) -- the fixture discriminates.  Restore; regenerate.

- [ ] **Step 6: Run the fixture on the machine and everything else**

Run: `bash tests/run.sh >$SCRATCH/rs.log 2>&1; tail -1 $SCRATCH/rs.log; cd .. && python3 toolchain/tests/run_runtime.py --names libso_calls,libso_lit,libso_addr,libso_shapes`
Expected: all fixtures pass; the runtime oracle runs the four M42 fixtures
and each exits 42 -- NOTE: they link as ordinary programs, so `_libc_blk_*`
cells hold 0 and the block templates are unplaced; for the oracle to run
them, the M42 `_seg1.link.s` must PUT a stub that points each block cell at
its template (`_libc_blk_<m> DA <m>__BT`).  Generate that stub per fixture
from the `--emit-blocks` JSON (a 20-line step in run.sh or a helper
`tests/libso/blkstub.py`); this is the static-program layout step 4 builds
properly, in miniature.
Commit `feat(fcc): library mode reaches block statics through their block`,
quoting K&R A.7.1 (array decay) and A.7.4.8 (sizeof) as the rules the rewrite
keeps.

### Task 7: All of libc compiles in library mode

**Files:**
- Modify: `toolchain/Makefile` (`lib/libc_so.s` rule), `tools/check_libc_piles.py`
  (an ARTIFACTS entry, mirroring the rule's prerequisites)
- Create: `tools/check_libso_identity.py`

- [ ] **Step 1: The Makefile rule**

After `lib/libc_c.s`'s rule, with the same prerequisite list:
```make
lib/libc_so.s: $(wildcard lib/libc_c/*.c) $(wildcard include/*.h) $(wildcard include/sys/*.h) $(wildcard include/arpa/*.h) $(wildcard include/netinet/*.h) lib/libc_c/core.list fcc
	./fcc --libso --sections --core-list lib/libc_c/core.list --emit-blocks lib/libc_so.blocks.json lib/libc_c/libc_c.c -o lib/libc_so.s --data-segment lib/libc_so_data.s
	python3 ../tools/check_libc_piles.py --write libc_so
lib/libc_so_data.s: lib/libc_so.s
libc_so: lib/libc_so.s
```
Run: `cd toolchain && make libc_so`.  Expected at first: dies at some
unrouted shape or a clash (two members' same-named statics).  Each is a Task
6-style routing (add a fixture line to `libso_shapes.c` for the shape) or a
real finding (a clash is resolved by the member's owner: rename in FGX-only
code, or record it as a divergence if it is BSD source -- stop and ask before
editing vendored BSD text).  Repeat until it compiles.

- [ ] **Step 2: Byte-identity checker**

`tools/check_libso_identity.py`: compile the umbrella twice -- `--libso` as
the rule does, and `--libso` with `FCC_LIBSO_NOBLOCKS=1` (an env switch
`is_block_static` honours, returning 0) -- then split both `.s` outputs at
`FGX_SECT`/`FGX_ENDS` into functions and assert every function whose body
names no `_libc_blk_` cell is byte-identical in both.  Self-test: two tiny
synthetic `.s` pairs, one identical, one differing in a function without
`_libc_blk_`, which must be reported.

- [ ] **Step 3: Run it**

Run: `python3 tools/check_libso_identity.py --self-test && python3 tools/check_libso_identity.py`
Expected: clean; it prints how many functions touch a block and how many are
identical.

- [ ] **Step 4: Stack check and commit**

Run: `cd toolchain && python3 ../tools/stack_check.py lib/libc_so.s`
Expected: 0 violations (the rewrite adds FPR use, not stack).
Add `make libc_so` to `piles`, and the identity check to `test-archives`.
Commit `feat(libc): libc compiles in library mode`, listing in the body how
many members have blocks, the total block bytes, the core size, and any
clash resolved.

### Task 8: Gate and record

- [ ] **Step 1:** `tools/gate.sh` -> `GATE GREEN` (fcc source changed, so the
  fixtures, the multibank sweep and the runtime oracle run).
- [ ] **Step 2:** Spec section 10: step 2 landed, with the block/core numbers
  from Task 7; ROADMAP item 6: next is step 3 (fgx_ld library output).
  Commit `docs(plans): shared libc SP2 step 2 landed`.  Record in the project notes
  (group `fgx`, `add_memory`): the flag, the sidecar format, the routing
  method, the numbers, and any clash found.
