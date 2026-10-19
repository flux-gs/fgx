#!/usr/bin/env python3
"""Generate src/drivers/console/console_font_3x5.s — a 3x5 glyph block
sized into a 4x6 cell for the 320-mode console.

Each glyph is 3 pixels wide × 5 tall.  The renderer reads 6 bytes per
glyph: 5 rows of glyph data + 1 trailing row of gap.  Each byte's top
nibble encodes that row's 4 horizontal pixels (3 glyph + 1 right-gap),
with bit 7 the leftmost pixel.  This packing matches the 4-bit input
of the BitsTo4bppMask LUT used by the 320 renderer.

Layout in the output table (Font_3x5):
  [char 32]  6 bytes  (space)
  [char 33]  6 bytes  (!)
  ...
  [char 127] 6 bytes  (DEL — unprintable, blank)
  Total: 96 × 6 = 576 bytes.

Unmapped glyphs render as a small filled-block "tofu".
"""
import argparse
import pathlib
import textwrap

# Each glyph is a 5-line string of "." (clear) / "#" (set), 3 cols wide.
# Lines outside that shape are stripped.  Use ".." padding on lines so
# alignment is obvious.  Missing glyphs auto-fill with TOFU.
GLYPHS = {
    " ": ".../.../.../.../...",
    "!": ".#./.#./.#./.../.#.",
    '"': "#.#/#.#/.../.../...",
    "#": "#.#/###/#.#/###/#.#",
    "$": ".##/##./.##/.##/##.",
    "%": "#.#/..#/.#./#../#.#",
    "&": ".#./#.#/.#./#.#/.##",
    "'": ".#./.#./.../.../...",
    "(": "..#/.#./.#./.#./..#",
    ")": "#../.#./.#./.#./#..",
    "*": "#.#/.#./#.#/.../...",
    "+": ".../.#./###/.#./...",
    ",": ".../.../.../.#./#..",
    "-": ".../.../###/.../...",
    ".": ".../.../.../.../.#.",
    "/": "..#/..#/.#./#../#..",
    "0": ".#./#.#/#.#/#.#/.#.",
    "1": ".#./##./.#./.#./###",
    "2": "##./..#/.#./#../###",
    "3": "###/..#/.#./..#/##.",
    "4": "#.#/#.#/###/..#/..#",
    "5": "###/#../##./..#/##.",
    "6": ".##/#../##./#.#/.#.",
    "7": "###/..#/.#./#../#..",
    "8": ".#./#.#/.#./#.#/.#.",
    "9": ".#./#.#/.##/..#/##.",
    ":": ".../.#./.../.#./...",
    ";": ".../.#./.../.#./#..",
    "<": "..#/.#./#../.#./..#",
    "=": ".../###/.../###/...",
    ">": "#../.#./..#/.#./#..",
    "?": ".#./#.#/.##/.../.#.",
    "@": ".#./#.#/###/#../.##",
    "A": ".#./#.#/###/#.#/#.#",
    "B": "##./#.#/##./#.#/##.",
    "C": ".##/#../#../#../.##",
    "D": "##./#.#/#.#/#.#/##.",
    "E": "###/#../##./#../###",
    "F": "###/#../##./#../#..",
    "G": ".##/#../#.#/#.#/.##",
    "H": "#.#/#.#/###/#.#/#.#",
    "I": "###/.#./.#./.#./###",
    "J": "..#/..#/..#/#.#/.#.",
    "K": "#.#/#.#/##./#.#/#.#",
    "L": "#../#../#../#../###",
    "M": "#.#/###/###/#.#/#.#",
    "N": "#.#/###/###/###/#.#",
    "O": ".#./#.#/#.#/#.#/.#.",
    "P": "##./#.#/##./#../#..",
    "Q": ".#./#.#/#.#/###/.##",
    "R": "##./#.#/##./#.#/#.#",
    "S": ".##/#../.#./..#/##.",
    "T": "###/.#./.#./.#./.#.",
    "U": "#.#/#.#/#.#/#.#/.#.",
    "V": "#.#/#.#/#.#/#.#/.#.",
    "W": "#.#/#.#/###/###/#.#",
    "X": "#.#/#.#/.#./#.#/#.#",
    "Y": "#.#/#.#/.#./.#./.#.",
    "Z": "###/..#/.#./#../###",
    "[": "###/#../#../#../###",
    "\\": "#../#../.#./..#/..#",
    "]": "###/..#/..#/..#/###",
    "^": ".#./#.#/.../.../...",
    "_": ".../.../.../.../###",
    "`": "#../.#./.../.../...",
    "a": ".../.##/.##/#.#/.##",
    "b": "#../##./#.#/#.#/##.",
    "c": ".../.##/#../#../.##",
    "d": "..#/.##/#.#/#.#/.##",
    "e": ".../.#./#.#/##./.##",
    "f": "..#/.#./###/.#./.#.",
    "g": ".../.##/#.#/.##/##.",
    "h": "#../#../##./#.#/#.#",
    "i": ".#./.../.#./.#./.#.",
    "j": "..#/.../..#/#.#/.#.",
    "k": "#../#.#/##./#.#/#.#",
    "l": ".#./.#./.#./.#./.#.",
    "m": ".../###/###/#.#/#.#",
    "n": ".../##./#.#/#.#/#.#",
    "o": ".../.#./#.#/#.#/.#.",
    "p": ".../##./#.#/##./#..",
    "q": ".../.##/#.#/.##/..#",
    "r": ".../#.#/##./#../#..",
    "s": ".../.##/##./.##/##.",
    "t": ".#./###/.#./.#./.##",
    "u": ".../#.#/#.#/#.#/.##",
    "v": ".../#.#/#.#/#.#/.#.",
    "w": ".../#.#/#.#/###/###",
    "x": ".../#.#/.#./.#./#.#",
    "y": ".../#.#/#.#/.##/##.",
    "z": ".../###/..#/#../###",
    "{": "..#/.#./##./.#./..#",
    "|": ".#./.#./.#./.#./.#.",
    "}": "#../.#./.##/.#./#..",
    "~": ".../.##/##./.../...",
}

