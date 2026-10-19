#!/usr/bin/env python3
"""
fgx_gc.py - drop the library functions and data items a tool cannot reach
(apple/fgx#457).  The linker's garbage collection, over Merlin source.

A library compiled with `fcc --sections` carries each function and each
data item as a SECTION:

                FGX_SECT <label>
                ...the unit's rows...
                FGX_ENDS

graph() takes a set of files, as {path: [lines]}, treats the ones named in
`prune' as sectioned, and reach() returns the sections reachable from the
rest (fgx_static and fgx_dyn are the callers):

  - a section DEFINES every column-1 label inside it (a function's local
    labels and equates included);
  - a section REFERENCES every identifier token in its rows, comments
    excepted.  Merlin source spells every symbol reference as its label --
    PEA target-1, JSR, JSL, DA, ADRL, the FGX2_* macros' ;-separated
    arguments, __asm bodies -- so the tokens of a compiler-delimited unit are
    its relocation list.  A comment is a row starting `;' or `*', or the rest
    of a row from a `;' that follows white space; a macro's arguments hold no
    white space, so their `;'s are not comments.  Comments are prose: the
    hand-written runtime's "free per the dpmap layout" named free(3), and
    reading comments kept 32 of su's sections alive;
  - the ROOTS are the tokens of everything that is not in a section: the
    tool's own code and data, the hand-written runtime and library files,
    and the unsectioned rows of the pruned files.

Taking a function's address always leaves its label in some live row, code or
data, so a function reached only through a pointer is kept: its table is a
live data section.

Usage:
  fgx_gc.py --self-test
"""

import os
import re
import sys

IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
COMMENT = re.compile(r"\s;.*")


def code_of(lines):
    """The rows' text without their comments, for the reference scan."""
    out = []
    for ln in lines:
        s = ln.lstrip()
        if not s or s[0] in ";*":
            continue
        out.append(COMMENT.sub("", ln))
    return "\n".join(out)


def die(msg):
    sys.stderr.write("fgx_gc: %s\n" % msg)
    sys.exit(2)


def split_sections(lines, path):
    """[('loose', [lines]) | ('sect', label, [lines])] in file order; the
    FGX_SECT/FGX_ENDS rows stay with their section."""
    out, cur, loose = [], None, []
    for i, ln in enumerate(lines, 1):
        tok = ln.split()
        if tok[:1] == ["FGX_SECT"]:
            if cur is not None:
                die("%s:%d: FGX_SECT inside section %s" % (path, i, cur[1]))
            if loose:
                out.append(("loose", loose))
                loose = []
            if len(tok) < 2:
                die("%s:%d: FGX_SECT without a label" % (path, i))
            cur = ("sect", tok[1], [ln])
        elif tok[:1] == ["FGX_ENDS"]:
            if cur is None:
                die("%s:%d: FGX_ENDS with no section open" % (path, i))
            cur[2].append(ln)
            out.append(cur)
            cur = None
        elif cur is not None:
            cur[2].append(ln)
        else:
            loose.append(ln)
    if cur is not None:
        die("%s: section %s never closed" % (path, cur[1]))
    if loose:
        out.append(("loose", loose))
    return out


def defined_labels(lines):
    """Column-1 labels of a unit's rows."""
    labs = set()
    for ln in lines:
        if ln and ln[0] not in " \t;*":
            m = IDENT.match(ln.lstrip("]:"))
            if m:
                labs.add(m.group(0))
    return labs


def is_data_path(path):
    b = os.path.basename(path)
    return b.endswith(".data.s") or b.endswith("_data.s")


DS_ROW = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s+DS\s+(\d+)\s*$")
SECT_ROWS = ("FGX_SECT", "FGX_ENDS", "FGX2_EXPORT")
ROOT_LABEL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\b")


def is_common(rows):
    """(name, size) when a section is a K&R tentative definition -- fcc emits
    `char *UP;' as the one row `UP DS 4' -- else None.  K&R A.10.2 (p. 187):
    in the common extension "if a definition occurs somewhere in the
    program, then the tentative definitions become merely declarations"."""
    found = None
    for r in rows:
        t = COMMENT.sub("", r).rstrip()
        if not t.strip() or t.lstrip()[0] in ";*":
            continue
        if t[0] in " \t":
            if t.split()[0] in SECT_ROWS:
                continue
            return None
        m = DS_ROW.match(t)
        if not m or found:
            return None
        found = (m.group(1), int(m.group(2)))
    return found


