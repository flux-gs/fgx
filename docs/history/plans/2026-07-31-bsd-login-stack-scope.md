# BSD login stack — scope & decomposition (2026-07-31)

Scopes a full 2.11BSD login stack for FGX: `init` spawning `getty` per line,
`getty` spawning `login`, `login` authenticating against `/etc/passwd` and
exec'ing the user's shell; plus `passwd(1)` and the adjacent tools; plus
multiple virtual consoles switchable by alt-1/alt-2/alt-3, each its own
getty/login/shell for real multiuser.

This is a **scoping doc, not an implementation plan**. It reconciles current
state, evaluates the direct ports, and splits the work into four slices with
their dependencies. Per-slice design specs come when each slice is picked up.

**Bottom line.** The login stack itself is mostly a deletion exercise -- the
2.11BSD sources are vendored and the hard parts (pwent, credentials, ptys, the
sgtty tty layer) already exist. Two things gate it that are *not* about login at
all: **stage 2 cannot read past a directory's first block**, so `/etc` is one
file away from unbootable and cannot hold `passwd`/`ttys`/`group`; and the
**bank-0 stack arena** cannot fund concurrent interactive sessions. The arena is
split out as its own peer campaign (slice B) because it is needed regardless of
consoles -- **pipelines are the sharper driver**, since every pipeline stage is a
co-resident task.

---

## 1. Current state

Already in place, verified this session:

| Piece | Where | State |
|---|---|---|
| `getpwent`/`getpwnam`/`getpwuid`/`setpwent`/`endpwent` | `toolchain/lib/libc_c/libc_c.c:2110+` | Real 7-field `/etc/passwd` parser. Skips blank/`#` lines as an FGX tolerance. `pw_class`/`pw_change`/`pw_expire` exist for API compat, read back `""`/0 |
| uid/gid credentials | `src/kernel/syscall.s:566`, `task.s:1225` | u-area creds; `SYS_SETUID`=23, `SYS_SETGID`=25, `SYS_SETEUID`=26, `SYS_SETEGID`=27; `getuid`/`geteuid` share call 24 (real in A, effective in Y, per 2.11BSD) |
| ptys | `src/kernel/pty.s` | 2 pairs, kernel-builtin: `/dev/ptyp0`+`ttyp0`, `ptyp1`+`ttyp1` |
| tty layer | `_ttyTable`, `include/kernel.s:589` | `NTTY EQU 3` = console + 2 pty slaves. Full sgtty state: `SgFlags`, `Tc*`, `Ltchars`, `Lmode`, `FgPgrp`, canon buffer |
| chardev registry | `src/kernel/chardev.s` | Dynamic, name-based (`_Chardev_LookupSuffix`). Adding `/dev/ttyv1..N` is registration, not new plumbing |
| `init` | `src/userland/init/init.c` | 96 lines. Spawns `/bin/sh` as `-sh`, waits on that pid specifically, exits (kernel halts). Its own header documents it as standing in for `login` |
| `utmp.h` | `toolchain/include/utmp.h` | Header only, arrived with tcsh. No `login(3)`/`logout(3)`/`ttyslot()` |

Absent and needed: `crypt(3)`, `getpass(3)`, `ttyent` (`getttyent`/`getttynam`),
utmp/wtmp write path, `grp.h`/`/etc/group`/`initgroups`. `ttyname(fd)` exists but
is a stub (see slice A).

## 2. Direct-port evaluation

Sources are vendored under `vendor/2.11BSD/usr/`, per the standing port-source
policy (2.11BSD is THE source; netbsd-0-9 is advisory-only).

**`init` -- `usr/sbin/init/init.c`, 782 lines. Verdict: workalike keeping BSD's
structure, ~250-300 lines.** The respawn engine is genuinely portable and is the
part worth having: the `itab` line table, the `/etc/ttys` merge on SIGHUP, the
`gettytime`/`gettycnt` throttle that stops a broken line spinning, the
multi-user/single-user transition. What it drags in and we drop: `sysctl`,
`reboot(2)`/`RB_*`, `syslog`, `autoconfig()`, securelevel
(`get/setsecuritylevel`), and the window-system `wcmd` fork.

