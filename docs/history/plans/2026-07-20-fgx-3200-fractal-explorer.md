# FGX 3200-color SHR graphics layer + Mandelbrot/Julia explorer — design

Date: 2026-07-20
Status: DESIGN (approved in brainstorm; awaiting spec review before implementation plan)
Author: the maintainer + Claude

## Goal

Two deliverables:

1. **`libfgx/gfx`** — a reusable Super Hi-Res graphics abstraction layer that
   concentrates the machine-specific inline/hand asm so future 3200-color
   projects never touch SCBs, banks, or the scanline IRQ directly.
2. **`fractal`** — a userland Mandelbrot/Julia explorer that is a thin C client
   of `gfx`, rendering in true 3200-color mode as the flagship showcase.

The explorer is the first *client* of the layer; the layer is the primary
long-lived artifact.

## Non-goals / out of scope

- **Floating point.** All fractal math is integer fixed-point. No softfloat/libm
  on the hot path.
- **Smooth (continuous / `log`-based) escape coloring.** Needs float
  transcendentals per pixel. Deferred — it is the natural first client of the
  future Number Cruncher Reloaded (APU) libm-offload path (see
  `docs/` / the project notes `fgx` decision "NCR as fcc/libc softfloat backend").
- **Zoom depth past 24 fractional bits.** Would require arbitrary-precision
  bignum. Deferred.
- **>255 iterations.** Would make the iteration buffer 16-bit/pixel → two banks
  → hits the fcc pointer-arithmetic-past-64KB gap. Deferred.
- **640-mode fractal.** 3200-color is a 320/4bpp trick; there is no 640-mode
  equivalent. The layer switches to 320 for the fractal and restores the
  console on exit.
- **Per-line median-cut / histogram palette optimization.** Range-fit is enough
  for typical views; noted as an upgrade path, not built.

## Hardware background (verified in repo, 2026-07-20)

- SHR pixels at `$E1:2000` (32000 B, 4bpp/320). SCBs at `$E19D00` (200 bytes,
  one per scanline; bit 7 = 320/640 select, bits 0-3 = palette 0..15). Palettes
  at `$E19E00` (16 palettes x 16 colors x 2 bytes; `xxxxRRRR GGGGBBBB`).
- Only **16 hardware palette slots** exist. "3200 colors" = 200 lines x 16,
  achieved by reloading palette RAM per scanline via the **VGC scanline
  interrupt** (`$C023` flag bit 2, `$C032` control, `$C034` ack).
- FGX today: SHR display, per-8-scanline-row palette selection for the text
  console (`Con_SetRowPalette` + SCBs), VBL IRQ (line 192) for timing. **No
  scanline-IRQ palette engine exists** — tier 3 is new machinery.
- `console_altscreen.s` already snapshots/restores console buffers — the
  save/restore precedent for the mode switch.
- **3200-color mode is known to render correctly under MAME**, so tier 3 is
  closed-loop (pixel-hash) testable, not visual-only.

## Architecture

### A. `libfgx/gfx` — the graphics layer

C-callable surface; asm concentrated here.

| API | Behavior | Tier |
|---|---|---|
| `gfx_enter()` / `gfx_exit()` | Save SCBs + palettes, set all SCBs to 320 (bit7=0), enable SHR. On exit: restore SCBs + palettes and force a console repaint from `CON_FGBUF`/`CON_BGBUF` (cheaper than saving/restoring 32KB of pixels). | both |
| `gfx_plot(x,y,c)` + span/row writers | Pixel & scanline writes into `$E1:2000` (banked 24-bit stores). | both |
| `gfx_set_line_palette(line, colors[16])` | The single palette funnel. Tier 2 → write the SCB band palette; Tier 3 → stage the per-line palette table. Same call, both tiers — this is what makes tier 3 additive. | both |
| `gfx_show()` / `gfx_hide()` | Tier 2: no-op (SCBs static). Tier 3: install/remove the scanline-IRQ palette-reload engine. | tier 3 |

**Asm boundary.** `gfx` primitives are C with `__asm` islands (banked stores,
mode registers) per the "new tools in C/fcc" policy. The **one** hand-asm
exception is the tier-3 scanline-IRQ handler (interrupt context,
timing-critical) — the low-level carve-out the policy allows.

