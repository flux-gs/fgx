#!/usr/bin/env python3
"""fbench Option B — cycle timing under the REAL FGX kernel.

Benches that need more runtime than the bare-metal Option-A env (div/mod,
pointers, static data, recursion) hang bare-metal but run correctly under the
kernel.  This driver builds each corpus bench as an FGX1 binary (with the
fbench_start()/fbench_done() markers), stages them onto a bootable disk, and runs
each through tools/mame_test/run.py with the fgxdebug plugin's cycle_markers
write-taps.  The plugin captures emu.time() at the $025000/$025002 marker writes
and writes {start_t,done_t,delta_s} per bench.

METRIC: delta_us (emulated microseconds of the hot loop) is the primary,
clock-independent metric — the authoritative baseline-vs-current signal.  The
IIgs runs fast mode under the kernel (~2.2 MHz effective, with memory slowdowns),
and this MAME build exposes no CPU cycle counter, so absolute "cycles" via
time*clock is approximate and NOT comparable to the 1.023 MHz reference numbers.
Track the delta_us change across codegen versions.
"""
import argparse, glob, json, os, pathlib, re, shutil, subprocess, sys

ROOT  = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TC    = os.path.join(ROOT, "toolchain")
FCC   = os.path.join(TC, "fcc")
CDIR  = os.path.join(os.path.dirname(__file__), "corpus")
# The bench links exactly as a fixture does, through fixture_link.py
# (fgx_static), via the test runner's own function: two copies of this
# recipe drifting apart is precisely how a soft-frame mutation once
# survived twice (see run_runtime.build_fcc_bin).
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tests'))
from run_runtime import link_fixture, _LINK_INTERMEDIATES   # noqa: E402

WRAP  = "_wrap_fbench.s"                       # FGX1 wrapper (in corpus/)
BASE_DISK = os.path.join(ROOT, "disk", "fgx.po")
BENCH_DISK_REL = "disk/fbench.po"             # run.py manifest disk_image is REPO-relative
BENCH_DISK = os.path.join(ROOT, BENCH_DISK_REL)
RUN_PY = os.path.join(ROOT, "tools", "mame_test", "run.py")
MAME_TESTS = os.path.join(ROOT, "tools", "mame_test", "tests")
START_HEX, DONE_HEX = "025000", "025002"

def prodos_name(stem):
    """ProDOS-safe: uppercase, alphanumerics only (drop '_'/'.'), <=15, letter-first."""
    s = "".join(c for c in stem.upper() if c.isalnum())
    if s and not s[0].isalpha():
        s = "B" + s
    return s[:15]

def iters_of(cfile):
    m = re.search(r"ITERS=(\d+)", open(cfile).read())
    return int(m.group(1)) if m else 1

def build_fgx1(cfile):
    """fcc + fgx_static link of a bench binary in CDIR.

    Named build_fgx1 for its callers; the FGX1 single-segment wrapper it used
    to drive is obsolete.  fcc collapsed to one mode (P3-2.6): output is always
    FGX2-shaped, every function ends in RTL, and the header fields the old
    wrapper hand-wrote -- fcc_stack_pages, fcc_text, fcc_end -- are no longer
    emitted at all, so _wrap_fbench.s could not assemble and every bench
    reported merlin-fail.  The current recipe is fgx_static, through
    fixture_link.py, and this reuses the test runner's own function so the
    two cannot drift.

    Returns (prodos, path) or (None, reason).
    """
    stem = os.path.splitext(os.path.basename(cfile))[0]
    pro = prodos_name(stem)
    try:
        if subprocess.run([FCC, stem + ".c", "-o", "fcc_output.s"], cwd=CDIR,
                          capture_output=True, text=True).returncode != 0:
            return (None, "fcc-fail")
        out = link_fixture(pathlib.Path(CDIR), ["fbench_markers.s"])
        if out is None:
            return (None, "link-fail")
        dst = os.path.join(CDIR, pro)
        shutil.copy(str(out), dst)
        return (pro, dst)
    finally:
        for f in _LINK_INTERMEDIATES:
            pathlib.Path(CDIR, f).unlink(missing_ok=True)
        shutil.rmtree(os.path.join(CDIR, ".ld"), ignore_errors=True)

