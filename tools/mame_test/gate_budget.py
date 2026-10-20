#!/usr/bin/env python3
"""The gate's test corpus has a TIME BUDGET, and this is what enforces it.

WHY THIS EXISTS.  On 2026-07-29 the ~310-manifest MAME suite was deleted
outright (commit 2bbf4cca3) and replaced with one smoke test, because its cost
had stopped buying anything.  Thirty-nine days later there were 268 manifests
again and 81 of them in `GATE_TESTS'.  The regrowth was not a decision: 282 of
the 337 additions rode in on commits that were about `src/' or the toolchain,
one regression test at a time, each of them locally reasonable.

The bar that was supposed to stop it -- the four questions in docs/testing.md --
is a PER-TEST gate, and the cost it needs to catch is PER-CORPUS.  Question 3
asks "does its cost scale with the corpus or with the change", which no single
test can ever answer wrongly: every manifest is cheap on its own.  So the bar
was applied 337 times, passed 337 times, and the corpus still reached three and
a half hours of declared budget.  A per-test question cannot bound a sum.  This
can, because it looks at the sum.

WHAT IT MEASURES, AND WHY THAT NUMBER.  The budget is the sum of each gate
test's declared `timeout_s'.  That is a worst case, not a stopwatch reading --
the gate wall-clocks well under it, four-way parallel -- and the worst case is
deliberately the right meter for a budget:

  - it is ALREADY DECLARED in every manifest, so nothing new has to be
    instrumented, journalled or kept honest across machines;
  - it does not drift with machine load, parallelism or a cold cache, so the
    number means the same thing in two different checkouts;
  - it prices what the gate has actually AGREED TO WAIT FOR, which is the thing
    that turns into an afternoon when a test wedges;
  - and it makes a lazy timeout cost real budget, which is the pressure that
    was missing.

RATCHET, NOT A CAP.  BUDGET_S only ever goes DOWN.  Removing tests is what buys
headroom, and a deletion commit lowers the ceiling by what it freed in the same
commit -- otherwise the slack just refills.  Raising it is a decision someone
makes on purpose, in a commit that says why, not something that happens because
a test was added.
"""

import json
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

# THE RATCHET.  Set 2026-09-07 to 12,975s (80 gate tests, the corpus as it
# stood), then lowered the same day to 6,365s when the closed-defect manifests
# left and the gate went to 46, to 6,165s when logintest and the serial
# witnesses followed, and to 6,015s when manpty went.  Lower it whenever tests
# leave; never raise it silently.
#
# RAISED to 6,105s on 2026-09-20, by 90s, for `unixdgram' -- deliberately, with
# the alternative measured rather than assumed.  AF_UNIX SOCK_DGRAM is a new
# subsystem that syslog(3) now depends on, and NOTHING among the 44 cases
# duplicates any part of it, so every retiree that could have paid for it was a
# straight trade of new coverage for old.  The three exact-fit candidates were
# statenoent, czcorrupt and coninv, and each is the only case watching what it
# watches.  The 90s is already the tight number: the fixture passes at a 40s cap
# and 90 is margin, not requirement.
BUDGET_S = 6105


def gate_tests(gate_sh):
    """The names in GATE_TESTS, as the shell would split them.

    The assignment is a double-quoted string continued over a dozen lines, and
    inside double quotes a backslash-newline is a line continuation that bash
    removes -- so the shell never sees the backslashes and neither do we.
    Reading the file as text does see them, and a regex that forgets this
    happily reports thirteen tests named `\\'.
    """
    m = re.search(r'^GATE_TESTS="(.*?)"', gate_sh, re.S | re.M)
    if not m:
        return None
    return m.group(1).replace("\\\n", " ").split()


