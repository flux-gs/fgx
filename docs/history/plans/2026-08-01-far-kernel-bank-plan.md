# Far Kernel Bank Implementation Plan (phases 1-2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a second statically-linked kernel bank, prove it end to end with
`sound.s`, and prove far-bank syscall handlers with the BRAM RTC clock.

**Architecture:** A second Merlin32 link unit (`fgxfar.link.s` -> `bin/fgxfar.bin`)
is loaded by stage 2 into the kernel handle's existing headroom bank (live kernel
bank + 1). Core reaches it through a fixed export table of `JMP abs16` slots at
the BASE of the far bank; the far bank reaches core through symbol offsets
scraped by the existing `tools/gen_kernel_exports.py`. Boot patches only the bank
bytes of cross-bank `JSL`/`LDAL` operands, using generated patch-site tables.

**Status:** Tasks 1 and 2 are LANDED (72d0df8a4, 790951d8e). Three design points
changed on contact with the build and are corrected below: the far bank needs no
allocation, the export table must sit at offset $0000, and slot 0 is the init
entry.

**Tech Stack:** Merlin32 65816 assembly, ninja, Python 3 build tooling, MAME
headless boot harness (`tools/gate.sh`).

**Design document:** `docs/history/plans/far-kernel-bank.md`. Read it before starting; this plan
implements its sections 3, 4, 5 and phases 1-2 of section 6.

## Global Constraints

- **ASCII only.** No em-dash, no curly quotes, no Unicode anywhere in source,
  comments, log strings, or disk content. Use `--` for a dash.
- **Never commit to `main`.** Work on `feat/far-kernel-bank`, already created.
- **Never self-merge an MR.** Push the feature branch and let the maintainer merge.
- **Stage specific files.** `git add <paths>`, never `git add -A`.
- **Every new checker gets a `--self-test`** that proves it can fail, run before
  the real check, exactly as `build.ninja:83` does for the existing seven.
- **`MX` discipline.** Merlin32 `MX %00` = 16-bit A and index; `%11` = 8-bit both;
  `%10` = 8-bit A, 16-bit index. A `SEP #$30`/`REP #$30` that disagrees with the
  `MX` directive makes the assembler emit immediates of the wrong width. Declare
  `MX` after every mode change.
- **Cross-bank data access uses `LDAL`/`STAL`,** never `LDA |addr`, for any
  address whose bank is not the currently-executing bank.
- **The kernel ceiling is derived, never copied:** `FGX_DATA - FGX_CODE` from
  `include/kernel.s`. Do not hardcode 57968 anywhere.
- **Regenerate `w5100_patchsites.s` if `net.s` or kernel layout changes** --
  `tools/gen_w5100_patchsites.py`.
- **Generators must be idempotent.** After running a generator twice, `ninja -n`
  must report no work to do. A build step that rewrites its own inputs
  self-invalidates.
- **Self-test helpers are yours to write.** The `_selftest()` bodies in Tasks 1,
  3 and 4 call small local helpers (`_would_reject`, `rejects`, `raises_on`,
  `raises_on_stale`) that do not exist yet -- each is a few lines wrapping the
  checker's own entry point and catching `SystemExit`. Write them in the same
  file; they are not shared infrastructure.

## Build and test commands

```bash
ninja                      # full build
ninja bin/fgx.bin          # core kernel only
ninja bin/fgxfar.bin       # far kernel bank only (added by Task 1)
ninja build/.kernel_checked   # run the kernel source guards
tools/gate.sh              # build + MAME boot smoke test (~33 s) -- THE gate
tools/gate.sh --no-tests   # build only, writes a receipt marked as such
```

`tools/gate.sh` boots `disk/fgx.po`, waits for a shell prompt, runs `ls /`, and
checks the listing came back. It writes `.gate/<sha>.json`. **No status is not
pass** -- a gate that never ran leaves no receipt and reads as red.

To inspect a boot manually, the harness leaves `/tmp/fgx_test_smoke/dump.txt`
with the final register state and the console text.

---

## File Structure

**New files:**

| File | Responsibility |
|---|---|
| `include/kfar.s` | Far-bank geometry: bank anchor offsets, `KFAR_INIT` fixed entry, export-table base and one EQU per export slot. The single source of truth both link units agree on. |
| `fgxfar.link.s` | Merlin32 link file for the far bank. Sibling of `fgx.link.s`. |
| `src/kernel/far/far.s` | Far-bank segment root. Owns the export table, `Far_BankInit`, and `PUT`s each migrated subsystem. |
| `src/kernel/far/kernel_exports.s` | **Generated** by `tools/gen_kernel_exports.py` from the core listing. Core symbol offsets for far-bank code. |
| `src/kernel/far/core_patchsites.s` | **Generated.** Far-side sites whose operand bank byte must become the core bank. |
| `src/kernel/far_patchsites.s` | **Generated.** Core-side sites whose operand bank byte must become the far bank. |
| `tools/gen_far_bankpatch.py` | Emits both patch-site tables from the two listings. |
| `tools/check_far_calls.py` | Asserts every core reference to a far-bank export is `JSL`, never `JSR`. |

**Modified files:**

| File | Change |
|---|---|
| `include/kernel.s` | `FGX_KFAR_*` geometry constants. |
| `include/memmap.s` | `_kFarBank` static; rest-anchor offset for the far bank. |
| `src/boot/stage2.s` | Allocate the far bank, load `/KERNELF`, publish the bank byte. |
| `src/kernel/main.s` | Call `Far_Init` during boot; `_LogFarBank` boot line. |
| `build.ninja` | `kernelfar` rule, far-bank edges, generator edges, new guards. |
| `tools/check_kernel_ceiling.py` | Check both images against their own ceilings. |
| `make_disk.sh` | Stage `bin/fgxfar.bin` onto the image as `/KERNELF`. |

**Key mechanism, worth internalising before Task 1.** The two directions are
deliberately asymmetric, and that is what makes the build acyclic:

- **Core -> far:** `JSL <farbank>:<KFAR_ slot>`. The slot holds `JMP abs16`.
  **The slot needs no patching** -- the `JSL` already set PBR to the far bank, so
  a 16-bit `JMP` lands correctly. Only the `JSL` operand's bank byte is patched,
  core-side. Core never needs a far *symbol* address at build time, only a slot
  EQU.
- **The export table sits at bank offset $0000, and that is forced, not chosen.**
  Merlin32 emits only real bytes and does NOT pad the gap between two `ORG`s. The
  original design put the table at $FE00 and the init entry at $FD00; the
  resulting binary was 150 bytes of PACKED code with the offsets discarded, so
  loading it at bank:0000 would have put the init entry at offset 0 and made
  every slot address wrong. It assembled with exit 0 and looked correct.
- **Slot 0 is the init entry.** The separate fixed `KFAR_INIT` offset was never
  needed: slots are never patched, so the table is correct as assembled and there
  is no bootstrap ordering problem.
