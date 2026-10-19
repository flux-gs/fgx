#!/usr/bin/env python3
"""kstkhwm_check -- how deep do the KERNEL-IMAGE SLOT stacks actually go?

THE CANARY IS NOT THIS MEASUREMENT.  main.s seeds $C5C5 in the bottom word of
each slot stack and the dispatcher checks the running task's at every syscall
entry (syscall.s), but that is ONE WORD AT THE VERY BOTTOM: it answers "did
this stack overflow all of it", and nothing else.  A stack can run to within a
handful of bytes of that word, every boot, and the canary stays green -- which
is exactly what this check found on the 512-byte per-pid slices
(apple/fgx#230).

So the slots are PAINTED.  main.s fills every slot with STK_PAINT ($A5A5) at
boot, before borrowing the top one, so the lowest word that is no longer paint
IS the high-water mark.  A slot is reused by task after task, so its mark is
the deepest any of them went, which is the number that sizes it.  The fill
used to be zero, which measures nothing: a legitimately pushed zero and
untouched fill read alike.

The technique is the house one: main.s scans page 1 (`kstk: page 1
high-water'), probe_dev.s scans a window of the boot slot (`probe: stack
reached ktasks+'), and _Tas_PaintStack/Task_StkHwm have measured the USER
stacks since bank0-stack 0.1.

IT DISCRIMINATES, and that was verified rather than assumed: building with
OBUFSIZ 100 instead of 16 (`ttwrite''s `char obuf[OBUFSIZ]' local) moved the
mark on the tty-path stacks by 168 -> 252 bytes.  84 bytes deeper, which is
exactly the 84-byte delta in the array.  A mark that tracks a known change by
the predicted amount is measuring the stack and not an artefact.

KNOWN CEILING: a genuinely pushed $A5A5 word at the frontier reads as untouched
fill, so a mark can only ever be reported SHALLOWER than the truth, never
deeper.  Under-reporting is the safe direction for a headroom check.

THE SCHEDULER'S OWN STACK (FGX_STK_SWITCH, the `switch_stack' region) is
painted and canaried at boot the same way and reported as slot `sw' when the
dump carries it: swtch stands on it from @sw_pick to the resume TCS, the idle
arm included, so its depth is the scheduler's and the idle loop's, not any
task's.  It is held to the same ratchet.

The slot size and the switch stack's come from the generated config through
kequ, so a geometry change moves this check with it.

Run standalone for the table:  python3 kstkhwm_check.py <dump.json> [more...]
As a test check_script it takes one dump and enforces MIN_SPARE.

Exit 0 = pass, 1 = fail, 2 = inconclusive.
"""
import json
import sys

from kequ import equ

PAINT = 0xA5A5
CANARY = 0xC5C5
SIZE = equ("FGX_KSLOT_STK")           # a slot stack, include/kernel.s
COUNT = equ("FGX_KSLOT_COUNT")        # how many; the dump may cover more
SW_SIZE = equ("FGX_STK_SWITCH_SIZE")  # the scheduler's stack

# A RATCHET on the spare bytes of the deepest stack.  On the 512-byte per-pid
# slices it sat at 48 with the exec chain at 470 used, and that chain overran
# the slice under the fixture sweep (apple/fgx#442); the slots are 1,024 so
# the chain has room to show its true depth, and the ratchet starts where the
# old slice ended.  RAISE IT as the chain's real depth is measured: the goal
# is a margin proportional to the slot, not a number that merely beats the
# last run.
MIN_SPARE = 256


def word(b, i):
    return b[i] | (b[i + 1] << 8)


def marks(b, base, size, label=None):
    """[(slot, base_addr, canary_state, deepest_addr|None, used, spare, size)]"""
    out = []
    for k in range(len(b) // size):
        off = k * size
        can = word(b, off)
        state = {CANARY: "ok", PAINT: "unseeded"}.get(can, "DEAD $%04X" % can)
        mark = None
        # from base+2: the bottom word is the canary, never paint
        for i in range(2, size, 2):
            if word(b, off + i) != PAINT:
                mark = i
                break
        name = k if label is None else label
        if mark is None:
            out.append((name, base + off, state, None, 0, size, size))
        else:
            out.append((name, base + off, state, base + off + mark,
                        size - mark, mark, size))
    return out


def table(rows):
    print("slot   range           canary     deepest  used         spare")
    for k, a, state, deep, used, spare, size in rows:
        d = "-" if deep is None else "$%04X" % deep
        u = "untouched" if deep is None else "%d/%d" % (used, size)
        print("  %2s   $%04X-$%04X   %-10s %7s  %-11s %5d"
              % (k, a, a + size - 1, state, d, u, spare))


def main(argv):
    if not argv:
        print("kstkhwm: no dump path given")
        return 2
    worst_rc = 0
    for path in argv:
        try:
            d = json.load(open(path))
        except Exception as e:                                   # noqa: BLE001
            print("kstkhwm: cannot read dump: %s" % e)
            return 2
        r = d.get("memory", {}).get("kern_stacks")
        if not r:
            print("kstkhwm: INCONCLUSIVE -- the dump has no kern_stacks region")
            return 2
        b = bytes.fromhex(r["hex"])[:COUNT * SIZE]
        rows = marks(b, r["addr"], SIZE)
        # The scheduler's stack, when the dump carries it (older dumps do
        # not): one more row, named rather than numbered.
        sw = d.get("memory", {}).get("switch_stack")
        if sw:
            sb = bytes.fromhex(sw["hex"])
            rows += marks(sb, sw["addr"], SW_SIZE, label="sw")
        if not any(word(b, k * SIZE + i) == PAINT
                   for k in range(len(b) // SIZE) for i in (2, 4, 6)):
            print("kstkhwm: INCONCLUSIVE -- no STK_PAINT anywhere in the "
                  "slots.  This kernel does not paint its kernel stacks, so "
                  "the marks below would be residue, not measurements.")
            return 2
        if len(argv) > 1:
            print("\n=== %s ===" % path)
        table(rows)
        dead = [r_ for r_ in rows if r_[2].startswith("DEAD")]
        tight = [r_ for r_ in rows if r_[3] is not None and r_[5] < MIN_SPARE]
        if dead:
            print("kstkhwm: FAIL")
            for k, a, state, _d, _u, _s, _z in dead:
                print("    slot %s ($%04X) canary %s: this stack was "
                      "overrun ALL the way to its bottom word" % (k, a, state))
            worst_rc = 1
        elif tight:
            print("kstkhwm: FAIL")
            for k, a, _st, deep, used, spare, size in tight:
                print("    slot %s ($%04X) reached $%04X -- %d of %d bytes "
                      "used, %d spare, under the %d-byte ratchet"
                      % (k, a, deep, used, size, spare, MIN_SPARE))
            worst_rc = 1
        else:
            deepest = max((r_ for r_ in rows if r_[3] is not None),
                          key=lambda r_: r_[4], default=None)
            if deepest is None:
                print("kstkhwm: INCONCLUSIVE -- every stack reads untouched")
                return 2
            print("kstkhwm: PASS -- deepest slot %s used %d of %d bytes "
                  "(%d spare, ratchet %d); every canary intact"
                  % (deepest[0], deepest[4], deepest[6], deepest[5],
                     MIN_SPARE))
    return worst_rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