def stage_disk(built):
    """Copy the base disk and cadius-ADDFILE every bench into /FGX/BIN."""
    shutil.copy(BASE_DISK, BENCH_DISK)
    stg = "/tmp/fbench_stage"
    if os.path.exists(stg):
        shutil.rmtree(stg)
    os.makedirs(stg)
    info = []
    for pro, path in built:
        shutil.copy(path, os.path.join(stg, pro))
        info.append("%s=Type(06),AuxType(0000),VersionCreate(00),MinVersion(00),Access(C3)" % pro)
    open(os.path.join(stg, "_FileInformation.txt"), "w").write("\n".join(info) + "\n")
    for pro, _ in built:
        if subprocess.run(["cadius", "ADDFILE", BENCH_DISK, "/FGX/BIN",
                           os.path.join(stg, pro)], capture_output=True, text=True).returncode != 0:
            print("  WARN: cadius ADDFILE failed for %s" % pro, file=sys.stderr)

def run_bench(stem, pro, iters):
    """Boot the disk, run the bench under the kernel, return us/call or None."""
    out = "/tmp/fbench_cyc_%s.json" % pro
    if os.path.exists(out):
        os.remove(out)
    mf = os.path.join(MAME_TESTS, "fbench_%s.json" % pro)
    json.dump({
        "name": "fbench_%s" % pro,
        "description": "fbench cycle (kernel): %s" % stem,
        "command": pro.lower(),
        "disk_image": BENCH_DISK_REL,
        # Budget the slowest bench: bubbleSort (O(n^2) + per-iter array reset,
        # unoptimized pointer-indexed access) needs ~75 emulated seconds at
        # v0.14.0 codegen.  The plugin exits early on the DONE marker, so fast
        # benches don't pay this; only a genuinely hung bench waits it out.
        "timeout_s": 150,
        "cycle_markers": {"start_addr_hex": START_HEX, "done_addr_hex": DONE_HEX, "out_path": out},
        "exit_on_prompt": {"sentinel": "fgx:", "count_delta": 1},
    }, open(mf, "w"), indent=2)
    try:
        # run.py's own wall cap ~= boot + timeout_s + slack; wrap it with margin.
        subprocess.run(["python3", RUN_PY, "fbench_%s" % pro, "--no-state", "--headless"],
                       cwd=os.path.join(ROOT, "tools", "mame_test"),
                       capture_output=True, text=True, timeout=240)
    except subprocess.TimeoutExpired:
        return None
    finally:
        if os.path.exists(mf):
            os.remove(mf)
    if not os.path.exists(out):
        return None
    d = json.load(open(out))
    return (d["delta_s"] * 1e6) / iters     # us per call

def check_base_disk_fresh(rebuild=False):
    """Refuse to benchmark against a stale disk/fgx.po.

    THE DISK IS AN INPUT TO THE MEASUREMENT, not just a container.  Each bench
    is staged onto a copy of it and runs under the kernel and libc that disk
    carries, so a disk built from a different compiler than the one under test
    silently measures the wrong thing.

    It is also the harness's most confusing failure.  Rebuilding fcc
    invalidates the whole userland, so a disk left stale by an interrupted or
    forgotten build makes EVERY bench report "no marker / timeout" -- which
    reads as a broken harness rather than a stale input, and cost an hour of
    looking in the wrong place on 2026-08-09.

    Authority is ninja's own dependency graph via a dry run, not an mtime
    comparison: mtimes cannot see that a header changed under a rebuilt fcc.

    Returns None if fresh, or a message describing what is wrong.
    """
    if not shutil.which("ninja"):
        return ("ninja not on PATH -- cannot verify disk/fgx.po is current. "
                "This check is being SKIPPED, not passed: if the disk is stale "
                "every bench will report 'no marker / timeout'.")
    if not os.path.exists(BASE_DISK):
        return "disk/fgx.po does not exist -- run `ninja disk` first."
    r = subprocess.run(["ninja", "-n", "disk"], cwd=ROOT,
                       capture_output=True, text=True)
    if r.returncode != 0:
        return "ninja -n disk failed: " + (r.stderr or r.stdout).strip()[:200]
    if "no work to do" in (r.stdout + r.stderr):
        return None
    pending = [l for l in r.stdout.splitlines() if l.strip()][:3]
    if rebuild:
        print("== disk/fgx.po is stale; rebuilding (--rebuild-disk) ==")
        r2 = subprocess.run(["ninja", "disk"], cwd=ROOT,
                            capture_output=True, text=True)
        if r2.returncode != 0:
            return "ninja disk failed: " + (r2.stderr or r2.stdout).strip()[-300:]
        return None
    return ("disk/fgx.po is STALE -- every bench would report 'no marker / "
            "timeout' and any that did run would be measured against the wrong "
            "kernel.\n  ninja would rebuild, e.g.:\n    "
            + "\n    ".join(pending)
            + "\n  Run `ninja disk`, or pass --rebuild-disk.")