TOFU = "###/###/###/###/###"

# DEC special-graphics block ($60..$7E, 31 glyphs).  These must tile across
# adjacent cells without the usual 1-pixel right-gap, so they use 4-pixel
# rows ("####" instead of "###").  Vertical strokes sit at column 1 so they
# line up between rows; horizontal strokes fill all 4 px to bridge cells.
# Unmapped DEC slots fall through to TOFU.
DEC_GLYPHS = {
    # Glyphs whose vertical stroke exits the bottom of the cell use a
    # 6-row pattern so the trailing pixel lands in the gap row, closing
    # the seam against the cell below (which starts at its own row 0).
    0x6A: ".#../.#../##../..../....",   # j  lower-right corner ┘
    0x6B: "..../..../##../.#../.#../.#..", # k  upper-right corner ┐ (descender)
    0x6C: "..../..../.###/.#../.#../.#..", # l  upper-left corner  ┌ (descender)
    0x6D: ".#../.#../.###/..../....",   # m  lower-left corner  └
    0x6E: ".#../.#../####/.#../.#../.#..", # n  cross              ┼ (descender)
    0x6F: "####/..../..../..../....",   # o  scan line 1 (top)
    0x70: "..../####/..../..../....",   # p  scan line 3
    0x71: "..../..../####/..../....",   # q  scan line 5 (middle, ─)
    0x72: "..../..../..../####/....",   # r  scan line 7
    0x73: "..../..../..../..../####",   # s  scan line 9 (bottom)
    0x74: ".#../.#../.###/.#../.#../.#..", # t  T-right ├ (descender)
    0x75: ".#../.#../##../.#../.#../.#..", # u  T-left  ┤ (descender)
    0x76: ".#../.#../####/..../....",   # v  T-up    ┴
    0x77: "..../..../####/.#../.#../.#..", # w  T-down  ┬ (descender)
    0x78: ".#../.#../.#../.#../.#../.#..", # x  vertical bar │ (descender)
    # Misc DEC chars that aren't line-drawing — leave as TOFU for now.
}


def encode_glyph(pattern: str) -> bytes:
    """Return 6 bytes for one glyph.

    Standard glyphs supply 5 rows of pixel data; row 5 (the gap row) is
    appended as $00.  Line-drawing glyphs with a vertical that exits the
    bottom of the cell supply a full 6 rows and drive the gap row
    explicitly, so the stroke tiles cleanly into the cell below.

    Rows of 3 chars set bits 7/6/5 (right-gap pixel bit 4 stays 0).
    Rows of 4 chars also drive bit 4, letting horizontal strokes tile
    cell-to-cell.
    """
    rows = pattern.split("/")
    if len(rows) not in (5, 6):
        raise ValueError(f"glyph must have 5 or 6 rows, got {len(rows)}: {pattern!r}")
    out = bytearray()
    for row in rows:
        if len(row) not in (3, 4):
            raise ValueError(f"row must be 3 or 4 cols, got {len(row)}: {row!r}")
        b = 0
        if row[0] == "#":
            b |= 0x80
        if row[1] == "#":
            b |= 0x40
        if row[2] == "#":
            b |= 0x20
        if len(row) == 4 and row[3] == "#":
            b |= 0x10
        out.append(b)
    if len(rows) == 5:
        out.append(0x00)  # gap row
    return bytes(out)


