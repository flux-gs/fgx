#!/usr/bin/env python3
"""flip_sweep.py — the site-flip COVERAGE instrument (task #56, Task 9).

For each PHK/PHB bank-emission site (flip/sites.json): flip it (PHK<->PHB),
rebuild fcc, rebuild + boot the sweep, and record which constructs went P->F.
A site that reds >=1 construct is guarded by it (traceability); a site that reds
NOTHING is an enumerated COVERAGE GAP -> file a new construct.

Writes flip/matrix.json incrementally (partial progress survives a kill) and,
at the end, flip/MATRIX.json-derived summary to stdout.

ALWAYS reverts each flip (try/finally) and rebuilds fcc clean at the end, so the
toolchain source is left pristine even on error/interrupt.

Usage:
  flip_sweep.py [--limit N] [--mode default|noregalloc] [--start K]
"""
import json, os, re, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
MB   = os.path.abspath(os.path.join(HERE, ".."))            # multibank/
TC   = os.path.abspath(os.path.join(MB, "..", ".."))        # toolchain/
REPO = os.path.abspath(os.path.join(TC, ".."))              # repo root
DUMP = "/tmp/fgx_test_mbdiag/dump.txt"
NC   = 19                                                    # constructs 1..19

def sh(args, env=None, cwd=REPO, timeout=None):
    return subprocess.run(args, env=env, cwd=cwd, capture_output=True, text=True, timeout=timeout)

def read_lines(rel):
    with open(os.path.join(TC, rel)) as f: return f.readlines()

def write_lines(rel, lines):
    with open(os.path.join(TC, rel), "w") as f: f.writelines(lines)

def apply_flip(site):
    lines = read_lines(site["file"]); i = site["line"] - 1
    if site["orig"] not in lines[i]:
        raise RuntimeError("anchor drift %s:%d (expected %r)" % (site["file"], site["line"], site["orig"]))
    lines[i] = lines[i].replace(site["orig"], site["flipped"])
    write_lines(site["file"], lines)

def revert_flip(site):
    lines = read_lines(site["file"]); i = site["line"] - 1
    lines[i] = lines[i].replace(site["flipped"], site["orig"])
    write_lines(site["file"], lines)

def build_fcc(env):
    return sh(["make", "-C", TC, "fcc"], env=env, cwd=TC).returncode == 0

def build_sweep(env=None):
    # env carries FCC_NO_REGALLOC for the noregalloc mode: it affects fcc at
    # COMPILE time (when build_sweep.sh runs fcc on the fixtures), not fcc's build.
    r = sh([os.path.join(MB, "build_sweep.sh")], env=env)
    return "BUILD OK" in r.stdout

def boot_vector():
    """Stage multibank.bin, rebuild the sweep disk, boot, return {id:'P'/'F'}."""
    import shutil
    # run_runtime.py rmtree's disk_src/TESTS/FCC on exit, so recreate the dir +
    # _FileInformation.txt each time (else the copy silently fails and we'd read a
    # STALE dump).
    fcc_dir = os.path.join(REPO, "disk_src", "TESTS", "FCC")
    os.makedirs(fcc_dir, exist_ok=True)
    with open(os.path.join(fcc_dir, "_FileInformation.txt"), "w") as f:
        f.write("MBSWEEP=Type(06),AuxType(0000),VersionCreate(00),MinVersion(00),Access(C3)\n")
    shutil.copy(os.path.join(MB, "multibank.bin"), os.path.join(fcc_dir, "MBSWEEP"))
    env = dict(os.environ, DISK_SIZE_OVERRIDE="32MB", DISK_IMAGE_OVERRIDE="disk/fcc_runtime.fs")
    if sh(["./make_disk.sh", "--skip-kernel"], env=env).returncode != 0:
        return {}
    if os.path.exists(DUMP):        # clear stale dump so a failed boot can't return old markers
        os.remove(DUMP)
    try:
        sh(["python3", "tools/mame_test/run.py", "mbdiag", "--headless"], timeout=200)
    except subprocess.TimeoutExpired:
        pass
    screen = open(DUMP).read() if os.path.exists(DUMP) else ""
    return {int(i): r for i, r in re.findall(r'=MBi\s+(\d+)\s+([PF])', screen)}

def outcome(base, vec):
    """Constructs that went P (baseline) -> F/missing (flipped). Missing = red-by-hang.
    Iterates the ACTUAL baseline construct IDs (not a fixed 1..NC) so non-contiguous
    additions like c22..c25 are covered."""
    reds = []
    for c in sorted(base):
        if base.get(c) == 'P' and vec.get(c) != 'P':
            reds.append(c)
    return reds

def main():
    args = sys.argv[1:]
    limit = int(args[args.index("--limit")+1]) if "--limit" in args else None
    start = int(args[args.index("--start")+1]) if "--start" in args else 0
    mode  = args[args.index("--mode")+1] if "--mode" in args else "default"
    env = dict(os.environ)
    if mode == "noregalloc":
        env["FCC_NO_REGALLOC"] = "1"

    sites = json.load(open(os.path.join(HERE, "sites.json")))
    if limit: sites = sites[start:start+limit]
    else:     sites = sites[start:]

    print("== baseline (%s): build fcc + sweep, boot ==" % mode, flush=True)
    if not build_fcc(env):     sys.exit("baseline fcc build FAILED")
    if not build_sweep(env):   sys.exit("baseline sweep build FAILED")
    base = boot_vector()
    ngreen = sum(1 for c in base if base[c] == 'P')
    ntot = len(base)
    print("   baseline green: %d/%d  (constructs %s)" % (ngreen, ntot, sorted(base)), flush=True)
    if ntot == 0 or ngreen != ntot:
        print("   WARNING: baseline not all-green (%r) — reds measured vs this" % base, flush=True)

    matrix_path = os.path.join(HERE, "matrix.json")
    matrix = json.load(open(matrix_path)) if os.path.exists(matrix_path) else {}
    t0 = time.time()
    for k, site in enumerate(sites):
        key = "%s:%d[%s]" % (site["file"].split("/")[-1], site["line"], mode)
        try:
            apply_flip(site)
            if not build_fcc(env):
                rec = {"result": "fcc-build-fail", "reds": []}
            elif not build_sweep(env):
                rec = {"result": "sweep-build-fail", "reds": []}
            else:
                vec = boot_vector()
                reds = outcome(base, vec)
                rec = {"result": "green" if not reds else "red",
                       "reds": reds, "kind": site["kind"]}
        finally:
            revert_flip(site)
        matrix[key] = rec
        json.dump(matrix, open(matrix_path, "w"), indent=2)
        el = time.time() - t0; eta = el / (k+1) * (len(sites) - k - 1)
        print("[%s %2d/%2d] %-34s -> %-14s reds=%s  (ETA %dm)"
              % (mode, k+1, len(sites), key, rec["result"], rec["reds"], eta/60), flush=True)

    print("== rebuild fcc clean ==", flush=True)
    build_fcc(dict(os.environ))
    print("DONE %s: %d sites, %.1f min" % (mode, len(sites), (time.time()-t0)/60), flush=True)
    return 0

if __name__ == "__main__":
    sys.exit(main())
