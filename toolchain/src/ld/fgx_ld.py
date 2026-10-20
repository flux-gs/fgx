#!/usr/bin/env python3
"""
fgx_ld.py - FGX2 linker driver (Phase 4 slice 4.1).

Stitches pre-assembled, header-less segment binaries into an FGX2 binary
described by a small JSON manifest.  Eliminates hand-written FGX2 headers,
segment tables, and reloc tables in multi-segment program sources.

Manifest schema (JSON):

    {
      "output":         "multibank3",         # output filename (manifest-relative)
      "n_data_segment": 0,                    # segment holding globals/strings
      "entry_offset":   0,                    # PC offset within data seg @ exec
      "flags":          0,                    # FGX2 flags byte (bit 0 = strict)
      "segments": [
        {
          "bin":     "seg0",                  # pre-assembled segment file
          "listing": "seg0.lst",              # Merlin -V listing for auto-xrefs
                                              # (optional; omit if no xrefs)
          "kind":    "CODE",                  # CODE | DATA | RODATA
          "bss":     0,                       # zero-fill bytes after text
          "org":     0,                       # address the segment was
                                              # assembled at in its bank
          "offsets": [1, 4],                  # optional: every same-segment
                                              # address (fgx_offrel); present
                                              # = the segment may load at a
                                              # page offset (flag + relocs)
          "xrefs": [                          # manual xrefs (merged with auto)
            { "offset": 7, "kind": "jsl_bank",  "target_seg": 1 }
          ]
        },
        ...
      ],
      "library": {                            # optional: a library (libc.so)
        "core": 3, "templates": 4,            # core template / block templates
        "blocks": "libc_so.blocks.json",      # fcc --emit-blocks
        "core_list": "core.list",             # statics kept in the core
        "data_exports": "data.exports",       # the data names exported
        "static_prefix": "_libc_c_",          # fcc's static-name prefix
        "version": [1, 0]
      }
    }

A library link sets header flags bit 1 and appends a trailer after the
relocs, laid out by library_trailer (read back by read_trailer): export
table and its CRC-32, member-block table, per-process fixups.
A dynamic program ("dynamic": true, with "imports") sets header flags
bit 2 and appends dyn_trailer's (read back by read_dyn_trailer): its
imports and their sites.

Each xref produces one FGX2 reloc-table entry: (src_seg, offset, tgt_seg).

Offset relocations: a segment with "offsets" is PLACEABLE -- the loader may
put it at a page offset instead of $0000 -- and its segment-table byte 5
has bit 0 set (include/loader.s FGX2_SEGF_PLACE).  Every address that
names it then gets a reloc with bit 7 of tgt_seg set (FGX2_RELOC_OFFSET):
add segment tgt's load offset to the 16-bit word at src_seg:offset.  Those
are the segment's own "offsets" and every 16-bit address this linker writes
whose target is placeable.  A literal target offset (FGX2_XREF_JSL_BANK)
into a placeable segment cannot be relocated, and is refused.
Both jsl_bank and data_bank relocs map to the same loader operation (write
tgt_seg's runtime bank into the byte at src_seg:offset); `kind` only
documents the source-side construct + selects the macro-delta in the
listing parser.

Listing-based auto-derivation (Phase 4.2):  if a segment specifies
`listing`, fgx_ld parses the Merlin -V output for rows of type `Macro`
whose source-text column starts with a known FGX2 xref macro name.  For
each such row it reads the address column (the macro expansion's base
address) and the macro args (semicolon-separated), then emits one reloc
entry per macro invocation using a macro-specific delta:

  FGX2_XREF_JSL_BANK <tag>;<tgt_seg>;<tgt_off>    delta = +3  (JSL bank)
  FGX2_CALLEE_ENTER  <tag>;<tgt_seg>              delta = +4  (LDA #imm)

Auto-derived xrefs are merged with manual ones from the manifest.

Named-symbol imports (Phase 4.4):  two additional macros let callers
reference callees by name instead of literal offset, so adding an
instruction to a callee segment no longer silently breaks callers:

  FGX2_EXPORT     <name>                  ; emits 0 bytes; records
                                          ; exports[seg][name] = invocation addr
  FGX2_IMPORT_JSL <tag>;<name>;<tgt_seg>  ; emits `JSL $000000`; linker
                                          ; patches LL+HH at addr+1..+2 with
                                          ; resolved offset and emits a bank
                                          ; reloc at addr+3.

Imports are resolved after every segment has been scanned, so callee
segments can appear in any order relative to their callers.  Missing
exports produce a fatal error naming the segment, address, and symbol.

Output binary layout (matches include/loader.s constants):

    offset  size  field
    0       4     "FGX2"
    4       2     reserved (0)
    6       1     n_segments
    7       1     n_data_segment
    8       2     entry_offset
    10      1     flags
    11      2     reloc_count
    13      3     reserved (0)
    16      8*N   segment table (size, bss, kind, 3 reserved)
    16+8N   ...   concatenated segment data
    ...     4*R   reloc entries (src_seg, offset, tgt_seg)
"""

import argparse
import json
import os
import re
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stack_measure  # noqa: E402  (co-located in src/ld; see relocation note)
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), "tools"))
import gen_seg1_layout  # noqa: E402  (toolchain/tools: listing -> labels)

FGX2_MAGIC = b'FGX2'
# FGX3 (P3-5 I1): byte-identical layout to FGX2 — same 16-byte header, segtab,
# segment data, and 4-byte reloc entries — plus a MANDATORY ABI stamp at header
# byte 13 (reserved-0 in FGX2).  The magic bump is the clean-break marker: a
# pre-P3 kernel rejects the unknown magic natively (ENOEXEC), and the post-P3
# loader rejects a stale stamp, so a post-flip binary and a pre-flip kernel can
# never silently mis-run each other.  Keep in sync: include/loader.s
# FGX3_MAGIC / FGX3_OFF_ABI / FGX_ABI_CURRENT.
FGX3_MAGIC = b'FGX3'
FGX_ABI_CURRENT = 2    # v2 = post-Phase-3 (32-bit ptr model, hw stack, ABI v2)
ABI_OFF = 13           # FGX3 header byte 13 = abi_version (FGX2: reserved 0)
HEADER_SZ = 16
SEGTAB_ENTRY_SZ = 8
RELOC_ENTRY_SZ = 4
MAX_SEGS = 8
# include/loader.s FGX2_MAX_SEGS.  Every segment's bank takes a row of the
# task's TCB_BankList, which has 8 rows (slot 0 is the segment-0 code bank).
# Going past 8 needs the kernel TCB restructure (TCB_SIZE is pinned at 64
# bytes by an ERR), not a bigger number.
# FGX2 header byte 14 (shared with FGX1_OFF_STACK): bank-0 hardware-stack size
# hint the loader honours (Task_AllocStack, process.s).  0 = loader default
# (1 page).  Clamp must match the kernel's TASK_STACK_MAX_PAGES (task.s).
STACK_HINT_OFF = 14
# FGX2/FGX3 header byte 15: how many DEDICATED banks this binary wants for its
# soft-frame stack (bank-0 stack campaign 1.3).  0 = none, and every binary
# built before the campaign reads 0 because the byte was `reserved`.
#
# DERIVED, not declared.  A binary needs a soft bank exactly when fcc gave some
# function a soft frame, and that fact is visible in the assembly as a
# `<fn>_SOFTSIZE EQU` -- so the linker reads it out of the same files it already
# walks for the stack model.  Nothing new has to be passed down the build, and
# the flag cannot disagree with the codegen that motivates it.
SOFT_BANK_OFF = 15
SOFTSIZE_RE = re.compile(r"^\w+_SOFTSIZE\s+EQU", re.M)
MAX_STACK_PAGES = 83   # keep in sync with kernel TASK_STACK_MAX_PAGES (task.s)
# THE FLOOR UNDER THE HINT.  The stack model's number is a floor with no
# margin behind it: it cannot see a hand-written libc push, a signal frame
# or a data-dependent recursion, and the tools it sized to a page or two
# were measured within a few hundred bytes of their reservations.  A
# reservation is no longer a lifetime cost in bank 0 -- the kernel parks a
# task's stack when another needs its addresses (task.s, Uimg_*) -- so every
# binary gets at least this many pages, which with the argv frame, the guard
# and the direct page the kernel adds is an 8-page reservation.  A binary
# whose model already asks for more is unchanged -- the session shell's
# reservation, for one, is sized so its guard fires before its script arena
# silently truncates (the link's stack_pad, fgx_static/fgx_dyn --stack-pad),
# and a floor above it would trade that loud death for a silent one.
# Provisional: adjust from measurement in use.
MIN_STACK_PAGES = 5
MAX_RELOCS = 65535  # The reloc_count header field is 16-bit ("<H"), so this is
                    # the true format ceiling.  SP5: the loader now STREAMS the
                    # reloc table in fixed 64-entry batches (src/kernel/loader.s),
                    # so it no longer needs a matching buffer — big multi-bank C
                    # ports (vi: >1000 relocs) link without an artificial cap.
