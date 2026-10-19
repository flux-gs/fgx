#!/usr/bin/env python3
"""Which direct-page cells are LIVE across a sleep?

Phase 1 of the bank-0 / kernel-scratch assessment. Companion to
tools/dp_scratch_census.py, which answers "what cells exist and how are they
addressed"; this one answers "which of them cross a task switch".

METHOD.  `swtch` saves SE_KernSP / UserSP / UserDP / CallerBank and NO
direct-page scratch, so any cell written before a sleep and read after it is
carrying a value another task is free to overwrite.  For each sleep site we
take the enclosing routine (column-0 label to column-0 label) and report cells
STORED before the sleep and READ after it, in the same routine.

WHAT THIS IS NOT.  It is a within-routine dataflow approximation, and every hit
is a CANDIDATE requiring a read:

  - It does not follow calls.  A cell stored in a callee and read after the
    sleep here is missed (this is the #100 shape: the dispatcher staged
    _libcTmp2 in syscall.s and the module read it after sleeping).  Use
    --callers to widen.
  - It does not do path analysis, so a store on a branch never taken with the
    sleep still counts.
  - A routine that saves/restores the cell around the sleep still shows up;
    the SAVED class has to be recognised by reading the code.
  - A FUNCTION-POINTER CALL REACHES NOTHING, and it is the remaining hole.
    fcc dispatches one by pushing a computed address and RTL-ing to it
    (`LDA _fcc_fpr0 / DEC / PHA / RTL'), so there is no target name to follow.
    54 routines contain one, and the tables behind them are the ones that
    matter: `linesw[t_line].l_open' is how `kc_ttopen' reaches `ttyopen', and
    `VOP_INACTIVE' is how `vrele' reaches a filesystem.  So `ttyopen' and
    `ttywflush' are known to sleep while `kc_ttopen' -- one fnptr away -- is
    not.  That is why KSVC_SEAMS carries the verdict for the C behind each
    bank seam by hand: eleven of its fourteen are now corroborated by the
    closure, and the three that are not are exactly the fnptr dispatches.
    TREATING EVERY INDIRECT CALL AS ABLE TO SLEEP WAS MEASURED AND NOT TAKEN.
    It found a real defect on the way -- apple/fgx#460, the console font loader
    holding a file descriptor in shared render scratch across a sleeping read,
    fixed -- but as a standing setting it does not pay.  Covering fcc's form
    alone puts 54 routines in and takes the sleepy set to 366 with nothing to
    report; adding the three hand-written `JSR ('/`JMP (' sites makes it 57 and
    387 and reports `FGX_Entry' twice (src/kernel/main.s:641,719), which is the
    BOOT path, single-threaded before any second task exists.  Worse, it makes
    the KSVC_SEAMS cross-check in ksvc_seam_audit() meaningless: an
    over-approximated `can sleep' is not corroboration, so three seams whose C
    was READ and found not to sleep start contradicting their own verdicts.
    A precise closure that stops at the pointer is the more useful one.

So it OVER-reports, which is the correct direction for a risk register: the
output is a work list to walk, not a defect list.
"""

import argparse
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
DPMAP = REPO / "include" / "dpmap.s"

# Two spellings, and MISSING THE SECOND ONE UNDER-REPORTED THE WHOLE CENSUS.
#
#   1. the sleep primitive as a JUMP OPERAND      -- `JSR _sleep`
#   2. the sleep SELECTOR IN A REGISTER           -- `LDX #KSVC_SLEEP` then
#                                                    `JSL SYS_KCALL`
#
# Form 2 is how EVERY module sleeps: pty.mod (`pty.s:176-178`) and vfs.mod
# (`kc_sys.s:121-127`) both put the service number in X and call the one
# multiplexed kernel entry, so the sleep's NAME never appears as a jump target.
# A name-only regex reports those files as sleep-free -- and pty is where
# apple/fgx#41, this bug class's other historical defect, actually lived.
#
# WHICH SELECTORS ARE FORM 2 IS DERIVED, NOT LISTED -- see sleeping_selectors()
# below.  A hand-written pair (`KSVC_SLEEP|KSVC_SLEEPUN') was the whole list
# until apple/fgx#458, and it cost a real defect: `_Unp_NameCall' selects
# KSVC_UNPNAME, whose arm reaches `vrele' in far-bank C, so the sleep was
# invisible and `net_op_sockteardown' cleared SOCK_InUse on another task's live
# descriptor (`1d199238d').
# `kc_sleepi' and `kc_lbolt' -- the tty bank's interruptible sleep and its lbolt
# wait -- are NOT named here and do not need to be.  Each reaches the scheduler
# through a far shim it calls by name (`JSL _FarSh_Sleep', `JSL _FarSh_SleepUn'),
# so the closure derives both once the callgraph can see their bodies.  It could
# not until apple/fgx#459: the `JSL' sits after the `_ctp058' patch marker, a
# column-0 label that used to end the routine, so `kc_sleepi' read as a four-line
# leaf.  Naming them here instead would be the wrong fix -- a primitive list that
# grows per bank is the hand list this file keeps replacing with a derivation.
_SLEEP_NAMED = (
    r"\b(JSR|JSL|JMP|JML)\s+_?(sleep|sleepUn|Sleep|swtch|_Sched_Yield|"
    r"SYS_NETKC_SLEEP|_NlKC_Sleep|kc_sleep)\b"
)
# A routine head: a label starting in column 0 that is not a local (@) label.
LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\b")

# AN `EXT' IS A DECLARATION, NOT A ROUTINE, and reading it as one bound 15
# routines to the wrong body.  `Kern_LogStr ENT' defines it in src/kernel/log.s
# and `Kern_LogStr EXT' declares it in src/drivers/block/blkcache.s; both are
# column-0 labels, so `where' kept whichever file came last and the body
# analysed for the routine was the declaration plus the unrelated text after it.
# `calls' unions every site, so the EDGES were right and only the body was
# wrong -- which matters because `interprocedural', `unowned' and
# `check_module_carried' all scan `where', so the real body of `Blk_Read',
# `Blk_Write' and thirteen others was never scanned at all.  That is the
# hazard-hiding direction.  Measured 2026-09-20: 20 names declared EXT
# somewhere and defined elsewhere, 15 of them binding to the EXT.
EXT_DECL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\s+EXT\b")

