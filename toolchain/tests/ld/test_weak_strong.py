#!/usr/bin/env python3
"""
test_weak_strong.py -- hermetic self-test for fgx_ld's resolution of a
globally-searched import (FGX2_FARCALL / FGX2_LONG_PTR), resolve_precedence():

  ld_dup_export_err      -- two CODE exports of the same name -> a
                            duplicate-symbol error.
  ld_single_export_binds -- one CODE segment exports the name -> that export
                            binds, link succeeds.

Builds tiny synthetic segments + Merlin -V listings in a temp dir (no
merlin32/MAME).  Run: python3 tests/ld/test_weak_strong.py
"""
import json
import os
import subprocess
import sys
import tempfile

LD = os.path.join(os.path.dirname(__file__), "..", "..", "src", "ld", "fgx_ld.py")

JSL_CALLER = bytes([0x22, 0x00, 0x00, 0x00, 0x60])   # JSL $000000 ; RTS
RTL_LEAF = bytes([0x6B])                              # RTL (a callee body byte)


def row(lineno, srcfile, off, source):
    """One Merlin -V 'Macro' listing row in fgx_ld's 8-pipe column format.
    Only the type (Macro), the BB/OOOO address column, and the source column
    matter to scan_listing; the rest are filler."""
    return (f" {lineno} |  1      {srcfile}    1 | Macro       | 00 |"
            f"         |    0 | 00/{off:04X}               | {source}\n")


def farcall_row(name):
    return row(1, "caller.s", 0x0000, f"FGX2_FARCALL      {name}")


def export_row(name):
    return row(1, "leaf.s", 0x0000, f"FGX2_EXPORT       {name}")


def write(d, fname, data):
    p = os.path.join(d, fname)
    mode = "wb" if isinstance(data, (bytes, bytearray)) else "w"
    with open(p, mode) as f:
        f.write(data)
    return fname


def run_case(name, segments, n_data, expect_ok, expect_msg=None):
    with tempfile.TemporaryDirectory() as d:
        segs = []
        for s in segments:
            entry = {"bin": write(d, s["bin"], s["bytes"]), "kind": s["kind"]}
            if "listing" in s:
                entry["listing"] = write(d, s["listing_name"], s["listing"])
            segs.append(entry)
        manifest = {"output": "out.bin", "n_data_segment": n_data,
                    "segments": segs}
        mpath = os.path.join(d, "m.json")
        with open(mpath, "w") as f:
            json.dump(manifest, f)
        r = subprocess.run([sys.executable, LD, mpath],
                           capture_output=True, text=True)
        ok = (r.returncode == 0)
        if ok != expect_ok:
            print(f"FAIL {name}: rc={r.returncode} stderr={r.stderr.strip()}")
            return False
        if not expect_ok and expect_msg and expect_msg not in r.stderr:
            print(f"FAIL {name}: expected '{expect_msg}' in: {r.stderr.strip()}")
            return False
        print(f"PASS {name}")
        return True


def caller_seg():
    return {"bin": "caller", "kind": "CODE", "bytes": JSL_CALLER,
            "listing": "".join([farcall_row("foo")]),
            "listing_name": "caller.lst"}


def leaf_seg(binname, kind, listname):
    return {"bin": binname, "kind": kind, "bytes": RTL_LEAF,
            "listing": "".join([export_row("foo")]),
            "listing_name": listname}


def data_seg():
    return {"bin": "dseg", "kind": "DATA", "bytes": bytes([0x00, 0x00])}


def main():
    results = [
        # two CODE exports of the same name -> duplicate-symbol error.
        run_case("ld_dup_export_err",
                 [caller_seg(),
                  leaf_seg("userA", "CODE", "userA.lst"),
                  leaf_seg("userB", "CODE", "userB.lst"),
                  data_seg()],
                 n_data=3, expect_ok=False,
                 expect_msg="defined by multiple segments"),
        # one segment exports the name -> it binds.
        run_case("ld_single_export_binds",
                 [caller_seg(),
                  leaf_seg("leaf", "CODE", "leaf.lst"),
                  data_seg()],
                 n_data=2, expect_ok=True),
    ]
    n_fail = results.count(False)
    print(f"{len(results) - n_fail}/{len(results)} resolution cases passed")
    sys.exit(1 if n_fail else 0)


if __name__ == "__main__":
    main()
