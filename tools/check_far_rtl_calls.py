#!/usr/bin/env python3
"""check_far_rtl_calls -- inside the far bank, JSR must not target an RTL routine.

WHY THIS EXISTS (2026-08-01).  The far kernel bank's export-table targets end in
RTL, because the core kernel reaches them with JSL.  But once a subsystem MOVES
into the far bank, its far-bank neighbours start calling it directly -- and a
same-bank call is a JSR, which pushes two bytes where RTL pulls three.

That is not a crash at the call site.  The extra byte skews the return address
one level up, so control resumes at a plausible-looking wrong address and the
failure surfaces as "the CALLER is broken".  It cost a full boot-hang
investigation: `Far_BootChime` did `JSR Sound_Beep`, the chime SOUNDED, and boot
simply never continued past it.  Two sites had it -- the boot chime and the VT
bell -- and neither produced a diagnostic of any kind.

The fix is the convention this checker enforces, already used by the kernel's
MOD_JT `*Impl` targets and by src/kernel/far_shims.s: an RTS-terminated body plus
a thin RTL wrapper.  Same-bank callers JSR the body; cross-bank callers JSL the
wrapper.

WHY THIS SCANS SOURCE, NOT THE LISTING.  check_far_calls.py deliberately works on
the listing because the thing it looks for is an EQU, and Merlin32 expands EQUs
in the listing's source column, so a name scan there matches nothing forever.
That trap does not apply here: these are ordinary LABELS, which Merlin32 lists
verbatim -- and more to the point, "which routine does this label end with"
is a property of the source, not of the emitted bytes.  Recovering it from the
listing would mean flow analysis across branches to decide which RTS/RTL a JSR
target actually reaches; the source has the answer directly.

THE RULE.  Within src/kernel/far/, a label is RTL-terminated if any instruction
between it and the next global label is an RTL.  A `JSR <label>` naming such a
label is a violation.  This is intentionally conservative: a routine with an RTL
on any path is one a JSR must not target, whichever path runs.

Usage:
  check_far_rtl_calls.py             # scan every bank in BANK_DIRS
  check_far_rtl_calls.py --self-test
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# EVERY STATICALLY LINKED BANK, SCANNED SEPARATELY.  Each is its own link unit,
# so a JSR in one can only reach a label in the same one -- pooling the sources
# would let a name that is RTL-terminated in the tty bank condemn an unrelated
# same-name RTS routine in the far bank.  Adding a bank is a row here.
BANK_DIRS = (("far", os.path.join(ROOT, "src", "kernel", "far")),
             ("tty", os.path.join(ROOT, "src", "kernel", "tty")))

# A global label starts in column 0 and is not a comment.  Merlin32 locals begin
# with '@' or ':' and never reset the enclosing routine, so they are skipped.
_LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\b")
_RTL = re.compile(r"^\s+RTL\b", re.IGNORECASE)
_JSR = re.compile(r"^[^;]*?\bJSR\s+([A-Za-z_][A-Za-z0-9_]*)", re.IGNORECASE)


def rtl_labels(sources):
    """Labels whose body contains an RTL.  sources: {path: text}."""
    out = set()
    for path, text in sources.items():
        cur = None
        for line in text.split("\n"):
            if line[:1] == ";":
                continue
            m = _LABEL.match(line)
            if m:
                cur = m.group(1)
            if cur and _RTL.match(line):
                out.add(cur)
    return out


def jsr_sites(sources):
    """(path, lineno, target) for every JSR naming a label."""
    out = []
    for path, text in sources.items():
        for n, line in enumerate(text.split("\n"), 1):
            if line.lstrip()[:1] == ";":
                continue
            m = _JSR.match(line)
            if m:
                out.append((path, n, m.group(1)))
    return out


def violations(sources):
    rtl = rtl_labels(sources)
    return [(p, n, t) for p, n, t in jsr_sites(sources) if t in rtl], rtl


def _read_bank(root):
    sources = {}
    for dirpath, _, names in os.walk(root):
        for name in sorted(names):
            if name.endswith(".s"):
                p = os.path.join(dirpath, name)
                with open(p, errors="replace") as f:
                    sources[os.path.relpath(p, ROOT)] = f.read()
    return sources


def _selftest():
    """Prove the checker can FAIL, and that it ignores the legitimate shapes."""
    fails = []

    # The exact bug this exists to catch, plus the fix, plus the shapes that
    # must NOT be flagged.
    bad = {"far.s": (
        "Far_BootChime   MX      %00\n"
        "                JSR     Sound_Beep\n"
        "                RTL\n"
        "Sound_Beep      ENT\n"
        "                PHP\n"
        "                RTL\n")}
    hits, _ = violations(bad)
    if len(hits) != 1 or hits[0][2] != "Sound_Beep":
        fails.append(f"the real bug was not caught: {hits}")

    good = {"far.s": (
        "Far_BootChime   MX      %00\n"
        "                JSR     _Sound_BeepImpl\n"
        "                RTL\n"
        "Sound_Beep      ENT\n"
        "                JSR     _Sound_BeepImpl\n"
        "                RTL\n"
        "_Sound_BeepImpl MX      %00\n"
        "                PHP\n"
        "                RTS\n")}
    hits, _ = violations(good)
    if hits:
        fails.append(f"the *Impl fix was wrongly flagged: {hits}")

    # A local label must not end the enclosing routine's body: an RTL after
    # @lbl still belongs to the global label above it.
    local = {"far.s": (
        "Sound_Beep      ENT\n"
        "@sb_done        NOP\n"
        "                RTL\n"
        "Caller          JSR     Sound_Beep\n"
        "                RTS\n")}
    hits, _ = violations(local)
    if len(hits) != 1:
        fails.append(f"an RTL after a LOCAL label was not attributed to its "
                     f"routine: {hits}")

    # JSL to an RTL routine is correct and must never be flagged; neither may
    # a comment mentioning one.
    ok = {"far.s": (
        "Sound_Beep      ENT\n"
        "                RTL\n"
        "Caller          JSL     Sound_Beep\n"
        "; JSR     Sound_Beep  -- in a comment\n"
        "                RTS\n")}
    hits, _ = violations(ok)
    if hits:
        fails.append(f"JSL or a comment was flagged: {hits}")

    if fails:
        for f in fails:
            print(f"  {f}", file=sys.stderr)
        print(f"check_far_rtl_calls self-test: {len(fails)} FAILURE(S)")
        return 1
    print("check_far_rtl_calls self-test: OK (catches JSR->RTL, accepts the "
          "*Impl split, attributes RTL past local labels, ignores JSL)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return _selftest()

    rc, tally = 0, []
    for label, root in BANK_DIRS:
        sources = _read_bank(root)
        if not sources:
            print(f"check_far_rtl_calls: no sources under {root} -- the {label} "
                  f"bank moved or this path is stale. Fix this checker rather "
                  f"than deleting it.", file=sys.stderr)
            return 1

        hits, rtl = violations(sources)
        tally.append((label, len(sources), len(rtl)))
        if not hits:
            continue
        rc = 1
        print(f"check_far_rtl_calls: {len(hits)} same-bank JSR(s) to an "
              f"RTL-terminated {label}-bank routine. JSR pushes two bytes and "
              f"RTL pulls three, so the return lands one level up at a wrong "
              f"address -- the beep still sounds, the caller still 'works', and "
              f"boot hangs somewhere unrelated. Split the callee into an "
              f"RTS-terminated *Impl body plus a thin RTL wrapper (see "
              f"src/kernel/far/sound.s) and JSR the body:", file=sys.stderr)
        for path, line, target in hits:
            print(f"  {path}:{line}: JSR {target} -- {target} ends in RTL",
                  file=sys.stderr)
    if rc:
        return rc

    where = ", ".join(f"{label} {nf} file(s)/{nr} RTL routine(s)"
                      for label, nf, nr in tally)
    print(f"check_far_rtl_calls: clean ({where}; no same-bank JSR into any)")
    return 0


if __name__ == "__main__":
    # sys.exit: main() RETURNS its status, and a check that cannot fail the
    # build is exactly the defect it exists to catch.
    sys.exit(main() or 0)
