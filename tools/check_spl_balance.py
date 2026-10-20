#!/usr/bin/env python3
"""check_spl_balance.py - no `spltty()' in the tty bank leaks the interrupt mask.

WHY THIS EXISTS, and it is not a style rule.  At apple/fgx#108 T6 increment 2
`spltty()'/`splx()' stopped being empty macros (src/kernel/tty/ttyparam.h) and
became a real bracket: SEI, and restore the caller's I bit.  From that moment a
`spltty()' whose `splx()' never runs does not merely lose an optimisation -- it
leaves interrupts masked forever.

THE HEARTBEAT IS THE VBL.  With I set the quantum stops counting, `lbolt' never
fires, the keyboard is never scanned and the tty signal latch is never drained.
The machine does not crash: it goes quiet.  That is the hardest failure shape
this campaign has met, because a halt "looks like no verdict AND no failure" --
every LACKS assertion passes and nothing in the run names a cause.

IT HAS ALREADY HAPPENED ONCE, which is why the rule is a script and not a
paragraph.  `ttyunblock' takes `s = spltty()' and never calls `splx(s)' --
verbatim from vendor/2.11BSD/usr/sys/sys/tty.c:252, where it is a harmless dead
store because nothing after it needs the priority back.  Carrying it verbatim
was right while the macros were empty and became a latent hang the day they
were not.  Seventy call sites were read once by hand to find it; the tree should
not have to rest on that having been done perfectly.

WHAT IS CHECKED, and each rule catches a class the others do not:

  1  A function that calls `spltty()' and NEVER calls `splx()'.  This is the
     ttyunblock shape exactly, and it is the only rule here with no
     approximation in it: no path out of such a function can restore the mask.

  2  A `return' between a `spltty()' and its `splx()' AT THE SAME BRACE DEPTH.
     The classic early-out leak.  Restricted to equal depth deliberately -- a
     `return' inside a nested block is usually preceded by its own `splx' (catq
     is the example in this tree), and flagging those would make the check noise
     rather than a rule.

  3  A BLOCKING CALL inside an spl region.  Not an error: `ttywait' has one and
     it is correct.  FGX's `_sleep' documents the contract -- "The caller must
     re-test its wait condition under SEI (spl) and only then call _sleep, to
     avoid a lost wakeup ... _sleep keeps IRQs masked across the switch and CLIs
     on wake" (src/kernel/sched.s) -- so a sleep at spl is what the scheduler
     ASKS for, and upstream's `sleep()' behaves the same way.  What the rule
     does is RATCHET the set: a new one must be named here, so someone looks at
     it once rather than nobody looking at it ever.

     The subtlety worth carrying: because `_sleep' CLIs on wake, an spl region
     that continues after a sleep is ALREADY at spl0.  `ttywait' re-raises
     immediately (`splx(s); s = spltty();'), which is upstream's own line -- so
     there the `splx' is the no-op and the re-take is the real work.

THE ASSEMBLY HALF (apple/fgx#108 T6 increment 3).  Two core routines mask for
their whole length so that interrupt-time `ttyinput' cannot re-enter them --
`_wakeup', whose `_wkChan' an ISR would replace mid-scan, and
`_Kill_GroupFanout', which parks the signal number in the SHARED `_shTmp1'.
Deleting the `SEI' from either is SILENT: nothing fails, the hazard simply
returns and waits for a tick to land in the wrong place.  Deleting the `PLP' is
loud -- the machine hangs on the next boot -- so it needs no rule here.  MASKED
is what makes the silent half a build error.

NOT CHECKED, DELIBERATELY: full path coverage.  That needs a C front end, and
the two shapes above are the ones that have actually occurred.  This is a
ratchet on a known failure class, not a proof.

BLOCK COMMENTS ARE STRIPPED BEFORE ANYTHING IS COUNTED, and the first draft of
this survey did not do it: tty_dev.c has a paragraph explaining that "FGX's
`spltty()' is empty ... so the discipline has no other protection", and the
scan reported `kc_ttread' as a second unconditional leak on the strength of it.
A checker that reads prose as code produces confident false findings, which is
worse than no checker.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = ["src/kernel/tty/tty.c", "src/kernel/tty/tty_subr.c",
         "src/kernel/tty/tty_dev.c"]

SPLTTY = re.compile(r"\bspltty\s*\(\s*\)")
SPLX = re.compile(r"\bsplx\s*\(")
BLOCKING = re.compile(r"\b(kc_sleep|kc_sleepun|kc_lbolt)\s*\(")
RETURN = re.compile(r"^\s*return\b")
FUNC = re.compile(r"^([a-z_][a-z0-9_]*)\s*\(")

# Rule 3's ratchet: the blocking calls that are KNOWN to sit inside an spl
# region, each with the reason it is correct.  A site not on this list is
# reported so it gets looked at once.
# routine -> the source file it lives in.  Each must contain SEI, and a PLP for
# every RTS, inside the routine body.
MASKED = {
    "_wakeup": "src/kernel/sched.s",
    "_Kill_GroupFanout": "src/kernel/signal.s",
}

ALLOWED_BLOCKING = {
    ("src/kernel/tty/tty.c", "ttywait", "kc_sleep"):
        "upstream's own shape (tty.c:150); _sleep CLIs on wake and ttywait "
        "re-raises on the next line",
}


def strip_comments(text):
    """Remove /*...*/ and //... so prose about spltty is not read as code."""
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        elif text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def scan(rel, text):
    """Return (errors, blocking_sites) for one file's source text."""
    errors, blocking = [], []
    lines = strip_comments(text).split("\n")
    fn, fnline, brace = None, 0, 0
    opens, closes = [], []

    def finish():
        if fn and opens and not closes:
            errors.append(
                f"{rel}:{fnline}: {fn}() takes spltty() and never calls splx(). "
                f"Since T6 increment 2 that leaves interrupts masked for good: "
                f"the heartbeat is the VBL, so the machine goes quiet with no "
                f"verdict and no failure. This is ttyunblock's shape "
                f"(vendor/2.11BSD/usr/sys/sys/tty.c:252), where it was a "
                f"harmless dead store upstream.")

    for i, raw in enumerate(lines, 1):
        if brace == 0:
            m = FUNC.match(raw)
            if m and not raw.rstrip().endswith(";"):
                finish()
                fn, fnline = m.group(1), i
                opens, closes = [], []
        if SPLTTY.search(raw):
            opens.append((i, brace))
        if SPLX.search(raw):
            closes.append((i, brace))
        if opens and len(closes) < len(opens):
            m = BLOCKING.search(raw)
            if m:
                blocking.append((rel, fn, m.group(1), i))
            if RETURN.match(raw) and brace == opens[-1][1]:
                errors.append(
                    f"{rel}:{i}: {fn}() returns at the same brace depth it took "
                    f"spltty() at (:{opens[-1][0]}), with no splx() between. "
                    f"That path leaves interrupts masked.")
        brace += raw.count("{") - raw.count("}")
    finish()
    return errors, blocking


