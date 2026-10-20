#!/usr/bin/env python3
"""genconfig.py -- cfg/system.cfg -> include/config.s (Merlin EQUates).

Ported from lib/build_common.sh's generate_config() when the ninja graph took
over.  Nothing called it on the ninja branch, so editing cfg/system.cfg changed
NOTHING: include/config.s is tracked, so the kernel kept building happily from
whatever the last build.sh run had left there.  A config knob that silently does
not apply is worse than one that fails.

`key = value` per line, '#' comments and blanks skipped.  A key becomes an
EQU name by upcasing and mapping '.' to '_':

    video.bg_color = $0333   ->   CFG_VIDEO_BG_COLOR    EQU  $0333

A $0RGB colour additionally emits the byte pair the IIgs SHR palette wants:

    CFG_VIDEO_BG_COLOR_LO EQU  $33      (GB)
    CFG_VIDEO_BG_COLOR_HI EQU  $03      (0R)

`kernel.kslots` and `kernel.kstk` additionally DERIVE the bank-0 layout (see
DERIVED, below): the slot stacks, the interrupt-time context above them, the
slot pages and the scheduler's stack, constants that must all move together
and which Merlin32 cannot compute for itself.  `kernel.nproc` moves nothing in
bank 0; it only has to fit the kernel-image homes in one bank.

Usage:  genconfig.py <cfg> <out>
        genconfig.py --self-test
"""
import re
import sys

HEADER = (";" + "=" * 78 + "\n"
          "; FGX Configuration (AUTO-GENERATED from cfg/system.cfg)\n"
          "; DO NOT EDIT - modify cfg/system.cfg and rebuild\n"
          ";" + "=" * 78 + "\n\n")
FOOTER = ("\n;" + "=" * 78 + "\n"
          "; END OF AUTO-GENERATED CONFIG\n"
          ";" + "=" * 78 + "\n")

COLOR = re.compile(r"^\$0([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$")

# ---------------------------------------------------------------------------
# THE DERIVED BANK-0 LAYOUT.
#
# A task needs bank-0 pages for its kernel stack and its direct pages, and the
# 65816 gives no choice about that: S and D are 16-bit registers.  The kernel
# side of that is the slot geometry below, sized by kernel.kslots and
# kernel.kstk, and every constant in the language card follows from it; the
# user side is a task's stack reservation, which carries its user direct page
# (task.s Task_AllocStack).  So nothing here scales with NPROC, and the stack
# arena is the whole of bank 0 between BLK_STAGE and the kernel-C direct page.
#
# CFG_DP_KERNELC, the direct page kernel C runs on, is the last page below the
# I/O space.  It is a separate page and not a corner of the kernel's own
# because fcc's register file wants $98-$FF laid out the way a TASK direct page
# is laid out, and the kernel DP page has the console's persistent state across
# $C0-$EF.  The two maps are irreconcilable; see toolchain/lib/fcc_runtime.s.
#
# A layout edited by hand was done wrong once: the task count moved without
# BLK_STAGE, so two kernel stacks landed exactly on top of the buffer every
# SmartPort read stages through.  That did not fail -- it silently corrupted,
# and the symptom was a login test that got WORSE (apple/fgx#43, apple/fgx#45).
#
# So the arithmetic lives here, in Python, where it is free -- Merlin32 has no
# operator precedence and gives up on the nested-brace expressions this needs.
# tools/check_bank0_geometry.py then validates the RESULT against the whole
# invariant chain, independently: this file computes, that one checks.  Neither
# trusts the other, which is the point.
# ---------------------------------------------------------------------------
# THE KERNEL STACKS LIVE IN THE LANGUAGE CARD.
#
# $00:E000-$FFFF is 8 KB of bank-0 RAM in the language card -- flat, NOT
# bank-switched, and reachable by both the 16-bit stack pointer and the direct
# page register like any other bank-0 address.  It was measured on a real IIgs
# and the whole suite runs with it mapped (docs/history/audits/bank0-lc-spike-results.md).
#
# THE ARENA BASE DOES NOT MOVE.  Relocating it disturbs the stack-attribution
# tests, which are coupled to first-fit allocation OUTCOMES and not merely to
# addresses (docs/bank0-blkstage-relocation.md).  So BLK_STAGE and
# FGX_STK_ARENA stay exactly where they are.
KSTK_BASE = 0xE000        # the kernel-image slot stacks, in the language card
KSTK_LIMIT = 0xFFE0       # ...and the ceiling they must not reach
# THE INTERRUPT-TIME KERNEL-C STACK SIZE, read from include/kernel.s and not
# invented here: FGX_KSTK_SIZE is a kernel.s constant (it is not in the
# generated config, because the config is what kernel.s reads), so this is a
# MIRROR and check_bank0_geometry.py holds the two equal.  The interrupt
# context below is placed by it, so a stale copy here would put that context
# inside the slot stacks.
KSTK_SIZE = 512

