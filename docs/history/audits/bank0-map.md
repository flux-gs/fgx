# Deliverable 2 -- the bank-0 map, with a pinned-by column

Phase 2 of the bank-0 / kernel-scratch assessment
(`docs/history/plans/2026-08-13-bank0-and-kernel-scratch-assessment.md`).

**Run the tools; do not quote this file.**

    python3 tools/check_bank0_geometry.py
    python3 tools/check_stack_budget.py

Measured at `kernel.nproc = 11` (`cfg/system.cfg`), which derives everything
below via `tools/ninja/genconfig.py`.

---

## 1. The map

| range | size | what | pinned by |
|---|---:|---|---|
| `$0000-$00FF` | 256 | boot kernel DP; stale after `Toolbox_AllocKernelDP` | **FIRMWARE** -- firmware/MM scratch it freely |
| `$0100-$01FF` | 256 | `FGX_STK_KERNEL`, boot / no-task kernel stack | **HARDWARE** -- emulation-mode firmware forces stack page `$01` |
| `$0200-$02FF` | 256 | `FGX_SYSVARS` | **NOTHING** -- dead EQU, see 2 |
| `$0300-$03CD` | 206 | module JT gateway, dispatch trampolines, rest-of-OS anchor | **CONSTRUCTION** -- `MOD_JT_BASE` is the fixed module/kernel rendezvous |
| `$03CE-$07FF` | 1,074 | unallocated | **SHADOW?** -- see 3 |
| `$0800-$08FF` | 256 | **`BlkTramp` + `CoutTramp`**, 70 B used | **LIVE AT RUNTIME** -- relocated here, see 2 |
| `$0900-$0BFF` | 768 | -- | **FREE** -- reclaimed 2026-08-13, contiguous with `$0C00` |
| `$0C00-$17FF` | 3,072 | per-pid kernel stacks, `NPROC+1` = 12 pages | claimed |
| `$1800-$19FF` | 512 | `BLK_STAGE`, SmartPort staging buffer | claimed |
| `$1A00-$B2FF` | 39,168 | user-stack arena, 153 pages | claimed |
| `$B300-$B3FF` | 256 | `FGX_DP_KERNELC` | claimed |
| `$B400-$BFFF` | 3,072 | per-pid direct pages, `NPROC+1` = 12 pages | claimed |
| `$C000-` | -- | I/O | **HARDWARE** |

From `$0C00` up, the layout is **exact and contiguous** -- every boundary
derives from `kernel.nproc`, and `check_bank0_geometry.py` pins all of it
including the stage-2 mirrors. The easy wins really are gone, as the charter
assumed.

**The unclaimed region is entirely below `$0C00`**, and the four bank-0 rows of
the Memory Manager claim table (`toolbox.s:_ClaimTable`) do not mention it.

## 2. Two dead EQUs

- **`FGX_SYSVARS`** (`$0200`, 256 B) -- **one reference in the tree: its own
  declaration.** The comment says it "was reclaimed by Fix #2 but restored on
  revert"; nothing uses it now.
- **`FGX_BOOTAREA`** (`$0800`, **512 B since UFS 2.2**, 1,024 B before it) --
  **NOT DEAD. Do not delete the EQU and do not reuse the region.** *(Corrected 2026-08-13, before anything acted on
  the entry below.)* The region holds **`BlkTramp` and `CoutTramp`**, which the
  kernel `JSL`s at runtime through the `$02FF00` handoff block:
  `block.s:76` and `boot_console.s:48` read their entry points and
  `dev.s:280` (`_dev_patchBlkTramp`) patches them. `loader.s:20-24` states the
  contract outright -- *"This loader keeps BlkTramp / CoutTramp / HandoffData
  live for the kernel ... $0800-$0BFF persists in RAM for the lifetime of the
  system"* -- and `stage2.s:21` calls it "stage 1 code (dead but holding
  BlkTramp + CoutTramp)".

  **The reasoning that made it look dead is the lesson: "one reference, its own
  declaration" is a fact about the SYMBOL, not the REGION.** The live content
  is reached by pointer and by handoff block, never by this name, so no
  reference to `FGX_BOOTAREA` was ever going to appear. A symbol with no
  references is not an unused region -- to retire an address range you have to
  show nothing reaches those ADDRESSES, by any name.

  **RECLAIMED 2026-08-13, and the question that did it was "why would we need
  stage 1 to persist?"** The comment's framing conflated two things. Only
  **~70 bytes** are live -- `BlkTramp` + `BlkTrampParams` + `CoutTramp`, the
  bank-0 stubs that enter emulation mode to call SmartPort and COUT firmware,
  which the kernel in bank `$02`+ cannot do for itself. Everything else is boot
  code: `$0800-$09FF` is block 0 (ROM entry and the block-1 self-load) and
  `$0A00-$0B6A` is block 1 (`MainLoad`, dir scan, sapling load, `BlkRead`).
  The `$0A00` split is not a design choice either -- the IIgs ROM loads only
  block 0, so stage 1 self-loads block 1 there.

  The blob sat at the TOP of the region purely by assembly order. It is now
  assembled at `$0800` and copied there at `LoadDone`, over stage 1's own
  finished block-0 code, freeing **`$0900-$0BFF`** and making **`$0900-$17FF`
  15 contiguous pages**. The kernel needed no change: it reads the addresses
  from the `$02FF00` handoff block rather than baking them, which is the whole
  reason the blob could move. `loader.s` carries `ERR TrampEnd/$0900` so the
  blob cannot silently grow back into the reclaimed page.

  **UFS 2.2 shrank the loaded region itself, not just the live part.** Stage 1
  is one sector now -- 2.11BSD's disklabel owns sector 1
  (`h/disklabel.h:53`, `LABELSECTOR 1`) -- so `$0A00-$0BFF` is no longer read
  off the disk at all, and the ROM leaves it untouched. What lands is
  `$0800-$093F`; what survives the copy at `LoadDone` is still only
  `$0800-$0845`. Two further `ERR` lines in `loader.s` hold the new shape: one
  keeps `LoadDone` above the blob's destination, since the copy loop now lives
  in the same sector it is overwriting, and one keeps the whole file inside
  sector 0.

  The stale text follows, kept so the error is legible rather than silently
  rewritten: *"one reference: its own declaration. Boot-block load area; stage
  2 has handed off long before the first task, which is the same
  transient-overlap the kernel stacks already rely on for stage 2's
  `DIR_BUF`/`IDX_BUF`."*
