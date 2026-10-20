#!/usr/bin/env python3
"""ssansi_check -- the card shows an ANSI art file's colours and code page.

`ansicat -b 9600 /testdata/ansi.ans > /dev/ttyv3` writes six rows to the
Second Sight card's console, each built to land one attribute byte on the
card -- the VGA attribute bg<<4 | fg, with the palette in ANSI order:

  row 0  ESC[1;33;44m BRIGHT          bold yellow on blue       $4B
  row 1  ESC[0;5;41m  BLINK           blink: the bright red bg  $97
  row 2  ESC[0m $DB $B0 $B1 $B2 $80   code page 437, 7 on 0     $07
  row 3  ESC[0;38;5;196m CUBE         256-colour 196, bright red $09
  row 4  ESC[0;48;2;0;0;255m RGB      24-bit blue background    $47
  row 5  ESC[33;42m ESC[8] ESC[0m DEF CSI 8 ] default, 3 on 2   $23

then a ^Z and a SAUCE record, which must not reach the screen.  ansicat
clears and homes first, so row v is the card's visible row v: mirror row
(start_line + v) mod 100.

The mirror's address is read from the module's log line and must match the
dumped region's, as sscon_check.py does, or the result is inconclusive; and
ttyv3's ring must hold BRIGHT, or the file never reached it.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import binascii
import json
import pathlib
import re
import sys

COLS, ROWS = 80, 100
CTRL_OFF = ROWS * COLS * 2
START_LINE = CTRL_OFF + 4

EXPECT = [
    (b"BRIGHT", 0x4B),
    (b"BLINK", 0x97),
    (bytes([0xDB, 0xB0, 0xB1, 0xB2, 0x80]), 0x07),
    (b"CUBE", 0x09),
    (b"RGB", 0x47),
    (b"DEF", 0x23),
]


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    mem = d.get("memory", {})
    missing = [n for n in ("klog", "mirror", "vc3chars")
               if not mem.get(n, {}).get("hex")]
    if missing:
        print(f"ssansi_check: INCONCLUSIVE -- regions missing or empty: "
              f"{missing}")
        return 2
    klog = binascii.unhexlify(mem["klog"]["hex"]).decode("latin1")
    m = re.search(r"cells at \$([0-9A-F]{2}):([0-9A-F]{4})", klog)
    if not m:
        print("ssansi_check: INCONCLUSIVE -- no 'cells at' line in the log")
        return 2
    said = (int(m.group(1), 16) << 16) | int(m.group(2), 16)
    at = mem["mirror"]["addr"]
    if said != at:
        print(f"ssansi_check: INCONCLUSIVE -- the module put the cells at "
              f"${said:06X}, the dump read ${at:06X}")
        return 2
    mirror = binascii.unhexlify(mem["mirror"]["hex"])
    ring = binascii.unhexlify(mem["vc3chars"]["hex"])
    if b"BRIGHT" not in ring:
        print("ssansi_check: INCONCLUSIVE -- ttyv3's ring does not hold "
              "BRIGHT; the file did not reach it")
        return 2
    sl = mirror[START_LINE]
    bad = 0
    for v, (text, attr) in enumerate(EXPECT):
        row = (sl + v) % ROWS
        cells = [(mirror[2 * (row * COLS + c)], mirror[2 * (row * COLS + c) + 1])
                 for c in range(len(text))]
        got = bytes(ch for ch, _ in cells)
        attrs = sorted({a for _, a in cells})
        ok = got == text and attrs == [attr]
        print(f"ssansi_check: row {v}: chars {got.hex()} want {text.hex()}; "
              f"attrs {[f'${a:02X}' for a in attrs]} want ${attr:02X}"
              f"{'' if ok else '  <-- WRONG'}")
        bad += not ok
    sauce = b"SAUCE" in ring
    print(f"ssansi_check: start_line {sl}; SAUCE in ttyv3's ring: {sauce}")
    if bad or sauce:
        print("ssansi_check: FAIL")
        return 1
    print("ssansi_check: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