def graph(files, order, prune):
    """(units, owner, body, is_data, root_texts) for the sectioned files.

    Data follows K&R A.10.2's common extension: a pruned data section that
    is a tentative definition (is_common) yields to a column-1 label of a
    root data file or to an initialised data section of the same name, and
    of several such sections the largest survives.  A section that yields
    stays in `units' (indices do not shift) but owns nothing, so it is
    never live.

    Code follows the archive search: 2.11BSD's ld takes a library member
    only for a name still undefined after the object files, so a pruned
    code section named by an exported name of a root code file
    (exported_names: its FGX2_EXPORT rows, fcc's N_EXT) yields to it in
    the same way, and the library's own references bind to the program's
    definition.  A local label or an EQU is not an external definition and
    shadows nothing."""
    units, owner, body, is_data = {}, {}, {}, {}
    roots, root_data, root_code = [], set(), set()
    for p in order:
        if p not in prune:
            roots.append(code_of(files[p]))
            if not is_data_path(p):
                root_code |= exported_names(files[p])
                continue
            for ln in files[p]:
                m = ROOT_LABEL.match(ln)
                if m:
                    root_data.add(m.group(1))
    cands, skip_code = {}, set()
    for p in order:
        if p not in prune:
            continue
        units[p] = split_sections(files[p], p)
        for idx, u in enumerate(units[p]):
            if u[0] == "loose":
                roots.append(code_of(u[1]))
                continue
            key = (p, idx)
            if u[1] in root_code and not is_data_path(p):
                skip_code.add(key)
            com = is_common(u[2]) if is_data_path(p) else None
            for lab in defined_labels(u[2]) | {u[1]}:
                cands.setdefault(lab, []).append((key, com and com[0] == lab and com))
    skip = set(skip_code)
    for lab, cs in cands.items():
        commons = [(k, c) for k, c in cs if c]
        solid = sorted({k for k, c in cs if not c})
        if len(solid) > 1:
            die("%s defined in two sections (%s, %s)"
                % (lab, solid[0][0], solid[1][0]))
        if lab in root_data and any(is_data_path(k[0]) for k in solid):
            die("%s defined in two places (a root data file, %s)"
                % (lab, solid[0][0]))
        if not commons:
            continue
        if lab in root_data or solid:
            skip |= {k for k, _c in commons}
        else:
            best = max(commons, key=lambda kc: kc[1][1])   # first on a tie
            skip |= {k for k, _c in commons if k != best[0]}
    for lab, cs in cands.items():
        for key, _c in cs:
            if key not in skip:
                owner[lab] = key
    for p in units:
        for idx, u in enumerate(units[p]):
            key = (p, idx)
            if u[0] == "sect" and key not in skip:
                body[key] = code_of(u[2])
                is_data[key] = is_data_path(p)
    return units, owner, body, is_data, roots


def reach(root_texts, owner, body, is_data, follow_data=True):
    """Section keys reachable from the roots."""
    live, todo = set(), []
    for text in root_texts:
        todo += [owner[t] for t in IDENT.findall(text) if t in owner]
    while todo:
        key = todo.pop()
        if key in live:
            continue
        live.add(key)
        if is_data[key] and not follow_data:
            continue
        todo += [owner[t] for t in IDENT.findall(body[key])
                 if t in owner and owner[t] not in live]
    return live


def collect(files, order, prune, follow_data=True):
    """Return (units_by_file, live section keys).  A section key is
    (path, index).  follow_data=False is the self-test's broken collector:
    it does not follow references OUT of data sections."""
    units, owner, body, is_data, roots = graph(files, order, prune)
    return units, reach(roots, owner, body, is_data, follow_data)


def exported_names(lines):
    """Names a file's FGX2_EXPORT / LIBC_EXPORT rows export."""
    out = set()
    for ln in code_of(lines).split("\n"):
        t = ln.split()
        if ln[:1] not in ("", " ", "\t"):
            t = t[1:]
        if len(t) > 1 and t[0] in ("FGX2_EXPORT", "LIBC_EXPORT"):
            out.add(t[1])
    return out


def operand_refs(rows):
    """Identifiers from a row's OPERAND field only -- fcc wraps every
    stack-guard check in Merlin32's DO/FIN, and a library's own export can
    be named DO, so the opcode/directive column must never count as a use."""
    out = set()
    for r in rows:
        if not r.strip():
            continue
        parts = r.split(None, 1) if r[:1].isspace() else r.split(None, 2)
        if len(parts) == (2 if r[:1].isspace() else 3):
            out.update(IDENT.findall(parts[-1]))
    return out