- **Far -> core:** `JSL <corebank>:<scraped offset>` and `LDAL <corebank>:<scraped
  offset>`. Offsets come from `kernel_exports.s`; only the bank byte is patched,
  far-side.

---

## Task 1: Far-bank geometry, the empty far image, and a ceiling guard that covers it -- LANDED (72d0df8a4)

**Files:**
- Create: `include/kfar.s`
- Create: `src/kernel/far/far.s`
- Create: `fgxfar.link.s`
- Modify: `include/kernel.s` (append the `FGX_KFAR_*` block)
- Modify: `build.ninja` (add `rule kernelfar` and its build edge)
- Modify: `tools/check_kernel_ceiling.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `bin/fgxfar.bin`; `build/fgxfar_S01_FarMain_Output.txt` (the far
  listing); the symbols `KFAR_EXPORT_BASE`, `KFAR_INIT`, `KFAR_MAGIC`,
  `Far_BankInit`; the constant `FGX_KFAR_CODE`.

- [ ] **Step 1: Write the failing guard extension first**

Add a second image to `tools/check_kernel_ceiling.py`. It already parses
`FGX_CODE`/`FGX_DATA` out of `include/kernel.s` and derives the limit; give it a
table of (binary, code-symbol, data-symbol) pairs. Extend the existing
`_selftest()` so it proves the *new* path can fail:

```python
IMAGES = [
    ("bin/fgx.bin",    "FGX_CODE",      "FGX_DATA"),
    ("bin/fgxfar.bin", "FGX_KFAR_CODE", "FGX_KFAR_DATA"),
]

def _selftest():
    """Prove the checker can FAIL.  A gate that only ever passes is the defect
    it exists to catch, so silence is trusted only after this shows teeth."""
    sample = ("FGX_CODE        EQU     $020B00\n"
              "FGX_DATA        EQU     $02ED70\n"
              "FGX_KFAR_CODE   EQU     $030000\n"
              "FGX_KFAR_DATA   EQU     $03EC40\n")
    fails = []
    if ceiling(sample, "FGX_CODE", "FGX_DATA")[2] != 0xE270:
        fails.append("core ceiling parse drifted")
    if ceiling(sample, "FGX_KFAR_CODE", "FGX_KFAR_DATA")[2] != 0xEC40:
        fails.append("far ceiling parse drifted")
    # the checker must REJECT an oversized image
    if not _would_reject(size=0xEC41, limit=0xEC40):
        fails.append("checker accepted an over-ceiling far image")
    if fails:
        raise SystemExit("check_kernel_ceiling self-test FAILED: " + "; ".join(fails))
```

- [ ] **Step 2: Run the self-test and watch it fail**

```bash
python3 tools/check_kernel_ceiling.py --self-test
```

Expected: FAIL -- `cannot find FGX_KFAR_CODE in include/kernel.s`. The constants
do not exist yet. This is the point: the guard is written before the thing it
guards.

- [ ] **Step 3: Add the far-bank geometry constants**

In `include/kernel.s`, after the existing `FGX_CODE`/`FGX_DATA` block:

```
;--- Far kernel bank -----------------------------------------------------------
; A SECOND statically linked kernel image, loaded by stage 2 into its own
; MM-assigned bank.  Not an FGXM module: present before the FS exists, and free
; to call Kmalloc/_sleep.  See docs/history/plans/far-kernel-bank.md.
;
; Assembly bank $03 is a CONVENTION ONLY, exactly as modules ORG at $05.  At
; runtime the bank comes from PHK, never from this constant.
FGX_KFAR_BANK       EQU $03         ; assembly-time bank; runtime bank is dynamic
FGX_KFAR_CODE       EQU $030000     ; far-bank code start
FGX_KFAR_DATA       EQU $03EC40     ; far-bank statics start (= code ceiling)
```

- [ ] **Step 4: Create `include/kfar.s`**

```
;==============================================================================
; kfar.s - Far kernel bank ABI.  Shared by fgx.link.s and fgxfar.link.s.
;
; THE EXPORT SLOTS ARE `JMP abs16`, NOT `JML`, AND ARE NEVER PATCHED.  A core
; caller does `JSL <farbank>:<slot>`, which sets PBR = far bank before the slot
; executes, so a 16-bit JMP inside the slot already lands in the right bank.
; Only the CALLER's JSL operand bank byte is patched.  This is why there is no
; chicken-and-egg about who patches the patcher.
;
; Slot stride is 4 (3-byte JMP + 1 pad) to match MOD_JT_GATEWAY's shape, so the
; two tables read the same way.
;==============================================================================

KFAR_MAGIC          EQU     $4B46           ; 'FK' -- validity marker at +$00
KFAR_INIT           EQU     $FD00           ; fixed far-bank init entry (see below)
KFAR_EXPORT_BASE    EQU     $FE00           ; export table base (offset in far bank)

; KFAR_INIT is at a FIXED offset reachable WITHOUT the export table, because it
; is what makes the rest of the cross-bank machinery work.  Core calls it once,
; as `JSL <farbank>:KFAR_INIT`, with the far bank byte taken from the rest-anchor
; at runtime rather than from a patch table.

KFAR_HDR_MAGIC      EQU     KFAR_EXPORT_BASE+$00    ; word: KFAR_MAGIC
KFAR_HDR_ABIVER     EQU     KFAR_EXPORT_BASE+$02    ; word: ABI version
KFAR_HDR_RESERVED   EQU     KFAR_EXPORT_BASE+$04    ; word: reserved, 0

KFAR_ABI_VERSION    EQU     $0001

; --- Export slots.  Slot n = KFAR_EXPORT_BASE + $06 + 4n.  32 slots reserved so
; --- adding an export is never a layout change.  Unused slots hold a JMP to the
; --- far-bank stub halt, so an accidental call fails loudly.
KFAR_SLOT_COUNT     EQU     32
; (slots are assigned by the tasks that add exports -- see Task 5 and Task 8)
```

- [ ] **Step 5: Create `src/kernel/far/far.s` with the export table and a stub init**

```
;==============================================================================
; far.s - Far kernel bank segment root.
;
; Bank-agnostic: this file ORGs at FGX_KFAR_CODE ($03:0000) for assembly only.
; Every entry point does PHK/PLB so DBR becomes whatever bank the image was
; actually loaded into, exactly as an FGXM module's mod_init does.
;==============================================================================
                REL
                ORG     FGX_KFAR_CODE

                PUT     include/kernel.s
                PUT     include/macros.s
                PUT     include/kfar.s

;--- Far-bank entry points get PUT here as subsystems migrate.

;==============================================================================
; Far_BankInit - patch every far-side cross-bank operand bank byte to the CORE
; bank, then return.  Reached as `JSL <farbank>:KFAR_INIT` from the core kernel.
;
; In:   A = core bank number (low byte).  MX %00.
; Out:  C=1 on success.  A/X/Y clobbered.  DBR restored to caller's.
;==============================================================================
                ORG     FGX_KFAR_CODE+KFAR_INIT
