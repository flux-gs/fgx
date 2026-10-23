#!/usr/bin/env python3
"""test_dyn.py - fgx_dyn's dynamic link, host checks (shared libc SP3
step 3).  Needs a built tree: fcc compiles against build/libc.sigs and
links against lib/*.so.1.0.

Run from the toolchain root: python3 tests/dyn/test_dyn.py
"""
import os
import re
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO = os.path.dirname(ROOT)
HERE = os.path.dirname(os.path.abspath(__file__))
FCC = os.path.join(ROOT, "fcc")
SIGS = os.path.join(REPO, "build", "libc.sigs")
sys.path.insert(0, os.path.join(ROOT, "src", "ld"))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import fgx_bind  # noqa: E402
import fgx_dyn  # noqa: E402
import fgx_imports  # noqa: E402
import fgx_ld  # noqa: E402
import fgx_libso  # noqa: E402
import gen_seg1_layout  # noqa: E402
fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def compile_c(src, d, name):
    code, data = os.path.join(d, name + ".s"), os.path.join(d, name + ".data.s")
    r = subprocess.run([FCC, "--sigs", SIGS, "--data-segment", data, "-o", code, src],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit("test_dyn: %s does not compile:\n%s" % (src, r.stderr[-600:]))
    return code, data


def link(src, libs, name=None):
    """(returncode, output text, the linked file's bytes or None, link dir)."""
    name = name or os.path.splitext(os.path.basename(src))[0]
    d = tempfile.mkdtemp(prefix="dyn_%s_" % name)
    code, data = compile_c(src, d, name)
    out = os.path.join(d, name + ".bin")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_dyn.py"),
                        "--name", name, "--dir", os.path.join(d, "ld"),
                        "--code", code, "--data", data, "--lib", libs, "--out", out],
                       capture_output=True, text=True)
    return (r.returncode, r.stdout + r.stderr,
            open(out, "rb").read() if r.returncode == 0 else None,
            os.path.join(d, "ld"))


def segments(data):
    n = data[6]
    pos, out = 16 + 8 * n, []
    for i in range(n):
        size = struct.unpack_from("<H", data, 16 + 8 * i)[0]
        out.append(data[pos:pos + size])
        pos += size
    return out, pos + 4 * struct.unpack_from("<H", data, 11)[0]


def imps(data):
    _segs, end = segments(data)
    return fgx_imports.unpack(fgx_ld.read_dyn_trailer(data[end:])["blocks_raw"]["IMPS"])


def labels(listing):
    return {n: a for a, n in gen_seg1_layout.extract_labels(listing)}


def farcalls(listing):
    """[(addr, name)] of each FGX2_FARCALL row of a listing."""
    out = []
    for ln in open(listing, errors="replace"):
        cols = ln.split("|")
        if len(cols) < 8 or cols[2].strip() != "Macro":
            continue
        t = cols[7].split()
        if "FGX2_FARCALL" in t[:2]:
            out.append((int(cols[6].split("/")[1].split()[0], 16),
                        t[t.index("FGX2_FARCALL") + 1]))
    return out


def bit(bitmap, members, m):
    i = sorted(members).index(m)
    return bool(bitmap[i >> 3] & (1 << (i & 7)))


