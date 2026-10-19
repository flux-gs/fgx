# Fork-safe large allocations: restore the MM big-block path (#11)

> **★ COMPLETE 2026-08-02.**  All five tasks landed on
> `feat/preempt-p4-interruptible` (`7c73d111e`..`8aa8cff69`).  Three things went
> differently from the plan and are worth reading before trusting it as a
> record:
>
> 1. **The "19,712 B heap" the plan is built on was a MIS-MEASUREMENT.**  It came
>    from `mallocmax`, which runs its probes first and never frees, so it reports
>    a leftover rather than a ceiling.  The real per-process heap is 58,624 B --
>    a whole private sbrk bank, and the same data space 2.11BSD gave a PDP-11
>    process.  New fixture `heapcap` measures it honestly.
> 2. **A third defect surfaced that the plan did not predict:** a HOLE in the
>    middle of the size range.  Payloads from 32762 to `$F000` failed outright,
>    too big for malloc's signed-sbrk guard and too small for the MM path.
>    `_mgrow` splits an oversized `sbrk` into two in-range calls.
> 3. **Task 5 (#10) was settled the other way.**  Narrowing libc `malloc` to
>    `unsigned` was rejected: the premise (large allocations broken anyway) no
>    longer held once `malloc(80000L)` was a gated exit criterion again.  Fixed
>    the fixture's declaration instead.
>
> The maintainer ruled the small-allocation ceiling stays at one bank (~59 KB): main's
> ~512 KB was the SHARED kernel arena, which is exactly what fork could not
> isolate.

> Implements the fix for GitLab **#11** (heap cut 512 KB -> 19.7 KB, `malloc(80000L)`
> broken) without reintroducing **#4** (a fork child's heap writes leaking into the
> parent). Also closes the `realloc` big-block hole and settles **#10**.

**Goal:** large allocations come from dedicated MM banks again, and those banks
are covered by snapshot-fork so a child can never write through to the parent.

