#!/usr/bin/env python3
"""
fcc runtime-correctness sweep — run each fcc fixture binary on FGX/MAME
and verify its exit code.  Replaces the byte-eq-vs-Merlin oracle
(`tools/fas/tests/run.sh` — 0/175 because fas's DP-fold policy differs
from Merlin by design) with a behavioral correctness check.

Modes
-----
  --calibrate          run every Merlin-built fixture and write the
                       observed exit codes to oracle.json.  The oracle
                       file becomes the source of truth for the
                       --use-fas-bin comparison.

  (default)            run Merlin-built fixtures.  Pass iff exit code
                       matches oracle.json (or "any-exit" if calibration
                       hasn't been done).

  --use-fas-bin        RETIRED at P3-2.6: the fixture wrappers are now
                       fgx_static links (fixture_link.py), which fas cannot
                       drive as a single assembly.  fas-on-FGX validation
                       lives in the fas_fgx build (build.sh) instead.

Disk shape -- and why this is CHANGE-SCOPED by default
------------------------------------------------------
This script builds a ~32MB hard-drive image at disk/fcc_runtime.po
(via `DISK_SIZE_OVERRIDE=32767KB DISK_IMAGE_OVERRIDE=... make_disk.sh
--skip-kernel`) and tells the mame_test runner to boot from it via
the `disk_image` manifest field.

The volume no longer binds: every fixture links against the shared
fgx_static image (fixture_link.py), so the whole suite is a few MB on a
32 MiB UFS disk (710 fixture binaries, 7,745,582 bytes total, mean 10,909,
largest 90,812 -- measured from the .expected.bin files).  The cap below
stays regardless, because the reason for it is diagnostic, not capacity: a
change-scoped run boots only what the change touched (2026-08-01),
and `--all` is the full run.

So the default is the set a change actually touched: fixtures whose .c or
goldens differ from the merge base with main.  A codegen change surfaces as
a golden diff (tests/run.sh fails until the goldens are regenerated), so
"the goldens that moved" is exactly "the fixtures whose emitted code
changed".  That is typically a handful and one boot.  `--names` overrides;
`--all` runs the whole suite.

One case golden-diff scoping is blind to, and it is handled explicitly: a
change under toolchain/lib/ alters EVERY fixture binary and NO golden.  That
triggers a capped run with a printed warning naming how many fixtures are
NOT covered, because reporting a clean scoped run over a pile change would
be a false green over all 546.

Speed
-----
The cost is the MAME COLD BOOT (~25s incl. the 32MB disk copy), not the
fixtures.  **Chunked mode is the default**: one boot per chunk, running a script of N
fixtures that echoes `=<disk> $?` markers, invoked as `sh <script>`.  NOT
`.`-sourced -- dot-sourcing dies partway through a script (issue #9), which
silently capped every run at 8 fixtures and scored the rest as regressions.
VERIFIED RUNNABLE 2026-08-04 (apple/fgx#7).  The three blockers that made this
un-runnable after the monorepo migration are fixed in main: the rebuild helper
runs `ninja disk` (build.sh is gone), `tools/ninja/gen.py` excludes the harness's
`disk_src/tests` scratch from the image dependency graph, and the ProDOS
ceiling is handled by scoping a run to the fixtures a change actually touched
rather than by the `DISK_PASSES` mechanism that never existed.  Measured: a
6-fixture `--names` run is 6/6 in 14 s.

`--batch` (2 fixtures/boot) remains as a fallback.  Each run ALSO does `./build.sh disk` internally (stages userland +
the do_source `$?` keystone).  NOTE the staging entry point is now
`ninja disk`; build.sh was deleted by the monorepo migration.

Validation cadence (fcc codegen work) — least → most expensive.  Run only the
gates a change actually affects (2026-08-01); the ~310-test MAME suite
this cadence was written against was deleted on 2026-07-30.
  1. inner loop (seconds, host-only): `make -C toolchain` + `bash tests/run.sh`
     (goldens) + `FCC_NO_REGALLOC=1` byte-identity on affected fixtures.
  2. targeted correctness (~1 boot): plain `run_runtime.py` — the default is
     now change-scoped, so this IS the everyday command.  `--names a,b,c`
     when you want an explicit set.
  3. bank-emission codegen: `tests/multibank/run_multibank.py` (one boot, one
     small binary).  This is the far-pointer semantics oracle and it is NOT in
     the release gate — run it whenever bank emission or the libc pile moves.
     A pile change also silently grew seg0 past its ceiling once (issue #7).
  4. milestone only (batch several increments): `fbench compare` (perf
     MEASUREMENT, not a correctness gate) + the adversarial Workflow review.
Don't run step 4 per increment — that is what was costing hours.  There is no
longer a "full sweep" step: it does not fit a ProDOS volume (see Disk shape).
"""

import argparse, json, os, re, shutil, subprocess, sys, time
from pathlib import Path
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed

# --- Path wiring, re-anchored after the toolchain was extracted into its own
# --- repo by b6881ae.  Two distinct roots:
#   TOOLCHAIN_ROOT — this repo: fcc fixtures (M*/) + oracle.json live here.
#   FGX_REPO       — the FGX checkout providing the kernel, disk tooling, and
#                    MAME runner.  The sweep can ONLY run from inside FGX, where
#                    this repo mounts as the `toolchain/` submodule; a standalone
#                    checkout has no kernel to boot.
TOOLCHAIN_ROOT = Path(__file__).resolve().parents[1]


def _resolve_fgx_repo():
    """Locate the FGX checkout (kernel + disk + MAME runner).  Override with
    FGX_ROOT; default assumes this repo is FGX's `toolchain/` submodule, i.e.
    FGX root == TOOLCHAIN_ROOT.parent."""
    env = os.environ.get("FGX_ROOT")
    cand = Path(env).resolve() if env else TOOLCHAIN_ROOT.parent
    if not (cand / "tools" / "mame_test" / "run.py").exists():
        sys.exit(
            "runtime sweep needs the FGX tree (kernel + disk + MAME runner).\n"
            f"  looked in: {cand}\n"
            "  set FGX_ROOT=/path/to/fgx, or run from FGX's toolchain/ submodule.")
    return cand


FGX_REPO = _resolve_fgx_repo()
REPO = FGX_REPO                       # FGX-side paths below (build.sh, disk, fas) stay REPO-relative
FCC_TESTS = TOOLCHAIN_ROOT / "tests"
FAS_BIN = FGX_REPO / "tools" / "fas" / "fas"
DISK_SRC_FCC = FGX_REPO / "disk_src" / "tests" / "fcc"
RUN_PY = FGX_REPO / "tools" / "mame_test" / "run.py"
MAME_TESTS = FGX_REPO / "tools" / "mame_test" / "tests"
ORACLE_PATH = FCC_TESTS / "oracle.json"