# THE KERNEL-IMAGE SLOTS.
#
# A task's kernel image -- its kernel direct page and its kernel stack --
# lives in a SLOT while the task is inside the kernel, and the slot is bound
# when the scheduler picks the task, not when the task is created.  The
# stacks fill the flat 8 KB from $E000 upward, kernel.kslots of kernel.kstk
# bytes each, with the interrupt-time kernel-C context immediately above them;
# the direct pages sit in the mapped $D000 bank, one page per slot from $D000
# up, below the scheduler's own stack.  Neither block scales with NPROC.  A
# task whose slot another task needs is parked: its page and the live part of
# its stack go to a home image, KHOME_STRIDE bytes per pid in one bank the
# kernel allocates at boot, and come back to the same slot when it next runs.
KSLOT_DP_BASE = 0xD000
KHOME_STRIDE = 2048       # a home image: the page, then up to kstk of stack

# THE SCHEDULER'S OWN STACK.
#
# swtch moves S here at @sw_pick and stands on it until the resume TCS, so
# picking, parking a lane member, idling in WAI and the kernel C the idle arm
# enters never push on the stack of the task that just gave up the CPU.  It
# is the TOP OF THE MAPPED $D000 BANK, not part of the flat 8 KB: the per-pid
# stacks and the interrupt-time context are sized against $E000-$FFDF, and
# the $D000 window (bank 1, selected by _LC_MapRam and restored by every
# ROM-in bracket in the tree) holds nothing else.  The size is a MIRROR of
# include/kernel.s's FGX_STK_SWITCH_SIZE, held equal by
# check_bank0_geometry.py the way KSTK_SIZE is.
SWITCH_SIZE = 512
LC_BANK_TOP = 0xE000      # the mapped $D000 bank ends where the flat 8 KB begins

# THE INTERRUPT-TIME KERNEL-C CONTEXT (apple/fgx#108 T6, 2026-08-26).
#
# A second C context needs three things and only the first is a register file:
# its own $98..$FF (a direct page), its own STACK -- the heartbeat runs on
# whatever it interrupted, and the per-pid kernel stack has measured 190 bytes
# spare -- and a stack FLOOR, which comes free once the stack is its own.
#
# THEY GO ABOVE THE PER-PID KERNEL STACKS, in the same flat 8 KB of language
# card, and NOT in bank 0's low region.  $1600..$17FF is free down there and
# would have fit the direct page, but it is the contended end of the machine:
# the per-pid kernel DP block grows up into it and BLK_STAGE walls it at $1800.
# The language card has 1,504 bytes spare above the stacks at NPROC 12 and
# nothing else is growing into them.  Both blocks are derived from the same
# chain as the stacks, so an NPROC that does not fit fails here rather than
# overlapping something.
KIRQ_DP_PAGES = 1         # the interrupt kernel-C direct page: $98..$FF of one
IO_BASE = 0xC000          # bank-0 I/O; the DP block grows DOWN from here
BLK_STAGE_FIXED = 0x1800  # unchanged; no longer derived from the stacks
ARENA_FIXED = 0x1A00      # unchanged -- see above, this must not move
BLK_STAGE_BYTES = 0x200

