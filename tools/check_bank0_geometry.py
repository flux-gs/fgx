#!/usr/bin/env python3
"""check_bank0_geometry -- the bank-0 layout invariants.

Every task's hardware stack lives in bank 0 (the 65816's stack pointer is
16-bit), carved from FGX_STK_ARENA, with its user direct page as the first
page of its reservation.  Directly above the arena sits FGX_DP_KERNELC, the
page kernel C runs on, the last page below the $C000 I/O space; the kernel
images live in slots in the language card.  Nothing in bank 0 scales with
NPROC, and the constants are derived together or bank 0 corrupts.

memmap.s ERR-pins the ONE invariant Merlin32 can express (arena end ==
FGX_DP_KERNELC).  The others live here because the assembler cannot check
them:

  * THE CEILINGS.  The kernel-C page must be flush under the I/O space, the
    slot stacks and the interrupt context under the hardware vector table, the
    TCB table under FGX_CODE, and the per-pid tables long enough for NPROC.
    NPROC resolves through CFG_KERNEL_NPROC, and the nested-brace expressions
    that produces make Merlin32 give up ("can't be translated as a numeric
    expression") -- and the braces are not optional, because Merlin32
    evaluates strictly left-to-right with no operator precedence.  This is
    what makes exceeding a ceiling a build error instead of a boot-killing
    collision.

  * THE ALIASES.  The layout is now DERIVED from kernel.nproc, in
    tools/ninja/genconfig.py, and emitted into include/config.s; kernel.s, fs.s
    and stage2.s alias those names.  So this file no longer compares
    hand-synced copies -- there are none.  What it checks instead is that they
    are still aliases, because writing a literal back in restores the failure
    mode wholesale: a stage-2 constant that drifts kills the boot BEFORE any
    console exists (black screen, no diagnostic, every test failing
    identically), which is the single most expensive failure mode this repo
    has.

This file COMPUTES NOTHING.  genconfig.py derives, this validates the result
against the invariant chain, and neither trusts the other -- which is the only
reason the pair is worth having.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KERNEL_S = os.path.join(ROOT, "include", "kernel.s")
MEMMAP_S = os.path.join(ROOT, "include", "memmap.s")
TASK_S = os.path.join(ROOT, "src", "kernel", "task.s")
CONFIG_S = os.path.join(ROOT, "include", "config.s")

IO_BASE = 0xC000          # bank-0 I/O space; nothing may be placed at or above


def ds_bytes(path, name):
    """The byte count of a `<name> DS <literal>' reservation in an include."""
    with open(path) as f:
        for line in f:
            m = re.match(r"^" + re.escape(name) + r"\s+DS\s+(\$?[0-9A-Fa-f]+)\b", line)
            if m:
                tok = m.group(1)
                return int(tok[1:], 16) if tok.startswith("$") else int(tok)
    raise SystemExit(f"{path}: no `{name} DS <literal>' reservation")


def equ(path, name):
    """Read a LITERAL EQU.  An alias is a hard error, never a silent misread.

    The value pattern deliberately demands a complete token: `$1900` or `156`,
    and nothing else.  A loose `\\$?[0-9A-Fa-f]+` would happily read the first
    two characters of `CFG_STK_ARENA` as the hex number $CF and check the
    geometry of a machine that does not exist -- the exact silent-wrong-value
    failure this file is here to prevent.
    """
    with open(path, errors="replace") as f:
        m = re.search(rf"^\s*{name}\s+EQU\s+(\$[0-9A-Fa-f]+|\d+)(?=\s|;|$)",
                      f.read(), re.MULTILINE)
    if not m:
        raise SystemExit(
            f"check_bank0_geometry: cannot find a literal {name} in "
            f"{os.path.relpath(path, ROOT)} -- renamed, reformatted, or now an "
            f"alias. Fix this parser rather than dropping the check.")
    tok = m.group(1)
    return int(tok[1:], 16) if tok.startswith("$") else int(tok)


