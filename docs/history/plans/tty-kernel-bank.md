# Tty kernel bank - design

**Status:** T1 landed 2026-08-22; **T2.1** the same day.  The bank exists,
boots, initialises in both directions, logs `tty: bank ready` from inside
itself, and runs two tenants to checked verdicts at boot -- 2.11BSD's clists
(T1) and the line-discipline switch (T2.1).

Core kernel 56,683 B of 57,968 (1,285 free).  Far bank 15,822 B of 60,480
(44,658 free).  Tty bank 22,128 B of 60,480 (38,352 free).

This is the third statically linked kernel image.  It is a near-copy of the far
bank (`docs/history/plans/far-kernel-bank.md`), and that document is the long form of every
mechanism named here; this one records only what is different and why the bank
exists at all.

---

## 1. Why a third bank

The BSD tty layer has to be somewhere, and the survey
(`docs/history/plans/2026-08-22-tty-bsd-shape-placement-survey.md`) ruled out
both of the alternatives on measurements rather than on taste.

**Not a module.**  FGX's tty INPUT discipline runs at INTERRUPT time.
`toolbox.s` is the 60 Hz heartbeat task; at `@hb_kbd` it reads
`_ttyTable+TTY_SgFlags`, applies `SG_RAW`, detects `^C`/`^Z` and posts
`_kTtySigPend`.  It is live from `Toolbox_InstallHB` in `main.s`, **152 lines of
boot before `Mod_LoadConf`**.  A module is not loaded yet at that point and
cannot be.

**Not the far bank.**  The layer is 2,460 code lines of C.  At the measured
kernel-C rate of 19.1 bytes of 65816 per code line (801 lines -> 15,264 bytes
across four far-bank translation units, comments stripped), that is **~46,900
bytes** against **18,411 free** in the far bank.

**A third bank is nearly free.**  `LoaderAllocKernelBank` already claims
`KERNEL_BANKS` contiguous bank-aligned banks in a single `NewHandle`,
over-allocating one for alignment slack, and the far bank is base+1 derived from
`PHK`/`INC`.  The allocation was already parametric: `KERNEL_BANKS` `$02` ->
`$03` and a third image at base+2 is the whole claim change.

---

## 2. What is different from the far bank

| | far bank | tty bank |
|---|---|---|
| runtime bank | live kernel bank + 1 | live kernel bank + 2 |
| assembly ORG | `FGX_KFAR_BANK` `$08` | `FGX_KTTY_BANK` `$09` |
| ABI file | `include/kfar.s` | `include/ktty.s` |
| magic | `KFAR_MAGIC` `$4B46` `'FK'` | `KTTY_MAGIC` `$544B` `'KT'` |
| link file | `fgxfar.link.s` | `fgxtty.link.s` |
| root | `src/kernel/far/far.s` | `src/kernel/tty/ttybank.s` |
| image | `bin/fgxfar.bin`, `/KERNELFAR` | `bin/fgxtty.bin`, `/KERNELTTY` |
| core-side init | `Far_Init` | `Tty_Init` |
| bank-side init | `Far_BankInit` (slot 0) | `Tty_BankInit` (slot 0) |
| core -> bank markers | `_kfpNNN` -> `src/kernel/far_patchsites.s` | `_ktpNNN` -> `src/kernel/tty_patchsites.s` |
| bank -> core markers | `_cfpNNN` -> `src/kernel/far/core_patchsites.s` | `_ctpNNN` -> `src/kernel/tty/core_patchsites.s` |
| missing image | **FATAL** (the console lives there) | reported, not fatal -- see below |

Everything else is the same by construction: the export table is `JMP abs16`
slots at bank offset `$0000` and is never patched, unassigned slots halt with a
red border, and the return path is a scraped core address plus a boot-patched
bank byte.

**The root is `ttybank.s`, not `tty.s`.**  T3 compiles upstream's `tty.c`, and
fcc writes `tty.s` beside its source.  A root called `tty.s` would collide with
it in the same directory.

### The name

The bank is named for its tenant.  "far" said only "somewhere else", which was
right when its payload was four unrelated subsystems; this bank is the tty
layer's home and every increment of apple/fgx#108 lands in it.  If something
unrelated ever moves here the name should follow the majority -- but a bank
called "third" would tell a reader nothing on the day they need it.

### Tenants other than the tty layer

**The kernel clock** (`src/kernel/tty/kern_time.c`, slots 43 on) lives here
for this bank's room, not its subject.  Its C did not fit the far bank --
1,012 B free when it landed, against about 1.3 KB for its first increment
alone -- and this bank had 10,771 B and is live from boot, which `inittodr`
needs and a module is not.  It touches no tty: it reaches the core's four time
words through its own accessors in `kc_sys.s` and is reached through its own
slots.  The name stays: the tty layer is still the overwhelming majority, which
is the test "The name" above sets.

### Absence is not fatal, and that is temporary -- IT ENDED AT T3

`Far_Init` halts on a missing `/KERNELFAR` because there is nothing left to
degrade to: the console is in there and boot JSLs into it two instructions
later.  Nothing on the boot path calls into the tty bank yet, so `Tty_Init`
reports and returns with `_kTtyReady` clear.

**The day the line discipline moves in (T3) that has to become the same loud
halt.**  It is written down here and in `Tty_Init`'s own header because a
non-fatal path that quietly stops being survivable is exactly the kind of stale
policy the far bank's history warns about.

**That day arrived, and the note did its job.**  T3's stage 1 puts `t_pgrp` and
`t_flags` in this bank, so `Tty_Init`'s `@ti_absent` is now Far_Init's halt one
bank along -- firmware COUT, red border, spin.  Two accessors' worth of
`_kTtyReady` guards never had to be written, because the answer is now always
yes.

---

## 3. The apparatus is shared, not copied

The survey called for "a second copy of the per-bank apparatus".  What landed is
one copy of each tool, taught about a third bank, because two copies of a
generator are two things to keep in step:

* **`tools/gen_far_bankpatch.py`** already took a direction argument.  It now
  has four: `core`/`far` for the core <-> far pair and `core-tty`/`tty` for the
  core <-> tty pair.  The direction record gained a fifth field, the export-slot
  prefix of the bank being called, which drives the "unmarked cross-bank JSL"
  completeness check -- that check used to be spelled `direction == 'core'`.
* **`tools/check_far_calls.py`** parses every bank ABI in its `ABIS` table and
  checks the core listing against each range.  The two ranges coincide today
  (`$0000..$0085` both) and the loop exists because they are separate EQU sets
  that can drift.
* **`tools/check_far_rtl_calls.py`** walks each bank's source tree
  **separately**.  Pooling them would let a name that is RTL-terminated in one
  bank condemn an unrelated same-name RTS routine in the other.
* **`tools/check_kernel_ceiling.py`** gained an `IMAGES` row and a
  magic-per-bank map, so a displaced tty image is caught by its own `'KT'`
  rather than by the far bank's `'FK'`.
* **`tools/gen_kernel_exports.py`** gained a `tty` manifest.

**The RTL shims are not duplicated at all.**  `src/kernel/far_shims.s` holds
core-bank routines whose only job is to be RTL-terminated; nothing in them is
far-specific, and a second set would be core-bank bytes spent to say the same
thing twice.  The tty manifest scrapes the same symbols.  The `_FarSh_` spelling
now names where the shims LIVE, which is neither of the banks that call them.

`Tty_Init` **is** a near-copy of `Far_Init`, and deliberately.  The two differ
in the derived bank, the magic, the patch table and the failure policy, which is
four of the six things the routine does; a parameterised version taking a
descriptor would cost more core bytes than the duplication saves.

---

## 4. Boot sequence

1. Stage 2 loads `/KERNELTTY` into (kernel bank + 2):`$0000`, immediately after
   `/KERNELFAR`.  Offset `$0000` because the export table is the first thing in
   the image.
2. `FGX_Entry` calls `Far_Init`, then `Tty_Init`.
3. `Tty_Init` verifies `KTTY_MAGIC` and the ABI version in that bank, walks
   `_TtyPatchTbl` fixing every core-side `JSL` operand bank byte, then calls
   slot 0 with `A` = the core bank.
4. `Tty_BankInit` walks `_CorePatchTbl` fixing every tty-side operand bank byte
   to the core bank, and returns `C=1`.
5. `_kTtyReady` is set; `_LogTtyBank` later calls slot 1, which logs
   `tty: bank ready` **from inside the tty bank through
   `_FarSh_LogStr`** -- the round trip is the proof that both directions work.

### Nothing zeroes this bank's statics

There is no global BSS clear in FGX, and stage 2 MVNs only the image's real
bytes, so a `DUM` cell in this bank holds whatever the Memory Manager last left
there.  Every owner zeroes its own region before first read.  This is the same
contract the far bank's statics live under and it has cost time before.

---

## 5. How T1 was verified

The build's own gates cover the static half: the ceiling check reads
`bin/fgxtty.bin` and asserts it opens with `KTTY_MAGIC`, `check_far_calls`
rejects a 16-bit call into the table, `check_far_rtl_calls` walks
`src/kernel/tty/`, and both bankpatch directions are `--check`ed against the
fresh listings.

The runtime half was checked by **mutation**, because a boot line that is only
ever read is not a test:

| mutation | expected | observed |
|---|---|---|
| `Tty_Init` derives bank + 1 (second `INC` -> `NOP`, size-preserving) | magic check fails | `tty: bank ABSENT (/KERNELTTY missing or wrong version)` |
| `Tty_BankInit` patches to bank `$00` (`STA` -> `STZ`, size-preserving) | the tty -> core `JSL` goes wild | boot dies, `smoke` **red** |

Both mutations were size-preserving on purpose: this tree has been bitten by a
layout-sensitive fault that every in-place instrument re-rolls.

---

## 6. The first tenant: 2.11BSD's clists

`tty.h`, `clist.h`, `ttychars.h` and `tty_subr.c`, ported from
`vendor/2.11BSD/usr/sys/`; `docs/PROVENANCE.md` carries a row each with the
deltas.  Nine routines plus `cinit`, which upstream keeps in `init_main.c` and
which comes here because it belongs with the pool it builds.

**`struct tty` is carried WHOLE although only `struct clist` has a reader.**
The ruling for this campaign is to adopt BSD's `struct tty` and its queues; a
struct definition emits no bytes, so having it early costs nothing and porting
`tty.c` against a half-shape later would.  `sizeof(struct tty)` is 92 on fcc.

### The three things the port had to decide

**The block size is pinned; the payload gives.**  `CBSIZE` is
`CBLOCK - sizeof(struct cblock *)`, which is 30 on a PDP-11 and **28** here
because a pointer is 4 bytes.  `sizeof(struct cblock)` stays **32** either way,
and that -- not CBSIZE -- is what every `CROUND` mask depends on.  Nothing in
the port writes 28, 30 or 32 as a literal.

**Nothing has to align the pool, because upstream already does.**  `cinit`
rounds the base up to the next `CBLOCK` boundary and starts the chain there,
losing at most one block.  That is upstream's line, unchanged.

**`spltty()`/`splx()` ARE EMPTY, and that is a divergence with an expiry
date.**  Upstream brackets every clist mutation because a device interrupt can
call `putc` while a syscall is inside `getc`.  FGX cannot have that race today:
`FGX_DP_KERNELC` is a singleton register file, so exactly one C context runs at
a time and nothing calls these from an interrupt.  **T6 ends that**, and the
macros exist rather than being deleted so the call sites stay upstream's and
the change lands in one file.

### The CROUND trick survives by a property of THIS BANK

Upstream finds a block's base from any pointer into it with
`(int)bp & ~CROUND`.  On a PDP-11 that is free -- `int` and `char *` are both
16 bits.  Here a pointer is four bytes, so the cast to `int` drops the bank and
the cast back has to invent one.  fcc's rule (`_fcc_bank_for_int`,
apple/fgx#12) stamps **DBR** on any nonzero value, every entry into this bank's
C sets DBR to this bank, and the pool is a global here.  So the bank it invents
is the bank the block is in and the round trip is exact.

**That is a fact about where the pool lives, not about the code.**  Move `cfree`
to the kernel heap -- a different bank -- and all six casts start returning
this bank's offset in the wrong bank, silently, with nothing in the build able
to see it.  It is written at the head of `tty_subr.c` as well as here.

### The witness

`clist_probe.c`, reached from `_ClistProbe` in `main.s` at boot; the smoke gate
asserts `tty: clists ok` and the absence of `CLIST PROBE FAILED`.  The
**contains** is the load-bearing half -- a "lacks" alone passes when the probe
never runs.  Fifty cases, each returning its own number, because a probe that
says only that something broke costs a round trip.

Cases are chosen for where the `CROUND` arithmetic actually decides something.
`putc` n times then `c_cc == n` passes against an implementation that never
allocates a second block and corrupts the free list, so the file asserts the
BLOCK BOUNDARY (CBSIZE and CBSIZE+1) and the FREE COUNT, which is the only
observation that can see a block leaked or freed twice.  Cases that cannot fail
are marked as such where they appear.

**Proven by mutation, three ways, each landing on a different case:**

| mutation | case that fired | |
|---|---|---|
| `cinit` stops rounding the pool base up | **3** | the free chain is no longer block-aligned |
| `putc` never detects a block boundary | **18** | not 16 or 17 -- putc still returns 0 and `c_cc` still counts, so the FREE COUNT is what caught it |
| `catq`'s fast path copies only `c_cc` | **44** | not 42 -- the count arrives, the characters do not.  This is apple/fgx#199's damage, by hand |

Two of the three fired at a case AFTER the first one in their block, and in
both the earlier cases could not fail.  That is the campaign's most repeated
failure and the reason the numbering is per-assertion.

### Three fcc defects the port found

The clist code is 1980s K&R that no FGX port had exercised, and it walked into
three holes -- all filed, all fixed, all with a value-asserting fixture:

* **apple/fgx#199** -- `*to = *from` on a struct through a dereferenced pointer
  copied the **first two bytes**.  `catq`'s fast path does exactly that on a
  10-byte `struct clist`: the count arrived and both queue pointers stayed
  stale.  Silent.
* **apple/fgx#200** -- an array field at the end of a multi-hop `->` run:
  rejected in one reader, and in the other (the dot-bridged one) **silently
  dereferenced** -- the right address computed and then its first byte loaded
  as the pointer.
* **apple/fgx#201** -- subscripting a cast-produced struct pointer had no arm
  and reached the apple/fgx#166 zero-stride guard, which is that guard doing
  precisely what its comment says it is armed for.

A full golden regeneration after all three changed **zero** existing fixtures,
so none of the shapes had any coverage in 592 of them.

## 7. T2.1: the line-discipline switch, and which device is which tty

`conf.h` and `tty_conf.c` ported from `vendor/2.11BSD/`, plus `tty_dev.c`,
which is FGX's own.

**`linesw[]` IS UPSTREAM'S SIZE -- five rows of ten slots -- although FGX fills
one row and seven of its slots.**  The shape is the point: every BSD tty
driver's read is `(*linesw[tp->t_line].l_read)(tp, uio, flag)`, and that only
works if the table is indexed the way upstream indexes it.  `t_line` values are
written by userland ioctl, so a table trimmed to what is filled today would
have to be renumbered the day a discipline arrives.  Rows 1, 3 and 4 are
`nodev` because that is upstream's own `#else` arm when NBK/NTB/NSL are zero.

**Rows 0 and 2 point at `ttyadapt_*`, and that is T2's bargain.**  The real
routines are `tty.c`, which is T3; relocating the 790 lines of core-bank
discipline they replace would be paying twice, because T3 deletes them.  The
adapters have no bodies at T2.1 and each returns its own slot's number, so a
row copied one slot out of line -- the failure ten unnamed function pointers
per row invites -- is a wrong answer rather than a plausible one.  T2.2 gives
them bodies; T3 repoints the rows and deletes the file's adapters.

### `tty_dev.c` is FGX's, and it is `cdevsw[].d_ttys`

BSD finds a driver's `struct tty *` with
`&cdevsw[major(dev)].d_ttys[minor(dev)]`.  FGX has one major and a runtime
registry, so the same fact lives in the registry entry's `CD_TtyOff` -- written
at registration by the code that knows.  `tty_find(dev)` reads it rather than
hard-coding device indices, because registration order has changed twice and a
remembered index goes wrong silently.

**The division stays in assembly.**  `_Chardev_TtyIdx` turns the stored byte
offset into a tty index, so kernel C never restates `TTY_SIZE` -- a stride a
`DUM` block computes, and therefore a copy that goes wrong the first time a
field is added to `_ttyTable`.  It also adds the bounds check
`_Chardev_TtyOff` lacks: that routine's in-kernel callers pass indices they
just looked up, and a caller in another bank is exactly the one that might not.

### The witness, and the arm that could not fail

`tty_probe.c`, 41 cases, asserted by smoke as `tty: linesw ok`.

| mutation | case | |
|---|---|---|
| row 0 shifted one slot | **20** | the failure the layout invites |
| the bounds check deleted | **9** | see below |
| `tty_find` answers `&ttys[0]` for everything | **4** | not 6 -- resolving to the wrong tty is the same defect one step earlier, so case 6 is subsumed and says so |

**THE BOUNDS-CHECK CASE WAS GREEN AT FIRST, AND THAT WAS THE FINDING.**  It
asserted `tty_find(CHARDEV_MAX) == NULL`, and deleting the check left it
passing: reading one entry past the 384-byte registry answered heap bytes that
did not look like a tty, so refusing and reading-whatever-was-there produced
the same answer.  `kc_cdttyidx` now returns **-2 for "no such device"** and -1
for "not a tty", and the case asserts the REFUSAL rather than its usual
consequence.  `tty_find` still collapses both, because a driver has nothing
different to do with them -- only the probe does.

### The selector wake is unconditional, and BSD is why

**`ttwakeup` and `ttyowake` drop upstream's `if (tp->t_rsel)` / `if
(tp->t_wsel)` guards.**  This is the one place T3 knowingly departs from
upstream's text, so it is argued here rather than left in a comment.

Upstream records the selecting proc on the tty and hands it to `selwakeup`,
which wakes that one task.  **FGX's `select(2)` records itself on nothing.**
`_Sys_Select` is a poll-and-rescan loop whose block-forever arm sleeps on the
single `WCHAN_SELECT`; there is no per-tty slot to write and no proc to name.
So with the guards in place both calls are dead code: a tty could never wake
its own selector, and a select blocked on a pty or serial line would move only
on the 60 Hz idle re-scan in `sched.s`.

**Dropping them is upstream's own fallback, not an invention.**
`selwakeup(p, coll)` broadcasts and forces a rescan whenever it cannot target
one proc:

```c
	if (coll) {
		nselcoll++;
		wakeup((caddr_t)&selwait);
	}