def fgx2_rows(lines):
    """The rows fgx_ld's RELOC_COUNT gate recognizes (_parse_macro_row):
    FGX2_*, LIBC_EXPORT and LIBC_DATA_PTR, as fcc counts them."""
    def counted(tok):
        return tok.startswith("FGX2_") or tok in ("LIBC_EXPORT", "LIBC_DATA_PTR")
    n = 0
    for ln in lines:
        t = ln.split()
        if not t or t[0][0] in ";*":
            continue
        if counted(t[0]) or (len(t) > 1 and ln[0] not in " \t" and counted(t[1])):
            n += 1
    return n


def expect_die(fn, words):
    """True if fn() exits through die() with every word in its message."""
    import io
    err, old = io.StringIO(), sys.stderr
    sys.stderr = err
    try:
        fn()
    except SystemExit:
        msg = err.getvalue()
        return all(w in msg for w in words)
    finally:
        sys.stderr = old
    return False


def rows_test():
    """fgx2_rows counts what fgx_ld's RELOC_COUNT gate recognizes."""
    assert fgx2_rows(["x               LIBC_DATA_PTR _Ga;BC",
                      "                LIBC_EXPORT puts",
                      "                FGX2_EXPORT y", "; FGX2_EXPORT z"]) == 3


def commons_test():
    """K&R A.10.2 common extension: a pruned tentative data definition
    yields.  Raises AssertionError on a failed case."""
    common = ["                FGX_SECT UP", "UP              DS      4",
              "                FGX_ENDS"]
    init = ["                FGX_SECT UP", "                FGX2_EXPORT UP",
            "UP              DA      0", "                DA      0",
            "                FGX_ENDS"]
    assert is_common(common) == ("UP", 4)
    assert is_common(init) is None
    assert is_common(["                FGX_SECT _t_priv",
                      "_t_priv         DS      2", "x DS 2",
                      "                FGX_ENDS"]) is None
    lib_code = ["                FGX_SECT tgoto", "tgoto   LDA UP",
                "                RTL", "                FGX_ENDS"]
    files = {"p.s": ["main    JSR tgoto"], "p.data.s": ["UP              DS      4"],
             "l.s": lib_code, "l.data.s": common}
    units, owner, body, is_data, roots = graph(
        files, ["p.s", "p.data.s", "l.s", "l.data.s"], {"l.s", "l.data.s"})
    assert "UP" not in owner                      # the root's definition wins
    # Two libraries' commons: the larger survives.
    big = ["                FGX_SECT PC", "PC              DS      2",
           "                FGX_ENDS"]
    small = ["                FGX_SECT PC", "PC              DS      1",
             "                FGX_ENDS"]
    units, owner, *_ = graph({"a.data.s": small, "b.data.s": big, "r.s": ["x LDA PC"]},
                             ["r.s", "a.data.s", "b.data.s"],
                             {"a.data.s", "b.data.s"})
    assert owner["PC"][0] == "b.data.s", owner["PC"]
    # A common yields to an initialised pruned definition.
    units, owner, *_ = graph({"a.data.s": init, "b.data.s": common, "r.s": ["x LDA UP"]},
                             ["r.s", "b.data.s", "a.data.s"],
                             {"a.data.s", "b.data.s"})
    assert owner["UP"][0] == "a.data.s", owner["UP"]
    # A root code file's exported name shadows a pruned code section of the
    # same name, as ld's archive search does: the section owns nothing and is
    # never live, and the library's own references bind to the program's
    # label.
    lib = ["                FGX_SECT strtok", "strtok  RTL", "                FGX_ENDS",
           "                FGX_SECT getpw", "getpw   JSL strtok", "        RTL",
           "                FGX_ENDS"]
    files = {"p.s": ["main    JSL getpw", "                FGX2_EXPORT strtok",
                     "strtok  ENT", "        RTL"], "l.s": lib}
    units, owner, body, is_data, roots = graph(files, ["p.s", "l.s"], {"l.s"})
    live = {units[p][i][1] for p, i in reach(roots, owner, body, is_data)}
    assert "strtok" not in owner and live == {"getpw"}, (owner, live)
    # control: with no definition in the program, the library's is live
    files["p.s"] = ["main    JSL getpw"]
    units, owner, body, is_data, roots = graph(files, ["p.s", "l.s"], {"l.s"})
    live = {units[p][i][1] for p, i in reach(roots, owner, body, is_data)}
    assert live == {"getpw", "strtok"}, live
    # Only an exported name is a definition ld would see: a local label or
    # an EQU named strtok (a frame size, a static's label) leaves the
    # library's strtok undefined-and-loaded.
    for local in (["strtok  EQU 12"], ["strtok  RTL"]):
        files["p.s"] = ["main    JSL getpw"] + local
        units, owner, body, is_data, roots = graph(files, ["p.s", "l.s"], {"l.s"})
        live = {units[p][i][1] for p, i in reach(roots, owner, body, is_data)}
        assert live == {"getpw", "strtok"}, (local, live)
    # ...and only a code section yields: a pruned datum named after a
    # program's function is a different symbol space, left to the data rules.
    dat = ["                FGX_SECT strtok", "strtok  DA 0", "                FGX_ENDS"]
    files = {"p.s": ["main    LDA strtok", "                FGX2_EXPORT strtok",
                     "strtok  ENT"], "l.data.s": dat}
    _u, owner, *_ = graph(files, ["p.s", "l.data.s"], {"l.data.s"})
    assert owner.get("strtok") == ("l.data.s", 0), owner
    # A Merlin variable in a root is not a definition.
    units, owner, *_ = graph({"r.data.s": ["]__lc_fltused   =       1"],
                              "r.s": ["x LDA __lc_fltused"],
                              "l.data.s": ["                FGX_SECT __lc_fltused",
                                           "__lc_fltused    DS      2",
                                           "                FGX_ENDS"]},
                             ["r.data.s", "r.s", "l.data.s"], {"l.data.s"})
    assert owner["__lc_fltused"][0] == "l.data.s"
    # Two initialised definitions, one in a root: still an error.
    assert expect_die(lambda: graph({"r.data.s": ["UP  DA 0", "  DA 0"],
                                     "a.data.s": init},
                                    ["r.data.s", "a.data.s"], {"a.data.s"}),
                      ["UP", "defined"])


