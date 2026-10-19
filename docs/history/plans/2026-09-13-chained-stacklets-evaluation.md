# Chained stacklets -- an evaluation (apple/fgx#412)

Status: EVALUATION, 2026-09-13.  Nothing here is built.  It re-examines section
3.3-3.5 of `docs/history/plans/bank0-stack.md` (the campaign's plan of record for on-demand
stack growth) against today's tree, with measurements, and ends in a proposed
increment plan and the decisions it needs.

Written against a language-card move of the user direct pages that did not
land.  The arena reached the same 165 pages through the user-image cache
instead (`docs/history/plans/2026-09-17-bank0-residency-architecture.md`, R2),
and the NPROC ceilings of section 10 no longer hold since that plan's R4 took
NPROC to 32.  The measurements of section 11 are the programs' own and stand.

## 1. Why this is back on the table

The bank-0 user-stack arena is allocated by static worst-case RESERVATION.
After the language-card move (`feat/412-stack-margin`, arena 152 -> 165 pages)
the reservations still dwarf use:

| binary | reserved | measured high-water |
|---|---:|---:|
| tcsh | 19,214 B (76 pages) | 2,942-4,234 B |
| sh | 16 pages | 220-310 B interactive, 1,308 B sourcing |
| vi (elvis) | 22 pages | -- |
| tar | 24 pages | -- |

Phase B of #412 measured every static refinement of the model
(`stack_measure.py`) and found the gap is structural.  tcsh's reservation is:
- a deepest path of 6,061 B;
- two one-hop allowances of 5,154 B each, for a function-pointer dispatch and
  for a signal handler, each charging the largest subtree on top of the
  deepest path;
- 2,312 B of recursion reserve.

The sound refinements save:
- 0 pages on tcsh from using the depth of the indirect call site (the sites
  sit inside its 117-member SCC);
- 0 pages on tcsh from narrowing the signal allowance to the registered
  handlers (14 registrations are not literal functions).

`CYCLE_TURNS` is the only lever left, and it is a policy change (the maintainer: keep
it at 8).  Only growing a stack on demand closes the gap.

## 2. What BSD does, and what FGX cannot copy

2.11BSD sizes nothing.  On a segmentation fault the trap handler backs up the
faulting instruction and grows the stack to include SP; if that fails, the
process gets SIGSEGV:

    if (backup(u.u_ar0) == 0)
        if (!(u.u_sigstk.ss_flags & SA_ONSTACK) &&
                grow((u_int)osp))
            goto out;
    i = SIGSEGV;
                                  -- examples/2.11BSD/usr/sys/pdp/trap.c:218-222

`grow()` (vendor/2.11BSD/usr/sys/sys/kern_mman.c:48) adds SINCR clicks, and
`expand()` (vendor/2.11BSD/usr/sys/sys/vm_proc.c:29) moves the process image
to a larger region -- or swaps it out -- because the PDP-11 MMU lets a stack
live at any physical address.  FGX has no MMU and fcc frames hold absolute
bank-0 addresses, so a stack can never move (`docs/history/plans/bank0-stack.md` section 4).

Chaining is the BSD BEHAVIOUR without relocation: the overflow check trips,
the kernel links a fresh run of bank-0 pages below the current frame, and the
faulting prologue resumes; if no pages are free, the task gets the signal.
Frames already on the stack never move.

## 3. The plan of record's two blockers do not apply to chaining

### 3.1 Exiling address-taken locals is not a prerequisite

`docs/history/plans/bank0-stack.md` 3.1 calls exiling every address-taken local (increment
1.2, ~16,749 B of code that tcsh does not have) a "correctness prerequisite
for stacklets".  The reason it gives is that moving or spilling a frame
dangles pointers into it.  That is true of the far-backed window (3.3b), which
spills frames, and of relocation, which moves them.  Chaining does neither.
Every frame stays at the address it was created at, so a `&local` pointer --
859 mints across tcsh, sh, elvis and tar -- stays valid for exactly as long as
it does today.

What chaining copies is the boundary region only: `[S+1 .. caller_fb-1]` at the
moment the callee's guard trips.  That region is:
- the callee's saved `_fcc_fb` (2 B);
- the JSL return address (3 B);
- every argument the caller pushed;
- any temporaries the caller pushed before its arguments.

