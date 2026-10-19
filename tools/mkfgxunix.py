#!/usr/bin/env python3
"""mkfgxunix.py -- build /fgxunix, the ONE kernel image.

FGX shipped SIX artifacts where 2.11BSD ships one /unix: bin/fgx.bin,
bin/fgxfar.bin, bin/fgxtty.bin, three module files under /lib/modules, and
/etc/preload.conf to name them.  This tool concatenates them into a single
file with a segment table at the front, which is what 2.11BSD's own kernel
image does and has always done.

THE UPSTREAM SHAPE, READ RATHER THAN REMEMBERED.  A 2.11BSD overlaid kernel is
one a.out whose header is followed by `struct ovlhdr' -- `int max_ovl' and
`unsigned int ov_siz[NOVL]', NOVL 15 (usr/sys/h/exec.h:37-41).  The boot
program does NOT store a file offset per overlay: `copyunix' derives each one
by cumulative sum,

    case SEG_OVLY:
        segoff = (off_t) N_TXTOFF(exec);
        segoff += (off_t) exec.a_text;
        for (i = 0; i < ovseg; i++)
            segoff += (off_t) ovlhdr.ov_siz[i];

(examples/2.11BSD/usr/sys/pdpstand/boot.c:416-421), and advances a PHYSICAL
cursor -- `phys += btoc(seglen)' -- so each segment lands in its own region of
memory.  Both properties are kept here: SIZES ONLY in the table, offsets
derived by summing them, and a destination cursor that is a BANK rather than a
click of physical pages.  Storing offsets as well as sizes would be one more
pair of numbers that can disagree.

WHAT A SEGMENT'S DESTINATION IS.  Neither bank is known until the machine
boots -- the Memory Manager assigns them -- so a segment names its bank the
way stage 2 already computes one: a BASE selector plus an offset.

    sel 0   the kernel handle       _LoaderKernBank + bankofs
    sel 1   the rest-of-OS handle   _LoaderRestBase + REST_KMOD_FIRST_OFF + bankofs

SEL 1 IS ALSO WHAT preload.conf's LINE ORDER USED TO SAY.  Stage 2 records
every sel-1 segment's bank in `_PreStaged_Banks', in table order, and main.s
calls Mod_RegisterPreLoaded down that list -- so the order below is
load-bearing exactly as the order in preload.conf was, and for the same
reason: ufs.mod resolves vfs.mod's VT_VFSCORE in its own mod_init and refuses
to run without it, and ufsdir.mod resolves both.

THE FONT IS DELIBERATELY NOT IN HERE.  /lib/fonts/default.fnt is a fourth
load into the far bank and could trivially be a seventh segment, but folding
it in would mean rebuilding the kernel to change a font.  It stays a file.

Layout, little-endian throughout:

    block 0     the header
      +0    'FGXUNIX1'      8 B   magic
      +8    nseg            1 B
      +9    0               1 B   reserved
      +10   segment[nseg]   5 B each:
              +0  sel       1 B   0 = kernel handle, 1 = rest-of-OS kmods
              +1  bankofs   1 B   banks past that base
              +2  dstoff    1 B   destination offset HI byte (lo is $00)
              +3  nblk      2 B   512-byte blocks of payload
      ...zero to 512

    block 1..   the payloads, in table order, each padded to a block boundary

Usage:
    mkfgxunix.py <out>              # from the tree's standard six inputs
    mkfgxunix.py --describe <img>   # read a built image's table back
    mkfgxunix.py --self-test
"""

import os
import re
import struct
import sys

BLKSZ = 512
MAGIC = b"FGXUNIX1"
HDR_FIXED = 10                  # magic + nseg + reserved
SEG_ENT = 5
MAX_SEG = (BLKSZ - HDR_FIXED) // SEG_ENT

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SEL_KERN = 0
SEL_KMOD = 1

# The kernel handle's bank count and the rest-of-OS module window, READ from
# the generated include/config.s (kernel.banks and rest.kmod_banks in
# cfg/system.cfg) -- the source stage2.s and kernel.s alias -- so a table that
# overruns either is refused HERE rather than by a boot that MVNs a segment
# into a bank nobody claimed, and widening either moves this limit with it.
def sel_limits(text):
    """{SEL_KERN: banks, SEL_KMOD: banks} from the text of include/config.s."""
    out = {}
    for sel, name in ((SEL_KERN, "CFG_KERNEL_BANKS"),
                      (SEL_KMOD, "CFG_REST_KMOD_BANKS")):
        m = re.search(r"^\s*%s\s+EQU\s+\$?([0-9A-Fa-f]+)" % name, text, re.M)
        if not m:
            raise MkError("include/config.s: no %s EQU" % name)
        tok = m.group(0).split()[-1]
        out[sel] = int(tok[1:], 16) if tok.startswith("$") else int(tok)
    return out


def _sel_limits():
    with open(os.path.join(REPO, "include", "config.s")) as f:
        return sel_limits(f.read())


SEL_LIMIT = _sel_limits()
SEL_NAME = {SEL_KERN: "kernel", SEL_KMOD: "kmod"}

