#!/usr/bin/env python3
"""bootstk_chain -- turn the boot stack's low-water MARK into the CHAIN that set it.

bootstk_check.py answers "how much headroom is left".  This answers "whose
frames took it", which is the question a tripped ratchet actually raises.
apple/fgx#391.

WHY A RETURN ADDRESS IS FINDABLE AT ALL.  A JSR pushes the address of its OWN
LAST BYTE and a JSL pushes that plus the program bank, so every call site in a
merlin32 `-V' listing has exactly ONE value it can ever leave on a stack:
`off + size - 1'.  Build that map from the listings and a stack word is a
return address iff it is IN it.  That is a far tighter filter than "resolves to
a symbol", which every address in the bank satisfies: across the four banks a
boot chain crosses, 464 bytes of used stack produced 24 matches and NOT ONE of
them was ambiguous between two banks.

`- 1' IS THE WHOLE OF IT AND A MANUAL DISAGREES, so here is the machine.
"Apple IIgs Assembly Language Programming" p.113 says JSR "pushes the offset of
NEXT onto the stack" -- the following instruction's address, which would make
the value `off + size'.  The kernel listing settles it: at `02/5228' sits
`20 B6 51  JSR _Fs_RootOpen', three bytes, and the next instruction is the
`BCC' at `02/522B'.  What the boot stack holds is `$522A' -- the JSR's last
byte.  The book is describing RTS's effect (it pulls and INCREMENTS) rather
than the push, so do not "correct" this arithmetic to match it.

MODULE RETURN ADDRESSES CARRY A RUNTIME BANK, so the map cannot be built from
the listings alone.  `_modBankTab' (src/kernel/modload.s) holds the allocation
-- seven slots: the shared bank, vfs, ufs, ufsprobe, ufsdir, prodos, prodosw -- and the dump must
carry it, sampled at the SAME boot frame as the slice.  Reading it from a later
frame is wrong in a way that looks right: the shared bank and ufsprobe are $00
until modload runs, so a late read attributes early frames to banks that did
not exist yet.

SAMPLE DURING THE EXCURSION, NOT AFTER IT.  This is the whole of how to use the
tool, and getting it wrong produces exactly the wreckage apple/fgx#391 reports.
Between the mark and the live SP after the chain has unwound is a MIX of stale
frames from different moments; sampled while the chain is LIVE it is one
coherent ladder.  On `main' at 39c770a6b the boot excursion is a single event
ten frames wide -- 416 bytes spare at frame 272, 48 at frame 279 -- and a
sample at 279 decodes; the 700 the bootstk fixture uses does not.  `--ladder'
over a dump full of samples is how the window is found; `--emit-manifest'
writes the manifest that produces one.

TWO SHAPES MASQUERADE AS FRAMES and are named rather than silently dropped:

  REPEATED.  A value appearing more than once in the used region is data.  A
  chain reaches a given call site once; six copies of `swtch_nosave's return is
  a far pointer whose low word collides with it, not six-deep recursion into
  the scheduler.

  FAR-POINTER SHAPE.  fcc stores a far pointer as offset word then bank word,
  so `lo hi bank 00' with a plausible bank byte is a pointer being passed down.
  Its low half collides with a call site often enough to matter.

Neither is a certainty, so both are REPORTED with the reason and excluded from
the chain rather than deleted from the output.

A CALL-GRAPH FILTER WAS TRIED AND DOES NOT WORK HERE, which is worth recording
because it is the obvious next idea.  Keeping only rows whose enclosing symbol
is REACHABLE from the symbol the row above it called cut 25 candidates to 2 --
`_FarSh_Fs_OpenCore -> Fs_Open -> _Fs_RootOpen' and nothing else.  The VFS is
vtable-dispatched, so a static graph cannot cross a `v_op[]' slot, and every
real chain through this code breaks at its first VOP.  The filter does not
separate signal from noise; it deletes the signal.

AND THE MARK IS A LOWER BOUND, WHICH THIS QUANTIFIES.  A pushed word whose
value happens to be $A5A5 is indistinguishable from paint, so the true mark can
be deeper than the scan reports.  That is not hypothetical: this counts the
paint-valued words INSIDE the used region, and on a real boot chain there are
several.  Every one of them is a word that WOULD have hidden the mark had it
sat below it instead of above.

Exit 0 = resolved something, 1 = the dump or the listings are unusable.
Run `--self-test' to check the decode against synthetic listings and a
synthetic stack.
"""
import argparse
import json
import pathlib
import re
import sys
from collections import Counter