KIND_MAP = {"CODE": 0, "DATA": 1, "RODATA": 2}
# include/kernel.s HEAP_LIM: the heap limit cell the loader writes at this
# offset of every data bank.  A data segment's bytes plus bss must end at or
# below it, or the loader's store overwrites the segment's tail.
HEAP_LIM = 0xFFF8
VALID_XREF_KINDS = {"jsl_bank", "data_bank"}

# Per-macro descriptors.
#
# Reloc-emitting macros (literal-target form, slice 4.2):
#   "delta"   - byte offset from invocation addr to the patch byte
#   "kind"    - documentary tag (jsl_bank | data_bank); both map to the
#               same loader operation (write tgt_seg's runtime bank)
#   "tgt_arg" - 0-indexed macro arg holding target_seg (after splitting
#               the source-text column on ';' after the macro name)
#
# Name-resolution macros (slice 4.4):
#   FGX2_EXPORT     - records exports[seg][name] = invocation_addr
#   FGX2_IMPORT_JSL - resolves <name> in tgt_seg, patches operand low/high
#                     at addr+1/+2, emits bank reloc at addr+3
RELOC_MACROS = {
    "FGX2_XREF_JSL_BANK": {"delta": 3, "kind": "jsl_bank",  "tgt_arg": 1},
    "FGX2_CALLEE_ENTER":  {"delta": 4, "kind": "data_bank", "tgt_arg": 1},
}

# Merlin listing rows start with line-number + `|`.
LISTING_ROW_RE = re.compile(r"^\s*\d+\s*\|")


def die(msg):
    sys.stderr.write(f"fgx_ld: {msg}\n")
    sys.exit(2)


JSL_OPCODE = 0x22
JML_OPCODE = 0x5C
PHB_OPCODE = 0x8B
LDA_IMM8_OPCODE = 0xA9


def d1_check(relocs, seg_data, seg_kinds, n_data, bound=frozenset()):
    """
    D1 link-time bank-consistency gate (ORCA-informed decision D1,
    docs/decisions/orca-informed-decisions.md; adopted 2026-06-01,
    implemented with the 2026-07-05 architecture audit).

    Every FGX2 reloc writes a target segment's runtime BANK into one byte.
    Each reloc kind has a known compile-time shape, so a reloc whose patch
    site does not look like that shape means the reloc address drifted (the
    listing-parser class that once left g_op_table at $0000) or the macro
    args are wrong — either way the loader would stamp a bank byte into the
    middle of an instruction.  Fail the LINK, not the runtime:

      1. The patched byte must be the $00 placeholder every FGX2 macro emits.
      2. jsl-family relocs (XREF_JSL_BANK / IMPORT_JSL / FARCALL / manual
         jsl_bank) must patch the bank byte of an actual JSL ($22 at -3),
         and must target a CODE segment (a call into DATA is a bank bug).
      3. CALLEE_ENTER relocs must patch the imm of the PHB..LDA #$00
         prologue and must target THE data segment (n_data) — an fcc
         --data-segment value that disagrees with the manifest is exactly
         the silent wrong-bank case this gate exists to catch.
      4. LONG_PTR relocs must be followed by the $00 pad byte.
      4a. FARJUMP relocs must patch the bank byte of a JML ($5C at -3) and
         target a CODE segment, as the jsl family does for a JSL.
      5. No byte may be patched twice (conflicting or duplicated relocs).
    """
    seen = {}
    for src, off, tgt, prov in relocs:
        where = f"seg {src} offset {off:#06x} ({prov} -> seg {tgt})"
        prev = seen.get((src, off))
        if prev is not None:
            die(f"D1: byte patched by two relocs: {where}; first was {prev}")
        seen[(src, off)] = where
        data = seg_data[src]
        if data[off] != 0x00:
            die(f"D1: bank-reloc patch byte is not the $00 placeholder "
                f"(found ${data[off]:02X}) at {where} — reloc address drift?")
        if prov in ("xref_jsl", "import_jsl", "farcall", "manual_jsl"):
            if off < 3 or data[off - 3] != JSL_OPCODE:
                found = f"${data[off - 3]:02X}" if off >= 3 else "out of range"
                die(f"D1: jsl-bank reloc does not patch a JSL bank byte "
                    f"(opcode at patch-3 is {found}) at {where}")
            if seg_kinds[tgt] != "CODE":
                die(f"D1: call-bank reloc targets non-code segment "
                    f"({seg_kinds[tgt]}) at {where}")
        elif prov == "farjump":
            if off < 3 or data[off - 3] != JML_OPCODE:
                found = f"${data[off - 3]:02X}" if off >= 3 else "out of range"
                die(f"D1: farjump reloc does not patch a JML bank byte "
                    f"(opcode at patch-3 is {found}) at {where}")
            if seg_kinds[tgt] != "CODE":
                die(f"D1: jump-bank reloc targets non-code segment "
                    f"({seg_kinds[tgt]}) at {where}")
        elif prov == "callee_enter":
            if off < 4 or data[off - 1] != LDA_IMM8_OPCODE \
                       or data[off - 4] != PHB_OPCODE:
                die(f"D1: CALLEE_ENTER reloc shape mismatch (expected "
                    f"PHB..SEP..LDA #$00 prologue) at {where}")
            if tgt != n_data:
                die(f"D1: CALLEE_ENTER reloc targets segment {tgt}, but the "
                    f"manifest's data segment is {n_data}, at {where} — "
                    f"fcc --data-segment / manifest n_data_segment disagree")
        elif prov == "long_ptr":
            if off + 1 >= len(data) or data[off + 1] != 0x00:
                die(f"D1: LONG_PTR pad byte after the bank is not $00 "
                    f"at {where}")
        elif prov == "libc_data_ptr":
            # T5-C C6: same-segment far-pointer cell (stdio cells).  The
            # row must sit IN the data segment and target itself.
            if off + 1 >= len(data) or data[off + 1] != 0x00:
                die(f"D1: LIBC_DATA_PTR pad byte after the bank is not $00 "
                    f"at {where}")
            if src != tgt or tgt != n_data:
                die(f"D1: LIBC_DATA_PTR reloc must target its own (data) "
                    f"segment {n_data}, at {where}")
        # manual_data: generic shape — placeholder + duplicate checks only.

    # D1b (P3-5 I3): orphan-JSL scan.  d1_check above validates relocs that
    # EXIST; the transport's characteristic failure is a silently-skipped
    # listing row, which leaves the `JSL $000000` image in the segment with
    # NO reloc claiming its bank byte — invisible to every check above and
    # a guaranteed runtime jump to $00:0000.  Flag any unclaimed one.
    # (The LONG_PTR analog — 4 zero bytes in DATA — is indistinguishable
    # from legitimate zero data, which is exactly why the per-TU
    # FGX2_RELOC_COUNT cross-check exists; D1b covers the code side, the
    # count gate covers everything else.)
    # An import's call site (a library's call into a library below it) is
    # claimed by the binder, which writes its bank: `bound' holds each such
    # JSL's bank-byte address.
    claimed = set((src, off) for src, off, _t, _p in relocs) | set(bound)
    for si, data in enumerate(seg_data):
        if seg_kinds[si] != "CODE":
            continue
        for i in range(len(data) - 3):
            if data[i] == JSL_OPCODE and data[i + 1] == 0 \
               and data[i + 2] == 0 and data[i + 3] == 0 \
               and (si, i + 3) not in claimed:
                die(f"D1b: unclaimed JSL $000000 image at seg {si} offset "
                    f"{i:#06x} — no reloc patches its bank byte.  A "
                    f"listing row was likely skipped (unresolved import/"
                    f"farcall), or hand-asm emitted a placeholder JSL "
                    f"without a reloc")


