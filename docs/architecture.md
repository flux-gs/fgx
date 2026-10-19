# FGX Architecture Overview

The "start here" map of the system. Each section is a summary; the linked
reference docs and the named source files are authoritative. For what is
planned, see [ROADMAP.md](ROADMAP.md).

## What FGX is

FGX is a port of 2.11BSD to the Apple IIgs (WDC 65C816). The kernel's
machine-independent subsystems and most of the userland are BSD source,
compiled for the 65816. Ported files are registered one by one, with their
upstream in `vendor/`, in [PROVENANCE.md](PROVENANCE.md). Two pieces are FGX
assembly modelled on a 2.11BSD file rather than ports, and have no PROVENANCE
row:
the coremap (`src/kernel/bank.s`, after `subr_rmap.c`) and the pty driver
(`src/modules/pty/pty.s`, after `tty_pty.c`).

| From | What | Upstream |
|---|---|---|
| 2.11BSD | tty line discipline and clists, timekeeping, kernel log, sysctl, the user-pool resource map (modelled on, not ported), UFS; init, getty, login, fsck, mount, the Bourne shell, tcsh and most tools; much of libc, curses and termlib | `vendor/2.11BSD/usr/sys/sys/` (`tty.c`, `tty_subr.c`, `kern_time.c`, `subr_log.c`, `subr_rmap.c`, `ufs_*.c`), `vendor/2.11BSD/usr/{bin,ucb,sbin,...}` |
| 4.3BSD-Reno | the vnode layer above UFS (2.11BSD has no vnodes): VFS, name lookup and cache, buffer cache, file and vnode operations, spec and dead vnodes | `vendor/4.3BSD-Reno/kern/vfs_*.c`, `vendor/4.3BSD-Reno/ufs/` |

