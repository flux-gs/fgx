#!/usr/bin/env python3
"""test_data_fit.py -- fgx_ld refuses a data segment that runs into HEAP_LIM.

The loader writes the heap limit cell at $FFF8 of every data bank
(include/kernel.s HEAP_LIM), so a data segment whose bytes plus bss end past
$FFF8 would have its tail overwritten at load.  The linker refuses it instead.

  fits       data + bss ending exactly at $FFF8 links
  overflows  data + bss ending at $FFF9 is refused, naming $FFF8
Run: python3 tests/ld/test_data_fit.py
"""
import json, os, subprocess, sys, tempfile

LD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..",
                  "src", "ld", "fgx_ld.py")
HEAP_LIM = 0xFFF8


def row(n, src, off, text, typ="Macro"):
    return (f" {n} |  1      {src}    1 | {typ:<11} | 00 |"
            f"         |    0 | 00/{off:04X}               | {text}\n")


def link(d, data_bss):
    segs = [("CODE", bytes([0x6B]), [row(1, "c.s", 0, "FGX2_RELOC_COUNT 0")]),
            ("DATA", b"\x00\x00", [])]
    m = {"output": "out", "n_data_segment": 1, "segments": []}
    for i, (kind, data, rows) in enumerate(segs):
        open(os.path.join(d, f"s{i}"), "wb").write(data)
        open(os.path.join(d, f"s{i}.lst"), "w").write("".join(rows))
        m["segments"].append({"bin": f"s{i}", "listing": f"s{i}.lst",
                              "kind": kind,
                              "bss": data_bss if kind == "DATA" else 0})
    open(os.path.join(d, "m.json"), "w").write(json.dumps(m))
    return subprocess.run([sys.executable, LD, os.path.join(d, "m.json")],
                          capture_output=True, text=True)


def main():
    fails = 0
    with tempfile.TemporaryDirectory() as d:
        r = link(d, HEAP_LIM - 2)          # 2 data bytes + bss = $FFF8
        if r.returncode != 0:
            print("FAIL fits:", r.stderr.strip()[-300:])
            fails += 1
        r = link(d, HEAP_LIM - 1)          # ends at $FFF9
        if r.returncode == 0 or "$FFF8" not in r.stderr:
            print("FAIL overflows: a data segment ending at $FFF9 linked")
            fails += 1
    print("test_data_fit: %s" % ("%d FAILURE(S)" % fails if fails else
                                 "OK (fits at $FFF8, refused past it)"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
