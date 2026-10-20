#!/usr/bin/env python3
"""mkpdscratch.py OUT -- the ProDOS volume prodos.mod's tests mount.

BUILT BY cadius, an implementation of ProDOS nobody here wrote, so the volume
the filesystem reads is not one it made itself.  2400 KB is 4800 blocks, an
even count (src/kernel/vfs/prodos.h says why that matters), and past 4096.

WHAT IS ON IT, and the storage shape each file is there for:

  HELLO           seedling, text the test cats
  SAP             sapling, 20000 bytes, blocks 4-7 zero -- cadius writes those
                  as HOLES, a zero index entry
  TREE            tree, 140000 bytes: past the 256 blocks one index addresses
  F01..F09        seedlings that fill the volume directory's key block
  SUB/            its ENTRY in the volume directory's SECOND block, so its
                  header's parent_pointer is a continuation block
  ZLAST           the second entry in that continuation block
  EXT             a GS/OS extended file, type $B3 aux $DB07: a 1500-byte data
                  fork and a 700-byte resource fork, both saplings, and no
                  stored Finder info -- so `._ext' carries the Finder info
                  GS/OS's HFS FST would make of the type
  FILL, FPADn     no test reads them: they take every free block below 4096
  SUB/INNER/      its entry in SUB's key block, parent_pointer a key block,
                  and its KEY BLOCK IS 4096 -- 1 << 12, so an inode number
                  built from (block << 4) would truncate to 0 in 16 bits
  SUB/INNER/DEEP  seedling

The two directory placements are the two arms of prodos_vnops.c's pd_parent,
and they and INNER's key block are ASSERTED here rather than assumed: a cadius
that placed entries differently would otherwise leave the test green over one
arm, or below 4096.

The file contents are a pure function of the offset, and the manifest's sums
were computed from them (`--sums` prints them).

THE STAMPS ARE WRITTEN HERE, not left to cadius, which dates every entry with
the time it ran.  Every entry in the volume directory gets STAMP_DEFAULT except
those STAMPS names: HELLO in 1990, EXT in 2005 -- a year Technical Note #28
stores as 5 -- F01 in 2019 stored as year 119, as volumes GS/OS reads carry,
and SUB, whose stamp lives only in its entry in a continuation block.  The volume header's creation stamp is ROOT_CREATED.  `--sums' prints
each as the epoch second a UTC reading of it is, FGX having no timezone.
"""
import calendar
import os
import shutil
import subprocess
import sys
import tempfile

VOL = "PDSCRATCH"


def contents():
    sap = bytearray(((i * 5 + 1) & 255) or 1 for i in range(20000))
    sap[2048:4096] = bytes(2048)
    tree = bytes((((i * 7) ^ (i >> 8)) & 255) or 1 for i in range(140000))
    root = [("HELLO", b"hello from a prodos volume\n"),
            ("SAP", bytes(sap)), ("TREE", tree)]
    root += [("F%02d" % n, b"f%02d\n" % n) for n in range(1, 10)]
    return root


# Case masks (GS/OS Technical Note #8) and access bytes, written into every
# directory.  An entry named in neither keeps no case mask -- so it lists in
# lowercase -- and the access byte cadius gave it, $E3.  Hello shows mixed case,
# TREE a valid mask of all uppercase; SAP is read-only and F02 locked outright.
MASKS = {"HELLO": 0xBC00, "TREE": 0x8000}
ACCESS = {"SAP": 0x01, "F02": 0x00}
ACCESS_DEFAULT = 0xE3

STAMP_DEFAULT = (1995, 1, 1, 0, 0)
STAMPS = {"HELLO": (1990, 6, 15, 13, 45), "EXT": (2005, 2, 3, 4, 5),
          "SUB": (1987, 11, 30, 23, 59), "F01": (2019, 9, 1, 17, 37, 119)}
ROOT_CREATED = (1986, 9, 1, 12, 0)


def pdstamp(t):
    """A ProDOS date word then time word, low bytes first (Beneath Apple
    ProDOS p. 6-32; the year per Technical Note #28)."""
    y, mo, d, h, mi = t[:5]
    yy = t[5] if len(t) > 5 else (y - 1900 if y < 2000 else y - 2000)
    dw = yy << 9 | mo << 5 | d
    tw = h << 8 | mi
    return bytes((dw & 255, dw >> 8, tw & 255, tw >> 8))


