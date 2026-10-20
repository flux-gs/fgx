# Kernel banks

The FGX kernel is three statically linked images, each filling at most one 64 KB
65816 bank: the **core**, the **far** bank and the **tty** bank.  2.11BSD fits its
kernel into a PDP-11 address space by overlaying it; FGX takes a different route
and gives each image a bank of its own.  All three ship in one file, `/fgxunix`,
and every call between them is a long `JSL` whose bank byte is written at boot.

The design records with measurements and rejected alternatives are
[history/plans/far-kernel-bank.md](history/plans/far-kernel-bank.md) and
[history/plans/tty-kernel-bank.md](history/plans/tty-kernel-bank.md).

## The three banks

The banks sit together in one Memory Manager handle of `KERNEL_BANKS` ($03)
banks (`include/kernel.s`).  Stage 2 claims it bank-aligned
(`LoaderAllocKernelBank`, `src/boot/stage2.s`), so the far bank is always the
live kernel bank + 1 and the tty bank + 2.  Code works both numbers out from
`PHK` and never stores them.  The ORG banks below are for assembly only: no bank
runs at its ORG bank.

| | core | far | tty |
|---|---|---|---|
| runtime bank | MM-assigned (`KFGX_ANCHOR`, `$00:032C`) | core + 1 | core + 2 |
| assembly ORG | `$02` | `FGX_KFAR_BANK` `$08` | `FGX_KTTY_BANK` `$09` |
| link file | `src/kernel/link/core/fgx.link.s` (segments `KernelMain`, `BlockDriver`) | `src/kernel/link/far/fgxfar.link.s` | `src/kernel/link/tty/fgxtty.link.s` |
| root | `src/kernel/main.s` + `src/drivers/block/block.s` | `src/kernel/far/far.s` | `src/kernel/tty/ttybank.s` |
| image | `bin/fgx.bin` | `bin/fgxfar.bin` | `bin/fgxtty.bin` |
| ABI file | -- | `include/kfar.s` | `include/ktty.s` |
| magic at offset 0 | -- | `KFAR_MAGIC` `$4B46` `'FK'` | `KTTY_MAGIC` `$544B` `'KT'` |
| export slots | -- | `KFAR_SLOT_COUNT` (96) | `KTTY_SLOT_COUNT` (64) |
| code region | `FGX_CODE`..`FGX_DATA` | `$0000`..`FGX_KFAR_DATA` | `$0000`..`FGX_KTTY_DATA` |
| core-side init | -- | `Far_Init` (`main.s`) | `Tty_Init` (`main.s`) |
| bank-side init | -- | `Far_BankInit`, slot 0 | `Tty_BankInit`, slot 0 |

### Core bank

This bank holds everything `main.s` PUTs: the syscall dispatcher, the
scheduler, signals, the fd/FCB layer, the drivers and the module loader.  The
SmartPort block driver is the second segment.  Below the code are the vectors
(`FGX_VECTORS`), the globals (`FGX_GLOBALS`) and the task table
(`FGX_TASK_TBL`).  Above it, the statics (`KGlobals`) start at `FGX_DATA`
(`include/memmap.s`, `DUM FGX_DATA`) and must end below `$FE00` (an `ERR` on
`KMem_KGlobals_end` pins it); the separately anchored loader handoff block
(`_BlkTramp_*`, `_CoutTramp_*`, `_PreStaged_Banks`, `DUM $02FF00`) sits at `$FF00`.
The core runs in a bank the MM picks, so it reaches its own statics through DBR.
The few long-addressed self-references that have to work under a foreign DBR,
the `_weNNN` sites, get their bank bytes rewritten at boot by
`_RelocPatchWaveE` (`main.s`, table from `tools/gen_wavee_bankpatch.py`).

### Far bank

The far bank holds subsystems that must be present from boot but are not hot
enough to need core-bank room:

- the console driver and VT emulator (`src/kernel/far/console/`, slots 10-26, 73);
- the FGX binary loader (`loader.s`, slots 39-42);
- sound (`sound.s`), the battery-RAM clock (`clock.s`), `sigprocmask(2)`
  (`sigmask.s`) and `setitimer(2)` (`itimer.s`);
- kernel C, the kernel's side of the 4.3BSD-Reno VFS: the descriptor and
  path-syscall seam (`vfs_seam.c`), the root mount (`root_mount.c`), `/dev`
  (`dev_mount.c`, `dev_nodes.c`), `sysctl(2)` (`root_sysctl.c`), and
  `src/kernel/vfs/vfs_file.c` and `vfs_syscalls.c` compiled into this image.
  This C reaches `vfs.mod` and `ufs.mod` through generated import shims
  (`vfs_import.s`, `ufs_import.s`, from `tools/gen_mod_imports.py`).

