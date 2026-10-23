# Porting BSD utilities to FGX

The porting-specific half of adding a tool. The build mechanics (manifest
entries, staging, testing) are in [developing-userland.md](developing-userland.md);
the binary and runtime contract is in [userland-abi.md](userland-abi.md).

## Source

Userland ports take their source from the vendored 2.11BSD tree:

    vendor/2.11BSD/usr/{bin,ucb,usr.bin,sbin,old}/<name>[.c]

2.11BSD is a 16-bit-`int` (PDP-11) codebase written in K&R C, which matches fcc
exactly. Other trees under `vendor/` (4.3BSD-Reno, netbsd-0-9) are for
behaviour questions and second readings; a different source for a particular
tool is recorded as such in its provenance row. The full upstream distributions
live in the gitignored `examples/`; anything taken from there is vendored in the
same commit.

Every ported file keeps its upstream copyright and carries the provenance
header (`SPDX-License-Identifier`, `FGX-Provenance`), and gets a row in
[PROVENANCE.md](PROVENANCE.md); `tools/check_provenance.py` fails the build
otherwise. The man page comes along too (developing-userland.md, "Porting
instead of writing?").

## Recipe

1. **Copy the upstream source as-is** into `src/userland/<name>/`. K&R is fcc's
   native dialect: do not ANSI-fy definitions or drop `register`. A multi-file
   utility keeps its files: list the extra translation units in a `tu.list`
   and name it in the manifest's `tu_list` (`src/userland/ls/tu.list` is the
   model).  A large port can compile straight from `vendor/` instead, with
   the manifest's `main` naming its entry file and the `tu.list` naming
   the rest and any FGX copies (`src/userland/tcsh/tu.list`).
2. **Wire it into `tools/ninja/manifest.json`** (`tools` and `staging`; see
   developing-userland.md step 4), then `python3 tools/ninja/gen.py && ninja`.
3. **Take the errors fcc actually reports.** fcc fails closed, so the build
   tells you what is missing. The open gaps and hard limits are in
   [fcc-known-issues.md](fcc-known-issues.md). A gap is fixed in fcc or libc
   with a fixture (the toolchain-first rule), not by rewriting the BSD source.
   Every FGX change to the upstream text is a delta, and the provenance row
   names it.
4. **Run it** on the machine (`./mame-hd.sh`) and add a test only as
   developing-userland.md step 7 and [testing.md](testing.md) describe.

## Things that bite ports

- **Signal handlers.** BSD sources often `fprintf` and `longjmp` from a SIGINT
  handler (`ed`'s `onintr`, `more`). libc and the runtime's direct-page scratch
  are not reentrant, and delivery lands at a syscall exit where the
  interrupted libc function's state is live. A handler that only sets a flag is
  always safe; anything more is safe only if the interrupted code cannot be
  inside libc. The contract is [userland-abi.md section 6A](userland-abi.md).
- **Argument and environment limits.** A process sees at most 16 argv entries
  and 16 environment entries (`LSARGV_MAX`, `src/kernel/far/loader.s`;
  userland-abi.md section 5.2).
- **Struct return by value** is not supported; nor are multi-dimensional arrays
  of structs (fcc-known-issues.md).
- **Undeclared functions.** fcc follows K&R: an undeclared function returns
  `int`, so calling a pointer-returning function without a declaration loses
  the pointer's bank byte. fcc warns once per name per translation unit on an
  implicit declaration; take the warning seriously and include the header.
- **Temp files.** Ports that use scratch files (`ed`, `sed`, `sort`) should
  remove them on every exit path, including error exits and signals; FGX has no
  `/tmp` sweeper at boot.
- **stdio is 2.11BSD's**: `stdin`/`stdout`/`stderr` are `&_iob[0..2]`,
  `getc`/`putc` are macros on the FILE's count and pointer, and stdout is
  line-buffered on a terminal (`toolchain/include/stdio.h`).

## Candidates not yet ported

- `tail` (`vendor/2.11BSD/usr/ucb/tail.c`, 239 lines)
- `diff3` (`vendor/2.11BSD/usr/usr.bin/diff3/diff3.c`, 459 lines)
