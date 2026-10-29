#!/usr/bin/env python3
"""fgx_dyn.py - link a program dynamically against the shared libraries
(shared libc SP3 spec, section 3, "Dynamic program").

Segment 0 holds crt0_dyn (lib/crt0_dyn.s, the entry: it binds the program on
the machine) and crt0 (lib/crt0_lib.s), the program's code, the fcc runtime
it reaches -- each far helper a thunk to libc.so's far entry -- and
_crt0_inits, then the binder's tables (with_tables); segment 1 the program's data, its own runtime cells and one
reachability bitmap per needed library.  The libraries' data exports are
EQUs at their prebound addresses; fgx_ld binds the calls, jumps and
pointer cells to the libraries' exports and writes the FGXD trailer, and
a second link with the EQUs moved down by fgx_sites.DELTA finds the data
sites by difference.  The trailer's ENTR names _crt0_lib's offset, where
a host bind (fgx_bind) enters.

Run: fgx_dyn.py --name N --dir D --code a.s --data a.data.s
                --lib libc[,libtermlib...] --out F [--so NAME=PATH ...]
                [--code-seg b.s[,c.s] ...]    (one more code segment each)
                [--pack b.s,c.s,...]   (packed into segment 0's room, then
                                        into further code segments: fgx_pack)
                [--stack-pad BYTES]    (fgx_ld's stack_pad)
                [--split]              (the --code file's functions packed
                                        one by one: fgx_pack.split_code)
     fgx_dyn.py --self-test
"""
import argparse
import json
import os
import re
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fgx_bind  # noqa: E402
import fgx_gc  # noqa: E402
import fgx_imports  # noqa: E402
import fgx_ld  # noqa: E402
import fgx_libso  # noqa: E402
import fgx_offrel  # noqa: E402
import fgx_pack  # noqa: E402
import fgx_sites  # noqa: E402
import fgx_static  # noqa: E402

LIB = fgx_libso.LIB
TC = fgx_libso.TC
SEG0_EQUS = fgx_static.SEG0_EQUS + [("SYS_LDCTL", "8")]
CRT0_DYN = os.path.join(LIB, "crt0_dyn.s")
# Every file link_once and Merlin32 write in a link directory -- any segment
# number, since a link that packs more segments than fgx_ld accepts writes them
# before the refusal, and the rerun has to clear them.
OUTPUT = re.compile(r"^(?:(?:seg\d+|seg\d+_rt|rt|inits|dyn\.data|prog\.data|imports_layout|"
                    r"dataptr_mac|seg1_layout|pack_rt|rt_data|m\d+|\w+_reach)(?:\.s|\.link\.s|_Output\.txt)?|"
                    r"dyn\.json|shift|move|prog\.bin|error_output\.txt|_FileInformation\.txt)$")


def die(msg):
    sys.exit("fgx_dyn: " + msg)


def far_helpers(path=os.path.join(LIB, "libc_so_helpers.s")):
    """The fcc helpers libc.so exports far (tools/helper_census.py): the
    names of its FGX2_EXPORT <helper>_far rows."""
    out = []
    for ln in open(path):
        t = ln.split()
        if t[:1] == ["FGX2_EXPORT"] and t[1].endswith("_far"):
            out.append(t[1][:-len("_far")])
    return out


def thunked_runtime(far, roots=None):
    """fcc_runtime.s for a dynamic program: each far helper's unit becomes
    a thunk to libc.so's far entry, so fcc's JSR stays as it is (shared
    libc SP3 spec, section 3); the helpers are cold by the census's rule,
    so the thunk's JSR/RTS is on no measured path.  Given `roots' (the text
    of the program's code, crt0 and inits), only the units it reaches are
    kept, so the program imports a far entry exactly when it uses it."""
    head, units, order = fgx_libso.runtime_units(
        open(fgx_libso.RUNTIME).read().split("\n"))
    for u in far:
        labels = [r for r in units[u] if fgx_libso.RT_LABEL.match(r)]
        if len(labels) != 1:
            die("far helper %s shares its unit with %s" % (u, labels[1:]))
        units[u] = [units[u][0], "%-15s MX      %%00" % u,
                    "                FGX2_FARCALL %s_far" % u,
                    "                RTS", units[u][-1]]
    keep = set(order)
    if roots is not None:
        files = {"__roots__": roots.split("\n"),
                 "__rt__": sum((units[u] for u in order), [])}
        g_units, owner, body, is_data, rts = fgx_gc.graph(
            files, ["__roots__", "__rt__"], {"__rt__"})
        keep = {g_units["__rt__"][i][1] for _p, i in
                fgx_gc.reach(rts, owner, body, is_data)}
    rows = list(head)
    for u in order:
        if u in keep:
            rows += units[u][1:-1]                # drop FGX_SECT/FGX_ENDS
    return rows


