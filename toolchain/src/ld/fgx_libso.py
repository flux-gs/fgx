#!/usr/bin/env python3
"""fgx_libso.py - link libc's library-mode compile into libc.so (shared libc
SP2 spec, sections 3 and 4).

fgx_ld links segments that are already assembled; libc.so's code is one
compile of every member, far larger than a bank.  This driver splits
lib/libc_so.s into its FGX_SECT sections, measures each, packs the functions
into banks, gives each bank a copy of every string literal its functions
push with PHK, assembles the core template where the core sits in every
process and the block templates, assembles each bank, and hands the
segments to fgx_ld.

A literal used from two banks is in both.  Only the copy in the first bank
that holds it is exported, so a data-segment pointer to it (FGX2_LONG_PTR)
resolves there; nothing in libc compares literal addresses (K&R A.2.6 leaves
identical literals' distinctness to the implementation).

Run: python3 src/ld/fgx_libso.py [--self-test]      (from toolchain/)
"""
import os
import json
import shutil
import re
import subprocess
import sys
import struct
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fgx_gc  # noqa: E402

PREFIX = "_libc_c_"                      # fcc's static and literal prefix for libc_c.c
LIT = re.compile(r"^_libc_c_S\d+$")      # a string literal's section
LOOSE_OK = ("MX", "FGX2_MODE", "FGX2_RELOC_COUNT")


def die(msg):
    sys.exit("fgx_libso: " + msg)


def split_code(lines, path):
    """({section: rows}, [section, ...] in file order).  Outside a section
    only comments, MX, the MODE/RELOC_COUNT rows and Merlin variables may
    stand; anything else would be lost from every bank."""
    units, order = {}, []
    for u in fgx_gc.split_sections(lines, path):
        if u[0] == "sect":
            units[u[1]] = u[2]
            order.append(u[1])
            continue
        for ln in u[1]:
            t = ln.split()
            if not t or t[0][0] in ";*]" or t[0] in LOOSE_OK:
                continue
            die("%s: '%s' stands outside every section" % (path, ln.strip()))
    return units, order


def literal_refs(units, names):
    """{section: sorted literals its code names}."""
    return {n: sorted({t for t in fgx_gc.IDENT.findall(fgx_gc.code_of(units[n]))
                       if LIT.match(t)})
            for n in names}


LEAVES = ("RTS", "RTL", "JMP", "JML", "BRA", "BRL")
RT_LABEL = re.compile(r"^(_fcc_[A-Za-z0-9_]+)(\s|$)")


def _op(row):
    """A row's operation, or None for a blank, comment or label-only row."""
    s = fgx_gc.COMMENT.sub("", row).rstrip()
    if not s.strip() or s.lstrip()[0] in ";*":
        return None
    t = s.split()
    if row[0] not in " \t":
        t = t[1:]
    return t[0].upper() if t else None


def runtime_units(lines):
    """fcc_runtime.s as sections, split in memory (the file is shared with
    the kernel's fcc_rt.s and every link template, so it carries no
    markers).  A unit starts at a column-1 _fcc_ label and runs to the
    next; one whose last instruction does not leave (RTS, RTL, JMP, JML,
    BRA, BRL) falls into the next, so the two are one unit.  EQU rows, and
    everything before the first label, are the head every bank PUTs."""
    head, units, order, cur = [], {}, [], None
    for ln in lines:
        op = _op(ln)
        if op in ("EQU", "="):
            head.append(ln)
            continue
        m = RT_LABEL.match(ln)
        if m:
            last = [o for o in map(_op, units[cur]) if o] if cur else []
            if cur is None or (last and last[-1] in LEAVES):
                cur = m.group(1)
                units[cur] = ["                FGX_SECT %s" % cur]
                order.append(cur)
        (units[cur] if cur else head).append(ln)
    for u in order:
        units[u].append("                FGX_ENDS")
    return head, units, order


def shared_owner(units, shared):
    """{label: the shared unit that defines it}."""
    own = {}
    for s in shared:
        for lab in fgx_gc.defined_labels(units[s]) | {s}:
            own[lab] = s
    return own


def shared_refs(units, names, own):
    """{name: every shared unit it reaches, directly or through another}."""
    def direct(n):
        return {own[t] for t in fgx_gc.IDENT.findall(fgx_gc.code_of(units[n]))
                if t in own and own[t] != n}
    out = {}
    for n in names:
        seen, todo = set(), list(direct(n))
        while todo:
            s = todo.pop()
            if s not in seen:
                seen.add(s)
                todo += direct(s)
        out[n] = sorted(seen)
    return out


def pack(sizes, refs, lsizes, budgets, pre=(), first=()):
    """First fit by decreasing size (name breaks ties).  A function costs its
    bytes plus each literal it names that its bank does not hold yet.
    Bank 0 starts holding `pre', and the functions `first' go in bank 0
    before any other (they near-call a label bank 0's fixed files define).
    (banks, held, free), or None if a function fits no bank."""
    banks = [[] for _ in budgets]
    held = [set() for _ in budgets]
    free = list(budgets)
    held[0].update(pre)
    free[0] -= sum(lsizes[l] for l in pre)
    if free[0] < 0:
        return None
    order = sorted(first, key=lambda n: (-sizes[n], n)) + \
        sorted((n for n in sizes if n not in first), key=lambda n: (-sizes[n], n))
    for f in order:
        for b in (range(1) if f in first else range(len(budgets))):
            new = [l for l in refs[f] if l not in held[b]]
            cost = sizes[f] + sum(lsizes[l] for l in new)
            if cost <= free[b]:
                banks[b].append(f)
                held[b].update(new)
                free[b] -= cost
                break
        else:
            return None
    return banks, held, free


def pack_min(sizes, refs, lsizes, budget0, budgetn, nmax, orphans=(), pre=(),
             first=(), tail=0):
    """The fewest banks that hold every function and every literal only data
    points at (`orphans'); bank 0 carries libc's hand-written code, so its
    budget is its own.  The last bank also carries `tail' bytes: the core
    template, the block templates and the trailer's tagged blocks, which
    the loader places after its code (shared libc SP4 spec, section 5.2).
    That bank is filled second, after bank 0, and moved last: filled last,
    it would be the empty one whenever the code alone fits a bank fewer,
    and fgx_ld refuses an empty segment."""
    for n in range(1, nmax + 1):
        budgets = [budget0] + [budgetn] * (n - 1)
        budgets[min(1, n - 1)] -= tail
        if min(budgets) < 0:
            continue
        got = pack(sizes, refs, lsizes, budgets, pre, first)
        if got and n > 2:
            perm = [0] + list(range(2, n)) + [1]
            got = tuple([x[i] for i in perm] for x in got)
        if got and fit_orphans(orphans, got[1], got[2], lsizes):
            return got
    big = max(sizes, key=lambda n: sizes[n])
    die("libc does not fit %d code banks (largest function %s, %d bytes)"
        % (nmax, big, sizes[big]))


