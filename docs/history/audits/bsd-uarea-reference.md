# Deliverable 3 -- what 2.11BSD actually reserves

Phase 3 of the bank-0 / kernel-scratch assessment
(`docs/history/plans/2026-08-13-bank0-and-kernel-scratch-assessment.md`).

The charter's question: *how much does BSD reserve per process, and can FGX
meet it?* Both halves are now answered, and the second answer is no.

---

## 1. The numbers, from the live machine

`USIZE` is machine-dependent and is **not** in the vendored subset. It is
defined in `vendor/2.11BSD/usr/sys/pdp/machparam.h:87` (vendored from
`examples/` in the same commit that recorded this):

    #define NET_SSIZE   16  /* size of the network stack (*64) */
    #define KERN_SSIZE  32  /* size of the kernel  stack (*64) */
    #define USIZE       (btoc(sizeof(struct user)) + NET_SSIZE + KERN_SSIZE)

The remaining unknown -- `sizeof(struct user)` -- came from the running
11/70's generated `assym.h`, read-only, no compile:

    grep USIZE /usr/src/sys/GENERIC/assym.h   ->  #define USIZE 62.
    grep SBASE /usr/src/sys/GENERIC/assym.h   ->  #define NET_SBASE  [_u+896.]
                                                  #define KERN_SBASE [_u+1920.]

Those three lines determine the whole layout:

| component | offset | bytes | clicks |
|---|---:|---:|---:|
| `struct user` (rounded up to a click) | `_u+0` | **896** | 14 |
| network stack (`NET_SSIZE`) | `_u+896` | **1,024** | 16 |
| kernel stack (`KERN_SSIZE`) | `_u+1920` | **2,048** | 32 |
| **total u-area** (`USIZE*64`) | | **3,968** | **62** |

**Cross-checked:** 14 + 16 + 32 = 62 = `USIZE`, and `KERN_SBASE` + 2,048 =
3,968 = `USIZE*64`. Every number reconciles; none of it is inferred.

## 2. Against FGX

| | 2.11BSD | FGX | ratio |
|---|---:|---:|---:|
| u-area proper | 896 B | 116 B | 7.7x |
| kernel stack | 2,048 B | 256 B | **8x** |
| network stack | 1,024 B | **none** | -- |
| **per process** | **3,968 B** | **372 B** | **10.7x** |

## 3. FGX cannot afford the BSD shape, and the number is not close

At `NPROC+1` = 12:

| | bytes | vs bank 0 |
|---|---:|---|
| BSD-shaped u-area + stacks | 47,616 (46.5 KB) | **more than everything bank 0 currently claims (~46 KB)** |
| BSD-sized kernel stacks alone | 24,576 (24.0 KB) | 8x today's 3.0 KB |
| Phase 2's recoverable candidates | 2,354 (2.3 KB) | ~10% of the kernel-stack line alone |

**This closes the charter's third question.** Matching 2.11BSD's per-process
reservation would consume more of bank 0 than bank 0 currently hands out in
total. Not "expensive": arithmetically impossible in the space available.

## 4. But the comparison is a reference, not a requirement

The number FGX would have to meet is its own, and Phase 2a measured it:
**62 bytes of 256 used**, as a cumulative floor, across boot, shell and
networking with nine live tasks. 2.11BSD's `NET_SSIZE`/`KERN_SSIZE` are
"determined empirically" (`machparam.h:75`) for a kernel with a full VFS, a
supervisor-space network stack and far deeper call chains.

So the three findings line up in the same direction:

1. **Phase 1** -- 61% of DP sites cannot become stack automatics at any size,
   because the 65816 has no stack-relative indirect long mode.
2. **Phase 2a** -- the existing 256-byte stacks run about a quarter full.
3. **Phase 3** -- the BSD shape needs more bank 0 than exists.

**Growing the per-task kernel stack is not the answer to the scratch problem**,
and it is not a thing FGX can afford even if it were.

## 5. The structural finding: BSD gave networking its own stack

The single most transferable thing in the layout is not a size. It is that
**2.11BSD allocates a separate 1,024-byte stack for the networking code**, in
addition to the kernel stack, per process, *even on non-networking systems*
(`machparam.h:78-83`, which says so explicitly so binaries need not be
recompiled).

They did that because network code is deep and different from the rest of the
kernel.

**FGX runs `net.mod` on the same 256-byte per-task kernel page as everything
else -- and that is exactly where apple/fgx#100 lived.** Where 2.11BSD's answer
to "networking is deep and different" was a dedicated stack, FGX's was a shared
direct-page cell held across a sleep.

That is the comparison worth carrying into Phase 4, and it costs 1 KB per
process in BSD's design, which FGX equally cannot afford at `NPROC` = 11. The
question Phase 4b.6 should ask is whether the *depth* is real for FGX or an
artifact of a kernel five times the size.

## 6. Method notes

- **Read-only throughout.** Nothing was compiled or written on the oracle;
  `tools/pdp11.exp` is read-only by convention and the machine is somebody's
  working system. The generated `assym.h` already contained everything needed.
- **The dynamic ask was correctly dropped.** The charter originally wanted live
  kernel call-chain depth from the oracle; access is expect + telnet to a user
  shell, with no path to a running kernel's stack. Reading compile-time
  constants is the feasible form of the same question.
- **Trap: the oracle's `grep` is BRE and alternation does not survive the
  expect/tcsh layer.** `grep "A\|B\|C" file` returned nothing on a file that
  contains all three; three separate single-pattern greps found them
  immediately. A silent empty result from the oracle is more likely a quoting
  failure than an absent value -- re-query before concluding.
- **`2>&1` is not csh syntax.** The oracle's shell is tcsh; it answers
  "Ambiguous output redirect" and runs nothing.
