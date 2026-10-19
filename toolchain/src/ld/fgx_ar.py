#!/usr/bin/env python3
"""
fgx_ar.py - FGX archive tool: symbol index (ranlib analogue) + member
extraction (the ld archive-walk).

The OS build does not use it: programs link libc and the optional libraries
through fgx_dyn (the shared libraries) or fgx_static (build/static_libs).  The
tool, with tools/mk_fgxa.sh and tools/mk_fgxa_carve.py, is kept for static
archive links; tests/ld/test_asm_archive.py, tests/ld/test_c_archive.py and
src/ld/test_fgx_ar.py exercise it on archives they build themselves.  The
design notes below describe the archive model it implements.

Multi-archive linking, member level (multi-archive-linker P2, 2026-07-19).
The shared libc/libfgx bank stays a SHARED OBJECT (loaded once system-wide,
no member strip — that is the .so lineage and is left untouched).  The
OPTIONAL, per-tool library tier (termcap, curses, later libm/libutil) —
today PUT whole-pile into a per-tool seg3 CODE segment — becomes real
`.a`-style archives with member-level dead-strip: a tool that calls three
curses functions pulls only the members those functions transitively need,
not the whole library.  This is the classic BSD static-`ld` discipline, and
because the optional tier is per-tool (never shared) it costs no sharing.

An archive is described by `<lib>.fgxa/index.json`:

    {
      "lib": "curses",
      "members": [
        { "id": "addch",                       # stable member id (== source stem)
          "s":      "lib/libcurses_c/addch.s",       # code fragment (repo-relative)
          "data_s": "lib/libcurses_c/addch.data.s",  # data fragment (optional)
          "exports": ["waddch", "addch"],      # FGX2_EXPORT / LIBC_EXPORT names
          "imports": ["wclrtoeol", "_curbuf"]  # cross-TU refs (FARCALL/LONG_PTR/…)
        }, ...
      ]
    }

`index` builds that from member .s fragments (scan exports + imports, minus
each member's own exports).  `extract` runs the archive walk: seed the
undefined set from the tool's cross-TU references not already provided by
root+libc+libfgx, then fixpoint-pull members that define an undefined symbol
until the set is closed.  Returns the selected members in stable archive
order (so the assembled seg3 is byte-reproducible) plus any still-unresolved
symbols (a hard link error, named by the caller).

Member ORDER within the selection does not matter for correctness: the
selected members are co-assembled into one seg3 TU, and Merlin resolves the
intra-tier near JSRs regardless of definition order.  Order is fixed only
for reproducibility.
"""

import argparse
import json
import os
import re
import sys


def die(msg):
    sys.stderr.write(f"fgx_ar: {msg}\n")
    sys.exit(2)


# Macros a member .s uses to DEFINE a symbol (0 bytes; records an export).
EXPORT_MACROS = {"FGX2_EXPORT", "LIBC_EXPORT"}
# Macros a member .s uses to REFERENCE another TU's symbol, and the 0-based
# index of the symbol name within the ';'-separated macro args.  Same set
# fgx_ld resolves globally; a same-TU (intra-member) call is a plain near
# JSR and never appears here, so imports are exactly the cross-TU edges.
IMPORT_MACROS = {
    "FGX2_FARCALL":    0,   # cross-bank user call: FGX2_FARCALL <name>
    "FGX2_LONG_PTR":   1,   # far data pointer:     FGX2_LONG_PTR <tag>;<name>;<seg>
    "FGX2_ABS_OFFSET": 1,   # abs offset ref:       FGX2_ABS_OFFSET <tag>;<name>;<seg>
    "FGX2_IMPORT_JSL": 1,   # explicit-seg import:  FGX2_IMPORT_JSL <tag>;<name>;<seg>
}
ALL_MACROS = EXPORT_MACROS | set(IMPORT_MACROS)