**`getty` -- NOT VENDORED.** `vendor/2.11BSD/` carries only
`usr/{bin,old,sbin,ucb,usr.bin}`; getty lives in `libexec/`. Nothing to evaluate
yet. Its job also collapses here: no baud negotiation, no modem, no parity
autodetect, no `gettytab`. FGX getty = open the line, apply sgtty modes, print
`/etc/issue`, read a name, exec login. **~150 lines.** Fetch the real source as a
reference if wanted, but the port is mostly deletion.

**`login` -- `usr/bin/login/login.c`, 602 lines. Verdict: hybrid.** The core flow
(`getpwnam` -> `getpass` -> `crypt` -> compare -> `setgid`/`setuid` -> `chdir` ->
build env -> exec shell as `-sh`) is ~150 lines and lifts cleanly. The other 450
are `quota`, `setpriority`, `initgroups`/`grp.h`, `setlogin`, `lastlog`,
`getttynam`, `syslog`, `tzfile`, Kerberos, and hostname/`netdb` for the `-h`
telnetd path. Note `login` touches `ttyent` in exactly two places: `ty_type`
supplies `TERM` via `stypeof()` (`login.c:577`) and `ty_status & TTY_SECURE`
gates root logins (`login.c:484`).

**`passwd` -- `usr/bin/passwd/passwd.c`, 265 lines. Verdict: workalike,
~120 lines.** Built around `ndbm` + `/etc/ptmp` locking + `mkpasswd`. FGX has no
ndbm, so this becomes a flat-file rewrite.

---

## 3. Slice A -- boot and tty blockers

Small, gates everything that touches the disk or names a tty. **No dependency on
slices B/C/D.**

### A1. stage 2 multi-block directory scan

`src/boot/stage2.s:574 find_in_dir` starts at `DIR_FIRST_OFF` (43) with slot
counter 1 and scans while `< DIR_ENTRIES` (13) -- twelve slots -- then returns
C=0, which `@wp_compLoop` treats as fatal. Its own comment admits it: *"Single-
block scan only -- multi-block dirs (>13 entries) not handled."* ProDOS puts
`prev_block` at DIR_BUF+0/+1 and `next_block` at +2/+3, and real ProDOS chases
that chain (*Beneath Apple ProDOS* p.25). The kernel's own FS handles multi-block
directories fine -- `/bin` has 60+ files -- so the defect is confined to the
minimal pre-console reader in stage 2.

**Why it is a hard prerequisite:** stage 2 looks up `ETC/PRELOAD.CONF` and
`ETC/BOOT.CONF`. `/etc` already spans two blocks and `PRELOAD.CONF` sits in the
last slot stage 2 can see. Adding any file that sorts before it pushes it into
block 2, the PRODOS FST never pre-stages, and the kernel comes up with no FS
dispatch. It dies before any console exists, so the symptom is a black screen,
no diagnostic, every test failing identically. `passwd` did exactly this on
2026-07-26. This slice wants to add `passwd`, `ttys`, `group`, `issue`.

**Fix.** Hoist the two initialization stores out of `find_in_dir` into the
caller, making the scan window a parameter: key block -> start offset 43, counter
1 (12 slots, slot 0 is the subdir header); continuation block -> start offset 4,
counter 0 (all 13 slots). On C=0, read `DIR_BUF+2/+3`; if non-zero, `BlkRead` and
rescan with the continuation window. An exhausted chain still returns C=0, so
every existing caller is unchanged.

**Two guards**, because a probe during the reverted 2026-07-26 attempt showed
`DIR_BUF` can hold non-directory bytes on some scan-failure path:
- after reading block N+1, verify `DIR_BUF+0/+1` == the block we came from. A
  directory that does not point back is not our directory.
