#!/usr/bin/env python3
"""check_module_data_refs.py -- catch module-local DATA read through the WRONG BANK.

An FGXM module's code runs in the module's own bank (PB, set by the JSL that
reached it) but with **DBR = the kernel bank**, because almost everything a
module touches is a kernel static.  That makes plain absolute addressing --
`LDA sym`, `STA sym,X`, `LDA |sym` -- correct for kernel symbols and WRONG for
the module's own data: the operand is a 16-bit offset applied to DBR, so it
lands at the module-relative offset inside the KERNEL.

The read succeeds, returns ordinary kernel code bytes, and moves whenever the
kernel's layout moves.  apple/fgx#93 was exactly this: net.mod's 4-byte
`_w5SockMask` table was read as `LDA _w5SockMask,X`, so socket allocation was
masking with whatever kernel byte sat at $23BE+X.  Two inert bytes added to
modload.s put `LDA _mlcState` there, the "mask" read as $1D, and the socket
allocator declared every socket busy.  Green and red were two bytes apart and
nothing in the build noticed.

The rule this enforces: **module-local data must be reached with the module's
own bank in DBR** (`PHK`/`PLB`, as net.s does around `_wpBaseLow`), or not
exist (compute it).  Code that legitimately runs under PHK/PLB waives with a
`MODBANK-OK` comment plus a reason, either on the access:

    LDA     |_wpBaseLow             ; MODBANK-OK: DBR = load bank (PHK/PLB above)

...or, better, once on the DECLARATION, covering every use of that datum:

    _ccWR3  DS  2                   ; MODBANK-OK: only from mod_init (DBR=ours)

Prefer the declaration form.  "This datum is only ever reached with our bank in
DBR" is a property of the datum, and stating it once beats repeating it at
forty call sites -- but it is still a claim about control flow that only a
human can make, which is why a bare waiver with no reason is not accepted.

What this does NOT catch: module data reached through a POINTER (`LDA #sym`
into a zero-page pair, then `[dp]`).  Those carry a bank byte explicitly and
are a different, visible construct.

Exit 0 clean, 1 on any unwaived site.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MODULES = REPO / "src" / "modules"

# Pseudo-ops that DEFINE storage.  A label on one of these is module-local data.
DATA_OPS = {
    "DS", "HEX", "ASC", "DFB", "DB", "DW", "DA", "ADR", "ADRL",
    "REV", "STR", "FLS", "DDB",
}

# Mnemonics whose operand is DBR-relative when written as plain absolute.
# (Long forms -- LDAL/STAL/... -- and immediate are bank-explicit and safe.)
DBR_MNEMONICS = {
    "LDA", "STA", "ADC", "SBC", "AND", "ORA", "EOR", "CMP", "BIT",
    "LDX", "LDY", "STX", "STY", "STZ", "CPX", "CPY",
    "INC", "DEC", "ASL", "LSR", "ROL", "ROR", "TRB", "TSB",
}

WAIVER = "MODBANK-OK"

# A MODULE-level waiver, for a module built from C.
#
# fcc addresses globals DBR-relatively, which is the very shape this checker
# exists to catch -- and in a C module it is CORRECT, because MOD_KC_ENTER
# (include/kernelc.s) puts DBR on the module's own bank for the whole time the
# C runs.  The waiver cannot go on the access or the declaration the way an
# asm one does: both live in fcc OUTPUT, and annotating generated files is
# exactly the workaround this tree forbids.  So it goes in the module ROOT,
# names the generated files it covers, and carries a reason like any other.
#
#     ; MODBANK-C-OK: <why>   in <module>.s   exempts <module>_c.s / .data.s
C_WAIVER = "MODBANK-C-OK"

LABEL_RE = re.compile(r"^([A-Za-z_@][A-Za-z0-9_]*)\s+([A-Z]+)\b")
# A code line may carry a LABEL in column 0 -- and the bug this tool exists
# for was on exactly such a line ("@wsa_l LDA _w5SockMask,X").  An earlier
# version of this regex demanded leading whitespace and silently skipped
# every labelled instruction in the tree.
CODE_RE = re.compile(r"^(?:[A-Za-z_@][A-Za-z0-9_]*)?\s+([A-Za-z]+)\s+(\S+)")


def strip_comment(line):
    """Merlin: ';' starts a comment; a line starting with '*' is all comment."""
    if line.lstrip().startswith("*"):
        return "", line
    i = line.find(";")
    if i < 0:
        return line, ""
    return line[:i], line[i:]


def _rel(path):
    """Repo-relative when possible; absolute otherwise (self-test tempdirs)."""
    try:
        return path.relative_to(REPO)
    except ValueError:
        return path


def scan_module(mod_dir):
    """-> (data_labels, findings) for one module directory."""
    sources = sorted(mod_dir.glob("*.s"))

    # Module-level C waiver: the root names it, and it covers only that
    # module's fcc output -- never hand-written assembly in the same
    # directory, which still has to say PHK/PLB and waive per line.
    mod = mod_dir.name
    c_generated = {f"{mod}_c.s", f"{mod}_c.data.s"}
    root = mod_dir / f"{mod}.s"
    c_waived = (root.exists()
                and C_WAIVER in root.read_text(errors="ignore"))
    if c_waived:
        sources = [s for s in sources if s.name not in c_generated]

    data_labels = {}                       # name -> "file:line"
    waived = set()                         # symbols waived at their declaration

    for src in sources:
        for n, raw in enumerate(src.read_text(errors="ignore").splitlines(), 1):
            code, comment = strip_comment(raw)
            m = LABEL_RE.match(code)
            if m and m.group(2) in DATA_OPS:
                data_labels[m.group(1)] = f"{_rel(src)}:{n}"
                if WAIVER in comment:
                    waived.add(m.group(1))

    findings = []
    for src in sources:
        for n, raw in enumerate(src.read_text(errors="ignore").splitlines(), 1):
            code, comment = strip_comment(raw)
            m = CODE_RE.match(code)
            if not m:
                continue
            mnem, operand = m.group(1).upper(), m.group(2)
            if mnem not in DBR_MNEMONICS:
                continue
            if operand.startswith("#") or operand.startswith(">"):
                continue                   # immediate / forced long: bank-explicit
            # Merlin's '|' forces 16-bit absolute -- still DBR-relative.
            sym = operand.lstrip("|").split(",")[0].lstrip("(").lstrip("[")
            if sym not in data_labels or sym in waived:
                continue
            if WAIVER in comment:
                continue
            findings.append((f"{_rel(src)}:{n}", mnem, sym,
                             data_labels[sym], raw.rstrip()))
    return data_labels, waived, findings


def self_test():
    """Prove the checker still catches the shape it exists for.

    apple/fgx#93's site was a LABELLED instruction (`@wsa_l LDA _w5SockMask,X`),
    and the first version of this tool's code regex demanded leading whitespace
    -- so it skipped every labelled instruction in the tree and reported the
    original bug as clean.  These cases pin that down.
    """
    import tempfile

    cases = [
        # (source, should_flag, what it is)
        ("@wsa_l          LDA     _tbl,X\n_tbl            HEX     01020408\n",
         True,  "labelled instruction reading a module-local table"),
        ("                LDA     _tbl,X\n_tbl            HEX     01020408\n",
         True,  "unlabelled instruction, same read"),
        ("                LDA     |_cell\n_cell           DS      2\n",
         True,  "'|' forces 16-bit absolute -- still DBR-relative"),
        ("                LDA     _tbl,X\n_tbl            HEX     0102   ; "
         + WAIVER + ": test\n",
         False, "waived at the declaration"),
        ("                LDA     _tbl,X          ; " + WAIVER + ": test\n"
         "_tbl            HEX     0102\n",
         False, "waived on the access line"),
        ("                LDAL    _tbl\n_tbl            HEX     0102\n",
         False, "long addressing carries its own bank"),
        ("                LDA     #_tbl\n_tbl            HEX     0102\n",
         False, "immediate is an address, not a read"),
        ("                LDA     _kernelThing\n",
         False, "not module-local at all"),
    ]

    failures = 0
    with tempfile.TemporaryDirectory() as td:
        for i, (src, want, what) in enumerate(cases):
            mod = Path(td) / f"m{i}"
            mod.mkdir()
            (mod / "m.s").write_text(src)
            _, _, findings = scan_module(mod)
            got = bool(findings)
            if got != want:
                failures += 1
                print(f"self-test FAIL: {what}: "
                      f"expected {'a finding' if want else 'clean'}, "
                      f"got {'a finding' if got else 'clean'}")

    if failures:
        return 1
    print(f"check_module_data_refs: self-test OK ({len(cases)} cases)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()

    if not MODULES.is_dir():
        print(f"check_module_data_refs: no {MODULES}", file=sys.stderr)
        return 1

    mods = sorted(d for d in MODULES.iterdir() if d.is_dir())
    total_labels = 0
    total_waived = 0
    all_findings = []
    for mod in mods:
        labels, waived, findings = scan_module(mod)
        total_labels += len(labels)
        total_waived += len(waived)
        all_findings += [(mod.name,) + f for f in findings]

    if all_findings:
        print("error: module-local DATA read through DBR (= the KERNEL bank), "
              "not the module's own bank:")
        for mod, where, mnem, sym, decl, text in all_findings:
            print(f"  {where}: {mnem} {sym}   ({mod}.mod-local data, "
                  f"declared {decl})")
            print(f"      {text.strip()}")
        print()
        print("  This does not read the module's data.  It reads the KERNEL at "
              "the same\n"
              "  16-bit offset, and the value changes whenever the kernel's "
              "layout does\n"
              "  (apple/fgx#93).  Fix by setting DBR to the module bank "
              "(PHK/PLB) and\n"
              f"  marking the line '; {WAIVER}: <why>', or by not needing the "
              "data at all.")
        return 1

    print(f"check_module_data_refs: OK ({len(mods)} modules, {total_labels} "
          f"module-local data symbols, {total_waived} waived, no unwaived "
          f"DBR-relative reads)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
