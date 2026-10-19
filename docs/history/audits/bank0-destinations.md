# Deliverable 4 -- where could things go?

Phase 4 of the bank-0 / kernel-scratch assessment
(`docs/history/plans/2026-08-13-bank0-and-kernel-scratch-assessment.md`).

Phases 1-3 closed the obvious destination. This phase asks what is left.

---

## 0. What Phases 1-3 already removed from the table

| finding | consequence |
|---|---|
| No stack-relative indirect **long** mode on the 65816 | 33 cells / **2,276 sites** can never be stack automatics |
| Kernel stacks measured ~**62 of 256 bytes** used | nothing is asking for a bigger stack |
| BSD shape needs **46.5 KB** at `NPROC+1`=12 | more than all of bank 0's current claims |

**The kernel stack is not a destination.** Everything below assumes that.

## 1. The column the charter was missing: can a module still reach it?

`net`, `pty`, `vfs` and `pipe` are loadable modules in their own banks. This
decides more than cost -- it decides feasibility.

| destination | reachable from a module bank? | cost |
|---|---|---|
| kernel **direct page** | **yes, free** -- DP is bank-independent | none |
| absolute kernel-bank static | yes, but needs `LDAL` **and** a `wavee_bankpatch.s` entry | +1 B/site; an unregistered `LDAL` bakes bank `$02`, the RAM disk. A *dereferenced* pointer also pays a stage-into-DP copy per use (section 2) |
| kmalloc heap (far bank) | yes, via a long pointer -- **which must itself live in DP** | circular for the pointer itself |
| per-task kernel stack | yes | **unavailable for far pointers**, see above |
| another module's bank | no | -- |

**apple/fgx#100 lived in a module.** A destination table without this column is
systematically wrong for exactly the subsystem that motivated the assessment.

## 2. The trap: DP-IRREDUCIBLE cells cannot go to absolute either

The census's DP-IRREDUCIBLE class was defined by "cannot become a stack
automatic". The same instruction-set gap closes the other exit: **there is no
absolute-indirect-long-indexed addressing mode**. `[dp],Y` requires the pointer
to be *in the direct page*.

So a cell dereferenced as `[cell],Y` cannot be *dereferenced* from the stack or
from an absolute static.

**Stated precisely, because the strong form is wrong:** the pointer's storage
can live anywhere. What cannot move is the *dereference* -- at the moment of
`[ptr],Y` the pointer must be in the direct page. A far pointer parked in an
absolute static is therefore reachable, at the cost of **staging it into a DP
slot before each use**. That is not a hypothetical: it is what the kernel
already does, and the staging slot is `_libcTmp2`. Moving a cell to absolute
without removing its dereference just renames the problem and adds a copy.

So the remaining solution space for those 2,276 sites is:

1. **give the pointer a different direct page** (section 3),
2. **remove the need for the pointer** (section 4), or
3. **keep a staging slot but make it provably safe** (section 5) -- which is
   what the choke-point saves already do.

## 3. Option A -- a per-task kernel direct page

**The mechanism already exists and costs almost nothing.** The dispatcher
already swaps `D` on every syscall (`syscall.s:92-95`):

    TDC                          ; A <- D
    STA     _Sys_UserDP          ; save caller's DP
    LDA     _kFgxDPKernel        ; the single shared kernel DP page
    TCD

Making it per-task means replacing one load with a pid-indexed computation --
roughly five instructions, ~10-15 cycles per syscall entry, and **zero changes
at any of the 3,744 use sites**. Every cell keeps its DP offset, `[dp],Y` keeps
working, and modules keep free access. Nothing else on the table has that
property.

### What it costs

| item | cost |
|---|---|
| bank 0 | `NPROC+1` = 12 pages = **3,072 B** |
| syscall entry | ~5 instructions, ~10-15 cycles |
| use sites touched | **0** |

Phase 2 found 2,354 B recoverable, so this is ~718 B short on its own and would
have to take the difference from the arena's 30 reserved-but-unused pages.

### THE BLOCKER: the kernel DP is not all scratch

`D` moves the whole page. There is no way to make half a direct page per-task.
And measured by region, the kernel DP is a mixture:

| region | cells | sites | per-task safe? |
|---|---:|---:|---|
| `$00-$1F` fs/block transients | 8 | 436 | yes |
| `$20-$4F` heap pointers, boot-established | 14 | 375 | yes -- replicate at boot, all copies identical |
| `$50-$9F` libc scratch, printf, allocator | 36 | 1,426 | yes |
| `$A0-$AF` scheduler globals + table ptrs | 5 | 248 | **mixed** |
| `$B0-$BF` log / tty / pick_next / `_shTmp*` | 7 | 338 | mixed |
| `$C0-$EF` **console state + scratch** | 26 | **742** | **NO** |
| `$F0-$FF` block trampoline, table ptrs | 10 | 179 | yes -- boot-established |

Most of it is fine. The boot-established base pointers (`_schedTblPtr`,
`_sockTablePtr`, `dev_table_ptr`, ...) are written twice at boot and identical
for every task, so twelve copies are twelve correct copies. `_u` is *better*
per-task, since it points at the current task's u-area by definition.

**The console is the blocker.** `$C0-$EF` is one device's persistent state --
cursor row and column, top row, colours, render mode. Twelve tasks writing to
one console must share one cursor. Per-task copies would be wrong, not merely
wasteful. Same for `_curTask` and `_nReady` in the scheduler group.

And per section 2, moving the console to absolute statics does not help:
`_conFontPtr` (38 sites) and `_conScratch6` (24) are DP-IRREDUCIBLE and
`_conStrPtr` (110) is `(dp),Y`, so each would need staging back into a direct
page at every dereference. The console belongs on *a* direct page.

> **CORRECTION, 2026-08-13 -- the band is three things, not one, and only 16
> bytes of it were ever the blocker.**
>
> "One device's persistent state" was measured as one 48-byte block because it
> sat in one contiguous run. Split by who actually touches each cell:
>
> - **`$C0-$CF`, 16 B, 192 sites -- the only genuinely shared part**, and not
>   shared the way this section said. It is **per-VC**: `console_switch.s` was
>   already saving and restoring the whole run on every virtual-console switch.
>   Not "twelve tasks share one cursor" but "three consoles each own one".
> - **`$D0-$DF` + `$E2-$EF`, ~370 + ~160 sites -- console-internal scratch**,
>   live only within one console call. Per-task is *correct* for these, not
>   merely tolerable: a task that sleeps mid-console-op holding one is the
>   apple/fgx#100 shape.
> - **`$E0` `_conStrPtr`, 106 external sites -- an ARGUMENT cell.** The caller
>   stages it and calls the console; caller and callee are the same task, so
>   per-task is correct here too.
>
> The 16 shared bytes have since moved to `CON_VT_STATE` (a far-bank absolute
> block the VC switch already copied), so **the console no longer blocks the
> kernel DP from becoming per-task at all**. The DP-IRREDUCIBLE argument above
> still stands for `_conFontPtr` / `_conScratch6` / `_conStrPtr` -- and is now
> moot, because those three are in the per-task-safe groups.
>
> **What it cost, and the general lesson:** a direct-page access is bank-immune;
> an absolute one is DBR-relative. Four reads of `VT_FG`/`VT_BG` sat immediately
> after an `MVN`, which leaves DBR on the destination bank -- correct for years
> as DP cells, wrong the moment the datum moved. Only a golden-hash test
> (`coninv`) saw it. `check_kc_dbr.py` now gates that bracket.

> **BLOCKER #2, found 2026-08-13 while implementing: THE SCHEDULER GROUP, and
> it is the harder one.** With the console resolved, the next thing in the way
> is not a band of cells -- it is `swtch` itself.
>
> **A per-task `D` has to be selected by pid, and the pid lives in the page
> being selected.** `_curTask` is DP `$9E`. The dispatcher must know it
> *before* the `TCD`, so it cannot come from the page the `TCD` is choosing.
>
> A cheap reading was tested and fails: if each page's `_curTask` simply held
> that page's own pid, all 180 "who am I" reads stay correct without moving
> anything. But `sched.s:301-303` writes `_curTask` = the **incoming** pid and
> then derives `_fsCwdPtr` (another DP cell) from it, **while still running on
> the outgoing task's page**. The switch straddles the `D` change, so per-page
> copies do not compose with the one routine that has to see both tasks at
> once.
>
> Measured sizes for the genuinely-global cells:
>
> | cell | sites | files | note |
> |---|---:|---:|---|
> | `_curTask` | 180 | 17 | 6 in module banks + 1 in the far console bank, so those need `LDAL` + a bankpatch entry |
> | `_kTtyRdPtr` | 63 | 2 | both core-bank |
> | `_schedLastSlot` | 5 | 1 | |
> | `_nReady` | **0** | 0 | **declared and never used** -- delete it |
>
> `_pnBestPri` and `_pnScan` are safe per-task: they are live only within a
> single `pick_next` pass, which runs to completion.
>
> **This corrects the charter's cost.** Option A was costed as "about five
> instructions and zero use-site churn." It leaves the 3,744 use sites alone,
> but only after ~440 sites are moved OUT of the direct page first as
> prerequisites -- 192 for the console (done, !159) and ~250 here. The five
> instructions are real; they are just the last step, not the whole one.

