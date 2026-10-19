#!/usr/bin/env python3
"""
check_mx.py - Detect Merlin32 MX-tracking leaks across branches.

Merlin32 tracks the M/X width-flags state by linear source scan.  If a
branch target is reached at runtime with a different MX than Merlin
deduced, immediate-operand instructions at/after the target are encoded
with the wrong byte count, causing subtle crashes (classic: LDA #$xx gets
3 bytes in M=0 but runtime is M=1, so the trailing $00 is fetched as BRK).

This checker parses the Merlin listing files produced by `merlin32 -V ...`
and flags every intra-segment branch or JMP whose source M-column does
not match the target's M-column.  A mismatch means either Merlin's
deduced MX at the target is wrong, or the programmer forgot to put an
explicit MX directive there.

Usage:  tools/check_mx.py build/fgx_S01_KernelMain_Output.txt [...]
Exits non-zero on any mismatch; prints each as a filename:line message.

IT READS ALL FOUR BANKS, and for two of them that is new (2026-09-01).  It ran
on the core kernel and the block driver only, so the FAR bank and the TTY bank
-- which between them hold the console engine, the line discipline and every
routine kernel C calls -- were assembled by the same MX-tracking assembler with
nothing watching.  Both new listings are CLEAN as of the day they were wired
in, so this bought no cleanup; it bought a gate.  The self-test now parses all
four and prints each one's record and label counts, because "it parsed the core
kernel" was never a statement about the other three.

TWO THINGS IT DOES NOT CATCH, stated here rather than left to be discovered.

(1) A LINEAR WIDTH CHANGE WITH NO BRANCH IN IT.  Deleting the 320-pixel console
mode removed a `SEP #$20 / MX %10' pair the code after it was inheriting, so an
`STZ' wrote two bytes and the machine booted to a blank screen.  This gate
would NOT have found it and cannot: Merlin's deduced state and the runtime
state AGREED after the deletion -- both 16-bit -- and what was wrong was the
programmer's intent, not the tracking.  This checker compares Merlin's view
against the runtime's; when they agree there is nothing here to see.

(2) A STALE MODE THAT PROPAGATES THROUGH A BRA.  MEASURED 2026-09-01 by
deleting the `REP #$20' at `@hc_doneSep' in Con_HideCursor (console_char.s), a
real stack-desync bug -- the routine pushes A/X/Y 16-bit and `@hc_done' would
then pull them 8-bit -- and this gate stayed GREEN on the far bank.  Why: the
BEQ reaches `@hc_doneSep' at runtime M=10 while Merlin's LINEAR state there is
M=00 (it flowed in past an RTS), and the very next instruction is `BRA
@hc_done'.  The stale arm at `@hc_doneSep' is suppressed by the imm_only
relaxation (a BRA encodes identically in both widths), and at `@hc_done' the
BRA's listing column reads 00 -- Merlin's stale state, not the runtime's -- so
the path-dependent arm sees every entry agreeing.  Following the BRA one hop
was tried and measured: it adds NO findings on any of the four banks and does
not catch this either, because the miss is not in the forward walk but in the
entry set, which carries assembled columns rather than propagated runtime
modes.  Closing it needs a real CFG pass over the mode, which is its own piece
of work and is not smuggled in here.

TWO LOCAL SHAPES IT DOES CATCH, each on one line of the listing:

(3) AN MX DIRECTIVE THAT CONTRADICTS THE SEP/REP BEFORE IT (apple/fgx#444).
Merlin applies a SEP or REP to its own state, so a following `MX' that names
the other width for a bit that instruction just set is always wrong: every
immediate after it is encoded for a width the CPU is not in.  `SEP #$20 /
MX %01 / LDX #0' assembles a one-byte operand for a sixteen-bit X, which killed
the ALTZP boot probe.

(4) AN 8-BIT LOAD FEEDING A 16-BIT TRANSFER (apple/fgx#465).  With M=1 and
X=0, `LDA mem' sets only the low byte of A; TAX, TAY, TCD and TCS move all of
B:A because the INDEX flag, not M, governs them.  The index then carries
whatever B held -- #463's wild store three subsystems from its cause.  A site
that wants that on purpose says `MX-B-OK:' on the transfer line and why.
"""

import glob
import os
import re
import sys
from collections import defaultdict

