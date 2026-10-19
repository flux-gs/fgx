# FGX Console

The console is an 80x25 VT100-style text terminal drawn on the IIgs Super
Hi-Res (SHR) screen in 640-pixel mode. It has a 100-row cell ring per
console, ANSI colour folded onto the four colours a 640-mode row can show,
loadable bitmap fonts, and four virtual consoles (Option-1 to Option-4). The
fourth can be shown on a Second Sight card instead of the SHR screen.

Where the addresses live: [memory-map.md](../memory-map.md) (rest-of-OS
banks, bank `$01`) and [kernel-banks.md](../kernel-banks.md) (the far bank,
its jump-table slots and the `$F900` boot-font block). This page does not
repeat their tables.

---

## Where the code lives

| Piece | Files |
|---|---|
| Console engine (far kernel bank) | `src/kernel/far/console/*.s` |
| Public EQUs, VT state layout, attribute byte, mode descriptor | `include/console.s` |
| Buffer and font-table addresses | `include/memmap.s` (`DUM $030000` block, `CON_PREEXP_*`) |
| Console direct-page cells (`_conScratch*`, `_conTmp*`, `_conFontPtr`, `_conFontStage`) | `include/dpmap.s` |
| Per-VC state block (`CON_VC_STATE`, `VCS_*`, `NVC`) | `src/kernel/far/far.s` |
| tty lines `/dev/console`, `/dev/ttyv1-3`, VC registry, switch drain, border colour | `src/kernel/ttyv.s` |
| Keyboard poll into `_kKbdRing`, Option-N switch request | `src/kernel/toolbox.s` (`_HBTickTask`) |
| Console syscalls | `src/kernel/syscall.s` |
| Boot console (firmware COUT, before `Con_Init`) | `src/kernel/boot_console.s` |
| Boot font staging | `src/boot/stage2.s` |
| Second Sight back end | `src/modules/sscon/sscon.s` |
| `.FNT` tools | `tools/gen_fnt.py`, `tools/gen_all_fonts.sh`, `src/userland/font/font.c` |

The engine files in `src/kernel/far/console/`:

| File | Role |
|---|---|
| `console_init.s` | `Con_Init`, `Con_Clear`, `Con_RepatchBank`, SCB and palette install, PreExp font builders, `_Con_PaletteData` |
| `console_mode.s` | `_Con_ModeTable` (one entry, 640 mode) and `Con_InitMode` |
| `console_char.s` | `Con_PutChar`, `Con_CR`, line feed, index, reverse index, deferred wrap |
| `console_buffer.s` | ring-row arithmetic (`_Con_RingOffset`, `_Con_LogicalRowFromVp`) |
| `console_render.s` | `Con_RenderRow`, `Con_RenderAll`, `_Con_RenderCell` |
| `console_scroll.s` | `Con_ScrollRegionUp`, `Con_ScrollRegionDown` |
| `console_vt.s` | `Con_Write`, `Con_WriteBuf`, `Con_VtReset`, the parser state machine, `Con_Beep` |
| `console_vthandler.s` | CSI / ESC handlers |
| `console_vtcolor.s` | SGR to cell colour, `_Con_FgSlot` / `_Con_BgSlot` |
| `console_color.s` | `Con_SetFg`, `Con_SetBg` |
| `console_altscreen.s` | `Con_EnterAltScreen`, `Con_ExitAltScreen` |
| `console_font.s` | `Font_DEC_Graphics` (the 31 DEC Special Graphics glyphs, compiled in) |
| `console_font_loader.s` | `Con_LoadFontFromFile`, `Con_RevertToDefault`, `_Con_GlyphsFromBoot` |
| `console_set.s` | `Con_RebuildFontCache` |
| `console_switch.s` | `Con_SwitchVC`, `Con_EnterVC` / `Con_LeaveVC`, `Con_SaveVCState` / `Con_LoadVCState` |
| `console_backend.s` | `Con_SetBackend`: hands the pixel sites to a module |
| `console_bankpatch.s` | `_ConBankPatchTbl`, maintained by hand (see its header) |
| `console_kbd.s` | `Con_PollKey`, `Con_GetKey` |