def hello():
    rc, text, data, d = link(os.path.join(HERE, "hello.c"), "libc")
    check(rc == 0, "hello links dynamically against libc", text[-600:])
    if rc:
        return
    print("  " + text.strip().split("\n")[-1])
    check(data[10] & fgx_ld.DYN_FLAG, "header flags bit 2", hex(data[10]))
    t = imps(data)
    libc = fgx_imports.file_trailer(open(fgx_dyn.fgx_libso.so_path("libc"), "rb").read())
    check([l["name"] for l in t["libs"]] == ["libc"] and t["libs"][0]["crc"] == libc["crc"],
          "IMPS needs libc, with libc.so's export CRC", str(t["libs"]))
    im = {i["name"]: i for i in t["imports"]}
    for n in ("qsort", "printf", "_libc_start", "_lib_init"):
        check(n in im and im[n]["call"], "%s is imported with a call site" % n)
    check("strcmp" in im and im["strcmp"]["ptr"], "strcmp is imported with a ptr site")
    check("_fcc_long_divs_far" in im and im["_fcc_long_divs_far"]["call"],
          "the far helper _fcc_long_divs_far is imported with a call site")
    check("_fcc_fdiv_far" not in im, "_fcc_fdiv_far is not (hello never divides floats)")
    # stdout is <stdio.h>'s &_iob[1]: the program names libc's _iob table.
    for n in ("errno", "_iob", "_libc_blktab"):
        check(n in im and im[n]["data"], "%s is imported with data sites" % n)
    segs, _end = segments(data)
    if "_iob" in im:
        addr = libc_data = {e[0]: e[3] for e in libc["exports"]}["_iob"]
        vals = [struct.unpack_from("<H", segs[s], o)[0] for s, o, _v in im["_iob"]["data"]]
        check(vals == [v for _s, _o, v in im["_iob"]["data"]],
              "each data site carries the word the link wrote there")
        check(addr in vals, "_iob's sites hold its address",
              "%04X: %s" % (libc_data, ["%04X" % v for v in vals]))
    check("errno" in im and any(s == 1 for s, _o, _v in im["errno"]["data"]),
          "errno has a data site in segment 1 (ep's initialiser)")
    s0 = os.path.join(d, "seg0_Output.txt")
    own = set(labels(s0)) | set(fgx_ld.scan_listing(s0, 2)["exports"])
    calls = {s for i in t["imports"] for s in i["call"]}
    far = [(a, n) for a, n in farcalls(s0) if n not in own]
    check(far and all((0, a + 1) in calls for a, _n in far),
          "every FGX2_FARCALL to a name segment 0 does not define is a call site",
          "%d rows; missing %s" % (len(far), [n for a, n in far if (0, a + 1) not in calls]))
    members = fgx_dyn.json.load(open(fgx_dyn.fgx_libso.lib_file("libc", "blocks")))["members"]
    bm = t["libs"][0]["bitmap"]
    check(bit(bm, members, "malloc") and bit(bm, members, "proc"),
          "the bitmap has malloc's and proc's bits set")
    check(not bit(bm, members, "ctime"), "ctime's bit is clear")
    at = labels(os.path.join(d, "seg1_Output.txt")).get("_dyn_bits_libc")
    check(at is not None and segs[1][at:at + len(bm)] == bm,
          "_dyn_bits_libc in segment 1 holds the trailer's bitmap")


def dropped():
    # hello.c calls printf only: libcurses (and with it libtermlib) is
    # offered and must not reach the table, or the binder would load both.
    rc, text, data, _d = link(os.path.join(HERE, "hello.c"), "libc,libcurses",
                              name="dropped")
    check(rc == 0, "hello links with an unused library offered", text[-600:])
    if rc:
        return
    t = imps(data)
    check([l["name"] for l in t["libs"]] == ["libc"],
          "an unreferenced library and its below leave the table",
          str([l["name"] for l in t["libs"]]))
    # curs.c uses curses: libcurses stays and brings libtermlib below it.
    rc, text, data, _d = link(os.path.join(HERE, "curs.c"), "libc,libcurses",
                              name="kept")
    check(rc == 0 and [l["name"] for l in imps(data)["libs"]]
          == ["libc", "libtermlib", "libcurses"],
          "a referenced library stays, with the library below it", text[-300:])


def ul():
    """A program defining fflush and puts shadows libc's: a warning names
    libc, and its own calls bind to its own."""
    rc, text, data, d = link(os.path.join(REPO, "src", "userland", "ul", "ul.c"),
                             "libc,libtermlib")
    check(rc == 0, "ul links against libc and libtermlib", text[-600:])
    if rc:
        return
    for n in ("fflush", "puts"):
        check("defines %s, which libc exports" % n in text,
              "a warning names %s and libc" % n)
    t = imps(data)
    im = {i["name"] for i in t["imports"]}
    check(not im & {"fflush", "puts"}, "neither is an import", str(im & {"fflush", "puts"}))
    calls = {s for i in t["imports"] for s in i["call"]}
    own = [(0, a + 1) for a, n in farcalls(os.path.join(d, "seg0_Output.txt"))
           if n == "fflush"]
    check(own and not set(own) & calls, "ul's FGX2_FARCALL fflush rows are not call sites",
          "%d rows" % len(own))


