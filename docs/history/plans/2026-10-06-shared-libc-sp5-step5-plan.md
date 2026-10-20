# Shared libc SP5 step 5: retire the pile path -- Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** remove the per-program libc piles and everything that serves them from the build, the toolchain and the kernel, one area per commit, with the branch booting after every commit:
- **build:** gen.py's pile branch and its rules and helpers, `tools/stage_piles.py`, the `tools/fgx2/` templates, `tools/ninja/seg3.py`, the `shell_deps` pile floor, `lib/build_common.sh`'s pile build, and `util.fgxa`;
- **toolchain:** fgx_ld's LIBC and LIBCREF kinds, `fgx_gc.run()` and `--overlay`, and `crt0_far.s`;
- **kernel:** the far-bank pile path and registry arm, the core-bank registry, its reference counts and `TCB_LibcBank`, and the tty bank's `TX_PILE`.

**Architecture:** deletion, ordered so that each commit leaves a consistent system.
- Host side first, since nothing staged uses it.
- Then the kernel in three commits:
  - **K1, far bank:** the loader stops recognising pile segments and refuses unknown kinds. The core and tty sides still read the cells, which now always hold zero.
  - **K2, core bank:** the registry, the reference counts and `TCB_LibcBank` go, and Bank_Alloc's dry-pool chain calls `KTTY_LD_RECLAIM` directly. The tty bank's `_Tx_PileAdj` goes in the same commit, because it reads the registry through `include/memmap.s`, which the tty bank PUTs (`ttybank.s:50`).
  - **K3, tty bank:** `TX_PILE` goes from the entry layout, and with it the ninth byte of `KTTY_TEXT_REG`'s list.
- Every kernel commit regenerates the committed bank-patch tables. The build only `--check`s them (the `kchecks` rule); they are written by the same four `tools/gen_far_bankpatch.py` commands without `--check`.
- Last, the tests' descriptions, the docs, and the verification.

**Tech Stack:** Python 3 host tools, ninja (`tools/ninja/gen.py`), bash build scripts, Merlin32 65816 assembly (kernel core, far and tty banks), headless MAME through `tools/mame_test/run.py`.

**Spec:** [`2026-10-04-shared-libc-sp5-design.md`](2026-10-04-shared-libc-sp5-design.md), section 7 (what retires) and section 8 item 5. Step 3's RESUME carries the gen_commons item (Task 2b).

**Status:** revised for an adversarial review (Fable, 2026-10-06): one Critical, six Important, fifteen Minor findings. All are adopted except M6. Task 2b stays, because step 3's RESUME carried it into step 5. Fixes, by finding:
- **C1** `_Tx_PileAdj` moves into K2.
- **I1** each kernel commit regenerates the bank-patch tables.
- **I2** Task 1 edits gen.py:2214 and the fgxufs.po edge.
- **I3** the execkind oracle is ldd's.
- **I4** manyproc gets a HEAD baseline; no claim that K1 turns it green.
- **I5** the reclaim arm is checked by reading.
- **I6** the omissions are added to Tasks 1, 3 and 7.

## Starting state (measured 2026-10-06, HEAD 7f8316db9)

- **Nothing staged carries a LIBC or LIBCREF segment.**
  - A scan of the segment tables of all 414 FGX binaries under `disk_src`, `bin` and `build/stage` (scratchpad `pilescan.py`, Task 0) found kind 3/4 only in `bin/devttyx.bin` and `bin/rdrestart.bin`.
  - Both are September build leftovers: no edge builds them and neither is staged.
  - `disk_src/lib` holds only the five `.so.1.0` libraries; no `libc.so.<key>` pile is staged.
- **gen.py's pile branch is unreachable.** No manifest tool sets `pile` (193 tools: 13 static, the rest dynamic).
  - So `emit()`'s pile branch (gen.py:2550-2721) never runs. That covers `materialize_links()` (:656-783), `archive_deps()` (:893-907), `GC_PUTS`/`GC_PRUNE`/`GC_MODE` (:635-644), `LIBC_SEED_ROOTS`, `MEMBER_DIR` and `PILE_CARRIES_OWN`.
  - The rules `fgxgc`, `seg3sel`, `fgxld` and `seg1layout` have no edges outside it.
  - The `stagepiles` edge (:2935-2941) runs on every build and stages nothing.
  - `direct_link_edges()` reads `seg3_tus`/`seg4_tus` itself (:573-583), so those stay. Only `libc_overlay` is pile-only.
- **Bank fill** (`tools/check_kernel_ceiling.py`): kernel 55,999 of 57,168 B (1,169 free), far 60,461 of 60,480 (19 free), tty 64,311 of 65,280 (969 free).
- **The far loader's pile path** (`src/kernel/far/loader.s`):
  - state `:44-95`;
  - `_Ld_PileOpen`/`_Ld_PileClose`/`_Ld_PileHexDigits`/`_Ld_PileNib` `:287-435`;
  - the LIBC/LIBCREF arm of the segment loop `:1095-1380`. Its `@lf2_skipBytes` is shared with a loaded text's code segments and stays.
  - text registration `:1505-1570` (`_ldTextList+8`);
  - the extras blanking `:1578-1597`;
  - `_FreeExtras`'s refcount rollback `:1872-1920`;
  - per-load zeroing `:597-599`.