BIG_DISK_REL = "disk/fcc_runtime.po"
# 32767KB -> 33553408 bytes = 65534 blocks, NOT "32MB".
#
# cadius turns 32MB into 33554432 bytes = 65536 blocks, which is ONE BLOCK OVER
# the ProDOS/SmartPort 16-bit maximum, so the volume's block count wraps to
# zero (apple/fgx#80).  That fix reached make_disk.sh's default and the boot
# image but not this override, and the mismatch stayed invisible because the
# runtime oracle only runs when fcc's SOURCE changes -- a check that does not
# run cannot report the thing it would have caught.  It surfaced as
# "Disk image wrong size: 33554432 (expected 33553408)" the first time the
# oracle ran after the fix landed.
# 64 MB of 1 KB filesystem blocks.  The fixtures are ~28 MB and the staged
# tree another ~13 MB, and a 2.11BSD volume has no ProDOS ceiling to fit
# them under -- so nothing is trimmed.  Override with FCC_RUNTIME_BLOCKS.
BIG_DISK_BLOCKS = 65536

BATCH_SIZE = 2              # fixtures per MAME boot — paste-rate budget.
                            # Was 4; dropped to 2 because some batches
                            # were hitting timeout and producing "no marker"
                            # results (false failures).  At BATCH=2 the
                            # full sweep is slower but cleaner.
DISK_NAME_MAX = 8           # short generated names, see short_disk_name
PASTE_CHARS_PER_SEC = 4     # MAME natural-keyboard pacing (conservative)
BOOT_OVERHEAD_S = 25        # autoboot_delay + sweep disk copy + boot
PER_FIX_S = 6               # per-fixture execution+typing budget

# Fixtures per chunk (one MAME boot).  Bounded by the per-chunk timeout
# (BOOT_OVERHEAD_S + PER_FIX_S*n + 5 must stay under run_chunked's 300s
# subprocess cap, so n <= 45), NOT by anything about the shell.
#
# It used to be bounded by the shell, and badly.  The chunk script was `.`
# -sourced, and dot-sourcing DIES PARTWAY THROUGH (issue #9): 17 spawns for a
# script of plain `echo`s, far fewer when builtins are mixed in, leaving a
# garbled line and no sentinel.  Every fixture past that scored `no-marker`,
# which the harness reported as a REGRESSION -- so the default of 24 was
# silently failing two thirds of every run.
#
# Running the script with `sh <file>` instead of `. <file>` sidesteps it
# entirely: a child shell reads the identical script and completes 48/48
# fixtures in one boot, where dot-sourcing stopped at 8.  That is also what
# localises #9 to the dot path rather than to spawning.
CHUNK_DEFAULT = 40


def short_disk_name(fixture_name, seen):
    """A short alphanumeric name, first char alpha.  Collisions resolved by
    appending a digit.

    LOWER CASE, AND THAT IS NOT COSMETIC.  It was upper because ProDOS stores
    names that way and compares case-INSENSITIVELY, so `/tests/fcc/wlong'
    reached `/TESTS/FCC/WLONG' and nobody had to think about it.  A 2.11BSD
    root is case-SENSITIVE: the same command finds nothing.  Every batch
    manifest and every probe in this tree already spells the path lower
    (`run_multibank.py', `probes/mbdiag.json', `probes/p326_bisect.json'), so
    lower is what the volume must carry.  apple/fgx#342.

    The eight-character cap stays.  2.11BSD allows fourteen -- this tree raised
    MAXNAMLEN to 63 at apple/fgx#317 -- so it is no longer a limit, but the
    names are generated and short ones keep a chunk script inside the line
    length the paste can carry."""
    s = re.sub(r'[^A-Za-z0-9]', '', fixture_name).lower()
    if not s or not s[0].isalpha():
        s = "F" + s
    s = s[:DISK_NAME_MAX]
    base = s
    i = 1
    while s in seen:
        s = base[:DISK_NAME_MAX - 1] + str(i)
        i += 1
    seen.add(s)
    return s


# The 32 MB volume no longer caps this: every fixture links against the
# shared fgx_static image, so the whole suite (710 binaries, 7,745,582 bytes
# total, mean 10,909, largest 90,812 -- measured from the .expected.bin
# files) is a few MB.  The cap stays anyway: a change-scoped run is meant to
# boot only what the change touched, and `--all` is the full run.
MAX_FIXTURES_PER_DISK = 240

# Sources that change EVERY fixture binary without changing a single golden:
# the libraries every fixture links and the link itself.  Golden-diff
# scoping is blind to these by construction, so they get their own trigger.
BROAD_INPUT_PREFIXES = ("toolchain/lib/", "toolchain/src/ld/",
                        "toolchain/tests/fixture_link.py")


def _git_changed_paths():
    """Paths differing from the merge base with main, plus the working tree.

    Returns None (not an empty set) when git cannot answer, so callers can
    tell "nothing changed" apart from "I could not tell" -- the difference
    between running nothing and silently skipping the gate."""
    def _git(*a):
        r = subprocess.run(["git", *a], cwd=REPO, capture_output=True, text=True)
        return r.stdout if r.returncode == 0 else None

    base = _git("merge-base", "HEAD", "main")
    if base is None:
        return None
    base = base.strip()
    changed = set()
    for args in (("diff", "--name-only", f"{base}...HEAD"),
                 ("diff", "--name-only"),               # unstaged
                 ("diff", "--name-only", "--cached"),   # staged
                 # UNTRACKED, WHICH NO `git diff` FORM LISTS.  A brand-new
                 # fixture is invisible to all three above until it is
                 # committed -- so the change-scoped oracle skipped it during
                 # exactly the session that added it, reported a clean run, and
                 # the author committed a fixture that had never been executed.
                 # Found while adding M37/structassign.c at UFS 1.13a.
                 ("ls-files", "--others", "--exclude-standard")):
        out = _git(*args)
        if out is None:
            return None
        changed.update(l.strip() for l in out.splitlines() if l.strip())
    return changed


def _spread_sample(fixtures, k):
    """Evenly-strided sample, so a capped run spans every M-dir.

    A prefix would take M0..M11 whole and cover NOTHING after it, which is the
    worst shape for a sample meant to stand in for the suite -- the later dirs
    hold the pointer/struct/fn-ptr constructs most likely to break."""
    if k >= len(fixtures):
        return list(fixtures)
    by_dir = {}
    for f in fixtures:
        by_dir.setdefault(f["c"].parent.name, []).append(f)
    # Round-robin across dirs so EVERY dir contributes before any contributes
    # twice; a plain stride silently drops the small dirs entirely.
    picked, cursor = [], 0
    order = list(by_dir)
    while len(picked) < k:
        progressed = False
        for d in order:
            if cursor < len(by_dir[d]):
                picked.append(by_dir[d][cursor])
                progressed = True
                if len(picked) == k:
                    break
        if not progressed:
            break
        cursor += 1
    return sorted(picked, key=lambda f: fixtures.index(f))


