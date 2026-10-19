#!/usr/bin/env python3
"""curtrack_check -- the block cursor is WHERE THE CARET IS, in AttrBuf and on
the screen.

`vccursor' already counts inverse AttrBuf cells and asserts there is exactly
one.  Both defects this file was written for pass that count:

  1. THE STUCK CURSOR left exactly one inverse cell -- three columns behind the
     caret.  The echo seam (_FarSh_CdWrite, far_shims.s) hid nothing and leaned
     on _Con_WriteCharAtCursor retiring the record when a byte lands ON the
     drawn cell; BS, CR, LF and TAB move the caret and write no cell, so the
     record stayed live and Con_ShowCursor's idempotence refused to redraw.

  2. THE GHOST left AttrBuf perfect.  Con_HideCursor restored the cell named by
     the saved RING row and repainted the one named by the saved VIEWPORT row,
     so a scroll in between corrected the buffer and left the inverse block's
     PIXELS on screen permanently.

So a count is not the assertion; a POSITION is, and half of it has to be read
out of the framebuffer rather than out of AttrBuf.  Two arms:

  ATTR:  exactly one inverse AttrBuf cell, at the caret's ring cell.
  PIXEL: exactly one solid non-background cell in the visible 80x25, at the
         caret's SCREEN cell.

SHR GEOMETRY.  640 mode, 200 scanlines of 160 bytes, 80x25 text: a cell is 8
pixels wide (2 bytes) and 8 scanlines tall, so cell (row, col) is the 16 bytes
at (row*8 + y)*160 + col*2 for y in 0..7.  A blank cell renders as one repeated
byte -- background, or foreground when the inverse bit is set -- and no
printable glyph is uniform.  The background value is not assumed: it is the
uniform value the most cells share, which on a mostly-empty screen is the
screen's own background whatever the palette says.

THE CURSOR MUST BE OVER A BLANK for the pixel arm to mean anything -- an
inverse block over a glyph is not uniform and would not be counted.  The
sequence ends at a prompt with the caret on a blank, and CharBuf is checked to
say so: if it ever stops being true this reports a broken PREMISE rather than a
missing cursor, because a check whose test did not run looks like a pass.
"""
import json
import sys

INVERSE_BIT = 0x20
COLS      = 80
VIS_ROWS  = 25                     # CON_VIS_ROWS
BUF_ROWS  = 100                    # CON_BUF_ROWS
SHR_PITCH = 160                    # bytes per scanline in 640 mode
CELL_H    = 8                      # scanlines per text row
CELL_W    = 2                      # bytes per text cell

# curst is dumped from KFAR_VT_STATE+VT_CURS_RENDERED ($3B), 32 bytes.
CURST_BASE      = 0x3B
VT_CURS_RENDERED = 0x3B            # 1 B
VT_CURS_SAVED_COL = 0x3E           # 1 B
VT_TOP_ROW       = 0x4C            # 2 B
VT_CURS_SAVED_RROW = 0x4F          # 1 B
VT_BUF_ROWS      = 0x50            # 2 B
VT_CUR_ROW       = 0x52            # 2 B, VIEWPORT row
VT_CUR_COL       = 0x54            # 2 B


def _raw(mem, name):
    r = mem.get(name)
    if not r or not r.get("hex"):
        return None
    return bytes.fromhex(r["hex"])


