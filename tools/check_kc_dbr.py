#!/usr/bin/env python3
"""check_kc_dbr.py - no CORE-bank static may be read DBR-relative inside a
KC_ENTER/KC_LEAVE bracket.

KC_ENTER switches DBR to the FAR bank as well as switching the direct page,
because fcc addresses kernel C's globals and its runtime scratch DBR-relative
and those live there.  The consequence is easy to write and impossible to see:
a `|_coreStatic` between the two macros keeps assembling, keeps its 16-bit
operand, and reads the FAR bank at that offset instead.  No symbol is
undefined, no relocation is missing, and the value that comes back is whatever
unrelated far-bank byte happens to sit there.

That is exactly how _BufInit handed bufinit an arena base it had never
allocated: the argument push sat after KC_ENTER, so the pointer came out of the
far bank while _bufArenaBase held the right address the whole time.  The
buffer cache then ran against a pool nobody owned, and every symptom pointed at
the block layer.

THE FIX IS ALWAYS THE SAME: capture the value into X or Y BEFORE KC_ENTER --
the macro clobbers A only -- and push it from there.

If the symbol really is a far-bank static, the read is correct: mark that line
`; KCDBR-OK` and it is skipped.

MOD_KC_ENTER COUNTS TOO, and the hazard there is the same shape inverted.  A
module's bracket points DBR at the MODULE's own bank, so an absolute read of a
KERNEL static inside it takes the module's bytes at that offset -- and a module
runs with DBR = the kernel bank by default, so the read looks right everywhere
else in the file.  The rule is identical either way: nothing absolute inside
the bracket unless it is deliberate and waived.
"""
import glob
import os
import re
import sys

ENTER_RE = re.compile(r"^\s*(?:MOD_)?KC_ENTER\b")
LEAVE_RE = re.compile(r"^\s*(?:MOD_)?KC_LEAVE\b")
# Merlin's forced-absolute operand: the idiom this tree uses for a static that
# is addressed through DBR rather than direct page.
ABS_RE = re.compile(r"^\s*(?:\S+\s+)?[A-Z]{3}\s+\|(\w+)")

# ---------------------------------------------------------------------------
# THE SECOND BRACKET: MVN/MVP .. DBR restore.
#
# Same hazard, different opener.  MVN and MVP leave DBR on the DESTINATION
# bank -- that is the instruction's documented behaviour, not a bug -- so every
# DBR-relative access after one reads the wrong bank until DBR is put back.
#
# It is bracketed exactly like KC_ENTER/KC_LEAVE, so it is checked here rather
# than in a tool of its own.  What it catches is not hypothetical: it is how a
# row fill came to read its MVN byte count out of CHARBUF (two spaces, $2020 =
# 8224) and smear 79 bytes across FGBUF and BGBUF on every scroll.
#
# It also became much easier to hit the day the console's cursor/colour scalars
# stopped being direct-page cells.  A direct-page access is bank-immune: DBR
# simply does not participate.  Move that same datum to a far-bank static and
# every read of it becomes DBR-relative, so code that was correct beside an MVN
# for years is silently wrong the moment the datum moves.  Two reads of VT_FG
# and two of VT_BG were exactly that, and only a golden-hash test saw it.
#
# CLOSERS: _DBRK (PHK/PLB), a bare PLB, a RETURN, or a global label -- a new
# routine is a new DBR contract, and every far entry establishes its own.
# Local labels (@foo) do NOT close: a branch target inside a routine inherits
# whatever the fall-through path left, and assuming otherwise is how this class
# hides.
#
# RTS/RTL/RTI CLOSE, and leaving them out is what the first cut got wrong.  It
# reported three hits in block.s where an MVN on the non-extended SmartPort
# path is followed immediately by PLP/SEC/RTS, and the flagged reads are inside
# @sprb_ext -- a branch target on a path that never executed that MVN.  Control
# cannot fall through a return, so the dirty region ends there.
#
# This is deliberately a fall-through analysis and not a control-flow graph.
# It can still be fooled by a branch INTO a dirty region from a clean one; what
# it cannot do is stay quiet about the straight-line case, which is the one
# that actually ships.
# ---------------------------------------------------------------------------
MOVE_RE = re.compile(r"^\s*(?:\S+\s+)?(?:MVN|MVP)\b")
RESTORE_RE = re.compile(r"^\s*(?:\S+\s+)?(?:_DBRK\b|PLB\b|RTS\b|RTL\b|RTI\b)")
GLOBAL_LABEL_RE = re.compile(r"^[A-Za-z_]\w*")


