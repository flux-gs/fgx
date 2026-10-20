# Bank 0 as a cache: stacks, direct pages and NPROC without an MMU

Status: EVALUATION, 2026-09-17; increments R0 (all three) and R1 built and
landed 2026-09-18, and the ALTZP spike run (sections 11, 12 and 9.2).  It answers the
question the maintainer put on 2026-09-17: the kernel stack is too small, the user
stacks are too small, NPROC is too small, all three break ordinary operation,
and any re-architecture is on the table -- including the "sliding stack
windows that can be swapped in" idea -- provided it needs no MMU and accounts
for main RAM, auxiliary RAM and shadowing, because the Second Sight Host Text
console in the patched MAME's source tree needs a 6,880-byte cell buffer the card can
scan.

Tree: `main` at `55dae2aa7`, `kernel.nproc = 12`.  Every number below is either
quoted from a primary source, read out of the tree at that commit, or taken
from a measurement recorded in the tree with its file named.  Estimates are
marked as estimates.

## 0. The answer in one paragraph

The three shortages have one cause: bank 0 is treated as a STATIC allocation
of per-task regions, held for each task's whole life, whether or not the task
is running.  The 65816 pins stacks and direct pages to bank 0, so the region
count is NPROC x (kernel stack + user stack + two direct pages), and every
knob -- deeper kernel stacks, deeper user stacks, more processes -- multiplies
against a 64 KB bank that is already three-quarters spoken for.  The way out
is to stop treating bank 0 as an allocation and treat it as a CACHE: a task's
bank-0 bytes are RESIDENT while it runs and can be PARKED -- copied out to
another bank and later copied back to exactly the addresses they left -- while
it sleeps.  That is 2.11BSD's own u-area swap transplanted, and FGX has
already built and gated it once, for one 78-page lane and session shells only
(B3, 2026-08-07).  Generalising it to every task's user image and to the
kernel stacks turns all three shortages into copy costs of a few milliseconds
that are paid only under contention, decouples NPROC from bank 0 entirely, and
needs no compiler change.  The Second Sight buffer costs no bank 0 at all: the
card reads the Mega II banks `$E0`/`$E1` directly, so the buffer goes there.
The one hardware lever nobody has spiked -- the auxiliary-memory switches,
which give a SECOND bank 0 for `S` and `D` at the same addresses -- is real,
costed in section 9, and is an add-on to the cache design rather than a
substitute for it.

## 1. What the hardware fixes, quoted

### 1.1 The stack and the direct page live in bank 0

Apple IIgs Assembly Language Programming, p. 38:

> The stack pointer (S) is a 16-bit register that points to the next
> available location on the stack ... the stack is always in bank 0.  Note,
> however, that while the 6502's stack must be in page 1, the 65816's stack
> can be in any page.

Programming the Apple IIgs (Part 1), p. 101, on native mode:

> ... a stack situated anywhere within bank $00, not limited to a memory
> capacity of 256 bytes ... Its direct page register is activated, providing
> it with the capability of placing its direct page (the equivalent of a page
> 0) anywhere in bank $00.

So a live stack and a live direct page are bank-0 bytes, full stop.  What the
hardware does NOT say is that a SLEEPING task's stack bytes must stay there.

### 1.2 The language card is 16 KB in a 12 KB window

Measured, not argued: `docs/history/audits/bank0-lc-spike-results.md`, confirmed on a real
IIgs 2026-08-13.  `$D000-$DFFF` is two independently writable 4 KB banks;
`$E000-$FFFF` is one flat, unswitched 8 KB.  FGX maps LC RAM in at boot
(`_LC_MapRam`, `src/kernel/main.s:3963-3970`) and leaves it mapped; the
per-pid kernel stacks and the interrupt-time kernel-C context live in the flat
8 KB today (`include/config.s:32,38,39`).  The CPU vectors are still fetched
from the bank-`$FF` ROM shadow while shadow-register bit 6 is clear, so the
`$FFE0-$FFFF` RAM under them is unused and the usable ceiling is `$FFE0`.

### 1.3 The shadow register, including bit 6

Apple IIgs Firmware Reference, p. 303 (bits 0-4), and Programming the Apple
IIgs (Part 1), Table 4-1, p. 78:

> 0  Text page 1 shadowing disabled
> 1  High-res page 1 shadowing disabled
> 2  High-res page 2 shadowing disabled
> 3  Super high-res buffer shadowing disabled
> 4  Shadowing of auxiliary high-res pages disabled
> 5  Reserved -- do not modify
> 6  I/O and language card operation disabled
> 7  Reserved -- do not modify

and on bit 6, the same page:

> Some of the interrupt routines used in emulation mode are in ROM in the I/O
> space of the $C07X address range.  For this code to operate, I/O must remain
> enabled in the $CXXX range of memory in bank $00, and the high 16K of RAM
> must remain mapped as a language card.  In other words, the IOLC bit of the
> shadow register must be clear.

FGX's live value is `$27` (bits 0-2 set by `_Shadow_InhibitUnused`,
`src/kernel/main.s:3919-3928`; bit 5 is the ROM 3 power-on value; bit 3 clear
because the SHR framebuffer is bank `$01` shadowed to `$E1`, `main.s:3910-3912`;
bit 6 clear).  Two consequences that matter below: bank-0 text and hi-res
pages are NOT shadowed under FGX, and the IRQ dispatcher forces bits 0 and 6
clear for the length of every dispatch (`src/kernel/sim.s:299-329`, masks
`$9F3E`/`$9F1E`, the original saved to `$E1:0119` for the ROM to restore).

### 1.4 Banks `$E0` and `$E1`

Apple IIgs Firmware Reference, Appendix H, Figure H-1 (pp. 328-329): bank
`$E0` has 24 KB of free space at `$6000-$BFFF` and bank `$E1` has 8 KB at
`$A000-$BFFF`, both "accessed through the Memory Manager ... If you try to use
this space without first calling the Memory Manager, you will cause a system
failure."  Both banks are Mega II RAM at 1.024 MHz; "language-card mapping,
I/O space, and display buffers are always active" there (Hardware Reference,
p. 35).

### 1.5 The auxiliary-memory switches

Apple IIgs Hardware Reference, pp. 33-35: the 48 KB from `$0200` to `$BFFF`
is switched between main and auxiliary memory by RDCARDRAM/RDMAINRAM
(`$C003`/`$C002`) for reads and WRCARDRAM/WRMAINRAM (`$C005`/`$C004`) for
writes, independently; and

> A single soft switch named ALTZP (for alternate zero page) switches the
> bank-switched memory and the associated stack and direct-page area between
> main and auxiliary memory.  ... writing to location $C009 turns ALTZP on and
> selects auxiliary memory stack and direct page; writing to ... $C008 turns
> ALTZP off ...

> The language-card soft switches have the same effect on the auxiliary RAM
> that they do on the main RAM: the language-card bank switching is
> independent of the auxiliary RAM switching.

These are the //e's 128 KB mechanism.  They are what section 9 is about.

### 1.6 The block move costs 7 cycles a byte

In-tree measurement, `src/kernel/process.s:1236-1237`: a byte-by-byte copy
"about 37 cycles each against MVN's 7 (apple/fgx#372)".  At 2.8 MHz that is
400 bytes per millisecond, and every copy cost below is that number.

### 1.7 The Memory Manager's attribute word

