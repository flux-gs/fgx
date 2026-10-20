# A high-resolution timer from the video beam counter (Apple IIgs)

**Scope:** how to build and use a sub-frame-resolution timestamp on the Apple
IIgs with no timer peripheral and no interrupt — by reading the Mega II video
beam position. Design, portable pseudo-code, the concrete 65816 sequence, a
usage pattern, and the three gotchas that will bite you. Extracted from the FGX
project (`_Hr_Stamp` in `src/kernel/toolbox.s`); applicable to any IIgs
native-mode project that needs to profile work finer than the 60 Hz tick.

Cross-check: Apple IIgs Tech Note #39 "Mega II Video Counters"; the vertical/
horizontal counter registers are `$E0C02E` / `$E0C02F`.

---

## Why

The normal OS clock is the VBL tick — the frame counter incremented once per
video frame, i.e. **60 Hz (16.67 ms)**. That is far too coarse to measure
sub-frame work: repainting one console row takes single-digit milliseconds, a
fraction of one tick. You need a stopwatch ~260× finer.

The video chip already runs one for free. As the raster beam sweeps down the
display it reports **which scan line it is currently drawing**. That line
advances once every **63.7 µs** — 262 lines per NTSC frame — then snaps back to
the top. It is an always-running, zero-setup fine clock. Pair it with the frame
counter you already have and you get a seamless wide timestamp at 63.7 µs
resolution.

## The design

A timestamp is two halves:

```
stamp = frame * STEPS_PER_FRAME + linePos
        \_____/                   \_____/
        your VBL tick             beam scan-line, re-based to 0..261
```

- `STEPS_PER_FRAME = 262` (NTSC scan lines per frame; each step = 63.7 µs).
- `frame` = your existing 60 Hz VBL tick counter.
- `linePos` = the beam's vertical position, re-based so **0 is the exact instant
  the frame counter ticks** and it runs monotonically `0..261`.

Because there are exactly 262 `linePos` units per frame, rolling from `261` to
the next frame's `0` is a clean `+1` — no gap, no wrap discontinuity. Subtract
two stamps and multiply by 63.7 µs to get a duration.

### Platform-neutral pseudo-code

```
STEPS_PER_FRAME = 262          # scan lines per frame; each = 63.7 us
VBL_LINE        = 0x1C0        # raster line at which the frame counter ticks (IIgs)

func read_beam_line() -> int:
    V = read_vertical_counter()          # 9-bit; 0x0FA..0x1FF on IIgs
    return (V - VBL_LINE) mod STEPS_PER_FRAME   # re-base to monotonic 0..261

func hr_stamp() -> (frame, linePos):
    with interrupts_disabled:            # atomic: see gotcha 1
        line  = read_beam_line()
        frame = read_frame_counter()     # your VBL tick
    return (frame, line)

func to_ticks(frame, linePos) -> int:
    return frame * STEPS_PER_FRAME + linePos

func duration_us(start, end) -> float:
    return (to_ticks(*end) - to_ticks(*start)) * 63.7
```

### Usage — bracket the operation

```
start = hr_stamp()
do_the_work()                            # e.g. repaint a screen row
end   = hr_stamp()
cost  = duration_us(start, end)
```

## The concrete IIgs read (65816)