def tctest():
    """tctest's tentative `char *UP, *BC;' meets libtermlib's: no warning,
    no label of its own, UP an import with data sites."""
    rc, text, data, d = link(os.path.join(REPO, "src", "userland", "tctest", "tctest.c"),
                             "libc,libtermlib")
    check(rc == 0, "tctest links against libc and libtermlib", text[-600:])
    if rc:
        return
    check("warning" not in text, "no warning", text.strip()[-200:])
    t = imps(data)
    im = {i["name"]: i for i in t["imports"]}
    names = [l["name"] for l in t["libs"]]
    up = im.get("UP")
    check(up is not None and names[up["lib"]] == "libtermlib" and up["kind"] == 1
          and len(up["data"]) >= 2,
          "UP is a data import from libtermlib with data sites",
          "%d sites" % len(up["data"]) if up else "")
    check("BC" not in im, "BC, never named again, is not an import")
    own = labels(os.path.join(d, "seg1_Output.txt"))
    check("UP" not in own and "BC" not in own, "segment 1 has no UP or BC label")


def fit():
    """Data that fits fgx_ld's bank but ends above LIM is refused."""
    rc, text, _data, _d = link(os.path.join(HERE, "fit.c"), "libc")
    check(rc != 0 and "above LIM" in text, "a 64,000-byte bss is refused above LIM",
          text.strip()[-200:])
    d = tempfile.mkdtemp(prefix="dyn_fit_")
    small = os.path.join(d, "fit1000.c")
    with open(small, "w") as f:
        f.write(open(os.path.join(HERE, "fit.c")).read().replace("64000", "1000"))
    rc, text, _data, _d = link(small, "libc")
    check(rc == 0, "the same with 1,000 bytes links", text.strip()[-200:])


def bitmap():
    """hello's bitmap is bitmaps() over the imports its trailer lists."""
    rc, text, data, _d = link(os.path.join(HERE, "hello.c"), "libc")
    if rc:
        check(False, "hello links", text[-300:])
        return
    t = imps(data)
    bits, _need, _live = fgx_dyn.bitmaps(fgx_dyn.Libs(["libc"]),
                                         {i["name"] for i in t["imports"]})
    check(bits["libc"] == t["libs"][0]["bitmap"],
          "the bitmap equals bitmaps() over the trailer's imports",
          "%s vs %s" % (bits["libc"].hex(), t["libs"][0]["bitmap"].hex()))


def curses():
    """--lib libcurses brings libtermlib and libc, in load order; curses's
    data exports, DA among them, are data imports with sites."""
    rc, text, data, _d = link(os.path.join(HERE, "curs.c"), "libcurses")
    check(rc == 0, "curs links against libcurses", text[-600:])
    if rc:
        return
    t = imps(data)
    names = [l["name"] for l in t["libs"]]
    check(names == ["libc", "libtermlib", "libcurses"],
          "it needs libc, libtermlib and libcurses, in load order", str(names))
    im = {i["name"]: i for i in t["imports"]}
    for n in ("LINES", "COLS", "DA"):
        check(n in im and names[im[n]["lib"]] == "libcurses" and im[n]["data"],
              "%s is a data import from libcurses with sites" % n)


def shadow():
    """An initialised definition of a libc data export shadows it: a
    warning, no EQU and no import for it, the program's own label."""
    rc, text, data, d = link(os.path.join(HERE, "shadow.c"), "libc")
    check(rc == 0, "shadow links", text[-600:])
    if rc:
        return
    check("defines optind, which libc exports" in text, "a warning names optind and libc")
    im = {i["name"]: i for i in imps(data)["imports"]}
    check("optind" not in im, "optind is not an import")
    check("optarg" in im and im["optarg"]["data"], "optarg is a data import with sites")
    layout = open(os.path.join(d, "imports_layout.s")).read().split()
    check("optind" not in layout, "imports_layout.s has no EQU for optind")
    check("optind" in labels(os.path.join(d, "seg1_Output.txt")),
          "segment 1 holds the program's own optind")


