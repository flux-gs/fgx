# Plan 2026-07-21 — fractal v1: interactive 16-color explorer

Approved by the maintainer 2026-07-21. Supersedes the 256/3200-color push as the
shipping goal (see RESUME-2026-07-21-fgx-3200-fractal.md for why the
full-set 3200 approach stalled). Branch: feat/fgx-3200-fractal.

## Goal

A working, QUICK 320x200x16 Mandelbrot explorer in FGX:
- renders fast and correctly (tier-1 style: single pass, one palette);
- arrow-key crosshair; Enter zooms 2x centered on the crosshair; ESC exits;
- grey ramp default (16-level gradient), --rainbow flag for the old look.

Explicitly deferred: >16 colors (phase 2: palette-map / scanline-IRQ engine,
which works and stays parked), deeper zoom precision, zoom-out, Julia UI.

## Design decisions

- **Zoom depth: shallow v1.** The Q9 quarter-square engine allows integer
  steps only: 6 -> 3 -> 1, then Enter is inert ("max zoom", ~6x linear).
  Deeper zoom needs a wider multiply (Q13 split-table or 32-bit fractint
  style) — a follow-up, not v1. The Q9 engine and its --sum/--sumasm oracle
  checksums are untouched.
- **Coloring:** grey ramp idx = 1 + (c*15)/maxit (monotonic, gradient look),
  interior black. --rainbow keeps pal16 + 1+(c%15) cycling.
- **MAXIT scales with zoom:** 40 + 16/level (deeper views need more iters).
- **Mirror trick** only when the view qualifies (initial view: ci0 == -100*step);
  zoomed views compute all 200 rows.
- **Crosshair:** XOR-invert (15-idx) a 9px cross via new shr_xorpix stub;
  XOR again to erase. No save buffer. Clamped to 4..315 x 4..195.
- **Keys** (raw codes from waitkey): $08/$15/$0B/$0A arrows move 4px;
  vi aliases hjkl (also makes headless paste-injection testable); $0D zoom;
  $1B ESC or 'q' exit. ESC/q polled between rows aborts a render and exits.

## Files

- src/userland/fractal/fractal.c — do_draw rewritten to the explorer;
  band-256 code deleted (git has it). --3200 paths untouched (parked).
- src/userland/fractal/fractal_stubs.s — add shr_xorpix (g_off byte offset,
  g_msk nibble mask, EOR into SHR shadow).
- tools/mame_test/tests/fractal_exit.json — post_commands gain a leading "q"
  (Enter now zooms instead of exiting).
- tools/mame_test/tests/fractal_zoom.json — NEW: inject moves + zoom + q,
  assert clean exit (SCB 0x80) and no PANIC.

## Verification

- fractal_compute / fractal_compute_asm (oracle ITSUM) — must stay green.
- fractal_draw, fractal_exit (updated), fractal_zoom — headless MAME.
- Live check by the maintainer at 16 MHz (mame-hd.sh).
