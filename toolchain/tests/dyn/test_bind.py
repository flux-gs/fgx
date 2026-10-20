#!/usr/bin/env python3
"""test_bind.py - fgx_bind's host checks (shared libc SP3 step 4).  Needs a
built tree (build/libc.sigs, lib/*.so.1.0).

Run from the toolchain root: python3 tests/dyn/test_bind.py
"""
import contextlib
import io
import os
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPO = os.path.dirname(ROOT)
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "src", "ld"))
import fgx_bind  # noqa: E402
import fgx_imports  # noqa: E402
import fgx_ld  # noqa: E402
import fgx_libso  # noqa: E402
fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def so(name):
    data = open(fgx_libso.so_path(name), "rb").read()
    lib = fgx_bind.parse(data)
    return lib, fgx_ld.read_trailer(lib["trailer"])


def layout():
    """libc's banks, core and templates placed; its relocs renumbered."""
    prog = fgx_bind.parse(open(dyn("hello", os.path.join(HERE, "hello.c"), "libc"),
                               "rb").read())
    img = fgx_bind.Image(prog)
    lib, tr = so("libc")
    nb = tr["core"]                         # libc's code banks
    L = 1 + nb                              # the last of them in the image
    p = img.add_lib("libc", lib, tr)
    check(len(img.segs) == 2 + nb and p.seg_of == {i: 2 + i for i in range(nb)}
          and p.last == L, "libc's %d banks are image segments 2-%d" % (nb, L),
          str(p.seg_of))
    core, tmpl = lib["segs"][tr["core"]][0], lib["segs"][tr["templates"]][0]
    last = img.segs[L]
    check(p.core_at == len(lib["segs"][nb - 1][0]) and p.tmpl_at == p.core_at + len(core)
          and len(last) == p.tmpl_at + len(tmpl),
          "the core and the templates follow the last bank's bytes", "%d %d %d"
          % (p.core_at, p.tmpl_at, len(last)))
    fx = [(s, o) for s, o, t in img.relocs if t == img.n_data and s >= 2]
    check(not fx and len(tr["fixups"]) == 3,
          "libc's three fixups carry no reloc into the data segment: the "
          "startup sets their bank from DBR", str(fx))
    moved = [(o, t) for s, o, t in lib["relocs"] if s == tr["core"] and t == tr["templates"]]
    good = all(struct.unpack_from("<H", last, p.core_at + o - 2)[0]
               == (struct.unpack_from("<H", core, o - 2)[0] + p.tmpl_at) & 0xFFFF
               and (L, p.core_at + o, L) in img.relocs for o, _t in moved)
    check(moved and good, "each block-table pointer's offset moved by the "
          "templates' offset, its bank the last bank's", "%d rows" % len(moved))
    lost = [(s, o, t) for s, o, t in lib["relocs"]
            if (p.place[s][0], p.place[s][1] + o, p.place[t][0]) not in img.relocs]
    check(not lost and sum(1 for s, o, t in img.relocs if s >= 2)
          == len(lib["relocs"]),
          "every libc reloc is carried at its new place with its new target",
          str(lost[:4]))
    try:
        img.reloc(2, len(img.segs[2]), 3)
    except SystemExit as e:
        check("outside" in str(e), "a reloc past its segment's end is refused", str(e))
    else:
        check(False, "a reloc past its segment's end is refused")


def dyn(name, src, libs):
    """Compile and dynamically link `src'; the fgx_dyn output's path."""
    d = tempfile.mkdtemp(prefix="bind_%s_" % name)
    code, data = os.path.join(d, name + ".s"), os.path.join(d, name + ".data.s")
    subprocess.run([os.path.join(ROOT, "fcc"), "--sigs",
                    os.path.join(REPO, "build", "libc.sigs"),
                    "--data-segment", data, "-o", code, src], check=True)
    out = os.path.join(d, name + ".dyn")
    subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_dyn.py"),
                    "--name", name, "--dir", os.path.join(d, "ld"), "--code", code,
                    "--data", data, "--lib", libs, "--out", out],
                   check=True, stdout=subprocess.DEVNULL)
    return out


