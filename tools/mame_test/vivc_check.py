#!/usr/bin/env python3
"""vivc_check -- vi drew a real screen on virtual console 2.

Reads VC1's own CharBuf (dumped via _kVcBank[2], since the harness displays a
different console) and requires three things of it:

  * the file's first line, so vi read and drew the buffer at all;
  * the file's second line ON A LATER ROW than the first -- this is the whole
    point.  The bug being guarded against emitted NUL instead of LF, so the
    cursor never advanced and every line landed on row 1.  Asserting only that
    the text appears SOMEWHERE would pass on that, because the last line written
    still lands, on top of all the others;
  * a column of tildes, vi's empty-line filler, on several distinct rows.

Row identity is what makes this discriminate, so every check below is about
WHICH row a thing is on, never merely whether it is present.
"""
import json
import sys

COLS = 80
ROWS = 25
# THE NEEDLES ARE THE FILE'S FIRST TWO LINES AND THEY MOVED ONCE.  They were
# "# name:passwd" and "root:", which was /etc/passwd's comment header and the
# line under it.  /etc/passwd is 2.11BSD's own now, comments stripped, so the
# first needle named a line that no longer exists and the second was the FIRST
# line rather than the second -- two failures from one file edit, neither of
# them about vi.  Both are taken from the shipped file, which is what makes
# them checkable: `head -2 disk_src/etc/passwd'.
LINE1 = "root:"
LINE2 = "daemon:"
MIN_TILDE_ROWS = 15


def rows_of(raw):
    out = []
    for r in range(ROWS):
        chunk = raw[r * COLS:(r + 1) * COLS]
        out.append("".join(chr(b) if 32 <= b < 127 else " " for b in chunk).rstrip())
    return out


def main(path):
    with open(path) as f:
        mem = json.load(f).get("memory", {})

    r = mem.get("vc1char")
    if r is None:
        print("FAIL vc1char region not dumped")
        return 1
    if not r.get("hex"):
        print("FAIL vc1char resolved to $%06X and captured NOTHING -- VC1 has no "
              "framebuffer bank, so this says nothing about vi"
              % r.get("addr", 0))
        return 1

    rows = rows_of(bytes.fromhex(r["hex"]))
    fails = []

    r1 = next((i for i, t in enumerate(rows) if t.startswith(LINE1)), None)
    r2 = next((i for i, t in enumerate(rows) if t.startswith(LINE2)), None)
    if r1 is None:
        fails.append("first file line (%r) is on no row" % LINE1)
    if r2 is None:
        fails.append("second file line (%r) is on no row" % LINE2)
    if r1 is not None and r2 is not None and r2 <= r1:
        fails.append("second file line is on row %d, not BELOW the first (row %d)"
                     " -- lines are not advancing" % (r2, r1))

    tilde_rows = [i for i, t in enumerate(rows) if t.strip() == "~"]
    if len(tilde_rows) < MIN_TILDE_ROWS:
        fails.append("tilde filler on %d rows, want >= %d (rows: %s)"
                     % (len(tilde_rows), MIN_TILDE_ROWS, tilde_rows))

    if fails:
        for f in fails:
            print("FAIL " + f)
        print("--- VC1 CharBuf ---")
        for i, t in enumerate(rows):
            if t.strip():
                print("%2d|%s" % (i, t))
        return 1

    print("VIVC PASS: file body on rows %d and %d, tilde filler on %d rows"
          % (r1, r2, len(tilde_rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
