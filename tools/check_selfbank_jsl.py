#!/usr/bin/env python3
"""check_selfbank_jsl -- a JSL or JML must never name its own bank.

WHY THIS EXISTS (2026-09-11).  Merlin32 bakes the ORG bank into a long operand,
and every statically linked bank in FGX runs somewhere else: the core kernel
assembles at $02 and is loaded at whatever bank the boot program allocated.  A
cross-bank call therefore has a patch table behind it -- far_patchsites.s,
tty_patchsites.s, the wavee table -- and a SAME-bank call has none, because it
is not supposed to exist: the same-bank forms are JSR and JMP, and an RTL
routine in one's own bank is reached by a pile call (PHK + PEA, which takes the
LIVE bank from the program counter).  include/kernelc.s says so at KTTY_STUB2.

WHAT IT COST.  src/drivers/block/rawdisk.s reached _FarSh_Uiomove -- a routine
in its own bank -- with `JSL _FarSh_Uiomove'.  It assembled to `22 1D BD 02'
and jumped into bank $02, which at run time is a user heap.  The read did not
fault and did not return: the machine went idle in the scheduler with the
calling process gone, and the only visible symptom was fsck(8) stopping after
its banner.  check_far_rtl_calls.py could not see it -- that checker looks for
the opposite mistake, a JSR into an RTL routine -- and nothing else looked at
the emitted bank byte at all.

WHY CONTROL TRANSFERS ONLY.  A self-bank LDAL or STAL is the same mistake, but
the core kernel has forty of them on purpose: the wavee sites, `_weNNN', whose
bank bytes gen_wavee_bankpatch.py rewrites at boot.  That table is the thing
that makes them legitimate, and it covers no JSL.  Restricting this check to
$22 and $5C keeps it free of exemptions, and a control transfer is where the
failure is silent.

Usage:
  check_selfbank_jsl.py                # every bank in LISTINGS
  check_selfbank_jsl.py --self-test
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# EVERY STATICALLY LINKED BANK AND THE BANK IT ASSEMBLES AT.  The two kernel
# segments share an ORG bank because they share a bank; adding a bank is a row.
LISTINGS = (("core",  "build/fgx_S01_KernelMain_Output.txt", 0x02),
            ("block", "build/fgx_S02_BlockDriver_Output.txt", 0x02),
            ("far",   "build/fgxfar_Output.txt",              0x08),
            ("tty",   "build/fgxtty_Output.txt",              0x09))

LONG_JUMP = {0x22: "JSL", 0x5C: "JML"}

# `02/362A : 22 1D BD 02 | _rsdcall   JSL   _FarSh_Uiomove'
_ROW = re.compile(r"([0-9A-F]{2})/([0-9A-F]{4}) : "
                  r"([0-9A-F]{2}) ([0-9A-F]{2}) ([0-9A-F]{2}) ([0-9A-F]{2}) \|(.*)")


def violations(text, org):
    """[(addr, mnemonic, target, source-text)] for self-bank long jumps."""
    out = []
    for line in text.splitlines():
        m = _ROW.search(line)
        if not m:
            continue
        bank, addr, op, lo, hi, opbank, src = m.groups()
        if int(bank, 16) != org:
            continue                    # DUM/data section, not emitted code
        opcode = int(op, 16)
        if opcode not in LONG_JUMP:
            continue
        if int(opbank, 16) != org:
            continue
        out.append((addr, LONG_JUMP[opcode],
                    "$%s%s%s" % (opbank, hi, lo), src.strip()))
    return out


def self_test():
    bad = violations(
        "  | 02/362A : 22 1D BD 02 | _rsdcall  JSL  _FarSh_Uiomove\n", 0x02)
    assert len(bad) == 1, bad
    assert bad[0][1] == "JSL" and bad[0][2] == "$02BD1D", bad
    # A cross-bank JSL through a bank-zero gateway cell is the correct form.
    assert violations("  | 02/0B00 : 22 90 03 00 | JSL $000390\n", 0x02) == []
    # So is a call into the far bank, whose bank byte the patch table rewrites.
    assert violations("  | 02/0B00 : 22 00 00 08 | JSL KFAR_SLOT0\n", 0x02) == []
    # A row from another bank's DUM section must not be read as emitted code.
    assert violations("  | 00/1234 : 22 1D BD 02 | ...\n", 0x02) == []
    print("check_selfbank_jsl: self-test OK")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    rc = 0
    checked = 0
    for name, rel, org in LISTINGS:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            print("check_selfbank_jsl: %s listing missing: %s" % (name, rel),
                  file=sys.stderr)
            return 1
        with open(path, errors="replace") as fh:
            bad = violations(fh.read(), org)
        checked += 1
        for addr, mnem, target, src in bad:
            print("check_selfbank_jsl: %s bank %02X/%s: %s %s names its OWN "
                  "bank -- use JSR/JMP, or a pile call (PHK + PEA) for an RTL "
                  "target\n    %s" % (name, org, addr, mnem, target, src),
                  file=sys.stderr)
            rc = 1
    if rc == 0:
        print("check_selfbank_jsl: clean (%d bank listing(s); no long jump "
              "names its own bank)" % checked)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
