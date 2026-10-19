# Monorepo + Ninja + real CI — build/release restructure

**Date:** 2026-07-28
**Status:** IMPLEMENTED 2026-07-28 (phases 0-4) on `feat/monorepo`; unpushed
**Supersedes:** the 2026-07-16 "detangle toolchain from OS" decision (kept its
directional intent, replaced its two-repo mechanism)

## Problem

A single minor release costs most of a day. The maintainer: *"every minor release runs
build gates while testing the feature, both for fcc and fgx, twice over, again
for each MR created, twice over, and again when pins are moved, twice over."*

Four independent causes, measured 2026-07-28.

### 1. There is no CI worth the name

`apple/fcc` has **no `.gitlab-ci.yml` at all**. `apple/fgx`'s CI runs **zero
tests** — its whole build stage is:

```yaml
- make -C toolchain
- ./build.sh release
- ./build.sh verify
- test -s disk/fgx-floppy.po
```

No `tests/run.sh`, no farcalls, no `run_runtime.py`, no MAME. It builds an
artifact and publishes releases.

**So 100% of the real gate runs on one Mac, in the foreground, serially, twice
per MR, across two repos.** This is the dominant term. Everything below is a
multiplier on it.

It also explains `release.sh`'s shape: it re-runs the gate because *nothing
else ever ran it*. The re-gate is not paranoia, it is the only gate.

### 2. libc lives in the compiler repo

Every OS-library change is therefore a compiler release: fcc feat MR -> fcc
release MR -> tag -> FGX pin MR -> FGX release MR.

Worse, fcc's fixture gate pays for it. Measured on `tests/M11` (20 fixtures):

```
fcc compile only ......  0.06 s
full run.sh --dir ..... 28.0  s
```

Every fixture PUTs the whole pile — `macros + crt0_far + fcc_runtime + libc +
shims + libc_c + libfgx + args` ~= 44,000 lines of assembly — re-assembled by
Merlin32 **544 times per gate**. ~23 million lines of asm per run, producing a
`.bin` that (since the binary goldens were retired 2026-07-28) **nothing
compares against**. fcc's real golden is the `.expected.s` textual diff, which
costs 0.06 s.

**99.8% of the fcc fixture gate is assembling the OS's libc.**

### 3. build.sh's dependency tracking is hand-rolled and demonstrably wrong

```
build.sh + lib/build_common.sh ....... 2,056 lines
hand-rolled staleness sites ..........    18
  deps_of()              :326   hand-written PUT-closure scanner
  _elvis_stale()         :346
  _bsh_stale()           :387
  _tcsh_stale()          :434   three near-copies of one idea
  _assert_staged_fresh() :616
```

Every entry in the recent failure ledger is a dependency bug:

- **The STALE BINARY guard lied (2026-07-28).** It correctly detected
  `tcsh.bin` was stale and said "DELETE it and re-run (build.sh relinks it)" —
  but nothing rebuilt it; build.sh only `cp`'d it. The disk shipped with no
  `/bin/tcsh` and still reported `{"status":"ok"}`. In a real graph this cannot
  happen: staleness and the rebuild rule are the same edge.
- **libc pile traps.** `make libc_c` separately required; bsh/elvis staleness
  ignored the pile's *data* segment. Missing edges.
- **`_assert_staged_fresh` uses `ls -t ... | head -1`** — the same construct
  that silently returned empty under an `eza` alias, making the check vacuous.

Three copies of `_*_stale()` exist because there is no graph in which to say it
once.

### 4. release.sh re-gates an already-green tree

The release commit differs from the gated feature commit only by `CHANGELOG.md`
and the submodule pin.

### 5. The gate was ~85% idling (FIXED 2026-07-28)

Everything above was diagnosed before anyone timed the gate. Timing it moved the
whole analysis.

The MAME harness passed `-video none -sound none` under a comment claiming *"CPU
emulation runs at full speed"*. It did not: **MAME throttles to real time by
default**, and disabling rendering/audio does not change that. So
`-autoboot_delay 12` cost 12 WALL seconds of idling per test, 61 times per gate.

Adding `-nothrottle` for non-net tests (commit `2824f1c0`):