BRANCH_MNEMONICS = {"BEQ", "BNE", "BCC", "BCS", "BMI", "BPL", "BVC", "BVS",
                    "BRA", "JMP"}

LINE_RE = re.compile(
    r"^\s*\d+\s*\|\s*\d+\s+(?P<file>\S+)\s+(?P<srcline>\d+)\s*\|"
    r"\s*(?P<type>\S+)\s*\|\s*(?P<m>\S*)\s*\|\s*(?P<x>\S*)\s*\|"
    r"\s*(?P<size>\d+)\s*\|\s*(?P<rest>.*)$"
)
ADDR_RE = re.compile(r"^\s*([0-9A-Fa-f]{2})/([0-9A-Fa-f]{4})\s*(?::|$)")
LABEL_RE = re.compile(r"^(@?[A-Za-z_][\w]*)\b")
INSN_RE = re.compile(
    r"^(?:(@?[A-Za-z_][\w]*)\s+)?([A-Z]{2,4})\s+([@A-Za-z_][\w]*)")

def parse_listing(path):
    """Return list of line records (dicts) and a label→(addr, m, srcfile, srcline) map."""
    records = []
    label_map = {}
    current_global = None  # tracks most recent global label for @local scoping
    with open(path, encoding="latin-1") as f:
        for raw in f:
            m = LINE_RE.match(raw)
            if not m:
                continue
            src_text = m.group("rest")
            # Peel off "addr : bytes | source" split.
            # The listing used " | " as separator; we split on " |" once.
            # rest looks like:  "02/5FED : AF A9 9A 02 |                                       LDAL   ..."
            if " |" in src_text:
                addr_bytes, _, asm_raw = src_text.partition(" |")
            else:
                addr_bytes, asm_raw = src_text, ""
            addr_bytes = addr_bytes.strip()
            # The listing separator is " |" with a trailing space before the
            # asm column proper.  Strip that single separator space so a
            # label that starts in column 1 of the source lands at position 0.
            if asm_raw.startswith(" "):
                asm_raw = asm_raw[1:]
            asm_lead = asm_raw.rstrip()     # keep leading whitespace for label detect
            asm = asm_lead.strip()
            addr_match = ADDR_RE.match(addr_bytes)
            addr = None
            if addr_match:
                bank = int(addr_match.group(1), 16)
                offset = int(addr_match.group(2), 16)
                addr = (bank << 16) | offset

            # Detect label: Merlin32 labels sit in column 1 of the asm column
            # (no leading whitespace).  Mnemonics like "STAL", "LDAL" etc. are
            # always indented — skipping them requires this exact check,
            # otherwise "STAL foo,X" parses as a label named "STAL".
            label = None
            if asm_lead and asm_lead[0] not in (" ", "\t"):
                lbl_match = LABEL_RE.match(asm_lead)
                if lbl_match:
                    candidate = lbl_match.group(1)
                    after = asm_lead[len(candidate):]
                    if after == "" or after[0] in (" ", "\t"):
                        if m.group("type") in ("Empty", "Code", "Data", "Equivalence"):
                            label = candidate

            record = {
                "file": m.group("file"),
                "srcline": int(m.group("srcline")),
                "type": m.group("type"),
                "m": m.group("m"),
                "addr": addr,
                "asm": asm,
                "label": label,
            }
            records.append(record)

            if label:
                if label.startswith("@"):
                    key = (current_global, label)
                else:
                    current_global = label
                    key = (None, label)
                if addr is not None and key not in label_map:
                    label_map[key] = record
    return records, label_map


def classify_branch(asm):
    """Return (mnemonic, target_label) if this is an intra-segment branch/JMP."""
    m = INSN_RE.match(asm)
    if not m:
        return None
    mnem = m.group(2).upper()
    if mnem not in BRANCH_MNEMONICS:
        return None
    target = m.group(3)
    return mnem, target


def first_code_after(records, idx):
    """Return first Code record at or after records[idx], or None."""
    for j in range(idx, len(records)):
        if records[j]["type"] == "Code":
            return records[j]
    return None