Far_BankInit    MX      %00
                PHB
                PHK
                PLB                     ; DBR = far bank, for our own tables
                ; Task 3 fills in the patch-table walk here.  Until then the
                ; table is empty and this is a no-op that proves the call path.
                PLB
                SEC
                RTL

;==============================================================================
; The export table.  See include/kfar.s for why these are JMP and not JML.
;==============================================================================
                ORG     FGX_KFAR_CODE+KFAR_EXPORT_BASE
                DW      KFAR_MAGIC
                DW      KFAR_ABI_VERSION
                DW      0                       ; reserved

;--- Slot 0..31.  Every slot starts as a JMP to the stub halt; Task 5 and Task 8
;--- replace individual slots with real targets.
                LUP     KFAR_SLOT_COUNT
                JMP     _Far_StubHalt
                DFB     0                       ; pad to stride 4
                --^

;==============================================================================
; _Far_StubHalt - an unassigned export slot was called.  Red border + halt, the
; same loud-failure contract as the kernel's _Phase1_StubHalt for unwired MOD_JT
; slots.  Silence here would be a wild jump.
;==============================================================================
_Far_StubHalt   SEP     #$20
                MX      %10
                LDA     #$01
                STAL    $E0C034                 ; border = red
@spin           BRA     @spin
```

- [ ] **Step 6: Create `fgxfar.link.s`**

```
*==============================================================================
*  fgxfar.link.s - FGX far kernel bank link file
*
*  A SECOND link unit, not a third segment of fgx.link.s.  Merlin32 concatenates
*  a link file's segments into one image at one ORG, so a third segment would
*  share the core bank's ceiling and buy nothing.  A separate link gets its own
*  64 KB ceiling and its own listing.
*
*  Segment #1 : src/kernel/far/far.s
*==============================================================================

            TYP    $06                       ; Binary / fixed-address
            DSK    fgxfar                    ; Output name (ProDOS: 15 char max)
            ORG    $030000                   ; FGX_KFAR_CODE

            ASM    src/kernel/far/far.s
            SNA    FarMain
```

- [ ] **Step 7: Wire the ninja rule**

Model it on `rule kernel` (`build.ninja:41`), which captures the status, always
moves the listings, prints the log and exits non-zero on failure, and only then
publishes the binary. That shape exists because a kernel that failed to assemble
once left the PREVIOUS binary in place and the build still read green.

```ninja
rule kernelfar
  command = rc=0; merlin32 -V fgxfar.link.s > build/merlin_kernelfar.log 2>&1 || rc=$$?; for f in fgxfar_S01_FarMain_Output.txt _FileInformation.txt error_output.txt; do [ -f "$$f" ] && mv "$$f" build/; done; if [ $$rc -ne 0 ]; then cat build/merlin_kernelfar.log; exit $$rc; fi; mv fgxfar bin/fgxfar.bin
  description = merlin32 far kernel bank

build bin/fgxfar.bin build/fgxfar_S01_FarMain_Output.txt: kernelfar | fgxfar.link.s src/kernel/far/far.s include/kfar.s include/kernel.s include/macros.s
```

Add `tools/check_kernel_ceiling.py`'s new dependency and `bin/fgxfar.bin` to the
`build/.kernel_checked` edge inputs at `build.ninja:234`.

- [ ] **Step 8: Build and verify both ceilings are checked**

```bash
ninja bin/fgxfar.bin && python3 tools/check_kernel_ceiling.py --self-test && python3 tools/check_kernel_ceiling.py
```

Expected: far image builds; self-test passes (it can now find both constant
pairs and still rejects an oversized image); the real check passes for both
images.

- [ ] **Step 9: Verify the export table landed where the EQU says**

```bash
grep -E "03/FE0[0-9]" build/fgxfar_S01_FarMain_Output.txt | head -5
```

Expected: the `DW KFAR_MAGIC` line at address `03/FE00`. If the table is at a
different address, the `ORG` and the EQU have drifted and every future core call
would jump into the wrong place.

- [ ] **Step 10: Prove the core kernel is unchanged**

```bash
ninja bin/fgx.bin && python3 tools/check_kernel_ceiling.py && ls -l bin/fgx.bin
```

Expected: `bin/fgx.bin` byte size unchanged from before this task (57,578 bytes). Nothing in the core kernel has been touched yet.

- [ ] **Step 11: Commit**

```bash
git add include/kfar.s include/kernel.s src/kernel/far/far.s fgxfar.link.s \
        build.ninja tools/check_kernel_ceiling.py
git commit -m "feat(kernel): far-bank link unit, export table, and a ceiling guard that covers it

bin/fgxfar.bin now builds as a second link unit with its own 57,968-byte
ceiling. Export slots are JMP abs16, not JML, and are never patched: a core
caller's JSL sets PBR to the far bank before the slot executes, so a 16-bit JMP
already lands correctly. Only the caller's JSL operand bank byte needs patching,
which removes an entire patch direction.

Unassigned slots JMP to a red-border halt rather than falling through, matching
the _Phase1_StubHalt contract for unwired MOD_JT slots.

check_kernel_ceiling.py now covers both images and its self-test proves it
rejects an over-ceiling far image, not just an over-ceiling core one.

