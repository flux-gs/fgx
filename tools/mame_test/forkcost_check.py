#!/usr/bin/env python3
"""forkcost_check -- `/bin/true` at the prompt costs exactly 2 image copies.

_kImgCopies is zeroed at the paste frame; the dump is read after the command.
A poke that missed leaves the boot's own count (dozens), which reads as FAIL.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import binascii
import json
import pathlib
import sys


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    r = d.get("memory", {}).get("kimg")
    if not r or not r.get("hex"):
        print("forkcost: no kimg region in the dump")
        return 2
    b = binascii.unhexlify(r["hex"])
    n = b[0] | (b[1] << 8)
    print(f"forkcost: _kImgCopies = {n}")
    if n == 2:
        print("forkcost: PASS")
        return 0
    print("forkcost: FAIL -- expected 2")
    return 1


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
