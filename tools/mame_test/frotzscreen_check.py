#!/usr/bin/env python3
"""frotzscreen check: the status line renders as a REVERSE-VIDEO bar.

The screen dump's per-row `scanlines` are palette indices, one digit per
pixel; '0' is the console's dark (blue) background.  A reverse status bar
is a LIGHT background with dark glyphs -- so text_row_0 (the status line)
has very few '0' pixels, while the normal text rows below it are almost
all '0' with a few lit glyph pixels.  Measured on a v3 story: the status
bar is ~3% dark, a text row ~85% dark.

Asserting that contrast makes frotzscreen a RENDERING gate, not just a
text-presence one: a regression that drew the status line in normal video
(losing the REVERSE_STYLE -> SGR path) leaves the status TEXT unchanged
but flips row 0 from mostly-light to mostly-dark, and this goes red.
"""
import json
import pathlib
import sys


def dark_fraction(row):
    s = "".join(row["scanlines"])
    return s.count("0") / len(s) if s else 1.0


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    sa = d.get("screen_analysis", {})
    r0 = sa.get("text_row_0")
    if not r0 or not r0.get("scanlines"):
        print("frotzscreen_check: INCONCLUSIVE -- no text_row_0 scanlines")
        return 2

    bar = dark_fraction(r0)
    # Control: the darkest text row the dump carries (rows 1..5), i.e. a
    # normal-video line.  Its darkness is what the bar must contrast with.
    ctrl = None
    for r in range(1, 6):
        rr = sa.get("text_row_%d" % r)
        if rr and rr.get("scanlines"):
            f = dark_fraction(rr)
            if ctrl is None or f > ctrl[1]:
                ctrl = (r, f)

    print("frotzscreen_check: status-bar dark %.2f; darkest control row %s"
          % (bar, ctrl))

    if bar > 0.5:
        print("frotzscreen_check: FAIL -- row 0 is dark; status line is not a "
              "reverse bar")
        return 1
    if ctrl is None or ctrl[1] < 0.5:
        print("frotzscreen_check: FAIL -- no dark text row to contrast the bar "
              "against (capture may be wrong)")
        return 1
    print("frotzscreen_check: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