- a hop counter capped at 16, so a corrupt back-pointer pair cannot sustain a
  cycle.

Cost ~60-70 bytes in a 2.3 KB stage 2 at `ORG $2000`. No budget pressure.

**Test, and this is the part that matters.** Stage 2 runs before any console
exists, so a failure has no diagnostic. The check must be the actual claim, not
a proxy: stage a file into `disk_src/etc/` that sorts before `preload.conf`
(`passwd` is the natural one -- the exact file that broke this), rebuild, boot
under MAME, expect a normal boot. **Plus a negative control**: confirm the
*unfixed* stage 2 fails that same test. Without the control a passing boot proves
nothing, because the file could simply have landed in block 1. Diagnose failures
by probing `PRESTAGED_ABS` ($00:1FE8) -- all zeros means no module staged.

The earlier `next_block`-chasing attempt was reverted, but it was confounded by
unrelated breakage in the tree at the time. Re-test against clean HEAD before
concluding anything about it.

### A2. Real `ttyname(fd)`

`libc_c.c:2046` returns `"/dev/tty"` for any tty fd, with the comment "FGX has
one console; there is no fd->device-name map." Multi-tty breaks this
immediately, and `login` needs it for `ut_line`, as do `who` and `tty(1)`.

**Not the BSD implementation.** Real `ttyname(3)` does `fstat` ->
`readdir("/dev")` -> match `st_rdev`. FGX cannot: `/dev` is a synthetic
short-circuit in `Path_Resolve` (`_fsResolveIsChardev`/`_fsResolveChardevIdx`),
not an enumerable directory, and `stat` has no `st_rdev`.

**Instead, reuse `ioctl`.** The sgtty dispatch already resolves fd -> tty-table
offset at `syscall.s:2366 @si_ttyX`. Add one op on that existing path --
`FIODGNAME`, FreeBSD's name, to stay in the family -- converting the offset to an
index and copying from a static `_ttyNames` table. Non-tty fd -> `ENOTTY`, same
as every other op there. libc `ttyname()` becomes an `isatty` check plus one
ioctl into a static `"/dev/"`-prefixed buffer.

No new syscall number, so no corollary-syscall question. It also scales on its
own: when `NTTY` grows in slice D, the name table grows with it.

---

## 4. Slice B -- bank-0 task stack arena (own campaign)

**Split out because it is needed regardless of consoles.** Every pipeline stage
is a co-resident task, so the arena binds on ordinary shell use as more software
lands. Consoles merely make it acute.

### The immovable constraint

The 65816's stack pointer is 16-bit, so *every* task's hardware stack must live
in bank 0. There is no MMU and no page-fault mechanism.

### Current mechanism

`FGX_STK_ARENA EQU $3200`, `FGX_STK_ARENA_PAGES EQU 126` ($3200-$AFFF, 31.5 KB,
`include/kernel.s:236,248`), carved by a first-fit contiguous page-bitmap
allocator (`src/kernel/task.s:597 Task_AllocStack`) over `_stkArenaMap`. Each
task's share is a **static worst-case reservation held for its whole life**,
sized by `toolchain/src/ld/stack_measure.py` (deepest static call-graph path +
`CYCLE_TURNS = 8` times the deepest recursion-cycle frame + pad) and written into
FGX2 header byte 14 by `fgx_ld.py`. `TASK_STACK_MAX_PAGES EQU 83`.

Overflow detection is fcc's prologue guard (`toolchain/src/cc/emit.c:1644`),
DO-gated by `<fn>_STKGUARD` (armed only for direct recursion, indirect calls, or
frames >= 128 B). It compares the would-be new S against `_fcc_stkfloor`, a
**per-task direct-page word at DP offset $B9** (`include/kernel.s:270`) seeded by
the kernel after `Task_AllocStack` (`process.s:297`). Coverage gap: hand-asm,
libc asm and IRQ pushes are covered only by `FCC_STK_FLOOR_MARGIN` (128 B,
calibrated 2026-07-08) plus the one guard page.