# THE IMAGE, IN LOAD ORDER.  (path, sel, bankofs, dstoff_hi)
#
# The core loads at FGX_CODE, the page above the task table, and is the one
# segment not at its bank base.  The page is READ from include/kernel.s, not
# copied: the loader trusts this table and cannot notice a kernel linked for
# another page, so a copy here that drifted was a black screen at boot.  The
# other five load at their bank base because their export table is the first
# thing in the image and merlin32 does not pad between ORGs.
def core_dest_hi(text):
    """FGX_CODE's page within its bank, from the text of include/kernel.s."""
    m = re.search(r"^\s*FGX_CODE\s+EQU\s+\$([0-9A-Fa-f]+)", text, re.M)
    if not m:
        raise MkError("include/kernel.s: no FGX_CODE EQU")
    code = int(m.group(1), 16)
    if code & 0xFF:
        raise MkError("FGX_CODE $%06X is not page-aligned; the segment table "
                      "carries a page number" % code)
    return (code >> 8) & 0xFF


def _core_dest_hi():
    with open(os.path.join(REPO, "include", "kernel.s")) as f:
        return core_dest_hi(f.read())


SEGMENTS = [
    ("bin/fgx.bin",                 SEL_KERN, 0, _core_dest_hi()),
    ("bin/fgxfar.bin",              SEL_KERN, 1, 0x00),
    ("bin/fgxtty.bin",              SEL_KERN, 2, 0x00),
    ("disk_src/lib/modules/vfs",    SEL_KMOD, 0, 0x00),
    ("disk_src/lib/modules/ufs",    SEL_KMOD, 1, 0x00),
    ("disk_src/lib/modules/ufsdir", SEL_KMOD, 2, 0x00),
]


class MkError(Exception):
    pass


def nblocks(n):
    return (n + BLKSZ - 1) // BLKSZ


def build(segments):
    """(sel, bankofs, dstoff, payload) list -> the image bytes."""
    if not segments:
        raise MkError("no segments")
    if len(segments) > MAX_SEG:
        raise MkError("%d segments; the header block holds %d"
                      % (len(segments), MAX_SEG))

    seen = set()
    table = b""
    body = b""
    for sel, bankofs, dstoff, payload in segments:
        if sel not in SEL_LIMIT:
            raise MkError("segment selector %d is not 0 or 1" % sel)
        if bankofs >= SEL_LIMIT[sel]:
            raise MkError("%s bank +%d: the %s region is %d bank(s)"
                          % (SEL_NAME[sel], bankofs, SEL_NAME[sel],
                             SEL_LIMIT[sel]))
        if (sel, bankofs) in seen:
            raise MkError("two segments both target %s bank +%d"
                          % (SEL_NAME[sel], bankofs))
        seen.add((sel, bankofs))
        # A segment is MVNed to dstoff:00 and must not run past the bank.  The
        # loader has no way to notice that at boot -- it would wrap into the
        # bottom of the same bank, over code already placed there.
        if (dstoff << 8) + len(payload) > 0x10000:
            raise MkError("%s bank +%d: %d bytes at $%02X00 overruns the bank"
                          % (SEL_NAME[sel], bankofs, len(payload), dstoff))
        nb = nblocks(len(payload))
        table += struct.pack("<BBBH", sel, bankofs, dstoff, nb)
        body += payload + b"\0" * (nb * BLKSZ - len(payload))

    hdr = MAGIC + bytes([len(segments), 0]) + table
    return hdr.ljust(BLKSZ, b"\0") + body


