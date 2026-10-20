#!/usr/bin/env python3
"""test_fgx_ld_library.py - fgx_ld's library link (shared libc SP2 step 3).

Run from toolchain/: python3 src/ld/test_fgx_ld_library.py
"""
import json
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_ld  # noqa: E402

MACROS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "lib", "macros.s")
fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def dies(fn):
    try:
        fn()
    except SystemExit:
        return True
    return False


ROW = ("    %d |  1 core.s      %d | Macro       | 00 |         |    4 "
       "| 0B/%04X : 00 00 00 00 | %s\n")


def listing(rows):
    p = os.path.join(tempfile.mkdtemp(prefix="ldlib_"), "l.txt")
    with open(p, "w") as f:
        for i, (addr, src) in enumerate(rows, 1):
            f.write(ROW % (i, i, addr, src))
    return p


def assemble(d, name, org, body):
    """One segment, assembled with Merlin32 at `org' in bank $0B.  The PUT
    path is relative to the real directory: macOS's temp dir is behind the
    /var -> /private/var link, and Merlin resolves from where it runs."""
    with open(os.path.join(d, name + ".link.s"), "w") as f:
        f.write("                TYP    $06\n                DSK    %s\n"
                "                ORG    $0B%04X\n                MX     %%00\n"
                "                PUT    %s\n%s\n"
                % (name, org, os.path.relpath(MACROS, os.path.realpath(d)), body))
    subprocess.run(["merlin32", "-V", ".", name + ".link.s"], cwd=d,
                   check=True, capture_output=True)


def link(d, segs, n_data, extra=None):
    """fgx_ld over `segs' [(name, kind, org)]; (returncode, output bytes)."""
    m = {"output": "t", "format": "FGX3", "n_data_segment": n_data,
         "entry_offset": 0, "flags": 0,
         "segments": [dict({"bin": n, "listing": n + "_Output.txt",
                            "kind": k, "bss": 0}, **({"org": o} if o else {}))
                      for n, k, o in segs]}
    m.update(extra or {})
    mp = os.path.join(d, "t.json")
    with open(mp, "w") as f:
        json.dump(m, f)
    r = subprocess.run([sys.executable, os.path.join(HERE, "fgx_ld.py"), mp],
                       capture_output=True, text=True)
    out = os.path.join(d, "t")
    return r.returncode, (open(out, "rb").read() if r.returncode == 0 else r.stderr)


def seg_bytes(data, i):
    n = data[6]
    pos = 16 + 8 * n
    for k in range(i):
        pos += struct.unpack_from("<H", data, 16 + 8 * k)[0]
    return data[pos:pos + struct.unpack_from("<H", data, 16 + 8 * i)[0]]


CODE0 = """                FGX2_MODE 2
                FGX2_EXPORT f0
f0              RTL
                FGX2_RELOC_COUNT 2"""
DATA0 = """                FGX2_MODE 2
                FGX2_EXPORT cell
cell            DA      0
pself           FGX2_LONG_PTR _a;cell;0
pcode           FGX2_LONG_PTR _b;f0;0
_libc_blk_m     DA      0
                FGX2_RELOC_COUNT 4"""


def org():
    p = listing([(0xF004, "stdin   FGX2_LONG_PTR _Fa;foo;0"),
                 (0xF010, "        FGX2_EXPORT bar")])
    s = fgx_ld.scan_listing(p, 2, org=0xF000)
    check(s["longptr"] == [(4, "foo", 0)], "an org'd LONG_PTR row is at its segment offset")
    check(s["exports"] == {"bar": 0x10}, "an org'd export is at its segment offset")
    check(fgx_ld.scan_listing(p, 2)["exports"] == {"bar": 0xF010},
          "without org the listing address is the offset")
    check(dies(lambda: fgx_ld.scan_listing(p, 2, org=0xF008)),
          "a row below the segment's org is refused")


def org_link():
    d = tempfile.mkdtemp(prefix="ldlib_asm_")
    assemble(d, "code0", 0, CODE0)
    assemble(d, "data", 0xF000, DATA0)
    rc, out = link(d, [("code0", "CODE", 0), ("data", "DATA", 0xF000)], 1)
    check(rc == 0, "an org'd data segment links", "" if rc == 0 else out[-300:])
    if rc:
        return
    data = seg_bytes(out, 1)
    check(data[2:4] == b"\x00\xF0", "a pointer into the org'd segment holds its "
          "address $F000, not its offset", data[2:4].hex())
    check(data[6:8] == b"\x00\x00", "a pointer into an org-0 segment holds the offset",
          data[6:8].hex())


