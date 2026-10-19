#!/usr/bin/env python3
"""border_check -- the SHR border shows the colour of the console that has the
keyboard.

Each virtual console has a border colour of its own (`_vcBorderTbl',
src/kernel/ttyv.s), written into the low nibble of $C034 when the keyboard
moves: Option-1..3 switch the SHR screen and take the keyboard, Option-4
moves the keyboard alone to the card's console.  The IIgs screen then still
shows the console it showed, so the border is the one visible sign of where
the keys go.  This reads the `border' region (one byte at $E0C034; the high
nibble is the clock control and is ignored) and compares the low nibble with
VC_CARD's colour, 9 (orange), which is where ss4focus leaves the keyboard.

Exit 0 = pass, 1 = fail, 2 = inconclusive (no region).
"""
import json
import pathlib
import sys

VC_CARD_COLOUR = 9


def main(path="dump.json", want=None):
    d = json.loads(pathlib.Path(path).read_text())
    reg = d.get("memory", {}).get("border", {})
    if not reg.get("hex"):
        print("border_check: INCONCLUSIVE -- no 'border' region in the dump")
        return 2
    got = int(reg["hex"][:2], 16) & 0x0F
    want = VC_CARD_COLOUR if want is None else int(want)
    print(f"border_check: $C034 low nibble {got}, want {want}")
    if got != want:
        print("border_check: FAIL -- the border does not show the focused console")
        return 1
    print("border_check: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
