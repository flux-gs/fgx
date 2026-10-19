"""Parse a merlin32 -V seg0 listing into an address->symbol/mnemonic/srcfile map.

The merlin32 `-V` listing is pipe-delimited.  Splitting a line on '|' yields:

    cols[0] = listing line number
    cols[1] = "<include#> <filepath> <srcline>"   (filepath = split()[-2])
    cols[2] = Line Type   (Code / Directive / Comment / Empty / Equivalence / Data / Global / Macro)
    cols[3] = MX
    cols[4] = Reloc
    cols[5] = Size
    cols[6] = "<BB>/<OOOO>" optionally followed by " : <object bytes>"
    cols[7] = Source Code  (optional leading label, then mnemonic, then operand)

Only `Code` lines emit object bytes and are the only addresses a PC can sample,
so they are the only lines recorded in the offset->Sym map.  Labels (from
`Global`/ENT lines and col-0 prefixes on `Code` lines) update the current
enclosing symbol; `Equivalence` (EQU) labels are constants, not code
locations, and local (`@`) labels roll up to the enclosing global.
"""
import re
import bisect
from collections import namedtuple

Sym = namedtuple("Sym", "symbol mnemonic srcfile")

_ADDR = re.compile(r"([0-9A-Fa-f]{2})/([0-9A-Fa-f]{4})")
_MNEM = re.compile(r"\b([A-Z]{3,5})\b")             # 65816 mnemonics (incl. LDAL/STAL long forms)
_LABEL = re.compile(r"^([@A-Za-z_][A-Za-z0-9_]*)")  # leading label token (incl. local '@')


class SymbolTable:
    def __init__(self):
        self._by_off = {}   # offset -> Sym  (Code lines only)
        self._offsets = []  # sorted offsets
        self._max_off = -1  # highest recorded code offset (for the lookup range guard)

    @classmethod
    def from_listing(cls, path):
        st = cls()
        cur_sym = "?"
        code_banks = set()
        with open(path, errors="replace") as f:
            for line in f:
                cols = line.split("|")
                if len(cols) < 8:
                    continue
                ltype = cols[2].strip()
                m = _ADDR.search(cols[6])
                if not m:
                    continue
                off = int(m.group(2), 16)

                fparts = cols[1].split()
                srcfile = fparts[-2] if len(fparts) >= 2 else ""

                # In the pipe-split, the Source Code field keeps its delimiter
                # space: a label sits at leading-space 1, a bare mnemonic at the
                # ~31-column instruction indent.  So a label is present iff the
                # body's leading-space count is <= 1.
                src = cols[7].rstrip("\n")
                body = src.lstrip(" ")
                lead = len(src) - len(body)
                label = None
                if lead <= 1:
                    lm = _LABEL.match(body)
                    if lm:
                        label = lm.group(1)
                # fcc emits per-loop and per-jump labels (`_sed_L359`,
                # `ozunid_316`).  They are not functions, and letting them
                # become cur_sym splits one function's cost across its internal
                # branches -- so a function with many loops looks colder than a
                # straight-line one of the same weight.  Keep the enclosing
                # symbol instead.
                if (label and ltype != "Equivalence" and not label.startswith("@")
                        and not _GENERATED_LABEL.match(label)):
                    cur_sym = label

                # Only Code lines anchor an executable address.
                if ltype != "Code":
                    continue
                code_banks.add(int(m.group(1), 16))
                rest = body[len(label):] if label else body
                mm = _MNEM.search(rest)
                mnem = mm.group(1) if mm else ""
                st._by_off[off] = Sym(cur_sym, mnem, srcfile)
                if off > st._max_off:
                    st._max_off = off
        # The runtime histogram keys on the in-bank OFFSET only (the loader
        # relocates seg0 to a dynamic bank but preserves the offset).  That is
        # sound only while all executable code lives in ONE link bank.  Every
        # FGX tool's seg0 is single-bank today; fail loud if a future build
        # spans banks rather than silently mis-attributing colliding offsets.
        if len(code_banks) > 1:
            raise ValueError(
                "seg0 listing spans multiple link banks %s; the offset-only "
                "map cannot disambiguate -- add (bank,offset) keying." %
                sorted(hex(b) for b in code_banks))
        st._offsets = sorted(st._by_off)
        return st

    def lookup(self, offset):
        # Out-of-range offsets (e.g. a wrongly-included non-tool bank) resolve
        # to None -> categorized "unknown" rather than a fabricated symbol.
        if offset > self._max_off:
            return None
        i = bisect.bisect_right(self._offsets, offset) - 1
        if i < 0:
            return None
        return self._by_off[self._offsets[i]]


# fcc's generated labels: `<fn>_L<n>` loop/branch targets and `ozunid_<n>`.
_GENERATED_LABEL = re.compile(r"^(?:ozunid_\d+|.*_L\d+)$")

# NOTE ON "libc": the listing this maps against is seg0 ONLY.  The shared libc
# pile is seg2, in its own runtime bank, and is NOT in this table -- its samples
# land in kernel_io.  What this category actually names is crt0 plus the fcc
# runtime helpers that live in seg0 (`_fcc_*`, anything from /lib/).
CATEGORIES = ("user_body", "call_glue", "prologue_epilogue", "libc", "kernel_io", "unknown")

_CALL_GLUE = {"JSR", "JSL", "RTS", "RTL"}   # call/return glue (spec S5: JSR/JSL/RTS/RTL)
# Frame establish/teardown is precisely a per-function entry/exit RANGE (spec S5
# lists TSC/SEC/SBC/TCS) -- but SEC/SBC are overwhelmingly ordinary arithmetic
# (in sed, 281 SEC/SBC vs 356 TSC/TCS), so matching them by bare mnemonic would
# corrupt the roll-up.  We key only on the frame-pointer-unique TSC/TCS.  Some
# mid-function TSC/TCS (call-stack adjustment) thus lands here rather than in
# call_glue, but that is decision-neutral: S6 maps call_glue AND
# prologue_epilogue to the same lever (register-arg passing / cheaper frame).
_FRAME = {"TSC", "TCS"}


def _is_libc(sym):
    s = (sym.srcfile or "")
    return ("/lib/" in s) or s.endswith("crt0.s") or sym.symbol.startswith("_fcc_")


def categorize(sym, in_tool_bank):
    if not in_tool_bank:
        return "kernel_io"          # syscall / kernel / loader bank
    if sym is None:
        return "unknown"
    # libc is tested BEFORE glue/frame: a libc function's OWN internal
    # RTS/JSR/TSC is part of libc's intrinsic cost (addressed by the
    # "optimize libc" lever), NOT the user-call-site overhead an ABI change
    # would remove.  Glue/frame below therefore measure USER-code call sites,
    # which is what the S6 ABI lever actually targets.
    if _is_libc(sym):
        return "libc"
    if sym.mnemonic in _CALL_GLUE:
        return "call_glue"
    if sym.mnemonic in _FRAME:
        return "prologue_epilogue"
    return "user_body"
