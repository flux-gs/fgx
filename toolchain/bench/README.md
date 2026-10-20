# fbench — fcc benchmarking harness

Tracks four metrics across codegen changes: object/binary size, kernel size,
direct-page usage, execution time. ADVISORY — it does not gate the build.

## Correctness vs speed — do not confuse them
- CORRECTNESS is gated by `toolchain/tests/run_runtime.py` (exit code vs oracle.json)
  and `run.sh` (golden bytes). fbench never checks correctness.
- SPEED is measured here, two ways:
  - **Option A — bare-metal** (`fbench.py`, `cycles.py`): headerless binary
    (`corpus/_wrap_bench.s`, ORG $1000) loaded raw into MAME at $1000. Runs at a
    clean IIgs **slow 1.023 MHz**, so `emu.time()×1.023MHz` gives accurate cycle
    counts. BUT only the simplest benches run bare-metal — anything needing more
    runtime (div/mod, pointers, static data, recursion) hangs. Use for clean
    absolute cycles on shift/mul-class benches.
  - **Option B — real kernel** (`fbench_kernel.py`): each bench is an FGX1 binary
    staged on a disk and run under the booted FGX kernel via `tools/mame_test/run.py`.
    The whole corpus runs correctly. Metric is **`us_per_call`** (emulated
    microseconds of the hot loop): the kernel runs fast mode (~2.2 MHz effective,
    with IIgs memory slowdowns) and this MAME build exposes no CPU cycle counter,
    so absolute "cycles" are approximate and NOT comparable to the 1.023 MHz
    reference numbers — the authoritative signal is the **baseline-vs-current
    delta** in `us_per_call`.

## Cycle markers
Each bench brackets its hot loop with `fbench_start();` / `fbench_done();`
(`corpus/marker.h` → `corpus/fbench_markers.s` asm helpers: `STAL` a sentinel to
bank 2 $025000/$025002, DBR-independent). The SAME `.c` builds for both Option A
(`_wrap_bench.s`) and Option B (`_wrap_fbench.s`) — only the link wrapper differs.
Call them DIRECTLY, never via a function-like macro (fcc miscompiles those — see
`feedback_fcc_funclike_macro_call_empty_jsr`).

## Layout

    toolchain/bench/
      README.md             — this file
      fbench.py             — Option A driver: size/system/dp + bare-metal cycles
      cycles.py             — bare-metal MAME cycle runner (resolves Ample MAME)
      cycles_collect.py     — bare-metal corpus build + measure
      dp_collect.py         — DP-budget collector
      scoreboard.py         — unified scoreboard printer
      fbench_kernel.py      — Option B driver: build FGX1, stage on disk, run under kernel
      corpus/
        marker.h            — fbench_start()/fbench_done() decls
        fbench_markers.s    — asm marker helpers (PUT into both wrappers)
        _wrap_bench.s       — headerless bare-metal wrapper (ORG $001000)
        _wrap_fbench.s      — FGX1 wrapper for the kernel path (ORG $0B0000)
        <name>.c            — benchmark source (markers bracket the hot loop)
        <name>.link.s       — bare-metal Merlin32 link (ASM _wrap_bench.s)
        refs.json           — optional indicative reference cycles
      baselines/            — committed JSON snapshots (one per toolchain tag)
      reports/              — generated (gitignored)

## Run
    # Option A (size/system/dp + bare-metal cycles for benches that run there):
    python3 toolchain/bench/fbench.py snapshot <tag>      # -> baselines/<tag>.json
    python3 toolchain/bench/fbench.py compare <base.json> # vs current tree
    python3 toolchain/bench/fbench.py report

    # Option B (full corpus under the real kernel; needs cadius + MAME):
    python3 toolchain/bench/fbench_kernel.py              # -> reports/kernel_cycles.json
    python3 toolchain/bench/fbench_kernel.py --only t12_shift,t12_mul   # subset

## Add a benchmark
1. corpus/<name>.c: `/* ITERS=N */` (N>=2000), `#include "marker.h"`, a
   self-contained `int main(void)` whose hot loop is bracketed by
   `fbench_start();` … `fbench_done();` and which returns a value.
2. corpus/<name>.link.s: `TYP $06 / DSK <name> / ORG $001000 / ASM _wrap_bench.s`
   (the FGX1 link for Option B is generated on the fly by fbench_kernel.py).