This coupling produced the same production bug twice in two days (arena
112 -> 126 on 2026-07-27; `TASK_STACK_MAX_PAGES` 56 -> 83 on 2026-07-28, which
re-broke it the next day; fixed 2026-07-31 by shrinking three binaries).

### Measured footprint

Reading FGX2 header byte 14: **tcsh 55, tar 16, vi 14, sh 9**, everything else
2-3. Two corrections to how these get summed, both of which have been
systematically missing from the roadmap's arithmetic:

- **`Task_AllocStack` allocates N+1 pages** (`task.s:611` -- an `INC` before
  `STA _tas_npages`), one guard page per task. Every co-resident sum is
  understated by one page per task.
- **`execve` transiently double-holds.** The new stack is allocated
  (`process.s:1494`) while the old allocation is still held, so exec itself can
  ENOMEM on a fragmented arena.

With guards counted: 2 x tcsh + tar = 129 > 126 is **dead**, not "exactly at the
ceiling". 3 x tcsh = 168.

Measurement gotcha: a header sweep **must check the FGX2 magic first**.
`disk_src/bin/hd` is a 419-byte jsh script whose byte 14 is ASCII `P` from its
SPDX line, which reads as a bogus 80-page stack.

### Rejected: commit-on-use / lazy growth

**This supersedes the `docs/ROADMAP.md` bullet calling it the "cheapest real
win".** It is a category error on MMU-less hardware. With no virtual/physical
split, a growable limit inside a contiguous arena must be held free -- which is
exactly a reservation. Concretely:

- Growing downward in place needs the page below the guard page free, but
  first-fit packs tasks tight, so that page is a neighbour's *top* page.
- "Grow if the neighbour page happens to be free" converts a deterministic
  spawn-time ENOMEM into a nondeterministic mid-run failure at arbitrary
  recursion depth. Strictly worse.
- **Growth-by-relocation is unsound.** fcc frames hold *absolute* bank-0
  addresses: the prologue `PEI _fcc_fb` saves an absolute frame-base word, and
  `&local` yields absolute pointers that escape into DP cells, the heap, and
  kernel-held syscall args. The pointers into a C stack cannot be enumerated.

**Corollaries.** The same argument kills relocate-while-blocked and segmented
stacks. And **the arena can never be compacted** -- fragmentation must be
prevented, not repaired.

### Adopted: address-preserving swap, scoped to a "console lane"

Console session-leader shells share **one overlapping bank-0 page range**, with
home copies in MM handles outside bank 0, swapped at dispatch on focus change.
The insight: console shells are mutually exclusive by human focus -- at most one
is interactive, the rest block in tty `read()` or `wait()`. Live depth of a
blocked shell is ~1-3 KB, so a focus switch costs roughly 3-8 ms at 2.8 MHz.
Deadlock-free by construction: the eviction target is by definition not running.

**Enabling fact: signal delivery is already swap-compatible.** The kernel pushes
the handler far-target onto the *user* stack only at syscall-return time, in the
task's own context (`syscall.s:350-391`, the RTL far-jump trick). A signal to a
blocked task only sets pending state and wakes it; nothing in `signal.s` touches
`TCB_StackPtr` of a non-running task. This is a lucky consequence of the delivery
design.

**Prerequisite audit before building:** confirm no IRQ-time path (tty ring,
W5100 RX) writes through a stored user pointer while its owner is blocked.

### Reclaimable bank-0 space: ~+24 pages, ceiling ~150

- **+7, nearly free.** `FGX_DP_KTASKS` reserves 16 pid-indexed slots at
  $B000-$BFFF but `CFG_KERNEL_NPROC EQU 8` (`include/config.s:18`), so slots 9-15
  are dead -- and they are on the arena-adjacent side. Re-base to $B700 and the
  arena end moves $B000 -> $B700, 126 -> 133. Needs an `ERR` assert coupling it
  to NPROC so a future NPROC bump fails loudly.
