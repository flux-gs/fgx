#!/usr/bin/env python3
"""check_shtmp0_across_fs -- an errno parked in _shTmp0 must not cross an Fs_ call.

THE DEFECT THIS EXISTS TO STOP, WHICH HAS HAPPENED TWICE.

    STA     _shTmp0         ; preserve errno
    LDA     _mlFd
    JSR     Fs_Close
    LDA     _shTmp0         ; <- Fs_Close's errno, not the caller's

`Fs_Close`, `Fs_Read`, `Fs_Write`, `Fs_Closedir` and `Fs_Readdir` all reach
`_Fcb_LookupPtr`, whose fd*3 byte-offset scratch cell IS `_shTmp0`.  fcb.s:628
names the hazard and names the callers.  So the reload hands back the Fs_
routine's own errno, and because that is almost always EBADF, every failure
through such a tail reports EBADF whatever went wrong.

    apple/fgx#14   the FGX2 loader tails.  A wrong errno sent the whole
                   investigation after fd handling; the real error was EINVAL
                   from the override-bank check.
    apple/fgx#289  three more tails, missed by that fix: loader.s's
                   `@lb_eioClose', and modload.s's Bank_Alloc and
                   `@ml_eioClose' tails.

A wrong errno is worse than no errno -- it is a signpost pointing away from the
fault -- and the same shape came back once already, which is the argument for
checking it mechanically rather than by review.

THE FIX IS ALWAYS THE SAME: put the errno on the STACK across the call.

    PHA
    LDA     _mlFd
    JSR     Fs_Close
    PLA

WHAT IS FLAGGED.  A `STA _shTmp0` followed, before any reload of `_shTmp0`, by
a JSR/JSL to one of the clobbering routines, and then a `LDA _shTmp0`.  All
three parts must be present: a store with no later load is not a save, and a
load with no intervening call is fine.  Scanning stops at an `RTS`/`RTL`/`RTI`,
so a store in one routine cannot pair with a load in the next.

WHAT IS NOT FLAGGED, deliberately.  `_shTmp0` is general DP scratch and most
uses are nothing to do with errnos -- task.s counts retries in it, signal.s
holds a mask, main.s builds long pointers.  Only the save-across-call-reload
shape is a defect, so only that shape is reported.

Usage:
    check_shtmp0_across_fs.py [--self-test]
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SCAN = [os.path.join(ROOT, "src", "kernel")]

# Everything that reaches _Fcb_LookupPtr (fcb.s:628).
CLOBBERS = ("Fs_Close", "Fs_Read", "Fs_Write", "Fs_Closedir", "Fs_Readdir",
            "Fs_ReadN", "_FarSh_Fs_Close", "_FarSh_Fs_Read")

# A LABEL MAY PRECEDE THE MNEMONIC, and the first cut of this file did not
# allow for it -- so it matched nothing on a labelled line and reported the
# whole kernel clean while being unable to see a defect at all.  The self-test
# is what caught that, which is the entire reason it exists: a checker that
# cannot fail is not a check.
_LBL  = r"^(?:[A-Za-z_@][A-Za-z0-9_]*)?\s+"
STORE = re.compile(_LBL + r"STA\s+\|?_shTmp0\s*(?:;.*)?$", re.I)
LOAD  = re.compile(_LBL + r"LDA\s+\|?_shTmp0\s*(?:;.*)?$", re.I)
CALL  = re.compile(_LBL + r"(?:JSR|JSL)\s+\|?([A-Za-z_@][A-Za-z0-9_]*)", re.I)
RET   = re.compile(_LBL + r"RT[SLI]\s*(?:;.*)?$", re.I)


def strip(line):
    """Drop a trailing comment, and treat a whole-line comment as blank."""
    s = line.split(";", 1)[0]
    return s if s.strip() else ""


def scan_text(path, text):
    """Report (line, routine) for every save-across-call-reload of _shTmp0."""
    bad = []
    lines = text.split("\n")
    for i, raw in enumerate(lines):
        if not STORE.match(strip(raw)):
            continue
        crossed = None
        for j in range(i + 1, len(lines)):
            s = strip(lines[j])
            if not s:
                continue
            if RET.match(s):
                break                    # routine ended; no pairing
            m = CALL.match(s)
            if m and m.group(1) in CLOBBERS:
                crossed = (j + 1, m.group(1))
                continue
            if LOAD.match(s):
                if crossed:
                    bad.append((i + 1, crossed[0], crossed[1], j + 1))
                break                    # first reload settles it either way
            if STORE.match(s):
                break                    # re-saved; a new interval starts
    return bad


SELF_BAD = """
_Tail           STA     _shTmp0         ; preserve errno
                LDA     _mlFd
                JSR     Fs_Close
                LDA     _shTmp0
                RTS
"""

SELF_OK = """
_TailFixed      PHA
                LDA     _mlFd
                JSR     Fs_Close
                PLA
                RTS
_Other          STA     _shTmp0         ; a counter, not an errno
                DEC     _shTmp0
                LDA     _shTmp0
                RTS
_Split          STA     _shTmp0
                RTS
_Next           LDA     _shTmp0
                RTS
"""


def self_test():
    bad = scan_text("<self>", SELF_BAD)
    if len(bad) != 1:
        print("self-test FAILED: the known-bad shape was not caught (%r)" % (bad,))
        return 1
    ok = scan_text("<self>", SELF_OK)
    if ok:
        print("self-test FAILED: a clean shape was flagged (%r)" % (ok,))
        return 1
    print("check_shtmp0_across_fs: self-test OK")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()
    findings, nfiles = [], 0
    for root in SCAN:
        for dirpath, _dirs, files in os.walk(root):
            for fn in sorted(files):
                if not fn.endswith(".s"):
                    continue
                p = os.path.join(dirpath, fn)
                nfiles += 1
                with open(p, encoding="utf-8", errors="replace") as fh:
                    for hit in scan_text(p, fh.read()):
                        findings.append((os.path.relpath(p, ROOT),) + hit)
    if findings:
        print("check_shtmp0_across_fs: an errno in _shTmp0 crosses an Fs_ call "
              "-- it comes back as that call's errno (usually EBADF).  Hold it "
              "on the stack instead:\n")
        for rel, sline, cline, callee, lline in findings:
            print("  %s:%d  STA _shTmp0 -> %s at :%d -> LDA _shTmp0 at :%d"
                  % (rel, sline, callee, cline, lline))
        print("\n  PHA / <call> / PLA.  See fcb.s:628, apple/fgx#14, apple/fgx#289.")
        return 1
    print("check_shtmp0_across_fs: clean (%d kernel .s files, %d clobbering "
          "routines watched)" % (nfiles, len(CLOBBERS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
