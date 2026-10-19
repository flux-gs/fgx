#!/usr/bin/env python3
"""test_asm_archive -- fgx_ar's ASSEMBLY archives select what a tool reaches.

An --asm archive holds hand-written .s members (the long long runtime,
apple/fgx#447).  `select` must:

  - pull a member a root far-calls, and the member THAT one near-JSRs (the
    token scan sees the call, because the callee exports its name);
  - leave out a member nothing reaches;
  - concatenate the chosen code in ARCHIVE order, and their data fragments
    beside it, printing the ASM marker that says there is nothing to compile;
  - and `index` must refuse an --asm archive given a compiler, since nothing
    about it is compiled.

Every expectation has its failing twin in the same run: the unreached member
is checked absent as well as the reached ones present.
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
    "ma": ("                FGX2_EXPORT fa\n"
           "fa              ENT\n"
           "                JSR     hb\n"
           "                RTL\n",
           "a_cell          DA      0\n"),
    "mb": ("                FGX2_EXPORT hb\n"
           "hb              ENT\n"
           "                RTS\n", None),
    "mc": ("                FGX2_EXPORT fc\n"
           "fc              ENT\n"
           "                RTL\n", None),
}


def run(args, cwd):
    return subprocess.run([sys.executable, AR] + args, cwd=cwd,
                          capture_output=True, text=True)


def main():
    fails = []
    with tempfile.TemporaryDirectory() as d:
        paths = []
        for stem in ("ma", "mb", "mc"):
            code, data = MEMBERS[stem]
            p = os.path.join(d, stem + ".s")
            open(p, "w").write(code)
            if data:
                open(os.path.join(d, stem + ".data.s"), "w").write(data)
            paths.append(p)
        arc = os.path.join(d, "t.fgxa")
        r = run(["index", "--lib", "t", "--out", arc, "--asm"] + paths, d)
        if r.returncode:
            print(r.stderr)
            fails.append("index --asm failed")
        idx = json.load(open(os.path.join(arc, "index.json")))
        if not idx.get("asm"):
            fails.append("the index does not record the archive as assembly")

        root = os.path.join(d, "tool.s")
        open(root, "w").write("                FGX2_FARCALL fa\n")
        out = os.path.join(d, "out")
        r = run(["select", "--index", os.path.join(arc, "index.json"),
                 "--root", root, "--outdir", out, "--tool", "tool"], d)
        if r.returncode:
            print(r.stderr)
            fails.append("select failed")
        else:
            if r.stdout.strip() != os.path.join(out, "t.sel.s") + "\tASM":
                fails.append(f"select printed {r.stdout.strip()!r}, not the "
                             f"ASM marker line")
            code = open(os.path.join(out, "t.sel.s")).read()
            data = open(os.path.join(out, "t.sel.data.s")).read()
            if "fa              ENT" not in code:
                fails.append("the far-called member was not selected")
            if "hb              ENT" not in code:
                fails.append("the member reached only by a near JSR was not "
                             "selected")
            if "fc              ENT" in code:
                fails.append("a member nothing reaches was selected")
            if code.find("fa ") > code.find("hb ") >= 0:
                fails.append("the members are not in archive order")
            if "a_cell" not in data:
                fails.append("the selected member's data fragment is missing")

        r = run(["index", "--lib", "t2", "--out", os.path.join(d, "t2.fgxa"),
                 "--asm", "--cc", "./fcc"] + paths, d)
        if r.returncode == 0:
            fails.append("an --asm archive given --cc was accepted")

    for f in fails:
        print("  FAIL " + f)
    print("test_asm_archive: %s" % ("%d FAILURE(S)" % len(fails) if fails
                                    else "OK (reach through FARCALL and near "
                                         "JSR, unreached member left out, "
                                         "archive order, data, --cc refused)"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
