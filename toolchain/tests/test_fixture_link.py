#!/usr/bin/env python3
"""test_fixture_link.py - the fixture link (fixture_link.py) builds a static
image entered at _crt0_lib with no _crt0_start in it, reads an M-dir's
_link.json, and refuses a recipe key it does not know.  Needs ninja's
build/static_libs/ and the toolchain's lib/libc_so.s.

Run: python3 toolchain/tests/test_fixture_link.py
"""
import json
import os
import re
import shutil
import struct
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO, "tools"))
import fixture_link  # noqa: E402
import libc_so_check  # noqa: E402

fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def stage(tmp, mdir, name):
    """Copy a fixture's goldens into tmp as <name>.s / <name>.data.s."""
    src = os.path.join(HERE, mdir, name)
    shutil.copy(src + ".expected.s", os.path.join(tmp, name + ".s"))
    shutil.copy(src + ".expected.data.s", os.path.join(tmp, name + ".data.s"))


def plain(tmp):
    stage(tmp, "M0", "return_42")
    out = os.path.join(tmp, "r42.bin")
    ok, log = fixture_link.link(tmp, os.path.join(tmp, "ld"), ["return_42.s"],
                                ["return_42.data.s"], out)
    check(ok, "M0/return_42 links", log[-300:])
    if not ok:
        return
    data = open(out, "rb").read()
    check(data[:4] == b"FGX3", "the image is FGX3", repr(data[:4]))
    seg0 = 16 + 8 * data[6]
    entry = struct.unpack_from("<H", data, 8)[0]
    check(data[seg0 + entry:seg0 + entry + 2] == b"\xC2\x30",
          "the entry is _crt0_lib's REP #$30", hex(entry))
    lst = os.path.join(tmp, "ld", "seg0_Output.txt")
    check(not libc_so_check.label_addrs(lst, {"_crt0_start"}),
          "no _crt0_start in the link")
    check(not defines(os.path.join(tmp, "ld"), "__lc_pf_q"),
          "a program that does not reach printf gets no ffltpr")


def recipe(tmp):
    # M38's recipe, read from M38 itself: tcops links.
    m38 = os.path.join(HERE, "M38")
    stage(tmp, "M38", "tcops")
    ok, log = fixture_link.link(m38, os.path.join(tmp, "ld38"),
                                [os.path.join(tmp, "tcops.s")],
                                [os.path.join(tmp, "tcops.data.s")],
                                os.path.join(tmp, "tcops.bin"))
    check(ok, "M38/tcops links with M38/_link.json", log[-300:])
    # Control: the same fixture from a directory with no recipe must fail,
    # and on the termlib symbol, or the recipe is not what made it link.
    bare = os.path.join(tmp, "bare")
    os.mkdir(bare)
    ok, log = fixture_link.link(bare, os.path.join(tmp, "ldbare"),
                                [os.path.join(tmp, "tcops.s")],
                                [os.path.join(tmp, "tcops.data.s")],
                                os.path.join(tmp, "tcops_bare.bin"))
    check(not ok and "tgetent" in log[-300:] and "Traceback" not in log,
          "without a recipe tcops fails on tgetent, as fgx_static's own "
          "message", log[-300:])


def bad_key(tmp):
    d = os.path.join(tmp, "badkey")
    os.mkdir(d)
    with open(os.path.join(d, "_link.json"), "w") as f:
        json.dump({"code": [], "libs": []}, f)
    try:
        fixture_link.command(d, d, ["a.s"], ["a.data.s"], os.path.join(d, "a.bin"))
    except SystemExit as e:
        check("libs" in str(e), "an unknown recipe key is refused", str(e))
        return
    check(False, "an unknown recipe key is refused", "no SystemExit")


def defines(ld, name):
    """True when one of the link's libc banks or segment 0 defines `name'."""
    pat = re.compile(r"^%s\s+ENT\b" % re.escape(name), re.M)
    for f in os.listdir(ld):
        if re.match(r"^(bank\d+|seg0)\.link\.s$|^bank\d+\.s$", f):
            txt = open(os.path.join(ld, f), errors="replace").read()
            if pat.search(txt):
                return True
            # seg0's link file PUTs its sources: look in them too.
            for put in re.findall(r"^\s+PUT\s+(\S+)", txt, re.M):
                q = os.path.join(ld, put)
                if os.path.exists(q) and pat.search(open(q, errors="replace").read()):
                    return True
    return False