What FGX writes itself is what the PDP-11 hardware gave 2.11BSD and the IIgs
does not: the 65816 kernel core in Merlin32 assembly (syscall trampoline,
scheduler, interrupts, signal delivery), the three kernel banks, the boot
blocks, loader and `/fgxunix` image, the coremap's placement over 64 KB IIgs
banks, the FGXM module system, the drivers (SmartPort disks, the Super Hi-Res
console, Zilog SCC serial, the Uthernet II's W5100, the Ensoniq DOC), the
FGX2/FGX3 executable formats, shared libraries, and the `fcc` K&R C toolchain
that builds all of it on the host.

The machine has no MMU, so protection between processes is advisory. The
realistic minimum is 4 MB of RAM; 8 MB is comfortable.

## System layers

```
+--------------------------------------------------------------------+
| Userland   2.11BSD tools, sh, tcsh, daemons; FGX3 binaries,        |
|            dynamic against libc.so (ldload) or static              |
+--------------------------------------------------------------------+
| FGXM modules (loaded by /etc/rc, or on demand)                     |
|   ld  serial  bpf  net  ramdisk  pty  sscon  cda  klog  fpsim      |
|   prodos/prodosw (mount_prodos)                                    |
+--------------------------------------------------------------------+
| FGXM modules staged inside /fgxunix:  vfs  ufs  ufsdir             |
+--------------------------------------------------------------------+
| Kernel: three 64 KB banks from one /fgxunix image                  |
|   core (asm): syscalls, scheduler, signals, coremap, IRQ, seams    |
|   far:  console, loader, clock, sound, kernel-C VFS seams          |
|   tty:  2.11BSD tty.c / tty_subr.c, kern_time.c; FGX's tty_dev.c   |
+--------------------------------------------------------------------+
| Boot: stage 1 (block 0) -> stage 2 (src/boot/stage2.s)             |
+--------------------------------------------------------------------+
| Hardware / ROM: 65C816, SHR, ADB, Ensoniq DOC, SmartPort, SCC,     |
|   Uthernet II (W5100), Memory Manager and heartbeat Toolbox calls  |
+--------------------------------------------------------------------+
```

**Boot.** Stage 1 in block 0 reads stage 2 from a baked block range. Stage 2
(`src/boot/stage2.s`) walks the UFS boot volume for `/fgxunix`, reads its
segment table, and copies each segment into the bank the table names: the
three kernel banks and the vfs, ufs and ufsdir modules. The kernel mounts the
UFS root read-only and starts `init`, which is 2.11BSD init(8)
(`src/userland/init/init.c`). `/etc/rc` (`disk_src/etc/rc.in`) loads the
shared-library loader and libraries, runs `fsck -p`, remounts the root
read-write, and runs `modload` for the remaining modules. `init` then starts
`/bin/sh` on the console and `getty` on `ttyv1`-`ttyv3` (`disk_src/etc/ttys`).

**Kernel banks.** The kernel is monolithic, in three contiguous banks claimed
as one Memory Manager handle (`KERNEL_BANKS`, `include/kernel.s`): the core
bank, the far bank at core+1 and the tty bank at core+2, each with its own
code and static-data ceiling. The core is assembly; the far and tty banks mix
assembly with kernel C compiled by `fcc`. The kernel is relocatable: bank
numbers in the source are assembly-time ORGs. See
[kernel-banks.md](kernel-banks.md).

**Modules.** Everything else in kernel space is an FGXM module: a relocatable
image with a header, loaded by `Mod_Load` (`src/kernel/modload.s`) at a
build-assigned offset (`tools/gen_modplace.py`). Modules call the kernel
through a jump table at `MOD_JT_BASE` and build-resolved exports; the kernel
calls into a module through dispatch seams (`_Net_Dispatch` for networking,
the chardev switch, and `vfs_setvfsops` for filesystems). `/etc/modload.conf`
lists them; see [modules.md](modules.md).

## Process model

Processes are BSD's: `fork`, `vfork`, `execve`, `posix_spawn`, `wait`/
`waitpid`, process groups and job control, users and groups with permission
checks, and reparenting to PID 1. Signals are the BSD set; all are catchable
except SIGKILL and SIGSTOP (`src/kernel/signal.s`), and delivery happens at
syscall return.

Scheduling is preemptive for user code: the 60 Hz Toolbox heartbeat raises a
reschedule request every `QUANTUM_TICKS` (`include/kernel.s`), honoured at the
next syscall boundary or fcc-emitted loop safepoint. Kernel code runs to
completion and blocks with `_sleep`/`_wakeup`. `NPROC` is `kernel.nproc` in
`cfg/system.cfg`. Each scheduled task holds one of a few kernel-image slots
(a kernel stack and direct page in language-card RAM); an idle task's slot is
parked to a per-process home image when another task needs it. See
[scheduler.md](scheduler.md).

## Memory

User memory is 2.11BSD's resource map (`_coremap`, `src/kernel/bank.s`, from
`vendor/2.11BSD/usr/sys/sys/subr_rmap.c`) over a pool of 64 KB banks in
256-byte pages, first fit with coalescing on free. FGX adds one rule BSD does
not need: no allocation crosses a bank, because a 65816 code or data segment
cannot span one. Each process has its own data bank; code banks are shared as
text between processes running the same program, and shared libraries are
resident once. When the pool runs dry, `Bank_Alloc` falls back to a Memory
Manager grant.

Bank 0 holds the trampolines, block staging, and an arena of user stacks; a
task's user direct page is the first page of its stack reservation.
Reservations may overlap, and a non-running task's bytes are parked and
restored when it next runs. The layout is generated from `cfg/system.cfg`
into `include/config.s`. The kernel heap (`Kmalloc`/`Kfree`) starts in two
boot arenas and grows into pool banks. See [memory-map.md](memory-map.md),
`include/kernel.s` and `include/memmap.s`.

## Filesystem

The root is a 2.11BSD UFS filesystem on `/dev/sd0` (`disk_src/etc/fstab`),
reached through the 4.3BSD-Reno VFS. The VFS and UFS code is kernel C in
`src/kernel/vfs/`, built into the vfs, ufs and ufsdir modules; each filesystem
type registers its operations with the VFS switch through `vfs_setvfsops`.
`mount(2)` takes Reno's arguments, and `fsck` checks the root at boot. ProDOS
volumes mount through the loadable `prodos` filesystem type, plus `prodosw`
for its write half; `mount_prodos(8)` loads them on demand and mounts
read-only unless asked for `-o write`.

Each task's descriptor slots and the per-open FCBs are FGX's
(`src/drivers/fs/`); behind them, the open-file table is 4.3BSD-Reno's
`kern_descrip.c` (`src/kernel/vfs/vfs_file.c`, in the far bank). `struct stat` is 2.11BSD's layout (`src/kernel/vfs/statlayout.h`). See
[filesystem.md](filesystem.md).

## Devices and the tty

