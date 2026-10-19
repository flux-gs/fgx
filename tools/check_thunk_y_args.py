#!/usr/bin/env python3
"""check_thunk_y_args.py - a dispatch wrapper must RE-STAGE Y if its body takes
an argument there.

WHY THIS EXISTS.  _NetThunkExec takes its op number in Y.  So every kernel stub
that reaches a module op does `LDY #NETOP_x` and DESTROYS whatever the caller
had in Y -- and a caller that passed an argument there looks entirely unrelated,
because it is in a different file and was written before the op existed.

This has now been the bug TWICE, in the same migration:

  apple/fgx#93-era: _Loop_CloseTry took the socket index in Y from fs.s.  Found,
  fixed by staging through _loopThunkSock, and the comment block written at the
  time said "_Loop_CloseTry is the one such site".

  apple/fgx#96: _Loop_StatusTry took the DESCRIPTOR RECORD OFFSET in Y from
  _Sel_Classify.  The census above had audited the six ops being MOVED; this
  one's caller was select(), which was not one of them.  It indexed a 48-byte
  table with the op number 72 and answered select() from adjacent heap -- which
  presented as KERNEL-SIZE SENSITIVITY, because what that heap byte holds moves
  with the layout.

The guard both times was a prose comment, and both times the comment was a
census that could not know what it had missed.  This is the mechanical version.

WHAT IT CHECKS, and why the rule is this shape.  For each `net_op_*` wrapper:
find the routine it JSRs, and decide whether that routine READS Y before it
WRITES Y.  A routine that reads Y first is taking an input there -- that is what
an input register IS -- and the wrapper must therefore set Y before calling it,
because the thunk that got here already clobbered it.

It deliberately does NOT read the routine's `In: Y = ...` header comment.  The
comments are good in this tree, but a comment is what failed twice already; the
instruction stream cannot be out of date with itself.

KNOWN LIMIT, stated rather than hidden: the body scan is LINEAR, so a routine
whose first Y access is on a branch not taken from the top could be misjudged.
It is conservative in the safe direction -- a read seen anywhere before a write
FLAGS -- so the failure mode is a false alarm that a `LDY` or a waiver settles,
not a miss.  Waive with `THUNK-Y-OK: <why>` on the wrapper.

Usage:  check_thunk_y_args.py [<module>.s ...]     (default: the net module)
        check_thunk_y_args.py --self-test
"""
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SOURCES = [
    'src/modules/net/net.s',
    'src/modules/net/net_loop.s',
    'src/modules/net/net_xport.s',
    'src/modules/net/unp.s',
    'src/modules/net/pipe.s',
]

# The dispatch wrappers.  One family today; the constant is named so a second
# dispatcher does not have to rediscover why this file exists.
WRAPPER_RE = re.compile(r'^(net_op_\w+)\s')
WAIVER = 'THUNK-Y-OK'

LABEL_RE = re.compile(r'^([A-Za-z_@][A-Za-z0-9_]*)\s+(\S+)')
INSTR_RE = re.compile(r'^(?:[A-Za-z_@][A-Za-z0-9_]*)?\s+([A-Za-z]{3}:?)\s*(.*)$')

# Y is WRITTEN whole by these; after one, the wrapper's Y no longer matters.
Y_WRITE = {'LDY', 'TAY', 'PLY', 'TXY'}
# Y is READ by these.  INY/DEY/CPY read it too -- a routine that increments an
# index it was handed is taking it as an input just as much as one that stores
# it.
Y_READ = {'STY', 'TYA', 'TYX', 'INY', 'DEY', 'CPY', 'PHY'}
# ...and by any operand indexed with ,Y.
Y_INDEX_RE = re.compile(r',\s*Y\s*$', re.I)

TERMINATORS = {'RTS', 'RTL', 'RTI'}
# An unconditional transfer ends the LINEAR body -- and is usually not the end
# of the ROUTINE.  A three-line entry that sets A and BRLs to a shared body
# passes Y
# straight through, so the argument question is answered by the TARGET.  A
# first cut stopped only at RTS/RTL and ran off the end of these stubs into the
# next routine, reporting four different entries at one line in a fifth --
# which is what a false positive looks like from the inside.
UNCONDITIONAL = {'BRA', 'BRL', 'JMP', 'JML'}