def tables():
    """The tables: a cell per segment, the data segment's index, IMPS as
    the trailer has it, then a zeroed bind record of 2 + 14 bytes a
    library; each cell's bank byte is a reloc to its segment; the trailer
    names _crt0_lib's offset."""
    rc, text, data, linkdir = link(os.path.join(HERE, "hello.c"), "libc", "hello")
    check(rc == 0, "hello links with its tables", text[-400:])
    if rc:
        return
    p = fgx_bind.parse(data)
    tr = fgx_ld.read_dyn_trailer(p["trailer"])["blocks_raw"]
    seg0 = p["segs"][0][0]
    ex = fgx_ld.scan_listing(os.path.join(linkdir, "seg0_Output.txt"), 2)["exports"]
    cell = ex["_dyn_tab"]
    t = struct.unpack_from("<H", seg0, cell)[0]
    check((0, cell + 2, 0) in p["relocs"],
          "the tables' pointer's bank byte is a reloc to segment 0 (where they are)")
    n = struct.unpack_from("<H", seg0, t)[0]
    check(n == len(p["segs"]), "the table has a cell per segment", str(n))
    check(seg0[t + 2] == 1 and seg0[t + 3] == 0, "the data segment's index is 1",
          str(seg0[t + 2:t + 4].hex()))
    check(all((0, t + 4 + 4 * i + 2, i) in p["relocs"] for i in range(n)),
          "each cell's bank byte is a reloc to its segment")
    q = t + 4 + 4 * n
    ln = struct.unpack_from("<H", seg0, q)[0]
    check(seg0[q + 2:q + 2 + ln] == tr["IMPS"], "the IMPS table follows, as the trailer has it")
    nlib = tr["IMPS"][0]
    rec = seg0[q + 2 + ln:]
    check(len(rec) == 2 + 14 * nlib and not any(rec),
          "a zeroed bind record of 2 + 14 bytes a library ends the tables", rec.hex())
    check(struct.unpack_from("<H", tr["ENTR"], 0)[0] == ex["_crt0_lib"]
          and struct.unpack_from("<H", data, 8)[0] == ex["_crt0_dyn"],
          "the header enters _crt0_dyn; ENTR names _crt0_lib")


def full_seg0():
    """A program whose code segments have no room puts its tables in an
    added code segment (SP5 spec section 4.1)."""
    head = bytearray(16)
    head[6], head[7] = 2, 1
    body = bytes(head) + struct.pack("<HHB3x", 65530, 0, 0) + \
        struct.pack("<HHB3x", 4, 0, 1) + b"\0" * 65530 + b"\0" * 4
    out, tseg, t = fgx_dyn.with_tables(body, len(body), b"\0" * 64)
    p = fgx_bind.parse(out + fgx_ld.dyn_trailer(b""))
    check(len(p["segs"]) == 3 and p["segs"][2][2] == 0 and tseg == 2 and t == 0,
          "a full segment 0 gets an added code segment for its tables",
          "%d segs, tseg %r, t %r" % (len(p["segs"]), tseg, t))


def block_offsets():
    """crt0_dyn.s's B_* offsets equal ld.mod's (both read ldctl.h's layout)."""
    def equs(path):
        return {m.group(1): int(m.group(2)) for m in re.finditer(
            r"^(B_\w+)\s+EQU\s+(\d+)", open(path).read(), re.M)}
    dyn_ = equs(os.path.join(ROOT, "lib", "crt0_dyn.s"))
    mod = equs(os.path.join(REPO, "src", "modules", "ld", "ld.s"))
    check(dyn_ and all(mod.get(k) == v for k, v in dyn_.items()),
          "crt0_dyn's block offsets are ld.mod's", str(dyn_))



