#!/usr/bin/env python3
"""test_shells.py - vi and tcsh's built images are dynamic FGX3 programs,
sh's a static one (shared libc SP5 step 3).  Reads the binaries the build left behind; needs
a built tree.

Run: python3 toolchain/tests/dyn/test_shells.py [vi ...]   (none: every shell)
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO = os.path.dirname(ROOT)
sys.path.insert(0, os.path.join(ROOT, "src", "ld"))
import fgx_bind  # noqa: E402
import fgx_ld  # noqa: E402
fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def dynamic(name, path):
    p = os.path.join(REPO, path)
    data = open(p, "rb").read() if os.path.isfile(p) else b""
    check(data[:4] == b"FGX3", name + ": magic FGX3", repr(data[:4]))
    check(len(data) > 10 and data[10] & fgx_ld.DYN_FLAG, name + ": dynamic flag set",
          hex(data[10]) if len(data) > 10 else "short file")


def static(name, path):
    """A static image: FGX3, every segment kind one fgx_ld knows, and the
    dynamic flag clear."""
    p = os.path.join(REPO, path)
    data = open(p, "rb").read() if os.path.isfile(p) else b""
    check(data[:4] == b"FGX3", name + ": magic FGX3", repr(data[:4]))
    kinds = [k for _s, _b, k in fgx_bind.parse(data)["segs"]] if len(data) > 10 else []
    check(kinds and set(kinds) <= set(fgx_ld.KIND_MAP.values()),
          name + ": known segment kinds", "kinds %s" % kinds)
    check(len(data) > 10 and not data[10] & fgx_ld.DYN_FLAG, name + ": dynamic flag clear",
          hex(data[10]) if len(data) > 10 else "short file")


def sh():
    static("sh", "bin/sh.bin")


def vi():
    dynamic("vi", "bin/elvis.bin")


def tcsh():
    dynamic("tcsh", "bin/tcsh.bin")


SHELLS = {"sh": sh, "vi": vi, "tcsh": tcsh}
for n in sys.argv[1:] or sorted(SHELLS):
    SHELLS[n]()
print("FAIL: %d" % len(fails) if fails else "shell checks passed")
sys.exit(1 if fails else 0)
