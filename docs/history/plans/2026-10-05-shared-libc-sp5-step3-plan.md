# Shared libc SP5 step 3: sh, tcsh, vi and ac -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The three shell-sized programs leave the libc pile:
- tcsh and vi (elvis) link dynamically against libc.so (and libfgx.so, libtermlib.so where they use them);
- sh links statically with fgx_static;
- all three are FGX3;
- ac is measured and links dynamically if its own data fits, statically if not.

**Architecture:** One code-bank packer, `toolchain/src/ld/fgx_pack.py` (first-fit-decreasing by measured size, from `tools/elvis-fgx2/gen_elvis_link.py`), serves fgx_dyn and fgx_static through a new `--pack` option. Each shell's build script keeps its compile steps (signatures, commons, defines, far calls) and replaces its library selection and link with one fgx_dyn or fgx_static call. The three per-shell packers, their data-segment link files and the shape gate retire.

**Tech Stack:** Python 3 host tools (`toolchain/src/ld/`), the shells' bash build scripts (`tools/{sh,tcsh,elvis}-fgx2/`), ninja (`tools/ninja/gen.py` SHELLS), headless MAME tests (`tools/mame_test/run.py`).

**Status:** revised for an adversarial review (Fable, 2026-10-05): four Critical, ten Important and six Minor findings, all adopted.

**Spec:** [`2026-10-04-shared-libc-sp5-design.md`](2026-10-04-shared-libc-sp5-design.md), sections 6 (tcsh, vi and the overlay users dynamic; sh static; FGX3; ac) and 8 item 3.  Step 2's plan, [`2026-10-04-shared-libc-sp5-step2-plan.md`](2026-10-04-shared-libc-sp5-step2-plan.md), built `fgx_static --lib/--code-seg` and the static/dynamic branches this one uses.

## Global Constraints

- ASCII only in every file.
- 65816 assembly is written by the main agent, not delegated: an implementer who needs it stops with NEEDS_CONTEXT.
- Commit bodies are the changelog: informational, no process, no follow-ups; trailers as the session gives them.
- No push, no MR.
- Headless MAME only: `tools/mame_test/run.py`; say for every verdict whether it ran fresh.
- A test that cannot go red is not coverage: every new check states its control, and the control is run once.
- New MAME tests are probes and do not join `GATE_TESTS`.
- Nothing in spec section 7 is retired here beyond what these three links alone used (the per-shell packers, `dataseg.link.s` files and the elvis shape gate). `crt0_far.s`, the pile path, `seg3.py` and `fgx_gc` stay for step 4/5.
- Toolchain-first: a gap in fcc, libc or the linkers is fixed there, never worked around in a shell's script.
- Read the BSD counterpart before changing behaviour with one, and name it in the commit.
- Source comments describe the current state only.

## Plan rulings

- **R1. One packer in the toolchain.**
  - `fgx_pack.py` measures each TU's assembled size the way `gen_elvis_link.py`'s `measure_tu` does, with the bank's fixed overhead measured once, and packs first-fit-decreasing into the fewest banks under 64 KB.
  - Bank 0 is the bank the link already fills (crt0, runtime, inits, BANK0 for a static link).
  - fgx_dyn and fgx_static gain `--pack a.s,b.s,...`. Those TUs are packed into segment 0's remaining room, then into extra code segments, as `--code-seg` groups would be. The two options may be combined: `--code` and `--code-seg` stay explicit.
  - Each extra segment's overhead is its runtime: thunked in fgx_dyn, the whole `fcc_runtime.s` in fgx_static.
  - No reserve: measured, tcsh's 40 TUs (413,815 bytes) pack into 7 code banks with about 18 KB free in the last, where `with_tables` puts the tables (it picks the roomiest code segment). The pile link needed backtracking (`gen_tcsh_link.py:119`) only because of the 6,570-byte termlib pile and the whole runtimes; libtermlib.so is what makes plain first-fit-decreasing suffice. The cap is enforced by `with_tables`, whose off-by-one Task 1 fixes.
