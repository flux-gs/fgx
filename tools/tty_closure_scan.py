#!/usr/bin/env python3
"""Which routines of 2.11BSD's tty.c can the TTY bank port next?

apple/fgx#108 T3 plans by this answer, and it has been re-derived by hand
twice and been WRONG BOTH TIMES, in two different ways:

  1. A DIRECT-REACH scan says ~200 lines are portable.  That is wrong because
     a routine reaching nothing itself but CALLING one that sleeps still needs
     the seam.  The answer only means anything under TRANSITIVE CLOSURE.
  2. A plain name-then-paren scan misses `(*cdevsw[major(dev)].d_ioctl)(...)'.
     That made ttyblock and ttyunblock look portable with no seam at all, and
     put ttyunblock behind `timeout' -- a primitive it never calls.
  3. IT RANKS BY SEAM, WHICH IS NOT THE SAME AS PORTABLE, and the output says
     "MISSING SEAMS" rather than "portable" for that reason.  It listed five
     routines as needing no new seam when only two were actually portable:
     ttnread reaches ttyinput through ttypend, which was blocked by an fcc
     defect no call graph can see, and ttyselect reads u.u_procp, selwait and
     t_rsel -- DATA dependencies this scan does not look at, and FGX's select
     registers on nothing, so that routine needs answering for rather than
     transcribing.  IT HAPPENED AGAIN with ttyopen, which this scan ranks behind
     `sleep' alone: ttyopen also reads u.u_procp, u.u_ttyp, u.u_ttyd, p_pgrp
     and p_pid, so kc_sleep unlocks THREE of its four rows and not four.
  4. IT COUNTED A MACRO AS A MISSING PRIMITIVE.  `sigmask' is
     `#define sigmask(m) (1L << ((m)-1))' -- h/signal.h:136 -- and every name
     reaching the report is one this file does not define and HAVE does not
     list, so a macro from a header tty.c includes looks exactly like an unbuilt
     seam.  It put ttwrite behind `sigmask, sleep' when its only real primitive
     is `sleep', which kc_sleep already landed: ttwrite (126 lines) is behind
     the u-area predicate ALONE.  MACROS below is the fix; the self-test pins it.

So the scan is a committed tool rather than a paragraph in a handoff, and the
self-test pins the indirect-call case that was missed.

  python3 tools/tty_closure_scan.py             the table and the ranking
  python3 tools/tty_closure_scan.py --self-test
"""
import itertools
import re
import sys

TTY_C = "vendor/2.11BSD/usr/sys/sys/tty.c"

# Already in src/kernel/tty/tty.c.  Update this as increments land -- it is the
# only line that should need touching between them.
PORTED = {
    "partab", "ttychars", "ttstart", "ttrstrt", "nullmodem", "ttyout",
    "ttbreakc", "ttyrubo", "ttyecho", "ttyoutput", "ttyrub", "ttyretype",
    "ttyblock", "ttyunblock", "ttwakeup", "ttyowake", "ttyflush",
    "ttyclose", "ttymodem", "ttyinput", "ttypend",
    "ttnread", "ttyselect", "ttselect",
    "ttywait", "ttywflush", "ttylclose",
    "ttyopen", "ttwrite", "ttread", "ttycheckoutq", "ttioctl",
}

# Macros that travel WITH the port rather than being seams: CLR/SET/ISSET are
# defined in tty.c itself (lines 103-105), CTRL in h/ttydefaults.h, and
# TTHIWAT/TTLOWAT index two small tables in h/tty.h.
#
# `sigmask' is here for the same reason and was MISSED for four increments:
# h/signal.h:136 is `#define sigmask(m) (1L << ((m)-1))', a shift, not a call.
# The bank already carries the signal NUMBERS locally (src/kernel/tty/tty.h:297
# defines SIGINT), so the macro lands beside them exactly as CTRL did -- a
# header line, not a seam.  Counting it as one hid that ttwrite's only missing
# primitive was `sleep'.
MACROS = {"CLR", "SET", "ISSET", "CTRL", "MIN", "TTHIWAT", "TTLOWAT",
          "sigmask"}

