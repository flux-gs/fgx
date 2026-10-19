# Deliverable 5 -- costed options and the recommendation

Phase 5 of the bank-0 / kernel-scratch assessment
(`docs/history/plans/2026-08-13-bank0-and-kernel-scratch-assessment.md`).

**Nothing here has been implemented.**

> **SUPERSEDED IN PART, 2026-08-13.** The ranking below was decided before the
> language-card spike, which measured **16,384 bytes** of bank-0 RAM, ran the
> full suite **97/97** on it, and has since been **confirmed PASS on real
> hardware** (`docs/history/audits/bank0-lc-spike-results.md`). Section 4's
> recommendation is revised in **section 6** at the end of this file. The
> measurements in sections 1-3 stand; what changed is that the assessment now
> has an option that raises the ceiling, which none of A/B/C did.

---

## 1. The assessment set out to answer three questions

> *Are we severely overloading kernel scratch variables that should not exist,
> and can bank 0 be cleared enough to do this the way BSD does?*

| question | answer |
|---|---|
| **Scratch** -- are the shared cells a live hazard? | **Less than feared.** Measured exposure across the whole kernel call graph is **zero** live ranges crossing a sleep. Three choke points save; nothing else holds. |
| **Bank 0** -- can it be cleared? | **~2.3 KB**, of which 2,098 B is contiguous. That is the whole recoverable set; from `$0C00` up the layout is exact. |
| **Per-process stacks** -- can FGX afford the BSD shape? | **No.** 46.5 KB at `NPROC+1`=12, against ~46 KB of total bank-0 claims. |

**The premise turned out to be wrong in a useful way.** The assessment was
chartered on the hypothesis that bigger per-task kernel stacks would let FGX
retire shared scratch the way BSD does. Three independent measurements say
otherwise:

1. **61% of direct-page sites can never become stack automatics** -- the 65816
   has no stack-relative indirect long mode, so a far pointer cannot be
   dereferenced from a stack slot at any stack size.
2. **The stacks that exist run about a quarter full** -- 62 of 256 bytes,
   cumulative, across boot, shell and networking with nine live tasks.
3. **The BSD shape does not fit** -- and would not help if it did, per (1).

## 2. The options

### Option C -- do nothing structural  **[RECOMMENDED]**

| field | value |
|---|---|
| bank-0 recovered | 0 (or 1,280 B opportunistically, by deleting two dead EQUs) |
| kernel stack it buys | unchanged, 256 B -- against a measured need of 62 B |
| enough for the measured need? | **yes, 4x headroom** |
| cells deleted | none |
| cells remaining | 33 DP-IRREDUCIBLE, 73 others |
| sites touched | **~15** (the checker, not the kernel) |
| code-size delta | ~0 |
| enforcement | extend sleep-reachability over `net`/`sock`/`pipe`, **modelling the module jump-table seam** |
| risk | **lowest** |

