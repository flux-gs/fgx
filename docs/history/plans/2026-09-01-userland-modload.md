# Loading modules from userland, the way BSD does

The maintainer, 2026-09-01: "plan on the full userland model for modload".

## Why

`Mod_LoadConf` reads `/etc/modload.conf` during kernel boot and loads each
module through the kernel-internal `Fs_Open`/`Fs_ReadN` path.  On a 2.11BSD
root that path answers **EBADF**: `Fs_ReadN` tests `FCB_StorageType`, that field
is written only by `prodos.mod`, and `_Fcb_Alloc` zero-fills, so every
descriptor opened through `vfs_openat` is typeless to the legacy reader.

MEASURED 2026-09-01 on `disk/fgxufs.po`: the volume boots to a shell, the four
modules `/etc/preload.conf` names come up, and **the six in `modload.conf` do
not**.  The console says so without a debugger -- no `mod: ... loaded` lines
for them, `fs: /dev SELF-TEST FAILED CODE 09`, `dhclient: no network
interface`, `inetd: telnet/tcp: socket: Function not implemented`, and a
`/bin/sh` `#` prompt where ProDOS gives tcsh's `fgx#`.

**Moving the call is not the fix and cannot be.**  `Fs_ReadN`'s refusal does
not depend on when it runs, so a kernel-side `Mod_Load` fails wherever it sits.
Routing `Fs_ReadN` to the far bank for a far-ops descriptor was built and
costed: **74 core bytes against 33 free** (`check_kernel_ceiling`: 58,009
exceeds 57,968 by 41).  The patch is kept at
`docs/history/plans/attic/frn-far-routing.patch` if the trade is ever wanted.

BSD does not have this problem because BSD does not do this.  NetBSD 0.9's LKM
is an ioctl on `/dev/lkm` driven by a userland `modload(8)` that runs `ld(1)`
(`lkm.4:52,121`, `modload.8:59,68`), run from `/etc/rc` after init.  FGX needs
no `ld(1)` -- an FGXM module is already linked and carries its own relocation
table -- so only the READING has to move, and userland reads through the
syscall path, which has been routed for far-ops descriptors since UFS 1.7d I3.

## The sequencing that matters

**A1 comes first, and it is campaign 2.5.**  The dependency pinning
`Mod_LoadConf` before init is not the VFS: it is the `/dev` MOUNT.  Measured by
moving the call below it -- the mount fails outright, no `fs: /dev on unit`
line, `/dev` self-test FAILED -- because a device node is only as good as the
driver behind it and `serial` and `pty` arrive in `modload.conf`.  The mount's
own comment blamed `ufs.mod`/`ufsdir.mod`, which are pre-staged and therefore
not the reason; that comment is corrected.

2.5 makes `/dev` a directory of the UFS root with `mknod` at image-build time,
which DELETES the mount and the dependency with it.  Doing modload first would
mean inventing a way to keep alive a mount that 2.5 is about to remove.

## The increments

### A -- remove the kernel-side dependencies

- **A1 = campaign 2.5.**  `/dev` becomes part of the root; `mknod` runs in
  `fgxfs` at image-build time; `dev_mount` and its boot-time call go.
- **A2.**  The `/RAM5` mount and the network bring-up move to `/etc/rc`, which
  is where BSD mounts from `fstab`.  `mount(2)` already exists (UFS 1.8).

### B -- the install interface

- **B1.  A STREAMING INSTALL, NOT A BUFFER.**  A module is up to a whole bank,
  so requiring userland to hold 64 KB and hand it over is the wrong shape.
  `modload_begin(name)` / `modload_data(buf, len)` / `modload_end()` lets the
  kernel MVN into the module bank as chunks arrive, which is what `Mod_Load`
  already does internally (<= 512 B at a time through `_fsDataBuf`).  Bank
  allocation, relocation and `mod_init` stay kernel-side; only the read moves.
  Headroom exists: 91 syscalls against `SYS_NUM_MAX` 109.
- **B2.  EACH MODULE BINDS ITS OWN VTABLE.**  `_Ram_LoadOpsPtr`,
  `_Pty_LoadOpsPtr` and `_Net_LoadOpsPtr` are three hand-placed `JSR`s in
  `main.s` that must match whatever `modload.conf` happens to contain -- an
  arrangement a module arriving at runtime cannot rely on.  Registration moves
  into the module's own `mod_init`, which is also what NetBSD's `lkmentry`
  does.  **Its own increment, ahead of C**, converting one module at a time
  while `main.s` still carries the binds as a fallback.

### C -- the tool and the policy

- **C1.**  `modload(8)`, in C: reads `/lib/modules/<name>`, drives B1.
- **C2.**  `/etc/rc` drives it from `/etc/modload.conf`; `modload.conf(5)` and
  `modload(8)` updated.
- **C3.**  `Mod_LoadConf` and the three binds leave `main.s`.

### D -- verification

- **D1.  FIX apple/fgx#290 FIRST.**  `modimage` declares `modbank0` and
  `modbank1` and there are FIVE ordinals (0 prodos+serial+bpf+net+ramdisk+pty,
  1 vfs, 2 ufs, 3 ufsprobe, 4 ufsdir), so it currently CANNOT witness whether a
  module loaded -- it skips an ordinal it has no dump for and then reports it
  "not found loaded".  Until that is fixed, D2's evidence is unreadable.
- **D2.**  A test that boots UFS and asserts all six `modload.conf` modules are
  up.  **The red control already exists**: today's UFS boot has four up and six
  absent, so the test can be written against a machine that fails it.

## What stays kernel-side permanently

`/etc/preload.conf`'s four.  Not a preference: a module read THROUGH a
filesystem can never BE the filesystem, which is the cycle `preload.conf(5)`
states.  `PRODOS` leaves that list only at phase 3, when ProDOS becomes a
mountable type -- and the phase-2 gate ("boots from UFS with no ProDOS module
loaded at all") depends on that, not on this plan.

## Risks

| Risk | How it is settled |
|---|---|
| A module is needed BEFORE init and cannot be deferred | Console getty uses tty[0], which is core, and `/ldev` is a core registry, so `serial` and `pty` look deferrable.  MEASURE before C3 rather than trusting this row |
| B2 changes every module's init contract | Its own increment, one module at a time, with `main.s`'s binds still in place as the fallback |
| A2 moves mounts into `/etc/rc`, which runs later than boot | `/RAM5` is a convenience, not a boot requirement; the root and `/dev` are unaffected (2.5 folds `/dev` into the root) |