The core kernel reaches the engine through far jump-table slots
(`KFAR_CON_*` in `include/kfar.s`); kernel-banks.md lists them.

---

## Memory

| What | Where | Source of truth |
|---|---|---|
| Cell buffers: `CON_CHARBUF`, `CON_ATTRBUF`, `CON_FGBUF`, `CON_BGBUF` (100 rows x 80 each) and alt-screen snapshots `CON_ALT_CBUF/ABUF/FGBUF/BGBUF` (25 rows each) | one bank per console; VC 0's is rest-of-OS +0 | `include/memmap.s`, `REST_CONSOLE_BANK_OFF` (`include/kernel.s`) |
| Pre-expanded fonts: 16 regular variants at `CON_PREEXP_REG_BASE`, 16 bold at `CON_PREEXP_BOLD_BASE`, `CON_PREEXP_NEW_STRIDE` = 2016 B each | rest-of-OS +1, shared by all consoles | `include/memmap.s`, `REST_FONTS_BANK_OFF`, `_kFontsBank` |
| VT state, mode descriptor, alt-screen save words, per-VC blocks | far-bank statics | `include/console.s` (`VT_*` offsets), `src/kernel/far/far.s` |
| Runtime font glyph block (760 B) | kernel heap, `Kmalloc(M_FONT)` at `Con_Init` | `include/memmap.s` (console font comment) |
| Boot font (whole `.FNT` file) | far bank `$F900` | `KFAR_BOOT_FONT` (`include/kfar.s`) |
| SHR pixels, SCBs, palettes | bank `$01` `$2000-$9FFF`, shadowed to `$E1` | `CON_SHR_BASE` = `$012000` (`include/console.s`) |

**The console bank is found at run time.** `memmap.s` assembles the cell
buffers at `$030000` and the font tables at `$040000`, but those are
assembly-time addresses. At boot `main.s` derives `_kConsoleBank` and
`_kFontsBank` from `_restBaseBank + REST_*_OFF`. `Con_RepatchBank`
(`console_init.s`) stores the bank in `_kConsoleBank` and rewrites every
baked `$03` operand bank byte listed in `_ConBankPatchTbl`: the
`STAL`/`LDAL CON_*BUF` sites (operand+3) and the `MVN $03,$03` sites (both
bank bytes). Font-table accesses load `_kFontsBank` instead (`_cfp`-marked
`LDAL`). A virtual-console switch calls `Con_RepatchBank` again with the
incoming console's bank. It is not ISR-safe, which is why switches are drained
at a safe point (below).

---

## How a character reaches the screen

1. **Write.** A tty write on `/dev/console` or `/dev/ttyvN` goes through the
   2.11BSD tty discipline in the tty bank. Upstream `cnwrite`
   (`vendor/2.11BSD/usr/sys/pdp/cons.c`) is `l_write` and nothing else. FGX
   adds a write bracket (`_Vc_WriteEnter` in `ttyv.s` -> `Con_EnterVC` /
   `Con_LeaveVC`), because one engine serves four framebuffers and a write
   to a console that is not on screen must be pointed at that console's bank.
   Output bytes reach `Con_Write`. Kernel log lines go to `Con_PutChar` once
   `_kernLogMirror` is set (`src/kernel/log.s`).
2. **Parse.** `Con_Write` (`console_vt.s`) runs the byte through the VT
   parser. Printables go to `Con_PutChar`, controls and sequences go to the
   handlers.
3. **Store.** `Con_PutChar` writes the code into `CON_CHARBUF`, the flags
   into `CON_ATTRBUF`, and `VT_FG` / `VT_BG` into `CON_FGBUF` / `CON_BGBUF`.
   Right-margin wrap is deferred (xterm `xn`, `VT_PENDING_WRAP`). CR and LF
   are separate operations. ONLCR in the tty layer turns a bare LF into
   CR+LF.