```

`coll` comes from `TS_RCOLL`, which `ttyselect` sets when a SECOND task selects
on a tty that already has one recorded -- one slot, two selectors.  FGX has one
channel and no slot at all, which is that collision case permanently.

**The registration never carried readiness in the first place.**  BSD's select
is itself a poll-and-retry loop: after `tsleep(&selwait, ...)` it does `goto
retry` and calls `selscan` again, which calls `ttselect` again, which calls
`ttnread` again.  `t_rsel` is written by `ttyselect` and read only by
`selwakeup`.  Nothing in the readiness path consults it, so a port that cannot
register loses an optimisation and not an answer.

**It is not a wakeup storm.**  `_FarSh_SelWakeup` tests `_nSelSleepers` and
returns, so with nobody selecting the whole thing costs an `LDA` and a `BEQ` --
the same guard `sched.s` uses at its own wake sites.

`ttyflush` was already spelled this way, because upstream is too: its
`selwakeup` call carries no `if`, the NULL test living inside `selwakeup`.  The
change makes all three call sites agree.

**What FGX gives up:** a targeted wake.  Every ready tty wakes every blocked
selector, and each rescans.  With one channel that is the honest cost of not
registering, and it is bounded by `_nSelSleepers` being zero in the common case.

**What would end the divergence:** a `u.u_procp` equivalent reachable from this
bank, at which point `t_rsel` can be written and the guards come back with
upstream's meaning intact.  Nothing needs it before then.

### The probes are behind a flag, and the gate builds a kernel for them

`kernel.ttyprobe` (cfg/system.cfg), default **0**.  `clist_probe` and
`tty_probe` are ~34 KB of a 65 KB bank -- `tty_probe`'s body alone is 29,898 B,
more than `tty.c` itself -- and they stopped fitting beside the code they test.

**The alternative was retiring probe clusters one increment at a time**, and two
of those cost 5 KB of coverage to land 1.8 KB of code: the echo cluster
(`ttyout`, `ttyecho`, `ttbreakc`, `ttyrubo`, `nullmodem`) and `ttyflush`'s own
cases, after which `nullmodem` ships untested and `ttylclose` landed with no
witness.  Every one of those was an irreversible decision taken under bank
pressure rather than on the merits.

**This is not `kernel.ufsprobe`'s kind of off.**  That gate must stay 0 because
its probe WRITES to a disk on the boot path.  Nothing here is unsafe to run;
the flag exists so the shipping kernel does not carry test code.

**The gate runs it, and that is what makes defaulting to 0 honest.**  The bank's
C has no other witness -- all thirty-one routines whose only caller until T4's
`linesw` repoint is `tty_probe` -- so `tools/gate.sh` builds a probe kernel and
boots it as a step of its own.  A `requires` on the test manifest would have
SKIPPED when the flag was off, and a skip that reads as a pass is exactly the
failure `cfg/system.cfg`'s `kcprobe` comment already warns about.

Both verdicts are asserted PRESENT rather than the absence of a FAILED line: a
`lacks CLIST PROBE FAILED` passes when the probe never ran, and after this split
that is the likely failure.  Measured: with the probe built but its call site
removed, the gate goes red.

**Export slots 3 and 4 exist either way.**  A slot's address is its identity, so
dropping them would renumber every slot above and silently repoint the core's
calls.  Gated out they take the red-border halt an unassigned slot takes.

## 8. What comes next

T2.1 is the switch.  **T2.2 is the cdevsw op ABI** -- `d_open(dev, flag,
mode)`, `d_read(dev, uio, flag)`, `d_write`, `d_ioctl`, `d_select` across all
eight vtables, with `l_read`/`l_write` becoming adapters that unpack a uio into
today's per-byte loop.  That is what closes apple/fgx#198 and unblocks UFS
1.7d's I4.

**The uio-in-assembly question is decided (the maintainer, 2026-08-22):** the tty
chardevs move into this bank first, then the ops take a uio verbatim.  BSD's
drivers can afford `d_read(dev, uio, flag)` because they call `uiomove`; FGX's
`uiomove` is in vfs.mod, so a core-bank driver taking a uio would put the
kernel's own device ABI behind a loadable module.  Moving the drivers here
first means the uio helper sits beside them and the core bank gets headroom
back instead of spending its last 1,285 bytes.

Then `tty.c` itself (T3), where `ttyinput`, the assembly `putc` into `t_rawq`
and the permanently-set `PENDIN` land.  The increments and their order are in
the survey's section 9 and in apple/fgx#108.

## 9. The "u-area seam": who owns the job-control predicate

The handoffs called the next increment "the u-area seam".  That name is
borrowed from BSD's spelling and it is wrong twice over, which matters because
the name was shaping the design.

**Of the five things `tty.c` reaches for through `u`, exactly ONE lives in
FGX's u-area.**  The rest live in three other homes:

| BSD spelling | FGX home |
|---|---|
| `u.u_procp->p_pgrp` | `SE_PGroup`, the sched entry |
| `u.u_ttyp` / `u.u_ttyd` | a ctty index packed into `SE_Flags` (`SEF_CTTY_MASK`), read by `_Se_CurCtty`, written by `_Se_SetCtty` |
| `p_flag & SVFORK` | `SE_Flags & SEF_VFORKCHILD` |
| `p_sigignore`, `p_sigmask` | the sigHnd tables, via `_SigUserBitY` |
| `p_sig` | `TCB_PendingSig`, in the TCB |
| `u.u_uid` | `U_Uid` -- the u-area proper (`include/kernel.s`) |

So there is no single seam to build.  There is a question about WHERE THE
PREDICATE LIVES, and BSD answers it.

### What BSD says

**Every SIGTTIN/SIGTTOU background gate in both trees is in the tty layer.**
Not one is in the syscall layer, and not one is in the signal code:

    2.11BSD    sys/tty.c:335 (ttioctl), :1158 (ttread), :1350 (ttwrite)
               sys/tty_pty.c:112       (the pty slave's own copy)
    4.3BSD-Reno kern/tty.c:259, :1211, :1387
               kern/tty_pty.c:134

`kern_sig.c` mentions the two signals only in `ttystopsigmask` (Reno
`kern/kern_sig.c:46`) and in the stop-default arms at `:596` and `:691` -- that
is DELIVERY semantics, what raising the signal does.  The division is clean and
both trees keep it: **the tty layer decides when to raise it; the signal layer
decides what raising it does.**

**Reno factors the predicate and puts the factoring in the tty layer's own
header** (`sys/tty.h:133-141`):

    /* Is tp controlling terminal for p */
    #define isctty(p, tp)   ((p)->p_session == (tp)->t_session && \
                             (p)->p_flag&SCTTY)
    /* Is p in background of tp */
    #define isbackground(p, tp)     (isctty((p), (tp)) && \
                                    (p)->p_pgrp != (tp)->t_pgrp)

**And it takes the proc as an ARGUMENT.**  `isbackground(u.u_procp, tp)` --
the predicate is HANDED an identity; it does not reach a global itself.  The
`u.u_procp` appears at the call site, in `tty.c`.  That is the shape a
cross-bank shim can serve, and it is why the accessor question and the
ownership question have different answers.

### What that settles, and what it does not

**The background-stop predicate belongs in `tty.c`.**  FGX has it in
`signal.s` (`_Tty_BgWriteGate`, exported `ENT`, = `tty.c:1348-1355`) and inline
in `_Sys_Read` (`syscall.s:5137`, = `tty.c:1157-1162`) -- placements both trees
reject.  Neither is a mistake: `_Tty_BgWriteGate`'s own header says so, "FGX
has no shared tty write yet (apple/fgx#108 is the campaign to build one) ...
When #108 lands, this moves into the shared path unchanged."  That is this
campaign, and this is the move.

Calling the core predicate from the bank through a shim is therefore the one
option BSD argues against: it would leave the policy in the signal layer
permanently.  The fields come across as accessors and the conjunction is
transcribed from 2.11BSD, which is the porting source; Reno's `isbackground`
corroborates the OWNERSHIP without being the thing transcribed.

**`ttyopen`'s session acquisition is the exception, and for an FGX-specific
reason.**  `_Se_TtyOpen` (`ttyv.s:470`) is `tty.c:653-659` with one addition:
it acts on `_kCttyTarget` when a spawn is applying file actions, and on
`_curTask` otherwise, because **init opens the device inside the CHILD**.  BSD
has no equivalent -- its `ttyopen` is implicitly `u.u_procp` and cannot be
anything else -- so a verbatim port would silently put the shell's line under
init's process group, which is the defect `_Se_TtyOpen`'s header records.  That
block calls one shim; the core bank keeps owning WHICH process, because it is
the only layer that knows.

### Sequencing, and why the seam is not tested when it lands

`main.s:737` already states the limit: the probe runs at boot, and boot has no
current process for this code -- `Task_AllocUarea` builds INIT's u-area, not
one the probe runs as.  `_curTask` is nonzero (`main.s:495`), so a shim's
plumbing can be witnessed; the arms that matter -- background pgrp mismatch,
TOSTOP armed, SIGTTOU ignored or blocked -- cannot be reached from boot.

The first honest witness is the existing userland suite after `linesw[0]`
repoints.  So the core copies stay live and tested until then and are retired
after, rather than deleted ahead of a replacement that nothing can exercise.

### What landed on this reading

`ttyopen` (2.11BSD `usr/sys/sys/tty.c:646`), and with it the shape the rest
follows.  `_Se_TtyOpen` was SPLIT: `_Se_TtyOpenPg` takes the line's `t_pgrp` in
and hands it back out, so the core routine no longer reads
`_ttyTable+TTY_FgPgrp` on a caller's behalf and the two banks' `struct tty`
copies cannot drift apart through it.  `kc_ttyopen(idx, pgrp)` is the one call,
over `_FarSh_SeTtyOpen`.

**The probe opens a NON-TTY device in every case, deliberately.**  `ttyopen`'s
session block mutates live process state -- it binds a ctty and a process group
to whichever task the core says the open is for, and at probe time that task is
BOOT, whose `SE_PGroup` and ctty bits `posix_spawn` hands down to init and to
everything after it.  A probe that opened a real line would be the inverse of
the defect the probe split found: not a probe that INITIALISES, but one that
MUTATES.  So the witnessed part is `t_dev`, `TS_WOPEN`/`TS_ISOPEN`, the window
size, the `NTTYDISC` flush arm and the not-a-tty guard -- cases 350-366, each
mutation-checked: dropping the `bzero` goes red at 354, forcing the `TS_ISOPEN`
guard true at 365, inverting the `NTTYDISC` test at 360, and removing the
`idx >= 0` guard at 358.

`bzero` is now real in the bank (`tty_dev.c`).  It is in FGX's own file rather
than a ported one because upstream's is machine-dependent assembly outside the
tree this campaign ports from, and a function upstream does not have, added to
a file whose provenance row names `usr/sys/sys`, is exactly the drift
`check_provenance.py` exists to catch.

### `lbolt`, and `ttwrite` on the accessor shape

Both landed.  What follows is the record of why `lbolt` looks the way it does.

**`ttwrite` needed one thing FGX has never had: `lbolt`.**
`h/kernel.h:32` -- "awoken once a second" -- woken by `wakeup((caddr_t)&lbolt)`
as the FIRST line of `schedcpu` (`kern_synch.c:36`).  It is the channel BSD
sleeps on to mean "wait a bit and retry", and `ttwrite` uses it three times.
FGX's `WCHAN_*` block has the right shape and `$FF07` is free, but nothing in
this kernel is woken once a second: the idle loop's 60 Hz re-poll only runs
when NOTHING is runnable, so a writer waiting on it would never wake while
another task ran.  That made it a scheduler-adjacent change with its own
reasoning and its own witness, not something to smuggle into a tty increment --
`_Tty_BgWriteGate`'s header has said "FGX has no lbolt" all along.

**The reading that decided it: BSD wakes lbolt from the CLOCK, not from the
scheduler.**  Three placements were on the table -- `swtch` gated on a tick
counter, the `_kYieldReq` syscall-boundary hook, or the idle loop alone -- and
all three answer "where", which is the wrong question.  `schedcpu` is a
self-re-arming callout (`timeout(schedcpu, (caddr_t)0, hz)`, `kern_synch.c:72`,
started once at `init_main.c:203`) whose first line is the wake, so it fires
whether or not anything is runnable and whether or not anyone makes a syscall.
And `hardclock` does not perform it: it sets `needsoft` and defers
(`kern_clock.c:142`), because a callout may call `wakeup()`, which is not safe
at clock priority.

FGX has the same constraint for a different reason -- the heartbeat runs on the
interrupted task's direct page, so it cannot reach `_schedTblPtr` -- and it
already had the machinery, in `_Tty_DrainSigPend`: a flag the heartbeat sets,
drained at `_Sys_CheckSignal` (`signal.s`) and at `swtch`'s idle arm
(`sched.s`).  Between them they cover both cases, which is why the syscall-hook
and idle-loop options were each half of the answer.  `_kLboltDue` and
`_Lbolt_Wake` reuse exactly that pattern.

**The weaker guarantee, stated.**  `kern_synch.c:71` writes `++runrun;  /*
swtch at least once a second */` on the line before the callout re-arms, forcing
every runnable process through the scheduler each second.  FGX cannot -- Model A
preemption never preempts kernel code -- so a CPU-bound task issuing no syscall
delays an `lbolt` sleeper.  That is FGX's existing preemption divergence rather
than a new one, and it is survivable for the reason it is upstream: every
`lbolt` sleeper re-tests its condition and loops.

**`_Lbolt_Wake` returns the carry**, and that is what makes its guard testable.
Asserting the flag twice cannot separate a correct routine from one whose `BEQ`
has been deleted -- the unconditional version `STZ`s it too, so both leave it
clear.  Only "did `_wakeup` run" distinguishes them, and a branch that already
knows costs one `SEC`/`CLC` to say so, where a counter would have been kernel
data existing to be asserted.

**`ttwrite` carried the background gate across as C**, over `kc_curpgrp`,
`kc_curctty`, `kc_isvforked` and `kc_sigopted` -- the shape section 9 argued
for.  Two things about it are worth knowing:

- **`tp == u.u_ttyp` becomes an INDEX compare.**  Upstream compares pointers
  because `u_ttyp` is a `struct tty *`; FGX keeps the controlling terminal as an
  index packed into `SE_Flags`, so there is no pointer identity to compare.
- **The conjunction keeps UPSTREAM's order, not `_Tty_BgWriteGate`'s.**  That
  routine deliberately leads with `LTOSTOP` because the flag is usually off and
  it saves a pgroup lookup; the same reordering is available in the C and was
  NOT taken, because every term is now a cross-bank call and the
  cheap-test-first argument would have to be re-measured rather than inherited.
- **FGX now does sleep-and-retry here**, which the core path could not: that
  path returns EINTR because "FGX has no lbolt and its callers are per-byte
  loops with no restart point", and both halves of that are now gone.

`scanc` joined `bzero` in `tty_dev.c`, but from a different place and it
matters: 2.11BSD's is PDP-11 assembly (`machine/mch_xxx.s`), while 4.3BSD-Reno
carries a portable C version at `ufs/ufs_subr.c:160` under `#if !defined(vax)
&& !defined(tahoe) && !defined(hp300)`, headed *"C definitions of special
instructions"* -- which is exactly the case a 65816 is in.  So it is upstream's
own C for a non-VAX rather than a local reimplementation.  `bzero` has no such
version in either tree, which is why that one is hand-written.

**The probe drives `scanc` directly**, because through `ttwrite` the two arms it
selects are observationally IDENTICAL for ordinary text -- a `scanc` that called
everything special would send each byte through `ttyoutput`, which queues
ordinary characters and advances `t_col` exactly as the bulk path does.  The
split is a performance choice upstream, so only the primitive can witness it.

Cases 370-387, and no case may reach `kc_lbolt` or `kc_sleep`: both block, and a
probe that blocks at boot hangs the machine before the console exists -- the
apple/fgx#218 signature.  Case 378 is the exception worth naming: it arms every
term of the background gate and asserts the write goes through, so if the
neutral no-session answers were ever wrong it would HANG rather than fail.  A
timeout there is that case's failure, not a flake.

## 10. The cutover: what is left of T3, and the order it can move in

`tty.c` is closed and **nothing calls `linesw[]`**.  The bank is dead code: the
live discipline is still `syscall.s`'s `TTY_CanonBuf` gather, `_Tty_GetByte`,
`_Tty_EchoByte`, `_Tty_BgWriteGate` and `_IoOp_Tty`.  This section is the plan
for making the bank live, written before the change rather than after it.

**IT IS T3, NOT T4.**  apple/fgx#108's own increment list (the maintainer, 2026-08-22)
reads: "**T3** `tty.c` plus the assembly `putc` and permanent `PENDIN`;
`linesw[0]` repoints and the core discipline is deleted -- **this is the
increment that closes this issue**.  **T4** `tty_pty.c` into pty.mod."  Two
handoffs in a row called the cutover T4's.  It is not; T4 is a different
increment that comes after.

### It is a deletion, not a migration, and that is the measurement that matters

`_ttyTable` looks like 100 reference sites across seven files.  Grouped by the
routine that contains them, syscall.s's thirty-three are:

    ~20 in @si_*   the arms of _IoOp_Tty       -- ttioctl replaces them whole
    ~10 in @rd_*   the arms of the read path   -- ttread replaces them whole

**They die with the code; they do not need accessors.**  What survives the
deletion is small and enumerable.  Counted per field, the sites OUTSIDE the
code that dies are:

    TTY_FgPgrp   4 writers (ttyv.s x3, pty.mod x2), 5 readers
                 (signal.s x3, toolbox.s, ttyv.s, pipe.s)
    TTY_SgFlags  ttyv.s x3, pty.mod x2, toolbox.s, pty.s
    TTY_Lmode    signal.s x2 (LTOSTOP), pty.s
    TTY_WinRow   pty.mod, pty.s

Four fields, not a table.  `far_shims.s:500` already anticipates this in a
comment: "reads `_ttyTable+TTY_FgPgrp`, and `_ttyTable` is what T3 deletes."

### BSD keeps `t_pgrp` in the tty and everyone reaches it through the pointer

Checked rather than assumed.  Outside `tty.c`, 2.11BSD reads `t_pgrp` in four
places only: `kern_sysctl.c:949` (`e_tpgid`, a stats field), `sys_inode.c:715`
(`gsignal(u.u_ttyp->t_pgrp, SIGHUP)`), and `tty_pty.c:111`.  There is no
per-process mirror of the foreground group anywhere -- the tty owns it and
callers hold a `struct tty *`.  `usr/sys/h/tty.h:64` is the declaration.

So FGX's `_ttyTable+TTY_FgPgrp` and `ttys[i].t_pgrp` are the same field in two
banks, and the port's job is to delete one of them.  The only FGX-specific cost
is the bank crossing.

### The accessors must be ASSEMBLY, and the survey already said why

`toolbox.s`'s heartbeat reads the foreground group at 60 Hz **at interrupt
time**, and `include/kernelc.s:342` makes kernel C a singleton: a second C
context live at once shares the register file and corrupts it.  So the four
surviving fields get **assembly** export slots in this bank -- `PHB/PHK/PLB`,
an indexed load or store, `PLB/RTL`, no C -- which is the same shape the
campaign already plans for the input `putc`.

### The offsets are GENERATED and PINNED, never baked

`struct tty` is laid out by fcc, so an assembly accessor that spells `t_pgrp`
as a literal is a baked address of the kind `check_baked_addrs.py` exists to
catch.  The tree already has the pattern: `tools/gen_vfs_equ.py` derives its
EQUs from the C header, and the struct sizes it cannot derive are pinned by an
on-machine assertion in `toolchain/tests/M37/vfslayout.c`.  The tty offsets
follow it exactly -- generated from `tty.h`, and asserted on the machine by a
probe case, so a layout change fails loudly instead of moving the wrong bytes.

### The order, and why this order

Each stage boots and gates green on its own; they land together in one MR.

1. **The shared-state seam.**  The four surviving fields get one home in
   `ttys[]`, reached by generated-offset assembly accessors.  `_ttyTable`'s
   copies of them go.  No discipline moves, so the witness is the existing
   userland job-control suite -- `tostop`, `contostop`, `pgrptest`, `killpg0`,
   `orphstop`, `sessdet`, `vcclose`, `winsz`.
2. **The ioctl.**  `_IoOp_Tty`'s arms give way to `ttioctl`, which is already
   ported, probed and green.  This is the cheapest real cutover and it proves
   the seam before either I/O path moves.  Witness: `stty`, `sgtty`, `tctest`,
   `tchtest`, `winsz`, `ttysprobe`.
3. **The write side.**  A `t_oproc` per line, `l_write` repoints at `ttwrite`,
   and `@sw_console`, `@sw_chardev`'s loop and `_Tty_BgWriteGate` go.
4. **The input side.**  The assembly `putc` into `t_rawq`, `PENDIN` permanently
   set, `l_read` at `ttread` and `l_rint` at `ttyinput`; `TTY_CanonBuf`,
   `_Tty_GetByte` and the echo trio go.
5. **Retire `tty_probe`.**  22,987 B, 40% of the bank and more than `tty.c`
   itself, once the userland suite is the witness.  Closes apple/fgx#108.

**Why the state moves first.**  `ttwrite`'s background gate reads
`tp->t_pgrp` while the old read path reads `TTY_FgPgrp`.  Cut either I/O path
over before the fields have one home and the two disciplines disagree about
who is in the foreground -- which is exactly the "job control desynchronises on
the console" this campaign has been warning itself about.  With stage 1 done
the warning stops applying, and the rest can move a side at a time.

### Stage 1c: the migration inventory, measured

Stage 1a pinned the offsets and 1b built the slots.  1c moves every caller and
deletes `_ttyTable`'s copies -- and it has one hard constraint:

**IT IS ONE COMMIT, BECAUSE A PARTIAL MIGRATION IS TWO TRUTHS.**  While some
sites read `ttys[].t_pgrp` and others read `_ttyTable+TTY_FgPgrp`, the two
disciplines disagree about who is in the foreground.  Migrate every site and
delete the field together, or do not start.

`_Se_TtyOffToIdx` (`ttyv.s:384`) is the converter: A = byte offset -> A = index.
Every site below holds an OFFSET, in X or Y; the slots take an INDEX.

    ttyv.s:138   @tc_haveX      STZ ,X   X is #TTY_SIZE*3 or *4, and is still
                                         needed after for CanonLen/CanonPos
    ttyv.s:318   _Con_Close     STZ      tty[0], no index at all
    ttyv.s:595   _Se_TtyOpen    LDA ,X   } one routine; see the note below
    ttyv.s:603   _Se_TtyOpen    STA ,X   }
    signal.s:315 _Tty_DeliverSig LDA ,X  entry A IS the index, before the
                                         multiply that makes X
    signal.s:578 @tcf_muld      CMP ,Y   needs a temp: the compare is against
                                         a value the accessor's A would clobber
    signal.s:1227 @bwg_armed    CMP ,X   same shape
    toolbox.s:613 @hb_sigHaveTty LDA ,X  INTERRUPT TIME -- assembly only
    syscall.s:3465/3472/3628             die at stage 2, but must move now
    pipe.s:813, pty.s:1392/1420          MODULES

**The two modules cannot call the tty bank.**  `gen_kernel_exports.py` hands
out CORE addresses, so `_Tty_PgrpOf` / `_Tty_SetPgrp` core wrappers are needed
and belong beside `_Se_TtyOffToIdx`.  They also save twelve rows in
`src/kernel/tty_patchsites.s` -- one `_ktp` marker per wrapper instead of one
per call site.

Two hazards found while drafting it, both cheap to hit:

- **`_Se_TtyOpenPg` takes an INDEX, not an offset, and preserves X**
  (`ttyv.s`'s own header says so).  `_Se_TtyOpen` already converts; the rewrite
  keeps the index on the stack across the call and reuses it for the store.
- **`PLX` sets Z from X, not from A.**  Several of these sites read the group
  and immediately `BEQ` on "no foreground group".  Restoring a register after
  the accessor and branching on the old flags tests the wrong thing -- use an
  explicit `CMP #0`.

### Stage 1c, attempted 2026-08-24: reverted, and what it established

The migration was written, built and measured, then **reverted** rather than
committed half-working.  It is recorded here because most of it was right and
the parts that were wrong are not obvious.

**THE WITNESS IS NOT IN THE GATE.**  `tools/gate.sh`'s 37 tests contain no job
control at all.  The suite that matters is nine tests run by hand, and its
BASELINE WAS MEASURED AT 9/9 before touching anything -- which is the only
reason the first result (0/9) could be read as a regression rather than as
tests that were already red:

    python3 tools/mame_test/run.py tostop contostop pgrptest killpg0 \
        orphstop sessdet vcclose winsz conctty --fresh

**THE ACCESSORS MUST BE REGISTER-TRANSPARENT, and this is the finding.**
`LDA _ttyTable+TTY_FgPgrp,X` clobbers no register; `JSR _Tty_PgrpOf` clobbers X
and Y, and the slot behind it clobbers them again.  `syscall.s`'s tty read gate
never touched X, so `@rd_disc` ran the read with a foreign X.

What makes it worth writing down is how it presented.  Every symptom said the
COMPARISON was wrong: the shell could not read, bypassing the gate fixed it,
and hardcoding the console index did not.  Logging both operands printed
`line=8 reader=8` -- equal -- and logging the background decision printed
NOTHING AT ALL, because the gate never once chose background.  The gate was
correct the whole time and the damage was entirely in the registers it no
longer preserved.  A store accessor must preserve A as well, so that it is a
drop-in for the `STZ` it replaces.

**Two more things the attempt settled**, both by measurement:

- `tools/mame_test/vcclose_check.py` reads `tty[4].TTY_FgPgrp` at an offset
  into `_ttyTable`.  Deleting that field makes the check read a neighbour and
  report a plausible pgid, so it MUST be repointed at the tty bank in the same
  commit or it fails by construction.
- `_TtyStateProbe` leaves its scratch cells non-zero, so borrowing
  `_ttyStIdx` as a once-only debug flag silently suppresses the output.  That
  cost a whole cycle producing an empty log that read as "the branch is never
  taken".

**What was still failing when it was reverted, AND WHY -- FOUND.**  With the
accessors made register-transparent, seven of ten recovered; `tostop` and
`winsz` did not.  The discriminator is not in the kernel at all, and one grep
finds it:

    pgrptest killpg0 orphstop sessdet   open no tty device
    vcclose conctty contostop           /dev/console, /dev/tty, /dev/ttyv2
    winsz                               /dev/ptyp0        <-- FAILED
    tostop                              /dev/ptyp1        <-- FAILED

**They are the only two of the nine that open a pty MASTER, so they are the
only two that run pty.mod's foreground-group writes** -- `_Pty_SlaveTtyInit`
(`pty.s:1420`) and `_Pty_MaybeReset` (`pty.s:1392`), the two migrated sites that
live IN A MODULE.

The attempt gave those a core-bank entry through `gen_kernel_exports.py` and
called it with `JSL _Tty_KCall_SetPgrp`.  **That is not how a module reaches the
core bank.**  The exported EQU carries the ASSEMBLY-time bank `$02`, and the
kernel does not run there; `net.s:91` records the same thing having been fixed
once already, "relocated from baked-$02 `JSL _Net_KCall_*`", because "net loads
to a dynamic bank, so cross-bank kernel calls must go through the fixed bank-0
gateway".  pty.mod's own convention is the other one: `LDX #KSVC_* / JSL
SYS_KCALL` (`pty.s:200`, `:338`), the multiplexed service slot, which
`pty.s:38` notes "costs no bank-0 cell".

So the module half of stage 1c needs a **KSVC service number** appended to
`include/modules.s` (that list is marked APPEND ONLY -- "NOTHING WILL CATCH A
RENUMBER") and an arm in `_Sys_KCallImpl` (`jumptable.s:334`), not an exported
address.  Only a SET is needed for pty.mod: both sites are `STZ`.  `pipe.s:813`
in net.mod is a READ and must use net's own gateway convention.

Eliminated before that was found, so they need not be re-tested: the SIGWINCH
in `@si_swSet` (skipping it changes nothing), the `_ttyTable` layout shift from
deleting the field (tested with a two-byte pad holding the old offsets), and the
offset->index conversion (a hardcoded console index fails identically).

**A correction to this file's own first draft.**  It said the kernel log ring
showed "a runaway loop repeating one truncated entry".  That was an
over-reading of an UNVALIDATED decode.  A positive control was taken
afterwards: a healthy ring contains readable log lines and **zero** zero-bytes
(`dev 01: s7d2 blk=$0080.fs: /FGX on s7d1.INODEPROBE: PASS...`).  The failing
run's ring was one repeated character and mostly zeros -- which says the ring or
its pointer was CORRUPT, not that a loop was writing to it.  Decode a ring from
a passing run before reading anything into one from a failing run.


### Stage 1c LANDED (`c6aef66fa`)

`_ttyTable+TTY_FgPgrp` is gone; `ttys[].t_pgrp` is the only copy.  What the
second attempt did differently, in three lines:

- **The accessors preserve registers.**  `_Tty_PgrpOf` keeps X and Y,
  `_Tty_SetPgrp` keeps A as well, and every caller that branches on "no
  foreground group" spells `CMP #0`.
- **The modules go through `SYS_KCALL`.**  `KSVC_TTYPGRP` / `KSVC_TTYSETPGRP`,
  appended to `include/modules.s` with arms in `_Sys_KCallImpl`; the group
  travels in Y because X is the service number.
- **Three sites needed no bracket and one no conversion.**  `toolbox.s` already
  carries the index in Y's high byte, and the read gate restores X from
  `_Sys_RdBufOff`, the static the dispatcher loaded it from.

The harness learned the tty bank: `run.py` has a `ttybank` region kind resolved
against `build/fgxtty_Output.txt` and placed at kernel bank + 2, and
`vcclose_check.py` resolves stride/offset/NTTY instead of hardcoding them.

**Witness, and it is not the gate**: the nine job-control tests plus smoke,
9/9 baseline before and 10/10 after, with `vcclose` measured red under a
mutation that stops `_Ttyv_Close` clearing the group.

Next: stage 2, the ioctl.  `ttioctl` is already ported, probed and green, and
`_IoOp_Tty`'s twenty `@si_*` arms are what it replaces -- which also gives the
core bank back the room stage 1 spent (283 free).


### Stage 2a: the call seam, and the gate nobody had noticed

Stage 2 splits.  This is the first half: `ttioctl` gets a caller, and the
routing that lets an unlisted command reach it.  No `struct tty` field moves
yet, so no field has two homes and the "one commit or do not start" rule that
governed 1c does not bind here.

**The seam.**  Export slot 12 (`KTTY_KC_TTIOCTL`) is `kc_ttioctl` in
`tty_dev.c`, which bounds- and bound-checks the index and calls `ttioctl`.
`_IoOp_Tty` keeps the three commands that are FGX's own -- TIOCISCONS and
FIODGNAME have no 2.11BSD counterpart, and TIOCNOTTY is pure process state that
upstream answers in `tty_tty.c:58` before any dispatch -- and hands everything
else to `_Tty_Ioctl` (`ttyv.s`).  That is upstream's own order:
`tty_pty.c:508-527` takes the driver's commands first and falls through to
`ttioctl(tp, cmd, data, flag)` for the rest.

**THE ARGUMENTS ARE STAGED ON THE STACK, and that is forced.**
`KTTY_KC_ENTER` points DBR at the tty bank and D at `FGX_DP_KERNELC`, so after
it neither `_Sys_IoctlCmd` (kernel bank) nor `_libcTmp2` (kernel direct page)
can be read at all -- and the pushes cannot precede the bracket, because its
three saved bytes would then sit between the arguments and the callee's frame.
Stack-relative addressing is the only mode that survives both switches, so the
four values are pushed first and re-read at `n,S` after, with every offset a
running total that each push moves.  `probe_dev.s:234` uses the same idiom.
This is also the first time kernel C is entered from a SYSCALL rather than from
boot; fcc's stack guard is compiled out in this bank, so it does not gate it.

**THE FINDING, and it is the reason stage 2 is not just "wire it up".**
`_IoOp_Chardev` carried a HAND-MAINTAINED ALLOW-LIST of tty commands -- twenty
`CMP`/`BEQ` pairs -- and THAT, not `_IoOp_Tty`, decided what reached the tty
dispatch.  Since apple/fgx#121 gave the console a node, every tty descriptor
INCLUDING fd 0 is a chardev fd, so `_kOpsConsole`'s direct route to `_IoOp_Tty`
no longer occurs in practice and the list is the only door.  A correct, green,
fully wired seam behind it is dead code.

The list had already drifted once and says so in its own comment: the sgtty
local-mode family had real per-tty state from 2026-07-27 but was missing here,
so those calls worked on the console and answered ENOTTY on a pty slave or a
virtual console.  With `ttioctl` behind the seam the command set is open ended,
so a parallel enumeration of "which commands are tty commands" is a defect with
a date on it.

**The replacement is a fall-through, not another entry.**  `@si_cdGo` now runs
the device's own ioctl op first and, ONLY on ENOTTY, asks `_Chardev_TtyOff`
whether this chardev is a tty line and retries against the discipline.  Any
other errno is a real answer and is not retried -- a pty master's EBUSY is not
an invitation to ask the line.  `_Chardev_TtyOff` is the right authority
because it already solves the sentinel problem the list works around: it stores
the offset PLUS ONE, so 0 means "not a tty" and tty[0] -- the console -- round
trips correctly, which is the exact ambiguity `contostop` was written for.
Masters record no offset, so the master's ioctl surface does not widen.

**Witness**: `ttiocsm`, which drives all three of `ttioctl`'s return paths
because the core maps each differently -- 0 handled (TIOCGETD, and the VALUE
must be OTTYDISC, seeded to `0x5A5A` first so a seam that writes nothing cannot
pass), a positive errno (TIOCSETD of discipline 99 against `nldisp` 5 is
ENXIO), and -1 (an unassigned command still answers ENOTTY).  The ENXIO case
discriminates hardest: that value can only be chosen INSIDE the tty bank, so
reading it back proves a result travelled the return path rather than that the
call returned.

**Cost so far: 129 bytes of core bank** (57,685 -> 57,814, 154 free), which is
the tightest this kernel has been.  Stage 2a only ADDS -- the payback is 2b-2e,
where the fourteen `@si_*` arms die.

