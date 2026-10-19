#!/usr/bin/env python3
"""check_wchans -- the fixed wait channels are DISTINCT.  apple/fgx#238.

`_sleep'/`_wakeup' identify a channel by its 16-bit value, so two constants
that share one are one channel wearing two names: every wake of either
releases the sleepers of both.  WCHAN_LBOLT and WCHAN_PTY were both $FF07 for
about five weeks and nothing said so, because every sleeper on both channels
re-tests its condition and loops -- the collision cost spurious wakeups and
cost nothing else, right up until a test needed to tell one wake from another.

The whole check is that nine EQUs in one file are distinct.  It is here rather
than as a Merlin `ERR' because pairwise distinctness of nine constants is a
loop, and a loop is what a script is for.

Exit 0 = clean, 1 = a collision.
"""
import pathlib
import re
import sys

HEADER = pathlib.Path("include/kernel.s")
PAT = re.compile(r"^(WCHAN_[A-Z0-9_]+)\s+EQU\s+(\$[0-9A-Fa-f]+|\d+)", re.M)


def main():
    if not HEADER.exists():
        print("check_wchans: FAIL -- %s not found (run from the repo root)"
              % HEADER)
        return 1
    text = HEADER.read_text()
    seen = {}
    dupes = []
    for name, raw in PAT.findall(text):
        val = int(raw[1:], 16) if raw.startswith("$") else int(raw)
        if val in seen:
            dupes.append((seen[val], name, val))
        else:
            seen[val] = name
    if not seen:
        print("check_wchans: FAIL -- no WCHAN_* constants matched; the "
              "pattern has gone stale and this check is vacuous")
        return 1
    if dupes:
        for a, b, v in dupes:
            print("check_wchans: FAIL -- %s and %s are both $%04X.  One "
                  "channel with two names: a wake of either releases the "
                  "sleepers of both (apple/fgx#238)." % (a, b, v))
        return 1
    print("check_wchans: clean (%d fixed wait channels, all distinct)"
          % len(seen))
    return 0


if __name__ == "__main__":
    sys.exit(main())
