#!/usr/bin/env python3
"""check_libso_identity.py - library mode touches only what reaches a block.

fcc's --libso reaches a block static through its member's block cell,
_libc_blk_<member>.  Every other function must compile exactly as it would
with blocks off (FCC_LIBSO_NOBLOCKS=1), which is the claim that the block
rewrite changed nothing it was not meant to.  This compiles libc's umbrella
both ways, splits the code at FGX_SECT/FGX_ENDS, and requires every section
that names no _libc_blk_ cell to be byte-identical in both.

Run: python3 tools/check_libso_identity.py [--self-test]
"""
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TC = os.path.join(ROOT, "toolchain")
SECT = re.compile(r"^\s+FGX_SECT\s+(\S+)\s*$")
ENDS = re.compile(r"^\s+FGX_ENDS\s*$")


def sections(text):
    """{name: body} for each FGX_SECT ... FGX_ENDS run."""
    out, name, body = {}, None, []
    for line in text.splitlines():
        m = SECT.match(line)
        if m:
            name, body = m.group(1), []
            continue
        if ENDS.match(line) and name is not None:
            out[name] = "\n".join(body)
            name = None
            continue
        if name is not None:
            body.append(line)
    return out


def compare(blocks_on, blocks_off):
    """(touching, identical, differing names) over the blocks-on sections."""
    on, off = sections(blocks_on), sections(blocks_off)
    touching = identical = 0
    differ = []
    for name, body in on.items():
        if "_libc_blk_" in body:
            touching += 1
        elif off.get(name) == body:
            identical += 1
        else:
            differ.append(name)
    return touching, identical, differ


def compile_umbrella(noblocks, d):
    env = dict(os.environ)
    if noblocks:
        env["FCC_LIBSO_NOBLOCKS"] = "1"
    out = os.path.join(d, "off.s" if noblocks else "on.s")
    r = subprocess.run(
        ["./fcc", "--libso", "--sections", "--core-list",
         "lib/libc_c/core.list", "lib/libc_c/libc_c.c", "-o", out,
         "--data-segment", out + ".data"],
        cwd=TC, env=env, capture_output=True, text=True)
    if r.returncode:
        sys.exit("check_libso_identity: fcc failed:\n" + r.stderr[-800:])
    return open(out).read()


def self_test():
    on = ("                FGX_SECT f\n LDA _libc_blk_m\n                FGX_ENDS\n"
          "                FGX_SECT g\n LDA #1\n                FGX_ENDS\n"
          "                FGX_SECT h\n LDA #2\n                FGX_ENDS\n")
    off = ("                FGX_SECT f\n LDA m_x\n                FGX_ENDS\n"
           "                FGX_SECT g\n LDA #1\n                FGX_ENDS\n"
           "                FGX_SECT h\n LDA #3\n                FGX_ENDS\n")
    t, i, d = compare(on, off)
    assert (t, i, d) == (1, 1, ["h"]), (t, i, d)
    print("check_libso_identity: self-test OK")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    d = tempfile.mkdtemp(prefix="libso_ident_")
    t, i, differ = compare(compile_umbrella(False, d), compile_umbrella(True, d))
    if differ:
        for n in differ:
            print("check_libso_identity: %s names no block but differs" % n)
        return 1
    print("check_libso_identity: clean (%d sections reach a block, %d others "
          "identical with blocks off)" % (t, i))
    return 0


if __name__ == "__main__":
    sys.exit(main())