# A PATCH SITE IS NOT A ROUTINE EITHER -- apple/fgx#459.  The bank-byte patchers
# find their sites by a column-0 marker (`gen_wavee_bankpatch.py:81' matches
# `_we\d+', gen_far_bankpatch.py matches `_kfp\d+'), and a patch site sits in the
# MIDDLE of a routine by its nature: it labels the very instruction whose operand
# gets fixed up.  Read as a routine head it cuts the routine in two and the
# second half's calls are attributed to the marker.
#
# That is not cosmetic.  `kc_sleepi' (src/kernel/tty/kc_sys.s) is the tty bank's
# interruptible sleep, and its `JSL _FarSh_Sleep' sits after `_ctp058' -- so the
# sleep belonged to the marker, `kc_sleepi' read as a four-line leaf, and nothing
# that called it inherited a sleep.  513 markers in nine families.
PATCH_MARKER_RE = re.compile(r"^_(kfp|ktp|ctp|cfp|kcb|kcm|kbid|we|qmul)\d+\b")

# An fcc-generated routine head carries `ENT'; every other column-0 label in such
# a file CONTINUES it.  fcc emits the stack-guard arms (`<fn>_stkovf',
# `<fn>_stkok'), the branch labels (`_<file>_L<n>') and the frame constants
# (`<fn>_FRAMESIZE', `<fn>_STKGUARD') all in column 0, so `kc_ttopen' ended eight
# lines in, before its body.  Measured: 770 ENT heads against 13,952 other
# column-0 labels, and treating only ENT as a head takes the tree from 20,462
# nominal routines to 6,660 real ones.  STATIC C functions are covered -- fcc
# emits them file-prefixed and still ENT (`_vfs_subr_specalloc ENT').
ENT_DECL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+ENT\b")


def is_generated(path):
    """True for an fcc-generated .s -- it has a .c sibling."""
    try:
        return path.with_suffix(".c").exists()
    except (AttributeError, OSError):
        return False


def routine_heads(lines, generated=False):
    """Indices of the column-0 labels that actually START a routine."""
    if generated:
        return [i for i, l in enumerate(lines) if ENT_DECL_RE.match(l)]
    return [i for i, l in enumerate(lines)
            if LABEL_RE.match(l)
            and not EXT_DECL_RE.match(l)
            and not PATCH_MARKER_RE.match(l)]


def strip_comment(line):
    if line.lstrip().startswith("*"):
        return ""
    i = line.find(";")
    return line if i < 0 else line[:i]


def relname(path):
    """Repo-relative if possible, else the path as given.

    Callers include check_dp_sleep_safety's self-test, which analyses
    synthetic routines written to a temp directory; those are legitimately
    outside the tree and must not crash the analysis.
    """
    try:
        return str(path.relative_to(REPO))
    except ValueError:
        return str(path)


def dp_cells():
    names, in_dum = [], False
    for raw in DPMAP.read_text().splitlines():
        s = strip_comment(raw).strip()
        if s.startswith("DUM"):
            in_dum = True
            continue
        if s.startswith("DEND"):
            in_dum = False
            continue
        if in_dum:
            m = re.match(r"^([_A-Za-z][A-Za-z0-9_]*)\s+(DS|EQU)\s", strip_comment(raw))
            if m:
                names.append(m.group(1))
    return names


def analyse(path, names, alt):
    store = re.compile(r"\b(STA|STX|STY|STZ|INC|DEC)\s+\|?<?(" + alt + r")\b")
    read = re.compile(r"(?:\[\s*|\(\s*|\b(?:LDA|LDX|LDY|CMP|CPX|CPY|AND|ORA|"
                      r"EOR|ADC|SBC|BIT)\s+\|?<?)(" + alt + r")\b")
    lines = path.read_text(errors="replace").splitlines()

    # Routine boundaries.
    heads = routine_heads(lines, is_generated(path))
    def routine_of(i):
        lo = max([h for h in heads if h <= i], default=0)
        hi = min([h for h in heads if h > i], default=len(lines))
        return lo, hi

    out = []
    for i, raw in enumerate(lines):
        if not sleep_re().search(strip_comment(raw)):
            continue
        lo, hi = routine_of(i)
        before, after = {}, {}
        for j in range(lo, i):
            for m in store.finditer(strip_comment(lines[j])):
                before.setdefault(m.group(2), j + 1)
        for j in range(i + 1, hi):
            for m in read.finditer(strip_comment(lines[j])):
                after.setdefault(m.group(1), j + 1)
        live = sorted(set(before) & set(after))
        out.append({
            "file": relname(path),
            "line": i + 1,
            "routine": LABEL_RE.match(lines[lo]).group(1) if lo < len(lines)
                       and LABEL_RE.match(lines[lo]) else "?",
            "sleep": strip_comment(raw).strip()[:70],
            "live": [{"cell": c, "stored": before[c], "read": after[c]}
                     for c in live],
        })
    return out


# JMP/JML/BRL are TAIL CALLS and propagate "can sleep" exactly as JSR/JSL do.
# Omitting them under-reports, which is the dangerous direction: _Net_Xport_Recv
# reaches the sleeping _Tcp_RecvCore by `JMP`, and was invisible without this.
#
# `PEA target-1' IS A CALL -- apple/fgx#459.  It is how fcc calls C: push the
# return address, push target-1, RTL.  Matching only the jump mnemonics left the
# ENTIRE C LAYER edgeless, so `namei', `getblk', `vrele' and `ttyopen' were
# leaves -- and that is where the sleeps live.  14 hand-written .s files reach C
# this way, `src/kernel/far/vfs_seam_entry.s:1271' among them.
CALL_RE = re.compile(
    r"\b(JSR|JSL|JMP|JML|BRL)\s+\|?<?([A-Za-z_][A-Za-z0-9_]*)"
    r"|\bPEA\s+([A-Za-z_][A-Za-z0-9_]*)-1\b")

# Only JSR/JSL RETURN here, so only they can have a "read after the call" in
# this routine.  A tail call does not come back.
#
# A PILE CALL DOES RETURN, and to the return address pushed just before it --
# so it belongs here too.  It is written as the SECOND of two PEAs
# (`PEA <ret>-1' then `PEA <target>-1'), and only the target is the callee, so
# the pair is matched as a whole rather than each PEA counting as a call.
RETURNING_CALL_RE = re.compile(r"\b(JSR|JSL)\s+\|?<?([A-Za-z_][A-Za-z0-9_]*)")
PILE_CALL_RE = re.compile(r"\bPEA\s+([A-Za-z_][A-Za-z0-9_]*)-1\b")


def call_targets(line):
    """Every routine this line calls, tail calls or pile-calls."""
    out = []
    for m in CALL_RE.finditer(line):
        out.append(m.group(2) or m.group(3))
    return out