def repack(path, out, fn):
    """Copy a dynamic program with its IMPS table changed by fn(table)."""
    data = open(path, "rb").read()
    p = fgx_bind.parse(data)
    end = len(data) - len(p["trailer"])
    t = fgx_imports.unpack(fgx_ld.read_dyn_trailer(p["trailer"])["blocks_raw"]["IMPS"])
    fn(t)
    with open(out, "wb") as f:
        f.write(data[:end] + fgx_ld.dyn_trailer(fgx_ld.block(b"IMPS", fgx_imports.pack(t))))
    return out


def moved_libc(d, by):
    """d/libc.so.1.0: libc.so with every data export's address moved by
    `by' in its trailer -- a different CRC, the same core."""
    data = open(fgx_libso.so_path("libc"), "rb").read()
    p = fgx_bind.parse(data)
    tr = fgx_ld.read_trailer(p["trailer"])
    ex = [(n, k, s, (v + by) & 0xFFFF if k == 1 else v, sz)
          for n, k, s, v, sz in tr["exports"]]
    extra = b"".join(fgx_ld.block(t.encode(), b) for t, b in tr["blocks_raw"].items()
                     if t not in ("EXPT", "BLKS", "FIXS"))
    t2 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"], tr["templates"],
                                tr["core_base"], tr["core_size"], ex, tr["blocks"],
                                tr["fixups"], extra)
    out = os.path.join(d, "libc.so.1.0")
    with open(out, "wb") as f:
        f.write(data[:len(data) - len(p["trailer"])] + t2)
    return out


def grown_libc(d):
    """d/libc.so.1.0 and d/libtermlib.so.1.0: a libc whose core is two bytes
    larger -- two bytes on its end, its base and every data export two
    lower, so its CRC differs -- beside the shipped libfgx (resident from
    boot, /etc/ld.so.conf) and termlib, which must then
    stack two bytes lower and move its core sites."""
    data = open(fgx_libso.so_path("libc"), "rb").read()
    p = fgx_bind.parse(data)
    tr = fgx_ld.read_trailer(p["trailer"])
    segs = [bytearray(s) for s, _b, _k in p["segs"]]
    segs[tr["core"]] += b"\0\0"
    ex = [(n, k, s, (v - 2) & 0xFFFF if k == 1 else v, sz)
          for n, k, s, v, sz in tr["exports"]]
    t2 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"], tr["templates"],
                                tr["core_base"] - 2, tr["core_size"] + 2, ex,
                                tr["blocks"], tr["fixups"])
    head = bytearray(p["head"])
    body = bytearray()
    for (s, b, k), seg in zip(p["segs"], segs):
        body += struct.pack("<HHB3x", len(seg), b, k)
    body += b"".join(segs)
    body += b"".join(struct.pack("<BHB", *r) for r in p["relocs"])
    with open(os.path.join(d, "libc.so.1.0"), "wb") as f:
        f.write(head + body + t2)
    shutil.copy(fgx_libso.so_path("libtermlib"), d)
    shutil.copy(fgx_libso.so_path("libfgx"), d)       # the rest of the boot set


