# Second Sight Host Text console (R6) -- implementation plan

- **Status:** S1 to S4 LANDED 2026-09-18 on `feat/bank0-cache-r0` (section
  7 below records what was built and measured), then REVISED the same day
  (section 7.1): the card is the display of a fourth virtual console, not
  of the console.  Increment R6 of
  `2026-09-17-bank0-residency-architecture.md` (sections 7 and 11), whose
  memory question it closes; the driver is this plan's.
- **Goal:** a Second Sight card in its Host Text mode as the display of a
  virtual console, `ttyv3`, where the card scans a cell buffer out of Mega
  II RAM and the CPU renders no glyphs.  Same VT102 console, same keyboard;
  the IIgs screen keeps the first console and the card's console lives
  beside it.
- **Shape:** a loadable module, `sscon`, behind a five-site seam in the
  existing console.  Nothing changes for a machine without the card.

## 1. The card, in the terms FGX needs

Read 2026-09-18 from the patched MAME's source tree: `docs/SECONDSIGHT.md`,
`cards/secondsight/TESTING.md`, the MAME device
`cards/secondsight/overlay/src/devices/bus/a2bus/a2secondsight.cpp` and the
engine `ssvga.h`/`ssvga.cpp` it wraps, the reference client
`cards/secondsight/test/sstest.s`, and the Lua harness
`tools/ss_hosttext_test.lua`.

- **Four slot registers at `$C080 + slot*16`** (`ssvga.h:24-28`): `+0`
  command (write), `+1` data (write), `+2` data (read), `+8` handshake
  (read).  No `$Cn00` ROM, no `$C800` space: `$Cn00-$CnFF` reads `$00`
  (MAME's default `read_cnxx`), an empty slot reads the floating bus.
- **Identification** is command `$00` GetStatus: twelve bytes back through
  `+2`, the first discarded, then `'GSVGA'`, a record length, the firmware
  version (`$20`), whether VGA output is active, the mode number
  (`ssvga.cpp:561-585`).  This is the only probe; there is no slot
  signature.
- **Handshake** (`ssvga.cpp:471-494`): the long commands finish, then set a
  deferred status that appears on the SECOND read of `+8` -- the first read
  returns `$00`.  `$A5` done, `$A6` refused.  The card never reports `$A5`
  for work it has not applied.  A new command discards a pending status.
- **Bring-up, 80x25** (`TESTING.md:138-154`, `sstest.s:61-137`): `$01` ->
  command, `$03` -> data (raster 80x25, 9x16 cells, 720x400), `$04` -> data
  (Host Text); poll.  Fill the cells BEFORE arming.  Lay the 32-byte control
  block.  `$50` -> command (SetTextCtrl), block address low, high, flags
  (bit 0: the block is on the aux side); poll.  Leaving Host Text unarms.
- **Cells**: interleaved character byte then attribute byte, `index =
  row*cols + col`, two bytes each (`ssvga.cpp:2093-2106`).  Attribute:
  foreground in the low nibble, background in the high nibble, sixteen of
  each while flag bit 3 (BLINK) is clear (`ssvga.cpp:2112-2114`).
- **Control block** (`ssvga.h:163-178`): `+0` flags (bit 0 planar, bit 1
  WRAP, bit 2 palette from block, bit 3 blink, bit 4 legacy cursor, bits
  5-7 buffer/attr/palette on the aux side), `+1` cols, `+2` visible rows,
  `+3` buffer rows, `+4` start_line, `+5` cursor x, `+6` cursor y, `+7`
  frozen top, `+8` frozen bottom, `+$0A` buffer address, `+$0C` attr
  address, `+$0E` palette address, `+$10` cursor style (`$0003` block on,
  `$0000` off), all addresses 16-bit little-endian.  With WRAP the visible
  row `v` shows buffer row `(start_line + v) mod buffer_rows`
  (`ssvga.cpp:1953-1977`).  The block is latched once per frame
  (`a2secondsight.cpp:210-218`), so any field may be written at any time;
  cells are read live.
- **No bank number**: the card reads the Apple II video bus, which on a
  IIgs is Mega II bank `$E0` (main) or `$E1` (aux), chosen per pointer by
  the flags (`a2secondsight.cpp:123-136`).  Under FGX's `$C035 = $27` a
  bank-0 buffer would not reach the card; a Mega II buffer always does.
- **Character set**: IBM code page 437 in every raster, the raw byte
  indexes the font (`ssvga.cpp:2130-2135`).  ASCII `$20-$7E` is CP437;
  `$00` and `$20` are both blank; `$7F` is a glyph.  The VT100 line-drawing
  set maps onto CP437's box characters (`q` `$C4`, `x` `$B3`, `l` `$DA`,
  `k` `$BF`, `m` `$C0`, `j` `$D9`, `n` `$C5`, `t` `$C3`, `u` `$B4`, `v`
  `$C1`, `w` `$C2`, `a` `$B1`, `~` `$FA`).