def fixups():
    relocs = [(0, 3, 1, "farcall"), (2, 6, 2, "libc_data_ptr"), (2, 10, 0, "long_ptr")]
    kept, fx = fgx_ld.split_fixups(relocs, 2, 3)
    check(kept == [(0, 3, 1, "farcall"), (2, 10, 0, "long_ptr")] and fx == [6],
          "a core pointer into the core is a fixup, others stay relocs")
    check(dies(lambda: fgx_ld.split_fixups([(0, 3, 3, "long_ptr")], 2, 3)),
          "a code pointer into a block template is refused")
    try:
        kept, fx = fgx_ld.split_fixups([(2, 12, 3, "long_ptr")], 2, 3)
    except SystemExit:
        kept, fx = None, None
    check(kept == [(2, 12, 3, "long_ptr")] and fx == [],
          "the core's pointer into a template (its block table) stays a reloc")
    check(dies(lambda: fgx_ld.split_fixups([(3, 3, 2, "long_ptr")], 2, 3)),
          "a block template pointing into the core is refused")


def exports():
    segs = [{"kind": "CODE"}, {"kind": "CODE"}, {"kind": "DATA"}, {"kind": "RODATA"}]
    by_seg = [{"printf": 5, "_libc_c_S1": 9, "_libc_c_helper": 12},
              {"strtok": 0}, {"_libc_blk_a": 0}, {"a__BT": 0}]
    core_labels = [(0xF000, "errno"), (0xF002, "_libc_c___lc_pf_n"),
                   (0xF004, "_libc_blk_a"), (0xF006, "_libc_FILE_table")]
    got = fgx_ld.library_exports(segs, by_seg, core_labels, 2, "_libc_c_", ["errno"])
    check(got == [("errno", 1, 2, 0xF000, 2), ("printf", 0, 0, 5, 0),
                  ("strtok", 0, 1, 0, 0)],
          "exports: public code names and the listed data names, sorted; statics, "
          "cells, templates and unlisted core cells out; a data export's size "
          "is the gap to the next core label", str(got))
    check(dies(lambda: fgx_ld.library_exports(
        segs, by_seg, core_labels, 2, "_libc_c_", ["errno", "environ"])),
        "a listed data export the core does not define is refused")
    check(dies(lambda: fgx_ld.library_exports(
        segs, by_seg, core_labels + [(0xF008, "printf")], 2, "_libc_c_",
        ["errno", "printf"])),
        "a name both code and data is refused")


def blocks():
    members = {"a": {"size": 4}, "b": {"size": 6}}
    cells = {"_libc_blk_a": 0xF010, "_libc_blk_b": 0xF012}
    got = fgx_ld.block_table(members, cells, {"a__BT": 0, "b__BT": 4}, 10)
    check(got == [(0xF010, 0, 4), (0xF012, 4, 6)], "the block table, by member")
    check(dies(lambda: fgx_ld.block_table(members, cells, {"a__BT": 0, "b__BT": 4}, 12)),
          "a template whose listed size disagrees with the blocks file is refused")
    check(dies(lambda: fgx_ld.block_table(members, {"_libc_blk_a": 1},
                                          {"a__BT": 0, "b__BT": 4}, 10)),
          "a member with no block cell is refused")


def core_list():
    p = os.path.join(tempfile.mkdtemp(prefix="ldlib_"), "core.list")
    with open(p, "w") as f:
        f.write("# comment\n_lc_buf\nerrno\n")
    names = {"_libc_c__lc_buf", "errno"}
    check(not dies(lambda: fgx_ld.check_core_list(p, names, "_libc_c_")),
          "core.list names defined as statics or plain names pass")
    check(dies(lambda: fgx_ld.check_core_list(p, {"errno"}, "_libc_c_")),
          "a core.list name no member defines is refused")


def _raises(fn):
    try:
        fn()
    except ValueError:
        return True
    return False