# The primitives.  A routine that calls one of these can sleep; so can any
# routine that calls such a routine, transitively.
#
# THE MODULE SHIMS ARE DERIVED, NOT LISTED, and that correction is the point of
# ksvc_sleep_shims() below.  A module cannot name `_sleep': it puts a service
# number in X and JSLs the gateway, so it reads as sleep-free to a scan that
# looks for the primitive.  This set used to carry the shims by hand -- and it
# had `_NlKC_Sleep' and `kc_sleep' but NOT `_PtyKC_Sleep', so pty.mod was
# invisible to every pass in this file.  pty is where apple/fgx#41 lived, and
# this module's own docstring cites it as the reason the shims are covered at
# all.  A hand list is the wrong shape for "every module that sleeps"; the
# KSVC number is the fact, so read that.
SLEEP_PRIMS = {"_sleep", "_sleepUn", "swtch",
               "SYS_NETKC_SLEEP", "_Sched_Yield"}

# `LDX #KSVC_<x>' reaching a `JSL SYS_KCALL' -- the only way a module can reach
# kernel code at all.  Both must appear in the same routine; the load alone is a
# constant nobody dispatched.
KCALL_RE = re.compile(r"\bJSL\s+\|?<?SYS_KCALL\b")
KSVC_LDX_RE = re.compile(r"\bLDX\s+#(KSVC_[A-Z0-9_]+)\b")

JUMPTABLE = REPO / "src" / "kernel" / "jumptable.s"

# The dispatch chain in _Sys_KCallImpl: `CPX #KSVC_x' / `BNE @next' / `BRL @arm'.
KSVC_CPX_RE = re.compile(r"\bCPX\s+#(KSVC_[A-Z0-9_]+)\b")
ANY_LABEL_RE = re.compile(r"^(@?[A-Za-z_][A-Za-z0-9_]*)")
JUMP_RE = re.compile(r"\b(BRA|BRL|JMP|JML)\s+\|?<?(@?[A-Za-z_][A-Za-z0-9_]*)")
COND_RE = re.compile(r"\b(BCC|BCS|BEQ|BNE|BPL|BMI|BVC|BVS)\s+"
                     r"\|?<?(@?[A-Za-z_][A-Za-z0-9_]*)")
RET_RE = re.compile(r"\b(RTS|RTL|RTI)\b")

# WHAT THE C BEHIND EACH BANK SEAM DOES, audited once by reading it.
#
# A KSVC arm may leave the core bank by `JSL KFAR_*' (far kernel bank) or
# `JSL KTTY_*' (tty bank).  Both are EQUs into a slot table, so the callgraph
# stops dead at them -- and what sits behind three of them SLEEPS.  The slot
# tables cannot be read positionally to recover the symbol: far.s puts TWO
# `JMP's in slot 27 under `DO KCPROBE', so counting entries drifts by one and
# resolves KFAR_VFS_UNPNAME to `_Far_ConSetBackend'.  Even with the symbol in
# hand the verdict would need the C callgraph, which does not exist here (see
# the note by _SLEEP_NAMED).  So the verdict is recorded by name.
#
# A SEAM THAT IS NOT LISTED IS TREATED AS SLEEPING, and that is the direction
# this file's doctrine demands: omitting a sleeping seam hides a hazard, while
# a needless `True' only produces a finding, and a finding gets read.  So a new
# far or tty service is suspect until somebody reads it and writes the reason
# down here.  ksvc_seam_audit() reports both halves of a stale table: a seam an
# arm reaches that is not listed, and a listed seam no arm reaches any more.
KSVC_SEAMS = {
    # --- reaches C that sleeps ---
    "KFAR_VFS_UNPNAME": (True,
        "unp_nameop (far-bank C, src/kernel/vfs/vfs_syscalls.c) -> vrele -> "
        "VOP_INACTIVE -> block I/O.  UNP_OP_UNBIND is the arm that sleeps, and "
        "apple/fgx#458 is the defect it hid."),
    "KTTY_KC_TTOPEN": (True,
        "kc_ttopen -> linesw[t_line].l_open = ttyopen -> ttywflush -> ttywait "
        "-> kc_sleep(&tp->t_outq) (src/kernel/tty/tty.c).  A non-NTTYDISC line "
        "drains its output queue on open."),
    "KTTY_KC_TTCLOSE": (True,
        "kc_ttclose -> ttylclose -> ttywflush -> ttywait -> kc_sleep "
        "(src/kernel/tty/tty.c).  An ordinary close DRAINS; only FNDELAY "
        "throws the queues away."),
    # --- does not sleep ---
    "KFAR_CON_SETBACKEND": (False,
        "_Far_ConSetBackend: stores a renderer's address in far-bank statics.  "
        "Far-bank ASSEMBLY, no pile call into C on the path."),
    "KFAR_CON_RENDERALL": (False,
        "_fw_Con_RenderAll (src/kernel/far/far.s): redraws from the VC state "
        "block.  Far-bank assembly, no pile call into C."),
    "KTTY_TOD_NOW": (False,
        "tod_now (src/kernel/tty/kern_time.c) -> tod_read -> kc_todsnap: copies "
        "the kernel clock's core words under SEI, then arithmetic."),
    "KTTY_KC_TTMODEM": (False,
        "kc_ttmodem -> ttymodem: a carrier transition -- t_state, SIGHUP/"
        "SIGCONT and ttyflush.  ttyflush DISCARDS, it does not wait."),
    "KTTY_KC_TTSELECT": (False,
        "kc_ttselect -> ttyselect: records a selecting process and tests the "
        "queues.  Select is the call that must NOT block."),
    "KTTY_KC_TTCARRIER": (False, "kc_ttcarrier: reads TS_CARR_ON from t_state."),
    "KTTY_KC_TTSTOPPED": (False, "kc_ttstopped: reads TS_TTSTOP from t_state."),
    "KTTY_KC_PTCINPUT": (False,
        "kc_ptcinput -> ttyinput plus kc_wakeup.  Enqueues a character and "
        "wakes a waiter; a wakeup is not a wait."),
    "KTTY_KC_PTCWRITABLE": (False, "kc_ptcwritable: measures queue room."),
    "KTTY_KC_PTYOPROC": (False,
        "kc_ptyoproc: sets the master's output-pending flag and wakes it."),
    "KTTY_KC_TTOUTQRUN": (False,
        "kc_ttoutq_run -> getc/ndqb: drains the output queue into the caller's "
        "buffer, taking only what is already there."),
}
SEAM_RE = re.compile(r"^(KFAR_|KTTY_)[A-Z0-9_]+$")

