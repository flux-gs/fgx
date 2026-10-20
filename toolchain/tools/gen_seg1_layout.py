#!/usr/bin/env python3
"""gen_seg1_layout.py - generate a Merlin32 stub that exposes seg1's
data label offsets to seg0's assembler.

Usage:
    gen_seg1_layout.py <seg1.lst> <seg1_layout.s>

Parses Merlin32 listing rows of the form:
    "  N |  ... | type | mx |  | size | BB/OOOO : bytes | LABEL DIRECTIVE ..."

For every row that defines a label AND has a directive that emits
bytes (DS / DA / DFB / ASC / HEX), emits an EQU declaration mapping
the label to its 16-bit offset within seg1.  The result is a flat
text file seg0.link.s PUTs at the top — Merlin32 then resolves every
LDA / STA / STZ / etc. against that label to an absolute operand.

Why this exists: seg0 and seg1 are separate Merlin32 invocations (no
shared symbol table).  At runtime DBR = seg1 bank, so seg0 code's
"LDA: name" reads the right memory — but the assembler still needs
the label's offset at link time.

If a label's offset is < $0100, Merlin32 may DP-fold the reference.
seg1.link.s pads with 256 bytes before any real data to avoid this.
"""

import re
import sys


# Merlin32 listing row shape (pipe-delimited).  Columns:
#   line# | file/source-line | type | mx | reloc | size | addr | source-text
LISTING_RE = re.compile(r'^\s*\d+\s*\|')


def parse_address(addr_field):
    """'0B/0142 : ...' -> 0x0142 (the 16-bit offset within seg)."""
    s = addr_field.strip().split()[0]
    if '/' not in s:
        return None
    _, off_hex = s.split('/', 1)
    try:
        return int(off_hex, 16)
    except ValueError:
        return None


# Match a leading label followed by a byte-emitting directive.  Order
# matters: we want the rows that actually allocate storage with a
# label, not the directive-only rows that just push the cursor (those
# extend the previous label).
LABEL_DIRECTIVE_RE = re.compile(
    r'^([A-Za-z_][A-Za-z0-9_]*)\s+'
    r'(DS|DA|DFB|ASC|HEX|FGX2_LONG_PTR|FGX2_ABS_OFFSET|LIBC_DATA_PTR)\b',
    re.IGNORECASE,
)

# A pure POSITION label: `<name> ANOP` emits no bytes but marks an offset that
# code legitimately references (the canonical case is the Unix end-of-data
# symbol `end`, base of an sbrk arena -- 2.11BSD sh blok.c `BLK(end)`).  Its
# listing row is type 'Directive' and carries the current address.
LABEL_ANOP_RE = re.compile(r'^([A-Za-z_][A-Za-z0-9_]*)\s+ANOP\b', re.IGNORECASE)


# Merlin32-internal label prefixes generated during macro expansion;
# they reappear in every assembly so cross-seg sharing collides.
INTERNAL_LABEL_PREFIXES = ('ozunid_',)


def extract_labels(lst_path):
    labels = []  # (offset, name)
    with open(lst_path) as f:
        for raw in f:
            if not LISTING_RE.match(raw):
                continue
            parts = [p.strip() for p in raw.rstrip('\n').split('|')]
            if len(parts) < 8:
                continue
            row_type = parts[2]
            # 'Data' rows emit bytes from DS/DA/etc.  'Macro' rows
            # come from FGX2_LONG_PTR / FGX2_ABS_OFFSET macro
            # invocations; these also allocate bytes at the address
            # column and may carry a label.  'Empty' rows can carry
            # a standalone label (e.g. `_libc_FILE_table\n  DA 0\n
            # DA 0\n...`); the label takes the next line's address.
            # 'Directive' rows are normally cursor pushes, but `<name> ANOP` is
            # a byte-less POSITION label (e.g. `end`) whose offset must export.
            if row_type not in ('Data', 'Macro', 'Empty', 'Directive'):
                continue
            source = parts[7]
            addr = parse_address(parts[6])
            if addr is None:
                continue
            stripped = source.strip()
            if row_type == 'Directive':
                ma = LABEL_ANOP_RE.match(stripped)
                if ma and not ma.group(1).startswith(INTERNAL_LABEL_PREFIXES):
                    labels.append((addr, ma.group(1)))
                continue
            m = LABEL_DIRECTIVE_RE.match(stripped)
            if m:
                name = m.group(1)
                if not name.startswith(INTERNAL_LABEL_PREFIXES):
                    labels.append((addr, name))
                continue
            # 'Empty' rows: just a bare label (e.g. `_libc_FILE_table`
            # followed by indented DAs).  Capture if the source-text
            # column is a single identifier.
            bare = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*$', stripped)
            if bare and row_type == 'Empty':
                name = bare.group(1)
                if not name.startswith(INTERNAL_LABEL_PREFIXES):
                    labels.append((addr, name))
    return labels


def main():
    if len(sys.argv) != 3:
        print("usage: gen_seg1_layout.py <seg1.lst> <seg1_layout.s>",
              file=sys.stderr)
        return 1
    lst_path, out_path = sys.argv[1], sys.argv[2]
    labels = extract_labels(lst_path)
    # Deduplicate (same label declared on multiple rows shouldn't
    # happen but be defensive) and sort by offset.
    seen = {}
    for off, name in labels:
        if name not in seen:
            seen[name] = off
    items = sorted(seen.items(), key=lambda kv: kv[1])

    with open(out_path, 'w') as f:
        f.write("* Auto-generated by tools/gen_seg1_layout.py.\n")
        f.write("* DO NOT EDIT — regenerated each build from seg1.lst.\n")
        f.write("*\n")
        f.write("* EQUs declaring every seg1 data label's offset so seg0\n")
        f.write("* Merlin32 can resolve `LDA: name` / `STA: name` to the\n")
        f.write("* right operand at assembly time.  DBR (set by loader to\n")
        f.write("* seg1's bank) supplies the bank byte at runtime.\n")
        f.write("*\n")
        f.write("* Names colliding with Merlin32 register operand tokens\n")
        f.write("* (S/X/Y — e.g. a C global `struct s {...} S;`) are declared\n")
        f.write("* as DUM labels instead: Merlin textually substitutes EQU\n")
        f.write("* symbols into operands BEFORE address-mode decode, so an\n")
        f.write("* `S EQU $xxxx` turns every `LDA 6,S` stack-relative operand\n")
        f.write("* into garbage; a label does not get substituted.\n")
        f.write("\n")
        reserved = {"s", "x", "y"}
        for name, off in items:
            if name.lower() in reserved:
                f.write(f"                DUM     ${off:04X}\n")
                f.write(f"{name}\n")
                f.write("                DEND\n")
            else:
                f.write(f"{name:<23} EQU     ${off:04X}\n")
    print(f"gen_seg1_layout: wrote {len(items)} labels to {out_path}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
