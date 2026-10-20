#!/usr/bin/env python3
"""fbench — fcc benchmarking harness (size/system/dp now; cycles via cycles.py)."""
import argparse, json, os, subprocess, sys, glob

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TC   = os.path.join(ROOT, "toolchain")
# fcc-built userland binaries we attribute to codegen (explicit, deterministic).
FCC_USERLAND = ["sed", "ed", "grep", "tr", "od", "more", "man"]   # extend as ported

def _git_sha(path):
    try:
        return subprocess.check_output(["git", "-C", path, "rev-parse", "HEAD"],
                                       text=True).strip()
    except Exception:
        return "unknown"

def _git_dirty(path):
    try:
        return bool(subprocess.check_output(["git","-C",path,"status","--porcelain"],
                                            text=True).strip())
    except Exception:
        return False

def collect_size():
    per, tb, tl = {}, 0, 0
    for b in sorted(glob.glob(os.path.join(TC, "tests", "**", "*.expected.bin"), recursive=True)):
        rel = os.path.relpath(b, ROOT); nb = os.path.getsize(b)
        s = b[:-len(".expected.bin")] + ".expected.s"; nl = 0
        if os.path.exists(s):
            with open(s, errors="replace") as f:
                nl = sum(1 for ln in f if ln.strip() and not ln.lstrip().startswith((";","*")))
        per[rel] = {"bytes": nb, "lines": nl}; tb += nb; tl += nl
    return {"goldens": {"total_bytes": tb, "total_asm_lines": tl, "per_fixture": per}}

def collect_system():
    kb = os.path.getsize(os.path.join(ROOT,"bin","fgx.bin")) if \
         os.path.exists(os.path.join(ROOT,"bin","fgx.bin")) else 0
    # fcc-built userland only: explicit list, not a wildcard over disk_src (which
    # is regenerated per build and contains hand-asm tools/fonts/manpages).
    ub = 0
    for tool in FCC_USERLAND:
        for cand in (os.path.join(ROOT,"bin",tool+".bin"), os.path.join(ROOT,"bin",tool)):
            if os.path.exists(cand): ub += os.path.getsize(cand); break
    return {"kernel_bytes": kb, "fcc_userland_bytes": ub}

def _snap(tag, with_cycles=True):
    import fbench_kernel, dp_collect
    # Cycles: Option B (real FGX kernel).  The bare-metal Option-A harness
    # (cycles_collect) is unreliable for benches running >~2.5s — it hijacks a
    # still-booting, diskless IIgs whose memory soft-switches are in flux, so
    # those benches' stack accesses desync and the DONE marker never fires.  The
    # kernel boots a stable native-mode env, so every corpus bench completes.
    # Metric is us_per_call (emulated; the baseline-vs-current DELTA on the same
    # harness is the authoritative signal — this MAME build exposes no cycle
    # counter, so absolute "cycles" via time*clock would be approximate).
    #
    # Cycle collection cold-boots MAME once per bench (~30s each), so it is gated
    # by with_cycles (size-only snapshots and the unit test pass --no-cycles).
    # It degrades gracefully (warn + empty) when merlin32/cadius/MAME are absent,
    # so size/provenance snapshots still work on a CI box without an emulator.
    kc_results, kc_skipped = {}, []
    if with_cycles:
        try:
            kc_results, kc_skipped = fbench_kernel.collect_kernel_cycles()
        except RuntimeError as e:
            print(f"fbench: cycles UNMEASURED — {e}")
    return {"tag": tag,
            "toolchain_git": _git_sha(TC) + ("-dirty" if _git_dirty(TC) else ""),
            "fgx_git": _git_sha(ROOT),
            "size": collect_size(), "system": collect_system(),
            "dp": dp_collect.collect_dp(),
            "cycles": kc_results,
            "cycles_skipped": [{"stem": s, "why": w} for s, w in kc_skipped]}

def snapshot(tag, out, with_cycles=True):
    snap = _snap(tag, with_cycles=with_cycles)
    d = os.path.dirname(out)
    if d: os.makedirs(d, exist_ok=True)            # fresh-tree safe
    with open(out, "w") as f: json.dump(snap, f, indent=2)
    g = snap["size"]["goldens"]
    print(f"snapshot '{tag}': {len(g['per_fixture'])} fixtures, {g['total_bytes']} bytes, "
          f"{g['total_asm_lines']} asm lines, {len(snap['cycles'])} benches -> {out}")
    return snap

def _pct(d, b): return (d*100.0/b) if b else 0.0

def compare(base_path, with_cycles=True):
    with open(base_path) as f: base = json.load(f)
    cur = _snap("current", with_cycles=with_cycles)
    # SIZE
    bg, cg = base["size"]["goldens"], cur["size"]["goldens"]
    db = cg["total_bytes"]-bg["total_bytes"]; dl = cg["total_asm_lines"]-bg["total_asm_lines"]
    print(f"size bytes: {bg['total_bytes']} -> {cg['total_bytes']} ({db:+d}, {_pct(db,bg['total_bytes']):+.2f}%)")
    print(f"asm lines:  {bg['total_asm_lines']} -> {cg['total_asm_lines']} ({dl:+d}, {_pct(dl,bg['total_asm_lines']):+.2f}%)")
    # SYSTEM
    for k in ("kernel_bytes","fcc_userland_bytes"):
        ob,nb = base["system"].get(k,0), cur["system"].get(k,0)
        print(f"{k}: {ob} -> {nb} ({nb-ob:+d}, {_pct(nb-ob,ob):+.2f}%)")
    # DP
    print(f"dp fcc_bytes: {base['dp']['fcc_bytes']} -> {cur['dp']['fcc_bytes']}  "
          f"overlaps: {len(cur['dp']['overlaps'])}")
    # CYCLES (headline) — kernel us/call (Option B). Older baselines stored
    # bare-metal cyc_per_call; fall back to it so cross-format compares don't crash.
    print("cycles (us/call, kernel):")
    def _cyc(d): return d.get("us_per_call", d.get("cyc_per_call"))
    for n in sorted(set(base["cycles"]) | set(cur["cycles"])):
        ob = _cyc(base["cycles"].get(n,{}))
        nb = _cyc(cur["cycles"].get(n,{}))
        if ob is None or nb is None:
            print(f"  {n}: {ob} -> {nb} (incomplete)"); continue
        print(f"  {n}: {ob:.1f} -> {nb:.1f} ({nb-ob:+.1f}, {_pct(nb-ob,ob):+.2f}%)")

def main():
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("snapshot"); s.add_argument("tag"); s.add_argument("--out")
    s.add_argument("--no-cycles", action="store_true",
                   help="size/system/dp only; skip the (slow) per-bench kernel cycle runs")
    c = sub.add_parser("compare"); c.add_argument("base")
    c.add_argument("--no-cycles", action="store_true", help="skip cycle measurement")
    sub.add_parser("report")
    a = ap.parse_args()
    if a.cmd == "snapshot":
        snapshot(a.tag, a.out or os.path.join(os.path.dirname(__file__),"baselines",a.tag+".json"),
                 with_cycles=not a.no_cycles)
    elif a.cmd == "compare":
        compare(a.base, with_cycles=not a.no_cycles)
    elif a.cmd == "report":
        snap = snapshot("report", os.path.join(os.path.dirname(__file__),"reports","latest.json"),
                        with_cycles=False)
        import scoreboard; scoreboard.print_scoreboard(snap)

if __name__ == "__main__":
    main()