def delta():
    """A library below that grew moves the one above: termlib's base and its
    core sites two lower, the program's termlib data sites too."""
    tc = dyn("tctest", os.path.join(REPO, "src", "userland", "tctest", "tctest.c"),
             "libc,libtermlib")
    a, _e, ra = fgx_bind.bind(tc, fgx_libso.LIB)
    # The boot set (libc, then /etc/ld.so.conf's libfgx) holds its slots, so
    # termlib binds where it was assembled; with no ld.so.conf it would lie
    # directly under libc and bind by name.
    _lt0, ttr0 = so("libtermlib")
    check(ra["libs"] == {"libc": "prebound", "libtermlib": "prebound"}
          and ra["copies"][1][2] == ttr0["core_base"],
          "termlib binds prebound under the boot set", "%s %04X" % (ra["libs"],
                                                                  ra["copies"][1][2]))
    empty = tempfile.mkstemp(prefix="ldconf_")[1]
    _c, _e, rc = fgx_bind.bind(tc, fgx_libso.LIB, conf=empty)
    check(rc["copies"][1][2] == so("libc")[1]["core_base"] - ttr0["core_size"]
          and rc["libs"]["libtermlib"] == "by name",
          "with no ld.so.conf termlib stacks under libc alone, by name",
          "%s %04X" % (rc["libs"], rc["copies"][1][2]))
    d = tempfile.mkdtemp(prefix="bind_grown_")
    grown_libc(d)
    b, _e, rb = fgx_bind.bind(tc, d)
    check(rb["libs"] == {"libc": "by name", "libtermlib": "by name"},
          "both libraries bind by name", str(rb["libs"]))
    _lt, ttr = so("libtermlib")
    check(rb["copies"][1][2] == ttr["core_base"] - 2, "termlib stacks two lower",
          "%04X" % rb["copies"][1][2])
    csit = ttr["blocks_raw"]["CSIT"]
    sites = [struct.unpack_from("<BH", csit, 3 * i) for i in range(len(csit) // 3)]
    T = 2 + so("libc")[1]["core"]           # termlib's bank in the image
    place = {0: (T, 0), 1: (T, len(_lt["segs"][0][0]))}
    bad = [(s, o) for s, o in sites
           if struct.unpack_from("<H", b.segs[place[s][0]], place[s][1] + o)[0]
           != (struct.unpack_from("<H", a.segs[place[s][0]], place[s][1] + o)[0] - 2) & 0xFFFF]
    check(sites and not bad, "every termlib core site moved by -2",
          "%d sites, %d wrong" % (len(sites), len(bad)))
    t = fgx_imports.unpack(fgx_ld.read_dyn_trailer(
        fgx_bind.parse(open(tc, "rb").read())["trailer"])["blocks_raw"]["IMPS"])
    up = [im for im in t["imports"] if im["name"] == "UP"][0]
    check(all(struct.unpack_from("<H", b.segs[s], o)[0]
              == (struct.unpack_from("<H", a.segs[s], o)[0] - 2) & 0xFFFF
              for s, o, _v in up["data"]),
          "the program's UP sites moved by -2", "%d sites" % len(up["data"]))


def binding():
    hello = dyn("hello", os.path.join(HERE, "hello.c"), "libc")
    t = fgx_imports.unpack(fgx_ld.read_dyn_trailer(
        fgx_bind.parse(open(hello, "rb").read())["trailer"])["blocks_raw"]["IMPS"])
    out = tempfile.mkstemp(prefix="trace_")[1]
    with open(out, "w") as tf:
        img, entry, rep = fgx_bind.bind(hello, fgx_libso.LIB, trace=tf)
    text = open(out).read()
    check(rep["libs"] == {"libc": "prebound"} and rep["lookups"] == 0,
          "hello binds libc prebound, no name looked up", str(rep["libs"]))
    check("libc.so.1 => " in text and "prebound" in text, "the trace names the path",
          text.split("\n")[0])
    lib, tr = so("libc")
    ex = {e[0]: e for e in tr["exports"]}
    bad = []
    for im in t["imports"]:
        for s, o in (im["call"] + im["ptr"] if im["kind"] == 0 else []):
            e = ex[im["name"]]
            if struct.unpack_from("<H", img.segs[s], o)[0] != e[3] \
                    or (s, o + 2, 2 + e[2]) not in img.relocs:
                bad.append(im["name"])
    check(not bad, "every call and pointer site holds its export's offset and "
          "a reloc to its bank's segment", str(bad))
    bm = t["libs"][0]["bitmap"]
    need = sum(sz for i, (_c, _t, sz) in enumerate(tr["blocks"])
               if bm[i >> 3] & (1 << (i & 7)))
    check(rep["lowest"] == tr["core_base"] and rep["lim"] == tr["core_base"] - need,
          "LIM is libc's base less the reached blocks", "%04X" % rep["lim"])

    d = tempfile.mkdtemp(prefix="bind_mis_")
    moved_libc(d, -2)
    img2, _e, rep2 = fgx_bind.bind(hello, d)
    check(rep2["libs"] == {"libc": "by name"} and rep2["lookups"] == len(t["imports"]),
          "against a libc whose data moved, every import is looked up by name",
          "%s %d" % (rep2["libs"], rep2["lookups"]))
    diff = [(s, o) for im in t["imports"] for s, o, _v in im["data"]
            if struct.unpack_from("<H", img2.segs[s], o)[0]
            != (struct.unpack_from("<H", img.segs[s], o)[0] - 2) & 0xFFFF]
    check(not diff and rep2["sites"]["data"] > 0,
          "every data site moved down 2, mod 65,536", str(diff[:4]))
    img3, _e, _r = fgx_bind.bind(hello, d, patch_data=False)
    check(all(img3.segs[s][o:o + 2] == img.segs[s][o:o + 2]
              for im in t["imports"] for s, o, _v in im["data"]),
          "--no-data-sites leaves the data sites as linked")

    older = repack(hello, os.path.join(d, "older.dyn"),
                   lambda tb: tb["libs"][0].update(minor=1))
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        fgx_bind.bind(older, fgx_libso.LIB)
    check("ld.so: warning: libc.so.1.0 has older revision than expected 1"
          in err.getvalue(), "an older minor binds with SunOS's warning",
          err.getvalue().strip()[-200:])
    major = repack(hello, os.path.join(d, "major.dyn"),
                   lambda tb: tb["libs"][0].update(major=2))
    try:
        fgx_bind.bind(major, fgx_libso.LIB)
    except SystemExit as e:
        check("ld.so: libc.so.2: not found" in str(e),
              "a major with no library is not found", str(e))
    else:
        check(False, "a major with no library is not found")
    rows = repack(hello, os.path.join(d, "rows.dyn"),
                  lambda tb: tb["libs"][0].update(bitmap=tb["libs"][0]["bitmap"] + b"\0",
                                                  rows=tb["libs"][0]["rows"] + 8,
                                                  crc=0))
    try:
        fgx_bind.bind(rows, fgx_libso.LIB)
    except SystemExit as e:
        check("rows" in str(e), "a bitmap for a different block table is refused", str(e))
    else:
        check(False, "a bitmap for a different block table is refused")

    tc = dyn("tctest", os.path.join(REPO, "src", "userland", "tctest", "tctest.c"),
             "libc,libtermlib")
    img4, _e, rep4 = fgx_bind.bind(tc, fgx_libso.LIB)
    nb = so("libc")[1]["core"]
    T = 2 + nb                              # termlib's bank in the image
    check(len(img4.segs) == T + 1 and rep4["libs"] == {"libc": "prebound",
                                                       "libtermlib": "prebound"},
          "tctest binds libc and libtermlib: %d segments" % (T + 1), str(rep4["libs"]))
    lt, ttr = so("libtermlib")
    tt = fgx_imports.unpack(ttr["blocks_raw"]["IMPS"])
    calls = [(T, o) for im in tt["imports"] for s, o in im["call"]]
    check(calls and all(any(r[0] == T and r[1] == o + 2 and 2 <= r[2] <= 1 + nb
                            for r in img4.relocs) for _s, o in calls),
          "termlib's calls into libc get libc's banks", "%d sites" % len(calls))

MERLIN_START = """                MX      %%00
                PHP
                REP     #$30
                PEA     $%04X
                LDX     #$%04X
                LDY     #$0000
                SEP     #$20
                MX      %%10
LOOP            LDAL    $070000,X
                STA     (1,S),Y
                INX
                INY
                CPY     #$%04X
                BNE     LOOP
                PHB
                PLA
                STA     |$%04X
                STA     |$%04X
                REP     #$20
                MX      %%00
                PLA
                LDA     #$%04X
                STA     $FFF8
                PLP
                JMP     $%04X
"""


def startup():
    """The routine's bytes are what Merlin32 assembles from the same source,
    and its only reloc is the template's bank: segment 0 is shared text, so
    it must not name the data bank (the store is through (1,S),Y, DBR).  The
    core's fixups get this process's bank from DBR after the copy, as the
    binder sets them (ld_bind.c), never from a reloc the text freezes."""
    b, rel = fgx_bind.startup([(4, 0x8CDA, 0xF6A3, 2389, [2, 7])], 0xF6A3, 0x0123)
    d = tempfile.mkdtemp(prefix="bind_start_")
    with open(os.path.join(d, "s.link.s"), "w") as f:
        f.write("                TYP    $06\n                DSK    s\n"
                "                ORG    $0B0000\n" + MERLIN_START
                % (0xF6A3, 0x8CDA, 2389, 0xF6A3 + 2, 0xF6A3 + 7, 0xF6A3, 0x0123))
    subprocess.run(["merlin32", "-V", ".", "s.link.s"], cwd=d, check=True,
                   capture_output=True)
    m = bytearray(open(os.path.join(d, "s"), "rb").read())
    i = 14                      # PHP, REP, PEA, LDX, LDY, SEP: 1 + 2 + 3 + 3 + 3 + 2
    check(m[i:i + 4] == b"\xBF\x00\x00\x07", "Merlin assembles LDAL $070000,X as BF 00 00 07",
          m[i:i + 4].hex())
    m[i + 3] = 0
    check(bytes(b) == bytes(m), "fgx_bind's routine is Merlin's", b.hex())
    check([r for r in rel if r[1] != "self"] == [(i + 3, 4)],
          "the template's bank is the only bank reloc; nothing names the data bank", str(rel))
    check([r[0] for r in rel if r[1] == "self"] == [len(b) - 2],
          "the closing JMP's operand names segment 0 itself (an offset reloc when placed)",
          str(rel))


def image():
    hello = dyn("hello", os.path.join(HERE, "hello.c"), "libc")
    d = tempfile.mkdtemp(prefix="bind_img_")
    out = os.path.join(d, "hello.bin")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_bind.py"),
                        "--prog", hello, "--out", out, "--trace"],
                       capture_output=True, text=True)
    check(r.returncode == 0, "fgx_bind writes hello's image", r.stderr[-300:])
    if r.returncode:
        return
    data = open(out, "rb").read()
    p = fgx_bind.parse(data)
    check(data[10] & (fgx_ld.LIB_FLAG | fgx_ld.DYN_FLAG) == 0 and not p["trailer"],
          "flags bits 1 and 2 clear, no trailer", hex(data[10]))
    nb = so("libc")[1]["core"]
    check(data[6] == 2 + nb and data[7] == 1
          and [k for _s, _b, k in p["segs"]] == [0, 1] + [0] * nb,
          "%d segments: code, data, libc's %d banks" % (2 + nb, nb))
    prog = fgx_bind.parse(open(hello, "rb").read())
    entry = struct.unpack_from("<H", data, 8)[0]
    seg0 = p["segs"][0][0]
    old = struct.unpack_from("<H", fgx_ld.read_dyn_trailer(prog["trailer"])
                             ["blocks_raw"]["ENTR"], 0)[0]      # _crt0_lib
    check(entry == len(prog["segs"][0][0]) and seg0[entry:entry + 3] == b"\x08\xC2\x30",
          "the entry is the routine at segment 0's end: PHP, REP #$30")
    check(seg0[-3] == 0x4C and struct.unpack_from("<H", seg0, len(seg0) - 2)[0] == old,
          "it ends in JMP to _crt0_lib")
    lim = struct.unpack_from("<H", seg0, seg0.index(b"\x8D\xF8\xFF", entry) - 2)[0]
    _lib, tr = so("libc")
    check(lim == tr["core_base"], "it sets HEAP_LIM to libc's core base", "%04X" % lim)
    check(data[13:16] == prog["head"][13:16], "ABI, stack and soft-bank bytes kept")
    kinds = [k for _s, _b, k in p["segs"]]
    lib_to_data = [r for r in p["relocs"] if r[0] >= 2 and kinds[r[2]] == 1]
    check(not lib_to_data, "no library bank holds a reloc into the data segment "
          "(shared text would freeze it at the first process's bank)", str(lib_to_data[:4]))

