#!/usr/bin/env python3
"""test_libso.py - fcc --libso host checks (shared libc SP2 step 2).

Run from the toolchain root: python3 tests/libso/test_libso.py
"""
import json
import os
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UMB = os.path.join(ROOT, "tests", "libso", "umb")
FCC = os.path.join(ROOT, "fcc")
fails = []


def check(cond, what, detail=""):
    print(("  ok   " if cond else "  FAIL ") + what + ("  " + detail if detail else ""))
    if not cond:
        fails.append(what)


def fcc(src, *extra):
    d = tempfile.mkdtemp(prefix="libso_")
    out = os.path.join(d, "o.s")
    blocks = os.path.join(d, "blocks.json")
    r = subprocess.run([FCC, "--libso", "--emit-blocks", blocks, "-I" + UMB,
                        *extra, os.path.join(UMB, src), "-o", out,
                        "--data-segment", os.path.join(d, "o.data.s")],
                       capture_output=True, text=True)
    return r, d, blocks


def libso_name():
    """--libso-name names the block cells of a library other than libc; the
    default stays _libc_blk_."""
    d = tempfile.mkdtemp(prefix="libso_name_")
    src = os.path.join(d, "one.c")
    with open(src, "w") as f:
        f.write("static int n;\nint f() { return n++; }\n")
    def run(*extra):
        out = os.path.join(d, "o.s")
        r = subprocess.run([FCC, "--libso", *extra, "--sections", src, "-o", out,
                            "--data-segment", os.path.join(d, "o.data.s")],
                           capture_output=True, text=True)
        text = (open(out).read() + open(os.path.join(d, "o.data.s")).read()
                if r.returncode == 0 else "")
        return r, text
    r, text = run("--libso-name", "libtermlib")
    check(r.returncode == 0 and "_libtermlib_blk_one" in text
          and "_libc_blk_" not in text,
          "--libso-name libtermlib names the cell _libtermlib_blk_one",
          r.stderr[-200:])
    r, text = run()
    check(r.returncode == 0 and "_libc_blk_one" in text
          and "_libtermlib_blk_" not in text,
          "without it the cell is _libc_blk_one", r.stderr[-200:])


def attribution():
    r, d, blocks = fcc("umb.c")
    check(r.returncode == 0, "umb.c compiles in --libso", r.stderr.strip()[:200])
    if r.returncode:
        return
    m = json.load(open(blocks))["members"]
    names = {k: [row["name"] for row in v["statics"]] for k, v in m.items()}
    check(set(names) == {"a", "b"}, "two members, named by file stem", str(names))
    check(any(n.endswith("a_count") for n in names.get("a", [])), "a_count is a's")
    check(any(n.endswith("a_buf") for n in names.get("a", [])), "a_buf is a's")
    check(any("calls" in n for n in names.get("a", [])),
          "a_get's function-local static is a's")
    check(any(n.endswith("b_state") for n in names.get("b", [])), "b_state is b's")
    sizes = {row["name"]: row["bytes"] for v in m.values() for row in v["statics"]}
    buf = [s for n, s in sizes.items() if n.endswith("a_buf")]
    check(buf == [10], "a_buf is 10 bytes", str(buf))


def clash():
    r, _, _ = fcc("clash.c")
    check(r.returncode != 0 and "a_count" in r.stderr and "clash_b" in r.stderr,
          "a same-named static in two members is refused, naming both",
          r.stderr.strip()[:200])


def layout():
    core = os.path.join(tempfile.mkdtemp(prefix="libso_core_"), "core.list")
    with open(core, "w") as f:
        f.write("# test core list\nb_state\n")
    r, d, blocks = fcc("umb.c", "--core-list", core)
    check(r.returncode == 0, "umb.c compiles with --core-list", r.stderr.strip()[:200])
    if r.returncode:
        return
    m = json.load(open(blocks))["members"]
    rows = {row["name"].split("_")[-1]: row for row in m.get("a", {}).get("statics", [])}
    got = [(k, rows[k]["offset"], rows[k]["bytes"]) for k in ("count", "buf", "calls") if k in rows]
    check(got == [("count", 0, 2), ("buf", 2, 10), ("calls", 12, 2)],
          "member a's statics laid out in declaration order", str(got))
    check(m.get("a", {}).get("size") == 14, "member a's block is 14 bytes",
          str(m.get("a", {}).get("size")))
    names_b = [row["name"] for row in m.get("b", {}).get("statics", [])]
    check(not any(n.endswith("b_state") for n in names_b),
          "a core.list static is not in a block", str(names_b))
    data = open(os.path.join(d, "o.data.s")).read()
    check("_libc_blk_a" in data and "a__BT" in data,
          "the data file has member a's block cell and template")
    check("_umb_b_state" in data and "DA      $0007" in data.split("_umb_b_state", 1)[1][:80],
          "the core static keeps its label and initial value 7")