The bound is readable: the prologue has not yet overwritten `_fcc_fb`, so it
still holds the caller's frame base (`emit.c:2128-2150`).  Nothing the caller
reads after the call lives in that region:
- fcc has no struct-return-by-value ABI (`parse_stmt.c:7282-7283`);
- by-value struct ARGUMENTS are part of the copied window
  (`emit_fpr_arg_window`, `emit.c:5829-5840`);
- the caller pops its arguments and discards them.

### 3.2 The "pin set" is not needed either, with one real exception

The plan pins functions that take `&param` -- 16 in tcsh, 3 in sh, 2 in elvis
(measured, matching the record) -- on the grounds that something walks their
argument area.
- **`va_start` walks upward** from the last named parameter (`stdarg.h:22-29`,
  tcsh's `varargs.h:18-21`).  Under a full-region copy every pushed argument
  is in the new stacklet, so the walk stays inside the copy.
- **`skipargs(&v, ...)`** writes through a pointer into the callee's own
  parameter copy, which the callee then reads.  Both sides use the same copy.

**The exception is a C function entered from assembly**, where the `PEI`'d
`_fcc_fb` is stale and the copy bound is meaningless:
- `_sig_tramp` -> handler (`crt0_far.s:500-661`);
- crt0 -> `main`.

Those entry points must never chain at entry.  `_sig_tramp` already checks
the floor before dispatch (`crt0_far.s:567-571`) and can reserve room instead;
`main` starts on the first stacklet, which is sized for it.

### 3.3 The guard does not need to be on every non-leaf function

3.4 of the plan says chaining needs `STKGUARD` on "essentially every
non-leaf", which the code banks cannot afford.  Measured cost at today's 9 B
guard:

| binary | functions | guarded | non-leaf | arm every non-leaf |
|---|---:|---:|---:|---:|
| tcsh | 569 | 78 | 467 | +3,501 B (6,544 B free, but seg1 and seg2 left with 104 B and 63 B) |
| sh | 128 | 14 | 109 | +855 B |
| elvis | 214 | 13 | 185 | +1,548 B |
| tar | 36 | 3 | 32 | +261 B |

The invariant chaining actually needs is weaker:
1. every CYCLE in the call graph contains a guarded function; and
2. each stacklet's floor margin covers the deepest stack an UNGUARDED run of
   calls can take before the next guard checks again.

Measured over the current build outputs (a greedy cut of the unguarded
subgraph's cycles):

| binary | extra guards to break every unguarded cycle | longest unguarded chain |
|---|---|---:|
| tcsh | 5: `stderror`, `_sh_lex_getexcl`, `_sh_parse_asyn0`, `_sh_parse_syn0`, `aliasrun` | 328 B |
| sh | 1: `_macro_copyto` | 230 B |
| elvis | 2: `blkget`, `tmpabort` | 429 B |
| tar | 0 | 104 B |
| libc_c.s / libc_net.s / libcurses.s | 0 / 0 / 0 | 74 / 56 / 57 B |

Condition 1 is stricter than the linker's current warning, which treats an SCC
as safe if ANY member is guarded (`fgx_ld.py`, `unguarded_cycles`): an
unguarded sub-cycle can still loop without a check.

Condition 2 gives a per-binary margin of roughly:
- the unguarded chain;
- the caller's largest argument push (tcsh 70 B);
- the hand-assembled libc tail (<= 384 B);
- the red zone of section 4.

That comes to under 1 KB for tcsh, at a code cost of 5 guards.

## 4. Everything that assumes one contiguous stack

The inventory, condensed.  Rows marked HARD are design problems rather than
edits.

| area | site | under chaining |
|---|---|---|
| guard | `emit.c:2140-2146` `JMP _fcc_stkoflow`; `fcc_runtime.s:206` exits 134 | **HARD.** Resumable: `JSL` to a per-segment stub that calls a chain syscall and returns into `fn_stkok TCS` with A intact.  A compiler change and a world recompile.  Kernel C keeps a non-resuming variant (`fcc_ktrap.s:67`). |
| spawn | `task.s:645-1004` `Task_AllocStack`; `process.s:241-268`, `1990-2010` floor seed | The hint sizes the first stacklet; a second entry carves stacklets without touching the TCB; every chain and unchain rewrites `_fcc_stkfloor`. |
| exit / exec | `task.s:1016-1114` `Task_FreeStack`; `process.s:2345-2503, 3156-3204` | Walk and free the chain.  exec must save the OLD chain head before its DP page goes. |
| fork | `process.s:1390-1733` `_Fork_Snapshot` / `_Fork_Restore` | **HARD.** The borrowing child runs on the parent's pages: unchaining in the child would free parent-owned stacklets, and chaining deeper allocates ones the parent never had.  Needs owner-tagged stacklets (arena map bytes hold the owner instead of 0/1), no freeing while borrowed, the snapshot as a list, and the child's stacklets freed at hand-back.  The vfork stub (`libc.s:183-300`) must save `_fcc_stkfloor`, which it does not today. |
| syscall | `syscall.s:261-277` floor check (`TCB_StackBase+128`) | Wrong under chaining: must compare against the CURRENT floor (`_Sys_UserDP`+$B9).  It can only kill, never chain. |
| signals | `syscall.s:636-676` pushes up to 12 B unchecked; `_sig_tramp` pushes 17 B and checks `128-6` | Red zone in every stacklet's margin; `_sig_tramp`'s check chains instead of trapping, or the kernel chains before building the frame. |
| IRQ | heartbeat through the firmware IRQ path on the user S (`toolbox.s:32`) | Red zone. |
| longjmp | `libc.s:425-500` `TCS` to the saved S | **HARD.**  It leaks newer stacklets and leaves the floor pointing at the wrong one.  jmp_buf needs no ABI change: stacklets are disjoint, so the one containing env.sp is findable.  Either longjmp calls a syscall, or the kernel reclaims lazily -- any stacklet newer than the one holding S is dead, reclaimed at the next chain operation.  bsh longjmps out of signal handlers. |
| chain state | TCB full (`kernel.s:723`), SE full (`kernel.s:966`) | **HARD but small.**  `TCB_StackPtr`/`TCB_StackBank` (`kernel.s:674-675`) are copied through fork and exec (`process.s:742-748, 2351-2353, 2788-2790`) but never used to address a stack -- 4 B for a chain head -- and per-stacklet headers live in the stacklets.  Never `Kmalloc M_KERN` (fork does not copy it; `bank0-stack.md` 3.5). |
| lane (B3) | `task.s:689-835, 2671-2979` | Compatible: stacklets outside the lane are private and stay put.  Lane identity must not come from `TCB_StackBase`, which a vfork child copies.  The lane itself may become unnecessary once windows are small (`b3-stack-swap-scope.md` 1084-1087). |
| reporting | `task.s:1998-2193` paint / `Task_StkHwm` / GUARD line; `PI_StkSize`/`PI_StkHwm`; `ps` | Per stacklet; the columns change meaning. |
| tools/tests | `check_stack_budget.py`, `stack_baseline.py`, `stkpad_analyze.py`, `M1/stkfloor.c`, `M1/stkguard.c`, `mutstk` | Encode "reservation = one region" and "overflow = killed". |

Unchanged:
- context switch (S saved and restored as today);
- the argv frame and crt0's reads of it (first stacklet only);
- syscall signature bytes read at `2,S`/`4,S` (just pushed);
- arena accounting.

## 5. The unchain path

Return past a stacklet's top needs no per-call check.  The copied JSL return
address in the new stacklet is replaced by the address of an unchain
trampoline; the real return address is kept in the stacklet header.  The
callee's epilogue (`TAY / TSC / ADC #FS / TCS / PLA / STA _fcc_fb / TYA / RTL`,
`emit.c:2188-2212`) `RTL`s into the trampoline.  The trampoline:
- restores S to the old stacklet, just above the original return address, so
  the caller's argument pop sees its own copy;
- restores `_fcc_stkfloor`;
- jumps to the real return address;
- preserves A, Y, `_fcc_long_hi` and `_fcc_fpr0`, the epilogue's return-value
  contract.

Freeing on unchain is where thrash lives -- a function oscillating across the
boundary would allocate and free on every call.  Keep the most recent emptied
stacklet cached per task and free it lazily.

## 6. What it would buy

With a stacklet chained on demand, the hint sizes an initial WINDOW rather than
a reservation.  Sized from measured high-water plus the margin, rather than
the model's worst case:
- tcsh would start near 20 pages rather than 78;
- sh near 5 rather than 18;
- deeper use pays for itself only when it happens.

The #412 set (init, two sh, tcsh, getty, update, inetd, vi) would reserve
roughly 60 pages rather than 156.  The windows are estimates until increment
S0 measures them.

Failure moves from spawn time to run time, which is the trade the 2026-07-31
record rejected for grow-on-fault (ROADMAP:3323-3336).  The difference that
record itself names: chaining "takes pages that are *actually free at that
instant* and fails cleanly if none are" (`bank0-stack.md` section 4).  That is
2.11BSD's contract -- SIGSEGV when the stack cannot grow.

## 7. Proposed increments

Each is abortable, and the rollback past the last one is a window-size
parameter, not a rebuild (`bank0-stack.md` section 6).

- **S0 -- measure the windows, no codegen change.**  Build with hints clamped
  to candidate window sizes and run the gate plus the deep workloads
  (`srcdepth_loud`, `mutstk_deep`, tcsh scripts, tar trees).  Today's guard
  kills show where a window is too small.  Output: per-binary window sizes
  and trip rates.
- **S1 -- every cycle guarded.**  The linker computes the cycle-breaking
  guard set; fcc arms `STKGUARD` on it.  The linker's unguarded-cycle warning
  becomes the stricter rule of section 3.3.  Output: +5/+1/+2/+0 guards, and
  the per-binary unguarded-chain margin recorded in the FGX2 header.
- **S2 -- resumable guard, still exiting.**  `JMP` becomes `JSL` to a
  per-segment stub that calls a new syscall; the syscall exits 134 exactly as
  today.  World recompile; behaviour unchanged; per-segment code cost measured
  against the tcsh cliff.
- **S3 -- chain and unchain.**  Owner-tagged stacklet allocation, the chain
  syscall, the boundary copy, the unchain trampoline, floor rewrites, the
  syscall floor check and signal red zone, lazy reclamation for longjmp, exec
  and exit walking the chain, and fork's list snapshot with ownership.
  Fixtures, each of which must go red without the feature:
  - recursion across a boundary with a varargs callee;
  - longjmp across stacklets;
  - a snapshot-fork child that chains and returns;
  - a signal delivered at a boundary.
- **S4 -- flip the policy.**  The hint becomes a window; the B3 lane is
  re-evaluated; `check_stack_budget.py` models windows.

## 8. Risks

- **Silent cross-task corruption.**  This is still the project's most
  expensive failure class (`bank0-stack.md` section 6).  A wrong boundary
  copy, a stale floor or a fork ownership slip scribbles on a neighbour.  S3's
  fixtures exist for exactly these.
- **The asm-to-C entries of section 3.2** are an argument, not a measurement.
  S3 needs a fixture where a signal handler's first guarded call sits at a
  boundary.
- **The margin is static.**  A binary rebuilt with a deeper unguarded chain
  needs its margin recomputed at link time.  It must be derived by the
  linker, never hand-set.

## 9. Decisions this needs

1. **Proceed at all**, and in the order above -- S0 is cheap and informs the
   rest.
2. **The failure signal.**  2.11BSD delivers SIGSEGV when the stack cannot
   grow; FGX's guard exits 134.  Keep 134, or deliver SIGSEGV (which needs a
   stack to run the handler on -- BSD's `SA_ONSTACK` test in trap.c exists for
   that).
