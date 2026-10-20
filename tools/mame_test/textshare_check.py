#!/usr/bin/env python3
"""textshare_check -- two spawned sleeps share one code bank; the shell's differs.

Reads the pids the script printed (`TS A=<a> B=<b>`, `TS SH=<s>`) from the
console CharBuf (the `charbuf' region run.py dumps, 80-byte rows) and
TCB_CodeBank (+20) for each from the task table (64-byte slots, pid =
slot + 1).  Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import binascii
import json
import pathlib
import re
import sys

TCB = 64
CODEBANK = 20


def screen_text(d):
    cb = d.get("memory", {}).get("charbuf")
    if not cb or not cb.get("hex"):
        return ""
    raw = bytes(b & 0x7F for b in binascii.unhexlify(cb["hex"]))
    text = raw.decode("ascii", "replace")
    return "\n".join(text[i:i + 80].rstrip() for i in range(0, len(text), 80))


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    r = d.get("memory", {}).get("tcbs")
    text = screen_text(d)
    a = re.search(r"TS A=(\d+) B=(\d+)", text)
    s = re.search(r"TS SH=(\d+)", text)
    if not r or not r.get("hex") or not a or not s:
        print("textshare: no task table or no pids on the screen")
        return 2
    t = binascii.unhexlify(r["hex"])

    def bank(pid):
        o = (pid - 1) * TCB
        if t[o] | (t[o + 1] << 8) != pid:
            return 0
        return t[o + CODEBANK]

    pa, pb, ps = int(a.group(1)), int(a.group(2)), int(s.group(1))
    ba, bb, bs = bank(pa), bank(pb), bank(ps)
    print(f"textshare: sleep {pa} ${ba:02X}, sleep {pb} ${bb:02X}, sh {ps} ${bs:02X}")
    if ba == 0 or bb == 0 or bs == 0:
        print("textshare: a pid has no task slot or no code bank -- not running?")
        return 2
    if ba != bb:
        print("textshare: FAIL -- the two sleeps have different code banks")
        return 1
    if ba == bs:
        print("textshare: FAIL -- sh shares sleep's code bank (control)")
        return 1
    print("textshare: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