# What the TTY bank actually has today: T1's clists, the empty spl macros, the
# two seams already built, and the indirect calls whose targets are in reach.
HAVE = {
    "getc", "putc", "b_to_q", "q_to_b", "ndqb", "ndflush", "nextc", "unputc",
    "catq", "cinit", "spltty", "splx", "spl0", "spl5", "spl6",
    # `bzero' is REAL as of ttyopen: the bank links no libc, so it carries its
    # own in tty_dev.c.  `bcopy' WAS LISTED HERE AND IS NOT IN THE BANK -- the
    # fourth time HAVE has claimed something the bank does not have, and the
    # first time in the direction that makes the ranking OPTIMISTIC rather than
    # pessimistic.  ttioctl is its only caller (tty.c:498-511), so removing it
    # is what puts it in that routine's missing column where it belongs.
    # `scanc' joined bzero as REAL with ttwrite: 2.11BSD's is PDP-11 assembly
    # (machine/mch_xxx.s), so the bank carries 4.3BSD-Reno's portable C from
    # ufs/ufs_subr.c:160 -- upstream's own version for a non-VAX.
    "bzero", "max", "min", "scanc", "major", "minor", "CCEQ",
    "panic",                      # kc_panic, kc_sys.s
    "uiomove",                    # kc_uiomove, the T3 seam
    "wakeup",                     # kc_wakeup -- live since T1; tty_subr.c
                                  # calls it on cwaiting in six places
    "sleep",                      # kc_sleep, e9adde576.  IT IS THE WRONG SLEEP
                                  # for three of the rows below and the call
                                  # graph cannot say so: kc_sleep is
                                  # UNINTERRUPTIBLE, and ttread/ttwrite/ttioctl
                                  # sleep at TTIPRI/TTOPRI and need the signal
                                  # to unwind.  That is why TTIPRI/TTOPRI are
                                  # DATA_DEPS rows -- a checkable name standing
                                  # for a property the ranking would otherwise
                                  # hide.
    "cdevsw.d_ioctl",             # kc_cdioctl -> _Chardev_Ioctl
    "selwakeup",                  # kc_selwakeup -> wakeup(WCHAN_SELECT)
    "gsignal",                    # kc_gsignal -> _Kill_GroupFanout
    "cdevsw.d_stop",              # kc_cdstop -> _Chardev_Stop (COPS_Stop)
    "ureadc",                     # kc_ureadc -> vfs.mod, beside uiomove.  It
                                  # went THERE rather than into this bank
                                  # because T4's tty_pty.c calls it four times
                                  # from a module -- two callers in two banks.
    "(*t_oproc)", "(*l_rint)", "(*l_start)",
} | MACROS

KW = {"if", "while", "for", "switch", "return", "sizeof", "defined", "else", "do"}

# DATA dependencies, which this scan CANNOT SEE because it only parses calls.
# It has mis-ranked a routine on this three times; a routine here is reported
# with its reason instead of as portable, so the output cannot say "PORTABLE
# NOW" about something that needs a u-area.
#
# The entries are FACTS ABOUT UPSTREAM's source, so they are checked: every
# name listed must actually appear in the routine's body, or the scan fails.
# That is what stops this becoming a stale opinion pinned to a tool.
DATA_DEPS = {
    "ttyopen":   ("u.u_procp", "u.u_ttyp", "u.u_ttyd", "p_pgrp", "p_pid"),
    "ttyselect": ("u.u_procp", "selwait", "t_rsel", "t_wsel"),
    # `lbolt' is h/kernel.h:32, "awoken once a second", and it is a sleep
    # CHANNEL IDENTITY owned by the core clock -- the one dependency here that
    # a local definition would silently break rather than fail to compile: the
    # bank would sleep on its own address and nothing would ever wake it.
    # TTIPRI/TTOPRI say the sleep must be INTERRUPTIBLE; see `sleep' in HAVE.
    "ttread":    ("u.u_procp", "lbolt", "TTIPRI"),
    "ttwrite":   ("u.u_procp", "lbolt", "TTIPRI", "TTOPRI"),
    "ttioctl":   ("u.u_procp", "lbolt", "TTOPRI"),
    # THE THIRD ONE THIS TABLE CAUGHT, and it was found by reading rather than
    # by the scan: ttycheckoutq is ranked behind `sleep, timeout' and also does
    # `oldsig = u.u_procp->p_sig', which is how it notices a signal arrived
    # while it waited.  A seam for `timeout' alone would not have ported it.
    "ttycheckoutq": ("u.u_procp", "p_sig"),
}


