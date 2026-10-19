#!/usr/bin/env python3
"""fgx_bind.py - bind a dynamic program to its shared libraries on the host
(shared libc SP3 spec, section 4): what sub-project 4's ldload does once per
boot (place and bind the libraries) and its binder does at exec (bind the
program), written out as an ordinary FGX3 image the loader runs.

The image is the program's segments, then each library's code banks as CODE
segments, its core template and block templates on the end of its last
bank.  A startup routine at the end of segment 0 copies each core to its
base below HEAP_LIM, sets HEAP_LIM to the lowest, and enters _crt0_lib.

Run: fgx_bind.py --prog P --out F [--lib-dir D] [--so NAME=PATH ...]
                 [--trace] [--no-data-sites] [--conf LD_SO_CONF]
     fgx_bind.py --prog P --digest [--lib-dir D] [--so NAME=PATH ...]
                 [--conf LD_SO_CONF]
"""
import argparse
import glob
import os
import re
import struct
import sys
from collections import namedtuple

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_imports  # noqa: E402
import fgx_ld  # noqa: E402
import fgx_libso  # noqa: E402

HEADER = 16
KIND_CODE = fgx_ld.KIND_MAP["CODE"]
MAX_SEGS = 8                    # TCB_BankList's slots for the program (fgx_ld)
Placed = namedtuple("Placed", "seg_of place last core_at tmpl_at")


def die(msg):
    sys.exit("fgx_bind: " + msg)


def parse(data):
    """A linked FGX2/FGX3 file: header, segments, relocs, trailer bytes."""
    n = data[6]
    segs, pos = [], HEADER + 8 * n
    flags = []
    for i in range(n):
        size, bss, kind, fl = struct.unpack_from("<HHBB", data, HEADER + 8 * i)
        segs.append((bytearray(data[pos:pos + size]), bss, kind))
        flags.append(fl)
        pos += size
    nrel = struct.unpack_from("<H", data, 11)[0]
    relocs = [struct.unpack_from("<BHB", data, pos + 4 * i) for i in range(nrel)]
    return {"head": bytes(data[:HEADER]), "segs": segs, "flags": flags,
            "relocs": relocs,
            "trailer": bytes(data[pos + 4 * nrel:])}


class Image:
    """The bound image being built: the program's segments first."""

    def __init__(self, prog):
        self.segs = [bytearray(s) for s, _b, _k in prog["segs"]]
        self.bss = [b for _s, b, _k in prog["segs"]]
        self.kinds = [k for _s, _b, k in prog["segs"]]
        self.flags = list(prog.get("flags", [0] * len(self.segs)))  # FGX2_SEGF_PLACE
        self.relocs = list(prog["relocs"])
        self.n_data = prog["head"][7]

    def reloc(self, seg, off, tgt):
        if not 0 <= off < len(self.segs[seg]):
            die("a reloc at segment %d offset %#06x is outside it (%d bytes)"
                % (seg, off, len(self.segs[seg])))
        self.relocs.append((seg, off, tgt))

    def word_add(self, seg, off, n):
        v = struct.unpack_from("<H", self.segs[seg], off)[0]
        struct.pack_into("<H", self.segs[seg], off, (v + n) & 0xFFFF)

    def word_set(self, seg, off, v):
        struct.pack_into("<H", self.segs[seg], off, v & 0xFFFF)

    def add_lib(self, name, lib, tr):
        """The library's code banks as CODE segments, its core template
        and block templates on the end of the last; its relocs renumbered.
        A pointer into the templates gains their new offset.  A fixup (a
        core pointer into the core) is NOT a reloc: the last bank is shared
        text, whose relocs the loader applies at the first load only, so a
        reloc would carry the first process's data bank into every later
        copy.  The startup sets each fixup's bank byte from DBR instead."""
        core, tmpl = tr["core"], tr["templates"]
        code = [i for i, (_s, _b, k) in enumerate(lib["segs"]) if k == KIND_CODE]
        if code != list(range(core)) or tmpl != core + 1:
            die("%s: segments %s are not code banks, core, templates"
                % (name, [k for _s, _b, k in lib["segs"]]))
        first = len(self.segs)
        seg_of = {i: first + i for i in code}
        last = first + len(code) - 1
        for i in code:
            self.segs.append(bytearray(lib["segs"][i][0]))
            self.bss.append(0)
            self.kinds.append(KIND_CODE)
            self.flags.append(0)
        core_at = len(self.segs[last])
        self.segs[last] += lib["segs"][core][0]
        tmpl_at = len(self.segs[last])
        self.segs[last] += lib["segs"][tmpl][0]
        if len(self.segs[last]) > 0xFFFF:
            die("%s: its last bank, core and templates are %d bytes"
                % (name, len(self.segs[last])))
        place = {i: (seg_of[i], 0) for i in code}
        place[core] = (last, core_at)
        place[tmpl] = (last, tmpl_at)
        for src, off, tgt in lib["relocs"]:
            if tgt == core:
                die("%s: a reloc into its core (segment %d offset %#06x); "
                    "fgx_ld makes those fixups" % (name, src, off))
            s, o = place[src]
            t, to = place[tgt]
            if to:
                self.word_add(s, o + off - 2, to)
            self.reloc(s, o + off, t)
        return Placed(seg_of, place, last, core_at, tmpl_at)


