#!/usr/bin/env python3
"""Offset relocations: the two-origin classifier finds every same-segment
address and refuses any byte it cannot classify."""
import os, shutil, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "src", "ld"))
import fgx_offrel  # noqa: E402


def seg(body, fill=0):
    d = tempfile.mkdtemp()
    with open(os.path.join(d, "b.s"), "w") as f:
        f.write(body)
        if fill:
            f.write("                DS     %d\n" % fill)
    try:
        return fgx_offrel.assemble_code(d, "s", [], ["b.s"])
    finally:
        shutil.rmtree(d)


def must_die(body):
    try:
        seg(body)
    except SystemExit:
        return
    raise AssertionError("accepted:\n" + body)


# JSR abs, JMP abs, LDA #label (16-bit), PEA label-1, DA label: five sites.
GOOD = """\
                MX     %00
start           JSR    there
                JMP    there
                LDA    #there
                PEA    there-1
there           RTS
tab             DA     start
"""
code, s = seg(GOOD)
assert s == [1, 4, 7, 10, 13], s

# Branches and data-bank operands move nothing.
code, s = seg("loop            BRA    loop\n                LDA    $1234\n")
assert s == [], s

# fill: a segment ending exactly at a page end still classifies.
code, s = seg(GOOD, fill=256 - 15)
assert len(code) == 256 and s == [1, 4, 7, 10, 13], (len(code), s)

# big: over LIMIT is never placed.
code, s = seg("x               RTS\n", fill=fgx_offrel.LIMIT)
assert s is None

# Refused: a high byte alone, a low byte alone, a halved address, a
# doubled one.  The first two are why MOVE is odd.
must_die("x               LDA    #>x\n")
must_die("x               DFB    <x\n")
must_die("x               DA     x/2\n")
must_die("x               DA     x*2\n")
print("test_offset_relocs: ok")


# --- fgx_ld: "offsets" become relocs (src, off, 0x80|tgt), the segment is
# flagged, and every address fgx_ld itself writes into a placeable segment's
# target gets one too.  Synthetic listings, as test_farjump.py builds them.
import json, struct, subprocess  # noqa: E402

LD = os.path.join(HERE, "..", "..", "src", "ld", "fgx_ld.py")


def row(n, src, off, text):
    return (f" {n} |  1      {src}    1 | Macro       | 00 |"
            f"         |    0 | 00/{off:04X}               | {text}\n")


def ld(segs):
    d = tempfile.mkdtemp()
    try:
        m = {"output": "out", "n_data_segment": 1, "segments": []}
        for i, (kind, data, rows, offs) in enumerate(segs):
            open(os.path.join(d, f"s{i}"), "wb").write(data)
            open(os.path.join(d, f"s{i}.lst"), "w").write("".join(rows))
            e = {"bin": f"s{i}", "listing": f"s{i}.lst", "kind": kind, "bss": 0}
            if offs is not None:
                e["offsets"] = offs
            m["segments"].append(e)
        open(os.path.join(d, "m.json"), "w").write(json.dumps(m))
        r = subprocess.run([sys.executable, LD, os.path.join(d, "m.json")],
                           capture_output=True, text=True)
        out = open(os.path.join(d, "out"), "rb").read() if r.returncode == 0 else None
        return r, out
    finally:
        shutil.rmtree(d)


def image(out):
    n, nrel = out[6], struct.unpack_from("<H", out, 11)[0]
    flags = [out[16 + 8 * i + 5] for i in range(n)]
    p = 16 + 8 * n + sum(struct.unpack_from("<H", out, 16 + 8 * i)[0] for i in range(n))
    rel = {struct.unpack_from("<BHB", out, p + 4 * k) for k in range(nrel)}
    return flags, rel


SEG0 = bytes([0x22, 0, 0, 0, 0x34, 0x12])        # JSL leaf ; DA <own address>
SEG0_ROWS = [row(1, "a.s", 0, "FGX2_EXPORT start"),
             row(2, "a.s", 0, "x FGX2_FARCALL leaf"),
             row(3, "a.s", 0, "FGX2_RELOC_COUNT 2")]
