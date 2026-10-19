#!/usr/bin/env python3
"""check_port_shim_widths -- a port shim must not narrow a libc function.

apple/fgx#55.  FGX's ported BSD userland gets its BSD-shaped declarations from
per-port shim headers under src/userland/<tool>/.  Those shims are FGX-owned
code, and two mistakes in one of them silently corrupted every signal mask in
tcsh:

  1. `sigmask_t` was never typedef'd for this build.  Every typedef of it in
     tcsh's own sh.types.h sits behind a platform guard (`#ifdef sun`,
     `#ifdef __hpux`) and the build is -Dpdp11, so none is taken.  fcc is K&R,
     so the undeclared type name fell back to implicit `int` -- 16 bits.
  2. The shim re-declared `sigblock`/`sigsetmask` as K&R int-returning AFTER
     including <signal.h>, which declares them returning `long`.

Either one alone loses the top half of a 32-bit mask.  SIGCHLD is bit 19,
SIGTSTP 17, SIGCONT 18, so what got dropped was precisely the job-control
signals -- and nothing failed, warned, or looked wrong: the generated code just
stored one word where it had computed two.

WHY A CHECKER AND NOT A TEST.  There is no runtime symptom to assert.  A
narrowed mask does not crash; it silently unblocks a signal at a restore, and
the damage surfaces later as an unrelated race.  The only reliable moment to
catch it is at build time, against the declaration itself.

Exit 0 = clean, 1 = a shim narrows something.  --self-test proves the checker
can still fail (a checker that cannot fail is the defect it exists to prevent).
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# A K&R declaration list: `extern int foo(), bar();` -- the shape that carries
# no argument types and whose return type silently wins or loses against a
# prototype elsewhere in the same TU.
KR_EXTERN = re.compile(r"^\s*extern\s+(\w+)\s+([^;]*);", re.M)
NAME_IN_LIST = re.compile(r"(\w+)\s*\(\s*\)")

# Types a shim must never widen-then-narrow.  Keyed by the header that owns the
# real declaration.
LONG_DECL = re.compile(r"^\s*long\s+(\w+)\s*\(", re.M)


def long_returning(header):
    try:
        with open(header) as f:
            return set(LONG_DECL.findall(f.read()))
    except IOError:
        return set()


def shim_headers():
    root = os.path.join(REPO, "src", "userland")
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if name.endswith(".h"):
                yield os.path.join(dirpath, name)


def check_text(text, wide, path):
    """Findings for one shim's text.  Pure, so --self-test can drive it."""
    bad = []
    for rettype, decls in KR_EXTERN.findall(text):
        if rettype == "long":
            continue
        for name in NAME_IN_LIST.findall(decls):
            if name in wide:
                bad.append("%s: re-declares %s() as `%s`, but it returns "
                           "`long` -- a conflicting K&R declaration narrows "
                           "the value at some call sites and not others"
                           % (path, name, rettype))
    return bad


def main(argv):
    if "--self-test" in argv:
        wide = {"sigblock", "sigsetmask"}
        cases = [
            ("extern int sigvec(), sigblock();", 1, "the #55 shape"),
            ("extern int sigvec(), sigpause();", 0, "unrelated names"),
            ("extern long sigblock();", 0, "correctly widened"),
            ("extern int  sigvec();\nextern long sigpause();", 0, "the fix"),
        ]
        fails = 0
        for text, want, why in cases:
            got = len(check_text(text, wide, "t.h"))
            if got != want:
                print("SELFTEST FAIL (%s): %d findings, want %d" %
                      (why, got, want))
                fails += 1
        # The tcsh shim must carry a 32-bit sigmask_t.
        shim = os.path.join(REPO, "src/userland/tcsh/sys/signal.h")
        if os.path.exists(shim) and not has_wide_sigmask_t(open(shim).read()):
            print("SELFTEST FAIL: the real tcsh shim has no `typedef long "
                  "sigmask_t` -- the checker below would be asserting nothing")
            fails += 1
        if fails:
            return 1
        print("check_port_shim_widths self-test: clean")
        return 0

    wide = long_returning(os.path.join(REPO, "toolchain/include/signal.h"))
    if not wide:
        print("check_port_shim_widths: FAIL -- no long-returning declarations "
              "found in toolchain/include/signal.h.  Either the header moved "
              "or the pattern stopped matching; every check below would pass "
              "vacuously.")
        return 1

    bad = []
    n = 0
    for path in shim_headers():
        n += 1
        rel = os.path.relpath(path, REPO)
        with open(path) as f:
            bad += check_text(f.read(), wide, rel)

    shim = os.path.join(REPO, "src/userland/tcsh/sys/signal.h")
    if os.path.exists(shim):
        with open(shim) as f:
            if not has_wide_sigmask_t(f.read()):
                bad.append("src/userland/tcsh/sys/signal.h: no `typedef long "
                           "sigmask_t`.  tcsh's own sh.types.h only typedefs "
                           "it behind #ifdef sun / #ifdef __hpux, neither of "
                           "which this build takes, so without it fcc's K&R "
                           "implicit int makes every tcsh signal mask 16 bits "
                           "and every save/restore drops SIGCHLD, SIGTSTP and "
                           "SIGCONT (apple/fgx#55).")

    if bad:
        print("check_port_shim_widths: FAIL")
        for b in bad:
            print("  - %s" % b)
        return 1
    print("check_port_shim_widths: clean (%d shim headers, %d long-returning "
          "libc functions guarded)" % (n, len(wide)))
    return 0


def has_wide_sigmask_t(text):
    return re.search(r"typedef\s+long\s+sigmask_t\s*;", text) is not None


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