- `_ldLibcSeg` is a pinned loader output (`far.s:837`, `KFAR_LD_LIBCSEG` = `KFAR_LD_OUTPUTS+13`, `include/kfar.s:442`), read by the core at `main.s:950` and `process.s:206, 3143, 3389`.
- **The core bank:**
  - `_libcShTab`/`_libcShLast` (`include/memmap.s:426-455`, 129 B) and `_ldPileCorePath` (`:1541-1555`, 32 B);
  - `_LibcSh_Slot` (`process.s:1290-1320`);
  - refcount sites: `process.s:1040-1050, 1098-1108, 3138-3153, 3385-3397`, `task.s:355-380`, `main.s:948-953`, `process.s:200-209`;
  - `_LibcSh_Reclaim` (`bank.s:196-234`), called at `bank.s:154`;
  - `TCB_LibcBank` (`include/kernel.s:624`). It was `TCB_Reserved1`, an alignment byte; the TCB is pinned at 64 B by an `ERR`.
  - The 16-bit pair accesses `TCB_DataBank` + `TCB_LibcBank` at `process.s:710, 787, 2999, 3457` copy the byte beside DataBank, which K2 leaves zero.
- **The tty bank:**
  - `text.s`: `TX_PILE` at entry offset 16, `TX_COUNT` 17, `TX_STAMP` 18, `TX_SIZE` 20. `_Tx_Off` multiplies by 16+4.
  - `_Tx_PileAdj` (`:106-136`) and its calls at `:181-183` and `:362-364`.
  - `KTTY_TEXT_REG` copies a 9-byte list as 10 bytes (`:345-357`), with banks 0-7 and the pile in [8].
- **The format cap.** `FGX2_MAX_SEGS` is 9 (`include/loader.s:87`); its comment says 9 exists only because the ninth segment is the pile, which rides `TCB_LibcBank`. fgx_ld enforces "a 9-segment binary ends with LIBC" (`fgx_ld.py:905-916`).
  - `TCB_BankList` has 8 rows. Without the LIBC rule, a ninth CODE segment would load into a bank that exit never frees.
  - fgx_static already refuses more than 8 segments (`fgx_static.py:313`), and fgx_dyn refuses 9 (step 3).
