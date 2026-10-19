# Bank-0 stack: where we actually are (2026-08-06)

**Read this first, then `bank0-stack.md` for the design reasoning.** That
document is the campaign's plan and rationale and remains correct about *why*;
this one carries the *current numbers* and says which of its statements have
since gone stale. Numbers here were measured on `feat/virtual-consoles` at
`a6c119008`, not carried over from earlier sessions.

## 1. The constraint, in one paragraph

The 65816's stack pointer is 16 bits, so **every task's hardware stack must live
in bank 0**. FGX carves them all from one fixed region, `FGX_STK_ARENA`
(`include/kernel.s`), via a first-fit page bitmap in `Task_AllocStack`. Each
task's share is a **static worst-case reservation held for its whole life**,
sized by `toolchain/src/ld/stack_measure.py` from the deepest static call-graph
path. A shell blocked in `wait()` is touching a few hundred bytes of a multi-KB
reservation while its children cannot spawn. Nothing in this session changed
that; it is the shape of the problem.

## 2. Current numbers

| | value | note |
|---|---|---|
| `FGX_STK_ARENA_PAGES` | **154** | 149 -> 147 when `NPROC` went 8 -> 10; 147 -> 156 by the bank-0 compaction (§11). **DERIVED since 2026-08-07** |
| `kernel.nproc` | **11** | THE knob. `tools/ninja/genconfig.py` computes the kernel-stack block, `BLK_STAGE`, the arena base, the arena size and the DP base from it; every slot costs exactly 2 arena pages. Raising it is one line, up to a named build error at 13 (apple/fgx#45) |
| arena base / DP block | `$1A00` / `$B400` | DP block holds pids 0..11, ends at `$C000`; both DERIVED from `kernel.nproc` |
| `TASK_STACK_MAX_PAGES` | 83 | ~21 KB; the gate forbids raising it |
| worst-case scenario | **123 / 154** | `check_stack_budget.py`, "deepest tool in a pipeline under tcsh". Corrected 2026-08-07 (apple/fgx#30): the old 117 excluded `init` and omitted the argv-frame page every task gets. RUN THE TOOL rather than quoting this -- not quoting it is what let #30 sit |

Per-binary reservations (byte 14 of the FGX1 header, `disk_src/bin/*`):

| binary | pages | |
|---|---|---|
| `sh` (bsh) | 14 | |
| `tcsh` | **74** | Unclamped since 2026-08-06.  Was 83 CLAMPED against a need of 133; see §4 |
| `vi` (elvis) | 22 | was 51 before 2026-08-06 |
| `tar` | 20 | |

Live co-residency on the shipped config (measured from the task table, two
consoles): init 3 + console `sh` + `tcsh` on ttyv1 + `login` = 119 of 156.

### 2.1 Reading it live: `ps`

Every number above came out of a build-time model or the kernel log ring. Since
2026-08-06 the running machine reports it directly -- `ps(1)` carries both
scarce resources and an arena footer:

    fgx# ps
      PID  PPID ST   STK    HWM   HEAP CMD
        0     0  R     -      -      - [kernel]
        1     0  S     3    144  60058 init
        4     1  R    16    224  50538 sh
        5     1  S     3    134  60956 getty
        6     4  R     3    118  61259 ps
    stack arena: 25/147 pages used

- **STK** -- pages this task RESERVED of the bank-0 arena, guard page included.
  This is what fills the arena.
- **HWM** -- bank-0 stack bytes it has actually TOUCHED, *measured*, by the same
  `STK_PAINT` scan the kernel has run at exit since increment 0.1
  (`Task_StkHwm`, task.s). What is new is that it now runs against a LIVE task;
  before, a mark could only be read for a process that had already died. `-`
  means the region is outside the arena and was never painted.
- **HEAP** -- bytes of C heap the task had left at its TIGHTEST. The heap is the
  tail of its 64 KB data bank, grown by `sbrk`, and the kernel now keeps a
  high-water mark of the break beside the break itself (`HEAP_HWM`, the
  self-describing descriptor at the top of the bank -- see `include/kernel.s`).
- The footer is counted off `_stkArenaMap` itself, so it is the allocator's own
  state rather than a sum of the rows.

**The HEAP column is the PEAK, and that is the whole point.** The first cut
reported the live break, and a process that peaks while it starts up and then
frees reads as idle afterwards -- which is exactly what tcsh's login path does,
and exactly how a wrong diagnosis got as far as a filed issue (§4). The stack
side had already paid for this lesson once; the heap side got the same
instrument rather than the same lesson twice.

**The two columns are two ends of one trade.** Making a large local `static`
takes bytes off STK and puts them in the data bank, where they come out of HEAP.
Watch both when proposing it.

**A reservation many times its HWM is arena somebody else could have had; a
reservation close to its HWM is one deep call from the guard page.** Both
readings are the point, and neither was previously available while the system
was running.

**`ps` and `check_stack_budget.py` will disagree by about one page per task, and
`ps` is right.** `sh` reads 16 here against the table's 14 above: 14 hint + 1
guard + **1 argv/envp frame page**. The budget tool models only hint + guard --
its own header has recorded that undercount since #45 ("EVERY task here is short
at least one page, and more with a large env") along with a second one for init.
The two were left for a single fix because correcting either alone encodes a
different wrong number. That fix now has an oracle to check itself against.

## 3. What changed on 2026-08-06, and why the numbers moved

Three independent things landed, and they interact:

1. **`stack_measure`'s one-hop allowance was fixed** (MR !60, `ced106b2c`, now on
   `main`). It had been suppressed whenever `floored` was set, so binaries using
   fn-ptr dispatch were sized to a floor rather than a fit. **vi and tcsh were
   both under-sized.** vi jumped 14 -> 51 pages, tcsh back up to its clamp. This
   is a correctness fix: vi previously *opened* at 14 pages and died on the first
   character typed.
2. **Four elvis `BLK` locals became `static`** (`src/userland/elvis/`), taking vi
   51 -> 22 pages. See §5.
3. **User stacks are freed at exit, not at reap.** `Task_FreeStack` ran only from
   `Task_Free`, so a zombie whose parent never waits pinned its whole
   reservation. Recovered ~60 pages in `logintest`, which spawns seven sessions
   and never `wait()`s.

## 4. tcsh WAS clamped; the shrink shipped 2026-08-06

tcsh used to report

    stack pages (pad 128, total 34012, clamp 83): 83
    !! CLAMPED: deepest path exceeds the 83-page (20KB) cap

It needed **34,012 B = 133 pages** and reserved 83 — sized to a FLOOR, exactly
the condition that made vi die on its first keystroke, so it was relying on the
prologue guard rather than on a reservation that fits.

**Five one-word changes take it to 74 pages, unclamped.** They were written and
behaviour-tested in early August and then held OFF for a day behind an empty
`TRACKED` because they tripped apple/fgx#42 — a bug that was never about them.
#42 is fixed (see below) and `TRACKED` is now populated: the arena's worst case
is **114/156 pages**, down from 123.

### The fix, and that it works

| TU (`src/userland/tcsh/`) | function | locals made `static` | stack | data |
|---|---|---|---|---|
| `ed.screen.c` | `ChangeSize` | `t_c_`, `backup` | 5,790 B | 2,048 B |
| `sh.glob.c` | `backeval` | `ibuf`, `tibuf` | 3,072 B | 1,024 B |
| `sh.dol.c` | `heredoc` | `obuf`, `lbuf`, `mbuf` | 2,898 B | 1,536 B |
| `tw.parse.c` | `t_search` | five name buffers | 2,658 B | 803 B |
| `sh.lex.c` | `bgetc` | `tbuf` | 1,536 B | 513 B |
| | | **total** | **-> 74 pages** | **5,924 B** |

Measured, not projected: with all five, `stack_measure` reports 18,757 B = 74
pages and drops the CLAMPED line. Leave-one-out: without `ChangeSize` the rest
leave tcsh at 96 pages, still clamped; without `backeval`, 86, still clamped.
`tenematch`'s own `word[FILSIZ+1]` was measured and **left alone** — it moves the
reservation by zero pages once `t_search` has shrunk.

The behaviour is tested and correct (`tcstatic`, `tccomp` — command
substitution, here-documents, the script reader and filename completion, each
probed with a SHORT payload following a LONG one so a leaked buffer tail would
show). `tcstatic` is mutation-proven: making `heredoc`'s output pointer carry
across calls — the exact failure a static risks — turns `=T3S=` red while every
other assertion stays green.

### What blocked it: apple/fgx#42 — FIXED 2026-08-06, and it was an fcc bug

`vivc` — vi under a tcsh **login** shell on a virtual console — went RED with the
five conversions in and GREEN with them out. It was not a bug in the conversions:
**5,924 bytes of dead, never-referenced static padding reproduced it exactly**,
and four of the five (3,876 B) passed.

Measured boundary, by padding the data segment:

| dataseg | `vivc` |
|---|---|
| 28,324 (shipping) | PASS |
| 30,372 / 32,200 / 32,800 | PASS |
| 34,248 | **FAIL** |

Caught in the act — stall on ttyv1, `Option-1` back to the console, `ps` there:

    PID  PPID ST   STK    HWM   HEAP CMD
      5     1  R    84   3090  27302 tcsh      <- ALIVE, state R

**tcsh is running.** 27,302 bytes of heap free at its high-water mark, 25 arena
pages free, no PANIC, no overflow, no spawn error — it simply never prints its
prompt on the VC.

**Root cause: fcc mis-banked the address of an automatic struct.** A struct
value is already an ADDRESS, carried the legacy way (A = offset, `_fcc_ptr+2` =
bank), and that bank is its storage's — 0 for a hardware frame, DBR for a
global. fcc's `N_CAST` arm had no `LT_STRUCT` case, so casting one to a pointer
fell through to the int->pointer rule, which stamps DBR unconditionally.

tcsh's `sh.parse.c alias()` declares `jmp_buf osetexit` as an **automatic**, and
`sh.h`'s `getexit()` expands to `copy((char *)(osetexit), ...)`. The destination
reached `copy()` as `DBR:frame_offset`, so 12 bytes of jmp_buf went into the
**malloc heap** instead of onto the bank-0 stack. Where they landed depends on
the heap base — i.e. on the data segment size, which is why any 6 KB did it.
Past ~34 KB the write hit a live free-list block header; the next `free()` then
walked a cycle forever, which is the "running but silent" tcsh.

`setjmp.h` documents the stack-local `jmp_buf` hazard and says fcc fails closed
on it — but that guard fires at a `setjmp()` CALL, and `alias()` never calls
setjmp on `osetexit`; it only copies it.

Fixed in fcc's `N_CAST` arm plus the shared `fpr_from_walked` helper, with
`_fcc_bank_from_carrier` added to `fcc_runtime.s` so the correct sequence is the
same size as the wrong one (tcsh packs its 7 code banks with 268 bytes to
spare — an inline bridge does not fit). Regression fixture:
`toolchain/tests/M4/struct_cast_bank.c`, mutation-proven.

**How it was found**, because the method generalises: the PC sampler put 100% of
a stalled machine in one bank, in two hot spots that the segment listing named
as libc's `free()` list walk and its `_fcc_ltu16` helper — so the free list had a
cycle. Walking the list out of a memory dump showed a node with size 0 whose
address was `ptr - 6`; a temporary validator in `malloc.c` froze on the first
anomaly and named the call; a `capture_writes` tap on the offending heap cell
gave the writer's PC and, via the hardware-stack JSL chain, the whole caller
chain `srcunit -> settell` / `alias -> copy`.

### The wrong answer this section used to give

It said tcsh runs its data bank to the ceiling during login, citing
`heap full: brk refused at $0001` in the klog. **Both halves were wrong**, and
the way they were wrong is worth more than the conclusion was:

1. **Those log lines are not tcsh's.** `_Sys_Brk`'s own comment in
   `process.s` says so: *"bsh asks for more heap and is refused ROUTINELY, so
   this is a per-call fact, not an incident."* The line carries no pid. It was
   read as tcsh's because tcsh was the subject.
2. **tcsh's heap is nowhere near full** — peak use during an interactive login
   is **6,632 B of a 37,206 B heap**.

And the first attempt to measure it was wrong in a familiar way: `ps` was taught
to report the *current* break, which shows a process that peaks during startup
and frees as idle. That is the same current-versus-high-water trap the stack
side already paid for, which is why the kernel now keeps a break HIGH-WATER MARK
beside the break — see §2.1.

## 5. The lever that worked, and what it is worth

Making a large local `static` removes it from the frame at no behavioural cost,
**provided the function is not recursive**. On elvis this took vi from 51 to 22
pages with four one-word changes:

| TU | function | local | size |
|---|---|---|---|
| `modify.c` | `add()` | `buf` + `linebuf` | 4 KB |
| `blk.c` | `undo()` | `oldhdr` | 2 KB |
| `recycle.c` | `garbage()` | `oldhdr` | 2 KB |
| `cmd1.c` | `cmd_make()` | `buf` | 2 KB |

**Pick the targets by SUBTREE, not by frame size.** The one-hop allowance uses
`maxfn`, the deepest *subtree* rooted at a non-entry function, and charges it
twice. The function heading that subtree can have a tiny frame — elvis's was
`v_overtype`, own frame **4 bytes**. Reading "largest frames" and assuming the
biggest frame drives the allowance produced a prediction of ~21 pages that
delivered 1. `SM_TOPSUB=1` exists to answer this directly and prints the chain.

**Safety test, applied to each candidate:** the function must not appear in the
SCC `stack_measure` reports for that binary (no path from it back to itself),
and FGX signal handlers are flag-setters that return, so there is no
asynchronous re-entry. With no recursion a static's lifetime is
indistinguishable from the automatic it replaces.

**Pattern for changing vendored source:** move the TU from `PRISTINE` to
`TRACKED` in the tool's build script and keep an FGX copy under
`src/userland/<tool>/`, verbatim apart from the change, registered in
`docs/PROVENANCE.md`. `elvis`'s `system.c`/`unix.c` were already doing this;
`build_tcsh_link.sh` grew the same `TRACKED` list on 2026-08-06.

**Running total for the lever:** vi 51 -> 22 pages (four changes, SHIPPED), bsh
23 -> 9 much earlier (`service.c`'s `newt[1000]`, shipped), tcsh 133 -> 74 (five
changes, **measured and blocked — see §4**). It is the highest-yield tool in the
campaign by a wide margin.

**And it has a price that was not being counted: it costs DATA BANK.** Every
byte taken off the stack lands in the same 64 KB bank as the binary's heap. vi
and bsh had the room; tcsh does not, and nobody checked before this session
because the reservation was the only number anyone was watching. **Measure the
data bank as well as the stack when proposing this lever.** `dataseg: <n> B` is
printed by each tool's build script; the heap is `[end, $FFFE)` of the same
bank.

**What it does NOT buy (1) — measured, not assumed.** §7's first open question asked
whether the technique also drives `mints` (address-taken bank-0 locals) toward
zero, since a static's address is in the data bank. It does, but nowhere near
fast enough: tcsh's five conversions took `mints` **663 -> 573**, about 18 per
converted declaration. Reaching zero at that rate needs ~30 more conversions,
and the remaining mints are overwhelmingly small scalars (`&i`, `&status`) in
functions where a static is NOT safe. **The far-backed window's gate stays
closed**, and the cheap route to it that §7 hoped for does not exist.

**What it does NOT buy (2).** It does not create memory. It moves a worst-case
reservation out of a shared arena into a private bank — which is a good trade
only while the private bank has slack. See §4.

## 6. The two structural options, and their real status

Both come from `bank0-stack.md` §3.3 / §3.3b. Neither is built.

**Chaining bank-0 regions (§3.3) — plan of record, unbuilt.** A task's stack
becomes a window; frames that fall out chain to another bank-0 arena region.
Bound becomes the whole arena shared dynamically (~2,000 levels at 19 B/level)
instead of reserved statically. Overflow is caught by the existing prologue
guard made resumable; underflow needs a sentinel return address; frame extents
come from walking the `PEI`'d `_fcc_fb` chain. **Not** far-memory spill — S is
16 bits, so the live stack can never leave bank 0.

**Far-memory-backed window (§3.3b) — decided AGAINST 2026-08-03, on a gate that
has since moved.** The measurement behind it is strong: at its deepest point bsh
holds 7,150 B and can address 121 of them, so **98.3% of the live stack is
cold**, and no function reaches more than 9 bytes past its own frame across bsh,
tcsh, tar, grep and ls. The blocker is `&local` minting an absolute bank-0
address that a callee may dereference after the window would have spilled the
frame. The gate was `mints == 0`.

`mints` (`python3 tools/stack_reach.py`), against the 2026-08-03 numbers:

| | sh | tcsh | tar | grep | ls |
|---|---|---|---|---|---|
| 2026-08-03 | 34 | 669 | 52 | 34 | 46 |
| 2026-08-06 (vi shrink) | 12 | 663 | 34 | 14 | 27 |
| **2026-08-06 (tcsh shrink)** | **12** | **573** | **34** | **14** | **27** |

Every count fell; none reached zero, and tcsh's 573 still dominates. **The
decision stands, and §7's hope of reaching the gate cheaply is now measured and
closed** — five static conversions moved tcsh 90 mints, so the gate is ~30
conversions away through code that cannot safely take them.

**Blocked behind both:** increment 1.2 (exile every address-taken local) costs
~16,749 B of code against tcsh's ~3,998 B free, so it needs an eighth code bank,
i.e. the kernel TCB restructure.

## 7. Open questions worth measuring next

1. ~~**Does the static-buffer technique reduce `mints`?**~~ **ANSWERED
   2026-08-06: yes, and not nearly enough.** 663 -> 573 for five conversions.
   See §5's closing paragraph and §6's table. Closed.
2. ~~**Where does tcsh's 37 KB of heap go?**~~ **ANSWERED and WITHDRAWN
   2026-08-06** — it does not go anywhere. tcsh peaks at 6,632 B of a 37,206 B
   heap during an interactive login. The question rested on a misread klog line
   (§4). `ps` now has a HEAP column, so it can be asked of any process without
   a forensic.
3. **Is tcsh's clamp reachable in practice?** 133 pages needed against 83
   reserved. Either find the workload that walks the deepest path, or accept the
   guard as the backstop and say so explicitly. Still open, and still matters
   while the shrink is blocked.
4. **Does `NPROC` want its two arena pages back?** 147 -> 149 is available if
   `NPROC` returns to 8, but two extra consoles need the slots more than the
   arena needs the pages today.
5. **Is the aux bank ($01) reachable as a second arena?** 64 KB of RAM that
   `include/kernel.s` marks "reserved, not used". See §9.

## 8. Corrections to earlier documents

Recorded so the next reader does not trust a superseded number:

- `bank0-stack.md` §8 and `ROADMAP.md` both said **"87 of 149 pages"** for the
  worst case. It is **123 of 147** — the arena shrank by 2 for `NPROC`, and the
  `stack_measure` fix re-sized vi and tcsh upward. **`ROADMAP.md` corrected;
  `bank0-stack.md` §8 still carries the old figure and is annotated there.**
- `ROADMAP.md`'s demand-swap entry described the arena as **`$3200-$AFFF`, 126
  pages**. It is **`$2200`, 147 pages**, ending at `FGX_DP_KTASKS` `$B500`.
  **Corrected in `ROADMAP.md` 2026-08-06.**
- `ROADMAP.md` recorded **"tcsh 83 -> 55 via `-DTC_BUFSIZ=256`"**. `TC_BUFSIZ=256`
  is still set, but the 55 was measured while the allowance was suppressed; tcsh
  reads **83 (clamped)** with it restored. **Corrected in `ROADMAP.md`
  2026-08-06.**
- `check_stack_budget.py`'s "tcsh runs vi" scenario was narrowed to
  `["tcsh","vi"]` on 2026-08-05, on the expectation that login would exec the
  session shell and leave no bsh underneath. The ttyv lines have since shipped
  `on`, and the **console line still runs `/bin/sh` directly** — so bsh IS
  resident under a ttyv tcsh. Re-widened to `["sh","tcsh","vi"]`, which now fits
  (119 of 147) where it did not then (151 of 149).
- `bank0-stack.md` §8 lists tcsh as "not enabled, same size wall as 1.2". True,
  and it was additionally **clamped** until 2026-08-06 (§4).
- `bank0-stack.md` §4 rejects the **RAMRD/RAMWRT aux-bank arena** because it
  "would swallow the 80-column text page at `$0400-$07FF` that FGX wants for a
  console text mode". **That is the wrong reason.** FGX has no text-mode console
  and does not use `$0400-$07FF`. The real blocker is larger and is in the
  shipped code — see §9.
- This document's own §4 said the tcsh fix "is a campaign of targeted changes
  rather than four one-word edits". **It is five one-word edits**, and they
  work — see §4. Corrected in place, because that sentence deferred the work by
  a week. What actually blocks tcsh was found only by doing it.

## 9. The aux bank ($01): assessed 2026-08-06, and what actually blocks it

**ALTZP is the wrong switch.** It redirects `$0000-$01FF` — the direct page and
the 6502 stack page — to aux. FGX's task stacks are 16-bit-`S` regions at
`$2200-$B4FF` and its per-task direct pages are at `$B500-$C000`; neither is in
ALTZP's window. The switch that would actually move a task stack into aux RAM is
**RAMRD/RAMWRT**, which redirects all of `$0200-$BFFF`. Any discussion of "using
ALTZP for stacks" is really a discussion about RAMRD/RAMWRT.

**The blocker is that FGX's own screen lives in the aux bank.** `include/
console.s`: `CON_SHR_BASE EQU $012000 ; SHR pixel base (bank $01 shadowed)`, and
`_ConfigureHardware` (`src/kernel/main.s`) deliberately enables SHR shadowing
(`LDAL HW_SHADOW / AND #$F7`). SHR shadowing maps bank `$01` `$2000-$9FFF` onto
`$E1` — **32 KB of the aux bank IS the framebuffer**. A stack carved in aux at
any address in that range would paint itself onto the screen.

What is left of aux, outside the shadow:

| aux region | bytes | pages |
|---|---|---|
| `$010200-$011FFF` | 7,680 | 30 |
| `$01A000-$01BFFF` | 8,192 | 32 |
| **total** | **15,872** | **62** |

And the addresses are not free to choose: RAMRD/RAMWRT redirects a bank-0
address to the *same offset* in aux, so an aux arena can only exist at
`$0200-$1FFF` and `$A000-$BFFF`.

**62 pages against today's 147 is a 42% increase — but it does not buy what
hurts.** The two chunks are 30 and 32 pages; the largest single reservation on
the machine is a 74-page tcsh, which fits in neither. An aux lane would relieve
small-task and pipeline pressure, not the big-stack problem that produced this
campaign.

Against that, the cost is systemic. RAMRD/RAMWRT is a *global* redirect of
`$0200-$BFFF`, not a per-region one, so while an aux-lane task runs:

- its per-task DP page must be in aux too (DP is always bank 0), and the only
  usable aux window for it is `$A000-$BFFF` — competing with the stack;
- every syscall and every IRQ must flip back to main before touching the arena,
  the DP table or any kernel bank-0 state, and restore before `RTI`/`RTL`;
- the firmware heartbeat (`_HBTickTask`, VBL, ~60 Hz) fires asynchronously and
  runs firmware code that assumes main memory;
- SmartPort/ProDOS firmware calls already carry a documented DP-clobber hazard
  (`block.s _blkFwCall`) and would additionally need the switch pinned.

**Verdict: not worth it in this shape.** Not rejected on principle — rejected on
62 non-contiguous pages against a whole-system invariant.

**The one thing that would change the answer, and why it is not free.** If the
console wrote directly to `$E12000` instead of shadowing through bank `$01`, the
whole 48 KB of aux `$0200-$BFFF` becomes candidate arena: **190 pages**, in one
contiguous run that a 74-page tcsh fits in comfortably.

**The cost is READ speed, not write speed** — a point worth stating precisely,
because the intuitive version ("`$E1` is slow memory") gets the trade backwards.
Shadowing mirrors **writes only**: *"the IIgs hardware executes any instruction
that writes into the selected area in bank `$00` or `$01` by writing into both
... because the RAM in banks `$E0` and `$E1` runs at 1 MHz, all code that is
shadowed is executed at slow speed"* (*Programming the Apple IIgs*, p. 62). So
today the console gets **fast reads and slow writes**. Moving the framebuffer to
`$E1` makes reads slow too.

That matters here for one specific reason: **FGX's most expensive console
operation reads the framebuffer.** `Con_ScrollRegionUp` (`console_scroll.s`) is
a `MVN $01,$01` over ~30 KB of pixels — its own header notes a full SHR scroll
costs **~100 ms**, and the file already carries deferred-MVN batching and a
`FLUSH_INTERVAL` coalescing knob built to hide exactly that latency. Halving the
speed of the read half of that move makes the console's worst case worse, on the
one path that is already the worst case. Glyph rendering is unaffected — it
writes SHR and reads the font tables in bank `$04`, so it is slow-write either
way.

**And the framebuffer move does not by itself buy the arena.** RAMRD/RAMWRT is
still a global redirect with all the syscall/IRQ/heartbeat/firmware discipline
above; freeing the shadow makes the *lane bigger*, it does not make the lane
cheaper. The Memory Manager also owns bank `$01` and would have to be made to
give it up.

So the order is: this is a console-engine change with a known, adverse effect on
the console's worst path, taken to enlarge a mechanism that is not built and
whose cost is elsewhere. Measure before believing either half — time a
`MVN $01,$01` against a `MVN $E1,$E1` over the same 30 KB and compare VBLs —
but the prior is that scrolling gets materially slower.

## 10. Two model-side levers, assessed

The reservation is a *model* output. Two of its terms are over-approximations,
and both were tested this session rather than assumed.

**1. Narrow the fn-ptr allowance to address-taken functions — REJECTED,
measured.** `stack_measure` charges `maxfn` = the deepest subtree over *every*
non-entry function, because an indirect call could land anywhere. It could only
land on a function whose address is taken, which is a far smaller set. But the
two binaries that matter are exactly the counter-example: tcsh's `maxfn` head is
`dosettc` and elvis's is `v_overtype`, and **both are in their program's builtin
dispatch table** — `FGX2_LONG_PTR _Fa;dosettc;0` appears in `sh.init.data.s`.
The address-taken set already contains the worst case. Zero gain where it is
needed.

**2. Narrow the signal-handler allowance to the registered handlers — worth
~4 pages, measured.** The signal term is charged as `edge + maxfn` on the
reasoning that "the handler is some non-entry function". The handlers are
knowable: tcsh registers five that survive into the binary, and their subtrees
are

    alrmcatch        4107
    _sh_phup         4089
    pintr            2933
    pchild            254
    _sh_sem_vffree     26

against a `maxfn` of 5,133 — so the true bound is 4,107 and the model is 1,026 B
(4 pages) pessimistic. Implementable: fcc emits a tell at each `signal()` /
`sigvec()` call whose handler argument is a literal function name, and
`stack_measure` falls back to `maxfn` if any call site passes a non-literal.
**The fallback is the whole safety argument** — without it this becomes an
under-approximation, and an under-approximated stack fails silently.

A first estimate of this lever was **9 pages**, taken from the two handlers that
happened to resolve first. Enumerating all five brought it to 4. The number
above is the enumerated one.
## 11. Bank-0 audit (2026-08-06): what is down there, and what can move

Asked for directly: can anything in bank 0 be converted to dynamic allocation,
or moved to another bank? **Almost nothing can move, and that is the finding** —
the residents are there by hardware necessity, not by habit. The available win
is **compaction and right-sizing**, and it is worth 9 to 14 arena pages.

### The map below the arena, with who actually references it

| range | pages | what | verdict |
|---|---|---|---|
| `$0000-$00FF` | 1 | stale copy of the kernel DP; the live one is MM-allocated. Firmware/MM scratch this page freely | **untouchable** |
| `$0100-$01FF` | 1 | `FGX_STK_KERNEL` — the boot/kernel stack page | live |
| `$0200-$02FF` | 1 | `FGX_SYSVARS` | **DEAD — zero references in the whole tree** |
| `$0300-$03FF` | 1 | `FGX_INTVEC` gateway: module trampolines + the `IDROUTINE` tramp. Bank-0 by design (reached from other banks / firmware) | live |
| `$0400-$07FF` | 4 | nominally `FGX_INTVEC`; the loader claims only **256 B at `$0300`**, and `memmap.s` pins only `KMem_IDTramp_end < $0800` | **apparently free** |
| `$0800-$0BFF` | 4 | stage-1 code — **NOT dead**: it holds `BlkTramp`/`CoutTramp`, which the kernel JSLs for the lifetime of the system | live, and fixed (ROM loads stage 1 here) |
| `$0C00-$0FFF` | 4 | stage-2 `DIR_BUF` / `IDX_BUF` | **transient — boot only** |
| `$1000-$1FFF` | 16 | `FGX_STK_KTASKS`, per-task kernel stacks at `base+(pid<<8)`. `NPROC` = 10, so **11 are used and 5 are slack**. Measured peak use: **~58 B of each 256** | live, oversized |
| `$2000-$21FF` | 2 | `BLK_STAGE` — SmartPort's result buffer. Bank $00 is **firmware-mandated**; the ADDRESS is FGX's choice | live, relocatable within bank 0 |
| `$2200-$B4FF` | 147 | the arena | |
| `$B500-$BFFF` | 11 | `FGX_DP_KTASKS`, per-task direct pages | live |

### Why nothing leaves bank 0

- **Task stacks and kernel stacks**: the 65816's `S` is 16 bits — stack accesses
  are always bank 0. Not negotiable.
- **Direct pages**: `D` is 16 bits; DP is always bank 0. Same.
- **`BLK_STAGE`**: the SmartPort firmware writes its result into bank $00. The
  address can move; the bank cannot.
- **The `$0300` gateway**: trampolines exist precisely so other banks and the
  firmware can reach the kernel through a 16-bit bank-0 address.
- **Dynamic allocation is not available** either: the kernel heap lives in banks
  `$07-$09`, and `Task_AllocStack`'s own comment records why bank-0 pages are not
  `NewHandle`d — "a NewHandle'd bank-0 page is unsafe for handler use" (3a/3b/
  3c-1/#3), and the MM has no free bank-0 page once the TN#27 claim lands.

### The win: compaction, 9 pages safe / 14 with right-sizing — **BUILT 2026-08-06**

**And it needs no Memory Manager change at all.** TN#27 already claims
`$00/0800` for `$B800` bytes as ONE block, so anything moved *within*
`$0800-$BFFF` is invisible to the MM. (The per-region rows in stage2's
`_LoaderClaimTable` are already marked VESTIGIAL — "no longer walked".)

Walking down from the arena:

1. **Right-size `FGX_STK_KTASKS` from 16 pages to the 11 that exist** and move it
   to `$0C00-$16FF`, over the stage-2-only `DIR_BUF`/`IDX_BUF`. Same precedent
   the arena already relies on twice: it covers `$3000-$BFFF`, which stage 2 uses
   as `KERNEL_BUFFER`, and `$8000`, which the boot RAM probe touches.
2. **Move `BLK_STAGE` to `$1700-$18FF`.**
3. **Lower `FGX_STK_ARENA` `$2200` -> `$1900`, `FGX_STK_ARENA_PAGES` 147 -> 156.**

**This is built.** `FGX_STK_ARENA` is `$1900` and `FGX_STK_ARENA_PAGES` is 156;
`ps` reports `stack arena: 25/156 pages used` on the running machine. That is
**+9 pages for every task** — the same order as the tcsh shrink, without touching
vendored source, and it helps every program rather than one. A further **+5** is available by narrowing each kernel stack from 256 B to
128 B (peak use is 58 B), but that changes the `pid<<8` stride to `pid<<7` in the
allocator, the canary seed and the dispatcher check, so it is a separate step
with real risk for a fifth of the gain.

Not worth chasing: the dead `FGX_SYSVARS` page and the apparently-free
`$0400-$07FF` are **not contiguous with the arena** — live stage-1 code at
`$0800-$0BFF` sits between them and everything else, and stage 1 is loaded there
by ROM. Five pages stranded behind an immovable object.

### Lockstep list, as built

Four constants, no code: `FGX_STK_KTASKS` `$1000` -> `$0C00`, `FGX_STK_ARENA`
`$2200` -> `$1900`, `FGX_STK_ARENA_PAGES` 147 -> 156 (`include/kernel.s`) and
`BLK_STAGE` `$2000` -> `$1700` (`include/fs.s`). Everything else already reads
them symbolically — `check_baked_addrs` stays clean, and the `memmap.s` `ERR`
pin plus `tools/check_bank0_geometry.py` recompute themselves
(`bank0 geometry OK: arena $1900+156p -> $B500`).

**What proved the boot chain survives: `floppy_boot`.** It is red for an
unrelated reason (the streamlined floppy image has no `/bin/pwd` or `/bin/echo`,
so its assertions cannot pass) — but its screen shows the machine booting off the
internal 3.5" drive through stage 1, stage 2, module loading and `/etc/rc` to a
shell prompt. That is the whole boot path, on the SmartPort driver whose result
buffer just moved, with the compacted layout. Gate green 26/26 (including
`blkprobe`), full suite 55/56 with the same three pre-existing failures.

## 12. What the PDP-11 did, and where the analogy breaks

The maintainer, 2026-08-06: the PDP-11 is structurally so similar to the IIgs that 2.11BSD
should be read as prior art rather than reinvented. It is, and the comparison
pays — but it pays partly by showing exactly where the two machines diverge.

**Sourced from the kernel, not from memory (the maintainer pointed it out):** the 2.11BSD
kernel is at `examples/2.11BSD/usr/sys/` — `sys/vm_swap.c`, `sys/vm_sched.c`,
`sys/vm_text.c`, `sys/vm_proc.c`, `h/user.h`. Every claim below is cited to it.
(`vendor/2.11BSD/` carries `usr/` only, which is why an earlier draft of this
section hedged; `examples/` is the fuller tree and is gitignored.)

### The structural parallel is real

| | PDP-11 / 2.11BSD | Apple IIgs / FGX |
|---|---|---|
| per-process address space | 64 KB (or 64K I + 64K D) | 64 KB per bank |
| physical memory | up to 4 MB, 22-bit | up to 8 MB, 24-bit |
| reaching past 64 KB | MMU remaps 8 APRs | bank register + long addressing |
| kernel bigger than the space | **text overlays** swapped into a window | **far kernel bank** + code-bank packing |
| code vs data | **separate I&D space** | **separate code banks / data bank** |
| N copies of one program | **shared text** (one image, refcounted) | shared libraries (libc.so and the rest) resident; **program text is NOT** |
| memory pressure | **swap whole processes to disk** | — (this is the open problem) |
| per-process kernel stack | in the u-area, **remapped to a fixed virtual address** | `FGX_STK_KTASKS+(pid<<8)`, fixed *physical* |

FGX has independently arrived at three of these — overlays, split I&D, and a
shared libc image. That is a decent sign the analogy holds.

### Where it breaks, and it breaks exactly at our problem

**The PDP-11 has an MMU and the 65816 does not.** Every PDP-11 answer above is a
mapping trick: a process's stack sits at the top of its own *virtual* space and
lives physically wherever the kernel put it; the u-area is at a fixed *virtual*
address and the MMU points it at the current process. On the 65816, `S` and `D`
are 16 bits and the hardware forces bank 0 — bank 0 is *physical*, and there is
no register that makes some other bank appear there.

So the one thing the PDP-11 does effortlessly is the one thing FGX cannot do at
all. That is not a gap in FGX's design; it is the machine.

### What that tells us about B3 — 2.11BSD already wrote the admission rule

**B3 is the software emulation of the u-area remap**, paying a `memcpy` where the
PDP-11 paid a store to an MMU register. That is not an analogy — it is what the
code does. `vm_swap.c`'s `swapout()` reaches another process's u-area with

    savekdsa6 = *KDSA6;
    *KDSA6 = p->p_addr;        /* point kernel APR 6 at the victim's u-area */
    u.u_ru.ru_nswap++;
    *KDSA6 = savekdsa6;

The u-area is always at the same *kernel virtual* address; the MMU decides which
*physical* one that is. Address-preserving by construction. FGX has no such
register, so it must restore to the same *physical* address instead — which is
exactly why B3 is "address-preserving" and why `bank0-stack.md` is right that the
arena can never be compacted.

Three things are directly transferable, and they answer questions we were about
to answer the hard way:

**1. The eligibility rule is "sleeping interruptibly" — never "focus".**
`vm_sched.c`'s victim scan:

    if (rp->p_stat == SSLEEP &&
        (rp->p_flag & P_SINTR) || rp->p_stat == SSTOP) {

A shell blocked in `read()` on a tty sleeps interruptibly — that is *why* `^C`
reaches it. **This covers console, serial and pty sessions identically**, which
is precisely the remote-login case that broke B3's focus premise. 2.11BSD's
swapper never knew what a "focused console" was, and did not need to.

**2. Don't audit for foreign writes — LOCK.** `swapout()` opens with
`p->p_flag |= SLOCK;`, and the victim scan skips `SSYS|SLOCK|SULOCK`. Where FGX's
B3 notes propose *auditing* every path that might write into a blocked task's
stack, 2.11BSD *flags* the task while such a path is live. Both need the same
survey of the kernel, but the failure modes differ: an audit silently expires the
first time someone adds a path, a flag makes "this task is not swappable right
now" a thing the new code has to opt out of.

**3. The victim score is size plus sleep time.**

    size = rp->p_dsize + rp->p_ssize + (rp->p_slptime - maxslp << 4);

Prefer the biggest, longest-sleeping process. For FGX that names tcsh at 84 pages
blocked at a prompt, without any special case.

And one structural confirmation: `swapout()` swaps **data, stack and u-area as
three separate regions** (`p_daddr`/`odata`, `p_saddr`/`ostack`, `p_addr`/`USIZE`).
Swapping the stack *alone* — B3's whole idea — is not a narrowing FGX invented; it
is a region 2.11BSD already treated separately.

The u-area is also where the PDP-11 kept the per-process kernel stack
(`h/user.h`: `u_stack[1] /* kernel stack per user, extends from u + USIZE*64 */`),
and it is swapped out with the process. FGX holds all 11 kernel stacks
permanently resident. Same argument, region nobody has questioned.

### Shared text: done, by the text table

2.11BSD shares one text image between every process running the same binary,
precisely because memory was scarce. FGX now shares both halves: libraries
through `libc.so` and the other shared libraries, loaded once and bound into
every dynamic program by the user-space binder (`ld.mod`), and program text
through the kernel's own text table (`src/kernel/tty/text.s`), so three tcsh
sessions sharing one binary share one set of code banks rather than holding
three.

2.11BSD's version is `vm_text.c`'s `xalloc()`, with a two-level refcount —
`x_count` (processes attached) and `x_ccount` (in-core users) — so the text image
survives every process that shares it and is freed only at zero. FGX's
analogue is the `KTTY_TEXT_FIND`/`REG`/`UNREF`/`RECLAIM`/`FORK`/`SET` slots: a
sticky cache that finds or registers a loaded binary's banks, refcounts
attachers, and reclaims only once the count drops to zero, instead of a
registry keyed one segment at a time. textchurn and textreclaim probe it:
refcount balance across fork/exec/exit paths, and reclaim of a text nothing
still runs.

This was bank pressure rather than bank-0 pressure, so it did not move the
arena; it is recorded here because it was the same idea from the same
machine as the rest of this section, and the precedent said it mattered.
