#!/usr/bin/env python3
"""fgx_lddigest.py - what ld_load (lib/libc_c/ld_load.c) leaves in shared
libraries' banks, as a digest per bank, for the machine probe lddig to
check (shared libc SP4 spec, section 9).

Libraries load in the order given, cores stacked down from HEAP_LIM, each
laid out as fgx_bind lays it -- its code banks, then on the end of the last
the core template, the block templates -- followed by the trailer's EXPT
FIXS and XIDX (an export index) blocks, tagged as in the file and ended by
an END tag.  Its relocs
are applied, its core sites moved, its imports bound.  Every byte that
holds a runtime bank (a reloc's, a code import site's, a per-process
fixup's) is 0 in the digest; lddig checks those bytes itself.

The digest is h = rotl16(h, 1) ^ byte, which is linear: byte b at index i
of n contributes rotl16(b, (n - 1 - i) % 16), so lddig takes a byte out by
XORing its contribution away.

With --boot the boot set comes first -- libc and /etc/ld.so.conf's
libraries, each after what it stacks on (fgx_bind.boot_order), as rc's
ldload makes them resident -- and
then the libraries named, less any already in it.

Run: fgx_lddigest.py --out F [--boot] NAME=PATH ...
     fgx_lddigest.py --self-test
"""
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_bind  # noqa: E402
import fgx_imports  # noqa: E402
import fgx_ld  # noqa: E402


def rotl(v, n):
    n &= 15
    return ((v << n) | (v >> (16 - n))) & 0xFFFF if n else v


def digest(b):
    h = 0
    for x in b:
        h = rotl(h, 1) ^ x
    return h


def xidx(tr):
    """ld_load's export index: the assembled core base, the count, and each
    EXPT record's offset in its payload, in EXPT's (name) order."""
    rec, offs, p = tr["blocks_raw"].get("EXPT", b""), [], 0
    while p < len(rec):
        offs.append(p)
        p += 1 + rec[p] + 6
    return struct.pack("<HH", tr["core_base"], len(offs)) + \
        b"".join(struct.pack("<H", o) for o in offs)


def tagged(tr):
    raw = tr["blocks_raw"]
    return (fgx_ld.block(b"EXPT", raw.get("EXPT", b""))
            + fgx_ld.block(b"FIXS", raw.get("FIXS", b""))
            + fgx_ld.block(b"XIDX", xidx(tr))
            + fgx_ld.block(b"END\0", b""))


def lay_out(libs):
    """[(name, major, base, [digest per bank])], libraries loaded in order.
    An entry ("pad", n) holds n bytes of the arena, as `ldctl pad n' does."""
    img = fgx_bind.Image({"segs": [], "relocs": [], "head": bytes(16)})
    loaded, out, base = {}, [], fgx_ld.HEAP_LIM
    for name, path in libs:
        if name == "pad":
            base -= int(path)
            continue
        lib = fgx_bind.parse(open(path, "rb").read())
        tr = fgx_ld.read_trailer(lib["trailer"])
        base -= tr["core_size"]
        placed = img.add_lib(name, lib, tr)
        delta = base - tr["core_base"]
        csit = tr["blocks_raw"].get("CSIT", b"")
        for i in range(len(csit) // 3):
            s, o = struct.unpack_from("<BH", csit, 3 * i)
            S, O = placed.place[s]
            img.word_add(S, O + o, delta)
        L = fgx_bind.Lib(name, path, lib, tr,
                         {e[0]: tuple(e[1:]) for e in tr["exports"]},
                         placed, base, delta)
        if "IMPS" in tr["blocks_raw"]:
            fgx_bind.bind_sites(img, placed.place,
                                fgx_imports.unpack(tr["blocks_raw"]["IMPS"]),
                                loaded, name, None, True,
                                {"lookups": 0, "sites": {k: 0 for k in fgx_imports.SITES}})
        img.segs[placed.last] += tagged(tr)
        if len(img.segs[placed.last]) > 0x10000:
            fgx_ld.die(f"{name}: its last bank with the tagged blocks is "
                       f"{len(img.segs[placed.last])} bytes")
        loaded[name] = L
        segs = sorted(set(placed.seg_of.values()))
        banks = []
        for s in segs:
            b = bytearray(img.segs[s])
            for rs, ro, _t in img.relocs:
                if rs == s:
                    b[ro] = 0
            banks.append(digest(b))
        out.append((name, tr["major"], base, banks))
    return out


def write(rows, out):
    with open(out, "w") as f:
        for name, major, base, banks in rows:
            f.write("%s %d %04x %d %s\n" % (name, major, base, len(banks),
                                            " ".join("%04x" % d for d in banks)))


def self_test():
    b = bytes(range(37)) * 3
    for i in (0, 5, 16, len(b) - 1):
        m = bytearray(b)
        m[i] = 0
        assert digest(m) == digest(b) ^ rotl(b[i], len(b) - 1 - i), i
    lib = os.path.join(os.path.dirname(os.path.dirname(HERE)), "lib")
    so = [(n, os.path.join(lib, n + ".so.1.0"))
          for n in ("libc", "libtermlib", "libcurses")]
    if not all(os.path.exists(p) for _n, p in so):
        print("fgx_lddigest: self-test OK (layout skipped: no built libraries)")
        return
    rows = lay_out(so)
    base = fgx_ld.HEAP_LIM
    for (n, p), (name, major, b, banks) in zip(so, rows):
        tr = fgx_ld.read_trailer(fgx_bind.parse(open(p, "rb").read())["trailer"])
        base -= tr["core_size"]
        assert (name, major, b, len(banks)) == (n, 1, base, tr["core"]), name
    padded = lay_out([so[0], ("pad", "100")] + so[1:])
    assert padded[1][2] == rows[1][2] - 100 and padded[0] == rows[0]
    print("fgx_lddigest: self-test OK")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    a = sys.argv[1:]
    boot = "--boot" in a
    a = [x for x in a if x != "--boot"]
    if len(a) < 3 or a[0] != "--out":
        sys.exit("usage: fgx_lddigest.py --out F [--boot] NAME=PATH ...")
    libs = [tuple(x.split("=", 1)) for x in a[2:]]
    if boot:
        lib = os.path.join(os.path.dirname(os.path.dirname(HERE)), "lib")
        first = [(n, fgx_bind.find_so(n, m, 0, lib, dict(libs)))
                 for n, m in fgx_bind.boot_order(lib, dict(libs))]
        libs = first + [x for x in libs if x[0] not in dict(first)]
    write(lay_out(libs), a[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
