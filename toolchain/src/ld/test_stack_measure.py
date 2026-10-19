#!/usr/bin/env python3
"""Self-check for stack_measure (P3-3 3.2).  Run: python3 test_stack_measure.py

Covers the sizing behaviours fgx_ld relies on:
  1. per-call overhead is counted per graph edge (F1),
  2. direct self-recursion is detected and floors the size to the cap + guard,
  3. a frame that overruns the page cap is flagged (clamped),
  4. indirect calls size by the ONE-HOP model — deepest direct path + one
     dispatch of the deepest non-entry subtree (maxfn) — NOT floor-to-cap
     (3.2c, task #43: the old floor put every fn-ptr tool at 32 pages and let
     three sized tools exhaust the 112-page stack arena)."""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stack_measure as sm


def _write(dirp, name, text):
    p = os.path.join(dirp, name)
    with open(p, "w") as f:
        f.write(text)
    return p


# A two-level chain: main() calls leaf().  Frames 10 and 20.  The deepest sum
# must include one edge's overhead (CALL_OVERHEAD + ARG_PAD_PER_CALL) on top of
# the raw 30 bytes of frames.
CHAIN = """\
main            ENT
                JSR     leaf
                RTL
main_FRAMESIZE   EQU     10
leaf            ENT
                RTL
leaf_FRAMESIZE   EQU     20
"""

# Direct self-recursion: the depth walk can't bound it, so it must be flagged.
REC = """\
r               ENT
                FGX2_FARCALL r
                RTL
r_FRAMESIZE      EQU     100
main            ENT
                JSR     r
                RTL
main_FRAMESIZE   EQU     0
"""

# A single frame larger than the page cap must clamp + flag.
# Sized from the CAP, not a magic number: a fixture that must CLAMP has to stay
# bigger than whatever the cap currently is.  Hardcoded 9000 B (36 pages) went
# stale the moment the cap rose 32 -> 56 and the clamp assertion tested nothing.
DEFAULT_MAX_PAGES_FOR_TEST = __import__("stack_measure").DEFAULT_MAX_PAGES
BIG = """\
main            ENT
                RTL
main_FRAMESIZE   EQU     {BIG_FRAME}
""".format(BIG_FRAME=(DEFAULT_MAX_PAGES_FOR_TEST * 256) + 512)

# Indirect dispatch (the fn-ptr RTL idiom) in main; `deep` (500 B subtree) is
# never called directly, so the one-hop model must add edge + depth(deep) on
# top of main's direct path (main -> helper).  maxfn is the deepest NON-entry
# subtree: deep(500) + edge + sub(40) = 500 + 21 + 40, not helper's 30.
INDIR = """\
main            ENT
                JSR     helper
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
main_FRAMESIZE   EQU     10
helper          ENT
                RTL
helper_FRAMESIZE EQU     30
deep            ENT
                JSR     sub
                RTL
deep_FRAMESIZE   EQU     500
sub             ENT
                RTL
sub_FRAMESIZE    EQU     40
"""


