#!/usr/bin/env python3
"""check_vacuous_assertions.py -- catch MAME assertions satisfiable by the
command line MAME types, rather than by anything the system did.

THE FAILURE THIS EXISTS TO STOP
    run.py's screen_contains searches the WHOLE console ring, and the ring
    holds the shell's echo of the command MAME typed.  So a manifest whose
    needle appears in its own `command` matches that echo -- and passes on a
    run that produced no output whatsoever.

    tools/mame_test/tests/wide60.json records the first instance in its own
    header: "the first cut asserted a marker that the outer shell echoed as
    part of the command, so it passed on a run that produced no output".

    mid40st was the second, and it hid a real question for weeks: its needle
    `RC=` is inside `sh -c '. /testdata/mid40; echo RC=$?'`.  It only went red
    when unrelated console output pushed the echoed command out of the ring --
    i.e. the test's PASS had never depended on the shell printing anything.

    A third variant is the same idea one level down: run.py used to read the
    `expect` block key-by-key with .get(), so a MISSPELLED key was silently
    dropped (ttysprobe shipped `screen_not_contains`, which does not exist).
    That one is now caught by KNOWN_EXPECT_KEYS in run.py.

WHY A TOOL AND NOT VIGILANCE
    Three instances found by three different people at three different times,
    each after the assertion had been green for a while.  The property is
    mechanically checkable in four lines, so check it mechanically.

THE ESCAPE HATCH, AND ITS PRICE
    Some assertions legitimately name a string that also appears in the
    command -- typically a marker echoed by a post_command, where the
    DISCRIMINATION comes from the command never being typed at all (the
    machine halted, so neither the echo nor its output appears).  Those are
    weak but not vacuous.

    A manifest may list such needles in `echo_ok`.  That is a DELIBERATE
    statement that the author checked the assertion still discriminates, and
    it should carry a comment saying how.  It is not a way to silence this
    check; it is a way to record that the question was asked.

A SECOND SHAPE, SAME FAMILY: A COMMAND THAT IS NEVER TYPED
    run.py exits when the prompt sentinel "fgx#" appears one more time than at
    first paste.  A manifest whose `command` is `sh` re-enters the Bourne shell,
    which prints that sentinel IMMEDIATELY -- so the run ends before any
    post_command is typed, and every assertion about their output reports
    `screen missing X`.  That reads as a PRODUCT failure and is not one.

    Measured 2026-08-22: eight manifests had this shape.  cdtwo was red at HEAD
    for it and passes with one line; so do b3hwm, ctrlc, sigpaus, sigwin, tostop
    and vcclose.  (twodrive cannot run here at all -- it refuses without its
    second-drive image, loudly and by design.)

    THE RULE IS NARROW ON PURPOSE, because the obvious wide one is wrong: 13
    manifests carry post_commands without the override and only these eight are
    broken.  The other five are fine, and measurably so -- four use `tcsh`,
    whose prompt is NOT the sentinel, so the early exit never fires and the run
    reaches its frame limit with the post commands typed; one sets its own
    count_delta.  A checker that flagged those would be crying wolf at working
    tests.  So it fires only on the interpreter that reprints the sentinel.

Usage:
    check_vacuous_assertions.py [--self-test]
"""
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.join(HERE, "mame_test", "tests")

# Keys whose values are needles searched against captured output.
NEEDLE_KEYS = ("screen_contains", "klog_contains", "faslog_contains")


def command_text(m):
    """Everything MAME types, which is also everything the shell echoes."""
    parts = [m.get("command") or ""]
    parts.extend(m.get("post_commands") or [])
    return " ".join(parts)


# Commands that re-enter an interpreter printing the SAME prompt sentinel
# run.py exits on.  `tcsh` is deliberately absent: its prompt is not "fgx#", so
# the early exit never fires and its post_commands are typed.
SENTINEL_SHELLS = ("sh",)


def scan_unreachable(path):
    """Return True if this manifest's post_commands can never be typed."""
    with open(path) as f:
        m = json.load(f)
    if not m.get("post_commands"):
        return False
    if (m.get("command") or "").strip() not in SENTINEL_SHELLS:
        return False
    # An explicit exit_on_prompt -- false, or a dict with the author's own
    # count_delta -- is a statement that the question was asked.
    return "exit_on_prompt" not in m


def scan_manifest(path):
    """Return [(key, needle)] for assertions satisfiable by the echoed command."""
    with open(path) as f:
        m = json.load(f)
    cmd = command_text(m)
    allowed = set(m.get("expect", {}).get("echo_ok") or [])
    hits = []
    for key in NEEDLE_KEYS:
        for needle in (m.get("expect", {}).get(key) or []):
            if not isinstance(needle, str) or not needle:
                continue
            if needle in cmd and needle not in allowed:
                hits.append((key, needle))
    return hits


