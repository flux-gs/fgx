#!/usr/bin/env python3
"""
test_d1_gate.py — hermetic self-test for fgx_ld's D1 bank-consistency gate.

Builds tiny synthetic segments in a temp dir (no merlin32/MAME needed) and
drives fgx_ld.py via manifests with MANUAL xrefs, asserting:
  1. a well-formed jsl_bank reloc (JSL $000000 shape) links,
  2. a jsl_bank reloc whose patch-3 opcode is not JSL ($22) fails,
  3. a jsl_bank reloc over a non-$00 placeholder byte fails,
  4. two relocs patching the same byte fail,
  5. a jsl_bank reloc targeting the DATA segment fails.
Run: python3 tests/ld/test_d1_gate.py
"""
import json
import os
import subprocess
import sys
import tempfile

LD = os.path.join(os.path.dirname(__file__), "..", "..", "src", "ld", "fgx_ld.py")

JSL_SHAPE = bytes([0x22, 0x00, 0x00, 0x00, 0x60])   # JSL $000000 ; RTS
RTS_SHAPE = bytes([0x60, 0x00, 0x00, 0x00, 0x60])   # RTS (not a JSL)
DIRTY_BANK = bytes([0x22, 0x00, 0x00, 0x71, 0x60])  # bank byte already non-zero


def run_case(name, seg0_bytes, xrefs, expect_ok, expect_msg=None):
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, "seg0"), "wb") as f:
            f.write(seg0_bytes)
        with open(os.path.join(d, "seg1"), "wb") as f:
            f.write(bytes([0x00, 0x00]))            # 2-byte DATA seg
        manifest = {
            "output": "out.bin",
            "n_data_segment": 1,
            "segments": [
                {"bin": "seg0", "kind": "CODE", "xrefs": xrefs},
                {"bin": "seg1", "kind": "DATA"},
            ],
        }
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


def main():
    results = [
        run_case("good_jsl_reloc", JSL_SHAPE,
                 [{"offset": 3, "kind": "jsl_bank", "target_seg": 0}], True),
        run_case("not_a_jsl", RTS_SHAPE,
                 [{"offset": 3, "kind": "jsl_bank", "target_seg": 0}], False,
                 "does not patch a JSL bank byte"),
        run_case("dirty_placeholder", DIRTY_BANK,
                 [{"offset": 3, "kind": "jsl_bank", "target_seg": 0}], False,
                 "not the $00 placeholder"),
        run_case("double_patch", JSL_SHAPE,
                 [{"offset": 3, "kind": "jsl_bank", "target_seg": 0},
                  {"offset": 3, "kind": "jsl_bank", "target_seg": 0}], False,
                 "patched by two relocs"),
        run_case("call_into_data", JSL_SHAPE,
                 [{"offset": 3, "kind": "jsl_bank", "target_seg": 1}], False,
                 "targets non-code segment"),
    ]
    n_fail = results.count(False)
    print(f"{len(results) - n_fail}/{len(results)} D1 gate cases passed")
    sys.exit(1 if n_fail else 0)


if __name__ == "__main__":
    main()