def epoch(t):
    return calendar.timegm((t[0], t[1], t[2], t[3], t[4], 0, 0, 0, 0))


def stamp(out):
    """Stamps in the volume directory; case masks and access bytes in every
    directory's entries."""
    img = bytearray(open(out, "rb").read())
    img[2 * 512 + 4 + 0x18:2 * 512 + 4 + 0x1C] = pdstamp(ROOT_CREATED)

    def walk(key, top):
        blk = key
        while blk:
            for s in range(13):
                o = blk * 512 + 4 + s * 39
                if img[o] >> 4 in (0, 0xE, 0xF):
                    continue
                name = bytes(img[o + 1:o + 1 + (img[o] & 15)]).decode()
                if top:
                    img[o + 0x21:o + 0x25] = pdstamp(STAMPS.get(name, STAMP_DEFAULT))
                mask = MASKS.get(name, 0)
                img[o + 0x1C:o + 0x1E] = bytes((mask & 255, mask >> 8))
                img[o + 0x1E] = ACCESS.get(name, ACCESS_DEFAULT)
                if img[o] >> 4 == 0xD:
                    walk(w(img, o + 0x11), False)
            blk = w(img, blk * 512 + 2)
    walk(2, True)
    open(out, "wb").write(img)


def mode(name, isdir=False):
    """pd_mode's bits for an entry's access byte."""
    acc = ACCESS.get(name, ACCESS_DEFAULT)
    m = (0o555 if isdir else 0o444) if acc & 1 else 0
    return m | (0o200 if acc & 2 else 0)


EXT_TYPE, EXT_AUX = 0xB3, 0xDB07
EXT_DATA = bytes(((i * 3 + 7) & 255) or 1 for i in range(1500))
EXT_RSRC = bytes(((i * 11 + 5) & 255) or 1 for i in range(700))


def appledouble(ftype, aux, rsrc):
    """`._NAME' as RFC 1740 lays out an AppleDouble header file, with xnu's
    two entries (Finder Info first, Resource Fork last) and the Finder info
    GS/OS's HFS FST gives a type its table does not name."""
    be = lambda v: v.to_bytes(4, "big")
    h = (be(0x00051607) + be(0x00020000) + bytes(16) + (2).to_bytes(2, "big") +
         be(9) + be(50) + be(32) + be(2) + be(82) + be(len(rsrc)))
    finfo = b"p" + bytes((ftype, aux >> 8, aux & 255)) + b"pdos" + bytes(24)
    return h + finfo + rsrc


def bsd_sum(data):
    s = 0
    for c in data:
        s = (s >> 1) + (0x8000 if s & 1 else 0)
        s = (s + c) & 0xFFFF
    return s


def cadius(*args):
    subprocess.run(("cadius",) + args, check=True, stdout=subprocess.DEVNULL)


def add(img, tmp, folder, name, data):
    path = os.path.join(tmp, name)
    with open(path, "wb") as f:
        f.write(data)
    cadius("ADDFILE", img, folder, path)
    os.remove(path)


def w(b, o):
    return b[o] | b[o + 1] << 8


def entry(img, dirkey, name):
    """(block, slot, entry bytes) of `name' in the directory keyed at dirkey."""
    blk = dirkey
    while blk:
        b = img[blk * 512:(blk + 1) * 512]
        for s in range(13):
            e = b[4 + s * 39:4 + (s + 1) * 39]
            if e[0] >> 4 and e[1:1 + (e[0] & 15)] == name.encode():
                return blk, s, e
        blk = w(b, 2)
    sys.exit("mkpdscratch: %s not found" % name)


def storage(n):
    """Blocks cadius spends on an n-block file: data plus its index blocks."""
    if n <= 1:
        return 1
    if n <= 256:
        return n + 1
    return n + 1 + (n + 255) // 256


def free_below(out, limit):
    img = open(out, "rb").read()
    bm = img[w(img, 2 * 512 + 4 + 0x23) * 512:]
    return sum(1 for i in range(limit) if bm[i >> 3] & (0x80 >> (i & 7)))


