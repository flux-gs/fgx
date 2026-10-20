#!/usr/bin/env python3
"""Build-time gate: no NEW baked kernel-data address literals.

Flags a literal $02E000-$02FDFF (the KGlobals data region) used as an address in
kernel/module source -- the "bake a kernel address that then drifts with kernel
layout" anti-pattern behind the address-collision heisenbugs (see
docs/superpowers/specs/2026-06-04-fgx-kernel-memory-modernization-design.md).
Kernel state must be reached by a memmap.s label (modules: via the
gen_kernel_exports.py manifest + a kernel_exports.s PUT), never a hard literal.

Allowed: the memory-map source-of-truth files (memmap.s, dpmap.s, kernel.s);
$02FE00-$02FFFF (MOD_JT + the loader handoff -- the deliberate fixed ABI);
comments; and the generated (gitignored) kernel_exports.s includes.

Run by build.sh.  Exit 1 (with the offending lines) on any hit.
"""
import re
import subprocess
import sys

SOT = {'include/memmap.s', 'include/dpmap.s', 'include/kernel.s'}
# $02E000..$02EFFF  or  $02F000..$02FDFF  (excludes $02FE/$02FF = MOD_JT/handoff)
LIT = re.compile(r'\$02[Ee][0-9A-Fa-f]{3}|\$02[Ff][0-9A-Da-d][0-9A-Fa-f]{2}')


def code_part(line):
    """Drop Merlin32 comments (';' to EOL; a leading '*' is a full-line comment)."""
    if line.lstrip().startswith('*'):
        return ''
    return line.split(';', 1)[0]


def _selftest():
    """Prove the detector can FAIL before its silence is trusted.

    This gate passes by finding nothing, so a broken regex, a bad comment
    stripper, or an empty file list all look exactly like a clean tree.  The
    positives below must be flagged and the negatives must not.
    """
    bad = [
        "                LDA    $02E000",          # KGlobals base
        "                STA    $02EFFF",          # top of the E page
        "                LDA    $02F000",          # F page
        "                LDA    $02FDFF",          # last flagged address
        "        LDAL   $02e123,X",                # lowercase hex
    ]
    good = [
        "; LDA $02E000 in a comment",              # comment-only
        "*               LDA    $02E000",          # full-line comment
        "                LDA    $02FE00",          # MOD_JT -- deliberately excluded
        "                LDA    $02FF01",          # handoff -- excluded
        "                LDA    KMem_KGlobals",    # the correct idiom
        "                LDA    $030000",          # different bank
    ]
    fails = 0
    for line in bad:
        if not LIT.search(code_part(line)):
            print(f"  SELFTEST FAIL: missed a baked address: {line.strip()}")
            fails += 1
    for line in good:
        if LIT.search(code_part(line)):
            print(f"  SELFTEST FAIL: false positive on: {line.strip()}")
            fails += 1
    if fails:
        print(f"check_baked_addrs self-test: {fails} FAILURE(S)")
        return 1
    print(f"check_baked_addrs self-test: OK "
          f"({len(bad)} caught, {len(good)} correctly ignored)")
    return 0


def main():
    if "--self-test" in sys.argv:
        return _selftest()

    tracked = subprocess.check_output(['git', 'ls-files', 'src', 'include']).decode().split()
    files = [f for f in tracked
             if f.endswith('.s') and f not in SOT and not f.endswith('kernel_exports.s')]
    hits = []
    for f in files:
        try:
            for n, line in enumerate(open(f, errors='replace'), 1):
                if LIT.search(code_part(line)):
                    hits.append(f'{f}:{n}: {line.strip()}')
        except FileNotFoundError:
            pass
    if hits:
        print('check_baked_addrs: baked kernel-data address literal(s) '
              '($02E000-$02FDFF) found. Reach kernel state by a memmap.s label '
              '(modules: add to gen_kernel_exports.py), not a literal:',
              file=sys.stderr)
        for h in hits:
            print('  ' + h, file=sys.stderr)
        sys.exit(1)
    print(f'check_baked_addrs: clean ({len(files)} files, no baked '
          'kernel-data address literals)')


if __name__ == '__main__':
    # sys.exit: main() RETURNS its status, and a self-test that cannot fail
    # the build is exactly the defect it exists to catch.
    sys.exit(main() or 0)
