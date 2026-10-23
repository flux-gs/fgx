#!/usr/bin/env python3
"""libc_so_check.py - what libc.so.1.0 must hold (shared libc SP2 spec,
section 8).

  - every export resolves inside its segment (code) or the core (data), the
    data exports are exactly lib/libc_c/data.exports, and the stored
    checksum is the export records' CRC;
  - the boundary holds: libc.so exports no libfgx or libutil name, and no
    bank source uses PILE_CALL;
  - every FGX2_FARCALL/FARJUMP a bank's listing shows has its bank reloc;
  - nothing points into a block template, and no template points into the
    core;
  - the templates tile their segment and every block cell is in the core;
  - every fixup is in the core, and there is at least one (libc:
    findiop.c's _smallbuf);
  - the far helper entries are exactly lib/libc_so_helpers.s's, each a JSR
    to its own helper followed by RTL.

--self-test runs the checks on the built file (clean) and on four broken
copies that must fail: one JSL's reloc removed, one export moved past its
segment's end, one byte of an export name changed under its checksum, one
_libc_blktab row's size changed in the core, one far helper entry's export
moved off its JSR.

Run: python3 tools/libc_so_check.py [--self-test]   (after make -C toolchain libc_so)
"""
import glob
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TC = os.path.join(ROOT, "toolchain")
sys.path.insert(0, os.path.join(TC, "src", "ld"))
sys.path.insert(0, os.path.join(TC, "tools"))
import fgx_ld  # noqa: E402
import fgx_imports  # noqa: E402
import fgx_libso  # noqa: E402
import gen_seg1_layout  # noqa: E402

NAME = "libc"
for _i, _a in enumerate(sys.argv):
    if _a == "--lib" and _i + 1 < len(sys.argv):
        NAME = sys.argv[_i + 1]
SO = fgx_libso.so_path(NAME)
D = os.path.join(TC, "lib", fgx_libso.LIBS[NAME]["dir"])


def parse(data):
    """Header fields, segments, kinds, relocs, the reloc table's offset and
    the trailer (None when the flag is clear)."""
    n, flags = data[6], data[10]
    nrel = struct.unpack_from("<H", data, 11)[0]
    segs, kinds, pos = [], [], 16 + 8 * n
    for i in range(n):
        size, _bss, kind = struct.unpack_from("<HHB", data, 16 + 8 * i)
        segs.append(data[pos:pos + size])
        kinds.append(kind)
        pos += size
    relpos = pos
    relocs = [struct.unpack_from("<BHB", data, pos + 4 * i) for i in range(nrel)]
    pos += 4 * nrel
    tr = fgx_ld.read_trailer(data[pos:]) if flags & fgx_ld.LIB_FLAG else None
    return {"segs": segs, "kinds": kinds, "relocs": relocs, "relpos": relpos,
            "trailer": tr, "trailer_pos": pos}


def label_addrs(listing, names):
    """{label: its address} for the column-1 labels `names' in a listing."""
    out = {}
    for raw in open(listing, errors="replace"):
        parts = [p.strip() for p in raw.split("|")]
        if len(parts) < 8 or "/" not in parts[6]:
            continue
        tok = parts[7].split()
        if tok and tok[0] in names:
            out.setdefault(tok[0], int(parts[6].split()[0].split("/")[1], 16))
    return out


def boundary_names():
    names = set()
    for p in [os.path.join(TC, "lib", "libfgx.s"),
              os.path.join(ROOT, "build", "static_libs", "libutil.s")]:
        for ln in open(p, errors="replace"):
            t = ln.split()
            if t[:1] == ["FGX2_EXPORT"] and len(t) > 1:
                names.add(t[1])
    return names