DATA = (b"\0" * 4, [row(1, "d.s", 0, "p FGX2_LONG_PTR t;start;0"),
                    row(2, "d.s", 0, "FGX2_RELOC_COUNT 1")])
LEAF = (bytes([0xEA, 0xEA, 0x6B]), [row(1, "p.s", 2, "FGX2_EXPORT leaf"),
                                    row(2, "p.s", 0, "FGX2_RELOC_COUNT 1")])

r, out = ld([("CODE", SEG0, SEG0_ROWS, [4]), ("DATA",) + DATA + (None,),
             ("CODE",) + LEAF + ([],)])
assert r.returncode == 0, r.stderr
flags, rel = image(out)
assert flags == [1, 0, 1], flags
want = {(0, 3, 2), (1, 2, 0),                    # the bank relocs, as before
        (0, 1, 0x82), (1, 0, 0x80), (0, 4, 0x80)}
assert rel == want, sorted(rel ^ want)

# Nothing placeable: no offset relocs, no flags (today's images, unchanged).
r, out = ld([("CODE", SEG0, SEG0_ROWS, None), ("DATA",) + DATA + (None,),
             ("CODE",) + LEAF + (None,)])
flags, rel = image(out)
assert flags == [0, 0, 0] and rel == {(0, 3, 2), (1, 2, 0)}, (flags, rel)

# A literal target offset (FGX2_XREF_JSL_BANK) into a placeable segment
# cannot be relocated: refused.
r, out = ld([("CODE", bytes([0x22, 2, 0, 0]),
              [row(1, "a.s", 0, "FGX2_XREF_JSL_BANK t;2;2"),
               row(2, "a.s", 0, "FGX2_RELOC_COUNT 1")], []),
             ("DATA",) + DATA[:1] + ([],) + (None,), ("CODE",) + LEAF + ([],)])
assert r.returncode != 0 and "XREF_JSL_BANK" in r.stderr, r.stderr
print("test_offset_relocs: fgx_ld ok")


# --- the built tree: a dynamic and a static program flag every code
# segment that fits under LIMIT and carry its offset relocs.
ROOT = os.path.join(HERE, "..", "..", "..")
for prog in ("disk_src/sbin/update", "disk_src/bin/getty"):
    path = os.path.join(ROOT, prog)
    if not os.path.exists(path):
        print("test_offset_relocs: %s absent, built-tree check skipped" % prog)
        continue
    out = open(path, "rb").read()
    flags, rel = image(out)
    n = out[6]
    for i in range(n):
        size, _bss, kind = struct.unpack_from("<HHB", out, 16 + 8 * i)
        if kind != 0 or size > fgx_offrel.LIMIT:
            continue
        assert flags[i] == 1, (prog, i, flags)
        assert any(s == i and t == 0x80 | i for s, _o, t in rel), (prog, i)
print("test_offset_relocs: built tree ok")


# A manual manifest xref (kind jsl_bank) is a literal target offset too:
# into a placeable segment it is refused, as the listing-derived one is.
d = tempfile.mkdtemp()
try:
    segs = [("CODE", bytes([0x22, 2, 0, 0]), [], [],
             [{"offset": 3, "kind": "jsl_bank", "target_seg": 2}]),
            ("DATA", b"\0" * 4, [], None, []),
            ("CODE",) + LEAF + ([], [])]
    m = {"output": "out", "n_data_segment": 1, "segments": []}
    for i, (kind, data, rows, offs, xrefs) in enumerate(segs):
        open(os.path.join(d, f"s{i}"), "wb").write(data)
        open(os.path.join(d, f"s{i}.lst"), "w").write("".join(rows))
        e = {"bin": f"s{i}", "listing": f"s{i}.lst", "kind": kind, "bss": 0,
             "xrefs": xrefs}
        if offs is not None:
            e["offsets"] = offs
        m["segments"].append(e)
    open(os.path.join(d, "m.json"), "w").write(json.dumps(m))
    r = subprocess.run([sys.executable, LD, os.path.join(d, "m.json")],
                       capture_output=True, text=True)
    assert r.returncode != 0 and "literal offset" in r.stderr, (r.returncode, r.stderr)
finally:
    shutil.rmtree(d)
print("test_offset_relocs: manual xref ok")