- The per-bank overhead is the thunked runtime with `roots=None`, the full set: an upper bound of about 3.6 KB, since the real per-bank runtime (`thunked_runtime(far, roots)`, `fgx_dyn.py:280-281`) is smaller.
- Measuring needs `seg1_layout.s` and `imports_layout.s`, which `link_once` writes before it assembles segment 0, while the packed groups are `link_once`'s input (`extra`). Task 1 splits `link_once` into the data half (segment 1 and the layouts) and the code half, and packs between them.
- fgx_static's extra segments carry `fcc_runtime.s`, not BANK0 (libllong, `d_stub.s`). No shell TU references a BANK0-only label (sh calls only `_fcc_divs16`/`_fcc_divu16`, in `fcc_runtime.s`). A packed TU that does fails loudly at assembly, so no packer rule is needed.
  - The three `gen_*_link.py` packers retire.
  - Cost if wrong: a fourth packer later.
- **R2. The shells' compiles do not change.** Each keeps its signature passes, `--commons`, defines and far-call mode:
  - sh: `--sigs sh.sigs`;
  - tcsh: `-Dpdp11 $TCDEFS --sigs gen/tcsh.sigs`;
  - elvis: one-mode far.

  What goes:
  - step 1b, `seg3.py`'s libc selection;
  - step 1c, `fgx_gc`'s collection;
  - steps 3-6: the data segment, packing, assembly and `fgx_ld`;
  - elvis's step 6 shape gate.

  Tentative definitions and the library's data:
  - **Dynamic (tcsh, vi):** fgx_dyn's segment 1 is `fcc_runtime_data.s`, `crt0_lib_data.s`, the program's data and `dyn.data.s` (`fgx_dyn.py:255-260`), and `split_data` (`:173-194`) already drops a `name DS n` tentative of a library export (vi's `UP`/`BC`/`PC`/`ospeed`). gen_commons runs with `--extern-defs toolchain/lib/fcc_runtime_data.s` only.
  - **Static (sh):** `--extern-defs` over exactly what fgx_static assembles in segment 1: `fgx_libso.DATA` (`libc_data.s`, `args_data.s`, `fcc_runtime_data.s`, `libc_start_data.s`, the `ll_*.data.s`) and `crt0_lib_data.s`. Not `libc_so_data.s` or libfgx's data, which fgx_static prunes: a tentative yielding to a pruned datum would leave an undefined label (`build_bsh.sh:142-144` states this hazard). sh's `errno`/`environ` tentatives yield to `libc_data.s`/`args_data.s` this way.
- **R3. Link modes.**
  - tcsh: `fgx_dyn --lib libc,libfgx`.
  - vi: `fgx_dyn --lib libc,libfgx,libtermlib`. fgx_dyn drops a library a shell does not reference (step 2, operand identifiers).
  - sh: `fgx_static --lib build/static_libs/libfgx.s,build/static_libs/libfgx.data.s`, as the static set links. sh is the console shell and the recovery shell when libc.so will not load (spec 6.1).
  - The outputs keep their paths (`tools/{sh,tcsh,elvis}-fgx2/*.bin`), so staging does not move.
- **R4. A libc export a shell defines is a finding, not a warning to live with.** fgx_dyn warns "defines X, which libc exports" and binds the shell's own references to its own copy and libc's internal ones to libc's. Two copies of a stateful libc object, `malloc` above all (tcsh's `tc.alloc.c`), would split the heap. Every such warning on the three shells is resolved in its task: by the BSD source's own configuration (e.g. tcsh's `SYSMALLOC`, see `config_f.h`), or by making the program use libc's. The task's report lists the warnings: none, or each resolved. Known now, and ruled here:
  - **vi** (`src/userland/elvis/system.c`): `geteuid` (:103), `sleep` (:104), `sync` (:105), `getwd` (:206) and `index` (:214) are FGX stubs from before libc had them (`getwd` always answers `/`). They are deleted, and elvis uses libc's. libc itself calls `index` (3 sites) and `sleep` (1).
  - **`access`** (`system.c:86`) stays. It is elvis's wrapper that installs the FGX key maps on first use (`build_elvis.sh:56-58`). Under fgx_dyn elvis's references bind to it and libc's to libc's, which is what the wrapper needs.
  - **tcsh's `strstr`** (`sh.misc.c:172`, under `#ifndef POSIX`) stays. It has the same semantics, libc has no internal caller of it, and defining POSIX would change far more of tcsh.
  - **tcsh's malloc:** `config_f.h:118` `#define SYSMALLOC`, and the compiled `tc.alloc` defines no `malloc`/`free`/`realloc`/`calloc`: tcsh uses libc's.
  - **sh** links statically, where Task 1's shadowing applies: `malloc`, `free`, `rename` and `setenv` are sh's own, as in 2.11BSD.
