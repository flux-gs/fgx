#!/usr/bin/env python3
"""fgx_static.py - link a program statically against libc's library-mode
compile (shared libc SP2 spec, section 3, "Static programs").

Segment 0 holds crt0, the program's code, the --lib libraries' live code,
the fcc runtime and libc's hand-written code; segment 1 the program's data,
the libraries' live data, libc's hand-written data, the core cells and block
templates of the libc members the program reaches, and _libc_blktab; then
one segment per --code-seg, each with the whole fcc runtime; then the libc
functions and string literals it reaches, packed as libc.so's are
(fgx_libso).  The program enters at _crt0_lib (lib/crt0_lib.s), which
calls libc's _libc_start (lib/libc_start.s), then _crt0_inits -- written
here, it calls _lib_init (lib/libc_c/libc_init.c) with the link's
_libc_blktab -- then main.

Code reaches a member's statics only through the member's cell, so nothing
names its template: a template is kept exactly when its cell is.

Run: fgx_static.py --name N --dir D --code a.s --data a.data.s --out F
                   [--lib CODE,DATA]... [--code-seg a.s[,b.s]]...
                   [--pack a.s,b.s,...] [--stack-pad BYTES]
                   [--libc-bank-cap BYTES] [--squeeze]
     fgx_static.py --self-test
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_gc  # noqa: E402
import fgx_ld  # noqa: E402
import fgx_libso  # noqa: E402
import fgx_offrel  # noqa: E402
import fgx_pack  # noqa: E402

LIB = fgx_libso.LIB
TC = fgx_libso.TC
CRT0 = os.path.join(LIB, "crt0_lib.s")
BLK = re.compile(r"^_libc_blk_(\w+)$")
# Every file build() and Merlin32 write in the program's link directory.
OUTPUT = re.compile(r"^(?:(?:seg\d+|inits|bank\d+|m\d+|ovn|lits|rt_head|seg1_layout|end|"
                    r"libc|libc\.data|libs|libs\.data)(?:\.s|\.link\.s|_Output\.txt)?|static\.json|move|"
                    r"error_output\.txt|_FileInformation\.txt)$")
SEG0_EQUS = fgx_libso.CODE_EQUS + [("ARGS_MAX", "16"), ("ARGS_INPUT_MAX", "128")]
# ffltpr (toolchain/lib/ffltpr.c), compiled as program source by ninja.
FFLTPR = tuple(os.path.join(os.path.dirname(TC), "build", "static_libs", f)
               for f in ("ffltpr.s", "ffltpr.data.s"))
FLTUSED = re.compile(r"\b__lc_fltused\b")


def die(msg):
    sys.exit("fgx_static: " + msg)


def collect(files, order, prune):
    """fgx_gc's reachability over `files', with each block cell's section
    also reaching its member's template."""
    units, owner, body, is_data, roots = fgx_gc.graph(files, order, prune)
    for lab, key in list(owner.items()):
        m = BLK.match(lab)
        if m and m.group(1) + "__BT" in owner:
            body[key] += "\n" + m.group(1) + "__BT"
    return units, fgx_gc.reach(roots, owner, body, is_data)


def check_templates(listing, cells, members):
    """Each kept member's template, as the data segment's listing lays it
    out, must be the size the blocks file gives: _lib_init copies that many
    bytes, so a stale blocks file would copy the wrong block silently."""
    got = fgx_libso.section_sizes(listing, "libc.data.s")
    for m in cells:
        if m not in members:
            die("member %s has a block cell but no row in the blocks file "
                "(stale libc_so.blocks.json?)" % m)
        if got.get(m + "__BT") != members[m]["size"]:
            die("member %s's template is %s bytes in the listing but %d in "
                "the blocks file (stale libc_so.blocks.json?)"
                % (m, got.get(m + "__BT"), members[m]["size"]))


BANK = ["                SEP     #$20",           # A = the data bank
        "                MX      %10",
        "                PHB",
        "                PLA",
        "                REP     #$20",
        "                MX      %00",
        "                AND     #$00FF",
        "                PHA"]


COPY = ["                SEP     #$20",           # the copier's bank: this one
        "                MX      %10",
        "                PHK",
        "                PLA",
        "                REP     #$20",
        "                MX      %00",
        "                AND     #$00FF",
        "                PHA",
        "                PEA     _lib_copy"]


