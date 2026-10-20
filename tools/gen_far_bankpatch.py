#!/usr/bin/env python3
"""gen_far_bankpatch -- cross-bank operand BANK-byte patch tables, both directions.

WHY THIS EXISTS.  The far kernel bank (bin/fgxfar.bin) is a SECOND statically
linked kernel image, and neither image knows the other's runtime bank: the
Memory Manager hands both out at boot.  So every cross-bank reference is
assembled against a placeholder bank -- FGX_KFAR_BANK ($08) core-side, the
core's ORG bank far-side -- and the boot code has to overwrite each operand's
BANK byte with the live value.  It can only do that from a table of addresses,
and a HAND-MAINTAINED table of addresses is a table that goes stale the first
time anyone inserts an instruction above a call site.  The failure is silent and
awful: the JSL still assembles, still runs, and jumps into whatever bank the
assembler baked in.

So the table is scraped out of the freshly-built listing, exactly like
tools/gen_w5100_patchsites.py and docs/superpowers/reloc-tools/
gen_console_bankpatch.py.  Sites are marked in source with a label on the SAME
line as the instruction (so the label's address IS the opcode address):

                _kfp001         JSL     KFAR_SOUND_BEEP

Core side (`core`): core kernel -> far bank, markers _kfpNNN, table
_FarPatchTbl in src/kernel/far_patchsites.s.
Far side (`far`): far bank -> core kernel, markers _cfpNNN, table
_CorePatchTbl in src/kernel/far/core_patchsites.s.

Entries are emitted SYMBOLICALLY (`DA _kfp001+3`), not as raw addresses, so the
assembler resolves them and a moved site cannot go stale silently.  Bank byte
is at operand+3 for JSL/LDAL/STAL, and at +1 (dst) / +2 (src) for MVN.

WHAT IT REJECTS -- this, not the table rendering, is the point:
  1. a marker on an instruction with no long operand (a marker on a JSR is the
     classic one: JSR is 16-bit, there is no bank byte to patch, and the call
     never leaves the bank);
  2. a `JSL KFAR_*` with NO marker -- an unpatched cross-bank call, the exact
     silent failure above (the sibling guard tools/check_far_calls.py rejects
     JSR/JMP to KFAR_ slots; this one is about MARKER COMPLETENESS);
  3. a duplicated marker label -- two sites patching one address, one of them
     left unpatched.
`--check` re-renders from the listing and fails on any drift from the committed
file, which is what keeps the committed table honest between regenerations.

ZERO SITES IS THE NORMAL CASE TODAY.  Both tables are empty until the export
tasks land, so an empty table is rendered, not an error: label, no DA lines,
EQU 0 for both counts.  The assembly walker does `CPX #_FarPatchBytes` / `BCC`,
so 0 means the loop body never runs.

Usage:
  gen_far_bankpatch.py <listing> <outfile> <core|far>            # (re)generate
  gen_far_bankpatch.py <listing> <outfile> <core|far> --check    # gate: exit 1 on drift
  gen_far_bankpatch.py --self-test
"""
import difflib
import re
import sys

# marker prefix, table label, entry-count EQU, byte-count EQU, export prefix.
#
# The fifth field is the EXPORT-SLOT symbol prefix of the bank being CALLED, and
# it is set only on the directions whose sites are calls INTO an export table --
# it drives the "unmarked cross-bank JSL" completeness check in scan().  The
# return directions have no such prefix: a far/tty -> core call names a scraped
# core symbol, whose spelling is not a pattern, and marker completeness there is
# enforced by the far-side ceiling check plus the fact that an unpatched operand
# lands in the assembler's ORG bank and halts on the first call.
#
# THREE BANKS SINCE 2026-08-22, hence two directions per peer rather than two in
# total: 'core'/'far' are the core <-> far pair, 'core-tty'/'tty' the core <->
# tty pair.  The KEY NAMES THE SIDE BEING PATCHED, then the peer where that is
# ambiguous, which is why the far pair keeps its original two-word spelling.
DIRECTIONS = {
    'core': ('_kfp', '_FarPatchTbl', '_FarPatchEntries', '_FarPatchBytes',
             'KFAR_'),
    'far': ('_cfp', '_CorePatchTbl', '_CorePatchEntries', '_CorePatchBytes',
            None),
    'core-tty': ('_ktp', '_TtyPatchTbl', '_TtyPatchEntries', '_TtyPatchBytes',
                 'KTTY_'),
    'tty': ('_ctp', '_CorePatchTbl', '_CorePatchEntries', '_CorePatchBytes',
            None),
}