def fltpr(tmp):
    """2.11BSD's fltused/ffltpr split, for a static link: a program with no
    `]__lc_fltused' marker in any object -- its own code, a --code-seg file
    or a --lib library -- gets ffltpr's `?' printer and none of fltpr's
    digits (ecvt/fcvt); the same program with the marker in any of them gets
    fltpr.  fltpr.s: "If the compiler notices any floating point type stuff
    going on in a C object, it automatically outputs a reference to the
    symbol "fltused"."""
    marker = "]__lc_fltused   =       1\n"
    d = os.path.join(tmp, "flt")
    os.mkdir(d)
    stage(d, "M11", "lc_printf_2")
    shutil.copy(os.path.join(d, "lc_printf_2.s"), os.path.join(d, "marked.s"))
    with open(os.path.join(d, "marked.s"), "a") as f:
        f.write(marker)
    # A --lib library compiled as program source, carrying the marker.
    lib = os.path.join(REPO, "build", "static_libs", "libutil")
    shutil.copy(lib + ".s", os.path.join(d, "mlib.s"))
    shutil.copy(lib + ".data.s", os.path.join(d, "mlib.data.s"))
    with open(os.path.join(d, "mlib.s"), "a") as f:
        f.write(marker)
    ldir = os.path.join(d, "libdir")
    os.mkdir(ldir)
    with open(os.path.join(ldir, "_link.json"), "w") as f:
        json.dump({"lib": [[os.path.join(d, "mlib.s"),
                            os.path.join(d, "mlib.data.s")]]}, f)
    # A --code-seg file carrying the marker.
    with open(os.path.join(d, "seg.s"), "w") as f:
        f.write("                FGX2_MODE 2\n                MX      %00\n"
                "flt_seg_fn      RTL\n" + marker
                + "                FGX2_RELOC_COUNT 1\n")
    plainc = os.path.join(d, "lc_printf_2.s")
    data = [os.path.join(d, "lc_printf_2.data.s")]
    cases = (("no marker", d, [plainc], (), False),
             ("the marker in the program's code", d,
              [os.path.join(d, "marked.s")], (), True),
             ("the marker in a --lib library", ldir, [plainc], (), True),
             ("the marker in a --code-seg file", d, [plainc],
              ([os.path.join(d, "seg.s")],), True))
    for i, (what, mdir, code, segs, marked) in enumerate(cases):
        ld = os.path.join(d, "ld%d" % i)
        ok, log = fixture_link.link(mdir, ld, code, data,
                                    os.path.join(d, "f%d.bin" % i),
                                    code_segs=segs)
        check(ok, "links with %s" % what, log[-300:])
        if not ok:
            continue
        check(defines(ld, "ecvt") == marked,
              "fltpr's ecvt is %slinked with %s" % ("" if marked else "not ", what))
        check(defines(ld, "__lc_pf_q") != marked,
              "ffltpr's __lc_pf_q is %slinked with %s" % ("not " if marked else "", what))

def oracle_flags(tmp):
    """run_runtime's differential build compiles a fixture as run.sh does,
    _fcc.flags included: M42/libso_calls built both ways is one image."""
    import pathlib
    import run_runtime
    golden = os.path.join(tmp, "golden")
    os.mkdir(golden)
    stage(golden, "M42", "libso_calls")
    gbin = os.path.join(golden, "g.bin")
    ok, log = fixture_link.link(os.path.join(HERE, "M42"), os.path.join(golden, "ld"),
                                [os.path.join(golden, "libso_calls.s")],
                                [os.path.join(golden, "libso_calls.data.s")], gbin)
    check(ok, "M42/libso_calls links from its golden", log[-200:])
    fx = {"name": "libso_calls", "c": pathlib.Path(HERE, "M42", "libso_calls.c"),
          "s": pathlib.Path(HERE, "M42", "libso_calls.expected.s")}
    obin = run_runtime.build_fcc_bin(fx, pathlib.Path(tmp),
                                     pathlib.Path(REPO, "toolchain", "fcc"))
    check(obin is not None and ok and open(str(obin), "rb").read() == open(gbin, "rb").read(),
          "the oracle's build of M42/libso_calls is the golden's image")


tmp = tempfile.mkdtemp(prefix="fixture_link.")
try:
    for t in (plain, recipe, bad_key, fltpr, oracle_flags):
        t(tmp)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
print("test_fixture_link: %s" % ("FAIL (%d)" % len(fails) if fails else "OK"))
sys.exit(1 if fails else 0)