4. **Render.** `_Con_RenderCell` paints the one cell; `Con_RenderRow` paints
   a row. For each cell the renderer folds the fg and bg colour indexes to
   palette slots, makes a 4-bit variant `(bgslot<<2)|fgslot` (nibbles swapped
   for reverse), picks the regular or bold table, and copies 8 pre-expanded
   words to `$01:2000 + row*1280`. Runs of identical (attr, fg, bg) skip the
   decode, and blank cells skip the glyph loads. Underline ORs a fill word onto
   scanline 7.
5. **Display.** Bank `$01` is the SHR shadow. `_ConfigureHardware`
   (`src/kernel/main.s`) clears SHADOW bit 3 so writes to `$01:2000-$9FFF`
   reach `$E1`. `_Shadow_InhibitUnused` then ORs in `$07` to stop shadowing
   the text and hi-res pages. NEWVIDEO is set to `$81`.

All 200 SCBs are set to `$80` (640 mode, palette 0) by `_Con_InitSCBs`.

**Render gate, `VT_RENDER_STATE`** (`include/console.s`): 0 = immediate,
3 = suspended. `Con_RenderRow` and `_Con_RenderCell` skip pixel work at 3; the
cell ring is always updated.
- 3 is set by `SYS_SCREEN_CTL` claim (`_Sys_ScreenCtl`, `syscall.s`) while
  a task owns the SHR screen. It is cleared on release or when the owner dies
  (`process.s`). It is also used by `Con_EnterVC` while a background console is
  written. A full-screen `Con_ScrollRegionUp` taken at 3 skips its pixel
  `MVN`; the cell ring has already moved, and the release's `Con_RenderAll`
  repaints it.