Apple IIgs Toolbox Reference Volume 1, Table 12-2, p. 489: bit 15
`attrLocked`, 14 `attrFixed`, 4 `attrNoCross`, 3 `attrNoSpec`, 2 `attrPage`,
1 `attrAddr` ("must be at a specified address when allocated.  An example is
allocating the graphics screen"), 0 `attrBank` ("must start in a specified
bank.  An example is allocating a block to be used as a direct page").  And
p. 511: "The locationPtr points to the starting address of the block only if
the attributes parameter specifies fixed address or fixed bank.  Otherwise,
locationPtr is ignored."

## 2. Bank 0 and bank 1 as they are

### 2.1 Bank 0 at NPROC 12

Derived from `include/config.s` (generated from `cfg/system.cfg` by
`tools/ninja/genconfig.py`) and `include/kernel.s`; run
`tools/check_bank0_geometry.py` rather than quoting this table.

| range | bytes | tenant | pinned by |
|---|---:|---|---|
| `$0000-$00FF` | 256 | boot kernel DP, stale; firmware scratch | firmware |
| `$0100-$01FF` | 256 | `FGX_STK_KERNEL`: no-task syscalls, every emulation-mode firmware excursion, every interrupt frame lands here first | hardware (emulation mode forces page 1) |
| `$0200-$02FF` | 256 | `FGX_SYSVARS`, dead EQU | nothing |
| `$0300-$03FF` | 256 | `SYS_TRAMP` `$0328`, `MOD_JT_BASE` `$032E`, yield mirror `$030A`, trap cells `$0310`, `IDROUTINE_TRAMP` `$0320`, page-3 vectors `$03D0-$03FF` | construction and firmware |
| `$0400-$07FF` | 1,024 | text page 1: never written at runtime; screen holes `$0478..$07F8` and `MSLOT` `$07F8` belong to slot firmware | firmware holes |
| `$0800-$08FF` | 256 | `BlkTramp` + `CoutTramp`, 70 B live, JSL'd by the kernel forever | runtime trampolines |
| `$0900-$15FF` | 3,328 | per-task KERNEL direct pages, `NPROC+1` = 13 x 256 (`FGX_DP_KKERN`) | D, per task |
| `$1600-$17FF` | 512 | slack below `BLK_STAGE` | -- |
| `$1800-$19FF` | 512 | `BLK_STAGE`, SmartPort staging | firmware-mandated bank 0 |
| `$1A00-$B1FF` | 38,912 | user-stack ARENA, 152 pages; lane = top 78 pages at `$6400` | S, per task reservation |
| `$B200-$B2FF` | 256 | `FGX_DP_KERNELC`, the shared kernel-C direct page (band `$98-$FF` saved per task at every switch) | D |
| `$B300-$BFFF` | 3,328 | per-task USER direct pages, 13 x 256 (`FGX_DP_KTASKS`) | D, per task |
| `$C000-$CFFF` | 4,096 | I/O and slot ROM | hardware |
| `$D000-$DFFF` x2 | 8,192 | language-card banks 1 and 2, BOTH FREE (`feat/412-stack-margin`, held, would put the user DPs in one) | -- |
| `$E000-$F9FF` | 6,656 | per-task KERNEL stacks, 13 x 512 (`FGX_STK_KTASKS`) | S, per task |
| `$FA00-$FAFF` | 256 | interrupt-time kernel-C DP | D |
| `$FB00-$FCFF` | 512 | interrupt-time kernel-C stack | S |
| `$FD00-$FFDF` | 736 | free | -- |
| `$FFE0-$FFFF` | 32 | vector ceiling (fetched from ROM shadow) | hardware |

### 2.2 What one task costs in bank 0 today

| item | bytes | held |
|---|---:|---|
| kernel direct page | 256 | for life |
| user direct page | 256 | for life |
| kernel stack | 512 | for life |
| user stack reservation | 768 (3 pages: 1 + argv + guard) to 19,968 (78) | for life |

So the fixed part is 1,024 B per task, 13,312 B for the 13 slots, held
whether or not the task exists, and the variable part is the reservation,
held whether or not the task is running.  A shell blocked in `read()` holds
its whole reservation while touching a few kilobytes of it -- that sentence is
in the roadmap (`docs/ROADMAP.md:3103-3104`) and it is still the whole problem.

### 2.3 Bank 1

Read from the tree, not from a document -- `include/kernel.s:37` still says
`FGX_BANK_AUX ... reserved, not used`, and it is wrong.  FGX writes bank `$01`
in two places: the SHR framebuffer, `STAL $012000,X` and neighbours in
`src/kernel/far/console/console_render.s:202-215`, SCBs at `$019D00` and
palettes at `$019E00` (`CON_SHR_BASE EQU $012000`, `include/console.s:62`);
and `GFX_PALTAB`, 256 per-scanline palettes of 32 bytes for the
scanline-interrupt palette swap (`src/kernel/syscall.s:1142-1143`, copied
with `MVN $01,$01` at `:1280-1284`).  The aux half of the 80-column text page
is cleared once by the boot loader (`src/boot/loader.s:141-161`) and written
again only by ROM `COUT` through `CoutTramp`, i.e. by the boot console and the
panic path.  FGX clears RAMRD/RAMWRT at boot through the state register
(`src/kernel/main.s:1929-1932`, `AND #$CF`) and never sets ALTZP.

| range | bytes | state |
|---|---:|---|
| `$0000-$03FF` | 1,024 | aux zero page and stack, reached only under ALTZP: unused; outside the TN#27 aux claim |
| `$0400-$07FF` | 1,024 | aux text page 1: the ROM `COUT` path writes it, so not free |
| `$0800-$1FFF` | 6,144 | claimed by TN#27, no tenant |
| `$2000-$9FFF` | 32,768 | SHR framebuffer + SCBs + palettes, LIVE, shadowed to `$E1` |
| `$A000-$BFFF` | 8,192 | `GFX_PALTAB`, LIVE |
| `$C000-$CFFF` | 4,096 | I/O (active in bank `$01` too) |
| `$D000-$FFFF` | 16,384 | aux language card.  The Hardware Reference (p. 33) says the LC switches act on both banks, so with LC RAM mapped this is RAM reachable by long addressing; NOT measured -- a one-line probe, the shape of `bank0-lc-spike-results.md` |

So 7 KB of bank `$01` is free today, plus 16 KB of aux language card pending
a probe; the 40 KB from `$2000` to `$BFFF` is the console's, and would be
free only if the console stopped being a bank-`$01` shadow -- which section 7
gives a reason to consider.  None of it is reachable by `S` or `D` without the
switches in section 9; all of it is one `MVN` from bank 0.

### 2.4 What bounds NPROC today

From `docs/history/plans/2026-09-13-chained-stacklets-evaluation.md`
section 10, checked with `check_bank0_geometry.check()`:

| NPROC | binds |
|---:|---|
| 13 | the TCB table: `FGX_TASK_TBL` `$02:0800` + 13 x 64 B runs into `FGX_CODE` at `$02:0B00` |
| 14 | the interrupt-time kernel-C context has to leave the flat 8 KB (`tools/ninja/genconfig.py:171-180`) |
| 15-16 | 16 kernel stacks of 512 B end past `$FFE0`, and the kernel DP block at `$0900` runs into `BLK_STAGE` at 15 pages (`genconfig.py:183-190`) |
| 16 | five signal handler tables and `_kAlarmTicks` are statically sized for 16 |
| ~18+ | vnode pool and `NFILE` (32 each): one cwd per process plus one root per mount, 12 + 14 = 26 of 32 today |

Two of the five are bank 0 (14, 15-16); the other three are tables.  The
stacklets evaluation's own verdict stands: stacklets do not raise NPROC.
Section 6 is what does.

## 3. The demand side, measured

### 3.1 Kernel stacks: 424 to 510 of 512, and the frames are small

apple/fgx#442, read out of the dumps by `tools/mame_test/kstkhwm_check.py`
(`docs/history/RESUME-2026-09-17b-kernel-stack-exhaustion.md`): on a run the
suite calls green, every live slice is at 464/512, 470/512, 510/512 (canary
dead) and 424/512; on the failing run all eight slices overrun to their bottom
word and the CPU ends up in bank `$7C`.  The deepest chain is exec -- "every
process on this machine is execve'd, exec opens its binary, and that open
crosses core -> far -> core -> far -> module" (`src/kernel/vfs/vfs_vnops.c:186-192`)
-- with mount(2) and namei close behind, and the `ttwrite` path at 448/512
before its buffer moved to the u-area (`src/kernel/ttyv.s:224-227`).

Measured over the 505 kernel-C functions in `src/kernel/vfs`, `src/kernel/tty`
and `src/modules`: frame sizes have mean 9.4 B, median 4 B, 90th percentile
26 B, maximum 138 B (a probe guard); the largest shipped VFS frame is
`ufs_itrunc` at 80 B.  The 42-byte `vattr` deletion (`cfcb1b158`) was worth 40
bytes of margin.  So the honest reading of the RESUME's open question -- "is
there another 100+ bytes in the exec chain, or is it death by fifty 8-byte
frames?" -- is: it is death by many small frames plus linkage, and reduction
buys one round at a time.  A structural answer has to make the slice bigger.

### 3.2 User stacks: reservations dwarf use, and the small tools are tight

`docs/history/audits/bank0-stack-baseline.md` (bytes actually touched, painted at carve and
scanned at free) and section 11 of the stacklets evaluation (S0):

| binary | reserved (pages) | measured high-water | free |
|---|---:|---:|---:|
| tcsh | 78 | 3,346 B interactive, 4,234 B largest recorded | ~15 KB |
| sh (bsh) | 18 | 344 B interactive, 1,342 B sourcing 55 commands | ~3 KB |
| vi | 24 | 624 B | ~5 KB |
| tar | 26 | 1,312 B | ~5 KB |
| ls | 13 | 1,470 B | ~1.8 KB |
| grep, wc | 4 | 542 B of 1,024 | 482, TIGHT |
| echo | 3 | 276 B of 768 | 492, TIGHT |

`tools/check_stack_budget.py -v` puts the worst co-resident scenario at
131 of 152 pages ("deepest tool in a pipeline under tcsh"), three consoles at
129, tcsh-runs-tar at 127.  The arena binds on ordinary use.  And depth is a
static guess: `CYCLE_TURNS = 8` (`toolchain/src/ld/stack_measure.py:232`)
stands in for a data-dependent quantity, `/sbin/reboot` overran by 14 bytes
with nothing trapping (apple/fgx#404), and tcsh's 117-member recursion SCC is
unguarded by construction (`stack_measure.py:573-576`).

### 3.3 Where tasks sleep, and how deep

Every `_sleep`/`_sleepUn` site was enumerated for this evaluation.  The ones
that decide the design:

- **Disk I/O never sleeps.**  "FGX's disk I/O is synchronous SmartPort PIO,
  so the transfer is already finished when the driver returns and `B_DONE`
  is set before `biowait` is reached" (`src/kernel/vfs/vfs_bio.c:37-39`); no
  `_sleep` anywhere under `src/drivers/`.  So the deepest chains -- exec,
  mount, namei -- normally run to completion without giving up the CPU.
- **Lock sleeps CAN be deep.**  Buffer, inode, vnode and superblock locks
  sleep uninterruptibly (`vfs_bio.c:338,392,480`, `ufs_inode.c:281`,
  `vfs_subr.c:437`) from under namei and vn_open.  They fire only when
  another task holds the object, which on a uniprocessor that never preempts
  kernel code means the holder itself slept while holding it -- a tty or pty
  vnode under `ttread`, mainly.  Rare, but a design that copies a sleeper's
  kernel stack must expect 460-500 live bytes occasionally, not only the
  50-150 of a shell in `read()`.
- **The shell is essentially always asleep inside kernel C** (`ttread` sleeps
  on `t_rawq`); `wait4`, `select`, pipes, sockets, nanosleep and the vfork
  parent sleep shallow, with their cross-sleep state pushed on their own
  kernel stack.
- **Nothing holds a pointer into ANOTHER task's kernel stack across a sleep.**
  Sleep channels are object addresses in kernel pools; pipe, socket and select
  state is on the sleeper's own stack.  Two contexts stand on a stack they do
  not own: interrupt frames (only ever the RUNNING task's), and the idle loop,
  which "idles here on the blocked caller's kernel stack" and enters kernel C
  from it (`src/kernel/sched.s:417-436`).

### 3.4 When a task is off the CPU, where is it

Model A: "this never preempts kernel code; the dispatcher honors it between
syscalls" (`src/kernel/toolbox.s:446-449`); compute loops reach the boundary
through `_fcc_safepoint`, which makes a `SYS_YIELD` (`toolchain/lib/fcc_runtime.s:245-250`).
So a task that is not running is in exactly one of two states: at a syscall
boundary with an EMPTY kernel stack (ready, or blocked in user mode by the
scheduler), or asleep inside a syscall with live kernel frames.  There is no
third state.  That is what makes the kernel-stack half of section 5 cheap.

A switch costs ~3,600-4,400 cycles today, 70% of it the 104-byte kernel-C
register-file copy, and forced switches are capped at 15/s
(`docs/history/plans/2026-09-09-performance-dive-results.md:673-681`).

## 4. The invariant, and what it rules in and out

`docs/history/plans/b3-stack-swap-scope.md` section 1, which is the design:

> 2.11BSD never fixes up a pointer, because the MMU means it never has to.  A
> no-MMU port keeps every one of its disciplines only to the exact extent
> that every byte returns to the address it left.

fcc frames hold absolute bank-0 addresses: the prologue `PEI`s `_fcc_fb`,
`&local` mints a bank-0 pointer that escapes into DP cells, the heap and
kernel-held syscall arguments (`toolchain/src/cc/emit.c:2117-2151`,
`docs/userland-abi.md:391`), and `tools/stack_reach.py` counts those mints at
34 for sh and 669 for tcsh.  Three families of idea follow from that, and it
is worth naming them because all three have been called "windows":

| idea | what moves | status |
|---|---|---|
| relocation, compaction, grow-by-move | live frames to new addresses | dead: pointers cannot be enumerated (`ROADMAP.md:3323-3336`) |
| far-backed SLIDING window (`bank0-stack.md` 3.3b) | cold frames spilled out of bank 0, the top K kept | dead on its own gate: `mints` had to reach 0 and did not, and driving it to 0 needs an eighth tcsh code bank |
| chained stacklets (`bank0-stack.md` 3.3, the 2026-09-13 evaluation) | nothing moves; a fresh run of bank-0 pages is linked below the current frame | alive; a compiler change (resumable guard) and a world recompile; bounded by the arena; does not raise NPROC |
| address-preserving PARK and RESTORE (B3) | the whole live extent, out and back to the SAME addresses | alive and BUILT for one lane; `b3swap`, `b3thrash`, `b3three` green; the machinery is in `src/kernel/task.s:2450-3030` |

The maintainer's "sliding stack windows that can be swapped in" is the fourth row with
one clarification: the window does not slide -- a task's bytes always come
back to its own addresses -- but WHICH task's bytes occupy a given range of
bank 0 changes over time.  Nothing about `mints` constrains it, because a
parked pointer into a parked frame is still correct the moment the frame is
back.  What constrains it is the survey B3 already did and enforces: who can
hold, write, run on, or derive state from a range while its owner is parked
(`SEF_STKLOCK`, `SEF_STKBORROW`, the `_sleep` assertion, the `Task_StkHwm`
redirect, the argv frame staged straight into the home bank by
`_La_SetStageBank`).

## 5. The design: bank 0 becomes a cache of task images

### 5.1 Two images per task, nothing fixed

Each task has two bank-0 images:

- the USER image: its user direct page plus its user stack reservation;
- the KERNEL image: its kernel direct page plus its kernel stack.

Each image has a HOME address in bank 0 (where it runs) and a HOME COPY out
of bank 0 (where it lives while parked).  A task is RESIDENT when its bytes
are at their home address.  The rule at every instant:

> The RUNNING task is resident in both images.  Every other task is resident
> only if nobody else needs its addresses.

Everything else in bank 0 -- the gateway page, the trampolines, `BLK_STAGE`,
the shared kernel-C page, the interrupt context -- stays exactly where it is.
Per task, the amount of bank 0 held FOR LIFE becomes zero.

### 5.2 The user side: an arena that may be oversubscribed

Today `Task_AllocStack` first-fits a reservation into a page bitmap and fails
with `stk ENOMEM` when no run is free (`src/kernel/task.s:645-700`).  Under
the cache the allocation has two tiers:

1. **Uncontended, exactly today's behaviour.**  If a free run exists, take it.
   Nothing overlaps, nothing is ever copied, and a machine that fits its
   working set in 152 pages behaves byte-for-byte as it does now.
2. **Oversubscribed.**  If no free run exists, the range may OVERLAP the
   reservations of tasks that are not running and are parkable.  The new task
   takes the range; the overlapped tasks are parked when it first runs.
   Choosing the range is 2.11BSD's victim rule with B3's correction: the
   victim is not the fattest sleeper but the one sitting on the addresses
   needed (`b3-stack-swap-scope.md` 2.2), so the allocator prefers a range
   whose overlapped owners have slept longest (`vm_sched.c:83`, "maximum
   f(size, slptime); or 3) if none, select the oldest").
3. **Refusal.**  If no range can be found whose overlapped owners are all
   parkable, or if the home copy cannot be allocated, `stk ENOMEM` as today.
   Out of home is a spawn-time failure, never a mid-run one; 2.11BSD's
   out-of-swap panic (`sys/vm_swap.c:107`) is the counter-example B3 already
   records.

Residency is then a scheduler concern, and the scheduler already has the
hook: `swtch` calls `Lane_Ensure` on the chosen task before the `TCS`
(`src/kernel/sched.s:330`), and `pick_next` refuses candidates that cannot be
made resident (`sched.s:105-131`).  Generalised, `Ensure(task)` becomes: for
every RESIDENT task whose user range overlaps this task's, park it; then
restore this task.  The eligibility predicate is `Lane_Evictable` unchanged
(`task.s:2742-2811`): not running, not `SEF_STKLOCK`, not `SEF_STKBORROW`, and
a READY resident keeps its bytes for the B3.3 dwell (12 ticks) while a BLOCKED
one is evicted at once, so the interactive path never pays.

What already exists and transfers without change: the home-copy lifecycle
(`Lane_HomeAlloc`/`Lane_HomeFree`), the self-patching `MVN` (`_Lane_Copy`),
the two flags and the `_sleep` panic, the borrower rule for fork children, the
argv frame staged into the home bank so a spawning resident is never
disturbed (`src/kernel/far/loader.s:2440-2470`), the reader redirect in
`Task_StkHwm` (`task.s:2033-2049`), and six gate tests.  What changes:

- **Membership.**  Today a task is a lane member iff its request is 40 pages
  or more (`TASK_STACK_LANE_MIN`) and every member gets the whole 78-page
  lane at `$6400`.  Under the cache every task is a member of its own range.
  The lane, `_laneResident`, `_laneHomeBank` and `_Lane_IsMember` become the
  per-page resident-owner map plus each TCB's own base and size.
- **The copy size.**  `_Lane_Copy` moves the WHOLE lane, `FGX_STK_LANE_PAGES*256`
  = 19,968 bytes, every time (`task.s:2707-2710`); that is the 21.5 KB per
  direction the B3 doc costs at ~40 ms per hand-over and the reason B3.3
  needed a dwell.  The design in `b3-stack-swap-scope.md` 3.4 was always the
  live extent only -- "from the current S up to the stack top ... 3 KB is
  about 8 ms" -- and the saved `SE_UserSP` is exactly that bound.  The
  general mechanism copies `[S, top]` plus the direct page.  For a shell in
  `read()` that is 3.3-4.2 KB, 9-11 ms; for a pipeline stage, 0.3-1.5 KB,
  1-4 ms.
- **The direct page rides with the stack.**  Put each task's user DP page at
  the BOTTOM of its own reservation, the page below `TCB_StackBase` (GNO's
  shape, one block with `D` at its base and `S` at its top,
  `docs/history/audits/bank0-upper-region-options.md` 6c) instead of in the fixed `$B300`
  block, so it parks and returns with the stack and the 13-page
  `FGX_DP_KTASKS` block is returned to the arena.  It costs one page of each
  reservation, which the argv frame page already sets a precedent for.  The
  kernel reaches the running task's DP through `_Sys_UserDP` and
  `TCB_DirectPage` today, both of which simply take the new address; every
  consumer of `TCB_StackBase` and `TCB_StackSize` -- the argv staging, the
  floor seed, the paint, the high-water scan -- sees the stack exactly as
  before, and only the carve, the free and the park know about the page
  below it.  (Landed that way 2026-09-18: the bottom, not the top this
  paragraph first said, for exactly that reason.)

Depth follows for free.  A reservation is no longer a lifetime cost, only a
residency footprint, so the sizing policy can stop being a fit-the-arena
exercise: tcsh at 78 pages is fine, and so is sh at 32 instead of 18 and every
tool at 8 instead of 3.  The prologue guard and the dispatcher floor check
keep the failure loud at the reservation edge exactly as today.  What the
cache does NOT do is let one task exceed the arena: chaining remains the only
route past ~38 KB of stack for a single process, and nothing measured needs
it.

Fork.  `_Fork_Snapshot` copied the parent's entire reservation into its
descriptor; since R0(c) it copies the live extent, as the soft-frame pair
already did.  Semantics do not change: a fork child still borrows its
parent's user image at the parent's addresses, the parent is pinned by
`SEF_STKBORROW` for the borrow window, and the hand-back is unchanged.  The
cache skips a borrower in every walk -- its bytes are its parent's, and the
parent is in the walk, pinned.

### 5.3 The kernel side: kernel-image slots

The flat 8 KB holds 13 slices of 512 bytes because the shift `pid << 9` is an
instruction at every site (`syscall.s:194-203`, `task.s:1334-1337`, each
behind `ERR FGX_KSTK_SIZE-512`).  Replace "one slice per pid" with "N slots,
bound on demand":

- A SLOT is a kernel direct page (256 B) followed by a kernel stack of
  `KSTK` bytes.  `N_KSLOT` slots and the interrupt-time context fill the flat
  8 KB:

  | `N_KSLOT` | `KSTK` | bytes | spare of 7,392 (8,160 less the 768 B interrupt context) |
  |---:|---:|---:|---:|
  | 4 | 1,536 | 7,168 | 224 |
  | 5 | 1,216 | 7,360 | 32 |
  | 6 | 960 | 7,296 | 96 |
  | 8 | 640 | 7,168 | 224 |

  Any of these is at least a 25% deeper stack than today's 512, three times
  deeper at four slots, and none of them depends on NPROC.  The two free
  `$D000` banks (8 KB) could hold the 256-byte direct pages instead, which
  buys 1 KB back for the stacks; that is a byte-budget choice.

- **Binding.**  A task binds a slot when it enters the kernel with an EMPTY
  kernel stack, which section 3.4 says is the only way a non-sleeping task
  ever enters it.  At that moment nothing points into the slot, so any free
  slot will do.  The dispatcher's `XBA/ASL/TCS` becomes a load of the slot
  base from the TCB (the four dead bytes `TCB_StackPtr`/`TCB_StackBank`, which
  the stacklets evaluation found are copied but never used, hold a slot
  index and a home pointer).  The slot's direct page is seeded the way
  `_Task_SeedKernDP` seeds a pid's page today -- one `MVN` of pid 0's page
  and an identity stamp (`task.s:1442-1452`) -- or restored from the home
  copy if the task has been in the kernel before.
- **Pinning.**  The running task's slot is pinned.  A task that SLEEPS inside
  the kernel keeps its slot and its binding: its frames hold absolute
  addresses (`&vattr`, `ttwrite`'s `uio`), so when it wakes it must return to
  the same slot.
- **Parking.**  When a task needs a slot and none is free, the scheduler
  parks the sleeper that has slept longest: copy `[S, slot top]` plus the
  direct page to its home copy, mark the slot free.  A shell in `read()` is
  100-200 bytes; a lock sleeper under namei is up to 500; either is a
  millisecond or two.
- **Restoring.**  When a parked sleeper is woken and picked, `swtch` must
  first make its slot available -- park whoever holds it, which is always
  possible because the holder is by definition not running -- then copy the
  image back and `TCS` into it.  This is the same pick-time demand eviction
  B3 settled on after the eager-at-block design died (`b3-stack-swap-scope.md`
  4.2b), and it is why liveness holds: the only unparkable slot is the running
  task's own.
- **Never from an interrupt.**  Binding, parking and restoring happen in
  `swtch` and the dispatcher, in task context with interrupts masked, never
  in the heartbeat.  2.11BSD's overlay-thunk races (`pdp/mch_csv.s:122-138`)
  are the warning B3 already took.

Two things must change for this to be sound, both small:

1. **The idle loop gets its own stack.**  Today `@sw_none` idles on the
   blocked caller's kernel stack and calls kernel C from there
   (`sched.s:417-436`).  Under slots that stack may be parked while the
   machine idles.  The idle arm switches `S` to a dedicated idle stack (the
   736 free bytes at `$FD00`, or the boot stack) on entry; it never returns to
   the frame it left, because it ends in `BRL @sw_pick`.
2. **Priming writes into the home copy.**  `Task_PrimeKernStack` writes the
   first-run return address into a not-yet-run child's kernel stack
   (`task.s:1478-1525`).  It writes into the child's home image instead, and
   the first bind copies the two words in.  Same shape as `_La_SetStageBank`.

The interrupt-time kernel-C context (`$FA00-$FCFF`) is untouched: interrupts
push on whatever `S` is current, which is always a resident slot, and the
kernel-C interrupt entry already switches to its own stack.  The shared
kernel-C page at `$B200` and its 104-byte per-task band are untouched too;
that band is already virtualised by `_KcDp_Save`/`_KcDp_Rest` at every switch.

What the slots buy, stated plainly: apple/fgx#442 stops being a race between
VFS depth and a 512-byte constant; the deepest chain gets 960-1,536 bytes;
adding a process costs no language card; and the 13 kernel direct pages at
`$0900-$15FF` (3,328 B) come back to low bank 0.

### 5.4 Where the home copies live

Sized by RESERVATION, not by live extent, so that parking can never fail
(section 5.2, rule 3).  Allocated at spawn.  Candidates, in order:

1. **A dedicated swap pool** from `Bank_Alloc`, the shape B3's home banks
   already have: three tcsh sessions at 20 KB each are one 64 KB bank; 32
   tasks of mixed size, kernel images included, are about four.
   `BANK_USER_COUNT` is 56 on 8 MB (`b3-stack-swap-scope.md` 4.2); FGX refuses
   to boot under 3 MB, which is 48 banks, so the pool is one to four of them.
2. **Bank `$01`'s spare 7 KB** (section 2.3), and its 16 KB language card if
   the probe says it is RAM: fixed, no Memory Manager handle, one `MVN` away.
   Enough for the kernel images of the always-asleep daemons; not enough for
   the shells.  It grows to 47 KB the day the console leaves bank `$01`
   (section 7).
3. NOT the kernel heap (`M_KERN`, 16 KB): B3's rule against `Kmalloc`ing swap
   state stands, and the sizes do not fit anyway.

### 5.5 Costs

At 7 cycles per byte, 2.8 MHz, 400 B/ms.  Per event:

| event | bytes | time | when it happens |
|---|---:|---:|---|
| park a shell's user image | 3,300-4,500 | 8-11 ms | only when another task needs its range, and only if it is blocked or past its dwell |
| restore it | same | same | when it is next picked |
| park a pipeline stage | 300-1,500 | 1-4 ms | same rule |
| park a sleeper's kernel image | 350-750 (256 DP + 100-500) | 1-2 ms | only when all `N_KSLOT` slots are held by sleepers |
| bind a slot for a user-mode task | 256 (its DP) | 0.6 ms | only if its slot was reclaimed since its last syscall |
| a context switch today, for scale | -- | 1.3-1.6 ms | every switch |

Per workload, what actually copies:

- **One session, any pipeline that fits 152 pages:** nothing.  Tier 1 only.
- **Three interactive sessions:** the B3 result, now measured -- a resident
  that is blocked hands over at once, so a keystroke on session B parks A
  (asleep in `read()`) once, ~10 ms, and A's next keystroke parks B.  At human
  typing rates that is invisible; at 10 cps on a remote pty it is 3-8% of the
  machine, which is the number the roadmap already accepted for B3.
- **Two CPU-bound tasks whose ranges overlap:** bounded by the dwell to one
  hand-over per 200 ms -- 130 swaps in the `b3thrash` run versus 532 with no
  dwell (`task.s:2762-2777`).
- **Kernel slots:** with `N_KSLOT` at or above the number of tasks asleep
  inside the kernel at once -- the shell, init, getty, update, inetd is five
  -- nothing copies.  With more sleepers than slots, each wake costs one park
  and one restore, 2-4 ms, on a path that just waited for a keystroke, a
  pipe or a second.

None of these costs is paid by a machine that fits.  All of them replace a
failure -- `stk ENOMEM`, a dead canary, a CPU in bank `$7C` -- with a delay.

### 5.6 What it does not do

- It does not let one process use more stack than the arena (~38 KB).
  Chaining is the answer to that if it is ever needed; nothing measured
  needs it.
- It does not make fork copy-on-write.  A child still borrows.
- It does not remove the reservation model; it changes what a reservation
  costs.  `stack_measure` keeps sizing, the guard keeps killing, and the S0
  windows become MINIMUMS rather than targets.

## 6. NPROC after decoupling

With the kernel image in slots and both direct pages riding with their images,
nothing in bank 0 scales with NPROC.  What is left, from section 2.4 and the
stacklets evaluation section 10:

| item | at 16 (R4 step 1) | at 32 (R4 step 2, landed) |
|---|---|---|
| TCB table, 64 B each, in the kernel bank below `FGX_CODE` | 16 slots fill `$0800-$0BFF` exactly; `FGX_CODE` is `$020C00` | 32 slots fill `$0800-$0FFF`; `FGX_CODE` is `$021000` with its lockstep list; the kernel bank holds 56,483 of 56,688, so the next growth moves the table beside the sched table (`Kmalloc` at boot, as `SE_*` already is) |
| sched table `SE_*`, 32 B each, `Kmalloc`'d | sized by `TASK_MAX_SLOTS` | 1 KB |
| kernel-C DP save table, 128 B each, `Kmalloc`'d | `CFG_KERNEL_NPROC` x 128 | 4 KB |
| signal entry, mask, ignore and catch tables (heap, 224 B) and `_kAlarmTicks` (64 B in the kernel data region) | sized for 16; `check_bank0_geometry` holds NPROC to that | the heap block is 448 B (entries to 64, masks at 64, ignores at 192, catches at 320: the stride fork's inheritance loop walks is 128); `_kAlarmTicks` (128 B) and `_kAlarmFired` (32 B) doubled in place, the data region having 184 spare rather than the 22 first counted; `check_bank0_geometry` reads both `DS` sizes and the catch offset and refuses a table shorter than NPROC |
| `VFS_NPROC`: per-pid nameidata slots (heap) and descriptor arrays (a far-bank static, 120 B per pid) | 16; the build refuses a copy that differs from `kernel.nproc` | 32; the descriptor arrays and the file table left the far bank's static for one heap arena (`VFS_FILE_BYTES`, 5,376 B, reached through `_kFileArenaPtr`; Reno's `struct file *file, *fileNFILE` shape), so `NFILE` could rise; the far bank holds 56,034 of 60,480 |
| vnode pool and `NFILE` | 32 each; the pool's structural floor (one cwd per process, one root per mount) is 30 | 64 each (floor 46; 2.11BSD's ratio); heap, `VFS_POOL_BYTES` 37,888 |
| u-area (116 B) and fd tables | `Kmalloc` per task | unchanged |
| home copies | 16 x 2 KB, a quarter of one bank | 32 x 2 KB fills the bank exactly (`genconfig` allows it) |
| the `pid << 9` and `pid << 8` shift sites | gone with the slots | -- |

Sixteen was an EQU change plus two copies of the page the EQU names, both
now read from `include/kernel.s` rather than kept: the boot image builder's
segment table (`tools/mkfgxunix.py`, which is what the loader trusts, so a
stale copy there put the kernel a page below where it was linked and booted
to a black screen) and the boot checker's (`tools/mame_test/ufsboot_check.py`).
The kernel heap, measured at the prompt through `vmstat` at 16: 63,728 of
the first bank's 65,528 in use, the second and third banks empty, so about
130 KB of headroom; the boot-time growth from 12 to 16 is about 4.3 KB.
Thirty-two was the tables above -- three byte-budget calls (the kernel bank's
last kilobyte, the far bank's static, the data region's spare), which were
The maintainer's (decision 5, taken 2026-09-18) and landed the same day as the third
column shows.  GNO ran about 32 with every C local on bank-0 hardware
stacks on this hardware, with per-binary declared stack sizes, so the number
is not speculative.  What the count buys is bounded by the user side, and
measured (2026-09-18, twenty background sleeps from the console shell) the
bound is NOT the arena: fifteen run and the sixteenth exec fails with
ENOMEM while the arena still places -- three overlaps at `$1A00` parked and
restored, never a `stk ENOMEM`.  Each FGX2 process costs two banks, code
and data, plus one libc bank per pile class that identical binaries share;
the 56-bank pool is dry at the ninth sleep, runtime Memory Manager grants
carry the rest, and the arena block table's sixteen rows fill at the
fifteenth, after which nothing can exec, `echo` included.  Six banks sat
idle as zero-reference classes in the libc registry, which evicts only when
its own sixteen slots are full.  LANDED 2026-09-18 (the maintainer: "proceed"): the
table has thirty-two rows, `BLKTAB_ROWS` in `include/fs.s`, the most its
eight-bit row walkers hold, at 128 more heap bytes and no bank; and
`Bank_Alloc` gives one cached libc class back and scans again before it
grants, which is 2.11BSD's `malloc(coremap)` freeing unused text images
with `xuncore()` and retrying once.  Measured after: twenty background
sleeps all run, five cached classes reclaimed, twenty-two rows of the
thirty-two used; the `manyproc` test spawns twenty-two and expects the
prompt back.  The next limit is the process table itself: at NPROC 32 the
boot's seven tasks and the shell leave twenty-four, and on an 8 MB machine
the Memory Manager holds banks for more than that.  Past NPROC the
two-bank cost of a small image (code and data segments) is the structural
lever; the arena's eight-page floor decides only residency.

## 7. Second Sight Host Text costs no bank 0

The requirement as the card actually states it, from the patched MAME's source tree:

- Host Text 80x43 is 3,440 cells of a character byte and an attribute byte,
  6,880 bytes interleaved, or two 3,440-byte planes that "need not be
  adjacent", plus a 32-byte control block and 48 bytes of palette
  (`docs/SECONDSIGHT.md`, "Memory each mode needs"; `cards/secondsight/TESTING.md:98-100`).
- "There is no bank number.  A slot card does not see `$00` versus `$E0`; it
  sees the Apple II video bus.  On a IIgs that is Mega II `$E0` for main and
  `$E1` for aux ... Writing straight to `$E0`/`$E1`, any address works."
  (`docs/SECONDSIGHT.md`, "Where the cell buffer can live").
- The MAME implementation reads exactly that:
  `space.read_byte(offs_t(aux ? 0xe10000 : 0xe00000) | addr)`
  (`cards/secondsight/overlay/src/devices/bus/a2bus/a2secondsight.cpp:126-135`).
- The measured bank-`$00` result -- `$0400`, `$0800`, `$2000`, `$4000` reach
  the card, `$6000`, `$9000`, `$BF00` do not -- is the shadow map, with
  shadowing enabled.

So "the framebuffer must be in shadowed RAM" is the //e-program reading of a
requirement whose IIgs reading is "the framebuffer must be in Mega II RAM".
Two facts decide it for FGX:

1. **The bank-0 route would not even work under FGX.**  `$C035` is `$27`:
   text page 1 and both hi-res pages are NOT shadowed (section 1.3), so a
   cell buffer at `$2000` in bank 0 would never reach the card without
   reversing the shadow policy that made 64 arena pages full speed.
2. **Bank `$E1` has 8 KB of free space at `$A000-$BFFF` and bank `$E0` has
   24 KB at `$6000-$BFFF`** (section 1.4), reachable from the kernel by the
   same long stores the console already uses for bank `$01`
   (`console_render.s:202-215`) -- 403 of FGX's 412 I/O sites already address
   `$E0`/`$E1` this way.

The allocation is one Memory Manager call, the shape the CDA module already
uses for its `$C018` block: `NewHandle(6,960, userID, attrLocked | attrFixed
| attrNoCross | attrPage | attrBank, $E10000)` -- "must start in a specified
bank" -- and the control block and palette sit in the same block.  Bank-0
cost: zero.  Shadowing: irrelevant.  Arena: untouched.

Two consequences for the rest of this document.  First, a console that scans
out of `$E1` directly is one the CPU renders no glyphs for -- a newline is one
byte, `start_line` -- so the Host Text console is a different, cheaper driver
than the SHR renderer, not a port of it.  Second, if Host Text becomes the
console, the SHR framebuffer's 32 KB of bank `$01` is free, which is the
whole difference between bank `$01` holding 16 parked kernel images and
holding every parked image on the machine.  Even without Second Sight, the
SHR framebuffer could be written to `$E1` directly instead of through the
bank-`$01` shadow -- that trades the 2.8 MHz reads the scroll coalescer does
on bank `$01` for 1 MHz reads in `$E1`, so it is a measurement, not a free
move.

As built (R6, section 11), the card does not replace the SHR console: it is
the display of a fourth virtual console, `ttyv3`, and the IIgs screen keeps
the first, because one keyboard serves both and a machine whose primary
screen went blank at the takeover is not a console with a card, it is a
card instead of a console.  So the second consequence is not taken: bank
`$01` stays the SHR framebuffer, and reclaiming it is the `$E1` measurement
above, a residency follow-on of its own.

## 8. Auxiliary RAM and shadowing, accounted

- **Shadowing is a write-through from `$00`/`$01` to `$E0`/`$E1`** and the
  store is stretched to 1 MHz; reads stay at 2.8 MHz (Hardware Reference
  p. 22).  FGX inhibits it everywhere except SHR.  Nothing in the design of
  section 5 lives in a shadowed range, and the arena's hi-res pages stopped
  being shadowed on 2026-08-14 (`306a8604d`).  The Second Sight buffer does
  not depend on shadowing (section 7).
- **Bank `$01` today** (section 2.3): 7 KB free, 40 KB holding the console's
  SHR framebuffer and scanline palette table, reachable by `MVN` and long
  addressing, not by `S` or `D`.  Its best use in this design is home storage
  (section 5.4).  Its LC region is 16 KB more of the same, pending a
  one-line probe.
- **Bank `$01` under the switches** (section 9): the only way it ever becomes
  `S`/`D`-reachable.

## 9. The lever nobody has spiked: a second bank 0

Section 1.5 says the hardware can map auxiliary memory at bank-0 ADDRESSES,
in two independent halves:

- ALTZP: `$0000-$01FF` and the language card `$D000-$FFFF`;
- RDCARDRAM/WRCARDRAM: `$0200-$BFFF`.

Under ALTZP, an `S` in `$E000-$FFFF` addresses bank `$01`'s language card.
That is a SECOND set of kernel-image slots, or slots twice the size, at the
same addresses, switched by one store and copied never.  Under the read/write
switches, an `S` in `$1A00-$B1FF` addresses a second 38 KB arena at the same
addresses: two resident sets with no copy between them, and the copy cache of
section 5 behind that for the third task and beyond.  It is the closest thing
this machine has to an MMU for stacks, and it has never been costed for FGX
beyond one sentence rejecting it because of the 80-column text page
(`bank0-stack.md` section 4), which FGX does not use.

What it costs, concretely:

1. **Every bank-0-addressed byte the kernel, an interrupt handler or firmware
   touches inside a switched half must be valid in WHICHEVER half is
   current.**  For the `$0200-$BFFF` half that is the gateway page
   (`$0300-$03FF`, including the yield mirror the heartbeat writes), the
   trampolines at `$0800`, `BLK_STAGE` at `$1800`, the shared kernel-C page
   at `$B200`, and the SmartPort firmware's screen holes and `MSLOT` at
   `$07F8`.  They would have to move out of the half (the 736 free bytes at
   `$FD00` and a `$D000` bank can take the gateway, the trampolines and
   `BLK_STAGE`; the kernel-C page could ride with the slots) or the switch
   would have to be off whenever they are touched, which for the heartbeat
   means at every interrupt.  For the ALTZP half it is only page 1 and the
   interrupt context, which is far more contained.
2. **Bank `$01`'s current tenants must leave the switched half.**  The SHR
   framebuffer at `$01:2000-$9FFF` and `GFX_PALTAB` at `$01:A000-$BFFF` sit
   inside the read/write half, and the framebuffer is shadowed to `$E1`; a
   stack write there would paint the screen at 1 MHz.  Section 7's move of
   the console to `$E1` direct is a prerequisite for the read/write half, not
   for the ALTZP half.  All three switches are bits of the state register
   `$C068` (Hardware Reference p. 32, Table 3-2), which FGX already drives
   with a read-modify-write at boot to clear RAMRD and RAMWRT
   (`src/kernel/main.s:1929-1932`), so the flip is one `STAL $E0C068`; the
   ALTZP bit's polarity in the OCR'd table reads inverted from the `$C008`/
   `$C009` sense on p. 35 and is the first thing the probe settles.
3. **Firmware excursions run in whichever half is current.**  The SmartPort
   call bounces to page 1 with `D = 0` and no `SEI` (`block.s:722-818`); under
   ALTZP that is aux page 1 and aux zero page, which is RAM either way, but
   the driver would have to force the switch off around the excursion the way
   it already brackets the LC state, and every interrupt that arrives inside
   it would see the forced state.
4. **It is a two-way switch.**  It doubles residency; it does not remove the
   need for the cache.  It is worth exactly one copy per switch between the
   two halves' occupants, and nothing when only one half's occupants are
   active.
5. **It has never been measured under FGX.**  The Hardware Reference describes
   it as a //e-era facility; whether the FPI honours it for native-mode
   accesses to bank-0 addresses is a MAME probe first and a real-IIgs probe
   second, exactly as the LC spike was run.

Verdict: a real option, ranked after the software cache because the cache is
needed anyway, costs no global state, and has its safety survey done.  The
spike is cheap -- a boot-time probe that writes distinct canaries through both
halves of both switches and reads them back, then leaves ALTZP on through the
suite -- and it should be run before anyone designs against it either way.

### 9.1 The "it broke the handlers up in `$FFxx`" question

Asked 2026-09-17: did an earlier ALTZP or RAMRD/RAMWRT attempt break
interrupts by overwriting the handlers at `$FFxx`?  The record, checked in
`git log --all` and the docs:

- **No stack experiment with either switch has ever run.**  RAMRD/RAMWRT
  appear only in boot-time text-page clearing (`85b634560`, `b06995218`,
  2026-04-20) and in `simtest`'s MMU-steering reset (`058060c30`, `23b940766`,
  2026-05-26); ALTZP appears in one paragraph, `docs/history/audits/bank0-stack-status.md`
  section 9 (2026-08-06), which calls it "the wrong switch" because the task
  stacks and direct pages were at `$0200-$BFFF` then.  That verdict predates
  the 2026-08-13 move of the kernel stacks into the language card, which is
  inside ALTZP's window.
- **The `$FFxx` story is the language card, twice.**  First the fear:
  `docs/history/audits/bank0-assessment-review-response.md` rated LC RAM high-risk because
  "native vectors live at `$00:FFE0-$FFFF`, inside the space".  The spike
  measured that wrong (`docs/history/audits/bank0-lc-spike-results.md`, 97/97 with LC RAM
  mapped and interrupts firing).  Then the real casualty, apple/fgx#242 and
  the CDA work of 2026-09-15: ROM code that expects Monitor ROM under
  `$D000-$FFFF` -- the Desk Manager, Text Tools through the slot-3 80-column
  firmware, `$FC58`, `$FDED`, the `$FFFA` vector -- found FGX's kernel stacks
  there instead, and a harness dump that walked `$C080-$C08F` remapped the
  card under itself.  Both were closed by brackets that save the state
  register and force the state each side needs: `KTTY_KC_ENTER_IRQ` forces
  RAM in for the interrupt-time kernel-C context and puts ROM back if that
  is what it found (`include/kernelc.s:536-582`); `_BootCon_PutChar` forces
  ROM in around `$FDED` (`src/kernel/boot_console.s:144-162`).

Why the vectors themselves are not at risk, from the Firmware Reference,
p. 192, "The built-in interrupt handler":

> If I/O shadowing is on, then the system ROM in bank $FF is shadowed (and
> readable) in bank $00.  The system jumps indirectly through the interrupt
> vector located either at EIRQ ($FFFE, $FFFF) if it was running in emulation
> mode when the interrupt occurred or at NIRQ ($FFE4, $FFE5) if it was
> running in native mode.  ... the 65C816 uses the interrupt vector located
> in the RAM vector table if I/O shadowing is off and uses the vector located
> in the ROM vector table if I/O shadowing is on.  If you have not correctly
> set up the RAM vectors and you turn off I/O shadowing, the system will
> fail.  Both EIRQ and NIRQ jump to ROM located within the soft-switch area.

FGX keeps I/O shadowing on (bit 6 clear) and the IRQ dispatcher re-forces it
on every interrupt (section 1.3), so the vector fetch reads the ROM image
whatever RAM -- main LC, aux LC -- sits under `$FFE0`; nothing in FGX writes
those 32 bytes.  The stub the vectors name is at `$00:C071`, in I/O space,
which neither the LC switches nor ALTZP touch; it jumps to the bank-`$E1`
dispatcher, which jumps to `_KernIrq_Dispatch` in the kernel bank, which
saves registers at `$E1:0108-$0119`.  Nothing on the entry path executes
from or reads `$00:D000-$FFFF`.

So the workaround for ALTZP is the discipline FGX already applies to the LC
state, plus one bit of the same register:

1. **Seed the interrupt-time kernel-C context in both halves** at boot
   (`_KcDpIrq_Zero` runs once per half), so an interrupt taken with ALTZP on
   lands on a seeded floor and register file; or extend `KTTY_KC_ENTER_IRQ`
   to save STATEREG bit 7 beside bit 3, force main after the `TXS` onto the
   interrupt stack, and restore it before `LEAVE`'s `TCS`.  Seeding both is
   simpler and has no ordering hazard.
2. **Force ALTZP off around every firmware excursion** the way ROM is forced
   in around `$FDED`: the SmartPort call (`_blkFwCall`, which zeroes `D` and
   bounces to page 1), `CoutTramp`, `IDROUTINE`, `PWRUP`.  The SmartPort
   excursion runs with interrupts enabled (`block.s:722-818`, no `SEI`), the
   sharp edge the LC spike already named; any state bracket around it,
   ALTZP or LC, needs that closed.
3. **If the probe shows the vector fetch coming from aux RAM under ALTZP**,
   contradicting p. 192, copy the ROM's 32-byte vector table into RAM at
   `$FFE0-$FFFF` in both halves at boot -- the remedy the Firmware Reference
   prescribes for the shadowing-off case, and sound here because the vectors
   name `$C071` stubs that are visible in every state.
4. **Leave the RAMRD/RAMWRT half for later.**  Its window holds the gateway
   page, the trampolines, `BLK_STAGE`, the shared kernel-C page and the
   console's 40 KB of bank `$01` (section 9, item 1 and 2); ALTZP's window
   holds only page 1, the boot DP and the language card, which is where the
   kernel images live.

What cannot be reasoned away: whether the FPI honours ALTZP for native-mode
accesses at all.  The Hardware Reference presents it as a //e facility and
the state register lists it as live (Table 3-2); the probe settles it.

### 9.2 MEASURED, 2026-09-17: the probe ran (`docs/history/audits/bank0-altzp-spike-results.md`)

Commit cb8370bb5 (archived history), MAME.  In native mode with the state register's bit 7
set, bank-0 long loads and stores, a push through `S` and a store through `D`
all reach bank `$01`, main is untouched, the aux language card is RAM, and
RAMWRT/RAMRD redirect `$0200-$BFFF` the same way.  The polarity is bit 7 = 1
for aux; the OCR'd Table 3-2 above is inverted.

The `$FFxx` fear resolves into a fact: on every interrupt the ROM 3 interrupt
manager writes `$08` to the state register through `$E1:C068` at `$FF:BD7B`
(ALTZP off, main RAM, language card to ROM) and writes the caller's saved
value back at `$FF:BF48` before its `RTI`.  The native frame is pushed into
the live half and popped from the same half; every FGX interrupt handler runs
in main.  So of the four workaround items above, 1 and 3 are unnecessary, 2
is measured working for SmartPort, the Toolbox and ROM `COUT` during a full
boot with the switch on, and 4 stands.  With ALTZP left on after the flip,
FGX boots to a shell on aux page 0/1 and the aux language card.  Two early
probe runs stormed; the cause was an `MX` directive in the first version's
mirror loop that misdeclared the index width, so Merlin32 emitted one-byte
immediates a 16-bit `X` read as two (the spike document, section 4).  The
first text reproduces it 3 of 3, the one-line mutation 1 of 1, and turning
the switch back off after the soak passes, so the switch was never involved.
The full-suite result is in the spike document.

## 10. Everything else considered, and why not

- **Shadow-register bit 6 (IOLC), for a flat 64 KB bank 0.**  Costed in
  `docs/history/audits/bank0-upper-region-options.md` section 5 and re-surveyed for this
  evaluation: 403 of 412 I/O sites are already `$E0`/`$E1`, and only three
  runtime sites address bank-0 I/O -- but the SmartPort firmware is CALLED in
  bank `$00` on every disk transfer (`src/boot/loader.s:417`), the ROM's
  interrupt entry stub lives at `$00:C071`, the CPU vectors would become
  FGX's to own, and the IRQ dispatcher clears the bit on every interrupt.
  The prize is 4 KB, because the RAM behind the I/O hole IS the second
  `$D000` bank the language-card route already reaches.  Rejected, still.
- **Everyone at the same address (the pure sliding window).**  Give every
  task the same bank-0 stack address and copy on every inter-task switch.
  It is section 5 with tier 1 deleted: it pays 1-11 ms on every switch
  between different tasks, including every pipe hand-off, where the
  oversubscribed arena pays only when 152 pages are actually exceeded.
  Dominated.
- **The far-backed window.**  Dead on `mints` (section 4).  Reopens only
  after every address-taken local is exiled, which needs tcsh's eighth code
  bank and was measured at ~16.7 KB of code against ~4 KB free.
- **Chained stacklets now.**  The evaluation stands and S0 is done; the plan
  needs a resumable guard, a world recompile, owner-tagged pages for fork,
  and a longjmp story.  It buys per-process depth past a reservation, which
  the cache makes cheap to reserve instead.  Keep it for the day a single
  process needs more than the arena.
- **One kernel stack for the whole system, with restartable syscalls.**  If
  no kernel path ever slept with frames live -- every sleep unwound to the
  dispatcher and the syscall restarted from the top -- one 8 KB kernel stack
  would serve every task.  There are 24 sleep sites in 12 files, which is
  small; the callers are not restartable (`ttread` mid-line, `ttwrite`
  mid-buffer, buffer-cache `goto loop` under namei), and it is not BSD's
  design: `tsleep` in the middle of anything is the whole point of a
  per-process kernel stack, and FGX ports the VFS from Reno verbatim.
  Rejected on divergence; slots get the depth without it.
- **Soft C stacks (exile-all).**  Moves ~80% of stack bytes into the data
  bank and leaves 19 B/level of linkage in bank 0; measured, works for bsh,
  does not fit tcsh's code banks.  Orthogonal to the cache; still blocked on
  the same size wall.
- **Shrinking kernel stacks to make room** (`ROADMAP.md:3085-3087`, 256 to
  128).  Written when the measured peak was 58 B; the peak is now 510.
- **Carving 52 arena pages for 1 KB kernel slices** (the RESUME's option).
  Works, costs a third of the arena for life, and stays NPROC-linear.  Slots
  give more depth for no arena.
- **`feat/412-stack-margin`** (user DPs into a `$D000` bank, arena 165).
  Its DP move is SUPERSEDED by R2, which put the user DP into the
  reservation directly and reached the same 165 pages that way; its S0
  measurements stand.

## 11. Increments and gates

Each is abortable and each leaves the tree shippable.

- **R0 -- three changes that stand alone.**
  (b) **LANDED 2026-09-18** (`feat/bank0-cache-r0`): `swtch` stands on
  `FGX_STK_SWITCH`, 512 bytes at the top of the mapped `$D000` bank, from
  `@sw_pick` to the resume `TCS`, idle arm included; painted, canaried and
  measured at 116 of 512.  It went first because R1 needs it: the scheduler
  cannot park or restore a kernel image it is standing on.
  (a) and (c) **LANDED 2026-09-18** (`feat/bank0-cache-r0`), on decision 7:
  a fact found while designing them is that live-extent copies and the
  exact paint-scan high-water mark cannot both exist on addresses two tasks
  share (bank 0 below the incoming task's `S` keeps the previous occupant's
  bytes, a copy that moves only `[S, top]` cannot carry a task's deeper
  excursions out, and repainting costs as much as copying).  So the sampled
  mark went in first: the dispatcher records the deepest user `S` it sees at
  a syscall entry, per pid, and `Task_StkHwm` reports that for a region two
  tasks have shared (a lane member, a snapshot-fork parent) and the exact
  scan for a private one; the `stkhwm` log line says `sampled` in place of
  the scan's stopping word.  The park-time sample of decision 7 is R2's,
  where the user-image park computes the extent anyway.  Then (a): the lane
  hand-over moves `[S, top]`, `S` the lower in-lane of the saved user `SP`
  and the primed first-run `SP`, instead of all 19,968 bytes; measured on a
  session shell spawning a session shell, four hand-overs and both shells'
  output whole (`lanetest`).  And (c): a snapshot fork saves `[S, top]` of
  the parent instead of the whole reservation, the descriptor carrying the
  live base and length so the restore is unchanged; the parent is marked
  shared.  The ten fork tests pass; the gate on the final build is green,
  43 of 43.
- **R1 -- kernel-image slots** (section 5.3), the apple/fgx#442 fix.
  **LANDED 2026-09-18** (`feat/bank0-cache-r0`): six slots of 1,216 bytes at
  `$E000`, slot pages at `$D000-$D5FF`, the interrupt context immediately
  above the slots at `$FC80`, home images 2 KB per pid in one `Bank_Alloc`
  bank; `kernel.kslots` and `kernel.kstk` are the knobs.  Binding, parking
  and restoring live in `_Slot_Ensure` (task.s), called from `swtch` on the
  switch stack; the dispatcher reads the running task's page and stack top
  from `_kCurKDP` and `_kCurKStkTop`.  Measured on the smoke boot: the exec
  chain at 470 of 1,216 with 746 spare, the deepest slot boot's at 488, all
  six slots used and two tasks parked on an ordinary boot and shell.  Gate
  green: 42 of 42, the multibank sweep, and the runtime oracle at 616 of 616
  validated with every chunk reaching its end -- the truncation apple/fgx#442
  is titled for.  With `kernel.kslots = 1` the fork, pipe, respawn and pty
  tests pass and the kernel log shows a park and a restore on every switch.
  That mutation also found and fixed a defect: init's bind wrote a first-run
  frame over the bind's own return address on boot's stack, which six slots
  hid.  The new `kslots` test reads the bind lines from the log and gates
  `kstkhwm_check` (ratchet 256).
- **R2 -- the user image** (section 5.2).  **LANDED 2026-09-18**
  (`feat/bank0-cache-r0`), in two commits.  First the cache itself: every
  task is a member of its own range.  When the arena has no free run for a
  request of `kernel.stkover` pages or more -- default 40, the session
  shells, so a machine that fitted before behaves as it did -- `Task_AllocStack`
  lays the range over tasks that are not running and can be parked, parks
  them then and there (live extent, to a home of 2 KB units in a swap bank
  the kernel takes from `Bank_Alloc` as needed), and the scheduler brings
  each back to its own addresses at its next pick (`Uimg_Ensure`, task.s;
  `Uimg_CanRun` in `pick_next`).  Two session shells do not fit a 152-page
  arena side by side, so a shell spawning a shell -- the case the lane's
  spawn hand-off existed for -- has no clearable range: it is placed anyway,
  built in its home (the paint and the argv staging pointed there through a
  24-bit base), and comes in at its first pick once its parent is in
  `wait()`.  The lane, its membership tables and its far-bank staging slot
  are gone; the eligibility rule, `SEF_STKLOCK`, `SEF_STKBORROW` and the
  dwell carry over.  Then the direct page: the first page of the
  reservation, below the stack, zeroed at the carve, parked and restored
  with it; the pid-indexed block is gone and the arena is 165 pages, up to
  the kernel-C page at `$BF00`.  Measured: a backgrounded shell asleep is
  parked by a second and echoes from its restored frames after it
  (`stkover`); a shell spawned by a shell is built in its home and both
  echo, through four hand-overs (`stkdefer`); the fork, exec, pipe, respawn
  and stack-report tests pass; gate green on the cache commit, 43 of 43.
  The knob defaults ON for the shells rather than OFF as this bullet first
  said, because OFF would have lost the third console the lane gave.  The
  workout this bullet asked for was run as a local mutation -- the arena
  clamped to 100 pages (60 cannot hold a 78-page shell at all) with any
  request allowed to overlap: twenty tests pass, smoke, both overlap tests,
  the pipe, respawn, fork, pty, argv and stack-report tests among them;
  the nested-shell run alone parked thirteen times and restored eleven, the
  backgrounded-shell run placed four ranges over sleepers, parked
  twenty-four times and restored twenty-one, with no refusal and no
  `ENOMEM`.  The `b3*` tests and the attribution taps went on 2026-09-07
  (0e018a70b), so "no foreign write into a parked image" rests on the
  survey in the B3 scope document and on the outputs above coming back
  whole, not on a tap.
- **R3 -- reservation policy.**  **LANDED 2026-09-18** (`feat/bank0-cache-r0`),
  provisionally: the maintainer had no measured basis for the sizes and chose to run
  the recommendation and adjust from use.  The linker writes a stack hint of
  at least five pages (`MIN_STACK_PAGES`, fgx_ld), so a tool reserves eight
  pages with the argv frame, the guard and the direct page, where the
  smallest reserved four; a binary whose model asks for more is unchanged.
  The session shell is NOT raised to 32 as section 5.2 proposed: its
  reservation is sized so the stack guard fires before its script arena
  silently truncates (`tools/sh-fgx2/gen_sh_link.py`, apple/fgx#12), and
  `srcdepth_loud` guards exactly that, so a floor above it would trade a
  loud death for a silent one.  `kernel.stkover` is 1: any request may be
  laid over a parked sleeper instead of failing, which is what makes the
  floors affordable -- with them an idle three-console machine reserves
  more than it did and a pipeline under a session shell reaches the arena's
  edge.  The stack budget check reports a scenario past the arena as a
  note, since it parks rather than fails, and keeps failing the build for a
  binary that cannot fit the arena alone.  The S0 windows are recorded in
  the stacklets evaluation as minimums; shrinking toward them waits on the
  cycle guards (S1), without which a window is a silent ceiling.  The
  readout for adjusting: the klog lines `stkover`, `stkdefer`, `upark`,
  `urest`, and the STK and HWM columns of `ps`.  Measured on the commit:
  gate green, 43 of 43 with the fcc sample; the full suite 135 passed, 0
  failed, 6 skipped by configuration; the boot's own tools carve 1,792
  bytes where they carved 768, and the four-stage pipeline under a session
  shell is 138 of 165 pages before anything parks.
- **R4 -- NPROC 16, then 32** (section 6).  **16 LANDED 2026-09-18**
  (`feat/bank0-cache-r0`): `kernel.nproc` goes from 12 to 16, and because
  sixteen TCBs fill the page under the code exactly, `FGX_CODE` goes from
  `$020B00` to `$020C00` with the linker script's `ORG`, stage2's
  `KERNEL_DEST` and the ceiling checker's sample in lockstep; `VFS_NPROC`
  follows, as the build's check demands, and the far bank's function-pointer
  patch table is regenerated for its moved static.  The first build booted
  to a black screen: the boot image builder carried its own copy of the
  kernel's page, so the loader put the kernel where it was no longer linked.
  That copy and the boot checker's now read `include/kernel.s`.  Measured:
  kernel bank 55,607 of 57,712, far bank 58,201 of 60,480, heap 63,728 of
  the first bank's 65,528 with two banks empty (section 6); the smoke, slot,
  ps, respawn, both overlap, pty flush, stack high-water and vmstat tests
  pass on the rebaked image; gate green (43 of 43, the multibank sweep, the
  runtime oracle at 235 of 235) once the six VFS fixture goldens that carry
  `VFS_NPROC` were regenerated, thirteen lines each way; the full suite 135
  passed, 0 failed, 6 skipped by configuration.  **32 LANDED 2026-09-18**
  (decision 5, the maintainer): `FGX_CODE` rises another kilobyte to `$021000`, the
  signal block doubles its stride to 448 bytes, the alarm tables double in
  place, `VFS_NPROC` follows, the vnode pool and `NFILE` go to 64, and the
  file table with the per-process descriptor arrays leaves the far bank's
  static for a heap arena (section 6, third column); the same six goldens
  move again, constants only.  Measured: kernel bank 56,483 of 56,688, far
  bank 56,034 of 60,480.
- **R5 -- the ALTZP spike** (section 9).  **RUN 2026-09-17**, section 9.2 and
  `docs/history/audits/bank0-altzp-spike-results.md`.
- **R6 -- Second Sight Host Text console.**  A driver campaign of its own; the
  memory question is closed by section 7.  **LANDED 2026-09-18**
  (`feat/bank0-cache-r0`), planned and recorded in
  `2026-09-18-second-sight-console-plan.md`: a five-site seam in the console
  (`console_backend.s`) and a module, `sscon`, that keeps the card's cell
  buffer a mirror of the console's 100-row ring in a 16,080-byte Memory
  Manager block in bank `$E0` -- bank `$E1`'s 8 KB could not hold the ring,
  and the ring is what makes a scroll one byte -- so the CPU renders no glyph
  and bank 0 pays nothing.  **Revised the same day:** the card is the
  display of a fourth virtual console, `ttyv3` (`VC_CARD`), with a getty of
  its own, and the IIgs screen keeps the first; one keyboard serves both,
  Option-4 giving it to the card's console and Option-1..3 taking it back.
  Measured: the getty's prompt on the card with the shell still on the IIgs
  screen, all 8,000 ring cells of `ttyv3`'s bank equal to the mirror after
  scrolling, and the virtual-console and cursor tests passing with the card
  present.  Bank `$01` therefore stays the SHR framebuffer; the follow-on
  that reclaims it is section 7's `$E1` measurement, not this increment.
  The fourth getty made seven steady sleepers for six kernel-image slots,
  which reopened decision 2 (section 12): seven slots of 1,024 now.

## 12. Decisions this needs

1. Proceed with R0 and R1 as the apple/fgx#442 fix, rather than another
   round of frame shaving.  **DECIDED 2026-09-18: yes; both landed.**
2. `N_KSLOT` and `KSTK`: four of 1,536, six of 960, or the direct pages in a
   `$D000` bank -- a byte budget.  **DECIDED 2026-09-18: six of 1,216 with
   the direct pages in the `$D000` bank**, which covers a three-console
   machine's steady sleepers without a copy.  **REOPENED the same day by
   R6:** the card's console adds a fourth getty, so the machine has seven
   steady sleepers (init, update, inetd, the console shell, three gettys)
   for six slots, and the two that share the sixth park and restore each
   other on every wake -- measured at 132 cycles in 180 s with a vi session
   on VC1, 264 lines in the 4 KB klog ring, which lost a test's needle.
   Seven slots fit at 1,024 bytes each (7 x 1,024 under `$FFE0`; the exec
   chain measured 470), not at 1,216.  **DECIDED 2026-09-18 (evening):
   seven of 1,024.**  The slot stacks run `$E000`-`$FBFF`, the interrupt
   context sits at `$FC00`/`$FD00`, the switch stack stays at `$DE00`; the
   exec chain uses 470 of 1,024 and the boot stack keeps 560 spare, and
   the churn is gone -- the test whose needle the ring lost passes again.
3. Home storage: bank `$01` first, then a swap pool; and whether the SHR
   framebuffer moves to `$E1` to free the rest of bank `$01`.  Kernel
   images took one `Bank_Alloc` bank (2 KB per pid).  **User images, taken
   2026-09-18 with R2: a swap pool** -- runs of 2 KB units in up to four
   `Bank_Alloc` banks, taken as needed and kept once taken, granted at the
   overlapper's spawn for itself and every task it lands on.  Bank `$01` is
   untouched.  R6 did not move the framebuffer: the card displays a fourth
   virtual console and the IIgs screen keeps the SHR console, so bank `$01`
   stays in use (section 7).
4. Reservation policy after R2 (section 5.2, "depth follows for free").
   **DECIDED 2026-09-18, provisionally: a five-page floor on every hint,
   the session shell unchanged, the overlap knob at 1, the budget check
   demoted to a note** -- to be adjusted from measurement in use, which
   The maintainer preferred to guessing sizes (section 11, R3).
5. The NPROC target, and whether the TCB table moves or `FGX_CODE` rises.
   **16 TAKEN 2026-09-18 with `FGX_CODE` rising one page**, the page being
   free.  **32 DECIDED AND LANDED 2026-09-18** (the maintainer: "let's move to 32"),
   the three byte budgets of section 6 resolved as: the table stays on the
   bank with `FGX_CODE` at `$021000`, 205 bytes left below the ceiling, so
   the next kernel growth moves it off; the far bank's descriptor static
   became one heap arena with the file table, which let `NFILE` rise with
   it; the alarm tables doubled in a data region that had 184 bytes spare,
   not the 22 first counted.
6. Whether to run the ALTZP probe now, so section 9 stops being a paragraph.
   **DECIDED 2026-09-17: run**; section 9.2.
7. The high-water mark under live-extent copies (R0(a), R0(c), R2).
   **DECIDED 2026-09-18: sampled marks for parkable tasks** -- the deepest
   user `S` recorded at every syscall entry and at every park, BSD's
   statclock shape -- with the exact paint scan kept for tasks whose region
   is private.  The alternative, whole-image copies, keeps the exact marks
   and today's costs.  The entry sample landed with R0(a)/(c); the park
   sample lands with R2's user-image park.

## 13. Sources read for this evaluation

Primary: Apple IIgs Hardware Reference pp. 22-23, 30-35; Apple IIgs Firmware
Reference pp. 303, 328-329; Apple IIgs Toolbox Reference Vol. 1 pp. 488-489,
511; Apple IIgs Assembly Language Programming p. 38; Programming the Apple
IIgs (Part 1) pp. 78, 101; `vendor/2.11BSD/usr/sys/sys/vm_swap.c`,
`vm_sched.c`.

Tree: `include/config.s`, `include/kernel.s`, `src/kernel/sched.s`,
`src/kernel/syscall.s:85-235`, `src/kernel/task.s:645-700,1322-1525,1994-2160,2450-3030`,
`src/kernel/process.s:1395-1560`, `src/kernel/far/loader.s:2440-2470`,
`src/kernel/far/console/console_render.s`, `src/kernel/main.s:3900-3970`,
`src/kernel/sim.s:239-330`, `toolchain/lib/fcc_runtime.s:205-250`,
`src/kernel/vfs/vfs_bio.c`, `src/kernel/vfs/vfs_vnops.c:177-202`.

Record: `docs/history/plans/b3-stack-swap-scope.md`, `docs/history/plans/bank0-stack.md`,
`docs/history/audits/bank0-stack-baseline.md`, `docs/history/audits/bank0-lc-spike-results.md`,
`docs/history/audits/bank0-upper-region-options.md`, `docs/history/audits/bank0-assessment-conclusions.md`,
`docs/history/audits/kernel-scratch-census.md`, `docs/history/audits/bsd-uarea-reference.md`,
`docs/history/plans/2026-09-13-chained-stacklets-evaluation.md`,
`docs/history/RESUME-2026-09-17b-kernel-stack-exhaustion.md`,
`docs/ROADMAP.md:2960-3346`; the patched MAME's `docs/SECONDSIGHT.md`,
`cards/secondsight/TESTING.md`, `a2secondsight.cpp`.