```
                    before     after
failsafe (15)        645s        50s    12.9x   15/15 pass
fast     (22)        825s        68s    12.1x   22/22 pass
uthernet2 (24)     1,141s     1,141s     1.0x   correctly excluded
FGX release gate   34.2 min   21.6 min
```

Safe because `autoboot_delay` counts EMULATED frames (12 x 60 = 720): the guest
still sees 720 frames, so guest-visible timing is bit-identical. The uthernet2
gates are excluded because guest timeouts are *also* in emulated time, and they
wait on real DHCP/TCP/DNS peers answering on a wall clock — a 12x-faster guest
would time out before the reply arrived.

**This was the single largest win of the whole analysis, and it was invisible
until something was measured rather than reasoned about.** It is also the fourth
build-system claim today that read as true and was false — see the pattern in
Decision 2.

## Measured baseline (2026-07-28)

Everything below is measured on this Mac, `--fresh --no-state` (no cache
assistance), unless marked *projected*.

```
cleanroom (clone -> toolchain -> 136 binaries -> disk)      66s
build.sh disk (incremental, working tree)                   86s
fcc compile, 20 M11 fixtures                              0.06s
fcc fixture gate, same 20 (99.8% assembling libc)         28.0s

MAME per test, non-net, unthrottled                        ~3.1s
MAME per test, net, throttled                              ~48s

FGX release gate (build + fast + uthernet2)              21.6 min
full suite, 317 tracked manifests                    ~34 min *projected*
```

Suite composition, and how much of it can share a MAME session:

```
batchable (plain command + screen checks)   215 / 317   (68%)
needs its own boot                          102
   stage_files 32   memory_regions 23   mame_slots 23
   raw_inject  19   watch_min      10   stack_excursion 8
   fresh_nvram  3   png_snapshot    3   capture_writes 2
```

**The net group is now 88% of the release gate and 56% of a full run.** All 24
share `mame_slots: ["-sl1","uthernet2"]` — identical MAME config — so they are
the highest-value batching target: one boot, one `dhclient`, one observed lease,
then all 24 checks. Projected 1,141s -> ~150s, release gate -> ~5 min.

## Decision 1 — monorepo, BSD layout

### Why not "detangle in place"

The 2026-07-16 decision (toolchain keeps fcc/fas/fgx_ld + its own runtime; OS
libraries move to FGX) was recorded and never executed. Its directional intent
is right; its two-repo mechanism does not solve the problem, for two reasons.

**a) The standalone-compiler premise is false.** It was the original reason for
the split. Measured:

| | FGX coupling | standalone? |
|---|---|---|
| `fas` | 14x `__FGX__` (a predefined macro) | **yes** — a Merlin-compatible 65816 assembler, proven by byte-eq goldens vs Merlin32 |
| `fcc` | `FGX2_LONG_PTR` x17, `FGX2_FARCALL` x7, `FGX2_EXPORT` x7, `FGX2_RELOC_COUNT`, `FGX_ABI_CURRENT`, `FGX_MODE_CURRENT`; shells to `fgx_ld` | **no** — the multi-bank far-pointer model *is* the FGX2 ABI |
| `fgx_ld.py` | 122 refs | no, by construction |

The identifier count understates it: the macros fcc emits are defined in FGX's
`macros.s`, the `_fcc_*` helpers it calls are FGX's `crt`, and the goldens
pinning it are FGX2 two-segment fixtures. There is no general 65816 C compiler
here that happens to target FGX.

Nothing else consumes `apple/fcc` (0 forks).

**b) A perfect detangle still does not fix the worst case.** Change the calling
convention and you touch fcc's emitter *and* the `crt` code implementing it —
inherently one atomic change. Two repos force that through release-then-pin
wherever the line is drawn. That is exactly the class of change that has been
costing days. Monorepo makes it one commit, and bisectable, which it is not
today across the pin.

### Where the line actually goes — 2.11BSD is authoritative

The vendored tree settles it:

```
usr/lib/pcc/        code.c local.c local2.c table.c order.c macdefs.h
                    -> NO .s files at all

usr/lib/libc/pdp/   ALL= crt gen net stdio sys
      crt/          csv.s ldiv.s lmul.s lrem.s aldiv.s almul.s alrem.s
                    udiv.s uldiv.s ulrem.s ulsh.s ultof.s
      csu/          crt0.s mcount.s
```

`csv.s` — *"C register save and restore routines. When a C routine is called
its stack frame (after csv or ovhandlr have set things up)…"* — is the calling
convention **implementation**, and it lives in libc. pcc emits `jsr pc,csv` and
`jsr pc,ldiv`; libc supplies both. The compiler ships nothing linkable.

**BSD's rule: the compiler owns the ABI as a specification; libc owns the code
implementing it.**

`lib/fcc_runtime.s` is `_fcc_divs16, _fcc_long_divu, _fcc_long_add,
_fcc_long_divs, _fcc_fadd, _fcc_itof, _fcc_ftol, _fcc_ulsh…` — that is
`crt/ldiv.s + lmul.s + lrem.s + ultof.s`, function for function.
`crt0.s`/`crt0_far.s` is `csu/crt0.s`. Both belong with libc.

`lib/macros.s` is FGX's, unambiguously — header: *"FGX - Flux GS uniX / Common
macros for FGX development"*; defines `_SYSCALL`, `_SYSRET`, `_TOOL`,
`_SETSCB`, `_ZeroBankRegion` and the whole `FGX2_*` family. And
`toolchain/lib/macros.s` is a **subset** of `include/macros.s` (FGX's has
`_BANKK`, `_DBRK`, `KHEAP_USE`, `U2_LOCK/UNLOCK` extra) — the same drift hazard
the A2 unification killed for libc, still live. The two collapse into one.

Note BSD is itself a monorepo containing pcc, libc, kernel and userland.
Separation there is **directory + build order**, not repo. That is what we
adopt.

### Target layout

```
tools/fcc/            compiler (was toolchain/src/cc)
tools/fas/            assembler (was toolchain/src/as)
tools/ld/             fgx_ld.py
lib/libc/gs/csu/      crt0.s, crt0_far.s
lib/libc/gs/crt/      fcc_runtime.s, fcc_runtime_data.s
lib/libc/             libc_c/, libfgx_c/, libcurses_c/, libtermlib_c/,
                      libc_net_c/, libc.s, fcc_libc_shims.s, args.s
include/              macros.s (single copy), libc headers
src/kernel/ …         unchanged
tests/fcc/            M* fixtures + .expected.s goldens
tests/as/             Merlin32 byte-eq goldens
```

Merge via subtree so both histories survive; archive `apple/fcc` read-only.

### Consequence for fcc's fixture gate

With crt0 and the runtime gone too, fcc has nothing to link fixtures against —
so dropping the link step stops being a tradeoff and becomes the only coherent
option. fcc's gate becomes compile + golden diff (~2 s). Link and runtime sweep
move to the OS build, which owns the runtime and the MAME harness.

This is exactly BSD: pcc's correctness is its *output*; the system build is what
links and runs it.

**Accepted cost:** fcc alone no longer catches "emitted asm Merlin32 won't
take." The OS build catches it (it assembles ~100 userland tools), and in a
monorepo that is the same pipeline, so the gap is a scheduling detail rather
than a repo boundary. Explicitly *not* verified: whether the fixture corpus
exercises constructs no userland tool does. If it does, the answer is a smoke
subset in the OS build, not a runtime in the compiler.

## Decision 2 — Ninja, generated from Python; build.sh deleted

Not wrapped. A compatibility shim over a 1,240-line script with three copies of
`_*_stale()` guarantees both exist forever, and there is exactly one user.

**Ninja over CMake.** CMake's value is cross-platform builds, `find_package`,
IDE integration, and toolchain files for *known* compilers — none apply to a
custom 65816 cross-toolchain. It would be `add_custom_command` throughout, i.e.
writing ninja by hand through a translation layer.

Ninja fits because the project already generates build inputs in Python
(`fgx_ld.py`, `gen_seg1_layout.py`, `gen_tcsh_link.py`, `gen_commons.py`); the
generator reuses that logic rather than duplicating it.