There is no deferred scroll repaint.  One existed while console writes went
through the console pseudo-descriptor, which armed it; it stopped engaging
when that path was retired, and measured afterwards it saved about 6% of a
1,100-line `cat` at a 30-tick flush interval and nothing at the original 4, so
it was removed (apple/fgx#534).

**Back end.** Five sites touch pixels: `Con_RenderRow`, `_Con_RenderCell`,
`Con_Clear`, `Con_ScrollRegionUp` and `Con_ScrollRegionDown`. Each tests
`_conBackendOn` and, when a module has registered through `SYS_KCALL`
`KSVC_CONBACKEND` (`Con_SetBackend`), JSLs the module's routine instead.
`console_backend.s` documents the hook ABI.

---

## Calling convention

On entry to a `Con_*` routine: native mode, `MX %00` unless the routine's
header says otherwise (`Con_Write` takes any M/X and saves P), D = the kernel
direct page (`include/dpmap.s`; not page 0), and `DBR` = the far bank (the far
jump-table wrappers set it). Registers are clobbered unless
a return value is documented. `Con_Write` clobbers A, X and Y.

The console renders at interrupt time for keyboard echo. So a routine must
not hold a value in the shared console DP cells across anything that can
sleep. That is why the font loader keeps its descriptor in far-bank statics
(`_conFontFd`, see `console_font_loader.s`).

---

## VT100 / ANSI emulation

The parser in `console_vt.s` is a subset of Paul Williams' VT500 state
machine, with states `VT_S_*` in `include/console.s`. Parameters (up to 16),
intermediates and the CSI private marker live in `CON_VT_STATE`. Parser state
persists across writes, so a sequence may be split anywhere. The terminal type
in `/etc/ttys` is `vt100`.

| Class | Handled |
|---|---|
| C0 | BEL (`Con_Beep`, Ensoniq), BS, HT (to the next set tab stop), LF, CR, SO/SI (G1/G0 into GL). Other controls are ignored. |
| ESC | `7` `8` (DECSC/DECRC), `D` (IND), `M` (RI), `E` (NEL), `c` (RIS), `H` (HTS), `( 0`/`( B` and `) 0`/`) B` (G0/G1 = DEC Special Graphics / US-ASCII) |
| CSI | `A B C D` (cursor), `H f` (CUP), `G` (CHA), `J` (ED), `K` (EL), `m` (SGR), `s u` (save/restore), `r` (DECSTBM), `S T` (SU/SD), `g` (TBC), `h l` with `?7` (DECAWM), `?25` (DECTCEM), `?1049` (alt screen); `8 ]` (Linux: current pair becomes the default). `n` (DSR) and `c` (DA) are accepted and ignored, because no reply path exists. |
| SGR | 0, 1, 4, 5, 7, 22, 24, 25, 27, 30-37, 39, 40-47, 49, 90-97, 100-107, and 38/48 in `;5;n` and `;2;r;g;b` form, folded to 16 colours as Linux `vc_t416_color` does. The colon forms are rejected by the parser. |

The cursor is an inverse block drawn by `Con_ShowCursor` and removed by
`Con_HideCursor`. They track the ring row (`VT_CURS_SAVED_RROW`), so a scroll
in between does not strand the block.

**Alt screen** (`?1049h` / `?1049l`, `console_altscreen.s`) saves the
cursor and colour state and the 25 rows starting at ring row 0 (char, flags,
fg, bg). It clears the screen, and restores both on exit. It is one level
deep. Ring rows 25..99 are not saved, so an alt session that scrolls overwrites
scrollback.

### Colour model

A cell holds an **ANSI colour index**, 0..15 in ECMA-48 order, for both fg and
bg. SGR 0/39/49 resolve to the console's default pair `VT_DEF_COLOR`. The
pair starts as 7 on 0 and is replaced by `CSI 8 ]`. SGR 5 (blink) is iCE
colour: it sets the background's bright bit. Each display maps the index
itself:

- **SHR, 640 mode.** A 640-mode row has four cell-addressable colours, so
  `_Con_FgSlot` / `_Con_BgSlot` (`console_vtcolor.s`) fold the 16 onto palette
  0's slots: 0 = blue `$0009` (blue; black as background), 1 = grey `$0CCC`
  (black/white as foreground), 2 = red `$0E00` (red, yellow, magenta),
  3 = green `$00D0` (green, cyan). A bright colour folds with its base colour.
  A cell whose fg and bg fold to the same slot is invisible. Bold selects
  the bold PreExp table. Reverse swaps the slots. Underline is drawn.
- **Second Sight card.** It shows all 16 colours as the VGA attribute
  `bg<<4|fg`, with code page 437 glyphs (sscon).

The attribute byte (`CON_ATTRBUF`) carries flags only: bit 4 bold, 5
inverse, 6 underline, 7 DEC graphics glyph (`include/console.s`).

`_Con_PaletteData` (`console_init.s`) is copied by `_Con_InstallPalettes`
into all 16 SHR palettes, but every SCB selects palette 0 and no console code
changes an SCB. `SYS_SETPAL` rewrites palette 0's fg slots (1/5/9/13) or bg
slots (0/4/8/12) to a 12-bit RGB value. `SYS_BORDER` sets the border nibble of
`$E0C034` and keeps the clock-control high nibble. Every `$C034` write does a
read-modify-write.

---

## Fonts

**Format: FGXF v1** (`tools/gen_fnt.py`, `console_font_loader.s`).

| Offset | Size | Field |
|---|---|---|
| 0 | 4 | magic `FGXF` |
| 4 | 1 | version (1) |
| 5 | 1 | cell width (advisory in 640 mode) |
| 6 | 1 | cell height, which must equal the mode's `CM_CellHpx` (8), else `FGXF_ERR_WRONG_MODE` |
| 7 | 1 | flags (0) |
| 8 | 16 | name |
| 24 | 16 | author |
| 40 | 8 | licence |
| 48 | 760 | glyphs: 95 printable ASCII characters (`$20-$7E`) x 8 scanlines, one byte per scanline |

A file is 808 bytes. The 31 DEC Special Graphics glyphs are not in the file.
They come from the compiled-in `Font_DEC_Graphics` and are shared by every
font. Glyph index = 95 + (char - `$60`).

**Loading.**
- At boot, stage 2 reads `/lib/fonts/default.fnt` from the boot volume and
  writes the whole file into the far bank at `KFAR_BOOT_FONT`
  (`src/boot/stage2.s`). `Con_Init` validates it in place
  (`_Con_GlyphsFromBoot`), so console init reads no disk. A failure halts
  with a message on the boot console.
- `Con_RebuildFontCache` (`console_set.s`) pre-expands the 1-bit glyphs into
  the 16 regular and 16 bold variants in the fonts bank. Bold is synthesized
  by OR-ing each glyph byte with itself shifted right one pixel
  (`_Con_BuildBoldPreExpFontForVariant`).
- `SYS_FONTLOAD` (57) -> `Con_LoadFontFromFile` reads a `.FNT` into the heap
  glyph block, rebuilds the cache and repaints. `_Sys_FontStoreBasename`
  (`syscall.s`) records the basename (lowercased, extension stripped) in
  `CurrentFontName`. `SYS_FONTREVERT` (58) -> `Con_RevertToDefault` goes back
  to the staged boot block and clears the name. `SYS_FONTNAME` (59) copies the
  name out.
- libfgx wrappers: `fontload`, `fontrevert`, `fontname`
  (`toolchain/include/fgx.h`, `toolchain/lib/libfgx_c/libfgx.c`).
- `font(1)` (`src/userland/font/font.c`): `font` lists `/lib/fonts` and
  marks the active face, `font NAME` loads `NAME.fnt`, and `font default`
  reverts. Names are case-sensitive because the root is UFS.

**Shipped faces** (`disk_src/lib/fonts/`): `default.fnt` (a committed binary
with no remaining source), `bold.fnt` (from
`src/drivers/console/fonts/font_bold.s`).  `tools/gen_all_fonts.sh`
regenerates `bold.fnt`.

---

## Virtual consoles

| VC | Key | tty line | Device |
|---|---|---|---|
| 0 | Option-1 | `tty[0]` | `/dev/console` |
| 1 | Option-2 | `tty[3]` | `/dev/ttyv1` |
| 2 | Option-3 | `tty[4]` | `/dev/ttyv2` |
| 3 (`VC_CARD`) | Option-4 | `tty[6]` | `/dev/ttyv3` |

`NVC` = 4 (`far.s`). `/etc/ttys` runs `/bin/sh` on the console and `getty`
on ttyv1-3.

- **Banks.** `_kVcBank[i]` (`memmap.s`, core bank) is each console's cell
  bank. VC 0's is `_kConsoleBank`. The others are allocated with `Bank_Alloc`
  on the line's first write (`_Vc_EnsureBank`, `ttyv.s`). A line left `off`
  never gets a bank, and Option-N for it does nothing.
- **State.** Each VC has a 128-byte block in `CON_VC_STATE`. It holds the
  `CON_VT_STATE` bytes up to `VCS_VT_LEN` ($5A: parser, SGR, cursor, scroll
  region, tab stops, ring pointers, colour), the alt-screen save words and
  flags. `VT_RENDER_STATE` and the fields after it are global and are not
  swapped.
- **Switching.** The heartbeat swallows Option-1..4 and posts
  `_kVcSwitchReq` (`toolbox.s`). The switch repatches bank operands, so it is
  drained at a safe point (`_Vc_DrainSwitch`, `ttyv.s`). The drain calls
  `Con_SwitchVC`: save the outgoing state, repatch to the incoming bank, load
  its state, repaint. A switch is refused while a task owns the SHR screen
  (`_screenOwner`).
- **Border.** The SHR border shows which console has the keyboard: blue,
  dark green, purple, orange for VC 0-3 (`_vcBorderTbl`, `ttyv.s`).
- **The Second Sight card.** `/etc/rc` loads `sscon`
  (`src/modules/sscon/sscon.s`). If it finds a card, it mirrors VC 3's ring
  into the card's Host Text buffer in bank `$E0` and registers as VC 3's back
  end. A full-screen scroll then moves the card's `start_line` instead of
  copying pixels. With a card, Option-4 moves only the keyboard
  (`_kVcFocus`), and the SHR screen keeps showing its console. Without a card,
  VC 3 is a fourth SHR console. Design notes:
  `docs/history/plans/2026-09-18-second-sight-console-plan.md`.

---

## Scrolling

The ring has `CON_BUF_ROWS` = 100 rows. `VT_TOP_ROW` is the ring row shown on
screen row 0, and `VT_BUF_ROWS` is the ring size.

- **Full-screen scroll up** (region = rows 0..24): `Con_ScrollRegionUp`
  advances `VT_TOP_ROW`, so the cells need not move. It then moves the pixels
  up one 1280-byte character row with `MVN` in bank `$01` (or skips that
  while a task owns the screen, see the render gate). Last, it clears and renders the bottom row. A DECSC-saved
  row inside the region moves up with it.
- **Partial regions** (DECSTBM, `VT_SR_TOP`/`VT_SR_BOT`) and **scroll down**
  (`Con_ScrollRegionDown`, reached from RI at the top and from SD) cannot use
  the ring advance, since rows outside the region would move with it.  They
  copy the region's cells a row at a time (`_Con_ShiftRegionUp`/`Down`, with
  `_Con_CopyRingRow` in `console_buffer.s`), move the pixels with `MVN`/`MVP`,
  and clear the revealed row, so a later full repaint shows the same screen
  (apple/fgx#535, test `scrollrgn`).
- Off-screen ring rows are not viewable: there is no scrollback-paging
  entry point.

---

## Before the console exists: the boot console

`src/kernel/boot_console.s` provides `_BootCon_Init` and `_BootCon_PutChar`.
They print one character at a time through firmware COUT on the 80-column text
screen, by way of the bank-0 `CoutTramp` thunk in `src/boot/loader.s`. There is
no scrolling, colour, cursor control or escape handling. `main.s` calls
`_BootCon_Init` early in `FGX_Entry`. The boot console is used for
pre-`Con_Init` halts (including a bad boot font), the `PANIC` path
(`jumptable.s`), and the module jump-table slot `SYS_CONPUTCHAR` ($00:0350).

The kernel log fills its ring before the console exists. `_BootScreen`
(`main.s`) calls `KFAR_CON_INIT`, replays the ring onto the SHR console and
then sets `_kernLogMirror`, so later log lines are mirrored live.

---

## Tests

`tools/mame_test/run.py` reads the live console's `charbuf` through
`_kConsoleBank` (and any VC's through `_kVcBank`) into `screen_text`. Most
screen assertions therefore check the cell ring, not the pixels. Tests worth
knowing, all in `tools/mame_test/tests/`:

| Test | What it holds |
|---|---|
| `smoke.json` | The gate: boot to a prompt, run `ls /`, read the listing off the console |
| `conpaint.json` | The SHR pixels match the CharBuf cell for cell at idle (`conpaint_check.py`). This is the one test that checks the pixels. |
| `coninv.json` | Per-cell fg/bg buffers survive scrolling |
| `fontload.json` | `font bold` loads and `font` marks it active from the kernel's `CurrentFontName` |
| `vivc.json` | vi draws a full screen on VC 1, read from `_kVcBank[1]` |
| `vccurstype.json` | Typing at a VC's login prompt keeps the cursor |
| `sscon.json`, `ssconscroll.json`, `ssansi.json`, `ss4focus.json` | Second Sight back end: VC 3 on the card, ring mirroring through scroll, 16 colours and CP437, Option-4 focus |
| `frotzscreen.json` | A full-screen program with a fixed status window over a scrolling region |

See [testing.md](../testing.md) for running them.

---

## Gotchas

- `$E0C034` is border colour (low nibble) plus clock control (high nibble).
  Always read-modify-write it.
- `console_bankpatch.s` is maintained by hand. A new `STAL`/`LDAL CON_*BUF`
  or `MVN $03,$03` site needs a `_kcbNNN`/`_kcmNNN` label and a table entry.
  A missing entry leaves a bank byte at its assembled value, and the boot shows
  it (wrong-bank glyphs or a blank screen).
- `VT_RENDER_STATE` has a load-bearing zero pad at `$5B`, because core-bank
  readers take the cell 16-bit (`include/console.s`).