Nothing calls the far bank yet and bin/fgx.bin is byte-unchanged."
```

---

## Task 2: Stage 2 loads the far bank -- LANDED (790951d8e)

**Much smaller than planned.** The allocator, the rest-anchor slot and the
publication step were all deleted rather than written.

`LoaderAllocKernelBank` already claims `KERNEL_BANKS` ($02) contiguous
bank-aligned banks via one `attrNoSpec` `NewHandle` -- the comment calls it
"image + headroom" -- and the kernel image occupies only the first: it ends at
$EC4A with statics below the $FE00 KGlobals ceiling. Nothing in the tree
referenced `base+1`. So the far bank IS that headroom bank: already claimed,
already locked, already bank-aligned.

    far bank == live kernel bank + 1

which the kernel derives from `PHK`. No second `NewHandle`, no
`REST_KFAR_BANK_OFF`, no `_kFarBank` published static.

What actually landed:

- `src/boot/stage2.s`: after the kernel load, `walk_path` `/KERNELFAR`, set
  `LoadDstBank` = `_LoaderKernBank + 1` (`INC`, 8-bit A in emulation mode), patch
  `_DoPass_MVN_op+1`, `LoadDstOffHi` = `$00`, `LoadDispatch`. Offset $0000, not
  the kernel's $0B00, because the far image must be contiguous from its bank base.
- A missing `/KERNELFAR` is **deliberately non-fatal**: `Far_Init` verifies
  `KFAR_MAGIC` and `_kFarReady` gates every cross-bank call, so absence degrades
  rather than bricks. Halting in the loader would trade a degraded boot for no
  boot at all, before any console exists to say why.
- Named `KERNELFAR`, not `KERNELF`: a filename that is a strict prefix of another
  catalog entry is needless risk in a directory walk.
- `make_disk.sh` stages it before the `disk_src` walk, same rationale as the
  kernel -- a user-file overflow must not silently drop it.
- Disk-image and floppy edges gained `bin/fgxfar.bin` in `tools/ninja/gen.py`,
  because `build.ninja` is GENERATED and gitignored ("do not edit").

**Verified on the emulated machine without spending a kernel byte.** A load that
silently did nothing looks identical to one that worked while nothing reads the
result, so `tools/mame_test/kprobe.py` (non-perturbing, MAME hardware debugger)
read the banks back directly:

    $00:032C  7d 4b                     live kernel bank $7D, magic 'K'
    $7E:0000  46 4b 01 00 00 00 4c 90 00 00 4c 86 00 00 4c 86

'FK', ABI 1, reserved, `JMP $0090` (slot 0 -> `Far_BankInit`), `JMP $0086` (stub
halt) -- byte-identical to `xxd bin/fgxfar.bin` on the host.

---

## Task 3: `Far_Init`, the patch-site generator, and the validity flag

**Files:**
- Create: `tools/gen_far_bankpatch.py`
- Create: `src/kernel/far_patchsites.s` (generated, committed like
  `w5100_patchsites.s`)
- Create: `src/kernel/far/core_patchsites.s` (generated)
- Modify: `src/kernel/main.s` (add `Far_Init` and its boot call)
- Modify: `src/kernel/far/far.s` (fill in `Far_BankInit`'s table walk)
- Modify: `tools/ninja/gen.py` (NOT `build.ninja` -- it is generated and
  gitignored, and hand-edits are wiped on the next regeneration)

**Interfaces:**
- Consumes: `build/fgxfar_Output.txt` (single-segment links emit `_Output.txt`,
  not `fgxfar_S01_*`) and `build/fgx_S01_KernelMain_Output.txt`.
- Produces: `Far_Init` (core, `JSR`-called, `MX %00`, returns `C=1` on success);
  `_kFarReady` (1 byte: `$00` unusable, `$01` patched and callable);
  `_FarPatchTbl`/`_FarPatchEntries`/`_FarPatchBytes` (core-side site table);
  `_CorePatchTbl`/`_CorePatchEntries`/`_CorePatchBytes` (far-side site table).
  Table shape and the walk loop mirror `console_bankpatch.s` +
  `console_init.s:37-49` exactly.

**The far bank number is NOT a stored static.** Task 2 established it as live
kernel bank + 1, so `Far_Init` derives it with the `_BANKK` macro and an `INC`.
There is no `_kFarBank` to publish or keep in sync.

- [ ] **Step 1: Write the generator, self-test first**

`tools/gen_far_bankpatch.py` follows `gen_w5100_patchsites.py`'s interface: it
takes a listing, an output path, and supports `--check` (regenerate and diff,
fail on drift) and `--self-test`.

Marker convention, matching `console_bankpatch.s`: a cross-bank site carries a
`_kfp###` (core->far) or `_cfp###` (far->core) label **on the instruction line**,
so the label's address is the opcode address, and the generator emits
`DA <label>+N` where N is the operand's bank-byte offset -- `+3` for
`JSL`/`LDAL`/`STAL`, `+1` and `+2` for `MVN`.

As built, the generator enforces three things beyond emitting the table:

- a marker is accepted only on `JSL`/`LDAL`/`STAL`/`MVN` -- the instructions that
  actually *have* an operand bank byte -- and rejected on anything else, which
  covers a marker mistakenly left on a `JSR`. A bare marker on its own line is
  rejected too: it would carry the *next* instruction's address.
- every `JSL` whose operand is a `KFAR_*` symbol must carry a marker, or it would
  never be patched and would jump to the assembler's baked `FGX_KFAR_BANK` ($08).
  This rule runs on the `core` direction only; the far side has no symbol
  convention to key off. Comments are stripped before tokenizing.
- marker labels must be unique, since a duplicate means two sites share one table
  entry and one goes unpatched.

Sibling guard `tools/check_far_calls.py` separately rejects `JSR`/`JMP` to a
`KFAR_` slot; the two do not overlap.

```python
def _selftest():
    """Prove the generator can FAIL.  A generator that only ever succeeds is
    indistinguishable from one that never ran."""
    fails = []
    # a listing with a marked site must produce exactly one DA entry
    if len(sites_from(SAMPLE_ONE_SITE)) != 1:
        fails.append("failed to find a marked site")
    # an unmarked JSL into the far bank must NOT be silently ignored
    if not raises_on(SAMPLE_UNMARKED_CROSSBANK):
        fails.append("accepted an unmarked cross-bank site")
    # --check must reject a stale committed table
    if not raises_on_stale(SAMPLE_ONE_SITE, stale_table=""):
        fails.append("--check accepted a stale table")
    if fails:
        raise SystemExit("gen_far_bankpatch self-test FAILED: " + "; ".join(fails))
```

- [ ] **Step 2: Run the self-test and watch it fail**

```bash
python3 tools/gen_far_bankpatch.py --self-test
```

Expected: FAIL until all three behaviours are implemented. Do not proceed while
any of the three still passes vacuously.

- [ ] **Step 3: Implement `Far_Init` in the core kernel**

```
;==============================================================================
; Far_Init - make the far kernel bank callable.
;
; 1. Read _kFarBank.  $00 means stage 2 did not load it -- leave _kFarReady = 0.
; 2. Verify KFAR_HDR_MAGIC reads $4B46 and KFAR_HDR_ABIVER matches
;    KFAR_ABI_VERSION.  A far image from a stale disk is worse than none.
; 3. Walk _FarPatchTbl, storing _kFarBank into each listed operand bank byte.
; 4. JSL <farbank>:KFAR_INIT with A = the core bank, so the far bank patches its
;    own side.
; 5. Set _kFarReady = 1.
;
; In:  MX %00, kernel DBR.
; Out: C=1 and _kFarReady=1 on success; C=0 and _kFarReady=0 otherwise.
;==============================================================================
```

Failure must be loud and must not fall through into an unpatched `JSL` -- an
unpatched operand would jump into bank `$00` at a far-bank offset. On failure,
log through `_BootCon_PutChar` (firmware COUT; the console may itself be in the
far bank later) and halt.

- [ ] **Step 4: Fill in `Far_BankInit`'s table walk**

Replace the Task 1 no-op comment with the walk over `_CorePatchTbl`, storing the
core bank number (passed in A) into each listed operand bank byte. Keep the
`PHB`/`PHK`/`PLB` framing already there; restore DBR before `RTL`.

- [ ] **Step 5: Call `Far_Init` from boot**

In `src/kernel/main.s`, after `Dev_Init` and before anything that could call into
the far bank. Add the permanent boot log line, budgeted tightly -- the core bank
has 304 bytes free:

```
_msg_far_ok     ASC     'far: bank ready',00
_msg_far_none   ASC     'far: absent',00
```