- **MAME**: the device is in Ample's shipped `mame64`; the slot option is
  `-sl3 secondsight` (any slot).  It exports nothing to Lua; a harness sees
  the card through `manager.machine.screens[":sl3:screen"]` (`pixel`,
  `snapshot`) or by reading the cell buffer through the CPU's space.

## 2. Where FGX's console meets pixels

The console lives in the far kernel bank, `src/kernel/far/console/`.  Its
VT102 layer works entirely on an 80-column ring of 100 rows in the console
bank -- CharBuf, AttrBuf, FgBuf, BgBuf -- with `VT_TOP_ROW` naming the
ring row shown at the top of the screen; a full-screen scroll advances
`VT_TOP_ROW` and the ring is coherent (`console_scroll.s:39-64`).  Pixels
are touched at exactly five places:

| site | today |
|---|---|
| `Con_RenderRow`, A = viewport row (`console_render.s:31-40`) | `_Con_RenderRow_640`: 80 glyphs into bank `$01` |
| `_Con_RenderCell`, A = viewport row, X = column (`console_render.s:298`) | one glyph; also the cursor, which is an inverse-bit flip and a cell render (`console_char.s:386-455`) |
| `Con_Clear` (`console_init.s:234-262`) | 32,000-byte MVN over the SHR screen |
| `Con_ScrollRegionUp` (`console_scroll.s:105-160`) | MVN of the region's pixels, unless the batch defers it |
| `Con_ScrollRegionDown` (`console_scroll.s:205-268`) | MVP of the region's pixels |

`Con_RenderAll` is a loop over `Con_RenderRow`; the alt screen, the
virtual-console switch and the deferred-batch flush all end in it.  The
mode descriptor's `CM_RenderRowFn` slot was reserved for a second renderer
and never wired (`console_mode.s:87-92`).

## 3. Design

### 3.1 Five sites, one back-end

Each site becomes a four-byte `JSL` to the SHR routine, which ends in
`RTL`; the SHR routines are otherwise unchanged and remain the default.
`Con_SetBackend` (far bank), reached from a module through a new
`SYS_KCALL` service, patches the five operands to the module's routines,
then runs `Con_RenderAll` so the ring appears on the card at once -- the
boot log included, because the ring holds it.  No flag, no indirect jump
(`JML [abs]` reads its pointer from bank 0, which has no free cell), no
per-call test: an unregistered back-end costs nothing.

The hook ABI gives the module what it needs without touching VT state:

| hook | in | does |
|---|---|---|
| RenderRow | A = viewport row, X = ring row, Y = `VT_TOP_ROW` | writes 80 cells of ring row X into mirror row X; writes `start_line` = Y |
| RenderCell | A = viewport row, X = column, Y = ring row | writes one cell |
| Clear | -- | fills the 25 visible mirror rows with blank cells |
| ScrollUp | A = top, X = bottom, Y = `VT_TOP_ROW` | full screen: `start_line` = Y (the ring advanced); a region: moves the mirror rows |
| ScrollDown | A = top, X = bottom, Y = `VT_TOP_ROW` | a region: moves the mirror rows; the full-screen case is a region too (the ring does not retreat) |