def one_more_row():
    """A libc whose block table gained a row -- 38, the same five bitmap
    bytes, the same exports and so the same CRC -- is refused: the bitmap's
    bits would name other members."""
    hello = dyn("hello", os.path.join(HERE, "hello.c"), "libc")
    data = open(fgx_libso.so_path("libc"), "rb").read()
    p = fgx_bind.parse(data)
    tr = fgx_ld.read_trailer(p["trailer"])
    t2 = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"], tr["templates"],
                                tr["core_base"], tr["core_size"], tr["exports"],
                                tr["blocks"] + [(tr["blocks"][-1][0], 0, 2)],
                                tr["fixups"])
    d = tempfile.mkdtemp(prefix="bind_row_")
    with open(os.path.join(d, "libc.so.1.0"), "wb") as f:
        f.write(data[:len(data) - len(p["trailer"])] + t2)
    try:
        fgx_bind.bind(hello, d)
    except SystemExit as e:
        check("38" in str(e) and "37" in str(e),
              "a block table one row longer is refused, naming both counts", str(e))
    else:
        check(False, "a block table one row longer is refused, naming both counts")


def digest():
    """fgx_bind's digest of a prebound bind walks the sites and changes when
    one site's word does."""
    hello = dyn("hello", os.path.join(HERE, "hello.c"), "libc")
    img, _e, rep = fgx_bind.bind(hello, fgx_libso.LIB)
    table = rep["table"]
    a, n = fgx_bind.digest(img, table, rep)
    check(n > 0, "the digest walks the sites", str(n))
    s, o = next((s, o) for im in table["imports"] for s, o in im["call"])
    img.segs[s][o] ^= 1
    check(a != fgx_bind.digest(img, table, rep)[0], "the digest sees one site's word")


