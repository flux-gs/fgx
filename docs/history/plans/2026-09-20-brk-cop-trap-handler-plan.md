# BRK/COP trap handler -- plan (2026-09-20)

Closes the hole that makes a stray BRK erase the machine, and is the instrument
for apple/fgx#463.  The maintainer's ruling: implement BSD's **user-mode SIGTRAP arm too**,
not only the kernel-mode report; then carry on and fix #463.

## Why

Nothing in the tree installs `$00:FFE6` (native BRK) or `$00:FFF4` (native COP).
`include/hardware.s:31` records the consequence, measured on apple/fgx#305: a
runaway BRK "landed at `$00:0000` because `$00:FFE6` reads `$0000`".  From there
`$02` decodes as COP, the trap loop pushes a 4-byte frame per iteration, and the
16-bit stack pointer WRAPS -- paving all of bank 0 with its own frames.  That
erases the relocation anchor at `$00:032C`, so the harness reads every kernel and
console region from the wrong bank and reports a blank screen with vacuously
green `screen_lacks` assertions.

The amplifier has now cost two investigations (#305, and most of #463).

## BSD authority

`examples/2.11BSD/usr/sys/pdp/trap.c` -- **vendor this file into `vendor/` in the
implementing commit**, per the port-source rule.

- `:102-120`, the kernel-mode `default:` arm: `splhigh()`, then
  `printf("ka6 %o aps %o\npc %o ps %o\nov %d\n", ...)`, `printf("trap type %o\n",
  dev)`, then `panic("trap")`.  So: raise priority, report the faulting PC and PS
  and the trap type, then stop.
- `:161-164`, `case T_BPTTRAP + USER: i = SIGTRAP; ps &= ~PSL_T;` -- a user-mode
  breakpoint is SIGTRAP to the process, not a panic.

## The binding constraint, measured

`tools/check_kernel_ceiling.py`:

    kernel 56683 B of 56688 (5 free)
    far    58913 B of 60480 (1567 free)
    tty    54705 B of 65280 (10575 free)

**The core bank has 5 bytes free**, so neither the handler nor its installer may
land there -- a new `JSL KFAR_*` export slot alone would spend 4 of the 5.

## Where it goes

Bank-0 `$FF00-$FFFF` is **free and unclaimed**, and it contains the native vector
block.  Established by:

- `CFG_DP_KERNELC_IRQ = $FC00` (256 B) and `CFG_STK_KIRQ = $FD00` + `FGX_KSTK_SIZE`
  512, so `FGX_STK_KIRQ_TOP = $FEFF` -- the kernel IRQ stack ends below the hole.
- A survey of the assembled bytes of every kernel and module listing for long
  addressing into bank-0 `$FFxx` (`(8F|AF|5C|22) xx FF 00`): no matches, with a
  positive control on `$03xx` that correctly reports the IDROUTINE trampoline
  (`22 20 03 00`) and the `8F .. 03 00` cell stores.  The earlier source-text grep
  was vacuous -- it missed symbol-spelled operands like `STAL IDROUTINE_TRAMP`.
- `stage2.s`'s `LoaderRelocateKernel` MVN targets the **kernel** bank's `$FF00`
  (the 24-byte loader handoff block), not bank 0's.

The "fighting LC RAM banking" objection that rejected the COP vector for the
SYSCALL path (`src/kernel/syscall.s:57`, which chose `JSL SYS_TRAMP` instead) does
not transfer: the kernel's own slot stacks (`$E000`..) and its IRQ stack live in
that same bank-0 language-card RAM, so if it were switched out the kernel would
already be dead.  State the divergence in the commit.

## Design

**Handler at `$00:FF00`, self-contained.**  The kernel-mode arm needs no kernel
symbol: the trap frame is on the stack, the report cells and the border are
absolute.  Absolute-long stores and relative branches only, so the template is
position-independent and installable by a byte copy.

- `$FF00` BRK entry, `$FF08` COP entry -- distinct so the magic differs; each
  falls into common code.
- On entry the stack holds the frame already decoded from the #463 dump:
  increasing address = `P`, `PCL`, `PCH`, `PB`.  Record the faulting `PB`/`PC`
  and `S`.  `S` still points at the pre-fault call chain, which is what names
  #463's origin.
- **Nothing may push** before the frame is read -- `fcc_ktrap.s`'s rule, for the
  same reason.
- Magic written **LAST**, so a reader that sees it knows the other fields are
  valid.  Then border, then spin.  This is `fcc_ktrap.s`'s contract exactly.

**Report cells.**  Reuse `KFGX_TRAP_MAGIC` (`$000310`) and `KFGX_TRAP_S`
(`$000314`); add `KFGX_TRAP_PC` (`$000318`) and `KFGX_TRAP_PB` (`$00031A`).
Reserve them in `include/memmap.s` with its `ERR` assertion AND declare the EQUs
in `include/kernel.s`, because a module PUTs kernel.s but not memmap.s -- the
existing cells' comment explains this at length.  New magics beside
`KTRAP_MAGIC_HW/SF`: `KTRAP_MAGIC_BRK $C5D2`, `KTRAP_MAGIC_COP $C5D3`.

**Installer: stage 2.**  It already writes bank-0 cells (`KFGX_ANCHOR`,
`KFGX_REST_COUNT/HANDLE`) and is outside the core bank's budget.  It copies the
template to `$FF00` and writes the two vectors.  Zero core-bank cost.

**User-mode SIGTRAP arm.**  Needs kernel services, which a self-contained bank-0
handler cannot reach, so the handler dispatches through a bank-0 **hook cell**
that the kernel fills once signals are up; an unfilled (zero) hook takes the halt
path.  That degrades safely and keeps boot-time traps diagnosable.

User vs kernel discrimination: the 65816 has no supervisor bit, so compare the
trapped `PB` against the live kernel bank read from the anchor at `$00:032C` and
its `+1`/`+2` (far, tty).  **Open question to settle while implementing:** a BRK
inside a loadable module is kernel-mode but its bank is none of those three, so
the test must also consult `_modBankTab`, or invert and ask whether `PB` is the
current task's code bank.  Decide from the module-bank table rather than guessing.

## Sequencing

1. Report cells + EQUs + memmap reservation + magics.
2. Handler template (kernel-mode arm) + stage-2 install.
3. Harness: read the trap report and print it, pairing with the
   `kernel_bank_anchor` check already landed in `789873620`.
4. **Use it on #463** -- read the faulting PB/PC and the stack chain.
5. User-mode SIGTRAP arm + the hook cell.
6. Fix #463 proper.  NOTE: if #463's BRK is in USER mode, the SIGTRAP arm will
   turn the crash into a killed process and the gate may go green -- that is the
   safety net working, NOT the fix.  Name and fix whatever executes a `$00` byte.

## Testing

A trap handler that never fires is indistinguishable from one that is missing, so
it needs a positive control: a fixture that executes a deliberate `BRK` and
asserts the report's magic and a plausible PB/PC.  The `fcc_ktrap` cells have no
such fixture today, which is why they are trusted rather than verified.
