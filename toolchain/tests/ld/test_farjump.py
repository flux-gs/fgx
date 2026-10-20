#!/usr/bin/env python3
"""test_farjump.py -- fgx_ld: FGX2_FARJUMP, LIBC_EXPORT, and the segment cap.

  farjump_resolves     a JML placeholder resolves like a FARCALL: linked
                       when the target is exported ...
  farjump_unresolved   ... and REFUSED when it is not (today's fgx_ld counts
                       the row, resolves nothing, and ships $000000).
  libc_export_no_libc  a CODE segment carrying libc.s: its LIBC_EXPORT row
                       IS the export, and still counts toward its file's
                       FGX2_RELOC_COUNT.
  kind_libc_unknown    a manifest naming kind LIBC is refused.
  nine_segs_refused    a 9-segment manifest is refused: TCB_BankList has 8
                       rows.
  eight_segs_ok        an 8-segment manifest links: the cap is exactly 8,
                       not off by one in either direction.
Run: python3 tests/ld/test_farjump.py
"""
import json, os, subprocess, sys, tempfile

LD = os.path.join(os.path.dirname(__file__), "..", "..", "src", "ld", "fgx_ld.py")
JML = bytes([0x5C, 0x00, 0x00, 0x00])
JSL_RTS = bytes([0x22, 0x00, 0x00, 0x00, 0x60])
LEAF = bytes([0xEA, 0xEA, 0x6B])      # NOP NOP RTL: the export sits at +2


def row(n, src, off, text, typ="Macro"):
    return (f" {n} |  1      {src}    1 | {typ:<11} | 00 |"
            f"         |    0 | 00/{off:04X}               | {text}\n")


def link(d, segs):
    m = {"output": "out", "n_data_segment": 1, "segments": []}
    for i, (kind, data, rows) in enumerate(segs):
        open(os.path.join(d, f"s{i}"), "wb").write(data)
        open(os.path.join(d, f"s{i}.lst"), "w").write("".join(rows))
        m["segments"].append({"bin": f"s{i}", "listing": f"s{i}.lst",
                              "kind": kind, "bss": 0})
    open(os.path.join(d, "m.json"), "w").write(json.dumps(m))
    return subprocess.run([sys.executable, LD, os.path.join(d, "m.json")],
                          capture_output=True, text=True)


def main():
    fails = 0
    with tempfile.TemporaryDirectory() as d:
        # seg0: a thunk `leaf FGX2_FARJUMP leaf`; seg1 data; seg2 exports leaf
        r = link(d, [
            ("CODE", JML, [row(1, "t.s", 0, "leaf FGX2_FARJUMP leaf"),
                           row(2, "t.s", 0, "FGX2_RELOC_COUNT 1")]),
            ("DATA", b"\x00\x00", []),
            ("CODE", LEAF, [row(1, "p.s", 2, "LIBC_EXPORT leaf"),
                            row(2, "p.s", 0, "FGX2_RELOC_COUNT 1")]),
        ])
        if r.returncode != 0:
            print("FAIL farjump_resolves:", r.stderr.strip()[-300:]); fails += 1
        r = link(d, [
            ("CODE", JML, [row(1, "t.s", 0, "leaf FGX2_FARJUMP leaf"),
                           row(2, "t.s", 0, "FGX2_RELOC_COUNT 1")]),
            ("DATA", b"\x00\x00", []),
            ("CODE", LEAF, [row(1, "p.s", 2, "LIBC_EXPORT other"),
                            row(2, "p.s", 0, "FGX2_RELOC_COUNT 1")]),
        ])
        if r.returncode == 0 or "unresolved" not in r.stderr:
            print("FAIL farjump_unresolved: linked with no 'leaf' anywhere")
            fails += 1
        # seg0 holds the caller AND libc.s's getpid.
        r = link(d, [
            ("CODE", JSL_RTS + LEAF, [row(1, "c.s", 0, "FGX2_FARCALL getpid"),
                                      row(2, "p.s", 7, "LIBC_EXPORT getpid"),
                                      row(3, "c.s", 0, "FGX2_RELOC_COUNT 1"),
                                      row(4, "p.s", 0, "FGX2_RELOC_COUNT 1")]),
            ("DATA", b"\x00\x00", []),
        ])
        if r.returncode != 0:
            print("FAIL libc_export_no_libc:", r.stderr.strip()[-300:]); fails += 1
        r = link(d, [("CODE", LEAF, []), ("DATA", b"\x00\x00", []),
                     ("LIBC", LEAF, [])])
        if r.returncode == 0 or "unknown kind 'LIBC'" not in r.stderr:
            print("FAIL kind_libc_unknown:", r.stderr.strip()[-300:] or "linked")
            fails += 1
        r = link(d, [("CODE", LEAF, []), ("DATA", b"\x00\x00", [])]
                 + [("CODE", LEAF, [])] * 7)
        if r.returncode == 0 or "FGX2 cap is 8" not in r.stderr:
            print("FAIL nine_segs_refused:", r.stderr.strip()[-300:] or "linked")
            fails += 1
        r = link(d, [("CODE", LEAF, []), ("DATA", b"\x00\x00", [])]
                 + [("CODE", LEAF, [])] * 6)
        if r.returncode != 0:
            print("FAIL eight_segs_ok:", r.stderr.strip()[-300:]); fails += 1
    print("test_farjump: %s" % ("FAILED" if fails else "ok"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
