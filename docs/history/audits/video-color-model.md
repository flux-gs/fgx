# FGX Console — Current Color Model

> **HISTORICAL (2026-04 phase-1 record).** This describes the ORIGINAL colour
> model, where the foreground was always pixel-value 3 and text rendered as
> 4-colour vertical stripes. That is **no longer how the console works**: it now
> builds `ExpandWord` at runtime per fg/bg pair and renders per-cell foreground
> and background against mirrored ANSI palettes, so text renders uniform. For
> current behaviour see [drivers/console.md](../../drivers/console.md). The hardware
> substrate below (640-mode palette groups, SCB layout, `$E1:9D00`/`$E1:9E00`,
> SHADOW bit 3, 160 B/scanline) is still accurate.

**Status**: captured 2026-04-17, validated visually in `test/video/tests/t46_rainbow_scroll.s`.

This describes how colors are produced on screen **right now** in the phase-1
framebuffer work. 

---

## Hardware substrate — IIgs SHR 640 mode

**Pixel layout**

- 640×200, 2 bits per pixel, 4 pixels per byte, 160 bytes per scanline.
- 32,000 bytes of SHR pixel memory at bank `$E1:2000 — $E1:9CFF`.
- 200 Scanline Control Bytes at `$E1:9D00 — $E1:9DC7` (one per scanline).
- 16 palette tables at `$E1:9E00 — $E1:9FFF`, each 16 entries × 2 bytes.
- We write pixels via bank `$01` shadowing (SHADOW bit 3 = 0 makes `$01:2000+`
  mirror to `$E1:2000+`).

**2-bit pixel values don't directly name a palette entry.** 640 mode splits
the 16-entry row palette into 4 groups, one per **byte position**:

| byte position (bits) | pixel value 0 | 1 | 2 | 3 |
|----------------------|---|---|---|---|
| position 0 (7-6, leftmost)  | entry 0  | 1  | 2  | 3  |
| position 1 (5-4)            | entry 4  | 5  | 6  | 7  |
| position 2 (3-2)            | entry 8  | 9  | 10 | 11 |
| position 3 (1-0, rightmost) | entry 12 | 13 | 14 | 15 |

**Formula**: palette entry rendered = `(byte_position × 4) + pixel_value`.

So in 640 mode a single scanline can show up to 16 distinct colors using
just a 16-entry palette — but the colors available at each pixel column
are fixed to one group of 4, determined by that column's position within
the byte.

**SCB byte** (`$E1:9D00 + scanline`) selects:

- bit 7 (`$80`): 640 mode (we always set this)
- bit 6 (`$40`): fill mode (we leave cleared)
- bit 5 (`$20`): scanline IRQ (we leave cleared)
- bit 4: reserved
- bits 3-0: palette index 0..15 (which of the 16 palette tables this
  scanline uses)

---

## FGX text grid on top of that substrate

- Cell = 8 pixels wide (6-pixel glyph + 2-pixel right padding) × 8
  scanlines tall. 8-px cell pitch → byte-aligned → 80 columns, 25 rows.