The 9-bit vertical position `V` is split across two registers (TN #39):

| Register | EQU | Contents |
|---|---|---|
| `$E0C02E` | `HW_VERTCNT`  | high 8 bits of V (V1..V8) |
| `$E0C02F` | `HW_HORIZCNT` | bit 7 = V0 (vertical LSB); bits 6..0 = horizontal (ignored) |

```asm
; Reassemble V into A (low 8) + carry (bit 8), then re-base to linePos 0..261.
                PHP
                SEI                     ; atomic snapshot (gotcha 1)
                SEP     #$20            ; 8-bit A for the shift/rotate trick
                LDAL    HW_HORIZCNT     ; A = [V0 | H6..H0]   *** LDAL, not LDA (gotcha 2)
                ASL     A               ; V0 -> carry
                LDAL    HW_VERTCNT      ; A = V8..V1          *** LDAL
                ROL     A               ; A = V7..V0, carry = V8   (full 9-bit V)
                REP     #$20            ; 16-bit
                AND     #$00FF          ; keep low 8; AND leaves carry (=V8) intact
                BCC     @noV8
                ORA     #$0100          ; fold V8 back in
@noV8           SEC
                SBC     #$01C0          ; V - VBL_LINE
                BCS     @line           ; V >= VBL_LINE -> 0..63
                CLC
                ADC     #262            ; V <  VBL_LINE -> wrap into 64..261
@line           ; A = linePos (0..261); pair with the frame counter, still under SEI
                LDA     _kSystemTicks   ; the VBL frame counter
                ; return (frame=ticks, linePos); e.g. X=ticks, A=linePos
                PLP                     ; restore prior interrupt state
```

FGX's `_Hr_Stamp` returns `A = linePos`, `X = frame`; the caller forms
`X * 262 + A`.

## The three gotchas

### 1. Atomicity — read both halves under one interrupt-disable
**Symptom:** occasional timestamps that jump ~one whole frame.
**Mechanism:** if a VBL fires *between* reading the beam line and reading the
frame counter, the two halves straddle a frame boundary and disagree.
**Pattern:** wrap both reads in `SEI`/`PLP` (or your platform's IRQ-off). The
window is tiny but the error is a full frame when it hits.

### 2. Bank-explicit MMIO reads — use `LDAL`, never `LDA` abs
**Symptom:** the frame half advances correctly but the beam half is a fixed
nonsense value; decoding it shows `V = 0` every time. (In FGX: `linePos = $FF46`,
which is exactly `(0 - $1C0) mod 262`.)
**Mechanism:** the counters live in bank `$E0`, but kernel code runs with the
data-bank register (DBR) pointing at its own (often relocated) bank. A plain
16-bit absolute `LDA $C02E` reads `DBR:C02E` — *your* bank's RAM — not the `$E0`
hardware. You silently read zeros forever. Merlin32 does **not** auto-promote a
symbolic `EQU $E0C02E` operand to a long load; it truncates to absolute.
**Pattern:** use a bank-explicit long load: `LDAL HW_VERTCNT` (opcode `$AF`).
General rule: any MMIO whose bank ≠ the current DBR must be `LDAL`/`STAL`. (The
non-IIgs analog: address MMIO by its full physical/segmented address, never the
ambient one.)

### 3. Validate it *live*, in the real execution context
**Symptom:** a standalone probe of the register reads a plausible live value, yet
the wired-in timer is broken — because the two run with different DBR/segment
state (this is exactly how gotcha #2 hides).
**Mechanism:** component-level reads and the real call site differ in ambient
CPU state (bank register, sync/settling of the video counters at early boot —
they read 0 before the video is running).
**Pattern:** emit a cheap self-check *from the real call site*. Take two stamps
around a known-nonzero operation and assert **(a)** both `linePos` values are in
`[0, 261]` and **(b)** the second stamp is strictly greater than the first.
Collapse that to one "in-range AND advanced" status bit and check it from a test.
That bit is what turns "compiles and looks right" into "proven on the metal."
(FGX does this in `_Con_HrProfSane`.)

### Bonus: re-base the raw counter
On this hardware `V` never reaches 0 (`$FA..$1FF`) and wraps mid-screen. The
`(V - $1C0) mod 262` re-base to `0..261` is what makes subtraction and the
frame-rollover arithmetic clean. Skip it and you fight the raw boundary.

## What it costs / what it buys

~20 instructions, no peripheral, no ISR. Resolution fine enough to time a single
console-row repaint: in FGX a full 25-row SHR console flush measured **863 of
these units = ~55 ms** on 16 MHz emulation — a number the 60 Hz tick literally
cannot express (it is ~3.3 ticks, but the interesting per-row detail is 0.13 of
a tick).

---

*Provenance: FGX `_Hr_Stamp` (`src/kernel/toolbox.s`), landed 2026-07-01. The
wrong-bank bug in gotcha #2 was real and was caught only by the live check in
gotcha #3.*