def read(path):
    with open(os.path.join(REPO, path), errors='ignore') as f:
        return f.read().splitlines()


def strip_comment(line):
    """Merlin: a ';' starts a comment; a '*' in column 0 is a whole-line one."""
    if line[:1] == '*':
        return '', line
    i = line.find(';')
    return (line, '') if i < 0 else (line[:i], line[i:])


def index_labels(files):
    """label -> (path, line index).  First definition wins, as Merlin does."""
    out = {}
    for path, lines in files.items():
        for n, raw in enumerate(lines):
            code, _ = strip_comment(raw)
            m = LABEL_RE.match(code)
            if m and m.group(1) not in out:
                out[m.group(1)] = (path, n)
    return out


def _local_label(lines, routine_start, name, budget=400):
    """Merlin locals (@foo) belong to the preceding GLOBAL label, so resolve one
    by searching forward from the routine that owns it rather than globally --
    the same @name is reused all over the file."""
    for n in range(routine_start, min(routine_start + budget, len(lines))):
        code, _ = strip_comment(lines[n])
        m = LABEL_RE.match(code)
        if m and m.group(1) == name:
            return n
    return None


def body_takes_y(files, labels, target, budget=400, depth=4):
    """Does `target` READ Y before writing it?  -> (True/False, evidence).

    Follows unconditional tail transfers, so a thin entry is judged by the body
    it hands off to.  Bounded depth, because a jump cycle is a real shape in
    hand-written asm and this is a lint, not an interpreter."""
    if depth <= 0 or target not in labels:
        return False, None                 # not ours (a kernel export, say)
    path, start = labels[target]
    lines = files[path]
    for n in range(start, min(start + budget, len(lines))):
        code, _ = strip_comment(lines[n])
        m = INSTR_RE.match(code)
        if not m:
            continue
        op, operand = m.group(1).rstrip(':').upper(), m.group(2)
        if op in Y_WRITE:
            return False, None             # sets its own Y before using one
        if op in Y_READ or Y_INDEX_RE.search(operand):
            return True, f'{path}:{n + 1}: {code.strip()}'
        if op in UNCONDITIONAL:
            dest = operand.split()[0].split(',')[0] if operand else ''
            if dest.startswith('@'):
                at = _local_label(lines, start, dest)
                if at is None:
                    return False, None
                return body_takes_y_from(files, path, at, labels, budget, depth - 1)
            if dest in labels:
                return body_takes_y(files, labels, dest, budget, depth - 1)
            return False, None             # unresolvable: do not guess
        if op in TERMINATORS and n > start:
            return False, None
    return False, None


def body_takes_y_from(files, path, start, labels, budget, depth):
    """body_takes_y, but entered at a line rather than at a label."""
    lines = files[path]
    for n in range(start, min(start + budget, len(lines))):
        code, _ = strip_comment(lines[n])
        m = INSTR_RE.match(code)
        if not m:
            continue
        op, operand = m.group(1).rstrip(':').upper(), m.group(2)
        if op in Y_WRITE:
            return False, None
        if op in Y_READ or Y_INDEX_RE.search(operand):
            return True, f'{path}:{n + 1}: {code.strip()}'
        if op in UNCONDITIONAL or (op in TERMINATORS and n > start):
            return False, None
    return False, None


def check(sources):
    files = {p: read(p) for p in sources}
    labels = index_labels(files)
    findings = []
    checked = 0

    for path, lines in files.items():
        n = 0
        while n < len(lines):
            code, _ = strip_comment(lines[n])
            m = WRAPPER_RE.match(code)
            if not m:
                n += 1
                continue
            wrapper = m.group(1)
            # The wrapper runs to its first terminator.
            staged = False
            call = None
            waived = False
            for k in range(n, min(n + 60, len(lines))):
                code_k, comment_k = strip_comment(lines[k])
                if WAIVER in comment_k or WAIVER in lines[k]:
                    waived = True
                mi = INSTR_RE.match(code_k)
                if not mi:
                    continue
                op, operand = mi.group(1).rstrip(':').upper(), mi.group(2).strip()
                if op == 'LDY':
                    staged = True
                elif op in ('JSR', 'JML', 'JMP') and call is None:
                    call = operand.split()[0] if operand else None
                elif op in TERMINATORS and k > n:
                    break
            checked += 1
            if call and not staged and not waived:
                takes, where = body_takes_y(files, labels, call)
                if takes:
                    findings.append((path, n + 1, wrapper, call, where))
            n += 1
    return checked, findings


