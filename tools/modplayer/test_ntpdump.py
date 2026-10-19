#!/usr/bin/env python3
"""Standalone test for ntpdump.py (no pytest dependency — repo uses plain scripts).
Run: python3 tools/modplayer/test_ntpdump.py   (exit 0 = pass, nonzero = fail)."""
import pathlib, sys

REPO = pathlib.Path(__file__).resolve().parents[2]
NTPDUMP = REPO / "tools/modplayer/ntpdump.py"
MODULE = REPO / "disk_src/root/ntp/beatbox.ntp"


def parse(path):
    import importlib.util
    spec = importlib.util.spec_from_file_location("ntpdump", NTPDUMP)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m.parse_ntp(path.read_bytes())


def test_header_magic_and_counts():
    d = parse(MODULE)
    assert d["magic"] == b"nfc!", f"magic={d['magic']!r}"
    assert d["version"] == 2, f"version={d['version']}"
    assert 1 <= d["ntracks"] <= 9, f"ntracks={d['ntracks']}"
    assert d["ninstr"] >= 1, f"ninstr={d['ninstr']}"
    # full-song effect tally is a dict of MOD-effect counts
    assert "effect_counts" in d
    # note-lifecycle keys always present (0 if absent)
    for k in ("setvol", "setvol0", "volslide", "notecut", "notedelay"):
        assert k in d["lifecycle_counts"], f"missing lifecycle key {k}"


def main():
    tests = [test_header_magic_and_counts]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"PASS {t.__name__}")
        except Exception as e:
            failed += 1
            print(f"FAIL {t.__name__}: {type(e).__name__}: {e}")
    print(f"--- {len(tests)-failed}/{len(tests)} passed ---")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