def _parse_macro_line(line):
    """Return (macro_name, args) if `line` invokes an FGX2 export/import
    macro, else None.  Merlin macro args carry no interior spaces, so the
    args are the single whitespace token after the macro name; a trailing
    `; comment` is space-separated and splits away.  The macro is token 0,
    or token 1 when a column-1 label precedes it."""
    s = line.rstrip("\n")
    stripped = s.lstrip()
    if not stripped or stripped[0] in ("*", ";"):
        return None
    toks = s.split()
    if toks[0] in ALL_MACROS:
        mi = 0
    elif len(toks) > 1 and toks[1] in ALL_MACROS:
        mi = 1
    else:
        return None
    macro = toks[mi]
    arg_field = toks[mi + 1] if len(toks) > mi + 1 else ""
    args = arg_field.split(";") if arg_field else []
    return macro, args


def scan_member(path):
    """Scan a member .s for its FGX2-macro exports and cross-TU imports.
    Imports exclude the member's own exports.  (Used directly for the
    simple single-macro case + the unit tests; cmd_index layers the data
    universe on top — see below.)"""
    exports, imports = [], []
    try:
        with open(path) as f:
            lines = f.readlines()
    except OSError as e:
        die(f"cannot read member '{path}': {e}")
    for line in lines:
        parsed = _parse_macro_line(line)
        if parsed is None:
            continue
        macro, args = parsed
        if macro in EXPORT_MACROS:
            if not args or not args[0]:
                die(f"{path}: {macro} with no symbol name")
            exports.append(args[0])
        else:
            idx = IMPORT_MACROS[macro]
            if idx >= len(args) or not args[idx]:
                die(f"{path}: {macro} missing symbol arg (args={args})")
            imports.append(args[idx])
    exp = sorted(set(exports))
    imp = sorted(set(imports) - set(exp))
    return exp, imp


# A column-1 label that DEFINES a datum in a member's .data.s.  fcc emits the
# library's file-scope globals as `<name> <directive>`: a Merlin data directive
# (`ttytype DS 50`, `stdscr DA $0000`, `_echoit DFB $01`), an EQU, or — for a
# pointer/array global whose first element is a far pointer — an FGX2/LIBC
# macro (`_unctrl FGX2_LONG_PTR _Sa;_unctrl_S0;0`).  Array-continuation lines
# carry no column-1 label (leading whitespace), so they are correctly skipped.
DATA_DIRECTIVE_RE = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)\s+"
    r"(DFB|DB|DDB|DA|DW|DS|HEX|ASC|DCI|STR|REV|FLS|INV|EQU|=|"
    r"FGX2_[A-Z_]+|LIBC_[A-Z_]+)\b")
# Any assembler identifier (to tokenise operands for cross-member ref scan).
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def scan_defs(s_path, data_path):
    """A member's DEFINITIONS: code exports (FGX2_EXPORT in .s) + data
    labels (column-1 `<name> <directive>` in its .data.s).  The data set
    includes member-private statics/string-pool labels; cmd_index keeps
    only those actually referenced across members (or header-public)."""
    code_exports, _ = scan_member(s_path)
    data_defs = []
    if data_path and os.path.exists(data_path):
        with open(data_path) as f:
            for line in f:
                m = DATA_DIRECTIVE_RE.match(line)
                if m:
                    data_defs.append(m.group(1))
    return set(code_exports), set(data_defs)


def scan_refs(paths):
    """Every assembler identifier appearing in the given source files —
    the candidate set of symbols this member references.  Filtered against
    the library symbol universe by the caller (so opcodes/directives, which
    are never library symbols, drop out)."""
    toks = set()
    for p in paths:
        if not p or not os.path.exists(p):
            continue
        with open(p) as f:
            for line in f:
                # Drop Merlin comments so a symbol named in a comment is not
                # counted as a reference.
                code = line.split(";", 1)[0]
                toks.update(IDENT_RE.findall(code))
    return toks


def index_members(member_dicts):
    """Assign each member a stable identity key (archive order) and build the
    export symbol -> member map.  Duplicate exports across the set are a fatal
    ambiguity — same rule as fgx_ld's duplicate-strong-symbol error.  Pure
    (no I/O), so both load_archives and tests use it."""
    members = []
    sym2mem = {}
    for m in member_dicts:
        m = dict(m)
        m["_key"] = len(members)              # stable tiebreak / identity
        members.append(m)
        for e in m.get("exports", []):
            prev = sym2mem.get(e)
            if prev is not None:
                die(f"symbol '{e}' exported by two members "
                    f"('{prev.get('id')}' and '{m.get('id')}')")
            sym2mem[e] = m
    return members, sym2mem


