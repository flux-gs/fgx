# Far kernel bank - design

**Status:** phases 1, 2 and 4 LANDED 2026-08-01. Phases 1-2 merged as MR !35;
phase 4 (console) on `feat/far-console`.

Core kernel 57,578 -> **47,545 B** of the 57,968 ceiling: free space 390 ->
**10,423**. Far bank 11,080 B of 60,480. Sound driver, BRAM RTC and the whole
console driver (17 files) run from the far bank; four syscalls and 14 console
export slots reach it, 53 core->far and 27 far->core patch sites.

Phase 3 (`loader.s`) is **DONE, 2026-08-23**, and stopped being optional in the
eight weeks after that paragraph was written.  The 10,423 bytes phase 4 bought
were spent: UFS 1.7d I2 took 1,388 of them and the tty bank's own apparatus
another 310, leaving the core kernel **67 bytes free** with the tty campaign's
next increment needing 747.  Moving `loader.s` out took it to **2,554 free**.

The `ramdisk` half of the original phase-3 pairing was not needed and is not
done: ramdisk is a module already, and the 96 bytes it still occupies in the
core bank are not worth a bank crossing.

**One bug class the console move exposed, worth reading before adding to the far
bank:** a far-bank routine that is ALSO an export-table target ends in RTL, but
its far-bank neighbours call it with a same-bank JSR, which pushes two bytes
where RTL pulls three. `Far_BootChime` did this to `Sound_Beep`; the chime
sounded, the routine "worked", and boot hung somewhere unrelated. The fix is the
`*Impl` split (RTS body + RTL wrapper) used by MOD_JT and `far_shims.s`, and
`tools/check_far_rtl_calls.py` now fails the build on any recurrence.