**The payoff is the gate.** `ninja -n` / `ninja -t deps` *answers* "what does
this change affect". Change-scoping stops being hand-coded — which is the thing
that turns a day into minutes.

### Prerequisite — fcc cannot report dependencies

```
usage: fcc <input.c> [-o <output.s>] [-I dir]... [-Dname[=value]]... [-include <file>]...
```

No `-M`/`-MD`/`-MF`. Point ninja at that and you get a build confidently correct
about what it knows and blind to every header edge — the current bug class,
harder to see.

Fix in the toolchain (per the standing rule, not around it): fcc already
resolves `-I` and `-include`, so it knows every file it opened; it just never
writes them down. Small and additive. The assembler side needs the same for PUT
closures — either `fas -M` or generator-side scanning (the logic exists as
`deps_of`).

## Decision 3 — CI: Mac primary, Linux clean-room only

Ample's MAME cannot run headless on Linux — `-debug` opens a GUI window even
with `-video none` (recorded 2026-06-29) — and the uthernet2 group needs vmnet,
which is macOS-only. The available Linux container is also far slower than the
Mac. So Linux MAME is ruled out, not attempted.

The real gate stays on the Mac. The win is not hardware — it is that the gate
becomes **asynchronous**: push and keep working, instead of watching a terminal
for hours. Same silicon, different blocking behavior.

**A self-hosted GitLab runner is NOT the mechanism.** See "Rejected: Mac as a
GitLab runner" below — it was considered, and rejected on trust grounds.

### Chosen mechanism — a spawned job, no external trigger

**Not a daemon.** Nothing needs to be resident. The existing `pre-push` hook
(already wired via `core.hooksPath=tools/hooks`) spawns a **detached background
job** and returns; `git push` completes immediately. The job runs the
ninja-scoped gate, posts its result, and exits.

**The verdict is a LOCAL artifact.** The gate writes a receipt keyed by commit
SHA + tree hash (`.gate/<sha>.json`, gitignored), and `release.sh` reads *that*.
No network, no upstream service, no GitLab.

Posting to the GitLab **Commit Status API**
(`POST /projects/:id/statuses/:sha`) is an **optional mirror** — it makes the MR
show green for the other maintainers, over the same outbound channel `glab`
already uses. A failed post does not mean a failed gate, and a missing GitLab
does not block a release. See "Invariant — GitLab is never a dependency of
correctness" below.

The only thing a resident process would add is serialization across two rapid
pushes, which is a `flock` on the gate script. No launchd plist, no lifecycle,
no "is it running?" failure mode.

One ordering detail: `pre-push` fires *before* the push lands, so the job must
not post a status for a SHA the server has not seen yet — wait for the push to
complete, or retry the post once.

The MR shows green/red exactly as a runner would produce, so Decision 4
(release = "is the pipeline green on this SHA?") works unchanged.

Properties:

- **No external trigger exists.** Nothing on the internet can cause execution on
  the Mac. It runs only code already in the working tree.
- No runner token, no registration, no inbound anything, and no
  CI-config-controls-execution problem.
- Simpler: no executor config, no job YAML for the Mac half.

**Accepted limitation:** it gates the maintainer's commits only. A branch pushed by
another maintainer gets no MAME gate. That is already true today — they cannot
run MAME either — and the Linux clean-room build still catches build breaks for
everyone. Extending the gate to their branches would be a deliberate decision to
extend trust, not a default.

### Rejected: Mac as a GitLab runner

Considered first, and it clears the obvious objection but not the real one.

**NAT is not the blocker.** GitLab runners never accept inbound connections: the
runner authenticates with a registration token and long-polls
`GET /api/v4/jobs/request` outbound, pulling work down. GitLab stores no address
to dial. Verified 2026-07-28 — `glab api version` from this Mac returns GitLab
19.1.1, and the existing runner reports `ip_address: None`, because GitLab never
originates a connection. Only the interactive web terminal needs inbound, and it
is off by default.