def main():
    with tempfile.TemporaryDirectory() as d:
        # Since 9648a8da2 the per-edge charge is CALL_OVERHEAD + the arg bytes
        # MEASURED at the call site; ARG_PAD_PER_CALL is only the fallback for a
        # site the reader cannot model.  These fixtures push no arguments, so
        # their edges cost CALL_OVERHEAD alone.  The old constant was still
        # inlined here, which is why the expectations below no longer matched.
        edge = sm.CALL_OVERHEAD
        # The SYNTHETIC one-hop allowances (indirect / signal) are charged at
        # stack_pages' `edge_overhead` parameter, which still defaults to the
        # flat CALL_OVERHEAD + ARG_PAD_PER_CALL -- there is no call site to
        # measure for an edge the graph cannot see.  Two different quantities
        # that were one before 9648a8da2; keep them apart here.
        hop = sm.CALL_OVERHEAD + sm.ARG_PAD_PER_CALL

        # 11 values since 9648a8da2 added argstats.  This unpack was left at 10
        # and the whole self-check died on a ValueError at the FIRST assertion,
        # so every case below it stopped running -- silently, because nothing
        # invokes this file on a schedule.  That is how the elvis under-sizing
        # regression below reached a shipped binary.
        worst, entry, _, _, cycles, indirect, maxfn, mutual, has_signal, _, _ = \
            sm.analyze([_write(d, "chain.s", CHAIN)])
        assert entry == "main", entry
        assert worst == 10 + edge + 20, worst        # F1: one edge's overhead
        assert not cycles and not indirect and not mutual
        assert not has_signal                        # no signal() in CHAIN
        assert maxfn == 20, maxfn                    # deepest non-entry: leaf

        pages, info = sm.stack_pages([_write(d, "rec.s", REC)])
        assert info["cycles"] == ["r"], info          # direct recursion caught
        assert info["mutual_cycles"] == [], info      # self-edge: guard-trapped
        # A cyclic binary is NO LONGER sized to the cap (changed 2026-07-26): it
        # gets its measured depth plus CYCLE_TURNS extra turns of the deepest
        # cycle member.  Cap-sizing coupled every cyclic binary to the global cap,
        # so raising the cap for tcsh inflated bsh 33 -> 57 pages and the two
        # stacks stopped fitting the 112-page bank-0 arena.  What must still hold:
        # floored is reported, an allowance IS reserved, and it stays under the cap.
        assert info["floored"], info
        assert info["cycle_extra"] > 0, info
        assert pages < sm.DEFAULT_MAX_PAGES, (pages, info)
        assert pages * 256 >= info["worst"], (pages, info)   # covers measured depth

        # Mutual recursion (a -> b -> a, no self-edge): flagged as mutual —
        # per-TU fcc gives its members STKGUARD=0, so fgx_ld must warn (the one
        # silent-overrun residue, 3.2c).  That warning matters MORE now that a
        # cyclic binary is sized by allowance rather than to the cap.
        MUT = ("a               ENT\n                JSR     b\n"
               "                RTL\na_FRAMESIZE      EQU     10\n"
               "b               ENT\n                JSR     a\n"
               "                RTL\nb_FRAMESIZE      EQU     20\n"
               "main            ENT\n                JSR     a\n"
               "                RTL\nmain_FRAMESIZE   EQU     0\n")
        pages, info = sm.stack_pages([_write(d, "mut.s", MUT)])
        assert info["floored"] and info["cycle_extra"] > 0, (pages, info)
        # No STKGUARD EQU in this fixture and neither frame reaches the >=128
        # gate, so the whole cycle is unguarded -> both members reported, as
        # the actual SCC rather than a DFS cut-point.
        assert info["mutual_cycles"] == ["a", "b"], info
        assert info["unguarded_cycles"] == [["a", "b"]], info

        # ...but a cycle with ONE guarded member traps on that member, so it is
        # NOT reported.  This is the tcsh case: 15 of its 16 cycles carry a
        # guarded function (e.g. dobackp, 1040 B frame -> fcc's >=128 gate), and
        # warning on all of them buried the single genuinely unguarded one.
        # The guard flag is READ from the .s, not re-derived from fcc's gate.
        GUARDED = ("a               ENT\n                JSR     b\n"
                   "                RTL\na_FRAMESIZE      EQU     10\n"
                   "a_STKGUARD       EQU     0\n"
                   "b               ENT\n                JSR     a\n"
                   "                RTL\nb_FRAMESIZE      EQU     20\n"
                   "b_STKGUARD       EQU     1\n"
                   "main            ENT\n                JSR     a\n"
                   "                RTL\nmain_FRAMESIZE   EQU     0\n"
                   "main_STKGUARD    EQU     0\n")
        pages, info = sm.stack_pages([_write(d, "guarded.s", GUARDED)])
        assert info["floored"], info                  # still a cycle
        assert info["mutual_cycles"] == [], info      # ...but it traps
        assert info["unguarded_cycles"] == [], info

        # THE elvis REGRESSION.  A cycle and an fn-ptr dispatch are INDEPENDENT
        # facts about a binary, and a binary can have both.  While a cyclic
        # binary was sized straight to max_pages, suppressing the one-hop
        # allowance on `floored` was free -- the cap dominated.  960dc6a92
        # replaced cap-sizing with the bounded cycle_extra and left the
        # suppression, so such a binary lost the cap AND the allowance.
        #
        # In elvis that zeroed a 4,786 B reserve and sized vi to 14 pages, while
        # add() -- reachable ONLY through the vikeys fn-ptr table, hence absent
        # from the direct graph -- needs a 4,128 B frame.  Every insert-mode
        # keystroke died on add()'s prologue guard with exit 134.
        #
        # `fat` below is that shape: big, reachable only by dispatch.  Without
        # the allowance total is 45 + 8*(5+20) + 128 = 373 (2 pages) and fat's
        # 3,000 B frame does not fit; with it, maxfn covers fat.
        CYCIND = """\
main            ENT
                JSR     a
                LDA     _fcc_fpr0
                DEC
                PHA
                RTL
main_FRAMESIZE   EQU     10
a               ENT
                JSR     b
                RTL
a_FRAMESIZE      EQU     10
b               ENT
                JSR     a
                RTL
b_FRAMESIZE      EQU     20
fat             ENT
                RTL
fat_FRAMESIZE    EQU     3000
"""
        pages, info = sm.stack_pages([_write(d, "cycind.s", CYCIND)], pad=128)
        assert info["floored"] and info["indirect"], info
        assert info["maxfn"] == 3000, info             # fat, reached only by ptr
        assert info["indirect_extra"] == hop + 3000, info
        assert info["cycle_extra"] > 0, info           # the cycle is ALSO charged
        # The whole point: the sized stack must hold the indirectly-reached
        # frame.  This is the assertion that goes red on the 960dc6a92 shape.
        assert pages * sm.STACK_PAGE >= 3000, (pages, info)

        pages, info = sm.stack_pages([_write(d, "big.s", BIG)])
        assert info["clamped"] and pages == sm.DEFAULT_MAX_PAGES, (pages, info)

        # A ~17-page frame (two 2KB arrays, the ss_bigbuf shape) now FITS the
        # raised 32-page cap and is not clamped (the P3-3 3.2 decision).
        BIGBUF = "main            ENT\n                RTL\n" \
                 "main_FRAMESIZE   EQU     4098\n"
        pages, info = sm.stack_pages([_write(d, "bigbuf.s", BIGBUF)])
        assert not info["clamped"] and pages == 17, (pages, info)

        # A small non-recursive program + realistic non-C headroom fits one
        # page, so it keeps the loader default (pages 0, no header churn).
        pages, info = sm.stack_pages([_write(d, "chain.s", CHAIN)], pad=128)
        assert pages == 0 and not info["clamped"], (pages, info)

        # 3.2c one-hop indirect model: NOT floored to cap; total = direct path
        # (main 10 + edge + helper 30) + one dispatch (edge + maxfn) + pad,
        # where maxfn = deep's subtree (500 + edge + 40).
        pages, info = sm.stack_pages([_write(d, "indir.s", INDIR)], pad=128)
        want_maxfn = 500 + edge + 40
        want_total = (10 + edge + 30) + (hop + want_maxfn) + 128
        assert info["indirect"] and not info["floored"], info
        assert info["maxfn"] == want_maxfn, info
        assert info["total"] == want_total, info
        want_pages = (want_total + sm.STACK_PAGE - 1) // sm.STACK_PAGE
        assert pages == want_pages != sm.DEFAULT_MAX_PAGES, (pages, info)

        # #45 Fix B: a program that registers a signal handler earns one extra
        # one-hop allowance (edge + maxfn) on top of worst — the handler
        # subtree stacks on the live frame but is invisible to depth(main).
        # SIG has main -> reg (which calls c_signal) and a big `handler`
        # subtree that no graph edge reaches; maxfn must bound it.
        SIG = """\
main            ENT
                JSR     reg
                RTL
main_FRAMESIZE   EQU     10
reg             ENT
                FGX2_FARCALL signal
                RTL
reg_FRAMESIZE    EQU     20
handler         ENT
                JSR     hsub
                RTL
handler_FRAMESIZE EQU    300
hsub            ENT
                RTL
hsub_FRAMESIZE   EQU     40
"""
        pages, info = sm.stack_pages([_write(d, "sig.s", SIG)], pad=128)
        assert info["has_signal"] and not info["floored"], info
        want_maxfn = 300 + edge + 40                  # handler subtree
        assert info["maxfn"] == want_maxfn, info
        assert info["signal_extra"] == hop + want_maxfn, info
        assert info["indirect_extra"] == 0, info      # no fn-ptr RTL idiom here
        want_total = (10 + edge + 20) + (hop + want_maxfn) + 128
        assert info["total"] == want_total, info

        # No signal() -> no allowance (guard against a false-positive RE).
        pages0, info0 = sm.stack_pages([_write(d, "chain.s", CHAIN)], pad=128)
        assert not info0["has_signal"] and info0["signal_extra"] == 0, info0

    print("stack_measure self-check: OK")


if __name__ == "__main__":
    main()
