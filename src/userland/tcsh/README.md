# src/userland/tcsh — FGX-side port shims for tcsh 6.00

**This directory is deliberately (almost) empty.** It stays on the include
path (tcsh's manifest flags pass `-I` here) so a genuinely FGX-specific header can
be dropped in, but there are no header shims any more.

## Why the shims were deleted

It held seven headers — `unistd.h`, `utmp.h`, `varargs.h`, `sys/file.h`,
`sys/param.h`, `sys/signal.h`, `sys/uio.h`. Toolchain v1.20.0 promoted all
eight of the headers this port needs into the canonical FGX libc
(`toolchain/include/`) as proper BSD-compatible system headers, which made
every one of these a strict subset: audited symbol by symbol, the only
differences were their own include guards, plus `sigmask` (which lives in
`signal.h`, the header `sys/signal.h` layers over) and `sbrk` (in the
canonical `unistd.h`).

**They were not merely redundant, they were dangerous.** This directory is
`-I`'d BEFORE `toolchain/include`, so a shim SHADOWS the canonical header of
the same name — and a toolchain header fix is then SILENTLY INEFFECTIVE. That
already cost about an hour in this port: the `ru_ovly` fix landed in
`toolchain/include/sys/resource.h` while a stale shim here kept `sh.time`
failing with "no such field", and the failure was misattributed to a line
number in the C source. That shim was deleted then; these seven are the rest
of the same hazard.

The standing rule this follows: fix the toolchain, do not keep a per-port copy
of a standard header.