def macro_owner():
    r, d, blocks = fcc("mac_umb.c")
    check(r.returncode == 0, "mac_umb.c compiles", r.stderr.strip()[:200])
    if r.returncode:
        return
    m = json.load(open(blocks))["members"]
    check(list(m) == ["mac_m"], "a static a header macro defines belongs to the member that "
          "expands it, not the header", str(list(m)))


def template_sections():
    r, d, _ = fcc("umb.c", "--sections")
    check(r.returncode == 0, "umb.c compiles with --sections", r.stderr.strip()[:200])
    if r.returncode:
        return
    sys.path.insert(0, os.path.join(ROOT, "src", "ld"))
    import fgx_gc
    lines = open(os.path.join(d, "o.data.s")).read().split("\n")
    try:
        units = fgx_gc.split_sections(lines, "o.data.s")
    except SystemExit:
        check(False, "fgx_gc splits the library-mode data file")
        return
    sects = [u for u in units if u[0] == "sect"]
    names = [u[1] for u in sects]
    check(len(names) == len(set(names)), "no data section name repeats",
          str(sorted(n for n in names if names.count(n) > 1)))
    a = [u for u in sects if u[1] == "a__BT"]
    body = "\n".join(a[0][2]) if a else ""
    check(len(a) == 1 and "a_count" in body and "a_buf" in body and "calls" in body,
          "member a's template is one section holding all its statics")


def static_link():
    d = tempfile.mkdtemp(prefix="libso_static_")
    src = os.path.join(ROOT, "tests", "libso", "static_min.c")
    r = subprocess.run([FCC, "--data-segment", os.path.join(d, "p.data.s"),
                        "-o", os.path.join(d, "p.s"), src],
                       capture_output=True, text=True)
    check(r.returncode == 0, "static_min.c compiles", r.stderr[-200:])
    if r.returncode:
        return
    out = os.path.join(d, "p.bin")
    r = subprocess.run([sys.executable, os.path.join(ROOT, "src", "ld", "fgx_static.py"),
                        "--name", "p", "--dir", os.path.join(d, "p.ld"),
                        "--code", os.path.join(d, "p.s"),
                        "--data", os.path.join(d, "p.data.s"), "--out", out],
                       capture_output=True, text=True)
    check(r.returncode == 0, "fgx_static links it", (r.stdout + r.stderr)[-300:])
    if r.returncode:
        return
    m = json.load(open(os.path.join(d, "p.ld", "static.json")))
    data = open(out, "rb").read()
    seg0 = 16 + 8 * data[6]
    entry = struct.unpack_from("<H", data, 8)[0]
    check(data[seg0 + entry:seg0 + entry + 2] == b"\xC2\x30",
          "the entry is _crt0_lib's REP #$30", hex(entry))
    sys.path.insert(0, os.path.join(ROOT, "..", "tools"))
    import libc_so_check
    check(not libc_so_check.label_addrs(os.path.join(d, "p.ld", "seg0_Output.txt"),
                                        {"_crt0_start"}),
          "no _crt0_start label in the link")
    at = libc_so_check.label_addrs(os.path.join(d, "p.ld", "seg0_Output.txt"),
                                   {"_crt0_inits", "_libc_start", "_libc_sigtramp",
                                    "_sig_tramp"})
    check(len(at) == 4, "segment 0 holds _crt0_inits, _libc_start, "
          "_libc_sigtramp and _sig_tramp", str(sorted(at)))
    check("_sig_tramp" in at and data[seg0 + at["_sig_tramp"]] == 0x5C,
          "_sig_tramp is a JML", str(at.get("_sig_tramp")))
    rows = open(os.path.join(d, "p.ld", "libc.data.s")).read()
    check("_libc_blk_strtok" in rows and "strtok__BT" in rows,
          "strtok's cell and template are kept, with a table row")
    check("_libc_blk_ctime" not in rows, "an unreached member's block is not")
    check(len(m["segments"]) >= 3 and m["segments"][2]["kind"] == "CODE",
          "libc's reached code is its own bank")


libso_name()
attribution()
clash()
layout()
macro_owner()
template_sections()
static_link()
print("FAIL: %d" % len(fails) if fails else "libso checks passed")
sys.exit(1 if fails else 0)
