#!/usr/bin/env python3
"""coremap_check -- the user pool's page map is well formed.

Reads the dumped _coremap (4-byte {size, addr} pieces, size 0 ends it) and
_kUserFirstBank, and holds the map to tools/coremap_model.py's check():
sorted, coalesced, every piece inside the 56-bank pool.  At least four
banks must be free after the churn (the idle system leaves about ten).
Prints the free total.  With the texttab region (src/kernel/tty/text.s), it
also refuses a text entry with a key and no banks: a claim its failed load
gave up and nothing freed.  Exit 0 pass, 1 fail, 2 inconclusive.
--self-test: an unsorted map and an overlapping map must both fail.
"""
import binascii
import json
import os
import pathlib
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
from tools import coremap_model  # noqa: E402

def _pool():
    """rest.user_banks, as include/config.s carries it (CFG_REST_USER_BANKS)."""
    import re
    cfg = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "include", "config.s")
    with open(cfg) as f:
        return int(re.search(r"^CFG_REST_USER_BANKS\s+EQU\s+(\d+)",
                             f.read(), re.M).group(1))


POOL = _pool()     # include/loader.s BANK_USER_COUNT aliases the same value
NTEXT, TXSZ = 16, 36                # src/kernel/tty/text.s
FLOOR = 4 * 256


def pieces(raw):
    out = []
    for i in range(0, len(raw) - 3, 4):
        size, addr = struct.unpack_from("<HH", raw, i)
        if size == 0:
            return out
        out.append((size, addr))
    return None                       # no terminator inside the dump


def empty_claims(tab):
    out = []
    for i in range(NTEXT):
        e = tab[i * TXSZ:(i + 1) * TXSZ]
        if (e[2] | e[3] << 8) and not any(e[8:16]):
            out.append(i + 1)
    return out


def verdict(raw, first, tab=None):
    p = pieces(raw)
    if p is None:
        print("coremap: FAIL -- no terminator in the dumped map")
        return 1
    try:
        coremap_model.check(p, first, POOL)
    except AssertionError as e:
        print("coremap: FAIL -- %s" % e)
        return 1
    free = sum(s for s, _a in p)
    print("coremap: %d pieces, %d pages free (%.2f banks)" % (len(p), free, free / 256))
    if free < FLOOR:
        print("coremap: FAIL -- under %d pages free" % FLOOR)
        return 1
    if tab is not None:
        left = empty_claims(tab)
        if left:
            print("coremap: FAIL -- text entries %s have a key and no banks" % left)
            return 1
    print("coremap: PASS")
    return 0


def main(path="dump.json"):
    if path == "--self-test":
        good = struct.pack("<HHHH", 2048, 0x4100, 0, 0)
        assert verdict(good, 0x41) == 0
        unsorted = struct.pack("<HHHHHH", 256, 0x4500, 1024, 0x4200, 0, 0)
        assert verdict(unsorted, 0x41) == 1
        overlap = struct.pack("<HHHHHH", 1024, 0x4100, 1024, 0x4300, 0, 0)
        assert verdict(overlap, 0x41) == 1
        claim = bytearray(NTEXT * TXSZ)
        claim[2] = 7                                  # a key (ino 7), no banks
        assert verdict(good, 0x41, bytes(claim)) == 1
        claim[8] = 0x50                               # filled: one bank
        assert verdict(good, 0x41, bytes(claim)) == 0
        print("coremap_check: self-test ok")
        return 0
    d = json.loads(pathlib.Path(path).read_text())
    m = d.get("memory", {})
    if not m.get("coremap", {}).get("hex") or not m.get("first", {}).get("hex"):
        print("coremap: a region is missing from the dump")
        return 2
    raw = binascii.unhexlify(m["coremap"]["hex"])
    first = binascii.unhexlify(m["first"]["hex"])[0]
    tab = m.get("texttab", {}).get("hex")
    return verdict(raw, first, binascii.unhexlify(tab) if tab else None)


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
