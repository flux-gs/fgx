#!/usr/bin/env python3
"""check_kernel_ceiling -- the kernel image must fit between FGX_CODE and FGX_DATA.

WHY THIS EXISTS (2026-07-31).  lib/build_common.sh:187 has enforced this since
the build.sh era, but the ninja build only lists that file as a DEPENDENCY INPUT
(gen.py) and never runs it.  So under ninja a kernel bank overrun linked
SILENTLY -- and the bank sat one byte under its ceiling on 2026-07-26.  A guard
that exists but never runs is indistinguishable from no guard at all.

THE CEILING IS DERIVED, NEVER COPIED.  It is FGX_DATA - FGX_CODE, parsed out of
include/kernel.s at check time.  build_common.sh hardcoded 57968 with a comment
claiming "$02EC40 - $020B00 = 57664" -- the comment had already drifted from the
constant it described, which is precisely what copying a number buys you.  Raise
FGX_CODE/FGX_DATA in include/kernel.s and this check follows for free.

Note the ceiling is the CODE region only.  memmap.s's own ERR guards separately
enforce that FGX_DATA's content fits below $02FE00; this check does not
duplicate them.

TWO IMAGES SINCE 2026-08-01.  The far kernel bank (bin/fgxfar.bin, geometry
FGX_KFAR_CODE..FGX_KFAR_DATA) is a SECOND statically linked image with its own
ceiling.  It gets the same treatment for the same reason: a second bank that
overran silently would be no better than the first one doing it.  See
docs/history/plans/far-kernel-bank.md.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KERNEL_S = os.path.join(ROOT, "include", "kernel.s")

# (label, binary, code-EQU, data-EQU).  A missing binary is only fatal for
# images marked required -- the far bank is optional until Task 1 lands it, and
# an absent OPTIONAL image is reported, never silently skipped.
IMAGES = [
    ("kernel", os.path.join(ROOT, "bin", "fgx.bin"),
     "FGX_CODE", "FGX_DATA", True),
    ("far   ", os.path.join(ROOT, "bin", "fgxfar.bin"),
     "FGX_KFAR_CODE", "FGX_KFAR_DATA", True),
    ("tty   ", os.path.join(ROOT, "bin", "fgxtty.bin"),
     "FGX_KTTY_CODE", "FGX_KTTY_DATA", True),
]

# FGX_CODE        EQU     $020B00         ; Kernel code start.
_EQU = r"^\s*{}\s+EQU\s+\$([0-9A-Fa-f]+)"


def _equ(text, name):
    m = re.search(_EQU.format(name), text, re.MULTILINE)
    if not m:
        raise SystemExit(
            f"check_kernel_ceiling: cannot find {name} in {KERNEL_S} -- the "
            f"constant was renamed or its EQU reformatted. Fix this parser "
            f"rather than deleting the check.")
    return int(m.group(1), 16)


def ceiling(text, code_name="FGX_CODE", data_name="FGX_DATA"):
    code, data = _equ(text, code_name), _equ(text, data_name)
    if data <= code:
        raise SystemExit(
            f"check_kernel_ceiling: {data_name} (${data:06X}) is not above "
            f"{code_name} (${code:06X}) -- the geometry in kernel.s is wrong.")
    return code, data, data - code


# An export-table bank's image opens with its ABI magic at offset 0.  Reading it
# back from the BUILT IMAGE is the only way to see a byte that got emitted
# BEFORE the bank root's ORG: the ORG resets Merlin's address counter, so the
# assembler's own view stays correct and only the file offset moves.  An `ERR`
# in the source cannot see this, and one was tried.
KFAR_MAGIC = 0x4B46             # include/kfar.s  KFAR_MAGIC, 'FK'
KTTY_MAGIC = 0x544B             # include/ktty.s  KTTY_MAGIC, 'KT'
MAGIC_BY_CODE = {
    "FGX_KFAR_CODE": KFAR_MAGIC,
    "FGX_KTTY_CODE": KTTY_MAGIC,
}


def head_is_magic(binary, code_name):
    """Export-table banks only: is the table still at image offset 0?"""
    want = MAGIC_BY_CODE.get(code_name)
    if want is None:
        return True
    with open(binary, "rb") as f:
        head = f.read(2)
    return len(head) == 2 and head[0] | (head[1] << 8) == want


def exceeds(size, limit):
    """THE decision, as a real function.

    It exists so the self-test can exercise the same code main() does.  The
    previous self-test asserted `not (limit + 1 > limit)` and
    `(limit - 1) > limit`, both constant-false -- it was testing arithmetic,
    not the checker, and would have passed against a checker that never
    rejected anything.
    """
    return size > limit


def _selftest():
    """Prove the checker can FAIL.  A gate that only ever passes is the defect
    it exists to catch, so silence is trusted only after this shows teeth."""
    sample = ("FGX_CODE        EQU     $021000   ; comment\n"
              "FGX_DATA        EQU     $02ED70   ; comment\n"
              "FGX_KFAR_CODE   EQU     $030000   ; comment\n"
              "FGX_KFAR_DATA   EQU     $03EC40   ; comment\n"
              "FGX_KTTY_CODE   EQU     $040000   ; comment\n"
              "FGX_KTTY_DATA   EQU     $04EC40   ; comment\n")
    fails = []

    code, data, limit = ceiling(sample)
    if (code, data, limit) != (0x021000, 0x02ED70, 0xDD70):
        fails.append(f"core parsed {code:#08x}/{data:#08x}/{limit}, want "
                     f"0x20c00/0x2ed70/57712")

    # The FAR geometry must parse independently -- a checker that silently fell
    # back to the core constants would report the far bank against the wrong
    # ceiling and pass an image that does not fit.
    fcode, fdata, flimit = ceiling(sample, "FGX_KFAR_CODE", "FGX_KFAR_DATA")
    if (fcode, fdata, flimit) != (0x030000, 0x03EC40, 0xEC40):
        fails.append(f"far parsed {fcode:#08x}/{fdata:#08x}/{flimit}, want "
                     f"0x30000/0x3ec40/60480")

    # ...and so must the TTY geometry, for the same reason: three images now
    # share one parser, and a bank whose constants silently fell back to
    # another's would be measured against the wrong ceiling.
    tcode, tdata, tlimit = ceiling(sample, "FGX_KTTY_CODE", "FGX_KTTY_DATA")
    if (tcode, tdata, tlimit) != (0x040000, 0x04EC40, 0xEC40):
        fails.append(f"tty parsed {tcode:#08x}/{tdata:#08x}/{tlimit}, want "
                     f"0x40000/0x4ec40/60480")

    # Every IMAGES row's EQUs must exist in the REAL kernel.s.  Without this a
    # new bank added to the table with a misspelled constant raises only on the
    # build that first produces its binary.
    with open(KERNEL_S, errors="replace") as f:
        real = f.read()
    for label, _binary, code_name, data_name, _req in IMAGES:
        try:
            ceiling(real, code_name, data_name)
        except SystemExit as e:
            fails.append(f"{label.strip()}: {code_name}/{data_name} not usable "
                         f"in the real {os.path.basename(KERNEL_S)} ({e})")

    # THE decision, exercised through the same function main() uses.
    if not exceeds(limit + 1, limit):
        fails.append("over-ceiling size not rejected")
    if exceeds(limit, limit):
        fails.append("exact-fit size wrongly rejected")
    if exceeds(limit - 1, limit):
        fails.append("under-ceiling size wrongly rejected")

    # A malformed kernel.s must raise, not silently pass.
    for label, text, names in (
            ("missing FGX_CODE", "nothing here\n", ("FGX_CODE", "FGX_DATA")),
            ("inverted core geometry",
             "FGX_CODE EQU $02ED70\nFGX_DATA EQU $020B00\n",
             ("FGX_CODE", "FGX_DATA")),
            ("missing FGX_KFAR_CODE", sample.replace("FGX_KFAR_CODE", "X_"),
             ("FGX_KFAR_CODE", "FGX_KFAR_DATA")),
            ("inverted far geometry",
             "FGX_KFAR_CODE EQU $03EC40\nFGX_KFAR_DATA EQU $030000\n",
             ("FGX_KFAR_CODE", "FGX_KFAR_DATA")),
    ):
        try:
            ceiling(text, *names)
            fails.append(f"{label} did not raise")
        except SystemExit:
            pass

    # THE DISPLACED-IMAGE ARM.  Driven on real bytes rather than the live
    # binary, so it proves the recognizer both ways even on a clean tree --
    # and a checker that only ever sees a correct image is the shape of guard
    # this file exists to argue against.
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        good = os.path.join(d, "good.bin")
        bad = os.path.join(d, "bad.bin")
        with open(good, "wb") as f:
            f.write(bytes([KFAR_MAGIC & 0xFF, KFAR_MAGIC >> 8]) + b"\0" * 30)
        # One stray byte in front: exactly what a pre-ORG DFB produces.
        with open(bad, "wb") as f:
            f.write(b"\0" + bytes([KFAR_MAGIC & 0xFF, KFAR_MAGIC >> 8])
                    + b"\0" * 30)
        if not head_is_magic(good, "FGX_KFAR_CODE"):
            fails.append("a correctly placed far export table was rejected")
        if head_is_magic(bad, "FGX_KFAR_CODE"):
            fails.append("a far image displaced by one byte was accepted -- "
                         "this is the failure that assembles GREEN")
        # The core kernel has no such table; it must not be checked for one.
        if not head_is_magic(bad, "FGX_CODE"):
            fails.append("the core kernel image was checked for KFAR_MAGIC")
        # ...and the tty bank must be checked for ITS OWN magic, not the far
        # bank's.  A MAGIC_BY_CODE row copied without changing the value would
        # pass every far-bank test and accept any tty image at all.
        tgood = os.path.join(d, "tgood.bin")
        with open(tgood, "wb") as f:
            f.write(bytes([KTTY_MAGIC & 0xFF, KTTY_MAGIC >> 8]) + b"\0" * 30)
        if not head_is_magic(tgood, "FGX_KTTY_CODE"):
            fails.append("a correctly placed tty export table was rejected")
        if head_is_magic(good, "FGX_KTTY_CODE"):
            fails.append("an image opening with KFAR_MAGIC was accepted as the "
                         "TTY bank -- the two magics are not distinguished")

    if fails:
        for f in fails:
            print(f"  {f}", file=sys.stderr)
        print(f"check_kernel_ceiling self-test: {len(fails)} FAILURE(S)")
        return 1
    print("check_kernel_ceiling self-test: OK (derives every ceiling from "
          "kernel.s, rejects overrun, rejects bad geometry, keeps the "
          "banks' magics apart, catches an export table displaced off image "
          "offset 0)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return _selftest()

    with open(KERNEL_S, errors="replace") as f:
        text = f.read()

    rc = 0
    for label, binary, code_name, data_name, required in IMAGES:
        code, data, limit = ceiling(text, code_name, data_name)
        try:
            size = os.path.getsize(binary)
        except OSError as e:
            # Reported, never silently skipped: a missing image looks exactly
            # like a passing one if the loop just continues.
            print(f"check_kernel_ceiling: cannot stat {binary}: {e}",
                  file=sys.stderr)
            if required:
                rc = 1
            continue

        if exceeds(size, limit):
            print(f"check_kernel_ceiling: {label.strip().upper()} IMAGE TOO "
                  f"LARGE -- {size} bytes exceeds the {limit}-byte code region "
                  f"({code_name} ${code:06X} .. {data_name} ${data:06X}) by "
                  f"{size - limit}.\n"
                  f"  Reclaim code, or move statics out of {data_name} to raise "
                  f"the ceiling (see docs/ROADMAP.md, kernel-bank code room, and "
                  f"docs/history/plans/far-kernel-bank.md). Raising {data_name} also means "
                  f"updating the link file's ORG and, for the core kernel, "
                  f"stage2's KERNEL_DEST/_LO in lockstep.", file=sys.stderr)
            rc = 1
            continue

        if not head_is_magic(binary, code_name):
            print(f"check_kernel_ceiling: {label.strip().upper()} BANK IMAGE IS "
                  f"DISPLACED -- {os.path.relpath(binary, ROOT)} does not open "
                  f"with its ABI magic (${MAGIC_BY_CODE[code_name]:04X}). "
                  f"Something PUT before that bank root's `ORG {code_name}` "
                  f"emitted bytes, and Merlin32 does not pad between ORGs: those bytes are now at the "
                  f"front of the image and the export table has shifted down "
                  f"by that many. The slot EQUs the core kernel bakes into its "
                  f"JSL operands did NOT shift, so every export call lands "
                  f"inside the wrong instruction, in a bank the core cannot "
                  f"see into.\n"
                  f"  Move the offending code AFTER the ORG. An `ERR` in the "
                  f"bank root cannot catch this -- the ORG resets the address "
                  f"counter, so only the file offset is wrong.", file=sys.stderr)
            rc = 1
            continue

        print(f"    {label} {size} B of {limit} ({limit - size} free)")
    return rc


if __name__ == "__main__":
    # sys.exit: main() RETURNS its status, and a check that cannot fail the
    # build is exactly the defect it exists to catch.
    sys.exit(main() or 0)
