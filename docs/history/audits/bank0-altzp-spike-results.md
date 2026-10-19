# The auxiliary-memory switch spike -- measured, not argued

**Result: ALTZP gives the 65816's stack and direct page a SECOND bank 0 in
native mode, the ROM's interrupt manager handles it correctly on every tick,
and FGX boots to a shell with it left on.**

Run 2026-09-17 as commit cb8370bb5 in the archived history (**not for
merge** -- the probe is a throwaway).  The question it answers is section 9 of
`docs/history/plans/2026-09-17-bank0-residency-architecture.md`, and the
specific fear in section 9.1: that an earlier attempt broke because "it
overwrote the handlers up in `$FFxx`".  The record shows no such attempt was
ever made (the `$FFxx` story was the language card, twice), and this spike
shows what actually happens at the interrupt boundary.

The shape is the language-card spike's (`docs/history/audits/bank0-lc-spike-results.md`):
`_ALTZP_Spike` in `src/kernel/main.s` runs once at boot, after
`Toolbox_InstallHB` and before any task exists, mirrors its result block into
aux `$01:0800`, and `tools/mame_test/altzp_check.py` decodes the dump.

---

## 1. What was measured

Phase A runs under `SEI`, straight-line, touching no stack and no direct page
while the switch is on.  Every probe is a write through one addressing form
and a read back through the other: bank-0 addresses (`$00xxxx`, a push
through `S`, a store through `D`) are what the switch is claimed to redirect;
explicit bank-1 addresses (`$01xxxx`) are the auxiliary RAM itself and are
never redirected.

| question | measured | verdict |
|---|---|---|
| does STATEREG (`$C068`) bit 7 latch? | `$80` after `ORA #$80`, `$00` after `AND #$7F` | **yes** |
| polarity vs RDALTZP (`$C016`) | `$C016` reads `$80` with bit 7 set, `$00` clear | **bit 7 = 1 means AUX**, as `include/hardware.s:123` says; the OCR'd Table 3-2 is inverted |
| is `$01:E100` RAM through long addressing? | wrote `$11`, read `$11` | **yes -- the aux language card is RAM** under FGX's LC mapping |
| bank-0 long READS with ALTZP on: `$00E100`, `$000180`, `$00D100` | `$11 $22 $33` (the aux backgrounds), not `$A5 $5A $C3` (main) | **redirected**: flat 8 K, page 1, the `$D000` bank |
| bank-0 long WRITES with ALTZP on | aux holds `$B6 $6B $D4` afterwards | **redirected** |
| main memory after all of that | `$A5 $5A $C3`, exactly as written before the switch | **untouched** |
| a PUSH through `S` at `$E1FF` with ALTZP on | aux `$E1FE` = `$1234`; main `$E1FE` = `$A5A5` (the boot paint) | **the stack pointer reaches aux** |
| a STORE through `D` = `$E000` with ALTZP on | aux `$E010` = `$77` | **the direct page reaches aux** |
| RAMWRT on: bank-0 write of `$1000` | main `$46` unchanged, aux `$E7` | **redirected** |
| RAMRD on: bank-0 read of `$1000` | `$E7` (aux) | **redirected** |

Phase B copies both halves of the window main -> aux (`$0000-$01FF` and
`$D000-$FFFF`, two `MVN`s), turns ALTZP on, enables interrupts and spins on
`_kSystemTicks` for `AZ_SOAK_TICKS` heartbeat ticks.

| question | measured | verdict |
|---|---|---|
| does the heartbeat keep ticking with ALTZP on? | 10 of 10 ticks, seven runs | **yes** |
| is the switch still on afterwards? | STATEREG `$80` at the end of the soak | **yes** |
| the heartbeat body's own STATEREG sample (`_hbLcState`, OR over the first `LC_PROBE_TICKS` ticks) | `$08` every tick, 11 bracket runs, 0 failures | **inside the ISR, ALTZP is OFF** -- see section 2 |
| with `AZ_LEAVE_ON = 1`, does the rest of boot run on aux page 0/1 and the aux language card? | module loads, root mount, task spawns, the console and the shell all come up; STATEREG `$80` at the prompt; `echo` works | **yes** |

## 2. The interrupt boundary, watched

