#!/usr/bin/env python3
"""fgxdsk -- wrap an FGX 2.11BSD volume into a disk image SIMH can attach.

WHY THIS EXISTS.  tools/bsd211vol.py carves a filesystem OUT of a real PDP-11
disk so FGX can mount it; this is the other direction, and it is the second
half of the campaign's goal 2 -- "an FGX volume mounts on a PDP-11/70".  A .po
is the bare filesystem; what SIMH attaches to an RQ controller is a whole
DRIVE, and a 2.11BSD kernel finds its partitions by reading a DISKLABEL off
that drive rather than from a table baked into the driver
(examples/2.11BSD/usr/sys/pdpuba/ra.c reworked them out; the label is what is
left).  Without one the volume is bytes on a disk nothing can name.

WHAT IT WRITES:
    sector 0            the filesystem's own boot block, from the .po
    sector 1            the disklabel this tool builds
    sector 2 onward     the rest of the .po
    ...zero-padded to the drive's d_secperunit

SECTOR 1 IS FREE AND THAT IS NOT LUCK.  A 2.11BSD filesystem puts its
superblock at filesystem block 1, which with FS_BSIZE 1024 is device sectors
2-3, and reserves what is below it for boot -- d_bbsize is 512 and d_sbsize
1024 on the reference disk, which says exactly that.  So the label sector is
inside the filesystem's boot area on a real 2.11BSD disk too: the reference
image `examples/pdp11/2.11BSD_rq.dsk' has its root filesystem at offset 0 AND
a valid label at sector 1, which is what proves the layout rather than
argues for it.

THE GEOMETRY IS THE REFERENCE DRIVE'S, so an image lands on a controller
already configured for that machine.  Fields and the checksum come from
2.11BSD's own sources: struct disklabel (vendor/2.11BSD/usr/sys/h/disklabel.h)
and dkcksum (vendor/2.11BSD/usr/bin/disklabel/disklabel.c:324 -- an XOR of
u_shorts from the label's start through d_partitions[d_npartitions]).

32-BIT FIELDS ARE HIGH WORD FIRST, which is the same PDP-11 long order
tools/fgxfs.py and tools/bsd211vol.py already carry: the long 0x01020304
stores as the bytes 02 01 04 03.  Writing d_secperunit or a partition size
little-endian gives a label that parses to nonsense sizes.
"""

import os
import struct
import sys

SECSIZE = 512

# GEOMETRY COMES FROM 2.11BSD'S OWN /etc/disktab, not from this tool's
# arithmetic.  The RA72 row is the label on examples/pdp11/2.11BSD_rq.dsk; the
# RA92 row is that machine's disktab entry, which reads
#
#   ra92|RA92|DEC RA92:\
#       :dt=MSCP:ty=fixed:ns#69:nt#13:nc#3279:so:\
#       :pc#2940951:oc#0:bc#1024:fc#1024:
#
# THE DRIVE TYPE MUST MATCH THE SIMH `set rqN <type>' or the image is the
# wrong length for the device the emulator presents.  RA92 is the default
# because it is what the reference machine's boot.ini uses for its spare
# spindles; -t ra72 selects the other.
#
# secpercyl is ns*nt and secperunit is the disktab's `c' partition rather than
# ns*nt*nc: 69*13*3279 is 2,941,263, and the drive's usable size is 2,940,951.
# The difference is spares, and taking the product instead would describe a
# disk 312 sectors longer than the one SIMH attaches.
DRIVES = {
    "ra92": {
        "typename":   "RA92",
        "d_type":     2,          # DTYPE_MSCP
        "d_secsize":  512,
        "d_nsectors": 69,
        "d_ntracks":  13,
        "d_ncylinders": 3279,
        "d_secpercyl":  69 * 13,
        "d_secperunit": 2940951,
        "d_rpm":      3600,
        "d_interleave": 1,
    },
    "ra72": {
        "typename":   "RA72",
        "d_type":     2,
        "d_secsize":  512,
        "d_nsectors": 51,
        "d_ntracks":  20,
        "d_ncylinders": 1915,
        "d_secpercyl":  1020,
        "d_secperunit": 1953300,
        "d_rpm":      3600,
        "d_interleave": 1,
    },
}
DRIVE = DRIVES["ra92"]

DISKMAGIC   = 0x82564557
FS_V71K     = 5               # 2.11BSD filesystem, disklabel.h
MAXPART     = 8
LABELSECTOR = 1


def _pdp32(v):
    """A 2.11BSD u_long: HIGH word first, little-endian within each word."""
    return struct.pack("<HH", (v >> 16) & 0xFFFF, v & 0xFFFF)