def self_test():
    """The check must fire on the shape it exists to catch, and stay quiet on
    the shape it must not flag.  A checker nobody has watched fail is itself
    an unverified assertion."""
    import tempfile

    def one(manifest):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(manifest, f)
            p = f.name
        try:
            return scan_manifest(p)
        finally:
            os.unlink(p)

    # Positive: the mid40st shape -- needle inside the command.
    hits = one({"command": "sh -c '. /testdata/mid40; echo RC=$?'",
                "expect": {"screen_contains": ["RC="]}})
    assert hits == [("screen_contains", "RC=")], hits

    # Positive: needle inside a post_command.
    hits = one({"command": "true", "post_commands": ["echo MARK2"],
                "expect": {"screen_contains": ["MARK2"]}})
    assert hits == [("screen_contains", "MARK2")], hits

    # Negative: needle produced by expansion, absent from the command text.
    hits = one({"command": "S=ST; sh -c '. /testdata/mid40'; echo $S=$?",
                "expect": {"screen_contains": ["ST="]}})
    assert hits == [], hits

    # Negative: an explicitly acknowledged echo needle.
    hits = one({"command": "true", "post_commands": ["echo MARK2"],
                "expect": {"screen_contains": ["MARK2"], "echo_ok": ["MARK2"]}})
    assert hits == [], hits

    # Negative: output that merely resembles the command.
    hits = one({"command": "ls /",
                "expect": {"screen_contains": ["etc", "sbin"]}})
    assert hits == [], hits

    # --- the second shape: a command that can never be typed --------------
    def one_u(manifest):
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
            json.dump(manifest, f)
            p = f.name
        try:
            return scan_unreachable(p)
        finally:
            os.unlink(p)

    # Positive: the cdtwo shape.
    assert one_u({"command": "sh", "post_commands": ["/testbin/cdtwo"]}) is True

    # Negative: the override present, which is what 45 manifests already do.
    assert one_u({"command": "sh", "post_commands": ["/testbin/cdtwo"],
                  "exit_on_prompt": False}) is False
    # ...including a deliberate non-default count.
    assert one_u({"command": "sh", "post_commands": ["x"],
                  "exit_on_prompt": {"sentinel": "fgx#",
                                     "count_delta": 2}}) is False

    # Negative: tcsh, whose prompt is NOT the sentinel, so the early exit never
    # fires.  MEASURED -- bgsteal and the three p5_z_* tests pass exactly this
    # way, and flagging them would be crying wolf at working tests.
    assert one_u({"command": "tcsh", "post_commands": ["x"]}) is False

    # Negative: no post_commands at all.
    assert one_u({"command": "sh"}) is False

    # Negative: a program, not a shell -- its prompt return IS the signal.
    assert one_u({"command": "/testbin/dupfile",
                  "post_commands": ["x"]}) is False

    print("check_vacuous_assertions: self-test OK")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()

    bad = []
    unreachable = []
    n = 0
    for path in sorted(glob.glob(os.path.join(TESTS, "*.json"))):
        n += 1
        for key, needle in scan_manifest(path):
            bad.append((os.path.basename(path), key, needle))
        if scan_unreachable(path):
            unreachable.append(os.path.basename(path))

    if unreachable:
        print(f"check_vacuous_assertions: {len(unreachable)} manifest(s) run "
              f"`sh' with post_commands and no exit_on_prompt, so the run ends "
              f"at the nested shell's prompt and the post commands are NEVER "
              f"TYPED.  Every assertion about their output then reports "
              f"`screen missing', which reads as a product failure:\n")
        for name in unreachable:
            print(f"  {name}")
        print("\nFix by adding \"exit_on_prompt\": false, which is what the "
              "other 45 manifests of this shape already do.  If the run is "
              "meant to end at a prompt, set exit_on_prompt to a dict with the "
              "count_delta you want instead -- either way the question is then "
              "on the record.")
        return 1

    if not bad:
        print(f"check_vacuous_assertions: clean ({n} manifests)")
        return 0

    print(f"check_vacuous_assertions: {len(bad)} assertion(s) in "
          f"{len(set(b[0] for b in bad))} of {n} manifests are satisfiable by "
          f"the command line MAME types, so they can pass on a run that "
          f"produced no output:\n")
    for name, key, needle in bad:
        print(f"  {name:24} {key:16} {needle!r}")
    print("\nFix by making the needle something only the SYSTEM can produce -- "
          "build it by shell expansion so the typed command cannot contain it, "
          "e.g. `S=ST; ...; echo $S=$?` asserting 'ST='.")
    print("If an assertion is deliberately weak but still discriminates "
          "(typically: the command is never typed at all in the failing case), "
          "list the needle in the manifest's expect.echo_ok AND say in a "
          "comment how it discriminates.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
