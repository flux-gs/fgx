#!/usr/bin/env python3
"""P3-3 #42 pad calibration — reduce the stack_excursion dumps to the numbers
that decide DEFAULT_PAD / FCC_STK_FLOOR_MARGIN.

For each user task (DP $B1xx..$BFxx) the fgxdebug stack_excursion tap recorded:
  max_e   = max(_fcc_fb-1-S)  — deepest non-C push below the live C frame base
            (hand-asm libc / IRQ frame / signal trampoline; the pad's job)
  min_s   = absolute deepest S (all causes, fb-independent)
  max_s   = shallowest S seen (~= initial S = saved_S+4, top of usable stack)
  floor   = kernel-seeded _fcc_stkfloor = StackBase + FCC_STK_FLOOR_MARGIN(128)

Derived: StackBase = floor-128; StackSize = max(pages,1)*256 (static, per binary);
  argv frame T = (StackBase+StackSize) - max_s; headroom_to_base = min_s-StackBase;
  headroom_to_floor = min_s-floor; consumption = max_s-min_s.
"""
import json, sys, os

MARGIN = 128
# static pages per binary (stack_measure); floored recursive binaries = 32.
PAGES = {"pfwidth": 0, "ed": 32, "sed": 32, "jsh": 32, "cat": 0,
         "sigtest": 2, "ntpplay": None}
# which pids each workload's dump is expected to contain (for labelling only)
LABEL = {  # dp-page pid -> best-guess binary, per workload
  "stkpad_pf":   {2: "jsh", 3: "pfwidth"},
  "stkpad_ed":   {2: "jsh", 3: "cat", 4: "ed"},
  "stkpad_sed":  {2: "jsh", 3: "sed"},
  "stkpad_jsh":  {2: "jsh", 3: "?"},
  "stkpad_sig":  {2: "jsh", 3: "sigtest"},
  "stkpad_irqc": {2: "jsh", 3: "cat", 4: "ed"},
}

def sz(binname):
    p = PAGES.get(binname)
    return (max(p, 1) * 256) if p is not None else None

def main():
    names = sys.argv[1:] or list(LABEL)
    print(f"{'workload':13} {'pid/bin':12} {'max_e':>5} {'minS':>6} {'maxS':>6} "
          f"{'floor':>6} {'base':>6} {'T':>5} {'used':>5} {'h→base':>7} {'h→floor':>8} "
          f"{'e@':>10} hits")
    worst_e = 0
    for name in names:
        dp_path = f"/tmp/fgx_test_{name}/dump.json"
        if not os.path.exists(dp_path):
            print(f"{name:13} NO DUMP"); continue
        d = json.load(open(dp_path))
        for t in sorted(d.get("stack_excursion") or [], key=lambda x: x["dp"]):
            pid = (t["dp"] >> 8) - 0xB0
            binn = LABEL.get(name, {}).get(pid, "?")
            floor = t.get("floor") or 0
            base = floor - MARGIN if floor else 0
            ss = sz(binn)
            top = (base + ss) if (base and ss) else None
            T = (top - t["max_s"]) if (top and t["max_s"] >= 0) else None
            hb = (t["min_s"] - base) if base else None
            hf = (t["min_s"] - floor) if floor else None
            used = (t["max_s"] - t["min_s"]) if t["max_s"] >= 0 else None
            e = t["max_e"]
            worst_e = max(worst_e, e)   # headline worst INCLUDES the jsh shell
            def h(x): return f"${x:04X}" if isinstance(x, int) and x >= 0 else "  -"
            print(f"{name:13} p{pid}/{binn:10} {e:5d} {h(t['min_s'])} {h(t['max_s'])} "
                  f"{h(floor)} {h(base)} {(str(T) if T is not None else '-'):>5} "
                  f"{(str(used) if used is not None else '-'):>5} "
                  f"{(str(hb) if hb is not None else '-'):>7} "
                  f"{(str(hf) if hf is not None else '-'):>8} "
                  f"${t.get('e_pb',0):02X}:{t.get('e_pc',0):04X} {t['hits']}")
    print(f"\nWORST max_e across all user tasks: {worst_e} B   (DEFAULT_PAD={128})")

if __name__ == "__main__":
    main()
