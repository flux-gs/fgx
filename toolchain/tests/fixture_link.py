#!/usr/bin/env python3
"""fixture_link.py - link one fcc fixture as fgx_static links a static
program: crt0_lib, the fixture's code and data, libfgx's program-mode
compile (build/static_libs, as the static set links it) and libc's
library-mode compile.  run.sh, run_runtime.py, the bench and the multibank
sweep all link through here.

An M-dir's optional _link.json adds files, paths relative to the repository
root:
    {"code": ["a.s"], "data": ["a_data.s"], "lib": [["l.s", "l.data.s"]]}
`code' and `data' join the program's own (never pruned); each `lib' pair is
pruned as libfgx is.

Run: fixture_link.py --mdir D --scratch S --code a.s[,b.s] --data a.data.s[,..]
                     --out F [--name N]
     exit 0 linked, 1 the link failed, 2 a library is not built
"""
import argparse
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
STATIC = os.path.join(REPO, "toolchain", "src", "ld", "fgx_static.py")
LIBFGX = ("build/static_libs/libfgx.s", "build/static_libs/libfgx.data.s")
# fgx_static's ffltpr, which it links into a program with no fltused marker.
FFLTPR = ("build/static_libs/ffltpr.s", "build/static_libs/ffltpr.data.s")
KEYS = ("code", "data", "lib")


def recipe(mdir):
    p = os.path.join(mdir, "_link.json")
    if not os.path.exists(p):
        return {k: [] for k in KEYS}
    r = json.load(open(p))
    bad = sorted(set(r) - set(KEYS))
    if bad:
        sys.exit("fixture_link: %s: unknown keys %s" % (p, ", ".join(bad)))
    return {k: r.get(k, []) for k in KEYS}


def command(mdir, scratch, code, data, out, name="fixture", code_segs=()):
    r = recipe(mdir)
    here = lambda p: os.path.join(os.path.abspath(mdir), p)
    repo = lambda p: os.path.join(REPO, p)
    libs = [LIBFGX] + [tuple(l) for l in r["lib"]]
    missing = [p for l in libs + [FFLTPR] for p in l if not os.path.exists(repo(p))]
    if missing:
        print("fixture_link: %s not built: run ninja first" % ", ".join(missing),
              file=sys.stderr)
        sys.exit(2)
    cmd = [sys.executable, STATIC, "--name", name, "--dir", os.path.abspath(scratch),
           "--code", ",".join([here(p) for p in code] + [repo(p) for p in r["code"]]),
           "--data", ",".join([here(p) for p in data] + [repo(p) for p in r["data"]]),
           "--out", os.path.abspath(out)]
    for c, d in libs:
        cmd += ["--lib", repo(c) + "," + repo(d)]
    for g in code_segs:
        cmd += ["--code-seg", ",".join(here(p) for p in g)]
    return cmd


def link(mdir, scratch, code, data, out, name="fixture", code_segs=()):
    r = subprocess.run(command(mdir, scratch, code, data, out, name, code_segs),
                       capture_output=True, text=True)
    return r.returncode == 0 and os.path.exists(out), r.stdout + r.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mdir", required=True)
    ap.add_argument("--scratch", required=True)
    ap.add_argument("--code", required=True)
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--name", default="fixture")
    a = ap.parse_args()
    ok, log = link(a.mdir, a.scratch, a.code.split(","), a.data.split(","),
                   a.out, a.name)
    sys.stdout.write(log)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