Lib = namedtuple("Lib", "name path lib tr exports placed base delta")


def find_so(name, major, minor, lib_dir, override):
    """The library's file: `override' by name, else the highest minor of
    `major' in lib_dir (SunOS cache_rtld.c:145-183)."""
    if name in override:
        path = override[name]
    else:
        pat = re.compile(r"%s\.so\.%d\.(\d+)$" % (re.escape(name), major))
        found = [(int(m.group(1)), p) for p in glob.glob(os.path.join(
            lib_dir, "%s.so.%d.*" % (name, major)))
            for m in [pat.search(os.path.basename(p))] if m]
        if not found:
            die("ld.so: %s.so.%d: not found" % (name, major))
        path = max(found)[1]
    return path


def open_lib(name, major, minor, lib_dir, override):
    path = find_so(name, major, minor, lib_dir, override)
    lib = parse(open(path, "rb").read())
    if not lib["head"][10] & fgx_ld.LIB_FLAG:
        die("%s is not a library" % path)
    tr = fgx_ld.read_trailer(lib["trailer"])
    if tr["major"] != major:
        die("ld.so: %s is version %d; expected %d" % (path, tr["major"], major))
    if tr["minor"] < minor:
        sys.stderr.write("ld.so: warning: %s has older revision than expected "
                         "%d\n" % (os.path.basename(path), minor))
    return path, lib, tr


def bind_sites(img, where, table, libs, obj, trace, patch_data, report):
    """Bind one object's imports: `where' maps its segments to (image
    segment, offset); `table' is its IMPS table."""
    paths = []
    for rec in table["libs"]:
        L = libs.get(rec["name"])
        if L is None:
            die("%s needs %s, which is not bound" % (obj, rec["name"]))
        pre = rec["crc"] == L.tr["crc"] and rec["core_base"] == L.base
        paths.append(pre)
        if trace:
            trace.write("\t%s.so.%d => %s (core $%04X): %s\n" % (
                L.name, L.tr["major"], L.path, L.base, "prebound" if pre else
                "by name (crc %08x, $%04X; linked against %08x, $%04X)"
                % (L.tr["crc"], L.base, rec["crc"], rec["core_base"])))
    for im in table["imports"]:
        rec = table["libs"][im["lib"]]
        L = libs[rec["name"]]
        if paths[im["lib"]]:
            kind, seg, val = im["kind"], im["seg"], im["val"]
            addr = val
        else:
            e = L.exports.get(im["name"])
            report["lookups"] += 1
            if e is None or e[0] != im["kind"]:
                die("ld.so: %s: %s is not a %s export of %s" % (
                    obj, im["name"], "data" if im["kind"] else "code", L.name))
            kind, seg, val, size = e
            if kind == 1 and size < im["size"]:
                die("ld.so: %s: %s is %d bytes in %s; linked against %d"
                    % (obj, im["name"], size, L.name, im["size"]))
            addr = val + L.delta
        if kind == 0:
            report.setdefault("segs", {})[im["name"]] = seg
            tgt = L.placed.seg_of[seg]
            for s, o in im["call"] + im["ptr"]:
                S, O = where[s]
                img.word_set(S, O + o, val)
                img.reloc(S, O + o + 2, tgt)
        elif patch_data:
            for s, o, orig in im["data"]:
                S, O = where[s]
                img.word_set(S, O + o, (orig + addr - im["val"]) & 0xFFFF)
        for k in fgx_imports.SITES:
            report["sites"][k] += len(im[k])
        if trace:
            trace.write("\t\t%s => %s %s $%04X\n" % (
                im["name"], L.name, "bank %d" % seg if kind == 0 else "data", addr
                if kind else val))