def load_archives(index_paths):
    """Load one or more index.json files (archive order preserved,
    concatenated in argument order) into (members, sym2mem)."""
    member_dicts = []
    for ip in index_paths:
        try:
            with open(ip) as f:
                idx = json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            die(f"cannot read archive index '{ip}': {e}")
        member_dicts.extend(idx.get("members", []))
    return index_members(member_dicts)


def extract(members, sym2mem, provided, seed_undef):
    """The ld archive walk over the optional-library tier.

    provided   : symbols already satisfied by root+libc+libfgx (never pulled).
    seed_undef : every cross-TU symbol the tool + its TUs reference.

    Fixpoint: while some undefined symbol is exported by an un-pulled member,
    pull that member, mark its exports provided, add its still-undefined
    imports.  Returns (selected_members, unresolved) — selected in stable
    archive order (byte-reproducible seg3), unresolved = symbols no member
    or provider defines (the caller turns these into a named link error)."""
    provided = set(provided)
    undef = set(seed_undef) - provided
    pulled_keys = set()
    changed = True
    while changed:
        changed = False
        for sym in sorted(undef):
            m = sym2mem.get(sym)
            if m is None:
                continue                       # not in any archive; stays unresolved
            if m["_key"] in pulled_keys:
                undef.discard(sym)             # already pulled; symbol satisfied
                continue
            pulled_keys.add(m["_key"])
            for e in m.get("exports", []):
                provided.add(e)
                undef.discard(e)
            for imp in m.get("imports", []):
                if imp not in provided:
                    undef.add(imp)
            changed = True
    selected = [m for m in members if m["_key"] in pulled_keys]
    unresolved = {s for s in undef if s not in provided}
    return selected, unresolved


# --------------------------------------------------------------------------- CLI

def _read_symlist(path):
    """One symbol per line; '#' comments and blanks ignored."""
    out = []
    with open(path) as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if line:
                out.append(line)
    return out


