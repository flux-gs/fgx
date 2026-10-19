#!/usr/bin/env python3
"""check_far_calls -- a far-bank export slot must be reached by JSL/JML, never JSR/JMP.

WHY THIS EXISTS (2026-08-01).  The far kernel bank (docs/history/plans/far-kernel-bank.md) is a
SECOND statically linked image.  Core code calls into it with
`JSL <farbank>:<slot>`, where <slot> is one of the KFAR_* EQUs in include/kfar.s.

A JSR (or JMP) to that same slot ASSEMBLES CLEANLY.  Both are 16-bit, same-bank
control transfers, so the assembler happily encodes the slot's bank-relative
offset and the linker has nothing to complain about -- there is no relocation to
fail and no bank byte to get wrong.  At runtime the call lands at that offset in
the CORE bank, i.e. in whatever core code now occupies it.  Nothing faults at the
call site; execution goes wrong somewhere else entirely, possibly much later.
Only JSL ($22) and JML ($5C) carry the 24-bit operand that actually crosses banks.

THE DETECTION RULE IS THE RESOLVED TARGET ADDRESS, NOT THE SYMBOL NAME.
The obvious rule -- "flag JSR/JMP whose operand text is a KFAR_* name" -- CANNOT
WORK, and this was proved empirically rather than assumed: Merlin32 EXPANDS EQU
symbols in the listing's source column.  A real injected `JSR KFAR_INIT` lists as

  ... | Code | 00 | | 3 | 02/0E1C : 20 06 00 | JSR   {{{$0000}+$06}+4*0}

The name is gone.  (Ordinary LABELS survive -- `JSR _RelocPatchWaveE` lists as
written -- but every export slot is an EQU, so a name scan would have matched
nothing, forever, and looked exactly like a clean kernel.)

So the rule is semantic instead of textual:

    a listing row is a violation when it is a Code row of size 3 whose opcode is
    $20 (JSR abs) or $4C (JMP abs) and whose 16-bit target falls inside the far
    bank's export table, KFAR_EXPORT_BASE .. +KFAR_TABLE_SZ.

This needs no upkeep as slots are added, and it is strictly stronger than a name
scan: it also catches a raw `JSR $0006`.  It cannot false-positive on core code,
because the table regions (KFAR_EXPORT_BASE..+KFAR_TABLE_SZ in include/kfar.s,
KTTY_EXPORT_BASE..+KTTY_TABLE_SZ in include/ktty.s, both a few hundred bytes from
$0000) sit far below the core bank's code origin -- no core instruction
legitimately targets them.

WHAT IS NOT A CALL TARGET.  This is why the header/geometry constants
(KFAR_MAGIC, KFAR_ABI_VERSION, KFAR_EXPORT_BASE, KFAR_HDR_*, KFAR_SLOT_COUNT,
KFAR_SLOT0, KFAR_TABLE_SZ) need no exclusion list.  `LDA #KFAR_SLOT_COUNT`, a
`DA KFAR_INIT`, an EQU line and any comment are all invisible here: none of them
is a $20/$4C Code row.  Only control transfer counts.  Indirect jumps ($6C, $7C,
$DC) are likewise not flagged -- those read a pointer, they do not name a slot.

The geometry comes from include/kfar.s (never a copy) and its EQU expressions are
evaluated, so a renamed or reformatted constant makes this checker fail loudly at
parse time rather than quietly matching nothing.

Usage:
  check_far_calls.py <listing>     # e.g. build/fgx_S01_KernelMain_Output.txt
  check_far_calls.py --self-test
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# EVERY STATICALLY LINKED BANK WITH AN EXPORT TABLE, checked in one pass.
#
# The far bank and the tty bank put their tables at the same offset and size, so
# the RANGE test is the same test twice -- but the two are independent EQU sets
# that can drift apart, and a hit has to be able to say WHICH slot of WHICH bank
# was called short.  Both are parsed, both ranges are checked, and the names are
# reported per bank.  Adding a fourth bank is a row here.
ABIS = (("far", os.path.join(ROOT, "include", "kfar.s"), "KFAR"),
        ("tty", os.path.join(ROOT, "include", "ktty.s"), "KTTY"))

# KFAR_INIT           EQU     KFAR_SLOT0+4*0  ; slot 0: Far_BankInit
_HEX = re.compile(r"\$([0-9A-Fa-f]+)")
_ARITH = re.compile(r"[0-9+\-*/() ]+")


def _equ_re(prefix):
    return re.compile(r"^\s*(%s_\w+)\s+EQU\s+([^;\n]+)" % prefix, re.MULTILINE)


def _name_re(prefix):
    return re.compile(r"\b%s_\w+\b" % prefix)

# The 16-bit control transfers.  $22 JSL / $5C JML are the correct cross-bank
# forms and are deliberately absent.
BAD_OPCODE = {0x20: "JSR", 0x4C: "JMP"}


def equs(text, prefix="KFAR", path="include/kfar.s"):
    """Parse a bank ABI file into {name: expression-text}."""
    found = dict(_equ_re(prefix).findall(text))
    if not found:
        raise SystemExit(
            f"check_far_calls: no {prefix}_* EQU found in {path} -- the ABI file "
            f"was renamed, moved, or its EQUs reformatted. Fix this parser "
            f"rather than deleting the check: with no geometry, every listing "
            f"looks clean.")
    return found


def value(table, name, seen=(), prefix="KFAR", path="include/kfar.s"):
    """Evaluate one <prefix>_* EQU expression (Merlin32 arithmetic on $hex + names)."""
    if name in seen:
        raise SystemExit(f"check_far_calls: {name} in {path} is defined in "
                         f"terms of itself.")
    if name not in table:
        raise SystemExit(f"check_far_calls: {name} is missing from {path} -- "
                         f"that bank's ABI was renamed. Fix this parser.")
    expr = _HEX.sub(lambda m: str(int(m.group(1), 16)), table[name])
    expr = _name_re(prefix).sub(
        lambda m: f"({value(table, m.group(0), seen + (name,), prefix, path)})",
        expr).strip()
    if not _ARITH.fullmatch(expr):
        raise SystemExit(f"check_far_calls: cannot evaluate {name} = "
                         f"{table[name].strip()!r} from {path}. Teach this "
                         f"parser the new syntax rather than deleting the check.")
    return eval(expr)


def export_table(table, prefix="KFAR", path="include/kfar.s"):
    """Return (lo, hi_exclusive, {address: 'NAME,NAME'}) for the export table.

    The name map is built from every KFAR_* EQU that lands in the region -- no
    hand-curated slot list to fall out of date.  Several names can share one
    address (KFAR_INIT and KFAR_SLOT0 both mean slot 0); all are reported.

    An OFFSET is written relative to another <prefix>_* name (both ABI files
    express every one as *_EXPORT_BASE+n or *_SLOT0+4n), whereas a plain scalar
    is not.
    That distinction is what keeps KFAR_SLOT_COUNT (=32, numerically inside the
    table) from being reported as if it were the address of slot 6.  It affects
    naming in the message only -- the range check above is what decides.
    """
    lo = value(table, f"{prefix}_EXPORT_BASE", (), prefix, path)
    hi = lo + value(table, f"{prefix}_TABLE_SZ", (), prefix, path)
    if hi <= lo:
        raise SystemExit(f"check_far_calls: {prefix}_TABLE_SZ is not positive in "
                         f"{path} -- the export-table geometry is wrong.")
    names, name_re = {}, _name_re(prefix)
    for name, expr in table.items():
        v = value(table, name, (), prefix, path)
        if lo <= v < hi and name_re.search(expr):
            names.setdefault(v, []).append(name)
    return lo, hi, {a: ",".join(sorted(n)) for a, n in names.items()}


def bad_call(lo, hi, opcode, size, target):
    """THE decision, as a real function.

    True when a 3-byte JSR/JMP abs lands inside the far bank's export table.
    main() and the self-test both go through here, so the self-test exercises the
    shipped logic instead of restating it.
    """
    return size == 3 and opcode in BAD_OPCODE and lo <= target < hi


def scan(lines, lo, hi):
    """Scan Merlin32 listing rows; return [(srcfile, srcline, mnemonic, target)].

    Listing columns are pipe-separated:
      Line | # File Line | Line Type | MX | Reloc | Size | Address Object Code | Source
    The source column may itself contain a pipe, so the split is capped.  The
    location is taken from the "# File" column so the message points at real
    source, not at a listing row number nobody can act on.
    """
    hits = []
    for row in lines:
        cols = row.split("|", 7)
        if len(cols) < 8 or cols[2].strip() != "Code":
            continue
        loc = cols[1].split()
        obj = cols[6].split(":", 1)
        if len(loc) < 3 or len(obj) < 2:
            continue
        try:
            size = int(cols[5])
            code = [int(b, 16) for b in obj[1].split()]
        except ValueError:
            continue
        if len(code) < 3:
            continue
        if bad_call(lo, hi, code[0], size, code[1] | code[2] << 8):
            hits.append((loc[-2], loc[-1], BAD_OPCODE[code[0]],
                         code[1] | code[2] << 8))
    return hits


def _row(obj, kind="Code", size=3, srcfile="main.s", srcline="117", src=""):
    """Build one synthetic listing row (self-test only)."""
    return (f"  100 |  1        {srcfile}   {srcline} | {kind}        | 00 |"
            f"         | {size:4d} | 02/0E1C : {obj}    |          {src}")


def _selftest():
    """Prove the checker can FAIL.  This gate passes by finding nothing, so a
    broken listing parse, a wrong opcode set, or unparsable geometry all look
    exactly like a clean kernel.  Silence is trusted only after this shows teeth.
    """
    table = equs("KFAR_EXPORT_BASE EQU $0000\n"
                 "KFAR_SLOT_COUNT  EQU 32\n"
                 "KFAR_SLOT0       EQU KFAR_EXPORT_BASE+$06\n"
                 "KFAR_TABLE_SZ    EQU $06+4*KFAR_SLOT_COUNT\n"
                 "KFAR_HDR_MAGIC   EQU KFAR_EXPORT_BASE+$00 ; word\n"
                 "KFAR_INIT        EQU KFAR_SLOT0+4*0       ; slot 0\n")
    fails = []

    lo, hi, names = export_table(table)
    if (lo, hi) != (0x0000, 0x0086):
        fails.append(f"export table parsed as ${lo:04X}..${hi:04X}, want "
                     f"$0000..$0086")
    if names.get(0x0006) != "KFAR_INIT,KFAR_SLOT0":
        fails.append(f"slot 0 named {names.get(0x0006)!r}, want KFAR_INIT+SLOT0")
    # KFAR_SLOT_COUNT is 32, which is numerically inside the table but is a
    # count, not an offset -- it must not be reported as slot 6's name.
    if 0x0020 in names:
        fails.append(f"scalar KFAR_SLOT_COUNT mistaken for the address "
                     f"{names[0x0020]!r}")

    # THE SECOND BANK IS A SECOND PREFIX, and the prefix has to be doing real
    # work.  If _equ_re/_name_re ignored it and kept matching KFAR_ only, the
    # tty ABI would parse as EMPTY -- and an empty table raises rather than
    # silently covering nothing, so the failure to catch is the opposite one:
    # a prefix that matches everything.  Both directions are asserted.
    ttytext = ("KTTY_EXPORT_BASE EQU $0000\n"
               "KTTY_SLOT_COUNT  EQU 32\n"
               "KTTY_SLOT0       EQU KTTY_EXPORT_BASE+$06\n"
               "KTTY_TABLE_SZ    EQU $06+4*KTTY_SLOT_COUNT\n"
               "KTTY_INIT        EQU KTTY_SLOT0+4*0       ; slot 0\n")
    tlo, thi, tnames = export_table(equs(ttytext, "KTTY", "include/ktty.s"),
                                    "KTTY", "include/ktty.s")
    if (tlo, thi) != (0x0000, 0x0086):
        fails.append(f"tty ABI parsed as ${tlo:04X}..${thi:04X}, want $0000..$0086")
    if tnames.get(0x0006) != "KTTY_INIT,KTTY_SLOT0":
        fails.append(f"tty slot 0 named {tnames.get(0x0006)!r}, want "
                     f"KTTY_INIT+SLOT0")
    try:
        equs(ttytext, "KFAR", "include/kfar.s")
        fails.append("a KTTY-only ABI file parsed as KFAR -- the prefix is "
                     "not being used, so one bank's geometry would be read "
                     "for the other's")
    except SystemExit:
        pass
    # ...and every ABI row must name a file that exists and parses, or a bank
    # goes unchecked with no message at all.
    for label, path, prefix in ABIS:
        try:
            with open(path, errors="replace") as f:
                lo_, hi_, _n = export_table(equs(f.read(), prefix, path),
                                            prefix, path)
            if hi_ <= lo_:
                fails.append(f"{label}: {path} gave an empty export range")
        except (OSError, SystemExit) as e:
            fails.append(f"{label}: {path} is unreadable or unparsable ({e})")

    # THE decision, exercised through the same function main() uses.
    # (opcode, size, target, must_be_flagged, what it is)
    cases = [
        (0x20, 3, 0x0006, True,  "JSR KFAR_INIT"),
        (0x4C, 3, 0x0006, True,  "JMP KFAR_INIT"),
        (0x20, 3, 0x0000, True,  "JSR into the table header"),
        (0x20, 3, 0x0085, True,  "JSR to the last table byte"),
        (0x22, 4, 0x0006, False, "JSL KFAR_INIT (correct)"),
        (0x5C, 4, 0x0006, False, "JML KFAR_INIT (correct)"),
        (0x20, 3, 0x0E68, False, "ordinary core-bank JSR"),
        (0x20, 3, 0x0086, False, "JSR just past the table"),
        (0xA9, 3, 0x0020, False, "LDA #KFAR_SLOT_COUNT"),
        (0x6C, 3, 0x0006, False, "JMP ($0006) indirect -- reads a pointer"),
    ]
    for opcode, size, target, want, what in cases:
        if bad_call(lo, hi, opcode, size, target) != want:
            verb = "missed" if want else "false positive on"
            fails.append(f"{verb}: {what} (${opcode:02X} -> ${target:04X})")

    # End to end, through the listing parser main() uses.  The Data row proves
    # the Line Type / size gating: those same bytes as DATA must not be flagged.
    rows = [
        _row("20 06 00", srcfile="far_bringup.s", srcline="42",
             src="JSR   {{{$0000}+$06}+4*0}"),      # exactly what Merlin lists
        _row("22 06 00 08", size=4, srcline="10", src="JSL   $08:KFAR_INIT"),
        _row("20 06 00", kind="Data", srcline="11", src="HEX   200600"),
        _row("20 68 0E", srcline="12", src="JSR   _RelocPatchWaveE"),
        "------+------+------+",
        " 641 |  4    kfar.s  62 | Equivalence | 00 | |    0 | 02/0B00      "
        "         | KFAR_INIT  EQU  {{$0000}+$06}+4*0",
        "  99 |  1    main.s  13 | Comment     | 00 | |    0 | 02/0B00      "
        "         | ; never JSR KFAR_INIT, always JSL",
    ]
    hits = scan(rows, lo, hi)
    if hits != [("far_bringup.s", "42", "JSR", 0x0006)]:
        fails.append(f"listing scan returned {hits}, want exactly one JSR hit at "
                     f"far_bringup.s:42")

    # Unusable geometry must raise, not silently pass everything.
    for label, text in (
            ("empty kfar.s", "; nothing but a comment\n"),
            ("missing KFAR_TABLE_SZ", "KFAR_EXPORT_BASE EQU $0000\n"),
            ("unevaluatable expression",
             "KFAR_EXPORT_BASE EQU $0000\nKFAR_TABLE_SZ EQU >SOMELABEL\n"),
            ("self-referential EQU",
             "KFAR_EXPORT_BASE EQU $0000\nKFAR_TABLE_SZ EQU KFAR_TABLE_SZ+1\n"),
    ):
        try:
            export_table(equs(text))
            fails.append(f"{label} did not raise")
        except SystemExit:
            pass

    if fails:
        for f in fails:
            print(f"  {f}", file=sys.stderr)
        print(f"check_far_calls self-test: {len(fails)} FAILURE(S)")
        return 1
    flagged = sum(1 for c in cases if c[3])
    print(f"check_far_calls self-test: OK (rejects JSR/JMP into the export "
          f"table, accepts JSL/JML, ignores non-call rows -- data, EQU, comment, "
          f"immediate, indirect -- and locates hits by source file:line; "
          f"{flagged} caught, {len(cases) - flagged} correctly ignored; "
          f"{len(ABIS)} bank ABI(s) parse and stay apart)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return _selftest()

    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if len(args) != 1:
        sys.exit("usage: check_far_calls.py <listing> | --self-test")
    listing = args[0]

    # One geometry per statically linked bank.  They coincide today ($0000..
    # $0085 both), and that is not something to lean on: they are separate EQU
    # sets in separate files and only this loop keeps a divergence covered.
    banks, rc = [], 0
    for label, path, prefix in ABIS:
        with open(path, errors="replace") as f:
            table = equs(f.read(), prefix, path)
        banks.append((label,) + export_table(table, prefix, path))

    with open(listing, errors="replace") as f:
        rows = f.readlines()

    for label, lo, hi, names in banks:
        hits = scan(rows, lo, hi)
        if not hits:
            continue
        rc = 1
        print(f"check_far_calls: {len(hits)} 16-bit call(s) into the {label.upper()} "
              f"KERNEL BANK export table (${lo:04X}..${hi - 1:04X}). JSR/JMP are "
              f"same-bank: they assemble without error and transfer to that "
              f"offset in the CORE bank, running whatever code now lives there "
              f"-- no link error, no fault at the call site, and the damage "
              f"surfaces somewhere else entirely. Use JSL (or JML) so the bank "
              f"byte is actually carried:", file=sys.stderr)
        for srcfile, srcline, mnemonic, target in hits:
            slot = names.get(target, "an unnamed offset in the table")
            print(f"  {srcfile}:{srcline}: {mnemonic} ${target:04X} ({slot}) "
                  f"-- must be JSL <{label}bank>:{slot.split(',')[0]}",
                  file=sys.stderr)
    if rc:
        return rc

    where = ", ".join(f"{label} ${lo:04X}..${hi - 1:04X} ({len(names)} named)"
                      for label, lo, hi, names in banks)
    print(f"check_far_calls: clean (export tables: {where}; no JSR/JMP into any "
          f"of them from {os.path.basename(listing)})")
    return 0


if __name__ == "__main__":
    # sys.exit: main() RETURNS its status, and a check that cannot fail the
    # build is exactly the defect it exists to catch.
    sys.exit(main() or 0)
