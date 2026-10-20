# FGXM Loadable Modules

> Source of truth: `include/{fgxm,modules,chardev,devnodes}.s`,
> `src/kernel/{modload,jumptable,chardev,net_dispatch}.s`, the modules under
> `src/modules/`, `tools/gen_modplace.py`, `tools/gen_kernel_exports.py`,
> `tools/mkfgxunix.py`, `disk_src/etc/rc.in` and `disk_src/etc/modload.conf`.
> Where this doc and the code disagree, the code wins.

The FGX kernel is three statically linked images -- the core, far and tty
banks (`KERNEL_BANKS EQU $03`, `include/kernel.s`).  Everything else that can
live outside them is an **FGXM module**: a flat binary loaded into a module
bank at an offset fixed at build time, which talks to the kernel through a
bank-0 jump table and registers what it provides.  The model is NetBSD's
loadable kernel module, installed from a userland `modload(8)` (NetBSD 0.9
`sbin/modload`, `sys/kern/kern_lkm.c`, in the gitignored `examples/netbsd-0-9/`);
2.11BSD has no loadable modules.  The container and ABI are FGX's own.  There is no unload.

## The modules

Every directory under `src/modules/`:

| Module | Bank ordinal | What it is | Loaded by |
|--------|--------------|------------|-----------|
| `vfs` | 1 | the 4.3BSD-Reno VFS layer (namei, vnode cache, buffer cache, `vfssw`), compiled from C | pre-staged in `/fgxunix` |
| `ufs` | 2 | the block half of 2.11BSD UFS: inodes, superblock, block and inode allocators, bmap, mount | pre-staged in `/fgxunix` |
| `ufsdir` | 4 | the name half of UFS: the vnode operations and the directory scan (calls into `ufs` and `vfs`, never the reverse) | pre-staged in `/fgxunix` |
| `ld` | 0 | the shared-library registry `ldload(8)` fills; reached through `LD_TRAMP` (`$00031A`) | `/etc/rc`, first and alone |
| `serial` | 0 | both SCC channels as ttys, `/dev/tty00` (channel A, printer port) and `/dev/tty01` (channel B, modem port), IRQ-driven through the Serial Interrupt Manager | `/etc/rc.local`, off by default |
| `bpf` | 0 | `/dev/bpf0`, raw-frame capture through W5100 MACRAW | `/etc/rc.local`, off by default |
| `net` | 0 | the socket layer, UDP/ICMP/TCP over the W5100, the 127.0.0.1 loopback transport, AF_UNIX datagram sockets, and the `pipe(2)` rings (`pipe.s`) | `/etc/rc` |
| `ramdisk` | 0 | the RAM-disk block device (`RAM5`) | `/etc/rc` |
| `pty` | 0 | the pseudo-terminal pairs (`/dev/ptyp*`, `/dev/ttyp*`) | `/etc/rc` |
| `sscon` | 0 | the console on a Second Sight card's Host Text mode; registers as a console backend via `KSVC_CONBACKEND`, and does nothing if the card is absent | `/etc/rc.local`, off by default |
| `cda` | 0 | classic desk accessory support: patches the Desk Manager's SaveAll/RestAll so the Ctrl-OA-Esc menu restores FGX's border and text colours; `/dev/cda` | `/etc/rc.local`, off by default |
| `klog` | 0 | `/dev/klog`, the kernel log ring for syslogd; port of 2.11BSD `usr/sys/sys/subr_log.c` | `/etc/rc` |
| `fpsim` | 0 | the floating point simulator: one shared copy of fcc's soft double, reached through `FPSIM_TRAMP` (`$000324`); until it loads a double operation raises SIGILL (FGX's counterpart of 2.11BSD `usr/sys/pdp/mch_fpsim.s`) | `/etc/rc` |
| `ufsprobe` | 3 | filesystem self-tests; assembles to a bare header unless a probe gate in `cfg/system.cfg` is on, and is staged only then | `/etc/rc`, last, when present |
| `prodos` | 5 | the ProDOS filesystem type under the VFS: mount, lookup, read, readdir (`vfssw[MOUNT_PRODOS]`) | `mount_prodos(8)` |
| `prodosw` | 6 | the write half of the ProDOS type (bitmap, write, create, remove, rename, truncate) | `mount_prodos(8)`, for a writable mount |
| `common` | -- | not a module: `kc_sys.s` (the C-to-kernel seam every C module shares) and `probe_dev.s` (the probe disk scan), `PUT` into the modules that need them | -- |

