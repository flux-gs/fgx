#!/usr/bin/env python3
"""
test_uninit_warn.py -- fcc's use-before-set warning, both directions.

K&R 2nd ed 2.4, p.39: "External and static variables are initialized to zero by
default.  Automatic variables for which is no explicit initializer have
undefined (i.e., garbage) values."  The warning exists because on this machine
"garbage" is a cold boot's RAM rather than an emulator's obliging zeros
(apple/fgx#360), so the class is worth a diagnostic rather than a convention.

BOTH DIRECTIONS ARE ASSERTED.  A warning that fires on everything is noise and
a warning that fires on nothing is decoration; only the pair pins the
behaviour.  The quiet cases are the ones that cost something to get right --
the pointer store in particular, which the first cut of this warning missed and
which produced 58 false positives across libc before the FPR store path was
counted.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
FCC  = os.path.join(HERE, "..", "..", "fcc")
SRC  = os.path.join(HERE, "uninit.c")

MUST_WARN  = ["x", "y"]
MUST_QUIET = ["a", "b", "c", "p", "acc", "i", "s"]


def main():
    out = os.path.join(HERE, ".uninit.s")
    p = subprocess.run([FCC, SRC, "-o", out],
                       capture_output=True, text=True)
    if p.returncode != 0:
        print("test_uninit_warn: FAIL -- fcc exited %d\n%s"
              % (p.returncode, p.stderr))
        return 1
    warned = set()
    for line in p.stderr.splitlines():
        if "K&R 2.4" not in line:
            continue
        # "...: warning: 'name' is used but never set (K&R 2.4: ...)"
        name = line.split("warning: '", 1)[1].split("'", 1)[0]
        warned.add(name)

    fails = []
    for n in MUST_WARN:
        if n not in warned:
            fails.append("'%s' should have warned and did not" % n)
    for n in MUST_QUIET:
        if n in warned:
            fails.append("'%s' warned and must not" % n)

    if fails:
        print("test_uninit_warn: FAIL")
        for f in fails:
            print("   " + f)
        print("   warned: %s" % sorted(warned))
        return 1
    print("test_uninit_warn: OK -- %d warned (%s), %d quiet (%s)"
          % (len(MUST_WARN), ",".join(MUST_WARN),
             len(MUST_QUIET), ",".join(MUST_QUIET)))
    # fcc writes the data segment beside the code as .uninit.data.s.
    for f in (out, os.path.join(HERE, ".uninit.data.s")):
        try:
            os.remove(f)
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
