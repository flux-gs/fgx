#!/usr/bin/env python3
"""The argv caps agree, across every tracked file that carries a copy.

WHY THIS EXISTS.  `ARGS_MAX` bounds how many argv slots a binary's crt0 will
unpack, and it is written out more than once: as the definition in
toolchain/lib/args.s, and as the EQU tables the linkers write into every
program's link files (fgx_libso.DATA_EQUS, fgx_static.SEG0_EQUS, a
`("ARGS_MAX", "<n>")` pair in each).  The duplication is not avoidable -- crt0
lives in seg0 and its storage in seg1, and Merlin EQUs do not cross a segment
assembly -- so the copies are load bearing.

They had not agreed with the KERNEL since the kernel's cap was raised.  The
staging side accepts LSARGV_MAX argv entries and refuses more with a loud
EINVAL; crt0 stopped at ARGS_MAX = 8 and, past that, copied the string and then
silently declined to record a pointer -- so every argument between the two caps
was accepted by the kernel, laid into the child's frame, and dropped on arrival
with no diagnostic anywhere.  `echo` with twelve arguments printed seven, and a
shell loop over a glob quietly processed a prefix of its files (apple/fgx#300).

THE INVARIANT IS ARGS_MAX == LSARGV_MAX, not merely "the copies match".  Lower
and arguments vanish; higher and the storage is paid for and can never be
reached, because the kernel refuses first.  Either way the number that governs
is the smaller one, and a reader has no way to tell which it is.

SCOPE, stated rather than assumed: this checks the files that build SHIPPING
binaries.  The per-fixture link files under toolchain/tests/M* and
toolchain/bench/corpus carry their own copies and are left alone -- each is
internally consistent, they exercise the compiler rather than the argv path,
and pinning them here would make a fixture regeneration look like a defect.
"""
import os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# THE FILES ARE DISCOVERED AND NOT LISTED, and that is the whole difference
# between this checker working and this checker looking like it works: a
# hand-written list of copies goes stale the moment someone adds a binary
# with its own link file, and a stale list can silently miss a copy while
# the checker still reports clean.  A scan over GIT-TRACKED files cannot.
# GIT-TRACKED FILES ONLY, and that is the discriminator rather than a path
# pattern.  Most copies of these EQUs live in per-binary link files that the
# linkers GENERATE -- hundreds of them, gitignored, and stale for any tool the
# current build no longer produces.  Scanning those reports drift that is not
# drift.  What must agree is the SOURCES: the assembly that defines the cap and
# the Python tables the generated link files are written from.
SKIP_PARTS = ("tests/M", "bench/corpus", "docs/history")
SUFFIXES = (".s", ".s.in", ".py")
KERNEL = "src/kernel/far/loader.s"              # LSARGV_MAX, the staging cap

# ARGS_MAX bounds the argv VECTOR and must equal the kernel's staging cap.
#
# ARGS_INPUT_MAX IS GONE (apple/fgx#301, apple/fgx#438).  It bounded the argv
# TEXT crt0 copied into the binary's data bank, at 128 bytes for argv[0] plus
# every argument plus their NULs -- and the copy TRUNCATED silently when it did
# not fit, so a program ran on an argument its caller had not passed.  crt0
# copies nothing now: args_argv[i] points into the kernel's bank-0 frame, which
# is where 2.11BSD's argv points too.  Nothing reads the constant, so it is not
# checked; the linkers' EQU tables still carry a dead ARGS_INPUT_MAX, which is
# harmless.
NAMES = ("ARGS_MAX",)


def equ_in(text, name):
    """The value of `name EQU <n>` in this text, or of a linker's
    `("name", "<n>")` EQU-table pair, or None."""
    m = (re.search(r"^%s\s+EQU\s+(\d+)\s*(?:;.*)?$" % re.escape(name), text, re.M)
         or re.search(r'\(\s*"%s"\s*,\s*"(\d+)"\s*\)' % re.escape(name), text))
    return int(m.group(1)) if m else None


def tracked(root=ROOT):
    """The git-tracked .s / .s.in / .py files, minus the fixture trees."""
    try:
        out = subprocess.run(["git", "-C", root, "ls-files", "-z"],
                             capture_output=True, text=True)
        names = out.stdout.split("\0") if out.returncode == 0 else None
    except OSError:
        names = None
    if names is None:
        # No git here -- an exported tree, or the self-test's temp copy.  Walk
        # instead; the suffix and skip rules are the same, and without git's
        # ignore list the only extra files are generated ones this tree has
        # none of.
        names = []
        for dirpath, dirs, files in os.walk(root):
            dirs[:] = [d for d in dirs if d not in (".git", "build")]
            for fn in files:
                names.append(os.path.relpath(os.path.join(dirpath, fn), root)
                             .replace(os.sep, "/"))
    rels = []
    for rel in names:
        if not rel or not rel.endswith(SUFFIXES):
            continue
        if any(sk in rel for sk in SKIP_PARTS):
            continue
        rels.append(rel)
    return rels