def select_changed(fixtures):
    """Fixtures whose own source or emitted assembly changed vs the merge base.

    A codegen change shows up as a golden diff: tests/run.sh fails until the
    goldens are regenerated, and regenerating them is what puts those fixtures
    in this set.  So "the goldens that moved" is exactly "the fixtures whose
    emitted code changed" -- the set worth booting.

    Returns (subset, note).  `note` is non-empty whenever coverage is narrower
    than the caller might assume, and is always printed: a scoped run that does
    not say what it skipped reads as a full pass."""
    changed = _git_changed_paths()
    if changed is None:
        return fixtures, ("git could not determine a merge base; falling back "
                          "to the FULL suite")

    def _changed_here(f):
        return (rel_to_repo(f["c"]) in changed or rel_to_repo(f["s"]) in changed
                or rel_to_repo(f["s"]).replace(".expected.s",
                                               ".expected.data.s") in changed)

    broad = sorted(p for p in changed if p.startswith(BROAD_INPUT_PREFIXES))
    if broad:
        # Every fixture links the pile, so every binary changed and no golden
        # did.  Scoping by goldens here would select ZERO fixtures and report a
        # clean run over a change that touched all 546 -- the worst outcome.
        #
        # THE FIXTURES WHOSE GOLDENS ACTUALLY MOVED GO IN FIRST, AND USED NOT
        # TO.  This arm replaced the changed set with a uniform sample, which
        # is exactly backwards: a golden that moved is the strongest evidence
        # there is that a fixture's emitted code changed, and a spread sample
        # is a guess.  It cost a real regression -- UFS 1.12d made vget sleep,
        # vnodepool.c asserts that nothing in the vnode pool blocks, the golden
        # moved and was regenerated, and the sample did not include vnodepool.
        # The gate reported 238/238 and was green over a fixture that returned
        # 108.  Measured, from .gate/fee96a49...oracle.log.
        forced = [f for f in fixtures if _changed_here(f)]
        rest = [f for f in fixtures if not _changed_here(f)]
        room = MAX_FIXTURES_PER_DISK - len(forced)
        if room < 0:
            capped, room = forced[:MAX_FIXTURES_PER_DISK], 0
        else:
            capped = forced + _spread_sample(rest, room)
        return capped, (
            "libc/runtime pile changed (%s%s) -- this alters EVERY fixture "
            "binary but NO golden, so golden-diff scoping cannot see it. "
            "Running the %d whose own source or golden DID change, plus a "
            "%d-of-%d sample spread across all M-dirs; the other %d are NOT "
            "covered (exceeds the change-scoped cap of 240). Use --names for "
            "a targeted set."
            % (", ".join(broad[:3]), " +%d more" % (len(broad) - 3) if len(broad) > 3 else "",
               len(forced), len(capped) - len(forced), len(fixtures),
               len(fixtures) - len(capped)))

    subset = [f for f in fixtures if _changed_here(f)]
    if not subset:
        return [], ("no fixture source or golden differs from the merge base, "
                    "so no fixture's emitted code changed -- nothing to verify. "
                    "Use --names or --all to run anyway.")
    if len(subset) > MAX_FIXTURES_PER_DISK:
        dropped = len(subset) - MAX_FIXTURES_PER_DISK
        return subset[:MAX_FIXTURES_PER_DISK], (
            "%d fixtures changed, which exceeds the change-scoped cap of 240; "
            "running %d, DROPPING %d. Split the run with --names."
            % (len(subset), MAX_FIXTURES_PER_DISK, dropped))
    return subset, ""


def rel_to_repo(p):
    try:
        return str(Path(p).resolve().relative_to(Path(REPO).resolve()))
    except ValueError:
        return str(p)


def discover_fixtures():
    out = []
    for c_path in sorted(FCC_TESTS.glob("M*/*.c")):
        name = c_path.stem
        s_path = c_path.with_suffix(".expected.s")
        if not s_path.exists():
            continue
        out.append({
            "name": name,
            "c": c_path,
            "s": s_path,
        })
    return out


# The fixture link: run.sh's, the bench's and the sweep's, in one place
# (fixture_link.py, fgx_static).
import fixture_link  # noqa: E402

_LINK_INTERMEDIATES = ["fcc_output.s", "fcc_output.data.s", "fixture_fgx"]


def link_fixture(link_dir, extra_code=()):
    """Link the staged fcc_output.s/.data.s in link_dir -> fixture_fgx.
    Returns the Path or None."""
    out = link_dir / "fixture_fgx"
    ok, _log = fixture_link.link(str(link_dir), str(link_dir / ".ld"),
                                 ["fcc_output.s"] + list(extra_code),
                                 ["fcc_output.data.s"], str(out))
    return out if ok else None


def build_fcc_bin(fixture, out_dir, fcc_path):
    """Differential mode (Phase-2 net): recompile the fixture's .c with a
    CANDIDATE fcc binary, assemble+link with the normal FGX2 fixture flow,
    and return the binary — the runtime oracle then validates exit codes,
    decoupled from byte-identical .s output."""
    link_dir = fixture["c"].parent
    fcc_out = link_dir / "fcc_output.s"
    fcc_data_out = link_dir / "fcc_output.data.s"
    out_bin = out_dir / (fixture["name"] + ".fcc.bin")
    # Bank-0 campaign 1.3: honour the <name>.softscc sidecar, exactly as
    # run.sh does.  Without this the binary MAME runs has NO soft frames even
    # when the fixture exists to test them -- and a soft-frame fixture that
    # compiles hard is correct by construction, so it passes, and so does any
    # mutation of the soft codegen.  Measured 2026-08-02: a deliberately
    # reverted soft arm "passed" on MAME twice because of this gap.  The two
    # builders must agree or the runtime leg tests a different program than
    # the golden does.
    env = dict(os.environ)
    sidecar = link_dir / (fixture["name"] + ".softscc")
    env["FCC_SOFT_SCC"] = sidecar.name if sidecar.exists() else ""
    # And the <name>.sigs sidecar, for the same reason: fcc compiles a
    # fixture ABOUT --sigs differently with it, and without it the program
    # MAME runs is plain K&R -- correct by construction, so a reverted sidecar
    # change passed here while run.sh's golden went red (M38/sigsown,
    # measured).
    sigs = link_dir / (fixture["name"] + ".sigs")
    sigsarg = ["--sigs", sigs.name] if sigs.exists() else []
    # And the M-dir's _fcc.flags (M42: --libso-inplace), as run.sh passes them.
    flags_file = link_dir / "_fcc.flags"
    dirflags = flags_file.read_text().split() if flags_file.exists() else []
    try:
        r = subprocess.run(
            [str(fcc_path),
             "--data-segment", "fcc_output.data.s"] + sigsarg + dirflags +
            [fixture["c"].name, "-o", "fcc_output.s"],
            capture_output=True, text=True, cwd=link_dir, timeout=30, env=env)
        if r.returncode != 0 or not fcc_out.exists():
            return None
        linked = link_fixture(link_dir)
        if linked is None:
            return None
        shutil.copy(linked, out_bin)
        return out_bin
    finally:
        for f in _LINK_INTERMEDIATES:
            (link_dir / f).unlink(missing_ok=True)
        shutil.rmtree(link_dir / ".ld", ignore_errors=True)


