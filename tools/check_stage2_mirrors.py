#!/usr/bin/env python3
"""check_stage2_mirrors -- stage 2's copies of kernel bank-0 cells are exact.

Stage 2 assembles standalone: it cannot include include/memmap.s, which
places the bank-0 cells the loader writes (KFGX_ANCHOR, KFGX_REST_COUNT, ...)
with DS inside a DUM block, so it declares each one as an absolute EQU.  The
values it can alias from include/config.s are aliases (check_bank0_geometry.py
enforces those); these cannot be, so this compares them instead.

Every EQU in src/boot/stage2.s whose comment names `memmap.s LABEL' must
equal LABEL's address in the core kernel's listing.  A mismatch means stage 2
writes a cell the kernel does not read, before any console exists to say so.

Usage:  check_stage2_mirrors.py <kernel listing> [<stage2.s>]
        check_stage2_mirrors.py --self-test
"""
import re
import sys

MIRROR = re.compile(r"^(\w+)\s+EQU\s+\$([0-9A-Fa-f]+)\s*;\s*memmap\.s\s+(\w+)",
                    re.M)
LISTED = re.compile(r"\|\s*([0-9A-Fa-f]{2})/([0-9A-Fa-f]{4})\s*:[^|]*\|\s*(\w+)\s+DS\b")


def mirrors(stage2_text):
    """[(name, value, memmap label)] for each declared mirror."""
    return [(m.group(1), int(m.group(2), 16), m.group(3))
            for m in MIRROR.finditer(stage2_text)]


def addresses(listing_text):
    """{label: 24-bit address} for every DS-placed label in the listing."""
    out = {}
    for m in LISTED.finditer(listing_text):
        out.setdefault(m.group(3), (int(m.group(1), 16) << 16) |
                       int(m.group(2), 16))
    return out


def check(stage2_text, listing_text):
    errs = []
    found = mirrors(stage2_text)
    if not found:
        errs.append("src/boot/stage2.s declares no `memmap.s LABEL' mirrors; "
                    "the comment convention this check keys on has changed")
    addr = addresses(listing_text)
    for name, val, label in found:
        if label not in addr:
            errs.append(f"stage2.s {name} mirrors memmap.s {label}, which the "
                        "kernel listing does not place")
        elif addr[label] != val:
            errs.append(f"stage2.s {name} EQU ${val:06X} but memmap.s places "
                        f"{label} at ${addr[label]:06X}")
    return errs


def _selftest():
    s2 = ("KFGX_ANCHOR     EQU     $00032C         ; memmap.s KFGX_ANCHOR -- x\n"
          "KFGX_REST_COUNT EQU     $000305         ; memmap.s KFGX_REST_COUNT\n")
    lst = (" 1 | 8 memmap.s 1 | Dum | 00 | | 1 | 00/0305 : 00 | "
           "KFGX_REST_COUNT   DS   1   ; c\n"
           " 2 | 8 memmap.s 2 | Dum | 00 | | 1 | 00/032C : 00 | "
           "KFGX_ANCHOR       DS   1   ; c\n")
    fails = 0
    if check(s2, lst):
        print("  SELFTEST FAIL: matching mirrors were reported:", check(s2, lst))
        fails += 1
    if not check(s2.replace("$00032C", "$0003CE"), lst):
        print("  SELFTEST FAIL: a drifted mirror was not caught")
        fails += 1
    if not check(s2, lst.replace("KFGX_ANCHOR ", "KFGX_MOVED  ")):
        print("  SELFTEST FAIL: a mirror of a label the kernel dropped passed")
        fails += 1
    if not check("", lst):
        print("  SELFTEST FAIL: a stage2 with no mirrors passed")
        fails += 1
    if fails:
        print(f"check_stage2_mirrors self-test: {fails} FAILURE(S)")
        return 1
    print("check_stage2_mirrors self-test: OK (match passes; drift, a dropped "
          "label and a vanished convention fail)")
    return 0


def main(argv):
    if argv[:1] in (["--self-test"], ["--selftest"]):
        return _selftest()
    if not 1 <= len(argv) <= 2:
        print(__doc__.rstrip(), file=sys.stderr)
        return 2
    listing = open(argv[0], errors="replace").read()
    stage2 = open(argv[1] if len(argv) == 2 else "src/boot/stage2.s",
                  errors="replace").read()
    errs = check(stage2, listing)
    if errs:
        print("check_stage2_mirrors: STAGE 2 MIRRORS DRIFTED:")
        for e in errs:
            print("  " + e)
        return 1
    print(f"    stage2 mirrors OK: {len(mirrors(stage2))} bank-0 cells match "
          "memmap.s")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