def fit(prog_img, prog_table, libs, lowest):
    """LIM = the lowest core less the blocks the program's bitmaps reach,
    against the libraries bound; the data must end at or below it."""
    need = 0
    for rec in prog_table["libs"]:
        L = libs[rec["name"]]
        rows = L.tr["blocks"]
        if rec["rows"] != len(rows):
            die("%s's bitmap is for %d rows; its block table has %d (relink "
                "the program)" % (L.name, rec["rows"], len(rows)))
        need += sum(sz for i, (_c, _t, sz) in enumerate(rows)
                    if rec["bitmap"][i >> 3] & (1 << (i & 7)))
    lim = lowest - need
    end = len(prog_img.segs[prog_img.n_data]) + prog_img.bss[prog_img.n_data]
    if end > lim:
        die("the program's data ends at $%04X, above LIM $%04X (cores from "
            "$%04X, %d bytes of blocks)" % (end, lim, lowest, need))
    return lim


# The libraries resident from boot: libc, which rc's ldload(8) loads first,
# then /etc/ld.so.conf's, in its order (ldload.c).  This tree's copy is the
# image's.
LD_SO_CONF = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))),
                          "disk_src", "etc", "ld.so.conf")


def boot_libs(conf=None):
    """[(name, major)] resident from boot, in load order: libc, then
    ld.so.conf's lines (`library major'; `#' starts a comment)."""
    out = [("libc", 1)]
    with open(conf or LD_SO_CONF) as f:
        for ln in f:
            t = ln.split("#", 1)[0].split()
            if len(t) == 2 and t[1].isdigit() and t[0] != "libc":
                out.append((t[0], int(t[1])))
    return out


def boot_order(lib_dir, override, conf=None):
    """[(name, major)] of the boot set in the order it becomes resident:
    boot_libs, each library preceded by the libraries it stacks on
    (fgx_libso.LIBS `below') not already placed, as ldload's load of a
    library loads what it needs first.  A listed library with no file is
    not resident, as ldload reports it and goes on."""
    out = []

    def place(name, major):
        if name in dict(out):
            return
        for b in fgx_libso.LIBS.get(name, {}).get("below", []):
            place(b, fgx_libso.LIBS[b]["version"][0])
        out.append((name, major))
    for name, major in boot_libs(conf):
        if name == "libc" or name in override or glob.glob(
                os.path.join(lib_dir, "%s.so.%d.*" % (name, major))):
            place(name, major)
    return out


def boot_bases(lib_dir, override, conf=None):
    """{name: core base} of the boot set, each core stacked below the one
    before it from HEAP_LIM, in boot_order."""
    bases, base = {}, fgx_ld.HEAP_LIM
    for name, major in boot_order(lib_dir, override, conf):
        _p, _l, tr = open_lib(name, major, 0, lib_dir, override)
        base -= tr["core_size"]
        bases[name] = base
    return bases