### The way out already exists in the tree

`FGX_DP_KERNELC` is a **whole direct page of its own for kernel C**, because
fcc's register file wants `$98-$FF` laid out one way and the console wants
`$C0-$EF` laid out another, and "the two maps cannot both be true of one page"
(`include/kernel.s:495-502`). The entry macro `TCD`s to it.

So the pattern is established: **a subsystem can own a direct page and switch to
it on entry.** Option A becomes a split rather than a swap:

- a **per-task scratch DP** (12 pages) carrying `$00-$9F` and the replicated
  base pointers;
- a **shared console DP** (1 page) carrying `$C0-$EF`, entered by `TCD` in the
  console routines the way kernel C already does.

**Total 13 pages = 3,328 B**, against 2,354 B recoverable plus arena headroom.
Console entry/exit pays a `TCD` pair. The 742 console sites do not change --
they change *which page is live*, not their addressing.

**This is the only option found that fixes the whole shared-scratch class
without touching a single use site.** It is also the only one whose cost is
paid in the currency Phase 2 measured.

## 4. Option B -- remove the need (`copyin`/`copyout`)

2.11BSD never holds a far pointer to a caller buffer in shared scratch. It
calls `copyin`/`copyout`: one audited primitive, arguments passed in, no
custody rule for anyone else to get wrong.

FGX open-codes that pattern at roughly 250 sites through `_libcTmp2`, which is
why one cell has 554 uses across 24 files and why it was the cell that broke.

**One `copyin`/`copyout` pair would need exactly one scratch cell**, held only
inside a routine that provably does not sleep. The count of shared cells is a
symptom of N handlers each solving the same problem locally, not of a storage
shortage.

| | |
|---|---|
| **buys** | collapses the largest single hazard class; makes the enforcement checker tractable (one routine to audit, not 20 sleep sites x 11 cells) |
| **costs** | ~250 call sites rewritten; a new primitive in the kernel bank reachable from modules; per-call overhead where a hand-inlined copy was |
| **risk** | the sites are hand-written asm across the syscall layer and three modules |

This is the destination that matches what the reference system actually does,
as opposed to what its layout looks like.

## 5. Option C -- do nothing structural

Required by the charter, and it is not a straw man.

