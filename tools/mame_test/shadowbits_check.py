#!/usr/bin/env python3
"""shadowbits_check -- do the shadow inhibits SURVIVE, not merely get set?

$C035's bits are active-high inhibits and are CLEARED ON RESET, so the machine
boots shadowing every display region.  A shadowed bank-0 write is mirrored into
the Mega II bank and the STORE is stretched to 1.024 MHz; reads stay at 2.8.

FGX never displays text page 1 or either hi-res page -- it renders to a
scanline framebuffer through bank $01 -- so shadowing those three costs a
stretched cycle for nothing.  Two regions pay it: the low bank-0 space at
$0400-$07FF, and $2000-$5FFF, which is 64 of the user-stack arena's 153 pages,
so every push landing there has been stretched since the arena was carved.

WHY THIS TEST ASSERTS THE SURVIVING VALUE RATHER THAN THE WRITE.  The IRQ
dispatcher masks $C035 on EVERY interrupt per ROM convention (sim.s, saving to
the ROM's ShadSave slot at $E1:0119), and that mask clears bit 0.  Setting the
bits at boot therefore proves nothing on its own -- the question is whether
they come back out of the round-trip.  They do, but only measurement says so,
so this reads the register after a booted, interrupt-driven session.

BIT 3 MUST STAY CLEAR.  The framebuffer reaches the screen precisely BY being
shadowed from bank $01; inhibiting super hi-res would blank the display.  A
test that only checked "bits 0-2 set" would pass a change that blanked the
machine, so bit 3 is asserted in the other direction.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import json
import sys

WANT_SET = 0x07          # bits 0,1,2 -- text page 1, hi-res 1, hi-res 2
WANT_CLEAR = 0x08        # bit 3 -- super hi-res, the framebuffer's shadow


def main():
    if len(sys.argv) < 2:
        print("shadowbits: no dump path given")
        return 2
    try:
        d = json.load(open(sys.argv[1]))
    except Exception as e:                                   # noqa: BLE001
        print(f"shadowbits: cannot read dump: {e}")
        return 2

    reg = d.get("memory", {}).get("shadow_reg")
    if not reg or not reg.get("hex"):
        print("shadowbits: INCONCLUSIVE -- no shadow_reg region in the dump; "
              "the harness plugin must expose $00C035 or this test proves "
              "nothing")
        return 2

    v = int(reg["hex"][:2], 16)
    bad = []
    if (v & WANT_SET) != WANT_SET:
        missing = [b for b in (0, 1, 2) if not v & (1 << b)]
        bad.append(f"bits {missing} NOT inhibited -- those regions are still "
                   f"shadowed, so stores into them are stretched to 1 MHz "
                   f"(the arena's $2000-$5FFF pages among them)")
    if v & WANT_CLEAR:
        bad.append("bit 3 (super hi-res) is INHIBITED -- the framebuffer "
                   "reaches the screen by being shadowed from bank $01, so "
                   "this would blank the display")

    if bad:
        print(f"shadowbits: FAIL  $C035=${v:02X}")
        for b in bad:
            print(f"    {b}")
        return 1

    print(f"shadowbits: PASS  $C035=${v:02X} -- text page 1 and both hi-res "
          f"pages inhibited (full-speed stores), super hi-res still shadowed "
          f"(display intact), and the value survived the IRQ dispatcher's "
          f"per-interrupt mask")
    return 0


if __name__ == "__main__":
    sys.exit(main())