The measured exposure is zero. The two defects this campaign found (#41, #100)
are both fixed at their choke points, and the pattern that fixes them --
`PEI`/`PLA` around the sleep -- is cheap, local and already used in three
places.

**What it does not buy:** the invariant stays invisible. Every new sleeping path
is a fresh chance to reintroduce #100, and the tooling built in Phase 1 is
blind at exactly the seam where #100 lived.

**So the enforcement is the deliverable, not the fix.** A checker that models
the module seam turns "currently zero" into "cannot regress". That is ~15 sites
of Python and no kernel change, and it is the single highest value-per-risk
item in this entire document.

### Option A -- per-task kernel direct page

| field | value |
|---|---|
| bank-0 recovered | **spends** 3,328 B (13 pages: 12 per-task scratch + 1 shared console) |
| kernel stack it buys | unchanged |
| enough for the measured need? | n/a -- does not address stack size |
| cells deleted | **0 deleted, but all 33 DP-IRREDUCIBLE cells become per-task**, which is what the hazard class actually needs |
| sites touched | **0** in the kernel; the console gets `TCD` entry/exit |
| code-size delta | ~0 (a `TCD` pair per console entry) |
| enforcement | the class stops existing; no checker needed for it |
| risk | **medium** -- a boot-time replication step and a console DP discipline |

The mechanism is already there: the dispatcher swaps `D` on every syscall
(`syscall.s:92-95`), so making it pid-indexed is about five instructions.
**Nothing else on the table fixes the whole shared-scratch class without
touching a use site.**

The blocker is that the direct page is not all scratch -- the console's 742
sites are one device's shared state -- and the answer is the split already
proven by `FGX_DP_KERNELC`, which gives kernel C its own page for the same
reason.

**Cost against Phase 2:** 3,328 B needed, 2,354 B recoverable, so it takes
~1 KB from the arena's 30 reserved-but-unused pages.

**Why not recommended now:** it spends the entire recoverable set plus arena
headroom to fix a class whose measured exposure is currently zero. It becomes
the right answer if the exposure stops being zero -- if kernel C starts
sleeping, if more subsystems become modules, or if `NPROC` grows.

### Option B -- `copyin`/`copyout`

| field | value |
|---|---|
| bank-0 recovered | 0 |
| kernel stack it buys | unchanged |
| cells deleted | potentially most of `$50-$9F`; **`_libcTmp2`'s 554 sites collapse to one primitive** |
| sites touched | **~250 hand-written assembly sites** across the syscall layer and three modules |
| code-size delta | **unknown and material** -- could go either way; a call replaces an inlined copy, but 250 call sites is not free against the 64 KB segment ceiling |
| enforcement | one routine to audit instead of 20 sleep sites x 11 cells |
| risk | **highest** |

This is what 2.11BSD actually does, and Phase 3 confirmed it. It is the only
option that removes the need rather than relocating it, and it would make the
enforcement question trivial.

It is also 250 sites of hand-written asm in the layer with the least test
coverage, for a class with zero current exposure. **Right answer, wrong decade.**
Worth doing incrementally -- new code uses the primitive, old sites migrate when
touched -- rather than as a campaign.

## 3. The finding that may outrank all three

**Gate 2 is closed, and the answer is the worst case.** Measured on a live
boot (`$C035` via a harness dump region, no kernel change):

    $C035 = $20  ->  bits 0-4 all clear  ->  ALL shadowing ACTIVE

Every shadowed bank-0 write is mirrored to `$E0`/`$E1` and pays the 1 MHz
penalty. Two consequences:

1. **The 2,098 recoverable bytes at `$03CE-$0BFF` are text-page shadowed**, so
   their writes are slow until bit 0 is set. FGX renders to a scanline
   framebuffer and never displays the text screen.
2. **Part of the user-stack arena is hi-res shadowed.** `$2000-$5FFF` is hi-res
   pages 1 and 2, inside the arena's `$1A00-$B2FF`, so **every task whose stack
   landed there has been paying a stretched cycle on every push since the arena
   was carved** -- 64 of 153 pages.

**FGX cannot inhibit everything.** Bank `$01` holds live SHR data -- measured,
14% of `$01:2000` non-zero, SCB 100% populated -- so the display depends on
`$01 -> $E1` shadowing. (This also retires the comment at
`include/kernel.s:37`, `FGX_BANK_AUX ... reserved, not used`: it is used, for
the framebuffer.)

### The bits, settled

- **bit 0** -- Text Page 1 (main **and** aux)
- **bit 1** -- Hi-Res Page 1 (main and aux)
- **bit 2** -- Hi-Res Page 2 (main and aux)
- **bit 3** -- Super Hi-Res, the whole 32 K as one unit, shadowed from bank `$01`
- **bit 5** -- text page 2, on 1 MB boards. **This is the bit FGX was measured
  with already set**, so `$0800-$0BFF` arrives un-shadowed and needs nothing.
  (An earlier bit list called bit 5 "reserved"; the measurement supports the
  hardware reference.)
- **bit 6** -- I/O + language card. **CORRECTED:** an earlier version of this
  document said "must stay 0 or the machine dies". It is a *trade*, not a
  death: setting it costs every bank-`$00` soft switch and the slot ROM the
  block driver calls, while `$E0`/`$E1` I/O is unaffected. It is rejected for
  FGX on cost -- it buys only ~4 KB over the language-card route, because the
  RAM behind the I/O hole *is* the alternate `$D000` bank that route already
  reaches. **Leave it 0**, but for the right reason.

`$C035` is **cleared on reset, so everything is shadowed by default** -- which
is exactly the `$20` FGX was measured in. FGX has simply never set it.

**Bit 3 is what SHR needs, and it is independent of bits 0-2.** So FGX can
inhibit the text and hi-res regions it never displays while keeping the
framebuffer's mirroring. Per the hardware documentation this is not a clever
trick -- **setting bits 0-2 is the normal state for a native-mode SHR
program**, which is precisely what FGX is. The current all-shadowed state is
the non-standard one.

### What that is worth

| | |
|---|---|
| `$03CE-$0BFF` (the 2,098 recoverable bytes) | becomes **full-speed** RAM instead of 1 MHz-on-write |
| `$00:2000-$5FFF` -- 64 of the arena's 153 pages | stops paying the shadowed-write penalty |
| SHR display | **unaffected** -- bit 3 stays 0 |
| cost | **one read-modify-write at boot** |

**Correction to the earlier framing in this document:** shadowing stretches
only the **store**. Reads and computation stay at 2.8 MHz. So the arena
penalty falls on pushes, not pulls, and on stores through a stack pointer --
roughly half of stack traffic, not all of it. The effect is real but smaller
than "those pages run at 1 MHz" implied.

### Implementation notes for whoever does it

- **Read-modify-write only** -- `LDA $C035 / ORA #mask / STA $C035`. A blind
  store clobbers bit 6 (I/O and language card) and crashes the machine.
  `sim.s` already uses the read-modify-write form; copy that shape.
- **Restore before toolbox and firmware calls**, which assume the standard
  shadow state. `sim.s` already saves to `$0119` and restores around its ROM
  call; the same discipline applies.
- **Shadowing is a CPU-write mechanism.** Anything landing bytes in memory
  without a CPU store -- slot DMA in particular -- writes one bank only. This
  matters for the SmartPort staging buffer and any future DMA path.
- **`$C036` bit 4** would shadow all of banks `$00-$7F`. Leave it 0.
- **Set bit 0 first, then 1-2, verifying the display between.** Bits 1 and 2
  are documented as covering hi-res pages in **main and aux**, and SHR's lower
  half occupies the aux hi-res addresses (`$01:2000-$5FFF`) -- while bit 4
  exists specifically to override bits 1-2 "for odd banks". The documentation
  says setting bits 0-2 is normal for a native-mode SHR program, so they should
  not interact, but the failure mode if they do is **corruption confined to the
  top ~40% of the screen**, which is subtle enough to ship unnoticed. Bit 0
  (text pages) has no SHR overlap at all and is unconditionally safe; take it
  first and bank the recoverable region, then test bits 1-2 for the arena win
  separately.

This is now the **highest value-per-effort item in the assessment**: one
instruction at boot, no code motion, no bank-0 spend, and it both unlocks the
recoverable region at full speed and removes a standing write penalty from 40%
of the user-stack arena.

## 4. Recommendation

1. **Set `$C035` bits 0-2 at boot** (section 3), read-modify-write. This is the
   normal configuration for a native-mode SHR program; FGX has simply never set
   it. One instruction, no code motion, no bank-0 spend. It makes the
   recoverable region full-speed and removes a standing store penalty from 64
   of the arena's 153 pages. **Highest value-per-effort item in the
   assessment.** Verify the display is intact and re-run the suite; bit 3 stays
   0 so SHR should be untouched.
2. **Take Option C**, and treat *the enforcement checker as the deliverable*:
   sleep-reachability over `net`/`sock`/`pipe` that models the module seam.
   Currently-zero exposure is worth keeping.
3. **Delete the one dead EQU** (`FGX_SYSVARS`, 256 B -- **`FGX_BOOTAREA` is NOT
   dead**: it holds `BlkTramp`/`CoutTramp`, live at runtime, see
   `bank0-map.md`) and the
   dead `FGX_STK_TASKS` symbol. Free, and it stops the next reader resurrecting
   them. Note the recoverable low region is **fragmented, not contiguous** --
   the screen holes and page-3 vectors sit inside it; see
   `docs/history/audits/bank0-upper-region-options.md`.
4. **Hold Option A** as the designed answer if exposure returns. The analysis is
   done; the trigger is kernel C sleeping, more modules, or a higher `NPROC`.
5. **Adopt Option B incrementally** -- new code uses a `copyin`/`copyout`
   primitive; existing sites migrate when touched anyway.

**Do not grow the per-task kernel stack.** It cannot fix the scratch class,
nothing is asking for the space, and FGX cannot afford the size that would
match the reference.

## 5. Defects and rot found along the way

| what | where |
|---|---|
| apple/fgx#100 -- socket sleep lost the caller's buffer bank | **fixed**, MR !154 |
| `_libcTmp2` is 554 code sites, not ~694 | 148 of the grep hits were comments |
| harness dumps `$2000` as `BLK_STAGE`; it is `$1800` | `init.lua` -- reports a slice of the arena instead |
| "swtch swaps `_u`" | `include/kernel.s:745` -- `sched.s` never mentions `_u` |
| arena described as 149 pages `$2200-$B6FF` | actually 153 pages `$1A00-$B2FF` |
| `BLK_STAGE` "actually `$1700`" | actually `$1800` |
| stage-2 `CONF_BUF`/`PATH_BUF` at `$1000-$121F` | observably `$1400` and `$1600` |
| `FGX_BANK_AUX ... reserved, not used` | bank `$01` holds the live SHR framebuffer |

Seven stale comments in one assessment, every one of them an address or a
mechanism that a reader would have trusted. **The derived claim table and
`check_bank0_geometry.py` are the reason none of them became a defect** -- the
code is generated from the real EQUs, so only the prose rotted.


---

## 6. REVISED RECOMMENDATION -- after the language-card spike

The original ranking rested on a scarcity that has since been measured away.
**Bank 0 has 16 KB more RAM than the assessment's map showed**, it is reachable
by both `S` and `D`, nothing contends for it, and FGX passes 97/97 with it
mapped.

### What changes

**The forced trade is gone.** The review found that per-task scratch could be
overlaid on the three-quarters-empty kernel stack pages -- Option A for ~0 bytes
-- but that it competed with the kernel-C frame growth Phase 2a warned about:
*"you get one or the other, and which one depends on a measurement nobody has
taken."* **With 16 KB available, that measurement stops being a gate.** Both can
be funded from different parts of the region.

**Option A's price collapses twice over.** It was rejected at 3,328 B against a
2,354 B recoverable set. The recoverable set is now ~18 KB, and the option no
longer has to squeeze into a shared page.

### Revised order

1. **`$C035` bits 0-2 at boot.** Unchanged, still the cheapest thing here, still
   independent of everything else. Bit 0 first (no SHR overlap), then 1-2 with a
   display check.
2. **Productionise the language card.** The spike proved feasibility **and a
   real IIgs confirms it**. Shipping needs four remaining items from
   `bank0-lc-spike-results.md` section 5 -- `$C068` discipline around the
   SmartPort excursion, boot ordering, reset handling, and a geometry rule --
   The **session-long hardware run is not obtainable** -- a diagnostic image
   cannot demonstrate a working session -- so that half rests on the 97/97
   emulator result and gets answered by shipping rather than by a spike. This
   is the highest-value work item, because it is the only one that raises the
   ceiling.
3. **The enforcement checker**, with the spec corrected to cover
   selector-dispatch sleeps (`LDX #KSVC_SLEEP` / `JSL SYS_KCALL`) and the
   kernel-C layer, not just the module jump-table seam. Still the right answer
   to the scratch question: measured exposure is zero and the point is keeping
   it there.
4. **Then re-decide Option A**, at its real price and without the trade against
   kernel-C growth.
5. **`BLK_STAGE` relocation** and the dead-EQU deletions -- small, safe, do them
   when convenient.

### What does NOT change

- **Do not grow the per-task kernel stack to fix the scratch problem.** The
  blocker is the addressing mode, not the byte count, and that is unaffected by
  having more bytes. (Growing it for *kernel-C depth* is now affordable, which
  is a different question and a real one.)
- **The scratch exposure is still zero**, and the enforcement checker is still
  the deliverable rather than any code motion.
- **The 62-byte stack floor is still a floor**, still measured with kernel C
  barely exercised, and the true-HWM probe under a worst case is still worth
  building -- it is just no longer a gate on anything.

### The honest summary

The assessment set out to ask whether bank 0 could be cleared enough to hold
BSD-shaped per-process state. The answer to the question as posed is still no.
But the assessment's own map was short by a quarter of the bank, and the
question that mattered turned out to be **"is the map right"** rather than
**"can we afford the shape"**.