**Trust is the blocker.** apple/fgx is private with zero forks, so it is not
open to the world — but it has four members (`jayjayc`, `jsanford`,
`The maintainer` at Maintainer, `the maintainer` at Owner). **CI config lives in the repo**, so
anyone who can push a branch can change what CI executes. A Mac runner would
therefore let three other people run arbitrary code as the maintainer on his personal
machine. "Can read the repo" and "can execute as me on my hardware" are
different consent levels; the second is not implied by the first.

GitLab's mitigation is a **protected runner** (executes only on protected
branches — `main` is, feature branches are not), but that inverts the goal: the
gate is wanted *before* merge, so it would never fire when it matters.

Rejected on that basis. A spawned local job gets the same asynchrony with no
external attack surface, and is the smaller change.

### Operational notes — the Mac gate is not hermetic

The gate runs in the maintainer's own environment: MAME needs the real machine, vmnet is
macOS-only, merlin32 is locally licensed. Nothing about it is sandboxed, and
that is unavoidable.

So **the Mac gate proves "it works here", not "it works from a clean
checkout"** — which is precisely why the Linux clean-room build is load-bearing
rather than vestigial. It is the only check that the tree builds without local
state, catching the uncommitted-file and works-on-my-machine classes. Keep it,
plus artifact publishing.

Two things to plan for:

- **Sleep or a closed lid defers the gate.** A spawned job that never ran leaves
  the commit status absent rather than red. Distinguish "no status" from "failed" in
  whatever reads it, so a sleeping laptop never reads as a green release.
- **Contention** with interactive work: one gate at a time, `nice`, and ninja
  scoping keeping most pushes to a small subset.

### Invariant — GitLab is never a dependency of correctness

**The OS must be buildable and gateable with no upstream GitLab instance.**
Every build and gate step is a local script that works offline; GitLab is where
results are *mirrored* and artifacts are *published*, never where correctness
lives.

Audited 2026-07-28:

| | today | after |
|---|---|---|
| build | `build.sh` makes no network calls | unchanged — `configure.py` + `ninja`, offline |
| **clone** | **needs two repos** — submodule url `../fcc.git` | **one self-contained clone** (monorepo removes it) |
| gate | local (manual, but local) | local receipt; GitLab post optional |
| clean-room | GitLab-CI-only capability | `tools/cleanroom.sh`, runnable locally; CI merely calls it |
| distribution | Package Registry + Releases | unchanged — legitimately GitLab-coupled |

Note the monorepo *improves* this: today FGX cannot be built from a single clone
without network access to a second GitLab repo.

**Distribution is the one legitimate coupling.** Package Registry uploads and
GitLab Releases are publishing, not building. Without GitLab you cannot publish
there; the images still build. That is the correct boundary.

MR / protected-branch discipline is inherently server-side process, but it does
not affect buildability — a clone builds and gates identically without it.

### Tiers — mapped onto the standing 2026-07-22 cadence ruling

Not a new policy; the existing one, automated.

| trigger | runs | where |
|---|---|---|
| every push | build + fcc fixtures + farcalls + `as` goldens + **failsafe** MAME group (~11 tests) | Mac (spawned job) |
| release / tag | full gate — fast group + uthernet2 | Mac (spawned job) |
| full suite | explicit request only | Mac (spawned job) |
| every push (any author) | `tools/cleanroom.sh` + artifact publish | Linux CI |

Net tests stay serial (shared vmnet MAC); the rest parallelize.

## Decision 4 — "release" is the wrong word: cheap MRs + verified tags

The maintainer, 2026-07-28: *"the 'release' is probably a misnomer... we need to move
towards push early, push often with minimal gates until we lay down a 'release
tag' that runs the full suite."*

The downstream-rebase pain is a **cadence** problem, not a gate problem. Tags are
rare because each one costs a day; make tagging cheap and it happens weekly
instead of per-campaign, and nobody rebases across thousands of lines.

Two tiers:

| tier | runs | cost | ceremony |
|---|---|---|---|
| **every push** | build + *affected* tests, spawned in background, posts commit status | target < 5 min | none |
| **verified tag** | full suite + changelog + tag + publish | ~5-10 min once net batches | the only ceremony |

`main` stays green-ish and continuously pushable; a tag is a **quality signal**
("full suite passed here"), not an event.

