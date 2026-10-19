#!/usr/bin/env python3
"""check_libc_piles -- every fcc-built libc artifact must match its sources.

WHY THIS EXISTS (2026-07-31).  toolchain/lib/libc_c.s and libc_c_data.s are
GENERATED from toolchain/lib/libc_c/*.c by `make -C toolchain`, and the OS's
ninja graph consumes them as plain inputs it does not know how to build.
So editing libc_c.c and running `ninja all` reports "no work to do" and links
against the OLD pile -- an inconsistent tree that builds green.  That happened
during slice A: the fix had to be found by hand.

THE COMPILER IS A SOURCE (2026-08-14, apple/fgx#33).  A guard that watches
only a library's own .c files and headers misses an fcc codegen change: every
artifact goes stale while the fingerprint matches perfectly, which is exactly
the failure #33 describes -- artifacts sat four days behind the compiler, and
the tools linking them shipped assembly emitted by an older fcc.  Nothing
noticed, because nothing was watching the thing that had changed.

So toolchain/src/cc/* is part of every artifact's input set.  The consequence is
deliberate and worth stating plainly: AN FCC CHANGE FAILS THIS GUARD, and the
fix is to regenerate.  Usually the regenerated artifact is byte-identical and
only the sidecar moves -- that one-line diff is the receipt that someone
checked, which is the whole point.  A guard that stays green through the change
it exists to catch is not a guard.

WHY A GUARD AND NOT AN EDGE.  The piles are make's outputs, not ninja's:
toolchain/Makefile owns fcc and the rules that run it, and ninja's graph takes
the piles as inputs it cannot build.  So the OS build's job is to NOTICE a stale
pile and name the command that regenerates it (`make -C toolchain`).

WHY A FINGERPRINT AND NOT MTIME.  Same fresh-clone problem: git gives no useful
mtime ordering, so an mtime test false-positives on a clean checkout.  The
sidecar records a hash of the SOURCES that produced the current artifact, is
written by the same Makefile rule that writes the artifact.  That is
deterministic everywhere.

EACH PATTERN SET MUST BE A SUBSET OF ITS MAKE RULE'S PREREQUISITES.  If the
guard watches a file `make` does not, that file changing fails the build while
`make` reports nothing to do -- an unbreakable deadlock.  Watching FEWER files
than make is merely weaker; watching more is fatal.  toolchain/src/cc/* is
covered because every rule below has `fcc` as a prerequisite, and fcc is built
from those sources.
"""
import glob
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# fcc's own sources.  Folded into EVERY artifact's input set -- see the module
# docstring.  Reached through each rule's `fcc` prerequisite, so the subset rule
# above holds.
COMPILER = [
    "toolchain/src/cc/*.c",
    "toolchain/src/cc/*.h",
]

# name -> (sidecar, source patterns, the make target that regenerates it).  Patterns mirror toolchain/Makefile; see the docstring on why the
# direction of any mismatch matters.
ARTIFACTS = {
    "libc_c": {
        "sidecar": "toolchain/lib/libc_c.srcsha",
        # Mirrors the lib/libc_c.s rule.  arpa/ and netinet/ were missing until
        # 2026-07-31.
        "patterns": [
            "toolchain/lib/libc_c/*.c",
            "toolchain/include/*.h",
            "toolchain/include/sys/*.h",
            "toolchain/include/arpa/*.h",
            "toolchain/include/netinet/*.h",
        ],
        "make": "make libc_c",
        "what": "libc",
    },
    "libc_so": {
        "sidecar": "toolchain/lib/libc_so.srcsha",
        # Mirrors the lib/libc_so.s rule: libc_c's sources plus core.list.
        "patterns": [
            "toolchain/lib/libc_c/*.c",
            "toolchain/lib/libc_c/core.list",
            "toolchain/include/*.h",
            "toolchain/include/sys/*.h",
            "toolchain/include/arpa/*.h",
            "toolchain/include/netinet/*.h",
        ],
        "make": "make libc_so",
        "what": "libc library-mode compile",
    },
    # THE OTHER THREE PILES.  `make piles' builds libc_c, libfgx, libtermlib
    # and libcurses, and each is guarded on its own: an unguarded pile builds
    # green and ships stale (apple/fgx#137, found on libfgx).  The sidecars are
    # per-ARTIFACT, so two artifacts sharing a source directory do not cover
    # each other.
    #
    # Patterns mirror each rule in toolchain/Makefile exactly, and note what is
    # NOT there: these three rules take `include/*.h' only, not include/sys/ or
    # arpa/ or netinet/, which libc_c's rule does take.  Watching more files
    # than make is the fatal direction (see the docstring), so the difference is
    # deliberate rather than an oversight to tidy up.
    "libfgx": {
        "sidecar": "toolchain/lib/libfgx.srcsha",
        "patterns": [
            "toolchain/lib/libfgx_c/*.c",
            "toolchain/include/*.h",
        ],
        "make": "make libfgx",
        "what": "libfgx",
    },
    "libtermlib": {
        "sidecar": "toolchain/lib/libtermlib.srcsha",
        "patterns": [
            "toolchain/lib/libtermlib_c/*.c",
            "toolchain/include/*.h",
        ],
        "make": "make libtermlib",
        "what": "termlib",
    },
    "libcurses": {
        "sidecar": "toolchain/lib/libcurses.srcsha",
        "patterns": [
            "toolchain/lib/libcurses_c/*.c",
            "toolchain/include/*.h",
        ],
        "make": "make libcurses",
        "what": "curses",
    },
}


