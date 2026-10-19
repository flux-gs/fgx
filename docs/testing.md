# Testing FGX

## The gate is a smoke test plus a BUDGETED set

The gate runs `smoke` plus a set of further MAME boot tests, `GATE_TESTS` in
`tools/gate.sh` (44 besides smoke).  That set has a **declared-time ceiling**,
`BUDGET_S` in `tools/mame_test/gate_budget.py`, and the gate refuses to run over
it.  Adding a gate test means **taking one out**.

The ceiling is a **ratchet**: it only goes down. Deletions buy headroom and the
commit that deletes lowers the ceiling by what it freed, or the slack just
refills.

```bash
tools/gate.sh              # build + tests, then write .gate/<sha>.json
tools/gate.sh --no-tests   # build only (receipt marked build-only; not releasable)
python3 tools/mame_test/gate_budget.py   # what the corpus costs, and its ceiling
```

**Read the verdict line, not just `$?`.** The gate serialises itself with a
`.gate.lock` directory, and a gate that finds the lock held exits **75**
(`EX_TEMPFAIL`) after printing `SKIPPED` on stdout and stderr: it ran nothing, so
it reports neither green nor red. The contention is routine -- the pre-push hook
spawns a gate on every feature-branch push, and running one by hand right after
pushing is the obvious next move -- so treat 75 as "retry when it finishes". A
skip writes no receipt, which is what keeps `release.sh` honest: absent is red.

`tools/mame_test/tests/smoke.json` boots `disk/fgxufs.po` in headless MAME, waits
for the shell prompt, runs `ls /`, and asserts the listing came back. That is the
whole behavioural contract:

- the kernel starts,
- `init` runs,
- a login shell reaches a prompt,
- it can execute a binary,
- the binary produces correct output,
- and control returns to the prompt.

If that passes, the tree is not broken in a way that blocks development. If it
fails, something fundamental is wrong and you want to know immediately.

```bash
python3 tools/mame_test/run.py --headless --no-state --fresh smoke
python3 tools/mame_test/run.py --window --no-state smoke   # watch it boot
python3 tools/mame_test/run.py --debug smoke               # window, no timeout
```

## What else runs, and why it isn't "tests"

These are **source assertions**, not behavioural tests. Some thirty of them
(`tools/check_*.py` and a few generators' `--check`) run in seconds as ninja
edges, and each catches a class of fault that is invisible to a boot because it
corrupts at runtime, silently, later.  Among them:

| check | catches |
|---|---|
| `check_mx.py` | 65816 M/X flag leaks -- an 8-bit access where 16 was meant |
| `check_baked_addrs.py` | kernel-data addresses hardcoded into userland |
| `check_provenance.py` | a 2.11BSD-derived file with no attribution |
| `gen_syscall_table.py --check` | syscall table drifted from `include/loader.s` |
| `gen_w5100_patchsites.py --check` | W5100 self-mod tables drifted from the listing |

Each **self-tests before it is trusted** (`--self-test`), because a checker that
passes by finding nothing is indistinguishable from one that stopped looking.

Separately, `bash toolchain/tests/run.sh` diffs fcc's ~700 fixture goldens
(a few minutes, no emulator). `gate.sh` runs it only when `toolchain/` changed -- fcc
unchanged means its codegen cannot have regressed.

## What joins the gate

A test proposed for `GATE_TESTS` should answer:


1. **What product failure does this catch that the smoke test misses?** If it
   cannot name one, it is not earning its runtime.
2. **How does it fail when the HARNESS is broken rather than the OS?** The old
   suite could not distinguish those, which is exactly why its red was
   ignorable.
3. **What is its wall-clock cost, and does that cost scale with the corpus or
   with the change?** Per-change is fine; per-corpus is how you reach 30 minutes.
4. **Can it report a false green?** A cached pass, a skipped rig, a check whose
   tool never ran, a suite that aborted early with no summary -- all four
   happened here.
5. **What comes OUT to pay for it?** Only for a test that joins `GATE_TESTS`.
   The budget is fixed, so this one has an answer or the test does not go in the
   gate -- it can still live in the corpus and be run by name. This is the only
   question on the list that a single test cannot answer by itself, which is why
   it is the only one with a checker behind it.

Why the budget exists, and how the suite was deleted and then regrew, is
recorded in [history/audits/2026-09-07-test-suite-history.md](history/audits/2026-09-07-test-suite-history.md).

## When the gate goes red and then green

**A verdict is never erased.** `.gate/<sha>.json` is overwritten by the next run
of the same commit, so every verdict is also appended to `.gate/history.jsonl`,
and a green receipt records `reds_before`: how many times that SHA had already
failed. A gate that flakes red and passes on a re-run now leaves both facts
behind, instead of a clean history that did not happen (apple/fgx#262).

**"It is flaky" is a claim with a number attached.** `run.py` journals every
result under the fingerprint of the test's INPUTS -- disk image, manifest,
staged files, check_script, env -- so a key seen both green and red gave two
answers to identical inputs. That is a flake by definition rather than by
impression:

```bash
python3 tools/mame_test/flakes.py --days 30      # rate per test
python3 tools/mame_test/flakes.py --test morepty --test logintest
```

Raw fail counts cannot be used for this: a fixture is red until it works, and
that is development, not flakiness. Grouping by input key removes nearly all of
it, because a test under development changes its own inputs.

**A failed screen assertion prints the screen.** A bare `screen missing 'X'`
line is not diagnosable after the fact -- the scratch dir is reused by the next
run -- and that is why apple/fgx#262's two flakes were re-run to green rather
than explained. The tail of the capture now goes into the log beside the
failure.

## Writing a manifest

**Prefer extending an existing manifest**: a second assertion on a boot already
being paid for is free, and a source assertion (a ninja edge, seconds, no
emulator) is nearly free. A new manifest is the last resort. When it is the
right answer, the harness format is:

```json
{
  "name": "smoke",
  "description": "what product failure this catches",
  "command": "ls /",
  "timeout_s": 25,
  "expect": {
    "screen_contains": ["etc", "sbin", "usr", "fgx#"],
    "screen_lacks":    ["BRK", "PANIC", "not found"]
  }
}
```

Optional `"requires": {"env": [...], "tcp": "host:port", "reason": "..."}`
declares a rig the test needs; unmet, it is reported as **skipped** and named
individually, never counted as a pass.

Two traps worth keeping in mind, both of which produced long-lived false results
here:

- The SHR console wraps, and the boot `dmesg` is verbose -- assert on **short
  anchors** (one word, the prompt), never long substrings that can straddle a
  wrap.
- Make the asserted output **not a substring of the typed command**, or the
  command echo alone satisfies the match whether the program ran or not.
