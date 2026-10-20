#!/usr/bin/env python3
"""check_man_overstrike -- a cat page's emphasis must be overstrike, not literal.

WHY THIS EXISTS (2026-09-12).  A `.0` page is nroff CAT output, and in that
format emphasis is OVERSTRIKE: `_\bX` is an underlined X and `X\bX` a bold one.
tools/man_preformat.py turns those runs into the SGR escapes the FGX console
renders.  A page written BY HAND, without the backspaces, carries the
underscores as ordinary text -- and man(1) then shows `_s_y_n_c` where the
reader expects an emphasised word.

Eighteen of FGX's own pages had it, every one of them hand-written rather than
vendored from 2.11BSD: sync(1) is where it was reported, and a scan found the
other seventeen.  Nothing could have noticed, because the page renders, the
build is silent, and only a reader sees it.

THE TEST IS A RUN, NOT AN UNDERSCORE.  `SYS_SYNC` and `hwaddr.conf` are
ordinary text and must stay that way, so an underscore glued to a word
character on its left is never a hit.  What this looks for is the shape the
mistake makes: two or more `_<alnum>` pairs in a row, standing free of the
words around them -- `_s_y_n_c`, `_P_A_T_H`, `-_d`.  A SINGLE pair is left
alone: it cannot be told from a filename fragment, and the emphasis it would
carry is one character.

Usage:
  check_man_overstrike.py                 # every page under MAN_DIR
  check_man_overstrike.py --self-test
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN_DIR = os.path.join(ROOT, "src", "userland", "man", "pages")

# Two or more `_<alnum>` pairs, not glued to a word character on either side.
# The left lookbehind also excludes a backspace, so a page that IS correct --
# `_\bs_\by` -- does not match its own second pair.
_LITERAL = re.compile(rb"(?<![\x08\w])((?:_[A-Za-z0-9]){2,})(?![\w])")


def violations(data):
    """[(byte offset, run)] for literal-underscore emphasis in one page."""
    return [(m.start(), m.group(1)) for m in _LITERAL.finditer(data)]


def _lineno(data, off):
    return data.count(b"\n", 0, off) + 1


def self_test():
    assert violations(b"     _s_y_n_c executes\n"), "plain run must be caught"
    assert violations(b"along $_P_A_T_H);\n"), "run after punctuation"
    # `-_d, -_t' is two SEPARATE single pairs, and singles are tolerated --
    # the run test is what keeps a filename fragment from being a hit.
    assert violations(b"the -_d, -_t flags\n") == []
    # The correct form is not a violation.
    assert violations(b"     _\x08s_\x08y_\x08n_\x08c executes\n") == []
    # Ordinary identifiers must never be flagged.
    assert violations(b"the SYS_SYNC primitive\n") == []
    assert violations(b"read /etc/hwaddr.conf and a_b_c_name here\n") == []
    assert violations(b"MNT_RDONLY|MNT_NOWAIT\n") == []
    # One pair alone is deliberately tolerated.
    assert violations(b"fsync(_2) on its descriptor\n") == []
    print("check_man_overstrike: self-test OK")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    if not os.path.isdir(MAN_DIR):
        print("check_man_overstrike: no man page tree at %s" % MAN_DIR,
              file=sys.stderr)
        return 1
    rc = 0
    pages = 0
    for dirpath, _dirs, files in os.walk(MAN_DIR):
        for name in sorted(files):
            if not name.endswith(".0"):
                continue
            path = os.path.join(dirpath, name)
            with open(path, "rb") as fh:
                data = fh.read()
            pages += 1
            for off, run in violations(data):
                rel = os.path.relpath(path, ROOT)
                print("check_man_overstrike: %s:%d: %s is literal text, not "
                      "emphasis -- a cat page spells it %s"
                      % (rel, _lineno(data, off), run.decode("latin1"),
                         run.decode("latin1").replace("_", "_\\b")),
                      file=sys.stderr)
                rc = 1
    if rc == 0:
        print("check_man_overstrike: clean (%d page(s); emphasis is "
              "overstrike everywhere)" % pages)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
