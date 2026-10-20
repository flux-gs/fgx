# Far Kernel Bank -- Phase 4: the console

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Move the whole console driver (9,555 B, 17 files) plus `CON_VT_STATE`
into the far kernel bank, and build the far->core machinery it needs.

**Architecture:** Phases 1-2 landed the far bank and the core->far direction
(`JSL` through a `JMP abs16` export table, operand bank bytes patched by
`Far_Init`). Phase 4 adds the two directions never yet exercised: far->core
*calls and static reads* (scraped offsets + `_cfp` markers, walked by
`Far_BankInit`), and core->far *static reads* (`_kfp` markers on core `LDAL`).

**Design document:** `docs/history/plans/far-kernel-bank.md`. Read it first.

## Global Constraints

- **ASCII only.** No em-dash, no curly quotes, no Unicode. Use `--` for a dash.
- **Never commit to `main`.** Branch: `feat/far-console`.
- **Never self-merge an MR.**
- **Stage specific files.** `git add <paths>`, never `git add -A`.
- **Every new checker gets a `--self-test`** that proves it can fail.
- **`build.ninja` is GENERATED and gitignored.** Edit `tools/ninja/gen.py`.
- **A `DS` in a code segment reserves bytes where it sits.** Far-bank statics go
  AFTER all code. This planted `BRK` in an entry point during the sound move.
- **Cross-bank data uses `LDAL`/`STAL`**, never `LDA |addr`.
- **Regenerate after every kernel-layout change:** `w5100_patchsites.s` and
  `far_patchsites.s`, then rebuild. Both are committed and `--check`ed.

## Build and test

```bash
ninja                                   # full build
tools/gate.sh                           # build + MAME boot smoke (~6 s)
python3 tools/check_kernel_ceiling.py   # both images
tools/cleanroom.sh                      # fresh-clone rebuild
```

Baseline at plan time: **core 56,900 / 57,968 (1,068 free)**, far bank 1,157 B.

---

## Measurements this plan is built on

All re-measured on the post-phase-2 tree.

**Console: 9,555 B across 17 files.** Largest: `console_init.s` 2,178,
`console_vthandler.s` 1,817, `console_vt.s` 1,016, `console_render.s` 877.

**Inbound (core -> console): 14 symbols / 30 sites / 7 files.**
`Con_Write` (4), `Con_PollKey` (4), `Con_RenderAll` (3), `Con_ShowCursor` (3),
`Con_CR` (2), `Con_PutChar` (2), `_Con_InitSCBs` (2), `_Con_InstallPalettes` (2),
`Con_HideCursor` (2), `Con_GetKey` (2), `Con_WriteBuf`, `Con_Init`,
`Con_LoadFontFromFile`, `Con_RevertToDefault`.

**Outbound (console -> core): 8 symbols / 15 sites.**
`Fs_Read` (3), `Fs_Close` (3), `Fs_Open` (2), `Kern_LogStr` (2), `_Halt` (2),
`Kmalloc`, `_sleep`, and `KFAR_SOUND_BEEP` (1). That last one becomes a
**same-bank** call once the console moves and reverts to a plain `JSR` -- so the
real far->core call surface is **7 symbols / 14 sites**.

**Statics.** 9 far-only absolute statics (109 console sites) travel free.
6 shared, but **210 of their 219 console sites are `CON_VT_STATE`**. Move it with
the console and only **9 far->core static sites** remain, across 5 symbols:
`_kFontsBank` (4), `_kKbdRingCount` (2), `_kKbdRing`, `CurrentFontName`,
`_kConsoleBank`.

**`CON_VT_STATE`'s 14 core touches are all in `syscall.s`** and confined to two
features: the deferred-flush timestamp (`VT_LAST_FLUSH`, `:2081`, `:2091`,
`:2244`) and a hi-res profiling block (`VT_HRPROF_*`, `:2235`-`:2282`). They stay
in core and reach the far bank by patched `LDAL`.

**Hot path is not a problem.** Userland output goes through
`Con_Write(buffer)` -- per `write()`, not per character (`syscall.s:2053`,
`:2061`). `Con_PutChar` is per-character only for kernel logging (`log.s:102`,
`:111`), which is boot and `dmesg`. No export-surface coarsening needed.

**No ISR reaches console code.** The only hits are `toolbox.s:89` and `:156`,
both boot-time Toolbox-failure paths ending in `JMP _Kern_Halt`.

---

## Task 1: far->core machinery, proven by moving the far-bank boot line

**Files:**
- Modify: `tools/gen_kernel_exports.py` (add a `far` manifest entry)
- Modify: `tools/ninja/gen.py` (a `kexports` edge for the far bank)
- Create: `src/kernel/far/kernel_exports.s` (generated)
- Modify: `src/kernel/far/far.s`, `src/kernel/main.s`, `include/kfar.s`

