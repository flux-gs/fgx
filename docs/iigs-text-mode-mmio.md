# IIgs 40/80-column text mode via memory-mapped I/O

Practical reference for FGX-internal code that needs to render
to the Apple IIgs text page without using firmware COUT. Covers
40-column and 80-column modes, the soft-switch dance, the
shadow register interaction, the interleaved row addressing,
and how to switch between modes at runtime.

This doc exists because FGX simtest spent ~15 commits in
2026-05-26 deriving this from first principles after the
firmware-COUT path turned out to require a six-gotcha dance
(see `docs/iigs-lessons/lessons_iigs_hardware_firmware.md` §10).
The MMIO path is dramatically simpler — stay in native MX %00
throughout, no XCE, no PB constraint, no DP constraint, no SP
discipline. The cost is doing your own font rendering (the IIgs
hardware does that for you in classic 40/80-col text mode, so
the cost is really only your own cursor and string-walking
management).

Canonical working implementation: `src/standalone/simtest/simtest.s`
(`tp1_video_init`, `tp1_putc_at`, `tp1_clear`).

## 1. Why bypass firmware COUT

Firmware `COUT` (`$FDED`) and `HOME` (`$FC58`) are designed for
Apple II / emul-mode callers running in bank `$00` with `DP=$0000`
and the standard CSW / BASL state machine. Calling them from a
native-mode bank-≠$00 binary is technically possible but requires
six interlocking workarounds — see lessons §10 for the gory
detail. The short list:

- `JSR $FCxx` from bank `$02` jumps to `$02:FCxx` (no ROM in that
  bank). Need a bank-`$00` trampoline reached by `JSL`.
- ROM `HOME` / `COUT` assume `DP=$0000`; they read BASL/BASH from
  `$28/$29` and write through that pointer. Custom DP → wild
  writes wherever your DP-+$28 happens to point.
- ROM `HOME` / `COUT` internally `SEC/XCE` to emul. That forces
  `SH=$01`, and `CLC/XCE` back does NOT restore SH. Without an
  explicit save/restore via long-absolute slots (not the stack!),
  the next `PLD/PLB/RTL` reads garbage.
- The `TSC` save has to happen AFTER `PHD`, not before, or the
  PLD/RTL on the way out pops the wrong frame.

By contrast, MMIO writes to `$E0:0400+` (40-col) or
`$E0:0400+ / $E1:0400+` (80-col) are:

- Native-mode safe at any MX setting.
- Bank-agnostic for the caller (no PB constraint).
- DP-agnostic (no zero-page state).
- Stack-pointer agnostic (no XCE round-trip).
- Free of the firmware's character-set, soft-switch, and BASL
  side effects.

The MMIO approach also gives you a 24×80 high-ASCII canvas with
zero firmware involvement, which is exactly what you want for
diagnostic / kernel-bring-up screens.

## 2. Display memory map

### 40-col mode

Single bank:

- `$E0:0400-$E0:07FF` — MAIN bank, 1 KB region scanned by the VGC.
- AUX (`$E1:0400-$E1:07FF`) is ignored in 40-col mode.

24 rows × 40 columns = 960 bytes used; the remaining 64 bytes are
"screen holes" used historically for soft-switch / peripheral
state on the Apple II. Don't write meaningful data into the
holes (display garbage), and don't expect to read peripheral
state out of them on the IIgs (different memory layout).

### 80-col mode

Two banks scanned simultaneously per row:

- `$E1:0400-$E1:07FF` — AUX bank, provides **even** display
  columns (0, 2, 4, ..., 78).
- `$E0:0400-$E0:07FF` — MAIN bank, provides **odd** display
  columns (1, 3, 5, ..., 79).

Per visible column `C` in row `R`:

```
byte_offset_within_row = C >> 1
bank                   = (C & 1) ? $E0 : $E1   ; AUX is the EVEN-col bank
full_address           = bank : ($0400 + row_offset[R] + byte_offset_within_row)
```

Both banks use the same 24-entry interleaved row-offset table.

### Row offset table (same in 40 and 80 col)

