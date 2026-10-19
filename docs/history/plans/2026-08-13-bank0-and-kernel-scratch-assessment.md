# Assessment plan: kernel scratch, bank-0 scarcity, and per-process stacks

**Status: PLAN ONLY.** Nothing here is a decision. The deliverable is a set of
measurements and a costed set of options; the design choice comes after.

Branch `assess/bank0-and-kernel-scratch`. Chartered 2026-08-13 after an
adversarial review of `_libcTmp2` found two live socket defects (apple/fgx#100)
and the maintainer asked the broader question: are we severely overloading kernel scratch
variables that should not exist, and can bank 0 be cleared enough to do this the
way BSD does?

---

## 0. What this is really asking

Three questions that look separate and are one:

1. **Scratch.** FGX has shared kernel direct-page scratch cells (`_libcTmp2` and
   friends). BSD has none. Ours are safe only where the code runs to completion,
   and #100 is what happens where it does not.
2. **Bank 0.** The reason the scratch exists is that there is nowhere else to
   put a transient: the kernel stack is one 256-byte page per task and the
   direct page is full. Both live in bank 0.
3. **Per-process stacks.** BSD's answer to (1) is that transients are automatics
   on a per-process kernel stack. FGX *has* per-process kernel stacks. The
   question is whether they can be made big enough to use that way, which is
   question (2).

So the assessment is: **measure bank 0 honestly, find out what BSD actually
reserves, and determine whether FGX can afford the BSD shape.**

### The CORE, and what is time-boxed around it

The phases below are not equal, and the reading-and-writing ones will absorb
the whole schedule if allowed to, precisely because **a document cannot come
back negative while a measurement can.** The core is the measurement spine:

| | core work | why it is core |
|---|---|---|
| **1** | the census, with the addressing-mode axis, seeded from sleep sites | tells us if #100 is a sample, and whether the BSD answer is even reachable |
| **2 + 2a** | the bank-0 map, **and the kernel-stack HWM probe** | the only source of FGX's actual requirement |
| **3.1-3.2** | `USIZE` from the oracle, split into struct-user vs stack | the reference number |
| **5** | costed options, including do-nothing | the deliverable |

Everything else is **time-boxed and may return "not reached"**: Phase 0's
165 KB, Phase 1b beyond GNO (GS/OS, ORCA, llvm816 are spot checks), and 4b's
eight prompts, which fold into Phase 5's option generation rather than standing
as eight essays. A time-boxed phase that runs out of time says so; it does not
borrow from the core.

**Gate 0 must be falsifiable.** Every "ruled out" row carries the command that
re-tested its grounds and the output that command produced. A row with a
narrative and no command has not been re-tested -- and *a check whose tool did
not run looks exactly like a pass.*

---

## 1. THE FINDING THAT SHOULD FRAME EVERYTHING

`vendor/2.11BSD/usr/sys/h/user.h:24-27`:

> *"The user block is USIZE*64 bytes long; resides at virtual kernel loc 0140000;
> **contains the system stack (and possibly network stack) per user**"*

**In 2.11BSD the u-area and the kernel stack are ONE allocation.** `struct user`
sits at the bottom; the kernel stack grows down from the top of the same block.
That is why `newproc` "copying the u-area" copies the stack with it, why the
whole thing is swappable as a unit, and why a BSD kernel routine can put a
transient in an automatic without anyone owning a custody rule.

**FGX has both objects, separately**: a heap-allocated u-area (`SE_UareaPtr`,
just extended for `u_cmask`/`u_rlimit`) and a bank-0 kernel stack page
(`SE_KernStkBase`, `FGX_STK_KTASKS`). They were built at different times for
different reasons and neither knows about the other.

**Whether to unify them is the central design question this assessment exists to
inform.** Do not prejudge it -- there is a real argument against (the u-area is
on the heap in a far bank, and a 65816 stack pointer is 16 bits, so the stack
*must* be in bank 0 and the two cannot literally share an allocation the way
they do on a PDP-11). Establish the facts first.

**The disanalogy this framing must carry with it.** What makes the unification
cheap on a PDP-11 is the MMU: the u-area is mapped at ONE fixed kernel virtual
address (`user.h:25`, *"resides at virtual kernel loc 0140000"*), so every
routine reaches the current process's u-area and stack through the same address
regardless of which process is current. **FGX has no MMU and can never have that
property.** So the transferable part of 2.11BSD is not the unification -- it is
the two properties underneath it: **enough stack depth** to hold transients, and
**an addressing mode that can reach them**. FGX already has the third property
BSD relies on (a per-process kernel SP, switched at context switch,
`task.s:1163-1167`). Phase 5 must chase depth and addressing, not the shape.

---

## 2. Phase 0 -- Read the prior art as INPUT. It does not bind this assessment.

**The maintainer, 2026-08-13, explicitly: prior art can inform, but it does not guide or
limit.** Nothing below is settled. Every conclusion in those documents is
re-openable, and a conclusion that was correct under the constraints of the time
is not automatically correct now -- the u-area exists since then, the module
system exists since then, and three subsystems have left the core bank.

| doc | size | what it is |
|---|---|---|
| `docs/history/plans/bank0-stack.md` | 52 KB | the campaign design |
| `docs/history/plans/b3-stack-swap-scope.md` | 64 KB | the address-preserving swap scope |
| `docs/history/audits/bank0-stack-status.md` | 39 KB | current numbers, live co-residency |
| `docs/history/audits/bank0-stack-baseline.md` | 10 KB | measured baseline |

Read them for: what was measured, what was tried, what failed and **why** --
the failure reasons are the valuable part, because a failure caused by a
constraint that no longer holds is an opportunity, not a closed door.

**Gate 0** is a summary in three columns: what they measured (re-measure it),
what they concluded (treat as a hypothesis), and **what they ruled out and on
what grounds** (re-test the grounds). Explicitly list any conclusion that rested
on something since changed.

One example already visible: FGX rejected `NewHandle`'d bank-0 pages for stacks
after a crash at `$BBxx` (`task.s:1174-1177`) and went to a static arena. **GNO
allocates every process stack with `NewHandle` and it works** (see Phase 1b). So
that rejection is a hypothesis about a specific bug, not a law -- and it is
exactly the kind of thing Gate 0 must surface for re-testing rather than inherit.

**Do not quote their numbers.** `bank0-stack-status.md` says so itself: *"RUN
THE TOOL rather than quoting this -- not quoting it is what let #30 sit."*

---

## 2b. Phase 1b -- LOOK OUTSIDE. Same hardware, same problem, different answers.

The gs-mcp corpus indexes **62 repositories**, including two systems that solved
precisely this problem on precisely this CPU:

- **`gno_kern` / `gno`** -- GNO/ME, a UNIX-like multitasking kernel for the
  IIgs. 1,431 files. The closest comparable system that exists.
- **`iigs_system_601`** -- Apple's own GS/OS kernel source, 1.38 M lines.
- **`orca_c` / `orcalib`** -- the ORCA runtime's stack and DP conventions.
- **`llvm816`** -- a modern 65816 compiler's frame model.

### The finding that already changes the shape of the question

`gno/sys.c:594-619`, GNO's `commonFork`:

```c
newID = GetNewID(0x1000);
fstack = NewHandle((long)stackSize, newID | 0x0100, 0xC105, NULL);
...
dPageAddr = (word)*fstack;      /* <-- the DIRECT PAGE comes from the STACK block */
buffSize  = stackSize;
```

**GNO allocates ONE bank-0 block per process and uses it as both the direct page
and the stack** -- direct page at the base, stack growing down from the top --
obtained from the Memory Manager with the bank expressed as an *attribute*
(`$C105`).

That is the same unification 2.11BSD does with the u-area and kernel stack
(section 1), arrived at independently, **on this exact CPU, under this exact
16-bit-stack-pointer constraint.**

### Two corrections to that reading -- verified 2026-08-13, do not repeat them

1. **GNO's sizing is NOT on demand.** `stackSize` comes from ORCA's per-binary
   `#pragma stacksize`, a compile-time constant baked into each program: 512 in
   `bin/ps/ps.c:28`, 1024 in `bin/ls/ls.c:21`, 1280 in `bin/less/main.c:5`, 2048
   in `bin/vi/main.c:10`. That is **the same static per-binary hint FGX already
   has** in its FGX2 header page count. Only the *allocator* is dynamic. Any
   claim that GNO sizes stacks on demand is false, and 4b.2 must not rest on it.
2. **It is the USER stack, which GNO's kernel calls borrow -- not a dedicated
   kernel stack.** So GNO's 1024-byte default compares to FGX's **user** stack
   reservation in `FGX_STK_ARENA`, *not* to FGX's 256-byte kernel page. Compared
   against the wrong object it makes the gap look 4x smaller than it is.

**Rule for Deliverable 1b:** before any number is compared, state which of
FGX's four objects the reference system's block corresponds to. A number
compared across two different objects is worse than no number.

FGX currently has FOUR separate per-process objects:

| object | where | how sized |
|---|---|---|
| direct page | fixed pid-indexed block, `$B400` | one page |
| kernel stack | fixed pid-indexed block, `$0C00` | one page (`k<<8`) |
| user stack | `FGX_STK_ARENA`, first-fit | static worst-case reservation |
| u-area | far-bank heap | 116 B |

**Both reference systems keep together what FGX has split apart.** Whether that
convergence is a coincidence of their eras or a property of the problem is a
question this assessment must answer, not assume in either direction.

### What Phase 1b must produce

1. **GNO**: how are stacks sized, allocated, freed, and what happens on
   exhaustion? Does it swap? How does it handle the DP+stack block crossing a
   page or bank boundary? What does `$C105` actually request, and does the
   Memory Manager guarantee bank 0?
2. **GS/OS**: how does Apple's own kernel place per-process/per-call state in
   bank 0? It has the same constraint and a decade of production hardening.
3. **ORCA / llvm816**: what frame model does each use, and what does it assume
   about DP? FGX's fcc treats DP as a register file -- do they, and what does
   that cost them?
4. **The failure modes**: what do these systems do when bank 0 fills? That
   answer is worth more than their happy path.

**Deliverable 1b:** a comparison table -- FGX / GNO / GS/OS / 2.11BSD -- across
per-process block layout, sizing policy, allocator, exhaustion behaviour, and
scratch discipline. Plus a list of techniques worth stealing.

---

## 3. Phase 1 -- The scratch census

**Question:** how many shared kernel scratch cells are there, who uses them, and
which uses are safe by what argument?

Method:

1. **Enumerate the cells**, not just `_libcTmp2`. Start from `include/dpmap.s`
   and classify every direct-page cell as: per-task state, subsystem state, or
   *shared transient scratch*. The third class is the subject.
   Known members so far: `_libcTmp2`, `_fsTmp0/1`, `_libcTmp0/1`, `_shTmp0`,
   `_sockTmp*`, `_pipeRec*`. **The list is an output, not an input.**
2. **For each cell, every live range**: from the store that establishes it to
   the last dependent read.
3. **Classify each range** by what makes it safe:
   - **RTC** -- run-to-completion; nothing in the range sleeps or yields.
   - **SAVED** -- the range crosses a sleep but the cell is saved/restored
     (e.g. `_BlkCache_PinGet`, `blkcache.s:788`).
   - **ENFORCED** -- an RTC range in a file covered by
     `tools/check_fs_sleep_invariant.py`, so the build fails if it ever sleeps.
   - **UNSAFE** -- crosses a switch unprotected. #100's two socket paths.
4. **Record the ADDRESSING MODE of every cell.** This is the axis that decides
   whether the BSD answer is even available, and it is not about lifetime at
   all. **The 65816 has stack-relative (`sr,S`) and stack-relative indirect
   indexed (`(sr,S),Y`), but NO stack-relative indirect LONG mode.** A 3-byte
   far pointer dereferenced as `[dp]` or `[dp],Y` -- which is exactly what
   `_libcTmp2` is (`LDA [_libcTmp2]`, `syscall.s:141`; `STA [_libcTmp2],Y`,
   `net_xport.s:443-464`) -- **has no automatic-on-the-kernel-stack equivalent
   at any stack size.** Mark such cells **DP-IRREDUCIBLE**: no amount of bank-0
   recovered changes their answer, and Phase 4 must never route them to the
   stack. This is the #100 cell, so it is the majority of the motivating case.
5. **Record which cells IRQ-time code touches.** Interrupt handlers run on the
   same per-task kernel stack (Phase 3c) and can land between the store and the
   read of an RTC range. An RTC classification is only safe against *task*
   switches; #91 (a driver's scratch cell WAS `_blkNumHi`) is the precedent.
6. **Count them.** The adversarial review found ~694 uses across ~25 files. The
   number that matters is not uses but *ranges*, and of those, how many are
   ENFORCED versus merely RTC-by-inspection.
7. **Bound kernel re-entry per task.** The dispatcher computes the kernel stack
   top for pid k directly from `_curTask` (`task.s:1165-1172`) and `TCS`es to
   it, so a second kernel entry while that task already holds live kernel frames
   would reset S onto them. Enumerate the kernel entry points and either show
   each is non-reentrant per task or state the bound. **This bounds what a
   fixed-top per-task stack can EVER support, at any size**, so it belongs
   before any sizing work.

**Method note -- do not walk 694 sites.** Seed the census from the *sleep and
yield call sites*, walking backwards to find which ranges reach them. The
population of interest is ranges that cross a switch, not uses.

**Prerequisite (moved here from Phase 5).** `tools/check_fs_sleep_invariant.py`
covers 9 FS files. `net`, `sock`, `pipe` and `pty` -- where #100 lives -- are
uncovered, so classifying their ranges by hand is exactly the manual asm walk
this phase cannot afford. **Extend sleep-reachability over those files first**;
it is the tool that makes the census tractable, and costing it inside Phase 5's
do-nothing option was an ordering inversion.

**Deliverable 1:** a table of cells x ranges x {safety class, addressing mode,
IRQ-touched}, with the UNSAFE, unenforced-RTC and DP-IRREDUCIBLE rows called
out. This is the risk register for the whole question, and it is what tells us
whether #100 is an outlier or a sample.

**Gate 1:** every UNSAFE range is either filed as a defect or shown to be
unreachable.

---

## 4. Phase 2 -- The bank-0 inventory

**Question:** what is in bank 0, why is each thing there, and what pins it?

The 65816's stack pointer is 16 bits, so **every hardware stack must be in bank
0**. That is a hardware fact and the floor under everything else. What is *not*
forced is everything else that has accumulated there.

Method:

1. **Run the existing tools rather than reading their old output**:
   `tools/check_stack_budget.py`, `tools/ninja/genconfig.py`,
   `tools/stack_reach.py`, and whatever `bank0-stack-status.md` names.
2. **Build a complete map**: every region in `include/memmap.s` and
   `include/kernel.s` with base, size, what it holds, and -- the important
   column -- **why it must be in bank 0**. Expected categories:
   - **HARDWARE-PINNED**: task hardware stacks (16-bit SP), interrupt vectors,
     the bank-0 gateway (`MOD_JT_BASE`, fixed by construction), direct page.
   - **FIRMWARE/BOOT-PINNED**: boot area, stage-2 buffers, ROM scratch.
   - **CONVENTION-PINNED**: things placed in bank 0 because it was convenient
     or historical, with no hardware reason. **This is the recoverable set and
     finding it is the point of the phase.**
3. **Note the transient overlaps.** `FGX_STK_KTASKS` sits over stage-2's
   `DIR_BUF`/`IDX_BUF`/`CONF_BUF`/`PATH_BUF` because those are boot-only. Any
   growth plan has to respect or re-plan those overlaps.
4. **Measure live occupancy, not reservations.** The status doc's own example:
   119 of 156 arena pages live with two consoles, against a 123/154 worst case.
   Reserved-but-untouched is the recoverable headroom, and it is the difference
   between a static reservation and a working set.
5. **Include `tools/check_bank0_geometry.py`.** It is the tool that pins the
   derived ladder (`FGX_STK_KTASKS`, `FGX_DP_KTASKS`, the stage2 alias) and the
   earlier draft of this charter did not name it.

### 2a. PREREQUISITE -- measure FGX's own kernel-stack high-water mark

**Nothing in FGX measures how deep the kernel stack actually goes, and Phase 5
cannot answer its headline question without it.** What exists today is a
*binary overflow* signal, not a depth measurement: `Task_AllocKernStack` zeroes
the 256-byte page and seeds a `$C5C5` canary in the bottom word
(`task.s:1204-1214`), and the dispatcher checks that canary on entry
(`syscall.s:181-186`). That fires only when a task has **already run past the
bottom** into its neighbour. It says nothing about whether the true peak is
40 bytes or 250.

Every tool Phase 2 names is static or user-stack-only:
`tools/check_stack_budget.py` sums **user**-stack header pages in
`FGX_STK_ARENA`; the runtime `stkhwm` instrument (`task.s:1857`,
`tests/mame_test/tests/stkhwm.json`, `psstack.json`) is likewise user-stack.

**The delta FGX must find is (FGX's measured kernel-stack need) - 256 B, not
(2.11BSD's `USIZE`) - 256 B.** Phase 3's number alone cannot answer "is 256 B
enough"; it only says what a different machine chose.

Build the probe, then measure:

1. **Fill, don't zero.** Seed the page with a distinctive pattern at
   `Task_AllocKernStack` instead of zeros -- a zero word is indistinguishable
   from a legitimately pushed zero, so the current fill cannot measure depth
   even if something scanned it.
2. **Scan from the bottom** at task exit and at a `ps`-style probe point; report
   the first byte still holding the pattern. That is the HWM.
3. **Report it like the user-stack `stkhwm`** -- the pattern already exists, so
   this is replication, not invention.
4. **Measure under load, including IRQ.** Interrupts land their frame plus
   handler depth on the same page (Phase 3c moved both syscall and IRQ handling
   onto per-task kernel stacks). The static call-graph sum is only a **floor**;
   an unmeasured IRQ margin is the difference between a safe number and a
   plausible one. Run the suite, plus a net-loaded case, plus whatever raises
   interrupt frequency.

**Gate 2a:** an HWM number per call path, with the IRQ margin stated
separately. Without this the assessment can compare FGX to BSD but cannot say
whether FGX needs what BSD reserves.

**Deliverable 2:** a bank-0 map with a `pinned-by` column and a recoverable-bytes
estimate per region, ranked by (bytes recovered / risk). Plus a **4 objects x 4
events** table -- direct page, kernel stack, user stack, u-area against fork,
exec, exit, slot reuse -- recording what happens today. Every unification or
pooling option in 4b is costed by lifecycle events, and without the current
baseline those costs are guesses. (Known starting points: a fork child borrows
its parent's user stack; #49 is the exec case where a guard measured the old
stack in the new bank.)

---

## 5. Phase 3 -- What BSD actually reserves

**Question:** what is the real per-process cost in 2.11BSD, and is it a target
FGX could meet?

1. **Get `USIZE` from the oracle.** The definition is not in the vendored
   subset -- it is machine-dependent -- but a live 2.11BSD PDP-11 is reachable
   (`tools/pdp11.exp`, see `reference_fgx_pdp11_bsd_oracle_access`). Read it
   from the running system's headers. **Measure, do not infer** -- the whole
   "how much does BSD reserve" question turns on this number and a guess would
   poison the comparison.
2. **Decompose it**: of `USIZE*64` bytes, how much is `struct user` and how much
   is left for the stack? That split is the number FGX would have to match.
3. **Establish what BSD spends it on** by *static* call-graph depth over
   `vendor/2.11BSD/usr/sys`, plus what it puts in automatics --
   `copyin`/`copyout` are the specific case that matters, since that is the
   mechanism FGX open-codes. **Do not attempt to measure a live kernel's stack
   depth over the oracle.** Access is expect+telnet to a user `tcsh`
   (`reference_fgx_pdp11_bsd_oracle_access`); there is no path from there to a
   running kernel's stack, so a dynamic ask here would be satisfied by prose --
   the vacuous-deliverable failure class this charter is trying to avoid.
   Reading `USIZE` from the oracle's headers (items 1-2) IS feasible; this item
   is static analysis of the vendored tree.
4. **Compare like with like.** FGX's kernel stack is 256 B/task. Its u-area is
   116 B (44 + 72 after `u_rlimit`). BSD's combined block is the honest
   comparison, not the stack alone. **And BSD's number is the reference, not the
   requirement** -- the requirement is Phase 2a's measured FGX HWM plus its IRQ
   margin. Report both; where they disagree, say which one a decision should
   rest on and why.

**Deliverable 3:** a table -- 2.11BSD u-area bytes, stack bytes, combined, per
process; FGX's equivalents; FGX's *measured* need from Phase 2a; and the delta
FGX would need to find *per task*, multiplied by `NPROC`.

---

## 6. Phase 4 -- Where could things go?

For each recoverable region from Phase 2 and each scratch cell from Phase 1,
evaluate against these destinations. **The charter explicitly asks about all of
them, including swap.**

| destination | good for | cost / risk |
|---|---|---|
| **kmalloc/heap (far bank)** | large, long-lived, not stack-addressed | far pointers; bank-crossing; the VFS pools already did this successfully (~7.5 KB) |
| **per-process kernel stack** | short-lived transients, BSD's own answer | costs bank 0 at 256 B x NPROC per page of stride; needs the `(k<<8)` stride change |
| **the u-area** | per-process state of any size | already heap; already inherits; already proven to grow cheaply |
| **another bank entirely** | code, tables, module-local data | the module campaign's proven route -- pty, net, vfs all left the core bank |
| **swap in/out of bank 0** | stacks of blocked tasks | B3 already scoped this and narrowed it to a console lane -- **read that before re-opening it** |
| **per-task kernel DP** | shared scratch cells, wholesale | see below -- the cheapest wholesale fix, and it was missing from this table |
| **delete it** | reservations nothing uses | the cheapest bytes are the ones nobody needed |

### The destination this charter had omitted: give the KERNEL a per-pid DP

The pid-indexed DP block already holds pids 0..NPROC, where **`pid 0` is the
single shared kernel DP** (`kernel.s:459`) -- and that is the page `_libcTmp2`
lives on, at offset `$54` (`dpmap.s:140`). The per-task DP pages next to it are
for user tasks.

So the shared-scratch problem has a shape nobody costed: **make the kernel's
scratch region per-pid too** (switch `D` at kernel entry, or pid-index the
kernel DP the way tasks already are). Its properties are the ones every other
destination fails:

- **Zero changes at the ~694 sites.** The cells keep their DP offsets.
- **Preserves `[dp]` addressing**, so it is the only destination available to
  the DP-IRREDUCIBLE class from Phase 1.
- **Preserves module reachability** -- a DP touchpoint is free to a module.
- **Costs the currency this charter already trades in**: bank-0 pages, at the
  same price as one more kernel-stack page per task.

Cost it honestly, including the arguments against. `FGX_DP_KERNELC` was made a
singleton deliberately, on the reasoning that a per-pid file "only buys
something once kernel C can sleep" (`kernel.s:498-501`) -- **that reasoning is
about kernel C's register file, and the asm scratch case is different, because
asm kernel code demonstrably does sleep. That is #100.** Note also that the
block is pinned: it ends at `$C000` and holds exactly `NPROC+1` pages, so more
pages come out of `FGX_STK_ARENA`.

### The column every destination needs: module reachability

`net`, `pty`, `vfs` and `pipe` are loadable modules in their own banks, and
**DP is the one addressing mode that is free to them**. An absolute kernel-bank
cell needs `LDAL` plus a `wavee_bankpatch.s` entry, and an unregistered `LDAL`
bakes bank `$02` -- the RAM disk. #100 itself lives in a module. A migration
costed without this column is systematically wrong for exactly the subsystem
that motivated the assessment.

**Deliverable 4:** each candidate assigned a destination with a cost, or marked
immovable with the reason -- with a **"reachable from module banks, at what
cost?"** column on every row.

---

## 6b. Phase 4b -- Think outside the box, deliberately

The destination table in Phase 4 is a list of places FGX already knows about.
This phase exists because the charter asks for **novel and elegant** approaches,
and a table of known destinations will not produce one. Run these as explicit
prompts, each requiring a written answer even if the answer is "no":

1. **Unify what is currently four objects.** Both reference systems put the
   process's addressing state and its stack in ONE block. What would an FGX
   per-process block look like -- DP + kernel stack + u-area, one allocation,
   one lifetime, one inheritance copy? What breaks? (The u-area being in a far
   bank is the obvious objection; note that GNO's equivalent is in bank 0
   precisely because the DP must be.)
2. **Question the fixed pid-indexed layout.** `(k<<8)` and the DP block are
   static reservations sized by `NPROC`, so a system with 3 live tasks reserves
   for 9. GNO allocates its per-process block from the Memory Manager at fork.
   What does FGX's static layout buy that is worth the reservation? (It buys
   O(1) addressing with no indirection -- say what that is worth in measured
   cycles before defending it.) **Note the correction in Phase 1b:** GNO's
   *sizing* is a compile-time `#pragma stacksize` per binary, so the contrast
   is allocator-vs-allocator, not dynamic-vs-static sizing. FGX's FGX2 header
   page count is the same kind of hint.
3. **Question the worst-case stack reservation.** A task holds its deepest
   static call-graph depth for its whole life. That is a whole-life reservation
   for a peak that may occur for microseconds. What would demand growth cost --
   and is the reason it was rejected still true? **Boundary condition:**
   `tools/check_stack_budget.py` states that the arena can never be compacted,
   because fcc frames hold absolute bank-0 addresses and stacks therefore
   cannot be relocated. Growth-by-relocation is off the table without fcc
   changes; say so rather than re-deriving it.
4. **Re-test the `NewHandle` rejection.** FGX has a static arena because a
   `NewHandle`'d bank-0 page crashed at `$BBxx` for handler stacks. GNO does
   this successfully for every process. Find out what the actual failure was --
   a Memory Manager attribute, a locking bug, an interrupt-time constraint --
   and whether it applies to non-handler stacks at all. **Same boundary
   condition as (3):** only fixed-and-locked MM blocks are in play, since a
   movable block would relocate stacks that hold absolute addresses.
5. **Does every task need a kernel stack at all times?** Only a task inside a
   syscall is using one. With N tasks and a bounded number simultaneously in the
   kernel, kernel stacks could be a POOL claimed at syscall entry rather than a
   per-task reservation. What bounds the number of tasks simultaneously in the
   kernel? (Sleeping ones hold theirs; that is the hard part -- but the count of
   sleepers may be far below NPROC.)
6. **Invert the scratch problem.** Instead of finding a home for transients,
   ask why so many exist. `_Sys_Ioctl` needs `_libcTmp2` because a syscall must
   reach a caller buffer in another bank. **One `copyin`/`copyout` primitive
   would need exactly one scratch cell** -- the count of cells is a symptom of
   N handlers each solving the same problem locally.
7. **Is bank 0 the only 16-bit-addressable space?** The stack pointer is 16-bit
   and bank-0-relative, but the direct page register can point anywhere in bank
   0, and `MVN`/`MVP` cross banks freely. Enumerate precisely which operations
   force bank 0 and which are convention -- the answer bounds everything else.
8. **What would we do with 8 KB of bank 0?** Ask the question backwards: if the
   audit recovered a large block, what is the best thing to spend it on? If the
   answer is not "bigger kernel stacks", then bigger kernel stacks may not be
   the goal and the scratch problem wants a different solution.

**Deliverable 4b:** a written answer to each, with the ones worth pursuing
promoted into Phase 5's options. **An idea rejected here must record WHY**, so
the next assessment inherits the reason and not just the rejection -- which is
the failure mode Phase 0 exists to correct.

---

## 7. Phase 5 -- Synthesis

**Deliverable 5:** two or three costed options, each stating:

- bank-0 bytes recovered;
- what per-task kernel stack size it buys;
- whether that size is enough for **FGX's measured need** (Phase 2a's HWM plus
  its IRQ margin), with 2.11BSD's reservation reported alongside as reference;
- which scratch cells it lets us delete outright, and which remain -- **and how
  many of the remainder are DP-IRREDUCIBLE**, since those cannot be solved by
  any amount of stack;
- the migration cost in sites touched, and the risk of touching them;
- **the code-size delta against the 64 KB segment ceiling.** `dp -> absolute`
  costs +1 byte per site and `dp -> long` +2; across up to 694 sites that is
  ~0.7-1.4 KB of kernel growth in a segment with a history of ceiling
  incidents. An option that is cheap in sites can be dead on arrival in bytes;
- what enforcement (checker) makes the result stick.

**A "do nothing structural" option is required**, costed the same way: fix #100
at the choke point, extend the sleep checker to the net layer, and leave the
architecture alone. It may well win on risk-adjusted value, and the assessment
is not honest unless it is on the table.

---

## 8. Standing constraints

- **The maintainer, 2026-08-13:** stack space is HIGHLY impacted; direct page is FULL.
  Neither is a home for a temporary. Any proposal that spends either must say
  what it displaces.
- Bank 0 was compacted on 2026-08-06 and the kernel-stack block right-sized from
  16 pages to 11. **Assume the easy wins are gone** and that anything found is
  either subtle or costly.
- `kernel.nproc` is the master knob: every slot costs 2 arena pages, and the
  build already errors at 13 (apple/fgx#45). Bank-0 changes interact with it.
- The 64 KB per-segment cliff bounded a previous increment (bank-0 stack 1.2 was
  blocked by it). Any code motion has to be measured against it.

## 9. What this assessment will NOT do

- It will not implement anything. Phase 5 ends at costed options.
- It will not re-derive the B3 campaign. Phase 0 exists to prevent that.
- It will not touch UFS. That campaign is paused at 1.2, owing only the fileops
  vector, and `docs/history/RESUME-2026-08-13-*` carries its state.

## 10. Open on entry

- apple/fgx#100 -- the two socket paths. **Fixing it does not depend on this
  assessment** and probably should not wait for it; the choke-point fix is ~15
  lines in `_Sock_PollIntr`. Decide separately whether to land it first.
- MR !153 (`u_rlimit`) is open and gate-green, unaffected either way.