def _parse_macro_row(raw):
    """
    If `raw` is a Macro-typed listing row, return (macro_name, args, addr,
    srcfile).  Otherwise return None.  Address is the integer offset within
    the seg (the OOOO part of the Merlin `BB/OOOO` address column); srcfile
    is the contributing source file from the listing's file column (P3-5 I3:
    keys the per-TU FGX2_RELOC_COUNT cross-check).
    """
    if not LISTING_ROW_RE.match(raw):
        return None
    parts = [p.strip() for p in raw.rstrip('\n').split('|')]
    # Expected: [lineno, file/srcline, type, mx, reloc, size, addr_obj, source]
    if len(parts) < 8:
        return None
    if parts[2] != "Macro":
        return None
    source = parts[7]
    tokens = source.split(None, 2)
    if not tokens:
        return None
    # Lines with a column-1 label have the macro name as tokens[1]:
    #   `_fas_g_op_table   FGX2_ABS_OFFSET  _Sp;_S26;0`
    # Unlabelled lines have the macro at tokens[0]:
    #   `                  FGX2_ABS_OFFSET  _Sp;_S26;0`
    # FGX2 macros all start with "FGX2_"; check the first token and
    # shift over a label if present.  Without this, label rows were
    # silently skipped — e.g. the first FGX2_ABS_OFFSET of g_op_table
    # stayed at $0000 because `_fas_g_op_table` was parsed as the
    # macro name.
    def _is_ld_macro(tok):
        # FGX2_* (fcc/linker macros) + LIBC_EXPORT (libc.s's self-defined
        # FGX2_EXPORT twin) + LIBC_DATA_PTR
        # (libc_data.s's self-defined same-segment far-pointer cell, T5-C C6).
        return (tok.startswith("FGX2_") or tok == "LIBC_EXPORT"
                or tok == "LIBC_DATA_PTR")
    if _is_ld_macro(tokens[0]):
        macro_name = tokens[0]
        args_field = tokens[1] if len(tokens) > 1 else ""
    elif len(tokens) >= 2 and _is_ld_macro(tokens[1]):
        macro_name = tokens[1]
        args_field = tokens[2] if len(tokens) > 2 else ""
    else:
        return None
    # Strip trailing inline comment if any.
    args_field = args_field.split(';*', 1)[0].split('  ;', 1)[0]
    args = [a.strip() for a in args_field.split(';')] if args_field else []
    # Address column: 'BB/OOOO' optionally followed by ': bytes'.
    addr_field = parts[6].split()[0] if parts[6] else ""
    if '/' not in addr_field:
        return None
    _, off_hex = addr_field.split('/', 1)
    try:
        addr = int(off_hex, 16)
    except ValueError:
        return None
    # File column (parts[1]): '<put-depth> <filename> <srcline>'.  The
    # filename keys per-TU count attribution; tolerate shape drift by
    # falling back to the whole field.
    ftoks = parts[1].split()
    srcfile = ftoks[1] if len(ftoks) >= 2 else (ftoks[0] if ftoks else "?")
    return macro_name, args, addr, srcfile


