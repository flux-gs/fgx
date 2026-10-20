"""Relocate runtime bank:offset samples -> symbol/category; render a profile report.

FGX2 gives seg0 (ORG $0B0000, in-bank offset 0) its own runtime bank, so the
loader changes only the bank, never the in-bank offset.  A sampled "BB:OOOO"
therefore maps to the listing by its OOOO offset directly; detect_tool_banks
identifies which runtime bank(s) hold the tool's code (everything else is
kernel/syscall/I-O).
"""
import sys
import json
import argparse
from collections import Counter
from seg0map import SymbolTable, categorize, CATEGORIES

_BANK_THRESH = 0.10   # a bank holding >=10% of samples is treated as a tool code bank


def _parse_key(k):
    parts = k.split(":")
    if len(parts) != 2 or not parts[0] or not parts[1]:
        raise ValueError(f"bad sample key {k!r}: expected 'BANK:OFFSET' hex")
    return int(parts[0], 16), int(parts[1], 16)


def detect_tool_banks(samples, exclude_banks=()):
    exclude = set(exclude_banks)
    by_bank = Counter()
    total = 0
    for k, n in samples.items():
        b, _ = _parse_key(k)
        by_bank[b] += n
        total += n
    if total == 0:
        return set()
    # Strictly greater than the threshold: a borderline non-tool bank (e.g. a
    # kernel/syscall bank at exactly the threshold) is excluded rather than
    # offset-resolved against the single-bank seg0 table.  Banks in
    # exclude_banks (notably the live kernel bank, whose in-bank offsets collide
    # with the tool's seg0 offsets) are never treated as tool banks.
    cands = {b: n for b, n in by_bank.items()
             if b not in exclude and n / total > _BANK_THRESH}
    # AT MOST ONE.  Every candidate would be resolved by in-bank OFFSET against
    # the SAME single-bank seg0 table, so a second bank -- the shared libc pile
    # in its own bank is the one that actually happens -- gets its samples
    # relabelled with whatever seg0 symbol sits at the same offset.  Pile
    # offsets are small, so they all "resolve", and `lookup`'s out-of-range
    # guard never fires.  That is fabricated attribution with no warning, so
    # keep the largest and say plainly what was dropped.
    if not cands:
        # Nothing cleared the bar.  That is the normal shape for an I/O-bound
        # workload, where the tool's own bank is a small slice -- one measured
        # run had the tool at 8.3% while idle and firmware took 60%.  Say which
        # bank was closest so the caller can pass it rather than reading a
        # report that is 100% kernel_io.
        rest = {b: n for b, n in by_bank.items() if b not in exclude}
        if rest:
            b = max(rest, key=lambda k: rest[k])
            print(f"  WARNING: no bank holds more than {100 * _BANK_THRESH:.0f}% of "
                  f"samples, so NOTHING is resolved against the listing and the "
                  f"report will read 100% kernel_io.  The largest candidate is "
                  f"{hex(b)} at {100.0 * rest[b] / total:.1f}% -- pass "
                  f"--tool-banks {b:02x} if that is the tool's code bank.")
        return set()
    if len(cands) > 1:
        keep = max(cands, key=lambda b: cands[b])
        for b, n in sorted(cands.items(), key=lambda kv: -kv[1]):
            if b != keep:
                print(f"  WARNING: bank {hex(b)} holds {100.0 * n / total:.1f}% of "
                      f"samples but is NOT the tool's code bank; its samples stay "
                      f"in kernel_io rather than being resolved against the seg0 "
                      f"listing.  If this is the tool's code, pass --tool-banks.")
        return {keep}
    return set(cands)


def build_profile(samples, st, tool_banks):
    cats = Counter()
    syms = Counter()
    total = 0
    for k, n in samples.items():
        b, off = _parse_key(k)
        total += n
        in_tool = b in tool_banks
        sym = st.lookup(off) if in_tool else None
        cats[categorize(sym, in_tool)] += n
        syms[(sym.symbol if sym else f"bank{b:02X}")] += n
    return {"by_category": {c: cats.get(c, 0) for c in CATEGORIES},
            "by_symbol": syms.most_common(25), "total": total}


