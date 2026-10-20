# FGX Documentation

Start with **[architecture.md](architecture.md)** for the whole system, then dive
in below.

## Start here

| Doc | What |
|-----|------|
| [architecture.md](architecture.md) | the whole system: what is 2.11BSD's, what is FGX's own, and how the layers fit |
| [ROADMAP.md](ROADMAP.md) | what's shipped vs planned, per subsystem |
| [CONTRIBUTING.md](CONTRIBUTING.md) | setup, the dev loop, the build checks, how work lands |
| [BUILDING.md](BUILDING.md) | build `disk/fgxroot.fs` by hand, the image, the gate, the release |

## Developing for / contributing to FGX

| Doc | What |
|-----|------|
| [developing-userland.md](developing-userland.md) | write a program that runs on FGX (your `.c` + a one-line manifest entry) |
| [userland-abi.md](userland-abi.md) | binary formats, calling convention, the **syscall catalog** (section 4.3), the C library |
| [testing.md](testing.md) | the gate, what runs beside it, and the MAME harness |
| [fcc-known-issues.md](fcc-known-issues.md) | the `fcc` C dialect and its open gaps |
| [userland-bsd-ports.md](userland-bsd-ports.md) | porting a BSD utility |
| [PROVENANCE.md](PROVENANCE.md) | the registry of every BSD-derived and third-party file, with its `vendor/` upstream |
| [coding-standards.md](coding-standards.md) · [calling-conventions.md](calling-conventions.md) · [merlin32-reference.md](merlin32-reference.md) · [fgx2-linker.md](fgx2-linker.md) | code style and conformance rules, kernel calling conventions, the assembler, the multi-bank linker |

## Subsystem references

| Doc | What |
|-----|------|
| [kernel-banks.md](kernel-banks.md) | the core, far and tty kernel banks, the `/fgxunix` image, and how calls cross banks |
| [memory-map.md](memory-map.md) | bank 0, the kernel banks, the user bank pool and the coremap |
| [scheduler.md](scheduler.md) | processes, Model-A preemption, signals and job control |
| [filesystem.md](filesystem.md) | the 4.3BSD-Reno VFS over a 2.11BSD UFS root, ProDOS mounts, device files |
| [networking.md](networking.md) | BSD sockets over the W5100, AF_UNIX, DHCP, `/dev/bpf0` capture |
| [modules.md](modules.md) | the FGXM loadable-module system and its kernel interface |
| [drivers/console.md](drivers/console.md) · [iigs-text-mode-mmio.md](iigs-text-mode-mmio.md) | the SHR console, and the IIgs text-mode hardware |
| [bank0-blkstage-relocation.md](bank0-blkstage-relocation.md) | why the block staging buffer and the stack arena base stay where they are |
| [fgx-runtime-debugging.md](fgx-runtime-debugging.md) | debugging a running image |

## Process & hardware notes

| Doc | What |
|-----|------|
| [VERSIONING.md](VERSIONING.md) · [RELEASING.md](RELEASING.md) | SemVer policy + the release loop |
| [cosmetic-todo.md](cosmetic-todo.md) | the backlog of small open items |
| [iigs-lessons/](iigs-lessons/) | hard-won 65816 / IIgs / Merlin32 / MAME lessons |
| [history/](history/README.md) | dated records: plans, campaign logs, assessments and measurements -- not the live record |