Ordinals come from `tools/gen_modplace.py` `OWN_BANK`; absent means 0, the
shared bank.

## Banks and placement

Module code is ORG-dependent and Merlin32 emits no relocation information, so
each module is assembled for the exact offset it will be loaded at:

- A module's FGXM load address (+4) carries that offset in its low 16 bits and
  a **bank ordinal** in its high byte.  Modules assemble at `$05xxxx`
  (`FGX_MOD_ORG_BANK EQU $05`), so `$05` is ordinal 0, `$06` ordinal 1, and so
  on (`include/fgxm.s`).
- `tools/gen_modplace.py` assigns offsets at build time.  Ordinal 0 is the
  shared bank, packed as a chain in `ORDER` order with each module rounded up
  to a page; each other ordinal is its own chain starting at 0.  A module gets
  its own ordinal for size, not isolation.  The generated offset lands in
  `src/modules/<m>/modplace.s`.
- `Mod_Load` maps each ordinal to a real bank it allocates on first use
  (`_modBankTab`, `MOD_BANK_MAX EQU 7`, `src/kernel/modload.s`), and records
  each module's byte range so an image built against a different layout is
  refused instead of overwriting a running neighbour.  A module bank is never
  freed.
- `vfs`, `ufs` and `ufsdir` are the filesystem, which has to exist before
  anything can be read from disk, so they are **segments of `/fgxunix`** (the
  kernel image, as 2.11BSD ships one `/unix`).  The boot program places them in
  the three-bank module window of the rest-of-OS handle
  (`REST_KMOD_FIRST_OFF`, `include/kernel.s`) and passes the kernel a bank
  list; `tools/mkfgxunix.py` builds the segment table and refuses more kmod
  segments than the window holds.  See `fgxunix(5)`.  Every other module is
  loaded through the root into pool banks.

## The FGXM binary format

A 40-byte v2 header (`FGXM_HEADER_SZ`), defined in `include/fgxm.s`:

| Off | Size | Field |
|-----|------|-------|
| +0 | 4 | magic `'FGXM'` |
| +4 | 3 | load address: offset in the module bank (lo16), bank ordinal (hi byte) |
| +7 | 1 | header format version (`FGXM_OFF_FMTVER`; v2 = 2) |
| +8 | 2 | `mod_init` entry, bank-relative (`mod_init-$050000`) |
| +10 | 2 | text size (bytes copied) |
| +12 | 2 | BSS size (bytes zeroed) |
| +14 | 2 | vtable-directory offset (within text) |
| +16 | 16 | module name, NUL-padded |
| +32 | 2 | module version (reserved, 0) |
| +34 | 2 | kernel build identity (`FGXM_OFF_COREBUILD`; 0 = not build-locked) |
| +36 | 4 | reserved |

`Mod_Load` refuses a module whose build identity disagrees with the running
kernel's (published at `MOD_JT_CORE_BUILD` by `_JT_Init`): the module baked
kernel addresses at build time (see `kernel_exports` below), and against
another kernel build they are wrong.  `tools/check_build_id.py` guards it.

