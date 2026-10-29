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


def split_code(path, out_dir, keep="main"):
    """A program file too big for one bank, as pack units: fcc --sections
    output split at its FGX_SECT boundaries.  Every function is its own
    exported, far-called unit (FGX2_EXPORT / FGX2_FARCALL), so one in
    another bank is reached the way another file's would be.  Returns the
    file for segment 0 -- the header and the `keep' section -- and one file
    per other section; each carries the header and its own
    FGX2_RELOC_COUNT, which fgx_ld checks per file."""
    import fgx_gc
    lines = open(path).read().split("\n")
    parts = fgx_gc.split_sections(lines, path)
    if not any(p[0] == "sect" for p in parts):
        die("%s has no FGX_SECT sections to split (compile it with --sections)"
            % path)
    if parts[0][0] != "loose":
        die("%s starts with a section, not its header" % path)
    head = [ln for ln in parts[0][1] if ln.split()[:1] != ["FGX2_RELOC_COUNT"]]
    sects = [p for p in parts if p[0] == "sect"]
    if keep not in [p[1] for p in sects]:
        die("%s has no %s section" % (path, keep))
    base = os.path.splitext(os.path.basename(path))[0]
    os.makedirs(out_dir, exist_ok=True)

    def write(nm, body):
        rows = head + body
        p = os.path.join(out_dir, nm)
        with open(p, "w") as f:
            f.write("\n".join(rows) + "\n                FGX2_RELOC_COUNT %d\n"
                    % fgx_gc.fgx2_rows(rows))
        return p
    seg0 = write(base + ".s", [ln for p in sects if p[1] == keep for ln in p[2]])
    rest = [write("%s.%d.s" % (base, i), p[2])
            for i, p in enumerate(s for s in sects if s[1] != keep)]
    return seg0, rest


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
    # split_code: main stays, the others become files; each file's count is
    # its own FGX2 rows (FGX2_MODE, the exports, the call), not the input's.
    import tempfile
    t = tempfile.mkdtemp()
    src = os.path.join(t, "p.s")
    with open(src, "w") as f:
        f.write("\n".join([
            "                FGX2_MODE 2", "                MX      %00",
            "                FGX_SECT main", "                FGX2_EXPORT main",
            "main            ENT", "                FGX2_FARCALL f", "                RTL",
            "                FGX_ENDS",
            "                FGX_SECT f", "                FGX2_EXPORT f",
            "f               ENT", "                RTL", "                FGX_ENDS",
            "                FGX2_RELOC_COUNT 4"]) + "\n")
    s0, rest = split_code(src, os.path.join(t, "o"))
    a, b = open(s0).read(), open(rest[0]).read()
    assert "main            ENT" in a and "f               ENT" not in a, a
    assert "FGX2_RELOC_COUNT 3" in a, a          # MODE, EXPORT main, FARCALL f
    assert "f               ENT" in b and "FGX2_RELOC_COUNT 2" in b, b
    assert len(rest) == 1 and "MX      %00" in b
    print("fgx_pack: self-test OK")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
        sys.exit(0)
    sys.exit(__doc__)