- **R5. ac.** The `"pile": true` key goes. If fgx_dyn links ac, so its data fits below libc's core less its blocks and `struct ld_work`, ac is dynamic. If fgx_dyn refuses it with its fit message, ac takes `"static": true`. Either way `TSIZE` stays 6242 (spec 6). Its test's description and `ac.c`'s line-name comment are corrected (spec 6).

## Review Focus

1. **tcsh at the segment cap.** Seven code banks plus data is eight segments, the cap for a binary with no LIBC segment (`fgx_ld.py:913-914`), so the binder tables must land in a code bank. They are estimated at 6-9 KB (spec section 3). Measured, the last bank keeps about 18 KB free (R1). A regression shows as fgx_dyn's "no code segment has room", now a refusal at 8 segments rather than a silent 9th (Task 1). Pinned by Task 3's link and its summary line.
2. **sh's signal and soft-SCC paths in a static image.**
   - sh is FCC_SOFT_SCC (`src/softscc/sh.txt`); this is the first static link that uses the static branch's softscc plumbing.
   - Its signal trampoline must still reach a catcher: `signal(i, 1)` is the defect its signature pass exists for.
   - Pinned by `softexec`, `softfork` and `trapquiet` in the gate, and by Task 4's probe list.
3. **The console shell with libc.so unloadable.** sh is now static, so rcnolibc's recovery shell is genuinely static. Pinned by `rcnolibc` in Task 4, whose description is rewritten.
4. **A shell's own definitions of libc exports (R4)**, malloc first. Pinned by each task's link log, read for warnings, and by `tcstatic` and `tccomp` (tcsh) and `ufsvi` (vi).
5. **vi's terminal capabilities through libtermlib.so** (the baked "fgx" entry). Pinned by `ufsvi` in Task 2.

---

### Task 1: One packer, and `--pack` in fgx_dyn and fgx_static

**Files:**
- Create: `toolchain/src/ld/fgx_pack.py`
- Modify: `toolchain/src/ld/fgx_dyn.py` (`--pack`, the `link_once` split, the `with_tables` cap, `end`, `--stack-pad`, in `build`/`link_once`/`main`)
- Modify: `toolchain/src/ld/fgx_static.py` (`--pack`, in `build`/`parser`)
- Test: `toolchain/src/ld/fgx_pack.py --self-test`; `toolchain/tests/dyn/test_dyn.py` (`packed()`); `fgx_static.py --self-test`

**Interfaces:**
- Produces:
  - `fgx_pack.pack(sizes: dict[str, int], room0: int, cap: int, per_bank: int) -> list[list[str]]`. Returns the TU groups: the first group goes into segment 0's remaining `room0`, each later group into one extra bank whose overhead is `per_bank`. Packing is first-fit-decreasing, ties broken by name, so the result is deterministic. It dies naming the TU when a single TU exceeds `cap - per_bank`.
  - `fgx_pack.measure(tu: str, link_dir: str, puts: list[str]) -> int` assembles one TU with the given layout files and returns its byte size. It is ported from `gen_elvis_link.py`'s `measure_tu`.
  - fgx_dyn CLI: `--pack a.s,b.s,...` (repeatable lists are joined).
  - fgx_static CLI: `--pack a.s,b.s,...`.

- [ ] **Step 1: Write the failing self-test.**  In the new `fgx_pack.py`, write `self_test()` and the `--self-test` entry point first, with only stub functions, so the test runs and fails:

