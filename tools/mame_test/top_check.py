#!/usr/bin/env python3
"""top_check -- top(1)'s numbers come from the kernel, not from zeros.

The screen is top's last frame, left behind when `q' ends it.  Three things
must be true of it, each of which is 0 when its kernel half is missing:
  - the header's load average is not 0.00 (vm.loadavg, _Vm_Loadav);
  - the CPU-bound `spinme' row has TIME of at least one second (the
    heartbeat's TCB_Utime/TCB_Stime, carried by procs(2));
  - that row's DTIME, the ticks since the previous sample, is not 0.00.
A screen with no top header at all is a failure of the run, not a pass.

Exit 0 = pass, 1 = fail.
"""
import json
import pathlib
import re
import sys


def screen(d):
    """The console's rows, decoded as run.py decodes them for screen_text,
    which is added after the dump is written and so is not in the file."""
    cb = (d.get("memory") or {}).get("charbuf")
    if not cb:
        return []
    raw = bytes(b & 0x7F for b in bytes.fromhex(cb["hex"]))
    text = raw.decode("ascii", "replace")
    return [text[i:i + 80].rstrip() for i in range(0, len(text), 80)]


def main(path="dump.json"):
    rows = screen(json.loads(pathlib.Path(path).read_text()))
    fails = []
    head = [r for r in rows if "load average:" in r]
    if not head:
        print("top_check: FAIL -- no top header on the screen; top never drew")
        return 1
    m = re.search(r"load average: ([\d.]+), ([\d.]+), ([\d.]+)", head[-1])
    if not m:
        fails.append("load average unreadable: %r" % head[-1])
    elif float(m.group(1)) <= 0.0:
        fails.append("1-minute load average is %s" % m.group(1))
    spin = [r for r in rows if r.rstrip().endswith(" spinme")]
    if not spin:
        fails.append("no spinme row in the process table")
    else:
        f = spin[-1].split()
        try:
            t, dt = float(f[-3]), float(f[-2])
        except (ValueError, IndexError):
            t = dt = None
            fails.append("spinme row unreadable: %r" % spin[-1])
        if t is not None:
            print("top_check: spinme TIME %.2f DTIME %.2f; load %s"
                  % (t, dt, m.group(0) if m else "?"))
            if t < 1.0:
                fails.append("spinme TIME %.2f s after 8 s of spinning" % t)
            if dt <= 0.0:
                fails.append("spinme DTIME is %.2f" % dt)
    for f in fails:
        print("top_check: FAIL -- " + f)
    if fails:
        return 1
    print("top_check: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