def write_file_info(dir_path, names):
    info = "\n".join(
        f"{n}=Type(06),AuxType(0000),VersionCreate(00),MinVersion(00),Access(C3)"
        for n in names) + "\n"
    (dir_path / "_FileInformation.txt").write_text(info)


def stage_fixtures(fixtures, fas_bin_dir, use_fcc=None, build_jobs=1):
    """Copy fixture binaries to disk_src/tests/fcc/ with short disk names.
    Returns list of dicts: {name, disk, bin_path}.

    Task #60: the candidate-fcc compile+assemble+link of every fixture
    dominated differential-mode wall clock (serial ~1s x ~420).  Fixtures
    in the SAME M-dir share scratch filenames (fcc_output.s, seg0, seg1...),
    so the unit of parallelism is the M-DIR: dirs build concurrently,
    fixtures within a dir stay serial.  Disk names + chunk assignment stay
    deterministic: builds land in a dict, the original fixture order drives
    staging."""
    if DISK_SRC_FCC.exists():
        shutil.rmtree(DISK_SRC_FCC)
    DISK_SRC_FCC.mkdir(parents=True)
    built = {}
    by_dir = {}
    for fx in fixtures:
        by_dir.setdefault(fx["c"].parent, []).append(fx)

    def _build_dir(dir_fixtures):
        for fx in dir_fixtures:
            built[fx["name"]] = build_fcc_bin(fx, fas_bin_dir, use_fcc)

    if build_jobs > 1 and len(by_dir) > 1:
        t0 = time.monotonic()
        with ThreadPoolExecutor(max_workers=build_jobs) as ex:
            list(ex.map(_build_dir, by_dir.values()))
        print(f"==> fixture builds: {len(fixtures)} fixtures, "
              f"{len(by_dir)} dirs x {build_jobs} jobs, "
              f"{time.monotonic() - t0:.0f}s")
    else:
        for dfx in by_dir.values():
            _build_dir(dfx)
    staged = []
    seen = set()
    for fx in fixtures:
        bin_path = built.get(fx["name"])
        if bin_path is None:
            staged.append({**fx, "disk": None, "stage_path": None,
                           "skip_reason": "fcc compile/assemble failed"})
            continue
        disk = short_disk_name(fx["name"], seen)
        shutil.copy(bin_path, DISK_SRC_FCC / disk)
        staged.append({**fx, "disk": disk, "stage_path": bin_path,
                       "skip_reason": None})
    write_file_info(DISK_SRC_FCC,
                    [s["disk"] for s in staged if s["disk"]])
    return staged


def build_big_disk():
    """Build the sweep's boot volume.  A 2.11BSD one -- apple/fgx#342.

    IT USED TO BE ProDOS, AND THAT STOPPED WORKING ON 2026-09-04.  This ran
    `make_disk.sh' with DISK_SIZE_OVERRIDE/DISK_IMAGE_OVERRIDE, which is the
    ProDOS image builder, and the kernel stopped booting ProDOS at `fa0f4c2b2'
    ("ProDOS leaves the boot path") -- so both the sweep and the fixture oracle
    booted to a BLANK SCREEN and reported "no =MBEND/=MBRC marker (hang or boot
    failure)".  They had been dead for two days and nothing said so, because
    their gate step is stamped on `fcc_source_hash()', which covers `toolchain'
    and `src/kernel/vfs' but not the boot path: the skip said "fcc unchanged
    since the sweep + oracle last passed", which was true and irrelevant.

    THE 32 MB CEILING GOES WITH ProDOS, and with it the trimming.  This used to
    carve the image down with DISK_BIN_KEEP because "32 MB is the ProDOS VOLUME
    CEILING, not a tunable: the fixtures alone are ~28 MB and the full userland
    is another ~12 MB".  A 2.11BSD volume has no such ceiling, so the sweep now
    boots the SAME tree every other test does.  That is worth more than the
    space: the old comment recorded that "two earlier attempts to make room by
    pruning the image broke the sweep in ways that LOOK like codegen
    regressions, which is the worst possible failure mode" -- and a trimmed
    image is exactly the thing that produces them.
    """
    blocks = os.environ.get("FCC_RUNTIME_BLOCKS", str(BIG_DISK_BLOCKS))
    env = os.environ.copy()
    env["UFSBOOT_BLOCKS"] = blocks
    r = subprocess.run(["bash", "tools/make_ufsboot.sh", BIG_DISK_REL],
                       cwd=REPO, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-2000:], file=sys.stderr)
        print(r.stderr[-2000:], file=sys.stderr)
        sys.exit(f"make_ufsboot.sh (sweep volume) failed: {r.returncode}")


def build_default_kernel_first(stage_userland=False):
    """Ensure bin/fgx.bin is fresh (make_disk.sh --skip-kernel assumes it) AND
    that the disk_src tree is restaged from current sources.

    `ninja disk` is the entry point since the monorepo/ninja migration deleted
    build.sh.  This function still called `./build.sh [disk]` afterwards, so
    every runtime oracle that routes through it -- run_runtime.py's fixture
    sweep and tests/multibank/run_multibank.py -- died with FileNotFoundError
    the moment it tried to rebuild.  The only way either would run was
    --no-rebuild, which silently measures a STALE disk image: the sweep then
    reports the PREVIOUS binary's verdict as if it were the current one, the
    exact false-green this oracle exists to prevent.

    The `disk` target subsumes the old `build.sh disk`: it builds the kernel
    and userland and stages them into disk_src/ (incl. /BIN/SH -- a stale shell
    loses the do_source `$?` keystone and chunked markers stay literal `$?`),
    along with disk_src/tests/fcc/mbsweep for the multibank sweep.  It also
    images disk/fgx.po, which callers that re-image with DISK_SIZE_OVERRIDE
    discard; that spare image is the price of using the one target that is
    guaranteed to have staged everything.  stage_userland is kept for callers
    but no longer selects a narrower build -- `disk` always stages.

    THE GRAPH IS REGENERATED FIRST.  tools/ninja/gen.py lists the files under
    disk_src when it runs, and both callers add or remove disk_src/tests/fcc
    just before calling this.  A graph written while the multibank sweep's
    mbsweep was staged names it as an input of disk/fgxufs.po, and once it is
    gone `ninja disk` fails with "missing and no known rule to make it"."""
    subprocess.run(["python3", "tools/ninja/gen.py"], cwd=REPO,
                   capture_output=True, text=True, check=True)
    cmd = ["ninja", "disk"]
    r = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-2000:], file=sys.stderr)
        print(r.stderr[-2000:], file=sys.stderr)
        sys.exit(f"{' '.join(cmd)} failed")