- **`FGX_STK_TASKS`** (`$3000`) -- seven references, **all of them comments**,
  several saying so explicitly ("a symbol nothing references any more"). The
  arena was walked down over it. Costs nothing today; listed so the next reader
  does not resurrect it.

## 3. THE GATE: is the low region shadowed, and does that make it 1 MHz RAM?

**This is the open measurement Phase 2 turns on, and it is not answerable by
reading the source.**

`$0400-$07FF` is Apple II **text page 1** -- `src/boot/loader.s:100-121` clears
it in both main and aux at boot, with the `PAGE2`/`PAGE1` softswitches. `$0800-
$0BFF` is text page 2. On a IIgs, bank-`$00` writes to a shadowed range are
**also** written through to bank `$E0`, and that write-through **runs at 1 MHz**.

The Apple IIgs Firmware Reference (p. 303) gives the control:

> `$C035` -- bit 0 = 1 to inhibit shadowing text pages; bit 1 = hi-res page 1;
> bit 2 = hi-res page 2; bit 3 = 32K video buffer; bit 4 = aux hi-res.

**FGX never sets a global shadow policy.** `$C035` appears only in `sim.s` (and
its `simtest` twin), where it is saved to `$0119`, masked for the ROM call, and
restored. So FGX inherits whatever the ROM leaves.

Two consequences, both needing measurement rather than inference:

1. **The 2,098 contiguous bytes at `$03CE-$0BFF`** -- directly below the kernel
   stacks, and the natural place for them to grow downward -- are usable RAM
   only at the shadowed write cost, unless bit 0 is set. Setting it is one
   instruction with a display consequence FGX plausibly does not care about,
   since it renders to a scanline framebuffer in bank `$03` and never shows the
   text screen.
2. **Hi-res pages 1 and 2 are `$2000-$5FFF`, which is inside the user-stack
   arena** (`$1A00-$B2FF`). If hi-res shadowing is enabled, **a large part of
   the existing user-stack arena is already running at 1 MHz** -- roughly 16 KB
   of the 38 KB. That would be a standing performance cost nobody has measured,
   affecting stacks that exist today, independent of anything this assessment
   proposes.

**Gate 2 (new):** read `$C035` on a live boot and record it. Until then, every
recoverable-bytes number below is conditional, and point 2 is a hypothesis, not
a finding. **Do not report the low region as recoverable on the strength of it
being unallocated -- unallocated and usable are different questions here.**

## 4. Recoverable, conditional on Gate 2

| region | bytes | confidence |
|---|---:|---|
| `$0200-$02FF` (`FGX_SYSVARS`) | 256 | dead EQU; shadow-free (not a text page) |
| `$03CE-$07FF` | 1,074 | unallocated, but text page 1 |
| `$0800-$0BFF` (`FGX_BOOTAREA`) | 1,024 | boot-transient, but text page 2 |
| **total** | **2,354** | **2,098 of it contiguous at `$03CE-$0BFF`** |

**What 2,098 bytes buys, and why it is not the answer.** Spread over `NPROC+1`
= 12 kernel stacks it is 174 bytes each, taking them from 256 B to ~430 B. It
is **not** enough to double them (that needs 3,072 B). And per Phase 1, 61% of
direct-page sites cannot move to a stack at any size, so this does not buy the
BSD shape either way.

