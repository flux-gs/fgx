#!/usr/bin/env python3
"""sections.py -- fcc --sections marks units and changes nothing else.

For each library umbrella, compiles it with and without --sections and checks:
  1. stripping the FGX_SECT/FGX_ENDS rows from the --sections output gives the
     plain output byte for byte, code and data (the macros emit no bytes, so
     equal text is equal binaries);
  2. every function (`name ENT`) and every column-1 data label lies inside
     exactly one section, and a code section holds exactly one function;
  3. sections never nest and every FGX_SECT has its FGX_ENDS;
  4. every code section begins and ends in MX %00, so fgx_gc dropping one
     cannot change how Merlin assembles the next.

    python3 tests/sections.py            (from toolchain/)
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PILES = [
    ("lib/libc_c/libc_c.c", "-Ilib/libc_c"),
    ("lib/libfgx_c/libfgx.c", "-Ilib/libfgx_c"),
]
MARKS = ("FGX_SECT", "FGX_ENDS")


def compile_(src, inc, extra, d):
    base = os.path.join(d, os.path.basename(src)[:-2] + extra.replace("-", ""))
    s, ds = base + ".s", base + ".data.s"
    subprocess.run(["./fcc", "--pile", inc, src, "-o", s, "--data-segment", ds]
                   + ([extra] if extra else []), cwd=HERE, check=True,
                   capture_output=True)
    return open(s).read().split("\n"), open(ds).read().split("\n")


def is_mark(l):
    t = l.split()
    return bool(t) and t[0] in MARKS


def check_units(lines, what, code):
    errs, open_, ents, mx, start_mx = [], None, 0, "%00", None
    for i, l in enumerate(lines, 1):
        t = l.split()
        if t[:1] == ["FGX_SECT"]:
            if open_:
                errs.append("%s:%d: nested FGX_SECT" % (what, i))
            open_, ents, start_mx = t[1], 0, mx
            continue
        if t[:1] == ["FGX_ENDS"]:
            if not open_:
                errs.append("%s:%d: FGX_ENDS with none open" % (what, i))
            if code and ents != 1:
                errs.append("%s:%d: section %s holds %d functions"
                            % (what, i, open_, ents))
            if code and (start_mx != "%00" or mx != "%00"):
                errs.append("%s:%d: section %s MX %s..%s"
                            % (what, i, open_, start_mx, mx))
            open_ = None
            continue
        if len(t) >= 2 and t[0] == "MX":
            mx = t[1]
        if code and len(t) >= 2 and t[1] == "ENT":
            ents += 1
            if not open_:
                errs.append("%s:%d: %s ENT outside a section" % (what, i, t[0]))
        if (not code and l and l[0] not in " \t;*" and not open_):
            errs.append("%s:%d: data label %s outside a section"
                        % (what, i, t[0]))
    if open_:
        errs.append("%s: section %s never closed" % (what, open_))
    return errs


def main():
    errs = []
    with tempfile.TemporaryDirectory() as d:
        for src, inc in PILES:
            plain_s, plain_d = compile_(src, inc, "", d)
            sec_s, sec_d = compile_(src, inc, "--sections", d)
            for what, plain, sec, code in (
                    (src + " .s", plain_s, sec_s, True),
                    (src + " .data.s", plain_d, sec_d, False)):
                if [l for l in sec if not is_mark(l)] != plain:
                    errs.append("%s: stripped --sections output differs" % what)
                n = sum(1 for l in sec if l.split()[:1] == ["FGX_SECT"])
                e = check_units(sec, what, code)
                errs += e
                print("sections: %-32s %5d units%s"
                      % (what, n, "" if not e else "  %d error(s)" % len(e)))
    for e in errs[:30]:
        print("  " + e)
    print("sections: %s" % ("FAIL" if errs else "ok"))
    return 1 if errs else 0


sys.exit(main())