- [ ] **Step 6: Wire the generator edges in ninja**

```ninja
rule farpatch
  command = python3 tools/gen_far_bankpatch.py $listing $out $mode
  description = far patch-sites $out
```

Add `--check` variants to `build/.kernel_checked`, alongside the existing
`gen_w5100_patchsites.py --check`, and add
`python3 tools/gen_far_bankpatch.py --self-test > /dev/null` to the self-test
chain at `build.ninja:83`.

- [ ] **Step 7: Prove the generator is idempotent**

A build step that rewrites its own inputs self-invalidates, and it always looks
like the graph is being conservative.

```bash
ninja && python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt src/kernel/far_patchsites.s core
python3 tools/gen_far_bankpatch.py build/fgx_S01_KernelMain_Output.txt src/kernel/far_patchsites.s core
ninja -n
```

Expected: `ninja: no work to do.` If ninja wants to rebuild, the generator is
not idempotent -- fix that before continuing.

- [ ] **Step 8: Gate**

```bash
tools/gate.sh
```

Expected: GREEN, and the boot log shows `far: bank ready`. Both patch tables are
empty at this point, so `Far_Init` patches nothing -- what is being proven is the
call path into `KFAR_INIT` and back, which is the part that would silently
misbehave later.

- [ ] **Step 9: Commit**

```bash
git add tools/gen_far_bankpatch.py src/kernel/far_patchsites.s \
        src/kernel/far/core_patchsites.s src/kernel/main.s src/kernel/far/far.s build.ninja
git commit -m "feat(kernel): Far_Init, the bank-patch generator, and a validity flag

Far_Init verifies KFAR_HDR_MAGIC and the ABI version before patching anything --
a far image from a stale disk is worse than no far image -- then walks the
core-side patch table and calls KFAR_INIT so the far bank patches its own side.

_kFarReady gates every later cross-bank call. Failure logs through
_BootCon_PutChar (firmware COUT, since the console itself moves to the far bank
in a later phase) and halts, rather than falling through into an unpatched JSL,
which would jump into bank \$00 at a far-bank offset.

gen_far_bankpatch.py follows gen_w5100_patchsites.py: --check rejects a stale
committed table, and --self-test proves the generator fails on an unmarked
cross-bank site and on a stale table. Verified idempotent -- two runs then
'ninja -n' reports no work to do.

Both tables are empty here; what this proves is the KFAR_INIT call path."
```

---

## Task 4: The `JSR`-to-far-symbol guard

**Files:**
- Create: `tools/check_far_calls.py`
- Modify: `build.ninja`

**Interfaces:**
- Consumes: both listings; `include/kfar.s` for the slot EQU names.
- Produces: nothing at runtime. A build-time guard only.

This is the highest-value guard in the whole design and it earns its own task
because a reviewer could reasonably reject it independently.

**Why it exists.** If a symbol moves to the far bank but a call site is left as
`JSR`, the code **assembles cleanly** and jumps to that offset in the *core*
bank, landing in whatever code now occupies it. No link error. No crash at the
call site. Wrong execution somewhere else entirely, at a place with no obvious
connection to the change.

- [ ] **Step 1: Write the self-test first**

```python
def _selftest():
    """Prove the checker can FAIL.  This guard exists for a failure mode that
    assembles cleanly, so a vacuous version of it is worse than none."""
    fails = []
    if not rejects("                JSR     KFAR_CON_WRITE"):
        fails.append("accepted a JSR to a far export slot")
    if rejects("                JSL     KFAR_CON_WRITE"):
        fails.append("rejected a correct JSL")
    if not rejects("                JMP     KFAR_CON_WRITE"):
        fails.append("accepted a JMP to a far export slot")
    if fails:
        raise SystemExit("check_far_calls self-test FAILED: " + "; ".join(fails))
```

`JMP` must be rejected for the same reason as `JSR`: it is a 16-bit branch and
would land in the core bank.

- [ ] **Step 2: Run it and watch it fail**

```bash
python3 tools/check_far_calls.py --self-test
```

Expected: FAIL -- none of the three behaviours exist yet.

- [ ] **Step 3: Implement the checker**

Read the `KFAR_*` slot EQU names from `include/kfar.s`. Scan the core listing's
source column for any reference to one of those names, and assert the mnemonic
is `JSL`. Report file, line and the offending mnemonic. Exit non-zero on any
violation.

- [ ] **Step 4: Verify it passes on the real tree**

```bash
python3 tools/check_far_calls.py --self-test && python3 tools/check_far_calls.py build/fgx_S01_KernelMain_Output.txt
```

Expected: both pass. There are no far exports yet, so the real check passes
trivially -- but the self-test has shown teeth, which is what makes the silence
meaningful.

- [ ] **Step 5: Prove it catches a real violation**

Temporarily change one `JSL` in `src/kernel/far/far.s` to `JSR`, rebuild, and
confirm the checker fails and names the line. Revert.

- [ ] **Step 6: Wire into `kchecks`**

Add to `build.ninja:83`, in both the self-test chain and the real-check chain,
matching the existing pattern.

- [ ] **Step 7: Commit**

```bash
git add tools/check_far_calls.py build.ninja
git commit -m "feat(build): reject JSR/JMP to a far-bank export slot

A boundary call left as JSR ASSEMBLES CLEANLY and jumps to that offset in the
CORE bank, landing in whatever code now occupies it. No link error, no crash at
the call site, and a failure with no obvious connection to the change. JMP is
rejected for the same reason -- it is a 16-bit branch.

Self-test proves all three behaviours: JSR rejected, JMP rejected, JSL accepted.
Confirmed against a deliberately broken tree, not just a clean one."
```

---

## Task 5: Move `sound.s` to the far bank -- phase 1 payload

**Files:**
- Move: `src/kernel/sound.s` -> `src/kernel/far/sound.s`
- Modify: `src/kernel/far/far.s` (PUT it; assign three export slots)
- Modify: `include/kfar.s` (three slot EQUs)
- Modify: call sites -- `src/kernel/main.s`, `src/kernel/syscall.s`,
  `src/kernel/task.s` (the three files that call sound; confirm with the command
  in Step 1)
- Modify: `fgx.link.s` if `sound.s` is PUT there rather than from `main.s`

**Interfaces:**
- Consumes: `Far_Init`, `_kFarReady` (Task 3); the export-slot convention (Task 1).
- Produces: `KFAR_SOUND_BEEP`, `KFAR_SOUND_INIT`, `KFAR_SOUND_STOPDOC` slot EQUs.

`sound.s` is the phase-1 payload because it measured **zero** outbound calls into
core. It isolates the core-to-far direction completely: if it breaks, the fault
is in the call mechanism, not in `kernel_exports`.

- [ ] **Step 1: Confirm the call surface before moving anything**

```bash
grep -rn "JSR\s\+Sound_Beep\|JSR\s\+Sound_Init\|JSR\s\+Sound_StopDoc" --include=*.s src
grep -c "JSR\|JSL\|JMP" src/kernel/sound.s
```

