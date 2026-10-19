# Bank 0 above `$C000` -- what the assessment never mapped

Evaluation of `gs-mcp/docs/bank0-memory-map.md` (2026-08-13) against FGX's
bank-0 assessment. **The assessment's map stopped at "`$C000-` | I/O". That was
a quarter of the bank, and it is not all I/O.**

Two corrections to the map, one explanation of a measurement, and two routes to
substantially more bank 0.

---

## 1. CORRECTION -- the screen holes are inside the "recoverable" region

`hardware_ref` p. 106, via the map doc section 1.1. **56 bytes of main memory
are allocated to peripheral cards, 8 per slot, living inside the text page 1
buffer**:

    $0478 $04F8 $0578 $05F8 $0678 $06F8 $0778 $07F8   +$00..$07 = slot number

*"Owned by slot and built-in port firmware. Never write them unless you have
taken over the hardware entirely."*

**Phase 2 listed `$03CE-$07FF` (1,074 B) as unallocated and recoverable. Eight
8-byte holes inside it are not.** FGX calls slot firmware -- `block.s:1397`
does `LDAL $00C000,X` to read `$CnFB`, the SmartPort ID byte, and the SmartPort
entry is fetched from slot ROM -- so the holes for the disk slot at minimum are
live.

Practical effect is small (56 B of 1,074) but it changes the shape: the region
is **not a contiguous block**, and anything placed across it must skip eight
holes. A per-task stack or DP page laid over `$0400-$07FF` would straddle them.

## 2. CORRECTION -- `$03F0-$03FF` is the page-3 vector area

Map doc section 2.1: `$03F0` BRK, `$03F2/$03F3` RESET, `$03F4` power-up byte,
`$03FB` NMI `JMP`, `$03FE` IRQ -- with `$03FB` confirmed live in TN #1 and
`$03FE` in TN #105.

FGX's own `memmap.s` already treats `$03C8-$03CF` as firmware-scratched and
parks `KFGX_REST_ANCHOR` at `$03CC`, so the neighbourhood was known. But the
Phase 2 map called everything from `$03CE` up "unallocated", which sweeps the
page-3 vectors into the recoverable set. **They are not recoverable while
anything in the machine dispatches through them.**

## 3. EXPLAINED -- why `$C035` read back as `$20`

The measured value was `$20`, bit 5 set. The bit list FGX was working from
called bit 5 "reserved -- do not touch". **The map doc (section 2.2,
`hardware_ref` pp. 22-23 Table 2-1) says bit 5 is text page 2 shadowing, on
1 MB logic boards**, and section 1 notes text page 2 "is not shadowed on ROM 1;
ROM 3 adds a Shadow-register bit for it."

So the machine boots with **text page 2 shadowing already inhibited**, which is
exactly the `$20`. Consequence for Phase 2: **`$0800-$0BFF` (`FGX_BOOTAREA`,
1,024 B) is already full-speed RAM** and needs no shadow change at all. The
Phase 2 table discounted it as "boot-transient, but text page 2" -- the second
half of that was wrong.

**Two sources disagree on bit 5** (reserved vs text page 2). The measurement
supports the map doc, since something set bit 5 and nothing in FGX writes
`$C035`. Treat bits 0-2 as the actionable ones and leave 5 alone either way.

## 4. ROUTE A -- the language card: ~16 KB, and the vectors stay put

Map doc section 3.1, `hardware_ref` p. 30. **The language card is 16 KB of RAM
in a 12 KB window:**

    $D000-$DFFF   4K, bank-switched -- LC bank 1 OR LC bank 2
    $E000-$FFFF   8K, NOT bank-switched -- the same 8K either way

The two "banks" are a 4 KB feature, not a 12 KB one -- the most commonly
misunderstood part of the region, and worth stating because it halves a naive
estimate.

**Switching** (section 3.3, `hardware_ref` p. 31): `$C080-$C08F`, three
independent bits -- read RAM/ROM, write-enable/protect, `$D000` bank 1/2.
**Write-enable requires two consecutive reads of the same address** (the
`LDA $C083 / LDA $C083` idiom). You cannot read one bank and write the other,
and you cannot mix ROM and RAM within the region. Power-on state is read ROM,
write RAM, bank 2; **reset reinitializes it**, so FGX would set it once at boot.
`$C011` and `$C012` read the state back; **write-enable status cannot be read**.
`$C068` packs eight switches into one byte for fast interrupt save/restore.