def make_batch_manifest(batch_idx, batch_disks):
    name = f"fcc_runtime_batch{batch_idx:03d}"
    parts = []
    for disk in batch_disks:
        parts.append(f"/tests/fcc/{disk.lower()}")
        parts.append(f"echo ={disk} $?")
    parts.append("echo =DONE")
    command = "\\n".join(parts)
    timeout = BOOT_OVERHEAD_S + len(command) // PASTE_CHARS_PER_SEC + PER_FIX_S * len(batch_disks)
    return name, {
        "name": name,
        "description": f"fcc-runtime batch {batch_idx}: {len(batch_disks)} fixtures",
        "command": command,
        "timeout_s": timeout,
        "disk_image": BIG_DISK_REL,
        "exit_on_prompt": {"sentinel": "=DONE", "count_delta": 1},
        "expect": {"screen_contains": ["=DONE"]}
    }


def parse_batch_results(scratch_dir, batch):
    dump_txt = scratch_dir / "dump.txt"
    screen = dump_txt.read_text() if dump_txt.exists() else ""
    out = {}
    for entry in batch:
        if entry.get("disk") is None:
            out[entry["name"]] = (None, entry.get("skip_reason") or "no disk")
            continue
        m = re.search(rf'={re.escape(entry["disk"])}\s+(\d+)', screen, re.I)
        out[entry["name"]] = (int(m.group(1)), None) if m else (None, "no marker")
    return out


def run_batches(staged, batch_size):
    runnable = [s for s in staged if s.get("disk")]
    batches = [runnable[i:i + batch_size]
               for i in range(0, len(runnable), batch_size)]
    results = {}
    for i, batch in enumerate(batches):
        bname, mf = make_batch_manifest(i, [b["disk"] for b in batch])
        mf_path = MAME_TESTS / f"{bname}.json"
        mf_path.write_text(json.dumps(mf, indent=2))
        try:
            subprocess.run(["python3", str(RUN_PY), bname, "--headless"],
                           cwd=REPO, capture_output=True, text=True,
                           timeout=180)
            scratch = Path(f"/tmp/fgx_test_{bname}")
            results.update(parse_batch_results(scratch, batch))
            done = sum(1 for n in [b["name"] for b in batch]
                       if results.get(n, (None,))[0] is not None)
            print(f"  batch {i:03d}: {done}/{len(batch)} got exit code")
        finally:
            mf_path.unlink(missing_ok=True)
    # Carry forward "no disk" entries already in results.
    for s in staged:
        results.setdefault(s["name"], (None, s.get("skip_reason") or "missing"))
    return results


# --- Chunked mode: one MAME boot per chunk, fixtures run via the shell's
# --- `source` (needs the do_source $?-expansion keystone).  ~chunk_size× fewer
# --- boots than the per-2-fixture batch mode.  Markers (=<disk> <code>) are
# --- echoed to the screen and scraped exactly as in batch mode.
def stage_chunk_scripts(staged, chunk_size):
    """Write one source-able script per chunk into DISK_SRC_FCC; each runs its
    fixtures and echoes `=<disk> $?` markers.  Runs AFTER stage_fixtures,
    BEFORE build_big_disk.  Returns [(chunk_name, [entries])]."""
    runnable = [s for s in staged if s.get("disk")]
    chunks = [runnable[i:i + chunk_size]
              for i in range(0, len(runnable), chunk_size)]
    meta, names = [], []
    for k, chunk in enumerate(chunks):
        # LOWER, like every other name on a 2.11BSD root.  The command
        # below has always spelled it `sh /tests/fcc/{name.lower()}';
        # ProDOS compared case-insensitively so the mismatch was
        # invisible, and on a case-SENSITIVE root the shell finds
        # nothing and the chunk reports "TRUNCATED (no =DONE)" --
        # which reads as a hang.  apple/fgx#342.
        cname = f"chunk{k:02d}"
        # `clear` FIRST: dump.txt is a SCREEN SNAPSHOT, not a scrollback log,
        # and the boot log otherwise occupies ~16 rows of it.  This is for
        # DIAGNOSABILITY, not capacity -- clearing the screen did NOT raise the
        # marker count, which is how the "markers scrolled off the screen"
        # theory was ruled out (the real cause was the dot-sourcing death, now
        # sidestepped; see CHUNK_DEFAULT).  It keeps the dump readable and
        # stops a growing boot log from confusing the next investigation.
        lines = ["clear"]
        for e in chunk:
            lines.append(f"/tests/fcc/{e['disk'].lower()}")
            lines.append(f"echo ={e['disk']} $?")
        lines.append("echo =DONE")
        (DISK_SRC_FCC / cname).write_text("\n".join(lines) + "\n")
        meta.append((cname, chunk))
        names.append(cname)
    # Re-write _FileInformation.txt to include fixtures + chunk scripts.
    write_file_info(DISK_SRC_FCC,
                    [s["disk"] for s in staged if s["disk"]] + names)
    return meta


def make_chunk_manifest(chunk_idx, chunk_name, n_fix):
    name = f"fcc_runtime_chunk{chunk_idx:03d}"
    # `.` (dot), NOT `source`: /bin/sh is now bsh, the 2.11BSD Bourne shell,
    # whose sourcing builtin is `.` -- `source` is a csh/jsh-ism.  When the
    # login shell changed, every chunk silently produced no markers and the
    # whole sweep reported "no-marker" for every fixture, including return_0.
    # `sh <script>`, NOT `. <script>`.  Dot-sourcing dies partway through a
    # script -- 17 spawns in isolation, far fewer when builtins are mixed in --
    # leaving a garbled line and no sentinel (issue #9).  A CHILD shell reading
    # the same script runs all 30 spawns of the reproducer cleanly, so the fault
    # is in the dot path, not in spawning.  Costs one extra process per chunk
    # and buys back large chunks.
    command = f"sh /tests/fcc/{chunk_name.lower()}"   # one short paste
    timeout = BOOT_OVERHEAD_S + PER_FIX_S * n_fix + 5
    return name, {
        "name": name,
        "description": f"fcc-runtime chunk {chunk_idx}: {n_fix} fixtures via source",
        "command": command,
        "timeout_s": timeout,
        "disk_image": BIG_DISK_REL,
        "exit_on_prompt": {"sentinel": "=DONE", "count_delta": 1},
        "expect": {"screen_contains": ["=DONE"]},
    }