Expected: 4 call sites across 3 files (`Sound_Beep` x2, `Sound_Init` x1,
`Sound_StopDoc` x1), and **no** outbound calls from `sound.s` into core. If the
second command shows calls out, stop -- the measurement has drifted and this is
no longer the right phase-1 payload.

- [ ] **Step 2: Assign the export slots**

In `include/kfar.s`:

```
KFAR_SOUND_BEEP     EQU     KFAR_EXPORT_BASE+$06+4*0    ; slot 0
KFAR_SOUND_INIT     EQU     KFAR_EXPORT_BASE+$06+4*1    ; slot 1
KFAR_SOUND_STOPDOC  EQU     KFAR_EXPORT_BASE+$06+4*2    ; slot 2
```

- [ ] **Step 3: Move the file and add the bank framing**

`git mv src/kernel/sound.s src/kernel/far/sound.s`. Each of the three entry
points gains `PHB`/`PHK`/`PLB` on entry and `PLB` before return, and its `RTS`
becomes `RTL`:

```
Sound_Beep      MX      %00
                PHB
                PHK
                PLB                     ; DBR = far bank for our own data
                ; ... body unchanged ...
                PLB
                RTL
```

Internal `JSR`/`RTS` pairs *within* `sound.s` stay as they are -- they are
same-bank calls.

- [ ] **Step 4: Replace the stub slots with real targets**

In `src/kernel/far/far.s`, the export table's `LUP` block becomes explicit for
the assigned slots:

```
                ORG     FGX_KFAR_CODE+KFAR_EXPORT_BASE+$06
                JMP     Sound_Beep      ; slot 0
                DFB     0
                JMP     Sound_Init      ; slot 1
                DFB     0
                JMP     Sound_StopDoc   ; slot 2
                DFB     0
                LUP     KFAR_SLOT_COUNT-3
                JMP     _Far_StubHalt
                DFB     0
                --^
```

- [ ] **Step 5: Convert the four core call sites**

Each becomes a marked, patchable `JSL`:

```
_kfp001         JSL     KFAR_SOUND_BEEP     ; bank byte patched by Far_Init
```

The `_kfp###` label is what `gen_far_bankpatch.py` looks for. Every one of the
four sites needs its own marker.

- [ ] **Step 6: Build, regenerate, and check**

```bash
ninja && python3 tools/check_far_calls.py build/fgx_S01_KernelMain_Output.txt && python3 tools/check_kernel_ceiling.py
```

Expected: all pass. `check_far_calls` now has real work to do -- four sites.

- [ ] **Step 7: Confirm the core kernel actually shrank**

The whole point is bytes. Measure, do not assume:

```bash
python3 - <<'PY'
import re, collections
tot = collections.Counter()
for path in ("build/fgx_S01_KernelMain_Output.txt",
             "build/fgx_S02_BlockDriver_Output.txt"):
    for line in open(path, errors='replace'):
        p = line.split('|')
        if len(p) < 8: continue
        m = re.match(r'^\d+\s+(\S+)\s+\d+$', p[1].strip())
        if not m: continue
        try: sz = int(p[5].strip())
        except ValueError: continue
        a = p[6].strip().split()[0] if p[6].strip() else ''
        if not a.startswith('02/'): continue
        if not (0x0B00 <= int(a[3:], 16) < 0xEC40): continue
        tot[m.group(1)] += sz
print(sum(tot.values()), "bytes in core code region")
PY
```

Expected: roughly **56,950** (was 57,578; 644 bytes of sound leave, ~20 bytes of
`JSL` widening return). If the number did not drop by several hundred bytes, the
file did not actually leave the core image -- check `fgx.link.s` and `main.s` for
a lingering `PUT`.

- [ ] **Step 8: Gate, and test the sound path specifically**

```bash
tools/gate.sh
```

The gate boots and runs `ls /`, which does **not** exercise sound. A green gate
here proves nothing about `Sound_Beep`. Trigger the beep explicitly -- the
console bell (`printf '\a'`) reaches `Sound_Beep` -- and confirm it does not hang
or halt. A cross-bank call that returns with the wrong DBR typically shows up as
corruption in the *next* unrelated operation, so run `ls /` again afterwards and
confirm the listing is still correct.

- [ ] **Step 9: Re-verify no interrupt path reaches the far bank**

The build cannot check this, so it is checked by hand after every payload move.
An ISR that reaches far-bank code would take a cross-bank call at interrupt time
with whatever DBR the interrupted code had.

```bash
grep -n "Sound_Beep\|Sound_Init\|Sound_StopDoc" src/kernel/toolbox.s \
       src/kernel/sim.s src/kernel/uthernet.s src/kernel/signal.s
```

Expected: no hits, or hits only in boot-time failure paths that end in
`JMP _Kern_Halt`. Read the surrounding lines and confirm which -- a hit inside
`_HBTickTask`'s body or an SCC ISR is a stop-and-re-plan.

- [ ] **Step 10: Commit**

```bash
git add include/kfar.s src/kernel/far/far.s src/kernel/far/sound.s \
        src/kernel/main.s src/kernel/syscall.s src/kernel/task.s build.ninja
git commit -m "feat(kernel): sound.s runs from the far bank -- first payload

sound.s is the phase-1 payload because it measured ZERO outbound calls into
core, so it isolates the core-to-far direction completely: a failure here is in
the call mechanism, not in kernel_exports.

Three exports (Sound_Beep, Sound_Init, Sound_StopDoc), four core call sites
converted to marked JSL. Entry points gain PHK/PLB and return RTL; internal
JSR/RTS pairs are unchanged since they are same-bank.

Core code region measured 57,578 -> ~56,950 bytes. Verified by re-summing the
listing, not by assuming the PUT was removed.

Note the gate boots and runs 'ls /', which does not touch sound -- the bell was
triggered explicitly, and 'ls /' re-run afterwards to catch a wrong-DBR return,
which shows up in the NEXT unrelated operation rather than at the call."
```

---

## Task 6: Move the whole BRAM clock to the far bank, with core-side thunks

**Files:**
- Create: `src/kernel/far/clock.s`
- Modify: `src/kernel/main.s:801-831` (remove `_KCaptureBootTime`, call the slot)
- Modify: `src/kernel/syscall.s` (remove `_Sys_Uptime` 4575-4624, `_Sys_RtcRead`
  4625-4754, `_Sys_RtcWrite` 4755-4838, `_rtcFrame` at 462; add three thunks)
- Modify: `include/memmap.s` (remove `_kBootTime` at :67 from core statics)
- Modify: `src/kernel/far/far.s`, `include/kfar.s`

**Interfaces:**
- Consumes: everything from Tasks 1-5.
- Produces: `KFAR_CAPTURE_BOOTTIME`, `KFAR_SYS_RTCREAD`, `KFAR_SYS_RTCWRITE`,
  `KFAR_SYS_UPTIME` slot EQUs; `_thunk_RtcRead`, `_thunk_RtcWrite`,
  `_thunk_Uptime` in core; `src/kernel/far/clock.s` as the home for all BRAM RTC
  code and both its statics.