def audit(root):
    """Return (findings, total_s, names).  A finding is a human-readable line."""
    gate_path = os.path.join(root, "tools", "gate.sh")
    tests_dir = os.path.join(root, "tools", "mame_test", "tests")
    try:
        src = open(gate_path).read()
    except IOError:
        return (["cannot read %s" % gate_path], 0, [], (0, 0))

    names = gate_tests(src)
    if names is None:
        return (["no GATE_TESTS assignment in %s" % gate_path], 0, [], (0, 0))

    findings = []
    total = 0
    for n in names:
        path = os.path.join(tests_dir, n + ".json")
        if not os.path.exists(path):
            # A gate test with no manifest is not a slow gate, it is a DEAD
            # one: run.py fatals on an unknown name (run.py:2692), so the whole
            # test step refuses to start.  That is how `nodevboot' broke the
            # gate on 2026-09-05 and sat unnoticed -- the manifest was deleted
            # and the name was left behind.
            findings.append("%s: in GATE_TESTS, no manifest (run.py will fatal)"
                            % n)
            continue
        try:
            j = json.load(open(path))
        except ValueError as e:
            findings.append("%s: manifest is not valid JSON (%s)" % (n, e))
            continue
        t = j.get("timeout_s")
        if t is None:
            # run.py defaults to 30s, but an UNDECLARED bound is an unbounded
            # budget as far as this file is concerned: the sum stops meaning
            # anything the moment a member can opt out of being counted.
            findings.append("%s: no timeout_s declared" % n)
            continue
        total += t

    # THE CORPUS IS REPORTED BUT NOT CAPPED, DELIBERATELY.  The ceiling bounds
    # what the GATE waits for, which is the number that turns into an
    # afternoon.  The corpus is the number that turns into 268 manifests, and
    # it is printed so that deleting a test nobody runs in the gate still shows
    # up as progress -- otherwise the only visible reward is for deleting gate
    # tests, and the dead weight is mostly outside the gate.
    corpus_n = corpus_s = 0
    for path in sorted(os.listdir(tests_dir)) if os.path.isdir(tests_dir) else []:
        if not path.endswith(".json"):
            continue
        corpus_n += 1
        try:
            corpus_s += json.load(open(os.path.join(tests_dir, path))).get(
                "timeout_s", 0)
        except ValueError:
            pass

    if total > BUDGET_S:
        findings.append(
            "OVER BUDGET: %ds declared, ceiling %ds (over by %ds).  "
            "Adding a gate test means taking one out." % (total, BUDGET_S,
                                                          total - BUDGET_S))
    return (findings, total, names, (corpus_n, corpus_s))


def _write(path, text):
    d = os.path.dirname(path)
    if not os.path.isdir(d):
        os.makedirs(d)
    open(path, "w").write(text)


def _fake_tree(tmp, names, manifests):
    _write(os.path.join(tmp, "tools", "gate.sh"),
           'GATE_TESTS="%s"\n' % " \\\n            ".join(names))
    for n, body in manifests.items():
        _write(os.path.join(tmp, "tools", "mame_test", "tests", n + ".json"),
               body)
    return tmp


def self_test():
    """POSITIVE CONTROLS: a checker that passes by finding nothing is
    indistinguishable from one that stopped looking."""
    ok = json.dumps({"name": "x", "timeout_s": 10})
    cases = []

    # 1. a clean corpus is clean -- without this the other four prove nothing,
    #    because a checker that always fails would pass all of them.
    cases.append(("clean", ["a", "b"], {"a": ok, "b": ok}, 0))
    # 2. the continuation backslashes are NOT test names.
    cases.append(("continuations", ["a", "b", "c"],
                  {"a": ok, "b": ok, "c": ok}, 0))
    # 3. a name with no manifest -- the nodevboot shape.
    cases.append(("missing manifest", ["a", "ghost"], {"a": ok}, 1))
    # 4. a manifest with no timeout_s.
    cases.append(("no timeout_s", ["a", "b"],
                  {"a": ok, "b": json.dumps({"name": "b"})}, 1))
    # 5. over the ceiling.
    big = json.dumps({"name": "big", "timeout_s": BUDGET_S + 1})
    cases.append(("over budget", ["big"], {"big": big}, 1))
    # 6. unparseable JSON is a finding, not a crash.
    cases.append(("bad json", ["a", "junk"], {"a": ok, "junk": "{not json"}, 1))

    failed = 0
    for label, names, manifests, want in cases:
        tmp = tempfile.mkdtemp(prefix="gatebudget.")
        _fake_tree(tmp, names, manifests)
        findings, total, got_names, _corpus = audit(tmp)
        if label == "continuations" and got_names != names:
            print("SELF-TEST FAIL [%s]: parsed %r" % (label, got_names))
            failed += 1
            continue
        if (len(findings) > 0) != (want > 0):
            print("SELF-TEST FAIL [%s]: findings=%r" % (label, findings))
            failed += 1
    if failed:
        print("gate_budget.py self-test: %d FAILED" % failed)
        return 1
    print("gate_budget.py self-test: %d cases OK" % len(cases))
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    findings, total, names, corpus = audit(ROOT)
    if findings:
        for f in findings:
            print("gate_budget: %s" % f)
        return 1
    print("gate_budget: %d gate tests, %ds declared, ceiling %ds "
          "(%ds headroom)" % (len(names), total, BUDGET_S, BUDGET_S - total))
    print("gate_budget: corpus %d manifests, %ds declared (not capped)"
          % corpus)
    return 0


if __name__ == "__main__":
    sys.exit(main())
