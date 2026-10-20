#!/usr/bin/env python3
"""conpaint -- does the console's PIXEL screen show what its CharBuf says?

EVERY `screen_contains' IN THIS SUITE READS THE CHARBUF.  run.py decodes the
`charbuf' region into screen_text, so a console that stops painting looks
exactly like a healthy one to all of them: the buffer keeps filling while the
physical screen is frozen.  That is the hole this fills -- it reads the SHR
framebuffer and compares it, cell by cell, with the CharBuf rows the viewport
is showing.

THE FAILURES IT IS FOR.  A boot whose last writes scrolled once stopped one
row short of the shell prompt: every row present in the CharBuf, the pixels
showing the pre-scroll image (a deferred repaint a console read paid off;
removed, apple/fgx#534).  And a scroll inside a region, or downward, once moved
the pixels but not the cells, so the two disagreed until a repaint made the
pixels wrong too (apple/fgx#535, test `scrollrgn').

SHR GEOMETRY, as curtrack_check states it: 640 mode, 200 scanlines of 160
bytes, 80x25 text.  A cell is 8 pixels (2 bytes) wide and 8 scanlines tall,
so cell (row, col) is the 16 bytes at (row*8 + y)*160 + col*2, y in 0..7.  A
blank cell is one repeated byte; no printable glyph is uniform.  The
background is not assumed from the palette: it is the uniform value the most
cells share.

THE COMPARISON IS PER CELL, NOT PER ROW.  A row test passes on a lone cursor
block, and the stale screen this is for carries a full row of the WRONG text
-- so what is asserted is that every CharBuf character cell has ink under it,
and that the pixels carry no more than ONE inked cell the buffer does not
account for (the cursor).

Regions required, all sampled at the SAME moment: `shr' (012000, 32000),
`vc0char' (030000, 8000, conbank) and `toprow'
(KFAR_VT_STATE+VT_TOP_ROW).  `rstate' is reported when present.
"""
import json
import sys

COLS      = 80
VIS_ROWS  = 25
BUF_ROWS  = 100
SHR_PITCH = 160
CELL_H    = 8
CELL_W    = 2
CURSOR_ALLOWANCE = 1                   # the caret is one inked cell of its own


def _raw(mem, name):
    r = mem.get(name)
    if not r or not r.get("hex"):
        return None
    return bytes.fromhex(r["hex"])


def _cell(shr, row, col):
    out = []
    for y in range(CELL_H):
        off = (row * CELL_H + y) * SHR_PITCH + col * CELL_W
        out.extend(shr[off:off + CELL_W])
    return bytes(out)


def main(path):
    with open(path) as f:
        dump = json.load(f)
    mem = dump.get("memory") or {}
    shr = _raw(mem, "shr")
    # vc0char, not the plugin's `charbuf': this one can be sampled at the same
    # frame as the pixels.  Comparing an end-of-run buffer against earlier
    # pixels reports rows as unpainted that were simply written later.
    cb = _raw(mem, "vc0char") or _raw(mem, "charbuf")
    toprow = _raw(mem, "toprow")
    rstate = _raw(mem, "rstate")

    problems = []
    if not shr or len(shr) < SHR_PITCH * VIS_ROWS * CELL_H:
        problems.append("no `shr' region (012000, 32000 bytes)")
    if not cb or len(cb) < BUF_ROWS * COLS:
        problems.append("no `vc0char' region (030000, 8000 bytes, conbank)")
    if problems:
        for p in problems:
            print("PREMISE: " + p)
        return 2

    top = (toprow[0] | (toprow[1] << 8)) if toprow and len(toprow) >= 2 else 0
    if rstate:
        note = {2: "  (deferred: pixel work is being skipped)",
                3: "  (suspended: a bracket or SYS_SCREEN_CTL owns the screen)"}
        print("VT_RENDER_STATE = %d%s" % (rstate[0], note.get(rstate[0], "")))

    counts = {}
    for r in range(VIS_ROWS):
        for c in range(COLS):
            cell = _cell(shr, r, c)
            if len(set(cell)) == 1:
                counts[cell[0]] = counts.get(cell[0], 0) + 1
    if not counts:
        print("PREMISE: no uniform cell anywhere; cannot name a background")
        return 2
    bg = max(counts, key=counts.get)

    rows_with_text = 0
    fails = []
    for vr in range(VIS_ROWS):
        ring = (top + vr) % BUF_ROWS
        text = bytes(b & 0x7F for b in cb[ring * COLS:(ring + 1) * COLS])
        text = text.decode("ascii", "replace")
        chars = {c for c in range(COLS) if text[c] not in " \x00"}
        ink = {c for c in range(COLS) if set(_cell(shr, vr, c)) != {bg}}
        if chars:
            rows_with_text += 1
        missing = chars - ink
        extra = ink - chars
        if missing:
            fails.append("row %2d: %d of %d characters have NO pixels: %r"
                         % (vr, len(missing), len(chars), text.rstrip()[:50]))
        elif len(extra) > CURSOR_ALLOWANCE:
            fails.append("row %2d: %d inked cells the CharBuf does not account "
                         "for (a stale screen paints the row it used to show): %r"
                         % (vr, len(extra), text.rstrip()[:50]))

    if rows_with_text == 0:
        print("PREMISE: the viewport carries no text at all -- nothing to check")
        return 2
    print("viewport top row %d, %d rows carry text" % (top, rows_with_text))
    for f in fails:
        print("  " + f)
    if fails:
        print("FAIL: the screen does not show what the console buffer holds.")
        return 1
    print("PASS: every character in the viewport is painted.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