**All four routines move in ONE task, and that is not arbitrary.** `_kBootTime`
is written by `_KCaptureBootTime` (`main.s:806-820`) and read by `_Sys_Uptime`
(`syscall.s:4584`). Moving the writer without the reader would leave a far-bank
`STA` and a core-bank `LDA` pointing at different banks' copies of the same
static -- `uptime` would silently read zeroes. Move both, and `_kBootTime`
becomes far-only with no cross-bank access at all.

**The mechanism this task exists to prove.** The syscall dispatch table at
`src/kernel/syscall.s:575` holds `DA <handler>` -- 2-byte offsets with the core
bank implied. A far-bank handler therefore cannot be named directly in the table;
it needs a 5-byte core-side thunk. 15 bytes of thunk relocates 245 bytes of
handler. That ratio only improves for larger handlers, which is what makes this
the door to `syscall.s` (8,785 bytes).

**The hazard.** `src/kernel/syscall.s:4683` warns that **nothing DP-relative may
appear between `TCD` and `PLD`, because `_rtcFrame` is absolute** -- the routine
sets `D=$0000` for the Toolbox call and depends on `_rtcFrame` resolving
DBR-relative rather than through direct page. Moving the routine preserves that
property **only** because `_rtcFrame` moves with it and the far bank's entry
`PHK/PLB` makes DBR the far bank. Leaving `_rtcFrame` in core would break this in
a way the assembler cannot see.

**No far-to-core traffic in this task.** All four routines reach the Toolbox
through the stateless `$E10000` dispatch, not through core kernel symbols. That
is why `kernel_exports.s` is not needed until phase 3 -- see the closing section.

- [ ] **Step 1: Confirm both statics are far-only before moving anything**

```bash
grep -rn "_rtcFrame" --include=*.s src
grep -rn "_kBootTime" --include=*.s src include
```

Expected for `_rtcFrame`: references only from `_Sys_RtcRead` (`syscall.s:4643`)
and `_Sys_RtcWrite` (`:4728`, `:4768`, `:4775`).
Expected for `_kBootTime`: the declaration at `include/memmap.s:67`, writes from
`_KCaptureBootTime` (`main.s:806-820`), and one read from `_Sys_Uptime`
(`syscall.s:4584`).

Every one of those routines is moving in this task, so both statics become
far-only. **If any other file references either static, stop and re-plan** --
a shared static would have to stay in core and be reached by `LDAL`, and for
`_rtcFrame` that breaks the `TCD`/`PLD` window described above.

- [ ] **Step 2: Create `src/kernel/far/clock.s` and move all four routines**

```
;==============================================================================
; clock.s - Battery-RAM real-time clock, far bank.
;
; This is the BRAM RTC, NOT the 60 Hz tick counter.  The tick counter stays in
; the core bank's toolbox.s: it runs in the VBL ISR and _kSystemTicks is read
; directly by sched.s, blkcache.s and write.s.  See docs/history/plans/far-kernel-bank.md S7.
;
; Toolbox calls here use the stateless $E10000 dispatch with NO TLStartUp, the
; idiom sim.s:935 documents and ramdisk.s:649 reuses for ReadBParam.
;
; _rtcFrame and _kBootTime live HERE, not in core statics.  _kBootTime is
; written by _KCaptureBootTime and read by _Sys_Uptime; both are in this file,
; so it never crosses a bank.  Splitting them would leave a far-bank STA and a
; core-bank LDA addressing different banks' copies, and uptime would silently
; read zeroes.
;==============================================================================
```

Move `_KCaptureBootTime`, `_Sys_RtcRead`, `_Sys_RtcWrite` and `_Sys_Uptime`,
each gaining `PHB`/`PHK`/`PLB` framing and returning `RTL`. Declare `_rtcFrame`
and `_kBootTime` in the far bank's static area and remove `_kBootTime` from
`include/memmap.s:67`. Preserve the `TCD`/`PLD` window's comment verbatim -- it
now documents a live constraint that spans banks.

- [ ] **Step 3: Assign slots and replace the stubs**

Slots 0-2 are sound's, from Task 5:

```
KFAR_CAPTURE_BOOTTIME EQU   KFAR_EXPORT_BASE+$06+4*3    ; slot 3
KFAR_SYS_RTCREAD    EQU     KFAR_EXPORT_BASE+$06+4*4    ; slot 4
KFAR_SYS_RTCWRITE   EQU     KFAR_EXPORT_BASE+$06+4*5    ; slot 5
KFAR_SYS_UPTIME     EQU     KFAR_EXPORT_BASE+$06+4*6    ; slot 6
```

Replace the corresponding `JMP _Far_StubHalt` entries in `far.s`'s export table
with `JMP _KCaptureBootTime`, `JMP _Sys_RtcRead`, `JMP _Sys_RtcWrite`,
`JMP _Sys_Uptime`, and shrink the trailing `LUP` count to `KFAR_SLOT_COUNT-7`.

- [ ] **Step 4a: Convert the boot-time capture call site**

`_KCaptureBootTime` is called from boot, not through the syscall table, so it
needs a marked `JSL` rather than a thunk. In `src/kernel/main.s`, where
`JSR _KCaptureBootTime` was:

```
_kfp009         JSL     KFAR_CAPTURE_BOOTTIME   ; bank byte patched by Far_Init
```

- [ ] **Step 4b: Add the core-side syscall thunks**

```
;------------------------------------------------------------------------------
; RTC syscall thunks.  The dispatch table holds 2-byte offsets with the core
; bank implied, so a far-bank handler needs a core-resident stub.  5 bytes each.
;------------------------------------------------------------------------------
_thunk_RtcRead  MX      %00
_kfp010         JSL     KFAR_SYS_RTCREAD    ; bank byte patched by Far_Init
                RTS
_thunk_RtcWrite MX      %00
_kfp011         JSL     KFAR_SYS_RTCWRITE
                RTS
_thunk_Uptime   MX      %00
_kfp012         JSL     KFAR_SYS_UPTIME
                RTS
```

Point the dispatch table entries at the thunks:

```
                DA      _thunk_RtcRead          ; 31: SYS_RTCREAD
                DA      _thunk_RtcWrite         ; 32: SYS_RTCWRITE
```

and the `_Sys_Uptime` entry at slot 51.

- [ ] **Step 5: Verify the syscall table did not drift**

```bash
python3 tools/gen_syscall_table.py --check
```

Expected: pass. This guard exists because syscall-table drift fails at runtime
and silently.

- [ ] **Step 6: Build and run every guard**

```bash
ninja && ninja build/.kernel_checked
```

Expected: all guards pass, including `check_far_calls` (now 7+ sites) and
`check_kernel_ceiling` on both images.

