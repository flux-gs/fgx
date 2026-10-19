# ANSI colour and CP437 on the Second Sight console -- implementation plan

> For agentic workers: execute task by task, in order; each task ends green
> and committed.  Checkboxes track progress.

**Goal:** the card's console shows sixteen foregrounds on sixteen backgrounds
and CP437 glyphs; the IIgs screen renders every stream it renders today the
same, pixel for pixel.

**Architecture:** the cell buffers hold the ANSI colour index and the 8-bit
byte; each display maps them at render time (the SHR folds to its four slots
and seven-bit glyphs, the card writes `bg<<4|fg` under a VGA palette).

**Tech stack:** 65816 assembly under Merlin32 (far kernel bank, the `sscon`
module), C through fcc (`ansicat`), the MAME harness (`tools/mame_test`).

**Spec:** `docs/history/plans/2026-09-18-ansi-colour-card-design.md`.

## Global constraints

- ASCII only in every FGX file (test data excepted: the fixture is bytes).
- Source comments describe the current state; history goes in commit bodies.
- Commit bodies are the changelog: informational, no names, no process.
- The far bank has 4,311 bytes free (`tools/check_kernel_ceiling.py`); the
  core bank's 126 are not touched by this work.
- Never `git checkout` a generated file; `ninja` rebuilds; mame runs headless
  (`SDL_VIDEODRIVER=dummy`, run.py's default).
- A mutation restored by `mv` keeps its mtime and ninja skips the rebuild:
  restore by editing, and read the opcode back from the listing.

## Shared names

| name | where | meaning |
|---|---|---|
| `VT_DEF_COLOR` | `include/console.s`, `$2B` | default pair, `bg<<4 \| fg` |
| `VT_SGR_FLAGS` bit 3 (`$08`) | same | blink; applied as `bg \| 8` |
| `_Con_FgSlot`, `_Con_BgSlot` | `console_vtcolor.s` | 16-byte ANSI -> SHR slot tables |
| `_Vt_SgrExt` | `console_vthandler.s` | SGR 38/48 parameter reader |
| `_Vt_Handle_RSB` | `console_vthandler.s` | `CSI Ps ]`, `Ps` = 8 |

---

### Task 1: the cells hold ANSI indexes and 8-bit bytes (far bank)

**Files:** `include/console.s`; `src/kernel/far/console/console_vtcolor.s`,
`console_vthandler.s`, `console_char.s`, `console_render.s`,
`console_init.s`; `tools/mame_test/tests/coninv.json`;
`tools/mame_test/sscon_check.py`.

- [ ] `include/console.s`: `VT_DEF_COLOR EQU $2B ; 1 B: default pair, bg<<4|fg`;
  `VT_SGR_FLAGS` comment gains `3=blink`.
- [ ] `console_vtcolor.s`: `_Vt_ApplySgr` stores the index -- `$FF` resolves
  to the `VT_DEF_COLOR` nibble, the background ORs in `VT_SGR_FLAGS & $08`:

```
_Vt_ApplySgr
                SEP     #$20
                LDA    |CON_VT_STATE+VT_SGR_FG
                CMP     #$FF
                BNE     @as_fg
                LDA    |CON_VT_STATE+VT_DEF_COLOR
@as_fg          REP     #$20
                JSR     Con_SetFg               ; AND #$000F
                SEP     #$20
                LDA    |CON_VT_STATE+VT_SGR_BG
                CMP     #$FF
                BNE     @as_bg
                LDA    |CON_VT_STATE+VT_DEF_COLOR
                LSR
                LSR
                LSR
                LSR
@as_bg          PHA
                LDA    |CON_VT_STATE+VT_SGR_FLAGS
                AND     #$08                    ; blink: the bright background
                ORA     1,S
                STA     1,S
                PLA
                REP     #$20
                JSR     Con_SetBg
                JMP     _Vt_ApplyFlags
```

  `_Con_SgrToFg_640` is deleted; `_Vt_FgToSlot` becomes `_Con_FgSlot`, and
  `_Con_BgSlot` is added beside it, equal but for entries 0 and 8 (0).  The
  mode descriptor's reserved `CM_SgrToFgFn` slot (`console_mode.s`) points at
  nothing that exists any more: it becomes `DA 0` with its note updated.
- [ ] `console_vthandler.s`, `_Vt_ApplyOneSgr`: 5 sets flag bit 3, 25 clears
  it; `CMP #38` / `CMP #48` gain `BEQ` arms into `_Vt_SgrExt` (C=0 fg, C=1 bg).
  `_Vt_SgrExt` follows Linux `vc_t416_color`: `i = cur+1`; `i >= n` -> consume
  to `i` and stop; `par[i] = 5` and `i+1 < n` -> index `par[i+1]`, consume to
  `i+1`; `par[i] = 2` and `i+3 < n` -> r,g,b = `par[i+1..i+3]`, consume to
  `i+3`; else consume to `i`.  An index below 16 is used as is; 16-231 and
  232-255 go through `rgb_from_256` (cube levels `0,42,85,127,170,212`, grey
  `n*10-2312`); r,g,b fold to an index by `rgb_foreground` (hue bit set where
  a component exceeds max/2, red 1 green 2 blue 4; hue 7 with max <= `$55` ->
  8; max > `$AA` -> hue|8) or `rgb_background` (bit 7 of r,g,b -> 1,2,4).
  The loop's `_conScratch0` is left at the last consumed index.
- [ ] `console_vthandler.s`: `_Vt_DispatchCsiByFinal` gains `CMP #']'` ->
  `_Vt_Handle_RSB`: param 0 = 8 -> `VT_DEF_COLOR = VT_BG<<4 | (VT_FG | 8 if
  bold)`, then SGR state reset (FG/BG `$FF`, flags 0) and `_Vt_ApplySgr`.
  Other `Ps` ignored.  `_Vt_Handle_RIS` calls `_Vt_ApplySgr` after
  `Con_VtReset`.
- [ ] `console_char.s`, `Con_PutChar`: `AND #$007F` -> `AND #$00FF`; the
  `CMP #$7F / BCS @ch_exit` "DEL and above" arm -> `BEQ` (DEL only).
- [ ] `console_render.s`: both colour decodes map through the tables under
  8-bit X (the CharBuf offset is already on the stack; `_conScratch5+1` is an
  alias of `_fsTmp1` and is never written); both glyph loads mask `AND #$007F`
  where they had `AND #$00FF`.
- [ ] `console_init.s`: the boot default and the post-build restore store
  `VT_FG = 7`, `VT_BG = 0`, `VT_DEF_COLOR = $07`; `_Con_ClearShr` takes its
  fill slot from `_Con_BgSlot[VT_BG & $0F]`.
- [ ] `coninv.json`: the fgbuf golden is sha256 of 8000 x `$07`; the
  description says so.
- [ ] `sscon_check.py`: the ring's byte is compared unmasked (the card takes
  `$20-$FF` raw; below `$20` is blank).