def fit_orphans(need, held, free, lsizes):
    """Literals only data points at: each into the first bank with room.
    False if one fits nowhere."""
    for l in sorted(need):
        if any(l in h for h in held):
            continue
        for b in range(len(held)):
            if lsizes[l] <= free[b]:
                held[b].add(l)
                free[b] -= lsizes[l]
                break
        else:
            return False
    return True


def place_orphans(need, held, free, lsizes):
    if not fit_orphans(need, held, free, lsizes):
        die("no bank has room for the literals only data points at")


def canonical(held):
    """{literal: the first bank that holds it}, the copy that is exported."""
    canon = {}
    for b, h in enumerate(held):
        for l in h:
            canon.setdefault(l, b)
    return canon


def bank_rows(units, order, funcs, held_b, canon, b, lit=None):
    """Bank b's source rows: its functions and literal copies in file order,
    a copy's export row only where the copy is canonical, and the RELOC_COUNT
    fgx_ld checks the listing against."""
    lit = lit or LIT
    keep = set(funcs) | set(held_b)
    rows = ["                FGX2_MODE 2", "                MX      %00"]
    for n in order:
        if n not in keep:
            continue
        for ln in units[n]:
            if lit.match(n) and canon[n] != b and ln.split()[:1] == ["FGX2_EXPORT"]:
                continue
            rows.append(ln)
    rows.append("                FGX2_RELOC_COUNT %d" % fgx_gc.fgx2_rows(rows))
    return rows



HERE = os.path.dirname(os.path.abspath(__file__))
TC = os.path.dirname(os.path.dirname(HERE))              # toolchain/
LIB = os.path.join(TC, "lib")
sys.path.insert(0, HERE)
import fgx_ld  # noqa: E402

CAP = 0xFFFF                     # fgx_ld's largest segment
MAX_CODE_BANKS = 6               # 8 segments (a 9th must be LIBC) less core, templates
MACROS = os.path.join(LIB, "macros.s")
RUNTIME = os.path.join(LIB, "fcc_runtime.s")
LLONG = sorted(os.path.join(LIB, "libllong", f)
               for f in os.listdir(os.path.join(LIB, "libllong"))
               if f.endswith(".s") and not f.endswith(".data.s"))
LLONG_DATA = sorted(os.path.join(LIB, "libllong", f)
                    for f in os.listdir(os.path.join(LIB, "libllong"))
                    if f.endswith(".data.s"))
BANK0 = [os.path.join(LIB, "libc.s"), os.path.join(LIB, "fcc_libc_shims.s")] \
    + LLONG + [os.path.join(LIB, "libdouble", "d_stub.s"),
               os.path.join(LIB, "libc_start.s"),
               os.path.join(LIB, "ld_bind_asm.s")]
# libc.so's bank 0 also carries the far entries for the helpers the census
# chose (tools/helper_census.py), so each sits in one bank with its helper.
# A static link (fgx_static) calls its helpers near and leaves them out.
LIBSO_BANK0 = BANK0 + [os.path.join(LIB, "libc_so_helpers.s"),
                       os.path.join(LIB, "ld_bind_entry.s")]
DATA = [os.path.join(LIB, f) for f in ("libc_data.s", "args_data.s",
                                       "fcc_runtime_data.s",
                                       "libc_start_data.s")] + LLONG_DATA
# The EQUs every libc code bank assembles with: the syscall numbers the
# runtime traps with, the trampoline, and LIBC_FAR for the far-call build.
CODE_EQUS = [("SYS_EXIT", "1"), ("SYS_WRITE", "4"), ("SYS_TRAMP", "$000328"),
             ("LIBC_FAR", "1")]
# The direct-page cells fcc's string members share with the shims
# (fcc_libc_shims.s:70-71), which define them in bank 0; every other bank's
# code names them too.
DP_EQUS = [("c_strcmp_a", "$F2"), ("c_strcmp_b", "$F5")]
# The EQUs every data segment assembles with: the argv cap args_data.s sizes
# its vector by (tools/check_argv_caps.py holds ARGS_MAX to the kernel's).
DATA_EQUS = [("ARGS_MAX", "16"), ("ARGS_INPUT_MAX", "128")]


def write_link(d, name, org, equs, puts, pad=0):
    """<name>.link.s: one segment, assembled at `org' in bank $0B, starting
    with `pad' zero bytes."""
    with open(os.path.join(d, name + ".link.s"), "w") as f:
        f.write("                TYP    $06\n                DSK    %s\n" % name)
        f.write("                ORG    $0B%04X\n                MX     %%11\n" % org)
        for k, v in equs:
            f.write("%-18s EQU    %s\n" % (k, v))
        if pad:
            f.write("                DS     %d\n" % pad)
        for p in puts:
            # Relative to the directory's REAL path: Merlin resolves a PUT
            # from where it runs, and macOS's temp dirs sit behind the
            # /var -> /private/var link.
            f.write("                PUT    %s\n" % (
                p if not os.path.isabs(p)
                else os.path.relpath(os.path.realpath(p), os.path.realpath(d))))
    return name + ".link.s"


def run_merlin(d, link):
    """The segment's bytes, or None when it is over 64 KB."""
    dsk = link[:-len(".link.s")]
    for f in (dsk, dsk + "_Output.txt", "error_output.txt"):
        try:
            os.remove(os.path.join(d, f))
        except OSError:
            pass
    r = subprocess.run(["merlin32", "-V", ".", link], cwd=d,
                       capture_output=True, text=True)
    out = os.path.join(d, dsk)
    if r.returncode == 0 and os.path.exists(out):
        return open(out, "rb").read()
    err = os.path.join(d, "error_output.txt")
    text = (open(err).read() if os.path.exists(err) else "") + r.stdout
    if "Object code size > 64 KB" in text:
        return None
    die("%s does not assemble:\n%s" % (link, text[-1200:]))