def cmd_index(a):
    """Build <lib>.fgxa/index.json from member .s fragments, in two passes.

    Pass 1 — DEFS: each member's code exports (FGX2_EXPORT) + data-label
    defs (its .data.s globals + private statics).  Build the library symbol
    universe (symbol -> owning member); a symbol defined by two members is a
    fatal collision.
    Pass 2 — REFS: each member's imports = the universe symbols it references
    (code AND bare-data) that another member owns.  A member's stored exports
    = its code exports + the data globals some OTHER member references (or a
    --public symbol); private string-pool statics referenced by no one are
    dropped, keeping the index to real cross-member edges."""
    stems, defs, sowner, downer = [], {}, {}, {}
    public = set(_read_symlist(a.public)) if a.public else set()
    for s_path in a.members:
        if not s_path.endswith(".s"):
            die(f"member '{s_path}' is not a .s fragment")
        stem = os.path.splitext(os.path.basename(s_path))[0]
        data_s = s_path[:-2] + ".data.s"
        code_exp, data_def = scan_defs(s_path, data_s)
        stems.append((stem, s_path, data_s, code_exp, data_def))
        for e in code_exp:
            if e in sowner:
                die(f"duplicate code export '{e}' in '{sowner[e]}' and "
                    f"'{stem}' — archive symbols must be unique")
            sowner[e] = stem
        for d in data_def:
            # A data label may legitimately repeat only if it is a private
            # static; but fcc --pile makes labels globally unique, so a clash
            # is a real ambiguity.
            if d in downer and downer[d] != stem:
                die(f"duplicate data label '{d}' in '{downer[d]}' and "
                    f"'{stem}'")
            downer[d] = stem
    # fcc's STRING POOL IS NOT A LINKAGE EDGE.  --pile dedupes literals across
    # the whole aggregate and parks each one in whichever member happened to use
    # it first, so a two-byte constant creates a member dependency: `"r"` lives
    # in fstab.c as _libc_c_S11 and grent, pwent, rlimit and ttyent all
    # "import" it, dragging fstab's 3,417 bytes into fifteen binaries that never
    # call a fstab function.
    #
    # The edge is an artifact of the CARVE, not of the code.  `select` compiles
    # the FILTERED aggregate as one fresh TU, so fcc re-emits every literal the
    # surviving sources need, from those sources.  Excluding the pool from the
    # universe therefore removes a false dependency without removing a real one.
    #
    # The pool's names are `_<aggregate>_S<n>` and they are always HEX byte
    # strings; a genuinely public symbol is listed in public.syms and is kept
    # regardless.
    pool = {d for d in downer
            if re.match(r"^_[A-Za-z0-9_]+_S\d+$", d) and d not in public}
    universe = (set(sowner) | set(downer)) - pool
    owner = {**downer, **sowner}          # code export wins a name clash w/ data

    # Pass 2: references.
    referenced = set()                    # data symbols referenced cross-member
    imports_by_stem = {}
    for stem, s_path, data_s, code_exp, data_def in stems:
        own = code_exp | data_def
        refs = scan_refs([s_path, data_s]) & universe
        imp = {r for r in refs if owner.get(r) != stem}
        imports_by_stem[stem] = sorted(imp)
        referenced |= imp

    members = []
    for stem, s_path, data_s, code_exp, data_def in stems:
        # Exports: all code exports (a tool calls these), plus the data
        # globals that are cross-referenced or explicitly public.  Private
        # statics (referenced by nobody, not public) are omitted.
        data_exp = {d for d in data_def if d in referenced or d in public}
        exports = sorted(code_exp | data_exp)
        rec = {"id": stem, "s": s_path, "exports": exports,
               "imports": imports_by_stem[stem]}
        if os.path.exists(data_s):
            rec["data_s"] = data_s
        members.append(rec)

    os.makedirs(a.out, exist_ok=True)
    idx = {"lib": a.lib, "members": members}
    # For the concatenation build model (cmd_select): the archive records the
    # aggregate .c (the `#include "member.c"` umbrella) and the compile command,
    # so a tool builds its dead-stripped subset as ONE aggregated TU — same
    # near-ref codegen as the whole-library aggregate, just fewer members.
    # Standalone per-member objects re-expose the cross-TU far-pointer hazard
    # the aggregation exists to avoid (curses initscr NULL, 2026-07-19).
    if a.aggregate:
        idx["aggregate"] = a.aggregate
    if a.cc:
        idx["cc"] = a.cc
    # AN ASSEMBLY ARCHIVE has no umbrella and no compiler: its members are
    # hand-written .s, and `select' concatenates the chosen ones as they are.
    if a.asm:
        if a.aggregate or a.cc:
            die("an --asm archive takes no --aggregate/--cc: its members are "
                "assembled as written")
        idx["asm"] = True
    with open(os.path.join(a.out, "index.json"), "w") as f:
        json.dump(idx, f, indent=2, sort_keys=False)
        f.write("\n")
    if a.verbose:
        n_sym = sum(len(m["exports"]) for m in members)
        print(f"fgx_ar: {a.lib}.fgxa: {len(members)} members, {n_sym} exports")


def cmd_extract(a):
    """Run the archive walk for a tool and print the selected member .s
    (one per line) for the build to PUT, or die naming unresolved symbols.

    The seed is computed here: the tool's own .s files (root code + its TUs)
    are tokenised and intersected with the archives' symbol universe — i.e.
    exactly the symbols the tool reaches into the optional-library tier.
    libc/libfgx symbols are not in the universe, so they are correctly
    ignored (satisfied by the shared bank, not this walk)."""
    members, sym2mem = load_archives(a.index)
    universe = set(sym2mem)
    # Resolve each member's imports against the COMBINED universe of ALL loaded
    # archives (not the per-archive `imports` baked into each index.json, which
    # only captured intra-archive edges) — this is what makes a cross-archive
    # dep like curses' cr_tty -> termlib's tgetent pull the termlib member.
    # ld does the same: it re-examines every pulled object against the whole
    # library list.
    for m in members:
        files = [m.get("s"), m.get("data_s")]
        own = set(m.get("exports", []))
        m["imports"] = sorted((scan_refs([f for f in files if f]) & universe) - own)
    seed = sorted(scan_refs(a.root) & universe)
    selected, unresolved = extract(members, sym2mem, provided=set(), seed_undef=seed)
    if unresolved:
        die(f"unresolved symbol(s) for {a.tool or 'tool'} in archives "
            f"{a.index}: {sorted(unresolved)}")
    for m in selected:
        print(m["s"])
    if a.verbose:
        sys.stderr.write(
            f"fgx_ar: {a.tool or 'tool'}: seed {len(seed)} sym -> pulled "
            f"{len(selected)}/{len(members)} members: "
            f"{[m['id'] for m in selected]}\n")