- [ ] **Step 7: Test the syscalls from userland, not just the boot path**

The gate does not call `rtcread`, `rtcwrite` or `uptime`. Exercise them:

```bash
# in the booted image
date              # SYS_RTCREAD via _thunk_RtcRead
uptime            # SYS_UPTIME  via _thunk_Uptime
```

Expected: `date` prints a plausible date; `uptime` increases between two runs.
Then run `ls /` afterwards to catch a wrong-DBR or wrong-stack return, which
manifests in the next unrelated operation.

If `date` shows a 1900 epoch, `_KCaptureBootTime` returned nothing -- either the
Toolbox call lost its `D=$0000` requirement across the bank change, or
`_kBootTime` did not actually move and the writer and reader are addressing
different banks.

- [ ] **Step 8: Re-verify no interrupt path reaches the far bank**

```bash
grep -n "_Sys_RtcRead\|_Sys_RtcWrite\|_Sys_Uptime\|_KCaptureBootTime" \
     src/kernel/toolbox.s src/kernel/sim.s src/kernel/uthernet.s src/kernel/signal.s
```

Expected: no hits. The RTC is reached from the syscall dispatcher and from boot,
never from an ISR -- confirm that is still true rather than assuming it.

- [ ] **Step 9: Measure the total reclaim**

```bash
python3 - <<'PY'
import re, collections
tot = collections.Counter()
for path in ("build/fgx_S01_KernelMain_Output.txt",
             "build/fgx_S02_BlockDriver_Output.txt"):
    for line in open(path, errors='replace'):
        p = line.split('|')
        if len(p) < 8: continue
        m = re.match(r'^\d+\s+(\S+)\s+\d+$', p[1].strip())
        if not m: continue
        try: sz = int(p[5].strip())
        except ValueError: continue
        a = p[6].strip().split()[0] if p[6].strip() else ''
        if not a.startswith('02/'): continue
        if not (0x0B00 <= int(a[3:], 16) < 0xEC40): continue
        tot[m.group(1)] += sz
used = sum(tot.values())
print(f"core code region: {used} bytes, {57968-used} free")
PY
```

Expected: roughly **56,660 used, 1,300 free** (was 390). Sound 644 + clock 302,
less the thunks and `JSL` widening, plus `Far_Init` and its tables.

- [ ] **Step 10: Update the docs and commit**

Add a "Status" line to `docs/history/plans/far-kernel-bank.md` recording phases 1-2 landed and
the measured free-byte count. Add a `docs/CHANGELOG.md` entry.

```bash
git add src/kernel/syscall.s src/kernel/main.s include/memmap.s \
        src/kernel/far/clock.s src/kernel/far/far.s \
        include/kfar.s docs/history/plans/far-kernel-bank.md docs/CHANGELOG.md
git commit -m "feat(kernel): the whole BRAM RTC runs from the far bank

Proves the mechanism that unlocks syscall.s. The dispatch table at syscall.s:575
holds 2-byte DA offsets with the core bank implied, so a far-bank handler needs a
5-byte core-side thunk: 15 bytes of thunk relocated 245 bytes of handler, and the
ratio only improves for larger handlers.

All four routines move together, which is not arbitrary. _kBootTime is written by
_KCaptureBootTime and read by _Sys_Uptime; splitting them across banks would
leave a far-bank STA and a core-bank LDA addressing different copies, and uptime
would have silently read zeroes.

_rtcFrame moves WITH the handlers, and that is load-bearing. syscall.s:4683 warns
nothing DP-relative may appear between TCD and PLD because _rtcFrame is absolute
-- the routine sets D=\$0000 for the Toolbox call. The property survives only
because _rtcFrame is far-only and the far bank's entry PHK/PLB makes DBR the far
bank; leaving it in core would have broken this in a way the assembler cannot
see. Verified far-only before moving.

Core code region 57,578 -> ~56,660 bytes, free 390 -> ~1,300.

Tested through 'date' and 'uptime' from userland, then 'ls /' afterwards -- the
gate never calls these syscalls, and a wrong-DBR return shows up in the NEXT
operation rather than at the call."
```

---

## Wrap-up: push and open the MR

- [ ] **Step 1: Full clean build from scratch**

```bash
tools/cleanroom.sh
```

A stale artifact substituted for a real output has produced a false
byte-identical result in this repo before. Wipe and rebuild before claiming
anything.

- [ ] **Step 2: Gate**

```bash
tools/gate.sh
```

Expected: GREEN, with `.gate/<sha>.json` written.

- [ ] **Step 3: Push the feature branch and open an MR**

```bash
ALLOW_FEAT_PUSH=1 git push -u origin feat/far-kernel-bank
```

Then open an MR describing what landed and what the measured reclaim was.
**Do not self-merge** -- the maintainer merges.

---

## What phases 3-4 will need (not in this plan)

Phase 3 (ramdisk + `loader.s`, 3,764 B) and phase 4 (console, 9,554 B) get their
own plan once this one lands, because their content depends on what phases 1-2
measure.

**`kernel_exports.s` for the far bank is phase-3 work, not phase-1-2 work.**
Nothing in `sound.s` or the BRAM clock calls a core kernel symbol -- sound
measured zero outbound calls, and the clock reaches the Toolbox through the
stateless `$E10000` dispatch. Building the scraper edge now would be machinery
with no consumer. Phase 3 is where far-to-core traffic starts (`Fs_Open`,
`Fs_Read`, `Fs_ReadN`, `Fs_Close`, `Fs_Lseek`, `Bank_Alloc`, `Bank_Free`,
`Kmalloc`, `Kern_LogStr`, `Kern_LogStrNoEOL`, `Kern_LogEOL`, `Kern_LogDec16`,
`Kern_LogHex8`, `_sleep`, `_Halt` -- 15 symbols, 47 sites), and it will need:

- a `far` entry in the `MANIFESTS` dict at `tools/gen_kernel_exports.py:20`,
  listing those 15 symbols so a rename fails the build;
- a `kexports` ninja edge modelled on the four module edges at
  `build.ninja:252-261`;
- the `_cfp###` far-side patch markers, whose generator already exists from
  Task 3 but has had no sites to emit until now.

Two open questions phases 1-2 should answer along the way:

1. **Cross-bank call cost.** Measure `JSL`-plus-`PHK/PLB` overhead against a
   same-bank `JSR` once real payload is running. The console's `Con_PutChar` is
   hot; if the overhead is material, the console's export surface may need to be
   coarser (`Con_Write` batching) rather than per-character.
2. **Blocking across `_sleep` from the far bank.** Phase 3 is the first far-bank
   code that blocks. `net.mod` already does this -- its call frame rides the
   per-task kernel stack across the cooperative `_sleep` -- but it must be
   confirmed for a statically-linked far bank rather than assumed from the module
   case.

Also outstanding, and unrelated to this plan: `feat/smartport-ext-probe` is 9
commits ahead of an older `main` and needs a rebase before it can land.
