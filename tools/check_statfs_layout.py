#!/usr/bin/env python3
"""check_statfs_layout.py - the kernel's struct statfs and userland's must
describe the same 100 bytes.

THE SAME ARGUMENT AS check_stat_layout.py, one struct along.  SYS_STATFS and
SYS_GETFSSTAT copy `struct statfs' out of the kernel and df(1) reads it
directly, so the two declarations are a WIRE FORMAT: a member added, widened or
reordered on one side shifts every member after it, and nothing says so.

AND IT WAS ALREADY WRONG.  Until 2026-09-05 the kernel copy
(src/kernel/vfs/mount.h, 4.3BSD-Reno's field order, pinned at 100 bytes by
toolchain/tests/M37/vfslayout.c) and the userland copy
(toolchain/include/sys/mount.h) shared a NAME and nothing else: userland's was
58 bytes of 16-bit fields describing a ProDOS volume table, with no f_files or
f_ffree at all.  Nothing caught it because nothing had ever copied the kernel
struct out to a program.

BOTH SIDES ARE C HERE, which makes this checker simpler than the stat one --
there is no assembly DUM block to parse, just two struct bodies compared field
for field.  What is compared is field NAME, field WIDTH, field ORDER and the
total size.  Names must match exactly: unlike STX_/st_, neither side has a
prefix convention forcing them apart, so a rename on one side alone is a defect
and not a spelling difference.
"""
import re
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KHDR = os.path.join(ROOT, "src/kernel/vfs/mount.h")
KPRM = os.path.join(ROOT, "src/kernel/vfs/fsparam.h")   # mount.h's MNAMELEN
UHDR = os.path.join(ROOT, "toolchain/include/sys/mount.h")

# fcc's model: int and short are 16 bits, long is 32, pointers are 4.  The same
# table check_stat_layout.py carries, and for the same reason -- it is why
# 2.11BSD rather than Reno is the source for anything with an int in it.
CWIDTH = {
    "short": 2, "unsigned short": 2, "u_short": 2,
    "int": 2, "unsigned int": 2, "unsigned": 2,
    "long": 4, "unsigned long": 4,
    "char": 1, "unsigned char": 1,
}


def fields(text, what="statfs", also=""):
    """struct <what>'s members, in order: [(name, width)].

    An unknown type yields a width of None rather than a guess -- a checker
    that quietly skips what it cannot read is the failure mode this file
    exists to prevent, so it must be reported instead.

    `also' is text to search for macros the struct's own file does not define.
    The kernel's mount.h takes MNAMELEN from fsparam.h, and on this checker's
    first run that was reported as an unsizable member rather than skipped --
    which is the behaviour above working, one revision early.
    """
    m = re.search(r"struct\s+" + what + r"\s*\{(.*?)\}\s*;", text, re.S)
    if not m:
        return []
    out = []
    for line in m.group(1).split("\n"):
        line = re.sub(r"/\*.*?\*/", "", line).strip()
        if not line or line.startswith("*") or line.startswith("/*"):
            continue
        d = re.match(r"^((?:unsigned\s+|u_)?\w+)\s+(\w+)"
                     r"(?:\s*\[\s*(\w+)\s*\])?\s*;", line)
        if not d:
            continue
        ctype = re.sub(r"\s+", " ", d.group(1)).strip()
        # An array member counts as its WHOLE extent.  The bound may be the
        # MNAMELEN macro rather than a literal, and both sides must agree on
        # its value too, so it is resolved from the file it appears in.
        n = 1
        if d.group(3):
            n = (int(d.group(3)) if d.group(3).isdigit()
                 else macro(text + also, d.group(3)))
        if ctype not in CWIDTH or n is None:
            out.append((d.group(2), None))
        else:
            out.append((d.group(2), CWIDTH[ctype] * n))
    return out


def macro(text, name):
    """`#define <name> <int>' in this file, or None."""
    m = re.search(r"^#define\s+" + re.escape(name) + r"\s+(\d+)", text, re.M)
    return int(m.group(1)) if m else None