def scan_listing(path, n_segs, org=0):
    """
    Scan a Merlin32 -V listing and bucket FGX2 macro invocations into:
      - "relocs":   list of (offset, kind, tgt_seg) for literal-target macros
      - "exports":  dict[name] = offset  (FGX2_EXPORT)
      - "imports":  list of (addr, name, tgt_seg)  (FGX2_IMPORT_JSL)
      - "longptr":  list of (addr, name, tgt_seg)  (FGX2_LONG_PTR, slice 4.5)
    """
    relocs = []
    exports = {}
    imports = []
    longptr = []
    dataptr = []     # T5-C C6: LIBC_DATA_PTR bank-byte rows (addr list)
    absoff  = []
    farcalls = []
    modes = []
    rowcount = {}    # P3-5 I3: recognized FGX2_*/LIBC_EXPORT rows per srcfile
    declared = {}    # P3-5 I3: FGX2_RELOC_COUNT declarations per srcfile
    modefiles = set()  # files contributing FGX2_MODE (= fcc-generated TUs)
    try:
        with open(path) as f:
            lines = f.readlines()
    except OSError as e:
        die(f"cannot read listing '{path}': {e}")

    for raw in lines:
        parsed = _parse_macro_row(raw)
        if parsed is None:
            continue
        macro_name, args, addr, srcfile = parsed
        if addr < org:
            die(f"{path}: row at {addr:#06x} lies below the segment's org "
                f"{org:#06x}")
        addr -= org

        if macro_name == "FGX2_RELOC_COUNT":
            # P3-5 I3: per-TU declaration of how many FGX2_* rows this
            # source file emitted.  Cross-checked below against the rows
            # actually RECOGNIZED — a listing row the parser silently
            # drops (the g_op_table-at-$0000 class) makes the recognized
            # count come up short, and the link dies instead of shipping
            # an unpatched $00 placeholder.
            if len(args) < 1 or not args[0]:
                die(f"{path}: FGX2_RELOC_COUNT missing value "
                    f"(addr {addr:#06x})")
            try:
                val = int(args[0], 0)
            except ValueError:
                die(f"{path}: FGX2_RELOC_COUNT value '{args[0]}' not an "
                    f"integer (addr {addr:#06x})")
            declared[srcfile] = declared.get(srcfile, 0) + val
            continue

        # Every OTHER recognized FGX2_*/LIBC_EXPORT row counts toward its
        # file's total (recognition point — BEFORE the name dispatch, so
        # unknown FGX2_* names still count exactly as fcc counted them).
        rowcount[srcfile] = rowcount.get(srcfile, 0) + 1

        if macro_name == "FGX2_MODE":
            # P3-5 I2: per-TU toolchain-contract stamp (0 bytes).  Collected
            # here, gated in main(): every stamp in every listing must equal
            # FGX_ABI_CURRENT, and FGX3 output requires >=1 per listing.
            if len(args) < 1 or not args[0]:
                die(f"{path}: FGX2_MODE missing value (addr {addr:#06x})")
            try:
                val = int(args[0], 0)
            except ValueError:
                die(f"{path}: FGX2_MODE value '{args[0]}' not an integer "
                    f"(addr {addr:#06x})")
            modes.append((addr, val))
            modefiles.add(srcfile)
            continue

        if macro_name in ("FGX2_EXPORT", "LIBC_EXPORT"):
            # LIBC_EXPORT is libc.s's self-defined twin of FGX2_EXPORT
            # (defined there so near links that never PUT macros.s still
            # assemble).  The row still counts toward FGX2_RELOC_COUNT.
            if len(args) < 1 or not args[0]:
                die(f"{path}: {macro_name} missing symbol name (addr {addr:#06x})")
            name = args[0]
            if name in exports:
                die(f"{path}: {macro_name} '{name}' duplicated "
                    f"(first at {exports[name]:#06x}, again at {addr:#06x})")
            exports[name] = addr
            continue

        if macro_name == "FGX2_IMPORT_JSL":
            if len(args) < 3:
                die(f"{path}: FGX2_IMPORT_JSL at {addr:#06x} expects "
                    f"3 args (tag;name;tgt_seg), got {args}")
            name = args[1]
            try:
                tgt = int(args[2], 0)
            except ValueError:
                die(f"{path}: FGX2_IMPORT_JSL at {addr:#06x}: tgt_seg "
                    f"'{args[2]}' not an integer")
            if not (0 <= tgt < n_segs):
                die(f"{path}: FGX2_IMPORT_JSL at {addr:#06x}: tgt_seg "
                    f"{tgt} out of range 0..{n_segs - 1}")
            imports.append((addr, name, tgt))
            continue

        if macro_name in ("FGX2_FARCALL", "FGX2_FARJUMP"):
            # Cross-bank user call (JSL) or jump (JML), GLOBAL resolution (no
            # caller-supplied tgt_seg, unlike FGX2_IMPORT_JSL).  1 arg: the
            # target name, found by searching every segment's exports in the
            # resolution pass.  The two share an operand layout (+1,+2
            # offset, +3 bank), so one list and one patch loop.
            if len(args) < 1 or not args[0]:
                die(f"{path}: {macro_name} at {addr:#06x} missing symbol name")
            farcalls.append((addr, args[0], macro_name))
            continue

        if macro_name == "LIBC_DATA_PTR":
            # T5-C C6: same-segment far-pointer cell (stdio cells in
            # libc_data.s).  The offset was assembly-resolved (same-file
            # target); only the bank byte at addr+2 needs a load-time
            # reloc, targeting the CONTAINING segment — appended at the
            # per-segment resolve where that index is known.  Args are
            # documentary (tag;target-expr).
            dataptr.append(addr)
            continue

        if macro_name == "FGX2_LONG_PTR":
            if len(args) < 3:
                die(f"{path}: FGX2_LONG_PTR at {addr:#06x} expects "
                    f"3 args (tag;name;tgt_seg), got {args}")
            name = args[1]
            try:
                tgt = int(args[2], 0)
            except ValueError:
                die(f"{path}: FGX2_LONG_PTR at {addr:#06x}: tgt_seg "
                    f"'{args[2]}' not an integer")
            if not (0 <= tgt < n_segs):
                die(f"{path}: FGX2_LONG_PTR at {addr:#06x}: tgt_seg "
                    f"{tgt} out of range 0..{n_segs - 1}")
            longptr.append((addr, name, tgt))
            continue

        if macro_name == "FGX2_ABS_OFFSET":
            if len(args) < 3:
                die(f"{path}: FGX2_ABS_OFFSET at {addr:#06x} expects "
                    f"3 args (tag;name;tgt_seg), got {args}")
            name = args[1]
            try:
                tgt = int(args[2], 0)
            except ValueError:
                die(f"{path}: FGX2_ABS_OFFSET at {addr:#06x}: tgt_seg "
                    f"'{args[2]}' not an integer")
            if not (0 <= tgt < n_segs):
                die(f"{path}: FGX2_ABS_OFFSET at {addr:#06x}: tgt_seg "
                    f"{tgt} out of range 0..{n_segs - 1}")
            absoff.append((addr, name, tgt))
            continue

        desc = RELOC_MACROS.get(macro_name)
        if desc is None:
            continue
        tgt_arg = desc["tgt_arg"]
        if tgt_arg >= len(args):
            die(f"{path}: macro '{macro_name}' missing target_seg arg "
                f"(args: {args})")
        try:
            tgt = int(args[tgt_arg], 0)
        except ValueError:
            die(f"{path}: macro '{macro_name}' target_seg '{args[tgt_arg]}' "
                f"not an integer")
        if not (0 <= tgt < n_segs):
            die(f"{path}: macro '{macro_name}' target_seg {tgt} "
                f"out of range 0..{n_segs - 1}")
        relocs.append((addr + desc["delta"], desc["kind"], tgt))

    # P3-5 I3 count gate (per-listing, self-contained): every file that
    # DECLARED a count must have had exactly that many rows recognized.
    # A shortfall = the parser silently dropped a row (an unpatched $00
    # placeholder would ship); an excess = duplicated PUT or a stale
    # trailer.  Hard error in both directions, any output format.
    for f in sorted(declared):
        got = rowcount.get(f, 0)
        if got != declared[f]:
            if got < declared[f]:
                why = ("a listing row was silently skipped (an unpatched "
                       "$00 placeholder would ship)")
            else:
                why = "duplicate PUT or stale FGX2_RELOC_COUNT trailer"
            die(f"{path}: RELOC_COUNT gate: source file '{f}' declares "
                f"{declared[f]} FGX2_* rows but {got} were recognized — {why}")

    return {"relocs": relocs, "exports": exports, "imports": imports,
            "longptr": longptr, "dataptr": dataptr,
            "absoff": absoff, "farcalls": farcalls,
            "modes": modes, "modefiles": modefiles, "declared": declared}


def resolve_precedence(found, segs, name, addr, seg_i, macro):
    """Resolution for a globally-searched import (FGX2_FARCALL /
    FGX2_LONG_PTR).  `found` is [(seg, off), ...] -- every segment exporting
    `name`.  Exactly one definer binds; two or more is a duplicate-symbol
    error."""
    if len(found) > 1:
        where = ", ".join(str(seg) for seg, _ in found)
        die(f"segment {seg_i} {macro} at {addr:#06x}: symbol '{name}' "
            f"defined by multiple segments ({where})")
    return found[0]


# A library (libc.so, shared libc SP2 spec section 3): header flags bit 1
# says a trailer follows the relocs -- export table, its checksum, the
# member-block table and the per-process fixups.  Keep the layout in step
# with read_trailer.
LIB_FLAG = 0x02
LIB_MAGIC = b"FGXL"


def split_fixups(relocs, core, tmpl):
    """A reloc from the core template into itself becomes a fixup: the core
    is copied into every process's data bank, so its bank is the process's.
    A pointer into a block template from code or from a template, or from a
    template into the core, is refused: what it means to reach is a
    per-process block, and no reloc can hold that.  The core's block table
    points into the templates, which are read-only and the same in every
    process, so that pointer is an ordinary reloc."""
    kept, fixups = [], []
    for src, off, tgt, prov in relocs:
        if tgt == tmpl and src != core:
            die(f"library: segment {src} offset {off:#06x} points into a "
                f"block template ({prov}); only the core's block table may")
        if src == tmpl and tgt == core:
            die(f"library: block template offset {off:#06x} points into the "
                f"core ({prov}); the core's bank is per-process")
        if src == core and tgt == core:
            fixups.append(off)
        else:
            kept.append((src, off, tgt, prov))
    return kept, sorted(fixups)


def read_names(path):
    """The names in a list file: one per line, `#' starts a comment."""
    out = []
    for line in open(path):
        n = line.split("#")[0].strip()
        if n:
            out.append(n)
    return out


def library_exports(segs, exports_by_seg, core_labels, core, prefix,
                    data_names, core_end=None, blk_prefix="_libc_blk_"):
    """(name, kind, segment, value, size) sorted by name: kind 0 is every
    public code export at its segment offset (size 0), kind 1 each of
    `data_names' -- the extern data the library's headers declare -- at its
    core address, sized to the next core label (the last to `core_end').  Statics
    (prefix), block cells and templates are not exported (the block table
    carries the cells), nor is the rest of the core, which is libc's own."""
    def public(n):
        return not (n.startswith(prefix) or n.startswith(blk_prefix)
                    or n.endswith("__BT"))
    out = {}
    for i, s in enumerate(segs):
        if s.get("kind", "CODE") != "CODE":
            continue
        for n, off in exports_by_seg[i].items():
            if public(n):
                if n in out:
                    die(f"library: '{n}' is exported by segments "
                        f"{out[n][2]} and {i}")
                out[n] = (n, 0, i, off, 0)
    addr_of = {n: a for a, n in core_labels}
    starts = sorted({a for a, _n in core_labels})
    def size_of(a):
        later = [x for x in starts if x > a]
        end = later[0] if later else core_end
        return end - a if end is not None else 0
    for n in data_names:
        if n not in addr_of:
            die(f"library: data export '{n}' is not in the core")
        if n in out:
            die(f"library: '{n}' names both code and core data")
        out[n] = (n, 1, core, addr_of[n], size_of(addr_of[n]))
    return [out[n] for n in sorted(out)]


