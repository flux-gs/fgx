# Preemption campaign — sub-roadmap (chartered 2026-07-17, planned at train-3 close)

**STATUS: CAMPAIGN OPEN (the maintainer, 2026-07-17, post-v1.9.0).  Model A RATIFIED**
(the maintainer proceeded on this plan as written; the P0 latency survey feeds only
the P3 slot decision, not the model).  Branch `feat/preemption`
(tag `pre-preemption` on main).  P0 survey instrumentation: LATPROBE
(dispatcher entry/exit taps + `_kSwtchCount` sleep-exclusion; worst
CPU-bound syscall in ticks + its number, kbank-dump readable).

**PROGRESS (2026-07-18):** P0 (LATPROBE survey) ✓, P1 (timer-quantum resched
at the syscall boundary) ✓, **P2 → P2' (compiler loop-safepoints) ✓** — the
RTI-redirect P2 was proven dead (HBPROBE: firmware switches stacks) and replaced
by fcc-emitted `_fcc_safepoint` at loop tops (toolchain `feat/loop-safepoints`,
held local).  P2' acceptance GREEN: `spin_yield` (bg spinner never freezes the
fg) + `spin_sigint` (Ctrl-C kills a hung C loop).  **The P2' FS write/read
interleave race is ROOT-CAUSED + FIXED (2026-07-18, commit 99a60c17) — it was
the F2 block cache, fixed with invalidate-on-write; full FS+P2' gate 19/19.**
Core preemption (preempt user code via safepoints + timer quantum) is DONE and
proven; all held LOCAL on `feat/preemption` pending a release train.
**REMAINING:** P4 (blocking-I/O → real concurrency + TCP-server demo — a large,
independent train) and retiring the `_kYieldReq` kbd special-case into the
general mechanism, then the release.

**Goal:** real preemptive multitasking — a busy task loses the CPU on a timer
quantum without cooperating, the fg shell/editor stays live under any bg load,
and the F5 kbd-yield hack (`_kYieldReq`) is retired as a special case of the
general mechanism.

## What the BSD-foundations campaign already delivered (the foundation)

- Per-task fd tables, job control, signals, WCHAN sleep/wakeup, priorities,
  round-robin `swtch` (sched.s) — the scheduler core is real.
- Per-task **kernel stacks** (`FGX_STK_KTASKS + pid<<8`) and per-task **user
  DP pages** (`FGX_DP_KTASKS`) — the dispatcher already runs each task's
  syscalls on its own kernel stack.
- FS state safe across ANY syscall-boundary interleaving: F0.5
  save/load completeness (probe-guarded), F1 shared in-core inode, F2
  coherent block cache, F4 durability + error latch, F5 boundary yield
  proven byte-clean under a yield storm (`coop_yield.json`).

## ★ THE campaign design decision (decide FIRST, it shapes every train)

**Model A — 2.11BSD-faithful: preempt USER code only.** The timer IRQ marks
`need_resched`; if the interrupt landed in USER code, the IRQ path saves the
user context into the TCB and switches immediately; if it landed in KERNEL
code (syscall in flight), the switch is deferred to the dispatcher exit (the
F5 hook site, generalized). Kernel code runs to completion — exactly classic
uniprocessor Unix (2.11BSD does not preempt in-kernel either).

**Model B — kernel-preemptible.** Preempt anywhere, including mid-syscall.

**Recommendation: Model A, decisively.** Model B requires per-task kernel DP
pages (TODAY THERE IS ONE SHARED KERNEL DP — every `_shTmp`/`_fsTmp`/
`_kHeapCur`/`_libcTmp` cell is a cross-task singleton the instant a syscall
can be interrupted), plus critical sections around Kmalloc/Kfree, the block
cache, the bitmap, the module dispatch bridge, and the bank-0 SmartPort
trampolines. That is a second, larger F3. Model A sidesteps ALL of it:
syscall atomicity is preserved by construction, so every existing kernel
singleton (including the FS working singleton) remains correct. Model A also
automatically forbids switching mid-SmartPort/firmware — those only run
inside syscalls.

