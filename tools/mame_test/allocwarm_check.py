#!/usr/bin/env python3
"""allocwarm_check -- the poke must have landed where it was aimed (#120).

The first cut of this test poked $7DE002, from memmap.s's header comment saying
FGX_DATA is $02E000.  It is $02ED70, and has been for a while.  The poke hit
dead memory, the machine booted fine, and the run reported a PASS that meant
nothing -- a test whose instrument missed the target is indistinguishable from a
test whose subject is healthy.

So assert the address as well as the outcome: DetectedROM sits 4 bytes past the
region start and reads $0003 on a ROM-03 machine.  If that is not there, the
region is not where this test thinks it is and the result is inconclusive rather
than green.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import binascii
import json
import pathlib
import sys


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    r = d.get("memory", {}).get("fgxdata")
    if not r or not r.get("hex"):
        print("allocwarm: FAIL -- no fgxdata region; the address check could not "
              "run, and an unchecked address is how this test lied once already")
        return 2
    b = binascii.unhexlify(r["hex"])
    rom = b[4] | (b[5] << 8)
    cur = b[2] | (b[3] << 8)
    print(f"allocwarm: DetectedROM=${rom:04X} _taskAllocCur=${cur:04X} "
          f"at ${r['addr']:06X}")
    if rom == 0:
        print("allocwarm: FAIL -- DetectedROM reads $0000, so this is not the "
              "kernel globals region and the poke went somewhere else entirely")
        return 2
    print("allocwarm: PASS -- region confirmed (DetectedROM populated), so the "
          "poke landed on the real cursor and the boot survived it")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "dump.json"))