def trailer_v2():
    ex = [("errno", 1, 3, 0xF800, 2), ("puts", 0, 0, 0x0123, 0)]
    t = fgx_ld.library_trailer((1, 0), 3, 4, 0xF700, 0x0900, ex,
                               [(0xF810, 0, 6)], [0x10], extra=b"CSIT" +
                               struct.pack("<I", 3) + bytes([1, 0x34, 0x12]))
    r = fgx_ld.read_trailer(t)
    check(r["version"] == 2, "trailer version 2")
    check(r["exports"] == ex, "exports round-trip with sizes", str(r["exports"]))
    check(r["blocks"] == [(0xF810, 0, 6)] and r["fixups"] == [0x10],
          "blocks and fixups round-trip")
    check(r["crc"] == r["checksum"], "crc over the export records")
    check(r["blocks_raw"].get("CSIT") == bytes([1, 0x34, 0x12]),
          "a block the core reader does not decode is kept")
    bad = bytearray(t)
    bad[4] = 1
    check(_raises(lambda: fgx_ld.read_trailer(bytes(bad))), "version 1 refused")


def trailer():
    ex = [("errno", 1, 2, 0xF000, 2), ("printf", 0, 0, 5, 0)]
    t = fgx_ld.library_trailer((1, 0), 2, 3, 0xF000, 0x0FF8, ex, [(0xF010, 0, 4)], [6])
    r = fgx_ld.read_trailer(t)
    check((r["major"], r["minor"], r["core"], r["templates"], r["core_base"],
           r["core_size"]) == (1, 0, 2, 3, 0xF000, 0x0FF8), "trailer header round-trips")
    check(r["exports"] == ex and r["blocks"] == [(0xF010, 0, 4)] and r["fixups"] == [6],
          "trailer tables round-trip")
    t2 = fgx_ld.library_trailer((1, 0), 2, 3, 0xF000, 0x0FF8,
                                [ex[0], ("printf", 0, 0, 6, 0)], [(0xF010, 0, 4)], [6])
    check(fgx_ld.read_trailer(t2)["checksum"] != r["checksum"],
          "moving one export changes the checksum")
    check(r["crc"] == r["checksum"], "the stored checksum is the records' CRC")
    bad = bytearray(t)
    bad[bad.index(b"errno")] ^= 0x20
    r3 = fgx_ld.read_trailer(bytes(bad))
    check(r3["crc"] != r3["checksum"], "a corrupted export record fails its CRC")


def lower_so(d):
    """A one-segment library file exporting strcpy (code) and errno (data),
    with its core listing in a directory NOT named after it: lowerbuild/,
    which also defines the private cell args_env."""
    tr = fgx_ld.library_trailer((1, 0), 0, 0, 0xF800, 0x10,
                                [("errno", 1, 0, 0xF800, 2),
                                 ("strcpy", 0, 0, 0x0200, 0)], [], [])
    head = (b"FGX3" + b"\0\0" + bytes([1, 0]) + struct.pack("<H", 0)
            + bytes([fgx_ld.LIB_FLAG]) + struct.pack("<H", 0) + bytes([2, 0, 0]))
    seg = struct.pack("<HHB", 4, 0, 0) + b"\0\0\0"
    so = os.path.join(d, "lower.so.1.0")
    with open(so, "wb") as f:
        f.write(head + seg + b"\xEA" * 4 + tr)
    os.makedirs(os.path.join(d, "lowerbuild"), exist_ok=True)
    lst = listing([(0xF800, "errno           DA      0"),
                   (0xF802, "args_env        DS      2")])
    dst = os.path.join(d, "lowerbuild", "core_Output.txt")
    os.replace(lst, dst)
    return so, dst


