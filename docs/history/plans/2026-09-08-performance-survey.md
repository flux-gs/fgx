# Performance: what is measured, what it costs, and where a deep dive should start

Written 2026-09-08 at the maintainer's request, to aggregate work that is currently
spread across nine work items and one roadmap section.  **This file is a survey,
not a plan.**  It collects numbers that already exist and says which ones are
load-bearing; it does not choose the work.

Nothing here is new measurement.  Every figure is cited to the issue, checker or
commit that produced it, so the deep dive starts by re-taking the ones that
matter rather than by trusting this file.

---

## THE HEADLINE: one problem is being tracked as four

**Every FGX2 binary carries its own copy of the libc pile.**  That single fact
produces the tree's largest measured costs in three different units, and it is
filed four separate times because each filing saw one unit:

| seen as | where | measured |
|---|---|---|
| exec LATENCY | ROADMAP "Binary size and load time" | `/bin/login` is 60 KB; its `execve` costs **~630 ms**, the dominant term left in the login path after apple/fgx#50 took it 3.3 s -> 0.8 s |
| BOOT time | apple/fgx#362 | 25-30 s to the console prompt; the 15-27 s window is **310,259 bytes** of userland binary loading at ~25 KB/s |
| BANK pressure | apple/fgx#37 | piles used to be byte-identical at 62,753 B so all tasks shared **one** bank; now `cat` 26,426 / `echo` 18,401 / `ls` 41,291 differ, so N co-resident tasks hold **N banks**.  Three private copies before the first prompt, a fourth as soon as `ls` runs |
| DEMAND | apple/fgx#62 | elvis's data segment is 65,433 of 65,536 -- **103 bytes free** |

