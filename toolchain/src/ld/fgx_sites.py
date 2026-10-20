#!/usr/bin/env python3
"""fgx_sites.py - find the 16-bit data sites of a linked object by linking
it twice (shared libc SP3 spec, section 3, "Finding data sites").

The object is linked once with every data address at its prebound value and
once with all of them moved DOWN by DELTA.  Every 16-bit word that differs
by exactly DELTA is a site -- an operand (`LDA errno', `LDA #errno+2') or a
cell word (the offset of `LIBC_DATA_PTR', a core table's `DA') -- whatever
expression produced it.  The diff is of the LINKED segments, because fgx_ld
writes some offsets itself (FGX2_LONG_PTR).

DELTA is $1010 so both bytes of every site change: the first differing byte
is always the site's low byte.  It moves down because a core sits at the top
of the bank: moving up would wrap past $FFFF, and an operand that wrapped
below $100 would be assembled direct-page (fcc emits `LDA errno' without
Merlin's `:' force), changing an instruction's length.

Run: fgx_sites.py --self-test
"""
import sys

DELTA = 0x1010


def die(msg):
    sys.exit("fgx_sites: " + msg)


def diff_sites(a, b, delta=DELTA):
    """[(offset, value in a)] of each 16-bit word that differs between the
    two links by exactly `delta'.  Refuses any other difference."""
    if len(a) != len(b):
        die("the two links differ in length (%d, %d): an operand changed "
            "size, so the delta moved something it must not" % (len(a), len(b)))
    out, i = [], 0
    while i < len(a):
        if a[i] == b[i]:
            i += 1
            continue
        if i + 1 >= len(a):
            die("offset %#06x: a lone byte differs, not a word" % i)
        va, vb = a[i] | a[i + 1] << 8, b[i] | b[i + 1] << 8
        if (va - vb) & 0xFFFF != delta:
            die("offset %#06x: %#06x vs %#06x is not a word moved by %#06x "
                "(a high- or low-byte operand?)" % (i, va, vb, delta))
        out.append((i, va))
        i += 2
    return out


def attribute(sites, objects, where="segment"):
    """{object name: [(offset, value), ...]}.  `objects' is [(name, addr, size)].  A
    value belongs to the object it lies inside; failing that, to the one it
    is one past the end of (C allows that pointer).  Inside always wins:
    &x right after errno is x's, or the binder would move it by errno's
    delta."""
    out = {}
    for off, v in sites:
        inside = [n for n, a, sz in objects if a <= v < a + sz]
        past = [n for n, a, sz in objects if v == a + sz]
        owner = (inside or past or [None])[0]
        if owner is None:
            die("%s offset %#06x: %#06x lies in no import" % (where, off, v))
        out.setdefault(owner, []).append((off, v))
    return out


def expect_die(fn, word):
    try:
        fn()
    except SystemExit as e:
        assert word in str(e), (word, str(e))
        return
    raise AssertionError("expected a refusal naming %r" % word)


def self_test():
    a = bytes([0xAD, 0x00, 0xF8, 0xEA, 0xA9, 0x02, 0xF8, 0x00])   # LDA errno; LDA #errno+2
    b = bytes([0xAD, 0xF0, 0xE7, 0xEA, 0xA9, 0xF2, 0xE7, 0x00])
    assert diff_sites(a, b) == [(1, 0xF800), (5, 0xF802)]
    assert attribute([(1, 0xF800), (5, 0xF802)],
                     [("errno", 0xF800, 2), ("x", 0xF802, 4)]) == \
        {"errno": [(1, 0xF800)], "x": [(5, 0xF802)]}   # x's start, not one past errno
    assert attribute([(5, 0xF802)], [("errno", 0xF800, 2)]) == \
        {"errno": [(5, 0xF802)]}                       # one past the end: errno's
    expect_die(lambda: diff_sites(a, b[:-1]), "length")
    expect_die(lambda: diff_sites(a, bytes([0xAD, 0x00, 0xE7]) + a[3:]), "not a word")
    # A hand-written LDA #>errno: the lone high byte moves.
    expect_die(lambda: diff_sites(bytes([0xA9, 0xF8, 0x00]),
                                  bytes([0xA9, 0xE7, 0x00])), "not a word")
    expect_die(lambda: attribute([(1, 0x1234)], [("errno", 0xF800, 2)]), "no import")
    print("fgx_sites: self-test OK")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