### B. `fractal` — the explorer (userland C client)

Knows nothing about SCBs, banks, or IRQs. Flow: fixed-point compute →
iteration buffer → colorize → `gfx_*` display.

## Compute

- **Fixed-point 8.24 signed (32-bit).** Byte-aligned descale (`>>24` = drop 3
  bytes, a free reindex). 24 fractional bits ~6e-8 depth. Integer headroom ±128
  covers escape radius. `16.16` is the simpler/shallower fallback.
- **Hot loop = one routine:** signed **32x32 -> 64** fixed-point multiply +
  descale (`zr^2 - zi^2`, `2*zr*zi` per iteration per pixel). The 65816 has no
  hardware multiply; this is the perf center and the eventual NCR offload target.
- **Iteration buffer: 1 byte/pixel, cap 255 iterations → 320x200 = 62.5KB →
  single bank.** Deliberately under 64KB to avoid the fcc ptr-arith-past-64KB gap.

**Two passes (clean seam):**
1. **Compute** — fill the 64000-byte iteration buffer. Mode-independent, no
   graphics. Deterministic → pixel-hashable with zero graphics dependency.
2. **Colorize** — assign palettes + write 4bpp pixels to `$E1:2000`. The only
   pass that differs between tiers.

## Color strategy

- Each horizontal scanline shows only its 16 palette colors. Tier 3 gives each
  of 200 lines its own 16 → 3200 on screen.
- **Range-fit per band:** for each band, scan iteration values, find `min..max`,
  lay a 16-stop gradient across that range, quantize each pixel to nearest stop.
  Fractal iteration is locally continuous, so 16 fitted stops per line read as
  smooth; 200 different fits = the 3200-color look. Interior (never escaped) =
  black.
- **One colorize routine parameterized by band height `H`:**
  - Tier 2: `H=8` → 25 static SCB palettes, no IRQ.
  - Tier 3: `H=1` → 200 per-line palettes → scanline-IRQ engine.
  - Same range-fit code, same `grad(t) -> 12-bit RGB` gradient function. Only the
    palette count and who loads them differ. Tier 2 = tier 3 at `H=8`, not
    throwaway scaffolding.

## Controls / UX

Graphics mode, tty in raw mode (existing sgtty raw).

- Arrows / `hjkl` move a zoom-target crosshair; `+`/`-` set zoom factor (fast:
  just numbers + crosshair marker).
- Space = compute & display selected view (the slow pass).
- `j` toggles Julia (c = current center) ↔ Mandelbrot; `q` = quit → `gfx_exit`.
- Crosshair = XOR a few framebuffer pixels (no box-drag machinery).
- Progress feedback is free: the compute pass fills scanlines top-to-bottom, so
  the image builds row by row = the progress bar.

## Staging

- **Milestone 1 (tier 2):** `gfx_enter/exit/plot/set_line_palette` at `H=8` +
  compute + range-fit colorize. Colorful explorer, ~400 colors, fully
  headless-testable. No IRQ code.
- **Milestone 2 (tier 3):** add the scanline-IRQ engine behind `gfx_show/hide`
  and run colorize at `H=1`. Full 3200-color. Additive; does not touch the
  fractal or tier-2 tests.

## Testing

- **Compute pass → headless.** Deterministic iteration buffer → pixel-hash.
  Mode-independent. T1-tier.
- **Tier-2 colorize → headless.** `H=8` framebuffer → `shr_framebuffer`
  pixel-hash goldens (full set + a couple known zooms).
- **Tier-3 colorize → headless (MAME).** 3200-color mode renders correctly under
  MAME, so the scanline-IRQ engine gets framebuffer pixel-hash goldens too — not
  visual-only.
- **Fixed-point multiply → host unit test.** Validate 32x32->64 mul + descale
  against a `double` reference within tolerance. The one runnable check for the
  hot routine.

## Deferred / future (recorded, not built)

- Number Cruncher Reloaded (APU) as fcc/libc softfloat + libm backend →
  smooth-coloring + deep-zoom acceleration. Needs a MAME driver for the card
  first (the maintainer owns the physical card). See the project notes `fgx` NCR decision.
