# The performance dive: what was measured, what it costs, and what to do

Companion to `2026-09-08-performance-survey.md`, which listed fourteen
categories of ideas.  This file reports what happened when they were measured.
Every number here was taken on the tree at the commit named beside it; every
claim that is NOT measured says so.

Fable 5.1 worked this dive as an adversary throughout, on five separate briefs.
It corrected this file's author on six substantive points, three of which
changed a recommendation and one of which killed one outright.  Those
corrections are marked where they land.

## Status

The three items that were not performance work -- the instrument, a latent
defect, and the developer loop -- are **fixed**, verified by the gate's full
43-test MAME set passing 43/43.

| | | status |
|---|---|---|
| apple/fgx#369 | the PC sampler | **all four defects fixed** |
| apple/fgx#370 | libc's user-context Toolbox call | **fixed** |
| apple/fgx#374 | harness state restore | **fixed**, 4.37 s -> 1.35 s per test |
| apple/fgx#364, #366 | fixed by earlier merges | **closed** in triage |

The five optimisation items (7.1-7.5) are open.

### What the fixed sampler actually says

The old profile's biggest number was an artifact.  With sampling decoupled from
the frame, ten execs of `basename` spend:

    47.8%  idle, post-WAI SEI      (sched.s:428)
    12.4%  bank-0 slot firmware    (SmartPort reads)
    10.2%  _fcb_mvn                (fork's bank copy)
     8.3%  the tool's own code
     0.2%  _KcDp_Save              (the old sampler's 40%)

**About sixty per cent is disk I/O and waiting for it**, which corroborates the
separately measured finding that exec cost is essentially all byte-proportional.
The fork copy's 10.2% independently reproduces the 262 ms that ten forks cost by
wall-clock A/B.

## What came out of it

**Seven work items filed**, ordered by measured value:

| | finding | measured |
|---|---|---|
| apple/fgx#373 | `putchar` is one `write(2)` per character, and `ufs_write` is synchronous | 10.57 ms per output character; ~95 B/s |
| apple/fgx#368 | the shared-libc mechanism exists and NEVER fires | 5.2-6.0 s of a 26.8 s boot |
| apple/fgx#372 | fork copies four full 64 KB banks per command | 440 ms of the 781 ms cost of `true` |
| apple/fgx#369 | the PC sampler armed on frame 1 and reported on zero samples | two of four defects fixed |
| apple/fgx#371 | fcc's loop safepoint spends 12 of 20 cycles on JSR/RTS | per iteration of every loop |
| apple/fgx#374 | the harness's state restore works now | 2.03 s per test, 2.5x |
| apple/fgx#370 | libc still makes the user-context Toolbox call the kernel exists to prevent | latent; `cal` currently survives it |

**Answered apple/fgx#362**: process creation is roughly two thirds of boot,
measured by A/B rather than modelled.

**Eight ideas killed with a number**, including three of the survey's own
proposals and one of this dive's.  It corrected this file's author on five substantive points, three of
which changed a recommendation.  Those corrections are marked where they land.

---

# PART 1 -- THE METHOD, AND WHY IT CAN BE TRUSTED

Nothing below is worth reading if the instrument lies, and the first thing this
dive found is that it did.

## 1.1 The measurement that works: frame counts with the typing controlled

The MAME harness types a command on a **fixed schedule** and the survey's own
standing traps say a timing A/B that ignores that measures the harness.  It
does, and it is large:

    typing = 6.133 frames/char = 102 ms/char

Derived from two runs of the SAME ten execs of `true` at two command lengths
(49 chars -> 769 frames; 139 chars -> 1321 frames).  The per-command cost
backed out of each run agrees to two decimal places -- 46.85 frames from both.
That agreement is what makes the correction trustworthy rather than a fudge.

**Typing 139 characters costs 853 frames, or 14.2 seconds.**  In a 1321-frame
run that is 65% of the measurement.

The method that survives it: run each command **ten times** with command
strings **padded to identical length**, so typing is a constant that cancels in
every comparison, then subtract 6.133/char to recover absolute costs.

Validation on runs not used in the fit:

| run | chars | predicted | actual |
|---|---|---|---|
| `echo x` x10 | 69 | 1059.5 | 1057 |
| `basename /a/b` x10 | 139 | 1549 | 1549 |

**Run-to-run noise is ZERO.**  Both boot variants were repeated and returned
byte-identical frame counts (121, 121 and 37, 37).  MAME driven headless from
the same image is deterministic, so a difference of one frame is a real
difference.

That has a consequence worth stating: `true` and `false` have IDENTICAL segment
layouts (CODE 4294, DATA 3735, LIBC 11557, 4 relocs) and identical file sizes,
yet differ by a consistent 1.2 frames per exec.  That is not noise -- it is a
real systematic effect, most likely disk placement changing where reads fall
against the 8 KB read-ahead runs, though this dive did not chase it.  Treat 1-2
frames as the resolution of an unexplained systematic, not as error bars.

## 1.2 Every figure here is harness time, and the harness is 2.5x fast

`run.py:1361-1367` forces MAME's ZipGS CPU type to 1, i.e. **7 MHz**.  The
kernel's own VBL-ratio probe agrees -- the boot banner reads "65816 @ 7.0MHz".

**A stock Apple IIgs is 2.8 MHz.**  So every millisecond in this file is roughly
**2.5x optimistic** for real hardware.  CPU-bound terms (the MVN copies, the
byte loops, fcc's codegen) scale with that; shadowed SHR writes, device I/O and
anything bus-bound do not.  Frame counts and ratios are unaffected, which is why
the comparisons here are stated as ratios wherever it matters.

This is not a small correction.  An earlier draft of the fork analysis assumed
2.6 MHz and computed a full-bank MVN at 176 ms; at 7 MHz it is 65.5 ms.

## 1.3 The PC sampler: four defects, two first-order (apple/fgx#369)

The survey's Phase 0 said "prove the sampler works, it has never been used in
anger."  Both halves were wrong.  It HAS been used -- the elvis redraw baseline
(2026-07-09), the vi startup work (2026-07-20), the telnetd stall hunt
(2026-07-24) -- and there is a whole toolkit at `tools/profile/`.  That was the
project's "search before declaring something absent" trap, hit a third time.

What an audit of it found:

1. **It armed on frame 1.**  The gate asked only whether scripted input had
   fired; the autoboot path leaves `input_script` empty, so the test passed on
   the first frame of the ROM boot and **every histogram contained a whole
   boot**.  Regressed at `7e0495a6b` (2026-07-12).  Both profiling workloads are
   that shape.  **Fixed** (`45b7d237a`), verified by a log that shows no samples
   through frame 1499 and arming at 1500.
2. **A run that sampled nothing rendered an all-0.0% report and exited 0** --
   the instrument failing was indistinguishable from a flat profile.  **Fixed**
   (`45b7d237a`), with both controls: a zero histogram now exits 2, a populated
   one still exits 0.
3. **Sampling is phase-locked ~1.4 ms after the VBL IRQ.**  Not fixed; it needs
   a coroutine sampler.  This is why magnitudes below come from A/B timing and
   never from the sampler.
4. **The report's "libc" row is the fcc runtime, not libc**, and a libc-heavy
   run has its seg2 samples resolved against the wrong listing into fabricated
   symbol names.  Not fixed.

**The consequence for method:** the sampler is used here to LOCATE and A/B frame
timing to MEASURE.  Never the reverse.

The phase lock is not theoretical.  In the one profile taken, `$7C:90D1` holds
440 samples while `$90D2` -- the *identical adjacent `INX`* -- holds zero.  Two
identical two-cycle instructions cannot differ 440:0 under a fair sampler.

---

# PART 2 -- FINDINGS

## 2.1 The libc pile: a working share mechanism that never fires (apple/fgx#368)

**Status: confirmed empirically, filed, quantified.**

`SEG_KIND_LIBC` segments are **3,556,214 bytes -- 60.3% of all userland**
(CODE 29.9%, DATA 9.8%) across 83 binaries.  Mean pile 42,845 B.

The loader implements sharing: a content-addressed share key `{size, 24-bit
checksum}`, a refcounted registry, and on a key match it maps the resident bank
and **skips the segment's file bytes** with `Fs_Lseek(fd, SEEK_CUR, size)`.

It never fires.  Measured directly by dumping the registry after a full boot
plus an exec:

    _libcShBank = $45   _libcShRef = 1   _libcShLen = $E655   _libcShSum = $615F03

Those are init's key, predicted from init's own header BEFORE the run.  After
sh, cat, modload, echo x2, dhclient, inetd and getty x2 have all exec'd, the
refcount is **1**.

**Two independent causes, either fatal alone:**

* the registry is a **single slot**, and init pins it.  init's pile is unique
  among all 83 binaries and init never exits, so nothing else can ever share.
  `cat` and `modload` are byte-identical and back-to-back in `/etc/rc`; both
  still miss.
* dead-stripping made the piles per-binary distinct -- only 47 of 83 are
  byte-distinct.

**Why nobody noticed:** `loader.s:812` comments the miss arm as "observable in
dmesg"; the arm is a bare `BRA`, and `_libcShWarn` is defined at `loader.s:64`
and referenced nowhere in the tree.  The diagnostic was never wired up.

**Cost:** boot reads 442,017 pile bytes.  At the measured libc coefficient that
is 6.0 s, of which **5.2 s is avoidable**, out of a 25-30 s boot.

**What Fable killed:** "go back to one universal pile" is no longer available.
libc grew from 42 to 57 members; the union is **>= 76,190 B against a 65,536 B
bank**, tcsh already sits at 64,966 B with 570 B of headroom, and `fgx_ld.py`
refuses a second LIBC segment.  apple/fgx#37 listed that revert as option 1 in
August; **it has expired.**

**What fits:** the union over just the boot set is 36 members = **55,508 B, with
10,028 B of headroom**.  A boot-class pile that init also links pins the single
slot to the class that matters, needs no kernel change, and is the actionable
shape.

**Relationship to prior work:** apple/fgx#37 recorded the zero-sharing outcome
in August and the maintainer accepted it "for now".  New here: the single-slot/init-pin
mechanism, the dead diagnostic, the price in seconds, and the expiry of #37's
own proposed fix.

## 2.2 Fork is the majority of the cost of running a command

**Status: the cost is measured.  My proposed fix was wrong and is recorded here
as wrong, because the reason is the useful part.**

The Bourne shell does not fork for a builtin, and a `( ... )` subshell forks
without exec'ing.  Three commands at identical length decompose the cost exactly,
with typing cancelling:

| | per command | share of `true` |
|---|---|---|
| shell dispatch (`:`) | 101 ms | 13% |
| + fork (snapshot + restore) | 440 ms | 56% |
| + exec (load, reloc, start) | 240 ms | 31% |
| **`true` total** | **781 ms** | |

`_Fork_CopyBank` (`src/kernel/process.s:1161`) moves a **full 64 KB bank** --
`LDA #$FFFF` then an inline self-modified `MVN` -- and runs twice per fork/exit
cycle (`:1292` snapshot, `:1557` restore).

**sh's fork builds TWO pairs, not one.**  sh's FGX2 header byte 15
(`FGX2_OFF_SOFTBANK`) is 01, so `_Loader_SeedSoftBank` (`process.s:1770-1780`)
allocates a dedicated soft-frame bank at exec and `_Fork_Snapshot` snapshots it
as pair 1.  So a fork/exit cycle is **four** full-bank MVNs.

At **7 MHz** -- which is what the harness runs (`run.py:1361-1367` forces ZipGS
CPU type 1; the kernel's own probe agrees, "65816 @ 7.0MHz") -- one full-bank
MVN is 65,536 x 7 = 458,752 cycles = **65.5 ms**.  Four of them is **262 ms of
the measured 440**.

The remaining ~178 ms is not mysterious: the stack and DP copies
(`process.s:1400-1442`, `1562-1610`) are hand-rolled BYTE loops at ~37
cycles/byte -- **five times MVN's rate** -- and sh's ~4 KB stack plus 256 DP
bytes, copied in both directions, is ~46 ms.  The rest is Bank_Alloc/Free, the
Kmalloc'd descriptor, and the child's own `:` body and reap.

### The fix I proposed, and why it is dead

I proposed bounding the data-bank copy by the DATA segment size from the FGX2
header -- sh's DATA is 12,760 bytes of a 65,536-byte bank, which looked like a
4x cut.

**It would silently corrupt sh on the first command.**  The data bank is not the
data segment:

    [0, end)          data + bss        (sh: end = $31D8 = 12,760)
    [end, HEAP_BRK)   the sbrk heap     <-- sh's ENTIRE blok/stak arena
    [$FFFA..$FFFF]    HEAP_BASE/HWM/BRK

`malloc.c:1-5` says it outright: "The heap is the tail of the process DATA
segment ... so snapshot-fork's pair-0 copy carries the heap with the image."

I had it backwards because I read a stale comment.  `_Sys_Brk`'s header at
`process.s:1846-1848` still says "per-task PRIVATE sbrk bank", and it is
contradicted thirty lines later at `process.s:1880-1889` (changed 2026-07-23).
**Two stale comments in the tree should be corrected before they mislead the
next reader the same way.**

**And the break is not a safe bound either.**  FGX has no write-fault, and
2.11BSD's sh blok arena writes ABOVE the break -- upstream relies on a MEMF
fault to grow.  `blok.c:100-106` calls its own guard "currently UNVERIFIED", and
apple/fgx#361 (open) MEASURED that zero-filling `[old, new)` on grow kills the
boot in init's rc shell.  Live bytes above the break exist in a real shell
today.  **Until #361 closes, no bound below `$FFFF` is safe for pair 0.**

### What IS safe, in order of confidence

1. **Bound pair 1 (the soft-frame bank) by the parent's `_fcc_sfp`.**  The soft
   bank grows DOWN from `$FFFE` with page 0 as a guard
   (`fcc_runtime.s:164-168`), the prologue lowers `_fcc_sfp` BEFORE writing
   through it, and the loader places nothing else there.  So the live extent is
   exactly `[sfp, $FFFF]`, and for a simple command it is under 2 KB of 64 KB.
   **~130 ms of the 440.**  The parent's sfp must be read from the descriptor's
   DP copy, not the live DP, which by then holds the child's.
2. **Convert the stack and DP byte loops to MVN** -- both banks are known.
   **~37 ms**, and it is a strictly local change.
3. **Bound the stack copy to `[userSP+1, top)`** -- the hardware stack below SP
   is dead.  **~30 ms** for sh.
4. **Bound pair 0 by `HEAP_BRK`** -- DO NOT BUILD until apple/fgx#361 closes.

No copy-on-write is available: there is no MMU, and runtime far pointers (stak
pointers, `_fcc_sfp+2`, malloc'd pointers) carry the parent's bank byte, so
running the child in the spare bank would write through to the parent.

sh calls `fork()`, never `vfork()` (`xec.c:243`), and correctly so -- the child
mutates globals and the arena before exec'ing.

## 2.3 Cold cache costs 14%, and "read speed" is two different numbers

Ten DISTINCT binaries (418,498 B), each run once, against the same total command
length as the warm runs:

    warm-fit model predicts   654 frames
    actual                    744 frames     = 1.14x

So a cold buffer cache costs **14%** over the repeat-the-same-binary case.  The
effective rate over that run is **33 KB/s** against the ~70 KB/s marginal rate.

**Two rates, and they are not interchangeable.**  ~70 KB/s is the MARGINAL cost
per byte of segment.  Anything lower is an EFFECTIVE rate that has amortised the
fixed per-exec cost, the cold-cache penalty, or the program's own startup work
over the bytes.  apple/fgx#307's ~15 KB/s (stale, and ProDOS) and apple/fgx#362's
22-26 KB/s are effective rates over different windows.  Quoting a single "read
speed" for FGX is how those three numbers came to look like they contradicted
each other.

**Trap that voided the first attempt at this measurement:** `printenv` prints
`PS1=fgx#`, and `fgx#` is the harness's exit sentinel.  The run terminated after
3 of 10 commands and still passed every assertion, because the manifest only
asserted `fgx#`.  The rerun puts `echo ZZ` last and asserts `ZZ`, so the check
proves the final command ran.

## 2.4 The size model

    frames = 30.6 + 0.000875*(code+data) + 0.000818*libc      residuals <= 0.8 fr

    fixed per exec   30.6 frames = 510 ms
    code+data        68,545 B/s
    libc pile        73,359 B/s

The 510 ms fixed term and the independently measured 440 ms fork agree to within
the exec path's own non-byte work.

**The two halves cross-check against the fork/exec decomposition, and that is
the result which matters most here:**

    model intercept   30.6 fr = 510 ms   vs  measured shell + fork = 541 ms
    model byte terms  16.5 fr = 275 ms   vs  measured exec         = 240 ms

So the size-independent term IS the shell plus fork, and **exec cost is
essentially entirely byte-proportional**.  Bytes not read are time not spent,
roughly one for one.  That is what makes apple/fgx#368's arithmetic sound
without needing a separate I/O-versus-CPU split: there is almost no CPU term in
exec to begin with.  The two per-byte coefficients agree within
3%, which matters because **the libc pile carries zero relocations**: if
relocation were a material load cost, code+data would cost visibly more per
byte.  It does not, so load cost is essentially pure read at ~70 KB/s.

---

## 2.5 Boot: process creation is roughly two thirds of it (apple/fgx#362)

**Measured directly, not modelled.**  `/etc/rc` was replaced at test time
through the harness's `stage_files` (which stages into the UFS root,
`run.py:1414-1416`) with a version carrying only a comment -- no `modload`, no
`netstart`, no `inetd`.  Nothing in the tree was modified.  The stripped boot
reaches a prompt cleanly.

Prompt arrival was bracketed by SWEEPING the autoboot paste delay, because the
obvious measurement is wrong twice over (see Part 4, trap 6).  With a prompt
already waiting a one-character command costs ~12 frames, so prompt arrival =
paste + delta - 12.

    base      prompt at frame ~1609 = 26.8 s
    stripped  prompt at frame ~1057 = 17.6 s
    difference                552 frames = 9.2 s   (34% of boot)

Six execs removed, 323,076 bytes of binary.  **The model predicted 681 frames;
the measurement is 552 -- a 19% over-prediction**, which for a model fitted
entirely on shell workloads and applied to init's boot path is close enough to
build on.

Scaled to all eleven boot execs, process creation is roughly **18 s of the
26.8 s boot**.  It is not module loading, not the console (~1%), not dhclient's
failure.

The 9.2 s above was bought by deleting features.  The libc pile is 442,017 bytes
of the same budget and removing ~6 s of it costs no functionality at all, which
is why apple/fgx#368 is the first thing to do rather than the largest number.

---

# PART 3 -- WHAT WAS DISPROVEN

Recorded because each of these is an idea the survey proposed, and killing one
cheaply is the point of the exercise.

## 3.1 "Raise NBUF" -- already disproven in the tree

Phase 2.2 of the plan reads "NBUF: 16 buffers, 16 KB, on an 8 MB machine.
Raise it."  Two things are wrong.

**It conflates two caches.**  `VFS_NBUF` = 16 (`include/vfs_equ.s`) is the VFS
buffer cache and it is **hash-chained** (`vfs_bio.c` walks `dp->b_forw`,
standard 4.3BSD `bufhash`).  `BLKCACHE_NBUF` = 24 (`include/fs.s:525`) is the
lower block cache.

**The lower one is already tuned, and growing it is a measured regression.**
`include/fs.s` carries the table:

    NBUF win LRU  K | a2scsi retronet
     24  16   8  16 |   468     588   <- current
     32  16  16  16 |   480     612
     64  32  32  32 |   492     672
     64  16  48  16 |   516     732

The recorded reason: the cache is **scan-bound, not capacity-bound** -- a
streaming read's misses are compulsory, so capacity buys nothing while every
added slot costs scan time.  `_BlkCache_Lookup`
(`src/drivers/block/blkcache.s:102`) is a linear walk, ~1,080 cycles on a full
miss (~0.15 ms at the harness's 7 MHz, ~0.39 ms on a stock 2.8 MHz machine).

The tree names the real lever itself: **an indexed lookup, not more slots.**

## 3.2 PATH search is not a cost

A/B with identical 13-char command strings: `true` x10 = 1321 frames,
`/bin/true` x10 = 1309.  **1.2 frames per exec = 20 ms = under 3% of a `true`**,
and 1309 is exactly what the `false` control returned -- i.e. inside noise.

## 3.3 Binaries do not store BSS

A hypothesis of this dive's own, killed by its own measurement.  Only **882
bytes** across all 83 binaries are trailing zeros.  There is 1,013,066 bytes of
interior zero (17.2%), but 10.3 points of that is runs of length 1-2 -- ordinary
zero high-bytes of 16-bit values, not eliminable.

Zero runs >= 32 bytes total **397,925 bytes (6.75%)**, concentrated in sed
(33,676 B, 28.8% of the file, one 30,942-byte run in its DATA segment), vi, tcsh
and fsck.  Eliminating those needs the linker to partition zero-initialised data
to the end of the DATA segment and declare it as `bss`; every link generator in
the tree currently hardcodes `"bss": 0`.  Worth doing, but it is a linker change,
not the one-line flag the shape first suggested.

---

# PART 4 -- TRAPS THIS DIVE HIT

Each cost real time and each is a general lesson.

1. **The harness types on a fixed schedule, and it is 65% of a run.**  Padding
   command strings to equal length makes it cancel; forgetting it makes you
   report the harness.  This dive published a wrong "1.91 s fixed per exec"
   before catching it -- the tell was `:`, the null builtin, appearing to cost
   1.5 s.
2. **`printenv` prints `PS1=fgx#`, which IS the harness's exit sentinel.**  A
   cold-cache run terminated after 3 of 10 commands and still passed, because
   the manifest only asserted `fgx#`.  A workload manifest needs a positive
   control that proves the LAST command ran.
3. **A `memory_regions` entry lands under `memory.<name>` in dump.json**, not at
   a top-level key.  Reading the wrong key returns empty and looks exactly like
   "the mechanism left no trace".
4. **`run.py` refuses to run while `ninja -n` has work**, and a bare `build.ninja`
   regeneration counts as work.
5. **`ls` is aliased to a colourising tool**; capturing a path from it embeds
   ANSI escapes and the next command fails with a bizarre filename.
6. **The harness cannot measure a boot faster than its own paste frame.**  A
   boot A/B with `-autoboot_delay 25` floors every result at frame 1500: a
   stripped boot that finishes at frame 600 still reports ~1512.  Lowering the
   delay does not simply fix it either -- pasting before the prompt exists
   stalls the run to its timeout, because the command is typed into a shell
   that is not reading yet.  Bracketing the prompt with a delay SWEEP is the
   method that works.
7. **`$?` after a pipeline is the last command's status**, so `cmd | tail` hides
   a non-zero exit -- which is how a guard's own self-test first appeared to pass.

---

# PART 5 -- THE TOOLBOX AND THE CONSOLE (B6, B12)

Both sections rested on premises that turned out to be false.  Investigated
adversarially against the IIgs documentation, the GNO/ME sources and the tree.

## 5.1 The Toolbox is not reentrant, and FGX gets away with it only by construction

**B6's enabling question was whether the Toolbox can be called from more than
one task.  It cannot.**

Toolbox Reference vol 2 p333: *"Much of the system code is not reentrant; that
is, the code cannot be called while it is already executing ... The only time
you need to use the Scheduler is when you are writing ... Interrupt handlers
that access ProDOS 16 or the tool set routines."*  vol 2 p649 describes the busy
flag that makes a tool set non-reentrant by construction, and the work-area
pointer table at `$E103C8` holds **one** work-area pointer per tool set -- there
is no per-caller context.

The precedent is decisive: **GNO/ME, a multitasking kernel on this exact
hardware, mutexes the entire Toolbox.**  Its manual says "there is a limit of one
process at a time inside either GS/OS or the ToolBox", and `contextSwitch` in
`gno_kern/gno/kern.asm:1281` refuses to switch while the busy flag is non-zero.
The one tool set GNO does not mutex is TextTools, which GNO **rewrote** to be
reentrant.

FGX's answer is stricter and already correct: every Toolbox call is in kernel
context and the kernel is non-preemptive.  It has also **already been burned by
this exact hazard** -- `src/kernel/far/clock.s:80-92` records a user-context
`ReadTimeHex` that "NEVER RETURNS for tcsh", with PC sampling putting tcsh 89.9%
in ROM.  The fix was `_Sys_RtcRead` (#31), with `SEI`, the stack bounced to page
`$01`, and `D=$0000`.

**Consequence for B6:** any Toolbox use stays kernel-only.  Serialising a
userland call through the kernel costs a syscall crossing *plus* dispatch, so
per-call ROM routines cannot pay for themselves.  Only bulk operations could.

**One live instance found and filed (apple/fgx#370):** `libc.s:691-698`
(`today_init`) still makes the user-context call, reached by `cal` with no
arguments.  Measured: bare `cal` currently works and returns.  It is latent, not
failing -- and it is one preemption away from the tcsh hang.

## 5.2 Toolbox dispatch costs ~400 cycles, which prices every B6 idea

No published figure exists, so it was counted from Apple's own dispatcher source
(`iigs_system_601 GSToolbox/tl/tl.asm:576-679`).  The path pushes an `AnRTL-1`
frame, loads `TPTPtr`/`WAPTPtr` from bank `$E1` (slow RAM), makes the stack the
direct page, validates tool and function numbers, and returns through
`PLX/PLD/PLA/PLY/RTL`.

**~247 cycles to the tool's first instruction; ~400 cycles including the return,
the parameter strip and the busy-flag pair.  About 150 us at 2.8 MHz, before the
tool does any work.**

That kills the per-call ideas outright: a ROM `LongDivide` is itself a
~1,000-cycle shift-subtract loop, so dispatch adds 40% and the ROM saves *bytes*,
not time.  `Munger` on a short string loses outright.

## 5.3 PackBytes cannot compress code -- the premise is wrong

B6 claimed FGX is "already inside the tool set that holds a compressor".
PackBytes is a **scanline RLE**, not a general compressor: Toolbox Reference
vol 1 p651 gives four record types (literals, and repeats of one byte or a
4-byte pattern).  TN #94 adds that it "is not guaranteed to shrink the source
data".

Measured with a greedy-optimal packer (so the ROM cannot beat it) on current
binaries:

| binary | size | PackBytes best | zlib -9 |
|---|---|---|---|
| sh.bin | 114,146 | **93.3%** | 26.1% |
| ls.bin | 96,276 | 92.9% | 24.8% |
| inetd.bin | 90,903 | 95.0% | 23.7% |
| cat.bin | 50,886 | 93.9% | 27.3% |

The 5-7% is entirely zero runs.  At ~70 KB/s that saves ~110 ms on `/bin/sh` and
costs an unpack pass plus dispatch.  **B1.3 needs a real LZ codec, and
`compress` (LZW) is already ported.**  ACE is worse: audio-only, lossy, and its
tool table is a `DummyTable` in ROM -- it is loaded from disk by GS/OS, which
FGX does not have.

**Related correction:** "1,053 routines execute out of ROM" is false.  Only 21
tool sets are ROM-resident; Loader, QDAux, Print, StdFile, ACE, Resource, MIDI,
TextEdit and everything above #28 are `DummyTable` entries loaded by GS/OS.
From a raw boot with no `LoadOneTool`, FGX can reach only the ROM sets.

## 5.4 The console has a hardware floor, and it is not where boot time goes

**Every SHR store is shadowed to bank `$E1` and stretched to 1.024 MHz.**  The
framebuffer is 32,000 bytes, so a full repaint has a **~32 ms hardware floor at
any CPU speed**.  The measured `Con_RenderAll` is 40.6 ms -- already ~80% of the
floor.  **Further CPU optimisation of the SHR renderer is capped at about 20%.**

That is the real argument for B12's 80-column text mode, and it is a better
argument than the one B12 makes: an 80x24 text page is 1,920 bytes, so its
repaint/scroll floor is ~2 ms.  **About 16x** -- and it is the *only* way below
32 ms.

**But B12's headline claim is false.**  The recorded boot log is ~22-25 lines,
i.e. at most a few full-screen scrolls: **0.1-0.3 s of a 25-30 s boot, about
1%.**  Text mode is an interactive-throughput win -- `cat`, editors, anything
that scrolls -- not a boot win.

Two costs B12 does not account for: text-page-1 shadowing is currently
**inhibited** (`main.s:3742`, `$C035` bit 0) and must be re-enabled while a text
VC is visible; and **MAME's `apple2gs` does not emulate VidHD**, so B12.1's
80x45 / 120x67 modes cannot be measured or regression-tested in the harness at
all.

**Caveat on every console number in the tree:** they were taken at 7 or 16 MHz
emulation (`run.py:1361-1367` forces 7 MHz ZipGS).  Because the path is
shadow-write-bound the millisecond figures transfer to real hardware better than
most, but the CPU-bound parts are 2.5-6x slower on a stock 2.8 MHz machine.

---

# PART 6 -- fcc CODEGEN (B3), AND THE BENCHMARK CORPUS (Phase 0.2)

## 6.1 The corpus is C99, and fcc is right to reject it

Of the 19 programs in `examples/65816-llvm-mos/benchmarks/`, **10 compile under
fcc and 9 are rejected.**  All nine fail on the same construct -- a declaration
in the `for` init clause, `for (unsigned i = 0; ...)`.

That is not a toolchain gap.  K&R 2nd ed A.9.5 gives the grammar as

> `for (expression1; expression2; expression3) statement`

and states: *"In the for statement, the first expression is evaluated once, and
thus specifies initialization for the loop"*, with the equivalence
*"expression1; while (expression2) { statement expression3; }"*.  An
**expression**, not a declaration.  Declarations in `for` are C99.

**fcc is correct.**  Using the other nine requires hoisting the declarations --
a mechanical transformation that K&R's own equivalence shows preserves
semantics exactly, and which does not touch the algorithm.

The ten that build cover four of the six benchmarks for which llvm816 publishes
cycle baselines (`tests/benchSummary_2026_06_03.md`): bsearch 767, crc32 55,839,
djb2Hash 2,728, fib 11,764.  **A cycle-level fcc-vs-llvm816 comparison is
therefore available and is the single highest-value B3 measurement outstanding**
-- it needs the benchmarks wired as runnable FGX2 binaries, which this dive did
not do.

## 6.2 The loop safepoint: 20 cycles per iteration, 12 of them wasted (apple/fgx#371)

fcc emits `JSR _fcc_safepoint` at the top of every loop, so it runs **once per
iteration of every loop in every FGX program**.  The mechanism is right -- it is
what lets a compute-bound loop reach a scheduling boundary, so quantum fairness
and Ctrl-C both compose there.  The cost is the calling convention:

    JSR / LDAL / BEQ / RTS  = 20 cycles, of which JSR+RTS = 12 do no work

Inlining the fast path and leaving only the taken branch as a call gives 8
cycles, **a 60% cut**, for +6 bytes per loop site (sed has 80 loop sites: 480
bytes on a 116,822-byte binary).  Safe by exactly the argument the existing
comment already makes -- A and N/Z are dead at a loop top and X/Y survive the
yield.

For an average loop body of 100 cycles this is a 10% speedup on compute-bound
code.

## 6.3 Two suspected codegen problems that measurement killed

**The 256-byte frame cliff is real but never paid.**  fcc emits a Merlin
assembly-time conditional per local access: a single `LDA n,S` when the frame
offset fits in 8 bits, and a six-instruction reconstructed-pointer sequence
(`TSC/CLC/ADC/STA _fcc_fp/STZ _fcc_fp+2/LDA [_fcc_fp]`) when it does not -- ~5
cycles against ~20.  Scanning the built listings of twelve real tools (sh, ls,
cat, sed, grep, echo, basename, init, inetd, getty, true, wc, od, tr, cmp):
**zero slow-path accesses emitted.**  Real frames are small.  Dead.

**The `_fcc_img` memory pseudo-registers are not the general codegen model.**
They appear 18 times in every tool's listing -- a constant, which is the
runtime's own declarations, not uses.  They are the 32-bit intermediate
mechanism, which is why `crc32`'s `unsigned long` code uses them heavily and
`int`-based userland does not.  B13.4's premise (32-bit arithmetic as a
system-wide tax) does not hold for the ported tools, which are 16-bit throughout
-- as they must be, since 2.11BSD is a 16-bit-int codebase.

---

# PART 8 -- THE FAR-OUT LIST AND THE PER-OPERATION TAXES (B9, B13)

Costed from the tree.  Seven of nine far-out ideas are dead, and three of the
five taxes are too small to be levers.  Cycle totals below are COUNTED from
instruction sequences, not measured, and are marked where that matters.

## 8.1 The kill list

| idea | verdict | the fact that decides it |
|---|---|---|
| B9.1 snapshot boot | **DEAD** | The post-boot dirty set is ~1.7 MB plus bank `$E0/$E1` firmware RAM holding MM handle records and SCC/ADB state FGX does not own and cannot re-derive.  At 70 KB/s that restore IS the boot. |
| B9.2 busybox as a measurement | **DEAD** | The number it would produce is already computable from the segtabs: 80 staged binaries carry 3,271,950 B of pile in 44 distinct piles.  And it leaves fork (440 ms) and shell dispatch (101 ms) of the 781 ms untouched. |
| B9.3 bytecode for cold tools | **DEAD** | `true`'s CODE is 4,294 B and is crt0 plus the per-segment fcc runtime; `main` is three instructions.  A VM cannot remove that floor and must live somewhere -- the kernel bank has 2,554 B free. |
| B9.5 hold /bin in RAM | **DEAD today** | The ramdisk is ProDOS-format only (`ramdisk.s:485-497`), prodos.mod is gone, there is no newfs, and it has "no node and no mount, only a registration".  Non-pile /bin is 1,480,327 B against 1 MB. |
| B9.6 block-layer compression | **DEAD** | RLE bound over the staged set: **92.7%**.  A 7.3% saving does not pay for a codec call per block. |
| B9.7 profile-directed bank layout | **DEAD** | A seam crossing is ~35 cycles against a ~15,500-cycle `read(2)`.  Twenty crossings would be 4% -- and there is no free space to relocate into (core 2,554 B, vfs.mod 44 B). |
| B9.9 load-time specialisation | **DEAD** | Patch sites carry bank bytes only; with no cache on this CPU, specialising saves an operand fetch (~2 cycles) and breaks the share key. |
| B13.1 interrupt tax | **DEAD as a lever** | The tick body is ~900-1,000 cycles counted, ~1.1-1.4% of CPU at 7 MHz. |
| B13.2 context-switch tax | **DEAD as a lever** | ~3,600-4,400 cycles per switch, but Model A never preempts kernel code and `QUANTUM_TICKS` is 4, so forced switches cap at **15/s** -- under 1%. |
| B13.5 allocator | **DEAD as a lever** | Three Kmalloc calls per spawn against a 440 ms fork. |

**On the unconditional `_KcDp_Save`** (`sched.s:297`), which the PC sampler
pointed at: it IS justified.  The idle arm enters kernel C between the save and
the restore, so making the save conditional on the pick changing task would let
`ttdrain` clobber the outgoing task's live band whenever it was suspended inside
C -- which the shell always is, since `ttread` sleeps there.  ~70% of a switch is
that register-file copy, but at 15 switches/s it is not worth the risk.  This is
the clearest example in the dive of the phase-locked sampler pointing at
something real and unimportant.

## 8.2 Two taxes that ARE worth fixing

### printf routes every `%d` through 32-bit division

`printf.c:94-108, 236-246`: **every `%d`, not just `%ld`**, goes through
`__lc_pf_udec(unsigned long)`, which does `v % 10` and `v / 10` per digit.  With
`_fcc_long_modu` at ~4,800 cycles and `_fcc_long_divu` at ~2,900, that is
**~7,700 cycles per digit** -- ~23-38k per number, 3-5 ms at 7 MHz.  `ls -l` on
30 entries prints ~100 numbers: **0.3-0.5 s of pure division.**

A 16-bit path when the value is not long, or a powers-of-ten subtract table
with no divide at all, is a 5-20x improvement on that path.

### `_fcc_long_mods/modu` throw away a remainder they already have

The 32-bit divide loop holds the remainder in `_fcc_long_div_rem_lo/hi`
(`fcc_runtime.s:868-885`), and the modulo helpers discard it and recompute
`dvd - q*dvr`.  Returning it takes `long %` from ~4,800 to ~2,900 cycles.  One
file, additive, and the 16-bit `_fcc_mods16` already does it correctly and is
the template.

## 8.3 The developer loop (B14)

Measured on this tree: **a no-op `ninja` takes 42.7 s**, and touching a kernel
source and rebuilding also takes 42.7 s.  The disk-image steps dominate and are
not being skipped when nothing changed.

### The harness's state restore works, and has since injection landed (apple/fgx#374)

MAME state save/restore is implemented (`run.py --boot-state`) and disabled by a
comment saying the natural keyboard does not deliver characters after a restore,
"**until we inject keystrokes via a different path (writing to the ADB GLU or to
the kernel's keyboard ring directly)**".

That path exists now -- `FGX_MAME_PRIMARY=inject` writes through
`_kKbdInjectRaw` (`toolbox.s:483-515`).  **Tested, and it works:**

| | wall clock |
|---|---|
| `use_state: true` + `FGX_MAME_PRIMARY=inject` | **1.31 s** |
| normal cold boot, same command | **3.34 s** |

Both pass while asserting `STATEOK` on screen, so the command really is
delivered after the restore.  **2.03 s per test, a 2.5x speedup**, roughly
constant per test since it is the boot portion.

Not flipped on by default: the staleness invalidation names `disk/fgx.po` and
needs checking against the UFS image, `use_state` does not imply the injection
path today, and any test asserting on boot output cannot use it.

---

# PART 7 -- THE OPTIONS, RANKED

Ranked by measured value per unit of risk.  "Benchmark" is what was actually
measured; where a row says UNMEASURED it says so.

## Do these

### 7.1 Buffer libc's character output -- apple/fgx#373

| | |
|---|---|
| **Benchmark** | **10.57 ms per output character** to a file, 4.50 ms to the console.  Byte-at-a-time output runs at ~95 B/s. |
| **Pros** | ~1000x fewer syscalls.  No kernel change.  **54 files** use `putchar`/`fputc`.  It restores BSD's own stdio behaviour, which FGX currently diverges from; `fputs` in the same file already does the right thing.  Half the machinery exists (`_LC_BUFSZ`, `_lc_buf[]`) and is read-only today. |
| **Cons** | Flush discipline must be right (newline for a tty, full for a file, `fflush`/`exit`), and `_LC_BUFSZ` should go 512 -> 1024 to match a UFS block in the same change. |
| **Blocked by** | Nothing |

### 7.2 A boot-class libc pile -- apple/fgx#368

| | |
|---|---|
| **Benchmark** | 442,017 pile bytes read at boot; **5.2-6.0 s** of a 26.8 s boot |
| **Pros** | No kernel change.  The loader mechanism already exists and is correct; only the piles are wrong.  Costs no functionality.  The boot-set union is 55,508 B against a 65,536 B bank -- **10,028 B of headroom**. |
| **Cons** | Needs a pile-class build step, and init must link the same class or it pins the slot against everyone.  A single-slot registry means exactly one class can share. |
| **Blocked by** | Nothing |

### 7.3 Bound fork's bank copies -- apple/fgx#372

| | |
|---|---|
| **Benchmark** | fork is **440 ms of the 781 ms** cost of `true`; four full-bank MVNs are 262 ms of it |
| **Pros** | ~130 ms from bounding the soft-frame bank by `_fcc_sfp`, ~37 ms from turning the stack/DP byte loops into MVN, ~30 ms from bounding the stack copy.  All local. |
| **Cons** | Descriptor format changes (pair stride 2 -> 4).  The restore must read the parent's sfp from the descriptor, not the live DP. |
| **Blocked by** | Pair 0 (the data bank) is blocked on apple/fgx#361 and must not be attempted before it closes |

### 7.4 printf's 32-bit division, and the discarded remainder

| | |
|---|---|
| **Benchmark** | ~7,700 cycles per decimal digit; `ls -l` on 30 entries is **0.3-0.5 s of pure division** |
| **Pros** | Two small, additive toolchain changes.  `printf` routes **every `%d`**, not just `%ld`, through a 32-bit `%` and `/` per digit; a 16-bit path or a powers-of-ten subtract table is 5-20x.  Separately `_fcc_long_mods/modu` discard the remainder the divide already computed (~4,800 -> ~2,900 cycles), and the 16-bit `_fcc_mods16` is the template. |
| **Cons** | Toolchain changes, so full goldens plus the sweep and the gate. |
| **Blocked by** | Nothing |

### 7.5 Inline fcc's loop safepoint -- apple/fgx#371

| | |
|---|---|
| **Benchmark** | 20 cycles per loop iteration, of which **12 are JSR/RTS doing no work** |
| **Pros** | ~10% on compute-bound code for a 100-cycle loop body.  Applies to every loop in every program.  +6 bytes per loop site. |
| **Cons** | A toolchain change.  The win scales inversely with loop body size and is UNMEASURED end to end. |
| **Blocked by** | Nothing, but do it after 7.1-7.3 so the profile is not moving underneath it |

## Consider, with the measurement named

### 7.6 `bdwrite`, but only after 7.1

`ufs_write` bwrites every buffer it fills before returning
(`ufs_vnops.c:663`), and `ufs_inode.c:725` names the condition for changing
that: "import bdwrite when a measurement says the inode write-back is what
costs, not before."  The 10.57 ms one-byte write IS that measurement.

**But fix 7.1 first and re-measure.**  With buffered output the write pattern
becomes whole blocks, and a synchronous whole-block write may be entirely
acceptable.  Importing `bdwrite` changes durability semantics and deserves its
own measurement rather than inheriting this one.

### 7.7 An indexed blkcache lookup

The tree itself names this: the cache is scan-bound, not capacity-bound, and
"the next real lever is an INDEXED lookup, not more slots" (`include/fs.s:525`).
`_BlkCache_Lookup` is a linear walk of 24 slots, ~1,080 cycles on a full miss.
**Benefit UNMEASURED** -- and note that at ~0.15 ms per miss it is small against
a 781 ms command, so measure before building.

### 7.8 Partition zero-initialised data into bss

**397,925 bytes (6.75% of userland)** sit in zero runs of 32 bytes or more --
sed alone carries a single 30,942-byte zero run, 28.8% of its file.  Every link
generator hardcodes `"bss": 0`.  Eliminating it needs the linker to sort
zero-init data to the end of the DATA segment and declare the tail.  At ~70 KB/s
that is ~5.7 s of reads across a full `/bin` traversal, but only ~0.5 s on the
boot path.

### 7.9 An 80-column text console

The only way below the SHR framebuffer's **32 ms hardware floor**: a text page
is 1,920 bytes against 32,000, so ~2 ms, about **16x**.  But the console is
**~1% of boot**, so this is an interactive-throughput change, not a boot one.
VidHD's extended modes cannot be regression-tested at all, because MAME's
`apple2gs` does not emulate VidHD.

## Do not

| option | why it is dead |
|---|---|
| Raise `NBUF` | Already measured as a REGRESSION in the tree; the cache is scan-bound.  The survey also conflated two different caches. |
| One universal libc pile | The union is **>= 76,190 B against a 65,536 B bank**.  apple/fgx#37's option 1 has expired. |
| PackBytes for binaries | A scanline RLE.  **93-96%** on real binaries where zlib reaches 24-27%. |
| Toolbox routines for speed | ~400 cycles of dispatch, and the Toolbox is not reentrant -- it stays kernel-only, so a userland call costs a syscall crossing on top. |
| Bound fork's data bank by DATA size | The sbrk heap is the tail of that bank.  Silent corruption. |
| Optimise the SHR renderer further | Already ~80% of a hardware floor it cannot cross. |
| PATH search | 20 ms per exec, 2.6% of a `true`. |
| Declare BSS in binaries as-is | Only 882 bytes across 83 binaries are trailing zeros. |

---

# PART 8 -- THE REGISTRY WAS FULL, AND CONSOLIDATION IS NOT THE FIRST LEVER

Part 7 named pile-class consolidation as the next increment, on the reasoning
that sharing's ceiling is the repeat rate.  That reasoning was right about the
ceiling and wrong about what sets it.  Measured 2026-09-09 at `007c38717`.

## 8.1 Four slots, four permanent holders

Dump `_libcShTab` after a boot plus six execs (`memory_regions`, 32 B):

    slot 0  $45  ref 1  len 52175   init
    slot 1  $49  ref 2  len 26387   sh
    slot 2  $4E  ref 1  len 50704   inetd
    slot 3  $50  ref 2  len 45012   getty

**Every slot carries a live refcount.**  init, inetd and both gettys never
exit; the console `sh` outlives every command run from it.  So the table is
full and pinned from the moment the machine is up, the free-slot scan finds
nothing, the eviction scan finds nothing, and every tool a user runs takes the
table-full arm and loads its pile **privately, every time**.

That is the whole explanation for why !293's cache bought 2.00 s of boot and
nothing after it: the cache could only work in the window before the four
long-lived holders arrived.

## 8.2 The slot sweep

Two workloads, pasted in one go (`post_gap_frames: 0`) so the whole command
list lands in the keyboard ring at once and no typing schedule is in the
number.  A/B against the same tree; the emulator is deterministic, and 8/12/16
returning byte-identical frame counts on the first workload is that being
re-confirmed.

| slots | 15 execs / 8 classes | 33 execs / 13 classes | banks | registered |
|---|---|---|---|---|
| 4  | 1165 fr, 19.42 s | 2869 fr, 47.82 s | 19/56 | 4 |
| 6  | 961 fr, 16.02 s  | -- | 23/56 | 6 |
| 8  | **745 fr, 12.42 s** (-36.1%) | 2713 fr, 45.22 s | 25/56 | 8 |
| 12 | 745 fr | 2233 fr, 37.22 s | 27/56 | 12 |
| 16 | 745 fr | **2101 fr, 35.02 s** (-26.8%) | 28/56 | 13 |
| 20 | -- | 2101 fr | 28/56 | 13 |

Each workload flattens at its own distinct-class count.  The wide one needs
twelve before it does, because four slots are pinned before it starts -- which
is why eight looked nearly worthless there while being the whole win on the
narrow one.  **Sixteen** is the first size that saturates both, with three
slots spare.

Cost: 96 bytes of kernel globals (they end at `$02FA82` against the `$02FE00`
ERR), and a cached slot parks a bank no task maps.  Worst case measured -- fill
the table, then run the fork tool that wants whole banks -- 13 registered, 8 of
them cached, 30 of 56 banks allocated, `BIGFORK OK`.

**A cached pile cannot starve the allocator today**, so the reclaim path this
seemed to need is not needed: `Bank_Alloc` escalates to a Memory Manager claim
(`_MM_ClaimBanksToRow`) before it answers ENOMEM, and the ENOMEM arm past that
is only reachable from a masked-IRQ context or a full block table.  2.11BSD
does have the counterpart if it is ever wanted -- `malloc()` in
`usr/sys/sys/subr_rmap.c` retries once on the coremap after `xuncore(size)`
(`usr/sys/sys/vm_text.c`) frees the core of every text image whose `x_ccount`
is zero.  That is this refcount and this bitmap, so the shape would port
directly.  It was written, could not be shown to run, and was dropped.

## 8.3 What consolidation would actually cost

The static picture, from the shipped binaries' `LIBC` segment bytes:

* **149 staged FGX binaries, 63 distinct pile classes.**
* **6,353,750 pile bytes on the root, 46.7% of the staged tree.**  Nearly half
  the filesystem is near-identical copies of libc.
* The largest class already covers 53 binaries at 41,351 B; 61 of 157 built
  binaries select exactly the same twelve members.

Growing one class greedily from those twelve, adding at each step the member
closure that covers the most further binaries per byte, and **assembling every
candidate** to measure it rather than modelling it:

| members | class size | binaries covered | disk delta |
|---|---|---|---|
| 12 | 41,351 | 61 | 0 |
| 15 | 44,632 | 87 | +457,610 |
| 21 | 50,019 | 110 | -- |
| 27 | 55,718 | 122 | +1,731,694 |
| 35 | 65,011 | 134 | +2,966,993 |

The curve stops at 35 members: the next one overflows the 65,536 B bank.

Two things Part 7 got wrong, both by assembling the candidate instead of
estimating it:

* **The boot-set union does not fit.**  `init sh inetd getty login cat modload
  echo dhclient` closes to 35 members and overflows.  Part 7's "62,308-65,054,
  it fits but only just" was measuring a smaller set.
* **`init + sh + inetd + getty` alone is 64,823 B** -- it fits, by 713 bytes.
  That is the same trap the pile has already been in once: the resolver was
  taken out of `seg2.link.s.in` precisely because 35 bytes of headroom meant no
  libc function could ever be added again.

So consolidation costs **1.9-3.0 MB of disk** to pad tools up to a shared
class, on a root with 17,204 free blocks.  Raising the slot count costs 96
bytes and buys 26.8% on the wider workload.  **Capacity, not demand, was the
binding constraint**, and capacity is nearly free.

## 8.4 The measurement that makes this repeatable

`fgx_ar select` seeds its walk from `scan_refs` over ALL its `--root` files, so
handing it several tools' `.s` yields exactly their union closure -- no new
build machinery is needed to price a candidate class.  Assembling one takes
0.4 s: filter `libc_c.c`'s `#include` lines to the member set, compile with the
archive's own `cc`, and run `seg1 -> seg1_layout.s -> seg2` in a scratch dir at
`tools/<x>-fgx2` depth so the link files' `../../toolchain` PUTs resolve.

Positive control both ways: cat's twelve members reproduce its shipped `seg2`
**byte for byte** at 41,351 B, and true's four reproduce 11,783 B.

## 8.5 Where the remaining pile cost lives

With the class resident the pile read is an `lseek` and the cost is gone, so
what is left is the **duplication on disk**: 63 copies of a thing that the
loader is already content-addressing, 46.7% of the root, and consolidation
makes it worse rather than better.  The design that removes it is the one BSD
reached -- the shared object lives in ONE file and the binary names it -- which
means a segment that carries a reference instead of bytes, a loader that opens
it on a miss, and a linker and build that agree.  That is a campaign, not an
increment, and the numbers above are the case for it.

---

# PART 9 -- FORK, ONCE THE PILE READS WERE GONE

Removing the pile reads moved the profile, so the ranking was retaken against
it rather than inherited.  Same workload, same sampler, `pc_sample` over
thirty-three execs:

| | before Part 8 | after 16 slots | after the fork work |
|---|---|---|---|
| idle (post-WAI SEI) | 47.8% | 7.0% | 7.0% |
| `_fcb_mvn` (fork's bank copy) | 10.2% | 25.5% | **15.4%** |
| bank 0 (SmartPort, trampoline) | 12.4% | 19.7% | 23.7% |
| the tools' own code | 8.3% | ~23% | 29.5% |

The machine stopped being disk-bound.  Idle was the biggest number in the
original profile and is now 7%, which is the whole of what a resident pile
buys, and fork's whole-bank MVN went from a tenth of the profile to a quarter
-- not because it got slower, but because everything in front of it went away.

## 9.1 What landed, and what it measured

apple/fgx#372 named three unblocked items.  Two are done, and the third has
collapsed:

**Item 2, the byte loops.**  Snapshot and restore moved the parent's stack
pages and DP page a byte at a time, toggling MX around every byte -- about 37
cycles each against MVN's seven.  `_Fork_CopyRange` is `_Fork_CopyBank`'s
general form and both banks are known at those sites.

    fifteen execs   745 -> 709 frames    -0.60 s     40 ms/fork
    thirty-three   2101 -> 2017 frames   -1.40 s     42 ms/fork

against the 37 ms predicted.

**Item 1, the soft-frame bank.**  A fork/exit cycle carried four full-bank
MVNs; two of them were pair 1, the soft-frame bank sh asks for.  That bank
grows DOWN from `$FFFE` and a guarded prologue lowers `_fcc_sfp` BEFORE writing
through it, so the live extent is exactly `[sfp, $FFFF]` -- about 130 bytes for
a shell sitting in fork, against 65,536.  A pair now carries that floor
(stride 2 -> 4) and the restore reads it from the descriptor, never from the
live DP, which by then holds the child's.

    fifteen execs   709 -> 589 frames    -2.00 s    133 ms/fork
    thirty-three   2017 -> 1753 frames   -4.40 s    133 ms/fork

against the 130 ms predicted.

**Item 3, bounding the stack copy, is no longer worth doing.**  Its ~30 ms was
measured against the byte loops.  With item 2 in, sh's 3,840 stack bytes cost
about 7 ms across both directions, and the bound would need the user SP to be
trustworthy at snapshot time.  Not worth the interface.

## 9.2 The control that did not exist

softfork's own description says it cannot see pair 1: the child inherits
`_fcc_sfp` at the fork point and its frames grow DOWNWARD into unused space, so
the overlap never arises, and disabling pair 1's copy leaves it green.  It also
names what a real control needs -- a child that moves sfp back UP over the
parent's frames, via a longjmp to an outer setjmp.

`softjmp` is that, and both halves are measured: with pair 1 disabled it fails
on SJBAD while softfork stays green.

**Two mutations were wrong before one was right**, which is the part worth
recording:

* The first `softjmp` put only `chain` in its soft-frame list, copied from
  softfork's.  `scribble` recurses too, so the child scribbled the HARDWARE
  stack and the probe passed under the mutation -- a control that proved
  nothing.  The list is the generator's output now, not a copy.
* Raising the floor by 512 bytes to test the bound also passed.  On a shell
  whose live extent is ~130 bytes that start WRAPS past `$FFFF`, and `EOR
  #$FFFF` then yields a count that copies nearly the whole bank -- more than
  the correct code, not less.  At 48 bytes it goes red.

## 9.3 Cumulative

From the tree at `007c38717` to this branch, same two workloads:

    fifteen execs over eight classes     1165 -> 589 frames    -49.4%
    thirty-three execs over thirteen     2869 -> 1753 frames   -38.9%

## 9.4 What is left, by the current profile

* **`_fcb_mvn` is still 15.4%** and it is now entirely pair 0, the data bank.
  Bounding it is blocked on apple/fgx#361: the sbrk heap is the tail of that
  bank, the break is not a safe bound while 2.11BSD's sh writes above it, and
  FGX has no write fault to grow on.
* **Bank 0 is 23.7%**, which is the SmartPort read path -- now the binaries'
  own code and data segments, since the piles are skipped.  7.8 (zero-init data
  into bss) is the lever that shrinks those, at ~0.5 s on the boot path.
* **The tools' own code is 29.5%**, which is where 7.4 (printf's 32-bit divide
  per digit) and 7.5 (the loop safepoint's 12 wasted cycles) live.  Both are
  toolchain changes and neither has been measured end to end.

---

# PART 10 -- 7.4 DONE, 7.7 DEAD, 7.6 ANSWERED STRUCTURALLY

## 10.1 7.4 -- printf's division, both halves

**`_fcc_long_modu` was doing the work twice.**  It ran `_fcc_long_divu`, threw
away the remainder the restoring loop had just produced, and recovered it with
a 32-bit multiply and a 32-bit subtract -- computing the left side of K&R
A.7.6's own identity to get back a value it already had.  2nd ed p.166: "it is
always true that `(a/b)*b + a%b` is equal to `a`."  `_fcc_mods16` has always
done it the short way.  The divisor-zero check moved up, because `divu`'s zero
arm returns BEFORE the loop and would leave the remainder cells holding the
previous operation's value; A.7.6 makes that result undefined either way, but
answering the dividend is what callers had been getting.

**Every `%d` divided in 32 bits whatever it held.**  `__lc_pf_udec` takes an
`unsigned long`, so an ordinary int spent all of its digits in a 32-iteration
loop.  The high digits now peel in 32-bit only while the value still needs 32
bits; below 65536 the rest run at sixteen iterations.  Octal and hex needed
nothing -- they were already shifts and masks.

Measured on four `ls -l` and two `od -c` (~184 directory entries):

    baseline                3157 frames  52.62 s
    + the runtime fix       3097         51.62 s   -1.00 s
    + the 16-bit peel       3001         50.02 s   -1.60 s
                                                   -2.60 s total, -4.9%

which agrees with the 0.3-0.5 s per 30 entries this dive measured for pure
division.

`M22/pf_long` gains 65535 and 65536.  `v > 65535L` is a branch whose two sides
run different divide routines, and the fixture's existing values all cross that
seam mid-number rather than landing on it.  Measured discriminating: with the
condition mutated to `v > 65536L` the runtime oracle reports `pf_long
expected=42 got=1` -- the cast truncates 65536 to 0 on the 16-bit path.  The
asm goldens alone would have said only that the output moved.

## 10.2 7.7 -- an indexed blkcache lookup is dead

`_BlkCache_Lookup` is a linear walk of 24 slots and the tree names an indexed
lookup as "the next real lever" (`include/fs.s:525`).  Sampled over a workload
built to hammer the block layer -- writes, read-backs and a directory walk,
every command redirected to a file:

    67.4%  user banks (the tools' own code)
    20.6%  kernel
    11.1%  bank 0 (SmartPort)
     0.9%  ROM

**`_BlkCache_Lookup` does not appear at all.**  The largest kernel item is
`_fcb_mvn` at 5.2%; nothing in the block-cache path clears 0.1%.  The lever is
not there.

**The first attempt at this measurement measured the console.**  With `wc`,
`ls` and `od` printing to the screen, 14.7% of the run was one instruction --
`MVN $01,$01` at `7D:BC82`, the SHR framebuffer scroll.  An I/O measurement
whose output is not redirected is a console measurement.

## 10.3 7.6 -- buffering removed the repetition bdwrite existed to collapse

`ufs_inode.c:725` sets the condition: "import bdwrite when a measurement says
the inode write-back is what costs, not before."  The measurement that met it
was the 10.57 ms one-byte write, and that measurement is gone.

The answer is structural rather than statistical.  `bdwrite`'s specific win is
collapsing REPEATED writes to the same block, and the repetition was one inode
update per `write(2)`.  Buffered stdio made that one `write(2)` per 1024 bytes:
a 662-byte file is now a single call -- one data block, one inode update, with
nothing repeated left to collapse.  The factor is 1024, and it is already
banked.

For scale, all disk transfer (reads AND writes) in two write-heavy workloads:

    six `cat > /root/o1'          361 frames, bank 0 = 18.8% = 1.12 s
    the mixed I/O workload       1117 frames, bank 0 = 15.1% = 2.81 s

`bdwrite` addresses only the redundant fraction of the write half of that, and
would buy it by changing durability semantics.  **Recommend: do not import it.**

A clean read/write split of those figures is BLOCKED on apple/fgx#377: the
natural control is redirecting to `/dev/null`, and that hangs.  The first
attempt at the control ran to its frame cap and was briefly read as a slow run
rather than a hung one -- 2,566 bank-0 samples accumulated over 300 s of mostly
idle time, which looked like a comparable measurement and was not.

---

# PART 11 -- 7.5 LANDED, AND THE ESTIMATE WAS FIVE TIMES TOO HIGH

## 11.1 What changed

fcc hoists the safepoint's mirror test to the emission site and keeps the call
only on the taken arm.  Twenty cycles per loop iteration become eight; twelve of
the original twenty were the `JSR`/`RTS` doing no work.  `_fcc_safepoint` is
unchanged and still correct for a direct call.

The branch target is `*+5` rather than a label.  `BEQ` is two bytes and `JSR` is
three, so the displacement is a constant 3 that cannot go out of range, and it
is the idiom `IR_BCOND`'s far form already uses.  A label would have consumed a
`new_label()` number and renumbered every `_L<n>` in the translation unit,
rewriting every golden for no gain.

## 11.2 The measurement, which is the point

apple/fgx#371 projected **~10%** on compute-bound code, from a 100-cycle loop
body.  Real bodies are much larger, so the delivered win is smaller and depends
entirely on the body:

    cmp of two 106 KB files, 1/4/8 reps   457/1801/3589 -> 445/1765/3517   -2.0%
    fractal --sum2 (32-bit Mandelbrot)    9961 -> 9949                     -0.1%
    strings, wc, ls -l (I/O bound)        unchanged
    fractal --sumasm2 (hand asm, control) 541 -> 541                       unchanged

**THE SAVING SCALES WITH THE WORK** -- 12, 36 and 72 frames for 1, 4 and 8
repetitions -- and that scaling is the whole of the evidence that this is a
per-iteration saving rather than a fixed one.  The first two workloads measured
happened to differ by the same 12 frames, which looked like a fixed cost and
would have been recorded as one; only varying the repetition count separated
them.  A single before/after pair cannot tell those apart, and this campaign has
now been caught by that shape twice.

`fractal` is long-arithmetic throughout (638 `_fcc_long` calls), so its loop
body dwarfs twelve cycles.  That is why the compute-bound workload moves least,
which is the opposite of the intuition the issue was filed on.

## 11.3 The cost, measured on the path it would hurt

+6 bytes per loop site: **+0.63% to +0.92%** across sed, sh, ls, grep and
fractal.  Bank 0 is 23.7% of the profile and that is binary loading, so the exec
path was measured rather than assumed: `ls -l /bin` is unchanged.

## 11.4 What is left

* **7.8, zero-init data into bss**, is now the only untried lever the profile
  points at, and it is the bigger commitment: the linker must sort zero-init
  data to the tail of DATA and declare it, and every link generator hardcodes
  `"bss": 0`.  Size it first -- apple/fgx#377 is closed, so the `> /dev/null`
  control that Part 10.3 wanted is available again and a read/write split of the
  bank-0 share is measurable.
* **apple/fgx#372 pair 0** stays blocked on apple/fgx#361.
* The fbench cycle harness (`toolchain/bench/fbench.py snapshot`) is DEAD for
  the same reason as apple/fgx#342: it stages onto a ProDOS volume and every
  bench reports "no marker".  It was the natural instrument for this increment
  and could not be used; the numbers above come from MAME frame counts instead.

---

# PART 12 -- THE READ SIDE OF 7.1, AND IT IS THE BIGGEST LEVER YET

7.1 buffered libc's character OUTPUT.  The input half was never done, and it
was worth more.

## 12.1 How it was found, which was not by looking for it

Sizing 7.8 needed the cost per byte of reading, so `cat` of files from 4 B to
568 KB was timed.  The fit came out at **3.2 KB/s**, which is absurd for a
sequential read -- and `true` (19,896 B) execs in 157 frames, so the LOADER is
nowhere near that slow.  Two different read paths, two orders of magnitude
apart, and the slow one is the one userland uses.  That is apple/fgx#313, filed
six days earlier and not connected to the campaign.

## 12.2 The change

`stdio_core.c` buffered slots 3..7 and never 0/1/2, so a file reopened onto
stdin got a syscall per byte.  The test is now `isatty` rather than the slot
number, decided once per descriptor and retaken when the descriptor changes.

**Reading upstream is what shaped it.**  2.11BSD's `_filbuf` buffers ANY read
stream including stdin, keyed on the stream's `_IONBF` flag and not on the fd.
The exclusion was never a port of upstream.  What upstream relies on is that
`getpass(3)` opens `/dev/tty` and `setbuf`s that stream unbuffered -- FGX has no
controlling-terminal alias, so its `getpass` reads fd 0 raw, and an interactive
stdin genuinely must stay unbuffered.  `isatty` separates the two cases that the
slot number was conflating.

## 12.3 Measured

Isolating the read by subtracting a one-buffer `head -1` run from a whole-file
`grep`, so boot and spawn cancel:

    read of 49,152 B      6840 -> 852 frames    114.0 s -> 14.2 s   -87.5%
    grep over that file   7165 -> 1177 frames                       -83.6%
    head -1, one buffer    325 ->  325 frames   unchanged (control)

The `head` arm reads one bufferful either way, so a change there would have
meant the measurement was picking up something other than the read.

## 12.4 What this does to the remaining list

**7.8 is now much weaker than it looked and should be re-sized before anyone
starts it.**  It was ranked against a profile in which reading was ruinously
expensive per byte.  The zero-run statistic itself still holds and is larger
than Part 7 recorded -- **706,439 bytes, 7.20% of userland** across 155
binaries, fractal 35.6% and one 37,673-byte run -- but binary loading never went
through the slow path this fixes, and the exec-cost measurements could not
separate load time from per-tool work at 1/60 s quantisation.  The honest
position is that 7.8's benefit is UNMEASURED, not that it is large.

**apple/fgx#307 should be re-read too.**  It records a 48 KB sequential read
taking roughly four minutes on UFS; the same read is now 14.2 s, and its own
note that "this is the dominant term on BOTH filesystems" pointed here.

---

# PART 13 -- THE RE-PROFILE AFTER apple/fgx#313, AND A CORRECTED ATTRIBUTION

Five execs over a mixed load -- `ls -l /bin`, `wc /etc/services`,
`grep root /etc/passwd`, `od -c /etc/passwd`, `cmp /bin/sh /bin/sh`, all
redirected -- sampled with `pc_sample` under `FGX_MAME_PRIMARY=inject`,
1393 frames, 22,976 samples.

    the loaded modules (vfs/ufs/ufsdir)  34.7%
    the tools' own code                  29.6%
    kernel bank                          19.4%   idle 8.3%, _fcb_mvn 2.8%
    bank 0                               10.6%   the CARD's firmware, 10.5%
    far bank                              2.9%
    tty bank                              2.1%

## 13.1 THE FIRST VERSION OF THIS PART WAS WRONG, AND IT IS THE WARNING

It reported "the tools' own code 64.3%, FLAT, no hot spot left, the campaign
stops".  That number silently included the LOADED MODULES.  vfs, ufs and
ufsdir are relocated into allocated banks at load time, so their code appears
at bank numbers that no static list knows -- and anything bucketing "system
banks vs everything else" files them under userland.

`_modBankTab` is what resolves it: the kernel publishes ordinal -> bank, the
harness already scrapes it (`run.py`, `_MOD_SYMS`), and a `memory_regions`
entry brings it back with the profile.  Read that way the same samples say
something else entirely -- **the filesystem modules are the single largest
bucket at 34.7%**, and the tools' own code is 29.6%, not 64.3%.

**A profile is only as good as its bank attribution, and a bank that is
ALLOCATED AT RUNTIME cannot be attributed from a static table.**  Every earlier
profile in this document shares the flaw, Part 9.4's included: its "the tools'
own code is 29.5%" was measured the same way and carries the modules too.

## 13.2 What is actually hot, once the modules are attributed

Mapped through the module listings:

    vfs      17.6%    uiomove 4.2% + @uc_mvn 1.9%   the uio data copy, ~6%
                      ndslot 1.6%, lookup 0.9%, namei 0.4%
                      getblk 0.7%, brelse 0.7%      the VFS buffer cache
    ufsdir   13.7%    ufs_dirscan 4.0% + @ds_lp 2.1% + ufs_dirmatch 0.8%
                      + @ds_skip 0.4%               directory scanning, ~7.2%
                      spec_chwrite 1.2%
    ufs       3.3%

So there ARE hot spots, and they are the two the earlier attribution could not
see: **directory lookup at roughly 7.2%** and **the uio copy at roughly 6%**.

## 13.3 Two measurement traps, both caught before they became findings

**The first profile measured the harness typing.**  Idle came out at 37.7% and
one instruction -- `02/8EA5`, the `SEI` after `WAI` in `@sw_idle` -- was 37.7%
of the run on its own, which reads exactly like a lost wakeup.  It is not.  The
autoboot paste types at six frames per character, so a 151-character command
line spends ~900 of 2173 frames being typed while the shell sits blocked.
Re-running under injection drops the run to 1393 frames and idle to 8.3%.
**A profile whose command is typed by the harness is partly a typing
measurement**, the same shape as "an I/O measurement whose output is not
redirected is a console measurement".

**A long pasted command line is silently truncated.**  A 300-character line of
fifteen chained commands was cut mid-word; the run then reached its frame cap
and would have read as "the workload is slow".  The limit is `TTYHOG`, 255, and
it is 2.11BSD's own constant -- FGX ports the guard verbatim from
`tty_pty.c:432-440`, so this is conformant behaviour and not a defect.

## 13.4 What this does to the rest of the list

* **Bank 0 halved, 23.7% -> 10.6%**, and 10.5 of those points are the SmartPort
  card's own firmware in the `$C800-$CFFF` expansion-ROM window, on the
  "standard SmartPort - single-block read path" the boot banner names.  FGX can
  only reduce that by issuing fewer, larger requests.
* **`_fcb_mvn` fell 15.4% -> 2.8%**, so apple/fgx#372's remaining pair is worth
  at most that and unblocking apple/fgx#361 for it is not a trade worth making.
* **7.8 should not be started on Part 7's ranking.**  It was ranked when reading
  cost was ruinous per byte.  The zero-run statistic still holds and grew --
  706,439 bytes, 7.20% of userland across 155 binaries -- but its BENEFIT is
  unmeasured.
* **7.7 is dead as literally stated but the question underneath it is not.**
  `_BlkCache_Lookup` really is absent: it is the LEGACY cache, and the VFS path
  uses `getblk`/`brelse` instead, which is the pair Part 7 warned the survey had
  conflated.  Those are 1.4% here, so the indexed-lookup idea stays dead -- on
  evidence this time rather than on a profile that could not see the module.


# PART 14 -- apple/fgx#380, THE NAME CACHE, MEASURED AT -5.4%

The cache was ported at UFS 1.6a and had no caller until now.  It is wired into
`ufs_lookup` and it lives in `ufsdir.mod`.

## 14.1 THE MEASUREMENT, AND WHY IT IS AN A/B RATHER THAN A BEFORE/AFTER

`doingcache` is Reno's tunable and this tree kept it, for the reason
`vfs_cache.c` gives at the declaration: "a machine that is behaving strangely
can have the cache turned off without a rebuild, and the two behaviours are
then directly comparable."  That is exactly the experiment -- one source line,
so the two builds differ in the cache and in nothing else: same bank layout,
same module sizes, same code addresses.  A before/after against `main` would
have moved all three.

Five execs over the Part 13 workload -- `ls -l /bin`, `wc /etc/services`,
`grep root /etc/passwd`, `od -c /etc/passwd`, `cmp /bin/sh /bin/sh`, all
redirected -- under `FGX_MAME_PRIMARY=inject`.

    doingcache = 0      paste+1321 frames      no lookups counted
    doingcache = 1      paste+1249 frames      412 lookups, 279 hits

    -72 frames, -5.4%

Three runs of each; every one identical to the frame.  The estimate this was
taken on was 3.8%, from a stand-in cache measured at a 52.9% hit rate.  The
real one is better: **67.7%** (278 good hits and one negative, of 412), at
`NNAMECACHE` 32 rather than the stand-in's 64.

## 14.2 THE COUNTERS ARE THE POSITIVE CONTROL, AND THEY EARNED IT

`nchstats` is read straight out of ufsdir.mod's bank at the end of the run --
a `memory_regions` entry with `"modbank": 4`, because the bank is allocated at
load time and only `_modBankTab` knows it.

That check caught a wrong measurement in this very session.  The A/B was run by
`sed -i.bak` on `doingcache` and then `mv`-ing the `.bak` back; `mv` restores
the file's ORIGINAL mtime, which was older than the generated `.s`, so ninja
skipped the rebuild and the "cache on" runs were still the cache-off image.
They reported 1321 frames and would have read as "the cache does nothing".
`nchstats` came back all zero, which is impossible with the cache on, and that
is the only reason it was caught.

**A performance A/B needs a positive control that the arm under test is
actually the arm that ran.**  Frame counts alone cannot tell a build that did
not rebuild from a change that did not help.

`ncs_falsehits` is 2, which is worth recording: the capability check fires on
this workload, so `v_id` minting is live across the bank seam.  A build where
it is always zero is one where `getnewvnode` is not reaching `cache_purge`.

## 14.3 THE HASH WAS WRONG, AND ONLY WIRING IT COULD HAVE SHOWN THAT

`namei` built `ni_hash` as a plain sum of the component's bytes.  Reno weights
each by its 1-based position (`kern/vfs_lookup.c:180`, `ndp->ni_hash +=
(unsigned char)*cp * i;`).  Unweighted, every anagram hashes alike and lands in
one of the sixteen buckets together.

It is not a correctness bug and no functional test could have seen it -- which
`namei.h` had already written down, in the paragraph on `ncs_falsehits`: a
cache that is merely present answers correctly and slowly.  `ni_hash` is read
by `nchbucket` and by nothing else, so for as long as the cache had no caller
the field was write-only.  Fixed with the wiring, citing upstream.

## 14.4 WHERE IT LIVES, AND THE ONE CROSSING THAT BUYS THE REST

`vfs.mod` had **94 bytes** free, so the cache could not stay there and be wired:
`cache_lookup` and `cache_enter` are 2,398 bytes that had never shipped at all.

It went to `ufsdir.mod` whole, on the rule that moved `spec_vnops.c` there --
`ufs_lookup.c` is its only hot-path caller and reads its state on every call,
and module C reaches globals DBR-relatively, so the halves cannot be split.
`vfs.mod` came back to 3,532 bytes free.

What crosses now is the RARE direction: `getnewvnode` mints a capability number
through `cache_purge`, and `vfs_dounmount` drops a filesystem's entries through
`cache_purgevfs`.  Both travel as a `struct cacheops` of `&function` cells that
`ufs_dirinit` hands over, the way `vfs_setspecops` already worked.  That is one
pile call per vnode HANDOUT -- not per lookup -- against every crossing in the
system measured together at 0.69% (apple/fgx#381), and it buys 5.4%.

`vfs_cache_lookup.c` is gone as a file.  It was split out on 2026-09-06 only
because `_VFS_C` had to carry one half and not the other; both halves are in
one module again, and Reno keeps all five entries in one `kern/vfs_cache.c`.

## 14.5 THE RECIPE, since the manifest is not committed

The `nchstats` region bakes an offset into ufsdir's bank, and
`gen_modplace` moves those whenever a module grows -- a committed manifest
would compare the wrong bytes and still pass, which is the trap
`tools/mame_test/tests/modimage.json` exists to avoid.  Re-derive it:

    grep -m1 'STA *nchstats+0' build/module_ufsdir_Output.txt

and read the operand of the `8D lo hi` it prints.  Then a manifest with
`{"name": "nchstats", "modbank": 4, "addr_hex": "00<hi><lo>", "len": 32}`
and the five-exec command line above; decode as eight little-endian 32-bit
counters in `struct nchstats` order.


# PART 15 -- THE PROFILE AFTER THE NAME CACHE, AND apple/fgx#382 CLOSED OUT

Same workload as Parts 13 and 14, same sampler, `FGX_MAME_PRIMARY=inject`,
1,249 workload frames, 20,597 samples.  `_modBankTab` came back with it, so the
runtime-allocated module banks are attributed rather than guessed.

    kernel bank $7C                      19.3%   SEI (post-WAI idle) 8.5%,
                                                 _fcb_mvn 3.2%
    the tools' own code ($5B/$5D/$5E/    32.6%
                         $4E/$47)
    the filesystem modules               29.4%   vfs 15.1, ufsdir 9.4, ufs 4.9
    bank 0                               12.2%   12.1 of it the CARD's own
                                                 expansion ROM, which FGX
                                                 does not own
    far + tty banks                       5.4%

## 15.1 Inside the modules, by SOURCE FILE

Attributing by the listing's source column rather than by label: a label walk
lands on whatever `DS` cell precedes the code, which is how an earlier pass put
13% of the run in `_vfsPoolBank`.

    vfs.mod       fcc_rt 4.14   vfs_bio 3.40   vfs_subr 2.38   uio_copy 2.12
                  vfs_lookup 1.63   vfs_vnops 0.59   kern_subr 0.37
    ufsdir.mod    ufs_lookup 3.30   fcc_rt 3.21   ufs_vnops 1.63
                  vfs_cache 0.89
    ufs.mod       ufs_bmap 1.76   fcc_rt 1.35   ufs_sb 0.98   ufs_inode 0.37

**`fcc_rt.s` IS 8.70% OF THE RUN** once the three copies are added -- the
largest single attributable item in the profile, and a TOOLCHAIN target rather
than a kernel one.  Every module carries its own copy of the fcc runtime
because the helpers are reached DBR-relatively.

`vfs_cache.s` is 0.89%, which is what the name cache COSTS.  It buys 5.4%.

## 15.2 apple/fgx#381 re-measured: the uio copy is smaller than recorded

The issue records `uiomove` at 4.16%.  Split by file it is now **2.49%** --
`uio_copy.s` 2.12% (the hand-written copy) plus `kern_subr.s` 0.37%
(`uiomove`'s own C).  It did not get faster; the run got shorter, and the read
fix removed most of what used to call it per byte.

## 15.3 apple/fgx#382's four claims

**1. "PATH search is not a cost" -- RESTATED, not confirmed.**  Eight execs of
`arch` resolved on the first PATH entry against the fifth:

    PATH=/bin                     337 frames
    PATH=/n1:/n2:/n3:/n4:/bin     373 frames

36 frames for 32 failed lookups = **1.125 frames (~19 ms) each**, which agrees
with Part 3.2's ~20 ms.  What does not survive is the CONCLUSION: four extra
entries cost 4.5 frames per exec against a 42-frame exec, which is **10.7%**,
not 2.6%.  The claim is true per-lookup and false as a dismissal.

`nchstats` on that run shows **29 negative hits** of 32 failed lookups -- the
first exec's four are real misses and every repeat is answered from the cache,
which is exactly what `cache_lookup`'s header predicted it would do for a PATH
search.  So the residual 19 ms is syscall and namei overhead, not scanning.

**2. "The console is ~1% of boot" -- NOT REDONE, and it cannot be from a
workload profile.**  The PC sampler's window is the COMMAND (`run.py:1250`,
"while the command runs"), so no profile in this document has ever sampled
boot.  A `bootprof` run with a trivial command returned 776 samples over 49
post-paste frames -- 15.8 samples/frame against the workload profile's 16.5,
which is what proves the window rather than any comment.  Answering this needs
the sampler to start at reset.

**3. "Raising NBUF is a regression" -- WRONG, and the correction is that it is
INERT.**  `NBUF` 16 -> 32, positive control `VFS_ARENA_SIZE` 16384 -> 32768:

    mixed five-exec workload    1249 -> 1249 frames
    49 KB sequential read        985 ->  985 frames

Not one frame, either way.  "Do not raise NBUF" stands; the reason on record
was wrong.

**4. Part 9.4's profile** is superseded by 15.0 above.

## 15.4 OPTION 7.8 MEASURED AT LAST -- 1.95% general, 27% on sed

7.8 has been carried as "the only untried lever" with an UNMEASURED benefit.
It is measured now, by pricing the loader directly.

Two tools doing trivial work, at four and eight repetitions so the SLOPE
separates per-exec load cost from fixed overhead -- the shape this campaign has
twice been caught by:

    echo   42,323 B    4 reps 181 fr    8 reps 349 fr   ->  42.00 frames/exec
    sed   121,106 B    4 reps 457 fr    8 reps 913 fr   -> 114.00 frames/exec

72.00 frames per exec for 78,783 bytes = **1,094 bytes/frame, 65.7 KB/s**.
Both arms are exactly linear, and a single-pair estimate from the eight-rep arms
alone gives 1,117 B/frame -- 2% apart, which is the cross-check.

That 65.7 KB/s is independent confirmation of the ~70 KB/s Part 7 assumed, so
the arithmetic there survives the read fix even though its premise did not.

Zero runs >= 32 bytes, scanned per binary rather than taken as a corpus average:

    tool      bytes    zero>=32     %    longest    frames saved
    ls       95,275       7,583   8.0%     2,374        6.8
    wc       54,554       2,726   5.0%       895        2.4
    grep     65,581       5,390   8.2%     2,071        4.8
    od       69,973       6,200   8.9%     2,049        5.5
    cmp      56,895       4,801   8.4%     2,076        4.3
    sed     121,106      33,786  27.9%    30,942       30.9
    vi      326,788      32,470   9.9%     6,175       29.1
    tcsh    568,629      17,793   3.1%    14,248       15.9

**On the five-exec mixed workload: 24.4 frames of 1,249 = 1.95%.**
**On sed alone: 30.9 frames of its 114-frame exec = 27%.**

So 7.8 is worth about **2% generally and a quarter of an exec for the tools
with big data segments** -- sed, vi, tcsh.  Against that: it is a LINKER change,
sorting zero-init data to the end of the DATA segment and declaring a bss tail,
and every link generator in the tree hardcodes `"bss": 0`.  That is the decision
to take with a real number rather than a hope, which is all this section
claims to provide.
# PART 16 -- THE LARGEST ITEM IN THE PROFILE WAS THE COMPILER'S RUNTIME

Part 15 put `fcc_rt.s` at 8.70% of the run once its three module copies are
added -- the biggest single attributable item, and a toolchain target.  Broken
down by routine, through the listing's source-line column:

    _fcc_divs16   2.51        _fcc_mul16     0.54
    _fcc_long_mul 1.77        _fcc_gts16     0.48
    _fcc_lts16    1.00        _fcc_long_shl  0.38
    _fcc_long_shr 0.56        _fcc_ne16      0.31

Cross-checked by ADDRESS SPAN rather than trusting the line mapping: summing
the three banks' `_fcc_divs16` ranges gives 0.91 + 1.60 + 0.00 = 2.51%, which
is the same number the other way round.

## 16.1 One guard explained all of it

`parse_expr.c`'s multiplicative builder read

    int can_inline = (op == TOK_STAR) ||
                     ((op == TOK_SLASH || op == TOK_PERCENT) && lhs_u);

so `/2^k` inlined only for an UNSIGNED dividend.  The same conservatism runs
through the shift builder (`op == TOK_LSHIFT || lhs_u`) and through
`emit_shift_const_lower`, which emits LSR for every right shift and takes an
`is_unsigned` argument it discards -- safe only because the gate upstream never
lets a signed value reach it.

**The root cause is that fcc had no arithmetic-shift-right emitter**, so it
declined to inline anything signed that needed one: `>>`, `/2^k` and `%2^k`
alike.

## 16.2 The ceiling was measured before the compiler was touched

`ufs_lookup.c:257` is `blkend = (off / DIRBLKSIZ) * DIRBLKSIZ + DIRBLKSIZ;`
inside the directory scan, and `off` is a plain signed `int`.  Making it
`unsigned` fires the EXISTING path, so the win was priced without writing any
codegen:

    five-exec mixed workload   1249 -> 1237 frames    12 frames

Twelve frames is the number this campaign has twice mistaken for a fixed cost,
so it was scaled before being believed:

    2 x `ls -l /bin`   1045 -> 997     48 frames
    6 x `ls -l /bin`   3013 -> 2881   132 frames

48 at two and 132 at six is ~21 frames per directory scan -- per-scan, not
fixed.

## 16.3 What landed, and why it beats the probe

    five-exec mixed workload   1249 -> 1225 frames   -1.92%
    2 x `ls -l /bin`           1045 ->  997          -4.6%
    6 x `ls -l /bin`           3013 -> 2893          -4.0%

**The compiler change is worth twice the source probe on the mixed workload**
(24 frames against 12) because it reaches every signed `/2^k` in the tree
rather than the one site that prompted it.  On the directory-heavy arms it is
marginally behind the probe (2893 against 2881), which is the honest cost of
signed: `CMP #$8000 + ROR` per step against the probe's bare LSR.

## 16.4 K&R DID NOT DECIDE THIS, AND THAT IS THE FINDING

A.7.6 (p.166): "it is always true that `(a/b)*b + a%b` is equal to `a`.  If
both operands are non-negative, then the remainder is non-negative and smaller
than the divisor, if not, it is guaranteed only that the absolute value of the
remainder is smaller than the absolute value of the divisor."

A bare arithmetic shift FLOORS, and floor division satisfies both clauses --
so the standard permits it.  What it does not permit is DISAGREEING WITH
`_fcc_divs16`, which truncates toward zero: a compiler whose answer for
`x / 512` depends on whether 512 was written as a literal is worse than one
that rounds either way consistently.  The bias is there for internal
consistency, not for conformance, and reading the text is what established
that rather than assuming the stricter rule.

## 16.5 A correctness fix arrived with it

`N_MUL_CONST_LIBCALL` hardcoded `_fcc_divu16` and `_fcc_modu16`.  That was safe
only while the node was unreachable for a signed operand; opening the gate
makes a signed division by a NON-power-of-two constant reach it.  The helper is
chosen by signedness now.  `%` stays unsigned-only -- a signed remainder takes
its sign from the dividend, which is a second sequence with no measured caller.

## 16.6 The fixture is measured discriminating

`M37/divs_pow2` covers fifteen cases, and six of them are dividends where floor
and truncate differ (-1, -1025, -511, -513, -3, -1 at k=1).  Every expected
value matches truncation, so a compiler that dropped the bias cannot return 42
-- checked on the host against both roundings rather than assumed.  Verified on
the machine through the runtime oracle, not only against the `.s` golden: the
golden alone would have said only that the output moved.

## 16.7 What this leaves

`_fcc_divs16` is gone from the hot path.  The comparison helpers are next by
size -- `_fcc_lts16` 1.00, `_fcc_gts16` 0.48, `_fcc_ne16` 0.31, `_fcc_eq16`
0.25, **2.04% together** -- and a 16-bit compare is `CMP` plus a branch inline.
That is the same shape of change with none of the rounding subtlety, and it is
the obvious next one.