def scan(root=ROOT):
    """rel -> {name: value} for every tracked file DEFINING one of the caps."""
    found = {}
    rels = tracked(root)
    if rels is None:
        return found
    for rel in rels:
        try:
            text = open(os.path.join(root, rel), encoding="utf-8",
                        errors="replace").read()
        except OSError:
            continue
        vals = {n: equ_in(text, n) for n in NAMES}
        vals = {n: v for n, v in vals.items() if v is not None}
        if vals:
            found[rel] = vals
    return found


def check(root=ROOT):
    errors = []
    found = scan(root)
    if not found:
        errors.append("no file defines any of %s -- the scan has drifted from "
                      "the tree, not the tree from the values" % (NAMES,))
        return errors, (None, None)

    for n in NAMES:
        seen = {r: v[n] for r, v in found.items() if n in v}
        if not seen:
            errors.append("%s is defined nowhere" % n)
            continue
        if len(set(seen.values())) > 1:
            where = ", ".join("%s=%d" % (r, v) for r, v in sorted(seen.items()))
            errors.append("%s disagrees across its copies: %s" % (n, where))

    ker = None
    kpath = os.path.join(root, KERNEL)
    if os.path.exists(kpath):
        ker = equ_in(open(kpath, encoding="utf-8", errors="replace").read(),
                     "LSARGV_MAX")
    am = None
    ams = {r: v["ARGS_MAX"] for r, v in found.items() if "ARGS_MAX" in v}
    if ams:
        am = sorted(set(ams.values()))[0]
    if ker is None:
        errors.append("%s: no `LSARGV_MAX EQU <n>` line" % KERNEL)
    elif am is not None and am != ker:
        errors.append(
            "ARGS_MAX (%d) != LSARGV_MAX (%d).  The SMALLER governs and a "
            "reader cannot tell which: below the kernel's cap, arguments it "
            "accepted and staged are dropped by crt0 with no diagnostic "
            "(apple/fgx#300); above it, storage is paid for that the kernel "
            "refuses to fill." % (am, ker))
    return errors, (am, ker)


def self_test():
    """A checker whose tool did not run looks like a pass, so prove it fails."""
    import tempfile, shutil
    tmp = tempfile.mkdtemp()
    try:
        files = sorted(scan())
        for rel in list(files) + [KERNEL]:
            d = os.path.join(tmp, os.path.dirname(rel))
            os.makedirs(d, exist_ok=True)
            shutil.copy(os.path.join(ROOT, rel), os.path.join(tmp, rel))
        if check(tmp)[0]:
            return "self-test: the unmodified tree does not pass"
        if len(files) < 2:
            return "self-test: found %d copies; the scan is not seeing the tree" % len(files)

        def bend(rel, val):
            p = os.path.join(tmp, rel)
            t = open(p).read()
            t = re.sub(r"^ARGS_MAX(\s+)EQU(\s+)\d+",
                       r"ARGS_MAX\1EQU\g<2>%d" % val, t, count=1, flags=re.M)
            t = re.sub(r'(\(\s*"ARGS_MAX"\s*,\s*")\d+"',
                       r'\g<1>%d"' % val, t, count=1)
            open(p, "w").write(t)

        # 1. one copy drifts -> caught
        withmax = [f for f in files if "ARGS_MAX" in scan(tmp).get(f, {})]
        orig = open(os.path.join(tmp, withmax[0])).read()
        bend(withmax[0], 4)
        if not any("disagrees" in e for e in check(tmp)[0]):
            return "self-test: a drifted copy was not caught"
        open(os.path.join(tmp, withmax[0]), "w").write(orig)

        # 2. one linker EQU-table copy (.py, tuple form) drifts -> caught
        pys = [f for f in withmax if f.endswith(".py")]
        if not pys:
            return "self-test: no tuple-form (.py) copy found to drift"
        orig = open(os.path.join(tmp, pys[0])).read()
        bend(pys[0], 4)
        if open(os.path.join(tmp, pys[0])).read() == orig:
            return "self-test: the tuple-form copy in %s was not bent" % pys[0]
        if not any("disagrees" in e for e in check(tmp)[0]):
            return "self-test: a drifted tuple-form copy was not caught"
        open(os.path.join(tmp, pys[0]), "w").write(orig)

        # 3. every copy moves together, away from the kernel -> still caught
        for f in withmax:
            bend(f, 4)
        if not any("LSARGV_MAX" in e for e in check(tmp)[0]):
            return "self-test: a consistent cap below the kernel's was not caught"
        return None
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        bad = self_test()
        if bad:
            print(bad); sys.exit(1)
        print("check_argv_caps self-test: OK"); sys.exit(0)
    errs, (am, ker) = check()
    if errs:
        print("ARGV CAP CHECK FAILED:")
        for e in errs:
            print("  - %s" % e)
        print("Fix: the copies are load-bearing (crt0 is seg0, its storage seg1, "
              "and Merlin EQUs do not cross a segment assembly).  Change all of "
              "them, and keep ARGS_MAX equal to the kernel's LSARGV_MAX.")
        sys.exit(1)
    print("check_argv_caps: OK (ARGS_MAX = %s across %d discovered file(s), "
          "equal to the kernel's LSARGV_MAX)" % (am, len(scan())))