def render_report(profiles, meta):
    L = [f"# fcc real-world profile — {meta.get('date', '')}", ""]
    for tool, (prof, tmeta) in profiles.items():
        t = prof["total"] or 1
        L += [f"## {tool}  (wall {tmeta.get('wall_s', '?')} s, {prof['total']} samples)", ""]
        if prof["total"] < 600:
            L += [f"> ⚠ thin run ({prof['total']} samples) — category ranking may be "
                  f"statistically noisy; lengthen the workload.", ""]
        L += ["| category | % |", "|---|---|"]
        for c in CATEGORIES:
            L.append(f"| {c} | {prof['by_category'].get(c, 0) * 100.0 / t:.1f}% |")
        L += ["", "| symbol | % |", "|---|---|"]
        for s, n in prof["by_symbol"]:
            L.append(f"| {s} | {n * 100.0 / t:.1f}% |")
        L.append("")
    return "\n".join(L)


def _load_samples(path):
    sj = json.load(open(path))
    samples = sj.get("samples")
    if not isinstance(samples, dict):
        raise ValueError(f"{path}: missing or non-dict 'samples' key")
    for k, n in samples.items():
        if not isinstance(n, int) or n < 0:
            raise ValueError(f"{path}: sample count for {k!r} must be a non-negative int, got {n!r}")
    return sj, samples


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--samples", required=True, help="pc_samples.json from the plugin")
    ap.add_argument("--listing", required=True, help="build/userbin_<tool>_seg0_Output.txt")
    ap.add_argument("--tool", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--tool-banks", default=None,
                    help="comma-separated hex runtime bank(s) to force as the tool's code "
                         "bank(s); default = auto-detect the dominant bank(s)")
    a = ap.parse_args(argv)
    sj, samples = _load_samples(a.samples)
    meta = {"wall_s": sj.get("wall_s")}
    st = SymbolTable.from_listing(a.listing)
    kbank = sj.get("kernel_bank")
    if a.tool_banks:
        banks = {int(x, 16) for x in a.tool_banks.split(",") if x.strip()}
    else:
        # Exclude the live kernel bank: its in-bank offsets collide with the
        # tool's seg0 offsets and would otherwise be mis-attributed to the tool.
        # Exclude bank 0 for the same reason and a stronger one: it holds the
        # stack, the direct page and the slot/ROM firmware, never a tool's code
        # (FGX2 images load into pool banks), and on an I/O-bound workload it
        # readily clears the 10% threshold -- SmartPort reads alone were 12.4%
        # of one measured run, against 8.3% for the tool's real bank.
        _excl = {0}
        if kbank is not None:
            _excl.add(kbank)
        banks = detect_tool_banks(samples, exclude_banks=_excl)
        if kbank is not None:
            print(f"(excluded kernel_bank={hex(kbank)} from tool-bank detection)")
    prof = build_profile(samples, st, banks)
    open(a.out, "w").write(render_report({a.tool: (prof, meta)}, {"date": "2026-06-28"}))
    total = prof["total"]
    wall = sj.get("wall_s")
    print(f"tool_banks={sorted(hex(b) for b in banks)} total={total} wall_s={wall}")
    # A run that sampled NOTHING renders an all-0.0% report that is
    # indistinguishable from a flat profile, so it fails rather than warns.
    if not total:
        print("  ERROR: the sampler produced NO samples (total=0).  This report says "
              "nothing about where time went; it is the instrument failing, not a "
              "flat profile.  Check that pc_sample was enabled and that the run "
              "reached the armed window.")
        return 2
    if total < 600 or (wall or 0) < 10:
        print(f"  WARNING: thin run (total={total}, wall_s={wall}) -- category ranking may "
              f"be statistically noisy; lengthen the workload.")
    # Samples inside a tool bank that did not resolve to a symbol (wrong bank or
    # past the listing's end) land in 'unknown'; a large share signals a
    # bank/listing mismatch.
    unresolved = prof["by_category"]["unknown"]
    if unresolved and unresolved * 100.0 / (total or 1) > 5.0:
        print(f"  WARNING: {unresolved} samples ({unresolved * 100.0 / (total or 1):.1f}%) in a "
              f"tool bank did not resolve to a symbol -- check --tool-banks / --listing.")
    for c in CATEGORIES:
        print(f"  {c:18} {prof['by_category'][c] * 100.0 / (total or 1):5.1f}%")


if __name__ == "__main__":
    sys.exit(main() or 0)