def check(path):
    hits = []
    move_hits = []
    inside = False
    moved_at = 0
    with open(path) as f:
        for n, line in enumerate(f, 1):
            code = line.split(";")[0]
            if ENTER_RE.match(line):
                inside = True
                continue
            if LEAVE_RE.match(line):
                inside = False
                continue
            if MOVE_RE.match(code):
                moved_at = n
                continue
            if RESTORE_RE.match(code) or (moved_at and
                                          GLOBAL_LABEL_RE.match(code)):
                moved_at = 0
                continue
            m = ABS_RE.match(code)
            if not m:
                continue
            if inside and "KCDBR-OK" not in line:
                hits.append((n, m.group(1), line.rstrip()))
            elif moved_at and "MVNDBR-OK" not in line:
                move_hits.append((n, moved_at, m.group(1), line.rstrip()))
    for n, sym, text in hits:
        print(f"check_kc_dbr: {path}:{n}: |{sym} read inside a "
              f"KC_ENTER/KC_LEAVE bracket, where DBR is the FAR bank.",
              file=sys.stderr)
        print(f"    {text}", file=sys.stderr)
    if hits:
        print("Capture the value into X or Y before KC_ENTER (it clobbers A "
              "only), or mark the line ; KCDBR-OK if the symbol is a far-bank "
              "static.", file=sys.stderr)
    for n, mv, sym, text in move_hits:
        print(f"check_kc_dbr: {path}:{n}: |{sym} read DBR-relative while DBR "
              f"is still the destination bank of the MVN/MVP at line {mv}.",
              file=sys.stderr)
        print(f"    {text}", file=sys.stderr)
    if move_hits:
        print("Put DBR back with _DBRK before the read, or mark the line "
              "; MVNDBR-OK if reading the destination bank is deliberate.",
              file=sys.stderr)
    return 1 if (hits or move_hits) else 0


def selftest():
    """Red on a bracketed absolute read, green once it moves out of it."""
    import contextlib
    import io
    import tempfile
    bad = ("                KC_ENTER\n"
           "                LDA    |_bufArenaBase\n"
           "                PHA\n"
           "                KC_LEAVE\n")
    good = ("                LDX    |_bufArenaBase\n"
            "                KC_ENTER\n"
            "                TXA\n"
            "                PHA\n"
            "                KC_LEAVE\n"
            "                LDA    |_bufArenaBase\n")
    allowed = ("                KC_ENTER\n"
               "                LDA    |_kcFarStatic   ; KCDBR-OK far bank\n"
               "                KC_LEAVE\n")
    # The module bracket is a DIFFERENT macro name reaching the same hazard, so
    # it gets its own case rather than being assumed to fall out of the regex.
    modbad = ("                MOD_KC_ENTER\n"
              "                LDA    |_kernStatic\n"
              "                PHA\n"
              "                MOD_KC_LEAVE\n")
    # THE MVN BRACKET.  `mvnbad` is the REAL defect, verbatim from
    # _Con_FillAttrBuf on the day the console scalars moved out of the direct
    # page -- not a synthetic shape that merely resembles it.  A self-test that
    # passes on an invented case and misses the shipped one is how the last
    # gate in this tree came to report clean with the bug still in the file.
    mvnbad = ("_Con_FillAttrBuf\n"
              "_kcm013         MVN     $03,$03\n"
              "                SEP     #$20\n"
              "                LDA    |CON_VT_STATE+VT_FG\n")
    mvngood = ("_Con_FillAttrBuf\n"
               "_kcm013         MVN     $03,$03\n"
               "                SEP     #$20\n"
               "                _DBRK\n"
               "                LDA    |CON_VT_STATE+VT_FG\n")
    mvnwaived = ("_Con_Copy\n"
                 "                MVN     $03,$03\n"
                 "                LDA    |CON_CHARBUF    ; MVNDBR-OK dest bank\n")
    # A LOCAL label must NOT close the bracket -- a branch target inherits the
    # fall-through path's DBR -- while a GLOBAL one must, because a new routine
    # establishes its own.
    mvnlocal = ("_Con_Fill\n"
                "                MVN     $03,$03\n"
                "@fill_next      LDA    |CON_VT_STATE+VT_FG\n")
    mvnnextfn = ("_Con_Fill\n"
                 "                MVN     $03,$03\n"
                 "_Con_Other      LDA    |CON_VT_STATE+VT_FG\n")
    # block.s's real shape: the MVN path RETURNS, and the flagged read is in a
    # sibling branch target that never ran it.  Green, or the checker cries
    # wolf on working code -- which is how a gate gets switched off.
    mvnreturns = ("_Blk_Read\n"
                  "@sprb_mvn       MVN     $00,$02\n"
                  "                PLP\n"
                  "                SEC\n"
                  "                RTS\n"
                  "@sprb_ext       LDA    |_blkCurBufBank\n")
    rc = 0
    for name, body, want in (("bad", bad, 1), ("good", good, 0),
                             ("allowed", allowed, 0), ("modbad", modbad, 1),
                             ("mvnbad", mvnbad, 1), ("mvngood", mvngood, 0),
                             ("mvnwaived", mvnwaived, 0),
                             ("mvnlocal", mvnlocal, 1),
                             ("mvnnextfn", mvnnextfn, 0),
                             ("mvnreturns", mvnreturns, 0)):
        with tempfile.NamedTemporaryFile("w", suffix=".s", delete=False) as f:
            f.write(body)
            p = f.name
        # The red case prints its diagnostic on the way past; swallow it so a
        # passing self-test is silent and a real failure stands out.
        with contextlib.redirect_stderr(io.StringIO()):
            got = check(p)
        os.unlink(p)
        if got != want:
            print(f"SELFTEST FAIL: {name} returned {got}, wanted {want}",
                  file=sys.stderr)
            rc = 1
    if rc == 0:
        print("check_kc_dbr selftest: OK (red inside the bracket, green "
              "outside it and on KCDBR-OK)")
    return rc


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] in ("--self-test", "--selftest"):
        sys.exit(selftest())
    paths = sys.argv[1:] or sorted(
        glob.glob("src/**/*.s", recursive=True))
    sys.exit(max(check(p) for p in paths))
