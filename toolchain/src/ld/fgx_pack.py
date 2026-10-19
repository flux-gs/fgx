#!/usr/bin/env python3
"""fgx_pack.py - pack a program's translation units into code banks.

Each TU's assembled size is measured; the TUs are packed
first-fit-decreasing into segment 0's remaining room, then into as few
extra banks as hold the rest, each bank carrying its own runtime.
Ported from tools/elvis-fgx2/gen_elvis_link.py (measure_overhead,
measure_tu, pack).

     fgx_pack.py --self-test
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fgx_libso  # noqa: E402


def die(msg):
    sys.exit("fgx_pack: " + msg)


def pack(sizes, room0, cap, per_bank):
    """The TU groups: the first for segment 0's remaining `room0' bytes,
    each later one for an extra bank of `cap' bytes less its `per_bank'
    overhead.  First-fit-decreasing, ties broken by name."""
    room = [room0]
    groups = [[]]
    for tu in sorted(sizes, key=lambda t: (-sizes[t], t)):
        n = sizes[tu]
        if n > cap - per_bank:
            die("%s is %d bytes; a bank holds %d beside its runtime"
                % (tu, n, cap - per_bank))
        i = next((i for i, r in enumerate(room) if n <= r), None)
        if i is None:
            room.append(cap - per_bank)
            groups.append([])
            i = len(room) - 1
        room[i] -= n
        groups[i].append(tu)
    return groups


def assembled(link_dir, puts, equs=(), name="m1"):
    """The byte size of one segment assembled from `puts' in link_dir."""
    b = fgx_libso.run_merlin(link_dir, fgx_libso.write_link(
        link_dir, name, 0, equs, puts))
    if b is None:
        die("%s is over 64 KB" % ", ".join(os.path.basename(p) for p in puts))
    return len(b)


def measure(tu, link_dir, puts, equs=(), base=None):
    """`tu''s assembled size: the segment of `puts' (layout files and the
    runtime the TU reaches) with the TU, less the segment without it
    (`base', when the caller has measured it once)."""
    if base is None:
        base = assembled(link_dir, puts, equs)
    return assembled(link_dir, list(puts) + [tu], equs, "m0") - base


def self_test():
    # first-fit-decreasing: a (40000) does not fit bank 0's 35000 and opens
    # bank 1 (63536); b fits bank 0; c fits bank 1's 23536 left; d fits
    # neither bank 0's 5000 nor bank 1's 3536 and opens bank 2.
    g = pack({"a": 40000, "b": 30000, "c": 20000, "d": 10000}, room0=35000,
             cap=65536, per_bank=2000)
    assert g == [["b"], ["a", "c"], ["d"]], g
    assert pack({"x": 100}, 50, 65536, 2000) == [[], ["x"]]     # nothing fits bank 0
    try:
        pack({"huge": 70000}, 0, 65536, 2000)
    except SystemExit as e:
        assert "huge" in str(e)
    else:
        raise AssertionError("an oversized TU must be refused by name")
    print("fgx_pack: self-test OK")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
        sys.exit(0)
    sys.exit(__doc__)