def reach_test():
    """The collector keeps what the roots reach, through data: keep_fptr is
    named only by the data table tbl.  A collector that does not follow
    references out of data sections must lose it (the control)."""
    files = {
        "root.s": ["; drop_me and str_dead are named here only in comments",
                   "main            ENT             ; not drop_me either",
                   "                FGX2_FARCALL keep_direct", "                RTL"],
        "pile.s": ["                FGX_SECT keep_direct",
                   "                FGX2_EXPORT keep_direct",
                   "keep_direct     ENT", "                LDA     tbl",
                   "                LDA     str1", "                LDA     shared_static",
                   "                RTL", "                FGX_ENDS",
                   "                FGX_SECT keep_fptr",
                   "                FGX2_EXPORT keep_fptr",
                   "keep_fptr       ENT", "                RTL", "                FGX_ENDS",
                   "                FGX_SECT drop_me",
                   "                FGX2_EXPORT drop_me", "drop_me         ENT",
                   "                LDA     shared_static",
                   "                PEA     keep_fptr-1", "                RTL",
                   "                FGX_ENDS"],
        "pile.data.s": ["                FGX_SECT tbl", "tbl             DA      keep_fptr",
                        "                FGX_ENDS", "                FGX_SECT shared_static",
                        "shared_static   DS      2", "                FGX_ENDS",
                        "                FGX_SECT str1", "str1            ASC     'hello'",
                        "                FGX_ENDS", "                FGX_SECT str_dead",
                        "str_dead        ASC     'unused'", "                FGX_ENDS"]}
    order = ["root.s", "pile.s", "pile.data.s"]
    prune = {"pile.s", "pile.data.s"}

    def kept(follow_data):
        units, live = collect(files, order, prune, follow_data)
        return {units[p][i][1] for p, i in live}
    want = {"keep_direct", "keep_fptr", "tbl", "shared_static", "str1"}
    assert kept(True) == want, kept(True)
    assert kept(False) != want, "a collector that ignores data references passed"
    return len(want)


def self_test():
    rows_test()
    commons_test()
    n = reach_test()
    print("fgx_gc: self-test ok (kept %d, dropped drop_me and str_dead; "
          "the data-blind collector fails)" % n)
    return 0


def main():
    if sys.argv[1:] != ["--self-test"]:
        die("usage: fgx_gc.py --self-test")
    try:
        return self_test()
    except AssertionError as e:
        print("fgx_gc: SELF-TEST FAILED: %s" % e)
        return 1


if __name__ == "__main__":
    sys.exit(main())