# THE KERNEL'S OWN DIRECT PAGE, AND THE TEMPLATE.
#
# A task's USER direct page is the first page of its stack reservation
# (task.s Task_AllocStack), so no block in bank 0 scales with NPROC.  The
# page the KERNEL runs on while serving a task is its slot's (above); this
# one page at $0900 is the loader's hand-off page, boot's own, and the
# template every slot page is copied from when a task is bound, so the heap
# and table pointers established at boot are carried into every copy.  Its
# ceiling is BLK_STAGE, the collision the per-pid kernel stacks once had
# there (apple/fgx#43, #45), so the same check.
KDP_BASE = 0x0900


def derive(nproc, kslots=6, kstk=1216):
    """The coupled bank-0 constants, for a given NPROC and slot geometry.

    Nothing in bank 0 scales with NPROC any more: user direct pages ride in
    their tasks' stack reservations and kernel images live in the slots.
    NPROC still bounds the kernel-image homes, one per pid in one bank.  The
    kernel-C direct page is the last page below the I/O space, charged to the
    arena like any other page taken out of it.
    """
    # A knob can be turned down as well as up.  nproc 0 or 1 emits a
    # perfectly valid-looking layout, and TASK_MAX_SLOTS EQU NPROC then makes
    # task.s's table clear compute a NEGATIVE length -- `LDA
    # #{TASK_MAX_SLOTS*TCB_SIZE}-2` wraps to 65534 and MVNs that many bytes
    # over bank 0 at boot.  Nothing downstream bounds this from below.
    if nproc < 2:
        raise SystemExit(
            f"genconfig: kernel.nproc = {nproc} is too small. init is pid 1 and "
            f"needs at least one other slot to spawn into; below 2 the task "
            f"table's own size arithmetic goes negative and boot MVNs over "
            f"bank 0.")
    if kslots < 1:
        raise SystemExit(
            f"genconfig: kernel.kslots = {kslots}. At least one slot is "
            f"needed: the running task is always bound to one.")
    if kstk < KSTK_SIZE or kstk & 1:
        raise SystemExit(
            f"genconfig: kernel.kstk = {kstk} must be an even number of bytes "
            f"and at least {KSTK_SIZE}: the interrupt-time stack is {KSTK_SIZE} "
            f"and runs the same kind of code, and the paint is written two "
            f"bytes at a time.")
    kstk_top = KSTK_BASE + kslots * kstk
    if kstk_top > KSTK_LIMIT:
        raise SystemExit(
            f"genconfig: kernel.kslots = {kslots} slot stacks of kernel.kstk = "
            f"{kstk} bytes end at ${kstk_top:04X}, past the language-card "
            f"ceiling ${KSTK_LIMIT:04X}. The top of that region is the "
            f"hardware vector table; do not grow into it.")

    # The interrupt-time kernel-C context, immediately above the slot stacks:
    # one direct page, then one stack of KSTK_SIZE.  It runs ttyinput ->
    # ttyecho -> ttyoutput -> putc against a task's syscall depth.
    dp_kernelc_irq = kstk_top
    stk_kirq = dp_kernelc_irq + KIRQ_DP_PAGES * 256
    kirq_top = stk_kirq + KSTK_SIZE
    if kirq_top > KSTK_LIMIT:
        raise SystemExit(
            f"genconfig: kernel.kslots = {kslots} x kernel.kstk = {kstk} leaves "
            f"no room above the slot stacks (which end at ${kstk_top:04X}) for "
            f"the interrupt-time kernel-C context: its direct page and "
            f"{KSTK_SIZE}-byte stack would end at ${kirq_top:04X}, past the "
            f"language-card ceiling ${KSTK_LIMIT:04X}. Interrupt-time C is what "
            f"runs ttyinput at arrival (apple/fgx#108 T6); without its own page "
            f"and stack it shares a task's, which is the corruption the second "
            f"register file exists to stop.")
    # The slot direct pages, in the mapped $D000 bank below the scheduler's
    # stack.
    switch_base = LC_BANK_TOP - SWITCH_SIZE
    kslot_dp_top = KSLOT_DP_BASE + kslots * 256
    if kslot_dp_top > switch_base:
        raise SystemExit(
            f"genconfig: kernel.kslots = {kslots} slot direct pages end at "
            f"${kslot_dp_top:04X}, past the scheduler's stack at "
            f"${switch_base:04X}; the $D000 bank holds at most "
            f"{(switch_base - KSLOT_DP_BASE) // 256} of them.")
    # The home images: one per pid, in one bank.
    if 256 + kstk > KHOME_STRIDE:
        raise SystemExit(
            f"genconfig: kernel.kstk = {kstk} plus a 256-byte page does not fit "
            f"a {KHOME_STRIDE}-byte home image. Raise KHOME_STRIDE (and the "
            f"shift in task.s that ERRs against it) before raising the depth "
            f"past {KHOME_STRIDE - 256}.")
    if nproc * KHOME_STRIDE > 0x10000:
        raise SystemExit(
            f"genconfig: kernel.nproc = {nproc} home images of {KHOME_STRIDE} "
            f"bytes do not fit in one bank; the kernel keeps every parked "
            f"kernel image in a single Bank_Alloc bank.")
    blk_stage = BLK_STAGE_FIXED
    arena = ARENA_FIXED
    kdp_top = KDP_BASE + 256
    if kdp_top > blk_stage:
        raise SystemExit(
            f"genconfig: the kernel's template direct page at ${KDP_BASE:04X} "
            f"runs into BLK_STAGE at ${blk_stage:04X}.")
    dp_kernelc = IO_BASE - 256
    arena_pages = (dp_kernelc - arena) // 256
    # The slot pages, the scheduler's stack and boot's borrowed slot do not
    # scale with NPROC; they are emitted here so the whole bank-0 layout is
    # derived in one place and checked as one.  Boot runs on the TOP slot's
    # stack until the first task exists.
    boot_stk = KSTK_BASE + (kslots - 1) * kstk
    return {
        "CFG_STK_KTASKS": f"${KSTK_BASE:04X}",
        "CFG_BLK_STAGE": f"${blk_stage:04X}",
        "CFG_STK_ARENA": f"${arena:04X}",
        "CFG_DP_KERNELC": f"${dp_kernelc:04X}",
        "CFG_DP_KKERN": f"${KDP_BASE:04X}",
        "CFG_DP_KERNELC_IRQ": f"${dp_kernelc_irq:04X}",
        "CFG_STK_KIRQ": f"${stk_kirq:04X}",
        "CFG_KSLOT_DP": f"${KSLOT_DP_BASE:04X}",
        "CFG_STK_BOOT": f"${boot_stk:04X}",
        "CFG_KHOME_STRIDE": str(KHOME_STRIDE),
        "CFG_STK_SWITCH": f"${switch_base:04X}",
        "CFG_STK_ARENA_PAGES": str(arena_pages),
    }