`/bin/sh` at 114,146 bytes is the single largest item on the boot critical path
(apple/fgx#362).  `/bin/getty` is 52,605 and TWO of them load concurrently with
it, for virtual consoles nobody is watching during boot.

**This is the highest-leverage target in the tree and no single item makes the
case for it.**  That is the main reason this file exists.

---

## Category A -- the pile tax

**Items:** apple/fgx#37, apple/fgx#62, ROADMAP "Binary size and load time"
(line 4097), and the load half of apple/fgx#362.

The roadmap section names two unstarted directions and is explicit that neither
has been measured against the other:

* **Share the pile rather than copy it.**  A resident shared-libc segment trades
  RAM for load time across every exec.  apple/fgx#37 option 1 is the cheaper
  variant: revert the tool-side archive conversion and keep the fixture side,
  since apple/fgx#25's actual purpose was the fixture 64 KB ceiling and fixtures
  never co-reside.  Costs the 36.4% disk saving.
* **Reduce demand.**  `perf(elvis)`'s CRUNCH flag reclaimed 21 KB of data bank
  for one `-D` (2026-08-08) using a configuration the port already shipped.
  Other vendored ports are unlikely to be tuned for a 64 KB data space; nobody
  has looked.

**The sharing arithmetic is not all-or-nothing:** 152 tool binaries collapse to
69 distinct piles, 29 of them sharing the commonest one.  So sharing degrades
rather than disappears, and a pipeline spanning pile classes costs a bank per
class.

---

## Category B -- I/O throughput

**Items:** apple/fgx#307, the rate in apple/fgx#362, ROADMAP lines 3116-3138 and
3561.

apple/fgx#307 is the sharpest measurement in this category and its value is that
it EXCLUDES the obvious cause: over the same byte range `_kBlkReadCount` is
**1697 on UFS against 1696 on ProDOS**.  The block layer does the same work, so
the gap sits above it, per `read()`.  The buffer cache is **NBUF 16**
(`src/kernel/vfs/fsparam.h:196`) with no read-ahead.

The boot loads ~310 KB at roughly **25 KB/s** (apple/fgx#362).  Whether that is
the same ceiling apple/fgx#307 measures, or a different one, is unknown and is a
cheap thing to settle.

ROADMAP line 3561 already carries the right instruction and it should survive
into the deep dive verbatim:

> **Before optimizing either of these, MEASURE.**  "Block I/O is slow" could be
> [several different things]

The extended-SmartPort multi-block read (ROADMAP 3116) is filed as an I/O
throughput idea and is explicitly an optimisation hint, not a mechanism.

---

## Category C -- headroom, which on a 65816 is a performance constraint

Space is not a separate concern here: every one of these blocks work that would
otherwise be done, and two of them have already produced outages.

| item | measured |
|---|---|
| apple/fgx#338 | boot stack **52 of 512 spare**, 236 bytes deeper on a UFS root than the last published figure (288 spare, 2026-08-29).  Constant across seven sample frames, so it is the chain's depth and not an unlucky sample |
| apple/fgx#264 | fcc's kernel stack guard **cannot be armed**: margin 128 bytes against 30 spare on the deepest slice (482 of 512, on a plain `ls /`).  A truthful floor would sit ~98 bytes above legitimate use and halt the machine |
| apple/fgx#367 | libc frames are invisible to the stack model.  `DEFAULT_PAD` is 128 against `getwd` 384 and `syslog` 270; **17 tools** change page counts when the model can see libc; `inetd` and `telnetd` are on the loader's one-page default TODAY while calling `syslog` |
| apple/fgx#62 | elvis data bank 103 bytes free |
| (measured 2026-09-08) | `vfs.mod` **44 bytes free**; every fix in that bank must be a MOVE rather than an addition |

apple/fgx#367 is the newest and the one with a live hazard: it is the same shape
apple/fgx#365 sat in for two months before `getwd` grew a 384-byte frame and
started killing the multibank sweep.

---

## Category D -- boot path composition

**Items:** apple/fgx#362, apple/fgx#316, apple/fgx#338.

Phase breakdown at 1-second resolution (apple/fgx#362), on `disk/fgxufs.po`:

```
   0 - 10 s   kernel, block driver, root mount, "spawning init..."
  10 - 15 s   /etc/rc: modload of five modules, then netstart and dhclient
  15 - 21 s   NOTHING ON SCREEN -- inetd spawning, loading, parsing
  21 - 25 s   inetd arms its two listeners
  25 - 27 s   /bin/sh loads and reaches fgx#
```

Controlled removal of `/sbin/inetd &` from `/etc/rc` moves the prompt 27 s ->
25 s, so **all of inetd is 2 seconds** and the config files (1,224 + 662 bytes,
read with buffered `fopen`/`fgets`) are not a factor.  `init` runs `/etc/rc` to
completion before any line starts, so every second added to rc is a second
before the machine is usable.

`dhclient` fast-failed for want of an interface in that run, so 25 s is a FLOOR.
A machine with a card pays a real DHCP exchange in that window.

apple/fgx#316 is adjacent: module loading currently costs a process slot out of
**CFG_KERNEL_NPROC = 12**.

---

## Category E -- the measurement apparatus itself

This category exists because three separate performance facts were invisible for
weeks behind instrumentation that had stopped working.  A deep dive that does not
fix this first will measure the wrong things.

* **apple/fgx#338's own account**: the kernel used to print `bstk $F920 (288
  spare)` and the line was deleted with the development messages.  `bootstk`
  asserted the printed line, so it began failing with "the kernel printed no
  bstk figure" instead of a number, and a 236-byte deepening was invisible
  behind a checker that could not read anything.
* **apple/fgx#342**: the fcc runtime sweep and oracle boot a ProDOS image and
  have been dead since ProDOS left the boot path.
* **apple/fgx#362's own history**: the harness boot estimate was raised 12 -> 25
  -> 45 seconds, each time in reaction to a red gate, and nobody measured where
  the time went until 2026-09-08.
* **apple/fgx#288**: the gate's flake floor, which decides whether any A/B
  result is readable at all.

---

## Where a deep dive should start, in order

1. **Re-take the pile numbers.**  apple/fgx#37's bank arithmetic and the
   roadmap's 630 ms `execve` are the two figures that would justify the largest
   piece of work in this file, and both predate the UFS root swap.
2. **Settle whether the boot's ~25 KB/s and apple/fgx#307's per-`read()` gap are
   the same ceiling.**  Cheap, and it decides whether A and B are one project.
3. **Fix the apparatus in category E** before running any A/B.  Specifically
   apple/fgx#342, since the sweep and oracle are the only things that execute
   fcc's output under the kernel.
4. Only then choose between shared-pile and reduce-demand.

---

## Standing traps for this work

* **MEASURE, DO NOT INFER.**  ROADMAP 3561 says it for block I/O and it
  generalises.  This project has repeatedly produced a confident mechanism from
  a strong correlation; apple/fgx#365 cost most of a session that way, with
  three asserted causes that were all wrong before the fourth was measured.
* **A CHECK WHOSE TOOL DID NOT RUN LOOKS LIKE A PASS.**  Category E is four
  instances of exactly that.  Every probe needs a positive control -- a known-bad
  input it must call bad.
* **A CAP IS NOT AN ALLOCATION.**  apple/fgx#365 was misdiagnosed for hours by
  comparing a frame against `TASK_STACK_MAX_PAGES` (83 pages) when the binary
  had been allocated 1.
* **THE HARNESS TYPES ON A FIXED SCHEDULE**, not when the prompt appears
  (apple/fgx#288).  Any timing A/B has to account for that or it measures the
  harness.

---
---

# PART 2 -- IDEAS FOR THE DEEP DIVE

Everything above is measured.  **Everything below is not.**  This part is
deliberately speculative: it is the option space, written down so the dive
starts from a list rather than from whatever occurs to someone on the day.

Each entry says what is ALREADY TRUE, because several obvious ideas are already
done and re-proposing them wastes the dive.  Ideas are grouped by subsystem and,
within a group, roughly cheapest-experiment-first.

## What is already done, so nobody proposes it again

* **Multi-block SmartPort reads are IN USE.**  `_SP_ReadBlockN` ($48) exists and
  `blkcache.s:415` calls it.  The ROADMAP's "retire BLK_STAGE via extended
  SmartPort" sketch is spent.
* **The name cache is ported and live.**  `vfs_cache.c` + `vfs_cache_lookup.c`;
  `ufs_lookup` opens with `cache_lookup` and closes with `cache_enter`, which is
  Reno's own shape.
* **The libc archive already dead-strips at member granularity** (apple/fgx#25).
  The remaining cost is that each binary links its own copy, not that it links
  too much.
* **The loader already has a content-addressed share key** for segments
  (apple/fgx#37).  Shared text is a MECHANISM THAT EXISTS; what changed is that
  piles stopped being byte-identical, so the key stopped matching.
* **Staggering the getty lines was considered and declined** (the maintainer,
  2026-09-08).  Do not re-raise it.

---

## B1. Binary size and load

**B1.1 -- Make the piles share again.**  The share key works; the piles diverged.
Anything that makes co-resident tools link byte-identical libc segments restores
one-bank sharing without new loader machinery.  152 binaries already collapse to
69 distinct piles.  Cheapest probe: how much does the commonest pile grow if the
29 tools that share it are forced to a common superset?

**B1.2 -- Overlays, which is 2.11BSD's own answer and is vendored.**
`vendor/2.11BSD/usr/sys/h/exec.h:25-44` carries `ov_siz[NOVL]` and magic numbers
`A_MAGIC4`/`A_MAGIC5`/`A_MAGIC6`: the kernel binary itself is overlaid.  A tool
whose rarely-taken paths live in an overlay pays for them only when called.
This is a PORT, not an invention, which matters for a tree with a
read-the-source rule.  Fits elvis (apple/fgx#62) better than anything else here.

**B1.3 -- Compressed executables.**  `compress`/`zcat` are already ported.  On a
machine reading ~25 KB/s with a 7 MHz CPU, trading decompression time against
transfer time is plausibly a win, and it is measurable without touching the
loader: time `zcat big.bin > /dev/null` against reading `big.bin`.  If the CPU
wins, a compressed-text loader arm becomes worth designing.

**B1.4 -- Lazy segment load.**  Load a segment when first touched rather than at
exec.  Expensive to build (needs a fault or a trampoline per segment) and it is
the one idea here that fights the 65816's lack of an MMU.  Listed for
completeness; the overlay route (B1.2) buys most of the same thing with
machinery that already exists upstream.

**B1.5 -- Shared string pools.**  Every pile carries its own copy of the same
literals.  Unmeasured; the win is bounded by how much of a pile is strings, which
`dataseg.lst` can answer in an afternoon (apple/fgx#62 shows the method).

---

## B2. Caching and the storage path

This is the thinnest area in the tree and the one with the most unclaimed
classic technique.

**B2.1 -- Read-ahead.  There is none.**  BSD's `breada`/`rablock` is the obvious
port and apple/fgx#307 is the measurement waiting for it: same block count, gap
above the block layer, per `read()`.  A sequential-access detector plus one
prefetched block is the smallest version.

**B2.2 -- The buffer cache is 16 KB on an 8 MB machine.**  `NBUF` is 16 and
`FS_BLKSIZE` 1024 (`fsparam.h:196`).  Raising NBUF is a one-line experiment and
the arithmetic is worth doing before anything cleverer: 16 buffers is small
enough that a sequential read of a 48 KB file cannot hold its own indirect
blocks.

**B2.3 -- Delayed write is IMPLEMENTED AND NOT IMPORTED, on purpose.**
`ufs_inode.c:718-727` says it plainly: `bdwrite` exists in vfs.mod but ufs.mod
imports only `bread`, `bwrite`, `brelse` and `getblk`, and the note reads
*"import bdwrite when a measurement says the inode write-back is what costs, not
before."*  That measurement is exactly what the dive should take.  This is the
cheapest named lever in the whole file.

**B2.4 -- Track/cylinder buffering.**  Read a whole track on a miss and keep it.
The classic answer to a slow seek, and the SmartPort multi-block path (already
in use) is the mechanism.  Wants a measurement of seek versus transfer cost
first; on a solid-state backing store it may buy nothing.

**B2.5 -- Cylinder-group locality.**  UFS was designed around it.  Whether
`ufs_alloc` currently places blocks with locality in mind, or takes whatever the
free list offers, is a question this file cannot answer and the dive should.

**B2.6 -- The RAM disk as a cache tier.**  A ramdisk module exists (2048 blocks
at bank $02).  Staging hot read-only content -- `/bin`, or just the shell --
into it at boot is crude, cheap, and testable in an afternoon.

**B2.7 -- Boot-time prefetch.**  `init` runs `/etc/rc` to completion before any
line starts, so the kernel knows for ~15 seconds exactly which binaries it is
about to need.  Reading them while rc runs costs nothing but bandwidth that is
otherwise idle.

---

## B3. fcc and codegen

**B3.1 -- The soft-stack size tax is measured and is pure loss.**  +14.4% of
instruction count for `ed`, +10.9% `sed`, +7.6% `grep` against `--hard-stack`
(fcc @ e0411f0).  That tax is paid in bytes on disk, in load time, and in bank
pressure simultaneously.  Anything that narrows it pays three times.

**B3.2 -- The fcc-2.0 optimizing backend phase 2 is unblocked and unstarted.**
The ROADMAP says the multi-pass front-end "NOW ENABLES the deeper optimizing
backend (Track 2, phase 2)" and that it belongs on top of the front-end rather
than before it.  Ledger: `project_fcc2_optimizing_backend`.

**B3.3 -- Direct page as a register file.**  The 65816's DP is a 256-byte window
that addresses in one byte.  Hot locals living there instead of in a soft frame
is the single largest codegen lever this architecture offers, and it interacts
directly with B3.1.

**B3.4 -- Prologue and epilogue cost.**  Every guarded function pays a frame
setup plus a stack-floor compare.  Small leaf functions pay it proportionally
hardest.  Candidates: omit the guard for provably-shallow leaves, and a cheaper
frame form for functions with no locals.

**B3.5 -- Inlining and tail calls.**  Neither exists.  Both trade size against
speed in a direction that has to be chosen deliberately here, since size IS
speed on this machine.

---

## B4. Stack and memory

**B4.1 -- Right-size every binary's stack hint.**  apple/fgx#367 is the
correctness half; the performance half is that stacks are bank-0 pages, the
scarcest resource in the system, and 17 tools currently carry a number derived
from a model that cannot see libc.  Some will be too small (a latent
apple/fgx#365) and some too large (wasted arena).

**B4.2 -- Pool or share stacks.**  A task's stack is allocated for its lifetime.
Whether short-lived tools need their own pages for their whole life is a
question worth asking with `CFG_KERNEL_NPROC = 12` and bank 0 as the ceiling.

---

## B5. Wild cards

Ideas with a worse effort-to-confidence ratio, kept because the point of a
brainstorm is to write them down rather than to filter them early.

* **An exec image cache.**  Unix's original sticky bit existed for exactly this
  problem on exactly this class of machine.  Keeping the last N text images
  resident turns a repeated `ls` from a 41 KB read into a bank reference.  The
  loader's share key is most of the mechanism.
* **A resident shared libc, IIgs-style.**  The machine's own ROM Tool Sets are a
  working example of the pattern: one resident copy, a vector table, callers
  dispatch through it.  That is what a shared-libc bank would be, and the
  hardware's own idiom is an argument that the shape fits.
* **Profile-directed layout.**  Put the functions a boot actually calls next to
  each other so a sequential read gets them together.  Needs a profiler the tree
  does not have.
* **Trade the ninety percent case.**  Several ports carry configuration the FGX
  build does not set; `perf(elvis)`'s CRUNCH flag reclaimed 21 KB for one `-D`.
  A survey of vendored ports' build-time knobs is low-skill, low-risk work with
  a known precedent for paying off.

---

## How to run the dive without repeating this session's mistakes

1. **Take a baseline the harness cannot distort.**  The autoboot types on a
   fixed schedule (apple/fgx#288); a timing A/B that does not account for it
   measures the harness.
2. **One variable per run, with a positive control.**  Three of this session's
   wrong conclusions came from a change whose build never happened or whose
   effect was confounded.
3. **Prefer the levers that are already built and switched off** -- B2.3 first,
   then B2.2 -- before designing anything.  Two of the four cheapest ideas here
   are one-line changes to code that already exists.
4. **Re-measure apple/fgx#37 and the 630 ms `execve` before building on them.**
   Both predate the UFS root swap.

---

## B6. The Toolbox -- the largest body of fast code already on the machine

Raised by the maintainer 2026-09-08.  **The IIgs ROM carries 1,053 documented Toolbox
routines across 31 tool sets** (`gs-mcp` corpus: Toolbox Reference vols 1-3).
They execute out of ROM, cost no bank, and are already paid for.

**FGX already calls into two of those sets**, so the mechanism, the dispatch
convention and the bring-up gotchas are all solved:

| what FGX uses | call | where |
|---|---|---|
| Memory Manager -- whole-map pre-claim | (stage-2 loader) | userland allocations happen inside FGX's own claim |
| Misc Tool Set -- `_GetNewID` | `LDX #$2003` | `toolbox.s` `Toolbox_GetOwnID` |
| Misc Tool Set -- `_SetHeartBeat` | `LDX #$1203` | `toolbox.s` `Toolbox_InstallHB`, the 60 Hz tick |

The dispatch convention is `LDX #$RRTT` (routine, tool set) then `JSL $E10000`;
Misc is tool set `$03`, Memory Manager `$02`, Tool Locator `$01`.  FGX's two
numbers agree with Table D-1 (`toolbox_ref_vol2` p672), which is the master index
and the right place to take any number from.

### The find: FGX is already inside the tool set that holds a compressor

`toolbox_ref_vol1` p615, Table 14-1, lists the Miscellaneous Tool Set.  Three
routines sit directly beside the two FGX already calls, unused:

> **PackBytes** -- Packs bytes into a special format that uses less storage space
> **UnPackBytes** -- Unpacks data from the packed format used by PackBytes
> **Munger** -- Manipulates bytes in a string of bytes

**This is B1.3's missing half.**  Compressed executables were listed above as
"trade CPU against a 25 KB/s disk", with the unstated cost that a decompressor
is code the loader has to carry in a bank that has none to spare.  `UnPackBytes`
is in ROM.  The codec is free, in the tool set FGX has already brought up.

`Munger` is a ROM byte-string engine, which is the shape of several libc string
routines that currently cost pile bytes in every binary.

### Other sets worth a look, roughly by expected value

* **Integer Math (`$0B`, 3 routines indexed).**  fcc has no divide instruction,
  and `fsparam.h:209` records the consequence: `off / FS_BLKSIZE` is a 32-bit
  divide, and `vfs_syscalls.c` measured fcc's 32-bit unsigned divide runtime at
  **1,655 bytes of far bank against 737 free** -- it was avoided with a shift.
  If the ROM does long division, that is size AND speed on a path the kernel
  takes per `read()`.  **Check the routine list first: only 3 calls are indexed
  for this set, so it may be far smaller than the name suggests.**
* **Scheduler (`$07`, 12 routines).**  The IIgs's own deferred-task queue.  FGX
  built its own; whether the ROM's is cheaper or interacts better with the
  heartbeat is worth knowing before more scheduling work.
* **Memory Manager (`$02`, 34 routines).**  FGX pre-claims the whole map, so
  most of this set is bypassed by design.  But `HLock`/`HUnlock`/`CompactMem`
  are the machinery a resident shared-libc bank (B5) would otherwise have to
  invent.
* **SetVector / GetVector** (Misc).  FGX manages its own vectors; the ROM's
  interrupt-manager view may be a cheaper way to coexist with firmware, which is
  the problem `toolbox.s` already solved once by hand for the heartbeat.
* **ACE Tool Set (`9` routines)** -- Audio Compression and Expansion, hardware
  assisted.  Almost certainly audio-shaped, but a hardware compressor is worth
  ten minutes of reading given B1.3.

### Three constraints that decide whether any of this is usable

These are the questions to settle FIRST, because a "no" on the second one closes
most of the section.

1. **DISPATCH OVERHEAD.**  Every call is `JSL $E10000` plus the Tool Locator's
   dispatch.  For a routine as small as a divide, the dispatch may cost more
   than the work.  Measure the empty-call cost once and it prices every idea
   here.
2. **REENTRANCY.  This is the one that matters.**  FGX preempts.  ROM Toolbox
   routines are generally NOT reentrant, and most tool sets keep state in a
   direct page they were started up with.  Calling one from two tasks without a
   lock is a corruption, and a lock around a ROM call is a scheduling hazard on
   a machine with `CFG_KERNEL_NPROC = 12`.  Settle this before designing
   anything: it may confine Toolbox use to the kernel, or to a single serialised
   path.
3. **RAW-BOOT CONTEXT.**  `toolbox.s` already carries the scar: `_MMStartUp`
   returns `idErr=$0207` from raw boot because there is no app-launch context,
   which is why FGX uses `_GetNewID` instead.  Any set FGX wants must be brought
   up from the same cold state, and its StartUp may want a direct page FGX would
   have to find.

### How to read the reference without being misled

`gs-mcp` holds all 1,053 entries at **status `proposed`** -- OCR'd or
auto-extracted, never human-checked.  **Do not bake a tool number from the
database.**  Take it from the cited page (`get_iigs_page`), and Table D-1
(`toolbox_ref_vol2` p672) is the master routine-number index.  The two numbers
FGX already uses were cross-checked against it while writing this section and
agree, which is the pattern to repeat.

There is also 2.9 M lines of real IIgs source in the `gs-mcp` examples corpus --
including **GNO/ME**, a UNIX-like kernel for this exact machine, and Apple's own
**IIgs System Software 6.0.1** source.  For any question of the form "is it
sane to call this from a kernel", those two are the places somebody has already
answered it.

---

## B7. GNO/ME -- the same hardware, the opposite architecture

Raised by the maintainer 2026-09-08: GNO has much smaller binaries and does not pay the
load times FGX does, but it is architecturally very different.  Both halves of
that are true and the second one decides how to read the first.

The tree is at `examples/gno/` (also in the `gs-mcp` examples corpus, 308,861
lines).  It is a UNIX-like multitasking kernel for this exact machine, so it is
the only apples-to-apples comparison that exists.

### The difference, in one line from GNO's own manual

`usr.man/man2/execve.2`:

> A new userID is allocated for the process, and **the GS/OS System Loader** is
> used to bring the executable file specified by pathname into memory.

**GNO is a UNIX layer ON TOP OF GS/OS and the Toolbox.  FGX REPLACES them.**

That is the whole explanation for the binary-size gap, and it is not a defect in
either design:

| | GNO/ME | FGX |
|---|---|---|
| loader | GS/OS System Loader | its own |
| file I/O | GS/OS (`kern/gno/gsos.asm`, 38 KB of glue) | its own VFS + UFS |
| libc | ORCA libraries, resident under the process | a private pile per binary |
| binary format | OMF, segmented | FGX2/FGX3 segments |
| processes | ~32 | `CFG_KERNEL_NPROC` 12 |

A GNO tool is small because **the platform is underneath it**.  GS/OS, the
Toolbox and the ORCA runtime are already resident and shared, so the binary
carries only its own code.  An FGX tool carries what GNO gets from the system.
FGX pays that deliberately -- a standalone BSD is the point of the project, and
`gsos.asm` is the tax GNO pays in the other direction.

**So the value here is LESSONS, not convergence.**  Anything phrased as "be more
like GNO" is a category error; anything phrased as "GNO proves this works on
this silicon" is evidence.

### What transfers, strongest first

**B7.1 -- The stack default, and this one is immediately actionable.**  Same
manual page:

> If the executable file does not contain an OMF Stack Segment (SEGKIND = $12),
> **a default stack of 4096 bytes** is allocated to the process.

That is FGX's design exactly -- a per-binary stack size declared in the
executable, with a loader default when it is absent -- and apple/fgx#365 was
precisely the absent case.  **GNO's default is 4096 bytes.  FGX's is one page,
256 bytes.**  Sixteen times smaller, on the same hardware, for the same purpose.

Worth deciding on its own merits and cheap either way: raising the default costs
bank-0 arena on every unmeasured binary, which is exactly the resource
apple/fgx#367 says 17 tools are already mis-declaring.  But "one page" is not a
number anybody derived, and GNO's is.

**B7.2 -- Existence proof for a resident shared libc.**  B1.1 and B5 argue for
shared platform code from first principles.  GNO is that arrangement, working,
on this machine, with the binary sizes to show for it.  The argument stops being
speculative; what remains is whether FGX can host the mechanism GS/OS supplies.

**B7.3 -- DP and stack as ONE allocation.**  Same page: *"The direct-page
pointer is set to the bottom of the stack memory."*  GNO puts the direct page at
the base of each process's stack, so DP-relative locals are the natural frame
access.  That is the arrangement B3.3 wants for using DP as a register file, and
it is corroborated by the note already in this project's memory: GNO ran ~32
processes with C locals on bank-0 hardware stacks, D = frame.  FGX instead pays
a soft-stack tax measured at +14.4% (`ed`), +10.9% (`sed`), +7.6% (`grep`).

**Read this one carefully before acting on it.**  FGX's soft stack exists for
reasons the bank-0 campaign documented at length, and GNO's 32 processes at 4 KB
of stack each is 128 KB of bank-0-class memory, which is a budget FGX may not
have in the same place.  The question to ask is not "why did we not do it GNO's
way" but "what does GNO's arrangement cost in the resource FGX is short of".

**B7.4 -- Dynamic segment loading is proven here.**  B1.4 was listed as
expensive and fighting the lack of an MMU.  The GS/OS System Loader does it on
this hardware, so the cost is known rather than hypothetical, and its source is
readable: Apple's own System Software 6.0.1 tree is in the examples corpus
(1.3 M lines, loader included).

### What does not transfer, so nobody spends a week on it

* **Using GS/OS.**  Not being GS/OS is the project.
* **ORCA libraries.**  FGX's libc is BSD and vendored from 2.11BSD; that choice
  carries the conformance rule this whole tree is built on.
* **OMF.**  FGX's segment format is its own and the loader is built around it.

### How to use the corpus

`examples/gno/kern/gno/` is the kernel: `kern.asm` (45 KB) is the core,
`sys.c` (33 KB) the syscall layer, `proc.h` the process structure, `gsos.asm`
the GS/OS glue.  For "is it sane to do X from a kernel on this machine", GNO and
the 6.0.1 source are where somebody has already answered it -- which is the same
role `vendor/2.11BSD/` plays for behaviour, and it should be read the same way:
**from the source, with the file and routine named**, never from memory.

---

## B8. Three bodies of knowledge nobody has mined for this

Raised by the maintainer 2026-09-08.

### B8.1 -- llvm816, and the rule that governs reading it

`examples/65816-llvm-mos` is a real, buildable, measured LLVM/Clang backend for
this CPU, and it is the only other modern optimising compiler that targets it.

**IT IS FGX'S CLEAN-ROOM KNOWLEDGE ORACLE: ALGORITHMS ONLY, NO C++ COPYING.**
That is a standing rule from the project ledger and it governs any use of this
tree.  Read it for what it DECIDED and why; do not lift its code.

*Note for whoever picks this up: the rule is recorded in the memory ledger but is
NOT written in `docs/`, and `docs/history/plans/architecture-redesign.md` cites llvm816 freely
without restating it.  Writing it into the coding standards is a small, separate
job worth doing before a dive starts reading that tree in earnest.*

**FGX has already mined it once, structurally.**  `docs/history/plans/architecture-redesign.md`
records the convergence: bank in the pointer VALUE end to end, exactly one
lowering funnel per pointer-kind x operation, linker-patched banks, one libc.
It also names three specific folds and the Layer2Gate pattern.  That work is
done and should not be redone.

**What has NOT been mined is the part relevant here.**  Two concrete finds:

* **`examples/65816-llvm-mos/benchmarks/` is a ready-made 65816 C benchmark
  suite** -- `bsearch`, `bubbleSort`, `crc32`, `djb2Hash`, `dotProduct`, `fib`,
  `dmul`/`ddiv`/`dadd`, several `globalArr*` shapes, and more -- with a
  `compare/` harness and a `regen.sh`.  **FGX has no benchmark corpus of its
  own.**  Every idea in this file needs one, and this is twenty-odd programs
  chosen by somebody solving the same codegen problem on the same CPU.  Adopting
  the PROGRAMS is not copying the compiler.
* **A published geomean to sit beside.**  llvm816 measures at about **0.62x
  Calypsi 5.16** on its own suite (project ledger).  A number for fcc on the
  same programs would say, for the first time, where fcc actually stands rather
  than whether it got better this week.

### B8.2 -- gs-mcp: the optimisation data is there but nothing is TAGGED that way

The maintainer's point exactly, and it is confirmed rather than assumed: searching the
corpus for optimisation language returns nothing useful.  Queries for direct-page
alignment penalties, speed registers and fast/slow memory all came back empty
during this survey, and one errored on the OCR index.  **There is no
"optimisation" chapter, because 1980s hardware manuals do not have one.**

What the corpus HAS is the raw material, spread across documents by other names:

* **`hardware_ref` (164 pp)** -- memory speed behaviour.  The IIgs does not run
  at one speed: I/O space and certain banks force the slow clock, and shadowing
  adds cost to writes.  **Where FGX puts hot code and data is therefore a
  performance decision it has never made deliberately.**
* **`iigs_asm_programming` (176 pp), `ml_beginners` (633 pp),
  `programming_iigs_part1`/`part2`** -- addressing-mode and instruction timing.
  The cycle costs that decide whether DP-relative locals (B3.3) actually beat a
  soft frame, and whether a Toolbox dispatch (B6) beats inline code.
* **`toolbox_ref_vol1-3` Table D-1 (`vol2` p672)** -- the routine index B6 needs.
* **`tn_iigs` (108 pp)** -- technical notes, which is where hardware surprises
  get documented after the manuals ship.

**Three 65816 facts worth confirming from those pages before any codegen work**,
listed as questions because this survey could NOT confirm them through search
and will not assert them from memory:

1. Does a direct page whose low byte is non-zero cost an extra cycle on every DP
   access?  If so, every per-task DP in FGX must be page-aligned -- the build
   currently places them at `$B300` upward, which is aligned, but by choice or
   by luck is unrecorded.
2. What exactly runs at the slow clock, and does any hot FGX structure live
   there?
3. What do `REP`/`SEP` mode switches cost, given fcc emits them constantly?

Each is a page-read, not a project.

### B8.3 -- The outside literature

Compiler and 6502-family optimisation writing is extensive and none of it is in
this tree.  The specific bodies worth a pass, named so the search is not
open-ended:

* **6502/65816 community optimisation lore** -- cycle-counting idioms, table
  dispatch, self-modifying code, loop unrolling against a slow clock.  Much of
  it predates and outlives any compiler.
* **Compiler-textbook passes not yet in fcc** -- the fcc-2.0 ledger already
  scopes the backend; the front-end questions (inlining heuristics, tail calls,
  strength reduction, common subexpression elimination) have standard answers
  worth reading before inventing.
* **Other retro C compilers' write-ups** -- cc65, Calypsi, ORCA/C and SmallC all
  solved register-poor accumulator-machine codegen and several documented why.
  ORCA/C's source and ORCALib are already in the `gs-mcp` examples corpus.

**A caution consistent with the rest of this project:** an idea from the internet
arrives without the measurement that would justify it here.  Anything taken this
way is a HYPOTHESIS until it has a number from FGX's own benchmark corpus --
which B8.1 says does not exist yet, and which is therefore the first thing the
dive should build.

---

## B9. Far outside the box

Requested by the maintainer 2026-09-08.  These are deliberately less conservative than
B1-B8.  Each is grounded in a number or an in-tree fact, and ordered by HOW
CHEAPLY IT CAN BE DISPROVED rather than by expected value -- an idea that dies
in an afternoon is worth more than one that needs a month to evaluate.

### The measurement that reframes several of these

    /bin + /sbin       5,992 KB across 89 binaries      (avg 67 KB per tool)
    machine RAM        8,320 KB
    shared libc pile   62,753 B, when it was still shared   (apple/fgx#37)

**Userland is almost entirely duplicated libc, and it nearly fills the
machine.**  89 tools at a full pile each is ~5.6 MB of the 5.99 MB.  Every idea
below that sounds extravagant -- hold `/bin` in RAM, snapshot the booted system,
one binary for everything -- becomes ordinary arithmetic the moment the pile is
shared once.  Conversely, none of them is affordable while it is not.  **B1.1 is
the gate on half of this section.**

### B9.1 -- Snapshot boot (cheapest to disprove, largest single win)

Boot is 25-30 s and does the SAME WORK EVERY TIME: same modules, same rc, same
four binaries.  Boot once, dump the settled memory image to disk, and on later
boots restore the image instead of executing the path that produces it.

The restore is a bulk sequential read of a few hundred KB against a boot that
currently spends most of its time doing many small ones.  Hibernation is old,
well understood, and does not need an MMU -- it needs a stable memory map, which
FGX has because the loader pre-claims the whole thing.

**Disprove it in an afternoon:** time a bulk read of a ~600 KB file against the
25 s boot.  If bulk I/O is not dramatically faster per byte than the boot's
current mix, the idea is dead and costs nothing more.

*Known hard parts, so nobody is surprised: device state must be re-initialised
rather than restored, the clock must be re-read, and the Toolbox/heartbeat
bring-up in `toolbox.s` probably cannot be snapshotted at all.  A snapshot taken
AFTER those and BEFORE `/etc/rc` may be the tractable version.*

### B9.2 -- One binary for all of userland (busybox)

89 binaries, 89 piles.  One multi-call binary with one pile, dispatching on
`argv[0]`, collapses that to a single image -- and the shell could keep it
resident, so `ls` after `cat` costs no load at all.

This is the crudest possible answer to the pile problem and it needs no loader
work, no shared-library mechanism and no new format.  It is unattractive for
other reasons (every tool rebuilt on any change, a 64 KB bank ceiling per code
segment, and the vendored-port purity this tree values), which is exactly why it
belongs in this section rather than B1.

**Its real value may be as a MEASUREMENT even if never shipped:** build it once
for the ten most-used tools and the resulting size is the empirical floor for
what sharing can buy.

### B9.3 -- Bytecode for the cold tools

`PLASMA` -- a bytecode VM for this CPU family -- is in the `gs-mcp` examples
corpus (177 files, 80,353 lines).  Bytecode is several times denser than 65816
native code.

For tools that are I/O bound anyway -- `echo`, `mkdir`, `true`, `basename` -- a
5 KB bytecode program that runs three times slower still beats a 40 KB native one
that has to be read off a 25 KB/s disk first.  **The crossover is computable
without building anything**: interpreter overhead against bytes saved at the
measured load rate.

Deeply against this project's grain (a BSD in C, compiled), which is the point of
listing it here.  Most likely outcome is a number that says "no", and that number
is worth having.

### B9.4 -- Never read the same binary twice in a session

8 MB of RAM, and `ls` is re-read from disk every time it runs.  Keep exec'd text
images resident in spare banks and reuse them.  This is B5's exec-image cache
stated at its logical limit: with this much RAM and this slow a disk, **the
steady-state number of disk reads for a repeated command should be zero.**

The loader's content-addressed share key is most of the mechanism (apple/fgx#37).
What is missing is a policy: what to keep, what to evict, and how a bank that
holds a cached image is distinguished from one that is free.

### B9.5 -- Hold /bin in RAM, and keep it across a warm boot

Once the pile is shared, `/bin`'s unique content is small enough to stage into
the ramdisk at boot, after which exec costs no device I/O at all.  The IIgs
retains RAM across a warm reset -- GS/OS's `/RAM5` depended on it -- so a warm
boot could find the staging already done and skip it.

Gated entirely on B1.1: at 67 KB average it does not fit, and at a shared pile it
comfortably does.

### B9.6 -- Transparent compression at the block layer

Trade a 7 MHz CPU against a 25 KB/s disk, system-wide rather than per-binary.
B6 found the codec already in ROM (`PackBytes`/`UnPackBytes`, Miscellaneous Tool
Set), so the decompressor costs no bank.

**Measure the ROM codec's throughput FIRST.**  If `UnPackBytes` does not clear
~25 KB/s comfortably it is a pessimisation, and that is a ten-line test program.

### B9.7 -- Profile-directed bank layout

Every cross-bank call on this machine is a `JSL`/`RTL` plus the patch-table
machinery, and FGX crosses constantly: the far-bank seam costs about 180 bytes
of entry per path syscall, and every one of them crosses.  Functions that call
each other should share a bank.

FGX already has the infrastructure to act on such a decision -- `bankmap.json`,
the module placer, and the patch tables -- so this is a POLICY question on top of
existing mechanism.  And the profiler it needs EXISTS: see B11.0.

### B9.8 -- Make the common case not enter the kernel

apple/fgx#307's gap is per-`read()`, not per block.  A userland stdio buffer
large enough that reading a 48 KB file of 64-byte lines costs 48 syscalls rather
than 768 attacks the measured cost directly, in userland, with no kernel change.

Least exotic idea in this section and possibly the highest ratio of win to risk.
It is here because it was invisible until the gap was correctly attributed --
which is what apple/fgx#307's `_kBlkReadCount` measurement did.

### B9.9 -- Specialise code at load time

The tree already rewrites code at load: `w5100_patchsites`, `far_patchsites`,
the module bank patches.  That machinery is general enough to do more than fix
bank bytes -- a hot loop could be specialised to its actual parameters when the
binary is placed.

Speculative and easy to get wrong (it interacts with the share key: specialised
text is no longer identical, so it stops being shareable).  Listed because the
mechanism is unusually mature here and nobody has asked what else it could do.

### What NOT to do with this list

**Do not start at the top.**  Start with whichever is cheapest to KILL.  B9.1,
B9.3 and B9.6 all reduce to a single timing measurement, and three ideas
eliminated in an afternoon is a better day than one idea half-built.

**And note how much of it waits on one thing.**  B9.2, B9.4 and B9.5 are all
different phrasings of "stop carrying 89 copies of libc".  If the dive does only
one piece of work, that is the piece.

---

## B10. Hand assembly on measured hot paths

Raised by the maintainer 2026-09-08 from early-Unix practice: rewrite the hot loops and a
few functions in assembly, leave the rest in C.  It is the oldest performance
technique on this list and the one this machine is most suited to.

### The standing rule is about PROVENANCE, not about assembly

Clarified by the maintainer 2026-09-08, and worth stating carefully because the shorter
version of this rule that has been circulating is wrong in a way that would
misdirect the whole section.

**The rule was never anti-assembly.**  It was against hand-assembly
REIMPLEMENTATIONS of BSD tools when the C source was sitting in `vendor/`.
Rewriting `cat` in 65816 assembly throws away the thing this project is built
on: the lineage back to a specific upstream file, the ability to diff against it,
the conformance rule that says read the source rather than remember it, and the
`docs/PROVENANCE.md` row that `tools/check_provenance.py` requires.  A hand-asm
reimplementation has no upstream row to name.

**Inline assembly on a hot path is expected, and on this architecture it is a
matter of course.**  It keeps the lineage: the function is still the vendored C
function, still traceable to its upstream file, with a localised substitution
inside it.  The upstream definition remains beside the asm as the statement of
what the code is supposed to do.

**So the governing order is: ALWAYS START WITH THE VENDOR C.**  Port it, get it
correct, keep the provenance row -- and only then, on a measured path, replace
what the measurement says to replace.  Optimisation is always in scope; starting
from something other than the vendored source is not.

**What the rule's rationale still costs, and it costs a lot:** its rationale is that hand asm
"sidesteps the whole 65816/Merlin hand-asm bug class (MX-width slips, DBR
discipline, stale flags)".  That class is not theoretical.  **The most expensive
defect of this session was exactly one of them** -- apple/fgx#360, `LDA
|_kBlkTabBase` reading through the wrong data bank, which corrupted the block
table on 9 of 23 RAM patterns and took a bank-bisect, a page-bisect and a read
watchpoint to find.  Every verbatim block re-opens that door on purpose.

### The mechanism already exists

fcc supports verbatim assembly and the peephole optimiser knows to leave it
alone.  `toolchain/src/cc/peephole.c:777-788` marks every line between `;__ASM`
and `;__ASM_END` with a sentinel label, because "every pattern already treats a
labeled line as a branch-target barrier and never a candidate, which is exactly
the conservative contract a verbatim block needs."

So the question is not "can we" but "where, and how do we know it paid".

### There is already a worked precedent, with a number

Two console commits did exactly this and measured the result:

    687f27985  perf(console): fast-fill space cells (1 load + replicate vs 8 loads)
    a5359175a  perf(console): cache the per-cell attribute decode across same-attr runs

Combined effect recorded as **26.1% faster console flush**, and the same arc
first built `d4b2ea5b6`, a live flush profiler, to find the path.  **That order
is the template: profile, then specialise, then keep the profiler.**

### Candidates, all unprofiled

Listed as guesses to be confirmed or killed by measurement, not as a work queue:

* **`uiomove`** -- the byte copy under every `read()`/`write()`.  The 65816 has
  `MVN`/`MVP` block move, which is the fastest copy the machine has, and a
  byte-at-a-time C loop is the shape that benefits most.
* **libc `memcpy`/`strcpy`/`strlen`** -- same argument, paid by every tool.
* **The tty line discipline** -- per character, on every console and pty write.
* **`ufs_bmap`'s indirect descent** -- on the path apple/fgx#307 measured.
* **The fcc runtime helpers themselves** -- the 32-bit divide is 1,655 bytes
  (`vfs_syscalls.c`); whether it is also slow is unmeasured, and B6 asks whether
  the ROM should do it instead.

### The method, and it is not optional here

1. **Profile first.**  Every candidate above is a guess.  This project has paid
   repeatedly for confident mechanisms that measurement contradicted -- three
   times on apple/fgx#365 alone.
2. **Keep the C.**  Leave the original as a comment or an `#ifdef` so the asm can
   be diffed against a definition that is known correct.
3. **Prove the win, then prove the correctness separately.**  A hand-asm block
   needs a regression fixture that would go red on an MX slip or a DBR error --
   the two failure modes that do not announce themselves.
4. **Re-measure after.**  `26.1%` above is what makes those two commits
   defensible; without the number they would be unreviewable.

### The honest counter-argument

Every block written here is a block that fcc's optimiser can never improve.
B3.2's optimising backend, if it lands, raises all C uniformly and forever; hand
asm raises one path once and then freezes it.  On a codebase this size, ten
hand-optimised loops may be worth less than one backend pass -- and they compete
for the same attention.

**That is an argument about ORDER, not about permission.**  Inline assembly is
expected on this architecture and will be necessary regardless of how good fcc
gets; the machine is register-poor and bank-addressed and some things simply
cannot be said well in C.  What the counter-argument buys is discipline about
WHICH paths: a block is justified by a profile, not by a hunch, and a path that
the backend would have fixed anyway is a block written for nothing.

The order that follows from this and from the provenance rule above:

    1. port from the vendor C, with its PROVENANCE row
    2. make it correct, with a fixture
    3. measure, and find the paths that actually dominate
    4. replace THOSE, keeping the C beside them
    5. re-measure, and keep the profiler

---

## B11. Further unusual options

### B11.0 -- CORRECTION: the profiler already exists

**Two earlier sections of this file say the tree has no profiler.  That is
wrong**, and it is worth fixing loudly because it was the single largest stated
blocker on the whole dive.

`tools/mame_test/plugins/fgxdebug/init.lua:58-67` carries a **whole-system
PC sampler**, opt-in through a manifest key:

    "pc_sample": {"out": "<path>"}

It samples the full 24-bit program address and writes
`{"samples": {"BB:OOOO": count, ...}, "total": N, "wall_s": <emu.time delta>}` --
a bank:offset histogram with a wall-clock denominator.  Its own comment calls it
the "Phase-0 real-tool profiler".

So the dive's prerequisites are **half met already**: the profiler exists and
only the benchmark corpus (B8.1) is missing.  Every "needs a profiler" caveat
elsewhere in this file should be read against this.

*The lesson is the one this file keeps repeating: I asserted an absence twice
without checking for it.  Search the tree before declaring a capability
missing.*

### B11.1 -- Spend the idle time

The machine is idle almost all the time -- waiting on a keystroke, waiting on a
disk.  There is already a 60 Hz heartbeat task (`toolbox.s`) with somewhere to
hang work.

Candidates: prefetch the blocks a sequential reader is about to want; pre-load
the binary the shell is most likely to run next; pre-relocate or pre-decompress a
cached image; flush delayed writes.  **Idle-time work is free in a way nothing
else here is** -- it costs latency only when the guess is wrong.

### B11.2 -- Move work from run time to BUILD time

Everything computed at boot or exec that could have been computed once on the
host is pure loss on a 7 MHz machine.

* **Pre-relocation.**  If a binary is nearly always placed at the same bank, ship
  it pre-relocated and skip the patch pass at load.
* **Precomputed tables over computation.**  Classic, and the trade is unusually
  favourable here: 8 MB of RAM against a CPU with no multiply or divide.  A
  reciprocal table beats a 1,655-byte divide runtime if the divisors are few.
* **Build-time layout by profile** -- B9.7, now unblocked by B11.0.

### B11.3 -- Bigger filesystem blocks

`FS_BLKSIZE` is 1024 (`fsparam.h:197`).  Doubling or quadrupling it divides the
number of block operations for sequential reads by the same factor, and
apple/fgx#307 measured the cost as sitting per-operation above the block layer.

An on-disk format change with real consequences -- 2.11BSD compatibility, the
`fgxfs.py` host tool, fragmentation on small files -- which is why it is here and
not in B2.  But the arithmetic is one line and the measurement already exists.

### B11.4 -- Place data by memory SPEED, not just by bank

The IIgs does not run at one speed: parts of the address space force the slow
clock, and shadowing adds cost to writes.  FGX places code and data by bank
PRESSURE -- what fits -- and has never placed anything by speed.

If the hot structures (the buffer cache, the tty queues, the DP arena) are in
slow space while something cold sits in fast space, that is free performance
sitting in the layout.  **B8.2's open questions must be answered first**; this is
the reason to answer them.

### B11.5 -- exec by forking a pre-warmed template

If libc is nearly the whole binary (B9's arithmetic: 67 KB average, 62,753 B
pile), then a process that already has libc resident is most of any tool.

Keep a warm template process with the pile mapped; `exec` becomes loading only
the tool-specific part into it. This is the pre-forked worker pool, aimed at the
measured composition of an FGX binary rather than at concurrency.

Note the prior art already in the project ledger: a Train 1 P2 candidate design
proposed **GOT/PLT-style indirection, shared code calling out through per-process
DATA-segment cells to keep the shared code bytes pristine.**  That is the
mechanism this idea needs, already thought about once.

### B11.6 -- Same-bank calls should not pay for a bank crossing

Every `JSL`/`RTL` pair plus patch-table entry exists because the callee might be
in another bank.  When the linker can prove caller and callee share one, a `JSR`
is smaller and faster.

Whether fcc and the module placer already exploit this is unrecorded here and is
a five-minute question of somebody who knows the emitter.  If they do not, it is
a pure win with no behavioural change -- the kind of thing that is invisible
precisely because it never fails.

### B11.7 -- Reduce the number of syscall crossings, not their cost

The far-bank seam costs about 180 bytes of entry per path syscall and every one
crosses banks.  Two directions, both unexplored:

* **Batch.** A single call that opens, reads and closes costs one crossing where
  three do today -- worth it only for a measured pattern, and `Load_Binary` is
  the obvious candidate since it does exactly that sequence on every exec.
* **Answer in userland.**  B9.8's fatter stdio buffers are the same idea from the
  other end: the cheapest crossing is the one that does not happen.

### B11.8 -- Let the shell keep more of the system in its own process

Every shell builtin is a tool that never loads.  `bsh` has the BSD set; the
question is which of the 89 binaries are (a) run constantly and (b) small enough
to be builtins without distorting the port.

**This one cuts against the provenance rule and must be handled carefully:**
turning `/bin/echo` into a builtin is fine because bsh's own upstream has it, but
absorbing a vendored tool that upstream keeps separate is a divergence to declare
rather than to sneak in.

---

## B12. Console rendering, and an 80-column text mode

Raised by the maintainer 2026-09-08.  **This may be the single largest cost in the system
that nobody has costed**, because the console is on every path -- every boot
message, every shell prompt, every line of every tool's output.

### The numbers already recorded

* **SHR has no hardware scroll register**, so a full repaint costs roughly
  **100-150 ms** inherently.  Smooth 60 fps text scroll is *physically
  impossible*; **7-10 fps is the ceiling** (recorded 2026-06-30).
* Phase-0 scroll coalescing was needed just to stop large writes hanging the
  console, bounding any single write to ~150 ms and making `cat`/editor repaints
  about **17x faster**.
* Two later commits (`687f27985`, `a5359175a`) took the flush a further **26.1%**.

**Every one of those is work spent fighting a cost that a text mode does not
have.**  In hardware text mode the character generator is in silicon: writing a
character is one byte to memory, and there is no glyph blit, no font, and no
pixel work at all.

### FGX already does this -- at boot

`src/boot/loader.s:141` clears the text screen in both banks and knows the
constraint first-hand:

> 80-col mode interleaves the two banks; if we only clear main the aux half
> still shows the ROM's copyright splash.  With 80STORE on (ROM default), PAGE2
> ($C055) -- not RAMWRT -- redirects text-page writes to the aux bank.

And the loader **deliberately keeps a `CoutTramp` alive for the kernel**
(`loader.s:42,311,390`), with `src/kernel/boot_console.s` wrapping it because a
plain `JSR $FDED` from another bank would read RAM instead of ROM.

So the firmware path, the bank interleave, the 80STORE/PAGE2 discipline and a
working cross-bank COUT trampoline **all exist in this tree already**.  What does
not exist is a console DRIVER built on them.

### The caveats, and the maintainer named the shape of them

Managing an 80-column screen is genuinely awkward, and the specific costs are:

* **The interleave.**  Even and odd columns live in different banks, so a
  character write is a bank decision and a horizontal run is not contiguous.
* **The non-linear line map.**  Apple II text rows are not sequential in memory;
  the base addresses follow the classic three-group $28 stride.  A row table
  fixes this at a cost of 24 entries.
* **It lives in the shadowed/slow region**, which B11.4 says nobody has costed.
* **COUT itself may be the slow way to use it.**  The firmware routine does
  interpretation and cursor management per character; direct writes through a row
  table are likely much faster.  **Use COUT to bring it up, then measure whether
  to keep it.**

### The real conflict, which is architectural rather than technical

FGX **deliberately re-architected the SHR console** from a character grid into a
*scanline-native framebuffer with mixed graphics/text and Tektronix-style
behaviour* (decision, 2026-06-30).  A hardware text mode cannot do mixed
graphics and text, cannot do the fractal explorer, and cannot do arbitrary
scanline work.  **Proposing text mode as a REPLACEMENT would discard that
decision**, and this file is not the place to overturn it.

### Which is why the interesting version is BOTH

FGX already has virtual consoles.  `/etc/ttys` runs `console`, `ttyv1` and
`ttyv2`, and `_kVcBank[]` is a per-VC registry the harness already reads.

**A text-mode VC beside the SHR VCs costs nothing architecturally.**  The shell
and every ordinary tool -- the 95% case, and the one on the boot critical path --
would run at hardware text speed; anything wanting pixels switches to an SHR
console and pays for what it uses.  Mixed graphics/text survives intact on the
consoles that want it.

### What to measure, cheapest first

1. **What does the console actually cost as a fraction of a boot?**  B11.0's PC
   sampler answers this directly and it has never been asked.  If console
   rendering is 20% of the 25-30 s boot, this section is the top of the file; if
   it is 2%, it is a curiosity.
2. **Time a text-mode write against an SHR write.**  Both paths exist -- the
   boot console uses one, the running system the other -- so this is a
   measurement, not a project.
3. Only then decide whether the driver is worth building.

**Note the shape of this section against the rest of the file:** unlike most
ideas here, the mechanism is already in the tree and proven at boot.  The open
question is not feasibility but whether the win justifies a second console
driver -- and question 1 answers that for the price of one instrumented boot.

### B12.1 -- Why COUT specifically: VidHD's extended text modes

Clarified by the maintainer 2026-09-08.  The reason to reach for COUT rather than to bang
the text page directly is not only that the firmware path exists -- it is that
**the VidHD card extends that path with text geometries the stock machine cannot
produce**, and software driving the firmware vectors gets them.

`examples/hdtelnet/` is a complete working reference, local to this tree
(`the maintainer/hdtelnet`, a "VidHD wide-carriage vt100 telnet client").  From
`adb.s:8-14`:

```
; set vidhd text mode
; 2 - 80x45  (esc-1) (vhd only)
; 3 - 120x67 (esc-2) (vhd only)
```

**80x45 and 120x67.**  On a machine whose stock text console is 80x24, that is a
modern terminal geometry on real hardware.  `vidhd.s` shows the bring-up --
"Detect VidHD card slot and set up **Pascal vectors**", with
`stz $C00B` (SETSLOTC3ROM) so a card in slot 3 can be found -- and `vt100.s`
sits on top of it.

**FGX already detects the card.**  `src/userland/slotscan/slotscan.c:41` returns
`"VidHD"` for it, so the identification half is done and nothing consumes it.

### What this changes about B12

The text-mode console stops being purely a performance idea and becomes a
CAPABILITY one as well.  Two payoffs from one driver:

* **On stock hardware** -- hardware character generation instead of a 100-150 ms
  SHR repaint, on the 95% path.
* **On a VidHD** -- 80x45 or 120x67, through the same Pascal vectors, for the
  price of the mode set.

And it reinforces the shape B12 already argued for.  This is **in addition to the
SHR framebuffer console, not instead of it** (the maintainer, explicitly).  The
scanline-native SHR console keeps mixed graphics/text and everything the 2026-06-30
decision bought; a firmware-vector text console becomes a second kind of VC
beside it, and `_kVcBank[]` already makes per-VC differences a normal thing for
this system to express.

**Marked as future exploration, not current work** (the maintainer).  Recorded here so
that when a text console is built, it is built on the vectors that lead
somewhere rather than on direct page-poking that would have to be redone --
which is the one decision in this section that is expensive to get wrong and
free to get right.

---

## B13. Per-unit costs -- the taxes paid on every operation

The sections above chase big single costs.  This one is about small costs
multiplied by enormous counts, which is where systems usually actually spend
their time and which nothing in FGX has ever measured.

**All five are answerable with the B11.0 PC sampler and none has been asked.**

### B13.1 -- The interrupt tax

`toolbox.s:105` -- the heartbeat task body runs **at every VBL, ~60 Hz**,
forever, on every machine, whether or not anything needs it.  Sixty invocations a
second of anything is a standing cost, and nobody has measured what the body
costs or whether every part of it needs to run at 60 Hz rather than at 1 Hz or on
demand.

Serial is the sharper case.  `serial.s` programs the SCC for **9600-8N1 with
IRQ RX/TX**, which at full rate is on the order of **~960 interrupts per second**.
Each one is an entry, a save, a dispatch and a restore.  If the per-interrupt
overhead is even 200 cycles, that is a fifth of a 1 MHz machine's budget spent
before the handler does anything useful -- and telnet sessions run over exactly
this path.

**Cheapest probe:** sample with the serial line idle and again with it saturated.
The difference IS the interrupt tax, and it needs no instrumentation beyond
what exists.

### B13.2 -- The context-switch tax

Every task switch saves and restores state, and on this machine that includes
**fcc's register file** -- `include/kernel.s:607` describes `$98-$FF` laid out the
way a task direct page wants, and `:657` notes "THE STACK IS HALF OF IT, and
naming only the register file is how this gets" underestimated.

With `CFG_KERNEL_NPROC` 12 and a 60 Hz tick, switches are frequent.  The question
nobody has asked: what fraction of a busy second is spent switching rather than
running?  If it is material, the levers are fewer switches (longer quantum),
cheaper switches (save less), or both.

### B13.3 -- The tty per-character tax

BSD line discipline is per-character by construction: clists, `q_to_b`/`b_to_q`,
and a wakeup path (`src/kernel/tty/kc_sys.s`).  Every byte in or out of a
console, pty or serial line walks it.

At 9600 baud that is ~960 characters/second through a chain that was designed for
a PDP-11 with a real UART, on a machine where the same path also feeds the SHR
console's 100-150 ms repaint (B12).  **The tty layer and the console layer are
the same cost centre viewed from two ends**, and B12's measurement question
answers part of this one for free.

### B13.4 -- 32-bit arithmetic on 16-bit hardware

`off_t` is 32-bit and every file offset computation touches it.  fcc has no
divide, and `fsparam.h:209` records the consequence directly: `off / FS_BLKSIZE`
is a 32-bit divide, avoided there with a shift because the runtime measured
**1,655 bytes** against 737 bytes of free far bank.

The question is how many other hot paths do 32-bit work that could be 16-bit, or
divide by something that is not a power of two.  This is `grep`-able before it is
measurable, which makes it unusually cheap to scope.

### B13.5 -- The allocator

`malloc`/`free`/`sbrk` sit under everything, and FGX's heap arrangement is its
own (a per-task sbrk arena inside the data bank).  Fragmentation costs bytes in
the resource this machine is shortest of, and allocation cost is paid per call.

There is precedent that this pays: earlier allocator-adjacent work measured
**`memcmp` at -30%** and **`strlen` at -54%**.  Those numbers say the libc
primitives were not near optimal to begin with, and nothing suggests the
allocator has had the same attention.

---

## B14. The developer loop is a performance problem too

Different sense of the word, and worth separating rather than dropping, because
it is the cost paid most often by the people doing everything else in this file.

Measured this session, on real runs:

* `tools/gate.sh` end to end: **~10 minutes** when it completes.
* fcc fixtures alone: **~5 minutes** (626 fixtures).
* The multibank sweep: **~5 minutes**, and it rebuilds the kernel and disk image
  to run 44 assertions.
* A single MAME boot test: **~40 seconds**, most of it the 25-45 s guest boot.

**Every idea in this document will be validated through that loop**, so its cost
multiplies into all of them.  A performance dive that runs fifty A/B measurements
pays the boot time fifty times over -- which makes B9.1's snapshot boot
interesting for a second reason nobody has counted: it would speed up the
measurement of everything else.

Directions, unexplored:

* **A save-state fast path for tests that do not need a cold boot.**  `run.py`
  already has `--boot-state` and a `shell_ready` slot, and `BOOT_FRAMES_LOADED`
  is 180 frames (3 s) against 2,700 for a cold boot -- but the header says it is
  "only used if/when state-load gains a working keyboard-input path".  **A 15x
  reduction in per-test time is sitting behind one unfinished feature.**
* **Make the sweep not rebuild the world.**  It runs `./build.sh disk` to test 44
  compiler assertions.
* **Parallelism is already there** (`-j`, capped at 8) but competing MAME
  instances change guest timing, which is why timing-sensitive tests must declare
  `serial: true`.  That tension is unmeasured: how much wall clock does the cap
  cost, and how much accuracy would raising it lose?

This section is deliberately last because it improves nothing a user sees.  It is
here because a dive that ignores it will spend more time waiting than measuring.

---
---

# PART 3 -- PLAN OF ACTION FOR THE DIVE

Agreed with the maintainer 2026-09-08.  **Fable 5.1 is a working participant in this
dive, not a reviewer at the end**: it advises, informs, and ANTAGONISES.

The plan is ordered so that the cheapest disproofs come first and the expensive
work is gated on numbers.  Nothing here is committed to; each phase ends with a
decision that can cancel the next.

## Phase 0 -- Make measurement possible.  BLOCKING.

Nothing else starts until this is done, because every number below depends on it
and this file has already caught itself asserting things it had not measured.

**0.1 -- Prove the PC sampler works, with a positive control.**  It exists
(`fgxdebug/init.lua`, `"pc_sample"`), and it has never been used in anger.  Run
it against a program with a known hot loop and confirm the histogram points
there.  *A profiler that silently samples nothing looks exactly like a flat
profile.*

**0.2 -- Stand up a benchmark corpus.**  Adopt the programs from
`examples/65816-llvm-mos/benchmarks/` (B8.1).  Twenty-odd C programs chosen by
someone solving the same problem on the same CPU; adopting the programs is not
copying the compiler.  Wire them to run under the existing harness.

**0.3 -- Take the baselines and WRITE THEM DOWN.**  Boot profile, the benchmark
suite, and the four figures this file flags as stale: apple/fgx#37's bank
arithmetic, the 630 ms `execve`, apple/fgx#307's read gap, the console repaint.
Two predate the UFS root swap and must not be built on until re-taken.

**Fable's job in Phase 0:** attack the instrument.  What would make the sampler
lie?  What does it not see (ROM? IRQ context? a task that never runs)?  Is the
benchmark corpus representative of FGX's actual workload, or of a compiler
benchmark's?

## Phase 1 -- The cheap kills.  One measurement each, one afternoon total.

Each of these ELIMINATES OR PROMOTES a whole section for the price of a single
measurement.  Run them all before building anything.

| # | measurement | decides |
|---|---|---|
| 1.1 | console cost as a fraction of boot (PC sample) | B12 -- top of the file, or a curiosity |
| 1.2 | interrupt tax: sample idle vs serial saturated | B13.1 |
| 1.3 | bulk read of ~600 KB vs the 25 s boot | B9.1 snapshot boot |
| 1.4 | ROM `UnPackBytes` throughput vs 25 KB/s | B9.6, B1.3 -- and B6's premise |
| 1.5 | Toolbox empty-call dispatch cost | prices every B6 idea |
| 1.6 | is the Toolbox reentrant enough to call from >1 task? | closes or opens most of B6 |

**Fable's job in Phase 1:** for each result, argue the opposite reading.  A
number that looks decisive usually has a confound, and this session produced four
of them (a harness that never rebuilt, a cap mistaken for an allocation, a
correlation asserted as a cause, an absence asserted without a search).

## Phase 2 -- Levers already built and switched off

Cheapest real work in the file.  All three are small, and two are one line.

**2.1 -- `bdwrite`.**  `ufs_inode.c:718-727` says import it "when a measurement
says the inode write-back is what costs, not before."  Phase 0 provides that
measurement.  Import it or record why not.

**2.2 -- `NBUF`.**  16 buffers, 16 KB, on an 8 MB machine.  Raise it, re-run
apple/fgx#307's case, keep the number that wins.

**2.3 -- The stack-hint default.**  FGX gives an undeclared binary ONE page;
GNO gives 4096 bytes (B7.1).  Decide the number deliberately -- and land
apple/fgx#367's model fix with it, since 17 tools currently carry a page count
derived from a model that cannot see libc.

## Phase 3 -- The pile.  Gated on Phase 0/1.

**Three of this file's ideas are one idea**: stop carrying 89 copies of libc.
`/bin` + `/sbin` is 5,992 KB across 89 binaries on an 8,320 KB machine, and the
pile is essentially all of it.

Decide between the routes on Phase 0's numbers, not on taste:

* restore byte-identical piles so the loader's existing share key matches again
  (B1.1 -- smallest change, existing mechanism)
* a resident shared libc (B5/B7.2 -- GNO proves the shape works here)
* GOT/PLT-style indirection through per-process data cells (the Train 1 P2
  design already in the ledger)
* busybox as a MEASUREMENT even if never shipped, to get the empirical floor
  (B9.2)

**Fable's job in Phase 3:** be the adversary on the design, before code.  Which
route breaks `fork`?  Which breaks the share key?  What does each cost in bank 0
specifically?  What does it do to apple/fgx#37's arithmetic when N tasks differ?

## Phase 4 -- Only now, the targeted work

Whatever the profile actually names.  Hand assembly (B10) belongs here and
nowhere earlier, under its own five-step order: vendor C, fixture, measure,
replace the dominant path, re-measure.

## How to use Fable well, learned from this session

* **Give it the established facts AND the traps up front.**  The review that
  solved apple/fgx#365 worked because it was handed four measured facts, three
  traps, and the house rules -- it spent its time on the unknown rather than
  rediscovering the known.
* **Ask for the discriminating experiment, not the answer.**  "What single test
  separates these two hypotheses" is the question that pays.
* **Tell it that disproving us is the valuable outcome.**  It corrected two of
  this file's claims; both corrections were worth more than the sections they
  fixed.
* **Do not run a gate while it works the same tree.**  A concurrent rebuild
  corrupted `disk/fgxufs.po` this session and produced a "build failed" that
  looked like a code defect.  Give the agent the tree, or work elsewhere.

## The discipline this dive runs under

Carried forward because every one of them cost time in the session that produced
this file:

1. **A cap is not an allocation.**  Measure what the thing actually got.
2. **A check whose tool did not run looks like a pass.**  Positive control, every
   time.
3. **Correlation is not a mechanism.**  Name the discriminating test first.
4. **Search before declaring something absent.**  Twice wrong on that here.
5. **The harness types on a fixed schedule.**  A timing A/B that ignores it
   measures the harness.
6. **One variable per run.**
