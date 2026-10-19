#!/usr/bin/env python3
"""check_chardev_ops.py -- every CharDev_Ops vtable is COPS_SIZE long.

Nothing checked this before, and the vector had been eight slots for long
enough that it read as fixed.  Adding `COPS_Stop' (apple/fgx#108 T3) is what
made the gap matter: a vtable that still emits eight entries is SHORT, and
_Chardev_Dispatch reaches the ninth by arithmetic -- it reads whatever the
assembler laid down next and JSLs it.

THAT IS apple/fgx#210's SHAPE EXACTLY.  There, KFAR_SLOT_COUNT was 32 with 39
slots assigned, `LUP -7' emitted nothing, and slot 39 entered _KZeroRegion --
a call to an address nobody wrote, with no diagnostic.  #210's fix was to make
both banks ERR on table size; this is the same fix for the other table.

WHY A SOURCE SCAN RATHER THAN A MERLIN `ERR'.  An ERR can only guard a table
in a file that knows COPS_SIZE, and the module vtables do not include
chardev.s -- serial.s carries its own hand-copied COPS_* block, which is itself
a thing that can drift.  A scan over the source sees every table on the same
terms and can also check that restated offset block against the real one.

  python3 tools/check_chardev_ops.py
  python3 tools/check_chardev_ops.py --self-test
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHARDEV_H = os.path.join(ROOT, "include", "chardev.s")

# Files that define at least one CharDev_Ops vtable.  Listed rather than
# discovered: a driver whose table this cannot find must fail loudly here, not
# be silently absent from the check.
VTABLE_FILES = [
    "src/kernel/chardev.s",
    "src/kernel/ttyv.s",
    "src/kernel/tty_tty.s",
    "src/modules/pty/pty.s",
    "src/modules/serial/serial.s",
    "src/modules/bpf/bpf.s",
]

# A vtable label: `name ENT' or a bare `name' at column 0, whose next
# non-blank lines are DFB rows.  The name has to say what it is.
LABEL = re.compile(r"^([A-Za-z_]\w*(?:Ops|ops)\w*)\s*(?:ENT)?\s*$")
DFB = re.compile(r"^\s+DFB\s")


def slot_count(path):
    """{vtable name: number of 3-byte DFB rows}."""
    out = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    for i, line in enumerate(lines):
        m = LABEL.match(line.split(";")[0].rstrip())
        if not m:
            # `name ENT` with the DFB on a later line, and `name DFB ...` too
            m2 = re.match(r"^([A-Za-z_]\w*(?:Ops|ops)\w*)\s+(?:ENT|DFB)\b", line)
            if not m2:
                continue
            m = m2
        n, j = 0, i
        if DFB.match(lines[i]) or re.match(r"^\S+\s+DFB\s", lines[i]):
            n, j = 1, i
        j += 1
        while j < len(lines):
            s = lines[j]
            if DFB.match(s):
                n += 1
                j += 1
                continue
            if s.strip() == "" or s.lstrip().startswith(";"):
                # a blank or comment INSIDE the table is allowed only while
                # more DFBs follow; stop at the first that ends it
                k = j
                while k < len(lines) and (lines[k].strip() == ""
                                          or lines[k].lstrip().startswith(";")):
                    k += 1
                if k < len(lines) and DFB.match(lines[k]):
                    j = k
                    continue
            break
        if n:
            out[m.group(1)] = n
    return out


def declared_slots():
    """COPS_SIZE / 3, from include/chardev.s -- the DUM block is the source."""
    text = open(CHARDEV_H, encoding="utf-8").read()
    names = re.findall(r"^(COPS_\w+)\s+DS\s+3", text, re.M)
    if not names:
        raise SystemExit("check_chardev_ops: no COPS_* DS 3 slots in chardev.s")
    return len(names), names


def restated_offsets(path, names):
    """A module's hand-copied `COPS_x EQU n' block must match the real order."""
    bad = []
    text = open(os.path.join(ROOT, path), encoding="utf-8", errors="replace").read()
    for i, nm in enumerate(names):
        m = re.search(r"^%s\s+EQU\s+(\d+)" % re.escape(nm), text, re.M)
        if m and int(m.group(1)) != i * 3:
            bad.append("%s: %s is EQU %s, should be %d"
                       % (path, nm, m.group(1), i * 3))
    return bad


# The POLL* bits are chardev's ABI too, and kernel C cannot include an assembly
# header -- so spec_vnops.c restates them.  A drift is SILENT: a wrong bit makes
# spec_select answer confidently about the wrong direction, and nothing fails to
# build.  check_ntty.py exists for the same shape of copy.
POLL_C = "src/kernel/vfs/spec_vnops.c"
POLL_BITS = ("POLLIN", "POLLOUT")


def poll_bits():
    """POLLIN/POLLOUT as include/chardev.s states them -- the source."""
    text = open(CHARDEV_H, encoding="utf-8").read()
    out = {}
    for nm in POLL_BITS:
        m = re.search(r"^%s\s+EQU\s+\$?([0-9A-Fa-f]+)" % nm, text, re.M)
        if not m:
            raise SystemExit("check_chardev_ops: chardev.s states no %s" % nm)
        out[nm] = int(m.group(1), 16)
    return out


def restated_poll_bits(want):
    """spec_vnops.c's `#define POLLIN/POLLOUT' must agree with chardev.s."""
    bad = []
    path = os.path.join(ROOT, POLL_C)
    if not os.path.exists(path):
        return ["%s is missing -- the poll-bit check has nothing to hold" % POLL_C]
    text = open(path, encoding="utf-8", errors="replace").read()
    for nm, val in sorted(want.items()):
        m = re.search(r"^#define\s+%s\s+(\S+)" % nm, text, re.M)
        if not m:
            bad.append("%s: no `#define %s' -- chardev.s states it as $%04X, "
                       "and an absent copy is not agreement" % (POLL_C, nm, val))
            continue
        got = int(m.group(1), 0)
        if got != val:
            bad.append("%s: %s is %s, chardev.s states $%04X"
                       % (POLL_C, nm, m.group(1), val))
    return bad


def main():
    n_slots, names = declared_slots()
    errors, checked = [], 0
    for rel in VTABLE_FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            errors.append("listed vtable file is missing: %s" % rel)
            continue
        tables = slot_count(path)
        if not tables:
            errors.append("%s: no CharDev_Ops vtable found -- the scan has "
                          "drifted from the source, not the source from the "
                          "vector" % rel)
        for name, n in sorted(tables.items()):
            checked += 1
            if n != n_slots:
                errors.append(
                    "%s: %s has %d slot(s), COPS_SIZE is %d -- a short table is "
                    "dispatched past (apple/fgx#210)" % (rel, name, n, n_slots))
        errors += restated_offsets(rel, names)
    want = poll_bits()
    errors += restated_poll_bits(want)

    if errors:
        sys.stderr.write("CHARDEV OPS CHECK FAILED:\n")
        for e in errors:
            sys.stderr.write("  - %s\n" % e)
        sys.stderr.write("Fix: every CharDev_Ops vtable emits one DFB row per "
                         "COPS_* slot; use `DFB 0,0,0' for an op the device "
                         "does not have (the dispatcher tests for it).\n")
        return 1
    print("chardev ops OK: %d vtable(s), %d slots each (%s); poll bits %s "
          "agree with %s"
          % (checked, n_slots, ", ".join(n[5:] for n in names),
             "/".join("%s=$%04X" % (k, want[k]) for k in POLL_BITS), POLL_C))
    return 0


def _selftest():
    """Prove it goes red on a short table and on a drifted restated offset."""
    import shutil
    import tempfile
    fails = 0
    tmp = tempfile.mkdtemp(prefix="cdops-")
    try:
        full = ("demo_ops        DFB     <a,>a,^a\n"
                "                DFB     <b,>b,^b\n")
        short = "demo_ops        DFB     <a,>a,^a\n"
        p = os.path.join(tmp, "t.s")
        open(p, "w").write(full)
        if slot_count(p).get("demo_ops") != 2:
            print("  SELFTEST FAIL: a 2-row table counted %r"
                  % slot_count(p).get("demo_ops"))
            fails += 1
        open(p, "w").write(short)
        if slot_count(p).get("demo_ops") != 1:
            print("  SELFTEST FAIL: a 1-row table counted %r"
                  % slot_count(p).get("demo_ops"))
            fails += 1
        # a comment inside the table must not end it
        open(p, "w").write("demo_ops        DFB     <a,>a,^a\n"
                           "                ; a note\n"
                           "                DFB     <b,>b,^b\n")
        if slot_count(p).get("demo_ops") != 2:
            print("  SELFTEST FAIL: a comment inside the table ended it")
            fails += 1
        # and a blank line AFTER the table must end it
        open(p, "w").write(full + "\nsomething_else  NOP\n")
        if slot_count(p).get("demo_ops") != 2:
            print("  SELFTEST FAIL: the table did not end at the blank line")
            fails += 1
        # the real vector must have at least the eight historical slots
        n, names = declared_slots()
        if n < 8 or "COPS_Open" not in names:
            print("  SELFTEST FAIL: read %d slots from chardev.s (%s)" % (n, names))
            fails += 1

        # --- the poll-bit check must go RED on a drift, and on an absence ---
        # A check that only ever runs against agreeing copies has never been
        # shown to discriminate; these are the two ways the copies come apart.
        global POLL_C
        real_poll_c = POLL_C
        try:
            c = os.path.join(tmp, "spec.c")
            POLL_C = os.path.relpath(c, ROOT)
            want = {"POLLIN": 0x0001, "POLLOUT": 0x0004}

            open(c, "w").write("#define POLLIN 0x0001\n#define POLLOUT 0x0004\n")
            if restated_poll_bits(want):
                print("  SELFTEST FAIL: agreeing poll bits reported as drifted")
                fails += 1

            open(c, "w").write("#define POLLIN 0x0001\n#define POLLOUT 0x0002\n")
            if not restated_poll_bits(want):
                print("  SELFTEST FAIL: POLLOUT drifted to 0x0002 and passed")
                fails += 1

            open(c, "w").write("#define POLLIN 0x0001\n")
            if not restated_poll_bits(want):
                print("  SELFTEST FAIL: a MISSING POLLOUT passed -- an absent "
                      "copy is not agreement")
                fails += 1
        finally:
            POLL_C = real_poll_c

        # and the source side must really be where it is read from
        if poll_bits() != {"POLLIN": 0x0001, "POLLOUT": 0x0004}:
            print("  SELFTEST FAIL: chardev.s poll bits read as %r" % (poll_bits(),))
            fails += 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if fails:
        print("check_chardev_ops self-test: %d FAILURE(S)" % fails)
        return 1
    print("check_chardev_ops self-test: OK (short/full/comment/end cases, "
          "chardev.s parses, and the poll bits go red on a drift and on an "
          "absent copy)")
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(_selftest())
    sys.exit(main())