# THE REST-OF-OS LAYOUT.  Two fixed regions (the console bank and the font
# bank), then the module window, the heap's boot arenas and the user pool, in
# that order, as offsets from the runtime rest base.  The claim is all of
# them; its floor keeps the fixed regions and rest.min_user_banks user banks.
REST_KEYS = ("CFG_REST_KMOD_BANKS", "CFG_REST_HEAP_BANKS",
             "CFG_REST_USER_BANKS", "CFG_REST_MIN_USER_BANKS")


def derive_rest(kmod, heap, user, min_user):
    if min(kmod, heap, user, min_user) < 1 or min_user > user:
        raise SystemExit(
            f"genconfig: rest.kmod_banks={kmod} rest.heap_banks={heap} "
            f"rest.user_banks={user} rest.min_user_banks={min_user}: every "
            "region needs at least one bank, and the floor cannot exceed the "
            "pool.")
    fixed = 2 + kmod + heap
    if fixed + user > 0xFF:
        raise SystemExit(
            f"genconfig: the rest-of-OS claim of {fixed + user} banks does not "
            "fit the loader's one-byte bank count.")
    return {
        "CFG_REST_CONSOLE_BANK_OFF": "0",
        "CFG_REST_FONTS_BANK_OFF": "1",
        "CFG_REST_KMOD_FIRST_OFF": str(2),
        "CFG_REST_HEAP_FIRST_OFF": str(2 + kmod),
        "CFG_REST_USER_FIRST_OFF": str(fixed),
        "CFG_RESTOFOS_BANKS": f"${fixed + user:02X}",
        "CFG_RESTOFOS_MIN_BANKS": f"${fixed + min_user:02X}",
    }


