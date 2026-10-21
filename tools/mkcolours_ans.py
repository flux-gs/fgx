#!/usr/bin/env python3
"""mkcolours_ans -- write disk_src/testdata/colours.ans, an 80x25 colour chart.

`ansicat /testdata/colours.ans > /dev/ttyv3` fills the Second Sight card's
screen with every colour pair it can show, written as ANSI art writes them:

  row  0      title bar
  row  1      the foreground index of each column
  rows 2-17   the 16 x 16 matrix: background = row, foreground = column; each
              cell shows its VGA attribute byte bg<<4|fg in hex.  Bright
              foregrounds are ESC[1m, bright backgrounds ESC[5m (iCE colour),
              as ANSI.SYS art spells them.  At the right, the row's colour as
              a foreground in code page 437 blocks, with its name.
  row 19      the shade ramp $DB $B2 $B1 $B0 in each of the sixteen colours
  rows 20-23  a double-line box: SGR 7, 4, 38;5, 48;2 and 90-107 samples,
              then single-line box drawing, half blocks and the high glyphs
  row 24      footer, with no line end, so the screen does not scroll

Lines end in CR LF (ansicat sets LLITOUT, so the tty adds no CR), and none
reaches column 80, so no terminal's autowrap moves a row.  A ^Z and a SAUCE
record (80x25, iCE colour) follow.

Usage: tools/mkcolours_ans.py [output]
"""
import pathlib
import re
import sys

ESC = "\x1b["
NAMES = "blk red grn yel blu mag cyn wht".split()


def sgr(fg, bg):
    """The ANSI.SYS spelling of a colour pair: 30-37/40-47, bold, blink."""
    p = ["0"]
    if fg & 8:
        p.append("1")
    if bg & 8:
        p.append("5")
    p += [str(30 + (fg & 7)), str(40 + (bg & 7))]
    return ESC + ";".join(p) + "m"


def chart():
    rows = []
    title = " FGX colour chart -- 16 x 16, iCE colour, code page 437 "
    rows.append(sgr(15, 4) + title.center(79))
    rows.append(sgr(7, 0) + " bg " + "".join("  %X " % fg for fg in range(16)))
    for bg in range(16):
        r = sgr(7, 0) + " %X  " % bg
        for fg in range(16):
            r += sgr(fg, bg) + " %X%X " % (bg, fg)
        name = NAMES[bg & 7].upper() if bg & 8 else NAMES[bg & 7]
        r += sgr(7, 0) + "  " + sgr(bg, 0) + "\xdb\xdb\xb2\xb1\xb0 " + name
        rows.append(r)
    rows.append(sgr(7, 0))
    rows.append(sgr(7, 0) + "    " +
                "".join(sgr(c, 0) + "\xdb\xb2\xb1\xb0" for c in range(16)))

    box = sgr(11, 4)
    samples = [
        (ESC + "0;7;33;44m", " reverse "),
        (ESC + "0;4;37;40m", " underline "),
        (ESC + "0;38;5;196;40m", " 38;5;196 "),
        (ESC + "0;37;48;2;0;0;255m", " 48;2;0;0;255 "),
        (ESC + "0;95;104m", " 95;104 "),
        (ESC + "0;30;107m", " 30;107 "),
    ]
    inner = "".join(s + t for s, t in samples)
    width = sum(len(t) for _, t in samples)
    rows.append(box + "\xc9" + "\xcd" * 76 + "\xbb")
    rows.append(box + "\xba" + sgr(7, 1) + " " + inner +
                sgr(7, 1) + " " * (75 - width) + box + "\xba")
    glyphs = ("\xda\xc4\xc2\xbf \xc3\xc5\xb4 \xc0\xc1\xd9 \xb3 "
              "\xdc\xdf\xdd\xde\xfe "
              + "".join(chr(c) for c in range(0x80, 0xa8))
              + " " + "".join(chr(c) for c in range(0xe0, 0xf0)))
    rows.append(box + "\xba" + sgr(14, 1) + " " + glyphs[:75].ljust(75) +
                box + "\xba")
    rows.append(box + "\xc8" + "\xcd" * 76 + "\xbc")
    rows.append(sgr(8, 0) + " ansicat /testdata/colours.ans > /dev/ttyv3"
                .ljust(79) + ESC + "0m")
    assert len(rows) == 25
    return "\r\n".join(rows)


def sauce():
    rec = b"SAUCE00"
    rec += b"FGX colour chart".ljust(35) + b"FGX".ljust(20) + b"FGX".ljust(20)
    rec += b"20261021"
    rec += (0).to_bytes(4, "little")          # file size: unset
    rec += bytes([1, 1])                      # character, ANSi
    rec += (80).to_bytes(2, "little") + (25).to_bytes(2, "little")
    rec += bytes(4)                           # TInfo3, TInfo4
    rec += bytes([0, 1])                      # no comments; iCE colour
    rec += b"IBM VGA".ljust(22, b"\0")
    assert len(rec) == 128
    return rec


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                       pathlib.Path(__file__).resolve().parent.parent /
                       "disk_src/testdata/colours.ans")
    body = chart().encode("latin-1")
    for line in body.split(b"\r\n"):
        visible = len(re.sub(rb"\x1b\[[0-9;]*m", b"", line))
        assert visible <= 79, (visible, line[:40])
    out.write_bytes(body + b"\x1a" + sauce())


if __name__ == "__main__":
    main()