def routine_body(text, name):
    """The lines of one assembly routine: its label line to the next label."""
    lines, out, inside = text.split("\n"), [], False
    for line in lines:
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\b", line)
        if m:
            if inside:
                break
            inside = m.group(1) == name
        if inside:
            out.append(line)
    return out


def check_masked(read):
    """Each MASKED routine must SEI, and PLP on every RTS."""
    bad = []
    for name, rel in MASKED.items():
        body = routine_body(read(rel), name)
        if not body:
            bad.append(f"{rel}: {name} not found -- the mask rule is checking "
                       f"nothing.")
            continue
        code = [l.split(";", 1)[0] for l in body]
        if not any(re.search(r"\bSEI\b", l) for l in code):
            bad.append(
                f"{rel}: {name} no longer masks. It is reached from ttyinput at "
                f"interrupt time (apple/fgx#108 T6) and holds a singleton an "
                f"ISR would replace mid-scan, so removing the SEI does not fail "
                f"-- the hazard just comes back and waits for a tick to land in "
                f"the wrong place.")
        rts = sum(1 for l in code if re.search(r"\bRTS\b", l))
        plp = sum(1 for l in code if re.search(r"\bPLP\b", l))
        if rts and plp < rts:
            bad.append(
                f"{rel}: {name} has {rts} RTS but only {plp} PLP. An exit that "
                f"does not restore leaves interrupts masked, and the heartbeat "
                f"is the VBL.")
    return bad