# The bank-0 layout is DERIVED from kernel.nproc into include/config.s
# (tools/ninja/genconfig.py), and every consumer aliases it.  These are the
# aliases that must remain aliases: re-literalising any one of them restores
# exactly the hand-sync that produced a rotted stage-2 claim table and the
# NPROC=12 collision with BLK_STAGE.  Merlin32 has no operator precedence and
# cannot do this arithmetic, which is why it happens in Python.
ALIASES = [
    ("include/kernel.s", "FGX_STK_KTASKS", "CFG_STK_KTASKS"),
    ("include/kernel.s", "FGX_STK_ARENA", "CFG_STK_ARENA"),
    ("include/kernel.s", "FGX_STK_ARENA_PAGES", "CFG_STK_ARENA_PAGES"),
    ("include/kernel.s", "FGX_DP_KERNELC", "CFG_DP_KERNELC"),
    ("include/kernel.s", "FGX_DP_KERNELC_IRQ", "CFG_DP_KERNELC_IRQ"),
    ("include/kernel.s", "FGX_STK_KIRQ", "CFG_STK_KIRQ"),
    ("include/kernel.s", "FGX_STK_SWITCH", "CFG_STK_SWITCH"),
    ("include/kernel.s", "FGX_KSLOT_DP", "CFG_KSLOT_DP"),
    ("include/kernel.s", "FGX_KSLOT_COUNT", "CFG_KERNEL_KSLOTS"),
    ("include/kernel.s", "FGX_KSLOT_STK", "CFG_KERNEL_KSTK"),
    ("include/kernel.s", "FGX_STK_BOOT", "CFG_STK_BOOT"),
    ("include/kernel.s", "FGX_KHOME_STRIDE", "CFG_KHOME_STRIDE"),
    ("include/fs.s", "BLK_STAGE", "CFG_BLK_STAGE"),
    # Stage 2 assembles standalone and cannot include kernel.s -- but it CAN
    # include the generated config, so its mirrors are aliases too.
    ("src/boot/stage2.s", "FGX_DP_KKERN", "CFG_DP_KKERN"),
    ("src/boot/stage2.s", "FGX_DP_KERNELC", "CFG_DP_KERNELC"),
    # The two Memory Manager claims and the rest-of-OS regions (rest.* and
    # kernel.banks in cfg/system.cfg).  stage2.s's copies of these drifted:
    # f0248a505 lowered the floor in kernel.s and not in stage2.s, and the
    # loader halted at 12 banks while the kernel documented 10.
    ("include/kernel.s", "KERNEL_BANKS", "CFG_KERNEL_BANKS"),
    ("include/kernel.s", "RESTOFOS_BANKS", "CFG_RESTOFOS_BANKS"),
    ("include/kernel.s", "RESTOFOS_MIN_BANKS", "CFG_RESTOFOS_MIN_BANKS"),
    ("include/kernel.s", "REST_CONSOLE_BANK_OFF", "CFG_REST_CONSOLE_BANK_OFF"),
    ("include/kernel.s", "REST_FONTS_BANK_OFF", "CFG_REST_FONTS_BANK_OFF"),
    ("include/kernel.s", "REST_KMOD_FIRST_OFF", "CFG_REST_KMOD_FIRST_OFF"),
    ("include/kernel.s", "REST_HEAP_FIRST_OFF", "CFG_REST_HEAP_FIRST_OFF"),
    ("include/kernel.s", "REST_USER_FIRST_OFF", "CFG_REST_USER_FIRST_OFF"),
    ("include/loader.s", "BANK_USER_COUNT", "CFG_REST_USER_BANKS"),
    ("src/boot/stage2.s", "KERNEL_BANKS", "CFG_KERNEL_BANKS"),
    ("src/boot/stage2.s", "RESTOFOS_BANKS", "CFG_RESTOFOS_BANKS"),
    ("src/boot/stage2.s", "RESTOFOS_MIN_BANKS", "CFG_RESTOFOS_MIN_BANKS"),
    ("src/boot/stage2.s", "REST_KMOD_FIRST_OFF", "CFG_REST_KMOD_FIRST_OFF"),
]

# Hand-written literal copies of a kernel.s constant in another assembly file.
# None remain: the last one sized stage 2's vestigial claim table, which is
# gone.  The check stays for the next one.
LITERAL_MIRRORS = []

# ...and so is genconfig's own copy, which is NOT an EQU at all -- it is a
# Python assignment, because genconfig DERIVES the layout and therefore has to
# know the per-task stack size before include/kernel.s is read.  It matters more
# than the stage-2 mirror does: the interrupt-time kernel-C context is placed
# immediately above the per-pid stacks, so a genconfig that thinks they are 256
# bytes each puts that page INSIDE them.  That is not hypothetical -- the
# ceiling test there did think 256, for as long as apple/fgx#172 has been
# landed, and only this file's independent rule caught the NPROCs it let past.
PY_MIRRORS = [
    ("tools/ninja/genconfig.py", "KSTK_SIZE", "include/kernel.s",
     "FGX_KSTK_SIZE"),
    # The scheduler's own stack: genconfig places it by its size at the top of
    # the mapped $D000 bank, and main.s paints and swtch resets S by the
    # kernel.s constant, so the two must agree or the stack's top and its
    # paint disagree about where it ends.
    ("tools/ninja/genconfig.py", "SWITCH_SIZE", "include/kernel.s",
     "FGX_STK_SWITCH_SIZE"),
]


def check_aliases(read):
    """`read(relpath)` -> text.  Returns a list of failure strings."""
    bad = []
    texts = {}
    for rel, name, cfg in ALIASES:
        if rel not in texts:
            texts[rel] = read(rel)
        if not re.search(rf"^\s*{name}\s+EQU\s+{cfg}\s*(;|$)", texts[rel],
                         re.MULTILINE):
            bad.append(
                f"{rel} no longer defines {name} as `EQU {cfg}`. The bank-0 "
                f"layout is derived from kernel.nproc in "
                f"tools/ninja/genconfig.py; a literal here re-creates the "
                f"hand-sync that shipped a rotted claim table and put two "
                f"kernel stacks on top of BLK_STAGE.")
    # Measured, not assumed (merlin32 v1.1.10): an alias to an undefined symbol
    # that is USED fails assembly outright, so a dropped PUT in stage2 is a loud
    # build error rather than a black-screen boot.  The check stays anyway,
    # because an alias that is defined and never used assembles in SILENCE --
    # and it names the cause directly instead of leaving someone to read a
    # Merlin error about a symbol they did not know was supposed to be there.
    for rel, name, src_rel, src_name in LITERAL_MIRRORS:
        for r in (rel, src_rel):
            if r not in texts:
                texts[r] = read(r)
        m = re.search(rf"^\s*{name}\s+EQU\s+(\S+)", texts[rel], re.MULTILINE)
        t = re.search(rf"^\s*{src_name}\s+EQU\s+(\S+)", texts[src_rel],
                      re.MULTILINE)
        if not m or not t:
            bad.append(f"{rel}:{name} or {src_rel}:{src_name} is missing -- "
                       f"the mirrored constant cannot be verified.")
        elif m.group(1) != t.group(1):
            bad.append(
                f"{rel} defines {name} = {m.group(1)} but {src_rel} defines "
                f"{src_name} = {t.group(1)}. Stage 2 cannot include kernel.s, "
                f"so this copy is hand-written -- and its claim table sizes "
                f"the whole per-pid stack region with it, so a disagreement "
                f"claims the wrong number of bytes for the block.")
    for rel, name, src_rel, src_name in PY_MIRRORS:
        for r in (rel, src_rel):
            if r not in texts:
                texts[r] = read(r)
        m = re.search(rf"^{name}\s*=\s*(\d+)", texts[rel], re.MULTILINE)
        t = re.search(rf"^\s*{src_name}\s+EQU\s+(\d+)", texts[src_rel],
                      re.MULTILINE)
        if not m or not t:
            bad.append(f"{rel}:{name} or {src_rel}:{src_name} is missing -- "
                       f"the mirrored constant cannot be verified.")
        elif int(m.group(1)) != int(t.group(1)):
            bad.append(
                f"{rel} sets {name} = {m.group(1)} but {src_rel} defines "
                f"{src_name} = {t.group(1)}. genconfig derives the layout, so "
                f"it has to know the per-task kernel stack size BEFORE "
                f"kernel.s is read -- and it places the interrupt-time "
                f"kernel-C context immediately above that block, so a stale "
                f"copy here puts a direct page inside the stacks.")
    s2 = texts.get("src/boot/stage2.s", "")
    if s2 and not re.search(r"^\s*PUT\s+\.\./\.\./include/config\.s", s2,
                            re.MULTILINE):
        bad.append(
            "src/boot/stage2.s aliases the CFG_ layout names but no longer "
            "PUTs ../../include/config.s -- restore the PUT. (Merlin32 will "
            "also fail on the undefined symbols, but only for the aliases that "
            "are actually used; an unused one assembles silently.)")
    return bad


