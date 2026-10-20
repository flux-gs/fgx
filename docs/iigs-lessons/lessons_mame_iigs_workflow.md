# MAME-as-IIgs-emulator: workflow lessons learned

Strong suggestions for using MAME (verified against 0.285 and earlier) to
develop and debug IIgs software. Things that aren't quirks of MAME-the-
emulator family broadly but specifically affect the IIgs driver.

---

## 1. Slot-5 floppy timing dominates iteration speed; mount on slot-7 instead

**Symptom:** Disk mount + boot + spawn-to-test-binary takes 30+ seconds
under MAME's slot-5 5.25" / 3.5" floppy driver. Iteration on a kernel
change is painful.

**Mechanism:** MAME's slot-5 floppy emulation models the real-time mechanics
of the drive (motor spin-up, head seek, sector timing). Even at `-speed 100`
those are wall-clock delays.

**Recommended pattern:** mount your `.po` ProDOS-order image on a
slot-7 hard drive emulation (RetroNet / similar) instead. 4–6× faster
iteration. Useful invocation:

```
mame apple2gs -hard1 your_image.po
```

vs the floppy path:

```
mame apple2gs -flop1 your_image.po       # slow
```

Slot-7 is also generally less driver-finicky than slot-5 across MAME
revisions.

---

## 2. MAME `-autoboot_command` drops characters in multi-step diag flows

**Symptom:** You hand MAME `-autoboot_command 'kstat\ntime ls\nkstat\n'` to
run a benchmark sequence automatically. The first command runs fine. The
second command shows partial input ("ime ls"). The third runs anyway. The
results are unreliable.

**Mechanism:** MAME's autoboot stuffs characters into the keyboard buffer
at a fixed rate. The IIgs keyboard latch (`$C000`) is one-deep — if the
guest software is busy (e.g. running `time ls`) and doesn't drain the
latch before MAME stuffs the next key, that key is lost. The drop rate is
proportional to how long the previous command takes.

**Recommended pattern:**
- **For single short-running tests** (boot + run one binary + check
  output): autoboot is fine.
- **For multi-step diagnostic flows** with intermediate slow commands:
  don't use autoboot. Hand the keyboard to the human operator. They can
  run the test interactively.
- **For deterministic kernel testing** without an interactive operator:
  use a fixed test binary that runs the whole sequence with proper
  syncing — fopen / SYS_TICKS / WAI between steps to ensure the keyboard
  latch is fully drained between virtual keypresses. This is more setup
  but reliable.

---

## 3. `TAY`/`TAX` at M=8 X=16 doesn't reliably zero-extend (MAME, ≤0.285)

**Symptom:** A table lookup of the form `LDX #0 ; TXA ; LSR ; LSR ; LSR ;
TAY ; LDA Table,Y` (computing index in M=1, indexing in M=0) returns the
SAME table entry regardless of input X. Looks like the index is always 0
or stuck on some prior Y value.

**Mechanism:** WDC specifies that when transferring from a smaller register
to a larger one (e.g., M=8 A → 16-bit Y), the high byte of the destination
is set to zero. MAME's IIgs 65816 core (verified up to 0.285) does NOT
clear the high byte of Y on `TAY` under M=1 / X=0. Whatever leaked into
Y.hi from a prior 16-bit operation stays there, and the subsequent
`LDA Table,Y` reads from `Table + (Y.hi << 8 + Y.lo)`.

**Recommended pattern:** do all index arithmetic in full 16-bit M mode
and drop to 8-bit only for the byte load/store. Or, if you must shift in
M=1, defensively `LDY #0` immediately before `TAY` to clear Y.hi.

```
            ; SAFE: index in M=0, byte load in M=1
            LDX   #0
@loop       TXA                  ; M=0, A and X both 16-bit
            LSR : LSR : LSR
            TAY                  ; clean 16-bit transfer
            SEP   #$20           ; M=1 for byte load
            LDA   Table,Y
            ...
            REP   #$20
            INX
            CPX   #Limit
            BCC   @loop
```

