#!/usr/bin/env python3
"""check_stack_budget -- what the bank-0 arena holds at once, and what cannot.

WHY THIS EXISTS.  Every task's hardware stack must live in bank 0 (the 65816's
stack pointer is 16-bit), carved from ONE fixed region, FGX_STK_ARENA, as a
STATIC WORST-CASE RESERVATION.  A reservation is a residency footprint now,
not a lifetime cost: when the arena has no free run, the kernel lays a new
range over parked sleepers (kernel.stkover, task.s Uimg_*), so a scenario past
the arena parks rather than fails, and this check reports it as a NOTE.  What
still fails the build is a binary that cannot fit the arena ALONE, and a
ttys/NPROC pair that stalls a login.  Over-subscribing used to surface as
`stk ENOMEM <n>p` and a useless "Cannot allocate memory" from the shell, and
did TWICE in production:

  2026-07-27 (1aa865c44): arena grown 112 -> 126 to fit bsh + tcsh + tar.
  2026-07-28 (39adfaeeb): TASK_STACK_MAX_PAGES 56 -> 83 so tcsh fit unclamped --
                          its budget note checked tcsh + bsh + elvis but not
                          tar, the exact workload the grow existed for.  Broke
                          the next day.

Both were hand-checked invariants.  This is the check whose absence let the
second one land: the linker already writes every binary's page count into its
FGX2/FGX3 header, so the budget is a sum and a compare.

THREE THINGS THIS GETS RIGHT THAT HAND SUMS KEPT MISSING:

  1. THE GUARD PAGE, AND THE DIRECT PAGE.  Task_AllocStack allocates N+1
     pages of stack -- an INC before STA _tas_npages -- and one more below
     them for the task's direct page, so every co-resident task costs two
     more pages than its header says.  With guards counted, "2 x tcsh + tar"
     was 129, not 126: DEAD, not "exactly at the ceiling".

  2. THE CLAMP.  Task_AllocStack normalizes 0 -> 1 and clamps to
     TASK_STACK_MAX_PAGES.  A binary whose model wants more is SIZED TO A FLOOR,
     not a fit, so the budget must use the clamped number the kernel will
     actually allocate.

  3. THE MAGIC.  A header sweep MUST verify FGX2/FGX3 before trusting byte 14.
     disk_src/bin/hd is a 419-byte jsh script whose byte 14 is ASCII 'P' from its
     SPDX line -- it read as an 80-page stack and corrupted a budget by itself.

WHAT IT CANNOT CATCH: fragmentation.  This checks SUMS, not PLACEMENTS.  The
arena can never be compacted (fcc frames hold absolute bank-0 addresses, so
stacks cannot be relocated), and long-lived sessions ending in arbitrary order
will eventually ENOMEM with enough free pages.  Containment for that is
two-ended first-fit in Task_AllocStack, not this file.

EXEC TRANSIENTS need no special mechanism: a scenario is "the set of stacks
allocated at the same instant", and execve holds the OLD allocation while the
NEW one is carved (process.s:1494).  So an exec transient is modelled by listing
BOTH binaries in the scenario.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KERNEL_S = os.path.join(ROOT, "include", "kernel.s")
# The bank-0 layout is DERIVED from kernel.nproc into config.s
# (tools/ninja/genconfig.py); kernel.s only aliases it.
CONFIG_S = os.path.join(ROOT, "include", "config.s")
TASK_S = os.path.join(ROOT, "src", "kernel", "task.s")
STAGE_DIRS = ["disk_src/bin", "disk_src/sbin", "disk_src/testbin"]

MAGICS = (b"FGX2", b"FGX3")
STACK_HINT_OFF = 14        # toolchain/src/ld/fgx_ld.py STACK_HINT_OFF

# The kernel adds ceil((argv+envp bytes)/256) pages BEFORE the guard
# (process.s:239-263, #45) -- the frame the loader lays on top of the C stack,
# which the linker's hint never sees.  pages_for() does not model it; that is
# known under-count 2 in this file's header, and it understates every scenario
# equally, so the arena totals stay useful.
#
# The LANE FIT check cannot tolerate it, because there the model is compared
# against a hard kernel refusal.  MEASURED: tcsh's hint is 74, pages_for() says
# 75, and the kernel asks for 76 (`stk ENOMEM 76p`).  A lane of 75 would pass
# this check and ENOMEM every tcsh spawn -- green build, dead machine.  So the
# fit check charges this floor on top.  It IS a floor: a large environment costs
# more than one page, so this is conservative in the right direction.
# The argv/envp frame, in pages.  A FLOOR: see pages_for().  This replaced
# LANE_ARGV_FLOOR, which charged the frame ONLY on the lane path -- so the lane
# was priced correctly while every ordinary task was a page short.  Charging it
# in pages_for() covers both, and keeping the old constant as well would now
# double-count the members.
ARGV_FRAME_PAGES = 1

# Co-resident scenarios.  Each is the set of tasks whose stacks are allocated
# SIMULTANEOUSLY.
#
# Add a scenario when a new co-residency becomes real -- that is the point of
# the file.  A scenario for a co-residency that CANNOT occur is worse than no
# scenario: it inflates the worst case and buys false confidence.
#
# TWO UNDER-COUNTS, FIXED 2026-08-07 (apple/fgx#30).  Both understated every
# sum here, and both are corrected now; the descriptions stay because the first
# of them had already been re-derived three times:
#
#   1. init IS IN THE ARENA.  The note that used to sit here said init keeps a
#      static $3100 page outside the arena.  That has been FALSE since
#      2026-07-31 (arena B1b, 05dbe46e8): see include/kernel.s -- "init does NOT
#      keep a static page.  It calls Task_AllocStack like every other task" --
#      and main.s:549, "the hardcoded one-page $3100 stack predates C init".
#      init is pid 1 and permanently resident, so it costs ~3 pages (1 from its
#      0 hint, 1 argv-frame page, 1 guard) that no sum below includes.
#
#   2. THE ARGV/ENVP FRAME.  The kernel allocates hint + ceil(argv_frame/256)
#      + guard (process.s:239-263 for spawn, main.s:546-568 for init); #45 added
#      the middle term because the linker's hint never sees the frame the loader
#      lays on TOP of the C stack.  pages_for() models only hint + guard, so
#      EVERY task here is short at least one page, and more with a large env.
#
# They were fixed TOGETHER, because correcting either alone would have swapped
# one wrong number for another.  init is now charged to every scenario in the
# summation loop (not written into each list, where a new scenario could forget
# it), and pages_for() carries the argv-frame term.  The corrected model was
# validated against the RUNNING machine rather than only against the source:
# init 3, ps 3, getty 3, sh 16, ls 4 pages, each matching the ps STK column.
# The old model said
# 2/2/2/15/3 -- one page short, every time.
SCENARIOS = {
    "tcsh runs tar":
        # The exact 2026-07-31 breakage: tar under an interactive tcsh.
        ["tcsh", "tar"],
    "tcsh runs tar, launched from sh":
        # bsh is the login shell, so it stays resident under an interactive tcsh.
        ["sh", "tcsh", "tar"],
    "tcsh runs vi":
        # RE-WIDENED 2026-08-06 to the three-deep form, because the condition
        # the 2026-08-05 narrowing named has now happened and resolved the OTHER
        # way.  That narrowing dropped bsh on the reasoning that once the ttyv
        # lines went `on`, login would EXEC the session shell and leave no bsh
        # underneath -- true for the VC lines, but the CONSOLE line still runs
        # `/bin/sh` DIRECTLY (disk_src/etc/ttys), with no getty and no login.
        # So a tcsh session on ttyv1 sits beside the console's bsh, and all
        # three stacks are live at once.  MEASURED on the shipped config: the
        # task table holds init 3 + console sh + tcsh + login simultaneously.
        #
        # It fits now where it did not then: sh 14 + tcsh 83 + vi 22 = 119 of
        # 147, against sh 15 + tcsh 84 + vi 52 = 151 of 149 when it was
        # narrowed.  vi came down 51 -> 22 pages (four BLK locals made static,
        # src/userland/elvis/), which is what bought the room.
        ["sh", "tcsh", "vi"],
    "four-stage pipeline under tcsh":
        # Pipelines are the sharper driver: every stage is a co-resident task,
        # and this is Unix's bread and butter, not an exotic case.
        ["sh", "tcsh", "grep", "sed", "uniq", "wc"],
    "deepest tool in a pipeline under tcsh":
        ["sh", "tcsh", "tar", "grep"],

    # --- Slice C, the login chain (2026-08-04; SHIPPED CONFIG UPDATED
    # 2026-08-07).  The console line is `console /bin/sh ... on secure`, which
    # init spawns as /bin/sh DIRECTLY, with no getty and no login in between.
    # ttyp0/ttyp1 stay `off` because init never starts a getty on a pty.
    #
    # ttyv1 AND ttyv2 are now `on` (apple/fgx#43), so three-console
    # co-residency IS the shipped configuration and IS modelled -- see the
    # combined scenario at the end.  The note that used to sit here said the
    # opposite and outlived the config by one commit.
    #
    # The getty -> login -> shell chain is real all the same: logintest drives
    # it on /dev/ttyp0 from the pty master, which is the only way it runs today
    # and the exact shape init will use when the ttyv* lines go `on`.  Both
    # links are EXECs, so the peak is the exec transient -- process.s:1494 holds
    # the old allocation while the new one is carved -- not the four-deep chain.
    # The console /bin/sh that started the test stays resident throughout.
    "console shell runs halt":
        # /sbin/halt is the shutdown path now: `exit` on the console just gets
        # a fresh shell, because init respawns the line.
        ["sh", "halt"],
    "getty execs login on a pty":
        ["sh", "logintest", "getty", "login"],
    "login execs the session shell on a pty":
        ["sh", "logintest", "login", "sh"],
    "passwd inside a pty login session":
        ["sh", "logintest", "sh", "passwd"],

    # --- B3.4 (2026-08-07): the three-console case the campaign exists for.
    # Only reachable because lane members SHARE the lane: three tcsh sessions
    # cost 78 pages between them, not 3 x 78.  Without B3 this scenario is
    # 3 + 15 + 76 + 76 + 76 = 246 of 156 and cannot be made to fit by any
    # amount of shrinking.
    "three tcsh sessions, one running vi":
        ["sh", "tcsh", "tcsh", "tcsh", "vi"],
    "three tcsh sessions, one deep in a pipeline":
        ["sh", "tcsh", "tcsh", "tcsh", "tar", "grep"],

    # --- THE SHIPPED WORST CASE (2026-08-07).  Three consoles AND a pty login
    # chain at the same time -- which is exactly the apple/fgx#43 workload, and
    # since ttyv2 went `on` it is the default configuration rather than a
    # contrived one.  Modelling the two halves separately was optimistic: the
    # old maximum was the larger of them, and nothing said they could not
    # coincide.  They can, and logintest makes them.
    "three consoles with a pty login running passwd":
        ["sh", "tcsh", "tcsh", "tcsh", "logintest", "sh", "passwd"],
}


# ---------------------------------------------------------------------------
# /etc/ttys AND kernel.nproc MUST AGREE.
#
# Turning a console `on` costs process slots -- a permanent getty, the session
# shell it execs, and the login chain transient on top.  apple/fgx#43 is that
# bill going unpaid: with three lines on and NPROC=10, a pty login reached
# passwd(1) and the console said `No more processes.`  It presented as a login
# stall and cost two wrong diagnoses before anyone counted slots.
#
# Nothing connected the two files, and raising NPROC is now a ONE-LINE change
# (apple/fgx#45) -- which cuts both ways: it is equally one line to lower it and
# re-create #43 with every build check still green.  So the relation is
# asserted here.
#
# THESE ARE MEASURED FLOORS, NOT A DERIVATION.  Each was established by running
# the pty login test at that configuration and finding the smallest NPROC that
# completes it; there is no clean formula, because the chain's peak depends on
# which execs overlap.  Add a row when a configuration is measured, not when it
# is guessed.
MIN_NPROC_FOR_ON_LINES = {
    1: 8,    # console only -- the pre-2026-08 configuration
    2: 10,   # + ttyv1; raised 8 -> 10 on 2026-08-05 (apple/fgx#41)
    3: 11,   # + ttyv2; raised 10 -> 11 on 2026-08-07 (apple/fgx#43)
    4: 9,    # + ttyv3, the card's console; measured 2026-09-18 with the
             #   virtual-console login test fgxuser, the pty login test
             #   being gone: getty, login, tcsh, su, tcsh and the `id'
             #   under su complete at 9 and not at 8
}


def _ttys_on_lines(path):
    """Count the `on` lines in an /etc/ttys.  Comments and blanks skipped."""
    n = 0
    for line in open(path, errors="replace"):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        f = line.split()
        # name getty type status flags... -- status is field 3
        if len(f) >= 4 and f[3] == "on":
            n += 1
    return n


def check_ttys_vs_nproc(on_lines, nproc):
    """Return a failure string, or None.  Pure, so the self-test can drive it."""
    need = MIN_NPROC_FOR_ON_LINES.get(on_lines)
    if need is None:
        hi = max(MIN_NPROC_FOR_ON_LINES)
        if on_lines > hi:
            return (f"disk_src/etc/ttys has {on_lines} lines `on`, and no "
                    f"configuration past {hi} has been MEASURED. Run logintest "
                    f"at this line count, find the smallest kernel.nproc that "
                    f"completes it, and add the row to "
                    f"MIN_NPROC_FOR_ON_LINES -- do not guess it.")
        return None
    if nproc < need:
        return (f"disk_src/etc/ttys has {on_lines} lines `on` but "
                f"kernel.nproc is {nproc}; {need} is the measured floor. Each "
                f"console costs a permanent getty, its session shell, and the "
                f"login-chain transient, and running short does NOT fail "
                f"cleanly -- it presents as a login that stalls partway "
                f"(apple/fgx#43). Raise kernel.nproc in cfg/system.cfg, or turn "
                f"a line off.")
    return None


def _equ(path, name, default=None):
    """Read `NAME EQU <n>` (decimal or $hex) from a Merlin32 source."""
    with open(path, errors="replace") as f:
        text = f.read()
    # A COMPLETE literal token, not a prefix: the loose `\$?[0-9A-Fa-f]+`
    # this used to be would read `CFG_STK_ARENA_PAGES` as the hex number $CF
    # and budget an arena that does not exist.  The bank-0 layout became an
    # alias chain when kernel.nproc started deriving it.
    m = re.search(rf"^\s*{name}\s+EQU\s+(\$[0-9A-Fa-f]+|\d+)(?=\s|;|$)",
                  text, re.MULTILINE)
    if not m:
        if default is not None:
            return default
        raise SystemExit(
            f"check_stack_budget: cannot find {name} in {path} -- it was renamed "
            f"or its EQU reformatted. Fix this parser rather than dropping the "
            f"check.")
    tok = m.group(1)
    return int(tok[1:], 16) if tok.startswith("$") else int(tok)


def overlap_min():
    """The guarded page count from which a task may be placed OVER other
    tasks' reservations when the arena has no free run, or None if never.

    kernel.stkover (cfg/system.cfg, CFG_KERNEL_STKOVER in config.s) is a
    REQUEST -- the binary's clamped stack hint -- while pages_for() returns
    the GUARDED count Task_AllocStack compares.  The guard page is added
    before the test, so the threshold here is MIN+1 and must stay in step with
    task.s's `_Uimg_Overlap`, which tests the guarded count against MIN+1.
    0 means the arena never oversubscribes.
    """
    m = _equ(CONFIG_S, "CFG_KERNEL_STKOVER")
    return m + 1 if m else None


def scenario_total(pages, threshold):
    """Pages a set of co-resident tasks needs to run WITHOUT A COPY -- their
    plain sum -- and which of them may be parked instead when the arena is
    short: those at or above the overlap threshold.  Pure, so the self-test
    can drive it.

    The sum is the performance statement: under it nothing parks, over it a
    parkable task's live extent is copied out and back around the tasks that
    landed on it.  What over the sum MEANS is the threshold's business: with
    none (kernel.stkover = 0) it is an ENOMEM at spawn, as it always was.
    """
    parkable = sorted((p for p in pages if threshold and p >= threshold),
                      reverse=True)
    return sum(pages), parkable


def pages_for(path, max_pages):
    """Pages Task_AllocStack will actually carve for this binary, guard page
    included -- or None if it is not an FGX2/FGX3 binary at all.

    THE ARGV/ENVP FRAME IS PART OF THE RESERVATION (apple/fgx#30, and #45 in the
    kernel).  The linker sizes the hint for the C frame plus DEFAULT_PAD; it
    never sees the frame the loader lays on TOP of the child's stack.  Both
    allocation paths add it -- process.s:239-263 for posix_spawn,
    main.s:546-568 for the boot spawn -- as
    `normalize(hint) + ceil(frame/256)`, and Task_AllocStack then clamps and
    adds the guard.  The order matters and is reproduced exactly: clamping
    before adding would under-count a binary near the ceiling.

    ARGV_FRAME_PAGES IS A FLOOR, NOT A MODEL.  The true term is
    ceil(frame_bytes/256) and the frame depends on the actual command line and
    environment, which a static check cannot know.  One page is what every
    non-empty invocation costs, and it is what the shipped environment
    produces.  A long command line costs more and this will under-count it --
    stated because that is the residue, not a claim of exactness.

    VALIDATED AGAINST THE RUNNING MACHINE, not just against the source: init 3,
    ps 3, getty 3, sh 16, ls 4 pages, each matching the ps STK column.  The
    pre-#30 model
    said 2/2/2/15/3 -- one short, every time.
    """
    try:
        with open(path, "rb") as f:
            head = f.read(STACK_HINT_OFF + 1)
    except OSError:
        return None
    if len(head) <= STACK_HINT_OFF or head[:4] not in MAGICS:
        return None                       # script, FGX1 hand-asm, or not a binary
    hint = head[STACK_HINT_OFF]
    # normalize(hint) + argv frame, THEN clamp, THEN guard, THEN the direct
    # page -- the kernel's order.  The direct page is the first page of the
    # reservation (task.s Task_AllocStack), carved with the stack and outside
    # the clamp like the guard.
    return min(max(hint, 1) + ARGV_FRAME_PAGES, max_pages) + 1 + 1


def index_binaries(max_pages, arena):
    """(pages by binary name, binaries that do not fit the arena at all).

    A binary whose guarded reservation exceeds the arena can never spawn:
    Task_AllocStack refuses it with ENOMEM even with the arena empty, which
    is correct but only visible when somebody tries to run it.  Catching it
    here names the binary at build time.
    """
    out, oversized = {}, []
    for d in STAGE_DIRS:
        full = os.path.join(ROOT, d)
        if not os.path.isdir(full):
            continue
        for name in os.listdir(full):
            p = pages_for(os.path.join(full, name), max_pages)
            if p is not None:
                if p > arena:
                    oversized.append((name, p))
                out.setdefault(name, p)
    return out, oversized


def _selftest():
    fails = []
    # The clamp/guard/argv arithmetic is the part that has historically been
    # wrong.  DRIVEN THROUGH pages_for(), not recomputed here: this block used
    # to carry its own copy of the formula, so when apple/fgx#30 corrected
    # pages_for() the self-test kept asserting the OLD model -- a fence
    # checking a different machine from the one it guards.  It went red, which
    # is the good outcome, but only because the two disagreed by luck of which
    # was edited.
    #
    # Expectations are the kernel's own order: normalize(hint) + argv frame,
    # then clamp to max_pages, then + 1 guard, then + 1 direct page.  hint 83
    # with max 83 clamps to 83, guards to 84 and carries its page at 85 -- the
    # argv page is absorbed by the clamp, which is exactly what the kernel
    # does and why the clamp cannot come first.
    import tempfile
    cases = [(0, 83, 4), (1, 83, 4), (55, 83, 58), (83, 83, 85), (200, 83, 85)]
    for hint, mx, want in cases:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".bin") as tf:
            tf.write(b"FGX3" + b"\0" * (STACK_HINT_OFF - 4) + bytes([hint]) + b"\0")
            probe = tf.name
        try:
            got = pages_for(probe, mx)
        finally:
            os.unlink(probe)
        if got != want:
            fails.append(f"hint {hint} max {mx}: got {got}, want {want}")
    # A non-FGX file must be REJECTED, not read as a stack size -- the hd trap.
    with tempfile.NamedTemporaryFile(delete=False) as t:
        t.write(b"#!/bin/jsh\n# SPDX-License-Identifier: BSD-2-Clause\n")
        fake = t.name
    try:
        if pages_for(fake, 83) is not None:
            fails.append("a jsh script was accepted as an FGX binary (the hd trap)")
        with open(fake, "wb") as f:
            f.write(b"FGX3" + b"\0" * 10 + bytes([55]) + b"\0")
        if pages_for(fake, 83) != 58:
            fails.append("a real FGX3 header was not read as 55 + argv + guard "
                         "+ direct page")
    finally:
        os.unlink(fake)
    # A budget that exceeds the arena must be reported as over.
    if not (200 > _equ(CONFIG_S, "CFG_STK_ARENA_PAGES")):
        fails.append("over-budget comparison is inverted")
    # THE OVERLAP ACCOUNTING.  The sum is the no-copy footprint whatever the
    # threshold; the threshold only says which tasks may park instead.
    total, parkable = scenario_total([3, 16, 77, 76, 77, 23], 41)
    if total != 272 or parkable != [77, 77, 76]:
        fails.append("the scenario sum or its parkable set is wrong")
    if scenario_total([3, 16, 77, 76, 77, 23], None) != (272, []):
        fails.append("with overlap off, nothing should be parkable")
    if scenario_total([3, 16], 41) != (19, []):
        fails.append("a scenario with no parkable task was mischarged")
    # THE ttys/NPROC RELATION.  The shipping pair must be clean, and the exact
    # pair that shipped apple/fgx#43 -- three lines on with NPROC=10 -- must be
    # caught, because that combination looked green everywhere else.
    if check_ttys_vs_nproc(3, 11):
        fails.append("the shipping ttys/NPROC pair was reported as broken")
    if not check_ttys_vs_nproc(3, 10):
        fails.append("three consoles on NPROC=10 not caught -- this is the "
                     "exact configuration that shipped apple/fgx#43")
    if not check_ttys_vs_nproc(2, 8):
        fails.append("two consoles on NPROC=8 not caught")
    if not check_ttys_vs_nproc(4, 8):
        fails.append("four consoles on NPROC=8 not caught -- the login "
                     "chain's `id' under su is the ninth task")
    if not check_ttys_vs_nproc(5, 11):
        fails.append("an UNMEASURED line count was accepted -- silence there "
                     "reads as approval of a configuration nobody has run")
    if fails:
        for f in fails:
            print(f"  {f}", file=sys.stderr)
        print(f"check_stack_budget self-test: {len(fails)} FAILURE(S)")
        return 1
    print("check_stack_budget self-test: OK "
          "(clamp+guard arithmetic, rejects non-FGX files, comparison sane, "
          "overlap accounting, ttys `on` lines vs kernel.nproc)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return _selftest()

    arena = _equ(CONFIG_S, "CFG_STK_ARENA_PAGES")
    max_pages = _equ(TASK_S, "TASK_STACK_MAX_PAGES")
    have, oversized = index_binaries(max_pages, arena)
    threshold = overlap_min()
    verbose = "-v" in sys.argv or "--verbose" in sys.argv

    # Slots before pages: running short of process slots does not fail cleanly,
    # it stalls a login partway (apple/fgx#43).
    ttys = os.path.join(ROOT, "disk_src", "etc", "ttys")
    bad = check_ttys_vs_nproc(_ttys_on_lines(ttys),
                              _equ(CONFIG_S, "CFG_KERNEL_NPROC"))
    if bad:
        print(f"check_stack_budget: {bad}", file=sys.stderr)
        return 1

    # A binary that does not FIT THE ARENA can never spawn: Task_AllocStack
    # refuses it rather than hand it a smaller range than it asked for (a stack
    # overflow with no diagnostic).  Fail here, where the binary has a name.
    if oversized:
        print(f"check_stack_budget: BINARY DOES NOT FIT THE STACK ARENA "
              f"(FGX_STK_ARENA_PAGES = {arena}, guard page included):",
              file=sys.stderr)
        for name, p in sorted(oversized):
            print(f"  {name} needs {p} pages > {arena} "
                  f"(hint + argv frame + guard)",
                  file=sys.stderr)
        print(f"  This binary would be refused at spawn with ENOMEM whatever "
              f"else is running.\n"
              f"  Shrink its deepest path, or reclaim bank-0 pages for the "
              f"arena.", file=sys.stderr)
        return 1

    worst, worst_name, over, missing = 0, None, [], []
    for name, members in sorted(SCENARIOS.items()):
        parts, gaps, pages = [], [], []
        # INIT IS IN EVERY SCENARIO, charged here rather than written into each
        # list so a new scenario cannot forget it (apple/fgx#30).  It is pid 1
        # and permanently resident, and it is IN THE ARENA: the note that used
        # to sit at the top of this file said it kept a static $3100 page
        # outside the arena, which has been false since 2026-07-31 -- see
        # include/kernel.s, "init does NOT keep a static page.  It calls
        # Task_AllocStack like every other task."  That myth had been
        # re-derived three times, which is why this cites the header rather
        # than restating the reasoning.
        for m in ["init"] + list(members):
            if m not in have:
                gaps.append(m)
                continue
            pages.append(have[m])
            parts.append(f"{m} {have[m]}")
        # THE SUM IS WHAT RUNS WITHOUT A COPY.  Over it, tasks at or above
        # the overlap threshold are parked by whoever lands on them -- the
        # user-image cache -- and come back when they next run; the note
        # below says so rather than failing.
        total, parkable = scenario_total(pages, threshold)
        if total > arena and parkable:
            parts.append(f"({len(parkable)} of these may park)")
        if gaps:
            missing.append((name, gaps))
        if total > worst:
            worst, worst_name = total, name
        if total > arena:
            over.append((name, total, parts))
        elif verbose:
            print(f"    {total:3d}/{arena}  {name}  ({', '.join(parts)})")

    # A scenario naming a binary that does not exist is silently weaker than it
    # reads.  Report it -- a budget that quietly stopped measuring something is
    # the failure mode this whole file exists to prevent.
    for name, gaps in missing:
        print(f"check_stack_budget: NOTE: scenario '{name}' skipped "
              f"{', '.join(gaps)} (not staged) -- its budget is incomplete",
              file=sys.stderr)

    # A SCENARIO PAST THE ARENA IS A PERFORMANCE STATEMENT NOW, NOT A FAILURE.
    # Every task above kernel.stkover may be placed over a parked sleeper when
    # the arena has no free run, and with the knob at 1 that is every task:
    # the machine parks a live extent instead of refusing the spawn.  What the
    # sum still says is how much of the workload runs WITHOUT a copy, which is
    # worth printing every build and worth reading when a workload feels slow.
    if over:
        print(f"check_stack_budget: NOTE: the arena oversubscribes "
              f"(FGX_STK_ARENA_PAGES = {arena}); these scenarios park "
              f"sleepers when they run together:", file=sys.stderr)
        for name, total, parts in over:
            print(f"  {total} pages > {arena}: {name}\n"
                  f"      {', '.join(parts)}", file=sys.stderr)
        if threshold is None:
            print(f"  kernel.stkover is 0, so these fail with ENOMEM instead "
                  f"of parking.", file=sys.stderr)
            return 1

    print(f"    stack budget: worst case {worst}/{arena} pages "
          f"({worst_name}){' -- oversubscribed, parks' if over else ''}")
    return 0


if __name__ == "__main__":
    # sys.exit: main() RETURNS its status, and a check that cannot fail the
    # build is exactly the defect it exists to catch.
    sys.exit(main() or 0)