def target_realigned_before_risk(records, tgt_idx, src_m, imm_only=False):
    """Walk forward from tgt_idx; return True if the runtime MX gets realigned
    (via SEP/REP) before any instruction whose operand width depends on M.

    imm_only=True is the STALE-UNIFORM relaxation: when every live entry
    agrees on the runtime mode and only Merlin's dead linear state differs,
    non-immediate ops are encoded identically in both widths and execute in
    the (uniform) runtime mode — only immediates are mis-ENCODED.  For the
    PATH-DEPENDENT class (imm_only=False) semantic width matters too: a
    16-bit CMP/STA of an 8-bit cell touches the neighbor byte and PHA/PLA
    desync the stack by a byte."""
    for j in range(tgt_idx, min(tgt_idx + 20, len(records))):
        rec = records[j]
        if rec["type"] != "Code":
            continue
        asm_upper = rec["asm"].upper()
        # Strip leading label on same line.
        parts = asm_upper.split()
        if not parts:
            continue
        # Find mnemonic position: skip a leading label-looking token.
        mnem_idx = 0
        if parts[0][0] in "@_" or (parts[0][0].isalpha() and parts[0][0].islower()):
            mnem_idx = 1
        if mnem_idx >= len(parts):
            continue
        mnem = parts[mnem_idx]
        # SEP / REP that touches the M bit (#$20 or #$30) realigns.
        if mnem in ("SEP", "REP") and mnem_idx + 1 < len(parts):
            oper = parts[mnem_idx + 1]
            if "20" in oper or "30" in oper:
                return True
        # MX directive changes Merlin's view but not runtime — not a realignment.
        if mnem == "MX":
            continue
        # PLP restores a saved P — treat as realignment (the saver is
        # responsible for the width it saved).
        if mnem == "PLP":
            return True
        # Any M-width-dependent instruction after a mismatch is a real
        # risk — NOT just immediates.  A 16-bit LDA/CMP/STA of an
        # absolute/DP operand reads or writes the NEIGHBOR byte too
        # (the Bm_Sync guard bug 2026-07-17: CMP _bm_dirty_hi executed
        # in M=16 read DP $67+$68, picking up _kHeapCur's low byte as
        # the comparand high byte), and PHA/PLA desync the stack by a
        # byte.  LDX/LDY/CPX/CPY depend on X-width (untracked here) —
        # skip them.
        if mnem in ("LDA", "CMP", "AND", "ORA", "EOR", "BIT", "ADC", "SBC") \
           and mnem_idx + 1 < len(parts) and parts[mnem_idx + 1].startswith("#"):
            return False
        if not imm_only and mnem in ("LDA", "STA", "CMP", "AND", "ORA", "EOR",
                                     "BIT", "ADC", "SBC", "INC", "DEC", "STZ",
                                     "ASL", "LSR", "ROL", "ROR", "TRB", "TSB",
                                     "PHA", "PLA"):
            return False
        # Unconditional transfer: callee is responsible for its own MX.
        if mnem in ("JSR", "JSL", "JMP", "JML", "RTS", "RTL", "BRA"):
            return True
    # Reached search horizon without a verdict; treat as possibly-benign
    # rather than spam.
    return True


EXIT_MNEMONICS = {"RTS", "RTL", "RTI", "JMP", "JML", "BRA"}
MNEM_RE = re.compile(r"^(?:@?[A-Za-z_][\w]*\s+)?([A-Z]{2,4})\b")


def mnemonic_of(asm):
    m = MNEM_RE.match(asm)
    return m.group(1).upper() if m else None


def prev_code(records, idx):
    for j in range(idx - 1, -1, -1):
        if records[j]["type"] == "Code":
            return records[j]
    return None