def check(data, d):
    p = parse(data)
    tr, segs, kinds = p["trailer"], p["segs"], p["kinds"]
    if tr is None:
        return ["no library trailer (header flags bit 1 clear)"]
    errs = []
    core, tmpl = tr["core"], tr["templates"]
    lo, hi = tr["core_base"], tr["core_base"] + tr["core_size"]
    for name, kind, seg, val, size in tr["exports"]:
        if kind == 1 and (size == 0 or val + size > hi):
            errs.append("data export %s's size %d runs outside the core" % (name, size))
        if kind == 0 and (seg >= len(segs) or kinds[seg] != 0 or val >= len(segs[seg])):
            errs.append("export %s resolves outside its code segment (%d:%#06x)"
                        % (name, seg, val))
        if kind == 1 and not lo <= val < hi:
            errs.append("data export %s at %#06x is outside the core" % (name, val))
    if tr["crc"] != tr["checksum"]:
        errs.append("export table CRC %08x is not the stored checksum %08x"
                    % (tr["crc"], tr["checksum"]))
    listed = set(fgx_ld.read_names(fgx_libso.lib_file(NAME, "exports")))
    data_ex = {e[0] for e in tr["exports"] if e[1] == 1}
    if data_ex != listed:
        errs.append("data exports differ from data.exports: %s"
                    % sorted(data_ex ^ listed))
    for n in sorted({e[0] for e in tr["exports"]} & boundary_names()
                    if NAME == "libc" else ()):
        errs.append("libc.so exports %s, a libfgx/libutil name" % n)
    for src in sorted(glob.glob(os.path.join(d, "bank*.s"))):
        if "PILE_CALL" in open(src).read():
            errs.append("%s uses PILE_CALL" % os.path.basename(src))
    have = {(s, o) for s, o, _t in p["relocs"]}
    imps = fgx_imports.unpack(tr["blocks_raw"].get("IMPS", b""))
    bound = {(sg, off + 2) for im in imps["imports"] for sg, off in im["call"]}
    errs += import_errors(p, imps)
    for k, kind in enumerate(kinds):
        if kind != 0:
            continue
        scan = fgx_ld.scan_listing(os.path.join(d, "bank%d_Output.txt" % k),
                                   len(segs))
        for addr, name, mac in scan["farcalls"]:
            if (k, addr + 3) not in have and (k, addr + 3) not in bound:
                errs.append("bank %d: %s %s at %#06x has no reloc" % (k, mac, name, addr))
    for s, o, t in p["relocs"]:
        if (t == tmpl and s != core) or (s == tmpl and t == core):
            errs.append("reloc %d:%#06x -> %d crosses a block boundary" % (s, o, t))
    offs = sorted(b[1:] for b in tr["blocks"])
    pos = 0
    for t, size in offs:
        if t != pos:
            errs.append("block templates do not tile: gap or overlap at %#06x" % pos)
        pos = t + size
    if pos != len(segs[tmpl]):
        errs.append("block templates cover %d of %d bytes" % (pos, len(segs[tmpl])))
    for cell, _t, _s in tr["blocks"]:
        if not lo <= cell < hi:
            errs.append("block cell %#06x is outside the core" % cell)
    for f in tr["fixups"]:
        if not 0 <= f < tr["core_size"]:
            errs.append("fixup %#06x is outside the core" % f)
    if NAME in ("libc", "libcurses") and not tr["fixups"]:
        errs.append("no per-process fixups (libc: _smallbuf; "
                    "curses: sflags, sstrs)")
    labels = dict((n, a) for a, n in gen_seg1_layout.extract_labels(
        os.path.join(d, "core_Output.txt")))
    tab = "_%s_blktab" % NAME
    if tab not in labels:
        errs.append("the core has no %s" % tab)
    else:
        pos, rows = labels[tab] - lo, []
        seg = segs[core]
        while struct.unpack_from("<H", seg, pos)[0]:
            cell, toff, _bank, size = struct.unpack_from("<HHHH", seg, pos)
            if (core, pos + 4) not in have:
                errs.append("%s row at %#06x has no bank reloc" % (tab, pos))
            rows.append((cell, toff, size))
            pos += 8
        if rows != [tuple(b) for b in tr["blocks"]]:
            errs.append("%s's %d rows differ from the trailer's %d "
                        "blocks" % (tab, len(rows), len(tr["blocks"])))
    if NAME != "libc":
        return errs
    # libc's half of program startup (libc_start.s), in bank 0 beside the
    # runtime its trampoline near-jumps to, and the cells a program's crt0
    # and main name.
    byname = {e[0]: e for e in tr["exports"]}
    for n in ("_libc_start", "_libc_sigtramp"):
        e = byname.get(n)
        if not e or e[1] != 0 or e[2] != 0:
            errs.append("%s is not a code export in bank 0 (%s)" % (n, e))
    for n in ("_libc_blktab", "args_argc", "args_argv", "__progname"):
        if byname.get(n, (0, 0))[1] != 1:
            errs.append("%s is not a data export" % n)
    far = [e for e in tr["exports"] if e[0].endswith("_far") and e[1] == 0]
    listed = [l.split()[1] for l in open(os.path.join(TC, "lib",
              "libc_so_helpers.s")) if l.split()[:1] == ["FGX2_EXPORT"]]
    if sorted(e[0] for e in far) != sorted(listed):
        errs.append("far helper exports %s differ from libc_so_helpers.s's %s"
                    % (sorted(e[0] for e in far), sorted(listed)))
    targets = label_addrs(os.path.join(d, "bank0_Output.txt"),
                          {e[0][:-len("_far")] for e in far})
    for name, _k, seg, off, _sz in far:
        b = segs[seg][off:off + 4]
        if len(b) < 4 or b[0] != 0x20 or b[3] != 0x6B:
            errs.append("far helper %s is not JSR/RTL (%s)" % (name, b.hex()))
        elif b[1] | b[2] << 8 != targets.get(name[:-len("_far")]):
            errs.append("far helper %s JSRs %#06x, not its helper at %s"
                        % (name, b[1] | b[2] << 8,
                           targets.get(name[:-len("_far")])))
    return errs