Above the code ceiling the bank holds statics that are not part of the image (DUM):

| offset | what | named by |
|---|---|---|
| `$EC40` | far-bank statics; `CON_VT_STATE` first, read by the core at the fixed `KFAR_VT_STATE` | `far.s` DUM |
| `$F800` | the loader's outputs, read by the core | `KFAR_LD_ORG`, `KFAR_LD_*` |
| `$F900` | the console font, written there by stage 2 before the kernel runs | `KFAR_FONT_ORG`, `KFAR_BOOT_FONT` |

`Far_BankInit` zeroes the first two regions before anything reads them.  It
leaves the font alone, because stage 2 has already loaded it.

### Tty bank

This bank holds 2.11BSD's tty layer and two other tenants that are here for
the room:

- the line discipline and clists (`tty.c`, `tty_subr.c`, `tty_conf.c`), the
  tty instances `ttys[NTTY]` and their device lookup (`tty_dev.c`);
- the kernel clock (`kern_time.c`, slots 43-48): `gettimeofday`/`settimeofday`/
  `adjtime`, `inittodr` and the `CTL_MACHDEP` sysctls;
- the shared-text table (`text.s`, slots 56-62), after 2.11BSD's `struct text`
  (`usr/sys/h/text.h`) and `vm_text.c`, without swap;
- the kernel's shared-library hooks (`ld_hooks.s`, slots 49-54), which call
  `ld.mod` through `LD_TRAMP`.

The tty bank has to be present from boot because the receive path reaches it
from interrupts.  The root is called `ttybank.s` because fcc writes `tty.s`
beside `tty.c`.  The DUM region at `FGX_KTTY_DATA` is empty: every tty-bank
static is an fcc data segment inside the image, so it loads as zeros.  Any
static added to the DUM would not be zeroed by anything, and its owner would
have to clear it.

## Crossing banks

| direction | call | bank byte patched by | table (generated) | marker |
|---|---|---|---|---|
| core -> far | `JSL KFAR_<slot>` | `Far_Init` | `src/kernel/far_patchsites.s` | `_kfpNNN` |
| core -> tty | `JSL KTTY_<slot>` | `Tty_Init` | `src/kernel/tty_patchsites.s` | `_ktpNNN` |
| far -> core | `JSL _FarSh_*`, `LDAL`/`STAL` | `Far_BankInit` | `src/kernel/far/core_patchsites.s` | `_cfpNNN` |
| tty -> core | `JSL _FarSh_*`, `LDAL`/`STAL` | `Tty_BankInit` | `src/kernel/tty/core_patchsites.s` | `_ctpNNN` |

`tools/gen_far_bankpatch.py` builds all four tables from the listings.  It
uses four directions (`core`, `far`, `core-tty`, `tty`).  A marker is a label on
the same line as the instruction, and a table entry is `DA marker+3`, the
operand's bank byte (MVN contributes `+1` and `+2`).

**Into a bank.**  Each export slot is a `JMP abs16` at `$0006 + 4n`, and the
slots are never patched: the caller's `JSL` has already set PBR to the target
bank.  An unassigned or retired slot jumps to a red-border halt
(`_Far_StubHalt`, `_Ktty_StubHalt`).  Slot addresses are ABI, so a retired slot
is stubbed, never reused or closed up.  A slot target ends in `RTL`:

- an assembly target sets its own DBR (`PHB`/`PHK`/`PLB`) and restores the
  caller's before `RTL`;
- a kernel-C target is reached directly by the slot, with no wrapper.  The
  caller brackets the call with `KC_ENTER`/`KC_LEAVE` (far) or
  `KTTY_KC_ENTER`/`KTTY_KC_LEAVE` (tty) from `include/kernelc.s`.  The bracket
  sets DBR to the target bank and D to `FGX_DP_KERNELC`, and it runs before the
  arguments are pushed.

**Back to the core.**  Core routines end in `RTS`, so the far and tty banks
call RTL shims in `src/kernel/far_shims.s` instead.  The shims live in the core
bank and serve both banks, and each sets DBR to the core bank.
`tools/gen_kernel_exports.py` scrapes their addresses from the core listing into
`src/kernel/far/kernel_exports.s` and `src/kernel/tty/kernel_exports.s` (the
`far` and `tty` manifests).  Core statics are named by `include/memmap.s` and
have to be reached with a marked `LDAL`/`STAL`; a plain `LDA |sym` would read
the same offset in the wrong bank.  When the core reads a far-bank static, the
address is a fixed EQU in `include/kfar.s`, pinned by an `ERR` in `far.s`.
Scraping it would make the build cyclic.

