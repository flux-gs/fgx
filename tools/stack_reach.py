#!/usr/bin/env python3
"""stack_reach.py - how much of a task's stack must be ADDRESSABLE in bank 0 at
any one instant, as opposed to how much is live.

This is the sliding-window question (2026-08-02).  bsh sourcing 55
commands holds 7,150 bytes live, but the running code can only reach its own
frame plus its arguments -- 121 bytes.  The other 98% is written once on the way
down and read once on the way back, and between those two moments nothing can
touch it.  If that stays true, the cold part does not have to be in bank 0 at
all, and a small bank-0 window backed by far memory becomes possible.

Three numbers per binary, all read from fcc's emitted assembly:

  own    max `n,S` offset with no +FRAMESIZE term -- inside the current frame
  args   max `n+<fn>_FRAMESIZE,S` offset -- into the CALLER's argument block
  mints  `LDA _fcc_fb / CLC / ADC #n`, the &local idiom (emit_addr_of_local) --
         an absolute bank-0 stack address that can be handed DOWNWARD

`own` and `args` bound the reach: nothing fcc emits reaches a grandparent frame,
and `_fcc_fb` is only stored/loaded/PEI'd/INC'd, never indirected through.

`mints` is the blocker, and it is the whole reason increment 3.1 is called a
correctness prerequisite rather than an optimisation: a callee holding `&buf`
can dereference back into a frame a window would have spilled.  **A window is
only possible once this reaches 0.**  Track it per increment.

`window` is the bank-0 residency a one-frame window would need:
max FRAMESIZE (the frame is allocated whether or not it is addressed directly)
+ args + linkage + the non-C pad.

Usage:
    tools/stack_reach.py                 print the table
    tools/stack_reach.py --record LABEL  append a scan to the baseline ledger
    tools/stack_reach.py --self-test     prove the patterns on known assembly
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "toolchain", "src", "ld"))

LEDGER = os.path.join(ROOT, "tools", "stack_baseline.json")

# Programs worth tracking: the two shells (the recursion cases), and a couple of
# ordinary tools as a control -- a design that only works for shells is not a
# design.
PROGRAMS = ["sh", "tcsh", "tar", "grep", "ls"]

FRAME_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)_FRAMESIZE\s+EQU\s+(\d+)", re.M)
# Stack-relative operand.  Group 2 present => the offset is measured from the
# top of our own frame, i.e. it addresses the caller's pushed arguments.
SREL_RE = re.compile(
    r"^\s+[A-Z]{3}\s+(\d+)(\+[A-Za-z_][A-Za-z0-9_]*_FRAMESIZE)?,S", re.M)
# emit_addr_of_local's &local carrier: bank 0 staged, then fb + frame offset.
MINT_RE = re.compile(r"LDA\s+_fcc_fb\s*\n\s+CLC\s*\n\s+ADC\s+#\d+", re.M)
# Any OTHER use of _fcc_fb.  Save/restore/bump are fine; an indirection through
# it would mean the reach is not bounded by `own`+`args` and this whole analysis
# is wrong, so it is checked rather than assumed.
# `_fcc_fb` must be matched with an IDENTIFIER BOUNDARY, not as a prefix: libc's
# softfloat has _fcc_fb_exp / _fcc_fb_hi / _fcc_fb_lo / _fcc_fb_sign (the "float
# b" operand), which are unrelated symbols.  Without the boundary the
# unmodelled-use detector reported five of them on every binary.
FB = r"_fcc_fb(?![A-Za-z0-9_])"
FB_OK_RE = re.compile(r"^\s+(?:STA|LDA|PEI|INC|DEC)\s+" + FB + r"\s*$")
FB_ANY_RE = re.compile(r"^\s+\S+.*" + FB + r".*$", re.M)
# Merlin comments run from `;` to end of line, and libc.s DISCUSSES _fcc_fb at
# length.  Matching whole lines made the unmodelled-use detector fire on prose
# the moment the scan started reading the libc pile -- a checker that cries wolf
# is one people learn to ignore, which is worse than not having it.
CODE_ONLY = re.compile(r"^([^;]*)")

LINKAGE = 5          # JSL return address + PEI'd saved frame pointer
PAD = 128            # DEFAULT_PAD: the non-C excursion budget (stack_measure)


PUT_RE = re.compile(r"^\s+PUT\s+(\S+)", re.M)

# Layout and macro scaffolding carries no frames; skipped so `functions`
# stays a count of real code.
SKIP = {"macros.s", "dataseg_layout.s", "seg1_layout.s", "imports_layout.s"}


def sources(program, bdir=None):
    """Every .s the binary actually LINKS, from the link files its build
    wrote: <bdir>/seg*.link.s, and seg*.link.s and bank*.link.s in each
    <bdir>/*.ld/ (fgx_static's and fgx_dyn's).  A PUT resolves against its
    own link file's directory.

    This used to glob tools/<name>-fgx2/*.s, which silently excluded the shared
    libc pile -- it is PUT from toolchain/lib/.  Measured 2026-08-02: libc_c.s
    alone has 31 &local mints over 188 functions and libc_net.s 35 over 14 with
    a 192-byte frame, so bsh's headline "26 mints" was really 57+ and its
    `window` was quoted below a frame that ships inside it.

    The failure mode that made this urgent is not the wrong number, it is the
    RIGHT one arriving later: once increment 1.2 drives the in-tree mints to
    zero, a glob-based scan prints 0 while libc still mints dozens -- and the
    phase-1 exit decision (design 3.3b) is taken on a false zero.  Reading the
    link recipe means the tool cannot be fooled by where a file lives.
    """
    bdir = bdir or os.path.join(ROOT, "tools", "%s-fgx2" % program)
    links = glob.glob(os.path.join(bdir, "seg*.link.s"))
    for ld in glob.glob(os.path.join(bdir, "*.ld")):
        links += glob.glob(os.path.join(ld, "seg*.link.s"))
        links += glob.glob(os.path.join(ld, "bank*.link.s"))
    out, seen = [], set()
    for link in sorted(links):
        here = os.path.dirname(link)
        for put in PUT_RE.findall(open(link, errors="replace").read()):
            if not put.endswith(".s") or put.endswith(".data.s"):
                continue
            path = os.path.realpath(os.path.join(here, put))
            if path in seen or not os.path.exists(path):
                continue
            if os.path.basename(path) in SKIP:
                continue
            seen.add(path)
            out.append(path)
    if not out:                      # no link recipe (fixture dirs): old glob
        out = [f for f in glob.glob(os.path.join(bdir, "*.s"))
               if not f.endswith(".link.s") and not f.endswith(".data.s")]
    return out


ENT_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+ENT", re.M)


def analyze(paths):
    """Per-FUNCTION, because the global maxima are not comparable.

    `own` can legitimately exceed a function's FRAMESIZE: fcc addresses locals
    at `n,S`, and n includes any argument bytes already pushed for a call in
    flight (g_s_delta).  Those bytes are still OURS.  What would break the
    bounded-reach claim is an offset that exceeds frame + in-flight pushes and
    so lands in the CALLER's frame -- so the excess is measured per function and
    reported, rather than two unrelated maxima being eyeballed against each
    other.
    """
    frames, spans, mints, odd = {}, [], 0, []
    for p in paths:
        t = open(p, errors="replace").read()
        for m in FRAME_RE.finditer(t):
            frames[m.group(1)] = int(m.group(2))
        mints += len(MINT_RE.findall(t))
        ents = list(ENT_RE.finditer(t))
        for i, m in enumerate(ents):
            end = ents[i + 1].start() if i + 1 < len(ents) else len(t)
            spans.append((m.group(1), t[m.start():end]))
        for line in FB_ANY_RE.findall(t):
            code = CODE_ONLY.match(line).group(1)
            if not re.search(FB, code):
                continue                      # prose about it, not a use of it
            if not FB_OK_RE.match(code.rstrip()) and "ADC" not in code:
                odd.append(code.strip())

    own = args = excess = 0
    worst = None
    for name, body in spans:
        fs = frames.get(name)
        if fs is None:
            continue
        for m in SREL_RE.finditer(body):
            n = int(m.group(1))
            if m.group(2):
                args = max(args, n)
                continue
            own = max(own, n)
            if n - fs > excess:
                excess, worst = n - fs, "%s(%d) reaches %d" % (name, fs, n)
    return {"functions": len(frames),
            "max_frame": max(frames.values(), default=0),
            "own": own, "args": args, "mints": mints,
            "excess": excess, "worst_excess": worst,
            "window": max(frames.values(), default=0) + args + LINKAGE + PAD,
            "unexpected_fb": sorted(set(odd))[:5]}


def scan():
    out = {}
    for p in PROGRAMS:
        ss = sources(p)
        if ss:
            out[p] = analyze(ss)
    return out


def _self_test():
    """Prove each pattern against assembly that is known to contain -- and known
    to lack -- what it looks for.  Every number here is a MAXIMUM over a scan,
    so a pattern that silently stopped matching would report a smaller window
    and a lower mint count, which is the reassuring direction and the wrong one.
    """
    fails = 0
    src = (
        "foo_FRAMESIZE   EQU     40\n"
        "foo             ENT\n"
        "                LDA     12,S\n"                 # own frame
        "                STA     6,S\n"
        "                LDA     18+foo_FRAMESIZE,S\n"   # caller's args
        "                PEI     _fcc_fb\n"              # save: fine
        "                LDA     _fcc_fb\n"
        "                CLC\n"
        "                ADC     #8\n"                   # &local -- a mint
        "                STA     _fcc_fb\n")
    import tempfile
    with tempfile.NamedTemporaryFile("w", suffix=".s", delete=False) as f:
        f.write(src)
        path = f.name
    g = analyze([path])
    os.unlink(path)
    want = {"functions": 1, "max_frame": 40, "own": 12, "args": 18, "mints": 1,
            "excess": 0}
    for k, v in want.items():
        if g[k] != v:
            print("  SELFTEST FAIL: %s = %r, want %r" % (k, g[k], v))
            fails += 1
    if g["window"] != 40 + 18 + LINKAGE + PAD:
        print("  SELFTEST FAIL: window %d" % g["window"])
        fails += 1
    if g["unexpected_fb"]:
        print("  SELFTEST FAIL: flagged ordinary _fcc_fb use: %r"
              % g["unexpected_fb"])
        fails += 1

    # The reach claim rests on there being NO indirection through _fcc_fb.
    # Prove the detector for that actually fires, or its silence means nothing.
    with tempfile.NamedTemporaryFile("w", suffix=".s", delete=False) as f:
        f.write("bar_FRAMESIZE   EQU     8\nbar   ENT\n"
                "                LDA     [_fcc_fb],Y\n")
        path = f.name
    g2 = analyze([path])
    os.unlink(path)
    if not g2["unexpected_fb"]:
        print("  SELFTEST FAIL: an indirection through _fcc_fb was not flagged "
              "-- the bounded-reach claim would be unverified")
        fails += 1

    # ...and it must NOT fire on the two things that made it cry wolf the
    # moment the scan started reading the libc pile: prose ABOUT _fcc_fb, and
    # unrelated symbols that merely share its prefix (softfloat's _fcc_fb_exp
    # and friends).  A detector everyone learns to ignore is worse than none.
    for label, src in (
            ("a comment mentioning _fcc_fb",
             "z_FRAMESIZE  EQU  4\nz  ENT\n"
             "                LDA     2,S       ; restores _fcc_fb later\n"),
            ("the unrelated symbol _fcc_fb_sign",
             "z_FRAMESIZE  EQU  4\nz  ENT\n"
             "                CMP     _fcc_fb_sign\n"
             "                EOR     _fcc_fb_exp\n")):
        with tempfile.NamedTemporaryFile("w", suffix=".s", delete=False) as f:
            f.write(src)
            path = f.name
        g3 = analyze([path])
        os.unlink(path)
        if g3["unexpected_fb"]:
            print("  SELFTEST FAIL: flagged %s: %r" % (label, g3["unexpected_fb"]))
            fails += 1

    # sources() must read the .ld directories fgx_static/fgx_dyn write, not
    # just a bdir/seg*.link.s that no static or dynamic link produces.
    import tempfile, shutil
    tmp = tempfile.mkdtemp()
    try:
        ld = os.path.join(tmp, "static.ld")
        os.makedirs(ld)
        open(os.path.join(tmp, "prog.s"), "w").write("; prog\n")
        open(os.path.join(ld, "bank0.s"), "w").write("; bank0\n")
        open(os.path.join(ld, "seg1_layout.s"), "w").write("; layout\n")
        open(os.path.join(ld, "seg0.link.s"), "w").write(
            "        PUT  ../prog.s\n"
            "        PUT  seg1_layout.s\n"
            "        PUT  bank0.s\n")
        open(os.path.join(ld, "bank0.link.s"), "w").write(
            "        PUT  bank0.s\n")
        got = sorted(sources("whatever", bdir=tmp))
        want = sorted(os.path.realpath(p) for p in
                       (os.path.join(tmp, "prog.s"), os.path.join(ld, "bank0.s")))
        if got != want:
            print("  SELFTEST FAIL: sources(bdir=...) = %r, want %r"
                  % (got, want))
            fails += 1
    finally:
        shutil.rmtree(tmp)

    if fails:
        print("stack_reach self-test: %d FAILURE(S)" % fails)
        return 1
    print("stack_reach self-test: OK (11 cases)")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--record", metavar="LABEL")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return _self_test()

    got = scan()
    if not got:
        print("!! no built assembly found under tools/<name>-fgx2/ -- "
              "run `ninja` first; an empty scan is not a measurement")
        return 1
    print("%-8s %5s %9s %5s %5s %7s %6s %8s"
          % ("binary", "fns", "max frame", "own", "args", "over fs", "mints",
             "window"))
    for p, d in got.items():
        print("%-8s %5d %9d %5d %5d %7d %6d %8d"
              % (p, d["functions"], d["max_frame"], d["own"], d["args"],
                 d["excess"], d["mints"], d["window"]))
        if d["worst_excess"]:
            print("           worst: %s" % d["worst_excess"])
        if d["unexpected_fb"]:
            print("   !! _fcc_fb used in an unmodelled way -- the bounded-reach "
                  "claim needs re-checking: %r" % d["unexpected_fb"])

    if args.record:
        import datetime
        led = json.load(open(LEDGER)) if os.path.exists(LEDGER) else {}
        r = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                           capture_output=True, text=True)
        led.setdefault("reach_scans", []).append({
            "label": args.record,
            "date": datetime.date.today().isoformat(),
            "commit": r.stdout.strip() or "?",
            "programs": got})
        json.dump(led, open(LEDGER, "w"), indent=1)
        print("\nrecorded '%s'" % args.record)
    return 0


if __name__ == "__main__":
    sys.exit(main())
