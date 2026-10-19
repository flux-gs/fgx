# Follow-up: kernel → C (fcc) conversion triage

> Part of the 2026-07-05 FGX/fcc architecture audit. Question: which parts of
> the hand-asm kernel could convert to fcc-compiled C, and what blocks it?

## Inventory

Total asm: **41,564 lines** (`src/kernel/*.s src/drivers/**/*.s src/modules/**/*.s`).
~32,800 lines live in the bank-`$02` kernel image; ~8,760 lines are modules that
each occupy their **own 64KB bank** (prodos, net, net_xport, serial, bpf) —
module conversion does NOT consume bank-`$02` headroom.

## Per-file triage (largest files)

Classes: **A** = algorithmic (C-convertible), **B** = dispatch/ABI-coupled
(possible with thunks), **C** = hardware/IRQ/DP-tricks (stays asm).

| File | Lines | Bank | Verdict | Split A/B/C | Reason |
|---|--:|---|---|---|---|
| `src/kernel/syscall.s` | 4475 | $02 | B | ~55/35/10 | trampoline + frame surgery + signature-byte read stays asm (syscall.s:46-68); syscall bodies are logic over `[dp],Y` cross-bank copies — convertible behind an asm entry shim |
| `src/modules/prodos/prodos.s` | 3745 | own | **A** | ~90/10/0 | pure FST logic, zero MMIO/IRQ, already vtable-dispatched (FOP table), bank-isolated — the single best C target; its bank absorbs fcc bloat |
| `src/drivers/fs/fs.s` | 3209 | $02 | A/B | ~75/25/0 | dir-walk/FCB logic; welded to bank-$02 statics (`_fs*Buf`) reached by prodos.mod via KAD exports; hot, in-bank size cost |
| `src/kernel/main.s` | 1739 | $02 | C | ~15/15/70 | boot/init ordering, SHR bring-up — stays asm |
| `src/modules/net/net_xport.s` | 1292 | own | A/C | ~55/10/35 | UDP/TCP/ICMP state machines = C; W5100 ring MMIO + U2_LOCK stays asm primitives |
| `src/modules/serial/serial.s` | 1289 | own | C | ~10/10/80 | SCC two-step register access in PHP/SEI, IRQ rings |
| `src/kernel/loader.s` | 1283 | $02 | A/B | ~65/30/5 | header validation, segment loop, bss zero = logic; bank patching = thunk |
| `src/modules/net/net.s` | 1235 | own | A/B | ~65/30/5 | socket ops behind VT_NET vtable — same seam as prodos.mod |
| `src/kernel/process.s` | 1210 | $02 | B | ~45/45/10 | wait/zombie/argv = C; child resume-frame construction + `_Sys_UserSP` swap = asm |
| `src/drivers/console/console_vthandler.s` | 1099 | $02 | **A** | ~90/10/0 | pure VT/CSI parse; zero MMIO/IRQ/DP-indirect; easiest big in-bank file semantically |
| `src/kernel/task.s` | 1051 | $02 | A/B | ~70/30/0 | TCB table logic; DP/stack-page coupling = thunk |
| `src/kernel/uthernet.s` | 1025 | $02 | C | ~20/10/70 | W5100 probe/bring-up + ISR arm; 17 MMIO refs |
| `src/kernel/sim.s` | 996 | $02 | C | 0/0/100 | IRQ entry at $E10010, XCE-carry BRK-detect ordering invariant — hard no |
| `src/drivers/ramdisk/ramdisk.s` | 982 | $02 | B | ~50/40/10 | Toolbox NewHandle glue |
| `src/kernel/modload.s` | 980 | $02 | A | ~75/20/5 | loader parallel + pure conf-text parser |
| `src/kernel/signal.s` | 869 | $02 | A/B | ~70/30/0 | pending-bit/handler-table logic; delivery hook = seam |
| `src/drivers/block/block.s` | 851 | $02 | C | ~15/25/60 | SmartPort firmware trampoline via bank-$00, D=0 contract |
| `src/drivers/fs/bitmap.s` | 787 | $02 | **A** | ~95/5/0 | pure ProDOS bitmap math over heap buffer via `[_bm_ptr]` — ideal small spike |
| `src/kernel/pipe.s` | 745 | $02 | A/B | ~70/30/0 | byte-ring logic = C; `_sleep`-crossing scratch = seam |