**Interfaces:**
- Consumes: `Far_BankInit`'s `_CorePatchTbl` walk (exists, runs as a no-op).
- Produces: `KFAR_LOG_STATE` (slot 8); a working far->core `JSL`; the first
  non-empty `core_patchsites.s`.

**Why this task exists.** The far->core direction has never had a real site. The
console needs 14 of them at once, and debugging the machinery and the payload
together is how the sound move went wrong. This proves the mechanism with ONE
real call that has genuine value: the `far: bank ready` line moves into the far
bank and emits itself.

- [ ] **Step 1: Add the `far` manifest entry**

`tools/gen_kernel_exports.py` keys per-consumer symbol lists off a `MANIFESTS`
dict (line ~20). Add a `far` entry requesting exactly what phase 4 needs, so a
rename fails the build:

```
Fs_Open, Fs_Read, Fs_Close, Kern_LogStr, Kmalloc, _sleep, _Halt
```

- [ ] **Step 2: Add the ninja edge**

In `tools/ninja/gen.py`, beside the four module `kexports` edges:

```python
lines.append(
    "build src/kernel/far/kernel_exports.s: kexports "
    "build/fgx_S01_KernelMain_Output.txt | tools/gen_kernel_exports.py\n"
    "  listing = build/fgx_S01_KernelMain_Output.txt\n  module = far")
```

Add `src/kernel/far/kernel_exports.s` to the `bin/fgxfar.bin` edge inputs, and
`PUT kernel_exports.s` in `far.s` **after** the export table.

- [ ] **Step 3: Prove the drift guard bites**

```bash
ninja src/kernel/far/kernel_exports.s && head -20 src/kernel/far/kernel_exports.s
```

Then temporarily rename `Kern_LogStr` in `src/kernel/log.s`, run `ninja`, confirm
the build FAILS naming the symbol, and revert. This property is the whole reason
the scraper exists; verify it rather than trusting it.

- [ ] **Step 4: Move the boot line into the far bank**

Add to `src/kernel/far/far.s` a `Far_LogState` at slot 8, and move
`_msg_far_ok` there. It calls core `Kern_LogStr` through the scraped offset with
a `_cfp` marker:

```
Far_LogState    MX      %00
                PHB
                PHK
                PLB                     ; DBR = far bank, for our own string
                LDA     #_msg_far_ok
                STA     _conStrPtr      ; DP -- reached through D, bank-agnostic
_cfp001         JSL     Kern_LogStr     ; core bank; byte patched by Far_BankInit
                PLB
                RTL
```

`_LogFarBank` in `main.s` keeps the `_kFarReady` test and the `far: absent`
string (which must stay in core -- it is what prints when the far bank is
missing), and calls slot 8 for the success case.

- [ ] **Step 5: Generate the far-side patch table and confirm it is non-empty**

```bash
ninja bin/fgxfar.bin
python3 tools/gen_far_bankpatch.py build/fgxfar_Output.txt src/kernel/far/core_patchsites.s far
tail -4 src/kernel/far/core_patchsites.s
```

Expected: `_CorePatchEntries EQU 1`. If it is still 0 the marker did not scrape,
and `Far_BankInit` would leave the `JSL` pointing at the assembler's bank.

- [ ] **Step 6: Build, regenerate, gate**

```bash
ninja bin/fgx.bin
python3 tools/gen_w5100_patchsites.py build/fgx_S01_KernelMain_Output.txt src/kernel/w5100_patchsites.s
python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt src/kernel/far_patchsites.s core
ninja && tools/gate.sh
```

Expected: GREEN, and the boot console still shows `far: bank ready` -- now
emitted BY the far bank THROUGH a core call. That line is the proof; if the
far->core patch is wrong it hangs or prints nothing.

- [ ] **Step 7: Commit**

```bash
git add tools/gen_kernel_exports.py tools/ninja/gen.py src/kernel/far/kernel_exports.s \
        src/kernel/far/core_patchsites.s src/kernel/far/far.s src/kernel/main.s \
        include/kfar.s src/kernel/far_patchsites.s src/kernel/w5100_patchsites.s
git commit -m "feat(kernel): far->core calls, proven by moving the boot line into the far bank"
```

---

## Task 2: move the console

**Files:**
- Move: `src/drivers/console/*.s` + `fonts/*.s` -> `src/kernel/far/console/`
- Modify: `include/kfar.s` (slots 9-22), `src/kernel/far/far.s`
- Modify: `include/memmap.s` (`CON_VT_STATE` + 9 console-owned statics leave)
- Modify: the 7 core files holding the 30 inbound call sites
- Modify: `src/kernel/syscall.s` (14 `CON_VT_STATE` sites -> patched `LDAL`)
- Modify: `src/drivers/console/console_init.s` (bank-patch walker)
- Modify: `tools/ninja/gen.py`, `docs/superpowers/reloc-tools/gen_console_bankpatch.py`