**Within a bank.**  `JSR` must not reach an `RTL` routine, and a `JSL` that
names its own bank is wrong, because the bank byte is the ORG bank, not the
live one.  To call an RTL routine in its own bank, code pushes the return
address itself (`PHK` + `PEA`) and jumps; `include/kernelc.s` calls this a pile
call (`KTTY_STUB2`).

**Function pointers.**  The far and tty C is compiled with
`fcc --kernel-bank --pile`.  Every `&function` cell comes out as `KFAR_FN_PTR`
with a zero bank byte.  `Far_BankInit` and `Tty_BankInit` stamp each cell with
`PHK` from `_modFnPtrTab` (`fnptr_patchsites.s`, from
`tools/gen_mod_bankpatch.py`), before any C runs.

**One kernel-C context, plus one for interrupts.**  Far and tty C share
`FGX_DP_KERNELC`, which makes them a single fcc register file.  Neither may be
entered from inside the other.  Interrupt-time C (`KTTY_KC_ENTER_IRQ`) gets its
own page (`FGX_DP_KERNELC_IRQ`) and its own stack (`FGX_STK_KIRQ`, `FGX_KSTK_SIZE`
bytes).  Both receive interrupts enter it through `_Tty_IrqInput`
(`src/kernel/toolbox.s`): the heartbeat for the keyboard and the SCC handler for
`/dev/tty01`.  `_Tty_IrqInput` hands each character to `ttyinput` through slot
38 (`kc_ttyinput`).

## Build and boot

1. ninja links `fgx.link.s` first.  Both bank links need the core listing,
   because their `kernel_exports.s` files are generated from it, and the tty link
   is ordered after the far link (`tools/ninja/gen.py`).  Each link file has a
   directory of its own, because Merlin32 writes the image and listings beside
   it.
2. `tools/mkfgxunix.py` concatenates the images into `bin/fgxunix` behind a
   one-block segment table (`'FGXUNIX1'`, 5 bytes per segment: selector, bank
   offset, destination page, block count).  Offsets are derived by summing the
   sizes, as 2.11BSD's boot program does for overlays (`usr/sys/h/exec.h`
   `ov_siz`).  The segments are:

   | segment | selector | bank offset | destination |
   |---|---|---|---|
   | `bin/fgx.bin` | kernel handle | 0 | page of `FGX_CODE`, read from `include/kernel.s` |
   | `bin/fgxfar.bin` | kernel handle | 1 | `$0000` |
   | `bin/fgxtty.bin` | kernel handle | 2 | `$0000` |
   | `vfs`, `ufs`, `ufsdir` modules | rest-of-OS module window | 0, 1, 2 | `$0000` |

3. Stage 2 (`src/boot/stage2.s`) claims the kernel handle, reads `/fgxunix`,
   MVNs each segment into the bank its table entry names, and records the module
   banks in `_PreStaged_Banks`.  It then stages `/lib/fonts/default.fnt` into the
   far bank at `KFAR_BOOT_FONT` and jumps to the kernel.
4. `FGX_Entry` (`main.s`) calls `Far_Init` and then `Tty_Init`.  Each one checks
   the magic and ABI version in its bank and patches the core-side sites.  It
   then calls slot 0 with A = the core bank, and the bank patches its own side.
   If either bank is missing or has the wrong version, boot halts on a red
   border with a firmware-COUT message.
5. `_LogFarBank` and `_LogTtyBank` then call each bank's log slot.  The bank
   prints its line through `_FarSh_LogStr`, which proves both directions work.

## 2.11BSD in the tty bank

| FGX file | upstream |
|---|---|
| `src/kernel/tty/tty.c` | `vendor/2.11BSD/usr/sys/sys/tty.c` |
| `src/kernel/tty/tty_subr.c` | `vendor/2.11BSD/usr/sys/sys/tty_subr.c` (+ `cinit` from `init_main.c`) |
| `src/kernel/tty/tty_conf.c` | `vendor/2.11BSD/usr/sys/sys/tty_conf.c` |
| `tty.h`, `clist.h`, `ttychars.h`, `conf.h` | `vendor/2.11BSD/usr/sys/h/` |
| `src/kernel/tty/kern_time.c` | `vendor/2.11BSD/usr/sys/sys/kern_time.c`, with FreeBSD 2.2.8's `resettodr` and `adjtime` |
| `src/kernel/tty/tty_dev.c` | none: FGX's stand-in for `cdevsw[].d_ttys` |

`linesw[]` has upstream's rows: `OTTYDISC` and `NTTYDISC` are `ttyopen`,
`ttylclose`, `ttread`, `ttwrite`, `nullioctl`, `ttyinput`, `ttstart` and
`ttymodem`, and the `NBK`/`NTB`/`NSL` rows are upstream's own `nodev` arms.
Two other tty drivers live outside this bank: the pty driver is `pty.mod`
(`src/modules/pty/pty.s`, which follows `tty_pty.c`), and `/dev/tty` is
`src/kernel/tty_tty.s`, a port of `tty_tty.c`.