# Offsets of the operand BANK byte(s) from the opcode address, per mnemonic.
# Anything not listed here has no bank byte, so a marker on it is a bug.
# Every 65816 form that carries a 24-bit operand, i.e. that HAS a bank byte to
# patch.  The long-addressing arithmetic/compare forms (merlin32 spells them with
# an L suffix) belong here just as much as LDAL/STAL: the console move needed
# SBCL and CMPL against CON_VT_STATE, and an allow-list that omitted them
# rejected correct code.  JML is JSL's tail-call sibling.
BANK_OFFSETS = {
    'JSL': (3,), 'JML': (3,),
    'LDAL': (3,), 'STAL': (3,),
    'ADCL': (3,), 'ANDL': (3,), 'CMPL': (3,), 'EORL': (3,),
    'ORAL': (3,), 'SBCL': (3,),
    'MVN': (1, 2), 'MVP': (1, 2),
}

# "  1234 | 5 file.s 6 | Code | 00 | | 3 | 02/0B6E : 22 00 00 08 | source"
_ADDR = re.compile(r'\s*([0-9A-Fa-f]{2})/([0-9A-Fa-f]{4})')

_HEADER = {
    'core': [
        '; far_patchsites.s - GENERATED by tools/gen_far_bankpatch.py',
        '; Do NOT hand-edit.  Re-run the generator if far-bank call sites move.',
        ';',
        '; CORE -> FAR bank-byte patch table.  The core kernel reaches far-bank',
        '; exports with `JSL <farbank>:KFAR_<slot>`, but the far bank\'s runtime bank',
        '; is not known until boot, so the assembler bakes FGX_KFAR_BANK ($08) into',
        '; every such operand.  Each DA below is the in-core-bank offset of one baked',
        '; operand BANK byte; boot walks this table and overwrites each with the live',
        '; far bank.  JSL/LDAL/STAL: operand+3.  MVN: operand+1 (dst) and +2 (src).',
        ';',
        '; Sites are marked in source by a _kfpNNN label on the instruction line, and',
        '; scraped from the kernel listing -- entries are symbolic, so a site that',
        '; moves is re-resolved by the assembler instead of going stale silently.',
    ],
    'far': [
        '; core_patchsites.s - GENERATED by tools/gen_far_bankpatch.py',
        '; Do NOT hand-edit.  Re-run the generator if core call sites move.',
        ';',
        '; FAR -> CORE bank-byte patch table.  Far-bank code reaches back into the',
        '; core kernel with JSL/LDAL/STAL <corebank>:<offset>, but the core bank is',
        '; assigned by the Memory Manager at boot, so the assembler bakes its ORG',
        '; bank into every such operand.  Each DA below is the in-far-bank offset of',
        '; one baked operand BANK byte; far-bank init walks this table and overwrites',
        '; each with the live core bank.  JSL/LDAL/STAL: operand+3.  MVN: +1 and +2.',
        ';',
        '; Sites are marked in source by a _cfpNNN label on the instruction line, and',
        '; scraped from the far-bank listing -- entries are symbolic, so a site that',
        '; moves is re-resolved by the assembler instead of going stale silently.',
    ],
    'core-tty': [
        '; tty_patchsites.s - GENERATED by tools/gen_far_bankpatch.py',
        '; Do NOT hand-edit.  Re-run the generator if tty-bank call sites move.',
        ';',
        '; CORE -> TTY bank-byte patch table.  The core kernel reaches tty-bank',
        '; exports with `JSL <ttybank>:KTTY_<slot>`, but the tty bank\'s runtime bank',
        '; is not known until boot, so the assembler bakes FGX_KTTY_BANK ($09) into',
        '; every such operand.  Each DA below is the in-core-bank offset of one baked',
        '; operand BANK byte; boot walks this table and overwrites each with the live',
        '; tty bank.  JSL/LDAL/STAL: operand+3.  MVN: operand+1 (dst) and +2 (src).',
        ';',
        '; Sites are marked in source by a _ktpNNN label on the instruction line, and',
        '; scraped from the kernel listing -- entries are symbolic, so a site that',
        '; moves is re-resolved by the assembler instead of going stale silently.',
    ],
    'tty': [
        '; core_patchsites.s - GENERATED by tools/gen_far_bankpatch.py',
        '; Do NOT hand-edit.  Re-run the generator if core call sites move.',
        ';',
        '; TTY -> CORE bank-byte patch table.  Tty-bank code reaches back into the',
        '; core kernel with JSL/LDAL/STAL <corebank>:<offset>, but the core bank is',
        '; assigned by the Memory Manager at boot, so the assembler bakes its ORG',
        '; bank into every such operand.  Each DA below is the in-tty-bank offset of',
        '; one baked operand BANK byte; Tty_BankInit walks this table and overwrites',
        '; each with the live core bank.  JSL/LDAL/STAL: operand+3.  MVN: +1 and +2.',
        ';',
        '; Sites are marked in source by a _ctpNNN label on the instruction line, and',
        '; scraped from the tty-bank listing -- entries are symbolic, so a site that',
        '; moves is re-resolved by the assembler instead of going stale silently.',
    ],
}