def build_label(fs_sectors, packname="FGX"):
    """A disklabel whose partition `a' is the filesystem and nothing else."""
    lab = bytearray(SECSIZE)

    def w16(off, v): struct.pack_into("<H", lab, off, v & 0xFFFF)
    def w32(off, v): lab[off:off + 4] = _pdp32(v)
    def wstr(off, s, n): lab[off:off + n] = s.encode()[:n].ljust(n, b"\0")

    w32(0x00, DISKMAGIC)
    lab[0x04] = DRIVE["d_type"]
    lab[0x05] = 0
    wstr(0x06, DRIVE["typename"], 16)
    wstr(0x16, packname, 16)
    w16(0x26, DRIVE["d_secsize"])
    w16(0x28, DRIVE["d_nsectors"])
    w16(0x2A, DRIVE["d_ntracks"])
    w16(0x2C, DRIVE["d_ncylinders"])
    w16(0x2E, DRIVE["d_secpercyl"])
    w32(0x30, DRIVE["d_secperunit"])
    w16(0x3A, DRIVE["d_rpm"])
    lab[0x3C] = DRIVE["d_interleave"]
    w32(0x6C, DISKMAGIC)                       # d_magic2
    w16(0x72, MAXPART)                         # d_npartitions
    w16(0x74, 512)                             # d_bbsize
    w16(0x76, 1024)                            # d_sbsize

    # a = the filesystem, at sector 0.  c = the whole drive, which is
    # 2.11BSD's convention for "the raw disk" and what disklabel(8) expects to
    # find; every other letter stays zero rather than describing space no
    # filesystem occupies.
    def part(i, size, off, fstype):
        o = 0x78 + i * 12
        lab[o:o + 4] = _pdp32(size)
        lab[o + 4:o + 8] = _pdp32(off)
        struct.pack_into("<H", lab, o + 8, 1024)   # p_fsize
        lab[o + 10] = fstype
        lab[o + 11] = 1                            # p_frag
    part(0, fs_sectors, 0, FS_V71K)                # a
    part(2, DRIVE["d_secperunit"], 0, 0)           # c, FS_UNUSED

    # dkcksum: XOR of u_shorts from the start through d_partitions[npart].
    end = 0x78 + MAXPART * 12
    sum_ = 0
    for o in range(0, end, 2):
        sum_ ^= struct.unpack_from("<H", lab, o)[0]
    struct.pack_into("<H", lab, 0x70, sum_)
    return bytes(lab)


def wrap(po_path, dsk_path, packname="FGX"):
    data = open(po_path, "rb").read()
    if len(data) % SECSIZE:
        raise SystemExit(f"fgxdsk: {po_path} is not a whole number of sectors")
    fs_sectors = len(data) // SECSIZE
    total = DRIVE["d_secperunit"]
    if fs_sectors > total:
        raise SystemExit(f"fgxdsk: {po_path} is {fs_sectors} sectors, past "
                         f"the {DRIVE['typename']}'s {total}")
    lab = build_label(fs_sectors, packname)
    out = bytearray(data)
    out[LABELSECTOR * SECSIZE:(LABELSECTOR + 1) * SECSIZE] = lab
    with open(dsk_path, "wb") as f:
        f.write(out)
        f.truncate(total * SECSIZE)
    print(f"fgxdsk {dsk_path}: {DRIVE['typename']}, {total} sectors; "
          f"partition a = {fs_sectors} sectors ({fs_sectors // 2} KB) at 0")


def self_test():
    """The label must parse back to what was asked, and check out.

    Arm 3 is the one that matters: dkcksum over a CORRECT label is 0, because
    the stored checksum is itself in the XOR range -- so a label this tool
    writes and a label 2.11BSD accepts are the same test.
    """
    fails = []
    lab = build_label(64000, "FGX")

    def u16(o): return struct.unpack_from("<H", lab, o)[0]
    def u32(o):
        hi, lo = struct.unpack_from("<HH", lab, o)
        return (hi << 16) | lo

    if u32(0x00) != DISKMAGIC or u32(0x6C) != DISKMAGIC:
        fails.append("arm 1: magic or magic2 wrong")
    if u32(0x78) != 64000 or u32(0x7C) != 0:
        fails.append(f"arm 2: partition a is {u32(0x78)}@{u32(0x7C)}, not 64000@0")
    end = 0x78 + MAXPART * 12
    s = 0
    for o in range(0, end, 2):
        s ^= struct.unpack_from("<H", lab, o)[0]
    if s != 0:
        fails.append(f"arm 3: dkcksum over the finished label is {s:#06x}, not 0")
    if lab[0x78 + 10] != FS_V71K:
        fails.append("arm 4: partition a is not typed as a 2.11BSD filesystem")
    # 5: a byte flipped anywhere in the label must break the checksum, or
    #    arm 3 is checking arithmetic rather than integrity.
    bad = bytearray(lab)
    bad[0x20] ^= 0xFF
    s = 0
    for o in range(0, end, 2):
        s ^= struct.unpack_from("<H", bad, o)[0]
    if s == 0:
        fails.append("arm 5: a corrupted label still checksummed clean")
    if fails:
        for f in fails:
            print("SELF-TEST FAIL:", f, file=sys.stderr)
        return 1
    print("fgxdsk --self-test: OK (magic, partition a, dkcksum zero over a "
          "good label and nonzero over a corrupted one, 2.11BSD fs type)")
    return 0


def main(argv):
    global DRIVE
    argv = list(argv)
    if len(argv) >= 3 and argv[1] == "-t":
        want = argv[2].lower()
        if want not in DRIVES:
            print("fgxdsk: unknown drive %r; have %s"
                  % (want, " ".join(sorted(DRIVES))), file=sys.stderr)
            return 2
        DRIVE = DRIVES[want]
        del argv[1:3]
    if len(argv) == 2 and argv[1] == "--self-test":
        return self_test()
    if len(argv) not in (3, 4):
        print("usage: fgxdsk.py [-t ra92|ra72] IN.po OUT.dsk [packname] "
              "| --self-test", file=sys.stderr)
        return 2
    wrap(argv[1], argv[2], argv[3] if len(argv) == 4 else "FGX")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