def emit_bin(glyphs, name: str) -> bytes:
    """Emit an FGXF v1 binary suitable for runtime load on the 320 console."""
    header = bytearray(48)
    header[0:4] = b"FGXF"
    header[4]   = 0x01           # version
    header[5]   = 4              # cell_w
    header[6]   = 6              # cell_h
    header[7]   = 0              # flags
    name_bytes  = name.encode("ascii")[:16]
    header[8:8+len(name_bytes)] = name_bytes
    # author / license left zero-filled
    body = bytearray()
    for code in range(32, 127):                  # 95 ASCII glyphs
        body.extend(encode_glyph(glyphs.get(chr(code), TOFU)))
    for code in range(0x60, 0x7F):               # 31 DEC graphics glyphs
        body.extend(encode_glyph(DEC_GLYPHS.get(code, TOFU)))
    assert len(body) == 126 * 6 == 756, len(body)
    return bytes(header) + bytes(body)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", required=True, help="output path (.s or .FNT)")
    ap.add_argument("--label", default="Font_3x5",
                    help="symbol name for the glyph table (default Font_3x5)")
    ap.add_argument("--upper-fallback", action="store_true",
                    help="emit uppercase shapes for the lowercase slots a-z "
                         "(legibility win for the 3-pixel-wide cell)")
    ap.add_argument("--bin", action="store_true",
                    help="emit FGXF v1 binary (.FNT) instead of Merlin .s")
    ap.add_argument("--font-name", default="3x5",
                    help="name field in the binary FGXF header (max 16 chars)")
    args = ap.parse_args()

    glyphs = dict(GLYPHS)
    if args.upper_fallback:
        for lo in "abcdefghijklmnopqrstuvwxyz":
            up = lo.upper()
            if up in GLYPHS:
                glyphs[lo] = GLYPHS[up]

    if args.bin:
        data = emit_bin(glyphs, args.font_name)
        pathlib.Path(args.out).write_bytes(data)
        print(f"wrote {args.out}: FGXF v1, {len(data)} bytes")
        return

    out_lines = [
        ";==============================================================================",
        f"; {pathlib.Path(args.out).name} — 96 ASCII printable glyphs at 3×5 in a 4×6 cell.",
        ";",
        "; AUTO-GENERATED by tools/gen_fnt_3x5.py — edit the GLYPHS table there.",
        ";",
        f"; Layout: {args.label} + (char - 32) * 6 → 6 bytes per glyph.",
        "; Byte format: top nibble = 4-pixel row (3 glyph + 1 right-gap=0),",
        "; bottom nibble = unused (reserved 0).  6 rows: 5 glyph + 1 bottom gap.",
        f"; Variant: {'upper-fallback (a-z = A-Z)' if args.upper_fallback else 'mixed case'}.",
        ";==============================================================================",
        "",
        args.label,
    ]

    # ASCII block: 95 glyphs for chars 32..126 (indices 0..94).
    for code in range(32, 127):
        ch = chr(code)
        pattern = glyphs.get(ch, TOFU)
        glyph = encode_glyph(pattern)
        bytes_str = ",".join(f"${b:02X}" for b in glyph)
        label = ch if 33 <= code <= 126 and ch not in ("'", '"', ";") else f"char {code}"
        out_lines.append(f"                DFB  {bytes_str}    ; idx {code-32:3d}  ASCII {code:3d}  {label}")

    # DEC special-graphics block: 31 glyphs for chars $60..$7E (indices 95..125).
    out_lines.append("                ; --- DEC special-graphics block (G-bit / SI charset) ---")
    for code in range(0x60, 0x7F):
        pattern = DEC_GLYPHS.get(code, TOFU)
        glyph = encode_glyph(pattern)
        bytes_str = ",".join(f"${b:02X}" for b in glyph)
        out_lines.append(f"                DFB  {bytes_str}    ; idx {95+(code-0x60):3d}  DEC ${code:02X}")

    out_lines.append("")
    out_lines.append(";==============================================================================")
    out_lines.append("; END console_font_3x5.s")
    out_lines.append(";==============================================================================")

    pathlib.Path(args.out).write_text("\n".join(out_lines) + "\n")
    total = 95 + 31
    print(f"wrote {args.out}: {total} glyphs × 6 bytes = {total*6} B")


if __name__ == "__main__":
    main()