# The routine each seam lands on, so ksvc_seam_audit() can cross-check the hand
# verdict above against what the callgraph now derives.  Recorded here rather
# than resolved from the slot tables: far.s puts TWO `JMP's in slot 27 under
# `DO KCPROBE', so counting entries positionally drifts by one, and a
# cross-check against the `; slot N' comments reports 47 mismatches in far.s.
# A name here that is not a routine any more is reported, not ignored.
SEAM_TARGET = {
    "KFAR_VFS_UNPNAME":    "unp_nameop",
    "KFAR_CON_SETBACKEND": "_Far_ConSetBackend",
    "KFAR_CON_RENDERALL":  "_fw_Con_RenderAll",
    "KTTY_TOD_NOW":        "tod_now",
    "KTTY_KC_TTOPEN":      "kc_ttopen",
    "KTTY_KC_TTCLOSE":     "kc_ttclose",
    "KTTY_KC_TTMODEM":     "kc_ttmodem",
    "KTTY_KC_TTSELECT":    "kc_ttselect",
    "KTTY_KC_TTCARRIER":   "kc_ttcarrier",
    "KTTY_KC_TTSTOPPED":   "kc_ttstopped",
    "KTTY_KC_PTCINPUT":    "kc_ptcinput",
    "KTTY_KC_PTCWRITABLE": "kc_ptcwritable",
    "KTTY_KC_PTYOPROC":    "kc_ptyoproc",
    "KTTY_KC_TTOUTQRUN":   "kc_ttoutq_run",
}


def _jumptable():
    """(body, labels) for jumptable.s -- comment-stripped lines and label index."""
    lines = JUMPTABLE.read_text(errors="replace").splitlines()
    labels = {}
    for i, l in enumerate(lines):
        mm = ANY_LABEL_RE.match(l)
        if mm:
            labels.setdefault(mm.group(1), i)
    return [strip_comment(l) for l in lines], labels


def ksvc_arms():
    """{selector: arm label} from the CPX/BRL dispatch chain in jumptable.s.

    A selector with no arm is absent rather than wrong: KSVC_TTYOUTQREAD is
    declared in include/modules.s and its arm was retired (jumptable.s says so
    and that it never had a caller), so the service answers ENOSYS.  A module
    that selects one is reported by ksvc_seam_audit().
    """
    body, _labels = _jumptable()
    arms = {}
    for i, l in enumerate(body):
        mm = KSVC_CPX_RE.search(l)
        if not mm:
            continue
        for j in range(i + 1, min(i + 5, len(body))):
            b = JUMP_RE.search(body[j])
            if b:
                arms[mm.group(1)] = b.group(2)
                break
    return arms


def arm_callees(label, body, labels):
    """Everything an arm can call, walking its control flow line by line.

    A RANGE SCAN IS NOT SAFE HERE.  `@kc_unpname' has an early `RTL' on its
    ENAMETOOLONG path, BEFORE the far call that matters, so a
    `/^@kc_x/,/RTL/' window stops short -- that is how a first count of the
    far calls leaving an arm reported three arms as two.  Following branches
    instead also picks up the shared epilogues arms `BRL' into, and steps over
    the `_kfp*'/`_ktp*' far-call markers, which sit in column 0 and would
    otherwise end the arm as if they were routine heads.

    An out-of-file branch target is recorded as a callee: a tail call reaches
    the same code a JSR would.
    """
    start = labels.get(label)
    if start is None:
        return None
    seen, work, callees = set(), [start], set()
    while work:
        i = work.pop()
        while 0 <= i < len(body) and i not in seen:
            seen.add(i)
            l = body[i]
            c = RETURNING_CALL_RE.search(l)
            if c:
                callees.add(c.group(2))
            for cb in COND_RE.finditer(l):
                t = labels.get(cb.group(2))
                if t is None:
                    callees.add(cb.group(2))
                elif t not in seen:
                    work.append(t)
            u = JUMP_RE.search(l)
            if u:
                t = labels.get(u.group(2))
                if t is None:
                    callees.add(u.group(2))
                    break
                i = t
                continue
            if RET_RE.search(l):
                break
            i += 1
    return callees


def sleeping_selectors(calls, where):
    """The KSVC selectors whose arm can sleep -- DERIVED, not listed.

    apple/fgx#458.  For each arm: walk what it can call, and call the selector
    sleeping when either

      - a callee is a routine the primitive closure already calls sleepy (the
        core bank is fully analysable: every arm's callees have an asm body and
        name `_sleep' when they sleep), or
      - it crosses a bank seam that KSVC_SEAMS does not prove non-sleeping.

    The primitive closure is used rather than the full one on purpose: only the
    shims it would add are MODULE routines, and a core-bank arm never calls
    module code, so there is no fixed point to chase.
    """
    prim = can_sleep_closure(calls)
    body, labels = _jumptable()
    out = set()
    for sel, label in ksvc_arms().items():
        cs = arm_callees(label, body, labels)
        if cs is None:
            continue
        if any(c in prim for c in cs):
            out.add(sel)
            continue
        for c in cs:
            if SEAM_RE.match(c) and KSVC_SEAMS.get(c, (True,))[0]:
                out.add(sel)
                break
    return out


