# Adversarial review of the assessment -- findings and response

An adversarial pass over the completed bank-0 / kernel-scratch assessment
(Phases 1-5), commissioned because the conclusion was comfortable and the
tooling had a known blind spot. Every claim below was re-verified against the
repo before being accepted.

**Two of the four corrections are defects in my own tools. Two of the three new
opportunities are larger than anything the assessment found.**

---

## 1. What the review broke

### 1.1 "20 sleep sites in the entire tree" was WRONG -- a tool defect

Sleeps have **two spellings** and the census knew one:

1. the primitive as a jump operand -- `JSR _sleep`;
2. the service **selector in a register** -- `LDX #KSVC_SLEEP` / `JSL SYS_KCALL`.

**Form 2 is how every module sleeps.** `pty.mod` (`src/modules/pty/pty.s:176-178`)
and `vfs.mod` (`src/modules/vfs/kc_sys.s:121-127`) put the number in X and call
the one multiplexed entry, so the sleep name never appears as a jump target.
A name-only regex reported both files as **sleep-free**.

**`pty` is where apple/fgx#41 lived** -- the other historical defect of exactly
this class. The census was blind to the module with the prior conviction.

**Fixed.** Both tools now match both forms: **24 sleep sites in 12 files**, and
the range walk still returns **zero**. The conclusion survives; the enumeration
it rested on did not.

### 1.2 The kernel-C layer was never measured at all

`dp_sleep_ranges.py` scans `src/**/*.s`. **Kernel C sleeps in six places** --
`vfs_bio.c:338,392,480,747,791` and `vfs_subr.c:779` call `kc_sleep`. None of
it was ever in scope.

It turns out to be **safe by design, not by measurement**: fcc's register file
is one shared page, and `swtch` saves and restores it per task via `_kcDpSave`
(`sched.s:851+`), while C frames ride the per-task kernel stack already
preserved by `SE_KernSP`. So there is no defect -- but the assessment's "zero"
never looked, and said nothing about not looking.

**Ninth stale comment, and the instructive kind.** `include/kernel.s:499-500`
says *"FGX's FS layer today contains no sleep at all... If kernel C ever crosses
`_sleep`, the register file joins what the context switch saves"*. Kernel C now
sleeps, and `_kcDpSave` is exactly the mechanism the comment predicted. **The
code followed the prediction; only the prose failed to notice it had come
true.**

### 1.3 "61% can NEVER become stack automatics" was OVERSTATED

The instruction-set fact is right -- no stack-relative indirect long mode. The
leap to *"no per-task home at any stack size"* is not, and it propagated into
Phase 4 ("stack and absolute are both closed by the instruction set") and
Phase 5.

**`D` is a retargetable 16-bit bank-0 pointer, and the kernel stack is in bank
0.** Point the direct page at the task's own kernel stack page and `[dp],Y`
dereferences a stack-resident far pointer. This is not speculative: the
dispatcher swaps `D` every syscall (`syscall.s:92-95`), `_kFgxDPKernel` is a
variable rather than a constant (`main.s:140-147`), and **kernel C already runs
frames on those same per-task kernel stack pages** (`sched.s:855-858`).
Stack-and-DP coexistence in bank 0 is how kernel C works today.

A second mechanism: `PLB` + `(sr,S),Y` dereferences a stack-held far pointer in
about six instructions.

The practical conclusion -- don't migrate 2,276 sites -- stands on **cost**. The
impossibility framing does not, and it mispriced Option A (section 2.1).

Also: the 61% counts **whole cells**, so a cell with one `[cell],Y` and 100
direct accesses contributes all 101 sites. Irreducibility applies at the
dereference.

### 1.4 The 62-byte stack floor is narrower than it reads

Two limits beyond those already recorded:

- **Slot reuse erases history.** `Task_AllocKernStack` re-zeroes the page on
  every allocation (`task.s:1190-1205`), so the figure means "no task *alive at
  dump time*, *since its own allocation*" -- **short-lived deep tasks are
  systematically excluded**, which is exactly the exec-heavy pipeline case.
- **The one consumer built to eat kernel stack is unexercised.** Kernel C
  frames live on these pages, and the VFS chains that will drive them
  (namei/getblk/bread -- the call graph that drove BSD to 2,048 B) are barely
  touched by `smoke`/`psstack`/`telnet_loopback` while UFS is paused.

The number is honest. The slogan it produced -- *"nothing is asking for a
bigger stack"* -- is not entitled to it. **The asker has not arrived yet.**

### 1.5 Phase 3's framing (arithmetic confirmed)

All figures reconcile. Two framing problems:

- **BSD never paid `NPROC x 3,968` resident.** The u-area swaps with the
  process; FGX's model is all-resident. The "cannot afford" conclusion survives
  but the impossibility is as much about FGX's residency model as about bank
  size.
- **The denominator was understated.** "~46 KB of bank-0 claims" measures
  `$0000-$BFFF` and ignores `$D000-$FFFF` -- see 2.2.

---

## 2. What the review found that the assessment missed

### 2.1 Point `D` at the task's OWN kernel stack page -- Option A for ~0 bytes

The assessment measured 12 per-task bank-0 pages **three-quarters empty**, then
proposed buying **12 new pages** for per-task scratch. It never connected the
two.

Set `D = FGX_STK_KTASKS + (pid<<8)` at kernel entry -- the same 5-instruction
pid computation Option A already needs -- and the per-task scratch band lives in
the **low bytes of the stack page the task already owns**, with the stack
growing down from `$FF` above it. This is precisely the 2.11BSD/GNO unified
per-process block (state below, stack above, one allocation, one lifetime) that
Phase 4b.1 rejected -- **with `D` as the MMU substitute** that the PDP-11's
fixed u-area mapping provided.