```
row  offset   row  offset   row  offset
---  ------   ---  ------   ---  ------
  0  $0000     8  $0028    16  $0050
  1  $0080     9  $00A8    17  $00D0
  2  $0100    10  $0128    18  $0150
  3  $0180    11  $01A8    19  $01D0
  4  $0200    12  $0228    20  $0250
  5  $0280    13  $02A8    21  $02D0
  6  $0300    14  $0328    22  $0350
  7  $0380    15  $03A8    23  $03D0
```

Three groups of 8 rows, each group stepping by `$80`. Groups
themselves step by `$28` (40 = decimal column count). This
layout dates back to the original Apple II video controller and
is fixed in hardware; the IIgs VGC reads exactly the same
sequence.

As a Merlin32 data table:

```asm
tp1_row_offsets DA      $0000,$0080,$0100,$0180,$0200,$0280,$0300,$0380
                DA      $0028,$00A8,$0128,$01A8,$0228,$02A8,$0328,$03A8
                DA      $0050,$00D0,$0150,$01D0,$0250,$02D0,$0350,$03D0
```

Index by `row * 2` since each entry is a `DA` (2-byte) word.

### Why $E0/$E1 and not $00/$01?

The IIgs Mega-II video controller scans bank `$E0` (MAIN) and
bank `$E1` (AUX) directly. That's where the framebuffer lives.

When the SHADOW register (`$E0C035`) is configured to shadow text
page 1, writes to `$00:0400-$07FF` (and `$01:0400-$07FF` for
80-col) are **mirrored down** into `$E0/$E1`. Useful for Apple II
compatibility — DOS 3.3 and ProDOS write to `$00:0400` and the
shadow mechanism makes those writes visible.

In FGX, `_Shadow_InhibitUnused` (`src/kernel/main.s`) ORs `SHADOW_INHIBIT`
(`$07`, `include/hardware.s`) into `$E0C035`: it inhibits text-page-1 and
hi-res 1/2 shadowing only, and leaves SHR, AUXHGR/ALTDISP and I/O+LC shadowing
as they were (the block driver reaches slot ROM through the last).  With bit 0
set, bank-`$00` text-page writes do not reach the display.  (`FGX_SHADOW`, `$77`,
is defined in `include/hardware.s` but not used.) Native-mode FGX code
should always write directly to `$E0/$E1` — it works regardless
of the SHADOW setting.

Rule of thumb:

- **Diagnostic / standalone / kernel code** → always
  `STAL $E00400` (and `STAL $E10400` for 80-col).
- **Apple II compatibility code** → may write to `$00:0400` /
  `$01:0400` if shadow is on.

FGX simtest uses the direct `$E0/$E1` path exclusively.

## 3. Soft switches

The IIgs splits its soft switches into two address ranges with
fundamentally different semantics:

| Address | Function           | Trigger          | Notes                            |
|---------|--------------------|------------------|----------------------------------|
| `$C000` | CLR80STORE         | **WRITE only**   | Read returns keyboard register   |
| `$C001` | SET80STORE         | **WRITE only**   | Read returns keyboard register   |
| `$C002` | RAMRDOFF (MAIN)    | **WRITE only**   | Read returns keyboard register   |
| `$C003` | RAMRDON (AUX)      | **WRITE only**   | Read returns keyboard register   |
| `$C004` | RAMWRTOFF (MAIN)   | **WRITE only**   | Read returns keyboard register   |
| `$C005` | RAMWRTON (AUX)     | **WRITE only**   | Read returns keyboard register   |
| `$C00C` | CLR80VID (40-col)  | **WRITE only**   | Read returns keyboard register   |
| `$C00D` | SET80VID (80-col)  | **WRITE only**   | Read returns keyboard register   |
| `$C00E` | CLRALTCHAR         | **WRITE only**   | Primary character set            |
| `$C00F` | SETALTCHAR         | **WRITE only**   | Mousetext character set          |
| `$C050` | TXTOFF (graphics)  | Read or write    | Either triggers                  |
| `$C051` | TXTON              | Read or write    | Either triggers                  |
| `$C052` | MIXCLR (full text) | Read or write    | Either triggers                  |
| `$C053` | MIXSET             | Read or write    | Either triggers                  |
| `$C054` | PAGE1              | Read or write    | Either triggers                  |
| `$C055` | PAGE2              | Read or write    | Either triggers                  |
| `$C056` | LORES              | Read or write    | Either triggers                  |
| `$C057` | HIRES              | Read or write    | Either triggers                  |