3. Optional reference cyc in corpus/refs.json (labeled indicative-only).
4. `fbench.py report` (Option A) and/or `fbench_kernel.py --only <name>` (Option B).

## Update the baseline
After a codegen change lands and goldens + run_runtime are green:
    python3 toolchain/bench/fbench.py snapshot toolchain-<tag>
    python3 toolchain/bench/fbench_kernel.py --out toolchain/bench/baselines/toolchain-<tag>.kernel.json
    git add toolchain/bench/baselines/toolchain-<tag>*.json

## Rot status, 2026-08-09

The corpus stopped assembling when fcc went SINGLE-ABI. fcc used to emit a
bare `JSR name` for a call to an extern it had not seen -- `fbench_markers.s`
states that in its own header, "verified: no name mangling" -- and now emits
`FGX2_FARCALL name`, ends every function in RTL, and stamps each TU with
`FGX2_MODE` / `FGX2_RELOC_COUNT`. Those are macro invocations and the wrappers
PUT no macro file.

The failure was invisible in the report. Every bench came back `merlin-fail`,
which prints as `SKIP`, which is indistinguishable from a bench nobody had got
round to configuring. `fbench.py snapshot` cheerfully reported "0 benches".

**Option A (bare-metal) is REPAIRED.** Three changes: `corpus/bench_macros.s`
supplies the FGX2_* macros with `FGX2_FARCALL` as a same-bank synthesized JSL
(PHK + PER + JMP -- relocation-independent, and the 3-byte frame an RTL wants);
`fbench_markers.s` returns RTL instead of RTS to match; and `_wrap_bench.s`
reaches `main` the same way and stubs `SYS_TRAMP`/`SYS_EXIT`, which
`fcc_runtime.s`'s three trap routines need and bare metal has no kernel for.
The stub SPINS rather than returning, so a bench that trips a stack guard times
out visibly instead of reporting a meaningless number.

`t12_divmod`, `t12_mul` and `t12_shift` now measure again (157.3, 124.2 and
150.3 cycles/call). The rest build but hang, which is the limitation this
README already documents for bare metal -- they need the kernel.

**Option B (real kernel) is NOT repaired**, and it is the one that matters,
because it is the path that runs the whole corpus. It has at least three
further rots stacked behind the first, each only visible once the one before
it is fixed:

1. `libc.s` gates on `LIBC_FAR`, which `fcc_libc_shims.s` defines -- but the
   shims are PUT after libc.s, so the DO cannot evaluate. A `LIBC_FAR EQU 0`
   ahead of the PUTs is in `_wrap_fbench.s` now and clears this one.
2. The FGX1 header's `DFB fcc_stack_pages` is unresolved. The linker normally
   supplies it from `stack_measure.py`; a hand-written wrapper does not.
3. Unknown -- 2 is as far as this went.

Until Option B works there is NO cycle measurement for anything using
pointers, static data or recursion, which is most real code. The 0.1 gate's
missing third measurement is blocked on exactly this.

## The base disk is an INPUT, and it is now checked

`fbench_kernel.py` stages every bench onto a copy of `disk/fgx.po` and runs it
under the kernel and libc that disk carries. A disk built from a different
compiler than the one under test therefore measures the wrong thing -- the
disk is part of the measurement, not just a container for it.

It is also the harness's most confusing failure. Rebuilding fcc invalidates
the whole userland, so a disk left stale by an interrupted build makes EVERY
bench report `no marker / timeout`, which reads as a broken harness rather
than a stale input. That cost an hour on 2026-08-09, chasing the harness while
the inputs were the problem.

`check_base_disk_fresh()` now runs BEFORE anything is built or staged, and
refuses. Authority is `ninja -n disk` -- ninja's own dependency graph -- not an
mtime comparison, because mtimes cannot see that the userland is stale against
a rebuilt compiler. Pass `--rebuild-disk` to rebuild instead of refusing.

Verified both ways: it returns clean on a fresh tree, and rebuilding fcc alone
is enough to make it fire with the pending edges named. Note that touching a
compiler SOURCE file does not trip it and should not -- ninja tracks
`toolchain/fcc`, so the disk only goes stale once the compiler is actually
rebuilt.