def ksvc_seam_audit(where):
    """Where the KSVC tables have gone stale.  A guard that matches nothing
    does nothing, so say so rather than going quietly clean."""
    problems = []
    body, labels = _jumptable()
    arms = ksvc_arms()
    reached = set()
    for sel, label in arms.items():
        cs = arm_callees(label, body, labels) or set()
        if arm_callees(label, body, labels) is None:
            problems.append(
                f"KSVC dispatch names an arm `{label}' for {sel} that is not a "
                f"label in {relname(JUMPTABLE)} -- the arm resolver is broken, "
                f"so every selector's sleep verdict is unproven")
        reached |= {c for c in cs if SEAM_RE.match(c)}
    for c in sorted(reached - set(KSVC_SEAMS)):
        problems.append(
            f"a KSVC arm crosses the bank seam `{c}', which KSVC_SEAMS does not "
            f"describe.  It is being treated as SLEEPING, which is the safe "
            f"default; read what is behind it and record the reason")
    for c in sorted(set(KSVC_SEAMS) - reached):
        problems.append(
            f"KSVC_SEAMS describes `{c}', which no KSVC arm reaches any more "
            f"-- a stale verdict nothing consults")

    # THE HAND VERDICTS ARE CROSS-CHECKED WHERE THE CLOSURE CAN NOW SEE PAST THE
    # SEAM -- apple/fgx#459 gave it the C.  Only ONE direction is a problem: a
    # seam recorded as NOT sleeping whose named target the closure says sleeps.
    # The other direction is the fnptr floor and is expected -- `kc_ttopen' is
    # one `linesw[].l_open' away from the sleeping `ttyopen', so a `True' here
    # stays more conservative than the closure, which is the safe side.
    _calls, _where = build_callgraph()
    for c, tgt in sorted(SEAM_TARGET.items()):
        if c not in KSVC_SEAMS:
            problems.append(
                f"SEAM_TARGET names `{c}', which KSVC_SEAMS does not describe")

    # THE CROSS-CHECK NEEDS THE GENERATED ASM, WHICH IS NOT IN GIT.  fcc's output
    # is gitignored (.gitignore:360 for src/kernel/tty/tty_dev.s among others), so
    # in a fresh checkout the C side of every seam is simply absent -- and reading
    # that as "the target was renamed" reported ten structural problems on an
    # unbuilt tree, which is a check firing at its own subject being missing.
    # Say the cross-check did not run instead, because a check whose tool did not
    # run must not read as a pass.
    # src/kernel ONLY: every kernel .c has a sibling .s in a built tree (43 of
    # 43), while userland .c files link straight to binaries and 188 of 231 have
    # no sibling at all -- scanning those called a built tree unbuilt.
    # And only units the build graph compiles: a probe gate's C has no edge
    # unless that gate is on, so its .s is absent from a built tree too.
    ninja = REPO / "build.ninja"
    graph = ninja.read_text() if ninja.exists() else None
    unbuilt = sorted(relname(c.with_suffix(".s"))
                     for c in (REPO / "src" / "kernel").rglob("*.c")
                     if not c.with_suffix(".s").exists()
                     and (graph is None or
                          f"build {relname(c.with_suffix('.s'))} " in graph))
    if unbuilt:
        problems.append(
            f"THE SEAM CROSS-CHECK DID NOT RUN: {len(unbuilt)} fcc-generated .s "
            f"files are absent, so the C behind each bank seam is unreachable "
            f"and the KSVC_SEAMS verdicts are unverified here.  Build the tree "
            f"to check them (first missing: {unbuilt[0]})")
        return problems

    sleepy = can_sleep_closure(_calls, ksvc_sleep_shims(_where))
    for c, (sleeps, _reason) in sorted(KSVC_SEAMS.items()):
        tgt = SEAM_TARGET.get(c)
        if tgt is None:
            continue
        if tgt not in where:
            problems.append(
                f"SEAM_TARGET says `{c}' lands on `{tgt}', which is not a "
                f"routine in the callgraph -- renamed, so the cross-check on "
                f"this seam silently does nothing")
        elif not sleeps and tgt in sleepy:
            problems.append(
                f"KSVC_SEAMS records `{c}' as NOT sleeping, but the callgraph "
                f"says its target `{tgt}' can reach a sleep.  One of the two is "
                f"wrong, and the hand verdict is the one with no test")
    # A module selecting a service with no arm gets ENOSYS, not a sleep; but it
    # is a bug in the module, and this is the one pass that can see it.
    for name, (path, lo, hi, lines) in sorted(where.items()):
        b = [strip_comment(l) for l in lines[lo:hi]]
        if not any(KCALL_RE.search(l) for l in b):
            continue
        for l in b:
            for mm in KSVC_LDX_RE.finditer(l):
                if mm.group(1) not in arms:
                    problems.append(
                        f"{relname(path)}: {name} selects {mm.group(1)}, which "
                        f"has no arm in _Sys_KCallImpl -- the service answers "
                        f"ENOSYS")
    return problems


_SLEEP_RE = None
_KSVC_SLEEP_RE = None


def _derive():
    global _SLEEP_RE, _KSVC_SLEEP_RE
    calls, where = build_callgraph()
    sels = sleeping_selectors(calls, where) or {"KSVC_SLEEP"}
    alt = "|".join(sorted(sels))
    _SLEEP_RE = re.compile(_SLEEP_NAMED + r"|#\s*(" + alt + r")\b")
    _KSVC_SLEEP_RE = re.compile(r"\bLDX\s+#(" + alt + r")\b")


def sleep_re():
    """Every spelling of `this line sleeps', selectors included."""
    if _SLEEP_RE is None:
        _derive()
    return _SLEEP_RE


def ksvc_sleep_re():
    """`LDX #<selector whose arm sleeps>'."""
    if _KSVC_SLEEP_RE is None:
        _derive()
    return _KSVC_SLEEP_RE


def set_sleeping_selectors(sels):
    """Pin the derived set -- for --self-test, which needs a known answer."""
    global _SLEEP_RE, _KSVC_SLEEP_RE
    alt = "|".join(sorted(sels))
    _SLEEP_RE = re.compile(_SLEEP_NAMED + r"|#\s*(" + alt + r")\b")
    _KSVC_SLEEP_RE = re.compile(r"\bLDX\s+#(" + alt + r")\b")


def ksvc_sleep_shims(where):
    """Routines that sleep by KSVC number rather than by naming a primitive."""
    out = set()
    for name, (path, lo, hi, lines) in where.items():
        body = [strip_comment(l) for l in lines[lo:hi]]
        if any(ksvc_sleep_re().search(l) for l in body) and \
           any(KCALL_RE.search(l) for l in body):
            out.add(name)
    return out


def routines_of(path):
    """[(name, lo, hi, lines)] for each column-0-labelled routine in a file."""
    lines = path.read_text(errors="replace").splitlines()
    heads = [(i, LABEL_RE.match(lines[i]).group(1))
             for i in routine_heads(lines, is_generated(path))]
    out = []
    for k, (i, name) in enumerate(heads):
        hi = heads[k + 1][0] if k + 1 < len(heads) else len(lines)
        out.append((name, i, hi, lines))
    return out


_CALLGRAPH = None


def build_callgraph():
    """{routine: set(callees)} plus {routine: (path, lo, hi, lines)}.

    Memoised: the sleep-selector derivation needs it too, and it reads every
    .s in src/.
    """
    global _CALLGRAPH
    if _CALLGRAPH is not None:
        return _CALLGRAPH
    calls, where = {}, {}
    for p in (REPO / "src").rglob("*.s"):
        if not p.is_file():
            continue
        for name, lo, hi, lines in routines_of(p):
            body = [strip_comment(l) for l in lines[lo:hi]]
            calls.setdefault(name, set()).update(
                t for l in body for t in call_targets(l))
            where[name] = (p, lo, hi, lines)
    return calls, where


def can_sleep_closure(calls, shims=()):
    """Every routine that can reach a sleep primitive, transitively."""
    sleepy = set(SLEEP_PRIMS) | set(shims)
    changed = True
    while changed:
        changed = False
        for r, cs in calls.items():
            if r not in sleepy and (cs & sleepy):
                sleepy.add(r)
                changed = True
    return sleepy


_BLOCKS = None
BLOCK_LEN_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+EQU\s+\*-"
                          r"([A-Za-z_][A-Za-z0-9_]*)\s*$")
DS_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+DS\s+\d+")