def _selftest():
    """Guard the ways this gate can go VACUOUS.

    SCOPE, stated honestly: this does NOT validate the live-entry-mode analysis
    itself -- constructing a synthetic MX leak risks encoding my misreading of
    the algorithm rather than testing it.  What it does test is every way the
    gate can silently stop looking, which is the failure that matters: if
    parse_listing returns nothing, or the regexes stop matching Merlin's
    format, check_mx reports "clean" on a kernel it never examined.

    The analysis itself is covered by the real listings it runs against, and by
    the defect it caught in process.s @afa_errExit (2026-07-17).
    """
    fails = 0

    # (1) LINE_RE must match a REAL Merlin listing row.  This is the whole
    #     gate's input contract; a Merlin format change silently empties it.
    real = ("    428 |  3                 ../../include/hardware.s    378 | "
            "Equivalence | 00 |         |    0 | 02/0B00               | "
            "HW_BRAM                               EQU              $C033")
    if not LINE_RE.match(real):
        print("  SELFTEST FAIL: LINE_RE no longer matches a real listing row")
        fails += 1

    # (2) Branch classification must recognise the 65816 branch set.
    for asm, want in (("BEQ @loop", True), ("BNE @x", True), ("BRA @y", True),
                      ("BCC @z", True), ("BPL @w", True),
                      ("LDA #$10", False), ("NOP", False)):
        got = bool(classify_branch(asm))
        if got != want:
            print(f"  SELFTEST FAIL: classify_branch({asm!r}) -> {got}, want {want}")
            fails += 1

    # (3) EVERY listing the gate is pointed at must parse to a NON-EMPTY record
    #     set, and that means every BANK -- not the first one the glob happens
    #     to return.  Zero records is exactly what a clean run looks like from
    #     the outside, so a bank whose listing this parser cannot read would be
    #     reported as having no MX leaks rather than as unexamined.  The far and
    #     tty banks were added to the gate on 2026-09-01 and are the reason this
    #     stopped being a one-file check: they are assembled separately, and
    #     "it parsed the core kernel" says nothing about them.
    build = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build")
    wanted = sorted(glob.glob(os.path.join(build, "fgx_S*_Output.txt"))) + [
        os.path.join(build, "fgxfar_Output.txt"),
        os.path.join(build, "fgxtty_Output.txt")]
    seen = 0
    for lst in wanted:
        if not os.path.exists(lst):
            print(f"  SELFTEST NOTE: no {os.path.basename(lst)} -- run `ninja "
                  f"all` to exercise the parse-non-empty check on that bank")
            continue
        seen += 1
        recs, labels = parse_listing(lst)
        if len(recs) < 100:
            print(f"  SELFTEST FAIL: {lst} parsed to only {len(recs)} records "
                  f"-- the gate would inspect nothing")
            fails += 1
        if not labels:
            print(f"  SELFTEST FAIL: no labels parsed from "
                  f"{os.path.basename(lst)} -- no branch targets to check")
            fails += 1
        print(f"  (parsed {len(recs)} records, {len(labels)} labels from "
              f"{os.path.basename(lst)})")
    if seen == 0:
        print("  SELFTEST NOTE: no listings at all -- the parse-non-empty check "
              "did NOT run")

    # (4) THE MUTATION, and it is the arm that says this can still go RED.
    #     A synthetic listing in Merlin's own column format: `@t' is reached by
    #     a BRA from M=00 and by fall-through from M=10, and the first thing it
    #     does is a width-dependent PLA.  That is the shape a deleted `SEP #$20
    #     / MX %10' pair leaves behind -- one path stops restoring the width the
    #     other path assumes -- and it is the shape the 320-mode removal had.
    #     A parser or analysis change that stops seeing it fails here rather
    #     than reporting a clean bank.
    def row(n, ty, mcol, addr, asm):
        return (f"    {n} |  9                     synth.s    {n} | {ty} | "
                f"{mcol} |         |    0 | {addr}               | {asm}")
    synth = "\n".join([
        row(1, "Code", "00", "08/C000", "@src            BRA               @t"),
        row(2, "Code", "10", "08/C002", "                SEP               #$20"),
        row(3, "Code", "10", "08/C004", "                LDA               #$01"),
        row(4, "Code", "10", "08/C006", "@t              PLA"),
        row(5, "Code", "10", "08/C007", "                RTS"),
    ]) + "\n"
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
        f.write(synth)
        synth_path = f.name
    import contextlib
    import io
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = main([synth_path])
    os.unlink(synth_path)
    if rc == 0 or "PATH-DEPENDENT" not in buf.getvalue():
        print("  SELFTEST FAIL: the path-dependent mutation was NOT caught "
              f"(rc={rc}) -- this gate can no longer go red")
        fails += 1

    # (5) THE TWO LOCAL SHAPES, each red, and the allowlisted transfer green.
    def run_synth(lines_):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.write("\n".join(lines_) + "\n")
            p = f.name
        b = io.StringIO()
        with contextlib.redirect_stdout(b):
            r = main([p])
        os.unlink(p)
        return r, b.getvalue()
    rc, out = run_synth([
        row(1, "Code", "10", "08/D000", "                SEP               #$20"),
        row(2, "Directive", "01", "08/D002", "                MX                %01"),
        row(3, "Code", "01", "08/D002", "                LDX               #0"),
        row(4, "Code", "01", "08/D004", "                RTS")])
    if rc == 0 or "#444" not in out:
        print("  SELFTEST FAIL: an MX contradicting its SEP was NOT caught")
        fails += 1
    narrow = [
        row(1, "Code", "10", "08/E000", "                LDA               _cell"),
        row(2, "Code", "10", "08/E003", "                CLC"),
        row(3, "Code", "10", "08/E004", "                TAY")]
    rc, out = run_synth(narrow)
    if rc == 0 or "#465" not in out:
        print("  SELFTEST FAIL: an 8-bit load into a 16-bit TAY was NOT caught")
        fails += 1
    narrow[2] = row(3, "Code", "10", "08/E004",
                    "                TAY               ; MX-B-OK: B is zero here")
    rc, out = run_synth(narrow)
    if rc != 0:
        print("  SELFTEST FAIL: an MX-B-OK transfer was reported")
        fails += 1

    if fails:
        print(f"check_mx self-test: {fails} FAILURE(S)")
        return 1
    print("check_mx self-test: OK")
    return 0


