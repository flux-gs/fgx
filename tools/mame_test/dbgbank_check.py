#!/usr/bin/env python3
"""dbgbank_check -- a FRAME-SAMPLED region resolves the bank it named.

apple/fgx#236.  The fgxdebug plugin had two copies of the bank resolution: one
in the end-of-run dump, which handled all seven region shapes, and one in the
frame-scheduled sampler, which handled `ptr' and `kbank' and NOTHING ELSE.  So
a region carrying BOTH a bank flag and a "frame" was read from a bare 16-bit
offset -- which is bank 0 -- and reported an address and a plausible body with
no hint it had done so.

IT DOES NOT ASSERT A CONSTANT BANK, because the kernel bank moves under
relocation and the tty bank is derived from it.  It asserts the INVARIANT that
made the defect visible: the same symbol, sampled with and without a frame,
must land in the same bank.  That comparison cannot be satisfied by a wrong
answer that happens to look reasonable, and it goes on working the day the
kernel bank changes.

THE BANK MUST ALSO BE NON-ZERO, and that half is not redundant: bank 0 is what
the defect produced, and a build where BOTH samples somehow read bank 0 would
satisfy the equality on its own.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import json
import pathlib
import sys


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    mem = d.get("memory", {})
    live = mem.get("bank_live")
    samp = mem.get("bank_framed")
    if not live or not samp:
        print("dbgbank: INCONCLUSIVE -- one of the two regions is missing, so "
              "the comparison this test exists for could not be made")
        return 2
    if samp.get("sampled_at_frame", -1) < 0:
        print("dbgbank: INCONCLUSIVE -- bank_framed was never sampled at a "
              "frame (sampled_at_frame %s), so it is not testing the sampler"
              % samp.get("sampled_at_frame"))
        return 2

    lb = live["addr"] >> 16
    sb = samp["addr"] >> 16
    if lb == 0:
        print("dbgbank: INCONCLUSIVE -- the unframed sample is itself in bank 0 "
              "($%06X); the reference is not trustworthy" % live["addr"])
        return 2
    if sb != lb:
        print("dbgbank: FAIL -- the framed sample resolved to bank $%02X ($%06X) "
              "and the unframed one to bank $%02X ($%06X).  A frame-sampled "
              "region is ignoring its bank flag (apple/fgx#236); bank $00 means "
              "it read the offset raw." % (sb, samp["addr"], lb, live["addr"]))
        return 1

    print("dbgbank: ok -- framed and unframed both resolve to bank $%02X "
          "($%06X), sampled at frame %d"
          % (sb, samp["addr"], samp["sampled_at_frame"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