LABEL = re.compile(r"^([A-Za-z_]\w*)\b")
DS_SIZE = re.compile(r"^([A-Za-z_]\w*)\s+DS\s+(\d+)\s*$")


class Libs:
    """The named libraries and every one below them, in load order:
    `.names'; `.libs' [(so path, core listing, trailer)]; `.data' {name:
    (addr, size)} of their data exports; `.code' their code exports;
    `.lowest' the lowest core base."""

    def __init__(self, names, override=None):
        override = override or {}
        want = set()

        def add(n):
            if n not in want:
                want.add(n)
                for b in fgx_libso.LIBS[n]["below"]:
                    add(b)
        for n in names:
            add(n)
        self.names = [n for n in fgx_libso.LIBS if n in want]
        self.libs = []
        for n in self.names:
            so = override.get(n, fgx_libso.so_path(n))
            if not os.path.exists(so):
                die("%s is not built (make -C toolchain libso_all)" % so)
            # An override's core listing is in the link directory beside it
            # (fgx_libso.py --dir <so's dir>/ld).
            lst = os.path.join(os.path.dirname(so), "ld", "core_Output.txt") \
                if n in override else os.path.join(LIB, fgx_libso.LIBS[n]["dir"],
                                                   "core_Output.txt")
            self.libs.append((so, lst,
                              fgx_imports.file_trailer(open(so, "rb").read())))
        self.data = {e[0]: (e[3], e[4]) for _s, _l, tr in self.libs
                     for e in tr["exports"] if e[1] == 1}
        self.code = {e[0] for _s, _l, tr in self.libs
                     for e in tr["exports"] if e[1] == 0}
        self.lowest = min(tr["core_base"] for _s, _l, tr in self.libs)
        # A data site is attributed to a library by its address, so no two
        # libraries' cores may share one.
        spans = sorted((tr["core_base"], tr["core_base"] + tr["core_size"], n)
                       for n, (_s, _l, tr) in zip(self.names, self.libs))
        for (_a, end, x), (b, _e, y) in zip(spans, spans[1:]):
            if b < end:
                die("%s's core ($%04X) overlaps %s's (to $%04X): a data site "
                    "in it has no one owner" % (y, b, x, end - 1))

    def owner(self, name):
        """The library exporting `name'."""
        for n, (_s, _l, tr) in zip(self.names, self.libs):
            if any(e[0] == name for e in tr["exports"]):
                return n
        return None


def program_names(code_rows, data_rows):
    """(code exports, data labels, every identifier the program names)."""
    code = set(fgx_gc.exported_names(code_rows))
    data = {m.group(1) for r in data_rows for m in [LABEL.match(r)] if m}
    refs = set(fgx_gc.IDENT.findall(fgx_gc.code_of(code_rows + data_rows)))
    return code, data, refs


def split_data(data_rows, libs, code_exports):
    """K&R A.10.2's common extension against the libraries: a tentative
    definition of a library data export is a declaration (dropped; the
    name binds to the library's EQU) -- unless it is larger than the
    export, which would write past it into the library's next cell.  Any
    other definition of a library export, data or function, shadows it.
    (rows, dropped, shadowed)."""
    rows, dropped = [], []
    for r in data_rows:
        m = DS_SIZE.match(r)
        if m and m.group(1) in libs.data:
            n, size = m.group(1), int(m.group(2))
            if size > libs.data[n][1]:
                die("the program's tentative %s is %d bytes; the library's "
                    "is %d" % (n, size, libs.data[n][1]))
            dropped.append(n)
            continue
        rows.append(r)
    labels = {m.group(1) for r in rows for m in [LABEL.match(r)] if m}
    shadowed = sorted((labels | set(code_exports))
                      & (set(libs.data) | libs.code))
    return rows, dropped, shadowed