DBR on entry is the far bank, as inside the console; the module brackets
its own bank with `PHB/PHK/PLB ... PLB`.  It reads the cell buffers with
long loads whose bank byte it takes from `_kConsoleBank` on every call,
because a virtual-console switch changes it.

### 3.2 The mirror is the ring

The card's buffer is 80 columns by 100 rows, two bytes a cell: 16,000
bytes, plus the 32-byte control block and 48 bytes of palette, 16,080 in
one block.  Mirror row r is ring row r; `start_line` is `VT_TOP_ROW`;
WRAP is set.  So the display always shows what the VT layer's own mapping
says it shows, a full-screen scroll is one byte, and a deferred scroll
storm costs the same 25-row repaint it costs today.

Section 7 of the architecture placed a 6,960-byte block in bank `$E1`'s
8 KB of free space.  The ring mirror does not fit there; it goes in bank
`$E0`'s 24 KB at `$6000-$BFFF` (Firmware Reference Appendix H, section 1.4
of the architecture) by the same Memory Manager call, attributes locked,
fixed, may-not-cross-bank and fixed-bank with the location `$E00000`
(Toolbox Reference volume 1 p. 511: the location pointer is honoured only
for fixed address or fixed bank).  Bank-0 cost stays zero.  The
alternative, the 6,960-byte visible-only buffer in `$E1`, scrolls by
moving 6,720 bytes at 1 MHz, about 46 ms a line, which is the SHR cost
over again.

### 3.3 The module

`src/modules/sscon/` on the `ramdisk`/`serial` shape: FGXM header, `mod_init`,
kernel imports from `tools/gen_kernel_exports.py`, placement from
`tools/gen_modplace.py`, listed in `tools/ninja/gen.py`'s `MODULES` and
`KEXPORTS`, loaded by `/etc/modload.conf` or `modload sscon`.

`mod_init`: GetStatus at the configured slot (`sscon.slot` in
`cfg/system.cfg`, default 3, 0 disables; a scan of every slot would write a
command byte into whatever card sits there); no `'GSVGA'`, log and return.
NewHandle the block; on failure, log and return.  SetMode 80x25 Host Text;
fill the mirror's 100 rows blank; lay the control block (WRAP, palette
from block, buffer/attr/palette on the main side, 80 columns, 25 visible,
100 buffer rows, `start_line` 0, cursor style `$0000`); copy FGX's
16-colour palette in as RGB888 so the card shows the console's own
colours; SetTextCtrl; register through the KCALL service.  The log line
names the slot, geometry and block address.

### 3.4 Cells

Character: the ring's byte, 7-bit; the line-drawing charset (the G bit in
AttrBuf) through a 32-entry CP437 table; `$00` for a blank.  Attribute:
foreground from FgBuf and background from BgBuf; the inverse bit swaps
them, bold selects the bright half (index or 8) as CGA does, underline has
no cell form and is dropped.

**Corrected 2026-09-18.**  This section said FgBuf and BgBuf "already hold
16-colour palette indexes, so the card shows more colour than the four-slot
SHR renderer can".  They did not: `_Vt_ApplySgr` folded the sixteen ANSI
colours to the SHR's four slots before storing them, so the card as built
here showed four colours, and `Con_PutChar` masked every byte to seven bits.
Section 7.2 records the change that made both true.

### 3.5 Cursor, virtual consoles, alt screen

The cursor is the existing one: `Con_ShowCursor` flips the inverse bit and
renders the cell, which reaches the card through RenderCell.  The card's
hardware cursor (`cursor_x/y`, `cursor_style`) is a later increment; it
would spare two cell renders per keystroke and give a blinking block.  A
VC switch repatches the console bank and ends in `Con_RenderAll`, which
repaints the incoming VC's ring into the mirror; the alt screen likewise.
Neither needs a change.