**Consequence for F3 (recorded honestly):** under Model A, the F3 singleton
retirement is NOT a preemption prerequisite either. F3's motivations have
been peeled off one per increment as grounding improved: corruption (fixed
by F0.5), visibility (F1), the shared data home (F2), and now
preemption-prerequisite (Model A). What survives: LATENCY, ~1.6 KB statics,
BSD structure. And precisely on latency: **F3 alone does not bound it** —
a large write is one long syscall wherever the state lives; F3 is the
ENABLER for safe mid-op yield points at block boundaries inside FS loops
(no singleton ⇒ a block-boundary yield is safe). P3's deliverable is
therefore "F3 + explicit block-boundary yield points," or the latency
number won't move. F3 is chartered here as **train P3**, gated on P0's
survey — resist any "while we're in there" scope-pull into P1/P2.
**Supersedes** the train-3-close slot of F3 as this campaign's OPENER:
that slot predated the shared-kernel-DP grounding and the Model-A
ratification (Fable-reviewed 2026-07-17); subject to the maintainer's ratification
at P0.

## Trains

- **P0 — model ratification + latency survey ✓ DONE 2026-07-17.**
  Model A RATIFIED.  Survey (LATPROBE, heavy workload: fg 1.4 MB tar +
  sync all-task walk + big ls): **worst CPU-bound syscall = 38 ticks
  (~633 ms) = SYS_POSIX_SPAWN (#43)** — the loader's synchronous binary
  read, NOT an FS-write syscall.  Verdict for the P3 gate: **F3's latency
  case is unsupported by data** — FS syscalls stayed under spawn, and
  spawn's remedy would be loader-level yield points, not F3.  P3 stands as
  structure/hygiene only, no urgency; spawn latency noted as its own
  optional item (a visible-but-classic launch hiccup under a quantum).
  **Quantum chartered: 4 VBL ticks (~66 ms), round-robin within priority**
  — well clear of typical syscalls, ~10 quanta inside a worst-case spawn.
- **P1 — timer-quantum resched at the boundary ✓ DONE 2026-07-17.**
  Heartbeat decrements `_kQuantum` (baked-init QUANTUM_TICKS=4 ≈ 66 ms);
  expiry sets THE resched flag — `_kYieldReq` was not deleted but
  UNIFIED: kbd input and quantum expiry raise the same flag, honored once
  at the F5 dispatcher hook (the plan's one-mechanism intent, minus a
  cosmetic rename).  Acceptance `quantum_yield.json`: bg tar + fg
  `sleep 2; echo QTICK` with ZERO keypresses — QTICK at ~2 s (timer wake
  fires at the forced switch) vs starving until tar ends under kbd-only.
  Gate: full 16-fixture suite 16/0 — the first whole-suite proof that
  train-3 interleave-safety holds under CONTINUOUS quantum switching.
  Syscall-bound tasks now share fairly; a pure userland spin loop still
  starves others until P2.
- **P2′ — compiler-safepoint preemption ✓ DONE 2026-07-18 (the maintainer ratified
  "1 then 2").  SUPERSEDES the chartered P2 "user-context IRQ preemption".**
  Kernel: `KFGX_YIELD_MIRROR` (bank-0 $030A, user-readable) tracks
  `_kYieldReq` — heartbeat sets it (quantum/kbd), dispatcher + `_Sys_Yield`
  clear it.  Toolchain (branch `feat/loop-safepoints`, commit `65efd7f6`):
  fcc emits `JSR _fcc_safepoint` at every loop top; the routine LDALs the
  mirror and SYS_YIELDs if set.  Overhead +0% code size (measured, 463
  fixtures), common path LDAL+BEQ (no reg save — A/flags dead at loop top).
  **Acceptance (both green):** `spin_yield.json` — a pure `for(;;);` bg
  spinner no longer freezes the fg (SPINALIVE prints ~2 s in); AND
  `spin_sigint.json` — **Ctrl-C kills a hung FOREGROUND spinner** (the
  safepoint's SYS_YIELD is a real syscall boundary, so the pending SIGINT
  is delivered — a runaway C loop is killable, not a reboot).  Ships via
  the toolchain release flow (below).
  - **★ BLOCKER found at P2' gate (2026-07-18) — a latent FS write-state race
    that finer preemption makes deterministic. NEEDS A DECISION.**  Full
    18-fixture gate = 17/1: `synctest` regresses (green through P1).
    Root-caused: jsh-with-safepoints yields far more often, so a background FS
    writer (`synctest`, mid-tree-write, owning the shared `_fsFileState`
    singleton with dirty state) is reliably scheduled at the instant fg jsh
    spawns `sleep`.  `posix_spawn(/bin/sleep)` returns **EINVAL** — the loader's
    `Fs_Open`+`Fs_ReadN` of the binary, while another FCB is mid-write, reads
    corrupted bytes (jsh prints "sleep: not found").  PROOF it's the fg yield:
    rebuilding **jsh with `-fno-safepoints` makes synctest pass 2/2**.  This is
    the `_fsFileState` write-state concurrency class — F3's exact domain —
    resurfacing in the open/spawn-while-a-writer-is-dirty path; almost
    certainly PRE-EXISTING (P1 could hit it, just rarely), made deterministic
    by P2'.
  - **Scope decision for the maintainer:** (a) NARROWLY fix the FS
    open/read-while-dirty-writer path (likely `_Fs_FlushPreviousOwner` or the
    loader read not fully committing the prior writer before switching) — my
    lean; (b) pull **F3** forward as the real fix (this partially vindicates
    the original "preemption wants F3" intuition the train-3 close set aside);
    (c) ship P2' with a documented known-limitation, fix the FS bug next.  P2'
    is CODE-COMPLETE, its own acceptance green, held local pending this call.
    Old design detail retained:
  **Why the charter changed — HBPROBE evidence:** a kprobe tap inside the
  heartbeat body (branch feat/preemption, since reverted) dumped the
  interrupt-time bank-0 stack while userland `spin` busy-looped.  Finding:
  by the time a QUEUED heartbeat task runs, ROM has already switched to the
  bank-0 dispatch stack — the return chain is `$FE:B015` (ROM) → kernel,
  and the user's interrupted PC/PB is NOT reachable (it lives in ROM-
  internal state on spin's own stack).  The RTI-redirect trampoline is dead
  as drawn.  The IIgs doc corpus has NO documented save-area contract for
  that path (Fable confirmed: empty searches = ROM-internal, not API).
  - **Prior art (Fable):** GNO/ME does preempt on this ROM — but by owning
    the RAWER bank-$E1 IRQ vectors with a ROM-busy gate, switching only
    where the interrupted context is well-defined.  That is Model A + a
    busy check, and a CAMPAIGN of its own (FGX takes over an IRQ path it
    currently delegates, + two-resume-kind `swtch`, + firmware-window
    discipline).  **Kept in the showstopper register as A′, the documented
    fallback — no customer today.**
  - **P2′ mechanism:** fcc emits a safepoint at every loop BACK-EDGE
    (`emit_bra_label(lab_top)` in parse_stmt.c, all three loop forms):
    `LDAL yield_mirror / BEQ +n / JSL yield`.  A pure C loop yields within
    one iteration; NO firmware RE, NO stack surgery, on the task's own
    stack.  Fits the standing policy (all userland is first-party fcc C —
    there is no hand-asm userland loop to miss) and the house rule (fix it
    in the toolchain).
  - **THE payoff Fable surfaced (better than the chartered mechanism):**
    the safepoint IS a syscall boundary, so quantum fairness, SIGNAL
    DELIVERY, and kill-ability all compose free with the green P1 machinery.
    The real customer isn't an adversarial spinner (none exist here) — it's
    **your own buggy C program hung in a loop: today a reboot, under P2′ a
    Ctrl-C.**  Option A′ alone cannot deliver a signal to a spinner (it
    never crosses the dispatcher exit).
  - **Kernel-side piece (design first):** user code can't poll a kernel-bank
    global whose bank relocates ($02→$7D).  Mirror `_kYieldReq` to ONE
    fixed user-readable byte (bank-0/$E1 scratch, or an address crt0 gets at
    spawn); codegen reads THAT.  `_kYieldReq` is not retired under P2′ — it
    becomes THE mechanism, mirrored user-side (acceptance language updated).
  - **Binds before code (Fable):** measure back-edge overhead (~8–10 cyc)
    on the golden/perf sweep before any elision rules; audit residual asm
    linked into user binaries (libc.s / fcc_runtime.s) for UNBOUNDED loops
    (bounded div/MVN loops are fine within a quantum — likely empty, check);
    doc the honest holes (pre-safepoint binaries behave as today; a future
    non-fcc userland path re-opens it — the `ponytail:` ceiling).
  - **Slot/vehicle:** P2′ inside this campaign, executed via the standing
    toolchain release flow (fcc codegen + regression fixture + toolchain
    release + FGX re-pin + the one-byte kernel mirror + the `spin` fixture
    rebuilt with new fcc as the acceptance).  `src/userland/spin/spin.c`
    (the pure busy loop) already landed as that vehicle.
- **F3 — singleton retirement — PULLED FORWARD (the maintainer, 2026-07-18) to fix the
  P2' spawn-while-writing race. NOW ACTIVE (was P3/deferred).** Tag
  `pre-f3-singleton`. Fable-reviewed reordered slice plan (the raw ~608 sites
  overstate the danger; F1/F2 shrank the singleton's SEMANTIC surface to three
  roles — per-fd Pos, block-map/validity walk state, and 512B buffers that are
  now REDUNDANT copies of coherent F2 cache blocks):
  - **F3.0 — mechanism confirmation ✓ DONE 2026-07-18.** Disk-state
    discriminator (`cadius` extract + `cmp` /bin/sleep after a failing run):
    **byte-identical on disk → cases 1-2 (READ-ONLY misread; NO on-disk
    corruption, NO stopgap flush-guard needed).** kprobe on `_ldHeader` showed
    the loader read holds dir-fragment bytes = `Fs_ReadN` resolved the WRONG
    block (stale-valid skip or wrong block# — the singleton's block-map
    confused by the interleaved mid-write owner). F0.5 proved A→B→A between two
    ESTABLISHED writers; this is the untested edge — dirty-writer → FRESH read
    fd (spawn's newly-opened FCB inheriting stale tree-level globals). Red bar:
    `spawn_under_write.json`.
  - **★ F3.1 ROOT-CAUSED + FIXED 2026-07-18 — it was the F2 BLOCK CACHE, NOT
    the `_fsFileState` singleton.** The whole "singleton block-map confused by
    the interleaved writer → per-FCB migration" hypothesis (below) was WRONG.
    Bisection nailed it to `src/drivers/block/blkcache.s`:
    - The reproducer is DETERMINISTIC (baseline red 3/3, not a flaky race).
    - **Experiment 1** — force `_BlkCache_Fetch` to always-miss (every Blk_Read
      hits disk; disk is byte-clean per F3.0): `spawn_under_write` GREEN. ⇒ the
      corruption is the cache serving WRONG content on a HIT, for a CORRECTLY
      keyed (dev,blk) — not a wrong block# and not the singleton.
    - **Experiment 2** — switch the Blk_WRITE path from write-through *refresh*
      to *invalidate* (read-miss populate kept): GREEN. ⇒ the poison is created
      by the **write-through refresh hook**; the read-miss populate was never at
      fault (it copies just-read-from-disk bytes ≡ disk, can't diverge).
    Static analysis shows the write path SHOULD cache disk-identical bytes
    (`_SP_WriteBlock` preserves `_blkNum`/`_blkBuf`; Store copies the same source
    that went to disk) — so write-through refresh is subtly fragile under the
    P2' FS write/read interleave in a way that isn't statically auditable. Rather
    than add another subtle patch, the fix REPLACES the fragile invariant:
    - **THE FIX (`_BlkCache_WrInval`, blkcache.s):** Blk_Write success now DROPS
      the (dev,blk) entry instead of refreshing it. New invariant — *a VALID
      cache entry ≡ the bytes last READ from disk for (dev,blk); writes
      invalidate.* A valid entry can therefore NEVER diverge from disk under ANY
      interleave (correct-by-construction). Read caching — the primary F2 win
      (hot dir/index blocks across path walks + multi-segment loads) — is fully
      preserved; only a read of a just-written block costs one extra disk read.
    - Acceptance: `spawn_under_write` GREEN 3/3 (was red 3/3); `synctest` (same
      root cause) recovers too; full FS + P2' gate re-run. **P2' is UNBLOCKED by
      this ~15-line cache fix — the ~230-site per-FCB singleton migration is NOT
      needed for correctness here.**
  - **F3 singleton retirement — now DECOUPLED from P2' (optional cleanup, was
    "the unblock").** The P2' spawn-while-writing blocker is resolved above with
    the F2 fix, so the ~600-site singleton retirement is no longer on the P2'
    critical path. It remains a desirable architectural cleanup (removes the
    shared-buffer flush layer, enables held-pool-pointer reads) and can be
    scheduled on its own merits later; it is NOT a preemption prerequisite.
    Original (pre-2026-07-18, now superseded) slice plan kept for reference:
  - **F3.1(old) — `_fw*` block numbers + CurIdx/CurMaster + dirty flags →
    per-FCB** (~230 sites). SUPERSEDED as the P2' unblock by the F2 cache fix.
  - **F3.2 — Eof/Pos + key/storage/dev** (low risk; Eof/Size inode-backed
    since F1 → retires `_Fs_InodeSyncSize`).
  - **F3.3 — the 179 module buffer sites → HELD POOL POINTERS into the F2
    cache** (not per-FCB 512B copies — `FCB_DataBuf` becomes a pool-entry ref,
    deleting a whole copy layer). B_BUSY / pool-min / never-sleep-holding
    invariants from the train-3 parking; then DELETE `_Fs_SwitchToFCB` /
    `_fsFileState` / `_fsCurOwnerFcb` / `_fsDataBuf`. **The beast** (X-indexed
    absolutes → `[ptr],Y` Y-liveness rework in module code); MULTIBANK_VERIFIED.
- **P4 — blocking-I/O completion.** Sleep instead of poll everywhere a task
  can wait (net `recv`/`accept`, serial, pipe backpressure) so preemption +
  sleep compose into real concurrency; the TCP-server payoff demo lands here.
  **P4 is independent of P2 and lower-risk — float it earlier if P2 stalls:**
  P1+P4 already delivers the TCP server and fair syscall-bound sharing; only
  the pure userland spin-loop case waits on P2.

## Showstopper register

1. **Single shared kernel DP** — Model B blocker (per-task kernel DP pages
   would burn 2 KB of bank-0 in the TN#27 claim + a TCD per dispatch);
   Model A neutralizes it. THE reason Model A is recommended.
2. **IRQ-frame context switch (P2)** — the genuinely novel 65816 mechanism,
   and it touches `swtch` ITSELF, not just a new save path: today every
   task resumes via a kernel-stack RTS (swtch-frame); P2 adds tasks whose
   saved context is an IRQ-frame snapshot resumed via synthesized RTI, and
   BOTH kinds coexist in the run queue — so the TCB needs a resume-kind
   discriminant and `swtch` a second resume path through the most
   load-bearing scheduler code. Prototype behind a build flag with a
   dedicated spin-loop fixture before wiring the timer to it.
   Perf note while in there: `swtch` blanket-wakes WCHAN_KBD/WCHAN_SOCK
   sleepers on every switch (sched.s ~149–170) — at a 66 ms quantum that's
   ~15 spurious wake-poll-sleep cycles/sec/sleeper (harmless), but nobody
   tightens the quantum without re-checking that cost.
3. **Firmware/toolbox windows** — never switch while the heartbeat/SmartPort
   trampoline owns bank-0 state; Model A covers SmartPort (syscall-only);
   the heartbeat itself runs at IRQ level and must stay switch-free.
4. **Module non-reentrancy** — prodos.mod/net.mod state is per-operation;
   Model A's syscall atomicity is what keeps them safe. Any future Model-B
   ambition re-opens this wholesale.
5. **`_Sys_Saved*` dispatcher singletons** — already handled at the F5 site
   analysis (yield only where args are consumed and results unstored); P1
   inherits that placement; P2's user-context switch never touches them.

## Acceptance (campaign)

`while(1);` in the background + fg `vi` editing smoothly; bg `tar` +
interactive shell with no `_kYieldReq` special case in the tree; byte-clean
FS under the full preemptive interleave (existing 14-fixture gate + the new
spin fixture); latency numbers from P0 published in the release notes.
