import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from seg0map import SymbolTable
from profile_report import detect_tool_banks, build_profile, render_report

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "mini_seg0.txt")


def test_detect_tool_banks_picks_dominant():
    samples = {"0B:0112": 50, "0B:0358": 40, "00:1234": 2}  # bank 0B dominates
    assert detect_tool_banks(samples) == {0x0B}


def test_build_profile_categorizes():
    st = SymbolTable.from_listing(FIX)
    samples = {"0B:0113": 10, "0B:0358": 30, "00:9999": 5}  # JSR / LDA / kernel
    prof = build_profile(samples, st, {0x0B})
    assert prof["total"] == 45
    assert prof["by_category"]["call_glue"] == 10      # 0B:0113 = JSR
    assert prof["by_category"]["user_body"] == 30      # 0B:0358 = LDA in _sed_match
    assert prof["by_category"]["kernel_io"] == 5       # bank 00 not a tool bank


def test_detect_tool_banks_excludes_exactly_threshold():
    # A bank at exactly 10% is NOT a tool bank (strict >): keeps a borderline
    # kernel/syscall bank from being offset-resolved against seg0.
    samples = {"0B:0000": 90, "00:0000": 10}  # bank 00 == 10% exactly
    assert detect_tool_banks(samples) == {0x0B}


def test_detect_tool_banks_excludes_kernel_bank():
    # The kernel bank can dominate an I/O-heavy run; its offsets collide with the
    # tool's seg0, so it must never be picked as a tool bank.
    samples = {"6B:5F4C": 60, "7D:8358": 40}  # 6B=sed code, 7D=kernel (40% but excluded)
    assert detect_tool_banks(samples, exclude_banks={0x7D}) == {0x6B}


def test_parse_key_validation_rejects_malformed():
    import profile_report as pr
    for bad in ("0B0112", "0B:0112:9", ":0112", "0B:"):
        try:
            pr._parse_key(bad)
            assert False, f"expected ValueError for {bad!r}"
        except ValueError:
            pass


def test_build_profile_over_range_sample_is_unknown():
    st = SymbolTable.from_listing(FIX)
    # 0x9999 is past the fixture's max code offset (0x0408) but in tool bank 0B.
    prof = build_profile({"0B:9999": 7, "0B:0408": 3}, st, {0x0B})
    assert prof["by_category"]["unknown"] == 7    # over-range -> unknown, not fabricated
    assert prof["total"] == 10


def test_render_report_has_sections():
    prof = {"sed": ({"by_category": {"user_body": 30, "call_glue": 10},
                     "by_symbol": [("_sed_match", 30)], "total": 40}, {"wall_s": 12.3})}
    out = render_report(prof, {"date": "2026-06-28"})
    assert "user_body" in out and "_sed_match" in out and "12.3" in out


# ---- no-pytest fallback runner (pytest is not installed on this host) ----
if __name__ == "__main__":
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    fails = 0
    for fn in fns:
        try:
            fn()
            print(f"PASS {fn.__name__}")
        except AssertionError as e:
            fails += 1
            print(f"FAIL {fn.__name__}: {e!r}")
        except Exception as e:
            fails += 1
            print(f"ERROR {fn.__name__}: {e!r}")
    print(f"\n{len(fns)-fails}/{len(fns)} passed")
    sys.exit(1 if fails else 0)