Next: 2b, the tchars/ltchars family, which is the smallest field migration --
`_Tty_CookedDefaults` drops nine stores in favour of `ttychars()` (already
ported, `tty.c:223`, with `ttydefaults` at :216 matching the core's values for
all fourteen characters), and the only reader outside the dying arms is
pty.mod's `@mw_disc`, which needs a KSVC because a module cannot JSL a
`gen_kernel_exports.py` address.


### Stage 2b: the special characters

The first field migration, and the smallest: `t_chars`.  Four arms die
(TIOCGETC/SETC/GLTC/SLTC), `_ttyTable`'s 12-byte tchars image and 6-byte
ltchars image are deleted, and `ttys[].t_chars` -- one 14-byte `struct
ttychars`, upstream's own -- is the only copy.

**The defaults stopped being a transcription.**  `_Tty_CookedDefaults` made
nine stores of literal control characters; it now calls `ttychars()`, which is
`tp->t_chars = ttydefaults` (`tty.c:216-227`).  All fourteen values were
compared before the switch, not assumed: CERASE 0177, CKILL ^U, CINTR ^C,
CQUIT 034, CSTART ^Q, CSTOP ^S, CEOF ^D, CSUSP ^Z, CDSUSP ^Y, CRPRNT ^R,
CFLUSH ^O, CWERASE ^W, CLNEXT ^V all match what the core was storing.  Only
CBRK differs in spelling -- `_POSIX_VDISABLE` where the core wrote `$FFFF` --
and both mean "no delimiter".

**THE BOOT ORDER BIT, exactly as the far bank's comment said it would.**
`main.s` calls `_Tty_CookedDefaults` for tty[0] at line 294 and `Tty_Init` at
line 334, so the first version of this JSL'd into the tty bank FORTY LINES
BEFORE the bank's operand bank bytes were patched -- keeping the assembler's
`$09`, landing in ROM, blank screen.  `main.s`'s own `Far_Init` comment records
the identical defect being fixed once already on the far bank, down to the
symptom: "landing in ROM with a blank screen well before any console existed to
report it."  Third bank, same trap.  The fix is a `_kTtyReady` guard in
`_Tty_CookedDefaults` PLUS an explicit seed of tty[0]'s characters immediately
after `Tty_Init` -- the guard alone would have been a silent skip.

**THE OFFSETS WERE WRONG, AND THE PROBE IS WHY THAT COST NOTHING.**  Arithmetic
put `t_chars` at 69: 60 for `t_pgrp`, plus 2, plus seven `char` members.  fcc
puts it at **70**, because it aligns a struct member to an even offset and
those seven chars end on an odd one.  `tty_probe` case 164 said so on the
machine, and reading `ADC #70` out of fcc's own output confirmed it.  So the
pad this struct needs sits in the MIDDLE, after `t_rocol`, and NOT at the end:
70 + 14 + 8 is exactly 92 with nothing over -- which answers the question
`include/ktty.s` had left open since stage 1a.  Cases 164-166 now pin
`t_chars`, `t_intrc` and `t_winsize` the way 160-163 pin the size, `t_flags`
and `t_pgrp`.

**`struct tchars` IN USERLAND BECAME `char`, and that is an ABI change.**  It
was six `short`s, and its header said it "MUST STAY short: the struct is 12
bytes matching the kernel image".  That reason is gone with the image: 2.11BSD
`usr/sys/h/ioctl.h:22-29` is six `char` and always was, the tty bank matches
upstream, and `ttioctl` bcopies `sizeof (struct tchars)` out of `&tp->t_intrc`.
Left alone, TIOCGETC returned `0x1C03` where userland expected `0x0003` -- two
packed characters read as one short.  `struct ltchars` next to it has been six
packed bytes here all along, so this is `tchars` catching up to its own
sibling.  Both copies of the header change (`toolchain/include/sgtty.h` and
`src/userland/lib/sgtty.h`); consumers name the fields symbolically, so only
`stty`, `tchtest` and `telnet`'s comments needed touching.

**pty.mod needed a service, not an address.**  `@mw_disc` tests every byte
written to a pty MASTER against `t_intrc` and `t_quitc`, so it is the one
reader outside the dying arms.  A module cannot JSL a `gen_kernel_exports.py`
address -- stage 1c's second defect -- so `KSVC_TTYINTRQUIT` (32) is appended
to `include/modules.s`, with an arm in `_Sys_KCallImpl` over slot 14
(`Tty_IntrQuit`).  ONE call returns both characters, because a second bank
crossing there is paid per character.  Slot 14 is assembly for that reason
rather than the interrupt-time reason slots 8-11 are.

**Witness**: `ttiocsm` gains the tchars cases -- the defaults must read as the
actual control characters (a line never seeded reads zeroes, and a migration
still reading the old core bytes reads whatever now sits there), and then a
round-trip writes `^G`, reads it back and restores `^C`, because reading
defaults alone would pass against a read-only seam.

**Core bank 57,814 -> 57,634, 334 free** -- below where the session started
(283), so 2b paid back more than 2a spent.

Next: 2c, the window size (`t_winsize`, offset 84 and now pinned), whose only
writers outside the dying arms are `_Tty_CookedDefaults` and pty.mod's
`_Pty_SlaveTtyInit`.


### Stage 2c: the window size

Two more arms die -- TIOCGWINSZ and TIOCSWINSZ -- and `_ttyTable`'s
`struct winsize` image goes with them.  `ttys[].t_winsize` is the only copy.

**NO SHAPE DECISION, and that is worth saying explicitly** after 2b: all three
copies of `struct winsize` already agree at four shorts / 8 bytes (upstream
`ioctl.h:62`, `src/kernel/tty/tty.h:82`, `toolchain/include/sys/ioctl.h:22`).
The bank spells them `unsigned short` where userland has `short` -- upstream's
own spelling, kept, and identical in layout until a terminal has 32768 rows.
The decision above therefore costs nothing here; 2d is where it bites.

**A SETTER AND NO GETTER.**  Export slot 15 is `Tty_WinSzSet` and there is no
`Tty_WinSzGet`, because once TIOCGWINSZ belongs to `ttioctl` the field has
exactly ONE reader and it is in this bank.  What still crosses is the SEED:
`_Tty_CookedDefaults` gives every line the console viewport, and pty.mod
re-seeds a slave to the BSD 80x24 default.  Assembly rather than kernel C for
neither of the reasons slots 8-11 and 14 are -- it is a two-word store, so the
`KTTY_KC_ENTER` bracket and an fcc frame would have been most of the call.

**The pixel fields are left alone by the slot, deliberately.**  Nothing in FGX
can answer them honestly, and a caller that HAS set them owns them: TIOCSWINSZ
carries a whole `struct winsize` through `ttioctl` and never comes this way.
That is a behaviour change from `@si_gwinsz`, which reported pixels as 0
whatever had been set -- upstream stores and returns what it was given
(`usr/sys/sys/tty.c:1670`), and now so does FGX.

**pty.mod needed a service again**, `KSVC_TTYWINSZ` (32), for stage 1c's
reason: a module cannot JSL a `gen_kernel_exports.py` address.  Rows and
columns travel PACKED IN Y -- `ws_col << 8 | ws_row` -- because X carries the
service number and A carries the line.  That caps a SEED at 255 either way and
caps nothing else; the unpacking lives in `_Sys_KCallImpl`, on the side of the
crossing that already owns the offset-to-index conversion.

**The same boot-order guard as 2b, and for the same reason.**
`_Tty_CookedDefaults` runs for tty[0] at `main.s:294`, forty lines before
`Tty_Init`, so the seed sits inside the existing `_kTtyReady` arm and main.s
seeds tty[0]'s size itself after `_TtyDevInit`.  One `_Se_TtyOffToIdx` serves
both slots because `_Tty_SetWinSz` preserves A -- register transparency doing
a second job.