```python
def self_test():
    # first-fit-decreasing: a (40000) does not fit bank 0's 35000 and opens
    # bank 1 (63536); b fits bank 0; c fits bank 1's 23536 left; d fits
    # neither bank 0's 5000 nor bank 1's 3536 and opens bank 2.
    g = pack({"a": 40000, "b": 30000, "c": 20000, "d": 10000}, room0=35000,
             cap=65536, per_bank=2000)
    assert g == [["b"], ["a", "c"], ["d"]], g
    assert pack({"x": 100}, 50, 65536, 2000) == [[], ["x"]]     # nothing fits bank 0
    try:
        pack({"huge": 70000}, 0, 65536, 2000)
    except SystemExit as e:
        assert "huge" in str(e)
    else:
        raise AssertionError("an oversized TU must be refused by name")
    print("fgx_pack: self-test OK")
```

- [ ] **Step 2: Run it.**

Run: `python3 toolchain/src/ld/fgx_pack.py --self-test`
Expected: an AssertionError from the stubs.

- [ ] **Step 3: Implement `pack` and `measure`.**
  - `pack` is first-fit-decreasing over `sorted(sizes, key=lambda t: (-sizes[t], t))`. The bins are `[room0] + [cap - per_bank] * k`, growing `k` as needed.
  - `measure` is `gen_elvis_link.py`'s `measure_tu`, generalized to take the PUT list.
  - Self-test again: `fgx_pack: self-test OK`.
- [ ] **Step 4: Wire `--pack` into fgx_dyn.**
  - Each `--pack` TU is measured against a link directory holding the program's `seg1_layout.s` and `imports_layout.s`; `link_once` already writes both before segment 0 assembles.
  - Segment 0's room is 65536 minus the assembled size of segment 0 without the packed TUs.
  - The per-bank overhead is the thunked runtime's size, measured once.
  - The groups become segment 0's extra files plus `extra` code segments.
  - `link_once` is split as R1 says: data half, pack, code half.
  - **The segment cap, a defect fixed here:** `with_tables` refuses only at `n >= 9` (`fgx_dyn.py:335`), so an 8-segment image with no room gets a 9th CODE segment, which `fgx_ld` forbids ("a 9-segment binary must end with the LIBC segment", `fgx_ld.py:913-914`). Change it to `n >= 8`, with a test_dyn case: an image of 8 segments whose code banks are full must be refused by name.

  Write the failing host test first: `packed()` in test_dyn.py links `hello.c` plus three hand-written filler files, `fill1.s` to `fill3.s` in `toolchain/tests/dyn/` (each `fillN ENT`, `DS 40000`, `RTL`), all through `--pack`. It expects segment kinds `[0, 1, 0, 0]` or more code segments, as `multi()` checks (`test_dyn.py:352-378`), and that `imps()` succeeds. Red without `--pack` is fgx_dyn's "segment 0 is over 64 KB" (`fgx_dyn.py:272`), with the fillers given as `--code`.
- [ ] **Step 5: Wire `--pack` into fgx_static.**
  - Same shape. Segment 0's fixed overhead is crt0, the runtime, BANK0 and inits; each extra bank's overhead is the whole `fcc_runtime.s`.
  - The libc bank count follows step 2's rule (`6 - len(extra)`).
  - Write the self-test assertion first, that the parser has `--pack`, run it red, then implement.
