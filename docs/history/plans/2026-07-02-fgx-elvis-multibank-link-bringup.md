# Elvis Multi-Bank Link + Bring-Up — Implementation Plan

**Goal:** Link the ~28 compiled elvis TUs into a bootable multi-*code*-bank FGX2
binary and bring it up on MAME to the point of drawing its editor screen with a
file loaded — with `signal()` stubbed. Real `^C`→SIGINT is the deferred capstone.

**Approach:** Adapt the proven **vi-spike** multi-code-bank C pipeline
(`experiments/vi-spike/build_vi.sh` + `gen_vi_link.py` + `dataseg.link.s` +
`fgx_ld.py` manifest) to elvis. Every toolchain piece already exists and is
proven (vi.bin booted multi-bank; ed-fgx2 ships a 2-seg build):
- `fcc --far-calls --data-segment` emits `FGX2_FARCALL <fn>` for every user call
  (JSL, callee returns via **RTL**, string pool moves into the data seg).
- `gen_seg1_layout.py` exposes data-seg labels to the code segs.
- a bin-packer distributes code TUs across ≤7 code banks (≤64KB each) + 1 data
  bank.
- `fgx_ld.py` (MAX_SEGS=8) resolves cross-bank FARCALLs **globally** and emits
  the FGX2 multi-bank header + reloc tables → a single bootable `.bin`.

## Global Constraints
- Branch `feat/elvis-port-prep` (both repos), UNRELEASED. Never commit to main.
  Stage specific files. Commit trailer on every commit.
- **Fix the toolchain, don't work around.** Any `--far-calls` fcc gap → fix fcc,
  add an oracle fixture, keep oracle green.
- `examples/` is GITIGNORED: compile the pristine TUs from
  `examples/netbsd-0-9/usr.bin/elvis/`, the machine-layer TUs from tracked
  `src/userland/elvis/`. (Elvis is not CI/clean-checkout buildable yet — that is
  a later "vendor into tracked src" decision, out of scope here.)
- Validate on MAME (oracle + `tools/mame_test/run.py --no-state` for kernel
  changes).

## Harness Location (tracked)
- `src/userland/elvis/` — machine-layer C (`unix.c` already here; add
  `system.c`/`tio` seam if needed) + tracked build driver `build_elvis.sh` +
  packer `gen_elvis_link.py` + `dataseg.link.s` / `segK.link.s` templates.
- Build artifacts (per-TU `.code.s`/`.data.s`, `segK`, `elvis.bin`) → gitignored
  `tools/elvis-fgx2/`.

## TU Set (28 linkable)
- **Pristine (examples/):** blk cmd1 cmd2 ctype curses cut ex input main misc
  modify move1 move2 move3 move4 move5 opts recycle redraw regexp regsub system
  tio tmp vars vcmd vi
- **Tracked (src/userland/elvis/):** unix.c
- **EXCLUDE:** prsvunix.c (separate `elvprsv` program), vendored unix.c (replaced).

## Compile invocation (per TU)
`fcc --far-calls --data-segment <bdir>/<t>.data.s -DBSD=1 -DTINYSTACK=1 \
  -DNEWSTYLE=0 -I<elvisdir> -I<seamdir> <t>.c -o <bdir>/<t>.code.s`

---

### Phase 0 — Compile all 28 under `--far-calls` (de-risk codegen) — ✅ DONE
The 28/29 campaign used plain `--data-segment` (no `--far-calls`). `--far-calls`
is a different codegen path (RTL returns, FARCALL per call, string pool in data
seg); proven on vi's 21 TUs but may surface new elvis-specific fcc gaps.
- [x] main.c compiled clean `--far-calls` (58 FARCALLs, 3 RTL).
- [x] All 28 compile clean `--far-calls`, 0 failures. Biggest codegen risk retired.
- Flags: `fcc --far-calls --data-segment <t>.data.s -DBSD=1 -DTINYSTACK=1
  -DNEWSTYLE=0 -Iexamples/netbsd-0-9/usr.bin/elvis -Itoolchain/include
  -Isrc/userland/elvis <t>.c -o <t>.code.s`. Driver:
  `scratchpad/elvis_compile.sh`; outputs in gitignored `tools/elvis-fgx2/`.
- **DoD:** 28/28 compile clean `--far-calls` ✅.