def collect_kernel_cycles(only=None, verbose=True, rebuild_disk=False):
    """Build the corpus benches as FGX1 programs, stage them on a bootable disk,
    run each under the REAL kernel, and return (results, skipped).

      results = {stem: {"us_per_call": float, "iters": int}}
      skipped = [(stem, reason), ...]

    This is the cycle source for fbench (Option B).  The bare-metal Option-A
    path (cycles.py / cycles_collect.py) is unreliable for benches that run
    longer than ~2.5s: it hijacks a still-booting, diskless IIgs whose memory
    soft-switches are in flux, so those benches' stack reads/writes desync and
    the DONE marker never fires.  The kernel boots a stable native-mode env, so
    every bench completes.  Raises RuntimeError if a required tool is missing."""
    for tool in ("merlin32", "cadius"):
        if not shutil.which(tool):
            raise RuntimeError("fbench_kernel: %s not found" % tool)
    # BEFORE any bench is built or staged: a stale base disk invalidates every
    # number this run would produce.
    stale = check_base_disk_fresh(rebuild=rebuild_disk)
    if stale:
        raise RuntimeError("fbench_kernel: " + stale)
    sys.path.insert(0, os.path.dirname(__file__))
    import cycles
    if not cycles.mame_available():
        raise RuntimeError("fbench_kernel: MAME not found (see lib/mame_env.sh)")

    cfiles = sorted(c for c in glob.glob(os.path.join(CDIR, "*.c"))
                   # libc.sel.c is an artefact of the two-segment link
                   # (seg3 archive select), not a benchmark.
                   if os.path.basename(c) != "libc.sel.c"
                    if only is None or os.path.splitext(os.path.basename(c))[0] in only)
    built, skipped, meta = [], [], {}
    if verbose: print("== building FGX1 benches ==")
    for c in cfiles:
        stem = os.path.splitext(os.path.basename(c))[0]
        pro, info = build_fgx1(c)
        if pro is None:
            skipped.append((stem, info))
            if verbose: print("  SKIP %s: %s" % (stem, info))
            continue
        built.append((pro, info)); meta[pro] = {"stem": stem, "iters": iters_of(c)}
        if verbose: print("  built %s -> %s" % (stem, pro))
    results = {}
    if not built:
        return results, skipped
    if verbose: print("== staging %d benches onto %s ==" % (len(built), BENCH_DISK_REL))
    stage_disk(built)
    if verbose: print("== running under the kernel (one cold boot each) ==")
    for i, (pro, _) in enumerate(built, 1):
        stem, iters = meta[pro]["stem"], meta[pro]["iters"]
        uspc = run_bench(stem, pro, iters)
        if uspc is None:
            skipped.append((stem, "no marker / timeout"))
            if verbose: print("  [%d/%d] SKIP %s: no marker" % (i, len(built), stem))
        else:
            results[stem] = {"us_per_call": round(uspc, 3), "iters": iters}
            if verbose: print("  [%d/%d] %s: %.2f us/call" % (i, len(built), stem, uspc))
    return results, skipped

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "reports", "kernel_cycles.json"))
    ap.add_argument("--only", help="comma-separated stems to run (default: all)")
    ap.add_argument("--rebuild-disk", action="store_true",
                    help="rebuild disk/fgx.po if stale instead of refusing to run")
    a = ap.parse_args()
    only = set(a.only.split(",")) if a.only else None
    try:
        results, skipped = collect_kernel_cycles(only=only,
                                                 rebuild_disk=a.rebuild_disk)
    except RuntimeError as e:
        sys.exit(str(e))
    if not results and not skipped:
        sys.exit("no benches built")
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    json.dump({"metric": "us_per_call (emulated; fast-mode; delta is authoritative)",
               "results": results,
               "skipped": [{"stem": s, "why": w} for s, w in skipped]},
              open(a.out, "w"), indent=2)
    print("\n== kernel cycle report (us/call) ==")
    for stem in sorted(results):
        print("  %-14s %8.2f us/call" % (stem, results[stem]["us_per_call"]))
    for s, w in skipped:
        print("  SKIP %-12s %s" % (s, w))
    print("-> %s" % a.out)

if __name__ == "__main__":
    main()