def run_chunked(staged, chunk_meta, jobs=1):
    """Task #60: chunks are fully isolated (run.py clones the disk into a
    per-test scratch dir; the fgxdebug config is per-scratch via
    FGX_DEBUG_CONFIG), so N MAME instances run concurrently.  Progress +
    ETA print as chunks complete (closed-loop convention)."""
    results = {}
    t0 = time.monotonic()
    n_total = len(chunk_meta)
    n_done = 0

    def _run_one(item):
        i, (cname, chunk) = item
        bname, mf = make_chunk_manifest(i, cname, len(chunk))
        mf_path = MAME_TESTS / f"{bname}.json"
        mf_path.write_text(json.dumps(mf, indent=2))
        # Delete any dump a PREVIOUS run left in this scratch dir first.  The
        # scratch path is derived from the chunk INDEX, so a boot that produces
        # nothing otherwise gets scored against the last run's screen -- and if
        # that run split the fixtures differently, the stale markers belong to
        # other fixtures entirely.  Observed exactly that: a chunk reported 0/8
        # while its dump held four markers from a differently-sized earlier run,
        # complete with a =DONE that made it look like a clean boot.
        # run_multibank.py already guards this; the chunk path did not.
        scratch = Path(f"/tmp/fgx_test_{bname}")
        stale = scratch / "dump.txt"
        if stale.exists():
            stale.unlink()
        try:
            # --fresh is MANDATORY here.  run.py keeps a green cache and, on a
            # hit, reports "cached PASS" WITHOUT booting MAME and WITHOUT
            # writing a dump.  That cache is sound for run.py's own assertion
            # (screen_contains "=DONE"), but this harness does not use that
            # verdict -- it scrapes the SCREEN for per-fixture markers.  So a
            # cache hit left us parsing whatever dump.txt happened to be in the
            # scratch dir from an earlier run, which is keyed on chunk INDEX and
            # so routinely held a DIFFERENT chunk's fixtures.  Every score this
            # harness produced across a cached run was against a stale screen.
            subprocess.run(["python3", str(RUN_PY), bname, "--headless", "--fresh"],
                           cwd=REPO, capture_output=True, text=True,
                           timeout=300)
            r = parse_batch_results(scratch, chunk)
            got = sum(1 for e in chunk
                      if r.get(e["name"], (None,))[0] is not None)
            # The chunk script's last act is `echo =DONE`.  Its ABSENCE means
            # the chunk did not finish -- the markers we did get are a prefix,
            # and the rest are missing for a HARNESS reason (scrolled off the
            # screen, boot failure, hang), not because those fixtures failed.
            # Scoring them as regressions is the one failure mode this oracle
            # must never have, so surface it instead.
            dump = scratch / "dump.txt"
            done = dump.exists() and "=DONE" in dump.read_text(errors="replace")
            if not done:
                # NAME them, rather than leaving them to fall through to the
                # generic "missing" below.  Without a reason of their own they
                # are indistinguishable from a fixture that ran and produced
                # nothing, which is what made a single hang read as forty
                # regressions.
                for e in chunk:
                    if r.get(e["name"], (None,))[0] is None:
                        r[e["name"]] = (None, UNSCORED)
            return i, cname, len(chunk), got, r, done
        finally:
            mf_path.unlink(missing_ok=True)

    truncated = []

    def _report(i, cname, n_chunk, got, done):
        nonlocal n_done
        n_done += 1
        elapsed = time.monotonic() - t0
        eta = elapsed / n_done * (n_total - n_done)
        flag = "" if done else "   *** TRUNCATED (no =DONE) ***"
        if not done:
            truncated.append((cname, got, n_chunk))
        print(f"  chunk {i:03d} ({cname}): {got}/{n_chunk} got marker   "
              f"[{n_done}/{n_total} chunks, ETA {eta:.0f}s]{flag}")

    if jobs > 1 and n_total > 1:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            futs = [ex.submit(_run_one, item)
                    for item in enumerate(chunk_meta)]
            for fut in as_completed(futs):
                i, cname, n_chunk, got, r, done = fut.result()
                results.update(r)
                _report(i, cname, n_chunk, got, done)
    else:
        for item in enumerate(chunk_meta):
            i, cname, n_chunk, got, r, done = _run_one(item)
            results.update(r)
            _report(i, cname, n_chunk, got, done)
    if truncated:
        lost = sum(n - g for _, g, n in truncated)
        print(f"\n==> HARNESS FAILURE: {len(truncated)} of {n_total} chunks did "
              f"not reach =DONE; {lost} fixtures went UNSCORED.")
        print("==> Those fixtures are NOT regressions -- they never reported. "
              f"Lower --chunk-size (default {CHUNK_DEFAULT}) "
              "or investigate a boot/hang failure before reading the scores below.")
    for s in staged:
        results.setdefault(s["name"], (None, s.get("skip_reason") or "missing"))
    return results


# A fixture whose CHUNK never reached `=DONE'.  It did not run, so it is not a
# pass and it is not a regression -- and calling it a regression is the one
# failure mode a correctness oracle must not have, because it buries the real
# ones in noise.  The run still FAILS on it: an answer that was never given is
# not a clean result either.
UNSCORED = "chunk-truncated"


def classify(name, got, why, oracle):
    """One fixture's verdict: 'pass', 'regression', 'unscored' or 'incompat'.

    Pulled out of the summary loop so `--self-test' can drive it, because the
    distinction it draws is the whole point: a fixture whose chunk never
    reached `=DONE' MUST NOT come back 'regression'.  One hung fixture takes
    its whole chunk down with it, and calling those forty failures buries the
    real ones -- which is what apple/fgx#383 cost about forty minutes to
    unpick, with the runner printing "those fixtures are NOT regressions" four
    lines above the summary that counted them as exactly that.
    """
    if name not in oracle:
        return "incompat"
    if got is None:
        return "unscored" if why == UNSCORED else "regression"
    return "pass" if got == oracle[name] else "regression"


def _selftest_classify():
    """It must separate the two, in BOTH directions.

    A classifier that called everything 'unscored' would pass a one-sided
    check and silence every real regression, so the genuine failures are
    driven here too and must still come back 'regression'.
    """
    oracle = {"ok": 42, "bad": 42, "hung": 42}
    cases = [
        # name,   got,  why,        expected verdict
        ("ok",    42,   None,       "pass"),
        ("bad",   12,   None,       "regression"),   # wrong exit: a real one
        ("bad",   None, "missing",  "regression"),   # ran, said nothing
        ("bad",   None, None,       "regression"),
        ("hung",  None, UNSCORED,   "unscored"),     # THE case
        ("hung",  42,   UNSCORED,   "pass"),         # marker arrived anyway
        ("other", None, UNSCORED,   "incompat"),     # not in the oracle at all
    ]
    bad = []
    for name, got, why, want in cases:
        verdict = classify(name, got, why, oracle)
        if verdict != want:
            bad.append(f"{name} got={got} why={why}: {verdict} != {want}")
    if bad:
        print("run_runtime classify self-test: FAIL")
        for b in bad:
            print("   " + b)
        return 1
    print("run_runtime classify self-test: OK (a truncated chunk is unscored, "
          "a wrong exit and a silent fixture are still regressions, and a "
          "fixture outside the oracle is neither)")
    return 0


