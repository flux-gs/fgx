#!/usr/bin/env python3
"""fgx_imports.py - an object's imports from the shared libraries below it
(shared libc SP3 spec, section 3): the IMPS trailer block, and the resolver
fgx_ld binds names through.

A library (termlib, curses) and, in step 3, a dynamic program carry the
same table.  Per needed library: name, major, minor, export CRC, the core
base assumed, the rows of its block table the program was linked against
and a reachability bitmap over them, (rows + 7) / 8 bytes (none for a
library).  Per import:
the library, its ordinal (its index in that library's sorted export
table), name, kind (0 code, 1 data), prebound segment and offset, size.
Per import, its sites, three kinds: `call' (the operand of a JSL or JML),
`ptr' (a 24-bit pointer cell), `data' (a 16-bit word: its value as linked,
which the binder replaces by that value + actual - prebound).  A call or
pointer site is (segment, offset); a data site (segment, offset, original
word), so a bind writes the same bytes however often it runs.

Payload, little-endian:
  n_libs (B); per lib: namelen (B) name major (B) minor (B) crc (I)
                       core_base (H) rows (B) bitmap
  n_imports (H); per import: lib (B) ordinal (H) namelen (B) name kind (B)
                             seg (B) val (H) size (H)
  per import, same order: n_call (H) [seg (B) off (H)]*
                          n_ptr (H) [seg (B) off (H)]*
                          n_data (H) [seg (B) off (H) orig (H)]*

Run: fgx_imports.py --self-test
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fgx_ld  # noqa: E402

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))), "tools"))
import gen_seg1_layout  # noqa: E402

SITES = ("call", "ptr", "data")


def lib_name(so_path):
    """libc.so.1.0 -> libc."""
    return os.path.basename(so_path).split(".so")[0]


def file_trailer(data):
    """The library trailer of a whole FGX2/FGX3 file, or None."""
    n, flags = data[6], data[10]
    nrel = struct.unpack_from("<H", data, 11)[0]
    pos = 16 + 8 * n + sum(struct.unpack_from("<H", data, 16 + 8 * i)[0]
                           for i in range(n)) + 4 * nrel
    return fgx_ld.read_trailer(data[pos:]) if flags & fgx_ld.LIB_FLAG else None


class Resolver:
    """Names bound to the exports of the libraries below, in load order.
    `libs' is [(so_path, core_listing)]: the listing is the lower library's
    core as its build assembled it, from which its private cells are known.
    `own' is the importing object's own core labels, which may share names
    with a lower library's private ones (every library's _fcc_* cells)."""

    def __init__(self, libs, own=frozenset()):
        self.libs, self.own = [], set(own)
        for so, listing in libs:
            tr = file_trailer(open(so, "rb").read())
            if tr is None:
                fgx_ld.die(f"imports: {so} carries no library trailer")
            ex = {e[0]: (i,) + tuple(e[1:]) for i, e in enumerate(tr["exports"])}
            labels = {n for _a, n in gen_seg1_layout.extract_labels(listing)}
            self.libs.append({"name": lib_name(so), "major": tr["major"],
                              "minor": tr["minor"], "crc": tr["checksum"],
                              "core_base": tr["core_base"], "exports": ex,
                              "private": labels - set(ex)})
        self.order, self.imports = [], {}

    def _find(self, name, kind):
        for li, lib in enumerate(self.libs):
            e = lib["exports"].get(name)
            if e and e[1] == kind:
                return li, e
        return None

    def code(self, name):
        """(lib, ordinal, seg, off) of a code export, or None."""
        f = self._find(name, 0)
        return f and (f[0], f[1][0], f[1][2], f[1][3])

    def data(self, name):
        """(lib, ordinal, addr, size) of a data export, or None."""
        f = self._find(name, 1)
        return f and (f[0], f[1][0], f[1][3], f[1][4])

    def private(self, name):
        """The lower library whose private core cell `name' is, or None."""
        if name in self.own:
            return None
        for lib in self.libs:
            if name in lib["private"]:
                return lib["name"]
        return None

    def use(self, kind, name, site, seg, off, orig=None):
        """Record a site of `name' (kind 0 code, 1 data).  A data site
        carries the word the link wrote there."""
        if site == "data" and orig is None:
            fgx_ld.die(f"imports: data site of {name} at {seg}:{off:#x} has no original word")
        if name not in self.imports:
            f = self._find(name, kind)
            if f is None:
                fgx_ld.die(f"imports: {name} is no export of a lower library")
            li, (ordinal, k, s, v, size) = f
            self.imports[name] = {"lib": li, "ordinal": ordinal, "name": name,
                                  "kind": k, "seg": s, "val": v, "size": size,
                                  "call": [], "ptr": [], "data": []}
            self.order.append(name)
        self.imports[name][site].append((seg, off) if site != "data" else (seg, off, orig))

    def table(self):
        return {"libs": [{k: lib[k] for k in ("name", "major", "minor", "crc",
                                               "core_base")} | {"rows": 0, "bitmap": b""}
                         for lib in self.libs],
                "imports": [self.imports[n] for n in self.order]}

    def pack(self):
        return pack(self.table())


def pack(t):
    out = bytes([len(t["libs"])])
    for lib in t["libs"]:
        nm = lib["name"].encode("ascii")
        if lib["rows"] > 255 or len(lib["bitmap"]) != (lib["rows"] + 7) // 8:
            fgx_ld.die(f"imports: {lib['name']}'s bitmap is {len(lib['bitmap'])} "
                       f"bytes for {lib['rows']} rows")
        out += bytes([len(nm)]) + nm + struct.pack(
            "<BBIHB", lib["major"], lib["minor"], lib["crc"], lib["core_base"],
            lib["rows"]) + lib["bitmap"]
    out += struct.pack("<H", len(t["imports"]))
    for im in t["imports"]:
        nm = im["name"].encode("ascii")
        out += struct.pack("<BH", im["lib"], im["ordinal"]) + bytes([len(nm)]) \
            + nm + struct.pack("<BBHH", im["kind"], im["seg"], im["val"], im["size"])
    for im in t["imports"]:
        for k in SITES:
            out += struct.pack("<H", len(im[k]))
            if k == "data":
                out += b"".join(struct.pack("<BHH", s, o, v) for s, o, v in im[k])
            else:
                out += b"".join(struct.pack("<BH", s, o) for s, o in im[k])
    return out


def unpack(p):
    if not p:
        return {"libs": [], "imports": []}
    pos, libs = 1, []
    for _ in range(p[0]):
        n = p[pos]
        name = p[pos + 1:pos + 1 + n].decode("ascii")
        major, minor, crc, base, rows = struct.unpack_from("<BBIHB", p, pos + 1 + n)
        pos += 1 + n + 9
        libs.append({"name": name, "major": major, "minor": minor, "crc": crc,
                     "core_base": base, "rows": rows,
                     "bitmap": p[pos:pos + (rows + 7) // 8]})
        pos += (rows + 7) // 8
    ni = struct.unpack_from("<H", p, pos)[0]
    pos += 2
    imports = []
    for _ in range(ni):
        li, ordinal = struct.unpack_from("<BH", p, pos)
        n = p[pos + 3]
        name = p[pos + 4:pos + 4 + n].decode("ascii")
        kind, seg, val, size = struct.unpack_from("<BBHH", p, pos + 4 + n)
        pos += 4 + n + 6
        imports.append({"lib": li, "ordinal": ordinal, "name": name,
                        "kind": kind, "seg": seg, "val": val, "size": size})
    for im in imports:
        for k in SITES:
            c = struct.unpack_from("<H", p, pos)[0]
            pos += 2
            w = 5 if k == "data" else 3
            fmt = "<BHH" if k == "data" else "<BH"
            im[k] = [struct.unpack_from(fmt, p, pos + w * i) for i in range(c)]
            pos += w * c
    return {"libs": libs, "imports": imports}


def self_test():
    t = {"libs": [{"name": "libc", "major": 1, "minor": 0, "crc": 0x12345678,
                   "core_base": 0xF6B7, "rows": 0, "bitmap": b""},
                  {"name": "libtermlib", "major": 1, "minor": 2, "crc": 7,
                   "core_base": 0xF200, "rows": 3, "bitmap": b"\x05"}],
         "imports": [{"lib": 0, "ordinal": 3, "name": "strcpy", "kind": 0,
                      "seg": 1, "val": 0x0200, "size": 0,
                      "call": [(0, 1), (2, 0x44)], "ptr": [(1, 0x10)], "data": []},
                     {"lib": 0, "ordinal": 9, "name": "errno", "kind": 1,
                      "seg": 3, "val": 0xF800, "size": 2,
                      "call": [], "ptr": [], "data": [(0, 0x20, 0xF800)]},
                     {"lib": 1, "ordinal": 0, "name": "UP", "kind": 1,
                      "seg": 1, "val": 0xF210, "size": 4,
                      "call": [], "ptr": [],
                      "data": [(0, 0x30, 0xF210), (1, 0x31, 0xF212)]}]}
    assert unpack(pack(t)) == t, unpack(pack(t))
    assert unpack(b"") == {"libs": [], "imports": []}
    t["libs"][1]["rows"] = 9                      # two bytes' worth, one given
    try:
        pack(t)
    except SystemExit:
        pass
    else:
        raise AssertionError("a bitmap the wrong size for its rows must be refused")
    print("fgx_imports: self-test OK")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