def imports_link():
    """A library link imports calls from a lower library's exports, refuses
    its private cells, and names its block cells by its own prefix."""
    import fgx_imports
    d = tempfile.mkdtemp(prefix="ldlib_imp_")
    so, lst = lower_so(d)
    code = ("                FGX2_MODE 2\n                FGX2_EXPORT g\n"
            "g               FGX2_FARCALL strcpy\n                RTL\n"
            "                FGX2_RELOC_COUNT 3")
    assemble(d, "code0", 0, code)
    assemble(d, "data", 0xF000, "                FGX2_MODE 2\n"
             "                FGX2_EXPORT cell\ncell            DA      0\n"
             "_libt_blk_m     DA      0\n                FGX2_RELOC_COUNT 2")
    assemble(d, "tmpl", 0, TMPL)
    with open(os.path.join(d, "blocks.json"), "w") as f:
        json.dump({"members": {"m": {"statics": [], "size": 2}}}, f)
    with open(os.path.join(d, "data.exports"), "w") as f:
        f.write("cell\n")
    lib = {"library": {"core": 1, "templates": 2, "blocks": "blocks.json",
                       "data_exports": "data.exports", "blk_prefix": "_libt_blk_",
                       "static_prefix": "_libt_", "version": [1, 0]},
           "imports": [[so, lst]]}
    segs = [("code0", "CODE", 0), ("data", "DATA", 0xF000), ("tmpl", "RODATA", 0)]
    rc, out = link(d, segs, 1, lib)
    check(rc == 0, "a library with a non-libc block prefix and no core list "
          "links, importing strcpy", "" if rc == 0 else out[-300:])
    if rc:
        return
    c = seg_bytes(out, 0)
    check(c[0] == fgx_ld.JSL_OPCODE and c[1:4] == bytes([0x00, 0x02, 0x00]),
          "the JSL carries strcpy's prebound offset and bank 0", c[:4].hex())
    nrel = struct.unpack_from("<H", out, 11)[0]
    relpos = 16 + 8 * 3 + sum(struct.unpack_from("<H", out, 16 + 8 * i)[0]
                              for i in range(3))
    rels = [struct.unpack_from("<BHB", out, relpos + 4 * i) for i in range(nrel)]
    check((0, 3) not in [(r[0], r[1]) for r in rels],
          "no reloc at the import's bank byte (the binder's)", str(rels))
    t = fgx_ld.read_trailer(out[relpos + 4 * nrel:])
    check(t["blocks"] == [(0xF002, 0, 2)], "the block row found through _libt_blk_m",
          str(t["blocks"]))
    imp = fgx_imports.unpack(t["blocks_raw"].get("IMPS", b""))
    check(imp["imports"] and imp["imports"][0]["name"] == "strcpy"
          and imp["imports"][0]["call"] == [(0, 1)],
          "IMPS lists strcpy with one call site at (0, 1)", str(imp))
    check(imp["libs"][0]["name"] == "lower" and imp["libs"][0]["crc"] ==
          fgx_ld.read_trailer(open(so, "rb").read()[16 + 8 + 4:])["crc"],
          "the needed library is named with its export CRC", str(imp["libs"]))
    # An import prebound at offset 0 leaves a JSL $000000: the binder, not a
    # reloc, claims its bank, and D1b must not refuse it.
    so0 = os.path.join(d, "zero.so.1.0")
    data = bytearray(open(so).read() if False else open(so, "rb").read())
    tr0 = fgx_ld.library_trailer((1, 0), 0, 0, 0xF800, 0x10,
                                 [("errno", 1, 0, 0xF800, 2),
                                  ("strcpy", 0, 0, 0x0000, 0)], [], [])
    with open(so0, "wb") as f:
        f.write(bytes(data[:16 + 8 + 4]) + tr0)
    rc, out = link(d, segs, 1, dict(lib, imports=[[so0, lst]]))
    check(rc == 0, "an import prebound at offset 0 passes D1b",
          "" if rc == 0 else out[-200:])
    assemble(d, "code0", 0, code.replace("strcpy", "args_env"))
    rc, out = link(d, segs, 1, lib)
    check(rc == 2 and "private cell" in out,
          "a call to a lower library's private cell is refused", str(rc))


TMPL = """                FGX2_MODE 2
                FGX2_EXPORT m__BT
m__BT           DA      0
                FGX2_RELOC_COUNT 2"""