def block_ranges():
    """{base cell: [every cell in the declared block]}.

    A `<NAME>_LEN EQU *-<base>' line closes a run of `DS' declarations, which
    is how the assembler itself measures the block a save loop copies:
    `_SOCK_SCRATCH_LEN EQU *-_sockSrcOff' (src/kernel/socket.s:150) covers
    _sockSrcOff..the cell before it, _sockTmpOff among them.  Read from the
    declarations rather than assumed, so adding a cell to the middle of a block
    extends the credit and moving one out of it withdraws it -- which is the
    same fact the `ERR' on the next line asserts for _sockAcceptLOff.
    """
    global _BLOCKS
    if _BLOCKS is not None:
        return _BLOCKS
    _BLOCKS = {}
    for p in sorted((REPO / "src").rglob("*.s")):
        if not p.is_file():
            continue
        run, start = [], None
        for raw in p.read_text(errors="replace").splitlines():
            s = strip_comment(raw)
            d = DS_RE.match(s)
            if d:
                run.append(d.group(1))
                if start is None:
                    start = d.group(1)
                continue
            e = BLOCK_LEN_RE.match(s)
            if e and e.group(2) in run:
                base = e.group(2)
                _BLOCKS[base] = run[run.index(base):]
                continue
            if s.strip() and not s.startswith(" ") and not s.startswith("\t"):
                run, start = [], None
    return _BLOCKS


def saved_cells(names, alt, where, sleepy):
    """Cells a sleeping routine genuinely SAVES ACROSS its own sleep.

    The idiom is a PUSH of the cell BEFORE the sleep and a STA back to it
    AFTER: `PEI (_cell)` (_Tty_GetByte / _kTtyRdPtr, the apple/fgx#41 fix), or
    `LDA _cell+1 / PHA / LDA _cell / PHA` for a 3-byte far pointer
    (_BlkCache_PinGet, and _Sock_PollIntr since #100).

    POSITION IS THE WHOLE POINT.  Matching a push and a store anywhere in the
    routine would mark an ordinary read-modify-write ACROSS a sleep as safe --
    marking the hazard as its own protection, which is exactly backwards.  So
    the push must precede the sleep and the store must follow it.

    A CALL TO A SLEEPING ROUTINE COUNTS AS THE SLEEP.  Restricting this to a
    direct primitive was said to err toward over-reporting, and it does -- but
    the routines it under-credits are exactly the module ones, which reach the
    scheduler through a KSVC shim and can never name a primitive.  So every
    genuine save in a module read as no save at all, and a module cannot save
    with `PEI' either: PEI takes a direct-page operand and module scratch is
    absolute, so the LDA/PHA form below is the only one available to it.

    A BLOCK SAVE IS A SAVE -- `_Sock_PollIntr' does not push its scratch cell
    by cell, it pushes a declared RANGE with `LDA _sockSrcOff,X / PHA' counting
    down and pops it back with `PLA / STA _sockSrcOff,X'.  Reading only the
    cell-by-cell idiom, this pass saw no save at all and reported every caller
    holding any cell in that block -- `net_op_accept' holding `_sockTmpOff'
    across the accept being the measured case, where the cell is the fifth
    member of the range and demonstrably safe (src/kernel/socket.s:120-157,
    whose own `ERR' asserts _sockAcceptLOff sits OUTSIDE the block).
    block_ranges() reads the ranges the way the assembler computes them.

    A SAVE IN A DEEPER CALLEE IS A SAVE, propagated to a fixed point below.
    This used to stop at the direct callee, which was the safe bias while
    nothing relied on it; apple/fgx#458 made `_Unp_CloseTry' rely on it, since
    the sleep is two levels down in `_Unp_NameCall' and that is where the park
    belongs -- the discipline being that a cell is parked where the sleep is.
    The propagation demands that EVERY sleep point in the caller be protected:
    one unprotected direct sleep, or one sleeping callee that does not save the
    cell, and the caller is reported as before.  That is what keeps
    `git show 1d199238d~1' red.
    """
    pei = re.compile(r"\bPEI\s+\(\s*(" + alt + r")\s*\)")
    push = re.compile(r"\bLDA\s+\|?<?(" + alt + r")\b")
    sta = re.compile(r"\bSTA\s+\|?<?(" + alt + r")\b")
    out = {}
    for rname in sleepy:
        if rname not in where:
            continue
        _path, lo, hi, lines = where[rname]
        body = [strip_comment(l) for l in lines[lo:hi]]
        sleeps = []
        for i, l in enumerate(body):
            if sleep_re().search(l):
                sleeps.append(i)
                continue
            c = RETURNING_CALL_RE.search(l)
            if c and c.group(2) != rname and c.group(2) in sleepy:
                sleeps.append(i)
        if not sleeps:
            continue
        first, last = min(sleeps), max(sleeps)
        pushed = set()
        for i in range(0, first):
            for m in pei.finditer(body[i]):
                pushed.add(m.group(1))
            # LDA of the cell immediately followed by PHA is the push form.
            for m in push.finditer(body[i]):
                if i + 1 < len(body) and re.search(r"\bPHA\b", body[i + 1]):
                    pushed.add(m.group(1))
        restored = set()
        for i in range(last + 1, len(body)):
            for m in sta.finditer(body[i]):
                restored.add(m.group(1))
        saved = pushed & restored

        # The block form: an indexed push of a declared range before the sleep
        # and an indexed pop back after it.
        for base, cells in block_ranges().items():
            bpush = re.compile(r"\bLDA\s+\|?<?" + re.escape(base) + r"\s*,\s*[XY]\b")
            bpop = re.compile(r"\bSTA\s+\|?<?" + re.escape(base) + r"\s*,\s*[XY]\b")
            if any(bpush.search(body[i]) and
                   any(re.search(r"\bPHA\b", body[j])
                       for j in range(i, min(i + 3, first)))
                   for i in range(0, first)) and \
               any(bpop.search(body[i]) for i in range(last + 1, len(body))):
                saved |= {c for c in cells if c in names}
        out[rname] = saved

    # A SAVE IN A DEEPER CALLEE COUNTS, to a fixed point.  A routine inherits
    # protection for a cell only when it has no unprotected sleep of its own
    # AND every sleeping callee protects that cell.
    direct_sleep = {}
    callees = {}
    for rname in sleepy:
        if rname not in where:
            continue
        _p, lo, hi, lines = where[rname]
        body = [strip_comment(l) for l in lines[lo:hi]]
        direct_sleep[rname] = any(sleep_re().search(l) for l in body)
        # CALL_RE, NOT RETURNING_CALL_RE: a TAIL call propagates protection just
        # as it propagates "can sleep".  `_Net_Xport_Accept' reaches the
        # sleeping `_Tcp_Accept' by `JMP', so its own body has nothing after the
        # sleep -- but `net_op_accept' JSRs IT and reads afterwards, and the
        # restore in the tail callee runs before control gets back there.
        # Leaving tail calls out left _Net_Xport_Accept with no sleeping callee
        # at all, so it inherited nothing and every caller holding a _sock*
        # cell across an accept was reported.
        cs = set()
        for l in body:
            for t in call_targets(l):
                if t != rname and t in sleepy:
                    cs.add(t)
        callees[rname] = cs
    changed = True
    while changed:
        changed = False
        for rname, cs in callees.items():
            if direct_sleep.get(rname) or not cs:
                continue
            inherited = set.intersection(*[out.get(c, set()) for c in cs])
            if inherited - out.get(rname, set()):
                out[rname] = out.get(rname, set()) | inherited
                changed = True
    return out