def check(arena, pages, dp, nproc, sig=None, pid=None, dp_kernelc=None,
          kdp=None, kstk_size=512, kirq=None, switch=None, slots=None,
          alarm=None):
    """Return a list of failure strings.  Pure, so the self-test can drive it.

    `dp_kernelc` is the single kernel-C direct page below the pid-indexed
    block; when given, the arena is measured to IT and the two must be
    adjacent.  It is optional so the pre-kernel-C geometries below still
    validate -- the checker is not pinned to today's numbers.

    `slots` = (count, stack size, direct-page base, home stride) describes
    the kernel-image slots.  With it, the stack block at pid[0] is `count`
    stacks of `stack size` and the kernel DP block at `kdp` is the one
    template page; without it the block is (NPROC+1) stacks of `kstk_size`
    and (NPROC+1) pages, the per-pid arrangement.  `kstk_size` is the
    interrupt-time stack's size either way.
    """
    bad = []
    if slots is not None:
        n_stacks, stack_size = slots[0], slots[1]
    else:
        n_stacks, stack_size = nproc + 1, kstk_size
    arena_end = arena + pages * 256
    dp_bottom = dp if dp_kernelc is None else dp_kernelc
    if arena_end != dp_bottom:
        bad.append(
            f"arena ends at ${arena_end:04X} but the DP region starts at "
            f"${dp_bottom:04X} -- "
            f"{'overlap corrupts direct pages' if arena_end > dp_bottom else 'gap wastes bank 0'}")
    # The kernel-C page is charged to the arena and must sit IMMEDIATELY below
    # whatever is above it -- the pid-indexed block while there was one, the
    # I/O space now that user direct pages ride in their tasks' reservations.
    # A gap here is bank 0 that the arena no longer reaches, memmap.s's ERR
    # still passes on, and the pre-claim tables do not describe -- so the
    # Memory Manager would hand it out from under the direct page
    # fcc-compiled kernel code is running on.
    if dp is None:
        if dp_kernelc is not None and dp_kernelc + 256 != IO_BASE:
            bad.append(
                f"FGX_DP_KERNELC ${dp_kernelc:04X} + 256 != ${IO_BASE:04X} -- "
                f"with no per-pid direct-page block the kernel-C page must be "
                f"the last page below the I/O space, or the pages between are "
                f"claimed by nothing and the MM can allocate over them.")
    else:
        if dp_kernelc is not None and dp_kernelc + 256 != dp:
            bad.append(
                f"FGX_DP_KERNELC ${dp_kernelc:04X} + 256 != FGX_DP_KTASKS "
                f"${dp:04X} -- the kernel-C direct page must sit immediately "
                f"below the pid-indexed block, or the page between them is "
                f"claimed by nothing and the MM can allocate over it.")
        dp_top = dp + (nproc + 1) * 256
        if dp_top > IO_BASE:
            bad.append(
                f"DP block ${dp:04X}..${dp_top - 1:04X} (pids 0..{nproc}) runs "
                f"into I/O space at ${IO_BASE:04X}. NPROC={nproc} does not "
                f"fit: move FGX_DP_KTASKS down and shrink FGX_STK_ARENA_PAGES "
                f"by the same number of pages.")
    # The PER-PID SIGNAL TABLES must reach NPROC too.  This is the same class of
    # bug as the DP block above -- a table sized against NPROC that NPROC then
    # outgrew -- and it shipped: MASK/IGN were 32 B (8 tasks) while NPROC was 10.
    # Every access is base + (pid-1)*4, so pid 9's mask aliased pid 1's IGN word,
    # pid 10's aliased pid 2's, and both pids' IGN words fell PAST the end of the
    # Kmalloc'd block.  A pid-10 shell's SIGCHLD block-mask therefore lived in
    # the IGN word of the very slot the allocator hands its first child, and
    # Task_Alloc's per-pid scrub erased it mid-fork: SIGCHLD dispatched inside
    # the window tcsh blocks it for, and the shell hung at its first foreground
    # external command (apple/fgx#43).  Reachable only once a third console
    # pushed the login shell from pid 9 to pid 10.
    # THE PER-PID KERNEL STACKS -- the constraint that actually binds today, and
    # the one nothing was checking.  Address is pure arithmetic,
    # FGX_STK_KTASKS + (pid << 8), with no table and no bound (syscall.s,
    # task.s), so exceeding it does not fail: it silently lands on whatever is
    # next in bank 0.
    #
    # At NPROC=10 the block is $0C00..$16FF and BLK_STAGE is at $1700 -- EXACTLY
    # flush, zero margin.  NPROC=12 therefore put pids 11 and 12's kernel stacks
    # precisely on top of BLK_STAGE, the 512-byte buffer every SmartPort read
    # stages through: a disk block MVN'd over a live kernel stack, return
    # addresses included, and Task_PrimeKernStack zeroing an in-flight staged
    # block the other way.  That is why raising NPROC measured WORSE rather than
    # failing cleanly (apple/fgx#43).
    #
    # THE STACKS MOVED TO THE LANGUAGE CARD (2026-08-13).  They are no longer
    # in the low region at all, so the collision above is gone by construction:
    # the constraint is now the language-card ceiling, and the top of that
    # region is the hardware vector table.  BLK_STAGE and the arena did NOT
    # move -- relocating the arena base disturbs the B3 attribution tests,
    # which are coupled to first-fit allocation OUTCOMES and not merely to
    # addresses (docs/bank0-blkstage-relocation.md).
    #
    # pid 0 counts: the block is (NPROC+1) pages.
    if kdp is not None and pid:
        # The per-pid KERNEL direct pages grow UP into BLK_STAGE.  Same shape as
        # the kernel-stacks-vs-BLK_STAGE rule below, and kept for the same
        # reason: at NPROC=12 that one did not fail, it silently corrupted the
        # buffer every SmartPort read stages through (apple/fgx#43, #45).
        kdp_top = kdp + (256 if slots is not None else (nproc + 1) * 256)
        if kdp_top > pid[1]:
            bad.append(
                f"kernel DP block ${kdp:04X}..${kdp_top - 1:04X} runs into "
                f"BLK_STAGE at ${pid[1]:04X}.")
        if kdp < 0x0900:
            bad.append(
                f"kernel DP block starts at ${kdp:04X}, below $0900. "
                f"$0800-$08FF holds the relocated boot trampolines "
                f"(BlkTramp/CoutTramp), live for the lifetime of the system "
                f"-- see src/boot/loader.s.")

    if pid:
        kstk, blk_stage, tcb_tbl, tcb_size, code = pid
        # PER-TASK SIZE, READ RATHER THAN ASSUMED.  It was 256 and is 512 since
        # apple/fgx#172, and hardcoding it here would have let that change
        # double the region's true extent while this rule kept checking half of
        # it -- the exact shape of the NPROC=12 collision this file exists for.
        kstk_top = kstk + n_stacks * stack_size
        if kstk < 0xD000:
            bad.append(
                f"KERNEL stacks are at ${kstk:04X}, outside the "
                f"language card ($D000-$FFFF). If they are being moved back "
                f"into the low region, BLK_STAGE and the arena have to be "
                f"re-derived around them and the B3 taps re-proved.")
        elif kstk_top > 0xFFE0:
            bad.append(
                f"KERNEL stacks ${kstk:04X}..${kstk_top - 1:04X} "
                f"({n_stacks} of {stack_size} bytes) reach the hardware vector "
                f"table at $FFE0 -- the language card's flat 8 KB holds at most "
                f"{(0xFFE0 - kstk) // stack_size} of them, and the interrupt "
                f"context needs its share.")
        # THE INTERRUPT-TIME KERNEL-C CONTEXT sits immediately above the
        # per-pid stacks in the same flat 8 KB (apple/fgx#108 T6): one direct
        # page for fcc's $98..$FF, then one stack of kstk_size.
        #
        # ADJACENCY IS CHECKED, NOT JUST THE CEILING, and for the reason the
        # arena/FGX_DP_KERNELC pair is checked for equality rather than for
        # "no overlap": a GAP means genconfig and this file disagree about
        # where the stacks end, which is the disagreement that would put a
        # direct page inside them.  Either one fires.
        if kirq is not None:
            dp_irq, stk_irq = kirq
            if dp_irq != kstk_top:
                bad.append(
                    f"interrupt kernel-C DP is at ${dp_irq:04X} but the "
                    f"per-pid kernel stacks end at ${kstk_top:04X}. It is "
                    f"derived as the first page above them; a disagreement "
                    f"here means one of the two computations has the per-task "
                    f"stack size wrong.")
            if stk_irq != dp_irq + 256:
                bad.append(
                    f"interrupt kernel-C stack is at ${stk_irq:04X}, not one "
                    f"page above its direct page at ${dp_irq:04X}. The pair is "
                    f"one context and is derived as one block.")
            irq_top = stk_irq + kstk_size
            if irq_top > 0xFFE0:
                bad.append(
                    f"the interrupt kernel-C context "
                    f"${dp_irq:04X}..${irq_top - 1:04X} reaches the hardware "
                    f"vector table at $FFE0. NPROC={nproc} leaves no room "
                    f"above the per-pid stacks for it -- interrupt-time C is "
                    f"what runs ttyinput at arrival, and without its own page "
                    f"and stack it shares a task's.")

        if blk_stage + 0x200 != arena:
            bad.append(
                f"BLK_STAGE ${blk_stage:04X} + 512 != FGX_STK_ARENA "
                f"${arena:04X} -- the 512-byte staging buffer must sit "
                f"immediately below the arena, or one of them is overlapping "
                f"something unnamed.")
        tcb_top = tcb_tbl + nproc * tcb_size
        if tcb_top > code:
            bad.append(
                f"TCB table ${tcb_tbl:04X}..${tcb_top - 1:04X} ({nproc} slots "
                f"x {tcb_size} B) runs into FGX_CODE at ${code:04X}. "
                f"NPROC={nproc} does not fit: raise FGX_CODE (and its "
                f"lockstep list -- fgx.link.s ORG, stage2 KERNEL_DEST_LO, "
                f"verify_kernel).")
    # THE ALARM TABLES are kernel-data statics, four bytes and one byte a
    # task, indexed by pid with no bound: a table shorter than NPROC is
    # written past its end by the highest pids.  `alarm` = (bytes of
    # _kAlarmTicks, bytes of _kAlarmFired), read from include/memmap.s.
    if alarm is not None:
        ticks, fired = alarm
        if ticks < nproc * 4:
            bad.append(
                f"_kAlarmTicks is {ticks} bytes but NPROC={nproc} needs "
                f"{nproc * 4}: the highest pids' alarms land past its end "
                f"(include/memmap.s).")
        if fired < nproc:
            bad.append(
                f"_kAlarmFired is {fired} bytes but NPROC={nproc} needs "
                f"{nproc}: the highest pids' flags land past its end "
                f"(include/memmap.s).")

    if sig:
        mask_off, ign_off, blk = sig[:3]
        if mask_off < nproc * 2:
            bad.append(
                f"SIGHND_ENTRY table holds {mask_off // 2} tasks (two bytes "
                f"each, up to SIGHND_MASK_OFF) but NPROC={nproc}: pid "
                f"{mask_off // 2 + 1}'s entry aliases the MASK table.")
        if len(sig) > 3 and sig[3] + nproc * 4 > blk:
            bad.append(
                f"SIGHND_CATCH table at {sig[3]} needs {sig[3] + nproc * 4} "
                f"bytes for NPROC={nproc} but SIGHND_BLK_SIZE is {blk}.")
        need = ign_off + nproc * 4
        if ign_off - mask_off < nproc * 4:
            bad.append(
                f"SIGHND_MASK table holds {(ign_off - mask_off) // 4} tasks but "
                f"NPROC={nproc}: pid {(ign_off - mask_off) // 4 + 1}'s mask "
                f"aliases the IGN table. Grow SIGHND_IGN_OFF and "
                f"SIGHND_BLK_SIZE together (include/memmap.s).")
        if need > blk:
            bad.append(
                f"SIGHND_IGN table needs {need} bytes for NPROC={nproc} but "
                f"SIGHND_BLK_SIZE is {blk}: pid {nproc} writes past the end of "
                f"the block and corrupts the next kernel-heap object. Grow "
                f"SIGHND_BLK_SIZE (include/memmap.s).")

    # THE SCHEDULER'S OWN STACK: the top of the mapped $D000 language-card
    # bank.  swtch stands on it from @sw_pick to the resume TCS, so it has to
    # be RAM that _LC_MapRam keeps mapped, and it must not share a byte with
    # the per-pid stacks -- not pushing on a task's stack is the whole reason
    # it exists.
    if switch is not None:
        sw_base, sw_size = switch
        sw_top = sw_base + sw_size
        if sw_base < 0xD000 or sw_top > 0xE000:
            bad.append(
                f"the scheduler's switch stack ${sw_base:04X}..${sw_top - 1:04X} "
                f"is not inside the mapped $D000 bank ($D000-$DFFF) of the "
                f"language card. It has to be RAM _LC_MapRam keeps mapped, and "
                f"the flat 8 KB above $E000 belongs to the per-pid stacks and "
                f"the interrupt-time context.")
        if pid:
            kstk_lo = pid[0]
            kstk_hi = kstk_lo + n_stacks * stack_size
            if sw_base < kstk_hi and kstk_lo < sw_top:
                bad.append(
                    f"the scheduler's switch stack "
                    f"${sw_base:04X}..${sw_top - 1:04X} overlaps the "
                    f"kernel stacks ${kstk_lo:04X}..${kstk_hi - 1:04X}: swtch "
                    f"would be pushing on a task's stack, which is what it "
                    f"exists not to do.")

    # THE KERNEL-IMAGE SLOTS.  Their direct pages live in the mapped $D000
    # bank below the scheduler's stack, and a parked image -- the page plus up
    # to a whole stack -- must fit its home stride, NPROC of which fill one
    # bank.  The stacks themselves are checked above as the kernel stack
    # block.
    if slots is not None:
        n_slots, slot_stk, slot_dp, home = slots
        if n_slots < 1:
            bad.append("no kernel-image slots: the running task is always "
                       "bound to one, so there must be at least one.")
        if slot_stk < kstk_size or slot_stk & 1:
            bad.append(
                f"a slot stack of {slot_stk} bytes is shallower than the "
                f"interrupt-time stack ({kstk_size}) or odd; the paint is "
                f"written two bytes at a time.")
        dp_top = slot_dp + n_slots * 256
        dp_ceiling = switch[0] if switch is not None else 0xE000
        if slot_dp < 0xD000 or dp_top > dp_ceiling:
            bad.append(
                f"the slot direct pages ${slot_dp:04X}..${dp_top - 1:04X} are "
                f"not inside the mapped $D000 bank below "
                f"${dp_ceiling:04X}: a slot's page has to be RAM _LC_MapRam "
                f"keeps mapped, and the scheduler's stack sits at the top of "
                f"that bank.")
        if 256 + slot_stk > home:
            bad.append(
                f"a parked kernel image is a page plus up to {slot_stk} bytes "
                f"of stack, more than the {home}-byte home stride.")
        if nproc * home > 0x10000:
            bad.append(
                f"NPROC={nproc} home images of {home} bytes do not fit one "
                f"bank; the kernel keeps every parked kernel image in a "
                f"single Bank_Alloc bank.")
    return bad