def parse_row(line):
    """Split one Merlin32 listing row into (line_type, addr, tokens).

    Returns None for rows with no address column (rulers, banner).  `tokens` is
    the source text with any trailing comment removed -- a Code row's comment
    can mention JSL/KFAR_ and must not be mistaken for the instruction.
    """
    parts = line.split('|', 7)
    if len(parts) < 8:
        return None
    m = _ADDR.match(parts[6])
    if not m:
        return None
    addr = (int(m.group(1), 16) << 16) | int(m.group(2), 16)
    return parts[2].strip(), addr, parts[7].split(';')[0].split()


def scan(text, direction):
    """THE decision logic.  Returns (sites, errors).

    sites is [(marker_label, bank_byte_offset), ...] in listing (address) order,
    one entry per bank byte -- an MVN contributes two.  errors is a list of
    human-readable strings; a non-empty list means the caller must NOT write a
    table, because a table that omits a real site is worse than no table.

    A marker label is only ever the FIRST token of a row: Merlin labels start in
    column 0.  That also means a marker on its own line has no following
    mnemonic, which is rejected -- the label would then carry the address of the
    NEXT instruction, not the marked one.
    """
    prefix = DIRECTIONS[direction][0]
    export_prefix = DIRECTIONS[direction][4]
    marker_re = re.compile(re.escape(prefix) + r'\d+$')
    sites, errors, seen = [], [], {}

    for line in text.splitlines():
        row = parse_row(line)
        if not row:
            continue
        ltype, addr, toks = row

        if toks and marker_re.match(toks[0]):
            label = toks[0]
            if label in seen:
                errors.append(
                    'duplicate marker %s (also at $%06X) -- two sites would '
                    'patch one address and the other stays unpatched'
                    % (label, seen[label]))
                continue
            seen[label] = addr
            mnem = toks[1].upper() if len(toks) > 1 else ''
            if mnem not in BANK_OFFSETS:
                errors.append(
                    'marker %s at $%06X is on %r, which has no operand bank '
                    'byte -- markers belong on %s only, on the SAME line as the '
                    'instruction'
                    % (label, addr, mnem or '(nothing)',
                       '/'.join(sorted(BANK_OFFSETS))))
                continue
            for off in BANK_OFFSETS[mnem]:
                sites.append((label, off))

        # Marker completeness, calling side: every cross-bank JSL must be marked.
        if export_prefix and ltype == 'Code':
            marked = bool(toks) and bool(marker_re.match(toks[0]))
            for i, t in enumerate(toks[:-1]):
                if t.upper() == 'JSL' and toks[i + 1].startswith(export_prefix):
                    if not marked:
                        errors.append(
                            'UNMARKED cross-bank call at $%06X: `JSL %s` has no '
                            '%sNNN marker, so its bank byte is never patched and '
                            'it jumps into the baked assembly-time bank'
                            % (addr, toks[i + 1], prefix))
    return sites, errors