**Witness**: `winsz` (console 25x80 unchanged, a 40x100 round trip, and the pty
MASTER path that telnetd actually uses -- the master's winsize pair acts on its
slave's line) and `wsintr` (the SIGWINCH edge, via `select`).  Both existed and
both were green before, which is the point: no new fixture was needed, so the
measurement is whether the same assertions survive the move.

**MUTATION-VERIFIED, because a green that cannot go red is not coverage.**
Deleting `tp->t_winsize = *(struct winsize *)data` from `ttioctl`'s TIOCSWINSZ
arm turns `winsz` red at **rc=7** -- the round-trip code, not rc=2 (routing
dead) or rc=5 (the set refused).  So the SET reached the bank's arm and the GET
read the bank's storage; both halves are new at this stage.  It also settles a
thing 2b left untested: fcc's `*(struct winsize *)data = tp->t_winsize` copies
eight bytes through a FAR pointer into the caller's bank correctly, where 2b's
tchars arms had used `bcopy`.

**Core bank 57,634 -> 57,567, 401 free.**  Suite 22/22.

Next: 2d, `sgttyb` and the local mode word -- where the DECISION below stops
being free.

### Stage 2d: the mode word, the speeds, and the ABI break

The largest of the four, and the one the DECISION below was taken for.  Seven
arms die -- TIOCGETP/SETP/SETN and TIOCLGET/LSET/LBIS/LBIC -- and with them the
last of `_ttyTable`'s sgtty state.

**THE TWO WORDS WERE ALWAYS ONE.**  `_ttyTable` kept `TTY_SgFlags` and
`TTY_Lmode` as separate 16-bit cells six fields apart.  Upstream keeps one
`long`: `ioctl.h:175-189` defines EVERY L* bit as `((int)(BIT>>16))`, so
LTOSTOP `$0040` IS TOSTOP `$00400000` shifted down, and TIOCLGET is
`*(int *)data = (int)(tp->t_flags >> 16)` and nothing more.  Slots 10 and 11
have handed the whole long across as `A=low, X=high` since stage 1b, so the
migration needed no new slot for the field itself -- only for the two pieces of
`sgttyb` that are not flags.

**THE ACCESSORS TAKE A BYTE OFFSET, NOT AN INDEX**, which is a departure from
stage 1c and was measured rather than assumed.  Nearly every surviving caller
holds an offset in X -- the heartbeat, both signal paths, the console write, the
read path -- so an index-taking accessor would have put
`PHX / TXA / JSR _Se_TtyOffToIdx / ... / PLX` at eight sites instead of the
conversion once, inside the wrapper.  `_Tty_PgrpOf`'s callers had indexes; these
do not.

**ONE OF THEM RUNS AT INTERRUPT TIME.**  `toolbox.s`'s heartbeat reads the mode
word at 60 Hz to decide whether ^C is a signal or a byte, so the whole path is
assembly on both sides -- kernel C is a singleton and a second live context
would share its register file.  That is the same constraint that made slots
8-11 assembly, reaching one stage further.

**Two new slots, both for `struct ttychars`.**  `sg_erase` and `sg_kill` are
`t_chars.tc_erase`/`tc_kill` -- they moved with the characters at 2b, and 2b's
own note said the bank's pair was "write-only until the sgttyb migration, at
which point it is already correct."  It was.  Slot 16 (`Tty_EraseKill`) reads
them for the canonical line editor; the pair comes back in **A and Y rather
than A and X** because at that call site X is the CALLER'S BUFFER OFFSET, which
is apple/fgx#224's register exactly.  Slot 14 grew a third return value in Y
(the mode word) rather than gaining a sibling, because pty.mod's `@mw_disc`
tests RAW before it tests either character and pays every crossing PER BYTE.

**The speeds went where upstream puts them.**  `sg_ispeed`/`sg_ospeed` are
`t_ispeed`/`t_ospeed`, and `tty_pty.c:72-73` seeds them on the line after
`ttychars(tp)` -- two statements, one after the other, in the open path.  So
`kc_ttychars` does both, and `_Tty_CookedDefaults` lost the stores rather than
gaining a slot.  B9600 (13) is kept over upstream's EXTB (15): neither is real,
and changing what `stty` prints is not part of this stage.

**THE ABI BREAK, taken deliberately.**  `struct sgttyb` in both userland
headers is now BSD's four `char` plus one `short` -- six bytes, `ioctl.h:44-50`.
Its "MUST STAY short" note was correct about an older fcc and had become a
second truth about a layout the tty bank owns; see the DECISION below.  fcc's
`char` is UNSIGNED, MEASURED and not assumed -- every char load is
`LDA c / AND #$00FF` -- so a field set to `-1` reads back as 255 and compares
equal to `_POSIX_VDISABLE`.  **FGX does not inherit BSD's signed-char `CCEQ`
wrinkle**, which is the one thing the DECISION flagged as needing an answer
before 2d.  K&R 2nd ed A.4.2 permits either: "the available range of values,
and especially whether the value is signed, is implementation-dependent."

**IT UNCOVERED A DEFECT 2b HAD LEFT BEHIND -- apple/fgx#228.**  `stty(1)`'s
special-character table is `short *cp`, and 2b made `struct tchars` six
`char`s without changing it.  The READS survived by accident (`*sp->cp & 0xff`
takes the low byte of a 16-bit load, which is the byte wanted); every WRITE
stored two bytes, so `stty intr ^C` silently reset `quit`.  Nothing caught it
because **no fixture drives stty's set path at all**.  Fixed here, where the
sgttyb pair becomes `char` too and one type is finally right for the table.

**Witness: 28 tests, six of them not in the previous 22** -- `rawintr` (the
interrupt-time RAW read, which is the heartbeat site), `viinsert`, `vipty`,
`vivc` (elvis through the new 6-byte struct), `morepty` and `vccursor`.  28/28.

**MUTATION-VERIFIED.**  Deleting `tp->t_flags = newflags` from `ttioctl`'s
TIOCSETP arm turns `rawintr` red on its position report and `viinsert` red on
its output file, while `smoke` and `novi` stay green -- so the SET travels to
the bank and the core discipline reads the bank's copy.

**AND IT FOUND A HOLE IT COULD NOT FILL -- apple/fgx#229.**  Nothing in the
tree injects a DEL: `raw_inject` carries MAME keycodes and no fixture sends the
Delete key, so the erase/kill comparison the new slot 16 serves has never been
covered.  That predates this stage; what this stage adds is
`_TtyStateProbe` cases 9-12, which assert the slot returns `ttydefaults`'
CERASE and CKILL and that both new slots refuse index NTTY.  Mutation-verified:
pointing slot 16 at `TTYC_CHARS+2` prints `tty: STATE PROBE FAILED case 9`.
That checks the SLOT, not the discipline, and the issue says so.

**Core bank 57,567 -> 57,506, 462 free.**

Next: 2e, the pgrp pair -- then `tty_probe` retires and T3 closes.

### Stage 2e: the pgrp pair, and stage 2 is complete

The last two arms.  `_IoOp_Tty` is down to three commands and all three are
FGX's own: TIOCISCONS and FIODGNAME have no 2.11BSD counterpart, and TIOCNOTTY
is pure process state that upstream answers in `tty_tty.c:58` before any
dispatch.  TIOCSTI stays held back for the reason 2a gave -- its `flag`
argument is not derivable here yet.

**IT IS NOT A RENAME, which is why it is a stage rather than a line of 2d.**
The FIELD moved at stage 1c, so `@si_gpgrp`/`@si_spgrp` were already thin
wrappers over slots 8 and 9 -- the same slots `ttioctl` reaches `tp->t_pgrp`
through.  What moves is the DISPATCH, and `ttioctl` brings two upstream guards
the core arms did not have:

- **`kc_spgok`** (`tty.c:1660`) is the whole of upstream's pfind/inferior
  ownership conjunction, delegated to the core's `_Se_SpgOk`.  `@si_spgrp` made
  no ownership check at all, so any process could hand any group the terminal.
- **TIOCSPGRP is in the SIGTTOU background list** (`tty.c:1439`), where the
  core arm was ungated.  A modifying ioctl from a background process now stops
  the caller, which is upstream's rule and does NOT test TOSTOP -- background
  input control is stopped whether or not the line has asked for output stops.

The second was the risk worth naming before running anything: a shell taking
the terminal BACK calls TIOCSPGRP while `tp->t_pgrp` is still the job's group,
so the gate's `kc_curpgrp() != tp->t_pgrp` is true at exactly that moment.  It
does not fire because the gate also requires SIGTTOU to be neither ignored nor
blocked, and a job-control shell arranges precisely that -- which is why BSD
can afford the rule.

**Witness: the same 28, 28/28.**

**MUTATION-VERIFIED, AND THE RESULT IS ALSO A COVERAGE FINDING.**  Making
`ttioctl`'s TIOCSPGRP arm return EPERM unconditionally turns **`tostop`** red
(`TOSTOP FAIL`, missing `stopped sig=22`) -- so the route is live and the arm
is what answers.  But `pgrptest`, `contostop`, `killpg0` and `smoke` all stay
GREEN under a kernel where *every* TIOCSPGRP fails.  Four of the five
job-control fixtures cannot see a broken TIOCSPGRP; only one can.  Worth
knowing before the next change to that arm goes looking for a witness.

**Core bank 57,506 -> 57,454, 514 free.**

### Where stage 2 leaves the campaign

`_IoOp_Tty`'s twenty arms are three.  `_ttyTable` has no sgtty state left at
all -- no pgrp, no chars, no winsize, no flags, no speeds -- and what remains
in it is the canonical line buffer, the backend selector and two reserved
words, every one of which belongs to the READ PATH and dies at stage 4.

**RETIRING `tty_probe` IS NOT NEXT, and the five-stage list above says so.**
Stage 5's condition is "once the userland suite is the witness", which requires
the linesw repoint of stages 3 and 4.  Until then this file's own opening
paragraph still holds: `tty_probe` is the SOLE CALLER of the twenty-nine
routines ported from 2.11BSD `tty.c`, and cases 160-166 are the only on-machine
pin on `include/ktty.s`'s DUM chain -- which that file's header says must never
become an unchecked transcription.  Deleting it now would delete the only
coverage of code that has no other caller, to save bytes in a bank with 21,642
free.

Next is stage 3, the write side: a `t_oproc` per line, `l_write` repointed at
`ttwrite`, and `@sw_console`, `@sw_chardev`'s loop and `_Tty_BgWriteGate` go.

### Stage 3 LANDED: the write side

`l_write` is `ttwrite` and `l_start` is `ttstart`, in both standard rows.  Every
byte a process writes to a tty now goes user buffer -> uio -> `obuf` ->
`ttyoutput` -> `t_outq` -> `tty_oproc` -> the device.  The design below was
written first and survived contact; what follows is what it did NOT anticipate,
because that is the part worth carrying.

**The shape held.**  `tty_oproc` is `dzstart` and `dzxint` collapsed, draining
runs with `ndqb`/`ndflush`, and `kc_cdwrite` is the one new shim -- a RUN of
bytes, not a byte, so one crossing carries a cblock's worth.  The `uio`
crossing needed nothing new, as the correction to this section had said.

**`_WrOp_Console` IS DEAD CODE, AND THAT WAS MEASURED, NOT ASSUMED.**  Stubbed
to return EINTR immediately, `smoke`, `devtty` and `vcswitch` all still pass:
no write in the system reaches it.  Since apple/fgx#121 gave the console a
node, fd 1 is a chardev fd and `_WrOp_Chardev` is the live path -- the same
finding stage 2a made about `_IoOp_Tty`, on the other side.  It is LEFT IN
PLACE: the console pseudo-FCB is still built (`fcb.s:76`), so deleting the arm
would rest on one boot's measurement, and 2a left the identical ioctl case
alone for the same reason.

**FOUR DEFECTS, and three of them reported SUCCESS while producing nothing or
producing rubbish.  That is the theme of this stage.**

1. **`ttwrite` slept forever on absent carrier.**  `TS_CARR_ON` is set only by
   `ttymodem`, which is `l_modem` and still an adapter -- so nothing in FGX had
   ever set it, and nothing had ever asked.  `ttwrite` opens by sleeping on
   `t_rawq` waiting for carrier when a line is neither carrying nor open, so
   the first write blocked and never returned.  Fixed where upstream fixes it:
   `ptsopen` (`tty_pty.c:77`) is `if (tp->t_oproc) tp->t_state |= TS_CARR_ON;`
   -- for a device with no modem, the presence of an output routine IS the
   carrier.  `tty_devinit` does it beside the binding.

2. **The uio was handed over with the ASSEMBLER'S bank byte.**  `#^_ttWrUio`
   is `$02`; the kernel runs at `$7C`.  The tty bank read a uio that was never
   written, found `resid` 0, had nothing to do, and **returned success having
   moved nothing** -- the quietest possible failure.  It is the same trap as a
   module JSL'ing a `gen_kernel_exports.py` address (`net.s:91`, stage 1c), in
   its third spelling.  `PHK` is the running bank by construction.

3. **The uio was a kernel SINGLETON and a uio is a CURSOR.**  `ttwrite`
   consumes it as it goes, so it is live across `_PtyS_Write` sleeping on a
   full pty ring three banks down.  Two concurrent writers walked one uio.  It
   presents as corruption WITHIN A LINE -- `ttypeneg` read back "Ihus no jjob
   control", one character substituted and one doubled -- and a single-writer
   `smoke` cannot see it.  apple/fgx#89's shape exactly.  It lives in the
   U-AREA now (`U_TtyIov`/`U_TtyUio`), which is per task and is what
   `include/kernel.s` says the u-area is FOR: "syscall-in-progress state that
   must survive a mid-syscall block".

4. **`OBUFSIZ` 100 OVERFLOWS THE KERNEL STACK -- apple/fgx#230, and it is the
   one that cost the most.**  `char obuf[OBUFSIZ]` is a LOCAL, so it sits on
   the calling task's 512-byte kernel stack (`FGX_KSTK_SIZE`), which already
   reports ~190 bytes spare at boot -- under a chain ten calls deep ending in
   `Con_Write`.  **And this bank compiles with fcc's stack guard OFF**, so it
   does not trap: it scribbles the neighbour's stack and the write reports
   success.  Measured: at 100 and at 64 the full-screen fixtures come back
   garbled (`vivc` read `"name:passwd:uid:gid:geasswd:uid:gid:gecos"`, one run
   twice at two offsets); at 16 all 28 pass.  **The failing SET moved between
   runs at the same value**, which is what sent three hours of diagnosis at the
   data path instead of the stack.  `OBUFSIZ` is 16, chosen for margin -- the
   boundary is somewhere in (16, 64] and was not bisected further.  The issue
   is the hazard, not the constant: `ttread` at stage 4 has the same shape.

**ONE DIVERGENCE, AND IT IS THE ONE THIS SECTION LEFT OPEN.**  `ttwrite`'s
background gate answers **EINTR** instead of upstream's `kc_lbolt(); goto loop;`.
Upstream can retry inside the syscall because BSD's `sleep(&lbolt, TTOPRI)` is
interruptible and `issig`/`psig` run from within it; **FGX delivers signals at
syscall boundaries only**, so a writer that stayed in the loop would post
SIGTTOU to itself once a second forever and never stop -- measured, and it is
what `tostop` reported as `BAD notstopped`.  EINTR reaches the same state one
syscall later.  That is EXACTLY the adaptation `_Tty_BgWriteGate` already
carried (`signal.s`, filed under apple/fgx#105), so the divergence MOVED with
the gate rather than being invented.  `ttioctl`'s SIGTTOU loop has the same
shape and is deliberately untouched: nothing reaches it.

**THE DEVICES STOPPED DOING THE DISCIPLINE'S WORK.**  `_Ttyv_Write` and
pty.mod's `@sw_go` both mapped LF to CR+LF from `SG_CRMOD`, which was right
while the core drove those putc ops directly.  `ttyoutput` does it now
(`tty.c:400`), so mapping again put CR CR LF on the wire.  Both mappings are
deleted.  Echo is unaffected and that is what makes it safe before the input
side moves: `_Tty_EchoByte` writes straight to `KFAR_CON_WRITE` and has never
come through those ops.

**Witness: 28/28**, `smoke` first and alone as this section said it should be.
**Mutation-verified**: deleting `ttstart(tp)` from `ttwrite`'s loop turns
`smoke` red with NO shell output at all while `vcswitch` stays green -- so
every byte really does travel the clist and the drain is what puts it on the
screen.

**Core bank 57,454 -> 57,703, 265 free.**  Stage 3 only adds; the payback is
stage 4, where `TTY_CanonBuf` and the whole `@rd_*` block go.

Next: stage 4, the input side.  `ttread`, `ttyinput`, the assembly `putc` and
permanent PENDIN -- and it inherits apple/fgx#230, because `ttread` has a local
buffer on the same stack.

### Stage 4, RESTARTED 2026-08-25: what changed, and the increment order

**THE REASON 4a WAS REVERTED IS WRONG.**  4a concluded it was blocked on
apple/fgx#230, the kernel stack.  Measured since: the per-task kernel stack
slices are painted now (`STK_PAINT`, `tools/mame_test/kstkhwm_check.py`) and
**no slice ever overflows** -- under the known-bad OBUFSIZ 100 the deepest
tty-path slice reaches 402 of 512 with 110 spare and every `$C5C5` canary
intact.  The canary's silence was never evidence of headroom, and it was never
a contradiction: one word at the very bottom reports only a COMPLETE overrun.

And the OBUFSIZ defect that shares the file is not a stack problem at all.
Bisected to 51/52, where `ttwrite_FRAMESIZE` reads **72 in both builds** --
identical frame, identical local layout, opposite outcomes.  Ruled out by
measurement since: the `ovhiwat`/`out:` uio rewind (unreachable with
`tthiwat[]` raised, still fails), short-`b_to_q` accounting (faithful to
`vendor/2.11BSD`, `ce -= i` included), and cblock spanning (CBSIZE is 28; 28
and 29 both pass).  Mechanism still unknown; `kc_uiomove`'s cross-bank copy is
the leading candidate.  **Stage 4 is not blocked on any of it.**

#### The five corrections to 4a's design

1. **`l_close` is `ttylclose(tp, flag)`, not `ttyclose(tp)`.**
   `vendor/2.11BSD/usr/sys/sys/tty_conf.c:41` names `ttylclose` in row 0;
   `ttyclose` is what the DRIVER calls after `l_close` (`tty_pty.c:95-96`).
   Writing `ttyclose` zeroes the whole `t_state` word on a `TIOCSETD`, dropping
   `TS_ISOPEN` and `TS_CARR_ON` on a discipline change meant to leave the line
   up.
2. **The repoint breaks the ttyprobe kernel at BOOT unless the probe cases move
   first.**  `tty_probe.c`'s linesw cases CALLED each slot with one argument;
   after the repoint case 22 becomes `ttread(tp, <4,S>, <6,S>)` and hangs,
   which tryprobe reports as NO VERDICT.  Converted to pointer identity ahead
   of the repoint (`305628381`).
3. **`ttread`'s SIGTTIN gate still sleeps and retries** where stage 3 changed
   `ttwrite`'s to EINTR, and nothing documents it.  `kc_lbolt` is
   uninterruptible, so a background reader livelocks -- the same failure stage 3
   measured on the write side.  Stage 4 must carry the same divergence.
4. **The kernel direct pages ARE per-task** (`include/kernel.s:584`,
   `sched.s:389-393`); `FGX_DP_KERNELC` is the only shared one.  So
   `PEI (_kTtyRdPtr)` in `_Tty_GetByte` is belt-and-braces, not the protection
   -- do not copy that idiom into the seam believing otherwise.
5. **`cwaiting` is dead upstream too.**  Every reference in
   `vendor/2.11BSD/usr/sys/sys/tty_subr.c` is `if (cwaiting) { wakeup... }`
   with no assignment anywhere; `putc` just returns -1.  FGX's port is
   faithful, so adding the sleep would be a divergence rather than a port.

#### THE FIRST-CHARACTER BUG, and the fix is the design

4a's four pty/VC failures were the first character of every line arriving as a
different wrong value each run.  `_Tty_GetByte` parks exactly three cells --
`_Sys_RdRem`, `_Sys_BytesRead`, `_Sys_CallerBank` -- and **not**
`_Sys_RdBufOff` or `_Sys_RdMax`.  The old core path never needed them parked
because it carries the caller's buffer offset in X on the per-task stack across
every sleep (`@rd_g_key` is `PHX / JSR _Tty_GetByte / PLX`).  **A uio-based
seam has no X.**

So the fix is structural rather than a wider save list: build the uio in the
per-task u-area BEFORE anything can sleep, and take the delivered count from
`uio_offset` -- which `ureadc` advances per byte -- so `_Sys_RdMax` is never
consulted after the pump at all.  That also retires 4a's finding 1 (a stale
`_Sys_RdMax` FABRICATING a byte count) instead of parking around it.

#### The increment order, and what goes red if each is wrong

The bisect axis is BACKEND, not mode: that is the axis 4a's failure split on
(console clean, pty/VC broken), and a mode split would strand bytes when a
program changes modes mid-session, which `more(1)` does and `morepty` tests.

| # | What | Witness |
|---|---|---|
| 0 | measure the baseline | 38/40 -- `rdstop` and `vckeys` were ALREADY red (apple/fgx#232) |
| 1 | `ureadc` accepts UIO_USERSPACE; probe cases move with the arm | ttyprobe4 case 397 |
| 2 | linesw probe cases -> pointer identity | ttyprobe half A |
| 3 | `kc_ttread` + KTTY slot 19, no pump | ttyprobe4 cases 450-452 |
| 4 | `@rd_cdUio` + `_Tty_Read`, plumbed but unwired | size; first real witness is 5 |
| 5 | repoint `l_read`/`l_rint`, pump, route tty[0] only | smoke, ntkctl, novi, rawintr, ctrlc, intrflush |
| 6 | extend to the VC pair | vivc, vckeys, vcpager |
| 7 | extend to the pty slaves; the gate goes | morepty, ttypeneg, vipty, devtty |
| 8a | delete the core read discipline, gate and echo trio | the whole set |
| 8b | retire `TTY_CanonBuf`; two new slots | the whole set |

**INCREMENTS 0-7 ARE LANDED.**  5 is `c3e788aae`, 6 is `e720731aa`, 7 is
`ff7999d35`.  Every tty line reads through the ported discipline now.  The witness has read 38 of 40 at every one of them, which IS
the baseline.

#### Increment 8 is landed, and slot 16 nearly went with it

**8b landed.**  Two new export slots -- 20 `kc_ttflush` onto `ttyflush`, 21
`kc_ttnread` onto `ttnread` -- then the deletions: `TTY_CanonBuf`,
`TTY_CanonLen`, `TTY_CanonPos`, `TTY_CANON_SZ` and `_Tty_EraseKillAt`.  Core
bank **1,733 bytes free**, against the 138 it had when stage 4 opened.

**THE SIGNAL-DELIVERY FLUSH GOT NO SLOT.**  `_Tty_DeliverSig` reaches
`_Tty_DrainSigPend`, whose header says kernel-DP contexts only, and `sched.s`
calls it from the SWITCH path -- kernel C there would share its singleton
register file with whatever task was interrupted.  It posts `_kTtyFlushPend`
and the pump flushes before its next read: increment 5's latch, second
customer.

**SLOT 16 IS STILL LIVE AND THE GATE IS WHAT SAID SO.**  Retiring
`KTTY_ERASEKILL` looked safe -- its core wrapper `_Tty_EraseKillAt` had no
callers left once 8a deleted the gather.  Half A then came back with ONE
verdict of three, because `main.s` calls **the slot directly** from
`_TtySlotProbe` (`_ktp029`), where it pins `_Tty_Chars` and is the only
coverage the erase path has: no fixture sends the Delete key (apple/fgx#229).
**Grepping a wrapper's name does not find the slot's own callers.**  The
40-test witness passed throughout -- it does not build the probe configs -- so
this was gate-only.

**HALF A WAS AT 353 BYTES AND THE CLIST PROBE MOVED TO C** (`a3d68a1c9`).
Increment 8b's two slots put A there; `clist_probe.s` plus its data is 4,377
bytes, so `TTYCLIST` became `TTYPROBE3` and A went back to 4,730 while C came
down to 5,903.

**C "COULD NOT" TAKE IT IN AUGUST, AND THAT IS WORTH KEEPING.**  The 2026-08-24
measurement was 63,069 of 65,280 -- 2,211 free, short by 2,166 -- and it was
quoted in three places as though it settled the question.  The half was then
SPLIT into C and D, which took C to 55,000.  **A recorded "cannot" is a
measurement of a tree, not a property of a file**; re-measure before believing
a size verdict older than the last structural change.

The clist lever is now SPENT: B gave its copy up at `126d0e942`, A gave the last
one to C, and there is no third move -- one copy, and deleting it deletes the
witness.  B is the tightest half at 3,549.  Measured after the move: A 4,730,
B 3,549, C 5,903, D 5,330.

#### Increment 8a split it, because the canonical buffer was NOT dead code

**8a is landed.**  454 lines out of `syscall.s` -- `@rd_disc` and both gathers,
the core SIGTTIN gate (`@rd_gateOn`/`@rd_gateBg`/`@rd_isCtty`/`@rd_ttinEio`),
`_RdOp_Console`'s boot arm and the echo trio -- plus `_ttyGateTmp`.  The core
bank goes from 461 bytes free to 1,159.  Nothing could reach any of it once
increment 7 routed the last two lines.  `_Tty_GetByte`/`_Tty_PollByte` stay:
they are the VC focus gate and the pty byte source, with no upstream
counterpart.  `@rd_chardev` stays: it serves the chardevs that are NOT tty
lines.

**8b IS NOT A DELETION, AND THAT IS THE FINDING.**  `TTY_CanonBuf` /
`TTY_CanonLen` / `TTY_CanonPos` look like leftovers of the discipline 8a
removed.  They are not -- five live sites still use them, and four of them are
FLUSH sites whose behaviour has to survive:

| site | what it does |
|---|---|
| `_Tty_PollReadable` (`ttyv.s:228`) | READS `CanonPos`/`CanonLen` to answer select/poll readiness |
| `ttyv.s:144`, `ttyv.s:318` (`_Con_Close`) | clears the cursor on close -- `ttyflush(FREAD)` |
| `pty.s:212` | clears it on pty open |
| `signal.s:357` | the `LNOFLSH`-gated flush on signal delivery (the measured `zecho $HOME` bug) |

So 8b needs TWO NEW KTTY SLOTS before it can delete anything: a flush seam onto
`ttyflush` (`tty.c:776`) and a readiness seam onto `ttnread` (`tty.c:1200`).
Both routines are ported already and have no export slot.  include/ktty.s is
APPEND ONLY and slot 17 is the current high-water; `KTTY_ERASEKILL` (slot 16)
is the one 8b retires, and a retired slot is STUBBED rather than removed, with
the LUP count moving with it.

`TTY_CANON_SZ` is DELETED at 8b, not restored to 256: the 128 was a temporary
lever taken to get the core bank under its ceiling at increment 4, and 8a's
1,159 bytes free have already repaid it.

The userland comments in `getty.c`, `login.c` and `ptykey.c` that name
`TTY_CanonBuf` describe a behaviour that still holds -- an untaken remainder
becomes the next reader's first bytes -- but the structure is the clist canq
now, so they want renaming rather than deleting.

#### Increment 7 measured red, and the cause was not in the tty code

Routing `@rd_ptyS0`/`@rd_ptyS1` at `@rd_ttyBank` -- the same two-jump change
increment 6 made for the VCs -- took the witness to 35/40.  `morepty`,
`ttypeneg` and `vipty` were ONE defect: all three telnetd runs, all three
stopping at `Login incorrect`, because the CONSOLE read feeding the telnet
client handed `getpass(3)` a corrupted byte.  **The corruption landed on
tty[0], the line the change does not touch.**

**IT WAS NOT A TTY DEFECT.**  `_fcc_bank_for_int` read `_fcc_dbr`, a cell
crt0 (`crt0_lib.s`) seeds once from DBR because DBR never changes in user
code, so one snapshot serves every conversion site.  The kernel has no crt0 and
several data banks, and each PUTs its own image-zero copy of that cell -- so
every runtime int-to-pointer cast in kernel C reconstituted BANK 0.  `cinit`
built the whole clist free chain through bank-0 pointers, putting the pool
inside the `STK_PAINT` user-stack arena where a spawn's paint fill overwrote
its links.

**THE CONFIRMING MEASUREMENT NEEDED NO KERNEL INSTRUMENTATION**, which is the
lesson worth keeping: two `memory_regions` entries on an existing fixture, read
out of the dump.  Before the fix `cfreelist` was bank `$00` and the tty bank's
own `cfree[]` was ALL 1,024 BYTES STILL IMAGE-ZERO -- the pool the clists were
supposed to live in had never been touched.  After, bank `$7E` with 100 bytes
in use.  Every earlier instrumented probe had perturbed the layout enough to
move the bug; the dump did not.

apple/fgx#234 has the full account.  It also retired apple/fgx#230: OBUFSIZ's
51/52 bisect was the same corruption, `vivc`'s "the same run twice at two
offsets" being a rewritten chain rather than an overrun of `obuf`, and OBUFSIZ
is back to upstream's 100.

#### Increment 6 corrected two things this table said

**THERE IS NO TEST AT THE JOIN, AND THIS SECTION EXPECTED ONE.**  The plan had
increment 5's jump moving down to `@rd_disc` and growing an eight-instruction
comparison against `_ttyTable+{TTY_SIZE*3}` and `+{TTY_SIZE*4}`.  Nothing needs
comparing: every arm in `_Sys_Read` writes its own line into `_kTtyRdPtr` before
it jumps, so routing a line is a JUMP TARGET, and the seam reads the index back
out of the pointer through `_Se_TtyOffToIdx` -- the conversion `@rd_gateOn` and
`@rd_isCtty` were both already making.  A test at the join would re-derive two
instructions later what the arm had in hand.  The literal `LDA #0` the seam
carried at increment 5 was the only line-specific thing in it.

**`vckeys` IS NOT A USABLE WITNESS FOR THIS INCREMENT** even though the row
names it: it was red before stage 4 started (apple/fgx#232), so it cannot go
from green to red and reports nothing about the routing.  `vivc` and `vcpager`
carry the row alone, and neither can distinguish "the VC pair reads through the
discipline" from "the VC arms are dead code and nothing changed".  What
distinguishes them is a POSITIVE CONTROL: with `kc_ttread` returning `EIO` for
any line above tty[2], `smoke` stays green -- so the mutation is not a blanket
break -- while `vivc` stops at `login:` and `vcpager` loses its screen.
`vcswitch` stays green under it too, which is worth recording as the
INSENSITIVE control: switching consoles never reads, so a suite that had only
`vcswitch` would have called this increment green without exercising it.

The VC pair also GAINS `ttread`'s SIGTTIN gate, which no arm on this path ever
ran -- `_RdOp_Chardev` says so of the ptys ("No SIGTTIN gate for pty ttys in
v1") and the VCs inherited the same silence.  Upstream's is
`if (tp == u.u_ttyp && u.u_procp->p_pgrp != tp->t_pgrp)`,
`vendor/2.11BSD/usr/sys/sys/tty.c:1157`, ctty conjunct first -- which is what
`ttbgread` already implements, so the behaviour arrives with the routing.

**THE PROBE BANK HAD TO BE SPLIT FIRST.**  Half C was 65,271 of 65,280 -- NINE
bytes -- and increment 3 adds 320 to that bank, so half C stopped assembling
before stage 4 had written a line of what it tests.  Split at its own `ureadc`
banner into C (state and flow control) and D (moving bytes): 12,028 and 7,310
free.  apple/fgx#233.

**THE NEXT CEILING IS HALF A AT 762 BYTES, not `ttyprobe2` at 920.**  That line
was measured before half B gave up its second copy of the clist probe
(`126d0e942`), which returned 4,377 bytes to B and left A -- the only half still
linking `clist_probe` -- as the tightest.  **The clist lever is NOT available
to A for that reason**: dropping it there deletes the witness rather than a
duplicate.  Hand `clist_probe` to C or D, which have room, and move `TTYCLIST`
with it.  Measured at increment 6: A 762, B 3,958, C 10,689, D 5,739.

**THE CORE BANK IS THE OTHER CEILING.**  Increment 4 put it 42 bytes OVER, and
the lever was `TTY_CANON_SZ` 256 -> 128: 640 bytes back from the arm being
retired, on a buffer upstream has no counterpart to.  It is deleted outright at
increment 8, not restored.

#### Settled from the code, so it is not re-derived

- **Read and write SHARE `U_TtyIov`/`U_TtyUio`.**  A task is in one syscall at
  a time, and the one apparent counter-example -- `ttyecho` re-entering the
  write side from inside `ttread` -- reaches the device through `kc_cdwrite` ->
  `_FarSh_CdWrite` -> `_Chardev_Write`, which carries its run on the stack
  frame.  Grepping `U_TtyUio` finds writers in `syscall.s` and nowhere else.
- **The witness set is 40, not 28.**  The seven best read-side fixtures --
  `intrflush ctrlc rdrestart rdstop rdkill vckeys vcpager` -- are in neither
  the 28 nor `GATE_TESTS`, and of the whole tty family only `smoke` and
  `ptyrec` are gated.  `nottykey` is only a measurement WITH `ntkctl`.

## T4 DESIGNED 2026-08-26: `tty_pty.c`, and BSD already drew the seam

T3 is done.  T4 ports `vendor/2.11BSD/usr/sys/sys/tty_pty.c` -- 570 lines, 13
routines -- against FGX's 1,503 lines of hand-written 65816 in
`src/modules/pty/pty.s`.

**THE FIRST PASS ASKED THE WRONG QUESTION.**  It counted `tp->t_state` 23 times
and `t_canq` 18 across the file, concluded pty.mod could not reach that across
a bank, and offered three FGX-shaped seams to choose between.  Counting the
file as a whole is what made it look like a fork.  It is not one: **the access
splits exactly along BSD's own `pts`/`ptc` line**, which is the line the file's
own header draws in its second sentence -- "Actually two drivers, requiring two
entries in `cdevsw`".

| half | lines | `t_state` | queue refs | discipline calls |
|---|---|---|---|---|
| slave `pts*` | 141 | 6 | 8 (7 of them in REMOTE-mode `ptsread`) | `linesw` one-liners, `ttyclose` |
| master `ptc*` | 265 | 17 | 23 | `q_to_b`, `b_to_q`, `putc`, `ttwakeup` |
| `ptyioctl` | 107 | 0 | 1 | `ttioctl` fall-through |

### The design, from the source

**THE MASTER IS THE DEVICE.**  `ptcread` drains `t_outq` because that is what a
UART transmit interrupt does; `ptcwrite` feeds `ttyinput` because that is what a
receive interrupt does.  All 23 queue references are the device end of a line,
not a client of one.

**AND BSD'S HOOKS INTO THE DISCIPLINE ARE EXACTLY TWO FUNCTION POINTERS:**

    tty_pty.c:213   tp->t_oproc = ptsstart;     /* in ptcopen  */
    tty_pty.c:231   tp->t_oproc = 0;            /* in ptcclose -- "mark closed" */
    tty_pty.c:77    if (tp->t_oproc)            /* in ptsopen  */
                        tp->t_state |= TS_CARR_ON;

`t_oproc` and `d_stop` (`ptsstop`).  **The master's presence IS carrier** --
that is the whole of the connection between the two drivers, and `ptyioctl`
tells them apart by `cdevsw[major(dev)].d_open == ptcopen` (tty_pty.c:480).

**FGX HAS ALREADY BUILT BOTH HOOKS.**  `tty_devinit` sets
`ttys[idx].t_oproc = tty_oproc` for every bound line (tty_dev.c), and
`kc_cdstop` is `d_stop`, called from `ttyflush` (tty.c:795) and `ttstart`.
What FGX wired generically -- one `tty_oproc` for all lines, dispatching on
`t_dev` through the chardev registry -- BSD wires per driver.  That indirection
is FGX's `cdevsw`, one level further down, and it is legitimate.

### So the port needs NO new seam, and the placement question dissolves

- **The slave half ports into pty.mod as `linesw` dispatches**, through slots
  that already exist: `kc_ttread` (19), `kc_ttwrite` (17), `kc_ttflush` (20),
  `kc_ttychars` (13), `kc_ttyopen`.  Its six `t_state` touches are open/close
  bookkeeping and want an accessor, not a bank move.  `_PtyS_Read`'s `fail
  loud` EIO stub becomes the one-liner `ptsread` is.
- **The master half's queue work never crosses a bank**, because in FGX it is
  already on the tty-bank side of the hook: `tty_oproc` drains `t_outq` and
  hands RUNS to the device through `kc_cdwrite(t_dev, ...)`.  The master does
  not reach into `t_outq` from pty.mod; the discipline pushes at it.
- **FGX's rings are not the divergence the first pass called them.**  They
  stand where a UART's silo stands -- between `tty_oproc` and the master's
  `read(2)` -- not where `t_outq` stands.  That is BSD-shaped.  What IS a
  divergence is that FGX's pty slave has no `t_oproc` of its own, so
  `ptsstart`'s "the controller is still there" carrier semantics have no
  counterpart yet, and `ptcclose` has nothing to clear.

**THE REAL WORK OF T4 IS THEREFORE `t_oproc` PER LINE, NOT A BANK DECISION.**
Give the pty slave lines their own oproc and the port follows; the capacity
question the first pass raised does not arise, because nothing of size moves
into the tty bank.

### The increment order

| # | What | Witness |
|---|---|---|
| 1 | `l_modem` repoint: `ttyadapt_modem` -> `ttymodem`, probe pins move | **LANDED `306704a74`** -- ttyprobe half A |
| 2 | carrier follows the master: `ptcopen`/`ptcclose` call `l_modem`, and `ptsopen` calls `l_open` | **LANDED `e96b9cea2`** -- `ptyhup`, written first and measured red |
| 3 | the slave CLOSE through the discipline: `l_close` then `ttyclose` | **LANDED `505ec020a`** -- `ptyflush`, written first and measured red |
| 4 | the output queue is the discipline's: `t_oproc` = `ptsstart`, both master reads pull from `t_outq` through a uio | **LANDED `45f1f2be4`** -- `ptyoutq` flipped RING -> BSD |
| 5 | LANDED. NOT `ptyioctl` (already structural): the slave's `d_stop` is `ptsstop`, `pt_send` becomes real, and `ptsstart`'s TIOCPKT_START arm is evaluated at the master's ask | `ptypkt` |
| 6 | LANDED as a DECLARATION: REMOTE mode needs a record boundary the write path does not have, so TIOCREMOTE is refused and the divergence is stated in `pty(4)` BUGS | `ptyremote`, `manpty` |

### Increment 2 is landed, and the open half had to come with it

**`l_open` HAD NEVER BEEN DISPATCHED BY ANYTHING**, and that is the finding.
The increment was scoped as the carrier pair alone -- `ptcopen`/`ptcclose`
calling `l_modem` -- and with only that in place the witness stayed red for a
SECOND reason after the first was fixed:

- `ttymodem`'s lost-carrier arm is gated on `TS_ISOPEN`;
- `TS_ISOPEN` is set by `ttyopen` and by nothing else;
- `ttyopen` is `l_open`, and no FGX open path dispatched it.

So the bit could not be 1 on any line in this kernel, and every test of it --
`ttread`'s, `ttwrite`'s and the whole hangup arm -- was reading a constant.
`l_open` now carries the real `ttyopen` in both real rows, the way increment 1
gave `l_modem` the real `ttymodem`.  `l_close` stays an adapter: `ttylclose` is
the close half of the same port and nothing dispatches `l_close` yet.

**THE DUMP SAID IT, NOT AN INSTRUMENTED KERNEL** -- one `memory_regions` entry
on the fixture already being run:

    {"name":"ttys","symbol":"ttys","len":460,"ttybank":true}

`struct tty` is 92 bytes (`TTYC_SIZE`), `t_state` at +56, `t_pgrp` at +60.  The
line under test read `state=00000000` where every other line read
`00000010` -- so the boot binding's `TS_CARR_ON` had been cleared by the modem
call, which proved that half worked, while `TS_ISOPEN` had never been set,
which named the half that did not.  After the repoint the same line reads
`00000004`: open, and not carrying.

**PTYF_MOPEN REMAINS THE PRESENCE FLAG**, as designed below.  `t_oproc` stays
the output hook it also is upstream.

**Two new KTTY slots, 22 (`kc_ttopen`) and 23 (`kc_ttmodem`)**, because
`linesw[]` is the tty bank's and a module cannot reach it; `KSVC_TTYLOPEN` and
`KSVC_TTYMODEM` carry them to pty.mod.  `KSVC_TTYOPEN` is left declared with no
caller -- append only, and a service number is never reused.

**CARRIER GOES DOWN BEFORE THE FLAG DOES.**  Upstream's order in `ptcclose`,
and load-bearing here for a reason upstream does not have: `_Pty_MaybeReset`
zeroes the line's foreground group once both sides are shut, and that group is
who `ttymodem` has to signal.

The original scoping note is kept below, because what it got right is why the
witness existed before the code.

**INCREMENT 2 IS WHERE THE BEHAVIOUR CHANGES AND IT NEEDED ITS OWN WITNESS
FIRST.**  FGX synthesises a hangup today: `_Tty_GetByte`'s `@tgb_phup` hands
the reader a `^D` when `PTYF_MOPEN` is clear.  `ttymodem`'s lost-carrier arm is
the real mechanism -- SIGHUP then SIGCONT to the foreground group, then
`ttyflush(FREAD|FWRITE)`.  Those are not the same event, and no fixture asserts
either: nothing in the 40 currently checks that a master close HUPs the slave's
session.  **Write that assertion before increment 2, or the change lands with
no way to go red.**

**AND `t_oproc` CANNOT SIMPLY BECOME THE PRESENCE FLAG.**  `ptcopen` refuses a
second master with `if (tp->t_oproc) return (EIO)`, which works upstream
because `pt_tty[]` starts zeroed and only `ptcopen` fills it.  FGX's
`tty_devinit` installs `tty_oproc` on EVERY bound line at boot, so a pty slave
arrives with the field already set.  Either devinit learns which lines are pty
slaves, or FGX keeps `PTYF_MOPEN` as the presence flag -- which
`_PtyM_Open` already tests (pty.s:572) -- and uses `t_oproc` only as the output
hook it also is upstream.  The second is smaller and honest; say which in the
commit rather than leaving the divergence implied.

### Increment 3 is landed, and it is not the increment this table promised

The row read "the slave half as `linesw` one-liners -- `_PtyS_Read`'s EIO stub
becomes `ptsread`", and that was written before increment 7 of stage 4 landed.
**READ AGAINST THE TREE, THREE OF THE SLAVE'S FOUR ROUTINES WERE ALREADY
PORTED, AND NOT BY T4:**

- `ptsread` is `(*linesw[t_line].l_read)(tp, uio, flag)` and FGX's `_Sys_Read`
  detours a slave fd into `kc_ttread` -> `ttread` BEFORE the chardev read loop
  (stage 4 increment 7).  `_PtyS_Read`'s `fail loud' EIO stub is unreachable
  because the syscall layer, not the driver, is where FGX routes a tty read --
  for every line, not just a pty.
- `ptswrite` is `(*linesw[t_line].l_write)(tp, uio, flag)` and `_Sys_Write`
  reaches `ttwrite` the same way (stage 3).
- `_PtyS_Write` is NOT `ptswrite`.  It is the device end -- what `tty_oproc`
  reaches through `kc_cdwrite` when the discipline drains `t_outq` -- and it
  stands where a UART's transmit routine stands, which is this section's own
  point about the rings.

**SO WHAT WAS LEFT OF THE SLAVE HALF WAS THE CLOSE**, and it had become the
urgent piece rather than the tidy one: increment 2 made TS_ISOPEN real and
nothing brought it down.  `ptsclose` calls `l_close` AND `ttyclose`
(tty_pty.c:94-95), which are not two spellings of one thing -- the first takes
the discipline off the line, the second cleans the line -- so both sit behind
one door, `kc_ttclose` (slot 24).

`ptyflush` measured the older half of the same defect, which predates increment
2 entirely: `r2 n=1 b=67` before, `b=90` after -- a session's unread `C` handed
to the session that followed it, against that session's own `Z`.

**THE FLAG IS 0 AND IT IS A DIVERGENCE.**  FNDELAY decides drain-or-discard in
`ttylclose` and FGX's chardev close op is handed a minor and nothing else.
Stated at the door in `tty_dev.c` and in `include/ktty.s` rather than left to
be discovered.

**WHAT THE ROW STILL OWES:** `ptsread`'s REMOTE mode, unchanged and still the
open question below.  If the intent of the row was that a pty read should
arrive at the DRIVER rather than at the syscall layer's detour, that is a
change to `_Sys_Read` for every tty line and not a pty increment -- say so
before it is done.

### MEASURED 2026-08-26: where a pty's pending output lives, and who can see it

The first survey's line -- "FGX's rings are not the divergence the first pass
called them: they stand where a UART's silo stands, not where `t_outq` stands"
-- **is true of the INPUT ring and false of the OUTPUT ring.**  Reading the
master half against the tree is what separates them.

**2.11BSD'S PTY HAS EXACTLY ONE OUTPUT BUFFER AND IT IS THE DISCIPLINE'S.**
`ptsstart` moves no data; it is a wakeup:

    ptcopen   tp->t_oproc = ptsstart;                       tty_pty.c:213
    ptsstart  if (tp->t_state & TS_TTSTOP) return; ...
              ptcwakeup(tp, FREAD);                          tty_pty.c:290
    ptcread   if (tp->t_outq.c_cc && (tp->t_state&TS_TTSTOP) == 0) break;
              cc = q_to_b(&tp->t_outq, buf, MIN(uio->uio_resid, BUFSIZ));

The slave's bytes stay in `t_outq` until the MASTER'S OWN READ dequeues them,
and it is that read which then wakes a writer parked at hiwat.  FGX binds the
generic `tty_oproc` to every line and it DRAINS -- each `ttstart` empties
`t_outq` through `kc_cdwrite` into the pty's 128-byte ring.  Right for a
console, where the bytes are on the screen when the call returns.  A second
buffer on a pty, where the far end's read IS the device.

**THE INPUT RING IS NOT THE SAME CASE AND IS NOT A DIVERGENCE TO FIX.**
`ptcwrite` feeds `l_rint` directly at write time; FGX cannot run `ttyinput` at
arrival time until T6, which is the maintainer's accepted divergence of 2026-08-22.  The
InRing is the deferral that divergence requires.  Only the OutRing is unforced.

**THE MEASUREMENT** (`ptyoutq`, and it carries two positive controls because a
dead ioctl arm and an empty queue give the same zero):

    PTYOUTQ outq=0                  five bytes written by the slave, unread by
                                    the master -- the discipline says none
    PTYOUTQ read n=5 b0=65 b4=69    control 1: they were there all along
    PTYOUTQ stopped outq=5          control 2: TIOCSTOP, so tty_oproc refuses
                                    to drain -- the arm is alive and answers 5
    PTYOUTQ RING

So `TIOCOUTQ` works, and the queue it reports really is empty.  **The same zero
is what four other ported mechanisms measure on a pty:**

| mechanism | reads | on a pty |
|---|---|---|
| `TIOCOUTQ` (tty.c:1520) | `t_outq.c_cc` | 0 with output pending |
| `ttycheckoutq` (tty.c:1957) | `c_cc > hiwat` | never waits |
| `ttywait`/`ttywflush` | drains `t_outq` | vacuous -- and increment 3's close calls it |
| `ttyflush(FWRITE)` | discards `t_outq` | the bytes already left -- and increment 2's hangup calls it |
| `TS_TTSTOP` in `ptcread` | holds output at the master's read | FGX's bytes are past the discipline |

Backpressure has moved with them: upstream throttles the slave writer through
`t_outq` hiwat plus `ptcread`'s low-water wake, and FGX re-implements it as
`_PtyS_Write`'s `WCHAN_PTY` sleep on a full ring.  **Two copies of "how much
output is pending"** -- the shape stage 1c deleted for `t_pgrp`, on the grounds
that two copies let the two disciplines disagree.

**THE CAPACITY NUMBER THE DECISION NEEDS, read off the live machine rather than
the headers.**  `ttys[].t_ospeed` is 13 (`B9600`) on every bound line, so
`tthiwat[13]` is 650 and `ttlowat[13]` is 125.  The whole clist pool is
`NCLIST 32 x CBSIZE 28` = **896 bytes**, shared by all five lines; the current
pty ring is 128.  So one unread pty parked at hiwat would hold 650 of 896.
That is a config choice rather than a BSD conflict -- upstream sizes `nclist`
from the kernel config, and `ttyparam.h` already calls FGX's 32 "a sizing
default, not a measured optimum" -- but it has to be MADE before the output
path moves, either by raising NCLIST or by seeding a pty a lower speed index
(upstream's own knob: speed picks the watermark).

**WHAT THIS DOES NOT SETTLE.**  Whether to move is still open.  Increment 2's
row already anticipated the mechanism -- "the pty slave's `t_oproc` stops being
the boot binding's" -- and increment 2 delivered only the carrier half of it,
so the row is owed either way.  `ptcwakeup`'s select half is missing under
BOTH designs and depends on neither.

### T4 INCREMENT 4 DESIGNED 2026-08-26: the seam is `ndqb`/`ndflush`, PULLED

The maintainer chose Option B (2026-08-26): the pty's pending output lives in `t_outq`,
as it does upstream, rather than being drained eagerly into the driver's ring.
NCLIST was sized for it first (32 -> 64, `272832925`).  What follows is how it
lands without moving the driver out of pty.mod.

**INCREMENT 4 IS ATOMIC AND THAT IS A FINDING ABOUT THE PLAN.**  It cannot be
split into "stop draining" and "start pulling": the moment `tty_oproc` stops
emptying `t_outq`, the master's read has to be the thing that empties it, or
the slave's output reaches nobody.  The source and the drainer move together.

**THE FIRST TWO SEAM DESIGNS WERE WRONG, AND BOTH WOULD HAVE MOVED THE DRIVER
OUT OF pty.mod:**

1. *Give `kc_ptcread` a `uio`.*  Upstream's signature really is
   `ptcread(dev, uio, flag)', so this reads faithful -- but FGX's master read is
   a `CDF_RECORD` chardev op delivering through `_Sys_RdBufOff` /
   `_Sys_RdMax` / `_Sys_CallerBank`, and giving it a uio means building one in
   `_Sys_Read`'s record path AND putting `ptcread`'s body in the tty bank.
   The driver would leave pty.mod, against T4's whole charter.
2. *Let the tty bank copy to the caller's bank directly.*  It cannot.  Kernel C
   has no way to form a pointer into an arbitrary bank -- that is exactly what
   apple/fgx#234 made honest, since a runtime int-to-pointer cast now yields the
   LIVE data bank.  Every cross-bank move in this campaign goes through a shim
   (`kc_cdwrite`, `kc_uiomove`, `kc_ureadc`) for that reason.

**THE SEAM THAT WORKS IS THE ONE `tty_oproc` ALREADY USES.**  Its drain is

    cc = ndqb(&tp->t_outq, 0);          /* the next contiguous RUN */
    kc_cdwrite((int)tp->t_dev, tp->t_outq.c_cf, cc);
    ndflush(&tp->t_outq, cc);

-- ask the queue for a run, move it, tell the queue it is gone.  Increment 4
keeps that pair and reverses who calls it: the MASTER'S READ pulls the run
instead of `ttstart` pushing it.  `_PtyM_Read` stays in pty.mod, stays
assembly, and does the copy itself with an MVN from the tty bank into the
caller's bank -- which assembly can do and kernel C cannot.

    kc_ttoutq_run(idx)     -> A = c_cf offset, X = cc      (ndqb, no side effect)
    kc_ttoutq_flush(idx, cc)                               (ndflush + ttyowake)

The bank is the tty bank, which the core already resolves for every KTTY call.
`ttyowake` rides on the flush because that is where upstream puts it: `ptcread`
wakes a writer parked at hiwat once `c_cc <= TTLOWAT`, and the flush is the
moment `c_cc` drops.

**AND `t_oproc` BECOMES `ptsstart`, WHICH IS THE OTHER HALF.**  `ptsstart`
moves no data -- `if (t_state & TS_TTSTOP) return; ... ptcwakeup(tp, FREAD)` --
so it must be a TTY-BANK function, because `ttstart` calls it through the
function pointer in `struct tty` and a pointer cannot cross a bank.  `ptcopen`
installs it and `ptcclose` clears it (tty_pty.c:213, :231), which for FGX is a
slot: `kc_ptyoproc(idx, on)`, called from `_PtyM_Open`/`_PtyM_Close` beside the
`l_modem` calls increment 2 added.  Clearing to zero is upstream's own value and
`ttstart` already tests `t_oproc` before calling it -- "kludge for pty" is
upstream's comment on that very test.

**WHAT TURNS GREEN WITH IT**, and `ptyoutq` is already written to measure the
first one: `TIOCOUTQ` reports what is actually pending; `ttycheckoutq` waits on
a queue that can be over hiwat; `ttywait`/`ttywflush` drain something real, so
increment 3's close stops being vacuous on a pty; `ttyflush(FREAD|FWRITE)`
discards pending output at a hangup, so increment 2's carrier drop does what
`ttymodem` says it does; and `^S` holds output at the master's read, as
`ptcread`'s own `(tp->t_state&TS_TTSTOP) == 0` test does.

**STEPS 1 AND 2 ARE LANDED AND INERT** (`9cdcf07db`, `276415d3b`): the tty
bank has `ptsstart` and the three queue doors (slots 25-28), the core has the
four wrappers and `_Tty_OutqRead`'s ask-copy-tell loop, and `KSVC_TTYPTYOPROC`
/ `KSVC_TTYOUTQREAD` carry them to pty.mod.  Nothing calls any of it yet.

Two things were learned building them, and both are corrections to this plan:

**THE BANK COULD NOT AFFORD THE GUARD NINE TIMES.**  Every `kc_` door holds a
tty index and was open-coding the other half of `tty_find` -- the range test and
the bound test -- which by increment 4 stood NINE times in tty_dev.c.  With the
four new doors in, the tightest probe half had **224 bytes** left.  `tty_byidx`
is that pair once and gave back 429 bytes, taking half B to 653.  **The probe
ceiling is the binding constraint on this campaign again** (apple/fgx#233), and
it is the PROBE apparatus that is tight, not the product -- the shipping tty
bank has 15,849 free.  Shrinking the product to fit the test would be backwards;
the halves want re-splitting before increment 5 or 6 adds C to this bank.

**AND THERE ARE TWO READ PATHS, NOT ONE.**  The plan above says "the master's
read pulls the run", singular.  `_PtyM_Read` is the RECORD-mode syscall path and
delivers through `_Sys_RdBufOff`/`_Sys_CallerBank`, which is what
`_Tty_OutqRead` was built for.  **`_PtyM_DRead` is the `/dev` vnode path** --
cdevsw's `d_read`, apple/fgx#198's fix -- and delivers through a **uio** whose
base and bank live on its own stack frame.  Both drain the OutRing today, so
step 3 must convert both, and the two want different destinations from the same
queue.

**DECIDED: the second, uio-shaped door** (`kc_ttoutq_uio`, slot 29, landed at
`5da4b6345`).  Upstream's `ptcread(dev, uio, flag)` IS uio-shaped, so the uio
path is the BSD one and the record path is FGX's own; and it duplicates no queue
logic, because both doors go through `kc_ttoutq_run` and `kc_ttoutq_flush`.

**REJECTED: staging the uio's base and bank into the `_Sys_*` cells** so one
door serves both.  It reads cheaper and it is a driver writing statics its
signature never mentions -- apple/fgx#198's shape and #231's, twice paid for.

**STEP 3b IS THE FLIP AND IT IS ATOMIC ACROSS BOTH PATHS.**  `t_oproc` becoming
`ptsstart` stops the ring being fed, so a conversion that moved only
`_PtyM_Read` would leave `_PtyM_DRead` reading a ring nothing fills.  With it
go `_PtyS_Write` (whose only driver is `tty_oproc` draining, by its own header),
`_Pty_OutPut`, `PTYR_Out*` and the backpressure sleep in `@sw_putblk`.

**THE ONE THING 3b STILL HAS TO SOLVE, and the answer it should take:** a KSVC
has A and Y free (X is the service number) and the uio door needs THREE values
-- tty, uio offset, uio bank.  Pass `A = uio offset` and
`Y = (uio bank << 8) | tty INDEX`.  The index rather than the byte offset the
other five tty services take, because 0..4 fits in the spare byte and a
`TTY_SIZE`-scaled offset does not -- state that at the service, since an
inconsistent convention is its own trap.  `_PtyM_DRead` already holds the uio
as (offset, bank) at 9,S and 11,S.

### INCREMENT 4 IS LANDED (`45f1f2be4`, `5ba7abe2c`), AND PACKET MODE DECIDED IT

**THE ANSWER WAS TO STOP HAVING TWO DELIVERY CONVENTIONS.**  Everything below
about a fourth argument and a second service number is superseded: `ptcread`
writes its prefix with `ureadc(0, uio)' (tty_pty.c:275), so the destination has
to be a CURSOR, and a base with a length is not one.  `@rd_recfill` builds the
per-task uio `@rd_cdUio` already built for tty reads, both master-read paths go
through `kc_ttoutq_uio`, and the prefix costs no machinery at all.  The MVN loop
and its four statics were deleted having never had a caller.

**AND THE UIO IS IN THE U-AREA**, so it is per-task by construction -- nothing
parks anything across the master's sleep, where apple/fgx#231 had to, and
`_Tty_OutqRead`'s "safe for Model A's reason and no other" note disappears with
the routine.

    PTYOUTQ outq=0 ... RING      before
    PTYOUTQ outq=5 ... BSD       after

**THREE THINGS IT COST, ALL FOUND BY MEASUREMENT:**

1. **Every KSVC destroys X, and X is the pair offset.**  The oproc install
   indexed `_ptyTable,X` after the carrier call had overwritten X with 34, so it
   ran against a garbage line, took ENXIO and changed nothing -- and the only
   symptom was five bytes still arriving in the ring.  The tty-bank dump named
   it: `t_oproc` identical on all five lines.
2. **`ttywait` is a real wait now**, and increment 3's header guessed wrong
   saying the drain could not hang.  Reading the slave ECHOES into `t_outq`, and
   `ptsclose` -> `ttylclose` -> `ttywflush` then waits for a queue only the
   master's read can empty.  That is BSD's behaviour; `ptyflush` only ever
   avoided it because the ring absorbed the echo, and it drains the master first
   now.
3. **Select would have broken silently.**  `_PtyM_Poll` answered POLLIN from
   `PTYR_OutCount`, which is not fed any more and would read 0 forever.  No
   fixture covers select on a pty master.  It takes `ptcselect`'s own test
   (tty_pty.c:317) through the same door.

**THE ACCOUNT BELOW IS KEPT** because the reasoning that reached the wrong place
is the reasoning worth reading: three wrinkles in a row, each solved by
accommodating FGX's convention, and the fourth one only solvable by dropping it.

**AND THE THIRD WRINKLE WAS PACKET MODE, found while writing 3b.**  `_PtyM_Read`
in PKT mode writes a prefix byte as byte 0 of every read -- `TIOCPKT_DATA`, or
`TIOCPKT_FLUSHWR` once after a slave TIOCFLUSH -- so the record has to land at
`buffer[1]` with the count capped at `max - 1`.  `_Tty_OutqRead` reads
`_Sys_RdBufOff` and takes `max` in X, and has no way to be told "start one byte
in".  **It is live, not theoretical**: telnetd sets TIOCPKT, and telnetd is what
drives `ttypeneg`, `vipty` and `morepty`.

**THE PATTERN ACROSS ALL THREE WRINKLES IS THE KSVC CONVENTION.**  A service has
A and Y, X being the service number.  The uio door needed three values and was
solved by packing a tty INDEX into Y's spare byte; the record door with a packet
prefix needs four.  That is the constraint to design against, not a detail of
this increment.

Four ways, and the recommendation is the fourth:

1. Pack a skip flag into the high bit of the tty offset -- offsets reach 1,192
   so bit 15 really is free.  **REJECT**: a tag and a value sharing one 16-bit
   transport is the exact shape apple/fgx#234 spent most of a session on, where
   `0x8000 | (addr & 0x7FFF)` erased the bit that named the bug.
2. Have the driver bump `_Sys_RdBufOff` by one and restore it.  **REJECT**: a
   driver writing a static its signature never mentions, #198's shape again.
3. Pass a small argument block by address.  A new convention for one caller.
4. **A SECOND SERVICE NUMBER**, `KSVC_TTYOUTQREADP`, meaning "leave one byte for
   the packet prefix".  Explicit, no packing, no statics, and service numbers
   are append-only and cheap -- include/modules.s has been growing one at a time
   all campaign.  The arm differs from its sibling by two instructions.

**THE RING DOES NOT DISAPPEAR.**  `PTYR_InRing` is the input direction and it
stays until T6 -- it is the deferral the maintainer's 2026-08-22 divergence requires,
because nothing can run `ttyinput` at arrival time yet.  Only `PTYR_OutRing`
and `_PtyS_Write`'s backpressure sleep retire.

### INCREMENT 5 IS LANDED (`8861e7417`, `6689086da`), AND THE ROW WAS RIGHT TO WARN

**THE ROW PROMISED `ptyioctl` AND `ptyioctl` WAS ALREADY THERE.**  That is the
third time this table has named a port that FGX had built structurally, and the
warning written after the second one held: `syscall.s`'s `@si_cdGo` dispatches
the DEVICE's ioctl first and falls through to the discipline on ENOTTY, which
IS `ptyioctl`'s shape -- its master switch answers what is its own and hands
the rest to `ttioctl(tp, cmd, data, flag)`.  Reading the tree first is what
turned the increment into what it actually was.

**WHAT WAS MISSING WAS THE OTHER HALF OF PACKET MODE, and it was missing
because increment 4 had just made it matter.**  `pt_send` has two producers:

    ptsstop(tp, flush)   d_stop.  `flush == 0' means the line was STOPPED, so
                         PF_STOPPED goes on and TIOCPKT_STOP is armed;
                         otherwise `flush' IS the FREAD/FWRITE mask and ORs
                         straight in, because FREAD is 1 and TIOCPKT_FLUSHREAD
                         is 1, FWRITE is 2 and TIOCPKT_FLUSHWRITE is 2.
                         Upstream's own comment is the deciding line:
                         `/* note: FLUSHREAD and FLUSHWRITE already ok */'.
    ptsstart(tp)         t_oproc.  A line that had been stopped is running
                         again: PF_STOPPED off, TIOCPKT_START armed.

**THE PTY SLAVE'S d_stop SLOT WAS ZERO**, with the comment "a pty ring is not
in flight" beside it -- true while `tty_oproc` drained `t_outq` into the pair's
ring on every `ttstart`, and false the moment `t_oproc` became `ptsstart`.  A
pty slave line has output in flight now exactly as a serial line does.

#### The witness came first, and it measured a defect rather than a gap

`ptypkt` asks four questions with the first as its positive control (a data
prefix, proving packet mode is alive at all, without which every later -1 would
be a report about TIOCPKT).  On the tree as increment 4 left it:

    PTYPKT data    n=6  b0=0 b1=65    packet mode is alive
    PTYPKT flush   n=1  b0=2          the master IS told output was flushed
    PTYPKT flushed n=6  b0=0          ... and the five bytes are STILL THERE
    PTYPKT stop    n=-1 b0=0          no TIOCPKT_STOP
    PTYPKT start   n=-1 b0=0          no TIOCPKT_START

The third line is apple/fgx#239.  `_PtyS_Ioctl` answered TIOCFLUSH itself, by
dropping the pair's ring cursors and setting a hand-rolled FLUSHPEND bit -- and
the out ring is not fed any more, so the flush discarded nothing while the
status byte announced that it had.  Same class as the `_PtyM_Poll` regression
caught during increment 4: a consumer still reading the retired ring.

**THE MASTER IS NON-BLOCKING ON PURPOSE.**  A missing status byte leaves the
queue empty, and a blocking master hangs there, which names nothing -- the
poor-mutation shape this campaign has already paid for.  With FIONBIO the same
absence reads back as `n=-1` against an expected `n=1`, and the line says WHICH
of the four is missing.

#### The fix was to delete the arm, not to repair it

Upstream never answers TIOCFLUSH in the pty driver either.  Letting
`_PtyS_Ioctl` return ENOTTY routes it to `ttioctl` -> `ttyflush(tp, rw)` ->
`(*d_stop)(tp, rw)`, so the queue is really flushed AND `pt_send` gets its bits
from BSD's own path.  `PTYF_FLUSHPEND` -- a one-bit stand-in able to carry the
flush and nothing else -- retires into a real `PTYR_Send` word in the pair
record.

#### apple/fgx#240: kc_cdstop's shim had been reading its arguments one byte low

With the driver side complete, `flush` and `stop` still measured -1.
`_FarSh_CdStop` states its frame correctly -- `4,S = dev, 6,S = rw` above the
3-byte return address -- then reads `8,S` and `6,S` after pushing THREE bytes
(PHB is one, the PHA is two).  Its own comment shows the sum, "+1 PHB, +2 PHA",
against an offset of 8.  `_FarSh_CdIoctl` two screens up does the identical
arithmetic correctly for four arguments.

So every `ttyflush(FWRITE)` and every TIOCSTOP on every line dispatched d_stop
against **chardev $02** -- the return address's bank byte, after
`_Chardev_Stop`'s `AND #$00FF` -- with the flag arriving as `rw << 8`.  It was
invisible because the only device with a real d_stop body was the serial line,
so the wrong dispatch found a zero slot and returned silently.  `ttyflush`'s own
header records the expectation that produced -- "for every device but the serial
line it finds a zero slot and returns" -- which the defect satisfied by accident.

**A pty slave's d_stop is the first one a tty line was ever meant to reach**,
which is why increment 5 is what found it.  The fix makes `serial_stop`
reachable too; nothing in the witness drives the serial line, so that half is
unmeasured and the commit says so.

#### The one thing that could not follow: TIOCPKT_START, and where it went

`ptsstart` is in the TTY bank because `t_oproc` is a pointer inside `struct
tty` and a pointer cannot cross a bank.  `pt_flags`/`pt_send` are pty.mod's.
So the two halves of upstream's five-line body are in different banks, and the
half that touches driver state cannot follow the half that must live beside the
queue.

**A `d_start` SLOT IN cdevsw WAS CONSIDERED AND REJECTED.**  It would work --
`d_stop` already crosses exactly that way -- but BSD's cdevsw has no start
entry, because a start routine is per-LINE (`t_oproc`) and not per-device.
Adding one would be inventing a cdevsw entry upstream does not have, against
this design's own opening premise that there is no seam to invent.

**SO THE ARM IS EVALUATED AT THE ASK RATHER THAN AT THE EVENT**, out of the
same two facts: PF_STOPPED, which `ptsstop` records in the driver, and
TS_TTSTOP, which `kc_ttstopped` (KTTY slot 31, KSVC 40) carries across.
"Stopped once, and running now" is precisely what `ptsstart` tests eagerly.
Not observable anywhere else: `pt_send` has no consumer but this driver --
`ptcread` delivers it and `ptcselect` asks whether it is set, and both go
through the same door now.  **The WAKE stays eager**: `ptsstart` still calls
`kc_ptywake`, so a master parked in read(2) is woken by the restart as
upstream's `ptcwakeup(tp, FREAD)` wakes it, and finds the byte when it
re-tests.

`kc_ttstopped` is deliberately NOT folded into `kc_ttoutq_run`, which tests the
same bit: that one answers zero for a stopped line AND for an empty one,
because its caller asks "may I take bytes now".  A caller that must tell the two
apart cannot use a merged answer, and packing a flag into the count is
apple/fgx#234's shape.

#### Two smaller things the increment found

**A status byte goes ALONE, and the /dev read path did not.**  `ptcread`
RETURNS after its `ureadc` rather than falling into the dequeue, so the data
comes on the master's next read.  `_PtyM_Read` had always done that;
`_PtyM_DRead` delivered the prefix and then drained behind it.  Increment 4's
lesson is that the two paths must not differ.

**`_PtyM_Ioctl`'s TIOCPKT arm left the pair's flags word in A**, where
upstream's arm is `return (0)`, so a caller testing `!= 0` saw a failure on a
successful ioctl.  The fixture found it on its first boot.

#### DECLARING THE EQU IS NOT ASSIGNING THE SLOT

`include/ktty.s` named slot 31 and `ttybank.s` still had it inside the
`LUP KTTY_SLOT_COUNT-31` stub run, so the first call reached `_Ktty_StubHalt`
and the fixture stopped dead after three lines with **no verdict and no
failure** -- which is what a halt looks like from outside.  That is 8b's lesson
from the other side: the slot and its declaration are two edits, and a grep of
one does not cover the other.

**Slot 31 is the last of the reserved thirty-two.**  A thirty-third grows
`KTTY_SLOT_COUNT`, which moves where the bank's code starts but renumbers
nothing, because slot n is `KTTY_SLOT0 + 4n` and `KTTY_SLOT0` is fixed.

#### What increment 5 did NOT port, stated rather than dropped

- **TIOCPKT_NOSTOP / TIOCPKT_DOSTOP**, which upstream recomputes on EVERY ioctl
  from `t_stopc`, `t_startc` and RAW, and which nothing in this image consumes:
  telnetd sets TIOCPKT and then drops the status byte unread (telnetd.c:506).
  It would put a tty-bank round trip on every pty ioctl to feed a reader that
  does not exist.
- **TIOCUCNTL** and its `UIOCCMD` escape, which have no FGX counterpart at all.
- **`ptyioctl`'s discipline guard**, which closes and reverts a line whose
  `l_rint` is not `ttyinput`.  FGX has one discipline, so the condition cannot
  arise; `ttioctl`'s TIOCSETD already refuses a number past `nldisp` with ENXIO.
- **The TIOCSETP/TIOCSETN/TIOCSETD outq drain** in upstream's master switch,
  which exists so `ttywflush` cannot hang when the CONTROLLER issues an stty.
  FGX does not route those commands to the master at all (`@si_cdMW` forwards
  only the window-size pair, deliberately, apple/fgx#150), so the situation the
  drain prevents cannot arise here.  A slave stty still waits for the master's
  read, which is upstream's behaviour and not the hang that arm is about.

### INCREMENT 6 IS SETTLED: REMOTE mode is DECLARED, and the reason is structural

The row offered two outcomes -- port it, or declare it in the man page's BUGS
with the reason.  It is declared, and this is the evidence rather than the
preference.

**IT NEEDS A RECORD BOUNDARY THE WRITE PATH DOES NOT HAVE.**  Upstream's
`ptcwrite` REMOTE arm fills `t_canq` with `b_to_q` straight past the discipline
and then appends a single sentinel:

    while (uio->uio_resid && tp->t_canq.c_cc < TTYHOG - 1) { ... b_to_q ... }
    (void) putc(0, &tp->t_canq);

and `ptsread` drains *until one character is left* and discards it (`:126-131`).
The NUL is what makes one `write(2)` one record.  **FGX's chardev write is a
per-byte loop** -- `syscall.s:3908`, "FCB_FL_CHARDEV fd: per-byte
`_Chardev_Write` loop" -- and the pty master's `d_write` slot is `0,0,0`, "none
-- per-byte".  No byte in such a loop knows it is the last one, so the sentinel
cannot be placed.

**AND A BULK `d_write` WOULD NOT SETTLE IT**, which is the part worth writing
down because it looks like the obvious fix.  `COPS_DWrite` serves the /dev vnode
route (`jumptable.s` `@kc_cddwrite`); the SYSCALL route, which is the one a pty
master actually uses, stays per-byte regardless.  Remote mode waits on a record
boundary the write path lacks for EVERY chardev, which is a change well outside
this driver.

**NOTHING ASKS FOR IT, MEASURED IN BOTH TREES.**  `TIOCREMOTE` appears in
exactly two files in 2.11BSD -- `usr/sys/h/ioctl.h` and `usr/sys/sys/tty_pty.c`
-- and in two in FGX's, both vendored copies of those.  **2.11BSD's own `rlogin`
is vendored and does not use it.**  FGX's telnetd sets TIOCPKT and drops the
status byte unread (`telnetd.c:506`), so it is not a LINEMODE daemon either;
that is apple/fgx#143's business, and this is the note it will want.

**THE REFUSAL IS THE PORTED BEHAVIOUR, and it is pinned.**  The alternative to
implementing an ioctl is not silence -- it is failing the way an unsupported
command must.  A `TIOCREMOTE` that returned success would leave a caller
believing its next write went in as a record while the bytes were edited by the
very discipline remote mode exists to bypass.  `_PtyM_Ioctl` answers ENOTTY and
`@si_cdGo`'s fall-through finds a master is not a tty line, so ENOTTY is what
reaches the caller.  `ptyremote` measures exactly that -- `rc=-1 e=25` -- and
then writes and reads the pair, because a refused ioctl must also leave the
device undisturbed.  Mutation-verified: making the arm return 0 flips it to
`PTYREMOTE ACCEPTED`.

**AND THE DECLARATION IS GUARDED.**  `pty(4)` is a new page in a NEW manual
section -- FGX had cat1, cat2, cat3, cat5 and cat8 and nothing in section 4 --
and `tools/ninja/gen.py` picks sections up by globbing `cat[1-8]` at
build.ninja GENERATION time.  A regen that misses the directory drops the whole
section silently.  `manpty` greps the BUGS text itself rather than the NAME
line, so a page that went stale or truncated cannot pass it.

### T5 NEEDS NO PORT: `tty_tty.c` IS ALREADY IN, and this records the check

**READ THE TREE FIRST, for the FOURTH time.**  The campaign's task list has
carried "T5 `tty_tty.c`" since it was written, and the file was ported at
`a9c76016b` under apple/fgx#151 -- before the T-numbering caught up with it.
Increments 3, 5 and 6 each turned out to be smaller than their row promised for
the same reason; this one is not smaller, it is done.

**ALL FIVE UPSTREAM ROUTINES ARE COVERED**, checked one at a time against
`vendor/2.11BSD/usr/sys/sys/tty_tty.c` rather than taken from the file's own
header:

| upstream | FGX |
|---|---|
| `syopen` (:21) | `_SyTty_Open` + the path lookup |
| `syread` (:31) | `_SyTty_Read` (the ENXIO arm) + `_SyTty_Resolve` |
| `sywrite` (:42) | `_SyTty_Write` + `_SyTty_Resolve` |
| `syioctl` (:52) | `_SyTty_Ioctl`, TIOCNOTTY arm included, + `_SyTty_Resolve` |
| `syselect` (:70) | `_SyTty_Poll` + `_SyTty_Resolve` |

and the resolve is wired at all four dispatch points that need it --
`syscall.s:1746` (select), `:3720` (ioctl), `:3903` (write), `:4979` (read) --
so every op is covered and none is covered twice.

**THE PLACEMENT IS THE FGX DELTA AND IT IS ARGUED IN THE FILE.**  BSD reaches
its discipline THROUGH `cdevsw`, so `syread` can forward at the layer it was
called from; FGX reaches its discipline BY INDEX, so a `d_read` forward would
bypass the discipline entirely.  The substitution therefore happens one step
earlier, on the chardev index, where the FCB is read.  `docs/PROVENANCE.md`
carries that as the registered delta.

**ONE DIVERGENCE, DELIBERATE:** `syopen`'s forward to the real device's
`d_open` is not carried over.  The only thing it would accomplish for a tty is
`ttyopen`'s session claim, which is guarded on `p_pgrp == 0' and cannot hold
here -- a process with no group has no controlling terminal and took the ENXIO
arm already -- while the forward WOULD bump the target's `CD_OpenCount` and
postpone the real line's last close.

**Witness**: `devtty`, green.  It is the pair assertion, not a smoke test:
`tty=X` says /dev/tty resolved to the PTY rather than the console, and
`fd0=B` says both descriptors share the line's read cursor, which is what rules
out an independent second path to the device.

**WHAT IS ACTUALLY LEFT UNDER apple/fgx#151** is userland, not the tty layer:
`SYS_GETKEY`/`SYS_POLLKEY` still exist and eleven programs still call them, so
those read the PHYSICAL console whatever terminal they are on.  `more(1)` --
the canonical customer, and the reason the device exists -- has already moved
to 2.11BSD's own `read(2, &ch, 1)` idiom.  Three of the eleven (`ptykeyx`,
`nottykey`, `devttyx`) are FIXTURES that measure the bypass and must keep it.
The rest are demos and tools: fractal (12 sites), tip (5), robots, rdtimed,
worm, udpecho, ping, netdump.  That is #151's migration and it is not a port.

### T6 DESIGNED 2026-08-26: the second register file, and the bracket is already in

The last increment of apple/fgx#108.  Designed before it is written, as stage 3
and T4 were, and for the same reason: the code it moves is the only path by
which a key reaches a program, so a wrong guess presents as a machine that
takes no input and cannot say why.

**THE CHARTER, in the design's own words**
(`docs/history/plans/2026-08-22-tty-bsd-shape-placement-survey.md:358`):

> **T6 -- the second register file.**  Interrupt-time C gets its own `$98..$FF`;
> `ttyinput` returns to arrival time; `^S`/`^Q` become crisp and section 8's
> accepted divergence closes.  By this point it moves only WHERE `ttyinput` is
> called from -- the queue and the code are already upstream's -- which is the
> whole reason it is last rather than first.

The maintainer's ruling of 2026-08-22 (survey section 8) is what this closes: "**2b as
the increment, the second register file as the endpoint** ... The `^S`/`^Q`
cost is accepted for now, on the grounds that nothing is using serial ... until
the last increment lands, `t_stopc`/`t_startc` are honoured when a reader runs
rather than when the character arrives."  This is that last increment.

#### THE MEASUREMENT THAT SIZES THE WHOLE INCREMENT

**The `spl` bracket is ALREADY THREADED THROUGH THE PORTED CODE**, counted
2026-08-26:

    src/kernel/tty/tty.c        19 spltty()   31 splx()
    src/kernel/tty/tty_subr.c    8 spltty()   12 splx()

Every one is upstream's, at upstream's line, and every one is a no-op today:

    #define spltty()        0
    #define splx(s)                        -- ttyparam.h, as it read that day

That file already names itself the landing site: "THAT STOPS BEING TRUE AT T6
(apple/fgx#108) ... These two macros are where the real bracket goes on that
day; they are macros rather than nothing at all so the call sites stay
upstream's and the change is here."  **So T6 adds no bracket.  It gives two
macros bodies and 70 existing call sites start meaning something.**

That is the difference between this increment and the one the survey feared.
`vendor/2.11BSD/usr/sys/sys/tty_subr.c` brackets EVERY entry.  Read, not
inferred -- the function is on the first line, its `s = spltty()' on the second:
`getc' (29/:38), `q_to_b' (85/:99), `ndqb' (162/:171), `ndflush' (210/:221),
`putc' (273/:283), `b_to_q' (329/:345), `unputc' (450/:460), `catq' (502/:509).
The port kept all eight.

#### WHAT A "SECOND REGISTER FILE" ACTUALLY IS

**It is a value in D.  There is no compiler change.**  fcc's register file is
a set of DIRECT-PAGE OFFSETS -- `_fcc_fpr0 EQU $98` through `_fcc_ptr2 EQU $FC`
(`toolchain/lib/fcc_runtime.s:125-159`), with `_fcc_stkfloor` at `$B9` and
`_fcc_fb` at `$BB`.  Every access is direct-page addressed, so the file a given
C context uses IS whatever page D names.  The generated map already says how
wide it is: `KC_DP_LO EQU $98`, `KC_DP_BYTES EQU $68` (104 bytes,
`src/kernel/far/fcc_dp.s:50-51`).

So the entry macro is the whole mechanism.  `KTTY_KC_ENTER` ends

                LDA     #FGX_DP_KERNELC
                TCD

and an interrupt-time variant ends with a different constant.  Nothing else in
the toolchain knows or cares.

**BUT A SECOND CONTEXT IS NOT ONLY A REGISTER FILE.**  Three things are per-C-
context, and naming only the first is how this increment would be under-scoped:

1. **The register file** -- one page's `$98..$FF`, above.
2. **The hardware stack.**  fcc frames live on the stack, and the heartbeat
   runs on whatever stack it interrupted.  When it interrupts a task in KERNEL
   mode that is the per-pid kernel stack, `FGX_KSTK_SIZE` = 512 bytes, and the
   boot banner has measured it: `kstk: page 1 high-water $01BE (190 bytes
   spare)`.  Running `ttyinput` -> `ttyecho` -> `ttyoutput` -> `putc` on 190
   bytes is not a margin, it is a coin toss.  **The interrupt context gets its
   own stack**, which is what a real ISR has and what makes the stack-floor
   guard meaningful again.
3. **`_fcc_stkfloor`**, which lives at `$B9` of the page and therefore comes
   free with (1) once (2) gives it a floor to hold.

#### WHERE THEY GO IN BANK 0, AND THE ARENA DOES NOT MOVE

Measured 2026-08-26 with `tools/check_bank0_geometry.py`:

    arena $1A00 + 152p -> $B200,  kernel-C DP $B200,  DP pids 0..12 $B300..$C000
    per-pid kernel DPs $0900 + 13p -> $1600,  BLK_STAGE $1800

**`$1600..$17FF` is free -- exactly two pages**, and it is the tail of the
region `tools/ninja/genconfig.py` already describes as "the freed low region
... simply unclaimed for now".  One page for the interrupt kernel-C direct
page, one for the interrupt stack, and **nothing above `$1800` moves**: not
`BLK_STAGE`, not the arena, not `FGX_DP_KTASKS`, not `FGX_DP_KERNELC`.

That matters more than the two pages do.  Moving `FGX_DP_KERNELC` down would
shrink the arena, and `docs/bank0-blkstage-relocation.md` records why that is
not free: the B3 stack-attribution tests are coupled to first-fit allocation
OUTCOMES, not merely to addresses.  Taking the last two low pages costs
nothing anyone is measuring.

**It is exactly two, so the derivation must FAIL rather than overlap.**  The
per-pid kernel DP block is NPROC+1 pages from `$0900`, so it reaches `$1700` at
NPROC 13 -- eating the interrupt stack -- and `$1800` at 14.
`genconfig.py` already refuses the analogous collision with BLK_STAGE ("it does
not fail, it silently corrupts the buffer every SmartPort read stages through
-- apple/fgx#43, #45"), and the new pages get the same treatment there plus the
same independent re-check in `check_bank0_geometry.py`.

**AND NOT BECAUSE NPROC 13 IS ALREADY REJECTED.**  It is -- for the TCB table
against `FGX_CODE`, a different invariant on a different file -- and leaning on
that would make this guard's only evidence another guard.  apple/fgx#43 and #45
are what that costs: NPROC 12 moved the task count without moving BLK_STAGE and
the collision was silent.  Each block states its own wall.

#### THE THREE THINGS `ttyinput` REACHES THAT AN ISR CANNOT DO TODAY

Counted from `src/kernel/tty/tty.c`'s `ttyinput`, which calls `ttyflush`,
`putc`, `ttwakeup`, `ttyecho`, `kc_gsignal` and `kc_cdstop`.  The register file
answers none of these; they are the actual content of the increment.

**1.  `ttwakeup` -> `kc_wakeup` -> the scheduler.**  `src/kernel/toolbox.s:369`
states the constraint: "this heartbeat runs on the INTERRUPTED TASK'S direct
page, so it cannot reach `_schedTblPtr` and cannot call `_wakeup`".  Half of
that is now soluble -- `_FarSh_KernDP` reads `_kCurPid`, an absolute core-bank
global, so an ISR CAN select the kernel's real page -- but the other half is
real: `_wakeup` mutates run queues the interrupted task may be inside.

**BSD ANSWERS THIS AND FGX ALREADY MODELS THE ANSWER TWICE.**
`vendor/2.11BSD/usr/sys/sys/kern_clock.c:142`:

        if (needsoft && BASEPRI(ps)) {  /* if ps is high, just return */
                (void) _splsoftclock();
                softclock(pc,ps);
        }

`hardclock` does not run callouts, because a callout may call `wakeup()` and
that is not safe at clock priority.  FGX has this shape already, twice: the
heartbeat MARKS `_kLboltDue` and `_Lbolt_Wake` (sched.s) PERFORMS, and it marks
`_kTtySigPend` and `_Tty_DrainSigPend` (signal.s) performs -- both at the same
two kernel-DP sites.  **`ttwakeup`'s wake is a third tenant of that mechanism**,
not a new one, and `kc_gsignal` is the second thing above riding the same rail.

**2.  Echo, which on FGX is SYNCHRONOUS.**  `ttyecho` -> `ttyoutput` ->
`ttstart` -> `(*t_oproc)`, and FGX's `tty_oproc` "is `dzstart' AND `dzxint'
collapsed into one call" (tty_dev.c) -- it paints the screen before it returns.
An ISR that echoed would re-enter the console engine underneath a task already
inside it, and `spltty()` cannot help: the console write path is core-bank
assembly that never calls it.

**Upstream does not do this either, and that is the point.**  `dzstart` hands a
run to the silo and RETURNS; `dzxint` finishes it on a later interrupt.  So
arrival-time echo upstream reaches the QUEUE, not the wire.  T6 keeps that:
the ISR's `ttyinput` fills `t_outq` and marks the line, and the drain through
`t_oproc` happens at the soft site in task context.  **That is upstream's
asynchrony re-created, not an FGX shortcut** -- and it is stated here rather
than left to be discovered, because the visible consequence is that echo
appears at the next kernel entry rather than within the tick.

**3.  `kc_cdstop`, the `^S` path -- and this one is already fine.**
`_FarSh_CdStop` was fixed at apple/fgx#240 and `far_shims.s:668-670` already
saves and restores `_cdArgFlag`, written early and dead until now precisely so
"the increment that moves `ttyinput` does not have to find this first".  Same
for `_FarSh_CdIoctl` at `:494-496`.  T6 is what those two save/restores were
for; they stop being insurance and start being load-bearing.

#### WHAT `spltty()` AND `splx()` BECOME

On the 65816 the only interrupt-priority mechanism is the I flag, so:

    spltty()   PHP / SEI / pull the old P, return its I bit
    splx(s)    if s says I was clear, CLI

The VBL heartbeat is an IRQ, so `SEI` genuinely holds it off; the tick stays
pending and fires when I clears.  The regions are `tty_subr.c`-sized -- a
cblock link edit -- so the cost is a few microseconds a call, not a dropped
tick.

**They are a TTY-BANK LOCAL, not a cross-bank seam.**  `kc_*` seams pay a shim
crossing because they reach core state; these touch only P, so they are two
short routines beside the others in `kc_sys.s`, reached by `JSL` within the
bank.  A cross-bank crossing per `putc` would be the whole increment's cost in
the wrong place.

#### THE INCREMENT ORDER

Each lands green with a witness, as every increment of this campaign has.

**1.  THE CONTEXT, WITH NOTHING USING IT.**  The second DP page, the interrupt
stack, their geometry derivation in `genconfig.py`, their independent check in
`check_bank0_geometry.py`, the zeroing beside `_KcDp_Zero`, and an
`KTTY_KC_ENTER_IRQ` bracket.  Nothing calls it yet.
**Witness: a nesting probe.**  Enter tty-bank C, seed the register file with a
known pattern, enter tty-bank C AGAIN through the interrupt bracket, run
something that uses `$98..$FF` hard, return, and assert the outer pattern is
intact.  **The mutation is one constant**: point the interrupt bracket at
`FGX_DP_KERNELC` and the probe must go RED.  That is a test that can fail for
the reason it exists, which is what `feedback_fgx_test_must_discriminate` asks
of it.

**2.  THE BRACKET MADE REAL.**  `spltty()`/`splx()` get bodies; 70 call sites
start meaning something and nothing else changes.  Still no interrupt-time
`ttyinput`, so behaviour is identical and the whole 53-fixture witness is the
regression test.  This is deliberately its own increment: if a real `spltty`
breaks anything, it breaks it HERE, where the only change is the bracket.

**AND IT HAS A LANDMINE, FOUND BY READING AND NAMED HERE SO IT IS NOT FOUND BY
HANGING.**  `ttyunblock` takes `s = spltty()` and NEVER CALLS `splx(s)` --
`vendor/2.11BSD/usr/sys/sys/tty.c:252`, and FGX carried it verbatim because
carrying an upstream dead store verbatim was the right call while the macros
were empty.  It stops being a dead store the moment they are not: `spltty()`
becomes `SEI` and nothing ever clears I, so the VBL never fires again.  **THE
HEARTBEAT IS THE VBL** -- the quantum, `lbolt`, the keyboard scan and the
signal latch all stop -- so the symptom is a machine that goes quiet, with no
verdict and no failure, which is the hardest shape this campaign has met.

It is REACHABLE, not theoretical: two call sites in the ported `tty.c`
(upstream :206 and :1274, the second inside `ttread`), both behind `TS_TBLOCK`,
which `ttyblock` sets when the input queue fills.  Rare, which makes it worse
-- a latent hang that appears under load and not in the suite.

**SO INCREMENT 2 OWES A STATIC CHECK, not just a fix.**  One unbalanced
`spltty()` is a hang; the tree should not rely on having read them all once.  A
`tools/check_spl_balance.py` in the shape of `check_hb_scratch.py` -- every
function that calls `spltty()` reaches `splx()` on every path out -- is what
makes that a build error rather than a field report.  Upstream's own divergence
gets stated in the routine and in the man page's BUGS, as every other one has.

**3.  THE WAKE AND THE SIGNAL ON THE SOFT RAIL.**  `ttwakeup`'s wake and
`kc_gsignal` become mark-and-perform through the two existing kernel-DP drain
sites.  Still driven by the pump, so still task context, so still green --
this increment moves WHO PERFORMS, not who calls.

**4.  THE FLIP.**  The heartbeat calls `ttyinput` for the line the keystroke
belongs to.  The pump goes (`tty_dev.c:476-478`), `kc_getbyte`/`kc_pollbyte` go
(`kc_sys.s:413-419`), the two `_FarSh_Tty*Byte` export slots go
(`gen_kernel_exports.py:92-95`), `ttbgread`'s reason to exist goes
(`tty.c:1694-1697`), and `PTYR_InRing` goes (`pty.s:555-558`) so `ptcwrite`
feeds the discipline directly as `vendor/2.11BSD/usr/sys/sys/tty_pty.c:439`
does.  `_kTtyFlushPend` goes with them: the heartbeat's INTR latch exists only
because "the discipline never sees it", and after this it does.

**THIS IS THE ONE WITH THE HISTORY.**  Read "Stage 4a, ATTEMPTED 2026-08-25"
above before writing a line of it.  Console fixtures are not evidence for this
increment: stage 4a passed smoke and EVERY console fixture and still failed all
four pty/VC fixtures, because "the pty and VC paths are DEEPER".  The four to
watch are `morepty`, `ttypeneg`, `vipty` and `vivc`, and they are the ones to
run first, not last.

**5.  WHAT IT CLOSES.**  The maintainer's `^S`/`^Q` divergence (ROADMAP:1064-1067), and
the unpumped-input flush question (this file, "What is still open") -- which
answers itself once no input is unpumped.

#### WHAT T6 IS NOT

**Serial.**  The survey's own last word: "`ttyinput` for SERIAL ... Giving the
serial line an `l_rint` is a seventh increment, and it is the one that makes
section 8's accepted `^S`/`^Q` divergence matter -- so it belongs after T6, not
before."  `serial_isr` fills `_sccRxBuf` and `serial_read` pops it; those bytes
still meet no discipline when T6 is done.

**A compiler change.**  See above: the register file is a D value.  If this
increment finds itself editing fcc, something has been misunderstood.

#### TWO STALE COMMENTS IN THIS PATH, LEFT UNFIXED ON PURPOSE

Both say the opposite of the tree and both would mislead the increment that
touches them.  Recorded here instead of patched, because T6 rewrites those
regions and a comment fix now is churn T6 would delete.

- `src/kernel/syscall.s:5463-5468` calls `_kTtyRdPtr` "SHARED, and another task
  may run its own discipline read (retargeting the cell) while this one
  sleeps".  `include/kernel.s:584` documents PER-PID KERNEL DIRECT PAGES --
  `page(pid) = FGX_DP_KKERN + (pid<<8)` -- and names the shared page as the
  thing apple/fgx#41 and #100 WERE.  The cell is per-task; `far_shims.s:199` is
  right and the PEI/PLA is belt-and-braces.
- **apple/fgx#108's own comment cites `include/kernelc.s:342` for the singleton
  text.  It is at 518 now.**  Do not chase 342.

### T6 INCREMENTS 1 AND 2 ARE LANDED (`a281b1380`, `8bc25b21c`)

Both gate green on all five probe halves, witness 53/53.  What the design above
got right is not recorded here; what it did not is.

**INCREMENT 1 -- the context.**  `FGX_DP_KERNELC_IRQ` and `FGX_STK_KIRQ`, above
the per-pid kernel stacks in the language card, derived in `genconfig.py` and
re-checked independently in `check_bank0_geometry.py`.  `KTTY_KC_ENTER_IRQ`
switches DBR, D and S; `_KcDpIrq_Zero` zeroes the page and SEEDS its stack floor,
which makes it the first working fcc stack guard in this kernel.

**THE DESIGN PUT THE PAGES IN THE WRONG PLACE AND MEASURING MOVED THEM.**  It
said `$1600..$17FF`, two free pages in bank 0's low region.  True, but the
LANGUAGE CARD has 1,504 bytes spare above the stacks at NPROC 12 and nothing
growing into them, so both blocks went there and bank 0's contended end was left
alone.  What made that visible was reading `genconfig.py`'s ceiling test, which
computes the per-pid stack block at **256 bytes a task** and has done since
apple/fgx#172 made it 512 -- only `check_bank0_geometry.py`'s independent rule
caught the NPROCs it let past.  A computation that is merely OVERRULED is not
one to derive a new address from.  It reads the size now and the two files hold
their copies equal.  NPROC caps at 13 rather than 14.

**AND THE WITNESS FOUND TWO THINGS READING COULD NOT.**  `_KcIrqProbe`'s first
callee was `kc_ttstopped`, on the reasoning that any C exercises the register
file; fcc kept the whole routine in A/X/Y and wrote not one promoted-local slot,
so the case went red.  `src/kernel/far/kc_probe.c` warns about exactly that in
advance -- "A function that only added its two arguments would pass with no
direct page at all" -- which is the second time that paragraph has been paid
for, and `kc_irqprobe` is built to touch the file as its far twin is.

Then case 3 -- "the inner register file was written" -- **PASSED VACUOUSLY**.
It scanned the whole band, and `_KcDpIrq_Zero`'s floor seed is a 16-bit store
spanning `$B9-$BA`, so its high byte lands in a word that a skip aimed at `$B9`
does not cover.  One non-zero word answered the question by itself, and a
mutation that erased every trace of the call still reported OK.  It reads the
NAMED register band now.  Both were found by mutation, neither by review.

**INCREMENT 2 -- the bracket.**  `kc_spltty`/`kc_splx` in `kc_sys.s`, tty-bank
local because they touch nothing but P.  `ttyunblock` gained the `splx(s)`
upstream does not have, argued in the routine.  `tools/check_spl_balance.py`
holds the rule with a self-test per arm -- including the arm that matters most,
because its first draft read `tty_dev.c`'s PROSE about `spltty()` as code and
reported a confident second leak that was not there.

**THE 53 FIXTURES STAYED GREEN AND THAT IS NOT EVIDENCE.**  Nothing about
behaviour was meant to change, so a suite that would look identical against the
empty macros proves nothing about the bracket.  `kc_splprobe` (KTTY slot 34) is
the case that can go red: it asks the bracket through its own return value and
answers 44 real, 0 empty.  Measured both ways.  Its first red run reported
**case 0**, because the case number was loaded before the call and fcc returns
with Y holding whatever it last used -- so the probe's own reporting is verified
now rather than assumed.

**THE ECHO CLUSTER MOVED FROM HALF A TO HALF E.**  The bodies cost the tty bank
866 bytes and took half A 172 over its ceiling.  Cases 130-159 went across
whole, keeping their numbers, and were measured red by mutation in their new
home so the move is not a silent drop of thirty cases.

    ttyprobe  (A) 3,648 free     ttyprobe4 (D)   534 free  <-- the tightest now
    ttyprobe2 (B) 3,011 free     ttyprobe5 (E) 4,580 free
    ttyprobe3 (C)   938 free     shipping tty 13,949 free

**HALF D IS THE NUMBER TO WATCH NOW, NOT HALF A.**  Increments 3 and 4 add to
this bank again.

**ONE MORE STALE COMMENT FOR THE LIST.**  `tty_dev.c`'s pump argues its ordering
from "FGX's `spltty()' is empty (ttyparam.h), so the discipline has no other
protection; the shape is what provides it".  That stopped being true at
increment 2.  Left alone: increment 4 deletes the pump.

### INCREMENT 3 MEASURED AND LANDED (`5e4f1b065`): two brackets, and the rail
### is for the one the row never mentioned

The design above said increment 3 puts `ttwakeup`'s wake and `kc_gsignal` on the
mark-and-perform rail `_Lbolt_Wake` and `_Tty_DrainSigPend` use.  **That row is
wrong**, and the two things it turned on were measured rather than argued.

#### 1.  `_wakeup`'s HEADER IS A CLAIM, AND THE CLAIM IS FALSE

`sched.s:708` says *"Callable from mainline OR an ISR (short, no alloc)"*.  All
sixteen call sites were enumerated and their interrupt state read:

    far_shims.s:187  _FarSh_Wakeup      NONE      <-- this IS kc_wakeup
    far_shims.s:555  _FarSh_SelWakeup   NONE      <-- and this is kc_selwakeup
    signal.s:494     _Kill_Apply        NONE
    signal.s:1441    _scs_dispatch      NONE
    process.s x3     _kfp959/_kfp109    NONE
    sched.s:171-197  swtch              NONE (its CALLERS hold SEI by contract)
    sched.s:477-494  swtch_nosave       CLI@446 SEI@448 -- the idle loop's
    sched.s:789      _Lbolt_Wake        NONE
    jumptable.s:638  _Sys_KCallImpl     NONE      <-- the KSVC

**NOT ONE MASKS ON ITS OWN.**  `_wkChan` (`sched.s:1110`) is a bank static, so
an ISR entering `_wakeup` on top of an interrupted one replaces the channel
mid-scan -- and the outer scan then compares its REMAINING slots against the
wrong channel.  A task blocked on the outer channel is never marked READY.
**That is a lost wakeup, which is a hang**, and the two paths that reach it
unmasked are exactly the two `ttwakeup` takes.

So the header is aspirational.  An unchecked claim drifts, and this one had.

#### 2.  WHAT IS ACTUALLY ON THE PATH: fifteen singletons, three clusters

Walked from the core-bank entry points `ttyinput` reaches, following calls to
depth 8 and reporting every store to a named global:

| cluster | cells |
|---|---|
| the wake (`_FarSh_Wakeup`, `_FarSh_SelWakeup`) | `_wkChan` |
| the signal (`_FarSh_Gsignal`) | `_kPgid`, `_kSigByteIdx`, `_kSigMask`, `_kgfHits`, **`_shTmp1`**, and `_wkChan` again through `_Kill_Apply` |
| the chardev dispatch (`_FarSh_CdStop`) | `_cdArgFlag`, `_cdDispEntryOff`, `_cdDispMinor`, `_cdDispOpsBank`, `_cdDispOpsLo`, `_cdStopBank`, `_cdStopIdx` |

**`_shTmp1` IS apple/fgx#235 ONE CELL OVER.**  `_Kill_GroupFanout` parks the
signal number there, and `toolbox.s`'s own header forbids exactly that: "DO NOT
touch shared DP scratch (`_shTmp*` / `_libcTmp*` / `_fsTmp*`); the body fires
asynchronously w.r.t. any in-flight kernel call."  **And
`tools/check_hb_scratch.py` CANNOT SEE IT**: it scans the heartbeat body's own
lines in `toolbox.s` and does not follow calls, so the guard's scope stops
exactly where increment 4 extends the body.  Widening it is increment 3's work.

**AND THE "DEAD INSURANCE" COVERS ONE CELL OF NINE.**  The design section above
says `_FarSh_CdStop`'s and `_FarSh_CdIoctl`'s save/restores "stop being dead
insurance" at T6.  True, and nowhere near sufficient: they save `_cdArgFlag`,
the ARGUMENT channel, and nothing saves the DISPATCH state underneath it.

#### 3.  SO THE ANSWER IS THE ONE INCREMENT 2 ALREADY GAVE THE CLISTS

**LANDED at `5e4f1b065`**, with `check_spl_balance.py` gaining an assembly rule
that fails the build if either routine stops masking, and `check_hb_scratch.py`
widened to FOLLOW CALLS -- its old scope ended exactly where increment 4 extends
the heartbeat body.  That widening is **armed, not firing**: measured, the
heartbeat reaches four routines today and `_Kill_GroupFanout` is not among them.
The script says so itself, so the allowlist entry is not misread as evidence.

**FOR TWO OF THE THREE CLUSTERS, YES.**  Both were measured NON-BLOCKING -- no
`sleep`, no `swtch`, no `WAI` on any path, at depths 1 and 3:

    _wakeup             PHP/SEI ... PLP     -- and its header becomes true
    _Kill_GroupFanout   PHP/SEI ... PLP     -- takes _shTmp1 with it

Four bytes each, inside the routine so all sixteen call sites are unaffected,
and it is **upstream's model exactly**: `dzrint` calls `wakeup()` straight from
the receive interrupt (`examples/2.11BSD/usr/sys/pdpuba/dz.c`), protected by
nothing but priority level.

**THE CHARDEV CLUSTER CANNOT BE BRACKETED, AND THAT INVERTS THE ROW.**
`_Chardev_Dispatch` SELF-MODIFIES: it patches `_cdTrampReadOp+1/+3` and then
`_cdTrampJSL`, which `include/memmap.s:1772` declares as `DS 5` at `$03B8` --
**one shared five-byte JSL cell, "patched per dispatch"** in its own words
(chardev.s:501).  So the critical region does not end when the staging does; it
runs through the `JSL _cdTrampJSL` at chardev.s:490, which is the DEVICE CALL.
An ISR dispatching `d_stop` inside a task's read repoints the trampoline that
task is about to jump through -- a wild jump, not a lost wakeup.

And it cannot be masked either, for the reason section 4 gives: bracketing a
dispatch means bracketing whatever the device does, and for the console that is
a screen paint.  Holding the VBL off for the length of a scroll is not a
bracket, it is a stall.

**SO `^S` -> `d_stop` IS THE ONE THING THAT GOES ON THE RAIL** -- the ISR marks,
a soft site performs -- and it goes there for 2.11BSD's own stated reason
(`kern_clock.c:142`: hardclock defers because a callout may call `wakeup()`,
which is not safe at clock priority).  **The design's row named the wake and the
signal as the rail's tenants.  Measuring says those two are exactly the ones
that do NOT need it, and the one it did not mention is the one that does.**
That half is increment 4's work regardless, since nothing reaches `d_stop` from
an interrupt until the flip.

#### 4.  AND IT MAKES THE ECHO DEFERRAL LOAD-BEARING RATHER THAN TIDY

`_FarSh_CdWrite` carries `_cdArgByte`, `_ttyRunPtr` and the same `_cd*` dispatch
cluster -- but it is NOT on this list, because the design already decided that
the ISR's `ttyinput` fills `t_outq` and MARKS, with the drain through `t_oproc`
happening at the soft site in task context.  That decision was argued from
upstream's shape (`dzstart` reaches the silo, not the wire).  **This measurement
is what makes it mandatory**: FGX's console `t_oproc` paints the screen, and a
bracket around a screen paint would hold the VBL off for the length of a scroll.
Bracketing is only cheap because the long thing is not on the path.

### INCREMENT 4 DESIGNED 2026-08-26: it splits, and NOT the way stage 4a split it

The flip.  Designed before it is written because it is the increment with a
history: stage 4a wrote the whole input side, passed smoke and **every console
fixture**, and failed **all four** pty/VC fixtures with one signature.  The
lesson recorded there is that "the pty and VC paths are DEEPER", so a green
console is not evidence for this work.

#### THE SPLIT, AND WHY IT IS BY MECHANISM RATHER THAN BY LINE

The obvious split is console first, pty second.  **That is the wrong one**, and
stage 4a is the proof: it would deliver a green console and tell us nothing
about the paths that actually break.

The right seam is one stage 4a never drew.  The two producers `ttyinput` will
have are not two lines -- they are **two execution contexts**:

| | producer | context | risk it carries |
|---|---|---|---|
| **4a** | `ptcwrite`, i.e. `_PtyM_Write` | **TASK** -- a `write(2)` on the master | the discipline plumbing only |
| **4b** | the heartbeat | **INTERRUPT** | everything increments 1-3 built for |

Stage 4a changed both at once and therefore could not say which half was wrong.
Split here and 4a exercises the DEEP paths -- every pty fixture -- with **no
interrupt-time C at all**.  If it goes red, the cause is the discipline
plumbing, because nothing else moved.

#### 4a: `ptcwrite` FEEDS THE DISCIPLINE, AND IT IS A DELETION

`vendor/2.11BSD/usr/sys/sys/tty_pty.c:439` is the whole of what a master write
does with a byte:

        (*linesw[tp->t_line].l_rint)(*cp++, tp);

FGX puts it in `PTYR_InRing` instead and the pump takes it out.  **`_PtyM_Write`
is the SOLE producer** -- `pty.s:1097` says so in as many words ("This is the
only producer into the InRing, `_Pty_InPut` has one caller") -- so this is a
move, not a second path.

What goes with it:

- `PTYR_InRing`, `_Pty_InPut`, `_Pty_InGetNB`, the three `PTYR_In*` cursors and
  `_ptyInRings` -- the other 128 bytes a pair, after increment 7 took the out
  half;
- the syscall side's pty drain, which is what `_Pty_InGetNB_RTL` exists for;
- **apple/fgx#57's hand-coded INTR/QUIT test (`pty.s:1088-1100`)**, which the
  design table already lists as subsumed.  It is a KSVC crossing PER BYTE
  written to the master today, and `ttyinput` does the same job as its own
  `if (CCEQ(tp->t_intrc, c))` arm.  So 4a is a speed-up as well as a deletion.

**WHAT IT MUST NOT DROP: the backpressure.**  Upstream's loop is not a bare
`l_rint` -- it is guarded (`tty_pty.c:433-438`):

        if ((tp->t_rawq.c_cc + tp->t_canq.c_cc) >= TTYHOG - 2 &&
           (tp->t_canq.c_cc > 0 || tp->t_flags & (RAW|CBREAK))) {
                wakeup((caddr_t)&tp->t_rawq);
                goto block;
        }

`_Pty_InPut` answers `C=0` when the ring is full and `_PtyM_Write` blocks on
that, so FGX HAS this behaviour today through a different mechanism.  Dropping
the ring without porting the TTYHOG test replaces "block until the slave reads"
with "silently discard once the clist pool is dry", and **nothing in the suite
would notice**: no fixture writes a master faster than its slave reads.  A
witness for that is part of the increment, not an extra.

**Witnesses**: every pty fixture, and they are the ones to run FIRST --
`morepty`, `ttypeneg`, `vipty`, `ptyrec`, `ptykey`, `ptynb`, `ptyhup`,
`ptyflush`, `ptyrace`, `ptyoutq`, `ptypkt`, `ptyswsel`, `ptyeintr`,
`loopback_pair`, `devtty`.  Plus a NEW one for the backpressure, because none
of those can see it.

#### 4b: THE HEARTBEAT, AND THE FORK IT HAS TO SETTLE FIRST

`ttyinput` at arrival needs everything increments 1-3 built, and it needs one
question answered that the design has never asked: **after the flip, who owns a
keystroke?**

`_kKbdRing` is FOUR things today, and only the first of them goes away:

1. **the buffer between arrival and the discipline** -- consumed by the pump;
2. **the readiness answer for a raw/cbreak line** (`_Tty_PollReadable`,
   `ttyv.s:252`, falls back to `_kKbdRingCount`);
3. **the VC focus queue** -- shared across consoles, and `_Tty_GetByte`'s
   `@tgb_vcWait` (`syscall.s:5506`) sleeps until the reader's VC is on screen,
   because "THE RING IS SHARED -- every console would otherwise see every
   keystroke as its own";
4. **`SYS_GETKEY`/`SYS_POLLKEY`'s source**, which apple/fgx#151 CLOSED by ruling
   that these stay as a console primitive, with `ptykeyx` and `nottykey` as the
   fixtures that measure the bypass.

(2) and (3) DISSOLVE, and that is the good news.  The heartbeat already computes
which line owns a keystroke -- it does it for `^C` today, `_kVcActive` ->
tty[0]/[3]/[4] -- and its own comment names the upstream shape: "this is BSD's
`dzrint(4)', which binds a character to its line before the discipline ever sees
it".  Bind at arrival and each line's `t_rawq` holds only its own bytes, so the
focus gate has nothing left to gate and readability is just `t_rawq`.

**(4) IS THE FORK.**  The getkey primitive still needs bytes in a ring, and a
keystroke cannot go to both without changing what programs see:

- **Feed both.**  Simplest.  `fractal` keeps taking bytes from the ring, and the
  same bytes also land in tty[0]'s `t_rawq` -- so quitting fractal hands the
  shell everything typed during it.  That IS type-ahead, which is what a real
  terminal does, and it makes the documented "bypass" literal.  But it is a
  visible behaviour change to existing programs.
- **Route by consumer.**  Feed the ring only when a getkey consumer is active.
  Correct, and it does not work: `SYS_POLLKEY` is non-blocking and `fractal`
  polls, so at the instant of the keystroke there is no waiter to detect.
- **Convert the callers.**  apple/fgx#151 explicitly REFUSED this: `ptykeyx` and
  `nottykey` exist to measure the bypass and converting them deletes the
  coverage.  Not available.

**DECIDED (the maintainer, 2026-08-26): FEED BOTH.**  Asked as a behaviour question
about shipped programs, and the answer was *"you can break fractal if you need
to.  We are the only users of the system currently."*  So the heartbeat binds
the keystroke to its line and calls `ttyinput`, AND keeps pushing to
`_kKbdRing` for the getkey primitive apple/fgx#151 ruled stays.  One producer,
two consumers, and the "bypass" those fixtures measure becomes literal.

**WHAT THAT COSTS, STATED RATHER THAN DISCOVERED.**  Type-ahead becomes real,
which is what a terminal does -- and for a program that reads keys WITHOUT
reading its tty, the bytes it consumed also accumulate in `t_rawq` and reach
the next reader.  Worse for a full-screen one: tty[0] is cooked with ECHO on
unless a program clears it, so `ttyinput` will ECHO keystrokes over an SHR
display.  `fractal` is the program that shows it, and the real fix is the one a
real program makes -- turn echo off -- rather than anything in the kernel.

**THE SURVEY PRICED THIS IN ADVANCE** and called it accepted: "Echo timing --
already paid.  BSD echoes inside `ttyinput`, so typing appears while a
compute-bound process runs; FGX echoes in `_RdOp_Console`, so it appears only
while something is reading."  What was NOT predicted there is that it lands on
a graphics screen, so it is written down here.

4a does not depend on any of it, which is a third reason the split is where it
is.

### T6 INCREMENT 4a: WHAT THE RETIREMENT SURVEY FOUND BEFORE THE RETIREMENT

The ring's deletion was surveyed first -- six symbol groups traced, each
verdict then attacked by a second pass told to refute it.  **Four of the six
refutations landed, and three of them were LIVE DEFECTS rather than deletion
hazards.**  The deletion itself is still pending; this is what came out of
looking.

**TWO POLL ARMS WERE READING THE DEAD RING** (fixed, `7b61f57d5`).
`_PtyS_Poll` took POLLIN from `PTYR_InCount`, pinned at 0 since the flip -- so
select said "not readable" forever while the bytes sat in `t_rawq`, and a
select-driven reader on a pty slave went deaf.  `_PtyM_Poll` took POLLOUT from
`PTYR_InCount < PTY_RING_SZ`, which for a pinned-at-zero count is "always
writable" while `_PtyM_Write` refuses at TTYHOG.

**THAT IS THE THIRD TIME**, and the pattern is now worth naming: increment 4
caught `_PtyM_Poll`'s POLLIN, increment 7 caught `_PtyS_Poll`'s POLLOUT, and 4a
broke BOTH remaining arms at once in opposite directions.  **Every increment
that stops feeding a queue must ask what still READS it** -- a poll op is the
one that never shows up in a witness, because a fixture that does not select is
green either way.  `ptysrsel` covers both directions now.

**AND A THIRD, NOT FIXED: apple/fgx#241.**  A master's TIOCFLUSH answers out of
the same dead ring, so it announces a flush and discards nothing -- #239's
surviving half.  #239's own route does NOT work here and that was measured: a
master is not a tty line, so declining the ioctl answers ENOTTY rather than
falling through to `ttyflush`.  Upstream calls `ttioctl` on the SLAVE'S tp
(tty_pty.c:526).  An attempt through a new `KSVC_TTYFLUSH` still returned -1
and was reverted rather than left unverified.  The issue carries the evidence
and the fixture case that was written for it.

**WHAT THE SURVEY CONFIRMED, so the retirement can proceed on it:** the ring
IS dead.  `_Pty_InPut` has no callers; `_Pty_InGetNB`'s only reachable route is
through `_Tty_GetByte`/`_Tty_PollByte`, whose sole callers are the two far
shims, which answer -2 before entering.  Both groups survived their refutation.

**ONE PREMISE THE SURVEY PUNCTURED AND THE RETIREMENT MUST RESPECT:** "a pty
line has a nonzero `TTY_Backend`" is NOT universally true -- `_PtyS_Close`
clears it (`pty.s:1669`).  The -2 gate therefore does not hold for a line whose
slave has closed, and any reasoning that leans on it must say what happens
then.

### T6 4b: THE FLIP IS BLOCKED, and what blocks it invalidates increment 1

**apple/fgx#242.**  Increment 1 put interrupt-time kernel C's register file at
`$FA00` and its stack at `$FB00`-`$FCFF`, "in the LANGUAGE CARD above the
per-pid kernel stacks".  **Bank 0 `$D000`-`$FFFF` is not the kernel's RAM while
the firmware Heartbeat Interrupt Handler is dispatching**, so the whole context
is unreachable from the one interrupt it exists to serve.

Measured from inside the heartbeat body, store-then-read-back, one tick:

| address | region | read-back |
|---|---|---|
| `$00FCF0` | `FGX_STK_KIRQ` | **FAILS** |
| `$00FA98` | `FGX_DP_KERNELC_IRQ` | **FAILS** |
| `$00EFF0` | `FGX_STK_KTASKS` | **FAILS** |
| `$00D100` | LC switchable bank | **FAILS** |

**IT PRESENTS AS A DEAD KEYBOARD, NOT A CRASH.**  Boot completes, the shell
prompts, and the first keystroke wedges the heartbeat inside the bracket:
`_kSystemTicks` frozen at 1,349 with the frame counter at 6,901, the emit
entered once and never left, and the ring at 0 where stubbing the emit gives 5.
The arguments the C reads are ROM -- `idx = $8001`, `c = $C995`.

**AND `_KcIrqProbe` PASSES, ALL TWELVE CASES**, because it runs at boot in TASK
context where the language card is banked in.  Nothing had ever executed
`KTTY_KC_ENTER_IRQ` from an actual interrupt: increments 1, 2, 3 and 4b steps 1
to 3 all validated it from the wrong side of the very distinction the bracket
is named for.  **A probe that cannot run in the context under test is not
coverage for that context**, and this one could not, by construction.

#### CORRECTED BY REVIEW, same day -- four sub-conclusions did not survive

The measured core stands and is corroborated three ways: the sentinels, the
garbage C arguments (`idx=$8001, c=$C995` is what an argument fetch off a
ROM-mapped stack yields), and the wedge signature (an RTL pulling a ROM return
address).  **What was written around it was wrong in four places.**

**"THE OBVIOUS FIX MAKES IT WORSE" WAS UNSUPPORTED, and the run refutes it.**
The force sat at `@hb_emGo`, on the KEYSTROKE path, while `_kSystemTicks` is
incremented at the top of the body every tick -- and that run reported **ticks =
0**, so the body never executed once and the `LDAL $E0C08B` never ran.  The
death had another cause (most likely a stale image: it followed a merlin32
SIGBUS pair, and the test "passed" only because its sole assertion was
`screen_lacks PANIC` against a blank screen).

**AND THE MACHINE ITSELF CONTRADICTS THE FATALISM.**  Syscalls run with IRQs
unmasked, so VBLs land while S is inside the LC-resident per-pid kernel stacks;
the CPU pushes that frame INTO LC RAM (`include/kernel.s:285-288`, "an IRQ
pushes onto the INTERRUPTED stack before any emulation-mode switch") and every
such tick RTIs correctly.  **The firmware flips the mapping and hands it back,
sixty times a second.**  So the honest statement is "read-mapped to ROM for the
duration of the dispatch, and restored before RTI" -- not "someone else's".

**"THE SPACE IS COMMITTED" WAS FALSE.**  `arena_pages = (dp_kernelc - arena) //
256` is pure `derive()` arithmetic (`genconfig.py:193`) whose own next line says
"this is the arithmetic floor, not the ceiling anyone will meet".
`check_bank0_geometry.py` enforces aliases and the `$C000` ceiling and says
nothing about arena headroom.  Three more pages takes `CFG_STK_ARENA_PAGES`
from 152 to 149 -- it costs three pages of USER STACK ARENA, a real price but
an available one.

**AND `$C011`/`$C012` IS THE WRONG PAIR.**  Write-enable is not readable at all
-- "The only way that you can find out whether or not the language-card RAM is
write-enabled is by trying to write" (IIgs Hardware Reference ch.3, quoted at
`boot_console.s:136-140`).  The in-tree idiom saves STATEREG bit 3 (`LDAL
$E0C068 / AND #$08`) and restores by RE-RUNNING the double `$C08B` read:
`boot_console.s:142-161`.

**THE FOURTH DIRECTION IS PROBABLY THE RIGHT ONE:** do the save/force/restore
INSIDE the bracket -- `KTTY_KC_ENTER_IRQ` saves STATEREG bit 3 and double-reads
`$C08B`, `KTTY_KC_LEAVE_IRQ` restores per the saved bit.  About eight
instructions, on the emit path only, no geometry change, and it KEEPS the
at-arrival property the increment is named for.  The `boot_console` idiom
mirrored, not new mechanism.  (A fifth -- owning the VBL vector directly -- was
tried and retired once, `toolbox.s:82-84`.)

**THE EVIDENCE HAS THREE DEFECTS OF ITS OWN**, and they are recorded rather
than quietly fixed: the preserved diff contains THREE sentinels, not four
(`$00FA98` appears nowhere in it, verified), so that row rests on an
unpreserved build; `_hbTmpE` is double-booked in that diff, so the `$00D100`
row is only interpretable given `_hbTmpD` = 0; and **there is no positive
control** -- a harness defect inverting the CMP sense yields the identical
all-FAIL table.  The corroborating arguments rescue the conclusion; the table
alone does not carry it.  Also: this is EMULATOR evidence, and the 2026-08-13
real-hardware LC validation was TASK context.

**THE PATTERN IS WORTH NAMING.**  This is the second heartbeat-context
"unreachable" claim corrected in one day -- `27fdf3859` measured that the
heartbeat CAN reach `_schedTblPtr`, refuting `toolbox.s:370`.  The difference
is that this one's CORE was measured and everything around it was not.

**WHY IT STAYED INVISIBLE:** the heartbeat has only ever touched the kernel bank
and bank-0 LOW memory (`KFGX_YIELD_MIRROR`, `$00030A`).  The flip is the first
thing to ask it for anything else.

Steps 0, 1 and 2 are landed and green; step 3 is reverted and kept as
`docs/history/wip/T6-4b-flip.diff.pending`.

### T6 4b STEP 3 IS LANDED (`9a0966d60`): `d_stop` joins the rail

`d_stop` is the last thing `ttyinput` can reach that dispatches a chardev, so
it defers the way output does.  `kc_cdstop` is a C wrapper now -- it marks when
`tty_irq` is set and calls the assembly seam, renamed `kc_cdstop_now`, when it
is not.  **THE PORTED CALLERS DID NOT CHANGE**: the guard is in FGX's own seam.

**TWO ROUTES REACH IT FROM `ttyinput` AND BOTH ARE LIVE** -- the `^S` arm
directly (`tty.c:1085`), and the INTR arm through
`if ((t_flags&NOFLSH)==0) ttyflush(tp, FREAD|FWRITE)` (`tty.c:818`).
`ttymodem` and `ttioctl` reach it only in task context, where the wrapper is a
pass-through.  A stop is DEFERRED, not dropped: TS_TTSTOP is set by the caller
first and takes effect at once, so nothing new is queued meanwhile.

**Cases 9-12** drive it: `^S` defers, the drain performs the stop alone, `^Q`
restarts, the drain performs that.  `^Q` is not tidiness -- leaving TS_TTSTOP
set on tty[0] would stop the boot log for good and present as a hang somewhere
else entirely.

#### Three things this step cost, and all three are about the PROBE

**THE PROBE'S POSITION IS LOAD-BEARING AND MOVED TWICE.**  It now runs after
`_Tty_Chars`, because `t_stopc` is **ZERO** until that call seeds it, so `CCEQ`
was false and `ttyinput` skipped the stop arm entirely.  It had already moved
after `_TtyDevInit` because `tty_byidx` refuses an unbound line.  **A case that
fails because the machine is not ready yet looks exactly like a case that fails
because the code is wrong** -- which is why the probe prints the VALUE it got,
and why `got 65535` and `got 0` were each settled in one build.

**AND THE HUNT WENT TO THE WRONG PLACE BECAUSE TWO ASSERTIONS SHARED A NUMBER.**
`case 9 got 0` was the SECOND check, not the first: `_Tty_DrainOutPend`
fast-outs on `_kTtyOutAny` and the probe had not set it.  **The fault was in
the probe**, while four measurements went into `ttyinput`, which was innocent
throughout.  This routine's own case-4 note already said a number over more
than one assertion names the group and not the failure; it now has one number
per assertion.

**A SHARED HELPER READ ITS ARGUMENT OFF A STACK THAT NO LONGER EXISTED.**
`KTTY_KC_ENTER_IRQ` MOVES S to the interrupt stack, so the caller's pushes are
unreachable after it.  The byte rides in Y, which the macro leaves alone.

### T6 4b STEPS 1 AND 2 ARE LANDED (`d6ad53dc3`, `75bf0af7c`)

**Step 1: the door.**  `kc_ttyinput(idx, c)`, KTTY slot 38 -- resolve the line,
call its `l_rint`.  It is 2.11BSD's `dzrint` and nothing more, and it is
`kc_ptcinput` MINUS the hog arm: `ptcwrite` has a WRITER to push back on, a
receive interrupt has nobody, and `ttyinput` carries its own overflow handling
anyway (bell then drop, `vendor/2.11BSD/usr/sys/sys/tty.c:994` inside
`ttyinput` at `:791`, ported at `tty.c:1168`).  Landed inert.

**Step 2: the output rail, and ITS PERFORM HALF WAS ALREADY IN THE TREE.**  The
ISR cannot paint the screen, so the discipline running at interrupt time fills
`t_outq` and marks; a soft site performs.  The mark is **TS_TIMEOUT**, upstream's
own "output is deferred and something will restart it" bit, which `tty_oproc`'s
first line already treated that way.  The perform is **`ttrstrt`** --
`t_state &= ~TS_TIMEOUT; ttstart(tp)` -- **ported at `tty.c:251` with NO
CALLER**, because upstream reaches it through `timeout()`.  `kc_ttdrain` (slot
39) is that caller.  No invented state, no new bit.  **THAT IS THE FIFTH TIME
THIS CAMPAIGN HAS FOUND THE ROW'S WORK ALREADY DONE.**

**WHY DEFER, AND IT IS TWO REASONS.**  `_Chardev_Dispatch` self-modifies
`_cdTrampJSL`, so an ISR dispatch repoints the trampoline a task is about to
jump through.  Save/restore around the ISR's own dispatch would fix *that* and
still be wrong: FGX's console `t_oproc` PAINTS THE SCREEN, and a scroll inside
the heartbeat holds the next VBL off for the length of the paint.  Upstream
splits the same way -- `dzstart` reaches the silo, not the wire.

**BOTH DRAIN SITES ARE LOAD-BEARING.**  A cooked line wakes its reader on a
LINE DELIMITER, so between the first keystroke and Enter there may be no syscall
at all; with only `_Sys_CheckSignal` draining, every character typed before the
newline would echo in a burst when the line was submitted.  The swtch idle loop
is the other.

**AND ENTERING C FROM THE IDLE LOOP IS SAFE -- a second stale comment, the same
shape as the heartbeat's.**  signal.s says of `_kTtyFlushPend` that "one of that
routine's two callers is the swtch idle loop, where entering the shared kernel-C
register file is not safe".  **That predates apple/fgx#204.**  `_KcDp_Save`
(`sched.s:297`) is unconditional now and runs before the pick, `_KcDp_Rest`
(`:390`) runs only on the pick's success path, and the idle arm `@sw_none`
(`:435`) sits between them and re-enters `@sw_pick` when done -- so the shared
band belongs to nobody there: the outgoing task's copy is already in its slot
and no incoming task's has been restored.  The older comment is left alone; its
own cell was not re-measured.

**THE WITNESS IS `_KcIrqProbe` CASES 6-8**, end to end with nothing reaching the
screen: `kc_ttyinput(0, 'x')` answers 1 = deferred, `_Tty_Flush` empties both
queues (`ttyflush` leaves TS_TIMEOUT alone), `_Tty_DrainOutPend` restarts
exactly one line and clears the summary.  **Without the rail that same call
would paint an `x` across the boot log, which is what makes it runnable at boot
at all.**  Mutation-verified: delete the guard and it reports `case 6 got 0`.

**THE PROBE PRINTS THE VALUE IT GOT NOW**, and that is what found the first
failure: `case 6 got 65535` said `tty_byidx` had refused an UNBOUND line, so
`_KcIrqProbe` moved to after `_TtyDevInit`.  Cases 1-5 do not care where they
run; case 6 is why that order is load-bearing.  Three sub-checks, three case
numbers -- a single number over three assertions names the group and not the
failure, which this routine already learned once when case 4 reported "case 0".

**WHAT 4b STILL OWES:** the `d_stop` rail (`kc_cdstop` must mark at interrupt
time, the same shape as the output half), then THE FLIP -- the heartbeat calls
`kc_ttyinput` and the pump stops -- then retiring `kc_getbyte`, `kc_pollbyte`,
the two `_FarSh_Tty*Byte` slots and `ttbgread`'s reason to exist.

### T6 4b MEASURED 2026-08-27: the heartbeat CAN reach `_schedTblPtr`

The increment table said 4b puts `^S` -> `d_stop` on the mark-and-perform rail.
It did not say what happens to the SIGNAL half, and `ttyinput` signals:
`gsignal` -> `_FarSh_Gsignal` -> `_Kill_GroupFanout`, whose header states its
one precondition -- **"D = the kernel's REAL direct page; `_Kill_GroupFanout`
is DP-safe only on it, and it reaches the scheduler table through
`_schedTblPtr`"** (`far_shims.s:589-590`).  `_schedTblPtr` is a DP long-ptr at
**$A4** (`dpmap.s:285`).

The heartbeat's own comment answers it, twice, and it is the claim that had to
be tested rather than believed:

> FGX HAS THE SAME CONSTRAINT FOR A DIFFERENT REASON: this heartbeat runs on
> the INTERRUPTED TASK'S direct page, so it cannot reach `_schedTblPtr` and
> cannot call `_wakeup` -- the same reason the keyboard wakeup lives in swtch's
> idle arm and not here.

**A probe in the heartbeat body sampled every tick**, into kernel-bank
absolutes -- never shared DP scratch, which `check_hb_scratch.py` forbids and
is right to.  Two opposite workloads, because one alone could not tell "the
dispatcher zeroes D" from "user code happened to be running":

| workload | ticks | offKern | mismatch | last D | pid | kernel page |
|---|---|---|---|---|---|---|
| `spin &` -- pure userland busy loop | 1,693 | **1,693 (100%)** | **1,693 (100%)** | `$0000` | 11 | `$1400` |
| `ls` x5 -- syscall-heavy | 2,341 | **2,341 (100%)** | **2,341 (100%)** | `$0000` | 7 | `$1000` |

    ambient      _schedTblPtr = $000000      (both runs)
    kernel-page  _schedTblPtr = $40:732E     (both runs, both pids)

**THE PREMISE IS RIGHT IN EFFECT AND WRONG IN DETAIL.**  The heartbeat does not
run on the interrupted task's direct page.  It runs on **PAGE ZERO**, 4,034 of
4,034 samples, across a workload that is almost never in the kernel and one
that almost always is -- so D at heartbeat time is set by the firmware
Heartbeat dispatcher and says nothing about what was interrupted.  Page zero's
$A4 is `000000`, the null `_schedTblPtr` that `_Task_SeedKernDP`'s comment
warns a zeroed page would produce; cross-checked against the harness's
independent `direct_page` region rather than taken from the probe alone.

**THE CONCLUSION IS FALSE.**  `_schedTblPtr` is one `TCD` away.
`FGX_DP_KKERN + (_kCurPid<<8)` -- the identical computation `_FarSh_KernDP`
performs -- yields a page whose `_schedTblPtr` reads `$40:732E`, and the probe
read it from inside the heartbeat 4,034 times, restoring D unconditionally
afterwards.

**AND THE POINTER IS PID-INDEPENDENT**, which is the fact that makes the switch
safe: pid 7 and pid 11 both answered `$40:732E`, because `_Task_SeedKernDP`
MVNs the whole 256-byte template rather than zeroing ("A zeroed page would give
the task a null `_schedTblPtr` and a null `dev_table_ptr`").  So the ISR does
not have to know which task it interrupted for the pointer to be right.

**SO 4b's SIGNAL HALF NEEDS NO RAIL.**  `_Kill_GroupFanout` masks since
increment 3 -- which is what stops the ISR landing inside a task-context
fan-out, and was the increment's purpose -- and the page it needs is reachable.
`^S` -> `d_stop` still needs the rail, for the unrelated reason that
`_Chardev_Dispatch` self-modifies one shared five-byte trampoline
(`memmap.s:1772`), which no direct-page switch can fix.

**THE POSITIVE CONTROL IS `offKern`.**  Had it come back near zero, the probe
would have been sampling ticks that already ran on a kernel page and the
`mismatch` column would have meant nothing.  100% on both workloads is what
makes the two `_schedTblPtr` columns a comparison rather than a coincidence.

**AND THE PROBE FOUND A HARNESS DEFECT ON THE WAY IN**, fixed at `85408dfa2`:
`_kernel_symbol`'s greedy `.*\|` walked past the listing's source-line column
to a pipe inside an OPERAND -- Merlin's force-absolute prefix -- so
`_hbDpKernSched` resolved to the address of the instruction that mentioned it
and the region dumped four bytes of opcode as data.  The first reading of this
measurement was taken through that bug.

### T6 INCREMENT 4a IS COMPLETE (`cdb8b7bb0`): the in ring is retired

**385 BYTES OF THE CORE BANK CAME BACK** (57,199 -> 56,814 used, 1,154 free).
Gone: `_Pty_InPut`/`_Pty_InGetNB` and their `_Pty_RingSel`, `_Pty_InGetNB_RTL`,
the three `PTYR_In*` cursors, `_ptyInRings` (256 of the 385), the core's
`_Pty_InGetNB` stub and `_ptyInGetSite`, `_Pty_FlushRings`, syscall.s's
`@tgb_pty` and `@tpb_pty`, and `PTY_RING_SZ`/`PTY_RING_MASK` -- a pty's
buffering is NCLIST's question in both directions now.  Vtable directory entry
+4 is **zeroed, not closed up**; the pair record's fields are removed outright,
which is increment 7's distinction and holds for the same reason.

**`_ptyOpsOK` WENT WITH IT, AND IT HAD BEEN WRITE-ONLY SINCE INCREMENT 7.**
The byte meant "`_Pty_LoadOpsPtr` has patched everything", and its only readers
were the two stub routines that guarded their patched JSL sites with it --
`_Pty_OutPut` (retired at increment 7) and `_Pty_InGetNB` (retired here).  For
a whole increment it was set on every boot and asked by nothing.  **This is the
campaign's standing rule running backwards:** "every increment that stops
feeding a queue must ask what still reads it" usually finds a stale READER, and
here deleting the last reader is what left a WRITER dead.  Grepping for the
reader is what found it either way.

**THE PUNCTURED PREMISE IS NARROWER THAN THE SURVEY SAID.**  The warning was
that `_PtyS_Close` clears `TTY_Backend` (`pty.s:1669`), so the far shims' -2
gate does not hold for a line whose slave has closed.  Reading the tree: that
cell has exactly **two writers** -- `_Pty_SlaveTtyInit` sets it,
`_Pty_MaybeReset` clears it -- and the reset fires only when `PTYF_MOPEN` and
`PTYF_SOPEN` are **both** clear, which is to say when no fd exists on either
end to read through.  `pty.s:1669` is `_Pty_PktSend`'s comment block.  The gate
therefore holds wherever a read can reach it.

**THE UNREACHABLE ARM KEEPS ITS TEST ANYWAY**, and that is a deliberate few
bytes.  `_FarSh_TtyGetByte` reads the same `TTY_Backend` one instruction
earlier and answers -2 without entering, and the two far shims are
`_Tty_GetByte`'s only callers -- so `@tgb_notpumped` cannot run today.
Deleting the test instead of the arm would drop a pty line into the VC arm
below it, where it would sleep for a keystroke aimed at the visible console and
**eat it**.  A retired path answers; it does not fall through.

**AND THE ZEROED DIRECTORY ENTRY BUYS NOTHING TODAY**, which the comment now
says rather than implying otherwise.  `_Pty_LoadOpsPtr` does read that
directory at fixed offsets, but +4 and +6 are the last two entries, so removing
them would slide nothing.  The zeros keep the rule true for the next entry
appended at +8, which would slide.  The rule is right; this instance of it is
convention, not load-bearing, and saying so is cheaper than a future session
re-deriving it.

**apple/fgx#241 IS UNCHANGED AND MORE VISIBLE.**  A master's TIOCFLUSH used to
zero three cursors that had been pinned at zero since the flip, so the "flush"
was already a no-op wearing three stores; now it is a wake and a comment naming
the issue.  Upstream flushes the SLAVE'S queues (`ptyioctl` -> `ttioctl` on the
slave's tp, `vendor/2.11BSD/usr/sys/sys/tty_pty.c:524`, `:526`).

**WHAT A REOPENED PAIR NEEDS CLEAN IS THE DISCIPLINE'S QUEUES.**  `ttyclose`
already empties them -- `ttyflush(tp, FREAD|FWRITE)` is its first statement,
`vendor/2.11BSD/usr/sys/sys/tty.c:695-702`, ported at `tty.c:849` -- so
`_Pty_FlushRings` lost both callers rather than gaining a replacement.

Gate green, witness 55/55, both at `cdb8b7bb0`.

### What is still open

**UNPUMPED PTY INPUT SURVIVES A FLUSH**, and increment 5 deliberately did not
move that into `ptsstop`.  `ttyflush` calls d_stop only under `rw & FWRITE`
(tty.c:179), so an input-only flush -- `^C`'s, `ttywflush`'s, `ttyclose`'s --
never reaches the driver at all.  Upstream has nothing to flush there because
its receive interrupt has already emptied the silo into `t_rawq`; FGX's in-ring
holds arrived-but-unpumped bytes precisely because there is no receive
interrupt until T6.  It is that divergence, not this increment's, and it wants
deciding with the rest of T6 rather than half-answered here.

### Stage 4a, ATTEMPTED 2026-08-25: reverted, and what it established

The input side was written, built and measured, then **reverted** rather than
committed at 24/28.  Stage 1c's revert is the precedent and the reason is the
same: most of it was right, and what was wrong is not obvious.

**THE SHAPE WAS RIGHT AND IT WORKED.**  `l_read` -> `ttread`, `l_rint` ->
`ttyinput`, and `l_open`/`l_close`/`l_modem` -> the ported routines, so no
adapter was left in the table.  A seam `kc_ttread` PUMPS the line before it
reads it -- pulling one byte at a time from the core's `_Tty_GetByte` and
handing it to `l_rint` exactly as a receive interrupt would -- because FGX has
no interrupt that can run a line discipline until T6.  The core's byte SOURCE
stays where it is: the VC focus gate, which stops a shell on an unseen console
eating keystrokes aimed at the visible one, has no upstream counterpart to port
TO.

**smoke PASSED, and so did every console fixture.**  The shell prompted, read
`ls /`, echoed it through `ttyecho` -> `ttyoutput` -> the stage-3 write path,
and printed the listing.  `novi`, `novidraw`, `rawintr` and `viinsert` -- all
console readers, including RAW mode -- passed.

**IT DELETED 1,587 BYTES OF CORE BANK** (57,703 -> 56,116, 1,852 free): the
canonical gather, the erase/kill rubout, the echo trio, `_Tty_PollByte`, and
`TTY_CanonBuf` itself, which at TTY_CANON_SZ 256 x NTTY was 1,280 bytes.

**WHAT FAILED: the four pty/VC fixtures** -- `morepty`, `ttypeneg`, `vipty`,
`vivc` -- with one signature.  **The FIRST character of every line arrived as
garbage, a DIFFERENT value each run** ("root" came back "Zoot", then "$oot"),
while the rest of the line was intact.  `login` therefore failed and the test
sequence walked off.  Console reads were clean throughout, which is the
discriminator: the pty and VC paths are DEEPER.

**Three defects were found and fixed on the way, and they are real:**

1. **`_Sys_RdMax` IS NOT PARKED ACROSS A SLEEP.**  `_Tty_GetByte`'s header
   names three SYS_READ singletons it saves because its waits yield --
   `_Sys_RdRem`, `_Sys_BytesRead`, `_Sys_CallerBank` -- and RdMax is not among
   them, because nothing read it after a wait until the seam computed
   `RdMax - resid`.  A stale 1024 over a five-byte line reported 1024 bytes
   read.  The write side's `@sw_cdErrPop` note describes the identical trap and
   says why parking one operand of a subtraction and not the other turns a lost
   count into a FABRICATED one.
2. **`ureadc` refused UIO_USERSPACE** where `uiomove` beside it accepts it --
   an asymmetry introduced at stage 3.  With it in place `ttread` delivered
   nothing at all.  **Fixed and committed** (`1c2497795`).
3. **`catq`'s `bbuf[CBSIZE*4]` is 112 bytes on the 512-byte task kernel
   stack**, and fcc reserves the frame on entry even for the branch that
   returns without using it.  **Fixed and committed**, ahead of its caller.

**WHAT IT IS NOT, ruled out by measurement rather than by argument:** the
`_Sys_RdMax` staleness (fixed, and the counts came right while the bytes stayed
wrong); `catq`'s `bbuf` (shrunk to 16, no change); `catq`'s `*to = *from`
struct assignment, which is apple/fgx#199's exact shape and was the best
hypothesis -- replacing it with three field copies changed nothing.

**WHAT IT MOST LIKELY IS: apple/fgx#230.**  A different garbage value each run,
in a fixed POSITION, only on the deeper paths, from a bank whose kernel C
compiles with fcc's stack guard OFF.  Stage 3 met the same signature and it was
the stack both times.  And the guard cannot help find it: fcc emits one for
only 3 of this bank's 31 functions -- `ttread`, `ttyinput`, `ttyecho` and
`catq` are all `_STKGUARD EQU 0` -- and **even those never fire, because
`_KcDp_Zero` leaves `_fcc_stkfloor` at 0 and a floor of zero passes every
test.**  That is a second finding about #230: the guard is not merely off in
this bank, it is inert everywhere kernel C runs.

**SO STAGE 4 IS BLOCKED ON apple/fgx#230, which is what this file already said
and what the attempt then talked itself out of** on the grounds that `ttread`
has no bulk buffer.  It does not; the DEPTH is the problem, not one array.
Settle #230 first -- the guard made real (which needs a per-task
`_fcc_stkfloor`), the buffers moved off the stack, or a bigger
`FGX_KSTK_SIZE` -- and the increment above should go in largely as written.

### The stage 3 design, as it was written beforehand

Kept because the parts it got right are the parts worth reusing, and because
what it MISSED is listed above.

### Stage 3, DESIGNED BEFORE IT IS WRITTEN: the write side

Stage 2 is landed and this is the next increment.  It is written here first
because it has an open shape that stages 1 and 2 did not, and because the code
it replaces is the only path by which the machine can say anything -- a wrong
guess presents as a blank screen with no console to report it, which is the
failure mode apple/fgx#225 cost a session to.

**THE OPEN QUESTION.**  `_WrOp_Console` is not a byte loop with some decoration
around it.  It brackets the whole write in FGX-specific console machinery:
`_Vc_ConWriteEnter` (apple/fgx#129 -- a VC switch remaps the live engine, so
unbracketed writes paint into whichever console is on screen),
`KFAR_CON_HIDECURSOR` once around the loop so per-byte cursor renders do not
fight it, and the scroll-coalescing batch that arms `VT_RENDER_STATE` at the
top and flushes one `Con_RenderAll` at the bottom (apple/fgx#136).  None of
that has anywhere to live in `ttwrite -> ttyoutput -> ttstart -> (*t_oproc)`
IF `t_oproc` is called per character.

**UPSTREAM ANSWERS IT, AND THE ANSWER IS THAT `t_oproc` IS NOT PER CHARACTER.**
Read `dzstart` (`examples/2.11BSD/usr/sys/pdpuba/dz.c`), which is the canonical
shape:

    if (tp->t_state & (TS_TIMEOUT|TS_BUSY|TS_TTSTOP))  goto out;
    if (tp->t_outq.c_cc <= TTLOWAT(tp)) { ...wake TS_ASLEEP, selwakeup... }
    if (tp->t_outq.c_cc == 0)                          goto out;
    if (tp->t_flags & (RAW|LITOUT)) cc = ndqb(&tp->t_outq, 0);
    else {  cc = ndqb(&tp->t_outq, 0200);
            if (cc == 0) { cc = getc(&tp->t_outq);
                           timeout(ttrstrt, tp, (cc&0x7f)+6);
                           tp->t_state |= TS_TIMEOUT; goto out; } }
    tp->t_state |= TS_BUSY;  ...hand the RUN to the device...

`ndqb` returns a CONTIGUOUS RUN, not a byte.  A start routine moves a run at a
time and the transmit-done interrupt (`dzxint`) flushes it with `ndflush` and
calls start again.  So the bracket belongs around the RUN, and the console's
`t_oproc` is `dzstart` and `dzxint` COLLAPSED INTO ONE CALL, because FGX's
console write is synchronous and there is no transmit interrupt to come back
on: write the run, `ndflush` it, loop while the queue is non-empty.  `TS_BUSY`
is set and cleared inside that call and is never observable, which is what a
polled driver does rather than a divergence.

Everything that needs is already ported and green: `ndqb` (`tty_subr.c:231`),
`ndflush` (`:269`), `getc` (`:121`), `TTLOWAT` (`tty.h:427`) and the
`TS_TIMEOUT`/`TS_BUSY`/`TS_ASLEEP` bits (`tty.h:172-178`).

**So the shape is forced, not chosen:**

    console t_oproc     bracket ONCE (Vc_ConWriteEnter, HideCursor, arm the
                        batch), then loop { ndqb -> KFAR_CON_WRITE the run ->
                        ndflush }, then unbracket and flush one Con_RenderAll.
    pty-slave t_oproc   `ptsstart' (`tty_pty.c:163') and nothing more -- it
                        does NOT drain.  It clears PF_STOPPED and wakes the
                        master, and the master's READ does the draining out of
                        `t_outq'.  That is the half FGX already has as the pty
                        output ring, so this one is a repoint rather than a
                        port.

**THE COOKED DELAY ARM IS NOT OPTIONAL EVEN THOUGH FGX HAS NO DELAYS.**
`ndqb(&tp->t_outq, 0200)` stops at the first byte with the high bit set, which
is how `ttyoutput` encodes a delay, and the `cc == 0` arm is what schedules
`ttrstrt`.  FGX's `ttyoutput` is the ported one, so it CAN enqueue such a byte;
a start routine that used `ndqb(q, 0)` unconditionally would send the delay
marker to the screen as a character.

**THE `uio` CROSSING ALREADY EXISTS -- CHECKED, and this corrects the first
draft of this section, which called it an open question.**  It is not:

- `ttwrite` ALREADY CALLS `kc_uiomove(cp, cc, uio)` (`tty.c:2030`), and
  `ttread` calls `kc_ureadc` (`:1770`, `:1828`).  Both shims are written
  (`kc_sys.s:82`, `:127`) and both hop out to `uiomove`/`ureadc` in vfs.mod --
  two banks away, which `kc_uiomove`'s header spells out as forced.
- `include/chardev.s:101-112` defines the `struct uio` field offsets for
  assembly readers and PINS THEM ON THE MACHINE (rc 81 for `uio_resid`, rc 83
  for `uio_rw`).
- `KSVC_CDDREAD`/`CDDWRITE` already carry a uio across a bank boundary:
  "A = uio offset, Y = (uio bank << 8) | chardev idx".

So the bank does not need a new mechanism; stage 3 wires `l_write` to the one
that is there.  What IS untested is narrower and `include/chardev.s` says so
itself, in its own words: the `d_read`/`d_write` argument offsets are "NOT YET
EXERCISED ... they are read off three call instructions, which is not the same
as having watched an op fetch its argument."  Eight bytes of return address sit
above the op's frame -- three calls, not one -- so an op reads its arguments at
`9,S`, `11,S`, `13,S`.  That note also records the trap: an op CANNOT validate
its own frame, because a deliberately-wrong-by-two offset stayed green (the
wild read returned zero, which reads as UIO_READ).  **A first-byte assertion is
the only check worth anything there.**

**The one thing genuinely still open: what `_Tty_BgWriteGate` becomes.**
`ttwrite` carries upstream's own background gate, so the core's must go rather
than run twice -- but the core one is what `tostop` and `contostop` measure,
and its EINTR-instead-of-restart divergence is documented at `signal.s:1222`.
Read that note before deleting anything.

**Witness**: `smoke` first and by itself -- if the console cannot print, nothing
else in the suite means anything -- then the 28 of stage 2, then `morepty`,
`ptyrec` and `telnet_loopback` for the pty half.

### Stage 5 is NOT next, and this is the evidence

`tty_probe` is 22,987 bytes and retiring it is stage 5.  Its condition is "once
the userland suite is the witness", which means AFTER the linesw repoint of
stages 3 and 4.  Retiring it at the end of stage 2 would delete:

- the ONLY caller of the twenty-nine routines ported from 2.11BSD `tty.c` --
  this file's own opening paragraph -- so every one of them becomes untested
  code with no caller at all;
- cases 160-166, the only ON-MACHINE pin on `include/ktty.s`'s DUM chain, which
  that file's header requires ("what must not exist is an UNCHECKED one") and
  which caught the `t_chars` offset being 70 and not 69.

The bank has 21,642 bytes free.  There is nothing to buy with the deletion and
a campaign's worth of coverage to lose.

### DECISION: the sgtty structs take BSD's SHAPE, and an ABI break is acceptable

**The maintainer, 2026-08-25, asked directly.**  "We don't need to worry about ABI
breaking, we just need to make sure that the decision matches BSD's paradigm."

So the rule for the rest of this campaign, and for anything after it that
touches these structures:

> **A structure the ported discipline reads or writes takes 2.11BSD's layout.
> Where userland disagrees, USERLAND MOVES.**

That is not a preference between two defensible shapes.  The tty bank IS the
2.11BSD port -- that is the whole premise of T1 through T6 -- so a userland
struct that disagrees with it is not "FGX's convention", it is a second truth
about a layout the kernel already owns.

**What BSD's shape is**, read out of `vendor/2.11BSD/usr/sys/h/ioctl.h` rather
than remembered.  Characters are `char`; the only `short` is a mode word:

    struct sgttyb   4 x char + short   =  6 bytes   (ioctl.h:~50)
    struct tchars   6 x char           =  6 bytes   (ioctl.h:22-29)
    struct ltchars  6 x char           =  6 bytes   (ioctl.h:30-37)

`src/kernel/tty/tty.h` matches all three exactly, because it is the port.

**Why FGX diverged, and why the reason expired.**  The userland header said the
fields "MUST STAY short" because fcc "gives each struct member a 2-byte slot".
That was TRUE WHEN WRITTEN and stopped being true: the header dates the change
itself -- "chars would byte-pack to 6 since B-8 (2026-07-06)".  fcc packs `char`
members at one byte now, which probe cases 164-165 measure independently
(`t_chars` is 14 bytes for 14 chars; `t_intrc` sits at +2).  So the divergence
was a correct decision about an older compiler, left standing after the
compiler moved -- not a design choice to be weighed.

`struct ltchars` was NEVER converted and has been six packed bytes here all
along, so FGX already had two sibling structs disagreeing about their own
convention.

**Done at 2b:** `struct tchars` is `char` in both userland headers
(`toolchain/include/sgtty.h`, `src/userland/lib/sgtty.h`).  No port declares a
private copy -- checked -- and consumers name the fields symbolically, so
`stty`, `tchtest` and `telnet` recompiled unchanged.

**Due at 2d:** `struct sgttyb`, and it is the same forced choice four times
over -- twelve consumers, including elvis, tcsh, telnet and getty.

THE CRUX, so that it is not discovered mid-cutover the way `tchars` was:
userland's 10-byte `sgttyb` is currently SELF-CONSISTENT WITH THE CORE, whose
`_ttyTable` image is also 5 x 2 bytes.  Nothing is broken today.  Stage 2d
replaces that core image with the bank's 6-byte upstream view, at which point
`TIOCGETP` writes six bytes into a struct userland believes is ten.  Take the
decision deliberately when 2d opens; do not let the first symptom be a garbled
`stty`.

**One thing to pin before 2d, and it is not a blocker:** `_POSIX_VDISABLE` is
`((unsigned char)'\377')` = 255 (`ttychars.h:35`), and `CBRK` is that.  In a
SIGNED `char` field it reads as -1, so `t_brkc == _POSIX_VDISABLE` compares -1
against 255 and is false.  fcc's char signedness is NOT established here.  The
wrinkle exists identically in the bank and in 2.11BSD itself, so taking BSD's
shape inherits BSD's semantics rather than inventing new ones -- but it is
worth a fixture, because the answer decides whether `CCEQ` behaves on both
sides of the seam.