Reserved-but-unused arena headroom is 30 pages (7,680 B): `check_stack_budget`
reports a **123 of 153 page** worst case. That is the safety margin for the
deepest tool in a pipeline under tcsh, so it is not free -- but it is the
largest single number on the table and Phase 4 has to price it honestly rather
than treat it as untouchable.

## 5. Stale comments found while mapping

The charter says to run the tools rather than quote the documents. Mapping
turned up why:

- `toolbox.s:_ClaimTable`'s narrative says `BLK_STAGE` is "actually `$1700`".
  It is **`$1800`** (`config.s:27`). The prose was written at `NPROC = 10`; the
  code is derived and correct. Had the table still been hand-written, `$1700`
  would have collided with pid 11's kernel stack page.
- `include/kernel.s:265-300` still describes the arena as "149 pages
  (`$2200-$B6FF`), abutting `FGX_DP_KTASKS` at `$B700`". It is **153 pages,
  `$1A00-$B2FF`, abutting `$B400`**.
- `include/kernel.s:745` claims "swtch swaps `_u`". `sched.s` never mentions
  `_u`; it is re-derived per use. (Recorded in the Phase 1 census.)

None of these are defects. All three would have become defects the moment
someone trusted the prose over the derivation -- which is the argument for the
derived claim table and for `check_bank0_geometry.py`.

## 6. Gate 2a -- FGX's kernel stacks are a quarter full

The charter wanted a high-water probe built. It turned out most of one already
existed: `Task_AllocKernStack` **zeroes** each page and seeds a `$C5C5` canary
in its bottom word, and nothing ever re-zeroes it. So a byte that was ever
written to a non-zero value stays non-zero, and **the lowest non-zero byte in a
page is a cumulative high-water floor** -- not a snapshot of current depth.

Reading it needed one line: a `kern_stacks` region (`$0C00`, 3,072 B) in
`tools/mame_test/plugins/fgxdebug/init.lua`. No kernel change.

Measured across three workloads, counting only pages whose canary proves the
page really is an initialised kernel stack:

| workload | live stacks | deepest floor |
|---|---:|---:|
| `smoke` | 7 | **62 B** of 256 |
| `psstack` | 7 | **62 B** of 256 |
| `telnet_loopback` (networking, 9 tasks) | 9 | **62 B** of 256 |

Per-task floors cluster at 40 / 46 / 51 / 62 B. **No task's kernel stack has
ever been measured past 62 of its 256 bytes -- 24% -- including with the
network stack live.**

**This weakens the growth hypothesis from the other side.** Phase 1 showed 61%
of scratch sites cannot move to a stack at any size; Phase 2a shows the stack
that exists is three-quarters empty. Together they say the 256-byte kernel
stack is **not** the binding constraint, and that recovering bank 0 to enlarge
it would buy headroom nothing currently asks for.

**Read the number honestly:**

- It is a **floor, not the HWM**. A legitimately pushed zero is
  indistinguishable from untouched fill, so true depth is >= these figures. The
  charter's distinctive-fill probe would tighten it and is still worth building.
- The workloads are **the test suite, not a stress case**. No deep UFS path, no
  signal storm, no worst-case pipeline.
- **IRQ depth is included only where an interrupt actually nested during these
  runs.** Handlers share the page, so the figure is not an IRQ-free measurement
   -- but neither is it a deliberate worst case.

### What the same dump revealed about the boot overlap

Pages for pids that never got a task still hold **stage-2 boot residue**, since
`Task_AllocKernStack` never ran to zero them: `$1400` holds
`# /etc/boot.conf ... kernel /KERNEL` (CONF_BUF), `$1600` holds `KERNEL`
(PATH_BUF), and `$0C00` holds the `/LIB/MODULES` directory listing (DIR_BUF).

This is the transient overlap `include/kernel.s` documents, working exactly as
intended -- boot buffers below, task stacks over the top, stage 2 long gone.
**But the documented addresses are wrong again**: the comment places
`CONF_BUF`/`PATH_BUF` at `$1000-$121F`, and they are observably at `$1400` and
`$1600`. Fourth stale-address finding; the overlap principle holds, the numbers
do not.

### A measurement defect found in passing

`init.lua`'s `blk_stage` region points at **`$2000`**. `BLK_STAGE` is
**`$1800`** (`config.s:27`). The harness has been dumping 512 bytes of the
user-stack arena and calling it the SmartPort staging buffer. Not changed here
-- existing checks may read that region and this is an assessment branch -- but
it should be fixed, and it is the same hand-synced-constant rot the claim table
already got caught by.

## 7. Still owed by Phase 2

- **Gate 2**: the live `$C035` reading.
- **A distinctive-fill HWM probe** to turn section 6's floor into a true
  high-water mark, and a deliberate worst-case workload to exercise it.
- **The 4-objects x 4-events lifecycle table** (fork, exec, exit, slot reuse).
- **Live occupancy** rather than reservations, for the arena.
