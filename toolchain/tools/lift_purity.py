#!/usr/bin/env python3
"""T2-3 lift-purity gate: replay paths must never RECORD.

The eats-its-own-lowering class (memory:
feedback_fcc_lift_converter_eats_lowering) fired twice in one day: a batch
site-converter rewrites raw ir_emitf lines INSIDE emit_lower_op's case arms
or a *_lower() helper — which run at REPLAY — into record-time helpers, so
an op lowers by recording (itself, in the worst case: infinite recursion,
fcc SIGSEGV rc=139).

This gate fails if emit_lower_op's body or any *_lower helper contains a
call to ir_record_op*/ir_record_raw/emit_m8/emit_m16/emit_br/emit_bcond/
emit_jsr_rt/emit_label (the record-time surface).  Run by tests/run.sh.

Exit 0 clean; 1 contaminated (lists offenders).
"""
import re
import sys
from pathlib import Path

RECORD_RX = re.compile(
    r'\b(ir_record_op\w*|ir_record_raw|emit_m8|emit_m16|emit_br|emit_bcond|'
    r'emit_jsr_rt|emit_label)\s*\(')


def region(s, m):
    start = m.end()
    depth, i = 1, start
    while depth and i < len(s):
        if s[i] == '{':
            depth += 1
        elif s[i] == '}':
            depth -= 1
        i += 1
    return start, i


def strip_comments(s):
    """Blank out /*...*/ and //-to-EOL, preserving offsets/line numbers."""
    out = []
    i, n = 0, len(s)
    while i < n:
        if s.startswith('/*', i):
            j = s.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(''.join(c if c == '\n' else ' ' for c in s[i:j]))
            i = j
        elif s.startswith('//', i):
            j = s.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        else:
            out.append(s[i])
            i += 1
    return ''.join(out)


def main():
    src = Path(sys.argv[1] if len(sys.argv) > 1 else 'src/cc/emit.c')
    s = strip_comments(src.read_text())
    bad = []
    m = re.search(r'emit_lower_op\(const IrNode \*n\)\s*\{', s)
    if m:
        a, b = region(s, m)
        for hit in RECORD_RX.finditer(s, a, b):
            line = s.count('\n', 0, hit.start()) + 1
            bad.append(('emit_lower_op', line, hit.group(1)))
    for m in re.finditer(r'\n(\w+_lower)\s*\([^)]*\)\s*\{', s):
        a, b = region(s, m)
        for hit in RECORD_RX.finditer(s, a, b):
            line = s.count('\n', 0, hit.start()) + 1
            bad.append((m.group(1), line, hit.group(1)))
    if bad:
        print("lift_purity: REPLAY-PATH CONTAMINATION — an op lowers by "
              "recording (the eats-its-own-lowering class):")
        for fn, line, callee in bad:
            print(f"  {src}:{line}: {fn}() calls {callee}()")
        return 1
    print(f"lift_purity: clean ({src})")
    return 0


if __name__ == '__main__':
    sys.exit(main())