Also pure-A small: `src/drivers/fs/path.s` (512), `src/drivers/fs/fcb.s` (622).
`jumptable.s`, `console_init.s`, `console_render*.s` = B/C, stay asm.

## Headroom math

- Current kernel: **45,237 B** (`bin/fgx.bin` and `build/KERNEL`, Jul 5). Cap:
  **55,040 B** (`lib/build_common.sh:158-164`, `$02E700 − $021000`). Free:
  **9,803 B (17.8%)**.
- Converting E bytes of emitted hand-asm at fcc expansion k costs net (k−1)·E:
  k=2 → E ≤ 9.8 KB; k=3 → E ≤ 4.9 KB. That is 11–22% of the ~44 KB of kernel
  code and consumes ALL remaining feature headroom.
- **Conclusion: wholesale in-bank kernel-C requires a multi-bank kernel — and
  FGX already has one in disguise: the FGXM module system.** Each module gets a
  private 64KB bank. Practical policy: in-bank C limited to one spike-scale TU
  (≤ ~1.5 KB emitted asm); everything bigger converts **by modularizing**
  (bank-$02 then *shrinks*).

## fcc kernel-target status + blockers (ranked)

fcc has no freestanding/kernel mode (flags: `-o --data-segment --far-calls
--version -I -D`, `toolchain/src/cc/main.c:263-301`), but it emits Merlin32 `.s`
that can be PUT straight into the kernel link — no linker gap. Single-segment
mode addresses globals DBR-relative, matching the kernel's DBR=$02 convention.

1. **DP collision (the hard one).** fcc requires a fixed DP register file at
   $BC–$FF (`_fcc_ssp`=$BC, `_fcc_img0-15`=$C0-$DE, `_fcc_ptr`=$E8, `_fcc_fp`=$F8,
   `_fcc_ptr2`=$FC; `toolchain/lib/fcc_runtime.s:63-90`). The kernel DP page is
   FULL edge-to-edge (`include/dpmap.s`). Kernel-C needs a dedicated kernel-C DP
   page + PHD/TCD…PLD at every asm→C boundary, or dpmap surgery.
2. **No kernel soft-stack story.** crt0_c.s seeds `_fcc_ssp` via SYS_MALLOC —
   the kernel can't syscall itself. Needs a boot-time Kmalloc'd kernel soft
   stack (per-task if C code crosses `_sleep`).
3. **ABI thunks.** Kernel ABI = A/X/Y args + C-flag success + A=errno + DP
   statics; fcc ABI = stack args + A return. Every caller of a converted routine
   needs a thunk (or fcc grows a carry-return attribute — toolchain-first).
4. **Reentrancy.** fcc's DP register file is non-reentrant: ISRs must never
   call C (or must swap DP). Fine for the cooperative kernel body; absolute bar
   for class-C files.
5. **Size** (above) — gates only in-bank conversion.
6. Small: no `volatile` (keep MMIO in asm primitives); ENT/EXT symbol emission
   conventions for cross-TU kernel linking need verification in the spike.

## Recommended order

1. **Spike: `bitmap.s` (or `path.s`) as an in-kernel C TU** — smallest pure-A
   file, crisp 4-entry API, state behind a DP long-pointer, host-referenceable.
   Real deliverable = the **kernel-C runtime seam** (DP page, boot-seeded
   `_fcc_ssp`, PHD/TCD entry macro, carry/errno thunk pattern).
2. **prodos.mod FST ops in C** — the strategic target: ~3,700 lines of pure FS
   logic, own bank (bloat-immune), vtable-dispatched, aligns with the roadmapped
   C-module framework. Convert op-by-op with per-FOP fallback.
3. **net.s + net_xport.s protocol state machines** (module banks; W5100 ring
   primitives stay asm).
4. **console_vthandler.s** — biggest pure-A in-bank file (~1,878 B emitted →
   ~4-5 KB as C); only as/after modularization frees bank-$02 room.
5. loader/modload/signal/pipe/task bodies — after further modularization.

Never: sim.s, block.s, serial.s hw core, uthernet.s bring-up, main.s boot,
syscall.s dispatcher head.