- [ ] Build: `ninja` -- expect no errors; `tools/check_kernel_ceiling.py` far
  bank still within its ceiling.
- [ ] Verify (closed loop, headless): the scratch `shrbase` manifest ->
  `mem.shr_full sha256 matches` (`0d3a3688...`); `run.py coninv smoke
  vccurstype sscon ssconscroll ss4focus` -> all PASS.
- [ ] Commits: (a) the cell model, (b) SGR 38/48, (c) RIS applies the reset
  colours.  Each body quotes what it followed (console_codes(4), Linux vt.c).

### Task 2: the card's VGA palette (`sscon`)

**Files:** `src/modules/sscon/sscon.s`,
`src/kernel/far/console/console_backend.s`.

- [ ] `sscon.s`: the template's 48 palette bytes are the VGA sixteen in ANSI
  order (spec 2.4); `_ssTable` loses its `+15` entry; `_Ss_Alloc` stops
  storing into it.
- [ ] `console_backend.s`: `Con_SetBackend` stops after the five operands --
  the palette conversion, `@sb_nib` and the table's `+15` description go.
- [ ] Build; `run.py sscon ssconscroll ss4focus` PASS; the `sscon` dump's
  `card.png` shows the prompt light grey on black.
- [ ] Commit.

### Task 3: `ansicat(1)` and the `ssansi` test

**Files:** create `src/userland/ansicat/ansicat.c`,
`src/userland/man/pages/cat1/ansicat.0`, `disk_src/testdata/ansi.ans`,
`tools/mame_test/tests/ssansi.json`, `tools/mame_test/ssansi_check.py`;
modify `tools/ninja/manifest.json` (tool `ansicat`, staged to
`disk_src/usr/fgx/bin/ansicat`), `tools/gate.sh` (`ssansi` after `sscon`).

- [ ] `ansicat.c`: `getopt` `-b`; `TIOCLGET` into a saved `int`, `TIOCLBIS
  LLITOUT`; `signal(SIGINT, ...)` restoring; `ESC[0m ESC[2J ESC[H`; per file
  `getc` to EOF or `^Z`; `-b`: `per = baud/10` bytes a second, an accumulator
  adds `per` each tick and releases bytes while it holds 60, `nanosleep(1)`
  between ticks; `fflush` before each sleep; `ESC[0m`, `TIOCLSET` saved.
- [ ] The fixture, `disk_src/testdata/ansi.ans`, five rows then `^Z` and a
  SAUCE record:
  row 0 `ESC[1;33;44m` `BRIGHT` (attr `$4B`);
  row 1 `ESC[0;5;41m` `BLINK` (attr `$97`);
  row 2 `ESC[0m` `$DB $B0 $B1 $B2` (attr `$07`);
  row 3 `ESC[0;38;5;196m` `CUBE` (attr `$09`);
  row 4 `ESC[0;48;2;0;0;255m` `RGB` (attr `$47`);
  each row ends `ESC[0m CR LF`.
- [ ] `ssansi.json`: card in slot 3; `sh`, then `ansicat -b 9600
  /testdata/ansi.ans > /dev/ttyv3`; regions `klog`, `mirror`, `vc3chars`,
  `vcstate`; `check_script: ssansi_check.py`.
- [ ] `ssansi_check.py`: the mirror address from the log line (as
  `sscon_check.py`); visible row v is mirror row `(start_line + v) % 100`;
  asserts each row's first cells' char and attr bytes above, and that
  `SAUCE` is nowhere in ttyv3's ring.  Exit 0/1/2 as `sscon_check.py`.
- [ ] Man page per the spec's 2.5, overstrike emphasis
  (`tools/check_man_overstrike.py` clean).
- [ ] Build; `run.py ssansi` PASS.  Positive controls, one rebuild each,
  restored by edit: `_Vt_ApplySgr` folding through `_Con_FgSlot` again ->
  `ssansi` FAIL on the attrs; `Con_PutChar` masking `$7F` again -> FAIL on row
  2.
- [ ] Commit.

### Task 4: gate, docs

- [ ] `tools/gate.sh` green.
- [ ] The Second Sight plan: section 3.4's colour claim corrected in place;
  section 7.2 names this work.  The design doc gains an as-built section with
  the measurements.  `docs/ROADMAP.md`: one paragraph.
- [ ] Commit; the project notes episode for the as-built record.