def generate(cfg_text):
    out = []
    nproc = kslots = kstk = None
    rest = {}
    for line in cfg_text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key, val = key.strip(), val.strip()
        name = ("CFG_" + key).upper().replace(".", "_")
        out.append(f"{name:<20} EQU     {val}")
        if name == "CFG_KERNEL_NPROC":
            nproc = int(val)
        elif name == "CFG_KERNEL_KSLOTS":
            kslots = int(val)
        elif name == "CFG_KERNEL_KSTK":
            kstk = int(val)
        elif name in REST_KEYS:
            rest[name] = int(val)
        m = COLOR.match(val)
        if m:
            r, g, b = m.groups()
            out.append(f"{name + '_LO':<20} EQU     ${g}{b}")
            out.append(f"{name + '_HI':<20} EQU     $0{r}")
    if nproc is not None:
        out.append("")
        out.append("; --- BANK-0 LAYOUT, DERIVED FROM kernel.nproc "
                   + "-" * 33)
        out.append("; Do not hand-edit or re-literalise these in kernel.s / "
                   "fs.s / stage2.s:")
        out.append("; they must move together, and check_bank0_geometry.py "
                   "enforces both the")
        out.append("; resulting geometry and the fact that those files still "
                   "alias these names.")
        if kslots is None or kstk is None:
            raise SystemExit(
                "genconfig: cfg/system.cfg sets kernel.nproc but not both "
                "kernel.kslots and kernel.kstk -- the kernel-image slots need "
                "both to place the bank-0 layout.")
        for name, val in derive(nproc, kslots, kstk).items():
            out.append(f"{name:<20} EQU     {val}")
    if rest:
        missing = [k for k in REST_KEYS if k not in rest]
        if missing:
            raise SystemExit("genconfig: cfg/system.cfg sets part of the "
                             "rest-of-OS layout but not " + ", ".join(missing))
        out.append("")
        out.append("; --- REST-OF-OS LAYOUT, DERIVED FROM rest.* " + "-" * 34)
        out.append("; kernel.s and stage2.s alias these names; tools/mkfgxunix.py "
                   "reads them.")
        for name, val in derive_rest(*(rest[k] for k in REST_KEYS)).items():
            out.append(f"{name:<25} EQU     {val}")
    return HEADER + "\n".join(out) + "\n" + FOOTER


