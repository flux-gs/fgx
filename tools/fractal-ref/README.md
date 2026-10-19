# fractal-ref -- host reference oracle

Portable-C implementation of the exact 8.24 fixed-point Mandelbrot/Julia
iteration used by the FGX `fractal` tool. It exists so the on-device
iteration-buffer goldens are derived from an independent host oracle, not
self-recorded (FGX "validate against a host C reference" policy).

## Build / test

    make selftest      # fix_mul smoke test, 8/8 ok
    make goldens       # prints GOLDEN_FULLSET (full-frame hash) + GOLDEN_TILE

## Format: Q12 pure-C fixed point (no asm)

Fixed-point Q12 (`FBITS=12`). Because fixmul operands stay small (|z|<=~2 before
the escape break), the product `a*b` fits in signed 32-bit, so `(a*b)>>12` is a
plain 32-bit expression -- NO 64-bit intermediate, NO hand-asm multiply on the
65816 (fcc's `long*long` gives exactly this low-32 product). Trade: ~12-bit zoom
depth. Deep zoom (8.24 + a 32x32->64 asm helper) is the tracked upgrade.

Bit-identical contract: the escape test, z-updates, AND `fix_mul` all use 32-bit
signed `long` arithmetic -- byte-identical to fcc on the 65816. The on-device
`fractal --sum` test confirms the shift/multiply semantics match (djb2 checksum).

Fidelity: vs an independent float Mandelbrot, 94.6% of the full 320x200 frame is
within 1 iteration; the ~5% that differ are boundary/filament pixels where the
set is genuinely chaotic (any finite precision diverges there). Validated
2026-07-20.

## Goldens (consumed by tools/mame_test/tests/)

Full-set view: cr in [-2.5, 1.0], ci in [-1.5, 1.5], 320x200, 255 iters.
  cr0=-10240 (-2.5*2^12)  ci0=-6144 (-1.5*2^12)  step=45 (3.5/320*2^12)
    GOLDEN_FULLSET = ca84809686e2b0e257e51ee510974c95ad6e90e3e5360572358aeb48c10babb7

Oracle tile (fast on-device check): 48x30, maxit 64, over the period-2 bulb.
  cr0=-8192 (-2.0)  ci0=-2458 (-0.6)  step=45
    GOLDEN_TILE = ITSUM=-1446507476   (djb2 over iteration bytes, printed as %ld)

`fractal_ref` is a build artifact (git-ignored); regenerate with `make`.
