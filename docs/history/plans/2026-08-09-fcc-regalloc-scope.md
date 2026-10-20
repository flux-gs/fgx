# Scoping the fcc register-allocation work

Written off the 0.1 gate's measurement
(`docs/history/audits/2026-08-09-kernel-c-01-gate/`), which found that 40% of
2.11BSD's `bmap` compiled by fcc is intermediates shuttled through the direct
page and the stack frame: 25.6% DP register-file traffic, 14.6% frame-slot
(`n,S`) access, against 4.2% for the 32-bit long helpers everyone assumes are
the problem.

## fcc already has an allocator, and bmap gets none of it

This is the thing to understand before proposing work. `ir_promote_locals()`
(`toolchain/src/cc/ir.c:755`) is a delivered linear-scan allocator over
`{A,X,Y}` plus a sixteen-slot direct-page register file `_fcc_img0..15`
(`$C0-$DF`). It measurably works -- it was worth -54% cycles on `strLen` and
-30% on `memcmp` when it landed.

`bmap` is disqualified by **two independent gates**, both of which are correct
as written:

**Gate 1 -- only 16-bit scalars are eligible.** `ir.c:788`:

```c
if (lc->type != LT_INT && lc->type != LT_CHAR) continue;
```

Every hot variable in `bmap` is `daddr_t`, which is `long`. `nb`, `bn`, `ra`,
the block numbers the whole routine exists to compute -- none can be promoted.
A filesystem is made of 32-bit block numbers and offsets, so this is not
peculiar to `bmap`: it disqualifies the FS layer more or less entirely.

**Gate 2 -- any call to a non-`_fcc_` target kills whole-function promotion.**
`ir.c:770-777` falls back to `ir_promote_loops()`, which promotes only
call-free loop regions. The reason is sound: `_fcc_img0..15` live at fixed DP
offsets, so a callee running on the same task direct page reuses them. `bmap`
calls `balloc`, `bread`, `brelse`, `bwrite`, `bdwrite`, and its loops contain
those calls, so even the loop fallback finds nothing to keep.

Both gates have to move for FS code to benefit. Either alone leaves the other
in force.

## Prior art: examples/65816-llvm-mos has solved this already

`llvm816`, the LLVM/Clang W65816 backend in `examples/65816-llvm-mos` (last
commit 2026-07-05), is an independent attack on the same problem on the same
chip, and it converges on fcc's design closely enough to be worth reading
before writing anything.

- **Same imaginary registers, same place.** `IMG0..IMG15` backed by DP
  `$C0-$CE` + `$D0-$DE`, giving "17 effective i16 carriers (A + 16 IMG) before
  stack spills kick in". fcc's `_fcc_img0..15` at `$C0-$DF` is the same idea at
  the same addresses, arrived at separately. That is good evidence the file is
  the right size and in the right place.
- **It register-allocates 32-bit values.** i8/i16/i32/i64 arithmetic with
  carry-chained multi-word ops. So item B below is not speculative -- it has
  been done on this instruction set.
- **A pre-RA pass does the widening**: `WidenAcc16` promotes Acc16 to Wide16
  "lets greedy spread i16 pressure across A and 16 IMG slots". Worth reading
  as a model for where in the pipeline the work belongs.
- **Measured wins, which calibrate the bar below.** Unblocking greedy regalloc
  was worth popcount -19.4%, strcpy -18.9%, memcmp -8.6%, bsearch -9.2%. So
  8-20% is the honest expectation for allocator work on this chip, which is
  the range the bar below guesses at.
- **`compare/` is a ready-made methodology**: it recompiles a benchmark set
  under both clang and Calypsi and prints an instruction-count ratio. FGX has
  no equivalent for fcc, and building one is cheaper than arguing about
  whether a change helped.
- **Their ABI passes arguments in registers** -- arg0 in A, arg1 in X for
  i32-first-arg signatures, rest pushed. fcc pushes everything. That is a
  different lever from A and B and it aims at the 14.6% frame-slot bucket
  directly; see D.

Caveat before borrowing: this is an LLVM backend with a full SSA pipeline and
a greedy allocator underneath it. fcc is a single-pass front end with a small
IR. The *conclusions* transfer -- what to allocate, where to put it, how much
to expect -- and the pass structure does not.