**Architecture:** keep the sbrk heap in the task's data bank for small
allocations (that is what fixed #4), and route `>= KMALLOC_BIG_THRESH` to
task-private MM banks recorded in the block table. Teach `_Fork_Snapshot` to
include those banks in the snapshot pair set. `_Fork_Restore` already loops over
pairs and needs no change. Fail closed: if a spare bank cannot be claimed, fork
returns EAGAIN rather than sharing.

**Why this shape:** it is the 4.4BSD answer. 2.11BSD/PDP-11 had no large path at
all (64 KB data space; `ed.c:138` spools to `mktemp("/tmp/eXXXXX")`), 4.2/4.3BSD
on a flat VAX never needed one, and 4.4BSD introduced `mmap` — after which BSD
malloc services large requests from a **separate anonymous mapping**, not from
the contiguous break, and `fork` **copies** those mappings rather than sharing
them. FGX's `_Kmalloc_Big` dedicated bank-aligned block is an anonymous mapping
in all but name.

## Global constraints

- Vendored sources under `vendor/2.11BSD/` are **pristine** — never edited.
- Any fcc/libc fix requires a regression fixture, demonstrated **RED before green**.
- Bugs are GitLab work items; `docs/ROADMAP.md` carries a one-paragraph pointer.
- Feature branch only; never self-merge; `ALLOW_FEAT_PUSH=1` to push.
- FGX-facing text is ASCII only.
- After any kernel-layout change, regenerate `src/kernel/w5100_patchsites.s` and
  **both** `gen_far_bankpatch.py` invocations.

## Measured starting state (2026-08-02)

| fixture | main | `feat/preempt-p4-interruptible` |
|---|---|---|
| `mbig` — `malloc(80000L)` | `MB=P` | **`MB=F:alloc`** |
| `mallocmax` — total heap | 524,288 B / 2048 chunks | **19,712 B / 77 chunks** |
| `mallocmax` — `RSZ 16384` | ok | **FAIL** |
| `gptr_heap` | pass | **fail (exit 9 = malloc returned NULL)** |

## Facts the plan depends on (verified, not assumed)

- `_Fork_Snapshot` (`src/kernel/process.s:871`) documents its mutable set and
  builds a descriptor:
  ```
  +0 parent pid (2)   +2 pair count (2)
  +4 pairs[2] of {orig bank, spare bank} bytes   (data, sbrk)
  +8 stackBase (2)  +10 stackSize (2)  +12 dpPage (2)  +14 pad
  +16 stack bytes (stackSize), then 256 DP bytes
  ```
  The pair writes are **unrolled**: pair0 at ~:967 then "pair count = 1" at
  :975; pair1 at ~:1005 then "pair count = 2" at :1013.
- `_Fork_Restore` (`:1096`) is **already a loop** over pair count
  (`_fr_pairIdx`, stride 2) — no change needed there.
- Unwind on failure already exists (`@fs_unwindPair0`, `:1080`) — the fail-closed
  path to extend.
- **The SE slot is FULL**: 32/32 bytes, `SE_SbrkBank` at +31, and `SE_SIZE` is
  pinned to `TCB_SIZE/2` by `seoff = (TCBoff - $0800) >> 1`. A new per-task field
  is therefore structural and is **avoided** by this plan.
- **The block-table row has a spare byte.** `include/memmap.s:920`: 8-byte rows,
  16 of them — `+0 base bank, +1 bank count, +2 kind (4 = dedicated big-malloc
  block), +3 pad, +4..+7 MM handle`. Ownership goes in **+3**.
- `KMALLOC_BIG_THRESH = $F000` (`include/memmap.s:282`);
  `MM_CLAIM_MAX_BANKS = $20` (`:286`).
- `_Kmalloc_Big` (`src/kernel/libc/alloc.s:1063`) already returns a dedicated
  bank-aligned block at `bank:0000` and `_Kfree_Big` disposes it whole;
  `_BlkRow_DisposeByBank` tombstones the row.
- 16 rows is a **system-wide** cap shared with kinds 1/2/3, so it bounds how
  many big blocks can exist at once. Fail closed when rows run out.

## File structure

| file | responsibility |
|---|---|
| `include/memmap.s` | document `+3` as the owner pid; no size change |
| `src/kernel/libc/alloc.s` | stamp owner on kind-4 rows; free-by-owner helper |
| `src/kernel/process.s` | snapshot loop over data + sbrk + owned big banks; free owned big banks at exit/exec |
| `toolchain/lib/libc_c/libc_c.c` | route `>= $F000` to the big path; big-block `realloc`; drop the `0x7FFE` guard for the big path only |
| `toolchain/include/stdlib.h` | retire the "realloc >= $F000 returns NULL" note |
| `src/userland/bigfork/bigfork.c` | **new** — proves fork isolation of a big block |
| `tools/mame_test/tests/` | manifests for `mbig`, `mallocmax`, `bigfork` |

---

### Task 1: Own the kind-4 rows

**Files:** `include/memmap.s` (comment only), `src/kernel/libc/alloc.s`

- [x] **Step 1: document the field.** In the row-format comment change
      `+3 pad` to `+3 owner pid (0 = kernel/unowned)`. No layout change — the
      byte already exists.
- [x] **Step 2: stamp it.** In `_Kmalloc_Big`, after the row is claimed, write
      `_curTask` (low byte) to row+3. Kernel-context allocations (`_curTask == 0`)
      stay 0 and are never snapshotted.
- [x] **Step 3: add `_BlkRow_FreeByOwner`** — walk the 16 rows, and for each
      `kind == 4 && owner == A`, `_Kfree_Big` it. Returns the count freed.
- [x] **Step 4: assemble + boot smoke.** `ninja all && bash tools/gate.sh`.
- [x] **Step 5: commit.** `git add include/memmap.s src/kernel/libc/alloc.s`

### Task 2: libc routes large requests to the big path

**Files:** `toolchain/lib/libc_c/libc_c.c`, `toolchain/include/stdlib.h`

**Interfaces produced:** `malloc`/`free`/`realloc` keep their current
signatures. `free` must distinguish shapes: a big block is
**bank-aligned at offset 0**, so `(offset == 0)` identifies it — the sbrk heap
never returns offset 0 (its break starts at `$0002`).

- [x] **Step 1: write the failing fixture first** — see Task 4; run it and
      watch `mbig` report `MB=F:alloc`.
- [x] **Step 2: route in `malloc`.** For `size >= 0xF000` (or any size whose
      high word is non-zero) call the big-block syscall instead of `sbrk`. The
      `need > 0x7FFE` guard stays on the **sbrk path only** — it exists because a
      `need` crossing `0x8000` reaches the kernel as a NEGATIVE `sbrk`, which the
      kernel honours as a shrink below `end` and reports success.
- [x] **Step 3: route in `free`** on the offset-0 test.
- [x] **Step 4: `realloc` big-block path.** The kind-4 row carries base bank +
      bank count, so the old size IS recoverable — the historical blocker ("the
      kernel copy path cannot see the old block's length") no longer holds.
      Allocate new, copy `min(old,new)`, free old.
- [x] **Step 5: retire the stale note** in `stdlib.h:11` about `>= $F000`
      returning NULL.
- [x] **Step 6:** `make -C toolchain libc_c` — **required**; `ninja disk` does
      NOT regenerate `libc_c.s` from the `.c`, and skipping it silently invalidates
      the whole experiment.
- [x] **Step 7: commit.**

### Task 3: snapshot the owned big banks

**Files:** `src/kernel/process.s`

**Interfaces consumed:** `_BlkRow_FreeByOwner` (Task 1), row+3 owner.

- [x] **Step 1: replace the unrolled pair writes with a loop.** Build the pair
      list as: data bank, sbrk bank if granted, then each kind-4 row owned by the
      parent — one pair per **bank** of a multi-bank block. Write the real count.
- [x] **Step 2: size the descriptor for N pairs.** Currently `16 + stackSize +
      256` with `pairs[2]`; make the pair array variable and the allocation follow.
- [x] **Step 3: extend the unwind.** Generalise `@fs_unwindPair0` to free every
      spare claimed so far, then the descriptor, and return EAGAIN. **This is the
      fail-closed property** — never fall through to sharing.
- [x] **Step 4: verify `_Fork_Restore` needs no change** — it already loops on
      pair count. Read it and confirm; do not assume.
- [x] **Step 5: free owned big banks at exit and at a vfork child's execve,**
      beside the existing `SE_SbrkBank` teardown (`:1863`, `:1927`).
- [x] **Step 6:** regenerate `w5100_patchsites.s` and both
      `gen_far_bankpatch.py` invocations — kernel layout moved.
- [x] **Step 7:** `bash tools/gate.sh`, then commit.

### Task 4: fixtures, and put them in a gate

**Files:** `src/userland/bigfork/bigfork.c` (new), `tools/ninja/manifest.json`,
`tools/mame_test/tests/{mbig,mallocmax,bigfork}.json`

`bigfork` is the fixture that would otherwise be silently broken:

```c
/* bigfork - a big block must be COPIED by fork, not shared (#11 / #4).
 * malloc(80000L), write a sentinel, fork; the child overwrites it and
 * _exits; the parent must still read its own value.  Exits 42 on success. */
p = malloc(80000L);
p[0] = 'A'; p[70000] = 'B';        /* both banks of the block */
if (fork() == 0) { p[0] = 'Z'; p[70000] = 'Z'; _exit(0); }
wait((int *)0);
ck(p[0] == 'A' && p[70000] == 'B', "fork copies the big block");
```

- [x] **Step 1: write `bigfork.c`;** register in `manifest.json` (tools +
      staging).
- [x] **Step 2: prove it RED** — with Task 3 stubbed out it must report the
      child's `Z`. A fixture that has never been red proves nothing.
- [x] **Step 3: manifests for `mbig` and `mallocmax`.** Neither had one; that is
      why a documented **train-2 M-4 exit criterion** could regress unnoticed.
- [x] **Step 4: wire all three into `tools/gate.sh`** (they are seconds, and the
      gate is the only thing that always runs).
- [x] **Step 5:** full verification — `bash toolchain/tests/run.sh` (goldens),
      `python3 toolchain/tests/multibank/run_multibank.py`,
      `python3 toolchain/tests/run_runtime.py` (change-scoped; a `toolchain/lib/`
      edit trips the pile-change trigger and samples 240 fixtures), `tools/gate.sh`.
- [x] **Step 6: commit + push; update #11, #10, #4 and the ROADMAP.**

### Task 5: settle #10 (K&R argument width)

Do this **after** Tasks 1-3, because the allocator's shape may change underneath
it. `gptr_heap` fails because fixtures compile with **no `--sigs`**, so a bare
K&R `char *malloc();` pushes 2 bytes where libc reads 4 (`LDA #64 / PHA`).

The maintainer's call: **make libc `malloc` take `unsigned`** to match 2.11BSD, so the
natural K&R push is already correct — rather than routing fixtures through
`--sigs`. With the big path in place the 16-bit size is no longer a capability
ceiling, because large requests go through the big-block entry point rather than
through `malloc`'s 16-bit size argument.

- [x] Audit every `malloc`/`calloc`/`realloc` caller for sizes that need > 16
      bits (`mbig` and `mallocmax` are the known ones; `tar` already casts to
      `(unsigned)`).
- [x] Decide how a `> 64 KB` request is spelled once `malloc` is 16-bit —
      this is the open design question in Task 5 and must be settled before
      touching the signature.
- [x] Fixture, RED first, then goldens + oracle.

## Risks

1. **Fork cost.** A task holding 80 KB pays ~2 banks of MVN at fork and again at
   hand-back. Only tasks holding big blocks pay. No MMU, so COW is unavailable.
2. **Bank exhaustion.** Fork now needs one spare per owned big bank. Fails closed
   with EAGAIN — verify that path explicitly rather than trusting it.
3. **16-row table.** System-wide across kinds 1/2/3/4; a task with several big
   blocks plus fork spares can exhaust it. Fail closed.
4. **Fork is the least forgiving code in the tree.** Task 3 is the risky one; keep
   it a separate commit from Tasks 1, 2 and 4 so it can be reverted alone.