INCLUDE_MEMBER_RE = re.compile(r'#\s*include\s+"([A-Za-z0-9_]+)\.c"')


ASM_MARK = "ASM"


def select_asm(arc, sel, outdir):
    """An assembly archive's selection: the chosen members' code fragments,
    concatenated in ARCHIVE order (so the result is byte-reproducible), as
    <lib>.sel.s, and their data fragments as <lib>.sel.data.s -- the two files
    a C archive's selection compiles to, so seg3 PUTs either kind the same way.
    Prints `<lib>.sel.s\tASM`, which tells the caller there is nothing to
    compile."""
    order = {m["id"]: i for i, m in enumerate(arc["members"])}
    chosen = sorted(sel, key=lambda m: order[m["id"]])
    code, data = [], []
    for m in chosen:
        for key, dst in (("s", code), ("data_s", data)):
            path = m.get(key)
            if not path:
                continue
            try:
                with open(path) as f:
                    text = f.read()
            except OSError as e:
                die(f"cannot read member '{path}': {e}")
            dst.append(f"; ---- {arc['lib']} member {m['id']} ({path})\n")
            dst.append(text if text.endswith("\n") else text + "\n")
    out_s = os.path.join(outdir, f"{arc['lib']}.sel.s")
    with open(out_s, "w") as f:
        f.writelines(code)
    with open(os.path.join(outdir, f"{arc['lib']}.sel.data.s"), "w") as f:
        f.writelines(data)
    print(f"{out_s}\t{ASM_MARK}")


def cmd_select(a):
    """The concatenation build model: run the archive walk, then for each
    archive emit a filtered aggregate .c — the library's umbrella source with
    the `#include "member.c"` lines of UNSELECTED members removed — so the tool
    compiles its dead-stripped subset as ONE aggregated TU (same near-ref
    codegen as the whole-library aggregate, which is proven; standalone
    per-member objects re-expose the cross-TU far-pointer hazard).  Prints one
    `<sel.c>\\t<cc>` line per archive for the build to compile into seg3."""
    archives, all_members = [], []
    for ip in a.index:
        try:
            with open(ip) as f:
                idx = json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            die(f"cannot read archive index '{ip}': {e}")
        arc = {"lib": idx.get("lib"), "aggregate": idx.get("aggregate"),
               "cc": idx.get("cc"), "asm": bool(idx.get("asm")),
               "members": idx.get("members", [])}
        arc["key_lo"] = len(all_members)
        all_members.extend(arc["members"])
        arc["key_hi"] = len(all_members)
        archives.append(arc)
    members, sym2mem = index_members(all_members)
    universe = set(sym2mem)
    for m in members:
        files = [m.get("s"), m.get("data_s")]
        own = set(m.get("exports", []))
        m["imports"] = sorted((scan_refs([f for f in files if f]) & universe) - own)
    seed = sorted(scan_refs(a.root) & universe)
    selected, unresolved = extract(members, sym2mem, provided=set(), seed_undef=seed)
    if unresolved:
        die(f"unresolved symbol(s) for {a.tool or 'tool'} in archives "
            f"{a.index}: {sorted(unresolved)}")
    os.makedirs(a.outdir, exist_ok=True)
    for arc in archives:
        sel = [m for m in selected if arc["key_lo"] <= m["_key"] < arc["key_hi"]]
        # Every archive's selection is written even when empty: the link PUTs
        # it whether or not anything was chosen, and must not read a previous
        # build's.  An empty C selection is the umbrella with no members.
        if arc["asm"]:
            select_asm(arc, sel, a.outdir)
            if a.verbose:
                sys.stderr.write(f"fgx_ar: {arc['lib']}: {len(sel)}/"
                                 f"{len(arc['members'])} members selected\n")
            continue
        if not arc["aggregate"] or not arc["cc"]:
            die(f"archive '{arc['lib']}' index lacks aggregate/cc "
                f"(rebuild it with mk_fgxa.sh or mk_fgxa_carve.py)")
        sel_stems = {m["id"] for m in sel}
        try:
            with open(arc["aggregate"]) as f:
                lines = f.readlines()
        except OSError as e:
            die(f"cannot read aggregate '{arc['aggregate']}': {e}")
        # FGX_AR_HAVE_<member> for each member selected, so the aggregate can
        # ask at compile time what the walk chose.  printf.c prints %e/%f/%g
        # only when fltpr is here -- 2.11BSD's fltpr.s/ffltpr.s choice, which
        # its linker made by whether anything referenced `fltused'.
        kept = [f"#define FGX_AR_HAVE_{st} 1\n" for st in sorted(sel_stems)]
        # A kept member is included by its path beside the aggregate.  The
        # filtered copy is written into the TOOL's directory, and K&R 2nd ed
        # A.12.4 has a quoted #include search "first in association with the
        # original source file" -- that directory -- before any -I, so a
        # fixture tests/M28/scanf.c stood in for the member scanf.c.
        agg_dir = os.path.abspath(os.path.dirname(arc["aggregate"]))
        for ln in lines:
            mm = INCLUDE_MEMBER_RE.search(ln)
            if mm and mm.group(1) not in sel_stems:
                continue                       # drop an unselected member
            if mm:
                ln = (ln[:mm.start()] + '#include "'
                      + os.path.join(agg_dir, mm.group(1) + ".c") + '"'
                      + ln[mm.end():])
            kept.append(ln)
        out_c = os.path.join(a.outdir, f"{arc['lib']}.sel.c")
        with open(out_c, "w") as f:
            f.writelines(kept)
        print(f"{out_c}\t{arc['cc']}")
        if a.verbose:
            sys.stderr.write(f"fgx_ar: {arc['lib']}: {len(sel)}/"
                             f"{len(arc['members'])} members selected\n")


