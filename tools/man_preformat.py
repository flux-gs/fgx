#!/usr/bin/env python3
"""man_preformat.py - convert 2.11BSD nroff 'cat' man pages to FGX console form.

A BUILD-TIME host tool (run by ninja's manfmt rule, tools/ninja/gen.py).
Each input page is 2.11BSD nroff "cat" output -- teletype OVERSTRIKE markup
with LF line terminators:

    X\bX   (char, backspace, same char)        -> bold X
    _\bX   (underscore, backspace, char)        -> underlined X
    \t                                          -> column tab (8-col stops)

It is rewritten to the form the FGX SHR console actually renders:

  * Overstrike -> SGR escape sequences.  The console's VT parser
    (src/drivers/console/console_vthandler.s _Vt_ApplyOneSgr) handles SGR
    0/1/4/7/22/24/27, and the renderer (console_render.s) paints bold (bold
    font variant), underline (scanline-7 fill) and reverse distinctly.  We
    emit *distinct* bold/underline:
        bold       ESC[1m ... ESC[22m
        underline  ESC[4m ... ESC[24m
        line end   ESC[0m   (only if an attribute is still on)
    This is richer than the shipped ul(1), which collapses both to standout
    (ESC[7m) because the baked "fgx" termcap exposes only so/se -- not us/md.
    The host path emits the codes directly, so it isn't bound by that table.

  * Tabs expanded to spaces at 8-column stops.  Falls out of the column model
    below (the console does not tab-expand, so we must).

  * Lines stay LF-terminated.  FGX is LF-native: the console is a true VT and
    the kernel tty discipline does ONLCR (LF -> CR+LF) on cooked output, so
    more(1) writing page bytes renders each LF as one visible newline.

Why not clang-build our own ul(1) for this?  On the host, ul's tgetstr()
resolves against the *system* terminfo, not FGX's baked caps, so it would emit
the host terminal's sequences.  This script instead mirrors ul.c's column
model (col/maxcol + a per-cell bold/underline mode) so the overstrike parsing
is byte-identical to the on-device renderer, while emitting literal FGX codes.

Usage:  man_preformat.py <src-dir> <dst-dir>
  Converts every <src-dir>/*.0 to <dst-dir>/<name>.<N>, where the section
  digit N is the trailing digit of <dst-dir> (e.g. .../CAT1 -> "1"): grep.0 ->
  GREP.1.  The deployed pages follow the modern BSD formatted-page layout
  /usr/man/cat<N>/<name>.<N>; the raw 2.11BSD cat sources keep their authentic
  flat ".0" naming.  THE STAGED NAME IS LOWERCASE because man(1) does not
  case-fold and a 2.11BSD root does not either.
"""
import os
import sys

BOLD = 1
UNDER = 2

ESC = "\x1b"
SGR_BOLD = ESC + "[1m"
SGR_NOBOLD = ESC + "[22m"
SGR_UNDER = ESC + "[4m"
SGR_NOUNDER = ESC + "[24m"
SGR_RESET = ESC + "[0m"


def render_line(line):
    """One input line (no trailing LF) -> FGX bytes incl. a trailing CR.

    Mirrors ul.c filter()+flushln(): build a column buffer where each cell is
    [char, mode]; a backspace steps the cursor back so the next char overstrikes
    the cell, promoting it to bold (same char) or underline (an '_' meets a
    letter, in either order).  Then walk the columns emitting SGR runs.
    """
    cells = []          # cells[col] = [char, mode]; ' '/0 == untouched
    col = 0
    maxcol = 0

    def ensure(c):
        while len(cells) <= c:
            cells.append([" ", 0])

    for ch in line:
        o = ord(ch)
        if ch == "\b":
            if col > 0:
                col -= 1
            continue
        if ch == "\t":
            col = (col + 8) & ~7
            if col > maxcol:
                maxcol = col
            continue
        if ch == "\r":
            col = 0
            continue
        if o < 0x20:
            # Stray control (SO/SI/ESC half-line motions) -- these cat pages
            # carry none (verified: no form-feeds, no IESC), so drop defensively.
            continue
        ensure(col)
        cur, mode = cells[col]
        if cur == " " and mode == 0:
            cells[col] = [ch, 0]
        elif cur == "_" and ch != "_":
            cells[col] = [ch, mode | UNDER]
        elif ch == "_" and cur != "_":
            cells[col] = [cur, mode | UNDER]
        elif cur == ch:
            cells[col] = [ch, mode | BOLD]
        else:
            cells[col] = [ch, mode]     # different overstrike: last char wins
        col += 1
        if col > maxcol:
            maxcol = col

    out = []
    b_on = False
    u_on = False
    for i in range(maxcol):
        ch, mode = cells[i] if i < len(cells) else (" ", 0)
        want_b = bool(mode & BOLD)
        want_u = bool(mode & UNDER)
        # Turn attributes off before on so a mode change never lingers.
        if u_on and not want_u:
            out.append(SGR_NOUNDER)
            u_on = False
        if b_on and not want_b:
            out.append(SGR_NOBOLD)
            b_on = False
        if want_u and not u_on:
            out.append(SGR_UNDER)
            u_on = True
        if want_b and not b_on:
            out.append(SGR_BOLD)
            b_on = True
        out.append(ch)
    if u_on or b_on:
        out.append(SGR_RESET)
    out.append("\n")            # FGX newline (LF; kernel ONLCR -> CR+LF)
    return "".join(out)


def convert(data):
    # latin-1 in/out: every byte is one code point, no decode errors, ESC/CR
    # round-trip exactly.
    lines = data.split("\n")
    if lines and lines[-1] == "":
        lines.pop()             # trailing LF already accounted for by prev line
    return "".join(render_line(ln) for ln in lines)


def main(argv):
    if len(argv) != 3:
        sys.stderr.write("usage: man_preformat.py <src-dir> <dst-dir>\n")
        return 2
    src, dst = argv[1], argv[2]
    if not os.path.isdir(src):
        sys.stderr.write("man_preformat: no such source dir: %s\n" % src)
        return 1
    # Section number = the trailing digit of the dest dir (".../CAT1" -> "1").
    # The deployed page uses that as its suffix (modern BSD formatted-page
    # layout /usr/man/cat<N>/<name>.<N>); the raw 2.11BSD cat sources keep
    # their authentic flat ".0" naming.
    sect = os.path.basename(dst.rstrip("/"))[-1:]
    if not sect.isdigit():
        sys.stderr.write("man_preformat: dest dir %s has no section digit\n" % dst)
        return 1
    os.makedirs(dst, exist_ok=True)
    n = 0
    for name in sorted(os.listdir(src)):
        if not name.endswith(".0"):
            continue
        with open(os.path.join(src, name), "rb") as f:
            raw = f.read().decode("latin-1")
        base = name[:-2]                     # strip ".0"
        # LOWERCASE, and man(1) is the reason: it builds
        # /usr/man/cat<N>/<name>.<N> verbatim from its argument and does
        # not case-fold, so a staged GREP.1 is reachable only on a
        # filesystem that folds for it.  On a 2.11BSD root `man ls'
        # answered "no entry for ls" while `man LS' worked.  ProDOS folds
        # case, so lowercase resolves on both roots and upper on only one.
        outname = base + "." + sect          # grep.0 -> grep.1
        with open(os.path.join(dst, outname), "wb") as f:
            f.write(convert(raw).encode("latin-1"))
        n += 1
    print("man_preformat: converted %d page(s) -> %s" % (n, dst))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
