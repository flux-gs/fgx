# BLK_STAGE relocation -- attempted, measured, REJECTED

The assessment listed moving `BLK_STAGE` out from between the kernel stacks and
the user-stack arena as a small, safe win: **2 arena pages (512 B)**. It was
implemented, it worked, and it was **reverted**. This records why, because the
idea is obvious enough to be proposed again and the reason is not.

---

## What was built, and it did work

`BLK_STAGE` sat at `KSTK_BASE + (NPROC+1)*256`, i.e. **between** the per-pid
kernel stacks and the arena, costing the arena the two pages it occupied.
Moving it into the dead boot block area at `$0800` and letting the arena start
immediately above the kernel stacks gave:

    before:  stacks $0C00-$17FF | BLK_STAGE $1800 | arena $1A00 + 153 pages
    after:   BLK_STAGE $0800 | stacks $0C00-$17FF | arena $1800 + 155 pages

These addresses are the layout as it stood when the relocation was measured;
the kernel stacks have since moved to `CFG_STK_KTASKS` (`include/config.s`).
The conclusion below does not depend on them: `BLK_STAGE` and the arena base
stay where they are, which `tools/ninja/genconfig.py` relies on.

**+2 arena pages, confirmed:** `check_stack_budget` went from 123/153 to
123/155, geometry checker green, kernel built, `smoke`/`psstack`/`catsmoke`
green.

**It is safe from the DMA angle**, which was the first thing checked:
`BLK_STAGE` is used only by the **standard** SmartPort path, where the firmware
"can only name a bank-0 buffer" and the kernel `MVN`s 512 B out of it
(`block.s:647-655`). An extended bus reads straight into the caller's buffer and
never touches it. So nothing lands there without a CPU store -- which matters,
because slot DMA writes one bank only.

## Why it was reverted

**It broke `b3park` and `b3pty`, and the fix is not a constant shift.**

Those two tests are the B3 campaign's stack-attribution evidence: they tap
absolute bank-0 addresses and assert that every write into a parked task's live
frames is attributable to its owner. Their value is *precisely* that they are
anchored to real addresses.

Moving the arena base down two pages moved the taps relative to what they
watch. Part of that is a genuine bug in the tests, and it was fixed:

- **the lane tap was anchored to the wrong end.** The stack lane sits at the
  TOP of the arena (`FGX_STK_LANE_BASE = FGX_STK_ARENA + (ARENA_PAGES -
  LANE_PAGES)*256`), so its absolute position follows the arena *end*. Written
  as `ARENA + 0x4A70` it drifted the moment the base moved while the end stayed
  put. Re-anchoring to `ARENA_TOP - 0x4E90` restores the identical address.
- the `parkstk` tap is correctly anchored to `ARENA`, because it watches a
  bottom-of-arena stack and first-fit allocates from the base.

**But that was not sufficient.** With the tap at a byte-identical address, the
control still failed -- *"no write to `$6470` from pid 4's OWN DP"*. Shifting
the arena base changes which task lands where under first-fit, so the workload's
pid-to-stack mapping moves too. The taps are coupled not just to the arena
geometry but to the **allocation outcome** of a 30-process spawn storm.

Re-deriving them means re-establishing what each tap is measuring on a changed
allocation, and re-validating that the controls still discriminate. **That is
disproportionate to 512 bytes**, and the assessment had already concluded the
low-region reclamation is small and fragmented while the language card is the
prize (`docs/history/audits/bank0-lc-spike-results.md`).

## The finding worth keeping

**The B3 attribution tests couple bank-0 relayout to allocation outcomes**, not
merely to addresses. Any future change to the arena base -- including moving
the kernel stacks or the DP block into language-card space -- will disturb them
the same way, and the cost is not "shift the constants".

That is a real constraint on the language-card work, discovered cheaply here
rather than expensively there. Whatever relayout lands should either:

- keep the arena base fixed and take its space from the top or from outside the
  arena entirely (the language card does exactly this), **or**
- budget for re-deriving the B3 taps and re-proving they still discriminate.

One genuine defect was found and is worth fixing on its own: **the lane tap's
anchor**. It is currently correct only because the arena base has not moved. It
should be `ARENA_TOP`-relative regardless of whether anything else changes, and
that is a two-line change with no layout consequences.

## Credit where it is due

Neither test reported a vacuous pass. Both said, in terms, *"it watches
untouched paint, so its silence proves nothing"* and *"the task never executed
through this cell, so there is no ownership boundary"*. A weaker check would
have gone green on a tap watching dead memory and this would have shipped.
