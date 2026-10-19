# Contributing to FGX

FGX is a port of 2.11BSD to the Apple IIgs (65C816). This is the contributor
home base: how to set up, the dev loop, where things go, and how work lands. New
to the system? Read [architecture.md](/docs/architecture.md) first. For the build
itself -- targets, the image, the gate, the release loop --
see [BUILDING.md](/docs/BUILDING.md).

## Getting set up

```bash
# One repo, no submodules: the toolchain (fcc/fas/fgx_ld) lives in-tree at
# toolchain/.
git clone https://github.com/flux-gs/fgx.git fgx
cd fgx
make -C toolchain                  # build fcc/fas (their binaries aren't committed)
python3 tools/ninja/gen.py         # emit build.ninja from tools/ninja/manifest.json
```

**Prerequisites:** Merlin32 (the kernel assembler), cadius (builds the ProDOS
fixture volume the `mount_prodos` tests use), **ninja**, Python 3, a host C
compiler + `make` (for the toolchain), and MAME /
[Ample](https://github.com/ksherlock/ample) + an Apple IIgs **ROM 01 or ROM 03**
image to run it. The emulator location defaults to a macOS Ample install; point
it elsewhere with `$MAME` / `$FGX_MAME_SUPPORT` (see `lib/mame_env.sh`). The
launcher and the gate use only devices in stock MAME and Ample.

## Developing with a coding agent

FGX is developed with a coding agent (Claude Code) working under the rules
below, and they are the best way to set one up here. FGX is an unusual
target: a 16-bit-`int` K&R compiler, a CPU with run-time register widths, no
MMU, and an emulator as the only test machine. An agent's instincts from
mainstream C or Unix are often wrong here. These rules are what keeps its work
correct.

**1. Put the rules in the agent's instruction file.** `CLAUDE.md` at the repo
root is gitignored for this purpose; agents that read `AGENTS.md` can use that
name. Start it with the standing rules:

- **Fix the toolchain, never work around it.** When fcc or libc lacks a
  construct or a function a port needs, the fix goes in `toolchain/` with a
  regression fixture. That means no per-tool asm stub, no local copy of a
  standard function, and no sed over generated output. A comment like "fcc can't
  X, so we ..." is the sign that the agent took the wrong road.
- **Read the source, don't cite from memory.** Before an fcc parser or codegen
  change, read the governing section of K&R 2nd edition Appendix A and quote the
  deciding sentence in the commit. Before a syscall, libc or kernel change,
  read the BSD counterpart in `vendor/` and name the file and function. See
  "Conformance" in [coding-standards.md](/docs/coding-standards.md); this rule has
  turned up a defect nearly every time it was applied.
- **Port from `vendor/`.** Userland comes from `vendor/2.11BSD/`, and the VFS/UFS
  layer from `vendor/4.3BSD-Reno/` (2.11BSD has no vnodes). Kernel sources are
  there too, under `usr/sys/`. Every ported file gets a
  [PROVENANCE.md](/docs/PROVENANCE.md) row, and the build fails without one.
- **ASCII only** in source and docs.
- **Comments describe the code as it is now.** History belongs in the commit
  body.

**2. Close the loop headlessly.** The agent can boot and test FGX by itself:

```bash
python3 tools/mame_test/run.py --headless smoke    # one test, no window
tools/gate.sh                                      # the definition of done
```

Each test is a JSON manifest in `tools/mame_test/tests/`, described in
[testing.md](/docs/testing.md). If MAME is launched any other way, it opens a window
on your screen unless `SDL_VIDEODRIVER=dummy` is set. Give every new probe a
known-bad input that it must report as bad: a check whose tool never ran looks
exactly like a pass. Don't edit the tree while the gate is running; the harness
refuses a stale image, and the gate then reports a failure that is not a test
failure. Keep tests small: a smoke test that covers the change beats a deep
probe suite.

**3. Give it a code index.** The tree is large (65816 assembly, C, Python, and
the vendored BSD trees). A code-search MCP server that indexes symbols (for
example jCodemunch) saves the agent a lot of blind grepping. Leave `vendor/` and
`examples/` out of the index unless you are porting.

**4. Give it the hardware references.** Apple's IIgs Firmware and Toolbox
references and the 65816 data sheet are not in the repository. An agent with a
searchable copy makes far fewer register-level and bank-crossing mistakes.

**5. Keep its memory out of the tree.** Session notes, handoff files and agent
memory stay local; they are gitignored or outside the repository. What a later
reader needs goes in the commit body or the docs.

**6. Review what it claims.** Ask the agent to say what it ran and what the
output was, and treat "should pass" as "not run".

## The dev loop

```bash
ninja                              # assemble the kernel + compile userland -> disk/fgxufs.po
                                   #   (also runs the source gates; see below)
ninja release                      # just disk/fgxufs.po, the image CI publishes
./mame-hd.sh                       # boot disk/fgxufs.po interactively  (./mame-hd.sh -h for flags)

tools/gate.sh                      # build + the gate's MAME tests; writes the receipt
                                   #   release.sh requires
tools/gate.sh --no-tests           # build only
```

The gate's MAME tests are `smoke` (boot, reach a shell prompt, run `ls /`, check
the listing) plus a budgeted set of further boot tests (`GATE_TESTS` in
`tools/gate.sh`); [testing.md](/docs/testing.md) has the policy for what joins it.