**MRs stay, but get cheap** (the maintainer's call, 2026-07-28, over relaxing branch
protection). Both mains are protected with four maintainers, so the review point
is kept: one MR per change, scoped gate, merge as soon as green. This preserves
the standing never-self-merge rule rather than superseding it. What goes away is
the *second* MR — no separate release MR, no re-gate of an already-green tree.

### Test selection: speed FIRST, scoping second

Dependency-driven selection is right, but it will not help the dominant change
class, and sequencing it first would be a mistake:

| change | affected | scopable? |
|---|---|---|
| one userland tool | its own tests | **yes — big win** |
| **libc** | every binary links it | **no — full suite, correctly** |
| **kernel** | under every test | **no — full suite, correctly** |
| docs / spec | none | yes |

libc and kernel changes are the bulk of the work **today** and both legitimately
invalidate everything. So when the selector correctly says "run everything", that
must cost ~5 minutes, not 34.

**This balance is temporary and will invert.** The maintainer, 2026-07-28: *"the libc and
kernel changes will level out over the long run, they're just prominent now
because it's early development."* That is right, and it means selection is not a
permanent second-class item — as the kernel and libc stabilise, tool-level
changes come to dominate and the selector starts earning on most commits. Build
it properly, not as a bolt-on.

The sequencing still holds, for a narrower reason than "speed matters more":

- speed work is **cheap and independent** — `-nothrottle` was a two-line change
  that beat every structural item in this document by 12x, with no prerequisite;
- selection **depends on the ninja graph**, so it cannot come first anyway;
- the failure modes are asymmetric: a wrong "skip" is a missed regression, a
  wrong "run" is merely slow. Selection wants the suite already fast underneath
  it, so that erring toward "run" stays cheap.

When selection is built, derive deps from what manifests already carry —
`command` names its binary (`/bin/ping ...`), plus `stage_files` — and treat
kernel/libc as global invalidators. Do **not** add a `deps:` field to 317
manifests; it would rot exactly like the hand-written staleness sets in
`build.sh`.

## Decision 4a — release mechanics

With CI green on the SHA, the release gate is an API query, not hours. One MR
per change; no separate release MR; no re-gate. `--pin-toolchain` disappears
with the submodule.

## Phasing

Each phase independently shippable. **Reordered 2026-07-28 after measuring:**
gate-speed work moved to the front. It is cheap, independent of the structural
changes, and delivered the largest single win before any of them started.

0. **Gate speed** (partly DONE).
   - `-nothrottle` for non-net tests — **DONE**, commit `2824f1c0`, 12x.
   - Test-image `/etc/rc` without netstart; net tests do explicit
     `dhclient` -> observe lease -> `ping` — **in progress**.
   - **Batch the net group into one MAME session** — the big remaining win
     (88% of the gate, all 24 share one MAME config).
   - Then batch/parallelise the 215 shareable non-net tests
     (`run_runtime.py` already has both: one-boot-per-chunk, and `--jobs`).
   - Lower `FGX_MAME_BOOT_S` from 12: measured floor is 8 (passes at 8, fails
     at 6). Use 10, not 8 — a flaky boot race is a far worse trade than 48s.

1. **fcc `-MD/-MF`** (+ `fas -M` or generator-side PUT scan). Small, additive,
   unblocks everything. The only phase that endures the current process.
2. **Monorepo merge + BSD layout.** Subtree merge preserving both histories;
   `macros.s` de-duplicated; fcc fixture link dropped.
3. **Ninja generator**; `build.sh` and `lib/build_common.sh` deleted.
4. **Gate + release.** Pre-push hook spawning the gate job; local receipt as
   the verdict, GitLab commit status as an optional mirror; `tools/cleanroom.sh`
   extracted so the clean-room check runs offline too; tiers above;
   Linux CI reduced to calling `tools/cleanroom.sh` + publishing;
   `release.sh` reduced to changelog + tag against a green *local* receipt.

Monorepo before ninja so the build graph is written once against the final
layout. Tradeoff: the largest irreversible step lands before any build-system
payoff. Reversible ordering if the ninja win is wanted sooner, at the cost of
rewriting parts of the graph.