These divergences from upstream are still in force.  `docs/PROVENANCE.md` has
the per-function detail.

- **No `cdevsw` array.**  The character-device switch is the runtime registry
  in `include/chardev.s`.  `d_stop` becomes `kc_cdstop` (`tty_dev.c`),
  `d_ioctl` becomes `kc_cdioctl` (`kc_sys.s`), and `d_ttys[minor]` becomes `tty_find`
  (`tty_dev.c`).
- **The select wakeup is unconditional.**  `ttwakeup` and `ttyowake` call
  `kc_selwakeup()` without upstream's `if (tp->t_rsel)` test, and `ttyselect`
  records nothing.  FGX's `select(2)` registers no process, so every wake is
  upstream's collision case.
- **The output and carrier waits cannot be interrupted.**  `ttywait` and
  `ttwrite` sleep through `kc_sleep`, which is `_sleepUn`.  Upstream sleeps at
  `TTOPRI` (29, above `PZERO` 25, `h/tty.h`, `h/param.h`), and that sleep can be
  interrupted.  This bank has no u-area to unwind a signal through.  `ttread`
  uses `kc_sleepi`, which can be interrupted, as upstream does.
- **Sleep channels are 16 bits.**  `kc_sleep` passes the pointer's offset and
  drops the bank.  That is safe only because every waiter re-tests its condition
  after a wakeup.
- **`ttyopen` calls a core helper for the session step.**  Upstream assigns
  `u.u_ttyp`, `p_pgrp` and `t_pgrp`; here `kc_ttyopen` does that in the core
  bank.
- **`spltty`/`splx` are `kc_spltty`/`kc_splx`**, built on the 65816 `I` flag
  (`ttyparam.h`, `kc_sys.s`).  `tools/check_spl_balance.py` checks that every
  raise has a matching restore.
- **No libkern.**  `bcopy` in `tty_subr.c` is the local `clist_copy`.
  `tty_dev.c` carries FGX's own `bzero`, `bcopy` and `bcmp`, and `scanc`
  from 4.3BSD-Reno (`ufs/ufs_subr.c`).

## Budgets and guards

`tools/check_kernel_ceiling.py` reports how full each bank is, as "used B of
capacity (N free)".  This doc does not copy those numbers; run the tool.

| limit | source of truth | enforced by |
|---|---|---|
| core code fits `FGX_CODE`..`FGX_DATA` | `include/kernel.s` | `check_kernel_ceiling.py` |
| core statics end below `$02FE00`; `KMem_end` below `FGX_HEAP` | `include/memmap.s` | `ERR` in `memmap.s` |
| far code fits below `FGX_KFAR_DATA`; tty code fits below `FGX_KTTY_DATA` | `include/kernel.s` | `check_kernel_ceiling.py` |
| image opens with its magic (no bytes emitted before the ORG) | `include/kfar.s`, `include/ktty.s` | `check_kernel_ceiling.py` |
| assigned slots fit the reservation | `KFAR_SLOT_COUNT`, `KTTY_SLOT_COUNT` | `ERR *-{..._CODE+..._TABLE_SZ}` in `far.s`, `ttybank.s` |
| far statics, loader outputs and font do not overlap or wrap the bank | `far.s` DUMs | `ERR` in `far.s` |
| every cross-bank `JSL` is marked; markers sit on long operands; tables current | listings | `gen_far_bankpatch.py --check` |
| function-pointer tables current | listings | `gen_mod_bankpatch.py --check` |
| export slots reached by `JSL`/`JML`, never `JSR`/`JMP` | `include/kfar.s`, `include/ktty.s` | `check_far_calls.py` |
| no `JSR` to an `RTL` routine inside the far or tty bank | `src/kernel/far/`, `src/kernel/tty/` | `check_far_rtl_calls.py` |
| no `JSL`/`JML` naming its own bank, in any of the four listings | listings | `check_selfbank_jsl.py` |
| `--kernel-bank` emits `KFAR_FN_PTR` and reads the bank byte | fcc | `check_kernel_bank_emission.py` |
| at most 3 kernel segments and 3 module segments | `KERNEL_BANKS`, `include/kernel.s` | `mkfgxunix.py` (`SEL_LIMIT`) |

Every check except `mkfgxunix.py`'s runs in ninja's `kchecks` edge
(`build/.kernel_checked`).  `mkfgxunix.py` applies its limit when it builds
`bin/fgxunix`.
`KERNEL_BANKS` has copies in `include/kernel.s`, `src/boot/stage2.s` and
`mkfgxunix.py`'s `SEL_LIMIT`, and nothing checks that they agree.
