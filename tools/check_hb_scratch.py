#!/usr/bin/env python3
"""The heartbeat body must not touch shared DP scratch.  apple/fgx#235.

src/kernel/toolbox.s states the rule in its own header:

    - DO NOT touch shared DP scratch (_shTmp* / _libcTmp* / _fsTmp*); the
      body fires asynchronously w.r.t. any in-flight kernel call.

and the body broke it anyway, for the length of time it takes nobody to
re-read a comment.  `@hb_sigPost' parked one word in `_shTmp0' while it turned
Y's high byte into an index, so a kernel call holding a value there across the
instant a `^C' or `^Z' arrived got it overwritten -- and `_Fcb_LookupPtr'
writes `_shTmp0' (include/dpmap.s:273), as do the slot scan and the name
compare, so the damage presents as the FILE layer's bug.

A FIXTURE CANNOT COVER THIS and #235 says so: it would have to inject the key
while a syscall holds the cell live, which is a timing construction rather than
a keystroke test.  A green `ctrlc' or `intrflush' is not coverage.  So the
rule is checked where it is stated instead.

WHY THE STACK IS NOT FLAGGED: the body owns it.  PHP, PHB and the arm's own PHX
are already there, and a value that lives four instructions has no business
being a static at all.

IT FOLLOWS CALLS NOW -- apple/fgx#108 T6 increment 3.  Until 2026-08-26 this
read only the body's own lines, and that scope was about to become wrong: T6
increment 4 makes the heartbeat call `ttyinput', so everything `ttyinput'
reaches becomes heartbeat-time code.  Measured on that path, `_Kill_GroupFanout'
parks the signal number in `_shTmp1' -- #235 exactly, one cell over -- and this
script would have stayed green through it, because the write is a JSR away.
A guard whose scope stops where the body grows is a guard that reports the last
version of the problem.

REACHABLE ROUTINES ARE REPORTED, NOT FAILED, when they are already bracketed
against interrupts: a routine that masks for its whole length cannot be
re-entered by the tick, so the shared cell is safe there in a way it is not in
the body itself.  BRACKETED lists the ones checked and why.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "kernel" / "toolbox.s"

# THERE ARE TWO RECEIVE INTERRUPTS NOW -- apple/fgx#108 T7.  The heartbeat feeds
# the keyboard; `serial_isr' feeds /dev/tty01, and since T7 step 2 it runs the
# SAME line discipline through the same door.  A rule enforced on one of two
# callers of the same code is a rule that holds by luck of shared code.
#
# THE STRUCTURAL HAZARD IS ALREADY RETIRED and this is not what closes it: T6
# gave interrupt-time C its own register file (FGX_DP_KERNELC_IRQ), so the C
# these two reach shares no fcc locals with the syscall it interrupted.  What is
# left is the hand-written scratch below, which has no hardware excuse -- the
# 65816 forces DIRECT-PAGE staging for a 24-bit dereference, it does not force
# that page to be SHARED (docs/history/audits/kernel-scratch-census.md).
SER = ROOT / "src" / "modules" / "serial" / "serial.s"
SER_START = re.compile(r"^serial_isr\b", re.M)
SER_END = re.compile(r"^serial_isr_A\b", re.M)

# CALLS THROUGH THE BANK-0 GATEWAY CANNOT BE FOLLOWED, so they are DECLARED.
# `serial_isr' reaches the discipline as `LDX #KSVC_TTYIRQINPUT' + `JSL
# SYS_KCALL' -- an EQU naming a fixed bank-0 address, dispatched by a compare
# chain on X.  No scan of the text can see the far end, and following
# `_Sys_KCallImpl' instead would drag in EVERY KSVC arm (they are `@'-locals
# inside one routine), reporting arms this ISR never selects -- including
# `@kc_ttyrwArgs', which writes _libcTmp2 legitimately from a read(2).
#
# So the edge is named here, with the service that creates it.  A declared edge
# is a claim: if serial_isr ever calls a second service, this table is where the
# omission shows up, and there is nothing else that would notice.
#
# THE SECOND EDGE IS THE ONE THIS FILE PREDICTED OF ITSELF (apple/fgx#378).
# `_Tty_IrqInput' reaches the discipline as `JSL KTTY_KC_TTYINPUT' -- slot 38 of
# the tty bank's jump table, an EQU like the one above.  The walk matched the
# symbol, found no routine of that name, and stopped THERE, silently, reporting
# two reachable routines on a path whose far side is the whole line discipline.
# The header above says what that is: "A guard whose scope stops where the body
# grows is a guard that reports the last version of the problem."
#
# The far side needs no new indexing -- index_routines() already rglobs every
# `src/kernel/**/*.s', which includes the tty bank's generated output, so
# `kc_ttyinput' (tty_dev.s) is in the table and merely unreachable.
GATEWAY_EDGES = {
    "serial_isr": [("_Tty_IrqInput", "KSVC_TTYIRQINPUT")],
    "_Tty_IrqInput": [("kc_ttyinput", "KTTY_KC_TTYINPUT")],
    # AND AN INDIRECT CALL IS AS UNFOLLOWABLE AS A GATEWAY.  `kc_ttyinput' ends
    # in `(*linesw[tp->t_line].l_rint)(c, tp)' (tty_dev.c:1046) -- a dispatch
    # through the line-discipline switch, whose `l_rint' slot is `ttyinput' for
    # both disciplines FGX ships, OTTYDISC and NTTYDISC (tty_conf.c:140-148).
    # Without this the walk stops at `tty_byidx' and never enters the
    # discipline at all, which is the whole of what runs at interrupt time.
    "kc_ttyinput": [("ttyinput", "linesw[].l_rint")],
}

# The body runs from the firmware entry (`_HBTickTask' + 8, marked in source by
# the "Body starts here" comment) to the label that follows the task record.
BODY_START = re.compile(r"^_HBTickTask\b", re.M)
BODY_END = re.compile(r"^_TBM_", re.M)
SCRATCH = re.compile(r"\b(_shTmp\d*|_libcTmp\d*|_fsTmp\d*)\b")
# fcc's PILECALL IS NOT A JSR, and the tty bank is compiled code.  A call in
# pile output is `PHK / PEA callee-1 / RTL' -- there is no JSR in it, so a scan
# that knows only JSR/JSL/JMP walks into `kc_ttyinput' and finds no callees at
# all (apple/fgx#378).  The same shape also pushes the RETURN address, so this
# matches two labels per call; the second is an `_L<n>' local, which
# index_routines folds into its parent and the walk then skips as "not a body".
CALL = re.compile(r"\b(?:JSR|JSL|JMP)\s+([A-Za-z_][A-Za-z0-9_]*)"
                  r"|\bPEA\s+([A-Za-z_][A-Za-z0-9_]*)-1\b")


def _callees(code):
    """Callee names in one line, over both call forms."""
    return [a or b for a, b in CALL.findall(code)]
STORE = re.compile(r"\b(?:STA|STX|STY|STZ|INC|DEC)[:L]?\s")

# Routines that touch shared scratch but MASK for their whole length, so the
# tick cannot land inside them.  Each needs its PHP/SEI ... PLP verified by
# reading, and named here with what it protects.
#
# THIS TABLE IS ARMED, NOT FIRING.  Measured 2026-08-26: the heartbeat reaches
# exactly four routines today (_Se_TtyOffToIdx, _Sys_AlarmTickAll, _Tty_PgrpOf,
# and the since-retired _Tty_SgFlagsAt) and _Kill_GroupFanout is not among them -- it becomes
# reachable when T6 increment 4 routes ttyinput through the tick.  Emptying the
# table changes nothing today, which is stated here so nobody reads the entry as
# evidence that something is being caught.  What IS verified today is the
# MECHANISM: the self-test drives a shared-scratch write one JSR past the body
# and requires it to be reported.
BRACKETED = {
    "_Kill_GroupFanout":
        "PHP/SEI at entry, PLP on both exits (apple/fgx#108 T6 increment 3) -- "
        "it parks the signal number in _shTmp1 and is reached from ttyinput "
        "through kc_gsignal",
}


def violations(text, start=None, end=None):
    start = start or BODY_START
    end = end or BODY_END
    out, inside = [], False
    for i, line in enumerate(text.splitlines(), 1):
        if start.match(line):
            inside = True
            continue
        if inside and end.match(line):
            break
        if not inside:
            continue
        code = line.split(';', 1)[0]          # comments may NAME the cells
        m = SCRATCH.search(code)
        if m:
            out.append((i, m.group(1), line.rstrip()))
    return out


def self_test():
    """Prove it can go red.  A guard that cannot is the defect it exists for."""
    good = "_HBTickTask\n                PHA\n                TAX\n_TBM_TL_Fail\n"
    if violations(good):
        print("self-test FAILED: clean body reported a violation")
        return 1
    bad = "_HBTickTask\n                STA     _shTmp0\n_TBM_TL_Fail\n"
    if not violations(bad):
        print("self-test FAILED: `STA _shTmp0' in the body was not caught")
        return 1
    # A comment naming the cell must NOT trip it -- the fix's own comment does.
    commented = ("_HBTickTask\n                PHA     ; not _shTmp0 any more\n"
                 "_TBM_TL_Fail\n")
    if violations(commented):
        print("self-test FAILED: a comment naming the cell was flagged")
        return 1
    # And a cell OUTSIDE the body (a syscall handler) is legitimate.
    outside = "_Sys_Ticks\n                STA     _shTmp0\n_HBTickTask\n_TBM_TL_Fail\n"
    if violations(outside):
        print("self-test FAILED: a use outside the body was flagged")
        return 1
    # ...and the reachability pass must follow a CALL, which is the whole
    # point of widening it: the write that motivated this is a JSR away.
    body = {"_Victim": ["_Victim MX %00", "                STA     _shTmp1"],
            "_Clean":  ["_Clean  MX %00", "                PHA"]}
    hb = "_HBTickTask\n                JSR     _Victim\n_TBM_TL_Fail\n"
    if not reachable_violations(hb, body)[0]:
        print("self-test FAILED: a shared-scratch write one JSR from the body "
              "was not caught -- this is the scope T6 increment 4 widens into")
        return 1
    ok = "_HBTickTask\n                JSR     _Clean\n_TBM_TL_Fail\n"
    if reachable_violations(ok, body)[0]:
        print("self-test FAILED: a clean callee was reported")
        return 1
    # A READ of the cell downstream is not a violation; only a write is.
    body2 = {"_Reader": ["_Reader MX %00", "                LDA     _shTmp1"]}
    hb2 = "_HBTickTask\n                JSR     _Reader\n_TBM_TL_Fail\n"
    if reachable_violations(hb2, body2)[0]:
        print("self-test FAILED: a downstream READ was flagged as a write")
        return 1
    # --- the three things apple/fgx#378 added.  Each is driven, because the
    # file's own rule about the gateway table applies to all of it: an edge
    # nobody drives is a table entry, not a check.
    #
    # (a) fcc's PILECALL is a call.  Written as the compiler writes it.
    pile = {"_Victim": ["_Victim MX %00", "                STA     _shTmp1"]}
    hbp = ("_HBTickTask\n                PHK\n                PEA     _Victim-1\n"
           "                RTL\n_TBM_TL_Fail\n")
    if not reachable_violations(hbp, pile)[0]:
        print("self-test FAILED: a PILECALL to a dirty routine was not "
              "followed -- the tty bank is compiled code and calls this way")
        return 1
    # (b) a generated function is indexed WHOLE.  `<fn>_stkok' and `_L<n>' are
    # fcc's own internal labels; if they split the body, everything past the
    # stack guard becomes unreachable.
    if not _continues("kc_ttyinput", "kc_ttyinput_stkok"):
        print("self-test FAILED: `<fn>_stkok' did not continue its function")
        return 1
    if not _continues("ttyinput", "_tty_dev_L120"):
        print("self-test FAILED: an `_L<n>' local did not continue its function")
        return 1
    if _continues("ttyinput", "ttyoutput"):
        print("self-test FAILED: a genuinely new routine was folded into the "
              "previous one")
        return 1
    # (c) a gateway edge is followed MID-WALK, not only at the root.  This is
    # the one that mattered: `_Tty_IrqInput' is a JSR inside the body, so a
    # table consulted only for the root name never sees its entry.
    saved = GATEWAY_EDGES.get("_Mid")
    GATEWAY_EDGES["_Mid"] = [("_Victim", "TEST_SLOT")]
    mid = {"_Mid": ["_Mid    MX %00", "                RTS"],
           "_Victim": ["_Victim MX %00", "                STA     _shTmp1"]}
    hbm = "_HBTickTask\n                JSR     _Mid\n_TBM_TL_Fail\n"
    hit = reachable_violations(hbm, mid)[0]
    if saved is None:
        del GATEWAY_EDGES["_Mid"]
    if not hit:
        print("self-test FAILED: a gateway edge on a routine reached MID-WALK "
              "was not followed (apple/fgx#378)")
        return 1

    # --- the SCC half (apple/fgx#108 T7).  Two new things to prove: the
    # second body is scanned at all, and the DECLARED gateway edge is
    # followed.  An edge nobody drives is a table entry, not a check.
    sbad = "serial_isr\n                STA     _shTmp0\nserial_isr_A\n"
    if not violations(sbad, SER_START, SER_END):
        print("self-test FAILED: a shared-scratch write in serial_isr's own "
              "body was not caught")
        return 1
    sok = "serial_isr\n                PHA\nserial_isr_A\n"
    if violations(sok, SER_START, SER_END):
        print("self-test FAILED: a clean serial_isr body was reported")
        return 1
    # The ISR reaches the discipline ONLY through SYS_KCALL, which no scan can
    # follow -- so this drives the declared edge with a body that calls NOTHING.
    gate_body = {"_Tty_IrqInput": ["_Tty_IrqInput MX %00",
                                   "                STA     _shTmp1"]}
    gate_src = "serial_isr\n                JSL     SYS_KCALL\nserial_isr_A\n"
    hits, _ = reachable_violations(gate_src, gate_body, start=SER_START,
                                   end=SER_END, root_name="serial_isr")
    if not hits:
        print("self-test FAILED: the DECLARED gateway edge serial_isr -> "
              "_Tty_IrqInput was not followed.  The ISR reaches the discipline "
              "only through SYS_KCALL, so without this edge the SCC half "
              "checks the handler's own six lines and nothing else")
        return 1
    # ...and without the declaration it must NOT be followed, or the edge is
    # not what is doing the work.
    hits2, _ = reachable_violations(gate_src, gate_body, start=SER_START,
                                    end=SER_END, root_name=None)
    if hits2:
        print("self-test FAILED: the gateway callee was reached WITHOUT the "
              "declared edge -- something else is following SYS_KCALL, so the "
              "table is not what it claims")
        return 1
    print("check_hb_scratch: self-test ok (both bodies, one JSR past each, "
          "and the declared gateway edge)")
    return 0


# A GENERATED FUNCTION IS NOT ONE LABEL.  fcc emits `<fn>_stkovf', `<fn>_stkok'
# and `_<file>_L<n>' at column 0 INSIDE a function body, and the indexer read
# each as the start of a new routine -- so `kc_ttyinput' indexed as its first
# NINE lines, ending at its own stack-guard arm, and everything the discipline
# does was in a "routine" nothing calls (apple/fgx#378).  Both shapes continue
# the routine that is open.
_LOCAL_LABEL = re.compile(r"_L\d+$")


def _continues(cur, label):
    """Is `label' an internal label of the routine already open?"""
    if cur is None:
        return False
    return label.startswith(cur + "_") or bool(_LOCAL_LABEL.search(label))


def index_routines():
    """label -> body lines, over every kernel .s.  Generated export tables are
    skipped: they re-declare every symbol as an EQU, which glues unrelated
    routines onto whatever body happens to be open."""
    body = {}
    for path in sorted((ROOT / "src" / "kernel").rglob("*.s")):
        if path.name == "kernel_exports.s":
            continue
        cur, buf = None, []
        for line in path.read_text(errors="replace").splitlines():
            if re.search(r"\bEQU\b", line):
                continue
            m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\b", line)
            if m and not _continues(cur, m.group(1)):
                if cur:
                    body.setdefault(cur, []).extend(buf)
                cur, buf = m.group(1), []
            if cur is not None:
                buf.append(line)
        if cur:
            body.setdefault(cur, []).extend(buf)
    return body


def reachable_violations(text, body, depth=8, start=None, end=None, root_name=None):
    """Shared-scratch WRITES in what a delimited interrupt body CALLS."""
    start = start or BODY_START
    end = end or BODY_END
    roots, inside = [], False
    for line in text.splitlines():
        if start.match(line):
            inside = True
            continue
        if inside and end.match(line):
            break
        if inside:
            roots += _callees(line.split(";", 1)[0])
    for callee, _svc in GATEWAY_EDGES.get(root_name, ()):
        roots.append(callee)

    out, seen, stack = [], set(), [(r, 0) for r in roots]
    while stack:
        name, d = stack.pop()
        if name in seen or d > depth:
            continue
        # A GATEWAY EDGE IS FOLLOWED WHEREVER IT IS FOUND, not only at the root.
        # `_Tty_IrqInput' is reached one JSR INTO the heartbeat's walk, so a
        # table consulted only for the root name would never see its entry --
        # which is how apple/fgx#378 stayed green while the discipline moved to
        # the far side of it.  Named BEFORE the `name not in body' test: a
        # gateway's near side may itself be a bare EQU with no body to scan.
        for callee, _svc in GATEWAY_EDGES.get(name, ()):
            if callee not in seen:
                stack.append((callee, d + 1))
        if name not in body:
            continue
        seen.add(name)
        for line in body[name]:
            code = line.split(";", 1)[0]
            m = SCRATCH.search(code)
            if m and STORE.search(code) and name not in BRACKETED:
                out.append((name, m.group(1), code.strip()))
            for callee in _callees(code):
                if callee not in seen:
                    stack.append((callee, d + 1))
    return out, seen