def strip(src):
    """Comments and literals out, so comment prose cannot look like a call."""
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r'"(\\.|[^"\\])*"', '""', src)
    src = re.sub(r"'(\\.|[^'\\])*'", "'x'", src)
    return src


def callees(body):
    out = {m.group(1) for m in re.finditer(r"\b([A-Za-z_]\w*)\s*\(", body)} - KW
    # (*table[expr].member)(...) -- the shape a name scan cannot see.
    for m in re.finditer(
            r"\(\s*\*\s*([A-Za-z_]\w*)\s*\[[^\]]*\]\s*\.\s*([A-Za-z_]\w*)\s*\)\s*\(", body):
        out.add(m.group(1) + "." + m.group(2))
    # (*p->member)(...) and (*v.member)(...)
    for m in re.finditer(
            r"\(\s*\*\s*[A-Za-z_]\w*\s*(?:->|\.)\s*([A-Za-z_]\w*)\s*\)\s*\(", body):
        out.add("(*" + m.group(1) + ")")
    return out


def parse(src):
    """{name: (n_lines, callees)} for each column-0 K&R definition."""
    lines = strip(src).split("\n")
    starts = []
    for i, l in enumerate(lines):
        m = re.match(r"^([A-Za-z_]\w*)\s*\(", l)
        if m and m.group(1) not in KW and not l.rstrip().endswith(";"):
            starts.append((i, m.group(1)))
    starts.append((len(lines), None))
    out = {}
    for k in range(len(starts) - 1):
        a, name = starts[k]
        b = starts[k + 1][0]
        out[name] = (b - a, callees("\n".join(lines[a:b])))
    return out


def closures(fns):
    """{name: set of MISSING seams, transitively}."""
    def direct(f):
        return {c for c in fns[f][1] if c not in HAVE and c not in fns}

    def walk(f, seen):
        if f in seen:
            return set()
        seen.add(f)
        out = set(direct(f))
        for c in fns[f][1]:
            if c in fns and c not in PORTED:
                out |= walk(c, seen)
        return out

    return {f: walk(f, set()) for f in fns if f not in PORTED}


def report(fns, miss):
    rows = sorted(((f, fns[f][0], sorted(miss[f])) for f in miss),
                  key=lambda r: (len(r[2]), r[1]))
    print("%-13s %5s  %s" % ("ROUTINE", "LINES", "MISSING SEAMS (transitive closure)"))
    print("-" * 92)
    for f, n, c in rows:
        # DATA DEPS ARE SHOWN EVEN WHEN SEAMS ARE MISSING TOO.  The first cut
        # printed them only for a routine with no missing seam, so ttycheckoutq
        # -- which needs `timeout' AND a u-area -- showed as "sleep, timeout"
        # and read as one seam away from portable.  A partial answer in the
        # column headed MISSING is worse than no column.
        d = ("  + DATA: " + ", ".join(DATA_DEPS[f])) if f in DATA_DEPS else ""
        print("%-13s %5d  %s%s"
              % (f, n, ", ".join(c) or ("no seam missing" if d
                                        else "*** NONE -- PORTABLE NOW ***"), d))

    prims = sorted(set().union(*miss.values())) if miss else []
    print("\nCHEAPEST FIRST: the best k primitives, and what they unlock together")
    for k in range(1, 6):
        best = max(
            (( sum(n for f, n, c in rows if set(c) <= set(combo)), combo)
             for combo in itertools.combinations(prims, k)),
            default=(0, ()))
        tot, combo = best
        got = [f for f, n, c in rows if set(c) <= set(combo)]
        print("  %d: %-56s -> %4d lines" % (k, " + ".join(combo), tot))
        print("     %s" % (", ".join(got) or "-"))