**The decisive property for FGX** (section 3.4, `firmware_ref` p. 173): with
I/O shadowing on -- which is FGX's state -- *"the system ROM in bank `$FF` is
shadowed (and readable) in bank `$00`"* and the CPU pulls vectors from the ROM
table. **You cannot take the vectors merely by switching in LC RAM.** That is
usually described as a limitation; for FGX it is the feature. **Switching LC
RAM in does not disturb interrupt dispatch at all** -- the chain stays ROM ->
bank `$E1` vectors -> `$03FE`, and all of that dispatch state lives in bank
`$E1`, costing nothing in bank 0.

| | |
|---|---|
| **gains** | up to **16 KB** of bank-0 RAM reachable by `S` and `D`. Moving the kernel stacks (3,072 B) and the DP block (3,328 B) there returns **~6.4 KB of prime low bank 0** to the arena -- about 25 pages, which is the apple/fgx#45 `NPROC` ladder |
| **costs** | LC must stay switched in permanently, or anything resident there vanishes under an interrupt taken in the wrong state |
| **verify** | that FGX never needs Monitor/Applesoft ROM at `$D000-$FFFF` (it calls **slot** ROM at `$Cxxx` and the toolbox in `$E1`/`$FF`, neither of which is in this window); that no firmware path FGX uses flips the LC switches behind its back; and the `$C068` save/restore discipline for any path that must touch it |
| **risk** | **medium** -- one boot-time switch, permanent state, no vector work |

This is materially safer than the assessment assumed, because the vector
question -- which looked like the blocker -- does not arise while bit 6 is 0.

## 5. ROUTE B -- `$C035` bit 6: a flat 64 KB bank 0

Map doc section 2.2 quotes the register verbatim: *"When this bit is 1, the I/O
space and language card are inhibited, and contiguous RAM is available from
`$0000` through `$FFFF`."* Section 3.1 adds that the RAM which would occupy
`$C000-$CFFF` *becomes* the second `$D000` bank, so **bank 0 genuinely contains
a full 64 KB -- nothing is wasted, it is remapped.**

**FGX is closer to this regime than expected.** Measured across the tree:
**45 I/O accesses already go through `$E0C0xx`/`$E1C0xx` longs, and only 6 go
through bank 0** -- `loader.s:113,121` (boot-time `PAGE2`/`PAGE1`), `sim.s:301,328`
(the shadow register itself), and two in a standalone test. **Four sites in
shipped code**, all mechanically convertible.

**Correcting my own earlier claim:** I recorded bit 6 as "must stay 0 or the
machine dies". That is not what the hardware says. It is a *trade*: you lose
every soft switch at a bank-`$00` address, and `$E0`/`$E1` I/O is explicitly
unaffected and always enabled, so hardware access simply moves there.

**But there is a real blocker, and it is not the vectors.** With bit 6 = 1 the
`$Cxxx` space in bank 0 is RAM, so **slot ROM disappears from bank 0** --
and FGX reads `$CnFB` from `$00C000,X` (`block.s:1397`) and calls the SmartPort
firmware that lives there. Reaching it at `$E0:Cn00` may work, since `$E0` I/O
is always live, but the firmware would then execute with `PBR = $E0` at 1 MHz,
and it is legacy code with its own assumptions. **That is a spike, not an
argument.**

Vectors are the known, documented cost: with bit 6 = 1, `$00:FFE4-$FFFF` is
RAM and the CPU pulls FGX's vectors from it. *"If you have not correctly set up
the RAM vectors and you turn off I/O shadowing, the system will fail."* Write
them first.

| | |
|---|---|
| **gains** | **only +4,096 B over Route A** -- the `$Cxxx` hole. Section 3.1 says that RAM *is* the second `$D000` bank, which Route A already reaches, so the two routes are not additive the way "16 KB vs 32 KB" suggests |
| **costs** | own the native vectors; move 4 I/O sites; **lose SmartPort's slot ROM entirely** |
| **risk** | **high**, and gated on the SmartPort question |

**Verdict: rejected in favour of Route A.** Four kilobytes is not worth losing
every bank-`$00` soft switch and the slot ROM the block driver calls on every
disk I/O. Revisit only if FGX ever ships a native IWM/SmartPort driver and no
longer needs card firmware.