def block_table(members, cells, tmpl_exports, tmpl_len, blk_prefix="_libc_blk_"):
    """(cell address, template offset, size) per member, in name order.
    The templates lie back to back, so each one's listed size is the gap to
    the next, which must equal the blocks file's size."""
    rows = []
    for m in sorted(members):
        cell = cells.get(blk_prefix + m)
        t = tmpl_exports.get(m + "__BT")
        if cell is None or t is None:
            die(f"library: member {m} has no block cell or template "
                f"(cell {cell}, template {t})")
        rows.append((m, cell, t, members[m]["size"]))
    by_off = sorted(rows, key=lambda r: r[2])
    for i, (m, _c, t, size) in enumerate(by_off):
        end = by_off[i + 1][2] if i + 1 < len(by_off) else tmpl_len
        if end - t != size:
            die(f"library: member {m}'s template is {end - t} bytes in the "
                f"listing but {size} in the blocks file (stale blocks file?)")
    return [(c, t, sz) for _m, c, t, sz in rows]


def check_core_list(path, core_names, prefix):
    """Every name core.list gives must be defined in the core."""
    for n in read_names(path):
        if n not in core_names and prefix + n not in core_names:
            die(f"library: {path} names '{n}', which no libc member defines "
                f"in the core")


TRAILER_VERSION = 2
TRAILER_HEAD = "<4sBBBBBHHI"


def block(tag, payload):
    """One tagged, length-prefixed trailer block."""
    return tag + struct.pack("<I", len(payload)) + payload


def library_trailer(version, core, tmpl, core_base, core_size, exports,
                    blocks, fixups, extra=b""):
    """The FGXL trailer, version 2: a fixed head, then tagged blocks a
    reader skips when it does not know them -- EXPT (exports, with each
    data export's size), BLKS (member blocks), FIXS (per-process fixups),
    and `extra', blocks already tagged (IMPS, CSIT).  The CRC is over the
    EXPT payload only: it names the export table."""
    rec = b""
    for n, kind, seg, val, size in exports:
        b = n.encode("ascii")
        if len(b) > 255:
            die(f"library: export name '{n}' is over 255 bytes")
        rec += bytes([len(b)]) + b + struct.pack("<BBHH", kind, seg, val, size)
    out = struct.pack(TRAILER_HEAD, LIB_MAGIC, TRAILER_VERSION, version[0],
                      version[1], core, tmpl, core_base, core_size,
                      zlib.crc32(rec))
    out += block(b"EXPT", rec)
    out += block(b"BLKS", b"".join(struct.pack("<HHH", *b) for b in blocks))
    out += block(b"FIXS", b"".join(struct.pack("<H", f) for f in fixups))
    return out + extra


def read_blocks(data, pos):
    """The tagged blocks from `pos' on: {tag: payload}."""
    raw = {}
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4].decode("ascii")
        n = struct.unpack_from("<I", data, pos + 4)[0]
        raw[tag] = data[pos + 8:pos + 8 + n]
        pos += 8 + n
    return raw


# A dynamic program (shared libc SP3 spec, section 3): header flags bit 2
# says a trailer follows the relocs -- FGXD, a version byte, then tagged
# blocks as a library's: IMPS, the libraries it needs with their bitmaps,
# its imports and their sites.
DYN_FLAG = 0x04
DYN_MAGIC = b"FGXD"
DYN_VERSION = 1


def dyn_trailer(extra):
    return DYN_MAGIC + bytes([DYN_VERSION]) + extra


def read_dyn_trailer(data):
    if data[:4] != DYN_MAGIC:
        raise ValueError("no dynamic trailer")
    if data[4] != DYN_VERSION:
        raise ValueError(f"dynamic trailer version {data[4]}; this reader "
                         f"knows {DYN_VERSION}")
    return {"version": DYN_VERSION, "blocks_raw": read_blocks(data, 5)}


