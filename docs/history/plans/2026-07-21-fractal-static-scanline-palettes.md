# Plan 2026-07-21 -- fractal: static per-scanline palettes (approved direction)

The maintainer-approved next step after ordered dithering (b0882c3b). Goal: use the
SHR SCBs (each scanline picks one of 16 palettes, ZERO ongoing CPU cost --
no mid-frame rewriting, the 3200 IRQ engine stays parked; it costs ~80% CPU
at the maintainer's 7 MHz) to push effective on-screen colors from ~16 to ~100+ on
zoomed views.

## Why the old attempt failed, and the cures

- STRIPES came from per-line range-fitting: the same count mapped to
  different colors on adjacent lines. Cure: every palette samples the SAME
  global gradient ramp -- a line's palette is a DENSER SLICE of the ramp
  over that line's count range, so any count's color varies only subtly
  across lines.
- SEAMS came from hard 12-row screen-position bands. Cure: group lines by
  SIMILAR COUNT SPANS, not screen position.

## Design

1. **Span collection is free from the progressive renderer**: passes 8/4/2
   already sample every line's lattice. Track per-line min/max escaping
   count in two 200-entry byte arrays during those passes (update in the
   colorize step; skip interior). By the FINAL pass the spans are good
   estimates.
2. **Before the final pass**: build 16 palettes. Simple v1 grouping: sort
   the 200 [lo,hi] windows, split into 16 groups of ~12-13 lines by span
   similarity (1D clustering on (lo+hi)/2 is probably enough); each group's
   palette = 15 colors sampled from the global ramp across the group's
   merged [lo,hi] (index 0 stays black interior). Install via the EXISTING
   stubs: shr_setpaln (palette n) + shr_setscbs (g_scb[200], 320-mode SCB =
   palette number).
3. **Final pass quantizes per line**: idx = 1 + ((c - lo)*14)/(hi - lo)
   against the line's GROUP window, composing with the 2x2 dither (widen by
   2 bits as in b0882c3b: t = ((c-lo)*56)/(hi-lo), threshold bay4).
   Coarse passes keep the current global-16 coloring (preview only; SCBs
   all point at palette 0 until the final pass begins).
4. **'p' cycling**: rebuild all 16 palettes from the new base ramp --
   still instant (16 x 32-byte writes).
5. **Crosshair/help**: XOR invert is palette-agnostic ✓; the help box uses
   index 15 = brightest of whatever palette its lines landed in --
   acceptable, or force those SCB rows to palette 0 while the box shows.
6. **Fallback**: a line whose span exceeds 14 distinct counts still
   quantizes (dithered); a line with no escaping pixels inherits its
   neighbor's palette group.

## Verification

- Headless: extend shr2png.py to honor per-line SCBs + all 16 palettes
  (currently assumes palette 0; shr_scb + shr_palette are already in the
  dump regions).
- The compute goldens are untouched (coloring-only change).
- Watch for: seams at group boundaries (should be subtle), preview->final
  color pop (expected, brief), --rainbow interaction (keep rainbow
  global-16, skip per-line fitting there).

## Files

- src/userland/fractal/fractal.c -- span arrays, grouping, palette build,
  final-pass quantization, SCB assignment on render complete + reset on
  exit (scr_restore already re-inits SCBs to 640).
- tools/fractal-ref/shr3200png.py or shr2png.py -- SCB-aware rendering.
- No kernel changes; no new stubs (shr_setpaln/shr_setscbs exist).
