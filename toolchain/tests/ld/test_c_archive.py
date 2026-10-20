#!/usr/bin/env python3
"""test_c_archive -- fgx_ar's C archives write a selection even when it is empty.

A tool names its optional C archives (`"libs": "termlib"`) and the build
declares `<lib>.sel.s` / `<lib>.sel.data.s` for each one and links them,
whether or not the tool reaches a member.  `select` must therefore:

  - with a member reached: print `<lib>.sel.c<TAB><cc>` and keep that member's
    `#include`, dropping the unreached one;
  - with NOTHING reached: still print the line and write the filtered
    aggregate (no member includes, the umbrella's own lines kept), so the
    build compiles it into the files it links (apple/fgx#499);
  - and the empty run into the SAME outdir must replace the earlier selection,
    not leave it for the link to read.

Every expectation has its failing twin in the same run.
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TC = os.path.abspath(os.path.join(HERE, "..", ".."))
AR = os.path.join(TC, "src", "ld", "fgx_ar.py")

MEMBERS = {
    "ma": "                FGX2_EXPORT fa\nfa              ENT\n                RTL\n",
    "mb": "                FGX2_EXPORT fb\nfb              ENT\n                RTL\n",
}
AGGREGATE = 'int umbrella;\n#include "ma.c"\n#include "mb.c"\n'


def run(args, cwd):
    return subprocess.run([sys.executable, AR] + args, cwd=cwd,
                          capture_output=True, text=True)


def select(d, idx, root_text, out, fails, what):
    root = os.path.join(d, "tool.s")
    open(root, "w").write(root_text)
    r = run(["select", "--index", idx, "--root", root, "--outdir", out,
             "--tool", "tool"], d)
    if r.returncode:
        print(r.stderr)
        fails.append(f"{what}: select failed")
        return None
    sel_c = os.path.join(out, "t.sel.c")
    if r.stdout.strip() != sel_c + "\t./fcc --pile":
        fails.append(f"{what}: select printed {r.stdout.strip()!r}, not the "
                     f"compile line for t.sel.c")
        return None
    return open(sel_c).read()


def main():
    fails = []
    with tempfile.TemporaryDirectory() as d:
        paths = []
        for stem, code in MEMBERS.items():
            p = os.path.join(d, stem + ".s")
            open(p, "w").write(code)
            open(os.path.join(d, stem + ".c"), "w").write("")
            paths.append(p)
        agg = os.path.join(d, "t.c")
        open(agg, "w").write(AGGREGATE)
        arc = os.path.join(d, "t.fgxa")
        r = run(["index", "--lib", "t", "--out", arc, "--aggregate", agg,
                 "--cc", "./fcc --pile"] + paths, d)
        if r.returncode:
            print(r.stderr)
            fails.append("index failed")
        idx = os.path.join(arc, "index.json")
        json.load(open(idx))
        out = os.path.join(d, "out")

        full = select(d, idx, "                FGX2_FARCALL fa\n", out, fails,
                      "one member reached")
        if full is not None:
            if "ma.c" not in full:
                fails.append("the reached member's #include was dropped")
            if "mb.c" in full:
                fails.append("an unreached member's #include was kept")

        empty = select(d, idx, "                RTL\n", out, fails,
                       "nothing reached")
        if empty is not None:
            if "ma.c" in empty or "mb.c" in empty:
                fails.append("the empty selection still includes a member "
                             "(the earlier run's selection survived)")
            if "int umbrella;" not in empty:
                fails.append("the empty selection dropped the umbrella's own "
                             "lines")

    for f in fails:
        print("  FAIL " + f)
    print("test_c_archive: %s" % ("%d FAILURE(S)" % len(fails) if fails
                                  else "OK (reached member kept, unreached "
                                       "dropped, empty selection written and "
                                       "replaces the earlier one)"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