def binder_frames():
    """The root `ld_bind' reaches the binder and the load path in libc's
    library-mode code, so stack_frames charges them."""
    libs = fgx_dyn.Libs(["libc"])
    _b, _n, live = fgx_dyn.bitmaps(libs, {"ld_bind"})
    labels = {r.split()[0] for sect in live["libc"] for r in sect if r[:1].strip()}
    check({"ld_bind", "ld_need"} <= labels, "ld_bind reaches the load path",
          str(sorted(labels & {"ld_bind", "ld_need", "ld_fill"})))


def no_text_store():
    """crt0_lib writes nothing into its own code segment, which is shared
    text (SP5 spec section 5.1): _lib_copy's MVN is a cell in the data
    bank."""
    src = open(os.path.join(ROOT, "lib", "crt0_lib.s")).read()
    check("_lib_copy_mvn" not in src and "_lib_copy_cell" in src,
          "_lib_copy's MVN is the data bank's _lib_copy_cell")


def multi():
    """Three code segments: sites in each, the tables in the roomiest, a
    cell per segment (SP5 spec sections 4, 4.1)."""
    d = tempfile.mkdtemp(prefix="dyn_multi_")
    src = os.path.join(REPO, "src", "userland", "dynmulti")
    c0, d0 = compile_c(os.path.join(src, "dynmulti.c"), d, "dynmulti")
    c2, d2 = compile_c(os.path.join(src, "dynmulti2.c"), d, "dynmulti2")
    c3, d3 = compile_c(os.path.join(src, "dynmulti3.c"), d, "dynmulti3")
    out = os.path.join(d, "dynmulti.bin")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_dyn.py"),
                        "--name", "dynmulti", "--dir", os.path.join(d, "ld"),
                        "--code", c0, "--code-seg", c2, "--code-seg", c3,
                        "--data", ",".join([d0, d2, d3]), "--lib", "libc", "--out", out],
                       capture_output=True, text=True)
    check(r.returncode == 0, "dynmulti links with three code segments",
          (r.stdout + r.stderr)[-400:])
    if r.returncode:
        return
    data = open(out, "rb").read()
    p = fgx_bind.parse(data)
    kinds = [k for _s, _b, k in p["segs"]]
    check(kinds == [0, 1, 0, 0], "segments are code, data, code, code", str(kinds))
    t = fgx_imports.unpack(fgx_ld.read_dyn_trailer(p["trailer"])["blocks_raw"]["IMPS"])
    segs_with_sites = {s[0] for im in t["imports"] for k in fgx_imports.SITES for s in im[k]}
    check({0, 2, 3} <= segs_with_sites, "every code segment carries import sites",
          str(sorted(segs_with_sites)))