def interprocedural(names, alt, calls, where, sleepy, saved_by):
    """Cells stored, then a CALL THAT CAN SLEEP, then read -- in one routine.

    This is the #100 shape: the value is staged here, the switch happens deep
    inside the callee, and the read happens after control returns.  The
    within-routine pass cannot see it because no `JSR _sleep` appears here.
    """
    store = re.compile(r"\b(STA|STX|STY|STZ|INC|DEC)\s+\|?<?(" + alt + r")\b")
    read = re.compile(r"(?:\[\s*|\(\s*|\b(?:LDA|LDX|LDY|CMP|CPX|CPY|AND|ORA|"
                      r"EOR|ADC|SBC|BIT)\s+\|?<?)(" + alt + r")\b")
    hits = []
    for rname, (path, lo, hi, lines) in where.items():
        body = [strip_comment(l) for l in lines[lo:hi]]
        for k, l in enumerate(body):
            m = RETURNING_CALL_RE.search(l)
            if not m or m.group(2) not in sleepy:
                continue
            if m.group(2) in SLEEP_PRIMS:
                continue          # the within-routine pass owns those
            before, after = {}, {}
            for j in range(0, k):
                for s in store.finditer(body[j]):
                    before.setdefault(s.group(2), lo + j + 1)
            for j in range(k + 1, len(body)):
                for s in read.finditer(body[j]):
                    after.setdefault(s.group(1), lo + j + 1)
            live = sorted(set(before) & set(after))
            if live:
                hits.append({
                    "file": relname(path),
                    "routine": rname,
                    "line": lo + k + 1,
                    "callee": m.group(2),
                    "saved_in_callee": sorted(
                        c for c in live if saved_by.get(m.group(2), set()) >= {c}),
                    "live": [{"cell": c, "stored": before[c], "read": after[c]}
                             for c in live
                             if c not in saved_by.get(m.group(2), set())],
                })
    hits = [h for h in hits if h["live"]]
    hits.sort(key=lambda h: (-len(h["live"]), h["file"], h["line"]))
    return hits


# A BACKWARD BRANCH PUTS THE TOP OF THE LOOP AFTER THE SLEEP.
#
# Every one of pty's wait sites is `test / sleep / BRA back-to-the-test', so
# the read that decides whether to sleep again sits TEXTUALLY BEFORE the sleep
# and is reached AFTER it on the second pass.  A forward-only scan cannot see
# it, and all three passes here were forward-only.
#
# Merlin local labels (`@mr_wait') sit in column 0 like a routine head but do
# not start one, which is why LABEL_RE skips them and why they have to be
# collected separately.
LOCAL_LABEL_RE = re.compile(r"^(@[A-Za-z0-9_]+)")
BRANCH_RE = re.compile(
    r"\b(BRA|BRL|BCC|BCS|BEQ|BNE|BPL|BMI|BVC|BVS|JMP|JML)\s+\|?<?(@?[A-Za-z_]"
    r"[A-Za-z0-9_]*)")


def loop_window(body, k):
    """Index from which reads count as `after the sleep at k'.

    k+1 normally; the target of the earliest backward branch taken after k
    when the sleep sits inside a loop.
    """
    labels = {}
    for j, l in enumerate(body):
        mm = LOCAL_LABEL_RE.match(l)
        if mm:
            labels.setdefault(mm.group(1), j)
    start = k + 1
    for j in range(k + 1, len(body)):
        for mm in BRANCH_RE.finditer(body[j]):
            t = labels.get(mm.group(2))
            if t is not None and t <= k:
                start = min(start, t)
    return start


# THE CELLS THE SYSCALL DISPATCHER STAGES FOR SOMEBODY ELSE.
#
# These are not scratch a routine owns; they are OPERANDS resolved from the
# caller's fd or buffer before control reaches a driver.  _Fcb_LookupPtr writes
# _fcbPtr (drivers/fs/fcb.s) on behalf of whichever syscall is running, and
# every fd syscall calls it -- so the cell names THIS task's descriptor only
# until this task yields.
#
# Reading one of these after a sleep is apple/fgx#41 and #100 with the STORE in
# another routine, which is why neither pass above can see it: both require the
# store and the read in the same body.  The value is no less stale for having
# been staged by the caller.
CALLER_STAGED = ("_fcbPtr", "_libcTmp2")

# WHAT THIS FILE STILL CANNOT SEE, said rather than left to be discovered.
#
# The cell set is dp_cells() -- the direct page and nothing else.  KERNEL
# STATICS carry per-call state across sleeps too, and one of them was live:
# _PtyM_Write staged the write byte in _ptyTmpB2 and re-read it after
# _PtyKC_Sleep, so a concurrent pty writer put ITS character into the sleeper's
# ring (apple/fgx#206, fixed).  Every pass here was blind to it because
# _ptyTmpB2 is `DS 2' in src/kernel/pty.s, not a DUM cell in dpmap.s.
#
# A NAIVE EXTENSION OVER-REPORTS, measured rather than assumed: pointing the
# existing passes at the 1,151 column-0 `DS' symbols reports 13 sites, and the
# first one read -- _Sys_Read at syscall.s:4909 -- re-stores _Sys_RdByte four
# lines AFTER the call it is accused of carrying it across.  The store set is
# "anything stored earlier in this routine", which is fine for the small bodies
# the DP passes were written against and wrong for a 900-line dispatcher with
# many independent arms.  Extending the cell set wants the first-occurrence
# re-ownership test unowned() already does, and flow sensitivity the rest of
# this file does not have.  Left undone deliberately; the 13 are NOT a defect
# count.