## 6. LEAD -- why the historical `NewHandle` bank-0 crash may have been ours

Phase 4b.4 left the `$BBxx` crash that drove FGX to a static stack arena as
"deferred, not refuted". The map doc supplies a likely mechanism.

Section 4.4 gives the real-world idiom (`apple_iigs_projects/Maxus/maxus.asm`):

    DPAttr equ attrLocked+attrFixed+attrPage+attrBank

with `locationPtr` = `#0` so the bank byte is `$00`. **All four bits are
load-bearing**, and section 4.4 says why: *"`attrLocked` + `attrFixed` -> cannot
move out from under the `D` register. A direct page that relocates during
compaction is an instant crash."*

**`locationPtr` is ignored unless `attrAddr` or `attrBank` is set**
(`toolbox_ref_vol1` p. 511, verbatim) -- so a request that omits `attrBank`
silently ignores the location and lands wherever the Memory Manager likes.

Either omission reproduces the observed failure. Worth checking the historical
call before treating dynamic bank-0 allocation as unavailable.

## 6b. The vector fear was wrong -- the LC option is MEDIUM risk, not high

The review-response rated the language card **high** risk on the grounds that
"native vectors live at `$00:FFE0-$FFFF`, inside the space" and that an IRQ
arriving in the wrong LC state was the sharp edge. **Both halves are wrong, and
two independent primary sources say so.**

- `firmware_ref` p. 192: vectors come from the bank-`$FF` ROM shadow whenever
  I/O shadowing is on, and *"Both EIRQ and NIRQ jump to ROM located within the
  soft-switch area"*.
- GS/OS 6.0.1's own engineering map (`iigs_system_601:GSInfo/GS Memory Map:268`):
  *"00/C071..00/C07F Entry points for interrupt/brk handling (yes, 15 bytes of
  code live here!)"*, and `GSToolbox/sys.equs.asm:802` calls `$C071` the "ROM
  interrupt code jump table".

**`$C071` is I/O space. The `$C08x` switches control only `$D000-$FFFF`.** So an
IRQ taken with bank-0 LC RAM switched in vectors ROM -> `$Cxxx` stub -> `$E1`
dispatch -> FGX's hook at `$E10010` (`sim.s:183-214`) **without ever executing
`$00:D000-$FFFF`**. The dispatch path does not touch the region at all.

### The real sharp edge, which is narrower and fixable

**An IRQ during the SmartPort excursion.** The trampoline is
`PHP PHB PHK PLB SEP #$30 SEC XCE JSR $Cn00` (`block.s:225-227`) -- **there is
no `SEI`**, so interrupts stay enabled through an emulation-mode window in which
card firmware may call F8 ROM, which requires read-ROM selected while FGX's
stacks and DPs would sit unreadable underneath.

The designed fix is named in the doc (section 3.3): **`$C068` STATEREG** packs
`RDROM` + `LCBNK2` for a one-load/one-store save and restore. GS/OS uses exactly
this, and `iigs_system_601:GS.OS/Common/hw.equ.src:333` documents the trap --
two reads of `$C083`, *then* change statereg, because **write-enable is not in
the register and cannot be read back**.

### One correction to the supporting evidence

The claim that FGX never calls bank-0 ROM is **not quite true**: `loader.s:578`
does `JSR $FDED` (firmware COUT) and `main.s:1426` does `JSR $FE1F`
(`IDROUTINE`). **Both are boot-time**, so the conclusion survives -- FGX makes
no bank-0 ROM call at runtime -- but it becomes a **sequencing constraint**: any
LC switch-in must happen after hardware detection, not before.

### What it is worth, concretely

Moving the 12 kernel stacks (3,072 B), the 12 per-pid DPs (3,072 B) and
`FGX_DP_KERNELC` (256 B) -- **6,400 B** -- into the flat 8 KB at `$E000-$FFE3`
alone, plus the `BLK_STAGE` relocation, makes the arena `$0C00-$BFFF`:
**180 pages against 153 today, +27 pages**, with both `$D000` banks (8,192 B)
still spare. That is the apple/fgx#45 `NPROC` ladder unblocked *and* room to
double kernel stacks (512 B x 12 = 6,144 B also fits) if VFS depth arrives.