def main():
    errors, blocking = [], []
    for rel in FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            errors.append(f"{rel} is missing -- the spl rule cannot be checked.")
            continue
        e, b = scan(rel, open(path, errors="replace").read())
        errors += e
        blocking += b

    for rel, fn, call, line in blocking:
        if (rel, fn, call) not in ALLOWED_BLOCKING:
            errors.append(
                f"{rel}:{line}: {fn}() calls {call}() inside an spl region and "
                f"is not in ALLOWED_BLOCKING. That is not automatically wrong "
                f"-- sched.s asks callers to sleep at spl -- but _sleep CLIs on "
                f"wake, so the region is at spl0 afterwards and must re-take it "
                f"if it continues. Read the site, then name it in this script "
                f"with the reason.")

    errors += check_masked(
        lambda rel: open(os.path.join(ROOT, rel), errors="replace").read())

    if errors:
        print("check_spl_balance: SPL BRACKET BROKEN:", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 1
    print(f"    check_spl_balance: clean ({len(FILES)} file(s), "
          f"{len(blocking)} allowed blocking call(s) inside an spl region, "
          f"{len(MASKED)} masked core routine(s))")
    return 0


def selftest():
    """Each rule must reject the shape it exists for."""
    fails = []
    leak = "ttyunblock(tp)\n{\n    s = spltty();\n    foo();\n}\n"
    if not scan("t.c", leak)[0]:
        fails.append("a spltty() with no splx() at all was not caught -- "
                     "this is the shape that shipped")
    ok = "ttyflush(tp)\n{\n    s = spltty();\n    foo();\n    splx(s);\n}\n"
    if scan("t.c", ok)[0]:
        fails.append("a balanced bracket was reported as broken")
    early = ("ttread(tp)\n{\n    s = spltty();\n    if (x)\n        return (1);\n"
             "    splx(s);\n}\n")
    if not scan("t.c", early)[0]:
        fails.append("a return between spltty() and splx() at the same depth "
                     "was not caught")
    nested = ("catq(a, b)\n{\n    s = spltty();\n    if (x) {\n        splx(s);\n"
              "        return;\n    }\n    splx(s);\n}\n")
    if scan("t.c", nested)[0]:
        fails.append("catq's shape -- splx before a nested return -- was "
                     "reported as broken")
    prose = ("kc_ttread(tp)\n{\n    /* FGX's spltty() is empty, so the shape is\n"
             "     * what provides the protection. */\n    foo();\n}\n")
    if scan("t.c", prose)[0]:
        fails.append("a COMMENT mentioning spltty() was read as code -- the "
                     "exact false finding the first draft produced")
    unknown = ("ttyfoo(tp)\n{\n    s = spltty();\n    kc_lbolt();\n    splx(s);\n}\n")
    if not scan("t.c", unknown)[1]:
        fails.append("a blocking call inside an spl region was not reported")

    # The assembly half: a routine that stopped masking, and one that leaks.
    src = {"src/kernel/sched.s":
           "_wakeup ENT\n                PHP\n                SEI\n"
           "                PLP\n                RTS\n_next   ENT\n",
           "src/kernel/signal.s":
           "_Kill_GroupFanout MX %00\n                PHP\n                SEI\n"
           "                PLP\n                RTS\n                PLP\n"
           "                RTS\n_next   MX %00\n"}
    if check_masked(lambda rel: src[rel]):
        fails.append("a correctly masked routine was reported as broken")
    nosei = dict(src)
    nosei["src/kernel/sched.s"] = src["src/kernel/sched.s"].replace(
        "                SEI\n", "")
    if not check_masked(lambda rel: nosei[rel]):
        fails.append("a routine that stopped masking was not caught -- this is "
                     "the SILENT half, and the only rule that can see it")
    leak = dict(src)
    leak["src/kernel/signal.s"] = src["src/kernel/signal.s"].replace(
        "                PLP\n                RTS\n                PLP\n", 
        "                PLP\n                RTS\n")
    if not check_masked(lambda rel: leak[rel]):
        fails.append("an exit with no PLP was not caught")
    gone = dict(src)
    gone["src/kernel/sched.s"] = "_something_else ENT\n                RTS\n"
    if not check_masked(lambda rel: gone[rel]):
        fails.append("a MASKED routine that no longer exists was not caught -- "
                     "the rule would be checking nothing")

    if fails:
        print("check_spl_balance self-test: FAILURE(S)", file=sys.stderr)
        for f in fails:
            print(f"  {f}", file=sys.stderr)
        return 1
    print("check_spl_balance self-test: OK (catches an unbalanced bracket, an "
          "early return at the same depth, and a blocking call in an spl "
          "region; does not mistake a comment for code or flag catq's nested "
          "splx)")
    return 0


if __name__ == "__main__":
    sys.exit((selftest() if "--self-test" in sys.argv else main()) or 0)