# Routines that RE-ESTABLISH a staged cell, so a call to one inside the window
# ends the exposure just as a store would.  _fcbPtr's writers are three levels
# away from any body that uses them -- _Fcb_Alloc and _Fcb_LookupPtr store it in
# drivers/fs/fcb.s, and a module reaches them by KSVC number through a shim --
# so no scan of stores or of the call graph finds them.
#
# A HAND LIST IS RIGHT HERE AND WRONG FOR THE SLEEP SHIMS, and the difference is
# which way it fails.  Omitting a sleep shim HIDES a hazard, which is why those
# are derived from the KSVC number now.  Omitting a re-stager only produces a
# false positive, and a false positive gets read.
RESTAGERS = {
    "_fcbPtr": ("_Fcb_Alloc", "_Fcb_LookupPtr",
                "_NlKC_FcbAlloc", "_NlKC_FcbLookupPtr"),
    # `_Unp_LoadArgs' REBUILDS the whole 24-bit pointer -- `_unpArgBlk' into
    # _libcTmp2 and `_Sys_CallerBank' into _libcTmp2+2 -- so nothing of the
    # pre-sleep value survives it.  Both of its sources hold across a switch:
    # _unpArgBlk is inside the block _Unp_SaveBlk parks on the task's kernel
    # stack, and _Sys_CallerBank is saved per task by the scheduler
    # (SE_CallerBank, src/kernel/sched.s).  bind and connect call it after a
    # pipe.s call for exactly this reason: pipe.s builds its own uio pointer
    # in _libcTmp2.
    #
    # THIS DOES NOT SILENCE THE CHECK, which is why it belongs here rather than
    # in UNOWNED_OK: the window test is which comes FIRST, so moving a read
    # above the re-stage call puts the site straight back in the report.
    "_libcTmp2": ("_Unp_LoadArgs",),
}


def unowned(names, alt, calls, where, sleepy, saved_by, cells=CALLER_STAGED):
    """Caller-staged cells READ after a sleep, with no store in this routine.

    The third shape.  `analyse` wants store-sleep-read in one routine and
    `interprocedural` wants store-call-read in one routine; both intersect a
    store set, so a routine that only ever READS the cell drops out of each.
    """
    read = re.compile(r"(?:\[\s*|\(\s*|\b(?:LDA|LDX|LDY|CMP|CPX|CPY|AND|ORA|"
                      r"EOR|ADC|SBC|BIT)\s+\|?<?)(" + alt + r")\b")
    store = re.compile(r"\b(STA|STX|STY|STZ|INC|DEC)\s+\|?<?(" + alt + r")\b")
    watch = set(cells)
    hits = []
    for rname, (path, lo, hi, lines) in where.items():
        body = [strip_comment(l) for l in lines[lo:hi]]
        for k, l in enumerate(body):
            call = RETURNING_CALL_RE.search(l)
            callee = call.group(2) if call else None
            if not (sleep_re().search(l) or (callee and callee in sleepy)):
                continue
            # A STORE INSIDE THE WINDOW MAKES THE CELL THIS ROUTINE'S OWN
            # AGAIN.  _PtyM_Read stages _libcTmp2 from _Sys_RdBufOff after its
            # wait ends and reads it back to copy the record out; that is a
            # local variable, not a value carried across the switch.  So the
            # test is which comes FIRST in the window -- a read before any
            # store is a value inherited from before the sleep, a store first
            # is a value this routine just wrote.
            start = loop_window(body, k)
            after = {}
            for j in range(start, len(body)):
                if j == k:
                    continue
                for mm in store.finditer(body[j]):
                    if mm.group(2) in watch:
                        after.setdefault(mm.group(2), None)
                inner = RETURNING_CALL_RE.search(body[j])
                if inner:
                    for c in watch:
                        if inner.group(2) in RESTAGERS.get(c, ()):
                            after.setdefault(c, None)
                for mm in read.finditer(body[j]):
                    if mm.group(1) in watch:
                        after.setdefault(mm.group(1), lo + j + 1)
            live = sorted(c for c, ln in after.items()
                          if ln is not None
                          and c not in saved_by.get(callee, set()))
            if live:
                hits.append({
                    "file": relname(path),
                    "routine": rname,
                    "line": lo + k + 1,
                    "sleep": callee or strip_comment(l).strip()[:40],
                    "live": [{"cell": c, "read": after[c]} for c in live],
                })
    hits.sort(key=lambda h: (h["file"], h["line"]))
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", metavar="PATH")
    ap.add_argument("--callers", action="store_true",
                    help="interprocedural pass: stage here, sleep in a callee, "
                         "read on return (the apple/fgx#100 shape)")
    args = ap.parse_args()

    names = dp_cells()
    alt = "|".join(re.escape(n) for n in sorted(names, key=len, reverse=True))

    results = []
    for d in ("src",):
        for p in (REPO / d).rglob("*"):
            if p.suffix == ".s" and p.is_file():
                results.extend(analyse(p, names, alt))

    results.sort(key=lambda r: (-len(r["live"]), r["file"], r["line"]))

    n_live = 0
    for r in results:
        mark = "CANDIDATE" if r["live"] else "clean     "
        print(f"{mark} {r['file']}:{r['line']}  ({r['routine']})")
        print(f"           {r['sleep']}")
        for c in r["live"]:
            n_live += 1
            print(f"           LIVE {c['cell']:<16} stored :{c['stored']}"
                  f"  read :{c['read']}")
    print()
    print(f"{len(results)} sleep sites; "
          f"{sum(1 for r in results if r['live'])} with a candidate live range; "
          f"{n_live} candidate cell-ranges total")
    print("Every candidate needs a read: this over-reports by design "
          "(no call following, no path analysis, SAVED not recognised).")

    if args.callers:
        calls, where = build_callgraph()
        # WITH the shims: without them this census reported 57 routines where
        # the gate saw 72, missing every module that sleeps by KSVC number --
        # which is the case this file's docstring names as the reason the shims
        # are derived at all.
        sleepy = can_sleep_closure(calls, ksvc_sleep_shims(where))
        saved_by = saved_cells(names, alt, where, sleepy)
        hits = interprocedural(names, alt, calls, where, sleepy, saved_by)
        print()
        print(f"=== INTERPROCEDURAL: {len(sleepy)} routines can reach a sleep "
              f"(of {len(calls)} total) ===")
        for h in hits:
            print(f"CANDIDATE {h['file']}:{h['line']}  {h['routine']} "
                  f"-> {h['callee']} (can sleep)")
            for c in h["live"]:
                print(f"           LIVE {c['cell']:<16} stored :{c['stored']}"
                      f"  read :{c['read']}")
        print()
        print(f"{len(hits)} call sites stage a DP cell, call something that "
              f"can sleep, then read it back WITHOUT the callee saving it")
        print("Cells the callee saves across its own sleep (PEI/PHA + STA "
              "back) are treated as SAFE and not listed.")
        results = {"within": results, "interprocedural": hits,
                   "sleepy_routines": sorted(sleepy)}

    if args.json:
        pathlib.Path(args.json).write_text(json.dumps(results, indent=1))
        print(f"wrote {args.json}", file=sys.stderr)


if __name__ == "__main__":
    main()