- **+17, real work.** Retire `BLK_STAGE`, the 4 KB `$00:2000` bounce region
  claimed at `src/kernel/toolbox.s:274` (note: `include/kernel.s` describes it as
  512 B; the claim is `DW $1000`). Use the extended SmartPort call's 4-byte
  buffer pointer to read straight into the destination bank. Also deletes the
  per-block `MVN`, an I/O win in its own right. Arena base then $3200 -> $2000.
- **Stranded:** $0800-$0FFF is free after boot but separated from the arena by
  the kernel stacks at $1000-$1FFF. Not worth a two-region allocator.

**What the ceiling proves: reclaim alone can never fund three concurrent deep
shells** (3 x 56 = 168 > 150). The gap must come from policy, sizing, or swap.

### Unplanned-for risk: fragmentation

Today's workloads are LIFO-ish (shell spawns child, child exits), so first-fit
stays clean. Long-lived login sessions ending in arbitrary order break that:
ENOMEM with sufficient free pages, and no compaction possible ever. A budget
assertion checks *sums*, not *placements*, so it will not catch this.
Containment is **two-ended first-fit** (big stacks allocated from the top, small
from the bottom, ~15 lines in `Task_AllocStack`) plus spawn-time worst-case
admission.

### Phasing

| Phase | Buys | Cost |
|---|---|---|
| **B0.** Budget assertion: sum FGX2-magic binaries over co-resident scenarios vs `FGX_STK_ARENA_PAGES`, counting guard pages and exec transients | 0 pages; kills the twice-recurring bug | hours |
| **B1.** DP re-base to $B700 (+7) + `BLK_STAGE` retirement (+17) + two-ended first-fit | 126 -> 150 | days |
| **B2.** Measured per-binary `CYCLE_TURNS` | ~5-6 pages off tcsh | days, optional |
| **B3.** Console-lane address-preserving swap | 3 deep shells for one reservation | 1-2 weeks |

B0 is the regression fence for everything after it and should land first
regardless of what else happens.