def library_link():
    """fgx_ld's library path end to end, over assembled segments: the core
    at org $F000 with a pointer into itself (a fixup), one into code (a
    reloc) and one member's block cell; a two-byte template."""
    d = tempfile.mkdtemp(prefix="ldlib_lib_")
    assemble(d, "code0", 0, CODE0)
    assemble(d, "data", 0xF000, DATA0)
    assemble(d, "tmpl", 0, TMPL)
    with open(os.path.join(d, "blocks.json"), "w") as f:
        json.dump({"members": {"m": {"statics": [{"name": "m_x", "offset": 0,
                                                  "bytes": 2, "init": False}],
                                     "size": 2}}}, f)
    for name, text in (("core.list", "cell\n"), ("data.exports", "cell\n")):
        with open(os.path.join(d, name), "w") as f:
            f.write(text)
    lib = {"library": {"core": 1, "templates": 2, "blocks": "blocks.json",
                       "core_list": "core.list", "data_exports": "data.exports",
                       "static_prefix": "_libc_c_", "version": [1, 0]}}
    segs = [("code0", "CODE", 0), ("data", "DATA", 0xF000), ("tmpl", "RODATA", 0)]
    rc, out = link(d, segs, 1, lib)
    check(rc == 0, "a library links", "" if rc == 0 else out[-300:])
    if rc:
        return
    check(out[10] & fgx_ld.LIB_FLAG, "the header flags a library")
    nrel = struct.unpack_from("<H", out, 11)[0]
    check(nrel == 1, "the core's pointer into code stays the one reloc", str(nrel))
    end = 16 + 8 * 3 + sum(struct.unpack_from("<H", out, 16 + 8 * i)[0]
                           for i in range(3)) + 4 * nrel
    t = fgx_ld.read_trailer(out[end:])
    check(t["exports"] == [("cell", 1, 1, 0xF000, 2), ("f0", 0, 0, 0, 0)],
          "exports: the code name and the listed data name", str(t["exports"]))
    check(t["blocks"] == [(0xF00A, 0, 2)], "the block row: cell, template, size",
          str(t["blocks"]))
    check(t["fixups"] == [4], "the core's pointer into itself is a fixup at "
          "its bank byte", str(t["fixups"]))
    check((t["core_base"], t["core_size"]) == (0xF000, 12), "the core's base and size")
    assemble(d, "data", 0xF000, DATA0.replace(
        "_libc_blk_m     DA      0",
        "_libc_blk_m     DA      0\npbad            FGX2_LONG_PTR _c;m__BT;0").replace(
        "FGX2_RELOC_COUNT 4", "FGX2_RELOC_COUNT 5"))
    rc, out = link(d, segs, 1, lib)
    check(rc == 0 and struct.unpack_from("<H", out, 11)[0] == 2,
          "the core's pointer into a template links as a reloc", str(rc))
    code_bad = CODE0.replace("f0              RTL",
                             "f0              RTL\ncbad            FGX2_LONG_PTR _c;m__BT;0"
                             ).replace("FGX2_RELOC_COUNT 2", "FGX2_RELOC_COUNT 3")
    assemble(d, "code0", 0, code_bad)
    assemble(d, "data", 0xF000, DATA0)
    rc, out = link(d, segs, 1, lib)
    check(rc == 2 and "block template" in out,
          "a code pointer into a block template is refused", str(rc))


def dynamic_link():
    """A dynamic program: header flags bit 2 and an FGXD trailer whose IMPS
    lists its imports with their sites."""
    import fgx_imports
    d = tempfile.mkdtemp(prefix="ldlib_dyn_")
    so, lst = lower_so(d)
    assemble(d, "code0", 0, "                FGX2_MODE 2\n"
             "                FGX2_EXPORT g\n"
             "g               FGX2_FARCALL strcpy\n                RTL\n"
             "                FGX2_RELOC_COUNT 3")
    assemble(d, "data", 0, "                FGX2_MODE 2\n"
             "cell            DA      0\n                FGX2_RELOC_COUNT 1")
    segs = [("code0", "CODE", 0), ("data", "DATA", 0)]
    rc, out = link(d, segs, 1, {"dynamic": True, "imports": [[so, lst]]})
    check(rc == 0, "a dynamic program links", "" if rc == 0 else out[-300:])
    if rc:
        return
    check(out[10] & fgx_ld.DYN_FLAG and not out[10] & fgx_ld.LIB_FLAG,
          "header flags bit 2, not bit 1", hex(out[10]))
    nrel = struct.unpack_from("<H", out, 11)[0]
    relpos = 16 + 8 * 2 + sum(struct.unpack_from("<H", out, 16 + 8 * i)[0]
                              for i in range(2))
    rels = [struct.unpack_from("<BHB", out, relpos + 4 * i) for i in range(nrel)]
    check((0, 3) not in [(r[0], r[1]) for r in rels],
          "no reloc at the import's bank byte", str(rels))
    t = fgx_ld.read_dyn_trailer(out[relpos + 4 * nrel:])
    imp = fgx_imports.unpack(t["blocks_raw"]["IMPS"])
    check(imp["imports"] and imp["imports"][0]["name"] == "strcpy"
          and imp["imports"][0]["call"] == [(0, 1)],
          "the FGXD trailer's IMPS lists strcpy with a call site at (0, 1)",
          str(imp))
    check(_raises(lambda: fgx_ld.read_dyn_trailer(b"FGXL\x02" + b"\0" * 8)),
          "read_dyn_trailer refuses a library trailer")
    rc, out = link(d, segs, 1, {"dynamic": True})
    check(rc != 0, "a dynamic link with no imports list is refused")


imports_link()
org()
org_link()
fixups()
exports()
blocks()
core_list()
trailer()
trailer_v2()
library_link()
dynamic_link()
print("FAIL: %d" % len(fails) if fails else "fgx_ld library checks passed")
sys.exit(1 if fails else 0)