Block I/O goes through the SmartPort driver (`src/drivers/block/block.s`)
and a block cache. Character devices are reached through the chardev switch
(`src/kernel/chardev.s`).

The terminal layer is 2.11BSD's: `tty.c`, `tty_subr.c` and the clists run in
the tty bank (`src/kernel/tty/`), and the heartbeat hands each arrived key to
`ttyinput` at interrupt time, which recognises the interrupt and suspend
characters and posts the signals. The console is the Super Hi-Res screen as a
VT100/ANSI-colour text terminal with loadable fonts
(`src/kernel/far/console/`), with three virtual consoles (Option-1 to
Option-3) and a fourth on a Second Sight card through `sscon` (Option-4).
`serial` drives the SCC ports as `/dev/tty00` and `/dev/tty01`, `pty` supplies
pseudo-terminals (FGX assembly modelled on 2.11BSD `tty_pty.c`), `ramdisk` a RAM disk, and `klog` the
kernel log device. The Ensoniq DOC plays the alert tone
(`src/kernel/far/sound.s`). See [drivers/console.md](drivers/console.md).

## Networking

The network hardware is an Uthernet II, whose WIZnet W5100 runs TCP/IP in
silicon. `net.mod` (`src/modules/net/`) puts BSD sockets in front of it: UDP,
TCP client and server, raw ICMP, a 127.0.0.1 loopback transport, and AF_UNIX
datagram sockets. The kernel keeps only the W5100 bring-up and interrupt
handler (`src/kernel/uthernet.s`) and the `_Net_Dispatch` seam, so the socket
syscalls return ENOSYS when the module is absent. `bpf` provides packet
capture on `/dev/bpf0`; libc has a resolver (`/etc/hosts`, then DNS). See
[networking.md](networking.md).

## Executables and libraries

Userland binaries are FGX3: multi-segment, each segment in its own bank, with
a relocation table the loader applies at exec and a mandatory ABI-version
stamp. FGX1 and FGX2 remain accepted by the loader. System calls are
`JSL SYS_TRAMP` (`$000328`) followed by an inline call-number byte, numbered
in `include/loader.s` up to `SYS_NUM_MAX`.

Programs link either statically or dynamically against the shared libraries
in `/lib` (libc, libcurses, libtermlib, libutil, libfgx, `.so.1.0`). `/etc/rc`
loads the `ld` module, and `ldload(8)` makes libc and libfgx resident (the
libraries after libc are listed in `/etc/ld.so.conf`); the others load the
first time a program needs them. See
[userland-abi.md](userland-abi.md) and [fgx2-linker.md](fgx2-linker.md).

## The toolchain and build

The toolchain is in-tree at `toolchain/` and released with FGX. `fcc` is a
K&R C compiler with 2.11BSD's 16-bit `int`, run on the host; it emits 65816
assembly, Merlin32 assembles it, and the `toolchain/src/ld/` linkers
(`fgx_static`, `fgx_dyn`, built on `fgx_ld`) produce FGX3 binaries and the
shared libraries. `fas`, an in-house assembler that also runs on FGX, is not
the build assembler. See [fcc-known-issues.md](fcc-known-issues.md).

Ninja drives the whole build from `tools/ninja/gen.py`, with source-consistency
checkers as build edges, and produces one bootable image, `disk/fgxufs.po`.
`tools/gate.sh` is the boot-test gate a release requires. See
[BUILDING.md](BUILDING.md), [testing.md](testing.md) and
[developing-userland.md](developing-userland.md).

FGX does not use message-passing IPC; the abandoned microkernel design is
recorded in [history/ipc.md](history/ipc.md).

## Where to read next

| Topic | Doc |
|---|---|
| The core, far and tty banks | [kernel-banks.md](kernel-banks.md) |
| Address space, bank 0, the coremap | [memory-map.md](memory-map.md) |
| VFS, UFS, ProDOS mounts, file descriptors | [filesystem.md](filesystem.md) |
| FGXM modules and the jump table | [modules.md](modules.md) |
| Scheduling, sleep/wakeup, process lifecycle | [scheduler.md](scheduler.md) |
| Sockets and the W5100 | [networking.md](networking.md) |
| Syscall ABI, executable formats, crt0 | [userland-abi.md](userland-abi.md) |
| Every BSD-derived and third-party file | [PROVENANCE.md](PROVENANCE.md) |
| Coding conventions | [coding-standards.md](coding-standards.md), [calling-conventions.md](calling-conventions.md) |
