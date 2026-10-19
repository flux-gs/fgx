#!/usr/bin/env python3
"""gen_wavee_bankpatch.py — label the Wave-E baked-$02 long-op sites and emit
src/kernel/wavee_bankpatch.s (the boot self-mod patch table).

WHY SELF-MOD (not DBR-rel like Waves A-D): these 29 sites DELIBERATELY use long
addressing (STAL/LDAL) because DBR != live kernel bank at the site (modload's
VTDR walk runs DBR=module-bank; the _Sys_Deliver* group is read in the syscall
dispatcher's USER-bank exit path; jumptable's _cdRegIdx is read at DBR=caller-bank).
Plain DBR-rel would read the wrong bank.  Instead we keep STAL/LDAL (DBR-INDEPENDENT)
and patch each baked operand BANK byte from $02 to the live kernel bank ONCE at boot
(_RelocPatchWaveE in main.s, via _BANKK) — so they reach live kernel data regardless
of the runtime DBR.  Mirror of the console $03 patch (gen_console_bankpatch.py).

From the build listing, find every bank-$02 long op in the 4 Wave-E files, label each
site `_weNNN` in the source, and write wavee_bankpatch.s = _WaveEBankPatchTbl: each DA
entry is the in-kernel-bank offset of a baked-$02 operand BANK byte (operand+3).

Idempotent-ish: aborts if a target line is already labeled (re-run on clean source).
ALL Wave-E sites must be whitespace-led — split any same-line label onto its own line first.

Usage: gen_wavee_bankpatch.py <listing> [--write]
"""
import re, sys

PC_BYTES = re.compile(r'\s*([0-9A-Fa-f]{2})/([0-9A-Fa-f]{4})\s*:\s*([0-9A-Fa-f ]+?)\s*$')
SRC = re.compile(r'(\S+)\s+(\d+)\s*$')
# data/ALU long opcodes (the .F family): STAL/LDAL/CMPL/ADCL/SBCL/ORAL/ANDL/EORL + ,X forms
LONG_OPS = {0x0F,0x1F,0x2F,0x3F,0x4F,0x5F,0x6F,0x7F,0x8F,0x9F,0xAF,0xBF,0xCF,0xDF,0xEF,0xFF}
PATHS = {
    'modload.s':   'src/kernel/modload.s',
    'signal.s':    'src/kernel/signal.s',
    'syscall.s':   'src/kernel/syscall.s',
    'jumptable.s': 'src/kernel/jumptable.s',
}
OUT = 'src/kernel/wavee_bankpatch.s'


FOREIGN = []            # baked-$02 long ops in files PATHS does not cover


def collect(listings):
    sites = []                                        # (base, lineno)
    foreign = FOREIGN
    for path in listings:
        for raw in open(path, errors='replace'):
            if ' : ' not in raw:
                continue
            toks = raw.split('|')
            if len(toks) < 8:
                continue
            m = PC_BYTES.match(toks[6])
            if not m:
                continue
            bts = [int(b, 16) for b in m.group(3).split() if b]
            if not (len(bts) == 4 and bts[0] in LONG_OPS and bts[3] == 0x02):
                continue
            sm = SRC.search(toks[1])
            if not sm:
                continue
            base = sm.group(1).rsplit('/', 1)[-1]
            if base not in PATHS:
                # A baked-$02 long op in a file this table does not cover is
                # the EXACT defect apple/fgx#105 lost a session to, one file
                # over: it reads the pristine $02 load image forever and no
                # build step objects.  Surface it instead of skipping it.
                foreign.append((base, int(sm.group(2)), sm.group(1)))
                continue
            sites.append((base, int(sm.group(2))))
    return sorted(set(sites))