The harness's write tap on every alias of the state register
(`$00C068`, `$E0C068`, `$E1C068`, `$01C068`) records who writes it, from
where, with the value.  During the soak, one pair per tick:

    $E1C068 <- $08   by $FF:BD7B   S=$0100     (entry)
    $E1C068 <- $80   by $FF:BF48   S=$0100     (exit: the caller's saved value)

So the ROM 3 interrupt manager saves the state register at entry, forces the
standard state -- ALTZP off, RAMRD/RAMWRT off, main page 0/1, language card
to ROM (`$08` = RDROM) -- runs the dispatch on main page 1 in emulation mode,
and writes the saved value back before its `RTI`.  Nothing FGX does is
involved: `_KernIrq_Dispatch`, the heartbeat body, `KTTY_KC_ENTER_IRQ` and the
serial ISR all run inside that bracket and see main memory.  The native
interrupt frame is pushed into whichever half was live at the interrupt and
popped from the same half after the restore.

Two consequences for the design:

- **Interrupt-time state stays in main, by construction.**  The
  interrupt-time kernel-C context at `$FA00-$FCFF` need not be seeded in
  both halves and the bracket needs no ALTZP bit: the ROM has already forced
  main before any FGX interrupt code runs.  Section 9.1's items 1 and 3 are
  unnecessary.
- **A task image in aux is invisible to the interrupt path.**  Kernel-image
  slots in the aux language card can never be touched by an ISR, which is a
  stronger isolation than the main-LC slots have today.

The earlier ROM writes in the same log are the boot's own: `$00C068 <- $0C /
$0D` from `$FF:BB87`, `$00:FA74` and `$FF:9D02` at frames 24-49, and
`$E1C068 <- $0D` from `$FF:6209` and `$FD:E691` at frames 64-65, before FGX
exists.  FGX's one write is `_ConfigureHardware` clearing RAMRD/RAMWRT
(`$E0C068 <- $0C`, `src/kernel/main.s:1929-1932`).

## 3. Firmware excursions with the switch on

The leave-on boot exercises every firmware path FGX has, with ALTZP on in
task context: SmartPort block reads through `BlkTramp` (page-1 bounce, `D=0`,
no `SEI`) for every module load and the root mount, Toolbox calls
(`NewHandle` and friends through `$E10000`) for every task and buffer, and
ROM `COUT` through `CoutTramp` for the boot console.  All of it worked on aux
page 0/1 and the aux language card.  The two `MVN`s at the flip are what make
that transparent: the firmware's page-1 stack and zero-page scratch, and the
cursor state ROM `COUT` keeps in page 0, were identical in both halves at the
moment of the switch.

## 4. Two early runs stormed: an assembler directive, not the switch

The first two runs of the probe died before reaching the mirror: the CPU
was found in the kernel bank at a data address, `S` back at the probe's
depth, and page 1, the `$0280` page and the boot stack filled with identical
4-byte units that decode as native interrupt frames (`P=$02`, `PC=$0000`,
`PB=$65` in one run, `$74` in the other).  Those runs mirrored the result
block into bank 0 at `$0280`; the rewrite that moved the mirror to aux
`$01:0800` also rewrote the mirror loop as `_az_Mirror`, and every run since
has passed.  The location was never the cause.

The first version's inline mirror loop carried the directive `MX %01` after
`SEP #$20` and `REP #$10`, whose real state is M=1/X=0, that is `MX %10`.
Merlin32 sizes immediates from the directive, so `LDX #0` and
`CPX #AZ_RES_LEN` were emitted with one-byte operands (`A2 00`, `E0 24`)
while the CPU, with a 16-bit X, read two: X took the next opcode byte as its
high byte and the instruction stream was misaligned from there, running data
as code until the interrupt frames started stacking.  Under the right
directive the same lines assemble to `A2 00 00` and `E0 24 00`.

Isolated on 2026-09-17, one change per run:

- the first version's text restored verbatim: storm, 3 of 3;
- the current text with the bank-0 mirror restored (3 of 3), with
  `LC_PROBE_TICKS 8` and the 60-tick soak (2 of 2), with no capture taps
  (2 of 2), and with `AZ_LEAVE_ON 0` (1 of 1): all pass;
- the current text with `MX %01` written into `_az_Mirror` and nothing else
  changed: storm, 1 of 1.

The switch had nothing to do with it.  In the first-version runs the soak had
completed and ALTZP had been turned back off (`STATEREG <- $00` from
`$7C:CCF9`, frame 291) before the first bad frame was pushed, and the ROM's
bracket had ticked cleanly for all 60 ticks.  The `AZ_LEAVE_ON 0` run also
shows that flipping the switch off after a soak of interrupts is transparent,
which section 6 relies on.

## 5. The suite with ALTZP left on

`python3 tools/mame_test/run.py --no-state --fresh` on the `AZ_LEAVE_ON = 1`
kernel: **131 passed, 2 failed, 6 skipped.**  The six skips are the
config-gated write probes (`ufsprobe` and friends), skipped on every build.
The two failures were `rebootgs` and `rebootclean`, the two tests that reboot
the machine inside one run, and they fail for a reason the spike itself
caused and which is worth its own paragraph:

**A warm reboot inherits the switch, and turning it off under a stack that
was born in aux strands the stack.**  `_Kern_Doboot` clears nothing before
`JML $00FAA6`, so with `AZ_LEAVE_ON` the second boot came up with ALTZP
already on: the loader's page-1 stack, the kernel's boot stack in the
language card, every page-0 cell, all in aux.  The probe then entered,
assumed the standard state, and its phase-B `main -> aux` copy overwrote the
live aux stack with main's stale first-boot contents.  The dump has the same
signature as section 4's storms: CPU in the kernel bank at a data address,
`S` at the probe's depth, page 1 and the kernel stacks filled with repeating
frames.

Two changes, both on the spike branch:

- `_ALTZP_Spike` normalises at entry: if it inherits ALTZP on, it clears the
  switch FIRST and then copies aux -> main for both halves with no stack use
  in between.  The order is forced: while the switch is on, main's window is
  unreachable through any address (`$00xxxx` is redirected, `$01xxxx` is aux
  itself), and once it is off, `S` addresses the stale copy until the copy
  completes.  A first attempt with the copy before the clear wrote aux onto
  itself and reproduced the storm exactly.
- `_Kern_Doboot` clears ALTZP, RAMRD and RAMWRT before `JML $00FAA6`.
  PWRUP's entry conditions ("emulation mode, `D = $0000`, `DBR = $00`,
  `PB = $00`") assume the standard memory state; a design that leaves the
  switch on in task context owes this line to the reboot path.

With both, `rebootgs`, `rebootclean` and `altzp` pass together.  So the
leave-on kernel is 131 + 2 of 133 across the two runs; the 131 were not
re-run after the two changes, which touch only the probe's entry and the
reboot path.

## 6. What this changes in the design

- ALTZP is a real, cheap, second bank 0 for `S` and `D`: one read-modify-
  write of `$E0C068` to switch, and the ROM's interrupt manager already does
  the per-interrupt save and restore that a design would otherwise have to
  add.
- The RAMRD/RAMWRT half redirects too.  Its costs in section 9 (the gateway
  page, the trampolines, `BLK_STAGE`, the shared kernel-C page and the
  console's 40 KB of bank `$01` all sit inside its window) are unchanged by
  this measurement.
- The measurement is MAME's.  As with the language-card spike, the probe
  image is what a real IIgs boots to say the same: `altzp: PASS` on the boot
  log, or a `stk` line.  The session-long hardware run is not obtainable that
  way, for the reason `bank0-lc-spike-results.md` section 5 gives.

## 7. How to run it

The probe, its checker (`tools/mame_test/altzp_check.py`) and its test
(`altzp.json`) are commit cb8370bb5 in the archived history, not in this tree.
On a checkout of that commit:

    ninja
    python3 tools/mame_test/run.py altzp --fresh -j1      # the probe + checker
    python3 tools/mame_test/altzp_check.py /tmp/fgx_test_altzp/dump.json

`AZ_LEAVE_ON` and `AZ_SOAK_TICKS` are `EQU`s at the top of `_ALTZP_Spike`;
`LC_PROBE_TICKS` in `include/kernel.s` is 64 on this branch so the
heartbeat's STATEREG sample covers the soak.
