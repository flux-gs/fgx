#!/usr/bin/env python3
"""putdeps -- PUT/ASM closure scanner for Merlin-syntax assembly.

WHY THIS EXISTS
    The FGX build assembles with merlin32, whose entire interface is
    `[-v] [-s] [macro_dir] <source_file>` -- no depfile support, closed external
    tool.  fcc gained -MD and fas gained -MD, but neither covers the merlin32
    edges that assemble the kernel and every userland binary.  So the build
    graph has to derive those edges by scanning PUT/ASM closures itself.  This
    is not a redundant second model of the graph; for merlin32 it is the only
    mechanism available.

RESOLUTION, matching fas do_put() and Merlin32
    A PUT operand resolves relative to the DIRECTORY OF THE FILE CONTAINING IT
    (not the cwd, and not the top-level source).  Merlin appends `.S`
    automatically, so try in order: literal, +`.S`, +`.s`.

UNRESOLVED PUTS ARE ERRORS, NOT SKIPS
    build.sh's deps_of() did `if not os.path.exists(f): continue` -- an operand
    it could not resolve vanished silently, and the build graph came out missing
    an edge while looking complete.  That is the exact failure mode this work
    exists to remove (see the STALE BINARY guard that reported a stale tcsh.bin
    and had no rule to rebuild it).  Here an unresolvable PUT raises unless
    --allow-missing is passed.

Usage:
    putdeps.py <file.s> [more.s ...]        one resolved path per line
    putdeps.py --ninja <out> <file.s>...    a make/ninja depfile for <out>
    putdeps.py --selftest
"""
import os
import re
import sys

# Merlin: optional label, then the PUT/ASM opcode, then the operand.  A line
# whose first non-space char is ';' or '*' is a comment and never counts.
PUT_RE = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*)?\s+(?:PUT|ASM)\s+(\S+)",
                    re.IGNORECASE | re.M)


_LISTDIR_CACHE = {}


def _exists_exact(path):
    """os.path.isfile(), but CASE-SENSITIVE even on a case-insensitive volume.

    macOS/APFS is case-insensitive by default, so `os.path.isfile(base + ".S")`
    answers True for an on-disk `foo.s` -- and _resolve would then hand back the
    string it BUILT (`foo.S`) rather than the real dirent (`foo.s`).  That is not
    cosmetic: the returned path goes straight into --ninja depfiles, ninja
    compares dependency paths as strings, and a depfile naming `foo.S` against a
    build edge naming `foo.s` is a silently missing edge -- precisely the failure
    this module's header says it exists to remove.  It also made the selftest
    fail on macOS and pass on Linux, which is why the push gate had been red on
    every commit since 2026-07-31 without anyone's change being at fault.

    Checking the parent's listing makes resolution identical on both filesystem
    kinds.  The listing is cached: scan() resolves every PUT in the tree and the
    same few directories come up repeatedly.

    CACHE INVARIANT: no consumer may CREATE a .s file between scans in one
    process.  gen.py imports this module and calls scan() many times, but the
    generated sources (kernel_exports.s, w5100_patchsites.s, seg1_layout.s) are
    produced by ninja at BUILD time, not by gen.py -- which is why those scans
    either pass allow_missing=True or name the file via `generated=`.  A future
    caller that emits sources and then re-scans must clear _LISTDIR_CACHE.
    """
    if not os.path.isfile(path):
        return False                    # cheap reject, and covers "no such dir"
    d, n = os.path.split(path)
    d = d or "."
    try:
        names = _LISTDIR_CACHE[d]
    except KeyError:
        try:
            names = frozenset(os.listdir(d))
        except OSError:
            names = frozenset()
        _LISTDIR_CACHE[d] = names
    return n in names


def _resolve(operand, from_dir):
    """literal, then .S, then .s -- as fas do_put() and Merlin32 do."""
    base = os.path.normpath(os.path.join(from_dir, operand))
    for cand in (base, base + ".S", base + ".s"):
        if _exists_exact(cand):
            return cand
    return None


def _resolve_generated(operand, from_dir, generated):
    """Resolve an operand against files the BUILD will produce, not the disk.

    Same candidate order as _resolve, matched against `generated` (normalised
    paths) instead of the filesystem.  This is what lets a scan stay STRICT in a
    clean checkout: a source ninja generates does not exist yet, but the caller
    knows it is coming and names it, so the edge is EMITTED rather than dropped
    -- and anything not named is still a hard error.

    The path is not opened for nested PUTs; there is nothing to read until the
    build writes it.  Every file this is used for today (kernel_exports.s, for
    the far bank and the four modules) is a flat list of `sym EQU $addr` with no
    PUTs of its own.  A generated source that itself PUT'd would need its own
    closure stated by the caller.
    """
    base = os.path.normpath(os.path.join(from_dir, operand))
    for cand in (base, base + ".S", base + ".s"):
        if cand in generated:
            return cand
    return None