def compare(k, u):
    bad = []
    if not k:
        bad.append("no struct statfs found in src/kernel/vfs/mount.h")
    if not u:
        bad.append("no struct statfs found in toolchain/include/sys/mount.h")
    if bad:
        return bad
    for side, fs in (("kernel", k), ("userland", u)):
        for name, w in fs:
            if w is None:
                bad.append(f"{side} statfs: f_{name.removeprefix('f_')} has a "
                           f"type or array bound this checker cannot size")
    if bad:
        return bad
    if len(k) != len(u):
        return [f"field COUNT differs: kernel has {len(k)} "
                f"({', '.join(n for n, _ in k)}); userland has {len(u)} "
                f"({', '.join(n for n, _ in u)})"]
    for i, ((kn, kw), (un, uw)) in enumerate(zip(k, u)):
        if kn != un:
            bad.append(f"field {i}: kernel says {kn}, userland says {un} -- "
                       f"ORDER and NAME must match")
        elif kw != uw:
            bad.append(f"field {i} ({kn}): kernel says {kw} byte(s), "
                       f"userland says {uw}")
    if not bad:
        tk, tu = sum(w for _, w in k), sum(w for _, w in u)
        if tk != tu:
            bad.append(f"total size differs: kernel {tk}, userland {tu}")
        elif tk != 100:
            # The M37 fixture asserts 100 and the syscall copies that many
            # bytes; a change here that agreed with itself would still be
            # wrong.  THREE places, so the constant is checked too.
            bad.append(f"struct statfs is {tk} bytes; "
                       f"toolchain/tests/M37/vfslayout.c pins it at 100 -- "
                       f"change both, or neither")
    return bad


def main():
    k = fields(open(KHDR).read(), also=open(KPRM).read())
    u = fields(open(UHDR).read())
    bad = compare(k, u)
    if bad:
        print("check_statfs_layout: FAIL")
        for b in bad:
            print("  " + b)
        return 1
    print(f"check_statfs_layout: clean ({len(k)} fields, "
          f"{sum(w for _, w in k)} bytes; kernel mount.h and sys/mount.h agree)")
    return 0


def self_test():
    """THE POSITIVE CONTROL.  A checker whose parser silently matches nothing
    passes every input, and reads exactly like a clean tree.  This one exists
    because a 58-byte struct sat opposite a 100-byte one for weeks, so its own
    blindness is precisely the risk."""
    good = ("#define MNAMELEN 32\n"
            "struct statfs {\n"
            "    short f_type;\n"
            "    short f_flags;\n"
            "    long  f_blocks;\n"
            "    char  f_mntonname[MNAMELEN];\n"
            "};\n")
    cases = [
        ("an agreeing pair passes", good, good, True),
        ("A WIDTH CHANGE IS CAUGHT -- the real 2026-09-05 defect, where "
         "userland declared int where the kernel declared long",
         good, good.replace("long  f_blocks;", "int   f_blocks;"), False),
        ("a REORDER is caught at the same total size",
         good, good.replace("    short f_type;\n    short f_flags;\n",
                            "    short f_flags;\n    short f_type;\n"), False),
        ("a RENAME is caught",
         good, good.replace("f_blocks", "f_bfree"), False),
        ("a MISSING field is caught",
         good, good.replace("    short f_flags;\n", ""), False),
        ("AN ARRAY BOUND THAT DISAGREES IS CAUGHT even though the member name "
         "and type match -- MNAMELEN is 32 in one tree and could be 90 in "
         "another, which is 58 bytes of silent shift",
         good, good.replace("#define MNAMELEN 32", "#define MNAMELEN 90"),
         False),
        ("a member the checker cannot size is REPORTED, not skipped",
         good, good.replace("long  f_blocks;", "quad_t f_blocks;"), False),
    ]
    fails = 0
    for name, ktext, utext, want_clean in cases:
        bad = compare(fields(ktext), fields(utext))
        got_clean = not bad
        # The size assertion is part of compare(); these fixtures are 40 bytes,
        # so a "clean" case still reports the 100-byte mismatch.  Judge on
        # everything EXCEPT that one line.
        bad = [b for b in bad if "pins it at 100" not in b]
        got_clean = not bad
        ok = got_clean == want_clean
        fails += not ok
        print(f"  [{'ok' if ok else 'FAIL'}] {name}")
        if not ok:
            print(f"         expected {'clean' if want_clean else 'a failure'},"
                  f" got {bad or 'clean'}")
    print(f"check_statfs_layout --self-test: "
          f"{len(cases) - fails}/{len(cases)} passed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