def bind(prog_path, lib_dir, override=None, trace=None, patch_data=True,
         conf=None):
    """Bind as the machine binds on a booted system: the boot set holds its
    slots (boot_bases), and any other library stacks below the lowest of
    them, in the program's load order."""
    override = override or {}
    prog = parse(open(prog_path, "rb").read())
    if not prog["head"][10] & fgx_ld.DYN_FLAG:
        die("%s is not a dynamic program" % prog_path)
    table = fgx_imports.unpack(fgx_ld.read_dyn_trailer(prog["trailer"])["blocks_raw"]["IMPS"])
    img = Image(prog)
    report = {"libs": {}, "lookups": 0, "sites": {k: 0 for k in fgx_imports.SITES}}
    boot = boot_bases(lib_dir, override, conf)
    libs, base, lowest = {}, min(boot.values()), fgx_ld.HEAP_LIM
    if trace:
        trace.write("%s:\n" % os.path.basename(prog_path))
    copies = []
    for rec in table["libs"]:                       # load order
        path, lib, tr = open_lib(rec["name"], rec["major"], rec["minor"],
                                 lib_dir, override)
        if rec["name"] in boot:
            at = boot[rec["name"]]
        else:
            base -= tr["core_size"]
            at = base
        lowest = min(lowest, at)
        placed = img.add_lib(rec["name"], lib, tr)
        copies.append((placed.last, placed.core_at, at, tr["core_size"],
                       tr["fixups"]))
        delta = at - tr["core_base"]
        csit = tr["blocks_raw"].get("CSIT", b"")
        for i in range(len(csit) // 3):
            s, o = struct.unpack_from("<BH", csit, 3 * i)
            S, O = placed.place[s]
            img.word_add(S, O + o, delta)
        L = Lib(rec["name"], path, lib, tr,
                {e[0]: tuple(e[1:]) for e in tr["exports"]}, placed, at, delta)
        if "IMPS" in tr["blocks_raw"]:
            if trace:
                trace.write("%s.so.%d:\n" % (rec["name"], tr["major"]))
            bind_sites(img, placed.place, fgx_imports.unpack(tr["blocks_raw"]["IMPS"]),
                       libs, L.name, trace, True, {"lookups": 0, "sites":
                                                   {k: 0 for k in fgx_imports.SITES}})
        libs[L.name] = L
    bind_sites(img, {i: (i, 0) for i in range(len(prog["segs"]))}, table, libs,
               os.path.basename(prog_path), trace, patch_data, report)
    for rec in table["libs"]:
        L = libs[rec["name"]]
        report["libs"][L.name] = ("prebound" if rec["crc"] == L.tr["crc"]
                                  and rec["core_base"] == L.base else "by name")
    report["lowest"] = lowest
    report["copies"] = copies
    report["lim"] = fit(img, table, libs, lowest)
    if trace:
        trace.write("\t%d names looked up\n" % report["lookups"])
    raw = fgx_ld.read_dyn_trailer(prog["trailer"])["blocks_raw"]
    entry = struct.unpack_from("<H", raw["ENTR"], 0)[0] if "ENTR" in raw else \
        struct.unpack_from("<H", prog["head"], 8)[0]
    report["table"] = table
    return img, entry, report


def rotl(v, n):
    n &= 15
    return ((v << n) | (v >> (16 - n))) & 0xFFFF if n else v


def digest(img, table, report):
    """The binding's digest (shared libc SP4 spec, section 9): in IMPS
    order, each site's word after binding, and for a call or a pointer its
    bank normalised to 16 * (the import's library index) + (the library
    code segment it names).  (digest, sites walked)."""
    h = n = 0
    for im in table["imports"]:
        for k in fgx_imports.SITES:
            for site in im[k]:
                s, o = site[0], site[1]
                n += 1
                bs = bytes(img.segs[s][o:o + 2])
                if k != "data":
                    bs += bytes([16 * im["lib"] + report["segs"][im["name"]]])
                for x in bs:
                    h = rotl(h, 1) ^ x
    return h, n


def startup(copies, lowest, entry):
    """The bound image's startup, at the end of segment 0: copy each core
    template to its base in the data bank, set HEAP_LIM to the lowest base,
    enter _crt0_lib.  S, P and DBR are left as the loader set them, so
    _libc_start still finds the kernel's frame at S+4.

    Segment 0 is shared text, and the loader applies its relocs only at the
    first load (src/kernel/far/loader.s skips a cached text's), so nothing
    here may name the data bank: a byte loop reads each template through a
    long address whose bank -- a library segment's, the same for every
    sharer -- is a reloc, and stores through (1,S),Y, which is DBR:base,
    this process's own data bank.  An MVN would need the data bank as an
    immediate.  Then each fixup's bank byte gets that bank, read from DBR
    once per core, as the binder sets a dynamic program's (ld_bind.c).
    The closing JMP names segment 0 itself: when the loader may place that
    segment by size, the JMP's operand carries an offset reloc ("self")."""
    b, rel = bytearray(b"\x08\xC2\x30"), []             # PHP; REP #$30
    for seg, off, base, size, fixups in copies:
        if size == 0:
            continue
        b += b"\xF4" + struct.pack("<H", base)          # PEA core base: 1,S
        b += b"\xA2" + struct.pack("<H", off)           # LDX #template
        b += b"\xA0\x00\x00"                            # LDY #0
        b += b"\xE2\x20"                                # SEP #$20
        rel += [(len(b) + 3, seg)]
        b += b"\xBF\x00\x00\x00"                        # loop: LDA template,X (long)
        b += b"\x93\x01"                                # STA (1,S),Y
        b += b"\xE8\xC8"                                # INX; INY
        b += b"\xC0" + struct.pack("<H", size)          # CPY #size
        b += b"\xD0\xF3"                                # BNE loop (-13)
        if fixups:
            b += b"\x8B\x68"                            # PHB; PLA: A = DBR
            for f in fixups:
                b += b"\x8D" + struct.pack("<H", base + f)   # STA |fixup bank
        b += b"\xC2\x20"                                # REP #$20
        b += b"\x68"                                    # PLA: drop the base
    b += b"\xA9" + struct.pack("<H", lowest)            # LDA #lowest core
    b += b"\x8D" + struct.pack("<H", fgx_ld.HEAP_LIM)   # STA HEAP_LIM
    b += b"\x28"                                        # PLP
    rel += [(len(b) + 1, "self")]                       # segment 0's own address
    b += b"\x4C" + struct.pack("<H", entry)             # JMP _crt0_lib
    return bytes(b), rel


def write(img, head, entry, out):
    n = len(img.segs)
    if n > MAX_SEGS:
        die("the image needs %d segments; the loader takes %d" % (n, MAX_SEGS))
    rels = sorted(set(img.relocs))
    if len({(s, o) for s, o, _t in rels}) != len(rels):
        die("two relocs at one offset name different segments")
    if len(rels) > 0xFFFF:
        die("%d relocs" % len(rels))
    h = bytearray(head)
    h[6], h[7] = n, img.n_data
    struct.pack_into("<H", h, 8, entry)
    h[10] &= ~(fgx_ld.LIB_FLAG | fgx_ld.DYN_FLAG) & 0xFF
    struct.pack_into("<H", h, 11, len(rels))
    body = bytearray(h)
    for s, b, k, fl in zip(img.segs, img.bss, img.kinds, img.flags):
        body += struct.pack("<HHBB2x", len(s), b, k, fl)
    for s in img.segs:
        body += s
    for r in rels:
        body += struct.pack("<BHB", *r)
    tmp = out + ".tmp"
    try:
        with open(tmp, "wb") as f:
            f.write(body)
        os.replace(tmp, out)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prog", required=True)
    ap.add_argument("--out")
    ap.add_argument("--digest", action="store_true",
                    help="print the binding's digest; write no image")
    ap.add_argument("--lib-dir", default=os.path.join(os.path.dirname(
        os.path.dirname(HERE)), "lib"))
    ap.add_argument("--so", action="append", default=[], help="NAME=PATH")
    ap.add_argument("--trace", action="store_true")
    ap.add_argument("--no-data-sites", action="store_true")
    ap.add_argument("--conf", help="the ld.so.conf naming the boot set "
                    "(default: this tree's disk_src/etc/ld.so.conf)")
    a = ap.parse_args()
    override = dict(s.split("=", 1) for s in a.so)
    img, entry, rep = bind(a.prog, a.lib_dir, override,
                           sys.stdout if a.trace else None, not a.no_data_sites,
                           a.conf)
    if a.digest:
        h, n = digest(img, rep["table"], rep)
        print("LDB sites %04x n=%d" % (h, n))
        return 0
    if not a.out:
        die("--out names the image to write")
    code, rel = startup(rep["copies"], rep["lowest"], entry)
    at = len(img.segs[0])
    img.segs[0] += code
    if len(img.segs[0]) > 0xFFFF:
        die("segment 0 and the startup routine are %d bytes" % len(img.segs[0]))
    for off, tgt in rel:
        if tgt == "self":
            if img.flags[0]:
                img.reloc(0, at + off, 0x80)            # FGX2_RELOC_ADDOFF | 0
            continue
        img.reloc(0, at + off, img.n_data if tgt == "data" else tgt)
    head = open(a.prog, "rb").read()[:HEADER]
    write(img, head, at, a.out)
    print("bind %s: %d segments, %d bytes, %d relocs; LIM $%04X"
          % (os.path.basename(a.out), len(img.segs), os.path.getsize(a.out),
             len(set(img.relocs)), rep["lim"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