**Pulled to 4a13f9d (2026-07-26) while writing this.** Six commits since the
copy first read; the register-allocation section of their STATUS is unchanged,
so nothing above is stale and there is no newer allocator work to adopt. The
new material is libc, GNO and linker (`link816` now accepts library archives).

One backend change is worth reading anyway, because it is item A's pattern in
miniature. `W65816FrameLowering::determineCalleeSaves` gained a callee-side
save/restore of DP `$F4`, the VLA entry-SP cache, for exactly the reason A
exists: "$F4 is a single global DP location: a nested VLA callee overwrites it
in its own prologue and never restores it, so without a callee-side
save/restore the caller's $F4 is stale after the call". And it is paid only by
functions that use the location -- the same pay-only-if-used property proposed
for the img slots. A fixed DP cell shared by caller and callee, fixed by
callee-side save/restore rather than by a caller-side spill, is the shape both
projects arrive at.

## The work, in dependency order

### A. Callee-saved register slots -- do this first

Gate 2 is a calling-convention problem, and BSD answered it decades ago: the
PDP-11 C convention makes **r2-r5 callee-saved**, so a caller keeps values in
registers across a call and the callee spends the prologue/epilogue bytes only
if it actually uses them. 2.11BSD's compiler does exactly this, which is the
oracle this project defers to.

The fcc equivalent: nominate a subset of `_fcc_img*` as callee-saved. A
function that allocates one pushes and pulls it around its body; a leaf that
allocates none pays nothing.

- Unblocks whole-function promotion for every non-leaf, which is most of a
  filesystem.
- Cost is bounded and visible: 4 bytes of prologue/epilogue per saved slot
  (`PEI`/`PLA`+`STA`), paid once per function rather than per access.
- Interacts with `setjmp`/`longjmp` and with the kernel-C seam's reentrancy
  bar. Neither is a blocker -- kernel C is non-reentrant by rule and
  `jmp_buf` already saves what it needs -- but both need stating before code.
- **Risk: this changes the ABI.** Every hand-written asm routine that calls or
  is called by C has to agree. `check_far_rtl_calls.py` and the libc shims are
  the surfaces to audit.

### B. 32-bit promotion -- BUILT, and it does not do what this section hoped

Implemented and measured. Read the result before planning around the rest of
this document, because it invalidates the premise the whole scope was written
on.

**It works.** A long local or param now promotes to a contiguous img pair
{low, high}, reusing the pairing pointers already had. On a qualifying leaf,
`n,S` accesses fall from **17 to 1**. Goldens regenerated (26 moved, all of
them long-related), suite **559/0**, runtime oracle **540/542** with the two
failures (`sysops`, `ttyops`) confirmed PRE-EXISTING at `177d0cb9e`.

**Cycles: -29.0% on the long-heavy bench.** Measured under the real kernel
with fbench Option B (repaired to get this number -- see below), A/B against
the parent commit on the same disk:

| bench | baseline us/call | promoted | delta |
|---|---:|---:|---:|
| popcount | 1680.82 | 1193.69 | **-29.0%** |
| djb2Hash | 3629.84 | 3519.80 | -3.0% |
| dotProduct | 2406.65 | 2386.84 | -0.8% |
| sumOfSquares | 4587.94 | 4550.33 | -0.8% |
| bsearch, bubbleSort, fib, memcmp, strLen, strcpy, t12_* | | | 0.0% |

Nine of thirteen unchanged, and they are the int-only benches -- which is the
result to want: the change is targeted, not a global perturbation. popcount is
the one bench that keeps a `long` live across a loop.

**It is size-neutral.** The same leaf assembles to **174 bytes before and 174
after.** That is not a disappointing result, it is arithmetic: `LDA n,S` and
`LDA dp` are both two bytes. Moving a value from the stack frame to the direct
page changes the addressing mode, not the instruction width.

So the 25.6% + 14.6% this scope identified as "the real lever" on SIZE is
nothing of the kind. Those buckets are large in bytes, but the bytes are
already minimal-width; you cannot shrink a 2-byte load by giving it a
different 2-byte addressing mode. **Register allocation on this machine is a
CYCLES lever, not a SIZE lever** -- consistent with every number quoted for it
here, which were all cycle percentages (strLen -54%, memcmp -30%, llvm816's
-8.6% to -19.4%). The size reading was mine and it was wrong.

