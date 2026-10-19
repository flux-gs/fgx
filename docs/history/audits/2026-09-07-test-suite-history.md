# The MAME test suite: why it was deleted, and how it grew back

A dated record (2026-07-29 to 2026-09-07) of the decisions behind the gate's
budget.  The current policy is in [../../testing.md](../../testing.md).

## Why the old suite was deleted (2026-07-29)

Until 2026-07-29 the gate was ~310 MAME manifests, 20-30 minutes on a good run.
It was deleted wholesale (the maintainer's call). The reasoning, recorded because it would
otherwise be easy to rebuild by accident:

- **Its failures did not correlate with product breakage.** Session after
  session a red suite meant stale expectations, a missing hardware rig, or
  harness timing -- not an OS defect. Real bugs were caught by targeted probes
  and by the build's own checks.
- **It cost thousands of hours** across the project and dominated every release;
  the gate/MR/gate/MR loop it fed is why a single change took a day.
- **Its last full run was actively misleading.** Two hours, 62 timeouts, all
  self-inflicted: one MAME survived a too-short `SIGKILL` wait and kept a core
  pinned under `-nothrottle`, which starved the next test's wall-clock budget,
  which timed out and leaked another. Every screen assertion still passed. A
  suite that can spend two hours reporting numbers that mean nothing is worse
  than no suite, because it gets trusted.

The manifests remain in git history if a specific one is ever wanted as a
starting point.

## How it grew back (to 2026-09-07), and the question that was missing

The blank slate lasted about a day. Between 2026-07-29 and 2026-09-07 the
corpus went from **3 manifests to 268**, with **337 additions against 11
deletions**. It was not a campaign and no one argued with the policy on this
page: **282 of the 337 (84%) rode in on commits that were about `src/` or the
toolchain**, one regression test per fix, each locally reasonable. Meanwhile
`developing-userland.md` step 7 still said "add a test (recommended)", and that
is the document that sits on the path of the work; this one does not.

**The four questions below are asked of ONE test, and the cost they exist to
bound only appears in the SUM.** Question 3 in particular cannot be answered
wrongly by any single manifest -- every one of them is cheap on its own. So the
bar was cleared 337 times and the corpus still reached 216 minutes of declared
budget. That is not a bar anyone dodged; it was aimed one level too low.

**What the correction removed.** On 2026-09-07 the manifests whose reason for
existing was a defect that has since been fixed were deleted: 120 of them,
taking the gate from 80 tests to 46 and the corpus from 268 to 148. The maintainer's
rule is that a resolved defect does not need a standing witness -- the machine
gets smoke-tested by a person, and a recurrence gets a fresh work item. What
was KEPT from that set is the part a person at the keyboard cannot see: silent
corruption, resource leaks, stack headroom, module-image integrity, a kernel
trap that fired quietly, a fork that shared where it should have copied. Plus
the UFS campaign's own coverage, which is live work rather than residue.

Hence question 5, and `gate_budget.py` to enforce it mechanically, because the
first four are enforced by whoever remembers to open this file.