def LIBS_BELOW():
    return fgx_libso.LIBS[NAME]["below"]


def import_errors(p, imps):
    """A library's imports: each resolves at its ordinal in the named lower
    library; each call site's operand is the prebound offset after a JSL or
    JML; each pointer cell holds it; each data site's word lies in its
    import; each core site's word lies in the library's own core; no import
    is a lower library's private cell."""
    errs, tr, segs = [], p["trailer"], p["segs"]
    below = fgx_libso.LIBS[NAME]["below"]
    lows = {}
    for b in below:
        lows[b] = fgx_imports.file_trailer(open(fgx_libso.so_path(b), "rb").read())
    res = fgx_imports.Resolver([(fgx_libso.so_path(b), os.path.join(
        TC, "lib", fgx_libso.LIBS[b]["dir"], "core_Output.txt")) for b in below])
    def word(sg, off):
        return struct.unpack_from("<H", segs[sg], off)[0] if off + 2 <= len(segs[sg]) else -1
    for im in imps["imports"]:
        lib = imps["libs"][im["lib"]]["name"] if im["lib"] < len(imps["libs"]) else "?"
        ex = lows.get(lib, {"exports": []})["exports"]
        if im["ordinal"] >= len(ex) or ex[im["ordinal"]][0] != im["name"]:
            errs.append("import %s: %s's export at ordinal %d is %s" % (
                im["name"], lib, im["ordinal"],
                ex[im["ordinal"]][0] if im["ordinal"] < len(ex) else "none"))
        if res.private(im["name"]):
            errs.append("import %s is a private cell of %s" % (im["name"], lib))
        for sg, off in im["call"]:
            if segs[sg][off - 1] not in (fgx_ld.JSL_OPCODE, fgx_ld.JML_OPCODE) \
               or word(sg, off) != im["val"]:
                errs.append("import %s: call site %d:%#06x's operand is not "
                            "JSL/JML %#06x" % (im["name"], sg, off, im["val"]))
        for sg, off in im["ptr"]:
            if word(sg, off) != im["val"]:
                errs.append("import %s: pointer cell %d:%#06x's operand is not "
                            "%#06x" % (im["name"], sg, off, im["val"]))
        for sg, off, _orig in im["data"]:
            if not im["val"] <= word(sg, off) <= im["val"] + im["size"]:
                errs.append("import %s: data site %d:%#06x holds %#06x, outside "
                            "it" % (im["name"], sg, off, word(sg, off)))
    raw = tr["blocks_raw"].get("CSIT", b"")
    lo, hi = tr["core_base"], tr["core_base"] + tr["core_size"]
    for i in range(len(raw) // 3):
        sg, off = struct.unpack_from("<BH", raw, 3 * i)
        if not lo <= word(sg, off) <= hi:
            errs.append("core site %d:%#06x holds %#06x, outside the core"
                        % (sg, off, word(sg, off)))
    if below and "CSIT" not in tr["blocks_raw"]:
        errs.append("a library above libc carries no CSIT block")
    # A floor with a mechanism: each block-table row's `DA _<lib>_blk_<m>'
    # is a word in the core that names the core, so the site pass finds at
    # least one core site per block.
    elif below and len(raw) // 3 < len(tr["blocks"]):
        errs.append("fewer core sites (%d) than block-table rows (%d): the "
                    "site pass did not reach the core" % (len(raw) // 3,
                                                          len(tr["blocks"])))
    return errs


def report(data, d):
    p = parse(data)
    tr = p["trailer"]
    labels = sorted(gen_seg1_layout.extract_labels(os.path.join(d, "core_Output.txt")))
    imps = fgx_imports.unpack(tr["blocks_raw"].get("IMPS", b""))
    sites = {k: sum(len(i[k]) for i in imps["imports"]) for k in fgx_imports.SITES}
    csit = len(tr["blocks_raw"].get("CSIT", b"")) // 3
    def label_of(addr):
        return max((l for l in labels if l[0] <= addr), default=(0, "?"))[1]
    code = [len(s) for s, k in zip(p["segs"], p["kinds"]) if k == 0]
    nd = sum(1 for e in tr["exports"] if e[1] == 1)
    print("libc_so_check: %s clean -- %d imports (%d call, %d pointer, %d data "
          "sites), %d core sites" % (NAME, len(imps["imports"]), sites["call"],
                                     sites["ptr"], sites["data"], csit))
    print("libc_so_check: clean -- %d code banks (%s bytes), core %d bytes at "
          "$%04X, %d blocks (%d bytes), %d exports (%d code, %d data), fixups: %s"
          % (len(code), ", ".join(map(str, code)), tr["core_size"],
             tr["core_base"], len(tr["blocks"]), sum(b[2] for b in tr["blocks"]),
             len(tr["exports"]), len(tr["exports"]) - nd, nd,
             (", ".join(label_of(tr["core_base"] + f) for f in tr["fixups"])
              if 0 < len(tr["fixups"]) <= 8 else "%d" % len(tr["fixups"]))))


def retrail(data, p, imps=None, csit=None):
    """`data' with its trailer rebuilt: the IMPS and CSIT blocks replaced."""
    tr = p["trailer"]
    raw = dict(tr["blocks_raw"])
    if imps is not None:
        raw["IMPS"] = fgx_imports.pack(imps)
    if csit is not None:
        raw["CSIT"] = b"".join(struct.pack("<BH", s, o) for s, o in csit)
    extra = b"".join(fgx_ld.block(t.encode("ascii"), raw[t])
                     for t in ("IMPS", "CSIT") if t in raw)
    return data[:p["trailer_pos"]] + fgx_ld.library_trailer(
        (tr["major"], tr["minor"]), tr["core"], tr["templates"],
        tr["core_base"], tr["core_size"], tr["exports"], tr["blocks"],
        tr["fixups"], extra)


def import_controls(data, d):
    """A library with imports must fail each broken copy."""
    p = parse(data)
    imps = fgx_imports.unpack(p["trailer"]["blocks_raw"]["IMPS"])
    im = next(i for i in imps["imports"] if i["call"])
    seg, off = im["call"][0]
    # Control 6: a call site's operand is not the import's prebound offset.
    bad = bytearray(data)
    at = 16 + 8 * data[6] + sum(len(x) for x in p["segs"][:seg]) + off
    bad[at] ^= 0x01
    assert any("operand" in e for e in check(bytes(bad), d)), \
        "a call site off its prebound offset was not caught"
    # Control 7: a core site whose word lies outside the core (a call site's).
    assert any("core site" in e for e in check(retrail(data, p, csit=[(seg, off)]), d)), \
        "a core site outside the core was not caught"
    # Control 10: an empty CSIT block, as a site pass that never reached the
    # core would write.
    assert any("fewer core sites" in e for e in check(retrail(data, p, csit=[]), d)), \
        "an empty core-site list was not caught"
    # Control 8: an import naming another export's ordinal.
    import copy
    i8 = copy.deepcopy(imps)
    i8["imports"][0]["ordinal"] += 1
    assert any("ordinal" in e for e in check(retrail(data, p, imps=i8), d)), \
        "an import at the wrong ordinal was not caught"
    # Control 9: a JSL with neither a reloc nor an import call site.
    i9 = copy.deepcopy(imps)
    for x in i9["imports"]:
        if x["call"]:
            x["call"] = x["call"][1:]
            break
    assert any("has no reloc" in e for e in check(retrail(data, p, imps=i9), d)), \
        "a JSL with no reloc and no import site was not caught"


def self_test():
    data = open(SO, "rb").read()
    if NAME != "libc":
        errs = check(data, D)
        assert not errs, errs
        if LIBS_BELOW():
            import_controls(data, D)
        print("libc_so_check: %s self-test OK (clean file passes%s)" % (
            NAME, ", five broken copies fail" if LIBS_BELOW() else ""))
        return
    errs = check(data, D)
    assert not errs, errs
    p = parse(data)
    # Control 1: remove the reloc of the first JSL in bank 0.
    idx = next(i for i, (s, o, _t) in enumerate(p["relocs"])
               if s == 0 and p["segs"][0][o - 3] == fgx_ld.JSL_OPCODE)
    rel = p["relpos"] + 4 * idx
    nrel = struct.unpack_from("<H", data, 11)[0]
    bad = bytearray(data[:rel] + data[rel + 4:])
    struct.pack_into("<H", bad, 11, nrel - 1)
    assert any("has no reloc" in e for e in check(bytes(bad), D)), \
        "a JSL with no reloc was not caught"
    # Control 2: an export moved past its segment's end.
    tr = p["trailer"]
    ex = list(tr["exports"])
    i = next(i for i, e in enumerate(ex) if e[1] == 0)
    ex[i] = (ex[i][0], 0, ex[i][2], len(p["segs"][ex[i][2]]), 0)
    t2 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"],
                                tr["templates"], tr["core_base"], tr["core_size"],
                                ex, tr["blocks"], tr["fixups"])
    bad2 = data[:p["trailer_pos"]] + t2
    assert any("resolves outside" in e for e in check(bad2, D)), \
        "an export past its segment was not caught"
    # Control 3: one byte of the first export's name changed, checksum kept.
    bad3 = bytearray(data)
    first = p["trailer_pos"] + struct.calcsize(fgx_ld.TRAILER_HEAD) + 8 + 1
    bad3[first] ^= 0x20
    assert any("CRC" in e for e in check(bytes(bad3), D)), \
        "a corrupted export record was not caught"
    # Control 4: one _libc_blktab row's size changed in the core.
    n = data[6]
    core_at = 16 + 8 * n + sum(struct.unpack_from("<H", data, 16 + 8 * i)[0]
                               for i in range(tr["core"]))
    labels = dict((nm, a) for a, nm in gen_seg1_layout.extract_labels(
        os.path.join(D, "core_Output.txt")))
    row = core_at + labels["_libc_blktab"] - tr["core_base"]
    bad4 = bytearray(data)
    struct.pack_into("<H", bad4, row + 6, struct.unpack_from("<H", data, row + 6)[0] + 1)
    assert any("_libc_blktab's" in e for e in check(bytes(bad4), D)), \
        "a block table out of step with the trailer was not caught"
    # Control 5: a far entry's export moved one byte off its JSR.
    ex5 = list(tr["exports"])
    i5 = next(i for i, e in enumerate(ex5) if e[0].endswith("_far"))
    ex5[i5] = (ex5[i5][0], 0, ex5[i5][2], ex5[i5][3] + 1, 0)
    t5 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"],
                                tr["templates"], tr["core_base"],
                                tr["core_size"], ex5, tr["blocks"],
                                tr["fixups"])
    assert any("is not JSR/RTL" in e for e in
               check(data[:p["trailer_pos"]] + t5, D)), \
        "a far entry off its JSR was not caught"
    print("libc_so_check: self-test OK (clean file passes, five broken copies fail)")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    data = open(SO, "rb").read()
    errs = check(data, D)
    for e in errs:
        print("libc_so_check: " + e)
    if errs:
        return 1
    report(data, D)
    return 0


if __name__ == "__main__":
    sys.exit(main())