**And it does not fire on `bmap` at all.** `bmap.s` is **2480 bytes before and
2480 after**, because gate 2 still sends it to the loop-scoped fallback before
step 4b is ever reached. This document said as much -- "both gates have to
move, either alone leaves the other in force" -- and then recommended doing B
first anyway. The recommendation contradicted the analysis three paragraphs
above it.

What B is still worth: it is a real cycle improvement for long-heavy code, and
it is the half of the pair that has to exist before A can pay off on anything
in a filesystem. It is not a step toward fitting in a bank.

### B (as originally scoped) -- the one that pays on FS code

Gate 1, lifted by allocating a `long` to a **pair** of adjacent img slots.

- Sixteen slots is eight longs; `bmap` has three or four hot ones, so the file
  is deep enough.
- Mechanically the smaller change of the two: the allocator's tally, the
  eligibility test and the load/store lowering, with no ABI implication.
- Should also retire a chunk of the `_fcc_long_*` calls for free, since a long
  already in two DP slots does not need `_fcc_long_from_int` to materialise.

### D. Register-passed arguments -- the other half of the frame bucket

Not in the original scoping; `llvm816` prompted it. fcc pushes every argument;
llvm816 passes arg0 in A and arg1 in X. `bmap` takes four arguments and is
called from a dispatch layer, and 14.6% of its bytes are `n,S` frame access.

Independent of A and B, and probably cheaper than either, but it is an ABI
change with the same audit surface as A -- so if both are wanted they should
land together rather than churning the asm boundary twice.

### C. Re-measure against the same subject

`bmap.c` and `vnops.c` in the gate directory, rebuilt and re-bucketed with the
gate's own script. The number that decides whether this was worth doing is
`bmap.s` against today's **2480 bytes**.

Set the bar before starting, not after: **A and B together should take at
least 15% off `bmap`, and if they take less than 10% the work is not paying
for its complexity.** llvm816's own allocator work landed in the 8.6-19.4%
range on its benchmark set, so that bar is calibrated against a real result on
this chip rather than invented. Written down now so it can be wrong in public
rather than adjusted afterwards to match whatever came out.

Worth building at the same time: fcc has no benchmark harness. llvm816's
`compare/` recompiles a fixed set and prints a ratio, which is how they can
quote per-benchmark percentages at all. A few hundred lines of that for fcc
would outlast this piece of work.

## What is NOT in scope

- **Inlining the long helpers.** Measured at the gate: +168 bytes on `bmap` to
  save about 12 cycles a call, against a size constraint. Already rejected.
- **A general-purpose optimiser.** The 41.9% bucket is plain ALU, loads and
  stores; some of that is irreducible and the rest is a much longer road.
- **Anything that blocks the UFS campaign.** The 0.1 gate already returned
  "viable": the stack fits at 38 bytes of 256, and the size problem is
  addressed for now by planning the bank split rather than by shrinking code.
  This is an optimisation, and it should be sequenced as one.

## Recommendation, rewritten after building B

B is done and it settled the question this scope existed to ask, in the
opposite direction to the one intended: **register allocation will not shrink
the filesystem.** It moves values between two addressing modes of equal width.
Every measured win for it, here and in llvm816, is a cycle count.

That leaves the 0.1 gate's size finding standing on its own, and it should be
answered the way the gate itself suggested -- by planning the bank split, not
by waiting for the compiler to reclaim 40%.

So:

- **A (callee-saved slots) is now a CYCLES decision, not a size one.** It is
  still the thing that would let filesystem code use the allocator at all, and
  the llvm816 precedent for it is good. But it changes the ABI, and it should
  be justified by a cycle budget nobody has measured yet -- the gate's third
  measurement, still outstanding. Do not start it on the strength of this
  document's original size argument.
- **D (register-passed arguments)** is in the same position and for the same
  reason.
- **The cycle measurement should come first.** It is the one input that would
  make A and D worth arguing about, and it is the one the 0.1 gate skipped.

The lesson worth keeping is cheaper than the work: three separate size levers
were proposed in this campaign from reading a profile -- inlining the long
helpers, then register allocation -- and both evaporated on measurement, in
each case because a plausible story about *where the bytes are* said nothing
about *whether those bytes can be fewer*.