def read_trailer(data):
    if data[:4] != LIB_MAGIC:
        raise ValueError("no library trailer")
    if data[4] != TRAILER_VERSION:
        raise ValueError(f"library trailer version {data[4]}; this reader "
                         f"knows {TRAILER_VERSION}")
    (_m, _v, major, minor, core, tmpl, base, size,
     ck) = struct.unpack_from(TRAILER_HEAD, data, 0)
    raw = read_blocks(data, struct.calcsize(TRAILER_HEAD))
    rec, exports, p = raw.get("EXPT", b""), [], 0
    while p < len(rec):
        n = rec[p]
        name = rec[p + 1:p + 1 + n].decode("ascii")
        kind, seg, val, sz = struct.unpack_from("<BBHH", rec, p + 1 + n)
        exports.append((name, kind, seg, val, sz))
        p += 1 + n + 6
    bl = raw.get("BLKS", b"")
    fx = raw.get("FIXS", b"")
    return {"version": TRAILER_VERSION, "major": major, "minor": minor,
            "core": core, "templates": tmpl, "core_base": base,
            "core_size": size, "checksum": ck, "crc": zlib.crc32(rec),
            "exports": exports,
            "blocks": [struct.unpack_from("<HHH", bl, 6 * i)
                       for i in range(len(bl) // 6)],
            "fixups": [struct.unpack_from("<H", fx, 2 * i)[0]
                       for i in range(len(fx) // 2)],
            "blocks_raw": raw}


def main():
    ap = argparse.ArgumentParser(description="FGX2 linker driver")
    ap.add_argument("manifest", help="path to JSON manifest")
    ap.add_argument("-o", "--output", help="override output path")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    manifest_dir = os.path.dirname(os.path.abspath(args.manifest))
    try:
        with open(args.manifest) as f:
            m = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        die(f"cannot read manifest {args.manifest}: {e}")

    out_name = m.get("output")
    if not out_name:
        die("manifest missing 'output' field")
    out_path = args.output or os.path.join(manifest_dir, out_name)

    segs = m.get("segments")
    if not segs:
        die("manifest missing 'segments' or empty")
    n_segs = len(segs)
    if n_segs > MAX_SEGS:
        die(f"too many segments ({n_segs}); FGX2 cap is {MAX_SEGS}")
    for i, s in enumerate(segs):
        if s.get("kind", "CODE") not in KIND_MAP:
            die(f"segment {i} unknown kind '{s.get('kind')}'")

    n_data = m.get("n_data_segment", 0)
    if not (0 <= n_data < n_segs):
        die(f"n_data_segment ({n_data}) out of range 0..{n_segs - 1}")
    entry = m.get("entry_offset", 0)
    flags = m.get("flags", 0)

    # P3-5 I1: output format.  FGX3 = FGX2 layout + magic 'FGX3' + the
    # mandatory ABI stamp at byte 13; FGX2 output stays byte-identical to
    # pre-I1 builds (byte 13 = 0).  No abi_version override exists on
    # purpose — the only supported stamp is FGX_ABI_CURRENT (a linker that
    # can mint stale stamps defeats the gate; test fixtures byte-patch).
    fmt = m.get("format", "FGX2")
    if fmt not in ("FGX2", "FGX3"):
        die(f"unknown format '{fmt}' (FGX2 | FGX3)")

    # P3-3 3.2: size the bank-0 hardware stack from the fcc frame call graph.
    # `stack_frames` lists the program's fcc code .s output(s) (manifest-
    # relative; all TUs of a multi-bank program together).  Absent -> hint 0 =
    # loader default (hand-asm/unmeasured programs are unchanged).
    stack_frames = m.get("stack_frames", [])
    stack_pad = m.get("stack_pad", stack_measure.DEFAULT_PAD)
    stk_pages, stk_info = 0, None
    soft_banks = 0
    if stack_frames:
        paths = [os.path.join(manifest_dir, p) for p in stack_frames]
        missing = [p for p in paths if not os.path.exists(p)]
        if missing:
            die(f"stack_frames source(s) not found: {missing}")
        stk_pages, stk_info = stack_measure.stack_pages(
            paths, pad=stack_pad, max_pages=MAX_STACK_PAGES)
        for p_ in paths:
            if SOFTSIZE_RE.search(open(p_, errors="replace").read()):
                soft_banks = 1
                break
        for cyc in stk_info["unguarded_cycles"]:
            # A cycle in which NO member carries STKGUARD overruns SILENTLY.
            # One where any member is guarded traps loudly on that member, so
            # it is NOT reported: until 2026-07-28 this warned on every cycle
            # cut-point lacking a direct self-edge, which on tcsh named 16
            # functions of which 15 sat in guarded cycles -- the noise buried
            # the single real one.  A reported cycle may still be bounded by
            # DATA FLOW (a reentrancy flag), which no call-graph analysis can
            # see; read the source before calling it a defect.
            sys.stderr.write(
                f"fgx_ld: WARNING: {out_name}: UNGUARDED recursion cycle "
                f"{cyc}: no member carries the prologue stack guard, so an "
                f"unbounded turn overruns the stack silently\n")
        if stk_info["clamped"]:
            # Deepest path exceeds the page cap: the sized stack is a floor,
            # not a fit.  Only the fcc prologue overflow guard keeps this from
            # silently corrupting bank 0 — surface it, don't fail the link.
            # Report TOTAL and its composition, not worst+pad: the clamp tests
            # `total`, so printing worst+pad made the warning look like
            # arithmetic nonsense whenever the cycle reserve was what pushed it
            # over (tcsh: worst+pad = 12706 B fits 56 pages, total = 21194 B
            # does not).
            sys.stderr.write(
                f"fgx_ld: WARNING: {out_name}: stack model wants "
                f"{stk_info['total']} B (worst path {stk_info['worst']} + pad "
                f"{stk_info['pad']} + cycle reserve {stk_info['cycle_extra']})"
                f" = {(stk_info['total'] + 255) // 256} pages; clamped to the "
                f"{MAX_STACK_PAGES}-page cap (needs TASK_STACK_MAX_PAGES "
                f"raised or heap-boxing)\n")
    # The floor, for measured and unmeasured binaries alike: MIN_STACK_PAGES.
    if stk_pages < MIN_STACK_PAGES:
        stk_pages = MIN_STACK_PAGES

    seg_data = []
    for i, s in enumerate(segs):
        bin_rel = s.get("bin")
        if not bin_rel:
            die(f"segment {i} missing 'bin' field")
        bin_path = os.path.join(manifest_dir, bin_rel)
        try:
            with open(bin_path, "rb") as f:
                data = f.read()
        except OSError as e:
            die(f"cannot read segment {i} bin '{bin_path}': {e}")
        if len(data) > 0xFFFF:
            die(f"segment {i} too large ({len(data)} > 65535)")
        if len(data) == 0:
            die(f"segment {i} empty")
        # bytearray so name-resolution can patch operand bytes in place.
        seg_data.append(bytearray(data))

    # Pass 1: scan every segment's listing.  Collect literal-form relocs,
    # exports, and pending imports.  Exports must be gathered globally
    # before resolution, so a separate emission loop runs below.
    scans = []
    for i, s in enumerate(segs):
        scan = {"relocs": [], "exports": {}, "imports": [], "longptr": [],
                "dataptr": [], "absoff": [], "farcalls": [], "modes": [],
                "modefiles": set(), "declared": {}}
        if s.get("listing"):
            listing_path = os.path.join(manifest_dir, s["listing"])
            scan = scan_listing(listing_path, n_segs, org=s.get("org", 0))
        scans.append(scan)
    exports_by_seg = [s["exports"] for s in scans]

    # P3-5 I2: link-time toolchain-contract gate (Layer2Gate).  Every
    # FGX2_MODE stamp in every listing must equal FGX_ABI_CURRENT — a
    # mismatch means a stale pre-flip .s (regenerated-golden or build
    # artifact) is staged into this link; FAIL THE LINK, not the runtime.
    # FGX3 output is additionally fail-CLOSED: every segment must carry a
    # listing with >=1 stamp (an unstamped object can't prove its contract,
    # and byte 13 of the header is DERIVED from this verified agreement).
    for i, s in enumerate(segs):
        for addr, val in scans[i]["modes"]:
            if val != FGX_ABI_CURRENT:
                die(f"MODE gate: segment {i} listing '{s.get('listing')}' "
                    f"carries contract stamp {val} at {addr:#06x}, but this "
                    f"linker expects {FGX_ABI_CURRENT} — a stale pre-flip .s "
                    f"is staged into this link (regenerate it with the "
                    f"current fcc)")
        if fmt == "FGX3":
            if not s.get("listing"):
                die(f"MODE gate: FGX3 output requires a listing for every "
                    f"segment, but segment {i} has none (an unstamped "
                    f"object cannot prove its toolchain contract)")
            if not scans[i]["modes"]:
                die(f"MODE gate: FGX3 output requires >=1 FGX2_MODE stamp "
                    f"in segment {i} listing '{s.get('listing')}', found "
                    f"none — stale pre-stamp .s, or a hand-asm segment "
                    f"missing its stamp")
            # P3-5 I3: an fcc TU (identified by its MODE stamp) must also
            # declare its FGX2_RELOC_COUNT — a MODE-without-COUNT file is
            # a stale pre-I3 .s, or its COUNT row itself was silently
            # skipped; either way the fail-closed transport is broken for
            # that file, so fail the link.
            missing = sorted(scans[i]["modefiles"] -
                             set(scans[i]["declared"]))
            if missing:
                die(f"RELOC_COUNT gate: FGX3 output requires every "
                    f"fcc-generated file to declare FGX2_RELOC_COUNT, but "
                    f"segment {i} listing '{s.get('listing')}' has MODE-"
                    f"stamped file(s) with no declaration: {missing} — "
                    f"stale pre-I3 .s (regenerate with the current fcc)")

    # A library above libc, or a dynamic program, binds a name no segment
    # defines to an export of a library below it (shared libc SP3 spec, section 3): the operand gets the
    # prebound offset, the bank is the binder's (no reloc), and the site goes
    # in the trailer's IMPS block.
    resolver = None
    if m.get("imports"):
        import fgx_imports
        own = set()
        lib_m = m.get("library")
        if lib_m and segs[lib_m["core"]].get("listing"):
            own = {n for _a, n in gen_seg1_layout.extract_labels(os.path.join(
                manifest_dir, segs[lib_m["core"]]["listing"]))}
        resolver = fgx_imports.Resolver(
            [(os.path.join(manifest_dir, so), os.path.join(manifest_dir, lst))
             for so, lst in m["imports"]], own)

    def bind_import(name, i, addr, mac, site, at):
        """True when `name' is a lower library's code export: patch the
        prebound offset at `at' and record the site; dies on a private cell."""
        if resolver is None:
            return False
        r = resolver.code(name)
        if r is None:
            owner = resolver.private(name)
            if owner:
                die(f"segment {i} {mac} at {addr:#06x}: {name} is {owner}'s "
                    f"private cell; a library may import only exports")
            return False
        seg_data[i][at] = r[3] & 0xFF
        seg_data[i][at + 1] = (r[3] >> 8) & 0xFF
        resolver.use(0, name, site, i, at)
        return True

    # Pass 2: emit relocs in per-segment scan order so the output reloc
    # table is byte-equivalent to slice-4.2 builds whenever every literal
    # FGX2_XREF_JSL_BANK migrates to FGX2_IMPORT_JSL one-for-one.
    relocs = []
    offrels = []                 # (src, offset, 0x80 | tgt): FGX2_RELOC_OFFSET
    placeable = {i for i, s in enumerate(segs) if s.get("offsets") is not None}

    def offrel(src, word, tgt):
        if tgt in placeable:
            offrels.append((src, word, 0x80 | tgt, "offset"))

    for i in sorted(placeable):
        for off in segs[i]["offsets"]:
            if not (0 <= off and off + 1 < len(seg_data[i])):
                die(f"segment {i} offset site {off} out of segment size "
                    f"{len(seg_data[i])}")
            offrels.append((i, off, 0x80 | i, "offset"))
    auto_counts = []
    import_counts = []
    export_counts = []
    for i, s in enumerate(segs):
        scan = scans[i]
        auto_counts.append(len(scan["relocs"]))
        export_counts.append(len(scan["exports"]))
        import_counts.append(len(scan["imports"]))
        for offset, kind, tgt in scan["relocs"]:
            if not (0 <= offset < len(seg_data[i])):
                die(f"segment {i} auto-derived xref offset {offset} "
                    f"out of segment size {len(seg_data[i])}")
            prov = "xref_jsl" if kind == "jsl_bank" else "callee_enter"
            if kind == "jsl_bank" and tgt in placeable:
                die(f"segment {i} FGX2_XREF_JSL_BANK at {offset - 3:#06x}: a "
                    f"literal offset into segment {tgt}, which may load at a "
                    f"page offset, cannot be relocated; use FGX2_IMPORT_JSL")
            relocs.append((i, offset, tgt, prov))

        # Resolve named imports against the per-segment exports table.
        for addr, name, tgt in scan["imports"]:
            if name not in exports_by_seg[tgt]:
                exported = sorted(exports_by_seg[tgt].keys())
                die(f"segment {i} FGX2_IMPORT_JSL at {addr:#06x}: "
                    f"unresolved symbol '{name}' in segment {tgt} "
                    f"(exports: {exported or 'none'})")
            tgt_off = exports_by_seg[tgt][name] + segs[tgt].get("org", 0)
            if not (0 <= tgt_off <= 0xFFFF):
                die(f"segment {i} FGX2_IMPORT_JSL '{name}' resolved "
                    f"offset {tgt_off} out of 16-bit range")
            if not (0 <= addr + 3 < len(seg_data[i])):
                die(f"segment {i} FGX2_IMPORT_JSL at {addr:#06x} extends "
                    f"past segment end {len(seg_data[i])}")
            # JSL operand: addr+1 = LL, addr+2 = HH, addr+3 = BB.
            seg_data[i][addr + 1] = tgt_off & 0xFF
            seg_data[i][addr + 2] = (tgt_off >> 8) & 0xFF
            relocs.append((i, addr + 3, tgt, "import_jsl"))
            offrel(i, addr + 1, tgt)

        # Slice 4.5: resolve FGX2_LONG_PTR imports.  Layout differs from
        # JSL: addr+0=LL, addr+1=HH, addr+2=BB, addr+3=pad.
        #
        # Resolved GLOBALLY (search every segment's exports), like FGX2_FARCALL.
        # The macro's emitted tgt field is a stale compile-time guess: under
        # --far-calls the string pool moved to the data segment, but fcc still
        # emits ';0'.  String-pool labels (_<tu>_S<n>) are TU-prefixed and thus
        # globally unique, so the search is unambiguous; the bank reloc targets
        # whichever segment actually defines the symbol.
        for addr, name, tgt in scan["longptr"]:
            found = [(seg, exports_by_seg[seg][name])
                     for seg in range(n_segs) if name in exports_by_seg[seg]]
            if not found and bind_import(name, i, addr, "FGX2_LONG_PTR",
                                         "ptr", addr):
                continue
            if not found:
                die(f"segment {i} FGX2_LONG_PTR at {addr:#06x}: unresolved "
                    f"symbol '{name}' in any segment")
            rseg, tgt_off = resolve_precedence(
                found, segs, name, addr, i, "FGX2_LONG_PTR")
            tgt_off += segs[rseg].get("org", 0)
            if not (0 <= tgt_off <= 0xFFFF):
                die(f"segment {i} FGX2_LONG_PTR '{name}' resolved "
                    f"offset {tgt_off} out of 16-bit range")
            if not (0 <= addr + 3 < len(seg_data[i])):
                die(f"segment {i} FGX2_LONG_PTR at {addr:#06x} extends "
                    f"past segment end {len(seg_data[i])}")
            seg_data[i][addr + 0] = tgt_off & 0xFF
            seg_data[i][addr + 1] = (tgt_off >> 8) & 0xFF
            # addr+2 is the bank byte (data_bank reloc) → defining segment.
            relocs.append((i, addr + 2, rseg, "long_ptr"))
            offrel(i, addr, rseg)

        # T5-C C6: LIBC_DATA_PTR — same-segment far-pointer cell.  The
        # offset was assembly-resolved (no export lookup, no byte patch);
        # only the bank byte at addr+2 gets a reloc, targeting the
        # CONTAINING segment (this one).
        for addr in scan["dataptr"]:
            if not (0 <= addr + 3 < len(seg_data[i])):
                die(f"segment {i} LIBC_DATA_PTR at {addr:#06x} extends "
                    f"past segment end {len(seg_data[i])}")
            relocs.append((i, addr + 2, i, "libc_data_ptr"))

        # Slice 4.5: resolve FGX2_ABS_OFFSET imports.  2-byte form, no
        # reloc needed — bank byte comes from PHK at the deref site.
        for addr, name, tgt in scan["absoff"]:
            if name not in exports_by_seg[tgt]:
                exported = sorted(exports_by_seg[tgt].keys())
                die(f"segment {i} FGX2_ABS_OFFSET at {addr:#06x}: "
                    f"unresolved symbol '{name}' in segment {tgt} "
                    f"(exports: {exported or 'none'})")
            tgt_off = exports_by_seg[tgt][name] + segs[tgt].get("org", 0)
            if not (0 <= tgt_off <= 0xFFFF):
                die(f"segment {i} FGX2_ABS_OFFSET '{name}' resolved "
                    f"offset {tgt_off} out of 16-bit range")
            if not (0 <= addr + 1 < len(seg_data[i])):
                die(f"segment {i} FGX2_ABS_OFFSET at {addr:#06x} extends "
                    f"past segment end {len(seg_data[i])}")
            seg_data[i][addr + 0] = tgt_off & 0xFF
            seg_data[i][addr + 1] = (tgt_off >> 8) & 0xFF
            # No bank reloc -- caller PHKs at deref site.
            offrel(i, addr, tgt)

        # FGX2_FARCALL / FGX2_FARJUMP: cross-bank call (JSL) or jump (JML)
        # resolved GLOBALLY — search every segment's exports for the target
        # name (vs FGX2_IMPORT_JSL's explicit tgt_seg).  Same patch layout as
        # IMPORT_JSL: +1/+2 = offset, +3 = bank reloc.  Errors on unresolved
        # or ambiguous (exported by >1 segment).
        for addr, name, mac in scan["farcalls"]:
            found = [(seg, exports_by_seg[seg][name])
                     for seg in range(n_segs) if name in exports_by_seg[seg]]
            if not found and bind_import(name, i, addr, mac, "call", addr + 1):
                continue
            if not found:
                die(f"segment {i} {mac} at {addr:#06x}: unresolved "
                    f"symbol '{name}' in any segment")
            tgt, tgt_off = resolve_precedence(
                found, segs, name, addr, i, mac)
            tgt_off += segs[tgt].get("org", 0)
            if not (0 <= tgt_off <= 0xFFFF):
                die(f"segment {i} {mac} '{name}' resolved offset "
                    f"{tgt_off} out of 16-bit range")
            if not (0 <= addr + 3 < len(seg_data[i])):
                die(f"segment {i} {mac} at {addr:#06x} extends past "
                    f"segment end {len(seg_data[i])}")
            # JSL/JML operand: addr+1 = LL, addr+2 = HH, addr+3 = BB (reloc).
            seg_data[i][addr + 1] = tgt_off & 0xFF
            seg_data[i][addr + 2] = (tgt_off >> 8) & 0xFF
            relocs.append((i, addr + 3, tgt,
                           "farjump" if mac == "FGX2_FARJUMP" else "farcall"))
            offrel(i, addr + 1, tgt)

        # Manual xrefs from manifest (merged last).
        for j, x in enumerate(s.get("xrefs", [])):
            offset = x.get("offset")
            kind = x.get("kind")
            tgt = x.get("target_seg")
            if offset is None or kind is None or tgt is None:
                die(f"segment {i} xref #{j} missing offset/kind/target_seg")
            if kind not in VALID_XREF_KINDS:
                die(f"segment {i} xref #{j} unknown kind '{kind}'; "
                    f"valid: {sorted(VALID_XREF_KINDS)}")
            if not (0 <= tgt < n_segs):
                die(f"segment {i} xref #{j} target_seg {tgt} out of range")
            if not (0 <= offset < len(seg_data[i])):
                die(f"segment {i} xref #{j} offset {offset} "
                    f"out of segment size {len(seg_data[i])}")
            prov = "manual_jsl" if kind == "jsl_bank" else "manual_data"
            if kind == "jsl_bank" and tgt in placeable:
                die(f"segment {i} xref #{j}: a literal offset into segment "
                    f"{tgt}, which may load at a page offset, cannot be "
                    f"relocated; use FGX2_IMPORT_JSL")
            relocs.append((i, offset, tgt, prov))

    if len(relocs) > MAX_RELOCS:
        die(f"too many relocs ({len(relocs)}); cap is {MAX_RELOCS}")

    # D1 bank-consistency gate: validate every reloc's patch-site shape and
    # target-kind BEFORE emitting anything (fail the link, not the runtime).
    seg_kind_names = [s.get("kind", "CODE") for s in segs]
    bound = set()
    if resolver is not None:
        for im in resolver.imports.values():
            bound |= {(sg, off + 2) for sg, off in im["call"]}
    d1_check(relocs, seg_data, seg_kind_names, n_data, bound)
    relocs += offrels
    if len(relocs) > MAX_RELOCS:
        die(f"too many relocs ({len(relocs)}); cap is {MAX_RELOCS}")

    trailer = b""
    lib = m.get("library")
    if lib:
        core, tmpl = lib["core"], lib["templates"]
        relocs, fixups = split_fixups(relocs, core, tmpl)
        core_labels = gen_seg1_layout.extract_labels(
            os.path.join(manifest_dir, segs[core]["listing"]))
        core_names = {n for _a, n in core_labels}
        prefix = lib["static_prefix"]
        blk_prefix = lib.get("blk_prefix", "_libc_blk_")
        if lib.get("core_list"):
            check_core_list(os.path.join(manifest_dir, lib["core_list"]),
                            core_names, prefix)
        with open(os.path.join(manifest_dir, lib["blocks"])) as f:
            members = json.load(f)["members"]
        for mem, v in members.items():
            for st in v["statics"]:
                if st["name"] in core_names:
                    die(f"library: {st['name']} is in member {mem}'s block "
                        f"and in the core")
        exports = library_exports(
            segs, exports_by_seg, core_labels, core, prefix,
            read_names(os.path.join(manifest_dir, lib["data_exports"])),
            core_end=segs[core].get("org", 0) + len(seg_data[core]),
            blk_prefix=blk_prefix)
        blocks = block_table(members, {n: a for a, n in core_labels},
                             exports_by_seg[tmpl], len(seg_data[tmpl]),
                             blk_prefix)
        extra = b""
        if resolver is not None and resolver.order:
            extra = block(b"IMPS", resolver.pack())
        trailer = library_trailer(lib["version"], core, tmpl,
                                  segs[core].get("org", 0),
                                  len(seg_data[core]), exports, blocks, fixups,
                                  extra)
        flags |= LIB_FLAG
    if m.get("dynamic"):
        if lib:
            die("a library is not a dynamic program")
        if resolver is None:
            die("a dynamic program needs \"imports\": the libraries it binds to")
        trailer = dyn_trailer(block(b"IMPS", resolver.pack()))
        flags |= DYN_FLAG

    out = bytearray()
    out += FGX3_MAGIC if fmt == "FGX3" else FGX2_MAGIC
    out += b'\x00\x00'                                  # reserved
    out += bytes([n_segs])
    out += bytes([n_data])
    out += struct.pack("<H", entry)
    out += bytes([flags])
    out += struct.pack("<H", len(relocs))
    # offset 13 = abi_version (FGX3) / reserved 0 (FGX2), offset 14 =
    # stack-pages hint (STACK_HINT_OFF), offset 15 = soft-frame banks.
    out += bytes([FGX_ABI_CURRENT if fmt == "FGX3" else 0, stk_pages,
                  soft_banks])
    assert len(out) == HEADER_SZ
    assert out[STACK_HINT_OFF] == stk_pages
    assert out[SOFT_BANK_OFF] == soft_banks
    assert out[ABI_OFF] == (FGX_ABI_CURRENT if fmt == "FGX3" else 0)

    for i, s in enumerate(segs):
        size = len(seg_data[i])
        bss = s.get("bss", 0)
        kind_name = s.get("kind", "CODE")
        kind = KIND_MAP[kind_name]
        org = s.get("org", 0)
        if kind_name == "DATA" and org + size + bss > HEAP_LIM:
            die(f"segment {i} (DATA): {size} bytes + {bss} bss at org "
                f"${org:04X} ends at ${org + size + bss:04X}, into the heap "
                f"limit cell at ${HEAP_LIM:04X}; the data segment must end "
                f"at or below it")
        out += struct.pack("<HHBBxx", size, bss, kind,
                           1 if i in placeable else 0)    # FGX2_SEGF_PLACE
    assert len(out) == HEADER_SZ + n_segs * SEGTAB_ENTRY_SZ

    for data in seg_data:
        out += data

    for src, offset, tgt, _prov in relocs:
        out += struct.pack("<BHB", src, offset, tgt)
    out += trailer

    try:
        with open(out_path, "wb") as f:
            f.write(out)
    except OSError as e:
        die(f"cannot write output '{out_path}': {e}")

    if args.verbose:
        print(f"fgx_ld: wrote {out_path} ({fmt})")
        print(f"  {len(out)} bytes total")
        print(f"  {n_segs} segments, n_data={n_data}, entry={entry:#06x}, flags={flags:#04x}")
        if stk_info is not None:
            note = ""
            if stk_info["floored"]:
                note = " (floored: recursion/indirect -> cap + guard)"
            elif stk_info["clamped"]:
                note = " (CLAMPED: exceeds cap)"
            print(f"  stack hint (off {STACK_HINT_OFF}): {stk_pages} page(s), "
                  f"worst path {stk_info['worst']}+{stk_info['pad']} B{note}")
        for i, s in enumerate(segs):
            manual = len(s.get("xrefs", []))
            auto = auto_counts[i]
            exp = export_counts[i]
            imp = import_counts[i]
            print(f"  seg {i}: {len(seg_data[i])} B ({s.get('kind', 'CODE')}), "
                  f"bss={s.get('bss', 0)}, xrefs={auto} auto + {manual} manual, "
                  f"exports={exp}, imports={imp}")
        print(f"  {len(relocs)} total reloc entries")


if __name__ == "__main__":
    main()
