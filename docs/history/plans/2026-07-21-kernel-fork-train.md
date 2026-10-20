# Kernel fork train — vfork + snapshot fork + pipe ring growth

**Date:** 2026-07-21
**Status:** EXECUTION PLAN (design ratified by the maintainer 2026-07-21)
**Branch:** `feat/kernel-fork` (off local main; never pushed; lands to LOCAL main, hold-release)
**Purpose:** give FGX real BSD `fork(2)`/`vfork(2)` semantics so the tcsh 6.00 port
(follow-on plan) lands with `sh.proc.c` and all five fork sites **intact** — no
de-fork surgery. This is the platform-first rule applied to the kernel: fix the
platform, don't rework every port around its gap.

**Thesis:** FGX already has the hard parts of fork — preemptive scheduler, TCBs,
per-task user stacks/DP, FCB-refcount fd tables (`Task_AllocFdTable` + the spawn
fd-copy block, `process.s:141-188`), pgrps/job control, waitpid/zombies, signals,
execve v1 (`_Sys_Execve` + `Load_Binary`, `syscall.s:2412`), and the Bank_Alloc
user-bank pool (`bank.s:62`). What's missing is only the memory-image story, and
without an MMU that decomposes into two cheap tiers:

- **Tier 1 — vfork (zero copy):** child borrows the parent's entire image + stack;
  parent is suspended until the child execve()s or _exit()s. This is the hot path:
  csh/tcsh call `vfork()` for every plain external command (`sh.sem.c:143`) and
  were written to its rules.
- **Tier 2 — snapshot fork:** parent's *mutable* banks (data + heap grants +
  stack/DP pages) are MVN-copied to spare banks; the child runs **in place**; the
  parent is restored from the snapshot when the child execve()s or exits
  ("deferred-parent" fork). Code banks are shared read-only — fcc code is pure and
  all mutable data lives in the data seg (the DBR rule) — so nothing is relocated
  and no pointer in memory ever goes stale.

**Ruled out (the maintainer 2026-07-21):** tier 3 ping-pong swapping for a backgrounded
child that *never* execs (pure-builtin infinite loop in a subshell). Pathological;
documented as a known limitation instead of built.

**Ruled in (the maintainer 2026-07-21):** the backquote pipe-fill deadlock (suspended
parent is the sole reader while the pre-exec child writes > ring size) is solved
by **growing the pipe ring on demand** — it is already a per-pipe
`Kmalloc(PIPE_BUFSZ)` block, not static storage.

---

## 0. Standing constraints (FGX discipline)

- Feature branch → local main; **hold-release** until the maintainer green-lights a train.
- **Toolchain ordering:** the `fork()`/`vfork()` libc wrappers live in the
  toolchain repo → toolchain releases FIRST, FGX re-pins. Stage V0 lands them
  early (ENOSYS until the kernel catches up) so probes compile through real libc.
- **65816 kernel asm stays inline** — no subagents for Merlin32/65816 work.
- **Tiered test cadence:** per-change = a handful of representative probes;
  full parallel suite + `MULTIBANK_VERIFIED=1` only at stage gates.
- Probe binaries on the ProDOS image: **no underscores** in filenames.
- Headless MAME harness (`tools/mame_test/run.py` + tests JSON) is the green gate;
  run it yourself; closed-loop until complete or showstopper.

---

## 1. Locked design

### 1.1 Process states and TCB additions

Two new TCB fields (Stage 0 confirms free record space; the TCB already carries
TaskID/ParentID/CodeBank/DataBank/BankList[0..7]/LibcBank/FdTablePtr/DirectPage/
StackBase/SavedS/EntryPoint/Status — `process.s:96-429`):

- `TCB_ForkMode` (1 B): 0 = normal, 1 = vfork-child, 2 = snapfork-child.
  Read by execve/_exit to know whether a suspended parent needs waking/restoring.