This bug doesn't repro on real hardware (W65C816S follows the spec) but
the MAME variant is the default test environment for most modern IIgs
development, so guard against it.

---

## 4. Useful MAME debug workflows for IIgs development

**Screen capture for visual diagnostics:**
```
screencapture -l <windowID>             # macOS, captures a specific window
```
Pair with a deterministic test binary that renders a recognizable pattern
(border colors, framebuffer fills). Useful for "what was on screen when
the crash trap fired."

**Lua plugin for state dumps from MAME debugger:**
The `fgxdebug` Lua plugin used by FGX pattern: register a Lua hook that
on demand dumps CPU regs + a range of memory to a host-side file. Lets
you single-step or breakpoint-trigger state dumps without leaving the
MAME UI. (Plugin not redistributed; the pattern is the lesson.)

**MAME debugger BRK trap shows current PC**, with the bytes at that PC
on the same line. The 65816 BRK pushes PC=BRK_addr+2 (BRK is 2 bytes
opcode + signature), but the debugger generally shows the BRK-addr
itself, not PC-pushed.

**ROM monitor takes over the screen** on BRK trap — anything the guest
software wrote to display before the BRK is hidden. To preserve
diagnostic state across a crash:
- Write to the IIgs border color register (`$E0C034` low nibble) as a
  progress marker — survives the trap because it's a register, not
  display memory.
- Write to a known DP/bank-0 cell that you can inspect via the
  debugger's memory window after the trap.

---

## 5. RTC vs `-speed` flag interaction

**Symptom:** Real-time clock drift in long-running tests when MAME is
running at `-speed 200` or similar.

**Mechanism:** MAME's IIgs RTC tracks WALL CLOCK regardless of the
emulated CPU speed setting. With `-speed 200`, CPU cycles run at 2× but
the RTC continues at real-time, so `seconds elapsed since boot` (per
the RTC) ≠ `cycles elapsed / nominal_freq`.

**Recommended pattern:** for tests that measure time, either run MAME
at `-speed 100` (default), or measure CPU cycles directly (e.g., via
VBL counting — see `lessons_iigs_hardware_firmware.md` §7) instead of
RTC delta.

The IIgs UI speed setting (in MAME's internal menus or its config files)
is independent of the `-speed` flag. FGX runs at 8 MHz emulated CPU
(via the IIgs config) with `-speed 100`.

---

## 6. Boot border color as a kernel canary

**Symptom:** Boot completes without obvious failure but commands hang
or some subsystem is wrong. You can't tell where in boot something went
sideways because the boot splash overwrites diagnostic output.

**Mechanism:** The IIgs border color register (`$E0C034` low nibble) is
cheap to write, survives reboot and debugger trap, and is visible
without any console.

**Recommended pattern:** during major refactors or bring-up of a new
subsystem, set the border to a distinct color at each boot phase:
- Boot loader entry: red
- Stage 2 loaded: orange
- Kernel started: yellow
- Modules loaded: green
- Userland init spawned: cyan
- First shell prompt: white (or whatever your "running" color is)

If boot hangs, the last color set is your "how far did we get" indicator.
The pattern generalizes to userland test binaries — emit a SYS_BORDER
syscall (or direct write if your kernel allows) at each phase of the
test, then look at the border after a crash trap to know where the
crash was.

Particularly useful for tests where stdout output is hidden by the
debugger trap overlay.

---

## Cross-references

- MAME source: `src/mame/drivers/apple2gs.cpp` (and related video,
  keyboard files) for emulator behavior.
- IIgs CYAREG `$E0C036` for measured-vs-set CPU speed — see
  `hardware_ref` chapter on the Speed register.
- Example corpus: `a2audit` for systematic hardware probing patterns
  that work cleanly under both MAME and real hardware.