def load_oracle():
    if ORACLE_PATH.exists():
        return json.loads(ORACLE_PATH.read_text())
    return {}


def save_oracle(oracle):
    ORACLE_PATH.write_text(json.dumps(oracle, indent=2, sort_keys=True))


def main():
    if "--self-test" in sys.argv:
        return _selftest_classify()
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--batch-size", type=int, default=BATCH_SIZE)
    ap.add_argument("--use-fas-bin", action="store_true",
                    help="RETIRED at P3-2.6 (2-seg FGX2 wrappers; see docstring)")
    ap.add_argument("--use-fcc", default="",
                    help="DIFFERENTIAL mode: path to a CANDIDATE fcc binary; each "
                         "fixture's .c is recompiled with it (Merlin assembles as "
                         "usual) and exit codes are validated against oracle.json. "
                         "The Phase-2 front-end rewrite net: behavior-based, immune "
                         "to .s churn.")
    ap.add_argument("--calibrate", action="store_true",
                    help="record observed exit codes from Merlin runs to oracle.json")
    ap.add_argument("--names", default="",
                    help="comma-separated fixture names to include")
    ap.add_argument("--all", action="store_true",
                    help="run EVERY fixture instead of the default change-scoped "
                         "set. THIS IS THE SWEEP: the default stages only what "
                         "changed, so a plain run can report '3/3 pass' and read "
                         "exactly like a suite result. It used to die on the "
                         "ProDOS 32 MB ceiling because the disk was built one "
                         "block over the maximum; that was the sweep-disk size "
                         "fix, and --all now completes.")
    ap.add_argument("--chunked", action="store_true",
                    help="(DEFAULT) run fixtures via `.`-sourced scripts, one "
                         "MAME boot per chunk; ~13x faster than --batch")
    ap.add_argument("--batch", action="store_true",
                    help="legacy per-2-fixture batch mode (one boot per 2 fixtures, "
                         "~13x slower); fallback if a chunk's markers scroll off-screen")
    ap.add_argument("--jobs", type=int, default=0,
                    help="parallel MAME chunk instances (task #60).  Default 0 = "
                         "auto (min(4, cpu//2)); 1 = serial (pre-#60 behavior).  "
                         "Differential builds always parallelize per-M-dir at "
                         "min(8, cpu).")
    ap.add_argument("--chunk-size", type=int, default=CHUNK_DEFAULT,
                    help=f"fixtures per chunk in chunked mode (default {CHUNK_DEFAULT}). "
                         "Bounded by the per-chunk timeout (n <= 45), not by the "
                         "shell: the chunk runs via `sh <file>` rather than `.`, "
                         "which used to die partway through (issue #9).")
    ap.add_argument("--multibank", action="store_true",
                    help="run the multi-bank far-pointer construct SWEEP instead of the "
                         "single-bank oracle (one FGX2 binary; green iff exit 42). The "
                         "gate for the DBR!=PB far-pointer bank class (task #56); see "
                         "multibank/README.md.")
    args = ap.parse_args()

    # --multibank: thin alias to the sweep runner.  Skips the single-bank
    # fixture/chunk pipeline entirely (the sweep is one FGX2 binary, not ~150
    # single-bank fixtures).
    if args.multibank:
        return subprocess.call(
            [sys.executable, str(FCC_TESTS / "multibank" / "run_multibank.py")])

    # Chunked is the default; --batch opts out.  (--chunked is still accepted for
    # back-compat but is now redundant.)
    use_chunked = not args.batch

    if args.use_fas_bin:
        sys.exit("--use-fas-bin was RETIRED at P3-2.6: the fixture wrappers are "
                 "fgx_static links fas cannot drive; fas-on-FGX validation "
                 "lives in the fas_fgx build instead.")

    fixtures = discover_fixtures()
    total = len(fixtures)
    scope = "all"
    if args.names:
        wanted = set(n.strip() for n in args.names.split(",") if n.strip())
        fixtures = [f for f in fixtures if f["name"] in wanted]
        missing = wanted - {f["name"] for f in fixtures}
        if missing:
            # HARD failure, not a warning.  --names is an EXPLICIT request, so a
            # name that does not exist is a mistake in the request -- a typo, a
            # renamed fixture, a shell that expanded something unexpected.  This
            # used to warn and carry on, which meant the run still exited 0 and
            # printed "0/0 oracle-validated pass": a green verdict from a run
            # that executed nothing.  That is the exact shape this whole issue
            # is about (#7), and it bit again while VERIFYING the issue -- a
            # colourised `ls` fed 20 junk names in and the harness called it a
            # pass.
            sys.exit("==> ERROR: requested fixtures do not exist: "
                     f"{', '.join(sorted(missing))}\n"
                     "    (--names is explicit; refusing to report a verdict on "
                     "a selection that is not what was asked for)")
        if not fixtures:
            sys.exit("==> ERROR: --names selected no fixtures")
        scope = "--names"
    elif not args.all:
        fixtures, note = select_changed(fixtures)
        scope = "changed-vs-merge-base"
        if note:
            print(f"==> NOTE: {note}")
        if not fixtures:
            print(f"==> 0 of {total} fcc fixtures selected -- nothing to run")
            return 0
    if args.limit:
        fixtures = fixtures[:args.limit]
    print(f"==> {len(fixtures)} of {total} fcc fixtures selected ({scope})")
    if args.use_fcc:
        mode = f"candidate-fcc-built ({args.use_fcc})"
    elif args.calibrate:
        mode = "calibration"
    else:
        mode = "repo-fcc-built"
    print(f"==> mode: {mode}")

    # The fixture binaries are always BUILT here, never read from the tree: the
    # linked .bin is a derived artifact (fcc + merlin32 + fgx_ld over committed
    # text) and is no longer committed.  --use-fcc just points the build at a
    # different fcc than this repo's.
    use_fcc_path = Path(args.use_fcc).resolve() if args.use_fcc \
        else (TOOLCHAIN_ROOT / "fcc").resolve()
    if args.use_fcc and args.calibrate:
        print("==> ERROR: --use-fcc is exclusive with --calibrate")
        sys.exit(2)
    if not use_fcc_path.exists():
        print(f"==> ERROR: fcc not found: {use_fcc_path}")
        sys.exit(2)

    fas_bin_dir = REPO / "build" / "fcc_runtime_diff"
    fas_bin_dir.mkdir(parents=True, exist_ok=True)

    # Always restage userland: BOTH the batch (`echo =<disk> $?`) and the
    # chunked (source-script $?) marker mechanisms depend on a fresh shell with
    # the `$?` keystone.  A plain `./build.sh` leaves a stale /BIN/JSH on the
    # sweep disk -> `$?` stays literal `?` -> every fixture reports "no marker".
    print("==> ensuring kernel + userland are built and staged...")
    # Clear any fixtures a PREVIOUS sweep left behind, BEFORE `./build.sh disk`.
    # stage_fixtures() clears this dir too, but that runs after the build, and
    # the end-of-run cleanup is skipped whenever a sweep dies early -- so a
    # crashed run leaves ~28 MB of fixtures in disk_src/tests/fcc, `build.sh
    # disk` sweeps them into the ordinary (much smaller) disk image, and the
    # NEXT sweep fails in cadius with "not enough space" while pointing at a
    # fixture name.  That reads like the sweep outgrowing the 32 MB ProDOS
    # ceiling; it is actually stale state, and it made the full sweep look
    # permanently broken after the first crash.
    if DISK_SRC_FCC.exists():
        shutil.rmtree(DISK_SRC_FCC)
    build_default_kernel_first(stage_userland=True)
    print("==> staging fixtures on disk_src/tests/fcc/...")
    build_jobs = min(8, os.cpu_count() or 4)
    staged = stage_fixtures(fixtures, fas_bin_dir, use_fcc=use_fcc_path,
                            build_jobs=build_jobs)
    print(f"==> {sum(1 for s in staged if s['disk'])} fixtures staged "
          f"({sum(1 for s in staged if not s['disk'])} skipped: build fail)")
    if use_chunked:
        # NOTE: the 240 cap applies only to the default change-scoped
        # selection (select_changed); --names and --all are both uncapped and
        # run on one disk regardless of size, since the volume no longer
        # binds (see the module docstring).  Splitting a run across several
        # disk builds is not implemented -- an attempt is in the history and
        # was reverted because a half-working split reports "no-marker", i.e.
        # it is indistinguishable from real regressions, which is the one
        # failure mode a correctness oracle must never have.
        chunk_meta = stage_chunk_scripts(staged, args.chunk_size)
        print(f"==> staged {len(chunk_meta)} chunk scripts "
              f"(chunk_size={args.chunk_size})")
        print(f"==> building sweep disk at {BIG_DISK_REL}...")
        build_big_disk()
        mame_jobs = args.jobs if args.jobs > 0 else max(1, min(4, (os.cpu_count() or 4) // 2))
        print(f"==> running {len(chunk_meta)} chunks "
              f"(one boot each, {mame_jobs} parallel)")
        results = run_chunked(staged, chunk_meta, jobs=mame_jobs)
    else:
        print(f"==> running {len(staged) // args.batch_size + (1 if len(staged) % args.batch_size else 0)} batches")
        results = run_batches(staged, args.batch_size)

    # Oracle handling.
    oracle = load_oracle()
    if args.calibrate:
        # Record observed exit codes.
        for s in staged:
            got, _ = results.get(s["name"], (None, None))
            if got is not None:
                oracle[s["name"]] = got
        save_oracle(oracle)
        print(f"==> wrote {len(oracle)} entries to {ORACLE_PATH.relative_to(REPO)}")

    # Score against oracle.  Three populations:
    #   1. Fixtures IN oracle (Merlin produced an exit code): real scoring.
    #      pass = exit matches; fail = exit mismatch; miss = fas didn't
    #      produce a marker = REGRESSION (fas-built fails where Merlin
    #      succeeded).
    #   2. Fixtures NOT in oracle (Merlin calibration also missed them):
    #      FGX-incompatible (hang, crash, or runtime feature gap).  Don't
    #      score either way — report separately.
    pass_ct = regr_ct = incompat_ct = no_oracle_ct = 0
    unscored = []
    regressions = []
    incompats = []
    for s in staged:
        got, why = results.get(s["name"], (None, None))
        name = s["name"]
        expected = oracle.get(name)
        in_oracle = classify(name, got, why, oracle) != "incompat"
        if not in_oracle:
            # Fixture wasn't in oracle.  Whether or not fas got a marker,
            # it's FGX-incompatible (no Merlin baseline).
            incompat_ct += 1
            if got is None:
                incompats.append((name, "no-marker-merlin+fas", "-", "-"))
            else:
                # fas DID produce a marker; Merlin didn't.  Lucky timing
                # or genuine fas-better-than-Merlin.  Surface separately.
                incompats.append((name, "fas-only", "-", got))
                no_oracle_ct += 1
            continue
        # In-oracle scoring.
        verdict = classify(name, got, why, oracle)
        if verdict == "unscored":
            unscored.append(name)
        elif verdict == "pass":
            pass_ct += 1
        else:
            regr_ct += 1
            regressions.append((name, "no-marker" if got is None else
                                "wrong-exit", expected,
                                "-" if got is None else got))

    total_scored = pass_ct + regr_ct
    print()
    print(f"==> SCORED (in oracle): {pass_ct}/{total_scored} pass  "
          f"({regr_ct} regressions)")
    if unscored:
        print(f"==> UNSCORED (chunk never reached =DONE): {len(unscored)} "
              f"fixture(s) -- NOT regressions, they never ran.  This run is "
              f"INCOMPLETE and fails on that alone.")
        print(f"    {', '.join(sorted(unscored)[:20])}"
              + (" ..." if len(unscored) > 20 else ""))
    print(f"==> FGX-INCOMPAT (not in oracle): {incompat_ct} fixtures  "
          f"({no_oracle_ct} of them got a marker from fas)")
    if regressions:
        print(f"==> REGRESSIONS ({len(regressions)}):")
        for n, why, exp, got in regressions[:80]:
            print(f"    {why:10s} {n:24s} expected={exp:>5}  got={got!s:>5}")
    if incompats:
        print(f"==> FGX-INCOMPAT fixtures (excluded from score): "
              f"{[n for n,_,_,_ in incompats]}")
    print(f"\n  {pass_ct}/{total_scored} oracle-validated pass  "
          f"(out of {len(staged)} total"
          + (f", {len(unscored)} UNSCORED" if unscored else "") + ")")

    # Clean up disk_src/tests/fcc/ so a subsequent ./build.sh disk doesn't
    # try to stage 176+ fixture binaries onto the 800K boot disk and silently
    # drop the kernel (cost a ~10-min debug round; see commit message).
    if DISK_SRC_FCC.exists():
        shutil.rmtree(DISK_SRC_FCC)

    # An unscored fixture is not a pass.  The run answered a question it was
    # not asked, and the exit code says so.
    return 0 if (regr_ct == 0 and not unscored) else 1


if __name__ == "__main__":
    sys.exit(main())
