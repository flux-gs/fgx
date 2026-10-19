# ANSI colour and CP437 on the Second Sight console -- design

- **Status:** designed 2026-09-18 with the maintainer; merged 2026-09-18 as MR !347
  (`main` at `2005e608c`).
- **Goal:** the card's console (`ttyv3`, VC_CARD) shows full ANSI colour --
  sixteen foregrounds on sixteen backgrounds -- and the card's CP437 glyphs, so
  ANSI art, ANSI animations and CP437 text files display as drawn.  The IIgs
  screen's consoles keep working exactly as they do.
- **Scope:** text-mode ANSI/CP437 art.  The card's bitmap modes (`$13`
  320x200x8 and the 640x480 modes) are a separate, later project.

## 1. What the code does today

Read 2026-09-18.

- `_Vt_ApplySgr` (`console_vtcolor.s`) folds the sixteen ANSI colours into the
  SHR 640 renderer's four palette slots through `_Vt_FgToSlot` BEFORE
  `Con_SetFg`/`Con_SetBg` store them, so `CON_FGBUF`/`CON_BGBUF` hold slots
  0..3.  The card's `_Ss_Cells` builds a VGA attribute from those bytes and so
  shows four colours, in SHR palette 0 converted by `Con_SetBackend`.  The
  Second Sight plan's section 3.4 ("FgBuf/BgBuf already hold 16-colour
  palette indexes") is wrong.
- `Con_PutChar` (`console_char.s`) begins `AND #$007F`: a CP437 byte such as
  `$DB` (full block) or `$C4` (horizontal line) arrives as an ASCII letter.
- The tty strips bit 7 on output unless `RAW|LITOUT`: 2.11BSD `ttyoutput`,
  `vendor/2.11BSD/usr/sys/sys/tty.c:1054-1065`, ported as FGX `tty.c:397-405`.
  The console lines' bulk write reaches it through `_Tty_Write` (`ttyv.s`).
- SGR 38/48 are not parsed: `38;2;0;0;255` is read as four codes, and its `0`
  resets every attribute.  SGR 5 (blink) is ignored.
- `ESC c` (RIS, `_Vt_Handle_RIS`) resets the parser's SGR state but never
  applies it, so the colours in force before the reset stay in force.

## 2. Design

### 2.1 The cells hold what the program asked for

- `CON_FGBUF`/`CON_BGBUF` hold the ANSI colour index 0..15 in ECMA-48 order
  (black, red, green, yellow, blue, magenta, cyan, white; +8 bright).
- `CON_CHARBUF` holds the byte as written, eight bits.  `$00-$1F` and `$7F`
  are controls; `$80-$FF` are glyphs, as on ANSI.SYS and code page 437.  The G
  bit in `CON_ATTRBUF` still marks DEC line drawing at `$60-$7E`.
- Each display maps the cells to what it can show, at render time.

Rejected: a second pair of colour buffers for the card (16 KB more per VC bank,
and every write, scroll fill, erase and alt-screen snapshot maintaining two
copies); storing slots for SHR consoles and ANSI indexes for the card's (a VC
changes display at run time -- the card registers after boot, and `ttyv3`
without the card is a fourth SHR console -- so a buffer written under one
meaning would render wrong under the other).

### 2.2 SGR

- `_Vt_ApplySgr` stores the ANSI index; the fold to slots leaves it.
- **The default pair.**  `VT_DEF_COLOR` (`$2B`, inside the per-VC block
  `VCS_VT_LEN` saves), `bg<<4 | fg`, 7 on 0 at `Con_Init`.  SGR 0, 39 and 49
  resolve to it when they are parsed, so a cell never holds "default".  A VC
  used for the first time is seeded from the active VC's block
  (`_Con_VCFirstUse`), the pair with it.
- **`CSI 8 ]`** makes the current colours the default pair and resets the
  attributes to it.  Linux console private sequence, console_codes(4): "ESC [ 8
  ] Make the current color pair the default attributes."  As in Linux
  `vt.c` (`CSI_RSB_MAKE_CUR_COLOR_DEFAULT`: `vc_def_color = vc_attr` then
  `default_attr`), the pair is taken as displayed, bold folded in as the bright
  foreground.  It is per console because the VT state is per VC.