### 3.6 Not in this plan

80x43 and 80x50 rasters (the VT layer's 25 rows are a runtime word but the
alt-screen snapshots are sized for 25); a slot scan on real hardware.  As
first written this list also held reclaiming bank `$01` and dual output to
the monitor and the card; section 7.1 makes the second the design and the
first moot.

## 4. Harness

- A test adds the card with `"mame_slots": ["-sl3", "secondsight"]`
  (`tools/mame_test/run.py:1706`).
- `screen_contains` reads the CharBuf ring, not pixels, so it passes with or
  without the card.  The card's own output is read by a new plugin readout,
  `card_screen`: the non-background pixel count of the device's screen
  through `manager.machine.screens[":sl3:screen"]`, sampled at dump time,
  and a PNG snapshot beside the dump for eyes.  A test asserts the count is
  non-zero after the prompt; a machine without the card reports absent.
- Tests: `sscon` (boot with the card, `modload sscon`, the log line, the
  prompt in the ring, pixels on the card); `ssconscroll` (a long listing
  scrolls through `start_line`; pixels still there, the ring's last rows
  match `screen_text`).

## 5. Increments

- **S1 -- the seam.**  Five JSL sites, the SHR routines end in RTL,
  `Con_SetBackend`, the KCALL service, a far-bank export slot for the core's
  dispatcher.  No behaviour change; gate green proves it.
- **S2 -- the module lights the card.**  Probe, allocate, bring-up, register,
  RenderRow/RenderCell/Clear; the `sscon` test.
- **S3 -- scrolling, attributes, line drawing.**  The two scroll hooks, the
  CP437 table, the palette block; `ssconscroll`.
- **S4 -- checks under the card**: the VC switch and alt-screen tests run
  with `mame_slots` set, as a local mutation, and any defect found is fixed.
- Later: the hardware cursor; 43 and 50 rows; bank `$01` reclaim.

## 6. Decisions

Taken 2026-09-18 on the maintainer's delegation ("go with your recommendation"):
the back-end is a module behind patched JSL sites, not code in the far bank
(2,279 bytes free there); 80x25 first; the mirror is the whole ring in bank
`$E0` rather than a visible-only buffer in `$E1`; the slot is a config knob;
the cursor stays software for now; the harness reads the card's screen.
Revised 2026-09-18 (the maintainer): the card does not take the console over.  It
is the display of a fourth virtual console, so the SHR console keeps
rendering and the monitor keeps its screen; section 7.1.  The first cut
had cleared the monitor at the takeover and left the machine with no
primary screen, which is not a console with a card.

## 7. As built, 2026-09-18

The seam is not a vector.  A same-bank long call is forbidden
(`tools/check_selfbank_jsl.py`: the far bank's assembled bank is not its
runtime bank), so each of the five sites tests a far-bank word,
`_conBackendOn`, and either jumps to the SHR routine as before or reaches
the module through a `JSL` whose operand `Con_SetBackend` wrote.  The SHR
routines are untouched.  `Con_SetBackend` (`console_backend.s`) writes the
five operands, converts palette 0 into the module's block, clears the
monitor, turns the word on and repaints the ring; a module reaches it as
`SYS_KCALL` service 53 through far slot 73.  The far bank grew by 278
bytes.

The module is `src/modules/sscon/sscon.s`, 1.2 KB in the shared module
bank; `sscon.slot` in `cfg/system.cfg` names the slot; `/etc/rc.in` and
`/etc/modload.conf` list it after `pty`.  The extent table the loader keeps
for the shared bank held twelve entries and thirteen modules now load, so it
holds sixteen.  The module clobbers only the direct-page cells the routines
it replaces clobber, because the console renders at interrupt time and a
static in the module's bank would be shared between the task's write and
the echo that interrupts it.

