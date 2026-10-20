# Moving libc out of toolchain/ into the OS source tree -- scope (2026-07-31)

**The maintainer, 2026-07-31:** "libc should probably move out of `toolchain/` into the main
source tree, similar to BSD's source."

Agreed, and the slice-A follow-ups are the evidence: two of the four build guards
fixed that day existed *only* because libc is built by the toolchain's `make`
while the OS is built by `ninja`. This doc scopes the move. It is a scoping doc,
not an implementation plan.

**Bottom line.** The prize is not tidiness. It is that
`toolchain/lib/libc_c.s` stops being a **checked-in generated file** and becomes
an ordinary build product. That single change dissolves follow-ups 3 and 4
outright, deletes the fingerprint sidecar and the hand-anchored
`build/libc_seg2.sha`, and makes a libc edit rebuild the things that depend on it
the way every other source in the tree already does. The blocker is small and
lives in fcc: its system include directory is derived from `dirname(argv[0])`,
so the headers cannot move until that derivation does.

---

## 1. Why this is worth doing (not just neater)

The current split is not OS-vs-compiler, it is historical: `apple/fcc` was
absorbed at `toolchain/` in the 2026-07-28 monorepo merge and libc came along
with it because it happened to live in the compiler's repo.

Three concrete costs, all observed:

- **`libc_c.s` is generated but checked in**, and the OS graph consumes it as a
  plain source. Editing `libc_c.c` and running `ninja all` reported "no work to
  do" and linked the OLD libc. This bit slice A and had to be found by hand;
  `tools/check_libc_piles.py` now guards it, but a guard over a structural
  problem is a splint, not a fix.
- **`build/libc_seg2.sha`** exists only because no single build graph owns both
  the pile and its consumers. It had to be hand-anchored on `tools/cat-fgx2/seg2`
  and, before 2026-07-31, silently rotted into a false RED.
- **`toolchain/Makefile` and `tools/ninja/gen.py` must agree** about libc's
  prerequisite set by hand. They had already drifted: the Makefile did not list
  `arpa/` or `netinet/` headers.

None of these are bugs in the guards. They are all the same structural fact
stated three ways.

## 2. What is actually OS and what is actually toolchain

`toolchain/lib/` currently mixes both. The BSD line is clean:

**OS -- the system's libraries, belongs in the OS tree:**

| Component | Files |
|---|---|
| libc (hand-asm) | `libc.s`, `libc_data.s` |
| libc (C) | `libc_c/`, `libc_c.s`, `libc_c_data.s`, `libc_c.srcsha` |
| libc net | `libc_net_c/`, `libc_net.s`, `libc_net_data.s` |
| libfgx (platform) | `libfgx_c/`, `libfgx.s`, `libfgx_data.s` |
| libcurses | `libcurses_c/`, `libcurses.s`, `libcurses_data.s` |
| libtermlib | `libtermlib_c/`, `libtermlib.s`, `libtermlib_data.s`, `libtermlib_helpers.s` |
| archives | `curses.fgxa/`, `resolv.fgxa/`, `termlib.fgxa/` |
| syscall ABI | `syscall.h`, `fgx_syscalls.inc` |
| public headers | all of `toolchain/include/` |
| csu | `crt0.s`, `crt0_far.s`, `args.s`, `args_data.s` (BSD: `lib/csu`) |

**Toolchain -- compiler support, stays put:**

| Component | Files | Why |
|---|---|---|
| compiler runtime | `fcc_runtime.s`, `fcc_runtime_data.s` | This is FGX's libgcc: `_fcc_mul16`, the stack-floor trap, the carrier arms. Emitted code depends on it, not the OS. |
| ABI glue | `fcc_libc_shims.s` | Bridges fcc's calling convention to the hand-asm libc. Arguably OS, but it changes with codegen, so it tracks the compiler. |
| assembler macros | `macros.s` | Merlin32 macro definitions, not an OS artifact. |

`crt0` is the interesting one: BSD keeps it in `lib/csu` (OS side), and FGX's
`crt0_far.s` encodes the FGX2 entry ABI, spawn argv/envp staging, and the
data-bank setup -- all OS contracts. It moves.

## 3. The blocker: fcc's include-path derivation

`toolchain/src/cc/main.c:414-429` derives the system include directory as
`dirname(argv[0]) + "/include"`, falling back to `"include"`. So `toolchain/fcc`
finds `toolchain/include` by construction, and nothing else can.

**Per the toolchain-first rule this is fixed in fcc, not worked around.** No
wrapper script, no `-I` sprayed across 130 tool manifests, no symlink. Options,
cheapest first:

1. **`-isystem <dir>` / `--sysroot <dir>`, with the current derivation as the
   fallback.** The build passes the real path once, in `gen.py`'s `fcc` rule
   variable. Existing behavior is preserved for anyone invoking `fcc` by hand.
2. **An `FCC_SYSINC` environment variable**, same fallback. Cheaper still, but
   environment-dependent builds are the kind of thing that makes a clean-clone
   failure hard to reproduce.

Recommend (1): explicit, visible in `build.ninja`, and a compiler flag is the
conventional place for this. Add a fixture that compiles against a sysroot in a
non-default location, or the flag will rot the first time nobody uses it.

