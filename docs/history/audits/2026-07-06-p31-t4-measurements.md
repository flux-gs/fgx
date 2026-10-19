# P3-1 — T4 (soft-stack delete) measurements

> Phase-3 train, increment P3-1 (2026-07-06).  Data that sizes P3-3.
> Plan: docs/history/plans/2026-07-06-fgx-phase3-clean-break.md

## (a) Static worst-case frame sums (tools/stack_measure.py)

fcc emits `<fn>_FRAMESIZE EQU <bytes>` per function; the script walks the
JSR/FGX2_FARCALL call graph from `main` and sums frames along the deepest
path.  Recursion cycles are cut (sum = floor); indirect (fn-ptr) call sites
are counted but their edges are unknowable statically.

| binary | worst path sum | biggest frames | caveats |
|---|---|---|---|
| ed     |  76 B | compile=24 append=20 move=18 | commands recursion; 1 indirect |
| sed    |  72 B | compile=38 fcomp=26 advance=20 | — |
| jsh    | 162 B | _jsh_expand_at=50 _jsh_tab_complete=38 | run_seq recursion |
| od     |  84 B | main=34 icvt=34 d_put=28 | 2 indirect |
| grep   |  48 B | re_comp=28 main=20 | — |
| tr     |  24 B | main=18 | — |
| tctest |  22 B | tgoto=14 | 1 indirect |
| more   |  14 B | initterm=10 | 1 indirect |
| man    |  16 B | page_exists=8 | — |

**elvis (28 TUs, static, compile-only — runtime stays off the table):**
direct-graph worst path = **2,144 B** (main→cmd_tag→tmpstart→garbage(2050));
`add()=4,128 B` is reachable only via the vikeys fn-ptr dispatch (11 indirect
sites), so the realistic worst ≈ **5 KB** — the 5–6 KB design estimate stands,
now with a computed floor.  Heap-boxing candidates are exactly the >1 KB
frames: add=4128, garbage=2050, undo=2048, cmd_make=2048, cmd_at=1002.

## (b) Runtime `_fcc_ssp` high-water (fgxdebug `watch_min`)

New plugin feature: `watch_min` write-taps aggregate min/max/first of 16-bit
values written to a cell (no per-hit log).  Cells = every task DP's
`_fcc_ssp` (`FGX_DP_KTASKS $B000 + pid<<8`, offset $BC).  Filters: kernel/
bank-0 writers ignored (TCB page zeroing), v==0 ignored (crt0 pre-seed).
Manifests: tests/p31_ed.json / p31_sed.json / p31_tctest.json.

| workload | task | seed→min | **used** | static bound |
|---|---|---|---|---|
| ed_subst suite (100-line g//) | ed (pid4, 3396 pushes) | $8019→$7FD9 | **64 B** | 76 B |
| all three runs | jsh (pid2, ~650–1040 pushes) | $795B→$78F9/$7905 | **86–98 B** | 162 B |
| boot-time tool (pid0) | dhclient/netstart | $0048→$0001 | 71 B | — |

Caveat: short-lived pid slots are REUSED across sequential commands, so a
slot's seed/min can conflate different programs' malloc'd regions (pid3
showed max>seed — impossible for a monotone stack pointer).  The long-lived
rows above are clean; sed's own usage is bounded by its 72 B static sum.

## (c) Soft-stack size tax (pre-b31e84f fcc, `--hard-stack` vs default)

fcc @ e0411f0 (last commit carrying both frame models), same source, host
worktree, instruction-count of emitted .s:

| TU | hard | soft | tax |
|---|---|---|---|
| ed.c   |  9,322 | 10,669 | **+14.4%** |
| sed.c  | 14,043 | 15,567 | **+10.9%** |
| grep.c |  4,395 |  4,727 | **+7.6%** |

## Conclusion (feeds P3-3)

- Shipped userland's soft-stack use is **two orders of magnitude** below the
  region size: ≤100 B measured, ≤162 B static.  A bank-0 hardware-stack carve
  (TASK_STACK_MAX_PAGES 16→32 = 8 KB/task) absorbs it trivially.
- elvis-class needs ~5 KB + heap-boxing for its five >1 KB frames — the
  hybrid (locals on HW stack + compiler-owned boxing for big aggregates) is
  confirmed as the right T4 shape.
- Deleting the soft stack pays back **8–14% code size** on locals-heavy TUs
  (plus the DP $BC-$BE registers and the per-task malloc'd region).