def fill(out, tmp, folder, limit):
    """Files that use exactly the free blocks below `limit'."""
    want = free_below(out, limit)
    n = want
    while storage(n) > want:
        n -= 1
    add(out, tmp, folder, "FILL", bytes(((i >> 9) & 255) | 1
                                        for i in range(n * 512)))
    for k in range(want - storage(n)):
        add(out, tmp, folder, "FPAD%d" % k, b"pad\n")


def check(out):
    img = open(out, "rb").read()
    blk, slot, e = entry(img, 2, "SUB")
    sub = w(e, 0x11)
    h = img[sub * 512 + 4:sub * 512 + 43]
    if blk == 2 or w(h, 0x23) != blk or h[0x25] != slot + 1:
        sys.exit("mkpdscratch: SUB is at (%d,%d), parent (%d,%d): not the "
                 "continuation-block arm" % (blk, slot, w(h, 0x23), h[0x25]))
    blk, slot, e = entry(img, sub, "INNER")
    inner = w(e, 0x11)
    h = img[inner * 512 + 4:inner * 512 + 43]
    if blk != sub or w(h, 0x23) != sub:
        sys.exit("mkpdscratch: INNER's parent_pointer is not SUB's key block")
    blk, slot, e = entry(img, 2, "EXT")
    if e[0] >> 4 != 5:
        sys.exit("mkpdscratch: EXT is storage type %d, not extended" % (e[0] >> 4))
    if inner != 4096:
        sys.exit("mkpdscratch: INNER's key block is %d, not 4096" % inner)
    total = w(img, 2 * 512 + 4 + 0x25)
    bm = img[w(img, 2 * 512 + 4 + 0x23) * 512:]
    free = sum(1 for i in range(total) if bm[i >> 3] & (0x80 >> (i & 7)))
    return free


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--sums":
        t = lambda n: epoch(STAMPS.get(n, STAMP_DEFAULT))
        for name, data in contents():
            print("PDSUM %s %d %d t=%d m=%o" % (name.lower(), len(data),
                  bsd_sum(data), t(name), mode(name)))
        ad = appledouble(EXT_TYPE, EXT_AUX, EXT_RSRC)
        print("PDSUM ext %d %d t=%d m=%o" % (len(EXT_DATA), bsd_sum(EXT_DATA),
                                            t("EXT"), mode("EXT")))
        print("PDSUM ._ext %d %d t=%d m=%o" % (len(ad), bsd_sum(ad), t("EXT"),
                                              mode("EXT")))
        # A directory's bits are its HEADER's access byte, which cadius wrote
        # $C3 and the generator leaves alone.
        print("PDSUM sub read errno=21 t=%d m=755" % t("SUB"))
        print("PDSUM . read errno=21 t=%d m=755" % epoch(ROOT_CREATED))
        return
    out = sys.argv[1]
    tmp = tempfile.mkdtemp(dir=os.path.dirname(os.path.abspath(out)))
    try:
        if os.path.exists(out):
            os.remove(out)
        cadius("CREATEVOLUME", out, VOL, "2400KB")
        top = "/" + VOL
        for name, data in contents():
            add(out, tmp, top, name, data)
        cadius("CREATEFOLDER", out, top + "/SUB")
        add(out, tmp, top, "ZLAST", b"zlast\n")
        # cadius takes a resource fork from NAME#TTAAAA_ResourceFork.bin
        tag = "EXT#%02X%04X" % (EXT_TYPE, EXT_AUX)
        with open(os.path.join(tmp, tag + "_ResourceFork.bin"), "wb") as f:
            f.write(EXT_RSRC)
        add(out, tmp, top, tag, EXT_DATA)
        fill(out, tmp, top, 4096)
        cadius("CREATEFOLDER", out, top + "/SUB/INNER")
        add(out, tmp, top + "/SUB/INNER", "DEEP", b"deep file\n")
    finally:
        shutil.rmtree(tmp)
    stamp(out)
    free = check(out)
    print("mkpdscratch: %s, %d blocks free" % (out, free))


if __name__ == "__main__":
    main()