| | |
|---|---|
| **gains** | Option A's entire benefit -- all 33 far-pointer cells become per-task, **zero use-site churn** -- for **~0 new bank-0 bytes** instead of 3,328. The shared console DP can be the dead `$0200` page. |
| **costs** | dpmap repack so the per-task band fits low; canary moves between scratch top and stack floor; IRQ entry needs the same `D` |
| **risk** | **medium** -- scratch and stack share one page, and kernel C frames are on it too |
| **verify first** | the distinctive-fill true-HWM probe **under a deliberate worst case** (deep VFS, signal storm, IRQ load), plus a geometry assertion that the measured floor stays clear of the scratch band |

**This inverts Phase 5's ranking.** "Hold Option A because it spends the whole
recoverable set" was justified by a price that does not survive contact with the
assessment's own stack measurement.

**The honest tension:** section 1.4 says kernel-C stack growth is coming, and
this idea spends the same bytes. **You get one or the other**, and which one
depends on a measurement nobody has taken yet. That measurement is now the
gating item for the whole assessment.

### 2.2 The language card -- 12-16 KB of bank-0 RAM never mapped

**The bank-0 map's last row is "`$C000-` | I/O".** A quarter of the bank --
`$D000-$FFFF`, plus the alternate `$D000` bank -- was never inventoried. **`S`
and `D` are 16-bit bank-0 offsets, so both can reach it.**

Verified: `include/hardware.s:38-45` defines the LC soft switches
(`HW_LCBANK1_RD`, `HW_LCBANK2_RW`, ...) and **nothing in `src/` uses any of
them**. FGX has never touched the language card.

| | |
|---|---|
| **gains** | move the kernel stacks (3,072 B) and/or the DP block (3,072 B) + `FGX_DP_KERNELC` (256 B) up there; **~6.4 KB of prime low bank 0 returns to the arena** -- about 25 pages, which is the apple/fgx#45 `NPROC` ladder unblocked. Or grow kernel stacks there if VFS depth demands it, which retires Phase 3's "cannot afford" for the stack line. |
| **costs** | native vectors live at `$00:FFE0-$FFFF`, inside the space; LC state must be restored around SmartPort's emulation-mode `XCE` (`block.s:480-501`) and toolbox calls; an IRQ arriving in a wrong-state window is the sharp edge |
| **risk** | **high** -- but a MAME spike (write/read `$00:D000` under each `$C08x` state, then vector a test IRQ) converts an assertion into a measurement in an afternoon |

Note `$C035` bit 6 (I/O + language card) is a **different mechanism** from
`$C08x` bank switching and the hardware documentation says it must stay 0 for a
working system; that guidance stands. The `$C08x` route does not touch it.

### 2.3 Relocate `BLK_STAGE` -- 512 B, arena-contiguous

`BLK_STAGE` (`$1800`, 512 B) is only the **fallback** for non-extended buses;
extended buses DMA straight into the caller's buffer (`block.s:647-650`). Move
it onto the dead `FGX_BOOTAREA` (`$0800`, 1,024 B available) and the freed
`$1800-$19FF` is **contiguous with the arena at `$1A00`**: +2 arena pages,
exactly one `NPROC` slot's cost.

Low risk, one derived-config change. **And it flags a probable error in the
Phase 2 map**: the settled `$C035` bit list has **no bit for text page 2**, so
`$0800-$0BFF` may not be shadowed at all -- making that region's "but text page
2" discount wrong.

---

## 3. What did not change

- **The measured zero survives** the widened regex: 24 sleep sites, still no
  live range crossing one.
- **`$C035` bits 0-2 at boot** remains the cheapest win and is unaffected.
- **Do not grow the per-task kernel stack** as a way to fix scratch -- the
  blocker is the addressing mode, not the byte count. (Growing it for *kernel C
  depth* is a separate and now-live question, per 1.4.)
- **Deleting the dead EQUs** stands.

## 4. Revised order of work

1. **True-HWM probe under a worst case** (distinctive fill, deep VFS path,
   signal storm, IRQ load). It gates 2.1 and answers 1.4. **This is now the
   critical measurement of the whole assessment** -- everything else waits on
   whether the kernel stack has room to share.
2. **`$C035` bits 0-2** -- unchanged, cheapest win, independent of all of it.
3. **Fix the enforcement checker spec** to cover selector-dispatch sleeps and
   the kernel-C layer, not just the module JT seam. As specced it would have
   been blind to `pty.mod` **today**.
4. **`BLK_STAGE` relocation** -- 512 B where it is worth most.
5. **The language-card spike** -- highest ceiling of anything found; an
   afternoon to make it a measurement instead of an assumption.
6. **Re-decide Option A** once (1) lands, at its real price rather than 3,328 B.

## 5. The pattern behind all four errors

**Current-configuration facts were promoted into hardware law.** "No
stack-relative indirect long mode" (true) became "no per-task home at any size"
(false). "Bank 0 is `$0000-$BFFF`" (the current map) became the denominator for
"cannot afford". "The sleep sites are the ones named in jump operands" (one
calling convention) became "the sleep sites". Each time, a property of how FGX
is arranged today was mistaken for a property of the machine.

The tell is the word **cannot**. Three of the four corrections above were found
by asking, of a *cannot*, whether the hardware or merely this arrangement of it
was doing the forbidding.