def parse(img):
    """The header block back as a (sel, bankofs, dstoff, nblk, fileblk) list."""
    if len(img) < BLKSZ or img[:8] != MAGIC:
        raise MkError("not an FGXUNIX1 image")
    nseg = img[8]
    if nseg == 0 or nseg > MAX_SEG:
        raise MkError("segment count %d out of range" % nseg)
    out = []
    fileblk = 1
    for i in range(nseg):
        off = HDR_FIXED + i * SEG_ENT
        sel, bankofs, dstoff, nb = struct.unpack("<BBBH", img[off:off + SEG_ENT])
        out.append((sel, bankofs, dstoff, nb, fileblk))
        fileblk += nb
    if fileblk * BLKSZ != len(img):
        raise MkError("table describes %d blocks; the file holds %d"
                      % (fileblk, len(img) // BLKSZ))
    return out


def from_tree():
    segs = []
    for path, sel, bankofs, dstoff in SEGMENTS:
        full = os.path.join(REPO, path)
        try:
            with open(full, "rb") as f:
                payload = f.read()
        except IOError as e:
            raise MkError("%s: %s" % (path, e))
        if not payload:
            raise MkError("%s is empty" % path)
        segs.append((sel, bankofs, dstoff, payload))
    return segs


def describe(path):
    with open(path, "rb") as f:
        img = f.read()
    print("%s: %d bytes, %d blocks" % (path, len(img), len(img) // BLKSZ))
    for i, (sel, bankofs, dstoff, nb, fb) in enumerate(parse(img)):
        print("  seg %d  %-6s +%d  -> $%02X00  %4d blk  file blk %4d%s"
              % (i, SEL_NAME[sel], bankofs, dstoff, nb, fb,
                 "  (pre-staged)" if sel == SEL_KMOD else ""))


def self_test():
    cases = 0

    def check(what, cond):
        if not cond:
            print("  SELFTEST FAIL: " + what)
            sys.exit(1)

    # Round trip: sizes only in the table, offsets derived by summing them.
    segs = [(SEL_KERN, 0, 0x0B, b"A" * 600),
            (SEL_KERN, 1, 0x00, b"B" * 512),
            (SEL_KMOD, 0, 0x00, b"C" * 1)]
    img = build(segs)
    got = parse(img)
    check("block count", len(img) == (1 + 2 + 1 + 1) * BLKSZ)
    check("derived offsets", [g[4] for g in got] == [1, 3, 4])
    check("payload 0 placed", img[BLKSZ:BLKSZ + 600] == b"A" * 600)
    check("payload 0 padded", img[BLKSZ + 600:3 * BLKSZ] == b"\0" * (1024 - 600))
    check("payload 1 placed", img[3 * BLKSZ:3 * BLKSZ + 512] == b"B" * 512)
    check("payload 2 placed", img[4 * BLKSZ] == ord("C"))
    cases += 1

    # A short payload still occupies a whole block, so the next segment starts
    # on a block boundary -- which is the property the loader's block-indexed
    # reader depends on and cannot check for itself.
    check("one byte is one block", parse(build([(SEL_KERN, 0, 0, b"x")]))[0][3] == 1)
    cases += 1

    # The core's page comes from kernel.s's text, and only a page-aligned
    # FGX_CODE can be carried by a table that holds one byte of offset.
    check("bank limits parsed from config.s",
          sel_limits("CFG_KERNEL_BANKS     EQU     3\n"
                     "CFG_REST_KMOD_BANKS  EQU     4\n") == {SEL_KERN: 3, SEL_KMOD: 4})
    check("the live limits come from config.s",
          SEL_LIMIT == _sel_limits() and SEL_LIMIT[SEL_KMOD] >= 1)
    check("core page parsed",
          core_dest_hi("FGX_CODE        EQU     $020C00   ; x\n") == 0x0C)
    for what, text in [("no FGX_CODE", "FGX_DATA EQU $02ED70\n"),
                       ("unaligned FGX_CODE", "FGX_CODE EQU $020C80\n")]:
        try:
            core_dest_hi(text)
        except MkError:
            cases += 1
        else:
            check(what + " accepted", False)

    for what, segs in [
        ("bank overrun", [(SEL_KERN, 0, 0xFF, b"z" * 512)]),
        ("bank past the kernel handle", [(SEL_KERN, 3, 0, b"z")]),
        ("bank past the kmod region", [(SEL_KMOD, 4, 0, b"z")]),
        ("duplicate destination", [(SEL_KERN, 0, 0, b"z"), (SEL_KERN, 0, 0, b"z")]),
        ("bad selector", [(2, 0, 0, b"z")]),
        ("no segments", []),
        ("too many segments", [(SEL_KERN, 0, 0, b"z")] * (MAX_SEG + 1)),
    ]:
        try:
            build(segs)
        except MkError:
            cases += 1
        else:
            check(what + " accepted", False)

    for what, img in [
        ("bad magic", b"x" * BLKSZ),
        ("short file", b""),
        ("truncated payload", build([(SEL_KERN, 0, 0, b"z" * 512)])[:-1]),
        ("zero segments", (MAGIC + bytes([0, 0])).ljust(BLKSZ, b"\0")),
    ]:
        try:
            parse(img)
        except MkError:
            cases += 1
        else:
            check(what + " accepted", False)

    # THE POSITIVE CONTROL ON THE REAL TABLE, not on the encoder: the tree's
    # own six segments must describe a legal image.  A SEGMENTS list that has
    # rotted past a bank boundary is otherwise a black screen at boot.
    try:
        real = build(from_tree())
    except MkError as e:
        print("  SELFTEST FAIL: the tree's own segments do not build: %s" % e)
        sys.exit(1)
    check("real image parses", len(parse(real)) == len(SEGMENTS))
    cases += 1

    print("mkfgxunix self-test: OK (%d cases)" % cases)


def main(argv):
    if "--self-test" in argv:
        self_test()
        return 0
    if "--describe" in argv:
        describe(argv[argv.index("--describe") + 1])
        return 0
    if len(argv) != 2:
        sys.stderr.write(__doc__)
        return 2
    img = build(from_tree())
    with open(argv[1], "wb") as f:
        f.write(img)
    print("mkfgxunix: %s, %d bytes, %d blocks, %d segments"
          % (argv[1], len(img), len(img) // BLKSZ, len(SEGMENTS)))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except MkError as e:
        sys.stderr.write("mkfgxunix: %s\n" % e)
        sys.exit(1)
