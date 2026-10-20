#!/usr/bin/env python3
"""Anti-coincidence scan -- a per-build guard against FALSE GREEN.

Each fixture's canonical 4-byte tag global is named `cNN_g` (fcc mangles it to
`_cNN_g`).  A construct passes by reading its tag through the far pointer under
test; a WRONG bank byte reads the SAME offset in a DIFFERENT bank.  If that other
bank happens to hold the same 4 bytes at that offset, a wrong-bank read returns
the right value -> the fixture is silently blind (false green).

This scan reads every `_cNN_g` tag's offset from `ld/seg1_layout.s` and value
from `ld/seg1` (fgx_static's data segment), then checks that NO code bank
(`ld/seg0`, `ld/seg2`..., `ld/bank*`) holds that same 4-byte value at that same
offset.  Fail the build if any coincides -> fix by changing that fixture's tag.

Run from toolchain/tests/multibank/ after gen_sweep_link.py has linked
multibank.bin (ld/ holds fgx_static's link files).
"""
import os, re, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
TAG_LEN = 4
LABEL_RE = re.compile(r'^(_?c\d+_g)\s+EQU\s+\$([0-9A-Fa-f]+)', re.MULTILINE)


def read_bytes(path, off, n):
    try:
        with open(os.path.join(HERE, path), "rb") as f:
            f.seek(off)
            return f.read(n)
    except (OSError, ValueError):
        return b""


def main():
    layout = os.path.join(HERE, "ld", "seg1_layout.s")
    if not os.path.exists(layout):
        sys.exit("anti_coincidence: seg1_layout.s missing (run build_sweep.sh)")
    tags = LABEL_RE.findall(open(layout).read())
    if not tags:
        sys.exit("anti_coincidence: no _cNN_g tags in %s -- the scan would check nothing" % layout)

    ld = os.path.join(HERE, "ld")
    segs = sorted(os.path.relpath(p, HERE) for p in
                  glob.glob(os.path.join(ld, "seg[0-9]")) + glob.glob(os.path.join(ld, "seg[0-9][0-9]"))
                  + glob.glob(os.path.join(ld, "bank[0-9]")))
    segs = [s for s in segs if s != os.path.join("ld", "seg1")]
    if not segs:
        sys.exit("anti_coincidence: no code banks found in ld/ (run build_sweep.sh)")

    bad, unreadable = [], []
    for name, off_hex in tags:
        off = int(off_hex, 16)
        want = read_bytes(os.path.join("ld", "seg1"), off, TAG_LEN)
        if len(want) != TAG_LEN:
            unreadable.append((name, off))
            continue
        if want == b"\x00" * TAG_LEN:
            # Uninitialized tag: the fixture stores its (non-zero) tag at
            # RUNTIME, so the link-time image is all zeros -- nothing to
            # compare.  A non-zero runtime tag can never coincide with the
            # zero DS ballast filler (P3-2.6); coincidence against another
            # fixture's CODE bytes is out of this link-time scan's reach.
            continue
        for seg in segs:
            got = read_bytes(seg, off, TAG_LEN)
            if got == want:
                bad.append((name, off, seg, want.hex()))
    if unreadable:
        print("anti_coincidence: UNREADABLE TAG(S) -- could not read ld/seg1 at the tag's offset "
              "(the scan verified less than it claims):")
        for name, off in unreadable:
            print("    %s @ $%04X: could not read tag from seg1" % (name, off))
        return 1
    if bad:
        print("anti_coincidence: FALSE-GREEN RISK -- tag repeats at same offset in a code bank:")
        for name, off, seg, hx in bad:
            print("    %s @ $%04X == %s in %s (change this fixture's tag)" % (name, off, hx, seg))
        return 1
    print("  anti_coincidence: %d tag(s) unique across %d code bank(s) OK"
          % (len(tags), len(segs)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
