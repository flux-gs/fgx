#!/usr/bin/env python3
"""Every path copy into the kernel's path buffer must test the carry.

apple/fgx#436.  `_Sys_CopyPathToBuf' used to stop at the buffer, write a NUL
and return success, so a path past the limit was looked up as a DIFFERENT,
SHORTER name -- usually ENOENT for a file that exists, and, when the truncation
landed on another real name, the wrong file acted on.  It reports C=1 now, and
the report is only worth anything if every caller reads it.

There were twenty-six call sites when this was written, across two files, and
the failure mode this guards is a twenty-seventh added without the test: it
would compile, run, and silently truncate exactly as before.  The check is
therefore on the SHAPE at the call site, not on a count -- a new site is fine,
a new site with no carry test is not.

Accepted immediately after the JSR (comments and blank lines skipped):

    BCC <label>         the ok-path branch; the overflow falls through
    BCS <label>         the error branch

Run standalone for a report, or with --self-test to prove the checker can fail.
"""

import re
import sys
import tempfile
import os

FILES = [
    "src/kernel/syscall.s",
    "src/kernel/process.s",
    # The KSVC arm for an AF_UNIX socket's name copies the sockaddr's sun_path
    # in, so it is a twenty-seventh site and this checker's whole reason for
    # existing is a new one arriving without the carry test.
    "src/kernel/jumptable.s",
]

CALL = re.compile(r"^\s+JSR\s+(_Sys_CopyPathToBuf2?)\b")
GUARD = re.compile(r"^\s+(BCC|BCS)\s+\S")
SKIP = re.compile(r"^\s*(;.*)?$")


def check_text(text, name):
    """Return a list of (line_number, routine) for unguarded call sites."""
    lines = text.split("\n")
    bad = []
    for i, line in enumerate(lines):
        m = CALL.match(line)
        if not m:
            continue
        # The next line that is neither blank nor a whole-line comment.
        j = i + 1
        while j < len(lines) and SKIP.match(lines[j]):
            j += 1
        if j >= len(lines) or not GUARD.match(lines[j]):
            bad.append((i + 1, m.group(1)))
    return bad


def check_file(path):
    with open(path) as fh:
        return check_text(fh.read(), path)


def self_test():
    """A known-bad input the checker must call bad, and a known-good one.

    Without this the checker passes vacuously if CALL stops matching -- zero
    sites found reads exactly like zero sites unguarded.
    """
    good = (
        "                JSR     _Sys_CopyPathToBuf\n"
        "                BCC     @ok_plok\n"
        "                JMP     _Sys_PathTooLong\n"
        "@ok_plok        LDX     #_Sys_PathBuf\n"
    )
    bad = (
        "                JSR     _Sys_CopyPathToBuf\n"
        "                LDX     #_Sys_PathBuf\n"
    )
    commented = (
        "                JSR     _Sys_CopyPathToBuf2     ; TO path\n"
        "\n"
        "                ; a comment, then the test\n"
        "                BCS     @err\n"
    )
    ok = True
    if check_text(good, "<good>"):
        print("self-test FAIL: a guarded site was reported")
        ok = False
    if not check_text(bad, "<bad>"):
        print("self-test FAIL: an unguarded site was NOT reported")
        ok = False
    if check_text(commented, "<commented>"):
        print("self-test FAIL: a comment between the JSR and the test broke it")
        ok = False
    if ok:
        print("check_path_copy self-test OK (guarded pass, unguarded fail)")
    return 0 if ok else 1


def main():
    if "--self-test" in sys.argv:
        return self_test()
    total = 0
    bad = []
    for path in FILES:
        if not os.path.exists(path):
            print("check_path_copy: missing %s" % path)
            return 1
        with open(path) as fh:
            text = fh.read()
        total += sum(1 for l in text.split("\n") if CALL.match(l))
        for line, routine in check_text(text, path):
            bad.append("%s:%d %s is not followed by a carry test" %
                       (path, line, routine))
    if total == 0:
        print("check_path_copy: no call sites found at all -- the pattern has "
              "drifted, which is not a pass")
        return 1
    if bad:
        print("check_path_copy FAILED: a path copy whose overflow nobody reads "
              "truncates silently (apple/fgx#436):")
        for b in bad:
            print("    " + b)
        return 1
    print("check_path_copy OK: %d call site(s), every one tests the carry" %
          total)
    return 0


if __name__ == "__main__":
    sys.exit(main())