def inits(tables, bits=None):
    """_crt0_inits: _lib_init(table, bits, _lib_copy) for each block table,
    in load order.  `bits' is the bitmap labels, parallel to `tables';
    without it each is NULL, every row.  _lib_copy is crt0's MVN copier
    (lib/crt0_lib.s).  fcc's far-call convention: each 4-byte argument high
    word then low word, the last argument first; the caller drops them."""
    rows = ["_crt0_inits     MX      %00"]
    for i, t in enumerate(tables):
        rows += COPY
        if bits:
            rows += BANK + ["                PEA     %s" % bits[i]]
        else:
            rows += ["                PEA     0",        # bits, high word
                     "                PEA     0"]        # bits: NULL, every row
        rows += BANK + ["                PEA     %s" % t,
                        "                FGX2_FARCALL _lib_init",
                        "                TSC",
                        "                CLC",
                        "                ADC     #12",
                        "                TCS"]
    return rows + ["                RTS"]


END_DEF = re.compile(r"^end\b")
# `end' at a 4-byte boundary: sh's arena starts there (blok.c, bloktop =
# BLK(end)) and keeps BUSY in bit 0 of each block's link.
END_ROWS = ["                DS      0-*&3", "end             ANOP"]


def end_rows(code_rows, data_rows, die):
    """The rows that define `end' after the program's data, for a program
    that refers to it, as 2.11BSD's ld sets _end (ld.c, ldrsym(p_end, bsize,
    N_EXT+N_BSS)); none for one that does not.  ld(1): the symbols "are
    reserved, and if referred to, are set to ... the first location above
    all data ... It is erroneous to define these symbols."

    With --squeeze, `end' lands BELOW the squeezed bss (2.11BSD's _end sits
    ABOVE bss, since nothing there shrinks): `end' is the highest address
    `code_rows'/`data_rows' actually occupy once squeeze has pulled bss in,
    not the bank's old bss ceiling.  No program links with both --squeeze
    and a reference to `end' today, so the two have not needed to agree."""
    rows = code_rows + data_rows
    if any(END_DEF.match(r) for r in rows):
        die("the program defines end, which the linker sets: ld(1), \"it is "
            "erroneous to define these symbols\"")
    return END_ROWS if "end" in fgx_gc.operand_refs(
        fgx_gc.code_of(rows).split("\n")) else []


def squeeze_bss(data_size, need):
    """bss that leaves two bytes too few between the data's end (the first
    break) and HEAP_LIM for blocks of `need' bytes."""
    return fgx_ld.HEAP_LIM - data_size - (need - 2)


def ffltpr(objects):
    """2.11BSD's fltused/ffltpr split: [code], [data] to add to a program none
    of whose objects names __lc_fltused, fcc's marker on a translation unit
    that can print a float.  fltpr.s: "If fltused is not defined the
    references to pgen, pfloat and pscien in doprnt will be satisfied by
    ffltpr.s (fake floating print)."  ffltpr's __lc_pf_float, a definition
    in the program, shadows libc's, and fltpr is never reached.

    Two departures from 2.11BSD.  The choice is made only for a program that
    reaches libc's __lc_pf_float (printf's float conversions): ffltpr calls
    printf.c's __lc_pf_q, so linking it into any other program would pull
    printf in.  And `objects' is the program's own files and its --lib
    libraries, each scanned whole: a library compiled as program source is
    one translation unit, so a marker anywhere in it keeps fltpr, where
    2.11BSD counts only the archive members it loads."""
    if any(FLTUSED.search(open(p, errors="replace").read()) for p in objects):
        return [], []
    missing = [p for p in FFLTPR if not os.path.exists(p)]
    if missing:
        die("%s not built: run ninja first" % ", ".join(missing))
    return [FFLTPR[0]], [FFLTPR[1]]


def read(p):
    return open(p, errors="replace").read().split("\n")


def pruned(us, p, live):
    """A pruned file's rows: its unsectioned rows and its live sections, with
    the FGX2_RELOC_COUNT trailer recounted over what is kept."""
    rows = []
    for idx, u in enumerate(us):
        if u[0] == "loose":
            rows += [ln for ln in u[1] if ln.split()[:1] != ["FGX2_RELOC_COUNT"]]
        elif (p, idx) in live:
            rows += u[2]
    return rows + ["                FGX2_RELOC_COUNT %d" % fgx_gc.fgx2_rows(rows)]