def main():
    ap = argparse.ArgumentParser(description="FGX archive tool (index + extract)")
    ap.add_argument("-v", "--verbose", action="store_true")
    sub = ap.add_subparsers(dest="cmd", required=True)

    pi = sub.add_parser("index", help="build <lib>.fgxa/index.json")
    pi.add_argument("--lib", required=True, help="library name (e.g. curses)")
    pi.add_argument("--out", required=True, help="output <lib>.fgxa directory")
    pi.add_argument("--public",
                    help="file of symbol names to always export (e.g. the "
                         "library's header externs), for globals no member "
                         "references but a tool might")
    pi.add_argument("--aggregate",
                    help="the library umbrella .c (its #include \"member.c\" "
                         "lines) — recorded so `select` can build a filtered "
                         "subset aggregate")
    pi.add_argument("--cc", help="the fcc compile command for the aggregate")
    pi.add_argument("--asm", action="store_true",
                    help="members are hand-written assembly: `select` "
                         "concatenates the chosen .s/.data.s fragments instead "
                         "of filtering and recompiling a C umbrella")
    pi.add_argument("members", nargs="+", help="member .s fragments")
    pi.set_defaults(func=cmd_index)

    ps = sub.add_parser("select",
                        help="archive walk -> filtered aggregate .c per archive")
    ps.add_argument("--index", action="append", required=True,
                    help="archive index.json (repeat, in link order)")
    ps.add_argument("--root", action="append", required=True,
                    help="the tool's own .s file(s) (root code + TUs)")
    ps.add_argument("--outdir", required=True, help="where to write <lib>.sel.c")
    ps.add_argument("--tool", help="tool name, for the error message")
    ps.set_defaults(func=cmd_select)

    pe = sub.add_parser("extract", help="archive walk -> selected member .s")
    pe.add_argument("--index", action="append", required=True,
                    help="archive index.json (repeat, in link order)")
    pe.add_argument("--root", action="append", required=True,
                    help="the tool's own .s file(s) (root code + TUs); "
                         "seed = their refs into the archive tier")
    pe.add_argument("--tool", help="tool name, for the error message")
    pe.set_defaults(func=cmd_extract)

    a = ap.parse_args()
    a.func(a)


if __name__ == "__main__":
    main()