## Open / unmeasured

- **`build.sh disk` and MAME group wall times are still unmeasured.** The
  structural diagnosis does not depend on them (whatever they cost is paid 4-8x
  by hand today), but phase 4's scoping should target the real cost, so measure
  before finalizing tiers.
- Whether the fcc fixture corpus exercises constructs no userland tool does
  (decides whether a smoke-link subset is needed in the OS build).
- Whether `fas` should be extracted to its own repo later — it is the one
  genuinely standalone component, and it is one directory.
- MAME parallelism limits on the Mac runner beyond the net-test serialization.


---

# Outcome (2026-07-28)

All five phases landed in one session.  What actually shipped, and what the
plan got wrong.

## Delivered

| phase | result |
|---|---|
| 0 gate speed | `-nothrottle` for non-net tests: **12x**.  Release gate 34.2 -> 21.6 min |
| 1 fcc `-MD/-MF` | plus `fas -MD`; verified against real ninja 1.13.2 |
| 2 monorepo | 1094 fcc commits merged at `toolchain/`, path history intact |
| 3 ninja | 130 tools + kernel + shells + staging + 3 images; **build.sh DELETED** (1268 lines) |
| 4 gate | scoped selection, local receipts, cleanroom, release reads the receipt |

Verification at every step was byte-identity against build.sh: **131/131
binaries**, all three disk catalogs, shells byte-identical, MAME failsafe 15/15.

Gate cost now:

```
ping.c change      scoped gate GREEN in 83s   (was a 34-minute full gate)
clean tree         0 tests selected
libc pile          306/318      kernel  318/318
```

## What the plan got wrong

**Phase ordering.** The plan put `fcc -MD/-MF` first, "shipping under the
current process" -- one last toolchain release + re-pin.  Merging the monorepo
FIRST made that phase an ordinary commit and deleted the ceremony entirely.
Sequence the irreversible structural move before the work that would otherwise
have to endure the old process.

**Speed vs selection.** The plan asserted "making the suite fast is worth more
than making it selective".  Measured, that is only true *today*: libc touches
306/318 tests and the kernel 318/318.  The maintainer's correction stands -- as those
stabilise, tool-level changes dominate and selection earns on most commits.

**dyndep.** The plan assumed the seg3 archive dead-strip needed it.  It did not:
the output filenames are deterministic and only the contents are discovered.

## The one recurring bug class

A build system that WRITES ITS OWN INPUTS invalidates itself, and it always
presents as "the graph is being conservative" rather than as a defect.  Three
instances:

1. the shells' generated `seg*.link.s` -- "no change" rebuilt all three forever
2. the disk image's generated `/etc/rc` -- perpetual rebuild
3. `gen.py` rewriting `seg*.link.s` + manifests on every run -- which defeated
   test selection silently, reporting a 1-test change as 302

`write_if_changed()` is the helper; any future generated input routes through
it.

## The other recurring failure: a check that did not run looks like a check that passed

Counted this session: an `ls -t` vacuous under a shell alias; a group-name parse
that reported all 15 failsafe tests missing; a ninja test that "passed" because
ninja was not installed; a reference disk image copied mid-write; two more named
`.ref`/`.ref2`, which cadius reads by EXTENSION and so rejected entirely.  Every
one produced the answer being hoped for.

And the worst: a **false byte-identical**.  Ninja wrote a data segment to the
repo root while the edge declared it under `tools/<name>-fgx2/`, so the link
silently consumed build.sh's stale 1373-byte leftover instead of the correct
1367-byte output -- and produced a matching binary anyway.  Verifying a build
system against a tree full of the previous system's outputs proves nothing.
Every coverage claim here was re-run after wiping all prior artifacts.

## Not done

- `feat/monorepo` is UNPUSHED (1118 commits) -- needs review before an MR
- `apple/fcc` still needs archiving read-only (the maintainer, the CI host-side).  Do it AFTER
  the merge lands: the old SHAs live only there now, since filter-repo rewrote
  all 1094
- multi-TU is exercised only by `robots`; `lib/build_common.sh` survives because
  `make_disk.sh` and `make_floppy.sh` still source it
