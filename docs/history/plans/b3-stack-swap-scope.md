# B3: address-preserving stack swap — scope

**Status (2026-09-18): SUPERSEDED by the user-image cache** --
`docs/history/plans/2026-09-17-bank0-residency-architecture.md`, section 5.2.
The lane, `_laneResident`, `_laneHomeBank` and the home-bank argv staging are
gone; every task is a member of its own range and the allocator may lay a
range over parked tasks (`kernel.stkover`, `Uimg_*` in task.s).  The
eligibility rule, `SEF_STKLOCK`, `SEF_STKBORROW`, the dwell and the survey in
section 3.3 carry over unchanged.  This document is the record of how the
mechanism was built and proved; read the design document for what runs.

**Status (2026-08-07):** **B3.0 through B3.3 are BUILT and gated.** The lane
swap works: two members co-resident at one address, parked and restored
byte-exact, with hysteresis bounding what contention costs.

**B3.4 is half met.** Three tcsh sessions demonstrably co-exist and the arena
numbers prove it -- which was the campaign's whole objective. Shipping `ttyv2`
`on` is blocked by apple/fgx#43, a login(1) TERM regression on ptys that is not
a B3 defect and only became reachable once a third console was affordable.

Written 2026-08-06 after an independent review of the
2.11BSD kernel (`examples/2.11BSD/usr/sys/`) by a second reviewer, deliberately
given the primary source and FGX's hardware constraint but none of our
conclusions; amended twice since, after a second review found the survey in §3.3
wrong by two entries.

**The problem it exists for:** the arena is 156 pages and a tcsh asks for 76
(hint 74, plus its argv frame and guard). Two tcsh sessions plus init plus the
console `sh` need 168 to sit *idle*, which is why `/etc/ttys` ships two virtual
consoles and not three, and why remote login over a pty has nowhere to go.
Reclaim cannot close this — every page-level lever identified in
`bank0-stack-status.md` §§9-11 is worth about 20 pages between them, and
apple/fgx#42 has already spent 9 of those.

---

## 1. The invariant

> 2.11BSD never fixes up a pointer, because the MMU means it never has to. A
> no-MMU port keeps every one of its disciplines only to the exact extent that
> **every byte returns to the address it left.**

That sentence is the design. Everything below is a consequence of it.

FGX cannot relocate a stack: fcc frames hold absolute bank-0 addresses (the
prologue `PEI`s `_fcc_fb`, and `&local` escapes into DP cells, the heap and
kernel-held syscall args), so the pointers into a C stack cannot be enumerated.
What FGX *can* do is take the bytes away and put them back **where they were**.
A blocked task cannot tell the difference.

---

## 2. What the independent review changed

Both readings of the source agreed on the mechanism inventory: three separately
swapped regions (`sys/vm_swap.c:105`), eligibility on interruptible sleep
(`sys/vm_sched.c:106`), `SLOCK`/`SULOCK` exclusion, a victim score of size plus
sleep time, the u-area at a fixed kernel virtual address switched by one MMU
register write (`pdp/mch_xxx.s:149`), the per-process kernel stack living inside
it, and shared text refcounted by `x_count`/`x_ccount`.

Five things came back that we did not have, and four of them change the design.

**2.1 The scarce resource is bank 0, not memory — so the question is different.**
2.11BSD was short of *memory*. FGX has 8 MB and is short of *bank 0*: 40 KB that
only the running and ready tasks actually need at any instant. So the mechanism
to import is not "how did 2.11BSD fit processes into memory" but "how did it
time-share a resource that only the ready subset needs right now". That is
exactly what its u-area handling does, and it is the part that transfers.

**2.2 Address-preserving swap makes eviction ADDRESS-constrained, not just
size-constrained.** This is the important one. 2.11BSD picks the biggest,
longest-sleeping victim and puts it back wherever core is free, because `sureg()`
absorbs the move. FGX cannot: a returning task needs *its own* addresses. So the
victim is not "whoever is fattest" but **"whoever is sitting on the range the
incoming task needs"** — and if the ranges do not coincide, evicting the fattest
sleeper accomplishes nothing.

That converts the lane from a convenience into a *derived requirement*. Tasks
that are to share residency must be allocated the **same page range**, so that
evicting one is exactly what frees the other's addresses. A general swapper over
a first-fit arena would evict correctly-sized victims at the wrong addresses
forever.

**2.3 The u-area's bundling is an MMU-register economy, and FGX already split it
the right way.** 2.11BSD puts the per-process struct *and* the kernel stack in
one region because one relocation register maps both. Nothing intrinsic requires
that. On FGX only the hardware stack and the direct page must be in bank 0; bulky
per-task state can live anywhere in 8 MB. FGX's per-task DP pages at
`$B500-$BFFF`, switched by reloading `D` at context switch, **are** the u-area's
hot part, arrived at independently — and `D` is the genuine hardware analogue of
`KDSA6`.

**2.4 2.11BSD swaps RUNNABLE processes too, and we both under-read this.** The
victim scan's fallback tier takes `SRUN` or non-interruptible `SSLEEP`, oldest
first (`sys/vm_sched.c:122-131`), when no interruptible sleeper is available. So
"only swap blocked tasks" is 2.11BSD's *preference*, not its rule. FGX should
still start blocked-only — it is the safe subset — but the precedent says the
door is not closed.

**2.5 Shared text gets EASIER without an MMU, and the precondition moves to the
toolchain.** Every instance can execute one physical copy, because there is no
per-process code address to map. What it needs instead is that code reach its
per-instance data through a per-task base rather than through absolute addresses
baked beside the code. FGX's model is already this: data is DBR-relative and DBR
is per task. That reframes the shared-text item in §11 — the blocker may be
narrower than "relocs are applied per load". Not part of B3; recorded because the
review moved it.

---

## 3. The design

### 3.1 The lane

A **reserved page range in the arena**, sized to the largest session shell (today
tcsh at 76 pages including its guard and argv page), with a **home copy per member**
in a Memory Manager handle outside bank 0. At most one member is resident at a
time; the rest are parked.

Every member is allocated **the same base address**. That is what makes eviction
meaningful (§2.2) and what makes restoration exact.

Members are **session-leader shells only**. Their children are ordinary tasks
with ordinary reservations, allocated outside the lane, and are never swapped —
a child running while its parent shell is parked is the normal case and must keep
working.

> **CORRECTION 2026-08-07.** That last paragraph is **true only of `spawnx`
> children**. A `fork`/`vfork` child gets no reservation of its own: it BORROWS
> the parent's stack, at the parent's addresses, including a member's lane pages
> (`process.s:598-615`). So "a child running while its parent shell is parked" is
> not the normal case that must keep working — for a forked child it is the case
> that **corrupts**, because the bytes it is running on are the ones being
> swapped. See the borrower subsection in §3.3.

### 3.2 Eligibility

Import 2.11BSD's predicate rather than inventing one:

    swappable(t) = t is a lane member
                && t is asleep INTERRUPTIBLY (or stopped)
                && not LOCKED (SEF_STKLOCK, §3.3)
                && not BORROWED (SEF_STKBORROW, §3.3) -- added 2026-08-07

Interruptible sleep is exactly "blocked in `read()` on a tty, a pty or a pipe,
or in `wait()`" — the state in which `^C` can reach it. **It is deliberately
blind to which console is focused**, which is what makes it correct for pty
sessions: a telnetd login is interruptibly asleep exactly like a console shell,
and `_kVcActive` becomes an optimisation hint rather than the mechanism.

### 3.3 Lock, do not audit

