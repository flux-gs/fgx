#!/usr/bin/env python3
"""Unit tests for fgx_ar.py — the member-extraction archive walk + the
member .s scanner.  Pure/fast (no assembly, no MAME); run standalone:

    python3 src/ld/test_fgx_ar.py     # prints "fgx_ar: N/N tests passed"

Exits non-zero on any failure (integrates with the golden/gate harness by
exit code).
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fgx_ar  # noqa: E402


def mk(members):
    """Index a list of member dicts (assign keys, build sym map)."""
    return fgx_ar.index_members(members)


def sel(members, sym2mem, provided, undef):
    picked, unresolved = fgx_ar.extract(members, sym2mem, provided, undef)
    return [m["id"] for m in picked], unresolved


# --- extraction algorithm ---------------------------------------------------

def test_transitive_pull():
    # tool -> A; A -> B; B -> C; D unreferenced.  Pull A,B,C only.
    members, s2m = mk([
        {"id": "A", "exports": ["a"], "imports": ["b"]},
        {"id": "B", "exports": ["b"], "imports": ["c"]},
        {"id": "C", "exports": ["c"], "imports": []},
        {"id": "D", "exports": ["d"], "imports": []},
    ])
    picked, un = sel(members, s2m, provided=[], undef=["a"])
    assert picked == ["A", "B", "C"], picked
    assert un == set(), un


def test_dead_strip_leaves_unreferenced_out():
    # The whole point: a printf-only tool drops qsort/sockets.
    members, s2m = mk([
        {"id": "printf", "exports": ["printf"], "imports": ["putc"]},
        {"id": "putc",   "exports": ["putc"],   "imports": []},
        {"id": "qsort",  "exports": ["qsort"],  "imports": ["memcpy"]},
        {"id": "socket", "exports": ["socket"], "imports": []},
    ])
    picked, un = sel(members, s2m, provided=[], undef=["printf"])
    assert set(picked) == {"printf", "putc"}, picked
    assert "qsort" not in picked and "socket" not in picked
    assert un == set()


def test_provided_shortcircuits():
    # A imports strcpy, provided by libc -> not pulled, not unresolved.
    members, s2m = mk([
        {"id": "A", "exports": ["a"], "imports": ["strcpy"]},
    ])
    picked, un = sel(members, s2m, provided=["strcpy"], undef=["a"])
    assert picked == ["A"], picked
    assert un == set(), un


def test_unresolved_named():
    # tool needs X; nothing defines it -> unresolved.
    members, s2m = mk([{"id": "A", "exports": ["a"], "imports": []}])
    picked, un = sel(members, s2m, provided=[], undef=["a", "X"])
    assert picked == ["A"], picked
    assert un == {"X"}, un


def test_diamond_pulls_once():
    # A -> {b,c}; B -> d; C -> d.  D pulled exactly once.
    members, s2m = mk([
        {"id": "A", "exports": ["a"], "imports": ["b", "c"]},
        {"id": "B", "exports": ["b"], "imports": ["d"]},
        {"id": "C", "exports": ["c"], "imports": ["d"]},
        {"id": "D", "exports": ["d"], "imports": []},
    ])
    picked, un = sel(members, s2m, provided=[], undef=["a"])
    assert picked == ["A", "B", "C", "D"], picked        # stable archive order
    assert picked.count("D") == 1
    assert un == set()


def test_cycle_terminates():
    # A <-> B mutual reference (legal near-JSR cycle within a lib).
    members, s2m = mk([
        {"id": "A", "exports": ["a"], "imports": ["b"]},
        {"id": "B", "exports": ["b"], "imports": ["a"]},
    ])
    picked, un = sel(members, s2m, provided=[], undef=["a"])
    assert set(picked) == {"A", "B"}, picked
    assert un == set()


def test_stable_order_regardless_of_seed_order():
    members, s2m = mk([
        {"id": "M1", "exports": ["s1"], "imports": []},
        {"id": "M2", "exports": ["s2"], "imports": []},
        {"id": "M3", "exports": ["s3"], "imports": []},
    ])
    p1, _ = sel(members, s2m, [], ["s3", "s1", "s2"])
    p2, _ = sel(members, s2m, [], ["s2", "s3", "s1"])
    assert p1 == p2 == ["M1", "M2", "M3"], (p1, p2)


def test_nothing_referenced():
    members, s2m = mk([{"id": "A", "exports": ["a"], "imports": []}])
    picked, un = sel(members, s2m, provided=[], undef=[])
    assert picked == [] and un == set()


def test_duplicate_export_is_fatal():
    try:
        mk([
            {"id": "A", "exports": ["dup"], "imports": []},
            {"id": "B", "exports": ["dup"], "imports": []},
        ])
    except SystemExit as e:
        assert e.code == 2
        return
    assert False, "expected SystemExit on duplicate export"


# --- member .s scanner ------------------------------------------------------

def test_scan_member():
    src = (
        "* a comment line\n"
        "                MX      %00\n"
        "                FGX2_EXPORT waddch\n"
        "waddch          FGX2_EXPORT addch\n"       # label-prefixed macro
        "                FGX2_FARCALL wclrtoeol   ; needs clrtoeol\n"
        "                FGX2_LONG_PTR _t;_curbuf;0\n"
        "                FGX2_FARCALL waddch\n"      # self-ref -> excluded
        "                JSR     _fcc_eq16\n"        # plain near JSR: not an edge
        "                RTL\n"
    )
    with tempfile.NamedTemporaryFile("w", suffix=".s", delete=False) as f:
        f.write(src)
        path = f.name
    try:
        exp, imp = fgx_ar.scan_member(path)
    finally:
        os.unlink(path)
    assert exp == ["addch", "waddch"], exp
    # wclrtoeol + _curbuf are imports; waddch self-ref excluded; JSR ignored.
    assert imp == ["_curbuf", "wclrtoeol"], imp


def test_scan_integration_with_extract():
    # Two members on disk; index one, extract from the scanned records.
    a = ("                FGX2_EXPORT initscr\n"
         "                FGX2_FARCALL gettmode\n")
    b = ("                FGX2_EXPORT gettmode\n"
         "                FGX2_FARCALL strcpy\n")     # strcpy = libc-provided
    d = tempfile.mkdtemp()
    pa, pb = os.path.join(d, "scr.s"), os.path.join(d, "tty.s")
    open(pa, "w").write(a)
    open(pb, "w").write(b)
    ea, ia = fgx_ar.scan_member(pa)
    eb, ib = fgx_ar.scan_member(pb)
    members, s2m = mk([
        {"id": "scr", "exports": ea, "imports": ia},
        {"id": "tty", "exports": eb, "imports": ib},
    ])
    picked, un = sel(members, s2m, provided=["strcpy"], undef=["initscr"])
    assert picked == ["scr", "tty"], picked   # initscr pulls scr -> gettmode -> tty
    assert un == set(), un                      # strcpy provided, not unresolved


def main():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    passed = 0
    for t in tests:
        t()
        passed += 1
    print(f"fgx_ar: {passed}/{len(tests)} tests passed")


if __name__ == "__main__":
    main()