from kequ import equ

PAINT = 0xA5A5          # STK_PAINT, src/kernel/task.s
CANARY = 0xC5C5         # every slot's bottom-word seed (main.s)
SLICE = equ("FGX_KSLOT_STK")    # the slot stack size, include/kernel.s
BOOT_BASE = equ("FGX_STK_BOOT")  # the top slot, boot's; --base overrides

# The banks whose code is linked at a FIXED bank, so a listing is enough.
FIXED_BANKS = {0x02: ("kernel", "fgx_S01_KernelMain_Output.txt"),
               0x7C: ("far",    "fgxfar_Output.txt"),
               0x7D: ("tty",    "fgxtty_Output.txt")}

# _modBankTab's slots, in order (src/kernel/modload.s: MOD_BANK_MAX = 7).
MOD_SLOTS = ("shared", "vfs", "ufs", "ufsprobe", "ufsdir", "prodos", "prodosw")
MOD_LISTING = {"vfs": "module_vfs_Output.txt", "ufs": "module_ufs_Output.txt",
               "ufsprobe": "module_ufsprobe_Output.txt",
               "ufsdir": "module_ufsdir_Output.txt",
               "prodos": "module_prodos_Output.txt",
               "prodosw": "module_prodosw_Output.txt"}

_ADDR = re.compile(r"([0-9A-Fa-f]{2})/([0-9A-Fa-f]{4})")
_MNEM = re.compile(r"\b([A-Z]{3,5})\b")
_LABEL = re.compile(r"^([@A-Za-z_][A-Za-z0-9_]*)")
# fcc's own labels, which are places inside a function rather than functions:
# `<fn>_L<n>' branch targets, `ozunid_<n>', and the guarded prologue's pair
# `<fn>_stkok' / `<fn>_stkovf' (emit.c:2069-2074).  Letting one become the
# enclosing symbol reports `ufs_bmapx_stkok' where the frame belongs to
# `ufs_bmapx'.
_GENERATED = re.compile(r"^(?:ozunid_\d+|.*_L\d+|.*_stkok|.*_stkovf)$")


class Site:
    __slots__ = ("sym", "srcfile", "text", "kind")

    def __init__(self, sym, srcfile, text, kind):
        self.sym, self.srcfile, self.text, self.kind = sym, srcfile, text, kind


def call_sites(path):
    """pushed value -> Site, for every JSR/JSL in a merlin32 -V listing.

    The pipe-split is seg0map.py's (tools/profile/seg0map.py) and the column
    meanings are documented there; what this adds is cols[5], the SIZE, which
    is what turns a call site into the one value it can push."""
    out, cur = {}, "?"
    with open(path, errors="replace") as fh:
        for line in fh:
            c = line.split("|")
            if len(c) < 8:
                continue
            m = _ADDR.search(c[6])
            if not m:
                continue
            off = int(m.group(2), 16)
            src = c[7].rstrip("\n")
            body = src.lstrip(" ")
            label = None
            if len(src) - len(body) <= 1:
                lm = _LABEL.match(body)
                if lm:
                    label = lm.group(1)
            if (label and c[2].strip() != "Equivalence"
                    and not label.startswith("@")
                    and not _GENERATED.match(label)):
                cur = label
            if c[2].strip() != "Code":
                continue
            rest = body[len(label):] if label else body
            mm = _MNEM.search(rest)
            if not mm or mm.group(1) not in ("JSR", "JSL"):
                continue
            try:
                size = int(c[5].strip())
            except ValueError:
                continue
            parts = c[1].split()
            out[off + size - 1] = Site(cur, parts[-2] if len(parts) >= 2 else "",
                                       " ".join(rest.split())[:40], mm.group(1))
    return out