def bitmaps(libs, roots):
    """Each needed library's reachability bitmap over its block-table rows
    (sorted member names), from the names the program imports, through
    every needed library's library-mode code and data: (bits {lib: bytes},
    need {lib: bytes of reached blocks}, live {lib: [live code sections'
    rows]})."""
    files, order = {}, []
    for n in libs.names:
        for k in ("code", "data"):
            p = fgx_libso.lib_file(n, k)
            files[p] = open(p).read().split("\n")
            order.append(p)
    root = "__roots__"
    files[root] = ["        " + " ".join(sorted(roots))]
    units, owner, body, is_data, rts = fgx_gc.graph(files, [root] + order,
                                                     set(order))
    live = fgx_gc.reach(rts, owner, body, is_data)
    names = {units[p][i][1] for p, i in live}
    bits, need, code = {}, {}, {}
    for n in libs.names:
        cp = fgx_libso.lib_file(n, "code")
        code[n] = [units[cp][i][2] for p, i in sorted(live) if p == cp]
        members = json.load(open(fgx_libso.lib_file(n, "blocks")))["members"]
        b = bytearray((len(members) + 7) // 8)
        need[n] = 0
        for i, m in enumerate(sorted(members)):
            if "_%s_blk_%s" % (n, m) in names:
                b[i >> 3] |= 1 << (i & 7)
                need[n] += members[m]["size"]
        bits[n] = bytes(b)
    return bits, need, code


def read(p):
    return open(p, errors="replace").read().split("\n")


def link_data(d, data_rows, libs, shift, shadowed, gen):
    """Segment 1 in d with the libraries' data EQUs `shift' below their
    prebound addresses, and the layout files every code segment PUTs.
    `gen' is {file: text} of the generated sources (rt.s, inits.s,
    dyn.data.s), written here so each link directory has its own.  The
    segment's bytes."""
    os.makedirs(d, exist_ok=True)
    fgx_libso.clear_outputs(d, OUTPUT)
    for fn, text in gen.items():
        with open(os.path.join(d, fn), "w") as f:
            f.write(text)
    fgx_libso.write_dataptr_mac(d)
    with open(os.path.join(d, "imports_layout.s"), "w") as f:
        for n, (a, _sz) in sorted(libs.data.items()):
            if n not in shadowed:
                f.write("%-18s EQU    $%04X\n" % (n, a - shift))
    with open(os.path.join(d, "prog.data.s"), "w") as f:
        f.write("\n".join(data_rows) + "\n")
    # The 256-byte pad keeps every data label at $0100 or above, as every
    # program's data segment does, so no data operand is direct-page.
    seg1 = fgx_libso.run_merlin(d, fgx_libso.write_link(
        d, "seg1", 0, fgx_libso.DATA_EQUS,
        [fgx_libso.MACROS, "dataptr_mac.s", "imports_layout.s",
         fgx_libso.runtime_data(d, set(libs.data)),
         os.path.join(LIB, "crt0_lib_data.s"),
         "prog.data.s", "dyn.data.s"],
        pad=256))
    if seg1 is None:
        die("the data segment is over 64 KB")
    subprocess.run([sys.executable, os.path.join(TC, "tools", "gen_seg1_layout.py"),
                    os.path.join(d, "seg1_Output.txt"),
                    os.path.join(d, "seg1_layout.s")], check=True,
                   stdout=subprocess.DEVNULL)
    return seg1


LAYOUT = [fgx_libso.MACROS, "seg1_layout.s", "imports_layout.s"]


def seg0_puts(code):
    return LAYOUT + [CRT0_DYN, fgx_static.CRT0] + list(code) + ["rt.s", "inits.s"]


def pack_tus(d, code, tus):
    """fgx_pack's groups for `tus' in d, after link_data: the first joins
    segment 0, each later one is a code segment.  A bank's overhead is the
    whole thunked runtime, an upper bound on the part its TUs reach."""
    with open(os.path.join(d, "pack_rt.s"), "w") as f:
        f.write("\n".join(thunked_runtime(far_helpers())) + "\n")
    puts = LAYOUT + ["pack_rt.s"]
    per_bank = fgx_pack.assembled(d, puts, SEG0_EQUS)
    sizes = {t: fgx_pack.measure(t, d, puts, SEG0_EQUS, per_bank) for t in tus}
    b = fgx_libso.run_merlin(d, fgx_libso.write_link(d, "seg0", 0, SEG0_EQUS,
                                                     seg0_puts(code)))
    if b is None:
        die("segment 0 is over 64 KB before any --pack file joins it")
    return fgx_pack.pack(sizes, fgx_libso.CAP - len(b), fgx_libso.CAP, per_bank)


def code_seg(d, nm, puts, offsets):
    """A code segment's bytes and, when `offsets', its own address sites
    (fgx_offrel; None for a segment too big to move)."""
    if offsets:
        return fgx_offrel.assemble_code(d, nm, SEG0_EQUS, puts)
    return fgx_libso.run_merlin(d, fgx_libso.write_link(d, nm, 0, SEG0_EQUS, puts)), None


def link_code(d, code, libs, frames=None, extra=(), stack_pad=None, offsets=True):
    """Segment 0 and one code segment for each list of files in `extra'
    (segments 2, 3, ...) in d, after link_data, and d/prog.bin.  `frames'
    the stack_frames sources, `stack_pad' fgx_ld's stack_pad, `offsets'
    whether code segments list their own addresses, so the loader may
    place them by size.  Segment 0's bytes."""
    seg0, offs0 = code_seg(d, "seg0", seg0_puts(code), offsets)
    if seg0 is None:
        die("segment 0 is over 64 KB; give the program's further code as "
            "--code-seg or --pack")
    # Each further code segment carries its own thunked fcc runtime: fcc
    # reaches its helpers by a near JSR, which cannot leave the bank -- the
    # tool build gives seg3 its own fcc_runtime.s for the same reason.
    extra_segs = []
    for i, files in enumerate(extra):
        nm = "seg%d" % (i + 2)
        rt = "\n".join(thunked_runtime(far_helpers(),
                                       "\n".join(sum((read(f) for f in files), []))))
        with open(os.path.join(d, nm + "_rt.s"), "w") as f:
            f.write(rt + "\n")
        b, offs = code_seg(d, nm, LAYOUT + list(files) + [nm + "_rt.s"], offsets)
        if b is None:
            die("code segment %d is over 64 KB" % (i + 2))
        extra_segs.append({"bin": nm, "listing": nm + "_Output.txt", "kind": "CODE",
                           "bss": 0})
        if offs is not None:
            extra_segs[-1]["offsets"] = offs
    entry = fgx_ld.scan_listing(
        os.path.join(d, "seg0_Output.txt"), 2)["exports"].get("_crt0_dyn")
    if entry is None:
        die("seg0 exports no _crt0_dyn")
    m = {"output": "prog.bin", "format": "FGX3", "n_data_segment": 1,
         "entry_offset": entry, "flags": 0, "dynamic": True,
         "imports": [[so, lst] for so, lst, _t in libs.libs],
         "segments": [dict({"bin": "seg0", "listing": "seg0_Output.txt",
                            "kind": "CODE", "bss": 0},
                           **({} if offs0 is None else {"offsets": offs0})),
                      {"bin": "seg1", "listing": "seg1_Output.txt",
                       "kind": "DATA", "bss": 0}] + extra_segs}
    if frames:
        m["stack_frames"] = [os.path.relpath(os.path.realpath(f), os.path.realpath(d))
                             for f in frames]
    if stack_pad is not None:
        m["stack_pad"] = stack_pad
    mp = os.path.join(d, "dyn.json")
    with open(mp, "w") as f:
        json.dump(m, f, indent=1)
    r = subprocess.run([sys.executable, os.path.join(HERE, "fgx_ld.py"), mp])
    if r.returncode:
        die("fgx_ld refused the link (above)")
    return seg0


def link_once(d, code, data_rows, libs, shift, shadowed, gen, frames=None, extra=(),
              pack=(), stack_pad=None, offsets=True):
    """link_data, fgx_pack's groups for the `pack' files (the first joins
    `code', the rest follow `extra'), then link_code.  (seg0, seg1, code,
    extra) -- the last two with the packed files placed."""
    seg1 = link_data(d, data_rows, libs, shift, shadowed, gen)
    if pack:
        groups = pack_tus(d, code, pack)
        code = list(code) + groups[0]
        extra = list(extra) + groups[1:]
    seg0 = link_code(d, code, libs, frames, extra, stack_pad, offsets)
    return seg0, seg1, code, extra


def with_tables(a, end_a, imps, dseg=1, tseg=None):
    """The linked program with the binder's tables appended: the segment
    count, the data segment's index, a cell per segment (a word 0 and a bank
    byte the loader fills, as it fills any long pointer), IMPS's length and
    IMPS, then the bind record, zero (SP5 spec section 5.2): a word and 14
    bytes a library.  They go at the tail of the code segment with the most
    room or, if none has room, in an added code segment of their own (spec
    section 4.1).  (file bytes without a trailer, the tables' segment, the
    tables' offset in it)."""
    p = fgx_bind.parse(a[:end_a] + fgx_ld.dyn_trailer(b""))
    segs = [bytearray(s) for s, _b, _k in p["segs"]]
    bss = [b for _s, b, _k in p["segs"]]
    kinds = [k for _s, _b, k in p["segs"]]
    flags = list(p["flags"])
    nlib = imps[0] if imps else 0
    n = len(segs)
    size = 4 + 4 * (n + 1) + 2 + len(imps) + 2 + 14 * nlib   # room for one more cell
    code = [i for i, k in enumerate(kinds) if k == fgx_ld.KIND_MAP["CODE"]]
    if tseg is None:
        roomy = min(code, key=lambda i: len(segs[i]))
        tseg = roomy if len(segs[roomy]) + size <= 0xFFFF else None
    if tseg is None:
        # TCB_BankList has room for eight banks of the program's own
        # (fgx_ld), so a program with eight segments has nowhere to add one.
        if n >= 8:
            die("no code segment has room for the binder's tables (%d bytes) "
                "and the program has eight segments" % size)
        segs.append(bytearray())
        bss.append(0)
        kinds.append(fgx_ld.KIND_MAP["CODE"])
        flags.append(0)
        tseg = n
        n += 1
    t = len(segs[tseg])
    tab = struct.pack("<HBB", n, dseg, 0) + b"\0\0\0\0" * n \
        + struct.pack("<H", len(imps)) + imps + b"\0" * (2 + 14 * nlib)
    segs[tseg] += tab
    # Each cell's offset word gets an offset reloc when its segment may be
    # placed: ld_bind adds the cell's offset at every patch (ld_bind.c).
    relocs = sorted(set(p["relocs"]) | {(tseg, t + 4 + 4 * i + 2, i) for i in range(n)}
                    | {(tseg, t + 4 + 4 * i, 0x80 | i) for i in range(n) if flags[i]})
    head = bytearray(p["head"])
    head[6] = n
    struct.pack_into("<H", head, 11, len(relocs))
    body = bytes(head)
    for seg, b, k, fl in zip(segs, bss, kinds, flags):
        body += struct.pack("<HHBB2x", len(seg), b, k, fl)
    body += b"".join(bytes(s) for s in segs)
    body += b"".join(struct.pack("<BHB", *r) for r in relocs)
    return body, tseg, t


def add_reloc(body, r):
    """`body' (no trailer) with one more reloc (src segment, offset, target
    segment)."""
    p = fgx_bind.parse(body + fgx_ld.dyn_trailer(b""))
    relocs = sorted(set(p["relocs"]) | {r})
    head = bytearray(p["head"])
    struct.pack_into("<H", head, 11, len(relocs))
    out = bytes(head) + body[16:16 + 8 * head[6]]
    out += b"".join(bytes(s) for s, _b, _k in p["segs"])
    return out + b"".join(struct.pack("<BHB", *x) for x in relocs)


def ld_work_size():
    """sizeof (struct ld_work), the binder's scratch at the break
    (sys/ldctl.h), as fcc lays it out -- asked of fcc rather than counted,
    so the header and this check cannot drift apart."""
    import tempfile
    tc = os.path.join(HERE, "..", "..")
    with tempfile.TemporaryDirectory() as t:
        c = os.path.join(t, "lw.c")
        open(c, "w").write("#include <sys/types.h>\n#include <sys/uio.h>\n"
                           "#include <sys/ldctl.h>\n"
                           "int ld_work_size = sizeof (struct ld_work);\n")
        subprocess.run([os.path.join(tc, "fcc"), "-I", os.path.join(tc, "include"),
                        "--data-segment", os.path.join(t, "lw.data.s"),
                        c, "-o", os.path.join(t, "lw.s")], check=True)
        m = re.search(r"ld_work_size\s+DA\s+\$([0-9A-F]+)",
                      open(os.path.join(t, "lw.data.s")).read())
    if not m:
        die("cannot read sizeof (struct ld_work) back from fcc")
    return int(m.group(1), 16)


def fit_error(name, end, lowest, blocks, libc_core, work):
    """Why a program whose data ends at `end' cannot run, or None.  Its
    blocks go below the lowest needed core (`blocks' bytes); and the
    binder's scratch, `work' bytes at the even break, must end below
    libc's core, or ld_bind refuses every exec (ld_bind.c)."""
    lim = lowest - blocks
    if end > lim:
        return ("%s's data ends at $%04X, above LIM $%04X (cores from $%04X, "
                "%d bytes of blocks)" % (name, end, lim, lowest, blocks))
    if ((end + 1) & 0xFFFE) + work >= libc_core:
        return ("%s's data ends at $%04X: the binder's %d bytes of scratch "
                "need it below $%04X (libc's core at $%04X)"
                % (name, end, work, libc_core - work, libc_core))
    return None


def init_text(libs, need=None):
    """_crt0_inits for the needed libraries that have blocks to copy: a
    library whose reached blocks total 0 bytes gets no _lib_init call, which
    would only walk its block table to find nothing (`need' None: every
    library)."""
    names = [n for n in libs.names if need is None or need[n]]
    return "\n".join(fgx_static.inits(["_%s_blktab" % n for n in names],
                                      ["_dyn_bits_%s" % n for n in names]))


def build(name, d, code, data, out, lib_names, override=None, extra=(), pack=(),
          stack_pad=None):
    libs = Libs(lib_names, override)
    code_rows = sum((read(p) for p in list(code) + sum((list(x) for x in extra), [])
                     + list(pack)), [])
    data_rows = sum((read(p) for p in data), [])
    code_exports, _data, refs = program_names(code_rows, data_rows)
    operands = fgx_gc.operand_refs(fgx_gc.code_of(code_rows + data_rows).split("\n"))
    used = {libs.owner(n) for n in operands - code_exports} - {None}
    keep = [n for n in lib_names if n == "libc" or n in used]
    if keep != list(lib_names):
        libs = Libs(keep, override)        # adds each kept library's below
    rows, dropped, shadowed = split_data(data_rows, libs, code_exports)
    for n in shadowed:
        lib = libs.owner(n)
        sys.stderr.write("fgx_dyn: warning: %s defines %s, which %s exports; "
                         "its own references bind to its own, %s's internal "
                         "ones to %s's\n" % (name, n, lib, lib, lib))

    # _crt0_inits and the runtime first: their names are roots too (the
    # far entries, _lib_init, each library's block table).  A second pass
    # drops the inits of libraries left with nothing to copy; fewer roots
    # can only shrink what the others reach.
    crt0 = open(fgx_static.CRT0).read()
    exports = set(libs.data) | libs.code
    need = None
    for _pass in range(2):
        inits = init_text(libs, need)
        rt = "\n".join(thunked_runtime(far_helpers(),
                                       "\n".join(code_rows) + "\n" + crt0 + "\n" + inits))
        roots = (refs | set(fgx_gc.IDENT.findall(fgx_gc.code_of(
            (crt0 + "\n" + inits + "\n" + rt).split("\n"))))) & exports
        bits, need, _live = bitmaps(libs, roots)
        if all(need.values()):
            break
    # The binder and the load path, which crt0 enters through the registry
    # rather than by name, are charged to the stack (spec section 5.1).
    _b, _n, live = bitmaps(libs, roots | {"ld_bind"})
    gen = {"rt.s": rt + "\n", "inits.s": inits + "\n",
           "dyn.data.s": "".join("%-15s HEX     %s\n" % ("_dyn_bits_" + n, bits[n].hex().upper())
                                 for n in libs.names)
           + "_dyn_blk        DS      50\n"
           + "_dyn_nolibc     ASC     'ld.so: libc.so.1 not loaded'\n"
           + "                HEX     0A\n"
           + "".join(r + "\n" for r in fgx_static.end_rows(code_rows, data_rows, die))}

    frames = list(code) + sum((list(x) for x in extra), []) + list(pack)
    os.makedirs(d, exist_ok=True)
    fgx_libso.clear_outputs(d, OUTPUT)
    reach = {}
    for n in libs.names:
        reach["%s_reach.s" % n] = "                FGX2_MODE 2\n" + "".join(
            "\n".join(sect) + "\n" for sect in live[n])
        frames.append(os.path.join(d, "%s_reach.s" % n))
    seg0, seg1, code, extra = link_once(d, code, rows, libs, 0, shadowed,
                                        dict(gen, **reach), frames, extra, pack,
                                        stack_pad)
    sd = os.path.join(d, "shift")
    s0, s1, _c, _x = link_once(sd, code, rows, libs, fgx_sites.DELTA, shadowed, gen,
                               extra=extra, offsets=False)
    if (len(s0), len(s1)) != (len(seg0), len(seg1)):
        die("the shifted link's segments are %d and %d bytes, not %d and %d"
            % (len(s0), len(s1), len(seg0), len(seg1)))

    end = len(seg1)
    lim = libs.lowest - sum(need.values())
    libc_core = libs.libs[libs.names.index("libc")][2]["core_base"]
    err = fit_error(name, end, libs.lowest, sum(need.values()), libc_core,
                    ld_work_size())
    if err:
        die(err)

    a = open(os.path.join(d, "prog.bin"), "rb").read()
    b = open(os.path.join(sd, "prog.bin"), "rb").read()
    sa, end_a = fgx_libso.file_segments(a)
    sb, _e = fgx_libso.file_segments(b)
    old = fgx_imports.unpack(fgx_ld.read_dyn_trailer(a[end_a:])["blocks_raw"]["IMPS"])
    res = fgx_imports.Resolver([(so, lst) for so, lst, _t in libs.libs])
    for im in old["imports"]:
        for k in fgx_imports.SITES:
            for site in im[k]:
                res.use(im["kind"], im["name"], k, *site)
    objects = [(n, a_, sz) for n, (a_, sz) in libs.data.items() if n not in shadowed]
    for seg, (x, y) in enumerate(zip(sa, sb)):
        found = fgx_sites.attribute(fgx_sites.diff_sites(x, y), objects,
                                    "%s segment %d" % (name, seg))
        for obj, offs in found.items():
            for off, v in offs:
                res.use(1, obj, "data", seg, off, v)
    table = res.table()
    for lib in table["libs"]:
        lib["bitmap"] = bits[lib["name"]]
        lib["rows"] = len(json.load(open(fgx_libso.lib_file(lib["name"], "blocks")))["members"])
    ex = fgx_ld.scan_listing(os.path.join(d, "seg0_Output.txt"), 2)["exports"]
    body, tseg, t = with_tables(a, end_a, fgx_imports.pack(table))
    body = bytearray(body)
    cell = 16 + 8 * body[6] + ex["_dyn_tab"]           # segment 0 is first in the file
    struct.pack_into("<H", body, cell, t)
    body = add_reloc(bytes(body), (0, ex["_dyn_tab"] + 2, tseg))
    if body[16 + 8 * tseg + 5]:                         # FGX2_SEGF_PLACE
        body = add_reloc(body, (0, ex["_dyn_tab"], 0x80 | tseg))
    trailer = fgx_ld.dyn_trailer(fgx_ld.block(b"IMPS", fgx_imports.pack(table))
                                 + fgx_ld.block(b"ENTR", struct.pack("<H", ex["_crt0_lib"])))
    tmp = out + ".tmp"
    try:
        with open(tmp, "wb") as f:
            f.write(bytes(body) + trailer)
        os.replace(tmp, out)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)
    ims = table["imports"]
    n_sites = {k: sum(len(i[k]) for i in ims) for k in fgx_imports.SITES}
    print("dyn %s: seg0 %d bytes, data %d bytes, %d imports (%d call, %d pointer, "
          "%d data sites), LIM $%04X" % (name, len(seg0), len(seg1), len(ims),
                                         n_sites["call"], n_sites["ptr"],
                                         n_sites["data"], lim))
    return {"imports": ims, "dropped": dropped, "shadowed": shadowed,
            "lim": lim, "seg0": len(seg0), "seg1": len(seg1), "libs": libs.names}


