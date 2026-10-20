#!/usr/bin/env python3
"""trapquiet_check -- no fcc stack-overflow trap fired, and it can say so.

apple/fgx#261.  The traps in src/kernel/far/fcc_ktrap.s stopped the machine with
a border colour and a spin.  A colour is not readable from a dump, so a wedged
harness run reported a TIMEOUT and nothing else -- which is why apple/fgx#194
and apple/fgx#225 each cost a long bisect, #225 worst, because the guard fired
on a FICTIONAL floor with a healthy stack and looked like a layout lottery.

The traps now record four words at KFGX_TRAP_MAGIC ($0310) before spinning, and
main.s zeroes them before the first guarded prologue can fire.  So:

    magic $0000  no trap fired this boot
    magic $C5D0  _fcc_stkoflow -- hardware stack
    magic $C5D1  _fcc_sfoflow  -- soft frame

THE ZERO IS WHAT MAKES THE REPORT MEAN ANYTHING.  Without it these are whatever
the last run left, and a reader is told a trap fired whenever the bytes happen
to look right -- the failure mode the report exists to end, one level up.

READING THE OTHER THREE IS THE POINT.  A floor of $0000 against any S is the
inert guard include/kernel.s:632 describes and the overflow is real; a floor
wildly above S -- $FFA9 against $F9BD, say -- is #225 on sight, a fictional
floor over a healthy stack, and the stack is not the problem at all.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import json
import pathlib
import sys

MAGICS = {0xC5D0: "_fcc_stkoflow (kernel-C HARDWARE stack)",
          0xC5D1: "_fcc_sfoflow (kernel-C SOFT frame)"}


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    r = (d.get("memory") or {}).get("trap")
    if not r or not r.get("hex"):
        print("trapquiet: INCONCLUSIVE -- no `trap' region in the dump, so the "
              "cells were not read.  A missing instrument is not a quiet one.")
        return 2
    b = bytes.fromhex(r["hex"])
    if len(b) < 8:
        print(f"trapquiet: INCONCLUSIVE -- region is {len(b)} bytes, need 8")
        return 2
    w = lambda i: b[i] | (b[i + 1] << 8)
    magic, dp, sp, floor = w(0), w(2), w(4), w(6)
    if magic == 0:
        print(f"trapquiet: PASS -- magic $0000 at ${r['addr']:06X}, no trap fired")
        return 0
    who = MAGICS.get(magic)
    if who is None:
        print(f"trapquiet: FAIL -- magic ${magic:04X} is not zero and not a "
              f"known trap.  Either a trap gained a magic this checker does not "
              f"know, or something else now writes ${r['addr']:06X} -- which has "
              f"happened twice in this window already (see include/memmap.s).")
        return 1
    print(f"trapquiet: FAIL -- {who} FIRED.")
    print(f"  D=${dp:04X}  S=${sp:04X}  floor=${floor:04X}")
    if floor == 0:
        print("  floor $0000: the guard was INERT and this is a real overflow "
              "(include/kernel.s:632).")
    elif floor > sp and (floor - sp) > 0x0400:
        print(f"  floor ${floor:04X} sits far ABOVE S ${sp:04X}: that is a "
              f"FICTIONAL floor over a healthy stack -- apple/fgx#225's shape, "
              f"a cell read before it was written.  The stack is not the fault.")
    else:
        print("  floor is plausible against S: treat as a genuine overflow and "
              "look at the depth of the chain that reached it.")
    return 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