def bank_map(dump_mem, build_dir, banks_region):
    """bank byte -> (name, call-site table).

    The fixed banks come from their listings; the module banks need the runtime
    allocation, which only the dump has."""
    out = {}
    for bk, (name, listing) in FIXED_BANKS.items():
        p = build_dir / listing
        if p.is_file():
            out[bk] = (name, call_sites(p))
    r = dump_mem.get(banks_region) if banks_region else None
    if r and r.get("hex"):
        for name, bk in zip(MOD_SLOTS, bytes.fromhex(r["hex"])):
            if bk == 0 or name not in MOD_LISTING:
                continue            # 0 = not allocated at this frame
            p = build_dir / MOD_LISTING[name]
            if p.is_file():
                out[bk] = (name, call_sites(p))
    return out


def scan_mark(b):
    """The lowest word that is no longer paint, or None if the slice is whole.

    bootstk_check.py's scan, repeated here rather than imported: that file is a
    gate checker with its own exit-code contract and importing it for one loop
    would tie a diagnostic's behaviour to a checker's."""
    for i in range(0, len(b) - 1, 2):
        if (b[i] | (b[i + 1] << 8)) != PAINT:
            return i
    return None


def classify(b, mark, banks, bankset):
    """Every candidate frame in the used region, shallowest first.

    Returns (rows, paint_words).  A row is (offset, value, bank byte or None,
    bank name, Site, reason) where reason is "" for a chain frame."""
    cand = []
    for i in range(mark, len(b) - 1):
        v16 = b[i] | (b[i + 1] << 8)
        bk3 = b[i + 2] if i + 2 < len(b) else None
        # A JSL return names its own bank, so match it against that bank alone.
        if bk3 is not None and bk3 in banks:
            site = banks[bk3][1].get(v16)
            if site and site.kind == "JSL":
                cand.append([i, v16, bk3, banks[bk3][0], site, ""])
                continue
        for bk, (name, tbl) in banks.items():
            site = tbl.get(v16)
            if site and site.kind == "JSR":
                cand.append([i, v16, None, name, site, ""])
                break
    counts = Counter(row[1] for row in cand)
    for row in cand:
        why = []
        if counts[row[1]] > 1:
            why.append("repeated x%d" % counts[row[1]])
        i = row[0]
        if (i + 3 < len(b) and b[i + 2] in bankset and b[i + 3] == 0
                and row[2] is None):
            why.append("far-pointer shape")
        row[5] = ", ".join(why)
    paint = sum(1 for i in range(mark, len(b) - 1, 2)
                if (b[i] | (b[i + 1] << 8)) == PAINT)
    return sorted(cand, key=lambda r: -r[0]), paint