## 4. Where things land -- three options

FGX's top-level `include/` is **kernel Merlin32 includes** (`kernel.s`,
`loader.s`, `config.s`, `memmap.s`). BSD puts kernel headers under `sys/` and
userland headers at `/usr/include`, so the name is already spoken for.

**Option A -- `src/lib/` + `src/include/` (recommended).**
Libraries at `src/lib/libc/`, headers at `src/include/`. Sits beside
`src/kernel/`, `src/drivers/`, `src/userland/`, which is the tree's existing
organizing idea. Top-level `include/` keeps its kernel meaning, so the kernel
side of the tree does not move at all. Least churn for the most clarity.

**Option B -- `lib/` + `include/` at the repo root, BSD-faithful.**
Mirrors `/usr/src/lib` and `/usr/include` most closely. Costs: top-level `lib/`
is currently the legacy `build_common.sh` directory and would have to be cleared
first, and userland `.h` would sit in `include/` next to kernel `.s`, which is
the muddiest outcome of the three. Fully faithful would mean moving the kernel
includes to `sys/` as well -- a much larger, separate change.

**Option C -- `src/lib/` only, headers stay put.**
Move the libraries, leave `toolchain/include/`. Half the benefit, none of the
fcc work. Worth naming only to reject: the headers are the OS's public API, and
leaving them behind keeps the include-path derivation as a permanent reason the
libraries cannot fully join the OS build.

## 5. The real prize: stop checking in generated piles

Once libc is in the OS graph, `libc_c.s`, `libc_c_data.s` and their siblings
become ordinary build outputs:

- **gitignore them.** No more 1.1 MB generated file in every diff.
- **Delete `tools/check_libc_piles.py` and `toolchain/lib/libc_c.srcsha`.** The
  staleness they guard becomes structurally impossible.
- **Delete the `libcsha` rule and `build/libc_seg2.sha`.** Every consumer depends
  on the pile directly, so there is nothing to fingerprint.
- **Delete the pile rules from `toolchain/Makefile`,** removing the
  hand-maintained prerequisite set that had already drifted.

`fcc` is already an input to the OS graph (`TOOLCHAIN_DEPS`), so the ordering
this needs already exists.

**One consequence to accept deliberately:** a clean clone can no longer build the
OS without first building `fcc`. Today the checked-in piles hide that. Given
`toolchain/` is in-tree since the monorepo merge, this is honest rather than
costly -- but `tools/cleanroom.sh` must be re-run, because that is exactly the
class of failure it exists to catch (it is how the tcsh two-phase build gap was
found).

## 6. Blast radius

Twelve files reference `toolchain/include` or `toolchain/lib` today:

```
tools/ninja/gen.py            tools/gate.sh            tools/libc_bisect.sh
tools/check_libc_piles.py     lib/build_common.sh
tools/elvis-fgx2/build_elvis.sh
tools/sh-fgx2/build_bsh.sh    tools/sh-fgx2/build_sh.sh   tools/sh-fgx2/gen_sh_link.py
tools/tcsh-fgx2/build_tcsh.sh tools/tcsh-fgx2/build_tcsh_link.sh
tools/tcsh-fgx2/gen_tcsh_link.py
```

Plus: `gen.py`'s explicit pile floor in `shell_deps()`, the generated
`seg*.link.s` PUT closures, the 130 tool manifests, and the 544 fcc fixture
goldens (check whether any embed an include path -- if they do, that is a
REGEN, and REGEN of goldens is never silent).

Use `git mv` so history follows the files; `check_provenance.py` tracks 98
registered 2.11BSD-derived files by path and will need its registry updated in
the same commit.

## 7. Suggested phasing

| Phase | What | Why first |
|---|---|---|
| **L0** | fcc gains `-isystem`/`--sysroot` + a fixture; derivation kept as fallback | Nothing can move until this lands, and it is independently harmless |
| **L1** | `git mv` the libraries to `src/lib/`, headers to `src/include/`; update the 12 references and the provenance registry; gate green | The move itself, still with checked-in piles -- one reviewable change that alters no build semantics |
| **L2** | Give the piles real ninja edges; gitignore them; delete `check_libc_piles.py`, `libc_c.srcsha`, `libcsha`, `build/libc_seg2.sha`, and the Makefile pile rules | The payoff. Separated from L1 so a bisect can tell "the move" from "the build-graph change" |
| **L3** | Re-run `tools/cleanroom.sh`; confirm a fresh clone builds fcc then the OS | The clean-clone contract changes in L2; this is the check that says so |

L1 is deliberately semantics-free: same build, same outputs, different paths. If
the gate goes red there, it is a path bug and nothing else -- which is the whole
reason not to fold L2 into it.

## 8. Not in scope

- Moving the kernel includes to `sys/` (Option B's full form). Separate change,
  much larger, no dependency on this one.
- Splitting `fcc_libc_shims.s`. It is ABI glue that tracks codegen; revisit only
  if it stops changing with the compiler.
- Anything about the BSD login stack (slices A-D) or the bank-0 stack arena.
  This is orthogonal to both and can land in any order relative to them.
