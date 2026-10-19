#!/usr/bin/env python3
"""ticksprobe_check -- is a plugin frame still an emulated frame?

THE HARNESS SCHEDULES EVERYTHING BY COUNTING CALLBACKS.  `frame_count' in
plugins/fgxdebug/init.lua is incremented once per `emu.register_frame_done',
and every timed action is expressed against it: when each injected keystroke
is written, when the dump is taken, when the run is cut off.  If MAME ever
coalesces or skips those callbacks -- under host load, on a new version, with
a different video backend -- the counter runs slow, the guest receives its
input at different EMULATED moments, and NOTHING IN THE LOGS SAYS SO.  Both
runs print the same frame numbers, because those numbers are the counter.

That is not a hypothetical failure mode; it was the leading explanation for
apple/fgx#265 and apple/fgx#266 until this measurement ruled it out.  A test
whose input timing can silently change is a test whose reds cannot be read.

WHAT IS ASSERTED, AND WHY IT IS A RATIO.  `_kSystemTicks' is the guest's own
60 Hz counter, incremented by the heartbeat on the VBL
(src/kernel/toolbox.s::_HBTickTask), so at the fixture's fixed dump frame it
says how much EMULATED time really passed.  One tick per frame is the
invariant.  The absolute number is not asserted: it carries a boot-length
offset -- the heartbeat starts a couple of seconds in -- and pinning it would
turn every legitimate change in boot into a red here.  The RATIO is the
property, and a callback regime running at half rate reports about 2.0, which
is nowhere near the window.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import json
import sys

# Measured 2026-08-30: 4943 ticks at frame 5101 = 0.969, idle and under an
# 8-way suite alike (ticks/frame).  The window is wide enough for a boot that starts the
# heartbeat a second earlier or later and nowhere near a dropped-callback
# regime.
LO, HI = 0.93, 1.02


def run(path):
    try:
        d = json.load(open(path))
    except (OSError, ValueError) as e:
        print("INCONCLUSIVE: cannot read %s: %s" % (path, e))
        return 2
    frame = d.get("frame")
    reg = (d.get("memory") or {}).get("systicks")
    # FAIL CLOSED ON A MISSING INSTRUMENT.  A checker that cannot reach its
    # subject and says nothing is indistinguishable from one that looked and
    # found nothing wrong, which is the failure this suite keeps paying for.
    if not frame:
        print("INCONCLUSIVE: dump has no frame number")
        return 2
    if not reg or not reg.get("hex"):
        print("INCONCLUSIVE: dump has no `systicks' region -- the manifest "
              "must dump _kSystemTicks for this to measure anything")
        return 2
    ticks = int.from_bytes(bytes.fromhex(reg["hex"]), "little")
    if ticks == 0:
        print("INCONCLUSIVE: _kSystemTicks is 0 -- the heartbeat never ran, "
              "so this says nothing about the callback rate")
        return 2
    ratio = float(ticks) / float(frame)
    ok = LO <= ratio <= HI
    print("%s: %d guest ticks / %d plugin frames = %.3f (want %.2f..%.2f)"
          % ("PASS" if ok else "FAIL", ticks, frame, ratio, LO, HI))
    if not ok:
        print("  a plugin frame is no longer an emulated frame: every "
              "injected keystroke now lands at a different emulated moment "
              "than the logs imply, and no other test can see it")
    return 0 if ok else 1


def selftest():
    """A checker that cannot go red is not coverage.  Three synthetic dumps
    whose answers are known by construction."""
    import tempfile, os
    def dump(frame, ticks, region=True):
        d = {"frame": frame}
        if region:
            d["memory"] = {"systicks": {"hex": ticks.to_bytes(4, "little").hex()}}
        fd, p = tempfile.mkstemp(suffix=".json")
        os.write(fd, json.dumps(d).encode())
        os.close(fd)
        return p
    good = dump(5101, 4943)          # the measured, healthy case
    half = dump(5101, 9886)          # callbacks at half rate: twice the
                                     # emulated time per counted frame -> ~1.94
    none = dump(5101, 0, region=False)
    rc_good, rc_half, rc_none = run(good), run(half), run(none)
    for p in (good, half, none):
        os.unlink(p)
    assert rc_good == 0, "the healthy case must pass, got %d" % rc_good
    assert rc_half == 1, "a half-rate callback must FAIL, got %d" % rc_half
    assert rc_none == 2, "a missing region must be INCONCLUSIVE, got %d" % rc_none
    print("ticksprobe_check: self-test OK")
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(selftest())
    sys.exit(run(sys.argv[1] if len(sys.argv) > 1 else "dump.json"))