def slice_of(region, base, size):
    b = bytes.fromhex(region["hex"])
    # The dump may carry the whole arena; boot's slice is always the last one.
    if len(b) > size:
        off = (len(b) // size - 1) * size
        return b[off:off + size], region.get("addr", base) + off
    return b[:size], region.get("addr", base)


def stack_slices(mem, base, size):
    """The regions that are actually the slice being measured.

    A DUMP CARRIES MANY 512-BYTE REGIONS and none of the others is a stack --
    `shr_palette', `charbuf', `fs_dirbuf' are all this size.  Selecting on
    LENGTH decodes one of them into a confident-looking ladder of frames that
    never ran, which is worse than refusing: the first run of this tool picked
    `shr_palette' and printed twenty `_fcc_fadd' frames.

    So the test is the region's own ADDRESS, which the dump records, AND that
    it holds paint: an unpainted region is not a stack slice this tool can
    reason about, whatever address it sits at."""
    out = {}
    for name, r in mem.items():
        if not r.get("hex"):
            continue
        raw = bytes.fromhex(r["hex"])
        if len(raw) < size:
            continue
        addr = r.get("addr")
        if addr is None or not (addr <= base < addr + len(raw)):
            continue
        b, _ = slice_of(r, base, size)
        if not any((b[i] | (b[i + 1] << 8)) == PAINT
                   for i in range(0, len(b) - 1, 2)):
            continue                # no paint anywhere: not a painted slice
        out[name] = r
    return out


def report(name, b, base, banks, bankset, quiet=False):
    mark = scan_mark(b)
    if mark is None:
        if not quiet:
            print("%s: the whole slice is paint -- nothing has run on it." % name)
        return 1
    if (b[0] | (b[1] << 8)) == CANARY:
        if not quiet:
            print("%s: the slice carries the $C5C5 canary, so it belongs to a "
                  "task and not to boot.  Sample earlier." % name)
        return 1
    rows, paint = classify(b, mark, banks, bankset)
    chain = [r for r in rows if not r[5]]
    print("%s: mark $%04X, %d bytes spare, %d used"
          % (name, base + mark, mark, len(b) - mark))
    if quiet:
        return 0
    print()
    print("  %-7s %-9s %-8s %-28s %-30s %s"
          % ("addr", "return", "bank", "enclosing symbol", "call", "source"))
    for off, v16, bk3, bname, site, why in rows:
        ret = "%02X/%04X" % (bk3, v16) if bk3 is not None else "   %04X" % v16
        line = ("  $%04X  %-9s %-8s %-28s %-30s %s"
                % (base + off, ret, bname, site.sym[:28], site.text[:30],
                   site.srcfile))
        print(line if not why else line.rstrip() + "        [%s]" % why)
    print()
    # A DECODED ROW IS NOT A FRAME, AND THE DENOMINATOR SAYS SO.  Every call
    # site in the loaded banks is one 16-bit value, so a word of stack data
    # matches one by chance with probability sites/65536 -- over a few hundred
    # bytes of used stack that is a good fraction of the rows, not a rounding
    # error.  Printing the expected count beside the observed one is the whole
    # difference between an instrument and a list of plausible-looking symbols.
    #
    # THE JSL ROWS ARE THE TRUSTWORTHY ONES: three bytes must agree, including
    # a bank byte drawn from a handful of live values, so their expected count
    # rounds to nothing.  A JSR row is evidence only in company.
    sites = sum(len(t) for _, t in banks.values())
    used = len(b) - mark
    jsl_rows = [r for r in rows if r[2] is not None]
    jsr_rows = [r for r in rows if r[2] is None]
    expect = used * sites / 65536.0
    print("  %d candidate frame(s): %d JSL (bank byte agrees too) and %d JSR."
          % (len(rows), len(jsl_rows), len(jsr_rows)))
    print("  %d set aside as data by the two shapes above; %d left."
          % (len(rows) - len(chain), len(chain)))
    print("  %d call site(s) are loaded over %d used bytes, so ~%.0f of the %d "
          "JSR row(s)\n  are expected to be COINCIDENCE.  Read the coherent "
          "spine, not the row count." % (sites, used, expect, len(jsr_rows)))
    if chain:
        print("  deepest resolved frame: $%04X in %s (%s)"
              % (base + chain[-1][0], chain[-1][4].sym, chain[-1][3]))
    print("  %d paint-valued word(s) sit INSIDE the used region, so a pushed "
          "word\n  does read as paint: the mark is a lower bound on depth, not "
          "an exact figure." % paint)
    return 0


def ladder(mem, base, size):
    """The mark at every sample, in BOOT-FRAME order.

    This is how the excursion window is found: the interval in which the mark
    moves is the phase of boot that owns it, and the sample at the far end of
    that interval is the one whose chain is still live."""
    slices = stack_slices(mem, base, size)
    if not slices:
        print("no region in the dump covers $%06X." % base)
        return 1
    rows = []
    for name, r in slices.items():
        b, addr = slice_of(r, base, size)
        mark = scan_mark(b)
        rows.append((r.get("sampled_at_frame", -1), name, addr, mark))
    rows.sort(key=lambda t: (t[0], t[1]))
    print("  %-7s %-18s %-8s %-7s %s"
          % ("frame", "region", "mark", "spare", "used"))
    for frame, name, addr, mark in rows:
        fr = str(frame) if frame >= 0 else "dump"
        if mark is None:
            print("  %-7s %-18s %-8s %-7s %s"
                  % (fr, name, "--", "whole", "0  (all paint)"))
        else:
            print("  %-7s %-18s $%04X    %-7d %d"
                  % (fr, name, addr + mark, mark, size - mark))
    return 0


LADDER_FRAMES = (240, 260, 270, 272, 274, 276, 278, 280, 300, 700)


def emit_manifest(path, frames, base, size):
    """Write the probe manifest that produces a dump this tool can read.

    NOT under tools/mame_test/tests/: everything there is discovered and run by
    the gate, and this is a diagnostic for when the ratchet fires, not a test
    that should cost a boot on every pull request."""
    m = {
        "name": "bootstk_chain_probe",
        "description": ("Boot-stack ladder for bootstk_chain.py (apple/fgx#391): "
                        "the slice at a ladder of absolute boot frames, plus "
                        "_modBankTab at each so a module return address can be "
                        "attributed to the bank it actually ran in."),
        "command": "sh",
        "post_commands": ["A=ok", "echo BSTKOK=$A"],
        "post_gap_frames": 300,
        "timeout_s": 400,
        "exit_on_prompt": False,
        "use_state": False,
        "expect": {"screen_contains": ["BSTKOK=ok"], "screen_lacks": ["PANIC"]},
        "memory_regions":
            [{"name": "bstk_f%04d" % f, "addr_hex": "%06X" % base,
              "len": size, "boot_frame": f} for f in frames]
            + [{"name": "modbanks_f%04d" % f, "symbol": "_modBankTab",
                "len": len(MOD_SLOTS), "boot_frame": f} for f in frames],
    }
    pathlib.Path(path).write_text(json.dumps(m, indent=2) + "\n")
    print("wrote %s (%d frames)\n\n  python3 tools/mame_test/run.py --manifest %s\n"
          "  python3 tools/mame_test/bootstk_chain.py --dump "
          "/tmp/fgx_test_bootstk_chain_probe/dump.json --ladder"
          % (path, len(frames), path))
    return 0


def self_test():
    """The decode, and the three ways it can lie.

    A SYNTHETIC LISTING IS THE POINT.  What is being checked is that a call
    site's pushed value is `off + size - 1' and that nothing else in the used
    region is called a frame -- both of which are claims about arithmetic, not
    about any particular boot."""
    import tempfile
    bad = 0
    listing = "\n".join([
        # line | file | type | mx | reloc | size | bank/off | source
        "1|0 src/a.s 1|Code|00||3|02/1000 : 20 00 20|myfunc  JSR     callee",
        "2|0 src/a.s 2|Code|00||4|02/2000 : 22 00 00 02|other   JSL     farthing",
        "3|0 src/a.s 3|Code|00||2|02/3000 : A9 00|third   LDA     #0",
        "4|0 src/a.s 4|Equivalence|00||0|02/4000|SOMEEQU EQU  $1234",
    ])
    with tempfile.TemporaryDirectory() as td:
        p = pathlib.Path(td) / "l.txt"
        p.write_text(listing + "\n")
        sites = call_sites(p)
        checks = [
            ("a 3-byte JSR pushes off+2", 0x1002 in sites),
            ("a 4-byte JSL pushes off+3", 0x2003 in sites),
            ("the JSR is recorded as JSR",
             0x1002 in sites and sites[0x1002].kind == "JSR"),
            ("the JSL is recorded as JSL",
             0x2003 in sites and sites[0x2003].kind == "JSL"),
            ("a non-call Code line is not a site", 0x3001 not in sites),
            ("an EQU is not a site", 0x4000 not in sites),
            ("the enclosing symbol is kept",
             0x1002 in sites and sites[0x1002].sym == "myfunc"),
        ]
        banks = {0x02: ("kernel", sites)}

        # A stack holding: paint, one real JSR return, a far pointer whose low
        # word collides with that same site, and the same collision again.
        def stk(words):
            out = bytearray()
            for w in words:
                out += bytes((w & 0xFF, (w >> 8) & 0xFF))
            return bytes(out)

        b = bytearray(stk([PAINT] * 8))
        b += bytes((0x02, 0x10))                      # $1002 -- a real return
        b += bytes((0x02, 0x10, 0x3C, 0x00))          # far pointer, same low word
        b += bytes((0x02, 0x10, 0x3C, 0x00))          # and again
        b += stk([PAINT])                             # paint INSIDE the used region
        b += bytes((0x03, 0x20, 0x02))                # $2003 in bank $02 -- a JSL
        b = bytes(b)
        mark = scan_mark(b)
        rows, paint = classify(b, mark, banks, {0x3C})
        keep = [r for r in rows if not r[5]]
        repeated = [r for r in rows if "repeated" in r[5]]
        farptr = [r for r in rows if "far-pointer" in r[5]]
        jsl = [r for r in rows if r[2] is not None]
        checks += [
            ("the mark is the first non-paint word", mark == 16),
            ("paint inside the used region is counted", paint == 1),
            ("the JSL return is matched against its own bank", len(jsl) == 1),
            ("a value seen three times is called repeated", len(repeated) == 3),
            ("the far-pointer shape is named", len(farptr) == 2),
            ("only the JSL survives as a chain frame", len(keep) == 1),
            ("rows come back shallowest first",
             all(rows[i][0] > rows[i + 1][0] for i in range(len(rows) - 1))),
        ]

        # THE VACUOUS ARM.  An all-paint slice must not report a mark, or every
        # untouched slice reads as a chain of depth zero.
        checks.append(("an all-paint slice has no mark",
                       scan_mark(stk([PAINT] * 16)) is None))
        # AND A SLICE THAT IS NOT BOOT'S must be refused, not decoded.
        canary = stk([CANARY] + [PAINT] * 15)
        checks.append(("a canaried slice is refused",
                       report("t", canary, 0xF800, banks, set(), quiet=True) == 1))

        for name, ok in checks:
            print("  %s %s" % ("ok  " if ok else "WRONG", name))
            bad += 0 if ok else 1
    if bad:
        print("bootstk_chain: SELF-TEST FAILED (%d)" % bad)
        return 1
    print("bootstk_chain: self-test clean (%d cases)" % len(checks))
    return 0


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dump", default="dump.json")
    ap.add_argument("--region", help="slice region to decode (default: the "
                                     "deepest one in the dump)")
    ap.add_argument("--banks", help="region holding _modBankTab (default: the "
                                    "one matching the chosen slice's frame)")
    ap.add_argument("--build", default="build", help="directory of merlin32 "
                                                     "-V listings")
    ap.add_argument("--base", default="%06X" % BOOT_BASE,
                    help="hex address the region starts at")
    ap.add_argument("--ladder", action="store_true",
                    help="print the mark for every slice region and stop")
    ap.add_argument("--emit-manifest", metavar="PATH",
                    help="write the probe manifest that produces such a dump")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)

    base = int(args.base, 16)
    if args.self_test:
        return self_test()
    if args.emit_manifest:
        return emit_manifest(args.emit_manifest, LADDER_FRAMES, base, SLICE)

    dp = pathlib.Path(args.dump)
    if not dp.is_file():
        print("bootstk_chain: %s does not exist.  Produce one with\n"
              "  python3 tools/mame_test/bootstk_chain.py --emit-manifest "
              "<path>\nthen run it through tools/mame_test/run.py --manifest."
              % dp, file=sys.stderr)
        return 1
    mem = (json.loads(dp.read_text()).get("memory") or {})
    if not mem:
        print("bootstk_chain: the dump carries no memory regions.",
              file=sys.stderr)
        return 1
    if args.ladder:
        return ladder(mem, base, SLICE)

    slices = stack_slices(mem, base, SLICE)
    if not slices:
        print("bootstk_chain: no painted region in %s covers $%06X.  The "
              "manifest must ask\nfor that address with a boot_frame -- see "
              "--emit-manifest." % (dp, base), file=sys.stderr)
        return 1
    if args.region:
        if args.region not in slices:
            print("bootstk_chain: %r is not a painted slice covering $%06X; "
                  "the dump has %s"
                  % (args.region, base, ", ".join(sorted(slices))),
                  file=sys.stderr)
            return 1
        name = args.region
    else:
        # THE DEEPEST SAMPLE IS THE INFORMATIVE ONE, and picking it beats
        # picking the last: a ladder's later frames read the residue of the
        # excursion, and the sample taken while the chain was live is the one
        # that decodes.
        #
        # A DUMP-TIME SAMPLE IS NOT A CANDIDATE.  Regions with no boot_frame
        # (`sampled_at_frame' -1) are read after the run, by which point
        # Task_AllocKernStack has handed the slice to pid NPROC and repainted
        # it -- so it reads as 512 bytes used and wins a "deepest" contest it
        # has no business entering.  Same for anything carrying the canary.
        def depth(n):
            b, _ = slice_of(slices[n], base, SLICE)
            if (b[0] | (b[1] << 8)) == CANARY:
                return -1
            m = scan_mark(b)
            return SLICE - m if m is not None else -1
        live = {n: r for n, r in slices.items()
                if r.get("sampled_at_frame", -1) >= 0 and depth(n) >= 0}
        pool = live or slices
        name = max(pool, key=depth)
        if not live:
            print("NOTE: no sample carries a boot_frame, so this is a dump-time "
                  "read -- by then\n  the slice belongs to pid NPROC.  See "
                  "--emit-manifest.\n")
        elif len(pool) > 1:
            print("(deepest of %d boot-frame samples: %s, frame %s -- --region "
                  "picks another)\n"
                  % (len(pool), name, pool[name].get("sampled_at_frame")))

    banks_region = args.banks
    if banks_region is None:
        # PAIR ON THE FRAME, NOT THE NAME.  _modBankTab must be read at the
        # same boot frame as the slice: the shared bank and ufsprobe are $00
        # until modload runs, so a later read attributes early frames to banks
        # that did not exist when they were pushed.
        frame = slices[name].get("sampled_at_frame", -1)
        for cand, r in sorted(mem.items()):
            if (r.get("hex") and len(bytes.fromhex(r["hex"])) == len(MOD_SLOTS)
                    and r.get("sampled_at_frame", -2) == frame):
                banks_region = cand
                break
    build = pathlib.Path(args.build)
    banks = bank_map(mem, build, banks_region)
    if not banks:
        print("bootstk_chain: no listings under %s -- build first." % build,
              file=sys.stderr)
        return 1
    if banks_region is None:
        print("NOTE: the dump carries no _modBankTab region, so module frames "
              "cannot be\n  attributed.  Add {\"symbol\": \"_modBankTab\", "
              "\"len\": 5} at the same boot_frame.\n")
    b, addr = slice_of(slices[name], base, SLICE)
    return report(name, b, addr, banks, set(banks), quiet=False)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
