# Writing an FGX program

This is the path for writing a program that runs *on* FGX. New userland tools are
**C, cross-compiled with `fcc`** (the host compiler, in-tree at `toolchain/`
— it runs on your machine, not on the IIgs). FGX is a 2.11BSD port: `main(argc,
argv)`, 2.11BSD system calls, files and sockets are fds, and a BSD C library shared as
`libc.so` (stdio, `malloc`, string/ctype, time, syslog, ...). The binary ABI is in
[userland-abi.md](userland-abi.md); the syscall catalog is §4.3 there.

The canonical minimal example is **`src/userland/true/`** — copy it.

> **All C tools link as FGX3** (the FGX2 layout plus a mandatory ABI stamp;
> `fmt` defaults to `FGX3` in `tools/ninja/gen.py`). `fcc` emits one output mode (far calls + data segment), and
> every C tool registers with a one-line entry in
> **`tools/ninja/manifest.json`**. You need **only your `.c`**: the link
> driver (`fgx_dyn`, or `fgx_static` for a manifest tool marked `"static"`)
> generates seg0 (code) and seg1 (data) with no hand-written `.link.s`; a
> dynamic program binds to the shared `libc.so` at exec, a static one carries
> the libc functions it reaches.
> `FGX1`/`FGX2` survive only as loader formats for legacy binaries; never write
> a new one. `ed` is the reference C tool.

## Anatomy of a tool

A C tool is **one file** in `src/userland/<name>/` (plus one optional):

| File | Role |
|------|------|
| `<name>.c` | your program — `int main(int argc, char **argv)`, returns the exit status |
| `<name>_stubs.s` | *optional* — only if you call a syscall libc doesn't wrap |

(No link file: `tools/ninja/gen.py` registers the tool, and the link driver
(`fgx_dyn`, or `fgx_static` for a manifest tool marked `"static"`) generates
the seg0/seg1 link at build time.)

The fcc-generated `<name>.s` is a **build artifact** — `.gitignore` it.

## Step by step

1. **Create `src/userland/<name>/<name>.c`.** Write `main`. A couple of fcc
   gotchas to know up front (full list in [fcc-known-issues.md](fcc-known-issues.md)
   and [userland-bsd-ports.md](userland-bsd-ports.md)):
   - Large `char[]` locals are fine: the linker sizes each binary's
     bank-0 hardware stack from fcc's frame call graph, and overflow trips the
     `STKGUARD` trap loudly. Buffers handed to syscalls that take an own-bank
     offset still belong in the data bank (file-scope).
   - `float` (32-bit), `double` and `long double` (64-bit, soft) and
     `long long` (64-bit) work, as does real `va_arg`, as do `%ld` and
     width/precision specs like `%7ld`.
   - **Signal handlers set a flag and return — nothing else.**  libc and the
     fcc DP scratch are not reentrant; a handler that calls printf/fopen/
     malloc, does pointer or `long` arithmetic, or `longjmp`s can silently
     corrupt whatever it interrupted.  The contract (and why) is
     [userland-abi.md §6A](userland-abi.md).
   - Temp files must be unlinked on *every* exit path, including signals.

2. ~~Create a `.link.s`~~ -- **not needed.** The link driver supplies the
   whole link: `fgx_dyn` (or `fgx_static` for a manifest tool marked
   `"static"`) puts the crt0 (`crt0_dyn.s` + `crt0_lib.s`, or `crt0_lib.s`
   alone), your compiled `.s` and the fcc runtime in seg0, and the data
   segment fcc always emits in seg1.  A dynamic program binds to the shared
   `libc.so` at exec; a static one carries the libc functions it reaches in
   its own segments.