def scan(roots, allow_missing=False, generated=()):
    """Transitive PUT/ASM closure of `roots`, including the roots themselves.

    `generated` names sources the BUILD produces (see _resolve_generated).  An
    operand that resolves there is returned as a dependency but not opened, and
    does not count as missing -- so a scan of a tree containing generated
    sources can stay strict instead of falling back to allow_missing, which
    would drop the edge as well as the error.

    Returns paths in first-seen order -- stable output keeps generated depfiles
    diff-clean across runs."""
    generated = {os.path.normpath(g) for g in generated}
    seen, order, missing = set(), [], []
    todo = list(roots)
    while todo:
        path = todo.pop(0)
        real = os.path.normpath(path)
        if real in seen:
            continue
        if real in generated:
            seen.add(real)                    # edge kept; nothing to read yet
            order.append(real)
            continue
        if not os.path.isfile(real):
            missing.append((real, "<root>"))
            continue
        seen.add(real)
        order.append(real)
        here = os.path.dirname(real) or "."
        with open(real, errors="ignore") as fh:
            text = fh.read()
        for m in PUT_RE.finditer(text):
            line_start = text.rfind("\n", 0, m.start()) + 1
            if text[line_start:m.start() + 1].lstrip()[:1] in (";", "*"):
                continue                      # commented-out PUT
            hit = _resolve(m.group(1), here)
            if hit is None:
                hit = _resolve_generated(m.group(1), here, generated)
            if hit is None:
                missing.append((m.group(1), real))
            else:
                todo.append(hit)
    if missing and not allow_missing:
        for operand, src in missing:
            print(f"putdeps: unresolved PUT {operand!r} in {src}", file=sys.stderr)
        raise SystemExit(
            f"putdeps: {len(missing)} unresolved PUT operand(s) -- a dropped "
            f"edge would make the build graph silently miss rebuilds")
    return order


def _selftest():
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        sub = os.path.join(d, "sub")
        os.makedirs(sub)
        w = lambda p, s: open(p, "w").write(s)

        # leaf reached via a SUBDIRECTORY include: proves operands resolve
        # relative to the including file, not the top-level source or cwd.
        w(os.path.join(sub, "leaf.s"), "LEAF EQU $42\n")
        w(os.path.join(sub, "mid.s"), "                PUT     leaf\n")
        w(os.path.join(d, "top.s"),
          "                PUT     sub/mid\n"
          "; commented    PUT     nope\n"
          "*              PUT     alsonope\n"
          "LBL             PUT     sub/leaf\n")      # labelled PUT, dup target
        w(os.path.join(d, "unused.s"), "UNUSED EQU $99\n")

        got = scan([os.path.join(d, "top.s")])
        names = [os.path.basename(p) for p in got]
        assert names == ["top.s", "mid.s", "leaf.s"], names
        assert not any("unused" in n for n in names), names

        # extension-less operand resolving via the .s suffix is covered above
        # (every PUT there omits the extension).

        # CASE.  The block above only ever writes lowercase `.s`, so on a
        # case-INSENSITIVE volume (macOS/APFS) `base + ".S"` matched first and
        # _resolve returned a path whose case did not match the dirent.  That
        # passed on Linux and failed here, so the gate was red on every commit
        # while nobody's change was at fault.  Drive BOTH suffixes, and assert
        # the returned basename is the one actually on disk.
        upper = os.path.join(d, "upper")
        os.makedirs(upper)
        w(os.path.join(upper, "capleaf.S"), "CAP EQU $7\n")     # UPPERCASE .S
        w(os.path.join(d, "captop.s"), "                PUT     upper/capleaf\n")
        got = [os.path.basename(p) for p in scan([os.path.join(d, "captop.s")])]
        assert got == ["captop.s", "capleaf.S"], got

        # And the mirror: a lowercase .s target must not come back as .S.
        got = [os.path.basename(p) for p in scan([os.path.join(d, "top.s")])]
        assert all(n.endswith(".s") for n in got), got

        # An unresolvable PUT must RAISE, not vanish -- deps_of()'s bug.
        w(os.path.join(d, "bad.s"), "                PUT     does_not_exist\n")
        try:
            scan([os.path.join(d, "bad.s")])
        except SystemExit:
            pass
        else:
            raise AssertionError("unresolved PUT did not raise")
        # ...unless explicitly allowed
        assert len(scan([os.path.join(d, "bad.s")], allow_missing=True)) == 1

        # A BUILD-GENERATED operand: absent from disk, named by the caller.
        # It must resolve (no error) AND appear as a dependency -- allow_missing
        # would do the first and not the second, which is the silently-dropped
        # edge this module exists to prevent.
        w(os.path.join(d, "gen_user.s"), "                PUT     made_later\n")
        made = os.path.join(d, "made_later.s")
        got = scan([os.path.join(d, "gen_user.s")], generated=[made])
        assert os.path.normpath(made) in got, got
        # Naming one generated file must not excuse a DIFFERENT missing PUT.
        try:
            scan([os.path.join(d, "bad.s")], generated=[made])
        except SystemExit:
            pass
        else:
            raise AssertionError("generated= wrongly excused an unrelated PUT")

        # Cycles must terminate.
        w(os.path.join(d, "a.s"), "                PUT     b\n")
        w(os.path.join(d, "b.s"), "                PUT     a\n")
        assert len(scan([os.path.join(d, "a.s")])) == 2
    print("putdeps self-check: OK")


def main(argv):
    if "--selftest" in argv:
        _selftest()
        return 0
    allow = "--allow-missing" in argv
    argv = [a for a in argv if a != "--allow-missing"]
    if argv[:1] == ["--ninja"]:
        out, roots = argv[1], argv[2:]
        deps = scan(roots, allow)
        sys.stdout.write(out + ":")
        for d in deps:
            sys.stdout.write(" \\\n  " + d)
        sys.stdout.write("\n")
        return 0
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    for p in scan(argv, allow):
        print(p)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
