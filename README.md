# FGX — Flux's GS uniX

*A [cCc] collective endeavor.*

[![build](https://github.com/flux-gs/fgx/actions/workflows/build.yml/badge.svg)](https://github.com/flux-gs/fgx/actions/workflows/build.yml)
&nbsp;
[**⬇ Download `fgx-2.0.0.fs`**](https://github.com/flux-gs/fgx/releases/download/v2.0.0/fgx-2.0.0.fs)
&nbsp;·&nbsp;
[all releases →](https://github.com/flux-gs/fgx/releases)
&nbsp;·&nbsp;
[latest from main →](https://github.com/flux-gs/fgx/releases/tag/main-latest)

> The button downloads this version's bootable 32 MB hard-disk image; every
> tagged release carries its own as `fgx-<version>.fs`. GitHub Actions builds
> it from the tag, with fcc's fixture suite. The images of the three newest
> commits on `main` are on the rolling `main-latest` pre-release, as
> `fgx-main-<commit>.fs`: untested between releases. On first boot, choose a time zone
> and turn on the devices and services the machine needs: see
> [Configuring a machine](docs/CONFIGURING.md).

FGX is a port of 2.11BSD to the Apple IIgs (WDC 65C816). Its kernel runs
2.11BSD's tty subsystem and clists, timekeeping, sysctl and kernel log, and
mounts a root filesystem in 2.11BSD's UFS format through 4.3BSD-Reno's VFS,
buffer cache, name cache and UFS code (2.11BSD has no vnodes). Most of its
userland -- init, getty, login, fsck, mount, the Bourne shell, tcsh, ed, sed,
tar and some seventy other tools -- is 2.11BSD source compiled for the 65816.
[`docs/PROVENANCE.md`](docs/PROVENANCE.md) registers every ported file against
its upstream in `vendor/`: kernel, userland and C library alike.

What FGX supplies itself is the machine-dependent half that 2.11BSD wrote for
the PDP-11, done again for the 65816 and the IIgs: the kernel core (syscall
trampoline, scheduler, interrupts, signal delivery), the boot blocks and
loader, memory management (a 2.11BSD-style resource map over 64 KB banks, with
no MMU), the drivers (SmartPort disks, the Super Hi-Res console, SCC serial,
Uthernet II, Ensoniq audio), the module and shared-library loaders, and `fcc`,
the K&R C compiler that builds the whole system on your host.

> **Status:** FGX boots its own 2.11BSD UFS image, checks the root with `fsck`,
> and comes up multi-user: `/etc/rc`, `getty` and `login` on the virtual
> consoles, `fork`/`vfork`/`execve`, job control, the full BSD signal set,
> preemptive multitasking (user code loses the CPU on a timer quantum; the
> kernel runs to completion), shared libraries, and TCP, UDP and Unix-domain
> sockets. `/bin/sh` is the 2.11BSD Bourne shell, `tcsh` is the interactive
> shell and `vi` is elvis. This is an active hobby project:
> [`docs/ROADMAP.md`](docs/ROADMAP.md) has the state of every subsystem.

## What it is

- **Kernel**: monolithic, in three 64 KB banks (core, far, tty) shipped as one
  `/fgxunix` image, with FGXM modules. The VFS and UFS modules are staged into
  that image; networking, serial, ptys, packet capture, the RAM disk, the
  kernel log and the shared-library loader load with `modload(8)` from
  `/etc/rc`, and the ProDOS filesystem type loads when a ProDOS volume is
  mounted.
- **System calls**: BSD system calls through one trampoline (`JSL $000328`
  followed by the call number), numbered as 2.11BSD numbers them wherever that
  slot was free; the catalog is in [`docs/userland-abi.md`](docs/userland-abi.md).
- **Processes**: `fork`/`vfork`/`execve`, `posix_spawn`/`waitpid`, process
  groups and job control, all BSD signals (every one catchable except SIGKILL
  and SIGSTOP), users, groups and permission checks.
- **Memory**: no MMU. A resource map modelled on 2.11BSD's (`subr_rmap.c`)
  hands out 256-byte pages from a pool of 64 KB banks; each process gets its
  own data bank, programs share their code, and five shared libraries (libc,
  libcurses, libtermlib, libutil, libfgx) are each loaded once: libc and libfgx
  at boot by `ldload(8)`, the others when a program first needs them.
- **Filesystem**: a 2.11BSD UFS root through the 4.3BSD-Reno VFS, checked by
  `fsck` at boot. `mount_prodos(8)` mounts ProDOS volumes, read-only or with
  `-o write`.
- **Networking**: an Uthernet II (WIZnet W5100, which runs TCP/IP in hardware)
  behind BSD sockets: UDP, TCP client and server, raw ICMP. The tools are
  `dhclient`, `ifconfig`, `route`, `ping`, `host`, `nc`, `telnet`, `telnetd`
  under `inetd`, `ntpd`, and `netdump` for packet capture through `/dev/bpf0`.
- **Console**: the Super Hi-Res screen as a VT100/ANSI-colour text console with
  loadable fonts, and three virtual consoles (Option-1 to Option-3). A Second
  Sight card adds a fourth (Option-4).
- **Userland**: 102 programs in `/bin` and `/sbin` with their man pages, among
  them `cron`, `syslogd`, `fsck`, `tar`, `compress`, `more` and the curses games.
- **Toolchain**: `fcc`, a K&R C compiler with a 16-bit `int` like 2.11BSD's,
  in-tree at `toolchain/` and run on your host. It emits 65816 assembly,
  **Merlin32** assembles it, and `fgx_ld` links multi-bank binaries, static or
  dynamic against the shared libraries. `fas`, an in-house assembler that also
  runs on FGX, is an experiment and does not build the system.

## Target hardware

- **CPU**: WDC 65C816. An accelerator (TransWarp GS, Zip GS, or an emulator's
  fast mode) is strongly recommended; a stock 2.8 MHz machine runs FGX, slowly.
- **ROM**: ROM 01 or ROM 03. The kernel halts on ROM 00.
- **RAM**: 4 MB is the realistic minimum; 8 MB is comfortable.
- **Storage**: a SmartPort hard disk or card (SCSI, CFFA, MicroDrive) for the
  32 MB `fgxroot.fs` image.
- **Networking** (optional): Uthernet II in slot 1.
- **Display**: Super Hi-Res; optionally a Second Sight card for a fourth console.

FGX runs on real hardware and in MAME, including the **Ample** front end.

## Building

**[Full build documentation → `docs/BUILDING.md`](docs/BUILDING.md)** — targets,
the image, the gate, the release loop. The short version:

The build compiles the userland with `fcc`, assembles the kernel and that
compiled output with **Merlin32**, links multi-bank binaries with the Python
`fgx_ld.py` shim, and produces a bootable 2.11BSD-filesystem disk image
(`disk/fgxroot.fs`) with FGX's own boot blocks. **ninja** drives all of it.

**Prerequisites** (install/obtain these first):

| Tool | Purpose |
|------|---------|
| **Merlin32** (Brutal Deluxe) | the production 65816 assembler — kernel, hand-asm, *and* the `fcc`-compiled userland |
| **cadius** (Brutal Deluxe) | builds the scratch ProDOS volume the `mount_prodos` tests attach as a second disk |
| **ninja** | runs the build graph |
| **Python 3** | generates `build.ninja`, the `fgx_ld.py` multi-bank linker, and the build gates (MX/address linters, layout generators, provenance check) |
| **A host C compiler + `make`** | builds the in-tree toolchain (`fcc`/`fas`) |
| **MAME / Ample** + an **Apple IIgs ROM03 ROM** | to *run* the image (the ROM is copyrighted — provide your own) |

One repo, **no submodules** — the C compiler, assembler and linker live in-tree
at `toolchain/` and are versioned and released with the OS.

```bash
git clone <fgx-repo-url> fgx
cd fgx

make -C toolchain            # builds fcc / fas + the libc piles (binaries aren't committed)
python3 tools/ninja/gen.py   # emits build.ninja from tools/ninja/manifest.json

ninja                        # kernel + modules + userland -> disk/fgxroot.fs
./mame-hd.sh                 # boot disk/fgxroot.fs in the emulator
```

Also: `ninja release` (just `disk/fgxroot.fs`, which is what CI publishes), `tools/gate.sh`
(build + the gate's boot tests, which write the receipt `release.sh` requires),
and `tools/cleanroom.sh` (build from a fresh clone).

**Emulator location.** The `mame-*.sh` launchers and the test harness default to
a macOS **Ample** install. On any other setup, point them at your emulator via
two environment variables (resolved centrally in `lib/mame_env.sh`):

```bash
export MAME=/path/to/mame64                 # an Apple IIgs-capable MAME build
export FGX_MAME_SUPPORT=/path/to/support    # holds roms/ bgfx/ artwork/ nvram/ plugins/
```

`$MAME` also falls back to `mame64`/`mame` on your `$PATH` if the Ample default
isn't present.

## Directory structure

```
fgx/
├── docs/          # architecture, ABI, and subsystem references (start: architecture.md)
├── include/       # kernel/ABI EQUates, macros, struct layouts (fs.s, kernel.s, loader.s, …)
├── src/
│   ├── boot/      # boot blocks and the stage-2 loader
│   ├── kernel/    # core, far and tty banks: syscalls, scheduler, coremap, signals, tty, VFS
│   ├── drivers/   # block devices, the fd layer, the RAM disk, console fonts
│   ├── modules/   # loadable FGXM modules (vfs, ufs, net, serial, pty, bpf, ...)
│   ├── userland/  # the programs: 2.11BSD ports and FGX's own tools
│   └── standalone/# standalone hardware test binaries
├── toolchain/     # fcc, fas, fgx_ld, and the C library (in-tree)
├── tools/
│   ├── ninja/     # manifest.json + gen.py -> build.ninja; image assembly
│   ├── mame_test/ # the headless MAME harness and its test manifests
│   └── …          # linters, gate.sh, cleanroom.sh, release helpers
├── vendor/        # upstream sources: 2.11BSD (kernel included), 4.3BSD-Reno, netbsd-0-9, tz, ...
└── disk_src/      # files staged into the disk image (/etc, /bin metadata, …)
```

## Documentation

**[Documentation index →](docs/README.md)** (everything, categorized). The
essentials:

- **[Architecture overview](docs/architecture.md)** — start here
- [Contributing](docs/CONTRIBUTING.md) — setup, the dev loop, the build gates, how work lands
- [Building](docs/BUILDING.md) — the ninja build, the image, the gate, the release
- [Configuring a machine](docs/CONFIGURING.md) -- the clock and time zone, devices, network services
- [Writing an FGX program](docs/developing-userland.md) · [Userland ABI & syscalls](docs/userland-abi.md)
- [Testing](docs/testing.md) — the gate, its budget, and the MAME harness
- [Roadmap & subsystem status](docs/ROADMAP.md)
- Subsystems: [kernel banks](docs/kernel-banks.md) · [memory map](docs/memory-map.md) · [scheduler](docs/scheduler.md) · [filesystem](docs/filesystem.md) · [networking](docs/networking.md) · [modules](docs/modules.md)

## Version history

See [CHANGELOG.md](CHANGELOG.md).

## Support, issues and contributions

**No support is offered or implied.**  FGX is a hobby project, provided as is.
We will try to answer questions, and contributions are welcome.

- **Questions and discussion:** join the community in **#fgx** on the
  [Apple II Infinitum Slack](https://apple2.gs/slack/).
- **Bugs:** open a [GitHub issue](https://github.com/flux-gs/fgx/issues/new/choose).
- **Changes:** send a pull request; [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)
  has the workflow.

References already in the tree (`#123`, `apple/fgx#123`) name issues in the
project's earlier, archived tracker.

### Reporting bugs

The bug report form asks for what we need to find the problem:

- **The FGX version**: the image file you booted, and `uname -r`.
- **The full hardware description**: model and ROM version, RAM, accelerator,
  the storage the image is on, and every card with its slot -- or, in an
  emulator, Ample or MAME with its version and settings.
- **A detailed explanation**: what you did, what you expected, what happened
  instead, any messages exactly as shown, and `dmesg` for a problem at boot.
- **How to reproduce it in Ample or MAME**, step by step from a fresh boot.  A
  bug we can reproduce in the emulator is one we can fix; if it happens only on
  real hardware, say what you tried in the emulator.
- **Screenshots**, or a photo of the screen.

## License

FGX is licensed under the **BSD 2-Clause License** — see [`LICENSE`](LICENSE).

Much of the kernel, the userland and the C library is ported from **2.11BSD**
and **4.3BSD-Reno** and retains the Regents of the University of California
copyright; each such file carries a provenance header and is listed in
[`docs/PROVENANCE.md`](docs/PROVENANCE.md).

Some components are under other licences, each named in its files' SPDX header
and in [`docs/PROVENANCE.md`](docs/PROVENANCE.md): **frotz** (GPL-2.0-or-later),
the **soft double** (Apache-2.0 with LLVM Exceptions,
[`vendor/65816-llvm-mos/LICENSE.TXT`](vendor/65816-llvm-mos/LICENSE.TXT)),
**cron** (Vixie cron's terms), **ntp** (UMD NTP 3.4, whose headers state no
licence) and four **elvis** files (Steve Kirkendall's: freely redistributable).
The full list is at the end of [`LICENSE`](LICENSE).