### The read-vs-write gotcha

This bit simtest hard. The original assumption was that LDAL on
`$00C00C` would toggle 40-col mode, the same way LDAL on `$00C051`
toggles TXTON. It does not.

`$C000-$C00F` is the **keyboard register** on read. `LDAL $00C00C`
returns the most-recent-key-pressed byte and does **nothing**
to the 80-col-mode latch. To set the latch, you must **write**:

```asm
STAL    $00C00C                 ; CLR80VID (the value in A doesn't matter)
STAL    $00C00D                 ; SET80VID (the value in A doesn't matter)
```

The value written is ignored — the access itself is the trigger.
Use any A value; convention is to leave A holding whatever it
already held.

`$C050-$C05F` (the display mode switches) accept **either** a
read or a write as the trigger. Both `LDAL $00C051` and
`STAL $00C051` turn on text mode. FGX simtest uses LDAL for
these because it keeps A free for the next operation.

### Bank-$E0 vs bank-$00 access

The IIgs maps the soft switches into both bank `$00` and bank
`$E0` (FGX's convention: I/O lives at `$E0Cxxx`, not `$00Cxxx`). For the **read-or-write** $C05x switches, either
bank works. For the **write-only** $C00x switches, bank `$00`
also works (`STAL $00C00D` is fine for SET80VID).

FGX convention is `$E0` for real register stores (TBCOLOR,
NEWVIDEO, SHADOW), and `$00` for the historical soft-switch
strobes (the latter is what every Apple II Technical Reference
example shows, and it works equivalently on the IIgs). Either
is fine; pick one and stick with it within a routine.

## 4. Other registers (real stores, not toggles)

These are conventional memory-mapped registers with real
storage. The value you store is the value the hardware uses
on the next refresh.

| Address    | Register   | Function                                                |
|------------|------------|---------------------------------------------------------|
| `$E0C022`  | TBCOLOR    | Text foreground (hi nibble) + background (lo nibble); `$F0` = white on black |
| `$E0C029`  | NEWVIDEO   | Bit 7 = SHR enable; clear to use classic text/lores/hires modes |
| `$E0C035`  | SHADOW     | Per-region shadow-inhibit bits; for classic text via `$00` writes, bit 0 must be clear |

These ARE stores — load A with the desired value and STAL. The
IIgs has NO read-vs-write gotcha for these.

TBCOLOR nibble values follow the standard IIgs 16-color palette:
`0`=black, `1`=deep red, `2`=dark blue, ..., `F`=white. `$F0` is
white-on-black; `$0F` is black-on-white. Per-text-row override is
possible via SCBs in SHR mode but not in classic 40/80-col text.

## 5. The full init sequence for 40-col text mode

```asm
;------------------------------------------------------------------------------
; tp1_video_init_40 — set up classic 40-col text mode.
; Entry MX %00 native.  Returns MX %00.  Clobbers A.
;------------------------------------------------------------------------------
tp1_video_init_40 MX %00
                SEP     #$30
                MX      %11

                ; --- Register writes (real stores, $E0) ---
                LDA     #$00
                STAL    $E0C029                 ; NEWVIDEO = $00 (no SHR)
                LDA     #$F0
                STAL    $E0C022                 ; TBCOLOR = white-on-black

                ; --- $C05x switches: read-or-write trigger ---
                LDAL    $00C051                 ; TXTON
                LDAL    $00C052                 ; MIXCLR  (full text, no mixed)
                LDAL    $00C054                 ; PAGE1
                LDAL    $00C056                 ; LORES   (no hires bit)

                ; --- $C00x switches: WRITE-only trigger ---
                ; Reading these returns the keyboard register, NOT a toggle.
                STAL    $00C00C                 ; CLR80VID (40-col text)
                STAL    $00C00E                 ; CLRALTCHAR (primary charset)
                STAL    $00C000                 ; CLR80STORE
                STAL    $00C002                 ; RAMRDOFF (read MAIN)
                STAL    $00C004                 ; RAMWRTOFF (write MAIN)

                REP     #$30
                MX      %00
                RTS
```

Note the **MX %11 byte-mode** wrapper around the whole block.
The soft-switch and register writes are 1-byte stores; the
SEP/REP keep A and the memory cycle 8-bit.

## 6. The full init sequence for 80-col text mode

This is what simtest ships. Only one
instruction differs from the 40-col version — `STAL $00C00D`
(SET80VID) instead of `STAL $00C00C` (CLR80VID).

```asm
;------------------------------------------------------------------------------
; tp1_video_init — set up classic 80-col text mode.
; Entry MX %00 native.  Returns MX %00.  Clobbers A.
;
; In 80-col mode the display interleaves two banks per row:
;   AUX  ($E1:0400+) → even display cols (0, 2, 4, ..., 78)
;   MAIN ($E0:0400+) → odd  display cols (1, 3, 5, ..., 79)
;------------------------------------------------------------------------------
tp1_video_init  MX %00
                SEP     #$30
                MX      %11

                ; --- Register writes (real stores, $E0) ---
                LDA     #$00
                STAL    $E0C029                 ; NEWVIDEO = $00
                LDA     #$F0
                STAL    $E0C022                 ; TBCOLOR = $F0

                ; --- $C05x switches: read-or-write trigger ---
                LDAL    $00C051                 ; TXTON
                LDAL    $00C052                 ; MIXCLR
                LDAL    $00C054                 ; PAGE1
                LDAL    $00C056                 ; LORES (no hires bit)

                ; --- $C00x switches: WRITE-only trigger ---
                ; Reading these returns the keyboard register, NOT a toggle.
                STAL    $00C00D                 ; SET80VID (80-col text)
                STAL    $00C00E                 ; CLRALTCHAR (primary charset)
                STAL    $00C000                 ; CLR80STORE
                STAL    $00C002                 ; RAMRDOFF (read MAIN)
                STAL    $00C004                 ; RAMWRTOFF (write MAIN)

                REP     #$30
                MX      %00
                RTS
```

## 7. Switching between 40-col and 80-col at runtime

It's just one soft switch:

```asm
                ; Switch to 40-col
                STAL    $00C00C                 ; CLR80VID (any A value)
                ; Optionally: STAL $00C00E to ensure primary charset

                ; Switch to 80-col
                STAL    $00C00D                 ; SET80VID (any A value)
```

The text page memory contents don't move when you switch modes
— but the **interpretation** of those bytes changes. If you've
written your 40-col layout (MAIN bytes at offsets 0..39 in each
row's region) and switch to 80-col, the VGC reinterprets that as
"MAIN provides odd columns": your 40 bytes per row now appear at
odd columns 1, 3, 5, ..., 79 interleaved with whatever is in AUX
(probably garbage from a previous boot).

Either:

- Switch mode **before** writing, so subsequent writes go to the
  correct bank(s).
- Or clear AUX before switching to 80-col, and write the same
  content to both banks if you want a "doubled" 40-col-ish look
  in 80-col mode.

Worked example — switch to 80-col, redraw banner:

```asm
                SEP     #$30
                MX      %11
                STAL    $00C00D                 ; SET80VID
                REP     #$30
                MX      %00
                JSR     tp1_clear               ; clear BOTH banks
                JSR     tp1_render_80col_banner
```

## 8. Writing a single character — putc

### 40-col version (single-bank)

```asm
;------------------------------------------------------------------------------
; tp1_putc_at_40 — write one high-ASCII char to text page 1 at (row, col).
; Inputs:
;   _tp1_arg_row  = row (0..23)
;   _tp1_arg_col  = col (0..39)
;   _tp1_arg_char = char (will have $80 OR'd; pass plain ASCII)
; Bank is always $E0.  Self-mod patches operand bytes +1, +2 of trailing STAL.
;------------------------------------------------------------------------------
tp1_putc_at_40  MX %00
                LDA     _tp1_arg_row            ; loads 16-bit; high byte = _tp1_arg_col
                AND     #$00FF
                ASL     A
                TAY                             ; Y = row*2
                LDA     tp1_row_offsets,Y       ; 16-bit row offset
                STA     _tp1_eff_offset

                LDA     _tp1_arg_col            ; loads 16-bit; high byte = _tp1_arg_char
                AND     #$00FF
                CLC
                ADC     _tp1_eff_offset
                CLC
                ADC     #$0400
                STA     _tp1_smc40+1            ; patch operand low+high

                SEP     #$30
                MX      %11
                LDA     _tp1_arg_char
                ORA     #$80
_tp1_smc40      STAL    $E00400                 ; bytes +1, +2 patched above
                REP     #$30
                MX      %00
                RTS
```

### 80-col version (two-bank, what we just shipped)

```asm
;------------------------------------------------------------------------------
; tp1_putc_at — write one high-ASCII char to text page 1 at (row, col).
; Inputs:
;   _tp1_arg_row  = row (0..23)
;   _tp1_arg_col  = col (0..79)   ; 80-col mode
;   _tp1_arg_char = char
;
; 80-col bank mapping:
;   AUX  ($E1) ← even display cols (col & 1 == 0): 0, 2, 4, ..., 78
;   MAIN ($E0) ← odd  display cols (col & 1 == 1): 1, 3, 5, ..., 79
;   byte_offset_within_row = col >> 1
;
; Patches operand bytes (+1, +2) AND the bank byte (+3) of trailing STAL.
;------------------------------------------------------------------------------
tp1_putc_at     MX %00
                LDA     _tp1_arg_row            ; loads 16-bit; high byte = _tp1_arg_col
                AND     #$00FF
                ASL     A
                TAY                             ; Y = row*2
                LDA     tp1_row_offsets,Y       ; 16-bit row offset
                STA     _tp1_eff_offset

                ; Bank byte from col bit 0:
                ;   col bit 0 == 0 → AUX  ($E1)
                ;   col bit 0 == 1 → MAIN ($E0)
                SEP     #$30
                MX      %11
                LDA     _tp1_arg_col
                AND     #$01
                BNE     @pc_main
                LDA     #$E1
                BRA     @pc_bank_set
@pc_main        LDA     #$E0
@pc_bank_set    STA     _tp1_bank_sel
                REP     #$30
                MX      %00

                ; A = (col >> 1) + row_offset + $0400.
                LDA     _tp1_arg_col            ; loads 16-bit; high byte = _tp1_arg_char
                AND     #$00FF
                LSR     A                       ; col >> 1
                CLC
                ADC     _tp1_eff_offset
                CLC
                ADC     #$0400
                STA     _tp1_smc+1              ; patch operand low+high

                SEP     #$30
                MX      %11
                LDA     _tp1_bank_sel
                STA     _tp1_smc+3              ; patch bank byte ($E0 or $E1)

                LDA     _tp1_arg_char
                ORA     #$80
_tp1_smc        STAL    $E00400                 ; bytes +1,+2,+3 patched above
                REP     #$30
                MX      %00
                RTS
```

Important: `STAL` (4-byte opcode + 3-byte address) lays out as
`[opcode][lo][hi][bank]`. Patching `_tp1_smc+1` writes the low+high
operand bytes (16-bit), and `_tp1_smc+3` writes the bank byte.

The caller must `SEI` before any sequence of `tp1_putc_at` calls
in multi-task contexts, since the routine is self-modifying and
not reentrant. In simtest's single-task standalone, the boot
entry already SEIs.

## 9. Clearing the text page — `tp1_clear`

### 40-col version (clear MAIN only)

```asm
;------------------------------------------------------------------------------
; tp1_clear_40 — fill text page 1 ($E0:0400..$07FF) with high-ASCII space.
;------------------------------------------------------------------------------
tp1_clear_40    MX %00
                SEP     #$30
                MX      %11
                LDX     #0
                LDA     #$A0                    ; high-ASCII space
@tc_L           STAL    $E00400,X
                STAL    $E00500,X
                STAL    $E00600,X
                STAL    $E00700,X
                INX
                BNE     @tc_L
                REP     #$30
                MX      %00
                RTS
```

### 80-col version (clear BOTH banks)

```asm
;------------------------------------------------------------------------------
; tp1_clear — fill text page 1 with high-ASCII space in both banks.
;
; 80-col mode reads from BOTH $E0:0400..$07FF (MAIN, odd cols) and
; $E1:0400..$07FF (AUX, even cols).  Clear both.
;------------------------------------------------------------------------------
tp1_clear       MX %00
                SEP     #$30
                MX      %11
                LDA     #$A0                    ; high-ASCII space
                ; --- MAIN ($E0) pass: odd display columns ---
                LDX     #0
@tc_M           STAL    $E00400,X
                STAL    $E00500,X
                STAL    $E00600,X
                STAL    $E00700,X
                INX
                BNE     @tc_M
                ; --- AUX ($E1) pass: even display columns ---
                LDX     #0
@tc_A           STAL    $E10400,X
                STAL    $E10500,X
                STAL    $E10600,X
                STAL    $E10700,X
                INX
                BNE     @tc_A
                REP     #$30
                MX      %00
                RTS
```

Two 256-iteration passes through the X-indexed loop, each pass
writing 4 × 256 = 1024 bytes (covering `$0400-$07FF`). The 64
bytes of "screen holes" between display rows get $A0 too; that's
harmless because the VGC ignores those bytes.

## 10. The MX-discipline gotcha

This was the **single bug** that masked all of the soft-switch
read-vs-write fixes for hours during simtest C0.2 debugging.

Symptom: `tp1_clear` (or any byte-store loop) appears to run
forever; the screen displays a single character or never updates.

Root cause: A `SEP #$20` only sets the M (memory/A width) bit.
It leaves X at 16-bit width. The `LDX #0` then loads a 16-bit
zero, and the `INX / BNE` loop runs **65,536 iterations** instead
of 256. From the user's perspective, the loop never exits.

Fix: Always use **`SEP #$30`** for byte-loop routines. The `$30`
sets both M (`$20`) and X (`$10`) so A and X are both 8-bit.
Mirror with `REP #$30` on exit.

```asm
                SEP     #$30                    ; A=8, X=8, Y=8
                MX      %11                     ; tell assembler
                LDX     #0
@loop           ...
                INX
                BNE     @loop                   ; now wraps at 256
                REP     #$30                    ; back to A=16, X=16, Y=16
                MX      %00
```

Same trap fires whenever a `SEP #$20` predates a byte-oriented
loop. The Merlin32 assembler will silently accept it (it tracks
the MX directive separately from the runtime state — see
`docs/iigs-lessons/lessons_merlin32_quirks.md` for the
`tools/check_mx.py` build-time mitigation).

Cross-ref: lessons §10 also mentions the `SEP #$20` vs `SEP #$30`
issue under "common 65816 traps".

## 11. References

- `docs/iigs-lessons/lessons_iigs_hardware_firmware.md` §10
  (firmware COUT travails — why we ended up here)
- `docs/iigs-lessons/lessons_merlin32_quirks.md` (MX-leak section,
  `tools/check_mx.py`)
- `src/standalone/simtest/simtest.s` (canonical working
  implementation)
- Apple IIgs Hardware Reference, Chapter 4 (I/O memory map,
  TBCOLOR / NEWVIDEO / SHADOW register layouts)
- Apple IIe Technical Reference, Chapter 2 (text page memory
  layout + interleaved row addresses — same on IIgs)
- Apple IIgs Firmware Reference, §4 (soft switch summary,
  read-vs-write trigger semantics)
