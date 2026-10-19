#!/usr/bin/env python3
"""Aggregate fcc2 Phase-3 increment-0 measurement lines into a ranked
spill/reload byte table + floor/ceiling brackets.

Input: the stderr of a userland build run with FCC_P3_STATS=1, whose lines look
like  `fcc-p3\\t<func>\\t<key>\\t<count>\\t<bytes>`  (other stderr is ignored).

  floor   = removable reload bytes the global allocator could take with the
            CURRENT clean-BB coverage (within-BB + a register provably free).
  ceiling = total incremental spill/reload mass (any A-clobbered no-redef
            reload), assuming full barrier coverage + unlimited DP-IMG spill.
  ceiling - floor = the bytes GATED ON coverage co-evolution (see the L5 rows).

With --code-bytes N (total userland seg0 CODE bytes) it prints floor%/ceiling%
against N and flags the >=15% size-band DoD line.
"""
import sys, argparse, collections

# Keys whose `bytes` column is the removable-byte aggregate (avoid double count:
# L1/L2/L5 rows carry COUNTS only; floor/ceil/L3/storedrop carry the bytes).
BYTE_KEYS = {"floor", "ceil", "L3_leafmiss", "L3_complex", "L1_storedrop"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stats", default="-", help="stats file ('-' = stdin)")
    ap.add_argument("--code-bytes", type=int, default=0,
                    help="total userland seg0 code bytes (denominator for %)")
    a = ap.parse_args()

    f = sys.stdin if a.stats == "-" else open(a.stats)
    cnt = collections.Counter()
    byt = collections.Counter()
    nfn = 0
    for ln in f:
        p = ln.rstrip("\n").split("\t")
        if len(p) != 5 or p[0] != "fcc-p3":
            continue
        if p[2] == "fn":
            nfn += 1
            continue
        cnt[p[2]] += int(p[3])
        byt[p[2]] += int(p[4])

    print(f"functions measured: {nfn}\n")
    print(f"{'key':16} {'count':>8} {'bytes':>8}  note")
    notes = {
        "floor": "allocator-reachable NOW (within-BB, reg free)",
        "ceil": "total incremental spill/reload (full coverage)",
        "L3_complex": "binop stash, structurally irreducible (no ADC reg)",
        "L3_leafmiss": "binop stash, FOLD-reachable (ir_select coverage)",
        "L1_storedrop": "the STA also drops (reload is sole reader)",
        "L4_ovf": "surviving PHA == TAX bytes -> NOT a size lever",
    }
    for k in ("floor", "ceil"):
        print(f"{k:16} {cnt[k]:>8} {byt[k]:>8}  {notes.get(k,'')}")
    print()
    rest = sorted((k for k in set(cnt) | set(byt) if k not in ("floor", "ceil")),
                  key=lambda k: (-byt[k], -cnt[k], k))
    for k in rest:
        tag = notes.get(k, "")
        if k.startswith("L1_xbar_") or k.startswith("L5_sand_"):
            tag = "coverage opportunity (bytes are in floor/ceil)"
        print(f"{k:16} {cnt[k]:>8} {byt[k]:>8}  {tag}")

    fb, cb = byt["floor"], byt["ceil"]
    print(f"\nFLOOR   = {fb} bytes")
    print(f"CEILING = {cb} bytes")
    print(f"coverage-gated gap (ceil-floor) = {cb - fb} bytes")
    if a.code_bytes:
        fp, cp = 100.0 * fb / a.code_bytes, 100.0 * cb / a.code_bytes
        print(f"\nvs {a.code_bytes} userland code bytes:")
        print(f"  floor%   = {fp:5.2f}%")
        print(f"  ceiling% = {cp:5.2f}%   (>=15% size-band DoD? "
              f"{'YES' if cp >= 15 else 'NO'})")


if __name__ == "__main__":
    main()
