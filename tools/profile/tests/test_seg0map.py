import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from seg0map import SymbolTable, Sym, categorize

FIX = os.path.join(os.path.dirname(__file__), "fixtures", "mini_seg0.txt")


def test_parses_labels_mnemonics_srcfile():
    st = SymbolTable.from_listing(FIX)
    assert st.lookup(0x0112) == Sym("main", "TSC", "sed.s")          # label line's first code
    assert st.lookup(0x0113) == Sym("main", "JSR", "sed.s")          # still inside main
    assert st.lookup(0x0358) == Sym("_sed_match", "LDA", "sed.s")    # new label
    assert st.lookup(0x0010).srcfile.endswith("crt0.s")             # libc/runtime srcfile
    assert st.lookup(0x0010).mnemonic == "RTS"
    assert st.lookup(0x0010).symbol == "_crt0_start"


def test_lookup_between_addrs_uses_enclosing():
    st = SymbolTable.from_listing(FIX)
    assert st.lookup(0x0359).symbol == "_sed_match"   # no code line at 0x359 -> nearest prior


def test_local_label_rolls_up_to_enclosing_global():
    st = SymbolTable.from_listing(FIX)
    # @loop_done is a local (@) label; attribution rolls up to the enclosing global.
    assert st.lookup(0x035C) == Sym("_sed_match", "RTS", "sed.s")


def test_equates_and_directives_not_recorded():
    st = SymbolTable.from_listing(FIX)
    # Only Code lines are recorded; the Global ENT line at 0x0112 does not
    # overwrite the Code line's mnemonic, and no equate/comment leaks in.
    assert st.lookup(0x0112).mnemonic == "TSC"


def test_categorize():
    user_jsr = Sym("main", "JSR", "sed.s")
    user_lda = Sym("main", "LDA", "sed.s")
    user_tcs = Sym("main", "TCS", "sed.s")
    libc_lda = Sym("_fcc_memcpy", "LDA", "../../src/userland/lib/string.s")
    assert categorize(user_jsr, True) == "call_glue"
    assert categorize(user_tcs, True) == "prologue_epilogue"
    assert categorize(user_lda, True) == "user_body"
    assert categorize(libc_lda, True) == "libc"
    assert categorize(user_lda, False) == "kernel_io"     # sample outside tool banks
    assert categorize(None, True) == "unknown"


def test_libc_internal_glue_counts_as_libc():
    # A libc function's OWN internal RTS/JSR/TSC is libc's intrinsic cost, not a
    # user-call-site the ABI lever would remove -> must categorize as libc
    # (libc check runs before the glue/frame mnemonic checks).
    assert categorize(Sym("_fcc_divs16", "RTS", "../../src/userland/lib/libc.s"), True) == "libc"
    assert categorize(Sym("memcpy", "JSR", "../../src/userland/lib/string.s"), True) == "libc"
    assert categorize(Sym("_crt0_start", "TCS", "../../src/userland/lib/crt0.s"), True) == "libc"


def test_lookup_range_guard():
    st = SymbolTable.from_listing(FIX)
    # The fixture's highest code offset is 0x0408; anything past it is unknown.
    assert st.lookup(0xFFFF) is None
    assert st.lookup(0x0409) is None
    assert st.lookup(0x0408).mnemonic == "LDAL"   # in range


def test_parses_4letter_long_mnemonic():
    st = SymbolTable.from_listing(FIX)
    assert st.lookup(0x0408) == Sym("_sed_emit", "LDAL", "sed.s")


def test_tcs_parse_path_is_prologue_epilogue():
    st = SymbolTable.from_listing(FIX)
    sym = st.lookup(0x0400)
    assert sym == Sym("_sed_emit", "TCS", "sed.s")
    assert categorize(sym, True) == "prologue_epilogue"


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
