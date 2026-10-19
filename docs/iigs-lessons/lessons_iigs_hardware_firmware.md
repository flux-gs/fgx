# IIgs hardware + firmware lessons learned

Strong suggestions for IIgs-specific patterns. Where applicable, cited against
existing iigs-mcp doc pages — these lessons extend the manual coverage, not
replace it.

---

## 1. Use the Toolbox heartbeat for VBL-driven work, not a direct soft-vector install

**Symptom:** You install a VBL IRQ handler at `$E1/0031` (the IIgs soft VBL
vector), enable VGCINT bit 3 (`$00C041 = $08`), set up ACK at `$E0C047`,
and write an RTL handler. The IRQ fires (border-flash diagnostic works,
tick counter increments) — but the keyboard stops working entirely. The
`$E0C000` strobe never asserts again.

**Mechanism:** The IIgs firmware uses the VBL hook to drive its own
keyboard-scan heartbeat task. Replacing the soft vector starves that task.
There is no reliable "share the vector and chain into firmware" pattern —
every attempt either loses keyboard scans, loses VBL ticks, or hangs the
system on warm reset (P=garbage). (Verified across ~6 hours of trial in
the FGX project.)

**Recommended pattern:** install your 60 Hz work as a Toolbox MT
(Miscellaneous Tools) heartbeat task via `SetHeartBeat`
(`toolbox_ref_vol1:661-662`). The firmware's keyboard task and your
custom task both run from the same heartbeat dispatch.

The task descriptor needs:
- `HB_Link` (long, firmware fills): 0
- `HB_TickCount` (word): countdown, decremented each VBL; 0 = inactive.
  RESET this in your task body each fire, otherwise the task goes
  dormant after one tick.
- `HB_Signature` (word, must be byte-pattern $5A,$A5 — note `HEX 5AA5`
  in Merlin emits the bytes in the right order; `DW $5AA5` produces
  $A5,$5A and yields `noSigTaskErr=$0304`).
- body code at +8 (firmware JSLs here, in native, M=1, X=1).

Body discipline:
- `PHP` at entry, `PLP` at exit; RTL not RTI (firmware called JSL).
- `STAL $E0C047` (VBL ACK) is mandatory — without it the dispatcher
  re-fires you in a tight loop and the system freezes.
- Don't touch shared DP scratch — the body fires asynchronously w.r.t.
  any in-flight kernel call.

---

## 2. IIgs keyboard is polled by firmware, not IRQ-driven

**Symptom:** "Keyboard IRQ" attempts get attributed to ADB or VGC, but
nothing you change at `$E0C041` (VGCINT) affects keystroke delivery.

**Mechanism:** The Mega II custom IC latches the most recent key into
`$C000` directly (`hardware_ref:13`). The firmware's "keyboard interrupt"
is actually a VBL-driven polling loop that reads `$C000`, clears the
strobe at `$E0C010`, and dispatches. There is no per-keystroke hardware
interrupt.

**Recommended pattern:** drain `$E0C000` (use bank `$E0`, not `$00` —
see lesson 5 below) at every VBL into a software ring buffer. Consumers
dequeue from the ring without contending with firmware for the strobe.
This decouples key reads from foreground CPU load — important if you
ever spend >16 ms between polls (typical during a full-screen scroll),
because the one-deep Mega II latch overwrites the unread key.

Pattern in FGX's heartbeat body (M=1):
```
            LDAL  $E0C000             ; bit 7 = strobe, bits 6-0 = ASCII
            BPL   no_key
            AND   #$7F
            STAL  $E0C010             ; clear strobe
            ; enqueue A into ring...
no_key
```

The `$E0C025` register (KEYMODREG, `firmware_ref:298`) gives current
Ctrl-key state — useful to disambiguate Ctrl-H/J/K/U from Left/Down/Up/
Right which the Mega II latches as the same bytes ($08/$0A/$0B/$15).

---

## 3. Toolbox bring-up from a raw boot (no GS/OS, no ProDOS-16)

**Symptom:** You want Toolbox access (MM, MT, etc.) on a bare-metal kernel
that boots via SmartPort but doesn't load GS/OS or ProDOS-16. Calling
`_MMStartUp` immediately fails or hangs.

**Mechanism:** `_MMStartUp` expects to be called inside an environment GS/OS
has set up. From a raw SmartPort boot, the environment isn't there.

**Recommended pattern** (verified in FGX from SmartPort boot, also visible
in the `ddiigs` example repo):