def _selftest():
    """A generator that emitted nothing would still write a valid-looking file
    and let every CFG_ symbol fall back to whatever the tracked copy said."""
    fails = 0
    got = generate("# comment\n\nvideo.bg_color = $0333\nkernel.nproc = 8\n"
                   "kernel.kslots = 6\nkernel.kstk = 1216\n")
    for want in ("CFG_VIDEO_BG_COLOR    EQU     $0333",
                 "CFG_VIDEO_BG_COLOR_LO EQU     $33",
                 "CFG_VIDEO_BG_COLOR_HI EQU     $03",
                 "CFG_KERNEL_NPROC     EQU     8",
                 "CFG_KERNEL_KSLOTS    EQU     6",
                 "CFG_KSLOT_DP         EQU     $D000"):
        if want.split()[0] not in got:
            print(f"  SELFTEST FAIL: missing symbol {want.split()[0]}")
            fails += 1
    if "comment" in got:
        print("  SELFTEST FAIL: a '#' comment leaked into the output")
        fails += 1
    # A non-colour value must NOT sprout _LO/_HI.
    if "CFG_KERNEL_NPROC_LO" in got:
        print("  SELFTEST FAIL: non-colour value got a _LO/_HI pair")
        fails += 1
    # THE DERIVED LAYOUT.  Pinned to the numbers that actually ship, so a
    # change to the arithmetic cannot quietly re-lay-out bank 0.
    #
    # THESE PINS WERE STALE AND NOTHING NOTICED, which is the reason this
    # self-test is now wired into tools/gate.sh.  They still named the $0C00
    # arrangement long after the per-pid kernel stacks moved into the language
    # card at $E000 -- so every one of them was failing, and a check nobody
    # runs is indistinguishable from a check that passes.  The same rot put
    # $0C00 into include/kernel.s's layout comment, which is where
    # apple/fgx#172's framing came from.
    #
    # At every NPROC: kernel stacks at $E000, BLK_STAGE $1800, the arena $1A00
    # for 165 pages up to the kernel-C direct page at $BF00.
    d = derive(10)
    for name, want in (("CFG_STK_KTASKS", "$E000"), ("CFG_BLK_STAGE", "$1800"),
                       ("CFG_STK_ARENA", "$1A00"), ("CFG_DP_KERNELC", "$BF00"),
                       ("CFG_STK_SWITCH", "$DE00"),
                       ("CFG_DP_KERNELC_IRQ", "$FC80"), ("CFG_STK_KIRQ", "$FD80"),
                       ("CFG_KSLOT_DP", "$D000"), ("CFG_STK_BOOT", "$F7C0"),
                       ("CFG_KHOME_STRIDE", "2048"),
                       ("CFG_STK_ARENA_PAGES", "165")):
        if d[name] != want:
            print(f"  SELFTEST FAIL: derive(10)[{name}] = {d[name]}, want {want}"
                  " -- the shipping bank-0 layout changed")
            fails += 1
    # THE SLOT GEOMETRY'S WALLS.  Seven slots of 1,216 reach the vector table
    # through the interrupt context; a stack too shallow for the interrupt
    # stack's own code is refused; and 33 home images do not fit a bank.
    for bad_slots, bad_stk in ((7, 1216), (6, 1408), (4, 400), (0, 1216)):
        try:
            derive(12, bad_slots, bad_stk)
            print(f"  SELFTEST FAIL: derive(12, {bad_slots}, {bad_stk}) produced "
                  f"a layout anyway")
            fails += 1
        except SystemExit:
            pass
    try:
        derive(33)
        print("  SELFTEST FAIL: 33 home images were laid out in one bank")
        fails += 1
    except SystemExit:
        pass
    # The kernel-C page must be the last page below the I/O space at every
    # NPROC -- nothing in bank 0 scales with NPROC now, and a gap would be
    # unclaimed bank 0 that the arena does not cover and the claim table does
    # not describe.
    for n in (2, 8, 10, 11, 12):
        d = derive(n)
        if int(d["CFG_DP_KERNELC"][1:], 16) + 256 != IO_BASE:
            print(f"  SELFTEST FAIL: derive({n}) does not put the kernel-C "
                  f"page flush under the I/O space")
            fails += 1
        if "CFG_DP_KTASKS" in d:
            print(f"  SELFTEST FAIL: derive({n}) emitted a per-pid DP block")
            fails += 1
    # A process costs no arena page.
    if int(derive(11)["CFG_STK_ARENA_PAGES"]) != 165:
        print("  SELFTEST FAIL: the arena is not 165 pages at NPROC 11")
        fails += 1
    # A knob turned DOWN past a usable machine must raise, not emit a layout
    # that boots into a 65534-byte MVN.
    for bad in (0, 1):
        try:
            derive(bad)
            print(f"  SELFTEST FAIL: derive({bad}) produced a layout anyway")
            fails += 1
        except SystemExit:
            pass
    # An impossible NPROC must RAISE -- 200 kernel-image homes do not fit a
    # bank -- not emit a layout.
    try:
        derive(200)
        print("  SELFTEST FAIL: an impossible NPROC produced a layout anyway")
        fails += 1
    except SystemExit:
        pass
    if "CFG_BLK_STAGE" in generate("video.bg_color = $0333\n"):
        print("  SELFTEST FAIL: the derived block was emitted without an nproc")
        fails += 1
    # THE REST-OF-OS LAYOUT, pinned to what ships: console, fonts, a 3-bank
    # module window, 2 heap banks, a 56-bank pool, a floor of 3 user banks.
    want = {"CFG_REST_KMOD_FIRST_OFF": "2", "CFG_REST_HEAP_FIRST_OFF": "5",
            "CFG_REST_USER_FIRST_OFF": "7", "CFG_RESTOFOS_BANKS": "$3F",
            "CFG_RESTOFOS_MIN_BANKS": "$0A"}
    got = derive_rest(3, 2, 56, 3)
    for name, val in want.items():
        if got.get(name) != val:
            print(f"  SELFTEST FAIL: {name} = {got.get(name)}, want {val}")
            fails += 1
    # The floor and the claim must move with the window: one more module bank
    # moves the heap, the pool, the claim and the floor by one each.
    got = derive_rest(4, 2, 56, 3)
    if (got["CFG_REST_HEAP_FIRST_OFF"], got["CFG_REST_USER_FIRST_OFF"],
            got["CFG_RESTOFOS_BANKS"], got["CFG_RESTOFOS_MIN_BANKS"]) != \
            ("6", "8", "$40", "$0B"):
        print(f"  SELFTEST FAIL: a wider module window did not move the rest "
              f"of the layout: {got}")
        fails += 1
    for bad in ((0, 2, 56, 3), (3, 2, 56, 57), (3, 2, 300, 3)):
        try:
            derive_rest(*bad)
            print(f"  SELFTEST FAIL: derive_rest{bad} produced a layout anyway")
            fails += 1
        except SystemExit:
            pass
    try:
        generate("rest.kmod_banks = 3\n")
        print("  SELFTEST FAIL: a partial rest-of-OS layout was accepted")
        fails += 1
    except SystemExit:
        pass
    if fails:
        print(f"genconfig self-test: {fails} FAILURE(S)")
        return 1
    print("genconfig self-test: OK (keys, colour byte-pairs, comment skipping, "
          "the derived bank-0 layout and its wall, the rest-of-OS layout)")
    return 0


def main(argv):
    if "--self-test" in argv or "--selftest" in argv:
        return _selftest()
    if len(argv) != 2:
        print(__doc__.rstrip(), file=sys.stderr)
        return 2
    cfg, out = argv
    text = generate(open(cfg).read())
    # Write only on change: include/config.s is TRACKED and is an input to the
    # kernel edge, so an unconditional rewrite would both dirty the working tree
    # on every build and rebuild the kernel for nothing.
    try:
        if open(out).read() == text:
            return 0
    except FileNotFoundError:
        pass
    with open(out, "w") as f:
        f.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