- **`tools/check_libc_piles.py` is not pile-only.** It is the freshness guard for `libc_so.s` (libc.so's source), `libfgx.s`, `libcurses.s`, `libtermlib.s` and the `.fgxa` archives against their sources and fcc (its docstring, `ARTIFACTS`). Spec section 7 lists it for removal; that is wrong (ruling R2).
- **`lib/build_common.sh`'s `build_userbin_fgx2_c`** (`:483-759`) is a second, complete pile build. Its one live caller is `tools/profile/run_profile.sh:56`, which therefore profiles a pile-linked sed that is not the dynamic `bin/sed.bin` the system ships.

## Global Constraints

- ASCII only in every file.
- 65816 assembly is written by the main agent, never delegated. Tasks 4-6 are the main agent's.
- One area per commit, as spec section 8 item 5 says.
  - Before each commit, Task 0's scan runs again and must report no kind 3/4 in `disk_src`.
  - The branch builds and boots (`ninja all`, plus the boot MAME test) after each kernel commit.
- Commit bodies are the changelog: informational, no process, no follow-ups. Trailers as the session gives them.
- No push, no MR.
- Never run `git clean`. Never `git checkout` a tracked generated file (`kernel_exports.s`); ninja regenerates it.
- Headless MAME only, through `tools/mame_test/run.py`. Never a raw `mame64`, never `--debug`. Say for every MAME verdict whether it ran fresh or from cache.
- Source comments describe the current state only. History goes in the commit body.
- New MAME tests are probes and do not join `GATE_TESTS`.
- Toolchain-first: a gap found is fixed in fcc, libc or the linkers.
- Kernel commits name their BSD counterpart where there is one. The loader's refusal of an unknown segment kind is 2.11BSD `exec`'s ENOEXEC for a bad magic (`vendor/2.11BSD/usr/sys/sys/kern_exec.c`, read and quoted in Task 4's commit). The rest is FGX-only mechanism with no counterpart, and its commits say so.

## Plan rulings

- **R1. `FGX2_MAX_SEGS` goes back to 8, and fgx_ld's cap with it.**
  - Spec section 4.1 says "the ninth slot is free for code" once LIBC retires. But a ninth code segment needs a ninth `TCB_BankList` row, and the TCB is a full 64 bytes. Without the LIBC-only rule, nothing would stop a ninth segment that leaks its bank at exit.
  - `include/loader.s`, `fgx_ld.py` `MAX_SEGS` and the loader's 9-byte arrays (`_ldExtraBanks`, `_ldTextList`) become 8. The far bank gains the segment table's ninth entry (8 B).
  - Recorded as a divergence in spec section 9. Cost if wrong: a 9-segment program needs the TCB restructure, which it needed anyway.
- **R2. `tools/check_libc_piles.py` stays**, against spec section 7's list. It guards libc.so's own source and the archives. Only stale "pile" wording in what it prints is corrected. Cost if wrong: none.
- **R3. The `.fgxa` archives other than `util.fgxa` stay.**
  - Their OS build consumer was the pile branch's `fgx_ar select`, but the toolchain's own tests use them (`make test-archives`: `test_libc_archive.py`, `test_lib_boundary.py`), and spec section 7 lists only `util.fgxa`.
  - `util.fgxa` goes as the spec says. Its two readers move: `test_lib_boundary.py` reads libutil's exports from `build/static_libs/libutil.s`, and `tools/libc_so_check.py:boundary_names` reads the same file.
  - Whether the other five archives and `fgx_ar` retire is a question for the maintainer, in the Open items.
- **R4. The profiler profiles what ships.**
  - `run_profile.sh` builds `bin/<tool>.bin` with `ninja` instead of `build_userbin_fgx2_c`. The listing it copies is the dynamic link's `seg0.lst` (`tools/<tool>-fgx2/dyn.ld/seg0.lst`).
  - `build_userbin_fgx2_c` and `_build_userbin_fgx2_c_impl` are deleted from `lib/build_common.sh`; the helpers that `make_floppy.sh` and `make_ufsboot.sh` source stay.
  - The profiler's manifest stages to `prodos_dir` keys. Whether those still work is not in scope; Task 2 records what one run prints. Cost if wrong: the profiler stays broken in some further way, and it is visible.
- **R5. The loader refuses a segment kind above `SEG_KIND_RODATA` with ENOEXEC.** Otherwise a stale LIBCREF binary would read the next segment's bytes into a fresh bank and run garbage. It costs a CMP and a branch in a bank that gains about 1 KB.
- **R6. `TCB_LibcBank` becomes `TCB_Reserved1` again**, an alignment byte, so the TCB layout and the four 16-bit pair accesses stay as they are. Their comments say "+ TCB_Reserved1, zero". Cost if wrong: one byte, unchanged.
- **R7. The text table keeps its 20-byte entry.**
  - `TX_COUNT` 16, `TX_STAMP` 17-18, byte 19 padding, so `_Tx_Off`'s 16+4 stays.
  - `KTTY_TEXT_REG`'s list becomes 8 bytes, copied as 8, and the copy no longer spills into `TX_COUNT`. The `STZ TX_COUNT` that cleaned up after the 10th byte stays, as the count's initialiser.
  - `textchurn_check.py` follows the new `TX_COUNT` offset.
- **R8. The pinned far-bank loader outputs close up.** `_ldLibcSeg` goes, `_ldExtraBanks` becomes 8 bytes (R1), and every `KFAR_LD_*` after them moves down. The `ERR` pairs in `far.s` hold `include/kfar.s` in step; both change in the same commit (K2, the first to stop reading `KFAR_LD_LIBCSEG`).
- **R9. The scan replaces the stager.** `stage_piles.py` goes. The spec's per-commit "nothing staged carries a LIBC or LIBCREF segment" is Task 0's scan, run before each commit. After K1 the loader refuses such a binary outright (R5), and after Task 3 the host linker cannot write one, so no permanent build check is added.

## Review Focus

1. **A path that still takes or drops a pile reference after K1.** If anything still increments a slot after K1, K2's deletion of the decrement leaks; if anything still decrements, a stale nonzero byte frees a live bank.
   - Pinned by ordering: K1 removes every writer of `_libcShLast` and of a nonzero `KFAR_LD_LIBCSEG`, so after K1 every core site reads zero.
   - K2's commit greps for `_libcSh`, `LibcBank` and `LIBCSH_`, prints the count (zero expected), and states it.
2. **A shared-text registration that copies the wrong number of bytes.** The far loader's `_ldTextList` and the tty bank's REG copy must agree (8). A mismatch shifts `TX_COUNT`.
   - Pinned by K3 changing both in one commit, and by `textchurn` with the corrected offsets.
3. **The pinned loader outputs moving under a reader.** Every `KFAR_LD_*` reader is in the core bank (`main.s`, `process.s`) plus `include/kfar.s`. The `ERR` lines catch a disagreement at assembly time.
   - Positive control: K2's first assembly runs with `include/kfar.s` deliberately left unshifted, must fail on the `ERR`, and is then fixed.
4. **A dry pool that no longer reaches ld.mod.** `KTTY_LD_RECLAIM` was reached only from `_LibcSh_Reclaim`'s tail.
   - No machine test reaches its C=1 arm. Spec 5.3 says it is unreachable today: a library is reclaimed only after every cached text has gone, and `ldctl` has no unload. `ldfit` does not reclaim.
   - So the contract is checked by reading, and K2's commit says so. `ld_hooks.s:58-65` preserves Y and clobbers A/X; the `bank.s` call site needs nothing in X or Y across the call (it rescans from `LDX #0` or falls to `@balloc_grant`).
   - `textreclaim` covers the text arm of the same chain.
5. **A stale pile binary.** Pinned by a probe that execs a copy of `/bin/true` whose segment kind byte is patched to 4, through `/bin/ldd`, as `exectrunc` does.
   - Not through sh: 2.11BSD sh re-reads an ENOEXEC file as a shell script (`vendor/2.11BSD/usr/bin/sh/service.c:146-152`).
   - Expected `execution failed: Exec format error`, with `Undefined error` and a crash both absent.
   - The fixture is committed beside `exectrunc`'s.

---

### Task 0: the scan, as a reusable command

**Files:** none tracked (scratchpad `pilescan.py`).

- [ ] **Step 1:** `python3 $SCRATCH/pilescan.py disk_src build/stage` prints `fgx binaries N` and no `kind 3`/`kind 4` line. Expected now: no kind lines.
- [ ] **Step 2 (control):** `python3 $SCRATCH/pilescan.py bin` must print `kind 4 2` (devttyx, rdrestart). That proves the scan can see a pile.
- [ ] **Step 3:** delete the two stale binaries (`rm bin/devttyx.bin bin/rdrestart.bin`, gitignored build products with no edge), so later scans of `bin` are clean too.
- [ ] **Step 4, baselines at HEAD** (I4), MAME fresh:
  - `manyproc`, `textchurn`, `textreclaim`, `exectrunc`.
  - Spec section 1's "manyproc red until SP5" predates step 3, which relinked everything off piles, so manyproc may already be green at HEAD; record what it is.
  - This step makes no claim that any commit turns manyproc green. If it is red at HEAD, its cause is read from the run, not assumed.

### Task 1: the build side (implementer subagent, standard model)

Two commits, the profiler first, so that no commit leaves it reading a deleted template:
- **1a** is Task 2a's text below (`profile: build the tool ninja ships`), done here first;
- **1b** is `build: retire the per-program libc pile path`.

**Files:**
- Modify: `tools/ninja/gen.py`
  - delete `:2550-2721`, so the `if not rec["pile"]` test collapses into the dynamic arm;
  - delete `materialize_links`, `archive_deps`, `GC_PUTS`/`GC_PRUNE`/`GC_MODE`, `LIBC_SEED_ROOTS`, `MEMBER_DIR` and `PILE_CARRIES_OWN`;
  - delete `parse_tools`'s `pile` and `libc_overlay` keys;
  - delete the rules `fgxgc`, `seg3sel`, `fgxld`, `seg1layout` and `stagepiles`;
  - delete the `stage_piles` import, the `PILE_PREFIX` skip (:2911) and the `stagepiles` edge (:2935-2941);
  - delete the `shell_deps` floor (:1797-1813) and its docstring's floor paragraph.
  - `PILE_LIBS` and its guard (:2509-2511) go. The static arm (:2513-2515) and the dynamic arm's `lib_map` check (:2535-2538) both already refuse `llong`/`double` (M9).
  - `kchecks`'s inputs at :2214 name `tools/fgx2/seg0.link.s.in` and `seg1.link.s.in`; they go (I2). Read why they were inputs and say so in the report.
  - `build/.piles_staged` is an input of the `disk/fgxufs.po` edge (:2965); it goes from that edge with the `stagepiles` edge.
  - `tools/helper_census.py:140-144` counts `disk_src/lib/libc.so.*` as pile banks, which now matches `libc.so.1.0` (I6). Delete the pile term and its comment, and check that the census output is unchanged apart from that term.
  - `tools/ninja/derive.py`'s `libcmiss` transform has no derived fixture left; delete it and its `derived_map` row if any (I6).
  - Stale comments (I6): `.gitignore:44-48, 153`, `toolchain/tests/run.sh:270`, `toolchain/src/ld/fgx_dyn.py:368`, `toolchain/src/ld/fgx_bind.py:33`.
- Delete: `tools/stage_piles.py`, `tools/fgx2/` (all six templates), `tools/ninja/seg3.py`.
- Modify: `tools/gate.sh`: delete the stage_piles self-test (:380-388), and correct the `seg3sel` sentence at :518-521 to say what the archive rebuild still dirties (measure: `ninja -t query toolchain/lib/libc.fgxa/index.json`).
- Modify: `.gitignore`, the stage_piles line.
- Modify: `toolchain/src/ld/fgx_libso.py:265` and `fgx_static.py:235`, comments that cite the deleted templates. They say what they lay out, in their own words.

- [ ] **Step 1:** `python3 tools/ninja/gen.py` before the change: save `build.ninja` as `$SCRATCH/before.ninja`.
- [ ] **Step 2:** make the deletions.
- [ ] **Step 3:** `python3 tools/ninja/gen.py`, then `diff <(grep -E '^build ' $SCRATCH/before.ninja | sort) <(grep -E '^build ' build.ninja | sort)`.
  - Expected:
    - the `build/.piles_staged` edge removed;
    - the `disk/fgxufs.po` edge without that input;
    - the kchecks edge without the two templates;
    - the shells' edges without the floor's inputs;
    - every `bin/*.bin` edge's outputs unchanged.
  - `check_shell_linker_inputs()` still passes (gen.py exits 0).
  - Report the diff's line count and every line that falls outside those expectations.
- [ ] **Step 4:** `ninja -n all` reports nothing to do apart from edges whose inputs changed (gen.py itself). Then `ninja all` and Task 0's scan.
- [ ] **Step 5:** `git grep -n -e stage_piles -e materialize_links -e PILE_CARRIES_OWN -e seg3sel -e 'tools/fgx2' -e libc_overlay -- . ':!docs/history' ':!CHANGELOG.md' ':!toolchain/CHANGELOG.md'`. Print the count: zero, or each remaining hit justified in the report (e.g. `docs/fgx2-linker.md` until Task 3).
- [ ] **Step 6:** commit.

### Task 2: the profiler, gen_commons' list, util.fgxa (implementer subagent, standard model)

Three commits.

**2a, `profile: build the tool ninja ships`** (R4). Done as Task 1's first commit.
- [ ] `tools/profile/run_profile.sh`: replace the `build_common.sh` sourcing and `build_userbin_fgx2_c` with `ninja "bin/${TOOL}.bin"`.
  - The listing it copies is `tools/${TOOL}-fgx2/dyn.ld/seg0_Output.txt` (`fgx_dyn.py:308, 315`), or `static.ld/` for a static tool; test which exists.
  - `profile_report.py:43-45` and `seg0map.py:116` attribute samples by one seg0 table, so libc.so's samples come out unattributed. Record that in the commit body as a known limit (M8).
- [ ] `lib/build_common.sh`: delete `build_userbin_fgx2_c` and `_build_userbin_fgx2_c_impl` (:483-759) and the header comment block that describes them (:431 region).
- [ ] Check that `bash -n` passes on `lib/build_common.sh`, `tools/make_floppy.sh`, `tools/make_ufsboot.sh` and `run_profile.sh`.
- [ ] Do NOT run the profiler under MAME. Record in the report that it was not run.

**2b, `sh: gen_commons takes the segment-1 list from fgx_libso`.**
- [ ] `fgx_libso.py`: `main()` accepts `--print-data`, which prints `DATA` one path per line and exits 0. `self_test()` asserts that the printed list equals `DATA`.
- [ ] `tools/sh-fgx2/build_bsh.sh:128-134`: the `--extern-defs` list is built from `python3 "$LIBSO" --print-data` plus `crt0_lib_data.s`. Set `LIBSO` as the script sets `GENCOMMONS`.
- [ ] Rebuild sh with ninja's environment, never by hand (memory: hand runs miss `FCC_SOFT_SCC`). `ninja tools/sh-fgx2/bsh.bin` or the shell's output path from SHELLS; `shasum` the binary before and after. Expected: identical bytes.

**2c, `libutil: retire util.fgxa`** (R3).
- [ ] `toolchain/Makefile`: delete the `lib/util.fgxa/index.json` rule and comment (:169-174), and the `util.fgxa` mentions in `archives` and `test-archives`.
- [ ] `tools/check_libc_piles.py`: delete the `util` artifact. `tools/ninja/gen.py:1886, 1892, 3067`: delete the `util.fgxa` paths.
- [ ] `toolchain/tests/ld/test_lib_boundary.py`: libutil's exports come from `build/static_libs/libutil.s` (`FGX2_EXPORT` lines). Exit 2 with "run ninja first" when it is absent, as `fixture_link.py` does.
- [ ] `tools/libc_so_check.py:boundary_names`: the same file in place of `util.fgxa/*.s`.
- [ ] Control: in a scratch copy, delete `login` from the libutil export list `test_lib_boundary.py` reads; it must FAIL `libutil exports login`.
- [ ] `make -C toolchain test-archives`, then the gate's archive stage command (`cd toolchain && make -s test-archives archives`). Both pass.
- [ ] Remove `toolchain/lib/util.fgxa/` and `util.fgxa.srcsha` if tracked (`git rm`), or leave them if they are gitignored build products. Report which.

### Task 3: the toolchain (implementer subagent, standard model)

Three commits.

**3a, `fgx_ld: no LIBC segment kinds`** (R1).
- [ ] Delete `LIBC`/`LIBCREF` from `KIND_MAP` (:178), and `LIBC_KINDS`, `write_pile` (:238-269), `--pile-dir` (:882-884) and the ninth-segment rule (:905-916). Also delete the LIBCREF write-out at the `write_pile` call site.
- [ ] Every branch keyed on `LIBC_KINDS` (:320-674, :1006-1037, :1195-1201, :1282-1302) reduces to its "no LIBC segment" arm. Read each and keep what the no-LIBC arm does today (`LIBC_EXPORT`/`LIBC_DATA_PTR` recognition stays).
- [ ] `MAX_SEGS = 8`, with the comment saying why: `TCB_BankList` has 8 rows.
- [ ] A manifest naming `"kind": "LIBC"` fails with `unknown segment kind 'LIBC'`; check the message `KIND_MAP` lookups give today.
- [ ] Tests:
  - `toolchain/tests/ld/test_farjump.py` keeps `libc_export_no_libc` and drops its LIBC-segment cases.
  - `test_weak_strong.py` and `test_recursion_shadow.py`: their LIBC segment becomes CODE where the property under test survives (shadowing between two code segments). Where it does not, the case goes, and the report names it.
  - Add one case: a 9-segment manifest is refused with `FGX2 cap is 8`.
- [ ] `python3 -m pytest toolchain/tests/ld -q` (or the files run directly, as `make test` does) passes. `make -C toolchain test` passes.

**3b, `fgx_gc: the link-file driver and --overlay retire`.**
- [ ] Delete `run()` (:509-553), `main()`'s CLI driver and `--overlay`, and `graph()`'s `shadow` parameter. `shadow=True` was every remaining caller's default, so the code takes that arm.
- [ ] Delete the self-tests that exercise `run()`/overlay; keep the primitives' tests. If `fgx_gc.py --self-test` is invoked anywhere (`git grep`), it still runs.
- [ ] The `toolchain/tests/gc/` overlay fixtures (`ovl*`) that only `run()` read go with it (I6). Check every fixture there with `git grep` for a remaining reader before deleting it.
- [ ] `docs/fgx2-linker.md:141-185`, the overlay section, goes. `docs/fgx2-linker.md:105` (`seg3.py`) is corrected to the current link.

**3c, `toolchain: crt0_far.s retires`.**
- [ ] `git rm toolchain/lib/crt0_far.s`.
- [ ] Every comment naming it, outside `docs/history` and the changelogs, is rewritten to name what holds the contract now:
  - files: `include/kernel.s:1362`, `src/kernel/signal.s:962`, `src/kernel/syscall.s:568,803`, `src/kernel/far/fcc_rt.s:436`, `toolchain/lib/{libc_data,fcc_libc_shims,args_data,libc_start,crt0_lib,fcc_runtime,libc_start_data,libc}.s`, `toolchain/lib/libc_c/{env,signal}.c`, `toolchain/src/ld/stack_measure.py:68`;
  - contracts: `_sig_tramp`, `_fcc_dbr`, the DATA stash. Find each symbol's current definer with `git grep -n '^_sig_tramp\|^_fcc_dbr'` and name that file.
  - `toolchain/tests/test_fixture_link.py` and `toolchain/tests/libso/test_libso.py` keep their absence assertions (no `_crt0_start`), but their messages stop naming the file.
- [ ] `docs/userland-abi.md`, `docs/developing-userland.md` and `docs/history/plans/tty-kernel-bank.md`: the crt0_far references describe crt0_lib/crt0_dyn.
- [ ] `git grep -c crt0_far -- . ':!docs/history' ':!*CHANGELOG.md' ':!docs/superpowers'` prints nothing.
- [ ] `make -C toolchain test` and `ninja all` pass.

### Task 4 (K1): the far bank stops loading piles (main agent)

**Files:** `src/kernel/far/loader.s`, `include/loader.s`.

- [ ] **Step 1, delete:**
  - state `:44-63` (`_ldPileRef` .. `_ldPilePath`) and `:64-93` (the T5-B header, `_ldLibcNew`, the registry comment, `_libcShWarn`, `_ldLibcKey*`, `_ldLibcSlot`; `_ldRelocCount` at :94 stays);
  - the `BNE/JMP @lf2_relocDone` comment at :1397-1401 says why the JMP form is there now, without the registry (M4);
  - `_Ld_PileOpen`/`Close`/`HexDigits`/`Nib` and their header (:287-435);
  - `STZ _ldLibcNew` (:599).
  - `STZ _ldLibcSeg` (:598) stays until K2, so the pinned cell reads 0.
- [ ] **Step 2, the segment loop.** Replace `:1095-1380` (from `; --- T5-B: SEG_KIND_LIBC?` to just before `@lf2_notLibc`) with the kind check (R5) and keep the shared skip:

```
@lf2_moreSegs   ASL
                ASL
                ASL                              ; A(8) = cur*8 (cur<=7, no clip)
                REP     #$20
                MX      %00
                AND     #$00FF
                TAX                              ; X = segtab entry base (B-safe)
                SEP     #$20
                MX      %10
                ; 2.11BSD exec refuses a format it does not know with ENOEXEC;
                ; a segment kind past RODATA is one.
                LDA     _ldSegTable+FGX2_SEG_KIND,X
                CMP     #SEG_KIND_RODATA+1
                BCC     @lf2_kindOK
                REP     #$20
                MX      %00
                LDA     #ENOEXEC
                JMP     @lf2_errCloseExtras
@lf2_kindOK     ...falls into the data/code/alloc logic (old @lf2_notLibc)
```

  - The loaded-text skip (`@lf2_skipBytes`, the Lseek) is kept verbatim and moved beside its one remaining caller (`@lf2_notData`'s `BRL`), ending in `INC _ldCurSeg` / `BRL @lf2_loopTop`.
  - `JSR _Ld_PileOpen` / `JSR _Ld_PileClose` around `_LoadOneSegment` go: `JSR _LoadOneSegment` / `BCS @lf2_segOK` / `JMP @lf2_errCloseExtras`.
  - `@lf2_segOK`'s registration block goes; it keeps `INC _ldCurSeg` / `BRL @lf2_loopTop`.
- [ ] **Step 3, text registration** (:1505-1570). The `SEG_KIND_LIBC` test and `@lf2_regPile` go: every CODE segment except the data segment is listed, and nothing writes `_ldTextList+8`. The blanking block `:1578-1597` goes.
- [ ] **Step 4, `_FreeExtras`:** `:1876-1920` (the refcount rollback) goes, and the entry `PHP/REP` at :1871-1875 stays; the function starts at `@fe_libcDone`'s body, relabelled. The header comment loses "drop its libc pile reference".
- [ ] **Step 5:** `_cfp` markers that went with the deleted code:
  - `_cfp431`, `_cfp443-458`, `_cfp600-606`, `_cfp991-993`, `_cfp1000`, `_cfp1003`;
  - regenerate the committed tables after `ninja` builds the listings (I1). Same commands as the `kchecks` rule, without `--check`:

```
python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt src/kernel/far_patchsites.s core
python3 tools/gen_far_bankpatch.py build/fgxfar_Output.txt src/kernel/far/core_patchsites.s far
python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt src/kernel/tty_patchsites.s core-tty
python3 tools/gen_far_bankpatch.py build/fgxtty_Output.txt src/kernel/tty/core_patchsites.s tty
```

    Then `ninja all` again, so the kernel reassembles against them and `kchecks` passes. The fnptr tables (`gen_mod_bankpatch.py`) regenerate the same way if `kchecks` reports them stale.
  - `_FarSh_TextReclaim` (`src/kernel/far_shims.s:428`, `tools/gen_kernel_exports.py:82`) goes; its only caller was `_cfp1003`.
- [ ] **Step 6, `include/loader.s`:**
  - `FGX2_MAX_SEGS EQU 8` with a current-state comment (`TCB_BankList`'s 8 rows);
  - `SEG_KIND_LIBC`/`SEG_KIND_LIBCREF` and the LIBCREF essay go;
  - `PILE_PATH_*` go;
  - `FGX2_SEG_RESERVED`'s comment says reserved (0);
  - `_ldSegTable` shrinks with the EQU.
  - `_ldExtraBanks` (far.s, pinned) and `_ldTextList` stay 9 bytes until K2 and K3; the `LDX #8` zeroing loop (:592) covers them as before.
- [ ] **Step 7:** `ninja all`; `python3 tools/check_kernel_ceiling.py`, recording far free (expected about 1 KB, up from 19).
- [ ] **Step 8:** MAME, fresh:
  - `boot`, `textchurn`, `textreclaim`, `exectrunc` (its EIO must survive; `_LoadOneSegment`'s errno no longer passes through `_Ld_PileClose`), `manyproc`;
  - the new probe `execkind` (Review Focus 5): fixture `tools/mame_test/fixtures/kind4.bin` is `bin/true.bin` with segment 0's kind byte (offset 16+4) set to 4. Write it with a three-line Python in the commit's test step, and commit the fixture as `trunc.bin` is.
    - The test copies `exectrunc.json`'s shape: run through `/bin/ldd`, expect `execution failed: Exec format error`, and lack `Undefined error`.
    - Control: the same test against the un-patched `true.bin` must fail its expectation, because ldd reports the objects instead.
  - Expected: all as at Task 0's baseline, plus `execkind` green.
- [ ] **Step 9:** Task 0's scan, then commit `loader: the far bank no longer loads libc piles`. The body quotes `vendor/2.11BSD/usr/sys/sys/kern_exec.c:134-138` (the `default:` arm's `u.u_error = ENOEXEC`) and gives the far bank's free bytes before and after.

### Task 5 (K2): the core bank's registry and reference counts go (main agent)

**Files:**
- `include/memmap.s`, `include/kernel.s`, `include/kfar.s`;
- `src/kernel/far/far.s`, `src/kernel/far/loader.s` (`STZ _ldLibcSeg`, and `_ldExtraBanks`' zeroing count);
- `src/kernel/{process,task,main,bank}.s`, `src/kernel/tty/ld_hooks.s` (comment).

- [ ] **Step 1, delete:**
  - `memmap.s:426-455` (the registry comment, `LIBCSH_*`, `_libcShTab`, `_libcShLast`) and `:1541-1555` (`_ldPileCorePath` and its comment);
  - `process.s`: the spawn store `:200-209`, vfork step 7 `:1040-1050`, the snapshot-fail DEC `:1098-1108`, `_LibcSh_Slot` `:1290-1320`, exec's adopt/borrow-drop `:3138-3153`, and the exec rollback DEC `:3385-3397`;
  - `task.s:355-380`;
  - `main.s:948-953`;
  - `process.s:588-590`'s comment, which says a pile's bank is never copied;
  - **the tty bank's `_Tx_PileAdj`** (`text.s:106-136`) and its calls in `_Tx_Reclaim` (:180-183) and REG (:361-364), with `_Tx_Reclaim`'s header losing "its pile reference dropped" (C1). `TX_PILE` itself stays in the entry until K3, written as the zero the loader lists in [8].
  - The `_kfp` markers that go: `_kfp928`, `_kfp941`, `_kfp959`, `_kfp960`. The `_ctp076-078` markers go with `_Tx_PileAdj`. All tables regenerate as in K1 Step 5 (I1).
- [ ] **Step 2, `bank.s`:** `JSR _LibcSh_Reclaim` (:154) becomes the ld.mod call, and `_LibcSh_Reclaim` (:196-234) goes. The comment at :144-149 says the chain is: an unused text first, then an unused library (2.11BSD xuncore before failing).

```
_ktp114         JSL     KTTY_TEXT_RECLAIM           ; an unused text's banks first
                BCS     @balloc_rescan
_ktp111         JSL     KTTY_LD_RECLAIM             ; then an unused library's
                BCC     @balloc_grant
```

  - `KTTY_LD_RECLAIM` preserves Y and clobbers A/X, as `_LibcSh_Reclaim` did (`ld_hooks.s:58-60`, whose comment drops `_LibcSh_Reclaim`'s name).
  - The `_ktp111` marker moves with the instruction. Read how `_ktp` markers are collected (`gen_tty_patch` or equivalent) and confirm that a moved marker needs nothing else.
- [ ] **Step 3, the TCB:** `TCB_LibcBank` becomes `TCB_Reserved1 DS 1 ; alignment, zero` (R6). The pair accesses at `process.s:710, 787, 2999, 3457` and `_ev_oldData`'s comment (:5004) say "+ TCB_Reserved1". The comment at :643-644 and :3780 go.
- [ ] **Step 4, the pinned loader outputs** (R8). `far.s` loses `_ldLibcSeg` and its `ERR`; `_ldExtraBanks` becomes `DS FGX2_MAX_SEGS` (8 now); `include/kfar.s` shifts `KFAR_LD_HEADER`.. `KFAR_LD_TEXT` down by 2 (one for `_ldLibcSeg`, one for the 9th extras byte), and `KFAR_LD_LIBCSEG` goes. `loader.s:597-599`'s `STZ _ldLibcSeg` goes.
  - The zeroing loop at :590-594 now has two arrays of different lengths: `_ldExtraBanks` 0-7, `_ldTextList` 0-8 until K3.
  - Split it: `LDX #7` over both, plus `STZ _ldTextList+8`, so nothing writes `_ldExtraBanks+8`, which is now `_ldHeader+0` (M3). K3 deletes the extra STZ.
  - **Control first:** assemble once with `kfar.s` unshifted; the far bank's `ERR _ldHeader-...` must fail. Then shift it.
- [ ] **Step 5:**
  - `git grep -n -e _libcSh -e LibcBank -e LIBCSH_ -e LibcSh_ -e KFAR_LD_LIBCSEG -e _ldPileCorePath -e _Tx_PileAdj -- src include tools toolchain ':!*CHANGELOG.md'`: print the count. Expected zero once Step 7 lands in this commit. Report it.
  - `fgx_ld.py:131, 910` comments mentioning `TCB_LibcBank` went in Task 3; confirm.
- [ ] **Step 6:** `ninja all`, `check_kernel_ceiling.py` (record core free, expected about +300 B). MAME fresh: `boot`, `textreclaim`, `manyproc`, `ldfit`, `textchurn`. `textchurn_check.py` still reads a `libcsh` region; it now names a symbol that no longer exists, so Step 7 lands in this commit.
- [ ] **Step 7, the checker:** `textchurn.json` and `textreclaim.json` drop the `_libcShTab` region; `textchurn_check.py` drops `libcsh` from `need` and its owner loop, and its docstring drops "a libc pile slot".
- [ ] **Step 8:** Task 0's scan, then commit `kernel: the shared-pile registry and its reference counts retire`. The body gives core free before and after, states the grep count, and states that the dry pool's ld.mod arm was checked by reading (Review Focus 4).

### Task 6 (K3): the text table forgets piles (main agent)

**Files:** `src/kernel/tty/text.s`, `include/ktty.s:94`, `src/kernel/far/far.s` (`_ldTextList`), `src/kernel/far/loader.s` (zeroing loop), `tools/mame_test/textchurn_check.py`.

- [ ] **Step 1:**
  - `TX_PILE` goes; `TX_COUNT EQU 16`, `TX_STAMP EQU 17`, and `TX_SIZE EQU 20` with the comment "padded: `_Tx_Off` is 16+4" (R7).
  - The header paragraph `:22-24` goes. (`_Tx_PileAdj` went in K2.)
  - The loader's extra `STZ _ldTextList+8` from K2 goes.
  - The tables regenerate as in K1 Step 5.
- [ ] **Step 2, REG:**
  - the header says "an 8-byte list: the bank of each segment that is text (0 = not text)";
  - "one pile reference taken" goes;
  - the bank copy is `CPY #8`, and the `STZ _kTextTab+TX_COUNT,X` comment says it initialises the count.
  - `include/ktty.s:94` says the same.
- [ ] **Step 3, the far side:** `_ldTextList DS 8` (`far.s`, with its "[8] = pile" comment gone), and the loader's zeroing loop covers 8 for both arrays (`LDX #7`). `KTTY_TEXT_FIND`'s list is already 8 bytes (its header); confirm.
- [ ] **Step 4:** `textchurn_check.py`: `e[17]` becomes `e[16]`. Make the offset a named constant, `TX_COUNT = 16`, beside `TXSZ`.
- [ ] **Step 5:** `ninja all`, `check_kernel_ceiling.py` (record tty free). MAME fresh: `boot`, `textchurn`, `textreclaim`, `manyproc`, `exectrunc`, `execkind`.
- [ ] **Step 6:** commit `text: shared texts no longer hold a libc pile`.

### Task 7: descriptions and docs (implementer subagent, cheap model)

One commit, `docs: the pile path is gone`.

- [ ] `tools/mame_test/tests/catsmoke.json`: the description keeps the content assertion's rationale; the by-reference pile paragraph goes.
- [ ] `exectrunc.json`: the description says the errno comes back from `_LoadOneSegment`'s read. `_Ld_PileClose` is history, and the test's purpose (#520's errno) is restated without the deleted routine.
- [ ] `manyproc.json`: "plus a libc bank shared by identical binaries" becomes what holds banks now: code and data per process, and the resident shared libraries.
- [ ] Current-state docs that still describe `SEG_KIND_LIBC`, piles or `TCB_LibcBank`:
  - `docs/developing-userland.md`, `docs/userland-abi.md`, `docs/history/audits/bank0-stack-status.md`, `docs/BUILDING.md`, `docs/PROVENANCE.md`, `docs/history/plans/architecture-redesign.md`, `docs/history/audits/bank0-stack-baseline.md`, `docs/history/plans/bank0-stack.md` (M7);
  - `docs/ROADMAP.md`'s current-state lines (not its history paragraphs). Get the list from `git grep -n -i -e 'SEG_KIND_LIBC' -e 'LIBCREF' -e 'libc pile' -e 'libc\.so\.<key>' -- docs ':!docs/history' ':!docs/superpowers'`, and report each hit's disposition.
- [ ] Spec section 9 gains R1's divergence, and section 7 gains R2's and R3's corrections (check_libc_piles stays; util.fgxa only).
- [ ] `tools/check_libc_piles.py`'s printed "what" labels: `"libc pile"` becomes `"libc"` (and so on), with no behaviour change.

### Task 8: verification

- [ ] Announce the rebuild. Run `ninja all`, then Task 0's scan.
- [ ] `tools/gate.sh`. Delete the fixture and sweep stamps first, as step 4 did, so the fixture stage and the oracle run. Read which stage, if any, failed.
- [ ] `python3 toolchain/tests/run_runtime.py --all`: 684/684 expected. The libc did not change, but the linkers did (Task 3), and the standing rule is to run it after any link change.
- [ ] MAME fresh, as probes outside the gate: `manyproc` (the spec's proof, expected green), `textchurn`, `textreclaim`, `exectrunc`, `execkind`, `exectime`. Record `exectime`'s figure for step 6.
- [ ] Final `check_kernel_ceiling.py` line for all three banks, into the RESUME.
- [ ] Final whole-branch review (most capable model) over `7f8316db9..HEAD`, with this plan, the spec, and the ledger's rulings.

## Open items (for the maintainer, not blocking)

- The five remaining `.fgxa` archives and `fgx_ar` have no OS build consumer after Task 1; only the toolchain's archive tests use them. Retire them (a step of its own), or keep them as the toolchain's static-archive format?
- #521: the static-link float-printer cost (carried from step 4).
- The bare-metal bench's 7/13 assembly failures (carried from step 4).
