#!/usr/bin/env python3
"""T2-0: ir_emitf shape census — the IR_TEXT lift's work-ordering instrument.

Extracts every ir_emitf format string from the fcc sources, normalizes it
to a shape (mnemonic + operand pattern), and reports families ordered by
site count, with the ALLOCATOR-VALUE classes flagged:

  CTRL   branches/labels/jumps — lifting these turns the between-IR_TEXT
         BB partition into a real CFG (the campaign's true prize)
  MEM    loads/stores/moves — register-pressure visibility
  STACK  push/pop/S-adjust — stack-delta bookkeeping the ops must carry
  MODE   SEP/REP/MX — width tracking (barrier-adjacent)
  MISC   everything else

Usage: python3 tools/irtext_census.py [src/cc]
"""
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

CTRL = {'BRA', 'BRL', 'BEQ', 'BNE', 'BCC', 'BCS', 'BMI', 'BPL', 'BVC',
        'BVS', 'JMP', 'JML', 'JSR', 'JSL', 'RTS', 'RTL', 'LABEL'}
MEM = {'LDA', 'STA', 'LDX', 'STX', 'LDY', 'STY', 'STZ', 'TAX', 'TAY',
       'TXA', 'TYA', 'TXY', 'TYX', 'XBA', 'MVN', 'MVP'}
STACK = {'PHA', 'PLA', 'PHX', 'PLX', 'PHY', 'PLY', 'PHB', 'PLB', 'PHD',
         'PLD', 'PHK', 'PHP', 'PLP', 'TSC', 'TCS', 'TSX', 'TXS', 'PEI',
         'PEA', 'PER'}
MODE = {'SEP', 'REP', 'MX'}


def classify(mnem):
    if mnem in CTRL:
        return 'CTRL'
    if mnem in MEM:
        return 'MEM'
    if mnem in STACK:
        return 'STACK'
    if mnem in MODE:
        return 'MODE'
    return 'MISC'


def shape_of(fmt):
    """Normalize an ir_emitf format string to (mnemonic, operand-shape)."""
    # Strip leading whitespace and trailing \n; take the first line only
    # (multi-line fmts are compound shapes — tagged as such).
    lines = [l for l in fmt.split('\\n') if l.strip()]
    multi = len(lines) > 1
    first = lines[0].strip() if lines else ''
    toks = first.split(None, 1)
    if not toks:
        return ('<empty>', '', False)
    mnem = toks[0]
    # a %s-leading token is a label definition line
    if mnem.startswith('%') or mnem.startswith('@') or mnem.endswith(':'):
        return ('LABEL', toks[1] if len(toks) > 1 else '', multi)
    operand = toks[1] if len(toks) > 1 else ''
    # normalize numbers/format-specs so shapes merge
    operand = re.sub(r'%[-0-9.*]*[dsuxX]', '%', operand)
    operand = re.sub(r'\$[0-9A-Fa-f]+', '$N', operand)
    operand = re.sub(r'#\d+', '#N', operand)
    return (mnem, operand, multi)


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else 'src/cc')
    rx = re.compile(r'ir_emitf\(\s*"((?:[^"\\]|\\.)*)"', re.S)
    fam = Counter()
    cls_sites = Counter()
    examples = defaultdict(str)
    per_file = Counter()
    total = 0
    for f in sorted(root.glob('*.c')):
        src = f.read_text()
        for m in rx.finditer(src):
            fmt = m.group(1)
            mnem, op, multi = shape_of(fmt)
            key = (classify(mnem), mnem, op, multi)
            fam[key] += 1
            cls_sites[key[0]] += 1
            per_file[f.name] += 1
            if key not in examples:
                examples[key] = fmt[:60]
            total += 1

    print(f"ir_emitf sites: {total}  "
          f"({', '.join(f'{k} {v}' for k, v in per_file.most_common())})")
    print(f"distinct shapes: {len(fam)}\n")
    print("by allocator-value class:")
    for c, n in cls_sites.most_common():
        print(f"  {c:5s}: {n:4d} sites ({100*n/total:4.1f}%)")
    print("\ntop 40 families (class, mnemonic, operand shape, multi?):")
    cum = 0
    for (c, mnem, op, multi), n in fam.most_common(40):
        cum += n
        mtag = '+' if multi else ' '
        print(f"  {n:4d} {100*cum/total:5.1f}%  {c:5s} {mnem:8s}{mtag} {op[:44]}")


if __name__ == '__main__':
    main()