def boot_below():
    """A library ld.so.conf lists alone brings what it stacks on first, as
    ldload's load of it does: `libcurses 1' places libtermlib, then libcurses,
    and lddigest's --boot walks the same order."""
    conf = tempfile.mkstemp(prefix="ldconf_")[1]
    with open(conf, "w") as f:
        f.write("libcurses 1\n")
    b = fgx_bind.boot_bases(fgx_libso.LIB, {}, conf)
    order = sorted(b, key=lambda n: -b[n])
    check(order == ["libc", "libtermlib", "libcurses"],
          "a listed libcurses places libtermlib before it", str(order))
    check("libtermlib" in b
          and b["libcurses"] == b["libtermlib"] - so("libcurses")[1]["core_size"],
          "libcurses stacks directly under libtermlib",
          " ".join("%s=%04X" % (n, b[n]) for n in order))
    lib = fgx_libso.LIB
    order = [n for n, _m in fgx_bind.boot_order(lib, {}, conf)]
    check(order == ["libc", "libtermlib", "libcurses"],
          "boot_order, which lddigest --boot walks, is the same", str(order))


layout()
boot_below()
binding()
delta()
startup()
image()
one_more_row()
digest()
print("FAIL: %d" % len(fails) if fails else "bind checks passed")
sys.exit(1 if fails else 0)