def fingerprint(name, root=ROOT):
    """Hash of (relative path, content) over one artifact's sources, sorted so
    the result does not depend on filesystem enumeration order."""
    h = hashlib.sha256()
    files = []
    for pat in ARTIFACTS[name]["patterns"] + COMPILER:
        files.extend(glob.glob(os.path.join(root, pat)))
    for path in sorted(files):
        rel = os.path.relpath(path, root)
        h.update(rel.encode())
        h.update(b"\0")
        with open(path, "rb") as f:
            h.update(f.read())
        h.update(b"\0")
    return h.hexdigest(), len(files)


def _selftest():
    """Prove the checker can FAIL: a fingerprint must change when a source
    changes -- INCLUDING a compiler source, which is the case apple/fgx#33 was
    -- and must be stable when nothing changes."""
    import shutil
    import tempfile
    fails = []
    tmp = tempfile.mkdtemp()
    try:
        d = os.path.join(tmp, "toolchain", "lib", "libc_c")
        os.makedirs(d)
        os.makedirs(os.path.join(tmp, "toolchain", "include", "sys"))
        cc = os.path.join(tmp, "toolchain", "src", "cc")
        os.makedirs(cc)
        src = os.path.join(d, "libc_c.c")
        with open(src, "w") as f:
            f.write("int x;\n")
        emit = os.path.join(cc, "emit.c")
        with open(emit, "w") as f:
            f.write("/* codegen */\n")
        a, n = fingerprint("libc_c", tmp)
        if n != 2:
            fails.append(f"expected 2 sources (library + compiler), saw {n}")
        b, _ = fingerprint("libc_c", tmp)
        if a != b:
            fails.append("fingerprint is not stable across two identical runs")
        with open(src, "w") as f:
            f.write("int y;\n")
        c, _ = fingerprint("libc_c", tmp)
        if a == c:
            fails.append("fingerprint did NOT change when a source changed")
        # THE apple/fgx#33 CASE: the library source is untouched and only the
        # compiler moved.  This is the assertion the old checker could not make.
        with open(emit, "w") as f:
            f.write("/* codegen, changed */\n")
        d2, _ = fingerprint("libc_c", tmp)
        if c == d2:
            fails.append("fingerprint did NOT change when a COMPILER source "
                         "changed -- this is apple/fgx#33 exactly")
        # A renamed file with identical bytes must also change the hash.
        os.rename(src, os.path.join(d, "other.c"))
        e, _ = fingerprint("libc_c", tmp)
        if d2 == e:
            fails.append("fingerprint did NOT change when a source was renamed")
        # Each artifact must hash a DIFFERENT input set; two artifacts sharing a
        # fingerprint would mean one of them is watching the wrong sources.
        seen = {}
        for nm in ARTIFACTS:
            fp, cnt = fingerprint(nm)
            if cnt == 0:
                fails.append(f"{nm}: matched no sources at all")
            if fp in seen:
                fails.append(f"{nm} and {seen[fp]} hash the same input set")
            seen[fp] = nm
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    if fails:
        for f in fails:
            print(f"  {f}", file=sys.stderr)
        print(f"check_libc_piles self-test: {len(fails)} FAILURE(S)")
        return 1
    print("check_libc_piles self-test: OK (stable, detects library edits, "
          "compiler edits and renames; artifacts watch distinct sources)")
    return 0


def _write(name):
    # FOOTGUN, and it drew blood on the day this was written: --write records
    # whatever is on disk RIGHT NOW.  Run it without having just regenerated the
    # artifact and it cheerfully blesses a stale one, leaving a green guard over
    # an inconsistent tree -- the exact condition it exists to catch.  The ONLY
    # sanctioned callers are the toolchain/Makefile recipes, which run fcc
    # immediately before.  Never invoke it by hand to "fix" a staleness failure;
    # run the make target the failure names.
    art = ARTIFACTS[name]
    have, n = fingerprint(name)
    with open(os.path.join(ROOT, art["sidecar"]), "w") as f:
        f.write(have + "\n")
    print(f"    {art['what']} fingerprint written ({n} sources)")
    return 0


def _check(name):
    art = ARTIFACTS[name]
    sidecar = os.path.join(ROOT, art["sidecar"])
    have, n = fingerprint(name)

    if not os.path.exists(sidecar):
        print(f"check_libc_piles: {art['sidecar']} is missing.  The "
              f"{art['what']} carries no fingerprint, so staleness cannot be "
              f"detected.  Run:  cd toolchain && {art['make']}",
              file=sys.stderr)
        return 0, 1

    with open(sidecar) as f:
        want = f.read().strip()

    if have != want:
        print(f"check_libc_piles: STALE {art['what']}.  Its sources -- or fcc "
              f"itself, which is one of them -- changed without the artifact "
              f"being regenerated, so this tree links against the OLD one.\n"
              f"  sources {have[:16]} != artifact {want[:16]}\n"
              f"  Fix:  cd toolchain && {art['make']}",
              file=sys.stderr)
        return 0, 1

    return n, 0


def main():
    if "--self-test" in sys.argv:
        return _selftest()

    if "--write" in sys.argv:
        i = sys.argv.index("--write")
        name = sys.argv[i + 1] if i + 1 < len(sys.argv) else None
        if name not in ARTIFACTS:
            print(f"check_libc_piles --write needs an artifact name, one of: "
                  f"{', '.join(sorted(ARTIFACTS))}", file=sys.stderr)
            return 1
        return _write(name)

    total = 0
    bad = 0
    for name in sorted(ARTIFACTS):
        n, err = _check(name)
        total += n
        bad += err
    if bad:
        return 1
    print(f"    {len(ARTIFACTS)} fcc artifacts in sync with {total} sources "
          f"(fcc included)")
    return 0


if __name__ == "__main__":
    # sys.exit: main() RETURNS its status, and a check that cannot fail the
    # build is exactly the defect it exists to catch.
    sys.exit(main() or 0)