**Verification list for the spike** (one MAME afternoon): canary-fill both
`$D000` banks and `$E000-$FFE3` and run the suite with toolbox and SmartPort
traffic; confirm the two `$D000` banks are distinct RAM; fire a test IRQ in
each LC state **including inside an emulation-mode SmartPort window**; confirm
a native toolbox call runs with `S` in LC RAM; confirm the `$C068` idiom
preserves write-enable; and **check the harness can even see LC RAM** -- a MAME
dump of `$00:E000` may resolve to ROM depending on how the debugger models
banking, which is the "watchpoint on the ORG bank reports zero writes" trap
again.

## 6c. GNO does the unified block, and here is the code

The strongest evidence yet for the per-task-DP-on-the-stack-page idea, verified
in both indexed copies (`gno/sys.c:942-943`, `gno_kern` same lines):

```c
newStack = ctxtstuff.ctx_S1 = il_rec.dPageAddr + il_rec.buffSize - 5;
ctxtstuff.ctx_D = il_rec.dPageAddr;
```

**`D` at the base of the block, `S` at the top of the same block** -- one
bank-0 Memory Manager allocation per process serving as both direct page and
stack, attributes `$C015` (locked + fixed + noCross + page + bank), default
4 KB. A shipped IIgs multitasking kernel runs exactly the scheme the review
proposed as "Option A for ~0 bytes".

**And GNO never touches the bank-0 language card** -- zero `$C08x` references
in the entire kernel. So the two ideas are independent: GNO validates the
unified block, and nothing in GNO speaks to the LC either way.

## 6d. Revised reclaim floor: `$0400`, not `$03CE`

Combining sections 1 and 2 with the GS/OS map (`:87-137`):

- **screen holes** -- 64 B in eight islands, `$0478` through `$07F8`;
- **`MSLOT` at `$07F8`** -- holds `$Cn` for the slot owning `$C800-$CFFE`.
  Clobber it and the next SmartPort call dispatches into the wrong card's
  expansion ROM;
- **page-3 vectors `$03D0-$03FF`** -- 48 B, and the SmartPort window runs
  emulation-mode with IRQs enabled, so the ROM's 8-bit chain is reachable in
  principle.

**So the clean contiguous recoverable space is `$0800-$0BFF` (1,024 B, already
full-speed on ROM 01), and `$0400-$07FF` is 1,024 B minus 64 B of holes, usable
only in fragments or as growth that stops at `$07F8`.** The reclaim floor should
be `$0400`, and the "2,098 contiguous bytes" figure in `bank0-map.md` should be
read as fragmented.

## 7. Things the doc confirms that FGX already had right

- `D` and `S` are 16-bit and bank-0-only (section 4.2), and *"every tool set,
  desk accessory, application and the OS itself needs direct-page space, and
  all of it comes out of the same ~46 KB"*. The scarcity is structural, exactly
  as the assessment concluded.
- Shadowed writes run at 1.024 MHz while **reads come from the fast bank at
  2.8 MHz** (section 1.3) -- confirming the correction that only the store is
  stretched.
- All of bank `$00` is **special memory** (section 1.2), and the Memory
  Manager's allocatable window is `$0800-$BFFF` -- which is what FGX pre-claims.
- `$0C00-$1FFF` has "a reputation it did not earn" (section 4.1): it is
  reserved in `$E0`/`$E1`, **not** in bank 0. FGX puts kernel stacks there and
  that is correct.

## 8. Trust notes

The doc is explicit that its corpus is OCR'd and its structured entries are
`status: proposed`, and it lists its own known errors (section 5) including a
mangled attribute-bit figure, lost bit numbers in the state-register table, and
lost vector names. **It flags these rather than smoothing them**, which is why
the numbers above are worth acting on -- but the two that matter most for FGX
(bit 5's meaning, and the `$C08x` state table) should be confirmed against
`hardware_ref` pp. 22-23 and p. 31 before code depends on them.

Also recorded there: `search_iigs_docs` fails on queries containing `/` and
silently returns zero in `raw` mode for some phrasings that work in `safe`
mode. **That explains the empty result this assessment got when trying to
settle the shadow-bit question** and wrongly recorded as "the corpus did not
confirm it". Rephrase before concluding the corpus lacks material.
