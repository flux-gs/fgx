#!/usr/bin/env python3
"""lcstacks_check -- are the per-pid kernel stacks REALLY in the language card?

A green suite is consistent with the stacks never having moved: if a config
change silently failed to take, every test would still pass and the 3 KB of low
bank 0 would still be occupied.  So this asserts the claim rather than a proxy.

THE DISCRIMINATOR IS THE CANARY.  main.s paints every kernel-image slot stack
with STK_PAINT and seeds $C5C5 in its bottom word, so a slot base carrying that
pattern is a real, initialised kernel stack and nothing else in bank 0 looks
like one.  The fill beside it is not part of this check -- kstkhwm_check.py is
what reads the paint.  The check counts canaries in BOTH the new home (at the
slot stride the config gives) and the vacated region (at every page, where a
per-pid slice's canary would sit):

  - at least one in the language card, or the stacks are not there;
  - ZERO in $0C00, or they never left -- which is the failure a passing suite
    would otherwise hide.

The vacated region is NOT asserted to be empty.  It holds stage-2 boot residue
(the boot config file, a path buffer, the module directory listing) because
nothing zeroes it once no task is allocated there, and demanding zeros would
fail for a reason that has nothing to do with where the stacks live.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import json
import sys

from kequ import equ

CANARY = 0xC5C5


def canaries(blob, stride=256):
    b = bytes.fromhex(blob)
    return sum(1 for p in range(len(b) // stride)
               if (b[p * stride] | (b[p * stride + 1] << 8)) == CANARY)


def main():
    if len(sys.argv) < 2:
        print("lcstacks: no dump path given")
        return 2
    try:
        d = json.load(open(sys.argv[1]))
    except Exception as e:                                   # noqa: BLE001
        print(f"lcstacks: cannot read dump: {e}")
        return 2

    mem = d.get("memory", {})
    new, old = mem.get("kern_stacks"), mem.get("old_kstk")
    if not new or not old:
        print("lcstacks: INCONCLUSIVE -- the dump lacks kern_stacks and/or "
              "old_kstk; without both regions this proves nothing")
        return 2

    n_new = canaries(new["hex"], equ("FGX_KSLOT_STK"))
    n_old = canaries(old["hex"])
    bad = []
    if n_new < 1:
        bad.append(f"no kernel-stack canary at ${new['addr']:04X}: the stacks "
                   f"are NOT in the language card")
    if n_old:
        bad.append(f"{n_old} kernel-stack canaries still at ${old['addr']:04X}: "
                   f"the stacks never left the low region, and the 3 KB they "
                   f"were supposed to free is still occupied")
    if bad:
        print("lcstacks: FAIL")
        for b in bad:
            print(f"    {b}")
        return 1

    print(f"lcstacks: PASS -- {n_new} live kernel stacks in language-card RAM "
          f"at ${new['addr']:04X}, and none left at ${old['addr']:04X}; the low "
          f"region is genuinely vacated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