WIDTH_OPS = {"SEP", "REP"}
# Anything after which the 8-bit load no longer decides B:A, or after which the
# linear successor is not the only way to reach the next line.
NARROW_STOP = {"SEP", "REP", "PLP", "XCE", "XBA", "RTS", "RTL", "RTI", "JMP",
               "JML", "BRA", "BRL", "PLA", "TXA", "TYA", "TDC", "TSC"}
MNEM_ARG_RE = re.compile(r"^(?:@?[A-Za-z_][\w]*\s+)?([A-Z]{2,4})\b\s*(\S*)")


def _mnem_arg(asm):
    m = MNEM_ARG_RE.match(asm)
    return (m.group(1), m.group(2)) if m else (None, "")


def contradicting_directives(records):
    """(3): [(directive_rec, sep_rep_rec, bit)] where an MX directive names
    the other width for a bit the SEP/REP before it just set.  The walk back
    stops at a label (another entry), an exit or a PLP/XCE (a width Merlin
    cannot see), so only the fall-through that SEP/REP decided is judged."""
    out = []
    for i, rec in enumerate(records):
        if rec["type"] != "Directive":
            continue
        mm = re.match(r"^MX\s+%([01])([01])", rec["asm"])
        if not mm:
            continue
        for j in range(i - 1, -1, -1):
            prev = records[j]
            if prev["label"]:
                break
            if prev["type"] != "Code":
                continue
            op, arg = _mnem_arg(prev["asm"])
            if op in WIDTH_OPS:
                if not arg.startswith("#"):
                    break
                try:
                    val = int(arg[1:].replace("$", "0x"), 0)
                except ValueError:
                    break
                want = "1" if op == "SEP" else "0"
                if val & 0x20 and mm.group(1) != want:
                    out.append((rec, prev, "M"))
                if val & 0x10 and mm.group(2) != want:
                    out.append((rec, prev, "X"))
                break
            if op in ("PLP", "XCE", "RTI") or op in EXIT_MNEMONICS:
                break
    return out


def narrow_load_transfers(records):
    """(4): [(load_rec, transfer_rec)] where an 8-bit memory LDA (M=1, X=0)
    reaches TAX/TAY/TCD/TCS with no reload, width change or label between."""
    out = []
    for i, rec in enumerate(records):
        if rec["type"] != "Code" or rec["m"] != "10":
            continue
        op, arg = _mnem_arg(rec["asm"])
        if op not in ("LDA", "LDAL") or arg.startswith("#"):
            continue
        for j in range(i + 1, len(records)):
            nxt = records[j]
            if nxt["label"]:
                break
            if nxt["type"] != "Code":
                continue
            op2, _ = _mnem_arg(nxt["asm"])
            if op2 in ("TAX", "TAY", "TCD", "TCS"):
                if nxt["m"].endswith("0") and "MX-B-OK" not in nxt["asm"]:
                    out.append((rec, nxt))
                break
            if op2 in NARROW_STOP or (op2 or "").startswith("LDA"):
                break
    return out