### Phase 0.5 — ★ CROSS-BANK FN-PTR DISPATCH TABLES (fcc fix) — GATES EVERYTHING
Discovered assembling the dataseg: elvis's core is command/motion dispatch
tables (`cmdnames[]`, vi keymaps) holding FUNCTION POINTERS. Under `--far-calls`
fcc emits `&func` in a static initializer as a bare `DA func / DFB ^func` —
non-relocatable across banks → **the dataseg won't even assemble** (`Impossible
to evaluate DA Data 'cmd_source'`). 162 sites (ex.data.s 60, vi.data.s 102).
The vi-spike never solved this ("stevie booted, EMPTY screen"). ★BOTH PARTS
DONE + MAME-verified (see `feedback_fcc_far_fnptr_in_data_initializer` memory):
- [x] **Part 1 — storage:** emit `FGX2_LONG_PTR _Fa;<func>;0` at emit.c's 3
  fn-ptr init sites, guarded on **`g_far_calls`** (corrected from the earlier
  `g_data_out` — plain --data-segment is single-code-bank). dataseg assembles
  (52765 B); oracle 331/331.
- [x] **Part 2 — indirect CALL: a THREE-LAYER fix** (investigation found the
  callee bank was dropped in 3 places, not 1), all guarded on `g_far_calls`:
  - **L1 load** — `emit_load_global_field` + `emit_deref_ptr_field` read the
    loader-patched stored bank for LT_FN_PTR (was PHK own-bank).
  - **L2 stash** — the 3 stash-before-args sites (`parse_expr.c`) stash the
    4-byte far ptr and reload offset+bank (helpers `stash_fnptr_callee` /
    `call_stashed_fnptr`); arg eval no longer loses the bank.
  - **L3 trampoline** — `emit_call_indirect` emits a **double-RTL far**
    trampoline (PHK+PEA ret-1 far return frame → push target bank+offset-1 →
    RTL); `JML/JMP [abs]` can't indirect a DBR-relative 24-bit ptr (bank-0
    only).
- [ ] libc-fnptr wrinkle (`&strcpy` ×2): resolve multiply-defined to a
  deterministic copy (seg0) or avoid. **Deferred to LINK time (Phase 3).**
- [x] Regression fixture: `tools/farfnptr-fgx2/` (2 code banks + data) +
  `tools/mame_test/tests/farfnptr.json` — all 4 idioms cross-bank w/ a
  bank-clobbering arg; baseline FAILED, fixed PASSES **rc=42 on MAME**.
- **Prereq DONE:** `crt0_far.s` brought up to the soft-stack model (`_fcc_ssp`
  region init + `FGX2_FARCALL main`).
- **DoD ✅:** elvis dataseg assembles; the 2-bank fn-ptr-table fixture RUNS on
  MAME (rc=42); all 28 elvis TUs recompile clean, 0 stray in-bank RTS; goldens
  351/351 byte-identical.

### Phase 1 — Data segment (one bank)
- [ ] `dataseg.link.s` USEs all 28 `<t>.data.s`; assemble via Merlin32.
- [ ] `gen_seg1_layout.py dataseg.lst dataseg_layout.s`.
- [ ] Assert `dataseg` ≤ 65535. (RISK: elvis static buffers — `blk.c`,
  `tmp.c` — may be large; if >64KB, move big statics to heap/bss.)
- **DoD:** single data bank, size ≤64KB.

### Phase 2 — Pack code into ≤7 banks
- [ ] `gen_elvis_link.py`: assemble-measure each `<t>.code.s`, bin-pack into
  `segK.link.s` (each ≤64KB; each USEs `dataseg_layout.s` + far-call macros).
- [ ] Emit `elvis.json` (K CODE segs + 1 DATA; `n_data_segment` = data seg index;
  `entry_offset` at elvis `main`/crt0 entry).
- **DoD:** N≤7 code segs, each ≤64KB; manifest written.

### Phase 3 — Link + enumerate externals
- [ ] `fgx_ld.py elvis.json` → `elvis.bin`. Unresolved FARCALL targets = the
  machine-layer seam set (system, errno, signal, getcwd, any libc gap).
- **DoD:** link runs; unresolved-external list enumerated.

### Phase 4 — Machine-layer seams (stub-first for boot)
- [ ] `errno` real global (int in data seg; wrappers set it).
- [ ] `signal()` stub: install via `SYS_SIGNAL`(#48) or no-op returning SIG_DFL
  (elvis discards the return; task #27 fn-ptr-return not needed).
- [ ] `system()` / `:!` → spawn+wait, or `-1` stub for first boot.
- [ ] `getwd`→`getcwd`; residual libc via fcc shims (toolchain-first).
- **DoD:** `elvis.bin` links with zero unresolved.

### Phase 5 — FGX2 packaging + MAME bring-up
- [ ] Copy `elvis.bin` → `bin/` + disk image; wire `build.sh`.
- [ ] Autoboot `elvis <file>`; `run.py --no-state` screen capture.
- **DoD:** elvis boots, draws its editor screen (status line + file text + `~`
  empties) through the curses/redraw + tty seam; no crash. Deeper interactive
  editing = hand-test with the maintainer (keystrokes aren't headless-automatable).

### Phase 6 — (DEFERRED capstone) real `^C`→SIGINT
Wire `@rd_console` (`syscall.s:1475`) to `_Tty_DeliverSig`/`_Sig_Raise` on a
`t_intrc` match → elvis `signal(SIGINT)` + longjmp back to the command loop.
Separate design pass; the machinery (`_Sys_CheckSignal`, `_Sys_Signal` #48,
`_Tty_DeliverSig`, `_kTtySigReq`) already exists.

## Open Risks
- (a) `--far-calls` surfaces new fcc gaps (Phase 0 — the biggest unknown).
- (b) data seg > 64KB (elvis large statics) → heap/bss relocation.
- (c) a single TU's code > 64KB (cmd1 is 37KB *source* — check compiled size).
- (d) TINYSTACK/soft-stack × `--far-calls` RTL frame interplay.