- **RIS** (`ESC c`) applies the reset SGR state, so the colours return to the
  default pair; like Linux `reset_terminal`, it does not reset the pair itself
  (only `vc_init` sets `vc_def_color`).
- **SGR 5 / 25** (blink / steady): a flag, resolved when applied as `bg | 8`.
  That is iCE colour: sixteen backgrounds, which is how the card's Host Text
  runs with its BLINK flag clear.
- **SGR 38 / 48**: `;5;n` and `;2;r;g;b` are consumed so their numbers are
  not read as SGR codes, and mapped to sixteen colours as Linux does
  (console_codes(4): "256/24-bit foreground color follows, shoehorned into 16
  basic colors"): `n < 16` directly; otherwise `vt.c`'s `rgb_from_256`,
  then `rgb_foreground` (a component above half the maximum sets its hue bit;
  maximum above `$AA` is bright; hue 7 at or below `$55` is dark grey) or
  `rgb_background` (bit 7 of each component, eight colours, "err on the dark
  side").  Linux sets the bold intensity where FGX sets the bright index, since
  FGX's bold is a separate attribute.  Colon-separated forms stay ignored.

### 2.3 The SHR renderer: the IIgs screen unchanged

- The two colour decodes (`_Con_RenderRow_640`'s cache-miss path,
  `_Con_RenderCell`) map through `_Con_FgSlot[fg]` and `_Con_BgSlot[bg]`
  where they had `AND #$03`.  The run cache compares raw bytes, so a hit is
  still exact.
- `_Con_FgSlot` is today's `_Vt_FgToSlot`.  `_Con_BgSlot` is the same but for
  black (0 and 8), which goes to slot 0, the dark blue, instead of slot 1
  grey.  That is the one visible change on the IIgs screen: an explicit black
  background (`ESC[40m`) read grey, and default grey text on it was invisible.
  It is also what lets every console default to 7 on 0: the SHR draws it grey
  on blue, as today.
- `_Con_ClearShr` fills with `_Con_BgSlot[VT_BG]`.
- The glyph lookup masks the byte to seven bits, which is the mask
  `Con_PutChar` applied before: every byte shows the glyph it shows today, and
  `$80-$9F` fall below the font and render blank.
- The pre-expanded font builders keep sweeping slots through `VT_FG`/`VT_BG`;
  the defaults they restore afterwards become ANSI 7 and 0.

### 2.4 The card

- `_Ss_Cells` already writes `bg<<4 | fg`, inverse swapping the two and bold
  selecting the bright half, and passes bytes from `$20` up raw to the card's
  VGA font.  Unchanged.
- The palette: the module's template carries the sixteen VGA colours in ANSI
  order -- `000000 AA0000 00AA00 AA5500 0000AA AA00AA 00AAAA AAAAAA 555555
  FF5555 55FF55 FFFF55 5555FF FF55FF 55FFFF FFFFFF`, brown at 3, the colour ANSI
  art was drawn against.  `Con_SetBackend`'s palette-0 conversion and the
  registration table's palette entry are deleted.
- The control block's BLINK flag stays clear: sixteen backgrounds.

### 2.5 `ansicat(1)`

`ansicat [-b baud] [file ...]`, C through fcc, FGX2, `src/userland/ansicat/`,
with a page in `disk_src/usr/man/cat1`.  No BSD counterpart.

- Saves the local mode word (`TIOCLGET`), sets `LLITOUT` (`TIOCLBIS`) on its
  standard output, writes `ESC[0m ESC[2J ESC[H` -- ANSI.SYS homes the cursor on
  `2J` and ECMA-48 does not -- and restores both on exit and on SIGINT.
- Copies each file (standard input when none is named) up to its first `^Z`,
  the DOS end-of-file byte that precedes a SAUCE record.
- `-b baud` paces the output at baud/10 bytes a second with libc's
  `nanosleep(ticks)`, 60 a second, through an integer accumulator.

Its BUGS section: iCE colour only (the SAUCE iCE flag is not read); CP437
glyphs in `$01-$1F` are controls; an `ESC[2J` inside a file does not home the
cursor; art taller than 25 rows scrolls.

## 3. Increments

- **C1 -- the cell model.**  8-bit `Con_PutChar`; SGR stores ANSI indexes;
  `VT_DEF_COLOR` and `CSI 8 ]`; blink; the SHR tables, glyph mask, clear and
  defaults.  Own commits for the two defects: SGR 38/48, and RIS.
- **C2 -- the card's palette.**
- **C3 -- `ansicat`, its page, and the `ssansi` test.**

## 4. Verification

- **The IIgs screen, measured.**  A scratch manifest runs `colortest` on VC0
  and hashes the SHR framebuffer (`$E12000`, 32,000 bytes).  On `main`
  (`a585aebcc`) it reads `0d3a3688...`, the same on a second run; the branch
  must read the same.  `colortest` uses ANSI 4, 7, 1 and 2 and never 40, so no
  cell of it is touched by the black-background change.
- **`coninv`** (gate): FGBUF's untouched default is 8000 x `$07` instead of
  `$01`; BGBUF stays 8000 x `$00`.
- **`ssansi`** (new, gate): the card fitted, `ansicat
  /usr/share/ansi/test.ans > /dev/ttyv3`, and the mirror in bank `$E0` read
  for named cells' character and attribute bytes -- a bright foreground on a
  blue background, an SGR 5 bright background, `$DB` and `$B0-$B2`, a
  `38;5;196` -- and the SAUCE text after `^Z` absent.  Positive control: the
  same check against `main`'s build must fail.  The fixture is written for
  this test; nothing from `examples/`.
- Blast radius: `sscon`, `ssconscroll`, `ss4focus`, `vccurstype`, `smoke`,
  the gate.  The far bank's free bytes, before and after.

## 5. Not in this design

The card's bitmap modes; real blink (the card's BLINK flag and the SAUCE iCE
bit); CP437 glyphs for `$01-$1F`; a CP437 fold table for the SHR font; 43- and
50-row rasters.

## 6. As built, 2026-09-18

Merged as MR !347, in the commits the plan names: the cell model; SGR
38/48; RIS; the card's palette; `ansicat` and `ssansi`.

Departures from the design above:

- The fixture is `disk_src/testdata/ansi.ans` (`/testdata/ansi.ans` on the
  volume), where the tree keeps test data, not `/usr/share/ansi/test.ans`.
  It has a sixth row: yellow on green made the default by `CSI 8 ]` and
  returned to by `ESC[0m`, attribute `$23`.  `ssansi` runs `ansicat -b 9600`,
  so the pacing path runs too.
- `ssansi` did not join the gate beside `sscon`: the gate's budget sat at its
  ratchet (6,015 s declared of 6,015 s), and adding a test means taking one
  out.  It took `sscon`'s slot, whose whole contract it asserts, at `sscon`'s
  30 s; it measures 8 s of wall time.
- The SGR 5/25 and 38/48 entries sit above `_Vt_ApplyOneSgr`: its compare
  chain cannot branch to handlers below it.
- `ansicat.c` declares itself `FGX-Origin: original`, since it names 2.11BSD
  for the tty behaviour it works with and `check_provenance.py` would
  otherwise demand a UCB registration for it.
- `sscon_check.py` compares the ring's bytes unmasked: the card takes
  `$20-$FF` raw.

Measured:

- The IIgs screen: `colortest` on VC0 leaves the SHR framebuffer byte-identical
  to `main`'s (`0d3a3688...`), after the cell model and again after SGR 38/48
  and RIS.  The baseline was taken twice on `main` and matched; the runs cold
  boot the rebuilt volume (no cached state).
- `coninv`: FGBUF's untouched default is 8000 x `$07` (was `$01`), BGBUF
  8000 x `$00`.
- `ssansi`: all six rows' characters and attributes as specified, no SAUCE
  text in `ttyv3`'s ring.  Positive controls, one rebuild each, restored by
  edit and read back from the listing: `_Vt_ApplySgr` folding through
  `_Con_FgSlot` again gives `$0A $21 $11 $12 $01` on rows 0-4 (FAIL);
  `Con_PutChar` masking to seven bits gives `[012` and a blank on row 2
  (FAIL).
- The card after boot: the getty's banner and `login:` light grey on black,
  the IIgs screen grey on blue (`sscon`'s `card.png`).
- `smoke`, `vccurstype`, `sscon`, `ssconscroll`, `ss4focus`: pass.
- The far bank: 4,311 bytes free before, 3,894 after (the cell model +137,
  SGR 38/48 +353, the palette conversion's removal -73).  The core bank is
  untouched, 126 free.