**Interfaces:**
- Consumes: everything from Task 1.
- Produces: slots 9-22 for the 14 console exports.

- [ ] **Step 1: Re-verify the boundary has not drifted**

Re-run the inbound/outbound/static measurements from the "Measurements" section
above and confirm 14/30 inbound, 7/14 outbound (after the sound-bell reversion),
9 far->core static sites, 14 core `CON_VT_STATE` sites. **If any number differs,
stop and re-plan** -- the sound move taught that a stale dependency measurement
is how a "self-contained" file turns out to hold a syscall handler.

- [ ] **Step 2: Move the files and add bank framing**

`git mv` all 17 files. Each of the 14 exported entry points gains `PHB/PHK/PLB`
after its existing prologue and returns `PLB`/`RTL` -- **pull order is `PLB` then
`PLP`** where a `PHP` is also present, because `PHP` pushes first and `PHB` lands
on top. Internal `JSR`/`RTS` between console files are same-bank and unchanged.

- [ ] **Step 3: `CON_VT_STATE` and the 9 console-owned statics move**

Remove them from `include/memmap.s`; declare them in the far bank **after all
code**. The 210 console references stay DBR-relative and cost nothing.

- [ ] **Step 4: The 14 core `CON_VT_STATE` sites become patched `LDAL`**

In `syscall.s`, each `LDA |CON_VT_STATE+X` / `STA |CON_VT_STATE+X` becomes
`LDAL`/`STAL` with a `_kfp` marker. `gen_far_bankpatch.py` already accepts
markers on `LDAL`/`STAL` (bank byte at +3) and `Far_Init`'s walk already patches
`_kfp` sites, so no new mechanism is needed -- only markers. Costs +1 byte per
site.

- [ ] **Step 5: Fix the bank-patch walker**

`console_init.s:29-40` builds its patch pointer with `_BANKK` -- the live KERNEL
bank. The sites it patches are now far-bank sites. Since `Con_Init` will be
running IN the far bank with `DBR` = far bank, drop the long pointer entirely and
use `STA abs,Y`, exactly as `Far_BankInit` does. Update
`gen_console_bankpatch.py`'s header comment, which says "in-kernel-bank offset".

- [ ] **Step 6: Convert the 30 inbound call sites**

Each becomes `_kfpNNN JSL KFAR_CON_*`. Assign slots 9-22 in `include/kfar.s`.

- [ ] **Step 7: Convert the 14 outbound call sites**

`Fs_Open`/`Fs_Read`/`Fs_Close`/`Kern_LogStr`/`Kmalloc`/`_sleep`/`_Halt` become
`_cfpNNN JSL <scraped>`. Revert the sound bell in `console_vt.s` from
`JSL KFAR_SOUND_BEEP` to a plain `JSR Sound_Beep` -- it is same-bank now.

- [ ] **Step 8: Build, regenerate both tables, run every guard**

```bash
ninja bin/fgx.bin bin/fgxfar.bin
python3 tools/gen_w5100_patchsites.py build/fgx_S01_KernelMain_Output.txt src/kernel/w5100_patchsites.s
python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt src/kernel/far_patchsites.s core
python3 tools/gen_far_bankpatch.py build/fgxfar_Output.txt src/kernel/far/core_patchsites.s far
ninja && ninja build/.kernel_checked
```

- [ ] **Step 9: Gate, and measure the reclaim**

Expected core: roughly **47,400 / 57,968, ~10,500 free.** Re-sum the listing; do
not infer it from a removed PUT.

- [ ] **Step 10: Test what the gate does not**

The gate boots and runs `ls /`, which does exercise the console heavily -- but
also test the VT paths it does not: `vi` (full-screen redraw, alt-screen),
`clear`, `tput`, a colour test, and the bell. Then `ls /` again to catch a
wrong-DBR return, which surfaces in the NEXT operation.

- [ ] **Step 11: Re-verify no ISR reaches the far bank, and commit**

---

## Risks

| Risk | Mitigation |
|---|---|
| Boot logging breaks before `Con_Init` | `boot_console.s` firmware COUT already covers the pre-console window; `Far_Init` runs at `main.s:225`, long before `Con_Init` |
| 210 `CON_VT_STATE` sites regress if it does not move cleanly | it is console-owned 210:14; if the 14 core sites resist conversion, fall back to leaving it in core and patching 210 far sites (mechanically fine, just larger) |
| The bank-patch walker patches the wrong bank | Step 5; symptom would be console garbage immediately at `Con_Init` |
| Far bank overflows | it is at 1,157 of 60,480; the console takes it to ~10,700. Ample |
| A `DS` lands mid-routine | statics after all code, per the sound-move lesson |