- One **row** of text spans 8 scanlines, all assigned the same palette
  via their SCB bytes (so the whole row's 8 lines share a 16-entry palette).
- Glyphs are 1-bit 6×8 fonts (`test/video/harness/font_6x8.s`). Each font
  byte holds 8 bits; the top 6 bits are glyph pixels (columns 0..5), the
  bottom 2 bits are the padding columns (held at 0).

---

## From font bit to pixel value — the `ExpandWord` table

The renderer maps a 1-bit glyph byte to 2 SHR bytes per scanline (the
cell's 8 pixels). The `ExpandWord[256]` lookup table (defined in every
test that renders glyphs) does this in one memory read per scanline:

```
ExpandWord[F] = V[F>>4] | (V[F & $0F] << 8)
where V[n] encodes 4 pixels, each pixel = value 3 if that bit is set
in n, value 0 otherwise. V = [$00, $03, $0C, $0F, ..., $FF].
```

Practical effect: **every foreground pixel gets value 3; every background
pixel gets value 0.** That single design choice is what creates the
"vertical-stripe" color pattern that reads as soft dithering on screen —
see next section.

---

## How a single character ends up colorful

A 6-pixel-wide glyph spans these byte positions across the cell:

| glyph column | byte position | palette entry when value 3 (fg) |
|--------------|---------------|-------------------------------|
| col 0 | byte 0 pos 0 | **entry 3**  |
| col 1 | byte 0 pos 1 | **entry 7**  |
| col 2 | byte 0 pos 2 | **entry 11** |
| col 3 | byte 0 pos 3 | **entry 15** |
| col 4 | byte 1 pos 0 | **entry 3**  |
| col 5 | byte 1 pos 1 | **entry 7**  |

So every character foreground cycles through the 4 colors stored at
palette entries 3, 7, 11, 15, in vertical stripes: **A B C D A B**.

Background is similar but with value 0: every glyph background pixel
draws from entries 0, 4, 8, 12 (stripes E F G H E F). Normally we set
all four bg entries to the same K so the background reads as solid
black.

If a palette's entries 3/7/11/15 are all the same color, characters
render as one flat accent on K background. If they're four different
colors (as in `t46_rainbow_scroll.s`), each character becomes a
4-color vertical gradient. Small glyphs + per-column color variety =
the apparent "dither" effect that currently reads well.

---

## Max colors on screen

Under the current mechanism:

- **Per character**: up to 4 distinct foreground colors (stripes from
  palette entries 3/7/11/15) + up to 4 distinct background colors
  (entries 0/4/8/12). Practical max = 8 colors per char, though we
  usually keep bg uniform.
- **Per row**: same palette governs all 8 scanlines → up to 4 fg + 4 bg
  = 8 colors per row in practice.
- **Across rows**: each row can pick any of 16 palettes via its SCB
  byte. With 16 distinct palettes × 4 fg accents per palette = **64
  foreground colors simultaneously** on screen. Add background entries
  and it's up to 128 distinct palette entries addressable at once
  across the 25 rows (16 palettes × 8 meaningful entries each).

That 64-color ceiling is purely an artifact of keeping the glyph
rendering single-bit (value 3 only for fg). A 2bpp font would let us
exploit palette values 1 and 2 as well, which could push per-character
color count higher but requires a new font format and a new `ExpandWord`
variant.

---

## How the scroll preserves colors

`t45_color_scroll.s` / `t46_rainbow_scroll.s` proved the recipe:

- Pixel data lives in bank `$01` SHR mirror (`$012000 — $019CFF`, 32000
  bytes).
- SCBs live at `$01:9D00 — $01:9DC7` (200 bytes).
- A scroll moves **both** blocks in lockstep:
  - Pixels: `MVN $01,$01` from `$2500` to `$2000`, count = 30719 (24
    rows worth), for up-scroll. `MVP` with matching `src_end`/`dst_end`
    for down-scroll.
  - SCBs: `MVN $01,$01` from `$9D08` to `$9D00`, count = 191, for up.
    `MVP` from `$9DBF` to `$9DC7`, count = 191, for down.
- After the block move, the anchor row (row 24 on up-scroll, row 0 on
  down) gets its pixels cleared and its 8 SCB bytes rewritten with a
  fresh palette index — this is why the "incoming" row flashes a new
  color as content streams off the opposite edge.

Each row's palette assignment physically rotates with its pixels, so
colors move with the text.

---

## Known pitfalls (observed during POC work)

1. **DP variable aliasing.** If a 16-bit scroll counter sits at `$FA`
   and an 8-bit helper at `$FB`, any `INC` of the helper bumps the
   counter's high byte every iteration — loop never terminates in
   bounded time. Leave 2-byte gaps between 16-bit DP vars.
2. **MVP `src_end` / `dst_end` off-by-$80.** MVP walks backward, so X
   and Y must be `start + count - 1` exactly. An off-by-$80 error reads
   garbage from RAM below SHR and shifts content by a sub-scanline
   amount that's visually "close enough" to hide the bug on sparse
   content but wrecks dense color.
3. **Per-pixel-position palette groups require conscious palette
   construction.** "Uniform color" means setting entries 0/4/8/12 to
   the same value and 3/7/11/15 to the same value — not just entries
   0 and 1.

See [`iigs-lessons/lessons_merlin32_quirks.md`](../../iigs-lessons/lessons_merlin32_quirks.md) for the full
incident log.

---

## Files of record (HISTORICAL — the `test/video/` tree was deleted)

Nothing replaced these demos; the surviving artifacts are the runtime
`CON_EXPAND` builder and the FGXF fonts in `disk_src/lib/fonts/`.

- `test/video/tests/t45_color_scroll.s` — 16 palettes × 1 accent each
  = 17 on-screen colors, scroll validation.
- `test/video/tests/t46_rainbow_scroll.s` — 16 palettes × 4 accents
  each = up to 64 fg colors, "per-character rainbow stripe" visual.
- `test/video/harness/font_6x8.s` — 1-bit glyph table.
- `include/hardware.s` — SHR register and memory equates.
