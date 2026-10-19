#!/usr/bin/env python3
"""codepack_check -- code segments are packed into shared banks.

Reads the text table (src/kernel/tty/text.s: 36-byte entries, TX_BANKS at 8,
TX_PAGE at 16, TX_NPG at 24, page count 0 = the whole bank) and requires:
(a) at least one bank holds the segments of two or more texts, and inside
    every bank the page ranges [page, page + npg) are disjoint, a whole-bank
    segment alone in its bank;
(b) the positive control: some segment holds a whole bank (a segment too big
    to place, such as sh's segment 0).
Exit 0 pass, 1 fail, 2 inconclusive.  --self-test runs the controls.
"""
import binascii
import json
import pathlib
import sys

NTEXT, TXSZ = 16, 36


def segments(tab):
    out = []
    for i in range(NTEXT):
        e = tab[i * TXSZ:(i + 1) * TXSZ]
        if not (e[2] | e[3] << 8):
            continue
        for k in range(8):
            if e[8 + k]:
                out.append((i + 1, e[8 + k], e[16 + k], e[24 + k]))
    return out


def verdict(tab):
    segs = segments(tab)
    if not segs:
        print("codepack: no texts in the table")
        return 2
    by_bank = {}
    for text, bank, page, npg in segs:
        by_bank.setdefault(bank, []).append((text, page, npg))
    bad = 0
    shared = 0
    for bank, rows in sorted(by_bank.items()):
        if any(n == 0 for _t, _p, n in rows) and len(rows) > 1:
            print("codepack: FAIL -- bank $%02X is whole to one segment and holds others: %s" % (bank, rows))
            bad += 1
            continue
        spans = sorted((p, p + n, t) for t, p, n in rows if n)
        for (a0, a1, ta), (b0, b1, tb) in zip(spans, spans[1:]):
            if b0 < a1:
                print("codepack: FAIL -- bank $%02X: text %d [%d,%d) overlaps text %d [%d,%d)" % (bank, ta, a0, a1, tb, b0, b1))
                bad += 1
        if len({t for t, _p, _n in rows}) > 1:
            shared += 1
    whole = sum(1 for _t, _b, _p, n in segs if n == 0)
    print("codepack: %d segments in %d banks, %d shared by texts, %d whole-bank" % (len(segs), len(by_bank), shared, whole))
    if not shared:
        print("codepack: FAIL -- no bank holds two texts' segments")
        bad += 1
    if not whole:
        print("codepack: FAIL -- no whole-bank segment (the positive control)")
        bad += 1
    if bad:
        return 1
    print("codepack: PASS")
    return 0


def entry(ino, banks, pages, npgs):
    e = bytearray(TXSZ)
    e[2] = ino
    for k, (b, p, n) in enumerate(zip(banks, pages, npgs)):
        e[8 + k], e[16 + k], e[24 + k] = b, p, n
    return bytes(e)


def main(path="dump.json"):
    if path == "--self-test":
        pad = bytes(TXSZ * (NTEXT - 3))
        good = entry(1, [0x50], [0], [10]) + entry(2, [0x50], [10], [4]) + entry(3, [0x51], [0], [0]) + pad
        assert verdict(good) == 0
        overlap = entry(1, [0x50], [0], [10]) + entry(2, [0x50], [9], [4]) + entry(3, [0x51], [0], [0]) + pad
        assert verdict(overlap) == 1
        unpacked = entry(1, [0x50], [0], [0]) + entry(2, [0x52], [0], [0]) + entry(3, [0x51], [0], [0]) + pad
        assert verdict(unpacked) == 1
        print("codepack_check: self-test ok")
        return 0
    d = json.loads(pathlib.Path(path).read_text())
    h = d.get("memory", {}).get("texttab", {}).get("hex")
    if not h:
        print("codepack: the texttab region is missing from the dump")
        return 2
    return verdict(binascii.unhexlify(h))


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