- Fix at choke points, as `_Sock_PollIntr` (#100) and `_Tty_GetByte` (#41)
  already do. **Phase 1 measured the remaining exposure at zero** across the
  whole kernel call graph.
- Extend sleep-reachability enforcement over `net`/`sock`/`pipe`, **modelling
  the module jump-table seam**, since that is the one place the checker is blind
  and the one place a live defect was found.
- Reclaim the 2,354 B of dead EQUs and unallocated reservation opportunistically.
- Answer Gate 2 (`$C035`), which may be worth more than everything else here:
  if hi-res shadowing is on, ~16 KB of the existing user-stack arena is running
  at 1 MHz today.

| | |
|---|---|
| **buys** | no code motion, no new bank-0 spend, no ABI change |
| **costs** | the invariant stays invisible; every new sleeping path is a fresh chance to reintroduce #100 |
| **risk** | lowest of the three by a wide margin |

## 6. Assignments

| candidate | destination | note |
|---|---|---|
| 2,276 far-pointer sites (33 cells) | **Option A or B only** | stack and absolute are both closed by the instruction set |
| console `$C0-$CF` (192 sites) | **`CON_VT_STATE`, done** | per-VC, not per-task; moved to the far-bank block the VC switch already copied |
| console `$D0-$EF` (~530 sites) | **per-task DP** | internal scratch + one argument cell; per-task is correct, not merely safe |
| boot-established base pointers (375 sites) | replicate per-task, or leave | identical in every copy |
| `_u` | per-task DP | strictly better there |
| `_libcTmp2` (554 sites) | **Option B** | the copyin/copyout case, and the #100 cell |
| `FGX_SYSVARS` | **delete** | dead EQU, 256 B |
| `FGX_BOOTAREA` | **KEEP -- NOT DEAD** | holds `BlkTramp`/`CoutTramp`, JSL'd at runtime; the EQU's single reference is a fact about the symbol, not the region |
| `FGX_STK_TASKS` | delete the symbol | already dead; comments only |
| user-stack arena headroom (30 pages) | **measure before spending** | it is the worst-case guarantee, and Gate 2 may reprice it |

## 7. Phase 4b -- the lateral prompts, answered

1. **Unify the four per-process objects?** No. The 2.11BSD unification is cheap
   because an MMU maps the u-area at one fixed kernel address; FGX has no MMU
   and cannot have that property. Option A takes the *useful* half -- per-task
   addressing state -- without the unification.
2. **Question the fixed pid-indexed layout?** Keep it. It buys O(1) addressing
   with no indirection, and Option A depends on exactly that to compute a DP
   page from `_curTask` in five instructions.
3. **Demand-grown stacks?** Not worth pursuing: stacks measured a quarter full,
   so growth is not the constraint. Also bounded by `check_stack_budget.py`'s
   standing fact that the arena can never be compacted, since fcc frames hold
   absolute bank-0 addresses.
4. **Re-test the `NewHandle` rejection?** Deferred, not refuted. It only matters
   if something needs dynamically allocated bank-0 pages, and no surviving
   option does -- Option A's 13 pages are a static reservation.
5. **A pool of kernel stacks claimed at syscall entry?** Moot. The stacks are
   three-quarters empty; pooling optimises a resource that is not scarce.
6. **Invert the scratch problem?** **Yes -- this is Option B**, and Phase 3
   showed it is what the reference system actually does.
7. **Is bank 0 the only 16-bit-addressable space?** Enumerated: the stack
   pointer is bank-0-only (hardware), `[dp],Y` requires the pointer in the
   direct page but the direct page may sit anywhere in bank 0 (hardware), and
   `MVN`/`MVP` cross banks freely. Everything else in bank 0 is convention.
8. **What would 8 KB of bank 0 buy?** Not bigger kernel stacks -- nothing is
   asking. It would buy Option A twice over with room left, or it would buy
   `NPROC` growth, which apple/fgx#45 says is the knob everything else derives
   from.
9. **Disable SHR shadowing, move the framebuffer to `$E1`, and free bank `$01`?**
   **Rejected -- a no-op for this problem and a mild net negative overall.**
   Recorded with the reason, because it is the most natural "find more RAM"
   idea and it will be proposed again.

   - **The 32 KB cannot hold anything bank 0 is short of.** The 65816's stack
     pointer is 16-bit and always bank 0; the direct-page register is a 16-bit
     offset and always bank 0. Both are hardware. **About 44 of the ~46 KB
     claimed in bank 0 is stacks and direct pages**, so freeing a different
     bank relieves none of it. The scarcity is structural, not quantitative --
     which is why every surviving option is "give the pointer a different
     *direct page*" rather than "find more memory".
   - **The prize is 32 KB, not a bank.** `$01:A000-$BFFF` already holds
     `GFX_PALTAB`: `syscall.s:924-926` does `MVN $01,$01` from `$01:A000` into
     the hardware palette at `$01:9E00`.
   - **The trade is negative on the hot path.** Writes to `$01:2000-$9FFF` are
     shadowed today, so they *already* pay the stretched store; drawing to
     `$E1` directly keeps that cost and adds VGC contention, while turning the
     currently-full-speed reads from `$01` into 1 MHz reads. The palette `MVN`
     reads bank `$01` deliberately and would get slower.

   **What would change the answer:** a minimum-RAM target where 32 KB of fast
   RAM matters for the kernel heap (buffer cache, vnodes) currently living in
   banks `$07`+. That is a memory-pressure question, not a bank-0 question, and
   should be re-opened on its own terms if it ever bites.

## 8. What Phase 5 has to weigh

Option A fixes the class with zero site churn and a bank-0 bill FGX can nearly
afford. Option B fixes the same class properly and permanently at ~250 hand-asm
sites. Option C costs almost nothing and, per Phase 1's zero, is defensible
today -- but leaves the invariant unenforced at the one seam where it has
already failed once.

**None of them involves growing a kernel stack**, which is what the assessment
set out expecting to cost.
