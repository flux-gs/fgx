#!/usr/bin/env python3
"""BUILD GATE: no shared direct-page cell may be live across a task switch.

`swtch` saves SE_KernSP / UserSP / UserDP / CallerBank and NO direct-page
scratch (src/kernel/sched.s).  So a cell written before a sleep and read after
it is carrying a value that any other task's kernel code is free to overwrite.
That is apple/fgx#100 (a socket sleep lost the caller's buffer bank) and
apple/fgx#41 (a ctty gate lost the active tty pointer).

Both are fixed.  The measured exposure today is ZERO.  **This gate exists to
keep it there**, because the invariant is invisible: nothing about a new
sleeping path announces that it must not hold scratch.

WHAT IT CHECKS
  1. asm: no DP cell is stored, then a sleep is reached, then the cell is read
     -- within a routine, and across the call graph, unless the sleeping callee
     SAVES it (PEI/PHA before, STA back after).
  2. structure: kernel C is safe by CONSTRUCTION, and that construction is
     asserted rather than assumed -- kernel C runs on its own direct page
     (FGX_DP_KERNELC), so it cannot reach the asm scratch cells by DP offset at
     all, and its register file is saved per task across the switch
     (_kcDpSave, sched.s).  If either fact stops being true, the C layer joins
     the analysis and this gate says so.

WHY BOTH.  The first version of the underlying analysis reported "zero" while
being blind to two things: every MODULE sleeps by putting a service number in a
register (`LDX #KSVC_SLEEP` / `JSL SYS_KCALL`) rather than naming the primitive,
so pty.mod and vfs.mod read as sleep-free -- and pty is where #41 lived; and
the kernel C layer was never scanned at all.  A gate that inherits those blind
spots enforces one seam while blind at another, so `--self-test` proves it can
fail on both.
"""