def render(sites, direction):
    """Render the .s table.  Pure -- running it twice is byte-identical."""
    _, tbl, ent, byt, _export = DIRECTIONS[direction]
    pad = max(len(ent), len(byt))
    rule = ';' + '=' * 78
    out = [rule] + _HEADER[direction] + [rule, tbl]
    out += ['                DA      %s+%d' % (label, off) for label, off in sites]
    out.append('%-*s EQU %d' % (pad, ent, len(sites)))
    out.append('%-*s EQU %d' % (pad, byt, 2 * len(sites)))
    return '\n'.join(out) + '\n'


def check(block, outpath):
    """Compare a freshly rendered table against the committed file.

    Returns (rc, message).  Non-zero on ANY difference, including the file being
    absent: a missing table and a stale table fail the build the same way.
    """
    try:
        with open(outpath, errors='replace') as f:
            cur = f.read()
    except OSError as e:
        return 1, '%s cannot be read (%s) -- the table is missing' % (outpath, e)
    if cur == block:
        return 0, None
    diff = ''.join(difflib.unified_diff(
        cur.splitlines(True), block.splitlines(True),
        fromfile=outpath + ' (committed)', tofile='(regenerated)', n=1))
    return 1, '%s is OUT OF DATE vs the listing:\n%s' % (outpath, diff)


def _listing(rows):
    """Build a synthetic listing for the self-test, in the real column layout."""
    out = ['------+------+-------------+----+---------+------+-----------+------',
           ' Line | # File Line | Line Type | MX | Reloc | Size | Address   '
           'Object Code |  Source Code']
    for n, (ltype, addr, src) in enumerate(rows, 1):
        out.append('%5d |  1  x.s %3d | %-11s | 00 |         |    3 | '
                   '02/%04X : 22 00 00 08 | %s' % (n, n, ltype, addr, src))
    return '\n'.join(out) + '\n'


