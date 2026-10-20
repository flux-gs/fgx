# fcc — the FGX C toolchain

*A [cCc] collective endeavor.*

Host-cross C toolchain for FGX development only. Not a general-purpose
65816/ProDOS/GS-OS environment. The compiler, assembler and linker run on your
**host** and target FGX's binary format; what runs on the IIgs is the runtime in
`lib/` (crt0, libc and the shared libraries) and the experimental on-disk `fas`
below.

- `fcc` — **K&R C** compiler (src/cc/), emits 65816 asm. The grammar and
  semantics fcc obeys are K&R Appendix A, on a pcc-shaped declarator recursion;
  16-bit `int`, matching 2.11BSD. It takes some ANSI conveniences on top —
  prototypes are accepted (including abstract declarators in externs), plus
  `void`, `enum`, `typedef`, `long`, `long long` (64-bit), `float` (32-bit
  single) and `double`/`long double` (64-bit, soft double in `lib/libdouble/`).
  It is **not C89**: no `#`/`##` preprocessor operators; macro parameters ARE
  substituted inside char/string literals (K&R behaviour that ANSI removed);
  `__STDC__` is not defined; `const`/`volatile`/`register`/`auto` are parsed and
  discarded; implicit declarations are legal (warned once per name per TU).
  C90 completeness is a long-term goal, not the current state.
  `dirname(argv[0])/include` is
  the system-header path, so `fcc` and `include/` must stay siblings (both at root).
- `src/ld/fgx_ld.py` — FGX2 multi-bank linker driver (the Python linker shim).
- `lib/` — language runtime, crt0, the C library (C sources in `lib/libc_c/`,
  plus curses, termlib and friends, each built into a shared library such as
  `libc.so.1.0`), and the syscall contract (syscall.h).
- `fas` — an in-house 65816 assembler (src/as/); also cross-compiled by `fcc`
  into `/usr/fgx/bin/fas` on the FGX disk (built as `tools/fas/fas_fgx`).
  **Experimental, not the build assembler** — the production assembler for the FGX build is **Merlin32** (a third-party
  prerequisite), which assembles everything `fcc` emits; `fas` self-hosts
  on-device as a product/experiment and can't yet co-assemble a full code bank.

## Build & test
    make            # -> ./fcc ./fas
    make test       # fcc golden suite (needs merlin32 on PATH)

## Relationship to FGX
**This directory is part of the FGX monorepo.** There is no submodule and no
pin: edit this tree freely, `make -C toolchain` from the FGX root, and a change
spanning the compiler and the OS is one commit, one branch, one gate, one release. FGX owns
the syscall contract *values* (the SYS_TRAMP/SYS_* EQUs in FGX's
`include/loader.s`) — see lib/syscall.h.

fcc's pre-merge history and its own release tags (`v1.16.0` … `v1.24.0`) live in
the archived `apple/fcc` repo; all 1094 pre-merge SHAs were rewritten by the
subdirectory filter, so old SHAs resolve only there.

## License
BSD 2-Clause — see [`LICENSE`](LICENSE). Same license and provenance discipline
as the parent FGX repo. The compiler, assembler and linker are original work.
The C library, curses and termlib include code ported from 2.11BSD and
4.3BSD-Reno, and the soft double and two math routines come from llvm-mos
(Apache-2.0); every such file is registered in FGX's
[`docs/PROVENANCE.md`](../docs/PROVENANCE.md). The linker/codegen *design* was
informed by studying the copyrighted ORCA tools source ("Opus ][: The
Source"), which is **not** included or redistributed here — only independent implementations of the concepts. See
[`docs/decisions/orca-informed-decisions.md`](docs/decisions/orca-informed-decisions.md).