The **vtable directory (VTDR)** is the ASCII magic `'VTDR'` followed by
`(type, offset)` word pairs and a `VT_END` terminator.  Types
(`include/modules.s`): `VT_FST`, `VT_CONSOLE`, `VT_INPUT`, `VT_SOUND`,
`VT_BLOCKDEV`, `VT_HELLO`, `VT_CHARDEV`, `VT_NET` (net.mod's op table),
`VT_VFSCORE`, `VT_UFSCORE`, `VT_PDCORE` (the C entry points vfs, ufs and
prodos export to the modules that build on them).

## Loading

At boot:

1. The kernel registers the pre-staged `vfs`, `ufs`, `ufsdir` from memory
   (`Mod_RegisterPreLoaded`, `src/kernel/main.s`), then mounts the UFS root.
2. `/etc/rc` loads `ld` alone (so `ldload(8)` can make the shared libraries
   resident before `fsck`), then, after the root is writable, the rest every
   machine needs in one process: `/sbin/modload net ramdisk pty klog fpsim
   $UFSPROBE`.  The modules for hardware a machine may not have -- `serial`,
   `bpf`, `sscon`, `cda` -- are lines in `/etc/rc.local`, which
   `/etc/rc` sources last and which ships with each commented out (see
   [CONFIGURING.md](CONFIGURING.md)).  `/etc/modload.conf` holds the same
   list in the same order and `tools/check_modload_lists.py` fails the build
   if they disagree; **`rc.in` and `rc.local` are the list that runs**.
3. `mount_prodos(8)` runs `modload(8)` when the kernel answers `ENODEV` (no
   such filesystem type): `prodos`, plus `prodosw` for a writable mount.

**`modload(8)`** (`src/userland/modload/modload.c`) opens
`/lib/modules/<name>` and streams it to the kernel through `SYS_MODLOAD` (110):
`ML_BEGIN` claims the single load session, the 40-byte header goes over as its
own `ML_DATA` chunk so the kernel can validate it and claim the byte range
before any text is written, the text follows in 512-byte chunks, and `ML_END`
zeroes BSS, walks the VTDR and runs `mod_init` (`Mod_RegisterStreamed`).
`ML_ABORT` gives back the session and the claimed range on any failure.

`mod_init` must return `C=1`; on `C=0` the load fails with `ENOEXEC` and the
module's slot stays idle.

The kernel also has an in-kernel reader, `Mod_LoadConf`, called from
`main.s` after the pre-staged set and before the root is mounted.  It reads
`/etc/modload.conf` through `Fs_Read` (`src/kernel/modload.s`), which does not
serve the UFS root (see the header of `modload.c`), so on a UFS root `/etc/rc`
is what loads the modules.

## The jump-table ABI

**Module to kernel** is a `JSL` into the module jump table, a bank-0 gateway
at `MOD_JT_BASE = $00032E`: a 6-byte header (ABI version, core build id,
reserved) and **32** 4-byte `JML` slots, filled by `_JT_Init` with the
running kernel's bank.  Bank 0 is the one address a module can name without
knowing where the kernel landed.  Slot numbers are positional
(`include/modules.s`); the authority on what a slot does is
`_JT_Targets` in `src/kernel/jumptable.s`.

| Slots | Service |
|-------|---------|
| 0-2 | `SYS_BLKPIN` / `SYS_BLKUNPIN` / `SYS_BLKPINZ` -- block-cache pins |
| 3 | `SYS_KCALL` -- the multiplexed service slot (below) |
| 4-6 | `SYS_BLKREAD` / `SYS_BLKWRITE` / `SYS_BLKSTATUS` |
| 7 | `SYS_CONPUTCHAR` |
| 16, 17 | `SYS_KERNLOG`, `SYS_PANIC` |
| 23 | `MOD_REGISTERCHARDEV` |
| 24 | `SYS_MODLOG` |
| 25, 26 | `SYS_SIM_INSTALL` / `SYS_SIM_REMOVE` (SCC interrupt handlers) |
| 27-31 | `SYS_NETKC_*`, net.mod's callbacks |
| 8, 9-11, 12-15, 18-22 | unimplemented or retired: `_Phase1_StubHalt`, a red border and a halted machine |

The gateway cannot grow, so new module-to-kernel services are **`SYS_KCALL`
service numbers**, not slots: `JSL SYS_KCALL` with `X` = service, `A`/`Y` =
arguments; `C=1` + results, or `C=0` + `A` = errno, and an unknown service
returns `ENOSYS` rather than halting.  `KSVC_COUNT` is 58; the numbers are
append-only.  They cover kernel heap (`KSVC_KMALLOC` / `KSVC_KFREE`), logging,
sleep/wakeup, tty and chardev services, the current pid/uid/gid, time, and
pool-bank grants (`KSVC_BANKGRANT` / `KSVC_BANKFREE`).

**Kernel to module** goes through what the module registered, via
self-modifying `JSL`+`RTL` cells in bank 0 (the 65816 has no `JSL [dp],Y`):

- **Character devices** -- `_Chardev_Dispatch` (`src/kernel/chardev.s`)
  patches `_cdTrampJSL` (`$03B8`) with the op from the module's
  `CharDev_Ops` (`COPS_Open`/`Close`/`Getc`/`Putc`/`Ioctl`/`Poll`/`DRead`/
  `DWrite`/`Stop`, `include/chardev.s`).  The op is entered with DBR = the
  kernel's bank; an op that reads its own statics sets DBR itself.
- **Networking** -- `_Net_Dispatch` (`src/kernel/net_dispatch.s`) patches
  `_netTrampJSL` (`$03C2`) with an entry from net.mod's `VT_NET` table; the
  socket syscalls, the socket `read`/`write` path and `Fs_Close`'s socket
  teardown go through it.
- **Filesystems** -- a filesystem module fills its `vfssw` row through
  vfs.mod (`vfs_setvfsops`) and the Reno VFS dispatches through vnode ops.
  Modules built on another module resolve its `VT_*CORE` table with
  `KSVC_FINDVTABLE`.
- **Trampoline vectors** -- `ld` and `fpsim` point a bank-0 `JML` vector
  (`LD_TRAMP`, `FPSIM_TRAMP`) at themselves in `mod_init`.

### Registration

- **Declarative** -- the loader records each VTDR entry in the module
  registry (`_modRegPtr`, a Kmalloc'd soft-global); the kernel and other
  modules find it with `Mod_FindVtable` / `KSVC_FINDVTABLE`.
- **Imperative** -- `mod_init` calls `MOD_REGISTERCHARDEV`, `SYS_SIM_INSTALL`,
  or a `SYS_KCALL` service such as `KSVC_CONBACKEND`.

### Device numbers

A module that owns a `/dev` node registers **at that node's number**: it
passes `CDF_FIXED` plus the number in `Y`'s high byte to
`MOD_REGISTERCHARDEV` (`include/chardev.s`), and the number comes from
`include/devnodes.s` (`DEVNODE_TTY00`, `DEVNODE_BPF0`, `DEVNODE_KLOG`, ...),
which `tools/ninja/gen.py` generates from the same `DEV_NODES` lists that make
the nodes on the volume.  The device number is therefore the build's, not an
artifact of which modules loaded first on a given machine.

### Reaching kernel state -- `kernel_exports`

A module that touches kernel statics cannot hard-code their addresses.
`tools/gen_kernel_exports.py` scrapes them from the freshly built kernel
listing into a per-module `src/modules/<m>/kernel_exports.s` (the module `PUT`s
it), in the manner of 4.4BSD `ld -A /vmunix`.  It is regenerated every build, a
renamed or removed symbol fails the build, and it stamps the build identity the
FGXM header carries.  Direct-page offsets (`include/dpmap.s`) and struct field
offsets a module bakes in have no such guard and move in lockstep by hand.

## Limits

- **The gateway is full-size by construction.**  32 slots at
  `$032E`-`$03B3`, in page 3's fixed-cell block (see
  [memory-map.md](memory-map.md)); new services are `KSVC_*` numbers.
- **Placement is a chain.**  Growing a module earlier in `ORDER` moves every
  module after it in the same bank, including the placement-absolute
  `w5100_patchsites.s` tables in `net` and `bpf`, which then need
  regenerating (header of `tools/gen_modplace.py`).
- **Some handoffs predate `KSVC_KMALLOC`.**  The bpf capture block
  (`_Bpf_AllocBlk`) and the socket descriptor table are allocated kernel-side
  and handed to the module.
- **Kernel-static ceiling.**  Core-bank statics stay below `$02FE00`, enforced
  by an `ERR` on `KMem_KGlobals_end` (`include/memmap.s`).  See
  [memory-map.md](memory-map.md).

## Source map

| Area | File |
|------|------|
| FGXM format | `include/fgxm.s` |
| Jump-table slots, `KSVC_*`, `VT_*` | `include/modules.s` |
| Chardev ABI, `CDF_FIXED` | `include/chardev.s`, `src/kernel/chardev.s` |
| Device numbers | `include/devnodes.s` (generated by `tools/ninja/gen.py`) |
| Loader | `src/kernel/modload.s` |
| Jump table + slot implementations | `src/kernel/jumptable.s` |
| Net dispatch + socket syscall thunks | `src/kernel/net_dispatch.s` |
| Placement | `tools/gen_modplace.py` |
| Kernel-address scraper | `tools/gen_kernel_exports.py` |
| Pre-staged segments | `tools/mkfgxunix.py` |
| Userland loader | `src/userland/modload/modload.c` |
| Modules | `src/modules/*/` |
| Load lists | `disk_src/etc/rc.in`, `disk_src/etc/modload.conf` (`tools/check_modload_lists.py`) |