def _selftest():
    """Prove this generator can FAIL.

    Every assertion runs the SAME scan()/render()/check() the build runs -- no
    inline expressions that cannot fail (tools/check_kernel_ceiling.py once
    asserted `not (limit + 1 > limit)`, which tested arithmetic rather than the
    checker and would have passed against a checker with no teeth).
    """
    import os
    import tempfile
    fails = []

    def sites_only(text, direction='core'):
        sites, errors = scan(text, direction)
        return sites, errors

    # 1. One marked JSL -> exactly one entry, at +3.
    one = _listing([('Code', 0x0B6E, '_kfp001         JSL     KFAR_INIT')])
    sites, errors = sites_only(one)
    if sites != [('_kfp001', 3)] or errors:
        fails.append('marked JSL: got sites=%r errors=%r, want [(_kfp001, 3)] '
                     'and no errors' % (sites, errors))
    if 'DA      _kfp001+3' not in render(sites, 'core'):
        fails.append('marked JSL did not render `DA _kfp001+3`')

    # An MVN marker contributes both bank bytes.
    mvn = _listing([('Code', 0x0C00, '_kfp002         MVN     $08,$08')])
    sites, errors = sites_only(mvn)
    if sites != [('_kfp002', 1), ('_kfp002', 2)] or errors:
        fails.append('MVN marker: got %r / %r, want +1 and +2' % (sites, errors))

    # 2. A marker on a JSR has no bank byte -- must be rejected.
    for bad in ('JSR     KFAR_INIT', 'JMP     _somewhere', 'LDA     #$00'):
        sites, errors = sites_only(_listing([('Code', 0x0B6E, '_kfp001  ' + bad)]))
        if not errors:
            fails.append('marker on %r was ACCEPTED' % bad.split()[0])
    # A marker on its own line carries the wrong address -- also rejected.
    sites, errors = sites_only(_listing([('Empty', 0x0B6E, '_kfp001')]))
    if not errors:
        fails.append('bare marker label (no instruction) was ACCEPTED')

    # 3. An unmarked JSL to a KFAR_ symbol must be rejected.
    sites, errors = sites_only(_listing([('Code', 0x0B6E, '        JSL     KFAR_INIT')]))
    if not errors:
        fails.append('unmarked `JSL KFAR_INIT` was ACCEPTED -- it would jump '
                     'into the baked bank')
    if sites:
        fails.append('unmarked JSL produced table entries: %r' % (sites,))
    # ...but a comment mentioning it, or a non-KFAR JSL, must NOT trip it.
    for benign in ('        JSR     _BootCon_Init   ; patch the JSL KFAR_INIT later',
                   '        JSL     $E10000'):
        sites, errors = sites_only(_listing([('Code', 0x0B6E, benign)]))
        if errors:
            fails.append('false positive on %r: %r' % (benign.strip(), errors))

    # 4. A duplicate marker label must be rejected.
    dup = _listing([('Code', 0x0B6E, '_kfp001         JSL     KFAR_INIT'),
                    ('Code', 0x0C22, '_kfp001         JSL     KFAR_INIT')])
    sites, errors = sites_only(dup)
    if not errors:
        fails.append('duplicate _kfp001 was ACCEPTED')

    # 5. Zero sites is valid and must NOT error.
    empty_listing = _listing([('Code', 0x0B6E, '        LDA     #$0000')])
    sites, errors = sites_only(empty_listing)
    if sites or errors:
        fails.append('zero-site listing: got %r / %r, want no sites and no '
                     'errors' % (sites, errors))
    empty = render(sites, 'core')
    for want in ('_FarPatchTbl', '_FarPatchEntries EQU 0', '_FarPatchBytes   EQU 0'):
        if want not in empty:
            fails.append('empty table is missing %r' % want)
    if '\n                DA' in empty:
        fails.append('empty table emitted DA lines')

    # The far direction must key off its own marker prefix and labels.
    far = _listing([('Code', 0x0100, '_cfp001         LDAL    _kSomeCoreWord'),
                    ('Code', 0x0110, '_kfp009         JSL     KFAR_INIT')])
    sites, errors = sites_only(far, 'far')
    if sites != [('_cfp001', 3)] or errors:
        fails.append('far direction: got %r / %r, want only _cfp001+3'
                     % (sites, errors))
    block = render(sites, 'far')
    if '_CorePatchTbl' not in block or '_CorePatchEntries EQU 1' not in block:
        fails.append('far direction rendered the wrong table labels')

    # The two TTY directions are a THIRD BANK, not a rename of the far pair.
    # Asserted here rather than trusted because the four-tuple that describes a
    # direction is data: a copied row with one field left saying `_cfp` or
    # `_FarPatchTbl` renders a table the assembler happily accepts and the wrong
    # bank walks, and only the boot would notice.
    ct = _listing([('Code', 0x0B6E, '_ktp001         JSL     KTTY_INIT'),
                   ('Code', 0x0B80, '_kfp001         JSL     KFAR_INIT')])
    sites, errors = sites_only(ct, 'core-tty')
    if sites != [('_ktp001', 3)] or errors:
        fails.append('core-tty direction: got %r / %r, want only _ktp001+3'
                     % (sites, errors))
    block = render(sites, 'core-tty')
    for want in ('_TtyPatchTbl', '_TtyPatchEntries EQU 1', 'DA      _ktp001+3'):
        if want not in block:
            fails.append('core-tty rendered without %r' % want)
    if '_FarPatchTbl' in block:
        fails.append('core-tty rendered the FAR bank\'s table label')

    # ...and an unmarked JSL into the tty export table must be rejected the same
    # way an unmarked JSL into the far one is.  This is the completeness check
    # that used to be spelled `direction == 'core'`, so it is the one field most
    # likely to have been left behind when the pair was copied.
    sites, errors = sites_only(
        _listing([('Code', 0x0B6E, '        JSL     KTTY_INIT')]), 'core-tty')
    if not errors:
        fails.append('unmarked `JSL KTTY_INIT` was ACCEPTED -- it would jump '
                     'into the baked bank')

    sites, errors = sites_only(
        _listing([('Code', 0x0100, '_ctp001         JSL     _FarSh_LogStr'),
                  ('Code', 0x0110, '_cfp001         JSL     _FarSh_LogStr')]), 'tty')
    if sites != [('_ctp001', 3)] or errors:
        fails.append('tty direction: got %r / %r, want only _ctp001+3'
                     % (sites, errors))

    # 6. --check must reject a stale file and accept a matching one.
    good = render(*(sites_only(one)[0], 'core'))
    tmp = tempfile.mkdtemp()
    match = os.path.join(tmp, 'match.s')
    stale = os.path.join(tmp, 'stale.s')
    with open(match, 'w') as f:
        f.write(good)
    with open(stale, 'w') as f:
        f.write(good.replace('_kfp001+3', '_kfp001+1'))
    rc, _ = check(good, match)
    if rc != 0:
        fails.append('--check REJECTED an up-to-date table')
    rc, msg = check(good, stale)
    if rc == 0 or not msg:
        fails.append('--check ACCEPTED a stale table')
    rc, _ = check(good, os.path.join(tmp, 'absent.s'))
    if rc == 0:
        fails.append('--check ACCEPTED a missing table')
    for p in (match, stale):
        os.unlink(p)
    os.rmdir(tmp)

    # Idempotency: the renderer is pure, so a second run is byte-identical.
    if render(*(sites_only(one)[0], 'core')) != good:
        fails.append('render() is not deterministic -- a second run would '
                     'rewrite its own input and self-invalidate the build')

    if fails:
        for f in fails:
            print('  %s' % f, file=sys.stderr)
        print('gen_far_bankpatch self-test: %d FAILURE(S)' % len(fails))
        return 1
    print('gen_far_bankpatch self-test: OK (scrapes +3/+1/+2 sites, rejects a '
          'marker with no bank byte, an unmarked JSL to KFAR_*/KTTY_*, and a '
          'duplicate marker; keeps the four directions\' tables apart; renders '
          'a valid EQU 0 empty table; --check catches stale, missing, and '
          'passes matching)')
    return 0


