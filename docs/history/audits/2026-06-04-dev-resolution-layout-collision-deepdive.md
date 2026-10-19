# Deep-dive brief: kernel-layout collision breaks `/dev` chardev resolution

**Date:** 2026-06-04
**Status:** ✅ RESOLVED 2026-06-05 (commit `ec15e9e`, branch
`feat/udp-sockets-dhclient`). **It was NOT a layout collision** — it was an
**M-width bug** in `_Chardev_LookupSuffix` (`src/kernel/chardev.s`). Everything
below this box is the original (mis-)diagnosis; kept for the trail.
**Owner branch:** `fix/dev-resolution-layout-collision` (branched off `main`
after the net stack merged).

---

## ✅ Resolution (2026-06-05)

`@cls_next` (the "try next chardev" arm of the lookup loop) ended with
`REP #$30` (M=16) before `BRA @cls_loop`, whose bounds check is
`LDA _cdLkpIdx / CMP _chardev_count`. `_chardev_count` is `DS 1` (one byte), so
on **iteration 2+** the `CMP` read it as a **16-bit word** — count `$03` plus
its neighbour byte (`$1103` in the failing layout) — and `_cdLkpIdx` was read
16-bit with a stale high byte (init `STZ`'d only the low byte at M=8). The
bounds check went haywire and the loop **missed every chardev past idx 0**.

- `/dev/null` (idx 0) matched on **iteration 1** (still M=8 from entry) → always
  worked.
- `/dev/bpf0` (idx 2) had to **advance** past idx 0 → hit the M=16 arm → missed.
- Decisive test: `cat /dev/null` opened fine while `netdump` could not open
  `/dev/bpf0`. Same resolver, same `_cdTablePtr`, same DP — so NOT a collision,
  NOT a DP/pointer fault. Idx-specific ⇒ a loop/data bug.

**Why it looked layout-sensitive (the "heisenbug"):** the two values the 16-bit
reads pulled in — `_cdLkpIdx`'s stale high byte and the byte *after*
`_chardev_count` — are uninitialised / neighbour memory, so they shift with
kernel layout. At 43850 they happened to be benign; at 43908+ they weren't.
Pure-padding "reproduced" it and klog "fixed" it because both just re-rolled
that garbage. The soft-globals sweep couldn't fix it because there was no
collision to fix.

**Fix:** drop the `REP #$30` in `@cls_next` so `@cls_loop` stays **M=8** (the
correct width for a 1-byte count + a 0..15 idx). `@cls_try` already does its own
`REP #$30` for the `entry_off = idx*24` math and masks idx with `AND #$00FF`,
so nothing downstream needed the wide mode. Verified: netdump gate 1/1
(`listening on /dev/bpf0`, `packets`); `cat /dev/null` still fine; socktest 1/1.
kernel 47249.

**Unblocks:** the reverted saturation (`4c67aac`) can be re-applied — it was the
landmine's "straw," but any +N bytes only re-rolled the garbage; the real bug
is gone. The `fix/dev-resolution-layout-collision` investigation branch can be
retired.

---

---

## TL;DR

When the FGX kernel binary grows past **~43.9 KB** (somewhere in
`(43850, 43908]`), the synthetic-device path resolver starts returning
**ENOENT** for `/dev/bpf0`, so `fopen("/dev/bpf0")` fails ("netdump: cannot
open /dev/bpf0") on the **first** open after a clean boot. It is a
**layout-sensitive memory collision** (a heisenbug), NOT pure total size and
NOT a logic bug in the resolver. Any future kernel growth re-trips it. Regular
file opens (which go through the FST/FOP dispatch, not the `/dev` short-circuit)
keep working.

This is the "something's pooched with the memory map / missing MM allocation /
MX bug" that the maintainer predicted.

---

## Symptom

```
fgx:/root/# netdump
netdump: cannot open /dev/bpf0
fgx:/root/# netdump 10
netdump: cannot open /dev/bpf0
fgx:/root/#
```

First open after a fresh boot. Device IS registered at boot
(`net: /dev/bpf0 registered`), DHCP leases fine. Clean failure — no crash, the
shell returns to the prompt.

## Confirmed facts (with evidence)

1. **Kernel errno = `$0002` ENOENT.** Instrumented `_Sys_Open`
   (`src/kernel/syscall.s`) to klog its result: `sysopen err=$0002` for
   `/dev/bpf0`. So the kernel `SYS_OPEN` itself fails — the failure is in
   `Path_Resolve`'s `/dev/` chardev short-circuit (`src/drivers/fs/path.s:71`),
   which then falls through to the file walk → ENOENT. NOT libc, NOT the
   single-opener guard (dumped `BPF_CapState` = 0), NOT FCB exhaustion.

2. **It is pure size/layout, NOT the saturation code.** Step A (Kmalloc, no
   saturation, 43850 B) opens fine; Step B (saturation, 43908 B) fails. Taking
   Step A and adding **58 bytes of inert `DS` padding** (no logic) to reach
   43908 B **reproduces the failure**. So the saturation *code* is innocent —
   *any* +58 B trips it. The saturation commit `4c67aac` was just the straw.

3. **It is LAYOUT, not total size (heisenbug).** Padding `uthernet.s`
   (+58..300 B) **breaks** it; adding klog code in `chardev.s` (+80 B) **fixes**
   it. Same total size, different break/fix → it depends on *which addresses
   shift*, i.e. a specific structure landing on/off a colliding address.

4. **The resolver inputs are correct when it runs.** In a build where the
   `chardev.s` instrumentation happened to land the layout safely, the matcher
   `_Chardev_LookupSuffix` logged `cdlk p=$78A0 l=$0004 b0=$0062` — i.e. it was
   handed suffix "bpf0", length 4 — and matched (open succeeded, `fd=$0003`).
   So the matcher logic is fine; the collision corrupts something *around* it
   in the failing layout.

5. **The chardev table is intact at the failing size.** Dumped at the prompt
   (`_chardev_table` = `$02F7E1`): `_chardev_count = 3`, idx2 = `bpf0`,
   ops=`$024D11`, minor 0. `_bpfBase` = `$0727DA`, block zeroed (`CapState=0`).
   So registration is fine and the table is not the corrupted thing.

## What it is NOT

- Not the single-opener `BPF_CapState` guard (dumped 0; that path returns EBUSY
  not ENOENT anyway, and the chardev open arm in `Fs_Open` ignores the op's
  result — see `src/drivers/fs/fs.s:2293`).
- Not libc `fopen`'s FILE-table-full (ENFILE) path — the kernel returns ENOENT
  before libc gets a fd.
- Not a code-into-data overflow: code top at fail ≈ `$02CB84`; `FGX_DATA` DUM at
  `$02E000` (≈ `$147C` headroom). `_Sys_PathBuf` (`$02784B`), `_chardev_table`
  (`$02F7E1`), `_cdLkp*` (`$02F96x`), `_fsPathScratch` (`$02F52B`) are all in
  fixed, safe locations above/below the code, not overrun.
- Not the loader's multipass MVN: 43850 and 43908 are both 86 blocks
  (`PASS_BLKS=72` → one interpass flush + a 14-block final), identical load path.

## Reproduction (headless, deterministic)

Working baseline is `main` after the net merge (kernel 43850, netdump opens).

To reproduce the break, grow the kernel ~58+ B. Cleanest: add inert padding in
`src/kernel/uthernet.s` just before `_Net_CaptureStart`:

```
_Diag_SizePad   DS      58      ; -> kernel 43908; "cannot open". Monotonic:
                                ; >= ~43900 fails in THIS (uthernet.s) config.
```

Then build + observe the **real screen** (the gate's old assert was a false
positive — fixed in `b26b83f` to require "listening on /dev/bpf0"):

```
ninja                                         # build.sh was deleted 2026-07-29
python3 tools/mame_test/run.py --headless netdump_capstate
cat /tmp/fgx_test_netdump_capstate/dump.txt   # "cannot open" vs "listening on"
```

> **This recipe no longer runs as written.** `netdump_capstate` was one of the
> ~310 manifests deleted with the test suite on 2026-07-29; only `smoke`,
> `shell_smoke` and `floppy_boot` remain. The *technique* (build, run headless,
> read `dump.txt`) is still how you do this — see
> [fgx-runtime-debugging.md](../../fgx-runtime-debugging.md).

`tools/mame_test/tests/netdump_capstate.json` dumps the useful regions:
- `direct_page` ($0000–$00FF): `_bpfBase` at DP $F3 (3 B), `_bpfSnapPtr` at $F6.
- `chardev_table` ($02F7E1, 386 B): `_chardev_count` at +384, 24-B entries.
- `bpf_block` ($072780, 256 B): the Kmalloc'd capture block (CapState at +0).
- `klog` ($02E53D, 1792 B): boot + `sysopen`/`cdlk` diag lines.

To read the errno, re-add the `_Sys_Open` klog (success `sysopen ok fd=$NN`
at `@op_returnFd`, failure `sysopen err=$NN` at `@op_done`). NOTE: adding klog
shifts layout and can move/heal the bug — compensate with `_Diag_SizePad` to
hold the failing size, or bisect in the pure-padding config first.

## Proposed investigation plan

1. **Pin the exact threshold byte.** Bisect `_Diag_SizePad DS n` over
   `n ∈ [0, 58]` (43850..43908) in `uthernet.s` — monotonic there. Find the
   smallest `n` that flips working→broken. That gives the exact code-top
   address at the boundary.
2. **Read the listing at that code-top.** In `build/fgx_S0{1,2}_*_Output.txt`,
   look at what routine/data sits at the boundary address, and what is
   *immediately* above the code top.
3. **Find the runtime WRITE that lands there.** Since the matcher inputs are
   fine but the resolver still misses, hunt for a fixed-address (or
   layout-drifting) write that clobbers a structure the `/dev` path reads —
   prime suspects:
   - **Self-modifying dispatch trampolines:** `_cdTrampJSL` (chardev dispatch,
     `src/kernel/chardev.s`) and `_fstTrampJSL` (`_Fst_Dispatch`). A
     5-byte JSL/RTL cell whose operand is patched per call — if its address
     or a neighbor drifts onto a `/dev`-path structure, the patch corrupts it.
     The /dev path is the only open path that does NOT go through `_Fst_Dispatch`
     (it short-circuits in `Path_Resolve`), which is consistent with file opens
     working while `/dev` opens fail.
   - **The loader/handoff over-copy:** the final MVN copies in page granularity
     to `$02B000`+, over-copying ~`$7C` garbage bytes past the code end
     (`stage2.s` LoadDone). Confirm it cannot touch a live structure.
   - **A DP/scratch alias** that the `/dev` short-circuit uses but the FOP path
     does not (`_fsTmp1` = DP $DA in `Path_Resolve`; `_cdLkp*`).
4. **Fix:** relocate the colliding structure into `memmap.s` with a hard `ERR`
   guard (like the existing `KMem_end-1/FGX_HEAP` guard), so any future overrun
   fails the build instead of silently corrupting at runtime.
5. **Re-apply saturation:** cherry-pick `4c67aac` once the landmine is defused,
   and re-run the (now honest) netdump gate.

## Key commits / tags

- `72de241` — Kmalloc the bpf block (43850, **works**).
- `4c67aac` — saturation feature (43908, **trips the landmine**). Reverted.
- `a99c722` — Revert of the saturation commit (branch back to 43850).
- `b26b83f` — fix the netdump gate's false-positive assert (`"netdump:"` →
  `"listening on /dev/bpf0"`); this is why the regression shipped green.
- Auto-memory: `project_fgx_kernel_size_layout_heisenbug` (full evidence trail).

## Lesson already banked

The earlier hand-picked `$02FF00`/MOD_JT placements (`8fd1bc8`, fixed by the
Kmalloc refactor `72de241`) were the *first* two instances of "kernel state at a
drifting/overlapping address." This is a *third* manifestation of the same class
— a structure whose safety depends on the exact code layout. The durable fix
direction is: **every kernel allocation through `memmap.s` (DUM) or `Kmalloc`,
with build-time `ERR` guards on every boundary.**