Re-run `python3 tools/ninja/gen.py` after editing `tools/ninja/manifest.json`
(or adding a tool); `tools/gate.sh` does it for you.

### The build gates

`ninja` runs some forty source-consistency checks (`tools/check_*.py`) and
**fails the build** if any trips. Each is its own edge, so a failure names itself
rather than failing "the build". Among them:

- **MX-flag consistency** (`check_mx.py`): no implicit 8/16-bit mode leaks.
- **No baked kernel addresses** (`check_baked_addrs.py`): reach kernel state via
  `memmap.s` labels / generated exports, not `$02Exxx` literals.
- **Provenance** (`check_provenance.py`): every BSD-derived file carries its
  attribution header (see *Porting* below).
- **Syscall-table sync** (`gen_syscall_table.py --check`): the doc table matches
  `include/loader.s` (see *Adding a syscall* below).
- **W5100 patch-site drift** (`gen_w5100_patchsites.py`): the generated
  patch-site listing matches the driver.

## Where things go

### New userland tools are written in C

**New userland tools are written in C and compiled with `fcc`**; there are no new
hand-assembled binaries. A tool is just `tool.c`, plus at most a small
hand-written syscall-stub `.s` (the fcc-generated `tool.s` is a build artifact;
add it to `.gitignore`, like `dhclient.s` / `ping.s`); the link files are
generated. The full walkthrough, with the files and the two-line
`tools/ninja/manifest.json` registration, is in
[developing-userland.md](/docs/developing-userland.md). A port of a BSD tool starts
from its vendored C source, never from a rewrite.

### Adding a syscall

1. Add `SYS_<NAME> EQU <n>` to `include/loader.s` **with a describing comment**;
   that comment *is* the published ABI (`name(args): A=.. X=.. -> C=.. / errno`).
2. Wire its handler into the dispatch table in `src/kernel/syscall.s`.
3. Run `python3 tools/gen_syscall_table.py` to regenerate the catalog in
   `userland-abi.md` section 4.3 (the build fails if you skip it).

### Porting BSD code

When you port a 2.11BSD (or other third-party) utility, **retain the upstream
copyright**: add the SPDX / `FGX-Provenance` header and a registry row per
[PROVENANCE.md](/docs/PROVENANCE.md). The provenance gate fails the build otherwise.
Porting gotchas (fcc's C subset, substitutions) are in
[userland-bsd-ports.md](/docs/userland-bsd-ports.md) and
[fcc-known-issues.md](/docs/fcc-known-issues.md).

### Code style

[coding-standards.md](/docs/coding-standards.md),
[calling-conventions.md](/docs/calling-conventions.md), and
[merlin32-reference.md](/docs/merlin32-reference.md). The repo ships an `.editorconfig`
for whitespace; the IIgs/65816 hardware lessons live in
[iigs-lessons/](/docs/iigs-lessons/).

## Commit messages

```
area: what changed, as a statement      # <= 72 chars
```

The **area** is the subsystem or tool the change is about: `fcc`, `kernel`,
`console`, `build`, `tcsh`, `stat(1)`, and so on. The subject states what is now
true (`fcc: a pointer argument to a long parameter keeps its bank`), not the
activity of changing it.

The **body** is what a reader of the history needs: what was wrong or missing,
what changed, and why. It is also the changelog entry: the changelog is each
commit's subject and whole body. Write it to inform, in plain sentences. Leave
out who asked for the change and how it was tested, unless the testing is itself the
point. When the change alters the syscall ABI, the kernel-module contract, the
boot/loader handoff or the on-disk image layout, say so in the body; that
decides the version bump (see [VERSIONING.md](/docs/VERSIONING.md)). An fcc or kernel
change that rests on K&R or BSD text quotes or names that text, as
*Developing with a coding agent* above describes.

## Issues and pull requests

**Report problems** in [GitHub Issues](https://github.com/flux-gs/fgx/issues),
with what you ran, what you saw, and how to reproduce it. Issue references
already in the tree (`#123`, `apple/fgx#123`) point to the project's earlier
tracker.

**Send changes** as a pull request against `main` from a branch in your fork:

1. Branch off `main`, and keep each pull request to one change.
2. Run `tools/gate.sh` and make it green. Say in the pull request what you ran
   and the result. CI does not build pull requests (the full build is heavy and
   runs only for releases), so your gate result is the evidence.
3. A maintainer reviews the pull request on GitHub.

Maintainers cut releases with `release.sh`; [RELEASING.md](/docs/RELEASING.md) has the
procedure. Pushing a `vX.Y.Z` tag makes CI build the image and publish
`fgx-X.Y.Z.po` as the release's download.

## Where to read next

- **[architecture.md](/docs/architecture.md)**: the whole system, start here
- [ROADMAP.md](/docs/ROADMAP.md): what's shipped vs planned
- Subsystem references: [memory-map.md](/docs/memory-map.md),
  [scheduler.md](/docs/scheduler.md), [filesystem.md](/docs/filesystem.md),
  [networking.md](/docs/networking.md), [modules.md](/docs/modules.md),
  [userland-abi.md](/docs/userland-abi.md)
- [The docs index](/docs/README.md): everything, categorized