def main(paths):
    if "--self-test" in paths:
        return _selftest()

    """Per-label live-entry-mode analysis.

    Merlin deduces MX by LINEAR source scan, so its state at a label can be
    dead (flowed out of an early-exit path's REP/SEP) while every LIVE entry
    arrives in a different mode.  For each branch-target label we collect the
    modes of all live entries (branch sources + fall-through unless the
    linear predecessor is an unconditional exit) and flag:

      (a) path-dependent mode: two live entries disagree — the Bm_Sync
          @bs_iL bug class (2026-07-17): one path's 16-bit CMP of an 8-bit
          DP cell read the neighbor byte and unbounded the loop;
      (b) stale encoding: all live entries agree but differ from Merlin's
          deduced (= assembled) state — immediates/width-ops at the label
          were ENCODED for a mode the code never runs in.

    Either is suppressed when the target realigns (SEP/REP on M, or PLP)
    before any M-width-dependent instruction.
    """
    any_issue = False
    for path in paths:
        records, label_map = parse_listing(path)
        for rec, why, bit in contradicting_directives(records):
            any_issue = True
            print(f"{rec['file']}:{rec['srcline']}: {rec['asm'].split(';')[0].strip()} "
                  f"contradicts `{why['asm'].split(';')[0].strip()}' on {bit} "
                  f"(apple/fgx#444): immediates after it are encoded for the "
                  f"wrong width")
        for load, xfer in narrow_load_transfers(records):
            any_issue = True
            print(f"{xfer['file']}:{xfer['srcline']}: "
                  f"{xfer['asm'].split(';')[0].strip()} moves B:A after the "
                  f"8-bit load at {load['file']}:{load['srcline']} -- the high "
                  f"byte is stale B (apple/fgx#465); load 16-bit, or say "
                  f"MX-B-OK: and why")
        idx_by_addr_file = {}
        for i, rec in enumerate(records):
            if rec["addr"] is not None:
                idx_by_addr_file.setdefault((rec["file"], rec["addr"]), i)
        entries = defaultdict(list)
        current_global = None
        for i, rec in enumerate(records):
            if rec["label"] and not rec["label"].startswith("@"):
                current_global = rec["label"]
            if rec["type"] != "Code":
                continue
            br = classify_branch(rec["asm"])
            if not br:
                continue
            mnem, target = br
            key = (current_global, target) if target.startswith("@") \
                else (None, target)
            entries[key].append((rec, mnem))
        for key, srcs in entries.items():
            tgt_rec = label_map.get(key)
            if not tgt_rec:
                continue
            tgt_idx = idx_by_addr_file.get((tgt_rec["file"], tgt_rec["addr"]))
            if tgt_idx is None:
                continue
            live = {r["m"] for r, _ in srcs if r["m"]}
            pc = prev_code(records, tgt_idx)
            if pc is not None and pc["m"] and \
               mnemonic_of(pc["asm"]) not in EXIT_MNEMONICS:
                live.add(pc["m"])
            if not live:
                continue
            if len(live) > 1:
                if target_realigned_before_risk(records, tgt_idx, None):
                    continue
                any_issue = True
                who = ", ".join(f"{r['file']}:{r['srcline']} {m} (M={r['m']})"
                                for r, m in srcs)
                print(f"{tgt_rec['file']}:{tgt_rec['srcline']}: label "
                      f"{key[1]} reached with PATH-DEPENDENT M "
                      f"({'/'.join(sorted(live))}) and no realignment before "
                      f"a width-dependent insn; entries: {who}")
                continue
            runtime_m = next(iter(live))
            if tgt_rec["m"] and runtime_m != tgt_rec["m"]:
                if target_realigned_before_risk(records, tgt_idx, runtime_m,
                                                imm_only=True):
                    continue
                any_issue = True
                print(f"{tgt_rec['file']}:{tgt_rec['srcline']}: label "
                      f"{key[1]} assembled with M={tgt_rec['m']} but every "
                      f"live entry arrives M={runtime_m} — stale linear "
                      f"state; add an explicit MX at the label")
    return 1 if any_issue else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
