# Provenance & third-party attribution

The toolchain's provenance is registered in FGX's
**[../../docs/PROVENANCE.md](../../docs/PROVENANCE.md)**, alongside the kernel and
userland. The compiler, assembler and linker (`src/cc`, `src/as`, `src/ld`) are
original work; the C library, curses and termlib under `lib/` include code ported
from 2.11BSD and 4.3BSD-Reno, and `lib/libdouble/softdouble.c`,
`lib/libc_c/ldexp.c` and `lib/libc_c/modf.c` come from llvm-mos (Apache-2.0).
Every such file carries its upstream copyright and provenance header and has a
row in that registry, which `tools/check_provenance.py` enforces at build time.

## ORCA / "Opus ][: The Source" -- design oracle, NOT vendored code

Some of fcc's design was informed by studying the ORCA development tools' source,
published as **"Opus ][: The Source"** -- the ORCA/C compiler and linker,
**Copyright (c) Byte Works, Inc. / Mike Westerfield**. Specifically:

- the **multibank far-pointer model** (4-byte bank:offset, independently
  relocated), and
- the **linker's bank-consistency check** (fail the link, not the runtime, on an
  unintended cross-bank reference).

See [`decisions/orca-informed-decisions.md`](decisions/orca-informed-decisions.md)
for the decisions and the specific file cites.

**That source is copyrighted. We do not include or redistribute any of it here.**
fcc ships independent implementations of the *concepts* only -- never ORCA code.
The cites in the decisions doc point into the ORCA source for study; you need
your own copy of "Opus ][: The Source" to follow them.