2.11BSD sets `SLOCK` on a process while any path holds its memory
(`sys/vm_swp.c:137`, around raw I/O) and the victim scan skips it. FGX takes the
same shape: a per-task **`SEF_STKLOCK`** flag, set for any window in which the
kernel holds a pointer into a task's user stack, and honoured by the swapper.

The survey of paths is the same work either way. The difference is the failure
mode: an audit silently expires the first time somebody adds a path, whereas a
flag makes "not swappable right now" something new code has to think about.

#### The survey, done 2026-08-06 (B3.0, static half)

The question is narrower than "who holds a pointer into a user stack". With
address-preserving swap, a pointer stays valid across a swap — the bytes come
back to the same addresses. The only fatal case is a write that lands **while the
owner is parked**, i.e. from an interrupt or from another task's context.

> **AMENDED 2026-08-07 (apple/fgx#46): the rule is "who can hold, write, run on,
> **or derive state from** the lane".** The survey below asks only who WRITES,
> and that clause missed an entire class — code that READS the lane and draws a
> conclusion from it. The first one found was `Task_StkHwm`: it scans bank 0
> from `TCB_StackBase` for the deepest non-`STK_PAINT` word, so for a parked
> member it measured whatever the **resident** left there and reported it as the
> parked task's high-water mark. That is not a cosmetic `ps` column — it is the
> measurement `TASK_STACK_LANE_MAX` is derived from, and the lane's size is
> charged to every scenario containing a shell in `check_stack_budget.py`.
>
> A reader is not automatically safe just because it cannot corrupt anything.
> Ask of each one: **is the answer still true when the bytes are elsewhere?** If
> it is derived from lane contents, it must follow the bytes to the home bank
> (what `Task_StkHwm` now does) or refuse to answer. Silently answering about a
> different task is the worst of the three.
>
> Covered by `b3hwm`, which puts two deliberately-unlike members in the lane at
> once and requires their marks to differ; the pre-fix build reports them as
> identical to the byte.

Every FGX I/O path was checked against that. **All of them are ring- or
staging-mediated, and every copy into a user buffer happens in the owning task's
own context:**

| path | intermediary | copy performed by |
|---|---|---|
| tty input | kernel kbd ring, heartbeat-fed (`Con_PollKey`, `console_kbd.s`); `_kTtyRdPtr` holds a `_ttyTable` address | the reader, on wake |
| pty | `_ptyInRings`/`_ptyOutRings`, kernel-bank (`pty.s`) | the reader, on wake |
| pipe | `Kmalloc(PIPE_BUFSZ)` ring via `PIPE_BufPtr`; the writer fills it and calls `_wakeup` | `_Pipe_CopyOut`, in the reader's context after its `_sleep` returns |
| block I/O | `BLK_STAGE` (bank 0, kernel), firmware-mandated; then `MVN` to the caller's buffer | the caller — and it never yields: there is no `_sleep` on the block path at all, so a task doing disk I/O is never asleep to be swapped |
| W5100 RX | the W5100's own hardware RX buffer; `_Sock_PollIntr` polls | `_W5_RxCopy`, in the reader's context |

**That is a uniform property of the design, not five coincidences**, and it is the
single biggest thing standing between B3 and "unsafe". It should be stated as an
invariant somewhere load-bearing, because a future driver that DMAs straight into
a user buffer would silently break B3.

#### What DOES write into another task's stack

**AMENDED 2026-08-07.** The first cut of this list had three entries and was
wrong by two. Both misses share a shape, and it is the same shape that killed
B3.2's first implementation (§4.3): the survey asked *"who writes into a task's
stack"* and answered it for the paths that write into a **child's** stack, while
the dangerous direction is a write into a **parent's** stack — or into a range
some *other* task is executing on. The list below is the corrected one; entries
4 and 5 were added after an adversarial review, and 6 is B3's own doing.

1. **`_Loader_StageArgs`** — the parent writes the argv/envp frame into the
   CHILD's stack at spawn (`include/loader.s`). Foreign write, but the child is
   not yet runnable. **`SEF_STKLOCK` covers this** (three call sites).
2. **`_Fork_Snapshot`** — copies the parent's live stack into the child's. Reads
   a running parent, writes a not-yet-runnable child. **`SEF_STKLOCK` covers
   this** (`process.s:788`).
3. **Signal delivery** — pushes the handler frame onto the user stack, but only
   at syscall-return in the task's own context (`syscall.s:350-391`), which is
   why 2.11BSD's equivalent is also swap-compatible. **Safe as-is.**
4. **`_Fork_Restore` — MISSED BY THE FIRST SURVEY; COVERED 2026-08-07** by
   `SEF_STKBORROW`, which the parent holds across the whole borrow window and so
   across this write too. The finding as originally written: The
   snapshot hand-back copies the parent's saved stack bytes back over the
   parent's live stack, and does it **from the CHILD's context**: `@fr_stack`
   walks a bank-0 destination (`STZ _libcTmp2+2`) to `FSD_STKBASE`, the parent's
   base (`process.s:1228`, tail at ~1290). It is called at `process.s:2044` (the
   child's `execve`) and `process.s:2508` (the child's `_exit`). **Neither site
   is wrapped in `Task_StkLock`.** At that moment the parent is interruptibly
   asleep on `WCHAN_VFORK` — a textbook parked member under B3.2 — so the write
   would land on whichever member is resident. This is a foreign write into a
   *parked* task's stack, which is precisely the fatal case defined above.
5. **The child of a fork is not a writer but a USER — see the next section.**
   This is a different category and the survey had no room for it, which is why
   it was missed. **COVERED 2026-08-07 by `SEF_STKBORROW`**, which also closes
   item 4 above (`_Fork_Restore` runs inside the borrow window).
6. **`_Tas_PaintStack`, once the lane exists.** Allocation paints the whole
   requested range with `$A5A5` for the high-water scan (`task.s`, the shared
   tail both scans reach). Harmless while every stack is private; under B3.1 a
   lane member is allocated the WHOLE 78-page lane, so admission scribbles the
   entire lane — including the resident member's live bytes — **before**
   `_Loader_StageArgs` ever runs. §4.3's post-mortem blamed only StageArgs; the
   paint is an earlier writer in the same window, and any hand-off must park the
   resident before the paint, not merely before the staging.

So `SEF_STKLOCK`'s coverage as built is: **from stack allocation until first
run**, and **across the snapshot-fork copy**. That is genuinely small — but it is
not complete, and the gap (4 and 6) is not a sprawling audit either. Both are
single call sites with a known counterpart.

#### The borrower case: a range can be pinned by a task that is not its owner

**ADDED 2026-08-07.** This is the category the survey structurally could not
express, because it is not about who *writes*.

`_Sys_Vfork` gives the child the parent's entire image and copies `TCB_StackBank`,
`TCB_StackPtr`, `TCB_StackBase`, `TCB_StackSize` and `TCB_DirectPage` straight
across (`process.s:598-615`); the child's TCB owns nothing, which is exactly what
makes the teardown paths no-op on the shared image. A snapshot fork adds spare
banks for the mutable image, but the child still **executes on the parent's
bank-0 stack**, at the parent's addresses, for the whole borrow window. The
parent meanwhile blocks on `WCHAN_VFORK` through a plain, interruptible `_sleep`
(`process.s:843`) — there is no uninterruptible sleep in FGX; every sleep goes
through `_sleep`.

Line those two facts up against §3.2's eligibility rule (interruptibly asleep,
not `SEF_STKLOCK`'d) and the result is:

> **A forking lane member is an eligible swap victim while a RUNNING task
> executes on its stack.**

Swapping it out hands the lane to another member and overwrites a running task's
stack under it. This is not an edge case — `fork` + `exec` is how a shell starts
anything, and a snapshot subshell that never execs (tcsh pipelines,
backgrounding) makes the window unbounded. It also means B3.2's own gate wording,
*"a child keeps running while its parent is parked"*, describes the corrupting
case rather than the passing one; it is safe only for `spawnx` children, whose
stacks are their own.

**The awkward part is that the obvious fix collides with B3.0.** Holding
`SEF_STKLOCK` on the parent across the borrow would mean the parent sleeps while
pinned — which is exactly what the `_sleep` assertion this campaign just built
panics on. The lock's meaning is "nobody may swap me *right now*, and I am not
about to sleep"; the borrower case needs "nobody may swap me *for as long as
someone else is running on my bytes*", across a sleep, which is a different
predicate with a different lifetime.

So the eligibility rule needs a **second, independent condition**, tested by the
victim scan and deliberately NOT tested by the `_sleep` assertion.

### `SEF_STKBORROW` — the borrower condition, landed 2026-08-07

`SEF_STKBORROW` (bit 6 of `SE_Flags`) means *"a fork child is executing on this
task's bank-0 stack"*. Set on the **parent** in `_Sys_Vfork`, cleared on the
parent at **both** hand-back sites (the child's `execve` and its `_exit`).

The two flags are deliberately not merged:

| | meaning | lifetime | read by |
|---|---|---|---|
| `SEF_STKLOCK` | "do not swap me right now, and I am not about to sleep" | inside one syscall | victim scan **and** `_sleep`'s assertion |
| `SEF_STKBORROW` | "do not swap me while someone else runs on my bytes" | **spans a sleep by design** | victim scan only |

**One bit suffices**: `vfork` blocks the parent until hand-back, so a task can
never have two borrowers at once.

**It covers survey item 4 for free.** `_Fork_Restore` runs *before* the hand-back
clear at both of its call sites, so the parent is already flagged ineligible
while that write happens — no separate lock at those two sites.

**The pairing is checked by the kernel, continuously, rather than by one
bespoke test.** The set and the two clears live in different routines; if they
drift apart the result is silent until B3.2 reads the flag, and then it is
either a shell that can never be swapped out or a live task swapped from under a
running child. So `Task_BorrowClr` reports a clear with no matching set, and
`Task_BorrowSet` reports a set that finds the flag already on (which, given the
one-borrower-at-a-time property, means a clear was missed). Every fork in the
suite is therefore a test of the pairing.

**Mutation-proven three ways, all caught by `tools/gate.sh`:**

| mutation | result |
|---|---|
| delete the set in `_Sys_Vfork` | 10 gate tests fail: `PANIC B3: fork hand-back with no SEF_STKBORROW, parent pid 2` |
| delete the `execve` clear | `fkbadex` fails: `PANIC B3: SEF_STKBORROW set twice (a clear was missed), parent pid 6` |
| delete the `_exit` clear | `fkbadex`, same |

Two notes for whoever touches this next. The execve clear is **gated on
`_ev_isChild`**, because that block is also reached by a plain `exec`, which
borrowed nothing — without the gate every `sh -c cmd` in the suite trips the
unmatched-clear report. And the `_exit` clear needs no such gate, because its arm
already sits inside `BIT #SEF_VFORKCHILD+SEF_SNAPCHILD`.

Both reports **return rather than halt**, for the same reason as
`_Slp_StkLockPanic`: nothing is corrupted until B3.2 reads the flag. Both become
halts when it does.

**What is still missing before B3.2**: the victim scan that reads the flag. The
state and its invariant are now in place and enforced; the consumer is not.
Item 4 and item 5 above are no longer open.

**Neither is visible to the current evidence chain.** No tap has ever watched a
fork parent's stack: `b3park`/`b3pty`/`b3ptyrd` all park their subjects
in `sleep` or `read`, never mid-fork. That is the same "subjects chosen to
receive nothing" failure the earlier review caught in the attribution rule, and
it means the greens say nothing either way about items 4 and 5. A test for the
borrower case — a member forks a child that stays busy WITHOUT exec'ing while a
second member runs — should be written **before** the code, and must be red
against the §4.2/§4.3 design as it stands.

#### The empirical half: `b3park`, built 2026-08-06

The survey is an argument; this is the evidence. `tools/mame_test/tests/
b3park.json` backgrounds a `sleep` — parking a task interruptibly asleep with a
live stack in the arena — then hammers the machine with a 30-process spawn storm,
which is maximum arena churn all around the parked stack. `ps` before and after
reports the high-water mark of every parked task, measured by the kernel's own
`STK_PAINT` scan. **Three subjects are checked: `init`, `getty` and the
backgrounded `sleep`** — `init` and `getty` are the valuable ones because they sit
at the *bottom* of the arena, where a stray write is most likely to land.

Result: unmoved. `init` 144, `getty` 134, `sleep` 138, identical across the storm.

The task table is dumped `kbank`-relative and decoded, so stack extents are read
from the kernel's own structure rather than assumed. It also proved the
compaction landed: `init` at `$1900..$1C00`, the new arena base.

**Mutation-proven, and it took three attempts to make it discriminate — which is
the finding worth keeping.** A fixed-address scribble on the *alloc* path fires
on every spawn, so both `ps` tables show the same moved mark and the test passes.
Moving it to the *exit* path did not help: tasks exit throughout boot, long
before the first `ps`. Only a cursor that **walks downward** makes the mark grow
*across the measurement window* regardless of when the corruption began — and
then the check caught it exactly (`init` 386 -> 450) while `getty` and `sleep`
stayed put.

Two things this cost, recorded so the next test does not pay them again:
*a before/after comparison is blind to any corruption that starts before the
"before"*, and *the console `sh` is not a valid subject* — it runs the storm, so
its mark legitimately grows 232 -> 814. Widening the check to "every task in both
tables" was tried and is wrong for that reason.

#### The other half: the attribution tap, built 2026-08-06

> **Merged 2026-08-07 (apple/fgx#47).** This shipped as a separate test named
> `b3live`, which ran the byte-identical workload to `b3park` and differed only
> in which checker read the dump -- two machine boots for one machine state.
> It is now the second half of `b3park`, which asserts both claims in order and
> prints both verdicts. The rule and the taps are unchanged; only the boot is
> shared. `b3live_check.py` remains as the shared attribution module that
> `b3park` and `b3pty`/`b3ptyrd` all call.

`b3park` cannot see a foreign write landing INSIDE the frames a task has already
touched — the mark stays where it was. `b3live` covers that half with a
`capture_writes` tap on the live region.

**The attribution trick is that `capture_writes` records the writer's `D`, and
FGX gives every task its own direct page.** So `D` names the writing *task*: a
write into a parked task's stack is legitimate if and only if `D` is that task's
own DP page. No frame ordering, no PC ranges to maintain.

Two taps: the parked `sleep`'s own frames (`$2190`), and — as a positive control
— the live frames of the shell that runs the storm (`$A480`). A control that
records nothing means the tap machinery is broken and the subject's silence is
worthless.

**The ownership boundary is the paint.** The raw log is dominated by writes that
predate the task: IIgs firmware during boot (`D=$0000`, `PB:PC=$00/F8CC`), then
`Task_AllocStack`'s `STK_PAINT` fill at carve time (`A=$A5A5`, kernel DP). The
check finds the last paint from a non-owner DP — the instant of ownership — and
judges only what follows. Without that rule every run looks catastrophic; it is
the same ordering trap `b3park` hit from the other side.

Result, after the carve: **every write to both cells came from the owning task's
own DP page.**

**Mutation-proven, and the mutation proves something extra.** A kernel-context
write of `$BEEF` into `$2190` on every task exit — inside the parked task's live
frames, from a foreign DP — turns `b3live` red (18 foreign writes) **while
`b3park` still passes**. That is empirical proof the two tests cover different
halves, rather than an assertion that they do.

Anti-stale, since a probe address going stale is this project's most repeated
self-inflicted wound: the fixed tap addresses are re-verified every run against
the TCB table — each must fall inside the task it names, and inside that task's
live region (above end minus high-water). Drift fails loudly instead of reporting
a serene zero.

#### What B3.0 has and has not established

**Established, with evidence:** nothing writes into a parked task's stack —
neither below its high-water mark nor inside its live frames — across a
30-process spawn storm.

**Not established:** the same under network and pty traffic (the storm is arena
and disk churn), and the behaviour of the three known foreign writers from the
survey (`_Loader_StageArgs`, snapshot fork, signal delivery), which these tests
do not exercise against a *parked* task because they cannot occur against one
today. Those are what `SEF_STKLOCK` is for, and they are B3.1's business.

### 3.4 What moves, and where to

**Phase 1 moves the user stack only**, and only the live extent — from the
current `S` up to the stack top — not the whole reservation. A shell blocked at a
prompt holds 1-3 KB of a 78-page reservation, so the copy is small even though
the reservation is not. `Task_StkHwm`'s paint scan already measures exactly this
and `ps` already reports it.

Destination is a Memory Manager handle in a high bank. **This is RAM, not disk**:
2.11BSD paid milliseconds of I/O, FGX pays a `MVN` at 7 cycles a byte. 3 KB is
about 8 ms at 2.8 MHz.

### 3.5 Triggers and hysteresis

- **Swap in**: on wake, before the task runs. Mandatory and immediate.
- **Swap out**: on block, **only if the lane is contended** — another member is
  waiting for residency. An uncontended lane never copies anything, which keeps
  the single-console case free.

Without hysteresis a remote shell would swap on every keystroke: tcsh's editor
reads in raw mode, so it blocks per character. At 10 cps and 3-8 ms a copy that
is 3-8% of the machine for no benefit while nothing else wants the lane.

### 3.6 Explicitly out of scope

- **Kernel stacks.** 2.11BSD swaps them with the u-area and FGX holds all 11
  resident, which is 11 pages of bank 0 held for tasks that may be blocked
  indefinitely. It is the same argument and a real prize, but it is a second
  campaign: the kernel stack is live *during* the syscall that would swap it.
- **Growth.** Bank-0 stack allocations are fixed-size at task creation, by
  hardware. No mechanism grows them later. Unchanged by B3.
- **Compaction / relocation.** Dead, permanently, for the reason in §1.
- **Non-shell tasks.** No general swapper.

#### The pty half: `b3pty`, built 2026-08-07 -- and it corrected `b3live`

`b3park` and `b3live` both ran ONE workload: a 30-process spawn storm, which is
arena churn and disk I/O. Two of the five paths §3.3 rests on were never
exercised while a task was parked. A survey plus evidence from the wrong
workload is still an argument.

`b3pty` runs the same tap under `/testbin/logintest` -- the only real pty
workload in the suite. It opens a pty master, spawns getty on the slave, and
drives getty -> login -> shell -> passwd across two pty pairs, so
`_ptyInRings`/`_ptyOutRings` run hard in both directions with tasks blocking and
waking on pty reads throughout, while the arena churns underneath. Result: after
ownership, **every write into both parked subjects' live frames came from the
task itself**.

**Subjects are `getty` and `init`, not a backgrounded `sleep`.** A `sleep` does
not survive this workload -- logintest churns enough processes to wrap the pid
counter, and its signal phases reach the console shell's group. `getty` is the
better subject anyway: blocked in a REAL device read rather than on a timer, and
like `init` it sits at the bottom of the arena.

**Two corrections to `b3live` that building this forced.** Both are the same
shape: a rule that happened to be right for one workload.

1. **The ownership boundary was TIMING-DEPENDENT.** It was "the last `STK_PAINT`
   from a non-owner DP". But the kernel writes the argv/envp frame into the
   child's stack AFTER the carve and before first run -- survey case 1, and
   exactly the window `SEF_STKLOCK` is specified to cover. A task `init`
   **respawns** is carved twice, so its second paint lands after the staging and
   the staging escapes judgement; a once-carved task has the same legitimate
   writes fall on the other side. `b3pty` caught it as `getty` passing and
   `init` failing on identical kernel writes from `$7D/68A1`. The boundary is
   now **the first write from the task's OWN DP** -- the instant it starts
   executing, which is the only point at which "parked" starts to mean anything.

2. **`D` names the DP IN EFFECT, not the task.** When the kernel runs a syscall
   on behalf of a task, `D` is the kernel DP and a write to that task's own
   stack is legitimate. A RUNNING task is inside syscalls constantly -- b3live's
   control records 68 such writes from `$7D/9D00`. So the subject/control split
   is load-bearing, not laziness: **only PARKED subjects can be judged on
   foreignness**, and a control's only job is to prove the tap machinery
   records anything at all. This is a real limit on the attribution trick and it
   is worth stating: the evidence is strongest for tasks parked OUTSIDE a
   syscall, and merely strong for tasks asleep inside one.

A saturated capture log is now reported rather than read as quiet -- a truncated
log cannot prove an absence. Controls are exempt: they prove presence.

**Mutation-proven, and the mutation had to be redesigned twice.** A destructive
`$BEEF` scribble kills logintest, so `b3pty` fails on its vacuity guard rather
than on the property -- which proves nothing about the check. The mutation that
works is **non-destructive**: read each cell and write it straight back from
kernel context on every task exit. The value is unchanged and the workload
completes, but it is a foreign-context write into a parked task's live frames,
which is what the tap judges. With it in, `b3live` reports 66 foreign writes and
`b3pty` 34; with it out, both are green. (The first attempt used `STX:` and
silently wrote `$7D:xxxx` -- in the kernel DBR is the KERNEL bank, so a bank-0
mutation needs `STAL`.)

**Remaining gap, stated rather than implied:** neither subject is a task blocked
in `read()` on a PTY with a stack-local buffer. The pty readers here are
getty/login/shell on the SLAVE, which are transient and never reach a `ps`
table, so their extents cannot be discovered and validated. Covering that needs
a purpose-built reader binary that persists.

#### `b3ptyrd`: the pty path itself, and the attribution rule it corrected

An independent (Fable) review of the three tests above returned a verdict worth
recording verbatim in effect: *good enough to catch gross regressions, not good
enough to build B3's kernel work on.* Two findings were structural.

**1. `b3pty` never exercised the pty path against a watched stack.** Its parked
subjects are `init` and the CONSOLE `getty`; neither touches a pty. The tasks
that actually drive `_ptyInRings`/`_ptyOutRings` are the gettys/logins/shells
`logintest` spawns on the SLAVES, and those are transient, never reach a `ps`
table, and were not tapped. The test's own docstring admitted half of this; its
name and this document claimed more than the mechanism delivered. `b3pty` is now
scoped to what it measures -- **parked stacks under pty-driven process churn** --
and the pty row is evidenced by a new test instead.

**`b3ptyrd`** supplies the missing subject: `b3ptyrd` opens the pty MASTER and
`spawnx`s `b3ptyrx` on the SLAVE with the slave as its fd 0, then pushes writes
through; `b3ptyrx` blocks in `read(2)` forever with the destination buffer ON
ITS OWN BANK-0 STACK. It parks, receives real data into a stack frame, parks
again, and **persists**, so both extents come from the kernel's own TCB table.

**`spawnx`, not `fork`** -- and this is a fact about FGX worth keeping: fork is
snapshot/vfork shaped, so a forked child BORROWS its parent's stack and direct
page. Measured on the first cut: parent and child both reported
`TCB_StackBase $1F00` and `TCB_DirectPage $BC00`. A reader sharing its writer's
stack evidences nothing.

**2. `D` cannot certify anything on its own, and the greens were conditioned on
subjects that receive nothing.** The dispatcher switches `D` to the KERNEL
direct page at syscall entry and restores it at exit, so *every* kernel-mode
write carries `D = $B500` -- **including the ones §3.3 blesses**: the tty/pty/
pipe copy-out happens "by the reader, ON WAKE", i.e. in kernel mode. A parked
task that actually receives data would have had its own legitimate copy-out
flagged as a B3 violation. The old rule stayed green only because every subject
had been chosen to interact with nothing.

The fix uses data the tap already captured. A kernel-mode write is the owner's
if the CPU is running on one of the owner's own stacks:

    D == owner DP                          -> the owner, in user mode
    D == kernel DP, S in owner kernel stack -> kernel serving the owner
        (FGX_STK_KTASKS + (pid << 8))
    D == kernel DP, S inside owner stack    -> kernel on the owner's USER stack;
        FGX lays the syscall resume frame there, measured as $7D/68F9 and
        $7D/690E writing pid 8's frame with S=$2503..$2505, squarely inside its
        $2200..$2600
    anything else                           -> genuinely foreign

`b3ptyrd` is precisely the test that exercises this, so a regression in the rule
surfaces there first. Both constants are read from `include/kernel.s` at check
time rather than baked in.

**Known limit, stated:** an IRQ handler runs on whatever kernel stack is
current, so it masquerades as the task it interrupted. Strictly better than `D`
alone; the residue is named rather than hidden.

**FIRMWARE / INTERRUPT CONTEXT, resolved 2026-08-07 (apple/fgx#44).**
`b3ptyrd` intermittently reported writes with `D=$0000` as FOREIGN, under a
failure text asserting that B3 was unsafe as designed. That was the rule's
limitation, not a defect in the design.

**FGX runs at `D=$0000` in two places that write user stacks:**

1. the ROM SmartPort convention -- `_blkFwCall` (`src/drivers/block/block.s`)
   zeroes `D` so the firmware's 6502-style scratch lands in the real zero page
   rather than FGX's relocated kernel DP; an Apple II SCSI card hangs forever
   with a non-zero inherited `D`.
2. **the entire IRQ dispatch chain** -- `_KernIrq_Dispatch` does
   `LDA #$0000 / TCD` (`src/kernel/sim.s:333`), and everything downstream runs
   that way: its own `PHK`/`PLB`, the ROM heartbeat it chains to, and
   `serial_isr`.

**#44's records are the second, not the first**, which the kernel listing settles:
`PB:PC=$7D/25FC` is the dispatcher's own `PLB`, one byte past the `PHK` it
pushed at `$25FB` with `D` already zeroed (`$7D` = the MM-relocated live kernel
bank). So the trigger was never "the subject was doing disk I/O" -- it is **any
interrupt landing while the running task's `S` sits just above the tapped
cell**, and the 60 Hz heartbeat supplies those constantly. That is what
"intermittent" meant.

**Why attributing by `S` is sound** -- and this is the part to re-check if any of
it changes:

- **Model A preemption.** The quantum "never preempts kernel code"
  (`src/kernel/toolbox.s:337`) and resched happens at the syscall boundary
  (`src/kernel/syscall.s:310`). A task cannot be parked mid-IRQ or
  mid-firmware-call, so a `D=0` window always belongs to the task that is
  *running*.
- **Every `D=0` writer that can reach a tap is a PUSH at its own `S`** -- the
  interrupt frame, the dispatcher's `PHK`/`PHP`/`PEA`, `serial_isr`'s `PHA`, the
  ROM's own pushes. Pushes land at or below the executing SP, so they can never
  be one context writing into a *sleeping* task's frames.
- **Idle runs on the blocked caller's KERNEL stack** (`src/kernel/sched.s:340`),
  not in the arena, so idle-time heartbeats cannot push into a tap range.

"The block path never sleeps" remains true (no `_sleep` anywhere under
`src/drivers/`) but it is a corroborating footnote here, not the pillar --
#44's writes were not disk I/O at all.

**The day preemption moves past Model A, or any ISR starts writing through a
pointer into a user buffer rather than only pushing, this arm becomes a real
mask.** The W5100 ISR only acknowledges today; the operations re-poll in task
context (`src/kernel/sched.s:378-383`).

The rule now classifies `D=$0000` by `S` like any other non-owner DP and reports
it as INTERRUPT/FIRMWARE -- counted and printed, and **distinct from "another
task wrote here"**, which was the whole point. It is a classification, not an
exemption: firmware context that `S` cannot attribute to the owner still fails.

Two lessons worth keeping. The report said *"serves pid 25"* on a machine with
eleven slots, because the `S`->pid mapping was raw arithmetic with no bounds
check; **a probe that invents a plausible number sends the first reading of it
somewhere useless** -- and it did, twice: once toward a TERM-lookup bug and once
toward SmartPort. And the decision is now a pure function with a self-test that
replays #44's recorded values, because its trigger is a timing coincidence that
three consecutive `b3ptyrd` runs did not reproduce. *A flaky test passing again
is not evidence that it was fixed.*

**Still not covered, stated rather than hidden.** `on_owners_own_stack`'s
user-stack arm cannot tell lane members apart, because they share the lane's
address range. So a kernel write into lane addresses on behalf of a **parked**
member, issued from a resident context, classifies as `kernel` -- under the old
rule too. And once a swap actually occurs during a tapped run, the resident
sibling's own user-mode writes will classify `foreign`. Neither is reachable in
today's tests; both are why these taps are spot-checks rather than proof.

**Coverage, stated:** `b3ptyrd`'s tap is **192 bytes** of its subject's live
frame. `b3park`/`b3pty` are **2 bytes** of theirs -- a spot-check, not
region evidence, and a real foreign writer landing elsewhere in a 134-232 byte
live region would be invisible to them. `b3ptyrd`'s writer count is deliberately
small so the legitimate copy traffic cannot saturate its wider tap; a saturated
log is now reported rather than read as quiet, and the cap is read from the
manifest instead of hand-copied into each check script.

**Boundary residue:** the ownership anchor is the owner's DP page, which is
recycled with the pid. A prior incarnation of the same pid that ran through the
tapped cell would anchor it too early -- a false ALARM, never a false pass. The
checker now names that case instead of letting it present as a mystery
violation.

#### `SEF_STKLOCK` -- B3.0's gate, landed 2026-08-07

The flag exists, the two surveyed windows set and clear it, and `_sleep` panics
if the current task carries it.

**The survey's windows turn out to be narrower than this document assumed.**
Both -- argv/envp staging and the snapshot-fork copy -- act on a task that is
NOT YET RUNNABLE, so neither can reach `_sleep` and neither could ever be a swap
victim: the eligibility predicate (§3.2) already excludes them. They take the
lock anyway, because §5's lesson from 2.11BSD's `lock(2)` is that a lock not
honoured on every path is worse than no lock, and because it exercises set/clear
under the full suite.

The lock is taken at the CALL SITES, not inside the routines: the pairing stays
visible and there is no multi-exit bookkeeping. `Task_StkLock`/`Task_StkUnlock`
preserve A, X, Y **and P** -- every site wraps a call whose CARRY is its result,
and the sched-entry offset arithmetic would otherwise eat it.

**It is NOT set inside `Task_AllocStack`**, which was the obvious place and is
wrong: `_Sys_ExecveVfork` allocates a stack for the CURRENT task on a plain
exec, which never passes through `_Task_FirstRun` to clear it, so the flag would
strand on a running task and panic at its next sleep.

**Mutation-proven.** Deleting the unlock after `_Loader_StageArgs` in
posix_spawn -- the exact "somebody forgot to unlock" failure the flag exists to
catch -- makes every spawned task carry it, and the first interruptible sleep
reports `PANIC B3: interruptible sleep with SEF_STKLOCK held, pid 5`. `smoke`
goes red on `screen_lacks PANIC`.

It reports and RETURNS rather than halting: nothing is corrupted yet (the
swapper does not exist until B3.2), halting would hang the harness on a timeout
and hide every later occurrence, and the suite already gates on the message.
When B3.2 lands and a violation means real corruption, it becomes a halt.

---

## 4. Phasing and gates

Nothing proceeds until the previous gate is measurably true.

| # | work | gate |
|---|---|---|
| **B3.0** ✅ | The `SEF_STKLOCK` survey: find every path that holds a pointer into a task's user stack across a sleep, and flag them. No swapping yet. | **MET 2026-08-07.** Flag set/cleared at both surveyed windows under the full suite; `_sleep` reports and names the pid; mutation-proven by deleting the unlock in posix_spawn |
| **B3.1** ✅ | Lane allocation: two members, same base, only one ever admitted; the second spawn fails cleanly. Still no swapping. | **MET 2026-08-07**, lane RIGHT-SIZED 2026-08-07. `b3lane`: three members all at `$6700`, 78 pages each; a nested second refused with `stk ENOMEM 76p` and the shell survives. Suite 60/63 (3 pre-existing), gate green |
| **B3.2** ✅ | Swap out/in on demand, no hysteresis, one lane, two members. | **MET 2026-08-07.** `b3swap`: two members co-resident at `$6700`, 6+ swaps executed, markers interleaved `A1 B1 A2 B2`, each member verifying its own stack byte-exact across the swap. All six B3 tests green, gate green, suite 61/3 | Two tcsh sessions co-resident on two VCs; `^C` reaches a parked shell; **a member that FORKS a child which stays busy without exec'ing is not swapped out from under it**; suite green |
| **B3.3** ✅ | Hysteresis + victim choice; measure the copy cost under a typing workload. | **MET 2026-08-07.** A RUNNABLE resident holds the lane for `TASK_LANE_HOLD_TICKS` (12 = 200 ms); a BLOCKED one is evicted at once, so the interactive path never pays it. Contended cost measured across four dwells (532 / 208 / 130 / 47 swaps) and recorded at the knob; `b3thrash` is the workload, mutation-proven |
| **B3.4** | `ttyv2` ships `on`; three concurrent shells. | **MET 2026-08-07.** `b3three` shows three real tcsh alive at once, all at the lane base, 78 pages between them, read from the kernel's task table; `check_stack_budget.py` puts three sessions at 121-123/154 against 246 without the lane. `ttyv2` now ships **`on`** (`kernel.nproc = 11`, MR !77): apple/fgx#43 turned out to be plain process-slot exhaustion, unrelated to B3, and it needed apple/fgx#45's derived bank-0 layout before the slots could safely be bought |

### 4.1 B3.1 as built

The lane is the **top 78 pages** of the arena, at `FGX_STK_LANE_BASE` = `$6700`
with the shipped 156-page arena. (**RIGHT-SIZED 2026-08-07** from the original
84 = `TASK_STACK_MAX_PAGES` + guard -- see "sizing the lane" below.) It is carved
out of the ordinary allocator rather than tracked beside it: both first-fit
scans now stop below `FGX_STK_LANE_FIRST`, so nothing else can land there, and
**`Task_FreeStack` needs no special case at all** -- a lane stack frees like any
other, same map, same arithmetic.

**A member is allocated the WHOLE lane**, not what it asked for, so base *and*
size are identical for every member. That is what an address-preserving restore
needs; over-allocating costs nothing because only one member is ever resident.

**Membership is by size**: `_tas_npages >= TASK_STACK_LANE_MIN` (40). Measured
on the shipped binaries this admits exactly the session shells -- tcsh is 75
pages and everything else is 23 or less (vi 23, tar 21, sh 15) -- so editors and
pipeline stages stay in the general pool where they belong. It needs no ABI
change and no new spawn attribute. Raise the knob if a non-shell ever grows past
it: an accidental member would deny the lane to the shell it was reserved for.

**The general pool is 78 pages**, against a measured non-lane worst case of 39
(the "deepest tool in a pipeline under tcsh" scenario minus tcsh).
`check_stack_budget.py` charges a member the LANE's size rather than its
request, because otherwise every scenario containing a shell is understated.

#### Sizing the lane -- and the one-page trap in doing it

The first cut sized the lane at `TASK_STACK_MAX_PAGES` + guard = **84**, i.e.
the largest stack the allocator can carve *at all*. That is the wrong ceiling:
it reserves against a hypothetical shell rather than a real one, and because a
member is charged the whole lane, every page of the difference lands on the
worst case for the entire machine. Measured cost: **nine pages**, bought for
nothing.

It is now sized to the largest **measured** member plus a named slack
(`TASK_STACK_LANE_MAX` + `TASK_STACK_LANE_SLACK` = 76 + 2 = **78**). Raise the
slack, not the max: the max is a measurement and should track reality, the slack
is the deliberate margin.

> **The absolute figures in this section are pre-2026-08-07 and are left as
> written**, because they are a record of a comparison made at the time. Two
> things have since moved them: `kernel.nproc = 11` took the arena 156 -> 154
> (apple/fgx#43), and apple/fgx#30 corrected two under-counts in
> `check_stack_budget.py` -- `init` was excluded although it is in the arena,
> and `pages_for()` omitted the argv/envp frame page that the kernel adds to
> every task. Today's worst case is **123/154**. Run the tool rather than
> quoting any number here; that is the habit whose absence produced #30.

**The trap: "measured" is not the linker's hint plus a guard.** `process.s`
(#45) adds `ceil((argv+envp bytes)/256)` pages for the frame the loader lays on
*top* of the C stack, because the linker never sees it. tcsh's hint is 74;
`check_stack_budget.py`'s model says 75; **the kernel asks for 76**, which the
machine states itself as `stk ENOMEM 76p`. Sizing the lane off the model's 75
would have produced a lane one page short of the machine's own request -- a
green build in which every tcsh spawn ENOMEMs. So the build check charges a
documented `LANE_ARGV_FLOOR` on top of its model, making it conservative rather
than optimistic, and the boundary was checked directly: a lane of 76 passes, 75
fails, and 75 is exactly the value the naive reading would have chosen.

Both halves are enforced rather than trusted:

- `check_stack_budget.py` **fails the build** if any staged binary would be
  admitted and does not fit, naming the binary. Verified by mutation: shrinking
  the lane below tcsh's need exits 1 and prints `tcsh needs 76 pages > 74`.
- `Task_AllocStack` refuses a member that does not fit with a **clean spawn-time
  ENOMEM** (§5's rule), never a silently smaller lane -- which would be a stack
  overflow with no diagnostic. Verified by building with an undersized lane and
  observing `stk ENOMEM 76p` rather than a truncated allocation.

**Evidence is the kernel's own free-time log line**, extended to
`stkhwm <pid> <hwm>/<size> @<base>`. It has to be: a lane member has exited by
the time the harness dumps the task table, so the table cannot say what base it
had. (The first cut read the base by pulling X back off the stack in the log
tail, where a saved X and an 8-bit mirror byte are both pushed -- it logged
`$6A38`/`$0000`/`$FF29`. The base is now stashed in a scratch cell where X is
known good.)

**Mutation-proven three ways, each hitting a different arm:** removing lane
admission entirely -> "only 0 lane member(s)"; placing the lane one page low ->
wrong base reported; one page high -> the machine breaks outright and the check
reports INCONCLUSIVE rather than passing.

**Membership units.** `TASK_STACK_LANE_MIN` is a **request** (the clamped stack
hint), while `_tas_npages` is the **guarded** count -- the guard page is added
before the test. The first cut compared the guarded count directly against the
knob, making the real threshold a request of 39 rather than 40. Harmless, since
the gap between the largest non-shell (vi, 22) and tcsh (74) is enormous, but
the constant lied about itself. `task.s` now compares against
`TASK_STACK_LANE_MIN+1` and `check_stack_budget.py`'s `lane_knobs()` matches.

**Note for whoever changes the lane geometry next:** it moves every big stack,
so `b3live`/`b3pty`'s hardcoded CONTROL taps go stale. They fail loudly rather
than quietly (that is what the TCB cross-check is for), and re-pointing them is
a two-line change -- but expect it. It happened on this very change: both failed
with `control: $5080 is OUTSIDE pid 6's live region $53D2..$5700`, naming the
region to re-point into.

### 4.2 B3.2 as designed -- swap EAGERLY at block, and the deadlock disappears

Two facts settled before writing any scheduler code.

**Banks are not the wall.** `BANK_USER_COUNT` is **56**, not the 22 the
`Bank_Alloc` comment implies. Three concurrent tcsh sessions cost ~33 banks
(3 x 8 for the images, 3 x 1 for their home copies, plus init/getty/sh), so the
image side of three shells fits with room. Bank 0 really is the only wall, which
is what the whole campaign assumed and had not actually checked.

**The home copy is a whole BANK** (`Bank_Alloc`), not a `Kmalloc` block: it is
bank-aligned at offset 0, so the swap is a plain `MVN` between bank 0 and the
home bank with no offset arithmetic. 21,504 of 65,536 bytes is wasted per
member; at 1 bank of 56 per member that is the cheap side of the trade.
Allocated at **admission**, never at eviction -- section 5's rule, and 2.11BSD's
out-of-swap `panic` is the counter-example.

**The design: swap OUT when a member blocks, IN when it is resumed.** The naive
alternative -- evict on demand when another member is picked -- has a deadlock
in it: if the resident is READY rather than blocked, a blocked-only policy may
not evict it, so the picked member can never run and the scheduler has to grow a
"can this task run right now" predicate.

Swapping out **at the moment of blocking** removes that entirely. A member is
only ever resident while it is running, so **the lane is always free when a
member needs to come in** -- restore never has to evict anything, and the pick
loop needs no new predicate. The swap-out happens in the member's own context
(at `_sleep`), and the swap-in on the resume path in `swtch`, so neither is ever
reachable from an interrupt -- section 5's third failure mode, taken from
2.11BSD's unsolved overlay-thunk races.

The cost of that simplicity is exactly what **B3.3** exists to fix: eager
swapping pays two 21.5 KB copies (~40 ms) per block/wake pair, i.e. per
keystroke for a shell sitting in `read()`. B3.2's gate says "no hysteresis" for
this reason -- get it correct first, then make it lazy.

### 4.2b The trigger, RE-DECIDED 2026-08-07: demand eviction at pick time

§4.2 chose **eager swap-out at block** for one reason: *"a member is resident
only while RUNNING, so the lane is always free when a member needs to come in --
restore never has to evict anything, and the pick loop needs no new predicate."*

**That justification is dead three ways**, and §4.3 found all three: the spawn
path (which is not a context switch), a preempted-but-READY resident (preemption
exists, so a resident can be off-CPU without ever blocking), and a live fork
borrower. Once swap-in has to handle "lane occupied" regardless, eager-at-block
is paying for a simplification it no longer buys.

**So the trigger is now: swap on demand, at pick time.**

1. `pick_next` chooses as it does today.
2. If the chosen task is a lane member and is not the resident, `swtch` evicts
   the resident (lane -> that member's home bank) and swaps the chosen one in.
3. Eviction is allowed iff the resident is **not running**, **not
   `SEF_STKLOCK`**, and **not `SEF_STKBORROW`**. Evicting a READY -- not merely
   blocked -- member is safe precisely because the swap is address-preserving,
   and §2.4 records that 2.11BSD's own fallback tier does the same.
4. If the resident cannot be evicted, the chosen member cannot run this round
   and the pick must skip it.

Point 4 is the predicate §4.2 wanted to avoid. **That claim is retracted**: the
borrower case forces a predicate whatever the trigger, so refusing one buys
nothing.

What the change buys:

- **The single-member machine pays nothing.** That is today's machine, and it is
  also a shell typing while it is the only member. Eager-at-block pays two
  21.5 KB copies per block/wake pair -- per *keystroke* for a shell in `read()`.
- **One mechanism covers block, wake and spawn**, instead of an eager path plus
  §4.3's separate spawn dance.
- **B3.3's hysteresis falls out for free**: "swap only when someone else actually
  needs the lane" IS the hysteresis, rather than a later optimisation bolted onto
  a policy that swaps unconditionally.

**BUILT 2026-08-07, and the trigger choice held up.** `b3swap` shows the
single-member case paying nothing and a contended pair swapping correctly. It
also exposed the cost deferred to B3.3 -- two RUNNABLE members ping-ponged on
nearly every context switch, 532 swaps in one run -- which **B3.3 has since
bounded** with a dwell time (§4.4). Eager swap-at-block would have paid a
comparable price on every keystroke instead, with no equivalent lever.

**Liveness.** A member that cannot get the lane is blocked by a resident that is
running, `SEF_STKLOCK`'d, or `SEF_STKBORROW`'d. In each case the task responsible
is itself runnable -- the borrowing child is executing, the lock holder is
mid-syscall -- so the machine makes progress and the blocked-out member gets in
once that finishes. This is an argument, not a proof, and it is the first thing
to attack if B3.2 wedges again.

### 4.3 B3.2 -- attempted 2026-08-07, REVERTED, and what it cost to learn

The machinery went in cleanly (home-bank lifecycle, `Lane_SwapOut`/`Lane_SwapIn`,
a self-patching `MVN` mirroring `_KZeroRegion`, admission wired into
`Task_AllocStack`, swap-out at `_sleep`, swap-in on `swtch`'s resume path). It
booted and passed `smoke`. It **wedges** on `tcsh -c 'tcsh -c ps'`, and the
reason invalidates a sentence of §4.2's design.

**THE SPAWNING TASK CAN ITSELF BE THE RESIDENT MEMBER.** §4.2 argued that "a
member is resident only while RUNNING, so the lane is always free when a member
needs to come in". True for the *scheduler's* resume path -- and false for the
*spawn* path, which is not a context switch at all. A shell spawning another
shell is a lane member, running, resident, and about to have
`_Loader_StageArgs` write the child's argv frame straight over its own live
stack.

So the one-resident invariant has two customers, not one, and only the scheduler
half is naturally safe. The spawn half needs an explicit dance:

1. `Lane_Admit` allocates the child's home bank and records membership, but must
   **not** hand over the lane; it parks the current resident (the parent) and
   remembers it.
2. `_Loader_StageArgs` writes the child's frame into the lane.
3. A new `Lane_PostStage` copies that frame out to the **child's own home bank**
   and restores the parent's bytes -- unless the staged task IS the current one
   (a member `exec`ing replaces its own image and simply keeps the lane).

The child then gets the lane from `swtch`, by which time its parent has blocked
in `wait()` and parked itself. Cost is four 21.5 KB copies per shell spawn
(~80 ms), which only B3.3's hysteresis reduces.

**The second trap, and it is the one that actually broke the boot.** Hooking
`Lane_PostStage` after `_Loader_StageArgs` means inserting code between a call
and the `BCS` that tests its result -- and `LDA`/`CMP` on the way to deciding
"is this a lane member" **clobber the carry**. Init's stack base is `$1900`,
`CMP #FGX_STK_LANE_BASE` cleared C, the `BCS` fell through into the failure arm,
and the machine died at `hello load failed: errno=$00` before the first prompt.
The hook has to save both the carry AND `A` (which holds StageArgs' `saved_S`).

Reverted at `0484e3229` so the tree stays green: `b3lane`, `smoke` and the suite
pass.

**And the hand-off above is necessary but NOT sufficient -- do not build it as
written.** An adversarial review on 2026-08-07 took the finding seriously enough
to ask what ELSE is a customer of the one-resident invariant, and found two more
of the same shape, both amended into §3.3:

- a fork/vfork child **borrows** its parent's bank-0 stack while the parent
  sleeps interruptibly, so the parent is an eligible victim while a running task
  executes on its bytes -- and pinning the parent collides with B3.0's `_sleep`
  assertion, so it needs a separate predicate;
- **`_Fork_Restore`** writes the parent's stack from the child's context at two
  unlocked call sites, while the parent is parked;
- and B3's own `_Tas_PaintStack` scribbles the entire lane at admission, *before*
  StageArgs, so parking must precede the paint rather than the staging.

Two further corrections to the design as written, from the same review:

- **§4.2's "eager swap at block means restore never has to evict" is dead.** It
  fails for the spawn path (this section), for a preempted-but-READY resident,
  and for a live borrower. Since swap-in must handle "lane occupied" regardless,
  eager-at-block buys nothing while costing two 21.5 KB copies per block/wake --
  per keystroke for a shell in `read()`. Demand eviction at pick time is one
  mechanism covering block, wake and spawn, and it is B3.3's hysteresis for
  free. Re-decide this before writing code, rather than carrying §4.2 forward.
- **The "unless the staged task IS the current task" exception is at the wrong
  layer.** Lane-occupied goes straight to ENOMEM with no fallback to the general
  pool (`task.s`, `@tas_noRoom`), so a member exec'ing a shell dies in
  `Task_AllocStack` before any `Lane_PostStage` exception could run. The
  distinction has to be made at ADMISSION, and it has four arms, not two: exec
  replacing my own image; a vfork child exec'ing the image whose stack it
  borrows; a member exec'ing into a NON-member (dissolve membership, free the
  home bank); and a non-member exec'ing into a member (`login` -> tcsh, the
  actual ttyv1 chain -- a fresh admission that may find another member resident).

Also unspecified and needed: **every rollback path.** `Task_FreeStack` knows
nothing about home banks, residency, or restoring the parent's bytes, and
StageArgs is not cleanly pre-write -- the `E2BIG` gate is, but `EINVAL` at
`argc > LSARGV_MAX` fires after strings are already on the lane. Each of the
alloc-failure arms, the StageArgs-failure arm, and "child killed before first
run" must restore the parent's bytes, free the child's home bank, and return
residency.

---

### 4.4 B3.3 as built: a dwell, and why a BLOCKED resident is exempt

A resident that is **blocked** cannot use the lane until it wakes, so it has no
claim on it: it is evicted immediately, exactly as before. The dwell governs only
a resident that is **runnable** and therefore still making progress.

That asymmetry is the whole design. It means the dwell never touches the
interactive path -- a shell waiting on a keystroke is blocked, so it hands the
lane over at once -- and is paid only when a member contends with a CPU-bound
peer, which is both rare and inherently slow anyway.

**The dwell is a time, not a switch count.** The cost being amortised is
wall-clock copying (~40 KB of MVN per hand-over), and the switch rate is not
something an eligibility predicate should have to model. It also doubles as the
anti-starvation bound with no second mechanism: a waiting member is delayed by at
most one dwell, after which the resident is evictable whatever it is doing.

**Measured, then chosen** -- the gate's wording, taken literally:

| dwell | lane swaps (b3thrash) |
|---|---|
| none | **532** -- a swap on nearly every context switch |
| 6 ticks (100 ms) | 208 |
| 12 ticks (200 ms) | **130 -- shipped** |
| 30 ticks (500 ms) | 47 |

12 is the balance point: past it the returns diminish while the waiter's latency
keeps growing.

**The measurement needed a workload that did not exist.** `b3swap`'s members
sleep, so the lane changes hands because the holder BLOCKS -- the case hysteresis
barely touches. `b3swap` gained a `spin` mode so both members stay RUNNABLE and
the scheduler alternates them on its own quantum; `b3thrash` runs two of those.
Mutation-proven: dwell 0 -> 532 swaps, exit 1; dwell 12 -> 130, exit 0.

**The swap count is read from the kernel BY SYMBOL** (`memory_regions` now
accepts `symbol:`, resolved from the assembler listing). Two reasons: a
hardcoded probe address goes stale and then reads a serene, wrong zero rather
than failing; and `_laneSwaps` is a true total, where counting `laneswap` lines
in the klog undercounts badly -- that ring is 1792 bytes and wraps long before a
spin workload ends.

---

## 5. Failure modes to design against

Taken from 2.11BSD's own scars, which are instructive precisely because they
shipped:

- **Out of swap is a panic** (`sys/vm_swap.c:107`) — 2.11BSD never reserves swap
  at fork. FGX must allocate the home handle **at lane admission**, not at
  eviction, so that running out is a clean spawn-time failure rather than a
  mid-run one.
- **`lock(2)` cannot honour its own promise** (`pdp/kern_pdp.c:71-74`) — a
  "locked in core" flag that the growth path can still override. If
  `SEF_STKLOCK` is not honoured on *every* path, it is worse than nothing.
- **Unsolved interrupt races in the overlay thunks** (`pdp/mch_csv.s:122-138`,
  *"There's very little that can be done about this"*) — the general warning is
  that a window-switch mechanism reachable from interrupt context breeds races
  that cannot be closed afterwards. B3's swap must be reachable only from the
  scheduler, never from an interrupt.
- **Fragmentation sheds resource silently** (`h/map.h:17-23`). FGX's lane is a
  fixed range precisely to avoid needing an allocator here.

And one from FGX's own scars rather than 2.11BSD's, learned three times in two
days and therefore worth stating as a rule:

- **Ask who USES a range, not just who WRITES it.** Every hole found in this
  design so far — the spawning task being the resident member (§4.3), the fork
  borrower, `_Fork_Restore`, the admission-time paint — is a customer of the
  one-resident invariant that is neither the scheduler nor the obvious writer.
  A survey organised around "who writes into a task's stack" cannot express "who
  is *executing on* this range right now", and that is the question an
  address-preserving swapper actually has to answer. Before adding any new
  swap trigger, enumerate every context that can hold, write, or run on the lane,
  and say for each whether it can occur while a member is PARKED.

---

## 6. What would make this not worth doing

Stated up front so the answer is not motivated later:

- If the `SEF_STKLOCK` survey (B3.0) finds paths that cannot be flagged — a
  pointer held across a sleep with no bounded window — then address-preserving
  swap is unsafe and B3 dies there.
- If the measured copy cost at B3.3 makes an interactive session perceptibly
  worse, the lane is not worth the pages.
- If tcsh's reservation falls far enough by other means (the five tracked items
  plus apple/fgx#42 are worth roughly 20 pages), three shells might fit without
  any of this. **That is the cheaper outcome and should be preferred if it
  arrives first.**