Three defects were found and fixed before the suite was green.  The
cell-render site's back-end arm pushed its own registers over the viewport
row the entry had already pushed, so the first character rendered after
registration returned into the block driver; the arm now pops the entry's
push first.  The module never loaded from the boot list because `/etc/rc`
carries that list, not `/etc/modload.conf` (apple/fgx#384's lesson,
enforced by the gate's `check_modload_lists`), which the plan had
overlooked.  And the module's first cut patched its own code with the live
kernel bank and the block's address, which the suite's module-image check
(apple/fgx#110) refuses, as it should: it holds a loaded image to its file
but for the loader's own relocation.  Kernel statics are now read with the
kernel bank in DBR, the cell buffers with the console bank in DBR, and the
mirror is addressed by register under a fixed bank-`$E0` operand.

Measured in MAME with `-sl3 secondsight`:

- `sscon`: the module logs `sscon: 80x25 in slot 3, cells at $E0:6000`, the
  console's ring still carries the prompt, and the card's screen shows 179
  of 4,500 sampled pixels off the background, in the console's own palette
  (background `$0009`, foreground `$0CCC`, from the palette block).
- `ssconscroll`: after two listings scroll several screens, all 8,000
  ring cells equal the mirror's characters and the card's `start_line`
  equals `VT_TOP_ROW` (`sscon_check.py`), 321 samples off the background.
- The virtual-console and cursor-type tests pass with the card present, as
  a local mutation.
- `smoke` without the card: `sscon: no card in slot 3`, the SHR renderer
  as before.  Gate green, 44 of 44 with `sscon` in it; the full suite 137
  passed, 0 failed, 6 skipped by configuration, the module-image check
  among the passes.

The harness gained `mame_slots` use, a `card_screen` readout in the
fgxdebug plugin (a pixel sample of the device's own screen against its
majority value, and `card.png` beside the dump) and the `card_screen_min`
expectation; `sscon` is in the gate.

### 7.1 The card is the fourth virtual console, 2026-09-18

The first cut made the card the console's display, and the IIgs screen
went blank at the takeover.  The maintainer's direction: the card should operate as
a virtual console like `ttyv1`/`ttyv2`, and since real hardware has one
keyboard, the main console and the card's must co-exist.  As now built:

- `NVC` is 4 and `VC_CARD` (`include/kernel.s`) names VC 3.  Its line is
  `tty[6]` (`NTTY` 7), its node `/dev/ttyv3`, chardev index 9 -- the last
  built-in, so `/dev/console` and `/dev/tty` keep their indices and the raw
  disks count from 10.  `/etc/ttys` runs a getty on it.
- Every VC has a display: `_conVcDisplay` in the far bank, `$80` for the
  card.  `Con_SetBackend` marks `VC_CARD`'s entry alone, and
  `Con_LoadVCState` derives `_conBackendOn` from it each time the engine
  switches VCs, so the existing write bracket sends a `ttyv3` write to the
  card and any other VC's write to the SHR screen.  `Con_EnterVC` does not
  suppress rendering for a VC with a display of its own, and registering
  the display repaints VC 3 if it already has a bank.  Without the card the
  module logs that and `ttyv3` is a fourth SHR console.
- One keyboard.  `_kVcActive` is the VC on the SHR screen and `_kVcFocus`
  the VC the keyboard feeds; they were one word.  Option-1..3 switch the
  SHR screen and take the focus; Option-4 moves the focus to the card's
  console when a card has registered (`_kVcCard`) and switches the SHR
  screen to VC 3 otherwise.  The console read gate, select, the poll and
  the heartbeat's key routing compare against the focus.
- The border is the canary (the maintainer, 2026-09-18).  Each VC has a border
  colour (`_vcBorderTbl`: blue, dark green, purple, orange) and a switch
  writes the colour of the console that now has the keyboard into `$C034`'s
  low nibble.  After Option-4 the IIgs screen keeps its console and turns
  its border orange, the one visible sign that the keys go to the card.
- Three defects found on the way.  The bulk `d_write`/`d_read` for the
  console lines folded the minor with `AND #1`, so a write to `ttyv3` went
  to `ttyv1`'s line and bank.  The tty bank's row table `_ttyRowOff` had
  five rows for seven lines (six since the serial line), so `tty01`'s and
  `ttyv3`'s slots read a garbage row offset and a getty on either parked
  forever in its first `TIOCSETP`, held by `ttioctl`'s SIGTTOU check
  against a foreground group that read as 0; its own commit, with
  `check_ntty.py` counting the rows.  And the echo: a keystroke's echo is
  drained at a soft site through the core's run writer, which assumed the
  engine already described the typed line's console -- true while the
  keyboard and the screen agreed -- so a name typed at the card's login
  prompt was painted on the IIgs screen while the card's getty read it.
  `_FarSh_CdWrite` now hops the engine to the written line's console when
  it is elsewhere and back to the console it found, the bracketed one if
  a write is asleep inside its bracket (`_Vc_EchoEnter`/`_Vc_EchoLeave`);
  its own commit, with the `ss4focus` test.

Measured in MAME with `-sl3 secondsight`:

- `sscon`: the getty's banner and `login:` on the card (4 of 4,500 sampled
  pixels off the background, a two-line prompt, so the floor is 2) with
  the console shell on the IIgs screen; `vc: bank for vc3` in the log.
- `ssconscroll`: two listings written to `/dev/ttyv3` from the console
  shell; all 8,000 ring cells of `ttyv3`'s own bank equal the mirror and
  the card's `start_line` equals the `VT_TOP_ROW` saved in its console
  block, 323 samples off the background.
- `ss4focus`: Option-4 injected with the card present, then a login name
  typed; `ttyv3`'s ring holds `login: qqfocus`, the card draws it (11
  samples), the IIgs screen does not carry the name, and `$C034`'s low
  nibble reads 9, the card console's orange (`border_check.py`).
