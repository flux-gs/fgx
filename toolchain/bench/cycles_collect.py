#!/usr/bin/env python3
"""collect_cycles() — bare-metal (Option A) cycle collector.  DEPRECATED as
fbench's cycle source: it hijacks a still-booting, diskless IIgs at $1000, whose
memory soft-switches are in flux, so any bench running >~2.5s desyncs its stack
and never fires the DONE marker (only the short t12_* benches survive).  fbench
now sources cycles from fbench_kernel.collect_kernel_cycles() (Option B — runs
each bench under the real FGX kernel; all corpus benches complete).  Kept for the
short-bench bare-metal path and reference; not wired into fbench snapshot/compare.

build every corpus bench (fcc + merlin32); measure cycles if MAME is present,
otherwise record build-ok with cyc_per_call=None.  Every bench is either reported
(build ok / cyc measured) or SKIP'd with an explicit reason.  Nothing is dropped
silently."""
import os, re, glob, json, subprocess, shutil, cycles

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TC   = os.path.join(ROOT, "toolchain")
CDIR = os.path.join(os.path.dirname(__file__), "corpus")

def _iters(src):
    """Parse /* ITERS=N */ from source; default 2000."""
    try:
        m = re.search(r"ITERS=(\d+)", open(src).read())
        return int(m.group(1)) if m else 2000
    except OSError:
        return 2000

def collect_cycles():
    out, skipped = {}, []
    refs_path = os.path.join(CDIR, "refs.json")
    refs = {}
    if os.path.exists(refs_path):
        try:
            refs = json.load(open(refs_path))
        except (OSError, json.JSONDecodeError):
            pass

    fcc_bin   = os.path.join(TC, "fcc")
    have_m32  = shutil.which("merlin32") is not None
    have_mame = cycles.mame_available()   # FGX-resolved (Ample mame64 / $MAME), not bare "mame" on PATH

    if not have_m32:
        print("fbench: merlin32 absent — cannot build corpus; cycles UNMEASURED")
        return out

    if not have_mame:
        print("fbench: mame absent — building corpus for validation only; "
              "cyc_per_call will be None (run on a machine with MAME for live numbers)")

    for c in sorted(glob.glob(os.path.join(CDIR, "*.c"))):
        name = os.path.splitext(os.path.basename(c))[0]
        link = os.path.join(CDIR, name + ".link.s")

        if not os.path.exists(link):
            skipped.append((name, "no .link.s"))
            continue

        # --- Step 1: fcc compile ---
        r = subprocess.run(
            [fcc_bin, name + ".c", "-o", "fcc_output.s"],
            cwd=CDIR, capture_output=True, text=True)
        if r.returncode != 0:
            err = (r.stderr or r.stdout or "").strip().split("\n")[0]
            skipped.append((name, "fcc-fail: " + err))
            continue

        # --- Step 2: merlin32 assemble ---
        r2 = subprocess.run(
            ["merlin32", name + ".link.s"],
            cwd=CDIR, capture_output=True, text=True)
        if r2.returncode != 0:
            err2 = (r2.stderr or r2.stdout or "").strip().split("\n")[0]
            skipped.append((name, "merlin-fail: " + err2))
            continue

        it = _iters(c)
        if it <= 0:                       # malformed /* ITERS=N */ — never divide by it
            skipped.append((name, "bad ITERS=%d (must be > 0)" % it))
            continue
        ref = refs.get(name, {})

        # --- Step 3 (optional): MAME cycle measurement ---
        if not have_mame:
            out[name] = {
                "cyc_per_call": None,
                "build": "ok",
                "calypsi":  ref.get("calypsi"),
                "llvm_mos": ref.get("llvm_mos"),
            }
            print(f"  bench {name}: build ok — cyc UNMEASURED (MAME absent), iters {it}")
        else:
            total = cycles.run_binary(os.path.join(CDIR, name))
            if total is None:
                # Built fine but DONE marker never fired (main hung/crashed in the
                # bare-metal env, or exceeded -seconds_to_run). RECORD it (cyc=None
                # + reason) so the baseline is self-documenting — never drop silently.
                skipped.append((name, "no markers / timeout (built ok; main did not reach DONE)"))
                out[name] = {
                    "cyc_per_call": None,
                    "build": "ok",
                    "skip": "no-markers (bare-metal hang/timeout)",
                    "calypsi":  ref.get("calypsi"),
                    "llvm_mos": ref.get("llvm_mos"),
                }
                continue
            out[name] = {
                "cyc_per_call": total / it,
                "build": "ok",
                "calypsi":  ref.get("calypsi"),
                "llvm_mos": ref.get("llvm_mos"),
            }
            print(f"  bench {name}: {total/it:.1f} cyc/call "
                  f"(total {total:.0f}, iters {it})")

    for n, why in skipped:
        print(f"  SKIP {n}: {why}")

    return out