def build(name, d, code, data, out, bank_cap=None, squeeze=False, libs=(),
          extra=(), pack=(), stack_pad=None):
    """`libs' is [(code, data)] of libraries compiled as a program's source
    is (fcc --sections), pruned as libc is; their live code joins segment 0
    and their live data segment 1.  `extra' is [[code files]], one code
    segment each (segments 2, 3, ...), each with the whole fcc runtime: the
    program's code reaches its helpers by a near JSR, which cannot leave the
    bank.  An extra segment carries fcc_runtime.s alone, not
    fgx_libso.BANK0 (libllong, d_stub.s): its code may not call a long-long
    or soft-double helper, and such a call fails at assembly.  `pack' is
    code files fgx_pack places: into segment 0's room, then into further
    code segments of the same shape as `extra''s.  `stack_pad' is fgx_ld's
    stack_pad."""
    os.makedirs(d, exist_ok=True)
    fgx_libso.clear_outputs(d, OUTPUT)
    lib_code = os.path.join(LIB, "libc_so.s")
    lib_data = os.path.join(LIB, "libc_so_data.s")
    # _crt0_inits first: fgx_gc's roots are the unpruned files, and it is the
    # one that names _lib_init.
    with open(os.path.join(d, "inits.s"), "w") as f:
        f.write("\n".join(inits(["_libc_blktab"])) + "\n")
    seg0_fixed = [CRT0, fgx_libso.RUNTIME] + fgx_libso.BANK0 + \
        [os.path.join(d, "inits.s")]
    xcode = [f for fs in extra for f in fs] + list(pack)
    lpaths = [p for pair in libs for p in pair]
    prune = {lib_code, lib_data} | set(lpaths)

    def walk(code, data):
        order = code + xcode + seg0_fixed + data + lpaths + fgx_libso.DATA \
            + [lib_code, lib_data]
        files = {p: read(p) for p in order}
        return files, collect(files, order, prune)
    files, (units, live) = walk(list(code), list(data))
    # ffltpr only for a program that reaches libc's float printer: added to
    # one that does not, its call to __lc_pf_q would pull printf in.
    if any(units[p][i][1] == "__lc_pf_float" for p, i in live if p == lib_code):
        fcode, fdata = ffltpr(code + xcode + list(data) + lpaths)
        if fcode:
            code, data = list(code) + fcode, list(data) + fdata
            files, (units, live) = walk(code, data)
    frames = code + xcode
    lcode, ldata = [], []
    for c, dt in libs:
        lcode += pruned(units[c], c, live)
        ldata += pruned(units[dt], dt, live)
    if libs:
        for fn, rows in (("libs.s", lcode), ("libs.data.s", ldata)):
            with open(os.path.join(d, fn), "w") as f:
                f.write("\n".join(rows) + "\n")
    lseg0 = ["libs.s"] if libs else []
    lseg1 = ["libs.data.s"] if libs else []
    end = end_rows(sum((files[p] for p in code + xcode), []),
                   sum((files[p] for p in data), []), die)
    if end:
        with open(os.path.join(d, "end.s"), "w") as f:
            f.write("\n".join(end) + "\n")
        lseg1.append("end.s")

    # libc's data: the live core sections, the live templates, the table.
    keep = [units[lib_data][i] for p, i in sorted(live) if p == lib_data]
    members = json.load(open(os.path.join(LIB, "libc_so.blocks.json")))["members"]
    cells = [BLK.match(u[1]).group(1) for u in keep if BLK.match(u[1])]
    tmpls = {u[1][:-len("__BT")] for u in keep if u[1].endswith("__BT")}
    if set(cells) != tmpls:
        die("cells %s and templates %s disagree" % (sorted(cells), sorted(tmpls)))
    need = sum(members[m]["size"] for m in cells if m in members)
    tab = fgx_libso.blktab(cells, {m: members.get(m, {"size": 0})["size"]
                                   for m in cells})
    fgx_libso.write_data(os.path.join(d, "libc.data.s"),
                         keep + [("sect", "_libc_blktab", tab)])

    # Segment 1: the data.  Its listing gives every code segment its labels.
    # The 256-byte pad keeps every data label at $0100 or above, as every
    # program's data segment does, so no data operand is assembled
    # direct-page.
    link = fgx_libso.write_link(d, "seg1", 0, fgx_libso.DATA_EQUS,
                                [fgx_libso.MACROS] + fgx_libso.DATA
                                + [os.path.join(LIB, "crt0_lib_data.s"), "libc.data.s"]
                                + data + lseg1, pad=256)
    seg1 = fgx_libso.run_merlin(d, link)
    if seg1 is None:
        die("the data segment is over 64 KB")
    check_templates(os.path.join(d, "seg1_Output.txt"), cells, members)
    subprocess.run([sys.executable, os.path.join(TC, "tools", "gen_seg1_layout.py"),
                    os.path.join(d, "seg1_Output.txt"),
                    os.path.join(d, "seg1_layout.s")], check=True,
                   stdout=subprocess.DEVNULL)

    # Segment 0: crt0, the program, the runtime, libc's hand-written code
    # and _crt0_inits.
    def seg0_puts(code):
        return ([fgx_libso.MACROS, "seg1_layout.s", CRT0] + code + lseg0
                + [fgx_libso.RUNTIME] + fgx_libso.BANK0 + ["inits.s"])

    def seg0_link(code):
        return fgx_libso.run_merlin(d, fgx_libso.write_link(
            d, "seg0", 0, SEG0_EQUS, seg0_puts(code)))
    if pack:
        # A further bank's overhead is the whole fcc runtime it carries.
        puts = [fgx_libso.MACROS, "seg1_layout.s", fgx_libso.RUNTIME]
        per_bank = fgx_pack.assembled(d, puts, SEG0_EQUS)
        sizes = {t: fgx_pack.measure(t, d, puts, SEG0_EQUS, per_bank) for t in pack}
        base = seg0_link(code)
        if base is None:
            die("segment 0 is over 64 KB before any --pack file joins it")
        groups = fgx_pack.pack(sizes, fgx_libso.CAP - len(base), fgx_libso.CAP,
                               per_bank)
        code = code + groups[0]
        extra = list(extra) + groups[1:]
    # The final assembly lists segment 0's own addresses too (fgx_offrel),
    # so the loader may place it by size; so does every code segment below.
    seg0, offs = fgx_offrel.assemble_code(d, "seg0", SEG0_EQUS, seg0_puts(code))
    if seg0 is None:
        die("segment 0 (crt0, the program, libc's hand-written code) is over 64 KB")
    segs = [{"bin": "seg0", "listing": "seg0_Output.txt", "kind": "CODE", "bss": 0},
            {"bin": "seg1", "listing": "seg1_Output.txt", "kind": "DATA", "bss": 0}]

    def placeable(seg, offs):
        if offs is not None:
            seg["offsets"] = offs
        return seg
    placeable(segs[0], offs)
    xsizes = []
    for i, fs in enumerate(extra):
        nm = "seg%d" % (i + 2)
        got, offs = fgx_offrel.assemble_code(
            d, nm, SEG0_EQUS, [fgx_libso.MACROS, "seg1_layout.s"] + list(fs)
            + [fgx_libso.RUNTIME])
        if got is None:
            die("code segment %d is over 64 KB" % (i + 2))
        xsizes.append(len(got))
        segs.append(placeable({"bin": nm, "listing": nm + "_Output.txt",
                               "kind": "CODE", "bss": 0}, offs))

    # libc's reached code, in banks of its own.
    cunits, corder = fgx_libso.split_code(files[lib_code], lib_code)
    live_code = {units[lib_code][i][1] for p, i in live if p == lib_code}
    funcs = [n for n in corder if n in live_code and not fgx_libso.LIT.match(n)]
    lits = [n for n in corder if fgx_libso.LIT.match(n)]
    # The fcc runtime joins AFTER funcs/lits: its units are shared sections
    # each libc bank carries only as its functions reach them.  Segment 0
    # keeps the whole runtime -- the program's own code near-JSRs it there.
    rt_head, rt_units, rt_order = fgx_libso.runtime_units(
        open(fgx_libso.RUNTIME).read().split("\n"))
    with open(os.path.join(d, "rt_head.s"), "w") as f:
        f.write("\n".join(rt_head) + "\n")
    cunits.update(rt_units)
    corder += rt_order
    shared = lits + rt_order
    own = fgx_libso.shared_owner(cunits, shared)
    sizes, lsizes = fgx_libso.measure(d, funcs, shared, cunits, "seg1_layout.s")
    ovn = len(fgx_libso.run_merlin(d, fgx_libso.write_link(
        d, "ovn", 0, fgx_libso.CODE_EQUS + fgx_libso.DP_EQUS,
        [fgx_libso.MACROS, "seg1_layout.s", "rt_head.s"])))
    budget = fgx_libso.CAP - ovn
    if bank_cap:
        budget = min(budget, bank_cap)
    refs = fgx_libso.shared_refs(cunits, funcs, own)
    need_lits = {t for t in fgx_gc.IDENT.findall(
        open(os.path.join(d, "libc.data.s")).read()) if fgx_libso.LIT.match(t)}
    banks, held, free = fgx_libso.pack_min(sizes, refs, lsizes, budget, budget,
                                           6 - len(extra), need_lits)
    if len(segs) + len(banks) > 8:
        die("%d code segments and %d libc banks: a binary with no LIBC segment "
            "has at most 8 segments" % (len(segs) - 1, len(banks)))
    canon = fgx_libso.canonical(held)

    frames += [os.path.join(d, f) for f in lseg0]
    for b, fs in enumerate(banks):
        rows = fgx_libso.bank_rows(cunits, corder, fs, held[b], canon, b)
        with open(os.path.join(d, "bank%d.s" % b), "w") as f:
            f.write("\n".join(rows) + "\n")
        got, offs = fgx_offrel.assemble_code(
            d, "bank%d" % b, fgx_libso.CODE_EQUS + fgx_libso.DP_EQUS,
            [fgx_libso.MACROS, "seg1_layout.s", "bank%d.s" % b, "rt_head.s"])
        want = ovn + sum(sizes[f] for f in fs) + sum(lsizes[l] for l in held[b])
        if got is None or len(got) != want:
            die("libc bank %d assembled to %s bytes; its sections measured %d"
                % (b, "over 64K" if got is None else len(got), want))
        segs.append(placeable({"bin": "bank%d" % b, "listing": "bank%d_Output.txt" % b,
                               "kind": "CODE", "bss": 0}, offs))
        frames.append(os.path.join(d, "bank%d.s" % b))
    if squeeze:
        segs[1]["bss"] = squeeze_bss(len(seg1), need)
        if segs[1]["bss"] < 0 or need < 4:
            die("--squeeze needs blocks and room to squeeze (need %d)" % need)
    entry = fgx_ld.scan_listing(os.path.join(d, "seg0_Output.txt"),
                                len(segs))["exports"].get("_crt0_lib")
    if entry is None:
        die("seg0 exports no _crt0_lib")
    manifest = {"output": os.path.basename(out), "format": "FGX3",
                "n_data_segment": 1, "entry_offset": entry, "flags": 0,
                "stack_frames": [os.path.relpath(os.path.realpath(f), os.path.realpath(d))
                             for f in frames],
                "segments": segs}
    if stack_pad is not None:
        manifest["stack_pad"] = stack_pad
    mpath = os.path.join(d, "static.json")
    with open(mpath, "w") as f:
        json.dump(manifest, f, indent=1)
    r = subprocess.run([sys.executable, os.path.join(HERE, "fgx_ld.py"), mpath,
                        "-o", out], capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    if r.returncode:
        die(r.stderr.strip() or r.stdout.strip() or "fgx_ld failed")
    print("static %s: seg0 %d bytes, data %d bytes, %slibc banks [%s], blocks "
          "%d bytes for %d members" % (name, len(seg0), len(seg1), "".join(
              "seg%d %d bytes, " % (i + 2, n) for i, n in enumerate(xsizes)), ", ".join(
              str(budget - f + ovn) for f in free), need, len(cells)))


def self_test():
    files = {
        "p.s": ["main    ENT", "        FGX2_FARCALL strtok", "        RTL"],
        "l.s": ["                FGX_SECT strtok", "strtok  ENT",
                "        LDA     _libc_blk_strtok", "        RTL",
                "                FGX_ENDS",
                "                FGX_SECT unused", "unused  ENT", "        RTL",
                "                FGX_ENDS"],
        "l_data.s": ["                FGX_SECT _libc_blk_strtok",
                     "_libc_blk_strtok DA 0", "                FGX_ENDS",
                     "                FGX_SECT _libc_blk_unused",
                     "_libc_blk_unused DA 0", "                FGX_ENDS",
                     "                FGX_SECT strtok__BT",
                     "strtok__BT      ANOP", "strtok_sl_last  DS 4",
                     "                FGX_ENDS",
                     "                FGX_SECT unused__BT",
                     "unused__BT      ANOP", "                DS 2",
                     "                FGX_ENDS"],
    }
    units, live = collect(files, ["p.s", "l.s", "l_data.s"], {"l.s", "l_data.s"})
    names = sorted(units[p][i][1] for p, i in live)
    assert names == ["_libc_blk_strtok", "strtok", "strtok__BT"], names
    files["f.s"] = ["                FGX_SECT ticks", "ticks   ENT", "        RTL",
                    "                FGX_ENDS",
                    "                FGX_SECT procs", "procs   ENT", "        RTL",
                    "                FGX_ENDS"]
    files["p.s"] = files["p.s"] + ["        FGX2_FARCALL ticks"]
    units, live = collect(files, ["p.s", "l.s", "l_data.s", "f.s"],
                          {"l.s", "l_data.s", "f.s"})
    names = sorted(units[p][i][1] for p, i in live)
    assert "ticks" in names and "procs" not in names, names
    opts = set(parser()._option_string_actions)
    assert {"--lib", "--code-seg", "--pack", "--stack-pad"} <= opts, sorted(opts)
    assert squeeze_bss(1000, 100) == 0xFFF8 - 1000 - 98
    d = tempfile.mkdtemp(prefix="static_clr_")
    open(os.path.join(d, "seg0.link.s"), "w").close()
    fgx_libso.clear_outputs(d, OUTPUT)
    assert os.listdir(d) == []
    lst = os.path.join(tempfile.mkdtemp(prefix="static_bt_"), "seg1_Output.txt")
    row = ("  %d |  2   libc.data.s   %d | Macro       | 00 |         |    0 "
           "| 0B/%04X               |          %s\n")
    with open(lst, "w") as f:
        f.write(row % (1, 2, 0x0400, "FGX_SECT          strtok__BT"))
        f.write(row % (2, 5, 0x0404, "FGX_ENDS"))
    check_templates(lst, ["strtok"], {"strtok": {"size": 4}})
    for members in ({"strtok": {"size": 6}}, {}):
        try:
            check_templates(lst, ["strtok"], members)
        except SystemExit:
            continue
        raise AssertionError("a blocks file out of step with the templates "
                             "must be refused: %s" % members)
    rows = [r.split() for r in inits(["_libc_blktab"])]
    assert rows[0] == ["_crt0_inits", "MX", "%00"] and rows[-1] == ["RTS"]
    ops = [r for r in rows[1:-1] if r[0] != "MX"]
    assert ops[0] == ["SEP", "#$20"] and ["PHK"] in ops[:4]        # copy: this bank
    assert ops.index(["PEA", "_lib_copy"]) < ops.index(["PEA", "0"])  # pushed first
    assert ["PEA", "_libc_blktab"] in ops and \
        ops.index(["PEA", "_libc_blktab"]) < ops.index(["FGX2_FARCALL", "_lib_init"])
    assert ["ADC", "#12"] in ops                               # the caller pops 3 args
    print("fgx_static: self-test OK")

def parser():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--code", required=True, help="comma-separated .s files")
    ap.add_argument("--data", required=True, help="comma-separated .data.s files")
    ap.add_argument("--out", required=True)
    ap.add_argument("--libc-bank-cap", type=int)
    ap.add_argument("--squeeze", action="store_true")
    ap.add_argument("--lib", action="append", default=[], metavar="CODE,DATA",
                    help="a library compiled as program source, pruned")
    ap.add_argument("--code-seg", action="append", default=[], metavar="a.s[,b.s]",
                    help="one further code segment, assembled with fcc_runtime.s "
                    "only: a call from it to a long-long or soft-double helper "
                    "fails at assembly")
    ap.add_argument("--pack", action="append", default=[], metavar="a.s,b.s,...",
                    help="code files packed into segment 0's room, then into "
                    "further code segments as --code-seg's")
    ap.add_argument("--stack-pad", type=int, metavar="BYTES",
                    help="fgx_ld's stack_pad: bytes added to the measured stack")
    return ap


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    a = parser().parse_args()
    build(a.name, os.path.abspath(a.dir),
          [os.path.abspath(p) for p in a.code.split(",")],
          [os.path.abspath(p) for p in a.data.split(",")],
          os.path.abspath(a.out), a.libc_bank_cap, a.squeeze,
          [tuple(os.path.abspath(p) for p in l.split(",")) for l in a.lib],
          [[os.path.abspath(p) for p in g.split(",")] for g in a.code_seg],
          [os.path.abspath(p) for x in a.pack for p in x.split(",")], a.stack_pad)
    return 0

if __name__ == "__main__":
    sys.exit(main())