def main():
    if "--self-test" in sys.argv:
        return self_test()
    text = SRC.read_text()
    if not BODY_START.search(text) or not BODY_END.search(text):
        print("check_hb_scratch: FAILED -- cannot find the heartbeat body in "
              f"{SRC.relative_to(ROOT)}; the delimiters this reads "
              "(`_HBTickTask' .. `_TBM_') have moved, so it is checking "
              "nothing (apple/fgx#235)")
        return 1
    ser = SER.read_text()
    if not SER_START.search(ser) or not SER_END.search(ser):
        print("check_hb_scratch: FAILED -- cannot find `serial_isr' in "
              f"{SER.relative_to(ROOT)} between `serial_isr' and "
              "`serial_isr_A'; the delimiters have moved, so the SCC half is "
              "checking nothing (apple/fgx#108 T7)")
        return 1
    bad = violations(text)
    for line_no, cell, line in bad:
        print(f"check_hb_scratch: toolbox.s:{line_no} the heartbeat body "
              f"touches {cell} -- the body fires asynchronously w.r.t. any "
              f"in-flight kernel call and its own header forbids this "
              f"(apple/fgx#235)\n    {line.strip()}")
    routines = index_routines()
    reach, seen = reachable_violations(text, routines)
    sbad = violations(ser, SER_START, SER_END)
    for line_no, cell, line in sbad:
        print(f"check_hb_scratch: serial.s:{line_no} `serial_isr' touches "
              f"{cell} -- the SCC handler fires asynchronously w.r.t. any "
              f"in-flight kernel call, exactly as the heartbeat does "
              f"(apple/fgx#235, apple/fgx#108 T7)\n    {line.strip()}")
    sreach, sseen = reachable_violations(ser, routines, start=SER_START,
                                         end=SER_END, root_name="serial_isr")
    bad = bad + sbad
    reach = reach + sreach
    seen = seen | sseen
    for name, cell, line in reach:
        print(f"check_hb_scratch: {name}() writes {cell} and is REACHED from "
              f"the heartbeat body. The body fires asynchronously w.r.t. any "
              f"in-flight kernel call, and that does not stop being true one "
              f"JSR down (apple/fgx#235). Either take the value off the shared "
              f"cell, or mask the routine for its whole length and name it in "
              f"BRACKETED with what verifies that.\n    {line}")
    if bad or reach:
        print(f"check_hb_scratch: FAILED ({len(bad)} in the body, "
              f"{len(reach)} reached)")
        return 1
    print(f"check_hb_scratch: clean (heartbeat body and serial_isr, plus "
          f"{len(seen)} routine(s) they reach; {len(BRACKETED)} bracketed and "
          f"allowed, {sum(len(v) for v in GATEWAY_EDGES.values())} declared "
          f"gateway edge(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