def check(sites):
    """Gate mode: every baked-$02 long-op site must carry a _weNNN label AND
    appear in the table.  An unlabeled LDAL is not a build error -- it silently
    reads the pristine $02 LOAD IMAGE and is zero forever (apple/fgx#105 lost a
    session to exactly that).  LDAL is necessary, not sufficient."""
    unlabeled, found = [], []
    for base, ln in sites:
        repo = PATHS[base]
        line = open(repo, errors='replace').read().split('\n')[ln - 1]
        m = re.match(r'(_we\d+)\s', line)
        if m:
            found.append(m.group(1))
        else:
            unlabeled.append(f"{repo}:{ln}: {line.strip()}")

    tbl = open(OUT, errors='replace').read()
    intbl = set(re.findall(r'DA\s+(_we\d+)\+3', tbl))
    declared = re.search(r'_WaveEBankPatchEntries EQU (\d+)', tbl)
    declared = int(declared.group(1)) if declared else -1

    errs = []
    for base, ln, path in sorted(set(FOREIGN)):
        errs.append(f"  baked-$02 long op in {path}:{ln}, which this table does "
                    f"NOT cover -- add '{base}' to PATHS and regenerate, or make "
                    f"the access DBR-relative")
    for u in unlabeled:
        errs.append("  unlabeled baked-$02 long op (reads the STALE $02 image): " + u)
    for lab in sorted(set(found) - intbl):
        errs.append(f"  {lab} is labeled but MISSING from {OUT}")
    for lab in sorted(intbl - set(found)):
        errs.append(f"  {OUT} patches {lab}, which is no longer a baked-$02 site")
    if declared != len(intbl):
        errs.append(f"  _WaveEBankPatchEntries says {declared}, table has {len(intbl)} DA entries")

    if errs:
        print(f"wavee bankpatch OUT OF SYNC ({len(sites)} sites in the listing):")
        print('\n'.join(errs))
        print(f"  fix: strip the _weNNN labels, then re-run with --write")
        return 1
    print(f"wavee bankpatch OK: {len(intbl)} entries, in sync with the kernel listing")
    return 0


def main(argv):
    write = '--write' in argv
    listings = [a for a in argv if not a.startswith('--')]
    sites = collect(listings)
    if '--check' in argv:
        return check(sites)
    labels = {k: f'_we{i:03d}' for i, k in enumerate(sites, 1)}
    print(f"Wave-E baked-$02 long-op sites: {len(sites)}")

    byfile = {}
    for (base, ln), lab in labels.items():
        byfile.setdefault(base, []).append((ln, lab))

    aborted = False
    edits = {}
    for base, items in sorted(byfile.items()):
        repo = PATHS[base]
        src = open(repo, errors='replace').read().split('\n')
        for ln, lab in items:
            line = src[ln - 1]
            stripped = line.lstrip(' ')
            if not line.startswith(' ') or stripped[:3] == '_we':
                print(f"  !! {repo}:{ln} not a plain whitespace-led/unlabeled line: {line!r}")
                aborted = True
                continue
            src[ln - 1] = lab.ljust(16) + stripped
        edits[repo] = src
        print(f"  {repo}: {len(items)} sites")

    if aborted:
        print("ABORT: some sites are labeled / need manual handling (split the label onto its own line first).")
        return
    if write:
        for repo, src in edits.items():
            open(repo, 'w').write('\n'.join(src))

    entries = [f'{labels[k]}+3' for k in sites]
    out = []
    out.append(';==============================================================================')
    out.append('; wavee_bankpatch.s - GENERATED by tools/gen_wavee_bankpatch.py')
    out.append('; Do NOT hand-edit.  Re-run the generator if Wave-E baked-$02 sites move.')
    out.append(';')
    out.append('; Self-mod patch table for the Wave-E baked-$02 -> live-kernel-bank relocation.')
    out.append('; These STAL/LDAL sites run at DBR != kernel-bank (module/user/caller bank), so')
    out.append('; they cannot be DBR-rel\'d; instead _RelocPatchWaveE (main.s, at boot) overwrites')
    out.append('; each baked $02 operand BANK byte (operand+3) with the live kernel bank (_BANKK).')
    out.append(';==============================================================================')
    out.append('_WaveEBankPatchTbl')
    for e in entries:
        out.append(f'                DA      {e}')
    out.append(f'_WaveEBankPatchEntries EQU {len(entries)}')
    out.append(f'_WaveEBankPatchBytes   EQU {len(entries) * 2}')
    text = '\n'.join(out) + '\n'
    if write:
        open(OUT, 'w').write(text)
        print(f"  wrote {OUT} ({len(entries)} DA entries)")
    else:
        print(f"  (dry-run) {OUT}: {len(entries)} DA entries")


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]) or 0)