def _selftest():
    fails = []
    # The shipping geometry must be clean.
    if check(0x3200, 133, 0xB700, 8):
        fails.append("the real geometry was reported as broken")
    # Each invariant must be caught independently.
    if not check(0x3200, 134, 0xB700, 8):
        fails.append("arena/DP overlap not caught")
    if not check(0x3200, 132, 0xB700, 8):
        fails.append("arena/DP gap not caught")
    if not check(0x3200, 133, 0xB700, 12):
        fails.append("NPROC overflowing into I/O space not caught")
    # The signal tables: today's sizing is clean, and the shipped-broken sizing
    # (32 B tables with NPROC=10) must be caught on BOTH arms independently.
    if check(0x3200, 133, 0xB700, 8, (160, 224, 288)):
        fails.append("the real signal-table sizing was reported as broken")
    # The per-pid geometry.  PID = (kstack, BLK_STAGE, TCB tbl, TCB size, CODE).
    SHIP = (0xE000, 0x1700, 0x0800, 64, 0x0B00)
    if check(0x1900, 156, 0xB500, 10, (160, 224, 288), SHIP):
        fails.append("the shipping per-pid geometry was reported as broken")
    # THE KERNEL-C DIRECT PAGE.  Today's shipping layout is NPROC=11 with the
    # page at $B300 and the arena measured to it, not to the pid block.
    SHIP11 = (0xE000, 0x1800, 0x0800, 64, 0x0B00)
    if check(0x1A00, 153, 0xB400, 11, (160, 224, 288), SHIP11, 0xB300):
        fails.append("the shipping kernel-C geometry was reported as broken")
    # Measuring the arena to the pid block instead of to the kernel-C page --
    # i.e. forgetting to charge the page to the arena -- overlaps them.
    if not check(0x1A00, 154, 0xB400, 11, (160, 224, 288), SHIP11, 0xB300):
        fails.append("an arena still measured to FGX_DP_KTASKS was not caught")
    # A GAP between the kernel-C page and the pid block: the arena ends where
    # it should and memmap.s's ERR passes, but a page is left claimed by
    # nothing.  This is the arm that ERR cannot express.
    if not check(0x1A00, 152, 0xB400, 11, (160, 224, 288), SHIP11, 0xB200):
        fails.append("a gap between the kernel-C page and the DP block was not "
                     "caught -- memmap.s's ERR passes on this one")
    # NPROC=12 is the configuration that silently corrupted BLK_STAGE.  It is
    # now unreachable through cfg/system.cfg -- genconfig.py derives BLK_STAGE
    # from NPROC, so the two cannot drift -- but the check stays: it is what
    # catches anyone re-literalising the layout, and it is the one arm that
    # reproduces a bug that actually shipped.
    # RE-AIMED 2026-08-13: the stacks live in the language card now, so the
    # thing they can overrun is the hardware vector table at $FFE0, not
    # BLK_STAGE.  The shape is the same one that shipped corruption at
    # apple/fgx#43 -- a task count grown without the block that bounds it.
    if not check(0x1900, 154, 0xB300, 12, (160, 224, 288),
                 (0xFF00, 0x1800, 0x0800, 64, 0x0B00)):
        fails.append("kernel stacks running into the hardware vector table "
                     "not caught -- the shape that shipped memory corruption")
    # And a stack block that has wandered OUT of the language card entirely.
    if not check(0x1900, 154, 0xB300, 10, (160, 224, 288),
                 (0x0C00, 0x1800, 0x0800, 64, 0x0B00)):
        fails.append("kernel stacks outside the language card not caught")
    if not check(0x1900, 156, 0xB500, 13, (160, 224, 288),
                 (0x0C00, 0x1D00, 0x0800, 64, 0x0B00)):
        fails.append("TCB table overrunning FGX_CODE not caught")
    # The alarm statics: tables sized for sixteen with NPROC past them, the
    # signal block sized correctly so only the alarm rule can fire.
    if not check(0x1900, 156, 0xB500, 17, (64, 192, 448, 320),
                 (0x0C00, 0x2100, 0x0800, 64, 0x1000), alarm=(64, 16)):
        fails.append("alarm tables short of NPROC not caught")
    # The catch table: the block ends where it must begin plus NPROC words.
    if not check(0x3200, 133, 0xB700, 10, (160, 224, 288, 260)):
        fails.append("CATCH overrunning SIGHND_BLK_SIZE not caught")
    if not check(0x3200, 133, 0xB700, 10, (160, 192, 224)):
        fails.append("the shipped NPROC=10-vs-8-task signal tables not caught")
    if not check(0x3200, 133, 0xB700, 10, (160, 224, 224)):
        fails.append("IGN overrunning SIGHND_BLK_SIZE not caught")
    # THE INTERRUPT-TIME KERNEL-C CONTEXT (apple/fgx#108 T6).  Today's shipping
    # numbers: stacks $E000 + 13*512 -> $FA00, then the DP page, then a stack.
    SHIP12 = (0xE000, 0x1800, 0x0800, 64, 0x0B00)
    if check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200, 0x0900,
             512, (0xFA00, 0xFB00)):
        fails.append("the shipping IRQ kernel-C context was reported as broken")
    # A DP page that is not the first page above the stacks -- the shape a
    # genconfig with the wrong per-task stack size produces, and the reason the
    # rule checks adjacency rather than mere non-overlap.
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xED00, 0xEE00)):
        fails.append("an IRQ kernel-C DP inside the per-pid kernel stacks was "
                     "not caught")
    # The stack not immediately above its own page: the pair is one context.
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xFA00, 0xFC00)):
        fails.append("an IRQ kernel-C stack detached from its direct page was "
                     "not caught")
    # ...and the ceiling, which is the hardware vector table.
    if not check(0x1A00, 151, 0xB200, 13, (160, 224, 288),
                 (0xE000, 0x1800, 0x0800, 64, 0x0B00), 0xB100, 0x0900,
                 512, (0xFC00, 0xFE00)):
        fails.append("an IRQ kernel-C context reaching the vector table was "
                     "not caught")
    # THE SCHEDULER'S OWN STACK: the top 512 bytes of the mapped $D000 bank.
    if check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200, 0x0900,
             512, (0xFA00, 0xFB00), (0xDE00, 512)):
        fails.append("the shipping switch stack was reported as broken")
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xFA00, 0xFB00), (0xDF00, 512)):
        fails.append("a switch stack crossing into the flat 8 KB was not "
                     "caught")
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xFA00, 0xFB00), (0xCE00, 512)):
        fails.append("a switch stack outside the language card was not caught")
    # ...and a per-pid stack block that has moved down onto it.  Only the
    # overlap rule fires for this geometry: the block is inside the card and
    # under the vector table, and there is no interrupt context to check.
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288),
                 (0xD800, 0x1800, 0x0800, 64, 0x0B00), 0xB200, 0x0900, 512,
                 None, (0xDE00, 512)):
        fails.append("a switch stack under the per-pid kernel stacks was not "
                     "caught")
    # THE KERNEL-IMAGE SLOTS: six stacks of 1,216 from $E000, the interrupt
    # context above them at $FC80, pages at $D000, 2 KB home images.
    SLOTS = (6, 1216, 0xD000, 2048)
    if check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200, 0x0900,
             512, (0xFC80, 0xFD80), (0xDE00, 512), SLOTS):
        fails.append("the shipping slot geometry was reported as broken")
    # THE USER DIRECT PAGE RIDES WITH THE STACK: no per-pid block, the
    # kernel-C page flush under the I/O space, the arena up to it.
    if check(0x1A00, 165, None, 12, (160, 224, 288), SHIP12, 0xBF00, 0x0900,
             512, (0xFC80, 0xFD80), (0xDE00, 512), SLOTS):
        fails.append("the shipping geometry with no DP block was reported as "
                     "broken")
    if not check(0x1A00, 164, None, 12, (160, 224, 288), SHIP12, 0xBE00,
                 0x0900, 512, (0xFC80, 0xFD80), (0xDE00, 512), SLOTS):
        fails.append("a kernel-C page not flush under the I/O space was not "
                     "caught -- the page between is claimed by nothing")
    # A seventh slot pushes the interrupt context into the vector table.
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xFE40, 0xFF40), (0xDE00, 512),
                 (7, 1216, 0xD000, 2048)):
        fails.append("seven slots reaching the vector table were not caught")
    # An interrupt context left where the per-pid layout had it is no longer
    # adjacent to the stacks.
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xFA00, 0xFB00), (0xDE00, 512), SLOTS):
        fails.append("an interrupt context inside the slot stacks was not "
                     "caught")
    # Pages that run into the scheduler's stack.
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xFC80, 0xFD80), (0xDE00, 512),
                 (6, 1216, 0xDD00, 2048)):
        fails.append("slot pages running into the switch stack were not "
                     "caught")
    # A home stride too small for the image, and too many images for a bank.
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xFC80, 0xFD80), (0xDE00, 512),
                 (6, 1216, 0xD000, 1024)):
        fails.append("a home stride smaller than a kernel image was not "
                     "caught")
    if not check(0x1A00, 152, 0xB300, 12, (160, 224, 288), SHIP12, 0xB200,
                 0x0900, 512, (0xFC80, 0xFD80), (0xDE00, 512),
                 (6, 1216, 0xD000, 8192)):
        fails.append("home images overflowing their bank were not caught")

    # The pre-B1 geometry must also validate, so the checker is not just pinned
    # to today's numbers.
    if check(0x3200, 126, 0xB000, 8):
        fails.append("the pre-B1 geometry ($B000/126) was reported as broken")

    # THE ALIAS GUARD.  It replaced the numeric stage-2 mirror comparison: the
    # mirrors cannot drift now, because they are not copies.  What CAN happen is
    # someone writing a literal back in, which silently restores the old failure
    # mode -- so that is what is checked, on synthetic text.
    REAL = {
        "include/kernel.s": "\n".join(
            f"{n:<20} EQU     {c}" for _, n, c in ALIASES
            if _ == "include/kernel.s")
        + "\nFGX_KSTK_SIZE   EQU     512\nFGX_STK_SWITCH_SIZE EQU 512",
        "include/fs.s": "BLK_STAGE       EQU     CFG_BLK_STAGE   ; comment",
        "include/loader.s": "BANK_USER_COUNT EQU     CFG_REST_USER_BANKS ; c",
        "src/boot/stage2.s": "                PUT     ../../include/config.s\n"
        + "\n".join(f"{n:<20} EQU {c}" for _, n, c in ALIASES
                    if _ == "src/boot/stage2.s"),
        "tools/ninja/genconfig.py": "KSTK_SIZE = 512\nSWITCH_SIZE = 512",
    }
    if check_aliases(lambda rel: REAL[rel]):
        fails.append("correctly aliased sources were reported as literals")
    # genconfig's Python copy must be caught when it DISAGREES -- the load-bearing
    # mirror now, because the interrupt-time kernel-C context is DERIVED from
    # the top of the per-pid stack block.  256 here does not merely misreport a
    # ceiling: it puts a direct page inside the stacks.
    DRIFTED_PY = dict(REAL)
    DRIFTED_PY["tools/ninja/genconfig.py"] = "KSTK_SIZE = 256\nSWITCH_SIZE = 512"
    if not check_aliases(lambda rel: DRIFTED_PY[rel]):
        fails.append("a genconfig KSTK_SIZE that disagrees with kernel.s was "
                     "not caught -- it would place the IRQ context inside the "
                     "per-pid kernel stacks")
    # The same for the switch stack's size: genconfig places the stack by it
    # and main.s paints and swtch resets S by the kernel.s constant.
    DRIFTED_SW = dict(REAL)
    DRIFTED_SW["tools/ninja/genconfig.py"] = "KSTK_SIZE = 512\nSWITCH_SIZE = 256"
    if not check_aliases(lambda rel: DRIFTED_SW[rel]):
        fails.append("a genconfig SWITCH_SIZE that disagrees with kernel.s was "
                     "not caught -- the placed stack and the painted one would "
                     "end in different places")
    broken = dict(REAL)
    broken["include/fs.s"] = "BLK_STAGE       EQU     $1700"
    if not check_aliases(lambda rel: broken[rel]):
        fails.append("a re-literalised BLK_STAGE was not caught -- this is the "
                     "constant NPROC=12 failed to move")
    noput = dict(REAL)
    noput["src/boot/stage2.s"] = REAL["src/boot/stage2.s"].replace(
        "                PUT     ../../include/config.s\n", "")
    if not check_aliases(lambda rel: noput[rel]):
        fails.append("stage2 aliasing CFG_ names it never includes was not "
                     "caught -- those symbols would resolve to nothing")
    if fails:
        for f in fails:
            print(f"  {f}", file=sys.stderr)
        print(f"check_bank0_geometry self-test: {len(fails)} FAILURE(S)")
        return 1
    print("check_bank0_geometry self-test: OK "
          "(catches arena/DP overlap and gap, an uncharged or detached "
          "kernel-C direct page, one not flush under the I/O space, "
          "DP-vs-I/O, signal-table aliasing and "
          "overrun, kernel-stacks-vs-BLK_STAGE, TCB-vs-FGX_CODE, alarm tables "
          "short of NPROC, a catch table past its block, a switch stack "
          "outside the mapped $D000 bank or "
          "under the kernel stacks, slot stacks reaching the vector table, "
          "slot pages running into the switch stack, a home stride too small "
          "or a bank too full of home images, a re-literalised layout "
          "constant, and stage2 aliasing a config it does not include)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return _selftest()

    # THE LAYOUT IS READ WHERE IT IS DERIVED.  kernel.s, fs.s and stage2.s all
    # alias these, so reading it from any of them would just be reading the same
    # number by a longer route -- and equ() refuses to parse an alias anyway.
    # What keeps that honest is check_aliases(), below.
    nproc = equ(CONFIG_S, "CFG_KERNEL_NPROC")
    kstk_size = equ(KERNEL_S, "FGX_KSTK_SIZE")
    arena = equ(CONFIG_S, "CFG_STK_ARENA")
    pages = equ(CONFIG_S, "CFG_STK_ARENA_PAGES")
    dp = None                   # no per-pid direct-page block: see check()
    dp_kernelc = equ(CONFIG_S, "CFG_DP_KERNELC")
    sig = (equ(MEMMAP_S, "SIGHND_MASK_OFF"),
           equ(MEMMAP_S, "SIGHND_IGN_OFF"),
           equ(MEMMAP_S, "SIGHND_BLK_SIZE"),
           equ(MEMMAP_S, "SIGHND_CATCH_OFF"))
    alarm = (ds_bytes(MEMMAP_S, "_kAlarmTicks"), ds_bytes(MEMMAP_S, "_kAlarmFired"))

    # TCB_SIZE is computed (EQU *) so it cannot be read as a literal; 64 is
    # pinned by the DS 32-{*} pad in include/kernel.s, which ERRs if the fields
    # exceed it, and by SE_SIZE == TCB_SIZE/2 (the seoff is a shift).
    pid = (equ(CONFIG_S, "CFG_STK_KTASKS"), equ(CONFIG_S, "CFG_BLK_STAGE"),
           equ(TASK_S, "FGX_TASK_TBL_OFF"), 64,
           equ(KERNEL_S, "FGX_CODE") & 0xFFFF)
    kdp = equ(CONFIG_S, "CFG_DP_KKERN")
    kirq = (equ(CONFIG_S, "CFG_DP_KERNELC_IRQ"), equ(CONFIG_S, "CFG_STK_KIRQ"))
    switch = (equ(CONFIG_S, "CFG_STK_SWITCH"),
              equ(KERNEL_S, "FGX_STK_SWITCH_SIZE"))
    slots = (equ(CONFIG_S, "CFG_KERNEL_KSLOTS"), equ(CONFIG_S, "CFG_KERNEL_KSTK"),
             equ(CONFIG_S, "CFG_KSLOT_DP"), equ(CONFIG_S, "CFG_KHOME_STRIDE"))
    bad = check(arena, pages, dp, nproc, sig, pid, dp_kernelc, kdp,
                kstk_size, kirq, switch, slots, alarm=alarm)
    bad += check_aliases(
        lambda rel: open(os.path.join(ROOT, rel), errors="replace").read())
    if bad:
        print("check_bank0_geometry: BANK-0 GEOMETRY BROKEN:", file=sys.stderr)
        for b in bad:
            print(f"  {b}", file=sys.stderr)
        return 1

    print(f"    bank0 geometry OK: arena ${arena:04X}+{pages}p -> "
          f"${dp_kernelc:04X}, kernel-C DP ${dp_kernelc:04X} under I/O, "
          f"user DPs in their reservations, "
          f"{slots[0]} kernel slots of {slots[1]} B at ${pid[0]:04X} with "
          f"pages at ${slots[2]:04X}, "
          f"IRQ kernel-C DP ${kirq[0]:04X} stack ${kirq[1]:04X}"
          f"..${kirq[1] + kstk_size - 1:04X}, switch stack ${switch[0]:04X}"
          f"..${switch[0] + switch[1] - 1:04X}")
    return 0


if __name__ == "__main__":
    # sys.exit: main() RETURNS its status, and a check that cannot fail the
    # build is exactly the defect it exists to catch.
    sys.exit(main() or 0)