```
            ; Native, M=0, X=0, DBR=program bank, DP set up.
            _TLStartUp                ; sets up the Tool Locator
            _MTStartUp                ; Misc Tool Set
            ; Allocate a userID via Tool Locator's GetNewID.
            PEA   $1000               ; idTag = $10 (memory ID), uniq = 0
            _GetNewID
            PLA
            ; A now = $1001 (first ID), use this for all NewHandle calls.
```

Don't call `_MMStartUp` — it's not needed when MM was already brought up
by the IIgs boot ROM, and explicitly starting it again hits the failure
above.

Pre-claim every region your kernel statically owns (BLK_STAGE buffers,
task tables, heap banks) by calling `_NewHandle` with `attrFixed|attrLocked|
attrAddr` and the exact bank/offset. Otherwise MM may allocate over your
kernel data later. The pre-claim table needs one entry per region; FGX
uses ~9 entries plus runtime additions for module banks.

---

## 4. Reading the system clock from a minimal boot

**Symptom:** Calling `_ReadTimeHex` (`toolbox_call:Misc:$0D03`) from a
Toolbox-less boot returns garbage or crashes. Or you want the time
without bringing up Toolbox at all.

**Mechanism:** `_ReadTimeHex` is implemented inside the Misc Tool Set and
requires Toolbox bring-up first.

**Recommended pattern:**

- **With Toolbox available:** call `_ReadTimeHex` (`toolbox_ref_vol1:626`).
  Returns 8 bytes on the stack: `[0]=second [1]=minute [2]=hour [3]=year
  [4]=day [5]=month [6]=weekday [7]=flag`.

- **Toolbox-less (raw boot, super-minimal kernel):** the IIgs clock chip
  is at `$E10000` — a 16-bit address inside bank `$E1`. Direct hardware
  access bypasses Toolbox but you'll need to re-implement the BCD→hex
  conversion and the 7-vs-8-bit AM/PM convention manually. Reference:
  `hardware_ref` chapter on the battery RAM.

**MAME caveat:** the RTC tracks correctly when `-speed` is NOT passed to
MAME. With `-speed`, CPU cycles tick faster but the RTC stays real-time,
so any "ticks per second" calibration breaks.

---

## 5. Soft-switch and I/O register addressing: bank `$E0` not bank `$00`

**Symptom:** You write `STAL $00C034` to set the border color (low nibble
of VGCREG), and the write either has no effect or hits something else.
Reads via `$00C0xx` return inconsistent values.

**Mechanism:** Soft switches and I/O registers in the `$Cxxx` range exist
in both bank `$00` and bank `$E0`, but bank-`$00` accesses are subject to
RAMRD/RAMWRT redirection and 80STORE override. Bank-`$E0` accesses always
reach the I/O space directly (`hardware_ref:19-22`).

**Recommended pattern:** always use bank `$E0` for I/O:

```
            STAL  $E0C034              ; border = A.lo nibble
            LDAL  $E0C000              ; keyboard latch
            STAL  $E0C047              ; VBL ACK
```

NOT:
```
            STAL  $00C034              ; may not hit hardware depending on
                                       ; RAMWRT/80STORE state
```

Particularly important for kernel/driver code that runs with various
soft-switch states — bank-`$E0` is the only reliable path.

---

## 6. Super Hi-Res memory writes: use bank `$01` shadowing, not direct `$E1`

**Symptom:** Direct writes to `$E1:2000` (SHR screen) or `$E1:9D00` (SCBs)
work in some configurations and fail in others, especially under MAME.

**Mechanism:** The IIgs has a SHADOW register (`$E0C035`, `hardware_ref:23`)
that controls which auxiliary-bank ranges get shadowed from bank `$01` to
bank `$E1`. The intended write path is `$01:2000` → shadowed automatically
to `$E1:2000` for display. Direct writes to `$E1:xxxx` may bypass the
shadow mechanism or interact with it in implementation-specific ways.

**Recommended pattern:** write through bank `$01` shadowing for SHR data:

```
            STAL  $012000,X            ; screen pixel data
            STAL  $019D00,X            ; SCBs (scanline control bytes)
            STAL  $019E00,X            ; palette table
```

Direct `$E1Cxxx` accesses for non-shadowed registers (DOC sound, etc.)
are fine — only SHR display memory is shadow-mediated.

**MAME caveat:** direct `$E1xxxx` writes for SHR display were unreliable
across MAME versions tested in the FGX project. Bank-`$01` shadowing is
the safer/more compatible path.

---

## 7. CPU speed measurement via VBL-synced cycle counting

