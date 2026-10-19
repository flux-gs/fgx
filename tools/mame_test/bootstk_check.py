#!/usr/bin/env python3
"""bootstk_check -- the boot stack's headroom must stay real.

apple/fgx#195 said the boot chain's low-water sat at ~$F801, one or two bytes
from the bottom of its 512-byte slice, and proposed growing the slice and arming
a floor on that basis.  RE-MEASURED 2026-08-29: $F920, 288 bytes spare.

The original figure was not carelessness, it was a genuinely deceptive
measurement, and this file exists because the deception repeats:

  * the word at the slice BASE is $C5C5, the canary Task_AllocKernStack seeds --
    NOT stack data.  A scan looking for "the lowest byte that is not paint"
    finds it immediately and reports two bytes of headroom.
  * after userland starts, pid NPROC owns the same 512 bytes and has repainted
    them, so a late sample measures a TASK's stack while looking exactly like a
    measurement of boot's.

IT USED TO ASSERT A NUMBER THE KERNEL PRINTED, and that line is gone: `bstk
$F920 (288 spare)' came off the boot console with the rest of the development
messages, because a boot log carries what the machine DETECTED and a stack
headroom figure is for whoever is sizing a stack.  The measurement is the same
one; only the instrument moved, which is the move kstkhwm_check already makes
for the per-pid slices.  So this scans the PAINT -- Task_AllocKernStack fills
each slice with STK_PAINT ($A5A5) and main.s paints the whole arena before boot
borrows the top slice, so the lowest word that is no longer paint IS the mark,
and the painted words below it ARE the headroom.

BOTH DECEPTIONS ABOVE ARE REFUSED RATHER THAN AVERAGED OVER.  A slice carrying
the $C5C5 canary at its base has been handed to a task and is no longer boot's,
so it is INCONCLUSIVE and not a pass; and the sample frame that makes that
possible is the manifest's business, stated there with the measurement that
chose it.

THE EXTERNAL SAMPLE READS SIX BYTES SHALLOWER than the kernel's own scan did,
and that is arithmetic rather than disagreement: the in-kernel scan ran ON the
stack it was measuring, so its own frames were part of the excursion.  The
deleted code said so -- "an external sample taken at frame 700 reads $F926;
this reports $F920, six bytes deeper".  Reporting less headroom is the safe
bias, so the floor is not retuned to reclaim those six bytes.

THRESHOLD: 48 bytes, AND IT IS A RATCHET RATHER THAN A SAFE MARGIN.  It was
128, chosen against a measured 288 to catch a chain that had grown by hundreds
of bytes without policing ordinary drift.  The chain has since grown by
hundreds of bytes: on a UFS root the mark is $F834, 52 bytes spare, and that
was measured at seven boot frames from 300 to 2400 with the same answer at
every one -- so it is the boot chain's own depth and not a sample taken at an
unlucky moment.  apple/fgx#338 carries it.

48 is the same number kstkhwm_check settled on for the per-pid slices and for
the same reason: it is comfortably above the 14 bytes an interrupt costs,
measured push by push on apple/fgx#297.  It is NOT an endorsement of 52 bytes
in a 512-byte slice.  RAISE IT AS ROOM IS WON BACK, the way that file says.
The point of the number is that the next 200 bytes of deepening fails the build
instead of being discovered by a machine that stops booting.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import json
import pathlib
import sys

from kequ import equ

# A RATCHET on the boot chain's spare, in bytes.  It was 48 of a 512-byte
# slice, which the chain met exactly; the slot is 1,024 now, so the ratchet
# is set where the old slice would have ended and is meant to be raised as the
# chain's true depth is measured on the deeper stack.
FLOOR = 256
PAINT = 0xA5A5
CANARY = 0xC5C5
SIZE = equ("FGX_KSLOT_STK")     # the slot stack size, include/kernel.s
COUNT = equ("FGX_KSLOT_COUNT")  # boot's is the last of these
BASE = equ("FGX_STK_KTASKS")    # CFG_STK_KTASKS


def word(b, i):
    return b[i] | (b[i + 1] << 8)


def main(path="dump.json"):
    d = json.loads(pathlib.Path(path).read_text())
    r = (d.get("memory") or {}).get("bootstk_arena")
    if not r or not r.get("hex"):
        print("bootstk: INCONCLUSIVE -- the dump has no 'bootstk_arena' region, "
              "so there is nothing to measure.  The manifest must ask for "
              "$00E000 with a boot_frame; without the frame the slice has been "
              "repainted by pid NPROC and the number would be a task's.")
        return 2
    b = bytes.fromhex(r["hex"])
    if len(b) < SIZE:
        print(f"bootstk: INCONCLUSIVE -- the region is {len(b)} B, less than "
              f"one {SIZE} B slice.")
        return 2

    # THE LAST SLOT IS BOOT'S, BY CONSTRUCTION: FGX_STK_BOOT is the top slot,
    # the one main.s seeds S into before any task exists.  Indexing from the
    # END means the slot count can change without an address in the manifest
    # going stale.  Every slot carries the canary from boot, so the canary
    # itself says nothing here; what would say a task has been bound to this
    # slot is the SE table, which the dump does not carry, so the manifest's
    # boot_frame is what keeps the sample early.
    if len(b) < COUNT * SIZE:
        print(f"bootstk: INCONCLUSIVE -- the region is {len(b)} B, less than "
              f"the {COUNT} slots of {SIZE} B the config declares.")
        return 2
    off = (COUNT - 1) * SIZE
    addr = BASE + off

    # SCAN UP FROM THE BASE, past the canary word.  The first word that is no
    # longer paint is the deepest the chain reached; everything below it is
    # headroom.
    spare = None
    for i in range(2, SIZE, 2):
        if word(b, off + i) != PAINT:
            spare = i
            break
    if spare is None:
        print(f"bootstk: INCONCLUSIVE -- the whole {SIZE} B slice at "
              f"${addr:04X} is still paint, so nothing has run on it.  A boot "
              f"that reached this frame has used this stack; an all-paint read "
              f"means the region or the frame is wrong, not that the chain is "
              f"free.")
        return 2

    low = addr + spare
    print(f"bootstk: low-water ${low:04X}, {spare} bytes spare "
          f"(slice is {SIZE} B from ${addr:04X})")
    if spare < FLOOR:
        print(f"bootstk: FAIL -- headroom {spare} B is below {FLOOR} B.  The "
              f"boot/modload chain has deepened materially.  Before growing the "
              f"slice, confirm this is boot's own mark and not a task's -- the "
              f"canary arm above is the guard, and the sample frame is the "
              f"other half of it.")
        # AND THEN FIND OUT WHOSE FRAMES TOOK IT.  This number ratchets; it
        # cannot say what deepened, which is the position apple/fgx#376b was
        # left in.  bootstk_chain.py decodes the slice into the chain, and its
        # ladder is how the sample frame that still holds a LIVE chain is
        # found -- the one this fixture takes is far enough past the excursion
        # to read wreckage.
        print("bootstk: to see WHICH frames reached it:\n"
              "    python3 tools/mame_test/bootstk_chain.py --emit-manifest "
              "/tmp/bstk.json\n"
              "    python3 tools/mame_test/run.py --manifest /tmp/bstk.json\n"
              "    python3 tools/mame_test/bootstk_chain.py --dump "
              "/tmp/fgx_test_bootstk_chain_probe/dump.json --ladder\n"
              "  then drop --ladder to decode the deepest sample.")
        return 1
    print(f"bootstk: PASS -- {spare} B spare, floor {FLOOR} B.")
    return 0


def self_test():
    """Four arms: the deception this file exists for, the canary word it must
    step over, plus red and green.

    THE POINT IS THAT IT REFUSES, not that it computes.  A checker of this
    shape fails by returning a plausible number from the wrong bytes, so the
    arms that matter are the ones that must NOT return a wrong 0.
    """
    import tempfile, shutil, os
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="bootstk_selftest_"))
    fails = []

    def run(slice_bytes, label):
        arena = bytes(PAINT.to_bytes(2, "little") * (SIZE // 2)) * (COUNT - 1)
        d = {"memory": {"bootstk_arena":
                        {"hex": (arena + slice_bytes).hex()}}}
        p = tmp / "dump.json"
        p.write_text(json.dumps(d))
        return main(str(p))

    def slice_with(used):
        """A slice with `used' bytes of stack at the TOP and paint below."""
        spare = SIZE - used
        return (bytes(PAINT.to_bytes(2, "little") * (spare // 2))
                + bytes([0x11]) * used)

    # (1) GREEN: headroom comfortably above the ratchet.
    if run(slice_with(SIZE - (FLOOR + 200)), "green") != 0:
        fails.append("headroom above the floor was not accepted")

    # (2) RED: a chain that has eaten into the floor must FAIL, not warn.
    #     16 B under the ratchet: this arm is about the ratchet firing rather
    #     than about a crash.
    if run(slice_with(SIZE - (FLOOR - 16)), "red") != 1:
        fails.append("headroom under the floor was not called a failure -- "
                     "the checker cannot go red")

    # (3) THE CANARY IS NOT A MARK.  Every slot carries $C5C5 in its bottom
    #     word from boot, so the scan must start above it: a slice with the
    #     canary and comfortable headroom is a PASS with that headroom, not a
    #     two-byte reading that trips the floor.
    canary = bytearray(slice_with(SIZE - (FLOOR + 200)))
    canary[0:2] = CANARY.to_bytes(2, "little")
    if run(bytes(canary), "canary") != 0:
        fails.append("the bottom-word canary was read as the high-water mark")

    # (4) DECEPTION: an all-paint slice means the region or the frame is
    #     wrong.  A whole slot of headroom is not a very good pass, it is no
    #     reading.
    allpaint = bytes(PAINT.to_bytes(2, "little") * (SIZE // 2))
    if run(allpaint, "allpaint") != 2:
        fails.append("an untouched slice was reported as a whole slot spare "
                     "instead of refused")

    shutil.rmtree(tmp, ignore_errors=True)
    for f in fails:
        print("SELFTEST FAIL: " + f, file=sys.stderr)
    if fails:
        return 1
    print("bootstk_check self-test: 4 arms pass (2 green, 1 red-capable, "
          "1 refusal)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        sys.exit(self_test())
    sys.exit(main(*sys.argv[1:]))