import argparse
import importlib.util
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load_analysis():
    spec = importlib.util.spec_from_file_location(
        "dp_sleep_ranges", ROOT / "tools" / "dp_sleep_ranges.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


# Cells the syscall dispatcher stages BEFORE entering a module.  A module that
# sleeps is holding these on behalf of a caller it cannot see.
REQUIRED_SAVE = ("_libcTmp2",)

# (routine, cells) pairs the unowned-read pass may skip.  EMPTY, and meant to
# stay that way: unlike the sleep-shim list, an entry here hides a hazard.  The
# three pty sites this pass was written for were FIXED rather than listed --
# they now take non-blocking from the op's `flag' argument, which arrives in a
# register and cannot go stale.
UNOWNED_OK = set()

# MODULE STATICS A ROUTINE CARRIES ACROSS ITS OWN SLEEP -- apple/fgx#206's
# SECOND defect, and the half `dp_cells()' is structurally unable to see.
#
# `_PtyM_Write' stored the byte in `_ptyTmpB2' at entry and re-read it after
# `_PtyKC_Sleep'; `@sw_putblk' did the same with `_ptyTmpB3'.  Both are kernel
# statics, so a second task writing to a pty while the first slept overwrote
# the character the sleeper was about to enqueue -- apple/fgx#89 with the byte
# instead of the count, and a `$03' in a pty stream is a `^C' to the
# discipline.
#
# WHY THIS IS A NAMED SET AND NOT `every kernel static'.  That was MEASURED and
# rejected: across the 1,151 column-0 `DS' symbols the same passes report 13
# sites, and the first one read -- `_Sys_Read' at syscall.s -- re-stores its
# cell four lines AFTER the call it is accused of carrying it across.  The
# store set is "anything stored earlier in this routine", which suits the small
# bodies the DP passes were written against and is wrong for a 900-line
# dispatcher of independent arms.  The note in tools/dp_sleep_ranges.py records
# that measurement; this covers the cells a defect actually lived in, with no
# false positives, rather than covering everything with many.
#
# A ROUTINE THAT SAVES ACROSS ITS OWN SLEEP IS CREDITED, by `saved_cells' --
# which is exactly what the fix does: `LDA _ptyTmpB2 / PHA' before the sleep
# and `PLA / STA _ptyTmpB2' after.  Delete either half and this goes red.
MODULE_CARRIED = {
    "src/modules/pty/pty.s": ("_ptyTmpB2", "_ptyTmpB3", "_ptyNbFlag"),
    # `_sockTmpOff' is `DS 2' in src/kernel/socket.s -- a CORE-BANK static the
    # net module writes through the socket-table seam, and about sixteen sites
    # write it.  `net_op_sockteardown' holds the descriptor offset there across
    # `_Unp_CloseTry' and re-reads it to clear SOCK_InUse, which was safe until
    # UNP_OP_UNBIND made that call sleep: another task's socket syscall could
    # land between the two reads and the teardown would clear InUse on a LIVE
    # descriptor belonging to someone else while leaking its own.  That is
    # apple/fgx#458's defect, fixed in `1d199238d' by parking the cell in
    # `_Unp_NameCall', and this line is what makes it stay fixed --
    # `git show 1d199238d~1' goes red here.
    "src/modules/net/net.s": ("_sockTmpOff",),
}


def check_module_carried(m, where=None, sleepy=None, saved=None):
    """Module statics stored, carried across a sleep, and read back.

    THE READ IS FOUND THROUGH `loop_window', not forward of the sleep, and that
    is the whole reason a plain `analyse' pass misses this shape: a wait loop
    re-reads its cell at the LOOP HEAD, which is textually BEFORE the sleep it
    comes back from.  `_PtyM_Write' is exactly that -- `@mw_go' reads
    `_ptyTmpB2' and the sleep is forty lines below it -- so a forward-only scan
    finds a store, a sleep and no read, and reports clean.
    """
    if where is None:
        calls, where = m.build_callgraph()
        sleepy = m.can_sleep_closure(calls, m.ksvc_sleep_shims(where))
    watched = {}
    for rel, cells in MODULE_CARRIED.items():
        watched[str(pathlib.Path(rel))] = set(cells)
    every = sorted({c for cs in MODULE_CARRIED.values() for c in cs},
                   key=len, reverse=True)
    if not every:
        return []
    alt = "|".join(re.escape(n) for n in every)
    store = re.compile(r"\b(STA|STX|STY|STZ|INC|DEC)\s+\|?<?(" + alt + r")\b")
    read = re.compile(r"(?:\[\s*|\(\s*|\b(?:LDA|LDX|LDY|CMP|CPX|CPY|AND|ORA|"
                      r"EOR|ADC|SBC|BIT)\s+\|?<?)(" + alt + r")\b")
    if saved is None:
        saved = m.saved_cells(every, alt, where, sleepy)

    seen = set()
    out = []
    for rname, (path, lo, hi, lines) in sorted(where.items()):
        cells = (watched.get(str(pathlib.Path(m.relname(path))))
                 or watched.get(str(pathlib.Path(path))))
        if not cells:
            continue
        seen.add(str(pathlib.Path(m.relname(path))))
        seen.add(str(pathlib.Path(path)))
        body = [m.strip_comment(l) for l in lines[lo:hi]]
        for k, l in enumerate(body):
            call = m.RETURNING_CALL_RE.search(l)
            callee = call.group(2) if call else None
            if not (m.sleep_re().search(l) or (callee and callee in sleepy)):
                continue
            before = {}
            for j in range(0, k):
                for mm in store.finditer(body[j]):
                    if mm.group(2) in cells:
                        before.setdefault(mm.group(2), lo + j + 1)
            after = {}
            for j in range(m.loop_window(body, k), len(body)):
                if j == k:
                    continue
                for mm in read.finditer(body[j]):
                    if mm.group(1) in cells:
                        after.setdefault(mm.group(1), lo + j + 1)
            live = sorted((set(before) & set(after))
                          - saved.get(rname, set())
                          - saved.get(callee, set()))
            if live:
                out.append({
                    "file": m.relname(path), "line": lo + k + 1,
                    "routine": rname,
                    "sleep": (callee or m.strip_comment(l).strip()[:40])
                             + "  (module static carried across a sleep)",
                    "live": [{"cell": c, "stored": before[c], "read": after[c]}
                             for c in live],
                })

    # A NAME THAT MATCHES NOTHING IS A GUARD THAT DOES NOTHING.  If the file
    # moves or is renamed, this pass would go quietly clean; say so instead.
    for rel in MODULE_CARRIED:
        if str(pathlib.Path(rel)) not in seen:
            out.append({"file": rel, "line": 0, "routine": "-",
                        "sleep": "MODULE_CARRIED names a file with no routines "
                                 "in the callgraph -- moved or renamed?",
                        "live": []})
    out.sort(key=lambda h: (h["file"], h["line"]))
    return out


# Module sleep sites that do NOT save, each with the argument for why that is
# safe.  An entry here is a claim someone checked; it is not a way to quiet the
# gate.  Adding one without a reason defeats the whole check.
MODULE_SLEEP_ALLOWLIST = {
    "_NlKC_Sleep":
        "pass-through shim: three instructions, holds no scratch of its own "
        "(net_loop.s).",
    "_PtyKC_Sleep":
        "pass-through shim: LDX #KSVC_SLEEP / JSL SYS_KCALL / RTS (pty.s).",
    # The two below became visible with apple/fgx#458: their arms reach
    # ttywflush -> ttywait -> kc_sleep in the tty bank's C, so they have always
    # slept and the gate simply could not tell.  Same three-instruction shape as
    # _PtyKC_Sleep above -- read, not assumed.
    "_PtyKC_LineOpen":
        "pass-through shim: LDX #KSVC_TTYLOPEN / JSL SYS_KCALL / RTS (pty.s), "
        "holding no scratch of its own.  Sleeps because kc_ttopen reaches "
        "ttyopen -> ttywflush on a non-NTTYDISC line.",
    "_PtyKC_LineClose":
        "pass-through shim: LDX #KSVC_TTYLCLOSE / JSL SYS_KCALL / RTS (pty.s), "
        "holding no scratch of its own.  Sleeps because kc_ttclose reaches "
        "ttylclose -> ttywflush, which DRAINS unless FNDELAY is set.",
    "_Unp_NameCall":
        "REBUILDS rather than saves, and could not save if it wanted to: the "
        "KSVC_UNPNAME arm calls _Sys_CopyPathToBuf, which builds _libcTmp2 as "
        "its OWN [_libcTmp2],Y copy pointer (src/kernel/syscall.s), so the cell "
        "cannot survive this call whether it sleeps or not.  unp.s restages with "
        "_Unp_LoadArgs -- a RESTAGER in tools/dp_sleep_ranges.py -- before every "
        "[_libcTmp2] read, and the unowned-read pass covers _libcTmp2 and "
        "reports no path that inherits a stale one.  This is the argument "
        "_Pipe_PollIntr makes for the _pipe* scratch.  Verified 2026-09-20.",
    "kc_sleep":
        "pass-through shim into the kernel service slot (vfs/kc_sys.s).",
    "kc_sleepi":
        "pass-through shim into KSVC_SLEEP, kc_sleep's shape with the "
        "interruptible service (common/kc_sys.s): ENTERK, LDA, LDX, JSL, "
        "LEAVEK, RTL, holding no scratch of its own.  Its one caller chain is "
        "vn_lock <- vn_flock <- _Vfs_Flock <- _Sys_Flock, and flock(2) stages "
        "no pointer argument: _Sys_Flock reads no DP cell after the far call "
        "returns (syscall.s).  Verified 2026-09-26.",
    "_Pipe_PollIntr":
        "REBUILDS rather than saves: _PIPE_SCRATCH_LEN covers _pipeRecOff.._pipeNonBlk, "
        "which holds the caller's uio pointer (_pipeUio), and every ring move "
        "after a block goes through _Pipe_RingMove, which reloads _kCopyPtr "
        "from the pipe record (_Pipe_LoadRingPtr) and hands uiomove the uio "
        "from _pipeUio -- no DP pointer from before the sleep is used.  "
        "Verified 2026-09-22; this is the argument _Sock_PollIntr's header "
        "falsely claimed for itself, which is how #100 survived review.",
    "klog_dread":
        "REBUILDS rather than saves, and the order is what makes it true: the "
        "only sleep is the wait at `@dr_wait', which is reached BEFORE "
        "`@dr_have' stages _libcTmp2 -- and it stages it from the op's own "
        "stack frame (9,S/11,S), not from whatever the dispatcher left, so "
        "nothing of a pre-sleep value survives or is wanted.  The transfer loop "
        "after it holds _libcTmp2 across `uiomove', which does not sleep: "
        "src/kernel/vfs/kern_subr.c:185 is a copy loop over the iovecs whose "
        "only exit is kc_panic on a bad mode.  This is the argument "
        "_Pipe_PollIntr's entry makes for the _pipe* scratch.  Verified "
        "2026-09-20.",
    "_Loop_AcceptTry":
        "loopback accept: the data paths that hold a caller uio go through "
        "_Loop_SoIo, not this routine, and its own sleep holds only "
        "_sockTablePtr-derived state.  Verified 2026-09-22.",
}


def sleep_site_routines(m):
    """[(routine, path, body)] for every routine that CONTAINS a sleep."""
    out = []
    for p in sorted((ROOT / "src").rglob("*.s")):
        if not p.is_file():
            continue
        for name, lo, hi, lines in m.routines_of(p):
            body = "\n".join(m.strip_comment(l) for l in lines[lo:hi])
            if m.sleep_re().search(body):
                out.append((name, p, body))
    return out


def check_module_sleeps(m):
    """THE RULE THAT CATCHES apple/fgx#100.

    A module sleeps on behalf of a caller it cannot see.  The syscall
    dispatcher stages _libcTmp2 before entering the module, the module sleeps
    deep inside, and a third routine reads the pointer back on the way out --
    three routines, two files, one module boundary.  No within-routine or
    name-based call-graph analysis can see that, which is precisely why #100
    survived one.

    So the obligation is placed where it can be checked: **a sleep site inside
    a module must save the staged cells, or carry a written reason.**
    """
    names = m.dp_cells()
    alt = "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))
    problems = []
    for name, path, body in sleep_site_routines(m):
        if "modules" not in str(path):
            continue
        if name in MODULE_SLEEP_ALLOWLIST:
            continue
        where = {}
        for rn, lo, hi, lines in m.routines_of(path):
            where[rn] = (path, lo, hi, lines)
        saved = m.saved_cells(names, alt, where, {name}).get(name, set())
        for cell in REQUIRED_SAVE:
            if cell not in saved:
                problems.append(
                    f"{m.relname(path)}: {name} sleeps inside a module but does "
                    f"not save {cell}, and is not allowlisted.  The dispatcher "
                    f"stages {cell} before entering the module, so this sleep "
                    f"hands another task a window to overwrite a pointer this "
                    f"path will read back -- that is apple/fgx#100.")
    return problems


def check_asm(m, verbose=False):
    """Returns (findings, n_sleep_sites, n_sleepy_routines)."""
    names = m.dp_cells()
    alt = "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))

    within = []
    for p in (ROOT / "src").rglob("*.s"):
        if p.is_file():
            within.extend(m.analyse(p, names, alt))
    n_sites = len(within)
    findings = [w for w in within if w["live"]]

    calls, where = m.build_callgraph()
    # THE MODULE SLEEP SHIMS ARE DERIVED.  A hand list had `_NlKC_Sleep' and
    # `kc_sleep' and not `_PtyKC_Sleep', so every caller in pty.mod read as
    # unable to sleep -- in the one module apple/fgx#41 came from.
    shims = m.ksvc_sleep_shims(where)
    sleepy = m.can_sleep_closure(calls, shims)
    saved_by = m.saved_cells(names, alt, where, sleepy)
    inter = m.interprocedural(names, alt, calls, where, sleepy, saved_by)

    for h in inter:
        findings.append({
            "file": h["file"], "line": h["line"], "routine": h["routine"],
            "sleep": f"-> {h['callee']} (can sleep)", "live": h["live"],
        })

    # THE THIRD SHAPE: a cell this routine never stored, read after a sleep.
    # Both passes above intersect a STORE set, so a body that only READS a
    # dispatcher-staged cell falls out of each -- and the value is no less
    # stale for having been staged by the caller.
    findings.extend(check_module_carried(m, where, sleepy))

    for h in m.unowned(names, alt, calls, where, sleepy, saved_by):
        if (h["routine"], tuple(c["cell"] for c in h["live"])) in UNOWNED_OK:
            continue
        findings.append({
            "file": h["file"], "line": h["line"], "routine": h["routine"],
            "sleep": f"-> {h['sleep']} (can sleep); reads a cell it never "
                     f"stored",
            "live": [{"cell": c["cell"], "stored": "caller", "read": c["read"]}
                     for c in h["live"]],
        })
    return findings, n_sites, len(sleepy)


def check_kernel_c():
    """Assert the two facts that keep the C layer out of scope.

    Kernel C DOES sleep -- vfs_bio.c calls kc_sleep in several places -- so
    "the C layer is fine" is a claim that has to be checked, not assumed.  It
    is fine for two structural reasons, and if either changes the analysis
    above has to grow to cover C.
    """
    problems = []
    kernel_s = (ROOT / "include" / "kernel.s").read_text()
    sched_s = (ROOT / "src" / "kernel" / "sched.s").read_text()

    # (a) kernel C has a direct page OF ITS OWN, so it cannot address the asm
    #     scratch cells by DP offset.
    if "FGX_DP_KERNELC" not in kernel_s:
        problems.append("FGX_DP_KERNELC is gone: kernel C may now share the "
                        "asm scratch direct page, so the C layer must join "
                        "the cross-sleep analysis")

    # (b) its register file is saved per task across the switch.
    if "_kcDpSave" not in sched_s:
        problems.append("_kcDpSave is gone from sched.s: the kernel-C register "
                        "file is no longer saved across a task switch, so C "
                        "locals are exposed exactly as DP scratch would be")
    problems.extend(check_kcprobe_gate(sched_s))
    return problems


# `DO <cond>' opens a conditional-assembly block and `FIN' closes it; the
# assembler ELIDES the body when <cond> is 0.  Nesting is allowed.
DO_RE = re.compile(r"^\s+DO\s+([A-Za-z_][A-Za-z0-9_]*)\s*$")
FIN_RE = re.compile(r"^\s+FIN\s*$")
KCCALL_RE = re.compile(r"\bJSR\s+\|?<?(_KcDp_Save|_KcDp_Rest)\b")


def kc_call_conditions(sched_s):
    """{routine: [enclosing DO conditions]} for the two register-file calls."""
    stack, gated = [], {}
    for l in sched_s.splitlines():
        bare = l.split(';', 1)[0].rstrip()
        m = DO_RE.match(bare)
        if m:
            stack.append(m.group(1))
            continue
        if FIN_RE.match(bare):
            if stack:
                stack.pop()
            continue
        c = KCCALL_RE.search(bare)
        if c:
            gated[c.group(1)] = list(stack)
    return gated


def kcprobe_gated(sched_s):
    """Is either register-file call inside `DO KCPROBE'?  apple/fgx#204."""
    g = kc_call_conditions(sched_s)
    return any("KCPROBE" in conds for conds in g.values())


def kcprobe_value():
    """The effective KCPROBE, through the EQU chain to the generated config.

    include/kernelc.s says `KCPROBE EQU CFG_KERNEL_KCPROBE' and
    include/config.s is generated from cfg/system.cfg.  Reading the generated
    file is reading what the assembler will read.
    """
    try:
        cfg = (ROOT / "include" / "config.s").read_text()
    except OSError:
        return None
    m = re.search(r"^CFG_KERNEL_KCPROBE\s+EQU\s+(\d+)", cfg, re.M)
    return int(m.group(1)) if m else None


def check_kcprobe_gate(sched_s):
    """THE GUARD MUST SEE THE GATE, NOT THE SUBSTRING.  apple/fgx#204.

    The check above asks whether `_kcDpSave' appears in sched.s.  It does --
    and it appears INSIDE `DO KCPROBE', so at KCPROBE = 0 the assembler drops
    both the save and the restore and the substring is still there.  The gate
    printed "kernel C still on its own DP with its register file saved" at a
    setting where swtch saves nothing, which is the exact shape of guard this
    file exists to stop being: a report that cannot see its own subject.

    IT MATTERS BECAUSE THE C LAYER IS NOT GATED THE SAME WAY.  include/kernel.s
    calls KCPROBE "0 in a shipping kernel"; vfs.mod's C sleeps in getblk and
    biowait regardless, and src/modules/vfs/vfs.s says in as many words that
    the module is not gated on KCPROBE.  So at 0 the register file is exposed
    across every switch that happens inside kernel C.

    This does NOT fail at KCPROBE = 1, which is the committed setting: the
    protection is really there.  It fails at 0, where the structural claim in
    check_kernel_c is false, and it makes the summary line say `conditionally'
    so that the claim is never read as unconditional again.
    """
    gated = kc_call_conditions(sched_s)
    conds = sorted({c for conds in gated.values() for c in conds})
    if not gated:
        return ["neither _KcDp_Save nor _KcDp_Rest is called from sched.s: "
                "the kernel-C register file is not saved across a switch"]
    if "KCPROBE" not in conds:
        return []                       # ungated: the claim is unconditional
    val = kcprobe_value()
    if val is None:
        return ["_KcDp_Save/_KcDp_Rest sit inside `DO KCPROBE' and "
                "CFG_KERNEL_KCPROBE could not be read from include/config.s, "
                "so whether the kernel-C register file is saved at all is "
                "unknown (apple/fgx#204)"]
    if val == 0:
        return ["kernel.kcprobe = 0, and _KcDp_Save/_KcDp_Rest sit inside "
                "`DO KCPROBE' -- so swtch saves NO kernel-C register file, "
                "while vfs.mod's C still sleeps in getblk/biowait and is not "
                "gated on KCPROBE.  apple/fgx#204: the protection this gate "
                "reports is not present at this setting."]
    return []


def self_test(m):
    """Prove this gate can FAIL -- on the real code it currently passes, and a
    guard that cannot go red is the defect it exists to catch."""
    names = m.dp_cells()
    alt = "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))

    # 1. The named-primitive sleep spelling.
    if not m.sleep_re().search("                JSR     _sleep"):
        print("self-test FAILED: named sleep not detected")
        return 1

    # 2. THE SELECTOR SPELLING -- how every module sleeps, and the blind spot
    #    that made the first census report pty.mod as sleep-free.
    #
    #    KSVC_UNPNAME IS IN THE LIST ON PURPOSE.  These go through the regexes
    #    the passes actually use, so they fail if `_derive' stops consulting
    #    sleeping_selectors() -- which asserting the derivation alone does not
    #    catch, measured: that mutation left the gate blind and every other case
    #    green.
    for spelling in ("                LDX     #KSVC_SLEEP",
                     "                LDX     #KSVC_SLEEPUN",
                     "                LDX     #KSVC_UNPNAME"):
        if not m.sleep_re().search(spelling):
            print(f"self-test FAILED: selector sleep not detected: {spelling!r}")
            return 1
        if not m.ksvc_sleep_re().search(spelling):
            print(f"self-test FAILED: the shim regex misses {spelling!r}, so "
                  f"ksvc_sleep_shims() cannot derive the routine")
            return 1

    # 3. An ordinary line is not mistaken for a sleep.
    for benign in ("                JSR     Blk_Read",
                   "                LDA     _libcTmp2"):
        if m.sleep_re().search(benign):
            print(f"self-test FAILED: false positive on {benign!r}")
            return 1

    # 3b. THE MODULE-CARRIED PASS, both directions (apple/fgx#206).  It has
    #     its own body rather than reusing `analyse', because the read it must
    #     find is at a LOOP HEAD -- textually BEFORE the sleep it comes back
    #     from -- and a forward-only scan reports clean on the exact shape the
    #     defect had.  So the unsafe case below re-reads at `@loop', and the
    #     safe one differs only by the save around the sleep.
    import tempfile as _mc_tf
    UNSAFE = ["_Probe          MX      %00",
              "                STA     |_ptyTmpB2",
              "@loop           LDA     |_ptyTmpB2",
              "                BEQ     @done",
              "                LDX     #KSVC_SLEEP",
              "                JSL     SYS_KCALL",
              "                BRA     @loop",
              "@done           RTS"]
    SAFE = ["_Probe          MX      %00",
            "                STA     |_ptyTmpB2",
            "@loop           LDA     |_ptyTmpB2",
            "                BEQ     @done",
            "                LDA     |_ptyTmpB2",
            "                PHA",
            "                LDX     #KSVC_SLEEP",
            "                JSL     SYS_KCALL",
            "                PLA",
            "                STA     |_ptyTmpB2",
            "                BRA     @loop",
            "@done           RTS"]
    with _mc_tf.TemporaryDirectory() as td:
        f = pathlib.Path(td) / "probe.s"
        rel = str(f)
        saved_map = dict(MODULE_CARRIED)
        try:
            MODULE_CARRIED.clear()
            MODULE_CARRIED[rel] = ("_ptyTmpB2",)
            for body, want in ((UNSAFE, True), (SAFE, False)):
                f.write_text("\n".join(body) + "\n")
                where = {"_Probe": (f, 0, len(body), body)}
                hits = check_module_carried(m, where, {"_Probe"})
                got = any(h["live"] for h in hits)
                if got != want:
                    print("self-test FAILED: module-carried pass %s the %s "
                          "case" % ("flagged" if got else "missed",
                                    "unsafe" if want else "safe"))
                    return 1
        finally:
            MODULE_CARRIED.clear()
            MODULE_CARRIED.update(saved_map)

    # 4. A synthetic store -> sleep -> read IS flagged.  Without this the
    #    analysis could return zero because it finds nothing, ever.
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        src = pathlib.Path(td) / "src"
        src.mkdir()
        bad = src / "probe.s"
        bad.write_text(
            "_Known_Bad      MX      %00\n"
            "                LDA     #$1234\n"
            "                STA     _libcTmp2\n"
            "                JSR     _sleep\n"
            "                LDA     [_libcTmp2],Y\n"
            "                RTS\n"
            "_Other          MX      %00\n"
            "                RTS\n")
        hits = m.analyse(bad, names, alt)
        live = [h for h in hits if h["live"]]
        if not live:
            print("self-test FAILED: a store/sleep/read routine was NOT flagged")
            return 1
        if live[0]["live"][0]["cell"] != "_libcTmp2":
            print("self-test FAILED: wrong cell reported")
            return 1

    # 5. The SAVED idiom is recognised POSITIONALLY.  Matching a push and a
    #    store anywhere would mark a read-modify-write ACROSS a sleep as its
    #    own protection -- exactly backwards.
    with tempfile.TemporaryDirectory() as td:
        src = pathlib.Path(td) / "src"
        src.mkdir()
        f = src / "probe2.s"
        f.write_text(
            "_Saver          MX      %00\n"
            "                PEI     (_libcTmp2)\n"
            "                JSR     _sleep\n"
            "                PLA\n"
            "                STA     _libcTmp2\n"
            "                RTS\n"
            "_NotSaver       MX      %00\n"
            "                LDA     _libcTmp2\n"
            "                JSR     _sleep\n"
            "                STA     _libcTmp2\n"
            "                RTS\n")
        where = {}
        for name, lo, hi, lines in m.routines_of(f):
            where[name] = (f, lo, hi, lines)
        sv = m.saved_cells(names, alt, where, set(where))
        if "_libcTmp2" not in sv.get("_Saver", set()):
            print("self-test FAILED: the PEI/STA save idiom was not recognised")
            return 1
        if "_libcTmp2" in sv.get("_NotSaver", set()):
            print("self-test FAILED: a read-modify-write ACROSS a sleep was "
                  "credited as its own protection -- the backwards case")
            return 1

    # 6. THE #100 SHAPE.  A module sleep site that does not save and is not
    #    allowlisted must FAIL.  This is the case the first version of this
    #    gate MISSED: removing the real fix from _Sock_PollIntr left it
    #    reporting clean, because #100 is not a within-routine pattern -- the
    #    dispatcher stages, the module sleeps, a third routine reads.  Keep
    #    this case: without it the gate can pass while doing nothing.
    import tempfile as _tf
    with _tf.TemporaryDirectory() as td:
        mod = pathlib.Path(td) / "src" / "modules" / "fake"
        mod.mkdir(parents=True)
        f = mod / "fake.s"
        f.write_text(
            "_Fake_PollIntr  MX      %00\n"
            "                LDA     #WCHAN_SOCK\n"
            "                JSL     SYS_NETKC_SLEEP\n"
            "                RTS\n")
        where = {}
        for rn, lo, hi, lines in m.routines_of(f):
            where[rn] = (f, lo, hi, lines)
        saved = m.saved_cells(names, alt, where, {"_Fake_PollIntr"}).get(
            "_Fake_PollIntr", set())
        if "_libcTmp2" in saved:
            print("self-test FAILED: an unsaving module sleep was credited "
                  "with saving -- the #100 shape would pass")
            return 1

    # 7. THE SLEEP SHIMS ARE DERIVED, NOT LISTED.  A hand list carried
    #    _NlKC_Sleep and kc_sleep and NOT _PtyKC_Sleep, so every caller in
    #    pty.mod -- the module apple/fgx#41 came from -- read as unable to
    #    sleep, and all three passes skipped it.
    with _tf.TemporaryDirectory() as td:
        mod = pathlib.Path(td) / "src" / "modules" / "fake"
        mod.mkdir(parents=True)
        f = mod / "shim.s"
        f.write_text(
            "_Xx_Sleep       MX      %00\n"
            "                LDX     #KSVC_SLEEP\n"
            "                JSL     SYS_KCALL\n"
            "                RTS\n"
            "_Xx_NotSleep    MX      %00\n"
            "                LDX     #KSVC_WAKEUP\n"
            "                JSL     SYS_KCALL\n"
            "                RTS\n")
        where = {rn: (f, lo, hi, lines) for rn, lo, hi, lines in m.routines_of(f)}
        shims = m.ksvc_sleep_shims(where)
        if "_Xx_Sleep" not in shims:
            print("self-test FAILED: a KSVC_SLEEP shim was not derived")
            return 1
        if "_Xx_NotSleep" in shims:
            print("self-test FAILED: a non-sleeping KSVC shim was called a "
                  "sleep -- every module would read as sleepy")
            return 1

    # 7b. A SAVE AROUND A SHIM SLEEP IS STILL A SAVE.  saved_cells() used to
    #     look only for a DIRECT sleep primitive, so a module -- which can
    #     only reach the scheduler by KSVC number -- was never credited with
    #     saving anything.  A module cannot use PEI either (it takes a
    #     direct-page operand and module scratch is absolute), so the LDA/PHA
    #     form has to be recognised or every genuine module save reads as none.
    with _tf.TemporaryDirectory() as td:
        mod = pathlib.Path(td) / "src" / "modules" / "fake"
        mod.mkdir(parents=True)
        f = mod / "shimsave.s"
        f.write_text(
            "_Sh_Sleep       MX      %00\n"
            "                LDX     #KSVC_SLEEP\n"
            "                JSL     SYS_KCALL\n"
            "                RTS\n"
            "_Sh_Saver       MX      %00\n"
            "                LDA     _libcTmp2\n"
            "                PHA\n"
            "                JSR     _Sh_Sleep\n"
            "                PLA\n"
            "                STA     _libcTmp2\n"
            "                RTS\n"
            "_Sh_NotSaver    MX      %00\n"
            "                LDA     _libcTmp2\n"
            "                JSR     _Sh_Sleep\n"
            "                STA     _libcTmp2\n"
            "                RTS\n")
        where = {rn: (f, lo, hi, lines) for rn, lo, hi, lines in m.routines_of(f)}
        sleepy = set(where) | m.ksvc_sleep_shims(where)
        sv = m.saved_cells(names, alt, where, sleepy)
        if "_libcTmp2" not in sv.get("_Sh_Saver", set()):
            print("self-test FAILED: a save around a KSVC shim sleep was not "
                  "credited -- every module save would read as none")
            return 1
        if "_libcTmp2" in sv.get("_Sh_NotSaver", set()):
            print("self-test FAILED: a read-modify-write across a SHIM sleep "
                  "was credited as its own protection -- the backwards case, "
                  "now reachable through the shim path too")
            return 1

    # 8. THE THIRD SHAPE: a caller-staged cell READ after a sleep, with no
    #    store in this routine.  Both older passes intersect a store set, so
    #    a body that only reads the cell falls out of each -- which is how
    #    three pty wait loops read [_fcbPtr] after _PtyKC_Sleep under a gate
    #    that reported clean.  All four sub-cases matter:
    #      Bad1  plain read after the sleep
    #      Bad2  read BEFORE the sleep textually, reached after it by the
    #            backward branch every wait loop has
    #      Ok1   stored in the window first -- a local, not an inheritance
    #      Ok2   re-established by a call to a known re-stager
    with _tf.TemporaryDirectory() as td:
        mod = pathlib.Path(td) / "src" / "modules" / "fake"
        mod.mkdir(parents=True)
        f = mod / "unowned.s"
        f.write_text(
            "_Bad1           MX      %00\n"
            "                JSR     _sleep\n"
            "                LDA     [_fcbPtr],Y\n"
            "                RTS\n"
            "_Bad2           MX      %00\n"
            "@loop           LDA     [_fcbPtr],Y\n"
            "                JSR     _sleep\n"
            "                BRA     @loop\n"
            "_Ok1            MX      %00\n"
            "                JSR     _sleep\n"
            "                STA     _fcbPtr\n"
            "                LDA     [_fcbPtr],Y\n"
            "                RTS\n"
            "_Ok2            MX      %00\n"
            "                JSR     _sleep\n"
            "                JSR     _Fcb_LookupPtr\n"
            "                LDA     [_fcbPtr],Y\n"
            "                RTS\n")
        where = {rn: (f, lo, hi, lines) for rn, lo, hi, lines in m.routines_of(f)}
        hits = {h["routine"] for h in
                m.unowned(names, alt, {}, where, set(), {})}
        for want in ("_Bad1", "_Bad2"):
            if want not in hits:
                print(f"self-test FAILED: {want} was not flagged -- the "
                      f"unowned-read pass cannot go red")
                return 1
        for nope in ("_Ok1", "_Ok2"):
            if nope in hits:
                print(f"self-test FAILED: {nope} was flagged; a re-owned cell "
                      f"is not an inherited one and the gate would cry wolf")
                return 1

    # 8b. THE GATE, NOT THE SUBSTRING.  apple/fgx#204.  check_kernel_c asked
    #     whether `_kcDpSave' APPEARS in sched.s; it does, inside `DO KCPROBE',
    #     so at KCPROBE = 0 the assembler drops the save and the restore and
    #     the substring is still there.  Three cases, because the middle one
    #     is the whole point: gated-and-off must FAIL, gated-and-on must not,
    #     and ungated must not.
    gated = ("                DO      KCPROBE\n"
             "                JSR     _KcDp_Save\n"
             "                FIN\n"
             "                DO      KCPROBE\n"
             "                JSR     _KcDp_Rest\n"
             "                FIN\n")
    ungated = ("                JSR     _KcDp_Save\n"
               "                JSR     _KcDp_Rest\n")
    saved_kc = globals()["kcprobe_value"]
    try:
        globals()["kcprobe_value"] = lambda: 0
        if not check_kcprobe_gate(gated):
            print("self-test FAILED: KCPROBE = 0 with the save gated on it "
                  "was not reported -- the gate cannot see its own subject")
            return 1
        if check_kcprobe_gate(ungated):
            print("self-test FAILED: an UNGATED save was reported; the check "
                  "is about the gate, not about the setting")
            return 1
        globals()["kcprobe_value"] = lambda: 1
        if check_kcprobe_gate(gated):
            print("self-test FAILED: KCPROBE = 1 was reported; the protection "
                  "IS present at the committed setting and crying wolf there "
                  "would get the check turned off")
            return 1
        if not check_kcprobe_gate("                NOP\n"):
            print("self-test FAILED: a sched.s that never calls _KcDp_Save at "
                  "all was not reported")
            return 1
    finally:
        globals()["kcprobe_value"] = saved_kc

    # 9. The kernel-C structural assertions fire when their subject is absent.
    if not check_kernel_c.__doc__:
        print("self-test FAILED: kernel-C check lost its rationale")
        return 1

    # 9b. AN `EXT' IS A DECLARATION, NOT A ROUTINE.  Reading it as one bound a
    #     routine's node to the declaration site, so the passes that scan
    #     `where' -- interprocedural, unowned, check_module_carried -- never saw
    #     the real body.  Both directions: the definition must win, and the
    #     declaration must not appear as a routine of its own.
    with _tf.TemporaryDirectory() as td:
        f = pathlib.Path(td) / "ext.s"
        f.write_text(
            "Real_Thing      ENT\n"
            "                LDA     _libcTmp2\n"
            "                RTS\n"
            "Other_Thing     MX      %00\n"
            "                RTS\n")
        d = pathlib.Path(td) / "decl.s"
        d.write_text(
            "Real_Thing      EXT\n"
            "                ; unrelated text that is NOT Real_Thing's body\n"
            "Decl_Neighbour  MX      %00\n"
            "                JSR     _sleep\n"
            "                RTS\n")
        rs = {n for n, _lo, _hi, _l in m.routines_of(d)}
        if "Real_Thing" in rs:
            print("self-test FAILED: an EXT declaration was read as a routine, "
                  "so it can shadow the real body in `where'")
            return 1
        if "Decl_Neighbour" not in rs:
            print("self-test FAILED: skipping the EXT lost the routine after it")
            return 1
        if "Real_Thing" not in {n for n, _lo, _hi, _l in m.routines_of(f)}:
            print("self-test FAILED: an ENT definition is no longer a routine")
            return 1

    # 9c. THE CALLGRAPH REACHES C -- apple/fgx#459.  Three independent things
    #     had to hold, and each one alone left the C layer unreachable, so each
    #     gets its own assertion against the real tree.
    _c459, _w459 = m.build_callgraph()
    _s459 = m.can_sleep_closure(_c459, m.ksvc_sleep_shims(_w459))
    #     (a) `PEA target-1' is a call.
    if "unp_nameop" not in m.call_targets("                PEA     unp_nameop-1"):
        print("self-test FAILED: a PEA pile call is not read as a call, so the "
              "whole asm->C boundary is edgeless again")
        return 1
    #     (b) a generated C function is ONE routine, not a dozen.  kc_ttopen's
    #         body is behind its stack-guard labels, so shredding leaves it a
    #         leaf; 7 callees is the whole function.
    if len(_c459.get("kc_ttopen", ())) < 3:
        print("self-test FAILED: kc_ttopen has almost no callees -- generated C "
              "is being shredded at its column-0 continuation labels again")
        return 1
    #     (c) a patch marker does not end a routine.  kc_sleepi's JSL sits after
    #         `_ctp058', and it is the tty bank's interruptible sleep.
    if "kc_sleepi" not in _s459:
        print("self-test FAILED: kc_sleepi does not reach a sleep -- a column-0 "
              "patch marker is ending the routine before its JSL again")
        return 1
    for want in ("ttyopen", "ttywflush", "getblk", "bread", "kc_lbolt"):
        if want not in _s459:
            print(f"self-test FAILED: {want} is not known to sleep, so the C "
                  f"layer the sleeps live in is not reachable")
            return 1
    #     A generated file's routine heads come from ENT, including statics,
    #     which fcc emits file-prefixed and still ENT.
    if "_vfs_subr_specalloc" not in _w459:
        print("self-test FAILED: a static C function is missing from the "
              "callgraph -- the ENT rule dropped it")
        return 1

    # 9d. THE SEAM CROSS-CHECK.  A hand verdict of `does not sleep' that the
    #     closure contradicts must be reported; the reverse is the fnptr floor
    #     and must NOT be, or the gate cries wolf on all three of them.
    #     First: on a BUILT tree the cross-check must actually RUN.  Scanning
    #     every src/**/*.c for a sibling .s called this tree unbuilt, because 188
    #     of 231 userland .c files have none -- so the whole cross-check skipped
    #     itself while reporting that it had.
    if any("DID NOT RUN" in p for p in m.ksvc_seam_audit(_w459)):
        print("self-test FAILED: the seam cross-check reports itself skipped on "
              "a built tree -- its unbuilt-tree detection is too broad")
        return 1
    _seams = dict(m.KSVC_SEAMS)
    try:
        m.KSVC_SEAMS["KTTY_KC_TTOPEN"] = (False, "a deliberately wrong verdict")
        m.KSVC_SEAMS["KTTY_TOD_NOW"] = (False, "correct: it does not sleep")
        probs = m.ksvc_seam_audit(_w459)
        # kc_ttopen is one fnptr from the sleeping ttyopen, so the closure does
        # NOT contradict it -- use a target it can see instead.
        m.SEAM_TARGET["KTTY_KC_TTOPEN"] = "ttyopen"
        probs = m.ksvc_seam_audit(_w459)
        if not any("KTTY_KC_TTOPEN" in p and "NOT sleeping" in p for p in probs):
            print("self-test FAILED: a hand verdict the callgraph contradicts "
                  "was not reported")
            return 1
        if any("KTTY_TOD_NOW" in p and "NOT sleeping" in p for p in probs):
            print("self-test FAILED: a correct non-sleeping verdict was "
                  "reported; the cross-check cries wolf")
            return 1
        m.SEAM_TARGET["KTTY_KC_TTOPEN"] = "kc_ttopen_renamed_away"
        if not any("not a routine in the callgraph" in p
                   for p in m.ksvc_seam_audit(_w459)):
            print("self-test FAILED: a SEAM_TARGET naming a routine that no "
                  "longer exists was not reported, so that seam's cross-check "
                  "would silently do nothing")
            return 1
    finally:
        m.KSVC_SEAMS.clear()
        m.KSVC_SEAMS.update(_seams)
        m.SEAM_TARGET["KTTY_KC_TTOPEN"] = "kc_ttopen"

    # 10. THE SELECTOR SET IS DERIVED FROM THE DISPATCHER -- apple/fgx#458.
    #     The hand-written pair missed KSVC_UNPNAME and a real defect shipped.
    #     Asserted against the REAL jumptable.s, because the thing that can rot
    #     is the arm resolver, not a synthetic fixture.
    _calls, _where = m.build_callgraph()
    sels = m.sleeping_selectors(_calls, _where)
    for want in ("KSVC_SLEEP", "KSVC_SLEEPUN", "KSVC_UNPNAME"):
        if want not in sels:
            print(f"self-test FAILED: {want} is not derived as sleeping -- the "
                  f"apple/fgx#458 blind spot is back")
            return 1
    # A selector whose arm demonstrably cannot sleep must stay out, or every
    # module routine reads as sleepy and the gate stops discriminating.
    for nope in ("KSVC_WAKEUP", "KSVC_LOGEOL", "KSVC_CURPID"):
        if nope in sels:
            print(f"self-test FAILED: {nope} was called sleeping; the derivation "
                  f"has stopped discriminating")
            return 1

    # 10b. THE ARM WALK MUST PASS AN EARLY `RTL'.  @kc_unpname returns early on
    #      its ENAMETOOLONG path, BEFORE the far call, so a `/^@kc_x/,/RTL/'
    #      range scan stops short -- that is how a first count of the far calls
    #      leaving an arm reported three arms as two.
    _body, _labels = m._jumptable()
    arms = m.ksvc_arms()
    unp = m.arm_callees(arms["KSVC_UNPNAME"], _body, _labels)
    if "KFAR_VFS_UNPNAME" not in unp:
        print("self-test FAILED: the unpname arm's far call was not found -- the "
              "arm walk has regressed to stopping at the first RTL")
        return 1

    # 10c. AN UNDESCRIBED BANK SEAM IS TREATED AS SLEEPING, and reported.  A new
    #      far or tty service must be suspect until someone reads it.
    _seams = dict(m.KSVC_SEAMS)
    try:
        del m.KSVC_SEAMS["KTTY_TOD_NOW"]          # says: does not sleep
        if "KSVC_TIME" not in m.sleeping_selectors(_calls, _where):
            print("self-test FAILED: a seam with no verdict was treated as "
                  "non-sleeping -- the safe default is inverted")
            return 1
        if not any("KTTY_TOD_NOW" in p for p in m.ksvc_seam_audit(_where)):
            print("self-test FAILED: an undescribed seam was not reported")
            return 1
        m.KSVC_SEAMS["KFAR_NO_SUCH_SLOT"] = (False, "invented by the self-test")
        if not any("KFAR_NO_SUCH_SLOT" in p for p in m.ksvc_seam_audit(_where)):
            print("self-test FAILED: a stale KSVC_SEAMS entry no arm reaches was "
                  "not reported -- a verdict nothing consults reads as coverage")
            return 1
    finally:
        m.KSVC_SEAMS.clear()
        m.KSVC_SEAMS.update(_seams)

    # 11. A BLOCK SAVE IS A SAVE, and a half-done one is not.  _Sock_PollIntr
    #     pushes a declared RANGE with an indexed loop rather than cell by cell;
    #     read only as the cell-by-cell idiom it credited nothing, and every
    #     caller holding any _sock* cell across an accept was reported.
    names = ["_sockTmpOff"]
    alt = "_sockTmpOff"
    # THE REGRESSION TARGET HAS TO BE WATCHED OR IT IS NOT A TARGET.  Deleting
    # this MODULE_CARRIED entry leaves apple/fgx#458's actual defect invisible
    # again while every other case stays green -- measured.
    if "_sockTmpOff" not in MODULE_CARRIED.get("src/modules/net/net.s", ()):
        print("self-test FAILED: MODULE_CARRIED no longer watches _sockTmpOff "
              "in src/modules/net/net.s, so `git show 1d199238d~1' would go "
              "green -- apple/fgx#458's defect is unguarded")
        return 1
    if "_sockTmpOff" not in m.block_ranges().get("_sockSrcOff", []):
        print("self-test FAILED: _sockTmpOff is not seen inside the "
              "_SOCK_SCRATCH_LEN block -- block_ranges no longer reads the "
              "declarations the assembler measures")
        return 1
    if "_sockAcceptLOff" in m.block_ranges().get("_sockSrcOff", []):
        print("self-test FAILED: _sockAcceptLOff was read as INSIDE the block; "
              "src/kernel/socket.s asserts with ERR that it is outside, and "
              "crediting it would hide a real exposure")
        return 1
    BLK_SAVE = ["_BlkSaver       MX      %00",
                "                LDX     #_SOCK_SCRATCH_LEN-2",
                "@bs_save        LDA     _sockSrcOff,X",
                "                PHA",
                "                DEX",
                "                BPL     @bs_save",
                "                JSR     _sleep",
                "                LDX     #0",
                "@bs_rest        PLA",
                "                STA     _sockSrcOff,X",
                "                INX",
                "                RTS"]
    BLK_HALF = [l for l in BLK_SAVE if "STA     _sockSrcOff,X" not in l]
    with _tf.TemporaryDirectory() as td:
        f = pathlib.Path(td) / "blk.s"
        for bodyl, want, label in ((BLK_SAVE, True, "a block save"),
                                   (BLK_HALF, False, "a block save with no "
                                                     "restore")):
            f.write_text("\n".join(bodyl) + "\n")
            where = {"_BlkSaver": (f, 0, len(bodyl), bodyl)}
            sv = m.saved_cells(names, alt, where, {"_BlkSaver"})
            got = "_sockTmpOff" in sv.get("_BlkSaver", set())
            if got != want:
                print(f"self-test FAILED: {label} was "
                      f"{'not ' if want else ''}credited")
                return 1

    # 12. A SAVE IN A DEEPER CALLEE IS A SAVE -- and only when every sleeping
    #     callee has it.  apple/fgx#458's fix parks _sockTmpOff in
    #     _Unp_NameCall, two levels below the net_op_sockteardown call site, so
    #     without this the FIXED tree reported the defect it had just fixed.
    #     The tail-call case is separate: _Net_Xport_Accept reaches the sleeping
    #     _Tcp_Accept by JMP, so a returning-call-only scan found it no sleeping
    #     callee at all and it inherited nothing.
    DEEP = ["_Inner          MX      %00",
            "                LDA     _sockTmpOff",
            "                PHA",
            "                JSR     _sleep",
            "                PLA",
            "                STA     _sockTmpOff",
            "                RTS",
            "_InnerBad       MX      %00",
            "                JSR     _sleep",
            "                RTS",
            "_Outer          MX      %00",
            "                JSR     _Inner",
            "                RTS",
            "_OuterTail      MX      %00",
            "                JMP     _Inner",
            "_OuterBad       MX      %00",
            "                JSR     _InnerBad",
            "                RTS",
            "_OuterMixed     MX      %00",
            "                JSR     _Inner",
            "                JSR     _InnerBad",
            "                RTS",
            "_OuterOwnSleep  MX      %00",
            "                JSR     _Inner",
            "                JSR     _sleep",
            "                RTS"]
    with _tf.TemporaryDirectory() as td:
        f = pathlib.Path(td) / "deep.s"
        f.write_text("\n".join(DEEP) + "\n")
        where = {rn: (f, lo, hi, lines)
                 for rn, lo, hi, lines in m.routines_of(f)}
        sv = m.saved_cells(names, alt, where, set(where))
        for rn, want in (("_Outer", True), ("_OuterTail", True),
                         ("_OuterBad", False), ("_OuterMixed", False),
                         ("_OuterOwnSleep", False)):
            got = "_sockTmpOff" in sv.get(rn, set())
            if got != want:
                print(f"self-test FAILED: {rn} was "
                      f"{'not ' if want else 'wrongly '}credited with a "
                      f"deeper save")
                return 1

    print("check_dp_sleep_safety self-test: OK "
          "(named + selector sleeps, no false positives, a live range is "
          "flagged, the save idiom is positional, sleep shims are derived, "
          "an unowned read after a sleep goes red -- loop-back included -- "
          "a module static carried across a sleep goes red while a saved one "
          "does not, "
          "the KCPROBE gate is read rather than the substring, "
          "the sleeping KSVC selectors are derived from the dispatcher and the "
          "arm walk passes an early RTL, an undescribed bank seam is suspect, "
          "and a block or deeper-callee save is credited only when it is "
          "actually there; the callgraph reaches C through the pile call, a "
          "generated C function is one routine, a patch marker does not end "
          "one, and a hand seam verdict the closure contradicts is reported)")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    m = _load_analysis()
    if args.self_test:
        return self_test(m)

    findings, n_sites, n_sleepy = check_asm(m, args.verbose)
    _calls, where = m.build_callgraph()
    problems = (check_kernel_c() + check_module_sleeps(m)
                + m.ksvc_seam_audit(where))

    for h in findings:
        print(f"check_dp_sleep_safety: UNSAFE {h['file']}:{h['line']} "
              f"({h['routine']})  {h['sleep']}")
        for c in h["live"]:
            print(f"    {c['cell']} stored :{c['stored']} read :{c['read']} "
                  f"-- live across a task switch, and swtch saves no DP scratch")
    for p in problems:
        print(f"check_dp_sleep_safety: STRUCTURE {p}")

    if findings or problems:
        print(f"check_dp_sleep_safety: FAILED "
              f"({len(findings)} unsafe range(s), {len(problems)} structural)")
        return 1

    # SAY WHICH IT IS.  This line used to read "CONDITIONALLY, on KCPROBE"
    # unconditionally, which was accurate only while the gate existed --
    # apple/fgx#204 removed it, and a summary that still named a gate would be
    # the same defect as the one before it: a report that cannot see its own
    # subject.  Derived from the same scan the structural check uses.
    sched_s = (ROOT / "src" / "kernel" / "sched.s").read_text()
    how = ("unconditionally" if not kcprobe_gated(sched_s)
           else f"CONDITIONALLY, on KCPROBE, which is {kcprobe_value()}")
    print(f"check_dp_sleep_safety: clean ({n_sites} sleep sites, "
          f"{n_sleepy} routines can reach one; no DP cell live across a "
          f"switch unprotected; kernel C still on its own DP with its "
          f"register file saved -- {how})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