**Symptom:** You want to know if the user has a 1 MHz or accelerated IIgs
(2.8 MHz stock, or third-party accelerators), but `$E0C036` (CYAREG)
only tells you the SETTING, not the actual measured speed (which can
differ on accelerator cards).

**Mechanism:** VBL fires at a fixed 60 Hz regardless of CPU clock.
Counting cycles between two VBL transitions gives actual speed.

**Recommended pattern:**

1. Disable IRQs (`SEI`) for the measurement.
2. Wait for a falling edge of `$E0C019` bit 7 (RDVBLBAR-ish).
3. Increment a counter in a tight loop, periodically polling `$C019`.
4. On the next falling edge, the counter / known-iterations-per-MHz
   gives speed.
5. Use cheap amortized I/O reads (every 256 iters) to avoid skewing the
   cycle count — full-rate polling is dominated by the load instructions.

Result is good to ~5% precision, accurate enough to distinguish 1 MHz,
2.8 MHz (FPI stock fast mode), 4 MHz, and 8 MHz accelerators.

The IIgs ROM ID at `$FE1F` (lesson 8) tells you the ROM version (0, 1, 3)
which constrains plausible speeds — combine with cycle-count for cross-check.

---

## 8. ROM identification: `IDROUTINE` at $FE1F

Already documented (`tn_misc:15`, `tn_iigs:18`). Strong-suggestion summary:

- Enter in emulation mode, JSR `$FE1F`.
- On return, Y[7:0] = ROM version: 0 or 1 = pre-ROM-03 IIgs, 3 = ROM 03.
- The technote example does CLC/XCE inside the routine to enter native
  mode — match this pattern for any "am I on a IIgs" probe at boot.

Practical note: most IIgs project code in the example corpus (e.g.
`gno_kern`, `procmd`) calls IDROUTINE early to gate IIgs-only features.
If your target is ROM 03 only, you can `BCC older_rom_unsupported` and
short-circuit; otherwise branch on Y value.

---

## 9. (CORRECTED) "ProDOS Global Page at `$BF00`" was a misattribution

**This section previously claimed** the kernel DP page at `$00:BF00` was the
ProDOS Global Page, and that DP `$58-$77` aliased live `DEVADR` SmartPort
vectors (`$BF68` = "slot 8 dispatch"). **That is wrong — do not believe it.**

- FGX runs **no ProDOS** (no MLI, no BASIC.SYSTEM). Our "ProDOS" is only an
  on-disk-format FST. The ProDOS Global Page, `DEVADR`, `DEVNUM`, and `MEMTBL`
  are software structures that *ProDOS 8 builds when it is resident* — they do
  not exist in FGX's runtime.
- `$00:BF00` is ordinary **Memory-Manager-controlled RAM**. The IIgs MM's
  reserved (un-managed) bank-0 ranges are only `$0000-$07FF` and `$C000-$FFFF`;
  everything `$0800-$BFFF` (including `$BF00`) is allocatable, and
  `Toolbox_AllocKernelDP` legitimately got a page there via `NewHandle`.
- Even the cited ProDOS addresses were wrong: ProDOS `DEVADR` is `$BF10-$BF2F`
  (that would be DP `$10-$2F`), while `$BF68` falls in `MEMTBL`, not `DEVADR`.

The original 2026-05-14 symptom (shell commands hanging in slot SmartPort
firmware after a new DP allocation) was **real but never correctly
root-caused** — the same commit also fixed an unrelated `MT_SIZE *32` bug, and
the DP relocation likely masked or coincided with the real fix. Treat the cause
as unknown; if you reclaim kernel DP slots, verify empirically rather than
trusting any "DEVADR layout." Lesson within the lesson: a plausible
hardware/firmware story is not a verified one — this whole section was a
confabulation that survived in three source files for weeks.