def section_sizes(listing, src_name):
    """{section: bytes} from the FGX_SECT/FGX_ENDS rows `src_name' contributes
    to a listing: the gap between the two rows' addresses."""
    sizes, cur = {}, None
    for raw in open(listing, errors="replace"):
        parts = [p.strip() for p in raw.split("|")]
        if len(parts) < 8 or parts[2] != "Macro":
            continue
        where = parts[1].split()
        tok = parts[7].split()
        if len(where) < 2 or where[1] != src_name or not tok:
            continue
        bank, off = parts[6].split()[0].split("/")
        addr = int(bank, 16) << 16 | int(off, 16)
        if tok[0] == "FGX_SECT" and len(tok) > 1:
            cur = (tok[1], addr)
        elif tok[0] == "FGX_ENDS" and cur:
            sizes[cur[0]] = addr - cur[1]
            cur = None
    return sizes


def write_units(path, names, units):
    rows = ["                MX      %00"]
    for n in names:
        rows += units[n]
    with open(path, "w") as f:
        f.write("\n".join(rows) + "\n")


def measure(d, funcs, lits, units, layout, code_equs=None):
    """({function: bytes}, {literal: bytes}), halving any run over 64 KB.
    Every run carries all the literals, so each `LDA #literal' resolves."""
    write_units(os.path.join(d, "lits.s"), lits, units)
    sizes, lsizes, todo, k = {}, {}, [list(funcs)], 0
    while todo:
        part = todo.pop()
        src = "m%d.s" % k
        write_units(os.path.join(d, src), part, units)
        link = write_link(d, "m%d" % k, 0, (code_equs or CODE_EQUS) + DP_EQUS,
                          [MACROS] + ([layout] if isinstance(layout, str) else layout)
                          + [src, "lits.s", "rt_head.s"])
        k += 1
        if run_merlin(d, link) is None:
            if len(part) == 1:
                die("function %s alone is over 64 KB" % part[0])
            todo += [part[:len(part) // 2], part[len(part) // 2:]]
            continue
        lst = os.path.join(d, link[:-len(".link.s")] + "_Output.txt")
        sizes.update(section_sizes(lst, src))
        if not lsizes:
            lsizes = section_sizes(lst, "lits.s")
    missing = [n for n in list(funcs) + list(lits) if n not in sizes and n not in lsizes]
    if missing:
        die("no size measured for %s" % missing[:5])
    return sizes, lsizes


def blktab(members, sizes, name="libc"):
    """_<name>_blktab: per member (sorted), its cell's address, a far pointer
    to its template and its size; a zero word ends it (libc_c/libc_init.c
    reads it)."""
    rows = ["_%s_blktab    ANOP" % name]
    for m in sorted(members):
        rows += ["                DA      _%s_blk_%s" % (name, m),
                 "                FGX2_LONG_PTR _bt;%s__BT;0" % m,
                 "                DA      %d" % sizes[m]]
    rows.append("                DA      0")
    return rows


def write_data(path, units):
    rows = ["                FGX2_MODE 2"]
    for u in units:
        rows += u[2]
    rows.append("                FGX2_RELOC_COUNT %d" % fgx_gc.fgx2_rows(rows))
    with open(path, "w") as f:
        f.write("\n".join(rows) + "\n")


# Every file build() and Merlin32 write in its directory; a rerun that packs
# fewer banks must not leave an old bank's source or listing behind.
OUTPUT = re.compile(r"^(?:(?:bank\d+|m\d+|ov0|ovn|core|tmpl|lits|rt_head|pre0|core_layout|"
                    r"imports_layout|b0_equs|dataptr_mac|rt_data)(?:\.s|\.link\.s|_Output\.txt)?|\w+_so\.json|"
                    r"shift|scratch\.so|error_output\.txt|_FileInformation\.txt)$")


def clear_outputs(d, pattern=OUTPUT):
    """Remove the driver's previous outputs from d, refusing a directory that
    holds anything else (it is not the driver's)."""
    names = os.listdir(d)
    alien = [n for n in names if not pattern.match(n)]
    if alien:
        die("%s holds %s, which fgx_libso does not write; give it a "
            "directory of its own" % (d, ", ".join(sorted(alien)[:3])))
    for n in names:
        q = os.path.join(d, n)
        if os.path.isdir(q):
            shutil.rmtree(q)
        else:
            os.remove(q)


# Every library libc.so's link path builds (shared libc SP3 spec, section
# 2).  Paths are relative to lib/.  `below' are the libraries it imports
# from, in load order; `under' are further libraries whose cores its own
# stacks below, so that no two libraries' assembled cores overlap (a
# dynamic link attributes a data site to a library by its address);
# `dir' is its build directory, whose core listing a library above reads;
# `equs' are code EQUs its sources name that libc.s defines (a library
# above libc does not PUT libc.s).  The stacking order is libc, libfgx,
# libtermlib, libcurses, libutil: libc and libfgx, which /etc/ld.so.conf
# makes resident at boot, first, so a library loaded on first use lands
# where it was assembled.
LIBS = {
    "libc": dict(code="libc_so.s", data="libc_so_data.s",
                 blocks="libc_so.blocks.json", core_list="libc_c/core.list",
                 exports="libc_c/data.exports", prefix=PREFIX,
                 bank0=LIBSO_BANK0, data_files=DATA, below=[], version=[1, 0],
                 dir="libc_so.d", equs=[]),
    "libfgx": dict(code="libfgx_so.s", data="libfgx_so_data.s",
                   blocks="libfgx_so.blocks.json", core_list=None,
                   exports="libfgx_c/data.exports", prefix="_libfgx_",
                   bank0=[], data_files=[os.path.join(LIB, "fcc_runtime_data.s")],
                   below=["libc"], version=[1, 0], dir="libfgx_so.d",
                   equs=[("LIBC_DP_LP0", "$EB"), ("LIBC_DP_DST", "$E6")]),
    "libtermlib": dict(code="libtermlib_so.s", data="libtermlib_so_data.s",
                       blocks="libtermlib_so.blocks.json", core_list=None,
                       exports="libtermlib_c/data.exports", prefix="_libtermlib_",
                       bank0=[os.path.join(LIB, "libtermlib_helpers.s")],
                       data_files=[os.path.join(LIB, "fcc_runtime_data.s"),
                                   os.path.join(LIB, "libtermlib_helpers_data.s")],
                       below=["libc"], under=["libfgx"], version=[1, 0],
                       dir="libtermlib_so.d",
                       equs=[("LIBC_DP_LP0", "$EB"), ("LIBC_DP_DST", "$E6")]),
    "libcurses": dict(code="libcurses_so.s", data="libcurses_so_data.s",
                      blocks="libcurses_so.blocks.json",
                      core_list="libcurses_c/core.list",
                      exports="libcurses_c/data.exports", prefix="_libcurses_",
                      bank0=[], data_files=[os.path.join(LIB, "fcc_runtime_data.s")],
                      below=["libc", "libtermlib"], version=[1, 0],
                      dir="libcurses_so.d",
                      equs=[("LIBC_DP_LP0", "$EB"), ("LIBC_DP_DST", "$E6")]),
    "libutil": dict(code="libutil_so.s", data="libutil_so_data.s",
                    blocks="libutil_so.blocks.json", core_list=None,
                    exports="libutil_c/data.exports", prefix="_libutil_",
                    bank0=[], data_files=[os.path.join(LIB, "fcc_runtime_data.s")],
                    below=["libc"], under=["libcurses"], version=[1, 0],
                    dir="libutil_so.d",
                    equs=[("LIBC_DP_LP0", "$EB"), ("LIBC_DP_DST", "$E6")]),
}


def lib_file(name, key):
    v = LIBS[name][key]
    return v and os.path.join(LIB, v)


def so_path(name):
    return os.path.join(LIB, "%s.so.%d.%d" % ((name,) + tuple(LIBS[name]["version"])))


def lower(name, key="below"):
    """[(so path, core listing, trailer)] of the libraries below `name'
    (or, with key="under", of those its core stacks under besides)."""
    import fgx_imports
    out = []
    for b in LIBS[name].get(key, []):
        so = so_path(b)
        if not os.path.exists(so):
            die("%s needs %s, which is not built" % (name, so))
        out.append((so, os.path.join(LIB, LIBS[b]["dir"], "core_Output.txt"),
                    fgx_imports.file_trailer(open(so, "rb").read())))
    return out


def data_imports(libs):
    """[(name, addr, size)] of every data export of the libraries below."""
    return [(e[0], e[3], e[4]) for _so, _l, tr in libs
            for e in tr["exports"] if e[1] == 1]


def core_link(d, name="libc", shift=0, libs=None, core_pad=0):
    """The library's core, assembled at its base, and d/core_layout.s, the
    EQUs every code bank -- and anything else that assembles the fcc
    runtime, which names the core's cells -- takes its labels from.  Also
    writes d/core.s (with the block table) and d/tmpl.s.  libc's core ends
    at HEAP_LIM; a library above libc stacks directly below the lowest core
    of the libraries it imports from or stacks under, then `shift' lower
    (the site link).
    (size, base)."""
    L = LIBS[name]
    libs = libs if libs is not None else lower(name)
    data_path = lib_file(name, "data")
    dunits = fgx_gc.split_sections(open(data_path).read().split("\n"), data_path)
    for u in dunits:
        if u[0] == "loose":
            split_code(u[1], data_path)          # the same loose-row rule
    # A tentative definition of a lower library's data export is an import
    # of it (K&R A.10.2's common extension): curses's `char *BC;'.
    imported = {n for n, _a, _s in data_imports(libs)}
    sects = [u for u in dunits if u[0] == "sect"
             and not ((fgx_gc.is_common(u[2]) or ("",))[0] in imported)]
    members = json.load(open(lib_file(name, "blocks")))["members"]
    core_units = [u for u in sects if not u[1].endswith("__BT")]
    core_units.append(("sect", "_%s_blktab" % name,
                       blktab(members, {m: v["size"] for m, v in members.items()},
                              name)))
    if core_pad:
        # A core `core_pad' bytes larger: every core address moves down by
        # it, so the export table's CRC changes (the by-name bind's probe).
        core_units.append(("sect", "_%s_pad" % name,
                           ["_%s_pad%s DS      %d" % (name, " " * max(1, 10 - len(name)),
                                                      core_pad)]))
    write_data(os.path.join(d, "core.s"), core_units)
    write_data(os.path.join(d, "tmpl.s"), [u for u in sects if u[1].endswith("__BT")])
    data_files = [runtime_data(d, imported) if libs and f == RUNTIME_DATA else f
                  for f in L["data_files"]]
    puts = [MACROS] + (["dataptr_mac.s"] if libs else []) + data_files \
        + (["imports_layout.s"] if libs else []) + ["core.s"]
    if libs:
        write_imports_layout(d, libs, shift)
        write_dataptr_mac(d)
    size = len(run_merlin(d, write_link(d, "core", 0x100, DATA_EQUS, puts)))
    over = libs + (lower(name, "under") if libs else [])
    top = min(tr["core_base"] for _so, _l, tr in over) if over else fgx_ld.HEAP_LIM
    base = top - size - shift
    core = run_merlin(d, write_link(d, "core", base, DATA_EQUS, puts))
    if len(core) != size:
        die("the core is %d bytes at $%04X but %d when measured" % (len(core), base, size))
    subprocess.run([sys.executable, os.path.join(TC, "tools", "gen_seg1_layout.py"),
                    os.path.join(d, "core_Output.txt"),
                    os.path.join(d, "core_layout.s")], check=True,
                   stdout=subprocess.DEVNULL if libs else None)
    return size, base


def write_dataptr_mac(d):
    """d/dataptr_mac.s: the LIBC_DATA_PTR macro fcc's `&global' initialisers
    use, taken from libc_data.s, which defines it and which a library above
    libc does not PUT."""
    rows, on = [], False
    for ln in open(os.path.join(LIB, "libc_data.s")):
        on = on or ln.split()[:2] == ["LIBC_DATA_PTR", "MAC"]
        if on:
            rows.append(ln)
            if ln.split()[:1] == ["<<<"]:
                break
    if not rows or rows[-1].split()[:1] != ["<<<"]:
        die("libc_data.s no longer defines the LIBC_DATA_PTR macro")
    with open(os.path.join(d, "dataptr_mac.s"), "w") as f:
        f.writelines(rows)


RUNTIME_DATA = os.path.join(LIB, "fcc_runtime_data.s")
RT_LABEL_ROW = re.compile(r"^([A-Za-z_]\w*)\b")


def runtime_data(d, imported):
    """d/rt_data.s: fcc_runtime_data.s less every cell a lower library
    exports, for a program or library above libc.  The long long carrier's
    high words (_fcc_q2 ... _fcc_qb3) are the argument cells of libc.so's
    long long and double entries, which read libc's own copies: a module
    holding copies of its own would hand those entries operands they never
    see.  So the cells libc exports bind to libc's, and the rest of the
    runtime's scratch stays the module's.  Returns the file's path."""
    rows = []
    for r in open(RUNTIME_DATA).read().split("\n"):
        m = RT_LABEL_ROW.match(r)
        if m and m.group(1) in imported:
            continue
        rows.append(r)
    path = os.path.join(d, "rt_data.s")
    with open(path, "w") as f:
        f.write("\n".join(rows))
    return path


def write_imports_layout(d, libs, shift):
    with open(os.path.join(d, "imports_layout.s"), "w") as f:
        for n, a, _s in data_imports(libs):
            f.write("%-18s EQU    $%04X\n" % (n, a - shift))


def near_callers(units, funcs, bank0_files):
    """Functions that near-call (JSR/JMP, as termlib's inline __asm does) a
    label bank 0's fixed files define: they must sit in bank 0.
    (functions, the labels they near-call)."""
    labs = set()
    for p in bank0_files:
        labs |= fgx_gc.defined_labels(open(p).read().split("\n"))
    out, called = set(), set()
    for f in funcs:
        for r in units[f]:
            t = fgx_gc.COMMENT.sub("", r).split()
            if r[:1] not in (" ", "\t"):
                t = t[1:]
            if len(t) > 1 and t[0].upper() in ("JSR", "JMP") and t[1] in labs:
                out.add(f)
                called.add(t[1])
    return out, called


def check_private(name, units, funcs, libs, own):
    """A library may name only the exports of the libraries below it."""
    import fgx_imports
    res = fgx_imports.Resolver([(so, l) for so, l, _t in libs], own)
    bad = sorted({t for f in funcs for t in fgx_gc.IDENT.findall(
        fgx_gc.code_of(units[f])) if res.private(t)})
    if bad:
        die("%s names %s, private cells of the libraries below; a library "
            "may import only exports" % (name, ", ".join(bad[:8])))


def tagged_bytes(path):
    """What the loader places after a linked library's templates: its
    trailer's EXPT and FIXS blocks, tagged, the export index ld_load builds
    (XIDX: 12 bytes and 2 an export), and an END tag."""
    data = open(path, "rb").read()
    _segs, pos = file_segments(data)
    tr = fgx_ld.read_trailer(data[pos:])
    raw = tr["blocks_raw"]
    return 36 + len(raw.get("EXPT", b"")) + len(raw.get("FIXS", b"")) \
        + 2 * len(tr["exports"])


def last_bank_need(path, n_code):
    """The last code bank's bytes once loaded: its code, the core and block
    templates, and the tagged blocks."""
    segs, _pos = file_segments(open(path, "rb").read())
    return sum(len(s) for s in segs[n_code - 1:]) + tagged_bytes(path)


def tagged_guess(name, units, funcs):
    """tagged_bytes before the link: an EXPT record (namelen, name, kind,
    segment, value, size) and an XIDX entry per public code export and per
    data export; FIXS taken as empty, which the link's check then settles."""
    L = LIBS[name]
    bp = "_libc_blk_" if name == "libc" else "_%s_blk_" % name
    names = set(fgx_ld.read_names(lib_file(name, "exports")))
    for f in funcs:
        for ln in units[f]:
            t = ln.split()
            if t[:1] == ["FGX2_EXPORT"] and len(t) > 1:
                n = t[1]
                if not (n.startswith(L["prefix"]) or n.startswith(bp)
                        or n.endswith("__BT")):
                    names.add(n)
    return 36 + sum(9 + len(n) for n in names)


def link_lib(name, out, d, shift=0, core_pad=0, tagged=None):
    """Link the library into `out' through d.  {banks, base, size, need,
    tagged}: `need' is the last bank's bytes once loaded, which must fit
    64 KB; `tagged' the tail's estimate to use, or None to guess it."""
    L = LIBS[name]
    os.makedirs(d, exist_ok=True)
    clear_outputs(d)
    libs = lower(name)
    lit = re.compile(r"^%sS\d+$" % re.escape(L["prefix"]))
    code_path = lib_file(name, "code")
    units, order = split_code(open(code_path).read().split("\n"), code_path)
    size, base = core_link(d, name, shift, libs, core_pad)

    tmpl = run_merlin(d, write_link(d, "tmpl", 0, DATA_EQUS,
                                    [MACROS, "core_layout.s", "tmpl.s"]))

    funcs = [n for n in order if not lit.match(n)]
    lits = [n for n in order if lit.match(n)]
    if libs and not shift:
        own = {n for _a, n in fgx_ld.gen_seg1_layout.extract_labels(
            os.path.join(d, "core_Output.txt"))}
        check_private(name, units, funcs, libs, own)
    # The runtime joins AFTER funcs/lits are taken from `order': its units
    # are shared sections, charged per bank like literals, never functions.
    rt_head, rt_units, rt_order = runtime_units(open(RUNTIME).read().split("\n"))
    with open(os.path.join(d, "rt_head.s"), "w") as f:
        f.write("\n".join(rt_head) + "\n")
    units.update(rt_units)
    order += rt_order
    shared = lits + rt_order
    own_sh = shared_owner(units, shared)
    bank0 = L["bank0"]
    bank0_text = "\n".join(open(p).read() for p in bank0)
    pre0 = shared_refs(dict(units, bank0=bank0_text.split("\n")), ["bank0"],
                       own_sh)["bank0"]
    first, called = near_callers(units, funcs, bank0)
    # Measuring runs without bank 0's files: the labels its functions
    # near-call stand in as EQUs (a JSR's operand is two bytes either way).
    b0 = []
    if called:
        with open(os.path.join(d, "b0_equs.s"), "w") as f:
            f.write("".join("%-18s EQU    $8000\n" % n for n in sorted(called)))
        b0 = ["b0_equs.s"]
    layouts = ["core_layout.s"] + (["imports_layout.s"] if libs else [])
    code_equs = CODE_EQUS + L["equs"]
    sizes, lsizes = measure(d, funcs, shared, units,
                            layouts[0] if not (libs or b0) else layouts + b0,
                            code_equs)
    # Bank 0's fixed files call the helpers pre0 holds (the far entries JSR
    # theirs), so they assemble only with them; pack charges pre0 itself,
    # so its measured bytes come back out of the overhead.
    write_units(os.path.join(d, "pre0.s"), pre0, units)
    ov0 = len(run_merlin(d, write_link(d, "ov0", 0, code_equs if libs else CODE_EQUS,
                                       [MACROS] + layouts + bank0
                                       + ["pre0.s", "rt_head.s"]))) \
        - sum(lsizes[u] for u in pre0)
    ovn = len(run_merlin(d, write_link(d, "ovn", 0, code_equs + DP_EQUS,
                                       [MACROS] + layouts + ["rt_head.s"])))
    if ovn != 0:
        die("the runtime head emits %d bytes; it must emit none" % ovn)
    refs = shared_refs(units, funcs, own_sh)
    data_text = open(os.path.join(d, "core.s")).read() + open(os.path.join(d, "tmpl.s")).read()
    if tagged is None:
        tagged = tagged_guess(name, units, funcs)
    banks, held, free = pack_min(
        sizes, refs, lsizes, CAP - ov0, CAP - ovn, MAX_CODE_BANKS,
        {t for t in fgx_gc.IDENT.findall(data_text) if lit.match(t)}, pre0,
        first, tail=size + len(tmpl) + tagged)
    canon = canonical(held)

    segs = []
    for b, fs in enumerate(banks):
        rows = bank_rows(units, order, fs, held[b], canon, b, lit)
        with open(os.path.join(d, "bank%d.s" % b), "w") as f:
            f.write("\n".join(rows) + "\n")
        puts = [MACROS] + layouts + (bank0 if b == 0 else []) \
            + ["bank%d.s" % b, "rt_head.s"]
        equs = (code_equs if libs else CODE_EQUS) if b == 0 else code_equs + DP_EQUS
        got = run_merlin(d, write_link(d, "bank%d" % b, 0, equs, puts))
        want = (ov0 if b == 0 else ovn) + sum(sizes[f] for f in fs) \
            + sum(lsizes[l] for l in held[b])
        if got is None or len(got) != want:
            die("bank %d assembled to %s bytes; its sections measured %d"
                % (b, "over 64K" if got is None else len(got), want))
        segs.append({"bin": "bank%d" % b, "listing": "bank%d_Output.txt" % b,
                     "kind": "CODE", "bss": 0})
    n_core = len(segs)
    segs.append({"bin": "core", "listing": "core_Output.txt", "kind": "DATA",
                 "bss": 0, "org": base})
    segs.append({"bin": "tmpl", "listing": "tmpl_Output.txt", "kind": "RODATA",
                 "bss": 0})
    manifest = {"output": os.path.basename(out), "format": "FGX3",
                "n_data_segment": n_core, "entry_offset": 0, "flags": 0,
                "segments": segs}
    manifest["library"] = {
        "core": n_core, "templates": n_core + 1,
        "blocks": os.path.relpath(lib_file(name, "blocks"), d),
        "data_exports": os.path.relpath(lib_file(name, "exports"), d),
        "static_prefix": L["prefix"], "version": L["version"]}
    if L["core_list"]:
        manifest["library"]["core_list"] = os.path.relpath(lib_file(name, "core_list"), d)
    if name != "libc":
        manifest["library"]["blk_prefix"] = "_%s_blk_" % name
    if libs:
        manifest["imports"] = [[os.path.relpath(so, d), os.path.relpath(l, d)]
                               for so, l, _t in libs]
    mpath = os.path.join(d, "%s_so.json" % name)
    with open(mpath, "w") as f:
        json.dump(manifest, f, indent=1)
    subprocess.run([sys.executable, os.path.join(HERE, "fgx_ld.py"), mpath,
                    "-o", out], check=True)
    return {"banks": banks, "base": base, "size": size, "free": free,
            "tmpl": len(tmpl), "libs": libs, "tagged": tagged,
            "need": last_bank_need(out, len(banks)),
            "tagged_exact": tagged_bytes(out)}


def file_segments(data):
    n = data[6]
    pos, out = 16 + 8 * n, []
    for i in range(n):
        size = struct.unpack_from("<H", data, 16 + 8 * i)[0]
        out.append(data[pos:pos + size])
        pos += size
    return out, pos + 4 * struct.unpack_from("<H", data, 11)[0]


def add_sites(name, out, scratch, info):
    """Link twice, diff: each 16-bit word the shift moved is a data site.
    One in the library's own core goes in the CSIT block, one in a lower
    library's data export in the IMPS table beside fgx_ld's call and
    pointer sites.  The trailer is rewritten with both."""
    import fgx_imports
    import fgx_sites
    a, b = open(out, "rb").read(), open(scratch, "rb").read()
    sa, end = file_segments(a)
    sb, _e = file_segments(b)
    objects = [("core", info["base"], info["size"])] + data_imports(info["libs"])
    tr = fgx_ld.read_trailer(a[end:])
    res = fgx_imports.Resolver([(so, l) for so, l, _t in info["libs"]])
    old = fgx_imports.unpack(tr["blocks_raw"].get("IMPS", b""))
    for im in old["imports"]:
        for k in fgx_imports.SITES:
            for site in im[k]:
                res.use(im["kind"], im["name"], k, *site)
    csit = []
    for seg, (x, y) in enumerate(zip(sa, sb)):
        found = fgx_sites.attribute(fgx_sites.diff_sites(x, y), objects,
                                    "%s segment %d" % (name, seg))
        for obj, offs in found.items():
            for off, v in offs:
                if obj == "core":
                    csit.append((seg, off))
                else:
                    res.use(1, obj, "data", seg, off, v)
    extra = b""
    if res.order:
        extra += fgx_ld.block(b"IMPS", res.pack())
    extra += fgx_ld.block(b"CSIT", b"".join(struct.pack("<BH", s, o) for s, o in csit))
    t = fgx_ld.library_trailer((tr["major"], tr["minor"]), tr["core"],
                               tr["templates"], tr["core_base"], tr["core_size"],
                               tr["exports"], tr["blocks"], tr["fixups"], extra)
    with open(out, "wb") as f:
        f.write(a[:end] + t)
    n_data = sum(len(im["data"]) for im in res.table()["imports"])
    return len(res.order), n_data, len(csit)


def build(name, out, d, core_pad=0):
    """Link the library to `out'.  It is written whole or not at all: the
    link goes to a temporary file that is renamed only once its sites are
    added, so a refusal in the site pass leaves nothing make would call up
    to date."""
    tmp = out + ".tmp"
    try:
        info = link_lib(name, tmp, d, core_pad=core_pad)
        if info["need"] > 0x10000:
            # The guess was short (FIXS, or a renamed export): pack again
            # with the tail the link measured.
            info = link_lib(name, tmp, d, core_pad=core_pad,
                            tagged=info["tagged_exact"])
        if info["need"] > 0x10000:
            die("%s: its last bank once loaded is %d bytes" % (name, info["need"]))
        msg = ""
        if info["libs"]:
            sd = os.path.join(d, "shift")
            scratch = os.path.join(d, "scratch.so")
            info2 = link_lib(name, scratch, sd, fgx_sites_delta(), core_pad,
                             info["tagged"])
            if info2["banks"] != info["banks"]:
                die("the site link packed differently; its banks cannot be diffed")
            n_imp, n_data, n_core = add_sites(name, tmp, scratch, info)
            if n_core == 0:
                die("%s: the site link found no core site; every block-table "
                    "row names its cell, so the shift did not reach the core"
                    % name)
            msg = ", %d imports (%d data sites), %d core sites" % (n_imp, n_data, n_core)
        os.replace(tmp, out)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)
    print("%s.so: %d code banks (%s bytes), core %d bytes at $%04X, "
          "templates %d bytes%s" % (name, len(info["banks"]), ", ".join(
              str(CAP - f) for f in info["free"]), info["size"], info["base"],
              info["tmpl"], msg))


def fgx_sites_delta():
    import fgx_sites
    return fgx_sites.DELTA


def self_test():
    units = {
        "f": ["                FGX_SECT f", "                FGX2_EXPORT f",
              "f   ENT", "    LDA #_libc_c_S1", "    RTL", "                FGX_ENDS"],
        "g": ["                FGX_SECT g", "                FGX2_EXPORT g",
              "g   ENT", "    LDA #_libc_c_S1", "    LDA #_libc_c_S2",
              "    FGX2_FARCALL f", "    RTL", "                FGX_ENDS"],
        "h": ["                FGX_SECT h", "                FGX2_EXPORT h",
              "h   ENT", "    RTL", "                FGX_ENDS"],
        "_libc_c_S1": ["                FGX_SECT _libc_c_S1",
                       "                FGX2_EXPORT _libc_c_S1",
                       "_libc_c_S1  HEX 41,00", "                FGX_ENDS"],
        "_libc_c_S2": ["                FGX_SECT _libc_c_S2",
                       "                FGX2_EXPORT _libc_c_S2",
                       "_libc_c_S2  HEX 42,00", "                FGX_ENDS"],
    }
    order = ["f", "g", "h", "_libc_c_S1", "_libc_c_S2"]
    refs = literal_refs(units, ["f", "g", "h"])
    assert refs == {"f": ["_libc_c_S1"], "g": ["_libc_c_S1", "_libc_c_S2"], "h": []}, refs
    sizes = {"f": 100, "g": 60, "h": 50}
    lsizes = {"_libc_c_S1": 10, "_libc_c_S2": 5}
    # f (110 with S1) fills bank 0 to 20 free; g (75 with both) goes to bank 1;
    # h (50) does not fit bank 0's 20 and takes bank 1's last 55.
    banks, held, free = pack(sizes, refs, lsizes, [130, 130])
    assert banks == [["f"], ["g", "h"]], banks
    assert held == [{"_libc_c_S1"}, {"_libc_c_S1", "_libc_c_S2"}], held
    assert free == [20, 5], free
    assert pack(sizes, refs, lsizes, [100, 100]) is None      # f + S1 fits nowhere
    assert pack_min(sizes, refs, lsizes, 130, 130, 4)[0] == banks
    # The last bank also carries the core, the templates and the tagged
    # blocks (`tail'): 60 of its 130 gone, g and h no longer fit two banks.
    got = pack_min(sizes, refs, lsizes, 130, 130, 4, tail=60)
    assert len(got[0]) == 3 and got[2][-1] >= 0, got
    # A literal only data points at needs room too: f fills its bank, so
    # the orphan takes a second one rather than failing after the pack.
    got = pack_min({"f": 100}, {"f": []}, {"_libc_c_S1": 10}, 100, 100, 3,
                   orphans={"_libc_c_S1"})
    assert got[0] == [["f"], []] and got[1] == [set(), {"_libc_c_S1"}], got
    canon = canonical(held)
    assert canon == {"_libc_c_S1": 0, "_libc_c_S2": 1}, canon
    rows1 = bank_rows(units, order, banks[1], held[1], canon, 1)
    text1 = "\n".join(rows1)
    assert "FGX2_EXPORT _libc_c_S2" in text1
    assert "FGX2_EXPORT _libc_c_S1" not in text1 and "_libc_c_S1  HEX" in text1
    assert rows1[-1].split() == ["FGX2_RELOC_COUNT", str(fgx_gc.fgx2_rows(rows1[:-1]))]
    rows0 = bank_rows(units, order, banks[0], held[0], canon, 0)
    assert "FGX2_EXPORT _libc_c_S1" in "\n".join(rows0)
    held2, free2 = [set(), set()], [3, 20]
    place_orphans({"_libc_c_S2", "_libc_c_S1"}, held2, free2, lsizes)
    assert held2 == [set(), {"_libc_c_S1", "_libc_c_S2"}] and free2 == [3, 5]
    lines = ["                FGX2_MODE 2", "                MX      %00"] + \
        units["f"] + units["_libc_c_S1"] + ["]__lc_fltused   =       1"]
    u, o = split_code(lines, "t.s")
    assert o == ["f", "_libc_c_S1"] and u["f"] == units["f"], o
    try:
        split_code(["x  EQU 1"], "t.s")
    except SystemExit:
        pass
    else:
        raise AssertionError("an unsectioned definition must be refused")
    lst = os.path.join(tempfile.mkdtemp(prefix="libso_st_"), "m_Output.txt")
    row = ("  %d |  2   c.s   %d | Macro       | 00 |         |    0 "
           "| 0B/%04X               |          %s\n")
    with open(lst, "w") as f:
        f.write(row % (1, 2, 0x0120, "FGX_SECT          f"))
        f.write(row % (2, 9, 0x0188, "FGX_ENDS"))
        f.write(row % (3, 10, 0x0188, "FGX_SECT          g"))
        f.write(row % (4, 14, 0x01F0, "FGX_ENDS"))
        f.write(row.replace("c.s", "x.s") % (5, 2, 0x0300, "FGX_SECT          h"))
    assert section_sizes(lst, "c.s") == {"f": 0x68, "g": 0x68}
    d = tempfile.mkdtemp(prefix="libso_clr_")
    for n in ("bank0.s", "bank5_Output.txt", "core.link.s", "libc_so.json",
              "_FileInformation.txt", "m3"):
        open(os.path.join(d, n), "w").close()
    clear_outputs(d)
    assert os.listdir(d) == [], os.listdir(d)
    open(os.path.join(d, "libc_c.c"), "w").close()
    try:
        clear_outputs(d)
    except SystemExit:
        pass
    else:
        raise AssertionError("a --dir holding a file the driver does not write must be refused")
    assert os.listdir(d) == ["libc_c.c"]
    rows = blktab(["b", "a"], {"a": 4, "b": 6})
    assert rows == ["_libc_blktab    ANOP",
                    "                DA      _libc_blk_a",
                    "                FGX2_LONG_PTR _bt;a__BT;0",
                    "                DA      4",
                    "                DA      _libc_blk_b",
                    "                FGX2_LONG_PTR _bt;b__BT;0",
                    "                DA      6",
                    "                DA      0"], rows
    assert blktab([], {}) == ["_libc_blktab    ANOP", "                DA      0"]
    rt = ["; head comment", "_FCC_X          EQU     3",
          "_fcc_a          MX      %00", "                JSR     _fcc_b",
          "                RTS",
          "_fcc_b          MX      %00", "                LDA     #_FCC_X",
          "                JSR     _fcc_c", "                RTS",
          "_fcc_c          MX      %00", "                PHA",
          "_fcc_d          MX      %00", "                PLA", "                RTS"]
    head, ru, ro = runtime_units(rt)
    assert ro == ["_fcc_a", "_fcc_b", "_fcc_c"], ro
    assert "_FCC_X          EQU     3" in head
    assert ru["_fcc_c"][0].split() == ["FGX_SECT", "_fcc_c"]
    assert any(r.startswith("_fcc_d") for r in ru["_fcc_c"])   # c falls into d
    own = shared_owner(ru, ro)
    assert own["_fcc_d"] == "_fcc_c"
    fu = {"f": ["                FGX_SECT f", "f   ENT", "    JSR _fcc_a",
                "    JSR _fcc_d", "    RTL", "                FGX_ENDS"]}
    fu.update(ru)
    assert shared_refs(fu, ["f"], own) == {"f": ["_fcc_a", "_fcc_b", "_fcc_c"]}
    got = pack({"f": 10}, {"f": []}, {"_fcc_a": 5}, [20], pre={"_fcc_a"})
    assert got[1] == [{"_fcc_a"}] and got[2] == [5], got
    real = runtime_units(open(RUNTIME).read().split("\n"))
    assert "_fcc_fadd" not in real[1] and any(
        r.startswith("_fcc_fadd") for r in real[1]["_fcc_fsub"])
    assert not any(r.split()[:1] == ["_fcc_stkoflow"] for r in real[0])
    assert len(real[2]) == 69, len(real[2])
    rown = shared_owner(real[1], real[2])
    rdeps = shared_refs(real[1], real[2], rown)
    assert rdeps["_fcc_long_mods"] == ["_fcc_long_divs", "_fcc_long_udiv"], \
        rdeps["_fcc_long_mods"]
    # A failed site pass leaves no output behind: make would call a
    # CSIT-less library up to date.
    global link_lib, add_sites
    real = (link_lib, add_sites)
    d = tempfile.mkdtemp(prefix="libso_atomic_")
    out = os.path.join(d, "x.so.1.0")
    def fake_link(name, o, dd, shift=0, core_pad=0, tagged=None):
        os.makedirs(os.path.dirname(o), exist_ok=True)
        with open(o, "wb") as f:
            f.write(b"half")
        return {"libs": [1], "banks": [], "base": 0, "size": 0, "free": [],
                "tmpl": 0, "need": 0, "tagged": 0, "tagged_exact": 0}
    def fake_sites(*a):
        die("a site the finder refuses")
    link_lib, add_sites = fake_link, fake_sites
    try:
        build("libtermlib", out, os.path.join(d, "b"))
    except SystemExit:
        pass
    finally:
        link_lib, add_sites = real
    assert not os.path.exists(out), "a failed site pass left %s" % out
    # --print-data is a static link's segment-1 extern-defs list (gen.py's
    # gencommons edge); it must track DATA exactly, one path per line.
    import io
    out_s, old_argv, old_stdout = io.StringIO(), sys.argv, sys.stdout
    sys.argv, sys.stdout = ["fgx_libso.py", "--print-data"], out_s
    try:
        main()
    finally:
        sys.argv, sys.stdout = old_argv, old_stdout
    assert out_s.getvalue().splitlines() == DATA, out_s.getvalue()
    print("fgx_libso: self-test OK")


def main():
    if "--self-test" in sys.argv:
        self_test()
        return 0
    a = sys.argv[1:]
    if a == ["--print-data"]:
        for p in DATA:
            print(p)
        return 0
    name, pad = "libc", 0
    if a[:1] == ["--lib"]:
        name, a = a[1], a[2:]
    if a[:1] == ["--core-pad"]:
        pad, a = int(a[1]), a[2:]
    if len(a) != 4 or a[0] != "--out" or a[2] != "--dir" or name not in LIBS:
        die("usage: fgx_libso.py [--lib NAME] [--core-pad N] --out FILE --dir DIR"
            " | --print-data | --self-test")
    build(name, os.path.abspath(a[1]), os.path.abspath(a[3]), pad)
    return 0

if __name__ == "__main__":
    sys.exit(main())
