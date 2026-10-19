#!/usr/bin/env python3
"""sscon_check -- the Second Sight mirror equals its console's ring.

The sscon module keeps the card's cell buffer as a mirror of the 100-row
CharBuf ring of the console it displays, ttyv3 (VC_CARD): mirror row r, two
bytes a cell, is ring row r, and the card's start_line is that console's
VT_TOP_ROW.  This compares the two after a run that scrolled that console
several screens.  Characters only, and only where the cell's line-drawing
bit is off (those go through a CP437 table), compared as the eight-bit
bytes the card displays; the attribute byte is the card's own encoding and
the cursor cell carries a flipped one.

The ring is read from ttyv3's OWN bank (the harness's vcbank region), not
the SHR console's, and the top row from ttyv3's saved console block: that
console is never the one on the IIgs screen, so between writes its state
is in CON_VC_STATE block VC_CARD rather than live.

The mirror's address is READ FROM THE MODULE'S LOG LINE and must match the
dumped region's address; otherwise the region is not the mirror and the
result is inconclusive, not green -- a compare over the wrong bytes is the
vacuous pass this suite keeps finding.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import binascii
import json
import pathlib
import re
import sys

COLS, ROWS = 80, 100
VC_CARD = 3
VCS_SIZE = 0x80
VT_TOP_ROW = 0x4C
CTRL_OFF = ROWS * COLS * 2
START_LINE = CTRL_OFF + 4


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    mem = d.get("memory", {})
    need = ("klog", "mirror", "vc3chars", "vc3attrs", "vcstate")
    missing = [n for n in need if not mem.get(n, {}).get("hex")]
    if missing:
        print(f"sscon_check: INCONCLUSIVE -- regions missing or empty: "
              f"{missing} (an empty vc3 region means ttyv3 never wrote)")
        return 2
    klog = binascii.unhexlify(mem["klog"]["hex"]).decode("latin1")
    m = re.search(r"cells at \$([0-9A-F]{2}):([0-9A-F]{4})", klog)
    if not m:
        print("sscon_check: INCONCLUSIVE -- no 'cells at' line in the log")
        return 2
    said = (int(m.group(1), 16) << 16) | int(m.group(2), 16)
    at = mem["mirror"]["addr"]
    if said != at:
        print(f"sscon_check: INCONCLUSIVE -- the module put the cells at "
              f"${said:06X}, the dump read ${at:06X}")
        return 2
    mirror = binascii.unhexlify(mem["mirror"]["hex"])
    chars = binascii.unhexlify(mem["vc3chars"]["hex"])
    attrs = binascii.unhexlify(mem["vc3attrs"]["hex"])
    blocks = binascii.unhexlify(mem["vcstate"]["hex"])
    off = VC_CARD * VCS_SIZE + VT_TOP_ROW
    top = blocks[off] | (blocks[off + 1] << 8)
    bad = 0
    first = None
    for r in range(ROWS):
        for c in range(COLS):
            i = r * COLS + c
            if attrs[i] & 0x80:
                continue
            want = chars[i]             # the card takes $20-$FF raw
            if want < 0x20:
                want = 0x20
            got = mirror[2 * i]
            if got == 0:
                got = 0x20
            if got != want:
                bad += 1
                if first is None:
                    first = (r, c, want, got)
    sl = mirror[START_LINE]
    text = sum(1 for b in chars if 0x21 <= (b & 0x7F) <= 0x7E)
    print(f"sscon_check: {ROWS * COLS} cells compared, {bad} differ; "
          f"start_line {sl} vs ttyv3's VT_TOP_ROW {top}; {text} visible "
          f"characters in the ring; cells at ${at:06X}")
    if first:
        r, c, want, got = first
        print(f"sscon_check: first difference at ring row {r} col {c}: "
              f"ring ${want:02X} mirror ${got:02X}")
    if text < 200:
        print("sscon_check: INCONCLUSIVE -- ttyv3's ring holds almost "
              "nothing; the listings did not reach it")
        return 2
    if bad or sl != top:
        print("sscon_check: FAIL -- the card is not showing its console's ring")
        return 1
    print("sscon_check: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