- [ ] **Step 5b: `end`, the linker's symbol.**  2.11BSD's ld defines `_end` after the program's bss (`vendor/2.11BSD/usr/bin/ld/ld.c:1003,1029`, `p_end = slookup("_end")`, `ldrsym(p_end, bsize, N_EXT+N_BSS)`). sh uses it as the base of its arena: `blok.c:27` `bloktop=BLK(end)`, `defs.h:289` `address end[]`, compiled `LDA #end`. Today only sh's `dataseg.link.s` defines it (`DS 0-*&3` / `end ANOP`, 4-aligned, because `blok.c` keeps BUSY in bit 0), and Task 4 deletes that file. fgx_static and fgx_dyn define `end` after the last data file in segment 1, aligned to 4. A program that already defines `end` keeps its own. Test first: fgx_static's self-test (or a test_dyn case) asserts that the data listing defines `end` at a multiple of 4 at or past the last data label. Red, then green.
- [ ] **Step 5c: `--stack-pad`.**  `fgx_ld` reads a manifest `stack_pad` (`fgx_ld.py:938`, default `stack_measure.DEFAULT_PAD`, 128). sh's pile link passes 2304 (`gen_sh_link.py:218`), sized so the stack guard fires before the stak arena is truncated (`gate.sh:405-409`; `srcdepth_loud` is a gate test). fgx_static and fgx_dyn gain `--stack-pad BYTES` and write it into the manifest. Repoint the comments at `fgx_ld.py:160` and `check_data_budget.py:123` that cite `gen_sh_link.py`. Test: the parser assertion, then a link whose `static.json`/`dyn.json` carries the value.
- [ ] **Step 5d: a program's definition shadows the library's section, as an archive search does.**  sh defines `malloc` and `free` (blok.c), `rename` (io.c:81, its own fd-dup routine, not libc's) and `setenv` (name.c). `fgx_gc.graph` deduplicates only among PRUNED files (`fgx_gc.py:215-256`). So sh's references pull libc_so.s's `malloc` section live too, and `fgx_ld` dies "symbol 'malloc' defined by multiple segments" (`fgx_ld.py:664-668`). 2.11BSD links sh against libc.a, and ld searches the archive only for names still undefined after the object files, so sh's `malloc` is THE malloc and libc's own callers (10 `malloc` and 5 `free` sites in libc_so.s) bind to it. Make `fgx_gc.graph` give a label defined by a ROOT code file precedence over a pruned section of the same name: that section is not an owner, so it is never live, and libc's references bind to the program's label. Self-test first in `fgx_gc.py`: a program defining `strtok` beside a pruned file with a `strtok` section yields no live library `strtok` and no duplicate. Red, then green.
- [ ] **Step 6: Run the host suite.**

Run: `python3 toolchain/src/ld/fgx_pack.py --self-test && (cd toolchain && python3 tests/dyn/test_dyn.py) && python3 toolchain/src/ld/fgx_static.py --self-test && make -C toolchain test-archives`
Expected: all OK; `0 FAIL`.

- [ ] **Step 7: Commit** (one commit per step group if cleaner).  Body: the packer, ported from gen_elvis_link.py (name it); first-fit-decreasing; `--pack` in both linkers; the 8-segment cap fix; `end` (quote ld.c); `--stack-pad`; the archive-search shadowing (quote the BSD ld behaviour).

---

### Task 2: vi (elvis) links dynamically

**Files:**
- Modify: `tools/elvis-fgx2/build_elvis.sh`: keep step 1, the compile; replace steps 1b-6 with gen_commons plus one fgx_dyn call.
- Delete: `tools/elvis-fgx2/gen_elvis_link.py`, `tools/elvis-fgx2/dataseg.link.s`, and any `seg*.link.s.in` the script alone used.
- Modify: `tools/ninja/gen.py`, SHELLS `elvis`: `links`/`extra` follow (gen_commons, DYN_INPUTS); drop the deleted files.
- Modify: `src/userland/elvis/system.c` (R4: the five stubs go).
- Create: `tools/mame_test/tests/dynshells.json`, `toolchain/tests/dyn/test_shells.py`.
- `tools/check_argv_caps.py` needs no edit: it discovers git-tracked files (`:35-46`).

**Interfaces:**
- Consumes: Task 1's `fgx_dyn --pack`.
- Produces: `tools/elvis-fgx2/elvis.bin` as a dynamic FGX3 program.

- [ ] **Step 1: The failing check.**  dyntools' screen is nearly full (24 rows), so the shells get their own probe. Create `tools/mame_test/tests/dynshells.json`: command `/bin/ldd /bin/vi /bin/tcsh`; screen_contains `"/bin/vi:"`, `"-lc.1 => /lib/libc.so.1.0"`, `"-ltermlib.1 => /lib/libtermlib.so.1.0"`; screen_lacks `"statically linked"`, `"-lfgx.1"` (neither shell references a libfgx export), `"PANIC"`, `"BRK"`. Its description names the control: before this task, vi's ldd answer is `statically linked`. Create `toolchain/tests/dyn/test_shells.py` (test_dyn's `check()` harness; one function per shell, run by name as an argument, all with none) and its vi check: magic `FGX3`, the dynamic flag set. Run `python3 tools/mame_test/run.py --fresh dynshells` and `python3 toolchain/tests/dyn/test_shells.py vi`: Expected FAIL. dynshells is not a gate test.
- [ ] **Step 2: Rewrite the link.**
  - After step 1's compile, `gen_commons.py` writes `commons.data.s` with `--extern-defs` over the R2 list.
  - Then: `fgx_dyn.py --name elvis --dir dyn.ld --code main.code.s --pack <every other TU's .code.s> --data <every TU's .data.s>,commons.data.s --lib libc,libfgx,libtermlib --out elvis.bin`.
  - Delete the script's steps 1b, 1c and 2-6, the packer and the shape gate.
  - Keep the compile's far-call mode.
  - The script `tee`s fgx_dyn's output to `tools/elvis-fgx2/link.log`. The ninja `shellbuild` rule sends a script's stdout to /dev/null on success (`gen.py:1112`), so that file is where the link's summary and warnings are read.
  - Delete the five stubs R4 names from `src/userland/elvis/system.c`.
  - `rm -f` the retired outputs in `tools/elvis-fgx2/` (seg[0-9]*, *.lst, *.json, _m_*, _ov_*, dataseg*, libc.sel*, llong.sel*, double.sel*, libfgx*.gc.s). They are gitignored and would otherwise feed `helper_census.py` (which reads `tools/*-fgx2/*.json`) stale.
- [ ] **Step 3: Build and read the link.**  Announce the rebuild (main checkout, feat/shared-libc).

Run: `ninja 2>&1 | tail -5; cat tools/elvis-fgx2/link.log; head -c 4 tools/elvis-fgx2/elvis.bin`
Expected: `FGX3`; one `dyn elvis: seg0 ... imports` summary; no "defines X, which libc exports" warning, or each one resolved per R4 and listed in the report.

- [ ] **Step 4: Probes and gate.**

Run: `python3 tools/mame_test/run.py --fresh ufsvi && python3 toolchain/tests/dyn/test_shells.py vi && tools/gate.sh`
Expected: ufsvi and test_shells vi pass; gate green. dynshells stays red until Task 3 adds tcsh.

- [ ] **Step 5: Commit.**  Body: vi is dynamic against libc, libfgx (if kept) and libtermlib; the packer, the data-segment link and the shape gate retire; the R4 warnings, or none.

---

### Task 3: tcsh links dynamically

**Files:**
- Modify: `tools/tcsh-fgx2/build_tcsh_link.sh`: keep step 1, the compile with `-Dpdp11 $TCDEFS --sigs`; replace steps 1b-6.
- Delete: `tools/tcsh-fgx2/gen_tcsh_link.py`, `tools/tcsh-fgx2/dataseg.link.s`.
- Modify: `tools/ninja/gen.py`, SHELLS `tcsh`.
- Modify: `tools/mame_test/tests/dynshells.json` and `toolchain/tests/dyn/test_shells.py` (tcsh).

**Interfaces:**
- Consumes: Task 1's `--pack` and the 8-segment refusal.
- Produces: `tools/tcsh-fgx2/tcsh.bin`, dynamic FGX3.

- [ ] **Step 1: The failing check.**  Add `"/bin/tcsh:"` to dynshells' screen_contains and a tcsh function to `test_shells.py`. Run `dynshells` fresh and `test_shells.py tcsh`: Expected FAIL (tcsh `statically linked`, `FGX2`).
- [ ] **Step 2: R4 before the link.**  Confirm R4's tcsh findings from the compiled `tc.alloc.code.s` (no `malloc`/`free`/`realloc`/`calloc` label) and expect exactly one fgx_dyn warning, `strstr`, which R4 rules acceptable.
- [ ] **Step 3: Rewrite the link** as in Task 2:
  - `--lib libc,libfgx`;
  - `--code` is `sh.code.s` (main); no bank constraint applies, since crt0 reaches `main` by `FGX2_FARCALL` (`crt0_lib.s:44`);
  - `--pack` is the rest;
  - data is every `.data.s` plus `commons.data.s` from gen_commons over the R2 list;
  - output `tee`d to `tools/tcsh-fgx2/link.log`, and the retired outputs removed, as in Task 2.
- [ ] **Step 4: Build and read the link.**  Announce the rebuild.

Run: `ninja 2>&1 | tail -5; cat tools/tcsh-fgx2/link.log; head -c 4 tools/tcsh-fgx2/tcsh.bin`
Expected: `FGX3`; at most 8 segments (Review Focus 1); only the `strstr` warning. If fgx_dyn refuses with "no code segment has room", the measurement in R1 was wrong: report it with the per-bank sizes; do not hand-place TUs.

- [ ] **Step 5: Probes and gate.**

Run: `python3 tools/mame_test/run.py --fresh dynshells tcstatic tccomp stkdefer stkover && python3 toolchain/tests/dyn/test_shells.py && tools/gate.sh`
Expected: all pass; gate green.

- [ ] **Step 6: Commit.**  Body: tcsh dynamic, its segment count and table placement, the malloc finding.

---

### Task 4: sh links statically

**Files:**
- Modify: `tools/sh-fgx2/build_bsh.sh`: keep steps 0 and 1 (the signatures and the compile); replace 1b-6 with gen_commons plus one fgx_static call.
- Delete: `tools/sh-fgx2/gen_sh_link.py`, `tools/sh-fgx2/dataseg.link.s`.
- Modify: `tools/ninja/gen.py`, SHELLS `bsh`: inputs follow STATIC_INPUTS. Keep FCC_SOFT_SCC from `src/softscc/sh.txt`, which the ninja edge's environment carries.
- Modify: `disk_src/etc/rc.in`: the boot comment's "sh, a pile program until step 3, needs no libc.so either" becomes sh in the static set.
- Modify: `tools/mame_test/tests/rcnolibc.json`: its description says the console sh is static.
- Modify: `tools/check_data_budget.py`. It reads `tools/<b>-fgx2/dataseg_layout.s` (`:59-63`) and silently skips a binary without one (`:113-114`), so its sh ceiling check (`:126-128`) would go vacuous, or read a stale gitignored copy. Point it at `static.ld/seg1_layout.s` (static) or `dyn.ld/seg1_layout.s` (dynamic). A check that finds no layout for a binary it names fails.
- Modify: `toolchain/tests/dyn/test_shells.py` (sh).

**Interfaces:**
- Consumes: Task 1's `fgx_static --pack`; step 2's `build/static_libs/libfgx.{s,data.s}`.
- Produces: `tools/sh-fgx2/sh.bin`, static FGX3.

- [ ] **Step 1: The failing check, on the host.**  ldd cannot tell a pile image from a static one: both lack the dynamic flag, so both print `statically linked` (`ldd.c:56-57`). The discriminator is the image. Add an sh function to `test_shells.py`: magic `FGX3`, no segment of the LIBC kind (via `fgx_bind.parse`), the dynamic flag clear. Run `test_shells.py sh`: Expected FAIL (`FGX2`, a LIBC segment).
- [ ] **Step 2: Rewrite the link.**
  - gen_commons over R2's static list: `libc_so_data.s`, `libfgx` program-mode data, `fcc_runtime_data.s`, `libc_data.s`, `args_data.s`.
  - Then: `fgx_static.py --name sh --dir static.ld --code main.code.s --pack <the other 19 TUs' .code.s> --lib $REPO/build/static_libs/libfgx.s,$REPO/build/static_libs/libfgx.data.s --data <every .data.s>,commons.data.s --out sh.bin`.
  - Pass `--stack-pad 2304` (Task 1), with the reason in the script: the guard must fire before the stak arena is truncated.
  - `end` now comes from fgx_static (Task 1).
  - Output is `tee`d to `tools/sh-fgx2/link.log`, and the retired outputs are removed, as in Task 2.
  - Keep a hand run of the script working with the soft-SCC environment: memory "a hand run of build_bsh.sh skips ninja's FCC_SOFT_SCC". The script says so in its header and checks that the variable is set when `src/softscc/sh.txt` exists.
- [ ] **Step 3: Build and read the link.**  Announce the rebuild.

Run: `ninja 2>&1 | tail -5; cat tools/sh-fgx2/link.log; python3 toolchain/tests/dyn/test_shells.py sh`
Expected: a `static sh:` summary; at most 8 segments; test_shells sh passes; `check_soft_exile.py` (gate) still finds sh's soft-SCC code.

- [ ] **Step 4: Probes and gate.**

Run: `python3 tools/mame_test/run.py --fresh rcnolibc softexec softfork trapquiet srcdepth_loud && tools/gate.sh`
Expected: all pass; gate green.

- [ ] **Step 5: Commit.**  Body: sh static, the recovery shell genuinely static now, the soft-SCC environment kept, its packer retired.

---

### Task 5: ac measured (R5)

**Files:**
- Modify: `tools/ninja/manifest.json` (ac: drop `"pile": true`; add `"static": true` only if the measurement says so)
- Modify: `tools/mame_test/tests/ac.json` (description: one FGX delta, as `src/userland/ac/ac.c:18` declares)
- Modify: `src/userland/ac/ac.c:28-29`: the lines FGX writes are console, ttyv1-3 and ttyp0-1 (`init.c` from `/etc/ttys`; `login.c`). They index from 5,056 (`ttyp0`) to 5,533 (`ttyv3`) under 2.11BSD's `ut_line[3] * 79 + ut_line[4]` (`vendor/2.11BSD/usr/usr.sbin/ac/ac.c:136-161`), all inside `TSIZE` 6242.

- [ ] **Step 1: Measure.**  Drop `"pile": true`. Announce the rebuild, then run `ninja 2>&1 | grep -a -A3 'ac' | head`. Then:
  - Read `bin/ac.bin.log`, which the dynlink rule writes.
  - If fgx_dyn links ac: record its `dyn ac: ... data N bytes, LIM $XXXX` line. ac stays dynamic.
  - If fgx_dyn refuses with its fit message (`ac's data ends at $XXXX, above LIM $XXXX (cores from $F6A3, N bytes of blocks)`, or `...: the binder's 294 bytes of scratch need it below $XXXX`; `fgx_dyn.py:398-404`): record the numbers, add `"static": true`, rebuild, and record the `static ac:` line from the same log.
- [ ] **Step 2: Correct the claims.**  Fix the ac.json description and the ac.c comment as Files says. Read the vendor ac.c lines first and quote the index expression in the commit.
- [ ] **Step 3: Probes and gate.**

Run: `python3 tools/mame_test/run.py --fresh ac && tools/gate.sh`
Expected: pass; gate green.

- [ ] **Step 4: Commit.**  Body: the measurement (bytes against LIM), the link mode it decided, and the corrected claims with the 2.11BSD index expression.

---

### Task 6: ROADMAP

**Files:**
- Modify: `docs/ROADMAP.md`, the shared libc SP5 paragraph (find "Sub-project 5").

- [ ] **Step 1:** Step 3 landed: tcsh and vi dynamic, sh static, all FGX3, and ac's mode with its numbers. The packer is one module. Next: step 4 (the toolchain fixtures off `crt0_far.s`), then step 5 (retire the pile path).
- [ ] **Step 2: Commit** (docs only, no gate).

## Self-review

- **Spec coverage:** section 6's tcsh/vi dynamic is Tasks 2-3; sh static is Task 4; FGX3 comes from the linkers; ac and its corrected claims are Task 5. The overlay users and fas were step 2. Section 8 item 3 is the whole plan.
- **Interfaces:** `pack()`/`measure()` and the two `--pack` options (Task 1) are consumed by Tasks 2-4. `end`, `--stack-pad` and the archive-search shadowing (Task 1) are consumed by sh (Task 4); the 8-segment refusal guards tcsh (Task 3).
- **Review Focus:** each line names its probe and owning task.
