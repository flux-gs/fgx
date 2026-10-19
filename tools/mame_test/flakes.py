#!/usr/bin/env python3
"""flakes.py -- turn "that test is flaky" into a RATE, out of evidence already
on disk (apple/fgx#262).

`run.py` journals every result to results.jsonl as {test, key, ok, ts}, and the
KEY is the fingerprint of everything the test consumes: disk image, manifest,
staged files, check_script, harness env.  So a key that has been seen BOTH green
and red is a test that gave two answers to identical inputs, which is the
definition of a flake and not a matter of opinion.

WHY THE KEY AND NOT THE FAIL COUNT.  Raw fail counts are dominated by tests
being WRITTEN -- a fixture is red until it works, and that is not flakiness.
Grouping by key removes almost all of it: a test under development changes its
inputs, so each red lands on its own key and never flips one.

WHAT IT CANNOT SEE.  The key covers the test's inputs, not the host: a red
caused by a stale MAME, a busy machine or a serial peer that never bound looks
exactly like a red caused by the guest.  A flip is therefore evidence that the
result is not a function of the inputs alone -- it does not say which side of
the emulator the cause is on.
"""
import argparse, collections, json, sys, time
from pathlib import Path

JOURNAL = Path(__file__).resolve().parent / "results.jsonl"


def load(path, days=None):
    cut = 0 if days is None else time.time() - days * 86400
    out = []
    for line in Path(path).read_text().splitlines():
        if not line.strip():
            continue
        try:
            r = json.loads(line)
        except ValueError:
            continue                      # a torn line is not a reason to stop
        if r.get("ts", 0) >= cut:
            out.append(r)
    return out


def tally(recs):
    """(test, key) -> [greens, reds]"""
    byk = collections.defaultdict(lambda: [0, 0])
    for r in recs:
        byk[(r["test"], r["key"])][0 if r["ok"] else 1] += 1
    return byk


def report(byk, min_runs=2):
    rows = []
    seen = collections.Counter()
    flip = collections.Counter()
    reds = collections.Counter()
    for (t, _k), (g, r) in byk.items():
        if g + r >= min_runs:
            seen[t] += 1
            if g and r:
                flip[t] += 1
                reds[t] += r
    for t in seen:
        rows.append((flip[t] / seen[t] if seen[t] else 0.0, t, seen[t], flip[t], reds[t]))
    rows.sort(reverse=True)
    return rows, sum(seen.values()), sum(flip.values())


def selftest():
    """A rate that cannot come out wrong is not a measurement.  Feed it a corpus
    whose answer is known by construction: one true flake, one test that was
    merely broken and then fixed (inputs changed, so no key flips), and one that
    is simply always green."""
    recs = [
        {"test": "flaky",  "key": "K", "ok": True,  "ts": 1},
        {"test": "flaky",  "key": "K", "ok": False, "ts": 2},
        {"test": "fixed",  "key": "A", "ok": False, "ts": 1},
        {"test": "fixed",  "key": "A", "ok": False, "ts": 2},
        {"test": "fixed",  "key": "B", "ok": True,  "ts": 3},
        {"test": "solid",  "key": "S", "ok": True,  "ts": 1},
        {"test": "solid",  "key": "S", "ok": True,  "ts": 2},
    ]
    rows, pairs, flips = report(tally(recs))
    got = {t: (n, f) for _r, t, n, f, _x in rows}
    assert flips == 1, f"expected exactly one flipped key, got {flips}"
    assert got["flaky"] == (1, 1), got
    assert got["fixed"] == (1, 0), got     # red-then-red on A, and B ran once
    assert got["solid"] == (1, 0), got
    # and it must be able to say NO: a corpus with no flip must report none.
    _rows, _p, f2 = report(tally([r for r in recs if r["test"] != "flaky"]))
    assert f2 == 0, f"a clean corpus must report zero flips, got {f2}"
    print("flakes.py: self-test OK")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--days", type=int, default=None,
                    help="only consider results from the last N days")
    ap.add_argument("--journal", default=str(JOURNAL))
    ap.add_argument("--test", action="append",
                    help="restrict to these test names (repeatable)")
    ap.add_argument("--min-runs", type=int, default=2,
                    help="ignore keys run fewer than this many times (default 2)")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        selftest()
        return 0
    recs = load(a.journal, a.days)
    if a.test:
        want = set(a.test)
        recs = [r for r in recs if r["test"] in want]
    if not recs:
        print("no results in that window -- nothing measured, which is not "
              "the same as nothing wrong", file=sys.stderr)
        return 2
    byk = tally(recs)
    rows, pairs, flips = report(byk, a.min_runs)
    span = (time.strftime('%Y-%m-%d', time.localtime(min(r['ts'] for r in recs))),
            time.strftime('%Y-%m-%d', time.localtime(max(r['ts'] for r in recs))))
    print(f"{len(recs)} results, {span[0]} .. {span[1]}")
    print(f"{pairs} input-identical keys run {a.min_runs}+ times; "
          f"{flips} gave both answers ({flips/pairs:.1%} overall)" if pairs
          else "no key was run twice -- no flake can be seen from here")
    if not pairs:
        return 0
    print(f"\n{'test':<22}{'repeated keys':>14}{'flipped':>9}{'rate':>8}{'reds':>7}")
    for rate, t, n, f, r in rows:
        if f:
            print(f"{t:<22}{n:>14}{f:>9}{rate:>8.0%}{r:>7}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
