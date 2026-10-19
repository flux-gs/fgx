#!/usr/bin/env python3
"""Typing at a VC's `login:' prompt must not take the cursor away.  #255.

The cursor is one AttrBuf cell with the inverse bit ($20) OR-ed in
(Con_ShowCursor, console_char.s), so a console sitting at a prompt has exactly
ONE inverse cell -- the same countable property `vccursor_check.py' rests on.

THE COUNT ALONE IS NOT THE ASSERTION, and that is the point of this checker
rather than a second copy of vccursor's.  "One cursor before and one after"
is satisfied by a cursor that never moved, which is what a console that
ignored the keystroke entirely would show.  The claim is that the keystroke
was ECHOED and the cursor FOLLOWED it, so the column must advance by exactly
one and the row must not change.

GOES RED WITHOUT THE FIX: `_FarSh_CdWrite' -- the seam kernel C reaches the
chardev layer through, and therefore the seam every echoed keystroke takes
since the receive interrupt started running `ttyinput' at arrival time -- set
neither `_Sys_WrCdIdx' nor a `_Vc_WriteEnter' bracket.  The echoed byte
painted over the rendered cursor cell without hiding it first, which destroys
the inverse bit while leaving VT_CURS_RENDERED set; every later show is then a
no-op (console_char.s:286), including the one _Con_FlushDeferred does after a
full repaint.  Measured before the fix: 1 inverse cell at the prompt, 0 after
the first keystroke, and 0 for the rest of the line's life.
"""
import json
import sys

COLS = 80
BUF_ROWS = 100
INVERSE_BIT = 0x20

BEFORE = "vc1_before"
AFTER = "vc1_after"
LATE = "vc1_late"


def cursor_of(mem, name, fails):
    """The single inverse cell in `name', as (ring_row, col), or None."""
    r = mem.get(name)
    if r is None:
        fails.append("%s: region not dumped (add it to memory_regions)" % name)
        return None
    # An unresolved region dumps addr 0 and an empty body.  Reporting that as a
    # cursor bug sends the next reader into the console engine for what is a
    # harness problem -- vccursor_check.py draws the same distinction.
    if not r.get("hex"):
        fails.append("%s: resolved to $%06X and captured NOTHING -- stale "
                     "pointer, not a claim about the cursor"
                     % (name, r.get("addr", 0)))
        return None
    raw = bytes.fromhex(r["hex"])
    if len(raw) != BUF_ROWS * COLS:
        fails.append("%s: dumped %d bytes, want the whole %d-byte ring -- a "
                     "partial window drifts off the screen as the console "
                     "scrolls (apple/fgx#94)"
                     % (name, len(raw), BUF_ROWS * COLS))
        return None
    cells = [i for i, b in enumerate(raw) if b & INVERSE_BIT]
    if len(cells) != 1:
        where = ", ".join("(ring row %d, col %d)" % (i // COLS, i % COLS)
                          for i in cells[:8])
        fails.append("%s: %d inverse cells, want exactly 1%s"
                     % (name, len(cells), (" -- at " + where) if cells else
                        " -- the cursor is GONE, which is apple/fgx#255's "
                        "symptom exactly"))
        return None
    i = cells[0]
    return (i // COLS, i % COLS)


def main(path):
    with open(path) as f:
        mem = json.load(f).get("memory", {})

    fails = []
    before = cursor_of(mem, BEFORE, fails)
    after = cursor_of(mem, AFTER, fails)
    late = cursor_of(mem, LATE, fails)

    if before and after:
        if after[0] != before[0]:
            fails.append("the cursor changed ring row across one keystroke: "
                         "%s -> %s; the echo should have advanced the COLUMN"
                         % (before, after))
        elif after[1] != before[1] + 1:
            fails.append("the cursor did not follow the echoed character: "
                         "col %d -> %d, want %d.  A cursor that is present but "
                         "has not MOVED means the keystroke never reached the "
                         "screen, which this fixture must not report as a pass"
                         % (before[1], after[1], before[1] + 1))
    if after and late and after != late:
        fails.append("the cursor moved with nothing typed: %s -> %s"
                     % (after, late))

    if fails:
        for f in fails:
            print("FAIL: %s" % f)
        return 1
    print("vccurstype: cursor at %s before the keystroke, %s after -- present, "
          "and it followed the echo" % (before, after))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