3. **(Optional) raw syscalls.** If you need a syscall the libc doesn't wrap, add
   `<name>_stubs.s` with a tiny stub per call — load the args off the stack and
   trampoline:

   ```asm
                   FGX2_EXPORT mycall_ ; FGX2_FARCALL resolves via fgx_ld exports
   mycall_         MX   %00
                   LDA  4,S            ; first arg (fcc pushes right-to-left, so
                                       ;  the first is at 4,S, above the 3-byte
                                       ;  JSL return frame; an int second at 6,S)
                   JSL  SYS_TRAMP
                   DFB  nn             ; the call's SYS_* number, include/loader.s
                   RTL                 ; far return (one-mode: every C call is JSL)
   ```

   Three rules: every C-callable entry gets an **`FGX2_EXPORT`**, returns with
   **`RTL`** (not RTS), and reads C args one byte deeper (the **first** arg at
   `4,S`, the next at `6,S` for a 2-byte argument). If the stub passes the kernel a buffer
   by *offset*, the buffer must live in the **data bank** (kernel buffer
   writes go via the caller's DBR) — never a `DS` in the stub file; see the
   `ticks()` note in `toolchain/lib/libfgx_c/libfgx.c`. See
   `src/userland/fractal/fractal_stubs.s` for the `FGX2_EXPORT`/`RTL`/DBR
   pattern (it passes values through C globals rather than stack args), and
   declare the stub in your `.c` as an `extern` prototype.

4. **Register it in `tools/ninja/manifest.json`** — two places:
   - `tools`: `{ "name": "<name>" }`.  Optional keys: `flags` (extra fcc
     flags), `libs` (comma-separated libraries, e.g. `"termlib,curses"`),
     `tu_list` (a file listing extra `.c` translation units), `main` (the
     entry `.c` when it is not `src/userland/<name>/<name>.c`, e.g. one in
     `vendor/`), `yacc: true` (source is `<name>.y`), `static`, `commons`
     (K&R tentative definitions shared across translation units),
     `pack` (the linker places every translation unit but the entry in code
     segments itself) or `seg3_tus`/`seg4_tus` (by hand), `stack_pad`, and
     `gen_script`/`gen`/`gen_deps` (headers generated before any compile).
     `parse_tools` in `tools/ninja/gen.py` documents each; sh, tcsh and elvis
     use most of them.
   - `staging`: `{ "src": "bin/<name>.bin", "dst": "disk_src/bin/<name>" }`.

   That is all: `tools/ninja/gen.py` derives the build edges and the staging
   copy from those two entries.

5. **`.gitignore` the generated `.s`:** add `src/userland/<name>/<name>.s`.

6. **Build and run:**
   ```bash
   ninja                 # fcc compiles <name>.c -> <name>.s, merlin32 assembles it,
                      #   fgx_dyn links it,
                         #   it's staged into disk/fgxufs.po
   ./mame-hd.sh          # boot and run your tool from the shell
   ```

   After editing `manifest.json`, re-run `python3 tools/ninja/gen.py` to
   regenerate `build.ninja`.  `tools/gate.sh` does this for you.

7. **Prove it works, with the cheapest thing that can fail.**  In this order,
   and stop at the first one that can catch your defect:

   - run it: `./mame-hd.sh`, then your tool from the shell;
   - add the case to an existing manifest's `command` -- a second assertion on
     a boot that is already being paid for is free;
   - a **source assertion** (a ninja edge, seconds, no emulator) if the fault
     is visible in the source rather than only at runtime.

   A **new JSON manifest is the last resort**, not step 7's default, and one
   that runs in the gate needs a slot in the gate's TIME BUDGET: `GATE_TESTS`
   in `tools/gate.sh` is capped, so adding a test there means taking one out.
   `tools/mame_test/gate_budget.py` enforces that; [testing.md](testing.md) is
   the policy and explains why the bar is this high.

## Porting instead of writing?

Porting a 2.11BSD (or other) utility follows the same mechanics, plus you must
**retain the upstream copyright** (the SPDX / `FGX-Provenance` header + a registry
row — see [PROVENANCE.md](PROVENANCE.md); the build's provenance gate enforces
it). The porting guide is
[userland-bsd-ports.md](userland-bsd-ports.md).

**Always add the man page.** A port isn't done until `man <tool>` works. Copy
the 2.11BSD cat page from `vendor/2.11BSD/usr/man/cat1/<name>.0` (or, if it
is not vendored yet, from the gitignored `examples/2.11BSD/usr/man/cat1/`,
vendoring it in the same commit) to `src/userland/man/pages/cat1/<name>.0`; the build rewrites it to FGX console
form and stages it at `/usr/man/cat1`. (Man pages are vendored reference data,
not compiled source, so they need no SPDX header.)

**Toolchain-first:** when a port needs something fcc/libc lacks — a missing
function/syscall **or** an unsupported C construct (a pointer typedef, a
multi-token macro) — fix it in the toolchain, never work around it in the tool
or the build pipeline. See *Developing with a coding agent* in
[CONTRIBUTING.md](CONTRIBUTING.md), whose first rule this is.

## See also

- [userland-abi.md](userland-abi.md) — the binary format, the calling convention,
  the syscall catalog (§4.3), and the libc surface (§6).
- [CONTRIBUTING.md](CONTRIBUTING.md) — the dev loop, the build gates, landing work.