This bit FGX twice — the second time hung silently because boot completed
normally (kernel itself didn't use SmartPort), then EVERY userland command
hung in slot ROM as soon as it called `Fs_*`. "Boot OK but commands hang"
is the diagnostic signature of this class.

---

## 10. Calling ROM `COUT` / `HOME` from native-mode bank-≠$00 code

**Symptom:** You're writing a small standalone IIgs binary that runs at
`$02:2000` (or any bank other than `$00`), in 65816 native mode. You want
to print a banner using firmware `COUT` (`$FDED`) after clearing the
screen with `HOME` (`$FC58`). Every iteration of "make it work" crashes
in a different unrelated location:

- `JSR $FC58` from bank `$02` → BRK at `$02:FC58` (no ROM in your bank)
- Insert bank-`$00` trampoline via JSL → BRK at `$00:FC58` (HOME's first
  instruction) — the call reached HOME but HOME itself crashed
- Wrap with `SEC/XCE` to emul → banner prints, but post-return RTL pops
  garbage and wild-JMPs to a random bank (PB=$25, PB=$FB, etc.)
- Drop `XCE` and stay native → no crash on entry/exit but banner doesn't
  print (HOME and COUT silently no-op or hang)
- Add stack-recovery via `TSC/STAL ... LDAL/TCS` → banner prints, but
  `PLD/RTL` still pops wrong bytes → wild jump

This is six gotchas stacked on top of each other. Each fix surfaces the
next. The FGX `simtest` standalone took 13 commits across one debug
session to converge.

**Mechanisms** (all six, in the order they bite):

1. **ROM JSR-callable routines (`$FCxx`, `$FDxx`, `$FExx`, `$FFxx`)
   require `PB = $00`.** A `JSR $FC58` uses the current program bank;
   from bank `$02` it targets `$02:FC58`. ROM lives at `$00:FCxx`. You
   need a trampoline in bank `$00`, reached via `JSL`. Equivalent to
   FGX's `CoutTramp` handoff (`src/boot/loader.s`), consumed by
   `_BootCon_Init` / `_BootCon_PutChar` (`src/kernel/boot_console.s`).

2. **ROM HOME and COUT require `DP = $0000`.** They're 6502-era routines
   that read zero-page state (`CH` at $24, `CV` at $25, `BASL`/`BASH`
   at $28/$29, `CSWL`/`CSWH` at $36/$37). If your code uses a custom DP
   page (FGX kernel uses `$0200`, simtest used `$1000`), HOME reads
   BASL/BASH from your-DP+$28 and writes characters through that
   garbage pointer. The wild-jump destinations track wherever the
   garbage points.

3. **ROM HOME and COUT require emulation mode (`E=1`).** Several
   internal ROM helpers do `SEC/XCE` and bank-relative absolute reads
   that assume the emul stack layout. Calling them from native M=X=8
   (which looks 6502-equivalent) either no-ops or hits a stale ROM
   vector that JMPs to an uninitialized address. **Just because the
   register-size flags match (M=X=1) doesn't mean the ROM accepts
   native mode.**

4. **`SEC/XCE` to emul forces `SH=$01` and `CLC/XCE` back does NOT
   restore it.** This is the killer. When you enter emul mode, the
   stack-pointer high byte is forced to `$01` — the previous SH (e.g.,
   `$1F` from your code's native stack) is lost. On the way back to
   native, SH stays at `$01`. Any subsequent stack-relative operation
   (PLD, PLB, RTL, RTS) reads/writes the wrong stack page. **The
   recovery requires saving the 16-bit SP via `TSC / STAL fixed_slot`
   BEFORE entering emul, and restoring via `LDAL fixed_slot / TCS` AFTER
   returning to native.** The save slot CANNOT be on the stack (that's
   what you're trying to recover) — use a fixed RAM cell in your own
   bank, accessed via long absolute.

5. **ROM `HOME` / `COUT` internally `SEC/XCE` to emul mode even if
   their caller is in native.** So even if you carefully stay in native
   M=X=8 around the ROM call, the ROM call itself trips the SH-stranding
   trap from point #4. The SP-save/restore wrap is required regardless
   of YOUR mode-switching discipline.

6. **`TSC` save must happen AFTER `PHD`, not before.** PHD pushes the
   16-bit DP onto the stack. If you `TSC/STAL` before PHD, the saved SP
   reflects the pre-PHD depth — restoring it later positions the stack
   so that PLD pops PCH/PCL of the JSL return frame (not your PHD'd D).
   PLD then corrupts D, and RTL pops the rest of the JSL frame mixed
   with random bytes. Save SP at the depth where PLD will execute, not
   at the depth where the JSL caller pushed.

**Recommended pattern: the bank-`$00` trampoline with full discipline**

Source code lives in your home bank (e.g., bank `$02`); MVN it into
`$00:0300` (or wherever in bank `$00` is free) at startup; JSL in; the
helper does everything else. Helper body, ENTERED IN NATIVE MX %00:

```asm
helper_in_bank_0
                ; --- Native-mode setup -----------------------------------
                ; PHD must come BEFORE TSC so the saved SP positions
                ; PLD correctly for the post-restore pop.
                PHD                             ; save caller DP (native)
                LDA     #$0000
                TCD                             ; DP = 0 (ROM requires)

                ; Save 16-bit SP to a fixed RAM slot in our home bank.
                ; This is what recovers from XCE's SH-stranding.
                TSC
                STAL    _bankhelp_saved_sp      ; 24-bit absolute, any bank

                ; --- Switch to emul mode for ROM compatibility -----------
                SEC
                XCE                             ; E=1; SH now forced $01

                ; --- ROM-callable block (PB=$00, DP=$0, E=1) -------------
                LDA     $C051                   ; soft switches: read toggle
                LDA     $C052
                LDA     $C054
                LDA     $C056
                LDA     $C00C
                JSR     $FC58                   ; HOME
                ; ... LDA char / ORA #$80 / JSR $FDED (COUT) loop ...

                ; --- Switch back to native -------------------------------
                CLC
                XCE                             ; E=0; SH still $01
                REP     #$30
                MX      %00

                ; --- Recover the native stack ----------------------------
                LDAL    _bankhelp_saved_sp
                TCS                             ; 16-bit S restored

                ; --- Restore caller state --------------------------------
                PLD                             ; pops PHD'd D from native stack
                RTL                             ; pops JSL frame from native stack

_bankhelp_saved_sp DA $0000                    ; lives in home bank
```

(For Merlin32, you'll typically put `_bankhelp_saved_sp` in the home-bank
source code outside the MVN'd helper body — both because it's data not
code, and because the MVN range usually excludes it. The helper accesses
it via `STAL`/`LDAL` long absolute regardless.)

**Soft-switch dance specifics** (the IIgs equivalents to Apple II ones,
all read-to-toggle):
- `$C051` — TXTSET — switch to text-mode display
- `$C052` — MIXCLR — full-screen text (no graphics mix)
- `$C054` — PAGE1 — display page 1
- `$C056` — LORES — normal text / lores display path
- `$C00C` — CLR80VID — 40-column text

You only need a few of these depending on prior state; if your code
boots cold, do all five for safety.

**Why MVN, not just `JML $00:helper`?** Your binary is loaded into bank
`$02` by the bootloader. The helper bytes live there at assembly time.
For ROM JSRs (`JSR $FC58`) to work, the helper must execute from
`PB=$00`. MVN copies it once into bank `$00`. JSL `$00:0300` then
executes from there.

**Stage-2 / kernel-display interaction:** if your standalone is replacing
the kernel on a test disk, the FGX kernel sets video registers
(SHADOW=$77, NEWVIDEO=$81, etc.) for SHR-only rendering — but that's
NOT what's reaching simtest, because the kernel never ran on the test
disk. The "all black" surface symptoms during debugging usually trace
back to one of the six mechanisms above, not to shadow-register state
inherited from a previous boot.

**Diagnostic ladder when something doesn't show:**
1. Set border to white (`LDA #$0F / STAL $E0C034`) at the absolute
   first instruction. If border stays grey/black → your binary isn't
   executing at all (boot-handoff issue).
2. After border-white, write recognizable bytes directly to text page 1
   at `$00:0400`. If those don't appear → display mode / shadow issue
   (try `STAL $E0C035` with `$08`).
3. If direct writes appear but COUT doesn't → walk through the six
   gotchas above in order.

**A boot abort can look like your binary not running.** If stage 2 fails to
load the kernel image (no handoff), the symptom resembles "your standalone
binary isn't running" -- verify with a border-color diagnostic FIRST before
going down the rabbit hole.

---

## Cross-references

- `toolbox_ref_vol1:661-662` — `SetHeartBeat` and Heartbeat Interrupt Task.
- `toolbox_ref_vol1:626` — `_ReadTimeHex` (Misc Tool Set $0D03).
- `firmware_ref:46-49` — soft vector layout including VBL at `$E1:0031`.
- `firmware_ref:298` — KEYMODREG ($E0C025) bit layout.
- `hardware_ref:13-15` — Mega II IC and keyboard latch.
- `hardware_ref:19-23` — shadow register, speed register, I/O space.
- `hardware_ref:23, 36` — SHR shadowing detail.
- `tn_misc:15`, `tn_iigs:18` — IDROUTINE usage.
- `beneath_prodos` — ProDOS Global Page layout.
- Example corpus: `ddiigs` (Toolbox bring-up from Merlin32 ProDOS boot),
  `gno_kern` (Unix-shaped kernel with similar VBL/heartbeat needs),
  `procmd` (ProDOS-8 shell with IIgs awareness).
