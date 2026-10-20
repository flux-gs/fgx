# Building FGX

How to build `disk/fgxroot.fs` by hand, what else the build writes, and how a build
becomes a release. Contributor conventions (commits, where code goes, landing
work) are in [CONTRIBUTING.md](CONTRIBUTING.md); the release procedure itself is
in [RELEASING.md](RELEASING.md).

Ninja drives the whole build.

## Prerequisites

| tool | what for | notes |
|---|---|---|
| `ninja` | the build | `brew install ninja` |
| `python3` | build generation + all the gates/checkers | 3.8+ |
| `merlin32` | assembles the kernel and hand-asm | licensed Brutal Deluxe tool; CI builds it from the `apple/merlin32` fork |
| `cadius` | builds the ProDOS fixture volume the `mount_prodos` tests use | `apple/cadius` fork; 1.4.6 |
| a host C compiler + `make` | builds `fcc`/`fas` (not committed) | any cc |
| MAME or [Ample](https://github.com/ksherlock/ample) + an Apple IIgs **ROM 01 or ROM 03** image | booting the image | only needed to RUN, not to build |

The emulator path defaults to a macOS Ample install; point elsewhere with
`$MAME` / `$FGX_MAME_SUPPORT` (see `lib/mame_env.sh`).

## One-time setup

One repo, no submodules -- `fcc`, `fas` and `fgx_ld` live in-tree at
`toolchain/`.

```bash
git clone <fgx-repo-url> fgx
cd fgx
make -C toolchain              # builds fcc, fas, libc.so and the other shared libraries
python3 tools/ninja/gen.py     # emits build.ninja from tools/ninja/manifest.json
```

`build.ninja` is a generated file. Re-run `gen.py` after editing
`tools/ninja/manifest.json`, after adding a tool, or whenever ninja complains
about a missing edge. `tools/gate.sh` regenerates it for you.

## Building the image -- `disk/fgxroot.fs`

```bash
ninja                          # default target 'all': kernel + modules + userland
                               #   + linker probes + disk -> disk/fgxroot.fs
```

About 45 s from clean, a few seconds incrementally. Useful sub-targets when you
only want part of it:

| target | builds |
|---|---|
| `ninja kernel` | the three kernel banks (`bin/fgx.bin`, `bin/fgxfar.bin`, `bin/fgxtty.bin`) + the kernel source checks |
| `ninja userland` | the ~190 `bin/*.bin` programs (system, tools, shells and test binaries) |
| `ninja probes` | the shared-library and loader probe binaries, each linked by its own script |
| `ninja modules` | the loadable modules (`vfs`, `ufs`, `net`, `serial`, `pty`, `prodos`, ...) |
| `ninja man` | the preformatted man pages under `disk_src/usr/man/` |
| `ninja disk` | `disk/fgxroot.fs`, plus the scratch and fixture volumes the tests mount |
| `ninja release` | just `disk/fgxroot.fs`, the image CI publishes (see below) |
| `ninja all` | everything except `release` (the default) |

Ninja compares mtimes, not content, so a byte-identical relink can still
cascade. The staging rules use `cmp -s || cp` plus `restat = 1` to stop that at
the disk edge; if you see a spurious image rebuild, that is the mechanism to
look at.

`disk/fgxroot.fs` is built by `tools/make_ufsboot.sh`. You can call that script
directly to re-pack the image without consulting the graph, but prefer the ninja
target -- the script assumes the staged tree in `disk_src/` is current.

### The image

`disk/fgxroot.fs` is the one image: a 32 MB 2.11BSD filesystem that boots itself
-- stage 1 finds stage 2 from a baked block list, stage 2 reads `/fgxunix` off
the filesystem, and the kernel mounts the volume as its root.  The suite boots
it, `ninja release` builds it, and CI publishes it.  The 800 KB floppy is parked
(apple/fgx#340).

`make_ufsboot.sh` writes three files at image time rather than taking them from
the graph: `/etc/rc`, copied from `disk_src/etc/rc.in`, and `/etc/version` and
`/etc/build`, from git state and the clock -- nothing depends on a file for
those two, so they cannot be graph outputs.  `uname -r` and `uname -v` read them.

Before the image is built, `tools/prune_staged.py` takes out of `disk_src/`
whatever the build no longer produces.  Ninja cannot express "ensure this is
absent", which is how `disk_src/bin/jsh` once shipped after jsh was deleted.

## Booting what you built

```bash
./mame-hd.sh                        # boot disk/fgxroot.fs (slot-7 A2retroNET by default)
./mame-hd.sh -debug                 # under the MAME debugger
./mame-hd.sh -h                     # all flags
```

The defaults use only devices in stock MAME and Ample. `-microdrive` and
`-secondsight` are EXPERIMENTAL: they need MAME devices that no published MAME
or Ample release has yet, and the launcher refuses them on a MAME without them.
`tools/gate.sh` likewise skips, and names, any gate test that needs one of
these devices when the MAME it runs lacks it; set `FGX_GATE_EXPERIMENTAL=1` to
make that a failure instead.

Extra disk args mount on `-hard2`, `-hard3`, ... and appear under
`/mnt/<volname>/`.

## The source gates

`ninja` runs some thirty source-consistency checks (`tools/check_*.py`) as
ordinary build edges and **fails the build** if one trips -- each is its own
edge, so a failure names itself.  Among them:

- **MX-flag consistency** (`check_mx.py`) -- no implicit 8/16-bit mode leaks.
- **No baked kernel addresses** (`check_baked_addrs.py`) -- use `memmap.s`
  labels, not `$02Exxx` literals.
- **2.11BSD provenance** (`check_provenance.py`) -- every BSD-derived file
  carries its attribution header ([PROVENANCE.md](PROVENANCE.md)).
- **Syscall-table sync** (`gen_syscall_table.py --check`) -- the doc table
  matches `include/loader.s`.
- **W5100 patch-site drift** (`gen_w5100_patchsites.py`).

Each guards something that fails at runtime, silently, if wrong.

## The gate

```bash
tools/gate.sh              # checkers self-test -> gen.py -> ninja all
                           #   -> fcc fixtures IF toolchain/ changed
                           #   -> the gate's MAME tests -> receipt
tools/gate.sh --no-tests   # build only (writes a receipt, marked build-only)
```

A few minutes, longer when fcc's fixtures run. The gate's MAME tests are `smoke`
(boot `disk/fgxroot.fs`, reach a shell prompt, run `ls /`, check the listing) plus
a budgeted set of further boot tests, `GATE_TESTS` in `tools/gate.sh`, whose
declared time is capped by `tools/mame_test/gate_budget.py`.
[testing.md](testing.md) has the policy for what joins that set.

The verdict is a local artifact, `.gate/<sha>.json`, keyed by commit **and**
working tree (a dirty tree cannot inherit a clean commit's verdict). Posting it to
the forge as a commit status is an optional mirror (`FGX_GATE_POST=1`); a failed post is not a failed
gate.

A clone does not enable the repository's hooks by itself.  Once per clone:

```bash
git config core.hooksPath tools/hooks
```

The pre-push hook then starts the gate in the background on every push, and
its receipt is what `release.sh` reads.  `FGX_NO_GATE=1` skips it for a push
that changes nothing the gate can reach.

The fcc fixture run is gated on a content hash of fcc's **tracked** sources
(`git ls-files`), stamped only after they pass. Known gap: an untracked source
under `toolchain/` is invisible to that hash, so editing one will not retrigger
the fixtures.

## Building from a clean checkout

```bash
tools/cleanroom.sh [dest-dir]
```

Clones from `file://`, builds `fcc`/`fas`, generates the graph, runs `ninja
all`, and requires that `sh`, `elvis` and `tcsh` all built. This is the only
check that proves "it builds from a clean clone" rather than "it works on this
machine" -- the local gate cannot, because it runs in an environment full of
local state. It is a script, so it works offline and before pushing.

## Releasing

Full procedure in [RELEASING.md](RELEASING.md); the short version:

```bash
tools/gate.sh              # must be green -- release.sh READS the receipt
./release.sh               # preview: suggested bump + unreleased commits
./release.sh vX.Y.Z        # gate receipt -> changelog -> chore commit
                           #   -> push release/vX.Y.Z -> open the pull request
./release.sh --tag vX.Y.Z  # AFTER it merges (merge commit): push the tag
```

`release.sh` does not run the gate, it reads `.gate/<sha>.json` and requires
`mode: smoke`, `ok: true`, and a matching tree. A **missing** receipt is treated
exactly like a red one, and a `build-only` receipt is refused because it does
not attest that the OS boots. `main` changes only through pull requests,
which is why the release is a two-step.

There is no toolchain pin any more: `fcc` is in-tree and released with
everything else. A change spanning the compiler and the OS is one commit, one
branch, one review, one gate.

Pushing a `vX.Y.Z` tag runs the GitHub Actions build, which publishes
`fgx-X.Y.Z.fs` (from `ninja release`) on the tag's release.

## Troubleshooting

| symptom | cause |
|---|---|
| ninja rebuilds the image on every run | a step is writing its own inputs. Test: run the generator twice, then `ninja -n` -- it must say "no work to do". `write_if_changed()` is the mitigation. |
| a deleted tool keeps shipping | ninja cannot express "must be absent". `tools/prune_staged.py` prunes; `gen.py` warns. Check `disk_src/` by hand. |
| `merlin32: command not found` | licensed tool, not packaged. CI builds it from the `apple/merlin32` fork. |
| the toolchain rebuilt but nothing changed | `make -C toolchain` also builds libc.so and the other shared libraries; a rebuild of them is required for any libc experiment to take effect. |
| an "identical" / "unchanged" claim you did not fully believe | wipe all prior artifacts before comparing. A check whose tool did not run looks exactly like one that passed. |