def main(argv):
    sources = argv or DEFAULT_SOURCES
    checked, findings = check(sources)
    if findings:
        print('error: a dispatch wrapper calls a routine that takes an argument '
              'in Y, without re-staging it.\n'
              '       The thunk that reached this wrapper put the OP NUMBER in '
              'Y (_NetThunkExec),\n'
              '       so whatever the caller passed there is already gone '
              '(apple/fgx#96).\n', file=sys.stderr)
        for path, line, wrapper, call, where in findings:
            print(f'  {path}:{line}: {wrapper} -> {call}', file=sys.stderr)
            print(f'      {call} reads Y before setting it, at {where}',
                  file=sys.stderr)
        print('\n  Fix: stage the value in a named kernel static and reload it '
              'here, as\n'
              '  net_op_loopclose does with _loopThunkSock.  If the body '
              'genuinely does\n'
              f'  not take Y, waive on the wrapper with `; {WAIVER}: <why>`.',
              file=sys.stderr)
        return 1
    print(f'check_thunk_y_args: OK ({checked} dispatch wrappers, '
          f'{len(sources)} sources)')
    return 0


# ---------------------------------------------------------------------------
SELFTEST_BAD = """\
net_op_thing    MX      %00
                JSR     _Thing_Try
                RTL
_Thing_Try      MX      %00
                STY     _thingOff
                RTS
"""

SELFTEST_GOOD = """\
net_op_thing    MX      %00
                LDY     _thingStaged
                JSR     _Thing_Try
                RTL
_Thing_Try      MX      %00
                STY     _thingOff
                RTS
"""

SELFTEST_NOY = """\
net_op_thing    MX      %00
                JSR     _Thing_Try
                RTL
_Thing_Try      MX      %00
                LDY     #0
                STY     _thingOff
                RTS
"""

SELFTEST_WAIVED = """\
net_op_thing    MX      %00
                JSR     _Thing_Try              ; THUNK-Y-OK: body re-reads it
                RTL
_Thing_Try      MX      %00
                STY     _thingOff
                RTS
"""

SELFTEST_INDEXED = """\
net_op_thing    MX      %00
                JSR     _Thing_Try
                RTL
_Thing_Try      MX      %00
                LDA     [_sockTablePtr],Y
                RTS
"""


def selftest():
    """Each case is a shape this has to tell apart, and the BAD one is the
    real apple/fgx#96 reduced to five lines."""
    import tempfile
    rc = 0
    cases = [
        ('unstaged call to a Y-taking body', SELFTEST_BAD, 1),
        ('staged with LDY first', SELFTEST_GOOD, 0),
        ('body sets its own Y', SELFTEST_NOY, 0),
        ('explicitly waived', SELFTEST_WAIVED, 0),
        ('body indexes with ,Y', SELFTEST_INDEXED, 1),
    ]
    for name, text, want in cases:
        with tempfile.NamedTemporaryFile('w', suffix='.s', delete=False,
                                         dir=REPO) as f:
            f.write(text)
            rel = os.path.relpath(f.name, REPO)
        _checked, findings = check([rel])
        os.unlink(f.name)
        got = len(findings)
        if got != want:
            print(f'SELFTEST FAIL: {name}: expected {want} finding(s), got {got}',
                  file=sys.stderr)
            rc = 1
    if rc == 0:
        print(f'check_thunk_y_args selftest: OK ({len(cases)} cases)')
    return rc


if __name__ == '__main__':
    if sys.argv[1:2] == ['--self-test']:
        sys.exit(selftest())
    sys.exit(main(sys.argv[1:]))
