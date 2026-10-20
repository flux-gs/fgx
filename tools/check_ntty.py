#!/usr/bin/env python3
"""NTTY is stated in three files; hold them together.

apple/fgx#108 T7 grew the tty table for the serial line and found there was no
check at all:

    include/kernel.s          sizes _ttyTable and _Chardev_TtyIdx's
                              compare-and-subtract ladder
    src/kernel/tty/tty_dev.c  sizes ttys[]/tty_bound[] and bounds tty_byidx,
                              tty_find and tty_devinit's own loop
    src/kernel/signal.s       sizes _ttyNames, the FIODGNAME record table
    src/kernel/tty/ttybank.s  _ttyRowOff, the index -> ttys[] row offset table
                              every assembly slot of the tty bank indexes

_ttyRowOff IS COUNTED FOR THE SAME REASON AS _ttyNames BELOW.  Tty_PgrpGet and
its six siblings bound the index against NTTY and then read `_ttyRowOff,X'; a
table short of NTTY rows assembles, and the last lines' slots take their row
offset from the first bytes of the code that follows the table.  Their
foreground group, flags, erase/kill pair and window size then land at a garbage
offset into ttys[] and read back as zero -- and ttioctl's SIGTTOU check holds a
getty on such a line in its lbolt loop forever, on its first TIOCSETP.  The
rows must be 0..NTTY-1 times TTYC_SIZE, in that order, since the index is the
row number.

_ttyNames IS COUNTED HERE BECAUSE NOTHING BOUNDS THE INDEX AGAINST IT.
@si_dgname (src/kernel/syscall.s) turns a tty index into a record offset with
three ASLs and copies TTYNAME_MAX bytes from it, with no comparison against the
table's own length: a table short of NTTY records does not fail to build and
does not fail to run -- ttyname(3) on the missing line reads whatever assembles
next and reports it as a device name.  The record WIDTH is checked with the
count, because @si_dgname's stride is TTYNAME_MAX whatever the records hold; one
short record shifts every line after it onto the wrong name.

(A third copy lived in tty_probe.h until the tty-bank probes were removed on
2026-09-07; two files is what is left to hold together, and the check is
unchanged otherwise.)

Kernel C cannot include an assembly header, so the restatement is deliberate --
what was missing is anything that notices when the copies stop agreeing.

A DRIFT DOES NOT FAIL TO BUILD, AND THE EXISTING PROBE DOES NOT CATCH IT.
tty_dev.c's comment used to claim these "cannot drift the same way, and
tty_probe drives the drift that matters anyway: it asserts the number of ttys
the registry binds against the number this file has room for".  That is false
in the GROWTH direction, which is exactly the one T7 took: raise the assembly
copy alone and `tty_devinit's loop -- bounded by the C copy -- never visits the
new line, so it binds nothing, the count matches the old number, and the probe
is green while the new terminal is silently unbound.  A probe that counts what
the loop was willing to visit cannot see a line the loop never reached.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

SOURCES = (
    ("include/kernel.s",             r"^NTTY\s+EQU\s+(\d+)"),
    ("src/kernel/tty/tty_dev.c",     r"^#define\s+NTTY\s+(\d+)"),
)

# SEF_CTTY_MASK stores "tty index + 1" in three bits (include/kernel.s), so the
# highest index must still fit: NTTY <= 7.  Growing past that needs that field
# widened first, and it would fail silently -- a session's controlling terminal
# would alias another line's.
CTTY_CEILING = 7


TTYNAMES = "src/kernel/signal.s"
TTYROWOFF = "src/kernel/tty/ttybank.s"


def read_ttyrowoff(root):
    """(row multipliers, error).  One entry per `DA n*TTYC_SIZE' row of the
    _ttyRowOff table, in table order."""
    lines = (root / TTYROWOFF).read_text().splitlines()
    for i, line in enumerate(lines):
        if line.startswith("_ttyRowOff"):
            break
    else:
        return None, "%s: no _ttyRowOff table" % TTYROWOFF
    rows = []
    for line in lines[i:]:
        body = re.sub(r"^_ttyRowOff\b", "", line).split(";")[0].strip()
        m = re.match(r"DA\s+(\d+)\*TTYC_SIZE$", body)
        if not m:
            break
        rows.append(int(m.group(1)))
    return rows, None


def read_ttynames(root):
    """(record widths, error).  One entry per ASC line of the _ttyNames table."""
    text = (root / TTYNAMES).read_text()
    m = re.search(r"^TTYNAME_MAX\s+EQU\s+(\d+)", text, re.M)
    if not m:
        return None, None, "%s: no TTYNAME_MAX definition" % TTYNAMES
    width = int(m.group(1))
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("_ttyNames"):
            break
    else:
        return None, None, "%s: no _ttyNames table" % TTYNAMES
    widths = []
    for line in lines[i:]:
        body = re.sub(r"^_ttyNames\b", "", line).strip()
        if not body.startswith("ASC"):
            break
        body = body[3:].split(";")[0].strip()
        chars = re.findall(r"'([^']*)'", body)
        n = sum(len(c) for c in chars)
        n += len(re.findall(r"(?<![\w'])[0-9A-Fa-f]{2}(?![\w'])", re.sub(r"'[^']*'", "", body)))
        widths.append(n)
    return widths, width, None


def read_values(root):
    out = []
    for rel, pat in SOURCES:
        text = (root / rel).read_text()
        m = re.search(pat, text, re.M)
        if not m:
            return None, "%s: no NTTY definition matching %s" % (rel, pat)
        out.append((rel, int(m.group(1))))
    return out, None


def check(root):
    vals, err = read_values(root)
    if err:
        return err
    distinct = {v for _, v in vals}
    if len(distinct) != 1:
        lines = ["NTTY DISAGREES between its copies:"]
        lines += ["    %-30s NTTY = %d" % (rel, v) for rel, v in vals]
        lines.append("  A drift here does not fail to build.  Raising only the")
        lines.append("  assembly copy leaves tty_devinit's loop bounded by the C")
        lines.append("  one, so the new line is never bound and the probe stays")
        lines.append("  green with a silently missing terminal.")
        return "\n".join(lines)
    n = distinct.pop()
    if n > CTTY_CEILING:
        return ("NTTY = %d, but SEF_CTTY_MASK holds 'tty index + 1' in THREE "
                "BITS (include/kernel.s), so NTTY may not exceed %d without "
                "widening that field first." % (n, CTTY_CEILING))
    widths, width, err = read_ttynames(root)
    if err:
        return err
    if len(widths) != n:
        return ("_ttyNames holds %d record(s), but NTTY = %d (%s).\n"
                "  @si_dgname does not bound the tty index against this table, "
                "so tty[%d] reads\n"
                "  past the end and ttyname(3) reports whatever assembles next "
                "as a device name."
                % (len(widths), n, TTYNAMES, len(widths)))
    bad = [(i, w) for i, w in enumerate(widths) if w != width]
    if bad:
        return ("_ttyNames record(s) are not TTYNAME_MAX (%d) bytes wide: %s.\n"
                "  @si_dgname's stride is TTYNAME_MAX regardless, so a short "
                "record shifts every\n"
                "  line after it onto the wrong name."
                % (width, ", ".join("record %d = %d" % b for b in bad)))
    rows, err = read_ttyrowoff(root)
    if err:
        return err
    if rows != list(range(n)):
        return ("_ttyRowOff holds row(s) %s, but NTTY = %d needs rows 0..%d in "
                "order (%s).\n"
                "  The tty bank's slots bound the index against NTTY and never "
                "against this\n"
                "  table, so tty[%d] takes its row offset from the code after "
                "the table and its\n"
                "  foreground group lands at a garbage offset into ttys[]."
                % (rows, n, n - 1, TTYROWOFF, len(rows)))
    return None


def self_test():
    """The checker must go RED on a drift; a checker that cannot fail is not one."""
    import tempfile
    fails = 0
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        def names(n_rec, short_at=None):
            out = ["TTYNAME_MAX     EQU     8", "_ttyNames       ASC     'console',00"]
            for i in range(1, n_rec):
                if i == short_at:
                    out.append("                ASC     'ttyp0',00,00")   # 7 bytes
                else:
                    out.append("                ASC     'ttyp%d',00,00,00" % i)
            out.append("")
            out.append("_kTtySigPend    DS      NTTY")
            return "\n".join(out) + "\n"

        def rowoff(mults):
            out = ["_ttyRowOff      DA      %d*TTYC_SIZE   ; index -> byte offset" % mults[0]]
            out += ["                DA      %d*TTYC_SIZE" % m for m in mults[1:]]
            out.append("                ; a comment, then the first slot")
            out.append("Tty_PgrpGet     MX      %00")
            return "\n".join(out) + "\n"

        def write(n_asm, n_c, n_rec=None, short_at=None, rows=None):
            if n_rec is None:
                n_rec = n_asm
            if rows is None:
                rows = list(range(n_asm))
            for rel, body in (
                ("include/kernel.s",           "NTTY            EQU     %d\n" % n_asm),
                ("src/kernel/tty/tty_dev.c",   "#define NTTY            %d\n" % n_c),
                ("src/kernel/signal.s",        names(n_rec, short_at)),
                ("src/kernel/tty/ttybank.s",   rowoff(rows)),
            ):
                p = root / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(body)
        write(6, 6)
        if check(root) is not None:
            print("self-test FAIL: agreeing copies reported a problem"); fails += 1
        # the exact drift T7 would have shipped
        write(6, 5)
        if check(root) is None:
            print("self-test FAIL: assembly-only growth not caught"); fails += 1
        write(5, 6)
        if check(root) is None:
            print("self-test FAIL: C-only growth not caught"); fails += 1
        write(8, 8)
        if check(root) is None:
            print("self-test FAIL: SEF_CTTY_MASK ceiling not enforced"); fails += 1
        # the table this check was added for: NTTY grew, the records did not
        write(6, 6, n_rec=5)
        if check(root) is None:
            print("self-test FAIL: _ttyNames short of NTTY not caught"); fails += 1
        # a record that is not TTYNAME_MAX wide shifts every line after it
        write(6, 6, short_at=2)
        if check(root) is None:
            print("self-test FAIL: undersized _ttyNames record not caught"); fails += 1
        # the tty bank's row table stayed at five rows while NTTY went to 7:
        # ttyv3's getty then parked in TIOCSETP's SIGTTOU loop on first use
        write(7, 7, rows=[0, 1, 2, 3, 4])
        if check(root) is None:
            print("self-test FAIL: _ttyRowOff short of NTTY not caught"); fails += 1
        # the right count with a row out of place is the same wrong offset
        write(6, 6, rows=[0, 1, 2, 3, 3, 5])
        if check(root) is None:
            print("self-test FAIL: misordered _ttyRowOff row not caught"); fails += 1
    if fails:
        return 1
    print("check_ntty self-test: 8 case(s) OK")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    err = check(REPO)
    if err:
        sys.stderr.write("check_ntty: " + err + "\n")
        return 1
    vals, _ = read_values(REPO)
    widths, width, _ = read_ttynames(REPO)
    rows, _ = read_ttyrowoff(REPO)
    print("check_ntty: clean (NTTY = %d in all %d source(s); _ttyNames holds %d "
          "record(s) of %d bytes; _ttyRowOff holds %d row(s))"
          % (vals[0][1], len(vals), len(widths), width, len(rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