**B2 caveat.** `CYCLE_TURNS = 8` dominated every binary pre-shrink (8,488 B of
tcsh's 21,194), but `-DTC_BUFSIZ=256` already cut the deepest cycle frame, so the
remaining win is ~5-6 pages, not 33. The risk is asymmetric: `STKGUARD` arms on
*direct* recursion only, so **mutual cycles are unguarded** (tcsh has a
117-member SCC) and an undersized reserve fails as a silent neighbour spill, not
a clean exit-134. Do this only via a measured turn count, never a blind constant
cut, and promote `fgx_ld`'s unguarded-SCC warning to a tracked budget line.

---

## 5. Slice C -- the login stack proper

Depends on slice A (needs `/etc` writable and `ttyname` honest). Does **not**
depend on slice B, but its concurrency ceiling does.

Build order: libc gaps first (`ttyent`, `getpass`, password hash, utmp write
path), then `getty`, then `login`, then `init`'s rewrite, then `passwd(1)`.
`init` last because it is PID 1 -- a broken `init` is an unbootable disk, and
everything below it can be exercised from a shell first.

New `/etc` files: `passwd`, `ttys`, `group`, `issue`. All four are blocked on A1.

### Decisions taken

**Password hashing: a cheap non-DES hash now, real `crypt` later** (the maintainer,
2026-07-31). Classic 25-round DES `crypt` on a 2.8 MHz 65816 would make login
visibly pause, and the security value on a single-user IIgs is close to
decorative. **Give the hash a `$`-prefixed tag** so the file format stays
forward-compatible and a real DES `crypt` can coexist later without invalidating
existing entries.

**`login` execs the shell, it does not fork it.** Exec replaces the image and
frees the old stack, so the chain costs zero extra arena. Make this a rule across
the whole chain (`getty` execs `login` execs the shell), not a later
optimization.

**`login` must handle spawn ENOMEM gracefully.** On failure, report it and fall
back to `/bin/sh` rather than dropping the session. Until slice B lands this is
the *only* backstop against the arena ceiling, so it ships with the feature, not
after it.

### Correction worth recording: `/etc/ttys` has no shell field

An earlier draft of this scope claimed per-console shell policy via `/etc/ttys`
(console 1 tcsh, ttyv1/ttyv2 sh). **That is wrong.** A tty does not default to
any shell. `init` spawns `getty`; `getty` spawns `login`; `login` instantiates
the shell only after authentication, from that user's `pw_shell` in
`/etc/passwd`. `struct ttyent` carries `ty_name`, `ty_getty`, `ty_type`,
`ty_status`, `ty_window`, `ty_comment` -- no shell.

The consequence is real: the shell-cost lever is **per-user, not per-tty**, which
is materially weaker. Nothing prevents one user logging into all three consoles
and getting three copies of their own shell. Honest arithmetic against 126 pages
with guards counted:

| Scenario | Pages | Fits? |
|---|---|---|
| 3 consoles idle at `login:` | ~12 | yes |
| 1 tcsh + 2 sh + tar | 93 | yes |
| 3 users, all `pw_shell=/bin/sh` | 30 | yes |
| 3 users, all `pw_shell=/bin/tcsh` | 168 | **no, and no at the 150 ceiling either** |

So slice C delivers three working consoles and real login, with a hard ceiling of
roughly one deep shell at a time that no configuration removes. **Slice B3 is
what lifts it.**

The per-tty knob that *does* survive is `ty_type` -> `TERM`, which matters once a
serial getty runs on the SIM port, where the terminal type legitimately differs
from the SHR console.

---

## 6. Slice D -- multiple virtual consoles

Depends on C (there is nothing to put on a second console until getty/login
exist) and on B for concurrency beyond one deep shell.

Sketch, not yet designed:

- `NTTY` 3 -> N (`include/kernel.s:589`); the tty table is already indexed and
  `signal.s`'s tty-index arithmetic already loops for `NTTY > 1`.
- Per-VC `CharBuf`/`AttrBuf`. Bank $03 currently holds `CON_CHARBUF` at $030000
  and the alt-screen backup at $038000, so there is room; `console_altscreen.s`
  already demonstrates save/restore of 25 rows and names the scrollback
  limitation (rows 25..99 are not preserved) that a per-VC design must decide
  about.
- An alt-N hook in the keyboard path to switch the active VC and repaint.
- `/dev/ttyv0..N` registered through the existing dynamic chardev registry.
- `_ttyNames` from slice A2 grows with `NTTY` for free.

Serial getty on the SIM port is the natural sibling and is cheaper -- it needs no
console work at all, only a `/etc/ttys` entry and a `TERM` type.

---

## 7. Summary of dependencies

```
A (stage2 dir + ttyname)  ------> C (getty/login/passwd/init) ------> D (virtual consoles)
                                        ^                                 ^
B (stack arena) -- independent ---------+---------------------------------+
   B0 assertion  : do first, always
   B1 reclaim    : 126 -> 150 pages
   B3 lane swap  : what actually enables concurrent deep shells
```

**Recommended immediate work:** slice A in full, plus B0. Both are small, both
are regression fences, and neither depends on anything else.

## 8. Deferred, with reasons

- **Real DES `crypt(3)`** -- deferred behind the `$`-tagged hash seam. Revisit if
  BSD-compatible password files ever matter, and measure before committing.
- **`grp.h` / `/etc/group` / `initgroups`** -- `login` works without supplementary
  groups. Add when something needs group-based permission checks.
- **utmp/wtmp beyond `ut_line`** -- `who`/`w`/`last` want it; not on the critical
  path to a login prompt.
- **B2 (`CYCLE_TURNS` right-sizing)** -- small win, asymmetric risk; skip if B3 is
  going to happen anyway.
- **Kerberos, quota, lastlog, `setlogin`, `-h` hostname path** -- deleted from the
  `login` port outright. `-h` returns if telnetd ever wants it.