def check_data_deps(fns, src):
    """Every DATA_DEPS name must really appear in that routine's body.

    A hand-written list of things a scan cannot see is exactly the kind of note
    that rots: the routine gets ported, or upstream turns out not to use what
    the list claims, and the tool goes on reporting it.  Checking the list
    against the source on every run is three lines and makes it evidence.
    """
    lines = strip(src).split("\n")
    starts = []
    for i, l in enumerate(lines):
        m = re.match(r"^([A-Za-z_]\w*)\s*\(", l)
        if m and m.group(1) not in KW and not l.rstrip().endswith(";"):
            starts.append((i, m.group(1)))
    starts.append((len(lines), None))
    body = {}
    for k in range(len(starts) - 1):
        a, name = starts[k]
        body[name] = "\n".join(lines[a:starts[k + 1][0]])
    bad = []
    for fn, names in DATA_DEPS.items():
        if fn not in body:
            bad.append("%s: DATA_DEPS names a routine tty.c does not define" % fn)
            continue
        for nm in names:
            probe = nm.split(".")[-1]
            if probe not in body[fn]:
                bad.append("%s: DATA_DEPS claims it reads `%s', and it does not"
                           % (fn, nm))
    return bad


def self_test():
    """The two failures this tool exists to prevent."""
    fns = parse("""
f(tp)
\tstruct tty *tp;
{
\t(*cdevsw[major(tp->t_dev)].d_ioctl)(tp->t_dev, 0, 0, 0);
}

g(tp)
{
\tf(tp);
}
""")
    assert "cdevsw.d_ioctl" in fns["f"][1], "indirect call through a table missed"
    # PIN THE ROSTER FOR THE DURATION.  The test is about the DETECTION -- that
    # an indirect call is seen at all and that closure carries it up -- not
    # about what the bank happens to have today.  Reading the live HAVE made
    # the test fail the moment kc_cdioctl landed and `cdevsw.d_ioctl` stopped
    # being missing, which is the test breaking on a correct change.
    global HAVE
    saved, HAVE = HAVE, {"major"}
    miss = closures(fns)
    HAVE = saved
    assert miss["f"] == {"cdevsw.d_ioctl"}, miss["f"]
    # g calls nothing missing ITSELF; only the closure sees it.
    assert miss["g"] == {"cdevsw.d_ioctl"}, "transitive closure not applied"
    # and a comment must not read as a call
    assert "notacall" not in parse("h()\n{\n\t/* notacall(x) */\n\ti = 1;\n}\n")["h"][1]
    # A MACRO IS NOT A MISSING SEAM -- the fourth wrong ranking.  `sigmask'
    # reads like a call at every site, and only the MACROS set can say
    # otherwise, so both halves are pinned: the parser must still SEE the name,
    # and HAVE must absorb it before the ranking does.
    mk = parse("k()\n{\n\tx = sigmask(SIGTTOU);\n}\n")
    assert "sigmask" in mk["k"][1], "the scan must still see sigmask as a name"
    assert "sigmask" in HAVE, "sigmask absent from HAVE would rank as a seam"
    print("tty_closure_scan self-test OK")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
        sys.exit(0)
    src = open(TTY_C).read()
    fns = parse(src)
    bad = check_data_deps(fns, src)
    if bad:
        for b in bad:
            sys.stderr.write("tty_closure_scan: %s\n" % b)
        sys.exit(1)
    miss = closures(fns)
    report(fns, miss)
