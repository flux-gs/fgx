#!/usr/bin/env python3
"""check_libc_link_sites.py -- catch a link site that still PUTs the WHOLE
42-member libc pile instead of the subset the archive walk selects for it.

THE FAILURE THIS EXISTS TO STOP
    libc used to be one pile: `PUT ../../toolchain/lib/libc_c.s` and every
    binary carried all 42 members.  The libc-breakup campaign replaced that
    with a per-binary dead-strip -- `fgx_ar select` walks the compiled code,
    emits a filtered aggregate, and the link file PUTs `libc.sel.s` instead.

    Conversion was done consumer by consumer, and the consumer LIST was
    assembled by reading the build.  That list was wrong three times:

      1. toolchain/tests/M*/_seg0.link.s -- the fcc fixture gate, which links
         through fixture_link.py (fgx_static) today.  This one was known:
         72 of 549 fixtures were already RED with
         "Object code size > 64 KB", which is the whole reason task 5 existed.

      2. toolchain/tests/multibank/ -- the far-pointer sweep.  NOT known, and
         it had ALREADY silently regressed: carving libc into members grew
         lib/libc_c.s by ~86 KB of text, which pushed the sweep's seg0 over
         the ceiling.  It builds clean at main and fails on the campaign
         branch.  Found only because tools/gate.sh happened to run it.

      3. toolchain/tests/run_runtime.py -- a hand-kept MIRROR of run.sh's
         link.  Found by a gate failure that did not look like a link failure
         at all: it built 240 fixtures in 1 second, staged 0, and reported
         "0/237 oracle-validated pass", i.e. 237 absences scored as 237
         regressions.

      4. tools/fas/ -- the FGX-hosted assembler.  Found by review, not by any
         check.  It absorbed the same +86 KB and still FIT, so nothing went
         red; its seg2 was 62,753 of 65,535 bytes, 2,782 bytes of headroom
         away from being instance 2 all over again.

WHY A TOOL AND NOT VIGILANCE
    Three of those four were found by accident, one of them only after it had
    been broken for a while, and the one that was merely CLOSE to the ceiling
    was invisible to every gate we run -- a site that still fits produces no
    signal at all until the day it does not.  "Does any tracked file still PUT
    the whole pile" is a one-line property.  Check it mechanically.

THE ESCAPE HATCH, AND ITS PRICE
    ALLOWLIST below.  Every entry carries the reason it is exempt.  An entry
    is a statement that someone looked at the site and concluded the whole
    pile is correct there -- today that is only DEAD link files, kept for
    their archaeology, that no build path reaches.  It is not a way to silence
    this check for a live consumer; a live consumer gets converted.

Usage:
    check_libc_link_sites.py [--self-test]
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# A Merlin PUT/ASM of the whole pile (code or data).  Column-1 `*` and `;`
# start a comment line, so a file that merely MENTIONS libc_c.s in its header
# -- several do, explaining why they no longer PUT it -- is not a hit.
PILE_RE = re.compile(r"^[^*;]*\b(?:PUT|ASM)\s+\S*\blibc_c(?:_data)?\.s\b")

# path -> why the whole pile is correct here.  Keep the reason specific enough
# that the next reader can re-check it.
ALLOWLIST = {
    # FGX1-era wrapper, superseded by fixture_link.py (fgx_static), which the
    # runner actually uses.  Nothing ASMs or PUTs it; kept as archaeology.
    "toolchain/tests/M*/_wrap_libc.s":
        "dead FGX1-era wrapper -- no build path reaches it",
    "toolchain/tests/M*/_wrap_ss.s":
        "dead FGX1-era wrapper -- no build path reaches it",
    "toolchain/tests/preproc/_wrap.s":
        "dead FGX1-era wrapper -- no build path reaches it",
}


def _fnmatch_any(path):
    import fnmatch
    for pat in ALLOWLIST:
        if fnmatch.fnmatch(path, pat):
            return True
    return False


def scan_text(text):
    """Line numbers (1-based) in `text` that PUT/ASM the whole pile."""
    return [i for i, ln in enumerate(text.splitlines(), 1) if PILE_RE.match(ln)]


def tracked_files():
    """git-tracked sources only.  Generated link files (build/*/seg2.link.s,
    the shells') are untracked, and checking a generated file would report the
    generator's bug at the wrong address."""
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT,
                         capture_output=True, text=True, check=True).stdout
    # This file is excluded from its own scan.  It necessarily quotes the very
    # lines it hunts -- in the header that explains the failure, and in the
    # self-test that proves the pattern still fires -- so scanning itself made
    # it report ITSELF as four unconverted link sites.  A checker whose only
    # finding is its own source is worse than none: the real hits are buried in
    # noise nobody can act on, and the reflex becomes to stop reading it.
    me = os.path.relpath(os.path.abspath(__file__), ROOT)
    return [p for p in out.split("\0")
            if p.endswith((".s", ".s.in", ".link.s", ".sh", ".py"))
            and p != me]


def main():
    if "--self-test" in sys.argv:
        assert scan_text("                PUT    ../../lib/libc_c.s") == [1]
        assert scan_text("                PUT    ../../lib/libc_c_data.s") == [1]
        assert scan_text("                ASM     ../../lib/libc_c.s") == [1]
        # comments, and the converted form, are not hits
        assert scan_text("*  libc.sel.s is the subset of libc_c.s ...") == []
        assert scan_text("; PUT-included by tests via libc_c.s") == []
        assert scan_text("                PUT    libc.sel.s") == []
        assert scan_text("# libc_c.s is CHECKED IN") == []
        assert _fnmatch_any("toolchain/tests/M22/_wrap_libc.s")
        assert not _fnmatch_any("toolchain/tests/M22/_seg0.link.s")
        print("check_libc_link_sites: self-test ok")
        return 0

    hits = []
    for rel in tracked_files():
        if _fnmatch_any(rel):
            continue
        try:
            text = open(os.path.join(ROOT, rel), errors="replace").read()
        except OSError:
            continue
        for ln in scan_text(text):
            hits.append((rel, ln))
    if hits:
        sys.stderr.write(
            "check_libc_link_sites: FAIL -- these PUT the WHOLE 42-member libc\n"
            "pile.  A program links libc through fgx_dyn (libc.so) or\n"
            "fgx_static (libc's library-mode compile).  Or add an ALLOWLIST\n"
            "entry WITH ITS REASON if the whole pile is correct here.\n")
        for rel, ln in hits:
            sys.stderr.write(f"  {rel}:{ln}\n")
        return 1
    print(f"check_libc_link_sites: clean ({len(ALLOWLIST)} allowlisted)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