def main(path):
    with open(path) as f:
        mem = json.load(f).get("memory", {})

    fails = []
    char = _raw(mem, "vc0char")
    attr = _raw(mem, "vc0attr")
    shr  = _raw(mem, "shr")
    st   = _raw(mem, "curst")

    # An unresolved region dumps addr 0 with an empty body.  Say so instead of
    # counting: reporting a stale pointer as a cursor bug sends the next reader
    # into the console engine for a harness problem (vccursor_check's lesson).
    for nm, buf, want in (("vc0char", char, BUF_ROWS * COLS),
                          ("vc0attr", attr, BUF_ROWS * COLS),
                          ("shr", shr, SHR_PITCH * VIS_ROWS * CELL_H),
                          ("curst", st, 32)):
        if buf is None:
            fails.append("%s: resolved to $%06X and captured NOTHING -- stale "
                         "pointer, not a claim about the cursor"
                         % (nm, (mem.get(nm) or {}).get("addr", 0)))
        elif len(buf) != want:
            fails.append("%s: dumped %d bytes, want %d -- a partial dump cannot "
                         "carry the claim" % (nm, len(buf), want))
    if fails:
        for f in fails:
            print("FAIL " + f)
        return 1

    b = lambda off: st[off - CURST_BASE]
    w = lambda off: st[off - CURST_BASE] | (st[off - CURST_BASE + 1] << 8)

    rendered = b(VT_CURS_RENDERED)
    top      = w(VT_TOP_ROW)
    bufrows  = w(VT_BUF_ROWS) or BUF_ROWS
    vprow    = w(VT_CUR_ROW)
    col      = w(VT_CUR_COL)
    ring     = (top + vprow) % bufrows

    print("caret: screen row %d, col %d (ring row %d, _conTopRow %d)"
          % (vprow, col, ring, top))
    print("record: rendered=%d saved ring row %d, saved col %d"
          % (rendered, b(VT_CURS_SAVED_RROW), b(VT_CURS_SAVED_COL)))

    if not rendered:
        fails.append("VT_CURS_RENDERED is 0 at an idle prompt -- no cursor is "
                     "drawn at all")
    if vprow >= VIS_ROWS or col >= COLS:
        fails.append("caret is at screen row %d col %d, outside the %dx%d "
                     "viewport -- the premise is broken, not the cursor"
                     % (vprow, col, VIS_ROWS, COLS))
        for f in fails:
            print("FAIL " + f)
        return 1

    # --- the premise: the caret is on a blank, so an inverse block there is a
    # UNIFORM cell in the framebuffer and the pixel arm can see it.
    caret_ch = char[ring * COLS + col]
    if caret_ch not in (0x20, 0x00):
        fails.append("CharBuf at the caret holds $%02X, not a blank -- the "
                     "pixel arm counts UNIFORM cells and an inverse block over "
                     "a glyph is not uniform, so this run cannot make the "
                     "claim.  Fix the sequence, do not relax the check."
                     % caret_ch)

    # --- arm 1: AttrBuf.
    cells = [i for i, v in enumerate(attr) if v & INVERSE_BIT]
    if len(cells) != 1:
        where = ", ".join("(ring row %d, col %d)" % (i // COLS, i % COLS)
                          for i in cells[:8])
        fails.append("ATTR: %d inverse cells, want exactly 1%s"
                     % (len(cells), (" -- at " + where) if cells else
                        " -- no cursor was ever drawn"))
    else:
        i = cells[0]
        if (i // COLS, i % COLS) != (ring, col):
            fails.append("ATTR: the inverse cell is at (ring row %d, col %d) "
                         "but the caret is at (ring row %d, col %d) -- the "
                         "cursor record is STRANDED at a cell the caret has "
                         "left.  A write that lands on the drawn cell retires "
                         "the record; BS, CR, LF and TAB move the caret and "
                         "write no cell, so the rail that echoes them has to "
                         "hide the cursor first (far_shims.s)."
                         % (i // COLS, i % COLS, ring, col))

    # --- arm 2: the pixels.
    uniform = {}
    for r in range(VIS_ROWS):
        for c in range(COLS):
            vals = set()
            for y in range(CELL_H):
                o = (r * CELL_H + y) * SHR_PITCH + c * CELL_W
                vals.add(shr[o])
                vals.add(shr[o + 1])
            if len(vals) == 1:
                uniform.setdefault(vals.pop(), []).append((r, c))
    if not uniform:
        fails.append("PIXEL: no uniform cell anywhere on screen -- not even a "
                     "background one.  The SHR dump is not the framebuffer this "
                     "check thinks it is.")
    else:
        bg = max(uniform, key=lambda v: len(uniform[v]))
        blocks = [rc for v, lst in uniform.items() if v != bg for rc in lst]
        print("pixels: background byte $%02X on %d cells, %d solid block(s)%s"
              % (bg, len(uniform[bg]), len(blocks),
                 (" at " + str(blocks[:8])) if blocks else ""))
        if len(uniform[bg]) < VIS_ROWS * COLS // 4:
            fails.append("PIXEL: the modal uniform value covers only %d cells, "
                         "too few to be the background -- the geometry or the "
                         "region is wrong, so the block count means nothing"
                         % len(uniform[bg]))
        elif len(blocks) != 1:
            fails.append("PIXEL: %d solid blocks on screen, want exactly 1%s.  "
                         "A block with no inverse AttrBuf cell behind it is a "
                         "GHOST: Con_HideCursor restored the cell named by the "
                         "saved RING row and repainted the one named by a saved "
                         "VIEWPORT row, and a scroll in between makes those two "
                         "different cells."
                         % (len(blocks), (" -- at " + str(blocks[:8]))
                            if blocks else ""))
        elif blocks[0] != (vprow, col):
            fails.append("PIXEL: the block on screen is at row %d col %d but "
                         "the caret is at row %d col %d"
                         % (blocks[0][0], blocks[0][1], vprow, col))

    if fails:
        for f in fails:
            print("FAIL " + f)
        return 1
    print("CURTRACK PASS: one cursor, in AttrBuf and on screen, at the caret "
          "(screen row %d, col %d)" % (vprow, col))
    return 0


# ---------------------------------------------------------------------------
def _dump(*, attr_cell=(43, 8), caret=(24, 8), top=19, blocks=((24, 8),),
          rendered=1, caret_char=0x20, shr_len=None, attr_cells=None):
    """A synthetic dump.json body.  `attr_cell' and `blocks' are the two things
    the arms disagree about; everything else exists so the arms can run."""
    ring = (top + caret[0]) % BUF_ROWS

    char = bytearray(b" " * (BUF_ROWS * COLS))
    char[ring * COLS + caret[1]] = caret_char

    attr = bytearray(BUF_ROWS * COLS)
    for rc in (attr_cells if attr_cells is not None else
               ([attr_cell] if attr_cell else [])):
        attr[rc[0] * COLS + rc[1]] = INVERSE_BIT

    shr = bytearray(SHR_PITCH * VIS_ROWS * CELL_H)   # all $00 = background
    for (r, c) in blocks:
        for y in range(CELL_H):
            o = (r * CELL_H + y) * SHR_PITCH + c * CELL_W
            shr[o] = shr[o + 1] = 0x55
    if shr_len is not None:
        shr = shr[:shr_len]

    st = bytearray(32)
    st[VT_CURS_RENDERED - CURST_BASE] = rendered
    st[VT_CURS_SAVED_COL - CURST_BASE] = attr_cell[1] if attr_cell else 0
    st[VT_TOP_ROW - CURST_BASE] = top & 0xFF
    st[VT_TOP_ROW - CURST_BASE + 1] = top >> 8
    st[VT_CURS_SAVED_RROW - CURST_BASE] = attr_cell[0] if attr_cell else 0
    st[VT_BUF_ROWS - CURST_BASE] = BUF_ROWS & 0xFF
    st[VT_CUR_ROW - CURST_BASE] = caret[0] & 0xFF
    st[VT_CUR_ROW - CURST_BASE + 1] = caret[0] >> 8
    st[VT_CUR_COL - CURST_BASE] = caret[1] & 0xFF
    st[VT_CUR_COL - CURST_BASE + 1] = caret[1] >> 8

    reg = lambda raw: {"addr": 0x030000, "hex": bytes(raw).hex()}
    return {"memory": {"vc0char": reg(char), "vc0attr": reg(attr),
                       "shr": reg(shr), "curst": reg(st)}}


def selftest():
    """Every case is a distinct thing this has to tell apart, and the two
    MEASURED failures are in it by their measured numbers -- a check that
    cannot reproduce the defect it was written for is not evidence."""
    import contextlib
    import io
    import json as _json
    import os
    import tempfile

    cases = [
        ("clean: one cursor, both arms agree", _dump(), 0),
        # 2026-09-01, `ls foo' erased back with three DELs: caret col 8, the
        # inverse cell left at col 11.
        ("MEASURED defect 1 -- the record stranded three columns back",
         _dump(attr_cell=(43, 11), blocks=((24, 11),)), 1),
        # 2026-09-01, _conTopRow 20: the block at screen row 22 that AttrBuf
        # does not explain, beside a correct one at the caret.
        ("MEASURED defect 2 -- a ghost block AttrBuf cannot explain",
         _dump(blocks=((24, 8), (22, 7))), 1),
        ("no cursor drawn at all", _dump(attr_cell=None, blocks=(),
                                         rendered=0), 1),
        ("two inverse cells", _dump(attr_cells=[(43, 8), (43, 11)]), 1),
        ("pixels right, AttrBuf cell on the wrong ring row",
         _dump(attr_cell=(44, 8)), 1),
        ("the caret is not on a blank -- premise, not cursor",
         _dump(caret_char=ord("x")), 1),
        ("a short SHR dump cannot carry the claim", _dump(shr_len=1000), 1),
    ]
    rc = 0
    for name, body, want in cases:
        with tempfile.NamedTemporaryFile("w", suffix=".json",
                                         delete=False) as f:
            _json.dump(body, f)
            p = f.name
        with contextlib.redirect_stdout(io.StringIO()):
            got = main(p)
        os.unlink(p)
        if got != want:
            print("SELFTEST FAIL: %s: returned %d, wanted %d"
                  % (name, got, want), file=sys.stderr)
            rc = 1
    if rc == 0:
        print("curtrack_check selftest: OK (%d cases)" % len(cases))
    return rc


if __name__ == "__main__":
    if sys.argv[1:2] in (["--self-test"], ["--selftest"]):
        sys.exit(selftest())
    sys.exit(main(sys.argv[1]))
