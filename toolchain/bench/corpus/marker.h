/* marker.h — fbench cycle markers, callable from C.
 *
 * A benchmark brackets its hot loop with `fbench_start();` ... `fbench_done();`.
 * These are asm helpers (fbench_markers.s) — fcc emits a bare JSR to the name (no
 * mangling) — that STAL a sentinel to bank 2 ($025000 START / $025002 DONE). The
 * fbench harness taps those writes and captures emu.time() at each, so call
 * fbench_start() as the LAST thing before the loop and fbench_done() as the FIRST
 * thing after it. No spin: the bare-metal wrapper spins after `JSR main`; under
 * the kernel, main just returns. The same .c builds for both run modes (bare-metal
 * Option A and real-kernel Option B) — only the link wrapper differs.
 *
 * NB: call these DIRECTLY, not via a function-like macro. fcc miscompiles a
 * function-like macro whose replacement is a call — `#define M() f()` then `M();`
 * emits an EMPTY `JSR` (target lost). Tracked as an fcc preprocessor bug to fix
 * in the toolchain; until then, direct calls (which codegen correctly) are used. */
#ifndef FBENCH_MARKER_H
#define FBENCH_MARKER_H
void fbench_start(void);
void fbench_done(void);
#endif