3. **Where chain state lives.**  The unused `TCB_StackPtr`/`TCB_StackBank`
   bytes for the head plus in-stacklet headers, or cells in the task's DP page.
4. **The B3 lane's future** once windows are small.

## 10. For comparison: raising NPROC

Stacklets do not raise NPROC; the stack arena has not bounded the process
count since the per-pid kernel stacks moved to the language card (it is 165
pages at every NPROC).  Checked with genconfig's derivation and
`check_bank0_geometry.check()` on the current tree:

| NPROC | result | what binds |
|---|---|---|
| 12 | fits | -- (today) |
| 13 | fails | the TCB table, `FGX_TASK_TBL` `$02:0800` + 13 x 64 B, runs into `FGX_CODE` at `$02:0B00` |
| 14 | refused | the per-pid kernel stacks end at `$FE00`, leaving no room for the interrupt-time kernel-C context above them |
| 15, 16 | refused | 16 kernel stacks of 512 B end past `$FFE0`, the hardware vector table |

The ladder, and what each step costs:

- **13.**  Raise `FGX_CODE` by 64 B per slot with its lockstep list
  (`fgx.link.s` ORG, stage 2 `KERNEL_DEST_LO`, `verify_kernel`, #45), plus
  `VFS_NPROC`, which the build already checks against the config.  The cost
  is core-bank code room; the core bank has 5,296 B free.  Everything else
  already fits at 13:
  - kernel stacks and IRQ context end at `$FF00`;
  - the kernel direct pages at `$0900-$16FF`;
  - the user direct pages at `$D000-$DDFF`.
- **14.**  The interrupt-time kernel-C context (one direct page and a
  512 B stack) has to leave the flat 8 KB.  The `$D000` window has only one
  page spare at 14, so it comes out of the arena top: about 3 arena pages.
- **15 and 16.**  The kernel stacks no longer fit the language card; they
  cannot shrink (the deepest measured is 470 of 512 B).  The kernel direct
  pages outgrow `$0900-$17FF` (15 pages), and the `$D000` window is exactly
  full at 15.  So each slot past 14 moves a kernel stack and a kernel direct
  page back into low bank 0, out of the arena: about 3 arena pages per slot.
  This is the step stacklets make cheap, because arena pages stop being held
  by reservations.
- **16.**  The five signal HANDLER tables and `_kAlarmTicks` are statically
  sized for 16 tasks; growing them is an EQU change.
- **Past about 18.**  The vnode pool's structural floor is one cwd per
  process plus one root per mount: 12 + 14 = 26 of 32 today, one more per
  slot.  `VNODE_POOL` and `NFILE` (32 each) would have to grow; where that
  memory comes from is not measured here.

Per process, the kernel also holds a 128 B cwd buffer in kernel data and about
330 B of nameidata in the kernel heap.

Two different limits, then:
- **NPROC** is how many processes can exist.  13 is cheap, 14 modest, and 15
  or 16 is real work that stacklets would make cheaper.
- **The arena** is which programs can run together.  Stacklets fix that one.

## 11. S0 results: measured windows

Measured with `tools/stack_baseline.py`, milestone "#412 arena 165, stacklet
S0 workloads" in `docs/history/audits/bank0-stack-baseline.md`.  That run added
interactive-tcsh, scripted-tcsh and vi workloads.  The high-water marks are
bytes actually touched: the stack is painted when it is carved and scanned
when it is freed.

A window is `ceil((high-water + margin) / 256)` pages.  The margin is section
3.3's:
- the longest unguarded call chain after the cycle-breaking guards;
- the largest argument push;
- the deepest libc function the binary reaches;
- a 64 B red zone.

| binary | reserved today | measured high-water | margin | window |
|---|---:|---:|---:|---:|
| tcsh | 78 pages (lane 80) | 3,346 B interactive; 4,234 B is the largest recorded (ROADMAP) | 851 B | **17-20** |
| sh | 18 | 344 B interactive; 1,342 B sourcing 55 commands | 699 B | **5** (8 at 55 commands) |
| vi | 24 | 624 B | 864 B | **6** |
| tar | 26 | 1,312 B | 577 B | **8** |
| ls | 13 | 1,470 B | 256 B | **7** |
| mount | 8 | 934 B | not computed | ~6 |
| grep | 4 | 284 B | 132 B | **2** |

For the #412 set (init, two sh, tcsh, getty, update, inetd, vi), the
long-lived tasks come from #412's own `ps -a`: init 170 B, getty 246 B,
update 112 B, inetd 500 B.  Their margins were not computed; about 450 B is
assumed.  The set would hold **about 46-49 pages** instead of the 156 it
reserves today, returning **about 107-110 of the arena's 165 pages**.  That is
roughly eight times the language-card move's 13.

What S0 did not do:
- **Clamped-hint runs.**  Running the gate with hints clamped to these
  windows is weak evidence while most functions are unguarded (section
  3.3): a window that is too small can overrun silently instead of dying on
  the guard.  The painted high-water marks above are the stronger
  measurement.  The clamped check belongs after S1.
- **Workload coverage.**  Numbers are only as deep as the workloads.  A
  window is the FIRST stacklet, not a limit; deeper use chains.  Sizing it at
  the measured high-water plus margin means typical use never chains.

**S1 has value on its own, before any stacklet work.**  Guarding every call
cycle -- 5 functions in tcsh, 1 in sh, 2 in vi -- closes a silent-overrun hole
in TODAY's static reservations.  An unguarded sub-cycle can recurse past its
reservation into a neighbour's stack with no check at all.  The linker's
current warning misses it, because it treats a recursion group as safe if ANY
member is guarded.