- `TCB_SnapPtr` (3 B): long ptr to this task's *parent-snapshot descriptor*
  (Kmalloc'd; holds the spare-bank list + saved stack/DP pages + parent pid).
  0 when none. Nested forks chain naturally: each frozen parent's own snapshot
  hangs off the *grand*-child's parent, LIFO by construction.

Two new (or reused) wait states in the scheduler: `PS_VFORKWAIT` and
`PS_SNAPFROZEN`. Both are "not runnable until child execs or dies"; SNAPFROZEN
additionally means "my mutable image is in the spare banks, restore before run."

### 1.2 vfork (SYS_VFORK, new vector slot — next free after 44 SPAWNX)

Child TCB creation **reuses the spawn blocks**: TCB alloc + `Task_AllocFdTable`
+ the FCB-refcount fd-copy (`process.s:141-188`), pgrp/signal inheritance — but
**shares** every memory field: copy CodeBank/DataBank/BankList/LibcBank/
DirectPage/StackBase verbatim from the parent; the child resumes at the
syscall-return point on the *parent's* stack with A=0; parent → `PS_VFORKWAIT`,
its eventual return value = child pid. No bank is touched.

Child obligations (the classic vfork contract — csh/tcsh already obey it): no
return from the calling frame, then `execve()` or `_exit()`.

### 1.3 execve upgrade (retires the `syscall.s:2432` TODO)

Current `_Sys_Execve` v1 replaces the caller in its own bank. Upgrade to
**execve-with-new-banks**, shared by both fork tiers:

1. `Load_Binary` into freshly `Bank_Alloc`'d banks (exactly what spawn does),
   building a fresh stack/DP/first-run resume frame for the calling task.
2. Rebind the caller's TCB memory fields to the new image; free its *old* bank
   claims — **except** when `TCB_ForkMode != 0`: the old image belongs to the
   suspended parent, so instead of freeing, hand it back:
   - vfork-child: wake parent (`PS_VFORKWAIT` → RUNNABLE); parent's banks were
     never touched.
   - snapfork-child: restore parent's mutable banks from the snapshot
     (§1.4 restore), free the spares, wake parent.
3. Same hand-back runs in `_Exit_Core` when a forked child dies before exec.

### 1.4 Snapshot fork (SYS_FORK, real implementation in stub slot 2)

At fork time:

1. **Mutable-bank census** (Stage 0 deliverable, §2): data bank + per-task heap
   grant banks + stack page(s) + DP page. Code banks and the shared libc bank
   are excluded — read-only by the DBR rule.
2. `Bank_Alloc` one spare per mutable bank (dry pool → return -1/EAGAIN, no
   partial state); MVN-copy each (7 cy/B ≈ 160 ms per full 64 KB bank at
   2.8 MHz; a shell is realistically 1-3 mutable banks — sub-second).
   Stack/DP pages are copied into the snapshot descriptor block.
3. Build the snapshot descriptor; child runs **in place** in the parent's banks
   (A=0 return); parent → `PS_SNAPFROZEN`, holding the descriptor.
4. Restore path (from execve or exit, §1.3): MVN spares back over the live
   banks, restore stack/DP pages and parent's saved regs/SavedS, free spares,
   Kfree descriptor, parent RUNNABLE with A = child pid.

Known, documented semantic: the parent does not run concurrently with a
pre-exec child (it is either in `wait()` anyway — foreground — or resumes the
moment the child execs — background). The never-exec'ing backgrounded builtin
loop is the accepted pathological gap.

### 1.5 Pipe ring growth (removes the suspended-reader deadlock)

`PIPE_BUFSZ` (512, `include/kernel.s:383`) becomes the *initial* size:

- New 2 B field `PIPE_BufSz` at record offset 12 (bytes 12-15 of the 16-byte
  record are free today); all `PIPE_BUFSZ` compares/wraps in `pipe.s`
  (`@pw_space:420`, wrap checks at 499/547 etc.) switch to the field.
- `_Pipe_Write` full-ring path: if `PIPE_BufSz < PIPE_MAX_BUFSZ` (4096),
  Kmalloc a ring of 2x, copy resident bytes *unwrapped* (Head..) to offset 0,
  Kfree old ring, Head=0/Tail=Count, continue the write; only block when
  already at max. Growth is unconditional-on-full (no fork-awareness in
  pipe.s — simpler and it helps every heavy pipeline, not just backquotes).

Sizing note: 4 KB max × NPIPE live pipes is Kmalloc'd on demand, not resident.

---

## 2. Stage sequence

Order: **audit → wrappers → vfork → execve → snapfork → pipe → close-out.**
Each stage is RUNTIME-green (representative probes) before the next; full suite
at the V/F/P gates. Commits per checkbox cluster on `feat/kernel-fork`.

### Stage 0 — Audit + spec pin (no behavior change) — **DONE 2026-07-22**

Findings (commit `4eba40df` on `feat/kernel-fork`; supersede §1.1-1.2 details
above where they differ):

- [x] **Census finding — user malloc is NOT snapshotable:** userland
  `malloc()` is `SYS_MALLOC` (#96) into **shared kernel arena banks** (kind
  2/4 block-table rows) — co-resident with other tasks' allocations, so fork
  cannot blanket-copy those banks. **Resolution: new Stage S** — `SYS_BRK`
  (#17, BSD number) + libc `brk()/sbrk()` over a per-task PRIVATE bank
  (`SE_SbrkBank`, granted on first call, freed at exit, snapshot-copied by
  fork). The BSD shells (sh `stak.c`, csh/tcsh `alloc11.c`) are sbrk-based,
  so this is a direct-port runtime gap to fill regardless of fork.
  **Documented limit:** SYS_MALLOC heap is fork-SHARED (vfork-like); FGX-
  native spawn-world tools are unaffected, BSD ports never see it.
  Mutable-bank census = data seg bank(s) from `TCB_BankList` + `SE_SbrkBank`
  + user stack page (`TCB_StackBank/Base/Size`, bank 0) + DP page.
- [x] **No TCB space — and none needed:** TCB is hard-capped at 64 B (`ERR`
  guard) with every spare field EQU-overlaid. Instead: the scheduler-entry
  (SE) table had exactly 4 free pad bytes → `SE_SnapPtr` (3 B) +
  `SE_SbrkBank` (1 B); fork-mode is `SEF_VFORKCHILD`/`SEF_SNAPCHILD` flag
  bits. **No new task states either:** fork parents are ordinary
  `TASK_BLOCKED` on new channel `WCHAN_VFORK` ($FF06) with
  `TCB_WaitingOn` = child pid; the CHILD performs the snapshot-restore at
  execve/_exit and wakes the parent — swtch/scheduler untouched.
- [x] **Syscall numbers:** `SYS_BRK EQU 17` (BSD break(2)); `SYS_VFORK EQU
  46` — BSD's 66 is already squatted by `SYS_POLLKEY` (slot noted in the
  loader.s comment). Both vector slots reserved, still `_Sys_Stub`.
  `PIPE_BufSz EQU 12` (pipe-record bytes 12-13 were free) + `PIPE_MAX_BUFSZ
  EQU 4096` reserved; `docs/userland-abi.md` regenerated (build gates on it).
- [x] **Spec:** the "§3.3 spec" is a historical reference (no live spec doc
  carries it); process/fork documentation lands in `docs/scheduler.md` at
  Stage L, as-built.
- [x] **Harness note:** cherry-picked `fb52a504` (7 MHz ZipGS MAME cfg) from
  the fractal branch — at stock 2.8 MHz the jsh line editor drops autoboot
  paste characters and `jsh_exit_status` fails on PRISTINE v1.12.0; dedupes
  on merge when the fractal branch lands.
- [x] Gate: representative set green (jsh_exit_status, jsh_c_pipe, cat_pipe,
  grep_pipe @ 7 MHz); full suite at the Stage V gate; committed.

### Stage S — SYS_BRK + libc sbrk (new; before Stage F, after Stage V0)

- [ ] **S1:** `_Sys_Brk` handler: first call grants `SE_SbrkBank` via
  `Bank_Alloc`, break cursor rides a new SE-adjacent kernel var or the bank's
  base word; A = requested new break offset (0 = query), returns old break.
  ENOMEM past $FFFF (one-bank ceiling, fails closed — tcsh fit 64 KB
  data+stack on the PDP-11).
- [ ] **S2:** exit path frees `SE_SbrkBank` (route through the existing
  `Bank_Free` exit walk).
- [ ] **S3:** toolchain libc `brk()`/`sbrk()` wrappers over SYS_BRK (ride the
  Stage V0 toolchain release, or a follow-up if V0 already shipped).
- [ ] Probe: `SBRKT` — sbrk(4096) twice, contiguity + write/readback, sbrk(-)
  shrink, ENOMEM at 64 KB.
- [ ] Gate: representative set green; commit.

### Stage V0 — libc wrappers (toolchain repo)

- [ ] Add `fork()` / `vfork()` thin syscall wrappers to the toolchain libc pile
  + export table (plain BSD names per the libc=pure-BSD-names rule). Kernel
  slots return ENOSYS today — wrappers land inert.
- [ ] Toolchain regression fixture (link-resolves, ENOSYS at runtime), goldens
  green, **toolchain release, FGX re-pin** (release.sh is the single gate).

### Stage V — vfork + execve-with-new-banks

- [x] **V0** (toolchain `feat/fork-syscalls` @ `a0144511`, branched off the
  v1.17.0 pin): `fork()`/`brk()`/`sbrk()`/`_exit()` C wrappers + FRAMELESS
  hand-asm `vfork()` (stashes the caller's RTL address in libc data and
  rebuilds it on both exits — BSD's vfork.s trick; nested pre-exec vfork is
  UB as in BSD).  Toolchain release + FGX re-pin still pending (the maintainer gates
  the MR); the fork-train worktree tests against the branch commit locally.
- [x] **V1 + V3** (`5b8707ac`): SYS_VFORK live end-to-end, `VFEXIT` probe
  GREEN (child borrows image, shared-global write visible to parent,
  status 7 reaped, both stack-byte hazards handled — the kernel stashes
  the dispatcher's 4-byte exit frame on the parent's kernel stack across
  the sleep, mirroring the libc stub's RTL stash).  Implementation deltas
  vs the original sketch: no new task states (parent = TASK_BLOCKED on
  WCHAN_VFORK with a sleep-loop recheck on "child gone / zombie /
  SEF_VFORKCHILD cleared"); child first-run via `Task_PrimeKernStackAt` →
  `_Task_VforkFirstRun` replaying the dispatcher exit with A=0; the child
  OWNS NOTHING (zero BankList/handles) so all teardown paths no-op
  naturally; `_libcShRef` ++ balances the child's exit-time drop; spawn's
  fd-copy block extracted to `_Task_CopyParentFds` (shared).  The V3
  hand-back arm (clear flag → wake WCHAN_VFORK) landed inside `_Exit_Core`
  in the same commit.  execve FAILS CLOSED (ENOSYS) for vfork children
  until V2.
- [x] **Found by the probe** (logged to the project notes, queued as a TOOLCHAIN fix,
  not worked around): `waitpid(pid, &stack_local, 0)` loses the status
  (global ptr works) — the pile's `*status =` far store uses DBR instead
  of the pointer's bank 0.  jsh never saw it (`wstat` is a global);
  tcsh's `union wait` locals WILL.  Fix in fcc/libc before the tcsh port.
- [x] **V2** (`f9065ca7` + toolchain `fb6f3a6c`): execve-with-new-banks for
  vfork children, `VFEXEC` probe GREEN ON FIRST HARDWARE RUN (vfork +
  execv(/bin/basename) with STACK-resident argv; parent resumes at the
  exec; marker prints; status 0).  `_Sys_ExecveVfork` mirrors spawn's
  claim order and enters the new image via `_Task_FirstRun` (the staged
  frame is exactly FirstRun-shaped — no new resume machinery); failures
  restore every borrowed TCB field so a failed exec returns errno into
  the still-borrowed image, per the BSD contract.  libc side: execve/
  execv wrappers staging BSD `char**` vectors into the kernel's 16-bit
  offset ABI via a 768-byte bounce arena (out-of-bank strings copied,
  in-bank strings truncated; E2BIG past the caps — grow, or move to a
  far-argv kernel ABI, when a port needs it), `E2BIG` added to errno.h.
  Lesson banked: `make libc_c` regens BOTH `libc_c.s` and
  `libc_c_data.s` — commit them together (the first V2 commit missed
  the data file; merlin caught it as an unresolved pile symbol).
- [x] V1 gate: full suite (~260) green across three triage rounds — zero
  fork-train regressions; residuals were stale expectations (fixed),
  7 MHz-harness timing on main-without-fractal-console (rebase-resolves),
  and env-gated diags.  Harness hardening landed alongside: dstest/
  stattest/wstest build registrations, green-result cache + affected.py.
- [x] Stage V gate: full suite on V2 — zero new failures (the residual set
  is exactly the six triaged pre-existing/env items).  **That was the last
  unrequested full pass: the maintainer's 2026-07-22 ruling makes the ~14-test
  `--group failsafe` the development gate; the full suite runs only on his
  explicit request (see feedback_tiered_test_cadence).**

### Stages S + F + P — ALL COMPLETE 2026-07-22, every probe green on its
### first hardware run (post-fix), failsafe-gated per the new cadence

- [x] **Stage S** (`3ab2404e`): `_Sys_Brk` (#17) — per-task private sbrk
  bank; break cursor lives IN the bank at $0000 (no kernel table), heap
  at $0002, grown spans zero-filled (BSD semantics), one-bank ENOMEM
  ceiling.  Freed at exit + vfork-child exec.  `sbrktest` green.
  Probe gotchas banked: no "BRK" substring in markers; the provenance
  lint keys on the literal source-tree name in comments.
- [x] **Stage F** (`e6a5a723`): `_Sys_Fork` (#2) — snapshot fork sharing
  vfork's child-construction body (mode flag) + `_Fork_Snapshot`/
  `_Fork_Restore` (data bank + sbrk bank to spares via inline
  self-modified MVN; stack+DP bytes in a Kmalloc'd descriptor; LIFO
  nesting free).  `FKISO` (isolation across data/heap/stack tiers),
  `FKNEST`, `FKBG` (**CONCURRENT**: parent runs alongside the exec'd
  child) all green.  **65816 lesson: the kernel is RELOCATED — a JSL to
  an in-kernel label targets the assembly-time bank; the first probe run
  hung the machine until the MVN became inline fall-through with
  DBR-relative self-mod.**  DP-pointer discipline: descriptor truth in
  an absolute static, reloaded into `_kmallocResult` after every
  allocator call (the DP page is full; no new slots existed).
- [x] **Stage P** (`794ed940`): pipe ring growth — `PIPE_BufSz` field
  live, `_Pipe_TryGrow` doubles 512→4096 before the writer blocks,
  unwrap copy, growth unconditional-on-full (no fork-awareness in
  pipe.s).  `pipegrow` green both halves (no-reader 3KB round trip +
  the frozen-reader backquote shape).
- [x] Failsafe group grown to 14 (vfexit, vfexec, sbrktest, fkiso,
  pipegrow now guard the train), 14/14 green.

### Stage L — close-out (IN PROGRESS)

- [ ] Toolchain branch: golden REGEN (running) + runtime oracle + MR for
  The maintainer (never self-merge).  MR must note: pile regen reproducible at the
  tag (byte-identical); the waitpid stack-local status-store defect is a
  QUEUED fcc/libc fix the tcsh port needs.
- [ ] Docs: scheduler.md fork section + CHANGELOG narrative.
- [ ] Branch stays UNMERGED pending the maintainer (fractal branch ordering +
  hold-release policy); rebase after fractal lands resolves the three
  7 MHz-timing test failures.

### Stage F — snapshot fork

- [ ] **F1:** snapshot descriptor + MVN save/restore machinery (own routine
  pair in `process.s` or new `forksnap.s`; PUT from `main.s`).
- [ ] **F2:** SYS_FORK real handler in stub slot 2 per §1.4; `PS_SNAPFROZEN`;
  EAGAIN on pool-dry with full rollback.
- [ ] **F3:** nested fork (LIFO restore) — no new code expected, verify by probe.
- [ ] Probes: `FKISO`, `FKNEST`, `FKBG` green.
- [ ] Gate: full suite + `MULTIBANK_VERIFIED=1`; commit(s).

### Stage P — pipe ring growth

- [ ] **P1:** `PIPE_BufSz` field, init 512 at ring alloc; convert all constant
  compares in `pipe.s` to the field (read/write/teardown/space paths).
- [ ] **P2:** grow-on-full in `_Pipe_Write` per §1.5 (double up to 4096,
  unwrapped copy, then continue; block only at max).
- [ ] Probes: `PIPEGROW`, `FKPIPE` green; jsh pipeline handful re-run.
- [ ] Gate: full suite; commit(s).

### Stage L — close-out

- [ ] Docs: CHANGELOG narrative (what/why: fork tiers, deferred-parent
  semantics, ring growth); landmine doc section for the vfork frame contract
  and the no-tier-3 limitation; ROADMAP tick.
- [ ] the project notes: episode for the train (design + rejected tier 3 + rationale),
  supersede notes where applicable.
- [ ] Merge train → LOCAL main (tag `pre-kernel-fork` first); HOLD release.
- [ ] Unblocks: **tcsh 6.00 port plan** (separate doc; sh.proc.c intact).

---

## 3. Probes (new, `src/userland/` + `tools/mame_test/tests/`)

All follow the existing exit-code/screen harness patterns (clone
`tools/mame_test/tests/msgtest.json` shape; kprobe where kernel-state checks
help). C sources per the FGX2-default build (`build_userbin_fgx2_c`).

**VFEXEC** — vfork + exec + wait ordering:
```c
int pid = vfork();
if (pid == 0) { execve("/bin/true", argv0, 0); _exit(99); }  /* 99 = exec failed */
int st; waitpid(pid, &st, 0);
/* PASS: pid > 0, child exited 0 via exec'd binary, parent resumed after exec */
```

**VFEXIT** — vfork child `_exit(7)` without exec; parent sees status 7.

**FKISO** — snapshot isolation, the core correctness probe:
```c
int g = 1;                      /* data-bank global */
char *h = sbrk(64); h[0] = 1;   /* private sbrk bank (Stage S) — NOT malloc:
                                 * SYS_MALLOC heap is fork-SHARED by design */
int pid = fork();
if (pid == 0) { g = 2; h[0] = 2; _exit(0); }   /* mutate everything, die pre-exec */
int st; waitpid(pid, &st, 0);
/* PASS iff g == 1 && h[0] == 1 — parent restored from snapshot untouched */
```

**FKNEST** — fork inside fork (grandchild mutates, both ancestors restored).

**FKBG** — `fork(); child execs /bin/sleep-ish; parent must resume at child's
exec (not exit): parent writes a marker while the child is still alive.

**FKPIPE** — the backquote shape: pipe(); fork(); child writes 2 KB then
_exit (never reads, never execs); frozen parent restored at child exit reads
all 2 KB intact. Exercises ring growth 512→1024→2048 under a suspended reader.

**PIPEGROW** — no fork: writer pushes 4 KB against a slow reader; verifies
grow-to-max then correct blocking + byte-exact FIFO across two growths.

---

## 4. Risks / open items

- **Heap-grant enumeration (Stage 0)** is the one true unknown: snapshot
  correctness requires the kernel to know *every* mutable bank of a task. If
  grants aren't per-TCB today, that bookkeeping is the first real work and
  gates Stage F (not Stage V — vfork copies nothing).
- **Kernel stack across the freeze:** parent's in-kernel state at fork must be
  fully captured by SavedS/UserSP conventions the scheduler already uses for
  blocked tasks (`process.s:8-15` dance). Stage F reuses, not reinvents.
- **Signals to a frozen parent:** deliver on thaw (queue in the existing
  pending mask); document in the landmine section (§6A reentrancy rules apply).
- **vfork child blowing the shared stack:** FGX2 1-page default task stacks are
  tight (256 B frames overrun). tcsh will need a bigger stack allocation
  anyway; probes use small frames. Note in the tcsh port plan, not here.