def self_test():
    # A refused over-cap link leaves seg9 behind; it is still this driver's.
    for nm in ("seg0.s", "seg9", "seg9.link.s", "seg9_Output.txt", "seg10_rt.s"):
        assert OUTPUT.match(nm), nm
    assert not OUTPUT.match("notes.txt")
    far = far_helpers()
    assert "_fcc_fdiv" in far and "_fcc_fsub" not in far and len(far) == 9, far
    rows = thunked_runtime(far)
    text = "\n".join(rows)
    i = rows.index("_fcc_fdiv       MX      %00")
    assert rows[i + 1].split() == ["FGX2_FARCALL", "_fcc_fdiv_far"]
    assert rows[i + 2].split() == ["RTS"]
    assert any(r.startswith("_fcc_fadd") for r in rows)       # fsub's unit kept
    assert text.count("_fcc_fdiv       MX") == 1
    few = "\n".join(thunked_runtime(far, "  JSR _fcc_fdiv\n"))
    assert "FGX2_FARCALL _fcc_fdiv_far" in few
    assert "_fcc_fmul" not in few and "_fcc_long_divs" not in few  # unreached
    assert fgx_gc.operand_refs(["  DO main_STKGUARD", "  FGX2_FARCALL printf",
                        "lab LDA DO"]) == {"main_STKGUARD", "printf", "DO"}
    libs = Libs(["libc"])
    assert "errno" in libs.data and "printf" in libs.code
    assert Libs(["libtermlib"]).names == ["libc", "libtermlib"]
    rows, dropped, shadowed = split_data(
        ["errno           DS      2", "mine            DS      2",
         "optind          DA      1"], libs, {"fflush", "main"})
    assert dropped == ["errno"] and rows[0].startswith("mine")
    assert shadowed == ["fflush", "optind"], shadowed
    try:
        split_data(["errno           DS      64"], libs, set())
    except SystemExit as e:
        assert "64" in str(e) and "2" in str(e)
    else:
        raise AssertionError("a common larger than the export must be refused")
    bits, need, live = bitmaps(libs, {"strtok"})
    assert any(r.split()[:1] == ["strtok"] for r in sum(live["libc"], []))
    members = json.load(open(fgx_libso.lib_file("libc", "blocks")))["members"]
    order = sorted(members)
    i = order.index("strtok")
    assert bits["libc"][i >> 3] & (1 << (i & 7))
    j = order.index("ctime")
    assert not bits["libc"][j >> 3] & (1 << (j & 7))       # unreached
    assert need["libc"] == members["strtok"]["size"], need
    # a library with no reached blocks gets no _lib_init call
    assert "_lib_init" not in init_text(libs, {"libc": 0})
    assert init_text(libs, {"libc": 4}).count("FGX2_FARCALL _lib_init") == 1
    assert init_text(libs).count("FGX2_FARCALL _lib_init") == 1
    # the binder's scratch (struct ld_work) sits at the break, below libc's
    # core: a data end that leaves the blocks room but not the scratch fails
    assert fit_error("t", 0xF6A3 - 294, 0xF6A3, 0, 0xF6A3, 294) is not None
    assert fit_error("t", 0xF6A3 - 296, 0xF6A3, 0, 0xF6A3, 294) is None
    assert fit_error("t", 0xF000, 0xF6A3, 0x700, 0xF6A3, 294) is not None
    assert ld_work_size() == 294, ld_work_size()
    print("fgx_dyn: self-test OK")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--code", required=True, help="comma-separated .s files")
    ap.add_argument("--data", required=True, help="comma-separated .data.s files")
    ap.add_argument("--lib", required=True, help="comma-separated library names")
    ap.add_argument("--out", required=True)
    ap.add_argument("--so", action="append", default=[], help="NAME=PATH, as fgx_bind")
    ap.add_argument("--code-seg", action="append", default=[],
                    help="comma-separated .s files: one more code segment, in order")
    ap.add_argument("--pack", action="append", default=[],
                    help="comma-separated .s files packed into segment 0's room, "
                    "then into further code segments")
    ap.add_argument("--stack-pad", type=int, metavar="BYTES",
                    help="fgx_ld's stack_pad: bytes added to the measured stack")
    ap.add_argument("--split", action="store_true",
                    help="the one --code file is fcc --sections output too big "
                    "for a bank: its functions are packed one by one (fgx_pack)")
    a = ap.parse_args()
    code = [os.path.abspath(p) for p in a.code.split(",")]
    pack = [os.path.abspath(p) for x in a.pack for p in x.split(",")]
    if a.split:
        if len(code) != 1:
            die("--split takes one --code file")
        seg0, rest = fgx_pack.split_code(code[0],
                                         os.path.abspath(a.dir) + ".split")
        code, pack = [seg0], pack + rest
    build(a.name, os.path.abspath(a.dir),
          code,
          [os.path.abspath(p) for p in a.data.split(",")],
          os.path.abspath(a.out), a.lib.split(","),
          {k: os.path.abspath(v) for k, v in (x.split("=", 1) for x in a.so)},
          [[os.path.abspath(p) for p in s.split(",")] for s in a.code_seg],
          pack, a.stack_pad)
    return 0


if __name__ == "__main__":
    sys.exit(main())