- `ttysprobe` opens `/dev/ttyv3` and finds no `/dev/ttyv4`; `vccurstype`,
  `modimage`, `ufsdevstat`, `initrespawn` and `smoke` pass.
- `vivc` rendered vi on VC1 but its klog needle was lost: the fourth getty
  made seven steady sleepers for six kernel-image slots, and update and
  the VC1 session parked and restored each other about every 1.4 s (132
  cycles in 180 s, 264 lines in the 4 KB ring).  Architecture decision 2
  was reopened by it and taken as seven slots of 1,024; the needle holds.
- Gate green, 44 of 44 with `sscon` in it (642 fixtures, 235 of 235
  oracle-validated on the redesign commit); the full suite 137 passed, 1
  failed, 6 skipped by configuration, the one red being `vivc`'s needle
  above.

### 7.2 Sixteen colours and code page 437, 2026-09-18

Design and plan: `2026-09-18-ansi-colour-card-design.md` and
`2026-09-18-ansi-colour-card-plan.md`, merged as MR !347.  The console's
cells hold the ANSI colour index and the byte as written, and each display
maps them when it renders: the SHR folds colours to its four slots and
glyphs to seven bits, where the SGR parser and `Con_PutChar` did before, and
the card writes `bg<<4 | fg` under the VGA sixteen in ANSI order, which
`sscon` now carries in its control-block template -- `Con_SetBackend` no
longer converts the SHR's palette 0, and the registration table is five
routines.  A per-console default pair (`CSI 8 ]`, the Linux console's) makes
the card's console light grey on black by default and grey on blue on
request; SGR 5 is iCE colour; SGR 38/48 are folded to sixteen as Linux does.
`ansicat(1)` shows an ANSI art file, pacing it with `-b`.  `ssansi` took
`sscon`'s gate slot.
