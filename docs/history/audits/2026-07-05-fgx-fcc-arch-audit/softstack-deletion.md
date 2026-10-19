# Follow-up: soft-stack deletion arithmetic (bank-0 hardware stacks)

> Part of the 2026-07-05 FGX/fcc architecture audit. Question: can FGX delete
> the fcc soft stack and put C locals back on bank-0 hardware stacks (the GNO
> model, NPROC=32 on identical hardware)?

## 1. Bank-0 carve map (per include/kernel.s @ Jul 5; docs/memory-map.md of
Jun 16 is stale)

| Range | Size | Owner |
|---|---|---|
| $0000–$00FF | 256 B | boot kernel DP (stale after boot) |
| $0100–$01FF | 256 B | kernel/interrupt stack; emul-mode SmartPort firmware |
| $0200–$02FF | 256 B | FGX_SYSVARS (kept per Fix #2 revert) |
| $0300–$07FF | 1.25 KB | vectors + trampolines (SYS_TRAMP $0328, MOD_JT_GATEWAY, sim/cd/fst/net tramps) |
| $0800–$0FFF | 2 KB | FGX_BOOTAREA — transient, free after boot (reclaim candidate) |
| $1000–$1FFF | 4 KB | per-task KERNEL stacks, 256 B × 16 (must stay fixed) |
| $2000–$2FFF | 4 KB | BLK_STAGE — SmartPort staging actually uses 512 B (reclaim ~3.5 KB) |
| $3000–$3FFF | 4 KB | legacy per-task user stacks (init + first-run argv only; reclaim candidate) |
| $4000–$AFFF | **28 KB** | FGX_STK_ARENA — 112-page bitmap, first-fit, per-task 1..16 pages |
| $B000–$BFFF | 4 KB | FGX_DP_KTASKS — 16 × 256 B DP pages |
| $C000–$CFFF | 4 KB | I/O (hardware) |
| $D000–$FFFF | 12 KB | language card (avoided) |

## 2. Per-task hardware-stack window (worst case, equal division)

| NPROC | 28 KB arena (today) | 38 KB arena (reclaim $0800+$2000+$3000) |
|---|---|---|
| 4 | 7,168 B | 9,728 B |
| 6 | 4,608 B | 6,400 B |
| 8 (today) | 3,584 B | 4,864 B |

The arena is first-fit shared and per-binary sized via the FGX1 header's
`stack_pages_hint` (include/loader.s:22) — GNO fit NPROC≈32 because binaries
DECLARE their need (`#pragma stacksize`, typically 512–3072 B in the vendored
tree); FGX already has the identical mechanism.

**The 16 KB soft stack was picked, not measured**: `_CRT0_SSSIZE EQU $4000`
(toolchain/lib/crt0.s:61), "≈3× elvis's measured peak". The design spec
records the real distribution: **median frame 4 B, 82% of frames ≤ 16 B,
worst single frame ~4 KB, elvis dynamic peak ~5–6 KB**
(docs/superpowers/specs/2026-07-01-fcc-software-stack-design.md:40-41).
Every task burns a 16 KB heap malloc (8 tasks = 128 KB of user-bank heap).

## 3. Origin verdict: POLICY, not hardware

Trigger: elvis `add()` declares two 2048 B BLK buffers → ~4.2 KB frame →
fcc's `MAX_TOTAL_SLOTS` (2048 slots = 4 KB) rejected it. That cap mirrors
`TASK_STACK_MAX_PAGES EQU 16` (task.s:476, "4 KB cap per the vi-port plan") —
an allocation-policy knob on a 28 KB shared arena. Real hardware limits: S is
16-bit and the stack must be bank 0; `n,S` displacement is 8-bit. A 4.2 KB
frame fits a 17-page window; the cap was never raised. The deleted hard-frame
model already had a >255-offset far fallback via `_fcc_fp` (emit.c G53), so
big frames were codegen-supported before the soft stack existed.

## 4. Codegen payoff of returning to the hardware stack

| Operation | Hard stack | Soft stack (today) |
|---|---|---|
| local load/store ≤255 | `LDA/STA n,S` — 2 B, 5 cyc | `LDY #ofs` + `LDA [_fcc_ssp],Y` — 5 B, ~10 cyc, clobbers Y |
| local >255 | `_fcc_fp` far fallback ≈ 11 B | same 5 B |
| prologue/epilogue | ≈ 8 B | ≈ 8 B + TAY/TYA dance — a wash |
| `&local` | **bank 0 by construction** | far pointer (offset + `_fcc_ssp+2`) — every consumer bank-aware |

82% of frames ≤16 B ⇒ the 2 B/5 cyc case dominates. Aggregate: soft-stack
codegen pushed jsh past FGX1's 64 KB cap. Beyond size: the soft stack created
the 4th bank class (the structural whack-a-mole), the caller-buffer-bank shim
rule, and the Y-clobber bug family. `&local`=bank-0 kills the locals-specific
instances of all three.

**Caveat:** the hard-frame model was **deleted**, not flagged off — v0.21.0
"Delete the dead !g_soft_stack hardware-frame model" (toolchain b31e84f).
Reverting is code resurrection from git history + full golden churn (~347).

## 5. What breaks

- add()-class 4.2 KB frames need TASK_STACK_MAX_PAGES 16→32; one elvis-class
  task then eats 8 KB of 28 KB (≤3 concurrent big tasks — acceptable).
- Sizing has no call-graph analysis: fcc's auto-hint is largest SINGLE frame
  +128 B (main.c:436-444); chain sums (elvis 5–6 KB) overflow hint-sized
  stacks silently. Needs a static call-graph sum (cross-TU ⇒ linker involved)
  or GNO-style per-binary declaration.
- **FGX2 has no stack field**: `fcc_stack_pages` is FGX1-header-only; under
  --far-calls fcc emits nothing (main.c:449-455) → FGX2 binaries get the
  1-page default. FGX2 manifest + fgx_ld + loader need the field.
- Overflow behavior: soft stack v1 has no guard either (boundary-tag
  corruption caught at free); a hardware-stack overflow walks into the
  neighbor task's arena pages — mitigate with a prologue `TSC/CMP #limit`
  guard (~6 B, big-frame prologues only; already sketched in the spec).
- Recursion ceiling drops to the window (3.5–8 KB). Largest local array in
  tracked userland C is 1 KB (tctest.c:39); typical 512 B — fine. Only
  elvis-class ports at risk.

## 6. Recommendation: hybrid, biased toward delete

Locals return to the bank-0 hardware stack (2-byte `n,S`, bank-0 `&local`,
3-bank model). fcc grows **compiler-owned heap-boxing for large aggregate
locals** (frame slot holds a far pointer; prologue mallocs, epilogue frees;
threshold ~1 KB) — add() compiles unmodified, scalar codegen stays 2 B/5 cyc,
and the far-pointer deref machinery the soft stack validated is reused.
Per-binary stack size via `stack_pages_hint` + call-graph-sum sizing + the
FGX2 manifest field; TASK_STACK_MAX_PAGES → 32; reclaim $0800/$2000/$3000
(+10 KB → 38 KB arena) when NPROC pressure appears.

**Measure first (cheap, decisive):**
1. elvis soft-stack high-water via fgxdebug `capture_writes` on `_fcc_ssp`
   (DP $BC) through a full edit session — the 5–6 KB figure is a design-doc
   estimate. If real scalar-chain peak ≤3.4 KB after boxing, NPROC=8 works on
   today's 28 KB arena untouched.
2. Per-binary call-graph frame sums for the shipped userland (fcc already
   computes `g_max_framesize`; extend + dump in one compile sweep).
3. Golden size delta: rebuild 2–3 big TUs with pre-b31e84f fcc to quantify
   the soft-stack size tax precisely.