def main():
    if '--self-test' in sys.argv:
        return _selftest()

    args = [a for a in sys.argv[1:] if a != '--check']
    do_check = '--check' in sys.argv
    bad = [a for a in args if a.startswith('--')]
    if bad:
        sys.exit('gen_far_bankpatch: unknown option %r' % bad[0])
    if len(args) != 3 or args[2] not in DIRECTIONS:
        sys.exit(__doc__.strip().splitlines()[-3].strip())
    listing, outpath, direction = args

    with open(listing, errors='replace') as f:
        text = f.read()
    sites, errors = scan(text, direction)
    if errors:
        for e in errors:
            print('gen_far_bankpatch: %s' % e, file=sys.stderr)
        print('gen_far_bankpatch: %d problem(s) in %s -- table NOT written, an '
              'incomplete table is worse than none' % (len(errors), listing),
              file=sys.stderr)
        return 1

    block = render(sites, direction)
    if do_check:
        rc, msg = check(block, outpath)
        if rc:
            sys.stderr.write(
                'error: %s\n  Run: python3 tools/gen_far_bankpatch.py %s %s %s\n'
                % (msg, listing, outpath, direction))
            return rc
        print('far bankpatch (%s) OK: %d entries, in sync with %s'
              % (direction, len(sites), listing))
        return 0

    with open(outpath, 'w') as f:
        f.write(block)
    print('gen_far_bankpatch: wrote %s (%d %s patch entries)'
          % (outpath, len(sites), direction))
    return 0


if __name__ == '__main__':
    # sys.exit: main() RETURNS its status, and a generator/gate that cannot fail
    # the build is exactly the defect it exists to catch.
    sys.exit(main() or 0)