Corrections the build forced on this design, all now reflected below: the far
bank needs no allocation (it is the kernel handle's headroom bank), the export
table must sit at bank offset $0000 because merlin32 does not pad between ORGs,
slot 0 is the init entry, and far-bank absence is FATAL rather than degraded now
that boot-critical code lives there.
**Problem:** the kernel bank is full. 57,578 of 57,968 bytes used; **390 free**.
**Goal:** relocate 14,264 bytes of subsystem code into a second statically-linked
kernel bank, restoring headroom in the core bank and leaving the moved code
module-shaped so a later promotion to FGXM is a link change rather than a
rewrite.

---

## 1. Why now, and why not the obvious alternatives

The `FGX_DATA` lever is spent. Static-side reclaim is exhausted, so the next
byte has to come out of *code*. Three options were weighed:

**Reject: keep shrinking in place.** 304 bytes is below the noise floor of a
single feature. The SmartPort capability layer (2026-07-31) already had to be
built with `_LogBlkCaps` excluded and every `ASC` string trimmed just to link.
There is not enough room left to *refactor*, let alone add.

**Reject: FGXM modules alone.** The loadable-module framework is mature (five
modules ship), but it cannot take this work on its own:

- Modules cannot allocate kernel heap. `SYS_KMALLOC`/`KFREE`/`BANKALLOC`/
  `BANKFREE` are deliberately unwired. Measured below, the candidate code calls
  `Kmalloc` and `Bank_Alloc`/`Bank_Free`.
- Runtime modules load from `/etc/modload.conf`, which requires a live
  filesystem. `_KCaptureBootTime` and `Con_Init` both run long before that.
- **The module jump table is full.** `include/modules.s`: `MOD_JT_BASE+$06+4n`,
  32 slots, slot 31 (`+$82`) is `SYS_NETKC_SLEEP`. All 32 are allocated. Six are
  unwired-and-reusable, which is scavenging, not headroom.

**Accept: a second statically-linked kernel bank.** It has none of those three
constraints - it is present from boot, it is ordinary kernel code that may call
anything, and it needs no ABI slot. It is *module-shaped* (own DBR via PHK/PLB,
kernel statics reached by scraped offset), so the refactoring effort is not
wasted if a subsystem is later promoted to a real FGXM module.

### Naming

The second bank is the **far bank**. Code in it is **far-bank code**; the
existing kernel bank is the **core bank**. `FGX_BANK_KFAR` names the constant.
Not "module", to keep it unambiguous that this is not an FGXM module.

---

## 2. Measurements

All figures are summed from the Merlin32 listings
(`build/fgx_S01_KernelMain_Output.txt`, `build/fgx_S02_BlockDriver_Output.txt`)
over the code region `$02:0B00`-`$02:EC40`, per source file. Reproduce with the
script in appendix A.

### 2.1 Where the 57,578 bytes are

| Subsystem | Bytes | % |
|---|---:|---:|
| console (13 files) | 9,554 | 16.6 |
| `syscall.s` | 8,785 | 15.2 |
| process + task + sched + signal | 8,653 | 15.0 |
| fs drivers (fs, bitmap, write, inode, path, fcb) | 6,914 | 12.0 |
| pty + pipe | 3,400 | 5.9 |
| `loader.s` | 2,671 | 4.6 |
| uthernet + sim | 2,598 | 4.5 |
| blkcache + block | 2,184 | 3.8 |
| ramdisk | 1,093 | 1.9 |
| sound | 644 | 1.1 |
| `toolbox.s` | 656 | 1.1 |

### 2.2 What moves

| Payload | Bytes |
|---|---:|
| console (13 files) | 9,554 |
| `loader.s` | 2,671 |
| ramdisk | 1,093 |
| `sound.s` | 644 |
| BRAM clock (section 2.5) | 302 |
| **Total** | **14,264** |

Core bank after: **43,314 / 57,968 used, 14,654 free** (from 390).
Far bank after: **14,264 / 57,968 used, 43,704 free** for later migration.

### 2.3 The call boundary - 38 symbols, 94 sites

Core to far, 23 distinct symbols across 47 call sites:

| Group | Symbols | Sites |
|---|---:|---:|
| console | 14 | 30 |
| loader | 3 | 10 |
| ramdisk | 3 | 3 |
| sound | 3 | 4 |

Console's 14, with site counts: `Con_Write` (4), `Con_PollKey` (4),
`Con_RenderAll` (3), `Con_ShowCursor` (3), `Con_CR` (2), `Con_PutChar` (2),
`_Con_InitSCBs` (2), `_Con_InstallPalettes` (2), `Con_HideCursor` (2),
`Con_GetKey` (2), `Con_WriteBuf`, `Con_Init`, `Con_LoadFontFromFile`,
`Con_RevertToDefault`. Loader's three are `Load_Binary` (4),
`_Loader_ArgsExtraPages` (3), `_Loader_StageArgs` (3).

Far to core, 15 distinct symbols across 47 call sites: `Fs_Close` (10),
`Bank_Free` (9), `Fs_ReadN` (5), `Kern_LogStrNoEOL` (4), `Fs_Open` (3),
`Fs_Read` (3), `Kern_LogStr` (3), `_Halt` (2), `Kern_LogEOL` (2), `_sleep`,
`Kmalloc`, `Fs_Lseek`, `Bank_Alloc`, `Kern_LogDec16`, `Kern_LogHex8`.

`Kmalloc` and `_sleep` in that list are the concrete proof that this payload
could not be an FGXM module.

### 2.4 The data boundary - 54 patched sites, not 263

Of 297 statics declared in `include/memmap.s`, the far-bank payload touches 29.

- **14 far-only statics, 150 access sites.** Touched only by moving code. They
  move to the far bank's static region and stay DBR-relative. **Zero cost.**
- **`CON_VT_STATE`: 209 far accesses, 14 core accesses.** Overwhelmingly
  console-owned. It moves with the console; the 14 core touches get rerouted
  (accessor or a small core-side shim). Removes 209 sites from the patch set.
- **Remaining 14 shared statics, 54 far-side sites.** These need `LDAL` with a
  boot-patched bank byte: `_fsDirBuf` (23), `_frnDstOff` (7), `_diskStates` (5),
  `_frnDstBank` (5), `_kFontsBank` (4), `_kKbdRingCount` (2), and eight singles
  (`_kFgxUserID`, `_blkSrcPool`, `_kBlkTabBase`, `_kKbdRing`, `CurrentFontName`,
  `_kConsoleBank`, `_docOwner`, `_fsLsWhence`).

54 patched sites is well within the proven envelope: `console_bankpatch.s`
already carries 30+ generated entries for the console framebuffer relocation.

### 2.5 The BRAM clock

Scope note: this is the **battery-RAM real-time clock**, not the 60 Hz tick
counter. The two are unrelated and the tick counter is explicitly out of scope
(section 7).

| Routine | Location | Bytes |
|---|---|---:|
| `_Sys_RtcRead` (syscall #31) | `syscall.s:4625` | 105 |
| `_Sys_RtcWrite` (syscall #32) | `syscall.s:4755` | 103 |
| `_KCaptureBootTime` (ReadTimeHex at boot) | `main.s:816` | 57 |
| `_Sys_Uptime` (syscall #51) | `syscall.s:4575` | 37 |
| **Total** | | **302** |

Plus the `_rtcFrame DS 6` staging static at `syscall.s:462`. It is touched only
by `_Sys_RtcRead` (`:4643`) and `_Sys_RtcWrite` (`:4728`, `:4768`, `:4775`), both
of which move, so it is **far-only**: it moves with them, stays DBR-relative, and
needs no patching.

`_rtcFrame` carries a hazard worth calling out for phase 2. `syscall.s:4683`
warns that "NOTHING DP-relative may appear between TCD and PLD -- `_rtcFrame` is
absolute": the routine sets `D=$0000` for the Toolbox call and depends on
`_rtcFrame` resolving DBR-relative rather than through direct page. Moving the
routine keeps that property only because `_rtcFrame` moves with it and the far
bank's entry `PHK/PLB` makes DBR the far bank. If `_rtcFrame` were left in core,
this routine would break in a way the assembler cannot see.

302 bytes does not justify a phase on its own. It earns one because it is the
**smallest possible proof of a far-bank syscall handler**, and that mechanism is
the door to `syscall.s` (8,785 bytes, the largest single file in the kernel).
The clock is a good first test of it because it is self-contained, touches one
static, and - unlike the tick counter - is not on an interrupt path.

All four routines reach the Toolbox via the stateless `$E10000` dispatch with no
`TLStartUp`, the idiom `sim.s:935` documents and `ramdisk.s:649` reuses for
`ReadBParam`. `ramdisk` is already in the payload; `sim.s` is not, and its
`ReadBParam` use is left alone.

### 2.6 Interrupt safety

No far-bank payload symbol is reached from an interrupt handler. Verified:

- `_Con_FlushDeferred` is defined in `syscall.s:2225` (core, stays core) and
  called from `syscall.s:2101`, `:3435`, `:4539`.
- The only console calls from `toolbox.s` are `Con_CR` at `:89` and `:156`, both
  in boot-time Toolbox-failure paths ending in `JMP _Kern_Halt`, not in the
  heartbeat body.

This must be **re-verified after each phase**, since it is an invariant the
build cannot check.

---

## 3. Architecture

```
core bank (MM-assigned)                far bank (MM-assigned)
+----------------------------+         +----------------------------+
| syscall, process, task,    |  JSL    | console (9,554)            |
| sched, signal, fs, block,  |-------->| loader.s (2,671)           |
| pty, pipe, uthernet, sim   |<--------| ramdisk (1,093)            |
| toolbox, modload, jumptable|  JSL    | sound.s (644)              |
| statics $EC40..$FE00       |         | BRAM clock (302)           |
+----------------------------+         | own statics                |
  43,314 / 57,968                      | export table at $FE00      |
  free 14,654                          +----------------------------+
                                         14,264 / 57,968, free 43,704
```

Both banks are allocated by the Memory Manager at boot and relocated; neither
has a fixed bank number.

### 3.1 Two link units

`fgxfar.link.s` is a sibling of `fgx.link.s`, producing `bin/fgxfar.bin` from
`src/kernel/far/far.s`, which `PUT`s the moved files. A separate link unit
rather than a third `SNA` segment, because Merlin32 concatenates segments into
one image at one `ORG` - a third segment would share the core bank's 57,968-byte
ceiling and buy nothing. A separate link gets its own ceiling and its own
listing.

### 3.2 Core to far: a fixed export table

Merlin32 has no cross-link-unit linker, so the two directions use different
mechanisms. Core reaches far only through a **fixed export table** at the top of
the far bank, declared positionally by EQU in a new `include/kfar.s`:

```
KFAR_EXPORT_BASE  EQU  $FE00      ; offset within the far bank
KFAR_ABI_VER      EQU  KFAR_EXPORT_BASE+$00   ; word
KFAR_BUILD        EQU  KFAR_EXPORT_BASE+$02   ; word
KFAR_RESERVED     EQU  KFAR_EXPORT_BASE+$04   ; word
KFAR_CON_WRITE    EQU  KFAR_EXPORT_BASE+$06   ; slot 0
KFAR_CON_POLLKEY  EQU  KFAR_EXPORT_BASE+$0A   ; slot 1
...
```

Same shape as `MOD_JT_GATEWAY` (6-byte header, then 4-byte `JML` slots) for
consistency with the framework the team already reads. 23 symbols fit in 32
slots with room; the table is sized 32 from the start so adding an export is not
a layout change.

A core call site becomes `JSL $00FE06` with the bank byte patched at boot. The
target's `RTS` becomes `RTL`.

### 3.3 Far to core: scraped offsets

`tools/gen_kernel_exports.py` **already exists** and already does exactly this
job for FGXM modules - it scrapes symbol addresses out of the freshly built
kernel listing into a per-consumer `kernel_exports.s`. It gains a far-bank
consumer. No table, no slot budget: far code calls `JSL <scraped offset>` with
the bank byte patched at boot, and reads shared statics with `LDAL <scraped
offset>`, same patch.

The generator is the drift guard: a renamed or removed core symbol fails the
build.

### 3.4 Build order is acyclic

```
1. build core            -> bin/fgx.bin + core listing
2. gen_kernel_exports.py -> src/kernel/far/kernel_exports.s
3. build far             -> bin/fgxfar.bin + far listing
4. gen_far_bankpatch.py  -> the two patch-site tables
```

The cycle is broken by the asymmetry in 3.2/3.3: core needs **no** far address at
build time, because it reaches far only through fixed EQU offsets. Far needs core
addresses, and gets them from step 2.

Step 4 must not rewrite an input to steps 1-3. Running the generators twice and
then `ninja -n` must report no work to do.

### 3.5 DBR discipline

Each far-bank export does `PHK/PLB` on entry, exactly as `mod_init` does today,
so DBR is the far bank inside far code and its own inline data (strings,
dispatch tables, font bitmaps) resolves DBR-relative for free. Access to a
**shared core static** is `LDAL` with a boot-patched bank byte - the 54 sites of
section 2.4.

Far code must restore the caller's DBR before `RTL`.

### 3.6 Bank patching

Two generated tables of patch sites, one per direction, walked by `Far_Init` at
boot. This is the `console_bankpatch.s` mechanism, whose generator
(`docs/superpowers/reloc-tools/gen_console_bankpatch.py`) already emits a table
of `DA <site>+3` entries for `LDAL`/`STAL` operand bank bytes and `+1`/`+2` for
`MVN` operands. `tools/gen_far_bankpatch.py` is a clone with two outputs.

The console has already been through one bank relocation of this exact shape
(framebuffer `$03` -> dynamic `_kConsoleBank`), which is direct evidence the
approach holds at this scale.

### 3.7 Far-bank syscall handlers

The dispatch table at `syscall.s:575` is `DA <handler>` - 2-byte offsets, core
bank implied. A handler in the far bank therefore needs a **core-side thunk**:

```
_thunk_RtcRead  JSL  KFAR_RTC_READ    ; bank byte patched by Far_Init
                RTS
```

5 bytes of core thunk per moved handler. For the clock: 15 bytes of thunk to
relocate 245 bytes of handler, net **230 bytes**. The ratio only improves for
larger handlers, which is what makes this the door to `syscall.s`.

---

## 4. Boot sequence

1. Stage 2 allocates the far bank. `LoaderAllocRestBank` already allocates a
   second dynamic bank beside the kernel bank; the far-bank allocator is a clone
   of it.
2. Stage 2 loads `/KERNELF` into that bank with the existing multipass MVN,
   patching the destination bank operand at `_DoPass_MVN_op+1` - the same loop
   that already stages FGXM modules into successive banks.
3. Stage 2 publishes the far bank byte in the rest-anchor block, beside
   `REST_CONSOLE_BANK_OFF` and `REST_FONTS_BANK_OFF`.
4. The kernel's `FGX_Entry` calls `Far_Init`, which walks both patch tables and
   fixes every bank byte in both directions.
5. Everything after `Far_Init` may call into the far bank.

**Boot logging across the gap.** The console lives in the far bank, so nothing
console-based works before step 4. `src/kernel/boot_console.s` exists for exactly
this window: `_BootCon_PutChar` emits through the bank-0 `CoutTramp` thunk to
firmware COUT at `$00:FDED`, with its `JSL` operand patched from the loader
handoff. Any kernel log message emitted before `Far_Init` uses that path.

**Failure handling.** If the far bank fails to load or `Far_Init` cannot patch,
the machine cannot bring up a console, so the failure must be reported the way
stage 2 reports pre-console failures today: a border-colour signal plus halt. It
must not fall through into an unpatched `JSL`, which would jump into bank `$00`
at a console offset. `Far_Init` sets a validity flag that the failure path
checks.

---

## 5. Guards

Every guard below exists because an ungated version of this work would fail
silently.

| Guard | Catches | Basis |
|---|---|---|
| `check_kernel_ceiling.py` extended to both images | either bank overflowing | exists; derives its limit from `FGX_DATA - FGX_CODE` rather than copying it |
| `gen_kernel_exports.py` on the far consumer | a renamed/removed core symbol | exists; the generator failing *is* the check |
| **`JSR`-to-far-symbol check** | a boundary call left short | **new, and the highest-value guard here** |
| `Far_Init` validity flag | an unpatched bank byte reached at runtime | new |
| generator idempotency (`ninja -n` clean after two runs) | a build step rewriting its own inputs | recurring failure mode in this repo |
| post-phase ISR re-verification | far-bank code reached from an interrupt | manual; the build cannot check it |

The `JSR` check deserves emphasis. If a symbol moves to the far bank but a call
site is left as `JSR`, **the code assembles cleanly** and jumps to that offset in
the *core* bank - landing in whatever code now occupies it. No link error, no
crash at the call, just wrong execution somewhere else. The patch-table generator
knows the full set of boundary symbols, so it must also assert that every
reference to one is `JSL`.

---

## 6. Phases

Ordered so each phase exercises one new mechanism against the smallest payload
that can prove it.

### Phase 1 - mechanism, with `sound.s` (644 B)

Sound measured **zero** outbound calls into core, so it isolates the core-to-far
direction completely. Delivers: `fgxfar.link.s`, `src/kernel/far/far.s`,
`include/kfar.s`, the stage-2 far-bank allocate + load + publish, `Far_Init`,
`gen_far_bankpatch.py`, the `JSR` guard, and `check_kernel_ceiling.py` covering
both images. Proves: allocate, load, publish, patch, cross-bank call and return.

### Phase 2 - BRAM clock (302 B)

Adds the far-bank **syscall handler** mechanism: three core-side thunks
(`_Sys_RtcRead`, `_Sys_RtcWrite`, `_Sys_Uptime`), `_KCaptureBootTime` moved, and
`_rtcFrame` moved with them as a far-only static. Proves the mechanism that later
unlocks `syscall.s`. Watch the `TCD`/`PLD` window described in 2.5.

### Phase 3 - ramdisk + `loader.s` (3,764 B)

First real far-to-core traffic: `Fs_Open`/`Read`/`ReadN`/`Close`/`Lseek`,
`Bank_Alloc`/`Free`, `Kmalloc`, `Kern_Log*`. Proves the scraped-offset path and
that a far-bank caller can block across `_sleep` on the per-task kernel stack -
the same crossing `net.mod` already performs.

### Phase 4 - console (9,554 B) -- DONE 2026-08-01

The payload the whole design is for. `CON_VT_STATE` migrated to the far bank at
the fixed offset `KFAR_VT_STATE`, its core touches rerouted through `_kfp3xx`
long-addressed sites, all 17 console files moved, and `boot_console.s` confirmed
to cover the pre-`Far_Init` window (the boot log reaches the SHR console
normally, and the far bank's own failure path halts loudly).

Two things the phase forced that the plan did not anticipate:

- **The path bank was undeclared, not fixed.** `Path_Resolve` read the path
  DP-indirect, taking the bank from DBR, so the real contract was "the path is in
  whatever bank the caller runs in" -- invisibly true while every caller was
  kernel-bank code. It now travels explicitly in `_fsPathPtr` (three DP bytes
  carved from the front of the reserved `$00-$0F` block, which shifts nothing
  below it and so leaves prodos.mod's hardcoded `KDP_fsTmp2 $1A` alone).
- **A far-bank caller still cannot pass a far-bank pointer to `Fs_Open`.**
  `_Sys_PathResolveImpl` and prodos.mod's FOP path re-enter with a bare offset
  and DBR already forced to the kernel bank, so the bank cannot survive the FOP
  dispatch however far it travels inside `Fs_Open`. `_FarSh_Fs_Open` copies the
  path into `_fsFarPathBuf` at the boundary instead, and refuses truncation
  rather than opening the wrong file. Any future shim taking a pointer needs the
  same treatment: setting DBR fixes the callee's statics and simultaneously makes
  its pointer argument unreadable.

---

## 7. Out of scope

**The 60 Hz tick counter.** All of `toolbox.s` is 656 bytes and the heartbeat is
a fraction of it. It runs in the VBL ISR, and `_kSystemTicks` is read directly
via `LDA |_kSystemTicks` from `sched.s:479`, `blkcache.s:106,211`, and
`write.s:139,149,387,394,437,444`. Moving the counter breaks all of those;
moving only the incrementer saves roughly 150 bytes and puts a cross-bank `JSL`
on a 60 Hz path. Wrong trade at any price. (Distinct from the BRAM clock, which
is in scope - see 2.5.)

**Widening the 32-slot module jump table.** Required before further FGXM
extraction, but page 3 is boxed: `MOD_JT_GATEWAY` `$032E..$03B3`, then
`_cdTrampJSL $03B8`, `_fstTrampJSL $03BD`, `_netTrampJSL $03C2`, a 5-byte dead
hole at `$03C7`, and `KFGX_REST_ANCHOR $03CC`. Widening means relocating the
gateway or adding a second one. Separate spec.

**VFS drivers (6,914 B)** and **pty/pipe/sim/uthernet (5,998 B).** Deferred into
the 43,704 bytes this leaves free in the far bank. VFS needs measurement first:
it is a hub the already-modular ProDOS FST calls back into via `SYS_PATHRESOLVE`
/ `SYS_FCBALLOC` / `SYS_BMALLOC`, so moving it would put a bank crossing on a
path that already crosses one. `sim.s` and `uthernet.s` both hold ISRs, so
cross-bank interrupt dispatch must be proven before either moves.

**`syscall.s` (8,785 B).** Phase 2 builds the mechanism; actually migrating
handlers is a later spec.

**Promotion of any far-bank subsystem to a real FGXM module.** The console is
the obvious candidate - `VT_CONSOLE` and `MOD_REGISTERCONSOLE` are already
reserved in the ABI - but it is gated on the jump-table widening.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| A boundary call left as `JSR` assembles and silently misjumps | the generated `JSR` guard (section 5) |
| Console latency: `Con_PutChar` gains a cross-bank `JSL` | measure after phase 4; the console already crosses banks for its framebuffer |
| `CON_VT_STATE`'s 14 core touches are harder to reroute than they look | audit them in phase 4 before moving the file; fall back to leaving `CON_VT_STATE` in core and patching 209 sites (mechanically fine, just larger) |
| Far bank fails to load, leaving no console for the diagnostic | `boot_console.s` firmware COUT path plus border-colour signal (section 4) |
| MM cannot supply a second bank on a small machine | the far bank is one of two MM allocations already made at boot; failure is reported, not silently degraded |
| A phase leaves an ISR reaching far code | manual re-verification each phase (section 2.6) |

---

## Appendix A - reproducing the measurements

Per-file code bytes in the core bank:

```python
import re, collections
tot = collections.Counter()
for path in ("build/fgx_S01_KernelMain_Output.txt",
             "build/fgx_S02_BlockDriver_Output.txt"):
    for line in open(path, errors='replace'):
        p = line.split('|')
        if len(p) < 8:
            continue
        m = re.match(r'^\d+\s+(\S+)\s+\d+$', p[1].strip())
        if not m:
            continue
        try:
            sz = int(p[5].strip())
        except ValueError:
            continue
        addr = p[6].strip().split()[0] if p[6].strip() else ''
        if not addr.startswith('02/'):
            continue
        if not (0x0B00 <= int(addr[3:], 16) < 0xEC40):
            continue
        tot[m.group(1)] += sz
print(sum(tot.values()), "bytes")          # 57664
for f, n in tot.most_common():
    print(f"{n:7d}  {f}")
```

Byte cost of a named routine: same parse, but match on `os.path.basename` of the
file column and a source-line range, since the listing records nested `PUT` files
by relative path (`../kernel/syscall.s`) while the segment root appears bare
(`main.s`).

Call boundary and static usage: parse `JSR`/`JMP` targets and
`LDA`/`STA`/`INC`/... operands out of the sources, partitioned by whether the
containing file is in the far payload; cross-reference statics against the
`DS`/`DA`/`DW`/`DFB`/`ASC` declarations in `include/memmap.s`.
