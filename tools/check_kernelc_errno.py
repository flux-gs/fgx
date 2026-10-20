#!/usr/bin/env python3
"""check_kernelc_errno.py - kernel C's errno copies must equal errno.h's.

WHY THERE ARE TWO COPIES AT ALL.  Kernel C links no libc, so it cannot include
toolchain/include/errno.h; src/kernel/vfs/fsparam.h therefore restates the
values the VFS needs.  fsparam.h has said since it was written that "a second
copy of a number is a thing that drifts" -- and named THIS FILE as the thing
that stops it.

THIS FILE DID NOT EXIST until 2026-08-12.  The comment promised a check for
months and nothing enforced anything; the list was unguarded the whole time,
and two more entries (EINVAL, ENAMETOOLONG) were added to it on the strength of
that promise.  A comment asserting a guard is not a guard -- the same shape as
kc_sys.s asserting that KSVC_SLEEP routed to the uninterruptible sleep, which
it never did.

WHAT DRIFT LOOKS LIKE, and why it is worth a build step.  Nothing fails at
build time: the C compiles, the kernel links, and the wrong number simply
travels outward.  A VFS routine returns its ENOTDIR, the syscall layer hands
that integer to userland, and a shell prints the strerror of whatever errno
that value is on the OTHER side of the seam.  The bug surfaces as a wrong
message in a program nobody changed.

Usage:  check_kernelc_errno.py            (checks the tree)
        check_kernelc_errno.py --self-test
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ERRNO_H = "toolchain/include/errno.h"
# EVERY kernel-C header that restates an errno.  A list, not a path: the tty
# bank (apple/fgx#108) has its own param header for the same reason the VFS
# does, and a second copy that nothing compares is exactly the state this file
# exists to prevent.  Adding a bank is a row here.
KERNELC_H = ("src/kernel/vfs/fsparam.h",
             "src/kernel/tty/ttyparam.h")

# `#define ENOTDIR 20` with an optional trailing comment.  Only ALL-CAPS names
# beginning with E, which is what an errno is and what keeps MAXPATHLEN and the
# rest of fsparam.h's constants out of the comparison.
DEFINE_RE = re.compile(r'^\s*#define\s+(E[A-Z0-9_]*)\s+(\d+)\b')


def defines(text):
    out = {}
    for line in text.splitlines():
        m = DEFINE_RE.match(line)
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


def check(errno_text, kernelc_text):
    """-> list of complaints.  Empty means the copies agree."""
    truth = defines(errno_text)
    copy = defines(kernelc_text)
    bad = []
    for name in sorted(copy):
        if name not in truth:
            bad.append("%s = %d is not in errno.h at all -- kernel C invented "
                       "an errno, or errno.h dropped one" % (name, copy[name]))
        elif truth[name] != copy[name]:
            bad.append("%s: kernel C says %d, errno.h says %d"
                       % (name, copy[name], truth[name]))
    return bad, len(copy)


def main():
    with open(os.path.join(REPO, ERRNO_H), errors="ignore") as f:
        errno_text = f.read()

    rc, total = 0, 0
    for header in KERNELC_H:
        with open(os.path.join(REPO, header), errors="ignore") as f:
            kernelc_text = f.read()

        bad, n = check(errno_text, kernelc_text)
        total += n
        if not n:
            # An empty copy is not a pass.  If the regex stops matching -- the
            # file is reformatted, the names change shape -- this check would go
            # quiet and green while guarding nothing, which is the failure mode
            # it exists to prevent in the first place.
            print("error: %s declared NO errno values -- this check just "
                  "became vacuous. Fix the scan, do not delete the check."
                  % header, file=sys.stderr)
            rc = 1
            continue
        if bad:
            print("error: kernel C's errno copies in %s have drifted from %s:"
                  % (header, ERRNO_H), file=sys.stderr)
            for b in bad:
                print("  " + b, file=sys.stderr)
            print("\n  Kernel C links no libc and cannot include errno.h, so "
                  "%s\n  restates the values it needs.  errno.h is the truth; "
                  "fix the copy." % header, file=sys.stderr)
            rc = 1
    if rc:
        return rc
    print("kernelc errno OK (%d values across %d header(s), in sync with %s)"
          % (total, len(KERNELC_H), ERRNO_H))
    return 0


# ---------------------------------------------------------------------------
def selftest():
    truth = ("#define ENOENT 2\n"
             "#define EIO 5\n"
             "#define ENOTDIR 20\n"
             "#define EINVAL 22\n")
    cases = [
        ("in sync", "#define EIO 5\n#define ENOTDIR 20\n", 0),
        ("a value drifted", "#define EIO 5\n#define ENOTDIR 21\n", 1),
        ("kernel C invented one", "#define EIO 5\n#define EWEIRD 99\n", 1),
        # MAXPATHLEN and friends live in the same header and must not be
        # compared -- they have no errno.h counterpart and never will.
        ("non-errno constants ignored",
         "#define EIO 5\n#define MAXPATHLEN 128\n#define MAXNAMLEN 63\n", 0),
    ]
    rc = 0
    for name, copy, want in cases:
        bad, n = check(truth, copy)
        got = 1 if bad else 0
        if got != want:
            print("SELFTEST FAIL: %s: got %d, wanted %d (%s)"
                  % (name, got, want, bad), file=sys.stderr)
            rc = 1
    # ...and the vacuity guard itself.
    bad, n = check(truth, "/* no defines here at all */\n")
    if n != 0:
        print("SELFTEST FAIL: empty copy did not scan as empty", file=sys.stderr)
        rc = 1
    if rc == 0:
        print("check_kernelc_errno selftest: OK (%d cases + the vacuity guard)"
              % len(cases))
    return rc


if __name__ == "__main__":
    if sys.argv[1:2] in (["--self-test"], ["--selftest"]):
        sys.exit(selftest())
    sys.exit(main())
