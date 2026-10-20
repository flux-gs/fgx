# UFS 1.7d I3 -- mount UFS at /dev.  Survey, and the one decision that is not mine.

Written after I2c landed (`a50a5af84`).  The dispatch I3 needs now exists:
read, write, ioctl and select all go through `fp->f_ops` on the descriptor,
mutation-verified, so a vnode descriptor plugs in by having an f_ops rather
than by being added to five branch chains.

## What the campaign already decided

* **No synthesized /dev** (the maintainer, 2026-08-09).  Real IFCHR/IFBLK inodes on a
  real filesystem, created by `mknod`, opened by path.
* **Mount UFS *at* /dev while root is still ProDOS** -- consequence 4 of the
  device-model section, and the recommended way to get a real /dev before the
  root swap.
* **Route at the syscall boundary**, in `_Sys_Open`, before `Path_Resolve`.
  Load-bearing twice: it keeps `fs.s`/`prodos.s` sleep-free so
  `check_fs_sleep_invariant` retains its meaning, and it makes Phase 2's root
  swap "change which arm is the default" instead of new machinery.
* **Land the seam and its first customer in the SAME commit**, and keep the
  increment small.

## What the survey found

**The host half is ready.**  `tools/fgxfs.py mknod` writes `i_rdev` into the
low half of `di_addr[0]`, which is what 2.11BSD's union over the address array
requires, and its fsck checks device inodes rather than excusing them.

**The kernel half is ready.**  `ufs_mountfs` works and three probe gates mount
a volume with it.  `spec_open`/`close`/`read`/`write` dispatch onto the chardev
registry (1.13b).  `namei` and `vn_open` are in vfs.mod.

**`v_rdev` IS the registry index**, and the registry is filled in registration
order: `null` 0, then the two pty pairs 1-4, `ttyv1` 5, `ttyv2` 6, `console` 7,
`tty` 8, then whatever the modules register in `modload.conf` order (serial's
`tty01`, then `bpf0`).

## DECISION 1 (mine): node numbers must not be baked by hand

A static /dev image would carry those indices as literals, and they are a
property of `chardev.s`'s registration block plus `modload.conf`'s order.  Both
are tracked, so the numbers are deterministic -- but nothing would notice if
either moved, and the failure is a node that opens the WRONG DEVICE silently.

So the image is GENERATED from one source, and boot asserts a named node's
`i_rdev` against what the registry answers for the same name.  A drift then
stops the machine at the assertion rather than at a `/dev/null` that is really
a pty.

## DECISION 2 (the maintainer's): where the /dev volume physically lives

The plan does not say, and the three answers are materially different work.
Partitioning would settle it -- `/dev` as a partition of the boot unit -- but
the campaign puts partitioning behind 32-bit block numbers and it is not
landed, so it cannot be the answer for I3.

**A. A second SmartPort unit.**  `disk/fgxdev.po`, built by `fgxfs`, attached
as `-hard2`.  Kernel side is smallest: mount the second unit at boot, exactly
as the probe gates already mount `disk/ufsscratch.po`.

  * Cost: every test needs the image attached.  `extra_hards` is per-manifest
    by design -- run.py says a test that needs a second spindle "should say so
    itself rather than depend on the runner's environment" -- and /dev is
    needed by ALL 179, because `/bin/sh` opens `/dev/null` at startup.  That
    argues for making it a RUNNER default rather than a manifest key, on the
    grounds that /dev is part of the machine and not part of a test, which is
    the same reason the boot disk is not declared per-manifest.  One change in
    run.py, not 179.
  * Consequence: an FGX machine needs two units to have /dev.  Transitional --
    it folds into the UFS root at Phase 2.5 -- but real until then.

**B. A file-backed block device.**  Ship the UFS image as an ordinary file on
the ProDOS boot volume and give the kernel a block device that reads it.

  * Self-contained: one disk, no harness change, works on any machine.
  * Cost: a new block-device type, and it reads a ProDOS file from inside the
    block layer -- which is the sleep-free layer `check_fs_sleep_invariant`
    guards.  That interaction needs designing before it is costed.

**C. The RAM disk.**  Build /dev into the existing ramdisk at boot from a
staged image.

  * Cheapest to attach; `ramdisk.mod` and `/RAM5` already exist.
  * Cost: /dev is volatile, so `mknod` at runtime does not persist, and the
    staged image has to be copied in at every boot.  It is still REAL UFS with
    real inodes -- not the synthesized namespace the campaign rejected -- but
    it is a device that forgets.

**Recommendation: A.**  It is what "mount UFS at /dev while root is still
ProDOS" reads as, it reuses a mount path three probe gates already exercise,
and its cost is one runner change rather than new kernel machinery.  B is the
better end state for a single-disk machine and is worth doing if two units is
unacceptable -- but it is a bigger increment than the plan wants I3 to be, and
the plan is explicit that this is the increment to keep small.

## The steps, once decision 2 is made

1. **The volume.**  A ninja rule builds it with `fgxfs mkfs` + `mknod` per
   device, generated from the registry order rather than hand-written.
2. **Mount it at boot**, after `Mod_LoadConf` (ufs.mod must be up).  Assert the
   mount and one node's `i_rdev` against the registry.
3. **The syscall hook.**  `_Sys_Open` recognises the mount prefix before
   `Path_Resolve` and JSLs into vfs.mod: `namei` rooted at that mount's root
   vnode, `vn_open`, `f_ops = &vnops`, `f_data = ni_vp`.  A miss falls through
   unchanged -- the fall-through the `/ldev` rename already built and
   `devfallthru` already guards.
4. **The suite case.**  A STATEFUL device (not `/dev/null`, which certifies an
   arm that works for one device -- `ufs_devprobe.c`'s own warning), plus
   `ls /dev` and a redirection.
5. **`vfs_lseek`'s L_XTND**, the one arm apple/fgx#196 still owes: it needs
   `VOP_GETATTR`'s `va_size` and therefore a real vnode, which exists here.

## Red signal

`smoke` itself crosses the seam: `/bin/sh` opens `/dev/null` at startup from
pristine vendored source (`vendor/2.11BSD/usr/bin/sh/msg.c:65`), so all 34
tests exercise open-through-namei-through-`spec_*` the moment step 3 lands.
`ufsdevprobe` stays green underneath.