def run_ld(tool, name, d, code, data, extra, sub="ld"):
    """(returncode, output text, link dir) of an fgx_dyn or fgx_static link
    in d/`sub'."""
    args = [sys.executable, os.path.join(ROOT, "src", "ld", tool), "--name", name,
            "--dir", os.path.join(d, sub), "--code", code, "--data", data,
            "--out", os.path.join(d, name + ".bin")] + extra
    r = subprocess.run(args, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr, os.path.join(d, sub)


FILLS = ",".join(os.path.join(HERE, "fill%d.s" % i) for i in (1, 2, 3))


def packed():
    """--pack: three 40000-byte TUs beside hello fill segment 0's room and
    two more code banks."""
    d = tempfile.mkdtemp(prefix="dyn_pack_")
    code, data = compile_c(os.path.join(HERE, "hello.c"), d, "hello")
    rc, text, _l = run_ld("fgx_dyn.py", "hello", d, code + "," + FILLS, data,
                          ["--lib", "libc"])
    check(rc and "segment 0 is over 64 KB" in text,
          "control: the fillers as --code overflow segment 0", text[-300:])
    rc, text, _l = run_ld("fgx_dyn.py", "hello", d, code, data,
                          ["--lib", "libc", "--pack", FILLS])
    check(rc == 0, "hello links with three fillers through --pack", text[-400:])
    if rc:
        return
    data = open(os.path.join(d, "hello.bin"), "rb").read()
    kinds = [k for _s, _b, k in fgx_bind.parse(data)["segs"]]
    check(kinds[:2] == [0, 1] and len(kinds) >= 4 and set(kinds[2:]) == {0},
          "segments are code, data and at least two more code", str(kinds))
    check(len(imps(data)["imports"]) > 0, "the packed link's IMPS reads back")


def seg_cap():
    """with_tables refuses an 8-segment image whose code segments are full:
    a 9th segment must be the LIBC segment (fgx_ld)."""
    n = 8
    head = bytearray(16)
    head[6], head[7] = n, 1
    sizes = [65530 if i != 1 else 4 for i in range(n)]
    body = bytes(head) + b"".join(struct.pack("<HHB3x", sz, 0, 1 if i == 1 else 0)
                                  for i, sz in enumerate(sizes))
    body += b"".join(b"\0" * sz for sz in sizes)
    try:
        fgx_dyn.with_tables(body, len(body), b"\0" * 64)
    except SystemExit as e:
        check("eight segments" in str(e), "a full 8-segment image is refused by name",
              str(e))
    else:
        check(False, "a full 8-segment image is refused by name", "it was given a 9th")


def end_label(listing):
    """(`end''s address, the highest other data label) in a segment 1 listing."""
    lab = labels(listing)
    rest = [a for n, a in lab.items() if n != "end"]
    return lab.get("end"), max(rest)


def end_sym():
    """ld(1): `end' is "set to ... the first location above all data" when
    "referred to", and "it is erroneous to define" it -- here 4-aligned,
    as sh's arena needs.  Both linkers."""
    src = os.path.join(HERE, "end.c")
    d = tempfile.mkdtemp(prefix="dyn_end_")
    code, data = compile_c(src, d, "end")
    rc, text, ld = run_ld("fgx_dyn.py", "end", d, code, data, ["--lib", "libc"])
    check(rc == 0, "end.c links dynamically", text[-400:])
    if not rc:
        e, top = end_label(os.path.join(ld, "seg1_Output.txt"))
        check(e is not None and e % 4 == 0 and e >= top,
              "fgx_dyn: end is 4-aligned at or past the last data label",
              "end %r, last %04X" % (e, top))
    d = tempfile.mkdtemp(prefix="static_end_")
    code, data = compile_c(src, d, "end")
    rc, text, ld = run_ld("fgx_static.py", "end", d, code, data, ["--pack", FILLS])
    check(rc == 0, "end.c links statically with --pack", text[-400:])
    if not rc:
        e, top = end_label(os.path.join(ld, "seg1_Output.txt"))
        check(e is not None and e % 4 == 0 and e >= top,
              "fgx_static: end is 4-aligned at or past the last data label",
              "end %r, last %04X" % (e, top))
        m = fgx_dyn.json.load(open(os.path.join(ld, "static.json")))
        code_segs = [s for s in m["segments"] if s["kind"] == "CODE"
                     and not s["bin"].startswith("bank")]
        check(len(code_segs) >= 3, "fgx_static packs the fillers into seg0 and "
              "extra code segments", str([s["bin"] for s in m["segments"]]))
    # A program that never names end gets none; one that defines it is refused.
    d = tempfile.mkdtemp(prefix="dyn_noend_")
    code, data = compile_c(os.path.join(HERE, "hello.c"), d, "hello")
    rc, text, ld = run_ld("fgx_dyn.py", "hello", d, code, data, ["--lib", "libc"])
    check(rc == 0 and "end" not in labels(os.path.join(ld, "seg1_Output.txt")),
          "a program that does not refer to end gets none", text[-300:])
    with open(data, "a") as f:
        f.write("end             DS      2\n")
    for tool, extra in (("fgx_dyn.py", ["--lib", "libc"]), ("fgx_static.py", [])):
        rc, text, ld = run_ld(tool, "hello", d, code, data, extra, tool[:-3])
        check(rc and "end" in text and "erroneous" in text,
              "%s refuses a program that defines end" % tool, text[-300:])


def stack_pad():
    """--stack-pad reaches fgx_ld's manifest, in both linkers."""
    d = tempfile.mkdtemp(prefix="dyn_pad_")
    code, data = compile_c(os.path.join(HERE, "hello.c"), d, "hello")
    for tool, extra, man in (("fgx_dyn.py", ["--lib", "libc"], "dyn.json"),
                             ("fgx_static.py", [], "static.json")):
        rc, text, ld = run_ld(tool, "hello", d, code, data,
                              extra + ["--stack-pad", "2304"], tool[:-3])
        check(rc == 0, "%s links with --stack-pad" % tool, text[-300:])
        if not rc:
            m = fgx_dyn.json.load(open(os.path.join(ld, man)))
            check(m.get("stack_pad") == 2304, "%s carries stack_pad 2304" % man,
                  str(m.get("stack_pad")))


def fgxutil():
    """libfgx.so and libutil.so, each above libc: a program offered both
    keeps only the one it calls."""
    for src, lib, name in (("fgxlib.c", "libfgx", "ticks"),
                           ("utillib.c", "libutil", "logwtmp")):
        rc, text, data, _d = link(os.path.join(HERE, src),
                                  "libc,libfgx,libutil", name=lib)
        check(rc == 0, "%s links against %s.so" % (src, lib), text[-600:])
        if rc:
            continue
        t = imps(data)
        check([l["name"] for l in t["libs"]] == ["libc", lib],
              "%s's table needs libc and %s only" % (src, lib),
              str([l["name"] for l in t["libs"]]))
        check(any(i["name"] == name and i["call"] for i in t["imports"]),
              "%s is imported with a call site" % name)
    # Both at once: each library's block table is its own import.  Their
    # cores are disjoint, or fgx_dyn could not tell the two tables' data
    # sites apart (both were once assembled at $F699).
    rc, text, data, _d = link(os.path.join(HERE, "fgxutil.c"), "libc,libfgx,libutil")
    check(rc == 0, "fgxutil.c links against libfgx.so and libutil.so", text[-600:])
    if rc == 0:
        t = imps(data)
        bt = sorted((i["name"], len(i["data"])) for i in t["imports"]
                    if i["name"].endswith("_blktab") and i["lib"])
        check(bt == [("_libfgx_blktab", 1), ("_libutil_blktab", 1)],
              "each library's block table is imported once, by its own name", str(bt))
    # From the trailers, not through fgx_dyn.Libs, which refuses an overlap
    # by exiting and would end this script instead of failing the check.
    trs = {n: fgx_imports.file_trailer(open(fgx_libso.so_path(n), "rb").read())
           for n in fgx_libso.LIBS}
    spans = sorted((tr["core_base"], tr["core_base"] + tr["core_size"], n)
                   for n, tr in trs.items())
    check(all(b >= e for (_a, e, _x), (b, _f, _y) in zip(spans, spans[1:])),
          "no two libraries' cores overlap",
          " ".join("%s $%04X-$%04X" % (n, a, e - 1) for a, e, n in spans))


def carrier():
    """The long long carrier's high words are libc's cells, not the
    program's.  libc.so's long long and double entries read their operands'
    w2 and w3 from libc's _fcc_q2 ... _fcc_qb3; a program holding copies of
    its own wrote its operands where those entries never look, and every
    double result came back as the first operand unchanged."""
    rc, text, data, d = link(os.path.join(HERE, "carrier.c"), "libc")
    check(rc == 0, "carrier links dynamically against libc", text[-600:])
    if rc:
        return
    im = {i["name"]: i for i in imps(data)["imports"]}
    defined = labels(os.path.join(d, "seg1_Output.txt"))
    for n in ("_fcc_q2", "_fcc_q3", "_fcc_qb2", "_fcc_qb3"):
        check(n in im and im[n]["data"], "%s is imported from libc with data sites" % n)
        check(n not in defined, "the program holds no %s of its own" % n)


hello()
dropped()
ul()
tctest()
fit()
bitmap()
curses()
shadow()
tables()
full_seg0()
multi()
packed()
seg_cap()
end_sym()
stack_pad()
no_text_store()
block_offsets()
binder_frames()
fgxutil()
carrier()
print("FAIL: %d" % len(fails) if fails else "dyn checks passed")
sys.exit(1 if fails else 0)
